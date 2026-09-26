"""The geometry rules on a source .blend, nothing written (spec §6.7).

    tools/wardrobe/wardrobe.sh check watchman

Budget (with the heaviest head and headgear it can wear), weights, UVs,
joints and hidden body; the textures are checked when they exist (export).
Exit code 1 and every message when anything is wrong.
"""

import json
import math
import os
import sys

# No __pycache__ beside the tools (Blender would write one each run).
sys.dont_write_bytecode = True
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import bpy  # noqa: E402
from mathutils import Vector  # noqa: E402

import common  # noqa: E402
import recipes  # noqa: E402
import validate  # noqa: E402

# Until a kind's head and headgear are exported, they are counted at their
# budget: ~400 for a head, ~600 for hair, beard and headgear together.
PARTS_UNTIL_EXPORTED = 1000


def main():
    target, _ = common.args()

    if target == "hair" and not recipes.HAIR:
        print("wardrobe: no hair in the recipes: nothing to check")
        return

    path = common.SOURCE / ("%s.blend" % target)

    if not path.exists() or bpy.data.filepath != str(path):
        common.fail("no source/%s.blend" % target)

    if target in recipes.KINDS:
        messages = check_kind(recipes.KINDS[target])
    elif target == "heads":
        messages = check_parts("Head_", "heads")
    elif target == "hair":
        messages = check_parts("Hair_", "hair")
    elif target == "headgear":
        messages = check_parts("Gear_", "headgear")
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
                          combined_tris=combined, budget=common.budget_of(recipe["kind"]), bare=set(recipe["bare"]))


def check_parts(prefix, folder):
    """Each head (or headgear piece) in this file: its budget, weights, UVs
    and joints; a head's neck edge must sit under every collar it can wear."""
    armature = bpy.data.objects.get("Armature")
    parts = [obj for obj in bpy.data.objects if obj.name.startswith(prefix) and obj.type == "MESH"]
    messages = [] if parts else ["build: nothing called %s* in this file" % prefix]
    joints = reference_joints("male")

    for obj in parts:
        cap = common.part_limit(folder, obj.name[len(prefix):])
        found = validate.check(obj, armature=armature, reference_joints=joints, combined_tris=common.tri_count(obj), budget=cap)
        messages += ["%s %s" % (obj.name, m) for m in found]
        print("wardrobe: %s %d triangles (limit %d)" % (obj.name, common.tri_count(obj), cap))

        piece = recipes.HEADGEAR.get(obj.name[len(prefix):], {}) if prefix == "Gear_" else {}

        if piece.get("covers_head"):
            messages += ["%s %s" % (obj.name, m) for m in encloses(obj, piece, armature.data.bones["Head"].head_local)]

        if piece.get("over") and bpy.data.objects.get("Gear_" + piece["over"]) is not None:
            under = bpy.data.objects["Gear_" + piece["over"]]
            messages += ["%s %s" % (obj.name, m) for m in fit(obj, under, armature.data.bones["Head"].head_local,
                                                              piece["clearance"], piece["rest"])]

        if prefix == "Head_":
            lowest = min(v.co.z for v in obj.data.vertices)

            for kind, recipe in recipes.KINDS.items():
                if obj.name[len(prefix):] in recipe["options"]["faces"]:
                    top = collar_top(kind)

                    if top is not None and lowest > top - 0.01:
                        messages.append("seam: %s's neck edge (%.3f) is not under %s's collar (top %.3f)" % (obj.name, lowest, kind, top))

    return messages


def encloses(obj, piece, pivot):
    """A hood must hold every head it can go over: each head vertex of his
    skull (from just under `rigid_above`; its face opening aside) at least
    `inside` (metres) under it, looking out from the middle of his head.
    Flat faces of a hood cut too coarse sag through the head between their
    corners."""
    path = common.SOURCE / "heads.blend"

    if not path.exists():
        return []

    # The heads by their objects' names (their meshes keep the body's).
    with bpy.data.libraries.load(str(path)) as (source, target):
        target.objects = [name for name in source.objects if name.startswith("Head_")]

    heads = [o for o in target.objects if o is not None and o.type == "MESH"]

    if not heads:
        return ["encloses: no heads in heads.blend to check"]

    tree = common.bvh([obj])
    centre = pivot + Vector((0.0, 0.0, 0.1))
    hole = piece["opening"]
    worst, where = 1.0, None

    for head in heads:
        mesh = head.data

        for vertex in mesh.vertices:
            p = vertex.co

            # His skull, from just under his ears up (lower down, his neck
            # is the cape's to cover).
            if p.z < piece["rigid_above"] - 0.02:
                continue

            if abs(p.x) < hole["x"] + 0.015 and hole["from_z"] - 0.015 < p.z < hole["to_z"] + 0.015 and p.y < -0.02:
                continue

            d = (p - centre).normalized()
            hit = common.outer_hit(tree, centre, d, 0.4)
            # Nothing on his head's side (only the far side, or nothing at
            # all): the head is bare there.
            reach = (hit - centre).dot(d) if hit is not None else -1.0
            margin = reach - (p - centre).length

            if margin < worst:
                worst, where = margin, p.copy()

        bpy.data.objects.remove(head)
        bpy.data.meshes.remove(mesh)

    if where is not None and worst < piece["inside"]:
        return ["encloses: the head comes %.1f mm from its surface at (%.3f, %.3f, %.3f) (at least %.1f mm under it)"
                % (worst * 1000, where.x, where.y, where.z, piece["inside"] * 1000)]

    return []


def fit(obj, under, pivot, clearance, rest):
    """How a piece sits on what it goes over: along rays from the middle of
    his head over his crown (25-85 degrees up, every 30 degrees round), the
    gap between them. Never under `clearance` (it would cut in), never over
    `rest` (it would float, oversized)."""
    outer, inner = common.bvh([obj]), common.bvh([under])
    centre = pivot + Vector((0.0, 0.0, 0.1))
    gaps = []

    for elevation in (25, 45, 65, 85):
        for azimuth in range(0, 360, 30):
            e, a = math.radians(elevation), math.radians(azimuth)
            direction = Vector((math.cos(e) * math.sin(a), -math.cos(e) * math.cos(a), math.sin(e)))
            over, below = outer.ray_cast(centre, direction, 0.5), inner.ray_cast(centre, direction, 0.5)

            if over[0] is not None and below[0] is not None:
                gaps.append(over[3] - below[3])

    if not gaps:
        return ["fit: never over %s" % under.name]

    messages = []

    if min(gaps) < clearance - 0.001:
        messages.append("fit: cuts into %s (gap %.1f mm, at least %.1f)" % (under.name, min(gaps) * 1000, clearance * 1000))

    if max(gaps) > rest:
        messages.append("fit: stands %.1f cm off %s (at most %.1f)" % (max(gaps) * 100, under.name, rest * 100))

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
