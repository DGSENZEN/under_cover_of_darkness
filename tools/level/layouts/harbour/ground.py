"""The harbour's ground (terrain.py): the sea bed under the bay, the rocky
spit out to the fort, the river's mouth and banks beside the Guindais stair,
the headland east of the mole with its cliff and the smugglers' cave in it,
the blowhole's shaft up through it."""

import math

import terrain

from . import BLOWHOLE, CAUSEWAY, CAUSEWAY_DECK, stair_y

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
# The coast on past the ground's old edge, east to the world's (its cliff
# the far ground's own steep fall, no strata): from its seaward end back to
# the east coast's.
FAR_COAST = [(630.0, 170.0), (575.0, 166.0), (520.0, 160.0), (465.0, 151.0), (410.0, 140.0), (360.0, 131.0), (325.0, 124.0)]
# The harbour's own sea bed (x0, z0, x1, z1); the far ground round it, out
# past the world's wall (maps/city.gd WORLD), coarse and under the near
# ground where they meet.
NEAR_SEA = (-260.0, -10.0, 300.0, 420.0)
FAR = (-620.0, -10.0, 620.0, 900.0)
# The west land: its coast leaves the spit's root at z 70 (x -237) and runs
# south-west; its top 40 m, rising to the rock's 45 (city_massing) at its
# north (0.4 m under it where they overlap).
WEST_COAST = (70.0, 0.5)


def _cave():
    """The smugglers' cave: in through the cliff's gap (its first stretch
    square to the cliff, its mouth the gap's width less the rock round its
    arch), then bending north under the headland, past its beach, to the
    undercroft's seal. Its path and its radii (across, up)."""
    (ax, az), (bx, bz) = COAST[MOUTH[0]], COAST[MOUTH[1]]
    gap = math.hypot(bx - ax, bz - az)
    sea = ((bz - az) / gap, -(bx - ax) / gap)
    mx, mz = (ax + bx) / 2.0, (az + bz) / 2.0
    path = [(mx + sea[0] * 0.6, 2.0, mz + sea[1] * 0.6), (mx - sea[0] * 5.0, 2.0, mz - sea[1] * 5.0), (232.5, 2.0, 48.5), (231.5, 2.0, 40.0),
            (230.0, 2.0, 26.0), (231.0, 2.0, 10.0), (232.0, 2.0, -16.0)]
    radii = [(gap / 2.0 - 0.5, 6.5), (6.6, 5.8), (6.0, 5.2), (5.8, 4.8), (5.5, 4.5), (4.0, 3.5), (3.0, 3.0)]
    return path, radii


CAVE, CAVE_RADII = _cave()
CAVE_SIDES = 12
# The rock over the cave's arch, from just over its crown.
LINTEL_FOOT = 9.4


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


def _smooth(t):
    t = max(0.0, min(1.0, t))
    return t * t * (3.0 - 2.0 * t)


def west_land(x, z):
    """The land west of the river's mouth (x < -237): up from the river at
    2.5 in 1 to its top; its coast south-west from the spit's root, falling
    to the sea at 1.2 in 1 (steeper than the bank, a slope of rock); the
    sea's bed past it."""
    far = _smooth((-262.0 - x) / 30.0)
    coast = WEST_COAST[0] + WEST_COAST[1] * max(0.0, -237.0 - x) + (6.0 * math.sin(x * 0.023) + 3.0 * math.sin(x * 0.071 + 1.3)) * far
    top = 40.0 + (4.4 * _smooth((40.0 - z) / 40.0) + 2.2 * math.sin(x * 0.037) * math.sin(z * 0.029)) * far
    rise = (-237.0 - x) * 2.5
    # (Away from the spit's root, its fall to the sea in strata: a face of
    # rock over a ledge, as the river's west bank.)
    d = coast - z
    k = math.floor(d / 5.0)
    stepped = k * 6.0 + 6.0 * min(1.0, (d / 5.0 - k) / 0.45)
    fall = d * 1.2 + (stepped - d * 1.2) * far
    return max(min(top, rise, fall), sea_bed(x, z))


def spit(x, z):
    d, t = _segment((x, z), SPIT[0], SPIT[1])
    crest = 2.0 + 2.2 * math.sin(t * math.pi) * (1.0 - 0.4 * t) + _ripple(x, z, 0.5)
    rock = crest - (d / 10.0) ** 2 * 8.0

    # (Under the causeway, the rock kept under its deck: it is built on it.)
    if min(_segment((x, z), a, b)[0] for a, b in zip(CAUSEWAY, CAUSEWAY[1:])) < 4.0:
        rock = min(rock, CAUSEWAY_DECK - 0.6)
    land = west_land(x, z) if x < -237.0 else -99.0
    return max(rock, land, sea_bed(x, z))


