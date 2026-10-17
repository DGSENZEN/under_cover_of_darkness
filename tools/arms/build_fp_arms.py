"""The Prosecutor's first-person arms, piece 1: the blockout.

Shoulders to fingertips, no body: an armature with the bones the game's arm
solver uses (scripts/Visual/ArmReach.gd), a real arm's proportions, the hands
(the CC0 base hand from tools/arms/extract_base_hand.py, aged, its joints the
rig's, weighted joint by joint), big simple forms for the trench sleeve with a
shoulder cap and the shirt cuff, two rings, flat colours, and three poses.
Saves assets/characters/fp_arms/source/fp_arms_blockout.blend and exports
assets/characters/fp_arms/fp_arms.glb.

    /Applications/Blender.app/Contents/MacOS/Blender --background --factory-startup \\
        --python tools/arms/build_fp_arms.py -- <repo root>

Blender's axes: +Y forward (the game's -Z), +Z up. Left is -X.
Spec: docs/superpowers/specs/2026-10-16-prosecutor-fp-arms-design.md.
"""

import json
import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

import sleeve_form  # noqa: E402
SOURCE = os.path.join(HERE, "..", "..", "assets", "characters", "fp_arms", "source")
BASE_HAND = os.path.join(SOURCE, "base_hand.blend")
with open(os.path.join(SOURCE, "base_hand_joints.json")) as _f:
    # A right hand's joints, wrist at the origin, fingers along +Y, palm down.
    HAND_JOINTS = json.load(_f)

# Metres, full size. Shoulder to wrist 0.65 (a real arm's length).
SPEC = {
    "upper": 0.34,
    "fore": 0.31,
    "hand": 0.09,
    # Wrist to the middle fingertip: an adult man's hand.
    "hand_length": 0.194,
    "shoulder_width": 0.38,
    "shoulder_height": 1.45,
    # The hand itself, its knuckles and finger joints come from the base hand
    # (tools/arms/extract_base_hand.py): HAND_JOINTS.
    # Joint curls (degrees, toward the pad), per pose: fingers 01/02/03, and
    # the thumb's three joints as (curl, twist, swing): a fist's thumb turns
    # on its root to lie across the index and middle fingers. Thumbs found by
    # tools/arms/check_fp_arms_bends.py: resting on the index, never in it.
    "poses": {
        "Open": ((0.0, 0.0, 0.0), ((0.0, 0.0, 0.0), (0.0, 0.0, 0.0), (0.0, 0.0, 0.0))),
        "Fist": ((85.0, 95.0, 70.0), ((15.0, -40.0, 0.0), (15.0, 0.0, 0.0), (25.0, 0.0, 0.0))),
        "Hook": ((50.0, 70.0, 40.0), ((10.0, 0.0, 0.0), (20.0, 0.0, 0.0), (15.0, 0.0, 0.0))),
        # Round a 4 cm pipe, rung or rope: the thumb comes over to meet the
        # fingers.
        "Wrap": ((55.0, 80.0, 50.0), ((15.0, -55.0, 0.0), (25.0, 0.0, 0.0), (10.0, 0.0, 0.0))),
        # Pressing down on a top to climb on: palm flat, fingers spread a
        # little back, the thumb out to the side.
        "Push": ((-8.0, 5.0, 5.0), ((-10.0, 15.0, 0.0), (0.0, 0.0, 0.0), (5.0, 0.0, 0.0))),
        # Round a sword's grip: a fist, the index a little looser along it.
        "SwordGrip": ((80.0, 90.0, 60.0), ((15.0, -40.0, 0.0), (15.0, 0.0, 0.0), (25.0, 0.0, 0.0))),
    },
    # Fingers a pose sets apart from the rest (degrees, 01/02/03).
    "pose_fingers": {
        "SwordGrip": {"index": (65.0, 75.0, 50.0)},
        # (The index a little less closed at its knuckle: its tip rests on
        # the thumb's root instead of sinking into it.)
        "Fist": {"index": (75.0, 95.0, 70.0)},
    },
    "sleeve_short_of_wrist": 0.04,
    "cuff_length": 0.025,
    "rings": (("middle", "l"), ("ring", "l")),
}

