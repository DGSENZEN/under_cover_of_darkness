"""The build's own parts (build.py, common.py), on tiny scenes.

    tools/wardrobe/wardrobe.sh test

Each case builds a little and checks what came out. Runs in a
factory-fresh Blender, headless. Exit code 1 on any failure.
"""

import math
import os
import sys

# No __pycache__ beside the tools (Blender would write one each run).
sys.dont_write_bytecode = True
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import bmesh  # noqa: E402
import bpy  # noqa: E402
from mathutils import Vector  # noqa: E402
from mathutils.bvhtree import BVHTree  # noqa: E402

import common  # noqa: E402
import testkit  # noqa: E402


def fresh():
    """An empty scene."""
    bpy.ops.wm.read_factory_settings(use_empty=True)


def armature():
    """A tiny armature: root, and pelvis above it."""
    data = bpy.data.armatures.new("Arm")
    arm = bpy.data.objects.new("Armature", data)
    bpy.context.scene.collection.objects.link(arm)
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.mode_set(mode="EDIT")
    root = data.edit_bones.new("root")
    root.head, root.tail = (0, 0, 0), (0, 0, 0.1)
    pelvis = data.edit_bones.new("pelvis")
    pelvis.head, pelvis.tail = (0, 0, 1.0), (0, 0, 1.1)
    pelvis.parent = root
    bpy.ops.object.mode_set(mode="OBJECT")
    return arm


def case_chain_bones():
    """Four points make three bones in order, the first under the parent."""
    import build

    fresh()
    arm = armature()
    names = build.chain_bones(arm, "test", "pelvis", [Vector((0, 0, 1)), Vector((0, 0, 0.8)), Vector((0, 0, 0.6)), Vector((0, 0, 0.4))])
    bones = arm.data.bones
    ok = names == ["cloth_test_1", "cloth_test_2", "cloth_test_3"] and bones["cloth_test_1"].parent.name == "pelvis" \
        and bones["cloth_test_3"].parent.name == "cloth_test_2" and all(bones[n].use_deform for n in names)
    return [] if ok else ["chain: %s" % names]


def case_limits():
    """One place says how many triangles each part may have."""
    ok = (common.part_limit("heads", "weathered"), common.part_limit("headgear", "coif"),
          common.part_limit("headgear", "kettlehat"), common.part_limit("hair", "parted")) == (450, 240, 300, 220)
    return [] if ok else ["limits"]


GREY = (0.4, 0.4, 0.4)
CLOTH = {"stiffness": 1.4, "drag": 0.7, "gravity": 1.0, "radius": 0.03}

# One of each garment type batch 1 adds, over a shell (and hose and boots,
# so no skin shows but his head and hands).
TYPES = {
    "kind": "typetest", "body": "male", "base_tris": 1300, "bare": ["head", "hand"], "belt": ("spine_01", 0.0),
    "garments": [
        {"name": "tunic", "type": "shell", "fabric": "quilted_linen", "colour": GREY, "dye": True,
         "regions": ["torso", "pelvis", "upper", "lower"], "bottom": ("thigh_l", 0.1), "sleeve_end": ("hand_l", 0.0),
         "sleeve_back": 0.016, "thickness": 0.02, "smooth": 6, "lips": ["sleeve", "bottom"]},
        {"name": "hose", "type": "shell", "fabric": "wrapped", "colour": GREY, "regions": ["pelvis", "thigh", "calf"],
         "bottom": ("calf_l", 0.6), "top": ("spine_01", 0.0), "thickness": 0.006, "smooth": 2},
        {"name": "boots", "type": "boots", "fabric": "leather", "colour": GREY, "top": ("calf_l", 0.5),
         "thickness": 0.012, "sole": 0.004, "cuff": 0, "smooth": 3},
        {"name": "gloves", "type": "mittens", "fabric": "leather", "colour": GREY, "cuff": 0.035},
        {"name": "test", "type": "skirt", "fabric": "wool", "colour": GREY, "hem": ("thigh_l", 0.35), "flare": 1.3,
         "clearance": 0.03, "bones": 1,
         "panels": {"front": [-40, 40], "back": [140, 220], "left": [45, 135], "right": [-135, -45]}},
        {"name": "mail", "type": "panels", "fabric": "mail", "colour": GREY, "width": 0.36, "hem": ("calf_l", 0.05), "bones": 2},
        {"name": "coat", "type": "tabard", "fabric": "wool", "colour": GREY, "dye": True, "over": "tunic", "proud": 0.006,
         "tuck": 0.015, "hem": ("calf_l", 0.25), "width": 0.30, "bones": 3},
        {"name": "sash", "type": "sash", "fabric": "wool", "colour": GREY, "height": 0.07, "tails": 2, "at": 60,
         "length": 0.35, "bones": 3},
        {"name": "pauldron", "type": "pauldron", "fabric": "iron", "colour": GREY, "over": "tunic", "reach": 0.14,
         "drop": 0.12, "rings": 3, "clearance": 0.012, "roll": 0.01},
        {"name": "bracer", "type": "bracer", "fabric": "leather", "colour": GREY, "bone": "lowerarm_l", "from": 0.35,
         "to": 0.85, "thickness": 0.008},
        {"name": "quiver", "type": "prop", "shape": "quiver", "fabric": "leather", "colour": GREY, "at": 110,
         "length": 0.42, "bone": "pelvis"},
        {"name": "knife", "type": "prop", "shape": "knife", "fabric": "leather", "colour": GREY, "at": 30, "bone": "pelvis",
         "fittings": {"fabric": "iron", "colour": GREY}},
    ],
    "chains": {name: CLOTH for name in ("test_front", "test_back", "test_l", "test_r", "mail_front", "mail_back",
                                        "coat_front", "coat_back", "sash_1", "sash_2", "quiver")},
    "colliders": [], "metal": [], "options": {},
}


def part_vertices(obj, part_name, recipe=TYPES):
    """The vertices of one garment of `recipe` in the built `obj`."""
    part = 1 + [g["name"] for g in recipe["garments"]].index(part_name)
    parts = obj.data.attributes["wr_part"].data
    return {v for p in obj.data.polygons if parts[p.index].value == part for v in p.vertices}


def faces_on(obj, part_name, recipe=TYPES, side=0.0):
    """The bones that move the vertices of one garment of `recipe` (each
    vertex's heaviest); with `side`, only those on his left (1) or right (-1)."""
    vertices = [v for v in part_vertices(obj, part_name, recipe) if side == 0.0 or obj.data.vertices[v].co.x * side > 1e-4]
    return {common.dominant_bone(obj, v) for v in vertices}


def hangs_off(obj, part_name, recipe=TYPES):
    """How far a prop hangs off him: the least distance from its vertices to
    anything else he wears but his props."""
    from mathutils.bvhtree import BVHTree

    props = {1 + i for i, g in enumerate(recipe["garments"]) if g["type"] == "prop"}
    parts = obj.data.attributes["wr_part"].data
    rest = [tuple(p.vertices) for p in obj.data.polygons if parts[p.index].value not in props]
    tree = BVHTree.FromPolygons([v.co.copy() for v in obj.data.vertices], rest)
    return min(tree.find_nearest(obj.data.vertices[v].co)[3] for v in part_vertices(obj, part_name, recipe))


def leans_back(obj, part_name, recipe, length, back):
    """Whether a prop hung from his belt on his left leans `back` degrees
    back, as its recipe says: its tip at least 80% of the way behind its top
    that `length` leaning `back` makes (the bodies face -y), and no nearer
    his middle than its top (not swung in across his legs). Its top and tip
    are where its vertices within 5 cm of its highest and of its lowest
    are, on average (a quiver's fletchings spread across its mouth). []
    or what is wrong."""
    points = [obj.data.vertices[v].co.copy() for v in part_vertices(obj, part_name, recipe)]
    high, low = max(p.z for p in points), min(p.z for p in points)
    top = sum((p for p in points if p.z > high - 0.05), Vector()) / sum(1 for p in points if p.z > high - 0.05)
    tip = sum((p for p in points if p.z < low + 0.05), Vector()) / sum(1 for p in points if p.z < low + 0.05)

    if tip.y - top.y < 0.8 * length * math.sin(math.radians(back)) or tip.x < top.x - 0.01:
        return ["%s runs from %s down to %s, not back" % (part_name, tuple(round(c, 3) for c in top),
                                                           tuple(round(c, 3) for c in tip))]

    return []


