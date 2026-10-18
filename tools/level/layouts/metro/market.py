"""Layer 2, the corridors and the market (the Metro Underground spec, section
3.2): a stair down from the ticket hall into the Pasaje, a long pasillo
lined with puestos running south under 20 de Noviembre (floor -11), and
off it the herb market, the candle lane to the chapel, the tianguis lane to
the fondas, the rag lane to the storeroom, and at its south end the small
square where the bricked-up way to Pino Suárez is. Two lanes climb back up
into the south kiosk corridors, so the market loops back to the spine."""

from plan import rect

from metro.station import HALL

MARKET = -11.0


def lay(P):
    P.space("market_stairs", rect(-14, 14, -6, 34), floor=MARKET, height=HALL + 5.0 - MARKET, layer=2,
            openings=[{"to": "hall", "at": (-10, 14)}, {"to": "pasaje", "at": (-10, 34)}])
    P.route("market_stairs_flight", "stair", [(-10, HALL, 14.0), (-10, MARKET, 23.0)])
    P.space("pasaje", rect(-14, 34, -4, 150), floor=MARKET, height=4.5, layer=2,
            openings=[{"to": "market_stairs", "at": (-10, 34)}, {"to": "cistern_lane", "at": (-14, 43)},
                      {"to": "herb_market", "at": (-14, 74), "width": 4.0}, {"to": "candle_lane", "at": (-4, 74.5)},
                      {"to": "tianguis_lane", "at": (-4, 122.5)}, {"to": "rag_lane", "at": (-14, 140.5)},
                      {"to": "square_s", "at": (-9, 150), "width": 6.0}])

    # West: the lane down to the old cistern, the herb market and the lane
    # up to the south-west kiosk corridor.
    P.space("cistern_lane", rect(-20, 40, -14, 46), floor=MARKET, height=4.0, layer=2,
            openings=[{"to": "pasaje", "at": (-14, 43)}, {"to": "cistern", "at": (-20, 43)}])
    P.space("herb_market", rect(-44, 58, -14, 90), floor=MARKET, height=6.0, layer=2,
            openings=[{"to": "pasaje", "at": (-14, 74), "width": 4.0}, {"to": "lane_sw", "at": (-44, 62.5)}])
    P.space("lane_sw", rect(-87, 60, -44, 65), floor=MARKET, height=6.0, layer=2,
            openings=[{"to": "herb_market", "at": (-44, 62.5)}, {"to": "corridor_sw", "at": (-87, 62.5)}])
    P.route("lane_sw_flight", "stair", [(-87, HALL, 62.5), (-79, MARKET, 62.5)])

    # East: the candle lane to the chapel, on up to the south-east corridor.
    P.space("candle_lane", rect(-4, 72, 28, 77), floor=MARKET, height=3.5, layer=2,
            openings=[{"to": "pasaje", "at": (-4, 74.5)}, {"to": "chapel", "at": (28, 74.5)}])
    P.space("chapel", rect(28, 62, 44, 86), floor=MARKET, height=5.0, layer=2,
            openings=[{"to": "candle_lane", "at": (28, 74.5)}, {"to": "lane_se", "at": (44, 72.5)}])
    P.space("lane_se", rect(44, 70, 87, 75), floor=MARKET, height=6.0, layer=2,
            openings=[{"to": "chapel", "at": (44, 72.5)}, {"to": "corridor_se", "at": (87, 72.5)}])
    P.route("lane_se_flight", "stair", [(87, HALL, 72.5), (79, MARKET, 72.5)])

    # Further south: the fondas east, the storeroom west, the square.
    P.space("tianguis_lane", rect(-4, 120, 36, 125), floor=MARKET, height=3.5, layer=2,
            openings=[{"to": "pasaje", "at": (-4, 122.5)}, {"to": "fondas", "at": (36, 122.5)}])
    P.space("fondas", rect(36, 108, 62, 140), floor=MARKET, height=5.0, layer=2,
            openings=[{"to": "tianguis_lane", "at": (36, 122.5)}])
    P.space("rag_lane", rect(-48, 138, -14, 143), floor=MARKET, height=3.5, layer=2,
            openings=[{"to": "pasaje", "at": (-14, 140.5)}, {"to": "storeroom", "at": (-48, 140.5)}])
    P.space("storeroom", rect(-66, 128, -48, 156), floor=MARKET, height=7.0, layer=2,
            openings=[{"to": "rag_lane", "at": (-48, 140.5)}, {"to": "loft", "at": (-60, 156)}])
    P.space("square_s", rect(-24, 150, 6, 174), floor=MARKET, height=6.0, layer=2,
            openings=[{"to": "pasaje", "at": (-9, 150), "width": 6.0}])
