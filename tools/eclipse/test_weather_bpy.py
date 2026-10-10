"""weather.py inside Blender: densifying a piece on the world grid, measuring
what is round each face corner, baking the rules, the user's touch-ups.

    Blender -b --factory-startup --python tools/eclipse/test_weather_bpy.py
"""

import os
import sys
import unittest
from pathlib import Path

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

    def test_thin_faces_are_not_cut(self):
        # A rail 5 cm square and 3 m long: nothing for colour to change
        # across, so it keeps its six faces.
        rail = _box("rail", (0.0, 0.0, 1.0), (3.0, 0.05, 1.05))
        weather.densify([rail])
        self.assertEqual(len(rail.data.polygons), 6)

    def test_no_sliver_on_a_slanted_face(self):
        # One edge crosses the grid line x 0.5 at a shallow slant: every
        # corner is at least 2 cm off it, but the strip it would cut off is
        # not, so that cut is left out.
        m = common.Mesh("slant")
        m.face([(0.48, 0.0, 0.0), (1.5, 0.0, 0.0), (1.5, 0.0, 2.0), (0.53, 0.0, 2.0)], "lime")
        slant = m.make()
        weather.densify([slant])
        self.assertGreaterEqual(_thickness(slant).min(), weather.SNAP - 1e-6)

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

    def test_alternates_do_not_shade_each_other(self):
        # A stone column and a steel one stand in one place, never seen
        # together: each is measured with its own set, as the AO bake does.
        wall = _box("wall", (0.0, 0.0, 0.0), (3.0, 0.3, 3.0))
        stone = _box("stone", (1.0, -0.6, 0.0), (1.5, -0.1, 3.0))
        steel = _box("steel", (1.05, -0.55, 0.0), (1.45, -0.15, 3.0), "steel")
        objects = [wall, stone, steel]
        weather.densify(objects)
        sets = [["wall", "stone"], ["wall", "steel"]]
        together = weather.measure(objects, sets=sets)["steel"]["open_sky"]
        alone = weather.measure([wall, steel])["steel"]["open_sky"]
        np.testing.assert_allclose(together, alone)

    def test_glass_does_not_shade(self):
        # Glass over a wall lets the sky through: it is left out of the rays.
        wall = _box("wall", (0.0, 0.0, 0.0), (3.0, 0.3, 2.0))
        pane = _box("pane", (-0.5, -1.0, 2.5), (3.5, 1.0, 2.52), "glass")
        objects = [wall, pane]
        weather.densify(objects)
        under_glass = weather.measure(objects, free=["pane"])["wall"]["open_sky"]
        open_sky = weather.measure([wall])["wall"]["open_sky"]
        np.testing.assert_allclose(under_glass, open_sky)

    def test_a_thin_bar_is_not_darkened_by_its_joints(self):
        # A thin bar has corners only at its ends, where it meets other bars:
        # its sky is sampled in from the joint, so a post on its end does not
        # darken the whole bar (the kiosk canopy's ribs went dark).
        bar = _box("bar", (0.0, 0.0, 2.0), (2.0, 0.05, 2.05))
        post = _box("post", (-0.05, -0.05, 2.05), (0.1, 0.1, 3.0))
        objects = [bar, post]
        weather.densify(objects)
        measured = weather.measure(objects)["bar"]
        joint = _corner(measured, (0.0, 0.0, 2.05), (0.0, 0.0, 1.0))
        self.assertGreater(measured["open_sky"][joint], 0.6)

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

    def test_foot_wear_only_on_named_slots(self):
        # The wall is lime but not named for foot wear: its face low down,
        # clear of every edge (edges chip whatever the slot), stays whole;
        # named, it wears.
        def low_face(foot):
            common.reset()
            objects = self._scene()
            weather.bake(objects, "test", blendable_slots=("lime",), foot_slots=foot)
            rules = weather.read(objects[0].data, "rules")
            points, normals = weather._corners(objects[0].data)
            face = ((np.abs(points[:, 2] - 0.5) < 1e-4) & (points[:, 0] > 0.8) & (points[:, 0] < 2.2)
                    & (normals[:, 1] < -0.99))
            return rules[face, 1]

        self.assertEqual(low_face(()).max(), 0.0)
        self.assertGreater(low_face(("lime",)).max(), 0.0)

    def test_bake_is_deterministic(self):
        first = self._scene()
        weather.bake(first, "test", blendable_slots=("lime",))
        a = np.array([tuple(c.color) for c in first[0].data.color_attributes["rules"].data])
        common.reset()
        second = self._scene()
        weather.bake(second, "test", blendable_slots=("lime",))
        b = np.array([tuple(c.color) for c in second[0].data.color_attributes["rules"].data])
        np.testing.assert_array_equal(a, b)


