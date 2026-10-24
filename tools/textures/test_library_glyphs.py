"""The library's glyph atlases (library_glyphs.py): our own invented script, about forty glyphs drawn as strokes, and
any font's characters, baked as signed distance fields into an atlas with a map of where each character sits.

    python3 tools/textures/test_library_glyphs.py
"""

import json
import os
import sys
import tempfile
import unittest
from pathlib import Path

import numpy as np
from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import library_glyphs  # noqa: E402

ROBOTO = Path(__file__).resolve().parents[2] / "examples_dd3d" / "Roboto-Bold.ttf"


class Script(unittest.TestCase):
    def test_forty_distinct_glyphs(self):
        glyphs = library_glyphs.script_glyphs(seed=1888)
        self.assertGreaterEqual(len(glyphs), 40)
        images = [library_glyphs.draw_strokes(g, 96) > 0 for g in glyphs]
        for i in range(len(images)):
            for j in range(i + 1, len(images)):
                differ = np.mean(images[i] != images[j])
                self.assertGreater(differ, 0.02, "glyphs %d and %d nearly the same" % (i, j))

    def test_deterministic(self):
        a = library_glyphs.script_glyphs(seed=1888)
        b = library_glyphs.script_glyphs(seed=1888)
        self.assertEqual(a, b)

    def test_every_glyph_has_ink_and_room(self):
        for g in library_glyphs.script_glyphs(seed=1888):
            ink = library_glyphs.draw_strokes(g, 96) > 0
            self.assertGreater(ink.mean(), 0.03)
            # Clear of the cell's edge, so the distance field has room to fall off.
            self.assertFalse(ink[:6].any() or ink[-6:].any() or ink[:, :6].any() or ink[:, -6:].any())


class DistanceField(unittest.TestCase):
    def test_inside_high_outside_low_edge_half(self):
        ink = np.zeros((64, 64), bool)
        ink[20:44, 20:44] = True
        sdf = library_glyphs.signed_distance(ink, spread=8.0)
        self.assertGreater(sdf[32, 32], 0.9)
        self.assertLess(sdf[2, 2], 0.05)
        self.assertAlmostEqual(float(sdf[32, 20]), 0.5, delta=0.08)


class Atlas(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.out = Path(self.tmp.name)

    def tearDown(self):
        self.tmp.cleanup()

    def test_script_atlas_and_map(self):
        png, js = library_glyphs.bake_script("script", seed=1888, out_png=self.out, out_json=self.out)
        meta = json.loads(js.read_text())
        image = np.asarray(Image.open(png))
        self.assertEqual(image.shape[0], meta["rows"] * meta["cell"])
        self.assertEqual(image.shape[1], meta["cols"] * meta["cell"])
        self.assertGreaterEqual(len(meta["chars"]), 40)
        self.assertIn("fallback", meta)
        # Each character's cell carries ink (its middle row crosses a stroke somewhere).
        for ch, (col, row) in meta["chars"].items():
            cell = image[row * meta["cell"]:(row + 1) * meta["cell"], col * meta["cell"]:(col + 1) * meta["cell"]]
            self.assertGreater(cell.max(), 160, repr(ch))

    @unittest.skipUnless(ROBOTO.exists(), "no Roboto in examples_dd3d")
    def test_font_atlas_has_the_accents(self):
        chars = library_glyphs.LATIN
        png, js = library_glyphs.bake_font("latin", ROBOTO, chars, out_png=self.out, out_json=self.out)
        meta = json.loads(js.read_text())
        for ch in "áéíóúñüÁÉÍÓÚÑÜ¿¡":
            self.assertIn(ch, meta["chars"])


if __name__ == "__main__":
    unittest.main()
