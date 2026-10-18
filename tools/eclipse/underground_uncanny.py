"""The Metro Underground's uncanny (docs/superpowers/refs/underground/supernatural_refs.md):
the nahual, the old man who sits on the bench every night become an enormous black dog,
lying beside it with its head up; and the old man's palm hat, left on the bench by his paper.

The dog lies along +X (its head that way), on the floor (z = 0). Its head is its own object,
its origin the neck (NECK on the body) so the bay can turn it to watch; its snout along +X.
It is modelled as one smooth skin over a skeleton (Blender's Skin, then Subdivision), on a
xoloitzcuintle's build: the Aztec dog that guides the dead through Mictlan. Mignola's way:
one black shape with nothing drawn inside it but two ember eyes.

    Blender -b --factory-startup --python tools/eclipse/underground_uncanny.py
"""

import math
import os
import random
import sys

from mathutils import Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import bmesh  # noqa: E402
import bpy  # noqa: E402

import common  # noqa: E402
import gate  # noqa: E402
import underground_shapes  # noqa: E402
from underground_shapes import pipe, smooth_object, turned  # noqa: E402

NAME = "underground_uncanny"
ATLAS = 1024
SLOTS = ["nahual_black", "ember", "palm", "shade", "hollow"]

rng = random.Random(1521)

# Where the head turns on the body: the top of the neck. Where the chest is deepest and the
# waist most tucked (a xolo's build).
NECK = (0.88, 0.0, 0.64)
CHEST_X = 0.55
WAIST_X = 0.3
SIDES = 10
# How smooth the skin is made (Subdivision levels), and the voxels its parts are fused on (m).
SMOOTH = 2
BODY_VOXEL = 0.018
HEAD_VOXEL = 0.0125


def skinned(name, joints, bones, slot, smooth=SMOOTH):
    """An organic closed form from a skeleton (the Skin modifier, then Subdivision): `joints`
    [(at, (radius across, radius up))], `bones` [(i, j)] between them; joint 0 its root."""
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata([j[0] for j in joints], list(bones), [])
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(obj)
    skin = obj.modifiers.new("skin", "SKIN")
    skin.use_smooth_shade = True
    skin.branch_smoothing = 0.6

    for i, (_, (across, up)) in enumerate(joints):
        mesh.skin_vertices[0].data[i].radius = (across, up)

    mesh.skin_vertices[0].data[0].use_root = True
    sub = obj.modifiers.new("smooth", "SUBSURF")
    sub.levels = smooth
    sub.render_levels = smooth
    depsgraph = bpy.context.evaluated_depsgraph_get()
    solid = bpy.data.meshes.new_from_object(obj.evaluated_get(depsgraph))
    obj.modifiers.clear()
    obj.data = solid
    bpy.data.meshes.remove(mesh)
    solid.materials.clear()
    solid.materials.append(common.slot(slot))

    for poly in solid.polygons:
        poly.material_index = 0
        poly.use_smooth = True

    return obj


def chain(name, joints, slot="nahual_black", smooth=SMOOTH):
    """One unbranched limb skinned from its joints in order (every limb its own skin, rooted
    inside what it grows from; `fused` joins them into one surface)."""
    return skinned(name, joints, [(i, i + 1) for i in range(len(joints) - 1)], slot, smooth)


def leaf(name, root, tip, width, thick, cup, slot="nahual_black"):
    """A broad leaf (a bat ear): wide at its root, tapering to a rounded point at its tip,
    `thick` through, its front cupped in by `cup`; root and tip (x, y, z), its face toward +x."""
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=16, v_segments=12, radius=1.0)
    r, t = Vector(root), Vector(tip)
    length = (t - r).length
    up = (t - r).normalized()
    side = up.cross(Vector((1.0, 0.0, 0.0))).normalized()
    front = side.cross(up).normalized()

    for v in bm.verts:
        x, y, z = v.co
        along = (z + 1.0) / 2.0                       # 0 root, 1 tip
        w = width * (1.0 - 0.7 * along ** 1.4)        # wide at the root, narrowing to a rounded tip
        depth = thick * (1.0 - 0.2 * along) * x - cup * (1.0 - y * y) * (1.0 if x > 0 else 0.0)
        v.co = r + up * (along * length) + side * (y * w * 0.5) + front * depth

    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(obj)
    mesh.materials.append(common.slot(slot))
    return obj


