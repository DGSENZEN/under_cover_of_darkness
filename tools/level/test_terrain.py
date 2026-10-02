"""The terrain generator (terrain.py) and the triangle rays it is read by
(geo.TriGrid).

    python3 tools/level/test_terrain.py
"""

import os
import sys
import unittest

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import geo  # noqa: E402
import terrain  # noqa: E402


def face_normal(t, face):
    a, b, c = (t["verts"][i] for i in face)
    n = [(b[1] - a[1]) * (c[2] - a[2]) - (b[2] - a[2]) * (c[1] - a[1]),
         (b[2] - a[2]) * (c[0] - a[0]) - (b[0] - a[0]) * (c[2] - a[2]),
         (b[0] - a[0]) * (c[1] - a[1]) - (b[1] - a[1]) * (c[0] - a[0])]
    length = sum(v * v for v in n) ** 0.5
    return [v / length for v in n]


class Terrain(unittest.TestCase):
    def test_a_grid_follows_its_height(self):
        t = terrain.grid("slope", "yard", 0, 0, 20, 20, 2.0, lambda x, z: 0.1 * x, lambda *a: "grass")
        self.assertAlmostEqual(terrain.height_at(t, 10.0, 7.0), 1.0, places=3)
        self.assertEqual(len(t["faces"]), 10 * 10 * 2)

    def test_faces_wind_outward(self):
        t = terrain.grid("flat", "yard", 0, 0, 4, 4, 2.0, lambda x, z: 0.0, lambda *a: "grass")
        self.assertTrue(all(face_normal(t, f)[1] > 0.99 for f in t["faces"]))
        c = terrain.cliff("face", "yard", [(0, 0), (20, 0)], 0.0, 18.0)
        # it looks to the left of its path (going east: north, -z)
        self.assertTrue(all(face_normal(c, f)[2] < -0.5 for f in c["faces"]))

    def test_a_cliff_jointed_in_blocks(self):
        # Granite's upright joints: every `columns` columns a block of each
        # band stands out or back on its own; the columns inside a block keep
        # its face, the next block's differs.
        c = terrain.cliff("face", "yard", [(0, 0), (30, 0)], 0.0, 12.0, band=3.0, jitter=0.4, step=1.0, blocks=(3, 0.8), seed=5)
        foot = sorted((v for v in c["verts"] if abs(v[1]) < 1e-6), key=lambda v: v[0])
        outs = [round(v[2], 4) for v in foot]
        groups = [outs[i:i + 3] for i in range(0, len(outs) - 2, 3)]
        self.assertTrue(all(len(set(g)) == 1 for g in groups), groups)
        self.assertGreater(len({g[0] for g in groups}), 4)
        self.assertTrue(all(face_normal(c, f)[2] < 0.0 for f in c["faces"]))

    def test_slopes_choose_slots(self):
        t = terrain.grid("hill", "yard", 0, 0, 20, 20, 2.0, lambda x, z: 0.0 if x < 10 else (x - 10) * 2.0,
                         lambda x, y, z, s: "cliff" if s > 50 else "grass")
        self.assertIn("cliff", t["slots"])
        self.assertIn("grass", t["slots"])

    def test_keep_and_skirt(self):
        t = terrain.grid("bed", "sea", 0, 0, 40, 40, 4.0, lambda x, z: -8.0 if x > 20 else 1.0, lambda *a: "sand",
                         keep=lambda ys: max(ys) > -2.0, skirt=1.5)
        # only the quads with a corner over -2 are kept (to x = 24)
        self.assertTrue(all(max(t["verts"][i][0] for i in f) <= 24.0 for f in t["faces"] if min(t["verts"][i][1] for i in f) > -1.0))
        # the skirt hangs 1.5 m under the west edge
        self.assertTrue(any(abs(v[0]) < 1e-6 and abs(v[1] + 0.5) < 1e-6 for v in t["verts"]))

    def test_a_tunnel_faces_in_and_has_a_floor(self):
        t = terrain.tunnel("cave", "cave", [(0, 2, 0), (0, 2, -20)], [(4, 3), (3, 2.5)], floor=0.5)
        self.assertAlmostEqual(min(v[1] for v in t["verts"]), 0.5, places=3)
        tris = geo.TriGrid(terrain.triangles(t))
        self.assertIsNotNone(tris.down([0, 1.5, -10], 3.0))
        self.assertIsNotNone(tris.up([0, 1.5, -10], 5.0))

    def test_strata_bands_and_the_wet_foot(self):
        self.assertNotEqual(terrain.strata(0, 3, 0), terrain.strata(0, 9, 0))
        self.assertLess(sum(terrain.strata(0, 0.5, 0)), sum(terrain.strata(0, 3, 0)))

    def test_the_budget(self):
        with self.assertRaises(ValueError):
            terrain.grid("huge", "yard", 0, 0, 400, 400, 2.0, lambda x, z: 0.0, lambda *a: "grass")

    def test_names_godot_keeps(self):
        with self.assertRaises(ValueError):
            terrain.grid("West Spit.001", "yard", 0, 0, 4, 4, 2.0, lambda x, z: 0.0, lambda *a: "grass")

    def test_rays_miss_beside_the_triangles(self):
        tris = geo.TriGrid(terrain.triangles(terrain.grid("patch", "yard", 0, 0, 4, 4, 2.0, lambda x, z: 1.0, lambda *a: "grass")))
        self.assertAlmostEqual(tris.down([2, 3, 2], 5.0), 2.0, places=4)
        self.assertIsNone(tris.down([9, 3, 9], 5.0))
        self.assertIsNone(tris.down([2, 3, 2], 1.0))


if __name__ == "__main__":
    unittest.main(verbosity=1)
