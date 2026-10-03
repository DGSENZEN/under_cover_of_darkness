"""The tavern (the old town's spec, sections 5.3 and 7.3): the stairs
quarter's sailors' tavern, a Porto house 7.5 wide and 14 deep over its
cellar, its yard behind it. Hand-made on kit_town's grammar; pure data, as
kit_recipes (which imports this at its end).

Its ways in, of four kinds:
    door    its street door into the tavern room
    yard    the yard's gate off the back lane, its back door
    window  off the lane over the yard wall, onto the shed's roof, through
            its first floor's back window
    below   the cellar's door onto the vaulted stream (the thief's sewer),
            up the cellar stair

Inside: the tavern room (its bar, three tables, twelve drinkers' seats, the
off-duty watchman's table), a stair up to the lodging floor, the cellar and
its sealed door to the undercroft (B1b's and the undercroft's). The piece's
frame: x along its front, its front's face at z 0, the house to -z, its
yard behind it to YARD_END, its foot on the street.
"""

import kit_recipes as k  # noqa: F401 (first: it registers every kit)
import kit_shapes as ks
import kit_town as town

WIDTH = 7.5
DEPTH = 14.0
CELLAR = 3.0
SHOP = 3.8
UPPER = 3.2
STOREYS = 3
PARTY = 0.4
FRONT = 0.6
BACK = 0.4
YARD = 6.0
YARD_WALL = (2.5, 0.3)
SHED = (2.0, 3.0)
DOOR = (1.2, 2.2)
WINDOW = (1.25, 1.5, 0.9)
STAIR = 0.9
TABLE = (1.0, 0.75, 1.0)
BUDGET = 7000

EAVES = SHOP + (STOREYS - 1) * UPPER
INNER = WIDTH - 2.0 * PARTY
YARD_END = -DEPTH - YARD
DOOR_X = -2.0
WINDOW_X = 2.0


def _wall(length, base, top, thick, openings, slot, place, inside=True, frames=True):
    """A wall from `base` to `top` (its openings' feet given from the
    ground), placed."""
    shifted = [town.Opening(o.x, o.y - base, o.width, o.height, o.kind) for o in openings]
    s, c = town.wall(length, top - base, thick, shifted, slot, place, inside=inside, frames=frames)
    return town.placed(s, c, y=base)


