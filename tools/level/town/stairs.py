"""The old town's stairs quarter (its spec, section 4.3; old_town_porto.md
section 1, Barredo): terraces up the west side of the rock. Each terrace has
a lane along its south edge and one row of deep Porto houses facing it,
their backs on the next terrace's retaining wall, so their upper storeys
line the lane above. Two stair-lanes climb each step between the houses
(zig-zagging up the quarter), and a two-level house straddles it, its front
door on the lane below, its back door on the lane above. Light plots (walled
yards) open the rows; the city wall stands on a footing where its foot
steps up over the terraces, the old rampart runs on along the gorge's rim
past it. Laid by layouts/old_town/stairs.py (plan B1a, Task 15).

    PLATES      the quarter's terraces, south to north (from town.TERRACES)
    STEPS       each step between two terraces: its line z, foot y, rise,
                its two stair-lanes' x
    ROWS        each terrace's row: lots and light plots, west to east (on
                the third terrace and round the tavern, the blocks laid by
                hand: what stands against the step behind them)
    LOTS        its houses
    SQUARE      the fountain square where seven lanes meet (third terrace)
    STREAM      the vaulted stream's pieces, its outfall to its head
    TAVERN, TOWER, LEDGES, TANNERY, ALLEY, BASTION   the places laid by
                hand
    WALLS       its walls and the pieces laid with them, (piece args, at,
                yaw)
    TERRACE     every piece the kit builds for it

Godot's axes: north is -z; a lot's front faces south (yaw 0) onto its lane.
"""

import math
import random

from town import Lot, TERRACES

# The quarter's west, its east (the cliffs over the Baixa and the Carmo; at
# the bottom two terraces wall C's inner face, the harbour's), the Ribeira
# wall's inner face (the bottom terrace's south).
WEST = -178.0
EAST = -100.0
WALL_C = -100.4
RIBEIRA = -22.4
LANE = 3.0
GAP = 2.5
RISER = 0.18
FRONTS = ("render_ochre", "render_salmon", "render_straw", "render_blue", "render_pink", "render_green", "render_white", "azulejo_green",
          "azulejo_blue", "azulejo_cube", "limewash", "plaster_ochre")
QUIRKS = ("", "", "", "jetty", "mirante", "dormer", "privy_tower", "corner_shrine")

PLATES = sorted([t for t in TERRACES if t[1] == "stairs"], key=lambda t: -t[5])

# The city wall west of the quarter (the harbour lays it: from the Ribeira's
# corner north in 6 m runs, a 3 m run to finish, each at the Guindais
# stair's grade less 0.5): (z of its middle, its length, its foot's y).
WALL_X = -179.2
WALL_THICK = 2.4


def _wall_pieces():
    out, z = [], RIBEIRA

    while z > -120.0 + 0.5:
        length = 6.0 if z - 5.5 >= -120.0 else 3.0
        mid = z - length / 2.0
        out.append((mid, length, 2.5 + (-8.0 - mid) / 3.0 - 0.5))
        z -= length

    return out


WALL_PIECES = _wall_pieces()
WALL_END = WALL_PIECES[-1][0] - WALL_PIECES[-1][1] / 2.0


def south(plate):
    return RIBEIRA if plate[0] == "stairs_1" else plate[5]


def north(plate):
    return plate[3]


def level(plate):
    return plate[6]


def east(plate):
    """Its east edge: the cliff's top over the Baixa and the Carmo (beside
    the bottom two terraces, the top of wall C's walk's inner side)."""
    return EAST


# Each step up the quarter (between PLATES[k] and PLATES[k + 1]): its two
# stair-lanes' middles, zig-zagging so no lane runs straight up two steps.
GAPS = [(-168.0, -118.0), (-170.0, -121.0), (-146.0, -131.0), (-163.0, -112.0), (-152.0, -122.0), (-170.0, -128.0), (-148.0, -115.0),
        (-165.0, -131.0), (-150.0, -118.0)]


def _steps():
    out = []

    for k in range(len(PLATES) - 1):
        low, high = PLATES[k], PLATES[k + 1]
        rise = level(high) - level(low)
        steps = int(math.ceil(rise / RISER - 1e-9))
        out.append({"z": north(low), "y": level(low), "rise": rise, "steps": steps, "riser": rise / steps, "gaps": GAPS[k]})

    return out


STEPS = _steps()

# The west wall's stair (the spec's way 4, the harbour's west wall-walk,
# reached from the first lane): its width along the wall's inner face.
WALL_STAIR_WIDTH = 1.5
WALL_HEIGHT = 12.0

