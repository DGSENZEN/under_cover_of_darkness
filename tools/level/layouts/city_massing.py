"""The city behind the harbour as massing (the city spec, section 5.1; the
harbour plan's Sectors), until each district is built: the rock, from the
harbour's walls up the old town's terraces to the cathedral's terrace, the
palace on the east shoulder and the castle on the summit; the gorge down its
west side and the Great Bridge over it; the aqueduct across its valley to
the north; and the massing kit's silhouettes on all of it.

Where it meets the harbour: a row or a column of the rock's vertices runs
inside each of the harbour's walls, just under their walks, and the rock is
left out wherever the harbour has its own ground and floors; cliffs hide its
seams with the headland and the sea; the gorge begins with the harbour
river's own banks at their shared edge (harbour/ground.py's river)."""

import math
import random

import geo
import terrain
from lay import Layout

from harbour import stair_y
from harbour.ground import far_headland, river, west_land

# The rock: a vertex every CELL m over X0..X1, Z0..Z1. Its rows at z -22.2
# and -72.2 run inside the Ribeira's wall and wall D (and the old town's
# retaining wall over the shipyard's lane); its columns at x -179, -99 and 151
# inside the west wall, wall C and the east wall.
X0, X1, Z0, Z1, CELL = -599.0, 601.0, -722.2, -2.2, 10.0
SUNK = -40.0
# Where the old town's terraces step up (each a row), 6.8 m a step.
STEPS = [-102.2, -142.2, -182.2, -222.2]
STEP = 6.8
TOWN_TOP = 14.0 + STEP * len(STEPS)
# The cathedral's and the palace's terraces: (x0, x1, z0, z1), their height.
CATHEDRAL = ((-89.0, 51.0, -252.2, -192.2), 45.0)
PALACE = ((111.0, 191.0, -262.2, -202.2), 75.0)
# The Sea Gate's square, sunk behind the gate: its middle x, its half width,
# its north edge.
SQUARE = (-55.0, 15.0, -100.0)
# The river's line up the gorge (x, z), from the harbour's river's end north.
RIVER = [(-214.0, -152.2), (-218.0, -200.0), (-240.0, -250.0), (-266.0, -300.0), (-276.0, -360.0), (-276.0, -440.0), (-270.0, -520.0),
         (-262.0, -620.0), (-258.0, -722.2)]
CASTLE = (-200.0, -480.0)
BRIDGE_Z = -380.0
AQUEDUCT = ((150.0, -266.0), (200.0, -600.0))
# The east wall's cliff: the rock behind it and the old town, up to the
# palace's terrace (x, z, top) and round its south and west faces.
SCARP_X = 153.5


# The far land round it all, past the world's wall (no one gets there):
# hills west, north and east, ridge behind ridge out to FAR_LAND's edges, so
# the rock stands against land in the haze, not an empty sky. Its grid's
# lines run on the near ground's edges (NEAR: x -620 and 620, z -722 north;
# a vertex every FAR_CELL m); under the near ground's edge it is sunk
# EDGE_SINK m, at the sea's (its water ends at x -620 and 620) a low coast
# COAST m up; south past the bay's mouth it falls away into the haze. A
# shoulder levelled for the colossus (COLOSSUS: where, its plateau's reach).
FAR_CELL = 62.0
NEAR = (-620.0, -722.0, 620.0)
FAR_LAND = (NEAR[0] - FAR_CELL * 32, NEAR[1] - FAR_CELL * 32, NEAR[2] + FAR_CELL * 32, NEAR[1] + FAR_CELL * 32)
EDGE_SINK = 4.0
COAST = 1.5
COLOSSUS = ((-600.0, -1800.0), 150.0)


