"""The kit v1 shapes (kit_shapes.py) and the pieces modelled with them:
pure Python, no Blender.

    python3 tools/level/test_kit_shapes.py
"""

import math
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

    def test_a_polygon_is_one_face_as_wound(self):
        # A vault's web: one face through its points, seen from the side it
        # winds counter-clockwise toward (here: from below).
        part = kit_shapes.build([kit_shapes.polygon([[0.0, 3.0, 0.0], [1.0, 2.0, 0.0], [0.0, 2.0, 1.0]], "brick")])
        self.assertEqual(tris(part), 1)
        self.assertLess(kit_shapes._normal([part["verts"][i] for i in part["faces"][0][0]])[1], 0.0)
        moved = kit_shapes.moved([kit_shapes.polygon([[1.0, 0.0, 0.0], [0.0, 0.0, -1.0], [0.0, 1.0, 0.0]], "brick")], 90.0, (0.0, 5.0, 0.0))
        self.assertAlmostEqual(moved[0]["points"][2][1], 6.0)

    def test_an_arched_wall_moves_and_turns(self):
        # Set 1 m forward and turned a quarter: it runs along z, 0.4 thick
        # about x = 1.
        part = kit_shapes.build(kit_shapes.arched_wall(2.0, 3.0, 0.4, 1.2, 1.6, 0.6, 0.0, "ashlar", z=1.0, yaw=90.0))
        low, high = bounds(part)
        self.assertAlmostEqual(low[0], 0.8, places=5)
        self.assertAlmostEqual(high[0], 1.2, places=5)
        self.assertAlmostEqual(low[2], -1.0, places=5)
        self.assertAlmostEqual(high[2], 1.0, places=5)

    def test_a_horseshoe_head_runs_below_its_springing(self):
        # The Nasrid gate: an arch 7 m across at 6.5 m, its circle running on a
        # third of its radius below that, onto jambs narrower than the arch.
        shape = kit_shapes.arched_wall(12.0, 14.5, 2.4, 7.0, 6.5, 3.5, 0.0, "brick", horseshoe=0.33)[0]
        head = kit_shapes._head(shape)
        drop = 0.33 * 3.5
        jamb = abs(head[0][0])
        self.assertAlmostEqual(min(y for _, y in head), 6.5 - drop, places=3)
        self.assertAlmostEqual(max(y for _, y in head), 10.0, places=3)
        self.assertAlmostEqual(max(abs(x) for x, _ in head), 3.5, places=2)
        self.assertLess(jamb, 3.5 - 0.1)

        # Nothing of the wall in the opening: under the jambs' tops, nor in
        # the arch's circle over them.
        for x, y, z in kit_shapes.build([shape])["verts"]:
            if y < 6.5 - drop - 1e-3 and abs(x) < jamb - 1e-3:
                self.fail("a vertex in the gateway at %s" % [x, y, z])

            if y > 6.5 - drop + 1e-3 and math.hypot(x, y - 6.5) < 3.5 - 1e-2:
                self.fail("a vertex in the arch at %s" % [x, y, z])

        # Its fronts look out (drawn one side only): +z at the front, -z at
        # the back.
        part = kit_shapes.build([shape])

        for indices, _, _ in part["faces"]:
            points = [part["verts"][i] for i in indices]

            for side in (1.2, -1.2):
                if all(abs(p[2] - side) < 1e-6 for p in points):
                    self.assertGreater(kit_shapes._normal(points)[2] * side, 0.0, points)

        # And the wall is whole round the arch: its front's area is the
        # wall's less the opening's.
        front = sum(abs(kit_shapes._normal([part["verts"][i] for i in f[0]])[2]) / 2.0 for f in part["faces"]
                    if all(abs(part["verts"][i][2] - 1.2) < 1e-6 for i in f[0]))
        jamb_top = 6.5 - drop
        opening = 2.0 * jamb * jamb_top + sum(abs(x1 * y0 - x0 * y1) / 2.0 for (x0, y0), (x1, y1) in
                                               zip([(x, y - jamb_top) for x, y in head], [(x, y - jamb_top) for x, y in head[1:]]))
        self.assertAlmostEqual(front, 12.0 * 14.5 - opening, delta=0.5)

    def test_a_pointed_head_reaches_its_rise(self):
        part = kit_shapes.build(kit_shapes.arched_wall(2.0, 6.0, 0.4, 0.9, 3.9, 1.5, 1.8, "ashlar", pointed=True))
        # The hole's top: the highest point with nothing of the wall over it
        # in the middle of the opening is its apex (spring + rise).
        middle = [y for x, y, z in part["verts"] if abs(x) < 1e-3 and 1.8 < y < 6.0 - 1e-3]
        self.assertTrue(any(abs(y - 5.4) < 1e-3 for y in middle), middle)

    def test_a_lathe_turns_its_profile(self):
        # A bowl: 0.08 at its foot, 0.15 at its lip 0.07 up.
        part = kit_shapes.build([kit_shapes.lathe(0.0, 0.0, 0.0, [[0.08, 0.0], [0.13, 0.04], [0.15, 0.07]], 10, "pottery")])
        low, high = bounds(part)
        self.assertAlmostEqual(low[1], 0.0, places=5)
        self.assertAlmostEqual(high[1], 0.07, places=5)
        self.assertLessEqual(high[0], 0.15 + EPS)
        self.assertGreater(high[0], 0.14)
        # (Its foot closed, its mouth open: 10 x 2 bands, a 10-gon underneath.)
        self.assertEqual(tris(part), 10 * 2 * 2 + 8)

    def test_a_lathe_tipped_lies_along_its_axis(self):
        # A keg on its side: turned about x.
        part = kit_shapes.build([kit_shapes.lathe(0.0, 0.3, 0.0, [[0.25, -0.35], [0.3, 0.0], [0.25, 0.35]], 8, "boards", roll=90.0)])
        low, high = bounds(part)
        self.assertAlmostEqual(high[0] - low[0], 0.7, places=4)
        self.assertLess(high[1] - low[1], 0.61)

    def test_a_disc_has_its_photo_across_it(self):
        part = kit_shapes.build([kit_shapes.disc(0.0, 2.0, 0.0, 1.2, 16, "rose_window")])
        us = [uv[0] for face in part["faces"] for uv in face[2]]
        self.assertAlmostEqual(min(us), 0.0, places=5)
        self.assertAlmostEqual(max(us), 1.0, places=5)
        low, high = bounds(part)
        self.assertAlmostEqual(high[1], 3.2, places=5)
        # (Drawn both ways.)
        self.assertEqual(len(part["faces"]), 2)

    def test_a_slab_lays_its_photo_along_its_first_edge(self):
        # A roof's slope: its top from the ridge (y 5) down to the eaves; the
        # photo's rows run along the ridge, one photo every 1.5 m.
        corners = [[-2.0, 5.0, 0.0], [2.0, 5.0, 0.0], [2.0, 0.0, 8.0], [-2.0, 0.0, 8.0]]
        part = kit_shapes.build([kit_shapes.slab(corners, 0.2, "roof_slate", tile=1.5)])
        top = [f for f in part["faces"] if f[1] == "roof_slate"][0]
        points = [part["verts"][i] for i in top[0]]
        normal = kit_shapes._normal(points)
        self.assertGreater(normal[1], 0.0)
        self.assertGreater(normal[2], 0.0)

        for p, uv in zip(points, top[2]):
            self.assertAlmostEqual(uv[0], (p[0] + 2.0) / 1.5, places=5)
            self.assertAlmostEqual(uv[1], ((p[2] / 8.0) * 9.4339811) / 1.5, places=4)

    def test_a_ring_is_an_arc_of_stone(self):
        # An arch's hood: a half ring from 2.0 to 2.4 m out, 0.2 deep, over a
        # springing at y 3.
        part = kit_shapes.build([kit_shapes.ring(0.0, 3.0, 0.0, 2.0, 2.4, 0.2, 0.0, 180.0, 8, "ashlar")])
        low, high = bounds(part)
        self.assertAlmostEqual(low[1], 3.0, places=5)
        self.assertAlmostEqual(high[1], 5.4, places=4)
        self.assertAlmostEqual(high[0], 2.4, places=5)
        self.assertAlmostEqual(high[2] - low[2], 0.2, places=5)

        for x, y, z in part["verts"]:
            self.assertGreaterEqual(round((x * x + (y - 3.0) ** 2) ** 0.5, 6), 2.0 - 1e-6)

    def test_moved_shapes_turn_about_the_upright(self):
        # A board along x, turned a quarter: along z, then lifted.
        shapes = kit_shapes.moved([kit_shapes.box(2.0, 0.0, 0.0, 4.0, 0.2, 0.2, "timber"),
                                   kit_shapes.slab([[0, 0, 0], [4, 0, 0], [4, 0, 1], [0, 0, 1]], 0.1, "boards")], 90.0, (0.0, 3.0, 0.0))
        part = kit_shapes.build(shapes)
        low, high = bounds(part)
        self.assertAlmostEqual(low[1], 2.9, places=5)
        self.assertAlmostEqual(high[1], 3.1, places=5)
        self.assertAlmostEqual(low[2], -4.0, places=5)
        self.assertLess(high[0] - low[0], 1.3)

    def test_a_card_has_its_photo_across_it(self):
        part = kit_shapes.build([kit_shapes.card(0.0, 1.0, 0.0, 2.0, 2.0, "banner")])
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
        # The barracks' roof: 16 m across, its ridge 5 m up.
        recipe = kit_recipes.PIECES["roof_16x38"]
        part = kit_shapes.build(recipe["shapes"])
        low, high = bounds(part)
        self.assertLess(low[1], 0.05)
        self.assertGreater(high[1], 5.0)
        self.assertLess(high[1], 5.8)
        self.assertGreaterEqual(max(high[2], -low[2]), 8.0)
        self.assertEqual(recipe["cols"], [])

    def test_a_pitched_roof_is_an_a_not_a_v(self):
        # Its slopes fall from the ridge to the eaves: what is out at the eaves
        # is low, what is over the middle high; each slope's photo side faces
        # up and out.
        for name in ("roof_16x38", "roof_10x21"):
            part = kit_shapes.build(kit_recipes.PIECES[name]["shapes"])
            span = kit_recipes.PIECES[name]["span"]
            eaves = [v[1] for v in part["verts"] if abs(v[2]) > span / 2.0 - 0.01]
            ridge = [v[1] for v in part["verts"] if abs(v[2]) < 0.3]
            self.assertLess(max(eaves), 1.0, name)
            self.assertGreater(max(ridge), span * 0.25, name)

            for indices, slot, _ in part["faces"]:
                points = [part["verts"][i] for i in indices]

                # (The slopes; not the ridge's tiles over where they meet.)
                if slot.startswith("roof_") and max(abs(p[2]) for p in points) > 0.5:
                    normal = kit_shapes._normal(points)
                    middle_z = sum(p[2] for p in points) / len(points)

                    if abs(normal[1]) > 0.5 * max(abs(n) for n in normal):
                        self.assertGreater(normal[1], 0.0, "%s: a slope's top faces down" % name)
                        self.assertGreater(normal[2] * middle_z, -1e-6, "%s: a slope's top faces in" % name)