# What each terrace's row keeps for the places laid by hand: (x0, x1,
# kind). The whole of stairs_3 is its square's and its blocks'.
RESERVED = {
    "stairs_1": [(WEST, WEST + WALL_STAIR_WIDTH, "wall_stair")],
    "stairs_2": [(-158.0, -133.0, "tavern")],
    "stairs_3": [(WEST, EAST, "square")],
    "stairs_4": [(WEST, -175.5, "alley")],
    "stairs_5": [(-108.0, EAST, "tower")],
    "stairs_7": [(-108.0, EAST, "tower")],
    "stairs_9": [(-108.0, EAST, "tower")],
}

# The fountain square on the third terrace (old_town_porto.md section 1,
# the Barredo's largos; the spec's "a fountain square where seven lanes
# meet"): x0, z0, x1, z1. Its lanes: west the Guindais lane from the
# postern, east the lane to the miradouro over the Baixa (both CROSS), south
# two lanes to the terrace's lane (aligned with the stairs north), north the
# two stair-lanes up either side of the bastion and the passage beside the
# first to the tannery's alley.
SQUARE = (-150.0, -100.0, -129.75, -83.0)
CROSS = (-92.5, -89.5)
SOUTH_LANES = ((-150.0, -147.5), (-132.25, -129.75))
PASSAGE = (-150.0, -147.25)
TANNERY_ALLEY = (-110.0, -107.5)
# The bastion between the north stair-lanes: the fourth terrace carried
# forward over the square on retaining walls, the fountain in its face.
BASTION = (-144.75, -110.0, -132.25, -100.0)
# The tannery's yard (x0, z0, x1, z1): the terrace's north-west corner.
TANNERY = (WEST, -110.0, -163.0, CROSS[0])
# The miradouro over the Baixa at the east lane's end: x0, z0, x1, z1.
MIRADOURO = (-108.0, -97.0, EAST, -85.0)
# The blocks round the square, laid by hand: (name, x0, x1, front z, yaw,
# depth); the first lot of "ne" the step's two-level house, the last of
# "sw" the slot house.
BLOCKS = [
    ("sw", WEST, SQUARE[0], CROSS[1], 180.0, 16.5),
    ("ms", SOUTH_LANES[0][1], SOUTH_LANES[1][0], SQUARE[3], 180.0, 10.0),
    ("se", SQUARE[2], MIRADOURO[0], CROSS[1], 180.0, 16.5),
    ("ms_east", MIRADOURO[0], EAST, MIRADOURO[3], 180.0, 12.0),
    ("ne", SQUARE[2], MIRADOURO[0], CROSS[0], 0.0, 17.5),
    ("mn_east", MIRADOURO[0], EAST, MIRADOURO[1], 0.0, 13.0),
    ("nw", TANNERY[2], SQUARE[0], CROSS[0], 0.0, 15.0),
]
SLOT_WIDTH = 1.5

# The tavern (kit_tavern) on the second terrace, its front to the east on a
# little largo, its yard behind it on a back lane, a side alley past it to
# the north (its way in by the window), the stream under its yard; houses
# along the side alley, their backs on the third terrace's wall. Set back 2
# m from the terrace's lane so its house stands on whole ground cells: the
# ground is cut under it (its cellar's stair comes up through its floor).
TAVERN = (-136.25, -53.75, 90.0)
TAVERN_SIZE = (14.0, 7.5)
TAVERN_BLOCK = ("tavern_n", -158.0, -133.0, -59.5, 0.0, 10.5)

# The bricked-up alley along the old wall on the fourth terrace (x0, z0,
# x1, z1): its mouth on the terrace's lane walled up in brick.
ALLEY = (WEST, -135.0, -175.5, -113.0)
BRICKED = 3.4
# The rows' depth at most (the north terrace's houses leave gardens behind).
DEPTH = 22.0


def _intervals(x0, x1, cuts):
    """[x0, x1] less the cuts [(a, b)], in order."""
    out, at = [], x0

    for a, b in sorted(cuts):
        if a > at + 1e-6:
            out.append((at, min(a, x1)))

        at = max(at, b)

    if at < x1 - 1e-6:
        out.append((at, x1))

    return out


def _fill(rng, a, b):
    """Widths of houses ("house", w) and light plots ("yard", w) filling
    [a, b] exactly: houses 4.5 to 7.5, a yard now and then."""
    out, left, since = [], b - a, 0

    while left > 0.01:
        if left < 4.5:
            # (Too narrow for a house: the last house wider; a light plot only
            # when nothing else fits. A row never ends in a yard: its open
            # side would have no wall.)
            if out and out[-1][0] == "house":
                out[-1] = ("house", out[-1][1] + left)
            else:
                out.append(("yard", left))

            break

        if since >= 3 and rng.random() < 0.45 and left >= 4.5 + 3.0:
            w = rng.choice((3.0, 4.0, 5.0))
            out.append(("yard", w))
            since = 0
        else:
            w = min(rng.choice((4.5, 6.0, 6.0, 7.5)), left)

            if 0.01 < left - w < 4.5 and left <= 9.0:
                w = left

            out.append(("house", w))
            since += 1

        left -= w

    return out


