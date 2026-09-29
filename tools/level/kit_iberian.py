"""The city's Iberian buildings (kit v1): the Ribeira's tall narrow houses
(after Porto's riverfront: fronts tiled or washed inside granite frames,
iron balconies laddering up them, Spanish tiles on low roofs) over their
granite arcade; the Terreiro's arcaded bays (after Lisbon's Praca do
Comercio, its yellow and stone) and their corner; the columns at its water
stair; granite flights for the Guindais stair; the king on his horse; a
wall shrine. Pure data, as kit_recipes (which imports this at its end).

A house (casa_a .. casa_h) stands on the quay: its pivot the middle of its
footprint on the ground, its front to +z. Its first storey starts over the
arcade (GROUND), the arcade piece (arcade_ribeira_6) standing under its
front (ARCADE deep) before its ground floor. Its balconies are the thief's
ladder: each a hang from the one under it (rules.HANG), the first from the
quay, their iron rails drawn only (a rail's bar is no lip to hang from).
"""

import math

import kit_houses
import kit_recipes as k
import kit_shapes as ks

WIDTH = 6.0
DEPTH = 14.0
ARCADE = 4.0
GROUND = 3.6
STOREY = 3.0
FRONT = DEPTH / 2.0
BALCONY = (1.4, 0.15, 0.9)
FRENCH = (1.0, 2.2)
PITCH = 20.0
CASA_TRIS = 2200
DOOR = (1.2, 2.2)


def col(cx, cy, cz, sx, sy, sz, yaw=0.0, pitch=0.0, roll=0.0):
    return [cx, cy, cz, sx, sy, sz, "stone", yaw, pitch, roll]


def _frame(x, y0, z, w, h, slot="granite"):
    """A granite surround on the front z: jambs and a lintel round an
    opening w x h whose foot is at y0."""
    return [ks.box(x - w / 2.0 - 0.09, y0 + h / 2.0, z + 0.04, 0.18, h, 0.1, slot),
            ks.box(x + w / 2.0 + 0.09, y0 + h / 2.0, z + 0.04, 0.18, h, 0.1, slot),
            ks.box(x, y0 + h + 0.12, z + 0.05, w + 0.44, 0.24, 0.12, slot)]


def _window(x, y0, lit, balcony):
    """A French window on a storey whose floor is at y0: its glass (lit or
    dark), its granite surround, its shutters folded back; on a balcony (its
    slab, its iron rail and brackets) or a low iron guard."""
    w, h = FRENCH
    out = [ks.card(x, y0 + 0.05 + h / 2.0, FRONT + 0.02, w, h, "glass_lit" if lit else "glass_dark")]
    out += _frame(x, y0 + 0.05, FRONT, w, h)

    for side in (-1.0, 1.0):
        out.append(ks.card(x + side * (w / 2.0 + 0.3), y0 + 0.05 + h / 2.0, FRONT + 0.06, 0.45, h, "shutters"))

    if balcony:
        bw, bt, bd = BALCONY
        z = FRONT + bd / 2.0
        out.append(ks.box(x, y0 - bt / 2.0, z, bw, bt, bd, "granite"))
        out.append(ks.card(x, y0 + 0.45, FRONT + bd - 0.03, bw - 0.04, 0.9, "iron_rail"))

        for side in (-1.0, 1.0):
            out.append(ks.card(x + side * (bw / 2.0 - 0.02), y0 + 0.45, FRONT + bd / 2.0, bd - 0.06, 0.9, "iron_rail", 90.0))
            out.append(ks.box(x + side * (bw / 2.0 - 0.2), y0 - bt - 0.2, FRONT + 0.25, 0.12, 0.4, 0.5, "iron", 0.0, 30.0, 0.0))
    else:
        out.append(ks.card(x, y0 + 0.5, FRONT + 0.08, w, 0.8, "iron_rail"))

    return out


