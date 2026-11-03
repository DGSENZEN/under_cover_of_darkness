"""The revenant: too long and too large to be a man, bloated from the water, old, and coming for you. From the
Quaternius base, moved by its own skeleton into its stance and its proportions, long sinewy limbs against a trunk
swollen and sagging with water; a real skull with flesh hung on it, its teeth its own; tezontle crusted over a hump
on one shoulder, milagros nailed into it, what it wore rotted into it, and a rig of its own. The stance is its rest
pose: it stands hunched, arms hanging past its knees, and that is what its skin is built for.

It never left the lake. Its hair, the roots grown on its crust and its rags drift up off it as if it were still under
water (UV x: how far along each it is, for revenant_flesh.gdshader; UV y: its own phase), and the seep that raised it
lights a split down its chest and the cracks round what holds it (colour alpha: under 0.85 how much seep; above, its eyes).

Blender --background --factory-startup --python tools/monsters/build_revenant.py -- <repo root>
With REVENANT_PICTURES set, renders each view there.
"""

import math
import os
import random
import sys

import bmesh
import bpy
from mathutils import Matrix, Vector, noise
from mathutils.bvhtree import BVHTree

ROOT = sys.argv[sys.argv.index("--") + 1]
BASE = os.path.join(ROOT, "assets/characters/base/Superhero_Male_FullBody.gltf")
FACE = os.path.join(ROOT, "assets/monsters/anima_face.glb")
OUT = os.path.join(ROOT, "assets/monsters/revenant.glb")
PICTURES = os.environ.get("REVENANT_PICTURES", "")

STANDS = 2.6
## The base scaled up before it is stretched, and turned to face the way the game's bodies do.
GROWS = 1.2
VOXEL_FIRST = 0.012
VOXEL_LAST = 0.0068
TRIS = 26000
HEART = 22
HEAD_SCALE = 1.22
HEAD_TILT = 0.42
## The jaw hangs open this far (rad) in its rest: the mouth is there to open further.
JAW_HANGS = 0.3

# In the base's own space: it faces -y, its left is +x. [bone, way, stretched along, across]
STANCE = [
    ("spine_01", (0.0, -0.3, 1.0), 1.3, 0.82),
    ("spine_02", (0.0, -0.62, 1.0), 1.32, 0.95),
    ("spine_03", (0.0, -0.95, 0.75), 1.3, 1.0),
    ("neck_01", (0.0, -1.0, 0.12), 3.4, 1.0),
    # Wrong for each other: the left carries the crust, down and forward; the right is hauled up, reaching.
    ("clavicle_l", (1.0, -0.5, -0.34), 1.4, 1.0),
    ("upperarm_l", (0.42, -0.38, -1.0), 2.1, 0.72),
    ("lowerarm_l", (0.2, -0.55, -1.0), 2.2, 0.74),
    ("hand_l", (0.1, -0.4, -1.0), 1.85, 1.6),
    ("clavicle_r", (-1.0, -0.2, 0.08), 1.5, 1.0),
    ("upperarm_r", (-0.5, -0.2, -1.0), 2.25, 0.66),
    ("lowerarm_r", (-0.12, -0.7, -1.0), 2.35, 0.64),
    ("hand_r", (-0.05, -0.55, -1.0), 1.85, 1.6),
    ("thigh_l", (0.3, -0.5, -1.0), 1.36, 0.78),
    ("calf_l", (0.06, 0.48, -1.0), 1.48, 0.68),
    ("foot_l", (0.05, -1.0, -0.45), 1.45, 0.95),
    ("thigh_r", (-0.22, -0.28, -1.0), 1.36, 0.74),
    ("calf_r", (-0.08, 0.42, -1.0), 1.48, 0.66),
    ("foot_r", (-0.1, -1.0, -0.45), 1.45, 0.95),
]
FINGERS = ("index", "middle", "ring", "pinky", "thumb")
FINGERS_STRETCH = 1.95
FINGERS_ACROSS = 1.3

# Its bones: name, what it follows, and the base's bones it takes the weights of.
FINGER_NAMES = {"index": "finger_1", "middle": "finger_2", "ring": "finger_3", "pinky": "finger_4", "thumb": "thumb"}

# How much each bone's flesh swells all over (m). Little: the bloat is in the sacks.
SWELLS = {
    "hips": 0.05, "spine": 0.08, "chest": 0.07, "neck_1": 0.035, "neck_2": 0.025, "clavicle": 0.035, "arm_1": 0.032, "arm_2": 0.024,
    "hand": 0.006, "leg_1": 0.04, "leg_2": 0.022, "foot": 0.012, "head": 0.0, "jaw": 0.0,
}
PALE = (0.36, 0.36, 0.31)
PALE_COLD = (0.25, 0.3, 0.28)
BRUISE = (0.2, 0.2, 0.25)
SILT = (0.045, 0.05, 0.042)
ROT = (0.26, 0.2, 0.13)
WOOL = (0.17, 0.145, 0.12)
WOOL_LIT = (0.3, 0.25, 0.2)
HAIR = (0.018, 0.022, 0.024)
HAIR_TIP = (0.05, 0.07, 0.06)
ROOT = (0.07, 0.05, 0.035)
ROOT_TIP = (0.16, 0.14, 0.08)
TEZONTLE = (0.2, 0.065, 0.05)
LAKE_CRUST = (0.42, 0.39, 0.3)
TIN = (0.6, 0.58, 0.47)
IRON = (0.1, 0.085, 0.075)


def mix(a, b, t):
    t = max(0.0, min(1.0, t))
    return tuple(a[i] + (b[i] - a[i]) * t for i in range(3))


def smooth(a, b, x):
    t = max(0.0, min(1.0, (x - a) / (b - a)))
    return t * t * (3.0 - 2.0 * t)


def paint_value(c, alpha=1.0):
    return (max(c[0], 0.0) ** (1.0 / 2.2), max(c[1], 0.0) ** (1.0 / 2.2), max(c[2], 0.0) ** (1.0 / 2.2), alpha)


def apply(obj, kind, **settings):
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    modifier = obj.modifiers.new("M", kind)

    for key, value in settings.items():
        setattr(modifier, key, value)

    bpy.ops.object.modifier_apply(modifier=modifier.name)
    obj.select_set(False)


def new_bone_of(old):
    """The bone of ours that takes this base bone's weights, or None for one it doesn't keep."""
    side = old[-2:] if old[-2:] in ("_l", "_r") else ""
    stem = old[:-2] if side else old
    plain = {"pelvis": "hips", "spine_01": "spine", "spine_02": "chest", "spine_03": "chest", "neck_01": "neck_1", "Head": "head", "root": "hips",
             "clavicle": "clavicle", "upperarm": "arm_1", "lowerarm": "arm_2", "hand": "hand", "thigh": "leg_1", "calf": "leg_2", "foot": "foot", "ball": "foot", "ball_leaf": "foot"}

    if stem in plain:
        return plain[stem] + side

    for finger, name in FINGER_NAMES.items():
        if stem.startswith(finger):
            return name + ("" if stem.endswith("_01") else "_b") + side

    return None


