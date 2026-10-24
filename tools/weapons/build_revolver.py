"""The Prosecutor's revolver, after Abrams' Case Closed in Deadlock (the
user's reference; its reference sheet's four views measured): silhouette D,
the user's pick. A long fat cylinder with slot flutes in a thin light-steel
frame, a short stepped barrel over a walnut forend whose steel nose holds the
shot barrel's bore (ours is a LeMat), a slim hooked hammer, a long walnut grip
raked back hard, a round guard and a sickle trigger. Its outlines are the
drawing's own curves (OUTLINES, mm, x forward and y up, the fist at the
origin), drawn out into rounded slabs. Soft bevels and weighted normals carry
the light.

Fits the game's revolver as the stand-in was (scripts/Combat/Weapon.gd): the
handle at the origin, the barrel along the game's -Z, the muzzle, shot muzzle,
cylinder, hammer and gate where the game reads them. The cylinder, hammer and
gate are their own objects, each built about its pivot and axis as the game
turns them (the cylinder about its Y, the hammer about its X, the gate about
its Y; Blender's Z is the game's Y).

    /Applications/Blender.app/Contents/MacOS/Blender --background --factory-startup \\
        --python tools/weapons/build_revolver.py -- <repo root>

Saves assets/weapons/source/revolver.blend, exports assets/weapons/revolver.glb
and assets/weapons/source/revolver_preview.png (a three-quarter look).
Blender's axes: +Y forward (the game's -Z), +Z up, +X right.
Spec: docs/superpowers/specs/2026-10-23-revolver-model-and-flash-design.md.
"""

import math
import os
import re
import sys

import bmesh
import bpy
from mathutils import Matrix, Vector

ROOT = sys.argv[sys.argv.index("--") + 1] if "--" in sys.argv else os.getcwd()
SOURCE = os.path.join(ROOT, "assets", "weapons", "source")
GLB = os.path.join(ROOT, "assets", "weapons", "revolver.glb")

# Where the game reads the gun (Blender's axes: the game's (x, y, z) is
# Blender's (x, -z, y)). Metres, full size.
MUZZLE = Vector((0.0, 0.227, 0.0695))
SHOT_MUZZLE = Vector((0.0, 0.223, 0.038))
CYLINDER_AT = Vector((0.0, 0.1055, 0.046))
HAMMER_AT = Vector((0.0, 0.04, 0.072))
GATE_AT = Vector((0.0125, 0.06, 0.046))

CYLINDER_RADIUS = 0.0335
CYLINDER_LENGTH = 0.077
FRAME_THICK = 0.022
CHAMBERS = 6
# The whole gun grown about the fist on export: an oversized, chunky gun in
# the view, as the reference's (Weapon.gd scales its points to match).
SCALE = 1.3

# Silhouette D's curves (SVG path, mm; x forward, y up, the fist at 0,0):
# Blender's (Y, Z).
OUTLINES = {
    "frame": "M20 50 C24 62 30 72 40 77 L58 80 L58 84 L146 84 L150 80 L150 10 C150 6 146 4 142 4 "
             "L64 4 C56 4 50 0 44 -2 L30 8 C26 20 22 34 20 50 Z",
    # (Bowed as the reference's: steeper toward its foot.)
    "grip": "M29 34 C24 20 15 4 7 -14 C1 -28 -4 -44 -8 -58 C-22 -63 -42 -61 -55 -55 "
            "C-46 -36 -34 -12 -18 10 C-8 26 6 44 19 50 Z",
    "forend": "M144 58 L216 58 C220 58 222 54 222 50 L222 26 C222 20 216 16 210 16 L150 16 L144 22 Z",
    "hammer": "M36 72 C34 80 30 88 23 92 C21 94 23 97 27 96 C34 92 40 84 45 76 Z",
    "trigger": "M52 4 C50 -6 46 -12 39 -15 C46 -10 48 -4 47 4 Z",
}

# How soft the edges are (m) and how round (segments).
BEVEL = 0.0014
BEVEL_SEGMENTS = 3


def clear() -> None:
    bpy.ops.wm.read_factory_settings(use_empty=True)


