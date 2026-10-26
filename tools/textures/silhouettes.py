"""The candle lane's people (docs/superpowers/specs/2026-10-23-candle-lane-design.md, "People are flat black
silhouettes"; plan Task 6): Quaternius's CC0 base bodies posed by frames of Quaternius's CC0 Universal Animation
Library (assets/characters/animations), dressed in the city's clothes (tools/textures/dressing.py), drawn from the
side as one black shape on clear (Mignola's black), all at one scale, for the lane's cut-outs (Silhouette.gd).

- bargaining: a woman in her skirt and rebozo, her basket on her arm, talking with her hands;
- waiting: a man in his jacket and fedora, his arms folded;
- kneeling_a, kneeling_b: a woman under her rebozo and a man bareheaded, kneeling before the chapel;
- walking_a, walking_b, walking_c: a man in his coat and fedora, a woman in her rebozo, a man under a straw sombrero
  carrying a load: the crowd thickening at the mouth.

And the Pasaje's stallkeepers, behind their counters:
- keeper_counter: a man in his jacket and fedora leaning on his counter on both hands;
- keeper_stir: a woman in her rebozo stirring her pot with a long ladle;
- keeper_fan: a man in his jacket and bowler fanning the coals with a pleated fan;
- keeper_weigh: a man under his sombrero holding up a hand scale;
- keeper_wrap: a man bareheaded wrapping a paper parcel.

    Blender -b --factory-startup --python tools/textures/silhouettes.py [-- --out=PATH] [-- --only=name,name]

Writes textures/painted/underground/silhouettes.png (cells of 256 x 512, COLS across, black, its alpha the shape) and
silhouettes.json ({"cell_m": the cell's height in metres, "poses": [{"name", "cell": [col, row], "height_m", "facing"}]};
"facing" the way the figure faces in its cell, "left" or "right").
"""

import json
import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "eclipse"))
sys.path.insert(0, HERE)

import bpy  # noqa: E402
import numpy as np  # noqa: E402
from mathutils import Matrix, Vector  # noqa: E402

import common  # noqa: E402
import dressing  # noqa: E402
import dressing_city  # noqa: E402

BASE = common.ROOT / "assets" / "characters" / "base"
BODIES = {"man": BASE / "Superhero_Male_FullBody.gltf", "woman": BASE / "Superhero_Female_FullBody.gltf"}
# The other bodies: the base they are made from and how they are sized (x, y, z), posed and dressed full size first,
# so their clothes fit: a newsboy of twelve or so, younger children, a girl; the chaneque, a spirit a child's height;
# the man taller and thinner than anyone.
SIZED = {"boy": ("man", (0.78, 0.78, 0.78)), "child": ("man", (0.7, 0.7, 0.7)),
         "girl": ("woman", (0.72, 0.72, 0.72)), "small": ("man", (0.5, 0.5, 0.5)), "tall": ("man", (0.76, 0.76, 1.09))}
LIBRARIES = common.ROOT / "assets" / "characters" / "animations"
OUT = common.ROOT / "textures" / "painted" / "underground" / "silhouettes.png"
# Each cell's size (px; drawn at twice and averaged) and how many metres its height is; how many cells across.
CELL = (256, 512)
CELL_M = 2.1
COLS = 4
# Kneeling, from standing (degrees about each bone's own axes, found by rendering: X bends a knee back, swings an arm
# hanging at the side forward, and bends an elbow up): both knees down, the shins back along the floor, the feet
# stretched behind; the head bowed. Praying: the hands raised together before the chest. Bowed: the back a little
# bent, the hands clasped at the belt.
KNEEL = {"calf_l": [("X", 90)], "calf_r": [("X", 90)], "foot_l": [("X", 55)], "foot_r": [("X", 55)],
         "neck_01": [("X", 12)], "Head": [("X", 18)]}
PRAYING = {"upperarm_l": [("X", 30)], "upperarm_r": [("X", 30)], "lowerarm_l": [("X", 100)],
           "lowerarm_r": [("X", 100)]}
