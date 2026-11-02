"""The ravenous ánima's hands (silhouette A, the user's pick): a real hand, withered.
The CC0 hand the Prosecutor's arms are built from (tools/arms/extract_base_hand.py),
its skin shrunk onto its bones, fingers drawn long, knuckles and tendons standing,
hooked black nails, and the forearm it was torn from, two bones and dried skin,
dragged behind. A red thread and a tin milagro at the wrist: someone made a promise
for this one once, and stopped. Up on its fingertips, in the game (AnimaBody.gd).

Every part is a closed solid: the script refuses an open edge. Blender's axes: +Y
ahead (the game's -Z), +Z up, palm down, wrist at the origin.

    /Applications/Blender.app/Contents/MacOS/Blender --background --factory-startup \\
        --python tools/monsters/build_anima_hands.py -- <repo root>

Saves assets/monsters/source/anima_hands.blend, exports assets/monsters/anima_hands.glb
and assets/monsters/source/anima_hands_*.png previews.
"""

import math
import os
import random
import sys

import bmesh
import bpy
from mathutils import Matrix, Vector

ROOT = sys.argv[sys.argv.index("--") + 1]
sys.path.insert(0, os.path.join(ROOT, "tools", "arms"))

from build_fp_arms import FINGERS, HAND_JOINTS, hand_weights  # noqa: E402

SOURCE = os.path.join(ROOT, "assets", "monsters", "source")
GLB = os.path.join(ROOT, "assets", "monsters", "anima_hands.glb")
BASE_HAND = os.path.join(ROOT, "assets", "characters", "fp_arms", "source", "base_hand.blend")

## How big, against a man's, and how much longer its fingers are.
SIZE = 2.8
FINGER_LONG = 1.42
## How much of its flesh is left, across a finger: at a joint, and between joints.
AT_JOINT = 0.8
BETWEEN = 0.58
## The back of the hand sunk between its tendons (m, at a man's size), and how much
## of the palm's thickness is left.
SUNKEN = 0.0045
PALM_LEFT = 0.62
## Nails: how far past the fingertip, how thick at the root.
NAIL = 0.031
NAIL_WIDE = 0.0052
## The forearm: its two lengths behind the wrist (m), its bones.
ARM = (0.42, 0.42)
ARM_WIDE = (0.055, 0.044, 0.026, 0.008)
## Paint, as it should come out in the game.
DRIED = (0.2, 0.155, 0.11)
BONE = (0.43, 0.36, 0.25)
LIVER = (0.1, 0.045, 0.04)
INK = (0.012, 0.009, 0.009)
NAIL_BLACK = (0.022, 0.016, 0.014)
THREAD = (0.42, 0.035, 0.025)
TIN = (0.5, 0.48, 0.42)


def paint_value(c):
    """A colour for a colour layer, which the exporter takes for sRGB and turns to linear."""
    return (max(c[0], 0.0) ** (1.0 / 2.2), max(c[1], 0.0) ** (1.0 / 2.2), max(c[2], 0.0) ** (1.0 / 2.2), 1.0)


def mix(a, b, t):
    t = max(0.0, min(1.0, t))
    return tuple(a[i] + (b[i] - a[i]) * t for i in range(3))


def smooth(a, b, x):
    t = max(0.0, min(1.0, (x - a) / (b - a)))
    return t * t * (3.0 - 2.0 * t)


def closed_or_die(name, bm):
    bad = [e for e in bm.edges if len(e.link_faces) != 2]

    if bad:
        raise RuntimeError("%s has %d open edges" % (name, len(bad)))


JOINTS = {name: [Vector(p) for p in points] for name, points in HAND_JOINTS["fingers"].items()}


def nearest_on(point, a, b):
    way = b - a
    t = max(0.0, min(1.0, (point - a).dot(way) / max(way.length_squared, 1e-9)))
    return a + way * t, t


def long_joints():
    """Each finger's joints with its bones drawn long, from its knuckle."""
    out = {}

    for name, points in JOINTS.items():
        stretch = FINGER_LONG if name != "thumb" else 1.2
        chain = [points[0]]

        for k in range(3):
            chain.append(chain[-1] + (points[k + 1] - points[k]) * stretch)

        out[name] = chain

    return out


LONG = long_joints()


