"""The style lab's kit pieces as built (inside Blender): faces point the way
their side of the wall looks.

    Blender -b --factory-startup --python tools/eclipse/test_kit_bpy.py
"""

import math
import os
import sys
import unittest

import bmesh
import bpy

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import arcade_bay  # noqa: E402
import common  # noqa: E402


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


def _closed(o):
    """Every edge shared by exactly two faces: each solid closed as built
    (common.Mesh welds each of its shells on its own)."""
    bm = bmesh.new()
    bm.from_mesh(o.data)
    open_edges = sum(1 for e in bm.edges if len(e.link_faces) != 2)
    bm.free()
    return open_edges


def _smallest_triangle(o):
    bm = bmesh.new()
    bm.from_mesh(o.data)
    smallest = min(((l[1].vert.co - l[0].vert.co).cross(l[2].vert.co - l[0].vert.co)).length / 2
                   for l in bm.calc_loop_triangles())
    bm.free()
    return smallest


def _tris(o):
    return sum(len(p.vertices) - 2 for p in o.data.polygons)


def _world(o):
    return [o.matrix_world @ v.co for v in o.data.vertices]


class StreetKit(unittest.TestCase):
    """The street kit (cards/street_canal.md) as built."""

    PIECES = ["kerb_straight", "kerb_heaved", "kerb_corner", "kerb_drop", "gutter_grate", "causeway_band",
              "tram_track", "tram_track_shimmed", "tram_track_curve", "tram_conductor", "hatch", "junction_box"]
    BUDGET = {"kerb_straight": 150, "kerb_heaved": 150, "kerb_corner": 150, "kerb_drop": 150, "gutter_grate": 150,
              "causeway_band": 400, "hatch": 200, "junction_box": 200, "tram_track": 400, "tram_track_shimmed": 400,
              "tram_track_curve": 900, "tram_conductor": 200}

    @classmethod
    def setUpClass(cls):
        import street_kit
        street_kit.build()
        cls.objects = {o.name: o for o in bpy.context.scene.objects if o.type == "MESH"}

    def test_every_card_piece_is_an_object(self):
        self.assertEqual(sorted(self.objects), sorted(self.PIECES))

    def test_every_object_is_closed(self):
        open_edges = {n: _closed(o) for n, o in self.objects.items() if _closed(o)}
        self.assertEqual(open_edges, {})

    def test_no_degenerate_triangles(self):
        thin = {n: _smallest_triangle(o) for n, o in self.objects.items() if _smallest_triangle(o) < 1e-7}
        self.assertEqual(thin, {})

    def test_budgets(self):
        over = {n: _tris(o) for n, o in self.objects.items() if _tris(o) > self.BUDGET[n]}
        self.assertEqual(over, {})

    def test_exported_budgets(self):
        """The budgets hold for what went out, densified for its paint."""
        import json
        path = common.SOURCE / "street_kit_faces.json"

        if not path.exists():
            self.skipTest("street_kit not built")

        tris = json.loads(path.read_text())["tris"]
        over = {n: t for n, t in tris.items() if t > self.BUDGET[n]}
        self.assertEqual(over, {})

    def test_flush_pieces_top_at_zero(self):
        """What one walks on lies flush with the setts (a bolt head's few
        millimetres aside: faces under 0.01 m2 are details)."""
        for name in ("causeway_band", "tram_track", "tram_track_curve", "hatch", "gutter_grate"):
            o = self.objects[name]
            tops = [max((o.matrix_world @ o.data.vertices[v].co).z for v in p.vertices)
                    for p in o.data.polygons if p.normal.z > 0.99 and p.area > 0.01]
            self.assertAlmostEqual(max(tops), 0.0, delta=1e-4, msg=name)

    def test_kerb_proud(self):
        top = max(v.z for v in _world(self.objects["kerb_straight"]))
        self.assertAlmostEqual(top, 0.2, delta=1e-6)
        back_top = [v for v in _world(self.objects["kerb_heaved"]) if abs(v.y - 0.3) < 1e-3]
        self.assertAlmostEqual(max(v.z for v in back_top), 0.2, delta=1e-3)
        front = [v for v in _world(self.objects["kerb_heaved"]) if abs(v.y) < 2e-3 and v.z > 0.0]
        self.assertLess(max(v.z for v in front), 0.2 - 0.005)

    def test_curve_matches_its_footprint(self):
        import street_dims
        o = self.objects["tram_track_curve"]
        tops = [o.matrix_world @ v.co for v in o.data.vertices if abs(v.co.z) < 1e-5]

        for x, y in street_dims.footprint("tram_track_curve"):
            nearest = min(((v.x - x) ** 2 + (v.y - y) ** 2) ** 0.5 for v in tops)
            self.assertLess(nearest, 1e-4, (x, y))


