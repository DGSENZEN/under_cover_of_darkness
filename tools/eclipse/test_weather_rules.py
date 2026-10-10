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


class Tide(unittest.TestCase):
    def test_tide_band(self):
        """The canal's waterline: a grimed, damp-green band, nothing above it."""
        grime, tint = weather_rules.tide(np.array([-1.8, -1.0]), (-2.0, -1.55))
        self.assertGreaterEqual(grime[0], 0.6)
        self.assertAlmostEqual(tint[0], 0.3)
        self.assertEqual(grime[1], 0.0)
        self.assertEqual(tint[1], 0.5)


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
        # At the foot of a wall; somewhere along a convex edge (edges chip in
        # places); never on a flat face up the wall.
        edge = np.stack([np.linspace(0.0, 4.0, 80), np.zeros(80), np.full(80, 2.0)], axis=1)
        points = np.vstack([[[1.0, 0.0, 0.1]], edge, [[2.0, 0.0, 2.0]]])
        gap = np.concatenate([[0.1], np.full(80, 2.0), [2.0]])
        convex = np.concatenate([[0.0], np.ones(80), [0.0]])
        b = weather_rules.blend(points, gap, convex, np.ones(82, dtype=bool), 1)
        self.assertGreater(b[0], 0.5)
        self.assertGreater(b[1:81].max(), 0.5)
        self.assertLess(b[81], 0.1)


    def test_edges_wear_in_patches_not_everywhere(self):
        # A thin bar is all edge: its paint chips in places, it is not
        # stripped (the kiosk's ironwork went bare, Oct 9 2026).
        rng = np.random.default_rng(4)
        points = rng.uniform(0.0, 6.0, (2000, 3))
        b = weather_rules.blend(points, np.full(2000, INF), np.ones(2000), np.ones(2000, dtype=bool), 1)
        worn = (b > 0.5).mean()
        self.assertGreater(worn, 0.05)
        self.assertLess(worn, 0.4)


    def test_a_short_bar_is_never_stripped(self):
        # One 1.2 m bar, all edge, across many seeds: its paint chips in
        # small places, never comes off over most of it.
        x = np.linspace(0.0, 1.2, 200)
        points = np.stack([x + 3.0, np.full(200, 0.5), np.full(200, 2.0)], axis=1)
        shares = []

        for seed in range(1, 41):
            b = weather_rules.blend(points, np.full(200, INF), np.ones(200), np.ones(200, dtype=bool), seed)
            shares.append((b > 0.5).mean())

        self.assertLess(np.mean(shares), 0.3)
        self.assertLess(max(shares), 0.6)

    def test_foot_wear_only_where_named(self):
        # Plaster wears through at the foot of a wall; an iron post standing
        # on a kerb does not.
        points = np.array([[1.0, 0.0, 0.1]])
        b = weather_rules.blend(points, np.array([0.1]), np.zeros(1), np.ones(1, dtype=bool), 1, foot=np.zeros(1, dtype=bool))
        self.assertEqual(b[0], 0.0)


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
