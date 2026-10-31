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
from mathutils import Vector, geometry
from mathutils.bvhtree import BVHTree

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import arcade_bay  # noqa: E402
import stall  # noqa: E402
import underground_ground  # noqa: E402
import underground_services  # noqa: E402
import underground_furniture  # noqa: E402
import underground_floor  # noqa: E402
import underground_walls  # noqa: E402
import underground_vault  # noqa: E402
import underground_uncanny  # noqa: E402
import library_room  # noqa: E402
import library_corner  # noqa: E402
import library_shelves  # noqa: E402
import library_books  # noqa: E402
import library_spectres  # noqa: E402
import library_ward  # noqa: E402
import library_hangings  # noqa: E402
import candle_lane  # noqa: E402
import lane_landmarks  # noqa: E402
import pasaje_shell  # noqa: E402
import pasaje_stalls  # noqa: E402
import pasaje_wares  # noqa: E402
import pasaje_overhead  # noqa: E402
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


def _hit(o, start, direction, reach=20.0):
    """Where a ray from `start` along `direction` first meets `o` (world), or None."""
    tree = BVHTree.FromObject(o, bpy.context.evaluated_depsgraph_get())
    inv = o.matrix_world.inverted()
    found = tree.ray_cast(inv @ Vector(start), (inv.to_3x3() @ Vector(direction)).normalized(), reach)
    return None if found[0] is None else o.matrix_world @ found[0]


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
        self.assertLessEqual(sum(_tris(o) for o in self.objects.values()), 40000)

    def test_footprint(self):
        points = [p for o in self.objects.values() for p in _world(o)]
        size = [max(p[k] for p in points) - min(p[k] for p in points) for k in range(3)]
        self.assertTrue(2.9 <= size[0] <= 3.4, size)
        self.assertTrue(2.2 <= size[1] <= 2.6, size)
        self.assertTrue(2.6 <= size[2] <= 3.0, size)

    def _clear(self, lo, hi):
        """The vertices of the stall inside the box lo..hi (Blender axes)."""
        return [p for o in self.objects.values() for p in _world(o)
                if all(lo[k] < p[k] < hi[k] for k in range(3))]

    def test_room_for_her(self):
        """A person stands behind the counter (the game's body too, a capsule
        1 m across and 2 m tall): an aisle a metre deep and long, clear from
        the floor to 2.05 m (her stool and crates stand outside it)."""
        self.assertEqual(self._clear((-0.6, 0.62, 0.02), (0.3, 1.62, 2.05)), [])

    def test_a_way_in(self):
        """She walks in past the counter's right end: a gap over a metre wide,
        clear to 2.1 m (the game's body too), from the corridor into the aisle."""
        self.assertEqual(self._clear((0.45, -0.3, 0.02), (1.38, 1.6, 2.1)), [])

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
        self.assertEqual(gate.check(faces, tris, [], budget=40000), [])


class UndergroundGround(unittest.TestCase):
    """What lies on the Underground's floor (docs/superpowers/refs/underground/recipe.md):
    each piece its own object at the origin, closed, resting on the floor,
    in its budget, through the gate."""

    BUDGET = {"cone_crushed": 300, "jarrito": 400, "news_spread": 500, "news_folded": 400, "sack_slumped": 600,
              "sack_lying": 600, "crate": 1600, "crate_corn": 2400, "cable_run": 2400, "trompo": 500, "marigold_head": 200}

    @classmethod
    def setUpClass(cls):
        underground_ground.build()
        cls.objects = {o.name: o for o in bpy.context.scene.objects if o.type == "MESH"}

    def test_every_piece_is_an_object(self):
        self.assertEqual(sorted(self.objects), sorted(self.BUDGET))

    def test_every_object_is_closed(self):
        self.assertEqual({n: _closed(o) for n, o in self.objects.items() if _closed(o)}, {})

    def test_everything_rests_on_the_floor(self):
        low = {n: min(v.z for v in _world(o)) for n, o in self.objects.items()}
        self.assertEqual({n: z for n, z in low.items() if abs(z) > 1e-4}, {})

    def test_budgets(self):
        self.assertEqual({n: _tris(o) for n, o in self.objects.items() if _tris(o) > self.BUDGET[n]}, {})

    def _extent(self, name):
        vs = _world(self.objects[name])
        return [max(v[i] for v in vs) - min(v[i] for v in vs) for i in range(3)]

    def test_the_cone_lies_on_its_side_still_a_cone(self):
        # Trodden on one side, it keeps its length: longer than it stands tall, twice over.
        x, y, z = self._extent("cone_crushed")
        self.assertGreaterEqual(max(x, y), 0.16)
        self.assertLessEqual(z, max(x, y) / 2)

    def test_the_cable_drops_from_the_junction_and_ends_in_slack(self):
        # It rises up beside the post into the junction box's bottom (2.66 m), runs 4 m on, and its spare is coiled.
        vs = _world(self.objects["cable_run"])
        riser = [v for v in vs if v.z > 1.0]
        self.assertGreaterEqual(max(v.z for v in riser), 2.68)
        self.assertLess(max(abs(v.x) for v in riser), 0.05)
        x, y, _ = self._extent("cable_run")
        self.assertGreaterEqual(x, 4.0)
        self.assertGreaterEqual(y, 0.3)

    def test_the_lying_sack_is_squat(self):
        # Laid on its side, longer than tall by half again, its neck folded short.
        x, y, z = self._extent("sack_lying")
        self.assertGreaterEqual(max(x, y), 1.5 * z)
        self.assertLessEqual(max(x, y), 0.62)

    def test_each_passes_the_gate(self):
        problems = {}

        for n, o in self.objects.items():
            faces, tris, _ = common.dump_faces([o])
            found = gate.check(faces, tris, [], budget=self.BUDGET[n])
            if found:
                problems[n] = found[:3]

        self.assertEqual(problems, {})


def _segments_apart(a, b):
    """The least distance between two polylines (lists of 3-tuples), sampled finely."""
    def dense(points):
        out = []
        for p, q in zip(points, points[1:]):
            for k in range(6):
                t = k / 6
                out.append(tuple(p[i] + (q[i] - p[i]) * t for i in range(3)))
        return out + [points[-1]]

    return min(math.dist(p, q) for p in dense(a) for q in dense(b))


class UndergroundServices(unittest.TestCase):
    """The services along the Underground's walls (tools/eclipse/underground_services.py):
    each piece its own object built in the wall's frame (the wall is y = 0, the
    piece out into -y), closed, in its budget, through the gate; the mains in
    their colours; cables never through each other."""

    BUDGET = {"pipe_green_4": 1400, "pipe_green_2": 900, "pipe_ochre_4": 1200, "pipe_red_4": 1400,
              "pipe_red_valve": 2600, "pipe_red_drop": 2600, "pipe_blue_4": 1100, "cable_tray_4": 3200,
              "cable_tray_4_spill": 3600, "cable_swag": 1000, "cable_hook": 200, "conduit_drop": 700}
    COLOURS = {"pipe_green_4": "pipe_green", "pipe_green_2": "pipe_green", "pipe_ochre_4": "pipe_ochre",
               "pipe_red_4": "pipe_red", "pipe_red_valve": "pipe_red", "pipe_red_drop": "pipe_red",
               "pipe_blue_4": "pipe_blue", "cable_tray_4": "metro_orange", "cable_tray_4_spill": "metro_orange",
               "conduit_drop": "metro_orange"}

    @classmethod
    def setUpClass(cls):
        underground_services.build()
        cls.objects = {o.name: o for o in bpy.context.scene.objects if o.type == "MESH"}

    def test_every_piece_is_an_object(self):
        self.assertEqual(sorted(self.objects), sorted(self.BUDGET))

    def test_every_object_is_closed(self):
        self.assertEqual({n: _closed(o) for n, o in self.objects.items() if _closed(o)}, {})

    def test_budgets(self):
        self.assertEqual({n: _tris(o) for n, o in self.objects.items() if _tris(o) > self.BUDGET[n]}, {})

    def test_each_passes_the_gate(self):
        problems = {}

        for n, o in self.objects.items():
            faces, tris, _ = common.dump_faces([o])
            found = gate.check(faces, tris, [], budget=self.BUDGET[n])
            if found:
                problems[n] = found[:3]

        self.assertEqual(problems, {})

    def test_wall_pieces_meet_the_wall_and_stop_there(self):
        # Every wall piece's brackets reach the wall face (y = 0) and nothing goes behind it;
        # the conduit stands off its stall's box, not the wall.
        reach = {n: max(v.y for v in _world(o)) for n, o in self.objects.items() if n != "conduit_drop"}
        self.assertEqual({n: y for n, y in reach.items() if not -0.001 <= y <= 0.0005}, {})

    def test_each_main_in_its_colour(self):
        slots = {n: {o.material_slots[p.material_index].material.name for p in o.data.polygons}
                 for n, o in self.objects.items()}
        self.assertEqual({n: c for n, c in self.COLOURS.items() if c not in slots[n]}, {})

    def test_lengths_tile_along_the_wall(self):
        for n, length in (("pipe_green_4", 4.0), ("pipe_green_2", 2.0), ("pipe_ochre_4", 4.0), ("pipe_red_4", 4.0),
                          ("pipe_red_valve", 4.0), ("pipe_blue_4", 4.0), ("cable_tray_4", 4.0)):
            xs = [v.x for v in _world(self.objects[n])]
            self.assertAlmostEqual(min(xs), 0.0, delta=0.025, msg=n)
            self.assertAlmostEqual(max(xs), length, delta=0.025, msg=n)

    def test_the_trays_bundle_never_touches_itself(self):
        cables = underground_services.bundle(4.0)
        clash = [(i, j) for i in range(len(cables)) for j in range(i + 1, len(cables))
                 if _segments_apart(cables[i][2], cables[j][2]) < cables[i][0] + cables[j][0] + 0.002]
        self.assertEqual(clash, [])
        self.assertGreaterEqual(len(cables), 7)

    def test_the_swags_cables_never_touch(self):
        spans = [[(3.0 * i / 14, -out, r - sag * math.sin(math.pi * i / 14)) for i in range(15)]
                 for r, out, sag, _ in underground_services.SWAG]
        radii = [r for r, *_ in underground_services.SWAG]
        clash = [(i, j) for i in range(3) for j in range(i + 1, 3)
                 if _segments_apart(spans[i], spans[j]) < radii[i] + radii[j] + 0.002]
        self.assertEqual(clash, [])

    def test_the_spill_hangs_out_of_the_tray(self):
        # The loose cable's loop hangs a good way below the tray, in front of its front rail.
        vs = _world(self.objects["cable_tray_4_spill"])
        self.assertLess(min(v.z for v in vs), -0.4)
        self.assertLess(min(v.y for v in vs), -underground_services.TRAY_FRONT - 0.05)

    def test_the_conduit_rises_clear_of_the_mains_into_the_tray(self):
        # From the junction box's top (2.85 m) it has swung out in front of the water main (on the
        # box's line, its front 0.09 m before it) by the time it reaches the main's underside (3.16 m).
        path = underground_services.conduit_path()
        before_main = [p for p in path if p[2] >= 3.16 - 2.85 - underground_services.CONDUIT_R - 0.01]
        self.assertTrue(all(p[1] <= -0.18 for p in before_main))
        self.assertAlmostEqual(path[-1][2], underground_services.CONDUIT_RISE, delta=1e-6)


class UndergroundFurniture(unittest.TestCase):
    """The corridor's furniture (tools/eclipse/underground_furniture.py): free pieces
    on the floor at their origin, wall pieces in the wall's frame (the wall y = 0,
    out into -y, the floor z = 0); closed, in budget, through the gate."""

    BUDGET = {"bench": 3000, "tamale_cart": 9000, "stool": 800, "trash_bin": 1800, "niche": 6000,
              "vent_grille": 1400}
    FREE = ("tamale_cart", "stool", "trash_bin")
    WALL = ("bench", "niche", "vent_grille")

    @classmethod
    def setUpClass(cls):
        underground_furniture.build()
        cls.objects = {o.name: o for o in bpy.context.scene.objects if o.type == "MESH"}

    def _extent(self, name):
        vs = _world(self.objects[name])
        return [(min(v[i] for v in vs), max(v[i] for v in vs)) for i in range(3)]

    def test_every_piece_is_an_object(self):
        self.assertEqual(sorted(self.objects), sorted(self.BUDGET))

    def test_every_object_is_closed(self):
        self.assertEqual({n: _closed(o) for n, o in self.objects.items() if _closed(o)}, {})

    def test_budgets(self):
        self.assertEqual({n: _tris(o) for n, o in self.objects.items() if _tris(o) > self.BUDGET[n]}, {})

    def test_each_passes_the_gate(self):
        problems = {}

        for n, o in self.objects.items():
            faces, tris, _ = common.dump_faces([o])
            found = gate.check(faces, tris, [], budget=self.BUDGET[n])
            if found:
                problems[n] = found[:3]

        self.assertEqual(problems, {})

    def test_free_pieces_stand_on_the_floor(self):
        low = {n: self._extent(n)[2][0] for n in self.FREE + ("bench",)}
        self.assertEqual({n: z for n, z in low.items() if abs(z) > 1e-4}, {})

    def test_wall_pieces_meet_the_wall_and_stop_there(self):
        reach = {n: self._extent(n)[1][1] for n in self.WALL}
        self.assertEqual({n: y for n, y in reach.items() if not -0.001 <= y <= 0.0005}, {})

    def test_the_bench_is_sat_on_at_seat_height(self):
        # A Metro bench: 1.6-2 m long, its seat at knee height, its back against the wall.
        (x0, x1), (y0, _), (_, z1) = self._extent("bench")
        self.assertTrue(1.6 <= x1 - x0 <= 2.0)
        self.assertTrue(0.4 <= -y0 <= 0.62)
        self.assertTrue(0.75 <= z1 <= 0.95)
        seat = [v for v in _world(self.objects["bench"]) if abs(v.z - underground_furniture.BENCH_SEAT) < 0.004]
        self.assertGreaterEqual(len(seat), 8)

    def test_the_steamers_lid_is_where_the_steam_rises(self):
        top = max(_world(self.objects["tamale_cart"]), key=lambda v: v.z)
        want = underground_furniture.POT_TOP
        self.assertLess(math.dist((top.x, top.y), want[:2]), 0.05)
        self.assertAlmostEqual(top.z, want[2], delta=0.01)

    def test_the_niche_holds_lit_candles_on_its_shelf(self):
        wicks = common.WICKS.get("niche", [])
        (x0, x1), _, _ = self._extent("niche")
        self.assertGreaterEqual(len(wicks), 5)
        self.assertTrue(all(x0 < w[0] < x1 for w in wicks))
        self.assertTrue(all(underground_furniture.NICHE_SILL < w[2] < underground_furniture.NICHE_SILL + 0.35
                            for w in wicks))

    def test_the_niche_is_glazed_and_keeps_a_place_for_her_image(self):
        names = {s.material.name for s in self.objects["niche"].material_slots}
        self.assertIn("glass", names)
        self.assertIn("print_saint", names)

    def test_the_niches_gable_rises_to_a_peak(self):
        # Its boards' outer ends sit low over the cabinet's top; the peak is in the middle.
        top = underground_furniture.NICHE_SILL + 0.75 + 0.04
        ends = [v.z for v in _world(self.objects["niche"]) if 0.28 <= abs(v.x) <= 0.42 and v.z > top]
        self.assertTrue(ends)
        self.assertLessEqual(max(ends), top + 0.11)

    def test_the_bins_lid_stays_out_of_the_drum(self):
        o = self.objects["trash_bin"]
        inside = []

        for p in o.data.polygons:
            if o.material_slots[p.material_index].material.name != "metro_orange":
                continue
            for i in p.vertices:
                v = o.matrix_world @ o.data.vertices[i].co
                if math.hypot(v.x, v.y) < 0.19 and 0.05 < v.z < 0.695:
                    inside.append(tuple(round(c, 3) for c in v))

        self.assertEqual(inside, [])

    def test_every_paint_used_is_declared(self):
        used = {s.material.name for o in self.objects.values() for s in o.material_slots}
        self.assertEqual(used - set(underground_furniture.SLOTS), set())

    def test_the_vent_is_flush(self):
        self.assertGreaterEqual(self._extent("vent_grille")[1][0], -0.08)


class UndergroundFloor(unittest.TestCase):
    """The Underground's tiled floor in modules (tools/eclipse/underground_floor.py): each
    module 1.2 m along x, its tiles' tops at z = 0, laid edge to edge from y = 0; the
    wall's row of dark border tiles along +y; a drain set flush."""

    BUDGET = {"floor_field": 3200, "floor_field_worn": 3600, "floor_border": 3200, "floor_border_drain": 4200,
              "floor_edge": 2600}
    DEPTH = {"floor_field": 1.2, "floor_field_worn": 1.2, "floor_border": 1.2, "floor_border_drain": 1.2,
             "floor_edge": 0.9}

    @classmethod
    def setUpClass(cls):
        underground_floor.build()
        cls.objects = {o.name: o for o in bpy.context.scene.objects if o.type == "MESH"}

    def _faces_of(self, name, slot):
        o = self.objects[name]
        return [[o.matrix_world @ o.data.vertices[i].co for i in p.vertices] for p in o.data.polygons
                if o.material_slots[p.material_index].material.name == slot]

    def test_every_piece_is_an_object(self):
        self.assertEqual(sorted(self.objects), sorted(self.BUDGET))

    def test_every_object_is_closed(self):
        self.assertEqual({n: _closed(o) for n, o in self.objects.items() if _closed(o)}, {})

    def test_budgets(self):
        self.assertEqual({n: _tris(o) for n, o in self.objects.items() if _tris(o) > self.BUDGET[n]}, {})

    def test_each_passes_the_gate(self):
        problems = {}

        for n, o in self.objects.items():
            faces, tris, _ = common.dump_faces([o])
            found = gate.check(faces, tris, [], budget=self.BUDGET[n])
            if found:
                problems[n] = found[:3]

        self.assertEqual(problems, {})

    def test_modules_lay_edge_to_edge(self):
        # Exactly their footprint, so they tile with no gap and no overlap.
        for n, o in self.objects.items():
            vs = _world(o)
            box = [(min(v[i] for v in vs), max(v[i] for v in vs)) for i in range(2)]
            self.assertAlmostEqual(box[0][0], 0.0, delta=0.001, msg=n)
            self.assertAlmostEqual(box[0][1], 1.2, delta=0.001, msg=n)
            self.assertAlmostEqual(box[1][0], 0.0, delta=0.001, msg=n)
            self.assertAlmostEqual(box[1][1], self.DEPTH[n], delta=0.001, msg=n)

    def test_walked_on_at_floor_height(self):
        # Nothing stands proud of the floor; the tiles' tops are at it, give or take their settling.
        for n, o in self.objects.items():
            top = max(v.z for v in _world(o))
            self.assertLessEqual(top, 0.0005, n)
            self.assertGreaterEqual(top, -0.003, n)

    def test_the_border_row_runs_along_the_wall(self):
        for n in ("floor_border", "floor_border_drain", "floor_edge"):
            dark = self._faces_of(n, "tile_dark")
            self.assertTrue(dark, n)
            self.assertTrue(all(v.y >= self.DEPTH[n] - underground_floor.TILE - 0.001 for f in dark for v in f), n)

    def test_the_drain_is_flush_and_open(self):
        # Its grate's top at the floor; no tile in its hole; dark below it.
        grate = self._faces_of("floor_border_drain", "steel")
        self.assertAlmostEqual(max(v.z for f in grate for v in f), 0.0, delta=0.001)
        (x0, x1), (y0, y1) = underground_floor.DRAIN
        tiles = [f for slot in ("tile_cream", "tile_terra", "tile_dark")
                 for f in self._faces_of("floor_border_drain", slot)
                 if all(x0 + 0.01 < v.x < x1 - 0.01 and y0 + 0.01 < v.y < y1 - 0.01 for v in f)]
        self.assertEqual(tiles, [])
        sump = self._faces_of("floor_border_drain", "soot_black")
        self.assertLess(min(v.z for f in sump for v in f), -0.15)

    def test_the_worn_module_is_worn(self):
        # A sunk tile, a cracked one in two, a cement patch.
        o = self.objects["floor_field_worn"]
        self.assertTrue(self._faces_of("floor_field_worn", "cement"))
        self.assertLess(min(v.z for f in self._faces_of("floor_field_worn", "tile_terra") + self._faces_of(
            "floor_field_worn", "tile_cream") for v in f if v.z > -0.02), -0.004)
        self.assertGreater(len(o.data.polygons), len(self.objects["floor_field"].data.polygons))


