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


class Wards(unittest.TestCase):
    """The wards' sheet (pasaje_graffiti.make_wards): the chalk ritual circle, the threshold's arc, the salt line, the
    wall's ward sigil, each painted in its cell, a clear border, written in the invented script."""

    @classmethod
    def setUpClass(cls):
        cls.tmp = tempfile.TemporaryDirectory()
        brushes = Path(cls.tmp.name)
        rng = np.random.default_rng(6)
        for i in range(5):
            grey = (rng.random((64, 64)) * 255).astype(np.uint8)
            Image.fromarray(np.dstack([grey, np.full_like(grey, 255)]), "LA").save(brushes / ("brush_%02d.png" % i))
        cls.sheet = np.asarray(pasaje_graffiti.make_wards(brushes))

    @classmethod
    def tearDownClass(cls):
        cls.tmp.cleanup()

    def test_four_wards_each_painted_with_a_clear_border(self):
        n, size = pasaje_graffiti.WARD_GRID, pasaje_graffiti.CELL
        self.assertEqual(self.sheet.shape, (n * size, n * size, 4))
        self.assertEqual(pasaje_graffiti.WARDS, ["circle", "arc", "salt", "ward"])
        b = pasaje_graffiti.BORDER
        for k in range(n * n):
            j, i = divmod(k, n)
            cell = self.sheet[j * size:(j + 1) * size, i * size:(i + 1) * size]
            self.assertGreater((cell[..., 3] > 128).mean(), 0.01, k)
            self.assertEqual(int(max(cell[:b, :, 3].max(), cell[-b:, :, 3].max(), cell[:, :b, 3].max(),
                                     cell[:, -b:, 3].max())), 0, k)

    def test_the_circle_is_round_and_the_salt_a_line(self):
        size = pasaje_graffiti.CELL
        circle = self.sheet[:size, :size, 3] > 128
        h = size // 2
        for q in (circle[:h, :h], circle[:h, h:], circle[h:, :h], circle[h:, h:]):
            self.assertGreater(q.mean(), 0.01)
        # (The salt laid along the cell's width, thickest down its middle: the set stretches it across a sill.)
        salt = self.sheet[size:, :size, 3] > 64
        ys, xs = np.nonzero(salt)
        self.assertGreater(xs.max() - xs.min(), 0.8 * size)
        third = size // 3
        middle, outer = salt[third:2 * third].mean(), np.concatenate([salt[:third], salt[2 * third:]]).mean()
        self.assertGreater(middle, 3 * outer)


if __name__ == "__main__":
    unittest.main()
