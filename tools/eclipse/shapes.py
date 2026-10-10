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