class UndergroundWalls(unittest.TestCase):
    """The Underground's tiled walls (tools/eclipse/underground_walls.py): panels 1.2 m
    along x, from the wall's face (y = 0) out to the tiles' face (y = -FACE), floor to
    vault; tiles in running bond seamless panel to panel; a dark skirting, the line's
    band; worn panels, a crack showing the older stone behind; a name tablet."""

    PANELS = ("wall_tiled", "wall_tiled_worn", "wall_crack")
    BUDGET = {"wall_tiled": 4200, "wall_tiled_worn": 4600, "wall_crack": 5200, "name_tablet": 2400}

    @classmethod
    def setUpClass(cls):
        underground_walls.build()
        cls.objects = {o.name: o for o in bpy.context.scene.objects if o.type == "MESH"}

    def _faces_of(self, name, slot):
        o = self.objects[name]
        return [[o.matrix_world @ o.data.vertices[i].co for i in p.vertices] for p in o.data.polygons
                if o.material_slots[p.material_index].material.name == slot]

    def test_every_piece_is_an_object(self):
        self.assertEqual(sorted(self.objects), sorted(self.BUDGET))

    def test_every_object_is_closed(self):
        self.assertEqual({n: _closed(o) for n, o in self.objects.items() if _closed(o)}, {})

    def test_budgets(self):
        self.assertEqual({n: _tris(o) for n, o in self.objects.items() if _tris(o) > self.BUDGET[n]}, {})

    def test_each_passes_the_gate(self):
        problems = {}

        for n, o in self.objects.items():
            faces, tris, _ = common.dump_faces([o])
            found = gate.check(faces, tris, [], budget=self.BUDGET[n])
            if found:
                problems[n] = found[:3]

        self.assertEqual(problems, {})

    def test_panels_fill_their_place_exactly(self):
        # Floor to vault, edge to edge, from the wall's face to the tiles' face and no further.
        for n in self.PANELS:
            vs = _world(self.objects[n])
            ext = [(min(v[i] for v in vs), max(v[i] for v in vs)) for i in range(3)]
            self.assertAlmostEqual(ext[0][0], 0.0, delta=0.001, msg=n)
            self.assertAlmostEqual(ext[0][1], underground_walls.PANEL, delta=0.001, msg=n)
            self.assertAlmostEqual(ext[1][1], 0.0, delta=0.0005, msg=n)
            self.assertAlmostEqual(ext[1][0], -underground_walls.FACE, delta=0.0005, msg=n)
            self.assertAlmostEqual(ext[2][0], 0.0, delta=0.001, msg=n)
            self.assertAlmostEqual(ext[2][1], underground_walls.HEIGHT, delta=0.001, msg=n)

    def test_the_bond_runs_on_across_panels(self):
        # Each course's tiles meet the panel's ends with half a joint, so the next panel carries it on.
        for n in self.PANELS:
            ends = [v.x for slot in ("tile_wall", "tile_dark", "tile_line") for f in self._faces_of(n, slot)
                    for v in f if v.y < -underground_walls.FACE + 0.001]
            self.assertAlmostEqual(min(ends), underground_walls.JOINT / 2, delta=0.001, msg=n)
            self.assertAlmostEqual(max(ends), underground_walls.PANEL - underground_walls.JOINT / 2, delta=0.001, msg=n)

    def test_the_skirting_and_the_band(self):
        dark = self._faces_of("wall_tiled", "tile_dark")
        line = self._faces_of("wall_tiled", "tile_line")
        self.assertTrue(dark and line)
        self.assertLessEqual(max(v.z for f in dark for v in f), underground_walls.SKIRTING + 0.001)
        lo, hi = underground_walls.BAND
        self.assertTrue(all(lo - 0.001 <= v.z <= hi + 0.001 for f in line for v in f))

    def test_the_worn_panel_has_lost_and_odd_tiles(self):
        plain, worn = (len(self._faces_of(n, "tile_wall")) for n in ("wall_tiled", "wall_tiled_worn"))
        self.assertLess(worn, plain)
        self.assertTrue(self._faces_of("wall_tiled_worn", "tile_odd"))

    def test_the_crack_shows_the_older_stone_and_a_place_for_its_glyph(self):
        stone = self._faces_of("wall_crack", "stone_old")
        glyph = self._faces_of("wall_crack", "glyph_blank")
        self.assertTrue(stone and glyph)
        (x0, x1), (z0, z1) = underground_walls.CRACK
        self.assertTrue(all(x0 - 0.001 <= v.x <= x1 + 0.001 and z0 - 0.001 <= v.z <= z1 + 0.001 for f in glyph for v in f))
        tiles = [f for slot in ("tile_wall", "tile_dark", "tile_line") for f in self._faces_of("wall_crack", slot)
                 if all(x0 + 0.05 < v.x < x1 - 0.05 and z0 + 0.05 < v.z < z1 - 0.05 for v in f)]
        self.assertEqual(tiles, [])

    def test_the_tablet_stands_on_the_tiles_and_leaves_its_name_blank(self):
        vs = _world(self.objects["name_tablet"])
        self.assertAlmostEqual(max(v.y for v in vs), 0.0, delta=0.0005)
        self.assertTrue(self._faces_of("name_tablet", "sign"))


class UndergroundVault(unittest.TestCase):
    """The corridor's plastered vault in spans (tools/eclipse/underground_vault.py): its underside
    at z = 0, from the back wall's face (y = 0) across to the far wall's, SPAN along x."""

    @classmethod
    def setUpClass(cls):
        underground_vault.build()
        cls.objects = {o.name: o for o in bpy.context.scene.objects if o.type == "MESH"}

    def test_one_span_closed_in_budget_through_the_gate(self):
        self.assertEqual(sorted(self.objects), ["vault_span"])
        o = self.objects["vault_span"]
        self.assertEqual(_closed(o), 0)
        faces, tris, _ = common.dump_faces([o])
        self.assertEqual(gate.check(faces, tris, [], budget=400), [])

    def test_the_span_fills_its_place(self):
        vs = _world(self.objects["vault_span"])
        ext = [(min(v[i] for v in vs), max(v[i] for v in vs)) for i in range(3)]
        self.assertAlmostEqual(ext[0][0], 0.0, delta=0.001)
        self.assertAlmostEqual(ext[0][1], underground_vault.SPAN, delta=0.001)
        self.assertAlmostEqual(ext[1][0], 0.0, delta=0.001)
        self.assertAlmostEqual(ext[1][1], underground_vault.DEPTH, delta=0.001)
        self.assertAlmostEqual(ext[2][0], 0.0, delta=0.001)


class UndergroundUncanny(unittest.TestCase):
    """The Underground's uncanny (tools/eclipse/underground_uncanny.py): the nahual, an enormous
    black dog lying with its head up (its head its own object, turned about the neck), and the
    old man's hat it leaves on the bench; closed, in budget, through the gate."""

    BUDGET = {"nahual_body": 20000, "nahual_head": 8000, "old_hat": 600, "shade_capirote": 12000, "shade_veiled": 12000,
              "shade_child": 12000, "shade_sombrero": 12000,
              "anima_hand_reach": 4000, "anima_hand_claw": 4000}
    # (A creature's tight curves: gated at gate.CREATURE_SLIVER, docs/superpowers/refs/underground/nahual_refs.md.)
    CREATURE = ("nahual_body", "nahual_head", "shade_capirote", "shade_veiled", "shade_child", "shade_sombrero", "anima_hand_reach",
                "anima_hand_claw")

    @classmethod
    def setUpClass(cls):
        underground_uncanny.build()
        cls.objects = {o.name: o for o in bpy.context.scene.objects if o.type == "MESH"}

    def _extent(self, name):
        vs = _world(self.objects[name])
        return [(min(v[i] for v in vs), max(v[i] for v in vs)) for i in range(3)]

    def _slots(self, name):
        o = self.objects[name]
        return {o.material_slots[p.material_index].material.name for p in o.data.polygons}

    def test_every_piece_is_an_object(self):
        self.assertEqual(sorted(self.objects), sorted(self.BUDGET))

    def test_every_object_is_closed(self):
        self.assertEqual({n: _closed(o) for n, o in self.objects.items() if _closed(o)}, {})

    def test_budgets(self):
        self.assertEqual({n: _tris(o) for n, o in self.objects.items() if _tris(o) > self.BUDGET[n]}, {})

    def test_each_passes_the_gate(self):
        problems = {}

        for n, o in self.objects.items():
            faces, tris, _ = common.dump_faces([o])
            found = gate.check(faces, tris, [], budget=self.BUDGET[n],
                               sliver=gate.CREATURE_SLIVER if n in self.CREATURE else gate.SLIVER)
            if found:
                problems[n] = found[:3]

        self.assertEqual(problems, {})

    def test_one_fused_surface(self):
        # Its parts fused into one closed surface (the Colima dogs' one smooth volume, no joins):
        # every face reachable from every other.
        for n in ("nahual_body", "nahual_head"):
            bm = bmesh.new()
            bm.from_mesh(self.objects[n].data)
            black = [f for f in bm.faces if self.objects[n].material_slots[f.material_index].material.name == "nahual_black"]
            seen, todo = {black[0]}, [black[0]]
            while todo:
                f = todo.pop()
                for e in f.edges:
                    for g in e.link_faces:
                        if g not in seen:
                            seen.add(g)
                            todo.append(g)
            self.assertEqual(len(seen), len(black), n)
            bm.free()

    def test_an_enormous_dog_lying_on_the_floor(self):
        # Lying, it is 1.2-1.6 m from its tail to its forepaws, its body on the floor.
        (x0, x1), (y0, y1), (z0, z1) = self._extent("nahual_body")
        self.assertAlmostEqual(z0, 0.0, delta=1e-4)
        self.assertTrue(1.2 <= x1 - x0 <= 1.6, x1 - x0)
        self.assertTrue(0.4 <= y1 - y0 <= 0.8, y1 - y0)

    def test_the_head_held_up_from_the_neck(self):
        # The head's own axes are the neck's: it reaches forward of them along +X, held up so
        # its eyes are 0.6-0.9 m over the floor when set on the body's NECK.
        (x0, x1), _, (z0, z1) = self._extent("nahual_head")
        self.assertGreater(x1, 0.3)
        self.assertGreater(x1, -x0 * 2)
        neck = underground_uncanny.NECK
        eyes = [v for v in _world(self.objects["nahual_head"]) if v.x > 0.08]
        self.assertTrue(0.6 <= neck[2] + max(v.z for v in eyes) - 0.1 <= 0.95)

    def test_all_black_but_its_eyes(self):
        self.assertEqual(self._slots("nahual_body"), {"nahual_black"})
        self.assertEqual(self._slots("nahual_head"), {"nahual_black", "ember"})
        ember = [p for p in self.objects["nahual_head"].data.polygons
                 if self.objects["nahual_head"].material_slots[p.material_index].material.name == "ember"]
        ys = [self.objects["nahual_head"].data.vertices[p.vertices[0]].co.y for p in ember]
        self.assertTrue(min(ys) < -0.03 and max(ys) > 0.03, "two eyes, one each side")

    def _width_at(self, x, above=0.12):
        ys = [v.y for v in _world(self.objects["nahual_body"]) if abs(v.x - x) < 0.03 and v.z > above]
        return max(ys) - min(ys)

    def _depth_at(self, x):
        zs = [v.z for v in _world(self.objects["nahual_body"]) if abs(v.x - x) < 0.03 and abs(v.y) < 0.06]
        return max(zs) - min(zs)

    def test_modelled_not_primitive(self):
        # One smooth skin, not tubes: many faces, and nearly all of them smooth-shaded quads' halves.
        body, head = self.objects["nahual_body"], self.objects["nahual_head"]
        self.assertGreater(len(body.data.polygons), 1500)
        self.assertGreater(len(head.data.polygons), 450)

    def test_a_xolos_build(self):
        # The xoloitzcuintle: a deep chest, a waist tucked up narrow behind it, the haunches broader again.
        chest, waist = self._depth_at(underground_uncanny.CHEST_X), self._depth_at(underground_uncanny.WAIST_X)
        self.assertLess(waist, 0.8 * chest)
        # (Measured above the folded thighs: the torso's own width.)
        self.assertLess(self._width_at(underground_uncanny.WAIST_X, 0.28), self._width_at(underground_uncanny.CHEST_X, 0.28))

    def test_tall_ears_and_a_long_muzzle(self):
        vs = _world(self.objects["nahual_head"])
        top = max(v.z for v in vs)
        nose = max(v.x for v in vs)
        self.assertGreater(top, 0.28)
        self.assertGreater(nose, 0.34)

    SHADES = ("shade_capirote", "shade_veiled", "shade_child", "shade_sombrero")

    def _slots_of(self, name):
        o = self.objects[name]
        return {o.material_slots[p.material_index].material.name for p in o.data.polygons}

    def test_the_shades_are_shrouds_their_heights(self):
        # The procession (shade_refs.md): a shroud each, no body in it; floating, their hems off the floor.
        for n, (lo, hi) in (("shade_capirote", (1.95, 2.45)), ("shade_veiled", (1.55, 1.8)), ("shade_child", (1.0, 1.3)),
                            ("shade_sombrero", (1.8, 2.05))):
            vs = _world(self.objects[n])
            self.assertTrue(0.04 <= min(v.z for v in vs) <= 0.16, "%s floats %.2f" % (n, min(v.z for v in vs)))
            self.assertTrue(lo <= max(v.z for v in vs) <= hi, "%s %.2f" % (n, max(v.z for v in vs)))

    def test_their_faces_are_hollows_in_their_hoods(self):
        # The face a black recess facing +x, high in the hood.
        for n in self.SHADES:
            o = self.objects[n]
            hollow = [p for p in o.data.polygons if o.material_slots[p.material_index].material.name == "hollow"]
            self.assertTrue(hollow, n)
            top = max(v.z for v in _world(o))
            middle = sum((o.matrix_world @ p.center for p in hollow), Vector()) / len(hollow)
            self.assertGreater(middle.x, 0.02, n)
            self.assertGreater(middle.z, 0.6 * top, n)

    def test_their_hems_are_ragged(self):
        for n in self.SHADES:
            low = sorted(v.z for v in _world(self.objects[n]))[:60]
            self.assertGreater(low[-1] - low[0], 0.04, n)

    def test_their_sleeves_meet_at_the_candle(self):
        for n in self.SHADES:
            hand = underground_uncanny.CANDLE_HELD[n]
            near = [v for v in _world(self.objects[n]) if math.dist((v.x, v.y, v.z), hand) < 0.09]
            self.assertTrue(near, n)

    def test_the_sombrero_is_wide(self):
        all_vs = _world(self.objects["shade_sombrero"])
        vs = [v for v in all_vs if v.z > 0.88 * max(v.z for v in all_vs)]
        self.assertGreater(max(v.y for v in vs) - min(v.y for v in vs), 0.5)

    def test_the_animas_hands_reach_up(self):
        # The ánimas (the retablos' souls in purgatory: hands reaching up out of the flames): real hands from the
        # CC0 base body, cut at the forearm, standing upright from it (z 0) with the fingers up, 20-32 cm tall,
        # one open and reaching, one clawing.
        for n in ("anima_hand_reach", "anima_hand_claw"):
            o = self.objects[n]
            vs = _world(o)
            low, top = min(v.z for v in vs), max(v.z for v in vs)
            self.assertAlmostEqual(low, 0.0, delta=0.003, msg=n)
            self.assertTrue(0.2 <= top <= 0.32, "%s %.2f" % (n, top))
            self.assertGreater(len(o.data.vertices), 600, n)
            # Five fingers: the top fifth splits into several separate tips across its width.
            tips = [v for v in vs if v.z > top - 0.035]
            xs = sorted(round(v.x, 2) for v in tips)
            self.assertGreater(max(xs) - min(xs), 0.045, n)

    def test_the_old_mans_hat(self):
        (x0, x1), _, (z0, z1) = self._extent("old_hat")
        self.assertAlmostEqual(z0, 0.0, delta=1e-4)
        self.assertTrue(0.45 <= x1 - x0 <= 0.6)
        self.assertTrue(0.1 <= z1 - z0 <= 0.2)


class LibraryRoom(unittest.TestCase):
    """The librarian's shop, its room (tools/eclipse/library_room.py): the shopfront's outer face at
    y = -FRONT_T, the room from y = 0 to DEPTH (Godot's -z), x across, the floor at z = 0; closed, in budget,
    through the gate; a way in the player fits; the vault where the design puts it; built to any size."""

    BUDGET = {"room_vault": 24000, "room_back": 4000, "room_front": 9000, "room_floor": 6000, "room_rug": 800}

    @classmethod
    def setUpClass(cls):
        library_room.build()
        cls.objects = {o.name: o for o in bpy.context.scene.objects if o.type == "MESH"}

    def test_every_piece_is_an_object(self):
        self.assertEqual(sorted(self.objects), sorted(self.BUDGET))

    def test_every_object_is_closed(self):
        self.assertEqual({n: _closed(o) for n, o in self.objects.items() if _closed(o)}, {})

    def test_budgets(self):
        self.assertEqual({n: _tris(o) for n, o in self.objects.items() if _tris(o) > self.BUDGET[n]}, {})

    def test_each_passes_the_gate(self):
        problems = {}

        for n, o in self.objects.items():
            faces, tris, _ = common.dump_faces([o])
            found = gate.check(faces, tris, [], budget=self.BUDGET[n])
            if found:
                problems[n] = found[:3]

        self.assertEqual(problems, {})

    def test_the_way_in(self):
        # Through the arch: nothing in the way across the player's width up to 2.1 m, from the corridor in.
        front = self.objects["room_front"]
        blocked = []

        for i in range(12):
            x = -0.55 + 0.1 * i
            for k in range(15):
                z = 0.05 + 0.147 * k
                if _hit(front, (x, -2.0, z), (0.0, 1.0, 0.0), 3.0) is not None:
                    blocked.append((round(x, 2), round(z, 2)))

        self.assertEqual(blocked, [])

    @staticmethod
    def _soffit(vault, x, y):
        """The vault's underside over (x, y): the lowest of a few rays up round it (one may go up a joint)."""
        hits = [_hit(vault, (x + dx, y + dy, 2.0), (0.0, 0.0, 1.0)) for dx in (-0.03, 0.0, 0.03) for dy in (-0.11, 0.0, 0.11)]
        return min(h.z for h in hits if h is not None)

    def test_the_vault(self):
        vault = self.objects["room_vault"]
        self.assertAlmostEqual(self._soffit(vault, 0.0, library_room.DEPTH / 2), library_room.CROWN, delta=0.02)
        # At the side walls' inner faces the soffit comes down to the springing.
        edge = _hit(vault, (-library_room.WIDTH / 2 + 0.03, library_room.DEPTH / 2, 1.0), (0.0, 0.0, 1.0))
        self.assertIsNotNone(edge)
        self.assertAlmostEqual(edge.z, library_room.SPRING, delta=0.06)
        # The side walls stand from the floor to it: nothing between them across the room below the springing.
        self.assertIsNone(_hit(vault, (-library_room.WIDTH / 2 + 0.01, library_room.DEPTH / 2, 1.5), (1.0, 0.0, 0.0),
                               library_room.WIDTH - 0.02))

    def test_its_atlas_holds_its_bricks(self):
        # Thousands of bricks are thousands of islands: packed with a fixed small margin (a fraction of the atlas
        # each swamps them), the room keeps a density to paint at (the stall's is 92 px/m at 2048).
        try:
            objects = list(self.objects.values())
            common.unwrap(objects)
            common.to_metres(objects)
            common.pack(objects, margin=library_room.PACK_MARGIN)
            self.assertGreater(common.density(objects, library_room.ATLAS), 90.0)
        finally:
            library_room.build()
            type(self).objects = {o.name: o for o in bpy.context.scene.objects if o.type == "MESH"}

    def test_built_to_any_size(self):
        try:
            library_room.build(width=6.0, depth=5.0, crown=4.0)
            objects = {o.name: o for o in bpy.context.scene.objects if o.type == "MESH"}
            boards = [v for v in _world(objects["room_floor"]) if v.y > 0.05]
            self.assertAlmostEqual(max(v.x for v in boards) - min(v.x for v in boards), 6.0, delta=0.05)
            self.assertAlmostEqual(max(v.y for v in boards), 5.0, delta=0.05)
            self.assertAlmostEqual(self._soffit(objects["room_vault"], 0.0, 2.5), 4.0, delta=0.02)
        finally:
            # (Put back as the other tests found it.)
            library_room.build()
            type(self).objects = {o.name: o for o in bpy.context.scene.objects if o.type == "MESH"}


