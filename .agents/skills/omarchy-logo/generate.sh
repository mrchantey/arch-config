#!/usr/bin/env bash
# Generate a 3840x2160 print sheet of six colorized Omarchy logos.
#
# Usage:  generate.sh <name>
#   Reads  <script-dir>/<name>.json   (a JSON array of up to 6 variants,
#          each variant being an array of hex colors applied left-to-right
#          across the logo as an even horizontal gradient).
#   Writes ~/Pictures/assets/omarchy-logo/<name>.png
#
# The base logo (white glyphs on transparent) is expected at
#   ~/Pictures/assets/omarchy-logo/template.png
# (~/Pictures/assets mirrors the pictures/ prefix of the assets bucket, see `just pull-assets`)
# and is downloaded from S3 if missing.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PICTURES="$HOME/Pictures/assets"

NAME="${1:?usage: generate.sh <name>   (expects <name>.json next to this script)}"
CONFIG="$SCRIPT_DIR/$NAME.json"
[[ -f "$CONFIG" ]] || { echo "error: config not found: $CONFIG" >&2; exit 1; }

LOGO="$PICTURES/omarchy-logo/template.png"
if [[ ! -f "$LOGO" ]]; then
  echo "base logo missing, downloading..."
  mkdir -p "$(dirname "$LOGO")"
  curl -fsSL "https://arch-config--shared--assets.s3.us-west-2.amazonaws.com/pictures/omarchy-logo/template.png" -o "$LOGO"
fi

OUT_DIR="$PICTURES/omarchy-logo"
mkdir -p "$OUT_DIR"
OUT="$OUT_DIR/$NAME.png"

# --- canvas / grid geometry -------------------------------------------------
CW=3840; CH=2160          # print sheet
COLS=2;  ROWS=4           # eight logos, 2 columns x 4 rows
PAD=140                   # padding inside each cell
CELL_W=$((CW / COLS))
CELL_H=$((CH / ROWS))
LOGO_W=$((CELL_W - 2 * PAD))

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# Trimmed white logo -> use its alpha as the glyph mask.
magick -quiet "$LOGO" -trim +repage -strip "$TMP/mask.png"
read -r LW LH < <(identify -format "%w %h\n" "$TMP/mask.png")
LOGO_H=$(( LOGO_W * LH / LW ))

VARIANTS=$(jq 'length' "$CONFIG")
MAX=$((COLS * ROWS))
(( VARIANTS > MAX )) && echo "note: $VARIANTS variants defined, only first $MAX used"

# Build each colored logo, then compose them all in one pipeline. A single
# invocation avoids PNG round-trips that would silently downgrade the canvas
# to grayscale before the first color layer promotes it.
compose_args=()
for (( i = 0; i < VARIANTS && i < MAX; i++ )); do
  mapfile -t COLORS < <(jq -r ".[$i][]" "$CONFIG")
  N=${#COLORS[@]}
  (( N == 0 )) && { echo "skipping empty variant $i"; continue; }

  # Solid equal-height horizontal bars, top to bottom, one per color (no
  # gradient): stack the colors as a 1xN column, then nearest-neighbour scale
  # to the logo size so each band stays a hard, flat fill.
  grad_args=()
  for c in "${COLORS[@]}"; do grad_args+=( -size 1x1 "xc:$c" ); done
  magick "${grad_args[@]}" -append \
    -scale "${LOGO_W}x${LOGO_H}!" "$TMP/grad.png"

  # Punch the glyph shape (mask alpha) into the gradient.
  magick "$TMP/grad.png" \
    \( "$TMP/mask.png" -resize "${LOGO_W}x${LOGO_H}!" -alpha extract \) \
    -compose CopyOpacity -composite "$TMP/logo_$i.png"

  col=$(( i % COLS )); row=$(( i / COLS ))
  x=$(( col * CELL_W + (CELL_W - LOGO_W) / 2 ))
  y=$(( row * CELL_H + (CELL_H - LOGO_H) / 2 ))

  compose_args+=( "$TMP/logo_$i.png" -geometry "+${x}+${y}" -compose over -composite )
done

magick -size "${CW}x${CH}" xc:none "${compose_args[@]}" \
  -strip -depth 8 -type TrueColorAlpha "$OUT"
echo "wrote $OUT"
