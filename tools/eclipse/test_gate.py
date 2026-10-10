"""The geometry gate a lab piece must pass (gate.py): pure Python.

    python3 tools/eclipse/test_gate.py
"""

import os
import sys
import unittest

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import gate  # noqa: E402

UV = [(0.5, 0.5)]


def box(owner, x0, y0, z0, x1, y1, z1):
    """A box's six faces, outward, in overlap.py's shape."""
    return [
        {"owner": owner, "normal": (-1, 0, 0), "points": [(x0, y0, z0), (x0, y1, z0), (x0, y1, z1), (x0, y0, z1)]},
        {"owner": owner, "normal": (1, 0, 0), "points": [(x1, y0, z0), (x1, y0, z1), (x1, y1, z1), (x1, y1, z0)]},
        {"owner": owner, "normal": (0, -1, 0), "points": [(x0, y0, z0), (x0, y0, z1), (x1, y0, z1), (x1, y0, z0)]},
        {"owner": owner, "normal": (0, 1, 0), "points": [(x0, y1, z0), (x1, y1, z0), (x1, y1, z1), (x0, y1, z1)]},
        {"owner": owner, "normal": (0, 0, -1), "points": [(x0, y0, z0), (x1, y0, z0), (x1, y1, z0), (x0, y1, z0)]},
        {"owner": owner, "normal": (0, 0, 1), "points": [(x0, y0, z1), (x0, y1, z1), (x1, y1, z1), (x1, y0, z1)]},
    ]


def quad(owner, x0, y0, x1, y1, z=0.0):
    return {"owner": owner, "normal": (0, 0, 1), "points": [(x0, y0, z), (x1, y0, z), (x1, y1, z), (x0, y1, z)]}


class Gate(unittest.TestCase):
    def test_clean_piece_passes(self):
        faces = box(0, 0, 0, 0, 1, 1, 1) + box(1, 1, 0, 0, 2, 1, 1)
        self.assertEqual(gate.check(faces, 24, UV), [])

    def test_coplanar_overlap_fails(self):
        problems = gate.check([quad(0, 0, 0, 2, 2), quad(1, 1, 0, 3, 2)], 4, UV)
        self.assertEqual(len(problems), 1)
        self.assertIn("overlap", problems[0])
        self.assertIn("0", problems[0])
        self.assertIn("1", problems[0])

    def test_triangle_budget(self):
        problems = gate.check(box(0, 0, 0, 0, 1, 1, 1), 5001, UV)
        self.assertEqual(len(problems), 1)
        self.assertIn("over budget", problems[0])

    def test_budget_is_5000(self):
        """Densified for vertex paint (Oct 9 2026): 5000 triangles a piece."""
        self.assertEqual(gate.check(box(0, 0, 0, 0, 1, 1, 1), 5000, UV), [])

    def test_sliver_under_a_centimetre_fails(self):
        strip = quad(1, 5, 5, 6, 5.005)
        problems = gate.check(box(0, 0, 0, 0, 1, 1, 1) + [strip], 14, UV)
        self.assertEqual(len(problems), 1)
        self.assertIn("sliver", problems[0])

    def test_a_flange_a_centimetre_and_a_half_thick_passes(self):
        self.assertEqual(gate.check(box(0, 0, 0, 0, 1, 1, 1) + [quad(1, 5, 5, 6, 5.015)], 14, UV), [])

    def test_uv_outside(self):
        problems = gate.check(box(0, 0, 0, 0, 1, 1, 1), 12, [(0.5, 0.5), (1.02, 0.5)])
        self.assertEqual(len(problems), 1)
        self.assertIn("uv outside", problems[0])

    def test_degenerate_face(self):
        sliver = quad(1, 5, 5, 5.0005, 5.0005)
        problems = gate.check(box(0, 0, 0, 0, 1, 1, 1) + [sliver], 14, UV)
        self.assertEqual(len(problems), 1)
        self.assertIn("degenerate", problems[0])


class Layered(unittest.TestCase):
    """Faces stacked a hair apart, facing the same way, fight for depth at a
    distance (a plate laid on a wall): within LAYER_GAP they are refused,
    whether two objects or one."""

    def test_a_plate_a_centimetre_off_a_wall_fails(self):
        problems = gate.check([quad(0, 0, 0, 2, 2), quad(1, 0.5, 0.5, 1.0, 1.0, z=0.01)], 4, UV)
        self.assertEqual(len(problems), 1)
        self.assertIn("layered", problems[0])

    def test_within_one_object_fails_too(self):
        problems = gate.check([quad(0, 0, 0, 2, 2), quad(0, 0.5, 0.5, 1.0, 1.0, z=0.01)], 4, UV)
        self.assertEqual(len(problems), 1)
        self.assertIn("layered", problems[0])

    def test_well_apart_passes(self):
        self.assertEqual(gate.check([quad(0, 0, 0, 2, 2), quad(1, 0.5, 0.5, 1.0, 1.0, z=0.05)], 4, UV), [])

    def test_side_by_side_in_one_plane_passes(self):
        self.assertEqual(gate.check([quad(0, 0, 0, 1, 1), quad(0, 1, 0, 2, 1)], 4, UV), [])


if __name__ == "__main__":
    unittest.main()