class Yours(unittest.TestCase):
    """The user's touch-ups: four greyscale layers, harvested to an npz and
    laid over the rules on every build."""

    def setUp(self):
        import tempfile
        common.reset()
        self.kept = weather.YOURS
        self.folder = tempfile.mkdtemp()
        weather.YOURS = Path(self.folder)

    def tearDown(self):
        weather.YOURS = self.kept

    def _scene(self, height=2.5, front=0.0, soot=()):
        wall = _box("wall", (0.0, front, 0.0), (3.0, 0.2, height))
        weather.densify([wall])
        weather.bake([wall], "test", blendable_slots=("lime",), soot=list(soot))
        return [wall]

    def _paint(self, objects, layer, point, normal, value):
        mesh = objects[0].data
        measured = {"points": np.array([tuple(mesh.vertices[l.vertex_index].co) for l in mesh.loops]),
                    "normals": np.array([tuple(mesh.polygons[p.index].normal) for p in mesh.polygons
                                         for _ in p.loop_indices])}
        # Corners in loop order: rebuild normals by loop.
        normals = np.zeros((len(mesh.loops), 3))

        for poly in mesh.polygons:
            normals[list(poly.loop_indices)] = tuple(poly.normal)

        measured["normals"] = normals
        d = np.linalg.norm(measured["points"] - np.array(point), axis=1)
        hit = (d < 1e-4) & (normals @ np.array(normal) > 0.99)
        values = weather.read(mesh, layer)
        values[hit, :3] = value
        mesh.color_attributes[layer].data.foreach_set("color", values.astype(np.float32).ravel())
        return hit

    def _rules_at(self, objects, point, normal):
        mesh = objects[0].data
        normals = np.zeros((len(mesh.loops), 3))

        for poly in mesh.polygons:
            normals[list(poly.loop_indices)] = tuple(poly.normal)

        points = np.array([tuple(mesh.vertices[l.vertex_index].co) for l in mesh.loops])
        hit = (np.linalg.norm(points - np.array(point), axis=1) < 1e-3) & (normals @ np.array(normal) > 0.99)
        return weather.read(mesh, "rules")[hit]

    def test_paint_layers_start_as_rules(self):
        objects = self._scene()
        weather.paint_layers(objects)
        mesh = objects[0].data
        np.testing.assert_allclose(weather.read(mesh, "yours_tint")[:, 0], weather.read(mesh, "rules")[:, 2], atol=1e-6)
        np.testing.assert_allclose(weather.read(mesh, "start_light")[:, 0], weather.read(mesh, "rules")[:, 3], atol=1e-6)

    def test_stroke_survives_a_rebuild(self):
        objects = self._scene()
        weather.paint_layers(objects)
        self._paint(objects, "yours_grime", (1.0, 0.0, 2.0), (0.0, -1.0, 0.0), 1.0)
        self.assertGreater(weather.harvest(objects, "test"), 0)
        neighbour_before = self._rules_at(objects, (1.5, 0.0, 2.0), (0.0, -1.0, 0.0))
        common.reset()
        rebuilt = self._scene()
        self.assertEqual(weather.apply(rebuilt, "test"), [])
        self.assertTrue(np.allclose(self._rules_at(rebuilt, (1.0, 0.0, 2.0), (0.0, -1.0, 0.0))[:, 0], 1.0))
        np.testing.assert_allclose(self._rules_at(rebuilt, (1.5, 0.0, 2.0), (0.0, -1.0, 0.0)), neighbour_before)

    def test_apply_matches_within_a_millimetre(self):
        objects = self._scene()
        weather.paint_layers(objects)
        self._paint(objects, "yours_grime", (1.0, 0.0, 2.0), (0.0, -1.0, 0.0), 1.0)
        weather.harvest(objects, "test")
        common.reset()
        near = self._scene(front=0.0004)
        self.assertEqual(weather.apply(near, "test"), [])
        self.assertTrue(np.allclose(self._rules_at(near, (1.0, 0.0004, 2.0), (0.0, -1.0, 0.0))[:, 0], 1.0))
        common.reset()
        far = self._scene(front=0.003)
        self.assertEqual(len(weather.apply(far, "test")), 1)

    def test_removed_vertex_is_reported(self):
        objects = self._scene()
        weather.paint_layers(objects)
        self._paint(objects, "yours_grime", (1.0, 0.0, 2.0), (0.0, -1.0, 0.0), 1.0)
        weather.harvest(objects, "test")
        common.reset()
        lost = weather.apply(self._scene(height=1.5), "test")
        self.assertEqual(len(lost), 1)
        self.assertIn("grime lost", lost[0])

    def test_harvest_without_layers_keeps_saved(self):
        objects = self._scene()
        weather.paint_layers(objects)
        self._paint(objects, "yours_grime", (1.0, 0.0, 2.0), (0.0, -1.0, 0.0), 1.0)
        weather.harvest(objects, "test")
        saved = (weather.YOURS / "test.npz").read_bytes()
        common.reset()
        self.assertEqual(weather.harvest(self._scene(), "test"), 0)
        self.assertEqual((weather.YOURS / "test.npz").read_bytes(), saved)

    def test_untouched_vertices_follow_new_rules(self):
        objects = self._scene()
        weather.paint_layers(objects)
        self._paint(objects, "yours_grime", (1.0, 0.0, 2.0), (0.0, -1.0, 0.0), 1.0)
        weather.harvest(objects, "test")
        common.reset()
        # A soot plume now rises past the neighbour: the rules change there.
        rebuilt = self._scene(soot=[np.array([2.0, -0.05, 1.6])])
        weather.apply(rebuilt, "test")
        self.assertGreater(self._rules_at(rebuilt, (2.0, 0.0, 2.0), (0.0, -1.0, 0.0))[:, 0].min(), 0.2)
        self.assertTrue(np.allclose(self._rules_at(rebuilt, (1.0, 0.0, 2.0), (0.0, -1.0, 0.0))[:, 0], 1.0))


