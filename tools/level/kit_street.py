"""The old town's street furniture (its spec, sections 4.4, 7.4 and 16;
old_town_lisbon.md sections 7 and 14, old_town_porto.md section 14,
old_town_spain.md section 9.3): pure data, as kit_recipes (which imports
this at its end).

    corner_lamp     a curved iron arm on a corner ARM_HEIGHT up, a cross-bar
                    at its end: sockets "lamp", where the layout hangs two
                    lanterns (light markers, dark_only: the moon decides)
    shrine_alminha  a niche NICHE in a wall, the forgotten king painted in
                    it, its votive lamp's socket on its sill
    shrine_retablo  a panel of the comet under a little tiled roof, a lantern
                    over it at 2.5 m
    panel_comet     4 x 6 azulejos (TILE) in a one-tile frame: the city
    panel_king      under the red comet; the forgotten king as a saint
    fountain_carmo  four arches on Tuscan pillars over a two-step round
                    platform, four spouts, two curved tanks
    fountain_wall   a wall fountain: a stone back, its spout, a basin
    fountain_bowls  a basin, a column and its upper bowl

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


def _corner_lamp():
    """The arm: a plate on the wall, the arm curving out and up from it, a
    cross-bar at its end with a hook at each side."""
    y, out = ARM_HEIGHT, ARM_OUT
    shapes = [ks.box(0.0, y - 0.3, 0.02, 0.18, 0.7, 0.04, "iron"), ks.box(0.0, y, out / 2.0, 0.05, 0.05, out, "iron"),
              ks.box(0.0, y - 0.2, out * 0.3, 0.04, 0.04, out * 0.7, "iron", 0.0, 32.0, 0.0),
              ks.box(0.0, y + 0.02, out, 0.9, 0.05, 0.05, "iron")]
    shapes += [ks.box(s * 0.4, y - 0.06, out, 0.03, 0.12, 0.03, "iron") for s in (-1.0, 1.0)]
    hooks = [[s * 0.4, y - 0.12, out] for s in (-1.0, 1.0)]
    return shapes, [], hooks


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
    """A niche in a wall: its granite surround, its painted back (the
    forgotten king), a sill for the votive lamp."""
    w, h = NICHE
    y = NICHE_SILL
    shapes = [ks.box(0.0, y + h / 2.0, -0.08, w, h, 0.04, "pitch"), ks.card(0.0, y + h / 2.0, -0.05, w * 0.9, h * 0.9, "azulejo_king"),
              ks.box(-w / 2.0 - 0.06, y + h / 2.0, 0.0, 0.12, h + 0.2, 0.2, "granite"), ks.box(w / 2.0 + 0.06, y + h / 2.0, 0.0, 0.12, h + 0.2, 0.2, "granite"),
              ks.box(0.0, y + h + 0.06, 0.0, w + 0.24, 0.12, 0.2, "granite"), ks.box(0.0, y - 0.05, 0.04, w + 0.3, 0.1, 0.28, "granite")]
    return shapes, [], [[0.0, y + 0.02, 0.06]]


def _retablo():
    """A panel of the comet under a little four-faced tiled roof on its
    wall, a lantern's hook over it at 2.5 m."""
    w, h = RETABLO
    y = 1.7
    shapes = [ks.card(0.0, y + h / 2.0, 0.02, w, h, "azulejo_comet")] + ks.moved(_frame(w, h, 0.02), offset=(0.0, y, 0.0))
    shapes.append(ks.prism(0.0, y + h + TILE + 0.12, 0.12, 0.36, 0.22, 4, "roof_spanish", 45.0, 0.0, 0.0, top=0.05))
    shapes += [ks.box(0.0, 2.5 + 0.12, 0.08, 0.04, 0.04, 0.16, "iron")]
    return shapes, [], [[0.0, 2.5, 0.16]]


