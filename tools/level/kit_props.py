"""Kit v1's props: what fills the barracks' mess hall and kitchen (places
laid at the tables, a dresser of plates, kegs on their cradle, hams hung
from the joists, shields and spears on the walls, a cauldron by the
hearth), and the dressing that was still boxes modelled (trestle tables,
benches, crates, a chest, the weapon racks, the woodpile, sacks, the
stove). Pure data, as kit_recipes (which imports this at its end).

A prop's pivot is the middle of its footprint on its floor (or on a table
top for what is laid on one); one that stands against a wall has its back to
local -z.
"""

import math

import kit_recipes as k
import kit_shapes as ks

TABLE_TOP = 0.79


def _drawn(name, slot, shapes, size, budget=None):
    k.piece(name, "dressing", slot, "wood", [], cols=[], size=size)
    k.model(name, shapes)

    if budget:
        k.PIECES[name]["budget"] = budget


def _solid(name, slot, shapes, size, surface="wood"):
    """A prop men walk round: its collider its footprint's box."""
    k.piece(name, "dressing", slot, surface, [], cols=[[0.0, size[1] / 2.0, 0.0, size[0], size[1], size[2], surface, 0.0, 0.0, 0.0]], size=size)
    k.model(name, shapes)


# ---------------------------------------------------------------------------
# Crockery and food (small lathes: pewter and glazed pottery, bread, cheese)
# ---------------------------------------------------------------------------

def plate(x, y, z, slot="pewter"):
    return ks.lathe(x, y, z, [[0.08, 0.0], [0.12, 0.012], [0.135, 0.022]], 8, slot)


def bowl(x, y, z, slot="pottery"):
    return ks.lathe(x, y, z, [[0.045, 0.0], [0.075, 0.03], [0.085, 0.06]], 8, slot)


def tankard(x, y, z, handle=1.0):
    return [ks.lathe(x, y, z, [[0.042, 0.0], [0.04, 0.07], [0.044, 0.13]], 6, "pewter"),
            ks.box(x + handle * 0.058, y + 0.07, z, 0.022, 0.08, 0.018, "pewter")]


def jug(x, y, z, slot="pottery"):
    return [ks.lathe(x, y, z, [[0.06, 0.0], [0.085, 0.07], [0.08, 0.14], [0.045, 0.2], [0.05, 0.25]], 8, slot),
            ks.box(x + 0.09, y + 0.13, z, 0.02, 0.12, 0.02, slot)]


def boule(x, y, z):
    return ks.lathe(x, y, z, [[0.09, 0.0], [0.1, 0.03], [0.08, 0.07], [0.0, 0.09]], 8, "bread")


def loaf(x, y, z, yaw=0.0):
    return ks.lathe(x, y + 0.06, z, [[0.0, -0.13], [0.05, -0.1], [0.06, 0.0], [0.05, 0.1], [0.0, 0.13]], 6, "bread", yaw, 0.0, 90.0)


def _setting(x, side, with_bowl, with_bread):
    """A place laid at a table's edge (`side` +1 or -1 along z): a pewter
    plate, a bowl on it or bread beside it, a tankard on its inner side."""
    z = side * 0.28
    out = [plate(x, 0.0, z)]

    if with_bowl:
        out.append(bowl(x, 0.022, z))

    if with_bread:
        out.append(loaf(x - side * 0.02, 0.022, z, 20.0 * side))

    inward = 0.2 if x == 0.0 else -0.2 * math.copysign(1.0, x)
    out += tankard(x + inward, 0.0, z - side * 0.13, side)
    return out