BOWED = {"spine_01": [("X", 5)], "spine_02": [("X", 5)], "spine_03": [("X", 4)], "neck_01": [("X", 10)],
         "Head": [("X", 12)], "upperarm_l": [("X", 15)], "upperarm_r": [("X", 15)], "lowerarm_l": [("X", 70)],
         "lowerarm_r": [("X", 70)]}
# Wrapping, from leaning on a rail: the back straightened up off it, the hands raised a little over the counter, the
# head bowed over the work.
WRAPPING = {"spine_01": [("X", -9)], "spine_02": [("X", -9)], "spine_03": [("X", -6)], "neck_01": [("X", 8)],
            "Head": [("X", 12)]}
# Laden, walking under a load on the back: bent forward from the hips, the head lifted to see ahead.
LADEN = {"spine_01": [("X", 8)], "spine_02": [("X", 6)], "spine_03": [("X", 4)], "neck_01": [("X", -8)],
         "Head": [("X", -10)]}
# Holding up what she weighs nearer: the elbows bent a little more.
NEARER = {"lowerarm_l": [("X", 30)], "lowerarm_r": [("X", 30)]}
# Stooped with age: the back bent, the head lifted to see ahead.
STOOPED = {"spine_01": [("X", 10)], "spine_02": [("X", 8)], "spine_03": [("X", 6)], "neck_01": [("X", -4)],
           "Head": [("X", -6)]}
