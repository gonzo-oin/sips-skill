# sips-skill

An AI-agent skill for macOS image processing with Apple's built-in `sips` command.

This skill is designed for end-to-end image workflows using **sips only**:
- format conversion (JPEG, PNG, GIF, HEIC, etc.)
- resize, crop, pad, rotate, flip
- metadata/property operations
- ICC profile and color operations
- batch processing with helper scripts

## Why this skill

`sips` is preinstalled on macOS and works well for reliable command-line image tasks without external dependencies like ImageMagick.

## Install

From [skills.sh](https://skills.sh):

```bash
npx skills add https://github.com/gonzo-oin/sips-skill
```

## Skill entry point

- [SKILL.md](./SKILL.md)

## Quick examples

Resize (keep aspect ratio):

```bash
sips --resampleHeightWidthMax 1600 input.jpg --out resized.jpg
```

Convert JPEG to HEIC:

```bash
sips -s format heic -s formatOptions 80 input.jpeg --out output.heic
```

Crop to square:

```bash
sips --cropToHeightWidth 1200 1200 input.png --out cropped.png
```

Batch resize with helper script:

```bash
./scripts/sips_tool.sh apply \
  --out /tmp/resized \
  --args "--resampleHeightWidthMax 1920" \
  ./images
```

## Included scripts

- [`scripts/sips_tool.sh`](./scripts/sips_tool.sh): Generic batch wrapper for arbitrary `sips` operations.
- [`scripts/convert_to_heic.sh`](./scripts/convert_to_heic.sh): HEIC-focused converter with quality and size controls.

## HEIC / HEIF support notes

Format support depends on your macOS build. Always verify on the target machine:

```bash
sips --formats
```

On many modern macOS versions:
- `heic` is writable
- `heif` may be read-only

## Reference docs

- [`references/sips-reference.md`](./references/sips-reference.md)

## Development

Validate shell scripts:

```bash
bash -n scripts/sips_tool.sh
bash -n scripts/convert_to_heic.sh
```

## License

Apache-2.0 (see [LICENSE](./LICENSE)).
