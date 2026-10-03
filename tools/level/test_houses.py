"""The old town's four house families (plan B1a, Tasks 3-6): each generated
from its parameters on kit_town's grammar, to the references' measures.

    python3 tools/level/test_houses.py
"""

import os
import sys
import unittest

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import kit_pombal  # noqa: E402
import kit_porto  # noqa: E402
import kit_recipes  # noqa: E402
import kit_town  # noqa: E402
import rules  # noqa: E402
from test_kits import tris  # noqa: E402
from test_rules import marker, piece  # noqa: E402
from test_town import clear, stood_on  # noqa: E402

TEST = "test_house"


def openings(design, storey, face="front"):
    return [o for o in design["openings"] if o[0] == storey and o[1] == face]


def first_hit(cols, origin, direction):
    """The distance to the nearest collider along a ray, or None."""
    from test_town import boxes
    hits = [t for t in (b.ray(origin, direction) for b in boxes(cols)) if t is not None]
    return min(hits) if hits else None


def toured(design, route):
    """The design placed at the origin on a street (a floor in front of it
    to z +4), and `route` ([x, y, z, move], ...) as route checks: the
    rules' problems."""
    kit_town.register(TEST, "town", "render_ochre", design)
    kit_recipes.piece("test_street", "floor", "cobble", "stone", [kit_recipes.box(0.0, -0.1, 2.0, 12.0, 0.2, 4.0, "cobble")])
    points = [marker("tour_%d" % (i + 1), "route_check", p[:3], {"route": "tour", "order": i + 1, "move": p[3]}) for i, p in enumerate(route)]
    return rules.problems({"level": "fixture", "pieces": [piece("house", TEST, (0, 0, 0)), piece("street", "test_street", (0, 0, 0))],
                           "markers": points})


class Porto(unittest.TestCase):
    def tearDown(self):
        for name in (TEST, "test_street"):
            kit_recipes.PIECES.pop(name, None)

    def test_bays_follow_the_width(self):
        for width, bays in ((3.0, 1), (4.5, 2), (6.0, 3), (7.5, 3)):
            self.assertEqual(len(openings(kit_porto.design(width, 12.0, 4), 2)), bays, width)

    def test_storeys_are_shop_then_3_2(self):
        for storeys in (3, 4, 5):
            self.assertAlmostEqual(kit_porto.design(4.5, 12.0, storeys)["eaves"], 3.8 + (storeys - 1) * 3.2)

    def test_a_jetty_oversails_0_4(self):
        cols = kit_porto.design(4.5, 12.0, 4, "jetty")["cols"]
        ground = first_hit(cols, [0.0, 1.0, 3.0], [0.0, 0.0, -1.0])
        upper = first_hit(cols, [0.0, 6.0, 3.0], [0.0, 0.0, -1.0])
        self.assertAlmostEqual(ground - upper, 0.4, places=2)

    def test_the_first_balcony_is_hung_from_the_street(self):
        design = kit_porto.design(4.5, 12.0, 4)
        x, top, _width, depth = design["balconies"][0]
        self.assertLessEqual(top, rules.HANG)
        # (Its slab is a collider to hang from.)
        self.assertIsNotNone(first_hit(design["cols"], [x, top + 0.3, depth / 2.0], [0.0, -1.0, 0.0]))

    def test_an_enterable_house_has_its_door_and_rooms(self):
        for depth in (10.0, 12.0, 16.0):
            for rooms in (1, 2, 3):
                design = kit_porto.design(4.5, depth, 4, enterable=True, rooms=rooms)
                self.assertEqual(len(design["doors"]), 1)
                door = design["doors"][0]
                self.assertTrue(clear(design["cols"], [door[0], 1.0, 2.0], [door[0], 1.0, -1.5]))
                self.assertEqual(len(design["rooms_at"]), rooms)
                self.assertEqual(toured(design, design["tour"]), [], (depth, rooms))
                kit_recipes.PIECES.pop(TEST, None)

    def test_an_honest_house_is_shut(self):
        design = kit_porto.design(6.0, 12.0, 4)
        self.assertEqual(design["doors"], [])
        self.assertFalse(any(o[6] in kit_town.LIVE for o in design["openings"]))
        self.assertFalse(clear(design["cols"], [0.0, 1.0, 2.0], [0.0, 1.0, -1.5]))

    def test_a_two_level_house_has_a_door_a_storey_up(self):
        design = kit_porto.design(4.5, 12.0, 3, "two_level")
        back = [d for d in design["doors"] if abs(d[3] - 180.0) < 1e-6]
        self.assertEqual(len(back), 1)
        self.assertAlmostEqual(back[0][1], 3.8)
        self.assertTrue(clear(design["cols"], [back[0][0], 4.8, -14.0], [back[0][0], 4.8, -10.0]))
        self.assertEqual(toured(design, design["tour"] + design["out_back"]), [])

    def test_every_quirk_builds_and_its_roof_is_stood_on(self):
        for quirk in kit_porto.QUIRKS:
            design = kit_porto.design(4.5, 12.0, 4, quirk)
            self.assertEqual(stood_on(design["shapes"], design["cols"]), [], quirk)

    def test_the_slot_house_is_1_5_wide(self):
        self.assertAlmostEqual(kit_porto.design(4.5, 10.0, 3, "slot")["size"][0], 1.5)

    def test_porto_budget(self):
        for width in (3.0, 4.5, 6.0, 7.5):
            for storeys in (3, 5):
                for quirk in kit_porto.QUIRKS:
                    for enterable in (False, True):
                        design = kit_porto.design(width, 15.0, storeys, quirk, enterable, 3 if enterable else 0)
                        kit_town.register(TEST, "town", "render_ochre", design)
                        self.assertLessEqual(tris(kit_recipes.PIECES[TEST]), design["budget"], (width, storeys, quirk, enterable))


