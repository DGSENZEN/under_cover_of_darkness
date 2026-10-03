"""Small geometry for the level tools, in Godot's axes (x right, y up, z
toward you); pure Python, no Blender.

A basis is a 3x3 row-major list of lists (rows); a rotation from yaw
(about y), pitch (about x) and roll (about z), degrees, composes as Godot's
default Euler order YXZ: R = Ry(yaw) Rx(pitch) Rz(roll).
"""

import math

IDENTITY = [[1.0, 0.0, 0.0], [0.0, 1.0, 0.0], [0.0, 0.0, 1.0]]
# Godot -> Blender: (x, y, z) -> (x, -z, y).
TO_BLENDER = [[1.0, 0.0, 0.0], [0.0, 0.0, -1.0], [0.0, 1.0, 0.0]]


def mul(a, b):
    return [[sum(a[i][k] * b[k][j] for k in range(3)) for j in range(3)] for i in range(3)]


def apply(m, v):
    return [sum(m[i][k] * v[k] for k in range(3)) for i in range(3)]


def transpose(m):
    return [[m[j][i] for j in range(3)] for i in range(3)]


def add(a, b):
    return [a[i] + b[i] for i in range(3)]


def sub(a, b):
    return [a[i] - b[i] for i in range(3)]


def dot(a, b):
    return sum(a[i] * b[i] for i in range(3))


def rotation(yaw=0.0, pitch=0.0, roll=0.0):
    """Return a Godot YXZ basis (3x3 rows); yaw/pitch/roll are degrees."""
    y, p, r = (math.radians(a) for a in (yaw, pitch, roll))
    ry = [[math.cos(y), 0.0, math.sin(y)], [0.0, 1.0, 0.0], [-math.sin(y), 0.0, math.cos(y)]]
    rx = [[1.0, 0.0, 0.0], [0.0, math.cos(p), -math.sin(p)], [0.0, math.sin(p), math.cos(p)]]
    rz = [[math.cos(r), -math.sin(r), 0.0], [math.sin(r), math.cos(r), 0.0], [0.0, 0.0, 1.0]]
    return mul(mul(ry, rx), rz)


def to_blender_basis(basis):
    return mul(mul(TO_BLENDER, basis), transpose(TO_BLENDER))


def from_blender_basis(basis):
    return mul(mul(transpose(TO_BLENDER), basis), TO_BLENDER)


def to_blender(v):
    return apply(TO_BLENDER, v)


def from_blender(v):
    return apply(transpose(TO_BLENDER), v)


def facing_up(tri):
    """How much a triangle (three world vectors) faces the sky: its normal's
    y by the right-hand rule ((b - a) x (c - a)), its corners counter-
    clockwise seen from the side it faces; > 0 faces up, < 0 down."""
    (ax, ay, az), (bx, by, bz), (cx, cy, cz) = tri[0], tri[1], tri[2]
    return (bz - az) * (cx - ax) - (bx - ax) * (cz - az)


class Box:
    """Oriented box in Godot metres; row-major basis columns are its axes."""

    def __init__(self, centre, basis, size, surface=""):
        """centre/size: three-vectors; basis: 3x3 rows; surface: string.

        Copy centre, retain basis, store abs(size)/2 half-extents. occluder
        starts True; callers may exclude collision-only proxies.
        """
        self.centre = list(centre)
        self.basis = basis
        self.half = [abs(s) / 2.0 for s in size]
        self.surface = surface
        # Collision may fill an opening that visual occlusion must leave clear.
        self.occluder = True

    def axes(self):
        """Return three basis columns as new world-axis vector lists."""
        return [[self.basis[r][c] for r in range(3)] for c in range(3)]

    def local(self, point):
        """Return box-relative axis coordinates for a world three-vector."""
        d = sub(point, self.centre)
        return [dot(d, a) for a in self.axes()]

    def contains(self, point, margin=0.0):
        """Return bool for world point; positive margin shrinks bounds in metres."""
        return all(abs(c) <= h - margin for c, h in zip(self.local(point), self.half))

    def ray(self, origin, direction):
        """Return float entrance distance, or None when the ray misses.

        origin is a world three-vector; direction must be a unit three-vector.
        Distances are metres; a ray starting inside returns 0.0. No mutation.
        """
        o = self.local(origin)
        d = [dot(direction, a) for a in self.axes()]
        near, far = -math.inf, math.inf

        for i in range(3):
            if abs(d[i]) < 1e-9:
                if abs(o[i]) > self.half[i]:
                    return None
                continue

            t1 = (-self.half[i] - o[i]) / d[i]
            t2 = (self.half[i] - o[i]) / d[i]
            near = max(near, min(t1, t2))
            far = min(far, max(t1, t2))

        if near > far or far < 0.0:
            return None

        return max(near, 0.0)


