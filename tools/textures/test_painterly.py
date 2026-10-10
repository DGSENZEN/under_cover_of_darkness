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


class Ramp(unittest.TestCase):
    """The light ramp (variant D): how much light a surface takes, as a
    colour, from no light to full; the user may repaint it."""

    def setUp(self):
        self.ramp = np.asarray(painterly.ramp(), dtype=np.float64)

    def test_ramp_is_a_strip(self):
        self.assertEqual(self.ramp.shape, (1, painterly.RAMP_SIZE, 3))

    def test_ramp_never_darkens_toward_the_light(self):
        luma = self.ramp[0] @ np.array([0.299, 0.587, 0.114])
        self.assertTrue(np.all(np.diff(luma) >= -0.5))
        self.assertGreater(luma[-1], luma[0] + 150)

    def test_ramp_is_warm_where_lit(self):
        """The user asked for it warmer (Oct 9 2026): its lit half leans red
        over blue, and its middle too."""
        for i in (self.ramp.shape[1] // 2 + 4, self.ramp.shape[1] - 2):
            self.assertGreater(self.ramp[0, i, 0], self.ramp[0, i, 2] + 25)

    def test_ramp_cools_into_shadow_and_warms_into_light(self):
        cool = lambda c: c[2] / (c.sum() + 1)
        self.assertGreater(cool(self.ramp[0, 2]), cool(self.ramp[0, -2]) + 0.05)

    def test_ramp_steps_in_a_few_soft_bands(self):
        """Most of it lies on a few plateaus, not a smooth slope."""
        luma = self.ramp[0] @ np.array([0.299, 0.587, 0.114])
        flat = np.abs(np.diff(luma)) < 1.0
        self.assertGreater(flat.mean(), 0.6)


class Pool(unittest.TestCase):
    """A Company lamp's painted pool of light (variant D)."""

    def setUp(self):
        self.pool = np.asarray(painterly.pool(), dtype=np.float64)

    def test_pool_is_bright_at_its_heart_and_dark_at_its_rim(self):
        n = self.pool.shape[0]
        self.assertGreater(self.pool[n // 2 - 4:n // 2 + 4, n // 2 - 4:n // 2 + 4].mean(), 200)
        self.assertLess(np.concatenate([self.pool[:4].ravel(), self.pool[-4:].ravel()]).max(), 5)

    def test_pool_edge_is_broken_by_strokes(self):
        """Not a clean disc: round the middle radius, light and dark mix."""
        n = self.pool.shape[0]
        yy, xx = np.mgrid[:n, :n] - (n - 1) / 2
        ring = np.abs(np.hypot(yy, xx) - n * 0.32) < 2
        self.assertGreater(self.pool[ring].std(), 25)


class Macro(unittest.TestCase):
    """The world macro layer (the vertex-paint plan, Task 8): soft blotches
    the shader lays over everything at tens of metres, so no two copies of
    a kit piece match. R value, G warmth, B grime."""

    @classmethod
    def setUpClass(cls):
        cls.pixels = np.asarray(painterly.macro(), dtype=np.float64)

    def test_macro_is_seamless(self):
        self.assertEqual(self.pixels.shape, (painterly.MACRO_SIZE, painterly.MACRO_SIZE, 3))

        for c in range(3):
            channel = self.pixels[..., c]
            self.assertLess(np.abs(channel[:, 0] - channel[:, -1]).mean(), np.abs(np.diff(channel, axis=1)).mean() * 1.5)
            self.assertLess(np.abs(channel[0, :] - channel[-1, :]).mean(), np.abs(np.diff(channel, axis=0)).mean() * 1.5)

    def test_macro_is_soft(self):
        """Nine tenths of its energy below an eighth of the tile's frequencies
        (8 cycles across 256 px): big blotches, not grain."""
        n = painterly.MACRO_SIZE
        f = np.fft.fftfreq(n)
        radius = np.hypot(*np.meshgrid(f, f))

        for c in range(3):
            power = np.abs(np.fft.fft2(self.pixels[..., c] - self.pixels[..., c].mean())) ** 2
            self.assertGreater(power[radius <= 0.5 / 16].sum() / power.sum(), 0.9)

    def test_macro_channels_centred(self):
        for c in range(3):
            self.assertLess(abs(self.pixels[..., c].mean() - 128), 6)
            self.assertGreater(self.pixels[..., c].std(), 12)

    def test_macro_is_deterministic(self):
        self.assertEqual(_bytes(painterly.macro()), _bytes(painterly.macro()))


class Palette(unittest.TestCase):
    def test_palette_zocalo(self):
        image = painterly.palette(painterly.ZOCALO)
        self.assertEqual(image.size, (16, 1))
        got = ["#%02x%02x%02x" % image.getpixel((i, 0))[:3] for i in range(16)]
        self.assertEqual(got, ZOCALO)


if __name__ == "__main__":
    unittest.main()
