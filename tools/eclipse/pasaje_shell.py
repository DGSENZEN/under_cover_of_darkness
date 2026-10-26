"""The Pasaje's shell dressed (docs/superpowers/specs/2026-10-26-pasaje-market-design.md; plan
docs/superpowers/plans/2026-10-26-pasaje-market.md, Task 3): the Company's tile up the market street's 4.5 m walls, as
in the corridor (tools/eclipse/underground_walls.py: the line's blue band, the cap, plaster above), the plaster over
its two openings and their cement reveals with a worn stone sill, the plastered ceiling across its 9.4 m in spans and
the riveted iron girders under their joints, the floor's side strips and the steel-edged joints at its two ends, and
the ends of the fire main and the air line where they turn into the wall either side of the candle lane's mouth.

The rest is the Metro's own: the floor's 1.2 m modules (underground_floor) and the mains' and the tray's lengths
(underground_services); maps/pasaje.gd lays them all out.

Frames (Blender: the set's x, y = the set's -z, z up):
- wall, wall_worn, wall_fill_<cm>, lintel_<opening>: a panel as underground_walls builds one, along +x from 0, out
  from the wall's face (y = 0) to the tiles' (y = -FACE), floor (z = 0) to the ceiling (HEIGHT);
- reveal_<opening>: where it stands in the set (set at the set's origin);
- ceiling_span: across the street (x from -INSIDE to INSIDE), along +y from 0, its underside at z = 0;
- girder: across the street between the walls' plaster, centred on y = 0, its top at z = 0 (the ceiling's underside);
- floor_side: the strip along a wall, the wall at x = 0, out to x = SIDE, along +y from 0, its tiles' tops at z = 0;
- floor_joint: across the street, along +y from 0 to JOINT, a lip under the next floor along -y, its top at z = 0;
- fire_turn_in, air_turn_in, fire_turn_out, air_turn_out: as underground_services builds a main (along +x, the wall's
  face y = 0, the main's centre z = 0).

    Blender -b --factory-startup --python tools/eclipse/pasaje_shell.py
"""

import math
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import common  # noqa: E402
import underground_floor  # noqa: E402
import underground_services  # noqa: E402
import underground_shapes  # noqa: E402
import underground_walls  # noqa: E402
from underground_services import FLANGE, FLANGE_T, BAND, MAINS, along_x, flange_bolts, saddle  # noqa: E402
from underground_shapes import box, pipe, smooth_object, stud  # noqa: E402

NAME = "pasaje_shell"
# (The ceiling's spans are big: the larger atlas keeps the tiles' painting as fine as the corridor's.)
ATLAS = 4096
SLOTS = ["tile_wall", "tile_dark", "tile_line", "tile_odd", "mortar", "plaster", "plaster_vault", "cement", "stone_old",
         "tile_cream", "tile_terra", "grout", "iron", "steel", "pipe_red", "pipe_blue", "paint_band"]

rng = random.Random(1926)

# The set (maps/pasaje.gd): its half width to the walls' outer planes, the walls' tile-less faces (|x|), its half
# length, how short of the map's planes it stops, its height; its openings: [wall side, z from, z to, height].
HALF_W = 5.0
INSIDE = 4.7
HALF_L = 20.0
SEAM = 0.01
HEIGHT = 4.5
OPENINGS = {"herb_market": (-1, -3.0, 1.0, 3.0), "candle_lane": (1, -3.0, 3.9, 4.0)}

PANEL = underground_walls.PANEL
FACE = underground_walls.FACE
MORTAR = underground_walls.MORTAR

# The reveals: the cement architrave round each opening on the tiles (its width, how proud of them, its head's depth:
# the lane's lower, under the girders' bearing plates), its plinths, the lining of the wall's thickness, the sill.
ARCH = 0.18
PROUD = 0.05
HEAD = {"herb_market": 0.18, "candle_lane": 0.12}
PLINTH = (0.3, 0.07, 0.02)      # its height, how proud of the tiles, how much wider than the architrave
LINING = 0.04
SILL = 0.12
LIP = (0.05, 0.02)              # how far a sill or joint reaches under the next floor, and how far below it

