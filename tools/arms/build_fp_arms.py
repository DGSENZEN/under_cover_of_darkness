"""The Prosecutor's first-person arms, piece 1: the blockout.

Shoulders to fingertips, no body: an armature with the bones the game's arm
solver uses (scripts/Visual/ArmReach.gd), a real arm's proportions, and big
simple forms (trench sleeve with a shoulder cap, shirt cuff, forearm, palm,
finger segments, two rings) rigidly weighted, flat colours, and three poses.
Saves assets/characters/fp_arms/source/fp_arms_blockout.blend and exports
assets/characters/fp_arms/fp_arms.glb.

    /Applications/Blender.app/Contents/MacOS/Blender --background --factory-startup \\
        --python tools/arms/build_fp_arms.py -- <repo root>

Blender's axes: +Y forward (the game's -Z), +Z up. Left is -X.
Spec: docs/superpowers/specs/2026-10-16-prosecutor-fp-arms-design.md.
"""

import math
import os
import sys

# Metres, full size. Shoulder to wrist 0.65 (a real arm's length).
SPEC = {
    "upper": 0.34,
    "fore": 0.31,
    "hand": 0.09,
    "shoulder_width": 0.38,
    "shoulder_height": 1.45,
    "palm_width": 0.085,
    # Per finger: (offset across the palm toward the little finger, the
    # three joints' lengths).
    "fingers": {
        "index": (-0.030, (0.045, 0.027, 0.022)),
        "middle": (-0.010, (0.050, 0.030, 0.024)),
        "ring": (0.010, (0.046, 0.028, 0.022)),
        "pinky": (0.030, (0.036, 0.022, 0.019)),
    },
    "thumb": (0.040, 0.032, 0.026),
    # Joint curls (degrees, toward the palm), per pose: fingers 01/02/03, thumb.
    "poses": {
        "Open": ((0.0, 0.0, 0.0), 0.0),
        "Fist": ((85.0, 95.0, 70.0), 45.0),
        "Hook": ((50.0, 70.0, 40.0), 15.0),
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
    shoulder, elbow, wrist, knuckles and each finger's joints."""
    shoulder = (sign * SPEC["shoulder_width"] * 0.5, 0.0, SPEC["shoulder_height"])
    elbow = _add(shoulder, _norm((0.0, 0.88, -0.47)), SPEC["upper"])
    wrist = _add(elbow, _norm((0.0, 1.0, 0.05)), SPEC["fore"])
    knuckles = _add(wrist, (0.0, 1.0, 0.0), SPEC["hand"])
    inward = -sign
    fingers = {}

    for finger, (across, lengths) in SPEC["fingers"].items():
        base = _add(knuckles, (inward * -across, 0.0, 0.0))
        points = [base]
        direction = _norm((0.0, 1.0, -0.08))

        for length in lengths:
            points.append(_add(points[-1], direction, length))

        fingers[finger] = points

    thumb_base = _add(wrist, (inward * 0.025, 0.028, -0.012))
    # Along the side of the palm, a little in and down: at rest it lies by
    # the index finger, not hanging.
    thumb_dir = _norm((inward * 0.45, 0.85, -0.18))
    thumb = [thumb_base]

    for length in SPEC["thumb"]:
        thumb.append(_add(thumb[-1], thumb_dir, length))

    fingers["thumb"] = thumb
    return {"shoulder": shoulder, "elbow": elbow, "wrist": wrist, "knuckles": knuckles, "fingers": fingers}


def build(root_dir):
    import bpy
    import bmesh
    from mathutils import Matrix, Quaternion, Vector

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
        bone("upperarm_" + side, j["shoulder"], j["elbow"], "clavicle_" + side, True)
        bone("lowerarm_" + side, j["elbow"], j["wrist"], "upperarm_" + side, True)
        bone("hand_" + side, j["wrist"], j["knuckles"], "lowerarm_" + side, True)

        for finger in FINGERS:
            points = j["fingers"][finger]

            for k in range(3):
                name = "%s_0%d_%s" % (finger, k + 1, side)
                parent = "hand_" + side if k == 0 else "%s_0%d_%s" % (finger, k, side)
                bone(name, points[k], points[k + 1], parent, k > 0)

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
    }
    mat_order = ["coat", "cuff", "skin", "ring"]

    # --- Forms, built into one bmesh, each tagged with its bone and material
    bm = bmesh.new()
    deform = bm.verts.layers.deform.verify()
    groups = bone_names()

    def tube(a, b, r0, r1, bone_name, mat, segments=16, cap=True):
        """A tapered, capped tube from a to b."""
        a = Vector(a)
        b = Vector(b)
        axis = (b - a)
        length = axis.length
        rot = axis.to_track_quat("Z", "Y").to_matrix().to_4x4()
        result = bmesh.ops.create_cone(bm, cap_ends=cap, cap_tris=False, segments=segments,
                                       radius1=r0, radius2=r1, depth=length,
                                       matrix=Matrix.Translation((a + b) * 0.5) @ rot)
        _tag(result["verts"], bone_name, mat)

    def ball(centre, radius, bone_name, mat, segments=16):
        result = bmesh.ops.create_uvsphere(bm, u_segments=segments, v_segments=10, radius=radius,
                                          matrix=Matrix.Translation(Vector(centre)))
        _tag(result["verts"], bone_name, mat)

    def box(centre, size, along, bone_name, mat):
        rot = Vector(along).to_track_quat("Y", "Z").to_matrix().to_4x4()
        result = bmesh.ops.create_cube(bm, size=1.0, matrix=Matrix.Translation(Vector(centre)) @ rot @ Matrix.Diagonal((*size, 1.0)))
        _tag(result["verts"], bone_name, mat)

    def ring(centre, axis, bone_name):
        rot = Vector(axis).to_track_quat("Z", "Y").to_matrix().to_4x4()
        verts = []
        major, minor, seg, sides = 0.0115, 0.0022, 20, 6

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

    for side, sign in SIDES:
        j = joints(sign)
        sh, el, wr = Vector(j["shoulder"]), Vector(j["elbow"]), Vector(j["wrist"])
        fore_dir = (wr - el).normalized()
        sleeve_end = wr - fore_dir * SPEC["sleeve_short_of_wrist"]
        # The trench sleeve: wide at the shoulder, a closed cap over it.
        ball(sh, 0.085, "upperarm_" + side, "coat")
        tube(sh, el, 0.080, 0.064, "upperarm_" + side, "coat")
        ball(el, 0.064, "lowerarm_" + side, "coat")
        tube(el, sleeve_end - fore_dir * 0.05, 0.063, 0.058, "lowerarm_" + side, "coat")
        # The turned-back cuff of the coat: a little wider band.
        tube(sleeve_end - fore_dir * 0.05, sleeve_end, 0.064, 0.064, "lowerarm_" + side, "coat")
        # The shirt cuff showing past it, then the wrist.
        tube(sleeve_end, sleeve_end + fore_dir * SPEC["cuff_length"], 0.047, 0.046, "lowerarm_" + side, "cuff")
        tube(sleeve_end - fore_dir * 0.02, wr, 0.034, 0.030, "lowerarm_" + side, "skin", 12)
        # The palm and the back of the hand.
        knuckles = Vector(j["knuckles"])
        box((wr + knuckles) * 0.5, (SPEC["palm_width"], SPEC["hand"] + 0.01, 0.028), knuckles - wr, "hand_" + side, "skin")

        for finger in FINGERS:
            points = [Vector(p) for p in j["fingers"][finger]]
            radius = 0.011 if finger == "thumb" else (0.0085 if finger == "pinky" else 0.0095)

            for k in range(3):
                name = "%s_0%d_%s" % (finger, k + 1, side)
                tube(points[k], points[k + 1], radius, radius * 0.92, name, "skin", 10)
                ball(points[k + 1], radius * 0.9, name, "skin", 10)

        for finger, ring_side in SPEC["rings"]:
            if ring_side == side:
                points = [Vector(p) for p in j["fingers"][finger]]
                ring(points[0].lerp(points[1], 0.55), points[1] - points[0], "%s_01_%s" % (finger, side))

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

        for side, _ in SIDES:
            for finger in FINGERS:
                for k in range(3):
                    angle = thumb if finger == "thumb" else curls[k]
                    pb = rig.pose.bones["%s_0%d_%s" % (finger, k + 1, side)]
                    # Toward the palm: the palm faces down (-Z), the bones run
                    # along their own +Y, so a curl is negative about local X.
                    pb.rotation_quaternion = Quaternion((1.0, 0.0, 0.0), -math.radians(angle))

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