class CanalKit(unittest.TestCase):
    """The canal kit (cards/street_canal.md) as built."""

    PIECES = ["canal_wall", "canal_wall_short", "canal_wall_low", "canal_wall_low_short", "canal_wall_low_wet",
              "canal_wall_low_wet_short", "canal_wall_corner",
              "culvert", "culvert_open", "canal_landing_steps", "mooring_ring"]
    BUDGET = {"canal_wall": 600, "canal_wall_short": 600, "canal_wall_low": 600, "canal_wall_low_wet": 600,
              "canal_wall_low_short": 600, "canal_wall_low_wet_short": 600,
              "canal_wall_corner": 600, "culvert": 600, "culvert_open": 600, "canal_landing_steps": 500,
              "mooring_ring": 200}

    @classmethod
    def setUpClass(cls):
        import canal_kit
        canal_kit.build()
        cls.objects = {o.name: o for o in bpy.context.scene.objects if o.type == "MESH"}

    def test_every_piece_is_an_object(self):
        self.assertEqual(sorted(self.objects), sorted(self.PIECES))

    def test_every_object_is_closed(self):
        open_edges = {n: _closed(o) for n, o in self.objects.items() if _closed(o)}
        self.assertEqual(open_edges, {})

    def test_no_degenerate_triangles(self):
        thin = {n: _smallest_triangle(o) for n, o in self.objects.items() if _smallest_triangle(o) < 1e-7}
        self.assertEqual(thin, {})

    def test_budgets(self):
        over = {n: _tris(o) for n, o in self.objects.items() if _tris(o) > self.BUDGET[n]}
        self.assertEqual(over, {})

    def test_exported_budgets(self):
        import json
        path = common.SOURCE / "canal_kit_faces.json"

        if not path.exists():
            self.skipTest("canal_kit not built")

        tris = json.loads(path.read_text())["tris"]
        self.assertEqual({n: t for n, t in tris.items() if t > self.BUDGET[n]}, {})

    def test_coping_flush_and_proud(self):
        """The coping's top lies at the street, its front 0.15 out over the water."""
        o = self.objects["canal_wall"]
        points = _world(o)
        self.assertAlmostEqual(max(v.z for v in points), 0.0, delta=1e-6)
        self.assertAlmostEqual(min(v.y for v in points), -0.15, delta=1e-6)

    def test_water_face_from_the_floor_to_the_coping(self):
        """A ray at the wall from the water meets its face at y 0 from the
        canal's floor up to the coping's underside (the rubble set back)."""
        o = self.objects["canal_wall"]
        hits = []

        for z in (-1.95, -1.5, -1.2):
            hit, at, _, _ = o.ray_cast((2.25, -1.0, z), (0.0, 1.0, 0.0))
            hits.append(round(at.y, 3) if hit else None)

        self.assertEqual(hits, [0.0, 0.0, 0.0])
        hit, at, _, _ = o.ray_cast((2.25, -1.0, -0.6), (0.0, 1.0, 0.0))
        self.assertTrue(hit)
        self.assertAlmostEqual(at.y, 0.04, delta=1e-3)

    def test_steps(self):
        o = self.objects["canal_landing_steps"]
        tops = sorted({round((o.matrix_world @ o.data.vertices[p.vertices[0]].co).z, 4)
                       for p in o.data.polygons if p.normal.z > 0.99})
        self.assertAlmostEqual(tops[-1], 0.0, delta=1e-4)
        self.assertAlmostEqual(tops[0], -5.0 / 6.0, delta=1e-4)

    def test_culvert_open_goes_through(self):
        o = self.objects["culvert_open"]
        hit, _, _, _ = o.ray_cast((2.25, -1.0, -1.2), (0.0, 1.0, 0.0))
        self.assertFalse(hit)

    def test_culvert_is_choked(self):
        """The drain's mouth is dark inside: a ray in meets its back or its silt."""
        o = self.objects["culvert"]
        hit, at, _, _ = o.ray_cast((2.25, -1.0, -1.5), (0.0, 1.0, 0.0))
        self.assertTrue(hit)
        self.assertGreater(at.y, 0.3)


