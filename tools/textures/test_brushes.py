"""The user's brush sheets prepared for the painters (brushes.py): pure
Python, on synthetic sheets in a temporary folder.

    python3 tools/textures/test_brushes.py
"""

import os
import sys
import tempfile
import unittest
from pathlib import Path

import numpy as np
from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import brushes  # noqa: E402


def _sheet(path, seed, step=False):
    """A greyscale sheet with alpha: smooth noise, and with `step` a hard
    edge where its left and right (and top and bottom) borders meet."""
    rng = np.random.default_rng(seed)
    v = rng.random((128, 128))
    for _ in range(4):
        v = (v + np.roll(v, 1, 0) + np.roll(v, 1, 1) + np.roll(v, -1, 0) + np.roll(v, -1, 1)) / 5
    v = (v - v.min()) / (v.max() - v.min())
    if step:
        v = np.clip(v * 0.5 + np.linspace(0, 0.5, 128)[None, :] + np.linspace(0, 0.5, 128)[:, None] * 0.5, 0, 1)
    grey = (v * 255).astype(np.uint8)
    alpha = np.full_like(grey, 200)
    Image.fromarray(np.dstack([grey, grey, grey, alpha]), "RGBA").save(path)


def _seam_ratio(values, axis):
    """How much harsher the wrap seam is than an ordinary step between
    neighbours, along one axis."""
    a = np.moveaxis(values, axis, 1)
    seam = np.abs(a[:, 0] - a[:, -1]).mean()
    inside = np.abs(np.diff(a, axis=1)).mean()
    return seam / inside


class Brushes(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.src = Path(self.tmp.name) / "downloads"
        self.out = Path(self.tmp.name) / "brushes"
        self.src.mkdir()
        for i in range(5):
            name = "Texture_Abstract01 .png" if i == 1 else "Texture_Abstract%02d.png" % i
            _sheet(self.src / name, i, step=True)

    def tearDown(self):
        self.tmp.cleanup()

    def test_space_in_name(self):
        written = brushes.prepare(self.src, self.out)
        self.assertEqual(sorted(p.name for p in written), ["brush_%02d.png" % i for i in range(5)])
        self.assertTrue((self.out / "brush_01.png").exists())

    def test_size_and_alpha_kept(self):
        brushes.prepare(self.src, self.out)
        with Image.open(self.out / "brush_03.png") as image:
            size, mode = image.size, image.mode
        self.assertEqual(size, (1024, 1024))
        self.assertEqual(mode, "LA")

    def test_seamless(self):
        brushes.prepare(self.src, self.out)
        for i in range(5):
            values = brushes.load("brush_%02d" % i, self.out)
            for axis in (0, 1):
                self.assertLessEqual(_seam_ratio(values, axis), 1.5, "brush_%02d axis %d" % (i, axis))

    def test_middle_left_as_the_user_painted_it(self):
        # Hiding the seam must not touch the sheet's middle (a turned copy blended there leaves a
        # soft cross that repeats across every surface it is laid on).
        brushes.prepare(self.src, self.out)
        for i in range(5):
            name = "Texture_Abstract01 .png" if i == 1 else "Texture_Abstract%02d.png" % i
            source = Image.open(self.src / name).convert("LA").resize((brushes.SIZE, brushes.SIZE), Image.LANCZOS)
            grey, alpha = np.asarray(source).astype(np.float32).transpose(2, 0, 1) / 255.0
            want = grey * alpha
            got = brushes.load("brush_%02d" % i, self.out)
            middle = slice(brushes.SIZE // 4, 3 * brushes.SIZE // 4)
            self.assertLess(np.abs(got[middle, middle] - want[middle, middle]).max(), 2.5 / 255, "brush_%02d" % i)

    def test_load_premultiplies_alpha(self):
        brushes.prepare(self.src, self.out)
        values = brushes.load("brush_00", self.out)
        self.assertEqual(values.dtype, np.float32)
        self.assertLessEqual(values.max(), 200 / 255 + 1e-6)
        self.assertGreaterEqual(values.min(), 0.0)

    def test_missing_sheet_message(self):
        with self.assertRaises(FileNotFoundError) as caught:
            brushes.load("brush_03", self.out)
        self.assertIn("brushes.py", str(caught.exception))


if __name__ == "__main__":
    unittest.main()
