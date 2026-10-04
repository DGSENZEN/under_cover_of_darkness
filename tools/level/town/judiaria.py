"""The old town's Judiaria (its spec, section 4.3; old_town_spain.md
sections 2-4, Seville's Santa Cruz and Cordoba; old_town_porto.md, the
Judiaria do Olival): patio houses turned inward behind blank whitewashed
walls on eight terraces up the east side of the rock, between the Baixa's
and the Carmo's cliffs (west) and the palace's garden wall (east).

Each terrace has a lane between two rows: a low row of one-storey corner
houses on its south edge facing north, their backs on the step down; and a
row of two-storey patio houses facing south, their backs on the next
step's retaining wall. The lane dog-legs: its rows' depths swap segment by
segment, so it jogs its own width and no view runs down it. Each step is
climbed by two stair-lanes cut between the houses (one under a cobertizo,
a house bridging it, where there is room), and by a thief up the corbels
at the back of a plazuela; gated adarves run back from the lanes to dead
ends; the azoteas are linked house to house in chains, each up a stair on
a plazuela's side; cisterns lie under two plazuelas. The Baixa climbs to it
by two stair towers from the Rossio, each into a court shut by an iron
gate at curfew; the Carmo by two stairs along its cliff. Laid by
layouts/old_town/judiaria.py (plan B1a, Task 16).

    PLATES      its terraces, south to north
    SEGMENTS    each terrace's cuts along x and its south row's depth in each
    STEPS       each step: its line, foot, rise, stairs, plazuela
    LOTS, ROWS  its houses and what stands in each row
    WALLS       its walls and pieces, {"kind", "args", "at", "yaw"}
    TERRACE     every piece the kit builds for it

Godot's axes: north is -z; a north-row lot faces south (yaw 0), a
south-row lot north (yaw 180).
"""

import math
import random

from town import Lot, TERRACES

WEST = 15.0
# The palace's garden wall's face (its body on to the plates' edge, x 151).
EAST = 150.2
# The plates' east edge (the massing rock's grid line): the steps' walls run
# on under the garden wall to it.
EDGE = 151.0
BOUNDARY_H = 5.0
LANE = 3.0
CUTS = 7
# The longest a lane runs between its jogs.
SEGMENT = 25.0
MIN_LOT = 4.5
# The narrowest walled garden left between a lane's cut and a span.
GARDEN = 1.2
# The shallowest two-storey patio house (its hall, a patio, its back room).
SMALL_DEPTH = 10.0
PLAZUELA = 9.0
COURT = 6.0
EDGE_COURT = 2.5
CORBEL_HEAD = 2.0
COBERTIZO = 3.0
SETBACK = 4.5
CELL = 2.5
BAIXA_G = 2.5
# The harbour's shipyard under the first terrace's south edge.
HARBOUR_G = 2.5
# The harbour's city wall west of the shipyard (its inner face's x, its
# north end's z): the first terrace's south-west corner stands on it.
CITY_WALL = (16.4, -75.5)
# A stair-lane's (kit_terrace.stair_lane's: tread, landing, longest
# flight); a wall stair's (wall_steps: riser, tread, landing); a retaining
# wall's coping proud of its face.
TREAD, LANDING, FLIGHT = 0.32, 2.0, 12
WALL_RISER, WALL_TREAD, WALL_LANDING = 0.18, 0.28, 1.4
PROUD = 0.1
STAIR_RISER = 0.2
# The quarter gates' and the palace's (kit_terrace.gateway: wall, opening,
# height to the arch's crown); the adarves' (height, to the crown).
GATE = (4.0, 2.5, 3.2)
ADARVE_GATE = (3.6, 3.0)
# A garden's end wall's thickness (kit_terrace.garden_wall's).
GARDEN_WALL = 0.3

PLATES = sorted([t for t in TERRACES if t[1] == "judiaria"], key=lambda t: -t[5])


def south(plate):
    return plate[5]


def north(plate):
    return plate[3]


def level(plate):
    return plate[6]


def plate_named(name):
    return [p for p in PLATES if p[0] == name][0]


def houses_south(plate):
    """Whether a terrace is deep enough for a row of houses on its south
    edge (else walled gardens, the lane along its edge between them)."""
    return south(plate) - north(plate) >= 20.0


def depths(plate):
    """The south row's two depths (one segment's, the next's: they differ
    by the lane's width, so it jogs clear of its own line); on a terrace too
    shallow for two rows of houses, none (the lane along the edge) and a
    walled garden's."""
    d = south(plate) - north(plate)

    if not houses_south(plate):
        return (0.0, LANE)

    a = 6.5 if d >= 27.0 else 5.5
    return (a, a + LANE)