def material(name: str, colour: tuple, metallic: float, roughness: float) -> bpy.types.Material:
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    bsdf = m.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = (*colour, 1.0)
    bsdf.inputs["Metallic"].default_value = metallic
    bsdf.inputs["Roughness"].default_value = roughness
    return m


def mesh_object(name: str, bm: bmesh.types.BMesh, mat: bpy.types.Material) -> bpy.types.Object:
    data = bpy.data.meshes.new(name)
    bm.to_mesh(data)
    bm.free()
    obj = bpy.data.objects.new(name, data)
    bpy.context.collection.objects.link(obj)
    obj.data.materials.append(mat)
    return obj


def box(name: str, size: tuple, at: tuple, mat, rot: Matrix = Matrix.Identity(3)) -> bpy.types.Object:
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    bmesh.ops.scale(bm, vec=Vector(size), verts=bm.verts)
    bmesh.ops.transform(bm, matrix=rot.to_4x4(), verts=bm.verts)
    bmesh.ops.translate(bm, vec=Vector(at), verts=bm.verts)
    return mesh_object(name, bm, mat)


def tube(name: str, radius: float, length: float, at: tuple, mat, axis: str = "Y", segments: int = 24,
         radius_end: float = -1.0) -> bpy.types.Object:
    """A solid cylinder (a cone with radius_end) `length` long about `axis`, centred on `at`."""
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=False, segments=segments, radius1=radius,
                          radius2=radius if radius_end < 0.0 else radius_end, depth=length)
    # Made along Z: turned onto the axis asked for.
    if axis == "Y":
        bmesh.ops.rotate(bm, verts=bm.verts, cent=(0, 0, 0), matrix=Matrix.Rotation(-math.pi * 0.5, 3, "X"))
    elif axis == "X":
        bmesh.ops.rotate(bm, verts=bm.verts, cent=(0, 0, 0), matrix=Matrix.Rotation(math.pi * 0.5, 3, "Y"))
    bmesh.ops.translate(bm, vec=Vector(at), verts=bm.verts)
    return mesh_object(name, bm, mat)


def activate(obj: bpy.types.Object) -> None:
    bpy.context.view_layer.update()

    # (A removed object can leave a gap in the list until the layer updates.)
    for o in list(bpy.context.view_layer.objects):
        if o is not None:
            o.select_set(False)

    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj


def cut(target: bpy.types.Object, *cutters: bpy.types.Object) -> None:
    """Carves each cutter out of target, and removes the cutters."""
    for c in cutters:
        mod = target.modifiers.new("cut", "BOOLEAN")
        mod.operation = "DIFFERENCE"
        mod.solver = "EXACT"
        mod.object = c
        activate(target)
        bpy.ops.object.modifier_apply(modifier=mod.name)
        bpy.data.objects.remove(c, do_unlink=True)
        bpy.context.view_layer.update()


def join(name: str, objects: list) -> bpy.types.Object:
    """One object of `objects`' meshes (in place), each face keeping its
    material. (Merged by hand: the join operator will not run headless.)"""
    bm = bmesh.new()
    materials = []

    for o in objects:
        before = len(bm.faces)
        me = o.data.copy()
        me.transform(o.matrix_world)
        bm.from_mesh(me)
        bm.faces.ensure_lookup_table()
        slots = []

        for m in o.data.materials:
            if m not in materials:
                materials.append(m)
            slots.append(materials.index(m))

        for f in bm.faces[before:]:
            f.material_index = slots[f.material_index] if f.material_index < len(slots) else 0

        bpy.data.meshes.remove(me)

    for o in objects:
        bpy.data.objects.remove(o, do_unlink=True)

    data = bpy.data.meshes.new(name)
    bm.to_mesh(data)
    bm.free()

    for m in materials:
        data.materials.append(m)

    obj = bpy.data.objects.new(name, data)
    bpy.context.collection.objects.link(obj)
    return obj