def _plan():
    rng = random.Random(1384)
    look = random.Random(1415)
    lots, rows = [], {}

    for k, plate in enumerate(PLATES):
        name = plate[0]
        reserved = list(RESERVED.get(name, []))

        if any(kind == "square" for _a, _b, kind in reserved):
            rows[name] = []
            continue

        front, back = south(plate) - LANE, max(north(plate), south(plate) - LANE - DEPTH)
        cuts = [(a, b) for a, b, _kind in reserved]
        fixed = []

        if k < len(STEPS):
            step = STEPS[k]
            cuts += [(c - GAP / 2.0, c + GAP / 2.0) for c in step["gaps"]]
            # (The two-level house up the step, east of its first stair.)
            x = step["gaps"][0] + GAP / 2.0
            fixed.append((x, x + 6.0, "two_level"))
            cuts.append((x, x + 6.0))

        items = []

        for a, b in _intervals(WEST, east(plate), cuts):
            at = a

            for kind, w in _fill(rng, a, b):
                items.append((at, at + w, kind))
                at += w

        items = sorted(items + fixed)
        row, last = [], None

        for i, (a, b, kind) in enumerate(items):
            if kind == "yard":
                row.append({"kind": "yard", "x0": a, "x1": b})
                continue

            width = b - a
            avoid = {last} if last else set()
            cladding = look.choice([f for f in FRONTS if f not in avoid])
            last = cladding
            params = [("front", cladding), ("seed", rng.randrange(1000))]
            storeys, quirk, enterable, rooms = rng.choice((3, 4, 4, 5)), rng.choice(QUIRKS), False, 0

            # (A privy tower hangs over ground behind the house: never into
            # the step's wall it stands against.)
            if quirk == "privy_tower" and abs(back - north(plate)) < 0.01:
                quirk = ""

            if kind == "two_level":
                step = STEPS[k]
                back_storey = 1 if step["rise"] < 3.8 + 2.5 else 2
                params += [("shop", round(step["rise"] - (back_storey - 1) * 3.2, 3)), ("back_storey", back_storey)]
                quirk, enterable, rooms, storeys = "two_level", True, back_storey + 1, max(storeys, back_storey + 2)
            elif quirk == "corner_shrine" and width < 6.0:
                quirk = ""

            lot = Lot("%s_%d" % (name, i + 1), "porto", (a + b) / 2.0, front, level(plate), 0.0, width, front - back, storeys, quirk, enterable,
                      rooms, False, "", tuple(params))
            lots.append(lot)
            row.append({"kind": "house", "x0": a, "x1": b, "lot": lot.name})

        rows[name] = row

    lots += _hand_lots(rows)
    lots = _corners(lots)

    # About one ordinary house in five or six walked in, a third lived in.
    plain = [i for i, each in enumerate(lots) if not each.enterable]
    chosen = sorted(rng.sample(plain, int(round(len(lots) / 6.0))))

    for n, i in enumerate(chosen):
        each = lots[i]
        lots[i] = Lot(each.name, each.family, each.x, each.z, each.y, each.yaw, each.width, each.depth, each.storeys, each.quirk, True,
                      rng.choice((1, 2, 2, 3)), n % 3 == 0, each.sector, each.params)

    return lots, rows


def _widths(rng, length):
    """Houses' widths filling `length` exactly: 4.5 to 7.5, what is left
    over given to the last."""
    out, left = [], length

    while left > 0.01:
        w = min(rng.choice((4.5, 6.0, 6.0, 7.5)), left)

        # (What would be left too narrow for a house: all of it if a house
        # takes it, else this one narrower.)
        if left - w < 4.5:
            w = left if left <= 9.0 else left - 4.5

        out.append(w)
        left -= w

    return out