FINGERS = ("index", "middle", "ring", "pinky", "thumb")
SIDES = (("l", -1.0), ("r", 1.0))


def bone_names():
    """Every bone the rig has: root, the four arm bones and fifteen finger
    joints per side."""
    names = ["root"]

    for side, _ in SIDES:
        names += ["%s_%s" % (bone, side) for bone in ("clavicle", "upperarm", "lowerarm", "hand")]
        names += ["%s_%s_%s" % (finger, joint, side) for finger in FINGERS for joint in ("01", "02", "03")]

    return names


def _norm(v):
    length = math.sqrt(sum(c * c for c in v))
    return tuple(c / length for c in v)


def _add(a, b, scale=1.0):
    return tuple(a[i] + b[i] * scale for i in range(3))


def joints(sign):
    """World points (Blender axes) of one arm's chain, sign -1 left, 1 right:
    shoulder, elbow, wrist, knuckles and each finger's joints (the base
    hand's, mirrored for the left)."""
    shoulder = (sign * SPEC["shoulder_width"] * 0.5, 0.0, SPEC["shoulder_height"])
    elbow = _add(shoulder, _norm((0.0, 0.88, -0.47)), SPEC["upper"])
    wrist = _add(elbow, _norm((0.0, 1.0, 0.05)), SPEC["fore"])

    def at(p):
        return _add(wrist, (sign * p[0], p[1], p[2]))

    fingers = {finger: [at(p) for p in points] for finger, points in HAND_JOINTS["fingers"].items()}
    return {"shoulder": shoulder, "elbow": elbow, "wrist": wrist, "knuckles": at(HAND_JOINTS["knuckles"]), "fingers": fingers}


def _sub(a, b):
    return tuple(a[i] - b[i] for i in range(3))


def _dot(a, b):
    return sum(a[i] * b[i] for i in range(3))


def _smooth(edge0, edge1, x):
    t = min(max((x - edge0) / (edge1 - edge0), 0.0), 1.0)
    return t * t * (3.0 - 2.0 * t)


# How far each bend spreads either side of its joint (m): the wrist, a
# knuckle, the finger joints.
WRIST_BLEND = 0.015
KNUCKLE_BLEND = 0.010
JOINT_BLEND = 0.006


def hand_weights(co, finger, normal=None):
    """Skin weights of a base-hand vertex (right hand, local space) owned by
    finger (0 the palm and wrist, 1-5 index to thumb): {bone without side:
    weight}. Rigid along each bone, blended smoothly across each joint; palm
    skin near a knuckle or over the thumb's root shares its finger's first
    bone, never a neighbour's."""
    joints = HAND_JOINTS["fingers"]

    def into(name):
        """How far into each of the chain's three joints the vertex lies. The
        back of a finger stretches round a bend (a wide blend), its pad folds
        sharp (narrow): normal says which side the vertex is on."""
        points = joints[name]
        d = [_norm(_sub(points[k + 1], points[k])) for k in range(3)]
        normals = (d[0], _norm(_add(d[0], d[1])), _norm(_add(d[1], d[2])))
        back = 0.5 if normal is None else _smooth(-0.5, 0.5, _dot(normal, HAND_JOINTS["nails"][name]))
        widen = 0.6 + 0.9 * back
        blends = (KNUCKLE_BLEND * widen, JOINT_BLEND * widen, JOINT_BLEND * widen)
        return [_smooth(-blends[k], blends[k], _dot(_sub(co, points[k]), normals[k])) for k in range(3)]

    share = {}

    if finger:
        name = FINGERS[finger - 1]
        share[name] = into(name)[0]
    else:
        for name in FINGERS:
            points = joints[name]
            d0 = _norm(_sub(points[1], points[0]))
            t = _dot(_sub(co, points[0]), d0)

            if name == "thumb":
                # The thumb's root bone lies in the palm's ball: skin near it.
                along = _add(points[0], d0, min(max(t, 0.0), _dot(_sub(points[1], points[0]), d0)))
                reach = math.sqrt(_dot(_sub(co, along), _sub(co, along)))
                near = 1.0 - _smooth(0.012, 0.025, reach)
            else:
                # Across the hand only: the knuckle's skin above and below.
                near = 1.0 - _smooth(0.006, 0.016, abs(co[0] - _add(points[0], d0, t)[0]))

            if near > 0.0:
                share[name] = near * into(name)[0]

        total = sum(share.values())

        if total > 1.0:
            share = {k: v / total for k, v in share.items()}

    weights = {"hand": 1.0 - sum(share.values())}

    for name, s in share.items():
        a = into(name)
        weights[name + "_01"] = s * (1.0 - a[1])
        weights[name + "_02"] = s * a[1] * (1.0 - a[2])
        weights[name + "_03"] = s * a[1] * a[2]

    # The stump under the cuff follows the forearm.
    hand_in = _smooth(-WRIST_BLEND, WRIST_BLEND, co[1])
    weights = {k: v * hand_in for k, v in weights.items() if v * hand_in > 0.0}

    if hand_in < 1.0:
        weights["lowerarm"] = 1.0 - hand_in

    return weights


