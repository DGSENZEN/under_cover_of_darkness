"""The level check's rules against small levels, right and broken.

    python3 tools/level/test_rules.py
"""

import copy
import os
import sys
import unittest

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import geo  # noqa: E402
import kit_recipes  # noqa: E402
import rules  # noqa: E402

I = geo.IDENTITY


def piece(name, kind, at, yaw=0.0, sector="yard"):
    return {"name": name, "piece": kind, "sector": sector, "position": list(at), "basis": geo.rotation(yaw)}


def marker(name, ucd, at, props=None, size=None, sector="yard"):
    return {"name": name, "ucd": ucd, "sector": sector, "position": list(at), "basis": I, "size": size, "props": props or {}}


def good():
    return {
        "level": "fixture",
        "pieces": [piece("floor", "floor_cobble_4", (0, 0, 0)), piece("floor2", "floor_cobble_4", (4, 0, 0)),
                   piece("wall", "wall_ashlar_4", (0, 0, -2.2))],
        "markers": [
            marker("bench_spot", "station", (0, 0, 0), {"kind": "sit"}),
            marker("round", "route", (1, 0, 1)),
            marker("round_1", "waypoint", (0.5, 0, 0.5), {"route": "round", "order": 1}),
            marker("round_2", "waypoint", (4.5, 0, 0.5), {"route": "round", "order": 2}),
            marker("Hendrik", "guard", (1, 0, 1), {"archetype": "watchman", "route": "round"}),
            marker("yard_zone", "zone", (2, 1.5, 0), {"grade": "outside"}, size=[8, 3, 4]),
        ],
    }


def checks(route, points):
    """A route's checks: [((x, y, z), move), ...] in order."""
    return [marker("%s_%d" % (route, i + 1), "route_check", at, {"route": route, "order": i + 1, "move": move})
            for i, (at, move) in enumerate(points)]


def gap_level(gap):
    """Two floors, the first to x = 2, the second from x = 2 + gap on."""
    return {"level": "fixture", "markers": [],
            "pieces": [piece("near", "floor_cobble_4", (0, 0, 0)),
                       piece("far", "floor_cobble_4", (2.0 + gap + 2.0, 0, 0)),
                       piece("far_2", "floor_cobble_4", (2.0 + gap + 6.0, 0, 0))]}


def ledge_level(top):
    """A floor in front (z > 0) of a ledge `top` high and 0.4 deep (z -0.4 to 0)."""
    name = "test_ledge_%d" % int(round(top * 100))
    kit_recipes.piece(name, "wall", "ashlar", "stone", [kit_recipes.box(0.0, top / 2.0, -0.2, 4.0, top, 0.4, "ashlar")])
    TEST_PIECES.append(name)
    return {"level": "fixture", "markers": [],
            "pieces": [piece("front", "floor_cobble_4", (0, 0, 2)), piece("ledge", name, (0, 0, 0))]}


# Test-only pieces, removed after each test.
TEST_PIECES = []


