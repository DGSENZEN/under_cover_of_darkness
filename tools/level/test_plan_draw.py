"""The plan sheets (plan_draw.py), drawn from the checks' small town.

    python3 tools/level/test_plan_draw.py
"""

import os
import shutil
import sys
import tempfile
import unittest
from pathlib import Path

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
sys.path.insert(0, os.path.join(HERE, "layouts"))

import plan_draw  # noqa: E402
from test_plan_check import _town  # noqa: E402


class Sheets(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.out = Path(tempfile.mkdtemp())
        cls.data = _town().data()
        cls.paths = plan_draw.draw(cls.data, cls.out, px_per_m=2.0)
        cls.to_px = staticmethod(plan_draw.projection(cls.data, 2.0))

    @classmethod
    def tearDownClass(cls):
        shutil.rmtree(cls.out)

    def pixel(self, sheet, x, z):
        image = np.asarray(Image.open(self.out / ("plan_%s.png" % sheet)).convert("RGB"), dtype=np.int64)
        px, py = self.to_px(x, z)
        return image[int(py), int(px)]

    def test_six_sheets_written(self):
        self.assertEqual(sorted(p.name for p in self.paths), sorted("plan_%s.png" % s for s in plan_draw.SHEETS))

        for p in self.paths:
            self.assertTrue(p.exists())

    def test_sheet_size_matches_the_brink(self):
        image = Image.open(self.out / "plan_street.png")
        self.assertEqual(image.size, (520 * 2 + 2 * plan_draw.MARGIN, 520 * 2 + 2 * plan_draw.MARGIN))

    def test_plot_drawn_in_its_family_colour(self):
        got = self.pixel("street", 65, -35)
        want = np.array(plan_draw.FAMILY_COLOURS["house"])
        self.assertLessEqual(np.abs(got - want).max(), 8, (got, want))

    def test_events_sheet_reddens_at_subsidence_centre(self):
        self.assertGreater(self.pixel("events", -2, -2)[0], self.pixel("events", 0, 200)[0] + 40)

    def test_north_is_up(self):
        self.assertLess(self.to_px(0, -100)[1], self.to_px(0, 100)[1])
        self.assertLess(self.to_px(-100, 0)[0], self.to_px(100, 0)[0])


if __name__ == "__main__":
    unittest.main()
