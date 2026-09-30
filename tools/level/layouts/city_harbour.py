"""The harbour of the city on the rock (the city spec, section 6): its
ground, quays, the Ribeira, the Terreiro and the Sea Gate, the royal
shipyard and the customs house, the mole and the golden tower, the fort at
the harbour's mouth, the smugglers' cave, the ships, and what plays on them
(its guards, its ways in, its light). Each part in layouts/harbour/."""

from lay import Layout

from harbour import cave, fort, ground, markers, mole, quays, ribeira, ships, shipyard, terreiro

PARTS = [ground, quays, ribeira, terreiro, shipyard, mole, fort, cave, ships, markers]


def layout():
    L = Layout("city_harbour")

    for part in PARTS:
        part.lay(L)

    return L.data()