def stance():
    """Moves the base into its stance. Returns its baked mesh in the game's facing, with our bones' weights, and where its joints are."""
    bpy.ops.import_scene.gltf(filepath=BASE)
    rig = next(o for o in bpy.data.objects if o.type == "ARMATURE")
    body = next(o for o in bpy.data.objects if o.name.startswith("SuperHero_Male"))

    for obj in list(bpy.data.objects):
        if obj not in (rig, body):
            bpy.data.objects.remove(obj)

    for bone in rig.data.bones:
        bone.inherit_scale = "NONE"

    def aim(name, way, stretch, across):
        bpy.context.view_layer.update()
        pose = rig.pose.bones[name]
        frame = pose.matrix.copy()
        head = frame.to_translation()
        turn = frame.to_3x3().col[1].normalized().rotation_difference(Vector(way).normalized())
        pose.matrix = Matrix.Translation(head) @ turn.to_matrix().to_4x4() @ frame.to_quaternion().to_matrix().to_4x4()
        pose.scale = (across, stretch, across)

    for name, way, stretch, across in STANCE:
        aim(name, way, stretch, across)

    for side in ("_l", "_r"):
        for finger in FINGERS:
            for joint in ("_01", "_02", "_03"):
                rig.pose.bones[finger + joint + side].scale = (FINGERS_ACROSS, FINGERS_STRETCH, FINGERS_ACROSS)

    # Its fingers hang half closed, as a hand with nothing in it does.
    for side in ("_l", "_r"):
        for finger in FINGERS[:4]:
            for joint, bend in (("_01", 0.35), ("_02", 0.55), ("_03", 0.35)):
                rig.pose.bones[finger + joint + side].rotation_mode = "XYZ"
                rig.pose.bones[finger + joint + side].rotation_euler = (bend, 0.0, 0.0)

    bpy.context.view_layer.update()
    # Grown, and turned to face +y as the game's models do.
    place = Matrix.Rotation(math.pi, 4, "Z") @ Matrix.Scale(GROWS, 4)
    at = lambda name: place @ (rig.matrix_world @ rig.pose.bones[name].head)
    tip = lambda name: place @ (rig.matrix_world @ rig.pose.bones[name].tail)
    joints = {}

    for old, new in (("pelvis", "hips"), ("spine_01", "spine"), ("spine_02", "chest"), ("neck_01", "neck_1")):
        joints[new] = at(old)

    joints["neck_end"] = tip("neck_01")
    joints["chest_end"] = tip("spine_03")

    for side in ("_l", "_r"):
        for old, new in (("clavicle", "clavicle"), ("upperarm", "arm_1"), ("lowerarm", "arm_2"), ("hand", "hand"), ("thigh", "leg_1"), ("calf", "leg_2"), ("foot", "foot")):
            joints[new + side] = at(old + side)
            joints[new + "_end" + side] = tip(old + side)

        for finger, name in FINGER_NAMES.items():
            joints[name + side] = at(finger + "_01" + side)
            joints[name + "_b" + side] = at(finger + "_02" + side)
            joints[name + "_tip" + side] = tip(finger + "_03" + side)

    # Baked, with its weights under our names.
    old_names = {g.index: g.name for g in body.vertex_groups}
    bpy.context.view_layer.objects.active = body
    body.select_set(True)
    modifier = next(m for m in body.modifiers if m.type == "ARMATURE")
    bpy.ops.object.modifier_apply(modifier=modifier.name)
    body.select_set(False)
    weights = []

    for v in body.data.vertices:
        row = {}

        for group in v.groups:
            new = new_bone_of(old_names[group.group])

            if new:
                row[new] = row.get(new, 0.0) + group.weight

        weights.append(row)

    mesh = body.data.copy()
    mesh.transform(body.matrix_world)
    mesh.transform(place)
    # Stands on the floor.
    lowest = min(v.co.z for v in mesh.vertices)
    # (And over its hips, whatever its stance has done: what stands on the floor and turns is there, its head well ahead of it.)
    drop = Vector((-joints["hips"].x, -joints["hips"].y, -lowest))
    mesh.transform(Matrix.Translation(drop))

    for key in joints:
        joints[key] += drop

    bpy.data.objects.remove(body)
    bpy.data.objects.remove(rig)
    return mesh, weights, joints


def without_head(mesh, weights):
    """Everything above the neck goes: the head is the skull's."""
    bm = bmesh.new()
    bm.from_mesh(mesh)
    bm.verts.ensure_lookup_table()
    doomed = [bm.verts[i] for i, row in enumerate(weights) if row.get("head", 0.0) > 0.25]
    keep = [row for i, row in enumerate(weights) if row.get("head", 0.0) <= 0.25]
    bmesh.ops.delete(bm, geom=doomed, context="VERTS")
    # (A voxel remesh closes what's left of it, and the skull goes over the hole.)
    bm.to_mesh(mesh)
    bm.free()
    return keep


def islands_of(mesh):
    """Splits a mesh by what's joined up (welded first: a glTF comes in split at its seams), largest first."""
    bm = bmesh.new()
    bm.from_mesh(mesh)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=0.00002)
    seen = set()
    out = []

    for start in bm.verts:
        if start in seen:
            continue

        pile = [start]
        seen.add(start)
        group = []

        while pile:
            v = pile.pop()
            group.append(v)

            for e in v.link_edges:
                other = e.other_vert(v)

                if other not in seen:
                    seen.add(other)
                    pile.append(other)

        part = bm.copy()
        part.verts.ensure_lookup_table()
        indexes = {v.index for v in group}
        bmesh.ops.delete(part, geom=[v for v in part.verts if v.index not in indexes], context="VERTS")
        piece = bpy.data.meshes.new("Piece")
        part.to_mesh(piece)
        part.free()
        out.append(piece)

    bm.free()
    out.sort(key=lambda m: -len(m.vertices))
    return out


def head_on(joints):
    """The real skull and its teeth, on the neck, hung low and forward. Returns the skull's and the jaw's flesh, their teeth, what
    hangs in its mouth, where the jaw hinges and where its sockets are."""
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=FACE)
    made = set(bpy.data.objects) - before
    pieces = {}

    for obj in made:
        if obj.type == "MESH":
            mesh = obj.data.copy()
            mesh.transform(obj.matrix_world)
            pieces[obj.name.split(".")[0]] = mesh

    hinge = next(o for o in made if o.name == "Jaw").matrix_world.to_translation()

    for obj in made:
        bpy.data.objects.remove(obj)

    tilt = Matrix.Rotation(HEAD_TILT, 4, "X")
    box = [v.co for v in pieces["Skull"].vertices]
    base = Vector((0.0, min(c.y for c in box) + 0.09, min(c.z for c in box) + 0.05))
    place = Matrix.Translation(joints["neck_end"]) @ tilt @ Matrix.Scale(HEAD_SCALE, 4) @ Matrix.Translation(-base)
    hinge_at = place @ hinge
    jaw_place = Matrix.Translation(hinge_at) @ Matrix.Rotation(JAW_HANGS, 4, "X") @ Matrix.Translation(-hinge_at) @ place
    skull_parts = islands_of(pieces["Skull"])
    jaw_parts = islands_of(pieces["Jaw"])
    skull = skull_parts[0]
    # In the socket, a little out from its floor, so it shows and the socket stays dark round it.
    sockets = [place @ (pit + Vector((0.0, 0.016, 0.0))) for pit in pits_of(skull)]
    skull.transform(place)
    # (The jaw's flesh is its two biggest: bone and gum.)
    jaw_flesh = jaw_parts[:2]
    jaw_teeth = jaw_parts[2:]
    skull_teeth = skull_parts[1:]

    for part in jaw_flesh + jaw_teeth:
        part.transform(jaw_place)

    for part in skull_teeth:
        part.transform(place)

    pieces["Gullet"].transform(place)
    pieces["Tongue"].transform(jaw_place)
    print("HEAD", [round(c, 3) for c in (place @ Vector((0.0, max(c.y for c in box), 0.0)))], "HINGE", [round(c, 3) for c in hinge_at], "TEETH", len(skull_teeth), len(jaw_teeth))
    return skull, joined(jaw_flesh), skull_teeth, jaw_teeth, [pieces["Gullet"]], [pieces["Tongue"]], hinge_at, sockets


