# Sips Reference

## 1. Host Capability Discovery

Run these first on the target machine:

```bash
sips --version
sips --formats
sips --helpProperties
```

Why: available readable/writable formats and behavior can change across macOS versions.

## 2. High-Value Property Keys

Commonly useful image keys (query with `-g`, set/delete with `-s` / `-d` when writable):

- `format`
- `formatOptions`
- `pixelWidth`, `pixelHeight` (read-only)
- `dpiWidth`, `dpiHeight`
- `description`, `copyright`, `artist`
- `profile`

Examples:

```bash
sips -g format -g pixelWidth -g pixelHeight input.png
sips -s dpiWidth 72 -s dpiHeight 72 input.png --out output.png
sips -d description -d copyright input.png --out output.png
```

## 3. Transform Operations

### Resize

```bash
# Preserve aspect ratio by max edge
sips --resampleHeightWidthMax 1920 in.jpg --out out.jpg

# Force exact size (aspect ratio may change)
sips --resampleHeightWidth 1080 1080 in.jpg --out out.jpg
```

### Crop and Pad

```bash
sips --cropToHeightWidth 1000 1000 in.jpg --out out.jpg
sips --cropToHeightWidth 1000 1000 --cropOffset 120 80 in.jpg --out out.jpg
sips --padToHeightWidth 1200 1200 --padColor FFFFFF in.jpg --out out.jpg
```

### Rotate and Flip

```bash
sips --rotate 90 in.png --out out.png
sips --flip vertical in.png --out out.png
```

## 4. Format Conversion

### JPEG / PNG

```bash
sips -s format jpeg -s formatOptions 75 in.png --out out.jpg
sips -s format png -s formatOptions best in.jpg --out out.png
```

### HEIC / HEIF-family

```bash
# Preferred modern target
sips -s format heic -s formatOptions 80 in.jpg --out out.heic

# Depending on OS/build, this may or may not be writable
sips -s format heif in.jpg --out out.heif
```

If conversion fails, verify write support with `sips --formats` and choose a writable target.

## 5. Color and Profile Management

```bash
# Extract ICC profile
sips --extractProfile extracted.icc in.jpg

# Embed profile
sips --embedProfile /path/to/profile.icc in.jpg --out out.jpg

# Embed profile only if none exists
sips --embedProfileIfNone /path/to/profile.icc in.jpg --out out.jpg

# Match to target profile with intent
sips --matchToWithIntent /path/to/profile.icc perceptual in.jpg --out out.jpg

# Remove color management properties (TIFF/PNG/EXIF dicts)
sips --deleteColorManagementProperties in.png --out out.png
```

Rendering intent values:
- `perceptual`
- `relative`
- `saturation`
- `absolute`

## 6. Profile-Only Operations

Operate directly on ICC profiles:

```bash
sips --verify profile.icc
sips --repair profile.icc --out repaired.icc
sips --extractTag desc desc.tag profile.icc
sips --loadTag desc desc.tag profile.icc --out updated.icc
```

## 7. JavaScript Mode

Use sips JavaScript runtime for programmatic image generation/transforms.

```bash
sips --js script.js input.jpg --out output.png
```

`man sips` documents JS globals (`sips.images`, `sips.arguments`, `sips.size`, etc.) and output queue primitives.

## 8. Batch Through The Skill Scripts

```bash
# Any sips operation in batch via raw args
./scripts/sips_tool.sh apply --out /tmp/out --args "--resampleHeightWidthMax 1920" ./images

# HEIC-focused helper
./scripts/convert_to_heic.sh --out /tmp/heic --quality 80 --recursive ./images
```

## 9. Troubleshooting

1. Conversion fails with target format.
- Run `sips --formats` and confirm the target is marked writable.

2. Output larger than input.
- lower `formatOptions`
- reduce dimensions first
- use `--only-smaller` in provided scripts

3. Metadata deletion appears partial.
- some keys may be absent or read-only in the source format
- inspect with `sips -g allxml file`

4. Aspect ratio looks wrong.
- use `--resampleHeightWidthMax` instead of `--resampleHeightWidth`.
