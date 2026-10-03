"""The harbour of the city on the rock (the city spec, section 6): its
ground, quays, the Ribeira, the Terreiro and the Sea Gate, the royal
shipyard and the customs house, the mole and the golden tower, the fort at
the harbour's mouth, the smugglers' cave, the ships, the coast's rock and
life, and what plays on them (its guards, its ways in, its light). Each
part in layouts/harbour/."""

from lay import Layout

from harbour import cave, coast, fort, ground, markers, mole, quays, ribeira, ships, shipyard, spit, terreiro

PARTS = [ground, quays, ribeira, terreiro, shipyard, mole, fort, spit, cave, ships, coast, markers]


# What lies loose wherever it is laid in the harbour (kg): picked up and
# thrown in the game (Layout.put loose=; laid with no weight by the parts).
LOOSE = {"crate": 14.0, "barrel": 26.0, "stool": 4.0, "basket_fish": 3.0, "lobster_pots": 5.0, "rope_coil": 8.0, "anchor_small": 22.0,
         "candle_stand": 5.0, "chest": 24.0, "armchair": 11.0, "globe_stand": 9.0, "sea_chest": 28.0, "bench_plain": 14.0, "bucket": 3.0,
         "coffer": 6.0}


def layout():
    L = Layout("city_harbour")

    for part in PARTS:
        part.lay(L)

    named = {m["props"]["piece"] for m in L.markers if m["ucd"] == "loose"}

    for p in list(L.pieces):
        if p["piece"] in LOOSE and p["name"] not in named:
            L.mark("%s_loose" % p["name"].replace(".", "_"), "loose", p["position"], 0.0, p["sector"], piece=p["name"], mass=LOOSE[p["piece"]])

    return L.data()
