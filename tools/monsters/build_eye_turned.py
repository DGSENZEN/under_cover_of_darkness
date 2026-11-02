"""The floating eye turned worse (docs/superpowers/specs/2026-11-02-swipes-turning-eye-one-body-design.md):
the approved eye (tools/monsters/build_eye.py), torn open from inside. The same parts by the same
names, so EyeBody.gd can wear either: the stone broken out in two great bites, the lids ripped to
tatters, swollen wet meat bursting through round the ball and hanging from it, and two more pupils
pushing through the white. It is the same thing as before, and it has been hurt, and it is worse.

Opens assets/monsters/source/floating_eye.blend, so build that first. Every part is a closed solid:
the script refuses anything with an open edge. Blender's axes: +Y is where it looks, +Z up.

    /Applications/Blender.app/Contents/MacOS/Blender --background --factory-startup \\
        --python tools/monsters/build_eye_turned.py -- <repo root>

Saves assets/monsters/source/floating_eye_turned.blend, exports
assets/monsters/floating_eye_turned.glb and assets/monsters/source/eye_turned_*.png previews.
"""

import math
import os
import random
import sys

import bmesh
import bpy
from mathutils import Matrix, Vector, noise

ROOT = sys.argv[sys.argv.index("--") + 1]
SOURCE = os.path.join(ROOT, "assets", "monsters", "source")
GLB = os.path.join(ROOT, "assets", "monsters", "floating_eye_turned.glb")
PLAIN = os.path.join(SOURCE, "floating_eye.blend")

## The middle of the ball, its radius.
BALL = Vector((0.0, -0.02, 0.0))
BALL_RADIUS = 0.3
## The bites out of the stone: where, how big.
BITES = ((Vector((0.36, 0.0, 0.26)), 0.3), (Vector((-0.42, 0.0, -0.18)), 0.27), (Vector((0.1, 0.0, -0.36)), 0.17))
## The meat bursting through: lumps round the almond, how many, how far out, how big; the bites
## have more; strands hanging from it, how many, how long.
LUMPS = 34
LUMP_OUT = (0.28, 0.46)
LUMP_SIZE = (0.05, 0.12)
BITE_LUMPS = 9
STRANDS = 16
STRAND_LONG = (0.14, 0.42)
VOXEL = 0.016
MEAT_TRIS = 3200
## The tears in the lids: how many, how big.
LID_TEARS = 13
LID_TEAR_SIZE = (0.035, 0.085)
## The new pupils: their turn from the first on the ball (up, across; radians), how big against it.
PUPILS = (("Pupil_2", 0.12, 0.74, 1.15), ("Pupil_3", -0.16, -0.6, 1.0))
## How far each stands proud of the ball, so it sits up out of its torn flesh.
PUPIL_PROUD = 1.035
## The torn flesh round each, against the pupil.
PUPIL_RIM = 1.7
RIM_TORN = 0.9
## Paint.
MEAT_DEEP = (0.09, 0.008, 0.012)
MEAT_RED = (0.42, 0.03, 0.035)
MEAT_RAW = (0.72, 0.2, 0.17)
MEAT_FAT = (0.62, 0.48, 0.3)


def paint_value(c):
    return (max(c[0], 0.0) ** (1.0 / 2.2), max(c[1], 0.0) ** (1.0 / 2.2), max(c[2], 0.0) ** (1.0 / 2.2), 1.0)


def mix(a, b, t):
    t = max(0.0, min(1.0, t))
    return tuple(a[i] + (b[i] - a[i]) * t for i in range(3))


def smooth(a, b, x):
    t = max(0.0, min(1.0, (x - a) / (b - a)))
    return t * t * (3.0 - 2.0 * t)


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


def lump(at, size, rng, name="Lump", flat=1.0):
    """A rough rock or knob, its own closed solid, in world space."""
    bm = bmesh.new()
    bmesh.ops.create_icosphere(bm, subdivisions=2, radius=size)

    for v in bm.verts:
        v.co *= 1.0 + 0.35 * noise.noise(v.co * 12.0 + Vector((rng.random() * 9.0, rng.random() * 9.0, 0.0)))
        v.co.y *= flat
        v.co += at

    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    return obj