def fused(obj, voxel, calm=4, slot="nahual_black"):
    """Its parts fused into one smooth surface (the Colima dogs' one burnished volume): a voxel
    remesh unions them, then smoothing burnishes away the voxels' steps and the joins."""
    remesh = obj.modifiers.new("fuse", "REMESH")
    remesh.mode = "VOXEL"
    remesh.voxel_size = voxel
    remesh.adaptivity = 0.0
    smooth = obj.modifiers.new("burnish", "SMOOTH")
    smooth.factor = 0.6
    smooth.iterations = calm
    depsgraph = bpy.context.evaluated_depsgraph_get()
    solid = bpy.data.meshes.new_from_object(obj.evaluated_get(depsgraph))
    old = obj.data
    obj.modifiers.clear()
    obj.data = solid
    bpy.data.meshes.remove(old)
    tidy(solid)
    solid.materials.clear()
    solid.materials.append(common.slot(slot))

    for poly in solid.polygons:
        poly.material_index = 0
        poly.use_smooth = True

    return obj


def tidy(mesh, weld=0.001, least=200):
    """A fused surface tidied: corners closer than `weld` merged (the faces smoothing squeezed to
    nothing), and loose fragments under `least` faces (crumbs the voxels left at thin tips) gone."""
    bm = bmesh.new()
    bm.from_mesh(mesh)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=weld)
    bm.faces.ensure_lookup_table()
    seen, crumbs = set(), []

    for f in bm.faces:
        if f in seen:
            continue
        island, todo = {f}, [f]
        while todo:
            g = todo.pop()
            for e in g.edges:
                for h in e.link_faces:
                    if h not in island:
                        island.add(h)
                        todo.append(h)
        seen |= island
        if len(island) < least:
            crumbs.extend(island)

    if crumbs:
        bmesh.ops.delete(bm, geom=crumbs, context="FACES")

    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(mesh)
    bm.free()


