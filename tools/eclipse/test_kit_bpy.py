"""The style lab's kit pieces as built (inside Blender): faces point the way
their side of the wall looks.

    Blender -b --factory-startup --python tools/eclipse/test_kit_bpy.py
"""

import os
import sys
import unittest

import bmesh
import bpy

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import arcade_bay  # noqa: E402


class ArcadeBay(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        arcade_bay.build()
        cls.objects = [o for o in bpy.context.scene.objects if o.type == "MESH"]

    def _faces_in_plane_y(self, y):
        """The wall's own surfaces in a plane: not the little caps of rails
        buried flush against it."""
        out = []

        for o in self.objects:
            for p in o.data.polygons:
                ys = [(o.matrix_world @ o.data.vertices[v].co).y for v in p.vertices]

                if max(abs(c - y) for c in ys) < 1e-5 and abs(p.normal.y) > 0.9 and p.area > 0.01:
                    out.append((o.name, p.normal.y))

        return out

    def test_the_street_face_looks_at_the_street(self):
        """Every face in the façade's plane looks out to the plaza (-y)."""
        faces = self._faces_in_plane_y(arcade_bay.FRONT)
        wrong = [f for f in faces if f[1] > 0]
        self.assertTrue(faces)
        self.assertEqual(wrong, [], wrong[:5])

    def test_the_arcade_wall_looks_into_the_arcade(self):
        """Every face in the arcade wall's inner plane looks in (+y)."""
        faces = self._faces_in_plane_y(arcade_bay.WALL_BACK)
        wrong = [f for f in faces if f[1] < 0]
        self.assertTrue(faces)
        self.assertEqual(wrong, [], wrong[:5])

    def test_spandrels_triangulate_cleanly(self):
        """No zero-area triangle where the arch's crown meets the cornice."""
        o = bpy.data.objects["bay_spandrels"]
        bm = bmesh.new()
        bm.from_mesh(o.data)
        smallest = min(sum(((l[1].vert.co - l[0].vert.co).cross(l[2].vert.co - l[0].vert.co)).length / 2
                           for _ in [0]) for l in bm.calc_loop_triangles())
        bm.free()
        self.assertGreater(smallest, 1e-6)


if __name__ == "__main__":
    result = unittest.main(argv=["test_kit_bpy"], exit=False).result
    sys.exit(not result.wasSuccessful())
