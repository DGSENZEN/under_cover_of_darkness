"""The old town's Carmo hill (its spec, sections 4.3, 4.4 and 16;
old_town_lisbon.md sections 4 and 7): Lisbon's Chiado and the Carmo, on
three terraces over the Baixa. Its lots, and the terrace pieces it asks the
kit for; laid by layouts/old_town/carmo.py (plan B1a, Task 17).

    The lookout   the first terrace (LOOK), on a cliff more than 20 m over
                  the Baixa's Rossio: a miradouro, its pergola and azulejo
                  benches, two lamp posts; up from the Rossio by two stair
                  towers (public) and stone ledges (a thief's)
    The square    the second (SQUARE): the burned church left roofless,
                  its axis pointing at the comet (its light comes down the
                  nave onto the altar: the spec's 16), the watch house its
                  convent beside its apse, turned with it; the Largo before
                  its portal with the dolphin fountain; a Pombaline row on
                  the Largo's west, the convent's offices by the watch house
    The high      the third (HIGH): a Pombaline row under the upper town's
                  cliff, its lane before it

Every number here is the plan; the layout lays it. Godot's axes: north is
-z; a lot's x, z are its front's middle (town.Lot).
"""

import math
import random

from town import Lot

BAIXA_G = 2.5
LOOK = 26.0
SQUARE = 28.0
HIGH = 40.0
WEST, EAST = -100.0, 15.0
CLIFF_Z = -170.0
STEP_Z = -185.0
HIGH_Z = -265.0
NORTH = -290.0
LOOKOUT = (WEST, STEP_Z, EAST, CLIFF_Z)

# The comet's head in the sky (scripts/Night/night_sky.gdshader's
# comet_head): its light falls from there (plan Task 20's comet_shaft).
COMET = (-0.42, 0.52, -0.74)
# The church: its front, four bays (the second and fourth arches whole), its
# transept and its apse along its axis (kit_carmo); flying buttresses on its
# local +x side at these distances from its front (its bays' piers; the
# last short of the transept's arm).
RUIN_PARTS = (("carmo_front", 3.0), ("carmo_bay_broken", 11.0), ("carmo_bay_whole", 11.0), ("carmo_bay_broken", 11.0), ("carmo_bay_whole", 11.0),
              ("carmo_transept", 11.0), ("carmo_apse", 14.0))
RUIN_LENGTH = sum(n for _p, n in RUIN_PARTS)
BUTTRESSES = (3.0, 14.0, 25.0, 36.0, 44.0)
# Its buttresses' piers out from its axis (kit_carmo: the aisles' outer
# wall OUTER, the flyer's span).
BUTTRESS_OUT = 13.8 + 9.4
# Where its apse's end stands (x, z): the church runs from there toward the
# comet.
APSE_END = (-24.0, -191.0)
# The watch house (kit_watch) beside the apse, its cloister's broken wall
# GAP off the apse's wall, its middle line ALONG along the apse (the apse's
# own z: 0 its open end on the transept, -14 its east end).
WATCH_GAP = 3.0
WATCH_ALONG = -10.0
APSE_HALF = 5.0 + 1.2
WATCH_DEPTH = 12.0 + 12.0


def _flat(v):
    h = math.hypot(v[0], v[2])
    return v[0] / h, v[2] / h


AXIS = _flat(COMET)
# (Its yaw: its local -z, from its front to its apse, away from the comet.)
RUIN_YAW = math.degrees(math.atan2(AXIS[0], AXIS[1]))
WATCH_YAW = RUIN_YAW - 90.0


def turn(yaw, x, z):
    """(x, z) turned by yaw (Godot's: x' = x cos + z sin, z' = -x sin + z cos)."""
    a = math.radians(yaw)
    return x * math.cos(a) + z * math.sin(a), -x * math.sin(a) + z * math.cos(a)


def ruin_front():
    """The church's front's middle (x, z): RUIN_LENGTH from its apse's end
    toward the comet."""
    return APSE_END[0] + AXIS[0] * RUIN_LENGTH, APSE_END[1] + AXIS[1] * RUIN_LENGTH