def casa(storeys, front, side, balconies, lit, chimney=1.0):
    """A house: `storeys` over the arcade, its front skin `front` (tiles or
    render), its sides and back `side`; balconies "all" (every storey) or
    "top"; `lit` [(storey, window 0 or 1)]; the chimney to the left (-1) or
    right. Returns (shapes, colliders, size)."""
    height = storeys * STOREY
    eaves = GROUND + height
    rise = FRONT * math.tan(math.radians(PITCH))
    shapes = [ks.box(0.0, GROUND / 2.0, -ARCADE / 2.0 - 0.0, WIDTH, GROUND, DEPTH - ARCADE, "granite"),
              ks.box(0.0, GROUND + height / 2.0, 0.0, WIDTH, height, DEPTH, side),
              ks.box(0.0, GROUND + height / 2.0, FRONT + 0.025, WIDTH - 0.5, height, 0.05, front)]
    cols = [col(0.0, GROUND / 2.0, -ARCADE / 2.0, WIDTH, GROUND, DEPTH - ARCADE),
            col(0.0, GROUND + height / 2.0, 0.0, WIDTH, height, DEPTH)]

    # The ground floor behind the arcade: its door, a shop's grilled window.
    ground = FRONT - ARCADE
    shapes.append(ks.card(1.3, DOOR[1] / 2.0, ground + 0.02, DOOR[0], DOOR[1], "door_1"))
    shapes += _frame(1.3, 0.0, ground, DOOR[0], DOOR[1])
    shapes.append(ks.card(-1.2, 1.5, ground + 0.02, 1.8, 2.0, "glass_dark"))
    shapes.append(ks.card(-1.2, 1.5, ground + 0.06, 1.8, 2.0, "window_grille"))

    # Granite: quoins at the front's corners, a band at every floor, a
    # cornice under the eaves.
    for s in (-1.0, 1.0):
        shapes.append(ks.box(s * (WIDTH / 2.0 - 0.2), GROUND + height / 2.0, FRONT + 0.06, 0.4, height, 0.14, "granite"))

    for storey in range(storeys):
        y0 = GROUND + storey * STOREY
        shapes.append(ks.box(0.0, y0 + 0.02, FRONT + 0.07, WIDTH, 0.18, 0.12, "granite"))
        on_balcony = balconies == "all" or storey == storeys - 1

        for i, x in enumerate((-1.4, 1.4)):
            shapes += _window(x, y0, (storey + 1, i) in lit, on_balcony)

            if on_balcony:
                bw, bt, bd = BALCONY
                cols.append(col(x, y0 - bt / 2.0, FRONT + bd / 2.0, bw, bt, bd))

    shapes.append(ks.box(0.0, eaves - 0.18, FRONT + 0.15, WIDTH + 0.2, 0.36, 0.5, "granite"))

    # The roof: Spanish tiles at 20 degrees, its eaves to the quay and the
    # back, its gables to the neighbours; a chimney at the back.
    shapes += ks.moved(k.pitched(WIDTH, DEPTH, rise, slot="roof_spanish", under="boards", tile=2.0, overhang=0.5, verge=0.08), 0.0, (0.0, eaves, 0.0))

    for s in (-1.0, 1.0):
        shapes.append(ks.gable(s * (WIDTH / 2.0 - 0.1), eaves, 0.0, DEPTH, rise, 0.2, side, 90.0))

    slope = math.hypot(FRONT, rise)
    lift = k.ROOF_THICK / 2.0 / math.cos(math.radians(PITCH))

    for s in (-1.0, 1.0):
        cols.append(col(0.0, eaves + rise / 2.0 + lift, s * FRONT / 2.0, WIDTH, k.ROOF_THICK, slope, 0.0, s * PITCH))

    top = eaves + rise + 1.0
    shapes += kit_houses._chimney(chimney * 1.8, -FRONT + 1.5, top, side)[:2]
    return shapes, cols, [WIDTH + 0.4, top + 0.3, 2.0 * (FRONT + BALCONY[2])], eaves


# The eight: storeys over the arcade, their fronts and sides, which have
# balconies all the way up, which windows are lit.
CASAS = {
    "casa_a": dict(storeys=5, front="azulejo_green", side="render_ochre", balconies="all", lit=[(2, 0), (4, 1)], chimney=1.0),
    "casa_b": dict(storeys=4, front="azulejo_cube", side="whitewash", balconies="top", lit=[(3, 1)], chimney=-1.0),
    "casa_c": dict(storeys=6, front="azulejo_blue", side="render_salmon", balconies="all", lit=[(1, 1), (5, 0)], chimney=1.0),
    "casa_d": dict(storeys=3, front="render_ochre", side="render_ochre", balconies="all", lit=[(2, 1)], chimney=-1.0),
    "casa_e": dict(storeys=5, front="render_salmon", side="render_salmon", balconies="top", lit=[], chimney=1.0),
    "casa_f": dict(storeys=4, front="render_blue", side="whitewash", balconies="all", lit=[(1, 0), (4, 0)], chimney=-1.0),
    "casa_g": dict(storeys=6, front="whitewash", side="whitewash", balconies="top", lit=[(6, 1)], chimney=1.0),
    "casa_h": dict(storeys=4, front="azulejo_blue2", side="render_blue", balconies="top", lit=[(2, 0)], chimney=-1.0),
}

