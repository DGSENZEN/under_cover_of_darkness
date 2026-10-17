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
import stall  # noqa: E402
import common  # noqa: E402
import gate  # noqa: E402


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

    def test_solid_down_to_the_quays(self):
        """Over the quays (behind the canal walls) the bridge is solid down to
        the quays' foot: no slit under its deck."""
        from bridges import QUAY_FOOT

        for x in (-9.0, -7.0, 7.0, 9.0):
            hit, at, _, _ = self.o.ray_cast((x, 0.0, -0.3), (0.0, 0.0, 1.0))
            self.assertTrue(hit, x)
            self.assertAlmostEqual(at.z, QUAY_FOOT, delta=0.01, msg=x)

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


class Shapes(unittest.TestCase):
    """shapes.lathe and shapes.sag: closed, the size they were asked."""

    def setUp(self):
        common.reset()

    def test_lathe_closed_with_its_volume(self):
        import shapes
        m = common.Mesh("post", outward=True)
        n, r, h = 16, 0.2, 1.0
        shapes.lathe(m, [(r, 0.0), (r, h)], n, "iron")
        o = m.make()
        bm = bmesh.new()
        bm.from_mesh(o.data)
        volume = bm.calc_volume()
        bm.free()
        expected = 0.5 * n * r * r * math.sin(2 * math.pi / n) * h
        self.assertEqual(_closed(o), 0)
        self.assertAlmostEqual(volume, expected, delta=0.02 * expected)
        self.assertGreater(_smallest_triangle(o), 1e-7)

    def test_lathe_to_a_point(self):
        import shapes
        m = common.Mesh("cone", outward=True)
        shapes.lathe(m, [(0.3, 0.0), (0.0, 0.5)], 12, "iron")
        o = m.make()
        self.assertEqual(_closed(o), 0)
        self.assertGreater(_smallest_triangle(o), 1e-7)

    def test_sag_closed_and_hanging(self):
        import shapes
        m = common.Mesh("wire", outward=True)
        shapes.sag(m, (0.0, 0.0, 5.5), (30.0, 0.0, 5.5), 0.02, 6, 0.15, 12, "steel")
        o = m.make()
        self.assertEqual(_closed(o), 0)
        self.assertGreater(_smallest_triangle(o), 1e-7)
        lowest = min(v.z for v in _world(o))
        self.assertAlmostEqual(lowest, 5.5 - 0.15 - 0.02, delta=0.005)