# Dazed, the soul gone out of them (susto): the head hung, the shoulders in.
DAZED = {"spine_03": [("X", 6)], "neck_01": [("X", 15)], "Head": [("X", 22)]}
# Entranced, the medium: the head thrown back.
ENTRANCED = {"neck_01": [("X", -18)], "Head": [("X", -28)]}
# The tall man's arms, drawn out past his knees.
LONG_ARMS = {"lowerarm_l": [("S", 1.5)], "lowerarm_r": [("S", 1.5)]}
# The poses: [name, body (a man, a woman, or one of SIZED), library, action, how far through it, extra turns (bone:
# [(axis, degrees)], or ("S", times) to draw a bone out along its length), dress].
POSES = [
    ["bargaining", "woman", "UAL1_Standard.glb", "Idle_Talking_Loop", 0.35, {}, ["skirt", "rebozo", "basket"]],
    ["waiting", "man", "UAL2_Standard.glb", "Idle_FoldArms_Loop", 0.5, {},
     ["jacket", "trousers", "sleeves", "boots", "fedora"]],
    ["kneeling_a", "woman", "UAL1_Standard.glb", "Idle_Loop", 0.0, KNEEL | PRAYING, ["skirt", "rebozo"]],
    ["kneeling_b", "man", "UAL1_Standard.glb", "Idle_Loop", 0.0, KNEEL | BOWED, ["jacket", "trousers", "sleeves", "boots"]],
    ["walking_a", "man", "UAL1_Standard.glb", "Walk_Loop", 0.25, {}, ["coat", "sleeves", "boots", "fedora"]],
    ["walking_b", "woman", "UAL1_Standard.glb", "Walk_Formal_Loop", 0.6, {}, ["skirt", "rebozo"]],
    ["walking_c", "man", "UAL2_Standard.glb", "Walk_Carry_Loop", 0.3, {},
     ["jacket", "trousers", "sleeves", "boots", "sombrero", "crate"]],
    # The Pasaje's stallkeepers (docs/superpowers/specs/2026-10-26-pasaje-market-design.md), behind their counters.
    ["keeper_counter", "man", "UAL2_Standard.glb", "Idle_Rail_Loop", 0.4, {},
     ["shirt_sleeves", "vest", "trousers", "boots", "flat_cap"]],
    ["keeper_stir", "woman", "UAL2_Standard.glb", "Farm_Watering", 0.4, {}, ["dress", "bob", "ladle"]],
    ["keeper_fan", "man", "UAL1_Standard.glb", "Interact", 0.65, {},
     ["jacket", "trousers", "sleeves", "boots", "bowler", "fan"]],
    ["keeper_weigh", "woman", "UAL2_Standard.glb", "Idle_Lantern_Loop", 0.4, NEARER,
     ["narrow_skirt", "shawl", "bun", "scale"]],
    ["keeper_wrap", "man", "UAL2_Standard.glb", "Idle_Rail_Loop", 0.4, WRAPPING,
     ["shirt_sleeves", "vest", "apron", "trousers", "boots", "parcel"]],
    # The city's modern people (dressing_city.py).
    ["pelona", "woman", "UAL1_Standard.glb", "Walk_Formal_Loop", 0.6, {}, ["dress", "bob", "cloche"]],
    ["clerk", "man", "UAL1_Standard.glb", "Walk_Loop", 0.25, {},
     ["jacket", "trousers", "sleeves", "boots", "bowler", "umbrella"]],
    ["lineman", "man", "UAL1_Standard.glb", "Walk_Loop", 0.6, {},
     ["vest", "overalls", "shirt_sleeves", "boots", "flat_cap", "cable_coil"]],
    ["gendarme", "man", "UAL1_Standard.glb", "Idle_Loop", 0.0, {},
     ["jacket", "belt", "trousers", "sleeves", "boots", "kepi", "baton"]],
    # The street trades.
    ["newsboy", "boy", "UAL2_Standard.glb", "Idle_Lantern_Loop", 0.4, {},
     ["jacket", "trousers", "sleeves", "boots", "flat_cap", "papers"]],
    ["water_carrier", "man", "UAL1_Standard.glb", "Walk_Loop", 0.25, LADEN,
     ["shirt_sleeves", "vest", "trousers", "chochocol"]],
    ["porter", "man", "UAL1_Standard.glb", "Walk_Loop", 0.6, LADEN | {"spine_01": [("X", 12)]},
     ["shirt_sleeves", "vest", "trousers", "boots", "load"]],
    ["organ_grinder", "man", "UAL1_Standard.glb", "Interact", 0.65, {},
     ["jacket", "trousers", "sleeves", "boots", "kepi", "organ"]],
    ["sereno", "man", "UAL2_Standard.glb", "Idle_Lantern_Loop", 0.4, {},
     ["greatcoat", "sleeves", "boots", "hood", "capelet", "lantern"]],
    # Old and young.
    ["old_man", "man", "UAL1_Standard.glb", "Walk_Loop", 0.25, STOOPED, ["coat", "sleeves", "boots", "fedora", "cane"]],
    ["grandmother", "woman", "UAL1_Standard.glb", "Walk_Formal_Loop", 0.3, STOOPED,
     ["narrow_skirt", "shawl", "headscarf", "basket"]],
    ["mother", "woman", "UAL2_Standard.glb", "Idle_FoldArms_Loop", 0.5, {}, ["dress", "bun", "baby"]],
    ["running_boy", "child", "UAL1_Standard.glb", "Jog_Fwd_Loop", 0.3, {}, ["shirt_sleeves", "vest", "trousers", "flat_cap"]],
    ["running_girl", "girl", "UAL1_Standard.glb", "Jog_Fwd_Loop", 0.75, {}, ["dress", "bob"]],
    # The church in hiding (the Calles Law: worship suspended from 1926, a cassock fined in the street).
    ["priest", "man", "UAL1_Standard.glb", "Idle_Talking_Loop", 0.35, {},
     ["frock_coat", "sleeves", "trousers", "boots", "fedora", "rosary"]],
    ["nun", "woman", "UAL1_Standard.glb", "Walk_Formal_Loop", 0.6, {}, ["habit", "veil"]],
    ["devotee", "woman", "UAL2_Standard.glb", "Walk_Carry_Loop", 0.3, {}, ["narrow_skirt", "shawl", "headscarf", "saint"]],
    # The uncanny, each from the city's folklore.
    ["nahual_coyote", "man", "UAL1_Standard.glb", "Walk_Loop", 0.6, {},
     ["jacket", "trousers", "sleeves", "boots", "coyote_head", "claws"]],
    ["nahual_jaguar", "woman", "UAL1_Standard.glb", "Walk_Formal_Loop", 0.3, {}, ["dress", "jaguar_head", "claws", "tail"]],
    ["lechuza", "woman", "UAL1_Standard.glb", "Walk_Formal_Loop", 0.6, {}, ["narrow_skirt", "shawl", "wings", "owl_head"]],
    ["curandero", "man", "UAL2_Standard.glb", "Idle_Lantern_Loop", 0.4, {},
     ["shirt_sleeves", "vest", "trousers", "boots", "censer"]],
    ["susto", "woman", "UAL2_Standard.glb", "Idle_FoldArms_Loop", 0.5, DAZED, ["narrow_skirt", "shawl", "bun"]],
    ["medium", "woman", "UAL1_Standard.glb", "Idle_Loop", 0.0, ENTRANCED, ["evening_dress", "bob", "ectoplasm"]],
    ["chaneque", "small", "UAL1_Standard.glb", "Walk_Loop", 0.6, STOOPED, ["big_hat"]],
    ["tall_man", "tall", "UAL1_Standard.glb", "Walk_Loop", 0.25, LONG_ARMS,
     ["greatcoat", "sleeves", "boots", "bowler", "long_fingers"]],
]
# The moving shades (--loops): [name, body, library, action, dress], each a row of LOOP_FRAMES cells through its
# action: four walkers for the crowd, the bargaining woman's talk and the waiting man's shifting weight.
LOOPS_OUT = common.ROOT / "textures" / "painted" / "underground" / "shade_loops.png"
LOOP_FRAMES = 12
LOOPS = [
    ["walk_coat", "man", "UAL1_Standard.glb", "Walk_Loop", ["coat", "sleeves", "boots", "fedora"]],
    ["walk_rebozo", "woman", "UAL1_Standard.glb", "Walk_Formal_Loop", ["skirt", "rebozo"]],
    ["walk_carry", "man", "UAL2_Standard.glb", "Walk_Carry_Loop", ["jacket", "trousers", "sleeves", "boots", "sombrero", "crate"]],
    ["walk_jacket", "man", "UAL1_Standard.glb", "Walk_Formal_Loop", ["jacket", "trousers", "sleeves", "boots", "fedora"]],
    ["talk_bargaining", "woman", "UAL1_Standard.glb", "Idle_Talking_Loop", ["skirt", "rebozo", "basket"]],
    ["idle_waiting", "man", "UAL2_Standard.glb", "Idle_FoldArms_Loop", ["jacket", "trousers", "sleeves", "boots", "fedora"]],
]
# The Pasaje's walkers (--city-loops): [name, body, library, action, dress, turns], each a row of CITY_FRAMES cells
# (fewer than the lane's, so the city's many fit one sheet): its people walking the street.
CITY_LOOPS_OUT = common.ROOT / "textures" / "painted" / "underground" / "shade_loops_city.png"
CITY_FRAMES = 8
CITY_LOOPS = [
    ["city_pelona", "woman", "UAL1_Standard.glb", "Walk_Formal_Loop", ["dress", "bob", "cloche"], {}],
    ["city_clerk", "man", "UAL1_Standard.glb", "Walk_Loop", ["jacket", "trousers", "sleeves", "boots", "bowler"], {}],
    ["city_lineman", "man", "UAL1_Standard.glb", "Walk_Loop",
     ["vest", "overalls", "shirt_sleeves", "boots", "flat_cap", "cable_coil"], {}],
    ["city_newsboy", "boy", "UAL1_Standard.glb", "Walk_Loop", ["jacket", "trousers", "sleeves", "boots", "flat_cap"], {}],
    ["city_water_carrier", "man", "UAL1_Standard.glb", "Walk_Loop", ["shirt_sleeves", "vest", "trousers", "chochocol"],
     "LADEN"],
    ["city_porter", "man", "UAL1_Standard.glb", "Walk_Loop", ["shirt_sleeves", "vest", "trousers", "boots", "load"],
     "LADEN"],
    ["city_old_man", "man", "UAL1_Standard.glb", "Walk_Loop", ["coat", "sleeves", "boots", "fedora", "cane"], "STOOPED"],
    ["city_grandmother", "woman", "UAL1_Standard.glb", "Walk_Formal_Loop", ["narrow_skirt", "shawl", "headscarf", "basket"],
     "STOOPED"],
    ["city_priest", "man", "UAL1_Standard.glb", "Walk_Formal_Loop", ["frock_coat", "sleeves", "trousers", "boots", "fedora"],
     {}],
    ["city_nun", "woman", "UAL1_Standard.glb", "Walk_Formal_Loop", ["habit", "veil"], {}],
    ["city_devotee", "woman", "UAL2_Standard.glb", "Walk_Carry_Loop", ["narrow_skirt", "shawl", "headscarf", "saint"], {}],
    ["city_running", "child", "UAL1_Standard.glb", "Jog_Fwd_Loop", ["shirt_sleeves", "vest", "trousers", "flat_cap"], {}],
    ["city_nahual_coyote", "man", "UAL1_Standard.glb", "Walk_Loop",
     ["jacket", "trousers", "sleeves", "boots", "coyote_head", "claws"], {}],
    ["city_nahual_jaguar", "woman", "UAL1_Standard.glb", "Walk_Formal_Loop", ["dress", "jaguar_head", "claws", "tail"], {}],
    ["city_lechuza", "woman", "UAL1_Standard.glb", "Walk_Formal_Loop", ["narrow_skirt", "shawl", "wings", "owl_head"], {}],
    ["city_susto", "woman", "UAL1_Standard.glb", "Walk_Formal_Loop", ["narrow_skirt", "shawl", "bun"], "DAZED"],
    ["city_tall_man", "tall", "UAL1_Standard.glb", "Walk_Loop", ["greatcoat", "sleeves", "boots", "bowler", "long_fingers"],
     "LONG_ARMS"],
    ["city_chaneque", "small", "UAL1_Standard.glb", "Walk_Loop", ["big_hat"], "STOOPED"],
]


