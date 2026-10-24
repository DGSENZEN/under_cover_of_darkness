"""The librarian's ownerless shadow (docs/superpowers/specs/2026-10-17-librarian-shop-design.md, "Shadows"): a tall man
in the wide-brimmed hat and long coat that hang on his stand in the corner, walking, drawn from the side as one black
shape on clear (Mignola's black), for the shop's decal to throw on the shelves' fronts.

Quaternius's CC0 male base body (assets/characters/base) posed mid-stride, dressed in shapes built round its posed
bones (only the outline counts): a greatcoat to mid-shin whose skirt opens over the stride and trails behind, its
sleeves, a turned-up collar, boots, a wide-brimmed felt hat with a pinched crown.

Walking (--walk): the same man dressed the same way on each of WALK_FRAMES frames of Quaternius's CC0 formal walk
(assets/characters/animations, Universal Animation Library 1, Walk_Formal_Loop: in place, on the base body's rig),
from one fixed eye, the frames laid in a sheet; beside it, how far one cycle of his stride carries him.

    Blender -b --factory-startup --python tools/textures/librarian_shadow.py [-- --out=PATH] [-- --walk]

Writes textures/painted/underground/librarian_shadow.png (512 x 1024, black, its alpha the shape), or with --walk
librarian_shadow_walk.png (WALK_COLS x WALK_ROWS cells of 256 x 512, the first top left, along each row) and
librarian_shadow_walk.json ({"frames", "cols", "rows", "stride": one cycle's travel, of the picture's height}).
"""

import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "eclipse"))

import bmesh  # noqa: E402
import bpy  # noqa: E402
from mathutils import Vector  # noqa: E402

import common  # noqa: E402

BODY = common.ROOT / "assets" / "characters" / "base" / "Superhero_Male_FullBody.gltf"
OUT = common.ROOT / "textures" / "painted" / "underground" / "librarian_shadow.png"
WALK = common.ROOT / "assets" / "characters" / "animations" / "UAL1_Standard.glb"
WALK_ACTION = "Walk_Formal_Loop"
WALK_OUT = common.ROOT / "textures" / "painted" / "underground" / "librarian_shadow_walk.png"
# How many frames of the cycle, in how many columns and rows; each cell's size (px), drawn at twice that and averaged.
WALK_FRAMES = 16
WALK_COLS = 4
WALK_ROWS = 4
WALK_CELL = (256, 512)
# His stride (each bone's turns, degrees, about its own axes, in order; found by rendering: -X swings a thigh
# forward, X bends a knee back and an elbow forward, Z brings an arm down from the base body's T).
STRIDE = {"spine_01": [("X", -4)], "spine_02": [("X", -4)], "spine_03": [("X", -3)], "neck_01": [("X", 4)],
          "Head": [("X", 4)],
          "thigh_l": [("X", -20)], "calf_l": [("X", 6)], "foot_l": [("X", 8)],
          "thigh_r": [("X", 13)], "calf_r": [("X", 22)], "foot_r": [("X", -12)],
          "upperarm_l": [("Z", -78), ("X", -16)], "lowerarm_l": [("X", 12)],
          "upperarm_r": [("Z", 78), ("X", 22)], "lowerarm_r": [("X", 24)]}
# His fingers loosely curled (Z, the way the arms came down: the left's negative, the right's positive).
for _finger in ("index", "middle", "ring", "pinky"):
    for _joint, _deg in (("01", 28), ("02", 38), ("03", 30)):
        STRIDE["%s_%s_l" % (_finger, _joint)] = [("Z", -_deg)]
        STRIDE["%s_%s_r" % (_finger, _joint)] = [("Z", _deg)]
# The coat: its hem's height (m, of the base body's 1.81), how far it stands off the body front and back, how much
# its skirt flares by the hem (front, back) and how wide it hangs; its sleeves' radius at the shoulder and the cuff.
HEM = 0.4
COAT_OFF = (0.1, 0.12)
FLARE = (0.04, 0.1)
COAT_WIDE = (0.21, 0.27)
SLEEVE = (0.075, 0.062)
# How far the skirt may draw in from one ring to the next going down (m).
DRAPE = 0.006
# The hat: its brim's radius and how far it tips forward (degrees), its crown's radius and height.
BRIM = 0.215
BRIM_TIP = 8.0
CROWN = (0.096, 0.105)


