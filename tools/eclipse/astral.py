"""The astral passages' kit (docs/superpowers/specs/2026-10-26-astral-passages-design.md; plan
docs/superpowers/plans/2026-10-26-astral-passages.md): what the walker crosses the void on and what drifts in it.

- way_stone_a, way_stone_b, way_stone_c: the way's floating stones, slabs of the Metro's floor torn loose, their tops
  flat (z 0, flush with the floor they were), their edges broken, their undersides crumbled into hanging rubble.

Every piece in its own frame: its middle at the origin, z up.

    Blender -b --factory-startup --python tools/eclipse/astral.py
"""

import math
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import common  # noqa: E402
import underground_shapes  # noqa: E402
from underground_shapes import smooth_object, turned  # noqa: E402

NAME = "astral"
ATLAS = 2048
SLOTS = ["stone", "stone_old"]

rng = random.Random(1937)

# The stones: [name, its radius (m: the walked top's), how many sides its broken edge has, how deep it hangs].
STONES = {"way_stone_a": (0.86, 9, 0.45), "way_stone_b": (0.8, 8, 0.38), "way_stone_c": (0.92, 10, 0.52)}


def _stone(radius, sides, deep):
    def made(m):
        # The slab: its top flat at z 0, its edge broken (jittered), narrowing under it to its crumbled foot.
        turned(m, [(radius * 0.55, -deep), (radius * 0.82, -deep * 0.55), (radius * 0.98, -0.12), (radius, -0.03),
                   (radius * 0.97, 0.0)], sides, "stone_old", jitter=0.06)
        # Rubble hanging under it, broken off and caught in the void.
        for k in range(4):
            a = 2 * math.pi * k / 4 + rng.uniform(-0.4, 0.4)
            r = radius * rng.uniform(0.15, 0.4)
            z = -deep - rng.uniform(0.05, 0.3)
            size = rng.uniform(0.06, 0.12)
            turned(m, [(size * 0.5, -size), (size, -size * 0.4), (size * 0.6, 0.0)], 5, "stone",
                   at=(r * math.cos(a), r * math.sin(a), z), jitter=0.15, twist=rng.uniform(0, 1))
    return made


PIECES = [(n, _stone(*STONES[n])) for n in STONES]
BUDGET = {name: 1500 for name, _ in PIECES}
SLIVER = {name: 0.004 for name in BUDGET}


def build():
    common.reset()
    underground_shapes.rng = rng
    rng.seed(1937)
    for name, f in PIECES:
        smooth_object(name, f)


def main():
    build()
    common.export_piece(NAME, ATLAS, SLOTS, out=common.ROOT / "assets" / "eclipse" / "kit", sets_each=True,
                        budget=max(BUDGET.values()), sliver=min(SLIVER.values()))


if __name__ == "__main__":
    main()