def nahual_body():
    """The dog lying sphinx-like (a sighthound's pose), a xoloitzcuintle's build made enormous:
    a deep chest on the floor line, the waist tucked up behind it, the haunch rising again,
    the hind legs folded flat beside the belly, the forelegs straight out and parallel, a long
    low tail curled round to its feet, the neck rising long to its head."""
    torso = chain("nahual_body", [
        ((-0.04, 0.0, 0.28), (0.1, 0.11)),     # the rump
        ((0.1, 0.0, 0.29), (0.13, 0.14)),      # the haunch
        ((WAIST_X, 0.0, 0.33), (0.09, 0.085)),  # the tucked waist
        ((CHEST_X, 0.0, 0.31), (0.14, 0.22)),  # the ribs, deep to the floor line
        ((0.7, 0.0, 0.36), (0.13, 0.22)),      # the brisket
        ((0.8, 0.0, 0.5), (0.085, 0.1)),       # the neck's root
        (NECK, (0.07, 0.08))])                 # the neck's top
    limbs = []

    for sy in (-1, 1):
        # A foreleg straight out and parallel: from inside the brisket, the elbow tucked, the
        # forearm laid forward on the floor, the paw.
        limbs.append(chain("foreleg_%d" % sy, [((0.72, sy * 0.06, 0.28), (0.065, 0.065)), ((0.72, sy * 0.085, 0.16), (0.06, 0.06)),
                                                ((0.75, sy * 0.09, 0.06), (0.046, 0.046)), ((0.9, sy * 0.092, 0.045), (0.036, 0.036)),
                                                ((1.04, sy * 0.093, 0.04), (0.033, 0.033)), ((1.12, sy * 0.093, 0.035), (0.045, 0.034))], smooth=1))
        # A hind leg folded flat beside the belly: the thigh forward and out, the shank back to the
        # hock on the floor, the foot forward along it.
        limbs.append(chain("thigh_%d" % sy, [((0.1, sy * 0.05, 0.27), (0.09, 0.09)), ((0.14, sy * 0.11, 0.2), (0.09, 0.095)),
                                              ((0.3, sy * 0.15, 0.12), (0.07, 0.07))], smooth=1))
        limbs.append(chain("shank_%d" % sy, [((0.3, sy * 0.155, 0.115), (0.058, 0.058)), ((0.18, sy * 0.17, 0.075), (0.046, 0.046)),
                                              ((0.07, sy * 0.175, 0.045), (0.042, 0.042))], smooth=1))
        limbs.append(chain("hindfoot_%d" % sy, [((0.06, sy * 0.178, 0.04), (0.038, 0.034)), ((0.17, sy * 0.183, 0.033), (0.034, 0.03)),
                                                 ((0.28, sy * 0.185, 0.032), (0.04, 0.031))], smooth=1))

    # The tail: long, low-set, tapering, curled round along the floor to the hind feet.
    limbs.append(chain("tail", [((0.0, 0.0, 0.27), (0.045, 0.045)), ((-0.12, 0.0, 0.23), (0.035, 0.035)),
                                ((-0.2, -0.03, 0.13), (0.03, 0.03)), ((-0.2, -0.14, 0.045), (0.026, 0.026)),
                                ((-0.06, -0.25, 0.035), (0.024, 0.024)), ((0.1, -0.27, 0.032), (0.022, 0.022))], smooth=1))
    underground_shapes.join(torso, limbs)
    fused(torso, BODY_VOXEL)
    low = min(v.co.z for v in torso.data.vertices)

    for v in torso.data.vertices:
        v.co.z -= low

    return torso


def nahual_head():
    """Its head, from the neck (the origin): a stub of neck back into the body; a wedge, the
    skull and the muzzle nearly equal and their planes nearly parallel; the jaw's line, the
    cheekbones, the brow; its great bat ears, broad leaves set obliquely and cupped forward;
    and its two round ember eyes sunk in."""
    # (Its collar flush with the body's neck where it meets it; the stub inside the body closes the gap
    # as it turns.)
    head = chain("nahual_head", [((-0.12, 0.0, -0.12), (0.068, 0.074)), # the neck stub, into the body
                                 ((0.0, 0.0, 0.0), (0.07, 0.078)),      # the collar at the neck's top
                                 ((0.07, 0.0, 0.06), (0.09, 0.082)),    # the back of the skull, broad
                                 ((0.15, 0.0, 0.065), (0.08, 0.07)),    # the brow
                                 ((0.22, 0.0, 0.05), (0.062, 0.055)),   # the stop
                                 ((0.3, 0.0, 0.035), (0.05, 0.045)),    # the muzzle, level with the skull
                                 ((0.37, 0.0, 0.025), (0.042, 0.038))], smooth=1)  # the nose, blunt
    flesh = [chain("jaw", [((0.04, 0.0, -0.02), (0.06, 0.04)), ((0.17, 0.0, -0.01), (0.048, 0.034)),
                           ((0.3, 0.0, -0.005), (0.034, 0.028))], smooth=1)]
    eyes = []

    for sy in (-1, 1):
        flesh.append(chain("cheek_%d" % sy, [((0.07, sy * 0.045, 0.02), (0.036, 0.03)), ((0.17, sy * 0.04, 0.03), (0.034, 0.028))], smooth=1))
        # A great bat ear, a broad leaf: its root on the skull's crown, standing tall and a little out.
        # (Its root sunk deep in the skull: a leaf comes to a point at its root, and must overlap to fuse.)
        flesh.append(leaf("ear_%d" % sy, root=(0.07, sy * 0.035, 0.0), tip=(0.0, sy * 0.2, 0.34), width=0.17, thick=0.034,
                          cup=0.014))
        # An eye, round, sunk half into the skull beside the brow, looking forward and out.
        m = common.Mesh("eye_%d" % sy, outward=True)
        turned(m, [(0.012, 0.0), (0.022, 0.012), (0.022, 0.026), (0.012, 0.036)], 8, "ember",
               at=(0.15, sy * 0.05, 0.075), lean=math.pi / 2, towards=(math.pi - 0.5) if sy > 0 else 0.5)
        eyes.append(m.make())

    underground_shapes.join(head, flesh)
    fused(head, HEAD_VOXEL)
    underground_shapes.join(head, eyes)
    return head


