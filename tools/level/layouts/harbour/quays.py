"""The quays: granite along the Ribeira (and out under the Guindais stair's
foot), the Terreiro's edge either side of its water stair, before the
customs house and the shipyard's sea wall (broken by the channel to the
Nasrid gate), round the mole's root; their steps down to the sea and their
bollards."""

from . import CAUSEWAY, MOLE_X, QUAY

# Where the quays run (x from, to, sector), and the gaps in them (the water
# stair, the channel to the Nasrid gate) filled to their edges by 4 m blocks.
RUNS = [(-186.0, -98.0, "ribeira"), (-98.0, -66.0, "terreiro"), (-44.0, -12.0, "terreiro"), (-12.0, 66.0, "shipyard"), (76.0, 180.0, "mole")]
STEPS = [(-150.0, "ribeira"), (20.0, "shipyard"), (110.0, "shipyard")]


def sector_of(x):
    return next((sector for x0, x1, sector in RUNS if x0 <= x < x1), "shipyard")


def lay(L):
    for x0, x1, sector in RUNS:
        x = x0

        while x < x1 - 1e-6:
            size = 8 if x1 - x >= 8.0 - 1e-6 else 4
            L.put("quay_%d" % size, (x + size / 2.0, 0.0, -3.0), 0.0, sector)
            x += size

    # (The water stair's quays, 2 m into its sides.)
    for x in (-64.0, -46.0):
        L.put("quay_4", (x, 0.0, -3.0), 0.0, "terreiro")

    for x, sector in STEPS:
        L.put("quay_steps_8", (x, 0.0, 0.8), 0.0, sector)

    # Loose along the quays: buckets and crates left by the boats.
    for piece, (x, z), yaw, kg in (("bucket", (-141.5, -4.6), 0.0, 3.0), ("crate", (-125.0, -5.0), 15.0, 14.0), ("bucket", (-57.5, -2.0), 0.0, 3.0),
                                   ("crate", (-36.0, -4.8), -10.0, 14.0), ("bucket", (36.5, -4.4), 0.0, 3.0), ("crate", (92.0, -4.9), 30.0, 14.0)):
        L.put(piece, (x, QUAY, z), yaw, sector_of(x), loose=kg)

    for x0, x1, sector in RUNS:
        x = x0 + 4.0

        while x < x1 - 2.0:
            # (Not on the steps down to the sea, nor the mole's up.)
            if all(abs(x - s[0] + 2.0) > 5.0 for s in STEPS) and not MOLE_X - 9.0 < x < MOLE_X + 9.0 \
                    and not CAUSEWAY[0][0] - 5.0 < x < CAUSEWAY[0][0] + 5.0:
                L.put("bollard", (x, QUAY, -0.8), 0.0, sector)

            x += 8.0
