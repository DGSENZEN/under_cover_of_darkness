"""The old town's Baixa (its spec, section 4.3; old_town_lisbon.md section 4):
the low town rebuilt to a plan after the great fire. Three Pombaline blocks,
each two rows DEPTH deep back to back, a four-pitched corner building at
each of its corners, fire walls standing over the roofs every few
buildings; the main street on the Sea Gate's axis, 13.2 m between its
fronts, the secondary 8.8 east of it, the street under the stairs' cliff to
the west; the Sea Gate's square behind the gate, the Rossio at the main
street's head under the Carmo's wall. The rest is laid by
layouts/old_town/baixa.py (plan B1a, Task 14).

    BLOCKS      each block (x0, z0, x1, z1)
    ROWS        each block's long fronts: (block, face, its lots' names
                from left to right as they face the street)
    MAIN, EAST, WEST   the lanes, (x of the west front, x of the east)
    SEA_GATE_SQUARE, ROSSIO   the squares (x0, z0, x1, z1)
    SEWER       the sewer under the main street, its pieces along it
    HOLES       the ground's cells left out (their middles): the hatches'

Godot's axes: north is -z. A lot's x, z are its front's middle (town.Lot).
"""

import math
import random

from town import Lot

GROUND = 2.5
DEPTH = 13.0
MAIN = (-61.6, -48.4)
EAST = (-22.4, -13.6)
WEST = (-100.0, -87.6)
BLOCKS = {"baixa_w": (-87.6, -150.0, -61.6, -104.0), "baixa_e": (-48.4, -150.0, -22.4, -104.0), "baixa_f": (-13.6, -150.0, 12.4, -80.0)}
SEA_GATE_SQUARE = (-100.0, -104.0, -22.4, -74.4)
ROSSIO = (-100.0, -170.0, 15.0, -150.0)
FRONTS = ("azulejo_blue", "azulejo_green", "azulejo_cube", "render_ochre", "render_salmon", "render_straw", "limewash")
# A corner building's side runs this long down its block's front at least,
# and at most (its depth).
CORNER_SIDE = (8.0, 13.0)

# The sewer (2.2 x 3.1, its floor at FLOOR) under the main street, from
# behind the Sea Gate's square to the Rossio; a hatch down to it at each end
# (in the middle of one of the ground's cells: the ground leaves that cell
# out, the hatch's collar paves it flush), a chamber under each; the sewer
# runs half a shaft off the hatches, its +x wall under their ladders.
SEWER_SIZE = (2.2, 3.1)
SEWER_X = -54.25
SEWER_FLOOR = -1.2
SEWER_Z = (-95.0, -152.0)
HATCHES = [(-53.75, -106.25), (-53.75, -146.25)]
CHAMBER = 2.0
HOLES = list(HATCHES)
# The chamber's roof's top (the vault's height and its 0.3 m slab): where
# a hatch's shaft comes down to.
CHAMBER_TOP = SEWER_FLOOR + SEWER_SIZE[1] + 0.3
HATCH_DEPTH = round(GROUND - CHAMBER_TOP, 3)
COLLAR = 2.5
# A scaffold up a front (to its eaves), its width.
EAVES = 4.0 + 3.7 + 3.4 + 3.1
SCAFFOLD_WIDTH = 4.0


def width(bays):
    """A Pombaline front's width (kit_pombal.facade_width to the grid)."""
    return math.ceil((2.0 * 1.6 + (2 * bays - 1) * 1.35) / 0.5 - 1e-9) * 0.5


def sewer():
    """The sewer's pieces south to north: (kind, args, z of its middle)."""
    out = []
    z = SEWER_Z[0]

    for hz in sorted((h[1] for h in HATCHES), reverse=True) + [None]:
        stop = SEWER_Z[1] if hz is None else hz + CHAMBER / 2.0
        out.append(("vault", (SEWER_SIZE[0], SEWER_SIZE[1], round(z - stop, 3)), (z + stop) / 2.0))

        if hz is not None:
            out.append(("hatch_chamber", (SEWER_SIZE[0], SEWER_SIZE[1], CHAMBER), hz))
            z = hz - CHAMBER / 2.0

    return out


def _pack(rng, length, end):
    """The bays of a row's middle buildings down a front `length` long, a
    corner `end` wide at one end, a corner's side (CORNER_SIDE) at the
    other: (bays, that side's length)."""
    for _ in range(2000):
        bays, used = [], end

        while True:
            b = rng.choice((3, 3, 4, 4, 5, 6))

            if used + width(b) > length - CORNER_SIDE[0]:
                break

            bays.append(b)
            used += width(b)

        rest = length - used

        if len(bays) >= 2 and CORNER_SIDE[0] <= rest <= CORNER_SIDE[1]:
            return bays, rest

    raise ValueError("no row fits %.1f m" % length)


def _fire_walls(rng, row):
    """Fire walls down a row (lots' kinds and quirks, left to right): the
    party walls between two middle buildings where one stands, runs of 2-6
    buildings between them; {index of the building carrying it: side}."""
    n = len(row)
    out = {}
    run = 1

    for i in range(n - 1):
        a, b = row[i], row[i + 1]
        mids = a["kind"] == "mid" and b["kind"] == "mid"
        gabled = a["quirk"] != "mansard" or b["quirk"] != "mansard"

        if mids and gabled and run >= 2 and n - i - 1 >= 2 and (run >= rng.choice((2, 3)) or not out and n - i - 1 <= 3):
            if a["quirk"] != "mansard":
                out[i] = 1
            else:
                out[i + 1] = 0

            run = 1
        else:
            run += 1

    return out


