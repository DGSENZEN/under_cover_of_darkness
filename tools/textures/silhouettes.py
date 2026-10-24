"""The candle lane's people (docs/superpowers/specs/2026-10-23-candle-lane-design.md, "People are flat black
silhouettes"; plan Task 6): Quaternius's CC0 base bodies posed by frames of Quaternius's CC0 Universal Animation
Library (assets/characters/animations), dressed in the city's clothes (tools/textures/dressing.py), drawn from the
side as one black shape on clear (Mignola's black), all at one scale, for the lane's cut-outs (Silhouette.gd).

- bargaining: a woman in her skirt and rebozo, her basket on her arm, talking with her hands;
- waiting: a man in his jacket and fedora, his arms folded;
- kneeling_a, kneeling_b: a woman under her rebozo and a man bareheaded, kneeling before the chapel;
- walking_a, walking_b, walking_c: a man in his coat and fedora, a woman in her rebozo, a man under a straw sombrero
  carrying a load: the crowd thickening at the mouth.

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
from mathutils import Vector  # noqa: E402

import common  # noqa: E402
import dressing  # noqa: E402

BASE = common.ROOT / "assets" / "characters" / "base"
BODIES = {"man": BASE / "Superhero_Male_FullBody.gltf", "woman": BASE / "Superhero_Female_FullBody.gltf"}
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
# The poses: [name, body, library, action, how far through it, extra turns (bone: [(axis, degrees)]), dress].
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


def _rigged(body, library, action_name):
    """A fresh scene with the body on its rig, the action on the rig: (rig, action)."""
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(BODIES[body]))
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
    for name, axes in turns.items():
        pb = rig.pose.bones[name]
        pb.rotation_mode = "XYZ"
        for axis, deg in axes:
            pb.rotation_euler.rotate_axis(axis, math.radians(deg))
    bpy.context.view_layer.update()
    # (On the floor, whatever the pose does to its height.)
    low = min(p.z for p in _points())
    rig.location.z -= low
    bpy.context.view_layer.update()
    bones = {pb.name: (rig.matrix_world @ pb.head, rig.matrix_world @ pb.tail) for pb in rig.pose.bones}
    return rig, bones


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
            dressing.hat(bones, crown, brim, tip, size)
        elif piece == "sombrero":
            brim, tip, size = dressing.SOMBRERO
            dressing.hat(bones, crown, brim, tip, size)
        elif piece == "rebozo":
            dressing.rebozo(bones, crown)
        else:
            getattr(dressing, piece)(bones)


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


def loops(out):
    """The moving shades' loops, a row of LOOP_FRAMES cells each, the same scale and look as the still poses; and for
    each, how long a cycle takes and (walking) how far one carries it."""
    rows = len(LOOPS)
    sheet = np.zeros((rows * CELL[1], LOOP_FRAMES * CELL[0], 4), np.float32)
    meta = {"cell_m": CELL_M, "frames": LOOP_FRAMES, "loops": []}
    for row, (name, body, library, action_name, dress) in enumerate(LOOPS):
        rig, action = _rigged(body, library, action_name)
        scene = bpy.context.scene
        first, last = action.frame_range

        def at(f):
            scene.frame_set(int(f), subframe=f - int(f))
            return {pb.name: (rig.matrix_world @ pb.head, rig.matrix_world @ pb.tail) for pb in rig.pose.bones}

        steps = [first + (last - first) * k / LOOP_FRAMES for k in range(LOOP_FRAMES)]
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
        if action_name.startswith("Walk"):
            slides = []
            for f in range(int(first), int(last)):
                a, b = at(f)["ball_l"][0], at(f + 1)["ball_l"][0]
                if a.z < 0.05 and b.z < 0.05 and abs(b.y - a.y) > 1e-4:
                    slides.append(abs(b.y - a.y))
            slides.sort()
            stride = slides[len(slides) // 2] * (last - first) if slides else 0.0
        height = 0.0
        facing, head, shoulders = "left", [0.0, 0.0], [0.0, 0.0]
        for k, f in enumerate(steps):
            bones = at(f)
            dressed = set(bpy.data.objects)
            _dress(bones, dress)
            height = max(height, max(p.z for p in _points()))
            if k == 0:
                facing = _facing(bones)
                head = [round(bones["Head"][1].y - middle, 3), round(bones["Head"][1].z, 3)]
                shoulders = [round(bones["spine_03"][1].y - middle, 3), round(bones["spine_03"][1].z, 3)]
            cell = _render(str(out) + ".cell.png", middle)
            sheet[row * CELL[1]:(row + 1) * CELL[1], k * CELL[0]:(k + 1) * CELL[0]] = cell
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
    rows = (len(POSES) + COLS - 1) // COLS
    sheet = np.zeros((rows * CELL[1], COLS * CELL[0], 4), np.float32)
    meta = {"cell_m": CELL_M, "poses": []}
    for k, (name, body, library, action, through, turns, dress) in enumerate(POSES):
        row, col = divmod(k, COLS)
        if only is not None and name not in only:
            continue
        rig, bones = _pose(body, library, action, through, turns)
        _dress(bones, dress)
        height = max(p.z for p in _points())
        points = _points()
        middle = (min(p.y for p in points) + max(p.y for p in points)) / 2.0
        cell = _render(str(out) + ".cell.png")
        sheet[row * CELL[1]:(row + 1) * CELL[1], col * CELL[0]:(col + 1) * CELL[0]] = cell
        # (Where its head's crown and its shoulders are in its cell, m: across from its middle (the image's right
        # +), up from its foot; its smoke rises from them.)
        crown, shoulders = bones["Head"][1], bones["spine_03"][1]
        meta["poses"].append({"name": name, "cell": [col, row], "height_m": round(height, 3), "facing": _facing(bones),
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