def _hills(x, z, d):
    """The far land's ridges `d` m out from the near ground: low rolling
    land by it, rising the further out (no wall over the harbour), a long
    swell, a sharp-crested ridge running across it, smaller knolls."""
    rise = _smooth(d / 1300.0)
    swell = math.sin(x * 0.0031 + 0.7) * math.sin(z * 0.0024 + 1.9)
    ridge = 1.0 - abs(math.sin(x * 0.0047 - z * 0.0036 + 2.3))
    knolls = math.sin(x * 0.012 + z * 0.0094 + 0.4)
    return 12.0 + 0.11 * d + rise * (75.0 * swell + 85.0 * ridge * ridge) + 14.0 * knolls * (0.3 + 0.7 * rise)


def _near_edge(x, z):
    """The near ground's height on its edge at (x, z): the rock's, the west
    land's, the headland's (EDGE_SINK under it), or the sea's coast."""
    if z < -11.5:
        return height(x, z) - EDGE_SINK

    land = west_land(-620.0, z) if x < 0.0 else (far_headland(607.0, z) if z < 180.0 else -99.0)
    return land - EDGE_SINK if land > COAST + EDGE_SINK else COAST


def far_land(x, z):
    """The far land at (x, z); inside the near ground, none (-999: its
    quads dropped)."""
    if NEAR[0] < x < NEAR[2] and z > NEAR[1]:
        return -999.0

    d = math.hypot(max(NEAR[0] - x, 0.0, x - NEAR[2]), max(NEAR[1] - z, 0.0))
    edge = _near_edge(min(max(x, NEAR[0]), NEAR[2]), max(z, NEAR[1]))
    h = edge + (_hills(x, z, d) - edge) * _smooth(d / 260.0)
    (cx, cz), reach = COLOSSUS
    plateau = _hills(cx, cz, math.hypot(NEAR[0] - cx, NEAR[1] - cz)) - 30.0
    h += (plateau - h) * _smooth((reach - math.hypot(x - cx, z - cz)) / (reach * 0.5))
    # (South past the bay's mouth: down to a coast in the haze.)
    south = _smooth((z - 700.0) / 560.0)
    return max(h * (1.0 - south) + COAST * south, COAST)


def colossus_base():
    """The colossus's plateau: its height."""
    (cx, cz), _ = COLOSSUS
    return far_land(cx, cz)


def _smooth(t):
    t = max(0.0, min(1.0, t))
    return t * t * (3.0 - 2.0 * t)


def _ripple(x, z, amount):
    return amount * (math.sin(x * 0.13 + z * 0.07) * 0.6 + math.sin(x * 0.05 - z * 0.11) * 0.4)


def _harbour(x, z):
    """Where the harbour has its own ground and floors: the rock's vertices
    there are sunk, its quads there left out."""
    if -180.5 < x < 150.5 and z > -21.5:
        return True
    if -98.5 < x < 150.5 and z > -72.0:
        return True
    if -258.5 < x < -180.5 and z > -151.0:
        return True
    return x > 150.5 and z > -9.5


def river_x(z):
    """The river's middle at z (up the gorge)."""
    for (xa, za), (xb, zb) in zip(RIVER, RIVER[1:]):
        if zb <= z <= za:
            return xa + (xb - xa) * (z - za) / (zb - za)
    return RIVER[0][0] if z > RIVER[0][1] else RIVER[-1][0]


def _bed(z):
    return -3.0 + 8.0 * _smooth((-152.2 - z) / 150.0)


def _rim(z):
    return 45.0 + 52.0 * _smooth((-152.2 - z) / 170.0)


def _half(z):
    return 21.0 - 9.0 * _smooth((-152.2 - z) / 110.0)


def _walls(z):
    """The gorge's east and west walls' widths at z (floor to rim)."""
    t = _smooth((-152.2 - z) / 50.0)
    return 15.5 + 2.5 * t, 15.0 + 3.0 * t


def _outside(x, z, rect):
    x0, x1, z0, z1 = rect
    return math.hypot(max(x0 - x, 0.0, x - x1), max(z0 - z, 0.0, z - z1))


