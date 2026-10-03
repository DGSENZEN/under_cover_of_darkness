"""A built thing swept along a line (a causeway, a bridge's deck): a section
across it carried from station to station, mitred at each bend (so its
faces meet there with no gap and no overlap), into one mesh laid as terrain
(terrain.mesh: its collider exactly what is drawn). Built up face by face
in a Mesh, which other builders (a bridge's arches) add to.

A section is [(s, y, slot)]: s across the line (to the left of the way
along it), y up; each point's slot is the face's from it to the next. It
runs up its right side, over and down its left (so a face looks out to the
left of its run in (s, y)); a None slot draws nothing to the next."""

import math

import terrain


class Mesh:
    def __init__(self):
        self.verts, self.faces, self.slots = [], [], []

    def face(self, points, toward, slot):
        """A flat face through `points` (3 or more, in order round it,
        convex), looking along `toward`."""
        base = len(self.verts)
        self.verts.extend([[float(c) for c in p] for p in points])

        for k in range(1, len(points) - 1):
            ids = [base, base + k, base + k + 1]

            if terrain._area(*(self.verts[i] for i in ids)) > 1e-6:
                self.faces.append(terrain._facing(self.verts, ids, toward))
                self.slots.append(slot)

    def polygon(self, outline, place, toward, slot):
        """A flat face through a simple polygon `outline` [(u, v)] in its
        own plane, each point put in the world by place(u, v): cut into
        triangles (its ears), looking along `toward`."""
        for tri in triangulate(outline):
            self.face([place(*outline[k]) for k in tri], toward, slot)

    def strip(self, a, b, toward, slot):
        """Faces between two rows of points (as long), each quad looking
        along toward(k) (or `toward`)."""
        for k in range(len(a) - 1):
            look = toward(k) if callable(toward) else toward
            self.face([a[k], a[k + 1], b[k + 1], b[k]], look, slot)

    def data(self, name, sector, surface="stone", tint=None, occluder=False):
        return terrain.mesh(name, sector, self.verts, self.faces, self.slots, surface=surface, tint=tint, occluder=occluder)


def unit(dx, dz):
    length = math.hypot(dx, dz)
    return dx / length, dz / length


def left(d):
    """To the left of a way along d (x, z)."""
    return d[1], -d[0]


def mitred(path):
    """Stations along a polyline [(x, z)]: [(x, z, across, along)], across
    the vector a point s across the line is put along (the bend's mitre,
    long enough that each side stays parallel to the line), along the way
    on from it."""
    out = []

    for k, p in enumerate(path):
        d_in = unit(p[0] - path[k - 1][0], p[1] - path[k - 1][1]) if k > 0 else None
        d_out = unit(path[k + 1][0] - p[0], path[k + 1][1] - p[1]) if k + 1 < len(path) else None
        l_in = left(d_in) if d_in else None
        l_out = left(d_out) if d_out else None

        if l_in and l_out:
            m = unit(l_in[0] + l_out[0], l_in[1] + l_out[1])
            scale = 1.0 / (m[0] * l_in[0] + m[1] * l_in[1])
            across = (m[0] * scale, m[1] * scale)
        else:
            across = l_out or l_in

        out.append((p[0], p[1], across, d_out or d_in))

    return out


def outward(s0, y0, s1, y1):
    """A section face from point 0 to point 1 looks out to its run's left
    (s, y)."""
    ds, dy = s1 - s0, y1 - y0
    length = math.hypot(ds, dy)
    return -dy / length, ds / length


def sweep(mesh, section, stations, start=True, end=True):
    """The section carried through `stations` (mitred()): its faces, and
    its ends closed (unless start/end False: another part meets it there)."""
    def at(st, s, y):
        return [st[0] + st[2][0] * s, y, st[1] + st[2][1] * s]

    for i in range(len(section) - 1):
        s0, y0, slot = section[i]
        s1, y1, _ = section[i + 1]

        if slot is None:
            continue

        out = outward(s0, y0, s1, y1)
        a = [at(st, s0, y0) for st in stations]
        b = [at(st, s1, y1) for st in stations]

        def toward(k, out=out):
            # (The section's left, turned to the world by the stretch's own
            # way along.)
            d = stations[k][3]
            l = left(d)
            return [l[0] * out[0], out[1], l[1] * out[0]]

        mesh.strip(a, b, toward, slot)

    outline = [(s, y) for s, y, _ in section]

    for st, ok, sign in ((stations[0], start, -1.0), (stations[-1], end, 1.0)):
        if ok:
            mesh.polygon(outline, lambda s, y, st=st: at(st, s, y), [st[3][0] * sign, 0.0, st[3][1] * sign], section[0][2] or "granite")


def triangulate(polygon):
    """A simple polygon's triangles (indices), by clipping its ears."""
    area = sum(polygon[k][0] * polygon[(k + 1) % len(polygon)][1] - polygon[(k + 1) % len(polygon)][0] * polygon[k][1]
               for k in range(len(polygon)))
    order = list(range(len(polygon))) if area > 0.0 else list(reversed(range(len(polygon))))
    # (Points repeated in a row add nothing.)
    order = [k for n, k in enumerate(order) if n == 0 or polygon[k] != polygon[order[n - 1]]]
    out = []

    def convex(a, b, c):
        return (b[0] - a[0]) * (c[1] - a[1]) - (b[1] - a[1]) * (c[0] - a[0]) > 1e-9

    def holds(a, b, c, p):
        return convex(a, b, p) and convex(b, c, p) and convex(c, a, p)

    while len(order) > 3:
        for k in range(len(order)):
            i, j, m = order[k - 1], order[k], order[(k + 1) % len(order)]
            a, b, c = polygon[i], polygon[j], polygon[m]

            if not convex(a, b, c):
                continue

            if any(holds(a, b, c, polygon[q]) for q in order if q not in (i, j, m) and polygon[q] not in (a, b, c)):
                continue

            out.append([i, j, m])
            order.pop(k)
            break
        else:
            raise ValueError("sweep: a section that will not triangulate")

    out.append(order)
    return out
