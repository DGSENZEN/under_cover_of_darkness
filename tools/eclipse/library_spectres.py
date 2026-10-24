"""The librarian's spectres (docs/superpowers/plans/2026-10-19-librarian-shop-part-2.md, Task 3): necromancy's skull,
from CDmir's CC0 "human skull" (assets/characters/skull, credited in CREDITS.md), cut into what moves apart:

- necro_skull: the cranium and the upper teeth, its origin the middle of the whole skull;
- necro_jaw: the mandible and the lower teeth, its origin its hinge (the top of its rami, toward the back), so the
  game opens it by turning it about x;
- necro_skull_lite, necro_jaw_lite: the same, lighter, for the dead's small faces carried up in the smoke;
- alch_homunculus: alchemy's little man in his flask, Quaternius's CC0 male base body (assets/characters/base)
  curled up as an unborn child (head bowed onto his knees, arms round them), lightened, HOMUNCULUS across.

Scaled to a spectre's size (HEIGHT from the crown to the chin), its face toward -y (Godot's +z). They carry no
atlas: the game draws them black with a burning rim (anima_silhouette, anima_aura), from their own shape. Beside the
glb, library_spectres.json gives the jaw's hinge and the eye sockets' middles in the skull's frame (Godot's axes).

    Blender -b --factory-startup --python tools/eclipse/library_spectres.py
"""

import json
import os
import sys

import bpy
from mathutils import Vector, kdtree
from mathutils.bvhtree import BVHTree

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import common  # noqa: E402

SOURCE = common.ROOT / "assets" / "characters" / "skull" / "skull-Low4K.obj"
OUT = common.ROOT / "assets" / "eclipse" / "kit" / "library_spectres.glb"
POINTS = common.ROOT / "assets" / "eclipse" / "source" / "library_spectres.json"
## The skull from its crown to its chin (m): a spectre's, smaller than a living head.
HEIGHT = 0.08
## How much of its triangles the dead's faces keep.
LITE = 0.3
## The homunculus: across his longest side (m), how many triangles he keeps, his pose (each bone's turns, degrees,
## about its own axes; found by rendering: X bends the spine and the elbows forward, -X lifts a thigh).
HOMUNCULUS = 0.055
HOMUNCULUS_TRIS = 2400
CURLED = {"spine_01": [("X", 30)], "spine_02": [("X", 30)], "spine_03": [("X", 22)], "neck_01": [("X", 25)],
          "Head": [("X", 25)], "thigh_l": [("X", -128)], "thigh_r": [("X", -128)], "calf_l": [("X", 145)],
          "calf_r": [("X", 145)], "upperarm_l": [("Z", 80), ("X", 50)], "upperarm_r": [("Z", -80), ("X", 50)],
          "lowerarm_l": [("X", 125)], "lowerarm_r": [("X", 125)]}
BODY = common.ROOT / "assets" / "characters" / "base" / "Superhero_Male_FullBody.gltf"

HINGE = Vector()
EYES = []


def _loose(obj):
    """The object split into its loose parts (returns the new objects)."""
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.mesh.separate(type="LOOSE")
    bpy.ops.object.mode_set(mode="OBJECT")
    return [o for o in bpy.context.selected_objects]


def _verts(obj):
    return [obj.matrix_world @ v.co for v in obj.data.vertices]


def _join(name, parts):
    bpy.ops.object.select_all(action="DESELECT")
    for p in parts:
        p.select_set(True)
    bpy.context.view_layer.objects.active = parts[0]
    bpy.ops.object.join()
    joined = bpy.context.view_layer.objects.active
    joined.name = name
    joined.data.name = name
    return joined


def _set_origin(obj, at):
    """`obj`'s origin moved to `at` (world), its shape staying where it is."""
    shift = at - obj.location
    obj.data.transform(__import__("mathutils").Matrix.Translation(-shift))
    obj.location = at


def _lite(obj, name):
    copy = obj.copy()
    copy.data = obj.data.copy()
    copy.name = name
    copy.data.name = name
    bpy.context.scene.collection.objects.link(copy)
    cut = copy.modifiers.new("lite", "DECIMATE")
    cut.ratio = LITE
    bpy.ops.object.select_all(action="DESELECT")
    copy.select_set(True)
    bpy.context.view_layer.objects.active = copy
    bpy.ops.object.modifier_apply(modifier="lite")
    return copy


def _eyes(skull):
    """The eye sockets' middles: where, looking at the face from in front, it runs deepest, either side of the nose
    in the skull's upper half."""
    vs = _verts(skull)
    lo = Vector((min(v.x for v in vs), min(v.y for v in vs), min(v.z for v in vs)))
    hi = Vector((max(v.x for v in vs), max(v.y for v in vs), max(v.z for v in vs)))
    tree = BVHTree.FromPolygons([tuple(v) for v in vs], [tuple(p.vertices) for p in skull.data.polygons])
    eyes = []
    for side in (-1.0, 1.0):
        best = None
        for i in range(24):
            for k in range(24):
                x = side * (0.06 + 0.4 * i / 23.0) * (hi.x - lo.x) / 2.0
                z = lo.z + (0.35 + 0.35 * k / 23.0) * (hi.z - lo.z)
                hit = tree.ray_cast(Vector((x, lo.y - 1.0, z)), Vector((0.0, 1.0, 0.0)))
                if hit[0] is not None and (best is None or hit[0].y > best.y):
                    best = hit[0]
        # (Not at the socket's back wall: a little forward of it, where the eye would be.)
        eyes.append(Vector((best.x, best.y - 0.12 * (hi.y - lo.y) * 0.25, best.z)))
    return eyes


