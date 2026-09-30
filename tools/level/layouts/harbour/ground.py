"""The harbour's ground (terrain.py): the sea bed under the bay, the rocky
spit out to the fort, the river's mouth and banks beside the Guindais stair,
the headland east of the mole with its cliff and the smugglers' cave in it,
the blowhole's shaft up through it."""

import math

import terrain

from . import BLOWHOLE, stair_y

# The east coast (the cliff's line), from its seaward end back to the mole's
# root: the cliff faces the sea on its left. The cave's mouth breaks it
# between MOUTH_A and MOUTH_B.
COAST = [(282.0, 112.0), (256.0, 96.0), (234.0, 72.0), (229.0, 63.0), (223.0, 48.0), (220.0, 38.0), (205.0, 12.0), (180.0, -4.0), (152.0, -10.0)]
MOUTH = (3, 4)
CLIFF_TOP = 24.0
SPIT = ((-215.0, 10.0), (-85.0, 195.0))


def _ripple(x, z, amount):
    return amount * (math.sin(x * 0.37 + z * 0.11) * 0.6 + math.sin(x * 0.09 - z * 0.23) * 0.4)


def sea_bed(x, z):
    h = -6.0 - 4.0 * min(1.0, max(0.0, (z - 210.0) / 60.0))

    if z < 20.0 and -185.0 < x < 185.0:
        h = max(h, -3.5 - 2.5 * min(1.0, max(0.0, z / 20.0)))

    return h + _ripple(x, z, 0.3)


def _segment(p, a, b):
    """Distance from p to the segment a-b and how far along it (0..1)."""
    dx, dz = b[0] - a[0], b[1] - a[1]
    t = max(0.0, min(1.0, ((p[0] - a[0]) * dx + (p[1] - a[1]) * dz) / (dx * dx + dz * dz)))
    return math.hypot(p[0] - a[0] - dx * t, p[1] - a[1] - dz * t), t


def spit(x, z):
    d, t = _segment((x, z), SPIT[0], SPIT[1])
    crest = 2.0 + 2.2 * math.sin(t * math.pi) * (1.0 - 0.4 * t) + _ripple(x, z, 0.5)
    rock = crest - (d / 10.0) ** 2 * 8.0
    land = min(40.0, (-237.0 - x) * 2.5) if x < -237.0 and z < 70.0 else -99.0
    return max(rock, land, sea_bed(x, z))


def river(x, z):
    if x > -193.0:
        # (Up to the Guindais stair's side; north of its top a wider bank,
        # the grade the massing's gorge carries on at its first row.)
        rise = min(1.0, (x + 193.0) / (5.0 + 0.2 * max(0.0, -100.0 - z)))
        return 0.5 + (stair_y(z) - 0.4 - 0.5) * rise
    if x < -235.0:
        return min(45.0, (-235.0 - x) * 3.0) + _ripple(x, z, 0.4)
    return -3.0 + _ripple(x, z, 0.25)


def inland(x, z):
    """How far (m) (x, z) lies inland of the east coast (negative: at sea)."""
    best = None

    for a, b in zip(COAST, COAST[1:]):
        d, t = _segment((x, z), a, b)
        # The cliff faces the sea on its left: inland is to its right.
        dx, dz = b[0] - a[0], b[1] - a[1]
        side = (x - a[0]) * (-dz) + (z - a[1]) * dx

        if best is None or d < best[0]:
            best = (d, 1.0 if side < 0.0 else -1.0)

    return best[0] * best[1]


def headland(x, z):
    if math.hypot(x - BLOWHOLE[0], z - BLOWHOLE[1]) < 2.8:
        return -50.0

    if inland(x, z) > -2.5:
        return CLIFF_TOP + _ripple(x, z, 0.8) + max(0.0, inland(x, z) - 20.0) * 0.08

    return -6.0


def _slope_slot(ground):
    return lambda x, y, z, slope: "cliff" if slope > 50.0 else ("rock" if slope > 22.0 else ground)


def lay(L):
    L.terrain(terrain.grid("sea_bed", "sea", -260.0, -10.0, 300.0, 420.0, 8.0, sea_bed, "gravel", surface="gravel"))
    L.terrain(terrain.grid("west_spit", "fort", -260.0, -10.0, -70.0, 215.0, 2.5, spit, _slope_slot("gravel"), surface="stone",
                           keep=lambda ys: max(ys) > -2.5, skirt=0.8))
    # (To the massing's first row at its north end, and in under the west
    # wall at its east: city_massing's rock meets it there.)
    L.terrain(terrain.grid("river_banks", "river", -260.0, -152.5, -177.5, -10.0, 2.5, river, _slope_slot("gravel"), surface="stone",
                           skirt=0.8))
    L.terrain(terrain.grid("east_headland", "cave", 150.0, -60.0, 300.0, 115.0, 5.0, headland, _slope_slot("grass"), surface="stone",
                           keep=lambda ys: min(ys) > 0.0, occluder=True))
    L.terrain(terrain.cliff("east_cliff_a", "cave", COAST[:MOUTH[0] + 1], -4.0, CLIFF_TOP, band=5.5, jitter=0.7, seed=11, slot="cliff"))
    L.terrain(terrain.cliff("east_cliff_b", "cave", COAST[MOUTH[1]:], -4.0, CLIFF_TOP, band=5.5, jitter=0.7, seed=12, slot="cliff"))
    L.terrain(terrain.tunnel("smugglers_cave", "cave", [(226.0, 2.0, 57.0), (228.0, 2.0, 42.0), (230.0, 2.0, 26.0), (231.0, 2.0, 10.0),
                                                        (232.0, 2.0, -16.0)],
                             [(7.0, 6.0), (6.0, 5.0), (5.5, 4.5), (4.0, 3.5), (3.0, 3.0)], floor=-1.5, sides=10, seed=13, slot="rock"))
    L.terrain(terrain.grid("cave_beach", "cave", 223.0, 4.0, 237.0, 32.0, 1.0, lambda x, z: 0.6 + max(0.0, 30.0 - z) / 24.0 * 0.9 + _ripple(x, z, 0.08),
                           "gravel", surface="gravel"))
    L.terrain(terrain.tunnel("blowhole_shaft", "cave", [(BLOWHOLE[0], 3.0, BLOWHOLE[1]), (BLOWHOLE[0], CLIFF_TOP + 3.0, BLOWHOLE[1])],
                             [(1.8, 1.8), (2.3, 2.3)], floor=None, sides=8, seed=14, slot="rock"))
