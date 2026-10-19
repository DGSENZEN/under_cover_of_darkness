"""The rare-book librarian's shelves (docs/superpowers/specs/2026-10-17-librarian-shop-design.md;
docs/superpowers/refs/underground/recipe.md): a tall case for each of his five sections, each shaped and
ornamented its own way so a section is known at a glance; the low double-sided case either side of the runner;
the rolling library ladder on its rail.

- shelf_chronology: brass and clockwork; a clock in its crest (its face blank, the user's), gears either side.
- shelf_necromancy: black lacquer and bone; a pointed gable, a skull at its apex over crossed bones, a bone frieze.
- shelf_alchemy: copper-clad; on its crest a retort, a flask and an alembic of glass; copper bands.
- shelf_metaphysics: dark wood cut with sigils; a great ringed sigil standing on its crest, carved pilasters.
- shelf_hunting: iron; a trophy's horns over a shield on its crest, iron hooks along its top.
- shelf_middle: low and double-sided, so the corner shows over it.
- ladder, ladder_rail: the rolling ladder on its brass rail along the chronology case (the tallest shelves).

Each case's frame: its front's middle at the origin on the floor, its front toward -y (into the room), its back
against the wall at y = DEPTH. BOARD_SPOTS (written beside the kit) tells the bay's book filler where every board
is.

    Blender -b --factory-startup --python tools/eclipse/library_shelves.py
"""

import json
import math
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import common  # noqa: E402
import shapes  # noqa: E402
import underground_shapes  # noqa: E402
from mathutils import Vector  # noqa: E402
from underground_shapes import box, pipe, smooth_object, turned  # noqa: E402

NAME = "library_shelves"
ATLAS = 4096
SLOTS = ["wood", "lacquer_black", "bone", "brass", "sign", "copper", "glass", "sigil_wood", "iron"]

rng = random.Random(1911)

SECTIONS = ("chronology", "necromancy", "alchemy", "metaphysics", "hunting")
# A tall case: across, deep, tall (m); its sides' and back's thickness; the tops of its boards.
WIDTH = 1.8
DEPTH = 0.42
# (Under the vault: it comes down to 3.0 m at the side walls, so a case stands 2.7 m and its ornaments no higher
# than CREST_MAX.)
HEIGHT = 2.7
CREST_MAX = 3.25
SIDE = 0.05
BACK = 0.035
BOARD_T = 0.035
BOARDS = (0.12, 0.55, 1.0, 1.45, 1.9, 2.35)
# The low case: across, deep (both faces), tall; its boards.
LOW = (1.4, 0.7, 1.4)
LOW_BOARDS = (0.12, 0.55, 1.0)
# The ladder's rail along the chronology case: how far out and how high; where the ladder stands on it.
RAIL = (-0.07, 2.47)
LADDER_X = (0.1, 0.52)
LADDER_FOOT = -0.58

# Every board a book can stand on, by case: (x from, to, its top, y from, to) in the case's frame.
BOARD_SPOTS = {}


def _hexa(m, corners, slot):
    """A closed solid of six quads from its eight corners: the four of one end, then the other's in step."""
    m.shell()
    a, b = corners[:4], corners[4:]
    m.face(a, slot)
    m.face(list(reversed(b)), slot)

    for k in range(4):
        m.face([a[k], a[(k + 1) % 4], b[(k + 1) % 4], b[k]], slot)


def _link(m, centre, e1, e2, radius, tube, slot, steps=16, sides=8):
    """A ring of tube about `centre` in the plane of `e1`, `e2` (a torus built from its axes)."""
    c, e1, e2 = Vector(centre), Vector(e1).normalized(), Vector(e2).normalized()
    n = e1.cross(e2).normalized()

    def at(i, j):
        t, f = 2 * math.pi * i / steps, 2 * math.pi * j / sides
        out = e1 * math.cos(t) + e2 * math.sin(t)
        return tuple(c + out * (radius + tube * math.cos(f)) + n * tube * math.sin(f))

    m.shell()
    for i in range(steps):
        for j in range(sides):
            m.face([at(i, j), at(i + 1, j), at(i + 1, j + 1), at(i, j + 1)], slot)


