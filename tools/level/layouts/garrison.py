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

    # The flights up to the walk, either side of the gatehouse, against the
    # curtain's inner face (z 26), each to a landing at the walk's height
    # that runs into the walk (a top step alone is too narrow to step off).
    G.stairs((-15.4, 0, 25.3), 90.0, "stair_curtain", "walls")
    G.put("landing_walk", (-7.2, 5.0, 25.3), 0.0, "walls")
    G.stairs((15.4, 0, 25.3), -90.0, "stair_curtain", "walls")
    G.put("landing_walk", (7.2, 5.0, 25.3), 0.0, "walls")


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
    # woodpile, the cart.

    for x, z, yaw in ((0, -0.6, 0.0), (0, 4.6, 180.0), (-2.6, 2, 90.0)):
        G.put("bench", (x, 0, z), yaw, "courtyard")

    G.put("well", (-8, 0, 12), 0.0, "courtyard")
    G.put("cart", (9, 0, 15), 20.0, "courtyard")
    G.put("chopping_block", (-22.3, 0, 16.4), 0.0, "west_range")
    G.put("woodpile", (-24, 0, 18), 0.0, "west_range")

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
    # Flights: north up the east wall, west along the north, south up the
    # west, east along the south; each a steep tower flight (3 m) from the
    # edge of one corner landing to the edge of the next (the middle two
    # landings stand 0.2 off their walls so the flights meet them).
    G.stairs((-28.2, 0.0, -25.6), 180.0, "stair_tower", "tower")
    G.put("landing_2", (-28.4, 3.0, -29.6), 0.0, "tower")
    G.stairs((-29.4, 3.0, -29.8), -90.0, "stair_tower", "tower")
    G.put("landing_2", (-33.4, 6.0, -29.6), 0.0, "tower")
    G.stairs((-33.8, 6.0, -28.6), 0.0, "stair_tower", "tower")
    G.put("landing_2", (-33.4, 9.0, -24.6), 0.0, "tower")
    G.stairs((-32.4, 9.0, -24.2), 90.0, "stair_tower", "tower")
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
    G.wall((-2.2, 22.0), (-2.2, 31.0), "ashlar", 0.0, "gatehouse", openings={2.0: "door"})
    G.wall((2.2, 22.0), (2.2, 31.0), "ashlar", 0.0, "gatehouse", openings={2.0: "arch"})

    # (Over the ground storey they stop under the walk, so its top is one
    # platform from side to side.)
    for x in (-2.2, 2.2):
        for z, length in ((24.0, 4), (28.0, 4), (30.5, 1)):
            G.put("wall_ashlar_low_%d" % length, (x, 3.0, z), 90.0, "gatehouse")
    G.floor(-6, 22, 6, 32, "cobble", 0.0, "gatehouse")
    # The walk over it (top at the curtain's walk), ended flush with the
    # outer wall's face.
    G.floor(-6, 22, 6, 30, "flag", WALK, "gatehouse")

    for x in (-4.0, 0.0, 4.0):
        G.put("floor_flag_strip_4", (x, WALK, 30.5), 0.0, "gatehouse")
    G.put("portcullis", (0, 0, 30.2), 0.0, "gatehouse")
    # Round arches over either end of the passage, proud of the faces; the
    # garrison's banners hung high either side of them, over the windows
    # (the courtyard's face) and the slits (the canal's).
    G.put("gate_arch", (0.0, 0, 21.85), 180.0, "gatehouse")
    G.put("gate_arch", (0.0, 0, 31.15), 0.0, "gatehouse")

    for x in (-4.0, 4.0):
        G.put("banner", (x, 3.2, 21.99), 180.0, "gatehouse")
        G.put("banner", (x, 3.2, 31.01), 0.0, "gatehouse")
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
    # The captain's chamber and the dormitory closed off from the mess
    # hall's height (its banners hang on them).
    G.wall((16.6, -8.0), (29.6, -8.0), "timber", 3.0, s, thin=True)
    G.wall((16.6, 10.0), (29.6, 10.0), "timber", 3.0, s, thin=True)

    for z in range(-7, 10, 2):
        G.put("railing_2", (15.95, 3.0, z), 90.0, s)

    # Stairs: up toward the corridor (-x), arriving on a landing by the
    # gallery's doors.
    G.stairs((22.5, 0.0, -18.0), -90.0, "stair_straight", s)
    G.stairs((22.5, 0.0, 16.0), -90.0, "stair_straight", s)
    # The ceiling under the roof (what stops sight and feet), and the pitched
    # slate roof over it, its ridge along the wing; gable ends; chimneys over
    # the kitchen stove, the great hearth and the dormitory's stove.
    for x in range(14, 30, 4):
        for z in range(-20, 18, 4):
            G.put("ceiling_board_4", (x + 2.0, 6.2, z + 2.0), 0.0, s)

    G.put("roof_16x38", (22.0, 6.2, -1.0), 90.0, s)
    G.put("gable_16", (22.0, 6.2, -19.8), 0.0, s)
    G.put("gable_16", (22.0, 6.2, 17.8), 0.0, s)

    for z in (-11.5, 1.0, 14.0):
        G.put("chimney_6", (29.1, 6.2, z), 0.0, s)

    # Dressing: the mess (two long tables and their benches, the great hearth
    # on the east wall's middle), the kitchen, the dormitory, the captain.
    G.put("hearth", (28.9, 0, 1.0), -90.0, s)

    # The garrison's banners in rows down the mess hall's long walls (the
    # references' rule 8), hung high, either side of its doors (x 23).
    for x in (18.5, 20.8, 25.2, 27.5):
        G.put("banner", (x, 2.9, -7.89), 0.0, s)
        G.put("banner", (x, 2.9, 9.89), 180.0, s)

    # Its trusses (the middle one's corbel clear over the hearth's breast;
    # the chandelier hangs from it), joists under the gallery over the
    # corridor and over the kitchen.
    for z in (-5.5, -2.25, 1.0, 4.25, 7.5):
        G.put("hall_truss_15", (22.0, 0.0, z), 0.0, s)

    for i in range(19):
        G.put("joists_22", (15.45, 2.8, -19.6 + 37.2 / 19.0 * (i + 0.5)), 0.0, s)

    for x in (17.7, 19.7, 21.7, 23.7, 25.7, 27.7, 28.9):
        G.put("joists_72", (x, 2.8, -11.6), 90.0, s)

    for z in (-3.0, 5.0):
        G.put("table_long", (22.0, 0, z), 0.0, s)
        G.put("bench", (22.0, 0, z - 0.9), 0.0, s)
        G.put("bench", (22.0, 0, z + 0.9), 180.0, s)

    # The tables laid; a dresser of plates and the kegs along the north
    # wall, a rack of spears on the south; shields and spears flanking the
    # hearth and over the doors; a cauldron, logs and stools at the fire.
    for z in (-3.0, 5.0):
        G.put("tableware_4", (22.0, 0.79, z), 0.0, s)

    G.put("dresser", (26.4, 0, -7.675), 0.0, s)
    G.put("keg_rack", (19.2, 0, -7.6), 0.0, s)
    G.put("rack", (19.2, 0, 9.75), 180.0, s)

    for x, z in ((27.4, 9.4), (28.2, 9.3)):
        G.put("crate", (x, 0, z), 0.0, s)

    for z in (-4.5, 6.5):
        G.put("shield_trio", (29.58, 2.5, z), -90.0, s)

    G.put("shield_trio", (23.0, 3.3, -7.88), 0.0, s)
    G.put("shield_trio", (23.0, 3.3, 9.88), 180.0, s)
    G.put("cauldron", (27.7, 0, -1.3), 0.0, s)
    G.put("log_basket", (28.1, 0, 3.3), 0.0, s)

    for x, z in ((26.6, 0.3), (26.8, 2.0)):
        G.put("stool", (x, 0, z), 0.0, s)

    # The kitchen: its table spread, hams hung from the joists, a dresser, a
    # cauldron by the stove.
    G.put("stove", (28.6, 0, -11.5), -90.0, s)
    G.put("table_long", (22.0, 0, -11.5), 0.0, s)
    G.put("kitchen_spread", (22.0, 0.79, -11.5), 0.0, s)
    G.put("hanging_food", (19.8, 2.57, -13.6), 0.0, s)
    G.put("hanging_food", (25.2, 2.57, -9.6), 0.0, s)
    G.put("dresser", (26.0, 0, -8.325), 180.0, s)
    G.put("cauldron", (27.6, 0, -9.4), 0.0, s)
    G.put("stool", (20.5, 0, -10.3), 0.0, s)
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
    G.put("banner", (29.58, 3.4, -11.5), -90.0, s)
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

    # The glass in every lancet (panes in the wall's middle, from its sill):
    # the north tier from the floor, the south, west and east tiers a storey
    # up; the ground floor's two windows glazed too.
    # (The north wall's second tier, high under the roof, glazed too.)
    for x in (-2.0, 2.0, 6.0, 10.0):
        G.put("glass_lancet", (x, 1.8, -25.4), 0.0, s)
        G.put("glass_lancet", (x, 7.8, -25.4), 0.0, s)

    for x in (-2.0, 8.0):
        G.put("glass_lancet", (x, 4.8, -16.2), 0.0, s)
        G.put("glass_window", (x, 0.9, -16.2), 0.0, s)

    for x, z in ((-5.8, -20.8), (13.8, -23.2), (13.8, -20.6)):
        G.put("glass_lancet", (x, 4.8, z), 90.0, s)

    # Reliefs lit from below by candle stands: the frieze panels either side
    # of the west door inside, the angels in their reredos behind the altar.
    for z in (-23.5, -18.1):
        G.put("relief_panel", (-5.58, 1.2, z), 90.0, s)
        G.put("candle_stand", (-5.0, 0, z), 0.0, s)

    for x in range(-4, 10, 2):
        G.put("floor_carpet_2", (x + 1.0, 0.02, -20.8), 0.0, s)

    # Pews in rows either side of the aisle, facing the altar (east), clear
    # of the loft stair's foot (x 7.6).
    for x in (-3.6, -2.0, -0.4, 1.2, 2.8, 4.4, 6.0):
        G.put("pew", (x, 0, -23.2), -90.0, s)
        G.put("pew", (x, 0, -18.4), -90.0, s)

    # The chancel: a step of patterned tiles, the altar dressed on it, the
    # reredos behind it, candle stands either side.
    G.put("chapel_dais", (11.8, 0, -21.0), 0.0, s)
    G.put("altar", (11.6, 0.15, -20.8), -90.0, s)
    G.put("reredos", (13.6, 0.15, -20.8), -90.0, s)
    G.put("relief_altar", (13.57, 1.6, -20.8), -90.0, s)

    for z in (-22.8, -18.8):
        G.put("candle_stand", (11.6, 0.15, z), 0.0, s)

    for x in (-2.0, 5.6):
        G.put("candle_stand", (x, 0, -16.7), 0.0, s)

    # Open to its rafters: the ceiling stays (hidden) to stop sight and what
    # is thrown; arch-braced trusses each bay on shafts up the walls, a carved
    # frieze under their corbels; the fish-scale roof over them, the east
    # gable's rose, the west's oculus and bell-cote, the fleche on the ridge.
    for x in range(-6, 14, 4):
        for z in (-26, -22, -18):
            G.put("ceiling_hidden_4", (x + 2.0, 12.2, z + 2.0), 0.0, s)

    for x in (-4.0, 0.0, 4.0, 8.0, 12.0):
        G.put("chapel_truss", (x, 12.0, -20.8), 90.0, s)
        G.put("wall_shaft", (x, 0, -25.2), 0.0, s)

        # (The south wall's shafts clear of its windows.)
        if x != 8.0:
            G.put("wall_shaft", (x, 0, -16.4), 180.0, s)

    # (Not on the north wall: its upper lancets are where it would run.)
    G.put("chapel_frieze_19p2", (4.0, 9.0, -16.4), 180.0, s)
    G.put("chapel_frieze_9p2", (-5.6, 9.0, -20.8), 90.0, s)
    G.put("chapel_frieze_9p2", (13.6, 9.0, -20.8), -90.0, s)
    G.put("roof_10x21", (4.0, 12.0, -20.8), 0.0, s)
    G.put("gable_chapel_west", (-5.8, 12.0, -20.8), 90.0, s)
    G.put("gable_chapel_east", (13.8, 12.0, -20.8), 90.0, s)
    G.put("fleche", (9.0, 17.0, -20.8), 0.0, s)

    # Outside: buttresses between its bays, a plinth, a string course under
    # the lancets, a cornice on corbels under the eaves; a stepped portal
    # round each door.
    for x in (-4.5, 0.0, 5.0, 11.0):
        G.put("buttress_chapel", (x, 0, -16.0), 0.0, s)

    for z in (-24.0, -17.6):
        G.put("buttress_chapel", (-6.0, 0, z), -90.0, s)

    G.put("chapel_plinth_7p0", (-2.5, 0, -16.0), 0.0, s)
    G.put("chapel_plinth_11p0", (8.5, 0, -16.0), 0.0, s)

    for z in (-23.5, -18.1):
        G.put("chapel_plinth_4p2", (-6.0, 0, z), -90.0, s)

    G.put("chapel_course_20p0", (4.0, 4.4, -16.0), 0.0, s)
    G.put("chapel_course_9p6", (-6.0, 4.4, -20.8), -90.0, s)
    G.put("chapel_cornice_20p0", (4.0, 11.7, -16.0), 0.0, s)
    G.put("chapel_cornice_9p6", (-6.0, 11.7, -20.8), -90.0, s)
    G.put("chapel_portal", (2.0, 0, -16.0), 0.0, s)
    G.put("chapel_portal", (-6.0, 0, -20.8), -90.0, s)

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
    # A ladder up the range's north wall from the drill yard onto its roof
    # (in the tower's moon-shadow): a way up for a man who must vanish (its
    # climb is the "range_ladder" marker's).
    G.put("ladder_3", (-25.0, 0, -14.5), 0.0, s)
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

    # The lanes' houses (kit_houses), their fronts to the garrison: six of
    # them in an order that never repeats a neighbour, some set back a
    # little (a town's line, not a wall).
    north = "abcdefcadbfeac"
    east = "dfbeacfdaecbdf"
    depth = 7.0

    for i, x in enumerate(range(-39, 42, 6)):
        G.put("house_" + north[i], (x, 0, -44.0 - depth / 2.0 - 0.6 * (i % 3 == 1)), 0.0, "outside")

    for i, z in enumerate(range(-39, 42, 6)):
        G.put("house_" + east[i], (44.0 + depth / 2.0 + 0.6 * (i % 3 == 2), 0, z), -90.0, "outside")

    # (The corner lot where the lanes meet, built on: no gap onto the sky.)
    G.put("house_e", (44.0 + depth / 2.0, 0, -45.5), -90.0, "outside")



