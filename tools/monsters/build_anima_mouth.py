"""The ánima's third form, the mouth: several of them fused into one, a hunger that has swallowed
others. Ribs from Aaron Olson's human skeleton (CC BY 4.0, credited in CREDITS.md), the breastbone
gone so the cage is split down the front, the ribs drawn out into teeth; behind and under them one
closed mass of dried flesh, hollow for the mouth, with collars grown up where the game's own hands
and skulls push out of it (markers Arm_1..5, Face_1..3; Arm_1 and Arm_2 drag it); dead candles on
its back. RibsLeft and RibsRight have their origin at their hinge, so the game opens them.

Every part is a closed solid; the script refuses an open edge. Blender's axes: +Y ahead (the
game's -Z), +Z up.

  Blender --background --factory-startup --python tools/monsters/build_anima_mouth.py -- "$PWD" [skeleton scene.gltf]

With the skeleton's scene.gltf it first takes the ribcage out of it, to source/mouth_ribs_base.glb.
"""

import math
import os
import random
import sys

import bmesh
import bpy
from mathutils import Matrix, Vector, noise

ARGS = sys.argv[sys.argv.index("--") + 1:]
ROOT = ARGS[0]
SKELETON = ARGS[1] if len(ARGS) > 1 else ""
SOURCE = os.path.join(ROOT, "assets", "monsters", "source")
BASE = os.path.join(SOURCE, "mouth_ribs_base.glb")
GLB = os.path.join(ROOT, "assets", "monsters", "anima_mouth.glb")
OUT_PICTURES = os.environ.get("MOUTH_PICTURES", "")

## The skeleton's ribcage: where its middle is, and how much of it makes the mouth.
CAGE_MIDDLE = Vector((0.0, 0.0, 29.55))
CAGE_SCALE = 0.128
CAGE_LIFT = 0.56
## The ribs: how far out and how far in their tips are drawn, how they are made thicker to read.
TOOTH_FROM = -0.02
TOOTH_SPAN = 0.26
TOOTH_LONG = 0.17
TOOTH_IN = 0.12
TOOTH_DOWN = 0.05
RIB_WANDER = 0.012
RIB_VOXEL = 0.0065
RIB_THICKER = 0.005
RIB_TRIS = 3400
## The fang each rib is drawn out into: which ribs (their size in the skeleton), how long, how thick.
FANG_FROM = 110
FANG_LONG = (0.15, 0.3)
FANG_WIDE = 0.03
## The other souls' bones breaking through the flesh.
LOOSE_BONES = 11
LOOSE_FROM = 150
LOOSE_TRIS = 2400
## Where each side of the ribs swings from.
HINGE = Vector((0.0, -0.3, 0.55))
## The hollow the mouth needs in the mass: its middle, its half-sizes.
HOLLOW = Vector((0.0, 0.05, 0.56))
HOLLOW_SIZE = Vector((0.3, 0.32, 0.46))
MASS_VOXEL = 0.012
MASS_TRIS = 13500
## How the flesh has dried on what is under it: its long folds and its fine wrinkles, how deep.
FOLDS = (7.0, 0.05)
WRINKLES = (24.0, 0.012)
GULLET_TRIS = 900
## What is on it.
ARMS = (
    ("Arm_1", Vector((0.36, 0.1, 0.16)), Vector((0.45, 0.85, -0.2))),
    ("Arm_2", Vector((-0.37, 0.06, 0.15)), Vector((-0.45, 0.85, -0.25))),
    ("Arm_3", Vector((0.44, -0.3, 0.64)), Vector((0.85, 0.2, 0.5))),
    ("Arm_4", Vector((-0.46, -0.38, 0.52)), Vector((-0.8, 0.1, 0.6))),
    ("Arm_5", Vector((0.14, -0.62, 0.84)), Vector((0.2, -0.3, 0.95))),
)
FACES = (
    ("Face_1", Vector((0.27, -0.26, 1.02)), Vector((0.35, 0.75, 0.5))),
    ("Face_2", Vector((-0.4, -0.2, 0.84)), Vector((-0.55, 0.75, 0.25))),
    ("Face_3", Vector((0.42, -0.36, 0.3)), Vector((0.7, 0.6, 0.1))),
)
COLLAR = 0.095
CANDLES = 7
## Paint: bone, dried leather, what is under it, and where the fire has been.
BONE = (0.5, 0.43, 0.3)
BONE_DARK = (0.17, 0.13, 0.09)
LEATHER = (0.2, 0.135, 0.09)
LEATHER_DARK = (0.075, 0.05, 0.04)
RAW = (0.27, 0.07, 0.055)
FAT = (0.42, 0.33, 0.2)
INSIDE = (0.1, 0.012, 0.016)
INSIDE_WET = (0.32, 0.05, 0.05)
CHAR = (0.018, 0.015, 0.014)
WAX = (0.42, 0.37, 0.27)
SOOT = (0.03, 0.025, 0.02)