def _carcass(m, name, body, top_slot=None, side_slot=None):
    """A tall case's carcass in `body`: its sides (`side_slot`, if they differ), back, plinth, boards and top; its
    boards noted for the filler."""
    w, d, h = WIDTH, DEPTH, HEIGHT
    x0, x1 = -w / 2, w / 2
    # (The sides stop under the top, so their tops never lie in its plane.)
    for sx0, sx1 in ((x0, x0 + SIDE), (x1 - SIDE, x1)):
        box(m, (sx0, 0.0, 0.0), (sx1, d, h - 0.08), side_slot or body, r=0.0)
    box(m, (x0 + SIDE, d - BACK, 0.0), (x1 - SIDE, d, h - 0.08), body, r=0.0)
    box(m, (x0 + SIDE, 0.0, 0.0), (x1 - SIDE, d - BACK, BOARDS[0] - BOARD_T), body, r=0.0)
    spots = []

    for top in BOARDS:
        box(m, (x0 + SIDE, 0.03, top - BOARD_T), (x1 - SIDE, d - BACK, top), body, r=0.0)
        spots.append((x0 + SIDE, x1 - SIDE, top, 0.03, d - BACK))

    # Its top, overhanging the front by 4 cm (over 3: its front never lies near the sides').
    box(m, (x0, -0.04, h - 0.08), (x1, d, h), top_slot or body, r=0.0)
    BOARD_SPOTS[name] = spots


# --- the five sections -------------------------------------------------------------------------------------

def _gear(m, centre, radius, teeth, slot):
    """A gear standing in the case's front plane: a disc with its teeth round it, a boss at its middle."""
    cx, cy, cz = centre
    turned(m, [(radius, 0.0), (radius, 0.04)], 16, slot, at=(cx, cy, cz), lean=math.pi / 2, towards=0.0)
    for k in range(teeth):
        a = 2 * math.pi * k / teeth
        tx, tz = cx + (radius + 0.025) * math.cos(a), cz + (radius + 0.025) * math.sin(a)
        box(m, (tx - 0.02, cy - 0.04, tz - 0.02), (tx + 0.02, cy, tz + 0.02), slot, r=0.0, turn=(0.0, -a, 0.0))
    # (Its boss out of the disc's face, not sunk to its back: their backs would lie in one plane.)
    turned(m, [(0.05, 0.0), (0.05, 0.04)], 10, slot, at=(cx, cy - 0.04, cz), lean=math.pi / 2, towards=0.0)


def shelf_chronology(m):
    """Chronology: dark wood bound in brass, every board edged in brass, a clock in its crest (its face the user's to
    paint), gears either side of it, brass bands down its front."""
    _carcass(m, "shelf_chronology", "wood")
    h = HEIGHT
    box(m, (-WIDTH / 2, -0.02, h), (WIDTH / 2, 0.2, h + 0.1), "brass", r=0.02)
    # The clock: its brass bezel, its face standing out of it.
    zc = h + 0.1 + 0.2
    turned(m, [(0.2, 0.0), (0.2, 0.07)], 24, "brass", at=(0.0, 0.05, zc), lean=math.pi / 2, towards=0.0)
    turned(m, [(0.155, 0.0), (0.155, 0.035)], 24, "sign", at=(0.0, 0.05 - 0.07, zc), lean=math.pi / 2, towards=0.0)
    for side in (-1, 1):
        _gear(m, (side * 0.55, 0.1, h + 0.1 + 0.06), 0.11, 10, "brass")
    for side in (-1, 1):
        box(m, (side * (WIDTH / 2 - SIDE / 2) - 0.03, -0.04, 0.0), (side * (WIDTH / 2 - SIDE / 2) + 0.03, 0.0, h - 0.08),
            "brass", r=0.0)
    # Each board's front edged in brass (standing out 3.5 cm from it).
    for top in BOARDS[1:]:
        box(m, (-WIDTH / 2 + SIDE, -0.005, top - BOARD_T), (WIDTH / 2 - SIDE, 0.03, top), "brass", r=0.0)