def bare_holes(obj, arm, bone, at=(0.3, 0.5, 0.7)):
    """Rays out from `bone` (8 ways round it, `at` those fractions of its
    length) that meet anything but his skin first: holes in a bare limb."""
    tree = BVHTree.FromPolygons([v.co.copy() for v in obj.data.vertices], [tuple(p.vertices) for p in obj.data.polygons])
    fabric = obj.data.attributes["wr_fabric"].data
    b = arm.data.bones[bone]
    axis = (b.tail_local - b.head_local).normalized()
    u = axis.orthogonal().normalized()
    v = axis.cross(u)
    holes = []

    for t in at:
        centre = b.head_local.lerp(b.tail_local, t)

        for k in range(8):
            a = k * math.pi / 4.0
            hit = tree.ray_cast(centre, u * math.cos(a) + v * math.sin(a), 0.3)

            if hit[2] is None or fabric[hit[2]].value != 0:
                holes.append("%.1f of it, %d deg" % (t, k * 45))

    return holes


def case_types():
    """Every garment type batch 1 adds builds on the male body, rides the
    bones and chains it should, and passes every export rule."""
    import json
    import tempfile
    from pathlib import Path

    import build
    import validate

    fresh()
    folder = testkit.scratch_dir("wardrobe_types_")
    common.SOURCE, common.BACKUP = folder, folder / "backup"
    before = set(bpy.data.objects)
    skeleton, _, _ = common.import_quaternius("male")
    joints = common.joints(skeleton)

    for obj in [o for o in bpy.data.objects if o not in before]:
        bpy.data.objects.remove(obj)

    build.build_kind(TYPES, True)
    scene = bpy.context.scene
    outfit, arm = bpy.data.objects["Outfit"], bpy.data.objects["Armature"]
    chains = {c["chain"]: c for c in json.loads(scene["wardrobe_chains"])}
    cloth = [bone for c in chains.values() for bone in c["bones"]]
    messages = []

    def bones(chain):
        return len(chains[chain]["bones"]) if chain in chains else 0

    if (bones("mail_front"), bones("coat_front")) != (2, 3):
        messages.append("panels: mail %d bones, coat %d (want 2, 3)" % (bones("mail_front"), bones("coat_front")))

    if not {"test_front", "test_back", "test_l", "test_r"} <= set(chains) or bones("test_front") != 1:
        messages.append("skirt: chains %s" % sorted(c for c in chains if c.startswith("test")))

    if (bones("sash_1"), bones("sash_2"), bones("quiver")) != (3, 3, 1):
        messages.append("sash/quiver: %d %d %d bones (want 3 3 1)" % (bones("sash_1"), bones("sash_2"), bones("quiver")))

    pauldrons = (faces_on(outfit, "pauldron", side=1.0), faces_on(outfit, "pauldron", side=-1.0))

    if pauldrons != ({"upperarm_l"}, {"upperarm_r"}):
        messages.append("pauldrons on %s (left) and %s (right)" % tuple(sorted(p) for p in pauldrons))

    for prop in ("quiver", "knife"):
        if hangs_off(outfit, prop) > 0.03:
            messages.append("%s hangs %.3f m off him" % (prop, hangs_off(outfit, prop)))

    # Its `back` defaults to 12 degrees.
    messages += leans_back(outfit, "quiver", TYPES, 0.42, 12)

    if faces_on(outfit, "bracer") != {"lowerarm_l"}:
        messages.append("bracer on %s" % sorted(faces_on(outfit, "bracer")))

    # A garment its recipe dyes is dyed, whatever built it (a shell too).
    parts, dyed = outfit.data.attributes["wr_part"].data, outfit.data.attributes["wr_dye"].data
    tunic = 1 + [g["name"] for g in TYPES["garments"]].index("tunic")
    undyed = sum(1 for p in outfit.data.polygons if parts[p.index].value == tunic and not dyed[p.index].value)

    if undyed:
        messages.append("dye: %d of the dyed tunic's faces are not dyed" % undyed)

    outside = over_the_sash(outfit)

    if outside:
        messages.append("sash: %d rays round the back of his waist meet something else first (%s)" % (len(outside), outside[0]))

    messages += validate.check(outfit, armature=arm, reference_joints=joints, cloth_bones=cloth, bare={"head", "hand"})
    return messages


def over_the_sash(outfit, recipe=TYPES):
    """Rays in at his waist, round his back (clear of the sash's tails and
    the props) and up and down the band: every one must meet the sash
    before anything else (a band's straight faces between its samples cut
    inside a curved back)."""
    import math

    from mathutils.bvhtree import BVHTree

    names = [g["name"] for g in recipe["garments"]]
    sash = 1 + names.index("sash")
    parts = outfit.data.attributes["wr_part"].data
    tree = BVHTree.FromPolygons([v.co.copy() for v in outfit.data.vertices], [tuple(p.vertices) for p in outfit.data.polygons])
    belt = outfit.parent.data.bones[recipe["belt"][0]].head_local.lerp(outfit.parent.data.bones[recipe["belt"][0]].tail_local,
                                                                      recipe["belt"][1]).z
    height = next(g for g in recipe["garments"] if g["name"] == "sash")["height"]
    wrong = []

    for dz in (-0.4, -0.2, 0.0, 0.2, 0.4):
        for degrees in range(130, 181, 5):
            for side in (1.0, -1.0):
                a = math.radians(degrees)
                out = Vector((math.sin(a) * side, -math.cos(a), 0.0))
                centre = Vector((0.0, 0.03, belt + dz * height))
                hit = tree.ray_cast(centre + out * 0.5, -out, 0.5)

                if hit[0] is not None and parts[hit[2]].value != sash:
                    wrong.append("%s at %d deg, %+.3f m" % (names[parts[hit[2]].value - 1] if parts[hit[2]].value else "body",
                                                           degrees * side, dz * height))

    return wrong