def wither_finger(co, name):
    """Where a vertex of finger `name` goes: drawn long, and shrunk onto its bone,
    waisted between the joints. Returns the new place, and how near a joint it is."""
    points = JOINTS[name]
    long = LONG[name]
    best = None

    for k in range(3):
        at, t = nearest_on(co, points[k], points[k + 1])
        d = (co - at).length

        if best is None or d < best[0]:
            best = (d, k, t, at)

    _, k, t, at = best
    new_at = long[k].lerp(long[k + 1], t)
    offset = co - at
    # A fingertip's pad past the last joint keeps its length.
    near_joint = max(1.0 - smooth(0.0, 0.3, t), smooth(0.7, 1.0, t))
    if k == 0:
        near_joint = max(near_joint * 0.9, 1.0 - smooth(0.0, 0.2, t))
    left = BETWEEN + (AT_JOINT - BETWEEN) * near_joint
    return new_at + offset * left, near_joint


def wither_hand(mesh):
    """The base hand, withered, in place. Returns per-vertex (joint nearness, sunk)."""
    bm = bmesh.new()
    bm.from_mesh(mesh)
    bm.verts.ensure_lookup_table()
    bm.normal_update()
    finger_of = [d.value for d in mesh.attributes["finger"].data]
    notes = []
    random.seed(31)

    for v in bm.verts:
        co = v.co.copy()
        n = v.normal.copy()
        owner = finger_of[v.index]
        sunk = 0.0
        joint = 0.0

        if owner:
            new, joint = wither_finger(co, FINGERS[owner - 1])
            # The nail's end of the fingertip stays round: nothing to do.
            v.co = new
        else:
            # The palm: thin it, sink the back between the metacarpals, hollow the wrist.
            thin = co.copy()
            thin.z *= PALM_LEFT if co.z < 0.0 else 0.92
            width = 1.0 - 0.22 * smooth(0.04, 0.0, co.y)
            thin.x *= width
            back = smooth(0.15, 0.6, n.z)
            lateral = 1.0

            for name in FINGERS[:4]:
                knuckle = JOINTS[name][0]
                start = Vector((knuckle.x * 0.3, 0.012, 0.0))
                at, t = nearest_on(Vector((co.x, co.y, 0.0)), start, Vector((knuckle.x, knuckle.y, 0.0)))
                lateral = min(lateral, (Vector((co.x, co.y, 0.0)) - at).length)

            ridge = 1.0 - smooth(0.0, 0.011, lateral)
            sunk = back * (1.0 - ridge) * smooth(0.012, 0.03, co.y) * (1.0 - smooth(0.075, 0.095, co.y))
            thin -= n * SUNKEN * sunk
            thin += n * 0.0024 * back * ridge * smooth(0.012, 0.03, co.y)

            # Its share of the fingers' knuckles comes along.
            for name in FINGERS[:4]:
                head = JOINTS[name][0] + Vector((0.0, 0.0, 0.008))
                d = (co - head).length
                thin += n * 0.0048 * back * math.exp(-(d / 0.0125) ** 2)
                joint = max(joint, math.exp(-(d / 0.013) ** 2) * back)

            v.co = thin

        # Dried skin isn't smooth.
        grain = random.uniform(-1.0, 1.0)
        v.co += n * grain * 0.00022
        notes.append((joint, sunk, owner))

    bm.to_mesh(mesh)
    bm.free()
    mesh.update()
    return notes


def nail_on(bm, name, wide):
    """A hooked nail, off the fingertip, curling on the way the finger curls: closed."""
    long = LONG[name]
    tip = long[3]
    way = (long[3] - long[2]).normalized()
    nail_up = Vector(HAND_JOINTS["nails"][name]).normalized()
    down = -nail_up
    start = tip - way * 0.012 + nail_up * 0.0042
    length = NAIL * (0.8 if name == "thumb" else 1.0)
    rings = []
    count = 7
    sides = 7

    for i in range(count):
        t = i / (count - 1)
        at = start + way * (t * length) + down * (t * t * length * 0.72)
        forward = (way + down * (2.0 * t * 0.72)).normalized()
        side = forward.cross(nail_up).normalized()
        up = side.cross(forward).normalized()
        radius = wide * (1.0 - t) ** 0.72 + 0.0004
        ring = []

        for k in range(sides):
            a = math.tau * k / sides
            ring.append(bm.verts.new(at + side * math.cos(a) * radius * 1.25 + up * math.sin(a) * radius * 0.62))

        rings.append(ring)

    return _skin(bm, rings, sides)