def shelf_necromancy(m):
    """Necromancy: black lacquer, bone columns at its front, a pointed gable on its crest with a skull at its apex
    over crossed bones, a frieze of bone along its top."""
    _carcass(m, "shelf_necromancy", "lacquer_black")
    h = HEIGHT
    w = WIDTH / 2
    gable = [(-w, h), (w, h), (0.08, h + 0.36), (-0.08, h + 0.36)]
    _hexa(m, [(x, 0.0, z) for x, z in gable] + [(x, 0.12, z) for x, z in gable], "lacquer_black")
    box(m, (-w, -0.04, h - 0.26), (w, 0.0, h - 0.12), "bone", r=0.0)
    for side in (-1, 1):
        x = side * (w - SIDE / 2)
        turned(m, [(0.05, 0.0), (0.05, 0.08), (0.035, 0.12), (0.035, h - 0.42), (0.05, h - 0.38), (0.05, h - 0.3)], 10,
               "bone", at=(x, -0.05, 0.0))
    # The crossed bones behind the skull, the skull at the apex, its sockets black.
    for side in (-1, 1):
        turned(m, [(0.03, 0.0), (0.022, 0.04), (0.022, 0.34), (0.03, 0.38)], 8, "bone", at=(-side * 0.15, -0.04, h + 0.06),
               lean=math.radians(45.0), towards=side * math.pi / 2)
    top = (0.0, -0.09, h + 0.24)
    turned(m, [(0.05, 0.0), (0.09, 0.035), (0.1, 0.1), (0.08, 0.16), (0.03, 0.19)], 12, "bone", at=top)
    box(m, (-0.05, -0.18, h + 0.2), (0.05, -0.09, h + 0.28), "bone", r=0.02)
    for side in (-1, 1):
        turned(m, [(0.024, 0.0), (0.024, 0.045)], 8, "lacquer_black", at=(side * 0.04, -0.16, h + 0.34), lean=math.pi / 2,
               towards=0.0)


def shelf_alchemy(m):
    """Alchemy: its sides clad in copper, copper pipes and valves down its front as a still's, three vessels of glass
    standing on its crest (a retort, a flask, an alembic)."""
    _carcass(m, "shelf_alchemy", "wood", top_slot="copper", side_slot="copper")
    h = HEIGHT
    box(m, (-WIDTH / 2, -0.02, h), (WIDTH / 2, 0.25, h + 0.08), "copper", r=0.02)
    base = h + 0.08
    turned(m, [(0.045, 0.0), (0.1, 0.045), (0.11, 0.11), (0.085, 0.18), (0.03, 0.21)], 14, "glass", at=(-0.55, 0.1, base))
    pipe(m, [(-0.55, 0.1, base + 0.2), (-0.43, 0.1, base + 0.25), (-0.25, 0.1, base + 0.18)], 0.02, 8, "glass")
    turned(m, [(0.045, 0.0), (0.09, 0.045), (0.09, 0.12), (0.03, 0.19), (0.025, 0.33), (0.032, 0.35)], 12, "glass",
           at=(0.08, 0.1, base))
    turned(m, [(0.08, 0.0), (0.1, 0.09), (0.065, 0.15)], 12, "copper", at=(0.6, 0.1, base))
    turned(m, [(0.065, 0.0), (0.09, 0.05), (0.055, 0.11), (0.025, 0.14)], 12, "glass", at=(0.6, 0.1, base + 0.15))
    for side in (-1, 1):
        x = side * (WIDTH / 2 - SIDE / 2)
        pipe(m, [(x, -0.05, 0.1), (x, -0.05, h - 0.12)], 0.025, 8, "copper")
        for z in (0.6, 1.4, 2.1):
            turned(m, [(0.045, 0.0), (0.045, 0.04)], 10, "brass", at=(x, -0.05, z), lean=math.pi / 2, towards=0.0)