def _rigged(body, library, action_name):
    """A fresh scene with the body on its rig, the action on the rig: (rig, action)."""
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(BODIES[SIZED[body][0] if body in SIZED else body]))
    rig = next(o for o in bpy.data.objects if o.type == "ARMATURE")
    # (Only what hangs on its rig: the file brings a stray icosphere too.)
    for o in [o for o in bpy.data.objects if o.type == "MESH" and o.parent != rig]:
        bpy.data.objects.remove(o, do_unlink=True)
    mine = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=str(LIBRARIES / library))
    action = bpy.data.actions[action_name]
    action.use_fake_user = True
    for o in [o for o in bpy.data.objects if o not in mine]:
        bpy.data.objects.remove(o, do_unlink=True)
    rig.animation_data_create()
    rig.animation_data.action = action
    if len(getattr(action, "slots", [])):
        rig.animation_data.action_slot = action.slots[0]
    return rig, action


def _pose(body, library, action_name, through, turns):
    """The body in its pose at `through` of the action, standing on the floor: its rig and its bones (world)."""
    rig, action = _rigged(body, library, action_name)
    first, last = action.frame_range
    f = first + (last - first) * through
    scene = bpy.context.scene
    scene.frame_set(int(f), subframe=f - int(f))
    _turn(rig, turns)
    # (On the floor, whatever the pose does to its height.)
    low = min(p.z for p in _points())
    rig.location.z -= low
    bpy.context.view_layer.update()
    bones = {pb.name: (rig.matrix_world @ pb.head, rig.matrix_world @ pb.tail) for pb in rig.pose.bones}
    return rig, bones