def ruin_at(local):
    """A point of the church's own frame (x, y, z: its front at z 0, its
    apse to -z) in the world."""
    fx, fz = ruin_front()
    dx, dz = turn(RUIN_YAW, local[0], local[2])
    return [fx + dx, SQUARE + local[1], fz + dz]


def ruin_parts():
    """Each part of the church: (piece, its origin in the world, the
    distance along from its front)."""
    out, s = [], 0.0

    for piece, length in RUIN_PARTS:
        out.append((piece, ruin_at([0.0, 0.0, -s]), s))
        s += length

    return out


def buttresses():
    """Each buttress's pier (its origin in the world)."""
    return [ruin_at([BUTTRESS_OUT, 0.0, -s]) for s in BUTTRESSES]


def apse_at(local):
    """A point of the apse's own frame in the world."""
    return ruin_at([local[0], local[1], local[2] - (RUIN_LENGTH - 14.0)])


def watch_at():
    """The watch house's front's middle (x, z): its cloister's end WATCH_GAP
    off the apse's wall on its -x side (the cloister door's), its middle
    line at WATCH_ALONG along the apse; its own -z toward the apse."""
    p = apse_at([-(APSE_HALF + WATCH_GAP + WATCH_DEPTH), 0.0, WATCH_ALONG])
    return p[0], p[2]


WATCH = watch_at()


def watch_point(local):
    """A point of the watch house's own frame in the world."""
    dx, dz = turn(WATCH_YAW, local[0], local[2])
    return [WATCH[0] + dx, SQUARE + local[1], WATCH[1] + dz]


def watch_rect():
    """The watch house's box round its turned footprint (x0, z0, x1, z1)."""
    corners = []

    for lx, lz in ((-10.0, 0.0), (10.0, 0.0), (10.0, -WATCH_DEPTH), (-10.0, -WATCH_DEPTH)):
        dx, dz = turn(WATCH_YAW, lx, lz)
        corners.append((WATCH[0] + dx, WATCH[1] + dz))

    return min(c[0] for c in corners), min(c[1] for c in corners), max(c[0] for c in corners), max(c[1] for c in corners)


# The rows (Pombaline, four storeys, DEPTH deep): on the square's south
# edge facing north onto the Largo, their backs over the lookout; on the
# high terrace under the upper town's cliff facing south onto its lane.
# (x0, x1, the fronts' z, yaw.)
DEPTH = 13.0
EAVES = 3.85 + 3.7 + 3.4 + 3.1
SOUTH_ROW = (-94.0, -62.0, -200.0, 180.0)
HIGH_ROW = (-97.0, 12.0, -277.0, 0.0)
# The convent's office (a two-storey whitewashed house, its azotea at the
# watch house's eaves) against the watch house's side toward the comet:
# the watch's roof way starts on it. (Along the watch house, out from it.)
OFFICE = (12.0, 10.0)
# A scaffold up a front (to its eaves), its width.
SCAFFOLD_WIDTH = 4.0


def width(bays):
    """A Pombaline front's width (kit_pombal.facade_width to the grid)."""
    return math.ceil((2.0 * 1.6 + (2 * bays - 1) * 1.35) / 0.5 - 1e-9) * 0.5


def _pack(rng, length):
    """Bays for a row `length` long (within 2 m short of it): a corner at
    each end (2 or 3 bays), middles of 3-6 between."""
    for _ in range(5000):
        ends = [rng.choice((2, 3)), rng.choice((2, 3))]
        mids, used = [], width(ends[0]) + width(ends[1])

        for _ in range(20):
            b = rng.choice((3, 3, 4, 4, 5, 6))

            if used + width(b) <= length:
                mids.append(b)
                used += width(b)

            if length - used < 2.0 and mids:
                return [ends[0]] + mids + [ends[1]]

    raise ValueError("no row fits %.1f m" % length)