# Batch 2's garment types: on the male body (a padded gut, a studded
# jerkin, fur-cuffed boots, a fur mantle, one pauldron, a rapier's hanger)
# and the female (puffed sleeves, a half-cape).
TYPES2 = {
    "kind": "typetest2", "body": "male", "base_tris": 1300, "bare": ["head", "hand", "upper", "lower"],
    "belt": ("spine_01", 0.0),
    "garments": [
        {"name": "gut", "type": "shell", "fabric": "quilted_linen", "colour": GREY, "regions": ["torso", "pelvis"],
         "bottom": ("thigh_l", 0.05), "thickness": 0.014, "smooth": 4,
         "pads": [{"from": ("pelvis", 0.0), "to": ("spine_02", 0.5), "amount": 0.05, "front": True}]},
        {"name": "jerkin", "type": "shell", "fabric": "leather", "colour": GREY, "regions": ["torso"], "thickness": 0.012,
         "smooth": 4, "studs": {"spacing": 0.05}},
        {"name": "trousers", "type": "shell", "fabric": "wool", "colour": GREY, "regions": ["pelvis", "thigh", "calf"],
         "bottom": ("calf_l", 0.6), "top": ("spine_01", 0.0), "thickness": 0.008, "smooth": 2},
        {"name": "boots", "type": "boots", "fabric": "leather", "colour": GREY, "top": ("calf_l", 0.5), "thickness": 0.012,
         "sole": 0.004, "cuff": 0.05, "cuff_fabric": "fur", "cuff_colour": GREY, "smooth": 3},
        {"name": "hands", "type": "mittens", "fabric": "skin", "colour": (0.78, 0.6, 0.5), "cuff": 0},
        {"name": "belt", "type": "belt", "fabric": "leather", "colour": GREY, "height": 0.09,
         "buckle": {"fabric": "iron", "colour": GREY, "size": (0.07, 0.012, 0.06)}},
        {"name": "mantle", "type": "mantle", "fabric": "fur", "colour": GREY, "over": "jerkin", "reach": 0.16,
         "thickness": 0.05, "depth_front": 0.12, "depth_back": 0.18, "clear": 0.02},
        {"name": "pauldron", "type": "pauldron", "fabric": "iron", "colour": GREY, "side": "right", "over": "jerkin",
         "reach": 0.14, "drop": 0.12, "rings": 3, "clearance": 0.012, "roll": 0.01},
        {"name": "hanger", "type": "prop", "shape": "hanger", "fabric": "leather", "colour": GREY, "at": 100, "back": 35,
         "size": (0.03, 0.018, 0.95), "fittings": {"fabric": "iron", "colour": GREY}, "bone": "pelvis"},
        {"name": "bracer", "type": "bracer", "fabric": "leather", "colour": GREY, "bone": "lowerarm_l", "from": 0.35,
         "to": 0.85, "thickness": 0.008},
    ],
    "chains": {}, "colliders": [], "metal": [], "options": {},
}
TYPES3 = {
    "kind": "typetest3", "body": "female", "base_tris": 1300, "bare": ["head", "hand"], "belt": ("spine_01", 0.0),
    "garments": [
        {"name": "doublet", "type": "shell", "fabric": "wool", "colour": GREY, "dye": True,
         "regions": ["torso", "pelvis", "upper", "lower"], "bottom": ("thigh_l", 0.05), "sleeve_end": ("hand_l", 0.0),
         "sleeve_back": 0.016, "thickness": 0.012, "smooth": 6, "lips": ["sleeve", "bottom"]},
        {"name": "breeches", "type": "shell", "fabric": "wool", "colour": GREY, "regions": ["pelvis", "thigh", "calf"],
         "bottom": ("calf_l", 0.6), "top": ("spine_01", 0.0), "thickness": 0.008, "smooth": 2},
        {"name": "boots", "type": "boots", "fabric": "leather", "colour": GREY, "top": ("calf_l", 0.5), "thickness": 0.012,
         "sole": 0.004, "cuff": 0, "smooth": 3},
        {"name": "gloves", "type": "mittens", "fabric": "leather", "colour": GREY, "cuff": 0.03},
        {"name": "puffs", "type": "puff", "fabric": "wool", "colour": GREY, "dye": True, "from": 0.0, "to": 0.55,
         "peak": 0.25, "puff": 0.035, "slashes": {"count": 6, "colour": (0.78, 0.60, 0.22)}},
        {"name": "half_cape", "type": "half_cape", "fabric": "wool", "colour": GREY, "hem": ("spine_01", 0.0),
         "clear": 0.02, "chains": 3, "bones": 3},
        {"name": "drape", "type": "pauldron", "fabric": "wool", "colour": GREY, "side": "left", "over": "puffs",
         "reach": 0.12, "drop": 0.1, "rings": 3, "clearance": 0.01, "roll": 0.008},
    ],
    "chains": {"half_cape_%d" % n: CLOTH for n in (1, 2, 3)},
    "colliders": [{"bone": "spine_02", "radius": 0.14}, {"bone": "upperarm_l", "radius": 0.05}], "metal": [],
    "options": {},
}


def fabrics_of(obj, part_name, recipe):
    """The fabrics (recipes.FABRICS names) of one garment's faces."""
    import recipes

    part = 1 + [g["name"] for g in recipe["garments"]].index(part_name)
    parts, fabric = obj.data.attributes["wr_part"].data, obj.data.attributes["wr_fabric"].data
    return {recipes.FABRICS[fabric[p.index].value] for p in obj.data.polygons if parts[p.index].value == part}


def stands_off(obj, part_name, recipe):
    """How far one garment stands off everything else he wears, at most."""
    part = 1 + [g["name"] for g in recipe["garments"]].index(part_name)
    parts = obj.data.attributes["wr_part"].data
    rest = [tuple(p.vertices) for p in obj.data.polygons if parts[p.index].value != part]
    tree = BVHTree.FromPolygons([v.co.copy() for v in obj.data.vertices], rest)
    return max(tree.find_nearest(obj.data.vertices[v].co)[3] for v in part_vertices(obj, part_name, recipe))


def build_types(recipe):
    """`recipe` built into a temporary folder: (outfit, armature, chains by
    name, his body's joints)."""
    import json
    import tempfile
    from pathlib import Path

    import build

    fresh()
    source = common.WARDROBE / "source"
    folder = testkit.scratch_dir("wardrobe_%s_" % recipe["kind"])
    common.SOURCE, common.BACKUP = folder, folder / "backup"
    before = set(bpy.data.objects)
    skeleton, _, _ = common.import_quaternius(recipe["body"])
    joints = common.joints(skeleton)

    for obj in [o for o in bpy.data.objects if o not in before]:
        bpy.data.objects.remove(obj)

    try:
        build.build_kind(recipe, True)
    finally:
        common.SOURCE, common.BACKUP = source, source / "backup"

    chains = {c["chain"]: c for c in json.loads(bpy.context.scene["wardrobe_chains"])}
    return bpy.data.objects["Outfit"], bpy.data.objects["Armature"], chains, joints


def case_types2():
    """Batch 2's garment types build on both bodies, ride the bones and
    chains they should, and pass every export rule against their own body's
    skeleton."""
    import json

    import build
    import validate

    messages = []
    male, arm, chains, joints = build_types(TYPES2)
    cloth = [bone for c in chains.values() for bone in c["bones"]]

    if not faces_on(male, "mantle", TYPES2) <= set(build.CAPE_BONES) or fabrics_of(male, "mantle", TYPES2) != {"fur"}:
        messages.append("mantle on %s, of %s" % (sorted(faces_on(male, "mantle", TYPES2)), fabrics_of(male, "mantle", TYPES2)))

    pauldron = (faces_on(male, "pauldron", TYPES2, side=1.0), faces_on(male, "pauldron", TYPES2, side=-1.0))

    if pauldron != (set(), {"upperarm_r"}):
        messages.append("right pauldron on %s (left) and %s (right)" % tuple(sorted(p) for p in pauldron))

    if "fur" not in fabrics_of(male, "boots", TYPES2):
        messages.append("boots of %s: no fur cuff" % fabrics_of(male, "boots", TYPES2))

    if hangs_off(male, "hanger", TYPES2) > 0.03:
        messages.append("hanger hangs %.3f m off him" % hangs_off(male, "hanger", TYPES2))

    messages += leans_back(male, "hanger", TYPES2, 0.95, 35)
    # His bare left upper arm is whole under the mantle's rim (on his
    # collarbones, over his arm as he stands in the rest pose).
    holes = bare_holes(male, arm, "upperarm_l")

    if holes:
        messages.append("his bare left upper arm: %d of 24 rays out of it meet no skin first (%s)" % (len(holes), holes[0]))

    # And his elbow is whole beside his bracer (on his forearm, from 35%).
    holes = bare_holes(male, arm, "lowerarm_l", at=(0.05, 0.15))

    if holes:
        messages.append("his bare left elbow: %d of 16 rays out of it meet no skin first (%s)" % (len(holes), holes[0]))

    messages += ["male: %s" % m for m in validate.check(male, armature=arm, reference_joints=joints, cloth_bones=cloth,
                                                         bare=set(TYPES2["bare"]))]

    female, arm, chains, joints = build_types(TYPES3)
    cloth = [bone for c in chains.values() for bone in c["bones"]]

    if faces_on(female, "puffs", TYPES3) != {"upperarm_l", "upperarm_r"} or stands_off(female, "puffs", TYPES3) < 0.02:
        messages.append("puffs on %s, standing %.3f m off her sleeves" % (sorted(faces_on(female, "puffs", TYPES3)),
                                                                          stands_off(female, "puffs", TYPES3)))

    capes = [chains.get("half_cape_%d" % n, {}) for n in (1, 2, 3)]
    drape = (faces_on(female, "drape", TYPES3, side=1.0), faces_on(female, "drape", TYPES3, side=-1.0))

    # A cloth pauldron (the half-cape over her left shoulder) is on her left
    # alone, and carries no plate's trim (its bright rim and lames are iron's).
    if drape != ({"upperarm_l"}, set()) or fabrics_of(female, "drape", TYPES3) != {"wool"} \
            or json.loads(female.get("wr_details", "{}")).get("plates"):
        messages.append("drape on %s (left) and %s (right), of %s, plates %s" % (
            sorted(drape[0]), sorted(drape[1]), fabrics_of(female, "drape", TYPES3),
            json.loads(female.get("wr_details", "{}")).get("plates")))

    if [len(c.get("bones", [])) for c in capes] != [3, 3, 3] or any(c.get("parent") != "spine_03" for c in capes):
        messages.append("half-cape chains %s" % [(c.get("parent"), len(c.get("bones", []))) for c in capes])

    messages += ["female: %s" % m for m in validate.check(female, armature=arm, reference_joints=joints, cloth_bones=cloth,
                                                           bare=set(TYPES3["bare"]))]
    return messages


