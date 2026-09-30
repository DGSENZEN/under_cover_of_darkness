"""The royal shipyard (after Seville's Atarazanas and Barcelona's
Drassanes) inside its walls: twelve brick naves of seven bays under groin
vaults and a terrace, the slip nave's basin open to the sea through the
Nasrid water gate, a galley half-built on the stocks; the rope yard; the
customs house outside its west wall (its hall of seized cargo, the
harbourmaster's office upstairs), its yard behind; the sea wall, the
shipyard's west wall with its postern and its east wall with a stair up."""

from . import (CUSTOMS, GALLEY_NAVE, NAVE, NAVE_BAYS, NAVES, QUAY, SEA_WALL, SLIP_NAVE, WALL_D, WALL_E, WALL_F, nave_x, nave_z,
               wall_run)

UPPER = QUAY + 3.0
ROOF = QUAY + 6.0
# The postern through the west wall (the customs house's east door).
POSTERN_Z = -20.0
# The slip nave's basin (open to the sea), and the slipway at its head.
BASIN = (nave_x(SLIP_NAVE), nave_x(SLIP_NAVE + 1), -26.0)
SLIPWAY_Z = -30.0


def floor(L, x0, z0, x1, z1, kind, y, sector):
    """Floor tiles over x0..x1, z0..z1 in whole 2 m (overlapping the far
    edges rather than falling short of them)."""
    x1 = x0 + 2.0 * round((x1 - x0) / 2.0 + 0.49)
    z1 = z0 + 2.0 * round((z1 - z0) / 2.0 + 0.49)
    L.floor(x0, z0, x1, z1, kind=kind, y=y, sector=sector)


def _customs(L):
    x0, x1, z0, z1 = CUSTOMS
    inside = WALL_F - 1.8
    # Its walls: granite below, ochre render above; its door on the quay, a
    # back door to its yard; the shipyard's west wall is its east side.
    L.wall((x0, z1 - 0.2), (inside, z1 - 0.2), "granite", y=QUAY, sector="shipyard", openings={5.0: "window", 11.6: "door", 18.0: "window"})
    L.wall((x0, z1 - 0.2), (inside, z1 - 0.2), "render", y=UPPER, sector="shipyard", openings={5.0: "window", 11.6: "window", 18.0: "window"})
    L.wall((x0 + 0.2, z1), (x0 + 0.2, z0), "granite", y=QUAY, sector="shipyard")
    L.wall((x0 + 0.2, z1), (x0 + 0.2, z0), "render", y=UPPER, sector="shipyard", openings={7.0: "window", 16.0: "window"})
    L.wall((x0, z0 + 0.2), (inside, z0 + 0.2), "granite", y=QUAY, sector="shipyard", openings={20.0: "door"})
    L.wall((x0, z0 + 0.2), (inside, z0 + 0.2), "render", y=UPPER, sector="shipyard", openings={8.0: "window"})
    # Upstairs the harbourmaster's office in the north-east corner, its door
    # into the upper hall.
    L.wall((4.0, z0 + 0.4), (4.0, -22.0), "render", y=UPPER, sector="shipyard", thin=True)
    L.wall((4.0, -22.0), (inside, -22.0), "render", y=UPPER, sector="shipyard", thin=True, openings={3.0: "door"})
    # Floors: terracotta below and above (a well for the stair), the roof a
    # terrace; the stair up the west wall.
    floor(L, x0, z0, WALL_F - 1.2, z1, "terracotta", QUAY, "shipyard")
    floor(L, x0 + 4.0, z0, WALL_F - 1.2, z1, "terracotta", UPPER, "shipyard")
    floor(L, x0, -26.0, x0 + 4.0, z1, "terracotta", UPPER, "shipyard")
    floor(L, x0, z0, x0 + 4.0, -32.0, "terracotta", UPPER, "shipyard")
    floor(L, x0, z0, WALL_F - 1.2, z1, "granite", ROOF, "shipyard")
    L.stairs((x0 + 1.6, QUAY, -31.5), 0.0, sector="shipyard")
    # The seized cargo in the hall, the watchman's desk.
    L.put("cargo_bales", (-4.0, QUAY, -12.0), 0.0, "shipyard")
    L.put("crate_stack", (-5.0, QUAY, -18.0), 20.0, "shipyard")
    L.put("barrel_row", (-3.0, QUAY, -24.0), 0.0, "shipyard")
    L.put("crate_stack", (9.0, QUAY, -28.0), -10.0, "shipyard")
    L.put("table_long", (6.0, QUAY, -14.0), 90.0, "shipyard")
    # The customs yard behind, outside the wall; more cargo in it.
    floor(L, x0, WALL_D + 1.2, WALL_F - 1.2, z0, "granite", QUAY, "shipyard")
    L.put("cargo_bales", (0.0, QUAY, -50.0), 90.0, "shipyard")
    L.put("crate_stack", (8.0, QUAY, -44.0), 0.0, "shipyard")


