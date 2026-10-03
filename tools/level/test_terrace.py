"""The old town's terraces and its ground below (plan B1a, Task 7;
kit_terrace): retaining walls hung from, stair-lanes walked, the arch over a
lane, the stream's vault and the sewer, cisterns, hatches down to them.

    python3 tools/level/test_terrace.py
"""

import os
import sys
import unittest

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import geo  # noqa: E402
import kit_recipes  # noqa: E402
import kit_shapes  # noqa: E402
import kit_terrace  # noqa: E402
import rules  # noqa: E402
from test_rules import marker, piece  # noqa: E402

TEST_FLOORS = []


def floor(name, x0, z0, x1, z1, y):
    """A test floor whose top is y over x0..x1 by z0..z1."""
    kit_recipes.piece(name, "floor", "cobble", "stone", [kit_recipes.box((x0 + x1) / 2.0, y - 0.1, (z0 + z1) / 2.0, x1 - x0, 0.2, z1 - z0,
                                                                         "cobble")])
    TEST_FLOORS.append(name)
    return piece(name, name, (0, 0, 0))


def walked(pieces, route, extra=()):
    points = [marker("way_%d" % (i + 1), "route_check", p[:3], {"route": "way", "order": i + 1, "move": p[3]}) for i, p in enumerate(route)]
    return rules.problems({"level": "fixture", "pieces": pieces, "markers": points + list(extra)})


def hit(name, origin, direction):
    """The nearest of the piece's colliders along a ray (the piece at the
    origin), or None."""
    boxes = geo.piece_boxes(kit_recipes.PIECES[name], [0.0, 0.0, 0.0], geo.IDENTITY)
    hits = [t for t in (b.ray(origin, direction) for b in boxes) if t is not None]
    return min(hits) if hits else None


def _tri(origin, direction, a, b, c):
    """Where the ray meets the triangle abc (its distance), or None."""
    e1 = [b[i] - a[i] for i in range(3)]
    e2 = [c[i] - a[i] for i in range(3)]
    p = [direction[1] * e2[2] - direction[2] * e2[1], direction[2] * e2[0] - direction[0] * e2[2], direction[0] * e2[1] - direction[1] * e2[0]]
    det = sum(e1[i] * p[i] for i in range(3))

    if abs(det) < 1e-9:
        return None

    t0 = [origin[i] - a[i] for i in range(3)]
    u = sum(t0[i] * p[i] for i in range(3)) / det
    q = [t0[1] * e1[2] - t0[2] * e1[1], t0[2] * e1[0] - t0[0] * e1[2], t0[0] * e1[1] - t0[1] * e1[0]]
    v = sum(direction[i] * q[i] for i in range(3)) / det
    t = sum(e2[i] * q[i] for i in range(3)) / det
    return t if u >= 0.0 and v >= 0.0 and u + v <= 1.0 and t > 0.0 else None


def drawn(name, origin, direction, reach=100.0):
    """Whether anything drawn of the piece (at the origin) crosses the ray
    within reach: what the eye meets, not what stops a man."""
    built = kit_shapes.build(kit_recipes.PIECES[name]["shapes"])
    v = built["verts"]

    for face in built["faces"]:
        ring = face[0]

        for i in range(1, len(ring) - 1):
            t = _tri(origin, direction, v[ring[0]], v[ring[i]], v[ring[i + 1]])

            if t is not None and t <= reach:
                return True

    return False


