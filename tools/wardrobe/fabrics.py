"""What each fabric looks like, painted texel by texel (bake.py).

Blender bakes, for every texel of a part, where on him it is (3D position),
which way it faces, which fabric and colour it is; this paints the fabric's
pattern from those, in numpy: quilting lines, wool's slub, leather's
grain, mail's rings, iron's mottle. Positions use |x|, so his mirrored halves
(which share texels) paint alike.

No Blender here: plain numpy, so a pattern can be tuned by running this
alone on a saved bake.
"""

import numpy as np

# The order of recipes.FABRICS.
SKIN, QUILTED, WOOL, LEATHER, MAIL, IRON = range(6)


def _hash(ix, iy, iz, seed):
    """A repeatable random value in 0..1 for each integer lattice point."""
    h = (ix * 73856093) ^ (iy * 19349663) ^ (iz * 83492791) ^ (seed * 2654435761)
    h = (h ^ (h >> 13)) * 1274126177
    return ((h ^ (h >> 16)) & 0xFFFF) / 65535.0


def noise(points, scale, seed=0):
    """Smooth value noise in 0..1 at `points` (N x 3, metres), features about
    1/scale metres across."""
    p = points * scale
    i = np.floor(p).astype(np.int64)
    f = p - i
    f = f * f * (3.0 - 2.0 * f)
    out = np.zeros(len(points))

    for dx in (0, 1):
        for dy in (0, 1):
            for dz in (0, 1):
                w = (f[:, 0] if dx else 1 - f[:, 0]) * (f[:, 1] if dy else 1 - f[:, 1]) * (f[:, 2] if dz else 1 - f[:, 2])
                out += w * _hash(i[:, 0] + dx, i[:, 1] + dy, i[:, 2] + dz, seed)

    return out


def fbm(points, scale, seed=0, octaves=3):
    total, weight, amount = np.zeros(len(points)), 0.0, 1.0

    for o in range(octaves):
        total += amount * noise(points, scale * (2 ** o), seed + o)
        weight += amount
        amount *= 0.5

    return total / weight


def mirrored(points):
    """His left and right alike (the halves share texels)."""
    out = points.copy()
    out[:, 0] = np.abs(out[:, 0])
    return out


def lines(a, period, width):
    """1 on thin lines every `period` along `a`, 0 between."""
    d = np.abs(((a / period) + 0.5) % 1.0 - 0.5) * period
    return np.clip(1.0 - d / width, 0.0, 1.0)


def paint(fabric, points, normals, base):
    """Each texel's colour (N x 3, linear) before any light: `base` (the
    garment's colour, linear) worked into its fabric's pattern."""
    p = mirrored(points)
    shade = np.ones(len(points))

    quilted = fabric == QUILTED
    if quilted.any():
        # Diamond quilting: stitched lines crossing on the diagonal, across
        # the front and back (x) or round the sides (y).
        q = p[quilted]
        n = normals[quilted]
        across = np.where(np.abs(n[:, 0]) > np.abs(n[:, 1]), q[:, 1], q[:, 0])
        stitch = np.maximum(lines(across + q[:, 2], 0.045, 0.004), lines(-across + q[:, 2], 0.045, 0.004))
        puff = 0.92 + 0.1 * noise(q, 90.0, 11)
        shade[quilted] = puff * (1.0 - 0.28 * stitch)

    wool = fabric == WOOL
    if wool.any():
        w = p[wool]
        shade[wool] = 0.9 + 0.14 * fbm(w, 40.0, 21) + 0.04 * (noise(w * np.array([1.0, 1.0, 6.0]), 60.0, 22) - 0.5)

    leather = fabric == LEATHER
    if leather.any():
        l = p[leather]
        shade[leather] = 0.84 + 0.22 * fbm(l, 22.0, 31) - 0.08 * (noise(l, 140.0, 32) > 0.72)

    mail = fabric == MAIL
    if mail.any():
        m = p[mail]
        rings = lines(m[:, 2] * 1.0, 0.009, 0.0022) + lines(m[:, 0] + m[:, 1] * 0.5 + m[:, 2] * 0.5, 0.009, 0.0022)
        shade[mail] = 0.78 + 0.34 * np.clip(rings, 0, 1) * (0.7 + 0.3 * noise(m, 200.0, 41)) - 0.1 * noise(m, 30.0, 42)

    iron = fabric == IRON
    if iron.any():
        shade[iron] = 0.86 + 0.18 * fbm(p[iron], 16.0, 51)

    return base * shade[:, None]
