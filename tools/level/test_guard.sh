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

# Hand work on the ground that moves no vertex: a face repainted in another
# slot, the tint painted, its surface changed.
edit_terrain() {
  "$HERE/level.sh" build fixture --force >> "$scratch/log" 2>&1
  "$BLENDER" -b "$scratch/fixture.blend" --python-expr \
    "import bpy; o = [o for o in bpy.data.objects if o.get('terrain')][0]; m = o.data; $1; bpy.ops.wm.save_mainfile()" >> "$scratch/log" 2>&1
  "$HERE/level.sh" build fixture >> "$scratch/log" 2>&1 && ok=no || ok=yes
}
edit_terrain "m.materials.append(bpy.data.materials.new('moss_paint')); m.polygons[0].material_index = len(m.materials) - 1"
check "a terrain's face repainted in another slot is not built over" $ok
edit_terrain "m.color_attributes['Tint'].data[0].color = (0.2, 0.3, 0.1, 1.0)"
check "a terrain's tint painted is not built over" $ok
edit_terrain "o['surface'] = 'wood'"
check "a terrain's surface changed is not built over" $ok
edit_terrain "o['occluder'] = 1"
check "a terrain made an occluder is not built over" $ok
# Built when the guard hashed the ground's shape only: its paint cannot be
# told, so it is not built over (and says why).
edit_terrain "import sys; sys.path.insert(0, '$HERE'); import common, read; bpy.context.scene['content_hash'] = common.content_hash(read.read(), common.SHAPE)"
grep -q "before the guard looked at the ground's paint" "$scratch/log" && [ "$ok" = yes ] && ok=yes || ok=no
check "a level built before the guard saw paint is not built over" $ok
echo "== guard: $passed pass, $failed fail"
[ "$failed" -eq 0 ] && rm -rf "${scratch:?}"
[ "$failed" -eq 0 ]