def _hand_lots(rows):
    """The lots of the blocks laid by hand: round the square on the third
    terrace (its two-level house, its slot house) and along the tavern's
    side alley; each block's houses in rows[...] where they stand against
    the step behind them."""
    rng, look = random.Random(1386), random.Random(1417)
    plate3 = [p for p in PLATES if p[0] == "stairs_3"][0]
    plate2 = [p for p in PLATES if p[0] == "stairs_2"][0]
    k3 = PLATES.index(plate3)
    lots = []

    for block in BLOCKS + [TAVERN_BLOCK]:
        name, x0, x1, front, yaw, depth = block
        plate = plate2 if block is TAVERN_BLOCK else plate3
        widths = []

        if name == "ne":
            widths.append(6.0)

        if name == "sw":
            widths = _widths(rng, x1 - x0 - SLOT_WIDTH) + [SLOT_WIDTH]
        else:
            widths += _widths(rng, x1 - x0 - sum(widths))

        at, last = x0, None

        for i, width in enumerate(widths):
            avoid = {last} if last else set()
            cladding = look.choice([f for f in FRONTS if f not in avoid])
            last = cladding
            params = [("front", cladding), ("seed", rng.randrange(1000))]
            storeys, quirk, enterable, rooms = rng.choice((3, 4, 4, 5)), rng.choice(QUIRKS), False, 0

            if name == "ne" and i == 0:
                step = STEPS[k3]
                back_storey = 1 if step["rise"] < 3.8 + 2.5 else 2
                params += [("shop", round(step["rise"] - (back_storey - 1) * 3.2, 3)), ("back_storey", back_storey)]
                quirk, enterable, rooms, storeys = "two_level", True, back_storey + 1, max(storeys, back_storey + 2)
            elif name == "sw" and i == len(widths) - 1:
                quirk, enterable, rooms = "slot", True, 1
            elif quirk == "corner_shrine" and width < 6.0:
                quirk = ""
            elif quirk == "privy_tower" and name != "nw":
                # (Only the north-west block's backs are on open ground: the
                # tannery's alley; the rest stand on a lane or a step's wall.)
                quirk = ""

            lot = Lot("stairs_%s_%d" % (name, i + 1), "porto", at + width / 2.0, front, level(plate), yaw, width, depth, storeys, quirk,
                      enterable, rooms, False, "", tuple(params))
            lots.append(lot)
            back = front - depth if yaw == 0.0 else front + depth

            # (What stands against the step behind it: a house whose back is
            # on the terrace's north edge.)
            if abs(back - north(plate)) < 0.01:
                rows[plate[0]].append({"kind": "house", "x0": at, "x1": at + width, "lot": lot.name})

            at += width

    rows["stairs_3"].append({"kind": "block", "x0": BASTION[0], "x1": BASTION[2]})

    for name in ("stairs_2", "stairs_3"):
        rows[name].sort(key=lambda item: item["x0"])

    return lots


def lot_rect(lot):
    """A lot's footprint (x0, z0, x1, z1): its front at z, deep behind it."""
    if abs(lot.yaw - 180.0) < 0.01:
        return (lot.x - lot.width / 2.0, lot.z, lot.x + lot.width / 2.0, lot.z + lot.depth)

    return (lot.x - lot.width / 2.0, lot.z - lot.depth, lot.x + lot.width / 2.0, lot.z)


def _corners(lots):
    """Each lot with a side that stands open (no lot of its terrace within
    CORNER_REACH of it over CORNER_COVER of its depth, not the city wall)
    made a corner house on that side (no jetty: its side wall would not
    close one)."""
    out = []

    for lot in lots:
        r = lot_rect(lot)
        depth = r[3] - r[1]
        letters = ""

        for side, edge, beyond in (("w", r[0], (r[0] - CORNER_REACH, r[0])), ("e", r[2], (r[2], r[2] + CORNER_REACH))):
            # (Against the city wall, closed; past its end, over the old
            # rampart, open to the gorge.)
            if side == "w" and edge <= WEST + 0.01 and (r[1] + r[3]) / 2.0 > WALL_END:
                continue

            covered = 0.0

            for other in lots:
                o = lot_rect(other)

                if other is lot or abs(other.y - lot.y) > 0.01 or o[2] <= beyond[0] + 0.01 or o[0] >= beyond[1] - 0.01:
                    continue

                covered += max(0.0, min(o[3], r[3]) - max(o[1], r[1]))

            if covered < CORNER_COVER * depth:
                # (A house facing north has its east side to -x.)
                letters += side if abs(lot.yaw) < 0.01 else {"w": "e", "e": "w"}[side]

        if letters:
            quirk = "" if lot.quirk == "jetty" else lot.quirk
            lot = Lot(lot.name, lot.family, lot.x, lot.z, lot.y, lot.yaw, lot.width, lot.depth, lot.storeys, quirk, lot.enterable, lot.rooms,
                      lot.lived, lot.sector, lot.params + (("corner", "".join(sorted(letters, reverse=True))),))

        out.append(lot)

    return out


# A side stands open with no lot within this of it over this much of its
# depth (a stair-lane or a narrow light plot is closed).
CORNER_REACH = 3.5
CORNER_COVER = 0.9


LOTS, ROWS = _plan()


# The vaulted stream (old_town_porto.md section 1, the Rio da Vila; the
# spec's "the stream vaulted over with houses on it, the thief's sewer"):
# from a grating in the Ribeira wall north under the bottom three
# terraces, STREAM_DEPTH under each, stepping up each terrace in a cascade
# just behind its retaining wall; past the tavern's cellar door; up a
# hatch into the Guindais lane at its head.
STREAM_X = -151.95
STREAM_SIZE = (3.0, 2.4)
STREAM_LEDGE = 1.2
STREAM_DEPTH = 3.0
STREAM_DOOR = 1.4
STREAM_DOOR_LENGTH = 3.0
STREAM_CHAMBER = 2.0
CASCADE = 3.2
# Its hatch: a ground cell's middle in the Guindais lane, over the
# chamber's +x side (SHAFT / 2 in from its wall).
HATCH = (-151.25, -91.25)
CELL = 2.5


