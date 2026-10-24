"""The librarian's rugs (rugs.py): their designs drawn knot by knot, pure Python.

    python3 tools/textures/test_rugs.py
"""

import os
import sys
import unittest

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import rugs  # noqa: E402


def _near(image, colour, within=40.0):
    """How much of `image` lies within `within` of `colour` (RGB), 0-1."""
    d = np.linalg.norm(image[..., :3].astype(float) - np.array(colour, float), axis=-1)
    return float((d < within).mean())


def _hex(code):
    return tuple(int(code[i:i + 2], 16) for i in (1, 3, 5))


class Rugs(unittest.TestCase):
    def test_every_kind_is_drawn_at_its_size(self):
        for kind, (width, length, density) in rugs.RUGS.items():
            image = np.asarray(rugs.make(kind))
            # (Across the rug the image's width, along it the image's height, a knot a pixel.)
            self.assertEqual(image.shape[:2], (round(length * density), round(width * density)), kind)
            self.assertEqual(image.shape[2], 3, kind)

    def test_designs_are_mirror_true_before_wear(self):
        # A woven design is drawn the same both sides of its middle, across and along, before it is worn.
        for kind in ("zapotec", "persian", "sarape"):
            image = np.asarray(rugs.make(kind, worn=False)).astype(int)
            self.assertTrue((image == image[:, ::-1]).mean() > 0.97, kind)
            self.assertTrue((image == image[::-1]).mean() > 0.97, kind)

    def test_the_teotitlan_rug_is_dyed_as_theirs_are(self):
        # Undyed cream, cochineal red and indigo carry most of it; its outer band is indigo all round.
        image = np.asarray(rugs.make("zapotec", worn=False))
        palette = rugs.PALETTES["zapotec"]
        self.assertGreater(_near(image, _hex(palette["cochineal"])), 0.08)
        self.assertGreater(_near(image, _hex(palette["indigo"])), 0.08)
        self.assertGreater(_near(image, _hex(palette["cream"])), 0.2)
        edge = image[rugs.FRINGE:-rugs.FRINGE, 0]
        self.assertGreater(_near(edge[:, None], _hex(palette["indigo"])), 0.95)

    def test_the_teotitlan_border_is_a_step_fret(self):
        # Its greca repeats down the rug's length at its own period, and turns (not a stripe: it changes across too).
        image = np.asarray(rugs.make("zapotec", worn=False)).astype(int)
        band = image[:, rugs.ZAPOTEC_GRECA[0]:rugs.ZAPOTEC_GRECA[1]]
        period = rugs.ZAPOTEC_GRECA_PERIOD
        middle = band[60:60 + 2 * period]
        self.assertTrue((middle[:period] == middle[period:]).all())
        self.assertGreater(len({tuple(map(tuple, row)) for row in middle}), 2)

    def test_the_persian_runner_has_medallions_down_its_field(self):
        image = np.asarray(rugs.make("persian", worn=False))
        palette = rugs.PALETTES["persian"]
        madder = _hex(palette["madder"])
        y0, y1 = rugs.PERSIAN_FIELD
        column = image[y0:y1, image.shape[1] // 2].astype(float)
        # (Down the middle of its madder field, runs of something else: the medallions, three of them, apart.)
        other = np.linalg.norm(column - np.array(madder, float), axis=-1) > 40
        runs = np.diff(np.concatenate([[0], other.astype(int), [0]]))
        self.assertEqual(int((runs == 1).sum()), rugs.PERSIAN_MEDALLIONS)

    def test_wear_pales_the_path_people_walk(self):
        for kind in ("zapotec", "persian"):
            worn = np.asarray(rugs.make(kind)).astype(float)
            fresh = np.asarray(rugs.make(kind, worn=False)).astype(float)
            w = worn.shape[1]
            middle = (worn - fresh)[:, w * 2 // 5:w * 3 // 5].mean()
            edges = (worn - fresh)[:, :w // 8].mean()
            self.assertGreater(middle, edges + 4.0, kind)

    def test_the_petate_is_woven_on_the_bias(self):
        # Palm strips in a twill: a strip's light and dark alternate in runs, and the runs step diagonally.
        image = np.asarray(rugs.make("petate", worn=False)).astype(float).mean(axis=-1)
        strand = rugs.PETATE_STRAND
        y = 10 * strand + strand // 2
        row, next_row = image[y], image[y + strand]
        self.assertGreater(np.abs(np.diff(row)).max(), 12.0)
        # (The next strip's runs are this strip's moved along by a strip: matched best shifted, not in place.)
        shifted = [np.abs(row[s:] - next_row[:len(row) - s]).mean() for s in range(0, 2 * strand + 1)]
        self.assertLess(min(shifted[1:]), 0.5 * shifted[0])


if __name__ == "__main__":
    unittest.main()