def _carmo():
    """The dolphin fountain under its canopy: a two-step round platform,
    four Tuscan pillars round it under an entablature and a low dome, two
    curved tanks between the pillars, four spouts."""
    shapes = [ks.prism(0.0, 0.1, 0.0, 3.0, 0.2, 12, "granite"), ks.prism(0.0, 0.3, 0.0, 2.6, 0.2, 12, "granite")]
    cols = [town.col(0.0, 0.1, 0.0, 5.6, 0.2, 5.6), town.col(0.0, 0.1, 0.0, 5.6, 0.2, 5.6, "stone", 45.0),
            town.col(0.0, 0.3, 0.0, 4.8, 0.2, 4.8), town.col(0.0, 0.3, 0.0, 4.8, 0.2, 4.8, "stone", 45.0)]

    for sx in (-1.0, 1.0):
        for sz in (-1.0, 1.0):
            x, z = sx * 1.7, sz * 1.7
            shapes += [ks.prism(x, 0.4 + 1.4, z, 0.2, 2.8, 8, "ashlar"), ks.box(x, 0.4 + 0.1, z, 0.5, 0.2, 0.5, "granite"),
                       ks.box(x, 3.3, z, 0.5, 0.2, 0.5, "granite")]
            cols.append(town.col(x, 1.85, z, 0.4, 2.9, 0.4))

    shapes += [ks.box(0.0, 3.55, 0.0, 4.2, 0.3, 4.2, "ashlar"), ks.prism(0.0, 4.2, 0.0, 2.2, 1.0, 12, "ashlar", top=0.4),
                ks.prism(0.0, 4.9, 0.0, 0.2, 0.5, 8, "granite")]
    cols.append(town.col(0.0, 3.7, 0.0, 4.2, 0.6, 4.2))

    for s in (-1.0, 1.0):
        shapes.append(ks.box(s * 0.0, 0.75, s * 1.0, 2.6, 0.7, 0.8, "granite"))
        cols.append(town.col(0.0, 0.75, s * 1.0, 2.6, 0.7, 0.8))
        shapes.append(ks.box(0.0, 1.2, s * 0.55, 0.16, 0.16, 0.3, "brass"))
        shapes.append(ks.box(s * 0.55, 1.2, 0.0, 0.3, 0.16, 0.16, "brass"))

    return shapes, cols, [[0.0, 0.8, 0.0]]


def _wall_fountain():
    """A wall fountain: its stone back under a pediment, a mask spouting
    into a basin before it."""
    shapes = [ks.box(0.0, 1.3, 0.15, 2.4, 2.6, 0.3, "ashlar"), ks.gable(0.0, 2.6, 0.15, 2.6, 0.5, 0.32, "granite"),
              ks.box(0.0, 1.5, 0.34, 0.3, 0.3, 0.1, "brass"), ks.box(0.0, 0.4, 0.75, 2.0, 0.8, 0.9, "granite"),
              ks.box(0.0, 0.79, 0.75, 1.8, 0.02, 0.7, "glass_dark")]
    cols = [town.col(0.0, 1.3, 0.15, 2.4, 2.6, 0.3), town.col(0.0, 0.4, 0.75, 2.0, 0.8, 0.9)]
    return shapes, cols, [[0.0, 0.8, 0.75]]


def _bowls():
    """A basin, a column rising from it, an upper bowl spilling into it."""
    shapes = [ks.prism(0.0, 0.3, 0.0, 1.4, 0.6, 8, "granite"), ks.prism(0.0, 0.59, 0.0, 1.25, 0.02, 8, "glass_dark"),
              ks.prism(0.0, 1.0, 0.0, 0.15, 1.4, 6, "granite"),
              ks.lathe(0.0, 1.6, 0.0, [[0.12, 0.0], [0.6, 0.18], [0.65, 0.24]], 8, "granite")]
    cols = [town.col(0.0, 0.3, 0.0, 2.6, 0.6, 2.6), town.col(0.0, 0.3, 0.0, 2.6, 0.6, 2.6, "stone", 45.0), town.col(0.0, 1.0, 0.0, 0.3, 1.4, 0.3)]
    return shapes, cols, [[0.0, 0.6, 0.0]]


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
_piece("fountain_bowls", "street", "granite", _shapes, _cols, [2.8, 2.0, 2.8], 500, {"water": _water})
