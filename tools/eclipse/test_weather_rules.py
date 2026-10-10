"""The weathering rules (weather_rules.py): what grime, wear-through, tint
and baked light each vertex gets from what the builder measured.

    python3 tools/eclipse/test_weather_rules.py
"""

import os
import sys
import unittest

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import weather_rules  # noqa: E402

INF = np.inf


def wall(n=200, height=3.0, width=4.0, facing=(0.0, 1.0, 0.0)):
    """Points spread over a vertical wall at y 0, facing `facing`."""
    rng = np.random.default_rng(3)
    x = rng.uniform(0.0, width, n)
    z = rng.uniform(0.0, height, n)
    points = np.stack([x, np.zeros(n), z], axis=1)
    normals = np.tile(np.array(facing, dtype=np.float64), (n, 1))
    return points, normals, z


class Grime(unittest.TestCase):
    def test_grime_falls_with_height(self):
        points, _, z = wall()
        g = weather_rules.grime(points, z, np.zeros(len(z)), [], 1)
        self.assertGreater(g[z < 0.2].mean(), 0.7)
        self.assertLess(g[z > 1.5].max(), 0.05)

    def test_soot_rises_over_its_origin_only(self):
        origin = np.array([1.0, 0.0, 2.0])
        points = np.array([origin + (0, 0, 0.5), origin - (0, 0, 0.5), origin + (0, 0, 2.0)])
        gap = np.full(3, INF)
        g = weather_rules.grime(points, gap, np.zeros(3), [origin], 1)
        self.assertGreater(g[0], 0.3)
        self.assertEqual(g[1], 0.0)
        self.assertEqual(g[2], 0.0)

    def test_concave_adds_grime(self):
        points = np.array([[1.0, 0.0, 2.0], [1.0, 0.0, 2.0]])
        g = weather_rules.grime(points, np.full(2, INF), np.array([1.0, 0.0]), [], 1)
        self.assertGreater(g[0], g[1] + 0.2)


class Blend(unittest.TestCase):
    def test_blend_zero_where_not_blendable(self):
        points, _, z = wall()
        b = weather_rules.blend(points, z, np.ones(len(z)), np.zeros(len(z), dtype=bool), 1)
        self.assertEqual(b.max(), 0.0)

    def test_blend_at_wall_foot_and_convex_edges(self):
        points = np.array([[1.0, 0.0, 0.1], [1.0, 0.0, 2.0], [2.0, 0.0, 2.0]])
        gap = np.array([0.1, 2.0, 2.0])
        convex = np.array([0.0, 1.0, 0.0])
        b = weather_rules.blend(points, gap, convex, np.ones(3, dtype=bool), 1)
        self.assertGreater(b[0], 0.5)
        self.assertGreater(b[1], 0.5)
        self.assertLess(b[2], 0.1)


class Tint(unittest.TestCase):
    def test_streak_hangs_under_an_overhang(self):
        # A row of columns along a wall, just under a sill, and the same
        # places with nothing above.
        x = np.arange(0.0, 8.0, weather_rules.STREAK_COLUMN) + weather_rules.STREAK_COLUMN / 2
        points = np.stack([x, np.zeros(len(x)), np.full(len(x), 1.5)], axis=1)
        normals = np.tile([0.0, 1.0, 0.0], (len(x), 1))
        under = weather_rules.tint(points, normals, np.full(len(x), 0.3), 1)
        open_ = weather_rules.tint(points, normals, np.full(len(x), INF), 1)
        self.assertLess(under.min(), 0.4)
        self.assertGreaterEqual(open_.min(), 0.5 - 1e-9)

    def test_up_faces_bleach_more_than_down_faces(self):
        points = np.array([[1.0, 1.0, 1.0], [1.0, 1.0, 1.0]])
        normals = np.array([[0.0, 0.0, 1.0], [0.0, 0.0, -1.0]])
        t = weather_rules.tint(points, normals, np.full(2, INF), 1)
        self.assertGreater(t[0], t[1] + 0.1)

    def test_neutral_on_a_plain_wall(self):
        away = -weather_rules.SUN * np.array([1.0, 1.0, 0.0])
        away /= np.linalg.norm(away)
        points, normals, _ = wall(facing=tuple(away))
        t = weather_rules.tint(points, normals, np.full(len(points), INF), 1)
        self.assertLess(np.abs(t - 0.5).max(), 0.05)


class Light(unittest.TestCase):
    def test_occluded_darker_than_open(self):
        normals = np.array([[0.0, 1.0, 0.0], [0.0, 1.0, 0.0]])
        a = weather_rules.light(np.array([0.3, 1.0]), normals)
        self.assertLess(a[0], a[1] - 0.3)

    def test_never_brightens(self):
        normals = np.array([[0.0, 0.0, -1.0], [0.0, 0.0, 1.0], [1.0, 0.0, 0.0]])
        a = weather_rules.light(np.array([1.0, 1.0, 1.0]), normals)
        self.assertLessEqual(a.max(), 1.0)


class Rules(unittest.TestCase):
    def test_rules_shape_range_and_determinism(self):
        points, normals, z = wall()
        n = len(z)
        args = (points, normals, z, np.full(n, 0.5), np.zeros(n), np.zeros(n), np.full(n, 0.8), np.ones(n, dtype=bool),
                [np.array([2.0, 0.0, 1.0])])
        one = weather_rules.rules(*args, seed=weather_rules.seed_of("kiosk"))
        two = weather_rules.rules(*args, seed=weather_rules.seed_of("kiosk"))
        other = weather_rules.rules(*args, seed=weather_rules.seed_of("arcade_bay"))
        self.assertEqual(one.shape, (n, 4))
        self.assertGreaterEqual(one.min(), 0.0)
        self.assertLessEqual(one.max(), 1.0)
        np.testing.assert_array_equal(one, two)
        self.assertFalse(np.array_equal(one, other))


if __name__ == "__main__":
    unittest.main()
