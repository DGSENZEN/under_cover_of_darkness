"""The workshops (workshop.py: a district's buildings and their kit pieces in
a .blend to edit) and your pieces read back from them (yours.py ->
yours.json, applied by kit_recipes and kit.py): pure Python, no Blender.
(test_workshop.sh runs the round trip in Blender.)

    python3 tools/level/test_workshop.py
"""

import json
import math
import os
import random
import sys
import tempfile
import unittest

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import geo  # noqa: E402
import kit_recipes  # noqa: E402
import workshop_groups as wg  # noqa: E402
import yours_data  # noqa: E402


class Angles(unittest.TestCase):
    def test_yxz_angles_undo_rotation(self):
        rng = random.Random(7)

        for _ in range(200):
            yaw, pitch, roll = rng.uniform(-180, 180), rng.uniform(-85, 85), rng.uniform(-180, 180)
            back = geo.yxz_angles(geo.rotation(yaw, pitch, roll))
            again = geo.rotation(*back)
            want = geo.rotation(yaw, pitch, roll)

            for r in range(3):
                for c in range(3):
                    self.assertAlmostEqual(again[r][c], want[r][c], places=9)

    def test_plain_turns_read_back_as_given(self):
        self.assertEqual([round(a, 6) for a in geo.yxz_angles(geo.rotation(90.0, 0.0, 0.0))], [90.0, 0.0, 0.0])
        self.assertEqual([round(a, 6) for a in geo.yxz_angles(geo.rotation(0.0, 30.0, 0.0))], [0.0, 30.0, 0.0])
        self.assertEqual([round(a, 6) for a in geo.yxz_angles(geo.rotation(0.0, 0.0, -45.0))], [0.0, 0.0, -45.0])


class Yours(unittest.TestCase):
    def setUp(self):
        self.pieces = {"a": {"family": "wall", "cols": [[0, 1, 0, 2, 2, 2, "stone", 0, 0, 0]], "occlusion_exclude": [0]},
                       "b": {"family": "wall", "cols": [[0, 1, 0, 1, 1, 1, "stone", 0, 0, 0]]}}

    def test_your_colliders_replace_the_recipes(self):
        mine = {"a": {"file": "workshop_harbour.blend", "mesh": False,
                      "cols": [[0, 2, 0, 3, 4, 3, "wood", 10, 0, 0], [1, 1, 1, 1, 1, 1, "glass", 0, 0, 0]], "occlusion_exclude": [1]}}
        orphans = yours_data.apply(self.pieces, mine)
        self.assertEqual(orphans, [])
        self.assertEqual(self.pieces["a"]["cols"][0][6], "wood")
        self.assertEqual(len(self.pieces["a"]["cols"]), 2)
        self.assertEqual(self.pieces["a"]["occlusion_exclude"], [1])
        self.assertTrue(self.pieces["a"]["yours_cols"])
        self.assertNotIn("yours_mesh", self.pieces["a"])
        # (Left alone: one you did not touch.)
        self.assertEqual(self.pieces["b"]["cols"], [[0, 1, 0, 1, 1, 1, "stone", 0, 0, 0]])

    def test_your_mesh_is_named_with_its_file(self):
        yours_data.apply(self.pieces, {"b": {"file": "workshop_old_town.blend", "mesh": True, "cols": None}})
        self.assertEqual(self.pieces["b"]["yours_mesh"], "workshop_old_town.blend")
        self.assertEqual(self.pieces["b"]["cols"], [[0, 1, 0, 1, 1, 1, "stone", 0, 0, 0]])

    def test_a_piece_no_longer_in_the_kit_is_an_orphan(self):
        self.assertEqual(yours_data.apply(self.pieces, {"gone": {"file": "x.blend", "mesh": True}}), ["gone"])

    def test_the_file_is_read_from_LEVEL_YOURS_and_off_reads_nothing(self):
        with tempfile.TemporaryDirectory() as d:
            path = os.path.join(d, "yours.json")

            with open(path, "w") as f:
                json.dump({"pieces": {"a": {"file": "w.blend", "mesh": True, "cols": None}}}, f)

            old = os.environ.get("LEVEL_YOURS")

            try:
                os.environ["LEVEL_YOURS"] = path
                self.assertIn("a", yours_data.load())
                os.environ["LEVEL_YOURS"] = "off"
                self.assertEqual(yours_data.load(), {})
                os.environ["LEVEL_YOURS"] = os.path.join(d, "none.json")
                self.assertEqual(yours_data.load(), {})
            finally:
                if old is None:
                    os.environ.pop("LEVEL_YOURS", None)
                else:
                    os.environ["LEVEL_YOURS"] = old


