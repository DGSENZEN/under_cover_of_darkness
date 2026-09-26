"""The geometry rules on a source .blend, nothing written (spec §6.7).

    tools/wardrobe/wardrobe.sh check watchman

Budget (with the heaviest head and headgear it can wear), weights, UVs,
joints and hidden body; the textures are checked when they exist (export).
Exit code 1 and every message when anything is wrong.
"""

import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import bpy  # noqa: E402

import common  # noqa: E402
import recipes  # noqa: E402
import validate  # noqa: E402

# Until a kind's head and headgear are exported, they are counted at their
# budget: ~400 for a head, ~600 for hair, beard and headgear together.
PARTS_UNTIL_EXPORTED = 1000
# A head's triangles; each headgear piece's (the coif's is tighter).
HEAD_LIMIT = 450
GEAR_LIMIT = {"Gear_coif": 200}
GEAR_DEFAULT = 300


def main():
    target, _ = common.args()
    path = common.SOURCE / ("%s.blend" % target)

    if not path.exists() or bpy.data.filepath != str(path):
        common.fail("no source/%s.blend" % target)

    if target in recipes.KINDS:
        messages = check_kind(recipes.KINDS[target])
    elif target == "heads":
        messages = check_parts("Head_", HEAD_LIMIT)
    elif target == "headgear":
        messages = check_parts("Gear_", GEAR_LIMIT)
    else:
        common.fail("no rules for '%s'" % target)

    for message in messages:
        print("wardrobe: " + message)

    if messages:
        raise SystemExit(1)

    print("wardrobe: check %s OK" % target)


def check_kind(recipe):
    outfit = bpy.data.objects.get("Outfit")
    armature = bpy.data.objects.get("Armature")

    if outfit is None or armature is None:
        return ["build: no Outfit on an Armature in this file"]

    chains = json.loads(bpy.context.scene.get("wardrobe_chains", "[]"))
    cloth = [bone for chain in chains for bone in chain["bones"]]
    combined = common.tri_count(outfit) + parts_triangles(recipe)
    print("wardrobe: %s outfit %d triangles, %d with head and headgear (limit %d)"
          % (recipe["kind"], common.tri_count(outfit), combined, common.budget_of(recipe["kind"])))
    return validate.check(outfit, armature=armature, reference_joints=reference_joints(recipe["body"]), cloth_bones=cloth,
                          combined_tris=combined, budget=common.budget_of(recipe["kind"]))


def check_parts(prefix, limit):
    """Each head (or headgear piece) in this file: its budget, weights, UVs
    and joints; a head's neck edge must sit under every collar it can wear."""
    armature = bpy.data.objects.get("Armature")
    parts = [obj for obj in bpy.data.objects if obj.name.startswith(prefix) and obj.type == "MESH"]
    messages = [] if parts else ["build: nothing called %s* in this file" % prefix]
    joints = reference_joints("male")

    for obj in parts:
        cap = limit if isinstance(limit, int) else limit.get(obj.name, GEAR_DEFAULT)
        found = validate.check(obj, armature=armature, reference_joints=joints, combined_tris=common.tri_count(obj), budget=cap)
        messages += ["%s %s" % (obj.name, m) for m in found]
        print("wardrobe: %s %d triangles (limit %d)" % (obj.name, common.tri_count(obj), cap))

        if prefix == "Head_":
            lowest = min(v.co.z for v in obj.data.vertices)

            for kind, recipe in recipes.KINDS.items():
                if obj.name[len(prefix):] in recipe["options"]["faces"]:
                    top = collar_top(kind)

                    if top is not None and lowest > top - 0.01:
                        messages.append("seam: %s's neck edge (%.3f) is not under %s's collar (top %.3f)" % (obj.name, lowest, kind, top))

    return messages


def collar_top(kind):
    """How high a kind's collar stands (its source file's Outfit), or None."""
    path = common.SOURCE / ("%s.blend" % kind)
    garments = [g["name"] for g in recipes.KINDS[kind]["garments"]]

    if not path.exists() or "collar" not in garments:
        return None

    with bpy.data.libraries.load(str(path)) as (source, target):
        target.meshes = ["Outfit"] if "Outfit" in source.meshes else []

    if not target.meshes or target.meshes[0] is None:
        return None

    mesh = target.meshes[0]
    part = garments.index("collar") + 1
    parts = mesh.attributes["wr_part"].data
    top = max((mesh.vertices[i].co.z for p in mesh.polygons if parts[p.index].value == part for i in p.vertices), default=None)
    bpy.data.meshes.remove(mesh)
    return top


def parts_triangles(recipe):
    """The heaviest head plus the heaviest headgear set the kind can roll,
    from their exported JSON (or their budget, until exported)."""
    options = recipe["options"]
    heads = [read("heads/%s.json" % face) for face in options["faces"]]
    sets = [[read("headgear/%s.json" % piece) for piece in pieces] for pieces in options["headgear"]]

    if any(h is None for h in heads) or any(p is None for s in sets for p in s):
        return PARTS_UNTIL_EXPORTED

    return max(h["triangles"] for h in heads) + max((sum(p["triangles"] for p in s) for s in sets), default=0)


def read(relative):
    path = common.WARDROBE / relative
    return json.loads(path.read_text()) if path.exists() else None


def reference_joints(body):
    """The Quaternius skeleton as shipped: imported, read, and removed."""
    before = set(bpy.data.objects)
    armature, _, _ = common.import_quaternius(body)
    joints = common.joints(armature)

    for obj in [o for o in bpy.data.objects if o not in before]:
        bpy.data.objects.remove(obj)

    return joints


main()