class LibraryCorner(unittest.TestCase):
    """The librarian's corner (tools/eclipse/library_corner.py), built in its own frame: the desk's middle at the
    origin on the floor, its front (the customers' side) toward -y (Godot's +z, the shopfront); closed, in
    budget, through the gate; what lies on the desk lies on it."""

    BUDGET = {"desk": 6000, "desk_chair": 2500, "lamp": 2000, "ledger": 1500, "magnifier": 800, "gloves": 1200,
              "repair_kit": 1500, "coat_hook": 5000,
              "rituale": 2500, "stole": 2500, "crucifix": 2500, "aspergillum": 2500, "salt_tin": 2500,
              "oil_phial": 2500, "reliquary": 4000, "benedict_medal": 2500,
              "hunt_rack": 5000, "stakes": 3500, "sword_cane": 3500, "revolver": 3500, "rounds": 3500, "crossbow": 3500,
              "bandolier": 3500, "chains": 3500, "trap_jaws": 3500,
              "chained_book_rest": 2500, "chained_book_cover": 1500, "chained_book_block": 1500, "chained_book_chain": 3500,
              "quarantine_cage": 9000}
    BUDGET.update({"quarantine_book_%d" % k: 600 for k in range(7)})
    # His hunting things, each hung on the rack (the rounds stand on its shelf).
    HUNT = ["stakes", "sword_cane", "revolver", "rounds", "crossbow", "bandolier", "chains", "trap_jaws"]
    # What lies on the desk top (the lamp stands on its foot; its shade hangs over the ledger on purpose).
    ON_DESK = ["ledger", "magnifier", "gloves", "repair_kit", "rituale", "crucifix", "salt_tin", "oil_phial", "reliquary",
               "aspergillum"]

    @classmethod
    def setUpClass(cls):
        library_corner.build()
        cls.objects = {o.name: o for o in bpy.context.scene.objects if o.type == "MESH"}

    def _extent(self, name):
        vs = _world(self.objects[name])
        return [(min(v[i] for v in vs), max(v[i] for v in vs)) for i in range(3)]

    def test_every_piece_is_an_object(self):
        self.assertEqual(sorted(self.objects), sorted(self.BUDGET))

    def test_every_object_is_closed(self):
        self.assertEqual({n: _closed(o) for n, o in self.objects.items() if _closed(o)}, {})

    def test_budgets(self):
        self.assertEqual({n: _tris(o) for n, o in self.objects.items() if _tris(o) > self.BUDGET[n]}, {})

    def test_each_passes_the_gate(self):
        problems = {}

        for n, o in self.objects.items():
            faces, tris, _ = common.dump_faces([o])
            found = gate.check(faces, tris, [], budget=self.BUDGET[n])
            if found:
                problems[n] = found[:3]

        self.assertEqual(problems, {})

    def test_desk_height(self):
        # The writing top, met by a ray down onto the desk's middle (the ledger and the rest left out).
        top = _hit(self.objects["desk"], (0.0, 0.05, 3.0), (0.0, 0.0, -1.0))
        self.assertIsNotNone(top)
        self.assertAlmostEqual(top.z, library_corner.DESK_TOP, delta=0.01)

    def test_desk_faces_the_customers(self):
        # Its scuffed front panel is the desk's -y face: a ray from the customers' side meets it low down.
        front = _hit(self.objects["desk"], (0.0, -2.0, 0.5), (0.0, 1.0, 0.0))
        self.assertIsNotNone(front)
        self.assertLess(front.y, -0.3)

    def test_lamp_bulb(self):
        bulb = Vector(common.WICKS["lamp"][0])
        (x0, x1), (y0, y1), (z0, z1) = self._extent("lamp")
        self.assertTrue(x0 < bulb.x < x1 and y0 < bulb.y < y1 and z0 < bulb.z < z1, str(bulb))
        # Under the shade: a ray up from the bulb meets the lamp.
        self.assertIsNotNone(_hit(self.objects["lamp"], tuple(bulb), (0.0, 0.0, 1.0), 0.3))

    def test_ledger_lies_open_on_the_desk(self):
        low = self._extent("ledger")[2][0]
        self.assertTrue(library_corner.DESK_TOP + 0.002 <= low <= library_corner.DESK_TOP + 0.005, low)

    def test_the_small_things_lie_on_the_desk(self):
        for n in [n for n in self.ON_DESK if n != "ledger"] + ["lamp"]:
            low = self._extent(n)[2][0]
            self.assertTrue(library_corner.DESK_TOP + 0.002 <= low <= library_corner.DESK_TOP + 0.005, "%s %.4f" % (n, low))

    def test_nothing_on_the_desk_overlaps(self):
        # In plan, nothing laid on the desk lies on anything else there, and all of it within the desk's top.
        laid = self.ON_DESK
        boxes = {n: self._extent(n) for n in laid}
        (dx, dy, _) = self._extent("desk")
        outside = [n for n in laid if not (dx[0] <= boxes[n][0][0] and boxes[n][0][1] <= dx[1]
                                           and dy[0] <= boxes[n][1][0] and boxes[n][1][1] <= dy[1])]
        self.assertEqual(outside, [])
        clashes = []

        for i, a in enumerate(laid):
            for b in laid[i + 1:]:
                (ax, ay, _), (bx, by, _) = boxes[a], boxes[b]
                if ax[0] < bx[1] and bx[0] < ax[1] and ay[0] < by[1] and by[0] < ay[1]:
                    clashes.append((a, b))

        self.assertEqual(clashes, [])

    def test_the_stole_hangs_from_the_lamp(self):
        # Its highest point rests on the lamp's arm (within the arm's radius and the stole's thickness of it).
        top = max(_world(self.objects["stole"]), key=lambda v: v.z)
        a, b = Vector(library_corner.LAMP_JOINT), Vector(library_corner.LAMP_MID)
        t = max(0.0, min(1.0, (top - a).dot(b - a) / (b - a).length_squared))
        self.assertLess((top - (a + (b - a) * t)).length, 0.035)
        # Both its ends hang below the arm, clear of the desk.
        low = min(v.z for v in _world(self.objects["stole"]))
        self.assertTrue(library_corner.DESK_TOP + 0.05 < low < top.z - 0.2, low)

    def test_the_rituale_bristles_with_its_markers(self):
        # Its ribbon markers stand out past its pages by at least 3.5 cm (chunky enough to read), its fore-edge and
        # markers toward the customers (-y).
        o = self.objects["rituale"]
        yaw = library_corner.RITUALE_YAW
        out = Vector((math.cos(yaw), math.sin(yaw), 0.0))
        middle = Vector(library_corner.RITUALE_AT[:2] + (0.0,))
        ribbons = [s for s, m in enumerate(o.data.materials) if m.name in ("velvet_purple", "silver")]
        reach = max((o.matrix_world @ o.data.vertices[v].co - middle).dot(out)
                    for p in o.data.polygons if p.material_index in ribbons for v in p.vertices)
        self.assertGreater(reach, 0.17 / 2 + 0.035)
        self.assertLess(out.y, -0.9)

    def test_the_medal_is_nailed_to_the_desks_front(self):
        (mx, my, mz) = self._extent("benedict_medal")
        # (Aimed just above the seam between the top's board and its rim, which a ray could slip through.)
        front = _hit(self.objects["desk"], ((mx[0] + mx[1]) / 2, -2.0, (mz[0] + mz[1]) / 2 + 0.012), (0.0, 1.0, 0.0))
        self.assertIsNotNone(front)
        # Its back against the desk's front edge, the customers' side; the edge of the desk's top board.
        self.assertAlmostEqual(my[1], front.y, delta=0.002)
        self.assertTrue(0.98 <= mz[0] and mz[1] <= library_corner.DESK_TOP, mz)

    def test_the_rack_meets_the_wall(self):
        # The back wall's face in the corner's frame: the room's depth less the corner's place in it.
        self.assertAlmostEqual(self._extent("hunt_rack")[1][1], library_corner.WALL_Y, delta=0.001)

    @staticmethod
    def _touch(a, b, slack=0.003):
        return all(a[i][0] - slack <= b[i][1] and b[i][0] - slack <= a[i][1] for i in range(3))

    def test_each_weapon_hangs_on_the_rack(self):
        loose = []

        for n in self.HUNT:
            box = self._extent(n)
            if n == "rounds":
                x0, x1, top = library_corner.SHELF
                rests = abs(box[2][0] - top) < 0.003 and x0 <= box[0][0] and box[0][1] <= x1
                if not rests:
                    loose.append(n)
                continue
            pegs = [((x - 0.022, x + 0.022), (library_corner.WALL_Y - 0.15, library_corner.WALL_Y - 0.04),
                     (z - 0.022, z + 0.022)) for x, z in library_corner.PEGS[n]]
            if not any(self._touch(box, peg) for peg in pegs):
                loose.append(n)

        self.assertEqual(loose, [])

    def test_no_weapon_lies_on_another(self):
        boxes = {n: self._extent(n) for n in self.HUNT}
        clashes = [(a, b) for i, a in enumerate(self.HUNT) for b in self.HUNT[i + 1:] if self._touch(boxes[a], boxes[b], 0.0)]
        self.assertEqual(clashes, [])

    def test_the_hunt_hangs_behind_his_chair(self):
        # Clear of the chair and the coat stand: all of it within reach of the wall.
        front = min(self._extent(n)[1][0] for n in self.HUNT + ["hunt_rack"])
        self.assertGreater(front, max(self._extent("desk_chair")[1][1], self._extent("coat_hook")[1][1]))

    def test_the_book_is_chained_to_the_desk(self):
        chain = self._extent("chained_book_chain")
        self.assertTrue(self._touch(chain, self._extent("chained_book_cover")))
        self.assertTrue(self._touch(chain, self._extent("desk")))

    def test_the_chained_book_lies_on_its_rest(self):
        rest, block, cover = (self._extent(n) for n in ("chained_book_rest", "chained_book_block", "chained_book_cover"))
        self.assertAlmostEqual(block[2][0], library_corner.DESK_TOP + library_corner.LIFT, delta=0.001)
        self.assertTrue(rest[0][0] <= block[0][0] and block[0][1] <= rest[0][1] and rest[1][0] <= block[1][0]
                        and block[1][1] <= rest[1][1])
        # Its cover shut on its pages, its hinge along the spine (its -x edge) at the cover's underside.
        self.assertAlmostEqual(cover[2][0], block[2][1], delta=0.003)
        hinge = [Vector(p) for p in common.WICKS["chained_book_cover"]]
        self.assertEqual(len(hinge), 2)
        for p in hinge:
            self.assertAlmostEqual(p.x, cover[0][0], delta=0.01)
            self.assertAlmostEqual(p.z, cover[2][0], delta=0.003)
        self.assertGreater(abs(hinge[1].y - hinge[0].y), 0.2)

    def test_the_cage_holds_its_books(self):
        cage = self._extent("quarantine_cage")
        bars = library_corner.CAGE_BARS
        wrong = []

        for k in range(7):
            book = self._extent("quarantine_book_%d" % k)
            inside = all(cage[i][0] <= book[i][0] and book[i][1] <= cage[i][1] for i in range(3))
            if not inside or any(self._touch(book, bar, 0.0) for bar in bars):
                wrong.append(k)

        self.assertEqual(wrong, [])
        self.assertGreaterEqual(len(bars), 8)

    def test_the_chair_is_left_behind_the_desk(self):
        (x0, x1), (y0, y1), (z0, z1) = self._extent("desk_chair")
        self.assertAlmostEqual(z0, 0.0, delta=1e-4)
        self.assertGreater(y0, self._extent("desk")[1][1])


class LibraryShelves(unittest.TestCase):
    """The librarian's shelves (tools/eclipse/library_shelves.py): a tall case per section, each built in its own
    frame (its front's middle at the origin on the floor, its front toward -y, its back against the wall at +y), each
    shaped and ornamented its own way; the low double-sided case; the rolling ladder and its rail."""

    CASES = ["shelf_" + n for n in ("chronology", "necromancy", "alchemy", "metaphysics", "hunting")]
    BUDGET = dict({n: 12000 for n in CASES}, shelf_middle=9000, ladder=2500, ladder_rail=2500)

    @classmethod
    def setUpClass(cls):
        library_shelves.build()
        cls.objects = {o.name: o for o in bpy.context.scene.objects if o.type == "MESH"}

    def test_every_piece_is_an_object(self):
        self.assertEqual(sorted(self.objects), sorted(self.BUDGET))

    def test_every_object_is_closed(self):
        self.assertEqual({n: _closed(o) for n, o in self.objects.items() if _closed(o)}, {})

    def test_budgets(self):
        self.assertEqual({n: _tris(o) for n, o in self.objects.items() if _tris(o) > self.BUDGET[n]}, {})

    def test_each_passes_the_gate(self):
        problems = {}

        for n, o in self.objects.items():
            faces, tris, _ = common.dump_faces([o])
            found = gate.check(faces, tris, [], budget=self.BUDGET[n])
            if found:
                problems[n] = found[:3]

        self.assertEqual(problems, {})

    def _profile(self, name):
        vs = _world(self.objects[name])
        return [max([v.z for v in vs if abs(v.x - x) < 0.025] or [0.0]) for x in [-0.9 + 0.05 * k for k in range(37)]]

    def test_each_section_differs_in_shape(self):
        # Not one case recoloured five times: every two differ in their outline by 3 cm somewhere.
        profiles = {n: self._profile(n) for n in self.CASES}
        alike = [(a, b) for i, a in enumerate(self.CASES) for b in self.CASES[i + 1:]
                 if max(abs(p - q) for p, q in zip(profiles[a], profiles[b])) < 0.03]
        self.assertEqual(alike, [])

    def test_the_cases_stand_tall_against_the_wall(self):
        for n in self.CASES:
            vs = _world(self.objects[n])
            self.assertAlmostEqual(min(v.z for v in vs), 0.0, delta=1e-4, msg=n)
            self.assertGreaterEqual(max(v.z for v in vs), library_shelves.HEIGHT - 0.001, n)
            self.assertAlmostEqual(max(v.y for v in vs), library_shelves.DEPTH, delta=0.001, msg=n)
            self.assertLessEqual(max(abs(v.x) for v in vs), library_shelves.WIDTH / 2 + 0.06, n)

    def test_boards(self):
        # Every board the filler will lay books on is where BOARD_SPOTS says, its top met from above.
        wrong = []

        for name, boards in library_shelves.BOARD_SPOTS.items():
            for x0, x1, top, y0, y1 in boards:
                hit = _hit(self.objects[name], ((x0 + x1) / 2, (y0 + y1) / 2, top + 0.1), (0.0, 0.0, -1.0), 0.3)
                if hit is None or abs(hit.z - top) > 0.005:
                    wrong.append((name, top, None if hit is None else round(hit.z, 3)))

        self.assertEqual(wrong, [])
        self.assertEqual(sorted(library_shelves.BOARD_SPOTS), sorted(self.CASES + ["shelf_middle"]))

    def test_every_case_stands_under_the_vault(self):
        # The vault comes down toward the side walls (3.0 m at their faces, 3.36 m a case's depth out): a case stood
        # against a side wall, its crest and ornaments and all, stays under it.
        r, zc, half = library_room._arc(library_room.WIDTH, library_room.SPRING, library_room.CROWN)
        through = []

        for n in self.CASES:
            for v in _world(self.objects[n]):
                # The case's y out from its back (the wall) is the room's x in from the side wall.
                x = library_room.WIDTH / 2 - (library_shelves.DEPTH - v.y) - 0.035
                if abs(x) < library_room.WIDTH / 2 and v.z > zc + math.sqrt(max(0.0, r * r - x * x)) - 0.02:
                    through.append((n, round(v.z, 2)))
                    break

        self.assertEqual(through, [])

    def test_middle_case_is_low(self):
        self.assertLessEqual(max(v.z for v in _world(self.objects["shelf_middle"])), 1.45)

    def test_the_ladder_hangs_on_its_rail(self):
        # Its hooks at its top on the rail, its foot on the floor out from the case.
        ladder, rail = _world(self.objects["ladder"]), _world(self.objects["ladder_rail"])
        self.assertAlmostEqual(min(v.z for v in ladder), 0.0, delta=0.003)
        self.assertGreater(max(v.z for v in ladder), min(v.z for v in rail))
        self.assertLess(min(v.y for v in ladder), -0.4)


