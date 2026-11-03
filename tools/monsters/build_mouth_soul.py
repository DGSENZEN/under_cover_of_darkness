"""One of those it has swallowed, straining to get out of it: a skull gaping, and all it has left drawn out
behind into a tail, back to where it is held. Few triangles: there are several, and it is only light.
Its colour's red is how far along it is: 1 at the head, 0 at the end of the tail.

Blender --background --factory-startup --python tools/monsters/build_mouth_soul.py -- <repo root>
"""

import math
import os
import sys

import bmesh
import bpy
from mathutils import Matrix, Vector, noise

ROOT = sys.argv[sys.argv.index("--") + 1]
FACE = os.path.join(ROOT, "assets/monsters/anima_face.glb")
OUT = os.path.join(ROOT, "assets/monsters/mouth_soul.glb")
JAW_OPEN = -0.62
VOXEL = 0.011
SOUL_TRIS = 1500
## The tail: how long (m), how wide where it leaves the head, how many lengths of it.
TAIL = 1.0
TAIL_WIDE = 0.1
RINGS = 22
HEAD_BACK = -0.08


def apply(obj, kind, **settings):
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    modifier = obj.modifiers.new("M", kind)

    for key, value in settings.items():
        setattr(modifier, key, value)

    bpy.ops.object.modifier_apply(modifier=modifier.name)
    obj.select_set(False)


def main():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=FACE)
    bpy.context.view_layer.update()
    bm = bmesh.new()

    for name in ("Skull", "Jaw"):
        obj = bpy.data.objects[name]
        world = obj.matrix_world.copy()

        if name == "Jaw":
            hinge = world.to_translation()
            world = Matrix.Translation(hinge) @ Matrix.Rotation(JAW_OPEN, 4, "X") @ Matrix.Translation(-hinge) @ world

        mesh = obj.data.copy()
        mesh.transform(world)
        bm.from_mesh(mesh)
        bpy.data.meshes.remove(mesh)

    mesh = bpy.data.meshes.new("Soul")
    bm.to_mesh(mesh)
    bm.free()

    for obj in list(bpy.data.objects):
        bpy.data.objects.remove(obj)

    # The tail, in with the head before the remesh: one surface, so nothing shows inside it.
    bm = bmesh.new()
    bm.from_mesh(mesh)

    for k in range(RINGS * 2 + 1):
        t = k / (RINGS * 2)
        wide = TAIL_WIDE * (1.0 - t) ** 1.25 + 0.016
        at = Vector((math.sin(t * 5.5) * 0.05 * t, HEAD_BACK - TAIL * t, 0.02 + math.sin(t * 3.1 + 1.0) * 0.06 * t))
        piece = bmesh.new()
        bmesh.ops.create_icosphere(piece, subdivisions=2, radius=wide)
        bmesh.ops.translate(piece, vec=at, verts=piece.verts)
        bead = bpy.data.meshes.new("Bead")
        piece.to_mesh(bead)
        piece.free()
        bm.from_mesh(bead)
        bpy.data.meshes.remove(bead)

    bm.to_mesh(mesh)
    bm.free()
    soul = bpy.data.objects.new("Soul", mesh)
    bpy.context.collection.objects.link(soul)
    apply(soul, "REMESH", mode="VOXEL", voxel_size=VOXEL, use_smooth_shade=True)
    apply(soul, "SMOOTH", factor=0.6, iterations=4)
    apply(soul, "DECIMATE", ratio=min(1.0, SOUL_TRIS / max(sum(len(p.vertices) - 2 for p in soul.data.polygons), 1)))
    apply(soul, "SMOOTH", factor=0.5, iterations=1)
    bm = bmesh.new()
    bm.from_mesh(soul.data)
    layer = bm.loops.layers.color.new("Color")

    for f in bm.faces:
        f.smooth = True

        for loop in f.loops:
            along = max(0.0, min(1.0, 1.0 - (HEAD_BACK - loop.vert.co.y) / TAIL))
            loop[layer] = (along, along, along, 1.0)

    bm.to_mesh(soul.data)
    bm.free()
    soul.data.color_attributes.active_color_index = 0
    soul.data.color_attributes.render_color_index = 0
    print("TRIS", sum(len(p.vertices) - 2 for p in soul.data.polygons))
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.export_scene.gltf(filepath=OUT, export_format="GLB", export_yup=True, export_materials="NONE", export_normals=True, export_apply=False, export_vertex_color="ACTIVE", export_all_vertex_colors=False)
    print("WROTE", OUT)


main()