def _turn(rig, turns):
    """The extra turns on the pose (bone: [(axis, degrees)], or ("S", times) to draw a bone out along its length)."""
    for name, axes in turns.items():
        pb = rig.pose.bones[name]
        pb.rotation_mode = "XYZ"
        for axis, deg in axes:
            if axis == "S":
                # (Drawn out along its own length by `deg` times: the tall man's arms.)
                pb.scale = (1.0, deg, 1.0)
            else:
                pb.rotation_euler.rotate_axis(axis, math.radians(deg))
    bpy.context.view_layer.update()


def _sized(rig, body):
    """The dressed figure brought to its body's size, about its feet: its bones (world) after."""
    if body in SIZED:
        size = Matrix.Diagonal(SIZED[body][1]).to_4x4()
        for o in [o for o in bpy.data.objects if o.parent is None and o.type in ("MESH", "ARMATURE")]:
            o.matrix_world = size @ o.matrix_world
        bpy.context.view_layer.update()
    return {pb.name: (rig.matrix_world @ pb.head, rig.matrix_world @ pb.tail) for pb in rig.pose.bones}


def _points():
    """Every vertex drawn (world), the bodies as posed."""
    depsgraph = bpy.context.evaluated_depsgraph_get()
    points = []
    for o in bpy.data.objects:
        if o.type != "MESH":
            continue
        evaluated = o.evaluated_get(depsgraph)
        mesh = evaluated.to_mesh()
        points += [evaluated.matrix_world @ v.co for v in mesh.vertices]
        evaluated.to_mesh_clear()
    return points