class LibraryBooks(unittest.TestCase):
    """The librarian's books (tools/eclipse/library_books.py): the books that fill his shelves, standing (spine to
    -y, on the floor of their frame), the stacks, and the live book in its parts, shut, its hinge along its spine;
    the lectern and the front table."""

    LIVE = ["live_cover_back", "live_block_right", "live_block_left", "live_cover_front", "live_leaf", "live_spine_back",
            "live_spine_front"]

    @classmethod
    def setUpClass(cls):
        library_books.build()
        cls.objects = {o.name: o for o in bpy.context.scene.objects if o.type == "MESH"}
        cls.books = ["book_%d" % k for k in range(12)]
        cls.stacks = ["book_stack_%d" % k for k in range(3)]
        cls.BUDGET = dict({n: 600 for n in cls.books}, **{n: 1500 for n in cls.stacks}, **{n: 800 for n in cls.LIVE},
                          lectern=2500, front_table=4000)

    def _extent(self, name):
        vs = _world(self.objects[name])
        return [(min(v[i] for v in vs), max(v[i] for v in vs)) for i in range(3)]

    def test_every_piece_is_an_object(self):
        self.assertEqual(sorted(self.objects), sorted(self.BUDGET))

    def test_every_object_is_closed(self):
        self.assertEqual({n: _closed(o) for n, o in self.objects.items() if _closed(o)}, {})

    def test_budgets(self):
        self.assertEqual({n: _tris(o) for n, o in self.objects.items() if _tris(o) > self.BUDGET[n]}, {})

    def test_each_passes_the_gate(self):
        problems = {}

        for n, o in self.objects.items():
            faces, tris, _ = common.dump_faces([o])
            found = gate.check(faces, tris, [], budget=self.BUDGET[n])
            if found:
                problems[n] = found[:3]

        self.assertEqual(problems, {})

    def test_the_books_stand_on_their_feet_and_differ(self):
        sizes = set()

        for n in self.books:
            (x0, x1), (y0, y1), (z0, z1) = self._extent(n)
            self.assertAlmostEqual(z0, 0.0, delta=1e-4, msg=n)
            self.assertAlmostEqual(y0, 0.0, delta=0.002, msg=n)
            # Tall enough to read, short enough for the shelves (the lowest gap between boards is 0.26 m at the top).
            self.assertTrue(0.2 <= z1 <= library_books.TALLEST, (n, z1))
            sizes.add((round(x1 - x0, 3), round(y1 - y0, 3), round(z1, 3)))

        self.assertGreaterEqual(len(sizes), 8)

    def test_live_parts_share_a_hinge(self):
        # The hinge runs along the spine's outer face: the spine's halves from it to the boards, which begin where
        # the spine ends; its lower half the back half's height, its upper the front's.
        hx, hy, hz = library_books.LIVE_HINGE
        for n in ("live_spine_back", "live_spine_front"):
            self.assertAlmostEqual(self._extent(n)[0][0], hx, delta=0.001, msg=n)
            self.assertAlmostEqual(self._extent(n)[0][1], 0.0, delta=0.001, msg=n)
        for n in ("live_cover_back", "live_cover_front"):
            self.assertAlmostEqual(self._extent(n)[0][0], 0.0, delta=0.001, msg=n)
        self.assertAlmostEqual(self._extent("live_spine_back")[2][1], hz, delta=0.001)
        self.assertAlmostEqual(self._extent("live_spine_front")[2][0], hz, delta=0.001)
        self.assertAlmostEqual(self._extent("live_spine_front")[2][1], library_books.LIVE_SIZE[2], delta=0.001)

    def test_live_book_closes_flat(self):
        # Shut, its parts stacked: back board, right pages, left pages, front board, each on the one below.
        parts = ["live_cover_back", "live_block_right", "live_block_left", "live_cover_front"]
        boxes = [self._extent(n) for n in parts]
        for below, above in zip(boxes, boxes[1:]):
            self.assertLess(below[2][1] - above[2][0], 0.001)
        self.assertAlmostEqual(boxes[-1][2][1], library_books.LIVE_SIZE[2], delta=0.001)
        # Opened about the hinge, the left half lands on the table level with the right: front board on the
        # table, left pages as high as the right.
        hz = library_books.LIVE_HINGE[2]
        self.assertAlmostEqual(2 * hz - boxes[3][2][1], 0.0, delta=0.001)
        self.assertAlmostEqual(2 * hz - boxes[2][2][0], boxes[1][2][1], delta=0.001)


class LibrarySpectres(unittest.TestCase):
    """The librarian's spectres (tools/eclipse/library_spectres.py): CDmir's CC0 skull cut into the skull (cranium
    and upper teeth) and its jaw (mandible and lower teeth, its origin at its hinge), scaled to a spectre's size, its
    face toward -y; and lighter copies for the dead's faces in the smoke."""

    @classmethod
    def setUpClass(cls):
        library_spectres.build()
        cls.objects = {o.name: o for o in bpy.context.scene.objects if o.type == "MESH"}

    def _extent(self, name):
        vs = _world(self.objects[name])
        return [(min(v[i] for v in vs), max(v[i] for v in vs)) for i in range(3)]

    def test_pieces(self):
        self.assertEqual(sorted(self.objects), ["alch_homunculus", "necro_jaw", "necro_jaw_lite", "necro_skull",
                                                "necro_skull_lite"])

    def test_homunculus_small_curled_and_light(self):
        # The base body curled up: at most HOMUNCULUS across its longest side, compact (no limb flung out), whole,
        # light enough for an effect.
        (x0, x1), (y0, y1), (z0, z1) = self._extent("alch_homunculus")
        sides = sorted([x1 - x0, y1 - y0, z1 - z0])
        self.assertAlmostEqual(sides[2], library_spectres.HOMUNCULUS, delta=0.001)
        self.assertLess(sides[2] / sides[0], 2.2)
        self.assertAlmostEqual((x0 + x1) / 2.0, 0.0, delta=0.002)
        self.assertLessEqual(_tris(self.objects["alch_homunculus"]), 3000)
        self.assertGreater(_tris(self.objects["alch_homunculus"]), 1200)

    def test_sized_as_a_spectre(self):
        skull, jaw = self._extent("necro_skull"), self._extent("necro_jaw")
        height = max(skull[2][1], jaw[2][1]) - min(skull[2][0], jaw[2][0])
        self.assertAlmostEqual(height, library_spectres.HEIGHT, delta=0.002)

    def test_jaw_below_the_skull_hinged_at_its_top_back(self):
        skull, jaw = self._extent("necro_skull"), self._extent("necro_jaw")
        self.assertLess(jaw[2][1], (skull[2][0] + skull[2][1]) / 2.0)
        hinge = self.objects["necro_jaw"].location
        # Its origin is its hinge: at the top of the jaw's rami, toward the back.
        self.assertAlmostEqual(hinge.z, jaw[2][1], delta=0.006)
        self.assertGreater(hinge.y, (jaw[1][0] + jaw[1][1]) / 2.0)

    def test_facing_minus_y(self):
        # The teeth and the face stand forward (-y) of the cranium's middle.
        skull = self._extent("necro_skull")
        jaw = self._extent("necro_jaw")
        self.assertLess(jaw[1][0], (skull[1][0] + skull[1][1]) / 2.0 - 0.01)

    def test_every_piece_of_the_source_kept(self):
        # The cranium, the mandible and every tooth: 35 loose parts between the skull and its jaw.
        self.assertEqual(_loose_parts(self.objects["necro_skull"]) + _loose_parts(self.objects["necro_jaw"]), 35)
        self.assertGreater(_loose_parts(self.objects["necro_jaw"]), 10)

    def test_budgets(self):
        self.assertLessEqual(_tris(self.objects["necro_skull"]) + _tris(self.objects["necro_jaw"]), 4600)
        self.assertLessEqual(_tris(self.objects["necro_skull_lite"]) + _tris(self.objects["necro_jaw_lite"]), 1600)


def _loose_parts(o):
    import bmesh
    bm = bmesh.new()
    bm.from_mesh(o.data)
    seen = set()
    parts = 0
    for v in bm.verts:
        if v.index in seen:
            continue
        parts += 1
        stack = [v]
        seen.add(v.index)
        while stack:
            cur = stack.pop()
            for e in cur.link_edges:
                w = e.other_vert(cur)
                if w.index not in seen:
                    seen.add(w.index)
                    stack.append(w)
    bm.free()
    return parts


class LibraryWard(unittest.TestCase):
    """The librarian's ward candles (tools/eclipse/library_ward.py): five stubs burnt down to different heights on
    his chalk circle's outer ring, in the corner's frame; closed, in budget, through the gate (at its candle-sized
    sliver); each stub's wick on its top, where its flame stands."""

    @classmethod
    def setUpClass(cls):
        library_ward.build()
        cls.objects = {o.name: o for o in bpy.context.scene.objects if o.type == "MESH"}

    def test_one_object_closed_in_budget_through_the_gate(self):
        self.assertEqual(sorted(self.objects), ["ward_candles"])
        o = self.objects["ward_candles"]
        self.assertFalse(_closed(o))
        faces, tris, _ = common.dump_faces([o])
        self.assertEqual(gate.check(faces, tris, [], budget=library_ward.BUDGET, sliver=library_ward.SLIVER)[:3], [])

    def test_five_wicks_on_the_outer_ring(self):
        wicks = common.WICKS.get("ward_candles", [])
        self.assertEqual(len(wicks), 5)
        for w in wicks:
            self.assertAlmostEqual(math.hypot(w[0], w[1]), library_ward.RADIUS, delta=0.005)

    def test_each_wick_tops_its_stub_and_the_stubs_differ(self):
        verts = _world(self.objects["ward_candles"])
        tops = []
        for w in common.WICKS["ward_candles"]:
            near = [v for v in verts if math.hypot(v.x - w[0], v.y - w[1]) < 0.04]
            top = max(v.z for v in near)
            # (The wick stands just over the stub's melted top; nothing of the stub over it.)
            self.assertTrue(0.0 <= w[2] - top + 0.01 <= 0.02, "%.4f over %.4f" % (w[2], top))
            tops.append(top)
        self.assertGreater(max(tops) - min(tops), 0.04)

    def test_they_stand_on_the_floor(self):
        low = min(v.z for v in _world(self.objects["ward_candles"]))
        self.assertAlmostEqual(low, 0.0, delta=0.002)

    def test_their_wax_has_run(self):
        # Pooled round each foot wider than the stub, and run down its side.
        verts = _world(self.objects["ward_candles"])
        for (heading, r, h), w in zip(library_ward.STUBS, common.WICKS["ward_candles"]):
            foot = [math.hypot(v.x - w[0], v.y - w[1]) for v in verts if v.z < 0.004
                    and math.hypot(v.x - w[0], v.y - w[1]) < 0.12]
            self.assertGreater(max(foot), r * 1.6)
            side = [v for v in verts if h * 0.4 < v.z < h - 0.015 and math.hypot(v.x - w[0], v.y - w[1]) > r * 1.12
                    and math.hypot(v.x - w[0], v.y - w[1]) < r * 1.6]
            self.assertTrue(side, "no drip down stub %.0f" % heading)


class LibraryHangings(unittest.TestCase):
    """What hangs in the librarian's shop (tools/eclipse/library_hangings.py), in the shop's own frame (Blender: x
    across, y into the shop, z up): the book-mender's drying line, the rue on its rail, the milagros on the cage, the
    censer on the coat stand, the armillary over chronology. Closed, in budget, through the gate at its sliver."""

    @classmethod
    def setUpClass(cls):
        library_hangings.build()
        cls.objects = {o.name: o for o in bpy.context.scene.objects if o.type == "MESH"}

    def _extent(self, name):
        vs = _world(self.objects[name])
        return [(min(v[i] for v in vs), max(v[i] for v in vs)) for i in range(3)]

    def test_pieces_closed_in_budget_through_the_gate(self):
        self.assertEqual(sorted(self.objects), sorted(library_hangings.BUDGET))
        self.assertEqual({n: _closed(o) for n, o in self.objects.items() if _closed(o)}, {})
        for n, o in self.objects.items():
            faces, tris, _ = common.dump_faces([o])
            self.assertEqual(gate.check(faces, tris, [], budget=library_hangings.BUDGET[n],
                                        sliver=library_hangings.SLIVER)[:3], [], n)

    def test_over_the_floor_they_hang_above_a_head(self):
        # Where a body walks under them (the line, the armillary), nothing comes below 2.1 m.
        for n in ("drying_line", "armillary"):
            self.assertGreaterEqual(self._extent(n)[2][0], 2.1, n)

    def test_the_drying_line_carries_its_pages_blank(self):
        names = {s.material.name for s in self.objects["drying_line"].material_slots}
        self.assertIn("paper", names)
        pages = [p for p in self.objects["drying_line"].data.polygons
                 if self.objects["drying_line"].material_slots[p.material_index].material.name == "paper"]
        self.assertGreaterEqual(len(pages), 6 * library_hangings.PAGES)

    def test_the_armillary_turns_about_its_wick(self):
        centre = Vector(common.WICKS["armillary"][0])
        (x0, x1), (y0, y1), (z0, z1) = self._extent("armillary")
        self.assertAlmostEqual(centre.x, (x0 + x1) / 2, delta=0.02)
        self.assertAlmostEqual(centre.y, (y0 + y1) / 2, delta=0.02)
        self.assertTrue(z0 < centre.z < z1)

    def test_the_censer_hangs_from_the_coat_stands_hook(self):
        (x0, x1), (y0, y1), (z0, z1) = self._extent("censer")
        hook = Vector(library_hangings.CENSER_HOOK)
        self.assertAlmostEqual(z1, hook.z, delta=0.03)
        self.assertLess(math.hypot((x0 + x1) / 2 - hook.x, (y0 + y1) / 2 - hook.y), 0.05)
        self.assertGreater(z1 - z0, 0.35)


class CandleLane(unittest.TestCase):
    """The candle lane's own pieces (tools/eclipse/candle_lane.py), in the lane's frame (Blender: x along it, y = the
    lane's -z, z up): the chapel's doorway frame, the votive ledges and their candles, the milagros board, a Pasaje
    puesto, the enamel sign and the arrow plates (their faces blank). Closed, in budget, through the gate."""

    @classmethod
    def setUpClass(cls):
        candle_lane.build()
        cls.objects = {o.name: o for o in bpy.context.scene.objects if o.type == "MESH"}

    def _extent(self, name):
        vs = _world(self.objects[name])
        return [(min(v[i] for v in vs), max(v[i] for v in vs)) for i in range(3)]

    def test_pieces_closed_in_budget_through_the_gate(self):
        self.assertEqual(sorted(self.objects), sorted(candle_lane.BUDGET))
        self.assertEqual({n: _closed(o) for n, o in self.objects.items() if _closed(o)}, {})
        for n, o in self.objects.items():
            faces, tris, _ = common.dump_faces([o])
            self.assertEqual(gate.check(faces, tris, [], budget=candle_lane.BUDGET[n], sliver=candle_lane.SLIVER[n])[:3],
                             [], n)

    def test_the_doorway_opens_three_by_two_point_eight(self):
        # Rays through the frame's opening pass; just outside it they meet stone.
        o = self.objects["chapel_door"]
        x = candle_lane.DOOR_X - 0.2
        y_mid = -candle_lane.DOOR_Z
        for dy in (-1.45, 1.45):
            self.assertIsNone(_hit(o, (x, y_mid + dy, 1.4), (1.0, 0.0, 0.0), 0.5))
        self.assertIsNone(_hit(o, (x, y_mid, 2.75), (1.0, 0.0, 0.0), 0.5))
        self.assertIsNotNone(_hit(o, (x, y_mid, 2.9), (1.0, 0.0, 0.0), 0.5))
        self.assertIsNotNone(_hit(o, (x, y_mid + 1.6, 1.4), (1.0, 0.0, 0.0), 0.5))

    def test_the_ledges_and_masses_carry_their_candles(self):
        # (Crowded: the ledges forty and more each, the floor's masses their dozens.)
        for n, least in (("votive_north", 40), ("votive_south", 30), ("candle_mass_a", 25), ("candle_mass_b", 14)):
            wicks = common.WICKS.get(n, [])
            self.assertGreaterEqual(len(wicks), least, n)
            (x0, x1), _, _ = self._extent(n)
            self.assertTrue(all(x0 < w[0] < x1 for w in wicks), n)
            # (Every wick over a candle: a ray down from just above it meets the piece.)
            self.assertTrue(all(_hit(self.objects[n], (w[0], w[1], w[2] + 0.02), (0, 0, -1), 0.5) for w in wicks), n)

    def test_sign_faces_are_blank_for_the_users_words(self):
        for n in ("enamel_sign", "arrow_east", "arrow_west", "puesto", "gas_meter", "main_gauge"):
            names = {s.material.name for s in self.objects[n].material_slots}
            self.assertIn("sign", names, n)



class LaneLandmarks(unittest.TestCase):
    """The candle lane's landmarks (tools/eclipse/lane_landmarks.py; docs/superpowers/plans/2026-10-25-lane-landmarks.md),
    in the lane's frame (Blender: x along it, y = the lane's -z, z up). Closed, in budget, through the gate; clear of
    every head over the walk (lane z 0.2-2.6)."""

    @classmethod
    def setUpClass(cls):
        lane_landmarks.build()
        cls.objects = {o.name: o for o in bpy.context.scene.objects if o.type == "MESH"}

    def test_pieces_closed_in_budget_through_the_gate(self):
        self.assertEqual(sorted(self.objects), sorted(lane_landmarks.BUDGET))
        self.assertEqual({n: _closed(o) for n, o in self.objects.items() if _closed(o)}, {})
        for n, o in self.objects.items():
            faces, tris, _ = common.dump_faces([o])
            self.assertEqual(gate.check(faces, tris, [], budget=lane_landmarks.BUDGET[n],
                                        sliver=lane_landmarks.SLIVER[n])[:3], [], n)

    def test_the_garland_clears_the_walk(self):
        low = [v for v in _world(self.objects["garland"]) if -2.6 <= v.y <= -0.2 and v.z < 2.6]
        self.assertEqual(low[:3], [])

    def test_the_garland_spans_the_lane(self):
        ys = [v.y for v in _world(self.objects["garland"])]
        # (From the south wall's hook to her stall's front, lane z 0.)
        self.assertLessEqual(min(ys), -4.4)
        self.assertGreaterEqual(max(ys), -0.05)

    def test_the_heart_hangs_from_its_hook(self):
        # (Built with its hook at its own origin, so the lane can turn it there.)
        o = self.objects["milagro_heart"]
        zs = [v.co.z for v in o.data.vertices]
        self.assertLessEqual(abs(max(zs)), 0.05)
        self.assertTrue(0.55 <= max(zs) - min(zs) <= 0.8, max(zs) - min(zs))

    def test_the_lantern_bracket_misses_the_pipes(self):
        # (The south wall's fire main and air line over the arch, x 4.7-7.7: their axes (lane z, height) and how far
        # their flanges reach; no part of the lantern within 2 cm of them.)
        mains = [((4.55 - 0.15, 3.1), 0.075 + 0.035), ((4.55 - 0.085, 2.75), 0.035 + 0.035)]
        near = [tuple(round(c, 3) for c in v) for v in _world(self.objects["red_lantern"])
                if 4.7 <= v.x <= 7.7 and any(math.hypot(-v.y - z, v.z - h) < r + 0.02 for (z, h), r in mains)]
        self.assertEqual(near[:3], [])

    def test_the_lantern_hangs_over_the_arch_clear_of_its_head(self):
        vs = _world(self.objects["red_lantern"])
        self.assertTrue(5.6 <= min(v.x for v in vs) and max(v.x for v in vs) <= 6.8)
        # (Out from the wall over the threshold, its foot over every head.)
        self.assertGreaterEqual(min(v.z for v in vs), 2.3)

    def test_the_threshold_stands_against_the_shopfront_clear_of_the_doorway(self):
        # (Lane z 3.4-4.55, Blender y -4.55..-3.4; none of it in the arch's opening, x 4.7-7.7.)
        for name in ("lectern", "lectern_book_block", "lectern_book_cover", "lectern_book_chain", "book_barrow"):
            vs = _world(self.objects[name])
            self.assertTrue(-4.55 <= min(v.y for v in vs) and max(v.y for v in vs) <= -3.4, name)
            self.assertTrue(max(v.x for v in vs) < 4.7 or min(v.x for v in vs) > 7.7, name)


