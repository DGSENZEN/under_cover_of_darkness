"""The garrison's markers: its people, their stations and rounds, the doors,
the lights (each space lit on purpose: the garrison spec, sections 6.3 and
11), the bell, the canal, the climb, the hiding places, the hunt areas, the
camera's vantages, the atmosphere zones and the marks the story plays on.
Called by garrison.layout() with its Layout."""

from lay import facing

WALK = 5.0
FIRE = (0.0, 0.0, 2.0)


def add(G):
    people(G)
    doors(G)
    lights(G)
    things(G)
    hiding(G)
    camera(G)
    zones(G)
    story(G)
    decals(G)


# ---------------------------------------------------------------------------
# The cast: where each stands at the start, what he does
# ---------------------------------------------------------------------------

def people(G):
    at_fire = lambda p: facing(p, FIRE)
    G.mark("Mirelle", "guard", (2.6, 0, 0.8), at_fire((2.6, 0, 0.8)), archetype="duelist", temperament="steady", look_seed=11, role="captain")
    G.mark("Osric", "guard", (2.8, 0, 3.4), at_fire((2.8, 0, 3.4)), archetype="swordsman", temperament="steady", look_seed=12)
    G.mark("Brand", "guard", (-21.6, 0, 16.4), 90.0, "west_range", archetype="brute", temperament="rash", look_seed=13, stations="chop_brand")
    G.mark("Wat", "guard", (-24.0, WALK, 26.8), 180.0, "walls", archetype="archer", temperament="sly", look_seed=14, route="wall_round")
    G.mark("Aldous", "guard", (-31.0, 12.0, -27.0), 45.0, "tower", archetype="watchman", temperament="stubborn", look_seed=15, lookout=True, role="lookout")
    G.mark("Hendrik", "guard", (-17.6, 0, -1.5), -90.0, "west_range", archetype="watchman", temperament="steady", look_seed=16, role="colonnade")
    G.mark("Piers", "guard", (0.0, 0, -0.1), 180.0, archetype="watchman", temperament="craven", look_seed=17, stations="sit_piers")
    G.mark("Col", "guard", (22.0, 0, -1.6), 0.0, "barracks", archetype="watchman", temperament="steady", look_seed=18, stations="eat_col")
    G.mark("Tam", "guard", (24.8, 3.0, 13.2), 0.0, "barracks", archetype="watchman", temperament="steady", look_seed=19, stations="sleep_tam")
    G.mark("Gideon", "guard", (-26.0, 0, -12.2), 0.0, "west_range", archetype="watchman", temperament="steady", look_seed=20,
           stations="chest_0,chest_1,chest_2,pray_0", role="quartermaster")
    G.mark("Ned", "guard", (-22.6, 0, 9.4), 0.0, "west_range", archetype="watchman", temperament="craven", look_seed=21, stations="carry_ned",
           role="carrier")
    G.mark("Jory", "guard", (0.0, 0, 4.1), 0.0, archetype="watchman", temperament="steady", look_seed=22, stations="sit_bench")

    # Stations: seats at the fire's benches, the mess, the dormitory, the
    # chests, the crates, the block, the walk's rail, the chapel, the straw men.
    G.mark("sit_piers", "station", (0.0, 0, -0.1), 180.0, kind="sit")
    G.mark("sit_bench", "station", (0.0, 0, 4.1), 0.0, kind="sit")
    G.mark("sit_side", "station", (-2.1, 0, 2.0), -90.0, kind="sit")

    for i, (x, z, yaw) in enumerate(((22.0, -1.6, 0.0), (20.5, -4.4, 180.0), (22.0, 6.4, 180.0), (23.5, 3.6, 0.0))):
        G.mark("eat_col" if i == 0 else "eat_%d" % i, "station", (x, 0, z), yaw, "barracks", kind="eat")

    for i, (x, z) in enumerate(((24.8, 13.2), (20.2, 14.0), (27.4, 14.0))):
        G.mark("sleep_tam" if i == 0 else "sleep_%d" % i, "station", (x, 3.0, z), 0.0, "barracks", kind="sleep")

    for i, (x, z, yaw) in enumerate(((-26.0, -12.25, 0.0), (-23.0, -12.25, 0.0), (-27.45, -10.0, 90.0))):
        G.mark("chest_%d" % i, "station", (x, 0, z), yaw, "west_range", kind="rummage", chest="chest_box_%d" % i)

    G.mark("carry_ned", "station", (-22.6, 0, 9.4), 0.0, "west_range", kind="carry", drop_to="crates_drop")
    G.mark("chop_brand", "station", (-21.6, 0, 16.4), 90.0, "west_range", kind="chop")
    G.mark("lean_walk", "station", (2.0, WALK, 26.9), 180.0, "walls", kind="lean")
    G.mark("pray_0", "station", (9.6, 0, -21.6), -90.0, "chapel", kind="pray")
    G.mark("pray_1", "station", (9.6, 0, -20.0), -90.0, "chapel", kind="pray")
    G.mark("drill_0", "station", (-22.0, 0, -19.8), 0.0, kind="drill")
    G.mark("drill_1", "station", (-19.0, 0, -19.8), 0.0, kind="drill")

    # Rounds: the walk (Wat's), the yard, the barracks' corridor and gallery.
    G.route("wall_round", [(-24.0, WALK, 26.8, 180.0), (24.0, WALK, 26.8, 180.0)], "walls")
    G.route("yard_round", [(-12.0, 0, -12.0, 135.0), (10.0, 0, -12.0, -135.0), (10.0, 0, 18.0, -45.0), (-12.0, 0, 18.0, 45.0)])
    G.route("barracks_round", [(15.4, 0, -18.0, 180.0), (15.4, 0, 16.0, 0.0)], "barracks")


