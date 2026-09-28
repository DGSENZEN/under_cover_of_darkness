"""A small level for the pipeline's and the loader's own tests: a yard of
cobbles with a wall, a doorway into a room of boards, a torch, a bench
station, a route, a guard, a zone, a hide spot, a vantage and a mark."""

import geo


def P(name, piece, at, yaw=0.0, sector="yard"):
    return {"name": name, "piece": piece, "sector": sector, "position": list(at), "basis": geo.rotation(yaw)}


def M(name, ucd, at, props=None, size=None, yaw=0.0, sector="yard"):
    return {"name": name, "ucd": ucd, "sector": sector, "position": list(at), "basis": geo.rotation(yaw),
            "size": size, "props": props or {}}


def layout():
    pieces = []

    for x in (-4, 0, 4):
        for z in (-4, 0, 4):
            pieces.append(P("yard_floor_%d_%d" % (x, z), "floor_cobble_4", (x, 0, z)))

    pieces.append(P("north_wall_a", "wall_ashlar_4", (-3, 0, -6.2)))
    pieces.append(P("north_wall_door", "wall_ashlar_door", (0, 0, -6.2)))
    pieces.append(P("north_wall_b", "wall_ashlar_4", (3, 0, -6.2)))

    for x in (-2, 2):
        pieces.append(P("room_floor_%d" % x, "floor_board_4", (x, 0, -8.6), sector="room"))

    pieces.append(P("room_back", "wall_plaster_4", (-2, 0, -10.8), sector="room"))
    pieces.append(P("room_back_b", "wall_plaster_4", (2, 0, -10.8), sector="room"))
    pieces.append(P("room_bench", "bench", (0, 0, -9.8), sector="room"))

    markers = [
        M("start", "spawn", (0, 0, 4)),
        M("door_room", "door", (0, 0, -6.2)),
        M("torch_door", "light", (1.0, 2.3, -5.8), {"kind": "torch"}),
        M("bench_seat", "station", (0, 0, -9.3), {"kind": "sit"}, yaw=180.0, sector="room"),
        M("yard_round", "route", (0, 0, 0)),
        M("yard_round_1", "waypoint", (-4, 0, 3), {"route": "yard_round", "order": 1}),
        M("yard_round_2", "waypoint", (4, 0, 3), {"route": "yard_round", "order": 2}),
        M("Hendrik", "guard", (-4, 0, 3), {"archetype": "watchman", "route": "yard_round"}),
        M("room_zone", "zone", (0, 1.5, -8.6), {"grade": "indoors", "fog": 1.5}, size=[8, 3, 4], sector="room"),
        M("behind_door", "hide", (-1.6, 0, -7.4), sector="room"),
        M("yard_high", "vantage", (5, 3.5, 5), {"lens": "long"}),
        M("well_spot", "mark", (3, 0, 0)),
        M("yard_area", "hunt_area", (0, 1.5, 0), {"label": "the yard"}, size=[12, 3, 12]),
    ]
    return {"level": "fixture", "pieces": pieces, "markers": markers}
