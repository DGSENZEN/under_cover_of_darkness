"""The Ribeira (after Porto's): its granite arcade along the quay, the tall
narrow houses over it against the old wall behind, the west wall climbing
beside the Guindais stair to the old town's upper gate."""

from . import ARCADE_FRONT, QUAY, RIB_BAYS, STAIR_FLIGHTS, STAIR_FOOT, STAIR_X, WALL_C, WALL_D, WALL_RIB, WALL_W, rib_x, stair_y, wall_run

# The houses along it, west to east (casa_d, three storeys, its old vine the
# climb onto its roof and its roof the way onto the wall, the seventh).
HOUSES = ["casa_b", "casa_e", "casa_a", "casa_h", "casa_c", "casa_f", "casa_d", "casa_g", "casa_b", "casa_a", "casa_e", "casa_c", "casa_h"]
ROOF_HOUSE = 6


def lay(L):
    for i in range(RIB_BAYS):
        x = rib_x(i)
        L.put("arcade_ribeira_6", (x, QUAY, ARCADE_FRONT - 2.0), 0.0, "ribeira")
        L.put(HOUSES[i], (x, QUAY, ARCADE_FRONT - 7.0), 0.0, "ribeira", climbs=i == ROOF_HOUSE)

    # The old wall behind the houses, its corner at the west end; the west
    # wall up the slope beside the stair; the wall north past the Terreiro's
    # west arcade to the wall behind it.
    wall_run(L, (rib_x(0) - 3.0, WALL_RIB), (rib_x(RIB_BAYS - 1) + 3.0, WALL_RIB), "ribeira")
    L.put("city_wall_12_corner", (WALL_W, QUAY, WALL_RIB), -90.0, "ribeira")
    wall_run(L, (WALL_W, WALL_RIB - 1.2), (WALL_W, -120.0), "ribeira", outward=-1.0, ground=lambda x, z: stair_y(z) - 0.5)
    L.put("city_wall_12_corner", (WALL_C, QUAY, WALL_RIB), 0.0, "ribeira")
    wall_run(L, (WALL_C, WALL_RIB - 1.2), (WALL_C, WALL_D - 0.2), "ribeira")

    # The Guindais stair: flights of ten risers, each on to a landing, up
    # beside the west wall; a parapet on its river side; walled across at its
    # top (the old town's upper gate: an exit, sub-project 2).
    z, y = STAIR_FOOT

    for k in range(STAIR_FLIGHTS):
        L.put("granite_flight_3", (STAIR_X, y, z), 180.0, "ribeira")
        L.put("granite_parapet_3", (STAIR_X - 1.65, y, z), 180.0, "ribeira")
        L.put("granite_landing_3", (STAIR_X, y + 2.0, z - 4.5), 0.0, "ribeira")
        z, y = z - 6.0, y + 2.0

    L.put("wall_granite_4", (STAIR_X, y, z - 1.0), 0.0, "ribeira")
    L.put("alminha", (rib_x(0) - 3.05, QUAY, ARCADE_FRONT - 2.0), -90.0, "ribeira")
    assert abs(y - stair_y(z)) < 1e-6