for _name, _spec in CASAS.items():
    _shapes, _cols, _size, _eaves = casa(**_spec)
    k.piece(_name, "casa", _spec["front"], "stone", [], cols=_cols, size=_size)
    k.model(_name, _shapes)
    k.PIECES[_name]["budget"] = CASA_TRIS
    k.PIECES[_name]["front"] = FRONT
    k.PIECES[_name]["door"] = list(DOOR)
    k.PIECES[_name]["eaves"] = _eaves


def _iberian(name, slot, shapes, cols, size, budget=None):
    k.piece(name, "iberian", slot, "stone", [], cols=cols, size=size)
    k.model(name, shapes)

    if budget:
        k.PIECES[name]["budget"] = budget


# ---------------------------------------------------------------------------
# The Ribeira's arcade: a bay of low heavy granite (a segmental arch 4.4 m
# wide on piers, 2.6 m to its springing), a barrel vault over the walkway
# behind it. Its pivot is the middle of the walkway (the arch at +z), the
# house's ground floor at its back.
# ---------------------------------------------------------------------------

def _arcade():
    width, height, walk = 6.0, GROUND, ARCADE
    arch_z = walk / 2.0 - 0.45
    shapes = ks.arched_wall(width, height, 0.9, 4.4, 2.6, 0.8, 0.0, "granite", z=arch_z)
    span = walk - 0.9
    rise = 0.5
    radius = ((span / 2.0) ** 2 + rise ** 2) / (2.0 * rise)
    crown = 3.4
    spring = math.degrees(math.asin((span / 2.0) / radius))
    walk_mid = (arch_z - 0.45 - walk / 2.0) / 2.0
    shapes.append(ks.ring(0.0, crown - radius, walk_mid, radius, radius + 0.25, width, 90.0 - spring, 90.0 + spring, 4, "granite", 90.0))
    # (Solid over the vault: the house's first floor stands on it.)
    cols = [col(-(2.2 + 0.4), height / 2.0, arch_z, 0.8, height, 0.9), col(2.2 + 0.4, height / 2.0, arch_z, 0.8, height, 0.9),
            col(0.0, 3.5, arch_z, 4.4, 0.2, 0.9), col(0.0, 3.5, walk_mid, width, 0.2, span)]
    return shapes, cols


_shapes, _cols = _arcade()
_iberian("arcade_ribeira_6", "granite", _shapes, _cols, [6.0, GROUND, ARCADE], budget=600)


# ---------------------------------------------------------------------------
# The Terreiro: a bay of its arcade (round arches 6 m high in Lisbon's
# yellow, granite dressings, a walkway 4 m deep, rooms behind; a balconied
# window over each arch, a cornice, a low roof), and the corner where two
# arcades meet. Pivot: the bay's middle on the ground, the arches at +z.
# ---------------------------------------------------------------------------

BAY = {"width": 6.0, "arcade": 6.5, "top": 11.0, "depth": 8.0, "walk": 4.0, "opening": 4.0, "spring": 4.0}


def _upper_window(x, z, y0, yaw=0.0):
    w, h = 1.2, 2.6
    out = [ks.card(x, y0 + 0.1 + h / 2.0, z + 0.02, w, h, "glass_dark")]
    out += _frame(x, y0 + 0.1, z, w, h)
    out.append(ks.box(x, y0 - 0.08, z + 0.4, w + 0.6, 0.16, 0.8, "granite"))
    out.append(ks.card(x, y0 + 0.45, z + 0.78, w + 0.5, 0.9, "iron_rail"))
    return ks.moved(out, yaw) if yaw else out


