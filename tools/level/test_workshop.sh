#!/usr/bin/env bash
# The workshops' round trip in Blender (workshop.py -> your edits -> yours.py
# -> kit.py and kit_recipes), in a scratch folder: an edited mesh reaches
# the kit with the kit's plain materials and no photos; colliders moved and
# added reach the recipes; an untouched piece stays the generator's; a
# rebuilt workshop keeps your edits and reads back the same; a piece whose
# generator changed under your edit is named; reverting gives it back; the
# same piece edited in two workshops is refused.
#
#   tools/level/test_workshop.sh
set -euo pipefail

BLENDER=${BLENDER:-/Applications/Blender.app/Contents/MacOS/Blender}
HERE="$(cd "$(dirname "$0")" && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

export LEVEL_YOURS="$TMP/yours.json"
export LEVEL_WORKSHOP_DIR="$TMP"
export LEVEL_WORKSHOP_GROUPS="Golden tower (lighthouse),Sea fort"
W="$TMP/workshop_harbour.blend"

blender() {
  "$BLENDER" -b --factory-startup --python-exit-code 1 "$@" > "$TMP/log" 2>&1 || { cat "$TMP/log"; echo "FAIL: blender $*"; exit 1; }
}

on() {  # on <file> <python>: run python in the opened file
  local file=$1; shift
  "$BLENDER" -b "$file" --python-exit-code 1 --python-expr "$*" > "$TMP/log" 2>&1 || { cat "$TMP/log"; echo "FAIL: on $file"; exit 1; }
  grep "^RESULT" "$TMP/log" || true
}

check() {  # check <what> <python test, exits non-zero to fail>
  local what=$1; shift
  if python3 -c "$*"; then echo "ok   $what"; else echo "FAIL $what"; exit 1; fi
}

workshop() { LEVEL_WORKSHOP_OUT="$1" blender --python "$HERE/workshop.py" -- harbour; }
harvest() { blender --python "$HERE/yours.py" -- "$@" --out "$LEVEL_YOURS"; }

workshop "$W"
check "the workshop is written" "import os; assert os.path.getsize('$W') > 1000"

# The file: each building's collections, the pieces locked in place, the
# colliders hidden children of their piece, no photo packed in.
on "$W" "
import bpy, json
names = {c.name for c in bpy.data.collections}
need = {'Golden tower (lighthouse)', 'Golden tower (lighthouse) · building', 'Golden tower (lighthouse) · kit', 'Sea fort · colliders'}
assert need <= names, need - names
placed = bpy.data.objects['gold_stage_1.001']
assert placed.lock_location[0] and placed.data is bpy.data.objects['gold_stage_1'].data
boxes = [o for o in bpy.data.objects if o.get('collider_of') == 'fort_tower']
assert boxes and all(b.parent is bpy.data.objects['fort_tower'] and b.display_type == 'WIRE' for b in boxes)
assert not any(i.packed_file for i in bpy.data.images)
print('RESULT colliders', len(boxes))
"
FORT_COLS=$(grep "^RESULT colliders" "$TMP/log" | awk '{print $3}')

harvest "$W"
check "an untouched workshop has nothing yours" "import json; assert json.load(open('$LEVEL_YOURS'))['pieces'] == {}"

# Edits: gold_stage_3's top vertex raised a metre, a face given lioz;
# fort_tower's first collider moved and turned, and one more added.
on "$W" "
import bpy, math
from mathutils import Vector, Matrix
mesh = bpy.data.meshes['kit_gold_stage_3']
top = max(mesh.vertices, key=lambda v: v.co.z)
top.co.z += 1.0
if 'lioz' not in [m.name for m in mesh.materials]:
    mesh.materials.append(bpy.data.materials['lioz'])
