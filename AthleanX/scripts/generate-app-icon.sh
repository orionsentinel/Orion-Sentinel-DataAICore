#!/usr/bin/env bash
# Generates the ATHLEAN-X app icon PNG from SVG using rsvg-convert or Inkscape.
# Run this once on a Mac with rsvg-convert (brew install librsvg) or Inkscape.
#
# Output: AthleanX/AthleanX/Resources/Assets.xcassets/AppIcon.appiconset/icon-1024.png
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SVG="$SCRIPT_DIR/../AthleanX/Resources/AppIcon.svg"
OUT="$SCRIPT_DIR/../AthleanX/Resources/Assets.xcassets/AppIcon.appiconset/icon-1024.png"

if command -v rsvg-convert &>/dev/null; then
  rsvg-convert -w 1024 -h 1024 "$SVG" -o "$OUT"
  echo "Icon generated at $OUT"
elif command -v inkscape &>/dev/null; then
  inkscape --export-type=png --export-width=1024 --export-height=1024 \
    --export-filename="$OUT" "$SVG"
  echo "Icon generated at $OUT"
else
  echo "Install rsvg-convert (brew install librsvg) or Inkscape to generate the icon."
  exit 1
fi
