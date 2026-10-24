"""The old town's terraces and its ground below (plan B1a, Task 7;
kit_terrace): retaining walls hung from, stair-lanes walked, the arch over a
lane, the stream's vault and the sewer, cisterns, hatches down to them.

    python3 tools/level/test_terrace.py
"""

import math
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

    def test_a_retaining_wall_behind_a_stair_has_its_coping_flush(self):
        # (Where a stair stands against it: no lip over the stair's side,
        # its coping's face on the wall's.)
        name = kit_terrace.retaining(10.0, 7.0, flush=True)
        self.assertNotEqual(name, kit_terrace.retaining(10.0, 7.0))
        self.assertAlmostEqual(hit(name, [0.0, 6.9, 1.0], [0.0, 0.0, -1.0]), 1.0, places=3)
        self.assertAlmostEqual(hit(kit_terrace.retaining(10.0, 7.0), [0.0, 6.9, 1.0], [0.0, 0.0, -1.0]), 1.0 - kit_terrace.COPING[1], places=3)

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

    def test_a_hatchs_ladder_takes_a_man_down(self):
        # (A man a metre across goes down the shaft with room round him; its
        # climb faces the ladder drawn on its +x wall (a climb's normal is
        # its yaw's +z), as does the chamber's under it; it reaches out over
        # the street on the far side, where he takes hold of it.)
        self.assertGreaterEqual(kit_terrace.SHAFT, 1.5)

        for name in (kit_terrace.grate_hatch(4.0), kit_terrace.hatch_chamber(2.2, 3.1, 2.0)):
            climb = kit_recipes.PIECES[name]["climbs"][0]
            self.assertLess(math.sin(math.radians(climb[6])), -0.99, name)

        climb = kit_recipes.PIECES[kit_terrace.grate_hatch(4.0)]["climbs"][0]
        self.assertLessEqual(climb[0] - climb[5] / 2.0, -kit_terrace.SHAFT / 2.0 - 0.4)
        self.assertGreaterEqual(climb[0] + climb[5] / 2.0, kit_terrace.SHAFT / 2.0 - 0.05)
        # (Its wall the ladder's: the climb's plane `plane_back` behind its
        # box's middle, against its normal, where the climber is held to.)
        props = climb[8] if len(climb) > 8 else {}
        self.assertAlmostEqual(climb[0] - math.sin(math.radians(climb[6])) * props.get("plane_back", 0.0), kit_terrace.SHAFT / 2.0, places=3)

    def test_a_hatch_has_its_collar_and_an_open_mouth(self):
        # (The ground leaves a hole of whole cells round it: its collar
        # paves them, a little proud; nothing drawn or solid across the
        # shaft's mouth, its grate lying aside.)
        name = kit_terrace.grate_hatch(2.0, collar=5.0)
        self.assertAlmostEqual(1.0 - hit(name, [2.3, 1.0, 2.3], [0.0, -1.0, 0.0]), kit_terrace.COLLAR_PROUD, places=3)
        self.assertIsNone(hit(name, [2.7, 1.0, 0.0], [0.0, -1.0, 0.0]))
        self.assertIsNone(hit(name, [0.0, 1.0, 0.0], [0.0, -1.0, 0.0]))
        self.assertFalse(drawn(name, [0.0, 1.0, 0.0], [0.0, -1.0, 0.0], 3.5))
        # (Its ladder drawn on a wall of its shaft: a rail short of the wall.)
        self.assertTrue(drawn(name, [0.0, -1.0, 0.22], [1.0, 0.0, 0.0], kit_terrace.SHAFT / 2.0 - 0.03))

    def test_a_hatchs_grate_is_iron_bars_lying_aside(self):
        # (Its grate dragged off the mouth onto the paving on its -z side:
        # a square of iron SHAFT across, a frame and bars both ways, gaps
        # between them; no painted grille stretched over a card.)
        name = kit_terrace.grate_hatch(2.0, collar=5.0)
        self.assertFalse(any(sh.get("slot") == "window_grille" for sh in kit_recipes.PIECES[name]["shapes"]))
        near = kit_terrace.SHAFT / 2.0 + 0.2 + kit_terrace.GRATE_GAP
        mid = -(near + kit_terrace.SHAFT / 2.0)
        edge = kit_terrace.SHAFT / 2.0 - 0.02

        for x, z in ((edge, mid), (-edge, mid), (0.0, -near - 0.02), (0.0, -near - kit_terrace.SHAFT + 0.02), (0.0, mid)):
            self.assertTrue(drawn(name, [x, 1.0, z], [0.0, -1.0, 0.0], 1.1), (x, z))

        self.assertFalse(drawn(name, [0.13, 1.0, mid + 0.13], [0.0, -1.0, 0.0], 0.99), "no gap between its bars")
        self.assertLess(1.0 - hit(name, [0.0, 1.0, mid], [0.0, -1.0, 0.0]), 0.08, "it lies flat, not stood up")

    def test_a_hatchs_collar_fills_a_cell_longer_one_way(self):
        # (A ground's cells are its extent over a whole number of them: a
        # collar (across x, along z) paves one exactly, to its edges.)
        name = kit_terrace.grate_hatch(2.0, collar=(2.519, 2.5))
        self.assertIsNotNone(hit(name, [1.25, 1.0, 1.0], [0.0, -1.0, 0.0]))
        self.assertIsNone(hit(name, [1.27, 1.0, 1.0], [0.0, -1.0, 0.0]))
        self.assertIsNotNone(hit(name, [0.0, 1.0, 1.24], [0.0, -1.0, 0.0]))
        self.assertIsNone(hit(name, [0.0, 1.0, 1.26], [0.0, -1.0, 0.0]))
        self.assertNotEqual(name, kit_terrace.grate_hatch(2.0, collar=2.5))

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

    def test_a_scaffolds_climber_goes_up_through_its_decks(self):
        # (The controller holds a climber his radius and its gap (0.58 m) in
        # front of a ladder's plane (its normal the climb's yaw's +z), its
        # wall or, open, the plane_back behind its box's middle: there, all
        # the way up, his body clears the deck he climbs through; what its
        # ray behind him meets first is the ladder; at its top, ahead of him,
        # the deck a man stands on, a mantle up.)
        name = kit_terrace.scaffold(14.2, 4.0)
        boxes = geo.piece_boxes(kit_recipes.PIECES[name], [0.0, 0.0, 0.0], geo.IDENTITY)

        for c in kit_recipes.PIECES[name]["climbs"]:
            props = c[8] if len(c) > 8 else {}
            normal = [math.sin(math.radians(c[6])), 0.0, math.cos(math.radians(c[6]))]
            plane = c[2] - normal[2] * props.get("plane_back", 0.0)
            held = plane + normal[2] * 0.58
            foot = c[1] - c[4] / 2.0
            deck = foot + kit_terrace.LIFT

            # (Taken hold of a little to one side, as a man does: the climb
            # keeps him there.)
            for dx in (-0.35, 0.0, 0.35):
                for k in range(9):
                    y = foot + 0.05 + (kit_terrace.LIFT - 0.1) * k / 8.0
                    self.assertTrue(rules._fits(boxes, [c[0] + dx, y, held]), (c, dx, y))

            behind = hit(name, [c[0], foot + 1.0, held], [0.0, 0.0, -normal[2]])
            self.assertIsNotNone(behind)
            self.assertAlmostEqual(behind, 0.58, delta=0.06)
            # (The deck ahead: a man stands on it 0.55 past its edge.)
            landing = [c[0], deck, plane - normal[2] * 0.55]
            self.assertAlmostEqual(hit(name, [landing[0], deck + 0.5, landing[2]], [0.0, -1.0, 0.0]) or 99.0, 0.5, places=2)
            self.assertTrue(rules._fits(boxes, landing), c)

    def test_a_scaffold_climbs_to_the_eaves(self):
        # (A front still being rebuilt: decks a lift apart, ladders between
        # them, the top deck under the eaves; off the wall, clear of its
        # balconies.)
        name = kit_terrace.scaffold(14.2, 4.0)
        recipe = kit_recipes.PIECES[name]
        self.assertTrue(14.2 - 0.6 <= recipe["top"] <= 14.2 - 0.1, recipe["top"])
        ladders = [dict(marker("climb_%d" % i, "ladder", c[0:3], size=list(c[3:6])), basis=geo.rotation(c[6])) for i, c in enumerate(recipe["climbs"])]
        pieces = [piece("scaffold", name, (0, 0, 0)), floor("street", -4.0, 0.0, 4.0, 6.0, 0.0)]
        self.assertEqual(walked(pieces, recipe["tour"], ladders), [])
        self.assertIsNone(hit(name, [0.0, 4.2, 0.55], [1.0, 0.0, 0.0]))

        # (Nothing across a ladder: up its middle from its foot to the deck it reaches.)
        for c in recipe["climbs"]:
            foot = c[1] - c[4] / 2.0
            t = hit(name, [c[0], foot + 0.3, c[2]], [0.0, 1.0, 0.0])
            self.assertTrue(t is None or t > kit_terrace.LIFT - 0.3, c)

    def test_a_stair_lane_meets_any_step_exactly(self):
        # (Its riser divides the step: its head level with the terrace above,
        # no lip.)
        for rise in (4.23, 4.5, 5.0, 8.27):
            steps = int(math.ceil(rise / kit_terrace.RISER - 1e-9))
            recipe = kit_recipes.PIECES[kit_terrace.stair_lane(2.5, steps, rise / steps)]
            self.assertAlmostEqual(recipe["head"][1], rise, places=4)
            self.assertLessEqual(rise / steps, kit_terrace.RISER + 1e-9)

    def test_a_parapet_guards_a_drop(self):
        name = kit_terrace.parapet(6.0)
        self.assertIsNotNone(hit(name, [0.0, 0.6, 1.0], [0.0, 0.0, -1.0]))
        self.assertIsNone(hit(name, [0.0, kit_terrace.PARAPET[0] + 0.12, 1.0], [0.0, 0.0, -1.0]))

    def test_a_footing_fills_under_a_wall(self):
        name = kit_terrace.footing(6.0, 5.5, 2.4)
        self.assertAlmostEqual(hit(name, [0.0, 7.0, 0.0], [0.0, -1.0, 0.0]), 1.5, places=3)
        self.assertIsNotNone(hit(name, [0.0, 0.1, 2.0], [0.0, 0.0, -1.0]))

    def test_a_rampart_stands_over_its_rim(self):
        name = kit_terrace.rampart(10.0, 4.0, 6.0)
        recipe = kit_recipes.PIECES[name]
        self.assertAlmostEqual(10.0 - hit(name, [0.0, 10.0, 0.0], [0.0, -1.0, 0.0]), 4.0, delta=0.12)
        self.assertIsNotNone(hit(name, [0.0, -5.0, 3.0], [0.0, 0.0, -1.0]))
        self.assertGreaterEqual(recipe["size"][1], 10.0)

    def test_a_yard_front_has_its_gate(self):
        name = kit_terrace.yard_front(5.0)
        self.assertIsNotNone(hit(name, [-2.0, 1.0, 1.0], [0.0, 0.0, -1.0]))
        gate = [sh for sh in kit_recipes.PIECES[name]["shapes"] if sh.get("slot") == "door_1"]
        self.assertTrue(gate)

    def test_a_vaults_door_opens_its_side(self):
        # (The stream's vault where a cellar opens onto it: a doorway in its
        # +x wall at its middle, the wall whole either side.)
        name = kit_terrace.vault(3.0, 2.4, 6.0, ledge=0.8, door=1.4)
        self.assertIsNone(hit(name, [0.5, 1.0, 0.0], [1.0, 0.0, 0.0]))
        self.assertIsNotNone(hit(name, [0.5, 1.0, 2.0], [1.0, 0.0, 0.0]))
        self.assertIsNotNone(hit(name, [0.5, 1.0, -2.0], [1.0, 0.0, 0.0]))
        self.assertIsNotNone(hit(name, [0.5, 2.3, 0.0], [1.0, 0.0, 0.0]))

    def test_a_cascade_joins_two_levels_of_a_stream(self):
        # (Its foot level with the lower tunnel, open to it at -z; its top
        # level with the upper, open to it at +z... up its ladder.)
        name = kit_terrace.cascade(3.0, 2.4, 4.5)
        recipe = kit_recipes.PIECES[name]
        lx = recipe["ledge"]
        tour = recipe["tour"]
        pieces = [piece("cascade", name, (0, 0, 0)), floor("low", lx - 1.0, -4.0, lx + 1.0, -1.6, 0.0),
                  floor("high", lx - 1.0, 1.6, lx + 1.0, 4.0, 4.5)]
        ladders = [dict(marker("climb_%d" % i, "ladder", c[0:3], size=list(c[3:6])), basis=geo.rotation(c[6])) for i, c in enumerate(recipe["climbs"])]
        self.assertEqual(walked(pieces, tour, ladders), [])
        self.assertAlmostEqual(tour[0][1], 0.0)
        self.assertAlmostEqual(tour[-1][1], 4.5)

    def test_wall_steps_climb_their_rise_over_their_run(self):
        name = kit_terrace.wall_steps(11.8, 19.7, 1.5)
        recipe = kit_recipes.PIECES[name]
        self.assertAlmostEqual(recipe["head"][1], 11.8, places=3)
        self.assertAlmostEqual(recipe["head"][2], 19.7, places=3)
        pieces = [piece("steps", name, (0, 0, 0)), floor("foot", -1.0, -2.0, 1.0, 0.0, 0.0), floor("top", -1.0, 19.7, 1.0, 22.0, 11.8)]
        self.assertEqual(walked(pieces, recipe["tour"]), [])

    def test_a_wall_stairs_parapet_stands_proud_of_its_steps(self):
        # (Its raking parapet and its landing's rail a little proud of the
        # steps' open side: no two faces on one plane fighting there.)
        width = 1.6
        name = kit_terrace.wall_steps(7.0, 12.32, width)
        shapes = kit_recipes.PIECES[name]["shapes"]
        steps = [sh for sh in shapes if sh.get("slot") == "stair_stone"]
        rails = [sh for sh in shapes if sh.get("slot") == "ashlar_weathered" and sh["centre"][0] < 0.0]
        self.assertTrue(steps and len(rails) == 2)
        side = min(sh["centre"][0] - sh["size"][0] / 2.0 for sh in steps)

        for sh in rails:
            self.assertLessEqual(sh["centre"][0] - sh["size"][0] / 2.0, side - 0.005, sh["centre"])

    def test_a_stair_tower_climbs_its_cliff(self):
        # (Its foot door on the street, its top door onto the terrace at
        # the cliff's top, a switchback up inside walked from one to the
        # other; roofed, its walls whole.)
        name = kit_terrace.stair_tower(24.27)
        recipe = kit_recipes.PIECES[name]
        foot, top = recipe["foot"], recipe["top"]
        self.assertAlmostEqual(foot[1], 0.0)
        self.assertAlmostEqual(top[1], 24.27, places=3)
        pieces = [piece("tower", name, (0, 0, 0)), floor("street", foot[0] - 1.5, foot[2] - 1.5, foot[0] + 1.5, foot[2] + 1.5, 0.0),
                  floor("terrace", top[0] - 1.5, top[2] - 1.5, top[0] + 1.5, top[2] + 1.5, 24.27)]
        self.assertEqual(walked(pieces, recipe["tour"]), [])
        self.assertIsNotNone(hit(name, [0.0, 40.0, 0.0], [0.0, -1.0, 0.0]))
        # (Its doorways open arches, no leaf hung in them: a door swung in
        # across its 1.4 m landing shut the first flight off.)
        self.assertNotIn("doors", recipe)
        self.assertEqual(len(recipe["arches"]), 2)

        for d in recipe["arches"]:
            # (Nothing across the arch at a man's chest, through the wall.)
            sx = 1.0 if d[0] > 0.0 else -1.0
            across = hit(name, [d[0] + sx * 1.0, d[1] + 1.2, d[2]], [-sx, 0.0, 0.0])
            self.assertTrue(across is None or across > 1.6, (d, across))

    def test_ledges_climb_a_cliff_a_mantle_at_a_time(self):
        # (The thief's way up a cliff or a terrace's step: stone ledges a man
        # stands on (1.2 out from the face, 1.6 along it), each a mantle over
        # the last, the next straight ahead along the face, the last a
        # mantle onto the top; walked as the controller climbs.)
        for height in (5.0, 16.5, 21.5):
            name = kit_terrace.ledges(height)
            recipe = kit_recipes.PIECES[name]
            ys = [0.0] + [t[1] for t in recipe["tops"]] + [height]
            self.assertTrue(all(0.5 < b - a <= kit_terrace.LEDGE_RISE + 1e-6 for a, b in zip(ys, ys[1:])), ys)
            # (Each one's underside within 1.3 m of what a man stands on under
            # it: a higher overhang meets his head before his hands.)
            self.assertTrue(all(b - kit_terrace.LEDGE[2] - a <= 1.3 + 1e-6 for a, b in zip(ys, ys[1:-1])), ys)
            span = recipe["span"]
            cliff = "test_cliff_%d" % int(height * 100)
            kit_recipes.piece(cliff, "wall", "rubble_warm", "stone", [kit_recipes.box(span / 2.0, height / 2.0, -2.0, span + 6.0, height, 4.0, "rubble_warm")])
            TEST_FLOORS.append(cliff)
            pieces = [piece("ledges", name, (0, 0, 0)), piece("cliff", cliff, (0, 0, 0)), floor("street_%d" % int(height), -3.0, 0.0, span + 3.0, 5.0, 0.0)]
            self.assertEqual(walked(pieces, recipe["tour"]), [], height)
            self.assertAlmostEqual(recipe["tour"][-1][1], height, places=3)

    def test_a_drainpipe_is_climbed_to_the_eaves(self):
        # (A lead pipe up a wall's face to its eaves, drawn only (a man walks
        # by it); its climb from the street to the eaves out from the wall,
        # facing out; walked: up it and onto the roof behind its top.)
        for height in (7.0, 11.4):
            name = kit_terrace.drainpipe(height)
            recipe = kit_recipes.PIECES[name]
            climb = recipe["climbs"][0]
            self.assertLessEqual(climb[1] - climb[4] / 2.0, 0.05)
            self.assertAlmostEqual(climb[1] + climb[4] / 2.0, height, delta=0.05)
            self.assertLessEqual(climb[2] - climb[5] / 2.0, 0.02)
            self.assertGreaterEqual(climb[2] + climb[5] / 2.0, 0.5)
            self.assertAlmostEqual(climb[6], 0.0)
            self.assertTrue(drawn(name, [0.0, height / 2.0, 1.0], [0.0, 0.0, -1.0], 1.0))
            self.assertIsNone(hit(name, [0.0, height / 2.0, 1.0], [0.0, 0.0, -1.0]))
            house = "test_house_%d" % int(height * 100)
            kit_recipes.piece(house, "wall", "rubble_warm", "stone", [kit_recipes.box(0.0, height / 2.0, -3.0, 6.0, height, 6.0, "rubble_warm")])
            TEST_FLOORS.append(house)
            pieces = [piece("pipe", name, (0, 0, 0)), piece("house", house, (0, 0, 0)), floor("pipe_street_%d" % int(height), -3.0, 0.0, 3.0, 3.0, 0.0)]
            ladders = [dict(marker("climb_p_%d" % i, "ladder", c[0:3], size=list(c[3:6])), basis=geo.rotation(c[6])) for i, c in enumerate(recipe["climbs"])]
            self.assertEqual(walked(pieces, recipe["tour"], ladders), [], height)
            self.assertAlmostEqual(recipe["tour"][-1][1], height)

    def test_ivy_is_climbed_up_its_wall(self):
        # (Ivy over a wall's face: the user's Ivy0024 cut out, cards about a
        # metre (the photo's own scale, never stretched) over its width and
        # height, ragged at its top; its climb over it, facing out.)
        name = kit_terrace.ivy(2.4, 6.0)
        recipe = kit_recipes.PIECES[name]
        cards = [sh for sh in recipe["shapes"] if sh["kind"] == "card"]
        self.assertTrue(cards)
        self.assertTrue(all(sh["slot"] == "leaves" for sh in cards))
        self.assertTrue(all(0.8 <= sh["size"][0] <= 1.6 and 0.8 <= sh["size"][1] <= 1.6 for sh in cards))
        self.assertTrue(all(0.0 < sh["centre"][2] < 0.12 for sh in cards))
        climb = recipe["climbs"][0]
        self.assertGreaterEqual(climb[3], 2.0)
        self.assertAlmostEqual(climb[1] + climb[4] / 2.0, 6.0, delta=0.05)
        self.assertAlmostEqual(climb[6], 0.0)
        self.assertEqual(recipe["cols"], [])

    def test_ivy_is_ragged_not_a_rectangle(self):
        # (Its cards of many sizes, its rows reaching out unevenly either
        # side, thinning to a crown, some leaning off the wall: never a
        # crisp green panel.)
        name = kit_terrace.ivy(2.4, 6.0)
        cards = [sh for sh in kit_recipes.PIECES[name]["shapes"] if sh["kind"] == "card"]
        self.assertGreaterEqual(len({round(sh["size"][0], 2) for sh in cards}), 4)
        rows = {}

        for sh in cards:
            x, y, _z = sh["centre"]
            band = int(y // 1.0)
            lo, hi = rows.get(band, (99.0, -99.0))
            rows[band] = (min(lo, x - sh["size"][0] / 2.0), max(hi, x + sh["size"][0] / 2.0))

        lefts = [lo for lo, _hi in rows.values()]
        self.assertGreater(max(lefts) - min(lefts), 0.4, "its left side runs straight up")
        top = max(sh["centre"][1] + sh["size"][1] / 2.0 for sh in cards)
        crown = [sh for sh in cards if sh["centre"][1] > 6.0 - 1.2]
        middle = [sh for sh in cards if 2.0 < sh["centre"][1] < 3.2]
        self.assertLess(len(crown), len(middle), "no thinning crown")
        self.assertLessEqual(top, 6.0 + 0.3)
        self.assertTrue(any(abs(sh["turn"][1]) > 3.0 for sh in cards), "every card flat on the wall")

    def test_a_buttress_steps_back_up_its_cliff(self):
        # (A granite pier against a cliff's face (at z 0, out to +z), in
        # stages each shallower than the one under it, from the ground to
        # under the cliff's top; solid as drawn.)
        name = kit_terrace.buttress(23.5)
        out = [hit(name, [0.0, y, 5.0], [0.0, 0.0, -1.0]) for y in (1.0, 12.0, 21.0)]
        self.assertTrue(all(t is not None for t in out), out)
        self.assertTrue(5.0 - out[0] > 5.0 - out[1] > 5.0 - out[2] > 0.3, out)
        self.assertIsNone(hit(name, [0.0, 23.6, 5.0], [0.0, 0.0, -1.0]))
        self.assertIsNone(hit(name, [0.0, 1.0, -0.1], [0.0, 0.0, -1.0]))
        self.assertTrue(drawn(name, [0.0, 12.0, 5.0], [0.0, 0.0, -1.0]))

    def test_a_posterns_door_is_dark_and_deep(self):
        name = kit_terrace.postern(3.03, 2.4)
        recipe = kit_recipes.PIECES[name]
        self.assertTrue(any(sh.get("slot") == "pitch" for sh in recipe["shapes"]))
        self.assertIsNotNone(hit(name, [0.0, 2.8, 3.0], [0.0, 0.0, -1.0]))

    def test_a_cascade_climbs_north_too(self):
        # (Its upper level to -z: a stream running north up the terraces,
        # its ledge still on its +x side.)
        name = kit_terrace.cascade(3.0, 2.4, 8.27, ledge=1.2, up=-1.0)
        recipe = kit_recipes.PIECES[name]
        lx, tour = recipe["ledge"], recipe["tour"]
        self.assertGreater(lx, 0.0)
        pieces = [piece("cascade_n", name, (0, 0, 0)), floor("low_n", lx - 1.0, 1.6, lx + 1.0, 4.0, 0.0),
                  floor("high_n", lx - 1.0, -4.0, lx + 1.0, -1.6, 8.27)]
        ladders = [dict(marker("climb_n_%d" % i, "ladder", c[0:3], size=list(c[3:6])), basis=geo.rotation(c[6])) for i, c in enumerate(recipe["climbs"])]
        self.assertEqual(walked(pieces, tour, ladders), [])
        self.assertAlmostEqual(tour[-1][1], 8.27)
        self.assertLess(tour[-1][2], 0.0)

    def test_a_hatch_chamber_keeps_the_streams_channel(self):
        # (Under a hatch on the stream: its ledge under the shaft, the
        # channel running on through it.)
        name = kit_terrace.hatch_chamber(3.0, 2.4, 2.0, ledge=1.2)
        self.assertAlmostEqual(hit(name, [0.9, 1.0, 0.0], [0.0, -1.0, 0.0]), 1.0, places=2)
        self.assertAlmostEqual(hit(name, [-0.6, 1.0, 0.0], [0.0, -1.0, 0.0]), 1.0 + kit_terrace.CHANNEL, places=2)

    def test_a_vault_end_closes_its_channel(self):
        name = kit_terrace.vault_end(3.0, 2.4, channel=True)
        self.assertIsNotNone(hit(name, [-0.6, -0.5, 1.0], [0.0, 0.0, -1.0]))

    def test_a_tannery_has_its_vats_and_racks(self):
        # (Six vats a man walks between, hides drying on two racks, the
        # tanners' work spot.)
        name = kit_terrace.tannery()
        recipe = kit_recipes.PIECES[name]
        self.assertEqual(len(recipe["vats"]), 6)
        self.assertTrue(any(sh.get("slot") == "leather" for sh in recipe["shapes"]))
        self.assertIn("work", recipe)
        # (Its vats full of liquor, our own shader's, not mud.)
        self.assertEqual(len([sh for sh in recipe["shapes"] if sh.get("slot") == "tannery_liquor"]), 6)
        self.assertFalse(any(sh.get("slot") == "mud" for sh in recipe["shapes"]))

        for x, z in recipe["vats"]:
            self.assertIsNotNone(hit(name, [x, 2.0, z], [0.0, -1.0, 0.0]))

    def test_a_bricked_alley_is_shut_to_a_mans_chest(self):
        name = kit_terrace.bricked(2.5, 3.4)
        self.assertIsNotNone(hit(name, [0.0, 1.5, 1.0], [0.0, 0.0, -1.0]))
        self.assertIsNone(hit(name, [0.0, 3.6, 1.0], [0.0, 0.0, -1.0]))

    def test_a_garden_glimpse_is_hedged_round_its_gravel(self):
        # (What a barred gate shows of a garden beyond it: gravel from the
        # gate (z 0) back to -depth, hedged along its back and both sides
        # over a man's eye.)
        name = kit_terrace.garden_glimpse(6.0, 5.0)
        recipe = kit_recipes.PIECES[name]
        self.assertAlmostEqual(hit(name, [0.0, 1.0, -2.0], [0.0, -1.0, 0.0]), 1.0, places=3)
        self.assertTrue([sh for sh in recipe["shapes"] if sh.get("slot") == "gravel"])

        for start, direction in (([0.0, 1.7, -1.0], [0.0, 0.0, -1.0]), ([0.0, 1.7, -2.5], [1.0, 0.0, 0.0]), ([0.0, 1.7, -2.5], [-1.0, 0.0, 0.0])):
            self.assertIsNotNone(hit(name, start, direction), direction)

        self.assertTrue([sh for sh in recipe["shapes"] if sh.get("slot") == "hedge"])
        self.assertGreater(recipe["size"][1], 2.0)

    def test_a_garden_wall_is_climbed_over_from_the_lane(self):
        # (A walled garden's end: whitewash about z 0, its length along x, a
        # granite coping, no way through; a thief mantles its top from the
        # lane standing, stands on it, drops into the garden.)
        name = kit_terrace.garden_wall(3.0)
        recipe = kit_recipes.PIECES[name]

        for x in (-1.4, 0.0, 1.4):
            self.assertAlmostEqual(hit(name, [x, 1.2, 1.0], [0.0, 0.0, -1.0]), 1.0 - kit_terrace.YARD_WALL[1] / 2.0, places=3)

        top = recipe["size"][1]
        self.assertLessEqual(top, rules.MANTLE)
        self.assertIsNone(hit(name, [1.6, 1.2, 1.0], [0.0, 0.0, -1.0]))
        self.assertTrue([sh for sh in recipe["shapes"] if sh.get("slot") == "granite"])
        pieces = [piece("garden_wall", name, (0, 0, 0)), floor("garden_lane", -3.0, 0.0, 3.0, 3.0, 0.0), floor("garden_in", -3.0, -3.0, 3.0, 0.0, 0.0)]
        self.assertEqual(walked(pieces, [[0.0, 0.0, 1.5, "walk"], [0.0, top, 0.0, "mantle"], [0.0, 0.0, -1.5, "drop"]]), [])

    def test_a_yard_front_is_climbed_beside_its_gateway(self):
        # (Its wall as low as a garden's, mantled from the lane beside its
        # gateway; the gateway's piers and lintel over its 2.2 m gate.)
        for width, live in ((5.0, False), (15.0, True)):
            name = kit_terrace.yard_front(width, live)
            x = width / 2.0 - 0.7
            top = kit_terrace.YARD_WALL[0] + 0.1
            self.assertLessEqual(top, rules.MANTLE)
            self.assertAlmostEqual(hit(name, [x, top + 1.0, -0.15], [0.0, -1.0, 0.0]), 1.0, places=3)
            self.assertIsNotNone(hit(name, [0.0, 2.4, 1.0], [0.0, 0.0, -1.0]))
            pieces = [piece("yard_front", name, (0, 0, 0)), floor("yard_lane_%d" % width, -width / 2.0, 0.0, width / 2.0, 3.0, 0.0),
                      floor("yard_in_%d" % width, -width / 2.0, -3.0, width / 2.0, 0.0, 0.0)]
            self.assertEqual(walked(pieces, [[x, 0.0, 1.5, "walk"], [x, top, -0.15, "mantle"], [x, 0.0, -1.5, "drop"]]), [], width)

    def test_a_fill_is_solid_and_paved_at_its_top(self):
        # (A terrace carried forward between its retaining walls: solid to
        # its top, which is paved as a street.)
        name = kit_terrace.fill(10.9, 9.2, 4.23)
        self.assertAlmostEqual(hit(name, [0.0, 5.23, 0.0], [0.0, -1.0, 0.0]), 1.0, places=3)
        self.assertIsNotNone(hit(name, [0.0, 2.0, 6.0], [0.0, 0.0, -1.0]))
        tops = [sh for sh in kit_recipes.PIECES[name]["shapes"] if sh.get("slot") == "calcada"]
        self.assertTrue(tops)

    def test_a_bridge_spans_its_lane_between_two_houses(self):
        # (A room over a lane `span` wide, borne on its neighbours' party
        # walls: solid over the lane, nothing hanging under its floor, its
        # walls shut to the lane, a roof over it.)
        name = kit_terrace.bridge(2.5, 3.0)
        recipe = kit_recipes.PIECES[name]
        self.assertIsNotNone(hit(name, [0.0, -1.0, 0.0], [0.0, 1.0, 0.0]))
        self.assertIsNone(hit(name, [0.0, -0.05, 4.0], [0.0, 0.0, -1.0]))
        self.assertIsNotNone(hit(name, [0.0, 1.5, 4.0], [0.0, 0.0, -1.0]))
        self.assertIsNotNone(hit(name, [0.0, 10.0, 0.0], [0.0, -1.0, 0.0]))
        self.assertGreaterEqual(recipe["size"][0], 2.5 + 0.3)
        self.assertLess(recipe["top"], 4.0)

    def test_a_yard_gate_can_open(self):
        # (A yard's gate a man walks through: its opening clear, its door
        # where the layout hangs one.)
        name = kit_terrace.yard_front(15.0, True)
        recipe = kit_recipes.PIECES[name]
        self.assertIsNone(hit(name, [0.0, 1.0, 1.0], [0.0, 0.0, -1.0]))
        self.assertEqual(len(recipe["doors"]), 1)
        self.assertIsNotNone(hit(kit_terrace.yard_front(15.0), [0.0, 1.0, 1.0], [0.0, 0.0, -1.0]))

    def test_a_stair_lanes_landing_is_paved_on_top_only(self):
        # (Its body granite like its steps, the paving a slab on it: a
        # landing's side seen from a lane beside it is not a wall of
        # cobbles.)
        name = kit_terrace.stair_lane(2.5, 24)
        paved = [sh for sh in kit_recipes.PIECES[name]["shapes"] if sh.get("slot") == "calcada"]
        self.assertTrue(paved)
        self.assertTrue(all(sh["size"][1] <= 0.12 for sh in paved), [sh["size"] for sh in paved])

    def test_stone_follows_its_use(self):
        # (Treads and landings in worn granite flags, retaining walls in
        # warm rubble with a mossy coping, parapets in weathered ashlar
        # with the same coping, a stair tower's walls in ashlar: not one
        # granite on all of them.)
        def slots(name):
            return {sh.get("slot") for sh in kit_recipes.PIECES[name]["shapes"]}

        lane = slots(kit_terrace.stair_lane(2.5, 24))
        self.assertIn("stair_stone", lane)
        self.assertNotIn("granite", lane)
        self.assertEqual(slots(kit_terrace.retaining(10.0, 4.0)), {"rubble_warm", "coping_moss"})
        self.assertEqual(slots(kit_terrace.parapet(5.0)), {"ashlar_weathered", "coping_moss"})
        self.assertIn("stair_stone", slots(kit_terrace.wall_steps(11.8, 19.6, 1.5)))
        # (Its doors' sills granite; its walls, spine and steps not.)
        tower = kit_recipes.PIECES[kit_terrace.stair_tower(24.27)]["shapes"]
        self.assertIn("ashlar_weathered", {sh.get("slot") for sh in tower})
        self.assertIn("stair_stone", {sh.get("slot") for sh in tower})
        self.assertFalse([sh for sh in tower if sh.get("slot") == "granite" and sh.get("kind") == "box" and max(sh["size"]) > 2.0])
        # (A dressed face where asked: the bastion's, round its fountain.)
        self.assertIn("granite_rough", slots(kit_terrace.retaining(12.5, 4.23, False, "granite_rough")))

    def test_a_gateway_opens_or_bars_its_arch(self):
        # (A whitewashed wall across a lane or an alley, an arch in it:
        # live, its gate hung by the layout; barred, solid.)
        live = kit_terrace.gateway(6.0, 4.0, 2.5, 3.2)
        recipe = kit_recipes.PIECES[live]
        self.assertIsNone(hit(live, [0.0, 1.5, 1.0], [0.0, 0.0, -1.0]))
        self.assertIsNotNone(hit(live, [2.0, 1.5, 1.0], [0.0, 0.0, -1.0]))
        self.assertIsNotNone(hit(live, [0.0, 3.6, 1.0], [0.0, 0.0, -1.0]))
        self.assertEqual(len(recipe["doors"]), 1)
        self.assertAlmostEqual(recipe["doors"][0][4], 2.5)
        barred = kit_terrace.gateway(4.0, 4.0, 2.5, 3.2, False)
        self.assertIsNotNone(hit(barred, [0.0, 1.5, 1.0], [0.0, 0.0, -1.0]))
        self.assertTrue(any(sh.get("slot") == "window_grille" for sh in kit_recipes.PIECES[barred]["shapes"]))

    def test_pieces_are_named_by_their_measures(self):
        self.assertEqual(kit_terrace.stair_lane(1.5, 24), kit_terrace.stair_lane(1.5, 24))
        self.assertNotEqual(kit_terrace.retaining(10.0, 3.5), kit_terrace.retaining(10.0, 3.0))


if __name__ == "__main__":
    unittest.main()