def _terreiro_bay():
    b = BAY
    front = b["depth"] / 2.0
    arch_z = front - 0.5
    shapes = ks.arched_wall(b["width"], b["arcade"], 1.0, b["opening"], b["spring"], b["opening"] / 2.0, 0.0, "render_ochre", z=arch_z)
    shapes.append(ks.ring(0.0, b["spring"], front + 0.04, b["opening"] / 2.0, b["opening"] / 2.0 + 0.45, 0.1, 0.0, 180.0, 6, "granite"))

    for s in (-1.0, 1.0):
        shapes.append(ks.box(s * (b["width"] / 2.0 - 0.25), b["top"] / 2.0, front + 0.06, 0.5, b["top"], 0.14, "granite"))
        shapes.append(ks.box(s * (b["opening"] / 2.0 + 0.25), b["spring"] - 0.12, front + 0.06, 0.6, 0.24, 0.16, "granite"))

    upper = b["top"] - b["arcade"]
    back = b["depth"] - b["walk"] - 1.0
    shapes += [ks.box(0.0, b["arcade"] + upper / 2.0, 0.0, b["width"], upper, b["depth"], "render_ochre"),
               ks.box(0.0, b["arcade"] / 2.0, -front + back / 2.0, b["width"], b["arcade"], back, "render_ochre"),
               ks.box(0.0, b["arcade"] - 0.25, arch_z - 0.5 - b["walk"] / 2.0, b["width"], 0.5, b["walk"], "render_ochre"),
               ks.box(0.0, b["top"] - 0.2, front + 0.2, b["width"] + 0.1, 0.4, 0.6, "granite"),
               ks.box(0.0, b["arcade"], front + 0.07, b["width"], 0.2, 0.14, "granite"),
               ks.card(1.4, 1.1, -front + back + 0.02, 1.2, 2.2, "door_2")]
    shapes += _frame(1.4, 0.0, -front + back, 1.2, 2.2)
    shapes += _upper_window(0.0, front, b["arcade"])
    shapes += ks.moved(k.pitched(b["width"], b["depth"], 2.0, slot="roof_spanish", under="boards", tile=2.0, overhang=0.35, verge=0.05), 0.0,
                       (0.0, b["top"], 0.0))
    walk_mid = arch_z - 0.5 - b["walk"] / 2.0
    cols = [col(-(b["opening"] / 2.0 + (b["width"] - b["opening"]) / 4.0), b["arcade"] / 2.0, arch_z, (b["width"] - b["opening"]) / 2.0,
                b["arcade"], 1.0),
            col(b["opening"] / 2.0 + (b["width"] - b["opening"]) / 4.0, b["arcade"] / 2.0, arch_z, (b["width"] - b["opening"]) / 2.0,
                b["arcade"], 1.0),
            col(0.0, (b["arcade"] + b["spring"] + b["opening"] / 2.0) / 2.0, arch_z, b["opening"], b["arcade"] - b["spring"] - b["opening"] / 2.0, 1.0),
            col(0.0, b["arcade"] + upper / 2.0, 0.0, b["width"], upper, b["depth"]),
            col(0.0, b["arcade"] / 2.0, -front + back / 2.0, b["width"], b["arcade"], back),
            col(0.0, b["arcade"] - 0.25, walk_mid, b["width"], 0.5, b["walk"]),
            col(0.0, b["arcade"] - 0.08, front + 0.4, 1.8, 0.16, 0.8)]
    return shapes, cols


