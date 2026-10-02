"""The harbour's ground (terrain.py): the sea bed under the bay, the rocky
spit out to the fort, the river's mouth and banks beside the Guindais stair,
the headland east of the mole with its cliff and the smugglers' cave in it,
the blowhole's shaft up through it."""

import math

import terrain

from . import BLOWHOLE, stair_y

# The east coast (the cliff's line), from its seaward end (the headland's
# south-east corner, the ground's edge) back to the mole's root: the cliff
# faces the sea on its left, the headland on its right. The cave's mouth
# breaks it between MOUTH_A and MOUTH_B.
COAST = [(300.0, 119.0), (282.0, 112.0), (256.0, 96.0), (234.0, 72.0), (229.0, 63.0), (223.0, 48.0), (220.0, 38.0), (205.0, 12.0), (180.0, -4.0),
         (152.0, -10.0)]
MOUTH = (4, 5)
CLIFF_TOP = 24.0
# The headland's ground: north to the massing's line (where the north
# shore's cliff, 27 m, stands: city_massing), east to the ground's edge.
HEADLAND_NORTH = -11.5
HEADLAND_EAST = 300.0
NORTH_SHORE_TOP = 27.0
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


def west_bank(x, z):
    """The river's west bank: granite in strata, each a steep face over a
    ledge, the steps wandering along it, up to the rock at 45 m; toward the
    gorge (north of z -140) the plain slope the massing's gorge carries on.
    East of x -235, the river's bed (as river())."""
    if x >= -235.0:
        return river(x, z)

    plain = min(45.0, (-235.0 - x) * 3.0)
    d = (-235.0 - x) - 1.0 + 1.6 * math.sin(z * 0.13) + 0.9 * math.sin(z * 0.41 + 1.0)
    k = math.floor(d / 4.0)
    stepped = min(45.0, max(0.0, k * 7.5 + 7.5 * min(1.0, (d / 4.0 - k) / 0.55)))
    t = min(1.0, max(0.0, (-140.0 - z) / 12.5))
    return stepped + (plain - stepped) * t + _ripple(x, z, 0.4)


def inland(x, z):
    """How far (m) (x, z) lies inland of the east coast (negative: at sea)."""
    best = None

    for a, b in zip(COAST, COAST[1:]):
        d, t = _segment((x, z), a, b)
        # The cliff faces the sea on its left (terrain.cliff: (dz, -dx)):
        # inland is to its right, (-dz, dx).
        dx, dz = b[0] - a[0], b[1] - a[1]
        side = (x - a[0]) * (-dz) + (z - a[1]) * dx

        if best is None or d < best[0]:
            best = (d, 1.0 if side > 0.0 else -1.0)

    return best[0] * best[1]


def headland(x, z):
    """The headland's top: east of its cliff (inland), a little higher
    further in, back down to the cliff's top at the ground's east edge and up
    to the north shore's top at the massing's line; a hole for the
    blowhole's shaft. North of the line, the massing's rock (nothing)."""
    if z < HEADLAND_NORTH - 1e-6:
        return -60.0

    if math.hypot(x - BLOWHOLE[0], z - BLOWHOLE[1]) < 2.8:
        return -50.0

    d = inland(x, z)

    if d > -2.5:
        east = min(1.0, max(0.0, HEADLAND_EAST - x) / 40.0)
        rise = max(0.0, d - 20.0) * 0.08 * east
        # (Swells over the top, nothing at the cliff's edge: its top meets it.)
        swell = (1.8 * math.sin(x * 0.061 + 0.7) * math.sin(z * 0.052 + 1.3) + 0.9 * math.sin(x * 0.13 - z * 0.094 + 0.4)) * min(1.0, max(0.0, d) / 18.0) * east
        h = CLIFF_TOP + _ripple(x, z, 0.8) + rise + swell
        north = min(1.0, (z - HEADLAND_NORTH) / 10.0)
        return NORTH_SHORE_TOP + (h - NORTH_SHORE_TOP) * north

    return -6.0


def _slope_slot(ground):
    # (The shore's rock: banded by height, wet under high water, black with
    # lichen over it.)
    return lambda x, y, z, slope: "cliff_shore" if slope > 50.0 else ("rock_shore" if slope > 22.0 else ground)


