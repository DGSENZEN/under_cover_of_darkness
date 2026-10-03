"""The royal shipyard (after Seville's Atarazanas and Barcelona's
Drassanes) inside its walls: twelve brick naves of seven bays under groin
vaults and a terrace, the slip nave's basin open to the sea through the
Nasrid water gate, a galley half-built on the stocks; the rope yard; the
customs house outside its west wall (its hall of seized cargo, the
harbourmaster's office upstairs), its yard behind; the sea wall, the
shipyard's west wall with its postern and its east wall with a stair up."""

import kit_customs

from . import (CUSTOMS, CUSTOMS_AT, CUSTOMS_UPPER, GALLEY_NAVE, NAVE, NAVE_BAYS, NAVES, QUAY, SEA_WALL, SLIP_NAVE, WALL_D, WALL_E, WALL_F, nave_x, nave_z,
               wall_run)

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


def _house(x, z):
    """A point of the customs house's frame (kit_customs) in the world."""
    return CUSTOMS_AT[0] + x, CUSTOMS_AT[1] + z


def _customs(L):
    x0, x1, z0, z1 = CUSTOMS
    # The house (kit_customs): its loggia and the hall's front behind it,
    # its diamond-pointed front over them, its tower on the corner, its
    # sides, its hipped roof; each piece where its middle is in its frame.
    for name in ("customs_loggia", "customs_portal_wall", "customs_upper_front", "customs_tower", "customs_west_wall", "customs_back_wall"):
        mx, my, mz = kit_customs.PIECE_AT[name]
        wx, wz = _house(mx, mz)
        L.put(name, (wx, QUAY + my, wz), 0.0, "shipyard")

    mx, my, mz = kit_customs.PIECE_AT["customs_roof"]
    wx, wz = _house(mx, mz)
    L.put("customs_roof", (wx, QUAY + my, wz), 0.0, "shipyard")
    tx0, tx1, tz0, tz1 = kit_customs.TOWER
    front = _house(0.0, kit_customs.HALL_FRONT)[1]
    # Floors: the loggia's granite, the hall's terracotta (the tower solid
    # in its corner), the upper floor's over all but the tower and the
    # stair's well.
    floor(L, _house(tx1, 0.0)[0], front, x1, z1, "granite", QUAY, "shipyard")
    floor(L, x0, z0, x1, front, "terracotta", QUAY, "shipyard")
    stair_x, stair_z = x0 + 0.6, z0 + 2.4
    run = kit_customs.STAIR[0] * kit_customs.STAIR[2]
    well = (x0, x0 + 2.0, z0 + 2.0, z0 + 8.0)
    floor(L, x0, z0, x0 + 2.0, well[2], "terracotta", CUSTOMS_UPPER, "shipyard")
    floor(L, x0, well[3], x0 + 2.0, _house(0.0, tz0)[1], "terracotta", CUSTOMS_UPPER, "shipyard")
    floor(L, x0 + 2.0, z0, x1, _house(0.0, tz0)[1], "terracotta", CUSTOMS_UPPER, "shipyard")
    floor(L, _house(tx1, 0.0)[0], _house(0.0, tz0)[1], x1, z1 - 0.5, "terracotta", CUSTOMS_UPPER, "shipyard")
    # The stair up the west wall inside, rising south to the upper floor.
    L.put("customs_stair", (stair_x + kit_customs.STAIR[3] / 2.0, QUAY, stair_z + run / 2.0), 0.0, "shipyard")
    # Upstairs the harbourmaster's office in the north-east corner, its door
    # into the upper hall.
    mx, my, mz = kit_customs.PIECE_AT["customs_office"]
    wx, wz = _house(mx, mz)
    L.put("customs_office", (wx, QUAY + my, wz), 0.0, "shipyard")
    # The king's beam in the loggia; the hoist over the loading door.
    bx, bz = _house(kit_customs.PORTAL[0], (kit_customs.HALL_FRONT + kit_customs.Z1) / 2.0)
    L.put("kings_beam", (bx, QUAY, bz), 0.0, "shipyard")
    hx, hz = _house(kit_customs.LOADING[0], kit_customs.Z1)
    L.put("customs_hoist", (hx, QUAY + kit_customs.EAVES - 0.45, hz), 0.0, "shipyard")
    # The seized cargo in the hall, the watchman's desk, the clerk's: casks
    # racked against the back wall, bolts of cloth on the east, spice
    # chests, olive jars along the west, the notices inside the door (the
    # watchman's round kept clear: x 0 and 10.5, z -12).
    L.put("cargo_bales", (-2.0, QUAY, -15.0), 0.0, "shipyard")
    L.put("crate_stack", (-5.0, QUAY, -19.0), 20.0, "shipyard")
    L.put("barrel_row", (-3.0, QUAY, -24.0), 0.0, "shipyard")
    L.put("crate_stack", (9.0, QUAY, -29.0), -10.0, "shipyard")
    L.put("table_long", (6.0, QUAY, -14.0), 90.0, "shipyard")
    store = [("cask_rack", (3.0, -32.6), 0.0), ("cloth_bolts", (13.65, -30.0), -90.0), ("spice_chests", (6.0, -20.5), 15.0),
             ("olive_jars", (-8.6, -16.0), 90.0), ("clerk_desk", (-5.5, -12.4), 0.0), ("bench_plain", (-8.9, -22.0), 90.0)]

    for piece, (x, z), yaw in store:
        L.put(piece, (x, QUAY, z), yaw, "shipyard")

    L.put("notice_board", (2.6, QUAY + 1.7, front - kit_customs.WALL - 0.02), 180.0, "shipyard")
    mx, my, mz = kit_customs.PIECE_AT["customs_hall_frame"]
    wx, wz = _house(mx, mz)
    L.put("customs_hall_frame", (wx, QUAY + my, wz), 0.0, "shipyard")
    # More of what has been seized, along the walls and between the posts.
    for piece, (x, z), yaw in (("keg_rack", (-7.0, -32.7), 0.0), ("crate_stack", (-6.5, -28.0), 30.0), ("chest", (11.5, -32.8), 0.0),
                               ("sacks", (7.5, -33.0), 0.0), ("crate_stack", (12.6, -14.0), 0.0), ("anchor_small", (-7.5, -20.0), 40.0),
                               ("crate", (4.6, -16.6), 10.0), ("sacks", (1.8, -21.0), -20.0), ("barrel", (4.4, -29.0), 0.0), ("stool", (-4.6, -13.4), 0.0)):
        L.put(piece, (x, QUAY, z), yaw, "shipyard")
    # Upstairs, the store: casks, cloth, spice, jars, crates and sacks; a
    # clerk's desk at the stair's head.
    up = [("cask_rack", (-3.0, -32.6), 0.0), ("cloth_bolts", (-9.05, -19.0), 90.0), ("spice_chests", (0.0, -18.0), -20.0),
          ("olive_jars", (1.5, -8.6), 0.0), ("clerk_desk", (-6.5, -24.0), 90.0), ("crate_stack", (2.0, -28.0), 10.0), ("sacks", (-1.0, -13.0), 30.0),
          ("cargo_bales", (8.5, -14.0), 0.0), ("crate_stack", (13.0, -11.5), -5.0), ("crate_stack", (-6.0, -30.0), 20.0),
          ("crate_stack", (-6.0, -14.0), -10.0), ("crate_stack", (6.5, -16.5), 5.0), ("crate_stack", (2.0, -21.5), -15.0), ("sacks", (-3.0, -25.0), 0.0),
          ("sacks", (11.0, -18.0), 60.0), ("cargo_bales", (-3.0, -10.0), 90.0), ("keg_rack", (-2.0, -16.0), 90.0), ("barrel_row", (6.0, -24.0), 0.0),
          ("candle_stand", (-5.6, -24.8), 0.0), ("chest", (3.0, -32.8), 0.0)]

    for piece, (x, z), yaw in up:
        L.put(piece, (x, CUSTOMS_UPPER, z), yaw, "shipyard")

    # The harbourmaster's office: his desk on a rug, his chair, his
    # pigeonholes and his ledgers (either side of his window, clear of its
    # frame), a chart on the partition, the chart table, a globe, a bench for
    # those who wait.
    office = [("rug_3", (9.5, -28.2), 0.0), ("desk_writing", (9.5, -28.0), 0.0), ("armchair", (9.5, -28.95), 0.0),
              ("cabinet_pigeonholes", (13.75, -25.5), -90.0), ("shelves_ledgers", (6.35, -33.15), 0.0), ("shelves_ledgers", (9.65, -33.15), 0.0),
              ("chart_table", (5.4, -26.0), 90.0), ("globe_stand", (5.2, -32.3), 0.0), ("bench_plain", (11.5, -22.45), 0.0),
              ("rug_3", (5.4, -26.0), 90.0), ("dresser", (12.0, -33.0), 0.0), ("candle_stand", (8.0, -29.4), 0.0), ("candle_stand", (4.6, -24.3), 0.0),
              ("stool", (12.8, -24.6), 0.0), ("chest", (4.8, -30.6), 90.0)]

    for piece, (x, z), yaw in office:
        L.put(piece, (x, CUSTOMS_UPPER, z), yaw, "shipyard")

    L.put("wall_chart", (4.1, CUSTOMS_UPPER + 1.7, -29.5), 90.0, "shipyard")
    # Loose things to take: on the chart table, the bench, the hall's table,
    # the clerks' desks, by the globe.
    for piece, (x, y, z), yaw, kg in (("book", (5.05, CUSTOMS_UPPER + 0.84, -25.4), 15.0, 1.0), ("candlestick", (5.8, CUSTOMS_UPPER + 0.84, -26.8), 0.0, 1.0),
                                      ("ledger", (11.0, CUSTOMS_UPPER + 0.46, -22.45), 80.0, 2.0), ("coffer", (6.2, CUSTOMS_UPPER, -32.6), 10.0, 6.0),
                                      ("ledger", (6.0, QUAY + 0.79, -15.2), 5.0, 2.0), ("tankard", (6.15, QUAY + 0.79, -14.3), 0.0, 0.6),
                                      ("candlestick", (5.8, QUAY + 0.79, -12.4), 0.0, 1.0), ("jug", (5.9, QUAY + 0.79, -15.9), 0.0, 2.0),
                                      ("book", (-5.5, QUAY, -11.9), 30.0, 1.0), ("bucket", (-8.5, QUAY, -19.0), 0.0, 3.0),
                                      ("crate", (-1.5, CUSTOMS_UPPER, -20.5), 12.0, 14.0), ("bottle", (-6.2, CUSTOMS_UPPER + 1.2, -24.0), 0.0, 1.0)):
        L.put(piece, (x, y, z), yaw, "shipyard", loose=kg)
    L.put("arms_hanging", (13.98, CUSTOMS_UPPER + 2.7, -30.0), -90.0, "shipyard")
    # Sacks waiting in the loggia for the beam.
    L.put("sacks", (-1.0, QUAY, -8.4), 15.0, "shipyard")
    L.put("barrel_row", (11.0, QUAY, -8.6), 0.0, "shipyard")
    # The customs yard behind, outside the wall; more cargo in it.
    floor(L, x0, WALL_D + 1.2, WALL_F - 1.2, z0, "granite", QUAY, "shipyard")
    L.put("cargo_bales", (0.0, QUAY, -50.0), 90.0, "shipyard")
    L.put("crate_stack", (8.0, QUAY, -44.0), 0.0, "shipyard")


