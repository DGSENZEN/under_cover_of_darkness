"""The old town's rules (plan B1a, Task 1): a key building entered three ways
of different kinds, its ways ending inside it; a terrace step's public and
thief's connectors; the new markers' defaults; the townsfolk's places on a
floor.

    python3 tools/level/test_town_rules.py
"""

import os
import sys
import unittest

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import markers as schema  # noqa: E402
import rules  # noqa: E402
from test_rules import good, marker  # noqa: E402

# Inside the tavern's box (the good level's floors run x -2..6, z -2..2).
INSIDE = (4.5, 0.0, 0.5)
OUTSIDE = (0.5, 0.0, 0.5)
TAVERN = marker("tavern_house", "household", (4.5, 1.5, 0.0), {"label": "tavern", "ways": 3}, size=[3.0, 3.0, 3.0])


def way(name, kind, end, into="tavern"):
    """A two-point walk from the yard to `end`, its first marker naming the
    household it leads into and its kind."""
    return [marker(name + "_1", "route_check", OUTSIDE, {"route": name, "order": 1, "move": "walk", "into": into, "kind": kind}),
            marker(name + "_2", "route_check", end, {"route": name, "order": 2, "move": "walk"})]


def connector(name, way_kind, step="yard_step"):
    return [marker(name + "_1", "route_check", OUTSIDE, {"route": name, "order": 1, "move": "walk", "way": way_kind, "step": step}),
            marker(name + "_2", "route_check", INSIDE, {"route": name, "order": 2, "move": "walk"})]


def household(*ways):
    data = good()
    data["markers"].append(dict(TAVERN))

    for i, (kind, end) in enumerate(ways):
        data["markers"].extend(way("tavern_way_%d" % i, kind, end))

    return data


class TownRules(unittest.TestCase):
    def test_a_household_needs_three_kinds_of_way_in(self):
        data = household(("door", INSIDE), ("window", INSIDE))
        self.assertTrue(any("tavern (household): 2 ways in" in p for p in rules.problems(data)), rules.problems(data))
        data["markers"].extend(way("tavern_way_roof", "roof", INSIDE))
        self.assertEqual(rules.problems(data), [])

    def test_two_ways_of_one_kind_count_once(self):
        data = household(("door", INSIDE), ("door", INSIDE), ("window", INSIDE))
        self.assertTrue(any("tavern (household): 2 ways in" in p for p in rules.problems(data)), rules.problems(data))

    def test_a_way_in_ends_inside_its_household(self):
        data = household(("door", INSIDE), ("window", INSIDE), ("roof", (2.5, 0.0, 0.5)))
        self.assertTrue(any("route tavern_way_2 ends outside tavern" in p for p in rules.problems(data)), rules.problems(data))

    def test_a_terrace_step_needs_two_public_and_one_thief(self):
        data = good()
        data["markers"].append(marker("yard_step_box", "terrace_step", (2.0, 1.0, 0.0), {"label": "yard_step"}, size=[8.0, 3.0, 4.0]))
        data["markers"].extend(connector("step_public_a", "public"))
        data["markers"].extend(connector("step_thief", "thief"))
        self.assertTrue(any("yard_step (terrace step): 1 public and 1 thief connectors, needs 2 and 1" in p for p in rules.problems(data)),
                        rules.problems(data))
        data["markers"].extend(connector("step_public_b", "public"))
        self.assertEqual(rules.problems(data), [])

    def test_the_new_markers_have_defaults(self):
        self.assertEqual(schema.with_defaults({"ucd": "household", "props": {"label": "x"}})["props"]["ways"], 3)
        self.assertEqual(schema.with_defaults({"ucd": "terrace_step", "props": {"label": "x"}})["props"]["public"], 2)
        self.assertEqual(schema.with_defaults({"ucd": "terrace_step", "props": {"label": "x"}})["props"]["thief"], 1)
        self.assertFalse(schema.with_defaults({"ucd": "light", "props": {"kind": "lantern"}})["props"]["dark_only"])
        self.assertFalse(schema.with_defaults({"ucd": "door", "props": {}})["props"]["curfew"])

        for m in [marker("s", "shunned", (0, 1, 0), {"label": "nave"}, size=[2, 2, 2]), marker("h", "home", (0, 0, 0)),
                  marker("seat_1", "seat", (0, 0, 0)), marker("w", "work", (0, 0, 0), {"kind": "oven"}),
                  marker("shaft", "light", (0, 2, 0), {"kind": "comet_shaft"}),
                  marker("r_1", "route_check", (0, 0, 0), {"route": "r", "order": 1, "move": "walk", "way": "roof", "kind": "leap",
                                                           "into": "", "step": ""})]:
            self.assertEqual(schema.problems(m), [], m["name"])

    def test_a_way_or_kind_of_no_known_kind(self):
        bad = marker("r_1", "route_check", (0, 0, 0), {"route": "r", "order": 1, "move": "walk", "way": "secret", "kind": "chimney"})
        self.assertEqual(len(schema.problems(bad)), 2, schema.problems(bad))

    def test_a_home_stands_on_a_floor(self):
        data = good()
        data["markers"].append(marker("bed_1", "home", (0.5, 3.0, 0.5)))
        self.assertTrue(any("bed_1 (home): no floor under it" in p for p in rules.problems(data)), rules.problems(data))


if __name__ == "__main__":
    unittest.main()
