#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
sips_tool.sh - safe batch wrapper around macOS sips.

Usage:
  sips_tool.sh formats
  sips_tool.sh info [--one-line] [--key KEY ...] INPUT [INPUT...]
  sips_tool.sh apply [options] INPUT [INPUT...]

Subcommands:
  formats
    Print read/write formats from `sips --formats`.

  info
    Query image properties for one or many files.

  apply
    Apply arbitrary sips arguments in batch mode.
    This is the generic path that enables all sips workflows.

apply options:
  --out DIR               Output directory (required unless --in-place).
  --in-place              Modify source files in place.
  --suffix TEXT           Output suffix (default: -sips).
  --overwrite             Overwrite existing output files.
  --only-smaller          Keep output only when output bytes < input bytes.
  --dry-run               Print commands without executing.
  --arg TOKEN             Add one raw sips token (repeatable).
  --args "STRING"         Add many tokens split by spaces.
  --optimize-color        Adds --optimizeColorForSharing.
  -h, --help              Show help.

info options:
  --key KEY               Property key to query (repeatable).
                          Defaults: format, pixelWidth, pixelHeight.
  --one-line              Use sips one-line output.

Examples:
  # Convert recursively to HEIC (quality 80)
  ./scripts/sips_tool.sh apply \
    --out /tmp/heic \
    --arg -s --arg format --arg heic \
    --arg -s --arg formatOptions --arg 80 \
    ./images

  # Resize longest edge to 1920 and optimize color
  ./scripts/sips_tool.sh apply \
    --out /tmp/web \
    --args "--resampleHeightWidthMax 1920" \
    --optimize-color \
    ./images

  # Read custom metadata fields
  ./scripts/sips_tool.sh info --key format --key dpiWidth --key dpiHeight image.jpg
USAGE
}

die() {
  echo "Error: $*" >&2
  exit 1
}

to_lower() {
  printf '%s' "$1" | tr '[:upper:]' '[:lower:]'
}

normalize_format() {
  local fmt
  fmt="$(to_lower "$1")"
  case "$fmt" in
    jpg) echo "jpeg" ;;
    tif) echo "tiff" ;;
    *) echo "$fmt" ;;
  esac
}

format_to_extension() {
  local fmt
  fmt="$(normalize_format "$1")"
  case "$fmt" in
    jpeg) echo "jpg" ;;
    tiff) echo "tiff" ;;
    *) echo "$fmt" ;;
  esac
}

have_cmd() {
  command -v "$1" >/dev/null 2>&1
}

file_size_bytes() {
  local path="$1"
  if [[ "$(uname)" == "Darwin" ]]; then
    stat -f%z "$path"
  else
    stat -c%s "$path"
  fi
}

is_supported_file() {
  local path="$1"
  local ext="${path##*.}"
  ext="$(to_lower "$ext")"
  case "$ext" in
    jpg|jpeg|png|tif|tiff|heic|heif|heics|webp|gif|bmp|jp2|avif|psd|tga|exr|dng|raw|arw|cr2|cr3|nef|nrw|orf|rw2|pef|srw|ico|icns|pbm|pvr|icc|icm) return 0 ;;
    *) return 1 ;;
  esac
}

discover_files() {
  local input
  for input in "$@"; do
    if [[ -d "$input" ]]; then
      find "$input" -type f -print0
    elif [[ -f "$input" ]]; then
      printf '%s\0' "$input"
    fi
  done
}

query_image_format() {
  local input="$1"
  local fmt
  fmt="$(sips -g format "$input" 2>/dev/null | awk -F': ' '/format:/{print tolower($2); exit}')"
  normalize_format "$fmt"
}

next_available_path() {
  local desired="$1"
  local dir base stem ext candidate n

  dir="$(dirname "$desired")"
  base="$(basename "$desired")"
  ext="${base##*.}"
  stem="${base%.*}"

  candidate="$desired"
  n=1
  while [[ -e "$candidate" ]]; do
    candidate="$dir/${stem}-${n}.${ext}"
    ((n+=1))
  done
  printf '%s\n' "$candidate"
}