# --- the procession's shades (docs/superpowers/refs/underground/shade_refs.md) ---------------------
# A shade is a shroud with no body in it (the Santa Compaña's, the Procesión del Silencio's): one tall
# draped form from its hood to a ragged hem lifted off the floor, vertical folds deepening toward the
# hem, a cape's edge across the chest, its face a hollow recessed in the hood, its sleeves meeting
# before it where it holds its candle. Built ring by ring; faces x+, the floor z 0.

HOVER = 0.1
SEGMENTS = 56
RINGS = 96
# Each shade: its height to its hood's base (the shoulders' top), its hood ("capirote" a tall point,
# "veil" a rounded rebozo), its hem's half-width, its shoulders', a seed, a sombrero over it.
SHADES = {
    "shade_capirote": dict(body=1.45, hood="capirote", hem=0.33, shoulder=0.22, seed=11, hat=False),
    "shade_veiled": dict(body=1.24, hood="veil", hem=0.36, shoulder=0.2, seed=23, hat=False),
    "shade_child": dict(body=0.8, hood="veil", hem=0.24, shoulder=0.14, seed=37, hat=False),
    "shade_sombrero": dict(body=1.42, hood="veil", hem=0.32, shoulder=0.22, seed=51, hat=True),
}
# Where each holds its candle (its sleeves' cuffs meet there): before its chest, below the cape.
CANDLE_HELD = {n: (0.25 * d["shoulder"] / 0.22 + 0.02, 0.0, HOVER + d["body"] * 0.66) for n, d in SHADES.items()}


def _profile(body, hood, hem, shoulder):
    """(height above the hem, radius) up the shade: the flared hem, the falling robe, the cape over the
    shoulders, the neck, then its hood."""
    b = body
    rows = [(0.0, hem), (0.12 * b, hem * 0.9), (0.3 * b, hem * 0.76), (0.5 * b, shoulder * 0.98),
            (0.66 * b, shoulder * 0.94), (0.8 * b, shoulder * 1.04), (0.92 * b, shoulder * 1.02),
            (0.98 * b, shoulder * 0.8), (1.0 * b, 0.13)]
    if hood == "capirote":
        h = shoulder / 0.22
        rows += [(b + 0.05 * h, 0.15 * h), (b + 0.15 * h, 0.14 * h), (b + 0.3 * h, 0.105 * h), (b + 0.5 * h, 0.055 * h),
                 (b + 0.7 * h, 0.012)]
    else:
        h = shoulder / 0.2
        rows += [(b + 0.05 * h, 0.16 * h), (b + 0.15 * h, 0.165 * h), (b + 0.24 * h, 0.15 * h), (b + 0.3 * h, 0.11 * h),
                 (b + 0.335 * h, 0.04 * h)]
    return rows


def _radius_at(rows, z):
    for (z0, r0), (z1, r1) in zip(rows, rows[1:]):
        if z <= z1:
            t = (z - z0) / max(z1 - z0, 1e-6)
            t = t * t * (3 - 2 * t)
            return r0 + (r1 - r0) * t
    return rows[-1][1]


