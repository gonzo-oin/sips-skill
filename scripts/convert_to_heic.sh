#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Convert one or many images to HEIC with macOS sips.

Usage:
  convert_to_heic.sh --out OUTPUT_DIR [options] INPUT [INPUT...]

Options:
  --out DIR              Output directory (required).
  --quality N            HEIC quality 1-100 (default: 80).
  --suffix TEXT          Suffix for output basename (default: -heic).
  --overwrite            Overwrite existing output files.
  --only-smaller         Keep output only when output bytes < input bytes.
  --delete-originals     Delete originals after successful conversion.
  --recursive            When inputs are folders, scan recursively.
  --dry-run              Print commands without executing.
  -h, --help             Show help.

Notes:
  - This script relies only on sips.
  - HEIC write support is available on modern macOS versions.
  - If your system does not support writing a format, conversion will fail.
USAGE
}

die() {
  echo "Error: $*" >&2
  exit 1
}

to_lower() {
  printf '%s' "$1" | tr '[:upper:]' '[:lower:]'
}

file_size_bytes() {
  local path="$1"
  if [[ "$(uname)" == "Darwin" ]]; then
    stat -f%z "$path"
  else
    stat -c%s "$path"
  fi
}

is_supported_input() {
  local ext="${1##*.}"
  ext="$(to_lower "$ext")"
  case "$ext" in
    jpg|jpeg|png|bmp|tif|tiff|dng|arw|cr2|cr3|nef|rw2|webp|gif|avif|heif|heic) return 0 ;;
    *) return 1 ;;
  esac
}

discover_files() {
  local recursive="$1"
  shift
  local input
  for input in "$@"; do
    if [[ -d "$input" ]]; then
      if [[ "$recursive" == "true" ]]; then
        find "$input" -type f -print0
      else
        find "$input" -maxdepth 1 -type f -print0
      fi
    elif [[ -f "$input" ]]; then
      printf '%s\0' "$input"
    fi
  done
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

OUT_DIR=""
QUALITY="80"
SUFFIX="-heic"
OVERWRITE="false"
ONLY_SMALLER="false"
DELETE_ORIGINALS="false"
RECURSIVE="false"
DRY_RUN="false"
declare -a INPUTS=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --out)
      [[ $# -lt 2 ]] && die "Missing value for --out"
      OUT_DIR="$2"
      shift 2
      ;;
    --quality)
      [[ $# -lt 2 ]] && die "Missing value for --quality"
      QUALITY="$2"
      shift 2
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
    --delete-originals)
      DELETE_ORIGINALS="true"
      shift
      ;;
    --recursive)
      RECURSIVE="true"
      shift
      ;;
    --dry-run)
      DRY_RUN="true"
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    --*)
      die "Unknown option: $1"
      ;;
    *)
      INPUTS+=("$1")
      shift
      ;;
  esac
done

command -v sips >/dev/null 2>&1 || die "sips command not found (requires macOS)"
[[ -n "$OUT_DIR" ]] || die "--out is required"
[[ ${#INPUTS[@]} -gt 0 ]] || die "Provide at least one input file or directory"
[[ "$QUALITY" =~ ^[0-9]+$ ]] || die "--quality must be integer 1-100"
(( QUALITY >= 1 && QUALITY <= 100 )) || die "--quality must be 1-100"

mkdir -p "$OUT_DIR"

processed=0
skipped=0
removed=0

while IFS= read -r -d '' input; do
  if [[ ! -f "$input" ]]; then
    ((skipped+=1))
    continue
  fi
  if ! is_supported_input "$input"; then
    echo "SKIP unsupported extension: $input"
    ((skipped+=1))
    continue
  fi

  stem="$(basename "$input")"
  stem="${stem%.*}"
  output="$OUT_DIR/${stem}${SUFFIX}.heic"
  if [[ "$OVERWRITE" != "true" ]]; then
    output="$(next_available_path "$output")"
  fi

  cmd=(sips -s format heic -s formatOptions "$QUALITY" "$input" --out "$output")

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

  if [[ "$ONLY_SMALLER" == "true" ]]; then
    in_size="$(file_size_bytes "$input")"
    out_size="$(file_size_bytes "$output")"
    if (( out_size >= in_size )); then
      rm -f "$output"
      echo "SKIP not smaller: $input"
      ((skipped+=1))
      continue
    fi
  fi

  if [[ "$DELETE_ORIGINALS" == "true" ]]; then
    rm -f "$input" && ((removed+=1)) || true
  fi

  echo "OK: $input -> $output"
  ((processed+=1))
done < <(discover_files "$RECURSIVE" "${INPUTS[@]}")

if [[ "$DRY_RUN" == "true" ]]; then
  echo "Done (dry-run). Planned operations: $processed"
  exit 0
fi

echo "Done. Converted: $processed, Skipped: $skipped, Removed originals: $removed"
echo "Output directory: $OUT_DIR"
