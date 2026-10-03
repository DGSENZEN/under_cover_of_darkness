"""The old town's key buildings (plan B1a, Tasks 9-12): each entered by its
ways of different kinds, every way walked by the rules from outside to
inside; what each keeps (seats, beds, places).

    python3 tools/level/test_keys.py
"""

import os
import sys
import unittest

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import kit_recipes  # noqa: E402
import kit_town_chapel  # noqa: E402,F401
import kit_merchant  # noqa: E402,F401
import kit_tavern  # noqa: E402
import kit_watch  # noqa: E402
import rules  # noqa: E402
from test_kits import tris  # noqa: E402
from test_rules import marker, piece  # noqa: E402

PIECES = kit_recipes.PIECES
SUPPORTS = []


def _floor(name, x0, z0, x1, z1, y):
    kit_recipes.piece(name, "floor", "cobble", "stone", [kit_recipes.box((x0 + x1) / 2.0, y - 0.1, (z0 + z1) / 2.0, x1 - x0, 0.2, z1 - z0,
                                                                         "cobble")])
    SUPPORTS.append(name)
    return piece(name, name, (0, 0, 0))


def way_problems(name):
    """Every way into the key building `name`, placed alone at the origin
    with a lane round its footprint (and a platform under a way's start
    off the ground: a neighbour's roof, the stream's tunnel), walked by
    the rules: {kind: problems}."""
    recipe = PIECES[name]
    x0, z0, x1, z1 = recipe["footprint"]
    lane = 3.0
    pieces = [piece("it", name, (0, 0, 0)), _floor("lane_front", x0 - lane, z1, x1 + lane, z1 + lane, 0.0),
              _floor("lane_back", x0 - lane, z0 - lane, x1 + lane, z0, 0.0), _floor("lane_left", x0 - lane, z0, x0, z1, 0.0),
              _floor("lane_right", x1, z0, x1 + lane, z1, 0.0)]
    out = {}

    for i, way in enumerate(recipe["ways"]):
        start = way["points"][0]
        extra = [] if abs(start[1]) < 0.01 else [_floor("support_%d" % i, start[0] - 1.5, start[2] - 1.5, start[0] + 1.5, start[2] + 1.5, start[1])]
        route = "way_%d" % i
        points = [marker("%s_%d" % (route, j + 1), "route_check", p[:3], {"route": route, "order": j + 1, "move": p[3]})
                  for j, p in enumerate(way["points"])]
        ladders = [dict(marker("climb_%d" % j, "ladder", c[0:3], size=list(c[3:6])), basis=_basis(c[6])) for j, c in enumerate(recipe.get("climbs", []))]
        problems = rules.problems({"level": "fixture", "pieces": pieces + extra, "markers": points + ladders})
        out.setdefault(way["kind"], []).extend(problems)

    return out


def blocked(name):
    """The steps of the building's ways walked, climbed or dropped through
    something (the rules look for floors, not walls): a ray a metre over
    each walk, stairs or drop between its points meets none of its
    colliders. [(kind, from, to)]."""
    import geo
    recipe = PIECES[name]
    boxes = geo.piece_boxes(recipe, [0.0, 0.0, 0.0], geo.IDENTITY)
    out = []

    ladders = [geo.Box(c[0:3], geo.rotation(c[6]), c[3:6]) for c in recipe.get("climbs", [])]

    for way in recipe["ways"]:
        for a, b in zip(way["points"], way["points"][1:]):
            if b[3] == "climb":
                # (Up its ladder's middle from the lower end to the upper:
                # nothing across it, a floor or a roof without its hole.)
                middle = [(a[i] + b[i]) / 2.0 for i in range(3)]
                ladder = [box for box in ladders if box.contains(middle)]
                low, high = min(a[1], b[1]) + 0.3, max(a[1], b[1]) - 0.05

                if ladder and high > low:
                    start = [ladder[0].centre[0], low, ladder[0].centre[2]]

                    if any(t is not None and t < high - low for t in (box.ray(start, [0.0, 1.0, 0.0]) for box in boxes)):
                        out.append((way["kind"], a[:3], b[:3]))

                continue

            if b[3] not in ("walk", "stairs", "drop"):
                continue

            start, end = [a[0], a[1] + 1.0, a[2]], [b[0], b[1] + 1.0, b[2]]
            d = [end[i] - start[i] for i in range(3)]
            length = sum(c * c for c in d) ** 0.5

            if length < 1e-6:
                continue

            unit = [c / length for c in d]

            if any(t is not None and t < length - 0.01 for t in (box.ray(start, unit) for box in boxes)):
                out.append((way["kind"], a[:3], b[:3]))

    return out


