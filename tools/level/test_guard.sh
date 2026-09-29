#!/usr/bin/env bash
# The build's guard over a hand-edited .blend (the level is the user's once
# built): the fixture built into a scratch folder, built again (unedited: it
# may be), a piece moved in Blender and built again (refused), then with
# --force (built over).
#   tools/level/test_guard.sh
set -uo pipefail

BLENDER=${BLENDER:-/Applications/Blender.app/Contents/MacOS/Blender}
HERE="$(cd "$(dirname "$0")" && pwd)"
scratch=$(mktemp -d)
export LEVEL_SOURCE="$scratch"
passed=0
failed=0

check() {
  if [ "$2" = "yes" ]; then
    passed=$((passed + 1)); echo "PASS  $1"
  else
    failed=$((failed + 1)); echo "FAIL  $1"
  fi
}

"$HERE/level.sh" build fixture > "$scratch/log" 2>&1 && ok=yes || ok=no
check "the fixture builds into the scratch folder" $ok
"$HERE/level.sh" build fixture >> "$scratch/log" 2>&1 && ok=yes || ok=no
check "an unedited level is built again" $ok
"$BLENDER" -b "$scratch/fixture.blend" --python-expr \
  "import bpy; o = [o for o in bpy.data.objects if 'kit_piece' in o.keys()][0]; o.location.x += 1.0; bpy.ops.wm.save_mainfile()" >> "$scratch/log" 2>&1
"$HERE/level.sh" build fixture >> "$scratch/log" 2>&1 && ok=no || ok=yes
check "an edited level is not built over" $ok
"$HERE/level.sh" build fixture --force >> "$scratch/log" 2>&1 && ok=yes || ok=no
check "--force builds over it" $ok
"$BLENDER" -b "$scratch/fixture.blend" --python-expr \
  "import bpy; o = [o for o in bpy.data.objects if o.get('terrain')][0]; o.data.vertices[0].co.z += 0.5; bpy.ops.wm.save_mainfile()" >> "$scratch/log" 2>&1
"$HERE/level.sh" build fixture >> "$scratch/log" 2>&1 && ok=no || ok=yes
check "a sculpted terrain is not built over" $ok
echo "== guard: $passed pass, $failed fail"
[ "$failed" -eq 0 ] && rm -rf "${scratch:?}"
[ "$failed" -eq 0 ]