def mix(a, b, t):
    t = max(0.0, min(1.0, t))
    return tuple(a[i] + (b[i] - a[i]) * t for i in range(3))


def smooth(a, b, x):
    t = max(0.0, min(1.0, (x - a) / (b - a)))
    return t * t * (3.0 - 2.0 * t)


def paint_value(c):
    return (max(c[0], 0.0) ** (1.0 / 2.2), max(c[1], 0.0) ** (1.0 / 2.2), max(c[2], 0.0) ** (1.0 / 2.2), 1.0)


def active(obj):
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj


def apply(obj, kind, **settings):
    modifier = obj.modifiers.new("Do", kind)

    for key, value in settings.items():
        setattr(modifier, key, value)

    active(obj)
    bpy.ops.object.modifier_apply(modifier="Do")


def closed(obj):
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    bad = [e for e in bm.edges if len(e.link_faces) != 2]
    bm.free()

    if bad:
        raise RuntimeError("%s has %d open edges" % (obj.name, len(bad)))


def reduce(obj, tris):
    """Down to about `tris`; a collapse can pinch an edge, so a little finer until it doesn't."""
    whole = obj.data.copy()
    ratio = min(1.0, tris / max(sum(len(p.vertices) - 2 for p in obj.data.polygons), 1))

    for attempt in range(14):
        obj.data = whole.copy()
        apply(obj, "DECIMATE", ratio=ratio)
        bm = bmesh.new()
        bm.from_mesh(obj.data)
        pinched = sum(1 for e in bm.edges if len(e.link_faces) != 2)
        bm.free()

        if pinched == 0:
            break

        ratio = min(1.0, ratio * 1.04)

    bpy.data.meshes.remove(whole)


def open_edges(obj):
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    bad = sum(1 for e in bm.edges if len(e.link_faces) != 2)
    bm.free()
    return bad


def remesh_closed(obj, voxel, tris):
    """Voxels now and then touch at an edge: a hair coarser each try, until it comes out one skin."""
    whole = obj.data.copy()

    for attempt in range(10):
        obj.data = whole.copy()
        apply(obj, "REMESH", mode="VOXEL", voxel_size=voxel * (1.0 + attempt * 0.035), use_smooth_shade=True)

        if open_edges(obj) > 0:
            continue

        reduce(obj, tris)

        if open_edges(obj) == 0:
            break

    bpy.data.meshes.remove(whole)


def clear_scene():
    for obj in list(bpy.data.objects):
        bpy.data.objects.remove(obj)


def take_ribs_from_skeleton():
    """The one ribcage out of the whole download (it holds two skeletons)."""
    clear_scene()
    bpy.ops.import_scene.gltf(filepath=SKELETON)
    bpy.context.view_layer.update()
    keep = None

    for obj in bpy.data.objects:
        if obj.type == "MESH" and obj.parent is not None and obj.parent.name.startswith("BONES_RIBCAGE") and ".001" not in obj.parent.name:
            keep = obj

    bm = bmesh.new()
    bm.from_mesh(keep.data)
    bm.transform(keep.matrix_world)
    mesh = bpy.data.meshes.new("Ribs")
    bm.to_mesh(mesh)
    bm.free()
    clear_scene()
    ribs = bpy.data.objects.new("Ribs", mesh)
    bpy.context.collection.objects.link(ribs)
    # (Bone only: no textures of the download's come along.)
    mesh.materials.clear()
    bpy.ops.export_scene.gltf(filepath=BASE, export_format="GLB", export_yup=True, export_materials="NONE", export_normals=False)
    print("TOOK", BASE)


