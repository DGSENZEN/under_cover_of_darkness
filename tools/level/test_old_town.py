"""The old town as a level (plan B1a, Task 13 on): its ground of five
quarters, its lot plan (each lot a house the kit builds once per design),
the gates it shares with the harbour, its doors where its houses open.

    python3 tools/level/test_old_town.py
"""

import os
import sys
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
sys.path.insert(0, os.path.join(HERE, "layouts"))

import geo  # noqa: E402
import kit_porto  # noqa: E402
import kit_recipes  # noqa: E402
import kit_town  # noqa: E402
import old_town  # noqa: E402
import rules  # noqa: E402
import town  # noqa: E402
from test_rules import marker, piece  # noqa: E402

LAYOUT = None


def layout():
    global LAYOUT

    if LAYOUT is None:
        LAYOUT = old_town.layout()

    return LAYOUT


def lot(name, x, z, width=4.5, depth=12.0, storeys=4, enterable=False, quirk="", yaw=0.0):
    return town.Lot(name, "porto", x, z, 14.0, yaw, width, depth, storeys, quirk, enterable, 2 if enterable else 0)


class OldTown(unittest.TestCase):
    def test_the_old_town_checks_clean(self):
        self.assertEqual(rules.problems(layout(), "stage2"), [])

    def test_the_gates_keep_their_names(self):
        names = {m["name"] for m in layout()["markers"]}

        for gate in ("sea_gate", "wall_walk", "guindais", "west_wall"):
            self.assertIn("from_harbour_" + gate, names)
            self.assertIn("to_harbour_" + gate, names)

        self.assertIn("old_town_start", names)

    def test_no_slit_between_neighbours(self):
        # (A foot falls into a slit, the eye sees through it: neighbours
        # share a wall, or leave a lane of a metre or more.)
        self.assertEqual(town.slits([lot("a", 0.0, 0.0), lot("b", 4.5, 0.0)]), [])
        self.assertEqual(town.slits([lot("a", 0.0, 0.0), lot("b", 6.0, 0.0)]), [])
        self.assertEqual(len(town.slits([lot("a", 0.0, 0.0), lot("b", 5.0, 0.0)])), 1)
        self.assertEqual(town.slits(town.all_lots()), [])

    def test_every_live_door_has_its_marker(self):
        house = lot("door_house", 0.0, 0.0, enterable=True)
        key = kit_town.register_lot(house)
        door = kit_recipes.PIECES[key]["doors"][0]
        data = {"level": "fixture", "pieces": [piece("door_house", key, (0, 0, 0))], "markers": []}
        self.assertTrue(any("door_house: its door at" in p for p in rules.door_problems(data)), rules.door_problems(data))
        data["markers"].append(marker("door_house_door", "door", door[:3]))
        self.assertEqual(rules.door_problems(data), [])

    def test_no_door_marker_on_a_shut_front(self):
        house = lot("shut_house", 0.0, 0.0)
        key = kit_town.register_lot(house)
        data = {"level": "fixture", "pieces": [piece("shut_house", key, (0, 0, 0))],
                # (At its barred door: the first of its two bays, in its front wall.)
                "markers": [marker("shut_door", "door", (-0.925, 0.0, -0.3))]}
        self.assertTrue(any("shut_door (door): on a shut front of shut_house" in p for p in rules.door_problems(data)), rules.door_problems(data))

    def test_equal_designs_share_a_piece(self):
        a, b = lot("a", 0.0, 0.0), lot("b", 30.0, -40.0, yaw=90.0)
        self.assertEqual(town.design_key(a), town.design_key(b))
        self.assertNotEqual(town.design_key(a), town.design_key(lot("c", 0.0, 0.0, storeys=5)))
        self.assertTrue(town.design_key(a).startswith("town_"))

    def test_terraces_cover_the_quarters(self):
        for name, (x0, z0, x1, z1) in town.QUARTERS.items():
            for i in range(9):
                for j in range(9):
                    x = x0 + (x1 - x0) * (i + 0.5) / 9.0
                    z = z0 + (z1 - z0) * (j + 0.5) / 9.0

                    if not town.inside(x, z, town.PASSAGE):
                        self.assertGreater(town.height(x, z), town.HOLE + 1.0, (name, x, z))

    def test_the_quarters_stand_at_their_heights(self):
        # (The spec's 4.3: the Baixa at +3 to +6, the upper gate at +85.)
        self.assertAlmostEqual(town.height(-55.0, -100.0), 2.5)
        self.assertLessEqual(town.height(-40.0, -165.0), 6.0 + 1e-6)
        self.assertAlmostEqual(town.height(-30.0, -378.0), 85.0)
        self.assertAlmostEqual(town.height(148.0, -78.0), 14.0)


if __name__ == "__main__":
    unittest.main()
