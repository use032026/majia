#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

if ! command -v magick >/dev/null 2>&1; then
  echo 'ImageMagick (magick) is required to regenerate app icons.' >&2
  exit 1
fi

magick -background '#07544E' -density 96 assets/brand/app_icon.svg \
  -alpha off -depth 8 -strip PNG24:assets/brand/app_icon.png

for icon in ios/Runner/Assets.xcassets/AppIcon.appiconset/*.png; do
  pixels=$(magick identify -format '%w' "$icon")
  magick assets/brand/app_icon.png -filter Lanczos -resize "${pixels}x${pixels}" \
    -alpha off -depth 8 -strip "PNG24:$icon"
done

for spec in mdpi:48 hdpi:72 xhdpi:96 xxhdpi:144 xxxhdpi:192; do
  density=${spec%%:*}
  pixels=${spec##*:}
  icon="android/app/src/main/res/mipmap-$density/ic_launcher.png"
  magick assets/brand/app_icon.png -filter Lanczos -resize "${pixels}x${pixels}" \
    -alpha off -depth 8 -strip "PNG24:$icon"
done
