"""The greybox geometry (greybox.py) from the checks' small town.

    python3 tools/level/test_greybox.py
"""

import os
import sys
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
sys.path.insert(0, os.path.join(HERE, "layouts"))

import greybox  # noqa: E402
import plan  # noqa: E402
from test_plan_check import _town  # noqa: E402


def _mesh(box, name):
    return next(m for m in box["meshes"] if m["name"] == name)


def _covers(face, point, slack=1e-6):
    """Whether a planar convex face covers a point lying in its plane."""
    pts = face["points"]
    n = face["normal"]
    signs = set()

    for a, b in zip(pts, pts[1:] + pts[:1]):
        edge = [b[k] - a[k] for k in range(3)]
        to = [point[k] - a[k] for k in range(3)]
        cross = [edge[1] * to[2] - edge[2] * to[1], edge[2] * to[0] - edge[0] * to[2], edge[0] * to[1] - edge[1] * to[0]]
        s = sum(cross[k] * n[k] for k in range(3))

        if abs(s) > slack:
            signs.add(s > 0)

    return len(signs) <= 1


def _in_plane(face, point, slack=1e-4):
    a = face["points"][0]
    return abs(sum((point[k] - a[k]) * face["normal"][k] for k in range(3))) <= slack


def _area(face):
    pts = face["points"]
    total = [0.0, 0.0, 0.0]

    for a, b in zip(pts, pts[1:] + pts[:1]):
        total[0] += a[1] * b[2] - a[2] * b[1]
        total[1] += a[2] * b[0] - a[0] * b[2]
        total[2] += a[0] * b[1] - a[1] * b[0]

    return sum(v * v for v in total) ** 0.5 / 2