def bite(obj, cutter):
    """Takes `cutter`'s shape out of `obj`. `cutter` stays."""
    modifier = obj.modifiers.new("Bite", "BOOLEAN")
    modifier.operation = "DIFFERENCE"
    modifier.object = cutter
    modifier.solver = "EXACT"
    active(obj)
    bpy.ops.object.modifier_apply(modifier="Bite")


def closed(obj):
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    bad = [e for e in bm.edges if len(e.link_faces) != 2]
    bm.free()

    if bad:
        raise RuntimeError("%s has %d open edges" % (obj.name, len(bad)))


def break_stone(rng):
    cutters = []

    for at, size in BITES:
        # A jagged mouth: several rocks together, across the whole thickness of the stone.
        for i in range(5):
            off = Vector((rng.uniform(-1.0, 1.0), 0.0, rng.uniform(-1.0, 1.0))) * size * 0.7
            cutters.append(lump(at + off, size * rng.uniform(0.45, 0.8), rng, "Cut", flat=2.6))

    for name in ("Frame", "Tier", "Rim"):
        obj = bpy.data.objects[name]

        for cutter in cutters:
            bite(obj, cutter)

        closed(obj)

    for cutter in cutters:
        bpy.data.objects.remove(cutter)


def tear_lids(rng):
    for name in ("LidTop", "LidBottom"):
        obj = bpy.data.objects[name]
        cutters = []
        sign = 1.0 if name == "LidTop" else -1.0

        # Along its front edge, torn back.
        for i in range(LID_TEARS):
            across = rng.uniform(-0.3, 0.3)
            size = rng.uniform(*LID_TEAR_SIZE)
            cutters.append(lump(Vector((across, BALL_RADIUS * 0.82, sign * rng.uniform(0.02, 0.12))), size, rng, "Tear", flat=2.2))

        # (The lid sits at the ball's middle: the cutters are in its own space.)
        for cutter in cutters:
            cutter.location = Vector((0.0, -0.0, 0.0))
            bite(obj, cutter)
            bpy.data.objects.remove(cutter)

        closed(obj)
        paint_raw(obj)


def paint_raw(obj):
    """Stripped to the meat, the faces the tears left as well."""
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    bm.normal_update()

    for old in list(bm.loops.layers.color.values()):
        bm.loops.layers.color.remove(old)

    layer = bm.loops.layers.color.new("Color")

    for f in bm.faces:
        for loop in f.loops:
            c = loop.vert.co
            streak = noise.noise(Vector((c.x * 24.0, c.y * 24.0, c.z * 24.0))) * 0.5 + 0.5
            tone = mix(MEAT_DEEP, MEAT_RED, smooth(0.25, 0.6, streak))
            tone = mix(tone, MEAT_RAW, smooth(0.6, 0.76, streak) * 0.75)
            loop[layer] = paint_value(tone)

    bm.to_mesh(obj.data)
    bm.free()
    obj.data.color_attributes.active_color_index = 0
    obj.data.color_attributes.render_color_index = 0