def islands_of(bm):
    seen = set()
    found = []

    for v in bm.verts:
        if v.index in seen:
            continue

        stack = [v]
        seen.add(v.index)
        group = []

        while stack:
            at = stack.pop()
            group.append(at)

            for e in at.link_edges:
                other = e.other_vert(at)

                if other.index not in seen:
                    seen.add(other.index)
                    stack.append(other)

        found.append(group)

    return found


def into_mouth(co, rng_seed):
    """A skeleton's point, into the mouth's place: turned to face +Y, sized, the tips drawn into teeth."""
    at = co - CAGE_MIDDLE
    at = Vector((-at.x, -at.y, at.z)) * CAGE_SCALE
    # (Its ribs lean forward and down: stand the cage up a little, so the mouth looks ahead.)
    at = Matrix.Rotation(-0.2, 3, "X") @ at
    tip = smooth(TOOTH_FROM, TOOTH_FROM + TOOTH_SPAN, at.y)
    at.y += tip * tip * TOOTH_LONG
    at.x *= 1.0 - tip * tip * TOOTH_IN
    at.z -= tip * tip * TOOTH_DOWN * (1.0 if at.z > 0.0 else 0.4)
    wander = Vector((noise.noise(at * 7.0 + Vector((rng_seed, 0.0, 0.0))), noise.noise(at * 7.0 + Vector((0.0, rng_seed, 3.0))), noise.noise(at * 7.0 + Vector((5.0, 0.0, rng_seed)))))
    return at + wander * RIB_WANDER + Vector((0.0, 0.0, CAGE_LIFT))


def grow_fang(side, tip, rng):
    """A long tooth out of the end of a rib, in toward the middle of the mouth and ahead, one closed taper."""
    way = Vector((-math.copysign(0.55, tip.x), 0.8, rng.uniform(-0.35, 0.1))).normalized()
    long = rng.uniform(*FANG_LONG)
    rings = []

    for k in range(6):
        t = k / 5
        wide = FANG_WIDE * (1.0 - t) ** 0.7 + 0.002
        # A curved tooth: down its length it hooks back toward the throat.
        at = tip - way * 0.012 + way * long * t - Vector((math.copysign(0.0, tip.x), 1.0, 0.0)) * long * 0.2 * t * t
        ring = [side.verts.new(at + Vector((math.cos(j * math.tau / 6) * wide, 0.0, math.sin(j * math.tau / 6) * wide))) for j in range(6)]
        rings.append(ring)

    for k in range(5):
        for j in range(6):
            n = (j + 1) % 6
            side.faces.new((rings[k][j], rings[k][n], rings[k + 1][n], rings[k + 1][j]))

    side.faces.new(rings[0][::-1])
    side.faces.new(rings[-1])


def build_loose_bones(rng):
    """Ribs of the others, turned every way and half sunk in the mass, breaking through its back."""
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=BASE)
    source = next(o for o in set(bpy.data.objects) - before if o.type == "MESH")
    bpy.context.view_layer.update()
    bm = bmesh.new()
    bm.from_mesh(source.data)
    bm.transform(source.matrix_world)
    big = [g for g in islands_of(bm) if len(g) >= LOOSE_FROM and not (abs((sum((v.co for v in g), Vector()) / len(g)).x) < 0.5)]
    out = bmesh.new()

    for i in range(LOOSE_BONES):
        group = rng.choice(big)
        middle = sum((v.co for v in group), Vector()) / len(group)
        spin = (Matrix.Rotation(rng.uniform(0.0, math.tau), 3, "Z") @ Matrix.Rotation(rng.uniform(-1.3, 1.3), 3, "X") @ Matrix.Rotation(rng.uniform(0.0, math.tau), 3, "Y"))
        turn = rng.uniform(0.0, math.tau)
        at = Vector((math.cos(turn) * rng.uniform(0.28, 0.52), rng.uniform(-1.0, -0.25), rng.uniform(0.25, 1.02)))
        size = CAGE_SCALE * rng.uniform(0.7, 0.95)
        made = {}

        for v in group:
            made[v] = out.verts.new(at + spin @ ((v.co - middle) * size))

        faces = set()

        for v in group:
            faces.update(v.link_faces)

        for f in faces:
            try:
                out.faces.new([made[v] for v in f.verts])
            except ValueError:
                pass

    bm.free()
    bpy.data.objects.remove(source)
    mesh = bpy.data.meshes.new("Bones")
    out.to_mesh(mesh)
    out.free()
    bones = bpy.data.objects.new("Bones", mesh)
    bpy.context.collection.objects.link(bones)
    remesh_closed(bones, RIB_VOXEL, LOOSE_TRIS)
    paint_bone(bones)
    closed(bones)
    return bones