class FurnitureKit(unittest.TestCase):
    """The furniture kit (cards/street_life.md) as built."""

    POSTS = ["bollard_guardstone", "bollard_cannon", "bollard_company", "bollard_chain_post", "bollard_seeped",
             "tram_pole", "tram_pole_lamp", "lamp_dead", "ward_cage_lamp", "tram_stop", "parking_meter",
             "sign_bus_stop", "poster_column", "notice_board", "ward_hoarding"]
    BUDGET = dict({n: 200 for n in ["bollard_guardstone", "bollard_cannon", "bollard_company", "bollard_chain_post",
                                    "bollard_seeped", "chain_span", "span_wire", "trolley_wire"]},
                  **{n: 400 for n in ["tram_pole", "tram_stop", "parking_meter", "sign_bus_stop", "traffic_light_dead",
                                      "payphone_seeped"]},
                  **{n: 600 for n in ["tram_pole_lamp", "lamp_dead", "ward_cage_lamp", "poster_column", "notice_board",
                                      "ward_hoarding", "poster_cluster"]},
                  **{n: 150 for n in ["ward_plate", "sigil_disc", "plaque_talavera", "plate_street"]})

    @classmethod
    def setUpClass(cls):
        import furniture_kit
        furniture_kit.build()
        cls.objects = {o.name: o for o in bpy.context.scene.objects if o.type == "MESH"}

    def test_every_piece_is_an_object(self):
        self.assertEqual(sorted(self.objects), sorted(self.BUDGET))

    def test_every_object_is_closed(self):
        self.assertEqual({n: _closed(o) for n, o in self.objects.items() if _closed(o)}, {})

    def test_no_degenerate_triangles(self):
        self.assertEqual({n: _smallest_triangle(o) for n, o in self.objects.items() if _smallest_triangle(o) < 1e-7}, {})

    def test_budgets(self):
        self.assertEqual({n: _tris(o) for n, o in self.objects.items() if _tris(o) > self.BUDGET[n]}, {})

    def test_exported_budgets(self):
        import json
        path = common.SOURCE / "furniture_kit_faces.json"

        if not path.exists():
            self.skipTest("furniture_kit not built")

        tris = json.loads(path.read_text())["tris"]
        self.assertEqual({n: t for n, t in tris.items() if t > self.BUDGET[n]}, {})

    def test_posts_stand_on_the_ground(self):
        """A post rises from the ground, its foot at most 0.5 m buried."""
        for name in self.POSTS:
            zs = [v.z for v in _world(self.objects[name])]
            self.assertTrue(-0.5 <= min(zs) <= 1e-4 and max(zs) > 0.3, (name, min(zs), max(zs)))

    def test_trolley_wire_hangs(self):
        points = _world(self.objects["trolley_wire"])
        ends = [v.z for v in points if v.x < 0.05]
        self.assertAlmostEqual(sum(ends) / len(ends), 5.5, delta=0.01)
        self.assertAlmostEqual(min(v.z for v in points), 5.5 - 0.15 - 0.015, delta=0.005)

    def test_wires_and_chain_are_thick_enough(self):
        for name in ("trolley_wire", "span_wire", "chain_span"):
            points = [v for v in _world(self.objects[name]) if v.x < 0.3 * min(1.0, max(p.x for p in _world(self.objects[name])))]
            ys = [v.y for v in points]
            self.assertGreaterEqual(max(ys) - min(ys), 0.025, name)


class TradeKit(unittest.TestCase):
    """The trade kit (cards/street_life.md) as built."""

    BUDGET = dict({n: 800 for n in ["cart_hand", "cart_flower", "cart_tamale", "cart_ice", "cart_firewood",
                                    "shoeshine_stand", "stand_curiosities", "shrine_luchador", "crates_relics",
                                    "kiosk_sweets"]},
                  **{n: 1500 for n in ["kiosk_news", "kiosk_lottery", "booth_photographer", "wagon_monster"]})

    @classmethod
    def setUpClass(cls):
        import trade_kit
        trade_kit.build()
        cls.objects = {o.name: o for o in bpy.context.scene.objects if o.type == "MESH"}

    def test_every_piece_is_an_object(self):
        self.assertEqual(sorted(self.objects), sorted(self.BUDGET))

    def test_every_object_is_closed(self):
        self.assertEqual({n: _closed(o) for n, o in self.objects.items() if _closed(o)}, {})

    def test_no_degenerate_triangles(self):
        self.assertEqual({n: _smallest_triangle(o) for n, o in self.objects.items() if _smallest_triangle(o) < 1e-7}, {})

    def test_budgets(self):
        self.assertEqual({n: _tris(o) for n, o in self.objects.items() if _tris(o) > self.BUDGET[n]}, {})

    def test_exported_budgets(self):
        import json
        path = common.SOURCE / "trade_kit_faces.json"

        if not path.exists():
            self.skipTest("trade_kit not built")

        tris = json.loads(path.read_text())["tris"]
        self.assertEqual({n: t for n, t in tris.items() if t > self.BUDGET[n]}, {})

    def test_everything_rests_on_the_ground(self):
        """Wheels, legs and bases touch the ground: none floats, none sinks."""
        lows = {n: min(v.z for v in _world(o)) for n, o in self.objects.items()}
        self.assertEqual({n: z for n, z in lows.items() if abs(z) > 1e-4}, {})