def _tavern_holes():
    """The ground's cells wholly under the tavern's house (its cellar under
    them), by their middles."""
    x, z, _yaw = TAVERN
    depth, width = TAVERN_SIZE
    plate = PLATES[1]
    out = []

    for i in range(int(round((plate[4] - plate[2]) / CELL))):
        for j in range(int(round((plate[5] - plate[3]) / CELL))):
            cx, cz = plate[2] + (i + 0.5) * CELL, plate[3] + (j + 0.5) * CELL

            if x - depth - 1e-6 <= cx - CELL / 2.0 and cx + CELL / 2.0 <= x + 1e-6 and z - width / 2.0 - 1e-6 <= cz - CELL / 2.0 \
                    and cz + CELL / 2.0 <= z + width / 2.0 + 1e-6:
                out.append((cx, cz))

    return out


HOLES = [HATCH] + _tavern_holes()


def stream():
    """The stream's pieces from its outfall north: (kind, args, z of the
    piece's middle, its floor's y)."""
    w, h = STREAM_SIZE
    out = []
    plates = PLATES[:3]
    at = RIBEIRA

    def vault(z0, z1, y):
        if z0 - z1 > 0.01:
            out.append(("vault", (w, h, round(z0 - z1, 3), STREAM_LEDGE, "stream", "brick"), (z0 + z1) / 2.0, y))

    for k, plate in enumerate(plates):
        y = level(plate) - STREAM_DEPTH

        if plate[0] == "stairs_2":
            z = TAVERN[1]
            vault(at, z + STREAM_DOOR_LENGTH / 2.0, y)
            out.append(("vault", (w, h, STREAM_DOOR_LENGTH, STREAM_LEDGE, "stream", "brick", STREAM_DOOR), z, y))
            at = z - STREAM_DOOR_LENGTH / 2.0

        if k + 1 < len(plates):
            # (Its cascade just behind the next terrace's retaining wall.)
            middle = north(plate) - 0.9 - CASCADE / 2.0
            vault(at, middle + CASCADE / 2.0, y)
            drop = round(level(plates[k + 1]) - level(plate), 3)
            out.append(("cascade", (w, h, drop, STREAM_LEDGE, "brick", -1.0), middle, y))
            at = middle - CASCADE / 2.0
        else:
            z = HATCH[1]
            vault(at, z + STREAM_CHAMBER / 2.0, y)
            out.append(("hatch_chamber", (w, h, STREAM_CHAMBER, STREAM_LEDGE), z, y))
            at = z - STREAM_CHAMBER / 2.0

    return out


STREAM = stream()
STREAM_HEAD = STREAM[-1][2] - STREAM_CHAMBER / 2.0
HATCH_DEPTH = round(level(PLATES[2]) - (level(PLATES[2]) - STREAM_DEPTH + STREAM_SIZE[1] + 0.3), 3)

# The stair towers up the cliffs east of the quarter (kit_terrace's
# stair_tower: its back against the cliff, its foot door on the street
# below, its top door on the terrace): two to the Baixa (from the miradouro
# at the third terrace's east lane, from the fifth's lane's end), two to the
# Carmo's square (from the seventh's and the ninth's ends). Each (its
# terrace, its top door's z, the ground under it, its quarter). Ivy up
# the cliff beside one of each, the thief's way where the towers are
# watched (the face beside them too short for a run of ledges): (its
# terrace, its middle's z, the ground under it, its quarter), IVY_WIDTH
# wide, up the cliff and its parapet (IVY_OVER), climbed over.
BAIXA_G = 2.5
CARMO_G = 28.0
TOWERS = [("stairs_3", (CROSS[0] + CROSS[1]) / 2.0, BAIXA_G, "baixa"), ("stairs_5", -136.5, BAIXA_G, "baixa"),
          ("stairs_7", -195.0, CARMO_G, "carmo"), ("stairs_9", -236.5, CARMO_G, "carmo")]
IVY_CLIMBS = [("stairs_3", -96.0, BAIXA_G, "baixa"), ("stairs_7", -199.5, CARMO_G, "carmo")]
IVY_WIDTH, IVY_OVER = 2.4, 1.0
# (kit_terrace's tower: its flights' most steps and their riser; its length
# and breadth outside; its doors 2.1 from its middle at its -z end, the top
# door at its +z end after an odd count of flights.)
TOWER_STEPS, TOWER_RISER, TOWER_LENGTH, TOWER_BREADTH, TOWER_DOOR = 10, 0.18, 6.6, 3.7, 2.1


