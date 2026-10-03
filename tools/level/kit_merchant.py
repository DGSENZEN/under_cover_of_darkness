"""The merchant's house (the old town's spec, sections 5.3 and 7.3): a tall
Porto merchant's house on the upper town's merchants' street (after Rua das
Flores): a shop on the street, four storeys up a skylit stairwell, a
lookout on its roof terrace, its yard behind. Hand-made on kit_town's
grammar; pure data, as kit_recipes (which imports this at its end).

Its five ways in, of three kinds:
    door  its street door into the hall; the shop's door into the shop
    roof  off a neighbouring roof over the terrace's parapet: down the
          skylight over the stairwell; into the lookout and down its hatch
    yard  the yard's gate off the back lane, the back door into the
          counting house

Inside: the hall and its stairwell, the shop and its store, the counting
house (his strongbox), his study up the house (the ledger chest), his
bedroom at the top (the upper gate's key: plan B1b). The front is roofed
(hipped, canal tiles); the back is a terrace walled by its parapet, its
skylight over the stairwell, the lookout (mirante) on it.

The piece's frame: x along its front, its front's face at z 0, the house to
-z, the yard behind it to YARD_END, its foot on the street.
"""

import kit_recipes as k  # noqa: F401 (first: it registers every kit)
import kit_shapes as ks
import kit_town as town

WIDTH = 7.5
DEPTH = 20.0
STOREYS = (3.8, 3.2, 3.2, 3.2)
PARTY = 0.4
FRONT = 0.6
BACK = 0.4
FRONT_ROOF = 12.0
YARD = 6.0
YARD_WALL = (2.5, 0.3)
DOOR = (1.2, 2.2)
SHOP_DOOR = (1.6, 2.8)
WINDOW = (1.25, 1.5, 0.9)
STAIR = 1.0
STAIR_Z = -16.5
MIRANTE = (2.4, 2.2, 2.4)
BUDGET = 11000

LEVELS = [sum(STOREYS[:i]) for i in range(len(STOREYS))]
EAVES = sum(STOREYS)
INNER = WIDTH - 2.0 * PARTY
HALF = INNER / 2.0
YARD_END = -DEPTH - YARD
STREET_X = -1.85
SHOP_X = 1.5


def _stairs():
    """The stairwell: two flights a storey, stacked, on the left of the
    hall; [(origin x, y, z, rise)] and the well's footprint."""
    x = -HALF + STAIR
    flights = [(x, LEVELS[i], STAIR_Z, STOREYS[i]) for i in range(len(STOREYS) - 1)]
    f = town.stair_reach("two_flight", STAIR, max(STOREYS))["footprint"]
    return flights, (x + f[0], STAIR_Z + f[1], x + f[2], STAIR_Z + f[3])


