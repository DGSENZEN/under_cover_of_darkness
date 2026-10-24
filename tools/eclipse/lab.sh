#!/usr/bin/env bash
# The Eclipse city's style lab pieces (docs/superpowers/plans/2026-10-09-eclipse-style-lab.md):
# each piece modelled by its script in Blender, its atlas baked, exported to assets/eclipse/lab/
# and held to the geometry gate; then Godot imports what changed.
#
#   tools/eclipse/lab.sh kiosk|arcade_bay   that piece (exits non-zero if the gate fails)
#   tools/eclipse/lab.sh street_kit         a Zócalo kit, into assets/eclipse/kit/
#   tools/eclipse/lab.sh all                every piece
#   tools/eclipse/lab.sh joints <piece>     close-ups of the card's joints -> /tmp/eclipse-joints/
#   tools/eclipse/lab.sh test               the gate's own tests
set -euo pipefail

BLENDER=${BLENDER:-/Applications/Blender.app/Contents/MacOS/Blender}
GODOT=${GODOT:-/Users/tinkertailorr/Desktop/Godot.app/Contents/MacOS/Godot}
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
PIECES="kiosk arcade_bay stall"
# The Zócalo's kits (one atlas each, exported to assets/eclipse/kit/).
KITS="street_kit canal_kit bridge_stone bridge_steel furniture_kit trade_kit uncanny_kit bound_god figures_kit trees_kit scene_kit drift_kit underground_ground underground_services underground_furniture underground_floor underground_walls underground_vault underground_uncanny library_room library_corner library_shelves library_books library_ward"

piece() {
  # The user's vertex-paint strokes read from the piece's last .blend first;
  # if that fails the piece is not rebuilt, since the rebuild would save over
  # the only copy of the strokes.
  if [ -f "$ROOT/assets/eclipse/source/$1.blend" ]; then
    local log
    log="$("$BLENDER" -b "$ROOT/assets/eclipse/source/$1.blend" --python-exit-code 1 --python "$HERE/harvest.py" -- "$1" 2>&1)" || {
      echo "$log" | grep -E "^harvest|Error|Traceback" >&2
      echo "lab.sh: reading $1's vertex paint failed; not rebuilding it (its .blend holds strokes not yet saved)" >&2
      return 1
    }
    echo "$log" | grep -E "^harvest" || true
  fi
  "$BLENDER" -b --factory-startup --python "$HERE/$1.py" 2>&1 | grep -E "^$1:|Error|Traceback|line [0-9]+" || true
  test -f "$ROOT/assets/eclipse/lab/$1.glb" || test -f "$ROOT/assets/eclipse/kit/$1.glb"
}

import() {
  # Godot imports the new glTF and maps; its --import can hang after importing
  # while it reopens the editor's layout, so it gets 240 s and is then let go.
  perl -e 'alarm 240; exec @ARGV' "$GODOT" --headless --path "$ROOT" --import > "${TMPDIR:-/tmp}/eclipse-import.log" 2>&1 || true
}

case "${1:-}" in
  test) python3 "$HERE/test_gate.py"; python3 "$HERE/test_weather_rules.py"; python3 "$HERE/test_street_dims.py"; "$HERE/test_lab_sh.sh"
    "$BLENDER" -b --factory-startup --python-exit-code 1 --python "$HERE/test_weather_bpy.py" 2>&1 | grep -E "^(FAIL|ERROR)|^Ran|^OK|FAILED|Error"
    "$BLENDER" -b --factory-startup --python-exit-code 1 --python "$HERE/test_kit_bpy.py" 2>&1 | grep -E "^(FAIL|ERROR)|^Ran|^OK|FAILED|Error" ;;
  joints)
    mkdir -p /tmp/eclipse-joints
    "$BLENDER" -b --factory-startup --python "$HERE/joints.py" -- "${2:?a piece}" 2>&1 | grep -E "^joints|Error|Traceback" || true ;;
  all) for p in $PIECES $KITS; do piece "$p"; done; import ;;
  "") echo "lab.sh <piece>|all|joints <piece>|test" >&2; exit 2 ;;
  *) piece "$1"; import ;;
esac
