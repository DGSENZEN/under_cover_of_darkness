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
from scipy import ndimage

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import pasaje_graffiti  # noqa: E402


class Graffiti(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.brushes = Path(self.tmp.name)
        rng = np.random.default_rng(5)
        for i in range(5):
            grey = (rng.random((64, 64)) * 255).astype(np.uint8)
            Image.fromarray(np.dstack([grey, np.full_like(grey, 255)]), "LA").save(self.brushes / ("brush_%02d.png" % i))
        self.sheet = np.asarray(pasaje_graffiti.make(self.brushes))

    def tearDown(self):
        self.tmp.cleanup()

    def _cells(self):
        n, size = pasaje_graffiti.GRID, pasaje_graffiti.CELL
        return [self.sheet[j * size:(j + 1) * size, i * size:(i + 1) * size] for j in range(n) for i in range(n)]

    def test_sixteen_cells_each_painted(self):
        self.assertEqual(self.sheet.shape, (pasaje_graffiti.GRID * pasaje_graffiti.CELL,) * 2 + (4,))
        cells = self._cells()
        self.assertEqual(len(cells), 16)
        for k, cell in enumerate(cells):
            self.assertGreater((cell[..., 3] > 128).mean(), 0.02, k)

    def test_no_cell_reads_as_a_letter(self):
        # (A letter's ink is one or two strokes filling 8-50% of its box: every mark here is either broken into more
        # pieces than that, or fuller or emptier.)
        for k, cell in enumerate(self._cells()):
            ink = cell[..., 3] > 128
            _, blobs = ndimage.label(ink)
            ys, xs = np.nonzero(ink)
            box = ink[ys.min():ys.max() + 1, xs.min():xs.max() + 1]
            ratio = box.mean()
            self.assertTrue(blobs > 2 or not 0.08 <= ratio <= 0.5, (k, blobs, ratio))

    def test_cells_keep_a_clear_border(self):
        for k, cell in enumerate(self._cells()):
            b = pasaje_graffiti.BORDER
            edge = np.concatenate([cell[:b, :, 3].ravel(), cell[-b:, :, 3].ravel(), cell[:, :b, 3].ravel(),
                                   cell[:, -b:, 3].ravel()])
            self.assertEqual(int(edge.max()), 0, k)


if __name__ == "__main__":
    unittest.main()
