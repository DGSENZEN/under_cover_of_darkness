"""The Pasaje's overhead (docs/superpowers/specs/2026-10-26-pasaje-market-design.md; plan
docs/superpowers/plans/2026-10-26-pasaje-market.md, Task 6): what the market has hung over its street. Direction signs
on rods from the Company's girders, their faces blank both sides (the user's words); cables slung across from wall to
wall over the mains; strings of bare bulbs sagging between them; and at the stretch's south end the stallholders'
tarpaulin canopy, held up by ropes to the girders and the ceiling, with a pipe gantry of signs under it, so the view
down the street ends in the market.

Frames (Blender: the set's x, y = the set's -z, z up):
- sign_board_a, _b, _c: hung from their hanger bar at the origin (their pivot), the board below, its faces along the
  street;
- drop_rod: clamped to a girder's bottom flange at the origin, down to the sign's hook;
- cable_bundle, bulb_string: across the street at y = 0, at the heights they hang (set at the street's z);
- canopy, gantry: where they stand in the set (the gantry at y = 0, set at its z).

    Blender -b --factory-startup --python tools/eclipse/pasaje_overhead.py
"""

import math
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import common  # noqa: E402
import underground_shapes  # noqa: E402
from underground_shapes import box, pipe, smooth_object, stud, turned  # noqa: E402

NAME = "pasaje_overhead"
ATLAS = 2048
SLOTS = ["iron", "steel", "enamel", "sign", "rubber", "cloth_black", "cloth_blue", "cloth_patch", "brass", "glass_bulb",
         "burlap"]

rng = random.Random(1933)

# The set (maps/pasaje.gd, tools/eclipse/pasaje_shell.py): the walls' plaster above the tiles (|x|), the ceiling's
# underside, the girders' bottom, the stretch's south end (set z).
PLASTER = 4.668
CEILING = 4.46
GIRDER_FOOT = 4.18
SOUTH = 19.95
# The slung lines: where they leave the walls, how deep they sag.
SLUNG_AT = 4.3
CABLE_SAG = (0.5, 0.45, 0.56)
STRING_SAG = 0.55
BULB_EVERY = 0.8
# The signs: [width, height] of each board, the chains' length, the rod from a girder.
SIGNS = {"sign_board_a": (0.9, 0.32), "sign_board_b": (1.2, 0.28), "sign_board_c": (0.6, 0.45)}
CHAIN = 0.1
ROD = 0.75
BAR = 0.03
# The canopy: its edges at the walls (|x| CANOPY_X, CANOPY_EDGE high), its middle's sag, the lines it hangs from (set
# z) and its sag between them; the gantry under it (set z, its beam's height).
CANOPY_X = 4.55
CANOPY_EDGE = 3.18
CANOPY_MIDDLE = 3.1
CANOPY_LINES = (13.0, 16.0, SOUTH)
CANOPY_SAG = 0.08
CANOPY_T = 0.02
# Its valance and fringe: how far they hang (the fringe to 2.45 m over the walk), their flaps' width and gaps, how far
# out across the street they reach (short of the mains).
VALANCE = 0.28
FRINGE = 0.62
FLAP_W = 0.34
FLAP_GAP = 0.05
FLAP_X = 4.3
GANTRY_Z = 18.3
GANTRY_Y = 2.92


def _catenary(x, half, high, sag):
    """A slung line's height at `x` between walls at ±`half`, `high` there, `sag` lower in the middle."""
    return high - sag * (1.0 - (x / half) ** 2)


# --- the signs -----------------------------------------------------------------------------------

def _sign(width, height):
    def made(m):
        top = -CHAIN - BAR
        # The board, blank both faces, in its iron frame; the hanger bar and its two chains.
        box(m, (-width / 2, -0.015, top - height), (width / 2, 0.015, top), "sign", r=0.0)
        f = 0.035
        box(m, (-width / 2 - f, -f / 2, top - height - f), (width / 2 + f, f / 2, top - height), "iron", r=0.0)
        box(m, (-width / 2 - f, -f / 2, top), (width / 2 + f, f / 2, top + f), "iron", r=0.0)
        for x0, x1 in ((-width / 2 - f, -width / 2), (width / 2, width / 2 + f)):
            box(m, (x0, -f / 2, top - height), (x1, f / 2, top), "iron", r=0.0)
        pipe(m, [(-width / 2 + 0.06, 0.0, -0.012), (width / 2 - 0.06, 0.0, -0.012)], 0.012, 6, "steel")
        for x in (-width / 2 + 0.1, width / 2 - 0.1):
            pipe(m, [(x, 0.0, -0.02), (x, 0.0, top + f - 0.005)], 0.006, 4, "steel")
        if width < 0.7:
            # (The tall one wears a little hood against the drips.)
            box(m, (-width / 2 - 0.06, -0.06, top + f), (width / 2 + 0.06, 0.06, top + f + 0.035), "enamel", r=0.0)
    return made


