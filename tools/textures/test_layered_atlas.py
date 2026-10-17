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

    def test_print_in_columns(self):
        # On the wall half (a along x, b up): lines of print across each column, a clear gutter between.
        out = _l(_paint(print=1.0, print_colour="#222222", print_line_m=0.08, print_column_m=0.4))
        plain = _l(_paint())
        wall = out[8:-8, PX // 2:]
        self.assertLess(wall.min(), plain.max() - 0.2)
        x = np.arange(PX // 2, PX) * 0.02
        gutter = ((x / 0.4) % 1.0) >= 0.9
        self.assertTrue(np.allclose(wall[:, gutter], plain[8:-8, PX // 2:][:, gutter], atol=1e-3))
        rows = wall[:, ~gutter].mean(1)
        self.assertGreater(rows.max() - rows.min(), 0.1)

    def test_weave_bounded_and_periodic(self):
        plain = _l(_paint())
        woven = _l(_paint(weave=0.1, weave_m=0.16))
        self.assertLessEqual(np.abs(woven - plain).max(), 0.1 + 1e-6)
        wall = woven[PX - 42, PX // 2:]          # b = 0.84 m, a crest of the weave across
        self.assertAlmostEqual(wall[0], wall[8], places=3)
        self.assertGreater(np.abs(wall - wall.mean()).max(), 0.02)

    def test_strokes_lay_the_sheet_in_a_second_colour(self):
        # The user's sheet laid as brush marks: where it is high, the stroke's own colour; where low,
        # the base; a mark, not a ripple.
        sheet = np.zeros((128, 128), np.float32)
        sheet[:, 64:] = 1.0
        mask = np.ones((PX, PX), bool)
        recipe = _recipe(stroke_colour="#203040", stroke_amount=1.0, stroke_brush="brush_02", stroke_scale_m=1.0)
        out = layered_atlas.paint_slot(_texels(), mask, _ao(), recipe, {"brush_02": sheet})
        base = np.array([0x7a, 0x5a, 0x3a]) / 255.0
        stroke = np.array([0x20, 0x30, 0x40]) / 255.0
        wall = out[8:-8, PX // 2:].reshape(-1, 3)
        near_stroke = np.abs(wall - stroke).max(axis=1) < 2 / 255
        near_base = np.abs(wall - base).max(axis=1) < 2 / 255
        self.assertGreater(near_stroke.mean(), 0.2)
        self.assertGreater(near_base.mean(), 0.2)

    def test_a_dim_sheet_still_lays_its_marks(self):
        # The user's sheets are mostly see-through (their values premultiplied by alpha run 0.04-0.22):
        # their marks are read by rank within the sheet, so a dim sheet lays as many as a bright one.
        rng = np.random.default_rng(9)
        dim = (0.04 + 0.18 * rng.random((128, 128))).astype(np.float32)
        mask = np.ones((PX, PX), bool)
        recipe = _recipe(stroke_colour="#203040", stroke_amount=1.0, stroke_brush="brush_02", stroke_scale_m=0.5)
        out = layered_atlas.paint_slot(_texels(), mask, _ao(), recipe, {"brush_02": dim})
        stroke = np.array([0x20, 0x30, 0x40]) / 255.0
        base = np.array([0x7a, 0x5a, 0x3a]) / 255.0
        # Marked: moved at least a quarter of the way from the paint toward the stroke's colour.
        moved = np.abs(out[8:-8].reshape(-1, 3) - base).max(axis=1) / np.abs(stroke - base).max()
        marked = (moved > 0.25).mean()
        self.assertGreater(marked, 0.25)
        self.assertLess(marked, 0.65)
        plain = _l(_paint())
        broken = _l(layered_atlas.paint_slot(_texels(), mask, _ao(), _recipe(brush_amount=0.2), {"brush_02": dim}))
        self.assertGreater((broken - plain).max(), 0.1)
        self.assertLess((broken - plain).min(), -0.1)

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
