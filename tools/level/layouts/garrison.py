"""The garrison (the garrison spec): a walled keep on the canal bank.

Godot axes: x east, y up, z south; the courtyard floor at y = 0. The curtain's
inner faces are at x = +-30 and z = +-26 (the wall-walk on top at 5 m).

    courtyard      x -16..14,  z -16..22
    west range     x -30..-20, z -14..20 (armoury, storehouse over the
                   cellar, a lean-to), its colonnade x -20..-16
    drill yard     x -27..-6,  z -26..-16
    chapel         x -6..14,   z -25.6..-16 (12 m tall; a loft at its east end)
    barracks       x 14..30,   z -20..18 (two storeys: corridor, kitchen, a
                   double-height mess hall under a gallery; the captain's
                   chamber and the dormitory above)
    watchtower     x -35..-27, z -31..-23 (12 m, flights round its walls)
    gatehouse      x -6..6,    z 22..31 (passage, guardrooms, the walk over)
    postern        in the south curtain at x = 24
    outside        the quay and the canal (south), lanes of house fronts
                   (north, east), the grassy bank with trees (west)
"""

import lay
from lay import facing

WALK = 5.0
G = lay.Layout("garrison")


# ---------------------------------------------------------------------------
# The curtain
# ---------------------------------------------------------------------------

def curtain():
    # North (outside is -z): from the tower (x -27) to the corner.
    for x in range(-25, 30, 4):
        G.put("curtain_4", (x, 0, -27.2), 180.0, "walls")

    G.put("curtain_2", (30.0, 0, -27.2), 180.0, "walls")
    # South (outside +z), leaving the gatehouse (x -6..6) and the postern at 24.
    for x in list(range(-28, -6, 4)) + [12, 16, 20, 28]:
        G.put("curtain_4", (x, 0, 27.2), 0.0, "walls")

    # A breach in the parapet over a lean-to on the towpath: the way over the
    # wall for a man with nowhere else to go.
    G.put("curtain_breach_4", (8.0, 0, 27.2), 0.0, "walls")
    G.put("lean_to_4", (9.0, 0, 29.7), 0.0, "outside")

    G.put("curtain_postern_4", (24.0, 0, 27.2), 0.0, "walls")
    # East (outside +x) and west (outside -x, from the tower south).
    for z in range(-24, 27, 4):
        G.put("curtain_4", (31.2, 0, z), 90.0, "walls")

    for z in range(-20, 27, 4):
        G.put("curtain_4", (-31.2, 0, z), -90.0, "walls")

    G.put("curtain_2", (-31.2, 0, -23.0), -90.0, "walls")

    for corner in ((31.2, -27.2), (31.2, 27.2), (-31.2, 27.2)):
        G.put("curtain_corner", (corner[0], 0, corner[1]), 0.0, "walls")

    # The flights up to the walk, either side of the gatehouse.
    G.stairs((-14.0, 0, 24.6), 90.0, "stair_curtain", "walls")
    G.stairs((14.0, 0, 24.6), -90.0, "stair_curtain", "walls")


# ---------------------------------------------------------------------------
# The ground inside
# ---------------------------------------------------------------------------

def grounds():
    G.floor(-16, -16, 14, 22, "cobble", 0.0, "courtyard")
    G.floor(-30, 22, -6, 26, "cobble", 0.0, "courtyard")
    G.floor(6, 22, 30, 26, "cobble", 0.0, "courtyard")
    G.floor(14, 18, 30, 22, "cobble", 0.0, "courtyard")
    G.floor(14, -26, 30, -20, "cobble", 0.0, "courtyard")
    G.floor(-27, -26, -6, -14, "gravel", 0.0, "courtyard")
    G.floor(-30, -23, -27, -14, "gravel", 0.0, "courtyard")
    G.floor(-30, -14, -20, -2, "flag", 0.0, "west_range")       # armoury
    G.floor(-20, -14, -16, 20, "flag", 0.0, "west_range")       # colonnade
    G.floor(-30, 12, -20, 22, "mud", 0.0, "west_range")         # lean-to
    G.floor(-20, 20, -16, 22, "cobble", 0.0, "courtyard")
    # Mud patches in the courtyard (they darken and shine in rain).
    for x, z in ((-12, 12), (8, -12), (-4, 18)):
        G.put("floor_mud_2", (x, 0.01, z), 0.0, "courtyard")

    # The fire (a marker: the game's Fire), its benches, the well, the
    # woodpile, the cart, banners.

    for x, z, yaw in ((0, -0.6, 0.0), (0, 4.6, 180.0), (-2.6, 2, 90.0)):
        G.put("bench", (x, 0, z), yaw, "courtyard")

    G.put("well", (-8, 0, 12), 0.0, "courtyard")
    G.put("cart", (9, 0, 15), 20.0, "courtyard")
    G.put("chopping_block", (-22.3, 0, 16.4), 0.0, "west_range")
    G.put("woodpile", (-24, 0, 18), 0.0, "west_range")

    for x in (-4.5, -1.5, 1.5, 4.5):
        G.put("banner", (x, 0, 21.2), 180.0, "courtyard")

    # Palisade and a lattice screen to frame through (the references' 7, 9).
    for x in (-14, -12):
        G.put("palisade_2", (x, 0, -15.0), 0.0, "courtyard")