def _walls(L):
    # The shipyard's west wall (its outer face west), its postern; plain
    # where the customs house is built against it.
    against = lambda x, z: z > CUSTOMS[2]
    wall_run(L, (WALL_F, SEA_WALL - 1.2), (WALL_F, POSTERN_Z + 1.5), "shipyard", outward=-1.0, plain=against)
    L.put("city_wall_12_postern_plain", (WALL_F, QUAY, POSTERN_Z), -90.0, "shipyard")
    L.put("floor_granite_2", (WALL_F, QUAY, POSTERN_Z), 0.0, "shipyard")
    wall_run(L, (WALL_F, POSTERN_Z - 1.5), (WALL_F, WALL_D), "shipyard", outward=-1.0, plain=against)
    # The sea wall either side of the Nasrid gate; its corners.
    gate = (nave_x(SLIP_NAVE) + nave_x(SLIP_NAVE + 1)) / 2.0
    wall_run(L, (WALL_F + 1.2, SEA_WALL), (gate - 6.0, SEA_WALL), "shipyard")
    L.put("nasrid_gate", (gate, 0.0, SEA_WALL), 0.0, "shipyard")
    wall_run(L, (gate + 6.0, SEA_WALL), (WALL_E - 1.2, SEA_WALL), "shipyard")
    L.put("city_wall_12_corner_x", (WALL_F, QUAY, SEA_WALL), -90.0, "shipyard")
    L.put("city_wall_12_corner", (WALL_E, QUAY, SEA_WALL), 0.0, "shipyard")
    # The east wall north from the sea, a stair up its inner face.
    wall_run(L, (WALL_E, SEA_WALL - 1.2), (WALL_E, WALL_D), "shipyard")
    L.put("wall_stair_12", (WALL_E - 1.95, QUAY, -23.25), 90.0, "shipyard")


