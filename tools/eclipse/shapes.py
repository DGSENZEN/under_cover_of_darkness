"""Closed shapes for kit pieces (inside Blender), added to a common.Mesh
made with outward=True: lofts of a cross-section through a row of rings,
and boxes with their top edges bevelled.
"""

import bmesh
from mathutils import Matrix, Vector


def _area(points):
    n = Vector((0.0, 0.0, 0.0))

    for a, b in zip(points, points[1:] + points[:1]):
        n += Vector(a).cross(Vector(b))

    return n.length / 2


def loft(m, rings, slots, caps=True, cap_slot=None, fan=False):
    """A solid through `rings` (each a closed loop of 3D points, the same
    count, corresponding): a face per loop edge between each ring and the
    next (`slots`: one slot, or one per loop edge), and the end rings
    capped (`fan`: each cap a fan of triangles from the middle of its box,
    for a ring with points in a line, whose one polygon would triangulate
    into slivers). Faces that collapse to nothing are left out; a quad with
    one collapsed side becomes a triangle."""
    n = len(rings[0])
    edge_slot = slots if isinstance(slots, (list, tuple)) else [slots] * n

    for a, b in zip(rings, rings[1:]):
        for j in range(n):
            k = (j + 1) % n
            quad = [tuple(a[j]), tuple(a[k]), tuple(b[k]), tuple(b[j])]
            kept = [p for i, p in enumerate(quad) if (Vector(p) - Vector(quad[i - 1])).length > 1e-7]

            if len(kept) >= 3 and _area(kept) > 1e-9:
                m.face(kept, edge_slot[j])

    if caps:
        for ring in (rings[0], rings[-1]):
            if not fan:
                m.face([tuple(p) for p in ring], cap_slot or edge_slot[0])
                continue

            middle = tuple((min(p[k] for p in ring) + max(p[k] for p in ring)) / 2 for k in range(3))

            for j in range(n):
                tri = [middle, tuple(ring[j]), tuple(ring[(j + 1) % n])]

                if _area(tri) > 1e-9:
                    m.face(tri, cap_slot or edge_slot[0])


def loft_x(m, sections, slots, caps=True, cap_slot=None, fan=False):
    """loft() of (y, z) cross-sections stood along x: sections [(x, [(y, z)])]."""
    loft(m, [[(x, y, z) for y, z in profile] for x, profile in sections], slots, caps, cap_slot, fan)


def bevelled_box(m, lo, hi, slot_name, bevel, top_only=True):
    """A box from lo to hi with its top edges (or all) bevelled `bevel`."""
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    size = Vector(hi) - Vector(lo)
    centre = (Vector(hi) + Vector(lo)) / 2
    bmesh.ops.transform(bm, matrix=Matrix.Translation(centre) @ Matrix.Diagonal((*size, 1.0)), verts=bm.verts)
    edges = [e for e in bm.edges if not top_only or all(v.co.z > hi[2] - 1e-6 for v in e.verts)]
    bmesh.ops.bevel(bm, geom=edges + list({v for e in edges for v in e.verts}), offset=bevel, segments=1,
                    affect="EDGES", profile=0.5)

    for f in bm.faces:
        m.face([tuple(v.co) for v in f.verts], slot_name)

    bm.free()


def _fan(m, centre, ring, slot_name):
    """A cap of triangles from `centre` to each edge of `ring`."""
    n = len(ring)

    for j in range(n):
        tri = [tuple(centre), tuple(ring[j]), tuple(ring[(j + 1) % n])]

        if _area(tri) > 1e-9:
            m.face(tri, slot_name)


def lathe(m, profile, sides, slot_name, twist=0.0, at=(0.0, 0.0, 0.0)):
    """A closed solid turned about the Z axis (through `at`) from a profile
    [(r, z)] read from its bottom up: a point at r 0 closes it there, an end
    with r > 0 is capped flat."""
    import math

    ox, oy, oz = at
    rings = [[(ox + r * math.cos(twist + 2 * math.pi * k / sides), oy + r * math.sin(twist + 2 * math.pi * k / sides),
               oz + z) for k in range(sides)] for r, z in profile]
    loft(m, rings, slot_name, caps=False)

    for (r, z), ring in ((profile[0], rings[0]), (profile[-1], rings[-1])):
        if r > 1e-9:
            _fan(m, (ox, oy, oz + z), ring, slot_name)


