#!/usr/bin/env bash
# The props (tools/props): light fixtures built in Blender, headless.
#
#   tools/props/props.sh flames               the effect sheets (assets/vfx/)
#
# Exits non-zero when a step fails.
set -euo pipefail

BLENDER=${BLENDER:-/Applications/Blender.app/Contents/MacOS/Blender}
HERE="$(cd "$(dirname "$0")" && pwd)"

verb=${1:-}
shift || true

case "$verb" in
  flames)
    exec "$BLENDER" -b --factory-startup --python-exit-code 1 --python "$HERE/flames.py" -- "${1:-all}"
    ;;
  *)
    sed -n '2,6p' "$0"
    exit 1
    ;;
esac