def _walls(L):
    # The shipyard's west wall (its outer face west), its postern.
    wall_run(L, (WALL_F, SEA_WALL - 1.2), (WALL_F, POSTERN_Z + 1.5), "shipyard", outward=-1.0)
    L.put("city_wall_12_postern", (WALL_F, QUAY, POSTERN_Z), -90.0, "shipyard")
    L.put("floor_granite_2", (WALL_F, QUAY, POSTERN_Z), 0.0, "shipyard")
    wall_run(L, (WALL_F, POSTERN_Z - 1.5), (WALL_F, WALL_D), "shipyard", outward=-1.0)
    # The sea wall either side of the Nasrid gate; its corners.
    gate = (nave_x(SLIP_NAVE) + nave_x(SLIP_NAVE + 1)) / 2.0
    wall_run(L, (WALL_F + 1.2, SEA_WALL), (gate - 6.0, SEA_WALL), "shipyard")
    L.put("nasrid_gate", (gate, 0.0, SEA_WALL), 0.0, "shipyard")
    wall_run(L, (gate + 6.0, SEA_WALL), (WALL_E - 1.2, SEA_WALL), "shipyard")
    L.put("city_wall_12_corner", (WALL_F, QUAY, SEA_WALL), -90.0, "shipyard")
    L.put("city_wall_12_corner", (WALL_E, QUAY, SEA_WALL), 0.0, "shipyard")
    # The east wall north from the sea, a stair up its inner face.
    wall_run(L, (WALL_E, SEA_WALL - 1.2), (WALL_E, WALL_D), "shipyard")
    L.put("wall_stair_12", (WALL_E - 1.95, QUAY, -23.25), 90.0, "shipyard")


def _naves(L):
    for i in range(NAVES + 1):
        for j in range(1, NAVE_BAYS + 1):
            if i > 0:
                L.put("nave_pier", (nave_x(i), QUAY, nave_z(j)), 0.0, "shipyard")

    for i in range(NAVES):
        for j in range(1, NAVE_BAYS):
            L.put("nave_arch_x", (nave_x(i) + NAVE / 2.0, QUAY, nave_z(j)), 0.0, "shipyard")

        L.put("nave_end_wall", (nave_x(i) + NAVE / 2.0, QUAY, nave_z(NAVE_BAYS) - 0.4), 0.0, "shipyard")

        for j in range(NAVE_BAYS):
            L.put("nave_vault", (nave_x(i) + NAVE / 2.0, QUAY, nave_z(j) - NAVE / 2.0), 0.0, "shipyard")

    for i in range(1, NAVES + 1):
        for j in range(NAVE_BAYS):
            L.put("nave_arch_z", (nave_x(i), QUAY, nave_z(j) - NAVE / 2.0), 0.0, "shipyard")

    # Floors round the slip nave's basin and slipway; the basin's quay walls.
    west, east, head = BASIN
    top = nave_z(NAVE_BAYS)
    floor(L, nave_x(0), top, west - 6.0, SEA_WALL, "granite", QUAY, "shipyard")
    floor(L, east + 6.0, top, nave_x(NAVES), SEA_WALL, "granite", QUAY, "shipyard")
    floor(L, west - 6.0, top, east + 6.0, SLIPWAY_Z - 4.0, "granite", QUAY, "shipyard")
    floor(L, west - 6.0, SLIPWAY_Z - 4.0, west, head, "granite", QUAY, "shipyard")
    floor(L, east, SLIPWAY_Z - 4.0, east + 6.0, head, "granite", QUAY, "shipyard")

    for x, yaw in ((west - 3.0, 90.0), (east + 3.0, -90.0)):
        L.put("quay_8", (x, 0.0, -12.4), yaw, "shipyard")
        L.put("quay_8", (x, 0.0, -20.4), yaw, "shipyard")
        L.put("quay_4", (x, 0.0, -24.2), yaw, "shipyard")

    L.put("slipway_8", ((west + east) / 2.0, 0.0, SLIPWAY_Z), 0.0, "shipyard")
    # The lane behind the naves' end walls, under the old town's retaining
    # wall (city_massing).
    floor(L, WALL_F, WALL_D, nave_x(NAVES), top, "granite", QUAY, "shipyard")
    # The galley on the stocks down the middle of its nave, its scaffold's
    # ladders.
    L.put("galley_stocks", ((nave_x(GALLEY_NAVE) + nave_x(GALLEY_NAVE + 1)) / 2.0, QUAY, -38.0), 90.0, "shipyard", climbs=True)


def _rope_yard(L):
    floor(L, nave_x(NAVES), WALL_D, WALL_E - 1.2, SEA_WALL, "granite", QUAY, "shipyard")
    L.put("rope_coil", (125.0, QUAY, -14.0), 0.0, "shipyard")
    L.put("rope_coil", (127.0, QUAY, -15.5), 0.0, "shipyard")
    L.put("anchor_big", (138.0, QUAY, -20.0), 30.0, "shipyard")
    L.put("crate_stack", (142.0, QUAY, -40.0), 0.0, "shipyard")
    L.put("barrel_row", (122.0, QUAY, -48.0), 90.0, "shipyard")
    L.put("crane_jib", (132.0, QUAY, -3.0), 0.0, "shipyard")


def lay(L):
    _customs(L)
    _walls(L)
    _naves(L)
    _rope_yard(L)
