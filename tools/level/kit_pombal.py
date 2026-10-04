"""The Pombaline building (the old town's spec, section 5.2; old_town_lisbon.md
section 4 and its kit): the Baixa's and the Carmo hill's, rebuilt to a plan
after the great fire, generated from its bays on kit_town's grammar.

Openings as wide as the piers between them (OPENING), END_PIER at each end,
so a bay every BAY_PITCH; storeys of STOREYS (a vaulted shop floor, the
noble floor, lower ones up); on the first floor balcony doors (sacadas) each
on its balcony, sill windows over them; an azulejo front in stone frames; a
paired-brick cornice; a roof of canal tiles at PITCH with dormers, or a
mansard; fire walls FIRE_RISE over the roof at the party walls asked for.

    mid      a building inside a block: its front, its party walls
    corner   a block's corner: a second front down its right side, a
             four-pitched roof
    hill     a narrow building on a hill street (2-3 bays, 3-4 storeys)
    row      a workers' row: two low storeys, no balconies

An enterable building is hollow: its middle door live (on the first floor a
balcony door too, with a room there), its bottom `rooms` storeys rooms one
over another up a stairwell on its axis (two flights a storey about a
half-landing), the storeys over them sealed.

The piece's frame: x along its front, the front's face at z 0, the building
to -z, its foot on the street.
"""

import math
import random

import kit_recipes as k  # (first: it registers every kit, kit_iberian among them)
import kit_iberian as ib
import kit_shapes as ks
import kit_town as town

OPENING = 1.35
END_PIER = 1.6
BAY_PITCH = 2.7
STOREYS = (4.0, 3.7, 3.4, 3.1)
ROW_STOREY = 3.2
SACADA = 2.9
WINDOW = 2.2
SILL = 0.9
SHOP_DOOR = 3.0
ARCHED_SHOP = 1.8
BALCONY = (0.45, 0.15)
FRONT_WALL = 0.6
BACK_WALL = 0.5
PARTY = 0.5
FIRE_RISE = 0.6
FIRE_THICK = 0.8
PITCH = 27.0
DORMER = (1.0, 1.4, 1.2)
STAIR_WIDTH = 1.0
KINDS = ("mid", "corner", "hill", "row")
QUIRKS = ("", "mansard", "arched_shop")


def facade_width(bays):
    """The front's width to the measure: end piers and openings as wide as
    the piers between them."""
    return 2.0 * END_PIER + (2 * bays - 1) * OPENING


def _honest(rng, top):
    roll = rng.random()
    lit = 0.3 if top else 0.22
    return "lit" if roll < lit else "shut"


def roof_at(design, z):
    """The top of a building's roof (its colliders' top) at z down its
    middle: the gable's line, or the mansard's."""
    eaves, depth, kind = design["eaves"], design["size"][2], design["roof"]
    d = depth / 2.0 - abs(z + depth / 2.0)

    if kind == "mansard":
        lower, upper = town.MANSARD
        inset = town.MANSARD_HEIGHT / math.tan(math.radians(lower))

        if d < inset:
            return eaves + d * math.tan(math.radians(lower))

        return eaves + town.MANSARD_HEIGHT + (d - inset) * math.tan(math.radians(upper)) + k.ROOF_THICK / math.cos(math.radians(upper))

    return eaves + d * math.tan(math.radians(PITCH)) + k.ROOF_THICK / math.cos(math.radians(PITCH))


def _front(rng, n, heights, enterable, rooms, kind, quirk, face):
    """A front's openings, band by band: the ground floor's shop doors (the
    middle one the building's door), sacadas on the first floor, windows
    over. [(storey, Opening)]."""
    xs = [(i - (n - 1) / 2.0) * BAY_PITCH for i in range(n)]
    levels = [sum(heights[:i]) for i in range(len(heights))]
    middle = n // 2
    out = []

    for i, x in enumerate(xs):
        if kind == "row":
            if i == middle and face == "front":
                out.append((0, town.Opening(x, 0.0, OPENING, 2.4, "door" if enterable else "barred")))
            else:
                out.append((0, town.Opening(x, SILL, OPENING, 1.4, _honest(rng, False))))
        elif i == middle and face == "front":
            out.append((0, town.Opening(x, 0.0, OPENING, SHOP_DOOR, "door" if enterable else "barred")))
        else:
            wide = ARCHED_SHOP if quirk == "arched_shop" else OPENING
            out.append((0, town.Opening(x, 0.0, wide, SHOP_DOOR, "barred")))

    for s in range(1, len(heights)):
        h = heights[s]

        for i, x in enumerate(xs):
            if s == 1 and kind != "row":
                live = enterable and rooms >= 2 and i == 0 and face == "front"
                out.append((s, town.Opening(x, levels[s], OPENING, SACADA, "window" if live else _honest(rng, False))))
            else:
                tall = min(WINDOW, h - SILL - 0.35)
                out.append((s, town.Opening(x, levels[s] + SILL, OPENING, tall, _honest(rng, s == len(heights) - 1))))

    return out


