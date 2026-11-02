"""The ravenous ánima's face (silhouette B, the user's pick): small and dried, behind the
two great hands, only pits and a mouth. CDmir's CC0 human skull (assets/characters/skull,
credited in CREDITS.md) with the skin dried onto it: closed up, the cranium drawn in, the
jaw grown long, painted as leather over bone with ink in every hollow.

Two closed solids, the skull and the jaw (its origin its hinge, so it drops). The script
refuses an open edge. Blender's axes: +Y ahead (the game's -Z), +Z up.

    /Applications/Blender.app/Contents/MacOS/Blender --background --factory-startup \\
        --python tools/monsters/build_anima_face.py -- <repo root>

Saves assets/monsters/source/anima_face.blend, exports assets/monsters/anima_face.glb and
assets/monsters/source/anima_face_*.png previews.
"""

import math
import os
import random
import sys

import bmesh
import bpy
from mathutils import Matrix, Vector, kdtree
from mathutils.bvhtree import BVHTree

ROOT = sys.argv[sys.argv.index("--") + 1]
SKULL = os.path.join(ROOT, "assets", "characters", "skull", "skull-Low4K.obj")
SOURCE = os.path.join(ROOT, "assets", "monsters", "source")
GLB = os.path.join(ROOT, "assets", "monsters", "anima_face.glb")

## Crown to chin (m).
HEIGHT = 0.36
## Remeshed this fine, then brought down to this many faces each.
VOXEL = 0.0024
SKULL_FACES = 1650
JAW_FACES = 600
## The cranium drawn in, the jaw grown long and narrow.
CRANIUM_NARROW = 0.92
JAW_LONG = 1.26
JAW_NARROW = 0.9
## The eye pits, carved deep and slanted: where, how wide, how tall, how deep, how much tilt.
EYE_AT = (0.047, 0.036)
EYE_SIZE = (0.036, 0.029)
EYE_DEEP = 0.05
EYE_TILT = 0.34
## Long dried upper teeth: how many, how far across the arc, how long, how thick.
TEETH = 9
TEETH_ACROSS = 0.05
TOOTH_LONG = 0.027
TOOTH_WIDE = 0.0052
## Paint, as it should come out in the game.
LEATHER = (0.17, 0.125, 0.085)
LEATHER_DARK = (0.075, 0.05, 0.04)
BONE = (0.5, 0.43, 0.3)
TOOTH = (0.56, 0.5, 0.34)
INK = (0.008, 0.006, 0.006)


def paint_value(c):
    return (max(c[0], 0.0) ** (1.0 / 2.2), max(c[1], 0.0) ** (1.0 / 2.2), max(c[2], 0.0) ** (1.0 / 2.2), 1.0)


def mix(a, b, t):
    t = max(0.0, min(1.0, t))
    return tuple(a[i] + (b[i] - a[i]) * t for i in range(3))


def smooth(a, b, x):
    t = max(0.0, min(1.0, (x - a) / (b - a)))
    return t * t * (3.0 - 2.0 * t)


def world_verts(obj):
    return [obj.matrix_world @ v.co for v in obj.data.vertices]


def loose(obj):
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.mesh.separate(type="LOOSE")
    bpy.ops.object.mode_set(mode="OBJECT")
    return list(bpy.context.selected_objects)


def join(name, parts):
    bpy.ops.object.select_all(action="DESELECT")

    for part in parts:
        part.select_set(True)

    bpy.context.view_layer.objects.active = parts[0]
    bpy.ops.object.join()
    obj = bpy.context.view_layer.objects.active
    obj.name = name
    obj.data.name = name
    return obj


def apply_modifier(obj, kind, **settings):
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    mod = obj.modifiers.new(kind, kind)

    for key, value in settings.items():
        setattr(mod, key, value)

    bpy.ops.object.modifier_apply(modifier=mod.name)


