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

    def test_colour_is_dark_grime(self):
        for kind in decals.GRIME:
            rgb = np.asarray(decals.make(kind, self.brushes))[..., :3].astype(float)
            self.assertLess(rgb.mean(), 90.0, kind)


if __name__ == "__main__":
    unittest.main()