# Each step (between PLATES[k] and PLATES[k + 1]): its two stairs (x of
# their middle, width: a cobertizo over a 3 m one, where there is room), its
# plazuela's west x (the thief's corbels at its back). The top step's
# stairs (the seventh terrace is 15 m deep, one row) climb along its face.
STAIRS = [[(40.0, 3.0), (112.0, 2.5)], [(55.0, 2.5), (128.0, 3.0)], [(33.0, 3.0), (98.0, 2.5)], [(62.0, 2.5), (140.0, 3.0)],
          [(45.0, 3.0), (118.0, 2.5)], [(90.0, 2.5), (135.0, 2.5)], [(50.0, 1.6), (110.0, 1.6)]]
PLAZUELAS = [70.0, 92.0, 120.0, 100.0, 65.0, 75.0, 80.0]
# The roofs' chains: the steps whose plazuela has a wall stair up its west
# side to the azotea of the house west of it, the chain running west.
CHAINS = (1, 3, 5)
CHAIN_HOUSES = 5
# A chain's roofs at most this long (its stair up and its roofs within the
# spec's 25-60 m).
CHAIN_LENGTH = 42.0
MERCHANT = 10.0
# The cisterns: under the plazuelas of these steps.
CISTERNS = (2, 5)
CISTERN_SIZE = (3.0, 2.4)
CISTERN_LEDGE = 1.2
CISTERN_DEPTH = 3.0
CISTERN_CHAMBER = 2.0
SHAFT_OFF = 0.9
# Each terrace's adarve (x of its west side, width): a gated dead end.
ADARVES = {"judiaria_1": (95.0, 1.5), "judiaria_2": (30.0, 1.2), "judiaria_3": (60.0, 1.5), "judiaria_4": (122.0, 1.5),
           "judiaria_5": (95.0, 1.5), "judiaria_6": (110.0, 1.5), "judiaria_8": (75.0, 1.5)}
# The tenement court (a corral, its people's homes kept): (terrace, x0, width).
CORRAL = ("judiaria_2", 106.0, 16.0)
# The stair towers from the Rossio's east end (kit_terrace.stair_tower,
# their backs on the cliff, yaw 180): (terrace, the tower's middle z), the
# Rossio's mouth onto the 2.6 m lane under the cliff kept clear; the
# thief's corbels from that lane (terrace, ground, z); the Carmo's stairs
# along its cliff (terrace, the ground at their foot, their foot's z); the
# Carmo's corbels (terrace, ground, z).
TOWERS = [("judiaria_3", -154.8), ("judiaria_4", -165.9)]
BAIXA_CORBELS = ("judiaria_2", BAIXA_G, -115.0)
CARMO_STAIRS = [("judiaria_4", 26.0, -183.0), ("judiaria_5", 28.0, -217.0)]
CARMO_CORBELS = ("judiaria_6", 28.0, -235.0)
CARMO_STAIR_WIDTH = 2.0
# The east wall-walk's arrival (kept: the first terrace's south row open
# from here to the garden wall, its south-east corner open to the walk).
WALK_ARRIVAL = 138.0
WALK = (150.0, -75.0)
# The tower's (kit_terrace's: its flights' steps and riser, its breadth and
# length outside, its doors from its middle).
TOWER_STEPS, TOWER_RISER, TOWER_BREADTH, TOWER_LENGTH, TOWER_DOOR = 10, 0.18, 3.7, 6.6, 2.1


def _steps():
    out = []

    for k in range(len(PLATES) - 1):
        low, high = PLATES[k], PLATES[k + 1]
        rise = round(level(high) - level(low), 3)
        steps = int(math.ceil(rise / STAIR_RISER - 1e-9))
        out.append({"z": north(low), "y": level(low), "rise": rise, "steps": steps, "riser": rise / steps, "stairs": STAIRS[k],
                    "plazuela": PLAZUELAS[k], "along": not houses_south(low)})

    return out


STEPS = _steps()


def stair_run(step):
    """A stair-lane's run up its step."""
    n = step["steps"]
    flights = int(math.ceil(n / float(FLIGHT))) if n > FLIGHT else 1
    return n * TREAD + (flights - 1) * LANDING


def wall_run(rise):
    """A wall stair's run (its steps at WALL_TREAD, its landing)."""
    return int(math.ceil(rise / WALL_RISER - 1e-9)) * WALL_TREAD + WALL_LANDING


def tower_at(plate, z):
    """A Rossio tower's middle (x, z), height, and its top door's z (yaw 180:
    its own +z runs to the world's -z)."""
    height = round(level(plate_named(plate)) - BAIXA_G, 3)
    per = min(TOWER_STEPS, int(math.ceil(height / TOWER_RISER - 1e-9)))
    flights = int(math.ceil(height / (per * TOWER_RISER) - 1e-9))
    top_local = TOWER_DOOR if flights % 2 else -TOWER_DOOR
    return (WEST - 0.1 - TOWER_BREADTH / 2.0, z), height, z - top_local


