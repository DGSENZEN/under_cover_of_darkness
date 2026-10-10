"""South of the plaza: the town hall and its Portal de las Flores, split by
a passage; behind it the canal (the Acequia Real come back) between two
quays, with landings cut into the north quay and three bridges; beyond it
the market quarter: the iron-and-glass hall and rows of stalls on lanes."""

from plan import rect


def lay(P):
    P.plot("town_hall_w", "town_hall", rect(-100, 130, -5, 160), storeys=3, height=14.0)
    P.plot("town_hall_e", "town_hall", rect(5, 130, 100, 160), storeys=3, height=14.0)
    P.ground("calle_20_nov", "street", rect(-5, 130, 5, 160))
    P.route("town_hall_plank", "roof_link", [(-7, 14, 145), (7, 14, 145)])

    P.ground("quay_n", "street", rect(-310, 160, 310, 167))
    P.ground("canal", "canal", rect(-310, 167, 310, 179), level=-2.0)
    P.ground("quay_s", "street", rect(-310, 179, 310, 186))

    for name, x0 in (("landing_w", -60.0), ("landing_e", 45.0)):
        P.ground(name, "landing", rect(x0, 160, x0 + 15, 167), level=-1.0)
        P.route(name + "_stair", "stair", [(x0, 0, 163.5), (x0 + 9, -1, 163.5)])
        # Down off the landing on to the canal's floor.
        P.route(name + "_steps", "stair", [(x0 + 12, -1, 167), (x0 + 12, -2, 172)])

    # The canal's lower walkway (the spec's 3.3): along the canal's south
    # side under the quay and the market's edge, a step below the canal's
    # floor, opening on to the canal.
    P.space("canal_walkway", rect(-200, 179, 200, 190), floor=-2.5, height=2.4,
            openings=[{"to": "canal", "at": (-100, 179), "width": 4.0}, {"to": "canal", "at": (100, 179), "width": 4.0}])

    for i, x in enumerate((-150.0, 0.0, 150.0)):
        P.route("bridge_%d" % (i + 1), "bridge", [(x, 0, 162), (x, 0, 184)])

    # The market.
    P.ground("market_lanes_n", "market", rect(-310, 186, 310, 205))
    P.ground("market_lanes_s", "market", rect(-310, 280, 310, 300))
    P.ground("market_lane_w", "market", rect(-310, 240, -60, 250))
    P.ground("market_lane_e", "market", rect(60, 240, 310, 250))
    P.ground("market_lane_hall_w", "market", rect(-60, 205, -40, 280))
    P.ground("market_lane_hall_e", "market", rect(40, 205, 60, 280))
    P.plot("market_hall", "market_hall", rect(-40, 215, 40, 265), storeys=1, height=14.0)

    for side, (x0, x1) in (("w", (-300, -60)), ("e", (60, 300))):
        x = x0
        i = 0

        while x + 20 <= x1 + 1e-6:
            i += 1
            P.plot("stalls_%s%d_n" % (side, i), "stall", rect(x, 205, x + 20, 240), storeys=1, height=3.5, roof=False)
            P.plot("stalls_%s%d_s" % (side, i), "stall", rect(x, 250, x + 20, 280), storeys=1, height=3.5, roof=False)
            x += 24
