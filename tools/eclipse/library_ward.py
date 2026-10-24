"""The librarian's ward candles (docs/superpowers/specs/2026-10-17-librarian-shop-design.md, "The ward"; Part 2 Task
8): five stubs set on his chalk circle round the desk, burnt down to different heights, their wax run down their sides
and pooled on the boards. One object, ward_candles; each stub's wick is a wick (common.WICKS), where the bay stands its
flame (the corridor's candle, Vfx "candles").

The frame: the corner's (tools/eclipse/library_corner.py), the desk's middle at the origin on the floor, the
customers' side toward -y (Godot's +z). The bay sets it at the corner's place.

    Blender -b --factory-startup --python tools/eclipse/library_ward.py
"""

import math
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import common  # noqa: E402
import underground_shapes  # noqa: E402
from underground_shapes import pipe, smooth_object, turned  # noqa: E402

NAME = "library_ward"
ATLAS = 512
SLOTS = ["wax_white"]
BUDGET = 3000
# A stub's lip and its wax's runs are a few millimetres across by nature: a face is a sliver under 4 mm (the gate's
# 1 cm is for building-sized pieces; the wax is one colour, so a thin face costs its painter nothing).
SLIVER = 0.004

rng = random.Random(1904)

# The chalk circle's outer ring (m; library_lab.gd's WARD_RADIUS) the stubs stand on; where round it each stands
# (degrees from the customers' side round toward +x, Godot's way, clear of the salt's opening, the coat stand, his
# chair and the chained book's rest), its radius and how far it has burnt down (its height).
RADIUS = 1.18
STUBS = [(50.0, 0.03, 0.075), (84.0, 0.026, 0.115), (140.0, 0.032, 0.055), (218.0, 0.028, 0.095), (305.0, 0.025, 0.065)]


def _stub(m, x, y, r, h):
    """One stub: its wax pooled round its foot, its side a little uneven, its top melted into a cup under a lip, two
    or three runs down from the lip; its wick's place over the cup."""
    # (One solid from the pool's edge up to the cup: a stub stood in a separate pool layers their feet.)
    pool = r * rng.uniform(1.8, 2.2)
    turned(m, [(pool, 0.0), (pool * 0.86, 0.006), (r * 1.06, 0.01), (r, 0.016), (r * 1.02, h * 0.5), (r, h - 0.012),
               (r * 1.07, h - 0.002), (r * 0.62, h - 0.008)], 10, "wax_white", at=(x, y, 0.0), jitter=0.06,
           twist=rng.uniform(0, 1))

    for _ in range(rng.choice([2, 3])):
        a = rng.uniform(0, 2 * math.pi)
        run = rng.uniform(h * 0.35, h * 0.6)
        out = r * 1.02

        def at(d, z):
            return (x + (out + d) * math.cos(a), y + (out + d) * math.sin(a), z)

        pipe(m, [at(0.0015, h - 0.004), at(0.0025, h - 0.004 - run * 0.5), at(0.002, h - 0.004 - run)], 0.0045, 5,
             "wax_white")

    m.wick((x, y, h - 0.008 + 0.01))


def ward_candles(m):
    """The five stubs round the ward."""
    for heading, r, h in STUBS:
        a = math.radians(heading)
        # (Godot's x is Blender's x, its z Blender's -y.)
        _stub(m, RADIUS * math.sin(a), -RADIUS * math.cos(a), r, h)


def build():
    common.reset()
    underground_shapes.rng = rng
    rng.seed(1904)
    smooth_object("ward_candles", ward_candles)


def main():
    build()
    common.export_piece(NAME, ATLAS, SLOTS, out=common.ROOT / "assets" / "eclipse" / "kit", sets_each=True,
                        budget=BUDGET, sliver=SLIVER)


if __name__ == "__main__":
    main()