def carmo_head(foot_z, rise):
    """A Carmo stair's landing's middle z (it climbs south from its foot)."""
    return foot_z + wall_run(rise) - WALL_LANDING / 2.0


def _west_places():
    """What stands at the quarter's west edge: (plate, z it opens at, kind,
    width kept east of the edge)."""
    out = []

    for name, z in TOWERS:
        out.append((name, tower_at(name, z)[2], "gate_court", COURT))

    out.append((BAIXA_CORBELS[0], BAIXA_CORBELS[2], "edge_court", EDGE_COURT))
    out.append((CARMO_CORBELS[0], CARMO_CORBELS[2], "edge_court", EDGE_COURT))

    for name, ground, foot in CARMO_STAIRS:
        rise = level(plate_named(name)) - ground
        out.append((name, carmo_head(foot, rise), "carmo_court", COURT))

    return out


def _spans():
    """What each terrace's rows keep from houses along x (the west places'
    rows read once the lane is cut): {(plate, row): [(x0, x1, kind)]}."""
    out = {}

    def keep(name, row, x0, x1, kind):
        out.setdefault((name, row), []).append((x0, x1, kind))

    for k, step in enumerate(STEPS):
        low, high = PLATES[k], PLATES[k + 1]

        for c, w in step["stairs"]:
            if step["along"]:
                run = wall_run(step["rise"])
                keep(low[0], "north", c - run / 2.0 - 0.5, c + run / 2.0 + 0.5, "stair_court")
                keep(high[0], "south", c + run / 2.0 - 1.6, c + run / 2.0 + 0.4, "stair_head")
            else:
                keep(low[0], "north", c - w / 2.0, c + w / 2.0, "stair")
                keep(high[0], "south", c - w / 2.0, c + w / 2.0, "stair_head")

        p = step["plazuela"]
        keep(low[0], "north", p, p + PLAZUELA, "plazuela")
        keep(high[0], "south", p + PLAZUELA / 2.0 - CORBEL_HEAD / 2.0, p + PLAZUELA / 2.0 + CORBEL_HEAD / 2.0, "corbel_head")

    for name, (x0, w) in ADARVES.items():
        keep(name, "north", x0, x0 + w, "adarve")

    keep(PLATES[0][0], "south", WALK_ARRIVAL, EAST, "arrival")
    keep(CORRAL[0], "north", CORRAL[1], CORRAL[1] + CORRAL[2], "corral")
    return out


def _intervals(x0, x1, cuts):
    out, at = [], x0

    for a, b in sorted(cuts):
        if a > at + 1e-6:
            out.append((at, min(a, x1)))

        at = max(at, b)

    if at < x1 - 1e-6:
        out.append((at, x1))

    return [(a, b) for a, b in out if b - a > 1e-6]


def _cuts(plate, k, spans):
    """A terrace's cuts along x: about evenly spaced (the lane's views
    under 25 m), each either a lot's width clear of everything kept in
    either row (the west places' courts too) or on the corral's edge (a
    house's: an open span's would let a view run on through it, a gate be
    walked round)."""
    rng = random.Random(2000 + k)
    kept = [(a, b, kind) for row in ("north", "south") for a, b, kind in spans.get((plate[0], row), [])]
    kept += [(WEST, WEST + width, kind) for name, _z, kind, width in _west_places() if name == plate[0]]
    # (A chain's first house, a merchant's, whole beside its plazuela.)
    kept += [(STEPS[n]["plazuela"] - MERCHANT, STEPS[n]["plazuela"], "chain") for n in CHAINS if PLATES[n] is plate]

    def clear(x, margin):
        return WEST + margin - 1e-6 <= x <= EAST - margin + 1e-6 and all(
            x <= a - margin + 1e-6 or x >= b + margin - 1e-6 or (kind in ("corral", "chain") and (abs(x - a) < 1e-6 or abs(x - b) < 1e-6))
            for a, b, kind in kept)

    def candidates(margin):
        free = _intervals(WEST + margin, EAST - margin, [(a - margin, b + margin) for a, b, _kind in kept])
        return free, [x for a, b, kind in kept if kind in ("corral", "chain") for x in (a, b) if clear(x, margin)]

    cuts = []

    for i in range(1, CUTS):
        target = WEST + (EAST - WEST) * i / CUTS + rng.uniform(-2.0, 2.0)

        # (A lot's width clear of everything kept if one is near enough;
        # else a garden's, a walled garden left beside the span.)
        for margin, reach in ((MIN_LOT, 4.0), (GARDEN, 1e9)):
            free, edges = candidates(margin)
            near = [min(max(target, a), b) for a, b in free] + edges

            if near and min(abs(v - target) for v in near) <= reach:
                break

        if not near:
            continue

        x = min(near, key=lambda v: abs(v - target))
        snapped = round(x * 2.0) / 2.0

        # (On a half metre's grid where that stays clear.)
        if clear(snapped, margin):
            x = snapped

        if all(abs(x - c) >= 10.0 for c in cuts):
            cuts.append(x)

    # (Then any segment still longer than a view should run cut again,
    # nearest its middle, a lot's width clear if it can be.)
    for _ in range(CUTS):
        xs = [WEST] + sorted(cuts) + [EAST]
        long = [(a, b) for a, b in zip(xs, xs[1:]) if b - a > SEGMENT]

        if not long:
            break

        a, b = long[0]
        added = False

        for margin in (MIN_LOT, GARDEN):
            free, edges = candidates(margin)
            middle = (a + b) / 2.0
            near = [v for v in [min(max(middle, fa), fb) for fa, fb in free] + edges if a + 6.0 <= v <= b - 6.0]

            if near:
                x = min(near, key=lambda v: abs(v - middle))
                snapped = round(x * 2.0) / 2.0
                cuts.append(snapped if clear(snapped, margin) and a + 6.0 <= snapped <= b - 6.0 else x)
                added = True
                break

        if not added:
            break

    return sorted(cuts)


