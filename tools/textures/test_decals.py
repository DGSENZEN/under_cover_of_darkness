"""The Underground's grime decals (decals.py): pure Python, on synthetic
brush sheets in a temporary folder.

    python3 tools/textures/test_decals.py
"""

import os
import sys
import tempfile
import unittest
from pathlib import Path

import numpy as np
from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import decals  # noqa: E402


class Decals(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.brushes = Path(self.tmp.name)
        rng = np.random.default_rng(5)

        for i in range(5):
            grey = (rng.random((64, 64)) * 255).astype(np.uint8)
            Image.fromarray(np.dstack([grey, np.full_like(grey, 255)]), "LA").save(self.brushes / ("brush_%02d.png" % i))

    def tearDown(self):
        self.tmp.cleanup()

    def _alpha(self, kind):
        image = decals.make(kind, self.brushes)
        self.assertEqual(image.mode, "RGBA")
        return np.asarray(image)[..., 3].astype(float) / 255.0

    def test_every_kind_has_paint(self):
        for kind in decals.KINDS:
            self.assertGreater(self._alpha(kind).max(), 0.5, kind)

    def test_borders_clear(self):
        for kind in decals.KINDS:
            a = self._alpha(kind)
            border = np.concatenate([a[:8].ravel(), a[-8:].ravel(), a[:, :8].ravel(), a[:, -8:].ravel()])
            self.assertEqual(border.max(), 0.0, kind)

    def test_soot_darkest_at_the_top(self):
        a = self._alpha("soot")
        quarter = a.shape[0] // 4
        self.assertGreater(a[8:quarter].mean(), a[-quarter:-8].mean())

    def test_drips_run_down(self):
        a = self._alpha("drip")
        self.assertGreater(a[: a.shape[0] // 3].mean(), a[-a.shape[0] // 3:].mean())

    def test_oil_and_wet_kinds(self):
        self.assertIn("oil", decals.KINDS)
        self.assertIn("wet", decals.KINDS)

    def test_petals_strewn_marigold(self):
        # Loose cempasuchil petals: many small flecks, marigold orange, not one blot.
        image = np.asarray(decals.make("petals", self.brushes)).astype(float)
        a = image[..., 3] / 255.0
        lit = a > 0.5
        self.assertGreater(lit.mean(), 0.08)
        self.assertLess(lit.mean(), 0.6)
        r, g, b = (image[..., i][lit].mean() for i in range(3))
        self.assertGreater(r, 180.0)
        self.assertGreater(r, g + 40.0)
        self.assertGreater(g, b + 40.0)
        rows = lit[:, 8:-8].mean(1)
        self.assertGreater(rows.std(), 0.0)
        self.assertGreater(len(np.unique(image[..., 1][lit].round(-1))), 3)

    def test_poster_is_paper_torn_at_its_edges_and_blank(self):
        # A pasted bill gone yellow: opaque paper, light, its edge torn ragged, nothing printed
        # in its middle (what it says is the user's).
        image = np.asarray(decals.make("poster", self.brushes)).astype(float)
        a = image[..., 3] / 255.0
        self.assertGreater((a > 0.9).mean(), 0.45)
        self.assertGreater(image[..., :3][a > 0.9].mean(), 150.0)
        middle = image[200:312, 200:312, :3]
        self.assertLess(middle.std(axis=(0, 1)).max(), 25.0)
        rows = [np.flatnonzero(a[r] > 0.5) for r in range(64, 448, 16)]
        lefts = [r[0] for r in rows if r.size]
        self.assertGreater(np.std(lefts), 2.0)

    @staticmethod
    def _radial(a):
        """Mean alpha by distance from the middle (as a share of the half-width), in 40 bands."""
        n = a.shape[0]
        y, x = np.mgrid[0:n, 0:n]
        r = np.hypot(x - n / 2, y - n / 2) / (n / 2)
        return np.array([a[(r >= k / 40) & (r < (k + 1) / 40)].mean() for k in range(40)])

    def test_ward_circle_is_a_chalk_ring_round_a_blank_band(self):
        # His chalk ward: two rings drawn round the desk, the band between them left blank for its glyphs (Part 2's
        # script), the middle clear; chalk white.
        image = decals.make("ward_circle", self.brushes)
        a = np.asarray(image)[..., 3].astype(float) / 255.0
        rgb = np.asarray(image)[..., :3].astype(float)
        profile = self._radial(a)
        self.assertLess(profile[:20].max(), 0.05)
        inner, band, outer = profile[26:30].max(), profile[31:34].max(), profile[35:38].max()
        self.assertGreater(inner, 0.4)
        self.assertGreater(outer, 0.4)
        self.assertLess(band, 0.15)
        self.assertGreater(rgb[a > 0.5].mean(), 180.0)

    def test_ward_glow_is_its_chalk_lit_and_nothing_else(self):
        # The ward's flare (Part 2 Task 8): a decal's emission is added whatever its albedo's alpha, so its glow is
        # the chalk's own lines, bright where the chalk is and black wherever the floor shows through.
        chalk = np.asarray(decals.make("ward_circle", self.brushes)).astype(float)
        glow = np.asarray(decals.make("ward_glow", self.brushes)).astype(float)
        self.assertEqual(glow.shape, chalk.shape)
        clear = chalk[..., 3] < 1.0
        self.assertLess(glow[clear][:, :3].max(), 1.0)
        drawn = chalk[..., 3] > 200.0
        self.assertGreater(glow[drawn][:, :3].mean(), 170.0)
        # (Opaque inside its border: its alpha plays no part in emission, and a transparent black imports fringed.)
        b = decals.BORDER
        self.assertEqual(glow[b:-b, b:-b, 3].min(), 255.0)

    def test_salt_line_is_a_band_of_white_grains(self):
        image = decals.make("salt_line", self.brushes)
        a = np.asarray(image)[..., 3].astype(float) / 255.0
        rgb = np.asarray(image)[..., :3].astype(float)
        rows = a.mean(axis=1)
        self.assertGreater(rows[240:272].mean(), 0.35)
        self.assertLess(np.concatenate([rows[:180], rows[-180:]]).max(), 0.05)
        # Grains, not a smear: the band's alpha broken up.
        self.assertGreater(a[240:272, 40:-40].std(), 0.2)
        self.assertGreater(rgb[a > 0.5].mean(), 200.0)

    def test_colour_is_dark_grime(self):
        for kind in decals.GRIME:
            rgb = np.asarray(decals.make(kind, self.brushes))[..., :3].astype(float)
            self.assertLess(rgb.mean(), 90.0, kind)


if __name__ == "__main__":
    unittest.main()
