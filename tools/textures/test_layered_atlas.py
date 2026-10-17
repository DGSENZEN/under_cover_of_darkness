"""The layered painter (layered_atlas.py): pure Python, on synthetic texels.
A 64 x 64 slot whose left half faces up and right half faces sideways,
U along +x and V up; wear, cavity and occlusion laid in known stripes.

    python3 tools/textures/test_layered_atlas.py
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

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import layered_atlas  # noqa: E402
from eclipse_atlas import to_oklab  # noqa: E402

PX = 64
COLOUR = "#7a5a3a"
BLACK = np.array([0x0b, 0x0a, 0x0c]) / 255.0


def _texels():
    """Left half up-facing (a floor), right half a wall facing -y; positions
    in metres, 1 texel = 2 cm; wear high on the top rows, cavity on the
    bottom rows."""
    ys, xs = np.mgrid[0:PX, 0:PX].astype(np.float32)
    normal = np.zeros((PX, PX, 3), np.float32)
    normal[:, : PX // 2] = (0, 0, 1)
    normal[:, PX // 2:] = (0, -1, 0)
    position = np.dstack([xs * 0.02, np.zeros_like(xs), (PX - ys) * 0.02]).astype(np.float32)
    tangent_u = np.broadcast_to(np.array([1, 0, 0], np.float32), (PX, PX, 3)).copy()
    tangent_v = np.zeros((PX, PX, 3), np.float32)
    tangent_v[:, : PX // 2] = (0, 1, 0)
    tangent_v[:, PX // 2:] = (0, 0, 1)
    wear = np.zeros((PX, PX), np.float32)
    wear[:8] = 1.0
    cavity = np.zeros((PX, PX), np.float32)
    cavity[-8:] = 1.0
    return {"slot": np.zeros((PX, PX), np.int16), "position": position, "normal": normal,
            "tangent_u": tangent_u, "tangent_v": tangent_v, "wear": wear, "cavity": cavity}


def _ao():
    ao = np.ones((PX, PX))
    ao[-8:] = 0.2
    return ao


def _recipe(**over):
    recipe = {"colour": COLOUR, "light": 0.0, "height_light": 0.0, "wear": 0.0, "wear_colour": "#d8c8a8",
              "grime": 0.0, "grime_colour": "#2a2220", "brush": "brush_02", "brush_scale_m": 0.5,
              "brush_amount": 0.0, "black": 0.0}
    recipe.update(over)
    return recipe


def _brushes():
    rng = np.random.default_rng(3)
    return {"brush_02": rng.random((128, 128)).astype(np.float32)}


def _paint(**over):
    mask = np.ones((PX, PX), bool)
    return layered_atlas.paint_slot(_texels(), mask, _ao(), _recipe(**over), _brushes())


def _l(rgb):
    return to_oklab(np.asarray(rgb, np.float64))[..., 0]


class Layers(unittest.TestCase):
    def test_flat_colour_alone(self):
        out = _paint()
        want = np.array([0x7a, 0x5a, 0x3a]) / 255.0
        self.assertLessEqual(np.abs(out - want).max(), 1 / 255)

    def test_top_light(self):
        out = _paint(light=0.8)
        up, side = _l(out[20:40, 5:25]).mean(), _l(out[20:40, 40:60]).mean()
        self.assertGreaterEqual(up - side, 0.1 * 0.8)

    def test_edge_wear(self):
        out = _paint(wear=1.0)
        self.assertGreater(_l(out[:8, 40:60]).mean(), _l(out[20:40, 40:60]).mean() + 0.02)

    def test_crevice_grime(self):
        out = _paint(grime=1.0)
        grime = np.array([0x2a, 0x22, 0x20]) / 255.0
        plain = np.array([0x7a, 0x5a, 0x3a]) / 255.0
        bottom = out[-8:, 40:60].reshape(-1, 3).mean(0)
        self.assertLess(np.abs(bottom - grime).sum(), np.abs(plain - grime).sum() * 0.5)

    def test_mignola_black(self):
        out = _paint(black=0.5, grime=1.0, light=0.8)
        self.assertTrue(np.allclose(out[-8:], BLACK, atol=1 / 255))
        self.assertGreater(_l(out[:-8]).min(), _l(BLACK) + 0.02)

    def test_brush_breakup_bounded(self):
        plain = _l(_paint())
        brushed = _l(_paint(brush_amount=0.2))
        self.assertLessEqual(np.abs(brushed - plain).max(), 0.2 + 1e-6)
        self.assertGreater(brushed.std(), 0.0)

    def test_outside_the_mask_untouched(self):
        mask = np.zeros((PX, PX), bool)
        mask[:, :10] = True
        out = layered_atlas.paint_slot(_texels(), mask, _ao(), _recipe(light=0.8), _brushes())
        self.assertTrue((out[:, 10:] == 0).all())


class Atlas(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        root = Path(self.tmp.name)
        self.source, self.out, self.recipes, self.brushes = root / "src", root / "out", root / "rec", root / "br"
        for d in (self.source, self.recipes, self.brushes):
            d.mkdir()
        texels = _texels()
        texels["slot"][:, PX // 2:] = 1
        np.savez(self.source / "piece_texels.npz", **texels)
        Image.fromarray((_ao() * 255).astype(np.uint8), "L").save(self.source / "piece_ao.png")
        (self.source / "piece_regions.json").write_text(json.dumps(
            {"slots": ["wood", "mystery"], "atlas_px": PX, "px_per_m": 50}))
        (self.recipes / "wood.json").write_text(json.dumps(_recipe(light=0.5)))
        grey = (np.random.default_rng(1).random((64, 64)) * 255).astype(np.uint8)
        Image.fromarray(np.dstack([grey, np.full_like(grey, 255)]), "LA").save(self.brushes / "brush_02.png")

    def tearDown(self):
        self.tmp.cleanup()

    def test_missing_recipe(self):
        result = subprocess.run([sys.executable, layered_atlas.__file__, "piece", "--source=%s" % self.source,
                                 "--recipes=%s" % self.recipes, "--out=%s" % self.out, "--brushes=%s" % self.brushes],
                                capture_output=True, text=True)
        self.assertEqual(result.returncode, 1)
        self.assertIn("no recipe for slot mystery", result.stderr)

    def test_writes_base(self):
        (self.recipes / "mystery.json").write_text(json.dumps(_recipe(colour="#304050")))
        path = layered_atlas.paint("piece", self.source, self.out, self.recipes, self.brushes)
        self.assertEqual(path, self.out / "piece_base.png")
        with Image.open(path) as image:
            self.assertEqual(image.size, (PX, PX))

    def test_atlas_free_slots_skipped(self):
        (self.source / "piece_regions.json").write_text(json.dumps(
            {"slots": ["wood", "neon"], "atlas_px": PX, "px_per_m": 50}))
        path = layered_atlas.paint("piece", self.source, self.out, self.recipes, self.brushes)
        self.assertTrue(path.exists())

    def test_missing_brush_sheet_names_the_fix(self):
        (self.brushes / "brush_02.png").unlink()
        (self.recipes / "mystery.json").write_text(json.dumps(_recipe()))
        with self.assertRaises(FileNotFoundError) as caught:
            layered_atlas.paint("piece", self.source, self.out, self.recipes, self.brushes)
        self.assertIn("brushes.py", str(caught.exception))


if __name__ == "__main__":
    unittest.main()
