"""The Metro Underground's tiled floor (docs/superpowers/refs/underground/recipe.md), laid
in modules the bay (maps/underground_lab.gd) sets edge to edge: thick tiles in a
chequer of cream and terracotta on a grout bed, so the grout lines are deep and
gather grime; a row of dark border tiles along the wall; worn modules where tiles
have sunk, cracked or been patched with cement; a drain grate set flush with the
floor where the wall's water runs.

Each module runs 1.2 m along x and its depth along y from 0, the wall's side at
+y; its tiles' tops at z = 0.

    Blender -b --factory-startup --python tools/eclipse/underground_floor.py
"""

import math
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import common  # noqa: E402
import underground_shapes  # noqa: E402
from underground_shapes import box, smooth_object  # noqa: E402

NAME = "underground_floor"
ATLAS = 2048
SLOTS = ["tile_cream", "tile_terra", "tile_dark", "grout", "cement", "steel", "soot_black"]

rng = random.Random(1975)

TILE = 0.3              # the tiles' pitch
GROUT = 0.01            # the joint between them
TILE_T = 0.06           # a tile's thickness, standing on the grout bed
BED_T = 0.06
MODULE = 1.2            # along x, and the depth of a full module
EDGE_DEPTH = 0.9        # the narrow module that finishes a row against a wall
# How far a tile has settled at most: dropped (m) and tipped (degrees).
SETTLE = (0.0015, 0.35)
# The drain's hole in a border module: x from, x to; y from, y to.
DRAIN = ((0.3, 0.9), (0.3, 0.9))
FRAME = 0.03
BAR_W, BAR_PITCH = 0.015, 0.04
SUMP = 0.25
SUMP_WALL = 0.045


def _tile(m, i, j, slot, drop=0.0, tip=(0.0, 0.0), split=None):
    """The tile at column i, row j: settled a little (dropped and tipped so no
    corner stands above the floor); `split` cracks it in two at that x across it,
    the second piece sunk."""
    x0, y0 = i * TILE + GROUT / 2, j * TILE + GROUT / 2
    x1, y1 = x0 + TILE - GROUT, y0 + TILE - GROUT
    half = (TILE - GROUT) / 2
    ax, ay = math.radians(tip[0]), math.radians(tip[1])
    rise = half * (abs(math.sin(ax)) + abs(math.sin(ay)))
    z = -(drop + rise)

    if split is None:
        box(m, (x0, y0, z - TILE_T), (x1, y1, z), slot, r=0.006, turn=(ax, ay, 0.0))
        return

    cut = x0 + split
    box(m, (x0, y0, z - TILE_T), (cut - 0.004, y1, z), slot, r=0.006, turn=(ax, ay, 0.0))
    sunk = 0.007
    box(m, (cut + 0.004, y0, z - sunk - TILE_T), (x1, y1, z - sunk), slot, r=0.006)


def _settled():
    return rng.uniform(0.0, SETTLE[0]), (rng.uniform(-SETTLE[1], SETTLE[1]), rng.uniform(-SETTLE[1], SETTLE[1]))


def _bed(m, depth, hole=None):
    """The grout bed under the tiles, leaving `hole` ((x0, x1), (y0, y1)) open."""
    lo, hi = -TILE_T - BED_T, -TILE_T

    if hole is None:
        box(m, (0.0, 0.0, lo), (MODULE, depth, hi), "grout", r=0.0)
        return

    (x0, x1), (y0, y1) = hole
    box(m, (0.0, 0.0, lo), (MODULE, y0, hi), "grout", r=0.0)
    box(m, (0.0, y1, lo), (MODULE, depth, hi), "grout", r=0.0)
    box(m, (0.0, y0, lo), (x0, y1, hi), "grout", r=0.0)
    box(m, (x1, y0, lo), (MODULE, y1, hi), "grout", r=0.0)