def _bell(name, path, radii, sides=14):
    """A sleeve along `path`, its radius growing by `radii`, closed at both ends."""
    bm = bmesh.new()
    rings = []
    n = len(path)
    for i, p in enumerate(path):
        ahead = (path[min(i + 1, n - 1)] - path[max(i - 1, 0)]).normalized()
        side = ahead.cross(Vector((0.0, 0.0, 1.0)))
        side = side.normalized() if side.length > 1e-5 else Vector((1.0, 0.0, 0.0))
        up = side.cross(ahead).normalized()
        rings.append([bm.verts.new(p + (side * math.cos(math.tau * j / sides) + up * math.sin(math.tau * j / sides)) * radii[i])
                      for j in range(sides)])
    for r0, r1 in zip(rings, rings[1:]):
        for j in range(sides):
            bm.faces.new([r0[j], r0[(j + 1) % sides], r1[(j + 1) % sides], r1[j]])
    bm.faces.new(list(reversed(rings[0])))
    bm.faces.new(rings[-1])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    mesh.materials.append(common.slot("shade"))
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(obj)
    return obj


def _face_reach(a, z, face):
    """How far out of its face's oval a point of the hood is (below 1 inside): angle `a` round it, height z."""
    a = (a + math.pi) % math.tau - math.pi
    middle, half = (face[0] + face[1]) / 2.0, (face[1] - face[0]) / 2.0
    return (a / 0.62) ** 2 + ((z - middle) / half) ** 2


