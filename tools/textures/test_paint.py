"""The painted textures' own tests (tools/textures/paint.py): the foliage we
paint ourselves, cut out and in many greens, and the bark that tiles.

    python3 -m unittest tools/textures/test_paint.py -v
"""

import os
import sys
import unittest

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import paint  # noqa: E402

FOLIAGE = ["leaf_crown", "leaf_shrub", "yew", "twigs", "grass", "weed_broad", "reeds", "ivy",
           "palm_frond", "cypress", "agave", "orange_leaves", "gorse", "fennel", "pine"]
IRONWORK = ["iron_rail", "window_grille", "ratlines"]


class Harbour(unittest.TestCase):
    def test_ironwork_and_rigging_are_dark_lines_cut_clean(self):
        for name in IRONWORK:
            with self.subTest(name):
                image = paint.PAINTINGS[name]()
                w, h = image.size
                self.assertEqual((w & (w - 1), h & (h - 1)), (0, 0))
                pixels = np.asarray(image)
                alpha = pixels[:, :, 3]
                self.assertTrue(set(np.unique(alpha)) <= {0, 255}, "alpha not cut clean")
                solid = float((alpha == 255).mean())
                self.assertGreater(solid, 0.08, "hardly anything painted")
                self.assertLess(solid, 0.7, "a plate, not bars and lines")
                self.assertLess(pixels[alpha == 255][:, :3].mean(), 110.0, "not dark iron or tarred rope")

    def test_a_casement_is_pale_bars_round_clear_panes_on_a_panelled_foot(self):
        image = paint.PAINTINGS["casement"]()
        w, h = image.size
        self.assertEqual((w & (w - 1), h & (h - 1)), (0, 0))
        pixels = np.asarray(image)
        alpha = pixels[:, :, 3]
        self.assertTrue(set(np.unique(alpha)) <= {0, 255}, "alpha not cut clean")
        self.assertGreater(pixels[alpha == 255][:, :3].mean(), 150.0, "sashes are painted pale")
        # Panes through most of it; the foot solid (its panels).
        self.assertGreater(float((alpha[: int(h * 0.7)] == 0).mean()), 0.45, "no panes to see through")
        self.assertGreater(float((alpha[int(h * 0.82):] == 255).mean()), 0.9, "no panelled foot")
        # Two leaves: a meeting stile down the middle.
        self.assertGreater(float((alpha[: int(h * 0.7), w // 2 - 1: w // 2 + 1] == 255).mean()), 0.95)

    def test_a_sash_window_is_two_sashes_of_clear_panes(self):
        image = paint.PAINTINGS["sash"]()
        w, h = image.size
        self.assertEqual((w & (w - 1), h & (h - 1)), (0, 0))
        pixels = np.asarray(image)
        alpha = pixels[:, :, 3]
        self.assertTrue(set(np.unique(alpha)) <= {0, 255}, "alpha not cut clean")
        self.assertGreater(pixels[alpha == 255][:, :3].mean(), 150.0, "sashes are painted pale")
        self.assertGreater(float((alpha == 0).mean()), 0.5, "no panes to see through")
        # The meeting rail across its middle; no panelled foot.
        self.assertTrue(any((alpha[y] == 255).all() for y in range(int(h * 0.45), int(h * 0.56))), "no meeting rail")
        self.assertLess(float((alpha[int(h * 0.82): int(h * 0.95)] == 255).mean()), 0.6, "a door's foot, not a window")

    def test_a_lattice_is_painted_laths_crossing_with_gaps_between(self):
        image = paint.PAINTINGS["lattice"]()
        w, h = image.size
        self.assertEqual((w & (w - 1), h & (h - 1)), (0, 0))
        pixels = np.asarray(image)
        alpha = pixels[:, :, 3]
        self.assertTrue(set(np.unique(alpha)) <= {0, 255}, "alpha not cut clean")
        solid = float((alpha == 255).mean())
        self.assertGreater(solid, 0.35, "hardly any laths")
        self.assertLess(solid, 0.8, "no gaps: a board, not a lattice")
        # Diagonal: no row and no column is all gap or all lath inside the frame.
        inner = alpha[h // 8: -h // 8, w // 8: -w // 8] == 255
        self.assertFalse(inner.all(axis=1).any() or (~inner).all(axis=1).any(), "rows, not a lattice")
        self.assertFalse(inner.all(axis=0).any() or (~inner).all(axis=0).any(), "columns, not a lattice")

    def test_the_coil_mask_is_a_round_white_on_black(self):
        mask = np.asarray(paint.PAINTINGS["coil_mask"]().convert("L"))
        h, w = mask.shape
        self.assertTrue(set(np.unique(mask)) <= {0, 255})
        self.assertEqual(mask[h // 2, w // 2], 255)
        self.assertEqual(mask[0, 0], 0)
        self.assertEqual(mask[h - 1, w - 1], 0)

    def test_salt_is_a_pale_bloom_fading_to_nothing(self):
        image = np.asarray(paint.PAINTINGS["decal_salt"]())
        alpha = image[:, :, 3]
        self.assertGreaterEqual(len(np.unique(alpha)), 3, "a soft edge, not a hard cut")
        self.assertEqual(int(alpha[0, 0]), 0)
        self.assertGreater(image[alpha > 0][:, :3].mean(), 150.0, "not pale")


class Foliage(unittest.TestCase):
    def test_every_foliage_painting_is_cut_out_clean(self):
        for name in FOLIAGE:
            with self.subTest(name):
                image = paint.PAINTINGS[name]()
                self.assertEqual(image.mode, "RGBA")
                alpha = np.asarray(image)[:, :, 3]
                self.assertTrue(set(np.unique(alpha)) <= {0, 255}, "alpha not cut clean")
                solid = float((alpha == 255).mean())
                self.assertGreater(solid, 0.15, "hardly anything painted")
                self.assertLess(solid, 0.9, "no gaps: a card, not leaves")

    def test_the_customs_azulejos_are_cobalt_on_white_glaze(self):
        pixels = np.asarray(paint.PAINTINGS["azulejo_ship"]().convert("RGB")).astype(float)
        blue = (pixels[:, :, 2] > pixels[:, :, 0] + 40).mean()
        white = (pixels.min(axis=2) > 170).mean()
        self.assertGreater(blue, 0.15)
        self.assertGreater(white, 0.3)

    def test_the_comet_and_the_king_are_painted_in_the_glaze(self):
        # (The old town's panels, 4 x 6 tiles of 32 px: cobalt washed and
        # drawn on the tin glaze, its white left bare in places; the
        # comet's red-brown in its own.)
        for name in ("azulejo_comet", "azulejo_king"):
            with self.subTest(name):
                image = paint.PAINTINGS[name]()
                self.assertEqual(image.size, (128, 192))
                pixels = np.asarray(image.convert("RGB")).astype(float)
                self.assertGreater((pixels[:, :, 2] > pixels[:, :, 0] + 40).mean(), 0.3)
                self.assertGreater((pixels.min(axis=2) > 170).mean(), 0.15)

        comet = np.asarray(paint.PAINTINGS["azulejo_comet"]().convert("RGB")).astype(float)
        self.assertGreater(((comet[:, :, 0] > comet[:, :, 2] + 50) & (comet[:, :, 0] > 120)).mean(), 0.01)

    def test_the_souls_burn_under_the_king(self):
        # (The alminha: the comet's red fire in its lower third, cobalt
        # heavens above, the king's face a blank in the glaze.)
        image = paint.PAINTINGS["azulejo_souls"]()
        self.assertEqual(image.size, (128, 192))
        pixels = np.asarray(image.convert("RGB")).astype(float)
        low, high = pixels[128:], pixels[:64]
        self.assertGreater(((low[:, :, 0] > low[:, :, 2] + 50) & (low[:, :, 0] > 120)).mean(), 0.25)
        self.assertGreater((high[:, :, 2] > high[:, :, 0] + 40).mean(), 0.2)

    def test_the_kings_face_is_left_blank(self):
        # (A patch of bare glaze where his face is: nothing painted in it.)
        pixels = np.asarray(paint.PAINTINGS["azulejo_king"]().convert("RGB")).astype(float)
        face = pixels[58:66, 59:64]
        self.assertGreater(face.min(), 170.0)

    def test_a_lit_window_is_panes_of_warm_light(self):
        # (Through small panes in a dark frame: a room's warm light falling
        # off from its lamp, a curtain drawn to one side.)
        image = paint.PAINTINGS["window_lit"]()
        w, h = image.size
        self.assertEqual((w & (w - 1), h & (h - 1)), (0, 0))
        pixels = np.asarray(image.convert("RGB")).astype(float)
        warm = (pixels[:, :, 0] > pixels[:, :, 2] + 40).mean()
        self.assertGreater(warm, 0.6)
        lum = pixels.mean(axis=2)
        self.assertGreater(lum.max() - lum.min(), 120.0)
        # (Its frame's bars: whole dark rows and columns.)
        self.assertTrue(any(lum[y, 4:-4].mean() < 50 for y in range(h // 4, 3 * h // 4)))

    def test_the_tile_frame_is_a_strip_of_four_tiles(self):
        image = paint.PAINTINGS["tile_frame"]()
        self.assertEqual(image.size, (128, 32))
        pixels = np.asarray(image.convert("RGB")).astype(float)
        self.assertGreater((pixels[:, :, 2] > pixels[:, :, 0] + 40).mean(), 0.2)

    def test_the_royal_arms_are_a_cut_out_shield_with_its_quinas(self):
        image = np.asarray(paint.PAINTINGS["arms_royal"]())
        alpha = image[:, :, 3]
        self.assertTrue(set(np.unique(alpha)) <= {0, 255})
        # Its field's red bordure and blue quinas both show.
        rgb = image[:, :, :3].astype(float)[alpha == 255]
        self.assertGreater(((rgb[:, 0] > rgb[:, 2] + 60)).mean(), 0.1)
        self.assertGreater(((rgb[:, 2] > rgb[:, 0] + 30)).mean(), 0.03)

    def test_a_painting_is_a_power_of_two_on_each_side(self):
        for name in FOLIAGE + ["bark"]:
            with self.subTest(name):
                w, h = paint.PAINTINGS[name]().size
                self.assertEqual(w & (w - 1), 0)
                self.assertEqual(h & (h - 1), 0)

    def test_leaves_are_many_greens_not_a_flat_colour(self):
        for name in ["leaf_crown", "leaf_shrub", "yew", "grass", "weed_broad", "ivy", "gorse", "fennel", "pine"]:
            with self.subTest(name):
                pixels = np.asarray(paint.PAINTINGS[name]())
                solid = pixels[pixels[:, :, 3] == 255][:, :3].astype(int)
                colours = {tuple(p) for p in solid}
                self.assertGreaterEqual(len(colours), 10)
                # Green leads: more green than red or blue, taken together.
                mean = solid.mean(axis=0)
                self.assertGreater(mean[1], mean[0])
                self.assertGreater(mean[1], mean[2])

    def test_gorse_flowers_and_fennel_flowers_show(self):
        # Gorse's yellow among its dark spines; sea fennel's yellow-green
        # umbels over its grey-green fronds.
        for name, least in (("gorse", 0.01), ("fennel", 0.01)):
            with self.subTest(name):
                pixels = np.asarray(paint.PAINTINGS[name]())
                solid = pixels[pixels[:, :, 3] == 255][:, :3].astype(int)
                yellow = (solid[:, 0] > 140) & (solid[:, 1] > 120) & (solid[:, 2] < 90)
                self.assertGreater(float(yellow.mean()), least)

    def test_a_stone_pine_crown_is_wider_than_tall(self):
        # The umbrella: its needles spread wide and flat over a bare underside.
        alpha = np.asarray(paint.PAINTINGS["pine"]())[:, :, 3] == 255
        rows, cols = np.nonzero(alpha)
        self.assertGreater(cols.max() - cols.min(), 1.6 * (rows.max() - rows.min()))

    def test_laundry_is_garments_on_a_line(self):
        image = paint.PAINTINGS["laundry"]()
        w, h = image.size
        self.assertEqual((w & (w - 1), h & (h - 1)), (0, 0))
        pixels = np.asarray(image)
        alpha = pixels[:, :, 3]
        self.assertTrue(set(np.unique(alpha)) <= {0, 255})
        solid = float((alpha == 255).mean())
        self.assertGreater(solid, 0.25)
        self.assertLess(solid, 0.8)
        # The line along the top end to end (sagging), gaps between the
        # garments.
        self.assertTrue((alpha[: h // 6] == 255).any(axis=0).all(), "no line end to end")
        self.assertGreaterEqual(sum(1 for x in range(1, w) if alpha[h // 2, x] == 0 and alpha[h // 2, x - 1] == 255), 3)

    def test_a_crown_is_lumpy_not_a_disc(self):
        # Its outline wanders: along rays from the middle, where the leaves
        # end varies by more than a fifth of the half-width.
        alpha = np.asarray(paint.PAINTINGS["leaf_crown"]())[:, :, 3]
        h, w = alpha.shape
        ends = []

        for angle in np.linspace(0.0, 2.0 * np.pi, 48, endpoint=False):
            last = 0

            for r in range(1, w // 2):
                x = int(w / 2 + np.cos(angle) * r)
                y = int(h / 2 + np.sin(angle) * r)

                if alpha[y, x] == 255:
                    last = r

            ends.append(last)

        self.assertGreater(max(ends) - min(ends), w * 0.1)

    def test_grass_and_reeds_grow_from_the_bottom(self):
        for name in ["grass", "reeds"]:
            with self.subTest(name):
                alpha = np.asarray(paint.PAINTINGS[name]())[:, :, 3]
                h = alpha.shape[0]
                bottom = (alpha[int(h * 0.85):] == 255).mean()
                top = (alpha[: int(h * 0.15)] == 255).mean()
                self.assertGreater(bottom, top)


class Bat(unittest.TestCase):
    def test_a_bat_is_two_frames_of_a_dark_cut_out_silhouette(self):
        image = paint.PAINTINGS["bat"]()
        w, h = image.size
        self.assertEqual((w, h), (128, 64))
        pixels = np.asarray(image)
        alpha = pixels[:, :, 3]
        self.assertTrue(set(np.unique(alpha)) <= {0, 255})
        left, right = alpha[:, : w // 2], alpha[:, w // 2:]
        # Both frames a bat, and not the same bat: its wings beat.
        self.assertGreater((left == 255).mean(), 0.05)
        self.assertGreater((right == 255).mean(), 0.05)
        self.assertGreater((left != right).mean(), 0.05)
        self.assertLess(pixels[alpha == 255][:, :3].mean(), 60)


FLOOR_DECALS = ["decal_soot", "decal_dirt", "decal_straw", "decal_leaves"]


def _alpha(name):
    return np.asarray(paint.PAINTINGS[name]())[:, :, 3]


def _visible(name):
    pixels = np.asarray(paint.PAINTINGS[name]())
    return pixels[pixels[:, :, 3] > 0][:, :3].astype(float)


class FloorDecals(unittest.TestCase):
    def test_a_floor_decal_fades_out_before_its_square_edges(self):
        for name in FLOOR_DECALS:
            with self.subTest(name):
                image = paint.PAINTINGS[name]()
                self.assertEqual(image.mode, "RGBA")
                w, h = image.size
                self.assertEqual(w & (w - 1), 0)
                self.assertEqual(h & (h - 1), 0)
                alpha = _alpha(name)
                rim = np.concatenate([alpha[:4].ravel(), alpha[-4:].ravel(), alpha[:, :4].ravel(), alpha[:, -4:].ravel()])
                self.assertLess((rim > 0).mean(), 0.02, "its square shows at the rim")
                shown = float((alpha > 0).mean())
                self.assertGreater(shown, 0.08, "hardly anything painted")
                self.assertLess(shown, 0.85)

    def test_soot_and_dirt_fade_in_a_few_steps_not_a_hard_cut(self):
        # A PS2 falloff: some steps between clear and solid, not a smooth
        # ramp nor one cut.
        for name in ["decal_soot", "decal_dirt"]:
            with self.subTest(name):
                levels = set(np.unique(_alpha(name))) - {0}
                self.assertGreaterEqual(len(levels), 3)
                self.assertLessEqual(len(levels), 6)

    def test_soot_is_black_and_thickest_in_the_middle(self):
        alpha = _alpha("decal_soot").astype(float)
        h, w = alpha.shape
        middle = alpha[h * 3 // 8: h * 5 // 8, w * 3 // 8: w * 5 // 8].mean()
        y, x = np.mgrid[0:h, 0:w]
        ring = alpha[(np.hypot(x - w / 2, y - h / 2) > w * 0.3) & (np.hypot(x - w / 2, y - h / 2) < w * 0.45)].mean()
        self.assertGreater(middle, ring * 2.0)
        self.assertLess(_visible("decal_soot").mean(), 50)

    def test_dirt_is_brown_with_a_ragged_edge(self):
        mean = _visible("decal_dirt").mean(axis=0)
        self.assertGreater(mean[0], mean[2] + 8)
        alpha = _alpha("decal_dirt")
        h, w = alpha.shape
        ends = []

        for angle in np.linspace(0.0, 2.0 * np.pi, 48, endpoint=False):
            last = 0

            for r in range(1, w // 2):
                if alpha[int(h / 2 + np.sin(angle) * r), int(w / 2 + np.cos(angle) * r)] > 0:
                    last = r

            ends.append(last)

        self.assertGreater(max(ends) - min(ends), w * 0.1)

    def test_straw_is_pale_gold_strands(self):
        mean = _visible("decal_straw").mean(axis=0)
        self.assertGreater(mean[0], mean[2] + 30)
        self.assertGreater(mean[1], mean[2] + 20)
        self.assertLess(float((_alpha("decal_straw") > 0).mean()), 0.45, "a mat, not strands")
        self.assertTrue(set(np.unique(_alpha("decal_straw"))) <= {0, 255})

    def test_leaves_are_many_autumn_colours_cut_clean(self):
        visible = _visible("decal_leaves")
        self.assertGreaterEqual(len({tuple(p) for p in visible.astype(int)}), 10)
        mean = visible.mean(axis=0)
        self.assertGreater(mean[0], mean[2] + 15)
        self.assertTrue(set(np.unique(_alpha("decal_leaves"))) <= {0, 255})


class Carpet(unittest.TestCase):
    def test_the_carpet_tiles_both_ways(self):
        image = np.asarray(paint.PAINTINGS["carpet"]().convert("RGB")).astype(float)
        inside = np.abs(np.diff(image, axis=1)).mean()
        self.assertLess(np.abs(image[:, -1] - image[:, 0]).mean(), inside * 2.0 + 4.0)
        inside_v = np.abs(np.diff(image, axis=0)).mean()
        self.assertLess(np.abs(image[-1] - image[0]).mean(), inside_v * 2.0 + 4.0)

    def test_the_carpet_is_a_deep_red_weave_with_a_pattern_in_it(self):
        image = paint.PAINTINGS["carpet"]()
        w, h = image.size
        self.assertEqual(w & (w - 1), 0)
        self.assertEqual(h & (h - 1), 0)
        pixels = np.asarray(image.convert("RGB")).astype(float)
        mean = pixels.reshape(-1, 3).mean(axis=0)
        self.assertGreater(mean[0], mean[1] + 30)
        self.assertGreater(mean[0], mean[2] + 30)
        self.assertGreaterEqual(len({tuple(p) for p in pixels.reshape(-1, 3).astype(int)}), 8)
        self.assertGreater(pixels.std(), 10.0)


class Bark(unittest.TestCase):
    def test_bark_is_solid_and_tiles_both_ways(self):
        image = np.asarray(paint.PAINTINGS["bark"]().convert("RGB")).astype(float)
        # The last column runs on into the first, the last row into the first,
        # as smoothly as columns inside it do.
        inside = np.abs(np.diff(image, axis=1)).mean()
        seam = np.abs(image[:, -1] - image[:, 0]).mean()
        self.assertLess(seam, inside * 2.0 + 4.0)
        inside_v = np.abs(np.diff(image, axis=0)).mean()
        seam_v = np.abs(image[-1] - image[0]).mean()
        self.assertLess(seam_v, inside_v * 2.0 + 4.0)

    def test_bark_runs_in_furrows_up_the_trunk(self):
        # Rougher across (x) than up (y): its furrows run up the trunk.
        image = np.asarray(paint.PAINTINGS["bark"]().convert("L")).astype(float)
        self.assertGreater(np.abs(np.diff(image, axis=1)).mean(), np.abs(np.diff(image, axis=0)).mean() * 1.3)


class Facades(unittest.TestCase):
    def test_a_house_front_is_its_render_round_dark_windows_where_the_kit_puts_them(self):
        # (kit_massing lights its windows in the openings: FACADE_WINDOWS
        # along it, FACADE_FLOORS up it, FACADE_OPENING's sill and head.)
        per = paint.FACADE_PX[0] / paint.FACADE[0]
        self.assertAlmostEqual(paint.FACADE_PX[1] / paint.FACADE[1], per, places=6)

        for wall, colour in paint.FACADE_WALLS.items():
            image = np.asarray(paint.PAINTINGS["facade_" + wall]().convert("RGB")).astype(float)
            self.assertEqual(image.shape[:2], (paint.FACADE_PX[1], paint.FACADE_PX[0]), wall)
            h = image.shape[0]

            for floor in paint.FACADE_FLOORS:
                y = int(h - (floor + (paint.FACADE_OPENING[0] + paint.FACADE_OPENING[1]) / 2.0) * per)

                for u in paint.FACADE_WINDOWS:
                    # A window: dark glass or a shutter, never the render.
                    self.assertLess(image[y, int(u * per) + 2].mean(), np.mean(colour) * 0.6, (wall, floor, u))

            # Between the storeys' windows, the render.
            between = image[int(h - 3.2 * per), int(3.0 * per)]
            self.assertLess(np.abs(between - np.array(colour)).max(), 50.0, wall)


if __name__ == "__main__":
    unittest.main()