mesh.polygons[0].material_index = len(mesh.materials) - 1
first = bpy.data.objects['fort_tower collider 1']
at = first.matrix_basis.translation.copy()
first.matrix_basis = Matrix.Translation(at + Vector((1.0, 0.0, 0.0))) @ Matrix.Rotation(math.radians(30), 4, 'Z') @ Matrix.Translation(-at) @ first.matrix_basis
extra = first.copy()
bpy.context.scene.collection.objects.link(extra)
extra.matrix_basis = Matrix.Translation(Vector((0.0, 0.0, 2.0))) @ first.matrix_basis
extra['surface'] = 'wood'
bpy.ops.wm.save_mainfile()
"
harvest "$W"
check "your mesh and your colliders are read back, nothing else" "
import json; y = json.load(open('$LEVEL_YOURS'))['pieces']
assert set(y) == {'gold_stage_3', 'fort_tower'}, set(y)
assert y['gold_stage_3']['mesh'] and y['gold_stage_3']['file'] == 'workshop_harbour.blend' and y['gold_stage_3']['cols'] is None
assert not y['fort_tower']['mesh'] and len(y['fort_tower']['cols']) == $FORT_COLS + 1
assert y['fort_tower']['cols'][-1][6] == 'wood'
"
check "the recipes take your colliders" "
import sys; sys.path.insert(0, '$HERE'); import kit_recipes as k, geo
cols = k.PIECES['fort_tower']['cols']; assert len(cols) == $FORT_COLS + 1 and k.PIECES['fort_tower'].get('yours_cols')
assert k.PIECES['gold_stage_3']['yours_mesh'] == 'workshop_harbour.blend'
# (Moved a metre east and turned 30 degrees about Blender's z: Godot's y.)
import json, os, subprocess
fresh = json.loads(subprocess.check_output([sys.executable, '-c', 'import sys, json; sys.path.insert(0, \"$HERE\"); import kit_recipes as k; print(json.dumps(k.PIECES[\"fort_tower\"][\"cols\"][0]))'],
                                           env=dict(os.environ, LEVEL_YOURS='off')))
assert abs(cols[0][0] - fresh[0] - 1.0) < 1e-3, (cols[0], fresh)
assert abs(((cols[0][7] - fresh[7]) % 360.0) - 30.0) < 1e-3, (cols[0], fresh)
"

# The kit: your mesh, its slots the kit's plain materials, no photos;
# fort_bastion the generator's.
LEVEL_KIT_OUT="$TMP/kit.blend" LEVEL_KIT_ONLY=gold_stage_3,fort_bastion blender --python "$HERE/kit.py"
on "$TMP/kit.blend" "
import bpy, sys; sys.path.insert(0, '$HERE'); import workshop
mesh = bpy.data.meshes['kit_gold_stage_3']
names = [m.name for m in mesh.materials]
assert 'lioz' in names and not any('.' in n or n.startswith('__ws_') for n in names), names
assert not bpy.data.images, list(bpy.data.images)
assert not any(m.use_nodes and any(n.type == 'TEX_IMAGE' for n in m.node_tree.nodes) for m in bpy.data.materials)
print('RESULT kit', workshop.mesh_hash(mesh), workshop.mesh_hash(bpy.data.meshes['kit_fort_bastion']))
"
KIT_GOLD=$(grep "^RESULT kit" "$TMP/log" | awk '{print $3}')
KIT_BASTION=$(grep "^RESULT kit" "$TMP/log" | awk '{print $4}')
on "$W" "
import bpy, sys; sys.path.insert(0, '$HERE'); import workshop
print('RESULT ws', workshop.mesh_hash(bpy.data.meshes['kit_gold_stage_3']), bpy.data.meshes['kit_fort_bastion']['kit_base'])
"
WS_GOLD=$(grep "^RESULT ws" "$TMP/log" | awk '{print $3}')
WS_BASTION=$(grep "^RESULT ws" "$TMP/log" | awk '{print $4}')
check "the kit's gold_stage_3 is your mesh" "assert '$KIT_GOLD' == '$WS_GOLD'"
check "the kit's fort_bastion is the generator's" "assert '$KIT_BASTION' == '$WS_BASTION'"

