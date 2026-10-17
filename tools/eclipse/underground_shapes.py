"""Shapes for the Underground's kits, built to its recipe
(docs/superpowers/refs/underground/recipe.md): self-rounded boxes, turned
pieces with single-polygon ends, tubes, sheets, studs, smooth shading. Lifted
from the curandera's stall (tools/eclipse/stall.py) when the second kit
needed them. A piece sets `rng` to its own seeded Random before building, so
its jitter is its own.
"""

import math
import random

import bmesh
import bpy
from mathutils import Euler, Matrix, Vector

import common
import shapes

rng = random.Random(0)


def turned(m, profile, sides, slot, at=(0.0, 0.0, 0.0), twist=0.0, jitter=0.0, lean=0.0, towards=0.0):
    """A closed solid turned about Z through `at` from [(r, z)] (every r > 0;
    each end capped by one polygon, which the gate reads as one face, unlike
    a fan of thin triangles). `jitter` roughens the inner rings' radii; `lean`
    (radians) tips the whole about `at`, its far end swinging `towards` that
    heading."""
    m.shell()
    rings = []
    tip = Matrix.Rotation(towards, 3, "Z") @ Matrix.Rotation(lean, 3, "X") @ Matrix.Rotation(-towards, 3, "Z")

    for i, (r, z) in enumerate(profile):
        inner = 0 < i < len(profile) - 1
        ring = []

        for k in range(sides):
            a = twist + 2 * math.pi * k / sides
            rr = r * (1 + rng.uniform(-jitter, jitter)) if inner and jitter else r
            p = tip @ Vector((rr * math.cos(a), rr * math.sin(a), z))
            ring.append((at[0] + p.x, at[1] + p.y, at[2] + p.z))

        rings.append(ring)

    shapes.loft(m, rings, slot, caps=True)


def pipe(m, points, r, sides, slot, closed=False):
    """A tube along a polyline, its rings carried along without twisting;
    a closed loop joins its last ring to its first."""
    m.shell()
    pts = [Vector(p) for p in points]
    n = len(pts)

    def ahead(i):
        if closed:
            return (pts[(i + 1) % n] - pts[i - 1]).normalized()
        return (pts[min(i + 1, n - 1)] - pts[max(i - 1, 0)]).normalized()

    t = ahead(0)
    side = t.cross(Vector((0, 0, 1)) if abs(t.z) < 0.9 else Vector((1, 0, 0))).normalized()
    rings = []

    for i in range(n):
        t = ahead(i)
        side = (side - t * side.dot(t)).normalized()
        up = t.cross(side)
        rings.append([tuple(pts[i] + (side * math.cos(2 * math.pi * k / sides) + up * math.sin(2 * math.pi * k / sides)) * r)
                      for k in range(sides)])

    if closed:
        shapes.loft(m, rings + [rings[0]], slot, caps=False)
    else:
        shapes.loft(m, rings, slot, caps=True)


def slab(m, grid, offset, slot, slot_of=None):
    """A sheet given its thickness: `grid` rows of points for one face, the
    other `offset` away, the borders closed; `slot_of(i, j)` (if given) the
    slot of each cell's two faces (a patch sewn in)."""
    m.shell()
    rows, cols = len(grid), len(grid[0])
    a = [[tuple(p) for p in row] for row in grid]
    b = [[tuple(Vector(p) + Vector(offset)) for p in row] for row in grid]

    for i in range(rows - 1):
        for j in range(cols - 1):
            cell = slot_of(i, j) if slot_of else slot
            m.face([a[i][j], a[i][j + 1], a[i + 1][j + 1], a[i + 1][j]], cell)
            m.face([b[i][j], b[i + 1][j], b[i + 1][j + 1], b[i][j + 1]], cell)

    ring = ([(0, j) for j in range(cols - 1)] + [(i, cols - 1) for i in range(rows - 1)]
            + [(rows - 1, j) for j in range(cols - 1, 0, -1)] + [(i, 0) for i in range(rows - 1, 0, -1)])

    for p, q in zip(ring, ring[1:] + ring[:1]):
        m.face([a[p[0]][p[1]], a[q[0]][q[1]], b[q[0]][q[1]], b[p[0]][p[1]]], slot)


# A rounded edge's corner patch is about 0.6 of its radius thick (2 segments,
# measured): the least radius that keeps it over the gate's 1 cm sliver.
ROUND_LEAST = 0.0185


def box(m, lo, hi, slot, r=0.03, turn=None):
    """A box with every edge rounded `r` (2 segments), bevelled on its own
    so nothing near it pinches the bevel; never so far that the flat left
    between two roundings is under 1.2 cm. `turn` (Euler radians) tilts it
    about its centre.
    Too thin to round over the sliver gate, it stays square."""
    size = Vector(hi) - Vector(lo)
    # The flat left between two roundings must stay over the sliver too.
    r = min(r, 0.4 * min(size), (min(size) - 0.012) / 2)
    m.shell()

    if r < ROUND_LEAST:
        if turn:
            shapes.obox(m, tuple((Vector(hi) + Vector(lo)) / 2), tuple(size), turn, slot)
        else:
            m.box(lo, hi, slot)
        return

    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    centre = (Vector(hi) + Vector(lo)) / 2
    bmesh.ops.transform(bm, matrix=Matrix.Diagonal((*size, 1.0)), verts=bm.verts)
    bmesh.ops.bevel(bm, geom=list(bm.edges) + list(bm.verts), offset=r, segments=2, profile=0.5, affect="EDGES",
                    clamp_overlap=False)
    place = Matrix.Translation(centre) @ (Euler(turn, "XYZ").to_matrix().to_4x4() if turn else Matrix.Identity(4))
    bmesh.ops.transform(bm, matrix=place, verts=bm.verts)

    for f in bm.faces:
        m.face([tuple(v.co) for v in f.verts], slot)

    bm.free()


def bolt(m, x, y, z, r=0.026):
    """A hex bolt head with a pyramid crown, standing on a +Z face."""
    m.shell()
    shapes.lathe(m, [(r, 0.0), (r, 0.014), (0.0, 0.026)], 6, "steel", at=(x, y, z))


def stud(m, at, lean, towards, slot="steel", r=0.026):
    """A domed stud (nail head, rivet) on a face, tipped from +Z by `lean`
    towards the heading `towards` (radians)."""
    turned(m, [(r, 0.0), (r, 0.012), (r * 0.6, 0.024)], 6, slot, at=at, lean=lean, towards=towards)


def join(target, others):
    """Others' faces made part of `target` (its name and its materials kept)."""
    with bpy.context.temp_override(active_object=target, object=target,
                                   selected_editable_objects=[target, *others]):
        bpy.ops.object.join()
    return target


# Faces meeting harder than this stay sharp; softer, they shade smooth (a
# rounded edge's strips meet at 45 degrees, a turned piece's sides at 30-72).
SMOOTH_ANGLE = 50.0


def smooth_object(name, build):
    m = common.Mesh(name, outward=True)
    build(m)
    o = m.make()

    for poly in o.data.polygons:
        poly.use_smooth = True

    o.data.set_sharp_from_angle(angle=math.radians(SMOOTH_ANGLE))
    return o
