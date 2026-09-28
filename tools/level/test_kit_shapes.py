"""The kit v1 shapes (kit_shapes.py) and the pieces modelled with them:
pure Python, no Blender.

    python3 tools/level/test_kit_shapes.py
"""

import os
import sys
import unittest

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import kit_recipes  # noqa: E402
import kit_shapes  # noqa: E402

EPS = 1e-6


def bounds(part):
    xs = [v[0] for v in part["verts"]]
    ys = [v[1] for v in part["verts"]]
    zs = [v[2] for v in part["verts"]]
    return (min(xs), min(ys), min(zs)), (max(xs), max(ys), max(zs))


def tris(part):
    return sum(len(f[0]) - 2 for f in part["faces"])


class Shapes(unittest.TestCase):
    def test_a_prism_is_its_size(self):
        part = kit_shapes.build([kit_shapes.prism(0.0, 1.0, 0.0, 0.25, 2.0, 8, "ashlar")])
        low, high = bounds(part)
        self.assertAlmostEqual(low[1], 0.0, places=5)
        self.assertAlmostEqual(high[1], 2.0, places=5)
        self.assertLessEqual(max(high[0], -low[0], high[2], -low[2]), 0.25 + EPS)
        # (Faces keep their own corners: hard edges, the PS2 way.)
        self.assertEqual(len({tuple(round(c, 6) for c in v) for v in part["verts"]}), 16)
        self.assertEqual(tris(part), 8 * 2 + 2 * 6)

    def test_an_arched_opening_leaves_its_hole_clear(self):
        # A door in a 2 m wall: 1.2 wide, springing at 1.6, a round head up to
        # 2.2; nothing of the wall is left in the hole.
        part = kit_shapes.build(kit_shapes.arched_wall(2.0, 3.0, 0.4, 1.2, 1.6, 0.6, 0.0, "ashlar"))
        low, high = bounds(part)
        self.assertAlmostEqual(low[0], -1.0, places=5)
        self.assertAlmostEqual(high[0], 1.0, places=5)
        self.assertAlmostEqual(high[1], 3.0, places=5)

        for x, y, z in part["verts"]:
            if abs(x) < 0.6 - 1e-3 and 1e-3 < y < 1.6 - 1e-3:
                self.fail("a vertex in the doorway at %s" % [x, y, z])

    def test_a_pointed_head_reaches_its_rise(self):
        part = kit_shapes.build(kit_shapes.arched_wall(2.0, 6.0, 0.4, 0.9, 3.9, 1.5, 1.8, "ashlar", pointed=True))
        # The hole's top: the highest point with nothing of the wall over it
        # in the middle of the opening is its apex (spring + rise).
        middle = [y for x, y, z in part["verts"] if abs(x) < 1e-3 and 1.8 < y < 6.0 - 1e-3]
        self.assertTrue(any(abs(y - 5.4) < 1e-3 for y in middle), middle)

    def test_a_card_has_its_photo_across_it(self):
        part = kit_shapes.build([kit_shapes.card(0.0, 1.0, 0.0, 2.0, 2.0, "facade_1")])
        us = [uv[0] for face in part["faces"] for uv in face[2]]
        vs = [uv[1] for face in part["faces"] for uv in face[2]]
        self.assertAlmostEqual(min(us), 0.0)
        self.assertAlmostEqual(max(us), 1.0)
        self.assertAlmostEqual(min(vs), 0.0)
        self.assertAlmostEqual(max(vs), 1.0)


class Roofs(unittest.TestCase):
    def test_a_gable_is_a_triangle_to_its_apex(self):
        part = kit_shapes.build([kit_shapes.gable(0.0, 0.0, 0.0, 16.0, 5.0, 0.4, "plaster")])
        low, high = bounds(part)
        self.assertAlmostEqual(high[1], 5.0, places=5)
        self.assertAlmostEqual(low[1], 0.0, places=5)
        self.assertAlmostEqual(high[0], 8.0, places=5)
        apex = [v for v in part["verts"] if abs(v[1] - 5.0) < 1e-6]
        self.assertTrue(apex and all(abs(v[0]) < 1e-6 for v in apex))

    def test_a_pitched_roof_runs_from_its_eaves_to_its_ridge(self):
        # A section of the barracks' roof: 16 m across, its ridge 5 m up.
        recipe = kit_recipes.PIECES["roof_ridge_4x16"]
        part = kit_shapes.build(recipe["shapes"])
        low, high = bounds(part)
        self.assertLess(low[1], 0.05)
        self.assertGreater(high[1], 5.0)
        self.assertLess(high[1], 5.6)
        self.assertGreaterEqual(max(high[2], -low[2]), 8.0)
        self.assertEqual(recipe["cols"], [])


class Pieces(unittest.TestCase):
    def test_modelled_pieces_stay_in_their_size(self):
        # A v1 piece drawn within the footprint its v0 boxes (its colliders)
        # were made to: nothing of it pokes through a neighbour.
        loose = []

        for name, recipe in kit_recipes.PIECES.items():
            if not recipe.get("shapes"):
                continue

            part = kit_shapes.build(recipe["shapes"])
            low, high = bounds(part)
            size = recipe["size"]
            slack = 0.06 if recipe["family"] in ("wall", "curtain", "floor", "stair") else 0.25

            if max(high[0], -low[0]) > size[0] / 2.0 + slack or max(high[2], -low[2]) > size[2] / 2.0 + slack:
                loose.append("%s: x %.2f..%.2f z %.2f..%.2f for %s" % (name, low[0], high[0], low[2], high[2], size))

        self.assertEqual(loose, [])

    def test_modelled_pieces_are_low_poly(self):
        heavy = [(n, tris(kit_shapes.build(r["shapes"]))) for n, r in kit_recipes.PIECES.items() if r.get("shapes")]
        self.assertEqual([h for h in heavy if h[1] > kit_shapes.PIECE_TRIS], [])

    def test_the_kit_is_modelled(self):
        # Kit v1: the pieces that read as boxes are modelled (openings, columns
        # and arches, round things, foliage, the house fronts).
        wanted = ["wall_ashlar_door", "wall_plaster_window", "wall_ashlar_arch", "wall_ashlar_tall_lancet", "column", "arch_span_3",
                  "barrel", "well", "candle_stand", "cart", "tree", "bush", "house_front", "banner", "buttress", "chandelier", "weeds"]
        self.assertEqual([n for n in wanted if not kit_recipes.PIECES[n].get("shapes")], [])

    def test_colliders_stay_the_blocks(self):
        # Modelling a piece never moves what men walk on and bump into.
        door = kit_recipes.PIECES["wall_ashlar_door"]
        self.assertTrue(door["cols"])
        self.assertTrue(all(c[6] == "stone" for c in door["cols"]))


if __name__ == "__main__":
    unittest.main()