class Terrace(unittest.TestCase):
    def tearDown(self):
        for name in TEST_FLOORS:
            kit_recipes.PIECES.pop(name, None)

        TEST_FLOORS.clear()

    def test_a_stair_lane_walks(self):
        name = kit_terrace.stair_lane(1.5, 24)
        recipe = kit_recipes.PIECES[name]
        head = recipe["head"]
        pieces = [piece("lane", name, (0, 0, 0)), floor("foot_floor", -2.0, -3.0, 2.0, 0.0, 0.0),
                  floor("head_floor", -2.0, head[2], 2.0, head[2] + 3.0, head[1])]
        self.assertEqual(walked(pieces, recipe["tour"]), [])
        self.assertAlmostEqual(head[1], 24 * 0.18, places=6)

    def test_flights_are_6_to_12_steps_between_landings(self):
        recipe = kit_recipes.PIECES[kit_terrace.stair_lane(2.5, 30)]
        self.assertTrue(all(6 <= n <= 12 for n in recipe["flights"]), recipe["flights"])
        self.assertEqual(sum(recipe["flights"]), 30)

    def test_risers_are_0_18(self):
        recipe = kit_recipes.PIECES[kit_terrace.stair_lane(1.2, 10)]
        tops = sorted({round(c[1] + c[4] / 2.0, 4) for c in recipe["cols"]})
        self.assertAlmostEqual(tops[0], 0.18, places=4)
        self.assertTrue(all(abs((b - a) - 0.18) < 1e-4 for a, b in zip(tops, tops[1:]) if b - a > 1e-3))

    def test_a_retaining_wall_under_3_9_is_hung(self):
        name = kit_terrace.retaining(10.0, 3.5)
        pieces = [piece("wall", name, (0, 0, 0)), floor("low", -5.0, 0.0, 5.0, 4.0, 0.0), floor("high", -5.0, -6.0, 5.0, -0.5, 3.5)]
        self.assertEqual(walked(pieces, [[0.0, 0.0, 0.8, "walk"], [0.0, 3.5, -1.0, "hang"]]), [])
        # (Over 3.9 m it is no hang.)
        tall = kit_terrace.retaining(10.0, 4.5)
        pieces = [piece("wall", tall, (0, 0, 0)), floor("low", -5.0, 0.0, 5.0, 4.0, 0.0), floor("high2", -5.0, -6.0, 5.0, -0.5, 4.5)]
        self.assertNotEqual(walked(pieces, [[0.0, 0.0, 0.8, "walk"], [0.0, 4.5, -1.0, "hang"]]), [])

    def test_a_retaining_wall_with_its_parapet(self):
        name = kit_terrace.retaining(10.0, 20.0, parapet=True)
        self.assertIsNotNone(hit(name, [0.0, 20.5, 1.0], [0.0, 0.0, -1.0]))
        self.assertIsNone(hit(name, [0.0, 21.2, 1.0], [0.0, 0.0, -1.0]))

    def test_the_sewer_is_2_2_by_3_1(self):
        name = kit_terrace.vault(2.2, 3.1, 20.0)
        self.assertAlmostEqual(hit(name, [0.0, 1.0, 0.0], [1.0, 0.0, 0.0]), 1.1, places=2)
        self.assertAlmostEqual(hit(name, [0.0, 0.05, 0.0], [0.0, 1.0, 0.0]) + 0.05, 3.1, delta=0.06)
        pieces = [piece("sewer", name, (0, 0, 0))]
        self.assertEqual(walked(pieces, [[0.0, 0.0, -9.0, "walk"], [0.0, 0.0, 9.0, "walk"]]), [])

    def test_the_stream_runs_beside_its_ledge(self):
        name = kit_terrace.vault(3.0, 3.2, 20.0, ledge=0.8)
        recipe = kit_recipes.PIECES[name]
        lx = recipe["ledge"]
        pieces = [piece("stream", name, (0, 0, 0))]
        self.assertEqual(walked(pieces, [[lx, 0.0, -9.0, "walk"], [lx, 0.0, 9.0, "walk"]]), [])
        # (Beside the ledge, the channel: lower, its water the layout's.)
        self.assertGreater(hit(name, [0.0, 0.5, 0.0], [0.0, -1.0, 0.0]), 0.6)

    def test_an_arch_over_clears_2_2(self):
        name = kit_terrace.arch_over(2.5)
        self.assertIsNone(hit(name, [0.0, 2.1, 6.0], [0.0, 0.0, -1.0]))
        self.assertIsNotNone(hit(name, [0.0, 2.6, 6.0], [0.0, 0.0, -1.0]))

    def test_a_hatch_climbs_down(self):
        name = kit_terrace.grate_hatch(4.0)
        climb = kit_recipes.PIECES[name]["climbs"][0]
        self.assertLessEqual(climb[1] - climb[4] / 2.0, -4.0 + 0.05)
        self.assertGreaterEqual(climb[1] + climb[4] / 2.0, 0.5)

    def test_a_hatch_has_its_collar_and_an_open_mouth(self):
        # (The ground leaves a hole of whole cells round it: its collar
        # paves them, a little proud; nothing drawn or solid across the
        # shaft's mouth, its grate lying aside.)
        name = kit_terrace.grate_hatch(2.0, collar=5.0)
        self.assertAlmostEqual(1.0 - hit(name, [2.3, 1.0, 2.3], [0.0, -1.0, 0.0]), kit_terrace.COLLAR_PROUD, places=3)
        self.assertIsNone(hit(name, [2.7, 1.0, 0.0], [0.0, -1.0, 0.0]))
        self.assertIsNone(hit(name, [0.0, 1.0, 0.0], [0.0, -1.0, 0.0]))
        self.assertFalse(drawn(name, [0.0, 1.0, 0.0], [0.0, -1.0, 0.0], 3.5))
        # (Its ladder drawn on a wall of its shaft.)
        self.assertTrue(drawn(name, [0.0, -1.0, 0.0], [1.0, 0.0, 0.0], kit_terrace.SHAFT / 2.0))

    def test_a_hatch_chamber_opens_under_its_shaft(self):
        name = kit_terrace.hatch_chamber(2.2, 3.1, 2.0)
        recipe = kit_recipes.PIECES[name]
        self.assertIsNone(hit(name, [0.0, 1.0, 0.0], [0.0, 1.0, 0.0]))
        self.assertIsNone(hit(name, [1.0, 1.0, 0.0], [0.0, 1.0, 0.0]))
        self.assertAlmostEqual(hit(name, [-0.6, 1.0, 0.0], [0.0, 1.0, 0.0]) + 1.0, 3.1, delta=0.01)
        self.assertAlmostEqual(hit(name, [0.0, 1.0, 0.0], [1.0, 0.0, 0.0]), 1.1, delta=0.01)
        self.assertEqual(walked([piece("chamber", name, (0, 0, 0))], [[0.0, 0.0, -0.9, "walk"], [0.0, 0.0, 0.9, "walk"]]), [])
        climb = recipe["climbs"][0]
        self.assertLessEqual(climb[1] - climb[4] / 2.0, 0.05)
        self.assertGreaterEqual(climb[1] + climb[4] / 2.0, recipe["roof"])
        # (Its ends close round the vault's barrel: open on its arch, shut
        # in the corners over it.)
        self.assertFalse(drawn(name, [0.0, 1.5, 3.0], [0.0, 0.0, -1.0], 2.5))
        self.assertTrue(drawn(name, [1.0, 2.95, 3.0], [0.0, 0.0, -1.0], 2.5))

    def test_a_vault_end_shuts_it(self):
        name = kit_terrace.vault_end(2.2, 3.1)
        self.assertIsNotNone(hit(name, [0.0, 1.5, 1.0], [0.0, 0.0, -1.0]))
        self.assertTrue(drawn(name, [1.0, 2.95, 1.0], [0.0, 0.0, -1.0], 2.0))

    def test_a_scaffold_climbs_to_the_eaves(self):
        # (A front still being rebuilt: decks a lift apart, ladders between
        # them, the top deck under the eaves; off the wall, clear of its
        # balconies.)
        name = kit_terrace.scaffold(14.2, 4.0)
        recipe = kit_recipes.PIECES[name]
        self.assertTrue(14.2 - 0.6 <= recipe["top"] <= 14.2 - 0.1, recipe["top"])
        ladders = [dict(marker("climb_%d" % i, "ladder", c[0:3], size=list(c[3:6])), basis=geo.rotation(c[6])) for i, c in enumerate(recipe["climbs"])]
        pieces = [piece("scaffold", name, (0, 0, 0)), floor("street", -4.0, 0.0, 4.0, 4.0, 0.0)]
        self.assertEqual(walked(pieces, recipe["tour"], ladders), [])
        self.assertIsNone(hit(name, [0.0, 4.2, 0.55], [1.0, 0.0, 0.0]))

        # (Nothing across a ladder: up its middle from its foot to the deck it reaches.)
        for c in recipe["climbs"]:
            foot = c[1] - c[4] / 2.0
            t = hit(name, [c[0], foot + 0.3, c[2]], [0.0, 1.0, 0.0])
            self.assertTrue(t is None or t > kit_terrace.LIFT - 0.3, c)

    def test_pieces_are_named_by_their_measures(self):
        self.assertEqual(kit_terrace.stair_lane(1.5, 24), kit_terrace.stair_lane(1.5, 24))
        self.assertNotEqual(kit_terrace.retaining(10.0, 3.5), kit_terrace.retaining(10.0, 3.0))


if __name__ == "__main__":
    unittest.main()
