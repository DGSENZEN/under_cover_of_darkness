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

    if target in common.PART_TARGETS and not common.parts_of(common.part_table(common.PART_TARGETS[target][0]),
                                                              common.PART_TARGETS[target][1]):
        print("wardrobe: no %s %s in the recipes: nothing to check" % common.PART_TARGETS[target][::-1])
        return

    path = common.SOURCE / ("%s.blend" % target)

    if not path.exists() or bpy.data.filepath != str(path):
        common.fail("no source/%s.blend" % target)

    if target in recipes.KINDS:
        messages = check_kind(recipes.KINDS[target])
    elif target in common.PART_TARGETS:
        folder, body = common.PART_TARGETS[target]
        messages = check_parts("Head_" if folder == "heads" else "Hair_", folder, body)
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
    print("wardrobe: %s outfit %d triangles, %d with head, hair and headgear (limit %d)"
          % (recipe["kind"], common.tri_count(outfit), combined, common.budget_of(recipe["kind"])))
    return foreign_parts(recipe) + validate.check(outfit, armature=armature, reference_joints=reference_joints(recipe["body"]),
                                                  cloth_bones=cloth, combined_tris=combined,
                                                  budget=common.budget_of(recipe["kind"]), bare=set(recipe["bare"]))


def check_parts(prefix, folder, body="male"):
    """Each head (or hair or headgear piece) in this file, made for `body`:
    its budget, weights, UVs and joints (against that body's skeleton); a
    head's neck edge must sit under every collar it can wear."""
    armature = bpy.data.objects.get("Armature")
    parts = [obj for obj in bpy.data.objects if obj.name.startswith(prefix) and obj.type == "MESH"]
    messages = [] if parts else ["build: nothing called %s* in this file" % prefix]
    joints = reference_joints(body)

    wanted = recipes.HEADGEAR if prefix == "Gear_" else common.parts_of(common.part_table(folder), body)
    messages += ["build: no %s%s in this file (build %s again)" % (prefix, name, folder)
                 for name in wanted if bpy.data.objects.get(prefix + name) is None]

    chains = json.loads(bpy.context.scene.get("wardrobe_chains", "[]"))

    for obj in parts:
        cap = common.part_limit(folder, obj.name[len(prefix):])
        # A piece's own cloth bones (a hood's tail) are its to be weighted to.
        cloth = [b for c in chains if c.get("piece") == obj.name[len(prefix):] for b in c["bones"]]
        found = validate.check(obj, armature=armature, reference_joints=joints, cloth_bones=cloth,
                               combined_tris=common.tri_count(obj), budget=cap)
        messages += ["%s %s" % (obj.name, m) for m in found]
        print("wardrobe: %s %d triangles (limit %d)" % (obj.name, common.tri_count(obj), cap))

        piece = recipes.HEADGEAR.get(obj.name[len(prefix):], {}) if prefix == "Gear_" else {}

        if piece.get("covers_head"):
            messages += ["%s %s" % (obj.name, m) for m in encloses(obj, piece, armature.data.bones["Head"].head_local)]

        pivot = armature.data.bones["Head"].head_local
        style = recipes.HAIR.get(obj.name[len(prefix):], {}) if prefix == "Hair_" else {}

        # Hair clears every head it may go on (how far it stands off is its
        # own business: no `rest`).
        if style:
            under = heads(body)
            messages += ["%s %s" % (obj.name, m) for m in fit(obj, under, pivot, style["clearance"], None,
                                                              style.get("fit_rays"))] if under else []
            forget(under)

        if piece.get("over") == "head":
            under = heads()
            messages += ["%s %s" % (obj.name, m) for m in fit(obj, under, pivot, piece["clearance"], piece["rest"],
                                                              piece.get("fit_rays"))] if under else []
            forget(under)
        elif piece.get("over") and bpy.data.objects.get("Gear_" + piece["over"]) is not None:
            under = [bpy.data.objects["Gear_" + piece["over"]]]
            messages += ["%s %s" % (obj.name, m) for m in fit(obj, under, pivot, piece["clearance"], piece["rest"],
                                                              piece.get("fit_rays"))]

        if prefix == "Head_":
            lowest = min(v.co.z for v in obj.data.vertices)

            for kind, recipe in recipes.KINDS.items():
                if obj.name[len(prefix):] in recipe["options"]["faces"]:
                    top = collar_top(kind)

                    if top is not None and lowest > top - 0.01:
                        messages.append("seam: %s's neck edge (%.3f) is not under %s's collar (top %.3f)" % (obj.name, lowest, kind, top))

    return messages


