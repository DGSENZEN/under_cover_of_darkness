"""The Terreiro (after Lisbon's Praca do Comercio, about half its size): a
royal square on the water, calcada underfoot, arcaded west, north and east
in Lisbon's yellow; its water stair between two columns; the king on his
horse; the Sea Gate at its back through the city wall, between its drum
towers, its passage vaulted and murder-holed."""

from . import GATE_X, QUAY, TER_X, TER_Z, TOWERS_X, WALL_D, wall_run

ARCADE = 8.0
WEST = TER_X[0] + ARCADE / 2.0
EAST = -16.0
NORTH = TER_Z[0] + ARCADE / 2.0
# The north arcade's bays either side of the Sea Gate and its towers.
NORTH_BAYS = [-87.0, -81.0, -75.0, -69.0, -41.0, -35.0, -29.0, -23.0]
SIDE_BAYS = [-61.0 + 6.0 * i for i in range(10)]


def lay(L):
    L.floor(TER_X[0], -76.0, TER_X[1], -6.0, kind="calcada", y=QUAY, sector="terreiro")
    # (Out to the water stair's top, between its quays.)
    L.floor(-62.0, -6.0, -48.0, 0.0, kind="calcada", y=QUAY, sector="terreiro")

    for z in SIDE_BAYS:
        L.put("terreiro_bay_6", (WEST, QUAY, z), 90.0, "terreiro")
        L.put("terreiro_bay_6", (EAST, QUAY, z), -90.0, "terreiro")

    for x in NORTH_BAYS:
        L.put("terreiro_bay_6", (x, QUAY, NORTH), 0.0, "terreiro")

    L.put("terreiro_corner", (WEST, QUAY, NORTH), 0.0, "terreiro")
    L.put("terreiro_corner", (EAST, QUAY, NORTH), -90.0, "terreiro")

    # The Sea Gate: its front in the wall's line, its passage north through
    # the wall, its drum towers either side; the wall behind the square.
    L.put("gate_front", (GATE_X, QUAY, WALL_D - 0.3), 0.0, "terreiro")
    L.put("gate_passage_16", (GATE_X, QUAY, WALL_D - 1.8 - 8.0), 0.0, "terreiro")
    L.floor(GATE_X - 2.0, WALL_D - 17.8, GATE_X + 2.0, WALL_D - 1.8, kind="granite", y=QUAY, sector="terreiro")

    for x in TOWERS_X:
        L.put("tower_drum_8", (x, QUAY, WALL_D), 0.0, "terreiro")

    wall_run(L, (TER_X[0], WALL_D), (TOWERS_X[0] - 4.0, WALL_D), "terreiro")
    wall_run(L, (TOWERS_X[1] + 4.0, WALL_D), (15.2, WALL_D), "terreiro")
    # (Walled across at its city end: the old town beyond, sub-project 2.)
    L.put("wall_granite_4", (GATE_X, QUAY, WALL_D - 18.0), 0.0, "terreiro")

    # The water stair between its columns, the king facing the sea.
    L.put("water_stair_20", (GATE_X, 0.0, 2.55), 0.0, "terreiro")
    L.put("cais_colunas", (GATE_X, QUAY, -0.9), 0.0, "terreiro")
    L.put("statue_king", (GATE_X, QUAY, -34.0), 0.0, "terreiro")