class Houses(unittest.TestCase):
    """The lanes' houses: modelled, jettied, roofed, each its own."""

    NAMES = ["house_%s" % c for c in "abcdef"]

    def slots(self, part):
        return {f[1] for f in part["faces"]}

    def test_every_house_is_modelled_door_windows_and_roof(self):
        for name in self.NAMES:
            recipe = kit_recipes.PIECES[name]
            part = kit_shapes.build(recipe["shapes"])
            slots = self.slots(part)
            self.assertTrue(slots & {"door_1", "door_2"}, name)
            self.assertTrue(slots & {"glass_dark", "glass_lit"}, name)
            self.assertTrue(any(s.startswith("roof_") for s in slots), name)
            self.assertIn("beam", slots, name)
            self.assertLessEqual(tris(part), recipe.get("budget", kit_shapes.PIECE_TRIS), name)
            low, high = bounds(part)
            self.assertGreaterEqual(low[1], -0.01, name)
            self.assertGreater(high[1], 8.0, name)

    def test_upper_storeys_jut_over_the_lane(self):
        # A jettied house: what is up at the first floor stands further out
        # than the ground floor's front.
        for name in self.NAMES:
            part = kit_shapes.build(kit_recipes.PIECES[name]["shapes"])
            front = kit_recipes.PIECES[name]["front"]
            upper = [v[2] for v in part["verts"] if 3.4 < v[1] < 5.0]
            self.assertGreater(max(upper), front + 0.3, name)

    def test_a_house_is_solid_to_its_eaves(self):
        for name in self.NAMES:
            recipe = kit_recipes.PIECES[name]
            self.assertTrue(recipe["cols"], name)
            col = recipe["cols"][0]
            self.assertAlmostEqual(col[1] - col[4] / 2.0, 0.0, places=5)
            self.assertGreaterEqual(col[4], 5.5, name)

    def test_the_houses_differ(self):
        looks = set()

        for name in self.NAMES:
            part = kit_shapes.build(kit_recipes.PIECES[name]["shapes"])
            roof = sorted(s for s in self.slots(part) if s.startswith("roof_"))[0]
            looks.add((round(bounds(part)[1][1]), roof))

        self.assertGreaterEqual(len(looks), 5)


