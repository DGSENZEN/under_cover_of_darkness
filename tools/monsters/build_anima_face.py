"""The ravenous ánima's face (silhouette B, the user's pick): a small cranium, slanted pits, a
long hanging jaw. CDmir's CC0 human skull (assets/characters/skull, credited in CREDITS.md),
the sculpt itself and its own teeth, dried: the dome drawn in, the temples and cheeks sunk,
the brow dragged down to the nose, cracked leather over bone, ink in every hollow; the jaw
stretched long and tapered, the gums gone back from long teeth, some of them lost. Sinews
join the cheek to the jaw, stretched in the game as it gapes.

Skull and Jaw (its origin its hinge, so it drops) are closed solids, each with what hangs in
its mouth (Gullet, Tongue), and so is the Sinew, one strand a metre long the game stretches
between the SinewUp_ and SinewLow_ markers. The script
refuses an open edge, and any tooth away from the mouth. Blender's axes: +Y ahead (the game's
-Z), +Z up.

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
from mathutils import Matrix, Vector, kdtree, noise
from mathutils.bvhtree import BVHTree

ROOT = sys.argv[sys.argv.index("--") + 1]
SKULL = os.path.join(ROOT, "assets", "characters", "skull", "skull-Low4K.obj")
SOURCE = os.path.join(ROOT, "assets", "monsters", "source")
GLB = os.path.join(ROOT, "assets", "monsters", "anima_face.glb")

## Crown to chin of the sculpt, before it is dried (m).
HEIGHT = 0.36
## Measured off the fitted sculpt: the middle of the eye, the top of the mouth, the front.
EYE = Vector((0.045, 0.0, 0.015))
MOUTH_TOP = -0.075
## The dome drawn in: above the brow, behind the face, across.
DOME_LOW = 0.045
DOME_TALL = 0.8
DOME_DEEP = 0.82
DOME_WIDE = 0.86
CHEEK_WIDE = 0.95
## Sunk, each by how much (m): the temple, the cheek under the cheekbone.
TEMPLE = (Vector((0.098, 0.06, 0.05)), 0.05, 0.02)
CHEEK = (Vector((0.08, 0.07, -0.06)), 0.036, 0.018)
## The brow, dragged down at the nose (m) and forward: an angry slant.
BROW_DOWN = 0.019
BROW_OUT = 0.006
## The nose's holes, deeper.
NOSE_DEEP = 0.022
## A blow it took long ago, on one side of the dome.
DENT = (Vector((-0.06, 0.05, 0.1)), 0.032, 0.012)
## The jaw: how much longer, about its hinge; how narrow it comes at the chin.
JAW_LONG = 1.34
JAW_CHIN_NARROW = 0.6
## The teeth: how much longer, the gums gone back; which are lost, and which broken (by
## where they are along the row, from one end, upper and lower).
TOOTH_LONG = 1.34
TOOTH_TIP = 0.42
LOST = {"upper": [3, 7, 13], "lower": [2, 11]}
BROKEN = {"upper": [5, 10], "lower": [6, 14]}
BROKEN_LONG = 0.62
## How finely it is cut, and how many triangles each bone keeps.
SKULL_TRIS = 3200
JAW_TRIS = 1800
## The leather: how deep its cords and cracks are (m), how thick it lies on the bone.
CORDS = 0.0022
CRACKS = 0.002
LEATHER_THICK = 0.0024
## The gullet hanging from the skull's base, closing the mouth from behind and hanging on
## under the jaw to a point: where it starts (y, z), how wide, where it ends.
GULLET_AT = (-0.015, -0.055)
GULLET_WIDE = 0.046
GULLET_END = (-0.045, -0.3)
## The dried tongue on the floor of the jaw: its back and tip (y), how wide, how high.
TONGUE_BACK = 0.012
TONGUE_TIP = 0.088
TONGUE_WIDE = 0.034
TONGUE_FLOOR = -0.15
TONGUE_HIGH = 0.024
## Sinews, each side, along the back of the mouth (y), and how thick (m), at the end and the middle.
SINEW_AT = (0.05, 0.072, 0.098)
SINEW_ENDS = 0.0058
SINEW_MIDDLE = 0.0024
## Paint, as it should come out in the game.
LEATHER = (0.25, 0.185, 0.125)
LEATHER_DARK = (0.12, 0.082, 0.06)
BONE = (0.58, 0.5, 0.34)
BONE_DIM = (0.34, 0.27, 0.18)
TOOTH = (0.66, 0.58, 0.38)
TOOTH_ROOT = (0.13, 0.09, 0.05)
SINEW = (0.14, 0.085, 0.06)
INK = (0.006, 0.005, 0.005)


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


def bump(co, at, reach):
    return math.exp(-((co - at).length / reach) ** 2)


def mirrored(co):
    return Vector((abs(co.x), co.y, co.z))


def close_up(bm):
    """Its stray edges gone, its holes filled flat."""
    bmesh.ops.delete(bm, geom=[e for e in bm.edges if not e.link_faces], context="EDGES")
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context="VERTS")
    bmesh.ops.holes_fill(bm, edges=[e for e in bm.edges if len(e.link_faces) == 1], sides=0)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)


def cracks_at(co):
    """0 on a crack of the dried leather, 1 away from one."""
    far, _points = noise.voronoi(co * 34.0, distance_metric="DISTANCE", exponent=2.5)
    return smooth(0.0, 0.2, far[1] - far[0])


def cords_at(co):
    """The dried cords running down it, -1..1."""
    return noise.noise(Vector((co.x * 62.0, co.y * 62.0, co.z * 15.0)))


def skin_at(co, is_jaw):
    """1 where the leather still lies on it, 0 where it has worn off the bone: the brow, the
    cheekbones, the bridge of the nose, the chin; and where the blow split it, on the dome.
    The same both sides, but for that; its edges torn."""
    m = mirrored(co)

    if is_jaw:
        worn = max(bump(m, Vector((0.0, 0.135, -0.215)), 0.03), bump(m, Vector((0.05, 0.095, -0.165)), 0.016))
    else:
        worn = max(
            bump(m, Vector((0.056, 0.128, 0.05)), 0.024), bump(m, Vector((0.03, 0.142, 0.04)), 0.017),
            bump(m, Vector((0.078, 0.098, -0.036)), 0.024), bump(m, Vector((0.012, 0.15, 0.002)), 0.017),
            bump(co, DENT[0], DENT[1] * 1.15),
        )

    tear = noise.noise(co * 44.0) * 0.32 + noise.noise(co * 17.0) * 0.28
    return smooth(0.32, 0.58, 1.0 - worn + tear)


def dry_skull(obj):
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    close_up(bm)
    bmesh.ops.subdivide_edges(bm, edges=bm.edges[:], cuts=1, use_grid_fill=True, smooth=0.5)
    bmesh.ops.triangulate(bm, faces=bm.faces[:])

    for v in bm.verts:
        c = v.co.copy()
        above = smooth(-0.01, DOME_LOW + 0.03, c.z)
        # The brow first, while the eye is where it was measured: dragged down at the nose.
        near_eye = smooth(0.055, 0.015, abs(c.z - (EYE.z + 0.042)))
        toward_nose = smooth(0.082, 0.012, abs(c.x))
        front = smooth(0.07, 0.11, c.y)
        drag = near_eye * front
        c.z -= BROW_DOWN * toward_nose * drag
        c.y += BROW_OUT * drag
        # The nose's holes.
        if abs(c.x) < 0.03 and -0.052 < c.z < -0.012 and c.y > 0.1:
            c.y -= NOSE_DEEP * smooth(0.03, 0.012, abs(c.x)) * smooth(0.012, 0.0, abs(c.z + 0.032) - 0.008)

        # The dome drawn in.
        if c.z > DOME_LOW:
            c.z = DOME_LOW + (c.z - DOME_LOW) * DOME_TALL

        if c.y < 0.0:
            c.y *= DOME_DEEP

        c.x *= CHEEK_WIDE + (DOME_WIDE - CHEEK_WIDE) * above
        # Sunk.
        m = mirrored(c)

        for at, reach, by in (TEMPLE, CHEEK):
            inward = Vector((-math.copysign(1.0, c.x), -0.35, 0.0)).normalized()
            c += inward * by * bump(m, at, reach)

        c -= (c - Vector((0.0, 0.02, 0.0))).normalized() * DENT[2] * bump(c, DENT[0], DENT[1])
        v.co = c

    bm.normal_update()

    for v in bm.verts:
        v.co += v.normal * leather_rise(v.co, False)

    bm.to_mesh(obj.data)
    bm.free()
    decimated(obj, SKULL_TRIS)


def dry_jaw(obj, hinge):
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    close_up(bm)
    bmesh.ops.subdivide_edges(bm, edges=bm.edges[:], cuts=1, use_grid_fill=True, smooth=0.5)
    bmesh.ops.triangulate(bm, faces=bm.faces[:])

    for v in bm.verts:
        v.co = stretched(v.co, hinge)

    bm.normal_update()

    for v in bm.verts:
        v.co += v.normal * leather_rise(v.co, True)

    bm.to_mesh(obj.data)
    bm.free()
    decimated(obj, JAW_TRIS)


def stretched(co, hinge):
    """The jaw long and tapered, about its hinge."""
    from_hinge = co - hinge
    down = smooth(0.0, 0.16, -from_hinge.z * JAW_LONG)
    return hinge + Vector((from_hinge.x * (1.0 + (JAW_CHIN_NARROW - 1.0) * down), from_hinge.y, from_hinge.z * JAW_LONG))


def leather_rise(co, is_jaw):
    skin = skin_at(co, is_jaw)
    return LEATHER_THICK * skin + skin * (CORDS * cords_at(co) - CRACKS * (1.0 - cracks_at(co)))


def decimated(obj, tris):
    modifier = obj.modifiers.new("Keep", "DECIMATE")
    modifier.ratio = min(1.0, tris / max(sum(len(p.vertices) - 2 for p in obj.data.polygons), 1))
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.modifier_apply(modifier="Keep")


def row_order(teeth):
    """Along the row, one end to the other."""
    def along(tooth):
        vs = world_verts(tooth)
        middle = sum(vs, Vector()) / len(vs)
        return math.atan2(middle.x, middle.y - 0.02)

    return sorted(teeth, key=along)


def dry_teeth(teeth, which, hinge):
    """Long, the gum gone back from them; narrowed toward the tip; some lost, some broken.
    Lower ones ride to where the jaw has gone. Returns those left."""
    left = []

    for n, tooth in enumerate(row_order(teeth)):
        if n in LOST[which]:
            bpy.data.objects.remove(tooth)
            continue

        bm = bmesh.new()
        bm.from_mesh(tooth.data)
        root_z = max(v.co.z for v in bm.verts) if which == "upper" else min(v.co.z for v in bm.verts)
        tip_z = min(v.co.z for v in bm.verts) if which == "upper" else max(v.co.z for v in bm.verts)
        middle = sum((v.co for v in bm.verts), Vector()) / len(bm.verts)
        long = TOOTH_LONG * (BROKEN_LONG if n in BROKEN[which] else 1.0)
        span = max(abs(tip_z - root_z), 0.001)
        moved = stretched(Vector((middle.x, middle.y, root_z)), hinge) - Vector((middle.x, middle.y, root_z)) if which == "lower" else Vector()
        close_up(bm)
        bmesh.ops.subdivide_edges(bm, edges=bm.edges[:], cuts=1, use_grid_fill=True, smooth=0.9)

        for v in bm.verts:
            up_it = min(abs(v.co.z - root_z) / span, 1.0)
            narrow = 1.0 + (TOOTH_TIP - 1.0) * up_it * up_it
            v.co.x = middle.x + (v.co.x - middle.x) * narrow
            v.co.y = middle.y + (v.co.y - middle.y) * narrow
            v.co.z = root_z + (v.co.z - root_z) * long
            v.co += moved

        bm.to_mesh(tooth.data)
        bm.free()
        left.append(tooth)

    return left


def paint(obj, is_jaw, hinge):
    """Leather over bone, by the anatomy; ink down the pits, the cracks and the mouth; the
    teeth their own pieces, pale, dark at the gum."""
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bad = [e for e in bm.edges if len(e.link_faces) != 2]

    if bad:
        raise RuntimeError("%s has %d open edges" % (obj.name, len(bad)))

    bm.normal_update()
    tree = BVHTree.FromBMesh(bm)
    seen = set()
    pieces = []

    for v in bm.verts:
        if v in seen:
            continue

        stack = [v]
        seen.add(v)
        piece = []

        while stack:
            w = stack.pop()
            piece.append(w)

            for e in w.link_edges:
                u = e.other_vert(w)

                if u not in seen:
                    seen.add(u)
                    stack.append(u)

        pieces.append(piece)

    pieces.sort(key=len, reverse=True)
    root_of = {}

    for piece in pieces[1:]:
        z = [v.co.z for v in piece]
        root = max(z) if not is_jaw else min(z)

        if not is_jaw and root > MOUTH_TOP:
            raise RuntimeError("a tooth reaches up to %.3f, above the mouth" % root)

        for v in piece:
            root_of[v] = abs(v.co.z - root) / max(max(z) - min(z), 0.001)

    colour = {}

    for v in bm.verts:
        c = v.co

        if v in root_of:
            colour[v] = mix(TOOTH_ROOT, TOOTH, smooth(0.08, 0.42, root_of[v]))
            continue

        hit = tree.ray_cast(c + v.normal * 0.002, v.normal, 0.05)
        hollow = 1.0 - smooth(0.004, 0.045, hit[3]) if hit[0] is not None else 0.0
        skin = skin_at(c, is_jaw)
        crack = 1.0 - cracks_at(c)
        cord = cords_at(c)
        up = smooth(-0.6, 0.7, v.normal.z)
        mottle = noise.noise(c * 19.0) * 0.5 + 0.5
        leather = mix(LEATHER_DARK, LEATHER, 0.35 + up * 0.3 + mottle * 0.25 + cord * 0.28)
        bone = mix(BONE_DIM, BONE, smooth(0.25, 0.75, noise.noise(c * 52.0) * 0.45 + 0.5 + (up - 0.5) * 0.7))
        tone = mix(bone, leather, skin)
        # The torn edge of the leather is dark, and so are its cracks.
        tone = mix(tone, INK, 0.7 * smooth(0.4, 0.0, abs(skin - 0.5)))
        tone = mix(tone, INK, 0.5 * crack * skin)
        tone = mix(tone, INK, 0.8 * smooth(0.25, 0.8, hollow))
        m = mirrored(c)

        if is_jaw:
            # Inside the jaw: the mouth is black.
            inner = smooth(0.1, 0.5, -v.normal.x * math.copysign(1.0, c.x))
            floor = smooth(0.2, 0.7, v.normal.z) * smooth(0.0, 0.06, c.y - hinge.y)
            tone = mix(tone, INK, max(inner, floor))
        else:
            # The eyes and the nose, by how deep they go; the roof of the mouth.
            socket = smooth(0.06, 0.04, abs(m.x - EYE.x)) * smooth(0.055, 0.02, abs(c.z - (EYE.z + 0.005))) * smooth(0.07, 0.085, c.y)
            tone = mix(tone, INK, socket * smooth(0.13, 0.112, c.y))
            nose = smooth(0.032, 0.016, m.x) * smooth(0.03, 0.012, abs(c.z + 0.032)) * smooth(0.142, 0.125, c.y) * smooth(0.08, 0.1, c.y)
            tone = mix(tone, INK, nose)
            roof = smooth(0.1, 0.5, -v.normal.z) * smooth(-0.04, -0.07, c.z)
            tone = mix(tone, INK, roof)

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


def build_sinew():
    """One strand, a metre long along +Y, thin in its middle: stretched in the game."""
    bm = bmesh.new()
    rings = []
    count = 7

    for k in range(count):
        t = k / (count - 1)
        wide = SINEW_ENDS + (SINEW_MIDDLE - SINEW_ENDS) * math.sin(t * math.pi) ** 0.7
        rings.append([bm.verts.new((math.cos(j * math.tau / 5) * wide, t, math.sin(j * math.tau / 5) * wide)) for j in range(5)])

    for k in range(count - 1):
        for j in range(5):
            n = (j + 1) % 5
            bm.faces.new((rings[k][j], rings[k][n], rings[k + 1][n], rings[k + 1][j]))

    bm.faces.new(rings[0])
    bm.faces.new(rings[-1][::-1])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    layer = bm.loops.layers.color.new("Color")

    for f in bm.faces:
        for loop in f.loops:
            loop[layer] = paint_value(mix(SINEW, LEATHER_DARK, 0.5 + 0.5 * math.sin(loop.vert.co.y * 19.0)))

    mesh = bpy.data.meshes.new("Sinew")
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new("Sinew", mesh)
    bpy.context.collection.objects.link(obj)
    mesh.color_attributes.active_color_index = 0
    mesh.color_attributes.render_color_index = 0
    return obj


def build_gullet():
    """Dark and dry, hanging from the base of the skull to a point: no seeing through its
    mouth, and it is the long spike under the jaw."""
    bm = bmesh.new()
    rings = []
    count = 12
    around = 10

    for k in range(count):
        t = k / (count - 1)
        wide = GULLET_WIDE * math.sin(min(t * 3.6, 1.0) * math.pi * 0.5) * (1.0 - t) ** 0.8 + 0.0012
        y = GULLET_AT[0] + (GULLET_END[0] - GULLET_AT[0]) * t + math.sin(t * 6.0) * 0.006
        z = GULLET_AT[1] + (GULLET_END[1] - GULLET_AT[1]) * t
        ring = []

        for j in range(around):
            turn = j * math.tau / around
            lump = 1.0 + 0.3 * noise.noise(Vector((math.cos(turn) * 2.0, math.sin(turn) * 2.0, t * 9.0)))
            ring.append(bm.verts.new((math.cos(turn) * wide * lump, y + math.sin(turn) * wide * 0.8 * lump, z)))

        rings.append(ring)

    for k in range(count - 1):
        for j in range(around):
            n = (j + 1) % around
            bm.faces.new((rings[k][j], rings[k][n], rings[k + 1][n], rings[k + 1][j]))

    bm.faces.new(rings[0])
    bm.faces.new(rings[-1][::-1])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.normal_update()
    layer = bm.loops.layers.color.new("Color")

    for f in bm.faces:
        for loop in f.loops:
            # Black at the front, in the mouth; a dark dried brown behind and along it.
            c = loop.vert.co
            back = smooth(0.25, -0.4, loop.vert.normal.y)
            low = smooth(-0.13, -0.2, c.z)
            tone = mix(INK, mix(INK, LEATHER_DARK, 0.25 + 0.75 * math.sin(c.z * 110.0 + c.x * 40.0) ** 2), max(back, low))
            loop[layer] = paint_value(tone)

    mesh = bpy.data.meshes.new("Gullet")
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new("Gullet", mesh)
    bpy.context.collection.objects.link(obj)
    mesh.color_attributes.active_color_index = 0
    mesh.color_attributes.render_color_index = 0

    for polygon in mesh.polygons:
        polygon.use_smooth = True

    return obj


def build_tongue(hinge):
    """Dried to a strap on the floor of the jaw, black at its root, curled up at its tip. The
    jaw's child, about the hinge. No seeing through the mouth from the side, either."""
    bm = bmesh.new()
    rings = []
    count = 9
    around = 8

    for k in range(count):
        t = k / (count - 1)
        y = TONGUE_BACK + (TONGUE_TIP - TONGUE_BACK) * t
        wide = TONGUE_WIDE * (1.0 - t * t * 0.72) * math.sin(min(t * 6.0 + 0.2, 1.0) * math.pi * 0.5)
        high = TONGUE_HIGH * (1.0 - t * 0.55)
        floor_z = TONGUE_FLOOR + 0.03 * t * t + 0.004 * math.sin(t * 9.0)
        ring = []

        for j in range(around):
            turn = j * math.tau / around
            ring.append(bm.verts.new((math.cos(turn) * wide, y, floor_z + (math.sin(turn) * 0.5 + 0.5) * high)))

        rings.append(ring)

    for k in range(count - 1):
        for j in range(around):
            n = (j + 1) % around
            bm.faces.new((rings[k][j], rings[k][n], rings[k + 1][n], rings[k + 1][j]))

    bm.faces.new(rings[0])
    bm.faces.new(rings[-1][::-1])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    layer = bm.loops.layers.color.new("Color")

    for f in bm.faces:
        for loop in f.loops:
            c = loop.vert.co
            along = (c.y - TONGUE_BACK) / (TONGUE_TIP - TONGUE_BACK)
            furrow = smooth(0.003, 0.012, abs(c.x))
            tone = mix(INK, mix(LEATHER_DARK, SINEW, furrow), smooth(0.1, 0.7, along))
            loop[layer] = paint_value(tone)

    for v in bm.verts:
        v.co -= hinge

    mesh = bpy.data.meshes.new("Tongue")
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new("Tongue", mesh)
    bpy.context.collection.objects.link(obj)
    mesh.color_attributes.active_color_index = 0
    mesh.color_attributes.render_color_index = 0

    for polygon in mesh.polygons:
        polygon.use_smooth = True

    return obj