def _segments():
    spans = _spans()
    out = {}

    for k, plate in enumerate(PLATES):
        xs = [WEST] + _cuts(plate, k, spans) + [EAST]
        sd = depths(plate)
        out[plate[0]] = [(a, b, sd[(i + k) % 2]) for i, (a, b) in enumerate(zip(xs, xs[1:]))]

    return out, spans


SEGMENTS, _SPANS = _segments()


def segment(plate, x):
    """The segment (x0, x1, south row's depth) of a terrace at x."""
    for seg in SEGMENTS[plate[0]]:
        if seg[0] - 0.01 <= x <= seg[1] + 0.01:
            return seg

    raise ValueError((plate[0], x))


def lane(plate, x):
    """The lane at x on a terrace: (z north, z south)."""
    s = segment(plate, x)[2]
    return south(plate) - s - LANE, south(plate) - s


def row_at(plate, x, z):
    """Which of a terrace's rows (or its lane) lies at (x, z)."""
    zn, zs = lane(plate, x)
    return "south" if z > zs else "lane" if z > zn else "north"


def front(plate, row, x):
    """A row's front line on its lane at x."""
    zn, zs = lane(plate, x)
    return zn if row == "north" else zs


def _reserved():
    """What each terrace's rows keep from houses: {(plate, row): [(x0, x1,
    kind)]}."""
    out = {key: list(v) for key, v in _SPANS.items()}

    for name, z, kind, width in _west_places():
        row = row_at(plate_named(name), WEST + 1.0, z)
        assert row != "lane", (name, z, kind)
        out.setdefault((name, row), []).append((WEST, WEST + width, kind))

    return out


RESERVED = _reserved()


def _widths(rng, length, choices):
    out, left = [], length

    while left > 1e-6:
        w = min(rng.choice(choices), left)

        if left - w < MIN_LOT:
            w = left if left <= max(choices) * 1.4 else left - MIN_LOT

        out.append(round(w, 3))
        left -= w

    return out