class Dressing(unittest.TestCase):
    """The gatehouse's arches, banners, framed walls, joists and trusses."""

    def test_a_banner_hangs_from_its_rod_against_the_wall(self):
        # Its wall is behind it (local -z): the cloth just before it, a rod
        # over it on brackets into the wall; its tails at its foot (y 0).
        part = kit_shapes.build(kit_recipes.PIECES["banner"]["shapes"])
        low, high = bounds(part)
        self.assertAlmostEqual(low[1], 0.0, places=5)
        self.assertGreater(low[2], -0.02)
        cloth = [part["verts"][i] for f in part["faces"] if f[1] == "banner" for i in f[0]]
        self.assertTrue(cloth)
        self.assertTrue(all(0.0 < v[2] < 0.08 for v in cloth))
        self.assertGreater(high[1], max(v[1] for v in cloth))
        self.assertEqual(kit_recipes.PIECES["banner"]["cols"], [])

    def test_the_gate_arch_leaves_the_passage_clear(self):
        recipe = kit_recipes.PIECES["gate_arch"]
        part = kit_shapes.build(recipe["shapes"])

        for x, y, z in part["verts"]:
            if abs(x) < 1.95 - 1e-3 and y < 2.55 - 1e-3:
                self.fail("the gate arch stands in the passage at %s" % [x, y, z])

        low, high = bounds(part)
        self.assertGreater(high[1], 5.9)
        # (Solid only over the walk's floor: the parapet there.)
        self.assertTrue(all(c[1] - c[4] / 2.0 >= 4.8 - 1e-6 for c in recipe["cols"]))

    def test_plaster_walls_are_framed_both_sides(self):
        for name in ("wall_plaster_2", "wall_plaster_4", "wall_plaster_window", "wall_plaster_door", "wall_timber_thin_2"):
            recipe = kit_recipes.PIECES[name]
            part = kit_shapes.build(recipe["shapes"])
            depth = recipe["size"][2]
            beams = [part["verts"][i] for f in part["faces"] if f[1] == "beam" for i in f[0]]
            self.assertTrue(any(v[2] > depth / 2.0 + 0.01 for v in beams), name)
            self.assertTrue(any(v[2] < -depth / 2.0 - 0.01 for v in beams), name)

    def test_a_framed_door_is_flat_headed_and_clear(self):
        part = kit_shapes.build(kit_recipes.PIECES["wall_plaster_door"]["shapes"])

        for x, y, z in part["verts"]:
            if abs(x) < 0.6 - 1e-3 and 1e-3 < y < 2.2 - 1e-3:
                self.fail("something in the doorway at %s" % [x, y, z])

    def test_joists_and_trusses_are_drawn_only(self):
        for name in ("joists_22", "joists_72", "hall_truss_15"):
            recipe = kit_recipes.PIECES[name]
            self.assertEqual(recipe["cols"], [], name)
            self.assertTrue(recipe["shapes"], name)