def shade(name, body, hood, hem, shoulder, seed, hat):
    """One shade, ring by ring (shade_refs.md)."""
    rng = random.Random(seed)
    rows = _profile(body, hood, hem, shoulder)
    top = rows[-1][0]
    face = (body * 1.03, body + (0.26 if hood == "capirote" else 0.24) * shoulder / 0.21)
    phase = rng.uniform(0.0, math.tau)
    rag = [rng.uniform(0.0, 1.0) for _ in range(SEGMENTS)]
    bm = bmesh.new()
    rings = []

    for i in range(RINGS + 1):
        z = top * i / RINGS
        r = _radius_at(rows, z)
        ring = []
        for k in range(SEGMENTS):
            a = math.tau * k / SEGMENTS
            # Folds falling straight down the robe, deepening toward the hem, gone at the shoulders.
            fold_depth = 0.09 * max(0.0, 1.0 - z / (0.75 * body))
            rr = r * (1.0 + fold_depth * math.sin(6 * a + phase) + 0.4 * fold_depth * math.sin(11 * a + 2 * phase))
            x, y = math.cos(a) * rr * 0.82, math.sin(a) * rr
            front = max(0.0, math.cos(a))
            # The cape's edge across the chest, a ridge before it.
            ridge = math.exp(-((z - 0.6 * body) / 0.025) ** 2) * 0.03 * front
            x += ridge
            # The face: an oval hollow pushed back into the hood, its brow jutting over it.
            d = _face_reach(a, z, face)
            if d < 1.0:
                x -= 0.11 * shoulder / 0.22 * math.sqrt(1.0 - d) * math.cos(a)
            brow = math.exp(-((z - face[1]) / 0.03) ** 2) * math.exp(-(a / 0.6) ** 2)
            x += 0.035 * shoulder / 0.22 * brow
            zz = z
            if i == 0:
                # The hem ragged: torn tongues hanging lower here and there.
                zz -= 0.07 * max(0.0, math.sin(5 * a + phase)) + 0.04 * rag[k]
            elif i == 1:
                zz -= 0.03 * max(0.0, math.sin(5 * a + phase))
            ring.append(bm.verts.new((x, y, zz + HOVER + 0.11)))
        rings.append(ring)

    shade_slot, hollow_slot = 0, 1

    for i in range(RINGS):
        for k in range(SEGMENTS):
            f = bm.faces.new([rings[i][k], rings[i][(k + 1) % SEGMENTS], rings[i + 1][(k + 1) % SEGMENTS], rings[i + 1][k]])
            # (Its face by where its corners came from on the ring, so the hollow's edge follows the oval.)
            a = math.tau * (k + 0.5) / SEGMENTS
            z_mid = top * (i + 0.5) / RINGS
            f.material_index = hollow_slot if _face_reach(a, z_mid, face) < 0.82 else shade_slot

    # Its hem's underside closed a little up inside it, its hood's top to its point.
    under = bm.verts.new((0.0, 0.0, HOVER + 0.11 + 0.25))
    for k in range(SEGMENTS):
        bm.faces.new([rings[0][(k + 1) % SEGMENTS], rings[0][k], under]).material_index = shade_slot
    apex = bm.verts.new((0.0, 0.0, top + HOVER + 0.11 + 0.005))
    for k in range(SEGMENTS):
        bm.faces.new([rings[-1][k], rings[-1][(k + 1) % SEGMENTS], apex]).material_index = shade_slot

    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(obj)
    mesh.materials.append(common.slot("shade"))
    mesh.materials.append(common.slot("hollow"))

    # Its sleeves, from its shoulders down and forward, meeting before its chest at its candle.
    held = Vector(CANDLE_HELD[name])
    parts = []
    for sy in (-1, 1):
        # A bell sleeve: narrow at the shoulder, widening to its cuff, its mouth hanging open.
        shoulder_at = Vector((0.0, sy * shoulder * 0.86, HOVER + 0.11 + body * 0.9))
        elbow = Vector((0.07, sy * shoulder * 1.02, HOVER + 0.11 + body * 0.7))
        cuff = held + Vector((-0.03, sy * 0.075, -0.02))
        path = [shoulder_at.lerp(elbow, t / 5.0) for t in range(5)] + [elbow.lerp(cuff, t / 5.0) for t in range(6)]
        k = shoulder / 0.22
        parts.append(_bell(name + "_sleeve_%d" % sy, path, [0.055 * k + 0.05 * k * (j / (len(path) - 1)) ** 1.6
                                                             for j in range(len(path))]))
    if hat:
        m = common.Mesh("sombrero", outward=True)
        crown_at = HOVER + 0.11 + body + 0.12
        turned(m, [(0.2, 0.0), (0.4, 0.012), (0.42, 0.04), (0.2, 0.06), (0.19, 0.16), (0.15, 0.22), (0.06, 0.235)], 24,
               "shade", at=(0.0, 0.0, crown_at))
        parts.append(m.make())
    underground_shapes.join(obj, parts)

    for poly in obj.data.polygons:
        poly.use_smooth = True

    # (Its lowest point at the hover: its ragged hem's longest tongue.)
    low = min(v.co.z for v in obj.data.vertices)
    for v in obj.data.vertices:
        v.co.z += HOVER - low
    # Where its candle stands, written with the kit (its _wicks.json) for the bay.
    common.WICKS.setdefault(name, []).append((held.x, held.y, held.z + HOVER - low))
    return obj


def old_hat(m):
    """The old man's palm hat, its brim gone soft, left on the bench."""
    turned(m, [(0.11, 0.0), (0.26, 0.006), (0.265, 0.022), (0.12, 0.03), (0.115, 0.1), (0.09, 0.14), (0.04, 0.155)],
           16, "palm", jitter=0.04)


def build():
    common.reset()
    underground_shapes.rng = rng
    rng.seed(1521)
    nahual_body()
    nahual_head()
    smooth_object("old_hat", old_hat)
    for name, d in SHADES.items():
        shade(name, **d)


def main():
    build()
    # (Its creature is drawn by its own shader, never from the atlas: gated at gate.CREATURE_SLIVER; the hat
    # is held to the full sliver gate by its kit test.)
    common.export_piece(NAME, ATLAS, SLOTS, out=common.ROOT / "assets" / "eclipse" / "kit", sets_each=True, budget=20000,
                        sliver=gate.CREATURE_SLIVER)


if __name__ == "__main__":
    main()
