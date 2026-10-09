"""The style lab's painted atlases and normal maps (eclipse_atlas.py): pure
Python, on a synthetic piece: a 4 x 4 m wall facing -y, its left half
tezontle and its right half chiluca, U along +x and V up.

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
WALL = 4.0
FLAT = {"pores": 0, "brush": 0.0, "bevel": 0.0}
RECIPES = {
    "tezontle": {"base": "#6e2f26", "light": "#9a4a3a", "dark": "#3d1f1c", "grime": 0.0, "wear": 0.0, "mottle": 2,
                 "relief": FLAT},
    "chiluca": {"base": "#8a8790", "light": "#b9b4b0", "dark": "#5a5560", "grime": 0.0, "wear": 0.0, "mottle": 2,
                "relief": FLAT},
}


def _hex(c):
    return np.array([int(c[i:i + 2], 16) for i in (1, 3, 5)], dtype=np.float64)


class Atlas(unittest.TestCase):
    def setUp(self):
        self.src = Path(tempfile.mkdtemp())
        self.out = Path(tempfile.mkdtemp())
        (self.src / "piece_regions.json").write_text(json.dumps(
            {"slots": ["tezontle", "chiluca"], "atlas_px": PX, "px_per_m": PX / WALL}))
        self.texels()
        self.ao(np.full((PX, PX), 255))

    def tearDown(self):
        shutil.rmtree(self.src)
        shutil.rmtree(self.out)

    def texels(self, z_of_row=None):
        """Rows top to bottom (V high to low), as an image is."""
        u = (np.arange(PX) + 0.5) / PX
        v = 1.0 - (np.arange(PX) + 0.5) / PX
        uu, vv = np.meshgrid(u, v)
        slot = np.where(uu < 0.5, 0, 1).astype(np.int16)
        z = vv * WALL if z_of_row is None else np.repeat(z_of_row[:, None], PX, axis=1)
        position = np.dstack([uu * WALL, np.zeros_like(uu), z]).astype(np.float32)
        normal = np.broadcast_to(np.array([0, -1, 0], np.float32), (PX, PX, 3))
        tangent_u = np.broadcast_to(np.array([1, 0, 0], np.float32), (PX, PX, 3))
        tangent_v = np.broadcast_to(np.array([0, 0, 1], np.float32), (PX, PX, 3))
        np.savez(self.src / "piece_texels.npz", slot=slot, position=position, normal=normal,
                 tangent_u=tangent_u, tangent_v=tangent_v)

    def ao(self, values):
        Image.fromarray(values.astype(np.uint8), "L").save(self.src / "piece_ao.png")

    def paint(self, recipes=RECIPES):
        path = eclipse_atlas.paint_atlas("piece", self.src, self.out, recipes=recipes)
        return np.asarray(Image.open(path).convert("RGB"), dtype=np.float64)

    def normals(self):
        return np.asarray(Image.open(self.out / "piece_normal_base.png").convert("RGB"), dtype=np.float64)

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
        z = np.where(np.arange(PX) >= PX // 2, 0.1, 5.0)    # the lower half of the map at the street
        self.texels(z)
        grimy = {k: dict(v, grime=1.0) for k, v in RECIPES.items()}
        pixels = self.paint(grimy)
        self.assertLess(pixels[PX // 2 + 4:, 4:PX // 2 - 4].mean(), pixels[4:PX // 2 - 4, 4:PX // 2 - 4].mean() - 8)

    def test_never_writes_the_users_files(self):
        mine, my_normals = self.out / "piece.png", self.out / "piece_normal.png"
        Image.new("RGB", (PX, PX), (1, 2, 3)).save(mine)
        Image.new("RGB", (PX, PX), (4, 5, 6)).save(my_normals)
        before = mine.read_bytes(), my_normals.read_bytes()
        path = eclipse_atlas.paint_atlas("piece", self.src, self.out, recipes=RECIPES)
        self.assertEqual(path.name, "piece_base.png")
        self.assertTrue((self.out / "piece_normal_base.png").exists())
        self.assertEqual((mine.read_bytes(), my_normals.read_bytes()), before)

    def test_deterministic(self):
        a = eclipse_atlas.paint_atlas("piece", self.src, self.out, recipes=RECIPES).read_bytes()
        n = (self.out / "piece_normal_base.png").read_bytes()
        b = eclipse_atlas.paint_atlas("piece", self.src, self.out, recipes=RECIPES).read_bytes()
        self.assertEqual((a, n), (b, (self.out / "piece_normal_base.png").read_bytes()))

    def test_no_relief_is_a_flat_normal_map(self):
        self.paint()
        normals = self.normals()[4:-4, 4:-4]
        self.assertLess(np.abs(normals - np.array([128, 128, 255])).max(), 3)

    def test_courses_follow_world_height(self):
        """Mortar joints lie where world height crosses a course, whichever
        way the island lies: with V running down the wall, they still do."""
        coursed = dict(RECIPES)
        coursed["tezontle"] = dict(RECIPES["tezontle"], relief=dict(FLAT, blocks={"course": 0.5, "length": 0.8,
                                                                                 "joint": 0.06}))
        z = (np.arange(PX) + 0.5) / PX * WALL                # V runs DOWN the wall here
        self.texels(z)
        self.paint(coursed)
        normals = self.normals()
        # The joints' edges tilt the normal up and down the wall (green), the
        # field between them faces out: rows near course lines differ most.
        tilt = np.abs(normals[:, 4:PX // 2 - 4, 1] - 128).mean(axis=1)
        at_course = [r for r in range(PX) if abs(((r + 0.5) / PX * WALL) % 0.5) < 0.07 or
                     abs(((r + 0.5) / PX * WALL) % 0.5 - 0.5) < 0.07]
        between = [r for r in range(PX) if abs(((r + 0.5) / PX * WALL) % 0.5 - 0.25) < 0.07]
        self.assertGreater(np.mean(tilt[at_course]), np.mean(tilt[between]) + 10)
        # The chiluca half, with no relief, stays flat.
        self.assertLess(np.abs(normals[4:-4, PX // 2 + 4:-4] - np.array([128, 128, 255])).max(), 3)


class Scans(unittest.TestCase):
    """A scan projected by world position: the same wall as above, the scan a
    1 m square of horizontal stripes (bright rows on dark), its normals tilted
    toward the scan's up."""

    def setUp(self):
        self.base = Atlas("test_deterministic")
        self.base.setUp()
        self.scans = Path(tempfile.mkdtemp())
        folder = self.scans / "stripes"
        folder.mkdir()
        rows = np.zeros((64, 64, 3), dtype=np.uint8)
        rows[:32] = 220                                   # the top half of the scan bright
        rows[32:] = 40
        Image.fromarray(rows, "RGB").save(folder / "diffuse.jpg", quality=98)
        up = np.zeros((64, 64, 3), dtype=np.uint8)
        up[...] = (128, 200, 230)                         # tilted toward the scan's +y (up)
        Image.fromarray(up, "RGB").save(folder / "normal.jpg", quality=98)
        (folder / "info.json").write_text(json.dumps({"name": "stripes", "dimensions_mm": [1000, 1000]}))
        self.recipes = {k: dict(v, scan={"name": "stripes", "tint": 0.0}) for k, v in RECIPES.items()}

    def tearDown(self):
        self.base.tearDown()
        shutil.rmtree(self.scans)

    def paint(self):
        path = eclipse_atlas.paint_atlas("piece", self.base.src, self.base.out, recipes=self.recipes,
                                         scans_dir=self.scans)
        return np.asarray(Image.open(path).convert("RGB"), dtype=np.float64)

    def test_scan_lies_along_world_height(self):
        """The scan's bright half is the upper half of each metre of the
        wall, whichever way V runs: here V runs down it."""
        z = (np.arange(PX) + 0.5) / PX * WALL
        self.base.texels(z)
        pixels = self.paint()[:, 4:PX // 2 - 4].mean(axis=(1, 2))
        frac = z % 1.0
        upper = pixels[(frac > 0.6) & (frac < 0.9)].mean()
        lower = pixels[(frac > 0.1) & (frac < 0.4)].mean()
        self.assertGreater(upper, lower + 40)

    def test_scan_normals_turn_into_the_islands_frame(self):
        """The scan's normals lean toward world up; with +V running down the
        wall, the atlas's normals lean toward -V (green below 128)."""
        z = (np.arange(PX) + 0.5) / PX * WALL
        self.base.texels(z)
        tangent_v = np.broadcast_to(np.array([0, 0, -1], np.float32), (PX, PX, 3))
        with np.load(self.base.src / "piece_texels.npz") as d:
            data = {k: d[k] for k in d.files}
        data["tangent_v"] = tangent_v
        np.savez(self.base.src / "piece_texels.npz", **data)
        self.paint()
        normals = np.asarray(Image.open(self.base.out / "piece_normal_base.png").convert("RGB"), dtype=np.float64)
        self.assertLess(normals[8:-8, 8:PX // 2 - 8, 1].mean(), 110)

    def test_tint_pulls_toward_the_slot(self):
        tinted = {k: dict(v, scan={"name": "stripes", "tint": 1.0}) for k, v in RECIPES.items()}
        self.recipes = tinted
        pixels = self.paint()
        left = pixels[:, 4:PX // 2 - 4].reshape(-1, 3).mean(axis=0)
        self.assertGreater(left[0], left[2] + 20)          # tezontle's red, though the scan is grey


if __name__ == "__main__":
    unittest.main()
