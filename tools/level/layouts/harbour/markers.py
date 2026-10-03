"""What plays on the harbour: its nine guards and their rounds, its lights,
its water and air, its loot, keys, tools and chests, its doors, the exits to
the districts not yet built, the probes of its light, the views, and its
ways into the walled city as route checks (each move the rules measure)."""

import math

import kit_customs
import kit_harbour
import kit_iberian
import kit_recipes

from lay import facing

from .ground import FAR, NEAR_SEA
from . import (ARCADE_FRONT, CARRACK_X, CARRACK_Z, CUSTOMS, CUSTOMS_AT, CUSTOMS_EAVES, CUSTOMS_UPPER, GATE_X, MAINYARD_Y, MOLE_HEAD, MOLE_X, QUAY, SEA_WALL, WALK, WALL_D, WALL_E, WALL_F,
               NAVE_BAYS, NAVES, WALL_RIB, WALL_W, STAIR_X, along, nave_x, nave_z, rib_x, stair_y)
from .mole import CAP, PARAPET, TOP as MOLE_TOP, head_yaw, line as mole_line

MOLE_CAP = PARAPET[2] + CAP[1]
from .ribeira import ROOF_HOUSE
from .ships import START_BOAT

TERRACE = MOLE_TOP + 18.0
ROOF_EAVES = QUAY + kit_recipes.PIECES["casa_d"]["eaves"]
# Where each exit leads (data/districts.json): the old town's four gates to
# their arrivals there; the river and the undercroft sealed until built.
LEADS = {"exit_sea_gate": ("old_town", "from_harbour_sea_gate"), "exit_wall_walk": ("old_town", "from_harbour_wall_walk"),
         "exit_guindais": ("old_town", "from_harbour_guindais"), "exit_west_wall": ("old_town", "from_harbour_west_wall"),
         "exit_river": ("gorge", ""), "exit_undercroft": ("undercroft", "")}


def _terrace(radius, angle):
    """A point on the golden tower's first terrace (angle in degrees, from
    +x toward +z)."""
    a = math.radians(angle)
    return (MOLE_HEAD[0] + radius * math.cos(a), TERRACE, MOLE_HEAD[1] + radius * math.sin(a))


def _eye(at):
    """A man's eye over a floor's point."""
    return (at[0], at[1] + 1.7, at[2])


def _tower_local(x, y, z):
    """A point in the golden tower's frame (its door on its -z flat) in the
    world."""
    yaw = math.radians(head_yaw())
    return (MOLE_HEAD[0] + x * math.cos(yaw) + z * math.sin(yaw), MOLE_TOP + y, MOLE_HEAD[1] - x * math.sin(yaw) + z * math.cos(yaw))


def _boulder_near(z):
    """The top of a boulder in the riprap at the mole's seaward foot (its
    straight run) near z: (x, top, z)."""
    laid = [st for k, st in enumerate(mole_line()[:-2]) if k % 2 == 1 and abs(st[0] - MOLE_X) < 1e-6]
    px, pz = min(((st[0], st[1]) for st in laid), key=lambda p: abs(p[1] - z))
    best = max(kit_recipes.PIECES["riprap_8"]["cols"], key=lambda c: c[1] + c[4] / 2.0 - abs(c[0]) * 0.1)
    # (Along the straight run the riprap is turned a quarter: its local z
    # runs east, x north.)
    return (px + kit_harbour.RIPRAP + best[2], best[1] + best[4] / 2.0, pz - best[0])


def _checks(L, route, points, sector):
    for i, (at, move) in enumerate(points):
        L.mark("%s_%d" % (route, i + 1), "route_check", at, sector=sector, route=route, order=i + 1, move=move)