class UncannyKit(unittest.TestCase):
    """The uncanny kit (cards/street_life.md) as built."""

    BUDGET = dict({n: 600 for n in ["secreto_barrier", "claw_scored_slab", "petals_marigold", "candles_drift",
                                    "hatch_sealed", "cage_trap", "cage_trap_chaneque", "cage_trap_lechuza"]},
                  **{n: 1500 for n in ["idol_surfacing", "booth_line_of_dead", "booth_testimony", "offerings_heap"]})

    @classmethod
    def setUpClass(cls):
        import uncanny_kit
        uncanny_kit.build()
        cls.objects = {o.name: o for o in bpy.context.scene.objects if o.type == "MESH"}

    def test_every_piece_is_an_object(self):
        self.assertEqual(sorted(self.objects), sorted(self.BUDGET))

    def test_every_object_is_closed(self):
        self.assertEqual({n: _closed(o) for n, o in self.objects.items() if _closed(o)}, {})

    def test_no_degenerate_triangles(self):
        self.assertEqual({n: _smallest_triangle(o) for n, o in self.objects.items() if _smallest_triangle(o) < 1e-7}, {})

    def test_budgets(self):
        self.assertEqual({n: _tris(o) for n, o in self.objects.items() if _tris(o) > self.BUDGET[n]}, {})

    def test_exported_budgets(self):
        import json
        path = common.SOURCE / "uncanny_kit_faces.json"

        if not path.exists():
            self.skipTest("uncanny_kit not built")

        tris = json.loads(path.read_text())["tris"]
        self.assertEqual({n: t for n, t in tris.items() if t > self.BUDGET[n]}, {})

    def test_flush_pieces(self):
        """The claw-scored slab's top and the sealed hatch's plate lie at the setts' height."""
        for name in ("claw_scored_slab", "hatch_sealed"):
            o = self.objects[name]
            tops = [p for p in o.data.polygons if p.normal.z > 0.99 and p.area > 0.1]
            self.assertTrue(tops, name)
            self.assertAlmostEqual(max(max(o.data.vertices[v].co.z for v in p.vertices) for p in tops), 0.0, delta=1e-4,
                                   msg=name)

    def test_traces_are_not_films(self):
        """Petals and candles stand 4 cm or more off the ground (never a film on it)."""
        for name in ("petals_marigold", "candles_drift", "offerings_heap"):
            self.assertGreaterEqual(max(v.z for v in _world(self.objects[name])), 0.04, name)


class BoundGod(unittest.TestCase):
    """The Bound God's placeholder: a blocky god chained in its cage on its plinth."""

    @classmethod
    def setUpClass(cls):
        import bound_god
        bound_god.build()
        cls.o = bpy.data.objects["bound_god"]

    def _slot(self, poly):
        return self.o.data.materials[poly.material_index].name

    def test_closed_and_in_budget(self):
        self.assertEqual(_closed(self.o), 0)
        self.assertLessEqual(_tris(self.o), 5000)
        self.assertGreater(_smallest_triangle(self.o), 1e-7)

    def test_plinth_top(self):
        tops = [p for p in self.o.data.polygons if p.normal.z > 0.99 and self._slot(p) == "chiluca" and p.area > 1.0]
        self.assertAlmostEqual(max(p.center.z for p in tops), 1.2, delta=1e-4)

    def test_the_god_inside_its_cage(self):
        god = [self.o.data.vertices[v].co for p in self.o.data.polygons if self._slot(p) == "basalt" for v in p.vertices]
        self.assertLess(max(max(abs(c.x), abs(c.y)) for c in god), 1.9)
        self.assertGreaterEqual(min(c.z for c in god), 1.2 - 1e-4)

    def test_open_side_shows_the_god(self):
        """From the south (-Y) the god is seen through the cage's open side."""
        hit, _, _, index = self.o.ray_cast((0.0, -4.0, 3.0), (0.0, 1.0, 0.0))
        self.assertTrue(hit)
        self.assertEqual(self._slot(self.o.data.polygons[index]), "basalt")