def build_ribs():
    bpy.ops.import_scene.gltf(filepath=BASE)
    source = next(o for o in bpy.data.objects if o.type == "MESH")
    bpy.context.view_layer.update()
    bm = bmesh.new()
    bm.from_mesh(source.data)
    bm.transform(source.matrix_world)
    sides = {"RibsLeft": bmesh.new(), "RibsRight": bmesh.new()}
    groups = islands_of(bm)
    dropped = 0
    fangs = 0
    fang_rng = random.Random(7)

    for number, group in enumerate(groups):
        middle = sum((v.co for v in group), Vector()) / len(group)
        spread_z = max(v.co.z for v in group) - min(v.co.z for v in group)
        # The breastbone goes: what is left is split down the front.
        if abs(middle.x) < 0.5 and middle.y < -0.3 and spread_z > 1.5:
            dropped += 1
            continue

        side = sides["RibsLeft" if middle.x > 0.0 else "RibsRight"]
        made = {}

        for v in group:
            made[v] = side.verts.new(into_mouth(v.co, 1.3))

        if len(group) >= FANG_FROM:
            grow_fang(side, max(made.values(), key=lambda m: m.co.y).co.copy(), fang_rng)
            fangs += 1

        faces = set()

        for v in group:
            faces.update(v.link_faces)

        for f in faces:
            try:
                side.faces.new([made[v] for v in f.verts])
            except ValueError:
                pass

    print("BREASTBONE PIECES", dropped, "FANGS", fangs)
    bm.free()
    bpy.data.objects.remove(source)
    made_objects = []

    for name, side in sides.items():
        mesh = bpy.data.meshes.new(name)
        side.to_mesh(mesh)
        side.free()
        obj = bpy.data.objects.new(name, mesh)
        bpy.context.collection.objects.link(obj)
        # Closed, whatever the skeleton's surfaces were; then thick enough to read in the game.
        apply(obj, "REMESH", mode="VOXEL", voxel_size=RIB_VOXEL, use_smooth_shade=True)
        thicken = bmesh.new()
        thicken.from_mesh(obj.data)
        thicken.normal_update()

        for v in thicken.verts:
            v.co += v.normal * RIB_THICKER

        thicken.to_mesh(obj.data)
        thicken.free()
        reduce(obj, RIB_TRIS)
        paint_bone(obj)
        closed(obj)
        made_objects.append(obj)

    return made_objects


def paint_bone(obj):
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    bm.normal_update()
    layer = bm.loops.layers.color.new("Color")

    for f in bm.faces:
        f.smooth = True

        for loop in f.loops:
            c = loop.vert.co
            stain = noise.noise(c * 16.0) * 0.5 + 0.5
            # Clean to the tooth; dark and fleshed where it goes into the mass.
            root = smooth(0.05, -0.3, c.y)
            tone = mix(BONE, BONE_DARK, smooth(0.35, 0.72, stain))
            tone = mix(tone, LEATHER_DARK, root * 0.85)
            tone = mix(tone, RAW, smooth(0.62, 0.75, noise.noise(c * 9.0) * 0.5 + 0.5) * root)
            tone = mix(tone, BONE_DARK, smooth(-0.1, -0.6, loop.vert.normal.z) * 0.5)
            loop[layer] = paint_value(tone)

    bm.to_mesh(obj.data)
    bm.free()
    obj.data.color_attributes.active_color_index = 0
    obj.data.color_attributes.render_color_index = 0


