"""The old town's street furniture (its spec, sections 4.4, 7.4 and 16;
old_town_lisbon.md sections 7 and 14, old_town_porto.md section 14,
old_town_spain.md section 9.3): pure data, as kit_recipes (which imports
this at its end).

    corner_lamp     a curved iron arm on a corner ARM_HEIGHT up, a cross-bar
                    at its end: sockets "lamp", where the layout hangs two
                    lanterns (light markers, dark_only: the moon decides)
    shrine_alminha  a shrine NICHE on a wall, the forgotten king painted on
                    the wall's face in a granite surround standing out from
                    it, its votive lamp's socket on its sill
    shrine_retablo  a panel of the comet under a little tiled roof, a lantern
                    over it at 2.5 m
    panel_comet     4 x 6 azulejos (TILE) in a one-tile frame: the city
    panel_king      under the red comet; the forgotten king as a saint
    fountain_carmo  four arches on Tuscan pillars over a two-step round
                    platform, four spouts, two curved tanks
    fountain_wall   a wall fountain: a stone back, its spout, a basin
    fountain_bowls  the Rossio's: two steps, a coped basin round its water,
                    a baluster and a thick upper bowl

Wall pieces stand on their wall at z 0, facing +z; the others about their
middle. Each fountain's "water" socket is where the layout puts its noise
zone (it masks the player near it). The paintings are ours
(tools/textures/paint.py).
"""

import math

import kit_recipes as k
import kit_shapes as ks
import kit_town as town

ARM_HEIGHT = 3.6
ARM_OUT = 0.9
TILE = 0.14
NICHE = (0.6, 0.9)
NICHE_SILL = 1.6
RETABLO = (2 * TILE, 3 * TILE)


def _piece(name, family, slot, shapes, cols, size, budget, sockets=None):
    town.register(name, family, slot, {"shapes": shapes, "cols": cols, "size": size, "budget": budget})
    k.PIECES[name]["sockets"] = sockets or {}


