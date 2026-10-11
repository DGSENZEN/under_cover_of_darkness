"""The Zócalo's scenes (dress_scenes.py, the scenes plan's Task 5) laid over
the rules' dressing, from the real plan and the kits' faces
(tools/eclipse/lab.sh all first).

    python3 tools/level/test_dress_scenes.py
"""

import math
import os
import sys
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
sys.path.insert(0, os.path.join(HERE, "layouts"))

import city_zocalo  # noqa: E402
import dress  # noqa: E402
import greybox  # noqa: E402

DATA = city_zocalo.plan()
FACES = dress.load_faces()
BUILT = all(k in FACES for k in dress.KITS)
DRESSING = dress.dress(DATA, FACES) if BUILT else None

if BUILT:
    import dress_scenes  # noqa: E402
    import scenes_catalogue  # noqa: E402


def _xz(p):
    return (p["at"][0], p["at"][2])


def _apart(a, b):
    return math.hypot(a[0] - b[0], a[1] - b[1])


def _opposite(a, b):
    return {a, b} == {"day", "night"}


@unittest.skipUnless(BUILT, "the kits are not built (tools/eclipse/lab.sh all)")
class Scenes(unittest.TestCase):
    def test_every_recipe_placed(self):
        placed = [s["name"] for s in DRESSING["scenes"]]
        missing = [r.name for r in scenes_catalogue.RECIPES if r.name not in placed]
        self.assertEqual(missing, [])

        for r in scenes_catalogue.RECIPES:
            if r.landmark:
                self.assertEqual(placed.count(r.name), 1, r.name)

    def test_sites_accept(self):
        by_name = {r.name: r for r in scenes_catalogue.RECIPES}
        wrong = [(s["name"], s["site"]) for s in DRESSING["scenes"]
                 if s["site"] not in by_name[s["name"]].sites or not s["reason"]]
        self.assertEqual(wrong[:10], [])

    def test_spacing(self):
        by_name = {r.name: r for r in scenes_catalogue.RECIPES}
        scenes = DRESSING["scenes"]
        close = []

        for i, a in enumerate(scenes):
            for b in scenes[i + 1:]:
                d = _apart(_xz(a), _xz(b))
                same_site = d < 0.01 and (by_name[a["name"]].variant_of == b["name"]
                                          or by_name[b["name"]].variant_of == a["name"])

                if same_site:
                    continue

                if a["name"] == b["name"] and d < by_name[a["name"]].spacing:
                    close.append((a["name"], round(d, 1)))
                elif a["zone"] not in ("plaza", "hall") and b["zone"] not in ("plaza", "hall") and d < dress_scenes.APART:
                    close.append((a["name"], b["name"], round(d, 1)))

        self.assertEqual(close[:10], [])

    def test_zone_counts(self):
        zones = {}

        for s in DRESSING["scenes"]:
            zones[s["zone"]] = zones.get(s["zone"], 0) + 1

        self.assertGreaterEqual(zones.get("plaza", 0), 20, zones)
        self.assertGreaterEqual(zones.get("hall", 0), 8, zones)
        self.assertGreaterEqual(zones.get("madero", 0), 10, zones)
        self.assertGreaterEqual(zones.get("side", 0), 15, zones)
        self.assertEqual(zones.get("lane_end", 0), 0, zones)
        self.assertTrue(120 <= len(DRESSING["scenes"]) <= 160, len(DRESSING["scenes"]))

    def test_whole_or_nothing(self):
        by_name = {r.name: r for r in scenes_catalogue.RECIPES}
        parts = {}

        for p in DRESSING["pieces"]:
            if "scene" in p and p["kit"] != "figures_kit":
                parts.setdefault(p["scene"], [0, 0])[0] += 1

        for st in DRESSING["stations"]:
            parts.setdefault(st["scene"], [0, 0])[1] += 1

        short = []

        for k, s in enumerate(DRESSING["scenes"]):
            r = by_name[s["name"]]
            got = parts.get(k, [0, 0])

            if got != [len(r.pieces) + len(r.holds), len(r.figures)]:
                short.append((s["name"], got, [len(r.pieces) + len(r.holds), len(r.figures)]))

        self.assertEqual(short[:10], [])

    def test_stations(self):
        poses = set(FACES["figures_kit"]["objects"])
        figures = [p for p in DRESSING["pieces"] if p["kit"] == "figures_kit"]
        self.assertEqual(len(DRESSING["stations"]), len(figures))
        bad = [st for st in DRESSING["stations"] if st["pose"] not in poses
               or st["when"] != DRESSING["scenes"][st["scene"]]["when"]]
        self.assertEqual(bad[:5], [])

    def test_budgets(self):
        figures = len(DRESSING["stations"])
        trees = len([p for p in DRESSING["pieces"] if p["piece"] in dress_scenes.TREES])
        self.assertTrue(600 <= figures <= 900, figures)
        self.assertTrue(120 <= trees <= 180, trees)
        self.assertLessEqual(len(DRESSING["emitters"]), 220)

    def test_day_night_overlap_only(self):
        """Parts that overlap are a day part and a night part, never seen together."""
        import dress_life
        mine = [p for p in DRESSING["pieces"] if "scene" in p and p["piece"] not in dress_life.HUNG]
        clashes = []
        cells = {}

        for k, p in enumerate(mine):
            f = dress_life.foot(p, FACES)

            for i in range(math.floor(f[0] / 10), math.floor(f[2] / 10) + 1):
                for j in range(math.floor(f[1] / 10), math.floor(f[3] / 10) + 1):
                    for m in cells.get((i, j), []):
                        q = mine[m]
                        g = dress_life.foot(q, FACES)

                        if p["scene"] != q["scene"] and f[0] + 0.02 < g[2] and g[0] + 0.02 < f[2] \
                                and f[1] + 0.02 < g[3] and g[1] + 0.02 < f[3] \
                                and not _opposite(p.get("when", ""), q.get("when", "")):
                            clashes.append((p["piece"], q["piece"], round(p["at"][0], 1), round(p["at"][2], 1)))

                    cells.setdefault((i, j), []).append(k)

        self.assertEqual(clashes[:10], [])

    def test_routes_clear(self):
        """No scene's collider within 0.6 m of a street-level route's foot, a
        door's front, a kerb drop, the causeway (the plaza's processional
        way, 6 m either side), or a market lane's walkway (1.5 m either side
        of its middle)."""
        walks = [s for s in dress_scenes.keep_clear(DATA, DRESSING) if s["what"].startswith("the walkway")]
        self.assertGreaterEqual(len(walks), 6)
        blocked = []

        for c in DRESSING["colliders"]:
            if "scene" not in c:
                continue

            x, _, z, sx, _, sz = c["box"]
            reach = math.hypot(sx, sz) / 2   # (clearance() keeps the 0.6 m)

            for spot in dress_scenes.keep_clear(DATA, DRESSING):
                if dress_scenes.clearance(spot, x, z) < reach:
                    blocked.append((round(x, 1), round(z, 1), spot["what"]))
                    break

        self.assertEqual(blocked[:10], [])

    def test_god_ring_walkable(self):
        near = [c["box"] for c in DRESSING["colliders"] if "scene" in c
                and 6.4 - math.hypot(c["box"][3], c["box"][5]) / 2 < math.hypot(c["box"][0], c["box"][2])
                < 7.6 + math.hypot(c["box"][3], c["box"][5]) / 2]
        self.assertEqual(near[:5], [])

    def test_emitters_know_their_ground(self):
        """Every scene's emitter says how high it stands over its ground
        (the coals' embers fell to a floor 0.9 m under the setts)."""
        lost = [e["effect"] for e in DRESSING["emitters"] if e.get("scene") is not None and not 0.0 <= e.get("ground", -1.0) <= 3.0]
        self.assertEqual(lost, [])

    def test_candle_flames_on_their_wicks(self):
        """Every candles emitter carries its flames' places, each the top of a
        candle of its scene (they floated a hand or two over the drift)."""
        import json
        import mesh_cross
        wicks = {}

        for path in mesh_cross.SOURCE.glob("*_wicks.json"):
            wicks.update(json.loads(path.read_text()))

        candles = [e for e in DRESSING["emitters"] if e["effect"] == "candles"]
        self.assertTrue(candles)
        astray = []

        for e in candles:
            tops = []

            for p in DRESSING["pieces"]:
                if p.get("scene") == e.get("scene") and p["piece"] in wicks:
                    a = math.radians(p["yaw"])
                    tops += [(x * math.cos(a) + z * math.sin(a) + p["at"][0], y + p["at"][1],
                              -x * math.sin(a) + z * math.cos(a) + p["at"][2]) for x, y, z in wicks[p["piece"]]]

            placed = e.get("wicks", [])

            if not placed or any(min(math.dist(w, t) for t in tops) > 0.01 for w in placed):
                astray.append((e["at"], len(placed), len(tops)))

        self.assertEqual(astray, [])

    def test_scene_parts_stand_clear(self):
        """No part of a scene passes through another of it (the warden stood
        in the god's candles, kneelers knelt in each other, crates lay in the
        overturned cart), but what a figure holds and the parts made to
        touch (scenes_catalogue.TOUCHING)."""
        import mesh_cross
        import scenes_catalogue
        scenes = {}

        for p in DRESSING["pieces"]:
            if p.get("scene") is not None and not p.get("held"):
                scenes.setdefault(p["scene"], []).append(p)

        through = []

        for parts in scenes.values():
            for i, a in enumerate(parts):
                for b in parts[i + 1:]:
                    pair = (a["piece"], b["piece"])

                    if pair in scenes_catalogue.TOUCHING or pair[::-1] in scenes_catalogue.TOUCHING:
                        continue

                    if abs(a["at"][0] - b["at"][0]) > 4 or abs(a["at"][2] - b["at"][2]) > 4:
                        continue

                    n = mesh_cross.crossings(a, b)

                    if n:
                        through.append((a["piece"], b["piece"], round(a["at"][0], 1), round(a["at"][2], 1), n))

        self.assertEqual(sorted(set((a, b) for a, b, *_ in through)), [], through[:6])

    def test_garden_beds_planted(self):
        """Every bed of the garden is planted: shrubs round its edge and
        flowers through it, not bare earth under three trees."""
        beds = [a["rect"] for a in DRESSING["ground"]["areas"] if a["tile"] == "ground_earth" and a["level"] > 0.1]
        plants = [p for p in DRESSING["pieces"] if p["piece"] in ("garden_shrub", "flower_clump")]
        bare = []

        for r in beds:
            inside = [p for p in plants if r[0] < p["at"][0] < r[2] and r[1] < p["at"][2] < r[3]]

            if len(inside) < 12:
                bare.append((r, len(inside)))

        self.assertGreater(len(beds), 20)
        self.assertEqual(bare[:5], [])

    def test_gate_clean(self):
        problems = dress.gate(DRESSING, greybox.build(DATA), FACES)
        self.assertEqual(problems, [], "\n".join(problems[:20]))


if __name__ == "__main__":
    unittest.main()