class Rules(unittest.TestCase):
    def setUp(self):
        kit_recipes.piece("beam_low", "beam", "timber", "wood", [kit_recipes.box(0.0, 1.7, 0.0, 0.3, 0.2, 3.0, "timber")])
        kit_recipes.piece("crate_stack", "dressing", "boards", "wood", [kit_recipes.box(0.0, 1.0, 0.0, 1.0, 2.0, 1.0, "boards")])
        TEST_PIECES.extend(["beam_low", "crate_stack"])

    def tearDown(self):
        for name in TEST_PIECES:
            kit_recipes.PIECES.pop(name, None)

        TEST_PIECES.clear()

    def test_a_jump_names_its_class(self):
        # two floors 4.6 m apart edge to edge, the same height; the landing
        # 0.3 m past the far edge
        data = gap_level(4.6)
        data["markers"] += checks("leap", [((0, 0, 0), "walk"), ((6.9, 0, 0), "jump")])
        self.assertTrue(any("sprint" in p for p in rules.problems(data)))
        data["markers"][-1]["props"]["move"] = "sprint_jump"
        self.assertEqual(rules.problems(data), [])

    def test_the_uncertain_and_never_gaps(self):
        for gap, word in ((6.3, "uncertain"), (6.6, "never")):
            data = gap_level(gap)
            data["markers"] += checks("leap", [((0, 0, 0), "walk"), ((gap + 2.3, 0, 0), "assist_jump")])
            self.assertTrue(any(word in p for p in rules.problems(data)), gap)

    def test_a_hang_needs_room_under_its_lip(self):
        data = ledge_level(3.6)
        data["markers"] += checks("up", [((0, 0, 1.0), "walk"), ((0, 3.6, -0.2), "hang")])
        self.assertEqual(rules.problems(data), [])
        data["pieces"].append(piece("crate_in_the_way", "crate_stack", (0, 0, 0.6)))
        self.assertTrue(any("room under" in p for p in rules.problems(data)))

    def test_a_mantle_too_high(self):
        data = ledge_level(2.6)
        data["markers"] += checks("up", [((0, 0, 1.0), "walk"), ((0, 2.6, -0.2), "mantle")])
        self.assertTrue(any("mantle" in p and "2.6" in p for p in rules.problems(data)))

    def test_a_drop_too_far(self):
        data = ledge_level(5.0)
        data["markers"] += checks("down", [((0, 5.0, -0.2), "walk"), ((0, 0, 1.0), "drop")])
        self.assertTrue(any("drop" in p for p in rules.problems(data)))

    def test_a_guard_route_under_a_low_beam(self):
        data = good()
        data["pieces"].append(piece("beam", "beam_low", (2.5, 0, 0.5)))
        self.assertTrue(any("headroom" in p for p in rules.problems(data)))

    def test_a_locked_door_needs_its_key_or_a_pick(self):
        data = good()
        data["markers"].append(marker("office_door", "door", (0, 0, -2.2), {"locked": True, "key": "office", "pick": False}))
        self.assertTrue(any("no key 'office'" in p for p in rules.problems(data)))
        data["markers"].append(marker("office_key", "key", (0.5, 0, 0.5), {"key_id": "office"}))
        self.assertEqual(rules.problems(data), [])

    def test_a_key_to_nothing(self):
        data = good()
        data["markers"].append(marker("stray", "key", (0.5, 0, 0.5), {"key_id": "nowhere"}))
        self.assertTrue(any("opens nothing" in p for p in rules.problems(data)))

    def test_a_good_level_passes(self):
        self.assertEqual(rules.problems(good()), [])

    def test_an_unknown_piece(self):
        data = good()
        data["pieces"].append(piece("odd", "wall_marble_9", (0, 0, 0)))
        self.assertTrue(any("no kit piece" in p for p in rules.problems(data)))

    def test_a_decal_of_no_known_kind(self):
        data = good()
        data["markers"].append(marker("stain", "decal", (0, 1, -2), {"kind": "graffiti"}, size=[1, 1, 0.3]))
        self.assertTrue(any("decal kind" in p for p in rules.problems(data)))
        data["markers"][-1]["props"]["kind"] = "leak_1"
        self.assertEqual(rules.problems(data), [])

    def test_a_scaled_piece(self):
        # Scaled in Blender, its mesh would export scaled but its colliders
        # come from the recipe: told, not shipped.
        data = good()
        data["pieces"][2]["scale"] = [1.0, 1.5, 1.0]
        self.assertTrue(any("wall" in p and "scaled" in p for p in rules.problems(data)))
        data["pieces"][2]["scale"] = [1.0, 1.00001, 1.0]
        self.assertEqual(rules.problems(data), [])

    def test_an_unknown_marker(self):
        data = good()
        data["markers"].append(marker("x", "teleporter", (0, 0, 0)))
        self.assertTrue(any("no marker called" in p for p in rules.problems(data)))

    def test_a_station_without_its_kind(self):
        data = good()
        data["markers"][0]["props"] = {}
        self.assertTrue(any("needs 'kind'" in p for p in rules.problems(data)))

    def test_a_guard_on_a_route_that_is_not_there(self):
        data = good()
        data["markers"][4]["props"]["route"] = "nowhere"
        self.assertTrue(any("is not a route" in p for p in rules.problems(data)))

    def test_a_route_of_one_waypoint(self):
        data = good()
        data["markers"] = [m for m in data["markers"] if m["name"] != "round_2"]
        self.assertTrue(any("two waypoints" in p for p in rules.problems(data)))

    def test_a_station_in_the_air(self):
        data = good()
        data["markers"][0]["position"] = [0, 3.0, 0]
        self.assertTrue(any("no floor under it" in p for p in rules.problems(data)))

    def test_a_station_in_a_wall(self):
        data = good()
        data["markers"][0]["position"] = [0, 0, -2.2]
        self.assertTrue(any("inside something" in p for p in rules.problems(data)))

    def test_a_box_marker_without_its_size(self):
        data = good()
        data["markers"][5]["size"] = None
        self.assertTrue(any("needs a size" in p for p in rules.problems(data)))

    def test_a_turned_piece_turns_its_colliders(self):
        # A wall turned a quarter turn at x = 3 stands across x, not z.
        data = good()
        data["pieces"].append(piece("side", "wall_ashlar_4", (3.0, 0, 0), yaw=90.0))
        data["markers"][0]["position"] = [3.0, 0, 1.0]
        self.assertTrue(any("inside something" in p for p in rules.problems(data)))

    def test_over_budget(self):
        data = good()
        data["tris"] = {"floor_cobble_4": 70000}
        self.assertTrue(any("triangles" in p for p in rules.problems(data)))

    def test_two_markers_one_name(self):
        data = good()
        data["markers"].append(copy.deepcopy(data["markers"][0]))
        self.assertTrue(any("two markers have this name" in p for p in rules.problems(data)))

    def test_the_new_markers_pass_when_right(self):
        data = good()
        data["markers"] += [
            marker("purse", "loot", (0.5, 0, 0.5), {"value": 25}),
            marker("seal", "loot", (1.0, 0, 0.5), {"value": 0, "special": True, "kind": "seal", "label": "the harbourmaster's seal"}),
            marker("office_key", "key", (1.5, 0, 0.5), {"key_id": "office"}),
            marker("office_door", "door", (0, 0, -2.2), {"locked": True, "key": "office"}),
            marker("flask", "tool", (2.0, 0, 0.5), {"tool": "flask", "count": 2}),
            marker("crate_1", "prop", (2.5, 0, 0.5), {"kind": "crate"}),
            marker("rope_1", "rope", (3.0, 4, 0.5), {"length": 4.0}),
            marker("roar", "noise_zone", (0, 1, 0), {"db": 30.0}, size=[4, 3, 4]),
            marker("gate_up", "portcullis", (0, 0, -2), {"state": "up"}),
            marker("to_old_town", "exit", (0, 1, 1), {"label": "the old town"}, size=[2, 2, 2]),
            marker("see_moon", "probe", (1, 1, 1), {"expect": "moon"}),
        ]
        self.assertEqual(rules.problems(data), [])

    def test_an_unknown_property(self):
        data = good()
        data["markers"][0]["props"]["colour"] = "red"
        self.assertTrue(any("no property 'colour'" in p for p in rules.problems(data)))

    def test_bad_enums(self):
        for ucd, props, word in (("tool", {"tool": "grenade"}, "tool"), ("prop", {"kind": "piano"}, "prop kind"),
                                 ("probe", {"expect": "sun"}, "expect"), ("guard", {"archetype": "watchman", "light": "flare"}, "light")):
            data = good()
            data["markers"].append(marker("odd", ucd, (0.5, 0, 0.5), props))
            self.assertTrue(any(word in p for p in rules.problems(data)), ucd)

    def test_the_kit_keeps_the_metrics(self):
        self.assertEqual(rules.kit_problems(), [])

    def test_every_piece_is_well_formed(self):
        for name, recipe in kit_recipes.PIECES.items():
            for b in recipe["boxes"] + recipe["cols"]:
                self.assertGreaterEqual(len(b), 7, name)
                self.assertTrue(all(s > 0.0 for s in b[3:6]), name)


if __name__ == "__main__":
    unittest.main(verbosity=1)