def tower_at(plate, top_z, ground):
    """A tower's middle (x, z) and height for its terrace, top door's z and
    the ground under it."""
    height = round(level([p for p in PLATES if p[0] == plate][0]) - ground, 3)
    per = min(TOWER_STEPS, int(math.ceil(height / TOWER_RISER - 1e-9)))
    flights = int(math.ceil(height / (per * TOWER_RISER) - 1e-9))
    return EAST + 0.1 + TOWER_BREADTH / 2.0, top_z - (TOWER_DOOR if flights % 2 else -TOWER_DOOR), height


# The walls, each {"kind", "args", "at", "yaw"} (a kit_terrace piece).

def _neighbour(z):
    """The ground east of the quarter at z: the Baixa's or the Carmo's (the
    harbour's wall C's walk, 14.5, beside the bottom two terraces)."""
    import town
    y = town.height(EAST + 0.6, z)
    return 14.5 if y <= town.HOLE + 1.0 else y


# A stair-lane's tread, its landings, its longest flight (kit_terrace's: the
# plan is pure data, read while the kit is built).
TREAD, LANDING, FLIGHT = 0.32, 2.0, 12


def _stair_run(step):
    flights = int(math.ceil(step["steps"] / float(FLIGHT))) if step["steps"] > FLIGHT else 1
    return step["steps"] * TREAD + (flights - 1) * LANDING


def _walls():
    out = {"retaining": [], "parapet": [], "east": [], "footing": [], "rampart": [], "yard": [], "stair": []}

    for k, step in enumerate(STEPS):
        low, high = PLATES[k], PLATES[k + 1]
        x1 = east(low)
        gaps = [(c - GAP / 2.0, c + GAP / 2.0) for c in step["gaps"]]

        for a, b in _intervals(WEST, x1, gaps):
            out["retaining"].append({"kind": "retaining", "args": (round(b - a, 3), round(step["rise"], 3)),
                                     "at": ((a + b) / 2.0, step["y"], step["z"]), "yaw": 0.0})

        for c in step["gaps"]:
            out["stair"].append({"kind": "stair_lane", "args": (GAP, step["steps"], step["riser"]),
                                 "at": (c, step["y"], step["z"] + _stair_run(step)), "yaw": 180.0, "step": k})

        # (A parapet along the step's top where no house of the row under it
        # stands against the wall: over its light plots and kept ground.)
        houses = [(i["x0"], i["x1"]) for i in ROWS[low[0]] if i["kind"] in ("house", "block", "stair")]

        for a, b in _intervals(WEST, x1, houses + gaps):
            if b - a > 0.3:
                out["parapet"].append({"kind": "parapet", "args": (round(b - a, 3),), "at": ((a + b) / 2.0, level(high), step["z"]), "yaw": 0.0})

    for plate in PLATES:
        y = level(plate)
        z0, z1 = north(plate), south(plate)
        x = east(plate)
        # (The cliff to the east, split where the ground under it changes.)
        cuts = sorted({z0, z1} | {c for c in (-170.0, -185.0, -265.0, -72.5) if z0 < c < z1})

        for a, b in zip(cuts, cuts[1:]):
            below = _neighbour((a + b) / 2.0)

            if y - below > 0.3:
                out["east"].append({"kind": "retaining", "args": (round(b - a, 3), round(y - below, 3)), "at": (x, below, (a + b) / 2.0),
                                    "yaw": 90.0})

        # (Its parapet along the edge wherever no house stands on it: the
        # lane's end, the gardens behind the houses, a light plot, the ground
        # kept by hand; the stair tower's head standing on it.)
        row = ROWS[plate[0]]
        covered = []

        for each in LOTS:
            r = lot_rect(each)

            if abs(each.y - y) < 0.01 and r[2] >= x - 0.01 and z0 - 0.01 <= r[1] and r[3] <= z1 + 0.01:
                covered.append((r[1], r[3]))

        for name, top_z, ground, _quarter in TOWERS:
            if name == plate[0]:
                _x, z, _h = tower_at(name, top_z, ground)
                covered.append((z - TOWER_LENGTH / 2.0, z + TOWER_LENGTH / 2.0))

        if y - _neighbour((z0 + z1) / 2.0) > 1.0:
            for a, b in _intervals(z0, z1, covered):
                if b - a > 0.3:
                    out["parapet"].append({"kind": "parapet", "args": (round(b - a, 3),), "at": (x, y, (a + b) / 2.0), "yaw": 90.0})

        for item in row:
            if item["kind"] == "yard":
                out["yard"].append({"kind": "yard_front", "args": (round(item["x1"] - item["x0"], 3),),
                                    "at": ((item["x0"] + item["x1"]) / 2.0, y, south(plate) - LANE), "yaw": 0.0})

        # (The old rampart along the gorge's rim, past the city wall's end.)
        if z0 < WALL_END:
            a, b = z0, min(z1, WALL_END)
            out["rampart"].append({"kind": "rampart", "args": (round(b - a, 3), 4.0, 8.0), "at": (WEST - 2.0, y, (a + b) / 2.0), "yaw": -90.0})

    for mid, length, base in WALL_PIECES:
        under = [level(p) for p in PLATES if north(p) < mid + length / 2.0 and mid - length / 2.0 < p[5]]
        y = min(under) if under else None

        if y is not None and base - y > 0.05:
            # (The Guindais gate: a postern into the footing on its lane.)
            if mid - length / 2.0 < (CROSS[0] + CROSS[1]) / 2.0 < mid + length / 2.0:
                out["footing"].append({"kind": "postern", "args": (round(base - y, 3), WALL_THICK, length), "at": (WALL_X, y, mid), "yaw": 90.0})
            else:
                out["footing"].append({"kind": "footing", "args": (length, round(base - y, 3), WALL_THICK), "at": (WALL_X, y, mid), "yaw": 90.0})

    out.update(_places())
    return out