def _guards(L):
    L.mark("Rodrigo", "guard", (GATE_X - 2.5, QUAY, WALL_D + 3.7), 180.0, "terreiro", archetype="swordsman", look_seed=11)
    L.mark("Tome", "guard", (GATE_X + 2.5, QUAY, WALL_D + 3.7), 180.0, "terreiro", archetype="watchman", look_seed=12)
    L.route("quays_round", [(-170.0, QUAY, -3.0), (-104.0, QUAY, -3.0), (-70.0, QUAY, -3.0), (-40.0, QUAY, -3.0), (-14.0, QUAY, -3.0),
                            (40.0, QUAY, -3.0)], sector="terreiro")
    L.mark("Duarte", "guard", (-170.0, QUAY, -3.0), 90.0, "ribeira", archetype="watchman", route="quays_round", light="lantern", look_seed=13)
    L.mark("Inigo", "guard", (-40.0, QUAY, -3.0), -90.0, "terreiro", archetype="swordsman", route="quays_round", light="lantern", look_seed=14)
    L.route("customs_round", [(0.0, QUAY, -12.0), (10.5, QUAY, -12.0), (10.5, QUAY, -24.0), (1.0, QUAY, -26.0)], sector="shipyard", wait=2.0)
    L.mark("Baltasar", "guard", (0.0, QUAY, -12.0), 0.0, "shipyard", archetype="watchman", route="customs_round", look_seed=15)
    L.route("deck_round", [(35.5, 2.0, CARRACK_Z - 1.5), (46.5, 2.0, CARRACK_Z - 1.5)], sector="ships", wait=3.0)
    L.mark("Leonor", "guard", (35.5, 2.0, CARRACK_Z - 1.5), -90.0, "ships", archetype="duelist", route="deck_round", look_seed=16)
    L.mark("Gaspar", "guard", _terrace(5.7, 150.0), 60.0, "mole", archetype="archer", lookout=True, look_seed=17)
    L.route("mole_round", [(161.0, MOLE_TOP, 8.0), (161.0, MOLE_TOP, 138.0), (104.0, MOLE_TOP, 188.0), (161.0, MOLE_TOP, 140.0)], sector="mole")
    L.mark("Fernao", "guard", (161.0, MOLE_TOP, 8.0), 180.0, "mole", archetype="watchman", route="mole_round", look_seed=18)
    L.route("shipyard_round", [(37.4, QUAY, -14.0), (37.4, QUAY, -62.0), (54.2, QUAY, -62.0), (54.2, QUAY, -14.0)], sector="shipyard")
    L.mark("Afonso", "guard", (37.4, QUAY, -14.0), 0.0, "shipyard", archetype="brute", route="shipyard_round", look_seed=19)
    L.mark("tower_bell", "bell", _terrace(5.7, 120.0), 0.0, "mole")


def _lights(L):
    for x in (-80.0, -55.0, -30.0):
        for z in (-52.0, -16.0):
            L.mark("lamp_%d_%d" % (-x, -z), "light", (x, QUAY, z), 0.0, "terreiro", kind="lamp_post")

    L.mark("gate_torch_w", "light", (GATE_X - 3.5, QUAY + 4.0, WALL_D + 1.6), 0.0, "terreiro", kind="torch")
    L.mark("gate_torch_e", "light", (GATE_X + 3.5, QUAY + 4.0, WALL_D + 1.6), 0.0, "terreiro", kind="torch")
    L.mark("gate_brazier", "light", (GATE_X, QUAY, WALL_D + 7.0), 0.0, "terreiro", kind="brazier")
    L.mark("sea_gate_portcullis", "portcullis", (GATE_X, QUAY, WALL_D + 0.7), 0.0, "terreiro", state="up", width=4.0, height=5.0,
           label="the Sea Gate's portcullis")

    # The arcade's lanterns far apart: dark stretches under it between them.
    for i in (2, 8, 12):
        L.mark("arcade_lantern_%d" % i, "light", (rib_x(i), QUAY + 3.3, -8.0), 0.0, "ribeira", kind="lantern")

    L.mark("nave_brazier_w", "light", (29.0, QUAY, -30.0), 0.0, "shipyard", kind="brazier")
    L.mark("nave_brazier_e", "light", (96.0, QUAY, -40.0), 0.0, "shipyard", kind="brazier")
    L.mark("galley_torch", "light", (42.4, QUAY + 2.4, -25.2), 0.0, "shipyard", kind="torch", energy=1.0)
    L.mark("customs_lantern", "light", (2.0, QUAY + 3.2, -20.0), 0.0, "shipyard", kind="lantern")
    L.mark("office_candle", "light", (9.15, CUSTOMS_UPPER + 1.0, -28.28), 0.0, "shipyard", kind="candle")
    # (By the customs house's portal in the loggia, over the king's beam.)
    L.mark("portal_lantern", "light", (6.4, QUAY + 2.9, -9.6), 0.0, "shipyard", kind="lantern")
    L.mark("stern_lantern", "light", (CARRACK_X - 15.8, 10.2, CARRACK_Z), 0.0, "ships", kind="lantern")
    L.mark("cabin_candle", "light", (CARRACK_X - 12.0, 2.85, CARRACK_Z), 0.0, "ships", kind="candle", energy=0.6)
    L.mark("cabin_lantern", "light", (CARRACK_X - 9.6, 4.45, CARRACK_Z), 0.0, "ships", kind="lantern", energy=0.7)
    L.mark("caravel_lantern", "light", (-110.5, 5.0, 5.5), 0.0, "ships", kind="lantern")
    L.mark("beacon", "light", (MOLE_HEAD[0] - 3.2, TERRACE + 9.0, MOLE_HEAD[1] - 1.2), 0.0, "mole", kind="brazier")
    L.mark("tower_door_lantern", "light", _tower_local(1.2, 3.1, -8.1), 0.0, "mole", kind="lantern")
    L.mark("fort_lantern", "light", (-75.0, 19.4, 207.8), 0.0, "fort", kind="lantern")
    L.mark("smugglers_lamp", "light", (230.0, 2.2, 22.0), 0.0, "cave", kind="glow", color="#ffb060", energy=0.8, range=8.0)