class FiguresKit(unittest.TestCase):
    """The figures kit (specs/2026-10-10-zocalo-scenes-design.md): the clay
    stand-ins, their dogs and a pigeon."""

    POSES = ["fig_stand", "fig_queue", "fig_walk", "fig_kneel_pray", "fig_sit_kerb", "fig_sit_chair", "fig_lean_wall",
             "fig_push_cart", "fig_carry_basket", "fig_point", "fig_crouch_inspect", "fig_hold_lantern", "fig_type",
             "fig_dictate", "fig_barker", "fig_photographer", "fig_mourner", "fig_child", "fig_sleep_wall"]
    BUDGET = dict({n: 320 for n in POSES}, fig_child_held=560, dog_sit=200, dog_lie=200, dog_sniff=200, pigeon=90)
    STANDING = ["fig_stand", "fig_queue", "fig_walk", "fig_point", "fig_hold_lantern", "fig_dictate", "fig_carry_basket"]

    @classmethod
    def setUpClass(cls):
        import figures_kit
        figures_kit.build()
        cls.objects = {o.name: o for o in bpy.context.scene.objects if o.type == "MESH"}

    def test_every_piece_is_an_object(self):
        self.assertEqual(sorted(self.objects), sorted(self.BUDGET))

    def test_every_object_is_closed(self):
        self.assertEqual({n: _closed(o) for n, o in self.objects.items() if _closed(o)}, {})

    def test_no_degenerate_triangles(self):
        self.assertEqual({n: _smallest_triangle(o) for n, o in self.objects.items() if _smallest_triangle(o) < 1e-7}, {})

    def test_budgets(self):
        self.assertEqual({n: _tris(o) for n, o in self.objects.items() if _tris(o) > self.BUDGET[n]}, {})

    def test_pigeon_wings_hinged(self):
        """The pigeon's two wings carry their hinge (0 at the shoulder, 1 at
        the tip) and their side (-1 left, +1 right) for the pigeon shader;
        its body neither."""
        o = self.objects["pigeon"]
        self.assertIn("hinge", o.data.attributes)
        hinge = [d.value for d in o.data.attributes["hinge"].data]
        side = [d.value for d in o.data.attributes["side"].data]
        xs = [v.co.x for v in o.data.vertices]
        wing = [k for k, h in enumerate(hinge) if h > 0.0]
        self.assertTrue(wing)
        self.assertEqual({side[k] for k in wing}, {-1.0, 1.0})
        tip = max(range(len(xs)), key=lambda k: abs(xs[k]))
        self.assertAlmostEqual(hinge[tip], 1.0, places=2)
        self.assertTrue(all(0.0 <= h <= 1.0 for h in hinge))
        self.assertTrue(all(side[k] == 0.0 for k, h in enumerate(hinge) if h == 0.0 and abs(xs[k]) < 0.05))

    def test_heights(self):
        tops = {n: max(v.z for v in _world(o)) for n, o in self.objects.items()}
        self.assertEqual({n: round(tops[n], 3) for n in self.STANDING if abs(tops[n] - 1.70) > 0.05}, {})
        self.assertAlmostEqual(tops["fig_child"], 1.15, delta=0.05)

    def test_everything_rests_on_the_ground(self):
        lows = {n: min(v.z for v in _world(o)) for n, o in self.objects.items()}
        self.assertEqual({n: z for n, z in lows.items() if abs(z) > 1e-4}, {})

    def test_hands_recorded(self):
        """Each figure's hands (where a scene puts what it carries), in its own
        frame: the lantern held out at a hip's height, the barker's right hand
        high."""
        import figures_kit
        people = [n for n in self.objects if n.startswith("fig_")]
        self.assertEqual(sorted(figures_kit.HANDS), sorted(people))
        lantern = figures_kit.HANDS["fig_hold_lantern"]["right"]
        self.assertTrue(0.8 < lantern[2] < 1.2 and lantern[1] < -0.15, lantern)
        self.assertGreater(figures_kit.HANDS["fig_barker"]["right"][2], 1.9)

    def test_gate_clean(self):
        import gate
        problems = {}

        for n, o in self.objects.items():
            faces = [{"points": [tuple(o.matrix_world @ o.data.vertices[i].co) for i in p.vertices],
                      "normal": tuple(o.matrix_world.to_3x3() @ p.normal), "owner": n} for p in o.data.polygons]
            found = [p for p in gate.check(faces, 0, []) if not p.startswith("overlap")]

            if found:
                problems[n] = found[:3]

        self.assertEqual(problems, {})