def walk_at(z):
    """The city wall's walk's height at z (its pieces' tops)."""
    return [base + WALL_HEIGHT for mid, length, base in WALL_PIECES if mid - length / 2.0 - 0.01 <= z <= mid + length / 2.0 + 0.01][0]


def _places():
    """The walls and pieces of the places laid by hand."""
    out = {"bastion": [], "tannery": [], "alley": [], "climbs": [], "stream": []}
    plate1, plate3, plate4 = PLATES[0], PLATES[2], PLATES[3]
    y3, y4 = level(plate3), level(plate4)
    rise = round(y4 - y3, 3)
    x0, z0, x1, z1 = BASTION
    t = 0.8
    pt = 0.3
    # (Its retaining walls, the fill between them paved, a parapet round its
    # three open sides, the side ones ending at the front one's back.)
    out["bastion"] += [{"kind": "retaining", "args": (round(x1 - x0, 3), rise, False, "granite_rough"), "at": ((x0 + x1) / 2.0, y3, z1), "yaw": 0.0},
                       {"kind": "retaining", "args": (round(z1 - t - z0, 3), rise), "at": (x0, y3, (z0 + z1 - t) / 2.0), "yaw": -90.0},
                       {"kind": "retaining", "args": (round(z1 - t - z0, 3), rise), "at": (x1, y3, (z0 + z1 - t) / 2.0), "yaw": 90.0},
                       {"kind": "fill", "args": (round(x1 - x0 - 2.0 * t, 3), round(z1 - t - z0, 3), rise),
                        "at": ((x0 + x1) / 2.0, y3, (z0 + z1 - t) / 2.0), "yaw": 0.0},
                       {"kind": "parapet", "args": (round(x1 - x0, 3),), "at": ((x0 + x1) / 2.0, y4, z1), "yaw": 0.0},
                       {"kind": "parapet", "args": (round(z1 - pt - z0, 3),), "at": (x0, y4, (z0 + z1 - pt) / 2.0), "yaw": -90.0},
                       {"kind": "parapet", "args": (round(z1 - pt - z0, 3),), "at": (x1, y4, (z0 + z1 - pt) / 2.0), "yaw": 90.0}]
    tx0, tz0, tx1, tz1 = TANNERY
    out["tannery"] += [{"kind": "yard_front", "args": (round(tx1 - tx0, 3), True), "at": ((tx0 + tx1) / 2.0, y3, tz1), "yaw": 0.0},
                       {"kind": "yard_front", "args": (round(TANNERY_ALLEY[1] - TANNERY_ALLEY[0], 3), True),
                        "at": (tx1, y3, (TANNERY_ALLEY[0] + TANNERY_ALLEY[1]) / 2.0), "yaw": 90.0},
                       {"kind": "tannery", "args": (), "at": ((tx0 + tx1) / 2.0, y3, (tz0 + tz1) / 2.0), "yaw": 0.0}]
    ax0, az0, ax1, az1 = ALLEY
    out["alley"].append({"kind": "bricked", "args": (round(ax1 - ax0, 3), BRICKED), "at": ((ax0 + ax1) / 2.0, y4, az1), "yaw": 0.0})
    # (The west wall's stair: from the first lane north up the wall's inner
    # face to its walk at the step.)
    foot, head = south(plate1) - LANE, north(plate1)
    out["climbs"].append({"kind": "wall_steps", "args": (round(walk_at(head + 0.7) - level(plate1), 3), round(foot - head, 3), WALL_STAIR_WIDTH),
                          "at": (WEST + WALL_STAIR_WIDTH / 2.0, level(plate1), foot), "yaw": 180.0})
    out["towers"] = []

    for name, top_z, ground, _quarter in TOWERS:
        x, z, height = tower_at(name, top_z, ground)
        out["towers"].append({"kind": "stair_tower", "args": (height,), "at": (x, ground, z), "yaw": 0.0})

    out["ivy"] = []

    for name, z, ground, _quarter in IVY_CLIMBS:
        height = round(level([p for p in PLATES if p[0] == name][0]) - ground + IVY_OVER, 3)
        out["ivy"].append({"kind": "ivy", "args": (IVY_WIDTH, height), "at": (EAST, ground, z), "yaw": 90.0})

    for kind, args, z, y in STREAM:
        out["stream"].append({"kind": kind, "args": args, "at": (STREAM_X, y, z), "yaw": 0.0})

    w, h = STREAM_SIZE
    out["stream"] += [{"kind": "vault_end", "args": (w, h, True), "at": (STREAM_X, PLATES[0][6] - STREAM_DEPTH, RIBEIRA - 0.15), "yaw": 180.0},
                      {"kind": "vault_end", "args": (w, h, True), "at": (STREAM_X, y3 - STREAM_DEPTH, STREAM_HEAD - 0.15), "yaw": 0.0},
                      ]
    # (Turned so its grate leans aside along the lane's north edge.)
    out["hatch"] = [{"kind": "grate_hatch", "args": (HATCH_DEPTH, 2.5), "at": (HATCH[0], y3, HATCH[1]), "yaw": 0.0}]
    out["bridges"] = [{"kind": "bridge", "args": (GAP, BRIDGE_DEPTH), "at": (c, y, z), "yaw": 0.0} for _k, c, z, y in BRIDGES]
    out["scaffolds"] = [{"kind": "scaffold", "args": (eaves, SCAFFOLD_WIDTH), "at": (x, y, z), "yaw": 90.0, "corner": corner}
                        for x, y, z, eaves, corner in _chain_scaffolds()]
    return out