def weights_of(obj):
    """Each vertex's weights by bone name (the ones that count)."""
    names = {g.index: g.name for g in obj.vertex_groups}
    return [{names[g.group]: g.weight for g in v.groups if g.weight > 1e-4} for v in obj.data.vertices]


def strays(a, b):
    """a's vertices with no vertex of b within 0.1 mm carrying the same
    weights: two builds of one part compared by place, as their vertex order
    varies run to run."""
    from mathutils.kdtree import KDTree

    def same(x, y):
        return x.keys() == y.keys() and all(abs(x[k] - y[k]) < 1e-3 for k in x)

    tree = KDTree(len(b.data.vertices))

    for v in b.data.vertices:
        tree.insert(v.co, v.index)

    tree.balance()
    wa, wb = weights_of(a), weights_of(b)
    return [v.co.copy() for v in a.data.vertices if not any(same(wa[v.index], wb[i]) for _, i, _ in tree.find_range(v.co, 1e-4))]


def case_watchman():
    """The watchman the user approved rebuilds as he was: today's pipeline,
    run on his recipe, gives back source/watchman.blend (the same triangles
    per part, every vertex where it was with the weights it had, the same
    chains and cloth bones). Vertex order varies run to run: vertices are
    matched by place, within 0.1 mm."""
    import json
    import tempfile
    from pathlib import Path

    import build
    import recipes

    source = common.WARDROBE / "source"
    approved = source / "watchman.blend"
    fresh()
    folder = testkit.scratch_dir("wardrobe_watchman_")
    common.SOURCE, common.BACKUP = folder, folder / "backup"

    try:
        build.build_kind(recipes.WATCHMAN, True)
    finally:
        common.SOURCE, common.BACKUP = source, source / "backup"

    new, new_arm = bpy.data.objects["Outfit"], bpy.data.objects["Armature"]
    new_chains = json.loads(bpy.context.scene["wardrobe_chains"])

    with bpy.data.libraries.load(str(approved)) as (src, dst):
        dst.objects = ["Outfit", "Armature"]
        dst.scenes = list(src.scenes)

    old, old_arm = dst.objects
    old_chains = json.loads(dst.scenes[0]["wardrobe_chains"])
    names = [g["name"] for g in recipes.WATCHMAN["garments"]]

    def triangles(obj):
        parts, out = obj.data.attributes["wr_part"].data, {}

        for p in obj.data.polygons:
            out[parts[p.index].value] = out.get(parts[p.index].value, 0) + len(p.vertices) - 2

        return out

    def near(a, b):
        if isinstance(a, dict):
            return isinstance(b, dict) and a.keys() == b.keys() and all(near(a[k], b[k]) for k in a)

        if isinstance(a, list):
            return isinstance(b, list) and len(a) == len(b) and all(near(x, y) for x, y in zip(a, b))

        if isinstance(a, float) or isinstance(b, float):
            return abs(a - b) < 1e-4

        return a == b

    def bones(arm):
        return {b.name: (b.head_local.copy(), b.tail_local.copy()) for b in arm.data.bones if b.name.startswith("cloth_")}

    messages = []
    was, now = triangles(old), triangles(new)

    for part in sorted(set(was) | set(now)):
        if was.get(part, 0) != now.get(part, 0):
            label = names[part - 1] if 0 < part <= len(names) else "body"
            messages.append("%s: %d triangles, approved %d" % (label, now.get(part, 0), was.get(part, 0)))

    moved, lost = strays(new, old), strays(old, new)

    if moved or lost:
        messages.append("%d rebuilt vertices are not where the approved ones were (or weigh differently), %d approved "
                        "ones are gone (first %s)" % (len(moved), len(lost), tuple(round(c, 3) for c in (moved or lost)[0])))

    if not near(new_chains, old_chains):
        messages.append("chains differ from the approved build: %s" % sorted(
            c["chain"] for c in new_chains if not any(near(c, o) for o in old_chains)))

    was_bones, now_bones = bones(old_arm), bones(new_arm)
    shifted = sorted(n for n in set(was_bones) | set(now_bones) if n not in was_bones or n not in now_bones
                     or max((was_bones[n][0] - now_bones[n][0]).length, (was_bones[n][1] - now_bones[n][1]).length) > 1e-4)

    if shifted:
        messages.append("cloth bones moved, added or gone: %s" % shifted)

    return messages


def case_hood():
    """The hood is lit and baked from outside, where it is seen: every face
    of its one-sheet parts (the cape, the tail) faces away from the nearest
    point of what they drape over (his neck, chest, back and collarbones;
    not his head, nearer than his chest under his chin). A two-sided sheet
    shows its baked side on both. A face edge-on to him (where the cape
    leaves his neck) counts neither way: only one turned clearly toward him
    (over 15 degrees past edge-on) is wrong."""
    import build
    import recipes

    fresh()
    armature, reference, extras = build.start("headgear")

    for extra in extras.values():
        bpy.data.objects.remove(extra)

    kind = build.Kind({"belt": ("spine_01", 0.0), "garments": []}, armature, reference)
    hood = build.coif(kind, recipes.HEADGEAR["hood"], "hood", {})
    strips = hood.data.attributes["wr_strip"].data
    names = {group.index: group.name for group in reference.vertex_groups}
    heaviest = [names[max(v.groups, key=lambda g: g.weight).group] if v.groups else "" for v in reference.data.vertices]
    trunk = BVHTree.FromPolygons([v.co.copy() for v in reference.data.vertices],
                                 [tuple(p.vertices) for p in reference.data.polygons
                                  if build.majority([heaviest[i] for i in p.vertices]) in build.CAPE_BONES])
    sheet, inward = 0, []

    for polygon in hood.data.polygons:
        if not strips[polygon.index].value:
            continue

        sheet += 1
        near = trunk.find_nearest(polygon.center)[0]

        if near is None or (polygon.center - near).normalized().dot(polygon.normal) < -0.25:
            inward.append(tuple(round(x, 3) for x in polygon.center))

    if not sheet:
        return ["hood: no one-sheet faces"]

    return [] if not inward else ["hood: %d of its %d one-sheet faces face in toward him (first at %s)" % (len(inward), sheet, inward[0])]


def case_launcher():
    """wardrobe.sh stops when it cannot tell the kinds (recipes.py broken, or
    no Python): `check all` must not quietly check only heads, hair and
    headgear and exit 0. Blender is stood in for by `true`."""
    import subprocess
    import tempfile
    from pathlib import Path

    folder = testkit.scratch_dir("wardrobe_launcher_")
    broken = folder / "python3"
    broken.write_text("#!/bin/sh\nexit 1\n")
    broken.chmod(0o755)
    env = dict(os.environ, PATH="%s:%s" % (folder, os.environ.get("PATH", "")), BLENDER="true")
    script = Path(__file__).resolve().parent / "wardrobe.sh"
    done = subprocess.run(["bash", str(script), "check", "all"], env=env, capture_output=True, text=True)
    return [] if done.returncode != 0 else ["launcher: `check all` exited 0 though it could not tell the kinds"]