def _round_cols(r, y0, y1, n, yaw=0.0, x=0.0, z=0.0):
    """The colliders of an upright prism as ks.prism draws it (`r` to its
    corners, `n` sides, its first corner at 0 degrees, turned `yaw`) from
    y0 to y1: a strip across each pair of opposite flats, as wide as a
    flat, so solid exactly where it is drawn."""
    apothem = r * math.cos(math.pi / n)
    flat = 2.0 * r * math.sin(math.pi / n)
    out = []

    for k in range(n // 2):
        theta = math.degrees((2 * k + 1) * math.pi / n)
        out.append(town.col(x, (y0 + y1) / 2.0, z, 2.0 * apothem, y1 - y0, flat, "stone", yaw - theta))

    return out


def _taper_cols(r0, r1, y0, y1, n, yaw=0.0, x=0.0, z=0.0, step=0.12):
    """A prism tapering from `r0` at y0 to `r1` at y1 (a dome, a little
    pyramid roof) collided in tiers no higher than `step`, each as wide as
    the taper at its top (never out past what is drawn), over a thin tier at
    its foot as wide as its foot."""
    out = _round_cols(r0, y0, y0 + 0.02, n, yaw, x, z)
    tiers = max(1, int(math.ceil((y1 - y0) / step - 1e-9)))

    for i in range(tiers):
        a, b = y0 + (y1 - y0) * i / tiers, y0 + (y1 - y0) * (i + 1) / tiers
        out += _round_cols(r0 + (r1 - r0) * (b - y0) / (y1 - y0), a, b, n, yaw, x, z)

    return out


def _gable_cols(width, y0, rise, depth, z=0.0, step=0.1):
    """A gable (ks.gable: `width` across, `rise` to its apex, `depth` thick)
    collided in tiers as wide as it is at each tier's top, over a thin tier
    as wide as its foot."""
    out = [town.col(0.0, y0 + 0.01, z, width, 0.02, depth)]
    tiers = max(1, int(math.ceil(rise / step - 1e-9)))

    for i in range(tiers):
        a, b = y0 + rise * i / tiers, y0 + rise * (i + 1) / tiers
        out.append(town.col(0.0, (a + b) / 2.0, z, width * (1.0 - (b - y0) / rise) + 1e-3, b - a, depth))

    return out


def _corner_lamp():
    """The arm: a plate on the wall, the arm curving out and up from it, a
    cross-bar at its end with a hook at each side."""
    y, out = ARM_HEIGHT, ARM_OUT
    shapes = [ks.box(0.0, y - 0.3, 0.02, 0.18, 0.7, 0.04, "iron"), ks.box(0.0, y, out / 2.0, 0.05, 0.05, out, "iron"),
              ks.box(0.0, y - 0.2, out * 0.3, 0.04, 0.04, out * 0.7, "iron", 0.0, 32.0, 0.0),
              ks.box(0.0, y + 0.02, out, 0.9, 0.05, 0.05, "iron")]
    shapes += [ks.box(s * 0.4, y - 0.06, out, 0.03, 0.12, 0.03, "iron") for s in (-1.0, 1.0)]
    hooks = [[s * 0.4, y - 0.12, out] for s in (-1.0, 1.0)]
    # (Its plate, arm, brace and cross-bar solid as drawn: what is thrown at
    # it, or swung, rings off it.)
    cols = [town.col(0.0, y - 0.3, 0.02, 0.18, 0.7, 0.04), town.col(0.0, y, out / 2.0, 0.05, 0.05, out),
            town.col(0.0, y - 0.2, out * 0.3, 0.04, 0.04, out * 0.7, "stone", 0.0, 32.0), town.col(0.0, y + 0.02, out, 0.9, 0.05, 0.05)]
    return shapes, cols, hooks


def _frame(width, height, z):
    """A one-tile frame of the painted strip round width x height on z."""
    t = TILE
    out = [ks.card(0.0, height + t / 2.0, z, width + 2.0 * t, t, "tile_frame"), ks.card(0.0, -t / 2.0, z, width + 2.0 * t, t, "tile_frame")]

    # (Its sides upright: the strip's length turned to run up them.)
    for s in (-1.0, 1.0):
        x0, x1 = s * width / 2.0, s * (width / 2.0 + t)
        lo, hi = sorted((x0, x1))
        out.append(ks.polygon([[lo, 0.0, z], [hi, 0.0, z], [hi, height, z], [lo, height, z]], "tile_frame",
                              [[0.0, 1.0], [0.0, 0.0], [1.0, 0.0], [1.0, 1.0]]))

    return out


def _panel(slot):
    """4 x 6 tiles on the wall, their foot at 0, in a one-tile frame."""
    w, h = 4 * TILE, 6 * TILE
    return [ks.card(0.0, h / 2.0, 0.02, w, h, slot)] + _frame(w, h, 0.02)


def _alminha():
    """A shrine on a wall (its face at z 0): the forgotten king painted on
    the wall's face, a granite surround and a sill standing out round him,
    a sill for the votive lamp before him."""
    w, h = NICHE
    y = NICHE_SILL
    d = 0.2
    shapes = [ks.box(0.0, y + h / 2.0, 0.006, w, h, 0.012, "pitch"), ks.card(0.0, y + h / 2.0, 0.015, w * 0.9, h * 0.9, "azulejo_souls"),
              ks.box(-w / 2.0 - 0.06, y + h / 2.0, d / 2.0, 0.12, h + 0.2, d, "granite"), ks.box(w / 2.0 + 0.06, y + h / 2.0, d / 2.0, 0.12, h + 0.2, d, "granite"),
              ks.box(0.0, y + h + 0.06, d / 2.0, w + 0.24, 0.12, d, "granite"), ks.box(0.0, y - 0.05, 0.14, w + 0.3, 0.1, 0.28, "granite")]
    # (Its surround and sill solid as drawn.)
    cols = [town.col(-w / 2.0 - 0.06, y + h / 2.0, d / 2.0, 0.12, h + 0.2, d), town.col(w / 2.0 + 0.06, y + h / 2.0, d / 2.0, 0.12, h + 0.2, d),
            town.col(0.0, y + h + 0.06, d / 2.0, w + 0.24, 0.12, d), town.col(0.0, y - 0.05, 0.14, w + 0.3, 0.1, 0.28)]
    return shapes, cols, [[0.0, y + 0.02, 0.14]]


def _retablo():
    """A panel of the comet under a little four-faced tiled roof on its
    wall, a lantern's hook over it at 2.5 m."""
    w, h = RETABLO
    y = 1.7
    shapes = [ks.card(0.0, y + h / 2.0, 0.02, w, h, "azulejo_comet")] + ks.moved(_frame(w, h, 0.02), offset=(0.0, y, 0.0))
    roof_y = y + h + TILE + 0.12
    shapes.append(ks.prism(0.0, roof_y, 0.12, 0.36, 0.22, 4, "roof_spanish", 45.0, 0.0, 0.0, top=0.05))
    shapes += [ks.box(0.0, 2.5 + 0.12, 0.08, 0.04, 0.04, 0.16, "iron")]
    # (Its little roof solid as drawn.)
    cols = _taper_cols(0.36, 0.05, roof_y - 0.11, roof_y + 0.11, 4, 45.0, 0.0, 0.12)
    return shapes, cols, [[0.0, 2.5, 0.16]]


def _carmo():
    """The dolphin fountain under its canopy: a two-step round platform,
    four Tuscan pillars round it under an entablature and a low dome, two
    curved tanks between the pillars, four spouts."""
    shapes = [ks.prism(0.0, 0.1, 0.0, 3.0, 0.2, 12, "granite"), ks.prism(0.0, 0.3, 0.0, 2.6, 0.2, 12, "granite")]
    # (Every part solid as drawn: the round steps as round, the dome in
    # tiers.)
    cols = _round_cols(3.0, 0.0, 0.2, 12) + _round_cols(2.6, 0.2, 0.4, 12)

    for sx in (-1.0, 1.0):
        for sz in (-1.0, 1.0):
            x, z = sx * 1.7, sz * 1.7
            shapes += [ks.prism(x, 0.4 + 1.4, z, 0.2, 2.8, 8, "ashlar"), ks.box(x, 0.4 + 0.1, z, 0.5, 0.2, 0.5, "granite"),
                       ks.box(x, 3.3, z, 0.5, 0.2, 0.5, "granite")]
            cols += [town.col(x, 0.5, z, 0.5, 0.2, 0.5), town.col(x, 3.3, z, 0.5, 0.2, 0.5)] + _round_cols(0.2, 0.6, 3.2, 8, 0.0, x, z)

    shapes += [ks.box(0.0, 3.55, 0.0, 4.2, 0.3, 4.2, "ashlar"), ks.prism(0.0, 4.2, 0.0, 2.2, 1.0, 12, "ashlar", top=0.4),
                ks.prism(0.0, 4.9, 0.0, 0.2, 0.5, 8, "granite")]
    cols += [town.col(0.0, 3.55, 0.0, 4.2, 0.3, 4.2)] + _taper_cols(2.2, 0.4, 3.7, 4.7, 12) + _round_cols(0.2, 4.65, 5.15, 8)

    for s in (-1.0, 1.0):
        shapes.append(ks.box(s * 0.0, 0.75, s * 1.0, 2.6, 0.7, 0.8, "granite"))
        cols.append(town.col(0.0, 0.75, s * 1.0, 2.6, 0.7, 0.8))
        shapes.append(ks.box(0.0, 1.2, s * 0.55, 0.16, 0.16, 0.3, "brass"))
        shapes.append(ks.box(s * 0.55, 1.2, 0.0, 0.3, 0.16, 0.16, "brass"))
        cols += [town.col(0.0, 1.2, s * 0.55, 0.16, 0.16, 0.3), town.col(s * 0.55, 1.2, 0.0, 0.3, 0.16, 0.16)]

    return shapes, cols, [[0.0, 0.8, 0.0]]


def _wall_fountain():
    """A wall fountain: its stone back under a pediment, a mask spouting
    into a basin before it."""
    shapes = [ks.box(0.0, 1.3, 0.15, 2.4, 2.6, 0.3, "ashlar"), ks.gable(0.0, 2.6, 0.15, 2.6, 0.5, 0.32, "granite"),
              ks.box(0.0, 1.5, 0.34, 0.3, 0.3, 0.1, "brass"), ks.box(0.0, 0.4, 0.75, 2.0, 0.8, 0.9, "granite"),
              ks.box(0.0, 0.79, 0.75, 1.8, 0.02, 0.7, "glass_dark")]
    # (Its pediment and mask solid as drawn.)
    cols = [town.col(0.0, 1.3, 0.15, 2.4, 2.6, 0.3), town.col(0.0, 0.4, 0.75, 2.0, 0.8, 0.9), town.col(0.0, 1.5, 0.34, 0.3, 0.3, 0.1)]
    cols += _gable_cols(2.6, 2.6, 0.5, 0.32, 0.15)
    return shapes, cols, [[0.0, 0.8, 0.75]]


# The Rossio's fountain (m): its two steps' corners out and their rise; its
# basin's rim wall's corners out, its thickness, the rim's top, the water's
# level.
BOWLS_STEPS = (3.4, 3.0, 0.18)
BOWLS_BASIN = (2.6, 0.3, 1.06, 0.9)


def _ring_wall(r, t, y0, y1, n, slot):
    """An n-sided ring wall, `r` to its outer corners, `t` thick, from y0 to
    y1: a box along each side (the same boxes its colliders)."""
    apothem = r * math.cos(math.pi / n)
    side = 2.0 * r * math.sin(math.pi / n)
    shapes, cols = [], []

    for k in range(n):
        theta = (2 * k + 1) * math.pi / n
        rc = apothem - t / 2.0
        x, z = rc * math.cos(theta), rc * math.sin(theta)
        yaw = 90.0 - math.degrees(theta)
        shapes.append(ks.box(x, (y0 + y1) / 2.0, z, side, y1 - y0, t, slot, yaw))
        cols.append(town.col(x, (y0 + y1) / 2.0, z, side, y1 - y0, t, "stone", yaw))

    return shapes, cols


def _bowls():
    """The Rossio's fountain: on two octagonal steps, an octagonal basin,
    its coped rim wall round water standing below it; in the middle a
    pedestal, a bellied baluster and a thick upper bowl holding its own
    water, a pine-cone finial; solid as drawn."""
    s0, s1, step = BOWLS_STEPS
    r, t, rim, water = BOWLS_BASIN
    floor = 2.0 * step + 0.14
    shapes = [ks.prism(0.0, step / 2.0, 0.0, s0, step, 8, "granite"), ks.prism(0.0, step * 1.5, 0.0, s1, step, 8, "granite"),
              ks.prism(0.0, (2.0 * step + floor) / 2.0, 0.0, r - t + 0.05, floor - 2.0 * step, 8, "stone_moss"),
              ks.prism(0.0, water, 0.0, r - t + 0.02, 0.02, 8, "glass_dark")]
    cols = _round_cols(s0, 0.0, step, 8) + _round_cols(s1, step, 2.0 * step, 8) + _round_cols(r - t + 0.05, 2.0 * step, floor, 8)
    wall_shapes, wall_cols = _ring_wall(r, t, 2.0 * step, rim - 0.06, 8, "granite")
    # (The rim's coping, a little proud of the wall either side.)
    cope_shapes, cope_cols = _ring_wall(r + 0.05, t + 0.1, rim - 0.06, rim, 8, "granite")
    shapes += wall_shapes + cope_shapes
    cols += wall_cols + cope_cols
    # (The pedestal, the baluster bellied in its middle, the upper bowl as
    # a dish with a thickness, its water, the finial.)
    shapes += [ks.prism(0.0, floor + 0.35, 0.0, 0.55, 0.7, 8, "granite"),
               ks.prism(0.0, floor + 0.7 + 0.6, 0.0, 0.2, 1.2, 8, "granite", rings=[[0.35, 0.3], [0.65, 0.3]]),
               ks.lathe(0.0, floor + 1.9, 0.0, [[0.18, 0.0], [0.95, 0.24], [1.05, 0.3], [0.95, 0.32], [0.18, 0.1]], 8, "granite", closed=True),
               ks.prism(0.0, floor + 1.9 + 0.27, 0.0, 0.92, 0.02, 8, "glass_dark"),
               ks.prism(0.0, floor + 1.9 + 0.32 + 0.25, 0.0, 0.14, 0.5, 8, "granite", top=0.02)]
    cols += _round_cols(0.55, floor, floor + 0.7, 8) + _round_cols(0.3, floor + 0.7, floor + 1.9, 8)
    cols += _round_cols(1.05, floor + 1.9, floor + 2.12, 8) + _taper_cols(0.14, 0.02, floor + 2.22, floor + 2.72, 8)
    return shapes, cols, [[0.0, water, 0.0]]


_shapes, _cols, _hooks = _corner_lamp()
_piece("corner_lamp", "street", "iron", _shapes, _cols, [1.0, ARM_HEIGHT + 0.2, ARM_OUT], 300, {"lamp": _hooks})
_shapes, _cols, _lamp = _alminha()
_piece("shrine_alminha", "street", "granite", _shapes, _cols, [NICHE[0] + 0.3, NICHE_SILL + NICHE[1] + 0.2, 0.3], 300, {"lamp": _lamp})
_shapes, _cols, _lamp = _retablo()
_piece("shrine_retablo", "street", "azulejo_comet", _shapes, _cols, [0.8, 2.8, 0.4], 300, {"lamp": _lamp})
_piece("panel_comet", "street", "azulejo_comet", _panel("azulejo_comet"), [], [4 * TILE + 2 * TILE, 8 * TILE, 0.05], 120)
_piece("panel_king", "street", "azulejo_king", _panel("azulejo_king"), [], [4 * TILE + 2 * TILE, 8 * TILE, 0.05], 120)
_shapes, _cols, _water = _carmo()
_piece("fountain_carmo", "street", "ashlar", _shapes, _cols, [6.0, 5.2, 6.0], 2000, {"water": _water})
_shapes, _cols, _water = _wall_fountain()
_piece("fountain_wall", "street", "ashlar", _shapes, _cols, [2.6, 3.1, 1.3], 500, {"water": _water})
_shapes, _cols, _water = _bowls()
_piece("fountain_bowls", "street", "granite", _shapes, _cols, [6.8, 3.4, 6.8], 900, {"water": _water})
