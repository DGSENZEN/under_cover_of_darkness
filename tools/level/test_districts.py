"""The city's districts: the registry, the gates between districts and the
rules that check them across levels.

    python3 tools/level/test_districts.py
"""

import copy
import os
import sys
import unittest

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "layouts"))

import districts  # noqa: E402
import rules  # noqa: E402
from test_rules import good, marker  # noqa: E402

REG = {"start": "a", "districts": {"a": {"levels": ["la"]}, "b": {"levels": ["lb"]}}, "unbuilt": ["gorge"]}


def level(name):
    """The rules' good level as `name`, its markers renamed after it (so two
    such levels share no names)."""
    data = copy.deepcopy(good())
    data["level"] = name

    for m in data["markers"]:
        m["name"] = name + "_" + m["name"]

        if m["ucd"] == "waypoint":
            m["props"]["route"] = name + "_" + m["props"]["route"]

        if m["ucd"] == "guard" and m["props"].get("route"):
            m["props"]["route"] = name + "_" + m["props"]["route"]

    return data


def exit_to(name, to, arrive=""):
    return marker(name, "exit", (0, 1, 0), {"label": "on", "to": to, "arrive": arrive}, size=[2, 2, 2])


class Districts(unittest.TestCase):
    def test_an_arrival_stands_on_a_floor(self):
        data = good()
        data["markers"].append(marker("from_x", "arrival", (0, 5.0, 0)))
        self.assertTrue(any("from_x" in p and "no floor" in p for p in rules.problems(data)))
        data["markers"][-1]["position"] = [0.5, 0.0, 0.5]
        self.assertEqual(rules.problems(data), [])

    def test_an_exit_to_a_district_needs_its_arrival(self):
        la, lb = level("la"), level("lb")
        la["markers"].append(exit_to("exit_x", "b", "from_a_x"))
        found = rules.district_problems(REG, {"la": la, "lb": lb})
        self.assertTrue(any("exit_x" in p and "from_a_x" in p for p in found), found)
        lb["markers"].append(marker("from_a_x", "arrival", (0.5, 0, 0.5)))
        self.assertEqual(rules.district_problems(REG, {"la": la, "lb": lb}), [])

    def test_an_exit_to_no_district(self):
        la, lb = level("la"), level("lb")
        la["markers"].append(exit_to("exit_x", "atlantis"))
        found = rules.district_problems(REG, {"la": la, "lb": lb})
        self.assertTrue(any("exit_x" in p and "atlantis" in p for p in found), found)

    def test_an_exit_to_an_unbuilt_district_is_sealed(self):
        la, lb = level("la"), level("lb")
        la["markers"].append(exit_to("exit_x", "gorge"))
        self.assertEqual(rules.district_problems(REG, {"la": la, "lb": lb}), [])

    def test_an_exit_to_a_built_district_without_arrive(self):
        la, lb = level("la"), level("lb")
        la["markers"].append(exit_to("exit_x", "b"))
        found = rules.district_problems(REG, {"la": la, "lb": lb})
        self.assertTrue(any("exit_x" in p and "arrive" in p for p in found), found)

    def test_names_are_unique_across_districts(self):
        la, lb = level("la"), level("lb")
        la["markers"].append(marker("Inigo", "hide", (0.5, 0, 0.5)))
        lb["markers"].append(marker("Inigo", "hide", (0.5, 0, 0.5)))
        found = rules.district_problems(REG, {"la": la, "lb": lb})
        self.assertIn("Inigo: in la and lb", found)

    def test_a_district_of_a_level(self):
        self.assertEqual(districts.district_of(REG, "lb"), "b")
        self.assertIsNone(districts.district_of(REG, "lc"))

    def test_the_registry(self):
        registry = districts.load()
        self.assertEqual(registry["start"], "harbour")
        self.assertEqual(registry["districts"]["harbour"]["levels"], ["city_harbour"])
        self.assertEqual(registry["districts"]["old_town"]["massing"], "old_town")
        self.assertIn("gorge", registry["unbuilt"])


if __name__ == "__main__":
    unittest.main()