def _town(x, z):
    """The old town's terraces: 14 at the harbour's walls (just under their
    walks), up STEP at each of STEPS to TOWN_TOP, falling away north of them;
    its west quarter in 7 m steps with the Guindais stair's grade (to 70)."""
    k = sum(1 for s in STEPS if z <= s + 1e-6)
    y = 14.0 + STEP * k

    if z < STEPS[-1] - 40.0:
        y = TOWN_TOP - 0.6 * (STEPS[-1] - 40.0 - z)

    if x < -99.0:
        w = 14.0 + 7.0 * math.floor(max(0.0, min(70.0, stair_y(z) - 0.5) - 14.0) / 7.0)
        y += (w - y) * min(1.0, (-99.0 - x) / 80.0)

    return y


def _land(x, z):
    """The rock's ground before the gorge is cut: the town, the summit, the
    east shoulder, the aqueduct's valley, the two terraces."""
    y = max(_town(x, z), 100.0 - 0.3 * max(0.0, math.hypot(x - CASTLE[0], z - CASTLE[1]) - 60.0))

    if x > 155.0 and z > -262.0:
        y = max(y, 26.0 + 49.0 * _smooth((-z - 12.0) / 218.0) + _ripple(x, z, 1.0))

    if x > 40.0 and z < -262.0:
        y = max(y, 40.0 + 35.0 * _smooth((z + 330.0) / 68.0) + 45.0 * _smooth((-540.0 - z) / 80.0) + _ripple(x, z, 1.5))

    for rect, top in (CATHEDRAL, PALACE):
        y = max(y, top - 2.0 * _outside(x, z, rect))

    return y


def _gorge(x, z, land):
    """The gorge cut through the land: its floor, its walls to the rim (the
    west side's hills at the rim, the east side's land no lower than it
    along its edge)."""
    xr, half, bed, rim = river_x(z), _half(z), _bed(z), _rim(z)
    east, west = _walls(z)

    if abs(x - xr) <= half:
        return bed

    if x > xr:
        top_x = xr + half + east
        edge = max(_land(top_x, z), rim)

        if x < top_x:
            return bed + (edge - bed) * (x - xr - half) / east

        return max(land, rim - 0.4 * (x - top_x))

    top_x = xr - half - west

    if x > top_x:
        return bed + (rim - bed) * (xr - half - x) / west

    return rim + _ripple(x, z, 1.5)


def height(x, z):
    """The rock's height at (x, z) (SUNK where the harbour's own is)."""
    if _harbour(x, z):
        return SUNK

    if z > -152.0 and x < -181.0:
        return river(x, z)

    if z <= -152.0:
        return _gorge(x, z, _land(x, z))

    y = _land(x, z)

    if abs(x - SQUARE[0]) < SQUARE[1] and z > SQUARE[2]:
        y = min(y, 2.0)

    return y


def _slot(x, y, z, slope):
    if slope > 50.0:
        return "cliff_shore"

    if slope > 24.0:
        return "rock_shore"

    if -180.0 < x < 150.0 and z > -265.0 and y < 60.0:
        return "calcada"

    return "grass"


def _cliffs(L):
    # (The rock banded by height as the harbour's is: shore.gdshader.)
    # The north shore of the sea east of the mole, the headland's end.
    L.terrain(terrain.cliff("north_shore", "rock", [(X1, -11.5), (152.5, -11.5)], -6.0, 27.0, band=6.0, jitter=0.8, seed=21, slot="cliff_shore"))
    # The rock behind the east wall and up beside the old town to the
    # palace's terrace; round the terrace's south and west faces.
    marks = [-11.5, -60.0, -110.0, -160.0, -199.0]

    for i, (za, zb) in enumerate(zip(marks, marks[1:])):
        top = 26.0 + 49.0 * _smooth((-(za + zb) / 2.0 - 12.0) / 218.0) + 1.0
        base = _town(SCARP_X - 3.0, zb) - 3.0
        L.terrain(terrain.cliff("east_scarp_%d" % (i + 1), "rock", [(SCARP_X, za), (SCARP_X, zb)], base, top, band=6.0, jitter=0.8,
                                seed=22 + i, slot="cliff_shore"))

    x0, x1, z0, z1 = PALACE[0]
    L.terrain(terrain.cliff("palace_scarp_s", "palace", [(SCARP_X, z1 + 3.0), (x0 - 3.0, z1 + 3.0)], _town(130.0, z1 + 8.0) - 3.0, PALACE[1] + 1.0,
                            band=6.0, jitter=0.8, seed=27, slot="cliff_shore"))
    L.terrain(terrain.cliff("palace_scarp_w", "palace", [(x0 - 3.0, z1 + 3.0), (x0 - 3.0, z0)], _town(x0 - 8.0, z0) - 3.0, PALACE[1] + 1.0,
                            band=6.0, jitter=0.8, seed=28, slot="cliff_shore"))


