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

    def test_sigil_strokes_draw_in_order(self):
        sigil = _sheet("sigil_strokes")
        drawn = sigil[:, :, 3] > 0.5
        self.assertTrue(0.03 < drawn.mean() < 0.4, drawn.mean())
        order = sigil[:, :, 0][drawn]
        self.assertLess(order.min(), 0.1)
        self.assertGreater(order.max(), 0.9)


if __name__ == "__main__":
    unittest.main()
