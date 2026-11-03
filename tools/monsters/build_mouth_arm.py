"""The mouth's arms: the approved hands, with the flesh of the mass grown down their arms, thick where they
leave it and drawn out thin by the wrist, cords of it running on over the back of the hand. Skinned to the
arm's bones, so it goes where the arm goes.

Blender --background --factory-startup --python tools/monsters/build_mouth_arm.py -- <repo root>
With MOUTH_PICTURES set, renders each there.
"""

import math
import os
import random
import sys

import bmesh
import bpy
from mathutils import Vector, noise

ROOT = sys.argv[sys.argv.index("--") + 1]
HANDS = os.path.join(ROOT, "assets/monsters/anima_hands.glb")
LEFT = os.path.join(ROOT, "assets/monsters/anima_hands_left.glb")
OUT = os.path.join(ROOT, "assets/monsters/anima_mouth_arm.glb")
OUT_LEFT = os.path.join(ROOT, "assets/monsters/anima_mouth_arm_left.glb")
PICTURES = os.environ.get("MOUTH_PICTURES", "")

## The arm in the rig: its bones run back from the wrist along -Y, and bend at the elbow.
ARM_END = 0.823
ELBOW = 0.403
ARM_Z = -0.006
## How thick it stands: by the wrist, and where it leaves the mass; where it starts to thicken; where it starts
## (of the arm, just behind the red thread); how far it stands off what it covers.
THIN = 0.035
THICK = 0.165
THICKENS_FROM = 0.18
STARTS = 0.05
COVERS = 0.008
SLICE = 0.02
VOXEL = 0.0075
TRIS = 2800
## The cords: how many, how far on over the back of the hand they run, how thick at each end.
CORDS = 5
CORD_ONTO_HAND = 0.13
CORD_THICK = 0.014
CORD_THIN = 0.0045

## The mass's paint (build_anima_mouth.py).
LEATHER = (0.2, 0.135, 0.09)
LEATHER_DARK = (0.075, 0.05, 0.04)
RAW = (0.27, 0.07, 0.055)
FAT = (0.42, 0.33, 0.2)
DRIED = (0.17, 0.12, 0.08)


def mix(a, b, t):
    t = max(0.0, min(1.0, t))
    return tuple(a[i] + (b[i] - a[i]) * t for i in range(3))


def smooth(a, b, x):
    t = max(0.0, min(1.0, (x - a) / (b - a)))
    return t * t * (3.0 - 2.0 * t)


def paint_value(c):
    return (max(c[0], 0.0) ** (1.0 / 2.2), max(c[1], 0.0) ** (1.0 / 2.2), max(c[2], 0.0) ** (1.0 / 2.2), 1.0)


def blob(bm, at, size, seed):
    piece = bmesh.new()
    bmesh.ops.create_icosphere(piece, subdivisions=2, radius=1.0)

    for v in piece.verts:
        wobble = 1.0 + 0.3 * noise.noise(v.co * 2.3 + Vector((seed, seed * 0.7, 0.0)))
        v.co = Vector((v.co.x * size.x, v.co.y * size.y, v.co.z * size.z)) * wobble + at

    mesh = bpy.data.meshes.new("Piece")
    piece.to_mesh(mesh)
    piece.free()
    bm.from_mesh(mesh)
    bpy.data.meshes.remove(mesh)


def along(t):
    return Vector((0.0, -ARM_END * t, ARM_Z))


def thickness(t):
    return THIN + (THICK - THIN) * smooth(THICKENS_FROM, 1.0, t) ** 1.5


def apply(obj, kind, **settings):
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    modifier = obj.modifiers.new("M", kind)

    for key, value in settings.items():
        setattr(modifier, key, value)

    bpy.ops.object.modifier_apply(modifier=modifier.name)
    obj.select_set(False)


def closed(obj):
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    bad = [e for e in bm.edges if not e.is_manifold]
    count = len(bad)
    bm.free()

    if count:
        raise RuntimeError("%s has %d open edges" % (obj.name, count))


def measure(hand):
    """How far the approved arm and hand stand out, each way, along their length: {bin: [left, right, under, top]}."""
    world = hand.matrix_world
    slices = {}

    for v in hand.data.vertices:
        at = world @ v.co
        key = round(at.y / SLICE)
        here = slices.setdefault(key, [at.x, at.x, at.z, at.z])
        here[0] = min(here[0], at.x)
        here[1] = max(here[1], at.x)
        here[2] = min(here[2], at.z)
        here[3] = max(here[3], at.z)

    return slices


def stands_at(slices, y):
    """The widest of it in this slice and the two next it, so nothing pokes out between."""
    key = round(y / SLICE)
    near = [slices[k] for k in (key - 1, key, key + 1) if k in slices]

    if not near:
        return [0.0, 0.0, ARM_Z, ARM_Z]

    return [min(n[0] for n in near), max(n[1] for n in near), min(n[2] for n in near), max(n[3] for n in near)]


