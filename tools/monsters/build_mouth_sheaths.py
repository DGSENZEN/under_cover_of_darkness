"""Those inside the mouth, pressing out: the game's own skull, jaw and hand with its skin drawn over them, tight,
so they come up out of its flesh as part of it. assets/monsters/mouth_sheath.glb: SkinSkull, SkinJaw (its origin at
its hinge) and SkinHand. Nothing that pokes through is separate: remeshed whole, closed, soft.

Blender --background --factory-startup --python tools/monsters/build_mouth_sheaths.py -- <repo root>
With MOUTH_PICTURES set, renders them there.
"""

import os
import sys

import bmesh
import bpy
from mathutils import Matrix, Vector, noise

ROOT = sys.argv[sys.argv.index("--") + 1]
FACE = os.path.join(ROOT, "assets/monsters/anima_face.glb")
HANDS = os.path.join(ROOT, "assets/monsters/anima_hands.glb")
OUT = os.path.join(ROOT, "assets/monsters/mouth_sheath.glb")
PICTURES = os.environ.get("MOUTH_PICTURES", "")
VOXEL = 0.0095
SKIN_OVER = 0.005
TRIS = {"SkinSkull": 1500, "SkinJaw": 700, "SkinHand": 1500}
## How far back along its arm the hand stops: it is under the skin from there.
HAND_TO = -0.16

LEATHER = (0.2, 0.135, 0.09)
LEATHER_DARK = (0.05, 0.032, 0.026)
RAW = (0.27, 0.07, 0.055)
TAUT = (0.46, 0.38, 0.26)


def mix(a, b, t):
    t = max(0.0, min(1.0, t))
    return tuple(a[i] + (b[i] - a[i]) * t for i in range(3))


def smooth(a, b, x):
    t = max(0.0, min(1.0, (x - a) / (b - a)))
    return t * t * (3.0 - 2.0 * t)


def paint_value(c):
    return (max(c[0], 0.0) ** (1.0 / 2.2), max(c[1], 0.0) ** (1.0 / 2.2), max(c[2], 0.0) ** (1.0 / 2.2), 1.0)


def apply(obj, kind, **settings):
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    modifier = obj.modifiers.new("M", kind)

    for key, value in settings.items():
        setattr(modifier, key, value)

    bpy.ops.object.modifier_apply(modifier=modifier.name)
    obj.select_set(False)


def skin_it(name, mesh):
    """Closed and soft, drawn tight, and painted: pale where it is stretched over something, dark in what it sinks into."""
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    # (Thin fingers can come out of the remesh sharing an edge: coarser, then, until they don't.)
    first = obj.data.copy()

    for voxel_try in range(6):
        obj.data = first.copy()
        apply(obj, "REMESH", mode="VOXEL", voxel_size=VOXEL * (1.0 + voxel_try * 0.15), use_smooth_shade=True)
        bm = bmesh.new()
        bm.from_mesh(obj.data)
        bad = sum(1 for e in bm.edges if not e.is_manifold)
        bm.free()

        if bad == 0:
            break

    apply(obj, "SMOOTH", factor=0.6, iterations=3)
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    bm.normal_update()

    for v in bm.verts:
        v.co += v.normal * SKIN_OVER

    bm.to_mesh(obj.data)
    bm.free()
    polys = sum(len(p.vertices) - 2 for p in obj.data.polygons)
    whole = obj.data.copy()

    # (A collapse can pinch: a little less of it, then, until it doesn't.)
    for attempt in range(14):
        obj.data = whole.copy()
        apply(obj, "DECIMATE", ratio=min(1.0, TRIS[name] * (1.0 + attempt * 0.3) / max(polys, 1)))
        bm = bmesh.new()
        bm.from_mesh(obj.data)
        bad = sum(1 for e in bm.edges if not e.is_manifold)
        bm.free()

        if bad == 0:
            break
    else:
        raise RuntimeError("%s has %d open edges" % (name, bad))

    apply(obj, "SMOOTH", factor=0.5, iterations=1)
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    bm.normal_update()

    # How far each stands out of what is round it, or sinks.
    stands = {}

    for v in bm.verts:
        around = [e.other_vert(v).co for e in v.link_edges]
        middle = sum(around, Vector()) / max(len(around), 1)
        stands[v] = (v.co - middle).dot(v.normal)

    for _ in range(2):
        stands = {v: (stands[v] + sum(stands[e.other_vert(v)] for e in v.link_edges) / max(len(v.link_edges), 1)) * 0.5 for v in bm.verts}

    layer = bm.loops.layers.color.new("Color")

    for f in bm.faces:
        f.smooth = True

        for loop in f.loops:
            v = loop.vert
            folds = noise.noise(v.co * 34.0) * 0.5 + 0.5
            tone = mix(LEATHER, LEATHER_DARK, smooth(0.5, 0.74, folds))
            tone = mix(tone, TAUT, smooth(0.0, 0.0045, stands[v]))
            tone = mix(tone, LEATHER_DARK, smooth(0.0, -0.004, stands[v]))
            veins = abs(noise.noise(v.co * 21.0 + Vector((3.0, 0.0, 0.0))))
            tone = mix(tone, RAW, smooth(0.05, 0.0, veins) * 0.7)
            loop[layer] = paint_value(tone)

    bm.to_mesh(obj.data)
    bm.free()
    obj.data.color_attributes.active_color_index = 0
    obj.data.color_attributes.render_color_index = 0
    return obj