# ---------------------------------------------------------------------------
# The watchtower (north-west): hollow, flights round its walls, a platform
# ---------------------------------------------------------------------------

def watchtower():
    x0, x1, z0, z1 = -35.0, -27.0, -31.0, -23.0
    G.wall((x0, z1 - 0.2), (x1, z1 - 0.2), "ashlar", 0.0, "tower", storeys=4, openings={6.0: "door"}, face=-1)
    G.wall((x0, z0 + 0.2), (x1, z0 + 0.2), "ashlar", 0.0, "tower", storeys=4)
    G.wall((x0 + 0.2, z0), (x0 + 0.2, z1), "ashlar", 0.0, "tower", storeys=4)
    G.wall((x1 - 0.2, z0), (x1 - 0.2, z1), "ashlar", 0.0, "tower", storeys=4, openings={3.0: "slit", 6.0: "slit"})
    G.floor(-35, -31, -27, -23, "flag", 0.0, "tower")
    # Flights: north up the east wall, west along the north, south down the
    # west, east along the south; corner landings.
    G.stairs((-28.2, 0.0, -24.4), 180.0, "stair_straight", "tower")
    G.put("landing_2", (-28.4, 3.0, -29.6), 0.0, "tower")
    G.stairs((-29.4, 3.0, -29.8), -90.0, "stair_straight", "tower")
    G.put("landing_2", (-33.6, 6.0, -29.6), 0.0, "tower")
    G.stairs((-33.8, 6.0, -28.6), 0.0, "stair_straight", "tower")
    G.put("landing_2", (-33.6, 9.0, -24.4), 0.0, "tower")
    G.stairs((-32.6, 9.0, -24.2), 90.0, "stair_straight", "tower")
    G.put("landing_2", (-28.4, 12.0, -24.4), 0.0, "tower")
    # The platform (open over the last flight) and its merlons.
    for x in (-34, -32, -30, -28):
        for z in (-30, -28, -26):
            G.put("landing_2", (x, 12.0, z), 0.0, "tower")

    for i in range(4):
        G.put("wall_ashlar_1", (x0 + 1.0 + i * 2.0, 12.0, z0 + 0.2), 0.0, "tower")
        G.put("wall_ashlar_1", (x0 + 1.0 + i * 2.0, 12.0, z1 - 0.2), 0.0, "tower")
        G.put("wall_ashlar_1", (x0 + 0.2, 12.0, z0 + 1.0 + i * 2.0), 90.0, "tower")
        G.put("wall_ashlar_1", (x1 - 0.2, 12.0, z0 + 1.0 + i * 2.0), 90.0, "tower")


# ---------------------------------------------------------------------------
# The gatehouse (south): a symmetric passage, guardrooms, the walk over it
# ---------------------------------------------------------------------------