def sag(m, a, b, radius, sides, drop, segments, slot_name):
    """A closed tube from a to b hanging `drop` at its middle (a parabola,
    as a wire or chain hangs), `sides` round, capped at both ends."""
    import math

    a, b = Vector(a), Vector(b)
    centres = []

    for k in range(segments + 1):
        t = k / segments
        centres.append(a.lerp(b, t) - Vector((0.0, 0.0, 4.0 * drop * t * (1.0 - t))))

    rings = []

    for k, c in enumerate(centres):
        ahead = centres[min(k + 1, segments)] - centres[max(k - 1, 0)]
        ahead.normalize()
        side = ahead.cross(Vector((0.0, 0.0, 1.0)))

        if side.length < 1e-6:
            side = Vector((1.0, 0.0, 0.0))

        side.normalize()
        up = side.cross(ahead).normalized()
        # A vertex straight down, so the tube's lowest point is radius under its line.
        rings.append([tuple(c + (side * math.sin(2 * math.pi * j / sides) - up * math.cos(2 * math.pi * j / sides)) * radius)
                      for j in range(sides)])

    # Each end one polygon: a fan's triangles on a wire this thin are slivers.
    loft(m, rings, slot_name, caps=True)


def panel(m, lo, hi, inset, frame_slot, face_slot):
    """A box from lo to hi whose front (-Y) face is a frame `inset` wide
    round a field in `face_slot` (a blank canvas), one closed solid."""
    x0, y0, z0 = lo
    x1, y1, z1 = hi
    o = [(x0, y0, z0), (x1, y0, z0), (x1, y0, z1), (x0, y0, z1)]
    i = [(x0 + inset, y0, z0 + inset), (x1 - inset, y0, z0 + inset), (x1 - inset, y0, z1 - inset), (x0 + inset, y0, z1 - inset)]

    for k in range(4):
        j = (k + 1) % 4
        m.face([o[k], o[j], i[j], i[k]], frame_slot)

    m.face(i, face_slot)
    m.box(lo, hi, frame_slot, skip=("-y",))


def disc(m, centre, radius, depth, sides, rim, rim_slot, face_slot):
    """A disc standing in an XZ plane, its back at centre's y, its front
    `depth` towards -Y: a rim `rim` wide round a field in `face_slot`."""
    import math

    cx, cy, cz = centre
    ring = lambda r, y: [(cx + r * math.cos(2 * math.pi * k / sides), y, cz + r * math.sin(2 * math.pi * k / sides))
                         for k in range(sides)]
    back, front, inner = ring(radius, cy), ring(radius, cy - depth), ring(radius - rim, cy - depth)
    loft(m, [back, front], rim_slot, caps=False)
    _fan(m, (cx, cy, cz), back, rim_slot)

    for k in range(sides):
        j = (k + 1) % sides
        m.face([front[k], front[j], inner[j], inner[k]], rim_slot)

    _fan(m, (cx, cy - depth, cz), inner, face_slot)


def obox(m, centre, size, rotation, slot_name):
    """A box `size` (x, y, z) about `centre`, turned by `rotation` (Euler
    radians, XYZ): a stone heaved askew, a frame leaning on a wall."""
    from mathutils import Euler

    r = Euler(rotation, "XYZ").to_matrix()
    c = Vector(centre)
    hx, hy, hz = (s / 2 for s in size)
    corner = lambda x, y, z: tuple(c + r @ Vector((x, y, z)))
    p = {(i, j, k): corner(i * hx, j * hy, k * hz) for i in (-1, 1) for j in (-1, 1) for k in (-1, 1)}
    quads = [[(-1, -1, -1), (-1, 1, -1), (-1, 1, 1), (-1, -1, 1)], [(1, -1, -1), (1, -1, 1), (1, 1, 1), (1, 1, -1)],
             [(-1, -1, -1), (-1, -1, 1), (1, -1, 1), (1, -1, -1)], [(-1, 1, -1), (1, 1, -1), (1, 1, 1), (-1, 1, 1)],
             [(-1, -1, -1), (1, -1, -1), (1, 1, -1), (-1, 1, -1)], [(-1, -1, 1), (-1, 1, 1), (1, 1, 1), (1, -1, 1)]]

    for q in quads:
        m.face([p[k] for k in q], slot_name)
