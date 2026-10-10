"""West of the plaza: the Portal de Mercaderes (the arcade bay run, 30 bays
of 4.5 m), Calle Madero leaving west from the north-west corner past the
Palacio de Iturbide, the Monte de Piedad facing the cathedral across its
street, and the streets that make the west's blocks."""

from plan import rect

BAY = 4.5
BAYS = 30


def lay(P):
    z0 = -100.0
    run = BAY * BAYS / 3

    for i in range(3):
        P.plot("portal_mercaderes_%d" % (i + 1), "arcade", rect(-140, z0 + i * run, -120, z0 + (i + 1) * run),
               storeys=2, height=13.0)

    P.ground("madero", "street", rect(-310, -125, -120, -110))
    P.ground("calle_isabel", "street", rect(-235, -110, -215, 160))
    P.ground("calle_16_sept", "street", rect(-310, 35, -120, 50))
    P.plot("iturbide", "iturbide", rect(-280, -160, -240, -125), storeys=3, height=16.0)
    P.plot("pawnshop", "pawnshop", rect(-120, -210, -90, -150), storeys=3, height=14.0, interior=True)
