"""The anisotropic Kuwahara filter (kuwahara.py): pure numpy.

    python3 tools/textures/test_kuwahara.py
"""

import os
import sys
import unittest

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import kuwahara  # noqa: E402

N = 48


def _step(noise=0.06, seed=3):
    """Dark on the left, light on the right, a little grain over both."""
    rng = np.random.default_rng(seed)
    image = np.zeros((N, N, 3))
    image[:, : N // 2] = 0.2
    image[:, N // 2:] = 0.8
    return np.clip(image + rng.normal(0, noise, image.shape), 0, 1)


class Kuwahara(unittest.TestCase):
    def test_flat_stays_flat(self):
        flat = np.full((N, N, 3), 0.37)
        out = kuwahara.anisotropic(flat, radius=4)
        self.assertLess(np.abs(out - 0.37).max(), 1e-6)

    def test_edges_stay_while_grain_goes(self):
        image = _step()
        out = kuwahara.anisotropic(image, radius=4)
        # Two texels either side of the edge keep their own side's value...
        self.assertLess(np.abs(out[8:-8, N // 2 - 3] - 0.2).max(), 0.08)
        self.assertLess(np.abs(out[8:-8, N // 2 + 2] - 0.8).max(), 0.08)
        # ...while the grain inside each side is smoothed away by half or more.
        self.assertLess(out[8:-8, 4:N // 2 - 6].std(), image[8:-8, 4:N // 2 - 6].std() * 0.5)

    def test_wraps_seamlessly(self):
        """A tile filtered then shifted is the tile shifted then filtered: no seam at its edges."""
        image = _step(seed=5)
        a = np.roll(kuwahara.anisotropic(image, radius=3), (7, 11), axis=(0, 1))
        b = kuwahara.anisotropic(np.roll(image, (7, 11), axis=(0, 1)), radius=3)
        self.assertLess(np.abs(a - b).max(), 1e-6)

    def test_extra_maps_follow_the_colours_weights(self):
        """A map filtered alongside (the scan's normals) takes the colour's
        choices: given the colour itself, it comes out as the colour does."""
        image = _step(seed=7)
        out, extra = kuwahara.anisotropic(image, radius=3, extra=image.copy())
        self.assertLess(np.abs(out - extra).max(), 1e-6)


if __name__ == "__main__":
    unittest.main()