def design(bays, depth, storeys=4, kind="mid", fire_walls=(False, False), quirk="", enterable=False, rooms=0, front="azulejo_blue",
           side="granite", seed=0):
    """A Pombaline building: see the module's doc. A kit_town design with
    `openings`, `balconies`, `eaves`, `roof`, `doors`, `entries`, `rooms_at`,
    `tour`."""
    if kind not in KINDS or quirk not in QUIRKS:
        raise ValueError("no Pombaline %s / %s" % (kind, quirk))

    rng = random.Random(seed * 6151 + bays * 97 + int(depth) * 13 + storeys)
    heights = [ROW_STOREY] * storeys if kind == "row" else [STOREYS[min(i, len(STOREYS) - 1)] for i in range(storeys)]
    levels = [sum(heights[:i]) for i in range(storeys)]
    eaves = sum(heights)
    rooms = min(max(rooms, 1), 3, storeys) if enterable else 0
    width = math.ceil(facade_width(bays) / town.GRID - 1e-9) * town.GRID
    roof = "mansard" if quirk == "mansard" else "four" if kind == "corner" else "gable"
    side_bays = max(2, int((depth - 2.0 * END_PIER + OPENING) / BAY_PITCH)) if kind == "corner" else 0
    out = {"openings": [], "balconies": [], "doors": [], "entries": [], "places": {}, "eaves": eaves, "roof": roof,
           "budget": town.house_budget(bays + side_bays, storeys, enterable)}
    shapes, cols = [], []
    fronts = [("front", bays, (0.0, -FRONT_WALL / 2.0, 0.0), width)]

    if kind == "corner":
        fronts.append(("side", side_bays, (width / 2.0 - FRONT_WALL / 2.0, -depth / 2.0, 90.0), depth))

    walls = []

    for face, n, place, length in fronts:
        band = _front(rng, n, heights, enterable, rooms, kind, quirk, face)
        s, c = town.wall(length, eaves, FRONT_WALL, [o for _s, o in band], front, place, inside=enterable)
        shapes += s
        walls += c
        turn = place[2]

        for storey, o in band:
            out["openings"].append([storey, face, o.x, o.y, o.width, o.height, o.kind])

            if storey == 1 and kind != "row":
                # (A sacada's balcony, laid on a front facing +z and turned
                # onto its face.)
                b, bc = town.balcony(o.x, o.y, o.width + 0.3, BALCONY[0], FRONT_WALL / 2.0)
                b, bc = town.placed(b, bc, place[0], place[1], turn)
                shapes += b
                cols += bc

                if face == "front":
                    out["balconies"].append([o.x, o.y, o.width + 0.3, BALCONY[0]])

            if o.live and o.kind == "window":
                out["entries"].append("window")

    # The back: windows shut or lit, plain.
    back = [town.Opening((i - (bays - 1) / 2.0) * BAY_PITCH, levels[s] + SILL, OPENING, min(WINDOW, heights[s] - SILL - 0.35),
                         _honest(rng, s == storeys - 1)) for s in range(storeys) for i in range(bays)]
    s, c = town.wall(width, eaves, BACK_WALL, back, side, (0.0, -depth + BACK_WALL / 2.0, 180.0), frames=False, inside=enterable, flat=True)
    shapes += s
    walls += c

    # The party walls (on a corner, the left only), plain.
    for sx in ((-1.0,) if kind == "corner" else (-1.0, 1.0)):
        x = sx * (width / 2.0 - PARTY / 2.0)
        shapes.append(ks.box(x, eaves / 2.0, -depth / 2.0, PARTY, eaves, depth, side))
        cols.append(town.col(x, eaves / 2.0, -depth / 2.0, PARTY, eaves, depth))

    if enterable:
        inside = _inside(out, width, depth, heights, levels, rooms, kind, eaves)
        shapes += inside[0]
        cols += walls + inside[1]
    else:
        # (Solid to its faces: on a corner, to its side's face too.)
        right = 0.0 if kind == "corner" else PARTY
        cols.append(town.col((PARTY - right) / 2.0, eaves / 2.0, -depth / 2.0, width - PARTY - right + 0.02, eaves, depth))

    # The roof, the paired-brick cornice, dormers, chimneys.
    rs, rc = town.roof(roof, width, depth, eaves, PITCH, side)
    rs, rc = town.placed(rs, rc, z=-depth / 2.0)
    shapes += rs + [ks.box(0.0, eaves - 0.15, 0.1, width, 0.3, 0.25, "brick")]
    # (The cornice solid as drawn: a climber's hands meet it.)
    cols += rc + [town.col(0.0, eaves - 0.15, 0.1, width, 0.3, 0.25)]

    if kind == "corner":
        shapes.append(ks.box(width / 2.0 + 0.1, eaves - 0.15, -depth / 2.0, 0.25, 0.3, depth, "brick"))
        cols.append(town.col(width / 2.0 + 0.1, eaves - 0.15, -depth / 2.0, 0.25, 0.3, depth))

    if roof != "mansard":
        _dormers(shapes, cols, bays, eaves, rng)

    ridge = roof_at(out | {"size": [width, 0.0, depth]}, -depth / 2.0)

    for x in ([-(bays - 1) / 2.0 * BAY_PITCH, (bays - 1) / 2.0 * BAY_PITCH] if bays >= 4 else [-(bays - 1) / 2.0 * BAY_PITCH]):
        z, top = -depth * 0.55, ridge + 0.8
        shapes += [ks.box(x, (eaves + top) / 2.0, z, 0.8, top - eaves, 0.8, side), ks.box(x, top + 0.08, z, 1.0, 0.16, 1.0, "granite")]
        cols += [town.col(x, (eaves + top) / 2.0, z, 0.8, top - eaves, 0.8), town.col(x, top + 0.08, z, 1.0, 0.16, 1.0)]
        out.setdefault("chimneys", []).append([x, top + 0.3, z])

    out.update({"shapes": shapes, "cols": cols, "size": [width, ridge - eaves + eaves + 1.5, depth], "front": front})
    out["size"][1] = ridge + 1.5

    for i, sx in enumerate((-1.0, 1.0)):
        if fire_walls[i] and roof == "gable":
            _fire_wall(out, sx * (width / 2.0 - PARTY / 2.0), side)

    return out