def shelf_metaphysics(m):
    """Occult metaphysics: dark wood cut deep with sigils: a ringed sigil standing on its crest with a star and a
    boss within it, carved pilasters down its front."""
    _carcass(m, "shelf_metaphysics", "sigil_wood")
    h = HEIGHT
    box(m, (-WIDTH / 2, -0.02, h), (WIDTH / 2, 0.2, h + 0.08), "sigil_wood", r=0.02)
    zc = h + 0.08 + 0.21
    _link(m, (0.0, 0.06, zc), (1, 0, 0), (0, 0, 1), 0.19, 0.03, "sigil_wood", steps=20)
    # The star's four bars, each laid behind the last (crossing in one plane, their faces would lie on each other).
    for k in range(4):
        a = math.pi * k / 4
        y0 = 0.02 + 0.035 * k
        box(m, (-0.19, y0, zc - 0.018), (0.19, y0 + 0.035, zc + 0.018), "sigil_wood", r=0.0, turn=(0.0, a, 0.0))
    turned(m, [(0.05, 0.0), (0.05, 0.05), (0.03, 0.08)], 12, "sigil_wood", at=(0.0, 0.02, zc), lean=math.pi / 2, towards=0.0)
    for side in (-1, 1):
        x = side * (WIDTH / 2 - SIDE / 2)
        box(m, (x - 0.035, -0.045, 0.0), (x + 0.035, 0.0, h - 0.08), "sigil_wood", r=0.0)
        for z0 in (0.5, 1.2, 1.9):
            box(m, (x - 0.025, -0.085, z0), (x + 0.025, -0.045, z0 + 0.15), "sigil_wood", r=0.0)
            box(m, (x - 0.06, -0.085, z0 + 0.055), (x - 0.025, -0.045, z0 + 0.095), "sigil_wood", r=0.0)
            box(m, (x + 0.025, -0.085, z0 + 0.055), (x + 0.06, -0.045, z0 + 0.095), "sigil_wood", r=0.0)


def shelf_hunting(m):
    """Monster hunting: iron straps riveted across its front, a trophy's horns spread over a shield on its crest,
    iron hooks along its top."""
    _carcass(m, "shelf_hunting", "wood", top_slot="iron")
    h = HEIGHT
    box(m, (-WIDTH / 2, -0.02, h), (WIDTH / 2, 0.2, h + 0.1), "iron", r=0.02)
    shield = [(-0.14, h + 0.1), (0.14, h + 0.1), (0.14, h + 0.3), (-0.14, h + 0.3)]
    _hexa(m, [(x, -0.06, z) for x, z in shield] + [(x, 0.0, z) for x, z in shield], "wood")
    for side in (-1, 1):
        horn = [(side * 0.1, -0.03, h + 0.26), (side * 0.3, -0.03, h + 0.33), (side * 0.48, -0.03, h + 0.43),
                (side * 0.58, -0.03, h + 0.48)]
        pipe(m, horn[:3], 0.03, 8, "bone")
        pipe(m, horn[2:], 0.022, 8, "bone")
    for k in range(5):
        x = -0.72 + 0.36 * k
        pipe(m, [(x, 0.0, h - 0.04), (x, -0.08, h - 0.04), (x, -0.1, h - 0.12)], 0.013, 6, "iron")
    # Iron straps across its stiles, riveted.
    for side in (-1, 1):
        x = side * (WIDTH / 2 - SIDE / 2)
        for z0 in (0.3, 0.9, 1.5, 2.1):
            box(m, (x - 0.045, -0.035, z0), (x + 0.045, 0.0, z0 + 0.08), "iron", r=0.0)
            underground_shapes.stud(m, (x, -0.035, z0 + 0.04), math.pi / 2, 0.0, "iron", r=0.02)


