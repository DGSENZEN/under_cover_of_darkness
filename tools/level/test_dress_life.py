"""The Zócalo's street life (dress_life.py) laid over family 1's dressing,
from the real plan and the kits' faces (tools/eclipse/lab.sh all first).

    python3 tools/level/test_dress_life.py
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
import dress_life  # noqa: E402
import greybox  # noqa: E402
import plan_check  # noqa: E402

DATA = city_zocalo.plan()
FACES = dress.load_faces()
BUILT = all(k in FACES for k in dress.KITS)
DRESSING = dress.dress(DATA, FACES) if BUILT else None
LIFE = {"furniture_kit", "trade_kit", "uncanny_kit", "bound_god"}


def _pieces(name):
    return [p for p in DRESSING["pieces"] if p["piece"] == name]


def _count(*names):
    return sum(len(_pieces(n)) for n in names)


def _foot(p):
    return dress_life.foot(p, FACES)


def _meet(a, b, slack=0.02):
    return a[0] + slack < b[2] and b[0] + slack < a[2] and a[1] + slack < b[3] and b[1] + slack < a[3]


@unittest.skipUnless(BUILT, "the kits are not built (tools/eclipse/lab.sh all)")
class Life(unittest.TestCase):
    def test_every_card_piece_placed(self):
        names = {o for kit in LIFE for o in FACES[kit]["objects"]}
        placed = {p["piece"] for p in DRESSING["pieces"]}
        self.assertEqual(names - placed, set())
        self.assertEqual(len(_pieces("bound_god")), 1)

    def test_density(self):
        self.assertTrue(50 <= _count("tram_pole", "tram_pole_lamp", "lamp_dead", "ward_cage_lamp") <= 90)
        self.assertGreaterEqual(_count("cart_hand", "cart_flower", "cart_tamale", "cart_ice", "cart_firewood"), 60)
        self.assertGreaterEqual(_count("bollard_guardstone", "bollard_cannon"), 150)
        self.assertGreaterEqual(_count("plaque_talavera"), 150)
        self.assertGreaterEqual(_count("kiosk_news", "kiosk_lottery", "kiosk_sweets"), 20)

    def test_nothing_stands_in_anything(self):
        """No standing piece of street life overlaps another standing piece, a
        plot, a sunken place or (but the offerings and petals) a flush piece."""
        standing = [p for p in DRESSING["pieces"] if p["kit"] in LIFE and p["piece"] not in dress_life.ON_WALLS
                    and p["piece"] not in dress_life.HUNG and p["piece"] not in dress.FLUSH]
        others = [p for p in DRESSING["pieces"] if p["piece"] not in dress.FLUSH and p["piece"] not in dress_life.HUNG
                  and p["piece"] not in dress_life.ON_WALLS]
        clashes = []
        index = {}

        for k, p in enumerate(others):
            f = _foot(p)

            for i in range(math.floor(f[0] / 10), math.floor(f[2] / 10) + 1):
                for j in range(math.floor(f[1] / 10), math.floor(f[3] / 10) + 1):
                    index.setdefault((i, j), []).append(k)

        for p in standing:
            f = _foot(p)
            near = {k for i in range(math.floor(f[0] / 10), math.floor(f[2] / 10) + 1)
                    for j in range(math.floor(f[1] / 10), math.floor(f[3] / 10) + 1) for k in index.get((i, j), [])}

            for k in near:
                q = others[k]

                on_coping = p["piece"] in dress_life.ON_COPING and q["piece"].startswith(dress_life.COPING_PIECES)

                if q is not p and _meet(f, _foot(q)) and (p["piece"], q["piece"]) not in dress_life.TOGETHER \
                        and not on_coping:
                    clashes.append((p["piece"], p["at"][0], p["at"][2], q["piece"]))

            sunken = [] if p["piece"] in dress_life.ON_COPING else \
                [g for g in DATA["ground"] if g["kind"] in ("canal", "landing", "well", "dig")]

            for g in DATA["plots"] + sunken:
                b = plan_check._bounds(g["polygon"])

                if _meet(f, b, 0.05):
                    clashes.append((p["piece"], p["at"][0], p["at"][2], g["name"]))

        self.assertEqual(clashes[:10], [])

    def test_wall_pieces_on_walls(self):
        """Every plaque, plate and poster board is 4 cm off a plot's wall and
        within that wall's length."""
        walls = dress_life.street_walls(DATA)
        off = []

        for p in DRESSING["pieces"]:
            if p["piece"] not in ("plaque_talavera", "plate_street", "poster_cluster"):
                continue

            x, z = p["at"][0], p["at"][2]

            if not any(abs(dress_life.wall_distance(w, (x, z)) - dress_life.OFF_WALL) < 1e-3 and dress_life.within(w, (x, z))
                       for w in walls):
                off.append((p["piece"], x, z))

        self.assertEqual(off[:10], [])

    def test_spans_end_on_poles(self):
        poles = [p for p in DRESSING["pieces"] if p["piece"] in dress_life.POLES]
        tips = [dress_life.insulator(p) for p in poles]

        for s in _pieces("span_wire"):
            a = (s["at"][0], s["at"][2])
            r = math.radians(s["yaw"])
            length = 10.8 * s["stretch"]
            b = (a[0] + length * math.cos(r), a[1] - length * math.sin(r))

            for end in (a, b):
                self.assertTrue(any(math.hypot(end[0] - t[0], end[1] - t[1]) < 0.02 for t in tips), end)

    def test_wires_pass_no_plot(self):
        for s in _pieces("span_wire") + _pieces("trolley_wire"):
            r = math.radians(s["yaw"])
            length = (10.8 if s["piece"] == "span_wire" else 30.0) * s["stretch"]

            for k in range(11):
                x = s["at"][0] + length * k / 10 * math.cos(r)
                z = s["at"][2] - length * k / 10 * math.sin(r)
                inside = [g["name"] for g in DATA["plots"] if plan_check.inside((x, z), g["polygon"])]
                self.assertEqual(inside, [], (s["piece"], x, z))

    def test_every_lit_lamp_has_a_light(self):
        lit = _count("tram_pole_lamp", "ward_cage_lamp")
        self.assertEqual(len(DRESSING["lights"]), lit)

    def test_the_god(self):
        god = _pieces("bound_god")[0]
        self.assertEqual([round(v, 3) for v in god["at"]], [0.0, 0.2, 0.0])
        heap = _pieces("offerings_heap")[0]
        self.assertGreater(heap["at"][2], 2.9)
        self.assertEqual(len([p for p in _pieces("ward_cage_lamp")
                              if abs(math.hypot(p["at"][0], p["at"][2]) - dress_life.GOD_RING) < 0.01]), 8)

    def test_names_unique_across_kits(self):
        seen = {}

        for kit, faces in FACES.items():
            for name in faces["objects"]:
                self.assertNotIn(name, seen, (name, kit, seen.get(name)))
                seen[name] = kit

    def test_district_gate_clean(self):
        problems = dress.gate(DRESSING, greybox.build(DATA), FACES)
        self.assertEqual(problems, [], "\n".join(problems[:20]))


if __name__ == "__main__":
    unittest.main()
