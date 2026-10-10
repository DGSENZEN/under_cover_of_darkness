"""North of the plaza: the cathedral and the Sagrario behind their atrium,
the streets either side of them, the Templo Mayor dig north-east (four pits
round the deco tower that rises from it as its seventh shell), and Plaza de
Santo Domingo north-west: the church on its north, the evangelistas' arcade
on its west with the scribe's office, the Inquisition on its south-east
chamfered corner."""

from plan import rect


def lay(P):
    # The cathedral's block.
    P.ground("atrium", "atrium", rect(-70, -145, 40, -130))
    P.plot("cathedral", "cathedral", rect(-70, -265, 5, -145), storeys=1, height=30.0)
    P.plot("sagrario", "sagrario", rect(5, -215, 40, -145), storeys=1, height=22.0, roof=False)
    P.plot("cathedral_chapter", "house", rect(5, -265, 40, -215), storeys=3, height=13.0)
    P.ground("calle_monte_de_piedad", "street", rect(-90, -265, -70, -130))
    P.ground("calle_seminario", "street", rect(40, -265, 60, -130))
    P.ground("calle_guatemala", "street", rect(-120, -285, 310, -265))

    # The Templo Mayor: four pits 6 m down round the deco tower.
    for name, r in (("dig_n", rect(60, -225, 150, -200)), ("dig_s", rect(60, -170, 150, -145)),
                    ("dig_w", rect(60, -200, 90, -170)), ("dig_e", rect(120, -200, 150, -170))):
        P.ground(name, "dig", r, level=-6.0)

    P.plot("deco_tower", "deco_tower", rect(90, -200, 120, -170), storeys=18, height=72.0, base=-6.0, roof=False)
    P.ground("dig_walk", "street", rect(60, -145, 310, -130))
    P.route("dig_stair", "stair", [(60, 0, -160), (72, -6, -160)])

    # Plaza de Santo Domingo.
    P.ground("santo_domingo", "plaza", rect(-200, -290, -140, -210))
    P.ground("calle_brasil", "street", rect(-140, -310, -120, -110))
    P.ground("calle_cuba", "street", rect(-310, -325, -120, -305))
    P.ground("calle_chile", "street", rect(-235, -305, -215, -110))
    P.plot("santo_domingo_church", "church", rect(-195, -305, -145, -290), storeys=1, height=20.0, roof=False)
    P.plot("evangelistas_n", "evangelistas", rect(-215, -290, -200, -250), storeys=2, height=9.0)
    P.plot("scribe_office", "evangelistas", rect(-215, -250, -200, -235), storeys=2, height=9.0, interior=True)
    P.plot("evangelistas_s", "evangelistas", rect(-215, -235, -200, -210), storeys=2, height=9.0)
    # The Holy Office's corner, cut to face the plaza.
    P.plot("inquisition_rooms", "inquisition", [(-170, -210), (-146, -210), (-140, -204), (-140, -180), (-170, -180)],
           storeys=3, height=14.0, interior=True)
