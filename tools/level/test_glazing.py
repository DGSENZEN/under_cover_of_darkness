"""The glazed window (tools/level/kit_glazing.py): an opening through the
wall's whole thickness, its glass set back and its lead in front, a glass
collider filling it, and the record the exporter writes: pure Python, no
Blender.

    python3 tools/level/test_glazing.py
"""

import os
import sys
import unittest

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import geo  # noqa: E402
import kit_glazing  # noqa: E402
import kit_shapes  # noqa: E402


def polygon_area(points):
    """A planar polygon's area (the length of its cross-product sum)."""
    sx = sy = sz = 0.0

    for i in range(len(points)):
        a, b = points[i], points[(i + 1) % len(points)]
        sx += a[1] * b[2] - a[2] * b[1]
        sy += a[2] * b[0] - a[0] * b[2]
        sz += a[0] * b[1] - a[1] * b[0]

    return 0.5 * (sx * sx + sy * sy + sz * sz) ** 0.5


class Glazed(unittest.TestCase):
    def setUp(self):
        self.shapes, self.cols, self.rec = kit_glazing.glazed(0.0, 1.0, 1.0, 1.7, 0.0, 0.6, shape="round", lead="quarries")

    def test_the_outline_is_a_round_head_of_eight_segments(self):
        pts = kit_glazing.outline(0.0, 1.0, 1.0, 1.7, "round")
        self.assertEqual(len(pts), 11)
        self.assertAlmostEqual(max(p[1] for p in pts), 2.7, places=6)
        self.assertAlmostEqual(pts[2][1], 2.2, places=6)  # the right springing

    def test_a_pointed_head_meets_at_the_top_and_springs_level(self):
        pts = kit_glazing.outline(2.0, 1.0, 1.0, 2.0, "arched")
        self.assertEqual(len(pts), 11)
        apex = max(pts, key=lambda p: p[1])
        self.assertAlmostEqual(apex[0], 2.0, places=6)
        self.assertAlmostEqual(apex[1], 3.0, places=6)
        self.assertAlmostEqual(pts[2][1], pts[-1][1], places=6)
        self.assertEqual((pts[2][0], pts[-1][0]), (2.5, 1.5))

    def test_the_reveals_go_through_the_whole_wall(self):
        built = kit_shapes.build(self.shapes)
        zs = [v[2] for v in built["verts"]]
        self.assertAlmostEqual(max(zs), 0.0, places=4)
        self.assertAlmostEqual(min(zs), -0.6, places=4)

    def test_the_glass_is_set_back_and_the_lead_in_front(self):
        glass = [s for s in self.shapes if s.get("slot") == "glazing"]
        lead = [s for s in self.shapes if s.get("slot") == "quarries"]
        self.assertTrue(glass and lead)
        gz = {round(p[2], 4) for s in glass for p in s["points"]}
        lz = {round(p[2], 4) for s in lead for p in s["points"]}
        self.assertEqual(gz, {-0.15})
        self.assertEqual(lz, {-0.14})

    def test_the_collider_fills_the_opening_as_glass(self):
        self.assertEqual(len(self.cols), 1)
        c = self.cols[0]
        self.assertEqual(c[6], "glass")
        self.assertEqual([round(v, 4) for v in c[:6]], [0.0, 1.85, -0.3, 1.0, 1.7, 0.6])

    def test_the_record_is_the_glass(self):
        self.assertEqual(self.rec["normal"], [0.0, 0.0, 1.0])
        self.assertEqual(self.rec["lead"], "quarries")
        self.assertEqual(len(self.rec["outline"]), 11)
        self.assertTrue(all(abs(p[2] + 0.15) < 1e-6 for p in self.rec["outline"]))