def close_up(obj, faces, shape=None):
    """Closed, by voxels (which also takes the sculpt's hard pieces into one skin), shaped
    while it is still fine, then brought down, keeping its shape."""
    apply_modifier(obj, "REMESH", mode="VOXEL", voxel_size=VOXEL, use_smooth_shade=True)

    if shape is not None:
        shape(obj)

    now = len(obj.data.polygons)
    apply_modifier(obj, "DECIMATE", decimate_type="COLLAPSE", ratio=min(faces / max(now, 1), 1.0))
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    bad = [e for e in bm.edges if len(e.link_faces) != 2]

    if bad:
        raise RuntimeError("%s has %d open edges" % (obj.name, len(bad)))

    bm.free()


def in_eye(co):
    """How far inside an eye pit a point is, seen from the front: 1 in the middle, 0 out."""
    x = abs(co.x) - EYE_AT[0]
    z = co.z - EYE_AT[1]
    c = math.cos(EYE_TILT)
    t = math.sin(EYE_TILT)
    along = (x * c + z * t) / EYE_SIZE[0]
    up = (-x * t + z * c) / EYE_SIZE[1]
    return 1.0 - smooth(0.68, 1.0, math.sqrt(along * along + up * up))


def carve_eyes(obj):
    front = max(v.co.y for v in obj.data.vertices)

    for v in obj.data.vertices:
        v.co.x *= CRANIUM_NARROW
        inside = in_eye(v.co)

        if inside > 0.0 and v.co.y > front - 0.075:
            v.co.y -= EYE_DEEP * inside


def add_teeth(obj, hinge):
    """Long and dried, the gum drawn back: a closed taper each, into the bone. Returns their
    vertices' indices."""
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    bm.verts.ensure_lookup_table()
    front = max(v.co.y for v in bm.verts)
    made = []
    random.seed(19)
    tree = BVHTree.FromBMesh(bm)

    for i in range(TEETH):
        u = (i / (TEETH - 1)) * 2.0 - 1.0
        x = u * TEETH_ACROSS
        # In the gum along the line of the mouth, against the front of the bone there.
        top = hinge.z + 0.008 + abs(u) * 0.004
        hit = tree.ray_cast(Vector((x, front + 0.05, top + 0.006)), Vector((0.0, -1.0, 0.0)), 0.2)
        y = (hit[0].y if hit[0] is not None else front - 0.02 - u * u * 0.03) - 0.0045
        long = TOOTH_LONG * (1.0 - abs(u) * 0.25) * random.uniform(0.82, 1.12)
        wide = TOOTH_WIDE * (1.15 if abs(u) < 0.3 else 0.9)
        rings = []

        for k, (down, grow) in enumerate(((0.0, 0.9), (0.45, 1.0), (0.8, 0.7), (1.0, 0.14))):
            ring = []

            for j in range(6):
                a = math.tau * j / 6
                ring.append(bm.verts.new(Vector((x + math.cos(a) * wide * grow, y + math.sin(a) * wide * grow * 0.7 + down * 0.002, top - down * long))))

            rings.append(ring)

        for r in range(3):
            for j in range(6):
                n = (j + 1) % 6
                bm.faces.new((rings[r][j], rings[r][n], rings[r + 1][n], rings[r + 1][j]))

        bm.faces.new(list(reversed(rings[0])))
        bm.faces.new(rings[-1])
        made += [v for ring in rings for v in ring]

    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.verts.index_update()
    teeth = {v.index for v in made}
    bad = [e for e in bm.edges if len(e.link_faces) != 2]

    if bad:
        raise RuntimeError("teeth left %d open edges" % len(bad))

    bm.to_mesh(obj.data)
    bm.free()
    return teeth


def bump(co, at, reach):
    return math.exp(-((co - Vector(at)).length / reach) ** 2)


