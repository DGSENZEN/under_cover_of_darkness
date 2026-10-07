"""The watch house (the old town's spec, sections 5.3 and 7.1): the burned
church's convent made the watch's barracks, on the Carmo hill, its cloister
behind it against the ruin. Hand-made on kit_town's grammar; pure data, as
kit_recipes (which imports this at its end).

Its ways in, of three kinds:
    door  the barracks gate into the hall
    wall  from the ruin's side over the cloister's broken wall, across the
          cloister, through its door
    roof  off a neighbouring roof over the terrace's parapet, down the
          hatch's ladder into the barracks

Inside: the hall (the drum's place), the sergeant's office and the armoury
off a corridor to the cloister door, a stair up to the barracks (four beds:
the reserve asleep in B1b); on its flat roof the watch's lookout. The
piece's frame: x along its front, its front's face at z 0, the house to -z,
the cloister behind it to CLOISTER_END, its foot on the square.
"""

import kit_recipes as k  # noqa: F401 (first: it registers every kit)
import kit_shapes as ks
import kit_town as town

WIDTH = 20.0
DEPTH = 12.0
GROUND = 4.0
UPPER = 3.6
WALL = 0.6
GATE = (1.8, 3.0)
DOOR = (1.2, 2.2)
WINDOW = (1.0, 1.6, 1.0)
CLOISTER = 12.0
CLOISTER_WALL = (4.0, 0.6)
RUINED = 2.5
STAIR = 1.3
HATCH = (5.0, -3.0)
HATCH_HOLE = (1.6, 1.5)
LOOKOUT = (3.0, 2.6)
BUDGET = 9000

EAVES = GROUND + UPPER
INNER_X = WIDTH / 2.0 - WALL
CLOISTER_END = -DEPTH - CLOISTER


