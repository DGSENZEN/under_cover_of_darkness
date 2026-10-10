"""Line 2 under the plaza: four entrance kiosks, one near each corner, each
over a well whose stair goes down 8 m to corridors that reach the ticket
hall (60 x 30 m, floor -8); the platforms off its west and east ends
(floor -14); tunnels from the hall to the cathedral's crypt, from the crypt
to the Templo Mayor's nested shells and to the pawnshop's vault."""

from plan import rect

HALL_FLOOR = -8.0
CORRIDOR_HEIGHT = 3.5


def lay(P):
    P.space("station_hall", rect(-30, -15, 30, 15), floor=HALL_FLOOR, height=5.0,
            openings=[{"to": "corridor_nw_b", "at": (-27, -15)}, {"to": "corridor_ne_b", "at": (27, -15)},
                      {"to": "corridor_sw_b", "at": (-27, 15)}, {"to": "corridor_se_b", "at": (27, 15)},
                      {"to": "platform_w", "at": (-30, -6)}, {"to": "platform_e", "at": (30, -6)},
                      {"to": "crypt", "at": (0, -15)}])

    for sx, side in ((-1, "w"), (1, "e")):
        P.space("platform_" + side, rect(sx * 30, -10, sx * 130, -2), floor=-14.0, height=9.0,
                openings=[{"to": "station_hall", "at": (sx * 30, -6)}])
        P.route("platform_%s_stair" % side, "stair", [(sx * 30.2, HALL_FLOOR, -6), (sx * 45, -14.0, -6)])

    for corner, sx, sz in (("nw", -1, -1), ("ne", 1, -1), ("sw", -1, 1), ("se", 1, 1)):
        # The well under the kiosk, its stair down from the plaza.
        P.ground("well_" + corner, "well", rect(sx * 85, sz * 91, sx * 95, sz * 105), level=HALL_FLOOR)
        P.landmark("kiosk_" + corner, "metro_entrance", (sx * 90, sz * 98))
        P.route("kiosk_%s_stair" % corner, "stair", [(sx * 90, 0, sz * 105), (sx * 90, HALL_FLOOR, sz * 92)])
        # Along under the plaza, then across to the hall.
        a, b = "corridor_%s_a" % corner, "corridor_%s_b" % corner
        P.space(a, rect(sx * 25, sz * 96, sx * 85, sz * 100), floor=HALL_FLOOR, height=CORRIDOR_HEIGHT,
                openings=[{"to": "well_" + corner, "at": (sx * 85, sz * 98)}, {"to": b, "at": (sx * 27, sz * 96)}])
        P.space(b, rect(sx * 25, sz * 15, sx * 29, sz * 96), floor=HALL_FLOOR, height=CORRIDOR_HEIGHT,
                openings=[{"to": a, "at": (sx * 27, sz * 96)}, {"to": "station_hall", "at": (sx * 27, sz * 15)}])

    P.space("crypt", rect(-50, -250, 10, -160), floor=HALL_FLOOR, height=4.0,
            openings=[{"to": "station_hall", "at": (0, -160)}, {"to": "templo_shells", "at": (10, -200)},
                      {"to": "pawn_vault", "at": (-50, -180)}])
    P.space("templo_shells", rect(70, -215, 140, -155), floor=-14.0, height=6.0,
            openings=[{"to": "crypt", "at": (70, -200)}])
    P.space("pawn_vault", rect(-115, -205, -95, -155), floor=HALL_FLOOR, height=4.0, interior=True,
            openings=[{"to": "crypt", "at": (-95, -180)}])
    P.route("tunnel_hall_crypt", "tunnel", [(0, HALL_FLOOR, -15), (0, HALL_FLOOR, -160)], between=("station_hall", "crypt"))
    P.route("tunnel_crypt_shells", "tunnel", [(10, HALL_FLOOR, -200), (70, -14.0, -200)], between=("crypt", "templo_shells"))
    P.route("tunnel_crypt_vault", "tunnel", [(-50, HALL_FLOOR, -180), (-95, HALL_FLOOR, -180)], between=("crypt", "pawn_vault"))
