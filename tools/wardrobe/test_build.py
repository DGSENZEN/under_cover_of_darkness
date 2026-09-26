"""The build's own parts (build.py, common.py), on tiny scenes.

    tools/wardrobe/wardrobe.sh test

Each case builds a little and checks what came out. Runs in a
factory-fresh Blender, headless. Exit code 1 on any failure.
"""

import os
import sys

# No __pycache__ beside the tools (Blender would write one each run).
sys.dont_write_bytecode = True
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import bpy  # noqa: E402
from mathutils import Vector  # noqa: E402
from mathutils.bvhtree import BVHTree  # noqa: E402

import common  # noqa: E402


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


def case_types():
    """Every garment type batch 1 adds builds on the male body, rides the
    bones and chains it should, and passes every export rule."""
    import json
    import tempfile
    from pathlib import Path

    import build
    import validate

    fresh()
    folder = Path(tempfile.mkdtemp(prefix="wardrobe_types_"))
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


def case_watchman():
    """The watchman the user approved rebuilds as he was: today's pipeline,
    run on his recipe, gives back source/watchman.blend (the same triangles
    per part, every vertex where it was with the weights it had, the same
    chains and cloth bones). Vertex order varies run to run: vertices are
    matched by place, within 0.1 mm."""
    import json
    import tempfile
    from pathlib import Path

    from mathutils.kdtree import KDTree

    import build
    import recipes

    source = common.WARDROBE / "source"
    approved = source / "watchman.blend"
    fresh()
    folder = Path(tempfile.mkdtemp(prefix="wardrobe_watchman_"))
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

    def weights(obj):
        names = {g.index: g.name for g in obj.vertex_groups}
        return [{names[g.group]: g.weight for g in v.groups if g.weight > 1e-4} for v in obj.data.vertices]

    def same(a, b):
        return a.keys() == b.keys() and all(abs(a[k] - b[k]) < 1e-3 for k in a)

    def strays(a, b):
        """a's vertices with no vertex of b within 0.1 mm carrying its weights."""
        tree = KDTree(len(b.data.vertices))

        for v in b.data.vertices:
            tree.insert(v.co, v.index)

        tree.balance()
        wa, wb = weights(a), weights(b)
        return [v.co.copy() for v in a.data.vertices
                if not any(same(wa[v.index], wb[i]) for _, i, _ in tree.find_range(v.co, 1e-4))]

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

    folder = Path(tempfile.mkdtemp(prefix="wardrobe_launcher_"))
    broken = folder / "python3"
    broken.write_text("#!/bin/sh\nexit 1\n")
    broken.chmod(0o755)
    env = dict(os.environ, PATH="%s:%s" % (folder, os.environ.get("PATH", "")), BLENDER="true")
    script = Path(__file__).resolve().parent / "wardrobe.sh"
    done = subprocess.run(["bash", str(script), "check", "all"], env=env, capture_output=True, text=True)
    return [] if done.returncode != 0 else ["launcher: `check all` exited 0 though it could not tell the kinds"]


CASES = {"chain": case_chain_bones, "limits": case_limits, "types": case_types, "watchman": case_watchman,
         "hood": case_hood, "launcher": case_launcher}


def main():
    failed = 0

    for name, run in CASES.items():
        try:
            messages = run()
        except BaseException as error:  # a crash (or a script's exit) fails that case
            messages = ["crash: %r" % error]

        print("%s %s%s" % ("PASS" if not messages else "FAIL", name, "" if not messages else ": %s" % messages))
        failed += 1 if messages else 0

    print("build: %d/%d" % (len(CASES) - failed, len(CASES)))
    sys.exit(1 if failed else 0)


main()