def knobs_of(joints):
    """Its joints: bone standing out of the flesh at the elbow, wrist, knee, ankle and shoulder, the flesh wasted between them, so a limb has a place to bend and you can see it."""
    out = []

    for side in ("_l", "_r"):
        shoulder, elbow, wrist = joints["arm_1" + side], joints["arm_2" + side], joints["hand" + side]
        hip, knee, ankle = joints["leg_1" + side], joints["leg_2" + side], joints["foot" + side]
        out += [
            (elbow + Vector((0.0, -0.03, 0.0)), Vector((0.075, 0.075, 0.075)), 0.05, 0.0),
            (wrist, Vector((0.055, 0.055, 0.05)), 0.024, 0.0),
            (knee + Vector((0.0, 0.03, 0.0)), Vector((0.085, 0.085, 0.085)), 0.05, 0.0),
            (ankle, Vector((0.06, 0.06, 0.05)), 0.022, 0.0),
            (shoulder, Vector((0.1, 0.1, 0.1)), 0.04, 0.0),
            # (The muscle of it: high on the bone, wasted below.)
            (shoulder.lerp(elbow, 0.34), Vector((0.1, 0.1, 0.17)), 0.028, 0.0),
            (elbow.lerp(wrist, 0.26), Vector((0.08, 0.08, 0.15)), 0.024, 0.0),
            (elbow.lerp(wrist, 0.76), Vector((0.075, 0.075, 0.16)), -0.016, 0.0),
            (hip.lerp(knee, 0.4), Vector((0.12, 0.12, 0.2)), 0.03, 0.0),
            (knee.lerp(ankle, 0.28), Vector((0.09, 0.09, 0.15)), 0.028, 0.0),
            (knee.lerp(ankle, 0.8), Vector((0.08, 0.08, 0.15)), -0.012, 0.0),
        ]

    return out


def sacks_of(joints):
    """Where the water has gathered, and how it hangs: [centre, radii, how far out, how far down]. Its left is -x here."""
    chest = joints["chest"]
    # (Each from inside it: it swells out from there.)
    belly = joints["spine"].lerp(joints["chest"], 0.45) + Vector((0.0, 0.05, -0.02))
    hump = joints["chest_end"] + Vector((-0.1, -0.08, -0.04))
    throat = joints["neck_1"].lerp(joints["neck_end"], 0.45) + Vector((0.0, 0.0, -0.03))
    fore = joints["arm_2_l"].lerp(joints["hand_l"], 0.42)
    upper = joints["arm_1_l"].lerp(joints["arm_2_l"], 0.3)
    thigh = joints["leg_1_r"].lerp(joints["leg_2_r"], 0.35)
    jowl_l = joints["neck_end"] + Vector((-0.1, 0.09, 0.0))
    jowl_r = joints["neck_end"] + Vector((0.11, 0.1, 0.02))
    return [
        (belly, Vector((0.26, 0.28, 0.32)), 0.15, 0.17),
        (chest + Vector((0.12, 0.08, 0.1)), Vector((0.17, 0.17, 0.2)), 0.05, 0.04),
        (hump, Vector((0.26, 0.26, 0.3)), 0.15, 0.04),
        (throat + Vector((0.0, -0.08, -0.03)), Vector((0.12, 0.13, 0.13)), 0.07, 0.1),
        (fore, Vector((0.13, 0.13, 0.26)), 0.055, 0.03),
        (upper, Vector((0.16, 0.16, 0.24)), 0.05, 0.02),
        (thigh, Vector((0.18, 0.18, 0.3)), 0.05, 0.03),
        (jowl_l, Vector((0.1, 0.1, 0.11)), 0.05, 0.05),
        (jowl_r, Vector((0.1, 0.1, 0.11)), 0.06, 0.06),
    ] + knobs_of(joints)


def nails_on(joints):
    """Long black nails, on the ends of its fingers, part of the skin."""
    out = []

    for side in ("_l", "_r"):
        for name in FINGER_NAMES.values():
            tip = joints[name + "_tip" + side]
            way = (tip - joints[name + "_b" + side]).normalized()
            bm = bmesh.new()
            bmesh.ops.create_cone(bm, cap_ends=True, segments=6, radius1=0.014, radius2=0.002, depth=0.1, matrix=Matrix.Translation(tip + way * 0.03) @ way.to_track_quat("Z", "Y").to_matrix().to_4x4())
            mesh = bpy.data.meshes.new("Nail")
            bm.to_mesh(mesh)
            bm.free()
            out.append(mesh)

    return out


def joined(meshes):
    bm = bmesh.new()

    for mesh in meshes:
        bm.from_mesh(mesh)

    out = bpy.data.meshes.new("Joined")
    bm.to_mesh(out)
    bm.free()
    return out


def weigh_by(mesh, rows):
    """A lookup: for a point, the weights where the nearest face of `mesh` is, from `rows` per vertex."""
    bm = bmesh.new()
    bm.from_mesh(mesh)
    bmesh.ops.triangulate(bm, faces=bm.faces)
    bm.verts.ensure_lookup_table()
    bm.faces.ensure_lookup_table()
    tree = BVHTree.FromBMesh(bm)
    faces = [[(v.index, v.co.copy()) for v in f.verts] for f in bm.faces]
    bm.free()

    def lookup(point):
        _hit, _normal, index, _distance = tree.find_nearest(point)
        total = {}
        near = 0.0

        for i, at in faces[index]:
            share = 1.0 / max((at - point).length, 0.002)
            near += share

            for name, weight in rows[i].items():
                total[name] = total.get(name, 0.0) + weight * share

        return {name: weight / near for name, weight in total.items()}

    return lookup


def swells_at(row):
    total = 0.0

    for name, weight in row.items():
        stem = name[:-2] if name[-2:] in ("_l", "_r") else name
        total += SWELLS.get(stem, 0.008) * weight

    return total


def remesh(obj, voxel):
    apply(obj, "REMESH", mode="VOXEL", voxel_size=voxel, use_smooth_shade=True)


