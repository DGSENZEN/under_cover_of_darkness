#!/usr/bin/env bash
# Our own effect sheets and meshes (the effects plan, Task 2):
#   tools/vfx/vfx.sh plume|puff|fire     a Mantaflow sim rendered and packed into assets/vfx/
#   tools/vfx/vfx.sh sprites             sparks and sigil strokes, drawn (assets/vfx/)
#   tools/vfx/vfx.sh drift               the drift kit's petals and leaves (assets/eclipse/kit/)
#   tools/vfx/vfx.sh all                 every one
set -e
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
BLENDER=${BLENDER:-/Applications/Blender.app/Contents/MacOS/Blender}

sim() {
  local frames
  frames="$(mktemp -d "${TMPDIR:-/tmp}/vfx_$1.XXXXXX")"
  "$BLENDER" -b --factory-startup --python "$HERE/sim_render.py" -- "$1" "$frames" 2>&1 | grep -E "^sim_render|Error|Traceback" || true
  python3 "$HERE/pack_sheet.py" "$1" "$frames"
}

case "${1:-}" in
  plume|puff|fire) sim "$1" ;;
  sprites) python3 "$HERE/sprites_2d.py" ;;
  drift) "$ROOT/tools/eclipse/lab.sh" drift_kit ;;
  all) for k in plume puff fire; do sim "$k"; done; python3 "$HERE/sprites_2d.py"; "$ROOT/tools/eclipse/lab.sh" drift_kit ;;
  *) echo "vfx.sh plume|puff|fire|sprites|drift|all" >&2; exit 2 ;;
esac
