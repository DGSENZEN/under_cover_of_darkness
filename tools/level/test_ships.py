"""The harbour's ships (kit_ships) against what the harbour's layout, its
level check and its in-game tests ask of them, and against the reference
(docs/superpowers/refs/ships_harbour.md): pure Python, no Blender.

    cd tools/level && python3 -m unittest test_ships
"""

import functools
import math
import os
import sys
import unittest

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import geo  # noqa: E402
import kit_recipes  # noqa: E402
import kit_shapes  # noqa: E402
import kit_ships  # noqa: E402

PIECES = kit_recipes.PIECES
BUDGETS = {"carrack_hull": 9200, "carrack_rig": 7000, "carrack_mainyard": 600, "caravel": 4500, "boat_fishing": 900, "rowboat": 350}
# The quay's edge is at world z 0, the carrack's middle at 4.8: nothing of
# hers low down may reach past 0.15 (local -4.65).
QUAY_SIDE = -4.65
# Where the level lays her brow along her (local x), clear of the jump aboard
# at x 0.
BROW_X = kit_ships.BROW_X
# The player's capsule (Player.tscn): its radius, its height.
RADIUS, TALL = 0.5, 1.8


def tris(name):
    return sum(len(points) - 2 for points, _ in faces(name))


@functools.lru_cache(maxsize=None)
def boxes(name):
    return geo.piece_boxes(PIECES[name], [0.0, 0.0, 0.0], geo.IDENTITY)


@functools.lru_cache(maxsize=None)
def faces(name):
    part = kit_shapes.build(PIECES[name]["shapes"])
    return [([part["verts"][i] for i in f[0]], f[1]) for f in part["faces"]]


def top_of(c):
    return c[1] + c[4] / 2.0


def floor_under(name, point, reach=0.3):
    """The height of the first collider straight under `point` (from 0.05
    over it), or None within `reach`."""
    start = [point[0], point[1] + 0.05, point[2]]
    hits = [b.ray(start, [0.0, -1.0, 0.0]) for b in boxes(name)]
    hits = [t for t in hits if t is not None and t <= reach + 0.05]
    return start[1] - min(hits) if hits else None


def solid(name, point, margin=0.0):
    return any(b.contains(point, margin) for b in boxes(name))


def clear(name, low, high, step=0.1):
    """Whether no collider of `name` has a point in the box low..high
    (sampled every `step`)."""
    reach = [(low[i] + high[i]) / 2.0 for i in range(3)]
    size = math.dist(low, high) / 2.0
    near = [b for b in boxes(name) if math.dist(b.centre, reach) <= size + math.hypot(*b.half) + 0.01]
    counts = [max(1, int(math.ceil((high[i] - low[i]) / step))) for i in range(3)]

    for i in range(counts[0] + 1):
        for j in range(counts[1] + 1):
            for k in range(counts[2] + 1):
                p = [low[0] + (high[0] - low[0]) * i / counts[0], low[1] + (high[1] - low[1]) * j / counts[1],
                     low[2] + (high[2] - low[2]) * k / counts[2]]

                if any(b.contains(p) for b in near):
                    return False

    return True


