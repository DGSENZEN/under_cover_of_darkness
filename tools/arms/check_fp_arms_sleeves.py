"""Does the coat's sleeve bend like cloth over an arm? Each elbow is bent 90
and 130 degrees (closing the crook) and the sleeve measured through the
elbow's bisector: thick as at rest from the point to the crook (at least
ELBOW_KEEP) and side to side (SIDE_KEEP); and the crook, which folds into
itself as a crease (out of sight, as a sleeve does), never pushes cloth out
through the far side of the arm.

    /Applications/Blender.app/Contents/MacOS/Blender --background --factory-startup \\
        assets/characters/fp_arms/source/fp_arms_blockout.blend \\
        --python tools/arms/check_fp_arms_sleeves.py

Prints a line per measure and SLEEVES PASS or SLEEVES FAIL; exits 1 on a
failure.
"""

import math
import sys

import bpy
from mathutils import Matrix, Vector

ELBOW_KEEP = 0.8
SIDE_KEEP = 0.85
SLAB = 0.006
SHIRT_PAST = 0.025
BENDS = (0.0, 90.0, 130.0)


def rest_all(rig):
    rig.animation_data.action = None

    for track in rig.animation_data.nla_tracks:
        track.mute = True

    for pb in rig.pose.bones:
        pb.matrix_basis.identity()

    bpy.context.view_layer.update()


def evaluated(body):
    graph = bpy.context.evaluated_depsgraph_get()
    mesh = body.evaluated_get(graph).to_mesh()
    points = [v.co.copy() for v in mesh.vertices]
    body.evaluated_get(graph).to_mesh_clear()
    return points


def coat_verts(body):
    coat = [i for i, m in enumerate(body.data.materials) if m.name == "Coat"]
    out = set()

    for p in body.data.polygons:
        if p.material_index in coat:
            out.update(p.vertices)

    return out


def frame(rig, side):
    """The elbow: its joint, the bisector of upper arm and forearm, the crook
    (the side it bends toward) and the hinge, posed, world space."""
    upper = rig.pose.bones["upperarm_" + side]
    lower = rig.pose.bones["lowerarm_" + side]
    mw = rig.matrix_world
    joint = mw @ lower.head
    up = (mw @ upper.tail - mw @ upper.head).normalized()
    fore = (mw @ lower.tail - mw @ lower.head).normalized()
    bisector = (up + fore).normalized()
    turn = fore - up
    crook = (turn - bisector * turn.dot(bisector))
    crook = crook.normalized() if crook.length > 1e-6 else Vector((0.0, 0.0, 1.0))
    return joint, bisector, crook, bisector.cross(crook).normalized(), up, fore


def bend(rig, side, degrees):
    """Close the elbow by `degrees` about its hinge (the sign that brings the
    forearm toward the shoulder)."""
    lower = rig.pose.bones["lowerarm_" + side]
    best = None

    for sign in (1.0, -1.0):
        lower.matrix_basis = Matrix.Rotation(sign * math.radians(degrees), 4, "Z")
        bpy.context.view_layer.update()
        mw = rig.matrix_world
        reach = (mw @ lower.tail - mw @ rig.pose.bones["upperarm_" + side].head).length

        if best is None or reach < best[0]:
            best = (reach, sign)

    lower.matrix_basis = Matrix.Rotation(best[1] * math.radians(degrees), 4, "Z")
    bpy.context.view_layer.update()


def material_verts(body, name):
    index = [i for i, m in enumerate(body.data.materials) if m.name == name]
    out = set()

    for p in body.data.polygons:
        if p.material_index in index:
            out.update(p.vertices)

    return out