def case_bodies():
    """Heads and hair are made per body, each body's in its own file on its
    own skeleton: a female part is built on, and checked against, the
    female skeleton (her head's joint sits 5 cm under his)."""
    import build
    import export

    table = {"m": {"body": "male"}, "f": {"body": "female"}, "n": {}}
    ok = common.parts_of(table, "female") == ["f"] and common.parts_of(table, "male") == ["m", "n"] \
        and common.PART_TARGETS["heads_female"] == ("heads", "female") and common.PART_TARGETS["hair"] == ("hair", "male")
    fresh()
    head = build.start("heads_female", "female")[0].data.bones["Head"].head_local.z
    ok = ok and abs(export.reference_joints("female")["Head"][2] - head) < 0.001 \
        and abs(export.reference_joints("male")["Head"][2] - head) > 0.03
    return [] if ok else ["bodies: parts by body, their targets, or the female skeleton's joints"]


def case_male_parts():
    """The male heads and hair rebuild as committed (every vertex by place
    with its weights, as `watchman` compares): building per body changed
    nothing for them."""
    import tempfile
    from pathlib import Path

    import build

    source = common.WARDROBE / "source"
    folder = testkit.scratch_dir("wardrobe_male_parts_")
    messages = []

    # The heads first: the hair is fitted over the heads it finds there.
    for target, prefix, builder in (("heads", "Head_", build.build_heads), ("hair", "Hair_", build.build_hair)):
        fresh()
        common.SOURCE, common.BACKUP = folder, folder / "backup"

        try:
            builder(True)
        finally:
            common.SOURCE, common.BACKUP = source, source / "backup"

        rebuilt = {o.name: o for o in bpy.data.objects if o.name.startswith(prefix) and o.type == "MESH"}

        with bpy.data.libraries.load(str(source / ("%s.blend" % target))) as (src, dst):
            dst.objects = [name for name in src.objects if name.startswith(prefix)]

        for old in [o for o in dst.objects if o is not None and o.type == "MESH"]:
            # (Loaded beside its rebuild, the committed one is renamed .001.)
            name = old.name.split(".")[0]
            new = rebuilt.get(name)

            if new is None:
                messages.append("%s: not rebuilt" % name)
            elif common.tri_count(new) != common.tri_count(old) or strays(new, old) or strays(old, new):
                messages.append("%s: %d triangles (committed %d), %d vertices moved, %d gone" % (
                    name, common.tri_count(new), common.tri_count(old), len(strays(new, old)), len(strays(old, new))))

    return messages


def case_brute_arms():
    """The committed brute's bare arms are whole: rays out of his upper arms
    (his right below its pauldron; his left from 30%, below his mantle's
    rim: the cap of his shoulder above it rides under the fur in every pose)
    and his elbows (his bracers begin at 35% of his forearms) meet his skin
    first, all round, toward his armpits too: no holes where the build cut
    him, under his mantle's rest-pose overhang or round his bracers."""
    bpy.ops.wm.open_mainfile(filepath=str(common.WARDROBE / "source" / "brute.blend"))
    outfit, arm = bpy.data.objects["Outfit"], bpy.data.objects["Armature"]
    holes = []

    for bone, at in (("upperarm_l", (0.3, 0.4, 0.5, 0.7)), ("upperarm_r", (0.6, 0.7)),
                     ("lowerarm_l", (0.05, 0.15)), ("lowerarm_r", (0.05, 0.15))):
        holes += ["%s %s" % (bone, h) for h in bare_holes(outfit, arm, bone, at)]

    fresh()
    return ["%d rays out of his bare arms meet no skin first (%s)" % (len(holes), holes[0])] if holes else []


def case_brute_neck():
    """The committed brute's throat and the tops of his shoulders are whole
    under his mantle's inner rim: rays out of the foot of his neck (3 cm
    under its joint; round his front, to 60 degrees either side, level, a
    little down and a little up) meet his skin before his fur or his gut.
    (Steeper up they leave by his neck, which his head fills; further round
    they skim his shoulders to his mantle's rim hanging over them.)
    (Cut away under the roll, the skin left a ragged edge there, and his
    mantle's unlit underside showed through it as black shards.)"""
    bpy.ops.wm.open_mainfile(filepath=str(common.WARDROBE / "source" / "brute.blend"))
    outfit, arm = bpy.data.objects["Outfit"], bpy.data.objects["Armature"]
    tree = BVHTree.FromPolygons([v.co.copy() for v in outfit.data.vertices], [tuple(p.vertices) for p in outfit.data.polygons])
    fabric = outfit.data.attributes["wr_fabric"].data
    centre = arm.data.bones["neck_01"].head_local - Vector((0.0, 0.0, 0.03))
    holes = []

    for elevation in (-15.0, 0.0, 15.0):
        for azimuth in range(-60, 61, 15):
            e, a = math.radians(elevation), math.radians(azimuth)
            hit = tree.ray_cast(centre, Vector((math.cos(e) * math.sin(a), -math.cos(e) * math.cos(a), math.sin(e))), 0.4)

            if hit[2] is None or fabric[hit[2]].value != 0:
                holes.append("%d up, %d round" % (elevation, azimuth))

    fresh()
    return ["%d rays out of his neck meet no skin first (%s)" % (len(holes), holes[:4])] if holes else []


def case_duelist_cape():
    """The committed duelist's half-cape reads as a cape, not a sash: its
    hem at least 8 cm wider than its top (across her back, x)."""
    import recipes

    bpy.ops.wm.open_mainfile(filepath=str(common.WARDROBE / "source" / "duelist.blend"))
    outfit = bpy.data.objects["Outfit"]
    part = [g["name"] for g in recipes.DUELIST["garments"]].index("half_cape") + 1
    parts = outfit.data.attributes["wr_part"].data
    points = [outfit.data.vertices[i].co.copy() for p in outfit.data.polygons if parts[p.index].value == part for i in p.vertices]
    fresh()

    if not points:
        return ["no half-cape in the duelist's outfit"]

    top, low = max(p.z for p in points), min(p.z for p in points)
    width = lambda near: (lambda xs: max(xs) - min(xs))([p.x for p in points if abs(p.z - near) < 0.03])
    upper, hem = width(top - 0.02), width(low + 0.02)
    return [] if hem >= upper + 0.08 else ["its hem is %.1f cm across, its top %.1f: a strip, not a cape" % (hem * 100, upper * 100)]


def case_brute_bracers():
    """The committed brute's bracers close round his forearms: coming in
    from outside (16 ways round, all along each bracer but its rims), the
    bracer is met first, never his skin through it."""
    import recipes

    bpy.ops.wm.open_mainfile(filepath=str(common.WARDROBE / "source" / "brute.blend"))
    outfit, arm = bpy.data.objects["Outfit"], bpy.data.objects["Armature"]
    tree = BVHTree.FromPolygons([v.co.copy() for v in outfit.data.vertices], [tuple(p.vertices) for p in outfit.data.polygons])
    parts = outfit.data.attributes["wr_part"].data
    names = [g["name"] for g in recipes.BRUTE["garments"]]
    through = []

    for g in recipes.BRUTE["garments"]:
        if g["type"] != "bracer":
            continue

        bone = arm.data.bones[g["bone"]]
        axis = (bone.tail_local - bone.head_local).normalized()
        u = axis.orthogonal().normalized()
        v = axis.cross(u)

        for step in range(5):
            t = g["from"] + 0.02 + (g["to"] - g["from"] - 0.04) * step / 4
            centre = bone.head_local.lerp(bone.tail_local, t)

            for k in range(16):
                d = u * math.cos(k * math.pi / 8.0) + v * math.sin(k * math.pi / 8.0)
                hit = tree.ray_cast(centre + d * 0.2, -d, 0.2)

                met = names[parts[hit[2]].value - 1] if hit[2] is not None and parts[hit[2]].value > 0 else "skin"

                if met != g["name"]:
                    through.append("%s %.2f %d" % (g["name"], t, k * 22.5))

    fresh()
    return ["%d rays meet his skin before his bracer (%s)" % (len(through), through[:4])] if through else []