def sculpt(obj, lookup, sacks):
    """Thin, and swollen only where the water has gathered: the skin tight on the sacks, folded under them."""
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    bm.normal_update()

    for v in bm.verts:
        row = lookup(v.co)
        rest = v.co.copy()
        out = swells_at(row) + noise.noise(rest * 3.1 + Vector((3.1, 0.0, 0.0))) * 0.012 * (1.0 - min(row.get("head", 0.0) + row.get("jaw", 0.0), 1.0))
        move = v.normal * out

        for centre, radii, far, down in sacks:
            d = rest - centre
            r = Vector((d.x / radii.x, d.y / radii.y, d.z / radii.z)).length_squared

            if r > 6.0:
                continue

            g = math.exp(-r)
            move += d.normalized() * far * g
            # It hangs: most of all at the bottom of it.
            move.z -= down * g * smooth(0.6, -0.7, d.z / radii.z)
            # And the skin folds where it comes in under its own weight.
            if d.z < 0.0:
                move += v.normal * -0.022 * g * max(1.0 - abs(noise.noise(Vector((rest.x * 1.2, rest.y * 1.2, rest.z * 13.0)))) * 6.0, 0.0)

        v.co += move

    bm.to_mesh(obj.data)
    bm.free()


def jowls(c, hinge):
    """What hangs off the skull: cheeks gone to water, swollen, sagging past the jaw."""
    move = Vector()

    for side, far, down in ((-1.0, 0.034, 0.03), (1.0, 0.045, 0.042)):
        d = c - (hinge + Vector((side * 0.085, 0.03, -0.01)))
        g = math.exp(-Vector((d.x / 0.05, d.y / 0.07, d.z / 0.07)).length_squared)
        move += (d.normalized() * far + Vector((0.0, 0.0, -down))) * g

    return move


def split_wanders(z):
    return noise.noise(Vector((z * 3.4, 4.0, 1.0))) * 0.17 + noise.noise(Vector((z * 13.0, 9.0, 1.0))) * 0.035


def split_at(c, normal_y, row, top, bottom):
    """How near the split down its chest this is: 1 in it, 0 clear of it."""
    trunk = row.get("chest", 0.0) + row.get("spine", 0.0) + row.get("hips", 0.0) * 0.5

    if trunk < 0.3 or normal_y < -0.1 or c.z > top or c.z < bottom:
        return 0.0

    ends = smooth(top, top - 0.22, c.z) * smooth(bottom, bottom + 0.2, c.z)
    # (Wider and narrower as it goes, closing up altogether in places.)
    wide = 0.05 + max(noise.noise(Vector((c.z * 6.0, 2.0, 5.0))), -0.03) * 0.09
    return smooth(wide * 1.5, wide * 0.25, abs(c.x - split_wanders(c.z))) * ends


def stone_and_cloth(obj, lookup, crust_at, cloth_of, hinge, split_top, split_bottom):
    """Done on the finest skin, so it stays sharp: the crust's crags, and the lip of what it wore."""
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    bm.normal_update()
    moves = []

    for v in bm.verts:
        c = v.co.copy()
        grown = crust_of(c, crust_at)
        out = 0.0

        if grown > 0.0:
            distances, _points = noise.voronoi(c * 11.0, distance_metric="DISTANCE", exponent=2.5)
            crag = 1.0 - min(distances[0] * 1.5, 1.0)
            pits = max(0.5 - abs(noise.noise(c * 41.0)) * 9.0, 0.0)
            out = grown * (0.035 + crag * 0.085 - pits * 0.012)
            moves.append(v.normal * out)
            continue

        row = lookup(c)
        face = row.get("head", 0.0) + row.get("jaw", 0.0)
        rag = cloth_of(row, c)
        # Skin: mottled, slack, folded where it gathers at a joint. Over the skull, lumps of what's left.
        slack = noise.noise(c * 9.0) * 0.006 + max(1.0 - abs(noise.noise(c * Vector((5.0, 5.0, 16.0)))) * 7.0, 0.0) * -0.006
        out = rag * 0.012 + slack * (1.0 - rag * 0.5) * (1.0 - face * 0.6)
        # The split: sunk in, its lips standing.
        split = split_at(c, v.normal.y, row, split_top, split_bottom)
        out += smooth(0.1, 0.55, split) * 0.016 * (1.0 - smooth(0.55, 0.95, split)) - smooth(0.55, 0.95, split) * 0.075
        move = v.normal * out

        if face > 0.0:
            move += v.normal * max(noise.noise(c * 13.0 + Vector((2.0, 0.0, 0.0))), 0.0) * 0.022 * face
            move += jowls(c, hinge) * face

        moves.append(move)

    for v, move in zip(bm.verts, moves):
        v.co += move

    bm.to_mesh(obj.data)
    bm.free()


def crust_of(c, crust_at):
    """How far the crust has grown here, 0..1, ragged at its edge."""
    best = 0.0

    for at, size in crust_at:
        best = max(best, 1.0 - (c - at).length / size)

    return smooth(0.0, 0.3, best + noise.noise(c * 6.0) * 0.16)


def closed_and_cut(obj):
    whole = obj.data.copy()
    polys = sum(len(p.vertices) - 2 for p in whole.polygons)
    print("BEFORE", polys)

    for attempt in range(14):
        obj.data = whole.copy()
        bpy.context.view_layer.objects.active = obj
        obj.select_set(True)
        modifier = obj.modifiers.new("M", "DECIMATE")
        modifier.ratio = min(1.0, TRIS * (1.0 + attempt * 0.1) / max(polys, 1))
        bpy.ops.object.modifier_apply(modifier=modifier.name)
        obj.select_set(False)
        bm = bmesh.new()
        bm.from_mesh(obj.data)
        bad = sum(1 for e in bm.edges if not e.is_manifold)
        bm.free()

        if bad == 0:
            print("TRIS", sum(len(p.vertices) - 2 for p in obj.data.polygons), "attempt", attempt)
            return

    raise RuntimeError("the revenant has %d open edges" % bad)


def milagro(bm_out, at, normal, rng, marks):
    """A tin heart or arm or leg, and the nail through it, driven into its flesh: closed pieces of their own."""
    side = normal.cross(Vector((0.0, 0.0, 1.0)))
    side = side.normalized() if side.length > 0.01 else Vector((1.0, 0.0, 0.0))
    up = side.cross(normal).normalized()
    twist = rng.uniform(-0.6, 0.6)
    side, up = side * math.cos(twist) + up * math.sin(twist), up * math.cos(twist) - side * math.sin(twist)
    size = rng.uniform(0.03, 0.05)
    # A heart's outline, thin and closed.
    outline = []

    for i in range(HEART):
        a = i / float(HEART) * math.tau
        x = 16.0 * math.sin(a) ** 3
        y = 13.0 * math.cos(a) - 5.0 * math.cos(2.0 * a) - 2.0 * math.cos(3.0 * a) - math.cos(4.0 * a)
        outline.append((x / 17.0, y / 17.0))

    plate = at + normal * 0.012
    made = []

    for depth, rows in ((0.0, "front"), (-0.006, "back")):
        made.append([bm_out.verts.new(plate + normal * depth + side * x * size + up * y * size) for x, y in outline])

    faces = [bm_out.faces.new(made[0]), bm_out.faces.new(list(reversed(made[1])))]

    for i in range(HEART):
        j = (i + 1) % HEART
        faces.append(bm_out.faces.new((made[1][i], made[1][j], made[0][j], made[0][i])))

    # The nail: a square head, and a shank down into the flesh.
    head = 0.014
    nail = [plate + normal * 0.012 + side * sx * head + up * sy * head for sx, sy in ((-1, -1), (1, -1), (1, 1), (-1, 1))]
    root = [at - normal * 0.05 + side * sx * head * 0.3 + up * sy * head * 0.3 for sx, sy in ((-1, -1), (1, -1), (1, 1), (-1, 1))]
    top = [bm_out.verts.new(c) for c in nail]
    bottom = [bm_out.verts.new(c) for c in root]
    nail_faces = [bm_out.faces.new(top), bm_out.faces.new(list(reversed(bottom)))]

    for i in range(4):
        j = (i + 1) % 4
        nail_faces.append(bm_out.faces.new((bottom[i], bottom[j], top[j], top[i])))

    for f in faces:
        marks[f] = "tin"

    for f in nail_faces:
        marks[f] = "iron"

    bmesh.ops.recalc_face_normals(bm_out, faces=faces + nail_faces)


