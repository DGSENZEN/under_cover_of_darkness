"""The Pasaje's bills (pasaje_bills.py): pure Python, on synthetic brush sheets in a temporary folder.

    python3 tools/textures/test_pasaje_bills.py
"""

import os
import sys
import tempfile
import unittest
from pathlib import Path

import numpy as np
from PIL import Image
from scipy import ndimage

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import pasaje_bills  # noqa: E402


class Bills(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.tmp = tempfile.TemporaryDirectory()
        brushes = Path(cls.tmp.name)
        rng = np.random.default_rng(8)
        for i in range(5):
            grey = (rng.random((64, 64)) * 255).astype(np.uint8)
            Image.fromarray(np.dstack([grey, np.full_like(grey, 255)]), "LA").save(brushes / ("brush_%02d.png" % i))
        cls.sheet = np.asarray(pasaje_bills.make(brushes))

    @classmethod
    def tearDownClass(cls):
        cls.tmp.cleanup()

    def _cell(self, k):
        cols, size = pasaje_bills.COLS, pasaje_bills.CELL
        j, i = divmod(k, cols)
        return self.sheet[j * size:(j + 1) * size, i * size:(i + 1) * size]

    def test_the_sheet_holds_every_bill(self):
        self.assertEqual(pasaje_bills.BILLS, ["missing", "nahual_reward", "curandero", "exorcist", "cabaret",
                                              "lucha_night", "company_notice", "loteria", "wanted_spirit", "fiesta",
                                              "tatters", "tatters"])
        self.assertEqual(self.sheet.shape, (pasaje_bills.ROWS * pasaje_bills.CELL, pasaje_bills.COLS * pasaje_bills.CELL, 4))

    def test_each_is_paper_with_a_clear_border(self):
        b = pasaje_bills.BORDER
        for k in range(len(pasaje_bills.BILLS)):
            cell = self._cell(k)
            self.assertGreater((cell[..., 3] > 128).mean(), 0.12, k)
            self.assertEqual(int(max(cell[:b, :, 3].max(), cell[-b:, :, 3].max(), cell[:, :b, 3].max(),
                                     cell[:, -b:, 3].max())), 0, k)

    def test_their_edges_are_torn(self):
        # (A cut sheet's edge runs straight; a torn one wanders: where the paper starts along each row varies.)
        for k, kind in enumerate(pasaje_bills.BILLS):
            if kind == "tatters":
                continue
            paper = self._cell(k)[..., 3] > 128
            rows = [np.nonzero(r)[0][0] for r in paper if r.any()]
            middle = rows[len(rows) // 4: 3 * len(rows) // 4]
            self.assertGreater(float(np.std(middle)), 1.5, (k, kind))

    def test_they_are_left_empty_for_the_users_bills(self):
        # (Paper only, its years on it, no ink: inside the sheet, away from its torn rim, no more than a speck of it
        # (its staples) stands far off the paper's own tone. Ageing and damp move it 65 of 255 at most; every ink sat
        # 110 and more off its paper.)
        for k, kind in enumerate(pasaje_bills.BILLS):
            cell = self._cell(k)
            inner = ndimage.binary_erosion(cell[..., 3] > 160, iterations=12)
            tone = cell[..., :3].astype(np.float64) @ np.array([0.299, 0.587, 0.114])
            if not inner.any():
                continue
            off = np.abs(tone[inner] - np.median(tone[inner])) > 80
            self.assertLess(float(off.mean()), 0.005, (k, kind, float(off.mean())))

    def test_the_tatters_are_scraps_of_many_bills(self):
        for k, kind in enumerate(pasaje_bills.BILLS):
            if kind != "tatters":
                continue
            _, pieces = ndimage.label(self._cell(k)[..., 3] > 128)
            self.assertGreaterEqual(pieces, 3, k)


if __name__ == "__main__":
    unittest.main()