extract_target_format_from_args() {
  local i token next key value
  for ((i=0; i<${#SIPS_ARGS[@]}; i++)); do
    token="${SIPS_ARGS[$i]}"
    if [[ "$token" == "-s" || "$token" == "--setProperty" ]]; then
      if (( i + 2 < ${#SIPS_ARGS[@]} )); then
        key="$(to_lower "${SIPS_ARGS[$((i+1))]}")"
        value="${SIPS_ARGS[$((i+2))]}"
        if [[ "$key" == "format" ]]; then
          printf '%s\n' "$(normalize_format "$value")"
          return 0
        fi
      fi
    fi
  done
  printf '%s\n' ""
}

subcmd="${1:-}"
[[ -n "$subcmd" ]] || {
  usage
  exit 1
}

case "$subcmd" in
  -h|--help)
    usage
    exit 0
    ;;
  formats)
    have_cmd sips || die "sips command not found (requires macOS)"
    sips --formats
    exit 0
    ;;
  info)
    shift
    have_cmd sips || die "sips command not found (requires macOS)"

    one_line="false"
    declare -a KEYS=()
    declare -a INPUTS=()

    while [[ $# -gt 0 ]]; do
      case "$1" in
        --key)
          [[ $# -lt 2 ]] && die "Missing value for --key"
          KEYS+=("$2")
          shift 2
          ;;
        --one-line)
          one_line="true"
          shift
          ;;
        -h|--help)
          usage
          exit 0
          ;;
        --*)
          die "Unknown info option: $1"
          ;;
        *)
          INPUTS+=("$1")
          shift
          ;;
      esac
    done

    [[ ${#INPUTS[@]} -gt 0 ]] || die "Provide at least one image path"
    if [[ ${#KEYS[@]} -eq 0 ]]; then
      KEYS=(format pixelWidth pixelHeight)
    fi

    cmd=(sips)
    if [[ "$one_line" == "true" ]]; then
      cmd+=(--oneLine)
    fi
    for key in "${KEYS[@]}"; do
      cmd+=(--getProperty "$key")
    done

    for input in "${INPUTS[@]}"; do
      [[ -f "$input" ]] || {
        echo "SKIP not a file: $input"
        continue
      }
      echo "==> $input"
      "${cmd[@]}" "$input"
    done
    exit 0
    ;;
  apply)
    shift
    ;;
  *)
    die "Unknown subcommand: $subcmd"
    ;;
esac

have_cmd sips || die "sips command not found (requires macOS)"

OUT_DIR=""
IN_PLACE="false"
SUFFIX="-sips"
OVERWRITE="false"
ONLY_SMALLER="false"
DRY_RUN="false"
OPTIMIZE_COLOR="false"
declare -a SIPS_ARGS=()
declare -a INPUTS=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --out)
      [[ $# -lt 2 ]] && die "Missing value for --out"
      OUT_DIR="$2"
      shift 2
      ;;
    --in-place)
      IN_PLACE="true"
      shift
      ;;
    --suffix)
      [[ $# -lt 2 ]] && die "Missing value for --suffix"
      SUFFIX="$2"
      shift 2
      ;;
    --overwrite)
      OVERWRITE="true"
      shift
      ;;
    --only-smaller)
      ONLY_SMALLER="true"
      shift
      ;;
    --dry-run)
      DRY_RUN="true"
      shift
      ;;
    --optimize-color)
      OPTIMIZE_COLOR="true"
      shift
      ;;
    --arg)
      [[ $# -lt 2 ]] && die "Missing value for --arg"
      SIPS_ARGS+=("$2")
      shift 2
      ;;
    --args)
      [[ $# -lt 2 ]] && die "Missing value for --args"
      read -r -a chunk <<< "$2"
      SIPS_ARGS+=("${chunk[@]}")
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    --*)
      die "Unknown apply option: $1"
      ;;
    *)
      INPUTS+=("$1")
      shift
      ;;
  esac
done

[[ ${#INPUTS[@]} -gt 0 ]] || die "Provide at least one input file or directory"
[[ ${#SIPS_ARGS[@]} -gt 0 || "$OPTIMIZE_COLOR" == "true" ]] || die "Provide sips operations with --arg/--args or --optimize-color"

if [[ "$IN_PLACE" == "true" && -n "$OUT_DIR" ]]; then
  die "Use either --in-place or --out, not both"
fi
if [[ "$IN_PLACE" != "true" && -z "$OUT_DIR" ]]; then
  die "--out is required unless --in-place is used"
fi
if [[ "$IN_PLACE" == "true" && "$ONLY_SMALLER" == "true" ]]; then
  die "--only-smaller cannot be used with --in-place"
fi

if [[ -n "$OUT_DIR" ]]; then
  mkdir -p "$OUT_DIR"
fi

processed=0
skipped=0
total_input_bytes=0
total_output_bytes=0

target_format="$(extract_target_format_from_args)"

while IFS= read -r -d '' input; do
  if [[ ! -f "$input" ]]; then
    echo "SKIP not a file: $input"
    ((skipped+=1))
    continue
  fi
  if ! is_supported_file "$input"; then
    echo "SKIP unsupported extension: $input"
    ((skipped+=1))
    continue
  fi

  src_format="$(query_image_format "$input")"
  if [[ -z "$src_format" ]]; then
    echo "SKIP unreadable format: $input"
    ((skipped+=1))
    continue
  fi

  cmd=(sips)
  cmd+=("${SIPS_ARGS[@]}")
  if [[ "$OPTIMIZE_COLOR" == "true" ]]; then
    cmd+=(--optimizeColorForSharing)
  fi

  if [[ "$IN_PLACE" == "true" ]]; then
    cmd+=("$input")

    if [[ "$DRY_RUN" == "true" ]]; then
      echo "DRY-RUN: ${cmd[*]}"
      ((processed+=1))
      continue
    fi

    if "${cmd[@]}" >/dev/null 2>&1; then
      echo "OK: $input (in-place)"
      ((processed+=1))
    else
      echo "FAIL: $input"
      ((skipped+=1))
    fi
    continue
  fi

  out_format="$src_format"
  if [[ -n "$target_format" ]]; then
    out_format="$target_format"
  fi
  out_ext="$(format_to_extension "$out_format")"

  stem="$(basename "$input")"
  stem="${stem%.*}"
  output="$OUT_DIR/${stem}${SUFFIX}.${out_ext}"

  if [[ "$OVERWRITE" != "true" ]]; then
    output="$(next_available_path "$output")"
  fi

  cmd+=("$input" --out "$output")

  if [[ "$DRY_RUN" == "true" ]]; then
    echo "DRY-RUN: ${cmd[*]}"
    ((processed+=1))
    continue
  fi

  if ! "${cmd[@]}" >/dev/null 2>&1; then
    echo "FAIL: $input"
    ((skipped+=1))
    continue
  fi

  in_size="$(file_size_bytes "$input")"
  out_size="$(file_size_bytes "$output")"

  if [[ "$ONLY_SMALLER" == "true" ]] && (( out_size >= in_size )); then
    rm -f "$output"
    echo "SKIP not smaller: $input"
    ((skipped+=1))
    continue
  fi

  ((total_input_bytes+=in_size))
  ((total_output_bytes+=out_size))
  echo "OK: $input -> $output"
  ((processed+=1))
done < <(discover_files "${INPUTS[@]}")

if [[ "$DRY_RUN" == "true" ]]; then
  echo "Done (dry-run). Planned operations: $processed"
  exit 0
fi

if [[ "$IN_PLACE" != "true" && $processed -gt 0 && $total_input_bytes -gt 0 ]]; then
  ratio="$(awk -v a="$total_input_bytes" -v b="$total_output_bytes" 'BEGIN { printf "%.2f", (1 - (b/a)) * 100 }')"
  echo "Done. Processed: $processed, Skipped: $skipped"
  echo "Input bytes: $total_input_bytes"
  echo "Output bytes: $total_output_bytes"
  echo "Size reduction: ${ratio}%"
  echo "Output directory: $OUT_DIR"
else
  echo "Done. Processed: $processed, Skipped: $skipped"
fi