def homunculus():
    """The base body curled up, its armature's pose baked in, welded, lightened, sized and centred."""
    import bmesh
    import math
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=str(BODY))
    new = [o for o in bpy.data.objects if o not in before]
    rig = next(o for o in new if o.type == "ARMATURE")
    body = max((o for o in new if o.type == "MESH"), key=lambda o: len(o.data.vertices))
    for pb in rig.pose.bones:
        pb.rotation_mode = "XYZ"
        for axis, deg in CURLED.get(pb.name, []):
            pb.rotation_euler.rotate_axis(axis, math.radians(deg))
    bpy.context.view_layer.update()
    with bpy.context.temp_override(active_object=body, object=body, selected_objects=[body], selected_editable_objects=[body]):
        for mod in list(body.modifiers):
            if mod.type == "ARMATURE":
                bpy.ops.object.modifier_apply(modifier=mod.name)

    bm = bmesh.new()
    bm.from_mesh(body.data)
    bm.transform(body.matrix_world)
    # (Its seams welded: the base mesh splits them for its UVs.)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-4)
    mesh = bpy.data.meshes.new("alch_homunculus")
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new("alch_homunculus", mesh)
    bpy.context.scene.collection.objects.link(obj)
    for o in new:
        bpy.data.objects.remove(o, do_unlink=True)
    mesh.materials.clear()

    cut = obj.modifiers.new("lite", "DECIMATE")
    cut.ratio = min(1.0, HOMUNCULUS_TRIS / max(1, sum(len(p.vertices) - 2 for p in mesh.polygons)))
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.modifier_apply(modifier="lite")

    vs = [v.co for v in obj.data.vertices]
    lo = Vector((min(v.x for v in vs), min(v.y for v in vs), min(v.z for v in vs)))
    hi = Vector((max(v.x for v in vs), max(v.y for v in vs), max(v.z for v in vs)))
    scale = HOMUNCULUS / max(hi - lo)
    middle = (lo + hi) / 2.0
    for v in obj.data.vertices:
        v.co = (v.co - middle) * scale
    obj.data.update()
    return obj


def build():
    global HINGE, EYES
    common.reset()
    bpy.ops.wm.obj_import(filepath=str(SOURCE))
    source = [o for o in bpy.context.scene.objects if o.type == "MESH"][0]
    for slot in list(source.data.materials):
        source.data.materials.clear()
    parts = _loose(source)
    parts.sort(key=lambda o: len(o.data.vertices), reverse=True)

    # The two largest: the cranium (the higher) and the mandible; the rest teeth, each to whichever is nearer.
    big = parts[:2]
    big.sort(key=lambda o: max(v.z for v in _verts(o)), reverse=True)
    cranium, mandible = big
    trees = []
    for bone in (cranium, mandible):
        vs = _verts(bone)
        tree = kdtree.KDTree(len(vs))
        for i, v in enumerate(vs):
            tree.insert(v, i)
        tree.balance()
        trees.append(tree)
    upper, lower = [cranium], [mandible]
    for tooth in parts[2:]:
        middle = sum(_verts(tooth), Vector()) / len(tooth.data.vertices)
        (upper if trees[0].find(middle)[2] <= trees[1].find(middle)[2] else lower).append(tooth)

    skull = _join("necro_skull", upper)
    jaw = _join("necro_jaw", lower)

    # Facing -y (the chin forward of the cranium's middle); scaled to HEIGHT; the whole skull centred on the origin.
    vs = _verts(skull) + _verts(jaw)
    lo = Vector((min(v.x for v in vs), min(v.y for v in vs), min(v.z for v in vs)))
    hi = Vector((max(v.x for v in vs), max(v.y for v in vs), max(v.z for v in vs)))
    chin_y = min(v.y for v in _verts(jaw))
    turn = 1.0 if chin_y < (lo.y + hi.y) / 2.0 else -1.0
    scale = HEIGHT / (hi.z - lo.z)
    middle = (lo + hi) / 2.0
    import mathutils
    fit = mathutils.Matrix.Diagonal((turn * scale, turn * scale, scale, 1.0)) @ mathutils.Matrix.Translation(-middle)
    for obj in (skull, jaw):
        obj.data.transform(obj.matrix_world)
        obj.matrix_world = mathutils.Matrix.Identity(4)
        obj.data.transform(fit)
        obj.data.update()

    # The jaw's hinge: the top of its rami (its highest tenth), toward the back, on the middle line.
    jvs = _verts(jaw)
    top = max(v.z for v in jvs)
    span = top - min(v.z for v in jvs)
    rami = [v for v in jvs if v.z >= top - 0.1 * span]
    HINGE = Vector((0.0, sum(v.y for v in rami) / len(rami), top))
    _set_origin(jaw, HINGE)
    EYES = _eyes(skull)

    _lite(skull, "necro_skull_lite")
    lite_jaw = _lite(jaw, "necro_jaw_lite")
    lite_jaw.location = HINGE
    homunculus()


def main():
    build()
    bpy.ops.object.select_all(action="DESELECT")
    for o in bpy.context.scene.objects:
        if o.type == "MESH":
            o.select_set(True)
    OUT.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.export_scene.gltf(filepath=str(OUT), export_format="GLB", use_selection=True, export_apply=True,
                              export_materials="NONE")

    def godot(v):
        return [round(v.x, 5), round(v.z, 5), round(-v.y, 5)]

    POINTS.write_text(json.dumps({"jaw_hinge": godot(HINGE), "eyes": [godot(e) for e in EYES]}, indent=1) + "\n")
    print("library_spectres: wrote %s and %s" % (OUT.name, POINTS.name))


if __name__ == "__main__":
    main()