def _in_basin(i, j):
    """Whether the pier line i's pier at bay line j stands in the slip's
    basin or over its slipway (its foot on the basin's bed)."""
    return i in (SLIP_NAVE, SLIP_NAVE + 1) and nave_z(j) > SLIPWAY_Z - 4.0


def _naves(L):
    # The piers: at every line's crossing inside the walls (the north row
    # half in the end walls), the slip's in its basin standing on its bed.
    for i in range(1, NAVES + 1):
        for j in range(1, NAVE_BAYS + 1):
            L.put("nave_pier_deep" if _in_basin(i, j) else "nave_pier", (nave_x(i), QUAY, nave_z(j)), 0.0, "shipyard")

    # Against the walls, responds: down the west wall, along the sea wall;
    # in its corners with the sea wall and with the end walls, a quarter.
    for j in range(1, NAVE_BAYS):
        L.put("nave_respond", (nave_x(0), QUAY, nave_z(j)), 90.0, "shipyard")

    for i in range(1, NAVES + 1):
        L.put("nave_respond_deep" if _in_basin(i, 0) else "nave_respond", (nave_x(i), QUAY, nave_z(0)), 180.0, "shipyard")

    L.put("nave_respond_corner", (nave_x(0), QUAY, nave_z(0)), 90.0, "shipyard")
    L.put("nave_respond_corner", (nave_x(0), QUAY, nave_z(NAVE_BAYS)), 0.0, "shipyard")

    for i in range(NAVES):
        middle = nave_x(i) + NAVE / 2.0

        for j in range(1, NAVE_BAYS):
            L.put("nave_arch_x", (middle, QUAY, nave_z(j)), 0.0, "shipyard")

        L.put("nave_end_wall", (middle, QUAY, nave_z(NAVE_BAYS) - 0.4), 0.0, "shipyard")
        # Wall arches on the sea wall and the end wall.
        L.put("nave_wall_arch", (middle, QUAY, nave_z(0)), 180.0, "shipyard")
        L.put("nave_wall_arch", (middle, QUAY, nave_z(NAVE_BAYS)), 0.0, "shipyard")

        for j in range(NAVE_BAYS):
            L.put("nave_vault", (middle, QUAY, nave_z(j) - NAVE / 2.0), 0.0, "shipyard")

    for j in range(NAVE_BAYS):
        middle = nave_z(j) - NAVE / 2.0
        L.put("nave_wall_arch", (nave_x(0), QUAY, middle), 90.0, "shipyard")

        for i in range(1, NAVES + 1):
            L.put("nave_arch_z", (nave_x(i), QUAY, middle), 0.0, "shipyard")

        # (The terrace's open edge over the east arcade, its cornice.)
        L.put("nave_terrace_edge", (nave_x(NAVES), QUAY, middle), 90.0, "shipyard")

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
    # (The basin's bed, at its quays' foot, out to the sea's.)
    L.floor(west, SLIPWAY_Z + 2.0, east, -10.0, kind="gravel", y=-3.0, sector="shipyard")
    # The lane behind the naves' end walls, under the old town's retaining
    # wall (city_massing).
    floor(L, WALL_F, WALL_D, nave_x(NAVES), top, "granite", QUAY, "shipyard")
    # The galley on the stocks down the middle of its nave, its scaffold's
    # ladders.
    L.put("galley_stocks", ((nave_x(GALLEY_NAVE) + nave_x(GALLEY_NAVE + 1)) / 2.0, QUAY, -38.0), 90.0, "shipyard", climbs=True)


