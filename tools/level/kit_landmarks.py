"""The upper town's landmarks (the old town's spec, sections 4.3, 5.3, 7.3
and 16): the landmark tower-house, the walled garden house on the gorge
rim, the upper gate. Hand-made on kit_town's grammar; pure data, as
kit_recipes (which imports this at its end).

    landmark_tower  the district's landmark: a full tower-house (kit_tower,
                    8 m, nine storeys, about 30 m) walked to its top; in by
                    its door, its latrine chute, and a leap off a
                    neighbouring roof onto its balcony
    garden_house    on the gorge rim, its walled garden behind it, the
                    cistern under the garden; in by the garden's gate, over
                    its wall by the fig tree, and up from the cistern's
                    channel by the well; the gorge's corpse-lights come up
                    over its garden (places["wisps"], a box)
    upper_gate      a tower 22 m to its walk over the arch the way to the
                    cathedral goes through; passed over (off a roof onto its
                    walk, down through its rooms and the stair on its far
                    face) and under (along the cistern under it, up its
                    shaft) to the terrace beyond (places["beyond"]); its
                    gate (doors[0], 3.5 x 5) and its barred postern are plan
                    B1b's lock and key

Each piece's frame: x along its front, its front's face at z 0 (toward the
town), the building to -z, its foot on the street.
"""

import kit_recipes as k  # noqa: F401 (first: it registers every kit)
import kit_shapes as ks
import kit_terrace  # noqa: F401
import kit_tower
import kit_town as town

# The landmark tower: its balcony on its left face (the leap's) at storey 6.
LANDMARK = (8.0, 9)
LEAP_STOREY = 6
LEAP_GAP = 3.5
# (Its door clear of the flight up that storey's left wall.)
LEAP_ALONG = 2.0


def landmark():
    side, storeys = LANDMARK
    d = kit_tower.design(side, storeys, "full", "chute", enterable=True, balcony=("left", LEAP_STOREY, LEAP_ALONG), seed=7)
    levels = [s * kit_tower.STOREY for s in range(storeys)]
    edge = d["places"]["balcony"]
    y = levels[LEAP_STOREY]
    room = d["rooms_at"][LEAP_STOREY]
    ways = [
        {"kind": "door", "points": [[0.0, 0.0, 1.0, "walk"], [0.0, 0.0, -1.6, "walk"], d["rooms_at"][0] + ["walk"]]},
        {"kind": "below", "points": d["chute_tour"] + [d["rooms_at"][-1] + ["walk"]]},
        {"kind": "leap", "points": [[edge[0] - LEAP_GAP + 0.4, y, edge[2], "walk"], [edge[0] + 0.4, y, edge[2], "jump"],
                                    [-side / 2.0 - 0.3, y, edge[2], "walk"], [-side / 2.0 + kit_tower.WALL + 1.2, y, edge[2], "walk"],
                                    room + ["walk"]]},
    ]
    d.update({"ways": ways, "entries": [w["kind"] for w in ways], "footprint": (-side / 2.0 - 1.2, -side, side / 2.0 + 1.0, 0.0)})
    d["places"]["top_room"] = d["rooms_at"][-1]
    return d


# The garden house: its house HOUSE (width, depth, ground, upper), the
# garden behind it GARDEN deep and wide, walled GARDEN_WALL; the cistern
# under the garden (its walkway's floor CISTERN_FLOOR), the well's shaft
# up from it at SHAFT; the fig tree outside the right wall.
HOUSE = (8.0, 8.0, 3.8, 3.4)
GARDEN = (12.0, 14.0)
GARDEN_WALL = (3.0, 0.5)
CISTERN_FLOOR = -4.0
CISTERN = (3.0, 3.5)
SHAFT = (-1.9, -17.0)
GATE_Z = -14.0
FIG_Z = -16.0