def _tableware():
    """A 4 m table laid for six where the men sit (x -1.4, 0, 1.4 either
    side; its top at the pivot), a jug, bread, a cheese on its board and a
    platter of meat down its middle; the candles' places (x -1 and +1 on the
    middle line) left clear."""
    out = []

    for i, x in enumerate((-1.4, 0.0, 1.4)):
        for side in (1.0, -1.0):
            out += _setting(x, side, (i + (side > 0)) % 2 == 0, (i + (side > 0)) % 3 == 1)

    out += jug(-0.5, 0.0, 0.0)
    out.append(boule(0.45, 0.0, 0.03))
    out += [ks.box(-1.75, 0.015, 0.0, 0.42, 0.03, 0.24, "boards"), ks.lathe(-1.8, 0.03, 0.0, [[0.1, 0.0], [0.1, 0.07]], 8, "cheese"),
            ks.box(-1.6, 0.035, 0.07, 0.16, 0.006, 0.02, "iron"),
            ks.lathe(1.78, 0.0, 0.0, [[0.12, 0.0], [0.17, 0.015], [0.19, 0.03]], 8, "pewter"),
            ks.box(1.75, 0.06, 0.02, 0.17, 0.07, 0.1, "meat", 25.0), ks.box(1.85, 0.05, -0.04, 0.1, 0.05, 0.08, "meat", -30.0)]
    return out


_drawn("tableware_4", "pewter", _tableware(), [3.9, 0.3, 0.9], budget=1400)


def _spread():
    """The kitchen's table (its top at the pivot): boards of cabbages and
    turnips, loaves, a flour sack, a jug, bowls, a cleaver, a plucked bird."""
    out = [ks.box(-1.2, 0.015, 0.0, 0.6, 0.03, 0.4, "boards"), ks.box(0.9, 0.015, -0.05, 0.5, 0.03, 0.35, "boards"),
           ks.box(-1.05, 0.036, 0.1, 0.22, 0.012, 0.06, "iron", 30.0)]

    for x, z in ((-1.35, -0.08), (-1.15, 0.05), (-1.3, 0.12)):
        out.append(ks.lathe(x, 0.03, z, [[0.0, 0.0], [0.09, 0.04], [0.08, 0.11], [0.0, 0.15]], 7, "herbs"))

    for x, z in ((0.8, -0.1), (0.95, 0.02), (1.05, -0.12), (0.88, 0.1)):
        out.append(ks.lathe(x, 0.03, z, [[0.0, 0.0], [0.045, 0.03], [0.035, 0.07], [0.0, 0.1]], 6, "cheese"))

    out += [loaf(-0.2, 0.0, 0.25, 10.0), loaf(0.1, 0.0, 0.28, -15.0), boule(-0.45, 0.0, -0.2),
            ks.lathe(0.35, 0.0, -0.15, [[0.14, 0.0], [0.17, 0.12], [0.15, 0.28], [0.06, 0.36], [0.0, 0.38]], 8, "burlap")]
    out += jug(1.6, 0.0, 0.2) + [bowl(1.5, 0.0, -0.2), bowl(1.72, 0.0, -0.18)]
    out += [ks.lathe(-1.75, 0.0, -0.05, [[0.0, -0.1], [0.09, -0.07], [0.1, 0.0], [0.07, 0.07], [0.0, 0.09]], 7, "bread", 0.0, 0.0, 90.0),
            ks.box(-1.62, 0.02, 0.06, 0.1, 0.03, 0.03, "bread", 30.0)]
    return out


_drawn("kitchen_spread", "pottery", _spread(), [3.9, 0.4, 0.9], budget=1000)


# ---------------------------------------------------------------------------
# Against the walls: a dresser of plates, kegs on their cradle, shields and
# spears; hams hung from the joists
# ---------------------------------------------------------------------------