def strand(bm, roots, marks, kind, root, way, length, radius, flat, rng, uv_layer, attach_layer):
    """One thing drifting off it: a closed taper, or a flat rag, rising and curling as it would under water."""
    rows = 11
    sides = 4 if flat else 6
    phase = rng.random()
    seed = rng.uniform(0.0, 50.0)
    at = root - way * radius
    heading = way.copy()
    rings = []
    roots.append(root.copy())
    index = len(roots)

    for i in range(rows):
        t = i / float(rows - 1)
        across = heading.cross(Vector((0.13, 0.27, 0.95))).normalized()
        other = heading.cross(across).normalized()
        wide = (radius * (1.0 - t * 0.92) if not flat else radius * (1.0 - t * 0.88))
        ring = []

        for k in range(sides):
            a = (k + 0.5) / sides * math.tau
            offset = across * math.cos(a) * wide + other * math.sin(a) * (wide * (0.09 if flat else 1.0))
            ring.append(bm.verts.new(at + offset))

        rings.append((ring, t))
        # Mostly back, and only a little up: it's being carried by something slow.
        heading = (heading + Vector((0.0, -0.16, 0.05)) + Vector((noise.noise(Vector((seed, t * 2.4, 0.0))), noise.noise(Vector((seed, t * 2.4, 7.0))), noise.noise(Vector((seed, t * 2.4, 13.0))) * 0.6)) * 0.42).normalized()
        at += heading * length / (rows - 1)

    faces = [bm.faces.new([v for v in reversed(rings[0][0])]), bm.faces.new(rings[-1][0])]

    for i in range(rows - 1):
        a, b = rings[i][0], rings[i + 1][0]

        for k in range(sides):
            j = (k + 1) % sides
            faces.append(bm.faces.new((a[k], a[j], b[j], b[k])))

    for ring, t in rings:
        for v in ring:
            v[attach_layer] = index

    place_t = {v: t for ring, t in rings for v in ring}

    for f in faces:
        marks[f] = kind
        f.smooth = True

        for loop in f.loops:
            loop[uv_layer].uv = (place_t[loop.vert], phase)


def strands_on(bm, tree, marks, lookup, cloth_of, crust_at, sockets, rng):
    """Its hair, the lake's roots grown on its crust, and its rags. Returns where each is fixed, for its weights."""
    uv_layer = bm.loops.layers.uv.get("UVMap") or bm.loops.layers.uv.new("UVMap")
    attach_layer = bm.verts.layers.int.new("Attach")
    roots = []
    crown = sockets[0].lerp(sockets[1], 0.5) + Vector((0.0, -0.12, 0.05))
    hair = roots_made = rags = 0

    for _attempt in range(400):
        if hair >= 30:
            break

        way = Vector((rng.gauss(0.0, 0.8), rng.uniform(-1.0, -0.1), rng.uniform(-0.1, 0.8))).normalized()
        hit, normal, _i, _d = tree.ray_cast(crown + way * 0.8, -way, 0.8)

        if hit is None or normal.dot(way) < 0.25:
            continue

        strand(bm, roots, marks, "hair", hit, (way + Vector((0.0, -0.5, 0.1))).normalized(), rng.uniform(0.4, 0.95), rng.uniform(0.014, 0.024), False, rng, uv_layer, attach_layer)
        hair += 1

    for _attempt in range(400):
        if roots_made >= 16:
            break

        at, size = crust_at[rng.randrange(len(crust_at))]
        way = Vector((rng.gauss(0.0, 1.0), rng.gauss(0.0, 1.0), rng.gauss(0.2, 0.8))).normalized()
        hit, normal, _i, _d = tree.ray_cast(at + way * 1.0, -way, 1.2)

        if hit is None or normal.dot(way) < 0.2 or (hit - at).length > size:
            continue

        strand(bm, roots, marks, "root", hit, (normal + Vector((0.0, -0.3, -0.2))).normalized(), rng.uniform(0.2, 0.5), rng.uniform(0.012, 0.02), False, rng, uv_layer, attach_layer)
        roots_made += 1

    for _attempt in range(1500):
        if rags >= 30:
            break

        at = Vector((rng.uniform(-0.9, 0.9), rng.uniform(-0.6, 0.9), rng.uniform(0.5, 1.9)))
        way = Vector((rng.gauss(0.0, 1.0), rng.gauss(0.0, 1.0), rng.gauss(-0.1, 0.5))).normalized()
        hit, normal, _i, _d = tree.ray_cast(at + way * 1.5, -way, 2.0)

        if hit is None or normal.dot(way) < 0.25:
            continue

        here = cloth_of(lookup(hit), hit)

        # (From where it has torn: its edge, not the middle of it.)
        if here < 0.05 or here > 0.95:
            continue

        strand(bm, roots, marks, "rag", hit, (normal * 0.8 + Vector((0.0, -0.3, 0.15))).normalized(), rng.uniform(0.2, 0.46), rng.uniform(0.025, 0.05), True, rng, uv_layer, attach_layer)
        rags += 1

    print("DRIFTING", hair, roots_made, rags)
    return roots


def pits_of(skull):
    """Where its eyes go: the deepest of each socket, measured on the skull alone, in its own space. A ray counts only with bone
    round it, so nothing past its cheek can pass for a socket. The skull isn't the same on both sides."""
    bm = bmesh.new()
    bm.from_mesh(skull)
    tree = BVHTree.FromBMesh(bm)
    ys = [v.co.y for v in bm.verts]
    front = max(ys) + 0.05
    step = 0.006
    depth = {}

    for i in range(-22, 23):
        for k in range(-12, 24):
            hit, _normal, _index, _distance = tree.ray_cast(Vector((i * step, front, k * step)), Vector((0.0, -1.0, 0.0)), 1.0)
            depth[(i, k)] = (front - hit.y) if hit is not None else None

    pits = []

    for side in (-1, 1):
        best = None
        most = -1.0

        for (i, k), d in depth.items():
            if d is None or i * side < 4 or k < 2:
                continue

            # Rim: shallower bone, this far out, every way round.
            rim = [depth.get((i + a, k + b)) for a, b in ((7, 0), (-7, 0), (0, 6), (0, -6), (5, 5), (-5, 5), (5, -5), (-5, -5))]

            if any(r is None or r > d - 0.012 for r in rim):
                continue

            if d > most:
                most = d
                best = (i, k)

        if best is None:
            raise RuntimeError("no socket found on side %d" % side)

        at = Vector((best[0] * step, front - most, best[1] * step))
        pits.append(at)
        print("PIT", side, [round(c, 3) for c in at], "deep", round(most, 3))

    bm.free()
    return pits