def _card_polys(o, cards):
    return [p for p in o.data.polygons if o.data.materials[p.material_index].name in cards]


def _solid_open_edges(o, cards):
    """_closed() over the object's faces that are not leaf cards."""
    bm = bmesh.new()
    bm.from_mesh(o.data)
    names = [m.name for m in o.data.materials]
    bmesh.ops.delete(bm, geom=[f for f in bm.faces if names[f.material_index] in cards], context="FACES")
    open_edges = sum(1 for e in bm.edges if len(e.link_faces) != 2)
    bm.free()
    return open_edges


class TreesKit(unittest.TestCase):
    """The trees kit (specs/2026-10-10-zocalo-scenes-design.md): the garden's
    trees and iron, leaf cards on lathed trunks (the plan's Ruling 1)."""

    BUDGET = dict({n: 1300 for n in ["tree_ash", "tree_ash_young", "palm_canary", "tree_laurel", "tree_willow"]},
                  ahuehuete_split=1800, tree_guard=300, garden_bench=300, garden_edging=300, garden_shrub=200,
                  flower_clump=120)
    UNDER = ["tree_ash", "tree_laurel", "palm_canary"]

    @classmethod
    def setUpClass(cls):
        import trees_kit
        trees_kit.build()
        cls.cards = trees_kit.CARDS
        cls.objects = {o.name: o for o in bpy.context.scene.objects if o.type == "MESH"}

    def test_every_piece_is_an_object(self):
        self.assertEqual(sorted(self.objects), sorted(self.BUDGET))

    def test_solids_closed(self):
        self.assertEqual({n: _solid_open_edges(o, self.cards) for n, o in self.objects.items()
                          if _solid_open_edges(o, self.cards)}, {})

    def test_cards_two_faced(self):
        """Every card face has its twin facing the other way on the same corners."""
        lonely = {}

        for n, o in self.objects.items():
            polys = _card_polys(o, self.cards)
            keys = {}

            for p in polys:
                key = tuple(sorted(tuple(round(c, 4) for c in o.data.vertices[v].co) for v in p.vertices))
                keys.setdefault(key, []).append(p.normal.copy())

            bad = [k for k, ns in keys.items() if len(ns) != 2 or ns[0].dot(ns[1]) > -0.99]

            if bad:
                lonely[n] = len(bad)

        self.assertEqual(lonely, {})

    def test_cards_uv_their_own_painting(self):
        for n, o in self.objects.items():
            if not _card_polys(o, self.cards):
                continue

            uv = o.data.uv_layers.active.data

            for p in _card_polys(o, self.cards):
                us = sorted({(round(uv[i].uv[0], 3), round(uv[i].uv[1], 3)) for i in p.loop_indices})
                self.assertEqual(us, [(0.0, 0.0), (0.0, 1.0), (1.0, 0.0), (1.0, 1.0)], n)

    def test_cards_rounded_from_their_crown(self):
        """Each card face carries the point its normals round from (`round`)."""
        for n, o in self.objects.items():
            if _card_polys(o, self.cards):
                self.assertIn("round", o.data.attributes, n)

    def test_no_degenerate_triangles(self):
        self.assertEqual({n: _smallest_triangle(o) for n, o in self.objects.items() if _smallest_triangle(o) < 1e-7}, {})

    def test_budgets(self):
        self.assertEqual({n: _tris(o) for n, o in self.objects.items() if _tris(o) > self.BUDGET[n]}, {})

    def test_everything_rests_on_the_ground(self):
        lows = {n: min(v.z for v in _world(o)) for n, o in self.objects.items()}
        self.assertEqual({n: z for n, z in lows.items() if abs(z) > 1e-4}, {})

    def test_a_man_walks_under_the_crowns(self):
        for n in self.UNDER:
            o = self.objects[n]
            low = min(o.data.vertices[v].co.z for p in _card_polys(o, self.cards) for v in p.vertices)
            self.assertGreaterEqual(low, 2.2, n)