def design():
    shapes, cols = [], []
    doors, places = [], {}
    flights, well = _stairs()

    # The front: the street door, the shop's door, a window; balcony doors
    # and windows up it, shut or lit.
    front = [town.Opening(STREET_X, 0.0, DOOR[0], DOOR[1], "door"), town.Opening(SHOP_X, 0.0, SHOP_DOOR[0], SHOP_DOOR[1], "door")]

    for i in range(1, len(STOREYS)):
        for x, kind in ((-1.85, "shut"), (1.85, "lit" if i == len(STOREYS) - 1 else "shut")):
            front.append(town.Opening(x, LEVELS[i], WINDOW[0], 2.6, kind))

    s, c = town.band(WIDTH, 0.0, EAVES, FRONT, front, "render_blue", (0.0, -FRONT / 2.0, 0.0))
    shapes, cols = shapes + s, cols + c
    doors += [[STREET_X, 0.0, -FRONT / 2.0, 0.0], [SHOP_X, 0.0, -FRONT / 2.0, 0.0]]

    for i in range(1, len(STOREYS)):
        for x in (-1.85, 1.85):
            b, bc = town.balcony(x, LEVELS[i], WINDOW[0] + 0.4, 0.5, 0.0)
            shapes, cols = shapes + b, cols + bc

    # The back onto the yard: the counting house's door, windows shut.
    # (Turned 180 degrees the wall's x runs to -x: the door at +1.85, into
    # the counting house.)
    back = [town.Opening(STREET_X, 0.0, DOOR[0], DOOR[1], "door")] + [town.Opening(0.0, LEVELS[i] + WINDOW[2], WINDOW[0], WINDOW[1], "shut")
                                                                       for i in range(1, len(STOREYS))]
    s, c = town.band(WIDTH, 0.0, EAVES, BACK, back, "render_blue", (0.0, -DEPTH + BACK / 2.0, 180.0), frames=False)
    shapes, cols = shapes + s, cols + c
    doors.append([-STREET_X, 0.0, -DEPTH + BACK / 2.0, 180.0])

    for sx in (-1.0, 1.0):
        x = sx * (WIDTH / 2.0 - PARTY / 2.0)
        shapes.append(ks.box(x, EAVES / 2.0, -DEPTH / 2.0, PARTY, EAVES, DEPTH, "granite"))
        cols.append(town.col(x, EAVES / 2.0, -DEPTH / 2.0, PARTY, EAVES, DEPTH))

    # The ground floor: the hall (the stairwell in it), the shop and its
    # store, the counting house at the back.
    z0, z1 = -DEPTH + BACK, -FRONT
    # (The hall the house's depth on its left, its stairwell at its back.)
    hall_x = -HALF + 3.0
    plan = [(-HALF, z0, hall_x, z1), (hall_x, -8.0, HALF, z1), (hall_x, -12.5, HALF, -8.0), (hall_x, z0, HALF, -12.5)]
    s, c = town.rooms(plan, 0.0, STOREYS[0], [(hall_x, -4.0), (1.5, -8.0), (1.5, -12.5), (hall_x, -18.0)], "plaster", "stone")
    shapes, cols = shapes + s, cols + c

    # Floors a storey (holes over the stairwell); the terrace over the back
    # (a hole for the skylight over the well, wider than it, the ladder down
    # at its side), the hipped roof over the front.
    middle = (z0 + z1) / 2.0
    skylight = (well[0], well[1], well[2] + 1.0, well[3])

    for i, y in enumerate(LEVELS):
        hole = well if i >= 1 else None
        local = hole and (hole[0], hole[1] - middle, hole[2], hole[3] - middle)
        s, c = town.floors(INNER, z1 - z0, [y], local, "flagstone" if i == 0 else "boards", "stone" if i == 0 else "wood")
        s, c = town.placed(s, c, z=middle)
        shapes, cols = shapes + s, cols + c

    for x, y, z, rise in flights:
        s, c = town.stair("two_flight", STAIR, rise, (x, y, z), 0.0, "boards", "wood", solid=False)
        shapes, cols = shapes + s, cols + c

    back_d = DEPTH - FRONT_ROOF - BACK
    back_mid = -FRONT_ROOF - back_d / 2.0
    mw, mh, md = MIRANTE
    mx, mz = HALF - mw / 2.0 - 0.3, -DEPTH + BACK + md / 2.0 + 0.3
    hatch = (mx - 0.5, mz - 0.5, mx + 0.5, mz + 0.5)
    s, c = town.floors(INNER, back_d, [EAVES], [(h[0], h[1] - back_mid, h[2], h[3] - back_mid) for h in (skylight, hatch)], "terracotta", "stone")
    s, c = town.placed(s, c, z=back_mid)
    shapes, cols = shapes + s, cols + c
    # (The top floor's ceiling under the front roof.)
    s, c = town.floors(INNER, FRONT_ROOF - FRONT, [EAVES], None, "boards", "wood")
    s, c = town.placed(s, c, z=-FRONT - (FRONT_ROOF - FRONT) / 2.0)
    shapes, cols = shapes + s, cols + c
    rs, rc = town.roof("hipped", WIDTH, FRONT_ROOF, EAVES, 27.0, "granite")
    rs, rc = town.placed(rs, rc, z=-FRONT_ROOF / 2.0)
    shapes, cols = shapes + rs, cols + rc

    for x, z, w, d in ((0.0, -DEPTH + 0.125, WIDTH, 0.25), (-WIDTH / 2.0 + 0.125, back_mid, 0.25, back_d), (WIDTH / 2.0 - 0.125, back_mid, 0.25, back_d)):
        shapes.append(ks.box(x, EAVES + town.PARAPET / 2.0, z, w, town.PARAPET, d, "granite"))
        cols.append(town.col(x, EAVES + town.PARAPET / 2.0, z, w, town.PARAPET, d))

    # The skylight's lantern round its hole: low glazed sides, open (its
    # glass lifted), a ladder down from its rim to the top floor beside the
    # well.
    sx0, sz0, sx1, sz1 = skylight
    for x, z, w, d in (((sx0 + sx1) / 2.0, sz0 - 0.05, sx1 - sx0, 0.1), ((sx0 + sx1) / 2.0, sz1 + 0.05, sx1 - sx0, 0.1),
                       (sx1 + 0.05, (sz0 + sz1) / 2.0, 0.1, sz1 - sz0)):
        shapes.append(ks.box(x, EAVES + 0.3, z, w, 0.6, d, "glass_dark"))
        cols.append(town.col(x, EAVES + 0.3, z, w, 0.6, d))

    ladder_x = well[2] + 0.5
    top = LEVELS[-1]
    climbs = [[ladder_x, (top + EAVES + 0.6) / 2.0, (sz0 + sz1) / 2.0, 0.8, EAVES + 0.6 - top, 0.8, 0.0]]
    shapes.append(ks.box(ladder_x, (top + EAVES) / 2.0, (sz0 + sz1) / 2.0 - 0.45, 0.6, EAVES - top, 0.06, "timber"))

    # The lookout on the terrace: its door onto the terrace, a hatch and
    # ladder down inside it to the top floor.
    look = [town.Opening(0.0, EAVES, 0.9, 1.9, "door")]
    s, c = town.band(mw, EAVES, EAVES + mh, 0.15, look, "plaster", (mx, mz + md / 2.0 - 0.075, 0.0), frames=False)
    shapes, cols = shapes + s, cols + c

    for x, z, w, d in ((mx, mz - md / 2.0 + 0.075, mw, 0.15), (mx - mw / 2.0 + 0.075, mz, 0.15, md - 0.3), (mx + mw / 2.0 - 0.075, mz, 0.15, md - 0.3)):
        shapes.append(ks.box(x, EAVES + mh / 2.0, z, w, mh, d, "plaster"))
        cols.append(town.col(x, EAVES + mh / 2.0, z, w, mh, d))

    shapes += [ks.box(mx, EAVES + mh + 0.1, mz, mw + 0.3, 0.2, md + 0.3, "iron"),
               ks.card(mx, EAVES + mh * 0.6, mz - md / 2.0 - 0.01, mw * 0.6, mh * 0.4, "glass_dark", 180.0)]
    cols.append(town.col(mx, EAVES + mh + 0.1, mz, mw + 0.3, 0.2, md + 0.3))
    climbs.append([mx, (top + EAVES + 0.6) / 2.0, mz, 0.8, EAVES + 0.6 - top, 0.8, 0.0])
    doors.append([mx, EAVES, mz + md / 2.0 - 0.075, 0.0])
    places.update({"lookout": [mx, EAVES, mz], "strongbox": [-2.0, 0.0, -17.5], "ledger_chest": [2.0, LEVELS[2], -6.0],
                   "key_place": [2.0, LEVELS[3], -10.0], "shop": [2.0, 0.0, -4.0]})

    # The yard: its walls, its gate onto the back lane.
    wall_h, wall_t = YARD_WALL
    s, c = town.band(WIDTH, 0.0, wall_h, wall_t, [town.Opening(0.0, 0.0, DOOR[0], DOOR[1], "door")], "whitewash",
                     (0.0, YARD_END + wall_t / 2.0, 180.0), frames=False)
    shapes, cols = shapes + s, cols + c
    doors.append([0.0, 0.0, YARD_END + wall_t / 2.0, 180.0])

    for sx in (-1.0, 1.0):
        x = sx * (WIDTH / 2.0 - wall_t / 2.0)
        shapes.append(ks.box(x, wall_h / 2.0, -DEPTH - YARD / 2.0, wall_t, wall_h, YARD - wall_t, "whitewash"))
        cols.append(town.col(x, wall_h / 2.0, -DEPTH - YARD / 2.0, wall_t, wall_h, YARD - wall_t))

    s, c = town.floors(WIDTH - 2.0 * wall_t, YARD - wall_t, [0.0], None, "calcada", "stone")
    s, c = town.placed(s, c, z=-DEPTH - YARD / 2.0 + wall_t / 2.0)
    shapes, cols = shapes + s, cols + c

    # Its ways in.
    hall = [-2.6, 0.0, -6.0]
    shop = [2.0, 0.0, -4.0]
    counting = [1.5, 0.0, -17.0]
    attic = [1.5, top, -6.0]
    # (Over the parapet forward of the lookout.)
    neighbour = [WIDTH / 2.0 + 1.5, EAVES, -14.0]
    over = [[WIDTH / 2.0 - 0.125, EAVES + town.PARAPET, -14.0, "mantle"], [HALF - 0.6, EAVES, -14.0, "drop"]]
    ways = [
        {"kind": "door", "points": [[STREET_X, 0.0, 1.0, "walk"], [STREET_X, 0.0, -1.5, "walk"], hall + ["walk"]]},
        {"kind": "door", "points": [[SHOP_X, 0.0, 1.0, "walk"], [SHOP_X, 0.0, -1.5, "walk"], shop + ["walk"]]},
        {"kind": "roof", "points": [neighbour + ["walk"]] + over + [[ladder_x, EAVES, sz1 + 0.6, "walk"],
                                                                     [ladder_x, top, sz0 - 0.4, "climb"], attic + ["walk"]]},
        {"kind": "roof", "points": [neighbour + ["walk"]] + over + [[mx, EAVES, mz + md / 2.0 + 0.6, "walk"], [mx, EAVES, mz + 0.6, "walk"],
                                                                     [mx, top, mz - 0.6, "climb"], attic + ["walk"]]},
        {"kind": "yard", "points": [[0.0, 0.0, YARD_END - 1.0, "walk"], [0.0, 0.0, YARD_END + 2.0, "walk"], [-STREET_X, 0.0, -DEPTH - 1.0, "walk"],
                                    [-STREET_X, 0.0, -DEPTH + 1.2, "walk"], counting + ["walk"]]},
    ]
    return {"shapes": shapes, "cols": cols, "size": [WIDTH, EAVES + 4.0, 2.0 * (DEPTH + YARD)], "doors": doors, "ways": ways,
            "entries": [w["kind"] for w in ways], "places": places, "climbs": climbs, "budget": BUDGET,
            "footprint": (-WIDTH / 2.0, YARD_END, WIDTH / 2.0, 0.0), "chimneys": [[-2.0, EAVES + 2.6, -4.0]]}


town.register("merchant_house", "town", "render_blue", design())