def _skin(bm, rings, sides):
    made = list(rings[0])

    for r in range(len(rings) - 1):
        for k in range(sides):
            n = (k + 1) % sides
            bm.faces.new((rings[r][k], rings[r][n], rings[r + 1][n], rings[r + 1][k]))

        made += rings[r + 1]

    bm.faces.new(list(reversed(rings[0])))
    bm.faces.new(rings[-1])
    return made


def sweep(bm, points, radii, sides=9, squash=1.0, lumps=0.0, seed=0):
    """A tube through `points`, closed at both ends."""
    rng = random.Random(seed)
    rings = []

    for i, at in enumerate(points):
        ahead = (points[min(i + 1, len(points) - 1)] - points[max(i - 1, 0)]).normalized()
        side = ahead.cross(Vector((0.0, 0.0, 1.0)))
        side = side.normalized() if side.length > 0.01 else Vector((1.0, 0.0, 0.0))
        up = side.cross(ahead).normalized()
        ring = []

        for k in range(sides):
            a = math.tau * k / sides
            r = radii[i] * (1.0 + rng.uniform(-lumps, lumps))
            ring.append(bm.verts.new(at + side * math.cos(a) * r + up * math.sin(a) * r * squash))

        rings.append(ring)

    return _skin(bm, rings, sides)


def curve(points, per=4):
    out = []
    padded = [points[0]] + points + [points[-1]]

    for k in range(1, len(padded) - 2):
        p0, p1, p2, p3 = padded[k - 1], padded[k], padded[k + 1], padded[k + 2]

        for i in range(per):
            t = i / per
            out.append(0.5 * ((2 * p1) + (p2 - p0) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t * t + (3 * p1 - p0 - 3 * p2 + p3) * t * t * t))

    out.append(points[-1])
    return out