def design():
    shapes, cols = [], []
    doors, places = [], {}

    # The front: the gate, windows shut or lit up both floors.
    front = [town.Opening(0.0, 0.0, GATE[0], GATE[1], "door")]

    for x in (-7.0, -3.5, 3.5, 7.0):
        front += [town.Opening(x, WINDOW[2], WINDOW[0], WINDOW[1], "shut"), town.Opening(x, GROUND + WINDOW[2], WINDOW[0], WINDOW[1],
                                                                                         "lit" if x > 0 else "shut")]

    s, c = town.wall(WIDTH, EAVES, WALL, front, "limewash", (0.0, -WALL / 2.0, 0.0), inside=True)
    shapes, cols = shapes + s, cols + c
    doors.append([0.0, 0.0, -WALL / 2.0, 0.0])

    # The back onto the cloister: its door, windows over it.
    back = [town.Opening(0.0, 0.0, DOOR[0], DOOR[1], "door")] + [town.Opening(x, GROUND + WINDOW[2], WINDOW[0], WINDOW[1], "shut")
                                                                 for x in (-6.0, 6.0)]
    s, c = town.wall(WIDTH, EAVES, WALL, back, "limewash", (0.0, -DEPTH + WALL / 2.0, 180.0), inside=True, frames=False)
    shapes, cols = shapes + s, cols + c
    doors.append([0.0, 0.0, -DEPTH + WALL / 2.0, 180.0])

    for sx in (-1.0, 1.0):
        x = sx * (WIDTH / 2.0 - WALL / 2.0)
        shapes.append(ks.box(x, EAVES / 2.0, -DEPTH / 2.0, WALL, EAVES, DEPTH, "limewash"))
        cols.append(town.col(x, EAVES / 2.0, -DEPTH / 2.0, WALL, EAVES, DEPTH))

    # The ground floor: the hall, the corridor to the cloister door between
    # the office and the armoury.
    z0, z1 = -DEPTH + WALL, -WALL
    plan = [(-INNER_X, -6.0, INNER_X, z1), (-INNER_X, z0, -2.0, -6.0), (-2.0, z0, 2.0, -6.0), (2.0, z0, INNER_X, -6.0)]
    s, c = town.rooms(plan, 0.0, GROUND, [(0.0, -6.0), (-2.0, -9.0), (2.0, -9.0)], "limewash", "stone", 0.3)
    shapes, cols = shapes + s, cols + c
    places.update({"drum": [5.0, 0.0, -3.0], "office": [-6.0, 0.0, -9.0], "armoury": [6.0, 0.0, -9.0]})

    # Floors: the ground's, the barracks' (a hole over the stair), the roof
    # (a hole for the hatch).
    stair = (-INNER_X + STAIR, -5.0)
    reach = town.stair_reach("two_flight", STAIR, GROUND)
    f = reach["footprint"]
    stair_hole = (stair[0] + f[0], stair[1] + f[1], stair[0] + f[2], stair[1] + f[3])
    # (From its ladder's plank to past a man held on it: his body a metre
    # across goes through.)
    hatch_hole = (HATCH[0] - HATCH_HOLE[0] / 2.0, HATCH[1] - 0.42, HATCH[0] + HATCH_HOLE[0] / 2.0, HATCH[1] - 0.42 + HATCH_HOLE[1])
    middle = (z0 + z1) / 2.0

    for y, hole, slot in ((0.0, None, "flagstone"), (GROUND, stair_hole, "boards"), (EAVES, hatch_hole, "terracotta")):
        local = hole and (hole[0], hole[1] - middle, hole[2], hole[3] - middle)
        s, c = town.floors(2.0 * INNER_X, z1 - z0, [y], local, slot, "stone" if y != GROUND else "wood")
        s, c = town.placed(s, c, z=middle)
        shapes, cols = shapes + s, cols + c

    s, c = town.stair("two_flight", STAIR, GROUND, (stair[0], 0.0, stair[1]), 0.0, "flagstone", "stone")
    shapes, cols = shapes + s, cols + c

    # The barracks' four beds along its back wall.
    beds = []

    for x in (1.5, 3.5, 5.5, 7.5):
        shapes.append(ks.box(x, GROUND + 0.25, -10.0, 0.9, 0.5, 2.0, "boards"))
        cols.append(town.col(x, GROUND + 0.25, -10.0, 0.9, 0.5, 2.0))
        beds.append([x, GROUND, -10.0])

    # The roof: its terrace's parapet, the hatch's ladder, the lookout.
    for x, z, w, d in ((0.0, -0.125, WIDTH, 0.25), (0.0, -DEPTH + 0.125, WIDTH, 0.25), (-WIDTH / 2.0 + 0.125, -DEPTH / 2.0, 0.25, DEPTH),
                       (WIDTH / 2.0 - 0.125, -DEPTH / 2.0, 0.25, DEPTH)):
        shapes.append(ks.box(x, EAVES + town.PARAPET / 2.0, z, w, town.PARAPET, d, "limewash"))
        cols.append(town.col(x, EAVES + town.PARAPET / 2.0, z, w, town.PARAPET, d))

    climbs = [[HATCH[0], (GROUND + EAVES + 0.6) / 2.0, HATCH[1], 0.8, EAVES + 0.6 - GROUND, 0.8, 0.0]]
    shapes.append(ks.box(HATCH[0], (GROUND + EAVES) / 2.0, HATCH[1] - 0.45, 0.6, EAVES - GROUND, 0.06, "timber"))
    w, h = LOOKOUT
    lx, lz = -7.0, -3.0
    shapes += [ks.box(lx, EAVES + h + 0.1, lz, w + 0.3, 0.2, w + 0.3, "terracotta")]

    for sx in (-1.0, 1.0):
        for sz in (-1.0, 1.0):
            shapes.append(ks.box(lx + sx * (w / 2.0 - 0.15), EAVES + h / 2.0, lz + sz * (w / 2.0 - 0.15), 0.3, h, 0.3, "limewash"))
            cols.append(town.col(lx + sx * (w / 2.0 - 0.15), EAVES + h / 2.0, lz + sz * (w / 2.0 - 0.15), 0.3, h, 0.3))

    cols.append(town.col(lx, EAVES + h + 0.1, lz, w + 0.3, 0.2, w + 0.3))
    places["lookout"] = [lx, EAVES, lz]

    # The cloister: its side walls, its broken wall on the ruin's side, its
    # floor.
    mid = -DEPTH - CLOISTER / 2.0
    ch, ct = CLOISTER_WALL

    for sx in (-1.0, 1.0):
        x = sx * (WIDTH / 2.0 - ct / 2.0)
        shapes.append(ks.box(x, ch / 2.0, mid, ct, ch, CLOISTER, "ashlar"))
        cols.append(town.col(x, ch / 2.0, mid, ct, ch, CLOISTER))

    shapes.append(ks.box(0.0, RUINED / 2.0, CLOISTER_END + ct / 2.0, WIDTH - 2.0 * ct, RUINED, ct, "ashlar"))
    cols.append(town.col(0.0, RUINED / 2.0, CLOISTER_END + ct / 2.0, WIDTH - 2.0 * ct, RUINED, ct))
    s, c = town.floors(WIDTH - 2.0 * ct, CLOISTER - ct, [0.0], None, "flagstone", "stone")
    s, c = town.placed(s, c, z=mid + ct / 2.0)
    shapes, cols = shapes + s, cols + c
    places["cloister_door"] = [0.0, 0.0, -DEPTH]

    hall = [4.0, 0.0, -3.0]
    barracks = [4.0, GROUND, -7.0]
    ways = [
        {"kind": "door", "points": [[0.0, 0.0, 1.0, "walk"], [0.0, 0.0, -1.5, "walk"], hall + ["walk"]]},
        {"kind": "wall", "points": [[0.0, 0.0, CLOISTER_END - 1.0, "walk"], [0.0, RUINED, CLOISTER_END + ct / 2.0, "hang"],
                                    [0.0, 0.0, CLOISTER_END + 1.5, "drop"], [0.0, 0.0, -DEPTH - 1.0, "walk"], [0.0, 0.0, -DEPTH + 1.2, "walk"],
                                    [0.0, 0.0, -7.0, "walk"], [0.0, 0.0, -4.0, "walk"], hall + ["walk"]]},
        {"kind": "roof", "points": [[WIDTH / 2.0 + 1.5, EAVES, -8.0, "walk"], [WIDTH / 2.0 - 0.125, EAVES + town.PARAPET, -8.0, "mantle"],
                                    [WIDTH / 2.0 - 1.2, EAVES, -8.0, "drop"], [HATCH[0], EAVES, HATCH[1] - 0.8, "walk"],
                                    [HATCH[0], GROUND, HATCH[1] + 0.8, "climb"], barracks + ["walk"]]},
    ]
    return {"shapes": shapes, "cols": cols, "size": [WIDTH, EAVES + 3.0, 2.0 * (DEPTH + CLOISTER)], "doors": doors, "ways": ways,
            "entries": [w["kind"] for w in ways], "beds": beds, "places": places, "climbs": climbs, "budget": BUDGET,
            "footprint": (-WIDTH / 2.0, CLOISTER_END, WIDTH / 2.0, 0.0)}


town.register("watch_house", "town", "limewash", design())