def far_sea_bed(x, z):
    """The sea's bed past the harbour's: 0.6 m under it where they meet,
    shelving away to 22 m; well inside the harbour's, none (-999: dropped)."""
    x0, z0, x1, z1 = NEAR_SEA

    if x0 + 48.0 < x < x1 - 48.0 and z < z1 - 48.0:
        return -999.0

    out = math.hypot(max(x0 - x, 0.0, x - x1), max(z - z1, 0.0))
    return sea_bed(x, z) - 0.6 - 12.0 * _smooth(out / 400.0)


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


def east_bank(x, z):
    """The river's east bank, under the Guindais stair: granite in three
    strata, each a steep face over a ledge, wandering along it, up to the
    stair's foot; toward the gorge (north of z -140) the plain slope the
    massing's gorge carries on (river()). West of x -193, the river's bed."""
    if x <= -193.0:
        return river(x, z)

    width = 5.0 + 0.2 * max(0.0, -100.0 - z)
    t = (x + 193.0) / width - 0.1 + 0.06 * math.sin(z * 0.21) + 0.04 * math.sin(z * 0.57 + 1.0)
    t = min(1.0, max(0.0, t))
    step = min(2, int(math.floor(t * 3.0)))
    rise = 1.0 if t >= 1.0 else (step + min(1.0, (t * 3.0 - step) / 0.45)) / 3.0
    stepped = 0.5 + (stair_y(z) - 0.4 - 0.5) * rise + _ripple(x, z, 0.15)
    blend = min(1.0, max(0.0, (-140.0 - z) / 12.5))
    return stepped + (river(x, z) - stepped) * blend


def _heath(x, y, z, slope):
    """The headland's top: short turf, bare granite wherever it is steep.
    (Patches of rock by face read as squares of paving: its bare rock is its
    tors and ledges.)"""
    if slope > 50.0:
        return "cliff_shore"

    return "rock_shore" if slope > 22.0 else "grass"


def inland(x, z, coast=None):
    """How far (m) (x, z) lies inland of the east coast (negative: at sea)."""
    best = None
    coast = coast or COAST

    for a, b in zip(coast, coast[1:]):
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


def far_headland(x, z):
    """The headland on east past the old ground's edge (x 300, where its
    plateau is flat at the cliff's top): the plateau, a long swell over it
    further east, its coast (FAR_COAST) a steep fall of rock to the sea, no
    cliff of strata; 0.08 m under the near ground where they overlap."""
    d = inland(x, z, FAR_COAST + COAST)

    if z < HEADLAND_NORTH - 1e-6:
        return -60.0

    far = _smooth((x - 320.0) / 60.0)
    swell = (2.6 * math.sin(x * 0.019 + 0.4) * math.sin(z * 0.031 + 1.1) + 1.2 * math.sin(x * 0.047 - z * 0.029)) * far * _smooth(d / 25.0)
    top = CLIFF_TOP + _ripple(x, z, 0.8) + swell
    north = min(1.0, (z - HEADLAND_NORTH) / 10.0)
    top = NORTH_SHORE_TOP + (top - NORTH_SHORE_TOP) * north
    # (The coast: from the plateau 3 m in to the bed 3 m out.)
    h = sea_bed(x, z) + (top - sea_bed(x, z)) * _smooth((d + 3.0) / 6.0)
    return h - (0.08 if x < 300.5 else 0.0)


def _slope_slot(ground):
    # (The shore's rock: banded by height, wet under high water, black with
    # lichen over it.)
    return lambda x, y, z, slope: "cliff_shore" if slope > 50.0 else ("rock_shore" if slope > 22.0 else ground)


