#!/usr/bin/env bash
# The Eclipse city's style lab pieces (docs/superpowers/plans/2026-10-09-eclipse-style-lab.md):
# each piece modelled by its script in Blender, its atlas baked, exported to assets/eclipse/lab/
# and held to the geometry gate; then Godot imports what changed.
#
#   tools/eclipse/lab.sh kiosk|arcade_bay   that piece (exits non-zero if the gate fails)
#   tools/eclipse/lab.sh all                every piece
#   tools/eclipse/lab.sh joints <piece>     close-ups of the card's joints -> /tmp/eclipse-joints/
#   tools/eclipse/lab.sh test               the gate's own tests
set -euo pipefail

BLENDER=${BLENDER:-/Applications/Blender.app/Contents/MacOS/Blender}
GODOT=${GODOT:-/Users/tinkertailorr/Desktop/Godot.app/Contents/MacOS/Godot}
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
PIECES="kiosk arcade_bay"

piece() {
  "$BLENDER" -b --factory-startup --python "$HERE/$1.py" 2>&1 | grep -E "^$1:|Error|Traceback|line [0-9]+" || true
  test -f "$ROOT/assets/eclipse/lab/$1.glb"
}

import() {
  # Godot imports the new glTF and maps; its --import can hang after importing
  # while it reopens the editor's layout, so it gets 240 s and is then let go.
  perl -e 'alarm 240; exec @ARGV' "$GODOT" --headless --path "$ROOT" --import > "${TMPDIR:-/tmp}/eclipse-import.log" 2>&1 || true
}

case "${1:-}" in
  test) python3 "$HERE/test_gate.py" ;;
  joints)
    mkdir -p /tmp/eclipse-joints
    "$BLENDER" -b --factory-startup --python "$HERE/joints.py" -- "${2:?a piece}" 2>&1 | grep -E "^joints|Error|Traceback" || true ;;
  all) for p in $PIECES; do piece "$p"; done; import ;;
  "") echo "lab.sh <piece>|all|joints <piece>|test" >&2; exit 2 ;;
  *) piece "$1"; import ;;
esac