def through_cuff(points, skin, cuff, rig, side):
    """Skin vertices outside the shirt cuff's outer wall, along its length.
    The cuff's section, from its own vertices: per slice along the forearm,
    its widest reach each way round."""
    lower = rig.pose.bones["lowerarm_" + side]
    mw = rig.matrix_world
    a, b = mw @ lower.head, mw @ lower.tail
    axis = (b - a).normalized()
    mine = [i for i in cuff if ((points[i] - a) - axis * (points[i] - a).dot(axis)).length < 0.06]
    span = [(points[i] - a).dot(axis) for i in mine]
    low, high = min(span), max(span)
    centre = sum((points[i] for i in mine), Vector()) / len(mine)
    centre = a + axis * (centre - a).dot(axis)
    # The cuff's outline round the axis: its furthest reach per 20 degrees
    # (its vertices are 15 apart: every bin holds some).
    ref = (points[mine[0]] - centre)
    ref = (ref - axis * ref.dot(axis)).normalized()
    other = axis.cross(ref)
    reach = [0.0] * 18

    for i in mine:
        d = points[i] - centre
        d = d - axis * d.dot(axis)
        k = int((math.degrees(math.atan2(d.dot(other), d.dot(ref))) % 360.0) // 20)
        reach[k] = max(reach[k], d.length)

    poked = 0

    for p in skin_samples(points, skin):
        d = p - centre
        along = d.dot(axis)

        # Along the cuff where it shows: from the coat's end (the cuff shows
        # SHIRT_PAST beyond it) to its own end. Under the coat the coat hides
        # it (lining_hides).
        if not (high - SHIRT_PAST <= (p - a).dot(axis) <= high - 0.004):
            continue

        d = d - axis * along

        # (This arm's own wrist, not the other hand across the chest.)
        if d.length > 0.08:
            continue

        k = int((math.degrees(math.atan2(d.dot(other), d.dot(ref))) % 360.0) // 20)

        if d.length > reach[k] + 0.0005:
            poked += 1

    return poked


SKIN_EDGES = []


def skin_samples(points, skin):
    """The skin's vertices and points along its edges (its faces can cross a
    cuff with no vertex beyond it)."""
    for i in skin:
        yield points[i]

    for a, b in SKIN_EDGES:
        for t in (0.25, 0.5, 0.75):
            yield points[a].lerp(points[b], t)


def lining_hides(points, skin, lining, rig, side):
    """Skin under the coat's cuff that reaches out past its lining (and so
    could show between the cuffs): there must be none."""
    lower = rig.pose.bones["lowerarm_" + side]
    mw = rig.matrix_world
    a, b = mw @ lower.head, mw @ lower.tail
    axis = (b - a).normalized()
    mine = [i for i in lining if ((points[i] - a) - axis * (points[i] - a).dot(axis)).length < 0.07]
    span = [(points[i] - a).dot(axis) for i in mine]
    inner = min(((points[i] - a) - axis * (points[i] - a).dot(axis)).length for i in mine)
    low, high = min(span), max(span)
    count = 0

    for p in skin_samples(points, skin):
        d = p - a
        along = d.dot(axis)
        out = (d - axis * along).length

        if low <= along <= high and out < 0.08 and out > inner:
            count += 1

    return count


def upper_weight(body, index, side):
    """How much of a vertex follows the upper arm (and the clavicle above)."""
    names = {g.index: g.name for g in body.vertex_groups}
    return sum(g.weight for g in body.data.vertices[index].groups if names[g.group] in ("upperarm_" + side, "clavicle_" + side))


def across(points, verts, joint, bisector, crook, hinge):
    depth = [(points[i] - joint).dot(crook) for i in verts if abs((points[i] - joint).dot(bisector)) < SLAB]
    width = [(points[i] - joint).dot(hinge) for i in verts if abs((points[i] - joint).dot(bisector)) < SLAB]

    if not depth:
        return None, None

    return max(depth) - min(depth), max(width) - min(width)


def main():
    rig = bpy.data.objects["FPArms"]
    body = bpy.data.objects["FPArmsBody"]
    coat = coat_verts(body)
    failed = False

    for side in ("l", "r"):
        rest_all(rig)
        rest_points = evaluated(body)
        joint, bisector, crook, hinge, _, _ = frame(rig, side)
        near = [i for i in coat if (rest_points[i] - joint).length < 0.12]
        rest_depth, rest_width = across(rest_points, near, joint, bisector, crook, hinge)
        crook_side = [i for i in near if (lambda r: r.length > 0.0 and r.normalized().dot(crook) > 0.5)(
            (rest_points[i] - joint) - bisector * (rest_points[i] - joint).dot(bisector))]

        for degrees in BENDS:
            rest_all(rig)
            bend(rig, side, degrees)
            points = evaluated(body)
            pj, pb, pc, ph, up, fore = frame(rig, side)
            depth, width = across(points, near, pj, pb, pc, ph)

            if depth is None:
                print("ELBOW %s %d: no cloth across the elbow" % (side, degrees))
                failed = True
                continue

            if degrees == 0.0:
                rest_depth, rest_width = depth, width

            keep_depth = depth / rest_depth
            keep_width = width / rest_width
            print("ELBOW %s %d: point to crook keeps %.2f (%.1f of %.1f mm), side to side %.2f" % (
                side, degrees, keep_depth, depth * 1000, rest_depth * 1000, keep_width))
            failed = failed or keep_depth < ELBOW_KEEP or keep_width < SIDE_KEEP

            # The crook folds into itself, out of sight, as a crease (a
            # sleeve does); what must never happen is crook cloth pushed out
            # through the far side of the other half of the arm.
            poked = 0

            for i in crook_side:
                mine = upper_weight(body, i, side) >= 0.5
                bone = rig.pose.bones[("lowerarm_" if mine else "upperarm_") + side]
                a, b = rig.matrix_world @ bone.head, rig.matrix_world @ bone.tail
                axis = (b - a).normalized()
                d = points[i] - a
                radial = d - axis * d.dot(axis)
                beyond = radial.length > 0.045 and radial.normalized().dot(pc) < -0.3
                inside_span = 0.0 <= d.dot(axis) <= (b - a).length

                if beyond and inside_span:
                    poked += 1

            print("CROOK %s %d: %d of %d crook vertices pushed out through the far side" % (side, degrees, poked, len(crook_side)))
            failed = failed or poked > 0 or len(crook_side) < 50

    # The wrist bent hard (a hook over a sill): no skin through the shirt's
    # cuff, anywhere along it.
    skin = [i for i in material_verts(body, "Skin")]
    skin_set = set(skin)
    SKIN_EDGES.extend(tuple(e.vertices) for e in body.data.edges if e.vertices[0] in skin_set and e.vertices[1] in skin_set)
    cuff = material_verts(body, "ShirtCuff")

    for side in ("l", "r"):
        for axis in ("X", "Z"):
            for degrees in (0.0, 40.0, -40.0):
                rest_all(rig)
                rig.pose.bones["hand_" + side].matrix_basis = Matrix.Rotation(math.radians(degrees), 4, axis)
                bpy.context.view_layer.update()
                points = evaluated(body)
                poked = through_cuff(points, skin, cuff, rig, side)
                hidden = lining_hides(points, skin, material_verts(body, "Lining"), rig, side)
                print("WRIST %s %s %+d: %d skin vertices through the shirt cuff, %d out past the coat's lining" % (side, axis, degrees, poked, hidden))
                failed = failed or poked > 0 or hidden > 0

    rest_all(rig)
    print("SLEEVES FAIL" if failed else "SLEEVES PASS")
    sys.exit(1 if failed else 0)


main()