def _row(rng, look, name, row):
    """A row's lots, along x from its west end: corners at its ends, fire
    walls every few between its middles."""
    from town import baixa
    x0, x1, zf, yaw = row
    bays = _pack(rng, x1 - x0)
    kinds = ["corner"] + ["mid"] * (len(bays) - 2) + ["corner"]
    fire = baixa._fire_walls(rng, [{"kind": k, "quirk": ""} for k in kinds])
    fronts = baixa._fronts(look, len(bays))
    out, x = [], x0

    for i, b in enumerate(bays):
        w = width(b)
        walls = (fire.get(i) == 0, fire.get(i) == 1)
        bare = (fire.get(i - 1) == 1, fire.get(i + 1) == 0)

        # (Facing north, a house's own +x runs west: its sides swap.)
        if yaw == 180.0:
            walls, bare = walls[::-1], bare[::-1]

        params = [("bays", b), ("kind", kinds[i]), ("front", fronts[i]), ("seed", rng.randrange(1000))]

        if any(walls):
            params.append(("fire_walls", walls))

        if any(bare):
            params.append(("bare", bare))

        out.append(Lot("%s_%d" % (name, i + 1), "pombal", x + w / 2.0, zf, SQUARE if zf > HIGH_Z else HIGH, yaw, w, DEPTH, 4, "",
                       params=tuple(params)))
        x += w

    return out


def office():
    """The convent's office: against the watch house's own +x side, its
    front on the watch house's front's line, as deep as OFFICE out from it
    (a lot at the watch house's yaw)."""
    along, out = OFFICE
    fx, fz = turn(WATCH_YAW, 10.0 + out / 2.0, 0.0)
    return Lot("carmo_office", "patio", WATCH[0] + fx, WATCH[1] + fz, SQUARE, WATCH_YAW, out, along, 2, "", False, 0, False, "",
               (("kind", "small"), ("seed", 17)))


def _plan():
    rng = random.Random(1389)
    look = random.Random(1755)
    lots = _row(rng, look, "carmo_s", SOUTH_ROW) + _row(rng, look, "carmo_h", HIGH_ROW) + [office()]
    # About one building in five or six walked in (middles, their doors on
    # the street), a third of those lived in.
    mids = [i for i, each in enumerate(lots) if dict(each.params).get("kind") == "mid"]
    chosen = sorted(rng.sample(mids, max(1, int(round(len(lots) / 5.5)))))

    for k, i in enumerate(chosen):
        each = lots[i]
        lots[i] = Lot(each.name, each.family, each.x, each.z, each.y, each.yaw, each.width, each.depth, each.storeys, each.quirk, True,
                      rng.choice((1, 2, 2, 3)), k % 3 == 0, each.sector, each.params)

    return lots


LOTS = _plan()

# The ways up the steps. From the Rossio: two stair towers on its north
# edge (kit_terrace.stair_tower, their backs on the cliff: x of their
# middles), the thief's ledges (the x they arrive at). The lookout to the
# square (2 m): two stair-lanes STAIR_WIDTH wide (x), a thief's hang over
# its parapet (x). The square to the high terrace (12 m): two wall stairs
# along its face (x of their middles), ledges (the x they arrive at).
TOWERS = (-82.0, -38.0)
# Granite buttresses up the cliff (x), between the towers and the ledges:
# its 115 m face broken every dozen metres or so.
CLIFF_BUTTRESSES = (-93.0, -68.0, -56.0, -28.0, 4.0)
# (kit_terrace's measures: a stair's riser, a stair-lane's tread, flight and
# landing; a tower's flights' steps, breadth outside and top door off its
# middle; a ledge's length along its face and its rise over the last.)
RISER = 0.18
TREAD, FLIGHT, LANDING = 0.32, 12, 2.0
TOWER_STEPS, TOWER_BREADTH, TOWER_DOOR = 10, 3.7, 2.1
LEDGE_ALONG, LEDGE_RISE = 1.6, 2.0
BAIXA_LEDGES = -4.0
STAIR_WIDTH = 3.0
STEP1_STAIRS = (-50.0, 4.0)
STEP1_HANG = -40.0
WALL_STAIR = 2.0
WALL_RISER, WALL_TREAD, WALL_LANDING = 0.18, 0.28, 1.4
STEP2_STAIRS = (-80.0, -4.0)
STEP2_LEDGES = -32.0
# A gap in a parapet where a way comes up through it.
HEAD = 2.0
# The lookout's pergola (x0, x1, its depth out from the square's wall) and
# its benches along the parapet (x of each); its two lamp posts (x).
PERGOLA = (-27.0, -15.0, 3.0)
BENCHES = (-70.0, -62.0, -56.0, -24.0, -18.0, 6.0)
LAMP_POSTS = (-29.0, -13.0)
# The Largo's fountain (x, z) west of the church, the dolphin fountain
# under its canopy.
FOUNTAIN = (-84.0, -219.0)
LARGO = (-94.0, -240.0, -66.0, -201.0)
# The lanes the watch lights (z0, z1): the high terrace's, the square's
# north lane along the cliff under it.
LANES = ((-277.0, -265.0), (-265.0, -256.0))
# Where their corner lamps hang: (x, y, z, the way the wall faces).
LAMPS = [(-85.0, HIGH, HIGH_ROW[2], 0.0), (-55.0, HIGH, HIGH_ROW[2], 0.0), (-25.0, HIGH, HIGH_ROW[2], 0.0), (0.0, HIGH, HIGH_ROW[2], 0.0),
         (-60.0, SQUARE, HIGH_Z, 0.0), (-28.0, SQUARE, HIGH_Z, 0.0), (-84.0, SQUARE, SOUTH_ROW[2], 180.0), (-70.0, SQUARE, SOUTH_ROW[2], 180.0)]