def _water_and_air(L):
    # (The open sea out past the world's wall; its shore surveyed and its
    # guards' swim baked over the harbour's own bed.)
    x0, z0, x1, z1 = FAR
    L.mark("the_sea", "water", ((x0 + x1) / 2.0, -6.0, (z0 + z1) / 2.0), size=[x1 - x0, 12.0, z1 - z0], sector="sea", murk=0.5,
           shore_area=list(NEAR_SEA), swim_area=list(NEAR_SEA))
    L.mark("the_river", "water", (-215.0, -1.5, -80.0), size=[42.0, 3.0, 140.0], sector="river", murk=0.7)
    # (The slip's basin: up its slipway past where the ramp goes under, its
    # surface running in under the stone, no edge of water short of it; out
    # to the sea's own, meeting it without overlapping.)
    L.mark("the_basin", "water", (71.0, -2.0, -20.5), size=[8.4, 4.0, 21.0], sector="shipyard", murk=0.7)
    # The blowhole: its shaft's mouth up on the headland, the cave and the
    # headland round it masked while it roars.
    L.mark("blowhole_roar", "noise_zone", (232.0, 12.0, 0.0), size=[34.0, 32.0, 44.0], sector="cave", db=45.0, period=11.0,
           label="the blowhole")
    L.mark("zone_terreiro", "zone", (-55.0, 10.0, -38.0), size=[86.0, 18.0, 76.0], sector="terreiro", grade="outside", fog=1.0)
    L.mark("zone_sea_gate", "zone", (GATE_X, 5.0, WALL_D - 9.8), size=[4.0, 5.0, 16.0], sector="terreiro", grade="indoors", fog=1.2)
    L.mark("zone_shipyard", "zone", (66.8, 8.0, -37.8), size=[100.8, 12.0, 58.8], sector="shipyard", grade="indoors", fog=1.3)
    L.mark("zone_customs", "zone", (2.0, (QUAY + CUSTOMS_EAVES) / 2.0, -20.0), size=[24.0, CUSTOMS_EAVES - QUAY, 28.0], sector="shipyard",
           grade="indoors", fog=1.1)
    L.mark("zone_cave", "zone", (230.0, 4.0, 20.0), size=[30.0, 14.0, 80.0], sector="cave", grade="cellar", fog=1.5)
    L.mark("zone_cabin", "zone", (CARRACK_X - 10.5, 3.5, CARRACK_Z), size=[9.0, 3.0, 7.6], sector="ships", grade="hearth", fog=1.0)
    L.mark("zone_tower_room", "zone", (MOLE_HEAD[0], MOLE_TOP + 2.5, MOLE_HEAD[1]), size=[12.0, 5.0, 12.0], sector="mole", grade="indoors")

    for name, at, kind, yaw, floor in (("moss_steps_w", (-150.0, 0.8, 0.25), "moss", 0.0, False), ("moss_steps_c", (20.0, 0.8, 0.25), "moss", 0.0, False),
                                       ("moss_steps_e", (110.0, 0.8, 0.25), "moss", 0.0, False), ("salt_ribeira", (-120.0, 1.8, 0.25), "salt", 0.0, False),
                                       ("salt_customs", (4.0, 1.8, 0.25), "salt", 0.0, False), ("salt_mole", (150.0, 1.8, 0.25), "salt", 0.0, False),
                                       ("leak_seawall_1", (30.0, 10.0, SEA_WALL - 1.5), "leak_1", 180.0, False),
                                       ("leak_seawall_2", (100.0, 9.0, SEA_WALL - 1.5), "leak_2", 180.0, False)):
        L.mark(name, "decal", at, yaw, "shipyard" if "seawall" in name else "ribeira", size=[4.0, 2.0, 0.6], kind=kind, floor=floor)


