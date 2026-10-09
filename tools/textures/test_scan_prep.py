"""A scan prepared for painting (scan_prep.py): pure Python, on a synthetic
scan.

    python3 tools/textures/test_scan_prep.py
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

import scan_prep  # noqa: E402

FAST = {"px_per_m": 40, "radius": 2, "iterations": 1}


class Prep(unittest.TestCase):
    def setUp(self):
        self.dir = Path(tempfile.mkdtemp())
        folder = self.dir / "lit"
        folder.mkdir()
        rng = np.random.default_rng(1)
        # Light that rises and falls across the tile and wraps, as a scan's does.
        x = (0.6 + 0.25 * np.sin(2 * np.pi * np.arange(128) / 128))[None, :, None]
        grain = 0.9 + 0.2 * rng.random((128, 128, 1))
        colour = np.clip(np.broadcast_to(x * grain, (128, 128, 3)) * 255, 0, 255).astype(np.uint8)
        Image.fromarray(colour, "RGB").save(folder / "diffuse.jpg", quality=98)
        Image.new("RGB", (128, 128), (128, 128, 255)).save(folder / "normal.jpg", quality=98)
        (folder / "info.json").write_text(json.dumps({"name": "lit", "dimensions_mm": [1000, 1000]}))

    def tearDown(self):
        shutil.rmtree(self.dir)

    def test_size_follows_the_scans_real_size(self):
        colour, normal, size = scan_prep.prepare("lit", self.dir, **FAST)
        self.assertEqual(colour.shape, (40, 40, 3))
        self.assertEqual(normal.shape, (40, 40, 3))
        self.assertEqual(tuple(size), (1.0, 1.0))

    def test_baked_light_is_taken_out(self):
        """The light's swing across the tile at most half what it was."""
        colour, _, _ = scan_prep.prepare("lit", self.dir, **FAST)
        wave = np.sin(2 * np.pi * (np.arange(40) + 0.5) / 40)
        swing = lambda c: abs(np.dot(c.mean(axis=(0, 2)) - c.mean(), wave)) / np.dot(wave, wave)
        lit = np.asarray(Image.open(self.dir / "lit" / "diffuse.jpg").convert("RGB").resize((40, 40)), dtype=np.float64) / 255
        self.assertLess(swing(colour), swing(lit) * 0.5)

    def test_normals_stay_unit_and_facing_out(self):
        _, normal, _ = scan_prep.prepare("lit", self.dir, **FAST)
        self.assertLess(np.abs(np.linalg.norm(normal, axis=-1) - 1).max(), 1e-3)
        self.assertGreater(normal[..., 2].min(), 0.9)

    def test_prepared_once(self):
        scan_prep.prepare("lit", self.dir, **FAST)
        cache = self.dir / "lit" / "prepared.npz"
        stamp = cache.stat().st_mtime_ns
        scan_prep.prepare("lit", self.dir, **FAST)
        self.assertEqual(cache.stat().st_mtime_ns, stamp)

    def test_new_settings_prepare_again(self):
        scan_prep.prepare("lit", self.dir, **FAST)
        colour, _, _ = scan_prep.prepare("lit", self.dir, px_per_m=20, radius=2, iterations=1)
        self.assertEqual(colour.shape, (20, 20, 3))


if __name__ == "__main__":
    unittest.main()
