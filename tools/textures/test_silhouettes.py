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
POSES = ["bargaining", "waiting", "kneeling_a", "kneeling_b", "walking_a", "walking_b", "walking_c",
         "keeper_counter", "keeper_stir", "keeper_fan", "keeper_weigh", "keeper_wrap",
         "pelona", "clerk", "lineman", "gendarme",
         "newsboy", "water_carrier", "porter", "organ_grinder", "sereno"]
CELL = (256, 512)
# The commit the lane's seven people were approved in.
APPROVED = "2ca81339"
# The lane's people in hats, their hats re-seated since.
RESEATED = {"waiting", "walking_a", "walking_c"}


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
            low, high = (1.0, 1.3) if name.startswith("kneeling") else (1.2, 1.5) if self.poses[name].get("child") \
                else (1.5, 1.95)
            self.assertTrue(low <= height <= high, "%s %.2f m" % (name, height))
            # (The json's height is the drawing's.)
            rows = np.nonzero(self._cell(name)[..., 3].max(axis=1) > 128)[0]
            drawn = (CELL[1] - rows.min()) / CELL[1] * cell_m
            self.assertLess(abs(drawn - height), 0.03, "%s drawn %.2f, says %.2f" % (name, drawn, height))

    def test_the_lanes_people_are_as_approved(self):
        # (The Pasaje's keepers added after them, the lane's seven cells drawn as committed with the lane: Oct 24 2026.)
        approved = subprocess.run(["git", "-C", str(ROOT), "show", APPROVED + ":textures/painted/underground/silhouettes.png"],
                                  check=True, capture_output=True).stdout
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "approved.png"
            path.write_bytes(approved)
            was = np.asarray(Image.open(path).convert("RGBA"))
        meta = json.loads(subprocess.run(["git", "-C", str(ROOT), "show", APPROVED +
                                          ":textures/painted/underground/silhouettes.json"], check=True,
                                         capture_output=True).stdout)
        for pose in meta["poses"]:
            col, row = pose["cell"]
            then = was[row * CELL[1]:(row + 1) * CELL[1], col * CELL[0]:(col + 1) * CELL[0]]
            now = self._cell(pose["name"])
            if pose["name"] in RESEATED:
                # (Their hats seated on their heads since (Oct 26 2026, the user: "the hats aren't in their heads
                # correctly"): below their shoulders as approved.)
                below = CELL[1] - int(self.poses[pose["name"]]["shoulders"][1] / meta["cell_m"] * CELL[1]) + 6
                then, now = then[below:], now[below:]
                # (A new hat's width moves the figure's middle in its cell: matched as drawn, a few pixels over.)
                shift = min(range(-12, 13), key=lambda k: np.abs(np.roll(now[..., 3].astype(int), k, axis=1)
                                                                   - then[..., 3].astype(int)).sum())
                now = np.roll(now, shift, axis=1)
                # (And a fraction of a pixel, which moves only its edges' blend: under 1% of it more than half off.)
                body = then[..., 3] > 128
                off = np.abs(now[..., 3].astype(int) - then[..., 3].astype(int)) > 128
                self.assertLess(off.sum() / max(body.sum(), 1), 0.01, pose["name"])
                continue
            self.assertEqual(int(np.abs(then[..., 3].astype(int) - now[..., 3].astype(int)).max()), 0, pose["name"])

    def test_each_says_which_way_it_faces(self):
        for name in POSES:
            self.assertIn(self.poses[name]["facing"], ("left", "right"), name)


class HatsOnHeads(unittest.TestCase):
    def test_every_hat_sits_on_its_wearers_head(self):
        # (However the head is bowed or turned: the hat leans with it (tipped forward a little, no more), sits on its
        # middle, and the top of the skull is inside its crown.)
        run = subprocess.run([BLENDER, "-b", "--factory-startup", "--python-exit-code", "1", "--python",
                              str(HERE / "silhouettes.py"), "--", "--check-hats"], check=True, capture_output=True,
                             text=True)
        line = next(l for l in run.stdout.splitlines() if l.startswith("HATS "))
        hats = json.loads(line[len("HATS "):])
        self.assertTrue(hats, "no hatted poses")
        for name, seat in hats.items():
            self.assertTrue(seat["skull_in_crown"] and seat["tilt_deg"] <= 10.0 and seat["off_m"] <= 0.015,
                            "%s: %s" % (name, seat))


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