def _things(L):
    x0, x1, z0, z1 = CUSTOMS
    office = CUSTOMS_UPPER
    # (Its portal in the hall's front behind the loggia; its back door.)
    L.mark("customs_front", "door", (CUSTOMS_AT[0] + kit_customs.PORTAL[0], QUAY, CUSTOMS_AT[1] + kit_customs.HALL_FRONT - kit_customs.WALL / 2.0), 0.0,
           "shipyard", locked=True, key="customs_front", label="the customs house", width=kit_customs.PORTAL[1], height=kit_customs.PORTAL[2])
    L.mark("customs_back", "door", (10.0, QUAY, z0 + kit_customs.WALL / 2.0), 0.0, "shipyard", label="the yard door")
    # The hoist's rope down before the loading door (a way into the upper
    # floor: up it, across onto the door's sill).
    L.mark("hoist_rope", "rope", (CUSTOMS_AT[0] + kit_customs.LOADING[0], QUAY + kit_customs.EAVES - 0.8, z1 + 1.65), 0.0, "shipyard", length=5.6)
    L.mark("customs_postern", "door", (WALL_F, QUAY, -20.0), 90.0, "shipyard", label="the postern")
    L.mark("office_door", "door", (7.0, office, -22.0), 0.0, "shipyard", locked=True, key="customs_office", pick=False, label="the office")
    L.mark("cabin_door", "door", (CARRACK_X - 6.0, 2.0, CARRACK_Z), 90.0, "ships", label="the cabin")
    L.mark("tower_door", "door", _tower_local(0.0, 0.0, -6.75), head_yaw(), "mole", locked=True, label="the tower's door", width=1.6, height=2.6)
    L.mark("customs_office_key", "key", (6.0, QUAY + 0.85, -13.0), 0.0, "shipyard", key_id="customs_office", label="the office key")
    L.mark("cabin_key", "key", (CARRACK_X, QUAY + 0.75, -0.8), 0.0, "shipyard", key_id="cabin", label="the cabin's key")
    L.mark("seal_chest", "chest", (12.0, office, -30.0), 180.0, "shipyard", locked=True, label="the harbourmaster's strongbox")
    L.mark("cabin_strongbox", "chest", (CARRACK_X - 13.0, 2.0, CARRACK_Z + 2.2), 90.0, "ships", locked=True, key="cabin", pick=False,
           label="the captain's strongbox")
    L.mark("smugglers_chest", "chest", (234.0, 1.35, 21.0), -90.0, "cave", label="a smugglers' chest")

    loot = [("the_seal", (12.0, office + 0.15, -30.0), 250, "the harbourmaster's seal", {"special": True, "kind": "seal"}, "shipyard"),
            ("office_purse", (9.0, office + 0.86, -28.15), 60, "a purse", {}, "shipyard"),
            ("inkwell", (9.95, office + 0.86, -27.85), 80, "a silver inkwell", {}, "shipyard"),
            ("silk", (-4.0, QUAY + 0.8, -12.0), 100, "a bolt of silk", {}, "shipyard"),
            ("pepper", (-5.2, QUAY + 1.45, -18.0), 90, "a sack of pepper", {}, "shipyard"),
            ("wine", (-3.0, QUAY + 0.95, -24.0), 70, "a flask of wine", {}, "shipyard"),
            ("candlesticks", (9.0, QUAY + 1.45, -28.0), 120, "silver candlesticks", {}, "shipyard"),
            ("captains_gold", (CARRACK_X - 13.0, 2.2, CARRACK_Z + 2.2), 200, "the captain's gold", {}, "ships"),
            ("captains_ring", (CARRACK_X - 12.8, 2.2, CARRACK_Z + 2.2), 150, "a gold ring", {}, "ships"),
            ("spyglass", (CARRACK_X - 13.0, 8.1, CARRACK_Z), 60, "a spyglass", {}, "ships"),
            ("lookouts_purse", _terrace(5.9, 60.0), 40, "a purse", {}, "mole"),
            ("chainmasters_purse", (MOLE_HEAD[0] + 2.0, MOLE_TOP + 0.1, MOLE_HEAD[1] + 1.0), 50, "the chainmaster's purse", {}, "mole"),
            ("powder_money", (-80.0, 4.1, 196.0), 120, "the powder money", {}, "fort"),
            ("signet", (-70.0, 4.1, 196.0), 80, "a signet ring", {}, "fort"),
            ("brandy", (227.5, 2.7, 20.0), 90, "smuggled brandy", {}, "cave"),
            ("lace", (229.0, 2.2, 11.0), 110, "smuggled lace", {}, "cave"),
            ("silver_dish", (233.0, 2.3, 16.0), 140, "a silver dish", {}, "cave"),
            ("arcade_purse", (-160.0, QUAY + 0.1, -9.5), 30, "a purse", {}, "ribeira"),
            ("copper_pan", (-110.0, QUAY + 0.1, -9.5), 25, "a copper pan", {}, "ribeira"),
            ("astrolabe", (-120.0, 1.6, 5.5), 45, "an astrolabe", {}, "ships"),
            ("fish_money", (-150.0, 0.3, 3.6), 15, "fish money", {}, "ships"),
            ("offering", (GATE_X, QUAY + 3.6, -31.5), 35, "an offering purse", {}, "terreiro"),
            ("shipwrights_tools", (48.8, QUAY + 4.5, -40.0), 60, "a shipwright's tools", {}, "shipyard"),
            ("tar_money", (140.0, QUAY + 0.1, -22.0), 20, "tar money", {}, "shipyard")]

    for name, at, value, label, extra, sector in loot:
        L.mark(name, "loot", at, 0.0, sector, value=value, label=label, **extra)

    L.mark("objective_seal", "objective", (12.0, office + 0.5, -30.0), 0.0, "shipyard", label="the harbourmaster's seal")
    L.mark("flask_arcade", "tool", (-140.0, QUAY + 0.1, -9.5), 0.0, "ribeira", tool="flask", count=2)
    L.mark("flask_caravel", "tool", (-118.0, 1.6, 5.5), 0.0, "ships", tool="flask")

    for name, at, sector in (("crate_terreiro", (-30.0, QUAY + 0.3, -4.0), "terreiro"), ("crate_nave", (60.0, QUAY + 0.3, -30.0), "shipyard"),
                             ("crate_ribeira", (-125.0, QUAY + 0.3, -4.0), "ribeira")):
        L.mark(name, "prop", at, 0.0, sector, kind="crate")

    L.mark("rope_down_the_wall", "rope", (147.0, WALK - 0.1, SEA_WALL - 2.6), 0.0, "shipyard", length=11.5)
    L.mark("powder_room", "secret", (-75.0, 5.0, 196.0), 0.0, "fort", size=[14.0, 2.0, 4.0], label="the powder room")