def _ring(centre, rx, ry, n=32, z_axis=None):
    """A horizontal ellipse round `centre` (x across, y along the body), or one square to `z_axis`."""
    pts = []
    if z_axis is None:
        for k in range(n):
            a = 2 * math.pi * k / n
            pts.append(Vector((centre.x + rx * math.cos(a), centre.y + ry * math.sin(a), centre.z)))
        return pts
    z = z_axis.normalized()
    u = z.cross(Vector((1, 0, 0)) if abs(z.x) < 0.9 else Vector((0, 1, 0))).normalized()
    v = z.cross(u)
    return [centre + u * rx * math.cos(2 * math.pi * k / n) + v * ry * math.sin(2 * math.pi * k / n) for k in range(n)]


def _loft(name, rings):
    """A closed solid through `rings` (each the same count), capped at both ends."""
    bm = bmesh.new()
    loops = [[bm.verts.new(p) for p in ring] for ring in rings]
    n = len(rings[0])
    for a, b in zip(loops, loops[1:]):
        for k in range(n):
            bm.faces.new([a[k], a[(k + 1) % n], b[(k + 1) % n], b[k]])
    bm.faces.new(loops[0][::-1])
    bm.faces.new(loops[-1])
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(obj)
    return obj


def _posed():
    """The base body in his stride, its pose baked in; and its bones' heads and tails (world)."""
    bpy.ops.import_scene.gltf(filepath=str(BODY))
    rig = next(o for o in bpy.data.objects if o.type == "ARMATURE")
    body = max((o for o in bpy.data.objects if o.type == "MESH"), key=lambda o: len(o.data.vertices))
    for pb in rig.pose.bones:
        pb.rotation_mode = "XYZ"
        for axis, deg in STRIDE.get(pb.name, []):
            pb.rotation_euler.rotate_axis(axis, math.radians(deg))
    bpy.context.view_layer.update()
    bones = {pb.name: (rig.matrix_world @ pb.head, rig.matrix_world @ pb.tail) for pb in rig.pose.bones}
    with bpy.context.temp_override(active_object=body, object=body, selected_objects=[body],
                                   selected_editable_objects=[body]):
        for mod in list(body.modifiers):
            if mod.type == "ARMATURE":
                bpy.ops.object.modifier_apply(modifier=mod.name)
    # (Standing on the floor whatever the stride does to his height.)
    low = min((body.matrix_world @ v.co).z for v in body.data.vertices)
    for o in bpy.data.objects:
        if o.parent is None:
            o.location.z -= low
    for name in bones:
        h, t = bones[name]
        bones[name] = (h - Vector((0, 0, low)), t - Vector((0, 0, low)))
    return bones


def _on_leg(bones, side, z):
    """Where his leg on `side` is at height `z` (its thigh's or calf's line), along y; below a lifted leg's lowest
    point, that point's (so the coat keeps over both legs as a foot swings up behind)."""
    for part in ("thigh_" + side, "calf_" + side):
        a, b = bones[part]
        if min(a.z, b.z) <= z <= max(a.z, b.z) and abs(a.z - b.z) > 1e-6:
            return a.y + (b.y - a.y) * (z - a.z) / (b.z - a.z)
    points = [p for part in ("thigh_" + side, "calf_" + side) for p in bones[part]]
    lowest = min(points, key=lambda p: p.z)
    return lowest.y if z < lowest.z else None


