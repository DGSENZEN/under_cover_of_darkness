"""The Pasaje's graffiti sheet (pasaje_graffiti.py): pure Python, on synthetic brush sheets in a temporary folder.

    python3 tools/textures/test_pasaje_graffiti.py
"""

import os
import sys
import tempfile
import unittest
from pathlib import Path

import numpy as np
from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import library_glyphs  # noqa: E402
import pasaje_graffiti  # noqa: E402


class Graffiti(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.tmp = tempfile.TemporaryDirectory()
        brushes = Path(cls.tmp.name)
        rng = np.random.default_rng(5)
        for i in range(5):
            grey = (rng.random((64, 64)) * 255).astype(np.uint8)
            Image.fromarray(np.dstack([grey, np.full_like(grey, 255)]), "LA").save(brushes / ("brush_%02d.png" % i))
        cls.sheet = np.asarray(pasaje_graffiti.make(brushes))

    @classmethod
    def tearDownClass(cls):
        cls.tmp.cleanup()

    def _cell(self, k):
        n, size = pasaje_graffiti.GRID, pasaje_graffiti.CELL
        j, i = divmod(k, n)
        return self.sheet[j * size:(j + 1) * size, i * size:(i + 1) * size]

    def test_sixteen_cells_each_painted_with_a_clear_border(self):
        size = pasaje_graffiti.GRID * pasaje_graffiti.CELL
        self.assertEqual(self.sheet.shape, (size, size, 4))
        self.assertEqual(len(pasaje_graffiti.KINDS), 16)
        b = pasaje_graffiti.BORDER
        for k in range(16):
            cell = self._cell(k)
            self.assertGreater((cell[..., 3] > 128).mean(), 0.02, k)
            edge = np.concatenate([cell[:b, :, 3].ravel(), cell[-b:, :, 3].ravel(), cell[:, :b, 3].ravel(),
                                   cell[:, -b:, 3].ravel()])
            self.assertEqual(int(edge.max()), 0, k)

    def test_the_sheet_holds_every_kind_of_mark(self):
        kinds = pasaje_graffiti.KINDS
        for kind, least in (("tag", 4), ("throwup", 3), ("sigil", 3), ("calavera", 1), ("eye", 1), ("moon", 1),
                            ("roundel", 1)):
            self.assertGreaterEqual(kinds.count(kind), least, kind)

    def test_the_lettering_is_the_invented_script(self):
        # (The tags and sigils are spelt in the invented script's glyphs: the user's words come later.)
        script = library_glyphs.script_glyphs(seed=pasaje_graffiti.SCRIPT_SEED)
        for k, glyphs in pasaje_graffiti.spelling().items():
            self.assertIn(pasaje_graffiti.KINDS[k], ("tag", "throwup", "sigil"), k)
            self.assertTrue(glyphs and all(0 <= g < len(script) for g in glyphs), k)

    def test_the_sigils_are_round(self):
        # (Ink in every quarter about the cell's middle, as a ward circle has.)
        for k, kind in enumerate(pasaje_graffiti.KINDS):
            if kind != "sigil":
                continue
            ink = self._cell(k)[..., 3] > 128
            h = ink.shape[0] // 2
            for q in (ink[:h, :h], ink[:h, h:], ink[h:, :h], ink[h:, h:]):
                self.assertGreater(q.mean(), 0.01, k)


if __name__ == "__main__":
    unittest.main()