def paint(obj, teeth, tooth_line, is_jaw, front):
    """Leather over bone, by the anatomy: bone at the brow, the cheekbones, the bridge of the
    nose, the chin; ink down in the pits and every hollow; the teeth pale."""
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    bm.normal_update()
    bm.verts.ensure_lookup_table()
    tree = BVHTree.FromBMesh(bm)
    random.seed(7)
    colour = {}

    for v in bm.verts:
        if v.index in teeth:
            colour[v] = TOOTH
            continue

        hit = tree.ray_cast(v.co + v.normal * 0.002, v.normal, 0.05)
        hollow = 1.0 - smooth(0.004, 0.05, hit[3]) if hit[0] is not None else 0.0
        c = v.co
        face_on = smooth(-0.1, 0.7, v.normal.y)
        up = smooth(-0.4, 0.8, v.normal.z)
        tone = mix(LEATHER_DARK, LEATHER, 0.35 + up * 0.5)

        if is_jaw:
            bone = bump(c, (0.0, front, tooth_line - 0.075), 0.05)
            bone = max(bone, 1.0 - smooth(0.0, 0.016, abs(c.z - tooth_line)) if c.y > front - 0.06 else 0.0)
        else:
            x = abs(c.x)
            brow = bump(Vector((x, c.y, c.z)), (0.045, front - 0.012, EYE_AT[1] + EYE_SIZE[1] + 0.012), 0.032)
            cheek = bump(Vector((x, c.y, c.z)), (0.07, front - 0.03, EYE_AT[1] - EYE_SIZE[1] - 0.018), 0.026)
            bridge = bump(c, (0.0, front, EYE_AT[1] - 0.005), 0.02)
            maxilla = 1.0 - smooth(0.0, 0.016, c.z - tooth_line) if c.y > front - 0.05 and c.z > tooth_line - 0.012 else 0.0
            bone = max(brow, cheek, bridge, maxilla)

        tone = mix(tone, BONE, bone * face_on * 0.92)
        tone = mix(tone, INK, smooth(0.3, 0.8, hollow))

        if not is_jaw:
            tone = mix(tone, INK, smooth(0.12, 0.45, in_eye(c)) * smooth(front - 0.008, front - 0.022, c.y))

        colour[v] = tone

    layer = bm.loops.layers.color.new("Color")

    for f in bm.faces:
        for loop in f.loops:
            loop[layer] = paint_value(colour[loop.vert])

    bm.to_mesh(obj.data)
    bm.free()
    obj.data.color_attributes.active_color_index = 0
    obj.data.color_attributes.render_color_index = 0

    for polygon in obj.data.polygons:
        polygon.use_smooth = True