# Nature round the walls (kit_nature): trees on the grassy bank to the west
# and along the canal's far bank, a yew or two, dead trees against the
# moon; shrubs at the wall's foot; grass in tufts over the bank and in the
# cracks at the curtain's feet; reeds along the far bank's edge; ivy up the
# curtain's outer faces, the tower's, and the chapel's west end.
TREES = [("tree_oak", -44.0, -33.0), ("tree_oak", -52.0, -20.0), ("tree_dead", -48.5, -10.5), ("tree_oak", -43.0, -3.0),
         ("tree_oak", -55.0, 5.0), ("tree_yew", -39.0, 13.0), ("tree_oak", -47.0, 19.0), ("tree_dead", -56.5, 24.0),
         ("tree_oak", -52.0, 33.0), ("tree_oak", -58.0, -38.0), ("tree_yew", -38.5, -17.5),
         ("tree_oak", -38.0, 77.5), ("tree_dead", -24.0, 78.0), ("tree_oak", -5.0, 77.0), ("tree_oak", 11.0, 78.5),
         ("tree_oak", 27.0, 77.0), ("tree_yew", 41.0, 76.5)]
SHRUBS = [(-36.0, -12.0), (-37.5, 8.0), (-35.5, 22.0), (-40.0, 36.0), (-41.5, -26.0), (-50.0, -2.0), (-44.0, 27.0),
          (-31.0, 74.5), (4.0, 74.8), (33.0, 74.4), (-12.0, 75.5)]
