"""The plan builder (layouts/plan.py): the elements a district's plan lays,
and its event fields.

    python3 tools/level/test_plan.py
"""

import json
import os
import sys
import unittest

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "layouts"))

import plan  # noqa: E402


def _signed(polygon):
    return sum(a[0] * b[1] - b[0] * a[1] for a, b in zip(polygon, polygon[1:] + polygon[:1])) / 2.0


class Builder(unittest.TestCase):
    def setUp(self):
        self.P = plan.Plan("town")

    def test_elements_recorded(self):
        P = self.P
        P.ground("square", "plaza", plan.rect(-10, -10, 10, 10))
        P.plot("house_a", "house", plan.rect(12, -10, 20, -2), storeys=2, height=9.0, interior=True)
        P.route("plank", "roof_link", [(14, 9, -6), (14, 9, -14)])
        P.space("hall", plan.rect(-5, -5, 5, 5), floor=-8.0, height=5.0, openings=[{"to": "street", "at": (0, -5), "width": 3}])
        P.landmark("way_in", "metro_entrance", (0, -12), look="south")
        P.tram([(-12, -12), (12, -12), (12, 12), (-12, 12)])
        P.event("subsidence", centre=(0, 0), radius=50, strength=0.8)
        P.brink(plan.rect(-300, -300, 300, 300))
        d = P.data()
        self.assertEqual(d["name"], "town")
        self.assertEqual(d["ground"][0]["kind"], "plaza")
        self.assertEqual(d["plots"][0]["storeys"], 2)
        self.assertTrue(d["plots"][0]["interior"])
        self.assertEqual(d["routes"][0]["points"][1], [14, 9, -14])
        self.assertEqual(d["spaces"][0]["openings"][0]["to"], "street")
        self.assertEqual(d["landmarks"][0]["props"]["look"], "south")
        self.assertEqual(len(d["tram"]), 4)
        self.assertEqual(d["events"][0]["kind"], "subsidence")
        self.assertEqual(len(d["brink"]), 4)

    def test_causeway_is_kept(self):
        self.P.causeway([(0, 5), (0, 0)])
        self.assertEqual(self.P.data()["causeway"], [[0.0, 5.0], [0.0, 0.0]])

    def test_data_is_json(self):
        self.P.ground("square", "plaza", plan.rect(0, 0, 1, 1))
        self.P.event("water", line=[(0, 0), (10, 0)], reach=5, strength=1)
        json.dumps(self.P.data())

    def test_rect_orientation(self):
        """rect runs counter-clockwise in the (x, z) plane (positive shoelace
        area): clockwise as seen from above, with north up."""
        self.assertGreater(_signed(plan.rect(0, 0, 2, 1)), 0)
        self.assertAlmostEqual(plan.area(plan.rect(0, 0, 2, 1)), 2.0)

    def test_unknown_kind_refused(self):
        with self.assertRaises(ValueError):
            self.P.ground("x", "lawn", plan.rect(0, 0, 1, 1))
        with self.assertRaises(ValueError):
            self.P.route("x", "zipline", [(0, 0, 0), (1, 0, 0)])
        with self.assertRaises(ValueError):
            self.P.event("ghosts", centre=(0, 0), radius=1, strength=1)


class Fields(unittest.TestCase):
    def setUp(self):
        P = plan.Plan("town")
        P.event("subsidence", centre=(0, 0), radius=100, strength=0.8)
        P.event("subsidence", centre=(300, 0), radius=50, strength=0.3)
        P.event("water", line=[(-100, 50), (100, 50)], reach=20, strength=1.0)
        self.d = P.data()

    def test_field_radial(self):
        f = lambda x: plan.field(self.d, "subsidence", x, 0)
        self.assertAlmostEqual(f(0), 0.8)
        self.assertEqual(f(100), 0.0)
        self.assertEqual(f(150), 0.0)
        self.assertGreater(f(20), f(50))
        self.assertGreater(f(50), f(80))

    def test_field_line(self):
        self.assertAlmostEqual(plan.field(self.d, "water", 30, 50), 1.0)
        self.assertEqual(plan.field(self.d, "water", 30, 70), 0.0)

    def test_field_takes_the_strongest_shape(self):
        self.assertAlmostEqual(plan.field(self.d, "subsidence", 300, 0), 0.3)
        self.assertEqual(plan.field(self.d, "seepage", 0, 0), 0.0)


if __name__ == "__main__":
    unittest.main()
