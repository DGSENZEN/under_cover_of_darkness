"""The Porto house (the old town's spec, section 5.2; old_town_porto.md's kit
and sections 9 and 13): the narrow tall house of the stairs and the upper
town, generated from its lot on kit_town's grammar.

A shop floor SHOP high, then UPPER storeys; granite party walls; a stone
front (a tabique one over a jetty) with one bay of BAY openings per 3 m of
front (two at 4.5, three at 6 and 7.5); first-floor balcony doors on
balconies hung from the street, more balconies up the front by chance; a
hipped roof of canal tiles at PITCH; a chimney stack; one quirk.

An honest house is a solid body behind a front drawn shut. An enterable one
is hollow: its front door (and on two_level the back door a storey up) are
live, its bottom `rooms` storeys are rooms one over another joined by
straight stairs along the party walls (two flights about a half-landing in a
house 15 m deep or more), the storeys over them sealed. Its tour is the
route from the street through its door into each room (the rules walk it).

The piece's frame: x along the front, its front's face at z 0 (the lot's
front middle), the house behind it to -z, its foot on the street (y 0).
"""

import math
import random

import kit_recipes  # noqa: F401 (first: it registers every kit, kit_iberian among them)
import kit_iberian as ib
import kit_shapes as ks
import kit_town as town

SHOP = 3.8
UPPER = 3.2
PARTY = 0.4
SLOT_PARTY = 0.15
FRONT_WALL = 0.6
BACK_WALL = 0.4
TABIQUE = 0.15
BAY = 1.25
SILL = 0.9
HEAD = 2.4
BALCONY_DOOR = 2.8
BALCONY = (0.5, 0.15)
SHOP_DOOR = (1.6, 2.8)
DOOR = (1.2, 2.2)
SLOT_DOOR = 0.9
PITCH = 27.0
JETTY = 0.4
MIRANTE = (2.0, 2.0, 2.2)
DORMER = (1.0, 1.4, 1.2)
PRIVY = 1.2
SLOT_WIDTH = 1.5
# A corner house's side windows: their width, the triangles each costs.
SIDE_WINDOW = 1.0
SIDE_BUDGET = 70
STAIR_WIDTH = 0.9
# A house this deep turns its first stair about a half-landing.
TWO_FLIGHT_DEPTH = 15.0
# Up the front past the first floor, a balcony this often.
BALCONIES = 0.35
QUIRKS = ("", "jetty", "mirante", "dormer", "privy_tower", "against_wall", "corner_shrine", "two_level", "slot")


def bays(width):
    return 1 if width < 4.0 else 2 if width < 5.5 else 3


def _honest(rng, storey, top):
    """What a shut opening shows: mostly shutters, lit more often high up."""
    roll = rng.random()
    lit = 0.22 if storey < top else 0.32

    if roll < lit:
        return "lit"

    if roll < lit + 0.06:
        return "blind" if storey > 0 else "barred"

    if roll < lit + 0.09:
        return "boarded"

    return "shut"