def mesh_of(obj, world=None):
    mesh = obj.data.copy()
    mesh.transform(world if world is not None else obj.matrix_world)
    return mesh


def main():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=FACE)
    bpy.context.view_layer.update()
    skull_mesh = mesh_of(bpy.data.objects["Skull"])
    jaw_object = bpy.data.objects["Jaw"]
    hinge = jaw_object.matrix_world.to_translation()
    jaw_mesh = mesh_of(jaw_object)
    bpy.ops.import_scene.gltf(filepath=HANDS)
    bpy.context.view_layer.update()
    hand_object = next(o for o in bpy.data.objects if o.type == "MESH" and o.name.startswith("Hand"))
    hand_mesh = mesh_of(hand_object)

    for obj in list(bpy.data.objects):
        bpy.data.objects.remove(obj)

    bm = bmesh.new()
    bm.from_mesh(hand_mesh)
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if v.co.y < HAND_TO], context="VERTS")
    bm.to_mesh(hand_mesh)
    bm.free()
    skull = skin_it("SkinSkull", skull_mesh)
    jaw = skin_it("SkinJaw", jaw_mesh)
    jaw.data.transform(Matrix.Translation(-hinge))
    jaw.location = hinge
    hand = skin_it("SkinHand", hand_mesh)
    print("TRIS", {o.name: sum(len(p.vertices) - 2 for p in o.data.polygons) for o in (skull, jaw, hand)}, "HINGE", tuple(round(c, 3) for c in hinge))
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.export_scene.gltf(filepath=OUT, export_format="GLB", export_yup=True, export_materials="NONE", export_normals=True, export_apply=False, export_vertex_color="ACTIVE", export_all_vertex_colors=False)
    print("WROTE", OUT)

    if PICTURES:
        scene = bpy.context.scene
        scene.render.engine = "BLENDER_WORKBENCH"
        scene.display.shading.light = "STUDIO"
        scene.display.shading.color_type = "VERTEX"
        scene.display.shading.show_cavity = True
        scene.render.resolution_x = 900
        scene.render.resolution_y = 700
        world = bpy.data.worlds.new("World")
        scene.world = world
        camera_data = bpy.data.cameras.new("Look")
        camera_data.lens = 60
        camera = bpy.data.objects.new("Look", camera_data)
        bpy.context.collection.objects.link(camera)
        scene.camera = camera
        jaw.rotation_euler = (-0.6, 0.0, 0.0)
        hand.location = (0.7, 0.0, 0.0)

        for name, at, look in (("face", (0.0, 0.75, 0.0), (0.0, 0.0, -0.03)), ("hand", (0.7, 0.2, 0.95), (0.7, 0.2, 0.0))):
            camera.location = at
            camera.rotation_euler = (Vector(look) - Vector(at)).to_track_quat("-Z", "Y").to_euler()
            scene.render.filepath = os.path.join(PICTURES, "sheath_%s.png" % name)
            bpy.ops.render.render(write_still=True)


main()
