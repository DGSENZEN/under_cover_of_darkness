"""The converter's own tests: synthetic images only, so they run anywhere,
with or without the bought photos.

    python3 -m unittest tools/textures/test_ps2ify.py -v
"""

import os
import sys
import tempfile
import unittest
from pathlib import Path

import numpy as np
from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import ps2ify  # noqa: E402


def recipe(**changes):
    base = {
        "source": "x.png",
        "size": [128, 128],
        "colours": 32,
        "crop": None,
        "tint": [1.0, 1.0, 1.0],
        "contrast": 1.0,
        "brightness": 1.0,
        "desaturate": 0.0,
        "grime": 0.0,
        "ao": None,
        "alpha": "none",
        "threshold": 128,
        "key": None,
    }
    base.update(changes)
    return base


def noise(width, height, seed=1):
    rng = np.random.default_rng(seed)
    return Image.fromarray(rng.integers(0, 256, (height, width, 3), dtype=np.uint8), "RGB")


class Ps2ifyTest(unittest.TestCase):
    def test_size(self):
        out = ps2ify.convert(noise(700, 500), recipe(size=[128, 128]))
        self.assertEqual(out.size, (128, 128))

    def test_palette(self):
        out = ps2ify.convert(noise(300, 300), recipe(colours=16))
        colours = {tuple(p) for p in np.asarray(out.convert("RGB")).reshape(-1, 3)}
        self.assertLessEqual(len(colours), 16)

    def test_no_dither(self):
        ramp = np.tile(np.linspace(0, 255, 256, dtype=np.uint8), (64, 1))
        image = Image.fromarray(np.stack([ramp] * 3, axis=2), "RGB")
        out = np.asarray(ps2ify.convert(image, recipe(size=[256, 64], colours=4)).convert("L"))

        for row in out:
            changes = int(np.count_nonzero(np.diff(row.astype(int))))
            self.assertLessEqual(changes, 3)

    def test_threshold_alpha(self):
        alpha = np.tile(np.linspace(0, 255, 128, dtype=np.uint8), (128, 1))
        rgb = np.full((128, 128, 3), 120, dtype=np.uint8)
        image = Image.fromarray(np.dstack([rgb, alpha]), "RGBA")
        out = ps2ify.convert(image, recipe(alpha="threshold"))
        self.assertTrue(set(np.unique(np.asarray(out.convert("RGBA"))[:, :, 3])) <= {0, 255})

    def test_crop(self):
        pixels = np.zeros((200, 200, 3), dtype=np.uint8)
        pixels[:100, :100] = (230, 20, 20)
        pixels[:100, 100:] = (20, 230, 20)
        pixels[100:] = (20, 20, 230)
        out = np.asarray(ps2ify.convert(Image.fromarray(pixels, "RGB"), recipe(crop=[0, 0, 0.5, 0.5], size=[64, 64])).convert("RGB")).reshape(-1, 3)
        red = np.count_nonzero((out[:, 0] > 200) & (out[:, 1] < 60) & (out[:, 2] < 60))
        self.assertGreaterEqual(red / len(out), 0.95)

    def test_key(self):
        pixels = np.full((64, 64, 3), 255, dtype=np.uint8)
        pixels[24:40, 24:40] = (60, 50, 40)
        out = np.asarray(ps2ify.convert(Image.fromarray(pixels, "RGB"), recipe(size=[64, 64], key=[255, 255, 255, 30], alpha="threshold")).convert("RGBA"))
        self.assertEqual(out[2, 2, 3], 0)
        self.assertEqual(out[32, 32, 3], 255)

    def test_sixteen_bit(self):
        with tempfile.TemporaryDirectory() as folder:
            path = Path(folder) / "deep.tif"
            deep = (np.random.default_rng(3).integers(0, 65535, (90, 90))).astype(np.uint16)
            Image.fromarray(deep).save(path)
            out = ps2ify.convert(Image.open(path), recipe(size=[32, 32]))
            self.assertEqual(out.size, (32, 32))

    def test_missing_source(self):
        with tempfile.TemporaryDirectory() as folder:
            recipes = Path(folder) / "recipes"
            recipes.mkdir()
            (recipes / "x.json").write_text('{"source": "TCom_Nowhere_S.jpg", "size": [64, 64], "colours": 8}')

            with self.assertRaises(FileNotFoundError) as caught:
                ps2ify.build("x", Path(folder) / "empty", Path(folder) / "out", recipes)

            self.assertIn("TCom_Nowhere_S.jpg", str(caught.exception))


if __name__ == "__main__":
    unittest.main()