def build():
    bpy.ops.wm.read_factory_settings(use_empty=True)

    with bpy.data.libraries.load(BASE_HAND) as (from_file, into):
        into.meshes = list(from_file.meshes)

    base = bpy.data.meshes[0]
    # What the rig's weights read: the hand as it was.
    original = [(v.co.copy(), v.normal.copy()) for v in base.vertices]
    finger_of = [d.value for d in base.attributes["finger"].data]
    notes = wither_hand(base)
    weights = [hand_weights(tuple(co), finger, tuple(n)) for (co, n), finger in zip(original, finger_of)]
    # Past the wrist, its stump: the first of the arm.
    weights = [{("arm_1" if k == "lowerarm" else k): v for k, v in w.items()} for w in weights]

    bm = bmesh.new()
    bm.from_mesh(base)
    bm.verts.ensure_lookup_table()
    hand_count = len(bm.verts)
    closed_or_die("hand", bm)
    extra = []
    colour = {}

    def own(verts, bone_name, tone):
        for v in verts:
            colour[v] = tone(v) if callable(tone) else tone
            extra.append((v, bone_name))

    # Nails.
    for name in FINGERS:
        wide = NAIL_WIDE * (0.86 if name == "pinky" else 1.0)
        own(nail_on(bm, name, wide), name + "_03", NAIL_BLACK)

    # The forearm: two bones and dried skin, drawn in, dragged out behind.
    wrist = Vector((0.0, 0.006, -0.002))
    elbow_way = Vector((0.0, -1.0, 0.0))
    mid = wrist + elbow_way * ARM[0] / SIZE * 1.0
    end = mid + elbow_way * ARM[1] / SIZE

    def arm_bone_of(y):
        return "arm_1" if y > mid.y else "arm_2"

    for side, wide, seed in ((-1.0, 1.0, 3), (1.0, 0.86, 8)):
        lean = Vector((side * 0.011, 0.0, 0.0))
        points = curve([wrist + lean + Vector((0.0, 0.012, 0.0)), wrist + lean * 1.2 + elbow_way * 0.03, wrist.lerp(mid, 0.55) + lean * 0.8, mid + lean * 0.5, mid.lerp(end, 0.55) + lean * 0.35, end + lean * 0.1], 3)
        count = len(points)
        radii = [0.0135 * wide * (1.0 - 0.62 * (i / (count - 1)) ** 1.1) * (1.0 + 0.35 * math.exp(-((i / (count - 1) - 0.0) / 0.1) ** 2) + 0.3 * math.exp(-((i / (count - 1) - 0.5) / 0.08) ** 2)) for i in range(count)]
        made = sweep(bm, points, radii, 9, 0.8, 0.05, seed)

        for v in made:
            pale = random.random()
            colour[v] = mix(DRIED, BONE, pale * 0.5)
            extra.append((v, arm_bone_of(v.co.y)))

    # Shrunk skin, webbed between the two bones.
    points = curve([wrist + Vector((0.0, 0.006, -0.003)), wrist + elbow_way * 0.03, wrist.lerp(mid, 0.5), mid, mid.lerp(end, 0.5)], 3)
    count = len(points)
    made = sweep(bm, points, [0.0165 * (1.0 - 0.62 * (i / (count - 1))) for i in range(count)], 9, 0.34, 0.1, 14)

    for v in made:
        colour[v] = mix(LIVER, DRIED, random.random() * 0.75)
        extra.append((v, arm_bone_of(v.co.y)))

    # A red thread round the wrist, knotted, with a tin heart hung from it.
    thread_at = 0.0
    turns = []
    sides = 22

    for k in range(sides + 1):
        a = math.tau * k / sides
        turns.append(Vector((math.cos(a) * 0.0285, thread_at, math.sin(a) * 0.0195 - 0.001)))

    ring_points = turns[:-1]
    rings = []

    for k, at in enumerate(ring_points):
        ahead = (ring_points[(k + 1) % sides] - ring_points[k - 1]).normalized()
        out = Vector((math.cos(math.tau * k / sides), 0.0, math.sin(math.tau * k / sides)))
        ring = [bm.verts.new(at + out * math.cos(math.tau * j / 5) * 0.0019 + Vector((0.0, 1.0, 0.0)) * math.sin(math.tau * j / 5) * 0.0019) for j in range(5)]
        rings.append(ring)

    for k in range(sides):
        n = (k + 1) % sides

        for j in range(5):
            m = (j + 1) % 5
            bm.faces.new((rings[k][j], rings[k][m], rings[n][m], rings[n][j]))

    for ring in rings:
        for v in ring:
            colour[v] = THREAD
            extra.append((v, "hand"))

    heart = [bm.verts.new(Vector((x, thread_at + y, -0.0215 + z))) for x, y, z in [(0.0, -0.0005, 0.0), (0.0048, -0.0005, -0.003), (0.0, -0.0005, -0.0105), (-0.0048, -0.0005, -0.003), (0.0, 0.0005, 0.0), (0.0048, 0.0005, -0.003), (0.0, 0.0005, -0.0105), (-0.0048, 0.0005, -0.003)]]
    bm.faces.new((heart[3], heart[2], heart[1], heart[0]))
    bm.faces.new((heart[4], heart[5], heart[6], heart[7]))

    for k in range(4):
        n = (k + 1) % 4
        bm.faces.new((heart[k], heart[n], heart[n + 4], heart[k + 4]))

    for v in heart:
        colour[v] = TIN
        extra.append((v, "hand"))

    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    closed_or_die("hands", bm)

    # The whole of it, to game size, in one.
    bmesh.ops.scale(bm, vec=(SIZE, SIZE, SIZE), verts=bm.verts)
    bm.normal_update()
    bm.verts.ensure_lookup_table()

    # Paint: dried skin, ink in every crease (how far a vertex sits under its
    # neighbours), bone showing pale at the joints and tendons.
    layer = bm.loops.layers.color.new("Color")

    for v in bm.verts:
        if v.index < hand_count:
            joint, sunk, owner = notes[v.index]
            near = [e.other_vert(v).co for e in v.link_edges]
            middle = sum(near, Vector()) / max(len(near), 1)
            sits = (v.co - middle).dot(v.normal)
            crease = smooth(0.0, -0.0028, sits)
            ridge = smooth(0.0, 0.0024, sits)
            up = smooth(-0.2, 0.7, v.normal.z)
            tone = mix(LIVER, DRIED, 0.28 + up * 0.72)
            tone = mix(tone, LIVER, sunk * 0.82)
            tone = mix(tone, BONE, min(joint * up * 0.95 + ridge * 0.55, 1.0))
            tone = mix(tone, INK, crease * 0.95)
            colour[v] = tone

    for f in bm.faces:
        for loop in f.loops:
            loop[layer] = paint_value(colour[loop.vert])

    mesh = bpy.data.meshes.new("Hand")
    extra_groups = [(v.index, name) for v, name in extra]
    bm.to_mesh(mesh)
    bm.free()
    mesh.color_attributes.active_color_index = 0
    mesh.color_attributes.render_color_index = 0

    for name in ("finger", ".sculpt_face_set"):
        if name in mesh.attributes:
            mesh.attributes.remove(mesh.attributes[name])

    for polygon in mesh.polygons:
        polygon.use_smooth = True

    hand = bpy.data.objects.new("Hand", mesh)
    bpy.context.collection.objects.link(hand)

    # The rig: wrist, each finger's three, the arm's two. Its X the way they bend.
    data = bpy.data.armatures.new("AnimaHands")
    rig = bpy.data.objects.new("Rig", data)
    bpy.context.collection.objects.link(rig)
    bpy.context.view_layer.objects.active = rig
    bpy.ops.object.mode_set(mode="EDIT")
    edit = data.edit_bones
    knuckles = Vector(HAND_JOINTS["knuckles"]) * SIZE
    root = edit.new("hand")
    root.head = Vector((0.0, 0.0, 0.0))
    root.tail = knuckles
    root.align_roll(Vector((0.0, 0.0, 1.0)))

    for name in FINGERS:
        parent = root
        nail = Vector(HAND_JOINTS["nails"][name])

        for k in range(3):
            bone = edit.new("%s_%02d" % (name, k + 1))
            bone.head = LONG[name][k] * SIZE
            bone.tail = LONG[name][k + 1] * SIZE
            bone.align_roll(nail)
            bone.parent = parent
            bone.use_connect = k > 0
            parent = bone

    arm_1 = edit.new("arm_1")
    arm_1.head = wrist * SIZE
    arm_1.tail = mid * SIZE
    arm_1.align_roll(Vector((0.0, 0.0, 1.0)))
    arm_1.parent = root
    arm_2 = edit.new("arm_2")
    arm_2.head = mid * SIZE
    arm_2.tail = end * SIZE
    arm_2.align_roll(Vector((0.0, 0.0, 1.0)))
    arm_2.parent = arm_1
    arm_2.use_connect = True
    bpy.ops.object.mode_set(mode="OBJECT")

    for i, w in enumerate(weights):
        for name, weight in w.items():
            group = hand.vertex_groups.get(name) or hand.vertex_groups.new(name=name)
            group.add([i], weight, "REPLACE")

    for index, name in extra_groups:
        group = hand.vertex_groups.get(name) or hand.vertex_groups.new(name=name)
        group.add([index], 1.0, "REPLACE")

    hand.parent = rig
    modifier = hand.modifiers.new("Armature", "ARMATURE")
    modifier.object = rig
    return rig, hand