class PasajeShell(unittest.TestCase):
    """The Pasaje's shell dressed (tools/eclipse/pasaje_shell.py; docs/superpowers/plans/2026-10-26-pasaje-market.md
    Task 3): the Company's tile up its 4.5 m walls in 1.2 m panels and the fills that finish each run at an opening,
    the plaster over the openings, their reveals, the ceiling and its girders, the floor's rows, the mains' turns into
    the wall at the lane's mouth. Closed, in budget, through the gate."""

    @classmethod
    def setUpClass(cls):
        pasaje_shell.build()
        cls.objects = {o.name: o for o in bpy.context.scene.objects if o.type == "MESH"}

    def _extent(self, name):
        vs = _world(self.objects[name])
        return [(min(v[i] for v in vs), max(v[i] for v in vs)) for i in range(3)]

    def test_pieces_closed_in_budget_through_the_gate(self):
        self.assertEqual(sorted(self.objects), sorted(pasaje_shell.BUDGET))
        self.assertEqual({n: _closed(o) for n, o in self.objects.items() if _closed(o)}, {})
        for n, o in self.objects.items():
            faces, tris, _ = common.dump_faces([o])
            self.assertEqual(gate.check(faces, tris, [], budget=pasaje_shell.BUDGET[n],
                                        sliver=pasaje_shell.SLIVER[n])[:3], [], n)

    def test_the_panels_stand_the_walls_height_and_the_fills_finish_each_run(self):
        for n in ("wall", "wall_worn") + tuple(pasaje_shell.fill_name(w) for w in pasaje_shell.fills()):
            (x0, x1), (y0, y1), (z0, z1) = self._extent(n)
            self.assertAlmostEqual(z0, 0.0, delta=0.002, msg=n)
            self.assertAlmostEqual(z1, pasaje_shell.HEIGHT, delta=0.002, msg=n)
            self.assertAlmostEqual(y0, -underground_walls.FACE, delta=0.002, msg=n)
        # (Every run between an opening and the stretch's end is whole panels and one fill.)
        for side, a, b in pasaje_shell.wall_runs():
            panels, fill = divmod(round((b - a) * 1000), round(pasaje_shell.PANEL * 1000))
            if fill:
                (x0, x1), _, _ = self._extent(pasaje_shell.fill_name(fill / 1000))
                self.assertAlmostEqual(x1 - x0, fill / 1000, delta=0.002)

    def test_the_floor_fills_the_street(self):
        # (Across: a side strip at each wall and the Metro's 1.2 m modules between; along: whole rows and a joint at
        # each end.)
        across = 2 * pasaje_shell.SIDE + pasaje_shell.MODULES * underground_floor.MODULE
        self.assertAlmostEqual(across, 2 * pasaje_shell.INSIDE, delta=0.001)
        length = pasaje_shell.ROWS * underground_floor.MODULE + 2 * pasaje_shell.JOINT
        self.assertAlmostEqual(length, 2 * (pasaje_shell.HALF_L - pasaje_shell.SEAM), delta=0.001)
        (x0, x1), (y0, y1), (z0, z1) = self._extent("floor_side")
        self.assertAlmostEqual(x1 - x0, pasaje_shell.SIDE, delta=0.006)
        self.assertAlmostEqual(y1 - y0, underground_floor.MODULE, delta=0.006)
        self.assertLessEqual(z1, 0.0005)
        (x0, x1), (y0, y1), (z0, z1) = self._extent("floor_joint")
        self.assertAlmostEqual(x1 - x0, 2 * pasaje_shell.INSIDE, delta=0.002)
        self.assertLessEqual(z1, 0.0005)

    def test_the_girders_clear_the_openings(self):
        (_, _), (_, _), (z0, z1) = self._extent("girder")
        self.assertAlmostEqual(z1, 0.0, delta=0.002)
        tallest = max(o[3] for o in pasaje_shell.OPENINGS.values())
        self.assertGreaterEqual(pasaje_shell.HEIGHT - pasaje_shell.THICK + z0, tallest + 0.1)

    def test_the_reveals_line_their_openings_and_keep_them_open(self):
        for name, (side, a, b, high) in pasaje_shell.OPENINGS.items():
            o = self.objects["reveal_" + name]
            # (Above the floor none of it past the wall's outer plane; under it, the sill's lip reaches under the next
            # floor.)
            vs = _world(o)
            self.assertLessEqual(max(abs(v.x) for v in vs if v.z > -0.01), pasaje_shell.HALF_W - pasaje_shell.SEAM, name)
            self.assertLessEqual(max(abs(v.x) for v in vs), pasaje_shell.HALF_W + pasaje_shell.LIP[0] + 0.001, name)
            middle = -(a + b) / 2
            for up in (1.0, high - 0.1):
                self.assertIsNone(_hit(o, (0.0, middle, up), (side, 0.0, 0.0), 6.0), name)
            # (Its threshold under the wall's thickness, its top the floor's.)
            sill = _hit(o, (side * (pasaje_shell.INSIDE + 0.15), middle, 0.5), (0.0, 0.0, -1.0), 1.0)
            self.assertIsNotNone(sill, name)
            self.assertAlmostEqual(sill.z, 0.0, delta=0.003, msg=name)

    def test_the_mains_turn_into_the_wall(self):
        for n, length in (("fire_turn_in", pasaje_shell.TURN_IN), ("air_turn_in", pasaje_shell.TURN_IN),
                          ("fire_turn_out", pasaje_shell.TURN_OUT), ("air_turn_out", pasaje_shell.TURN_OUT)):
            (x0, x1), (y0, y1), _ = self._extent(n)
            self.assertAlmostEqual(y1, 0.0, delta=0.002, msg=n)
            self.assertAlmostEqual(x1 - x0, length, delta=0.12, msg=n)


class PasajeStalls(unittest.TestCase):
    """The Pasaje's stalls (tools/eclipse/pasaje_stalls.py; docs/superpowers/plans/2026-10-26-pasaje-market.md Task 4),
    each built from the wall's tiles (y = 0) out toward the street (-y), x along the wall, z up: the frames in their
    widths, counters, awnings, neon boxes and their tubes, the fruit barrow, the tortas stall's case and griddle.
    Closed, in budget, through the gate; each within a stall's depth and under the mains; every counter leaving the
    floor open under it."""

    @classmethod
    def setUpClass(cls):
        pasaje_stalls.build()
        cls.objects = {o.name: o for o in bpy.context.scene.objects if o.type == "MESH"}

    def _extent(self, name):
        vs = _world(self.objects[name])
        return [(min(v[i] for v in vs), max(v[i] for v in vs)) for i in range(3)]

    def test_pieces_closed_in_budget_through_the_gate(self):
        self.assertEqual(sorted(self.objects), sorted(pasaje_stalls.BUDGET))
        self.assertEqual({n: _closed(o) for n, o in self.objects.items() if _closed(o)}, {})
        for n, o in self.objects.items():
            faces, tris, _ = common.dump_faces([o])
            self.assertEqual(gate.check(faces, tris, [], budget=pasaje_stalls.BUDGET[n],
                                        sliver=pasaje_stalls.SLIVER[n])[:3], [], n)

    def test_every_piece_stands_in_a_stalls_depth_under_the_mains(self):
        for n in self.objects:
            (x0, x1), (y0, y1), (z0, z1) = self._extent(n)
            if n == "kiosk":
                # (The kiosk stands free in the street's middle, not against the wall: within its own body and
                # wings, under the canopy's sag.)
                self.assertLessEqual(max(-y0, y1), 1.2, n)
                self.assertLessEqual(max(-x0, x1), 1.8, n)
                self.assertGreaterEqual(z0, -0.0005, n)
                self.assertLessEqual(z1, pasaje_stalls.KIOSK_SIGN_TOP + 0.001, n)
                continue
            self.assertGreaterEqual(y0, -pasaje_stalls.REACH - 0.001, n)
            self.assertLessEqual(y1, 0.0005, n)
            self.assertGreaterEqual(z0, -0.0005, n)
            self.assertLessEqual(z1, pasaje_stalls.TOP, n)

    def test_each_family_comes_in_its_widths(self):
        for family in pasaje_stalls.FRAMES + pasaje_stalls.AWNINGS:
            for w in pasaje_stalls.WIDTHS:
                (x0, x1), _, _ = self._extent(pasaje_stalls.piece_name(family, w))
                self.assertTrue(w - 0.2 <= x1 - x0 <= w + 0.25, (family, w, x1 - x0))
        # (The counter short of the frame's right end: the keeper's way in.)
        for w in pasaje_stalls.WIDTHS:
            (x0, x1), _, _ = self._extent(pasaje_stalls.piece_name("counter", w))
            self.assertAlmostEqual(x1 - x0, w - 0.1 - pasaje_stalls.KEEPER_WAY, delta=0.01)

    def test_every_counter_leaves_the_floor_open_under_it(self):
        for w in pasaje_stalls.WIDTHS:
            o = self.objects[pasaje_stalls.piece_name("counter", w)]
            (x0, x1), (y0, y1), _ = self._extent(o.name)
            self.assertIsNone(_hit(o, ((x0 + x1) / 2, y0 - 0.05, 0.15), (0.0, 1.0, 0.0), 0.45), w)

    def test_neon_faces_are_blank_for_the_users_words(self):
        for w in pasaje_stalls.NEON_WIDTHS:
            names = {s.material.name for s in self.objects["neon_box_%d" % round(w * 10)].material_slots}
            self.assertIn("sign", names, w)
            slots = {s.material.name for s in self.objects["neon_tube_%d" % round(w * 10)].material_slots}
            self.assertEqual(slots, {"neon"}, w)


class PasajeWares(unittest.TestCase):
    """The Pasaje's wares (tools/eclipse/pasaje_wares.py; docs/superpowers/plans/2026-10-26-pasaje-market.md Task 5):
    each trade's goods, named for it, each built about its own foot (or, hung, from its own hook) to sit on a counter,
    a shelf, a barrow or the floor. Closed, in budget, through the gate; two and more for every trade."""

    @classmethod
    def setUpClass(cls):
        pasaje_wares.build()
        cls.objects = {o.name: o for o in bpy.context.scene.objects if o.type == "MESH"}

    def _extent(self, name):
        vs = _world(self.objects[name])
        return [(min(v[i] for v in vs), max(v[i] for v in vs)) for i in range(3)]

    def test_pieces_closed_in_budget_through_the_gate(self):
        self.assertEqual(sorted(self.objects), sorted(pasaje_wares.BUDGET))
        self.assertEqual({n: _closed(o) for n, o in self.objects.items() if _closed(o)}, {})
        for n, o in self.objects.items():
            faces, tris, _ = common.dump_faces([o])
            self.assertEqual(gate.check(faces, tris, [], budget=pasaje_wares.BUDGET[n],
                                        sliver=pasaje_wares.SLIVER[n])[:3], [], n)

    def test_every_trade_has_two_and_more(self):
        for trade in pasaje_wares.TRADES:
            self.assertGreaterEqual(len([n for n in self.objects if n.startswith(trade + "_")]), 2, trade)

    def test_each_stands_on_its_foot_or_hangs_from_its_hook(self):
        for n in self.objects:
            (x0, x1), (y0, y1), (z0, z1) = self._extent(n)
            if n in pasaje_wares.HUNG:
                self.assertAlmostEqual(z1, 0.0, delta=0.003, msg=n)
            else:
                self.assertAlmostEqual(z0, 0.0, delta=0.003, msg=n)
            # (Small enough for a counter or a shelf.)
            self.assertLessEqual(x1 - x0, 1.6, n)
            self.assertLessEqual(y1 - y0, 0.7, n)


class PasajeOverhead(unittest.TestCase):
    """The Pasaje's overhead (tools/eclipse/pasaje_overhead.py; docs/superpowers/plans/2026-10-26-pasaje-market.md Task
    6): hanging signs (their faces blank) on rods from the girders and on the gantry, cable bundles and bulb strings
    slung wall to wall, the tarpaulin canopy over the stretch's south end. Closed, in budget, through the gate; over
    every head; the canopy's edges between the wall's mains."""

    @classmethod
    def setUpClass(cls):
        pasaje_overhead.build()
        cls.objects = {o.name: o for o in bpy.context.scene.objects if o.type == "MESH"}

    def _extent(self, name):
        vs = _world(self.objects[name])
        return [(min(v[i] for v in vs), max(v[i] for v in vs)) for i in range(3)]

    def test_pieces_closed_in_budget_through_the_gate(self):
        self.assertEqual(sorted(self.objects), sorted(pasaje_overhead.BUDGET))
        self.assertEqual({n: _closed(o) for n, o in self.objects.items() if _closed(o)}, {})
        for n, o in self.objects.items():
            faces, tris, _ = common.dump_faces([o])
            self.assertEqual(gate.check(faces, tris, [], budget=pasaje_overhead.BUDGET[n],
                                        sliver=pasaje_overhead.SLIVER[n])[:3], [], n)

    def test_the_signs_hang_from_their_hooks_their_faces_blank(self):
        for n in pasaje_overhead.SIGNS:
            (_, _), (_, _), (z0, z1) = self._extent(n)
            self.assertAlmostEqual(z1, 0.0, delta=0.02, msg=n)
            self.assertIn("sign", {s.material.name for s in self.objects[n].material_slots}, n)

    def test_the_slung_lines_span_wall_to_wall_over_every_head(self):
        for n in ("cable_bundle", "bulb_string"):
            (x0, x1), _, (z0, z1) = self._extent(n)
            self.assertLessEqual(x0, -pasaje_overhead.PLASTER + 0.02, n)
            self.assertGreaterEqual(x1, pasaje_overhead.PLASTER - 0.02, n)
            self.assertGreaterEqual(z0, 3.4, n)

    def test_the_canopy_spans_the_south_end_between_the_mains(self):
        (x0, x1), (y0, y1), (z0, z1) = self._extent("canopy")
        self.assertLessEqual(x0, -4.5)
        self.assertGreaterEqual(x1, 4.5)
        # (Blender y is the set's -z: z 13 to the stretch's end.)
        self.assertLessEqual(y0, -19.9)
        self.assertGreaterEqual(y1, -13.0)
        # (Its fringe over a head: the player's capsule stands 2.05 m tall.)
        self.assertGreaterEqual(z0, 2.12)
        # Its edges, where the mains stand off the walls, between the air line's top and the gas main's bottom.
        edge = [v.z for v in _world(self.objects["canopy"]) if abs(v.x) >= 4.4]
        self.assertTrue(edge and min(edge) > 3.125 and max(edge) < 3.21, (min(edge), max(edge)))

    def test_the_bills_curl_rolls_off_the_wall_from_its_root(self):
        # (Its root on the wall's tiles, y = 0, at the bill's top edge, z = 0; rolled out a few centimetres, down and
        # back up; as long as it was made.)
        (x0, x1), (y0, y1), (z0, z1) = self._extent("bill_curl")
        self.assertAlmostEqual(y1, 0.0, delta=0.002)
        self.assertTrue(0.04 < -y0 < 0.1, y0)
        self.assertAlmostEqual(x1 - x0, pasaje_overhead.CURL[0], delta=0.002)
        self.assertTrue(z0 < -0.02 and z1 < 0.06, (z0, z1))


class StationShell(unittest.TestCase):
    """The station's shell dressed (tools/eclipse/station_shell.py; docs/superpowers/plans/2026-10-30-metro-station.md
    Task 4): every piece closed, in budget, through the gate; the walls at their heights, the coping's top the floor's
    with the yellow line let into it, a tread's top at its step."""

    @classmethod
    def setUpClass(cls):
        import station_shell
        cls.kit = station_shell
        station_shell.build()
        cls.objects = {o.name: o for o in bpy.context.scene.objects if o.type == "MESH"}

    def _extent(self, name):
        vs = _world(self.objects[name])
        return [(min(v[i] for v in vs), max(v[i] for v in vs)) for i in range(3)]

    def test_pieces_closed_in_budget_through_the_gate(self):
        import common
        import gate
        self.assertEqual(sorted(self.objects), sorted(n for n, _ in self.kit.PIECES))
        self.assertEqual({n: _closed(o) for n, o in self.objects.items() if _closed(o)}, {})
        for n, o in self.objects.items():
            faces, tris, _ = common.dump_faces([o])
            self.assertEqual(gate.check(faces, tris, [], budget=self.kit.BUDGET[n], sliver=self.kit.SLIVER[n])[:3], [], n)

    def test_the_walls_stand_their_heights(self):
        for h, height in self.kit.HEIGHTS.items():
            for n in ("wall_" + h, "wall_%s_worn" % h):
                (x0, x1), _, (z0, z1) = self._extent(n)
                self.assertAlmostEqual(z1, height, delta=0.01, msg=n)
                self.assertAlmostEqual(x1 - x0, self.kit.PANEL, delta=0.01, msg=n)

    def test_the_coping_is_the_floor_with_its_line_let_in(self):
        o = self.objects["coping"]
        _, (y0, y1), (z0, z1) = self._extent("coping")
        self.assertAlmostEqual(z1, 0.0, delta=0.001)
        self.assertAlmostEqual(y1 - y0, self.kit.COPING, delta=0.01)
        yellow = [o.data.materials[p.material_index].name == "paint_yellow" for p in o.data.polygons]
        line = [o.matrix_world @ o.data.vertices[v].co for p, y in zip(o.data.polygons, yellow) if y for v in p.vertices]
        self.assertTrue(line and all(self.kit.LINE[0] - 0.001 <= v.y <= self.kit.LINE[1] + 0.001 and v.z <= 0.0
                                     for v in line))

    def test_no_joint_runs_straight_up_a_panel_edge(self):
        # (The panel's every other course ends flush at both its edges, a cut tile's half: the next panel makes it
        # whole.)
        for n in ("wall_low", "wall_low_worn"):
            vs = _world(self.objects[n])
            for k, (z0, z1, _, _) in enumerate(self.kit.underground_walls.COURSES):
                if k % 2 == 0:
                    continue
                mid = (z0 + z1) / 2
                at_edge = [v for v in vs if abs(v[2] - mid) < (z1 - z0) / 2 and v[1] < -self.kit.MORTAR + 0.001]
                self.assertTrue(any(abs(v[0]) < 1e-4 for v in at_edge), (n, k, "left"))
                self.assertTrue(any(abs(v[0] - self.kit.PANEL) < 1e-4 for v in at_edge), (n, k, "right"))

    def test_neighbouring_coffers_meet_in_one_flat_soffit(self):
        # (A beam is two coffers' halves: rounded where they meet, the two made a groove down its middle that caught
        # the tubes' light, a hairline down every beam. Square there; the arris kept where the beam meets the recess.)
        o = self.objects["coffer"]
        c, b, d = self.kit.COFFER / 2, self.kit.BEAM, self.kit.COFFER_DEPTH
        for x, y in ((c - 0.003, 0.3), (-c + 0.003, 0.3), (0.3, c - 0.003), (0.3, -c + 0.003)):
            hit = _hit(o, (x, y, -1.0), (0.0, 0.0, 1.0))
            self.assertAlmostEqual(hit.z, -d, delta=0.001, msg=(x, y))
        hit = _hit(o, (c - b + 0.003, 0.3, -1.0), (0.0, 0.0, 1.0))
        self.assertGreater(hit.z, -d + 0.005, "the beam's arris at the recess")

    def test_a_guard_rail_guards_a_drop(self):
        # (Round the track steps' cut: a top rail a metre up, a mid rail under it so no one slips between, a post at a
        # run's start; the end post closes the last run.)
        (x0, x1), (y0, y1), (z0, z1) = self._extent("guard_rail")
        self.assertAlmostEqual(x1 - x0, self.kit.RAIL, delta=0.06)
        self.assertAlmostEqual(z0, 0.0, delta=0.001)
        self.assertAlmostEqual(z1, self.kit.GUARD[0] + 0.025, delta=0.003)
        o = self.objects["guard_rail"]
        for z in self.kit.GUARD:
            hit = _hit(o, (self.kit.RAIL / 2, -1.0, z), (0.0, 1.0, 0.0))
            self.assertIsNotNone(hit, z)
        _, _, (pz0, pz1) = self._extent("guard_post")
        self.assertAlmostEqual(pz1, z1, delta=0.01)

    def test_the_parapets_cap_covers_its_faces(self):
        # (Its stone over the parapet's top and the pit faces either side of it, a little proud, its top the floor's.)
        _, (y0, y1), (z0, z1) = self._extent("parapet_cap")
        self.assertGreaterEqual(y1 - y0 + 1e-6, self.kit.CAP[0])
        self.assertAlmostEqual(z1, 0.0, delta=0.001)
        self.assertAlmostEqual(z1 - z0, self.kit.CAP[1], delta=0.001)

    def test_the_plaster_ceilings_panels_meet(self):
        # (A plastered ceiling has no joints: a gap between two panels let the light on what lies above through, a
        # dashed hairline across the ceiling at a distance.)
        (x0, x1), (y0, y1), _ = self._extent("ceiling_panel")
        self.assertAlmostEqual(x1 - x0, self.kit.MODULE, delta=0.0002)
        self.assertAlmostEqual(y1 - y0, self.kit.MODULE, delta=0.0002)

    def test_the_upright_cement_is_cast_not_the_tracks(self):
        # (The shared grimy cement read as camouflage at arm's length, a door's jamb or the walls down the track steps:
        # every upright face of the station's is cast, calm; only the track's bed underfoot keeps the grime.)
        for n in ["lining", "pit_face", "column_track", "portal_mouth", "portal_tunnel"] + \
                [self.kit.reveal_name(*r) for r in self.kit.REVEALS]:
            self.assertNotIn("cement", {m.name for m in self.objects[n].data.materials}, n)
            self.assertIn("cement_cast", {m.name for m in self.objects[n].data.materials}, n)
        self.assertIn("cement", {m.name for m in self.objects["bed_slab"].data.materials})

    def test_a_tread_tops_its_step(self):
        _, (y0, y1), (z0, z1) = self._extent("tread")
        self.assertAlmostEqual(z1, 0.0, delta=0.001)
        self.assertAlmostEqual(z1 - z0, self.kit.RISE, delta=0.001)
        self.assertAlmostEqual(y1 - y0, self.kit.TREAD, delta=0.001)