class SceneKit(unittest.TestCase):
    """The scene kit (specs/2026-10-10-zocalo-scenes-design.md): the props the
    scenes are staged with."""

    PROPS = ["typewriter_desk", "stool", "chair", "brazier", "comal_pots", "basket", "baskets_stack", "crate",
             "canary_box", "censer", "lantern_carried", "lantern_set", "cart_overturned", "crates_spilled",
             "pulque_barrels", "cart_covered", "laundry_line", "exvoto_plate", "crate_soapbox", "camera_tripod",
             "firewood_stack", "firewood_bundle", "atole_pot", "flowers_bucket"]
    BUDGET = dict({n: 600 for n in PROPS}, barrel_organ=800, coffin_on_chairs=800, typewriter_desk=500)
    HUNG = ["laundry_line"]

    @classmethod
    def setUpClass(cls):
        import scene_kit
        scene_kit.build()
        cls.cards = scene_kit.CARDS
        cls.objects = {o.name: o for o in bpy.context.scene.objects if o.type == "MESH"}

    def test_every_piece_is_an_object(self):
        self.assertEqual(sorted(self.objects), sorted(self.BUDGET))

    def test_solids_closed(self):
        self.assertEqual({n: _solid_open_edges(o, self.cards) for n, o in self.objects.items()
                          if _solid_open_edges(o, self.cards)}, {})

    def test_no_degenerate_triangles(self):
        self.assertEqual({n: _smallest_triangle(o) for n, o in self.objects.items() if _smallest_triangle(o) < 1e-7}, {})

    def test_budgets(self):
        self.assertEqual({n: _tris(o) for n, o in self.objects.items() if _tris(o) > self.BUDGET[n]}, {})

    def test_everything_rests_on_the_ground(self):
        lows = {n: min(v.z for v in _world(o)) for n, o in self.objects.items() if n not in self.HUNG}
        self.assertEqual({n: z for n, z in lows.items() if abs(z) > 1e-4}, {})

    def test_the_laundry_hangs_from_its_line(self):
        o = self.objects["laundry_line"]
        top = max(v.z for v in _world(o))
        self.assertAlmostEqual(top, 3.2 + 0.015, delta=0.02)
        self.assertGreater(min(v.z for v in _world(o)), 1.9)


class DriftKit(unittest.TestCase):
    """The drift kit (the effects plan, Task 2): petals and leaves the wind
    carries, thin closed solids."""

    PIECES = ["petal_a", "petal_b", "leaf_ash", "leaf_laurel"]

    @classmethod
    def setUpClass(cls):
        import drift_kit
        drift_kit.build()
        cls.objects = {o.name: o for o in bpy.context.scene.objects if o.type == "MESH"}

    def test_every_piece_is_an_object(self):
        self.assertEqual(sorted(self.objects), sorted(self.PIECES))

    def test_closed_and_small(self):
        self.assertEqual({n: _closed(o) for n, o in self.objects.items() if _closed(o)}, {})
        self.assertEqual({n: _tris(o) for n, o in self.objects.items() if _tris(o) > 40}, {})

    def test_thick_enough(self):
        """No face under 1 cm across (the gate's sliver rule)."""
        import gate
        thin = {}

        for n, o in self.objects.items():
            faces = [{"points": [tuple(o.data.vertices[i].co) for i in p.vertices], "normal": tuple(p.normal), "owner": n}
                     for p in o.data.polygons]
            found = [p for p in gate.check(faces, 0, []) if "sliver" in p or "degenerate" in p]

            if found:
                thin[n] = found[:2]

        self.assertEqual(thin, {})