def lump_into(bm, at, size, seed, turn=None):
    piece = bmesh.new()
    bmesh.ops.create_icosphere(piece, subdivisions=3, radius=1.0)

    for v in piece.verts:
        wobble = 1.0 + 0.38 * noise.noise(v.co * 2.4 + Vector((seed, seed * 0.5, 0.0)))
        shaped = Vector((v.co.x * size.x, v.co.y * size.y, v.co.z * size.z)) * wobble
        v.co = (turn @ shaped if turn is not None else shaped) + at

    mesh = bpy.data.meshes.new("Piece")
    piece.to_mesh(mesh)
    piece.free()
    bm.from_mesh(mesh)
    bpy.data.meshes.remove(mesh)


def build_mass(rng):
    bm = bmesh.new()
    seed = 1.0

    # What the ribs grow out of: a back behind them, a spine's hump, shoulders, a low belly on
    # the floor, all trailing away behind to where the fire took the rest.
    for at, size in (
        (Vector((0.0, -0.42, 0.56)), Vector((0.42, 0.36, 0.56))),
        (Vector((0.0, -0.5, 0.92)), Vector((0.34, 0.3, 0.26))),
        (Vector((0.36, -0.34, 0.78)), Vector((0.2, 0.26, 0.24))),
        (Vector((-0.38, -0.36, 0.72)), Vector((0.22, 0.28, 0.26))),
        (Vector((0.0, -0.3, 0.14)), Vector((0.5, 0.42, 0.16))),
        (Vector((0.0, -0.78, 0.26)), Vector((0.42, 0.4, 0.24))),
        (Vector((0.08, -1.08, 0.16)), Vector((0.26, 0.26, 0.15))),
        (Vector((-0.1, -1.28, 0.09)), Vector((0.14, 0.2, 0.09))),
    ):
        lump_into(bm, at, size, seed)
        seed += 1.7

    # Long shapes laid over it every way, as sinew and the limbs of the others, not balls.
    for i in range(46):
        turn = rng.uniform(0.0, math.tau)
        at = Vector((math.cos(turn) * rng.uniform(0.16, 0.48), rng.uniform(-1.05, -0.18), rng.uniform(0.08, 1.05)))
        wide = rng.uniform(0.035, 0.07)
        spin = Matrix.Rotation(rng.uniform(0.0, math.tau), 3, "X") @ Matrix.Rotation(rng.uniform(0.0, math.tau), 3, "Z")
        lump_into(bm, at, Vector((wide, rng.uniform(0.16, 0.34), wide * rng.uniform(0.7, 1.2))), seed, spin)
        seed += 1.1

    # A spine's knobs along its back, all the way down.
    for i in range(13):
        t = i / 12
        at = Vector((math.sin(t * 5.0) * 0.03, -0.72 - t * 0.28 + (1.0 - t) * 0.18, 1.0 - t * 0.78))
        lump_into(bm, at, Vector((0.055, 0.06, 0.04)), seed)
        seed += 0.7

    # A collar of flesh grown up round each thing that pushes out of it.
    for name, at, way in ARMS + FACES:
        lump_into(bm, at - way.normalized() * COLLAR * 0.35, Vector((COLLAR, COLLAR, COLLAR)) * (1.25 if name.startswith("Face") else 1.0), seed)
        seed += 0.9

    mesh = bpy.data.meshes.new("Mass")
    bm.to_mesh(mesh)
    bm.free()
    mass = bpy.data.objects.new("Mass", mesh)
    bpy.context.collection.objects.link(mass)
    apply(mass, "REMESH", mode="VOXEL", voxel_size=MASS_VOXEL, use_smooth_shade=True)
    dry_out(mass)
    press_out_the_hollow(mass)
    reduce(mass, MASS_TRIS)
    # (What a collapse leaves is faceted, and shows close up.)
    apply(mass, "SMOOTH", factor=0.5, iterations=1)
    paint_flesh(mass)
    closed(mass)
    return mass


def dry_out(mass):
    """Dried on: long sunken folds and fine wrinkles, drawn in on what is under it."""
    bm = bmesh.new()
    bm.from_mesh(mass.data)
    bm.normal_update()

    for v in bm.verts:
        c = v.co
        folds = 1.0 - abs(noise.noise(Vector((c.x * FOLDS[0], c.y * FOLDS[0] * 0.45, c.z * FOLDS[0])))) * 2.6
        fine = 1.0 - abs(noise.noise(c * WRINKLES[0])) * 2.0
        v.co = c + v.normal * (FOLDS[1] * (folds - 0.5) * -1.0 + WRINKLES[1] * (fine - 0.5) * -1.0)

    bm.to_mesh(mass.data)
    bm.free()