class StationTrack(unittest.TestCase):
    """The track laid for the MP-68 (tools/eclipse/station_track.py; docs/superpowers/plans/2026-10-30-metro-station.md
    Task 5): every piece closed, in budget, through the gate; the running pads' tops at the module's z = 0, nothing of
    the bed over them; the guide bar's pieces all behind their contact face (y >= 0), the car's side of it clear; the
    drain's grating flush with the bed's top and its channel deep under it."""

    @classmethod
    def setUpClass(cls):
        import station_track
        cls.kit = station_track
        station_track.build()
        cls.objects = {o.name: o for o in bpy.context.scene.objects if o.type == "MESH"}

    def _extent(self, name):
        vs = _world(self.objects[name])
        return [(min(v[i] for v in vs), max(v[i] for v in vs)) for i in range(3)]

    def test_pieces_closed_in_budget_through_the_gate(self):
        import common
        import gate
        self.assertEqual(sorted(self.objects), sorted(n for n, _ in self.kit.PIECES))
        self.assertEqual({n: _closed(o) for n, o in self.objects.items() if _closed(o)}, {})
        for n, o in self.objects.items():
            faces, tris, _ = common.dump_faces([o])
            self.assertEqual(gate.check(faces, tris, [], budget=self.kit.BUDGET[n], sliver=self.kit.SLIVER[n])[:3], [], n)

    def test_the_pads_carry_the_car_and_nothing_stands_over_them(self):
        (x0, x1), (y0, y1), (z0, z1) = self._extent("track_bed")
        self.assertAlmostEqual(x1 - x0, self.kit.MODULE, delta=0.001)
        self.assertAlmostEqual(z1, 0.0, delta=0.001)
        self.assertAlmostEqual(y1, self.kit.PAD_FROM + self.kit.PAD_WIDE / 2, delta=0.001)
        o = self.objects["track_bed"]
        for y in (-self.kit.PAD_FROM, self.kit.PAD_FROM):
            for x in (0.3, 5.0, 9.7):
                # (Its worn band a millimetre under its edges.)
                self.assertAlmostEqual(_hit(o, (x, y, 1.0), (0.0, 0.0, -1.0)).z, 0.0, delta=0.0015, msg=(x, y))
        # (The safety rails under the pads' tops: the tyres ride the pads.)
        hit = _hit(o, (5.0, self.kit.GAUGE / 2, 1.0), (0.0, 0.0, -1.0))
        self.assertTrue(-0.06 < hit.z < -0.01, hit.z)

    def test_the_tyres_wear_the_pads_black(self):
        # (Where the tyres run, a band down each pad's middle worn black, a hair under its edges; the sleepers a darker
        # stone than the bed's cement; the safety rails dark iron, never the fittings' steel.)
        o = self.objects["track_bed"]
        tree = BVHTree.FromObject(o, bpy.context.evaluated_depsgraph_get())

        def slot_under(x, y):
            found = tree.ray_cast(Vector((x, y, 1.0)), Vector((0.0, 0.0, -1.0)), 5.0)
            return o.data.materials[o.data.polygons[found[2]].material_index].name

        for y in (-self.kit.PAD_FROM, self.kit.PAD_FROM):
            self.assertEqual(slot_under(5.0, y), "rubber", y)
            self.assertEqual(slot_under(5.0, y + self.kit.PAD_WIDE / 2 - 0.02), "cement", y)
        self.assertEqual(slot_under(5.5, 0.0), "stone")
        self.assertEqual(slot_under(5.0, self.kit.GAUGE / 2), "iron")

    def test_the_guide_bar_keeps_behind_its_face(self):
        for n in ("guide_bar", "guide_flare", "guide_kerb"):
            (_, _), (y0, _), _ = self._extent(n)
            self.assertGreaterEqual(y0, -0.0005, n)
        o = self.objects["guide_bar"]
        hit = _hit(o, (0.3, -1.0, self.kit.BAR[1]), (0.0, 1.0, 0.0))
        self.assertAlmostEqual(hit.y, 0.0, delta=0.001)
        # (The flare turns away from the car: its far end's face further back than its near end's.)
        f = self.objects["guide_flare"]
        near = _hit(f, (0.02, -1.0, self.kit.BAR[1]), (0.0, 1.0, 0.0))
        far = _hit(f, (self.kit.FLARE[0] - 0.05, -1.0, self.kit.BAR[1]), (0.0, 1.0, 0.0))
        self.assertLess(near.y, 0.01)
        self.assertGreater(far.y, self.kit.FLARE[1] * 0.7)

    def test_the_drain_is_flush_and_deep(self):
        _, (y0, y1), (z0, z1) = self._extent("drain")
        self.assertAlmostEqual(z1, 0.0, delta=0.001)
        self.assertAlmostEqual(y1 - y0, self.kit.DRAIN[0], delta=0.001)
        o = self.objects["drain"]
        # (Between two of its grating's bars a ray falls to the channel's floor; on a bar it stops at the bed's top.)
        hits = [_hit(o, (x / 100.0, 0.0, 1.0), (0.0, 0.0, -1.0)).z for x in range(2, 118, 1)]
        self.assertAlmostEqual(max(hits), 0.0, delta=0.001)
        self.assertLess(min(hits), -self.kit.DRAIN[1] + 0.03)

    def test_the_drains_end_is_stopped_flush(self):
        # (Where the trench meets the walkers' tunnels, a cast stop closes the channel, its top the bed's.)
        (x0, x1), (y0, y1), (z0, z1) = self._extent("drain_end")
        self.assertAlmostEqual(z1, 0.0, delta=0.001)
        self.assertAlmostEqual(y1 - y0, self.kit.DRAIN[0], delta=0.001)
        o = self.objects["drain_end"]
        for y in (-0.15, 0.0, 0.15):
            self.assertAlmostEqual(_hit(o, ((x0 + x1) / 2, y, 1.0), (0.0, 0.0, -1.0)).z, 0.0, delta=0.001, msg=y)