def design():
    shapes, cols = [], []
    doors, ways, places = [], [], {}

    # The street front: its door, the tavern room's window lit, the floors
    # over it shut or lit.
    front = [town.Opening(DOOR_X, 0.0, DOOR[0], DOOR[1], "door"), town.Opening(1.6, WINDOW[2], WINDOW[0], WINDOW[1], "lit")]

    for s in range(1, STOREYS):
        y = SHOP + (s - 1) * UPPER

        for x, kind in ((-1.8, "shut"), (1.8, "lit" if s == 1 else "shut")):
            front.append(town.Opening(x, y + WINDOW[2], WINDOW[0], WINDOW[1], kind))

    s, c = _wall(WIDTH, -CELLAR, EAVES, FRONT, front, "render_ochre", (0.0, -FRONT / 2.0, 0.0))
    shapes, cols = shapes + s, cols + c
    doors.append([DOOR_X, 0.0, -FRONT / 2.0, 0.0])

    # The back: the cellar's door onto the stream under the yard, the back
    # door, the first floor's window over the shed.
    back = [town.Opening(-0.0, -CELLAR, DOOR[0], DOOR[1], "door"), town.Opening(-DOOR_X, 0.0, DOOR[0], DOOR[1], "door"),
            town.Opening(-WINDOW_X, SHOP + WINDOW[2], WINDOW[0], WINDOW[1], "window"), town.Opening(2.0, SHOP + UPPER + WINDOW[2], WINDOW[0],
                                                                                                   WINDOW[1], "shut")]
    s, c = _wall(WIDTH, -CELLAR, EAVES, BACK, back, "render_ochre", (0.0, -DEPTH + BACK / 2.0, 180.0), frames=False)
    shapes, cols = shapes + s, cols + c
    doors += [[0.0, -CELLAR, -DEPTH + BACK / 2.0, 180.0], [DOOR_X, 0.0, -DEPTH + BACK / 2.0, 180.0]]

    # The party walls, down to the cellar's floor.
    for sx in (-1.0, 1.0):
        x = sx * (WIDTH / 2.0 - PARTY / 2.0)
        shapes.append(ks.box(x, (EAVES - CELLAR) / 2.0, -DEPTH / 2.0, PARTY, EAVES + CELLAR, DEPTH, "granite"))
        cols.append(town.col(x, (EAVES - CELLAR) / 2.0, -DEPTH / 2.0, PARTY, EAVES + CELLAR, DEPTH))

    # The undercroft's door, barred, in the cellar's right wall.
    shapes += [ks.box(INNER / 2.0 - 0.02, -CELLAR + 1.1, -9.0, 0.06, 2.2, 1.2, "door_1"),
               ks.box(INNER / 2.0 - 0.06, -CELLAR + 1.2, -9.0, 0.05, 0.08, 1.4, "iron")]
    places["undercroft_door"] = [INNER / 2.0, -CELLAR, -9.0]

    # Floors: the cellar's, the tavern room's (a hole over the cellar
    # stair), the lodging floor's (a hole over the room's stair), a ceiling
    # over it; the storey over that sealed.
    room_z = (-DEPTH + BACK - FRONT) / 2.0
    room_d = DEPTH - FRONT - BACK
    cellar_stair = (-INNER / 2.0 + STAIR / 2.0, -12.0, 0.0)
    room_stair = (INNER / 2.0 - STAIR / 2.0, -FRONT - 0.4, 180.0)
    holes = {0.0: _hole(cellar_stair, CELLAR), SHOP: _hole(room_stair, SHOP)}

    for y, slot in ((-CELLAR, "flagstone"), (0.0, "boards"), (SHOP, "boards"), (SHOP + UPPER, "boards")):
        hole = holes.get(y)
        local = hole and (hole[0], hole[1] - room_z, hole[2], hole[3] - room_z)
        s, c = town.floors(INNER, room_d, [y], local, slot, "stone" if y < 0.0 else "wood")
        s, c = town.placed(s, c, z=room_z)
        shapes, cols = shapes + s, cols + c

    cols.append(town.col(0.0, (SHOP + UPPER + EAVES) / 2.0, room_z, INNER, EAVES - SHOP - UPPER, room_d))

    for (x, z, yaw), rise, base in ((cellar_stair, CELLAR, -CELLAR), (room_stair, SHOP, 0.0)):
        s, c = town.stair("straight", STAIR, rise, (x, base, z), yaw, "timber", "wood")
        shapes, cols = shapes + s, cols + c

    # The bar, three tables, their twelve seats.
    shapes.append(ks.box(0.6, 0.525, -5.0, 3.2, 1.05, 0.6, "timber"))
    cols.append(town.col(0.6, 0.525, -5.0, 3.2, 1.05, 0.6))
    places["bar"] = [0.6, 0.0, -5.5]
    seats = []

    for tx, tz in ((-0.5, -10.5), (1.2, -10.8), (-1.0, -2.5)):
        shapes.append(ks.box(tx, TABLE[1] / 2.0, tz, TABLE[0], TABLE[1], TABLE[2], "timber"))
        cols.append(town.col(tx, TABLE[1] / 2.0, tz, TABLE[0], TABLE[1], TABLE[2]))
        seats += [[tx + dx, 0.0, tz + dz] for dx, dz in ((0.75, 0.0), (-0.75, 0.0), (0.0, 0.75), (0.0, -0.75))]

    places["watchman_table"] = [-1.0, 0.0, -2.5]

    # The yard: its walls, its gate onto the back lane, the shed along its
    # right wall (its roof the way up to the back window).
    yard_z = -DEPTH - YARD / 2.0
    wall_h, wall_t = YARD_WALL
    s, c = _wall(WIDTH, 0.0, wall_h, wall_t, [town.Opening(0.0, 0.0, DOOR[0], DOOR[1], "door")], "whitewash",
                 (0.0, YARD_END + wall_t / 2.0, 180.0), inside=True, frames=False)
    shapes, cols = shapes + s, cols + c
    doors.append([0.0, 0.0, YARD_END + wall_t / 2.0, 180.0])

    for sx in (-1.0, 1.0):
        x = sx * (WIDTH / 2.0 - wall_t / 2.0)
        shapes.append(ks.box(x, wall_h / 2.0, yard_z, wall_t, wall_h, YARD - wall_t, "whitewash"))
        cols.append(town.col(x, wall_h / 2.0, yard_z, wall_t, wall_h, YARD - wall_t))

    s, c = town.floors(WIDTH - 2.0 * wall_t, YARD - wall_t, [0.0], None, "calcada", "stone")
    s, c = town.placed(s, c, z=yard_z + wall_t / 2.0)
    shapes, cols = shapes + s, cols + c
    shed_w, shed_y = SHED
    shed_x = WIDTH / 2.0 - wall_t - shed_w / 2.0
    shed_d = YARD - wall_t
    shapes.append(ks.box(shed_x, shed_y - 0.1, yard_z + wall_t / 2.0, shed_w, 0.2, shed_d, "roof_clay"))
    cols.append(town.col(shed_x, shed_y - 0.1, yard_z + wall_t / 2.0, shed_w, 0.2, shed_d))

    for pz in (-DEPTH - 0.6, YARD_END + wall_t + 0.3):
        shapes.append(ks.box(shed_x - shed_w / 2.0 + 0.1, (shed_y - 0.2) / 2.0, pz, 0.15, shed_y - 0.2, 0.15, "timber"))
        cols.append(town.col(shed_x - shed_w / 2.0 + 0.1, (shed_y - 0.2) / 2.0, pz, 0.15, shed_y - 0.2, 0.15))

    # The roof and its chimney's stack.
    rs, rc = town.roof("hipped", WIDTH, DEPTH, EAVES, 27.0, "granite")
    rs, rc = town.placed(rs, rc, z=-DEPTH / 2.0)
    shapes, cols = shapes + rs, cols + rc
    shapes.append(ks.box(-2.5, EAVES + 1.2, -10.0, 0.8, 2.4, 0.8, "granite"))
    cols.append(town.col(-2.5, EAVES + 1.2, -10.0, 0.8, 2.4, 0.8))

    # Its ways in, from outside to a place inside.
    # (Beside the bar's end: every way in reaches it round the bar.)
    room = [-1.6, 0.0, -6.5]
    lodging = [0.0, SHOP, -9.0]
    cx, cz, _yaw = cellar_stair
    ways = [
        {"kind": "door", "points": [[DOOR_X, 0.0, 1.0, "walk"], [DOOR_X, 0.0, -1.5, "walk"], room + ["walk"]]},
        {"kind": "yard", "points": [[0.0, 0.0, YARD_END - 1.0, "walk"], [0.0, 0.0, YARD_END + 2.0, "walk"], [DOOR_X, 0.0, -DEPTH - 1.0, "walk"],
                                    [DOOR_X, 0.0, -DEPTH + 1.2, "walk"], room + ["walk"]]},
        {"kind": "window", "points": [[WIDTH / 2.0 + 1.0, 0.0, -17.0, "walk"], [WIDTH / 2.0 - wall_t / 2.0, wall_h, -17.0, "hang"],
                                      [shed_x, shed_y, -17.0, "mantle"], [WINDOW_X, shed_y, -DEPTH - 0.6, "walk"],
                                      [WINDOW_X, SHOP + WINDOW[2], -DEPTH + BACK / 2.0, "mantle"], [WINDOW_X, SHOP, -DEPTH + 1.5, "drop"],
                                      lodging + ["walk"]]},
        {"kind": "below", "points": [[0.0, -CELLAR, -DEPTH - 1.5, "walk"], [0.0, -CELLAR, -DEPTH + 1.5, "walk"]]
         + town.stair_tour("straight", STAIR, CELLAR, (cx, -CELLAR, cz), 0.0) + [room + ["walk"]]},
    ]
    places["stream_door"] = [0.0, -CELLAR, -DEPTH]
    return {"shapes": shapes, "cols": cols, "size": [WIDTH, EAVES + 4.0, 2.0 * DEPTH + 2.0 * YARD], "doors": doors, "ways": ways,
            "entries": [w["kind"] for w in ways], "seats": seats, "places": places, "budget": BUDGET,
            "footprint": (-WIDTH / 2.0, YARD_END, WIDTH / 2.0, 0.0), "chimneys": [[-2.5, EAVES + 2.6, -10.0]]}


def _hole(stair, rise):
    """A straight stair's footprint (x0, z0, x1, z1) laid at (x, z, yaw)."""
    x, z, yaw = stair
    run = town.stair_reach("straight", STAIR, rise)["run"]
    return (x - STAIR / 2.0, z, x + STAIR / 2.0, z + run) if yaw == 0.0 else (x - STAIR / 2.0, z - run, x + STAIR / 2.0, z)


town.register("tavern", "town", "render_ochre", design())