def by_name(groups):
    return {g["name"]: g for g in groups}


class Harbour(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.groups = wg.groups("harbour")
        cls.named = by_name(cls.groups)

    def test_the_buildings_asked_for_are_there(self):
        for name in ("Customs house", "Shipyard naves", "Golden tower (lighthouse)", "Mole", "Sea fort", "Causeway and bridge",
                     "Terreiro and the Sea Gate", "Ribeira houses", "City walls and the Nasrid gate", "Quays", "Ships"):
            self.assertIn(name, self.named)

    def test_each_building_holds_its_own_pieces(self):
        def placed(name):
            return {p["piece"] for p in self.named[name]["placed"]}

        self.assertTrue({"customs_portal_wall", "customs_roof", "customs_tower"} <= placed("Customs house"))
        self.assertTrue({"gold_stage_1", "gold_stage_2", "gold_stage_3"} <= placed("Golden tower (lighthouse)"))
        self.assertTrue({"nave_vault", "nave_pier"} <= placed("Shipyard naves"))
        self.assertTrue({"fort_bastion", "fort_tower"} <= placed("Sea fort"))
        self.assertIn("mole_head", placed("Mole"))
        self.assertIn("nasrid_gate", placed("City walls and the Nasrid gate"))
        self.assertIn("carrack_hull", placed("Ships"))
        # (The mole and the causeway are swept ground: shown from the level.)
        self.assertIn("mole_body", self.named["Mole"]["context"])
        self.assertIn("spit_causeway", self.named["Causeway and bridge"]["context"])

    def test_every_piece_has_one_home(self):
        homes = {}

        for g in self.groups:
            for piece in g["kit"]:
                self.assertNotIn(piece, homes, "%s homed in %s and %s" % (piece, homes.get(piece), g["name"]))
                homes[piece] = g["name"]

        used = {p["piece"] for g in self.groups for p in g["placed"]}
        self.assertEqual(used - set(homes), set())
        self.assertEqual(homes["customs_roof"], "Customs house")

    def test_placed_pieces_sit_round_their_buildings_middle(self):
        for g in self.groups:
            if not g["placed"]:
                continue

            xs = [p["position"][0] for p in g["placed"]]
            zs = [p["position"][2] for p in g["placed"]]
            self.assertLess(abs((min(xs) + max(xs)) / 2.0), 1e-6, g["name"])
            self.assertLess(abs((min(zs) + max(zs)) / 2.0), 1e-6, g["name"])
            self.assertAlmostEqual(min(p["position"][1] for p in g["placed"]), 0.0, places=6)


class OldTown(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.groups = wg.groups("old_town")
        cls.named = by_name(cls.groups)

    def test_one_house_of_each_style_and_quirk(self):
        styles = self.named["House styles"]
        shown = {wg.house_style(p["piece"]) for p in styles["placed"]}
        everywhere = {wg.house_style(n) for n in kit_recipes.PIECES if n.startswith(wg.HOUSE_PREFIXES)}
        self.assertEqual(shown, everywhere)
        self.assertEqual(len(styles["placed"]), len(everywhere))
        self.assertIn(("porto", "jetty"), shown)
        self.assertIn(("pombal", "mansard"), shown)
        self.assertIn(("patio", ""), shown)

    def test_key_buildings_and_works(self):
        keys = {p["piece"] for p in self.named["Key buildings"]["placed"]}
        self.assertTrue({"tavern", "town_chapel", "merchant_house", "landmark_tower", "garden_house", "tannery"} <= keys)
        self.assertTrue(any(n.startswith("scaffold_") for n in self.named["Buildings being built"]["kit"]))
        self.assertTrue(any(p["piece"].startswith("carmo_") for p in self.named["The Carmo"]["placed"]))

    def test_street_samples_stand_in_their_quarters(self):
        for name in ("Street: the Baixa", "Street: the stairs", "Street: the Judiaria"):
            placed = self.named[name]["placed"]
            self.assertGreater(len(placed), 10, name)
            self.assertTrue(any(p["piece"].startswith(wg.HOUSE_PREFIXES) for p in placed), name)

        self.assertTrue(any(p["piece"].startswith("scaffold_") for p in self.named["Street: the Baixa"]["placed"]))
        self.assertTrue(any(p["piece"] == "tavern" for p in self.named["Street: the stairs"]["placed"]))

    def test_every_piece_has_one_home(self):
        homes = set()

        for g in self.groups:
            self.assertEqual(homes & set(g["kit"]), set(), g["name"])
            homes |= set(g["kit"])

        used = {p["piece"] for g in self.groups for p in g["placed"]}
        self.assertEqual(used - homes, set())


if __name__ == "__main__":
    unittest.main()