def case_hoods_hold_faces():
    """The committed coif and hood hold every male face (Review Focus 2):
    along the ray from the middle of his head through each vertex of each
    head over its cape's top (lower down the cape covers from outside),
    the piece is not met before the vertex (a face beyond its rim: the
    heavy jaw came 5.9 mm through the hood's)."""
    import recipes

    import check

    source = common.WARDROBE / "source"
    bpy.ops.wm.open_mainfile(filepath=str(source / "headgear.blend"))
    centre = bpy.data.objects["Armature"].data.bones["Head"].head_local + Vector((0.0, 0.0, 0.1))
    heads = check.heads("male")
    through = []

    for piece in ("coif", "hood"):
        tree = common.bvh([bpy.data.objects["Gear_" + piece]])
        above = recipes.HEADGEAR[piece]["cape"]["top_z"] + 0.01

        for head in heads:
            for v in (v for v in head.data.vertices if v.co.z > above):
                d = v.co - centre
                hit = tree.ray_cast(centre, d.normalized(), d.length)

                if hit[0] is not None and d.length - hit[3] > 0.0005:
                    through.append("%s %s %.1f mm at (%.3f, %.3f, %.3f)" % (piece, head.name, (d.length - hit[3]) * 1000, *v.co))

    check.forget(heads)
    fresh()
    return ["%d face vertices beyond the coif or hood: %s" % (len(through), through[:8])] if through else []


def see_through(objects, cameras, window):
    """How many rays from `cameras` into `window` (points) meet a surface
    but none that faces them (a closed part culls its backs; a strip,
    wr_strip, draws both): holes where the background shows through him."""
    vertices, polygons, two = [], [], []

    for obj in objects:
        start = len(vertices)
        vertices += [v.co.copy() for v in obj.data.vertices]
        strip = obj.data.attributes.get("wr_strip")

        for p in obj.data.polygons:
            polygons.append(tuple(start + i for i in p.vertices))
            two.append(bool(strip.data[p.index].value) if strip is not None else False)

    tree = BVHTree.FromPolygons(vertices, polygons)
    holes = 0

    for camera in cameras:
        for target in window:
            d = (target - camera).normalized()
            at = camera.copy()

            if tree.ray_cast(camera, d, 3.0)[0] is None:
                continue

            for _ in range(12):
                hit = tree.ray_cast(at, d, 3.0)

                if hit[0] is None:
                    holes += 1
                    break

                if hit[1].dot(d) < 0.0 or two[hit[2]]:
                    break

                at = hit[0] + d * 1e-4

    return holes


def case_neck_seams():
    """No background shows through the seam where a bare neck meets its
    collar (the bare-hat watchman, the brute, the duelist, the arms
    master), with every face each may roll and the headgear he wears then:
    rays from in front of him and from each side at three-quarters, into
    the band round the foot of his neck. (Under the bare hat the
    watchman's batch 0 gambeson let the wall through beside his neck.)"""
    import check
    import recipes

    source = common.WARDROBE / "source"
    holes = []

    for kind in ("watchman", "brute", "duelist", "arms_master"):
        recipe = recipes.KINDS[kind]
        body = recipe["body"]
        options = recipe["options"]
        bare_sets = [s for s in options["headgear"] if not any(recipes.HEADGEAR[p].get("covers_head") or p == "curtain" for p in s)]

        for pieces in bare_sets:
            with bpy.data.libraries.load(str(source / ("%s.blend" % kind))) as (_, target):
                target.objects = ["Outfit"]

            outfit = target.objects[0]
            gear = []

            if pieces:
                with bpy.data.libraries.load(str(source / "headgear.blend")) as (_, target):
                    target.objects = ["Gear_%s" % p for p in pieces]

                gear = [o for o in target.objects if o is not None]

            heads = {o.name: o for o in check.heads(body)}
            low = 1.40 if body == "female" else 1.44

            for face in options["faces"]:
                head = heads.get("Head_" + face)
                window = [Vector((x * 0.008, -0.02, low + z * 0.008)) for x in range(-15, 16) for z in range(21)]
                cameras = [Vector((0.0, -0.7, low + 0.06)), Vector((0.45, -0.55, low + 0.06)), Vector((-0.45, -0.55, low + 0.06))]
                n = see_through([outfit, head] + gear, cameras, window) if head is not None else -1

                if n != 0:
                    holes.append("%s %s %s: %d" % (kind, "+".join(pieces) or "bare", face, n))

            check.forget(list(heads.values()) + gear + [outfit])

    fresh()
    return ["see-through rays at the neck: %s" % holes] if holes else []


def case_strips_face_out():
    """Every committed kind's hanging cloth (strips, below his chest) faces
    away from him: the bake paints both sides of a strip from the side its
    faces point to, and a skirt facing his legs baked their shadow (the
    swordsman's surcoat front read dark and muddy under his belt). The
    watchman's batch 0 outfit is his own (never rebuilt: the user's call)."""
    import recipes
    from mathutils import Vector

    inward = []

    for kind in recipes.KINDS:
        if recipes.KINDS[kind].get("batch") == 0:
            continue

        bpy.ops.wm.open_mainfile(filepath=str(common.WARDROBE / "source" / ("%s.blend" % kind)))
        outfit, arm = bpy.data.objects["Outfit"], bpy.data.objects["Armature"]
        chest = arm.data.bones["spine_02"].head_local.z
        axis_y = arm.data.bones["spine_01"].head_local.y
        strips = outfit.data.attributes["wr_strip"].data
        n = 0

        for p in outfit.data.polygons:
            if strips[p.index].value and p.center.z < chest:
                out = Vector((p.center.x, p.center.y - axis_y, 0.0))

                if out.length > 0.01 and p.normal.dot(out.normalized()) < -0.2:
                    n += 1

        if n:
            inward.append("%s %d" % (kind, n))

    fresh()
    return ["hanging strips facing him: %s" % inward] if inward else []


def case_shell_edges():
    """Every committed kind's shells (garments cut from his body's regions)
    meet each other in clean edges: no face of one with two or more open
    edges (a single triangle sticking out of its edge) where that edge lies
    against another shell (within 1.5 cm of it) and no other garment lies
    over the face (a thinner shell's edge under a thicker one is hidden),
    across his chest and back (from spine_02 up to the foot of his neck,
    within 20 cm of his middle): the archer's jerkin met his tunic there in
    a row of teeth. (His waist, legs, arms and neck lie under his belt,
    boots, pauldrons, hood or collar.) The watchman's batch 0 outfit is his
    own (never rebuilt: the user's call)."""
    from mathutils.bvhtree import BVHTree

    import recipes

    teeth = []

    for kind in recipes.KINDS:
        recipe = recipes.KINDS[kind]

        if recipe.get("batch") == 0:
            continue

        bpy.ops.wm.open_mainfile(filepath=str(common.WARDROBE / "source" / ("%s.blend" % kind)))
        me = bpy.data.objects["Outfit"].data
        parts = me.attributes["wr_part"].data
        shells = {i + 1 for i, g in enumerate(recipe["garments"]) if g["type"] == "shell"}
        verts = [v.co.copy() for v in me.vertices]
        trees = {k: BVHTree.FromPolygons(verts, [tuple(p.vertices) for p in me.polygons if parts[p.index].value == k])
                 for k in shells}
        garments = {k: BVHTree.FromPolygons(verts, [tuple(p.vertices) for p in me.polygons if parts[p.index].value == k])
                    for k in range(1, len(recipe["garments"]) + 1)}
        arm = bpy.data.objects["Armature"].data.bones
        chest, neck = arm["spine_02"].head_local.z, arm["neck_01"].head_local.z
        bm = bmesh.new()
        bm.from_mesh(me)
        n = 0

        for f in bm.faces:
            own = parts[f.index].value
            open_edges = [e for e in f.edges if e.is_boundary]
            where = f.calc_center_median()

            if own not in shells or len(open_edges) < 2 or not chest <= where.z <= neck or abs(where.x) > 0.2:
                continue

            mids = [(e.verts[0].co + e.verts[1].co) * 0.5 for e in open_edges]
            c = f.calc_center_median()

            if any(garments[k].ray_cast(c + f.normal * 0.001, f.normal, 0.03)[0] is not None for k in garments if k != own):
                continue

            if any(trees[k].find_nearest(m)[3] is not None and trees[k].find_nearest(m)[3] < 0.015
                   for k in shells if k != own for m in mids):
                n += 1

        bm.free()

        if n:
            teeth.append("%s %d" % (kind, n))

    fresh()
    return ["shell faces sticking out where shells meet: %s" % teeth] if teeth else []