def _on(ground, x, z, half_x, half_z):
    """The lowest of the rock's heights under a footprint (its corners and
    middle) and how much they differ; None off the rock."""
    hs = []

    for dx, dz in ((-1, -1), (-1, 1), (1, -1), (1, 1), (0, 0)):
        h = ground.heights(x + dx * half_x, z + dz * half_z)

        if not h:
            return None, None

        hs.append(max(h))

    return min(hs), max(hs) - min(hs)


def _clear(x, z, half_x, half_z, margin=3.0):
    """Whether a footprint keeps off the harbour, the terraces, the Sea
    Gate's square, the gorge and the east shoulder."""
    for dx in (-1.0, 0.0, 1.0):
        for dz in (-1.0, 0.0, 1.0):
            px, pz = x + dx * (half_x + margin), z + dz * (half_z + margin)

            if _harbour(px, pz) or px > SCARP_X - 4.0:
                return False

            if abs(px - SQUARE[0]) < SQUARE[1] + 4.0 and pz > SQUARE[2] - 6.0:
                return False

            if pz < -150.0 and px < river_x(pz) + _half(pz) + _walls(pz)[0] + 12.0:
                return False

    return all(_outside(x, z, rect) > max(half_x, half_z) + margin for rect, _ in (CATHEDRAL, PALACE))


# The old town's rows (kit_massing): their weights; the parish churches'
# spots (each its nave across a row and the next); cypresses in the lanes.
ROWS = [("mass_houses_20", 0.3), ("mass_houses_tall_20", 0.25), ("mass_houses_low_20", 0.2), ("mass_houses_mixed_20", 0.25)]
PARISHES = [(-150.0, -98.0), (-100.0, -142.0), (20.0, -120.0), (100.0, -160.0), (-160.0, -210.0), (125.0, -100.0)]
TOWER_HOUSES = 0.08