def coat(bones):
    """The greatcoat: its body round his spine, its skirt from the waist to the hem over both legs, opening over
    the forward leg and trailing behind, its collar turned up."""
    waist = bones["pelvis"][0].z + 0.02
    rings = []
    # The body, from the waist to the shoulders, round the spine's line.
    spine = [bones["pelvis"][0], bones["spine_01"][1], bones["spine_02"][1], bones["spine_03"][1]]
    for k, p in enumerate(spine):
        t = k / (len(spine) - 1)
        rings.append(_ring(Vector((p.x, p.y + 0.01, p.z if k else waist)), 0.2 + 0.04 * t, 0.13 + 0.01 * t))
    # Over the shoulders, rounding in to the neck.
    top = bones["spine_03"][1]
    neck = bones["neck_01"][0]
    rings.append(_ring(Vector((top.x, top.y + 0.02, top.z + 0.04)), 0.21, 0.1))
    rings.append(_ring(Vector((neck.x, neck.y + 0.02, neck.z + 0.02)), 0.11, 0.1))
    # (Its collar turned up round his neck, higher at the back: the coat's own top, so no ledge where they meet.)
    rings.append(_ring(Vector((neck.x, neck.y + 0.035, neck.z + 0.09)), 0.085, 0.08))
    rings.reverse()
    # The skirt, down to the hem.
    # (Cloth falls from what holds it out: going down, the skirt never draws in by more than DRAPE a ring, so a knee
    # swung forward holds it out below the knee rather than cutting it back.)
    steps = 10
    was = None
    for k in range(1, steps + 1):
        z = waist + (HEM - waist) * k / steps
        f = k / steps
        ys = [y for y in (_on_leg(bones, "l", z), _on_leg(bones, "r", z)) if y is not None]
        front = min(ys) - COAT_OFF[0] - FLARE[0] * f
        back = max(ys) + COAT_OFF[1] + FLARE[1] * f * f
        if was is not None:
            front = min(front, was[0] + DRAPE)
            back = max(back, was[1] - DRAPE)
        was = (front, back)
        rings.append(_ring(Vector((0.0, (front + back) / 2, z)), COAT_WIDE[0] + (COAT_WIDE[1] - COAT_WIDE[0]) * f,
                           (back - front) / 2))
    _loft("coat", rings)



def sleeves(bones):
    """His sleeves along each arm, wider than it, to the wrist."""
    for side in ("l", "r"):
        shoulder, elbow = bones["upperarm_" + side]
        wrist = bones["lowerarm_" + side][1]
        axis_up, axis_low = elbow - shoulder, wrist - elbow
        _loft("sleeve_" + side, [_ring(shoulder, SLEEVE[0], SLEEVE[0], 12, axis_up),
                                 _ring(elbow, (SLEEVE[0] + SLEEVE[1]) / 2, (SLEEVE[0] + SLEEVE[1]) / 2, 12, axis_up),
                                 _ring(elbow, (SLEEVE[0] + SLEEVE[1]) / 2, (SLEEVE[0] + SLEEVE[1]) / 2, 12, axis_low),
                                 _ring(wrist - axis_low.normalized() * 0.01, SLEEVE[1], SLEEVE[1], 12, axis_low)])


def boots(bones):
    """His boots: a shaft up the shin, the foot from heel to toe."""
    for side in ("l", "r"):
        ankle = bones["calf_" + side][1]
        shin = bones["calf_" + side][0] + (ankle - bones["calf_" + side][0]) * 0.6
        ball = bones["foot_" + side][1]
        toe = bones["ball_" + side][1]
        _loft("shaft_" + side, [_ring(shin, 0.047, 0.047, 24, ankle - shin), _ring(ankle, 0.045, 0.045, 24, ankle - shin)])
        # (The foot along its own way, heel to toe, its sole on the foot's line.)
        along = (toe - ankle).normalized()
        heel = ankle - along * 0.04
        _loft("foot_" + side, [_ring(heel + Vector((0, 0, -0.04)), 0.038, 0.028, 24, along),
                               _ring(ankle + Vector((0, 0, -0.028)), 0.045, 0.044, 24, along),
                               _ring(ball + Vector((0, 0, 0.012)), 0.043, 0.025, 24, along),
                               _ring(toe - along * 0.02 + Vector((0, 0, 0.011)), 0.026, 0.017, 24, along)])