def build_meat(rng):
    """Everything that has burst through, one mass, hollow for the ball; and what hangs from it."""
    pieces = []

    for i in range(LUMPS):
        turn = rng.uniform(0.0, math.tau)
        out = rng.uniform(*LUMP_OUT)
        at = Vector((math.cos(turn) * out * 1.05, rng.uniform(-0.02, 0.2), math.sin(turn) * out * 0.8))
        pieces.append(lump(at, rng.uniform(*LUMP_SIZE), rng))

    for at, size in BITES:
        for i in range(BITE_LUMPS):
            off = Vector((rng.uniform(-1.0, 1.0), rng.uniform(-0.3, 0.8), rng.uniform(-1.0, 1.0))) * size * 0.55
            pieces.append(lump(at * 0.86 + off, rng.uniform(0.06, 0.14), rng))

    bm = bmesh.new()

    for piece in pieces:
        bm.from_mesh(piece.data)
        bpy.data.objects.remove(piece)

    mesh = bpy.data.meshes.new("Meat")
    bm.to_mesh(mesh)
    bm.free()
    meat = bpy.data.objects.new("Meat", mesh)
    bpy.context.collection.objects.link(meat)
    apply(meat, "REMESH", mode="VOXEL", voxel_size=VOXEL, use_smooth_shade=True)
    # Room for the ball to turn in.
    # (Pressed back, not cut: it stays one closed skin.)
    bm = bmesh.new()
    bm.from_mesh(meat.data)
    room = BALL_RADIUS * 1.04

    for v in bm.verts:
        off = v.co - BALL

        if off.length < room:
            v.co = BALL + off.normalized() * room

    bm.to_mesh(meat.data)
    bm.free()
    # (A collapse can now and then pinch an edge: try again a little finer, or refuse it.)
    whole = meat.data.copy()
    ratio = min(1.0, MEAT_TRIS / max(sum(len(p.vertices) - 2 for p in meat.data.polygons), 1))

    for attempt in range(10):
        meat.data = whole.copy()
        apply(meat, "DECIMATE", ratio=ratio)
        bm = bmesh.new()
        bm.from_mesh(meat.data)
        pinched = sum(1 for e in bm.edges if len(e.link_faces) != 2)
        bm.free()

        if pinched == 0:
            break

        ratio = min(1.0, ratio * 1.05)

    bpy.data.meshes.remove(whole)
    # Strands of it, hanging: closed tapers of their own.
    bm = bmesh.new()
    bm.from_mesh(meat.data)
    top_verts = [v.co.copy() for v in bm.verts if v.co.z < 0.05 and v.co.y > -0.05]

    for i in range(STRANDS):
        root = rng.choice(top_verts)
        long = rng.uniform(*STRAND_LONG)
        rings = []

        for k in range(6):
            t = k / 5
            at = root + Vector((math.sin(t * 4.0 + i) * 0.012, math.cos(t * 3.0 + i) * 0.012, -long * t + 0.01))
            wide = 0.016 * (1.0 - t * 0.8) * (1.0 + 0.6 * math.sin(t * 9.0 + i))
            rings.append([bm.verts.new(at + Vector((math.cos(j * math.tau / 5) * wide, math.sin(j * math.tau / 5) * wide, 0.0))) for j in range(5)])

        for k in range(5):
            for j in range(5):
                n = (j + 1) % 5
                bm.faces.new((rings[k][j], rings[k][n], rings[k + 1][n], rings[k + 1][j]))

        bm.faces.new(rings[0][::-1])
        bm.faces.new(rings[-1])

    bmesh.ops.triangulate(bm, faces=bm.faces)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.normal_update()
    layer = bm.loops.layers.color.new("Color")

    for f in bm.faces:
        f.smooth = True

        for loop in f.loops:
            c = loop.vert.co
            up = loop.vert.normal.z * 0.5 + 0.5
            streak = noise.noise(Vector((c.x * 30.0, c.y * 30.0, c.z * 9.0))) * 0.5 + 0.5
            fat = smooth(0.66, 0.74, noise.noise(c * 14.0 + Vector((3.0, 1.0, 0.0))) * 0.5 + 0.5)
            tone = mix(MEAT_DEEP, MEAT_RED, smooth(0.1, 0.75, up * 0.6 + streak * 0.5))
            tone = mix(tone, MEAT_RAW, smooth(0.62, 0.8, streak) * 0.8)
            tone = mix(tone, MEAT_FAT, fat * 0.75)
            loop[layer] = paint_value(tone)

    bm.to_mesh(meat.data)
    bm.free()
    meat.data.color_attributes.active_color_index = 0
    meat.data.color_attributes.render_color_index = 0
    meat.data.materials.append(bpy.data.materials["wet_meat"])
    closed(meat)
    return meat