def _old_town(L, ground, rng):
    # Rows of houses facing the harbour: behind the Ribeira, then terrace by
    # terrace up to the cathedral's; lanes where one is left out (cypresses
    # in some); a tower house here and there; the parishes' churches first,
    # the rows round them.
    taken = []

    for x, z in PARISHES:
        if _clear(x, z, 6.5, 13.0):
            base, spread = _on(ground, x, z, 6.0, 12.5)

            if base is not None and spread < 9.0:
                L.put("mass_parish", (x, base - 0.6, z), 0.0, "old_town")
                taken.append((x, z, 8.0, 14.0))

    rows = [(z, -176.0, -104.0) for z in (-32.0, -47.0, -62.0)] + [(z, -176.0, 146.0) for z in range(-84, -266, -15)]

    for z, xa, xb in rows:
        x = xa + rng.uniform(0.0, 6.0)

        while x < xb:
            free = not any(abs(x - tx) < 10.0 + hx and abs(z - tz) < 6.1 + hz for tx, tz, hx, hz in taken)

            if rng.random() > 0.16 and free and _clear(x, z, 10.0, 6.1):
                base, spread = _on(ground, x, z, 10.0, 6.1)

                if base is not None and spread < 7.0:
                    if rng.random() < TOWER_HOUSES:
                        # (A merchant's tower in its garden, a cypress by it.)
                        L.put("mass_tower_house", (x - 5.0, base - 0.6, z), 0.0, "old_town")
                        at, _ = _on(ground, x + 4.0, z + 1.0, 1.0, 1.0)

                        if at is not None:
                            L.put("cypress", (x + 4.0, at - 0.3, z + 1.0), rng.uniform(0.0, 360.0), "old_town")
                    else:
                        pick, roll = ROWS[-1][0], rng.random()

                        for name, weight in ROWS:
                            if roll < weight:
                                pick = name
                                break
                            roll -= weight

                        L.put(pick, (x, base - 0.6, z), 0.0, "old_town")
            elif free and _clear(x, z, 4.0, 4.0) and rng.random() < 0.6:
                # (A lane: a garden's cypresses in it.)
                for k in range(1 + int(rng.random() * 3)):
                    cx, cz = x + rng.uniform(-6.0, 6.0), z + rng.uniform(-3.0, 3.0)
                    at, _ = _on(ground, cx, cz, 1.0, 1.0)

                    if at is not None:
                        L.put("cypress", (cx, at - 0.3, cz), rng.uniform(0.0, 360.0), "old_town")

            x += 22.0 + rng.uniform(-1.5, 2.5)

    # The Sea Gate's square: houses on its three sides, facing into it.
    for at, yaw in (((-67.0, -88.0), 90.0), ((-43.0, -88.0), -90.0), ((-55.0, -98.5), 0.0)):
        L.put("mass_houses_tall_20", (at[0], 2.0, at[1]), yaw, "old_town")

    # The terraces' retaining walls, a little up each step (their tops just
    # over the terrace above); the one over the shipyard's lane (its face at
    # z -72, a row of the rock inside it).
    for k, s in enumerate(STEPS):
        upper = 14.0 + STEP * (k + 1)

        for x in (-85.0, -25.0, 15.0, 55.0, 95.0, 135.0):
            if k == 0 and abs(x - SQUARE[0]) < 20.0 + SQUARE[1]:
                continue

            if any(_outside(x + dx, s + 6.0, rect) < 4.0 for rect, _ in (CATHEDRAL, PALACE) for dx in (-20.0, 0.0, 20.0)):
                continue

            L.put("mass_terrace_wall_40", (x, upper - 11.5, s + 5.0), 0.0, "old_town")

    for x in (35.2, 75.2, 115.2, 131.2):
        L.put("mass_terrace_wall_40", (x, 2.5, -73.0), 0.0, "old_town")


def _cathedral(L):
    (x0, x1, z0, z1), top = CATHEDRAL
    L.put("mass_cathedral", (-25.0, top, -225.0), 0.0, "cathedral")
    L.put("mass_belltower", (38.0, top, -200.0), 0.0, "cathedral")

    # Its terrace walled round (south, west, east), over the town's.
    for x in (-69.0, -29.0, 11.0, 31.0):
        L.put("mass_terrace_wall_40", (x, top - 11.5, z1 + 6.0), 0.0, "cathedral")

    for z in (z1 - 20.0, z0 + 20.0):
        L.put("mass_terrace_wall_40", (x0 - 4.0, top - 11.5, z), -90.0, "cathedral")
        L.put("mass_terrace_wall_40", (x1 + 4.0, top - 11.5, z), 90.0, "cathedral")


def _palace(L):
    top = PALACE[1]
    L.put("mass_palace", (150.0, top, -232.0), 0.0, "palace")
    L.put("mass_mirador", (186.0, top, -206.0), 0.0, "palace")

    # Its gardens on its terrace: palms and orange trees round it.
    for k, (x, z) in enumerate(((116.0, -206.0), (128.0, -207.0), (142.0, -206.5), (158.0, -207.0), (172.0, -206.0),
                                (116.0, -258.0), (186.0, -258.0), (186.0, -232.0))):
        L.put("palm_date" if k % 2 == 0 else "orange_tree", (x, top, z), k * 47.0, "palace")


