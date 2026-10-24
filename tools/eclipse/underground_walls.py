"""The Metro Underground's tiled walls (docs/superpowers/refs/underground/recipe.md): cream
subway tile in running bond on its mortar, a dark skirting, the line's colour in a band
of tile, a capping course and plaster above it to the vault; panels where the years
show (tiles fallen, others replaced with whatever was to hand); one where the tiles have
come away from older stone behind them, the city the Metro was dug through, a carved
block in it (its glyph is the user's); and a station's name tablet framed in mosaic
(its name is the user's).

Panels run 1.2 m along x, from the wall's face (y = 0) out to the tiles' face
(y = -FACE), floor (z = 0) to vault; the bay (maps/underground_lab.gd) sets the wall
itself back behind them, so whatever hangs on the wall hangs on the tiles.

    Blender -b --factory-startup --python tools/eclipse/underground_walls.py
"""

import math
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import common  # noqa: E402
import underground_shapes  # noqa: E402
from underground_shapes import box, smooth_object  # noqa: E402

NAME = "underground_walls"
ATLAS = 2048
SLOTS = ["tile_wall", "tile_dark", "tile_line", "tile_odd", "mortar", "plaster", "stone_old", "glyph_blank", "sign"]

rng = random.Random(1969)

PANEL = 1.2
HEIGHT = 4.0
MORTAR = 0.032          # the mortar bed on the wall (thick enough that the tiles' backs stand over 3 cm off its back)
TILE_T = 0.035          # the tiles standing on it
FACE = MORTAR + TILE_T  # the tiles' face off the wall
JOINT = 0.008
# The courses, bottom up: (from, to, tile height, tile width, slot).
SKIRTING = 0.3
BAND = (1.3, 1.5)
CAP = (2.3, 2.42)
COURSES = ([(0.15 * k, 0.15 * (k + 1), 0.3, "tile_dark") for k in range(2)]
           + [(SKIRTING + 0.1 * k, SKIRTING + 0.1 * (k + 1), 0.2, "tile_wall") for k in range(10)]
           + [(BAND[0] + 0.1 * k, BAND[0] + 0.1 * (k + 1), 0.2, "tile_line") for k in range(2)]
           + [(BAND[1] + 0.1 * k, BAND[1] + 0.1 * (k + 1), 0.2, "tile_wall") for k in range(8)]
           + [(CAP[0], CAP[1], 0.2, "tile_wall")])
# The opening where the old stone shows (x from, to; z from, to), and the ragged
# loss of tiles round it (an ellipse's middle and radii, roughened).
CRACK = ((0.36, 0.84), (0.1, 0.82))
LOSS = ((0.6, 0.47), (0.4, 0.52))


def _courses():
    """Every tile's place: (x0, x1, z0, z1, slot, course), in running bond, each
    course's ends meeting the panel's with half a joint."""
    places = []

    for k, (z0, z1, width, slot) in enumerate(COURSES):
        edges = [0.0]
        x = width / 2 if k % 2 else width

        while x < PANEL - 1e-6:
            edges.append(x)
            x += width

        edges.append(PANEL)

        for a, b in zip(edges, edges[1:]):
            places.append((a + JOINT / 2, b - JOINT / 2, z0 + JOINT / 2, z1 - JOINT / 2, slot, k))

    return places


def _plate(m, hole=None):
    """The mortar bed up to the cap, plaster above it, leaving `hole` open."""
    if hole is None:
        box(m, (0.0, -MORTAR, 0.0), (PANEL, 0.0, CAP[1]), "mortar", r=0.0)
    else:
        (x0, x1), (z0, z1) = hole
        box(m, (0.0, -MORTAR, 0.0), (x0, 0.0, CAP[1]), "mortar", r=0.0)
        box(m, (x1, -MORTAR, 0.0), (PANEL, 0.0, CAP[1]), "mortar", r=0.0)
        box(m, (x0, -MORTAR, 0.0), (x1, 0.0, z0), "mortar", r=0.0)
        box(m, (x0, -MORTAR, z1), (x1, 0.0, CAP[1]), "mortar", r=0.0)

    box(m, (0.0, -MORTAR, CAP[1]), (PANEL, 0.0, HEIGHT), "plaster", r=0.0)


def _tile(m, x0, x1, z0, z1, slot):
    box(m, (x0, -FACE, z0), (x1, -MORTAR, z1), slot, r=0.0)


