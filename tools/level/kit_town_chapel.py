"""The chapel (the old town's spec, sections 5.3 and 7.5): the upper town's
chapel, its belfry on its front's corner, its sacristy beside its altar end,
its silver altar walled up behind plaster (Porto's 1807 story: plan B1b
breaks it). Hand-made on kit_town's grammar; pure data, as kit_recipes
(which imports this at its end).

Its ways in, of three kinds:
    door    its nave's door
    window  off the lane onto the sacristy window's sill, down into the
            sacristy, through its door into the nave
    roof    off a neighbouring roof into the belfry's bell chamber, down its
            ladder, through its foot's door into the nave

The piece's frame: x along its front, its front's face at z 0, the nave to
-z, its foot on the square; the belfry outside its left wall, the sacristy
outside its right.
"""

import math

import kit_recipes as k  # noqa: F401 (first: it registers every kit)
import kit_shapes as ks
import kit_town as town

NAVE = (8.0, 16.0, 8.0)
WALL = 0.8
DOOR = (2.0, 3.5)
SIDE_DOOR = (1.0, 2.1)
BELFRY = (3.0, 14.0, 0.5)
CHAMBER = 10.5
BELL_OPENING = (1.0, 2.0)
SACRISTY = (4.0, 4.0, 4.0)
SACRISTY_WALL = 0.5
SACRISTY_WINDOW = (1.0, 1.2, 1.5)
PITCH = 30.0
BUDGET = 6000

HALF = NAVE[0] / 2.0
INNER = HALF - WALL