def _aqueduct(L, ground):
    (xa, za), (xb, zb) = AQUEDUCT
    length = math.hypot(xb - xa, zb - za)
    count = int(round(length / 40.0))
    yaw = math.degrees(math.atan2(-(zb - za), xb - xa))

    for i in range(count):
        t = (i + 0.5) / count
        L.put("mass_aqueduct_40", (xa + (xb - xa) * t, 40.0, za + (zb - za) * t), yaw, "aqueduct")


def _gorge_things(L):
    L.put("mass_bridge", (river_x(BRIDGE_Z), _bed(BRIDGE_Z), BRIDGE_Z), 0.0, "gorge")

    # The river on up the gorge (the harbour's ends at z -150): a box round
    # each stretch (water volumes are square to the axes; what of one lies in
    # the gorge's walls is in rock).
    for i, (a, b) in enumerate(zip(RIVER, RIVER[1:])):
        mid = ((a[0] + b[0]) / 2.0, (a[1] + b[1]) / 2.0)
        low = min(_bed(a[1]), _bed(b[1]))
        L.mark("gorge_river_%d" % (i + 1), "water", (mid[0], low - 0.5, mid[1]), 0.0, "gorge",
               size=[abs(b[0] - a[0]) + 2.0 * _half(mid[1]), 3.0, abs(b[1] - a[1]) + 2.0], murk=0.7)


def _castle(L, ground):
    cx, cz = CASTLE
    base, _ = _on(ground, cx, cz, 18.0, 18.0)
    L.put("mass_keep", (cx, base - 0.5, cz), 0.0, "castle")
    radius = 40.0

    for i in range(8):
        a = math.radians(22.5 + 45.0 * i)
        x, z = cx + radius * math.cos(a), cz + radius * math.sin(a)
        at, _ = _on(ground, x, z, 5.0, 5.0)
        L.put("mass_castle_tower", (x, at - 0.5, z), 0.0, "castle")
        b = math.radians(45.0 * (i + 1))
        mx, mz = cx + radius * math.cos(math.radians(22.5)) * math.cos(b), cz + radius * math.cos(math.radians(22.5)) * math.sin(b)
        at, _ = _on(ground, mx, mz, 12.0, 2.0)
        # (Its length along the side, its +z out from the keep.)
        L.put("mass_curtain_30", (mx, at - 0.5, mz), 90.0 - math.degrees(b), "castle")


def _far(L):
    """The far land round it all and the colossus on its shoulder, turned
    40 degrees off the harbour's line so the harbour sees him three
    quarters on, his sword arm toward it."""
    L.terrain(terrain.grid("far_land", "far", FAR_LAND[0], FAR_LAND[1], FAR_LAND[2], FAR_LAND[3], FAR_CELL, far_land, _slot, surface="stone",
                           keep=lambda ys: min(ys) > -500.0, skirt=30.0))
    (cx, cz), _ = COLOSSUS
    toward = math.degrees(math.atan2(-cx, -cz))
    L.put("mass_colossus", (cx, colossus_base() - 6.0, cz), toward - 40.0, "far")