# ---------------------------------------------------------------------------
# Doors (at their opening's middle, turned as their wall)
# ---------------------------------------------------------------------------

def doors(G):
    for name, at, yaw, sector, extra in (
        ("barracks_north_door", (14.2, 0, -12.0), 90.0, "barracks", {}),
        ("barracks_south_door", (14.2, 0, 6.0), 90.0, "barracks", {}),
        ("barracks_back_door", (26.0, 0, -19.8), 0.0, "barracks", {}),
        ("stair_hall_door", (16.6, 0, -17.6), 90.0, "barracks", {}),
        ("kitchen_door", (16.6, 0, -11.6), 90.0, "barracks", {}),
        ("south_hall_door", (16.6, 0, 13.0), 90.0, "barracks", {}),
        ("kitchen_stairs_door", (23.0, 0, -15.2), 0.0, "barracks", {}),
        ("kitchen_mess_door", (23.0, 0, -8.0), 0.0, "barracks", {}),
        ("mess_south_door", (23.0, 0, 10.0), 0.0, "barracks", {}),
        ("north_landing_door", (16.6, 3.0, -17.6), 90.0, "barracks", {}),
        ("captain_door", (16.6, 3.0, -11.6), 90.0, "barracks", {"locked": True, "key": "captain_key", "label": "the captain's door", "barred": True}),
        ("dormitory_door", (16.6, 3.0, 14.0), 90.0, "barracks", {}),
        ("chapel_south_door", (2.0, 0, -16.2), 0.0, "chapel", {"label": "the chapel door"}),
        ("chapel_west_door", (-5.8, 0, -20.8), 90.0, "chapel", {}),
        ("armoury_door", (-20.2, 0, -8.0), 90.0, "west_range", {"label": "the armoury door"}),
        ("storehouse_door", (-20.2, 0, 4.0), 90.0, "west_range", {"label": "the storehouse door"}),
        ("armoury_store_door", (-25.6, 0, -2.0), 0.0, "west_range", {}),
        ("guardroom_door", (-2.2, 0, 24.0), 90.0, "gatehouse", {}),
        ("tower_door", (-29.0, 0, -23.2), 0.0, "tower", {}),
        ("postern_door", (24.0, 0, 26.0), 0.0, "walls", {"label": "the postern"}),
    ):
        G.mark(name, "door", at, yaw, sector, **extra)


# ---------------------------------------------------------------------------
# Lights: each space lit on purpose
# ---------------------------------------------------------------------------