# The roof chains: up a builders' scaffold against the gable of a row's
# last house where it faces the open ground by the cliff, near its front's
# eaves (a gable is low there), then west along the row's roofs to the
# chain's end (laid by the layout). (terrace, the scaffold's z, the row's x
# where the chain ends.)
CHAINS = [("stairs_3", -87.25, -129.2), ("stairs_5", -140.0, -136.0)]
SCAFFOLD_WIDTH = 4.0
# (kit_porto's: a house's shop floor and upper storeys.)
PORTO_SHOP, PORTO_UPPER = 3.8, 3.2


def _chain_scaffolds():
    """Each chain's scaffold: (x, y, z, the corner house's eaves over its
    terrace, the corner lot's name)."""
    out = []

    for plate_name, sz, _end in CHAINS:
        plate = [p for p in PLATES if p[0] == plate_name][0]
        y = level(plate)
        x = MIRADOURO[0] if plate_name == "stairs_3" else [r for r in RESERVED[plate_name] if r[2] == "tower"][0][0]
        corner = [each for each in LOTS if abs(each.y - y) < 0.01 and lot_rect(each)[1] <= sz <= lot_rect(each)[3]
                  and abs(lot_rect(each)[2] - x) < 0.01][0]
        out.append((x, y, sz, round(PORTO_SHOP + (corner.storeys - 1) * PORTO_UPPER, 3), corner.name))

    return out


# Houses over the stair-lanes (the spec's "houses built over the stairs"):
# a room bridging an alley's mouth between the houses either side, a storey
# up, where both are houses of three storeys or more not walked in and the
# alley runs level far enough in from the lane before its stair. (step k,
# x, z of its middle, y of its foot.)
BRIDGE_DEPTH = 3.0
BRIDGE_STOREY = 3.8


def _bridges():
    named = {each.name: each for each in LOTS}
    out = []

    for k, step in enumerate(STEPS):
        plate = PLATES[k]
        row = ROWS[plate[0]]
        front = south(plate) - LANE
        foot = step["z"] + _stair_run(step)

        for c in sorted(step["gaps"], reverse=True):
            west = [i for i in row if i["kind"] == "house" and abs(i["x1"] - (c - GAP / 2.0)) < 0.01]
            east = [i for i in row if i["kind"] == "house" and abs(i["x0"] - (c + GAP / 2.0)) < 0.01]

            if not west or not east or front - foot < BRIDGE_DEPTH + 1.0:
                continue

            sides = [named[i["lot"]] for i in west + east]

            if any(each.enterable or each.storeys < 3 for each in sides):
                continue

            out.append((k, c, front - 0.6 - BRIDGE_DEPTH / 2.0, level(plate) + BRIDGE_STOREY))
            break

    return out


BRIDGES = _bridges()


WALLS = _walls()
TERRACE = [(w["kind"], w["args"]) for group in WALLS.values() for w in group]
