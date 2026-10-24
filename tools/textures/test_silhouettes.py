"""The candle lane's people (silhouettes.py): each pose on the sheet one black shape on clear, standing on its cell's
foot, a person's height; and the librarian's shadow unchanged now its dressing is shared (dressing.py). Pure Python
over the written images, but for the shadow, which renders again in Blender (BLENDER, or the app's).

    python3 tools/textures/test_silhouettes.py
"""

import json
import os
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

import numpy as np
from PIL import Image

HERE = Path(os.path.dirname(os.path.abspath(__file__)))
ROOT = HERE.parent.parent
SHEET = ROOT / "textures" / "painted" / "underground" / "silhouettes.png"
SHADOW = ROOT / "textures" / "painted" / "underground" / "librarian_shadow.png"
BLENDER = os.environ.get("BLENDER", "/Applications/Blender.app/Contents/MacOS/Blender")
POSES = ["bargaining", "waiting", "kneeling_a", "kneeling_b", "walking_a", "walking_b", "walking_c"]
CELL = (256, 512)


class Silhouettes(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.sheet = np.asarray(Image.open(SHEET).convert("RGBA"))
        cls.meta = json.loads(SHEET.with_suffix(".json").read_text())
        cls.poses = {p["name"]: p for p in cls.meta["poses"]}

    def _cell(self, name):
        col, row = self.poses[name]["cell"]
        return self.sheet[row * CELL[1]:(row + 1) * CELL[1], col * CELL[0]:(col + 1) * CELL[0]]

    def test_every_pose_has_its_own_cell(self):
        self.assertEqual(sorted(self.poses), sorted(POSES))
        cells = [tuple(p["cell"]) for p in self.meta["poses"]]
        self.assertEqual(len(set(cells)), len(cells))
        for col, row in cells:
            self.assertLessEqual((col + 1) * CELL[0], self.sheet.shape[1])
            self.assertLessEqual((row + 1) * CELL[1], self.sheet.shape[0])

    def test_each_is_one_black_shape_on_clear_standing_on_the_floor(self):
        for name in POSES:
            cell = self._cell(name)
            alpha = cell[..., 3]
            self.assertGreater(int((alpha > 200).sum()), 4000, name)
            self.assertLessEqual(int(cell[..., :3][alpha > 0].max()), 8, name)
            # (Nothing cut off by the cell's sides or top; its feet (or knees) on its foot.)
            self.assertEqual(int(alpha[:, :2].max()) + int(alpha[:, -2:].max()) + int(alpha[:2].max()), 0, name)
            self.assertGreater(int(alpha[-3:].max()), 200, name)

    def test_each_is_a_persons_height(self):
        cell_m = self.meta["cell_m"]
        for name in POSES:
            height = self.poses[name]["height_m"]
            low, high = (1.0, 1.3) if name.startswith("kneeling") else (1.5, 1.95)
            self.assertTrue(low <= height <= high, "%s %.2f m" % (name, height))
            # (The json's height is the drawing's.)
            rows = np.nonzero(self._cell(name)[..., 3].max(axis=1) > 128)[0]
            drawn = (CELL[1] - rows.min()) / CELL[1] * cell_m
            self.assertLess(abs(drawn - height), 0.03, "%s drawn %.2f, says %.2f" % (name, drawn, height))

    def test_each_says_which_way_it_faces(self):
        for name in POSES:
            self.assertIn(self.poses[name]["facing"], ("left", "right"), name)


class LibrarianUnchanged(unittest.TestCase):
    def test_the_librarians_shadow_renders_as_approved(self):
        with tempfile.TemporaryDirectory() as tmp:
            out = Path(tmp) / "shadow.png"
            subprocess.run([BLENDER, "-b", "--factory-startup", "--python-exit-code", "1", "--python",
                            str(HERE / "librarian_shadow.py"), "--", "--out=" + str(out)], check=True,
                           stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            again = np.asarray(Image.open(out).convert("RGBA"))
        approved = np.asarray(Image.open(SHADOW).convert("RGBA"))
        self.assertEqual(again.shape, approved.shape)
        self.assertEqual(int(np.abs(again.astype(int) - approved.astype(int)).max()), 0)


if __name__ == "__main__":
    unittest.main()