def _terreiro_corner():
    """The corner where two arcades meet: arches on +z and on +x, the
    walkway turning the corner behind them, a room in the corner, the
    storey over it all under a hipped roof."""
    b = BAY
    size = 8.0
    half = size / 2.0
    shapes, cols = [], []

    for yaw in (0.0, 90.0):
        shapes += ks.arched_wall(size, b["arcade"], 1.0, b["opening"], b["spring"], b["opening"] / 2.0, 0.0, "render_ochre", z=half - 0.5,
                                 yaw=yaw)
        face = [ks.ring(0.0, b["spring"], half + 0.04, b["opening"] / 2.0, b["opening"] / 2.0 + 0.45, 0.1, 0.0, 180.0, 6, "granite"),
                ks.box(0.0, b["top"] - 0.2, half + 0.2, size + 0.1, 0.4, 0.6, "granite"),
                ks.box(0.0, b["arcade"], half + 0.07, size, 0.2, 0.14, "granite")]
        face += _upper_window(0.0, half, b["arcade"])
        shapes += ks.moved(face, yaw)
        # Piers either side of its arch, the band over it.
        side = (size - b["opening"]) / 2.0

        for s in (-1.0, 1.0):
            centre = ks.moved([ks.box(s * (b["opening"] / 2.0 + side / 2.0), 0.0, half - 0.5, 1.0, 1.0, 1.0, "stone")], yaw)[0]["centre"]
            cols.append(col(centre[0], b["arcade"] / 2.0, centre[2], side, b["arcade"], 1.0, yaw))

        centre = ks.moved([ks.box(0.0, 0.0, half - 0.5, 1.0, 1.0, 1.0, "stone")], yaw)[0]["centre"]
        cols.append(col(centre[0], (b["arcade"] + b["spring"] + b["opening"] / 2.0) / 2.0, centre[2], b["opening"],
                        b["arcade"] - b["spring"] - b["opening"] / 2.0, 1.0, yaw))

    # The corner's granite quoin, the room at the back corner, the ceiling
    # over the turning walkway, the storey over all, a hipped roof.
    shapes.append(ks.box(half - 0.25, b["top"] / 2.0, half - 0.25, 0.5, b["top"], 0.5, "granite"))
    upper = b["top"] - b["arcade"]
    shapes += [ks.box(-half / 2.0, b["arcade"] / 2.0, -half / 2.0, half, b["arcade"], half, "render_ochre"),
               ks.box(0.0, b["arcade"] + upper / 2.0, 0.0, size, upper, size, "render_ochre"),
               ks.box(0.0, b["arcade"] - 0.25, 0.0, size, 0.5, size, "render_ochre"),
               ks.prism(0.0, b["top"] + 1.1, 0.0, half * math.sqrt(2.0) + 0.4, 2.2, 4, "roof_spanish", yaw=45.0, top=0.0)]
    cols += [col(-half / 2.0, b["arcade"] / 2.0, -half / 2.0, half, b["arcade"], half),
             col(0.0, b["arcade"] + upper / 2.0, 0.0, size, upper, size),
             col(0.0, b["arcade"] - 0.25, 0.0, size, 0.5, size)]
    return shapes, cols


_shapes, _cols = _terreiro_bay()
_iberian("terreiro_bay_6", "render_ochre", _shapes, _cols, [BAY["width"] + 0.2, BAY["top"] + 2.4, BAY["depth"] + 1.6], budget=1000)
_shapes, _cols = _terreiro_corner()
_iberian("terreiro_corner", "render_ochre", _shapes, _cols, [9.6, BAY["top"] + 2.4, 9.6], budget=1000)


# ---------------------------------------------------------------------------
# The water stair and its two columns (the Cais das Colunas), the granite
# flights of the Guindais stair with their landings and parapets.
# ---------------------------------------------------------------------------

def _columns():
    shapes, cols = [], []

    for x in (-7.0, 7.0):
        shapes += [ks.box(x, 0.7, 0.0, 1.6, 1.4, 1.6, "ashlar_gold"), ks.box(x, 1.5, 0.0, 1.3, 0.2, 1.3, "ashlar_gold"),
                   ks.prism(x, 1.6 + 2.5, 0.0, 0.5, 5.0, 8, "ashlar_gold", top=0.44),
                   ks.lathe(x, 6.6, 0.0, [[0.44, 0.0], [0.62, 0.3], [0.62, 0.45]], 8, "ashlar_gold"),
                   ks.box(x, 7.12, 0.0, 1.2, 0.25, 1.2, "ashlar_gold"),
                   ks.lathe(x, 7.25, 0.0, [[0.25, 0.0], [0.35, 0.2], [0.3, 0.45], [0.0, 0.6]], 8, "ashlar_gold")]
        cols += [col(x, 0.8, 0.0, 1.6, 1.6, 1.6), col(x, 4.1, 0.0, 0.9, 5.0, 0.9)]

    return shapes, cols


_shapes, _cols = _columns()
_iberian("cais_colunas", "ashlar_gold", _shapes, _cols, [16.2, 7.9, 1.8], budget=400)

# The water stair: 17 steps of 0.2 down to +z from the square's edge (its
# top step 0.2 under the square) into the sea, solid down to the sea bed.
_steps = 17
_water = [k.box(0.0, (2.3 - 0.2 * i - 1.5) / 2.0, -_steps * k.TREAD / 2.0 + (i + 0.5) * k.TREAD, 20.0, 2.3 - 0.2 * i + 1.5, k.TREAD, "granite")
          for i in range(_steps)]
k.piece("water_stair_20", "iberian", "granite", "stone", _water, size=[20.0, 3.8, _steps * k.TREAD])

