#!/usr/bin/env bash
#
# Builds the FaceTracker sprite sheet from the individual gaze tiles.
#
# The sprite is a 13x13 grid of tiles. They are laid out row-major with the TOP
# row at py=+15 (looking up) and the LEFT column at px=-15 (looking left), which
# is the orientation FaceTracker.astro decodes:
#
#   col = (px + 15) / 2.5      row = (15 - py) / 2.5
#
# Usage: tools/generate-face-sprite.sh [256|512]
#
# The component positions the sheet in percentages, so it is resolution-agnostic:
# switching tile size only means pointing the import in FaceTracker.astro at the
# matching file. Measured trade-off (all 169 poses, q75):
#
#   tile  sheet       file      pixels   decoded
#   256   3328x3328   1.13 MB   11.1 M    42 MB
#   512   6656x6656   3.58 MB   44.3 M   169 MB
#
# 512 is 3.2x the bytes and sits well past the ~16.7M-pixel decode ceiling iOS
# Safari applies to a single image, so on phones it risks slow decodes, memory
# pressure, and being silently subsampled -- which hands back the sharpness it
# was paid for. Alignment itself survives subsampling (percentages, not pixels).
#
# Quality is deliberately low-ish: the sprite is only ever visible while the
# pointer is moving, and FaceTracker layers the crisp 512px tile on top once the
# pointer comes to rest.

set -euo pipefail

# Force C locale: under e.g. nl_NL, printf/awk emit "-15,0" and the tile names
# (which use "." -> "p") would never match.
export LC_ALL=C

cd "$(dirname "$0")/.."

TILE_SIZE="${1:-512}"
QUALITY=75

case "$TILE_SIZE" in
  # The 256px tiles are build input only and live outside public/.
  256) TILE_DIR="tools/face-tiles" ;;
  # The 512px tiles stay in public/ because FaceTracker fetches one at rest.
  512) TILE_DIR="public/images/faces" ;;
  *) echo "error: tile size must be 256 or 512, got '$TILE_SIZE'" >&2; exit 1 ;;
esac

OUT="src/assets/images/faces/face-sprite-13x13-${TILE_SIZE}.webp"
EXPECTED=$((TILE_SIZE * 13))

command -v magick >/dev/null || { echo "error: ImageMagick (magick) not found" >&2; exit 1; }

list=$(mktemp)
trap 'rm -f "$list"' EXIT

# Emit the 169 tile paths in sprite order. sanitize() mirrors the component:
# -15.0 -> "m15p0", 2.5 -> "2p5".
awk -v dir="$TILE_DIR" -v sz="$TILE_SIZE" '
  function sanitize(v,   s) { s = sprintf("%.1f", v); sub(/-/, "m", s); sub(/\./, "p", s); return s }
  BEGIN {
    for (r = 12; r >= 0; r--)                 # py from +15 down to -15 (top -> bottom)
      for (c = 0; c <= 12; c++)               # px from -15 up to +15   (left -> right)
        printf "%s/gaze_px%s_py%s_%s.webp\n", dir, sanitize(-15 + c * 2.5), sanitize(-15 + r * 2.5), sz
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
[ "$dims" = "${EXPECTED}x${EXPECTED}" ] || {
  echo "error: expected ${EXPECTED}x${EXPECTED}, got $dims" >&2; exit 1; }

echo "wrote $OUT  ($dims, $(du -h "$OUT" | cut -f1))"