# The level links the kit's meshes by name: the harbour's golden tower is
# yours (what its export writes).
cp "$HERE/../../assets/level/source/city_harbour.blend" "$TMP/city_harbour.blend"
on "$TMP/city_harbour.blend" "
import bpy, sys; sys.path.insert(0, '$HERE'); import workshop
tower = [o for o in bpy.data.objects if o.get('kit_piece') == 'gold_stage_3']
assert tower and tower[0].data.library is not None
print('RESULT level', workshop.mesh_hash(tower[0].data))
"
check "the level's golden tower is your mesh" "assert '$(grep '^RESULT level' "$TMP/log" | awk '{print $3}')' == '$WS_GOLD'"

# Rebuilt: your edits kept, read back the same.
cp "$LEVEL_YOURS" "$TMP/before.json"
workshop "$W"
on "$W" "
import bpy, sys; sys.path.insert(0, '$HERE'); import workshop
print('RESULT again', workshop.mesh_hash(bpy.data.meshes['kit_gold_stage_3']))
assert 'Changed under your edits' not in bpy.data.collections
"
check "a rebuilt workshop keeps your mesh" "assert '$(grep '^RESULT again' "$TMP/log" | awk '{print $3}')' == '$WS_GOLD'"
harvest "$W"
check "and reads back the same" "import json; a = json.load(open('$TMP/before.json')); b = json.load(open('$LEVEL_YOURS')); assert a == b, (a, b)"

# The generator changed under your edit (its base no longer the made one's).
python3 -c "
import json; p = '$LEVEL_YOURS'; y = json.load(open(p)); y['pieces']['gold_stage_3']['base'] = 'older'; json.dump(y, open(p, 'w'))"
LEVEL_WORKSHOP_OUT="$W" "$BLENDER" -b --factory-startup --python-exit-code 1 --python "$HERE/workshop.py" -- harbour > "$TMP/log" 2>&1
check "a piece changed under your edit is named" "assert 'gold_stage_3: its generator has changed' in open('$TMP/log').read()"
on "$W" "
import bpy
assert 'gold_stage_3' in bpy.data.collections['Changed under your edits'].objects
"

# The same piece edited in a second workshop is refused.
cp "$W" "$TMP/workshop_other.blend"
on "$TMP/workshop_other.blend" "
import bpy
bpy.data.meshes['kit_gold_stage_3']['kit_base'] = 'something else'
bpy.data.meshes['kit_gold_stage_3'].pop('kit_from', None)
bpy.ops.wm.save_mainfile()
"
if "$BLENDER" -b --factory-startup --python-exit-code 1 --python "$HERE/yours.py" -- "$W" "$TMP/workshop_other.blend" --out "$TMP/both.json" > "$TMP/log" 2>&1; then
  echo "FAIL a piece edited in two workshops was taken"; exit 1
fi
check "a piece edited in two workshops is refused" "assert 'edited in both' in open('$TMP/log').read()"

# Reverted: given back to the generator.
on "$W" "
import bpy
bpy.data.meshes['kit_gold_stage_3']['kit_revert'] = 1
bpy.ops.wm.save_mainfile()
"
harvest "$W"
check "a reverted piece is no longer yours" "import json; y = json.load(open('$LEVEL_YOURS'))['pieces']; assert 'gold_stage_3' not in y and 'fort_tower' in y, y"
workshop "$W"
on "$W" "
import bpy
m = bpy.data.meshes['kit_gold_stage_3']
assert m['kit_base'] == m['kit_generated'] and not m.get('kit_revert')
"
echo "ok   reverted: the workshop rebuilt it from its generator"

# Whole districts, untouched, read back nothing (a row two kilometres down
# the file, glass that never occludes: neither is an edit).
rm -f "$LEVEL_YOURS"
for district in harbour old_town; do
  LEVEL_WORKSHOP_GROUPS= LEVEL_WORKSHOP_OUT="$TMP/workshop_$district.blend" blender --python "$HERE/workshop.py" -- "$district"
done
harvest "$TMP/workshop_harbour.blend" "$TMP/workshop_old_town.blend"
check "whole untouched districts have nothing yours" "import json; y = json.load(open('$LEVEL_YOURS'))['pieces']; assert y == {}, sorted(y)"
echo "workshop round trip: all passed"