def _bump(distance, sigma):
    """A soft round rise, nothing past three widths."""
    return math.exp(-(distance / sigma) ** 2) if distance < 3.0 * sigma else 0.0


def _along(co, a, b):
    """(how far along a->b as 0..1, distance from the line) for a point."""
    ab = _sub(b, a)
    t = _dot(_sub(co, a), ab) / _dot(ab, ab)
    off = _sub(co, _add(a, ab, t))
    return t, math.sqrt(_dot(off, off))


# An older man's hand (m): knuckle heads, extensor tendons, knobbed finger
# joints. Sized to read at the mesh's density; veins, creases and scars are
# painted and baked (pieces 2 and 5).
KNUCKLE_RISE, KNUCKLE_WIDTH = 0.0022, 0.008
TENDON_RISE, TENDON_WIDTH = 0.0012, 0.0035
KNOB_RISE, KNOB_WIDTH = (0.0009, 0.0006), 0.004


def age_offset(co, normal, finger=None):
    """How far an older man's hand moves a base-hand vertex (right hand,
    local space), along its normal: knuckle heads and tendons on the back of
    the hand, knobs at each finger joint. finger (0-5, as hand_weights)
    keeps the knobs to the vertex's own finger; None means any."""
    joints = HAND_JOINTS["fingers"]
    back = _smooth(0.2, 0.6, normal[2])
    rise = 0.0

    for f, name in enumerate(FINGERS):
        points = joints[name]

        if name != "thumb" and back > 0.0:
            # The metacarpal's head, under the skin over the knuckle.
            head = _add(points[0], (0.0, 0.0, 0.008))
            gap = _sub(co, head)
            rise += back * KNUCKLE_RISE * _bump(math.sqrt(_dot(gap, gap)), KNUCKLE_WIDTH)
            # Its tendon, from the middle of the wrist to the knuckle.
            flat = (co[0], co[1], 0.0)
            t, lateral = _along(flat, (points[0][0] * 0.3, 0.012, 0.0), (points[0][0], points[0][1], 0.0))
            rise += back * TENDON_RISE * _bump(lateral, TENDON_WIDTH) * _smooth(0.0, 0.25, t) * (1.0 - _smooth(0.85, 1.05, t))

        if finger is None or finger == f + 1:
            for k, height in ((1, KNOB_RISE[0]), (2, KNOB_RISE[1])):
                d = _norm(_sub(points[k + 1], points[k - 1]))
                axial = _dot(_sub(co, points[k]), d)
                t, reach = _along(co, points[k - 1], points[k + 1])
                rise += (0.4 + 0.6 * back) * height * _bump(abs(axial), KNOB_WIDTH) * (1.0 - _smooth(0.010, 0.013, reach))

    # Nothing under the cuff.
    rise *= _smooth(0.0, 0.02, co[1])
    return tuple(n * rise for n in normal)


