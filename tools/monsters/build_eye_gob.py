"""What a turned eye spits: a torn gob of its own meat with a small eye pushed through it, looking
where it goes, and strands dragging behind. Unit-sized (the game scales it). Every part closed.

/Applications/Blender.app/Contents/MacOS/Blender --background --factory-startup --python tools/monsters/build_eye_gob.py -- "$PWD"
"""

import math
import os
import random
import sys

import bmesh
import bpy
from mathutils import Vector, noise

ROOT = sys.argv[sys.argv.index("--") + 1]
GLB = os.path.join(ROOT, "assets/monsters/eye_gob.glb")

MEAT_TRIS = 900
LUMPS = 9
STRANDS = 7
STRAND_LONG = (0.5, 1.1)
EYE_SIZE = 0.56
EYE_AT = Vector((0.0, 0.62, 0.04))
## Paint: the eye's own meat, and its colours.
MEAT_DEEP = (0.09, 0.008, 0.012)
MEAT_RED = (0.42, 0.03, 0.035)
MEAT_RAW = (0.72, 0.2, 0.17)
MEAT_FAT = (0.62, 0.48, 0.3)
WHITE = (0.62, 0.52, 0.36)
BLOODSHOT = (0.45, 0.05, 0.04)
IRIS = (0.95, 0.36, 0.05)
IRIS_DEEP = (0.3, 0.05, 0.01)
PUPIL = (0.005, 0.004, 0.004)
## Across the ball, as a share of its radius.
IRIS_OUT = 0.62
PUPIL_OUT = 0.3


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


def closed(obj):
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    bad = [e for e in bm.edges if len(e.link_faces) != 2]
    bm.free()

    if bad:
        raise RuntimeError("%s has %d open edges" % (obj.name, len(bad)))


def wet_look():
    look = bpy.data.materials.new("wet_meat")
    look.use_nodes = True
    return look


def build_meat(rng):
    bm = bmesh.new()

    for i in range(LUMPS):
        at = Vector((rng.uniform(-0.55, 0.55), rng.uniform(-0.65, 0.3), rng.uniform(-0.5, 0.5)))
        size = rng.uniform(0.32, 0.62)
        piece = bmesh.new()
        bmesh.ops.create_icosphere(piece, subdivisions=3, radius=size)

        for v in piece.verts:
            v.co *= 1.0 + 0.4 * noise.noise(v.co * 5.0 + Vector((i * 3.1, 0.0, 0.0)))
            v.co += at

        mesh = bpy.data.meshes.new("Piece")
        piece.to_mesh(mesh)
        piece.free()
        bm.from_mesh(mesh)
        bpy.data.meshes.remove(mesh)

    mesh = bpy.data.meshes.new("Meat")
    bm.to_mesh(mesh)
    bm.free()
    meat = bpy.data.objects.new("Meat", mesh)
    bpy.context.collection.objects.link(meat)
    apply(meat, "REMESH", mode="VOXEL", voxel_size=0.045, use_smooth_shade=True)
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
    bm = bmesh.new()
    bm.from_mesh(meat.data)
    behind = [v.co.copy() for v in bm.verts if v.co.y < -0.2]

    # Strands dragged behind it, closed tapers of their own.
    for i in range(STRANDS):
        root = rng.choice(behind)
        long = rng.uniform(*STRAND_LONG)
        rings = []

        for k in range(6):
            t = k / 5
            at = root + Vector((math.sin(t * 3.0 + i) * 0.08 * t, -long * t + 0.04, math.cos(t * 4.0 + i) * 0.08 * t))
            wide = 0.075 * (1.0 - t * 0.85) * (1.0 + 0.4 * math.sin(t * 8.0 + i))
            rings.append([bm.verts.new(at + Vector((math.cos(j * math.tau / 5) * wide, 0.0, math.sin(j * math.tau / 5) * wide))) for j in range(5)])

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
            streak = noise.noise(c * 5.0) * 0.5 + 0.5
            fat = smooth(0.64, 0.74, noise.noise(c * 3.5 + Vector((3.0, 1.0, 0.0))) * 0.5 + 0.5)
            tone = mix(MEAT_DEEP, MEAT_RED, smooth(0.25, 0.6, streak))
            tone = mix(tone, MEAT_RAW, smooth(0.6, 0.78, streak) * 0.8)
            tone = mix(tone, MEAT_FAT, fat * 0.7)
            loop[layer] = paint_value(tone)

    bm.to_mesh(meat.data)
    bm.free()
    meat.data.color_attributes.active_color_index = 0
    meat.data.color_attributes.render_color_index = 0
    meat.data.materials.append(wet_look())
    closed(meat)
    return meat


def build_eye():
    bm = bmesh.new()
    bmesh.ops.create_icosphere(bm, subdivisions=4, radius=EYE_SIZE)
    layer = bm.loops.layers.color.new("Color")

    for f in bm.faces:
        f.smooth = True

        for loop in f.loops:
            c = loop.vert.co / EYE_SIZE
            out = math.sqrt(c.x * c.x + c.z * c.z) if c.y > 0.0 else 1.0
            vein = smooth(0.2, 0.05, abs(noise.noise(c * 4.0))) * smooth(0.4, 1.0, out)
            tone = mix(WHITE, BLOODSHOT, vein * 0.85)
            tone = mix(tone, IRIS, smooth(IRIS_OUT + 0.03, IRIS_OUT - 0.03, out))
            tone = mix(tone, IRIS_DEEP, smooth(PUPIL_OUT + 0.14, PUPIL_OUT + 0.02, out))
            tone = mix(tone, PUPIL, smooth(PUPIL_OUT + 0.02, PUPIL_OUT - 0.02, out))
            loop[layer] = paint_value(tone)

    mesh = bpy.data.meshes.new("Eye")
    bm.to_mesh(mesh)
    bm.free()
    mesh.color_attributes.active_color_index = 0
    mesh.color_attributes.render_color_index = 0
    mesh.materials.append(wet_look())
    eye = bpy.data.objects.new("Eye", mesh)
    bpy.context.collection.objects.link(eye)
    eye.location = EYE_AT
    closed(eye)
    return eye


def main():
    for obj in list(bpy.data.objects):
        bpy.data.objects.remove(obj)

    rng = random.Random(17)
    build_meat(rng)
    build_eye()
    bpy.ops.export_scene.gltf(filepath=GLB, export_format="GLB", export_yup=True, export_materials="EXPORT", export_normals=True, export_apply=False, export_vertex_color="ACTIVE", export_all_vertex_colors=False)
    print("TRIS", sum(sum(len(p.vertices) - 2 for p in o.data.polygons) for o in bpy.data.objects if o.type == "MESH"))
    print("WROTE", GLB)


main()
