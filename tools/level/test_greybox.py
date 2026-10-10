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

    def test_overlap_caught(self):
        P = _town()
        P.plot("house_twin", "house", plan.rect(60, -40, 80, -20), storeys=2, height=9.0)
        self.assertTrue(greybox.gate(greybox.build(P.data())))


if __name__ == "__main__":
    unittest.main()