def design(width, depth, storeys, quirk="", enterable=False, rooms=0, front="render_ochre", side="granite", seed=0, shop=SHOP,
           back_storey=1, corner=""):
    """A Porto house: see the module's doc. Returns a kit_town design with
    `openings` ([storey, face, x, y, w, h, kind]), `balconies` ([x, top,
    width, depth]), `eaves`, `doors`, `entries`, `rooms_at`, `tour` and (a
    two_level house) `out_back`, `places`. Its ground storey `shop` high (a
    two_level house's as tall as the terrace step it straddles, its back
    door on `back_storey`). A corner house's open sides (`corner`: "w",
    "e" or both) are clad as its front, a window on every storey (their
    openings' faces "west", "east"; their x the piece's z)."""
    if quirk not in QUIRKS:
        raise ValueError("no Porto quirk '%s'" % quirk)

    rng = random.Random(seed * 7919 + int(width * 10) * 31 + int(depth) * 17 + storeys)
    party = PARTY

    if quirk == "slot":
        width, party = SLOT_WIDTH, SLOT_PARTY

    if quirk == "two_level":
        enterable, rooms, storeys = True, max(rooms, back_storey + 1), max(storeys, back_storey + 1)

    rooms = min(max(rooms, 1), 3, storeys) if enterable else 0
    eaves = shop + (storeys - 1) * UPPER
    jet = JETTY if quirk == "jetty" else 0.0
    inner = width - 2.0 * party
    n = bays(width) if quirk != "slot" else 1
    pitch = inner / n
    xs = [(i - (n - 1) / 2.0) * pitch for i in range(n)]
    leaf = min(BAY, pitch - 0.35) if quirk != "slot" else 0.6
    out = {"openings": [], "balconies": [], "doors": [], "entries": [], "places": {}, "eaves": eaves, "budget": town.house_budget(n, storeys, enterable)}
    shapes, cols = [], []

    # The ground floor's openings: the door, the shop, a window.
    door_x = xs[0]
    ground = [town.Opening(door_x, 0.0, SLOT_DOOR if quirk == "slot" else DOOR[0], DOOR[1], "door" if enterable else "barred")]

    if n >= 2:
        ground.append(town.Opening(xs[1], 0.0, min(SHOP_DOOR[0], pitch - 0.3), SHOP_DOOR[1], "barred"))

    if n >= 3:
        ground.append(town.Opening(xs[2], SILL, leaf, HEAD - SILL, _honest(rng, 0, storeys - 1)))

    # The storeys over it: balcony doors on the first, then windows or
    # balcony doors by chance.
    upper = []

    for s in range(1, storeys):
        y = (s - 1) * UPPER

        for i, x in enumerate(xs):
            balcony = s == 1 or rng.random() < BALCONIES
            live = enterable and rooms >= 2 and s == 1 and i == len(xs) - 1
            kind = "window" if live else _honest(rng, s, storeys - 1)

            if balcony:
                upper.append(town.Opening(x, y, leaf, BALCONY_DOOR, kind))
                out["balconies"].append([x, shop + (s - 1) * UPPER, leaf + 0.4, BALCONY[0]])
            else:
                upper.append(town.Opening(x, y + SILL, leaf, HEAD - SILL, kind))

            if live:
                out["entries"].append("window")

    for o in ground:
        out["openings"].append([0, "front", o.x, o.y, o.width, o.height, o.kind])

    for o in upper:
        storey = 1 + int((o.y + 1e-6) // UPPER)
        out["openings"].append([storey, "front", o.x, o.y + shop, o.width, o.height, o.kind])

    # The front: the ground floor's band, the storeys' over it (out over the
    # street on a jetty, a tabique front).
    s1, c1 = town.wall(width, shop, FRONT_WALL, ground, front, (0.0, -FRONT_WALL / 2.0, 0.0), inside=enterable)
    thick = TABIQUE if jet else FRONT_WALL
    s2, c2 = town.wall(width, eaves - shop, thick, upper, front, (0.0, jet - thick / 2.0, 0.0), inside=enterable)
    s2, c2 = town.placed(s2, c2, y=shop)
    shapes += s1 + s2

    if jet:
        # (The jetty's beam ends under its overhang; its sides closed, the
        # party walls carried on out to its front.)
        shapes += [ks.box(x, shop - 0.12, jet / 2.0, 0.18, 0.24, jet + 0.3, "timber") for x in (-width / 2.0 + 0.3, 0.0, width / 2.0 - 0.3)]

        for sx in (-1.0, 1.0):
            cheek = (sx * (width / 2.0 - party / 2.0), (shop + eaves) / 2.0, (jet - thick) / 2.0, party, eaves - shop, jet - thick)
            shapes.append(ks.box(*cheek, side))
            cols.append(town.col(*cheek))

    # The back: a window a storey, shut; a two_level house's door a storey
    # up; against the wall, its top floor's door onto the wall-walk.
    back_x = xs[-1]
    back = [town.Opening(back_x, shop + (s - 1) * UPPER + SILL if s else SILL, leaf, HEAD - SILL, _honest(rng, s, storeys - 1))
            for s in range(storeys)]

    if quirk == "two_level":
        # (In the bay away from the stairs, which climb by the left party
        # wall: not over their well.)
        up = shop + (back_storey - 1) * UPPER
        back[back_storey] = town.Opening(xs[0], up, DOOR[0], DOOR[1], "door")
        out["doors"].append([-xs[0], up, -depth + BACK_WALL / 2.0, 180.0])
        out["entries"].append("door")

    if quirk == "against_wall":
        # (Barred: it opens in the night's plan, if ever.)
        top = shop + (storeys - 2) * UPPER
        back[-1] = town.Opening(back_x, top, DOOR[0], DOOR[1], "barred")
        out["places"]["wall_door"] = [-back_x, top, -depth]

    s3, c3 = town.wall(width, eaves, BACK_WALL, back, side, (0.0, -depth + BACK_WALL / 2.0, 180.0), frames=False, inside=enterable, flat=True)
    shapes += s3

    for o in back:
        out["openings"].append([0 if o.y < shop else 1 + int((o.y - shop + 1e-6) // UPPER), "back", o.x, o.y, o.width, o.height, o.kind])

    # The party walls, plain granite; a corner's open side clad as the
    # front, a barred window on the ground floor and one or two shut or lit
    # on each storey over it (drawn flat on a slot house's thin wall).
    for sx, letter, face in ((-1.0, "w", "west"), (1.0, "e", "east")):
        x = sx * (width / 2.0 - party / 2.0)

        if letter not in corner:
            shapes.append(ks.box(x, eaves / 2.0, -depth / 2.0, party, eaves, depth, side))
            cols.append(town.col(x, eaves / 2.0, -depth / 2.0, party, eaves, depth))
            continue

        along = [0.0] if depth < 10.0 else [-depth / 4.0, depth / 4.0]
        sides = [town.Opening(0.0, SILL, SIDE_WINDOW, HEAD - SILL, "barred")]

        for s in range(1, storeys):
            sides += [town.Opening(a, shop + (s - 1) * UPPER + SILL, SIDE_WINDOW, HEAD - SILL, _honest(rng, s, storeys - 1)) for a in along]

        s4, c4 = town.wall(depth, eaves, party, sides, front, (x, -depth / 2.0, 90.0 * sx), frames=False, inside=enterable,
                           flat=party < 0.3)
        shapes += s4
        cols += c4
        out["budget"] += SIDE_BUDGET * len(sides)

        for o in sides:
            storey = 0 if o.y < shop else 1 + int((o.y - shop + 1e-6) // UPPER)
            out["openings"].append([storey, face, -depth / 2.0 - sx * o.x, o.y, o.width, o.height, o.kind])

    # Balconies: their slabs, rails and corbels, their colliders.
    for x, top, wide, deep in out["balconies"]:
        face = jet if top > shop - 0.01 else 0.0
        b, bc = town.balcony(x, top, wide, deep, face)
        shapes += b
        cols += bc

    if enterable:
        inside = _inside(out, width, depth, storeys, rooms, party, door_x, back_x, eaves, quirk, shop, back_storey)
        shapes += inside[0]
        cols += c1 + c2 + c3 + inside[1]
    else:
        cols.append(town.col(0.0, eaves / 2.0, -depth / 2.0, width - 2.0 * party + 0.02, eaves, depth))

        if jet:
            cols.append(town.col(0.0, shop + (eaves - shop) / 2.0, jet / 2.0, width, eaves - shop, jet))

    # The roof, its eaves' cornice, its chimney.
    rs, rc = town.roof("hipped", width, depth + jet, eaves, PITCH, side)
    rs, rc = town.placed(rs, rc, z=-(depth - jet) / 2.0)
    shapes += rs + [ks.box(0.0, eaves - 0.1, jet + 0.12, width, 0.2, 0.3, "granite"), ks.box(0.0, eaves - 0.1, -depth - 0.12, width, 0.2, 0.3, "granite")]
    # (The eaves' cornices solid as drawn: a climber's hands meet them.)
    cols += rc + [town.col(0.0, eaves - 0.1, jet + 0.12, width, 0.2, 0.3), town.col(0.0, eaves - 0.1, -depth - 0.12, width, 0.2, 0.3)]
    rise = min(width, depth + jet) / 2.0 * math.tan(math.radians(PITCH))
    cx, cz = -width / 2.0 + party + 0.5, -depth * 0.7
    top = eaves + rise + 0.6
    shapes += [ks.box(cx, (eaves + top) / 2.0, cz, 0.7, top - eaves, 0.7, side), ks.box(cx, top + 0.08, cz, 0.9, 0.16, 0.9, "granite")]
    cols += [town.col(cx, (eaves + top) / 2.0, cz, 0.7, top - eaves, 0.7), town.col(cx, top + 0.08, cz, 0.9, 0.16, 0.9)]
    out["chimneys"] = [[cx, top + 0.3, cz]]
    _quirk(out, shapes, cols, quirk, width, depth, eaves, rise, jet, party, shop)
    out.update({"shapes": shapes, "cols": cols, "size": [width, eaves + rise + 1.5, depth + jet], "front": front})
    return out


def _stairs(depth, rooms, party, width, shop=SHOP):
    """Where the stairs go: [(kind, x, foot z, yaw, rise, y)], one up to
    each room over the first."""
    inner = width - 2.0 * party
    out = []

    if rooms >= 2:
        # (Two flights take two stairs' width and leave a way past them.)
        if depth >= TWO_FLIGHT_DEPTH and inner >= 2.0 * STAIR_WIDTH + 1.0:
            out.append(("two_flight", -inner / 2.0 + STAIR_WIDTH, -depth + BACK_WALL + 1.2, 0.0, shop, 0.0))
        else:
            out.append(("straight", -inner / 2.0 + STAIR_WIDTH / 2.0, -depth + BACK_WALL + 0.3, 0.0, shop, 0.0))

    if rooms >= 3:
        out.append(("straight", inner / 2.0 - STAIR_WIDTH / 2.0, -FRONT_WALL - 0.4, 180.0, UPPER, shop))

    return out


def _hole(kind, x, z, yaw, rise):
    """A stair's footprint in the house's frame (x0, z0, x1, z1)."""
    f = town.stair_reach(kind, STAIR_WIDTH, rise)["footprint"]

    if yaw:
        return (x - f[2], z - f[3], x - f[0], z - f[1])

    return (x + f[0], z + f[1], x + f[2], z + f[3])


def _inside(out, width, depth, storeys, rooms, party, door_x, back_x, eaves, quirk, shop=SHOP, back_storey=1):
    """An enterable house's inside: a floor at each room's foot, a ceiling
    over the last, the stairs between, the storeys over them sealed; its
    rooms' standing places, its door, its tour."""
    inner = width - 2.0 * party
    levels = [0.0] + [shop + i * UPPER for i in range(storeys - 1)]
    stairs = _stairs(depth, rooms, party, width, shop)
    shapes, cols = [], []
    room_depth = depth - FRONT_WALL - BACK_WALL

    for r in range(rooms + 1):
        y = levels[r] if r < len(levels) else eaves
        hole = None

        if 0 < r <= len(stairs):
            kind, x, z, yaw, rise, _y = stairs[r - 1]
            hole = _hole(kind, x, z, yaw, rise)

        s, c = town.floors(inner, room_depth, [y], hole and (hole[0], hole[1] + depth / 2.0 + (FRONT_WALL - BACK_WALL) / 2.0,
                                                            hole[2], hole[3] + depth / 2.0 + (FRONT_WALL - BACK_WALL) / 2.0))
        s, c = town.placed(s, c, z=-depth / 2.0 - (FRONT_WALL - BACK_WALL) / 2.0)
        shapes, cols = shapes + s, cols + c

    for kind, x, z, yaw, rise, y in stairs:
        s, c = town.stair(kind, STAIR_WIDTH, rise, (x, y, z), yaw, "flagstone" if y == 0.0 else "boards", "stone" if y == 0.0 else "wood")
        shapes, cols = shapes + s, cols + c

    # (Over the last room the house is solid to its eaves.)
    top = levels[rooms] if rooms < len(levels) else eaves

    if top < eaves - 0.01:
        cols.append(town.col(0.0, (top + eaves) / 2.0, -depth / 2.0, inner, eaves - top, room_depth))

    # (The door hung there its opening's size: a slot house's narrow.)
    front = [o for o in out["openings"] if o[0] == 0 and o[1] == "front" and o[6] == "door"][0]
    out["doors"].insert(0, [door_x, 0.0, -FRONT_WALL / 2.0, 0.0, front[4], front[5]])
    out["entries"].insert(0, "door")
    # (Each room's place: on the side away from the first stair.)
    out["rooms_at"] = [[inner / 4.0, levels[r], -depth / 2.0] for r in range(rooms)]
    tour = [[door_x, 0.0, 1.0, "walk"], [door_x, 0.0, -FRONT_WALL - 0.8, "walk"], out["rooms_at"][0] + ["walk"]]

    for (kind, x, z, yaw, rise, y), r in zip(stairs, range(1, rooms)):
        tour += town.stair_tour(kind, STAIR_WIDTH, rise, (x, y, z), yaw)
        tour.append(out["rooms_at"][r] + ["walk"])

    out["tour"] = tour

    if quirk == "two_level":
        # (Out to the back door's threshold: the terrace behind is the
        # layout's.)
        up = shop + (back_storey - 1) * UPPER
        out["out_back"] = [[-door_x, up, -depth + BACK_WALL + 0.8, "walk"], [-door_x, up, -depth + BACK_WALL / 2.0, "walk"]]

    return shapes, cols


def _quirk(out, shapes, cols, quirk, width, depth, eaves, rise, jet, party, shop=SHOP):
    """The house's one quirk on its roof or its back (the doors' are in
    design)."""
    if quirk == "mirante":
        w, d, h = MIRANTE
        y0, z = eaves + rise - 0.4, -depth / 2.0
        shapes += [ks.box(0.0, y0 + h / 2.0, z, w, h, d, "plaster"), ks.box(0.0, y0 + h + 0.08, z, w + 0.3, 0.16, d + 0.3, "iron")]
        shapes += [ks.card(0.0, y0 + h * 0.55, z + d / 2.0 + 0.02, w * 0.7, h * 0.5, "glass_dark"),
                   ks.card(0.0, y0 + h * 0.55, z - d / 2.0 - 0.02, w * 0.7, h * 0.5, "glass_dark", 180.0)]
        cols.append(town.col(0.0, y0 + h / 2.0 + 0.08, z, w + 0.3, h + 0.16, d + 0.3))
    elif quirk == "dormer":
        w, h, d = DORMER
        z = jet - 1.4
        y0 = eaves + 0.2
        shapes += [ks.box(0.0, y0 + h / 2.0, z, w + 0.2, h, d, "plaster"), ks.card(0.0, y0 + h * 0.5, z + d / 2.0 + 0.02, w * 0.7, h * 0.6, "glass_dark"),
                   ks.box(0.0, y0 + h + 0.1, z, w + 0.4, 0.2, d + 0.2, "roof_clay")]
        cols.append(town.col(0.0, (y0 + h + 0.2 + eaves) / 2.0, z, w + 0.4, y0 + h + 0.2 - eaves, d + 0.2))
    elif quirk == "privy_tower":
        x, z = width / 2.0 - party - PRIVY / 2.0, -depth - PRIVY / 2.0
        shapes += [ks.box(x, (shop + eaves) / 2.0, z, PRIVY, eaves - shop, PRIVY, "plaster"),
                   ks.box(x, shop - 0.15, z, PRIVY + 0.2, 0.3, PRIVY + 0.2, "granite")]
        cols.append(town.col(x, (shop + eaves) / 2.0, z, PRIVY, eaves - shop, PRIVY))
    elif quirk == "corner_shrine":
        x, y = -width / 2.0 + 0.6, 2.4
        shapes.append(ks.box(x, y + 0.45, 0.01, 0.62, 0.92, 0.04, "pitch"))
        out["places"]["shrine"] = [x, y, 0.05]


# (Its lots, if the kit was entered through this module and passed them by.)
town.register_town()
