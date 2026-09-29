"""The city's kit families against the level metrics and their budgets:
pure Python, no Blender.

    python3 tools/level/test_kits.py
"""

import math
import os
import sys
import unittest

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import geo  # noqa: E402
import kit_recipes  # noqa: E402
import kit_shapes  # noqa: E402
import rules  # noqa: E402


def tris(recipe):
    return sum(len(f[0]) - 2 for f in kit_shapes.build(recipe["shapes"])["faces"]) if recipe.get("shapes") else len(recipe["boxes"]) * 12


def family(name):
    return {n: r for n, r in kit_recipes.PIECES.items() if r["family"] == name}


def treads(recipe):
    """A flight's steps in order up: [(top y, depth along the flight)]."""
    steps = sorted(recipe["boxes"], key=lambda b: b[1] + b[4] / 2.0)
    return [(round(b[1] + b[4] / 2.0, 3), round(b[3], 3)) for b in steps]


def top_of(col):
    return col[1] + col[4] / 2.0


def _corners(box):
    axes = box.axes()
    return [[box.centre[i] + sum(s[k] * box.half[k] * axes[k][i] for k in range(3)) for i in range(3)]
            for s in ((1, 1, 1), (1, 1, -1), (1, -1, 1), (1, -1, -1), (-1, 1, 1), (-1, 1, -1), (-1, -1, 1), (-1, -1, -1))]


class Fort(unittest.TestCase):
    def test_budgets(self):
        pieces = family("fort")
        self.assertGreaterEqual(len(pieces), 16)

        for name, recipe in pieces.items():
            self.assertLessEqual(tris(recipe), recipe.get("budget", kit_shapes.PIECE_TRIS), name)

    def test_battlements_are_three_metre_bays(self):
        cols = kit_recipes.PIECES["city_wall_12_6"]["cols"]
        merlons = sorted((c for c in cols if c[1] > 12.0 + 0.9), key=lambda c: c[0])
        self.assertEqual(len(merlons), 2)
        self.assertAlmostEqual(merlons[0][3], 2.1, places=2)
        self.assertAlmostEqual(merlons[1][0] - merlons[0][0], 3.0, places=2)

    def test_the_walk_is_walkable_and_parapeted(self):
        cols = kit_recipes.PIECES["city_wall_12_6"]["cols"]
        body = max(cols, key=lambda c: c[3] * c[4] * c[5])
        self.assertAlmostEqual(top_of(body), 12.0, places=2)
        self.assertTrue(all(c[2] > 0.0 for c in cols if c[1] > 12.0))
        self.assertGreaterEqual(2.4 - max(c[5] for c in cols if c[1] > 12.0), 1.2)

    def test_wall_stairs_keep_the_metrics(self):
        for name, height in (("wall_stair_12", 12.0), ("wall_stair_10", 10.0)):
            steps = treads(kit_recipes.PIECES[name])
            rises = [round(b[0] - a[0], 3) for a, b in zip(steps, steps[1:])]
            self.assertTrue(all(r == kit_recipes.RISER for r in rises), name)
            self.assertAlmostEqual(steps[-1][0], height, places=3)
            self.assertTrue(all(d == kit_recipes.TREAD or (i + 1) % 10 == 0 for i, (_, d) in enumerate(steps[:-1])), name)

    def test_round_towers_are_solid_to_their_rims_and_no_further(self):
        for name, radius, top in (("tower_drum_8", 4.0, 20.0), ("gold_stage_1", 7.5, 18.0)):
            recipe = kit_recipes.PIECES[name]
            body = [c for c in recipe["cols"] if abs(top_of(c) - top) < 1e-3]
            self.assertTrue(body, name)
            corner = max(math.hypot(abs(c[0]) + c[3] / 2.0, abs(c[2]) + c[5] / 2.0) for c in body if c[7] == 0.0)
            self.assertLessEqual(corner, radius / math.cos(math.pi / (16 if "drum" in name else 12)) + 0.05, name)

    def test_the_sea_gate_passage_is_clear(self):
        # 4 m wide and 5 m high through its front and its passage.
        for name in ("gate_front", "gate_passage_16"):
            for c in kit_recipes.PIECES[name]["cols"]:
                low, high = c[1] - c[4] / 2.0, c[1] + c[4] / 2.0
                near = abs(c[0]) - c[3] / 2.0

                if near < 2.0 - 1e-3 and low < 5.0 - 1e-3:
                    self.fail("%s: a collider in the passage %s" % (name, c))

    def test_the_nasrid_gate_lets_boats_through(self):
        cols = kit_recipes.PIECES["nasrid_gate"]["cols"]
        jamb = 3.5 * math.cos(math.asin(0.33))

        for c in cols:
            if abs(c[0]) - c[3] / 2.0 < jamb - 1e-3 and c[1] - c[4] / 2.0 < 10.0 - 1e-3:
                self.fail("a collider in the water gate %s" % c)

    def test_colliders_stay_in_their_size(self):
        loose = []

        for name, recipe in family("fort").items():
            for box in geo.piece_boxes(recipe, [0.0, 0.0, 0.0], geo.IDENTITY):
                for corner in _corners(box):
                    if abs(corner[0]) > recipe["size"][0] / 2.0 + 0.3 or abs(corner[2]) > recipe["size"][2] / 2.0 + 0.3:
                        loose.append("%s: %s" % (name, [round(c, 2) for c in corner]))
                        break

        self.assertEqual(loose, [])

    def test_the_chain_stops_nobody(self):
        self.assertEqual(kit_recipes.PIECES["chain_span_12"]["cols"], [])


if __name__ == "__main__":
    unittest.main(verbosity=1)