class StationTaquillas(unittest.TestCase):
    """The taquillas (tools/eclipse/station_taquillas.py; docs/superpowers/plans/2026-10-30-metro-station.md Task 7):
    the Light Company's two booths, each closed, in budget, through the gate; standing on the floor with its back on the
    wall's face (y = 0), its windows facing the hall (-y); through each window the seller's side seen between brass bars,
    a dished cash slot let into its chiluca counter under them, a blank sign and the Company's ward lamp over it. Built to
    the house's inspirations: a tezontle plinth, estípites between the windows, Talavera under them, a stepped fret and a
    stepped chiluca crown, a crest over the middle bearing the Company's emblem (the user's), the seller's own things."""

    @classmethod
    def setUpClass(cls):
        import station_taquillas
        cls.kit = station_taquillas
        station_taquillas.build()
        cls.objects = {o.name: o for o in bpy.context.scene.objects if o.type == "MESH"}

    def _extent(self, name):
        vs = _world(self.objects[name])
        return [(min(v[i] for v in vs), max(v[i] for v in vs)) for i in range(3)]

    def _slot(self, o, hit_index):
        return o.data.materials[o.data.polygons[hit_index].material_index].name

    def _ray(self, o, at, way):
        tree = BVHTree.FromObject(o, bpy.context.evaluated_depsgraph_get())
        found = tree.ray_cast(Vector(at), Vector(way), 20.0)
        return (found[0], self._slot(o, found[2])) if found[0] is not None else (None, None)

    def test_pieces_closed_in_budget_through_the_gate(self):
        import common
        import gate
        self.assertEqual(sorted(self.objects), sorted(n for n, _ in self.kit.PIECES))
        self.assertEqual({n: _closed(o) for n, o in self.objects.items() if _closed(o)}, {})
        for n, o in self.objects.items():
            faces, tris, _ = common.dump_faces([o])
            self.assertEqual(gate.check(faces, tris, [], budget=self.kit.BUDGET[n], sliver=self.kit.SLIVER[n])[:3], [], n)

    def test_a_booth_stands_on_the_floor_its_back_on_the_wall(self):
        # (8 m of wall each, the hall's 5 m clear over it for its coffers' fittings.)
        for n, count in self.kit.WINDOWS.items():
            (x0, x1), (y0, y1), (z0, z1) = self._extent(n)
            self.assertAlmostEqual(z0, 0.0, delta=0.001, msg=n)
            self.assertAlmostEqual(y1, 0.0, delta=0.001, msg=n)
            self.assertLessEqual(x1 - x0, 8.0, n)
            self.assertAlmostEqual(x0, -x1, delta=0.01, msg=n)
            # (Its crest under the hall's coffers and their fittings, 4.4 m up.)
            self.assertLessEqual(z1, 3.8, n)
            self.assertEqual(len(self.kit.window_xs(count)), count, n)
            self.assertIn(count, (2, 3), n)

    def test_through_every_window_the_seller_is_seen_between_brass_bars(self):
        front = -self.kit.DEPTH
        z = self.kit.COUNTER + (self.kit.WINDOW[1] - self.kit.COUNTER) * 0.4
        for n, count in self.kit.WINDOWS.items():
            o = self.objects[n]
            for k, cx in enumerate(self.kit.window_xs(count)):
                bars = self.kit.bar_xs(cx)
                self.assertGreaterEqual(len(bars), 6, (n, k))
                for a, b in zip(bars, bars[1:]):
                    hit, _ = self._ray(o, ((a + b) / 2, -5.0, z), (0.0, 1.0, 0.0))
                    self.assertGreater(hit.y, front + 0.1, (n, k, a))
                    # (Between two bars a hand's width at most.)
                    self.assertLessEqual(b - a, 0.13, (n, k, a))
                hit, slot = self._ray(o, (bars[1], -5.0, z), (0.0, 1.0, 0.0))
                self.assertEqual(slot, "brass", (n, k))
                self.assertLess(hit.y, front + 0.1, (n, k))

    def test_the_counter_carries_a_dished_slot_under_the_bars(self):
        front = -self.kit.DEPTH
        for n, count in self.kit.WINDOWS.items():
            o = self.objects[n]
            for cx in self.kit.window_xs(count):
                # (The counter's stone out in front of the window, at its height.)
                # (Rays down from inside the window's head, under the cornice and the lamp.)
                top = self.kit.WINDOW[1] - 0.05
                hit, slot = self._ray(o, (cx + 0.4, front - self.kit.COUNTER_OUT * 0.75, top), (0.0, 0.0, -1.0))
                self.assertAlmostEqual(hit.z, self.kit.COUNTER, delta=0.002, msg=(n, cx))
                self.assertEqual(slot, "chiluca", (n, cx))
                # (The dish under the slot sunk in it, brass worn by the coins; through the slot the seller's side.)
                hit, slot = self._ray(o, (cx, front - 0.05, top), (0.0, 0.0, -1.0))
                self.assertEqual(slot, "brass", (n, cx))
                self.assertLess(hit.z, self.kit.COUNTER - 0.03, (n, cx))
                hit, _ = self._ray(o, (cx, -5.0, self.kit.COUNTER + self.kit.SLOT[1] / 2), (0.0, 1.0, 0.0))
                self.assertGreater(hit.y, front + 0.1, (n, cx))

    def test_a_blank_sign_and_the_companys_lamp_over_every_window(self):
        front = -self.kit.DEPTH
        for n, count in self.kit.WINDOWS.items():
            o = self.objects[n]
            for cx in self.kit.window_xs(count):
                _, slot = self._ray(o, (cx, -5.0, sum(self.kit.SIGN) / 2), (0.0, 1.0, 0.0))
                self.assertEqual(slot, "sign", (n, cx))
                hit, slot = self._ray(o, (cx, self.kit.LAMP[0], 3.6), (0.0, 0.0, -1.0))
                self.assertIn(slot, ("brass", "glass"), (n, cx))
                self.assertGreater(hit.z, self.kit.WINDOW[1], (n, cx))
                self.assertLess(self.kit.LAMP[0], front, n)

    def _clear_of_lamps(self, count, x):
        return all(abs(x - cx) > 0.3 for cx in self.kit.window_xs(count))

    def test_it_stands_on_tezontle_under_a_stepped_chiluca_crown(self):
        # (Mayan-Revival setbacks: the cornice out over the frieze, each tier over it set further back.)
        front = -self.kit.DEPTH
        self.assertGreaterEqual(len(self.kit.CROWN), 3)
        outs = [out for _, _, out in sorted(self.kit.CROWN)]
        self.assertEqual(outs[1:], sorted(outs[1:], reverse=True))
        self.assertTrue(all(a > b for a, b in zip(outs[1:], outs[2:])), outs)
        for n, count in self.kit.WINDOWS.items():
            o = self.objects[n]
            x = self.kit.window_xs(count)[0] - 0.45
            _, slot = self._ray(o, (x, -5.0, self.kit.PLINTH[0] / 2), (0.0, 1.0, 0.0))
            self.assertEqual(slot, "tezontle", n)
            for z0, z1, out in self.kit.CROWN:
                hit, slot = self._ray(o, (x, -5.0, (z0 + z1) / 2), (0.0, 1.0, 0.0))
                self.assertEqual(slot, "chiluca", (n, z0))
                self.assertAlmostEqual(hit.y, front - out, delta=0.003, msg=(n, z0))

    def test_a_stepped_fret_runs_the_frieze(self):
        # (A greca along the frieze over the signs: raised steps on the frieze's ground, read in and out along it.)
        front = -self.kit.DEPTH
        z = sum(self.kit.FRET) / 2
        for n, count in self.kit.WINDOWS.items():
            o = self.objects[n]
            half = self.kit.length(count) / 2
            depths = []
            for i in range(int((2 * half - 0.6) * 100)):
                x = -half + 0.3 + i / 100.0
                if not self._clear_of_lamps(count, x):
                    continue
                hit, slot = self._ray(o, (x, -5.0, z), (0.0, 1.0, 0.0))
                self.assertEqual(slot, "chiluca", (n, x))
                depths.append(round(hit.y - front, 3))
            self.assertEqual(set(depths), {0.0, -self.kit.FRET_PROUD}, n)
            turns = sum(1 for a, b in zip(depths, depths[1:]) if a != b)
            self.assertGreaterEqual(turns, 4 * (2 * half - 0.6) * 0.5, n)

    def test_estipites_stand_between_the_windows(self):
        # (Inverted pyramids of chiluca: narrow at the counter, broad under the frieze.)
        front = -self.kit.DEPTH
        for n, count in self.kit.WINDOWS.items():
            o = self.objects[n]
            for cx in self.kit.window_xs(count)[:-1]:
                low, slot = self._ray(o, (cx, front - 0.03, self.kit.COUNTER + 0.15), (1.0, 0.0, 0.0))
                self.assertEqual(slot, "chiluca", (n, cx))
                high, slot = self._ray(o, (cx, front - 0.03, self.kit.TRANSOM - 0.05), (1.0, 0.0, 0.0))
                self.assertEqual(slot, "chiluca", (n, cx))
                self.assertLess(high.x, low.x - 0.05, (n, cx))

    def test_a_stepped_crest_over_the_middle_bears_the_companys_emblem(self):
        front = -self.kit.DEPTH
        for n, count in self.kit.WINDOWS.items():
            o = self.objects[n]
            hit, _ = self._ray(o, (0.0, front + 0.2, 5.0), (0.0, 0.0, -1.0))
            self.assertGreaterEqual(hit.z, self.kit.TOP + 0.3, n)
            hit, _ = self._ray(o, (self.kit.window_xs(count)[0] - 0.45, front + 0.2, 5.0), (0.0, 0.0, -1.0))
            self.assertAlmostEqual(hit.z, self.kit.TOP, delta=0.002, msg=n)
            # (Beside the middle lamp's rod.)
            _, slot = self._ray(o, (0.2, -5.0, sum(self.kit.EMBLEM) / 2), (0.0, 1.0, 0.0))
            self.assertEqual(slot, "sign", n)

    def test_the_companys_lamps_are_wards(self):
        # (Its lamps keep the dead off the till: caged, obsidian lenses on their four sides.)
        for n, count in self.kit.WINDOWS.items():
            o = self.objects[n]
            for cx in self.kit.window_xs(count):
                _, slot = self._ray(o, (cx, -5.0, self.kit.LAMP[1]), (0.0, 1.0, 0.0))
                self.assertEqual(slot, "obsidian", (n, cx))

    def test_talavera_under_every_window(self):
        talavera = {"talavera_cobalt", "talavera_glaze", "talavera_yellow"}
        # (Along the middle of a row of tiles, under the panel's middle: not along a joint.)
        rows = self.kit.TILE_GRID[1]
        z = self.kit.TILES[0] + (self.kit.TILES[1] - self.kit.TILES[0]) * (rows // 2 - 0.5) / rows
        for n, count in self.kit.WINDOWS.items():
            o = self.objects[n]
            for cx in self.kit.window_xs(count):
                found = []
                for i in range(-50, 51, 5):
                    _, slot = self._ray(o, (cx + i / 100.0, -5.0, z), (0.0, 1.0, 0.0))
                    found.append(slot)
                tiled = [f for f in found if f in talavera]
                self.assertGreaterEqual(len(tiled), len(found) * 0.6, (n, cx, found))
                self.assertGreaterEqual(len(set(tiled)), 2, (n, cx))

    def test_the_seller_keeps_their_own_things(self):
        # (A saint's card on the boards, marigolds in a tin on the desk.)
        for n, o in self.objects.items():
            self.assertLessEqual({"print_saint", "marigold", "tin"}, {m.name for m in o.data.materials}, n)

    def test_the_seller_stands_raised_behind_the_counter(self):
        # (Inside, the booth's boarded floor raised so the seller looks down over the counter; the desk behind each
        # window at the counter's height.)
        for n, count in self.kit.WINDOWS.items():
            o = self.objects[n]
            for cx in self.kit.window_xs(count):
                hit, slot = self._ray(o, (cx + 0.5, -0.5, 2.0), (0.0, 0.0, -1.0))
                self.assertAlmostEqual(hit.z, self.kit.FLOOR, delta=0.002, msg=(n, cx))
                self.assertEqual(slot, "wood", (n, cx))


class StationTurnstiles(unittest.TestCase):
    """The turnstile banks (tools/eclipse/station_turnstiles.py; docs/superpowers/plans/2026-10-30-metro-station.md
    Task 8): two banks across the hall, each its cabinets across its middle and a railing from them to both walls; every
    lane at least 1.1 m clear for the player's capsule. Built to the house's inspirations: cabinets on tezontle under
    stepped tops, the Company's ward eyes and tally dials, stepped chiluca pylons, an open stepped fret in the railings.
    The west bank's half fused open by the surge (blackened, its arms melted and hanging, its eyes blown out, the dead's
    fare left on it), its other half patched in the Company's planks; the working arms a piece of their own."""

    @classmethod
    def setUpClass(cls):
        import station_turnstiles
        cls.kit = station_turnstiles
        station_turnstiles.build()
        cls.objects = {o.name: o for o in bpy.context.scene.objects if o.type == "MESH"}
        cls.banks = {n: cls.objects[n] for n in ("bank_east", "bank_west")}

    def _extent(self, name):
        vs = _world(self.objects[name])
        return [(min(v[i] for v in vs), max(v[i] for v in vs)) for i in range(3)]

    def _ray(self, o, at, way, far=20.0):
        tree = BVHTree.FromObject(o, bpy.context.evaluated_depsgraph_get())
        found = tree.ray_cast(Vector(at), Vector(way), far)
        if found[0] is None:
            return None, None
        return found[0], o.data.materials[o.data.polygons[found[2]].material_index].name

    def test_pieces_closed_in_budget_through_the_gate(self):
        import common
        import gate
        self.assertEqual(sorted(self.objects), sorted(n for n, _ in self.kit.PIECES))
        self.assertEqual({n: _closed(o) for n, o in self.objects.items() if _closed(o)}, {})
        for n, o in self.objects.items():
            faces, tris, _ = common.dump_faces([o])
            self.assertEqual(gate.check(faces, tris, [], budget=self.kit.BUDGET[n], sliver=self.kit.SLIVER[n])[:3], [], n)

    def test_a_bank_runs_wall_to_wall_on_the_floor(self):
        self.assertAlmostEqual(self.kit.HALF, 14.0 - 0.3 - 0.067, places=6)
        xs = self.kit.cabinet_xs()
        self.assertAlmostEqual(xs[0] - self.kit.CAB[0] / 2, -4.0, delta=0.01)
        self.assertAlmostEqual(xs[-1] + self.kit.CAB[0] / 2, 4.0, delta=0.01)
        for n in self.banks:
            (x0, x1), (y0, y1), (z0, z1) = self._extent(n)
            self.assertAlmostEqual(x0, -self.kit.HALF, delta=0.002, msg=n)
            self.assertAlmostEqual(x1, self.kit.HALF, delta=0.002, msg=n)
            self.assertAlmostEqual(z0, 0.0, delta=0.001, msg=n)
            self.assertLessEqual(y1 - y0, 2.0, n)
            # (Nothing over the hall's walks hangs; its pylons stand under the coffers' fittings.)
            self.assertLessEqual(z1, 2.4, n)

    def _clear_run(self, o, k):
        """The widest run across lane k (m) that no ray along the walk meets, from the floor to 2 m."""
        xs = self.kit.cabinet_xs()
        a, b = xs[k], xs[k + 1]
        best = run = 0.0
        x = a
        while x <= b:
            hit = any(self._ray(o, (x, -3.0, z / 10.0), (0.0, 1.0, 0.0), 6.0)[0] is not None for z in range(1, 21))
            run = 0.0 if hit else run + 0.005
            best = max(best, run)
            x += 0.005
        return best

    def test_every_lane_is_at_least_1_1_m_clear(self):
        for n, o in self.banks.items():
            lanes = self.kit.lane_xs()
            self.assertEqual(len(lanes), 4, n)
            for k in range(len(lanes)):
                self.assertGreaterEqual(self._clear_run(o, k), 1.1, (n, k))

    def test_cabinets_stand_on_tezontle_under_stepped_tops(self):
        halves = [h for _, _, h in self.kit.STEPS]
        self.assertEqual(halves, sorted(halves, reverse=True))
        for n, o in self.banks.items():
            for cx in self.kit.cabinet_xs():
                _, slot = self._ray(o, (cx, -3.0, self.kit.PLINTH[0] / 2), (0.0, 1.0, 0.0))
                self.assertEqual(slot, "tezontle", (n, cx))
                for i, (z0, z1, h) in enumerate(self.kit.STEPS):
                    inner = self.kit.STEPS[i + 1][2] if i + 1 < len(self.kit.STEPS) else 0.0
                    hit, _ = self._ray(o, (cx + (h + inner) / 2, 0.6, 3.0), (0.0, 0.0, -1.0))
                    self.assertAlmostEqual(hit.z, z1, delta=0.002, msg=(n, cx, i))

    def test_the_companys_eyes_and_dials_face_the_entry(self):
        for n, o in self.banks.items():
            for k, cx in enumerate(self.kit.cabinet_xs()):
                fused = n == "bank_west" and k < 2
                _, slot = self._ray(o, (cx, -3.0, self.kit.EYE[0]), (0.0, 1.0, 0.0))
                self.assertEqual(slot, "hollow" if fused else "obsidian", (n, k))
                _, slot = self._ray(o, (cx, -3.0, self.kit.DIAL[1]), (0.0, 1.0, 0.0))
                self.assertEqual(slot, "brass_burnt" if fused else "sign", (n, k))

    def test_stepped_pylons_crown_the_outer_cabinets(self):
        for n, o in self.banks.items():
            for k, cx in enumerate((self.kit.cabinet_xs()[0], self.kit.cabinet_xs()[-1])):
                hit, slot = self._ray(o, (cx, 0.0, 5.0), (0.0, 0.0, -1.0))
                smoked = n == "bank_west" and k == 0
                self.assertEqual(slot, "chiluca_scorched" if smoked else "chiluca", (n, cx))
                self.assertAlmostEqual(hit.z, self.kit.PYLON[-1][1], delta=0.002, msg=(n, cx))
                for side in (-1, 1):
                    _, slot = self._ray(o, (cx, side * 3.0, sum(self.kit.PLAQUE[:2]) / 2), (0.0, -side, 0.0))
                    self.assertEqual(slot, "sign", (n, cx, side))

    def test_railings_with_an_open_stepped_fret_reach_the_walls(self):
        for n, o in self.banks.items():
            for side in (-1, 1):
                # (A newel against the wall.)
                _, slot = self._ray(o, (side * (self.kit.HALF - 0.05), 0.0, 5.0), (0.0, 0.0, -1.0))
                self.assertEqual(slot, "chiluca", (n, side))
                # (The last bay: a brass handrail over it; its fret open, seen through.)
                mid = side * (self.kit.HALF - self.kit.NEWEL - 1.0)
                hit, slot = self._ray(o, (mid, 0.0, 5.0), (0.0, 0.0, -1.0))
                self.assertEqual(slot, "brass", (n, side))
                self.assertGreater(hit.z, self.kit.TOP_BAR, (n, side))
                seen = [self._ray(o, (mid - 0.9 + i / 100.0, -3.0, 0.55), (0.0, 1.0, 0.0), 6.0)[1] for i in range(180)]
                self.assertGreaterEqual(seen.count(None), 50, (n, side))
                self.assertGreaterEqual(seen.count("iron"), 18, (n, side))

    def test_a_staff_gate_chained_shut(self):
        near = self.kit.cabinet_xs()[-1] + self.kit.CAB[0] / 2 + self.kit.PLINTH[1] + self.kit.NEWEL
        for n, o in self.banks.items():
            _, slot = self._ray(o, (near + 0.06, -3.0, 0.535), (0.0, 1.0, 0.0))
            self.assertEqual(slot, "brass", n)

    def _side(self, o, k, face):
        """What lane k's ray meets on cabinet k's +x face (face 1) or cabinet k+1's -x face (face -1), at several
        places along it under the band."""
        x = self.kit.lane_xs()[k]
        found = []
        for y in (-0.6, -0.35, 0.35, 0.6):
            for z in (0.25, 0.4, 0.52):
                found.append(self._ray(o, (x, y, z), (-face, 0.0, 0.0), 1.0)[1])
        return found

    def test_the_west_banks_north_half_fused_its_south_half_patched(self):
        west, east = self.banks["bank_west"], self.banks["bank_east"]
        for k in (0, 1):
            found = self._side(west, k, 1)
            self.assertGreaterEqual(found.count("scorched"), len(found) * 0.8, (k, found))
        for k in (2, 3):
            found = self._side(west, k, 1)
            self.assertGreaterEqual(found.count("wood"), len(found) * 0.6, (k, found))
        for k in range(4):
            found = self._side(east, k, 1)
            self.assertEqual(set(found), {"iron"}, (k, found))
        # (The fused arms hang: nothing of them across the lane at the hub's height.)
        for k in (0, 1):
            hub = self.kit.hub_at(k)
            hit, _ = self._ray(west, (self.kit.cabinet_xs()[k + 1] - 0.4, 0.0, hub[2]), (-1.0, 0.0, 0.0), 2.0)
            self.assertLess(hit.x, hub[0] + 0.1, k)

    def test_the_fused_half_reads_burnt(self):
        # (Its iron charred warm, its brass heat-tinted, the pylon over it blackened from its foot: never the neutral
        # black the cold light turns navy, as iron's is.)
        import json
        recipes = common.ROOT / "tools" / "textures" / "recipes" / "underground"
        for name in ("scorched", "brass_burnt", "chiluca_scorched"):
            recipe = json.loads((recipes / (name + ".json")).read_text())
            r, g, b = (int(recipe["colour"][i:i + 2], 16) for i in (1, 3, 5))
            self.assertGreaterEqual(r - b, 0x10, name)
        self.assertGreater(json.loads((recipes / "chiluca_scorched.json").read_text())["height_light"], 0.3)
        west = self.banks["bank_west"]
        used = {m.name for m in west.data.materials} | {m.name for m in self.banks["bank_east"].data.materials}
        self.assertNotIn("soot_black", used)
        xs = self.kit.cabinet_xs()
        for cx, slot in ((xs[0], "chiluca_scorched"), (xs[-1], "chiluca")):
            _, found = self._ray(west, (cx - 3.0, 0.0, 1.5), (1.0, 0.0, 0.0))
            self.assertEqual(found, slot, cx)
        hub = self.kit.hub_at(0)
        _, found = self._ray(west, (hub[0] + 0.035, -0.3, 0.38), (0.0, 1.0, 0.0), 1.0)
        self.assertEqual(found, "brass_burnt")

    def test_the_dead_are_left_their_fare(self):
        found = {m.name for m in self.banks["bank_west"].data.materials}
        self.assertLessEqual({"copper", "silver", "print_saint", "marigold", "wax"}, found)
        self.assertFalse({"copper", "print_saint", "marigold", "wax"} & {m.name for m in self.banks["bank_east"].data.materials})

    def test_the_arms_turn_about_their_hub(self):
        dirs = self.kit.arm_directions()
        a = self.kit.axis()
        for i in range(3):
            self.assertAlmostEqual(dirs[i].dot(a), dirs[0].dot(a), places=5)
            for j in range(i + 1, 3):
                self.assertAlmostEqual(dirs[i].angle(dirs[j]), dirs[1].angle(dirs[2]), places=5)
        self.assertAlmostEqual(dirs[0].z, 0.0, places=6)
        (x0, x1), (y0, y1), (z0, z1) = self._extent("rotor")
        self.assertTrue(x0 < 0.0 < x1 and y0 < 0.0 < y1 and z0 < 0.0 < z1)
        self.assertGreaterEqual(x1, 0.9)
        for k in range(4):
            hub = self.kit.hub_at(k)
            far = self.kit.cabinet_xs()[k + 1] - self.kit.CAB[0] / 2 - self.kit.BAND[2]
            self.assertLessEqual(hub[0] + x1, far - 0.15, k)
            self.assertGreaterEqual(hub[2] + z0, 0.1, k)
            # (The boss it turns in, brass on the working cabinets.)
            _, slot = self._ray(self.banks["bank_east"], (hub[0] + 0.3, 0.0, hub[2]), (-1.0, 0.0, 0.0), 1.0)
            self.assertEqual(slot, "brass", k)


class StationLamps(unittest.TestCase):
    """The Company's bracket lamps (tools/eclipse/station_lamps.py; docs/superpowers/plans/2026-10-31-station-machinery.md
    Task 1), v2 on the user's note ("more work to look like lamps, more aesthetically distinct"): closed, in budget,
    through the gate; a stepped back plate on the face (y = 0), a gooseneck arm out along -y; a tall eight-sided glass
    lantern hung from it (mostly glass, read as a lamp across the hall), its crown stepped, a low sunburst round it, a turned knob over it;
    the Company's obsidian ward eye on the glass's front (the lamps are wards); a tin milagro tied under it. Nothing more
    than MOUNT_DROP under its mount, so on a wall at BRACKET_MOUNT it hangs over 2.4 m above the walks."""

    @classmethod
    def setUpClass(cls):
        import station_lamps
        cls.kit = station_lamps
        station_lamps.build()
        cls.objects = {o.name: o for o in bpy.context.scene.objects if o.type == "MESH"}

    def _ray(self, o, at, way):
        tree = BVHTree.FromObject(o, bpy.context.evaluated_depsgraph_get())
        found = tree.ray_cast(Vector(at), Vector(way), 5.0)
        if found[0] is None:
            return None, None
        return found[0], o.data.materials[o.data.polygons[found[2]].material_index].name

    def test_pieces_closed_in_budget_through_the_gate(self):
        import common
        import gate
        self.assertEqual(sorted(self.objects), sorted(n for n, _ in self.kit.PIECES))
        self.assertEqual({n: _closed(o) for n, o in self.objects.items() if _closed(o)}, {})
        for n, o in self.objects.items():
            faces, tris, _ = common.dump_faces([o])
            self.assertEqual(gate.check(faces, tris, [], budget=self.kit.BUDGET[n], sliver=self.kit.SLIVER[n])[:3], [], n)

    def test_it_hangs_off_the_face_clear_of_the_walk(self):
        vs = _world(self.objects["ward_bracket"])
        (x0, x1), (y0, y1), (z0, z1) = [(min(v[i] for v in vs), max(v[i] for v in vs)) for i in range(3)]
        self.assertAlmostEqual(y1, 0.0, delta=0.001)
        self.assertGreaterEqual(y0, -1.0)
        self.assertGreaterEqual(z0, -self.kit.MOUNT_DROP)
        self.assertLessEqual(self.kit.MOUNT_DROP, 1.1)
        self.assertLessEqual(x1 - x0, 0.7)

    def test_a_tall_glass_lantern_most_of_its_face(self):
        # (Seen from the front and the sides through its middle, glass most of the way up its body.)
        o = self.objects["ward_bracket"]
        gy, gz = self.kit.GLOBE
        z0, z1 = gz - self.kit.LANTERN[1] / 2 + 0.03, gz + self.kit.LANTERN[1] / 2 - 0.03
        self.assertGreaterEqual(self.kit.LANTERN[1], 0.45)
        self.assertGreaterEqual(self.kit.LANTERN[0], 0.28)
        for at, way in (((1.0, gy, None), (-1.0, 0.0, 0.0)), ((-1.0, gy, None), (1.0, 0.0, 0.0))):
            found = [self._ray(o, (at[0], at[1], z0 + (z1 - z0) * k / 10), way)[1] for k in range(11)]
            self.assertGreaterEqual(found.count("glass"), 7, found)

    def test_the_companys_eye_on_its_front(self):
        o = self.objects["ward_bracket"]
        gy, gz = self.kit.GLOBE
        _, slot = self._ray(o, (0.0, gy - 1.0, gz), (0.0, 1.0, 0.0))
        self.assertEqual(slot, "obsidian")

    def test_a_stepped_crown_with_a_sunburst_and_a_knob(self):
        o = self.objects["ward_bracket"]
        gy, gz = self.kit.GLOBE
        top = gz + self.kit.LANTERN[1] / 2
        self.assertGreaterEqual(len(self.kit.CROWN), 3)
        halves = [h for h, _, _ in self.kit.CROWN]
        self.assertEqual(halves, sorted(halves, reverse=True))
        # (Its knob over the crown, seen from the side.)
        _, slot = self._ray(o, (1.0, gy, top + self.kit.CROWN[-1][2] + 0.06), (-1.0, 0.0, 0.0))
        self.assertEqual(slot, "brass")
        # (Rays out round the crown: brass rays in some directions, none in others.)
        found = [self._ray(o, (0.6 * math.cos(2 * math.pi * k / 48), gy + 0.6 * math.sin(2 * math.pi * k / 48),
                               top + self.kit.SUN_AT), (-math.cos(2 * math.pi * k / 48), -math.sin(2 * math.pi * k / 48), 0.0))[0]
                 for k in range(48)]
        self.assertGreaterEqual(sum(1 for f in found if f is not None and (Vector(f) - Vector((0, gy, f[2]))).length > 0.2), 8)

    def test_the_arm_is_joined_at_both_ends_and_its_brace_meets_it(self):
        # (The user, Oct 31: "the gooseneck is not properly connected".)
        neck, brace = [Vector(p) for p in self.kit.neck_points()], [Vector(p) for p in self.kit.brace_points()]

        def off_neck(q):
            return min(geometry.intersect_point_line(q, a, b)[0].__sub__(q).length
                       if 0.0 <= geometry.intersect_point_line(q, a, b)[1] <= 1.0 else min((q - a).length, (q - b).length)
                       for a, b in zip(neck, neck[1:]))

        self.assertLessEqual(off_neck(brace[-1]), self.kit.ARM_R * 0.5)
        o = self.objects["ward_bracket"]
        # (Its root inside the corbel, its end inside the socket over the finial: solid metal round both.)
        for q in (neck[0], neck[-1]):
            hits = sum(1 for way in ((1, 0, 0), (-1, 0, 0), (0, 0, 1), (0, 0, -1))
                       if self._ray(o, tuple(q), way)[0] is not None)
            self.assertEqual(hits, 4, tuple(q))
        # (The brace's foot on the back plate.)
        self.assertLessEqual(abs(brace[0].y + self.kit.PLATE[0][3]), 0.02)

    def test_its_shape_is_subtle(self):
        # (The user, Oct 31: "the thorns are a bit too much": the sunburst short fins hugging the crown, a knob for
        # a spike.)
        self.assertLessEqual(self.kit.SUN_REACH, self.kit.CROWN[0][0] / math.cos(math.pi / self.kit.SIDES) + 0.05)
        self.assertLessEqual(self.kit.SPIKE, 0.13)

    def test_a_milagro_tied_under_it(self):
        self.assertIn("tin", {m.name for m in self.objects["ward_bracket"].data.materials})


class StationNeon(unittest.TestCase):
    """The station's neon (tools/eclipse/station_neon.py; docs/superpowers/plans/2026-10-31-station-machinery.md Task 2):
    the symbols in tube (slot `neon` only, drawn by Neon's shader in game), each fitting a hanging board's face; the
    Company's crowned blade sign: a blank face (the user's words), a stepped deco crown, under 2.4 m tall."""

    @classmethod
    def setUpClass(cls):
        import station_neon
        cls.kit = station_neon
        station_neon.build()
        cls.objects = {o.name: o for o in bpy.context.scene.objects if o.type == "MESH"}

    def _extent(self, name):
        vs = _world(self.objects[name])
        return [(min(v[i] for v in vs), max(v[i] for v in vs)) for i in range(3)]

    def _ray(self, o, at, way):
        tree = BVHTree.FromObject(o, bpy.context.evaluated_depsgraph_get())
        found = tree.ray_cast(Vector(at), Vector(way), 10.0)
        if found[0] is None:
            return None, None
        return found[0], o.data.materials[o.data.polygons[found[2]].material_index].name

    def test_pieces_closed_in_budget_through_the_gate(self):
        import common
        import gate
        self.assertEqual(sorted(self.objects), sorted(n for n, _ in self.kit.PIECES))
        self.assertEqual({n: _closed(o) for n, o in self.objects.items() if _closed(o)}, {})
        for n, o in self.objects.items():
            faces, tris, _ = common.dump_faces([o])
            self.assertEqual(gate.check(faces, tris, [], budget=self.kit.BUDGET[n], sliver=self.kit.SLIVER[n])[:3], [], n)

    def test_the_symbols_are_tube_on_a_boards_face(self):
        names = ["symbol_" + n for n in ("marigold", "eye", "skull", "serpent", "hand", "arrow")]
        self.assertLessEqual(set(names), set(self.objects))
        self.assertTrue(0.012 <= self.kit.TUBE_R <= 0.02)
        for n in names:
            o = self.objects[n]
            self.assertEqual({m.name for m in o.data.materials}, {"neon"}, n)
            (x0, x1), (y0, y1), (z0, z1) = self._extent(n)
            self.assertLessEqual(x1 - x0, 0.32 + 2 * self.kit.TUBE_R, n)
            self.assertLessEqual(z1 - z0, 0.32 + 2 * self.kit.TUBE_R, n)
            self.assertLessEqual(y1 - y0, 2 * self.kit.TUBE_R + 0.002, n)
            self.assertAlmostEqual((x0 + x1) / 2, 0.0, delta=0.03, msg=n)
            self.assertAlmostEqual((z0 + z1) / 2, 0.0, delta=0.03, msg=n)

    def test_a_neon_board_holds_its_symbols(self):
        # (The user, Oct 31: the symbols enlarged must fit on the board: a board of the neon's own, hung on its rods
        # from the ceiling (z = 0), its blank face both sides wide and tall enough for an arrow and a symbol 1.5 times
        # their drawn size at its ends and the user's words between.)
        (x0, x1), (y0, y1), (z0, z1) = self._extent("neon_board")
        self.assertAlmostEqual(z1, 0.0, delta=0.001)
        w, h, _ = self.kit.NEON_BOARD
        self.assertAlmostEqual(x1 - x0, w, delta=0.01)
        fw, fh = self.kit.NEON_FACE
        symbol = 0.32 * 1.5 + 2 * self.kit.TUBE_R * 1.5
        self.assertGreaterEqual(fh, symbol + 0.02)
        self.assertGreaterEqual(fw, 2 * (symbol + 0.04) + 0.9)
        o = self.objects["neon_board"]
        mid = -self.kit.NEON_DROP - h / 2
        for side in (-1, 1):
            for x in (-fw / 2 + 0.05, 0.0, fw / 2 - 0.05):
                _, slot = self._ray(o, (x, side * 3.0, mid), (0.0, -side, 0.0))
                self.assertEqual(slot, "sign", (side, x))

    def test_the_companys_blade_sign(self):
        (x0, x1), (y0, y1), (z0, z1) = self._extent("blade_company")
        self.assertAlmostEqual(z0, 0.0, delta=0.001)
        self.assertLessEqual(z1, 2.4)
        self.assertGreaterEqual(len(self.kit.CROWN), 3)
        halves = [h for h, _, _ in self.kit.CROWN]
        self.assertEqual(halves, sorted(halves, reverse=True))
        o = self.objects["blade_company"]
        for side in (-1, 1):
            _, slot = self._ray(o, (0.0, side * 3.0, self.kit.FACE_AT), (0.0, -side, 0.0))
            self.assertEqual(slot, "sign", side)


class StationRuns(unittest.TestCase):
    """The Company's cable runs (tools/eclipse/station_runs.py; docs/superpowers/plans/2026-10-31-station-machinery.md
    Task 4): one piece per run in the set's frame, its cable chunky brass sagging between its hangers, an insulator bell
    at each; every run from the engine's crown junction; its sampled path written to station_runs.json for the arcs."""

    @classmethod
    def setUpClass(cls):
        import station_runs
        cls.kit = station_runs
        station_runs.build()
        cls.objects = {o.name: o for o in bpy.context.scene.objects if o.type == "MESH"}

    def test_pieces_closed_in_budget_through_the_gate(self):
        import common
        import gate
        self.assertEqual(sorted(self.objects), sorted(n for n, _ in self.kit.PIECES))
        self.assertEqual({n: _closed(o) for n, o in self.objects.items() if _closed(o)}, {})
        for n, o in self.objects.items():
            faces, tris, _ = common.dump_faces([o])
            self.assertEqual(gate.check(faces, tris, [], budget=self.kit.BUDGET[n], sliver=self.kit.SLIVER[n])[:3], [], n)

    def test_six_runs_from_the_engine_chunky(self):
        self.assertEqual(len(self.kit.RUNS), 6)
        self.assertGreaterEqual(self.kit.CABLE_R, 0.03)
        for name, run in self.kit.RUNS.items():
            path = self.kit.path(name)
            start = Vector(path[0])
            self.assertLessEqual((start - Vector(self.kit.ENGINE_TERMINAL)).length, 0.05, name)
            self.assertIn("to", run)
            # (Its cable within its hangers' sag of the line between its anchors: no kinks, no loops.)
            self.assertGreater(len(path), len(run["anchors"]), name)

    def test_each_run_a_bundle_of_cables(self):
        # (The user, Oct 31: "add more cables": each run three cables side by side, held by its hangers.)
        self.assertGreaterEqual(len(self.kit.BUNDLE), 3)
        offsets = sorted(self.kit.BUNDLE)
        self.assertTrue(all(b - a >= 2 * self.kit.CABLE_R + 0.02 for a, b in zip(offsets, offsets[1:])))

    def test_the_json_carries_each_runs_path(self):
        import json
        self.kit.write_json()
        data = json.loads(self.kit.JSON.read_text())
        self.assertEqual(sorted(data), sorted(self.kit.RUNS))
        for name in data:
            self.assertEqual(data[name]["to"], self.kit.RUNS[name]["to"])
            self.assertEqual(len(data[name]["points"]), len(self.kit.path(name)))


class StationPipes(unittest.TestCase):
    """The Company's pipe racks (tools/eclipse/station_pipes.py; the user, Oct 31: "add more cables, piping around"):
    big pipes along the hall's long walls and the platforms' back walls on iron brackets, each rack a piece of its own in
    the set's frame; closed, in budget, through the gate."""

    @classmethod
    def setUpClass(cls):
        import station_pipes
        cls.kit = station_pipes
        station_pipes.build()
        cls.objects = {o.name: o for o in bpy.context.scene.objects if o.type == "MESH"}

    def test_pieces_closed_in_budget_through_the_gate(self):
        import common
        import gate
        self.assertEqual(sorted(self.objects), sorted(n for n, _ in self.kit.PIECES))
        self.assertEqual({n: _closed(o) for n, o in self.objects.items() if _closed(o)}, {})
        for n, o in self.objects.items():
            faces, tris, _ = common.dump_faces([o])
            self.assertEqual(gate.check(faces, tris, [], budget=self.kit.BUDGET[n], sliver=self.kit.SLIVER[n])[:3], [], n)

    def test_big_pipes_on_brackets(self):
        # (The user, Oct 31: "bigger".)
        self.assertGreaterEqual(len(self.kit.PIPES), 3)
        self.assertGreaterEqual(max(r for _, r, _ in self.kit.PIPES), 0.13)
        self.assertLessEqual(self.kit.BRACKET_EVERY, 2.4)
        self.assertGreaterEqual(len(self.kit.RACKS), 6)

    def test_mains_risers_and_mouths(self):
        # (A large machine being run: mains half a metre across under the coffers' beams, risers floor to ceiling, mouths
        # venting from the floor.)
        for name, (z, r, y, reach, floor, limit) in self.kit.MAINS.items():
            self.assertGreaterEqual(2 * r, 0.35, name)
            self.assertLessEqual(y + r, limit, name)
            self.assertGreaterEqual(y - r, floor + 2.4, name)
        self.assertGreaterEqual(len(self.kit.MAINS), 6)
        self.assertGreaterEqual(max(2 * r for _, r, *_ in self.kit.MAINS.values()), 0.5)
        # (Engrained: the floor's mains half sunk, the trays full of cables.)
        r, up = self.kit.FLOOR_MAIN
        self.assertLessEqual(up + r, 0.3)
        self.assertLess(up, r)
        self.assertGreaterEqual(len(self.kit.FLOOR_MAINS), 4)
        self.assertGreaterEqual(self.kit.TRAY_CABLES, 5)
        self.assertGreaterEqual(len(self.kit.RISERS), 8)
        self.assertGreaterEqual(2 * self.kit.RISER[0], 0.5)
        self.assertGreaterEqual(2 * self.kit.MOUTH[2], 1.0)


class StationDucts(unittest.TestCase):
    """The station's ducts (tools/eclipse/station_ducts.py: the floor's mains, the trays, the mouths, their feeds),
    closed, in budget, through the gate; a mouth standing on z = 0."""

    @classmethod
    def setUpClass(cls):
        import station_ducts
        cls.kit = station_ducts
        station_ducts.build()
        cls.objects = {o.name: o for o in bpy.context.scene.objects if o.type == "MESH"}

    def test_pieces_closed_in_budget_through_the_gate(self):
        import common
        import gate
        self.assertEqual(sorted(self.objects), sorted(n for n, _ in self.kit.PIECES))
        self.assertEqual({n: _closed(o) for n, o in self.objects.items() if _closed(o)}, {})
        for n, o in self.objects.items():
            faces, tris, _ = common.dump_faces([o])
            self.assertEqual(gate.check(faces, tris, [], budget=self.kit.BUDGET[n], sliver=self.kit.SLIVER[n])[:3], [], n)

    def test_a_mouth_stands_on_the_floor(self):
        vs = _world(self.objects["mouth"])
        self.assertAlmostEqual(min(v[2] for v in vs), 0.0, delta=0.001)


class YourShapes(unittest.TestCase):
    """The user's shapes kept through a kit's rebuild (tools/eclipse/your_shapes.py; docs/superpowers/plans/
    2026-10-30-metro-station.md Task 2): a vertex the user moved in a piece's .blend survives the next build; an
    untouched piece writes nothing; a kept shape still meets the gate; a shape for a piece no longer built is reported,
    never lost. Built in a folder of its own, never the repository's."""

    KIT = "yours_test"

    def setUp(self):
        import tempfile
        from pathlib import Path
        import common
        import your_shapes
        self.common, self.yours = common, your_shapes
        self.folder = Path(tempfile.mkdtemp())
        self.kept = (common.SOURCE, your_shapes.YOURS)
        common.SOURCE = self.folder / "source"
        your_shapes.YOURS = self.folder / "yours"

    def tearDown(self):
        import shutil
        self.common.SOURCE, self.yours.YOURS = self.kept
        shutil.rmtree(self.folder, ignore_errors=True)

    def _build(self):
        """The test kit: a box and a cylinder, side by side, built and exported."""
        self.common.reset()
        bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0.0, 0.0, 0.5))
        box = bpy.context.active_object
        box.name = "box"
        bpy.ops.mesh.primitive_cylinder_add(vertices=12, radius=0.4, depth=1.0, location=(2.0, 0.0, 0.5))
        bpy.context.active_object.name = "drum"
        for o in bpy.context.scene.objects:
            o.data.materials.append(self.common.slot("stone_step"))
        self.common.export_piece(self.KIT, 256, ["stone_step"], out=self.folder / "kit", sets_each=True)
        return {o.name: o for o in bpy.context.scene.objects if o.type == "MESH"}

    def _top(self, o):
        return max((o.matrix_world @ v.co).z for v in o.data.vertices)

    def test_a_moved_vertex_survives_the_next_build(self):
        objects = self._build()
        drum = sorted(round(v.co.z, 4) for v in objects["drum"].data.vertices)
        top = max(objects["box"].data.vertices, key=lambda v: (v.co.z, v.co.x, v.co.y))
        top.co.z += 0.05
        self.assertEqual(self.yours.harvest(list(objects.values()), self.KIT), ["box"])
        objects = self._build()
        self.assertAlmostEqual(self._top(objects["box"]), 1.05, delta=0.001)
        self.assertEqual(sorted(round(v.co.z, 4) for v in objects["drum"].data.vertices), drum)

    def test_an_untouched_piece_writes_nothing(self):
        objects = self._build()
        self.assertEqual(self.yours.harvest(list(objects.values()), self.KIT), [])
        self._build()
        self.assertFalse((self.yours.YOURS / self.KIT).exists() and any((self.yours.YOURS / self.KIT).iterdir()))

    def test_a_kept_shape_still_meets_the_gate(self):
        objects = self._build()
        # (A second lid laid 1 cm over its top, a layered face: the gate catches it on the next build.)
        work = bmesh.new()
        work.from_mesh(objects["box"].data)
        work.faces.ensure_lookup_table()
        lid = max(work.faces, key=lambda f: f.calc_center_median().z)
        copy = bmesh.ops.duplicate(work, geom=[lid])["geom"]
        bmesh.ops.translate(work, vec=(0.0, 0.0, 0.01), verts=[g for g in copy if isinstance(g, bmesh.types.BMVert)])
        work.to_mesh(objects["box"].data)
        work.free()
        self.yours.harvest(list(objects.values()), self.KIT)
        with self.assertRaises(SystemExit):
            self._build()

    def test_a_shape_for_a_piece_no_longer_built_is_reported_not_lost(self):
        objects = self._build()
        objects["box"].data.vertices[0].co.z -= 0.05
        self.yours.harvest(list(objects.values()), self.KIT)
        (self.yours.YOURS / self.KIT / "box.npz").rename(self.yours.YOURS / self.KIT / "gone.npz")
        objects = self._build()
        self.assertEqual(self.yours.keep(list(objects.values()), self.KIT), [])
        self.assertTrue((self.yours.YOURS / self.KIT / "gone.npz").exists())