def _dresser():
    out = [ks.box(0.0, 0.42, 0.0, 1.8, 0.84, 0.45, "boards"), ks.box(0.0, 0.86, 0.02, 1.86, 0.04, 0.49, "beam"),
           ks.box(0.0, 1.45, -0.2, 1.8, 1.15, 0.04, "boards"), ks.box(0.0, 1.25, -0.07, 1.76, 0.03, 0.28, "boards"),
           ks.box(0.0, 1.65, -0.07, 1.76, 0.03, 0.28, "boards"), ks.box(0.0, 2.04, -0.05, 1.9, 0.08, 0.36, "beam")]

    for x in (-0.88, 0.0, 0.88):
        out.append(ks.box(x, 0.42, 0.23, 0.07, 0.84, 0.03, "beam"))

    for y in (0.1, 0.78):
        out.append(ks.box(0.0, y, 0.23, 1.8, 0.06, 0.03, "beam"))

    for side in (-1.0, 1.0):
        out.append(ks.box(side * 0.88, 1.45, -0.07, 0.04, 1.15, 0.3, "boards"))

    for shelf in (1.265, 1.665):
        for i in range(5):
            x = -0.64 + i * 0.32
            out.append(ks.disc(x, shelf + 0.125, -0.15, 0.12, 8, "pewter" if (i + (shelf > 1.5)) % 2 else "pottery", 0.0, -12.0))

        out.append(ks.box(0.0, shelf + 0.05, -0.0, 1.72, 0.025, 0.02, "beam"))

    out += jug(-0.55, 0.88, 0.05) + jug(0.6, 0.88, 0.0, "pewter")
    out += [bowl(0.05, 0.88, 0.05), bowl(0.05, 0.94, 0.05), bowl(0.05, 1.0, 0.05)]
    return out


_solid("dresser", "boards", _dresser(), [1.8, 2.08, 0.45])


def _kegs():
    out = []

    for x in (-0.8, 0.0, 0.8):
        for z in (-0.18, 0.18):
            out.append(ks.box(x, 0.2, z, 0.08, 0.4, 0.08, "beam"))

    for z in (-0.18, 0.18):
        out.append(ks.box(0.0, 0.38, z, 1.8, 0.1, 0.1, "beam"))

    for x in (-0.55, 0.0, 0.55):
        out.append(ks.lathe(x, 0.66, 0.0, [[0.2, -0.28], [0.24, -0.12], [0.25, 0.0], [0.24, 0.12], [0.2, 0.28]], 8, "boards", 0.0, 90.0, 0.0))

        for hoop in (-0.18, 0.18):
            out.append(ks.lathe(x, 0.66, hoop, [[0.238, -0.015], [0.238, 0.015]], 8, "iron", 0.0, 90.0, 0.0, caps=False))

        out.append(ks.box(x, 0.58, 0.3, 0.03, 0.03, 0.06, "brass"))

    return out


_solid("keg_rack", "boards", _kegs(), [1.8, 0.92, 0.6])


def _shields():
    """Three round shields over two crossed spears (the wall behind, local -z;
    its pivot the group's middle)."""
    out = []

    for side in (-1.0, 1.0):
        angle = side * 35.0
        out.append(ks.prism(0.0, 0.0, 0.03, 0.025, 2.4, 4, "timber", 0.0, 0.0, angle))
        tip = (-math.sin(math.radians(angle)) * 1.2, math.cos(math.radians(angle)) * 1.2)
        out.append(ks.lathe(tip[0], tip[1], 0.03, [[0.04, 0.0], [0.0, 0.26]], 4, "iron", 0.0, 0.0, angle))

    for (x, y, z), face in (((-0.5, -0.1, 0.07), "shield_1"), ((0.5, -0.1, 0.07), "shield_3"), ((0.0, 0.2, 0.11), "shield_2")):
        out += [ks.disc(x, y, z, 0.34, 12, face),
                ks.ring(x, y, z, 0.32, 0.36, 0.03, 0.0, 360.0, 10, "iron"),
                ks.lathe(x, y, z, [[0.1, 0.0], [0.08, 0.04], [0.0, 0.07]], 8, "iron", 0.0, 90.0, 0.0)]

    return out


_drawn("shield_trio", "iron", _shields(), [2.0, 2.4, 0.3])


