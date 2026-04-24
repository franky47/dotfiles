---
name: imagemagick
description: ImageMagick 7+ image manipulation commands and best practices
---

# ImageMagick 7+ Usage

## Critical: Use `magick`, Not `convert`

In ImageMagick 7+, the `convert` command is **deprecated**. Use `magick` instead:

```bash
# Wrong (generates warnings)
convert input.png output.jpg

# Correct
magick input.png output.jpg

# Also correct (explicit tool)
magick convert input.png output.jpg
```

## Common Operations

### Format Conversion
```bash
magick input.png output.jpg
magick input.jpg -format webp output.webp
```

### Resize
```bash
magick input.jpg -resize 50% output.jpg
magick input.jpg -resize 1920x1080 output.jpg
magick input.jpg -resize 1920x1080^ output.jpg  # Minimum dimensions
```

### Compress/Quality
```bash
# JPEG quality (0-100, higher is better quality, larger file)
magick input.png -quality 85 output.jpg
```

### Strip Metadata
```bash
magick input.jpg -strip output.jpg
```

### Batch Processing
```bash
for file in *.png; do
  magick "$file" "${file%.png}.jpg"
done
```

## Key Flags

| Flag | Description |
|------|-------------|
| `-quality N` | JPEG compression (0-100) |
| `-resize WxH` | Resize to dimensions |
| `-strip` | Remove metadata |
| `-format FMT` | Specify output format |
| `-auto-orient` | Fix orientation from EXIF |
| `-compress type` | Compression type (lossy, lossless, none) |

## ImageMagick 6 vs 7

- IM 6: Uses `convert`, `mogrify`, `identify` as separate commands
- IM 7: All tools available via `magick <tool>` (e.g., `magick convert`, `magick mogrify`)
- IM 7 standalone commands still work but emit deprecation warnings

## Version Check

```bash
magick --version
```

## Important Notes

- Always quote filenames with spaces: `"$file"`
- Use `-strip` to reduce file size by removing EXIF/metadata
- Default JPEG quality is 92; use `-quality 85` for web images
- IM 7 maintains backward compatibility but warns about deprecated usage