# The ceiling: ten spans end to end, their underside under the ceiling's box; a girder under each joint.
SPANS = 10
SPAN = 2 * (HALF_L - SEAM) / SPANS
THICK = 0.04
GIRDER = (0.28, 0.2, 0.032, 0.014)  # its depth, its flanges' width and thickness, its web's
STIFFEN = 1.2
BEARING = (0.32, 0.3, 0.032)        # a bearing plate's height, width, thickness (on the plaster)

# The floor: a side strip at each wall (its dark border and one column of the chequer), the Metro's modules between,
# whole rows of them along, a joint at each end.
SIDE = 0.5
BORDER = 0.2
MODULES = 7
ROWS = 33
JOINT = (2 * (HALF_L - SEAM) - ROWS * underground_floor.MODULE) / 2

# The east wall's mains end either side of the lane's mouth: four lengths from the stretch's south end, then the turn
# in (TURN_IN long, into the wall short of the architrave); out of the wall north of it, then three lengths to the end.
TURN_IN = 0.67
TURN_OUT = 3.76
STEPS = 7
COLLAR = 0.03

BUDGET = {"wall": 3000, "wall_worn": 3000, "lintel_herb_market": 400, "lintel_candle_lane": 400,
          "reveal_herb_market": 800, "reveal_candle_lane": 800, "ceiling_span": 400, "girder": 2000, "floor_side": 600,
          "floor_joint": 600, "fire_turn_in": 1500, "air_turn_in": 1500, "fire_turn_out": 1500, "air_turn_out": 1500}
SLIVER = {}


def wall_runs():
    """Each run of wall between the stretch's ends and its openings: (side, z from, z to) in the set's frame."""
    runs = []
    for side in (-1, 1):
        z = -HALF_L + SEAM
        for a, b in sorted((o[1], o[2]) for o in OPENINGS.values() if o[0] == side):
            runs.append((side, z, a))
            z = b
        runs.append((side, z, HALF_L - SEAM))
    return runs


def fills():
    """The widths the runs leave over their whole panels (m, to the millimetre)."""
    left = {round((b - a) * 1000) % round(PANEL * 1000) for _, a, b in wall_runs()}
    return sorted(w / 1000 for w in left if w)


def fill_name(width):
    return "wall_fill_%d" % round(width * 100)


for _w in fills():
    BUDGET[fill_name(_w)] = 3000
SLIVER.update({n: 0.004 for n in BUDGET})


def _set(x, z, y):
    """A point in the set's frame (x across, z along, y up) as Blender's."""
    return (x, -z, y)


def _set_box(m, lo, hi, slot):
    """A box between two corners in the set's frame."""
    a, b = _set(*lo), _set(*hi)
    box(m, tuple(min(p, q) for p, q in zip(a, b)), tuple(max(p, q) for p, q in zip(a, b)), slot, r=0.0)


# --- the walls ----------------------------------------------------------------------------------

def _panel(width, build):
    """underground_walls' panel `build` at `width`, standing the street's height."""
    def made(m):
        saved = underground_walls.PANEL, underground_walls.HEIGHT
        underground_walls.PANEL, underground_walls.HEIGHT = width, HEIGHT
        try:
            build(m)
        finally:
            underground_walls.PANEL, underground_walls.HEIGHT = saved

    return made


def _lintel(name):
    """The plaster over an opening, from its head to the ceiling, on the panels' plane."""
    _, a, b, high = OPENINGS[name]

    def made(m):
        box(m, (0.0, -MORTAR, high), (b - a, 0.0, HEIGHT), "plaster", r=0.0)

    return made


def _reveal(name):
    """An opening's reveal: the cement architrave round it on the tiles, on plinths; the lining of the wall's thickness
    up its jambs and under its head; the worn stone sill across it, under the wall's thickness, a lip reaching under
    the floor beyond."""
    side, a, b, high = OPENINGS[name]
    face = INSIDE - FACE
    out = HALF_W - SEAM
    head = HEAD[name]
    tall, proud, wider = PLINTH

    def made(m):
        # The architrave's jambs on plinths, its head across.
        for edge, away in ((a, -1), (b, 1)):
            near, far = edge, edge + away * ARCH
            _set_box(m, (side * face, near, tall), (side * (face - PROUD), far, high), "cement")
            _set_box(m, (side * face, near, 0.0), (side * (face - proud), far + away * wider, tall), "cement")
        _set_box(m, (side * face, a - ARCH, high), (side * (face - PROUD), b + ARCH, high + head), "cement")
        # The lining: the jambs full height, the head's between them.
        for edge, inward in ((a, 1), (b, -1)):
            _set_box(m, (side * face, edge, 0.0), (side * out, edge + inward * LINING, high), "cement")
        _set_box(m, (side * face, a + LINING, high - LINING), (side * out, b - LINING, high), "cement")
        # The sill, its top the floor's, and its lip under the floor beyond the wall.
        _set_box(m, (side * INSIDE, a + LINING, -SILL), (side * out, b - LINING, 0.0), "stone_old")
        reach, drop = LIP
        _set_box(m, (side * out, a + LINING, -SILL), (side * (HALF_W + reach), b - LINING, -drop), "stone_old")

    return made


