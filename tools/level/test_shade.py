"""The level's baked vertex shading (shade.py): pure Python.

    python3 tools/level/test_shade.py
"""

import os
import sys
import unittest

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import shade  # noqa: E402

UP = (0.0, 1.0, 0.0)
SOUTH = (0.0, 0.0, 1.0)
NORTH = (0.0, 0.0, -1.0)
TORCH = {"kind": "torch", "position": [0.0, 2.0, 0.0]}


def grey(colour):
    return sum(colour) / 3.0


class Shade(unittest.TestCase):
    def test_open_and_clean_is_near_white(self):
        c = shade.colour((50.0, 3.0, 50.0), UP, 0.0, [], seed_free=True)
        self.assertTrue(all(0.9 <= v <= 1.1 for v in c), c)

    def test_occlusion_darkens(self):
        open_ = shade.colour((0.0, 3.0, 0.0), SOUTH, 0.0, [], seed_free=True)
        shut = shade.colour((0.0, 3.0, 0.0), SOUTH, 1.0, [], seed_free=True)
        self.assertLess(grey(shut), grey(open_) * 0.6)

    def test_soot_darkest_right_over_a_flame(self):
        over = shade.colour((0.0, 2.6, 0.05), SOUTH, 0.0, [TORCH], seed_free=True)
        beside = shade.colour((1.5, 2.6, 0.05), SOUTH, 0.0, [TORCH], seed_free=True)
        below = shade.colour((0.0, 1.0, 0.05), SOUTH, 0.0, [TORCH], seed_free=True)
        self.assertLess(grey(over), grey(beside))
        self.assertLess(grey(over), grey(below))

    def test_near_a_flame_warm(self):
        near = shade.colour((0.0, 1.2, 0.8), SOUTH, 0.0, [TORCH], seed_free=True)
        self.assertGreater(near[0], near[2])

    def test_damp_at_a_walls_foot(self):
        foot = shade.colour((10.0, 0.2, 0.0), SOUTH, 0.0, [], seed_free=True)
        high = shade.colour((10.0, 2.2, 0.0), SOUTH, 0.0, [], seed_free=True)
        self.assertLess(grey(foot), grey(high))
        # (Greener than it is red: moss and damp.)
        self.assertGreater(foot[1], foot[0])

    def test_the_moon_side_cold(self):
        # The moon shines toward +x+z from the north-west: a face looking
        # north-west is lit by it, and tinted cold.
        facing = shade.colour((20.0, 3.0, 20.0), (-0.7, 0.0, -0.7), 0.0, [], seed_free=True)
        away = shade.colour((20.0, 3.0, 20.0), (0.7, 0.0, 0.7), 0.0, [], seed_free=True)
        self.assertGreater(facing[2] - facing[0], away[2] - away[0])

    def test_grime_blotches_within_bounds(self):
        values = [grey(shade.colour((x * 0.73, 3.0, x * 1.31), SOUTH, 0.0, [])) for x in range(200)]
        self.assertGreater(max(values) - min(values), 0.05)
        self.assertGreaterEqual(min(values), shade.FLOOR)

    def test_never_black_never_blown(self):
        worst = shade.colour((0.0, 2.5, 0.0), SOUTH, 1.0, [TORCH, dict(TORCH, kind="hearth")])
        self.assertTrue(all(shade.FLOOR <= v <= shade.CEILING for v in worst), worst)


if __name__ == "__main__":
    unittest.main()