def _exits_and_views(L):
    for name, at, size, label, sector in (
            ("exit_sea_gate", (GATE_X, QUAY + 1.2, WALL_D - 16.5), [4.0, 2.4, 2.0], "the old town (the Sea Gate)", "terreiro"),
            ("exit_wall_walk", (WALL_E, WALK + 1.2, WALL_D + 3.0), [3.0, 2.4, 3.0], "the old town (the wall-walk)", "shipyard"),
            ("exit_guindais", (-184.5, stair_y(-91.0) + 1.2, -91.0), [3.0, 2.4, 2.0], "the old town's upper gate", "ribeira"),
            ("exit_west_wall", (WALL_W, stair_y(-116.0) + 12.0, -116.0), [3.0, 3.0, 3.0], "the old town (the west wall)", "ribeira"),
            ("exit_river", (-215.0, 0.0, -147.0), [40.0, 4.0, 4.0], "the gorge (the river)", "river"),
            ("exit_undercroft", (232.0, 2.0, -9.0), [5.0, 3.0, 2.0], "the undercroft (sealed)", "cave")):
        to, arrive = LEADS[name]
        L.mark(name, "exit", at, 0.0, sector, size=size, label=label, to=to, arrive=arrive)

    # Coming back from the old town: just outside each gate, facing the harbour.
    for name, at, sector in (("from_old_town_sea_gate", (GATE_X, QUAY, -62.0), "terreiro"),
                             ("from_old_town_wall_walk", (WALL_E, WALK, -64.0), "shipyard"),
                             ("from_old_town_guindais", (STAIR_X, stair_y(-85.0), -85.0), "ribeira"),
                             ("from_old_town_west_wall", (WALL_W, stair_y(-109.4) + 12.0, -109.4), "ribeira")):
        L.mark(name, "arrival", at, 180.0, sector)

    L.mark("start", "spawn", (START_BOAT[0], START_BOAT[1] - 0.12, START_BOAT[2]), facing(START_BOAT, (160.0, 0.0, 60.0)), "ships")
    L.mark("blowhole", "mark", (232.0, 26.0, 0.0), 0.0, "cave")

    for name, at, look, lens in (("view_mole_start", (175.0, 4.5, 118.0), (60.0, 60.0, -150.0), "wide"),
                                 ("view_quay_rock", (-40.0, 6.0, 45.0), (-45.0, 60.0, -300.0), "wide"),
                                 ("view_terreiro_stair", (GATE_X, 3.5, 3.0), (GATE_X, 8.0, -70.0), ""),
                                 ("view_sea_gate", (GATE_X, 4.2, -60.0), (GATE_X, 8.0, -76.0), ""),
                                 ("view_ribeira", (-120.0, 6.0, 12.0), (-150.0, 12.0, -14.0), ""),
                                 ("view_nave", (58.6, 4.2, -12.0), (58.6, 6.0, -67.0), ""),
                                 ("view_galley", (43.3, 6.5, -20.0), (45.8, 3.5, -40.0), ""),
                                 ("view_carrack_top", (CARRACK_X, 21.7, CARRACK_Z), (CARRACK_X, 20.0, -80.0), "wide"),
                                 ("view_golden_terrace", _eye(_terrace(5.2, 250.0)), (0.0, 10.0, 0.0), "wide"),
                                 ("view_cave_beach", (230.0, 2.5, 10.0), (226.0, 3.0, 60.0), "")):
        # (Looking at its subject: up at the rock, down at the galley.)
        pitch = math.degrees(math.atan2(look[1] - at[1], math.hypot(look[0] - at[0], look[2] - at[2])))
        L.mark(name, "vantage", at, facing(at, look), "sea", pitch=pitch, lens=lens)

    for name, at, label, sector in (("lm_sea_gate", (GATE_X, QUAY, WALL_D + 6.0), "the Sea Gate", "terreiro"),
                                    ("lm_golden_tower", (MOLE_HEAD[0] + 8.0, MOLE_TOP, MOLE_HEAD[1] - 13.0), "the golden tower", "mole"),
                                    ("lm_customs", (1.6, QUAY, -3.0), "the customs house", "shipyard"),
                                    ("lm_shipyard", (66.0, QUAY, -3.0), "the shipyard", "shipyard"),
                                    ("lm_ribeira", (-140.0, QUAY, -3.0), "the Ribeira", "ribeira"),
                                    ("lm_mole", (163.0, MOLE_TOP, 70.0), "the mole", "mole"),
                                    ("lm_carrack", (CARRACK_X, QUAY, -2.0), "the carrack", "shipyard")):
        L.mark(name, "landmark", at, 0.0, sector, label=label)

    for name, at, sector in (("hide_arcade_w", (-157.0, QUAY, -9.0), "ribeira"), ("hide_arcade_e", (-121.0, QUAY, -9.0), "ribeira"),
                             ("hide_terreiro_arcade", (-92.5, QUAY, -40.0), "terreiro"), ("hide_nave_5", (58.6, QUAY, -55.0), "shipyard"),
                             ("hide_nave_9", (88.0, QUAY, -30.0), "shipyard"), ("hide_customs_yard", (4.0, QUAY, -60.0), "shipyard")):
        L.mark(name, "hide", at, 0.0, sector)

    for name, centre, size, label in (("area_ribeira", (-140.0, 8.0, -10.0), [92.0, 16.0, 24.0], "the Ribeira"),
                                      ("area_terreiro", (-55.0, 8.0, -45.0), [86.0, 16.0, 94.0], "the Terreiro"),
                                      ("area_shipyard", (70.0, 8.0, -36.0), [162.0, 16.0, 74.0], "the shipyard"),
                                      ("area_mole", (130.0, 12.0, 105.0), [100.0, 24.0, 220.0], "the mole"),
                                      ("area_fort", (-75.0, 15.0, 205.0), [40.0, 30.0, 40.0], "the fort"),
                                      ("area_cave", (230.0, 10.0, 20.0), [30.0, 30.0, 82.0], "the cave")):
        L.mark(name, "hunt_area", centre, 0.0, "sea", size=size, label=label)

    for i, at in enumerate(((175.0, 4.0, 118.0), (160.0, 5.0, 40.0), (100.0, 5.0, -1.0), (40.0, 5.0, -2.0), (-20.0, 5.0, -30.0),
                            (GATE_X, 5.0, -50.0), (-100.0, 5.0, -3.0), (-160.0, 5.0, -3.0))):
        L.mark("bench_%d" % (i + 1), "mark", at, 0.0, "sea")


