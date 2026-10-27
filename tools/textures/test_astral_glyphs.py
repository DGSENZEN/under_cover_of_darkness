"""The astral passage's glyphs (astral_glyphs.py): the gate's three rings and the deep's constellations, from the
invented script. Pure Python.

    python3 tools/textures/test_astral_glyphs.py
"""

import os
import sys
import unittest

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import astral_glyphs  # noqa: E402


class Rings(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.sheet = np.asarray(astral_glyphs.make_rings())

    def test_three_rings_side_by_side(self):
        size = astral_glyphs.CELL
        self.assertEqual(self.sheet.shape, (size, size * 3, 4))

    def test_each_ring_is_its_band_of_glyphs_and_nothing_else(self):
        size = astral_glyphs.CELL
        y, x = np.mgrid[0:size, 0:size]
        r = np.hypot(x - size / 2, y - size / 2) / size
        for k in range(3):
            alpha = self.sheet[:, k * size:(k + 1) * size, 3] > 64
            inner, outer = astral_glyphs.RINGS[k][:2]
            self.assertGreater(alpha.mean(), 0.01, k)
            self.assertEqual(int((alpha & ((r < inner - 0.02) | (r > outer + 0.02))).sum()), 0, k)
            # (Glyphs all the way round: ink in every eighth of the circle.)
            angle = (np.arctan2(y - size / 2, x - size / 2) + np.pi) / (2 * np.pi)
            for e in range(8):
                self.assertGreater(int((alpha & (angle >= e / 8) & (angle < (e + 1) / 8)).sum()), 50, (k, e))


class Constellations(unittest.TestCase):
    def test_six_glyphs_as_stars_and_threads(self):
        stars = astral_glyphs.constellations()
        self.assertEqual(len(stars), 6)
        for glyph in stars:
            points = [p for stroke in glyph for p in stroke]
            self.assertGreaterEqual(len(points), 3)
            self.assertTrue(all(0.0 <= c <= 1.0 for p in points for c in p))


if __name__ == "__main__":
    unittest.main()