def outline(path: str, per: int = 10) -> list:
    """An SVG path of M, L, C and Z (absolute, mm) as points (m): curves
    sampled `per` steps each."""
    tokens = re.findall(r"[MLCZ]|-?\d*\.?\d+", path)
    points = []
    pen = Vector((0.0, 0.0))
    i = 0

    def num() -> float:
        nonlocal i
        i += 1
        return float(tokens[i - 1])

    while i < len(tokens):
        op = tokens[i]
        i += 1

        if op in ("M", "L"):
            pen = Vector((num(), num()))
            points.append(pen.copy())
        elif op == "C":
            a, b, c = Vector((num(), num())), Vector((num(), num())), Vector((num(), num()))

            for step in range(1, per + 1):
                t = step / per
                q = (1 - t) ** 3 * pen + 3 * (1 - t) ** 2 * t * a + 3 * (1 - t) * t * t * b + t ** 3 * c
                points.append(q)

            pen = c

    # (A closing point on the first is dropped.)
    if (points[-1] - points[0]).length < 1e-6:
        points.pop()

    return [(p.x * 0.001, p.y * 0.001) for p in points]


def sweep(name: str, path: list, radius: float, mat, segments: int = 12) -> bpy.types.Object:
    """A round tube `radius` thick along a side path [(y, z), ...] (open)."""
    bm = bmesh.new()
    rings = []

    for k, (y, z) in enumerate(path):
        here = Vector((0.0, y, z))
        ahead = Vector((0.0, *path[min(k + 1, len(path) - 1)])) - Vector((0.0, *path[max(k - 1, 0)]))
        ahead.normalize()
        side = Vector((1.0, 0.0, 0.0))
        up = ahead.cross(side).normalized()
        rings.append([bm.verts.new(here + (side * math.cos(a) + up * math.sin(a)) * radius)
                      for a in (math.tau * j / segments for j in range(segments))])

    for k in range(len(rings) - 1):
        for j in range(segments):
            bm.faces.new((rings[k][j], rings[k][(j + 1) % segments], rings[k + 1][(j + 1) % segments], rings[k + 1][j]))

    bm.faces.new(list(reversed(rings[0])))
    bm.faces.new(rings[-1])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return mesh_object(name, bm, mat)


def smooth(points: list, per: int = 6) -> list:
    """A closed outline through `points`, curved (Catmull-Rom, `per` steps a
    span): drawn shapes, not polygons."""
    out = []
    n = len(points)

    for i in range(n):
        p0, p1, p2, p3 = (Vector(points[(i + k) % n]) for k in (-1, 0, 1, 2))

        for step in range(per):
            t = step / per
            t2, t3 = t * t, t * t * t
            q = 0.5 * ((2 * p1) + (-p0 + p2) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t2 + (-p0 + 3 * p1 - 3 * p2 + p3) * t3)
            out.append((q.x, q.y))

    return out


def slab(name: str, outline: list, thickness: float, mat, x: float = 0.0) -> bpy.types.Object:
    """A side outline [(y, z), ...] (counter-clockwise seen from +X) drawn out
    `thickness` across X about `x`: the gun's pieces are slabs, rounded off."""
    bm = bmesh.new()
    near = [bm.verts.new((x - thickness * 0.5, y, z)) for y, z in outline]
    far = [bm.verts.new((x + thickness * 0.5, y, z)) for y, z in outline]
    bm.faces.new(list(reversed(near)))
    bm.faces.new(far)
    n = len(outline)

    for i in range(n):
        j = (i + 1) % n
        bm.faces.new((near[i], near[j], far[j], far[i]))

    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return mesh_object(name, bm, mat)


def round_off(obj: bpy.types.Object, width: float, segments: int = BEVEL_SEGMENTS, angle: float = 35.0) -> bpy.types.Object:
    """Its edges rounded now (a bevel applied): chunky, light-catching, as the
    reference's."""
    bevel = obj.modifiers.new("round", "BEVEL")
    bevel.width = width
    bevel.segments = segments
    bevel.limit_method = "ANGLE"
    bevel.angle_limit = math.radians(angle)
    bevel.use_clamp_overlap = True
    activate(obj)
    bpy.ops.object.modifier_apply(modifier=bevel.name)
    return obj


