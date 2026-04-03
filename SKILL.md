---
name: sips-skill
description: "Use macOS sips for full command-line image workflows: format conversion (including HEIC/HEIF-family where supported), resize/crop/pad/rotate/flip, metadata and color profile operations, and batch processing. Trigger this skill for any macOS image manipulation request that should rely entirely on sips."
---

# Sips Skill

Use this skill when image work must be done on macOS with `sips` only.

## Trigger

Use this skill when users ask to:
- convert image formats (`png`/`jpeg`/`gif`/`heic`/etc.)
- resize or crop images
- batch-process a folder of images
- optimize output size/quality for web or mobile
- rotate, flip, pad, or normalize image outputs
- inspect or modify metadata/properties
- apply ICC profile operations

## When Not to Use This Skill

Do not use this skill for:
- vector graphics editing (SVG authoring, illustration workflows)
- complex creative retouching/compositing
- video processing or transcoding
- non-macOS environments without `sips`

## Overview

`sips` is Apple’s built-in image processing CLI. This skill provides:
- direct `sips` command patterns for one-off tasks
- safe batch wrappers for repeatable jobs
- HEIC-first workflows without external dependencies
- guidance for host-specific format support (`sips --formats`)

Core command pattern:

```bash
sips [operations] input-file --out output-file
```

## Quick Start

### Resize (keep aspect ratio)

```bash
sips --resampleHeightWidthMax 1600 input.jpg --out resized.jpg
```

### Convert format (JPEG -> HEIC)

```bash
sips -s format heic -s formatOptions 80 input.jpeg --out output.heic
```

### Crop to fixed size

```bash
sips --cropToHeightWidth 1200 1200 input.png --out cropped.png
```

### Batch resize with helper script

```bash
./scripts/sips_tool.sh apply \
  --out /tmp/resized \
  --args "--resampleHeightWidthMax 1920" \
  ./images
```

## Common Use Cases

### 1. Format Conversion

```bash
# PNG -> JPEG
sips -s format jpeg -s formatOptions 80 in.png --out out.jpg

# JPEG -> PNG
sips -s format png -s formatOptions best in.jpg --out out.png

# JPEG -> HEIC
sips -s format heic -s formatOptions 80 in.jpg --out out.heic
```

### 2. Resize Workflows

```bash
# Max edge resize (safe default)
sips --resampleHeightWidthMax 1920 in.jpg --out out.jpg

# Exact dimensions (aspect ratio may change)
sips --resampleHeightWidth 1080 1080 in.jpg --out out.jpg

# Width-only resize
sips --resampleWidth 800 in.jpg --out out.jpg
```

### 3. Crop, Pad, Rotate, Flip

```bash
# Center-like crop with explicit size
sips --cropToHeightWidth 1000 1000 in.jpg --out cropped.jpg

# Crop with offset
sips --cropToHeightWidth 1000 1000 --cropOffset 80 40 in.jpg --out cropped-offset.jpg

# Pad to canvas
sips --padToHeightWidth 1200 1200 --padColor FFFFFF in.png --out padded.png

# Rotate and flip
sips --rotate 90 in.jpg --out rotated.jpg
sips --flip horizontal in.jpg --out flipped.jpg
```

### 4. Quality and Web Optimization

```bash
# JPEG quality tuning
sips -s format jpeg -s formatOptions 72 in.png --out web.jpg

# Optimize color for sharing
sips --optimizeColorForSharing in.jpg --out web-optimized.jpg
```

### 5. Metadata and Image Info

```bash
# Query key properties
sips -g format -g pixelWidth -g pixelHeight in.jpg

# One-line output for scripts
sips --oneLine -g format -g pixelWidth -g pixelHeight in.jpg

# Set and delete metadata
sips -s description "ready-for-web" in.png --out tagged.png
sips -d description tagged.png --out clean.png
```

### 6. Profile and Color Management

```bash
# Extract embedded ICC profile
sips --extractProfile extracted.icc in.jpg

# Embed profile
sips --embedProfile /System/Library/ColorSync/Profiles/sRGB\ Profile.icc in.jpg --out profiled.jpg

# Match to profile with rendering intent
sips --matchToWithIntent /System/Library/ColorSync/Profiles/sRGB\ Profile.icc perceptual in.jpg --out matched.jpg
```

## Batch Scripts

### `scripts/sips_tool.sh` (generic)

Use for almost any batch job; pass raw `sips` tokens with `--arg` / `--args`.

```bash
# Convert a folder to HEIC
./scripts/sips_tool.sh apply \
  --out /tmp/heic \
  --arg -s --arg format --arg heic \
  --arg -s --arg formatOptions --arg 80 \
  ./images

# Remove selected metadata keys in batch
./scripts/sips_tool.sh apply \
  --out /tmp/clean \
  --args "-d description -d copyright -d artist" \
  ./images
```

### `scripts/convert_to_heic.sh` (HEIC-focused)

```bash
./scripts/convert_to_heic.sh \
  --out /tmp/heic \
  --quality 80 \
  --only-smaller \
  --recursive \
  ./photos
```

## HEIC / HEIF Notes

- `heic` is typically writable on modern macOS.
- `heif` support may be read-only depending on host build.
- Always check actual capabilities on the current machine:

```bash
sips --formats
```

## Safety Checklist

- preserve originals by default (`--out` directory)
- test one file before batch operations
- validate output format/dimensions/size after transforms
- for automation, prefer `--dry-run` before large runs

## Validation Commands

```bash
ls -lh before.jpg after.heic
sips -g format -g pixelWidth -g pixelHeight after.heic
```

## Reference

Load `references/sips-reference.md` for:
- full capability mapping from `man sips`
- advanced profile/JS examples
- troubleshooting and host limitations