def lay(L):
    L.terrain(terrain.grid("sea_bed", "sea", -260.0, -10.0, 300.0, 420.0, 8.0, sea_bed, "gravel", surface="gravel"))
    # The far ground, out past the world's wall: the open sea's bed, the
    # west land, the headland on east.
    L.terrain(terrain.grid("far_sea_bed", "sea", FAR[0], FAR[1], FAR[2], FAR[3], 40.0, far_sea_bed, "gravel", surface="gravel",
                           keep=lambda ys: min(ys) > -500.0))
    L.terrain(terrain.grid("west_land", "fort", FAR[0], -10.0, -260.0, 330.0, 10.0, west_land, _slope_slot("gravel"), surface="stone",
                           keep=lambda ys: max(ys) > -2.5, skirt=2.0))
    L.terrain(terrain.grid("far_headland", "cave", 297.5, HEADLAND_NORTH, FAR[2] - 12.5, 180.0, 5.0, far_headland, _heath, surface="stone",
                           keep=lambda ys: max(ys) > -2.5, skirt=2.0))
    L.terrain(terrain.grid("west_spit", "fort", -260.0, -10.0, -70.0, 215.0, 2.5, spit, _slope_slot("gravel"), surface="stone",
                           keep=lambda ys: max(ys) > -2.5, skirt=0.8))
    # (To the massing's first row at its north end, and in under the west
    # wall at its east: city_massing's rock meets it there.)
    L.terrain(terrain.grid("river_banks", "river", -235.0, -152.5, -193.0, -10.0, 2.5, river, _slope_slot("gravel"), surface="stone",
                           skirt=0.8))
    # (Its east bank finer, for its strata, up to the stair.)
    L.terrain(terrain.grid("river_east_bank", "river", -193.0, -152.5, -177.5, -10.0, 0.7, east_bank,
                           lambda x, y, z, slope: "cliff_shore" if slope > 50.0 else ("rock_shore" if slope > 22.0 else "gravel"),
                           surface="stone", skirt=0.8))
    # (Its west bank finer, for its strata; grass on the ledges over the
    # water.)
    L.terrain(terrain.grid("river_west_bank", "river", -260.0, -152.5, -235.0, -10.0, 1.25, west_bank,
                           lambda x, y, z, slope: "cliff_shore" if slope > 50.0 else ("rock_shore" if slope > 22.0 else ("gravel" if y < 3.0 else "grass")),
                           surface="stone", skirt=0.8))
    L.terrain(terrain.grid("east_headland", "cave", 150.0, HEADLAND_NORTH, HEADLAND_EAST, 123.5, 2.5, headland, _heath,
                           surface="stone", keep=lambda ys: min(ys) > 0.0, occluder=True))
    # (Granite: strata 2.8 m deep, broken by upright joints into blocks.)
    L.terrain(terrain.cliff("east_cliff_a", "cave", COAST[:MOUTH[0] + 1], -4.0, CLIFF_TOP, band=2.8, jitter=0.6, seed=11, slot="cliff_shore",
                            step=1.6, blocks=(2, 0.7)))
    L.terrain(terrain.cliff("east_cliff_b", "cave", COAST[MOUTH[1]:], -4.0, CLIFF_TOP, band=2.8, jitter=0.6, seed=12, slot="cliff_shore",
                            step=1.6, blocks=(2, 0.7)))
    # (Rock over the cave's mouth down to its arch.)
    L.terrain(terrain.cliff("cave_lintel", "cave", [COAST[MOUTH[0]], COAST[MOUTH[1]]], LINTEL_FOOT, CLIFF_TOP, band=2.8, jitter=0.4, seed=15,
                            slot="cliff_shore", step=1.6, blocks=(2, 0.5)))
    cave = terrain.tunnel("smugglers_cave", "cave", CAVE, CAVE_RADII, floor=-1.5, sides=CAVE_SIDES, seed=13, slot="rock_shore")
    L.terrain(cave)
    # The rock round its arch, filling the cliff's gap from the cliff's foot
    # to the lintel and into the cliff's ends either side.
    (ax, az), (bx, bz) = COAST[MOUTH[0]], COAST[MOUTH[1]]
    gap = math.hypot(bx - ax, bz - az)
    along = [(bx - ax) / gap, 0.0, (bz - az) / gap]
    L.terrain(terrain.frame("cave_mouth", "cave", cave["verts"][:CAVE_SIDES], list(CAVE[0]), along, [along[2], 0.0, -along[0]], -4.0,
                            LINTEL_FOOT + 0.4, gap / 2.0 + 0.6, slot="cliff_shore"))
    L.terrain(terrain.grid("cave_beach", "cave", 223.0, 4.0, 237.0, 32.0, 1.0, lambda x, z: 0.6 + max(0.0, 30.0 - z) / 24.0 * 0.9 + _ripple(x, z, 0.08),
                           "gravel", surface="gravel"))
    # The blowhole's shaft up from the cave, flaring at the top into a funnel
    # of rock under the headland's turf (round the hole cut in it).
    rim = min(headland(BLOWHOLE[0] + 6.0 * math.cos(a), BLOWHOLE[1] + 6.0 * math.sin(a)) for a in [i * math.pi / 8.0 for i in range(16)])
    L.terrain(terrain.tunnel("blowhole_shaft", "cave", [(BLOWHOLE[0], 3.0, BLOWHOLE[1]), (BLOWHOLE[0], rim - 2.2, BLOWHOLE[1]),
                                                         (BLOWHOLE[0], rim - 0.35, BLOWHOLE[1])],
                             [(1.8, 1.8), (2.3, 2.3), (5.6, 5.6)], floor=None, sides=12, seed=14, slot="rock_shore"))