def in_their_sockets(bm, eyes, ahead):
    """Refuses an eye with no skull round it: left, right, above, below, and nothing in front."""
    tree = BVHTree.FromBMesh(bm)
    up = ahead.cross(Vector((1.0, 0.0, 0.0))).normalized() * -1.0

    for eye in eyes:
        for way in (Vector((1.0, 0.0, 0.0)), Vector((-1.0, 0.0, 0.0)), up, -up):
            hit, _normal, _index, _distance = tree.ray_cast(eye, way, 0.09)

            if hit is None:
                raise RuntimeError("an eye at %s has no skull round it, %s" % (eye, way))

        hit, _normal, _index, _distance = tree.ray_cast(eye + ahead * 0.024, ahead, 0.5)

        if hit is not None:
            raise RuntimeError("an eye at %s is covered" % eye)


def nail_them_on(obj, lookup, rng):
    """Into its chest, its hump, its arms, by the dozen: the living did this to keep it down."""
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    tree = BVHTree.FromBMesh(bm)
    marks = {}
    placed = []

    for attempt in range(2500):
        at = Vector((rng.uniform(-0.7, 0.7), rng.uniform(-0.8, 1.0), rng.uniform(0.9, 2.1)))
        way = Vector((rng.gauss(0.0, 1.0), rng.gauss(0.2, 1.0), rng.gauss(0.2, 0.5))).normalized()
        hit, normal, _index, _distance = tree.ray_cast(at + way * 2.0, -way, 2.4)

        if hit is None or normal.dot(way) < 0.3:
            continue

        row = lookup(hit)
        on_it = row.get("chest", 0.0) + row.get("spine", 0.0) + row.get("clavicle_r", 0.0) + row.get("arm_1_r", 0.0) * 0.8

        if on_it < 0.35 or any((hit - other).length < 0.13 for other in placed):
            continue

        milagro(bm, hit, normal, rng, marks)
        placed.append(hit.copy())

        if len(placed) >= 26:
            break

    print("MILAGROS", len(placed))
    return bm, marks


def paint(bm, marks, lookup, crust_at, cloth_of, nails, nailed, split_top, split_bottom):
    """Pale and cold, silt in its folds, veins dark under stretched skin, what it wore rotted into it, stone on its shoulder."""
    bm.verts.ensure_lookup_table()
    bm.normal_update()
    stands = {}

    for v in bm.verts:
        around = [e.other_vert(v).co for e in v.link_edges]
        stands[v] = (v.co - sum(around, Vector()) / max(len(around), 1)).dot(v.normal) if around else 0.0

    for _ in range(2):
        stands = {v: (stands[v] + sum(stands[e.other_vert(v)] for e in v.link_edges) / max(len(v.link_edges), 1)) * 0.5 for v in bm.verts}

    # (The teeth came in with colours of their own.)
    for old in list(bm.loops.layers.color.values()):
        bm.loops.layers.color.remove(old)

    for old in list(bm.loops.layers.float_color.values()):
        bm.loops.layers.float_color.remove(old)

    layer = bm.loops.layers.color.new("Color")

    for f in bm.faces:
        kind = marks.get(f, "")
        f.smooth = kind == ""
        stony = False

        for loop in f.loops:
            v = loop.vert
            c = v.co
            alpha = 0.0

            if kind == "tin":
                tone = mix(TIN, SILT, smooth(0.45, 0.75, noise.noise(c * 40.0) * 0.5 + 0.5))
            elif kind == "iron":
                tone = IRON
            elif kind == "tooth":
                tone = mix((0.5, 0.42, 0.25), SILT, smooth(-0.1, 0.3, noise.noise(c * 60.0)) * 0.6)
            elif kind == "gullet":
                tone = (0.04, 0.012, 0.012)
            elif kind == "eye":
                tone = (0.9, 1.0, 0.8)
                alpha = 1.0
            elif kind in ("hair", "root", "rag"):
                t = loop[bm.loops.layers.uv["UVMap"]].uv.x
                if kind == "hair":
                    tone = mix(HAIR, HAIR_TIP, smooth(0.5, 1.0, t))
                elif kind == "root":
                    tone = mix(ROOT, ROOT_TIP, smooth(0.3, 1.0, t))
                else:
                    tone = mix(WOOL, WOOL_LIT, smooth(0.0, 0.3, noise.noise(c * 40.0)))
            else:
                row = lookup(c)
                face = row.get("head", 0.0) + row.get("jaw", 0.0)
                tone = mix(PALE, PALE_COLD, smooth(-0.3, 0.45, noise.noise(c * 2.6)))
                tone = mix(tone, BRUISE, smooth(0.12, 0.42, noise.noise(c * 5.1 + Vector((9.0, 0.0, 0.0)))) * 0.5)
                # Veins, dark under the stretched skin.
                vein = 1.0 - abs(noise.noise(c * Vector((6.0, 6.0, 3.0)) + Vector((0.0, 4.0, 0.0)))) * 11.0
                tone = mix(tone, BRUISE, max(vein, 0.0) * 0.5)
                tone = mix(tone, ROT, smooth(0.2, 0.45, noise.noise(c * 3.7 + Vector((0.0, 0.0, 5.0)))) * 0.6)
                # Dead, dark round the mouth and eyes; what's left of its face is the colour of the water.
                tone = mix(tone, mix((0.17, 0.2, 0.18), (0.2, 0.15, 0.1), smooth(-0.2, 0.3, noise.noise(c * 6.0))), face * 0.85)
                tone = mix(tone, SILT, face * smooth(0.0, -0.004, stands[v]))
                # The lake's mud, dried up its legs and arms: nothing of it is clean.
                hands = sum(w for n, w in row.items() if n.startswith("hand") or "finger" in n or "thumb" in n)
                mud = max(smooth(0.95, 0.1, c.z + noise.noise(c * 4.0) * 0.28), hands * 0.8, sum(w for n, w in row.items() if n.startswith("arm_2")) * smooth(1.25, 0.8, c.z + noise.noise(c * 5.0) * 0.2))
                tone = mix(tone, mix((0.1, 0.09, 0.07), (0.05, 0.05, 0.05), smooth(-0.2, 0.3, noise.noise(c * 14.0))), mud * (0.55 + 0.35 * smooth(-0.3, 0.3, noise.noise(c * 9.0 + Vector((5.0, 0.0, 0.0))))))
                rag = cloth_of(row, c)
                tone = mix(tone, mix(WOOL, WOOL_LIT, smooth(0.0, 0.3, noise.noise(c * 55.0))), rag)
                # Silt in what sinks; the skin palest where it stands stretched.
                tone = mix(tone, SILT, smooth(-0.001, -0.006, stands[v]))
                tone = mix(tone, (0.5, 0.49, 0.42), smooth(0.0012, 0.006, stands[v]) * (1.0 - rag) * (1.0 - face * 0.7) * 0.7)

                for tip, way in nails:
                    if (c - tip).length < 0.12:
                        tone = mix(tone, (0.03, 0.025, 0.02), smooth(-0.025, 0.0, (c - tip).dot(way)))
                grown = crust_of(c, crust_at)
                # Round what's nailed to it, the skin has gone black and split: what holds it down, and what comes up round that.
                near_nail = max((smooth(0.075, 0.02, (c - at).length) for at in nailed if abs(c.z - at.z) < 0.09), default=0.0)
                tone = mix(tone, SILT, near_nail * 0.8)
                split = split_at(c, v.normal.y, row, split_top, split_bottom)
                tone = mix(tone, (0.015, 0.012, 0.012), smooth(0.45, 0.8, split))
                # How much seep lies under the skin here: most in the split, then round the nails and the crust's edge, and a little all over.
                alpha = 0.04 + smooth(0.0, 0.5, split) * 0.3 + smooth(0.45, 0.98, split) * 0.5 + near_nail * 0.3 + smooth(0.0, 0.25, grown) * (1.0 - smooth(0.25, 0.7, grown)) * 0.3
                alpha = min(alpha, 0.84) * (1.0 - face)

                if grown > 0.0:
                    rock = mix(TEZONTLE, (0.27, 0.25, 0.2), smooth(0.0, 0.3, noise.noise(c * 9.0)))
                    rock = mix(rock, (0.03, 0.02, 0.02), smooth(-0.0005, -0.006, stands[v]))
                    rock = mix(rock, (0.44, 0.34, 0.28), smooth(0.003, 0.012, stands[v]) * 0.6)
                    tone = mix(tone, rock, grown)
                    stony = stony or grown > 0.6

            loop[layer] = paint_value(tone, alpha)

        if stony:
            f.smooth = False

    return layer