def lights(G):
    L = lambda name, kind, at, sector="courtyard", yaw=0.0, **p: G.mark(name, "light", at, yaw, sector, kind=kind, **p)
    # The courtyard: its fire (the showcase's Fire), torches at the doors, the
    # gate's, the walk's cressets, the postern's dim one; the colonnade dark
    # but for its ends.
    L("fire", "brazier", FIRE)
    L("torch_barracks_n", "torch", (13.7, 2.3, -10.7), energy=1.8)
    L("torch_barracks_s", "torch", (13.7, 2.3, 7.3), energy=1.8)
    L("torch_chapel", "torch", (3.3, 2.3, -15.7), energy=1.6)
    L("torch_colonnade_n", "torch", (-19.7, 2.3, -12.6), "west_range", energy=1.2)
    L("torch_colonnade_s", "torch", (-19.7, 2.3, 5.3), "west_range", energy=1.2)
    L("torch_gate_w", "torch", (-2.7, 2.6, 31.5), "gatehouse", energy=2.2)
    L("torch_gate_e", "torch", (2.7, 2.6, 31.5), "gatehouse", energy=2.2)
    L("torch_postern", "torch", (24.9, 2.3, 25.7), energy=0.7)
    L("torch_back", "torch", (26.9, 2.3, -20.3), energy=1.2)
    L("cresset_walk_w", "torch", (-16.0, WALK + 1.4, 26.4), "walls", energy=1.6)
    L("cresset_walk_e", "torch", (16.0, WALK + 1.4, 26.4), "walls", energy=1.6)
    L("cresset_tower", "torch", (-31.0, 13.4, -27.0), "tower", energy=1.6)
    L("torch_tower_foot", "torch", (-28.0, 2.3, -23.7), "tower", energy=1.2)
    # The gate passage: one brazier, behind the lattice (its bars' shadows).
    L("brazier_gate", "brazier", (4.0, 0, 24.0), "gatehouse")
    L("torch_guardroom", "torch", (-5.3, 2.3, 26.0), "gatehouse", energy=1.2)
    # The barracks: corridor sconces spaced so pools alternate with dark, the
    # gallery's, the mess's hearth and candles, the kitchen's lantern, the
    # stair halls', the dormitory's banked stove, the captain's candles.
    for i, z in enumerate((-16.0, -8.0, 0.0, 9.0, 15.0)):
        L("sconce_%d" % i, "torch", (14.7, 2.3, z), "barracks", energy=1.4, range=7.0)

    L("sconce_gallery_n", "torch", (14.7, 5.3, -14.0), "barracks", energy=1.2, range=7.0)
    L("sconce_gallery_s", "torch", (14.7, 5.3, 12.0), "barracks", energy=1.2, range=7.0)
    L("hearth_mess", "hearth", (28.3, 0, 1.0), "barracks", -90.0)
    L("candles_mess_0", "candle", (21.0, 0.79, -3.0), "barracks")
    L("candles_mess_1", "candle", (23.0, 0.79, 5.0), "barracks")
    # A chandelier from the mess hall's middle truss over its tables, candles
    # on its dresser.
    L("chandelier_mess", "chandelier", (22.0, 5.28, 1.0), "barracks", chain=2.3)
    L("candles_dresser", "candle", (26.4, 0.88, -7.55), "barracks")
    L("lantern_kitchen", "lantern", (22.0, 2.9, -11.5), "barracks")
    L("lantern_stairs_n", "lantern", (19.5, 2.9, -16.0), "barracks")
    L("lantern_stairs_s", "lantern", (19.5, 2.9, 14.4), "barracks")
    L("stove_dormitory", "glow", (28.1, 3.6, 14.0), "barracks", color="#ff7a30", energy=0.7, range=5.0)
    L("candles_captain", "candle", (23.0, 3.88, -11.5), "barracks")
    # The chapel: the chandeliers, candles on stands and the altar, moonlight
    # through the north lancets as coloured shafts (the moon is in the
    # north-west; the shafts fall south across the pews).
    # (The chandeliers hung from the trusses' tie beams, 4 m of chain.)
    # (Reaching far enough to catch the roof's timbers over them.)
    L("chandelier_w", "chandelier", (0.0, 11.98, -20.8), "chapel", chain=3.98, range=12.0)
    L("chandelier_e", "chandelier", (8.0, 11.98, -20.8), "chapel", chain=3.98, range=12.0)

    # (The chancel's two on its step; the reliefs' by the west door.)
    for i, (x, y, z) in enumerate(((11.6, 1.6, -22.8), (11.6, 1.6, -18.8), (-5.0, 1.45, -23.5), (-5.0, 1.45, -18.1), (-2.0, 1.45, -16.7),
                                   (5.6, 1.45, -16.7))):
        L("candle_stand_%d" % i, "candle", (x, y, z), "chapel")

    L("candles_altar_0", "candle", (11.6, 1.25, -21.7), "chapel")
    L("candles_altar_1", "candle", (11.6, 1.25, -19.9), "chapel")

    for i, (x, colour) in enumerate(((-2.0, "#ff4a2a"), (2.0, "#ffb347"), (6.0, "#ff4a2a"), (10.0, "#ffb347"))):
        L("shaft_%d" % i, "window_shaft", (x - 1.9, 5.4, -27.2), "chapel", color=colour, energy=5.0, range=14.0)

    # The west range: the armoury's torch, the storehouse's lantern, the
    # cellar's one green lantern.
    L("torch_armoury", "torch", (-20.7, 2.3, -11.0), "west_range", energy=1.3)
    L("lantern_store", "lantern", (-25.0, 2.8, 5.0), "west_range")
    L("lantern_cellar", "lantern", (-25.0, -1.2, 5.0), "cellar", color="#6f9f55", energy=1.1)
    # Outside: lamp posts on the quay and the lanes.
    # (The north lane's close before its houses, whose fronts the moon never
    # reaches.)
    for i, (x, z) in enumerate(((-10.0, 40.0), (14.0, 40.0), (-20.0, -41.0), (20.0, -41.0), (38.0, 0.0), (-16.0, 73.5), (20.0, 73.5),
                                (0.0, -41.0), (-36.0, -41.0), (36.0, -41.0), (38.5, -24.0))):
        L("lamp_%d" % i, "lamp_post", (x, 0, z), "outside")