def _distance(L, ground):
    """What the distance's effects need (scripts/Visual/Distance.gd): its
    far lights (torches on the castle's towers and its keep, at the Great
    Bridge's ends, round the cathedral's terrace, on the mirador; the
    balefire on the keep), and its air (mist down the gorge, in the
    aqueduct's valley and the far land's hollows; corpse-lights over the
    gorge's river)."""
    cx, cz = CASTLE
    keep, _ = _on(ground, cx, cz, 18.0, 18.0)
    L.mark("balefire", "far_light", (cx, keep - 0.5 + 51.6, cz), 0.0, "castle", kind="balefire")

    for i in range(8):
        a = math.radians(22.5 + 45.0 * i)
        x, z = cx + 40.0 * math.cos(a), cz + 40.0 * math.sin(a)
        at, _ = _on(ground, x, z, 5.0, 5.0)
        L.mark("far_torch_castle_%d" % (i + 1), "far_light", (x, at - 0.5 + 27.6, z), 0.0, "castle", kind="torch")

    for k, (sx, sz) in enumerate(((1, 1), (1, -1), (-1, 1), (-1, -1))):
        L.mark("far_torch_keep_%d" % (k + 1), "far_light", (cx + sx * 16.5, keep - 0.5 + 52.6, cz + sz * 16.5), 0.0, "castle", kind="torch")

    bx = river_x(BRIDGE_Z)
    for k, side in enumerate((-1.0, 1.0)):
        L.mark("far_torch_bridge_%d" % (k + 1), "far_light", (bx + side * 28.0, _bed(BRIDGE_Z) + 97.0, BRIDGE_Z + 6.8), 0.0, "gorge", kind="torch")

    (x0, x1, z0, z1), top = CATHEDRAL
    for k, (x, z) in enumerate(((x0, z1), (x1, z1), (x0, z0), (x1, z0))):
        L.mark("far_torch_cathedral_%d" % (k + 1), "far_light", (x, top + 1.8, z), 0.0, "cathedral", kind="torch")

    L.mark("far_torch_mirador", "far_light", (186.0, PALACE[1] + 28.5, -206.0), 0.0, "palace", kind="torch")

    # The gorge's mist, stretch by stretch up its river; the corpse-lights
    # over its middle reach.
    for i, (a, b) in enumerate(zip(RIVER[1:], RIVER[2:])):
        mid = ((a[0] + b[0]) / 2.0, (a[1] + b[1]) / 2.0)
        L.mark("far_mist_gorge_%d" % (i + 1), "far_air", (mid[0], _bed(mid[1]) + 14.0, mid[1]), 0.0, "gorge",
               size=[2.0 * _half(mid[1]) + 50.0, 28.0, abs(b[1] - a[1]) + 30.0], kind="mist")

    # Mist lying at the foot of each of the old town's steps, and along the
    # rows over the Ribeira: each tier stands paler over the one below it,
    # the town softening into the harbour's air.
    L.mark("far_mist_town_foot", "far_air", (-140.0, 14.0 + 1.0, -47.0), 0.0, "old_town", size=[76.0, 12.0, 30.0], kind="mist")

    for k, s in enumerate(STEPS):
        L.mark("far_mist_terrace_%d" % (k + 1), "far_air", (-15.0, 14.0 + STEP * k + 1.0, s + 10.0), 0.0, "old_town",
               size=[320.0, 13.0, 16.0], kind="mist")

    L.mark("far_wisps_gorge", "far_air", (river_x(-430.0), _bed(-430.0) + 9.0, -430.0), 0.0, "gorge", size=[46.0, 16.0, 300.0], kind="wisps")
    (ax, az), (bx2, bz) = AQUEDUCT
    valley, _ = _on(ground, (ax + bx2) / 2.0, (az + bz) / 2.0, 4.0, 4.0)
    L.mark("far_mist_aqueduct", "far_air", ((ax + bx2) / 2.0, (valley or 20.0) + 10.0, (az + bz) / 2.0), 0.0, "aqueduct",
           size=[140.0, 24.0, 380.0], kind="mist")

    for k, (x, z) in enumerate(((-300.0, -1100.0), (500.0, -1150.0), (-1150.0, -450.0), (1100.0, -500.0), (150.0, -1700.0))):
        L.mark("far_mist_hollow_%d" % (k + 1), "far_air", (x, far_land(x, z) + 18.0, z), 0.0, "far", size=[420.0, 50.0, 300.0], kind="mist")


def layout():
    L = Layout("city_massing")
    rock = terrain.grid("rock", "rock", X0, Z0, X1, Z1, CELL, height, _slot, surface="stone", keep=lambda ys: min(ys) > SUNK / 2.0,
                        skirt=1.5, occluder=True)
    L.terrain(rock)
    ground = geo.TriGrid(terrain.triangles(rock))
    rng = random.Random(1947)
    _cliffs(L)
    _old_town(L, ground, rng)
    _cathedral(L)
    _palace(L)
    _aqueduct(L, ground)
    _gorge_things(L)
    _castle(L, ground)
    _far(L)
    _distance(L, ground)
    return L.data()