def drop_rod(m):
    """A rod down from a girder's bottom flange, clamped to it, a ring at its foot for a sign's hook."""
    box(m, (-0.06, -0.11, -0.035), (0.06, 0.11, 0.0), "iron", r=0.0)
    pipe(m, [(0.0, 0.0, -0.035), (0.0, 0.0, -ROD + 0.02)], 0.012, 6, "steel")
    turned(m, [(0.03, -ROD), (0.03, -ROD + 0.02)], 8, "steel")


# --- the slung lines -------------------------------------------------------------------------------

def _wall_plate(m, side, y, z):
    x0, x1 = sorted((side * PLASTER, side * (PLASTER - 0.012)))
    box(m, (x0, y - 0.1, z - 0.08), (x1, y + 0.1, z + 0.08), "iron", r=0.0)
    stud(m, (side * (PLASTER - 0.012), y, z), math.pi / 2, -side * math.pi / 2, slot="steel", r=0.016)


def cable_bundle(m):
    """Three heavy cables slung from wall to wall, each sagging its own depth, their plates on the plaster."""
    half = PLASTER - 0.006
    for k, sag in enumerate(CABLE_SAG):
        y = -0.07 + 0.07 * k
        r = (0.022, 0.028, 0.02)[k]
        pts = [(x, y, _catenary(x, half, SLUNG_AT, sag)) for x in (half * (-1 + 2 * i / 16) for i in range(17))]
        pipe(m, pts, r, 8, "rubber" if k != 1 else "cloth_black")
    for side in (-1, 1):
        _wall_plate(m, side, 0.0, SLUNG_AT)


def bulb_string(m):
    """A cord of bare bulbs sagging from wall to wall, a bulb every BULB_EVERY on its drop."""
    half = PLASTER - 0.006
    pts = [(x, 0.0, _catenary(x, half, SLUNG_AT - 0.05, STRING_SAG)) for x in (half * (-1 + 2 * i / 20) for i in range(21))]
    pipe(m, pts, 0.006, 4, "rubber")
    count = int(2 * half / BULB_EVERY)
    for k in range(count):
        x = -half + BULB_EVERY * (k + 0.5) + (2 * half - BULB_EVERY * count) / 2
        z = _catenary(x, half, SLUNG_AT - 0.05, STRING_SAG)
        pipe(m, [(x, 0.0, z - 0.004), (x, 0.0, z - 0.07)], 0.004, 4, "rubber")
        turned(m, [(0.016, z - 0.115), (0.016, z - 0.07)], 8, "brass")
        turned(m, [(0.01, z - 0.115), (0.026, z - 0.13), (0.03, z - 0.155), (0.02, z - 0.178), (0.006, z - 0.186)], 8,
               "glass_bulb")
    for side in (-1, 1):
        _wall_plate(m, side, 0.0, SLUNG_AT - 0.05)


# --- the canopy and its gantry -------------------------------------------------------------------------

def _canopy_top(x, z):
    """The tarpaulin's top at (set) x, z: slung low across the street, sagging between the lines it hangs from."""
    across = CANOPY_MIDDLE + (CANOPY_EDGE - CANOPY_MIDDLE) * (x / CANOPY_X) ** 2
    for a, b in zip(CANOPY_LINES, CANOPY_LINES[1:]):
        if a <= z <= b:
            t = (z - a) / (b - a)
            # (Its edges tied taut along the walls, the sag only in its middle.)
            return across - CANOPY_SAG * math.sin(math.pi * t) * (1.0 - (x / CANOPY_X) ** 2)
    return across


