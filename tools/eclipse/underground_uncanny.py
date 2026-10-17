"""The Metro Underground's uncanny (docs/superpowers/refs/underground/supernatural_refs.md):
the nahual, the old man who sits on the bench every night become an enormous black dog,
lying beside it with its head up; and the old man's palm hat, left on the bench by his paper.

The dog lies along +X (its head that way), on the floor (z = 0). Its head is its own object,
its origin the neck (NECK on the body) so the bay can turn it to watch; its snout along +X.
Mignola's way: one black shape with nothing drawn inside it but two ember eyes.

    Blender -b --factory-startup --python tools/eclipse/underground_uncanny.py
"""

import math
import os
import random
import sys

from mathutils import Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import common  # noqa: E402
import underground_shapes  # noqa: E402
from underground_shapes import pipe, smooth_object, turned  # noqa: E402

NAME = "underground_uncanny"
ATLAS = 1024
SLOTS = ["nahual_black", "ember", "palm"]

rng = random.Random(1521)

# Where the head turns on the body: the top of the neck.
NECK = (0.88, 0.0, 0.64)
SIDES = 10


def loft(m, spine, slot, sides=SIDES):
    """A closed solid lofted along `spine`: [(centre, (half width, half height))], each ring
    square to the spine, its width across (Y-ish), its height up (Z-ish); both ends capped."""
    m.shell()
    centres = [Vector(c) for c, _ in spine]
    rings = []

    for i, (c, (a, b)) in enumerate(spine):
        ahead = (centres[min(i + 1, len(centres) - 1)] - centres[max(i - 1, 0)]).normalized()
        side = ahead.cross(Vector((0.0, 0.0, 1.0)))
        side = side.normalized() if side.length > 1e-6 else Vector((0.0, 1.0, 0.0))
        up = side.cross(ahead).normalized()
        rings.append([tuple(centres[i] + side * (a * math.cos(2 * math.pi * k / sides))
                            + up * (b * math.sin(2 * math.pi * k / sides))) for k in range(sides)])

    m.face(rings[0], slot)

    for r0, r1 in zip(rings, rings[1:]):
        for k in range(sides):
            m.face([r0[(k + 1) % sides], r0[k], r1[k], r1[(k + 1) % sides]], slot)

    m.face(list(reversed(rings[-1])), slot)


def nahual_body(m):
    """The dog lying sphinx-like: a deep chest over its forelegs, a lean flank, its haunches
    folded, its tail curled round to its feet, the neck rising to its head."""
    b = "nahual_black"
    loft(m, [((0.0, 0.0, 0.2), (0.14, 0.18)), ((0.1, 0.0, 0.24), (0.21, 0.24)), ((0.34, 0.0, 0.22), (0.19, 0.22)),
             ((0.58, 0.0, 0.3), (0.2, 0.3)), ((0.76, 0.0, 0.38), (0.15, 0.25)), ((0.82, 0.0, 0.46), (0.11, 0.16))], b)
    # The neck, up and forward from the chest to the head.
    loft(m, [((0.7, 0.0, 0.46), (0.15, 0.16)), ((0.8, 0.0, 0.56), (0.14, 0.14)), (NECK, (0.12, 0.12))], b)

    for sy in (-1, 1):
        # A foreleg laid forward along the floor to its paw.
        loft(m, [((0.66, sy * 0.1, 0.2), (0.065, 0.075)), ((0.86, sy * 0.11, 0.08), (0.055, 0.055)),
                 ((1.06, sy * 0.11, 0.05), (0.045, 0.045))], b, sides=8)
        turned(m, [(0.03, 0.0), (0.06, 0.02), (0.055, 0.05), (0.03, 0.065)], 8, b, at=(1.08, sy * 0.11, 0.0))
        # A haunch folded, its foot forward beside the belly.
        loft(m, [((0.04, sy * 0.13, 0.22), (0.1, 0.13)), ((0.16, sy * 0.17, 0.14), (0.09, 0.1)),
                 ((0.2, sy * 0.18, 0.07), (0.06, 0.06))], b, sides=8)
        loft(m, [((0.14, sy * 0.19, 0.05), (0.045, 0.045)), ((0.34, sy * 0.2, 0.045), (0.04, 0.04))], b, sides=8)
        turned(m, [(0.025, 0.0), (0.05, 0.02), (0.045, 0.045), (0.025, 0.055)], 8, b, at=(0.36, sy * 0.2, 0.0))

    # The tail curled round to its hind feet.
    path = []
    for i in range(10):
        a = math.pi * i / 9
        path.append((-0.02 + 0.16 * math.sin(a) * -1 + 0.2 * (1 - math.cos(a)) * 0.6, -0.28 * math.sin(a / 2) - 0.02, 0.2 - 0.16 * (i / 9)))
    pipe(m, path, 0.035, 8, b)