def _plan():
    rng = random.Random(2016)
    lots, rows = [], {}
    chain_ends = {PLATES[k][0]: STEPS[k]["plazuela"] for k in CHAINS}

    for k, plate in enumerate(PLATES):
        y = level(plate)

        for row in ("north", "south"):
            items = []
            kept = RESERVED.get((plate[0], row), [])

            for x0, x1, s in SEGMENTS[plate[0]]:
                if row == "south" and not houses_south(plate):
                    # (A walled garden on the edge where the lane jogs in
                    # off it.)
                    if s > 0.0:
                        items += [{"kind": "garden", "x0": a, "x1": b} for a, b in _intervals(x0, x1, [(ka, kb) for ka, kb, _kind in kept])]

                    continue

                for a, b in _intervals(x0, x1, [(ka, kb) for ka, kb, _kind in kept]):
                    if b - a < MIN_LOT:
                        items.append({"kind": "garden", "x0": a, "x1": b})
                        continue

                    zf = front(plate, row, (a + b) / 2.0)
                    d = zf - north(plate) if row == "north" else south(plate) - zf

                    if row == "north" and abs(b - chain_ends.get(plate[0], -1.0)) < 0.01 and b - a >= MERCHANT:
                        # (A chain's house beside its plazuela a merchant's:
                        # its lookout over the chain.)
                        rest = b - a - MERCHANT
                        widths = (_widths(rng, rest, (6.0, 6.5, 7.0, 7.5)) if rest >= MIN_LOT else []) + [MERCHANT + (rest if rest < MIN_LOT else 0.0)]
                    else:
                        widths = _widths(rng, b - a, (6.0, 6.5, 7.0, 7.5, 10.0) if row == "north" else (6.0, 7.0, 8.0, 9.0))

                    at = a

                    for w in widths:
                        # (One storey on the south edge, and where a row is
                        # too shallow for a two-storey house's patio.)
                        low = row == "south" or d < SMALL_DEPTH
                        kind = "corner" if low else ("merchant" if w >= 9.5 else "small")
                        quirk = "shrine" if row == "south" and rng.random() < 0.2 else ""
                        lot = Lot("%s_%s_%d" % (plate[0], row[0], len(lots) + 1), "patio", at + w / 2.0, zf, y, 0.0 if row == "north" else 180.0,
                                  w, d, 1 if low else 2, quirk, False, 0, False, "",
                                  (("kind", kind), ("seed", rng.randrange(1000))))
                        lots.append(lot)
                        items.append({"kind": "house", "x0": at, "x1": at + w, "lot": lot.name})
                        at += w

            for a, b, kind in kept:
                if kind == "corral":
                    zf = front(plate, row, (a + b) / 2.0)
                    lot = Lot("%s_corral" % plate[0], "patio", (a + b) / 2.0, zf, y, 0.0, b - a, zf - north(plate), 2, "", True, 3, True, "",
                              (("kind", "corral"), ("seed", 7)))
                    lots.append(lot)
                    items.append({"kind": "house", "x0": a, "x1": b, "lot": lot.name})
                else:
                    items.append({"kind": kind, "x0": a, "x1": b})

            rows[(plate[0], row)] = sorted(items, key=lambda i: i["x0"])

    lots = _quirks(lots, rows)
    # About one house in five or six walked in (none too shallow for a
    # patio, nor a chain's or a cobertizo's), a third of them lived in.
    deep = [i for i, each in enumerate(lots) if not each.enterable and each.depth >= 8.0 and each.width >= 6.0 and each.quirk not in ("linked", "bridge")]
    chosen = sorted(rng.sample(deep, int(round(len(lots) / 6.0))))

    for n, i in enumerate(chosen):
        lots[i] = _with(lots[i], enterable=True, rooms=rng.choice((1, 2, 2, 3)), lived=n % 3 == 0)

    return lots, rows


def _with(lot, **change):
    fields = dict(name=lot.name, family=lot.family, x=lot.x, z=lot.z, y=lot.y, yaw=lot.yaw, width=lot.width, depth=lot.depth,
                  storeys=lot.storeys, quirk=lot.quirk, enterable=lot.enterable, rooms=lot.rooms, lived=lot.lived, sector=lot.sector,
                  params=lot.params)
    fields.update(change)
    return Lot(**fields)


def bridge_fits(k, c):
    """Whether step k's stair-lane at c climbs the step behind a
    cobertizo's setback within the north row's depth."""
    step = STEPS[k]
    zn, _zs = lane(PLATES[k], c)
    return zn - step["z"] - SETBACK >= stair_run(step) - 1e-6


def chain_items(rows, k):
    """The row items (houses, east to west) in step k's chain: from its
    plazuela west while the houses run on side by side."""
    p = STEPS[k]["plazuela"]
    row = rows[(PLATES[k][0], "north")]
    chain = []

    for item in sorted((i for i in row if i["x1"] <= p + 0.01), key=lambda i: -i["x1"]):
        if item["kind"] != "house" or item["lot"].endswith("_corral"):
            break

        if (chain and abs(item["x1"] - chain[-1]["x0"]) > 0.01) or (not chain and abs(item["x1"] - p) > 0.01):
            break

        if chain and sum(i["x1"] - i["x0"] for i in chain) + item["x1"] - item["x0"] > CHAIN_LENGTH:
            break

        chain.append(item)

        if len(chain) == CHAIN_HOUSES:
            break

    return chain


def _quirks(lots, rows):
    """The cobertizos (the house west of each 3 m stair bridging it, where
    the stair has room behind it) and the roofs' chains (the houses west of
    a chain's plazuela, linked)."""
    named = {each.name: each for each in lots}

    for k, step in enumerate(STEPS):
        row = rows[(PLATES[k][0], "north")]

        if not step["along"]:
            for c, w in step["stairs"]:
                if abs(w - COBERTIZO) > 0.01 or not bridge_fits(k, c):
                    continue

                west = [i for i in row if i["kind"] == "house" and abs(i["x1"] - (c - w / 2.0)) < 0.01]
                east = [i for i in row if i["kind"] == "house" and abs(i["x0"] - (c + w / 2.0)) < 0.01]

                if west and east:
                    named[west[0]["lot"]] = _with(named[west[0]["lot"]], quirk="bridge")

        if k in CHAINS:
            for item in chain_items(rows, k):
                named[item["lot"]] = _with(named[item["lot"]], quirk="linked")

    return [named[each.name] for each in lots]