def garden():
    hw, hd, ground, upper = HOUSE
    eaves = ground + upper
    gd, gw = GARDEN
    wall_h, wall_t = GARDEN_WALL
    shapes, cols, doors, places = [], [], [], {}
    end = -hd - gd

    # The house: its front on the street (its door barred), its back onto
    # the garden (the door live), its ground floor walked, sealed over it.
    front = [town.Opening(-1.5, 0.0, 1.2, 2.2, "barred"), town.Opening(1.8, 0.9, 1.2, 1.4, "shut"), town.Opening(-1.8, ground + 0.9, 1.2, 1.4, "lit"),
             town.Opening(1.8, ground + 0.9, 1.2, 1.4, "shut")]
    s, c = town.band(hw, 0.0, eaves, 0.6, front, "whitewash", (0.0, -0.3, 0.0), inside=False)
    shapes, cols = shapes + s, cols + c
    back = [town.Opening(-1.5, 0.0, 1.2, 2.2, "door"), town.Opening(1.8, ground + 0.9, 1.2, 1.4, "shut")]
    s, c = town.band(hw, 0.0, eaves, 0.5, back, "whitewash", (0.0, -hd + 0.25, 180.0), frames=False)
    shapes, cols = shapes + s, cols + c
    doors.append([1.5, 0.0, -hd + 0.25, 180.0])

    for sx in (-1.0, 1.0):
        shapes.append(ks.box(sx * (hw / 2.0 - 0.25), eaves / 2.0, -hd / 2.0, 0.5, eaves, hd, "whitewash"))
        cols.append(town.col(sx * (hw / 2.0 - 0.25), eaves / 2.0, -hd / 2.0, 0.5, eaves, hd))

    inner_w, inner_d = hw - 1.0, hd - 1.1
    s, c = town.floors(inner_w, inner_d, [0.0, ground], None, "flagstone", "stone")
    s, c = town.placed(s, c, z=-hd / 2.0 - 0.05)
    shapes, cols = shapes + s, cols + c
    cols.append(town.col(0.0, (ground + eaves) / 2.0, -hd / 2.0 - 0.05, inner_w, upper, inner_d))
    rs, rc = town.roof("hipped", hw, hd, eaves, 27.0, "whitewash")
    rs, rc = town.placed(rs, rc, z=-hd / 2.0)
    shapes, cols = shapes + rs, cols + rc

    # The garden: its walls (the gate in the left one, the back on the
    # gorge's rim), its floor (the well's shaft through it), the well-head.
    mid = -hd - gd / 2.0
    s, c = town.band(gd, 0.0, wall_h, wall_t, [town.Opening(GATE_Z - mid, 0.0, 1.2, 2.2, "door")], "whitewash",
                     (-gw / 2.0 + wall_t / 2.0, mid, -90.0), frames=False)
    shapes, cols = shapes + s, cols + c
    doors.append([-gw / 2.0 + wall_t / 2.0, 0.0, GATE_Z, 90.0])

    for x, z, w, d in ((gw / 2.0 - wall_t / 2.0, mid, wall_t, gd), (0.0, end + wall_t / 2.0, gw, wall_t)):
        shapes.append(ks.box(x, wall_h / 2.0, z, w, wall_h, d, "whitewash"))
        cols.append(town.col(x, wall_h / 2.0, z, w, wall_h, d))

    for x0, x1 in ((-gw / 2.0, -hw / 2.0), (hw / 2.0, gw / 2.0)):
        # (Beside the house, the garden's walls close to it.)
        shapes.append(ks.box((x0 + x1) / 2.0, wall_h / 2.0, -hd + wall_t / 2.0, x1 - x0, wall_h, wall_t, "whitewash"))
        cols.append(town.col((x0 + x1) / 2.0, wall_h / 2.0, -hd + wall_t / 2.0, x1 - x0, wall_h, wall_t))

    sx, sz = SHAFT
    hole = (sx - 0.5, sz - 0.5, sx + 0.5, sz + 0.5)
    s, c = town.floors(gw - 2.0 * wall_t, gd - wall_t, [0.0], (hole[0], hole[1] - (mid - wall_t / 2.0), hole[2], hole[3] - (mid - wall_t / 2.0)),
                       "calcada", "stone")
    s, c = town.placed(s, c, z=mid - wall_t / 2.0)
    shapes, cols = shapes + s, cols + c

    for x, z, w, d in ((sx, sz + 0.6, 1.4, 0.2), (sx, sz - 0.6, 1.4, 0.2), (sx - 0.6, sz, 0.2, 1.0), (sx + 0.6, sz, 0.2, 1.0)):
        shapes.append(ks.box(x, 0.45, z, w, 0.9, d, "granite"))
        cols.append(town.col(x, 0.45, z, w, 0.9, d))

    # The cistern under the garden: its walkway along its channel, its
    # walls, its roof the garden's floor; the well's ladder up its shaft.
    cw, ch = CISTERN
    cx = sx - (cw / 2.0 - 0.4)
    run_z0, run_z1 = -hd - 0.5, end + 0.5
    middle_z = (run_z0 + run_z1) / 2.0
    length = run_z0 - run_z1

    for box, slot in (((sx, CISTERN_FLOOR - 0.15, middle_z, 0.8, 0.3, length), "flagstone"),
                      ((cx - 0.4, CISTERN_FLOOR - 0.95, middle_z, cw - 0.8, 0.3, length), "stone_moss"),
                      ((cx - cw / 2.0 - 0.2, CISTERN_FLOOR + ch / 2.0 - 0.4, middle_z, 0.4, ch + 0.8, length), "stone_moss"),
                      ((cx + cw / 2.0 + 0.2, CISTERN_FLOOR + ch / 2.0 - 0.4, middle_z, 0.4, ch + 0.8, length), "stone_moss")):
        shapes.append(ks.box(*box, slot))
        cols.append(town.col(*box))

    climbs = [[sx, (CISTERN_FLOOR + 1.2) / 2.0, sz, 0.8, 1.2 - CISTERN_FLOOR, 0.8, 0.0]]
    shapes.append(ks.box(sx, (CISTERN_FLOOR + 0.9) / 2.0, sz - 0.45, 0.6, 0.9 - CISTERN_FLOOR, 0.06, "timber"))
    places["cistern"] = [sx, CISTERN_FLOOR, run_z1]

    # The fig tree outside the right wall: its trunk, its low branch (a
    # step up to the wall), its crown.
    fx = gw / 2.0 + 0.8
    shapes += [ks.prism(fx + 0.3, 1.2, FIG_Z, 0.18, 2.4, 6, "bark"), ks.box(fx, 1.5, FIG_Z, 1.0, 0.2, 1.2, "bark"),
               ks.card(fx, 3.4, FIG_Z, 3.0, 2.4, "orange_leaves"), ks.card(fx, 3.4, FIG_Z, 3.0, 2.4, "orange_leaves", 90.0)]
    cols += [town.col(fx, 1.5, FIG_Z, 1.0, 0.2, 1.2), town.col(fx + 0.3, 0.7, FIG_Z, 0.36, 1.4, 0.36)]
    places["fig"] = [fx, 1.6, FIG_Z]
    places["wisps"] = [0.0, 3.0, mid, gw - 2.0, 5.0, gd - 2.0]

    inside = [0.0, 0.0, -4.0]
    to_house = [[1.5, 0.0, -hd - 1.5, "walk"], [1.5, 0.0, -hd + 1.5, "walk"], inside + ["walk"]]
    ways = [
        {"kind": "door", "points": [[-gw / 2.0 - 1.5, 0.0, GATE_Z, "walk"], [-gw / 2.0 + 1.5, 0.0, GATE_Z, "walk"]] + to_house},
        {"kind": "wall", "points": [[gw / 2.0 + 2.4, 0.0, FIG_Z, "walk"], [fx - 0.2, 1.6, FIG_Z, "mantle"],
                                    [gw / 2.0 - wall_t / 2.0, wall_h, FIG_Z, "mantle"], [gw / 2.0 - 1.5, 0.0, FIG_Z, "drop"]] + to_house},
        {"kind": "below", "points": [[sx, CISTERN_FLOOR, -hd - 1.5, "walk"], [sx, CISTERN_FLOOR, sz + 0.4, "walk"],
                                     [sx, 0.0, sz - 0.9, "climb"], [sx + 1.2, 0.0, sz - 0.9, "walk"]] + to_house},
    ]
    return {"shapes": shapes, "cols": cols, "size": [gw + 3.0, eaves + 4.0, 2.0 * (hd + gd)], "doors": doors, "ways": ways,
            "entries": [w["kind"] for w in ways], "places": places, "climbs": climbs, "budget": 6000,
            "footprint": (-gw / 2.0, end, gw / 2.0 + 1.4, 0.0)}