def rig_it(joints, hinge, sockets):
    data = bpy.data.armatures.new("Revenant")
    rig = bpy.data.objects.new("RevenantRig", data)
    bpy.context.collection.objects.link(rig)
    bpy.context.view_layer.objects.active = rig
    rig.select_set(True)
    bpy.ops.object.mode_set(mode="EDIT")
    made = {}

    def bone(name, head, tail, parent=None):
        b = data.edit_bones.new(name)
        b.head = head
        b.tail = tail if (tail - head).length > 0.01 else head + Vector((0.0, 0.05, 0.0))
        b.use_connect = False

        if parent:
            b.parent = made[parent]

        made[name] = b

    hips = joints["hips"]
    bone("root", Vector((hips.x, hips.y, 0.0)), Vector((hips.x, hips.y, 0.3)))
    bone("hips", hips, joints["spine"], "root")
    bone("spine", joints["spine"], joints["chest"], "hips")
    bone("chest", joints["chest"], joints["chest_end"], "spine")
    neck_mid = joints["neck_1"].lerp(joints["neck_end"], 0.5)
    bone("neck_1", joints["neck_1"], neck_mid, "chest")
    bone("neck_2", neck_mid, joints["neck_end"], "neck_1")
    bone("head", joints["neck_end"], joints["neck_end"] + Vector((0.0, 0.2, 0.2)), "neck_2")
    bone("jaw", hinge, hinge + Vector((0.0, 0.2, -0.08)), "head")
    bone("eye_l", sockets[0], sockets[0] + Vector((0.0, 0.06, 0.0)), "head")
    bone("eye_r", sockets[1], sockets[1] + Vector((0.0, 0.06, 0.0)), "head")

    for side in ("_l", "_r"):
        bone("clavicle" + side, joints["clavicle" + side], joints["clavicle_end" + side], "chest")
        bone("arm_1" + side, joints["arm_1" + side], joints["arm_1_end" + side], "clavicle" + side)
        bone("arm_2" + side, joints["arm_2" + side], joints["arm_2_end" + side], "arm_1" + side)
        bone("hand" + side, joints["hand" + side], joints["hand_end" + side], "arm_2" + side)
        bone("leg_1" + side, joints["leg_1" + side], joints["leg_1_end" + side], "hips")
        bone("leg_2" + side, joints["leg_2" + side], joints["leg_2_end" + side], "leg_1" + side)
        bone("foot" + side, joints["foot" + side], joints["foot_end" + side], "leg_2" + side)

        for name in FINGER_NAMES.values():
            bone(name + side, joints[name + side], joints[name + "_b" + side], "hand" + side)
            bone(name + "_b" + side, joints[name + "_b" + side], joints[name + "_tip" + side], name + side)

    bpy.ops.object.mode_set(mode="OBJECT")
    rig.select_set(False)
    return rig


def skin_it(obj, rig, lookup, attach_points):
    """Each vertex takes its nearest flesh's weights, softened, its four most. What is nailed on goes with what it's nailed to."""
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    bm.verts.ensure_lookup_table()
    attach = bm.verts.layers.int.get("Attach")
    rows = [lookup(attach_points[v[attach] - 1]) if v[attach] > 0 else lookup(v.co) for v in bm.verts]

    # (Once: more and its joints go to rubber.)
    for _ in range(1):
        soft = []

        for v in bm.verts:
            around = [rows[e.other_vert(v).index] for e in v.link_edges]
            row = dict(rows[v.index])

            for other in around:
                for name, weight in other.items():
                    row[name] = row.get(name, 0.0) + weight / max(len(around), 1)

            soft.append(row)

        rows = soft

    # Across the lips, and through what's rigid: head and jaw stay their own, or its mouth drags.
    bm.free()
    groups = {}

    for i, row in enumerate(rows):
        top = sorted(row.items(), key=lambda pair: -pair[1])[:4]
        total = sum(w for _n, w in top) or 1.0

        for name, weight in top:
            if weight / total < 0.01:
                continue

            group = groups.get(name) or obj.vertex_groups.new(name=name)
            groups[name] = group
            group.add([i], weight / total, "REPLACE")

    obj.parent = rig
    modifier = obj.modifiers.new("Armature", "ARMATURE")
    modifier.object = rig


def pictures(obj):
    os.makedirs(PICTURES, exist_ok=True)
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_WORKBENCH"
    scene.display.shading.light = "STUDIO"
    scene.display.shading.color_type = "VERTEX"
    scene.display.shading.show_cavity = True
    scene.display.shading.show_shadows = True
    scene.render.resolution_x = 800
    scene.render.resolution_y = 900
    camera_data = bpy.data.cameras.new("Look")
    camera_data.lens = 45
    camera = bpy.data.objects.new("Look", camera_data)
    bpy.context.collection.objects.link(camera)
    scene.camera = camera
    world = bpy.data.worlds.new("Dark")
    scene.world = world
    world.color = (0.05, 0.05, 0.055)
    middle = Vector((0.0, 0.25, 1.25))

    def shot(name, at, look_at=middle):
        camera.location = at
        camera.rotation_euler = (look_at - at).to_track_quat("-Z", "Y").to_euler()
        scene.render.filepath = os.path.join(PICTURES, name + ".png")
        bpy.ops.render.render(write_still=True)

    shot("a_front", Vector((0.0, 5.2, 1.5)))
    shot("b_quarter", Vector((3.4, 3.9, 1.6)))
    shot("c_side", Vector((5.2, 0.25, 1.4)))
    shot("d_back", Vector((-2.2, -4.4, 1.9)))
    shot("e_head", Vector((0.7, 2.2, 2.2)), Vector((0.0, 0.9, 2.0)))
    shot("f_shoulder", Vector((-2.2, 1.6, 2.2)), Vector((-0.7, 0.4, 1.8)))
    shot("g_hand", Vector((0.5, 1.8, 0.5)), Vector((0.1, 0.8, 0.45)))


