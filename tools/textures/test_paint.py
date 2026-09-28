"""The painted textures' own tests (tools/textures/paint.py): the foliage we
paint ourselves, cut out and in many greens, and the bark that tiles.

    python3 -m unittest tools/textures/test_paint.py -v
"""

import os
import sys
import unittest

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import paint  # noqa: E402

FOLIAGE = ["leaf_crown", "leaf_shrub", "yew", "twigs", "grass", "weed_broad", "reeds", "ivy"]


class Foliage(unittest.TestCase):
    def test_every_foliage_painting_is_cut_out_clean(self):
        for name in FOLIAGE:
            with self.subTest(name):
                image = paint.PAINTINGS[name]()
                self.assertEqual(image.mode, "RGBA")
                alpha = np.asarray(image)[:, :, 3]
                self.assertTrue(set(np.unique(alpha)) <= {0, 255}, "alpha not cut clean")
                solid = float((alpha == 255).mean())
                self.assertGreater(solid, 0.15, "hardly anything painted")
                self.assertLess(solid, 0.9, "no gaps: a card, not leaves")

    def test_a_painting_is_a_power_of_two_on_each_side(self):
        for name in FOLIAGE + ["bark"]:
            with self.subTest(name):
                w, h = paint.PAINTINGS[name]().size
                self.assertEqual(w & (w - 1), 0)
                self.assertEqual(h & (h - 1), 0)

    def test_leaves_are_many_greens_not_a_flat_colour(self):
        for name in ["leaf_crown", "leaf_shrub", "yew", "grass", "weed_broad", "ivy"]:
            with self.subTest(name):
                pixels = np.asarray(paint.PAINTINGS[name]())
                solid = pixels[pixels[:, :, 3] == 255][:, :3].astype(int)
                colours = {tuple(p) for p in solid}
                self.assertGreaterEqual(len(colours), 10)
                # Green leads: more green than red or blue, taken together.
                mean = solid.mean(axis=0)
                self.assertGreater(mean[1], mean[0])
                self.assertGreater(mean[1], mean[2])

    def test_a_crown_is_lumpy_not_a_disc(self):
        # Its outline wanders: along rays from the middle, where the leaves
        # end varies by more than a fifth of the half-width.
        alpha = np.asarray(paint.PAINTINGS["leaf_crown"]())[:, :, 3]
        h, w = alpha.shape
        ends = []

        for angle in np.linspace(0.0, 2.0 * np.pi, 48, endpoint=False):
            last = 0

            for r in range(1, w // 2):
                x = int(w / 2 + np.cos(angle) * r)
                y = int(h / 2 + np.sin(angle) * r)

                if alpha[y, x] == 255:
                    last = r

            ends.append(last)

        self.assertGreater(max(ends) - min(ends), w * 0.1)

    def test_grass_and_reeds_grow_from_the_bottom(self):
        for name in ["grass", "reeds"]:
            with self.subTest(name):
                alpha = np.asarray(paint.PAINTINGS[name]())[:, :, 3]
                h = alpha.shape[0]
                bottom = (alpha[int(h * 0.85):] == 255).mean()
                top = (alpha[: int(h * 0.15)] == 255).mean()
                self.assertGreater(bottom, top)


class Bat(unittest.TestCase):
    def test_a_bat_is_two_frames_of_a_dark_cut_out_silhouette(self):
        image = paint.PAINTINGS["bat"]()
        w, h = image.size
        self.assertEqual((w, h), (128, 64))
        pixels = np.asarray(image)
        alpha = pixels[:, :, 3]
        self.assertTrue(set(np.unique(alpha)) <= {0, 255})
        left, right = alpha[:, : w // 2], alpha[:, w // 2:]
        # Both frames a bat, and not the same bat: its wings beat.
        self.assertGreater((left == 255).mean(), 0.05)
        self.assertGreater((right == 255).mean(), 0.05)
        self.assertGreater((left != right).mean(), 0.05)
        self.assertLess(pixels[alpha == 255][:, :3].mean(), 60)


class Bark(unittest.TestCase):
    def test_bark_is_solid_and_tiles_both_ways(self):
        image = np.asarray(paint.PAINTINGS["bark"]().convert("RGB")).astype(float)
        # The last column runs on into the first, the last row into the first,
        # as smoothly as columns inside it do.
        inside = np.abs(np.diff(image, axis=1)).mean()
        seam = np.abs(image[:, -1] - image[:, 0]).mean()
        self.assertLess(seam, inside * 2.0 + 4.0)
        inside_v = np.abs(np.diff(image, axis=0)).mean()
        seam_v = np.abs(image[-1] - image[0]).mean()
        self.assertLess(seam_v, inside_v * 2.0 + 4.0)

    def test_bark_runs_in_furrows_up_the_trunk(self):
        # Rougher across (x) than up (y): its furrows run up the trunk.
        image = np.asarray(paint.PAINTINGS["bark"]().convert("L")).astype(float)
        self.assertGreater(np.abs(np.diff(image, axis=1)).mean(), np.abs(np.diff(image, axis=0)).mean() * 1.3)


if __name__ == "__main__":
    unittest.main()