def width_at(tree, y, z):
    """How far out to his left a surface stands at (y, z): its outermost
    hit coming in along x (a low-poly head has few vertices near any one
    point: its surface is measured, not its vertices)."""
    hit = common.outer_hit(tree, Vector((0.0, y, z)), Vector((1.0, 0.0, 0.0)), 0.3)
    return hit.x if hit is not None else 0.0


def depth_at(tree, point):
    """How far a surface stands out from the head's middle (the vertical
    axis) toward `point`: its outermost hit along that way."""
    centre = Vector((0.0, 0.0, point[2]))
    way = (Vector(point) - centre).normalized()
    hit = common.outer_hit(tree, centre, way, 0.3)
    return (hit - centre).length if hit is not None else 0.0


def case_faces():
    """Batch 3's faces (§8): male young, weathered, heavy and old, female
    sharp and soft. Each built face differs from its neighbour where its
    recipe moves it (the heavy jaw wider, the young cheek not hollowed, the
    soft jaw rounder than the sharp), within the head budget."""
    import tempfile
    from pathlib import Path

    import build
    import recipes

    male, female = common.parts_of(recipes.HEADS, "male"), common.parts_of(recipes.HEADS, "female")

    if not {"young", "weathered", "heavy", "old"} <= set(male) or not {"sharp", "soft"} <= set(female):
        return ["faces: male %s, female %s" % (male, female)]

    source = common.WARDROBE / "source"
    folder = testkit.scratch_dir("wardrobe_faces_")
    heads = {}

    for body in ("male", "female"):
        fresh()
        common.SOURCE, common.BACKUP = folder, folder / "backup"

        try:
            build.build_heads(True, body)
        finally:
            common.SOURCE, common.BACKUP = source, source / "backup"

        for obj in [o for o in bpy.data.objects if o.name.startswith("Head_") and o.type == "MESH"]:
            points = [v.co.copy() for v in obj.data.vertices]
            tree = BVHTree.FromPolygons(points, [tuple(p.vertices) for p in obj.data.polygons])
            heads[obj.name[len("Head_"):]] = (points, tree, common.tri_count(obj))

    fresh()
    messages = []
    cheek = (0.047, -0.07, 1.648)

    heavy, weathered = width_at(heads["heavy"][1], -0.04, 1.60), width_at(heads["weathered"][1], -0.04, 1.60)

    if heavy < weathered + 0.004:
        messages.append("heavy jaw %.4f, weathered %.4f" % (heavy, weathered))

    if depth_at(heads["young"][1], cheek) < depth_at(heads["weathered"][1], cheek) + 0.005:
        messages.append("young cheek %.4f, weathered %.4f" % (depth_at(heads["young"][1], cheek), depth_at(heads["weathered"][1], cheek)))

    soft, sharp = width_at(heads["soft"][1], -0.045, 1.56), width_at(heads["sharp"][1], -0.045, 1.56)

    if soft < sharp + 0.003:
        messages.append("soft jaw %.4f, sharp %.4f" % (soft, sharp))

    messages += ["%s %d triangles (limit 450)" % (name, h[2]) for name, h in heads.items() if h[2] > 450]
    return messages


def build_hair_into(folder):
    """Every hair and beard of both bodies built into `folder`, over the
    committed heads (copied there first: hair is fitted over them):
    {style: (points, bones)} with bones the set any vertex is weighted to."""
    import shutil

    import build

    source = common.WARDROBE / "source"

    for name in ("heads.blend", "heads_female.blend"):
        shutil.copy(source / name, folder / name)

    made = {}

    for body in ("male", "female"):
        fresh()
        common.SOURCE, common.BACKUP = folder, folder / "backup"

        try:
            build.build_hair(True, body)
        finally:
            common.SOURCE, common.BACKUP = source, source / "backup"

        for obj in [o for o in bpy.data.objects if o.name.startswith("Hair_") and o.type == "MESH"]:
            names = {g.index: g.name for g in obj.vertex_groups}
            bones = {names[g.group] for v in obj.data.vertices for g in v.groups if g.weight > 1e-4}
            made[obj.name[len("Hair_"):]] = ([v.co.copy() for v in obj.data.vertices], bones)

    fresh()
    return made


def case_beards_and_tails():
    """Batch 3's hair (§8): the short beard (his jaw and chin, under his
    mouth: no cheeks, no moustache), the moustache (his upper lip only),
    tied hair (the parted cut and a tail down the back of his neck) and her
    tail (her long hair cut at her nape, tied back): each on his Head and
    neck alone, the tails clear of what they hang over (above the collars:
    a man's ends over z 1.52, hers over 1.46)."""
    import tempfile
    from pathlib import Path

    import recipes

    missing = [s for s in ("short", "moustache", "tied", "tail") if s not in recipes.HAIR]

    if missing:
        return ["no recipe for %s" % missing]

    hair = build_hair_into(testkit.scratch_dir("wardrobe_beards_"))
    messages = []
    short, moustache, tied, tail = (hair[s][0] for s in ("short", "moustache", "tied", "tail"))

    if max(p.z for p in short) > 1.62 or min(p.z for p in short) > 1.56:
        messages.append("short beard z %.3f..%.3f (want under his mouth, to his chin)" % (min(p.z for p in short), max(p.z for p in short)))

    if not all(abs(p.x) <= 0.045 and 1.62 <= p.z <= 1.65 and p.y <= -0.07 for p in moustache):
        messages.append("moustache off his upper lip: x %.3f z %.3f..%.3f y %.3f" % (max(abs(p.x) for p in moustache),
                        min(p.z for p in moustache), max(p.z for p in moustache), max(p.y for p in moustache)))

    if not 1.52 <= min(p.z for p in tied) <= 1.58:
        messages.append("tied hair's tail ends at z %.3f (want 1.52-1.58)" % min(p.z for p in tied))

    under_nape = [p for p in tail if p.z < 1.57]

    if not under_nape or any(abs(p.x) > 0.03 for p in under_nape) or min(p.z for p in tail) < 1.46:
        messages.append("her tail: %d points under her nape, widest |x| %.3f, lowest %.3f" % (
            len(under_nape), max((abs(p.x) for p in under_nape), default=0), min(p.z for p in tail)))

    messages += ["%s on %s" % (s, sorted(hair[s][1])) for s in ("short", "moustache", "tied", "tail")
                 if not hair[s][1] <= {"Head", "neck_01"}]
    return messages


def case_bare_hat():
    """The watchman's kettle hat over a bare head (batch 3's helmet variant,
    §8 "coif or bare head under the kettle hat"): along its rays it clears
    every male head and every hair style he may wear under it by at least
    its clearance, and floats no more than its `rest` off any of them."""
    import shutil
    import tempfile
    from pathlib import Path

    import build
    import check
    import recipes

    g = recipes.HEADGEAR.get("kettlehat_bare")

    if g is None:
        return ["no kettlehat_bare recipe"]

    source = common.WARDROBE / "source"
    folder = testkit.scratch_dir("wardrobe_bare_hat_")

    for name in ("heads.blend", "hair.blend"):
        shutil.copy(source / name, folder / name)

    fresh()
    common.SOURCE, common.BACKUP = folder, folder / "backup"

    try:
        build.build_headgear(True)
        hat = bpy.data.objects["Gear_kettlehat_bare"]
        pivot = bpy.data.objects["Armature"].data.bones["Head"].head_local
        unders = check.heads("male") + check.hair_of("male", g["over_hair"])
        messages = check.fit(hat, unders, pivot, g["clearance"], g["rest"], g.get("fit_rays"))
        # And every vertex of every head and hair above the hat's band is
        # under its bowl: along the ray from his head's middle through it,
        # the hat stands beyond it (sampled rays miss a hair's crest).
        tree = common.bvh([hat])
        centre = pivot + Vector((0.0, 0.0, 0.1))
        out = []

        for obj in unders:
            for v in obj.data.vertices:
                if v.co.z <= g["base_z"] + 0.005:
                    continue

                way = (v.co - centre).normalized()
                hit = tree.ray_cast(centre, way, 0.5)

                if hit[0] is None or hit[3] < (v.co - centre).length + 0.001:
                    out.append("%s (%.3f, %.3f, %.3f)" % (obj.name, v.co.x, v.co.y, v.co.z))

        messages += ["%d vertices through the hat: %s" % (len(out), out[:3])] if out else []
        messages += [] if len(unders) == 4 + len(g["over_hair"]) else ["fitted over %d pieces" % len(unders)]
    finally:
        common.SOURCE, common.BACKUP = source, source / "backup"

    fresh()
    return messages