def _ways_in(L):
    # The carrack's: aboard over its bulwark, up the shrouds to the top, down
    # onto the main yard, along it over the sea wall, down onto the walk.
    _checks(L, "way_carrack", [((CARRACK_X, QUAY, -3.0), "walk"), ((CARRACK_X, 2.0, 2.6), "jump"), ((CARRACK_X, 20.0, CARRACK_Z - 1.4), "climb"),
                               ((CARRACK_X, MAINYARD_Y + 0.25, 1.5), "drop"), ((CARRACK_X, MAINYARD_Y + 0.25, SEA_WALL - 0.3), "balance"),
                               ((CARRACK_X, WALK, SEA_WALL - 0.3), "drop")], "ships")
    # The roofs': up casa_d's old vine to its eaves, onto its roof, over its
    # ridge and a merlon onto the Ribeira wall's walk.
    x = rib_x(ROOF_HOUSE)
    vine = x + kit_iberian.VINE_X
    front = ARCADE_FRONT
    # (Over a merlon, not through a crenel: one is 0.9 m, the thief 1.0 m.)
    merlon = x - 1.5
    _checks(L, "way_roofs", [((vine, QUAY, -3.0), "walk"), ((vine, QUAY, front + 0.6), "walk"), ((vine, ROOF_EAVES - 0.1, front + 0.3), "climb"),
                             ((vine, ROOF_EAVES + 0.5, front - 1.0), "mantle"), ((x, QUAY + 15.2, -13.0), "walk"), ((merlon, QUAY + 12.8, -19.8), "walk"),
                             ((merlon, WALK + 1.8, WALL_RIB + 0.9), "mantle"), ((merlon, WALK, WALL_RIB - 0.3), "drop")], "ribeira")
    # The Nasrid gate's: swim in through it, up the slipway.
    _checks(L, "way_nasrid", [((71.0, -0.5, 8.0), "swim"), ((71.0, -0.5, -7.0), "swim"), ((71.0, -0.5, -20.0), "swim"),
                              ((71.0, -1.7, -26.5), "swim"), ((71.0, QUAY, -34.5), "walk")], "shipyard")
    # The mole's: from the boat onto a boulder, up the parapet, down on top.
    boulder = _boulder_near(START_BOAT[2])
    _checks(L, "way_mole", [((START_BOAT[0], START_BOAT[1] - 0.12, START_BOAT[2]), "walk"), (boulder, "mantle"),
                            ((MOLE_X + 6.2, MOLE_CAP, boulder[2]), "hang"), ((MOLE_X + 3.0, MOLE_TOP, boulder[2]), "drop")], "mole")
    # The Sea Gate's and the customs house's: walked.
    _checks(L, "way_gate", [((GATE_X, QUAY, -60.0), "walk"), ((GATE_X, QUAY, WALL_D - 6.0), "walk"), ((GATE_X, QUAY, WALL_D - 15.0), "walk")],
            "terreiro")
    _checks(L, "way_customs", [((1.6, QUAY, -3.0), "walk"), ((5.0, QUAY, -8.0), "walk"), ((5.0, QUAY, -14.0), "walk"), ((10.0, QUAY, -20.0), "walk"),
                               ((WALL_F + 2.5, QUAY, -20.0), "walk")], "shipyard")