def _dormers(shapes, cols, bays, eaves, rng):
    """Dormers on the front slope, one to every two bays."""
    w, h, d = DORMER
    count = max(1, bays // 2)
    z = -1.6

    for i in range(count):
        x = (i - (count - 1) / 2.0) * BAY_PITCH * 2.0
        y0 = eaves + 0.2
        shapes += [ks.box(x, y0 + h / 2.0, z, w + 0.2, h, d, "plaster"),
                   ks.card(x, y0 + h * 0.5, z + d / 2.0 + 0.02, w * 0.7, h * 0.6, "glass_lit" if rng.random() < 0.25 else "glass_dark"),
                   ks.box(x, y0 + h + 0.1, z, w + 0.4, 0.2, d + 0.2, "roof_clay")]
        cols.append(town.col(x, (y0 + h + 0.2 + eaves) / 2.0, z, w + 0.4, y0 + h + 0.2 - eaves, d + 0.2))


def _fire_wall(out, x, slot):
    """A fire wall on the party wall at x, standing FIRE_RISE over the
    gable roof along its whole line under a tile cap: drawn as a band over
    the eaves and a gable over it; its colliders a slab under each slope's
    line, FIRE_THICK thick, its top the cap."""
    eaves, depth = out["eaves"], out["size"][2]
    half = depth / 2.0
    a = math.radians(PITCH)
    rise = half * math.tan(a)
    lift = k.ROOF_THICK / math.cos(a)
    base = eaves + lift + FIRE_RISE
    out["shapes"] += [ks.box(x, (eaves + base) / 2.0, -half, PARTY, base - eaves, depth, slot),
                      ks.gable(x, base, -half, depth, rise, PARTY, slot, 90.0)]

    for s in (-1.0, 1.0):
        # (The slope's top line, from the eaves' end to the ridge, and the
        # slab under it.)
        z_eaves, z_ridge = -half + s * half, -half
        top = [(z_eaves + z_ridge) / 2.0, base + rise / 2.0]
        n = (math.cos(a), s * math.sin(a))
        cy, cz = top[1] - FIRE_THICK / 2.0 * n[0], top[0] - FIRE_THICK / 2.0 * n[1]
        out["cols"].append(town.col(x, cy, cz, PARTY, FIRE_THICK, math.hypot(half, rise), "stone", 0.0, s * PITCH, 0.0))
        out["shapes"].append(ks.box(x, top[1] + 0.04, top[0], PARTY + 0.1, 0.08, math.hypot(half, rise), "roof_spanish", 0.0,
                                    s * PITCH, 0.0))


def _inside(out, width, depth, heights, levels, rooms, kind, eaves):
    """An enterable building's inside: a floor at each room's foot, a
    ceiling over the last, a stairwell on its axis near the back (two
    flights a storey, stacked), the storeys over them sealed; its door,
    rooms' places and its tour."""
    right = FRONT_WALL if kind == "corner" else PARTY
    inner = width - PARTY - right
    middle = (PARTY - right) / 2.0
    room_depth = depth - FRONT_WALL - BACK_WALL
    z0 = -depth + BACK_WALL + 1.2
    holes = []
    shapes, cols = [], []
    reach = [town.stair_reach("two_flight", STAIR_WIDTH, heights[r]) for r in range(rooms)]

    for r in range(rooms + 1):
        y = levels[r] if r < len(levels) else eaves
        hole = None

        # (A floor with a stair coming up through it: its hole.)
        if 1 <= r < rooms:
            f = reach[r - 1]["footprint"]
            hole = (f[0], z0 + f[1], f[2], z0 + f[3])

        centre = -depth / 2.0 - (FRONT_WALL - BACK_WALL) / 2.0
        # (The shop floor stone, the floors over it boards.)
        slot, surface = ("flagstone", "stone") if r == 0 else ("boards", "wood")
        s, c = town.floors(inner, room_depth, [y], hole and (hole[0] - middle, hole[1] - centre, hole[2] - middle, hole[3] - centre), slot, surface)
        s, c = town.placed(s, c, middle, centre)
        shapes, cols = shapes + s, cols + c
        holes.append(hole)

    for r in range(rooms - 1):
        # (The stair up from the shop floor a solid stone flight; those over
        # it slabs, each in its stairwell's hole.)
        s, c = town.stair("two_flight", STAIR_WIDTH, heights[r], (0.0, levels[r], z0), 0.0, "flagstone" if r == 0 else "boards",
                          "stone" if r == 0 else "wood", solid=r == 0)
        shapes, cols = shapes + s, cols + c

    top = levels[rooms] if rooms < len(levels) else eaves

    if top < eaves - 0.01:
        cols.append(town.col(middle, (top + eaves) / 2.0, -depth / 2.0, inner, eaves - top, room_depth))

    door = [o for o in out["openings"] if o[0] == 0 and o[1] == "front" and o[6] == "door"][0]
    # (The door hung there its opening's size: no gap round or over it.)
    out["doors"].insert(0, [door[2], 0.0, -FRONT_WALL / 2.0, 0.0, door[4], door[5]])
    out["entries"].insert(0, "door")
    room_x = middle + inner / 2.0 - 1.2
    out["rooms_at"] = [[room_x, levels[r], -depth / 2.0] for r in range(rooms)]
    tour = [[door[2], 0.0, 1.0, "walk"], [door[2], 0.0, -FRONT_WALL - 0.8, "walk"], out["rooms_at"][0] + ["walk"]]

    for r in range(1, rooms):
        tour.append([0.0 - STAIR_WIDTH / 2.0 + 0.0, levels[r - 1], z0 - 0.8, "walk"])
        tour += town.stair_tour("two_flight", STAIR_WIDTH, heights[r - 1], (0.0, levels[r - 1], z0), 0.0)
        tour.append(out["rooms_at"][r] + ["walk"])

    out["tour"] = tour
    return shapes, cols


# (Its lots, if the kit was entered through this module and passed them by.)
town.register_town()
