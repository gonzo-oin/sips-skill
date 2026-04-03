---
name: sips-skill
description: Use macOS sips for end-to-end image workflows: inspect and edit image properties, resize/crop/pad/rotate/flip, convert formats (including HEIC/HEIF-family targets where supported), manage metadata and color profiles (ICC), and run JavaScript image scripts. Trigger for any macOS command-line image task that should rely entirely on sips.
---

# Sips Skill

Use `sips` as the primary macOS image CLI for both one-off and batch workflows.

## Quick Start

```bash
# List readable/writable formats on this machine
./scripts/sips_tool.sh formats

# Read core metadata
./scripts/sips_tool.sh info --key format --key pixelWidth --key pixelHeight image.png

# Generic batch operation: convert to HEIC and set quality
./scripts/sips_tool.sh apply \
  --out /tmp/heic \
  --arg -s --arg format --arg heic \
  --arg -s --arg formatOptions --arg 80 \
  ./images
```

## Capability Map

Based on `man sips`, the skill covers these capability families:

1. Image query and properties.
- `--getProperty`, `--setProperty`, `--deleteProperty`
- format, dpi, copyright, description, artist, etc.

2. Geometric transforms.
- `--resampleHeightWidth`, `--resampleHeightWidthMax`, `--resampleWidth`, `--resampleHeight`
- `--cropToHeightWidth`, `--cropOffset`, `--padToHeightWidth`, `--padColor`
- `--rotate`, `--flip`

3. Format conversion.
- `-s format <fmt>` with optional `-s formatOptions <value>`
- include HEIC workflows when write support is available on host macOS

4. Color and ICC profile workflows.
- `--embedProfile`, `--embedProfileIfNone`, `--matchTo`, `--matchToWithIntent`
- `--extractProfile`, `--deleteColorManagementProperties`

5. Profile-level operations.
- `--verify`, `--repair`, `--extractTag`, `--loadTag`, `--copyTag`, `--deleteTag`

6. JavaScript image scripting.
- `--js <file>` with sips JavaScript runtime for generated/modified outputs

## Workflow

1. Discover support on current host.
- Start with `sips --formats` because read/write support can vary by macOS version.

2. Choose operation family.
- Query/metadata, transform, conversion, color/profile, or JS.

3. Choose execution mode.
- Single command with raw `sips`.
- Batch automation with `scripts/sips_tool.sh apply`.
- Dedicated HEIC conversion with `scripts/convert_to_heic.sh`.

4. Validate output.
- dimensions, format, metadata, and visual quality.
- if conversion target is unsupported, retry with a writable format shown by `sips --formats`.

## Batch Scripts

### Generic Batch Wrapper (`scripts/sips_tool.sh`)

Use this for almost every batch use case. It accepts arbitrary `sips` tokens.

```bash
# Resize longest edge to 1920
./scripts/sips_tool.sh apply \
  --out /tmp/resized \
  --args "--resampleHeightWidthMax 1920" \
  ./images

# Crop to 1200x1200 then set crop offset
./scripts/sips_tool.sh apply \
  --out /tmp/cropped \
  --args "--cropToHeightWidth 1200 1200 --cropOffset 100 100" \
  ./images

# Strip selected metadata keys
./scripts/sips_tool.sh apply \
  --out /tmp/clean \
  --args "-d profile -d description -d copyright -d artist" \
  ./images
```

### HEIC Conversion (`scripts/convert_to_heic.sh`)

Use this when the explicit goal is HEIC output and possible size reduction.

```bash
./scripts/convert_to_heic.sh \
  --out /tmp/heic \
  --quality 80 \
  --only-smaller \
  --recursive \
  ./photos
```

## HEIC and HEIF Notes

- `HEIC` is commonly writable in modern macOS `sips` builds.
- `HEIF` container support can differ by version/build; confirm with `sips --formats`.
- This skill intentionally relies only on `sips` (no ImageMagick dependency).

## Core Command Patterns

```bash
# Resize with aspect ratio preservation
sips --resampleHeightWidthMax 1600 input.jpg --out output.jpg

# Exact resize (can change aspect ratio)
sips --resampleHeightWidth 1080 1080 input.jpg --out output.jpg

# Rotate and flip
sips --rotate 90 input.png --out output.png
sips --flip horizontal input.png --out output.png

# Convert to HEIC
sips -s format heic -s formatOptions 80 input.jpg --out output.heic

# Embed ICC profile only if none exists
sips --embedProfileIfNone /System/Library/ColorSync/Profiles/sRGB\ Profile.icc input.jpg --out output.jpg

# Query format and dimensions
sips -g format -g pixelWidth -g pixelHeight input.jpg
```

## Validation Checklist

```bash
# Size
ls -lh before.jpg after.heic

# Dimensions + format
sips -g format -g pixelWidth -g pixelHeight after.heic

# Optional one-line output for scripts
sips --oneLine -g format -g pixelWidth -g pixelHeight after.heic
```

## Reference

Load `references/sips-reference.md` when you need:
- exhaustive mapping of `man sips` capability groups
- advanced examples (profile tags, rendering intents, JS mode)
- troubleshooting for format write failures and metadata quirks
