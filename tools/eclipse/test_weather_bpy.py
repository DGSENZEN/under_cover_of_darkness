"""weather.py inside Blender: densifying a piece on the world grid, measuring
what is round each face corner, baking the rules, the user's touch-ups.

    Blender -b --factory-startup --python tools/eclipse/test_weather_bpy.py
"""

import os
import sys
import unittest

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import common  # noqa: E402
import weather  # noqa: E402


def _box(name, lo, hi, slot_name="lime"):
    m = common.Mesh(name)
    m.box(lo, hi, slot_name)
    return m.make()


def _area(obj):
    return sum(p.area for p in obj.data.polygons)


def _thickness(obj):
    """Each face's thinnest extent: its area over its longest edge."""
    out = []

    for poly in obj.data.polygons:
        vs = [obj.data.vertices[i].co for i in poly.vertices]
        longest = max((vs[i] - vs[(i + 1) % len(vs)]).length for i in range(len(vs)))
        out.append(poly.area / longest)

    return np.array(out)


def _edges(obj):
    return np.array([(obj.data.vertices[e.vertices[0]].co - obj.data.vertices[e.vertices[1]].co).length
                     for e in obj.data.edges])


def _corner(measured, point, normal):
    """The index of the face corner at `point` facing `normal`."""
    d = np.linalg.norm(measured["points"] - np.array(point), axis=1)
    d += 10.0 * (measured["normals"] @ np.array(normal) < 0.99)
    return int(np.argmin(d))


class Densify(unittest.TestCase):
    def setUp(self):
        common.reset()

    def test_densify_keeps_area_and_cuts_to_grid(self):
        wall = _box("wall", (0.0, 0.0, 0.0), (3.0, 0.2, 2.0))
        slab = _box("slab", (0.0, 1.0, 0.0), (1.0, 2.0, 0.05))
        before = _area(wall), _area(slab)
        weather.densify([wall, slab])
        self.assertAlmostEqual(_area(wall), before[0], places=6)
        self.assertAlmostEqual(_area(slab), before[1], places=6)
        self.assertLessEqual(_edges(wall).max(), weather.GRID + 1e-6)
        self.assertLessEqual(_edges(slab).max(), weather.GRID + 1e-6)

        for v in wall.data.vertices:   # every vertex still on the box's surface
            c = np.array(v.co)
            on = np.isclose(c, (0.0, 0.0, 0.0), atol=1e-6) | np.isclose(c, (3.0, 0.2, 2.0), atol=1e-6)
            self.assertTrue(on.any(), tuple(c))

    def test_story_line_snaps_to_grid(self):
        wall = _box("wall", (0.0, 0.0, 0.0), (3.0, 0.2, 2.0))
        weather.densify([wall], lines=[("z", 1.49)])
        heights = {round(v.co.z, 4) for v in wall.data.vertices}
        self.assertIn(1.5, heights)
        self.assertNotIn(1.49, heights)
        self.assertGreaterEqual(_thickness(wall).min(), weather.SNAP - 1e-6)

    def test_story_line_off_the_grid_cuts(self):
        wall = _box("wall", (0.0, 0.0, 0.0), (3.0, 0.2, 2.0))
        weather.densify([wall], lines=[("z", 0.3)])
        self.assertIn(0.3, {round(v.co.z, 4) for v in wall.data.vertices})

    def test_no_sliver_against_existing_edges(self):
        # A wall's top 1 cm over a grid line: the grid's cut there would leave
        # a 1 cm strip, so that face is not cut by it.
        wall = _box("wall", (0.0, 0.0, 0.0), (3.0, 0.2, 1.01))
        weather.densify([wall])
        self.assertGreaterEqual(_thickness(wall).min(), weather.SNAP - 1e-6)

    def test_coarse_object_uses_its_own_grid(self):
        fine = _box("fine", (0.0, 0.0, 0.0), (3.0, 0.2, 2.0))
        stairs = _box("stairs", (0.0, 5.0, 0.0), (3.0, 5.2, 2.0))
        weather.densify([fine, stairs], coarse={"stairs": 1.0})
        self.assertLessEqual(_edges(stairs).max(), 1.0 + 1e-6)
        self.assertGreater(_edges(stairs).max(), weather.GRID + 1e-6)
        self.assertLess(len(stairs.data.polygons), len(fine.data.polygons))