def soften(obj: bpy.types.Object) -> None:
    """Smooth, with weighted normals so its flats stay flat and its rounds
    round (applied on export)."""
    activate(obj)
    bpy.ops.object.shade_smooth()
    normals = obj.modifiers.new("weighted", "WEIGHTED_NORMAL")
    normals.keep_sharp = True
    normals.mode = "FACE_AREA_WITH_ANGLE"


def at_origin(obj: bpy.types.Object, pivot: Vector) -> None:
    """The object's mesh moved so `pivot` is its origin (the object left at the
    origin: the game places the part)."""
    obj.data.transform(Matrix.Translation(-pivot))


def placed(obj: bpy.types.Object, rot: Matrix, at: Vector) -> bpy.types.Object:
    obj.data.transform(Matrix.Translation(at) @ rot.to_4x4())
    return obj


def capsule_cut(name: str, radius: float, length: float, at: tuple, mat) -> list:
    """A rounded slot's cutters along Z (a tube and a ball at each end), to be
    cut one after another."""
    x, y, z = at
    parts = [tube(name, radius, length, at, mat, axis="Z", segments=32)]

    for end in (-0.5, 0.5):
        bm = bmesh.new()
        bmesh.ops.create_uvsphere(bm, u_segments=32, v_segments=16, radius=radius)
        bmesh.ops.translate(bm, vec=Vector((x, y, z + end * length)), verts=bm.verts)
        parts.append(mesh_object(name + "End", bm, mat))

    return parts