def _dress(bones, dress):
    crown = max(p.z for p in _points())
    for piece in dress:
        if piece == "fedora":
            brim, tip, size = dressing.FEDORA
            dressing.hat(bones, crown, brim, tip, size, seat=True, lift=dressing.FEDORA_LIFT)
        elif piece == "sombrero":
            brim, tip, size = dressing.SOMBRERO
            dressing.hat(bones, crown, brim, tip, size, seat=True, lift=dressing.SOMBRERO_LIFT)
        elif piece == "rebozo":
            dressing.rebozo(bones, crown)
        else:
            (getattr(dressing_city, piece, None) or getattr(dressing, piece))(bones)


def _render(px_file, middle=None):
    """The figure from its side, black on clear, its feet on the image's foot, the cell's scale, its middle (along
    y; by default its own) the cell's; returns the cell's pixels (rows from the top)."""
    if middle is None:
        points = _points()
        middle = (min(p.y for p in points) + max(p.y for p in points)) / 2.0
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_WORKBENCH"
    scene.display.shading.light = "FLAT"
    scene.display.shading.color_type = "SINGLE"
    scene.display.shading.single_color = (0.0, 0.0, 0.0)
    scene.render.film_transparent = True
    scene.render.resolution_x, scene.render.resolution_y = CELL[0] * 2, CELL[1] * 2
    scene.render.image_settings.color_mode = "RGBA"
    camera = bpy.data.objects.get("side")
    if camera is None:
        camera = bpy.data.objects.new("side", bpy.data.cameras.new("side"))
        scene.collection.objects.link(camera)
    camera.data.type = "ORTHO"
    camera.data.ortho_scale = CELL_M
    camera.location = (5.0, middle, CELL_M / 2.0)
    camera.rotation_euler = (math.radians(90.0), 0.0, math.radians(90.0))
    scene.camera = camera
    scene.render.filepath = px_file
    bpy.ops.render.render(write_still=True)
    image = bpy.data.images.load(px_file)
    pixels = np.array(image.pixels[:], np.float32).reshape(CELL[1] * 2, CELL[0] * 2, 4)
    bpy.data.images.remove(image)
    os.remove(px_file)
    return pixels.reshape(CELL[1], 2, CELL[0], 2, 4).mean(axis=(1, 3))[::-1]


def _facing(bones):
    """Which way the figure faces in its cell (its eyes before its head's middle; a kneeler's toes point behind it):
    the image's right is the world's +y (the side eye at +x)."""
    depsgraph = bpy.context.evaluated_depsgraph_get()
    eyes = next(o for o in bpy.data.objects if o.type == "MESH" and o.name.startswith("Eyes"))
    evaluated = eyes.evaluated_get(depsgraph)
    mesh = evaluated.to_mesh()
    ahead = sum(((evaluated.matrix_world @ v.co).y for v in mesh.vertices), 0.0) / len(mesh.vertices)
    evaluated.to_mesh_clear()
    return "right" if ahead > bones["Head"][0].y else "left"


