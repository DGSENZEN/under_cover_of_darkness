"""The Metro Underground's plan (layouts/city_metro.py; the Metro Underground
spec, docs/superpowers/specs/2026-10-16-metro-underground-design.md).
Targets marked (Claude's call) are open to the user's review of the sheets.

    python3 tools/level/test_metro_plan.py
"""

import copy
import math
import os
import sys
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
sys.path.insert(0, os.path.join(HERE, "layouts"))

import city_metro  # noqa: E402
import greybox  # noqa: E402
import plan  # noqa: E402
import plan_check  # noqa: E402
from metro import walk  # noqa: E402

DATA = city_metro.plan()
# The Zócalo plan's crypt (x -50..10, z -250..-160) and kiosks.
ZOCALO_CRYPT = plan.rect(-50, -250, 10, -160)
KIOSKS = [(sx * 90.0, sz * 98.0) for sx in (-1, 1) for sz in (-1, 1)]


def _space(name):
    return next(s for s in DATA["spaces"] if s["name"] == name)


def _landmarks(kind):
    return [m for m in DATA["landmarks"] if m["kind"] == kind]


def _long_axis(polygon):
    xs = [p[0] for p in polygon]
    zs = [p[1] for p in polygon]
    return max(max(xs) - min(xs), max(zs) - min(zs))


class MetroPlan(unittest.TestCase):
    def test_plan_check_clean(self):
        self.assertEqual(plan_check.check(DATA, plan_check.UNDERGROUND_RULES), [])

    def test_layers_by_depth(self):
        # (Claude's call: layer 1 runs from the landings under the kiosks, -3,
        # down to the track bed, -15.2.)
        layers = {k: [s["floor"] for s in DATA["spaces"] if s.get("layer") == k] for k in (1, 2, 3)}
        self.assertEqual([s["name"] for s in DATA["spaces"] if s.get("layer") not in (1, 2, 3)], [])
        self.assertTrue(all(-16.0 <= f <= -2.0 for f in layers[1]), layers[1])
        self.assertLess(sum(layers[2]) / len(layers[2]), sum(layers[1]) / len(layers[1]))
        self.assertTrue(all(f < -16.0 for f in layers[3]), layers[3])

    def test_spine(self):
        exits = [m["name"] for m in _landmarks("exit_zocalo")]
        spine = walk.shortest(DATA, "arrival", exits)
        self.assertIsNotNone(spine)
        layer = {s["name"]: s.get("layer") for s in DATA["spaces"]}
        spaces = [v for v in spine["via"] if v in layer]
        self.assertTrue(spaces and all(layer[s] == 1 for s in spaces), spine["via"])
        self.assertLessEqual(spine["length"], 250.0, spine)

    def test_walks_in_the_data(self):
        # (maps/metro's suite walks them: the plan carries their waypoints.)
        arrival = _landmarks("arrival")[0]["at"]
        ends = {"spine": [m["at"] for m in _landmarks("exit_zocalo")],
                "market": [m["at"] for m in DATA["landmarks"] if m["name"] in city_metro.WALKS["market"]],
                "old": [m["at"] for m in DATA["landmarks"] if m["name"] in city_metro.WALKS["old"]]}

        for name, goals in ends.items():
            points = DATA["walks"][name]
            self.assertGreaterEqual(len(points), 3, name)
            self.assertLess(math.dist(points[0], arrival), 0.01, name)
            self.assertTrue(any(math.dist(points[-1], g) < 0.01 for g in goals), name)

    def test_exits_under_kiosks(self):
        exits = _landmarks("exit_zocalo")
        self.assertEqual(len(exits), 4)

        for k in KIOSKS:
            self.assertTrue(any(math.hypot(m["at"][0] - k[0], m["at"][2] - k[1]) <= 2.0 for m in exits), k)

    def test_twenty_minutes(self):
        # (Claude's call.) The plan's fixed anchors, four exits a hundred
        # metres out and the crypt 160 m north under the cathedral, already
        # cost some 1200 m of this measure, and the track and its two
        # platforms count three times over for one 100 m walk.
        total = sum(_long_axis(s["polygon"]) for s in DATA["spaces"])
        total += sum(walk._length(r["points"]) for r in DATA["routes"])
        self.assertTrue(1600.0 <= total <= 2400.0, total)

    def test_places(self):
        # (Claude's call.) Scenes, not sprinkles: no two of a kind within 15 m.
        self.assertGreaterEqual(len(_landmarks("character_place")), 8)
        scenes = _landmarks("scene")
        self.assertGreaterEqual(len(scenes), 12)

        for m in scenes:
            self.assertTrue(m["props"].get("cause"), m["name"])

        for i, a in enumerate(scenes):
            for b in scenes[i + 1:]:
                if a["props"]["scene"] == b["props"]["scene"]:
                    self.assertGreater(math.dist(a["at"], b["at"]), 15.0, (a["name"], b["name"]))

    def test_landmarks_stand_in_spaces(self):
        # Every landmark on a floor of a space it lies in.
        loose = [m["name"] for m in DATA["landmarks"]
                 if not any(plan_check.inside((m["at"][0], m["at"][2]), s["polygon"]) and abs(m["at"][1] - s["floor"]) < 0.01
                            for s in DATA["spaces"])]
        self.assertEqual(loose, [])

    def test_signs(self):
        says = {m["props"]["says"] for m in _landmarks("sign")}
        self.assertEqual(says, {"Correspondencia", "Salida", "Andén"})

    def test_climbs(self):
        # (Claude's call.) A vent shaft: a space 8 m tall or more with a
        # climb from its floor rising 8 m or more.
        climbs = [r for r in DATA["routes"] if r["kind"] == "climb"]
        self.assertGreaterEqual(len(climbs), 4)

        def shaft(s):
            return s["height"] >= 8.0 and any(
                abs(min(r["points"], key=lambda p: p[1])[1] - s["floor"]) < 0.01
                and plan_check.near((min(r["points"], key=lambda p: p[1])[0], min(r["points"], key=lambda p: p[1])[2]),
                                    s["polygon"], 0.5)
                and max(p[1] for p in r["points"]) - min(p[1] for p in r["points"]) >= 8.0 for r in climbs)

        self.assertTrue(any(shaft(s) for s in DATA["spaces"]))

    def test_old_places_kept(self):
        for name in ("crypt", "templo_shells", "pawn_vault"):
            self.assertEqual(_space(name)["layer"], 3, name)

        crypt = _space("crypt")["polygon"]
        shared = plan_check.overlap_area(crypt, ZOCALO_CRYPT)
        self.assertGreaterEqual(shared / plan.area(ZOCALO_CRYPT), 0.8)

    def test_stacked_spaces_pass_the_gate(self):
        box = greybox.build(DATA)
        self.assertEqual(greybox.gate(box), [])
        self.assertFalse(any(m["kind"] in ("ground", "brink") for m in box["meshes"]))

    def test_overlapping_spaces_fail(self):
        # The herb market moved up into the hall's volume.
        moved = copy.deepcopy(DATA)
        herbs = next(s for s in moved["spaces"] if s["name"] == "herb_market")
        herbs["polygon"] = [[x, z - 60.0] for x, z in herbs["polygon"]]
        herbs["floor"] = -7.0
        problems = greybox.gate(greybox.build(moved))
        self.assertTrue(any(p.startswith("volume: hall and herb_market") for p in problems), problems)


if __name__ == "__main__":
    unittest.main()
