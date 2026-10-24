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

import plan  # noqa: E402
import plan_draw  # noqa: E402
from plan import rect  # noqa: E402
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

    def test_hundred_metre_lines_are_darker_than_the_grid(self):
        # x -160 is a 100 m line (the brink starts at -260); z -195 is open
        # paper between 10 m rows.
        on = self.pixel("street", -160, -195)
        off = self.pixel("street", -155, -195)
        self.assertLess(int(on.sum()), int(off.sum()) - 60, (on, off))

    def test_north_is_up(self):
        self.assertLess(self.to_px(0, -100)[1], self.to_px(0, 100)[1])
        self.assertLess(self.to_px(-100, 0)[0], self.to_px(100, 0)[0])


class Bands(unittest.TestCase):
    """Stacked spaces drawn one sheet per depth band; a plan with no brink
    drawn over the bounds of what it holds."""

    BANDS = [(-10.0, -4.0, "station"), (-16.0, -10.0, "market"), (-40.0, -16.0, "old")]

    @classmethod
    def setUpClass(cls):
        P = plan.Plan("stack")
        P.space("upper", rect(0, 0, 40, 20), floor=-8.0, height=4.0, layer=1)
        P.space("middle", rect(60, 0, 80, 30), floor=-14.0, height=4.0, layer=2)
        P.space("lower", rect(10, 40, 30, 90), floor=-20.0, height=4.0, layer=3)
        cls.data = P.data()
        cls.out = Path(tempfile.mkdtemp())
        cls.paths = plan_draw.draw(cls.data, cls.out, px_per_m=2.0, bands=cls.BANDS)
        cls.to_px = staticmethod(plan_draw.projection(cls.data, 2.0))

    @classmethod
    def tearDownClass(cls):
        shutil.rmtree(cls.out)

    def test_layer_stored(self):
        self.assertEqual([s["layer"] for s in self.data["spaces"]], [1, 2, 3])

    def test_band_sheets_written(self):
        for label in ("station", "market", "old"):
            self.assertIn(self.out / ("plan_underground_%s.png" % label), self.paths)

    def test_each_band_holds_its_own_space(self):
        spaces = {s["name"]: s for s in self.data["spaces"]}

        for label, name in (("station", "upper"), ("market", "middle"), ("old", "lower")):
            image = np.asarray(Image.open(self.out / ("plan_underground_%s.png" % label)).convert("RGB"), dtype=np.int64)
            # Coloured: far from grey (paper, grid and ink are greys); over
            # the map, not the legend in the margin above it.
            coloured = (image.max(axis=2) - image.min(axis=2)) > 40
            coloured[:plan_draw.MARGIN] = False
            ys, xs = np.nonzero(coloured)
            xs0 = [p[0] for p in spaces[name]["polygon"]]
            zs0 = [p[1] for p in spaces[name]["polygon"]]
            (ax, ay), (bx, by) = self.to_px(min(xs0), min(zs0)), self.to_px(max(xs0), max(zs0))
            self.assertLessEqual(abs(xs.min() - ax), 3, label)
            self.assertLessEqual(abs(xs.max() - bx), 3, label)
            self.assertLessEqual(abs(ys.min() - ay), 3, label)
            self.assertLessEqual(abs(ys.max() - by), 3, label)

    def test_bands_from_the_data(self):
        data = dict(self.data, bands=[list(b) for b in self.BANDS])
        out = Path(tempfile.mkdtemp())

        try:
            names = {p.name for p in plan_draw.draw(data, out)}
        finally:
            shutil.rmtree(out)

        self.assertIn("plan_underground_old.png", names)


if __name__ == "__main__":
    unittest.main()
