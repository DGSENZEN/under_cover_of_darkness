"""The ships in the harbour: the carrack alongside the sea wall's quay (its
main yard braced so its arm reaches over the wall's walk), a caravel at the
Ribeira, fishing boats along it, rowboats at the water stair, the fort,
the cave and the mole's seaward side (the thief's own)."""

import kit_ships

from . import CARRACK_X, CARRACK_Z, MAINYARD_Y

# The thief's rowboat, by the mole's seaward boulders: where the night
# begins.
START_BOAT = (176.0, 0.25, 120.0)
BOATS = [((-160.0, 0.2, 4.0), 90.0), ((-150.0, 0.2, 3.6), 80.0), ((-140.0, 0.2, 4.2), 95.0), ((-106.0, 0.2, 3.8), 88.0)]
ROWBOATS = [((-62.0, 0.25, 8.0), 10.0), ((-49.0, 0.25, 8.5), -8.0), ((-82.0, 0.25, 223.0), 60.0), ((230.0, 0.25, 36.0), 90.0),
            (START_BOAT, 0.0), ((68.0, 0.25, 2.5), 90.0)]


def lay(L):
    L.ship("carrack_hull", (CARRACK_X, 0.0, CARRACK_Z), 0.0, "ships")
    L.ship("carrack_rig", (CARRACK_X, 0.0, CARRACK_Z), 0.0, "ships")
    L.put("carrack_mainyard", (CARRACK_X, MAINYARD_Y, CARRACK_Z), 90.0, "ships")
    # Her brow from the quay's edge onto her waist (her deck's way ashore).
    L.put("carrack_brow", (CARRACK_X + kit_ships.BROW_X, 0.0, 0.0), 0.0, "ships")
    L.ship("caravel", (-120.0, 0.0, 5.5), 180.0, "ships")

    for at, yaw in BOATS:
        L.put("boat_fishing", at, yaw, "ships")

    for at, yaw in ROWBOATS:
        L.put("rowboat", at, yaw, "ships")