def previews(hand):
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_EEVEE"
    scene.render.resolution_x = 800
    scene.render.resolution_y = 800
    world = bpy.data.worlds.new("World")
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs[0].default_value = (0.2, 0.21, 0.24, 1.0)
    scene.world = world
    material = bpy.data.materials.new("Paint")
    material.use_nodes = True
    nodes = material.node_tree.nodes
    attribute = nodes.new("ShaderNodeVertexColor")
    material.node_tree.links.new(attribute.outputs[0], nodes["Principled BSDF"].inputs[0])
    nodes["Principled BSDF"].inputs["Roughness"].default_value = 1.0
    hand.data.materials.append(material)
    sun = bpy.data.objects.new("Sun", bpy.data.lights.new("Sun", "SUN"))
    sun.data.energy = 4.0
    sun.rotation_euler = (math.radians(50), 0.0, math.radians(30))
    bpy.context.collection.objects.link(sun)
    camera = bpy.data.objects.new("Camera", bpy.data.cameras.new("Camera"))
    camera.data.lens = 50
    bpy.context.collection.objects.link(camera)
    scene.camera = camera

    for name, at, target in (("back", (0.0, 0.25, 1.1), (0.0, 0.25, 0.0)), ("side", (1.1, 0.2, 0.15), (0.0, 0.2, 0.0)), ("wrist", (0.25, -0.2, 0.3), (0.0, 0.02, 0.0))):
        camera.location = at
        camera.rotation_euler = (Vector(target) - camera.location).to_track_quat("-Z", "Y").to_euler()
        scene.render.filepath = os.path.join(SOURCE, "anima_hands_%s.png" % name)
        bpy.ops.render.render(write_still=True)

    hand.data.materials.clear()


def main():
    rig, hand = build()
    print("TRIS", sum(len(p.vertices) - 2 for p in hand.data.polygons), "VERTS", len(hand.data.vertices))
    previews(hand)
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(SOURCE, "anima_hands.blend"))
    bpy.ops.export_scene.gltf(filepath=GLB, export_format="GLB", export_yup=True, export_materials="NONE", export_normals=True, export_apply=False, export_vertex_color="ACTIVE", export_all_vertex_colors=False, export_skins=True, export_animations=False)
    print("WROTE", GLB)


main()
