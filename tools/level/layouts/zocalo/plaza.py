"""The plaza (200 x 220 m) and the 20 m ring street round it that carries
the tram loop; the player arrives on the south ring."""

from plan import rect

PLAZA = rect(-100, -110, 100, 110)


def lay(P):
    P.ground("plaza", "plaza", PLAZA)
    P.ground("north_street", "street", rect(-120, -130, 120, -110))
    P.ground("south_street", "street", rect(-120, 110, 120, 130))
    P.ground("west_street", "street", rect(-120, -110, -100, 110))
    P.ground("east_street", "street", rect(100, -110, 120, 110))
    # The tram runs the ring's middle.
    P.tram([(-110, -120), (110, -120), (110, 120), (-110, 120)])
    P.landmark("tram_stop_south", "tram_stop", (0, 120))
    P.landmark("spawn", "spawn", (0, 120))