def main():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    rng = random.Random(11)
    body, weights, joints = stance()
    weights = without_head(body, weights)
    skull, jaw, skull_teeth, jaw_teeth, gullet, tongue, hinge, sockets = head_on(joints)
    # What the final skin looks up its weights from: the body, the skull, the jaw.
    source = joined([body, skull, jaw])
    rows = list(weights) + [{"head": 1.0}] * len(skull.vertices) + [{"jaw": 1.0}] * len(jaw.vertices)
    lookup = weigh_by(source, rows)
    # Its neck runs into the head by its two bones.
    neck_1, neck_end = joints["neck_1"], joints["neck_end"]
    length = (neck_end - neck_1).length

    def looked_up(point):
        row = lookup(point)

        if row.get("neck_1", 0.0) > 0.0:
            t = smooth(0.35, 0.65, (point - neck_1).dot((neck_end - neck_1).normalized()) / length)
            row["neck_2"] = row["neck_1"] * t
            row["neck_1"] *= 1.0 - t

        return row

    def cloth_of(row, c):
        """A coat, open over the belly and gone to the elbow; trousers, torn off below the knee."""
        edge = noise.noise(c * 7.0) * 0.1 + noise.noise(c * 26.0) * 0.035
        sleeve = (row.get("arm_1_l", 0.0) + row.get("arm_1_r", 0.0))
        trunk = row.get("chest", 0.0) + row.get("spine", 0.0) + row.get("clavicle_l", 0.0) + row.get("clavicle_r", 0.0)
        # (Open down the front, where the belly has burst it.)
        open_front = smooth(0.12, 0.26, abs(c.x) + edge) if c.y > joints["chest"].y else 1.0
        coat = smooth(0.42, 0.5, trunk + sleeve * 0.9 + edge) * open_front * (1.0 - smooth(0.0, 0.2, c.z - joints["clavicle_l"].z - 0.16))
        calf = row.get("leg_2_l", 0.0) + row.get("leg_2_r", 0.0)
        legs = row.get("hips", 0.0) + row.get("leg_1_l", 0.0) + row.get("leg_1_r", 0.0) + calf * smooth(joints["leg_2_l"].z - 0.42, joints["leg_2_l"].z - 0.34, c.z + edge)
        return max(coat, smooth(0.45, 0.55, legs + edge))

    shoulder = joints["arm_1_l"]
    crust_at = [(shoulder + Vector((0.0, -0.05, 0.05)), 0.34), (joints["chest_end"] + Vector((-0.26, -0.3, 0.12)), 0.42), (shoulder.lerp(joints["arm_2_l"], 0.3), 0.2)]
    # (Sealed where the head was, and at the base's own seams: a voxel remesh needs an inside.)
    whole = joined([body])
    bm = bmesh.new()
    bm.from_mesh(whole)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=0.0002)
    bmesh.ops.holes_fill(bm, edges=[e for e in bm.edges if e.is_boundary], sides=0)
    bm.to_mesh(whole)
    print("TRUNK OPEN", sum(1 for e in bm.edges if not e.is_manifold))
    bm.free()
    trunk = bpy.data.objects.new("Revenant", whole)
    bpy.context.collection.objects.link(trunk)
    remesh(trunk, VOXEL_FIRST)
    sculpt(trunk, looked_up, sacks_of(joints))
    nails = nails_on(joints)
    nail_tree = [(joints[name + "_tip" + side], (joints[name + "_tip" + side] - joints[name + "_b" + side]).normalized()) for side in ("_l", "_r") for name in FINGER_NAMES.values()]
    obj = bpy.data.objects.new("RevenantAll", joined([trunk.data, skull, jaw] + nails))
    bpy.context.collection.objects.link(obj)
    bpy.data.objects.remove(trunk)
    obj.name = "Revenant"
    remesh(obj, VOXEL_LAST)
    apply(obj, "SMOOTH", factor=0.5, iterations=1)
    split_top = joints["chest_end"].z - 0.02
    split_bottom = joints["spine"].z - 0.3
    stone_and_cloth(obj, looked_up, crust_at, cloth_of, hinge, split_top, split_bottom)
    closed_and_cut(obj)
    bm, marks = nail_them_on(obj, looked_up, rng)
    bm.loops.layers.uv.new("UVMap")
    # Its own teeth, what hangs in its mouth, and its eyes, far back in their sockets.
    for kind, parts in (("tooth", skull_teeth + jaw_teeth), ("gullet", tongue)):
        for part in parts:
            before = set(bm.faces)
            bm.from_mesh(part)

            for f in bm.faces:
                if f not in before:
                    marks[f] = kind

    in_their_sockets(bm, sockets, Matrix.Rotation(HEAD_TILT, 3, "X") @ Vector((0.0, 1.0, 0.0)))

    for socket in sockets:
        made = bmesh.ops.create_icosphere(bm, subdivisions=2, radius=0.021)

        for v in made["verts"]:
            v.co += socket

        for f in {f for v in made["verts"] for f in v.link_faces}:
            marks[f] = "eye"

    bmesh.ops.remove_doubles(bm, verts=list({v for f, k in marks.items() if k in ("tooth", "gullet") for v in f.verts}), dist=0.00002)
    marks = {f: k for f, k in marks.items() if f.is_valid}
    bm.faces.ensure_lookup_table()
    tree = BVHTree.FromBMesh(bm)
    nailed = [sum((v.co for v in f.verts), Vector()) / len(f.verts) for f, k in marks.items() if k == "iron"]
    attach_points = strands_on(bm, tree, marks, looked_up, cloth_of, crust_at, sockets, rng)
    paint(bm, marks, looked_up, crust_at, cloth_of, nail_tree, nailed[::6], split_top, split_bottom)
    bad = sum(1 for e in bm.edges if not e.is_manifold)
    print("OPEN EDGES", bad)

    if bad:
        raise RuntimeError("the revenant has %d open edges" % bad)

    bm.to_mesh(obj.data)
    bm.free()
    obj.data.color_attributes.active_color_index = 0
    obj.data.color_attributes.render_color_index = 0
    print("STANDS", round(max(v.co.z for v in obj.data.vertices), 3), "WIDE", round(max(v.co.x for v in obj.data.vertices) - min(v.co.x for v in obj.data.vertices), 3), "TRIS", sum(len(p.vertices) - 2 for p in obj.data.polygons))
    rig = rig_it(joints, hinge, sockets)
    skin_it(obj, rig, looked_up, attach_points)

    if "Attach" in obj.data.attributes:
        obj.data.attributes.remove(obj.data.attributes["Attach"])

    obj.select_set(True)
    rig.select_set(True)
    bpy.context.view_layer.objects.active = rig

    if PICTURES:
        pictures(obj)

    bpy.ops.export_scene.gltf(filepath=OUT, export_format="GLB", export_yup=True, use_selection=True, export_materials="NONE", export_normals=True, export_apply=False, export_animations=False, export_skins=True, export_vertex_color="ACTIVE", export_all_vertex_colors=False)
    print("WROTE", OUT)


main()
