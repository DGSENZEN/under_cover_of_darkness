"""The Zócalo's street and canal dressing (dress.py) from the real plan and
the kits' faces (tools/eclipse/<kit>.py must have been built).

    python3 tools/level/test_dress.py
"""

import json
import math
import os
import sys
import unittest
from pathlib import Path

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = Path(HERE).parents[1]
sys.path.insert(0, HERE)
sys.path.insert(0, os.path.join(HERE, "layouts"))

import city_zocalo  # noqa: E402
import dress  # noqa: E402
import greybox  # noqa: E402
import plan  # noqa: E402
import plan_check  # noqa: E402

DATA = city_zocalo.plan()
FACES = dress.load_faces()
BUILT = all(k in FACES for k in dress.KITS)
DRESSING = dress.dress(DATA, FACES) if BUILT else None


def _pieces(name):
    return [p for p in DRESSING["pieces"] if p["piece"] == name]


def _middle(p):
    """A placement's middle on the ground (x, z), its stretch counted."""
    lo, hi = dress.box(p, FACES)
    return ((lo[0] + hi[0]) / 2, (lo[2] + hi[2]) / 2)


@unittest.skipUnless(BUILT, "the kits are not built (tools/eclipse/lab.sh all)")
class Dressing(unittest.TestCase):
    def test_fill_even_stretch(self):
        self.assertEqual(dress.fill(200, 1.5), (133, 200 / 199.5))

        with self.assertRaises(ValueError):
            dress.fill(10, 4.5)

    def test_fill_mixed_takes_a_short_piece(self):
        """15 m of 4.5 and 1.5 m pieces: three long and one short, unstretched."""
        self.assertEqual(dress.fill_mixed(15.0, (4.5, 1.5)), ([4.5, 4.5, 4.5, 1.5], 1.0))

    def test_no_piece_overhangs_the_brink(self):
        x0, z0, x1, z1 = plan_check._bounds(DATA["brink"])
        out = []

        for p in DRESSING["pieces"]:
            lo, hi = dress.box(p, FACES)

            if lo[0] < x0 - 1e-3 or hi[0] > x1 + 1e-3 or lo[2] < z0 - 1e-3 or hi[2] > z1 + 1e-3:
                out.append((p["piece"], p["at"]))

        self.assertEqual(out, [])

    def test_tram_straights_are_unstretched(self):
        tracks = _pieces("tram_track") + _pieces("tram_track_shimmed")
        self.assertGreater(len(tracks), 150)
        self.assertTrue(all(abs(p["stretch"] - 1.0) < 1e-9 for p in tracks))
        self.assertEqual(len(_pieces("tram_track_curve")), 4)

    def test_every_stretch_within_five_percent(self):
        self.assertTrue(all(0.95 <= p.get("stretch", 1.0) <= 1.05 for p in DRESSING["pieces"]))

    def test_drops_at_the_four_gates(self):
        middles = sorted((round(x, 1), round(z, 1)) for x, z in map(_middle, _pieces("kerb_drop")))
        self.assertEqual(middles, [(-99.2, 42.5), (0.0, -109.2), (0.0, 109.2), (99.2, 0.0)])

    def test_steel_bridge_nearest_seepage(self):
        steel = _pieces("bridge_steel")
        self.assertEqual(len(steel), 1)
        self.assertAlmostEqual(steel[0]["at"][0], 150.0)
        self.assertEqual(len(_pieces("bridge_stone")), 2)

    def test_variants_follow_fields(self):
        for name, plain, kind, least in (("kerb_heaved", "kerb_straight", "subsidence", dress.HEAVE),
                                         ("tram_track_shimmed", "tram_track", "subsidence", dress.HEAVE)):
            for p in _pieces(name):
                self.assertGreaterEqual(plan.field(DATA, kind, *_middle(p)), least, (name, p["at"]))

            for p in _pieces(plain):
                self.assertLess(plan.field(DATA, kind, *_middle(p)), least, (plain, p["at"]))

        self.assertTrue(_pieces("kerb_heaved"))
        self.assertTrue(_pieces("tram_track_shimmed"))

        for p in _pieces("tram_conductor"):
            self.assertGreaterEqual(plan.field(DATA, "seepage", *_middle(p)), dress.SEEPED)

        self.assertTrue(_pieces("tram_conductor"))

    def test_inlays_do_not_overlap(self):
        for area in DRESSING["ground"]["areas"]:
            inlays = area["inlays"]

            for i in range(len(inlays)):
                for j in range(i + 1, len(inlays)):
                    a, b = inlays[i], inlays[j]
                    if not dress.boxes_meet(a, b):
                        continue
                    clipper, subject = (b, a) if plan_check.convex(b) else (a, b)
                    self.assertLess(plan_check.overlap_area(subject, clipper), 1e-4, (a[0], b[0]))

    def test_every_flush_piece_is_set_in_its_ground(self):
        """A flush piece's outline is one of the inlays (or openings) of the
        ground at its level, so no ground lies in its top's plane."""
        cut = {}

        for area in DRESSING["ground"]["areas"]:
            for poly in area["inlays"]:
                cut.setdefault(round(area["level"], 3), []).append([tuple(round(v, 3) for v in q) for q in poly])

        for p in DRESSING["pieces"]:
            if p["piece"] not in dress.FLUSH:
                continue

            outline = [tuple(round(v, 3) for v in q) for q in dress.outline(p)]
            self.assertIn(outline, cut.get(round(p["at"][1], 3), []), (p["piece"], p["at"]))

    def test_the_greybox_it_replaces(self):
        self.assertLessEqual({"ground", "plaza", "canal", "landing_w", "landing_e", "bridge_1", "bridge_2", "bridge_3"},
                             set(DRESSING["skip"]))

    def test_every_piece_exists_in_its_kit(self):
        missing = {(p["kit"], p["piece"]) for p in DRESSING["pieces"] if p["piece"] not in FACES[p["kit"]]["objects"]}
        self.assertEqual(missing, set())

    def test_district_gate_clean(self):
        box = greybox.build(DATA)
        problems = dress.gate(DRESSING, box, FACES)
        self.assertEqual(problems, [], "\n".join(problems[:20]))


if __name__ == "__main__":
    unittest.main()