def hat(bones, crown):
    """His wide-brimmed felt hat, tipped a little forward, set on the top of his head (`crown`): the brim dipping at
    its front and back, the crown pinched toward its top."""
    head = bones["Head"][1]
    at = Vector((head.x, head.y + 0.01, crown - 0.075))
    tip = math.radians(BRIM_TIP)
    up = Vector((0, -math.sin(tip), math.cos(tip)))

    def tipped(p):
        # (Tipped forward about the hat's band: its front down.)
        d = p - at
        return at + Vector((d.x, d.y * math.cos(tip) - d.z * math.sin(tip), d.y * math.sin(tip) + d.z * math.cos(tip)))

    brim = []
    for k, (r, z) in enumerate([(BRIM, -0.012), (BRIM, 0.0)]):
        ring = []
        for j in range(24):
            a = 2 * math.pi * j / 24
            # (Its brim curls down at the front and back, up at the sides.)
            dip = -0.022 * abs(math.sin(a)) + 0.008 * abs(math.cos(a))
            ring.append(tipped(at + Vector((r * math.cos(a), r * math.sin(a), z + dip))))
        brim.append(ring)
    _loft("brim", brim)
    rx, h = CROWN
    _loft("crown", [[tipped(p) for p in _ring(at + Vector((0, 0, -0.005)), rx, rx * 0.92, 24)],
                    [tipped(p) for p in _ring(at + Vector((0, 0, h * 0.6)), rx * 0.97, rx * 0.86, 24)],
                    [tipped(p) for p in _ring(at + Vector((0, 0, h * 0.92)), rx * 0.82, rx * 0.66, 24)],
                    [tipped(p) for p in _ring(at + Vector((0, 0, h)), rx * 0.55, rx * 0.4, 24)]])
    return up


def _eye(scene, top, middle, px):
    """The fixed side eye: the image's foot at the floor, `top` its height (m), the frames black on clear."""
    scene.render.engine = "BLENDER_WORKBENCH"
    scene.display.shading.light = "FLAT"
    scene.display.shading.color_type = "SINGLE"
    scene.display.shading.single_color = (0.0, 0.0, 0.0)
    scene.render.film_transparent = True
    scene.render.resolution_x, scene.render.resolution_y = px
    scene.render.image_settings.color_mode = "RGBA"
    camera = bpy.data.objects.new("side", bpy.data.cameras.new("side"))
    scene.collection.objects.link(camera)
    camera.data.type = "ORTHO"
    camera.data.ortho_scale = top
    # From his side, walking toward the image's left.
    camera.location = (5.0, middle, top / 2.0)
    camera.rotation_euler = (math.radians(90.0), 0.0, math.radians(90.0))
    scene.camera = camera