def build() -> dict:
    # (Less of a mirror: at 0.9 metal it showed the dark sky and went black.)
    steel = material("Steel", (0.72, 0.73, 0.76), 0.55, 0.38)
    dark_steel = material("DarkSteel", (0.5, 0.5, 0.54), 0.55, 0.42)
    brass = material("Brass", (0.82, 0.6, 0.28), 0.6, 0.32)
    walnut = material("Walnut", (0.34, 0.2, 0.11), 0.0, 0.58)

    # The frame: thin, outlining the cylinder; its window, a slot for the
    # hammer; a latch screw each side behind the cylinder.
    frame = slab("Frame", outline(OUTLINES["frame"]), FRAME_THICK, steel)
    window = box("Window", (0.09, CYLINDER_LENGTH + 0.004, 0.0695), (0.0, CYLINDER_AT.y, 0.0457), steel)
    slot = box("Slot", (0.008, 0.024, 0.03), (0.0, 0.04, 0.078), steel)
    cut(frame, window, slot)
    round_off(frame, 0.0028, 3)
    screws = [tube("Screw", 0.0032, 0.003, (side * (FRAME_THICK * 0.5 + 0.0008), 0.052, 0.056), dark_steel, axis="X",
                   segments=20) for side in (-1.0, 1.0)]
    for screw in screws:
        round_off(screw, 0.0008, 2)
    sight_rear = box("RearSight", (0.009, 0.007, 0.005), (0.0, 0.0605, 0.0865), steel)
    round_off(sight_rear, 0.0012, 2)

    # The barrel: a round tube, a raised ring along it, its bore; the front
    # sight on its top.
    barrel_length = MUZZLE.y - 0.144
    barrel = tube("Barrel", 0.0115, barrel_length, (0.0, 0.144 + barrel_length * 0.5, MUZZLE.z), steel, segments=48)
    round_off(barrel, 0.002, 3)
    cut(barrel, tube("Bore", 0.0052, 0.03, (0.0, MUZZLE.y, MUZZLE.z), steel, segments=24))
    ring = tube("Ring", 0.0145, 0.02, (0.0, 0.182, MUZZLE.z), steel, segments=48)
    round_off(ring, 0.0025, 3)
    cut(ring, tube("RingBore", 0.0112, 0.03, (0.0, 0.182, MUZZLE.z), steel, segments=24))
    sight = box("Sight", (0.0035, 0.007, 0.007), (0.0, 0.2205, MUZZLE.z + 0.014), steel)
    round_off(sight, 0.001, 2)

    # The forend: a walnut block under the barrel, its steel nose with the shot
    # barrel's bore.
    forend = slab("Forend", outline(OUTLINES["forend"]), 0.026, walnut)
    round_off(forend, 0.005, 4)
    nose = slab("Nose", [(0.217, 0.02), (0.2235, 0.022), (0.2235, 0.054), (0.217, 0.056)], 0.024, dark_steel)
    round_off(nose, 0.0015, 2)
    cut(nose, tube("ShotBore", 0.0085, 0.03, (0.0, SHOT_MUZZLE.y, SHOT_MUZZLE.z), dark_steel, segments=28))

    # The trigger guard, a ring; the sickle trigger.
    bpy.ops.mesh.primitive_torus_add(major_radius=0.017, minor_radius=0.0019, major_segments=40, minor_segments=10,
                                     location=(0.0, 0.054, -0.011), rotation=(0.0, math.pi * 0.5, 0.0))
    guard = bpy.context.view_layer.objects.active
    guard.name = "Guard"
    guard.data.materials.append(steel)
    activate(guard)
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    trigger = slab("Trigger", outline(OUTLINES["trigger"], 10), 0.005, dark_steel)
    round_off(trigger, 0.0012, 2)

    # The grip: long, raked back hard, narrow and well rounded.
    grip = slab("Grip", outline(OUTLINES["grip"]), 0.026, walnut)
    round_off(grip, 0.0085, 4, 30.0)

    gun = join("Revolver", [frame, *screws, sight_rear, barrel, ring, sight, forend, nose, guard, trigger, grip])
    soften(gun)

    # The cylinder, about its axis (Blender's Z, the game's Y), its face to
    # the muzzle at -Z: six chambers with brass noses at the face and brass
    # rims at the back, long rounded slot flutes between.
    cyl = tube("Cylinder", CYLINDER_RADIUS, CYLINDER_LENGTH, (0.0, 0.0, 0.0), steel, axis="Z", segments=64)
    holes = []
    for i in range(CHAMBERS):
        turn = math.tau * i / CHAMBERS
        holes.append(tube("Chamber", 0.0068, CYLINDER_LENGTH + 0.01,
                          (math.cos(turn) * 0.0195, math.sin(turn) * 0.0195, 0.0), steel, axis="Z", segments=24))
        flute_turn = turn + math.pi / CHAMBERS
        holes += capsule_cut("Flute", 0.0046, CYLINDER_LENGTH * 0.56,
                             (math.cos(flute_turn) * (CYLINDER_RADIUS + 0.0012), math.sin(flute_turn) * (CYLINDER_RADIUS + 0.0012),
                              -CYLINDER_LENGTH * 0.04), steel)
    holes.append(tube("Pin", 0.0042, CYLINDER_LENGTH + 0.01, (0.0, 0.0, 0.0), steel, axis="Z", segments=16))
    cut(cyl, *holes)
    # (Only its outer edges: rounding the flutes' lips left them ragged.)
    round_off(cyl, 0.0022, 3, 60.0)
    rounds = [cyl]
    for i in range(CHAMBERS):
        turn = math.tau * i / CHAMBERS
        x, y = math.cos(turn) * 0.0195, math.sin(turn) * 0.0195
        rounds.append(tube("Case", 0.0062, CYLINDER_LENGTH - 0.006, (x, y, 0.002), brass, axis="Z", segments=20))
        rounds.append(tube("Nose", 0.006, 0.007, (x, y, -CYLINDER_LENGTH * 0.5 + 0.0045), brass, axis="Z",
                           segments=20, radius_end=0.004))
        rim = tube("Rim", 0.0076, 0.0016, (x, y, CYLINDER_LENGTH * 0.5 + 0.0006), brass, axis="Z", segments=24)
        round_off(rim, 0.0005, 1)
        rounds.append(rim)
    cylinder = join("Cylinder", rounds)
    soften(cylinder)

    # The hammer, about its pivot (Blender's X): slim, hooked back.
    hammer = slab("Hammer", outline(OUTLINES["hammer"], 10), 0.007, steel)
    round_off(hammer, 0.0016, 3)
    at_origin(hammer, Vector((0.0, HAMMER_AT.y, HAMMER_AT.z)))
    soften(hammer)

    # The loading gate, about its hinge (Blender's Z): a small rounded plate
    # back from it on the right of the frame, behind the cylinder.
    gate = slab("Gate", smooth([(0.0, -0.011), (0.0, 0.011), (-0.014, 0.009), (-0.017, 0.0), (-0.014, -0.009)], 4),
                0.003, steel)
    round_off(gate, 0.001, 2)
    soften(gate)

    return {"gun": gun, "cylinder": cylinder, "hammer": hammer, "gate": gate}