# The upper gate: its tower GATE_TOWER (side, walk, wall), its passage
# PASSAGE (width, height), its floors over the passage, its stairs, the
# stair down its far face, the terrace beyond, the cistern under it.
GATE_TOWER = (10.0, 22.0, 1.5)
PASSAGE = (3.5, 5.0)
GATE_FLOORS = (7.0, 12.0, 17.0, 22.0)
GATE_STAIR = (1.0, -2.5, -6.0)
FAR_STAIR = (1.2, -4.75)
BEYOND = 6.0


def upper_gate():
    side, walk, wt = GATE_TOWER
    pw, ph = PASSAGE
    shapes, cols, doors, places = [], [], [], {}
    half = side / 2.0
    inner = half - wt
    vault_top = GATE_FLOORS[0] - 0.5

    # Its lower block: the masses either side of the passage, the vault
    # over it; its upper storeys' walls (the far one's door onto the stair
    # down its face), the postern barred on its front.
    for sx in (-1.0, 1.0):
        x = sx * (pw / 2.0 + (half - pw / 2.0) / 2.0)
        shapes.append(ks.box(x, vault_top / 2.0, -half, half - pw / 2.0, vault_top, side, "granite_rough"))
        cols.append(town.col(x, vault_top / 2.0, -half, half - pw / 2.0, vault_top, side))

    shapes += [ks.box(0.0, (ph + vault_top) / 2.0, -half, pw, vault_top - ph, side, "granite_rough"),
               ks.box(-3.5, 1.1, 0.03, 1.2, 2.2, 0.06, "door_1"), ks.box(-3.5, 1.2, 0.08, 1.4, 0.08, 0.05, "iron")]
    cols.append(town.col(0.0, (ph + vault_top) / 2.0, -half, pw, vault_top - ph, side))
    places["postern"] = [-3.5, 0.0, 0.0]
    shapes += [ks.box(0.0, 0.0 - 0.1, -half, pw, 0.2, side, "calcada")]
    cols.append(town.col(0.0, -0.1, -half, pw, 0.2, side))
    doors.append([0.0, 0.0, -half, 0.0, pw, ph])
    places["gate_door"] = [0.0, 0.0, -half]

    far_door = 3.0
    faces = (("front", side, (0.0, -wt / 2.0, 0.0), []), ("back", side, (0.0, -side + wt / 2.0, 180.0),
                                                          [town.Opening(-far_door, GATE_FLOORS[0], 1.0, 2.1, "door")]),
             ("left", side - 2.0 * wt, (-half + wt / 2.0, -half, -90.0), []), ("right", side - 2.0 * wt, (half - wt / 2.0, -half, 90.0), []))

    for _face, length, place, openings in faces:
        s, c = town.band(length, vault_top, walk, wt, openings + [town.Opening(0.0, f + 1.2, 0.5, 1.4, "shut") for f in GATE_FLOORS[1:3]],
                         "granite", place, frames=False)
        shapes, cols = shapes + s, cols + c

    doors.append([far_door, GATE_FLOORS[0], -side + wt / 2.0, 180.0])

    # Its floors (holes over the flights), its stairs stacked (two flights a
    # storey, open treads), its walk and crenels.
    sw, sx0, sz0 = GATE_STAIR
    rises = [GATE_FLOORS[i + 1] - GATE_FLOORS[i] for i in range(len(GATE_FLOORS) - 1)]
    f = town.stair_reach("two_flight", sw, rises[0], kit_tower.RISER, kit_tower.TREAD)["footprint"]
    hole = (sx0 + f[0], sz0 + f[1], sx0 + f[2], sz0 + f[3])

    for i, y in enumerate(GATE_FLOORS):
        h = hole if i >= 1 else None
        s, c = town.floors(2.0 * inner, 2.0 * inner, [y], h and (h[0], h[1] + half, h[2], h[3] + half), "flagstone" if i < 3 else "granite", "stone")
        s, c = town.placed(s, c, z=-half)
        shapes, cols = shapes + s, cols + c

    tours = []

    for i, rise in enumerate(rises):
        s, c = town.stair("two_flight", sw, rise, (sx0, GATE_FLOORS[i], sz0), 0.0, "granite", "stone", False, kit_tower.RISER, kit_tower.TREAD)
        shapes, cols = shapes + s, cols + c
        tours.append(town.stair_tour("two_flight", sw, rise, (sx0, GATE_FLOORS[i], sz0), 0.0, kit_tower.RISER, kit_tower.TREAD))

    # (The walk's parapet: a base all round, merlons with a crenel in the
    # middle of the front for the way over.)
    base, merlon = kit_tower.BASE, kit_tower.MERLON
    for x, z, w, d in ((0.0, -0.25, side, 0.5), (0.0, -side + 0.25, side, 0.5), (-half + 0.25, -half, 0.5, side - 1.0), (half - 0.25, -half, 0.5, side - 1.0)):
        shapes.append(ks.box(x, walk + base / 2.0, z, w, base, d, "granite"))
        cols.append(town.col(x, walk + base / 2.0, z, w, base, d))

    for x in (-4.2, -2.6, 2.6, 4.2):
        for z in (-0.25, -side + 0.25):
            shapes.append(ks.box(x, walk + base + merlon[1] / 2.0, z, merlon[0], merlon[1], 0.5, "granite"))
            cols.append(town.col(x, walk + base + merlon[1] / 2.0, z, merlon[0], merlon[1], 0.5))

    places["walk"] = [0.0, walk, -half]
    places["balefire_target"] = [0.0, walk, -half]

    # The stair down its far face from its first floor's door, its landing,
    # the terrace beyond (the shaft's hole in it).
    fw, fx0 = FAR_STAIR
    fz = -side - fw / 2.0 - 0.1
    s, c = town.stair("straight", fw, GATE_FLOORS[0], (fx0, 0.0, fz), 90.0, "granite", "stone", True, kit_tower.RISER, kit_tower.TREAD)
    shapes, cols = shapes + s, cols + c
    far_tour = town.stair_tour("straight", fw, GATE_FLOORS[0], (fx0, 0.0, fz), 90.0, kit_tower.RISER, kit_tower.TREAD)
    land = (far_door - 0.7, -side - fw - 0.1, far_door + 0.8, -side)
    shapes.append(ks.box((land[0] + land[2]) / 2.0, GATE_FLOORS[0] - 0.1, (land[1] + land[3]) / 2.0, land[2] - land[0], 0.2, land[3] - land[1], "granite"))
    cols.append(town.col((land[0] + land[2]) / 2.0, GATE_FLOORS[0] / 2.0, (land[1] + land[3]) / 2.0, land[2] - land[0], GATE_FLOORS[0], land[3] - land[1]))
    shaft = (1.1, -side - 3.0)
    beyond_z = -side - BEYOND / 2.0
    s, c = town.floors(side + 2.0, BEYOND, [0.0], (shaft[0] - 0.5, shaft[1] - 0.5 - beyond_z, shaft[0] + 0.5, shaft[1] + 0.5 - beyond_z),
                       "calcada", "stone")
    s, c = town.placed(s, c, z=beyond_z)
    shapes, cols = shapes + s, cols + c
    places["beyond"] = [0.0, 0.0, -side - BEYOND + 1.5]

    # The cistern under it from the town's side to the shaft beyond: its
    # walkway, channel, walls; its roof the passage's floor and the
    # terrace's; the shaft's ladder up.
    cw, ch = CISTERN
    run_z0, run_z1 = 3.0, -side - BEYOND + 0.5
    mz, length = (run_z0 + run_z1) / 2.0, run_z0 - run_z1
    cx = shaft[0] - (cw / 2.0 - 0.4)

    for box, slot in (((shaft[0], CISTERN_FLOOR - 0.15, mz, 0.8, 0.3, length), "flagstone"),
                      ((cx - 0.4, CISTERN_FLOOR - 0.95, mz, cw - 0.8, 0.3, length), "stone_moss"),
                      ((cx - cw / 2.0 - 0.2, CISTERN_FLOOR + ch / 2.0 - 0.4, mz, 0.4, ch + 0.8, length), "stone_moss"),
                      ((cx + cw / 2.0 + 0.2, CISTERN_FLOOR + ch / 2.0 - 0.4, mz, 0.4, ch + 0.8, length), "stone_moss")):
        shapes.append(ks.box(*box, slot))
        cols.append(town.col(*box))

    climbs = [[shaft[0], (CISTERN_FLOOR + 1.2) / 2.0, shaft[1], 0.8, 1.2 - CISTERN_FLOOR, 0.8, 0.0]]
    shapes.append(ks.box(shaft[0], (CISTERN_FLOOR + 0.9) / 2.0, shaft[1] - 0.45, 0.6, 0.9 - CISTERN_FLOOR, 0.06, "timber"))
    places["cistern"] = [shaft[0], CISTERN_FLOOR, run_z0]

    # Its two ways: over, off a roof on the town's side onto its walk
    # through the front's crenel, down its storeys, out its far door and
    # down its face; under, along the cistern and up the shaft.
    down = []

    for tour in reversed(tours):
        down += town.reverse_tour(tour)

    over = [[0.0, walk + 1.1, 3.0, "walk"], [0.0, walk + base, -0.25, "jump"], [0.0, walk, -1.5, "drop"]] + down + [[far_door, GATE_FLOORS[0], -side + 2.6, "walk"], [far_door, GATE_FLOORS[0], -side - 0.6, "walk"]]
    over += town.reverse_tour(far_tour)[1:] + [places["beyond"] + ["walk"]]
    under = [[shaft[0], CISTERN_FLOOR, 2.0, "walk"], [shaft[0], CISTERN_FLOOR, shaft[1] + 0.4, "walk"], [shaft[0], 0.0, shaft[1] - 0.9, "climb"],
             places["beyond"] + ["walk"]]
    ways = [{"kind": "roof", "points": over}, {"kind": "below", "points": under}]
    return {"shapes": shapes, "cols": cols, "size": [side + 2.0, walk + 3.0, 2.0 * (side + BEYOND)], "doors": doors, "ways": ways,
            "entries": [w["kind"] for w in ways], "places": places, "climbs": climbs, "budget": 9000,
            "footprint": (-half - 1.0, -side - BEYOND, half + 1.0, 0.0)}


town.register("landmark_tower", "town", "granite", landmark())
town.register("garden_house", "town", "whitewash", garden())
town.register("upper_gate", "town", "granite", upper_gate())