def gatehouse():
    # Guardrooms' outer walls (two storeys) and the passage's side walls.
    G.wall((-6.0, 22.2), (-2.0, 22.2), "ashlar", 0.0, "gatehouse", storeys=2, openings={2.0: "window"}, face=-1)
    G.wall((2.0, 22.2), (6.0, 22.2), "ashlar", 0.0, "gatehouse", storeys=2, openings={2.0: "window"}, face=-1)
    G.wall((-6.0, 30.8), (-2.0, 30.8), "ashlar", 0.0, "gatehouse", storeys=2, openings={2.0: "slit"})
    G.wall((2.0, 30.8), (6.0, 30.8), "ashlar", 0.0, "gatehouse", storeys=2, openings={2.0: "slit"})
    G.wall((-5.8, 22.0), (-5.8, 31.0), "ashlar", 0.0, "gatehouse", storeys=2)
    G.wall((5.8, 22.0), (5.8, 31.0), "ashlar", 0.0, "gatehouse", storeys=2)
    G.wall((-2.2, 22.0), (-2.2, 31.0), "ashlar", 0.0, "gatehouse", storeys=2, openings={2.0: "door"})
    G.wall((2.2, 22.0), (2.2, 31.0), "ashlar", 0.0, "gatehouse", storeys=2, openings={2.0: "arch"})
    G.floor(-6, 22, 6, 32, "cobble", 0.0, "gatehouse")
    # The walk over it (top at the curtain's walk).
    G.floor(-6, 22, 6, 32, "flag", WALK, "gatehouse")
    G.put("portcullis", (0, 0, 30.2), 0.0, "gatehouse")
    # A lattice across the east guardroom's arch: its brazier throws the bars'
    # shadows into the passage.
    G.put("lattice_screen", (2.2, 0, 24.0), 90.0, "gatehouse")
    G.put("bench", (-4.0, 0, 29.0), 90.0, "gatehouse")
    G.put("rack", (5.4, 0, 27.0), -90.0, "gatehouse")


# ---------------------------------------------------------------------------
# The barracks (east): two storeys
# ---------------------------------------------------------------------------