def build_flesh(flip, seed, slices):
    rng = random.Random(seed)
    bm = bmesh.new()

    # The limb itself, one lump after another, closed round all of the arm that was there: it comes out at the wrist.
    steps = 34

    for k in range(steps + 1):
        t = STARTS + (1.0 - STARTS) * k / steps
        stand = stands_at(slices, along(t).y)
        r = thickness(t) * (1.0 + 0.2 * noise.noise(Vector((t * 7.0, seed * 0.3, 0.0))))
        wide = max(r, max(-stand[0], stand[1]) + COVERS)
        middle = (stand[2] + stand[3]) * 0.5
        deep = max(r * 0.86, (stand[3] - stand[2]) * 0.5 + COVERS)
        blob(bm, Vector((0.0, along(t).y, middle)), Vector((wide, max(r, 0.05), deep)), seed + k * 0.7)

    # What presses out of it: the others', further up where there is more of it.
    for k in range(9):
        t = rng.uniform(0.3, 1.0)
        turn = rng.uniform(0.0, math.tau)
        r = thickness(t)
        out = Vector((math.cos(turn), 0.0, math.sin(turn))) * r * 0.82
        size = r * rng.uniform(0.34, 0.58)
        blob(bm, along(t) + out, Vector((size, size * rng.uniform(1.2, 2.2), size)), seed + 40.0 + k)

    mesh = bpy.data.meshes.new("Flesh")
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new("Flesh", mesh)
    bpy.context.collection.objects.link(obj)
    apply(obj, "REMESH", mode="VOXEL", voxel_size=VOXEL, use_smooth_shade=True)
    apply(obj, "SMOOTH", factor=0.5, iterations=2)
    ratio = min(1.0, TRIS / max(sum(len(p.vertices) - 2 for p in obj.data.polygons), 1))
    apply(obj, "DECIMATE", ratio=ratio)
    apply(obj, "SMOOTH", factor=0.5, iterations=1)
    closed(obj)
    return obj


def surface_top(objects, x, y):
    """The top of what is there, under this point, of any of `objects`."""
    best = None

    for obj in objects:
        inverse = obj.matrix_world.inverted()
        hit, at, _normal, _index = obj.ray_cast(inverse @ Vector((x, y, 1.0)), (inverse.to_3x3() @ Vector((0.0, 0.0, -1.0))).normalized())

        if hit:
            z = (obj.matrix_world @ at).z
            best = z if best is None else max(best, z)

    return best


def build_cords(flip, seed, hand, flesh):
    """Sinew from the flesh on over the back of the hand, half sunk in what it lies on: each a closed tube."""
    rng = random.Random(seed + 3)
    bm = bmesh.new()
    bpy.context.view_layer.update()

    for k in range(CORDS):
        across = (k / (CORDS - 1) - 0.5) * 2.0
        begin = rng.uniform(0.08, 0.16)
        out_to = CORD_ONTO_HAND * rng.uniform(0.6, 1.0)
        count = 22
        points = []
        last_z = ARM_Z + 0.05

        for b in range(count + 1):
            u = b / count
            y = -ARM_END * begin * (1.0 - u) + out_to * u
            # Fanning out toward the knuckles, and wandering a little, slowly.
            x = flip * across * (0.05 + 0.035 * smooth(0.0, CORD_ONTO_HAND, y)) + noise.noise(Vector((k * 3.1, y * 7.0, seed * 0.2))) * 0.006
            top = surface_top((hand, flesh), x, y)
            last_z = top if top is not None else last_z
            points.append(Vector((x, y, last_z)))

        # (It lies across the bumps, not into each.)
        for _pass in range(3):
            points = [points[0]] + [points[i - 1] * 0.25 + points[i] * 0.5 + points[i + 1] * 0.25 for i in range(1, count)] + [points[-1]]

        rings = []

        for b, at in enumerate(points):
            u = b / count
            # (Out of the flesh by degrees, and thinning away over the hand.)
            r = (CORD_THICK + (CORD_THIN - CORD_THICK) * u) * (0.25 + 0.75 * smooth(0.0, 0.2, u))
            sunk = at - Vector((0.0, 0.0, r * 0.35))
            rings.append([bm.verts.new(sunk + Vector((math.cos(j * math.tau / 6) * r, 0.0, math.sin(j * math.tau / 6) * r * 0.75))) for j in range(6)])

        for b in range(count):
            for j in range(6):
                n = (j + 1) % 6
                bm.faces.new((rings[b][j], rings[b][n], rings[b + 1][n], rings[b + 1][j]))

        bm.faces.new(list(reversed(rings[0])))
        bm.faces.new(rings[-1])

    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    mesh = bpy.data.meshes.new("Cords")
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new("Cords", mesh)
    bpy.context.collection.objects.link(obj)
    closed(obj)
    return obj