# (Kept clear of: the hiding place by the tower's foot; the gate, the
# lean-to under the breach, the postern and the climb on the south; the lamps
# on the far bank.)
KEEP_CLEAR = [(-33.6, -30.0, 1.5), (0.0, 30.0, 7.5), (9.0, 30.0, 2.5), (24.0, 29.0, 2.0), (18.0, 29.0, 1.5), (-16.0, 73.5, 1.2), (20.0, 73.5, 1.2)]


def _clear(x, z, taken):
    for cx, cz, r in KEEP_CLEAR + taken:
        if (x - cx) ** 2 + (z - cz) ** 2 < r * r:
            return False

    return True


def nature():
    import random
    rng = random.Random(1848)
    taken = []

    for kind, x, z in TREES:
        G.put(kind, (x, 0, z), rng.uniform(0.0, 360.0), "outside")
        taken.append((x, z, 1.4))

    for x, z in SHRUBS:
        G.put("bush", (x, 0, z), rng.uniform(0.0, 360.0), "outside")
        taken.append((x, z, 1.2))

    # Grass: over the west bank and the far bank, in the cracks along the
    # curtain's outer feet, a little in the drill yard's corners.
    fields = [((-59.0, -33.5), (-43.0, 43.0), 95, "outside"), ((-49.0, 49.0), (72.6, 79.5), 40, "outside"),
              ((-30.0, 30.0), (28.5, 29.3), 18, "outside"), ((-30.0, 30.0), (-29.3, -28.5), 14, "outside"),
              ((32.5, 33.3), (-26.0, 26.0), 12, "outside"), ((-29.6, -26.0), (22.5, 25.6), 5, "courtyard"),
              ((25.0, 29.6), (22.5, 25.6), 5, "courtyard")]

    for (x0, x1), (z0, z1), count, sector in fields:
        placed = 0

        for _ in range(count * 6):
            if placed >= count:
                break

            x, z = rng.uniform(x0, x1), rng.uniform(z0, z1)

            if _clear(x, z, taken):
                G.put("grass_tuft", (round(x, 2), 0.0, round(z, 2)), rng.uniform(0.0, 180.0), sector)
                placed += 1

    # Reeds along the far bank's edge, in clumps.
    x = -48.0

    while x < 48.0:
        for _ in range(rng.randint(1, 3)):
            rx, rz = x + rng.uniform(-0.8, 0.8), 72.4 + rng.uniform(0.0, 0.9)

            if _clear(rx, rz, []):
                G.put("reeds_clump", (round(rx, 2), 0.0, round(rz, 2)), rng.uniform(0.0, 180.0), "outside")

        x += rng.uniform(2.5, 5.5)

    # Ivy: up the curtain's outer faces (west x -32.4, south z 28.4, north
    # z -28.4), the tower's west and north faces, the chapel's west end (in
    # its corners by the buttresses, clear of its door).
    ivy = [(-32.4, 0.0, -18.0, -90.0, 2), (-32.4, 0.0, -9.5, -90.0, 2), (-32.4, 3.0, -9.5, -90.0, 1), (-32.4, 0.0, -2.0, -90.0, 1),
           (-32.4, 0.0, 6.0, -90.0, 2), (-32.4, 3.0, 6.5, -90.0, 2), (-32.4, 0.0, 14.5, -90.0, 1), (-32.4, 0.0, 21.0, -90.0, 2),
           (-26.0, 0.0, 28.4, 0.0, 2), (-18.0, 0.0, 28.4, 0.0, 1), (-11.0, 0.0, 28.4, 0.0, 2), (-11.0, 3.0, 28.4, 0.0, 1),
           (14.0, 0.0, 28.4, 0.0, 1), (28.0, 0.0, 28.4, 0.0, 2), (-20.0, 0.0, -28.4, 180.0, 2), (-5.0, 0.0, -28.4, 180.0, 1),
           (12.0, 0.0, -28.4, 180.0, 2), (25.0, 0.0, -28.4, 180.0, 1), (-35.0, 0.0, -27.5, -90.0, 2), (-35.0, 3.0, -25.5, -90.0, 2),
           (-32.0, 0.0, -31.0, 180.0, 2), (-6.4, 0.0, -24.95, -90.0, 1), (-6.4, 1.8, -24.95, -90.0, 1), (-6.4, 0.0, -16.7, -90.0, 1)]

    for x, y, z, yaw, size in ivy:
        G.put("ivy_2x3" if size == 2 else "ivy_1x2", (x, y, z), yaw, "chapel" if abs(x + 6.4) < 0.1 else "outside")


def weeds():
    """Clumps of weeds along the curtain's outer feet, in the drill yard's and
    the wood yard's corners (a fixed scatter: the same every build)."""
    import random
    rng = random.Random(1932)
    spots = []

    for x in range(-28, 30, 3):
        spots.append((x + rng.uniform(-0.8, 0.8), 28.8 + rng.uniform(0.0, 0.5)))
        spots.append((x + rng.uniform(-0.8, 0.8), -28.8 - rng.uniform(0.0, 0.5)))

    for z in range(-26, 28, 3):
        spots.append((32.8 + rng.uniform(0.0, 0.5), z + rng.uniform(-0.8, 0.8)))

    for x, z in ((-26.5, -25.3), (-24.0, -25.4), (-8.5, -25.2), (-27.0, -15.6), (-29.2, 25.2), (-26.4, 25.3), (-21.0, 25.4)):
        spots.append((x, z))

    for i, (x, z) in enumerate(spots):
        G.put("weeds", (round(x, 2), 0.0, round(z, 2)), rng.uniform(0, 180), "outside" if abs(x) > 31 or abs(z) > 28 else "courtyard")


def layout():
    weeds()
    nature()
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