class Bevel(unittest.TestCase):
    """Soft bevels for the new standard (Oct 16 2026): a bevelled solid
    stays closed and passes the gate; a bevel too narrow for the sliver
    gate is refused."""

    def _box(self):
        common.reset()
        m = common.Mesh("bevel_box", outward=True)
        m.box((0, 0, 0), (1, 1, 1), "wood")
        return m.make()

    def test_bevelled_box_stays_closed(self):
        o = self._box()
        common.bevel(o, 0.03)
        self.assertEqual(_closed(o), 0)

    def test_bevel_adds_faces(self):
        o = self._box()
        before = len(o.data.polygons)
        common.bevel(o, 0.03)
        self.assertGreater(len(o.data.polygons), before)

    def test_narrow_bevel_refused(self):
        o = self._box()
        with self.assertRaises(ValueError):
            common.bevel(o, 0.005)

    def test_bevelled_box_passes_gate(self):
        o = self._box()
        common.bevel(o, 0.03)
        faces, tris, _ = common.dump_faces([o])
        self.assertEqual(gate.check(faces, tris, []), [])


class Stall(unittest.TestCase):
    """The Underground's hero piece, the curandera's corridor stall
    (docs/superpowers/refs/underground/cards/stall.md): its parts, closed,
    standing on the floor, inside its footprint and budget, its frame and
    counter bevelled (no long hard edge left)."""

    PARTS = ["stall_frame", "stall_counter", "stall_awning", "stall_shelves", "stall_clutter", "stall_ofrenda", "stall_bulb",
             "stall_neon"]

    @classmethod
    def setUpClass(cls):
        stall.build()
        cls.objects = {o.name: o for o in bpy.context.scene.objects if o.type == "MESH"}

    def test_every_part_is_an_object(self):
        self.assertEqual(sorted(self.objects), sorted(self.PARTS))

    def test_every_object_is_closed(self):
        self.assertEqual({n: _closed(o) for n, o in self.objects.items() if _closed(o)}, {})

    def test_no_degenerate_triangles(self):
        self.assertEqual({n: _smallest_triangle(o) for n, o in self.objects.items() if _smallest_triangle(o) < 1e-7}, {})

    def test_stands_on_the_floor(self):
        lowest = min(min(v.z for v in _world(o)) for o in self.objects.values())
        self.assertAlmostEqual(lowest, 0.0, places=4)

    def test_budget(self):
        self.assertLessEqual(sum(_tris(o) for o in self.objects.values()), 20000)

    def test_footprint(self):
        points = [p for o in self.objects.values() for p in _world(o)]
        size = [max(p[k] for p in points) - min(p[k] for p in points) for k in range(3)]
        self.assertTrue(2.2 <= size[0] <= 2.6, size)
        self.assertTrue(1.2 <= size[1] <= 1.6, size)
        self.assertTrue(2.4 <= size[2] <= 2.8, size)

    def test_bevelled(self):
        """No edge longer than 10 cm between faces meeting harder than 60
        degrees on the frame or the counter: every big edge is softened."""
        hard = {}

        for name in ("stall_frame", "stall_counter"):
            bm = bmesh.new()
            bm.from_mesh(self.objects[name].data)
            hard[name] = sum(1 for e in bm.edges if len(e.link_faces) == 2 and e.calc_length() > 0.1
                             and math.degrees(e.calc_face_angle()) > 60)
            bm.free()

        self.assertEqual({n: k for n, k in hard.items() if k}, {})

    def test_passes_the_gate(self):
        faces, tris, _ = common.dump_faces(list(self.objects.values()))
        self.assertEqual(gate.check(faces, tris, [], budget=20000), [])


if __name__ == "__main__":
    result = unittest.main(argv=["test_kit_bpy"], exit=False).result
    sys.exit(not result.wasSuccessful())