def design():
    width, depth, height = NAVE
    shapes, cols, doors, places = [], [], [], {}

    # The nave: its front with the door and a round window over it, its
    # walls (a door from the belfry's foot, one from the sacristy), its back
    # (the walled-up altar inside it).
    s, c = town.wall(width, height, WALL, [town.Opening(0.0, 0.0, DOOR[0], DOOR[1], "door")], "limewash", (0.0, -WALL / 2.0, 0.0))
    shapes, cols = shapes + s, cols + c
    shapes.append(ks.disc(0.0, 5.6, 0.02, 0.8, 12, "glass_dark"))
    doors.append([0.0, 0.0, -WALL / 2.0, 0.0])
    belfry_w, belfry_h, belfry_t = BELFRY
    bz = -belfry_w / 2.0
    # (The left wall, turned to face -x: its x runs to +z; the right, to -z.)
    s, c = town.wall(depth - 2.0 * WALL, height, WALL, [town.Opening(bz + depth / 2.0, 0.0, SIDE_DOOR[0], SIDE_DOOR[1], "door")], "limewash",
                     (-HALF + WALL / 2.0, -depth / 2.0, -90.0), frames=False)
    shapes, cols = shapes + s, cols + c
    sw, sd, sh = SACRISTY
    sz = -depth + sd / 2.0
    s, c = town.wall(depth - 2.0 * WALL, height, WALL, [town.Opening(-(sz + depth / 2.0), 0.0, SIDE_DOOR[0], SIDE_DOOR[1], "door")], "limewash",
                     (HALF - WALL / 2.0, -depth / 2.0, 90.0), frames=False)
    shapes, cols = shapes + s, cols + c
    doors += [[-HALF + WALL / 2.0, 0.0, bz, 90.0], [HALF - WALL / 2.0, 0.0, sz, 90.0]]
    s, c = town.wall(width, height, WALL, [], "limewash", (0.0, -depth + WALL / 2.0, 180.0), frames=False)
    shapes, cols = shapes + s, cols + c
    shapes += [ks.box(0.0, 1.6, -depth + WALL + 0.06, 2.6, 3.2, 0.12, "plaster"), ks.box(0.0, 0.5, -depth + WALL + 0.9, 2.2, 1.0, 1.0, "ashlar")]
    cols.append(town.col(0.0, 0.5, -depth + WALL + 0.9, 2.2, 1.0, 1.0))
    places["walled_altar"] = [0.0, 0.0, -depth + WALL + 0.1]
    s, c = town.floors(2.0 * INNER, depth - 2.0 * WALL, [0.0], None, "flagstone", "stone")
    s, c = town.placed(s, c, z=-depth / 2.0)
    shapes, cols = shapes + s, cols + c

    # Its roof, the ridge down the nave.
    rs, rc = town.roof("gable", depth, width, height, PITCH, "limewash")
    rs, rc = town.placed(rs, rc, 0.0, -depth / 2.0, 90.0)
    shapes, cols = shapes + rs, cols + rc

    # The belfry outside the left wall at the front: its walls, the bell
    # openings round its chamber, the chamber's floor (the ladder's hole),
    # the ladder down to its foot, its cap.
    bx = -HALF - belfry_w / 2.0
    openings = [town.Opening(0.0, CHAMBER, BELL_OPENING[0], BELL_OPENING[1], "window")]

    for face, place in (("front", (bx, -belfry_t / 2.0, 0.0)), ("back", (bx, -belfry_w + belfry_t / 2.0, 180.0)),
                        ("left", (bx - belfry_w / 2.0 + belfry_t / 2.0, bz, -90.0))):
        length = belfry_w if face != "left" else belfry_w - 2.0 * belfry_t
        s, c = town.band(length, 0.0, belfry_h, belfry_t, openings, "limewash", place, frames=False)
        shapes, cols = shapes + s, cols + c

    # (The chamber's floor, less the ladder's hole; the foot's.)
    hole = (bx, bz - 0.5, bx + 1.0, bz + 0.5)
    s, c = town.floors(belfry_w - belfry_t, belfry_w - 2.0 * belfry_t, [CHAMBER], (hole[0] - bx, hole[1] - bz, hole[2] - bx, hole[3] - bz),
                       "boards", "wood")
    s, c = town.placed(s, c, bx, bz)
    g, gc = town.floors(belfry_w - belfry_t, belfry_w - 2.0 * belfry_t, [0.0], None, "flagstone", "stone")
    g, gc = town.placed(g, gc, bx, bz)
    shapes, cols = shapes + s + g, cols + c + gc
    ladder = [bx + 0.5, (CHAMBER + 0.6) / 2.0, bz, 0.8, CHAMBER + 0.6, 0.8, 0.0]
    shapes.append(ks.box(bx + 0.5, CHAMBER / 2.0, bz - 0.45, 0.6, CHAMBER, 0.06, "timber"))
    cap = belfry_w / math.sqrt(2.0) + 0.2
    shapes += [ks.box(bx, belfry_h + 0.1, bz, belfry_w + 0.3, 0.2, belfry_w + 0.3, "granite"),
               ks.prism(bx, belfry_h + 1.3, bz, cap, 2.2, 4, "roof_spanish", 45.0, top=0.0),
               ks.lathe(bx - 0.4, CHAMBER + 1.9, bz, [[0.05, 0.6], [0.3, 0.45], [0.38, 0.0]], 8, "brass")]
    cols += [town.col(bx, belfry_h + 0.1, bz, belfry_w + 0.3, 0.2, belfry_w + 0.3), town.col(bx, belfry_h + 0.9, bz, 1.8, 1.4, 1.8)]
    places["bell"] = [bx - 0.4, CHAMBER + 1.3, bz]

    # The sacristy outside the right wall at the back: its walls (the
    # window in its outer one), its floor, its flat roof.
    ax = HALF + sw / 2.0
    s, c = town.band(sd, 0.0, sh, SACRISTY_WALL, [town.Opening(0.0, SACRISTY_WINDOW[2], SACRISTY_WINDOW[0], SACRISTY_WINDOW[1], "window")],
                     "limewash", (HALF + sw - SACRISTY_WALL / 2.0, sz, 90.0), frames=False)
    shapes, cols = shapes + s, cols + c

    for z in (sz + sd / 2.0 - SACRISTY_WALL / 2.0, sz - sd / 2.0 + SACRISTY_WALL / 2.0):
        shapes.append(ks.box(ax, sh / 2.0, z, sw, sh, SACRISTY_WALL, "limewash"))
        cols.append(town.col(ax, sh / 2.0, z, sw, sh, SACRISTY_WALL))

    g, gc = town.floors(sw - SACRISTY_WALL, sd - 2.0 * SACRISTY_WALL, [0.0], None, "flagstone", "stone")
    g, gc = town.placed(g, gc, ax - SACRISTY_WALL / 2.0, sz)
    shapes, cols = shapes + g, cols + gc
    shapes.append(ks.box(ax, sh + 0.1, sz, sw + 0.2, 0.2, sd + 0.2, "roof_clay"))
    cols.append(town.col(ax, sh + 0.1, sz, sw + 0.2, 0.2, sd + 0.2))

    # Its ways in.
    nave = [0.0, 0.0, -8.0]
    lane = HALF + sw + 1.5
    ways = [
        {"kind": "door", "points": [[0.0, 0.0, 1.0, "walk"], [0.0, 0.0, -2.0, "walk"], nave + ["walk"]]},
        {"kind": "window", "points": [[lane, 0.0, sz, "walk"], [HALF + sw - SACRISTY_WALL / 2.0, SACRISTY_WINDOW[2], sz, "mantle"],
                                      [ax - 0.3, 0.0, sz, "drop"], [HALF + 0.6, 0.0, sz, "walk"], [HALF - WALL - 0.8, 0.0, sz, "walk"],
                                      nave + ["walk"]]},
        {"kind": "roof", "points": [[bx - belfry_w / 2.0 - 1.5, height, bz, "walk"], [bx - belfry_w / 2.0 + belfry_t / 2.0, CHAMBER, bz, "hang"],
                                    [bx - 0.5, CHAMBER, bz, "walk"], [bx + 0.5, CHAMBER, bz + 0.9, "walk"], [bx + 0.5, 0.0, bz - 0.9, "climb"],
                                    [bx + 0.6, 0.0, bz, "walk"], [-HALF + WALL + 0.8, 0.0, bz, "walk"], nave + ["walk"]]},
    ]
    return {"shapes": shapes, "cols": cols, "size": [width + 2.0 * sw, belfry_h + 3.0, 2.0 * depth], "doors": doors, "ways": ways,
            "entries": [w["kind"] for w in ways], "places": places, "climbs": [ladder], "budget": BUDGET,
            "footprint": (-HALF - belfry_w, -depth, HALF + sw, 0.0)}


town.register("town_chapel", "town", "limewash", design())
