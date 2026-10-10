"""The painterly look's brush tile and the Zócalo palette (painterly.py).

    python3 tools/textures/test_painterly.py
"""

import io
import os
import sys
import unittest

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import kuwahara  # noqa: E402
import painterly  # noqa: E402

ZOCALO = [
    "#14121a", "#2f4c7a", "#3a3340", "#5a5560", "#8a8790", "#b9b4b0", "#3d1f1c", "#6e2f26",
    "#9a4a3a", "#2a3b2e", "#3f7a52", "#7fd18a", "#7a5a24", "#c49a40", "#e8d8a8", "#d8e4f0",
]


def _bytes(image):
    out = io.BytesIO()
    image.save(out, "PNG")
    return out.getvalue()


class Brush(unittest.TestCase):
    """The brush tile after the user's reference (Oct 9 2026): soft, low
    contrast, sweeping strokes with bristle streaks, mostly one shallow
    diagonal way, seamless."""

    @classmethod
    def setUpClass(cls):
        cls.pixels = np.asarray(painterly.brush(), dtype=np.float64)

    def test_brush_is_seamless(self):
        neighbours = np.abs(np.diff(self.pixels, axis=1)).mean()
        across_x = np.abs(self.pixels[:, 0] - self.pixels[:, -1]).mean()
        across_y = np.abs(self.pixels[0, :] - self.pixels[-1, :]).mean()
        self.assertEqual(self.pixels.shape, (painterly.BRUSH_SIZE, painterly.BRUSH_SIZE))
        self.assertLess(across_x, neighbours * 1.5)
        self.assertLess(across_y, np.abs(np.diff(self.pixels, axis=0)).mean() * 1.5)

    def test_brush_is_soft_like_paint(self):
        """Low contrast round a mid grey, as plaster worked with a brush."""
        self.assertLess(abs(self.pixels.mean() - 128), 4)
        self.assertGreater(self.pixels.std(), 7)
        self.assertLess(self.pixels.std(), 20)

    def test_brush_sweeps_one_way(self):
        """Its strokes lie mostly within 35 degrees of a shallow diagonal, with
        smudges between them (coherent, but not ruled lines)."""
        angle, coherence = kuwahara.structure(self.pixels[..., None] / 255.0, sigma=6.0)
        degrees = np.degrees(angle) % 180.0
        strong = coherence > 0.3
        near = np.minimum(np.abs(degrees - 15.0), 180.0 - np.abs(degrees - 15.0)) < 35.0
        self.assertGreater(near[strong].mean(), 0.6)
        self.assertGreater(coherence.mean(), 0.25)
        self.assertLess(coherence.mean(), 0.75)

    def test_brush_has_bristle_streaks(self):
        """Fine streaks inside the strokes: detail at a small scale too."""
        fine = np.abs(self.pixels - np.asarray(kuwahara.gaussian(self.pixels, 3.0))).mean()
        self.assertGreater(fine, 1.5)

    def test_brush_is_deterministic(self):
        self.assertEqual(_bytes(painterly.brush()), _bytes(painterly.brush()))


class Palette(unittest.TestCase):
    def test_palette_zocalo(self):
        image = painterly.palette(painterly.ZOCALO)
        self.assertEqual(image.size, (16, 1))
        got = ["#%02x%02x%02x" % image.getpixel((i, 0))[:3] for i in range(16)]
        self.assertEqual(got, ZOCALO)


if __name__ == "__main__":
    unittest.main()