def canopy(m):
    """The stallholders' tarpaulin across the street's south end, patched, sagging between its lines; ropes up from
    its lines to the girders and the ceiling."""
    xs = [-CANOPY_X + 2 * CANOPY_X * i / 18 for i in range(19)]
    zs = [CANOPY_LINES[0] + (SOUTH - CANOPY_LINES[0]) * j / 14 for j in range(15)]
    top = [[(x, -z, _canopy_top(x, z)) for x in xs] for z in zs]
    low = [[(x, y, h - CANOPY_T) for x, y, h in row] for row in top]
    m.shell()
    patches = {(3, 2), (11, 5), (6, 9), (15, 11), (8, 12)}
    for j in range(len(zs) - 1):
        for i in range(len(xs) - 1):
            slot = "cloth_patch" if (i, j) in patches else "cloth_blue"
            m.face([top[j][i], top[j][i + 1], top[j + 1][i + 1], top[j + 1][i]], slot)
            m.face([low[j][i], low[j + 1][i], low[j + 1][i + 1], low[j][i + 1]], slot)
    rims = ([(top[0][i], top[0][i + 1], low[0][i + 1], low[0][i]) for i in range(len(xs) - 1)]
            + [(top[-1][i + 1], top[-1][i], low[-1][i], low[-1][i + 1]) for i in range(len(xs) - 1)]
            + [(top[j + 1][0], top[j][0], low[j][0], low[j + 1][0]) for j in range(len(zs) - 1)]
            + [(top[j][-1], top[j + 1][-1], low[j + 1][-1], low[j][-1]) for j in range(len(zs) - 1)])
    for quad in rims:
        m.face(list(quad), "cloth_blue")
    # Its north edge hung with a scalloped valance; its south end with a fringe of tarpaulin strips nearly to the
    # heads, closing the street's view (clear of the walls, where the mains run).
    for z, depth, toward in ((CANOPY_LINES[0], VALANCE, 1), (SOUTH, FRINGE, -1)):
        x = -FLAP_X
        k = 0
        while x + FLAP_W <= FLAP_X + 1e-6:
            under = min(_canopy_top(x, z), _canopy_top(x + FLAP_W, z)) - CANOPY_T
            drop = depth * (0.85 + 0.15 * rng.random()) if toward < 0 else depth
            y0, y1 = sorted((-z, -z + toward * 0.02))
            box(m, (x, y0, under - drop), (x + FLAP_W, y1, under + 0.005), "cloth_patch" if k % 3 == 1 else "cloth_blue",
                r=0.0)
            x += FLAP_W + FLAP_GAP
            k += 1
    # Its ropes: from its first line up to the girder before it, from its middle line to the girder over it, from its
    # end to hooks in the ceiling.
    for x in (-3.2, 0.0, 3.2):
        for z, up, to_z in ((CANOPY_LINES[0], GIRDER_FOOT, 11.994), (CANOPY_LINES[1], GIRDER_FOOT, 15.992),
                            (SOUTH - 0.05, CEILING, SOUTH - 0.05)):
            pipe(m, [(x, -z, _canopy_top(x, z) - 0.005), (x, -to_z, up - 0.01)], 0.008, 4, "burlap")
            if up == CEILING:
                box(m, (x - 0.04, -to_z - 0.04, CEILING - 0.012), (x + 0.04, -to_z + 0.04, CEILING), "iron", r=0.0)


def gantry(m):
    """The pipe gantry under the canopy: its beam across the street, hung on rods up through the tarpaulin to the
    ceiling, the signs' hooks along it."""
    pipe(m, [(-4.2, 0.0, GANTRY_Y), (4.2, 0.0, GANTRY_Y)], 0.025, 8, "steel")
    for x in (-3.9, -1.3, 1.3, 3.9):
        pipe(m, [(x, 0.0, GANTRY_Y - 0.02), (x, 0.0, CEILING - 0.012)], 0.012, 6, "steel")
        box(m, (x - 0.05, -0.05, CEILING - 0.012), (x + 0.05, 0.05, CEILING), "iron", r=0.0)
    for x in (-2.0, 0.0, 2.0):
        turned(m, [(0.035, GANTRY_Y - 0.06), (0.035, GANTRY_Y - 0.035)], 8, "iron", at=(x, 0.0, 0.0))


PIECES = [(n, _sign(*SIGNS[n])) for n in SIGNS] + [("drop_rod", drop_rod), ("cable_bundle", cable_bundle),
                                                   ("bulb_string", bulb_string), ("canopy", canopy), ("gantry", gantry)]
BUDGET = {name: 3000 for name, _ in PIECES}
BUDGET["canopy"] = 2000
SLIVER = {name: 0.004 for name in BUDGET}


def build():
    common.reset()
    underground_shapes.rng = rng
    rng.seed(1933)

    for name, f in PIECES:
        smooth_object(name, f)


def main():
    build()
    common.export_piece(NAME, ATLAS, SLOTS, out=common.ROOT / "assets" / "eclipse" / "kit", sets_each=True,
                        budget=max(BUDGET.values()), sliver=min(SLIVER.values()))


if __name__ == "__main__":
    main()