def preview(parts: dict) -> None:
    """A three-quarter look at the gun, its parts in place, for review."""
    shown = []
    for name, pivot, axis in [("cylinder", CYLINDER_AT, None), ("hammer", HAMMER_AT, None), ("gate", GATE_AT, None)]:
        copy = parts[name].copy()
        copy.data = parts[name].data.copy()
        bpy.context.collection.objects.link(copy)
        copy.location = pivot
        # (The cylinder's axis, Blender's Z, turned onto the barrel's Y.)
        if name == "cylinder":
            copy.rotation_euler = (math.pi * 0.5, 0.0, 0.0)
        shown.append(copy)

    for name in ["cylinder", "hammer", "gate"]:
        parts[name].hide_render = True

    scene = bpy.context.scene
    scene.render.engine = "BLENDER_EEVEE"
    scene.render.resolution_x = 1200
    scene.render.resolution_y = 800
    world = bpy.data.worlds.new("World")
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs[0].default_value = (0.32, 0.34, 0.38, 1.0)
    world.node_tree.nodes["Background"].inputs[1].default_value = 0.8
    scene.world = world
    sun = bpy.data.objects.new("Sun", bpy.data.lights.new("Sun", "SUN"))
    sun.data.energy = 3.0
    sun.rotation_euler = (math.radians(50), math.radians(10), math.radians(140))
    bpy.context.collection.objects.link(sun)
    camera = bpy.data.objects.new("Camera", bpy.data.cameras.new("Camera"))
    camera.data.lens = 50
    camera.location = (0.46, -0.2, 0.14)
    bpy.context.collection.objects.link(camera)
    target = Vector((0.0, 0.085, 0.015))
    camera.rotation_euler = (target - camera.location).to_track_quat("-Z", "Y").to_euler()
    scene.camera = camera
    scene.render.filepath = os.path.join(SOURCE, "revolver_preview.png")
    bpy.ops.render.render(write_still=True)
    # And straight from its left side, as the reference sheet's view.
    camera.data.type = "ORTHO"
    camera.data.ortho_scale = 0.34
    camera.location = (-0.6, 0.085, 0.02)
    camera.rotation_euler = (math.pi * 0.5, 0.0, -math.pi * 0.5)
    scene.render.filepath = os.path.join(SOURCE, "revolver_side.png")
    bpy.ops.render.render(write_still=True)

    for o in shown + [sun, camera]:
        bpy.data.objects.remove(o, do_unlink=True)

    for name in ["cylinder", "hammer", "gate"]:
        parts[name].hide_render = False


def export(parts: dict) -> None:
    # Each part about its own pivot, the gun about the fist: all grown by
    # SCALE about their origins.
    for obj in parts.values():
        obj.data.transform(Matrix.Scale(SCALE, 4))

    for o in list(bpy.context.view_layer.objects):
        if o is not None:
            o.select_set(False)
    for o in parts.values():
        o.select_set(True)
    bpy.ops.export_scene.gltf(filepath=GLB, export_format="GLB", use_selection=True, export_apply=True,
                              export_yup=True, export_materials="EXPORT", export_normals=True)


def main() -> None:
    clear()
    os.makedirs(SOURCE, exist_ok=True)
    parts = build()
    preview(parts)
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(SOURCE, "revolver.blend"))
    export(parts)
    for name, obj in parts.items():
        tris = sum(len(p.vertices) - 2 for p in obj.evaluated_get(bpy.context.evaluated_depsgraph_get()).data.polygons)
        print("PART %s triangles %d" % (name, tris))


main()