def barracks():
    s = "barracks"
    # Outer walls. West (the courtyard front): doors into the corridor at z -12
    # and 6, windows along it, above the gallery's.
    G.wall((14.2, -20.0), (14.2, 18.0), "plaster", 0.0, s, storeys=1,
           openings={3.0: "window", 8.0: "door", 13.0: "window", 18.0: "window", 22.0: "window", 26.0: "door", 32.0: "window", 36.0: "window"})
    G.wall((14.2, -20.0), (14.2, 18.0), "plaster", 3.0, s, storeys=1,
           openings={2.6: "door", 8.0: "window", 14.0: "window", 20.0: "window", 26.0: "window", 32.0: "window"})
    G.wall((29.8, -20.0), (29.8, 18.0), "plaster", 0.0, s, storeys=2)
    G.wall((14.0, -19.8), (30.0, -19.8), "plaster", 0.0, s, storeys=2, openings={12.0: "door"})
    G.wall((14.0, 17.8), (30.0, 17.8), "plaster", 0.0, s, storeys=2, openings={8.0: "window"})
    # The corridor's east wall (ground): doors into the stair hall, kitchen,
    # the mess (arches, lined up across for the enfilade), the south hall.
    G.wall((16.6, -19.6), (16.6, -8.0), "timber", 0.0, s, thin=True, openings={2.0: "door", 8.0: "door"})
    G.wall((16.6, -8.0), (16.6, 10.0), "timber", 0.0, s, thin=True, openings={4.0: "arch", 14.0: "arch"})
    G.wall((16.6, 10.0), (16.6, 17.6), "timber", 0.0, s, thin=True, openings={3.0: "door"})
    # Room partitions (ground): stair hall | kitchen | mess | south hall, with
    # doors on the enfilade axis x = 23.
    G.wall((16.6, -15.2), (29.6, -15.2), "timber", 0.0, s, thin=True, openings={6.4: "door"})
    G.wall((16.6, -8.0), (29.6, -8.0), "timber", 0.0, s, thin=True, openings={6.4: "door"})
    G.wall((16.6, 10.0), (29.6, 10.0), "timber", 0.0, s, thin=True, openings={6.4: "door"})
    # Floors (ground), and the upper floor: the gallery over the corridor,
    # the north block (the captain), the south block (the dormitory); none
    # over the mess hall (it is two storeys high).
    G.floor(14, -20, 30, 18, "board", 0.0, s)

    # The upper floor on one grid from the outer wall (under the partitions,
    # so every doorway has floor): the gallery (x 14..16) the whole length,
    # the north and south blocks right across; the stairs' wells (x 18..22)
    # left open, the tile at x 16..18 the landing by the gallery's doors.
    for x in range(14, 30, 2):
        for z in range(-20, 18, 2):
            over_mess = -8 <= z < 10
            well = x in (18, 20) and (z in (-20, -18) or z in (14, 16))

            if (over_mess and x > 14) or well:
                continue

            G.put("floor_board_2", (x + 1.0, 3.0, z + 1.0), 0.0, s)

    # Upper walls: the captain's chamber (a stout door off the gallery), the
    # dormitory; the gallery railed where it looks down into the mess.
    G.wall((16.6, -19.6), (16.6, -8.0), "timber", 3.0, s, thin=True, openings={2.0: "door", 8.0: "door"})
    G.wall((16.6, 10.0), (16.6, 17.6), "timber", 3.0, s, thin=True, openings={4.0: "door"})
    G.wall((16.6, -15.2), (29.6, -15.2), "timber", 3.0, s, thin=True)

    for z in range(-7, 10, 2):
        G.put("railing_2", (15.95, 3.0, z), 90.0, s)

    # Stairs: up toward the corridor (-x), arriving on a landing by the
    # gallery's doors.
    G.stairs((22.5, 0.0, -18.0), -90.0, "stair_straight", s)
    G.stairs((22.5, 0.0, 16.0), -90.0, "stair_straight", s)
    # The roof (a flat slab in stage 1).
    for x in range(14, 30, 4):
        for z in range(-20, 18, 4):
            G.put("floor_board_4", (x + 2.0, 6.2, z + 2.0), 0.0, s)

    # Dressing: the mess (two long tables and their benches, the great hearth
    # on the east wall's middle), the kitchen, the dormitory, the captain.
    G.put("hearth", (28.9, 0, 1.0), -90.0, s)

    for z in (-3.0, 5.0):
        G.put("table_long", (22.0, 0, z), 0.0, s)
        G.put("bench", (22.0, 0, z - 0.9), 0.0, s)
        G.put("bench", (22.0, 0, z + 0.9), 180.0, s)

    G.put("stove", (28.6, 0, -11.5), -90.0, s)
    G.put("table_long", (22.0, 0, -11.5), 0.0, s)
    G.put("barrel", (27.8, 0, -14.2), 0.0, s)
    G.put("sacks", (19.0, 0, -9.2), 0.0, s)

    for x in (19.0, 21.4, 23.8, 26.2):
        G.put("bunk", (x, 3.0, 11.7), 0.0, s)

    for x in (24.4, 26.8):
        G.put("bunk", (x, 3.0, 16.6), 0.0, s)

    G.put("stove", (28.6, 3.0, 14.0), -90.0, s)
    G.put("map_table", (23.0, 3.0, -11.5), 0.0, s)
    G.put("bed", (28.2, 3.0, -13.6), 0.0, s)
    G.put("bedroll", (24.8, 3.0, 14.0), 90.0, s)
    G.put("banner", (29.5, 3.0, -11.5), -90.0, s)
    # Lit windows on the courtyard front (about one in four).
    for z, y in ((-17.0, 0.0), (6.0, 3.0), (12.0, 3.0)):
        G.put("window_lit", (14.0, y, z), -90.0, s)


# ---------------------------------------------------------------------------
# The chapel (north): a tall nave, lancets, a loft at the east end
# ---------------------------------------------------------------------------