def paint(obj, seed):
    # (As the mass and the hand are painted: the same attribute, or it comes out a different colour.)
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    layer = bm.loops.layers.color.new("Color")

    for f in bm.faces:
        f.smooth = True

        for loop in f.loops:
            co = loop.vert.co
            t = max(-co.y / ARM_END, 0.0)
            folds = noise.noise(Vector((co.x * 24.0, co.y * 9.0, co.z * 24.0)) + Vector((seed, 0.0, 0.0))) * 0.5 + 0.5
            veins = abs(noise.noise(Vector((co.x * 18.0, co.y * 5.0, co.z * 18.0)) + Vector((0.0, seed, 0.0))))
            tone = mix(LEATHER, LEATHER_DARK, smooth(0.42, 0.72, folds))
            # Where it has stretched, what is under the skin shows, more up by the mass.
            tone = mix(tone, RAW, smooth(0.08, 0.0, veins) * smooth(0.1, 0.7, t) * 0.9)
            tone = mix(tone, FAT, smooth(0.66, 0.84, noise.noise(co * 13.0) * 0.5 + 0.5) * 0.45)
            # Toward the wrist it is drawn thin, and paler, over the same dried skin as the hand's.
            tone = mix(tone, DRIED, smooth(0.25, 0.02, t) * 0.8)
            loop[layer] = paint_value(tone)

    bm.to_mesh(obj.data)
    bm.free()
    obj.data.color_attributes.active_color_index = 0
    obj.data.color_attributes.render_color_index = 0


def weigh(obj, hand):
    groups = {name: obj.vertex_groups.new(name=name) for name in ("hand", "arm_1", "arm_2")}
    elbow_t = ELBOW / ARM_END

    for v in obj.data.vertices:
        t = -v.co.y / ARM_END
        on_elbow = smooth(elbow_t - 0.12, elbow_t + 0.12, t)
        off_hand = smooth(-0.02, 0.1, t)
        groups["hand"].add([v.index], 1.0 - off_hand, "REPLACE")
        groups["arm_1"].add([v.index], off_hand * (1.0 - on_elbow), "REPLACE")
        groups["arm_2"].add([v.index], off_hand * on_elbow, "REPLACE")


def build(source, out, flip, seed):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=source)
    hand = bpy.data.objects["Hand"]
    rig = next(o for o in bpy.data.objects if o.type == "ARMATURE")
    print("HAND COLOURS", [(c.name, c.domain, c.data_type) for c in hand.data.color_attributes], "PARENT", hand.parent.name if hand.parent else None)
    world = hand.matrix_world.copy()
    slices = measure(hand)
    flesh = build_flesh(flip, seed, slices)
    cords = build_cords(flip, seed, hand, flesh)

    # Into the hand's space, then into the hand.
    for piece in (flesh, cords):
        paint(piece, seed)
        weigh(piece, hand)
        piece.data.transform(world.inverted())
        piece.matrix_world = world

    bpy.ops.object.select_all(action="DESELECT")
    flesh.select_set(True)
    cords.select_set(True)
    hand.select_set(True)
    bpy.context.view_layer.objects.active = hand
    bpy.ops.object.join()
    hand.data.color_attributes.active_color_index = 0
    hand.data.color_attributes.render_color_index = 0
    print("TRIS", sum(len(p.vertices) - 2 for p in hand.data.polygons), "VERTS", len(hand.data.vertices))
    bpy.ops.export_scene.gltf(filepath=out, export_format="GLB", export_yup=True, export_materials="NONE", export_normals=True, export_apply=False, export_vertex_color="ACTIVE", export_all_vertex_colors=False, export_skins=True, export_animations=False)
    print("WROTE", out)

    if PICTURES:
        pictures(os.path.basename(out)[:-4])


def pictures(name):
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_WORKBENCH"
    scene.display.shading.light = "STUDIO"
    scene.display.shading.color_type = "VERTEX"
    scene.display.shading.show_cavity = True
    scene.render.resolution_x = 900
    scene.render.resolution_y = 600
    world = bpy.data.worlds.new("World")
    scene.world = world
    world.color = (0.05, 0.05, 0.055)
    camera_data = bpy.data.cameras.new("Look")
    camera_data.lens = 45
    camera = bpy.data.objects.new("Look", camera_data)
    bpy.context.collection.objects.link(camera)
    scene.camera = camera

    for shot, at, look in (("a_side", (1.2, -0.1, 0.25), (0.0, -0.1, 0.0)), ("b_wrist", (0.25, 0.14, 0.25), (0.0, 0.0, 0.0)), ("c_root", (0.55, -0.55, 0.45), (0.0, -0.7, 0.0))):
        camera.location = at
        camera.rotation_euler = (Vector(look) - Vector(at)).to_track_quat("-Z", "Y").to_euler()
        scene.render.filepath = os.path.join(PICTURES, "%s_%s.png" % (name, shot))
        bpy.ops.render.render(write_still=True)


build(HANDS, OUT, 1.0, 5)
build(LEFT, OUT_LEFT, -1.0, 11)