def press_out_the_hollow(mass):
    """Room for the mouth, pressed back, not cut: it stays one closed skin."""
    bm = bmesh.new()
    bm.from_mesh(mass.data)

    for v in bm.verts:
        off = v.co - HOLLOW
        scaled = Vector((off.x / HOLLOW_SIZE.x, off.y / HOLLOW_SIZE.y, off.z / HOLLOW_SIZE.z))

        if scaled.length < 1.0:
            out = scaled.normalized()
            v.co = HOLLOW + Vector((out.x * HOLLOW_SIZE.x, out.y * HOLLOW_SIZE.y, out.z * HOLLOW_SIZE.z))

    bm.to_mesh(mass.data)
    bm.free()


def paint_flesh(mass):
    bm = bmesh.new()
    bm.from_mesh(mass.data)
    bm.normal_update()
    layer = bm.loops.layers.color.new("Color")

    for f in bm.faces:
        f.smooth = True

        for loop in f.loops:
            c = loop.vert.co
            up = loop.vert.normal.z * 0.5 + 0.5
            streak = noise.noise(Vector((c.x * 16.0, c.y * 16.0, c.z * 7.0))) * 0.5 + 0.5
            crack = 1.0 - abs(noise.noise(c * 11.0)) * 6.0
            tone = mix(LEATHER_DARK, LEATHER, smooth(0.2, 0.7, up * 0.55 + streak * 0.55))
            tone = mix(tone, FAT, smooth(0.66, 0.78, noise.noise(c * 8.0 + Vector((2.0, 0.0, 1.0))) * 0.5 + 0.5) * 0.45)
            # Split where it has dried, the raw showing.
            tone = mix(tone, RAW, smooth(0.5, 0.9, crack) * 0.75)
            # Wet and dark toward the mouth; burnt to nothing behind.
            hollow = (c - HOLLOW)
            scaled = Vector((hollow.x / HOLLOW_SIZE.x, hollow.y / HOLLOW_SIZE.y, hollow.z / HOLLOW_SIZE.z)).length
            tone = mix(tone, INSIDE, smooth(1.28, 1.02, scaled))
            tone = mix(tone, CHAR, smooth(-0.8, -1.2, c.y + (streak - 0.5) * 0.25))
            loop[layer] = paint_value(tone)

    bm.to_mesh(mass.data)
    bm.free()
    mass.data.color_attributes.active_color_index = 0
    mass.data.color_attributes.render_color_index = 0


def build_gullet():
    """The dark of the mouth: a wall of folds well back in the hollow, black where the throat is."""
    bm = bmesh.new()
    bmesh.ops.create_icosphere(bm, subdivisions=4, radius=1.0)
    behind = Vector((0.0, -0.26, HOLLOW.z))

    for v in bm.verts:
        fold = 1.0 + 0.2 * math.sin(v.co.z * 15.0 + noise.noise(v.co * 3.0) * 7.0)
        v.co = behind + Vector((v.co.x * HOLLOW_SIZE.x * 0.92 * fold, v.co.y * 0.22, v.co.z * HOLLOW_SIZE.z * 0.92 * fold))

    bm.normal_update()
    layer = bm.loops.layers.color.new("Color")

    for f in bm.faces:
        f.smooth = True

        for loop in f.loops:
            c = loop.vert.co
            off = Vector((c.x / HOLLOW_SIZE.x, (c.z - HOLLOW.z) / HOLLOW_SIZE.z)).length
            ridge = math.sin(c.z * 60.0 + noise.noise(c * 8.0) * 6.0) * 0.5 + 0.5
            tone = mix(CHAR, INSIDE, smooth(0.15, 0.55, off))
            tone = mix(tone, INSIDE_WET, smooth(0.65, 0.95, ridge) * smooth(0.35, 0.8, off))
            loop[layer] = paint_value(tone)

    mesh = bpy.data.meshes.new("Gullet")
    bm.to_mesh(mesh)
    bm.free()
    mesh.color_attributes.active_color_index = 0
    mesh.color_attributes.render_color_index = 0
    gullet = bpy.data.objects.new("Gullet", mesh)
    bpy.context.collection.objects.link(gullet)
    reduce(gullet, GULLET_TRIS)
    closed(gullet)
    return gullet