def wall(m):
    _panel(PANEL, underground_walls.wall_tiled)(m)


def wall_worn(m):
    _panel(PANEL, underground_walls.wall_tiled_worn)(m)


# --- the ceiling ---------------------------------------------------------------------------------

def ceiling_span(m):
    """One span of the ceiling's plaster across the street."""
    box(m, (-INSIDE, 0.0, 0.0), (INSIDE, SPAN, THICK), "plaster_vault", r=0.0)


def girder(m):
    """A riveted iron girder across the street under a joint of the ceiling: its flanges and web, stiffeners paired
    either side of the web, bearing plates bolted to the plaster at each end."""
    depth, width, flange, web = GIRDER
    reach = INSIDE - MORTAR - BEARING[2]
    box(m, (-reach, -width / 2, -depth), (reach, width / 2, -depth + flange), "iron", r=0.0)
    box(m, (-reach, -width / 2, -flange), (reach, width / 2, 0.0), "iron", r=0.0)
    box(m, (-reach, -web / 2, -depth + flange), (reach, web / 2, -flange), "iron", r=0.0)
    count = int(2 * reach / STIFFEN)
    for k in range(1, count + 1):
        x = -reach + 2 * reach * k / (count + 1)
        # (One plate through the web, either side of it.)
        box(m, (x - 0.006, -width / 2 + 0.01, -depth + flange), (x + 0.006, width / 2 - 0.01, -flange), "iron", r=0.0)
        # (Its rivets in the bottom flange's underside, one each side of the stiffeners.)
        for s in (-1, 1):
            stud(m, (x, s * width / 3, -depth), math.pi, 0.0, slot="steel", r=0.012)
    high, wide, thick = BEARING
    for s in (-1, 1):
        x0, x1 = sorted((s * reach, s * (reach + thick)))
        box(m, (x0, -wide / 2, -high), (x1, wide / 2, 0.0), "iron", r=0.0)
        # (Bolted through the plaster above the top flange and below the bottom one.)
        for y in (-wide / 3, wide / 3):
            for z in (-high + 0.02, -0.06 - flange):
                stud(m, (s * reach, y, z), math.pi / 2, -s * math.pi / 2, slot="steel", r=0.014)


# --- the floor -----------------------------------------------------------------------------------

def floor_side(m):
    """The strip along a wall: its dark border at the wall and one column of the chequer (its tiles chequered to the
    modules beside it: their first column's), each tile settled, on the grout bed."""
    tile, grout, tile_t, bed_t = underground_floor.TILE, underground_floor.GROUT, underground_floor.TILE_T, underground_floor.BED_T
    depth = underground_floor.MODULE
    box(m, (0.0, 0.0, -tile_t - bed_t), (SIDE, depth, -tile_t), "grout", r=0.0)
    for j in range(round(depth / tile)):
        y0, y1 = j * tile + grout / 2, (j + 1) * tile - grout / 2
        box(m, (grout / 2, y0, -tile_t), (BORDER - grout / 2, y1, 0.0), "tile_dark", r=0.0)
        drop = rng.uniform(0.0, underground_floor.SETTLE[0])
        slot = "tile_cream" if (j + 1) % 2 else "tile_terra"
        box(m, (BORDER + grout / 2, y0, -tile_t - drop), (SIDE - grout / 2, y1, -drop), slot, r=0.0)