def case_coif_beards():
    """The spec's coif "hides the hair but allows a beard" (§6): every beard
    the watchman may wear under it lies under its mail (or in its face
    opening), no face of the one through a face of the other, on the heads
    they are fitted over."""
    import shutil
    import tempfile
    from pathlib import Path

    import build
    import check
    import recipes

    source = common.WARDROBE / "source"
    folder = testkit.scratch_dir("wardrobe_coif_beards_")

    for name in ("heads.blend", "hair.blend"):
        shutil.copy(source / name, folder / name)

    fresh()
    common.SOURCE, common.BACKUP = folder, folder / "backup"
    beards = [b for b in recipes.WATCHMAN["options"]["beards"] if b]

    try:
        build.build_headgear(True)
        coif = common.bvh([bpy.data.objects["Gear_coif"]])
        found = check.hair_of("male", beards)
        messages = ["%s passes through the coif at %d pairs of faces" % (b.name, len(coif.overlap(common.bvh([b]))))
                    for b in found if coif.overlap(common.bvh([b]))]
        messages += [] if len(found) == len(beards) == 3 else ["beards %s found %d" % (beards, len(found))]
        check.forget(found)
        # check.py says so of a coif shrunk onto them.
        obj = bpy.data.objects["Gear_coif"]
        pivot = bpy.data.objects["Armature"].data.bones["Head"].head_local + Vector((0.0, 0.0, 0.1))

        for v in obj.data.vertices:
            v.co = pivot + (v.co - pivot) * 0.85

        said = [m for m in check.check_parts("Gear_", "headgear") if "Gear_coif" in m and "passes through" in m]
        messages += [] if said else ["check.py passed a coif shrunk onto the beards"]
    finally:
        common.SOURCE, common.BACKUP = source, source / "backup"

    fresh()
    return messages


def case_foreign_parts():
    """A kind whose options name a part of the other body is refused
    (check.foreign_parts); the heaviest combination counts "" as none and
    leaves out hair a set hides and beards it forbids
    (common.heaviest_combination); an unknown body stops with a message."""
    import contextlib
    import io

    import check

    messages = []
    recipe = {"kind": "x", "body": "male",
              "options": {"faces": ["weathered", "sharp"], "hair": ["", "buns"], "beards": [], "headgear": [[]]}}
    found = check.foreign_parts(recipe)

    if found != ["options: sharp is made for the female body", "options: buns is made for the female body"]:
        messages.append("foreign parts %s" % found)

    counts = {"heads/a.json": {"triangles": 400}, "hair/h.json": {"triangles": 200}, "hair/b.json": {"triangles": 100},
              "headgear/hides.json": {"triangles": 300, "hides_hair": True, "allows_beard": False},
              "headgear/open.json": {"triangles": 250, "hides_hair": False, "allows_beard": True}}
    options = {"faces": ["a"], "hair": ["", "h"], "beards": ["", "b"], "headgear": [["hides"], ["open"]]}
    heaviest = common.heaviest_combination(options, counts.get)

    # The open set: 400 + 200 + 100 + 250; the hiding set only 400 + 300.
    if heaviest != 950:
        messages.append("heaviest %s (want 950)" % heaviest)

    out = io.StringIO()

    try:
        with contextlib.redirect_stdout(out):
            common.part_target("heads", "elf")

        messages.append("part_target(heads, elf) did not stop")
    except SystemExit:
        if "no heads for the elf body" not in out.getvalue():
            messages.append("part_target said %r" % out.getvalue())

    return messages


def head_skin():
    """Where the open file's detailed heads (High_*) sample their skin
    texture, the median colour (sRGB) of each: {head: (r, g, b)}."""
    import numpy as np

    out = {}

    for obj in [o for o in bpy.data.objects if o.name.startswith("High_") and o.type == "MESH"]:
        for slot, material in enumerate(obj.data.materials):
            if material is None or not material.use_nodes or "Superhero" not in material.name:
                continue

            image = next(n.image for n in material.node_tree.nodes if n.type == "TEX_IMAGE" and n.image is not None
                         and "Normal" not in n.image.name and "Roughness" not in n.image.name)
            w, h = image.size
            pixels = np.array(image.pixels[:], dtype=np.float32).reshape(h, w, 4)[..., :3]
            uv = obj.data.uv_layers.active.data
            samples = [pixels[min(int(uv[i].uv.y % 1.0 * h), h - 1), min(int(uv[i].uv.x % 1.0 * w), w - 1)]
                       for p in obj.data.polygons if p.material_index == slot for i in p.loop_indices]
            out[obj.name] = tuple(float(c) for c in np.median(np.array(samples), axis=0))
            break

    return out


def case_skin():
    """Bare skin (build.SKIN, the recipes' SKIN_COLOUR) is the colour of
    the detailed heads' skin, on either body: each committed head's skin
    texture, where its faces sample it, is within 0.03 of it (a bare arm
    otherwise shows paler than his face, in every tone)."""
    import build
    import recipes

    messages = [] if tuple(recipes.SKIN_COLOUR) == tuple(build.SKIN) else \
        ["recipes.SKIN_COLOUR %s is not build.SKIN %s" % (recipes.SKIN_COLOUR, build.SKIN)]

    for name in ("heads", "heads_female"):
        bpy.ops.wm.open_mainfile(filepath=str(common.WARDROBE / "source" / ("%s.blend" % name)))
        heads = head_skin()

        if not heads:
            messages.append("%s: no detailed head with a skin texture" % name)

        for head, median in heads.items():
            if max(abs(a - b) for a, b in zip(median, build.SKIN)) > 0.03:
                messages.append("%s's skin %s, bare skin %s" % (head, tuple(round(c, 3) for c in median), build.SKIN))

    fresh()
    return messages


CASES = {"chain": case_chain_bones, "limits": case_limits, "types": case_types, "watchman": case_watchman,
         "hood": case_hood, "launcher": case_launcher, "bodies": case_bodies, "male_parts": case_male_parts,
         "types2": case_types2, "skin": case_skin, "brute_arms": case_brute_arms, "foreign_parts": case_foreign_parts,
         "faces": case_faces, "beards_and_tails": case_beards_and_tails,
         "bare_hat": case_bare_hat, "coif_beards": case_coif_beards,
         "brute_neck": case_brute_neck, "duelist_cape": case_duelist_cape,
         "brute_bracers": case_brute_bracers, "hoods_hold_faces": case_hoods_hold_faces,
         "neck_seams": case_neck_seams, "strips_face_out": case_strips_face_out,
         "shell_edges": case_shell_edges}


def main():
    failed = 0

    for name, run in CASES.items():
        try:
            messages = run()
        except BaseException as error:  # a crash (or a script's exit) fails that case
            messages = ["crash: %r" % error]

        print("%s %s%s" % ("PASS" if not messages else "FAIL", name, "" if not messages else ": %s" % messages))
        failed += 1 if messages else 0

    testkit.tidy()
    left = testkit.leaked()

    if left:
        print("FAIL leak: %d scratch folders left in the temp folder (%s)" % (len(left), left[:2]))
        failed += 1

    print("build: %d/%d" % (len(CASES) + 1 - failed, len(CASES) + 1))
    sys.exit(1 if failed else 0)


main()