LOTS, ROWS = _plan()


def lot_rect(lot):
    if abs(lot.yaw - 180.0) < 0.01:
        return (lot.x - lot.width / 2.0, lot.z, lot.x + lot.width / 2.0, lot.z + lot.depth)

    return (lot.x - lot.width / 2.0, lot.z - lot.depth, lot.x + lot.width / 2.0, lot.z)


def chain_lots(k):
    """Step k's chain's houses, east to west."""
    named = {each.name: each for each in LOTS}
    return [named[i["lot"]] for i in chain_items(ROWS, k)]


def _neighbour(z):
    """The ground west of the quarter at z: the Baixa's (the Rossio's) or
    the Carmo's."""
    import town
    return town.height(WEST - 0.6, z)


def cells(plate):
    """A plate's ground's cells across x and along z (layouts/old_town/
    ground.py's: its extent over the whole number of CELLs nearest; the
    Judiaria's 136 m across in 54)."""
    x0, z0, x1, z1 = plate[2], plate[3], plate[4], plate[5]
    return (x1 - x0) / max(1, int(round((x1 - x0) / CELL))), (z1 - z0) / max(1, int(round((z1 - z0) / CELL)))


def cistern(k):
    """Step k's cistern under its plazuela: its vault's x, its floor's y,
    its hatch (x, z) at a ground cell's middle near the plazuela's front,
    the vault's north end's z."""
    plate = PLATES[k]
    cx, cz = cells(plate)
    middle = STEPS[k]["plazuela"] + PLAZUELA / 2.0
    hx = min((plate[2] + cx * (i + 0.5) for i in range(int(round((plate[4] - plate[2]) / cx)))), key=lambda x: abs(x - (middle + SHAFT_OFF)))
    zn, _zs = lane(plate, middle)
    hz = max(z for z in (north(plate) + cz * (j + 0.5) for j in range(int(round((south(plate) - north(plate)) / cz)))) if z <= zn - 2.5)
    return hx - SHAFT_OFF, level(plate) - CISTERN_DEPTH, (hx, hz), north(plate) + 1.5


HOLES = [cistern(k)[2] for k in CISTERNS]
HATCH_DEPTH = round(CISTERN_DEPTH - CISTERN_SIZE[1] - 0.3, 3)


def chain_stair(k):
    """Step k's wall stair up its plazuela's west side to the chain's east
    house's azotea, its landing at the house's roof gap: (its args, its
    foot (x, y, z))."""
    plate = PLATES[k]
    eaves = 7.6 if chain_lots(k)[0].storeys == 2 else 4.0
    run = round(wall_run(eaves), 3)
    width = 1.2
    link = north(plate) + 2.5
    return (eaves, run, width), (STEPS[k]["plazuela"] + width / 2.0, level(plate), link + run - WALL_LANDING / 2.0)


def palace_gate():
    """The palace gate's z: at the end of the sixth terrace's lane."""
    zn, zs = lane(plate_named("judiaria_6"), EAST - 1.0)
    return (zn + zs) / 2.0


