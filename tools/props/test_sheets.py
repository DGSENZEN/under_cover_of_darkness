"""Checks on the committed effect sheets (tools/props/flames.py renders them):
sizes, the 16 heat levels, flames that loop and move and keep their base on
the fuel, hard-edged smoke and soot, and the colour ramps.

    python3 -m unittest tools/props/test_sheets.py -v
"""

import sys
import tempfile
import unittest
from pathlib import Path

import numpy as np
from PIL import Image

VFX = Path(__file__).resolve().parents[2] / "assets" / "vfx"

# name: (frame width, frame height, frames)
SHEETS = {
    "candle": (8, 16, 5),
    "small": (16, 24, 6),
    "torch": (32, 64, 8),
    "brazier": (64, 64, 10),
    "fire": (64, 96, 12),
}
RAMPS = ["candle", "lamp", "torch", "brazier", "fire", "dying", "gutter"]


def frames_of(name):
    width, height, count = SHEETS[name]
    sheet = np.asarray(Image.open(VFX / ("flame_%s.png" % name)).convert("L"), dtype=np.float64)
    return [sheet[:, i * width:(i + 1) * width] for i in range(count)]


class SheetsTest(unittest.TestCase):
    def test_dimensions(self):
        for name, (width, height, count) in SHEETS.items():
            with Image.open(VFX / ("flame_%s.png" % name)) as sheet:
                self.assertEqual(sheet.size, (width * count, height), name)

        for name, size in {"smoke": (128, 32), "corona": (64, 64), "soot": (128, 128)}.items():
            with Image.open(VFX / (name + ".png")) as image:
                self.assertEqual(image.size, size, name)

    def test_the_corona_is_a_glow_not_a_disc(self):
        # A hot heart and a faint haze round it: by half its radius it is
        # down to a fifth of its heart, so it never reads as a lit ball.
        halo = np.asarray(Image.open(VFX / "corona.png").convert("L"), dtype=np.float64)
        middle = halo.shape[0] // 2
        heart = halo[middle, middle]
        self.assertGreater(heart, 200.0)
        self.assertLess(halo[middle, middle + halo.shape[0] // 4], heart * 0.2)
        self.assertGreater(halo[middle, middle + halo.shape[0] // 4], 0.0)

    def test_levels(self):
        for name in SHEETS:
            sheet = np.asarray(Image.open(VFX / ("flame_%s.png" % name)).convert("L"))
            self.assertLessEqual(len(np.unique(sheet)), 16, name)

    def test_loop_seam(self):
        for name in SHEETS:
            frames = frames_of(name)
            steps = [np.abs(frames[i + 1] - frames[i]).mean() for i in range(len(frames) - 1)]
            seam = np.abs(frames[0] - frames[-1]).mean()
            self.assertLessEqual(seam, 1.5 * float(np.mean(steps)), "%s seam %.2f, steps %.2f" % (name, seam, np.mean(steps)))

    def test_not_static(self):
        for name in SHEETS:
            frames = frames_of(name)
            steps = [np.abs(frames[i + 1] - frames[i]).mean() for i in range(len(frames) - 1)]
            self.assertGreater(float(np.mean(steps)), 2.0, name)

    def test_pinned_base(self):
        for name in SHEETS:
            width, height, _count = SHEETS[name]
            rows = max(int(round(height * 0.15)), 1)
            left, right = int(width * 0.2), int(round(width * 0.8))

            for index, frame in enumerate(frames_of(name)):
                self.assertTrue((frame[height - rows:, left:right] > 0).any(), "%s frame %d floats off its fuel" % (name, index))

    def test_smoke_and_soot(self):
        smoke = np.asarray(Image.open(VFX / "smoke.png").convert("RGBA"))
        self.assertTrue(set(np.unique(smoke[:, :, 3])) <= {0, 128, 255})
        soot = np.asarray(Image.open(VFX / "soot.png").convert("RGBA"))
        self.assertLessEqual(len(np.unique(soot[:, :, 3])), 8)
        self.assertTrue((soot[:, :, :3] == 0).all())

    def test_ramps(self):
        for name in RAMPS:
            ramp = np.asarray(Image.open(VFX / "ramps" / (name + ".png")).convert("RGBA"), dtype=np.float64)
            self.assertEqual(ramp.shape[:2], (1, 64), name)
            self.assertEqual(ramp[0, 0, 3], 0, name)
            brightness = ramp[0, :, :3].sum(axis=1)
            self.assertEqual(int(np.argmax(brightness)), 63, name)


class Backups(unittest.TestCase):
    """Every write backs up what it writes over (spec 12), sheets too."""

    def test_a_sheet_written_over_is_backed_up_first(self):
        sys.path.insert(0, str(Path(__file__).resolve().parent))
        import flames

        with tempfile.TemporaryDirectory() as folder:
            out = Path(folder) / "sheet.png"
            backups = Path(folder) / "backup"
            flames.write_png(out, np.zeros((2, 2), np.uint8), backup_dir=backups)
            self.assertFalse(backups.exists() and any(backups.iterdir()), "nothing was there to back up")
            flames.write_png(out, np.full((2, 2), 255, np.uint8), backup_dir=backups)
            saved = list(backups.iterdir())
            self.assertEqual(len(saved), 1)
            self.assertEqual(int(np.asarray(Image.open(saved[0])).max()), 0, "the backup is the sheet as it was")


if __name__ == "__main__":
    unittest.main()
