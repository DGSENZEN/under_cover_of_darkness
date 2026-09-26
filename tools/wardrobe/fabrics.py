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


# Rust's colour, linear (sRGB 0.27, 0.14, 0.07).
RUST = np.array([0.0595, 0.0176, 0.0060])


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
        # Rows of rings big enough to read at 128 px (a PS2 mail texture is
        # bright ring tops over dark gaps, not true-size links).
        m = p[mail]
        rows = lines(m[:, 2], 0.016, 0.004)
        rings = lines(m[:, 0] + m[:, 1] + 0.5 * m[:, 2], 0.016, 0.004)
        shade[mail] = 0.55 + 0.75 * np.clip(rings + rows, 0, 1) * (0.7 + 0.3 * noise(m, 200.0, 41)) - 0.1 * noise(m, 30.0, 42)

    iron = fabric == IRON
    if iron.any():
        # Painted metal (the PS2 had no specular): lighter where it faces
        # the sky, dark round the sides and beneath; hammered blotches; a
        # few bright scratches. Bright edges and rivets are the build's trim
        # (bake.trim). Tuned by eye: a strong shine banded the old hat and
        # made it the brightest thing on him.
        q = p[iron]
        up = normals[iron][:, 2]
        sky = 0.65 + 0.85 * np.clip(0.5 + 0.5 * up, 0.0, 1.0) ** 3
        hammered = 0.85 + 0.3 * fbm(q, 28.0, 51)
        scratched = lines(q[:, 0] * 0.8 + q[:, 2] * 0.6 + 0.01 * noise(q, 60.0, 52), 0.011, 0.0009) * (noise(q, 14.0, 53) > 0.6)
        shade[iron] = sky * hammered * (1.0 + 0.9 * scratched)

    out = base * shade[:, None]

    if iron.any():
        # Rust where water sits and runs: blotches on what faces sideways
        # and down, hardly any on a crown the rain washes. Dark and brown,
        # and never sky-lit (bright rust read as skin in daylight).
        q = p[iron]
        up = normals[iron][:, 2]
        rust = np.clip((noise(q, 38.0, 54) - 0.64) / 0.16, 0.0, 1.0) * (0.12 + 0.88 * (up < 0.45))
        red = RUST * np.minimum(shade[iron], 1.0)[:, None]
        out[iron] = out[iron] * (1.0 - 0.7 * rust[:, None]) + red * 0.7 * rust[:, None]

    return out