def _module(m, rows, border, worn=False, hole=None):
    """A module of 4 columns by `rows`, its last row the wall's dark border if `border`."""
    depth = rows * TILE
    _bed(m, depth, hole)
    cracked, sunk, patched = ((1, 2), (2, 1), (3, 3)) if worn else (None, None, None)

    for i in range(4):
        for j in range(rows):
            centre = ((i + 0.5) * TILE, (j + 0.5) * TILE)

            if hole and hole[0][0] < centre[0] < hole[0][1] and hole[1][0] < centre[1] < hole[1][1]:
                continue

            slot = "tile_dark" if border and j == rows - 1 else ("tile_cream" if (i + j) % 2 else "tile_terra")
            drop, tip = _settled()

            if (i, j) == cracked:
                _tile(m, i, j, slot, drop, tip, split=0.12)
            elif (i, j) == sunk:
                _tile(m, i, j, slot, 0.008, (0.8, -0.4))
            elif (i, j) == patched:
                _tile(m, i, j, "cement", 0.0015, (0.0, 0.0))
            else:
                _tile(m, i, j, slot, drop, tip)

    if hole:
        _drain(m, hole)


def _drain(m, hole):
    """A cast grate in its frame, its bars' tops flush with the floor, a dark sump under it."""
    (x0, x1), (y0, y1) = hole
    f = FRAME
    box(m, (x0, y0, -TILE_T), (x1, y0 + f, 0.0), "steel", r=0.0)
    box(m, (x0, y1 - f, -TILE_T), (x1, y1, 0.0), "steel", r=0.0)
    box(m, (x0, y0 + f, -TILE_T), (x0 + f, y1 - f, 0.0), "steel", r=0.0)
    box(m, (x1 - f, y0 + f, -TILE_T), (x1, y1 - f, 0.0), "steel", r=0.0)
    # The bars evenly across, the outermost a clear 3 cm (the gate's gap) from the frame's faces.
    first, last = y0 + f + 0.03 - BAR_W, y1 - f - 0.03
    count = int((last - first) / BAR_PITCH) + 1
    start = first + (last - first - (count - 1) * BAR_PITCH) / 2

    for k in range(count):
        y = start + k * BAR_PITCH
        box(m, (x0 + f, y, -0.035), (x1 - f, y + BAR_W, 0.0), "steel", r=0.0)

    # The sump: its walls under the frame (thick enough to stand clear of the bed's edges),
    # its floor deep in the dark.
    lo, w = -SUMP, SUMP_WALL
    box(m, (x0, y0, lo), (x1, y0 + w, -TILE_T), "soot_black", r=0.0)
    box(m, (x0, y1 - w, lo), (x1, y1, -TILE_T), "soot_black", r=0.0)
    box(m, (x0, y0 + w, lo), (x0 + w, y1 - w, -TILE_T), "soot_black", r=0.0)
    box(m, (x1 - w, y0 + w, lo), (x1, y1 - w, -TILE_T), "soot_black", r=0.0)
    box(m, (x0 + w, y0 + w, lo), (x1 - w, y1 - w, lo + 0.04), "soot_black", r=0.0)


def floor_field(m):
    """The open floor: the chequer, each tile settled its own way."""
    _module(m, 4, False)


def floor_field_worn(m):
    """Where the floor has taken its years: a tile sunk, one cracked in two, one gone
    and patched with cement."""
    _module(m, 4, False, worn=True)


def floor_border(m):
    """The row along a wall, its wall-side tiles dark."""
    _module(m, 4, True)


def floor_border_drain(m):
    """The row along a wall where the wall's water runs: a drain set flush in it."""
    _module(m, 4, True, hole=DRAIN)


def floor_edge(m):
    """The narrow row that finishes the floor against the far wall."""
    _module(m, round(EDGE_DEPTH / TILE), True)


PIECES = [floor_field, floor_field_worn, floor_border, floor_border_drain, floor_edge]


def build():
    common.reset()
    underground_shapes.rng = rng
    rng.seed(1975)

    for f in PIECES:
        smooth_object(f.__name__, f)


def main():
    build()
    common.export_piece(NAME, ATLAS, SLOTS, out=common.ROOT / "assets" / "eclipse" / "kit", sets_each=True, budget=4200)


if __name__ == "__main__":
    main()