class TriGrid:
    """Triangles (a terrain's) bucketed on a grid over x and z, for straight
    up and down rays: where one crosses a triangle, the triangle's plane
    gives the height (a vertical face is crossed edge-on, never hit) and its
    winding which way it faces (facing_up)."""

    def __init__(self, triangles, cell=4.0):
        """Bucket triangles (three world vectors each); cell is positive metres.

        Vertical/degenerate xz projections are skipped; vertices remain shared.
        """
        self.cell = cell
        self.cells = {}

        for tri in triangles:
            (ax, ay, az), (bx, by, bz), (cx, cy, cz) = tri
            area = (bx - ax) * (cz - az) - (bz - az) * (cx - ax)

            if abs(area) < 1e-9:
                continue

            for i in range(int(math.floor(min(ax, bx, cx) / cell)), int(math.floor(max(ax, bx, cx) / cell)) + 1):
                for k in range(int(math.floor(min(az, bz, cz) / cell)), int(math.floor(max(az, bz, cz) / cell)) + 1):
                    self.cells.setdefault((i, k), []).append((tri, area))

    def hits(self, x, z):
        """Return unsorted list[(float, bool)]: the world heights the
        vertical line at x/z metres crosses, each with whether that face
        faces up (its area's sign: facing_up is minus it)."""
        out = []

        for tri, area in self.cells.get((int(math.floor(x / self.cell)), int(math.floor(z / self.cell))), []):
            (ax, ay, az), (bx, by, bz), (cx, cy, cz) = tri
            u = ((bx - x) * (cz - z) - (bz - z) * (cx - x)) / area
            v = ((cx - x) * (az - z) - (cz - z) * (ax - x)) / area
            w = 1.0 - u - v

            if u >= -1e-9 and v >= -1e-9 and w >= -1e-9:
                out.append((u * ay + v * by + w * cy, area < 0.0))

        return out

    def heights(self, x, z):
        """Return unsorted list[float] world heights intersecting x/z metres."""
        return [y for y, _up in self.hits(x, z)]

    def under(self, point):
        """Whether `point` (a world three-vector) is under the ground: the
        first face over it, however high, faces up (its top). Under a face
        that faces down at it (a cave's roof, an overhang) it is not."""
        above = [(y, up) for y, up in self.hits(point[0], point[2]) if y >= point[1] - 1e-6]
        return bool(above) and min(above)[1]

    def down(self, point, reach):
        """Return nearest downward float distance, or None within reach metres.

        point is a world three-vector; near-zero hits clamp to 0.0.
        """
        below = [point[1] - y for y in self.heights(point[0], point[2]) if -1e-6 <= point[1] - y <= reach]
        return max(0.0, min(below)) if below else None

    def up(self, point, reach):
        """Return nearest upward float distance, or None within reach metres.

        point is a world three-vector; near-zero hits clamp to 0.0.
        """
        above = [y - point[1] for y in self.heights(point[0], point[2]) if -1e-6 <= y - point[1] <= reach]
        return max(0.0, min(above)) if above else None


def piece_boxes(recipe, position, basis, which="cols"):
    """Return list[Box] transformed into Godot world space from recipe[which].

    recipe is a kit dict; position is a three-vector and basis 3x3 rows.
    which selects 'cols' collision or 'boxes' visual proxies. Collision boxes
    indexed by occlusion_exclude retain collision but cannot occlude.
    """
    out = []

    for index, b in enumerate(recipe[which]):
        local_rot = rotation(b[7] if len(b) > 7 else 0.0, b[8] if len(b) > 8 else 0.0, b[9] if len(b) > 9 else 0.0)
        centre = add(position, apply(basis, b[0:3]))
        box = Box(centre, mul(basis, local_rot), b[3:6], b[6] if len(b) > 6 else "")
        if which == "cols":
            box.occluder = index not in recipe.get("occlusion_exclude", [])
        out.append(box)

    return out