def wall_run(rise):
    """A wall stair's run (its steps at WALL_TREAD, its landing)."""
    return int(math.ceil(rise / WALL_RISER - 1e-9)) * WALL_TREAD + WALL_LANDING


def ledge_reach(height):
    """How far along the face from a run of ledges' start (`height` up)
    a man arrives on its top (kit_terrace.ledges)."""
    count = int(math.ceil(height / LEDGE_RISE - 1e-9)) - 1
    return (count - 0.5) * LEDGE_ALONG


def tower_at(x):
    """A Rossio tower's middle (x, z) and its top door's x: its back on the
    cliff (yaw -90: its own -x to the world's -z, its own +z to -x; its top
    door TOWER_DOOR off its middle, which way by its flights' count)."""
    height = LOOK - BAIXA_G
    per = min(TOWER_STEPS, int(math.ceil(height / RISER - 1e-9)))
    flights = int(math.ceil(height / (per * RISER) - 1e-9))
    top = TOWER_DOOR if flights % 2 else -TOWER_DOOR
    return (x, CLIFF_Z + 0.1 + TOWER_BREADTH / 2.0), x - top


def stair_run(rise):
    """A stair-lane's run up `rise` (kit_terrace.stair_lane's: steps of at
    most RISER, flights of FLIGHT, landings between)."""
    steps = int(math.ceil(rise / RISER - 1e-9))
    flights = int(math.ceil(steps / float(FLIGHT))) if steps > FLIGHT else 1
    return steps * TREAD + (flights - 1) * LANDING


def _intervals(a, b, gaps):
    """[a, b] less the gaps (each (lo, hi)): the runs left."""
    out, x = [], a

    for lo, hi in sorted(gaps):
        if lo > x:
            out.append((x, min(lo, b)))

        x = max(x, hi)

    if x < b:
        out.append((x, b))

    return [(lo, hi) for lo, hi in out if hi - lo > 0.05]


def cliff_openings():
    """Where the lookout's parapet opens (x0, x1): each tower's top door,
    the ledges' arrival."""
    return [(tower_at(x)[1] - HEAD / 2.0, tower_at(x)[1] + HEAD / 2.0) for x in TOWERS] + [(BAIXA_LEDGES - HEAD / 2.0, BAIXA_LEDGES + HEAD / 2.0)]