class Budgets(unittest.TestCase):
    def test_each_ship_keeps_its_budget(self):
        for name, budget in BUDGETS.items():
            self.assertEqual(PIECES[name]["budget"], budget, name)
            self.assertLessEqual(tris(name), budget, name)

    def test_they_are_not_paper(self):
        # (The user: "they feel like made out of paper".) The carrack is
        # drawn with most of what she may, her rig a forest of lines and
        # ratlines between them, her boats at least half their budgets.
        self.assertGreaterEqual(tris("carrack_hull"), 7000)
        self.assertGreaterEqual(tris("carrack_rig"), 4500)
        ratlines = [s for s in PIECES["carrack_rig"]["shapes"] if s["kind"] == "polygon" and s["slot"] == "ratlines"]
        self.assertGreaterEqual(len(ratlines), 2 * (8 + 5 + 3))

        for name in ("caravel", "boat_fishing", "rowboat"):
            self.assertGreaterEqual(tris(name), BUDGETS[name] // 2, name)

    def test_ratlines_are_laid_on_their_painting(self):
        # Each strip between two shrouds shows the painting's ratlines between
        # two of its own shrouds (none of its shrouds on it), repeating up.
        for name in ("carrack_rig", "caravel"):
            for s in PIECES[name]["shapes"]:
                if s["kind"] == "polygon" and s["slot"] == "ratlines":
                    us = [uv[0] for uv in s["uvs"]]
                    self.assertTrue(0.52 <= min(us) and max(us) <= 0.585, us)
                    self.assertGreater(max(uv[1] for uv in s["uvs"]), 1.0)


class Carrack(unittest.TestCase):
    def test_she_keeps_off_the_quay(self):
        # Nothing of her hull, and nothing of her rig below 9 m, reaches past
        # the quay's edge; her beam over her wales is under 9.3 m (only her
        # open gunports' lids, to seaward, swing out past it).
        for name in ("carrack_hull", "carrack_rig"):
            for points, _ in faces(name):
                for p in points:
                    if name == "carrack_hull" or p[1] < 9.0:
                        self.assertGreaterEqual(p[2], QUAY_SIDE, "%s: %s" % (name, [round(c, 2) for c in p]))

        widest = max(kit_ships._half(x / 2.0, y / 10.0) for x in range(-30, 31) for y in range(-35, 90))
        self.assertLessEqual(2.0 * (widest + 0.13), 9.3)

    def test_her_sides_fall_in(self):
        # Round and full below, widest about the waterline, falling in above
        # it (tumblehome): amidships her rail is well inside her greatest
        # breadth, her castles' tops inside it again.
        widest = max(kit_ships._half(0.0, y / 10.0) for y in range(-35, 31))
        self.assertAlmostEqual(widest, kit_ships._half(0.0, kit_ships.YMAX), places=3)
        self.assertLess(kit_ships._half(0.0, 3.0), widest - 0.15)
        self.assertLess(kit_ships._half(-13.0, 8.0), kit_ships._half(-13.0, 3.0) - 0.4)
        self.assertGreater(kit_ships._half(0.0, -2.0), 0.8 * widest)

    def test_her_forecastle_overhangs_the_stem(self):
        hull = [p for points, _ in faces("carrack_hull") for p in points]
        stem_head = kit_ships._stem_x(kit_ships.FORE_SOLID)
        self.assertGreater(max(p[0] for p in hull if p[1] > kit_ships.FORE_SOLID), stem_head + 1.0)

    def test_the_waist_is_walked(self):
        # Her deck at 2.0 under the deck watch's lane (local z -1..-2 from x
        # -4.5 to 6.5), nothing in the lane below 2.2 m over the deck.
        for x in (-4.5, -2.0, 0.0, 2.5, 5.0, 6.5):
            for z in (-1.0, -1.5, -2.0):
                self.assertAlmostEqual(floor_under("carrack_hull", [x, 2.0, z]), 2.0, places=3)

        self.assertTrue(clear("carrack_hull", [-4.5, 2.05, -2.0], [6.5, 4.2, -1.0]))

    def test_she_is_boarded_from_the_quay(self):
        # From the quay (world 40, 2.5, -3) a jump lands on her deck at (40,
        # 2.0, 2.6): her rail there no higher than 3.05, her deck under the
        # landing, nothing over it.
        self.assertAlmostEqual(floor_under("carrack_hull", [0.0, 2.0, -2.2]), 2.0, places=3)
        rail = [b for b in boxes("carrack_hull") if b.contains([0.0, 2.5, -4.1])]
        self.assertTrue(rail)
        self.assertTrue(all(b.centre[1] + b.half[1] <= 3.05 for b in rail))
        self.assertTrue(clear("carrack_hull", [-0.5, 2.05, -3.6], [0.5, 4.0, -1.6]))

    def test_a_brow_joins_her_deck_to_the_quay(self):
        # Her brow (a gangplank: the level lays it at her waist from the
        # quay's edge, world z 0): one walk from the quay's top (2.5) up over
        # her rail and down onto her deck (2.0), no step on it over 0.3 m and
        # no slope over 35 degrees, clear of the rail under it; or her deck is
        # an island no way reaches and the deck watch is off the navmesh
        # (city_test C3: her castles' rails stop a guard's drop to the quay).
        brow = kit_recipes.PIECES["carrack_brow"]
        tops = []

        for z in [-1.15 + 0.1 * i for i in range(41)]:
            y = floor_under("carrack_brow", [0.0, 4.5, z], reach=3.0)
            self.assertIsNotNone(y, z)
            tops.append((z, y))

        self.assertAlmostEqual(tops[0][1], 2.5, delta=0.1)
        self.assertAlmostEqual(tops[-1][1], 2.0, delta=0.1)

        for (za, ya), (zb, yb) in zip(tops, tops[1:]):
            self.assertLess(abs(yb - ya), 0.3)
            self.assertLess(math.degrees(math.atan2(abs(yb - ya), zb - za)), 35.0, (za, zb))

        rail = max(b.centre[1] + b.half[1] for b in boxes("carrack_hull") if b.contains([BROW_X, 2.5, -4.1]))
        over = [y for z, y in tops if 0.4 < z < 0.85]
        self.assertTrue(over and min(over) > rail + 0.1, (over, rail))
        self.assertEqual(brow["family"], "ship")

    def test_the_cabin(self):
        # Its door in the forward bulkhead at -6 (the level hangs a door in
        # it): the opening 1.2 x 2.2 clear of colliders and of any face; the
        # cabin within: its floor at 2.0, headroom over 2.2, the strongbox's
        # place clear, the table under the candles at 2.85, its deckhead the
        # aftcastle's deck at 5.0.
        self.assertEqual(PIECES["carrack_hull"]["door"], [1.2, 2.2])
        self.assertTrue(clear("carrack_hull", [-6.3, 2.05, -0.55], [-5.7, 4.15, 0.55]))

        for points, slot in faces("carrack_hull"):
            if all(-6.15 < p[0] < -5.85 for p in points):
                middle = [sum(p[i] for p in points) / len(points) for i in range(3)]
                self.assertFalse(abs(middle[2]) < 0.55 and 2.05 < middle[1] < 4.15, (slot, middle))

        for x in (-14.5, -12.0, -9.0, -6.6):
            self.assertAlmostEqual(floor_under("carrack_hull", [x, 2.0, 1.5]), 2.0, places=3)

        self.assertTrue(clear("carrack_hull", [-14.4, 2.05, 0.6], [-6.4, 4.25, 2.9]))
        self.assertTrue(clear("carrack_hull", [-13.45, 2.05, 1.75], [-12.55, 2.9, 2.65]))
        table = floor_under("carrack_hull", [-12.0, 2.85, 0.0], 0.1)
        self.assertIsNotNone(table)
        self.assertAlmostEqual(table, 2.82, delta=0.04)
        self.assertAlmostEqual(floor_under("carrack_hull", [-10.0, 5.0, 0.0]), 5.0, places=3)

    def test_the_castles_decks_and_ladders(self):
        # The aftcastle's deck at 5.0 and the forecastle's at 6.5 reached by
        # ladders from the waist, the poop's at 8.0 (the spyglass's floor)
        # by one from the aftcastle's; a gap in the rail at each ladder's head.
        self.assertAlmostEqual(floor_under("carrack_hull", [-13.0, 8.1, 0.0]), 8.0, places=3)
        self.assertAlmostEqual(floor_under("carrack_hull", [-8.0, 5.0, 0.0]), 5.0, places=3)
        self.assertAlmostEqual(floor_under("carrack_hull", [12.0, 6.5, 0.0]), 6.5, places=3)
        climbs = PIECES["carrack_hull"]["climbs"]

        for deck in (kit_ships.CASTLE_DECK, kit_ships.FORE_DECK, kit_ships.POOP_DECK):
            reaching = [c for c in climbs if abs(c[1] + c[4] / 2.0 - deck - 0.3) < 0.05]
            self.assertTrue(reaching, deck)

            for x, y, z, sx, sy, sz, yaw in reaching:
                ahead = [math.sin(math.radians(yaw)), 0.0, math.cos(math.radians(yaw))]
                # (Over the ladder's head and on, a man's width, into the castle.)
                for t in (0.4, 0.8, 1.2):
                    for dz in (-0.35, 0.0, 0.35):
                        p = [x - ahead[0] * t + ahead[2] * dz, deck + 0.6, z - ahead[2] * t + ahead[0] * dz]
                        self.assertFalse(solid("carrack_hull", p), (deck, p))

    def test_the_stern_lantern_hangs_clear(self):
        # The level's lantern hangs from (-15.8, 10.2, 0) on a 0.4 m chain:
        # iron is drawn to that hook, nothing is where the lantern hangs.
        hull = faces("carrack_hull")
        iron = [p for points, slot in hull if slot == "iron" for p in points]
        self.assertLess(min(math.dist(p, [-15.8, 10.25, 0.0]) for p in iron), 0.15)

        for points, slot in hull:
            for p in points:
                self.assertFalse(-16.05 < p[0] < -15.55 and 9.3 < p[1] < 10.15 and abs(p[2]) < 0.25, (slot, p))


class Rig(unittest.TestCase):
    def test_the_main_top_is_a_tub_open_over_its_shrouds(self):
        # Its floor at 20 (3 m across), its sides fore and aft solid; nothing
        # over its floor's north and south edges where the climbers mantle in
        # and the yard is walked onto (C6, tests/city_test.gd).
        cols = PIECES["carrack_rig"]["cols"]
        floor = [c for c in cols if abs(top_of(c) - kit_ships.TOP) < 1e-3]
        self.assertEqual(len(floor), 1)
        sides = [c for c in cols if c[1] - c[4] / 2.0 >= kit_ships.TOP - 1e-3 and c[4] >= 0.8 and math.hypot(c[0], c[2]) > 1.3]
        self.assertTrue(any(c[0] > 1.3 for c in sides) and any(c[0] < -1.3 for c in sides))

        for s in (1.0, -1.0):
            self.assertTrue(clear("carrack_rig", [-1.1, kit_ships.TOP + 0.05, s * 2.4 if s < 0 else 0.8],
                                  [1.1, kit_ships.TOP + TALL, -0.8 if s < 0 else 2.4]))

    def test_the_shroud_climbs_keep_their_place(self):
        # C6 finds the climb through (40, 11, 3.0) and climbs it 0.9 m west of
        # its middle; each main climb no wider than the gap in the top's
        # sides (a climber, 0.5 m round, passes their ends).
        climbs = [c for c in PIECES["carrack_rig"]["climbs"] if abs(c[0]) < 0.1]
        self.assertEqual(len(climbs), 2)
        x, y, z, sx, sy, sz, yaw = min(climbs, key=lambda c: c[2])
        self.assertTrue(abs(0.0 - x) <= sx / 2.0 and abs(11.0 - y) <= sy / 2.0 and abs(-1.8 - z) <= sz / 2.0)
        self.assertGreaterEqual(sx / 2.0, 0.9)
        ends = [c for c in PIECES["carrack_rig"]["cols"] if c[1] - c[4] / 2.0 >= kit_ships.TOP - 1e-3 and c[4] >= 0.8]

        for c in climbs:
            for e in ends:
                for dx in (-1, 1):
                    corner = [e[0] + dx * e[3] / 2.0 * math.cos(math.radians(e[7])), e[2] - dx * e[3] / 2.0 * math.sin(math.radians(e[7]))]
                    climber = [max(-c[3] / 2.0, min(c[3] / 2.0, corner[0])), math.copysign(kit_ships.TOP_RADIUS - 0.5, c[2])]
                    self.assertGreater(math.dist(corner, climber), RADIUS - 0.02, (c, e))

    def test_the_yard_is_reached_and_walked(self):
        # The main yard hangs 2 m under the top (its collider's top 18.25
        # world), 26 m along z, its north arm over the sea wall's walk; its
        # visual top is the beam walked; nothing hangs over its north arm.
        yard = PIECES["carrack_mainyard"]
        self.assertEqual(yard["cols"], [[0.0, 0.2, 0.0, kit_ships.YARD, 0.1, 0.45, "wood", 0.0, 0.0, 0.0]])
        spar = [p for points, slot in faces("carrack_mainyard") if slot == "hull_bare" for p in points if abs(p[0]) < 12.5]
        self.assertAlmostEqual(max(p[1] for p in spar), 0.25, delta=0.02)
        self.assertTrue(all(p[1] < 0.33 for points, _ in faces("carrack_mainyard") for p in points if abs(p[0]) > 0.5))
        # (The rig's lines over the yard's north arm: none lower than a man
        # walking it. The yard is at world 18, its north arm local -z.)
        for points, slot in faces("carrack_rig"):
            for p in points:
                if abs(p[0]) < 0.8 and -12.6 < p[2] < -1.7:
                    self.assertFalse(18.2 < p[1] < 18.25 + TALL + 0.2, (slot, p))

    def test_the_fore_top_is_climbed_to(self):
        for c in PIECES["carrack_rig"]["climbs"]:
            if abs(c[0] - 10.0) < 0.1:
                self.assertLessEqual(c[1] - c[4] / 2.0, kit_ships.FORE_DECK + 0.05)
                self.assertAlmostEqual(floor_under("carrack_rig", [10.0, 16.0, 0.8]), 16.0, places=3)


class Caravel(unittest.TestCase):
    def test_her_decks_and_loot(self):
        # The astrolabe (local 0, 1.6, 0) and the flask (-2, 1.6, 0) fall on
        # her deck at 1.5; the tolda's deck at 3.5; the iron her lantern
        # hangs from at (-9.5, 5.0, 0).
        for point in ([0.0, 1.6, 0.0], [-2.0, 1.6, 0.0]):
            self.assertAlmostEqual(floor_under("caravel", point, 0.2), 1.5, places=3)
            self.assertFalse(solid("caravel", point))

        self.assertAlmostEqual(floor_under("caravel", [-8.0, 3.5, 0.0]), 3.5, places=3)
        iron = [p for points, slot in faces("caravel") if slot == "iron" for p in points]
        self.assertLess(min(math.dist(p, [-9.5, 5.1, 0.0]) for p in iron), 0.15)

    def test_her_lookout_is_climbed_to(self):
        # Up her shrouds on the quay's side to the basket: the climber comes
        # up clear of its floor overhead and within reach of its edge.
        climbs = PIECES["caravel"]["climbs"]
        self.assertEqual(len(climbs), 1)
        x, y, z, sx, sy, sz, yaw = climbs[0]
        floors = [c for c in PIECES["caravel"]["cols"] if c[4] <= 0.15 and abs(top_of(c) - kit_ships.CV_NEST) < 1e-3]
        self.assertEqual(len(floors), 1)
        hangs = abs(z) + 0.38
        self.assertGreaterEqual(hangs - 0.3, floors[0][5] / 2.0 + 0.05)
        self.assertLessEqual(hangs - floors[0][5] / 2.0, 1.0)
        self.assertLessEqual(y - sy / 2.0, kit_ships.CV_DECK + 0.05)

    def test_her_yards_are_longer_than_she_is(self):
        hull = [p for points, slot in faces("caravel") for p in points if p[1] < 3.0]
        length = max(p[0] for p in hull) - min(p[0] for p in hull)
        spars = [s for s in PIECES["caravel"]["shapes"] if s["kind"] == "polygon" and s["slot"] == "hull_bare"]
        points = [p for s in spars for p in s["points"] if p[1] > 4.0]
        self.assertGreater(max(math.dist(a, b) for a in points for b in points if abs(a[1] - b[1]) > 10.0), length)


class Boats(unittest.TestCase):
    def test_the_rowboat_keeps_the_water_tests_colliders(self):
        # tests/water_geometry_test.gd builds these very boxes.
        self.assertEqual(PIECES["rowboat"]["cols"], [kit_ships.col(0.0, -0.17, 0.0, 3.2, 0.1, 1.0), kit_ships.col(0.0, 0.2, 0.68, 3.6, 0.8, 0.1),
                                                     kit_ships.col(0.0, 0.2, -0.68, 3.6, 0.8, 0.1)])

    def test_the_boats_are_stood_in_where_their_floors_are_drawn(self):
        for name, floor in (("rowboat", -0.12), ("boat_fishing", -0.42)):
            boards = [p for points, slot in faces(name) if slot == "boards" for p in points if abs(p[1] - floor) < 0.005]
            self.assertTrue(boards, name)
            self.assertAlmostEqual(floor_under(name, [0.0, floor, 0.0]), floor, places=3)

    def test_their_pivots_are_at_the_waterline(self):
        for name in ("boat_fishing", "rowboat", "caravel", "carrack_hull"):
            ys = [p[1] for points, _ in faces(name) for p in points]
            self.assertLess(min(ys), -0.1, name)
            self.assertGreater(max(ys), 0.5, name)

    def test_they_are_clinker_built_with_a_crescent_sheer(self):
        # Their gunwales rise to stem and stern; their strakes lap (a face
        # under each lap looks down).
        for name, band in (("boat_fishing", "cloth"), ("rowboat", "render_blue")):
            built = faces(name)
            top = [p for points, slot in built if slot == band for p in points]
            middle = max(p[1] for p in top if abs(p[0]) < 0.5)
            self.assertGreater(max(p[1] for p in top), middle + 0.3, name)
            laps = [points for points, slot in built if kit_shapes._normal(points)[1] < -0.5 * math.hypot(*kit_shapes._normal(points))
                    and min(p[1] for p in points) > -0.3 and slot not in ("timber", "boards")]
            self.assertGreaterEqual(len(laps), 8, name)


if __name__ == "__main__":
    unittest.main(verbosity=1)