class StationEngine(unittest.TestCase):
    """The Company's engine at the hall's middle (tools/eclipse/station_engine.py; the spec's item 5; the user, Oct 31:
    "it looks like a toy instead of a gigantic engine ... more things going on at the same time"): a stepped plinth with
    a railed walk round a tezontle housing, flywheels driving pistons, a glowing dynamo drum under a dome, a governor
    on its crown, gear trains in its windows, rows of big tubes into the coffers with gauge boards. Two static pieces
    (stone, works), each on its own atlas, and the moving pieces. Closed, in budget, through the gate."""

    @classmethod
    def setUpClass(cls):
        import station_engine
        cls.kit = station_engine
        station_engine.build()
        cls.objects = {o.name: o for o in bpy.context.scene.objects if o.type == "MESH"}
        cls.static = [cls.objects[n] for n in station_engine.STATIC]

    def _hit(self, at, way, reach):
        hits = [h for h in (_hit(o, at, way, reach) for o in self.static) if h is not None]
        return min(hits, key=lambda h: (h - Vector(at)).length) if hits else None

    def _open(self, o):
        """Open edges of its solids (its dial cards are open by nature)."""
        bm = bmesh.new()
        bm.from_mesh(o.data)
        cards = {i for i, mat in enumerate(o.data.materials) if mat.name in self.kit.CARDS}
        open_edges = sum(1 for e in bm.edges if len(e.link_faces) != 2
                         and not all(f.material_index in cards for f in e.link_faces))
        bm.free()
        return open_edges

    def test_pieces_closed_in_budget_through_the_gate(self):
        import common
        import gate
        self.assertEqual(sorted(self.objects), sorted(n for n, _ in self.kit.PIECES))
        self.assertEqual({n: self._open(o) for n, o in self.objects.items() if self._open(o)}, {})
        for n, o in self.objects.items():
            faces, tris, _ = common.dump_faces([o], skip=self.kit.CARDS)
            self.assertEqual(gate.check(faces, tris, [], budget=self.kit.BUDGET[n], sliver=self.kit.SLIVER[n])[:3], [], n)

    def test_every_gauge_has_its_dial_under_its_glass(self):
        o = self.objects["engine_works"]
        dials = [p for p in o.data.polygons if o.data.materials[p.material_index].name in self.kit.CARDS]
        # (Each card drawn from both sides.)
        self.assertEqual(len(dials), 2 * sum(len(c) for c in self.kit.GAUGES))

    def test_it_stands_floor_to_ceiling_round_a_walk(self):
        vs = [v for o in self.static for v in _world(o)]
        self.assertAlmostEqual(min(v.z for v in vs), 0.0, delta=0.005)
        self.assertAlmostEqual(max(v.z for v in vs), 5.0, delta=0.005)
        # (Its foot within a 9.6 m square, clear of the lanes; its steps a walk's, its walk a metre and more wide.)
        foot = [v for v in vs if v.z < 2.4]
        self.assertLessEqual(max(max(abs(v.x), abs(v.y)) for v in foot), 4.8)
        for _, _, rise in self.kit.STEPS:
            self.assertLessEqual(rise, 0.3)
        self.assertGreaterEqual(self.kit.RAIL - self.kit.TALUD[0], 1.1)
        self.assertGreaterEqual(self.kit.RAIL_HIGH, 0.95)
        r0, r1, proud = self.kit.RING
        self.assertLessEqual(r1, 4.8)
        self.assertAlmostEqual(proud, 0.035, delta=0.001)

    def test_tube_rows_reach_the_ceiling(self):
        self.assertGreaterEqual(len(self.kit.BUNDLES), 4)
        for k, (x, y) in enumerate(self.kit.bundle_tops()):
            hit = self._hit((x, y, 4.8), (0, 0, 1), 0.5)
            self.assertIsNotNone(hit, k)
            self.assertAlmostEqual(hit.z, 5.0, delta=0.15, msg=k)
            self.assertGreaterEqual(len(self.kit.BUNDLES[k][1]), 3, k)
            self.assertGreaterEqual(max(r for _, r in self.kit.BUNDLES[k][1]), 0.22, k)

    def test_gauge_boards_and_clockwork(self):
        self.assertGreaterEqual(len(self.kit.GAUGES), 4)
        self.assertGreaterEqual(sum(len(c) for c in self.kit.GAUGES), 16)
        for k, cluster in enumerate(self.kit.GAUGES):
            for at, normal, r in cluster:
                hit = self._hit(Vector(at) + Vector(normal) * 0.2, -Vector(normal), 0.4)
                self.assertIsNotNone(hit, (k, at))
                self.assertLessEqual((hit - Vector(at)).length, 0.03, (k, at))
        gears = [n for n in self.objects if n.startswith("gear_")]
        self.assertGreaterEqual(len(gears), 3)
        self.assertEqual(sorted(gears), sorted(self.kit.GEARS))
        self.assertGreaterEqual(len([s for s in self.kit.gear_spots()]), 12)

    def test_flywheels_drive_pistons_inside_their_cylinders(self):
        # (Each crank turning a whole turn keeps its piston rod inside its cylinder and its crosshead between its
        # slide bars: the linkage EngineCrank plays in Godot.)
        rho, length, rod = self.kit.CRANK
        lo, hi = self.kit.CYLINDER_SPAN
        self.assertGreaterEqual(len(self.kit.CRANKS), 4)
        for k in range(72):
            t = 2 * math.pi * k / 72
            head = self.kit.crosshead_height(t)
            self.assertGreaterEqual(head + rod, lo + 0.05, k)
            self.assertLessEqual(head + rod, hi - 0.03, k)
            self.assertGreaterEqual(head - 0.07, self.kit.SLIDES[0], k)
        for name in ("flywheel", "conrod", "crosshead", "governor"):
            self.assertIn(name, self.objects)

    def test_it_takes_the_runs_and_the_trays(self):
        # (The runs' meeting point is inside the dome: every way out of it meets the engine.)
        for way in ((1, 0, 0), (-1, 0, 0), (0, 1, 0), (0, -1, 0), (0, 0, 1), (0, 0, -1)):
            self.assertIsNotNone(self._hit(self.kit.TERMINAL, way, 2.5), way)
        # (Each tray ends inside an iron box round a row.)
        for end in self.kit.TRAY_ENDS:
            up = self._hit(end, (0, 0, 1), 0.6)
            down = self._hit(end, (0, 0, -1), 0.6)
            self.assertIsNotNone(up, end)
            self.assertIsNotNone(down, end)


if __name__ == "__main__":
    # (`-- Class` or `-- Class.test_name` after Blender's own arguments runs just those.)
    chosen = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    result = unittest.main(argv=["test_kit_bpy"] + chosen, exit=False).result
    sys.exit(not result.wasSuccessful())
