"""The ships in the harbour: the carrack alongside the sea wall's quay (its
main yard braced so its arm reaches over the wall's walk), a caravel at the
Ribeira, fishing boats along it, rowboats at the water stair, the fort,
the cave and the mole's seaward side (the thief's own)."""

import kit_ships

from . import CARRACK_X, CARRACK_Z, MAINYARD_Y

# The thief's rowboat, by the mole's seaward boulders: where the night
# begins.
START_BOAT = (178.0, 0.25, 120.0)
# (Moored bow in along the Ribeira, clear of its water stair at x -150..-154:
# a swimmer comes to its foot.)
BOATS = [((-160.0, 0.2, 4.0), 90.0), ((-145.5, 0.2, 3.6), 80.0), ((-140.0, 0.2, 4.2), 95.0), ((-106.0, 0.2, 3.8), 88.0)]
ROWBOATS = [((-62.0, 0.25, 8.0), 10.0), ((-49.0, 0.25, 8.5), -8.0), ((-82.0, 0.25, 223.0), 60.0), ((230.0, 0.25, 36.0), 90.0),
            (START_BOAT, 0.0), ((68.0, 0.25, 2.5), 90.0)]


def lay(L):
    L.ship("carrack_hull", (CARRACK_X, 0.0, CARRACK_Z), 0.0, "ships")
    L.ship("carrack_rig", (CARRACK_X, 0.0, CARRACK_Z), 0.0, "ships")
    L.put("carrack_mainyard", (CARRACK_X + kit_ships.MAIN_YARD_X, MAINYARD_Y, CARRACK_Z), 90.0, "ships")
    # Her brow from the quay's edge onto her waist (her deck's way ashore).
    L.put("carrack_brow", (CARRACK_X + kit_ships.BROW_X, 0.0, 0.0), 0.0, "ships")
    L.ship("caravel", (-120.0, 0.0, 5.5), 180.0, "ships")
    # Her great cabin, under her aftcastle (its frame hers): the captain's
    # box bed and his sea chest at its foot, his chair at the head of his
    # table and his instruments on his chart, a washstand, his swords and
    # his cloak on the bulkhead, a globe.
    for piece, (x, y, z), yaw in (("cot_box", (-13.9, 2.0, -2.62), 0.0), ("sea_chest", (-12.3, 2.0, -2.55), 0.0),
                                  ("armchair", (-13.2, 2.0, 0.0), 90.0), ("captains_instruments", (-12.0, 2.84, 0.0), 0.0),
                                  ("washstand", (-10.0, 2.0, -3.1), 0.0), ("sword_rack", (-6.13, 3.7, -2.4), -90.0),
                                  ("cloak_pegs", (-6.13, 4.1, 2.4), -90.0), ("globe_stand", (-8.5, 2.0, 2.5), 0.0)):
        L.put(piece, (CARRACK_X + x, y, CARRACK_Z + z), yaw, "ships")

    # Loose on his table and his washstand: his tankard and bottle, a plate,
    # a candlestick; a book on the deck by his bed.
    for piece, (x, y, z), kg in (("tankard", (-11.25, 2.84, 0.32), 0.6), ("bottle", (-11.25, 2.84, -0.3), 1.0), ("plate", (-12.75, 2.84, -0.32), 0.5),
                                 ("candlestick", (-9.8, 2.84, -3.0), 1.0), ("book", (-12.9, 2.0, -1.8), 1.0)):
        L.put(piece, (CARRACK_X + x, y, CARRACK_Z + z), 20.0, "ships", loose=kg)

    for at, yaw in BOATS:
        L.put("boat_fishing", at, yaw, "ships")

    for at, yaw in ROWBOATS:
        L.put("rowboat", at, yaw, "ships")