def shelf_middle(m):
    """The low case either side of the runner: double-sided, its boards on both faces, low enough for the corner
    to show over it."""
    w, d, h = LOW
    x0, x1 = -w / 2, w / 2
    y0, y1 = -d / 2, d / 2
    for sx0, sx1 in ((x0, x0 + SIDE), (x1 - SIDE, x1)):
        box(m, (sx0, y0, 0.0), (sx1, y1, h - 0.07), "wood", r=0.0)
    box(m, (x0 + SIDE, -BACK / 2, 0.0), (x1 - SIDE, BACK / 2, h - 0.07), "wood", r=0.0)
    for fy0, fy1 in ((y0, -BACK / 2), (BACK / 2, y1)):
        box(m, (x0 + SIDE, fy0, 0.0), (x1 - SIDE, fy1, LOW_BOARDS[0] - BOARD_T), "wood", r=0.0)
    spots = []

    for top in LOW_BOARDS:
        for fy0, fy1 in ((y0 + 0.03, -BACK / 2), (BACK / 2, y1 - 0.03)):
            box(m, (x0 + SIDE, fy0, top - BOARD_T), (x1 - SIDE, fy1, top), "wood", r=0.0)
            spots.append((x0 + SIDE, x1 - SIDE, top, fy0, fy1))

    box(m, (x0 - 0.02, y0 - 0.04, h - 0.07), (x1 + 0.02, y1 + 0.04, h), "wood", r=0.02)
    BOARD_SPOTS["shelf_middle"] = spots


def ladder_rail(m):
    """The ladder's brass rail along the chronology case's front, on three brackets."""
    ry, rz = RAIL
    pipe(m, [(-WIDTH / 2 + 0.06, ry, rz), (WIDTH / 2 - 0.06, ry, rz)], 0.02, 8, "brass")
    for x in (-0.8, 0.0, 0.8):
        box(m, (x - 0.02, ry, rz - 0.06), (x + 0.02, 0.0, rz - 0.02), "brass", r=0.0)


def ladder(m):
    """The rolling library ladder hooked on its rail: two stiles from the floor up to it, rungs between, hooks over
    the rail."""
    ry, rz = RAIL
    top_y, top_z = ry - 0.04, rz - 0.06
    for x in LADDER_X:
        _hexa(m, [(x - 0.025, LADDER_FOOT - 0.0175, 0.0), (x + 0.025, LADDER_FOOT - 0.0175, 0.0),
                  (x + 0.025, LADDER_FOOT + 0.0175, 0.0), (x - 0.025, LADDER_FOOT + 0.0175, 0.0),
                  (x - 0.025, top_y - 0.0175, top_z), (x + 0.025, top_y - 0.0175, top_z),
                  (x + 0.025, top_y + 0.0175, top_z), (x - 0.025, top_y + 0.0175, top_z)], "wood")
        # Its hook over the rail.
        # (A smooth arc round the rail: a sharp bend would pinch its faces thin.)
        arc = [(x, ry + 0.05 * math.cos(math.radians(a)), rz + 0.05 * math.sin(math.radians(a))) for a in (200, 150, 105, 60, 15, -25)]
        pipe(m, [(x, top_y, top_z)] + arc, 0.016, 8, "brass")
    rungs = 9
    for k in range(1, rungs + 1):
        t = k / (rungs + 1)
        y, z = LADDER_FOOT + (top_y - LADDER_FOOT) * t, top_z * t
        pipe(m, [(LADDER_X[0] + 0.025, y, z), (LADDER_X[1] - 0.025, y, z)], 0.017, 8, "wood")


PIECES = [shelf_chronology, shelf_necromancy, shelf_alchemy, shelf_metaphysics, shelf_hunting, shelf_middle, ladder_rail,
          ladder]


def build():
    common.reset()
    underground_shapes.rng = rng
    rng.seed(1911)
    BOARD_SPOTS.clear()

    for f in PIECES:
        smooth_object(f.__name__, f)


def main():
    build()
    common.export_piece(NAME, ATLAS, SLOTS, out=common.ROOT / "assets" / "eclipse" / "kit", sets_each=True, budget=12000)
    # The boards for the bay's book filler, in Godot's axes (x, up, -y): (x from, to, top, z from, to).
    boards = {name: [[x0, x1, top, -y1, -y0] for x0, x1, top, y0, y1 in spots] for name, spots in BOARD_SPOTS.items()}
    (common.SOURCE / (NAME + "_boards.json")).write_text(json.dumps(boards, indent=1))


if __name__ == "__main__":
    main()
