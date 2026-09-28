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


class Rules(unittest.TestCase):
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

    def test_the_kit_keeps_the_metrics(self):
        self.assertEqual(rules.kit_problems(), [])

    def test_every_piece_is_well_formed(self):
        for name, recipe in kit_recipes.PIECES.items():
            for b in recipe["boxes"] + recipe["cols"]:
                self.assertGreaterEqual(len(b), 7, name)
                self.assertTrue(all(s > 0.0 for s in b[3:6]), name)


if __name__ == "__main__":
    unittest.main(verbosity=1)
