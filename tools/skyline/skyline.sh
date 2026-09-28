#!/usr/bin/env bash
# The skyline round the showcase yard (tools/skyline/skyline.py), modelled and
# rendered in headless Blender to assets/sky/skyline.png.
#   tools/skyline/skyline.sh
set -euo pipefail

BLENDER=${BLENDER:-/Applications/Blender.app/Contents/MacOS/Blender}
HERE="$(cd "$(dirname "$0")" && pwd)"
OUT="$HERE/../../assets/sky/skyline.png"

mkdir -p "$(dirname "$OUT")"
"$BLENDER" -b --factory-startup --python-exit-code 1 --python "$HERE/skyline.py" -- "$OUT"
rm -f "$OUT.raw.png"
echo "skyline: $OUT"