def walk(out):
    """His formal walk, frame by frame, dressed, in a sheet; and how far a cycle carries him."""
    import json

    import numpy as np

    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(BODY))
    rig = next(o for o in bpy.data.objects if o.type == "ARMATURE")
    body = max((o for o in bpy.data.objects if o.type == "MESH"), key=lambda o: len(o.data.vertices))
    mine = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=str(WALK))
    action = bpy.data.actions[WALK_ACTION]
    action.use_fake_user = True
    for o in [o for o in bpy.data.objects if o not in mine]:
        bpy.data.objects.remove(o, do_unlink=True)
    rig.animation_data_create()
    rig.animation_data.action = action
    if len(getattr(action, "slots", [])):
        rig.animation_data.action_slot = action.slots[0]
    scene = bpy.context.scene
    first, last = action.frame_range

    def at(f):
        scene.frame_set(int(f), subframe=f - int(f))
        bones = {pb.name: (rig.matrix_world @ pb.head, rig.matrix_world @ pb.tail) for pb in rig.pose.bones}
        evaluated = body.evaluated_get(bpy.context.evaluated_depsgraph_get())
        shape = evaluated.to_mesh()
        crown = max((body.matrix_world @ v.co).z for v in shape.vertices)
        evaluated.to_mesh_clear()
        return bones, crown

    # How far a cycle carries him: his planted foot's slide back, frame to frame, over the cycle.
    slides = []
    for f in range(int(first), int(last)):
        a, b = at(f)[0]["ball_l"][0], at(f + 1)[0]["ball_l"][0]
        if a.z < 0.04 and b.z < 0.04 and b.y > a.y:
            slides.append(b.y - a.y)
    slides.sort()
    stride = slides[len(slides) // 2] * (last - first)

    # One eye for every frame: as tall as his highest, hat and all.
    top = (max(at(first + (last - first) * k / WALK_FRAMES)[1] for k in range(WALK_FRAMES)) + 0.06) * 1.04
    _eye(scene, top, 0.0, (WALK_CELL[0] * 2, WALK_CELL[1] * 2))
    sheet = np.zeros((WALK_ROWS * WALK_CELL[1], WALK_COLS * WALK_CELL[0], 4), np.float32)
    frame_file = str(out) + ".frame.png"
    for k in range(WALK_FRAMES):
        bones, crown = at(first + (last - first) * k / WALK_FRAMES)
        dressed = set(bpy.data.objects)
        coat(bones)
        sleeves(bones)
        boots(bones)
        hat(bones, crown)
        scene.render.filepath = frame_file
        bpy.ops.render.render(write_still=True)
        image = bpy.data.images.load(frame_file)
        px = np.array(image.pixels[:], np.float32).reshape(WALK_CELL[1] * 2, WALK_CELL[0] * 2, 4)
        bpy.data.images.remove(image)
        # (Averaged down by two; Blender's rows run from the foot up, the sheet's from the top down.)
        cell = px.reshape(WALK_CELL[1], 2, WALK_CELL[0], 2, 4).mean(axis=(1, 3))[::-1]
        row, col = divmod(k, WALK_COLS)
        sheet[row * WALK_CELL[1]:(row + 1) * WALK_CELL[1], col * WALK_CELL[0]:(col + 1) * WALK_CELL[0]] = cell
        for o in [o for o in bpy.data.objects if o not in dressed]:
            mesh = o.data
            bpy.data.objects.remove(o, do_unlink=True)
            bpy.data.meshes.remove(mesh)
    os.remove(frame_file)
    sheet[..., :3] = 0.0
    image = bpy.data.images.new("librarian_shadow_walk", sheet.shape[1], sheet.shape[0], alpha=True)
    image.pixels = sheet[::-1].ravel()
    image.filepath_raw = str(out)
    image.file_format = "PNG"
    image.save()
    with open(os.path.splitext(str(out))[0] + ".json", "w") as f:
        json.dump({"frames": WALK_FRAMES, "cols": WALK_COLS, "rows": WALK_ROWS, "stride": round(stride / top, 4)}, f)
    print("wrote", out, "stride %.3f m of %.3f" % (stride, top))


def main():
    out = OUT
    args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    for arg in args:
        if arg.startswith("--out="):
            out = arg[len("--out="):]
    if "--walk" in args:
        walk(out if out != OUT else WALK_OUT)
        return

    bpy.ops.wm.read_factory_settings(use_empty=True)
    bones = _posed()
    crown = max((o.matrix_world @ v.co).z for o in bpy.data.objects if o.type == "MESH" for v in o.data.vertices)
    coat(bones)
    sleeves(bones)
    boots(bones)
    hat(bones, crown)

    points = [o.matrix_world @ v.co for o in bpy.data.objects if o.type == "MESH" for v in o.data.vertices]
    top = max(p.z for p in points)
    middle = (min(p.y for p in points) + max(p.y for p in points)) / 2.0
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_WORKBENCH"
    scene.display.shading.light = "FLAT"
    scene.display.shading.color_type = "SINGLE"
    scene.display.shading.single_color = (0.0, 0.0, 0.0)
    scene.render.film_transparent = True
    scene.render.resolution_x, scene.render.resolution_y = 512, 1024
    scene.render.image_settings.color_mode = "RGBA"
    camera = bpy.data.objects.new("side", bpy.data.cameras.new("side"))
    scene.collection.objects.link(camera)
    camera.data.type = "ORTHO"
    camera.data.ortho_scale = top * 1.04
    # From his side, walking toward the image's right.
    camera.location = (5.0, middle, top / 2.0)
    camera.rotation_euler = (math.radians(90.0), 0.0, math.radians(90.0))
    scene.camera = camera
    scene.render.filepath = str(out)
    bpy.ops.render.render(write_still=True)
    print("wrote", out)


if __name__ == "__main__":
    main()
