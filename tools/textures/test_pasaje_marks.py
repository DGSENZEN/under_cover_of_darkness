"""The marks of what happened in the Pasaje (pasaje_marks.py): pure Python, on synthetic brush sheets in a temporary
folder.

    python3 tools/textures/test_pasaje_marks.py
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

import pasaje_marks  # noqa: E402


class Marks(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.tmp = tempfile.TemporaryDirectory()
        brushes = Path(cls.tmp.name)
        rng = np.random.default_rng(9)
        for i in range(5):
            grey = (rng.random((64, 64)) * 255).astype(np.uint8)
            Image.fromarray(np.dstack([grey, np.full_like(grey, 255)]), "LA").save(brushes / ("brush_%02d.png" % i))
        albedo, normal = pasaje_marks.make(brushes)
        cls.albedo, cls.normal = np.asarray(albedo), np.asarray(normal)

    @classmethod
    def tearDownClass(cls):
        cls.tmp.cleanup()

    def _cell(self, sheet, k):
        n, size = pasaje_marks.GRID, pasaje_marks.CELL
        j, i = divmod(k, n)
        return sheet[j * size:(j + 1) * size, i * size:(i + 1) * size]

    def test_four_marks_each_painted_with_a_clear_border(self):
        self.assertEqual(pasaje_marks.MARKS, ["scorch", "gouges", "hand", "spiral"])
        size = pasaje_marks.GRID * pasaje_marks.CELL
        self.assertEqual(self.albedo.shape, (size, size, 4))
        self.assertEqual(self.normal.shape[:2], (size, size))
        b = pasaje_marks.BORDER
        for k in range(4):
            cell = self._cell(self.albedo, k)
            self.assertGreater((cell[..., 3] > 64).mean(), 0.01, k)
            self.assertEqual(int(max(cell[:b, :, 3].max(), cell[-b:, :, 3].max(), cell[:, :b, 3].max(),
                                     cell[:, -b:, 3].max())), 0, k)

    def test_the_gouges_and_cracks_are_cut_into_the_tile(self):
        # (Their normal map tilts where they are cut: the grooves' and cracks' walls catch the light.)
        for k, kind in enumerate(pasaje_marks.MARKS):
            tilted = np.abs(self._cell(self.normal, k)[..., :2].astype(np.float64) - 127.5) > 40
            if kind in ("gouges", "spiral"):
                self.assertGreater(tilted.mean(), 0.004, kind)
            else:
                self.assertLess(tilted.mean(), 0.004, kind)

    def test_the_claws_are_four_and_the_spiral_turns(self):
        gouges = self._cell(self.albedo, 1)[..., 3] > 160
        _, grooves = ndimage.label(gouges)
        self.assertGreaterEqual(grooves, 3)
        # (The spiral's cracks reach out round the cell's middle in every quarter.)
        spiral = self._cell(self.albedo, 3)[..., 3] > 100
        h = spiral.shape[0] // 2
        for q in (spiral[:h, :h], spiral[:h, h:], spiral[h:, :h], spiral[h:, h:]):
            self.assertGreater(q.mean(), 0.003)

    def test_the_soot_stays_dark_when_blended_in_linear_light(self):
        # (The engine lays a decal over the wall in linear light: soot at a share a in sRGB reads as only about
        # 1 - (1 - a) ** 2.2 dark, so its alpha is carried up to that.) Where there is soot to speak of, it is mostly
        # dense: the hand's print nearly all of it, the scorch's plume thinning as it climbs.
        for k, least in ((0, 0.62), (2, 0.86)):
            alpha = self._cell(self.albedo, k)[..., 3].astype(np.float64) / 255
            sooted = alpha[alpha > 0.35]
            self.assertGreater(float(np.median(sooted)), least, pasaje_marks.MARKS[k])

    def test_the_hand_is_too_big_to_be_a_persons(self):
        # (Its reach, wrist to fingertip, most of the cell: the set lays the cell 1.1 m across, a hand of 0.9 m.)
        hand = self._cell(self.albedo, 2)[..., 3] > 128
        ys, xs = np.nonzero(hand)
        self.assertGreater((ys.max() - ys.min()) / hand.shape[0], 0.7)


if __name__ == "__main__":
    unittest.main()