def build_candles(rng, mass):
    bm = bmesh.new()
    layer = None
    depsgraph = bpy.context.evaluated_depsgraph_get()
    placed = []

    for attempt in range(200):
        if len(placed) >= CANDLES:
            break

        x = rng.uniform(-0.34, 0.34)
        y = rng.uniform(-0.98, -0.3)

        if any((Vector((x, y)) - p).length < 0.11 for p in placed):
            continue

        hit, at, normal, _face = mass.evaluated_get(depsgraph).ray_cast(Vector((x, y, 2.0)), Vector((0.0, 0.0, -1.0)))

        if not hit or normal.z < 0.55:
            continue

        placed.append(Vector((x, y)))
        tall = rng.uniform(0.07, 0.2)
        wide = rng.uniform(0.024, 0.042)
        lean = Matrix.Rotation(rng.uniform(-0.3, 0.3), 3, "X") @ Matrix.Rotation(rng.uniform(-0.3, 0.3), 3, "Y")
        foot = at - Vector((0.0, 0.0, 0.025))
        rings = []

        # A burnt stub: uneven, wax run down it, sunk into the flesh at its foot.
        for k in range(6):
            t = k / 5
            ring_wide = wide * (1.45 - 0.45 * smooth(0.0, 0.3, t)) * (1.0 + 0.05 * math.sin(t * 9.0 + x * 30.0))
            ring = []

            for j in range(7):
                turn = j * math.tau / 7
                flat = Vector((math.cos(turn), math.sin(turn), 0.0)) * ring_wide
                ring.append(bm.verts.new(foot + lean @ (flat + Vector((0.0, 0.0, tall * t)))))

            rings.append(ring)

        for k in range(5):
            for j in range(7):
                n = (j + 1) % 7
                bm.faces.new((rings[k][j], rings[k][n], rings[k + 1][n], rings[k + 1][j]))

        bm.faces.new(rings[0][::-1])
        bm.faces.new(rings[-1])
        # The dead wick.
        top = foot + lean @ Vector((0.0, 0.0, tall))
        wick = bmesh.ops.create_cone(bm, cap_ends=True, segments=4, radius1=0.004, radius2=0.002, depth=0.03, matrix=Matrix.Translation(top + Vector((0.0, 0.0, 0.012))))
        del wick

    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.normal_update()
    layer = bm.loops.layers.color.new("Color")

    for f in bm.faces:
        f.smooth = True

        for loop in f.loops:
            c = loop.vert.co
            streak = noise.noise(c * 60.0) * 0.5 + 0.5
            tone = mix(WAX, BONE_DARK, smooth(0.3, 0.7, streak) * 0.7)
            # Black at the top, where it went out; up near the wick all soot.
            tone = mix(tone, SOOT, smooth(0.0, 1.0, loop.vert.normal.z) * 0.85)
            loop[layer] = paint_value(tone)

    mesh = bpy.data.meshes.new("Candles")
    bm.to_mesh(mesh)
    bm.free()
    mesh.color_attributes.active_color_index = 0
    mesh.color_attributes.render_color_index = 0
    candles = bpy.data.objects.new("Candles", mesh)
    bpy.context.collection.objects.link(candles)
    closed(candles)
    print("CANDLES", len(placed))
    return candles


def to_hinge(obj):
    """Its origin at its hinge: the game swings it."""
    obj.data.transform(Matrix.Translation(-HINGE))
    obj.location = HINGE


def markers():
    made = []

    for name, at, way in ARMS + FACES:
        empty = bpy.data.objects.new(name, None)
        bpy.context.collection.objects.link(empty)
        empty.location = at
        empty.rotation_mode = "QUATERNION"
        empty.rotation_quaternion = way.normalized().to_track_quat("Y", "Z")
        made.append(empty)

    return made


def wet_look():
    look = bpy.data.materials.new("Paint")
    look.use_nodes = True
    return look