def wall_tiled(m):
    """The plain run of wall."""
    _plate(m)

    for x0, x1, z0, z1, slot, _ in _courses():
        _tile(m, x0, x1, z0, z1, slot)


def wall_tiled_worn(m):
    """Where the years show: tiles fallen to the mortar, others replaced with
    whatever tiles were to hand, one cracked across."""
    _plate(m)
    places = _courses()
    field = [i for i, p in enumerate(places) if p[4] == "tile_wall" and p[5] < len(COURSES) - 1]
    rng.shuffle(field)
    fallen, odd, cracked = set(field[:7]), set(field[7:12]), field[12]

    for i, (x0, x1, z0, z1, slot, _) in enumerate(places):
        if i in fallen:
            continue
        if i == cracked:
            cut = x0 + (x1 - x0) * 0.4
            _tile(m, x0, cut - 0.002, z0, z1, slot)
            _tile(m, cut + 0.002, x1, z0, z1, slot)
            continue
        _tile(m, x0, x1, z0, z1, "tile_odd" if i in odd else slot)


def wall_crack(m):
    """The tiles come away from the stone behind them: a ragged loss down to the mortar,
    and in it the dressed blocks of the older city, one carved."""
    (cx0, cx1), (cz0, cz1) = CRACK
    _plate(m, hole=CRACK)
    (ex, ez), (rx, rz) = LOSS

    for x0, x1, z0, z1, slot, _ in _courses():
        overlaps = x0 < cx1 and x1 > cx0 and z0 < cz1 and z1 > cz0
        mx, mz = (x0 + x1) / 2, (z0 + z1) / 2
        rough = 1.0 + 0.18 * math.sin(mx * 23.0 + mz * 11.0) + 0.1 * math.sin(mz * 37.0)
        lost = ((mx - ex) / rx) ** 2 + ((mz - ez) / rz) ** 2 < rough

        if not (overlaps or lost):
            _tile(m, x0, x1, z0, z1, slot)

    # The old stone: dressed blocks in courses, their joints open, one block carved and proud.
    rows = [(cz0, 0.35), (0.35, 0.6), (0.6, cz1)]
    splits = [(cx0, 0.55, cx1), (cx0, 0.48, 0.72, cx1), (cx0, 0.63, cx1)]
    gap = 0.012

    for (z0, z1), xs in zip(rows, splits):
        for a, b in zip(xs, xs[1:]):
            carved = z0 == 0.35 and abs((a + b) / 2 - 0.6) < 0.01
            front = -0.042 if carved else -0.03
            box(m, (a + gap / 2, front, z0 + gap / 2), (b - gap / 2, 0.0, z1 - gap / 2),
                "glyph_blank" if carved else "stone_old", r=0.0)


def name_tablet(m):
    """A station's name in a mosaic frame: small tiles round a field (left plain: the
    name is the user's), on a dark back, set on the wall's tiles (y = 0 its back)."""
    w, h, t = 1.0, 0.35, 0.05
    box(m, (0.0, -MORTAR, 0.0), (w, 0.0, h), "tile_dark", r=0.0)
    front = -MORTAR - TILE_T
    box(m, (t, front, t), (w - t, -MORTAR, h - t), "sign", r=0.0)
    k = 0
    x = 0.0

    while x < w - 1e-6:
        for z0 in (0.0, h - t):
            box(m, (x + JOINT / 2, front, z0 + JOINT / 2), (x + t - JOINT / 2, -MORTAR, z0 + t - JOINT / 2),
                "tile_line" if k % 2 else "tile_wall", r=0.0)
            k += 1
        x += t

    z = t
    while z < h - t - 1e-6:
        for x0 in (0.0, w - t):
            box(m, (x0 + JOINT / 2, front, z + JOINT / 2), (x0 + t - JOINT / 2, -MORTAR, z + t - JOINT / 2),
                "tile_line" if k % 2 else "tile_wall", r=0.0)
            k += 1
        z += t


PIECES = [wall_tiled, wall_tiled_worn, wall_crack, name_tablet]


def build():
    common.reset()
    underground_shapes.rng = rng
    rng.seed(1969)

    for f in PIECES:
        smooth_object(f.__name__, f)


def main():
    build()
    common.export_piece(NAME, ATLAS, SLOTS, out=common.ROOT / "assets" / "eclipse" / "kit", sets_each=True, budget=5200)


if __name__ == "__main__":
    main()