def _hanging():
    """A pole under the joists (its pivot), hams, sausages, herbs and a pot
    hung from it."""
    out = [ks.box(0.0, 0.0, 0.0, 1.6, 0.06, 0.06, "beam")]

    for x in (-0.55, 0.35):
        out.append(ks.lathe(x, 0.0, 0.0, [[0.0, -0.5], [0.09, -0.46], [0.13, -0.33], [0.12, -0.2], [0.05, -0.1], [0.02, -0.03]], 8, "meat"))

    for i, x in enumerate((-0.15, -0.05, 0.05)):
        out.append(ks.box(x, -0.2, 0.0, 0.04, 0.34, 0.04, "meat", 0.0, 0.0, (i - 1) * 12.0))

    for x in (0.65, 0.72):
        out.append(ks.lathe(x, 0.0, 0.0, [[0.0, -0.32], [0.07, -0.22], [0.04, -0.06], [0.01, -0.02]], 6, "herbs"))

    out.append(ks.lathe(-0.72, 0.0, 0.0, [[0.08, -0.34], [0.12, -0.28], [0.12, -0.14]], 8, "iron"))
    out.append(ks.box(-0.72, -0.07, 0.0, 0.01, 0.14, 0.01, "iron"))
    return out


_drawn("hanging_food", "meat", _hanging(), [1.6, 0.6, 0.3])


# ---------------------------------------------------------------------------
# By the hearth: a cauldron on its tripod, a basket of logs; stools
# ---------------------------------------------------------------------------

def _cauldron():
    out = [ks.lathe(0.0, 0.0, 0.0, [[0.18, 0.2], [0.27, 0.28], [0.3, 0.4], [0.28, 0.55], [0.3, 0.58]], 10, "iron"),
           ks.disc(0.0, 0.5, 0.0, 0.27, 10, "meat", 0.0, -90.0),
           ks.box(0.0, 0.78, 0.0, 0.02, 0.4, 0.02, "iron")]

    for i in range(3):
        a = i * 120.0
        # (Their feet splayed out, their heads together over the pot.)
        out.append(ks.box(math.sin(math.radians(a)) * 0.3, 0.5, math.cos(math.radians(a)) * 0.3, 0.035, 1.05, 0.035, "iron", a, -18.0, 0.0))

    return out


_solid("cauldron", "iron", _cauldron(), [0.9, 1.0, 0.9], "metal")


def _basket():
    out = [ks.lathe(0.0, 0.0, 0.0, [[0.2, 0.0], [0.26, 0.2], [0.28, 0.42]], 8, "straw")]

    for i, (x, z, lean) in enumerate(((-0.08, 0.05, 8.0), (0.08, -0.04, -6.0), (0.0, 0.1, 3.0), (0.1, 0.08, -10.0))):
        out.append(ks.prism(x, 0.4, z, 0.06, 0.7, 6, "bark", i * 40.0, lean, 5.0))

    return out


_solid("log_basket", "straw", _basket(), [0.6, 0.8, 0.6])

_solid("stool", "boards", [ks.lathe(0.0, 0.42, 0.0, [[0.16, 0.0], [0.16, 0.05]], 8, "boards")]
       + [ks.box(math.sin(math.radians(a)) * 0.1, 0.21, math.cos(math.radians(a)) * 0.1, 0.04, 0.44, 0.04, "beam", a, -8.0, 0.0) for a in (0.0, 120.0, 240.0)],
       [0.36, 0.47, 0.36])


# ---------------------------------------------------------------------------
# The dressing that was still boxes, modelled (their colliders stay)
# ---------------------------------------------------------------------------

k.model("table_long", [ks.box(0.0, 0.75, 0.0, 4.0, 0.08, 0.9, "boards"), ks.box(0.0, 0.3, 0.0, 3.2, 0.08, 0.08, "beam")]
        + [s for x in (-1.6, 1.6) for s in (ks.box(x, 0.05, 0.0, 0.12, 0.1, 0.8, "beam"), ks.box(x, 0.38, 0.0, 0.12, 0.6, 0.14, "beam"),
                                          ks.box(x, 0.68, 0.0, 0.12, 0.08, 0.84, "beam"))])

k.model("bench", [ks.box(0.0, 0.45, 0.0, 3.0, 0.07, 0.34, "boards"), ks.box(0.0, 0.15, 0.0, 2.4, 0.05, 0.05, "beam")]
        + [ks.box(x * 1.2, 0.21, z * 0.1, 0.07, 0.44, 0.07, "beam", 0.0, -z * 8.0, -x * 6.0) for x in (-1.0, 1.0) for z in (-1.0, 1.0)])