def chapel():
    s = "chapel"
    # North and south walls: lancets in two tiers; the south door into the
    # courtyard (x 2).
    G.wall((-6.0, -25.4), (14.0, -25.4), "ashlar", 0.0, s, storeys=4, openings={4.0: "lancet", 8.0: "lancet", 12.0: "lancet", 16.0: "lancet"})
    G.wall((-6.0, -16.2), (14.0, -16.2), "ashlar", 0.0, s, storeys=1, openings={4.0: "window", 8.0: "door", 14.0: "window"})
    G.wall((-6.0, -16.2), (14.0, -16.2), "ashlar", 3.0, s, storeys=3, openings={4.0: "lancet", 14.0: "lancet"})
    # West (the entrance from the drill yard) and east (the altar's lancets;
    # the loft's door to the barracks gallery above).
    G.wall((-5.8, -25.6), (-5.8, -16.0), "ashlar", 0.0, s, storeys=1, openings={4.8: "door"})
    G.wall((-5.8, -25.6), (-5.8, -16.0), "ashlar", 3.0, s, storeys=3, openings={4.8: "lancet"})
    # (Plain behind the altar; above it the lancets, and the loft's way
    # through to the barracks at 8.2.)
    G.wall((13.8, -25.6), (13.8, -16.0), "ashlar", 0.0, s, storeys=1)
    G.wall((13.8, -25.6), (13.8, -16.0), "ashlar", 3.0, s, storeys=3, openings={2.4: "lancet", 5.0: "lancet", 8.2: "door"})
    G.floor(-6, -26, 14, -16, "flag", 0.0, s)

    for x in range(-4, 12, 2):
        G.put("floor_carpet_2", (x + 1.0, 0.02, -20.8), 0.0, s)

    # Pews in rows either side of the aisle, facing the altar (east).
    for x in (-3.0, -1.4, 0.2, 1.8, 3.4, 5.0, 6.6):
        G.put("pew", (x, 0, -23.2), -90.0, s)
        G.put("pew", (x, 0, -18.4), -90.0, s)

    G.put("altar", (11.6, 0, -20.8), -90.0, s)

    for z in (-24.4, -23.0):
        G.put("candle_stand", (10.6, 0, z), 0.0, s)

    for x in (-2.0, 4.0):
        G.put("candle_stand", (x, 0, -25.0), 0.0, s)
        G.put("candle_stand", (x, 0, -16.6), 0.0, s)

    # Banners for the relief panels until the art pass (the chandeliers are
    # light markers: their fixture is their model).
    for x in (1.0, 9.0):
        G.put("banner", (x, 5.0, -25.1), 0.0, s)
        G.put("banner", (x, 5.0, -16.5), 180.0, s)

    # The roof (a slab in stage 1: moonlight comes in only through the glass).
    for x in range(-6, 14, 4):
        for z in (-26, -22, -18):
            G.put("floor_board_4", (x + 2.0, 12.2, z + 2.0), 0.0, s)

    # The loft (x 12..14, z -18.4..-16.4 at 3 m) and its stair down into the
    # nave; its door onto the barracks gallery is the barracks' west wall's.
    G.put("landing_2", (13.0, 3.0, -17.4), 0.0, s)
    G.put("railing_2", (13.0, 3.0, -18.4), 0.0, s)
    G.stairs((7.6, 0.0, -17.2), 90.0, "stair_straight", s)


# ---------------------------------------------------------------------------
# The west range: armoury, storehouse over the cellar, a lean-to; the
# colonnade in front
# ---------------------------------------------------------------------------

def west_range():
    s = "west_range"
    G.wall((-30.0, -14.2), (-20.0, -14.2), "rubble", 0.0, s)
    G.wall((-29.8, -14.0), (-29.8, 12.0), "rubble", 0.0, s)
    G.wall((-20.2, -14.0), (-20.2, 12.0), "rubble", 0.0, s, openings={6.0: "door", 18.0: "door"})
    G.wall((-29.6, -2.0), (-20.4, -2.0), "rubble", 0.0, s, thin=True, openings={4.0: "door"})
    G.wall((-30.0, 12.2), (-20.0, 12.2), "rubble", 0.0, s, openings={5.0: "arch"})
    # The storehouse's boards, a well left over the cellar's flight.
    for x in range(-30, -20, 2):
        for z in range(-2, 12, 2):
            if x == -28 and z in (6, 8):
                continue
            G.put("floor_board_2", (x + 1.0, 0.0, z + 1.0), 0.0, s)
    # The roof over the range and the colonnade.
    for x in range(-30, -16, 2):
        for z in range(-14, 20, 2):
            G.put("floor_board_2", (x + 1.0, 3.2, z + 1.0), 0.0, s)

    # The colonnade's columns and arches.
    for z in (-12.5, -9.5, -6.5, -3.5, -0.5, 2.5, 5.5, 8.5, 11.5, 14.5, 17.5):
        G.put("column", (-16.2, 0, z), 0.0, s)

    for z in (-11.0, -8.0, -5.0, -2.0, 1.0, 4.0, 7.0, 10.0, 13.0, 16.0):
        G.put("arch_span_3", (-16.2, 0, z), 90.0, s)

    # The armoury: racks, the grindstone, a chest.
    for z in (-12.5, -9.0, -5.5):
        G.put("rack", (-29.2, 0, z), 90.0, s)

    G.put("grindstone", (-24.0, 0, -8.0), 0.0, s)
    # The storehouse: crates (the carrier's are markers: loose crates), sacks,
    # barrels; the cellar's stair down.
    for x, z in ((-28.5, 0.0), (-28.5, 1.2), (-27.3, 0.0)):
        G.put("crate", (x, 0, z), 0.0, s)

    G.put("sacks", (-22.0, 0, 2.0), 0.0, s)

    for z in (6.0, 7.0, 8.0):
        G.put("barrel", (-21.2, 0, z), 0.0, s)

    # The cellar (y -3): its floor, walls, barrels; the flight up to the
    # storehouse floor, whose well is left open.
    G.floor(-30, -2, -20, 12, "flag", -3.0, "cellar")
    G.wall((-29.8, -2.0), (-29.8, 12.0), "rubble", -3.0, "cellar")
    G.wall((-20.2, -2.0), (-20.2, 12.0), "rubble", -3.0, "cellar")
    G.wall((-30.0, -1.8), (-20.0, -1.8), "rubble", -3.0, "cellar")
    G.wall((-30.0, 11.8), (-20.0, 11.8), "rubble", -3.0, "cellar")
    G.stairs((-27.0, -3.0, 10.0), 180.0, "stair_straight", "cellar")

    for x in (-28.8, -27.8, -26.8):
        for z in (0.0, 1.0):
            G.put("barrel", (x, -3.0, z), 0.0, "cellar")

    for x in (-26.0, -23.0):
        G.put("rib_8", (x, -0.4, 5.0), 90.0, "cellar")