def build(root_dir):
    import bpy
    import bmesh
    from mathutils import Euler, Matrix, Quaternion, Vector

    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene

    # --- Armature
    arm_data = bpy.data.armatures.new("FPArms")
    rig = bpy.data.objects.new("FPArms", arm_data)
    scene.collection.objects.link(rig)
    bpy.context.view_layer.objects.active = rig
    bpy.ops.object.mode_set(mode="EDIT")
    edit = arm_data.edit_bones

    def bone(name, head, tail, parent=None, connect=False):
        b = edit.new(name)
        b.head = Vector(head)
        b.tail = Vector(tail)
        b.roll = 0.0

        if parent is not None:
            b.parent = edit[parent]
            b.use_connect = connect

        return b

    bone("root", (0.0, 0.0, SPEC["shoulder_height"] - 0.15), (0.0, 0.0, SPEC["shoulder_height"]))

    for side, sign in SIDES:
        j = joints(sign)
        bone("clavicle_" + side, (sign * 0.03, 0.0, SPEC["shoulder_height"]), j["shoulder"], "root")
        # The arm's bones turn as the old body's do (the game's holds and held
        # items are set for them): the palm on local -X for the right hand,
        # +X for the left.
        bone("upperarm_" + side, j["shoulder"], j["elbow"], "clavicle_" + side, True).align_roll(Vector((-sign, 0.0, 0.0)))
        bone("lowerarm_" + side, j["elbow"], j["wrist"], "upperarm_" + side, True).align_roll(Vector((-sign, 0.0, 0.0)))
        bone("hand_" + side, j["wrist"], j["knuckles"], "lowerarm_" + side, True).align_roll(Vector((-sign, 0.0, 0.0)))

        for finger in FINGERS:
            points = j["fingers"][finger]
            nail = HAND_JOINTS["nails"][finger]

            for k in range(3):
                name = "%s_0%d_%s" % (finger, k + 1, side)
                parent = "hand_" + side if k == 0 else "%s_0%d_%s" % (finger, k, side)
                # Each finger's bones turn with its nail: Z up the back of the
                # finger, so a curl about X closes it toward its pad.
                bone(name, points[k], points[k + 1], parent, k > 0).align_roll(Vector((sign * nail[0], nail[1], nail[2])))

    bpy.ops.object.mode_set(mode="OBJECT")

    # --- Materials (flat colours: a blockout)
    def material(name, colour, metal=0.0, rough=0.7):
        m = bpy.data.materials.new(name)
        m.use_nodes = True
        bsdf = m.node_tree.nodes.get("Principled BSDF")
        bsdf.inputs["Base Color"].default_value = (*colour, 1.0)
        bsdf.inputs["Metallic"].default_value = metal
        bsdf.inputs["Roughness"].default_value = rough
        m.diffuse_color = (*colour, 1.0)
        m.metallic = metal
        m.roughness = rough
        return m

    mats = {
        "coat": material("Coat", (0.07, 0.12, 0.26)),
        "cuff": material("ShirtCuff", (0.80, 0.77, 0.70)),
        "skin": material("Skin", (0.62, 0.43, 0.33)),
        "ring": material("RingMetal", (0.45, 0.45, 0.48), 1.0, 0.35),
        "lining": material("Lining", (0.18, 0.07, 0.06)),
        "button": material("Button", (0.12, 0.08, 0.05), 0.0, 0.4),
    }
    mat_order = ["coat", "cuff", "skin", "ring", "lining", "button"]

    # The base hand (CC0, tools/arms/extract_base_hand.py): a right hand, wrist
    # at the origin, each vertex marked with its finger.
    with bpy.data.libraries.load(BASE_HAND) as (src, dst):
        dst.meshes = ["BaseHand"]

    base_hand = dst.meshes[0]
    base_finger = [d.value for d in base_hand.attributes["finger"].data]
    # Made his: an older man's knuckles, tendons and joints.
    aged = [age_offset(tuple(v.co), tuple(v.normal), f) for v, f in zip(base_hand.vertices, base_finger)]

    for v, offset in zip(base_hand.vertices, aged):
        v.co += Vector(offset)

    # The bundle marks its faces flat: the skin is smooth.
    if "sharp_face" in base_hand.attributes:
        base_hand.attributes.remove(base_hand.attributes["sharp_face"])

    base_hand.update()

    def finger_radius(finger, side, centre, axis):
        """The skin's furthest reach from a finger's axis around a point on it
        (both hands are the base hand, mirrored)."""
        sign = -1.0 if side == "l" else 1.0
        wrist = Vector(joints(sign)["wrist"])
        index = FINGERS.index(finger) + 1
        axis = axis.normalized()
        reach = []

        for v, f in zip(base_hand.vertices, base_finger):
            if f != index:
                continue

            p = wrist + Vector((sign * v.co.x, v.co.y, v.co.z)) - centre

            if abs(p.dot(axis)) < 0.002:
                reach.append((p - axis * p.dot(axis)).length)

        # The band presses the skin a little: snug on the skin's middle reach.
        reach.sort()
        return reach[len(reach) * 3 // 4]

    # --- Forms, built into one bmesh, each tagged with its bone and material
    bm = bmesh.new()
    deform = bm.verts.layers.deform.verify()
    groups = bone_names()

    def add_part(part):
        """A piece of the coat (sleeve_form.Part) into the mesh."""
        verts = []

        for co, weights in zip(part.verts, part.weights):
            v = bm.verts.new(Vector(co))

            for name, w in weights.items():
                v[deform][groups.index(name)] = w

            verts.append(v)

        for face, mat in zip(part.faces, part.face_mats):
            f = bm.faces.new([verts[i] for i in face])
            f.material_index = mat_order.index(mat)
            f.select = True

    def ring(centre, axis, bone_name, inner):
        """A band whose inside sits on the skin (inner: the finger's radius)."""
        rot = Vector(axis).to_track_quat("Z", "Y").to_matrix().to_4x4()
        verts = []
        minor, seg, sides = 0.0022, 24, 8
        major = inner + minor * 0.8

        for i in range(seg):
            for k in range(sides):
                u = i / seg * math.tau
                v = k / sides * math.tau
                p = Vector(((major + minor * math.cos(v)) * math.cos(u), (major + minor * math.cos(v)) * math.sin(u), minor * math.sin(v)))
                verts.append(bm.verts.new(Matrix.Translation(Vector(centre)) @ rot @ p))

        bm.verts.ensure_lookup_table()

        for i in range(seg):
            for k in range(sides):
                a = verts[i * sides + k]
                b = verts[((i + 1) % seg) * sides + k]
                c = verts[((i + 1) % seg) * sides + (k + 1) % sides]
                d = verts[i * sides + (k + 1) % sides]
                bm.faces.new((a, b, c, d))

        _tag(verts, bone_name, "ring")

    face_mats = []

    def _tag(verts, bone_name, mat):
        index = groups.index(bone_name)

        for v in verts:
            v[deform][index] = 1.0
            v.tag = True

        for f in bm.faces:
            if all(v.tag for v in f.verts) and f.material_index == 0 and not f.select:
                f.material_index = mat_order.index(mat)
                f.select = True

        for v in verts:
            v.tag = False

    # The coat's shoulders and chest (sleeve_form.yoke): the arms run into a
    # body, wherever the view finds the shoulders (looking up at a hold).
    add_part(sleeve_form.yoke())

    for side, sign in SIDES:
        j = joints(sign)
        sh, el, wr = Vector(j["shoulder"]), Vector(j["elbow"]), Vector(j["wrist"])
        # The trench sleeve: wide at the shoulder, a closed cap over it.
        # The sleeve, shoulder to cuff, its top inside the yoke and stretching
        # from it (a shoulder the solver slides toward a far hold).
        add_part(sleeve_form.sleeve(j["shoulder"], j["elbow"], j["wrist"], side))
        # The coat's turned cuff closing the sleeve, the shirt's cuff inside.
        add_part(sleeve_form.cuffs(j["shoulder"], j["elbow"], j["wrist"], side))

        for finger, ring_side in SPEC["rings"]:
            if ring_side == side:
                points = [Vector(p) for p in j["fingers"][finger]]
                centre = points[0].lerp(points[1], 0.62)
                ring(centre, points[1] - points[0], "%s_01_%s" % (finger, side), finger_radius(finger, side, centre, points[1] - points[0]))

    for f in bm.faces:
        f.select = False
        f.smooth = True

    mesh = bpy.data.meshes.new("FPArmsBody")
    bm.to_mesh(mesh)
    bm.free()
    body = bpy.data.objects.new("FPArmsBody", mesh)
    scene.collection.objects.link(body)

    for key in mat_order:
        mesh.materials.append(mats[key])

    for name in groups:
        body.vertex_groups.new(name=name)

    body.parent = rig
    modifier = body.modifiers.new("Armature", "ARMATURE")
    modifier.object = rig

    # --- The hands: the base hand placed at each wrist (mirrored for the
    # left), weighted by bone heat, each finger's skin kept to its own bones.
    hands = []

    for side, sign in SIDES:
        data = base_hand.copy()
        data.transform(Matrix.Translation(Vector(joints(sign)["wrist"])) @ Matrix.Diagonal((sign, 1.0, 1.0, 1.0)))

        if sign < 0:
            data.flip_normals()

        data.materials.clear()
        data.materials.append(mats["skin"])
        hand = bpy.data.objects.new("Hand_" + side, data)
        scene.collection.objects.link(hand)
        hands.append(hand)

    for hand, (side, _) in zip(hands, SIDES):
        finger_of = [d.value for d in hand.data.attributes["finger"].data]

        for v, local, finger in zip(hand.data.vertices, base_hand.vertices, finger_of):
            for name, weight in hand_weights(tuple(local.co), finger, tuple(local.normal)).items():
                group = hand.vertex_groups.get(name + "_" + side) or hand.vertex_groups.new(name=name + "_" + side)
                group.add([v.index], weight, "REPLACE")

        for name in ("finger", ".sculpt_face_set"):
            if name in hand.data.attributes:
                hand.data.attributes.remove(hand.data.attributes[name])

    bpy.ops.object.select_all(action="DESELECT")

    for hand in hands:
        hand.select_set(True)

    body.select_set(True)
    bpy.context.view_layer.objects.active = body
    bpy.ops.object.join()
    mesh = body.data

    # --- Poses: one-frame actions the solver reads its closed fist from.
    rig.animation_data_create()

    for pose_name, (curls, thumb) in SPEC["poses"].items():
        action = bpy.data.actions.new(pose_name)
        rig.animation_data.action = action
        bpy.context.view_layer.objects.active = rig
        bpy.ops.object.mode_set(mode="POSE")

        for pb in rig.pose.bones:
            pb.rotation_mode = "QUATERNION"
            pb.rotation_quaternion = Quaternion()

        for side, sign in SIDES:
            for finger in FINGERS:
                for k in range(3):
                    own = SPEC["pose_fingers"].get(pose_name, {}).get(finger, curls)
                    curl, twist, swing = thumb[k] if finger == "thumb" else (own[k], 0.0, 0.0)
                    pb = rig.pose.bones["%s_0%d_%s" % (finger, k + 1, side)]
                    # Toward the pad: the bones run along their own +Y with Z
                    # out of the nail, so a curl is negative about local X.
                    # The left hand's bones are mirrored: its twist and swing
                    # turn the other way.
                    pb.rotation_quaternion = Euler((-math.radians(curl), sign * math.radians(twist), sign * math.radians(swing))).to_quaternion()

        for pb in rig.pose.bones:
            pb.keyframe_insert("rotation_quaternion", frame=1)

        bpy.ops.object.mode_set(mode="OBJECT")
        track = rig.animation_data.nla_tracks.new()
        track.name = pose_name
        track.strips.new(pose_name, 1, action)
        rig.animation_data.action = None

    out_dir = os.path.join(root_dir, "assets", "characters", "fp_arms")
    os.makedirs(os.path.join(out_dir, "source"), exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(out_dir, "source", "fp_arms_blockout.blend"))
    bpy.ops.export_scene.gltf(filepath=os.path.join(out_dir, "fp_arms.glb"), export_format="GLB",
                              export_animations=True, export_skins=True, export_animation_mode="ACTIONS")
    per_material = {key: sum(1 for p in mesh.polygons if p.material_index == i) for i, key in enumerate(mat_order)}
    return {"bones": len(arm_data.bones), "verts": len(mesh.vertices), "tris": sum(len(p.vertices) - 2 for p in mesh.polygons), "faces": per_material}


if __name__ == "__main__":
    try:
        import bpy  # noqa: F401
    except ImportError:
        sys.exit("run inside Blender: see the docstring")

    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    print("FPARMS", build(argv[0] if argv else os.getcwd()))