# A Guindais flight: 10 risers of 0.2 up to +z from its foot (its pivot), 3 m
# wide, solid 4 m down (the slope it climbs); a landing (its top at the
# pivot) and a parapet along a flight's side.
k.piece("granite_flight_3", "iberian", "granite", "stone",
        [k.box(0.0, ((i + 1) * k.RISER - 4.0) / 2.0, i * k.TREAD + k.TREAD / 2.0, 3.0, (i + 1) * k.RISER + 4.0, k.TREAD, "granite") for i in range(10)],
        size=[3.0, 2.0, 10 * k.TREAD])
k.piece("granite_landing_3", "iberian", "granite", "stone", [k.box(0.0, -2.0, 0.0, 3.0, 4.0, 3.0, "granite")], size=[3.0, 4.0, 3.0])
_rake = math.degrees(math.atan2(2.0, 3.0))
k.piece("granite_parapet_3", "iberian", "granite", "stone",
        [k.box(0.0, 1.0 + 0.55, 1.5, 0.3, 1.1, math.hypot(3.0, 2.0) + 0.1, "granite", 0.0, -_rake, 0.0)], size=[0.3, 3.2, 3.2])


# ---------------------------------------------------------------------------
# The king on his horse (bronze) on a stone pedestal; a wall shrine (an
# alminha: a tiled panel of the souls, a niche for a candle).
# ---------------------------------------------------------------------------

def _statue():
    shapes = [ks.box(0.0, 1.0, 0.0, 3.2, 2.0, 5.2, "granite"), ks.box(0.0, 2.6, 0.0, 2.6, 1.2, 4.4, "ashlar_gold"),
              ks.box(0.0, 3.35, 0.0, 2.9, 0.3, 4.7, "ashlar_gold"),
              # the horse, walking, its head up
              ks.box(0.0, 5.0, 0.0, 0.8, 0.9, 2.1, "brass"), ks.box(0.0, 5.75, 1.05, 0.45, 1.1, 0.5, "brass", 0.0, -35.0, 0.0),
              ks.box(0.0, 6.2, 1.45, 0.35, 0.35, 0.7, "brass", 0.0, 20.0, 0.0), ks.box(0.0, 5.2, -1.2, 0.2, 0.8, 0.2, "brass", 0.0, 25.0, 0.0)]

    for x, z, lift in ((-0.25, 0.8, 0.3), (0.25, 0.7, 0.0), (-0.25, -0.8, 0.0), (0.25, -0.75, 0.15)):
        shapes.append(ks.prism(x, 3.5 + 0.55 + lift / 2.0, z + lift * 0.5, 0.1, 1.1 - lift, 5, "brass", pitch=lift * 60.0))

    # the king: seated, cloaked, crowned, his sceptre raised
    shapes += [ks.box(0.0, 6.05, -0.1, 0.5, 0.8, 0.4, "brass"), ks.lathe(0.0, 6.45, -0.05, [[0.14, 0.0], [0.16, 0.2], [0.12, 0.3], [0.0, 0.34]], 6, "brass"),
               ks.lathe(0.0, 6.72, -0.05, [[0.15, 0.0], [0.17, 0.12]], 6, "brass", caps=False),
               ks.slab([[-0.35, 6.4, -0.3], [0.35, 6.4, -0.3], [0.5, 5.2, -0.65], [-0.5, 5.2, -0.65]], 0.06, "brass", up=(0.0, 0.3, -1.0)),
               ks.box(0.3, 6.3, 0.15, 0.12, 0.5, 0.12, "brass", 0.0, 40.0, 0.0), ks.prism(0.34, 6.8, 0.4, 0.03, 0.9, 4, "brass", pitch=25.0)]
    return shapes, [col(0.0, 1.75, 0.0, 3.2, 3.5, 5.2)]


def _alminha():
    shapes = [ks.box(0.0, 1.4, 0.0, 1.0, 1.6, 0.25, "ashlar_gold"), ks.card(0.0, 1.45, 0.13, 0.7, 0.9, "azulejo_blue"),
              ks.gable(0.0, 2.2, 0.02, 1.1, 0.35, 0.3, "ashlar_gold"), ks.box(0.0, 0.85, 0.15, 0.8, 0.08, 0.3, "ashlar_gold"),
              ks.prism(0.0, 0.95, 0.18, 0.04, 0.14, 6, "wax")]
    return shapes


_shapes, _cols = _statue()
_iberian("statue_king", "brass", _shapes, _cols, [3.4, 7.2, 5.4], budget=1200)
_iberian("alminha", "ashlar_gold", _alminha(), [], [1.1, 2.6, 0.6], budget=200)