def _probes(L):
    for name, at, expect, sector in (("probe_arcade", (rib_x(5), QUAY + 1.0, -8.5), "shadow", "ribeira"),
                                     ("probe_terreiro", (GATE_X, QUAY + 1.0, -50.0), "lamp", "terreiro"),
                                     ("probe_mole", (163.0, MOLE_TOP + 1.0, 60.0), "moon", "mole"),
                                     ("probe_nave", (58.6, QUAY + 1.0, -45.0), "shadow", "shipyard"),
                                     ("probe_deck", (CARRACK_X + 3.0, 3.0, CARRACK_Z), "moon", "ships"),
                                     ("probe_office", (10.0, CUSTOMS_UPPER + 1.0, -28.0), "lamp", "shipyard"),
                                     ("probe_beach", (231.0, 1.8, 8.0), "shadow", "cave"),
                                     ("probe_bastion", (-75.0, 5.0, 214.0), "moon", "fort")):
        L.mark(name, "probe", at, 0.0, sector, expect=expect)


def _roofs(L):
    # Under roofs (kit_recipes.roofed: no shadow from them in moonlight):
    # what is stored in the customs house's hall and up in its store, not
    # in its loggia, open to the harbour; the yard's work under the naves'
    # vaults (not on their terrace).
    # (Inside its walls' faces: the hoist hangs outside its front.)
    wall = kit_customs.WALL
    x0, x1, z0, z1 = CUSTOMS[0] + wall, CUSTOMS[1] - wall, CUSTOMS[2] + wall, CUSTOMS[3] - wall
    front = CUSTOMS_AT[1] + kit_customs.HALL_FRONT - wall
    L.mark("roofed_customs_hall", "roofed", ((x0 + x1) / 2.0, QUAY + kit_customs.UP / 2.0, (z0 + front) / 2.0), 0.0, "shipyard",
           size=[x1 - x0, kit_customs.UP, front - z0])
    L.mark("roofed_customs_store", "roofed", ((x0 + x1) / 2.0, (CUSTOMS_UPPER + CUSTOMS_EAVES) / 2.0, (z0 + z1) / 2.0), 0.0, "shipyard",
           size=[x1 - x0, CUSTOMS_EAVES - CUSTOMS_UPPER, z1 - z0])
    height = kit_harbour.TERRACE - 0.5
    L.mark("roofed_naves", "roofed", ((nave_x(0) + nave_x(NAVES)) / 2.0, QUAY + height / 2.0, (nave_z(0) + nave_z(NAVE_BAYS)) / 2.0), 0.0,
           "shipyard", size=[nave_x(NAVES) - nave_x(0), height, nave_z(0) - nave_z(NAVE_BAYS)])


