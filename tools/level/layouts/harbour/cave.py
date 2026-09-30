"""The smugglers' cave in the east cliff (after Peniscola's): a jetty on
its beach, their contraband, the tunnel on into the rock fallen in (the
undercroft, sub-project 2); the blowhole's shaft up to the headland."""


def lay(L):
    for i in range(5):
        L.put("floor_board_2", (230.0, 1.2, 31.0 + i * 2.0), 0.0, "cave")

    L.put("crate_stack", (227.5, 1.2, 20.0), 15.0, "cave")
    L.put("barrel_row", (233.0, 1.35, 16.0), 80.0, "cave")
    L.put("cargo_bales", (229.0, 1.4, 11.0), -10.0, "cave")
    L.put("rope_coil", (231.5, 1.2, 25.0), 0.0, "cave")
    L.put("lobster_pots", (226.5, 1.1, 26.0), 0.0, "cave")
    # The fall that closes the tunnel on inland.
    L.put("wall_rubble_4", (232.0, 0.8, -12.0), 0.0, "cave")
    L.put("crate_stack", (231.0, 1.5, -9.5), 40.0, "cave")