def build():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.wm.obj_import(filepath=SKULL)
    source = [o for o in bpy.context.scene.objects if o.type == "MESH"][0]
    source.data.materials.clear()
    parts = loose(source)
    parts.sort(key=lambda o: len(o.data.vertices), reverse=True)
    big = parts[:2]
    big.sort(key=lambda o: max(v.z for v in world_verts(o)), reverse=True)
    cranium, mandible = big
    trees = []

    for bone in (cranium, mandible):
        vs = world_verts(bone)
        tree = kdtree.KDTree(len(vs))

        for i, v in enumerate(vs):
            tree.insert(v, i)

        tree.balance()
        trees.append(tree)

    upper, lower = [cranium], [mandible]

    for tooth in parts[2:]:
        vs = world_verts(tooth)
        middle = sum(vs, Vector()) / len(vs)
        (upper if trees[0].find(middle)[2] <= trees[1].find(middle)[2] else lower).append(tooth)

    skull = join("Skull", upper)
    jaw = join("Jaw", lower)

    # Fitted: facing +Y, HEIGHT tall, the whole of it round the origin.
    for obj in (skull, jaw):
        obj.data.transform(obj.matrix_world)
        obj.matrix_world = Matrix.Identity(4)

    vs = world_verts(skull) + world_verts(jaw)
    lo = Vector((min(v.x for v in vs), min(v.y for v in vs), min(v.z for v in vs)))
    hi = Vector((max(v.x for v in vs), max(v.y for v in vs), max(v.z for v in vs)))
    chin_y = min(world_verts(jaw), key=lambda v: v.z).y
    turn = 1.0 if chin_y > (lo.y + hi.y) * 0.5 else -1.0
    size = HEIGHT / (hi.z - lo.z)
    fit = Matrix.Diagonal((turn * size, turn * size, size, 1.0)) @ Matrix.Translation(-(lo + hi) * 0.5)

    for obj in (skull, jaw):
        obj.data.transform(fit)
        obj.data.update()

    jvs = world_verts(jaw)
    top = max(v.z for v in jvs)
    span = top - min(v.z for v in jvs)
    rami = [v for v in jvs if v.z >= top - 0.12 * span]
    hinge = Vector((0.0, sum(v.y for v in rami) / len(rami), top))
    tooth_upper = min(v.z for v in world_verts(skull)) + 0.012
    tooth_lower = max(v.z for v in jvs if v.y > max(u.y for u in jvs) - 0.05)

    close_up(skull, SKULL_FACES, carve_eyes)
    close_up(jaw, JAW_FACES)

    # Dried: the jaw grown long and narrow, about its hinge.
    for v in jaw.data.vertices:
        from_hinge = v.co - hinge
        v.co = hinge + Vector((from_hinge.x * JAW_NARROW, from_hinge.y, from_hinge.z * JAW_LONG))

    tooth_lower = hinge.z + (tooth_lower - hinge.z) * JAW_LONG
    front = max(v.co.y for v in skull.data.vertices)
    teeth = add_teeth(skull, hinge)
    paint(skull, teeth, tooth_upper, False, front)
    paint(jaw, set(), tooth_lower - 0.006, True, front)
    jaw.data.transform(Matrix.Translation(-hinge))
    jaw.location = hinge
    jaw.parent = skull
    print("HINGE", tuple(round(x, 4) for x in hinge), "TRIS", sum(len(p.vertices) - 2 for p in skull.data.polygons), sum(len(p.vertices) - 2 for p in jaw.data.polygons))
    return skull, jaw


def previews(skull, jaw):
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_EEVEE"
    scene.render.resolution_x = 700
    scene.render.resolution_y = 700
    world = bpy.data.worlds.new("World")
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs[0].default_value = (0.2, 0.21, 0.24, 1.0)
    scene.world = world
    look = bpy.data.materials.new("Paint")
    look.use_nodes = True
    nodes = look.node_tree.nodes
    attribute = nodes.new("ShaderNodeVertexColor")
    look.node_tree.links.new(attribute.outputs[0], nodes["Principled BSDF"].inputs[0])
    nodes["Principled BSDF"].inputs["Roughness"].default_value = 1.0
    skull.data.materials.append(look)
    jaw.data.materials.append(look)
    sun = bpy.data.objects.new("Sun", bpy.data.lights.new("Sun", "SUN"))
    sun.data.energy = 4.0
    sun.rotation_euler = (math.radians(-65), math.radians(10), 0.0)
    bpy.context.collection.objects.link(sun)
    camera = bpy.data.objects.new("Camera", bpy.data.cameras.new("Camera"))
    camera.data.lens = 70
    bpy.context.collection.objects.link(camera)
    scene.camera = camera
    jaw.rotation_euler.x = math.radians(26)

    for name, at in (("front", (0.0, 0.85, 0.0)), ("three", (0.5, 0.65, 0.1)), ("side", (0.85, 0.0, 0.0))):
        camera.location = at
        camera.rotation_euler = (Vector((0.0, 0.0, -0.03)) - camera.location).to_track_quat("-Z", "Y").to_euler()
        scene.render.filepath = os.path.join(SOURCE, "anima_face_%s.png" % name)
        bpy.ops.render.render(write_still=True)

    jaw.rotation_euler.x = 0.0
    skull.data.materials.clear()
    jaw.data.materials.clear()


def main():
    skull, jaw = build()
    previews(skull, jaw)
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(SOURCE, "anima_face.blend"))
    bpy.ops.export_scene.gltf(filepath=GLB, export_format="GLB", export_yup=True, export_materials="NONE", export_normals=True, export_apply=False, export_vertex_color="ACTIVE", export_all_vertex_colors=False)
    print("WROTE", GLB)


main()