def _row(rng, block, face):
    """One long front of a block: its lots' fields, left to right as they
    face the street (east: south to north; west: north to south)."""
    x0, z0, x1, z1 = block
    end = rng.choice((7.5, 10.0))
    bays, side = _pack(rng, z1 - z0, end)
    out = []

    if face == "e":
        # (Its south corner faces south, its side down this front; its
        # north corner faces east, its side north.)
        out.append({"x": x1 - DEPTH / 2.0, "z": z1, "yaw": 0.0, "width": DEPTH, "depth": side, "bays": 4, "kind": "corner"})
        z = z1 - side

        for b in bays:
            out.append({"x": x1, "z": z - width(b) / 2.0, "yaw": 90.0, "width": width(b), "depth": DEPTH, "bays": b, "kind": "mid"})
            z -= width(b)

        out.append({"x": x1, "z": z0 + end / 2.0, "yaw": 90.0, "width": end, "depth": DEPTH, "bays": 3 if end > 8.0 else 2, "kind": "corner"})
    else:
        # (Its north corner faces north, its side down this front; its
        # south corner faces west, its side south.)
        out.append({"x": x0 + DEPTH / 2.0, "z": z0, "yaw": 180.0, "width": DEPTH, "depth": side, "bays": 4, "kind": "corner"})
        z = z0 + side

        for b in bays:
            out.append({"x": x0, "z": z + width(b) / 2.0, "yaw": -90.0, "width": width(b), "depth": DEPTH, "bays": b, "kind": "mid"})
            z += width(b)

        out.append({"x": x0, "z": z1 - end / 2.0, "yaw": -90.0, "width": end, "depth": DEPTH, "bays": 3 if end > 8.0 else 2, "kind": "corner"})

    return out


def _fronts(rng, n, first=(), last=()):
    """A row's claddings, left to right: each unlike the one before it, the
    first unlike `first`, the last unlike `last` (the corners it meets on
    the block's short faces)."""
    out = []

    for i in range(n):
        avoid = set(out[-1:]) | (set(first) if i == 0 else set()) | (set(last) if i == n - 1 else set())
        out.append(rng.choice([f for f in FRONTS if f not in avoid]))

    return out


def _plan():
    rng = random.Random(1755)
    look = random.Random(1640)
    lots, rows = [], []

    for block, box in BLOCKS.items():
        east = []

        for face in ("e", "w"):
            row = _row(rng, box, face)
            # (The west row's north corner meets the east row's north corner
            # on the block's north face, its south corner the east row's
            # south corner.)
            fronts = _fronts(look, len(row)) if face == "e" else _fronts(look, len(row), east[-1:], east[:1])

            if face == "e":
                east = fronts

            main = (face == "e" and abs(box[2] - MAIN[0]) < 0.01) or (face == "w" and abs(box[0] - MAIN[1]) < 0.01)

            for i, each in enumerate(row):
                quirk = ""

                # (A mansard never beside a mansard: two read as one roof,
                # and leave their party wall no gable for a fire wall.)
                if each["kind"] == "mid":
                    roll = rng.random()
                    beside = i > 0 and row[i - 1]["quirk"] == "mansard"
                    quirk = "arched_shop" if main and roll < 0.45 else "mansard" if roll > 0.8 and not beside else ""

                each["quirk"] = quirk

            fire = _fire_walls(rng, row)
            names = []

            for i, each in enumerate(row):
                name = "%s_%s%d" % (block, face, i + 1)
                walls = (fire.get(i) == 0, fire.get(i) == 1)
                params = [("bays", each["bays"]), ("kind", each["kind"]), ("front", fronts[i]), ("seed", rng.randrange(1000))]

                if any(walls):
                    params.append(("fire_walls", walls))

                lots.append(Lot(name, "pombal", each["x"], each["z"], GROUND, each["yaw"], each["width"], each["depth"], 4, each["quirk"],
                                params=tuple(params)))
                names.append(name)

            rows.append((block, face, names))

    # About one building in five or six walked in (middle ones, their doors
    # on the street), a third of those lived in.
    mids = [i for i, each in enumerate(lots) if dict(each.params)["kind"] == "mid"]
    chosen = sorted(rng.sample(mids, int(round(len(lots) / 5.5))))

    for k, i in enumerate(chosen):
        each = lots[i]
        lots[i] = Lot(each.name, each.family, each.x, each.z, each.y, each.yaw, each.width, each.depth, each.storeys, each.quirk, True,
                      rng.choice((1, 2, 2, 3)), k % 3 == 0, each.sector, each.params)

    return lots, rows


LOTS, ROWS = _plan()
TERRACE = [(kind, args) for kind, args, _z in sewer()] + [("vault_end", SEWER_SIZE), ("grate_hatch", (HATCH_DEPTH, COLLAR)),
                                                          ("scaffold", (EAVES, SCAFFOLD_WIDTH))]