def _yard_work(L):
    """The yard at work, nave by nave (nave i's middle at nave_x(i) + 4.2):
    its timber and planks, a mast on trestles, carpenters' benches, oars
    racked, tar heating, blocks and tackle hung from the arches, a sail
    spread to be sewn, a new keel begun, a saw trestle, anchors, a forge;
    shavings and soot on the floors; loose tools, buckets and crates. Kept
    clear: the brute's round down naves 2 and 4 (x 37.4, 54.2) and across
    at z -14 and -62, the hiding places in naves 5 and 8, the dark the
    probe in nave 5 reads, the slip's head, the postern's way in."""
    mid = lambda i: nave_x(i) + NAVE / 2.0
    work = [("timber_stack", (mid(0), -12.0), 0.0), ("plank_stack", (mid(0), -30.0), 0.0), ("timber_stack", (mid(0), -42.0), 0.0),
            ("timber_stack", (mid(0), -54.0), 0.0),
            ("workbench", (mid(1) - 2.6, -21.0), 0.0), ("workbench", (mid(1) + 2.6, -36.0), 0.0), ("mast_trestles", (mid(1), -50.0), 0.0),
            ("oars_rack", (mid(2) - 3.0, -24.0), 0.0), ("oars_rack", (mid(2) - 3.0, -48.0), 0.0), ("oars_stack", (mid(2) + 2.8, -36.0), 90.0),
            ("cauldron", (mid(4) - 2.8, -26.0), 0.0), ("fire_ring", (mid(4) - 2.8, -26.0), 0.0), ("tar_barrels", (mid(4) - 2.6, -29.4), 0.0),
            ("block_tackle", (mid(4), -42.0), 0.0),
            ("sail_spread", (mid(5), -24.0), 0.0),
            ("keel_frames", (mid(7), -42.0), 0.0), ("saw_trestle", (mid(7), -60.0), 0.0), ("block_tackle", (mid(7), -33.6), 0.0),
            ("anchor_big", (mid(8), -48.0), 20.0), ("oars_stack", (mid(8) - 1.5, -58.0), 90.0), ("rope_coil", (mid(8) + 1.8, -50.0), 0.0),
            ("rope_coil", (mid(8) + 2.4, -51.6), 0.0),
            ("forge", (mid(9), -64.4), 0.0), ("workbench", (mid(9) - 2.8, -50.0), 0.0), ("grindstone", (mid(9) + 2.6, -57.0), 0.0),
            ("timber_stack", (mid(10), -20.0), 0.0), ("plank_stack", (mid(10), -34.0), 0.0), ("mast_trestles", (mid(10), -52.0), 0.0),
            ("sail_spread", (mid(11), -30.0), 0.0), ("block_tackle", (mid(11), -50.4), 0.0), ("workbench", (mid(11) - 2.6, -42.0), 0.0),
            ("rope_coil", (mid(11) + 1.8, -58.0), 0.0), ("rope_coil", (mid(11) + 2.6, -60.0), 0.0)]

    for piece, (x, z), yaw in work:
        L.put(piece, (x, QUAY, z), yaw, "shipyard")

    # Loose: tools on and by the benches, buckets by the tar, crates about.
    for piece, (x, y, z), yaw, kg in (("mallet", (mid(1) - 2.6, QUAY + 0.85, -20.2), 15.0, 1.5), ("hand_saw", (mid(1) + 2.6, QUAY + 0.85, -36.9), 0.0, 1.2),
                                      ("adze", (mid(9) - 2.8, QUAY + 0.85, -49.0), 10.0, 2.0), ("mallet", (mid(7) + 1.6, QUAY, -38.0), 60.0, 1.5),
                                      ("bucket", (mid(4) - 1.4, QUAY, -27.6), 0.0, 3.0), ("bucket", (mid(4) - 3.8, QUAY, -28.2), 0.0, 3.0),
                                      ("bucket", (mid(9) + 1.6, QUAY, -61.8), 0.0, 3.0), ("crate", (mid(0) + 2.4, QUAY, -36.0), 10.0, 14.0),
                                      ("crate", (mid(5) + 2.6, QUAY, -36.0), -15.0, 14.0), ("crate", (mid(10) - 2.4, QUAY, -42.0), 5.0, 14.0),
                                      ("crate", (mid(11) + 2.5, QUAY, -20.0), 20.0, 14.0), ("stool", (mid(1) - 1.8, QUAY, -22.0), 0.0, 4.0)):
        L.put(piece, (x, y, z), yaw, "shipyard", loose=kg)

    # Shavings by the benches and the saw, soot by the tar and the forge.
    for i, (kind, (x, z), yaw, size) in enumerate((("straw", (mid(1) - 2.0, -21.5), 10.0, (3.0, 2.4)), ("straw", (mid(1) + 2.0, -36.5), -20.0, (2.6, 2.2)),
                                                   ("straw", (mid(7), -60.0), 0.0, (3.0, 4.0)), ("straw", (mid(7), -44.0), 5.0, (4.0, 6.0)),
                                                   ("soot", (mid(4) - 2.8, -26.6), 0.0, (2.4, 2.4)), ("soot", (mid(9), -62.6), 0.0, (2.8, 2.6)),
                                                   ("dirt", (mid(0), -48.0), 0.0, (3.0, 6.0)), ("straw", (mid(11) - 2.2, -42.0), 15.0, (2.6, 2.4)))):
        L.mark("yard_floor_%d" % (i + 1), "decal", (x, QUAY + 0.05, z), yaw, "shipyard", size=[size[0], 0.5, size[1]], kind=kind, floor=True)

    # The tar's fire and the forge's coals.
    L.mark("tar_fire", "light", (mid(4) - 2.8, QUAY + 0.6, -26.0), 0.0, "shipyard", kind="glow", color="#ff8a3c", energy=0.9, range=5.0)
    L.mark("forge_coals", "light", (mid(9), QUAY + 1.2, -63.6), 0.0, "shipyard", kind="glow", color="#ff6a20", energy=1.3, range=6.5)


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
    _yard_work(L)
    _rope_yard(L)
