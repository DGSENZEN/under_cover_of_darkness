"""python3 -m unittest discover -s tests/tools -p 'test_make_city_masks.py'"""
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
CITY = ROOT / 'assets/ui/main_menu/city.png'


class CityMasks(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.out = Path(tempfile.mkdtemp()) / 'city_masks.png'
        before = CITY.read_bytes()
        subprocess.run([sys.executable, str(ROOT / 'tools/make_city_masks.py'), '--out', str(cls.out)], check=True)
        cls.untouched = CITY.read_bytes() == before
        cls.masks = np.asarray(Image.open(cls.out).convert('RGBA')).astype(float) / 255.0

    def test_same_size_as_painting(self):
        self.assertEqual(Image.open(self.out).size, Image.open(CITY).size)

    def test_painting_untouched(self):
        self.assertTrue(self.untouched)

    def test_sky_is_up_top(self):
        sky = self.masks[..., 0] > 0.5
        rows = sky.shape[0]
        self.assertGreater(sky[: rows // 4].mean(), 0.2)
        self.assertLess(sky[-rows // 4:].mean(), 0.02)

    def test_lights_are_few_and_small(self):
        lights = self.masks[..., 1] > 0.5
        self.assertTrue(0.002 <= lights.mean() <= 0.04, lights.mean())

    def test_reflections_only_low(self):
        water = self.masks[..., 2]
        self.assertEqual(water[: int(water.shape[0] * 0.6)].max(), 0.0)
        self.assertGreater((water > 0.5).mean(), 0.01)

    def test_haze_low_and_behind_near_buildings(self):
        haze = self.masks[..., 3]
        h, w = haze.shape
        self.assertEqual(haze[: int(h * 0.55)].max(), 0.0)
        self.assertEqual(haze[int(h * 0.9):, int(w * 0.26)].max(), 0.0)  # the near tower at x 0.26
        self.assertGreater(haze[int(h * 0.74), int(w * 0.5)], 0.9)  # open lake


if __name__ == '__main__':
    unittest.main()
