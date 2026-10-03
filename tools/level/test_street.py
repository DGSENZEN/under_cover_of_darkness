"""The old town's street furniture (plan B1a, Task 8; kit_street): corner
lamps' arms, shrines and their lamps, tile panels of the comet and the
forgotten king, fountains and their water.

    python3 tools/level/test_street.py
"""

import os
import sys
import unittest

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import kit_recipes  # noqa: E402
import kit_street  # noqa: E402,F401
from test_kits import tris  # noqa: E402

PIECES = kit_recipes.PIECES


def cards(name, slot):
    return [s for s in PIECES[name]["shapes"] if s["kind"] == "card" and s["slot"] == slot]


class Street(unittest.TestCase):
    def test_a_panel_is_4_by_6_tiles(self):
        for name, slot in (("panel_comet", "azulejo_comet"), ("panel_king", "azulejo_king")):
            face = cards(name, slot)
            self.assertEqual(len(face), 1, name)
            self.assertAlmostEqual(face[0]["size"][0], 0.56, delta=0.01)
            self.assertAlmostEqual(face[0]["size"][1], 0.84, delta=0.01)
            self.assertTrue(any(s["slot"] == "tile_frame" for s in PIECES[name]["shapes"]), name)

    def test_a_shrine_has_its_lamp(self):
        lamp = PIECES["shrine_alminha"]["sockets"]["lamp"][0]
        niche = kit_street.NICHE
        self.assertLessEqual(abs(lamp[0]), niche[0] / 2.0)
        self.assertTrue(kit_street.NICHE_SILL <= lamp[1] <= kit_street.NICHE_SILL + niche[1])
        self.assertTrue(cards("shrine_alminha", "azulejo_king"))
        retablo = PIECES["shrine_retablo"]["sockets"]["lamp"][0]
        self.assertAlmostEqual(retablo[1], 2.5, delta=0.3)
        self.assertTrue(cards("shrine_retablo", "azulejo_comet"))

    def test_the_corner_lamp_hangs_two_lanterns_from_its_arm(self):
        hooks = PIECES["corner_lamp"]["sockets"]["lamp"]
        self.assertEqual(len(hooks), 2)
        self.assertTrue(all(abs(h[1] - kit_street.ARM_HEIGHT) < 0.2 and h[2] > 0.6 for h in hooks))

    def test_fountains_have_their_water(self):
        for name in ("fountain_carmo", "fountain_wall", "fountain_bowls"):
            self.assertTrue(PIECES[name]["sockets"].get("water"), name)
            self.assertTrue(PIECES[name]["cols"], name)

    def test_street_budget(self):
        for name, most in (("fountain_wall", 500), ("fountain_bowls", 500), ("fountain_carmo", 2000), ("corner_lamp", 300),
                           ("shrine_alminha", 300), ("shrine_retablo", 300), ("panel_comet", 120), ("panel_king", 120)):
            self.assertLessEqual(tris(PIECES[name]), most, name)
            self.assertLessEqual(tris(PIECES[name]), PIECES[name].get("budget", 800), name)


if __name__ == "__main__":
    unittest.main()
