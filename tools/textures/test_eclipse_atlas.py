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
# Scans prepared small and quick for the tests.
FAST_PREP = {"px_per_m": 64, "radius": 2, "iterations": 1}
RECIPES = {
    "tezontle": {"base": "#6e2f26", "light": "#9a4a3a", "dark": "#3d1f1c", "grime": 0.0, "wear": 0.0, "mottle": 2,
                 "strokes": 0, "relief": FLAT},
    "chiluca": {"base": "#8a8790", "light": "#b9b4b0", "dark": "#5a5560", "grime": 0.0, "wear": 0.0, "mottle": 2,
                "strokes": 0, "relief": FLAT},
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


class Under(unittest.TestCase):
    """The under atlas: what each slot wears through to (the vertex-paint
    plan, Task 5). Tezontle here wears through to chiluca; chiluca has
    nothing under it. Atlas's synthetic wall, not its tests."""

    setUp, tearDown, texels, ao = Atlas.setUp, Atlas.tearDown, Atlas.texels, Atlas.ao

    UNDER = {**RECIPES, "tezontle": {**RECIPES["tezontle"], "under": "chiluca"}}

    def images(self):
        eclipse_atlas.paint_atlas("piece", self.src, self.out, recipes=self.UNDER)
        load = lambda name: np.asarray(Image.open(self.out / name).convert("RGB"), dtype=np.float64)
        return (load("piece_base.png"), load("piece_under.png"), load("piece_normal_base.png"),
                load("piece_under_normal.png"))

    def test_under_atlases_written(self):
        self.images()
        self.assertTrue((self.out / "piece_under.png").exists())
        self.assertTrue((self.out / "piece_under_normal.png").exists())

    def test_slot_without_under_copies_top(self):
        top, under, top_n, under_n = self.images()
        right = slice(PX // 2 + 2, None)        # chiluca, clear of the seam
        np.testing.assert_array_equal(under[:, right], top[:, right])
        np.testing.assert_array_equal(under_n[:, right], top_n[:, right])

    def test_slot_with_under_differs(self):
        top, under, _, _ = self.images()
        left = slice(0, PX // 2 - 2)            # tezontle
        gap = np.linalg.norm(eclipse_atlas.to_oklab(top[:, left] / 255) - eclipse_atlas.to_oklab(under[:, left] / 255),
                             axis=-1)
        self.assertGreater(gap.mean(), 0.05)

    def test_under_recipe_by_name_and_inline(self):
        recipes = {"lime": {"base": "#eeeeee", "light": "#ffffff", "dark": "#cccccc", "under": "chiluca"},
                   "iron": {"base": "#204030", "light": "#305040", "dark": "#102010", "grime": 0.2,
                            "under": {"base": "#777777"}},
                   "brass": {"base": "#c49a40", "light": "#e8d8a8", "dark": "#7a5a24"},
                   "chiluca": RECIPES["chiluca"]}
        self.assertEqual(eclipse_atlas.under_recipe(recipes, "lime"), RECIPES["chiluca"])
        iron = eclipse_atlas.under_recipe(recipes, "iron")
        self.assertEqual(iron["base"], "#777777")
        self.assertEqual(iron["grime"], 0.2)
        self.assertNotIn("under", iron)
        self.assertIsNone(eclipse_atlas.under_recipe(recipes, "brass"))


class Painting(unittest.TestCase):
    """The painter's own manners, on the synthetic wall: a scan that ramps
    from dark to light up each metre, so every value is there to be banded."""

    def setUp(self):
        self.base = Atlas("test_deterministic")
        self.base.setUp()
        self.scans = Path(tempfile.mkdtemp())
        folder = self.scans / "ramp"
        folder.mkdir()
        ramp = np.repeat(np.linspace(30, 230, 64)[::-1, None], 64, axis=1)   # light at the top
        Image.fromarray(np.dstack([ramp] * 3).astype(np.uint8), "RGB").save(folder / "diffuse.jpg", quality=98)
        Image.new("RGB", (64, 64), (128, 128, 255)).save(folder / "normal.jpg", quality=98)
        (folder / "info.json").write_text(json.dumps({"name": "ramp", "dimensions_mm": [1000, 1000]}))
        self.recipes = {k: dict(v, scan={"name": "ramp", "detail": 0.0}) for k, v in RECIPES.items()}

    def tearDown(self):
        self.base.tearDown()
        shutil.rmtree(self.scans)

    def paint(self):
        path = eclipse_atlas.paint_atlas("piece", self.base.src, self.base.out, recipes=self.recipes,
                                         scans_dir=self.scans, prep=FAST_PREP)
        return np.asarray(Image.open(path).convert("RGB"), dtype=np.int64)

    def test_each_slot_keeps_a_few_colours(self):
        pixels = self.paint()
        left = {tuple(c) for c in pixels[:, : PX // 2 - 2].reshape(-1, 3)}
        self.assertLessEqual(len(left), eclipse_atlas.SLOT_COLOURS)

    def test_shadows_cool_lights_warm(self):
        pixels = self.paint()[:, 4:PX // 2 - 4].reshape(-1, 3).astype(np.float64)
        luma = pixels @ np.array([0.299, 0.587, 0.114])
        dark, light = pixels[luma <= np.percentile(luma, 15)], pixels[luma >= np.percentile(luma, 85)]
        # Blue's share of the colour: darkening alone leaves it as it is.
        cool = lambda c: (c[:, 2] / (c.sum(axis=1) + 1)).mean()
        self.assertGreater(cool(dark), cool(light) + 0.02)

    def test_few_lone_specks(self):
        """Marks of a texel on their own are under 2%: shapes, not grain."""
        pixels = self.paint()[2:-2, 2:PX // 2 - 2]
        same = lambda dy, dx: np.all(pixels == np.roll(pixels, (dy, dx), axis=(0, 1)), axis=-1)
        alone = ~(same(0, 1) | same(0, -1) | same(1, 0) | same(-1, 0))
        self.assertLess(alone[1:-1, 1:-1].mean(), 0.02)

    def test_strokes_are_colour_only(self):
        """Brush strokes paint colour and raise nothing: with no other relief
        the normal map stays flat under them (the user, Oct 9 2026: brush-stroke
        normals made it gritty)."""
        self.recipes = {k: dict(v, strokes=12, relief=FLAT) for k, v in self.recipes.items()}
        self.paint()
        normals = np.asarray(Image.open(self.base.out / "piece_normal_base.png").convert("RGB"), dtype=np.float64)
        self.assertLess(np.abs(normals[6:-6, 6:PX // 2 - 6, :2] - 128).mean(), 1.0)

    def test_strokes_follow_band_edges(self):
        """Strokes gather where the value bands meet: the colour there varies
        more than with no strokes."""
        plain = self.paint().astype(np.float64)
        self.recipes = {k: dict(v, strokes=12) for k, v in self.recipes.items()}
        stroked = self.paint().astype(np.float64)
        self.assertGreater(np.abs(stroked - plain)[:, 4:PX // 2 - 4].mean(), 2.0)

    def test_a_style_overrides_the_painting(self):
        """A calmer style (fewer bands) leaves fewer colours in a slot."""
        def colours(style):
            path = eclipse_atlas.paint_atlas("piece", self.base.src, self.base.out, recipes=self.recipes,
                                             scans_dir=self.scans, prep=FAST_PREP, style=style)
            pixels = np.asarray(Image.open(path).convert("RGB"))[4:-4, 4:PX // 2 - 4]
            return len({tuple(c) for c in pixels.reshape(-1, 3)})

        self.assertLess(colours({"BANDS": 2, "STROKES": 0}), colours({"BANDS": 6, "STROKES": 0}))
        self.assertEqual(eclipse_atlas.BANDS, 5)          # the default left as it was

    def test_wear_lightens_convex_edges(self):
        with np.load(self.base.src / "piece_texels.npz") as d:
            data = {k: d[k] for k in d.files}
        wear = np.zeros((PX, PX), np.float32)
        wear[:, 4:8] = 1.0                                  # a convex edge running up the wall
        data["wear"] = wear
        np.savez(self.base.src / "piece_texels.npz", **data)
        story = {k: dict(v, wear=1.0) for k, v in self.recipes.items()}
        self.recipes = story
        pixels = self.paint().astype(np.float64)
        self.assertGreater(pixels[:, 4:8].mean(), pixels[:, 12:24].mean() + 6)


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
                                         scans_dir=self.scans, prep=FAST_PREP)
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



class ZocaloTiles(unittest.TestCase):
    def test_ground_tiles_include_the_zocalo_tiles(self):
        """The plaza's flags and the streets' setts are painted with the
        ground's tiles, each from a recipe naming a scan fetch_scans knows."""
        import fetch_scans

        self.assertLessEqual({"ground_flags", "ground_setts"}, set(eclipse_atlas.GROUND_TILES))

        for tile in ("ground_flags", "ground_setts"):
            recipe = eclipse_atlas.load_recipes([tile])[tile]
            self.assertIn(recipe["scan"]["name"], fetch_scans.SCANS, tile)

    def test_flag_courses_wrap_with_their_stagger(self):
        """An even number of staggered courses and whole slabs fit a period,
        or the stagger breaks at the tile's wrap."""
        blocks = eclipse_atlas.load_recipes(["ground_flags"])["ground_flags"]["relief"]["blocks"]
        period = eclipse_atlas.GROUND_PERIODS["ground_flags"]
        courses, slabs = period / blocks["course"], period / blocks["length"]
        self.assertAlmostEqual(courses, round(courses))
        self.assertEqual(round(courses) % 2, 0)
        self.assertAlmostEqual(slabs, round(slabs))


class StreetLifeRecipes(unittest.TestCase):
    def test_street_life_recipes(self):
        """The street life kits' slots each have a recipe; any scan they
        name is one fetch_scans knows."""
        import fetch_scans

        names = ["wood", "canvas", "talavera", "obsidian", "marigold", "wax", "flesh", "glass"]
        recipes = eclipse_atlas.load_recipes(names)
        self.assertEqual(sorted(recipes), sorted(names))

        for name, recipe in recipes.items():
            for r in (recipe, recipe.get("under") if isinstance(recipe.get("under"), dict) else {}):
                if "scan" in r:
                    self.assertIn(r["scan"]["name"], fetch_scans.SCANS, name)


class Tile(unittest.TestCase):
    """A seamless ground tile painted from a recipe (paint_tile): a scan of
    soft blobs laid flat, painted as an atlas is, its wrap closed."""

    def setUp(self):
        self.scans = Path(tempfile.mkdtemp())
        self.out = Path(tempfile.mkdtemp())
        folder = self.scans / "blobs"
        folder.mkdir()
        rng = np.random.default_rng(5)
        small = Image.fromarray((rng.random((8, 8, 3)) * 255).astype(np.uint8), "RGB")
        big = np.asarray(small.resize((64, 64), Image.Resampling.BICUBIC))
        Image.fromarray(big, "RGB").save(folder / "diffuse.jpg", quality=98)
        Image.fromarray(np.full((64, 64, 3), (128, 128, 255), np.uint8), "RGB").save(folder / "normal.jpg", quality=98)
        (folder / "info.json").write_text(json.dumps({"name": "blobs", "dimensions_mm": [1000, 1000]}))
        self.recipes = {"ground": {**RECIPES["chiluca"], "mottle": 0, "strokes": 3, "scan": {"name": "blobs", "tint": 0.5}}}

    def tearDown(self):
        shutil.rmtree(self.scans)
        shutil.rmtree(self.out)

    def paint(self):
        eclipse_atlas.paint_tile("ground", 64, self.out, recipes=self.recipes, scans_dir=self.scans, prep=FAST_PREP)
        load = lambda name: np.asarray(Image.open(self.out / name).convert("RGB"), dtype=np.float64)
        return load("ground.png"), load("ground_normal.png")

    def test_paint_tile_sizes(self):
        colour, normal = self.paint()
        self.assertEqual(colour.shape, (64, 64, 3))
        self.assertEqual(normal.shape, (64, 64, 3))

    def test_paint_tile_is_seamless(self):
        colour, _ = self.paint()
        across_x = np.abs(colour[:, 0] - colour[:, -1]).mean()
        across_y = np.abs(colour[0, :] - colour[-1, :]).mean()
        self.assertLess(across_x, np.abs(np.diff(colour, axis=1)).mean() * 1.5)
        self.assertLess(across_y, np.abs(np.diff(colour, axis=0)).mean() * 1.5)

if __name__ == "__main__":
    unittest.main()