# ---------------------------------------------------------------------------
# Things the game makes: the bell, the canal, the climb, chests, crates
# ---------------------------------------------------------------------------

def things(G):
    G.mark("bell", "bell", (7.0, 0, 19.5), 180.0)
    G.mark("canal", "water", (0.0, -2.5, 58.5), 0.0, "outside", size=(100.0, 3.0, 27.0), murk=0.7)
    G.mark("wall_climb", "ladder", (18.0, 2.5, 28.65), 0.0, "walls", size=(1.2, 5.0, 0.7))
    G.mark("range_ladder", "ladder", (-25.0, 1.7, -14.7), 180.0, "west_range", size=(1.0, 3.4, 0.6))

    for i, (x, z, yaw) in enumerate(((-26.0, -13.2, 0.0), (-23.0, -13.2, 0.0), (-28.4, -10.0, 90.0))):
        # (the chest faces its station: its front toward +z, or +x for the third)
        G.mark("chest_box_%d" % i, "mark", (x, 0, z), yaw + 180.0, "west_range")

    for i in range(8):
        G.mark("cargo_%d" % i, "mark", (-23.6 + (i % 4) * 0.66, 0.6 + (i // 4) * 0.52, 10.4), 0.0, "west_range")

    G.mark("crates_drop", "mark", (-18.2, 0, -11.0), 0.0, "west_range")
    G.mark("woodpile", "mark", (-24.0, 0, 18.0), 0.0, "west_range")
    G.mark("gather_dice", "mark", (3.6, 0, 7.0))
    G.mark("gather_story", "mark", FIRE)

    for name, at, label in (
        ("lm_fire", FIRE, "the fire"), ("lm_well", (-8.0, 0, 12.0), "the well"), ("lm_gate", (0.0, 0, 26.0), "the gate"),
        ("lm_chapel", (4.0, 0, -20.8), "the chapel"), ("lm_mess", (22.0, 0, 1.0), "the mess"), ("lm_armoury", (-25.0, 0, -8.0), "the armoury"),
        ("lm_store", (-25.0, 0, 5.0), "the storehouse"), ("lm_cellar", (-25.0, -3.0, 5.0), "the cellar"), ("lm_postern", (24.0, 0, 25.0), "the postern"),
        ("lm_tower", (-31.0, 0, -27.0), "the tower"), ("lm_colonnade", (-18.0, 0, 2.0), "the colonnade"), ("lm_walk", (0.0, WALK, 26.8), "the wall"),
        ("lm_dormitory", (23.0, 3.0, 14.0), "the dormitory"), ("lm_captain", (23.0, 3.0, -11.5), "the captain's room"),
    ):
        G.mark(name, "landmark", at, label=label)


# ---------------------------------------------------------------------------
# Hiding places and hunt areas
# ---------------------------------------------------------------------------

def hiding(G):
    for i, (at, sector) in enumerate((
        ((-17.6, 0, -3.0), "west_range"), ((-17.6, 0, 9.0), "west_range"), ((19.2, 0, -16.6), "barracks"),
        ((29.0, 0, -14.4), "barracks"), ((15.2, 3.0, 16.8), "barracks"), ((27.6, 3.0, 11.0), "barracks"),
        ((-4.8, 0, -24.8), "chapel"), ((12.8, 0, -24.8), "chapel"), ((13.2, 3.0, -16.8), "chapel"),
        ((-9.4, 0, 13.4), "courtyard"), ((10.4, 0, 16.8), "courtyard"), ((-24.0, 0, 19.6), "west_range"),
        ((-28.6, 0, 16.0), "west_range"), ((-28.8, -3.0, 10.4), "cellar"), ((-12.0, 0, -24.4), "courtyard"),
        ((29.0, 0, -25.0), "courtyard"), ((29.0, 0, 20.8), "courtyard"), ((-5.0, 0, 23.2), "gatehouse"),
        ((-33.6, 0, -30.0), "tower"), ((17.4, 0, 8.6), "barracks"),
    )):
        G.mark("hide_%d" % i, "hide", at, 0.0, sector)

    for name, centre, size, label in (
        ("area_barracks", (22.1, 3.25, -4.0), (16.2, 7.5, 44.0), "the barracks"),
        ("area_barracks_ground", (22.1, 1.0, -4.0), (16.2, 3.0, 44.0), "the barracks' ground floor"),
        ("area_chapel", (4.0, 3.25, -21.0), (20.4, 7.5, 10.0), "the chapel"),
        ("area_west", (-23.0, 0.0, 3.0), (16.0, 7.0, 36.0), "the west range and the cellar"),
        ("area_walls", (-1.0, 9.25, 1.0), (68.0, 9.5, 64.0), "the walls and the tower"),
        ("area_courtyard", (-1.0, 1.0, 14.5), (30.0, 4.0, 61.0), "the courtyard and the quay"),
    ):
        G.mark(name, "hunt_area", centre, 0.0, size=size, label=label)


# ---------------------------------------------------------------------------
# The camera's vantages: high corners, framing through foreground, the
# symmetric axes, the enfilade down the corridor
# ---------------------------------------------------------------------------

def camera(G):
    for name, at, lens, sector in (
        ("v_courtyard_sw", (-14.0, 7.0, 20.0), "long", "courtyard"), ("v_courtyard_ne", (12.0, 7.0, -14.0), "long", "courtyard"),
        ("v_gatehouse_top", (0.0, 7.5, 23.0), "long", "gatehouse"), ("v_palisade", (-13.0, 1.4, -17.4), "medium", "courtyard"),
        ("v_colonnade", (-18.4, 1.6, 0.0), "medium", "west_range"), ("v_gallery", (15.4, 4.8, -6.0), "medium", "barracks"),
        ("v_corridor", (15.4, 1.7, -19.0), "long", "barracks"), ("v_mess_axis", (17.4, 1.7, 1.0), "medium", "barracks"),
        ("v_chapel_axis", (-4.6, 1.8, -20.8), "long", "chapel"), ("v_chapel_loft", (13.0, 4.8, -17.4), "medium", "chapel"),
        ("v_dormitory", (17.4, 4.7, 16.8), "medium", "barracks"), ("v_cellar", (-27.0, -1.2, 11.4), "medium", "cellar"),
        ("v_quay", (0.0, 1.2, 38.0), "long", "outside"), ("v_tower", (-31.0, 13.6, -27.0), "long", "tower"),
        ("v_walk", (-10.0, 6.6, 26.8), "medium", "walls"), ("v_back_yard", (27.0, 1.6, -24.0), "medium", "courtyard"),
    ):
        G.mark(name, "vantage", at, 0.0, sector, lens=lens)


# ---------------------------------------------------------------------------
# Atmosphere zones (outside is the default)
# ---------------------------------------------------------------------------

def zones(G):
    for name, centre, size, grade, fog, colour in (
        ("zone_barracks", (22.0, 3.0, -1.0), (16.0, 6.0, 38.0), "indoors", 1.2, ""),
        ("zone_mess", (23.1, 3.0, 1.0), (13.0, 6.0, 18.0), "hearth", 1.4, ""),
        ("zone_chapel", (4.0, 6.0, -20.8), (20.0, 12.0, 9.6), "chapel", 2.2, "#b0654a"),
        ("zone_cellar", (-25.0, -1.6, 5.0), (10.0, 3.2, 14.0), "cellar", 2.6, ""),
        ("zone_range", (-25.0, 1.6, -1.0), (10.0, 3.2, 26.0), "indoors", 1.2, ""),
        ("zone_gatehouse", (0.0, 2.5, 26.5), (12.0, 5.0, 9.0), "indoors", 1.1, ""),
        ("zone_tower", (-31.0, 6.0, -27.0), (8.0, 12.0, 8.0), "indoors", 1.0, ""),
    ):
        G.mark(name, "zone", centre, 0.0, "courtyard", size=size, grade=grade, fog=fog, fog_color=colour)


# ---------------------------------------------------------------------------
# The story's marks (ShowNight reads them by name)
# ---------------------------------------------------------------------------

def story(G):
    for name, at, sector in (
        ("gate", (0.0, 0, 26.0), "gatehouse"), ("gate_out", (0.0, 0, 34.0), "outside"),
        ("postern_post", (24.0, 0, 24.6), "courtyard"),
        ("wall_foot", (18.0, 0, 30.2), "outside"), ("drop_in", (-9.0, WALK, 26.8), "walls"),
        ("colonnade_wait", (-18.8, 0, 1.0), "west_range"), ("colonnade_post", (-17.6, 0, -1.5), "west_range"),
        ("hide", (-28.8, -3.0, 10.4), "cellar"), ("gone_to_ground", (-26.0, 3.2, -9.0), "west_range"),
        ("sneak_1", (19.2, 0, -16.6), "barracks"), ("sneak_2", (14.8, 3.0, -2.0), "barracks"),
        ("sneak_3", (13.0, 3.0, -17.4), "chapel"), ("chapel_hide", (-4.6, 0, -24.8), "chapel"),
        ("chapel_fight", (2.0, 0, -20.8), "chapel"),
        ("captain_door_at", (15.6, 3.0, -11.6), "barracks"),
        ("escape_stairs", (22.4, 3.0, 16.0), "barracks"), ("escape_door", (13.4, 0, 6.0), "courtyard"),
        ("escape_climb", (14.0, 0, 24.0), "walls"), ("escape_walk", (8.0, WALK, 27.4), "walls"),
        ("escape_over", (9.0, 0, 32.6), "outside"), ("canal_edge", (10.0, 0, 43.6), "outside"),
        ("canal_swim", (10.0, -1.0, 47.0), "outside"),
        ("courtyard_fight", (0.0, 0, 10.0), "courtyard"), ("gate_passage", (0.0, 0, 27.6), "gatehouse"),
    ):
        G.mark(name, "mark", at, 0.0, sector)


# ---------------------------------------------------------------------------
# Decals: moss at the walls' feet outside, leaks down from sills and eaves,
# grime along the bottoms of the courtyard's walls. Each faces into its wall
# (local -z); its size across, up and how deep it reaches.
# ---------------------------------------------------------------------------

def decals(G):
    count = [0]

    def D(kind, at, yaw, size, sector="courtyard"):
        count[0] += 1
        G.mark("decal_%d" % count[0], "decal", at, yaw, sector, size=size, kind=kind)

    # Moss along the curtain's outer feet, the towpath's side and the north.
    for x in range(-24, 28, 8):
        D("moss", (float(x), 0.35, 28.6), 0.0, (4.0, 0.7, 0.8), "outside")
        D("moss", (float(x), 0.35, -28.6), 180.0, (4.0, 0.7, 0.8), "outside")

    # Leaks: under the barracks' upper windows and the chapel's south lancets,
    # down the gatehouse's front, under the curtain's walk inside.
    for i, z in enumerate((-12.0, -6.0, 0.0, 6.0, 12.0)):
        D("leak_1" if i % 2 == 0 else "leak_2", (13.9, 4.3, z), -90.0, (1.3, 1.8, 0.8), "barracks")

    for x in (-2.0, 8.0):
        D("leak_2", (x, 3.9, -16.0), 0.0, (1.1, 1.6, 0.8), "chapel")

    for x in (-4.0, 4.0):
        D("leak_1", (x, 4.2, 31.0), 0.0, (1.4, 2.0, 0.8), "gatehouse")

    for x in (-20.0, -12.0, 12.0, 20.0):
        D("leak_2", (x, 3.6, 25.9), 180.0, (1.6, 2.2, 0.8), "walls")

    # Grime along the bottoms of the barracks' front and the colonnade's back wall.
    for z in (-18.0, -12.0, -6.0, 0.0, 6.0, 12.0):
        D("grime", (13.9, 0.45, z), -90.0, (4.0, 0.9, 0.8), "barracks")

    for z in (-12.0, -6.0, 0.0, 6.0):
        D("grime", (-20.0, 0.45, z), 90.0, (4.0, 0.9, 0.8), "west_range")