class Greybox(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.data = _town().data()
        cls.box = greybox.build(cls.data)

    def test_gate_clean(self):
        self.assertEqual(greybox.gate(self.box), [])

    def test_ground_has_a_hole_at_the_well(self):
        centre = (0.0, 0.0, -55.0)
        covering = [f for f in _mesh(self.box, "ground")["faces"] if _in_plane(f, centre) and _covers(f, centre)]
        self.assertEqual(covering, [])

    def test_sunken_floor_at_its_level(self):
        floor = [f for f in _mesh(self.box, "well_a")["faces"] if f["normal"][1] > 0.99]
        self.assertTrue(any(_in_plane(f, (0, -8, -55)) and _covers(f, (0, -8, -55)) for f in floor))

    def test_plot_is_closed_above(self):
        ups = [f for f in _mesh(self.box, "house_a")["faces"] if f["normal"][1] > 0.99]
        self.assertEqual(len(ups), 1)
        self.assertAlmostEqual(ups[0]["points"][0][1], 9.0)
        self.assertAlmostEqual(_area(ups[0]), 400.0, places=6)

    def test_space_wall_has_its_gap(self):
        point = (0.0, -8.0 + 1.5, -50.0)
        walls = [f for f in _mesh(self.box, "hall")["faces"] if abs(f["normal"][1]) < 0.01]
        self.assertTrue(walls)
        self.assertEqual([f for f in walls if _in_plane(f, point) and _covers(f, point)], [])

    def test_stair_rises_from_floor_to_street(self):
        stair = _mesh(self.box, "stair_a")
        top = max(stair["faces"], key=lambda f: f["normal"][1])
        ys = [p[1] for p in top["points"]]
        self.assertAlmostEqual(min(ys), -8.0, delta=0.01)
        self.assertAlmostEqual(max(ys), 0.0, delta=0.01)

    def test_plank_rests_on_its_roofs(self):
        # plank_ab runs (75, 9, -25) to (75, 9, -15): its deck a little proud
        # of the roofs, along z, 0.8 m wide across x.
        plank = _mesh(self.box, "plank_ab")
        top = max(plank["faces"], key=lambda f: f["normal"][1])
        self.assertGreater(top["normal"][1], 0.99)
        self.assertTrue(all(abs(p[1] - (9.0 + greybox.PROUD)) < 1e-6 for p in top["points"]), top["points"])
        self.assertAlmostEqual(min(p[2] for p in top["points"]), -25.0, delta=1e-6)
        self.assertAlmostEqual(max(p[2] for p in top["points"]), -15.0, delta=1e-6)
        self.assertAlmostEqual(max(p[0] for p in top["points"]) - min(p[0] for p in top["points"]), greybox.PLANK[0], delta=1e-6)

    def test_brink_falls_away(self):
        ys = [p[1] for f in _mesh(self.box, "brink")["faces"] for p in f["points"]]
        self.assertAlmostEqual(min(ys), -greybox.CLIFF, delta=1e-6)

    def test_gaps_match_across_an_opening(self):
        # A passage floored a metre above the well it opens into: the well's
        # wall opens from the passage's floor, as the passage's does.
        P = _town()
        P.space("ledge", plan.rect(10, -56, 20, -50), floor=-7.0, height=3.0, openings=[{"to": "well_a", "at": (10, -53)}])
        box = greybox.build(P.data())
        walls = [f for f in _mesh(box, "well_a")["faces"] if abs(f["normal"][1]) < 0.01]
        below = (10.0, -7.5, -53.0)
        above = (10.0, -6.5, -53.0)
        self.assertTrue([f for f in walls if _in_plane(f, below) and _covers(f, below)])
        self.assertEqual([f for f in walls if _in_plane(f, above) and _covers(f, above)], [])

    def test_pit_keeps_its_wall_beside_a_pit_on_the_same_side(self):
        # A small pit inside a bigger one, both meeting x 100: the big pit's
        # west wall stands its whole length.
        P = _town()
        P.ground("big_pit", "dig", plan.rect(100, 100, 130, 130), level=-6.0)
        P.ground("small_pit", "landing", plan.rect(100, 110, 106, 116), level=-3.0)
        box = greybox.build(P.data())
        walls = [f for f in _mesh(box, "big_pit")["faces"] if f["normal"][0] > 0.99]
        point = (100.0, -1.0, 113.0)
        self.assertTrue([f for f in walls if _in_plane(f, point) and _covers(f, point)])

    def test_raised_ground_stands_on_the_street(self):
        """A plaza a pavement up: its top at its level (none over the well
        cut in it), its sides from the street up facing out, the well's
        walls up to the plaza."""
        P = plan.Plan("pavement")
        P.brink(plan.rect(-40, -40, 40, 40))
        P.ground("square", "plaza", plan.rect(-10, -10, 10, 10), level=0.2)
        P.ground("street", "street", plan.rect(-40, -40, 40, -10))
        P.ground("well", "well", plan.rect(-2, -2, 2, 2), level=-8.0)
        box = greybox.build(P.data())
        raised = _mesh(box, "square")
        self.assertEqual(raised["kind"], "raised")
        tops = [f for f in raised["faces"] if f["normal"][1] > 0.99]
        self.assertTrue(tops)
        self.assertTrue(all(abs(p[1] - 0.2) < 1e-9 for f in tops for p in f["points"]))
        self.assertFalse(any(_covers(f, (0, 0.2, 0)) for f in tops))
        self.assertAlmostEqual(sum(_area(f) for f in tops), 400 - 16, places=6)

        for n, at in (((1, 0, 0), (10, 0.1, 0)), ((-1, 0, 0), (-10, 0.1, 0)), ((0, 0, 1), (0, 0.1, 10)),
                      ((0, 0, -1), (0, 0.1, -10))):
            sides = [f for f in raised["faces"] if sum(f["normal"][k] * n[k] for k in range(3)) > 0.99
                     and _in_plane(f, at) and _covers(f, at)]
            self.assertTrue(sides, n)

        walls = [f for f in _mesh(box, "well")["faces"] if abs(f["normal"][1]) < 0.01]
        self.assertAlmostEqual(max(p[1] for f in walls for p in f["points"]), 0.2)
        covering = [f for f in _mesh(box, "ground")["faces"] if _in_plane(f, (0, 0, 5)) and _covers(f, (0, 0, 5))]
        self.assertEqual(covering, [])
        self.assertEqual(greybox.gate(box), [])

    def test_layered_faces_caught(self):
        # Two roofs 2 cm apart over one footprint fight at a distance; 4 cm do not.
        def roofs(gap):
            P = _town()
            P.plot("roof_a", "house", plan.rect(100, -40, 110, -30), storeys=2, height=9.0, roof=False)
            P.plot("roof_b", "house", plan.rect(100, -40, 110, -30), storeys=2, height=9.0 + gap, base=0.0, roof=False)
            box = greybox.build(P.data())
            return [f for f in greybox._layered(greybox.faces(box))
                    if {greybox.faces(box)[f[0]]["owner"], greybox.faces(box)[f[1]]["owner"]} == {"roof_a", "roof_b"}]

        self.assertTrue(roofs(0.02))
        self.assertFalse(roofs(0.04))

    def test_overlap_caught(self):
        P = _town()
        P.plot("house_twin", "house", plan.rect(60, -40, 80, -20), storeys=2, height=9.0)
        self.assertTrue(greybox.gate(greybox.build(P.data())))


def _rooms(width=3.0, at=(10, 5), b_height=4.0, b_rect=(10, 2, 20, 8)):
    """Two rooms side by side at one floor, an opening between."""
    P = plan.Plan("rooms")
    P.space("a", plan.rect(0, 0, 10, 10), floor=0.0, height=6.0, openings=[{"to": "b", "at": at, "width": width}])
    P.space("b", plan.rect(*b_rect), floor=0.0, height=b_height, openings=[{"to": "a", "at": at, "width": width}])
    return P.data()


class Openings(unittest.TestCase):
    """A gap in a wall opens onto the room beside, never onto nothing."""

    def test_clean_opening_passes(self):
        self.assertEqual(greybox.gate(greybox.build(_rooms())), [])

    def test_gap_past_the_rooms_end_caught(self):
        # The gap runs z 1.5-4.5; room b starts at z 2.
        problems = greybox.gate(greybox.build(_rooms(at=(10, 3))))
        self.assertTrue(any(p.startswith("gap: a to b") for p in problems), problems)

    def test_gap_above_the_rooms_ceiling_caught(self):
        # The gap is 3 m tall; room b only 2.5.
        problems = greybox.gate(greybox.build(_rooms(b_height=2.5)))
        self.assertTrue(any(p.startswith("gap: a to b") for p in problems), problems)

    def test_volume_found_whatever_the_order(self):
        # A box inside the arm of an L, the box declared first.
        P = plan.Plan("ell")
        P.space("box", plan.rect(2, 12, 6, 16), floor=0.0, height=3.0)
        P.space("ell", [(0, 0), (20, 0), (20, 10), (10, 10), (10, 20), (0, 20)], floor=0.0, height=3.0)
        problems = greybox.gate(greybox.build(P.data()))
        self.assertTrue(any(p.startswith("volume: box and ell") for p in problems), problems)


if __name__ == "__main__":
    unittest.main()