def floor_joint(m):
    """The joint where this stretch's floor meets the next's: a cement strip between steel angles, a lip reaching
    under the next floor."""
    tile_t = underground_floor.TILE_T + underground_floor.BED_T
    angle = 0.04
    box(m, (-INSIDE, 0.0, -tile_t), (INSIDE, angle, 0.0), "steel", r=0.0)
    box(m, (-INSIDE, JOINT - angle, -tile_t), (INSIDE, JOINT, 0.0), "steel", r=0.0)
    box(m, (-INSIDE, angle, -tile_t), (INSIDE, JOINT - angle, -0.004), "cement", r=0.0)
    reach, drop = LIP
    box(m, (-INSIDE, -reach, -tile_t), (INSIDE, 0.0, -drop), "cement", r=0.0)


# --- the mains' turns -----------------------------------------------------------------------------

def _collar(m, x, r):
    """The cement collar round a main where it goes into the wall: a square frame on the tiles, the main through it."""
    big = r + COLLAR
    t = 0.03
    box(m, (x - big, -t, r), (x + big, 0.0, big), "cement", r=0.0)
    box(m, (x - big, -t, -big), (x + big, 0.0, -r), "cement", r=0.0)
    box(m, (x - big, -t, -r), (x - r, 0.0, r), "cement", r=0.0)
    box(m, (x + r, -t, -r), (x + big, 0.0, r), "cement", r=0.0)


def _turn(colour, length, inward):
    """A main's end: its length along the wall and its bend into it (at its far end if `inward`, else out of it at its
    near end), the flange at its joint with the next length, a painted band, a saddle, the collar at the wall."""
    slot, r, standoff, sides = MAINS[colour]
    d = r + standoff
    big = r + FLANGE
    # (The bend's ends a little straight, so its first and last rings stand square to the main and to the wall.)
    e = 0.012
    rho = d - e
    turns = [math.pi / 2 * k / STEPS for k in range(STEPS + 1)]

    def made(m):
        if inward:
            along_x(m, [(0.0, big, "steel"), (FLANGE_T, big, slot), (FLANGE_T, r, slot), (0.3, r, "paint_band"),
                        (0.3 + BAND, r, slot), (length - d - e, r, slot)], sides, -d)
            flange_bolts(m, FLANGE_T, -d, r)
            bend = [(length - d - e, -d, 0.0)] + [(length - d + rho * math.sin(t), -e - rho * math.cos(t), 0.0)
                                                    for t in turns] + [(length - e, 0.0, 0.0)]
            saddle(m, (length - d) / 2, d, r)
            _collar(m, length - e, r)
        else:
            along_x(m, [(d + e, r, slot), (length - 0.3 - BAND, r, "paint_band"), (length - 0.3, r, slot),
                        (length - FLANGE_T, r, slot), (length - FLANGE_T, big, "steel"), (length, big, "steel")],
                    sides, -d)
            bend = [(e, 0.0, 0.0)] + [(d - rho * math.cos(t), -e - rho * math.sin(t), 0.0)
                                      for t in turns] + [(d + e, -d, 0.0)]
            for x in (d + (length - d) / 3, d + 2 * (length - d) / 3) if length > 2 else (d + (length - d) / 2,):
                saddle(m, x, d, r)
            _collar(m, e, r)
        pipe(m, bend, r, sides, slot)

    return made


PIECES = [("wall", wall), ("wall_worn", wall_worn)]
PIECES += [(fill_name(w), _panel(w, underground_walls.wall_tiled)) for w in fills()]
PIECES += [("lintel_" + n, _lintel(n)) for n in OPENINGS] + [("reveal_" + n, _reveal(n)) for n in OPENINGS]
PIECES += [("ceiling_span", ceiling_span), ("girder", girder), ("floor_side", floor_side), ("floor_joint", floor_joint)]
PIECES += [("fire_turn_in", _turn("red", TURN_IN, True)), ("air_turn_in", _turn("blue", TURN_IN, True)),
           ("fire_turn_out", _turn("red", TURN_OUT, False)), ("air_turn_out", _turn("blue", TURN_OUT, False))]


def build():
    common.reset()
    underground_shapes.rng = rng
    rng.seed(1926)
    underground_walls.rng.seed(1926)

    for name, f in PIECES:
        smooth_object(name, f)


def main():
    build()
    common.export_piece(NAME, ATLAS, SLOTS, out=common.ROOT / "assets" / "eclipse" / "kit", sets_each=True,
                        budget=max(BUDGET.values()), sliver=min(SLIVER.values()))


if __name__ == "__main__":
    main()