class Export(unittest.TestCase):
    """common.export_piece with weathering: vertex colour out as COLOR_0,
    soot empties baked and gone."""

    def setUp(self):
        import tempfile
        common.reset()
        self.kept = common.OUT, common.SOURCE, weather.YOURS
        folder = Path(tempfile.mkdtemp())
        common.OUT, common.SOURCE, weather.YOURS = folder / "lab", folder / "source", folder / "yours"

    def tearDown(self):
        common.OUT, common.SOURCE, weather.YOURS = self.kept

    def _export(self):
        import bpy
        _box("wall", (0.0, 0.0, 0.0), (2.0, 0.2, 2.0))
        soot = bpy.data.objects.new("soot_a", None)
        bpy.context.scene.collection.objects.link(soot)
        soot.location = (1.0, -0.1, 1.0)
        common.export_piece("test", 64, ["lime"], weather={"lines": [("z", 0.3)], "blendable": ["lime"]})
        return _glb(common.OUT / "test.glb")

    def test_export_has_color_0(self):
        gltf = self._export()
        attributes = [set(p["attributes"]) for m in gltf["meshes"] for p in m["primitives"]]
        self.assertTrue(all("COLOR_0" in a for a in attributes), attributes)
        self.assertTrue(all("COLOR_1" not in a for a in attributes), attributes)

    def test_no_soot_nodes_exported(self):
        gltf = self._export()
        self.assertEqual([n["name"] for n in gltf["nodes"] if n.get("name", "").startswith("soot_")], [])

    def test_painting_note_written(self):
        self._export()
        self.assertIn("yours_grime", (common.SOURCE / "PAINTING.md").read_text())


def _glb(path):
    import json
    import struct
    data = path.read_bytes()
    length = struct.unpack("<I", data[12:16])[0]
    return json.loads(data[20:20 + length])


if __name__ == "__main__":
    result = unittest.main(argv=["test_weather_bpy"], exit=False).result
    sys.exit(not result.wasSuccessful())
