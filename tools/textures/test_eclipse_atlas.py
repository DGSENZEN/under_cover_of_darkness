"""The style lab's painted atlases (eclipse_atlas.py): pure Python, on a
synthetic piece's maps.

    python3 tools/textures/test_eclipse_atlas.py
"""

import json
import os
import shutil
import sys
import tempfile
import unittest
from pathlib import Path

import numpy as np
from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import eclipse_atlas  # noqa: E402

PX = 64
RECIPES = {
    "tezontle": {"base": "#6e2f26", "light": "#9a4a3a", "dark": "#3d1f1c", "grime": 0.0, "wear": 0.0, "mottle": 2},
    "chiluca": {"base": "#8a8790", "light": "#b9b4b0", "dark": "#5a5560", "grime": 0.0, "wear": 0.0, "mottle": 2},
}


def _hex(c):
    return np.array([int(c[i:i + 2], 16) for i in (1, 3, 5)], dtype=np.float64)


class Atlas(unittest.TestCase):
    def setUp(self):
        self.src = Path(tempfile.mkdtemp())
        self.out = Path(tempfile.mkdtemp())
        regions = np.zeros((PX, PX, 4), dtype=np.uint8)
        regions[:, :, 3] = 255
        regions[:, PX // 2:, 0] = 16                      # left: slot 0, right: slot 1
        Image.fromarray(regions, "RGBA").save(self.src / "piece_regions.png")
        (self.src / "piece_regions.json").write_text(json.dumps(
            {"slots": ["tezontle", "chiluca"], "atlas_px": PX, "height_range": [-4.0, 12.0]}))
        self.ao(np.full((PX, PX), 255))
        self.height(np.full((PX, PX), 5.0))

    def tearDown(self):
        shutil.rmtree(self.src)
        shutil.rmtree(self.out)

    def ao(self, values):
        Image.fromarray(values.astype(np.uint8), "L").save(self.src / "piece_ao.png")

    def height(self, metres):
        Image.fromarray(((metres + 4.0) / 16.0 * 255).round().astype(np.uint8), "L").save(self.src / "piece_height.png")

    def paint(self, recipes=RECIPES):
        path = eclipse_atlas.paint_atlas("piece", self.src, self.out, recipes=recipes)
        return np.asarray(Image.open(path).convert("RGB"), dtype=np.float64)

    def test_regions_take_their_slot_colours(self):
        pixels = self.paint()
        left = np.median(pixels[:, 4:PX // 2 - 4].reshape(-1, 3), axis=0)
        right = np.median(pixels[:, PX // 2 + 4:-4].reshape(-1, 3), axis=0)
        self.assertLess(np.abs(left - _hex(RECIPES["tezontle"]["base"])).max(), 24)
        self.assertLess(np.abs(right - _hex(RECIPES["chiluca"]["base"])).max(), 24)

    def test_ao_darkens(self):
        ao = np.full((PX, PX), 255)
        ao[: PX // 2] = 77
        self.ao(ao)
        pixels = self.paint()
        self.assertLess(pixels[: PX // 2 - 4, 4:PX // 2 - 4].mean(), pixels[PX // 2 + 4:, 4:PX // 2 - 4].mean())

    def test_grime_rises_from_the_ground(self):
        metres = np.full((PX, PX), 5.0)
        metres[PX // 2:] = 0.1                             # the lower half of the map at the street
        self.height(metres)
        grimy = {k: dict(v, grime=1.0) for k, v in RECIPES.items()}
        pixels = self.paint(grimy)
        self.assertLess(pixels[PX // 2 + 4:, 4:PX // 2 - 4].mean(), pixels[4:PX // 2 - 4, 4:PX // 2 - 4].mean() - 8)

    def test_never_writes_the_users_file(self):
        mine = self.out / "piece.png"
        Image.new("RGB", (PX, PX), (1, 2, 3)).save(mine)
        before = mine.read_bytes()
        path = eclipse_atlas.paint_atlas("piece", self.src, self.out, recipes=RECIPES)
        self.assertEqual(path.name, "piece_base.png")
        self.assertEqual(mine.read_bytes(), before)

    def test_deterministic(self):
        a = eclipse_atlas.paint_atlas("piece", self.src, self.out, recipes=RECIPES).read_bytes()
        b = eclipse_atlas.paint_atlas("piece", self.src, self.out, recipes=RECIPES).read_bytes()
        self.assertEqual(a, b)


if __name__ == "__main__":
    unittest.main()
