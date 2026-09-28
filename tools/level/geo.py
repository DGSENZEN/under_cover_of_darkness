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


class Box:
    """An oriented box: centre, basis (rows are... columns are its axes),
    half extents."""

    def __init__(self, centre, basis, size, surface=""):
        self.centre = list(centre)
        self.basis = basis
        self.half = [abs(s) / 2.0 for s in size]
        self.surface = surface

    def axes(self):
        return [[self.basis[r][c] for r in range(3)] for c in range(3)]

    def local(self, point):
        d = sub(point, self.centre)
        return [dot(d, a) for a in self.axes()]

    def contains(self, point, margin=0.0):
        return all(abs(c) <= h - margin for c, h in zip(self.local(point), self.half))

    def ray(self, origin, direction):
        """The distance along a ray (origin, unit direction) to where it enters
        the box, or None."""
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


def piece_boxes(recipe, position, basis, which="cols"):
    """A placed piece's colliders (or visual boxes) as world Boxes."""
    out = []

    for b in recipe[which]:
        local_rot = rotation(b[7] if len(b) > 7 else 0.0, b[8] if len(b) > 8 else 0.0, b[9] if len(b) > 9 else 0.0)
        centre = add(position, apply(basis, b[0:3]))
        out.append(Box(centre, mul(basis, local_rot), b[3:6], b[6] if len(b) > 6 else ""))

    return out