def _basis(yaw):
    import geo
    return geo.rotation(yaw)


class Keys(unittest.TestCase):
    def tearDown(self):
        for name in SUPPORTS:
            PIECES.pop(name, None)

        SUPPORTS.clear()


class Tavern(Keys):
    def test_the_tavern_has_four_ways_of_four_kinds(self):
        self.assertEqual(sorted(w["kind"] for w in PIECES["tavern"]["ways"]), ["below", "door", "window", "yard"])

    def test_every_way_into_the_tavern_checks(self):
        for kind, problems in way_problems("tavern").items():
            self.assertEqual(problems, [], kind)

        self.assertEqual(blocked("tavern"), [])

    def test_the_tavern_seats_its_drinkers_and_keeps_its_places(self):
        recipe = PIECES["tavern"]
        self.assertEqual(len(recipe["seats"]), 12)
        self.assertTrue({"watchman_table", "undercroft_door", "bar"} <= set(recipe["places"]))
        self.assertLessEqual(tris(recipe), recipe["budget"])


class WatchHouse(Keys):
    def test_the_watch_house_has_three_ways(self):
        self.assertEqual(sorted(w["kind"] for w in PIECES["watch_house"]["ways"]), ["door", "roof", "wall"])

    def test_every_way_into_the_watch_house_checks(self):
        for kind, problems in way_problems("watch_house").items():
            self.assertEqual(problems, [], kind)

        self.assertEqual(blocked("watch_house"), [])

    def test_the_barracks_sleeps_four(self):
        recipe = PIECES["watch_house"]
        beds = recipe["beds"]
        self.assertEqual(len(beds), 4)
        self.assertTrue(all(abs(b[1] - kit_watch.GROUND) < 0.01 for b in beds), beds)
        self.assertTrue({"drum", "office", "armoury", "lookout"} <= set(recipe["places"]))
        self.assertLessEqual(tris(recipe), recipe["budget"])


class Merchant(Keys):
    def test_the_merchant_has_five_ways_of_three_kinds(self):
        ways = PIECES["merchant_house"]["ways"]
        self.assertEqual(len(ways), 5)
        self.assertEqual(sorted({w["kind"] for w in ways}), ["door", "roof", "yard"])

    def test_every_way_into_the_merchants_checks(self):
        for kind, problems in way_problems("merchant_house").items():
            self.assertEqual(problems, [], kind)

        self.assertEqual(blocked("merchant_house"), [])

    def test_the_merchant_keeps_his_places(self):
        recipe = PIECES["merchant_house"]
        self.assertTrue({"strongbox", "ledger_chest", "key_place"} <= set(recipe["places"]))
        # (His key at the top of the house, his strongbox at its foot.)
        self.assertGreater(recipe["places"]["key_place"][1], recipe["places"]["strongbox"][1] + 6.0)
        self.assertLessEqual(tris(recipe), recipe["budget"])


class Chapel(Keys):
    def test_the_chapel_has_three_kinds(self):
        self.assertEqual(sorted(w["kind"] for w in PIECES["town_chapel"]["ways"]), ["door", "roof", "window"])

    def test_every_way_into_the_chapel_checks(self):
        for kind, problems in way_problems("town_chapel").items():
            self.assertEqual(problems, [], kind)

        self.assertEqual(blocked("town_chapel"), [])

    def test_the_chapel_keeps_its_walled_altar(self):
        recipe = PIECES["town_chapel"]
        self.assertIn("walled_altar", recipe["places"])
        self.assertLessEqual(tris(recipe), recipe["budget"])


if __name__ == "__main__":
    unittest.main()