def _walls():
    out = {k: [] for k in ("retaining", "stair", "parapet", "west", "south", "boundary", "gate", "corbels", "towers", "carmo", "adarve",
                           "garden", "chain", "cistern")}

    for k, step in enumerate(STEPS):
        low, high = PLATES[k], PLATES[k + 1]
        cuts = [] if step["along"] else [(c - w / 2.0, c + w / 2.0) for c, w in step["stairs"]]

        for a, b in _intervals(WEST, EDGE, cuts):
            out["retaining"].append({"kind": "retaining", "args": (round(b - a, 3), step["rise"]), "at": ((a + b) / 2.0, step["y"], step["z"]),
                                     "yaw": 0.0})

        for c, w in step["stairs"]:
            if step["along"]:
                run = round(wall_run(step["rise"]), 3)
                # (Up the step's face eastward, against it; off its landing
                # north onto the terrace above.)
                out["stair"].append({"kind": "wall_steps", "args": (step["rise"], run, w),
                                     "at": (c - run / 2.0, step["y"], step["z"] + PROUD + w / 2.0), "yaw": 90.0, "step": k, "c": c})
            else:
                out["stair"].append({"kind": "stair_lane", "args": (w, step["steps"], step["riser"]),
                                     "at": (c, step["y"], step["z"] + stair_run(step)), "yaw": 180.0, "step": k, "c": c})

        # (A parapet on the step's top where nothing stands on its edge
        # but a stair's head.)
        guarded = [(i["x0"], i["x1"]) for i in ROWS[(high[0], "south")] if i["kind"] in ("house", "stair_head")]

        for a, b in _intervals(WEST, EAST, guarded):
            if b - a > 0.3:
                out["parapet"].append({"kind": "parapet", "args": (round(b - a, 3),), "at": ((a + b) / 2.0, level(high), step["z"]), "yaw": 0.0})

        # (The thief's corbels up the back of the plazuela.)
        p = step["plazuela"]
        out["corbels"].append({"kind": "corbels", "args": (step["rise"],), "at": (p + PLAZUELA / 2.0, step["y"], step["z"]), "yaw": 0.0, "step": k})

    for plate in PLATES:
        y = level(plate)
        z0, z1 = north(plate), south(plate)
        # (The west cliff, split where the ground under it changes; the
        # first terrace's from the harbour's wall north.)
        top = min(z1, CITY_WALL[1]) if plate is PLATES[0] else z1
        splits = sorted({z0, top} | {c for c in (-170.0, -185.0, -265.0) if z0 < c < top})

        for a, b in zip(splits, splits[1:]):
            below = _neighbour((a + b) / 2.0)

            if y - below > 0.3:
                out["west"].append({"kind": "retaining", "args": (round(b - a, 3), round(y - below, 3)), "at": (WEST, below, (a + b) / 2.0),
                                    "yaw": -90.0})

        # (Its parapet along the west edge where no house stands on it: but
        # where a tower's top door or a Carmo stair's landing opens.)
        covered = [(lot_rect(each)[1], lot_rect(each)[3]) for each in LOTS if abs(each.y - y) < 0.01 and lot_rect(each)[0] <= WEST + 0.01]

        for name, z in TOWERS:
            if name == plate[0]:
                covered.append((z - TOWER_LENGTH / 2.0, z + TOWER_LENGTH / 2.0))

        for name, ground, foot in CARMO_STAIRS:
            if name == plate[0]:
                head = carmo_head(foot, y - ground)
                covered.append((head - WALL_LANDING / 2.0, head + WALL_LANDING / 2.0))

        if plate is PLATES[0]:
            covered.append((CITY_WALL[1], z1))

        for a, b in _intervals(z0, z1, covered):
            if b - a > 0.3 and y - _neighbour((a + b) / 2.0) > 0.9:
                out["parapet"].append({"kind": "parapet", "args": (round(b - a, 3),), "at": (WEST, y, (a + b) / 2.0), "yaw": -90.0})

        # (The palace's garden wall on the east, the sealed gate at the end
        # of the sixth terrace's lane; the first terrace's open south of
        # the walk's arrival.)
        za = WALK[1] if plate is PLATES[0] else z1
        gate = palace_gate() if plate[0] == "judiaria_6" else None
        gaps = [(gate - GATE[0] / 2.0, gate + GATE[0] / 2.0)] if gate is not None else []

        for a, b in _intervals(z0, za, gaps):
            out["boundary"].append({"kind": "retaining", "args": (round(b - a, 3), BOUNDARY_H, False, "ashlar_weathered"),
                                    "at": (EAST, y, (a + b) / 2.0), "yaw": -90.0})

        if gate is not None:
            out["gate"].append({"kind": "gateway", "args": (GATE[0], BOUNDARY_H, GATE[1], GATE[2], False, "ashlar_weathered"),
                                "at": (EAST + 0.4, y, gate), "yaw": 90.0, "palace": True})

    # The first terrace's south edge over the harbour's shipyard: its cliff
    # from the harbour's wall east to the walk's, a parapet where no house
    # stands on it.
    first = PLATES[0]
    y1 = level(first)
    out["south"].append({"kind": "retaining", "args": (round(WALK[0] - CITY_WALL[0], 3), round(y1 - HARBOUR_G, 3)),
                         "at": ((CITY_WALL[0] + WALK[0]) / 2.0, HARBOUR_G, south(first)), "yaw": 0.0})
    guarded = [(i["x0"], i["x1"]) for i in ROWS[(first[0], "south")] if i["kind"] == "house"] + [(WEST, CITY_WALL[0]), (WALK[0], EAST + 1.0)]

    for a, b in _intervals(WEST, EAST, guarded):
        if b - a > 0.3:
            out["parapet"].append({"kind": "parapet", "args": (round(b - a, 3),), "at": ((a + b) / 2.0, y1, south(first)), "yaw": 0.0})

    # The towers, the corbels up the cliffs, the Carmo's stairs.
    for name, z in TOWERS:
        (x, zm), height, _door = tower_at(name, z)
        out["towers"].append({"kind": "stair_tower", "args": (height,), "at": (x, BAIXA_G, zm), "yaw": 180.0, "plate": name})

    for name, ground, z in (BAIXA_CORBELS, CARMO_CORBELS):
        height = round(level(plate_named(name)) - ground, 3)
        out["corbels"].append({"kind": "corbels", "args": (height,), "at": (WEST, ground, z), "yaw": -90.0, "plate": name})

    for name, ground, foot in CARMO_STAIRS:
        rise = round(level(plate_named(name)) - ground, 3)
        out["carmo"].append({"kind": "wall_steps", "args": (rise, round(wall_run(rise), 3), CARMO_STAIR_WIDTH),
                             "at": (WEST - PROUD - CARMO_STAIR_WIDTH / 2.0, ground, foot), "yaw": 0.0, "plate": name})

    # The quarter's two gates: across each tower's court's mouth on its lane.
    for name, z in TOWERS:
        plate = plate_named(name)
        door = tower_at(name, z)[2]
        row = row_at(plate, WEST + 1.0, door)
        out["gate"].append({"kind": "gateway", "args": (COURT, 4.0, GATE[1], GATE[2], True),
                            "at": (WEST + COURT / 2.0, level(plate), front(plate, row, WEST + 1.0)), "yaw": 0.0, "quarter": True})

    # Each adarve's gate across its mouth (its piers into its neighbours'
    # fronts).
    for name, (x0, w) in ADARVES.items():
        plate = plate_named(name)
        out["adarve"].append({"kind": "gateway", "args": (w + 1.0, ADARVE_GATE[0], w, ADARVE_GATE[1], True),
                              "at": (x0 + w / 2.0, level(plate), front(plate, "north", x0 + w / 2.0)), "yaw": 0.0, "plate": name})

    # The gardens' walls: a barred gate in each one's front on the lane (a
    # plain wall across a narrow one), a wall down each end to its back but
    # where a house of its own row and depth stands beside it, or the
    # quarter's own edge.
    for plate in PLATES:
        y = level(plate)

        for row in ("north", "south"):
            items = ROWS.get((plate[0], row), [])

            for n, item in enumerate(items):
                if item["kind"] != "garden":
                    continue

                a, b = item["x0"], item["x1"]
                zf = front(plate, row, (a + b) / 2.0)
                back = north(plate) if row == "north" else south(plate)
                inward = -1.0 if row == "north" else 1.0
                yaw = 0.0 if row == "north" else 180.0

                if b - a >= 2.4:
                    out["garden"].append({"kind": "yard_front", "args": (round(b - a, 3),), "at": ((a + b) / 2.0, y, zf), "yaw": yaw})
                else:
                    out["garden"].append({"kind": "garden_wall", "args": (round(b - a, 3),),
                                          "at": ((a + b) / 2.0, y, zf + inward * GARDEN_WALL / 2.0), "yaw": 0.0})

                for x, sx, beside in ((a, 1.0, items[n - 1] if n > 0 else None), (b, -1.0, items[n + 1] if n + 1 < len(items) else None)):
                    covered = (beside is not None and beside["kind"] == "house"
                               and abs(segment(plate, beside["x0"] + 0.01)[2] - segment(plate, a + 0.01)[2]) < 1e-6)
                    edge = x < WEST + 0.01 or x > EAST - 0.01

                    if not covered and not edge:
                        out["garden"].append({"kind": "garden_wall", "args": (round(abs(back - zf), 3),),
                                              "at": (x + sx * GARDEN_WALL / 2.0, y, (zf + back) / 2.0), "yaw": 90.0})

    for k in CHAINS:
        args, at = chain_stair(k)
        out["chain"].append({"kind": "wall_steps", "args": args, "at": at, "yaw": 180.0, "step": k})

    w, h = CISTERN_SIZE

    for k in CISTERNS:
        x, y, (hx, hz), back = cistern(k)
        chamber_n = hz - CISTERN_CHAMBER / 2.0
        length = round(chamber_n - back, 3)
        out["cistern"] += [{"kind": "hatch_chamber", "args": (w, h, CISTERN_CHAMBER, CISTERN_LEDGE), "at": (x, y, hz), "yaw": 0.0, "step": k},
                           {"kind": "vault", "args": (w, h, length, CISTERN_LEDGE, "cistern", "brick"), "at": (x, y, (chamber_n + back) / 2.0),
                            "yaw": 0.0, "step": k},
                           {"kind": "vault_end", "args": (w, h, True), "at": (x, y, back - 0.15), "yaw": 0.0, "step": k},
                           {"kind": "vault_end", "args": (w, h, True), "at": (x, y, hz + CISTERN_CHAMBER / 2.0 + 0.15), "yaw": 180.0, "step": k},
                           {"kind": "grate_hatch", "args": (HATCH_DEPTH, tuple(round(c, 4) for c in cells(PLATES[k]))), "at": (hx, level(PLATES[k]), hz),
                            "yaw": 0.0, "step": k}]

    return out


WALLS = _walls()
TERRACE = [(w["kind"], w["args"]) for group in WALLS.values() for w in group]