class Chapel(unittest.TestCase):
    """The chapel's art: open trusses, glass, a spire, its dressing."""

    def test_the_hidden_ceiling_stops_but_is_not_drawn(self):
        recipe = kit_recipes.PIECES["ceiling_hidden_4"]
        self.assertEqual(recipe["boxes"], [])
        self.assertFalse(recipe.get("shapes"))
        self.assertEqual(len(recipe["cols"]), 1)
        self.assertEqual(recipe["surface"], "ceiling")

    def test_the_gables_carry_their_glass_on_both_faces(self):
        for name, radius in (("gable_chapel_east", 1.05), ("gable_chapel_west", 0.7)):
            part = kit_shapes.build(kit_recipes.PIECES[name]["shapes"])
            glass = [part["verts"][i] for f in part["faces"] if f[1] == "rose_window" for i in f[0]]
            self.assertTrue(any(v[2] > 0.2 for v in glass) and any(v[2] < -0.2 for v in glass), name)
            self.assertGreater(max(v[0] for v in glass), radius, name)
            # (The glass within the gable's triangle.)
            for x, y, z in glass:
                self.assertLess(abs(x), 4.8 * (1.0 - y / 5.0), name)

    def test_the_spire_rises_well_over_the_ridge(self):
        part = kit_shapes.build(kit_recipes.PIECES["fleche"]["shapes"])
        low, high = bounds(part)
        self.assertGreater(high[1], 8.0)
        self.assertEqual(kit_recipes.PIECES["fleche"]["cols"], [])

    def test_the_portal_leaves_the_door_clear(self):
        part = kit_shapes.build(kit_recipes.PIECES["chapel_portal"]["shapes"])

        for x, y, z in part["verts"]:
            if abs(x) < 0.6 - 1e-3 and y < 1.6 - 1e-3:
                self.fail("the portal stands in the doorway at %s" % [x, y, z])

    def test_the_dais_is_a_step_men_climb(self):
        recipe = kit_recipes.PIECES["chapel_dais"]
        self.assertTrue(recipe["cols"])
        self.assertLessEqual(recipe["size"][1], 0.2)

    def test_a_truss_spans_the_nave(self):
        part = kit_shapes.build(kit_recipes.PIECES["chapel_truss"]["shapes"])
        low, high = bounds(part)
        self.assertGreater(high[0] - low[0], 9.0)
        self.assertLess(high[0] - low[0], 9.4)
        self.assertGreater(high[1], 4.0)
        self.assertLess(low[1], -2.3)