def _rooms(L):
    # Rooms (the real-windows spec, 4): a window's lamps are the lights in
    # its room, and they throw out through its glass. The hall and the store
    # are the roofed boxes; the office (upstairs, the north-east corner)
    # inside the store's, from its walls; the carrack's cabin, its zone.
    wall = kit_customs.WALL
    x0, x1, z0, z1 = CUSTOMS[0] + wall, CUSTOMS[1] - wall, CUSTOMS[2] + wall, CUSTOMS[3] - wall
    front = CUSTOMS_AT[1] + kit_customs.HALL_FRONT - wall
    L.mark("room_customs_hall", "room", ((x0 + x1) / 2.0, QUAY + kit_customs.UP / 2.0, (z0 + front) / 2.0), 0.0, "shipyard",
           size=[x1 - x0, kit_customs.UP, front - z0])
    L.mark("room_customs_store", "room", ((x0 + x1) / 2.0, (CUSTOMS_UPPER + CUSTOMS_EAVES) / 2.0, (z0 + z1) / 2.0), 0.0, "shipyard",
           size=[x1 - x0, CUSTOMS_EAVES - CUSTOMS_UPPER, z1 - z0])
    ox, oz = CUSTOMS_AT[0] + kit_customs.OFFICE[0], CUSTOMS_AT[1] + kit_customs.OFFICE[1]
    L.mark("room_customs_office", "room", ((ox + x1) / 2.0, (CUSTOMS_UPPER + CUSTOMS_EAVES) / 2.0, (z0 + oz) / 2.0), 0.0, "shipyard",
           size=[x1 - ox, CUSTOMS_EAVES - CUSTOMS_UPPER, oz - z0])
    L.mark("room_carrack_cabin", "room", (CARRACK_X - 10.5, 3.5, CARRACK_Z), 0.0, "ships", size=[9.0, 3.0, 7.6])


def lay(L):
    _guards(L)
    _lights(L)
    _water_and_air(L)
    _things(L)
    _exits_and_views(L)
    _ways_in(L)
    _probes(L)
    _roofs(L)
    _rooms(L)
