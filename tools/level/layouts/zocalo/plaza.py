"""The plaza (200 x 220 m) and the 20 m ring street round it that carries
the tram loop; the player arrives on the south ring."""

from plan import rect

PLAZA = rect(-100, -110, 100, 110)


def lay(P):
    # A pavement 0.2 up, its kerbs 0.2 proud of the ring's setts (the street
    # and canal kit's card).
    P.ground("plaza", "plaza", PLAZA, level=0.2)
    P.ground("north_street", "street", rect(-120, -130, 120, -110))
    P.ground("south_street", "street", rect(-120, 110, 120, 130))
    P.ground("west_street", "street", rect(-120, -110, -100, 110))
    P.ground("east_street", "street", rect(100, -110, 120, 110))
    # The tram runs the ring's middle; its east and west runs a metre out, so
    # each straight between radius-12 curves is whole 4.5 m track pieces.
    P.tram([(-111, -120), (111, -120), (111, 120), (-111, 120)])
    # The Iztapalapa causeway's line, up Calle 20 de Noviembre to the station.
    P.causeway([(0, 160), (0, 0)])
    P.landmark("tram_stop_south", "tram_stop", (0, 120))
    P.landmark("spawn", "spawn", (0, 120))