def heads(body="male"):
    """Every head of `body` (its heads file), brought into this file
    (forget() lets them go): what hair, hoods and helms go over."""
    path = common.SOURCE / ("%s.blend" % common.part_target("heads", body))

    if not path.exists():
        return []

    # The heads by their objects' names (their meshes keep the body's).
    with bpy.data.libraries.load(str(path)) as (source, target):
        target.objects = [name for name in source.objects if name.startswith("Head_")]

    return [o for o in target.objects if o is not None and o.type == "MESH"]


def forget(objects):
    for obj in objects:
        mesh = obj.data
        bpy.data.objects.remove(obj)
        bpy.data.meshes.remove(mesh)


def encloses(obj, piece, pivot):
    """A hood must hold every head it can go over: each head vertex of his
    skull (from just under `rigid_above`; its face opening aside) at least
    `inside` (metres) under it, looking out from the middle of his head.
    Flat faces of a hood cut too coarse sag through the head between their
    corners."""
    found = heads()

    if not found:
        return ["encloses: no heads in heads.blend to check"] if (common.SOURCE / "heads.blend").exists() else []

    tree = common.bvh([obj])
    centre = pivot + Vector((0.0, 0.0, 0.1))
    hole = piece["opening"]
    worst, where = 1.0, None

    for head in found:
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

    forget(found)

    if where is not None and worst < piece["inside"]:
        return ["encloses: the head comes %.1f mm from its surface at (%.3f, %.3f, %.3f) (at least %.1f mm under it)"
                % (worst * 1000, where.x, where.y, where.z, piece["inside"] * 1000)]

    return []


def fit(obj, unders, pivot, clearance, rest, rays=None):
    """How a piece sits on what it goes over (each of `unders` in turn: a
    helm on every head it may be worn on): along rays from the middle of his
    head (`rays`, {"elevations": [...], "azimuths": [...]} in degrees; by
    default over his crown, 25-85 up, every 30 round), the gap between them.
    Never under `clearance` (it would cut in), never over `rest` (it would
    float, oversized)."""
    rays = rays or {"elevations": [25, 45, 65, 85], "azimuths": list(range(0, 360, 30))}
    outer = common.bvh([obj])
    centre = pivot + Vector((0.0, 0.0, 0.1))
    messages = []

    for under in unders:
        inner = common.bvh([under])
        gaps = []

        for elevation in rays["elevations"]:
            for azimuth in rays["azimuths"]:
                e, a = math.radians(elevation), math.radians(azimuth)
                direction = Vector((math.cos(e) * math.sin(a), -math.cos(e) * math.cos(a), math.sin(e)))
                over, below = outer.ray_cast(centre, direction, 0.5), inner.ray_cast(centre, direction, 0.5)

                if over[0] is not None and below[0] is not None:
                    gaps.append(over[3] - below[3])

        if not gaps:
            messages.append("fit: never over %s" % under.name)
            continue

        if min(gaps) < clearance - 0.001:
            messages.append("fit: cuts into %s (gap %.1f mm, at least %.1f)" % (under.name, min(gaps) * 1000, clearance * 1000))

        if rest is not None and max(gaps) > rest:
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
    """The heaviest head, hair, beard and headgear set the kind can roll
    (common.heaviest_combination, as the export counts them), from their
    exported JSON (or their budget, until exported)."""
    heaviest = common.heaviest_combination(recipe["options"], read)
    return PARTS_UNTIL_EXPORTED if heaviest is None else heaviest


def foreign_parts(recipe):
    """Every face, hair style, beard and headgear piece a kind's options
    name that is made for another body than the kind's (on his skeleton it
    would sit at the other body's head height)."""
    body = recipe["body"]
    options = recipe["options"]
    named = [(name, recipes.HEADS.get(name, {})) for name in options.get("faces", [])]
    named += [(name, recipes.HAIR.get(name, {})) for key in ("hair", "beards") for name in options.get(key, []) if name != ""]
    named += [(name, recipes.HEADGEAR.get(name, {})) for pieces in options.get("headgear", []) for name in pieces]
    return ["options: %s is made for the %s body" % (name, part.get("body", "male"))
            for name, part in named if part.get("body", "male") != body]


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


if __name__ == "__main__":
    main()