def _walls():
    out = {k: [] for k in ("cliff", "buttresses", "step1", "step2", "parapet", "towers", "ledges", "stair1", "stair2")}
    rise = LOOK - BAIXA_G
    # The cliff over the Rossio, in three; its parapet but where the ways
    # come up.
    third = (EAST - WEST) / 3.0

    for i in range(3):
        a = WEST + i * third
        out["cliff"].append({"kind": "retaining", "args": (round(third, 3), rise), "at": (a + third / 2.0, BAIXA_G, CLIFF_Z), "yaw": 0.0})

    for a, b in _intervals(WEST, EAST, cliff_openings()):
        out["parapet"].append({"kind": "parapet", "args": (round(b - a, 3),), "at": ((a + b) / 2.0, LOOK, CLIFF_Z), "yaw": 0.0})

    for x in CLIFF_BUTTRESSES:
        out["buttresses"].append({"kind": "buttress", "args": (rise,), "at": (x, BAIXA_G, CLIFF_Z), "yaw": 0.0})

    for x in TOWERS:
        (tx, tz), _door = tower_at(x)
        out["towers"].append({"kind": "stair_tower", "args": (rise,), "at": (tx, BAIXA_G, tz), "yaw": -90.0})

    start = BAIXA_LEDGES - ledge_reach(rise)
    out["ledges"].append({"kind": "ledges", "args": (rise,), "at": (start, BAIXA_G, CLIFF_Z), "yaw": 0.0, "step": "carmo_step_baixa"})

    # The lookout to the square: its wall cut for its stair-lanes, their
    # runs out on the lookout; a parapet on the square's edge but at their
    # heads.
    low = SQUARE - LOOK
    cuts = [(c - STAIR_WIDTH / 2.0, c + STAIR_WIDTH / 2.0) for c in STEP1_STAIRS]

    for a, b in _intervals(WEST, EAST, cuts):
        out["step1"].append({"kind": "retaining", "args": (round(b - a, 3), low), "at": ((a + b) / 2.0, LOOK, STEP_Z), "yaw": 0.0})

    steps = int(math.ceil(low / RISER - 1e-9))

    for c in STEP1_STAIRS:
        out["stair1"].append({"kind": "stair_lane", "args": (STAIR_WIDTH, steps, low / steps), "at": (c, LOOK, STEP_Z + stair_run(low)), "yaw": 180.0})

    for a, b in _intervals(WEST, EAST, cuts):
        out["parapet"].append({"kind": "parapet", "args": (round(b - a, 3),), "at": ((a + b) / 2.0, SQUARE, STEP_Z), "yaw": 0.0})

    # The square to the high terrace: its wall, its coping flush where a
    # wall stair climbs along it; a parapet on the high terrace's edge but
    # at the stairs' landings and the ledges' arrival.
    high = HIGH - SQUARE
    run = round(wall_run(high), 3)
    flush = [(c - run / 2.0, c + run / 2.0) for c in STEP2_STAIRS]

    for a, b in _intervals(WEST, EAST, flush):
        out["step2"].append({"kind": "retaining", "args": (round(b - a, 3), high), "at": ((a + b) / 2.0, SQUARE, HIGH_Z), "yaw": 0.0})

    for a, b in flush:
        out["step2"].append({"kind": "retaining", "args": (round(b - a, 3), high, False, "rubble_warm", True), "at": ((a + b) / 2.0, SQUARE, HIGH_Z),
                             "yaw": 0.0})

    for c in STEP2_STAIRS:
        out["stair2"].append({"kind": "wall_steps", "args": (high, run, WALL_STAIR), "at": (c - run / 2.0, SQUARE, HIGH_Z + WALL_STAIR / 2.0),
                              "yaw": 90.0, "c": c})

    start = STEP2_LEDGES - ledge_reach(high)
    out["ledges"].append({"kind": "ledges", "args": (high,), "at": (start, SQUARE, HIGH_Z), "yaw": 0.0, "step": "carmo_step_2"})
    heads = [(c + run / 2.0 - WALL_LANDING, c + run / 2.0) for c in STEP2_STAIRS] + [(STEP2_LEDGES - HEAD / 2.0, STEP2_LEDGES + HEAD / 2.0)]

    for a, b in _intervals(WEST, EAST, heads):
        out["parapet"].append({"kind": "parapet", "args": (round(b - a, 3),), "at": ((a + b) / 2.0, HIGH, HIGH_Z), "yaw": 0.0})

    return out


WALLS = _walls()
TERRACE = sorted({(w["kind"], w["args"]) for walls in WALLS.values() for w in walls}) + [("scaffold", (EAVES, SCAFFOLD_WIDTH)),
                                                                                       ("drainpipe", (8.6,))]