def main():
    if SKELETON:
        take_ribs_from_skeleton()

    clear_scene()
    rng = random.Random(29)
    ribs = build_ribs()
    mass = build_mass(rng)
    gullet = build_gullet()
    candles = build_candles(rng, mass)
    bones = build_loose_bones(rng)
    look = wet_look()

    for obj in ribs + [mass, gullet, candles, bones]:
        obj.data.materials.append(look)

    for obj in ribs:
        to_hinge(obj)

    markers()
    bpy.ops.export_scene.gltf(filepath=GLB, export_format="GLB", export_yup=True, export_materials="NONE", export_normals=True, export_apply=False, export_vertex_color="ACTIVE", export_all_vertex_colors=False)
    print("TRIS", sum(sum(len(p.vertices) - 2 for p in o.data.polygons) for o in bpy.data.objects if o.type == "MESH"))
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(SOURCE, "anima_mouth.blend"))
    print("WROTE", GLB)

    if OUT_PICTURES:
        pictures(ribs, mass)


def add_limbs():
    """For the pictures only: the game's own hands and skulls on the markers."""
    hands = os.path.join(ROOT, "assets", "monsters", "anima_hands.glb")
    face = os.path.join(ROOT, "assets", "monsters", "anima_face.glb")

    for name, at, way in ARMS:
        before = set(bpy.data.objects)
        bpy.ops.import_scene.gltf(filepath=hands)
        roots = [o for o in set(bpy.data.objects) - before if o.parent is None]
        turn = way.normalized().to_track_quat("Y", "Z").to_matrix().to_4x4()

        for root in roots:
            root.matrix_world = Matrix.Translation(at) @ turn @ Matrix.Translation((0.0, 0.2, 0.0)) @ root.matrix_world

    for name, at, way in FACES:
        before = set(bpy.data.objects)
        bpy.ops.import_scene.gltf(filepath=face)
        roots = [o for o in set(bpy.data.objects) - before if o.parent is None]
        turn = way.normalized().to_track_quat("Y", "Z").to_matrix().to_4x4()

        for root in roots:
            root.matrix_world = Matrix.Translation(at) @ turn @ Matrix.Scale(1.3, 4) @ root.matrix_world

        for obj in set(bpy.data.objects) - before:
            if obj.name.startswith("Sinew"):
                obj.hide_render = True


def pictures(ribs, mass):
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_WORKBENCH"
    scene.display.shading.light = "STUDIO"
    scene.display.shading.color_type = "VERTEX"
    scene.display.shading.show_cavity = True
    scene.display.shading.show_shadows = True
    scene.render.resolution_x = 900
    scene.render.resolution_y = 760
    camera_data = bpy.data.cameras.new("Look")
    camera_data.lens = 40
    camera = bpy.data.objects.new("Look", camera_data)
    bpy.context.collection.objects.link(camera)
    scene.camera = camera
    world = bpy.data.worlds.new("Dark")
    scene.world = world
    world.color = (0.05, 0.05, 0.055)
    middle = Vector((0.0, -0.25, 0.55))

    def shot(name, at, look_at=middle):
        camera.location = at
        camera.rotation_euler = (look_at - at).to_track_quat("-Z", "Y").to_euler()
        scene.render.filepath = os.path.join(OUT_PICTURES, name + ".png")
        bpy.ops.render.render(write_still=True)

    def swing(angle):
        # (RibsLeft lies at -x: it opens the way z turns, RibsRight the other.)
        for obj in ribs:
            obj.rotation_euler = (0.0, 0.0, angle if obj.name == "RibsLeft" else -angle)

    shot("a_front", Vector((0.0, 2.3, 0.75)))
    shot("b_quarter", Vector((1.5, 1.8, 0.95)))
    shot("c_side", Vector((2.4, -0.3, 0.7)))
    shot("d_back", Vector((-1.1, -2.2, 1.5)))
    swing(0.42)
    shot("e_open", Vector((0.5, 2.1, 0.8)))
    swing(0.0)
    add_limbs()
    shot("f_with_limbs_front", Vector((0.0, 2.6, 0.85)))
    shot("g_with_limbs_quarter", Vector((1.8, 2.0, 1.05)))
    swing(0.42)
    shot("h_with_limbs_open", Vector((-1.3, 2.1, 0.9)))
    swing(0.0)
    shot("i_close_collar", Vector((0.85, 0.7, 0.75)), Vector((0.42, -0.3, 0.62)))
    shot("j_close_candles", Vector((0.5, -1.3, 1.6)), Vector((0.0, -0.65, 0.95)))


main()