def lay(L):
    L.terrain(terrain.grid("sea_bed", "sea", -260.0, -10.0, 300.0, 420.0, 8.0, sea_bed, "gravel", surface="gravel"))
    L.terrain(terrain.grid("west_spit", "fort", -260.0, -10.0, -70.0, 215.0, 2.5, spit, _slope_slot("gravel"), surface="stone",
                           keep=lambda ys: max(ys) > -2.5, skirt=0.8))
    # (To the massing's first row at its north end, and in under the west
    # wall at its east: city_massing's rock meets it there.)
    L.terrain(terrain.grid("river_banks", "river", -235.0, -152.5, -177.5, -10.0, 2.5, river, _slope_slot("gravel"), surface="stone",
                           skirt=0.8))
    # (Its west bank finer, for its strata; grass on the ledges over the
    # water.)
    L.terrain(terrain.grid("river_west_bank", "river", -260.0, -152.5, -235.0, -10.0, 1.25, west_bank,
                           lambda x, y, z, slope: "cliff_shore" if slope > 50.0 else ("rock_shore" if slope > 22.0 else ("gravel" if y < 3.0 else "grass")),
                           surface="stone", skirt=0.8))
    L.terrain(terrain.grid("east_headland", "cave", 150.0, HEADLAND_NORTH, HEADLAND_EAST, 123.5, 5.0, headland, _slope_slot("grass"),
                           surface="stone", keep=lambda ys: min(ys) > 0.0, occluder=True))
    # (Granite: strata 2.8 m deep, broken by upright joints into blocks.)
    L.terrain(terrain.cliff("east_cliff_a", "cave", COAST[:MOUTH[0] + 1], -4.0, CLIFF_TOP, band=2.8, jitter=0.6, seed=11, slot="cliff_shore",
                            step=1.6, blocks=(2, 0.7)))
    L.terrain(terrain.cliff("east_cliff_b", "cave", COAST[MOUTH[1]:], -4.0, CLIFF_TOP, band=2.8, jitter=0.6, seed=12, slot="cliff_shore",
                            step=1.6, blocks=(2, 0.7)))
    # (Rock over the cave's mouth down to its arch, and down the ground's
    # east edge.)
    L.terrain(terrain.cliff("cave_lintel", "cave", [COAST[MOUTH[0]], COAST[MOUTH[1]]], 7.0, CLIFF_TOP, band=2.8, jitter=0.4, seed=15,
                            slot="cliff_shore", step=1.6, blocks=(2, 0.5)))
    L.terrain(terrain.cliff("east_edge", "cave", [(HEADLAND_EAST, HEADLAND_NORTH), (HEADLAND_EAST, COAST[0][1])], -4.0, CLIFF_TOP + 0.9,
                            band=2.8, jitter=0.5, seed=16, slot="cliff_shore", step=2.0, blocks=(2, 0.6)))
    L.terrain(terrain.tunnel("smugglers_cave", "cave", [(226.0, 2.0, 57.0), (228.0, 2.0, 42.0), (230.0, 2.0, 26.0), (231.0, 2.0, 10.0),
                                                        (232.0, 2.0, -16.0)],
                             [(7.0, 6.0), (6.0, 5.0), (5.5, 4.5), (4.0, 3.5), (3.0, 3.0)], floor=-1.5, sides=10, seed=13, slot="rock"))
    L.terrain(terrain.grid("cave_beach", "cave", 223.0, 4.0, 237.0, 32.0, 1.0, lambda x, z: 0.6 + max(0.0, 30.0 - z) / 24.0 * 0.9 + _ripple(x, z, 0.08),
                           "gravel", surface="gravel"))
    L.terrain(terrain.tunnel("blowhole_shaft", "cave", [(BLOWHOLE[0], 3.0, BLOWHOLE[1]), (BLOWHOLE[0], CLIFF_TOP + 3.0, BLOWHOLE[1])],
                             [(1.8, 1.8), (2.3, 2.3)], floor=None, sides=8, seed=14, slot="rock"))