class Props(unittest.TestCase):
    """What fills the mess hall and the kitchen."""

    PROPS = ["tableware_4", "dresser", "keg_rack", "hanging_food", "shield_trio", "cauldron", "stool", "kitchen_spread", "log_basket"]

    def test_every_prop_is_modelled_within_its_budget(self):
        for name in self.PROPS:
            recipe = kit_recipes.PIECES[name]
            part = kit_shapes.build(recipe["shapes"])
            self.assertLessEqual(tris(part), recipe.get("budget", kit_shapes.PIECE_TRIS), name)

    def test_tableware_sits_on_the_table_and_leaves_the_candles_room(self):
        # Its foot at the table top (y 0); nothing over the table's edge;
        # the candles (x -1 or +1 on the table's middle line) have room.
        part = kit_shapes.build(kit_recipes.PIECES["tableware_4"]["shapes"])
        low, high = bounds(part)
        self.assertGreaterEqual(low[1], -1e-6)
        self.assertLess(high[2], 0.45)
        self.assertGreater(low[2], -0.45)

        for x, y, z in part["verts"]:
            for candle in (-1.0, 1.0):
                self.assertGreater((x - candle) ** 2 + z ** 2, 0.15 ** 2, "something where a candle stands at %s" % [x, y, z])

    def test_the_food_hangs_under_its_pole(self):
        part = kit_shapes.build(kit_recipes.PIECES["hanging_food"]["shapes"])
        low, high = bounds(part)
        self.assertLess(high[1], 0.1)
        self.assertLess(low[1], -0.4)

    def test_the_tables_and_benches_stand_on_trestles(self):
        for name in ("table_long", "bench", "crate", "chest", "rack", "woodpile", "sacks", "stove"):
            self.assertTrue(kit_recipes.PIECES[name].get("shapes"), name)

    def test_what_is_hung_on_walls_stays_before_them(self):
        for name in ("shield_trio", "dresser", "keg_rack"):
            part = kit_shapes.build(kit_recipes.PIECES[name]["shapes"])
            self.assertGreaterEqual(bounds(part)[0][2], -kit_recipes.PIECES[name]["size"][2] / 2.0 - 0.01, name)


