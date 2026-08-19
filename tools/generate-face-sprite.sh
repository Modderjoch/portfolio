#!/usr/bin/env bash
#
# Builds the FaceTracker sprite sheet from the individual gaze tiles.
#
# The sprite is a 13x13 grid of 256px tiles (3328x3328). Tiles are laid out
# row-major with the TOP row at py=+15 (looking up) and the LEFT column at
# px=-15 (looking left), which is the orientation FaceTracker.astro decodes:
#
#   col = (px + 15) / 2.5      row = (15 - py) / 2.5
#
# 3328^2 = 11.1M pixels, comfortably under the ~16.7M decode ceiling that iOS
# Safari applies to a single image. Do not raise the tile size without checking
# that budget -- a 512px tile grid would be 6656^2 = 44M pixels and get silently
# subsampled, which breaks sprite alignment.
#
# Quality is deliberately low-ish: the sprite is only ever visible while the
# pointer is moving, and FaceTracker layers the crisp 512px tile on top once the
# pointer comes to rest.
#
# Usage: tools/generate-face-sprite.sh

set -euo pipefail

# Force C locale: under e.g. nl_NL, printf/awk emit "-15,0" and the tile names
# (which use "." -> "p") would never match.
export LC_ALL=C

cd "$(dirname "$0")/.."

TILE_DIR="tools/face-tiles"
OUT="src/assets/images/faces/face-sprite-13x13-256.webp"
QUALITY=75

command -v magick >/dev/null || { echo "error: ImageMagick (magick) not found" >&2; exit 1; }

list=$(mktemp)
trap 'rm -f "$list"' EXIT

# Emit the 169 tile paths in sprite order. sanitize() mirrors the component:
# -15.0 -> "m15p0", 2.5 -> "2p5".
awk -v dir="$TILE_DIR" '
  function sanitize(v,   s) { s = sprintf("%.1f", v); sub(/-/, "m", s); sub(/\./, "p", s); return s }
  BEGIN {
    for (r = 12; r >= 0; r--)                 # py from +15 down to -15 (top -> bottom)
      for (c = 0; c <= 12; c++)               # px from -15 up to +15   (left -> right)
        printf "%s/gaze_px%s_py%s_256.webp\n", dir, sanitize(-15 + c * 2.5), sanitize(-15 + r * 2.5)
  }' > "$list"

missing=0
while read -r tile; do
  [ -f "$tile" ] || { echo "missing tile: $tile" >&2; missing=1; }
done < "$list"
[ "$missing" -eq 0 ] || { echo "error: aborting, tiles are missing" >&2; exit 1; }

count=$(wc -l < "$list")
[ "$count" -eq 169 ] || { echo "error: expected 169 tiles, listed $count" >&2; exit 1; }

mkdir -p "$(dirname "$OUT")"
magick montage "@$list" -tile 13x13 -geometry +0+0 -quality "$QUALITY" "$OUT"

dims=$(magick identify -format '%wx%h' "$OUT")
[ "$dims" = "3328x3328" ] || { echo "error: expected 3328x3328, got $dims" >&2; exit 1; }

echo "wrote $OUT  ($dims, $(du -h "$OUT" | cut -f1))"