def roof_pitches(shapes):
    """The pitches (degrees, rounded) of the faces drawn in a roof slot."""
    import math
    import kit_shapes
    built = kit_shapes.build(shapes)
    out = set()

    for face in built["faces"]:
        if face[1].startswith("roof"):
            n = kit_shapes._normal([built["verts"][i] for i in face[0]])
            length = sum(c * c for c in n) ** 0.5

            if length > 1e-9 and n[1] > 0.0:
                out.add(round(math.degrees(math.acos(n[1] / length))))

    return out


class Pombaline(unittest.TestCase):
    def tearDown(self):
        for name in (TEST, "test_street"):
            kit_recipes.PIECES.pop(name, None)

    def test_four_bays_are_12_7_wide(self):
        self.assertAlmostEqual(kit_pombal.facade_width(4), 12.65)
        self.assertAlmostEqual(kit_pombal.design(4, 12.0)["size"][0], 13.0)
        # (Each opening 1.35 wide, 2.70 apart.)
        xs = sorted(o[2] for o in openings(kit_pombal.design(4, 12.0), 2))
        self.assertEqual([round(b - a, 3) for a, b in zip(xs, xs[1:])], [2.7, 2.7, 2.7])

    def test_a_fire_wall_stands_0_6_over_the_roof(self):
        design = kit_pombal.design(4, 12.0, fire_walls=(True, False))
        x = -design["size"][0] / 2.0 + 0.25
        roof_at = lambda z: kit_pombal.roof_at(design, z)  # noqa: E731

        for z in (-6.0, -2.5, -9.5):
            top = 30.0 - first_hit(design["cols"], [x, 30.0, z], [0.0, -1.0, 0.0])
            self.assertAlmostEqual(top, roof_at(z) + 0.6, delta=0.12)

        # (None on the other side: the roof's own slope there.)
        top = 30.0 - first_hit(design["cols"], [-x, 30.0, -6.0], [0.0, -1.0, 0.0])
        self.assertLess(top, roof_at(-6.0) + 0.35)

    def test_sacadas_on_the_first_floor_only(self):
        design = kit_pombal.design(4, 12.0)
        self.assertTrue(all(abs(o[5] - 2.9) < 1e-6 for o in openings(design, 1)))
        self.assertEqual(len(design["balconies"]), 4)
        self.assertTrue(all(abs(b[1] - 4.0) < 1e-6 for b in design["balconies"]))
        self.assertTrue(all(o[5] <= 2.2 + 1e-6 for s in (2, 3) for o in openings(design, s)))

    def test_a_corner_building_has_four_pitches_and_two_fronts(self):
        design = kit_pombal.design(4, 12.0, kind="corner")
        self.assertEqual(design["roof"], "four")
        self.assertTrue(openings(design, 2, "side"))
        self.assertEqual(stood_on(design["shapes"], design["cols"]), [])

    def test_a_mansard_is_65_then_25(self):
        design = kit_pombal.design(4, 12.0, quirk="mansard")
        # (Its steep slopes drawn at 65; its upper roof's tiles are round, so
        # its 25 is read from the slabs under them.)
        self.assertIn(65, roof_pitches(design["shapes"]))
        self.assertIn(25, {round(abs(c[8])) for c in design["cols"]})

    def test_an_enterable_building_is_toured(self):
        for rooms in (1, 2, 3):
            design = kit_pombal.design(4, 12.0, enterable=True, rooms=rooms)
            self.assertEqual(len(design["rooms_at"]), rooms)
            self.assertEqual(toured(design, design["tour"]), [], rooms)
            kit_recipes.PIECES.pop(TEST, None)

    def test_every_kind_is_stood_on(self):
        for kind in kit_pombal.KINDS:
            for quirk in kit_pombal.QUIRKS:
                design = kit_pombal.design(3 if kind == "hill" else 4, 12.0, 3 if kind in ("hill", "row") else 4, kind, quirk=quirk)
                self.assertEqual(stood_on(design["shapes"], design["cols"]), [], (kind, quirk))

    def test_pombaline_budget(self):
        for bays in (3, 4, 6):
            for kind in kit_pombal.KINDS:
                for enterable in (False, True):
                    design = kit_pombal.design(bays, 12.0, 4, kind, enterable=enterable, rooms=3 if enterable else 0)
                    kit_town.register(TEST, "town", "azulejo_blue", design)
                    self.assertLessEqual(tris(kit_recipes.PIECES[TEST]), design["budget"], (bays, kind, enterable))


if __name__ == "__main__":
    unittest.main()