def mark_sinews(skull, jaw, hinge):
    """Where each sinew has hold, on the cheek and on the jaw, on their surfaces."""
    for obj, name, z, wide in ((skull, "SinewUp", -0.082, 0.07), (jaw, "SinewLow", -0.135, 0.056)):
        bm = bmesh.new()
        bm.from_mesh(obj.data)
        tree = BVHTree.FromBMesh(bm)

        for side, side_name in ((-1.0, "L"), (1.0, "R")):
            for n, y in enumerate(SINEW_AT):
                near = tree.find_nearest(Vector((side * wide, y, z - n * 0.004 * side)))
                marker = bpy.data.objects.new("%s_%s%d" % (name, side_name, n), None)
                bpy.context.collection.objects.link(marker)
                marker.location = near[0] - (hinge if obj is jaw else Vector())
                marker.parent = obj

        bm.free()


def build():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.wm.obj_import(filepath=SKULL)
    source = [o for o in bpy.context.scene.objects if o.type == "MESH"][0]
    source.data.materials.clear()
    parts = [p for p in loose(source) if len(p.data.polygons) > 0]
    parts.sort(key=lambda o: len(o.data.vertices), reverse=True)
    big = parts[:2]
    big.sort(key=lambda o: max(v.z for v in world_verts(o)), reverse=True)
    cranium, mandible = big
    # Fitted: facing +Y, HEIGHT tall, the whole of it round the origin.
    everything = [cranium, mandible] + parts[2:]

    for obj in everything:
        obj.data.transform(obj.matrix_world)
        obj.matrix_world = Matrix.Identity(4)

    vs = world_verts(cranium) + world_verts(mandible)
    lo = Vector((min(v.x for v in vs), min(v.y for v in vs), min(v.z for v in vs)))
    hi = Vector((max(v.x for v in vs), max(v.y for v in vs), max(v.z for v in vs)))
    chin_y = min(world_verts(mandible), key=lambda v: v.z).y
    turn = 1.0 if chin_y > (lo.y + hi.y) * 0.5 else -1.0
    size = HEIGHT / (hi.z - lo.z)
    fit = Matrix.Diagonal((turn * size, turn * size, size, 1.0)) @ Matrix.Translation(-(lo + hi) * 0.5)

    for obj in everything:
        obj.data.transform(fit)
        obj.data.update()

    upper, lower = [], []

    # A tooth's open end is at its root: above its middle, it is an upper one.
    for tooth in parts[2:]:
        bm = bmesh.new()
        bm.from_mesh(tooth.data)
        open_ends = [v.co.copy() for v in bm.verts if any(len(e.link_faces) == 1 for e in v.link_edges)]
        middle = sum((v.co for v in bm.verts), Vector()) / max(len(bm.verts), 1)
        open_at = sum(open_ends, Vector()) / max(len(open_ends), 1)
        bm.free()
        (upper if open_at.z > middle.z else lower).append(tooth)

    if len(upper) != 16 or len(lower) != 16:
        raise RuntimeError("teeth came apart as %d upper, %d lower" % (len(upper), len(lower)))

    jvs = world_verts(mandible)
    top = max(v.z for v in jvs)
    span = top - min(v.z for v in jvs)
    rami = [v for v in jvs if v.z >= top - 0.12 * span]
    hinge = Vector((0.0, sum(v.y for v in rami) / len(rami), top))

    dry_skull(cranium)
    dry_jaw(mandible, hinge)
    upper = dry_teeth(upper, "upper", hinge)
    lower = dry_teeth(lower, "lower", hinge)
    skull = join("Skull", [cranium] + upper)
    jaw = join("Jaw", [mandible] + lower)
    paint(skull, False, hinge)
    paint(jaw, True, hinge)
    jaw.data.transform(Matrix.Translation(-hinge))
    jaw.location = hinge
    jaw.parent = skull
    bpy.context.view_layer.update()
    mark_sinews(skull, jaw, hinge)
    sinew = build_sinew()
    gullet = build_gullet()
    gullet.parent = skull
    tongue = build_tongue(hinge)
    tongue.parent = jaw
    print("HINGE", tuple(round(x, 4) for x in hinge), "TRIS", sum(len(p.vertices) - 2 for p in skull.data.polygons), sum(len(p.vertices) - 2 for p in jaw.data.polygons))
    return skull, jaw, sinew, [gullet, tongue]


