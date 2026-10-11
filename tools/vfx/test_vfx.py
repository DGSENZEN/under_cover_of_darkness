"""Checks on our own effect sheets (tools/vfx/vfx.sh renders and draws
them; the effects plan, Task 2): sizes, frames filled and moving, six-way
lights distinct, fire warm, the sigil's stroke order, the sparks.

    python3 -m unittest tools/vfx/test_vfx.py -v
"""

import json
import unittest
from pathlib import Path

import numpy as np
from PIL import Image

VFX = Path(__file__).resolve().parents[2] / "assets" / "vfx"
SIX_WAY = ["plume", "puff"]
SHEETS = {"plume": ["plume_a", "plume_b"], "puff": ["puff_a", "puff_b"], "fire": ["fire"], "sparks": ["sparks"],
          "sigil_strokes": ["sigil_strokes"]}


def _sheet(name):
    return np.asarray(Image.open(VFX / (name + ".png")).convert("RGBA"), dtype=np.float64) / 255.0


def _radial_variation(mask):
    """How much a shape's edge strays from a circle: its radius from its
    middle measured at 64 angles, their spread over their mean."""
    ys, xs = np.nonzero(mask)
    cy, cx = ys.mean(), xs.mean()
    radii = []

    for a in np.linspace(0, 2 * np.pi, 64, endpoint=False):
        steps = np.arange(0, mask.shape[0], 0.5)
        y, x = (cy - np.cos(a) * steps).astype(int), (cx + np.sin(a) * steps).astype(int)
        inside = (y >= 0) & (y < mask.shape[0]) & (x >= 0) & (x < mask.shape[1])
        hit = steps[inside][mask[y[inside], x[inside]]]
        radii.append(hit.max() if len(hit) else 0.0)

    radii = np.array(radii)
    return radii.std() / max(radii.mean(), 1e-6)


def _cells(sheet, meta):
    h, v = meta["grid"]
    px = meta["px"]
    return [sheet[j * px:(j + 1) * px, i * px:(i + 1) * px] for j in range(v) for i in range(h)][:meta["frames"]]


class Sheets(unittest.TestCase):
    def test_sized_by_their_grid(self):
        for name, files in SHEETS.items():
            meta = json.loads((VFX / (name + ".json")).read_text())

            for f in files:
                image = Image.open(VFX / (f + ".png"))
                self.assertEqual(image.size, (meta["grid"][0] * meta["px"], meta["grid"][1] * meta["px"]), f)

    def test_frames_filled_and_moving(self):
        for name in ("plume", "puff", "fire", "sparks"):
            meta = json.loads((VFX / (name + ".json")).read_text())
            cells = _cells(_sheet(SHEETS[name][0]), meta)
            self.assertEqual(len(cells), meta["frames"], name)

            for k, c in enumerate(cells):
                self.assertGreater(c[:, :, 3].max(), 0.2, (name, k, "empty frame"))

            moving = [np.abs(a[:, :, 3] - b[:, :, 3]).mean() for a, b in zip(cells, cells[1:])]
            self.assertGreater(min(moving), 0.001, (name, "two frames alike"))

    def test_six_lights_differ(self):
        for name in SIX_WAY:
            a, b = _sheet(name + "_a"), _sheet(name + "_b")
            shown = a[:, :, 3] > 0.3

            for k, light in enumerate(("right/left", "top/bottom", "back/front")):
                diff = np.abs(a[:, :, k][shown] - b[:, :, k][shown]).mean()
                self.assertGreater(diff, 0.02, (name, light))

    def test_fire_is_warm(self):
        fire = _sheet("fire")
        shown = fire[:, :, 3] > 0.3
        self.assertGreater(fire[:, :, 0][shown].mean(), fire[:, :, 2][shown].mean() + 0.15)

    def test_billows_fill_their_frames(self):
        # (A billow in a fifth of its frame draws a 2 m sprite as a disc of
        # smoke a few hands wide: the copal seen as scattered balls.)
        for name in SIX_WAY:
            meta = json.loads((VFX / (name + ".json")).read_text())
            cover = [(c[:, :, 3] > 0.3).mean() for c in _cells(_sheet(name + "_a"), meta)]
            self.assertGreater(min(cover), 0.2, (name, "a frame mostly empty"))
            self.assertGreater(float(np.median(cover)), 0.3, (name, "frames mostly empty"))

    def test_billows_are_not_discs(self):
        # Lumpy silhouettes, never the ball a sim starts from: their radius
        # from the middle varies round them (a sphere's: 0.04; the in-game
        # discs were small blobs in big sprites, which the fill test
        # catches).
        for name in SIX_WAY:
            meta = json.loads((VFX / (name + ".json")).read_text())

            for k, c in enumerate(_cells(_sheet(name + "_a"), meta)):
                self.assertGreater(_radial_variation(c[:, :, 3] > 0.3), 0.05, (name, k, "a disc"))

    def test_fire_has_tongues(self):
        # A bed of flames, not a column on a white-hot ball: wider than a
        # column, split into tongues (where it burns hot enough for the
        # flame shader to draw: heat, its glow by its coverage, past 0.25),
        # its foot not white.
        meta = json.loads((VFX / "fire.json").read_text())
        split = 0

        for k, c in enumerate(_cells(_sheet("fire"), meta)):
            shown = c[:, :, 3] > 0.3
            ys, xs = np.nonzero(shown)
            tall = ys.max() - ys.min()
            self.assertGreater((xs.max() - xs.min()) / tall, 0.5, (k, "a column"))
            foot = c[int(ys.max() - tall * 0.25):ys.max() + 1]
            self.assertLess(foot[:, :, :3].min(axis=2)[foot[:, :, 3] > 0.3].mean(), 0.75, (k, "a white-hot foot"))
            hot = (c[:, :, 0] * 0.3 + c[:, :, 1] * 0.59 + c[:, :, 2] * 0.11) * c[:, :, 3] > 0.25
            row = hot[int(ys.min() + tall * 0.5)]
            split += np.count_nonzero(np.diff(row.astype(int)) == 1) >= 2

        self.assertGreaterEqual(split, meta["frames"] // 2, "one tongue")

    def test_sigil_strokes_draw_in_order(self):
        sigil = _sheet("sigil_strokes")
        drawn = sigil[:, :, 3] > 0.5
        self.assertTrue(0.03 < drawn.mean() < 0.4, drawn.mean())
        order = sigil[:, :, 0][drawn]
        self.assertLess(order.min(), 0.1)
        self.assertGreater(order.max(), 0.9)


if __name__ == "__main__":
    unittest.main()
