#!/usr/bin/env bash
# The skyline round the showcase yard (tools/skyline/skyline.py), modelled and
# rendered in headless Blender to assets/sky/skyline.png; or another map's
# (city: the city on the rock's) to assets/sky/skyline_<scene>.png.
#   tools/skyline/skyline.sh
#   tools/skyline/skyline.sh city
set -euo pipefail

BLENDER=${BLENDER:-/Applications/Blender.app/Contents/MacOS/Blender}
HERE="$(cd "$(dirname "$0")" && pwd)"
SCENE="${1:-yard}"
OUT="$HERE/../../assets/sky/skyline.png"

if [ "$SCENE" != "yard" ]; then
  OUT="$HERE/../../assets/sky/skyline_$SCENE.png"
fi

mkdir -p "$(dirname "$OUT")"
"$BLENDER" -b --factory-startup --python-exit-code 1 --python "$HERE/skyline.py" -- "$OUT" "$SCENE"
rm -f "$OUT.raw.png"
echo "skyline: $OUT"
