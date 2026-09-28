"""The level's shading, baked into its vertex colours the PS2 way (the
garrison spec, 6.1): a colour per corner of every face, multiplied into its
photo by the level's materials. Pure Python (export.py measures the
occlusion in Blender and calls colour()).

    ambient occlusion  measured: how shut in the corner is (0 open, 1 shut)
    grime              low blotches over everything, seeded by place
    damp               darker and greener at a wall's foot
    soot               above every flame (torches, braziers, hearths, fires),
                       darkest straight over it
    warm               a little amber near a flame
    cold               a little blue on faces the moon looks at

The real lights stay the only light: this only darkens and tints (within
FLOOR..CEILING), so the lightgem and the guards agree with what is seen.
"""

import math

FLOOR = 0.3
CEILING = 1.1
# How much a fully shut corner is darkened.
AO_STRENGTH = 0.6
# Grime: blotches this big (m), this deep.
GRIME_SIZE = 2.3
GRIME_DEPTH = 0.18
# Damp: up to this high on the wall (m), this dark at the foot, this green.
DAMP_HIGH = 0.9
DAMP_DARK = 0.35
DAMP_TINT = (0.86, 1.0, 0.88)
# Soot: from these flames, a plume this wide (m) rising this high.
SOOTY = ("torch", "brazier", "hearth", "fire", "lamp_post")
SOOT_WIDTH = 0.55
SOOT_HEIGHT = 2.2
SOOT_DARK = 0.6
# Warmth near a flame (within WARM_REACH), the moon's cold on the faces it
# looks at.
WARM_REACH = 3.0
WARM_TINT = (1.08, 1.0, 0.86)
COLD_TINT = (0.9, 0.96, 1.08)
MOON_TOWARD = (0.62, -0.5, 0.6)


def colour(point, normal, occlusion, flames, seed_free=False):
    """The shade at `point` on a face looking along `normal`, shut in by
    `occlusion` (0..1), near `flames` ([{"kind", "position"}]); `seed_free`
    leaves the grime out (the tests)."""
    x, y, z = point
    c = [1.0, 1.0, 1.0]
    k = 1.0 - AO_STRENGTH * max(0.0, min(1.0, occlusion))

    if not seed_free:
        k *= 1.0 - GRIME_DEPTH * _blotch(x / GRIME_SIZE, y / GRIME_SIZE, z / GRIME_SIZE)

    # Damp creeps up a wall's foot (faces standing, near the ground).
    if abs(normal[1]) < 0.5 and y < DAMP_HIGH:
        wet = 1.0 - max(0.0, y) / DAMP_HIGH
        k *= 1.0 - DAMP_DARK * wet
        c = [c[i] * (1.0 + (DAMP_TINT[i] - 1.0) * wet) for i in range(3)]

    for flame in flames:
        if flame.get("kind") not in SOOTY:
            continue

        fx, fy, fz = flame["position"]
        across = math.hypot(x - fx, z - fz)
        above = y - fy

        if 0.0 < above < SOOT_HEIGHT:
            k *= 1.0 - SOOT_DARK * math.exp(-(across * across) / (SOOT_WIDTH * SOOT_WIDTH)) * (1.0 - above / SOOT_HEIGHT)

        near = math.dist((x, y, z), (fx, fy, fz))

        if near < WARM_REACH:
            warmth = 1.0 - near / WARM_REACH
            c = [c[i] * (1.0 + (WARM_TINT[i] - 1.0) * warmth) for i in range(3)]

    toward = -(normal[0] * MOON_TOWARD[0] + normal[1] * MOON_TOWARD[1] + normal[2] * MOON_TOWARD[2]) / _length(MOON_TOWARD)

    if toward > 0.0:
        c = [c[i] * (1.0 + (COLD_TINT[i] - 1.0) * toward) for i in range(3)]

    return tuple(max(FLOOR, min(CEILING, v * k)) for v in c)


def _length(v):
    return math.sqrt(sum(a * a for a in v))


def _blotch(x, y, z):
    """Smooth value noise, 0..1, the same for the same place."""
    ix, iy, iz = math.floor(x), math.floor(y), math.floor(z)
    fx, fy, fz = x - ix, y - iy, z - iz
    sx, sy, sz = fx * fx * (3 - 2 * fx), fy * fy * (3 - 2 * fy), fz * fz * (3 - 2 * fz)
    total = 0.0

    for dx in (0, 1):
        for dy in (0, 1):
            for dz in (0, 1):
                weight = (sx if dx else 1 - sx) * (sy if dy else 1 - sy) * (sz if dz else 1 - sz)
                total += weight * _hash(ix + dx, iy + dy, iz + dz)

    return total


def _hash(x, y, z):
    h = (x * 73856093) ^ (y * 19349663) ^ (z * 83492791)
    h = (h ^ (h >> 13)) * 1274126177
    return ((h ^ (h >> 16)) & 0xFFFF) / 65535.0