def loops(out, entries=None, frames=LOOP_FRAMES):
    """The moving shades' loops, a row of `frames` cells each, the same scale and look as the still poses; and for
    each, how long a cycle takes and (walking) how far one carries it. (`entries` LOOPS by default: [name, body,
    library, action, dress, and the city's, turns (or a name of the turns above)].)"""
    entries = LOOPS if entries is None else entries
    rows = len(entries)
    sheet = np.zeros((rows * CELL[1], frames * CELL[0], 4), np.float32)
    meta = {"cell_m": CELL_M, "frames": frames, "loops": []}
    for row, entry in enumerate(entries):
        name, body, library, action_name, dress = entry[:5]
        turns = entry[5] if len(entry) > 5 else {}
        turns = globals()[turns] if isinstance(turns, str) else turns
        rig, action = _rigged(body, library, action_name)
        scene = bpy.context.scene
        first, last = action.frame_range
        size = Matrix.Diagonal(SIZED[body][1]).to_4x4() if body in SIZED else Matrix.Identity(4)
        dressing.REACH = None

        def at(f):
            # (The turned bones handed back to the action's quaternions first: an Euler bone ignores them.)
            for bone in turns:
                rig.pose.bones[bone].rotation_mode = "QUATERNION"
            scene.frame_set(int(f), subframe=f - int(f))
            _turn(rig, turns)
            return {pb.name: (rig.matrix_world @ pb.head, rig.matrix_world @ pb.tail) for pb in rig.pose.bones}

        steps = [first + (last - first) * k / frames for k in range(frames)]
        # (One floor and one middle for every frame, so the figure neither bobs off the floor nor slides in its cell.)
        lows, middles = [], []
        for f in steps:
            at(f)
            points = _points()
            lows.append(min(p.z for p in points))
            middles.append((min(p.y for p in points) + max(p.y for p in points)) / 2.0)
        rig.location.z -= min(lows)
        middle = sum(middles) / len(middles)
        # How far a cycle carries it: its planted foot's slide back, frame to frame (walking in place).
        stride = 0.0
        if action_name.startswith(("Walk", "Jog")):
            slides = []
            for f in range(int(first), int(last)):
                a, b = at(f)["ball_l"][0], at(f + 1)["ball_l"][0]
                if a.z < 0.05 and b.z < 0.05 and abs(b.y - a.y) > 1e-4:
                    slides.append(abs(b.y - a.y))
            slides.sort()
            stride = slides[len(slides) // 2] * (last - first) * size[1][1] if slides else 0.0
        middle *= size[1][1]
        height = 0.0
        facing, head, shoulders = "left", [0.0, 0.0], [0.0, 0.0]
        for k, f in enumerate(steps):
            bones = at(f)
            dressed = set(bpy.data.objects)
            if k == 0:
                dressing.REACH = dressing._reaching(bones)
            _dress(bones, dress)
            # (Sized after dressing, so the clothes fit; undone after the frame.)
            for o in [o for o in bpy.data.objects if o.parent is None and o.type in ("MESH", "ARMATURE")]:
                o.matrix_world = size @ o.matrix_world
            bpy.context.view_layer.update()
            bones = {pb.name: (rig.matrix_world @ pb.head, rig.matrix_world @ pb.tail) for pb in rig.pose.bones}
            height = max(height, max(p.z for p in _points()))
            if k == 0:
                facing = _facing(bones)
                head = [round(bones["Head"][1].y - middle, 3), round(bones["Head"][1].z, 3)]
                shoulders = [round(bones["spine_03"][1].y - middle, 3), round(bones["spine_03"][1].z, 3)]
            cell = _render(str(out) + ".cell.png", middle)
            sheet[row * CELL[1]:(row + 1) * CELL[1], k * CELL[0]:(k + 1) * CELL[0]] = cell
            rig.matrix_world = size.inverted() @ rig.matrix_world
            # (The frame's clothes undressed again; the eye stays.)
            for o in [o for o in bpy.data.objects if o not in dressed and o.type == "MESH"]:
                mesh = o.data
                bpy.data.objects.remove(o, do_unlink=True)
                if mesh.users == 0:
                    bpy.data.meshes.remove(mesh)
        fps = scene.render.fps / scene.render.fps_base
        meta["loops"].append({"name": name, "row": row, "height_m": round(height, 3), "facing": facing,
                              "seconds": round((last - first) / fps, 3), "stride_m": round(stride, 3), "head": head,
                              "shoulders": shoulders})
        print("loop %s: %.2f m, %.2f s, stride %.2f m" % (name, height, (last - first) / fps, stride))
    sheet[..., :3] = 0.0
    image = bpy.data.images.new("shade_loops", sheet.shape[1], sheet.shape[0], alpha=True)
    image.pixels = sheet[::-1].ravel()
    image.filepath_raw = str(out)
    image.file_format = "PNG"
    image.save()
    with open(os.path.splitext(str(out))[0] + ".json", "w") as f:
        json.dump(meta, f, indent=1)
    print("wrote", out)


def check_hats():
    """Prints `HATS {name: {"skull_in_crown", "tilt_deg", "off_m"}}` for every hatted pose (still and looped): whether
    the top of its skull lies inside its hat's crown, how far the crown leans off the head's own up, and how far its
    band's middle is off the line up the head through the skull's top."""
    hats = {}
    worn = [(p[0], p[1], p[2], p[3], p[4], p[5], p[6]) for p in POSES] + \
        [("%s@%.1f" % (l[0], t), l[1], l[2], l[3], t, {}, l[4]) for l in LOOPS for t in (0.0, 0.5)]
    for name, body, library, action, through, turns, dress in worn:
        if not any(piece in dressing.HATS for piece in dress):
            continue
        rig, bones = _pose(body, library, action, through, turns)
        _dress(bones, dress)
        skull = dressing.skull_top(bones)
        up, _ = dressing.head_frame()
        crown = bpy.data.objects["crown"].data
        inside = all((skull - f.center).dot(f.normal) < 0.0 for f in crown.polygons)
        # (The crown's rings lofted from its band up: its first ring the band, its last the top.)
        ring = len(crown.vertices) // 4
        band = sum((v.co for v in crown.vertices[:ring]), Vector()) / ring
        top = sum((v.co for v in crown.vertices[-ring:]), Vector()) / ring
        tilt = math.degrees((top - band).angle(up))
        # (How far the band's middle is off the line up the head through its skull's top.)
        off = ((band - skull) - up * (band - skull).dot(up)).length
        hats[name] = {"skull_in_crown": inside, "tilt_deg": round(tilt, 1), "off_m": round(off, 3)}
    print("HATS " + json.dumps(hats))


def main():
    out = OUT
    only = None
    args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    for arg in args:
        if arg.startswith("--out="):
            out = arg[len("--out="):]
        elif arg.startswith("--only="):
            only = arg[len("--only="):].split(",")
    if "--loops" in args:
        loops(out if out != OUT else LOOPS_OUT)
        return
    if "--city-loops" in args:
        loops(out if out != OUT else CITY_LOOPS_OUT, CITY_LOOPS, CITY_FRAMES)
        return
    if "--check-hats" in args:
        check_hats()
        return
    rows = (len(POSES) + COLS - 1) // COLS
    sheet = np.zeros((rows * CELL[1], COLS * CELL[0], 4), np.float32)
    meta = {"cell_m": CELL_M, "poses": []}
    for k, (name, body, library, action, through, turns, dress) in enumerate(POSES):
        row, col = divmod(k, COLS)
        if only is not None and name not in only:
            continue
        rig, bones = _pose(body, library, action, through, turns)
        _dress(bones, dress)
        bones = _sized(rig, body)
        height = max(p.z for p in _points())
        points = _points()
        middle = (min(p.y for p in points) + max(p.y for p in points)) / 2.0
        cell = _render(str(out) + ".cell.png")
        sheet[row * CELL[1]:(row + 1) * CELL[1], col * CELL[0]:(col + 1) * CELL[0]] = cell
        # (Where its head's crown and its shoulders are in its cell, m: across from its middle (the image's right
        # +), up from its foot; its smoke rises from them.)
        crown, shoulders = bones["Head"][1], bones["spine_03"][1]
        meta["poses"].append({"name": name, "cell": [col, row], "height_m": round(height, 3), "facing": _facing(bones),
                              "body": body,
                              "head": [round(crown.y - middle, 3), round(crown.z, 3)],
                              "shoulders": [round(shoulders.y - middle, 3), round(shoulders.z, 3)]})
        print("pose %s: %.2f m, facing %s" % (name, height, meta["poses"][-1]["facing"]))
    sheet[..., :3] = 0.0
    image = bpy.data.images.new("silhouettes", sheet.shape[1], sheet.shape[0], alpha=True)
    image.pixels = sheet[::-1].ravel()
    image.filepath_raw = str(out)
    image.file_format = "PNG"
    image.save()
    with open(os.path.splitext(str(out))[0] + ".json", "w") as f:
        json.dump(meta, f, indent=1)
    print("wrote", out)


if __name__ == "__main__":
    main()