class _BridgeChecks:
    """The stone arch and the seeped steel bridge (cards/street_canal.md):
    each built on its own (a build wipes the scene)."""

    MODULE = None
    CROWN = None
    # Where along its width a ray down meets the parapet's (or railing's) top.
    PARAPET_Y = 1.85

    @classmethod
    def setUpClass(cls):
        import importlib
        module = importlib.import_module(cls.MODULE)
        module.build()
        cls.o = bpy.data.objects[module.NAME]

    def _deck(self):
        """The deck's walking line along the bridge's middle: (x, z) where a
        ray down at y 0 first meets the bridge, every 0.25 m."""
        out = []

        for k in range(-44, 45):
            x = k * 0.25
            # (At the very ends a millimetre in: a ray down the end's edge grazes it.)
            probe = max(-10.999, min(10.999, x))
            hit, at, _, _ = self.o.ray_cast((probe, 0.0, 5.0), (0.0, 0.0, -1.0))
            out.append((x, at.z if hit else None))

        return out

    def test_closed_and_in_budget(self):
        self.assertEqual(_closed(self.o), 0)
        self.assertLessEqual(_tris(self.o), 3000)
        self.assertGreater(_smallest_triangle(self.o), 1e-7)

    def test_exported_budget(self):
        import json
        path = common.SOURCE / (self.MODULE + "_faces.json")

        if not path.exists():
            self.skipTest(self.MODULE + " not built")

        self.assertLessEqual(json.loads(path.read_text())["tris"][self.MODULE], 3000)

    def test_deck_ends_flush_with_the_quays(self):
        line = dict(self._deck())
        self.assertAlmostEqual(line[-11.0], 0.0, delta=1e-3)
        self.assertAlmostEqual(line[11.0], 0.0, delta=1e-3)

    def test_crown(self):
        self.assertAlmostEqual(max(z for _, z in self._deck()), self.CROWN, delta=1e-3)

    def test_deck_walkable(self):
        """No stretch of the deck steeper than 8 degrees."""
        line = self._deck()

        for (x0, z0), (x1, z1) in zip(line, line[1:]):
            self.assertLess(math.degrees(math.atan2(abs(z1 - z0), x1 - x0)), 8.0, x0)

    def test_parapets_stand_their_height(self):
        """At every station the parapet's top is 0.9 over the deck beside it."""
        deck = dict(self._deck())

        for x in (-10.0, -6.0, -3.0, 0.0, 3.0, 6.0, 10.0):
            hit, at, _, _ = self.o.ray_cast((x, self.PARAPET_Y, 5.0), (0.0, 0.0, -1.0))
            self.assertTrue(hit, x)
            self.assertAlmostEqual(at.z - deck[x], 0.9, delta=0.03, msg=x)

    def test_soffit_meets_the_walls_under_the_coping(self):
        """Over the canal (walls' faces at x +-6) the bridge's underside meets
        each wall below its coping's underside (-0.35), so the coping runs
        into the bridge, never across its face."""
        for x in (-5.95, 5.95):
            hit, at, _, _ = self.o.ray_cast((x, 0.0, -1.9), (0.0, 0.0, 1.0))
            self.assertTrue(hit)
            self.assertLess(at.z, -0.35)


class StoneBridge(_BridgeChecks, unittest.TestCase):
    MODULE = "bridge_stone"
    CROWN = 0.6


class SteelBridge(_BridgeChecks, unittest.TestCase):
    MODULE = "bridge_steel"
    CROWN = 0.3
    PARAPET_Y = 2.06


if __name__ == "__main__":
    result = unittest.main(argv=["test_kit_bpy"], exit=False).result
    sys.exit(not result.wasSuccessful())
