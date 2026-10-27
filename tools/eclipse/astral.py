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
from underground_shapes import box, pipe, smooth_object, turned  # noqa: E402

NAME = "astral"
ATLAS = 2048
SLOTS = ["stone", "stone_old", "iron", "wood", "brass", "cloth"]

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


# --- the city's fragments, drifting in the void (drawn in its ink: their shapes count, not their paint) ----------

def arch(m):
    """An arch torn from a street: its two piers, its ring of voussoirs, its keystone; the left pier broken short."""
    for x, top in ((-1.45, 2.2), (1.45, 2.9)):
        box(m, (x - 0.28, -0.28, 0.0), (x + 0.28, 0.28, top), "stone_old", r=0.02)
    ring = [(1.45 * math.cos(a), 0.0, 2.9 + 1.45 * math.sin(a)) for a in [math.pi * k / 16 for k in range(17)]]
    pipe(m, ring, 0.24, 4, "stone")
    box(m, (-0.18, -0.3, 4.2), (0.18, 0.3, 4.62), "stone_old", r=0.02)


def stairs(m):
    """A run of a stair's steps on their stringer, broken off at both ends."""
    for k in range(8):
        width = 1.6 - (0.5 if k in (0, 7) else 0.0)
        box(m, (-width / 2, k * 0.3, k * 0.18), (width / 2, k * 0.3 + 0.34, k * 0.18 + 0.18), "stone", r=0.0)
    pipe(m, [(0.85, -0.1, -0.15), (0.85, 2.5, 1.35)], 0.07, 4, "iron")


def doorway(m):
    """A doorway, its frame and lintel, its door ajar on its hinges, its knocker."""
    for x in (-0.62, 0.62):
        box(m, (x - 0.12, -0.12, 0.0), (x + 0.12, 0.12, 2.3), "wood", r=0.0)
    box(m, (-0.74, -0.14, 2.3), (0.74, 0.14, 2.52), "wood", r=0.0)
    # (Its door swung half open from its left jamb.)
    swing = math.radians(38.0)
    w = 1.0
    cx, cy = -0.5 + w / 2 * math.cos(swing), w / 2 * math.sin(swing)
    box(m, (cx - w / 2, cy - 0.035, 0.05), (cx + w / 2, cy + 0.035, 2.25), "wood", r=0.0, turn=(0.0, 0.0, swing))
    turned(m, [(0.06, -0.01), (0.06, 0.03)], 8, "iron",
           at=(cx + 0.3 * math.cos(swing), cy + 0.3 * math.sin(swing) - 0.07, 1.2), lean=math.pi / 2,
           towards=swing - math.pi / 2)


def lamp_post(m):
    """A street's lamp post: its foot, its post, its arm, its lantern."""
    turned(m, [(0.22, 0.0), (0.2, 0.25), (0.1, 0.4)], 8, "iron")
    pipe(m, [(0.0, 0.0, 0.35), (0.0, 0.0, 3.2)], 0.07, 8, "iron")
    pipe(m, [(0.0, 0.0, 3.0), (0.45, 0.0, 3.25), (0.75, 0.0, 3.2)], 0.035, 6, "iron")
    turned(m, [(0.06, 2.75), (0.18, 2.85), (0.16, 3.1), (0.05, 3.18)], 6, "brass", at=(0.75, 0.0, 0.0))


def bell(m):
    """A chapel's bell on its yoke, its clapper hanging."""
    turned(m, [(0.62, -0.95), (0.58, -0.85), (0.4, -0.45), (0.34, -0.1), (0.22, 0.0)], 14, "brass")
    box(m, (-0.55, -0.12, 0.0), (0.55, 0.12, 0.22), "wood", r=0.0)
    pipe(m, [(0.0, 0.0, -0.1), (0.0, 0.0, -0.76)], 0.035, 6, "iron")
    turned(m, [(0.06, -0.88), (0.09, -0.8), (0.05, -0.74)], 8, "iron")


def tile_slab(m):
    """A slab of the Pasaje's chequered tiles coming apart: its tiles lifting off one another, turned a little."""
    for i in range(3):
        for j in range(3):
            lift = 0.06 * (i + j) + 0.04 * ((i * 7 + j * 3) % 4)
            turn = (0.06 * (i - 1), 0.05 * (j - 1), 0.1 * ((i + 2 * j) % 3 - 1))
            x, y = (i - 1) * 0.66, (j - 1) * 0.66
            box(m, (x - 0.3, y - 0.3, lift), (x + 0.3, y + 0.3, lift + 0.1), "stone" if (i + j) % 2 else "stone_old",
                r=0.0, turn=turn)


def stall_frame(m):
    """A market stall's frame, its cover torn away but a flap: four pipe posts, its rails, the flap hanging."""
    for x in (-0.95, 0.95):
        for y in (0.0, 1.3):
            pipe(m, [(x, y, 0.0), (x, y, 2.3 if y < 0.5 else 2.0)], 0.03, 6, "iron")
        pipe(m, [(x, 0.0, 2.3), (x, 1.3, 2.0)], 0.03, 6, "iron")
    for y, z in ((0.0, 2.3), (1.3, 2.0)):
        pipe(m, [(-0.95, y, z), (0.95, y, z)], 0.03, 6, "iron")
    box(m, (-0.9, 1.26, 1.3), (-0.2, 1.3, 1.94), "cloth", r=0.0)


FRAGMENTS = {"arch": arch, "stairs": stairs, "doorway": doorway, "lamp_post": lamp_post, "bell": bell,
             "tile_slab": tile_slab, "stall_frame": stall_frame}

PIECES = [(n, _stone(*STONES[n])) for n in STONES] + list(FRAGMENTS.items())
BUDGET = {name: 2000 for name, _ in PIECES}
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