def nahual_head(m):
    """Its head, from the neck: a long skull, the snout drawn out and down, tall ears laid back,
    and its two round ember eyes; nothing else drawn in it."""
    b = "nahual_black"
    loft(m, [((-0.1, 0.0, 0.0), (0.09, 0.1)), ((0.0, 0.0, 0.03), (0.12, 0.12)), ((0.12, 0.0, 0.02), (0.11, 0.1)),
             ((0.2, 0.0, -0.01), (0.075, 0.07))], b)
    loft(m, [((0.16, 0.0, -0.02), (0.08, 0.075)), ((0.26, 0.0, -0.045), (0.065, 0.06)), ((0.33, 0.0, -0.06), (0.052, 0.048))], b)
    turned(m, [(0.034, 0.0), (0.045, 0.022), (0.034, 0.044)], 8, b, at=(0.35, 0.0, -0.085))

    for sy in (-1, 1):
        # A tall ear, laid back: a thick triangle from the skull's crown.
        base, tip = (0.02, sy * 0.07, 0.1), (-0.07, sy * 0.1, 0.3)
        m.shell()
        t = 0.015
        a0 = (base[0] + 0.05, base[1] - t, base[2])
        a1 = (base[0] - 0.05, base[1] - t, base[2])
        a2 = (tip[0], tip[1] - t, tip[2])
        b0, b1, b2 = ((p[0], p[1] + 2 * t, p[2]) for p in (a0, a1, a2))
        m.face([a0, a1, a2], b)
        m.face([b2, b1, b0], b)
        for p, q, r, s in ((a0, b0, b1, a1), (a1, b1, b2, a2), (a2, b2, b0, a0)):
            m.face([p, q, r, s], b)
        # An eye: round, ember, standing out of the skull's side.
        # (Tipped to face out from its side and a little forward: lean pi/2 toward t points along
        # (sin t, -cos t).)
        turned(m, [(0.016, 0.0), (0.026, 0.012), (0.022, 0.026)], 8, "ember", at=(0.13, sy * 0.075, 0.035),
               lean=math.pi / 2, towards=(math.pi - 0.4) if sy > 0 else 0.4)


def old_hat(m):
    """The old man's palm hat, its brim gone soft, left on the bench."""
    turned(m, [(0.11, 0.0), (0.26, 0.006), (0.265, 0.022), (0.12, 0.03), (0.115, 0.1), (0.09, 0.14), (0.04, 0.155)],
           16, "palm", jitter=0.04)


PIECES = [nahual_body, nahual_head, old_hat]


def build():
    common.reset()
    underground_shapes.rng = rng
    rng.seed(1521)

    for f in PIECES:
        smooth_object(f.__name__, f)


def main():
    build()
    common.export_piece(NAME, ATLAS, SLOTS, out=common.ROOT / "assets" / "eclipse" / "kit", sets_each=True, budget=6000)


if __name__ == "__main__":
    main()
