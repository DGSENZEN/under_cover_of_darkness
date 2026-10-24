"""Do the first-person hands bend cleanly? For every pose, every finger joint
of both hands: the finger's thickness across the joint (back of the finger to
its pad, through the joint's middle) must keep at least KEEP of its thickness
at rest, as a real finger's does; and in the grips where the thumb comes round
(Wrap, SwordGrip, Fist) no thumb skin may sink into the index finger.

    /Applications/Blender.app/Contents/MacOS/Blender --background --factory-startup \\
        assets/characters/fp_arms/source/fp_arms_blockout.blend \\
        --python tools/arms/check_fp_arms_bends.py

Prints a line per joint that fails (and the worst of each pose), then
BENDS PASS or BENDS FAIL; exits 1 on a failure.
"""

import sys

import bpy
from mathutils import Vector
from mathutils.kdtree import KDTree

KEEP = 0.75
KNUCKLE_REACH = 0.007
# How near the joint's middle plane a vertex must be to count (m).
SLAB = 0.003
FINGERS = ("index", "middle", "ring", "pinky", "thumb")
THUMB_POSES = ("Wrap", "SwordGrip", "Fist")


def evaluated(body):
    graph = bpy.context.evaluated_depsgraph_get()
    mesh = body.evaluated_get(graph).to_mesh()
    points = [v.co.copy() for v in mesh.vertices]
    normals = [v.normal.copy() for v in mesh.vertices]
    body.evaluated_get(graph).to_mesh_clear()
    return points, normals


def pose(rig, name):
    rig.animation_data.action = bpy.data.actions[name] if name else None

    for track in rig.animation_data.nla_tracks:
        track.mute = True

    if not name:
        for pb in rig.pose.bones:
            pb.matrix_basis.identity()

    bpy.context.scene.frame_set(1)
    bpy.context.view_layer.update()


def joints(rig, side):
    """Per joint: (name, centre, axis across the joint, back-of-finger
    direction), posed, world space."""
    out = []

    for finger in FINGERS:
        for k in range(3):
            # (The thumb's root joint lies deep in the ball of the palm: no
            # finger's cross-section to measure there.)
            if finger == "thumb" and k == 0:
                continue

            bone = rig.pose.bones["%s_0%d_%s" % (finger, k + 1, side)]
            parent = bone.parent
            m = rig.matrix_world @ bone.matrix
            p = rig.matrix_world @ parent.matrix
            along = (m.col[1].xyz.normalized() + p.col[1].xyz.normalized()).normalized()
            out.append(("%s_%d_%s" % (finger, k, side), m.translation.copy(), along, m.col[2].xyz.normalized(), k == 0))

    return out


def owners(body):
    """Vertex -> the finger (and side) whose bones hold most of it."""
    names = {g.index: g.name for g in body.vertex_groups}
    out = {}

    for v in body.data.vertices:
        share = {}

        for g in v.groups:
            parts = names[g.group].split("_")

            if parts[0] in FINGERS and len(parts) == 3:
                key = (parts[0], parts[2])
                share[key] = share.get(key, 0.0) + g.weight

        if share:
            key = max(share, key=share.get)

            if share[key] > 0.5:
                out[v.index] = key

    return out


def thickness(points, own, finger, side, centre, along, back, knuckle=False):
    """Back of the finger to its pad through the joint. At a knuckle the
    finger's own skin has not begun (it starts at the web): there, all the
    skin over the knuckle counts, within KNUCKLE_REACH across."""
    reach_back = reach_pad = None
    across = along.cross(back).normalized()
    near = range(len(points)) if knuckle else [i for i, key in own.items() if key == (finger, side)]

    for i in near:
        d = points[i] - centre

        if abs(d.dot(along)) > SLAB:
            continue

        if knuckle and abs(d.dot(across)) > KNUCKLE_REACH:
            continue

        h = d.dot(back)
        reach_back = h if reach_back is None else max(reach_back, h)
        reach_pad = -h if reach_pad is None else max(reach_pad, -h)

    if reach_back is None:
        return None

    return reach_back + reach_pad


def main():
    rig = bpy.data.objects["FPArms"]
    body = bpy.data.objects["FPArmsBody"]
    own = owners(body)
    failed = False

    pose(rig, None)
    rest_points, _ = evaluated(body)
    rest = {}

    for side in ("l", "r"):
        for name, centre, along, back, knuckle in joints(rig, side):
            finger = name.split("_")[0]
            rest[name] = thickness(rest_points, own, finger, side, centre, along, back, knuckle)

    for pose_name in [a.name for a in bpy.data.actions]:
        pose(rig, pose_name)
        points, normals = evaluated(body)
        worst = (9.0, "")

        for side in ("l", "r"):
            for name, centre, along, back, knuckle in joints(rig, side):
                finger = name.split("_")[0]
                now = thickness(points, own, finger, side, centre, along, back, knuckle)
                then = rest[name]

                if now is None or not then:
                    print("BEND %s %s: no skin across the joint" % (pose_name, name))
                    failed = True
                    continue

                ratio = now / then
                worst = min(worst, (ratio, name))

                if ratio < KEEP:
                    print("BEND %s %s keeps %.2f (%.1f of %.1f mm)" % (pose_name, name, ratio, now * 1000, then * 1000))
                    failed = True

        print("POSE %s worst joint %s keeps %.2f" % (pose_name, worst[1], worst[0]))

        if pose_name in THUMB_POSES:
            for side in ("l", "r"):
                index = [i for i, key in own.items() if key == ("index", side)]
                tree = KDTree(len(index))

                for n, i in enumerate(index):
                    tree.insert(points[i], n)

                tree.balance()
                inside = 0

                for i, key in own.items():
                    if key != ("thumb", side):
                        continue

                    _, n, dist = tree.find(points[i])
                    j = index[n]

                    if dist < 0.004 and (points[i] - points[j]).dot(normals[j]) < -0.0005:
                        inside += 1

                print("THUMB %s %s: %d thumb vertices inside the index" % (pose_name, side, inside))
                failed = failed or inside > 0

    print("BENDS FAIL" if failed else "BENDS PASS")
    sys.exit(1 if failed else 0)


main()