class Nature(unittest.TestCase):
    PLANTS = ["tree_oak", "tree_yew", "tree_dead", "bush", "grass_tuft", "weeds", "reeds_clump", "ivy_2x3", "ivy_1x2"]

    def test_a_rounded_card_carries_normals_out_from_its_middle(self):
        # (On both of its faces: lit alike from either side, as a mass.)
        part = kit_shapes.build([kit_shapes.card(1.0, 2.0, 0.0, 1.0, 1.0, "leaf_crown", round=[0.0, 2.0, 0.0])])
        self.assertEqual(sorted(part["normals"]), [0, 1])

        for face, normals in part["normals"].items():
            for index, n in zip(part["faces"][face][0], normals):
                v = part["verts"][index]
                out = [v[0] - 0.0, v[1] - 2.0, v[2] - 0.0]
                length = sum(c * c for c in out) ** 0.5
                self.assertAlmostEqual(sum(a * b / length for a, b in zip(n, out)), 1.0, places=5)

    def test_a_plain_card_keeps_flat_normals(self):
        part = kit_shapes.build([kit_shapes.card(0.0, 1.0, 0.0, 1.0, 1.0, "cloth")])
        self.assertEqual(part["normals"], {})

    def test_every_plant_is_modelled_within_its_budget(self):
        for name in self.PLANTS:
            with self.subTest(name):
                recipe = kit_recipes.PIECES[name]
                self.assertTrue(recipe.get("shapes"))
                self.assertLessEqual(tris(kit_shapes.build(recipe["shapes"])), recipe.get("budget", kit_shapes.PIECE_TRIS))

    def test_a_trees_crown_is_leaves_rounded_as_a_mass_over_its_trunk(self):
        for name, leaves, least in (("tree_oak", "leaf_crown", 24), ("tree_yew", "yew", 24), ("tree_dead", "twigs", 6)):
            with self.subTest(name):
                part = kit_shapes.build(kit_recipes.PIECES[name]["shapes"])
                crown = [i for i, f in enumerate(part["faces"]) if f[1] == leaves]
                self.assertGreaterEqual(len(crown) // 2, least)
                self.assertTrue(all(i in part["normals"] for i in crown))
                trunk = [f for f in part["faces"] if f[1] == "bark"]
                self.assertTrue(trunk)
                low, high = bounds(part)
                self.assertGreater(high[1], 5.0)

    def test_a_tree_stands_on_its_trunk_alone(self):
        # Men walk under the boughs and round the trunk, not the crown.
        for name in ("tree_oak", "tree_yew", "tree_dead"):
            with self.subTest(name):
                cols = kit_recipes.PIECES[name]["cols"]
                self.assertEqual(len(cols), 1)
                self.assertLessEqual(max(cols[0][3], cols[0][5]), 1.2)

    def test_ground_cover_and_ivy_stop_nobody(self):
        for name in ("bush", "grass_tuft", "weeds", "reeds_clump", "ivy_2x3", "ivy_1x2"):
            with self.subTest(name):
                self.assertEqual(kit_recipes.PIECES[name]["cols"], [])

    def test_ivy_lies_flat_before_its_wall(self):
        # (Its wall at the piece's back: local z 0, the ivy just in front.)
        for name in ("ivy_2x3", "ivy_1x2"):
            with self.subTest(name):
                low, high = bounds(kit_shapes.build(kit_recipes.PIECES[name]["shapes"]))
                self.assertGreaterEqual(low[2], 0.0)
                self.assertLessEqual(high[2], 0.25)
                self.assertAlmostEqual(low[1], 0.0, places=3)


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
        heavy = [(n, tris(kit_shapes.build(r["shapes"])), r.get("budget", kit_shapes.PIECE_TRIS)) for n, r in kit_recipes.PIECES.items() if r.get("shapes")]
        self.assertEqual([h for h in heavy if h[1] > h[2]], [])

    def test_the_kit_is_modelled(self):
        # Kit v1: the pieces that read as boxes are modelled (openings, columns
        # and arches, round things, foliage, the house fronts).
        wanted = ["wall_ashlar_door", "wall_plaster_window", "wall_ashlar_arch", "wall_ashlar_tall_lancet", "column", "arch_span_3",
                  "barrel", "well", "candle_stand", "cart", "tree", "bush", "house_a", "banner", "buttress", "chandelier", "weeds"]
        self.assertEqual([n for n in wanted if not kit_recipes.PIECES[n].get("shapes")], [])

    def test_colliders_stay_the_blocks(self):
        # Modelling a piece never moves what men walk on and bump into.
        door = kit_recipes.PIECES["wall_ashlar_door"]
        self.assertTrue(door["cols"])
        self.assertTrue(all(c[6] == "stone" for c in door["cols"]))


if __name__ == "__main__":
    unittest.main()