class Walls(unittest.TestCase):
    def test_no_strip_collider_spans_a_hole(self):
        holes = [kit_glazing.hole(2.0, 1.0, 1.0, 1.5), kit_glazing.hole(5.0, 0.0, 1.2, 2.2)]
        shapes, cols = kit_glazing.strips(0.0, 8.0, 0.0, 4.0, -0.3, 0.6, holes, "whitewash")

        for c in cols:
            for x0, x1, y0, y1 in holes:
                overlap = (min(c[0] + c[3] / 2, x1) - max(c[0] - c[3] / 2, x0) > 1e-6
                           and min(c[1] + c[4] / 2, y1) - max(c[1] - c[4] / 2, y0) > 1e-6)
                self.assertFalse(overlap, c)

        area = sum(c[3] * c[4] for c in cols)
        self.assertAlmostEqual(area, 32.0 - 1.5 - 1.2 * 2.2, places=6)

    def test_around_leaves_the_holes_and_covers_the_rest(self):
        # An x-plane, narrowing upward.
        outline = [[0.0, 0.0, -2.0], [0.0, 0.0, 2.0], [0.0, 3.0, 1.6], [0.0, 3.0, -1.6]]
        holes = [(-1.5, -1.0, 1.2, 1.8), (1.0, 1.5, 1.2, 1.8)]
        faces = kit_glazing.around(outline, holes, "x", "wood_old", (1.0, 0.0, 0.0))
        area = sum(polygon_area(f["points"]) for f in faces)
        self.assertAlmostEqual(area, 0.5 * (4.0 + 3.2) * 3.0 - 2 * 0.5 * 0.6, places=4)

        for f in faces:
            n = kit_shapes._normal(f["points"])
            self.assertGreater(n[0] / sum(c * c for c in n) ** 0.5, 0.99)
            cx = sum(p[2] for p in f["points"]) / len(f["points"])
            cy = sum(p[1] for p in f["points"]) / len(f["points"])
            self.assertFalse(any(u0 < cx < u1 and v0 < cy < v1 for u0, u1, v0, v1 in holes))

    def test_moved_records_turn_like_shapes(self):
        rec = kit_glazing.glazed(0.0, 1.0, 1.0, 1.5, 0.0, 0.6)[2]
        turned = kit_glazing.moved([rec], -90.0, (10.0, 0.0, 5.0))[0]
        probe = kit_shapes.moved([kit_shapes.polygon(rec["outline"], "glazing")], -90.0, (10.0, 0.0, 5.0))[0]["points"]

        for a, b in zip(turned["outline"], probe):
            self.assertTrue(all(abs(a[i] - b[i]) < 1e-6 for i in range(3)))

        self.assertAlmostEqual(abs(turned["normal"][0]), 1.0, places=6)


class Manifest(unittest.TestCase):
    def setUp(self):
        shapes, cols, rec = kit_glazing.glazed(0.0, 1.0, 1.0, 1.5, 0.0, 0.6)
        wall = [0.0, 3.0, -0.3, 4.0, 1.0, 0.6, "stone", 0, 0, 0]
        self.recipe = {"family": "dressing", "slot": "stone", "surface": "stone", "boxes": [], "cols": cols + [wall], "windows": [rec],
                       "sockets": {}, "size": None, "opening": None, "shapes": shapes}
        self.rec = rec

    def test_windows_are_put_in_the_world(self):
        basis = [[0.0, 0.0, 1.0], [0.0, 1.0, 0.0], [-1.0, 0.0, 0.0]]  # turned 90 degrees
        pieces = [{"name": "probe", "piece": "glazing_probe", "sector": "s", "position": [10.0, 0.0, 5.0], "basis": basis},
                  {"name": "plain", "piece": "plain_probe", "sector": "s", "position": [0.0, 0.0, 0.0], "basis": geo.IDENTITY}]
        out = kit_glazing.world_windows(pieces, {"glazing_probe": self.recipe, "plain_probe": dict(self.recipe, windows=[])})
        self.assertEqual(len(out), 1)
        w = out[0]
        self.assertEqual((w["piece"], w["sector"], w["lead"]), ("probe", "s", "casement"))
        self.assertEqual(w["normal"], [round(v, 4) for v in geo.apply(basis, [0.0, 0.0, 1.0])])
        first = geo.add([10.0, 0.0, 5.0], geo.apply(basis, self.rec["outline"][0]))
        self.assertEqual(w["outline"][0], [round(v, 4) for v in first])

    def test_glass_never_occludes(self):
        boxes = geo.piece_boxes(self.recipe, [0.0, 0.0, 0.0], geo.IDENTITY)
        self.assertEqual([b.occluder for b in boxes if b.surface == "glass"], [False])
        self.assertEqual([b.occluder for b in boxes if b.surface == "stone"], [True])


if __name__ == "__main__":
    unittest.main()
