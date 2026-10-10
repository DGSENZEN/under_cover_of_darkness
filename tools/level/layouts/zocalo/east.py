"""East of the plaza: the National Palace, a 205 m front 80 m deep round
its courtyard, entered by a gate passage from the east street."""

from plan import rect


def lay(P):
    for name, r in (("palace_front_n", rect(120, -105, 140, -5)), ("palace_front_s", rect(120, 5, 140, 105)),
                    ("palace_north", rect(140, -105, 180, -30)), ("palace_south", rect(140, 30, 180, 105)),
                    ("palace_back", rect(180, -105, 200, 105))):
        P.plot(name, "palace", r, storeys=3, height=16.0)

    P.ground("palace_gate", "courtyard", rect(120, -5, 140, 5))
    P.ground("palace_courtyard", "courtyard", rect(140, -30, 180, 30))
    P.ground("calle_correo_mayor", "street", rect(200, -285, 220, 160))