def drill_yard():
    s = "courtyard"

    for x in (-22.0, -19.0, -16.0):
        G.put("straw_man", (x, 0, -21.0), 0.0, s)

    G.put("rack", (-12.0, 0, -25.2), 0.0, s)
    G.put("barrel", (-9.0, 0, -25.0), 0.0, s)


# ---------------------------------------------------------------------------
# Outside: the quay and the canal, the lanes, the bank
# ---------------------------------------------------------------------------

def outside():
    G.floor(-44, 28, 44, 44, "cobble", 0.0, "outside")
    G.floor(-44, -44, 44, -28, "cobble", 0.0, "outside")
    G.floor(32, -28, 44, 28, "cobble", 0.0, "outside")
    G.floor(-60, -44, -32, 44, "grass", 0.0, "outside")

    for x in range(-42, 44, 4):
        G.put("quay_wall_4", (x, 0, 44.5), 0.0, "outside")

    G.floor(-50, 45, 50, 72, "mud", -4.0, "outside")
    G.floor(-50, 72, 50, 80, "grass", 0.0, "outside")

    for x in (-26.0, -8.0, 10.0, 30.0):
        G.put("mooring_post", (x, 0, 43.6), 0.0, "outside")

    for x, z, yaw in ((-18.0, 47.5, 90.0), (14.0, 47.5, 95.0)):
        G.put("boat", (x, -0.2, z), yaw, "outside")

    G.put("crane", (-20.0, 0, 41.0), 0.0, "outside")

    # House fronts, their heights varied (a town's roofline, not a wall).
    for i, x in enumerate(range(-39, 42, 6)):
        G.put("house_front", (x, -1.5 * (i % 3 == 1) - 3.0 * (i % 5 == 3), -44.0 - 0.6 * (i % 2)), 0.0, "outside")

    for i, z in enumerate(range(-39, 42, 6)):
        G.put("house_front", (44.0 + 0.6 * (i % 2), -2.0 * (i % 3 == 2), z), -90.0, "outside")

    for x, z in ((-21.0, -43.75), (3.0, -43.75), (27.0, -43.75)):
        G.put("window_lit", (x, 3.0, z), 0.0, "outside")

    for x, z in ((-45.0, -30.0), (-50.0, -18.0), (-42.0, -4.0), (-54.0, 6.0), (-46.0, 18.0), (-52.0, 32.0)):
        G.put("tree", (x, 0, z), 0.0, "outside")

    for x, z in ((-36.0, -12.0), (-38.0, 8.0), (-35.5, 22.0), (-40.0, 36.0)):
        G.put("bush", (x, 0, z), 0.0, "outside")


def layout():
    curtain()
    grounds()
    watchtower()
    gatehouse()
    barracks()
    chapel()
    west_range()
    drill_yard()
    outside()
    import garrison_markers
    garrison_markers.add(G)
    return G.data()