def previews(skull, jaw, sinew, inside):
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

    for obj in inside:
        obj.data.materials.append(look)

    sinew.hide_render = True
    sun = bpy.data.objects.new("Sun", bpy.data.lights.new("Sun", "SUN"))
    sun.data.energy = 4.0
    sun.rotation_euler = (math.radians(65), math.radians(10), 0.0)
    bpy.context.collection.objects.link(sun)
    camera = bpy.data.objects.new("Camera", bpy.data.cameras.new("Camera"))
    camera.data.lens = 70
    bpy.context.collection.objects.link(camera)
    scene.camera = camera
    # Its jaw drops: the front of it goes down.
    views = (("front", (0.0, 0.85, -0.05), -0.05, 0.0), ("three", (0.5, 0.65, 0.05), -0.05, 0.0), ("side", (0.85, 0.0, -0.05), -0.05, 0.0), ("gape", (0.0, 0.7, -0.08), -0.08, 0.62), ("gape_three", (0.35, 0.55, -0.02), -0.06, 0.62), ("close", (0.17, 0.42, -0.01), -0.02, 0.2))

    for name, at, look_z, drop in views:
        jaw.rotation_euler.x = -drop
        camera.location = at
        camera.rotation_euler = (Vector((0.0, 0.02, look_z)) - camera.location).to_track_quat("-Z", "Y").to_euler()
        scene.render.filepath = os.path.join(SOURCE, "anima_face_%s.png" % name)
        bpy.ops.render.render(write_still=True)

    jaw.rotation_euler.x = 0.0
    sinew.hide_render = False
    skull.data.materials.clear()
    jaw.data.materials.clear()

    for obj in inside:
        obj.data.materials.clear()


def main():
    skull, jaw, sinew, inside = build()
    previews(skull, jaw, sinew, inside)
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(SOURCE, "anima_face.blend"))
    bpy.ops.export_scene.gltf(filepath=GLB, export_format="GLB", export_yup=True, export_materials="NONE", export_normals=True, export_apply=False, export_vertex_color="ACTIVE", export_all_vertex_colors=False)
    print("WROTE", GLB)


main()