def more_pupils():
    plain = bpy.data.objects["Pupil"]

    for name, up, across, size in PUPILS:
        mesh = plain.data.copy()
        mesh.name = name
        # About the ball's middle, which is where the pupil's mesh is held from; smaller, on the ball.
        turn = Matrix.Rotation(across, 4, "Z") @ Matrix.Rotation(up, 4, "X")
        mesh.transform(turn @ Matrix.Diagonal((size, PUPIL_PROUD, size, 1.0)))
        obj = bpy.data.objects.new(name, mesh)
        bpy.context.collection.objects.link(obj)
        obj.parent = bpy.data.objects["Ball"]
        closed(obj)
        # The flesh it pushed through, torn round it; a child, so it goes where the pupil looks.
        rim_mesh = plain.data.copy()
        rim_mesh.name = name + "_rim"
        rim_mesh.transform(turn @ Matrix.Diagonal((size * PUPIL_RIM, 0.995, size * PUPIL_RIM, 1.0)))
        bm = bmesh.new()
        bm.from_mesh(rim_mesh)
        heart = sum((v.co for v in bm.verts), Vector()) / len(bm.verts)
        # Ragged: not a washer.
        for v in bm.verts:
            off = v.co - heart
            flat = off - heart.normalized() * off.dot(heart.normalized())
            v.co += flat * RIM_TORN * noise.noise(off.normalized() * 2.6 + heart * 9.0)

        layer = bm.loops.layers.color.new("Color")

        for f in bm.faces:
            for loop in f.loops:
                loop[layer] = paint_value(mix(MEAT_RED, MEAT_RAW, noise.noise(loop.vert.co * 60.0) * 0.5 + 0.5))

        bm.to_mesh(rim_mesh)
        bm.free()
        rim_mesh.color_attributes.active_color_index = 0
        rim_mesh.color_attributes.render_color_index = 0
        rim_mesh.materials.clear()
        rim_mesh.materials.append(bpy.data.materials["wet_meat"])
        rim = bpy.data.objects.new(name + "_rim", rim_mesh)
        bpy.context.collection.objects.link(rim)
        rim.parent = obj
        closed(rim)


def previews():
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_EEVEE"
    scene.render.resolution_x = 800
    scene.render.resolution_y = 800
    world = bpy.data.worlds.new("World")
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs[0].default_value = (0.2, 0.21, 0.24, 1.0)
    scene.world = world
    sun = bpy.data.objects.new("Sun", bpy.data.lights.new("Sun", "SUN"))
    sun.data.energy = 4.0
    sun.rotation_euler = (math.radians(60), math.radians(10), math.radians(150))
    bpy.context.collection.objects.link(sun)
    camera = bpy.data.objects.new("Camera", bpy.data.cameras.new("Camera"))
    camera.data.lens = 60
    bpy.context.collection.objects.link(camera)
    scene.camera = camera

    for name, at in (("front", (0.0, 2.6, 0.1)), ("three", (1.6, 2.0, 0.5))):
        camera.location = at
        camera.rotation_euler = (Vector((0.0, 0.0, -0.05)) - camera.location).to_track_quat("-Z", "Y").to_euler()
        scene.render.filepath = os.path.join(SOURCE, "eye_turned_%s.png" % name)
        bpy.ops.render.render(write_still=True)

    bpy.data.objects.remove(sun)
    bpy.data.objects.remove(camera)


def main():
    bpy.ops.wm.open_mainfile(filepath=PLAIN)
    rng = random.Random(61)
    break_stone(rng)
    tear_lids(rng)
    build_meat(rng)
    more_pupils()
    previews()
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(SOURCE, "floating_eye_turned.blend"))
    bpy.ops.export_scene.gltf(filepath=GLB, export_format="GLB", export_yup=True, export_materials="EXPORT", export_normals=True, export_apply=False, export_vertex_color="ACTIVE", export_all_vertex_colors=False)
    print("TRIS", sum(sum(len(p.vertices) - 2 for p in o.data.polygons) for o in bpy.data.objects if o.type == "MESH"))
    print("WROTE", GLB)


main()