class Measure(unittest.TestCase):
    def setUp(self):
        common.reset()

    def test_measure_floor_and_overhang(self):
        # A wall's front at y 0 (facing -y) with a sill slab jutting out over it.
        wall = _box("wall", (0.0, 0.0, 0.0), (3.0, 0.2, 2.5))
        sill = _box("sill", (0.0, -0.3, 1.5), (3.0, 0.0, 1.55))
        weather.densify([wall, sill])
        measured = weather.measure([wall, sill])["wall"]
        i = _corner(measured, (1.0, 0.0, 1.0), (0.0, -1.0, 0.0))
        self.assertAlmostEqual(measured["overhang_gap"][i], 0.5, delta=0.01)
        self.assertAlmostEqual(measured["floor_gap"][i], 1.0, delta=0.01)
        high = _corner(measured, (1.0, 0.0, 2.0), (0.0, -1.0, 0.0))
        self.assertTrue(np.isinf(measured["overhang_gap"][high]))

    def test_floors_have_no_floor_gap(self):
        slab = _box("slab", (0.0, 0.0, 0.0), (2.0, 2.0, 0.2))
        weather.densify([slab])
        measured = weather.measure([slab])["slab"]
        top = measured["normals"][:, 2] > 0.7
        self.assertTrue(np.isinf(measured["floor_gap"][top]).all())

    def test_soffit_darker_than_open_wall(self):
        # A tunnel: two walls and a roof; the roof's underside sees little sky.
        left = _box("left", (0.0, 0.0, 0.0), (0.2, 4.0, 2.5))
        right = _box("right", (2.2, 0.0, 0.0), (2.4, 4.0, 2.5))
        roof = _box("roof", (0.0, 0.0, 2.5), (2.4, 4.0, 2.7))
        objects = [left, right, roof]
        weather.densify(objects)
        measured = weather.measure(objects)
        soffit = _corner(measured["roof"], (1.0, 2.0, 2.5), (0.0, 0.0, -1.0))
        outside = _corner(measured["left"], (0.0, 2.0, 1.5), (-1.0, 0.0, 0.0))
        self.assertLess(measured["roof"]["open_sky"][soffit], measured["left"]["open_sky"][outside] - 0.2)

    def test_convex_edges_found(self):
        slab = _box("slab", (0.0, 0.0, 0.0), (2.0, 2.0, 0.5))
        weather.densify([slab])
        measured = weather.measure([slab])["slab"]
        edge = _corner(measured, (1.0, 0.0, 0.5), (0.0, 0.0, 1.0))
        middle = _corner(measured, (1.0, 1.0, 0.5), (0.0, 0.0, 1.0))
        self.assertGreater(measured["convex"][edge], 0.8)
        self.assertLess(measured["convex"][middle], 0.1)


class Bake(unittest.TestCase):
    def setUp(self):
        common.reset()

    def _scene(self):
        wall = _box("wall", (0.0, 0.0, 0.0), (3.0, 0.2, 2.5))
        sill = _box("sill", (0.0, -0.3, 1.5), (3.0, 0.0, 1.55), "chiluca")
        objects = [wall, sill]
        weather.densify(objects)
        return objects

    def test_bake_writes_rules_attribute(self):
        objects = self._scene()
        weather.bake(objects, "test", blendable_slots=("lime",))

        for o in objects:
            attribute = o.data.color_attributes.get("rules")
            self.assertIsNotNone(attribute)
            self.assertEqual(attribute.domain, "CORNER")
            self.assertEqual(len(attribute.data), len(o.data.loops))
            values = np.array([tuple(c.color) for c in attribute.data])
            self.assertGreaterEqual(values.min(), 0.0)
            self.assertLessEqual(values.max(), 1.0)

        sill = np.array([tuple(c.color) for c in objects[1].data.color_attributes["rules"].data])
        self.assertEqual(sill[:, 1].max(), 0.0)   # chiluca has nothing under it

    def test_bake_is_deterministic(self):
        first = self._scene()
        weather.bake(first, "test", blendable_slots=("lime",))
        a = np.array([tuple(c.color) for c in first[0].data.color_attributes["rules"].data])
        common.reset()
        second = self._scene()
        weather.bake(second, "test", blendable_slots=("lime",))
        b = np.array([tuple(c.color) for c in second[0].data.color_attributes["rules"].data])
        np.testing.assert_array_equal(a, b)


if __name__ == "__main__":
    result = unittest.main(argv=["test_weather_bpy"], exit=False).result
    sys.exit(not result.wasSuccessful())