_crate = [ks.box(0.0, 0.35, 0.0, 0.66, 0.7, 0.66, "boards")]

for _x in (-0.32, 0.32):
    for _z in (-0.32, 0.32):
        _crate.append(ks.box(_x, 0.35, _z, 0.07, 0.7, 0.07, "beam"))

for _y in (0.04, 0.66):
    _crate += [ks.box(0.0, _y, 0.33, 0.66, 0.07, 0.03, "beam"), ks.box(0.0, _y, -0.33, 0.66, 0.07, 0.03, "beam"),
               ks.box(0.33, _y, 0.0, 0.03, 0.07, 0.66, "beam"), ks.box(-0.33, _y, 0.0, 0.03, 0.07, 0.66, "beam")]

k.model("crate", _crate)

k.model("chest", [ks.box(0.0, 0.26, 0.0, 1.0, 0.52, 0.6, "boards"), ks.box(0.0, 0.58, 0.0, 1.04, 0.12, 0.64, "boards")]
        + [ks.box(x, 0.33, 0.0, 0.05, 0.68, 0.66, "iron") for x in (-0.35, 0.35)]
        + [ks.box(0.0, 0.42, 0.315, 0.12, 0.14, 0.02, "iron")])

_rack = [ks.box(-0.95, 0.9, 0.0, 0.08, 1.8, 0.08, "beam"), ks.box(0.95, 0.9, 0.0, 0.08, 1.8, 0.08, "beam"),
         ks.box(0.0, 1.5, 0.0, 2.0, 0.08, 0.2, "beam"), ks.box(0.0, 0.12, 0.0, 2.0, 0.1, 0.3, "beam")]

for _i in range(6):
    _x = -0.75 + _i * 0.3
    _rack += [ks.prism(_x, 1.1, 0.0, 0.022, 2.0, 4, "timber"), ks.lathe(_x, 2.1, 0.0, [[0.035, 0.0], [0.0, 0.24]], 4, "iron")]

for _x in (-0.55, 0.45):
    _rack += [ks.box(_x, 0.75, 0.1, 0.045, 0.9, 0.01, "iron", 0.0, 0.0, 4.0), ks.box(_x - 0.03, 1.22, 0.1, 0.2, 0.03, 0.03, "iron"),
              ks.box(_x - 0.04, 1.33, 0.1, 0.035, 0.18, 0.035, "leather")]

k.model("rack", _rack)

_logs = []

for _row, (_count, _y) in enumerate(((4, 0.12), (4, 0.34), (3, 0.56), (3, 0.78))):
    for _i in range(_count):
        _z = -0.36 + (_i + (0.5 if _count == 3 else 0.0)) * 0.24
        _logs.append(ks.prism(0.0, _y, _z, 0.12, 2.2 + 0.1 * ((_i + _row) % 3 - 1), 6, "bark", 0.0, 0.0, 90.0))

k.model("woodpile", _logs)

k.model("sacks", [ks.lathe(x, 0.0, z, [[0.18, 0.0], [0.25, 0.1], [0.26, 0.3], [0.2, 0.45], [0.08, 0.52], [0.0, 0.55]], 8, "burlap")
                  for x, z in ((-0.3, -0.12), (0.25, -0.15))]
      + [ks.lathe(0.0, 0.2, 0.22, [[0.0, -0.3], [0.16, -0.25], [0.22, -0.05], [0.2, 0.15], [0.1, 0.25], [0.0, 0.3]], 8, "burlap", 0.0, 0.0, 90.0)])

k.model("stove", [ks.box(0.0, 0.45, 0.0, 0.8, 0.9, 0.8, "iron"), ks.box(0.0, 0.92, 0.0, 0.86, 0.04, 0.86, "iron"),
                  ks.box(0.0, 0.35, 0.405, 0.32, 0.26, 0.02, "pitch"), ks.prism(0.0, 1.9, -0.25, 0.08, 1.92, 6, "iron"),
                  ks.lathe(0.12, 0.94, 0.08, [[0.1, 0.0], [0.12, 0.12], [0.12, 0.18]], 8, "iron")])
