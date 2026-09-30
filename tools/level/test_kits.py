"""The city's kit families against the level metrics and their budgets:
pure Python, no Blender.

    python3 tools/level/test_kits.py
"""

import math
import os
import sys
import unittest

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import geo  # noqa: E402
import kit_recipes  # noqa: E402
import kit_shapes  # noqa: E402
import rules  # noqa: E402


def tris(recipe):
    return sum(len(f[0]) - 2 for f in kit_shapes.build(recipe["shapes"])["faces"]) if recipe.get("shapes") else len(recipe["boxes"]) * 12


def family(name):
    return {n: r for n, r in kit_recipes.PIECES.items() if r["family"] == name}


def treads(recipe):
    """A flight's steps in order up: [(top y, depth along the flight)]."""
    steps = sorted(recipe["boxes"], key=lambda b: b[1] + b[4] / 2.0)
    # (A tread is the step's shorter side: its run, not its width.)
    return [(round(b[1] + b[4] / 2.0, 3), round(min(b[3], b[5]), 3)) for b in steps]


def top_of(col):
    return col[1] + col[4] / 2.0


def _corners(box):
    axes = box.axes()
    return [[box.centre[i] + sum(s[k] * box.half[k] * axes[k][i] for k in range(3)) for i in range(3)]
            for s in ((1, 1, 1), (1, 1, -1), (1, -1, 1), (1, -1, -1), (-1, 1, 1), (-1, 1, -1), (-1, -1, 1), (-1, -1, -1))]


class Fort(unittest.TestCase):
    def test_budgets(self):
        pieces = family("fort")
        self.assertGreaterEqual(len(pieces), 16)

        for name, recipe in pieces.items():
            self.assertLessEqual(tris(recipe), recipe.get("budget", kit_shapes.PIECE_TRIS), name)

    def test_battlements_are_three_metre_bays(self):
        cols = kit_recipes.PIECES["city_wall_12_6"]["cols"]
        merlons = sorted((c for c in cols if c[1] > 12.0 + 0.9), key=lambda c: c[0])
        self.assertEqual(len(merlons), 2)
        self.assertAlmostEqual(merlons[0][3], 2.1, places=2)
        self.assertAlmostEqual(merlons[1][0] - merlons[0][0], 3.0, places=2)

    def test_the_walk_is_walkable_and_parapeted(self):
        cols = kit_recipes.PIECES["city_wall_12_6"]["cols"]
        body = max(cols, key=lambda c: c[3] * c[4] * c[5])
        self.assertAlmostEqual(top_of(body), 12.0, places=2)
        self.assertTrue(all(c[2] > 0.0 for c in cols if c[1] > 12.0))
        self.assertGreaterEqual(2.4 - max(c[5] for c in cols if c[1] > 12.0), 1.2)

    def test_wall_stairs_keep_the_metrics(self):
        for name, height in (("wall_stair_12", 12.0), ("wall_stair_10", 10.0)):
            steps = treads(kit_recipes.PIECES[name])
            rises = [round(b[0] - a[0], 3) for a, b in zip(steps, steps[1:])]
            self.assertTrue(all(r == kit_recipes.RISER for r in rises), name)
            self.assertAlmostEqual(steps[-1][0], height, places=3)
            self.assertTrue(all(d == kit_recipes.TREAD or (i + 1) % 10 == 0 for i, (_, d) in enumerate(steps[:-1])), name)

    def test_round_towers_are_solid_to_their_rims_and_no_further(self):
        for name, radius, top in (("tower_drum_8", 4.0, 20.0), ("gold_stage_1", 7.5, 18.0)):
            recipe = kit_recipes.PIECES[name]
            body = [c for c in recipe["cols"] if abs(top_of(c) - top) < 1e-3]
            self.assertTrue(body, name)
            corner = max(math.hypot(abs(c[0]) + c[3] / 2.0, abs(c[2]) + c[5] / 2.0) for c in body if c[7] == 0.0)
            self.assertLessEqual(corner, radius / math.cos(math.pi / (16 if "drum" in name else 12)) + 0.05, name)

    def test_the_gold_ladder_comes_up_through_the_breastwork(self):
        # Its top meets a gap in the terrace's breastwork, no merlon over it:
        # a man comes up onto the terrace, and a guard's ladder link (which
        # lands 0.7 m in from the ladder) finds its floor. Drawn open too.
        import kit_fort
        recipe = kit_recipes.PIECES["gold_stage_1"]
        apothem, height = kit_fort.GOLD[0][0] / 2.0, kit_fort.GOLD[0][1]
        boxes = geo.piece_boxes(recipe, [0.0, 0.0, 0.0], geo.IDENTITY)
        built = kit_shapes.build(recipe["shapes"])
        drawn = []

        for y in (height + 0.3, height + 0.8, height + 1.5):
            for z in (-apothem + 0.1, -apothem + 0.3, -apothem + 0.55):
                for x in (kit_fort.LADDER - 0.3, kit_fort.LADDER, kit_fort.LADDER + 0.3):
                    self.assertFalse(any(b.contains([x, y, z]) for b in boxes), (x, y, z))

        # (No drawn face of the breastwork crosses the gap at its middle.)
        for face in built["faces"]:
            points = [built["verts"][i] for i in face[0]]

            if all(abs(p[0] - kit_fort.LADDER) < 0.4 for p in points) and all(height + 0.05 < p[1] < height + kit_fort.BREAST + 0.05 for p in points):
                drawn.append(points)

        self.assertEqual(drawn, [])

    def test_the_sea_gate_passage_is_clear(self):
        # 4 m wide and 5 m high through its front and its passage.
        for name in ("gate_front", "gate_passage_16"):
            for c in kit_recipes.PIECES[name]["cols"]:
                low, high = c[1] - c[4] / 2.0, c[1] + c[4] / 2.0
                near = abs(c[0]) - c[3] / 2.0

                if near < 2.0 - 1e-3 and low < 5.0 - 1e-3:
                    self.fail("%s: a collider in the passage %s" % (name, c))

    def test_the_nasrid_gate_lets_boats_through(self):
        cols = kit_recipes.PIECES["nasrid_gate"]["cols"]
        jamb = 3.5 * math.cos(math.asin(0.33))

        for c in cols:
            if abs(c[0]) - c[3] / 2.0 < jamb - 1e-3 and c[1] - c[4] / 2.0 < 10.0 - 1e-3:
                self.fail("a collider in the water gate %s" % c)

    def test_colliders_stay_in_their_size(self):
        loose = []

        for name, recipe in family("fort").items():
            for box in geo.piece_boxes(recipe, [0.0, 0.0, 0.0], geo.IDENTITY):
                for corner in _corners(box):
                    if abs(corner[0]) > recipe["size"][0] / 2.0 + 0.3 or abs(corner[2]) > recipe["size"][2] / 2.0 + 0.3:
                        loose.append("%s: %s" % (name, [round(c, 2) for c in corner]))
                        break

        self.assertEqual(loose, [])

    def test_the_chain_stops_nobody(self):
        self.assertEqual(kit_recipes.PIECES["chain_span_12"]["cols"], [])


CASAS = ["casa_%s" % c for c in "abcdefgh"]


def balconies(recipe):
    """A house's balcony floors (thin, deep enough to stand on, out over its
    front), from the bottom up."""
    front = recipe["front"]
    return sorted((c for c in recipe["cols"] if c[4] <= 0.2 and c[5] >= 0.8 and c[2] > front), key=lambda c: c[1])


class Iberian(unittest.TestCase):
    def test_budgets(self):
        pieces = dict(family("iberian"), **family("casa"))
        self.assertGreaterEqual(len(pieces), 18)

        for name, recipe in pieces.items():
            self.assertLessEqual(tris(recipe), recipe.get("budget", kit_shapes.PIECE_TRIS), name)

    def test_balconies_ladder_up_a_front(self):
        # From the quay to the first, then balcony to balcony: each lip within
        # a hang of the floor under it, deep enough, nothing solid in front
        # of the wall under it.
        for name in ("casa_a", "casa_d"):
            recipe = kit_recipes.PIECES[name]
            floors = balconies(recipe)
            self.assertGreaterEqual(len(floors), 3, name)
            below = 0.0

            for c in floors:
                lip = top_of(c)
                self.assertLessEqual(lip - below, rules.HANG, name)
                self.assertGreaterEqual(c[5], rules.LIP)
                below = lip
                hang = [c[0], lip - 1.0, c[2] + c[5] / 2.0 + 0.2]
                solid = [o for o in geo.piece_boxes(recipe, [0.0, 0.0, 0.0], geo.IDENTITY) if o.contains(hang)]
                self.assertEqual(solid, [], "%s: under its balcony at %.1f" % (name, lip))

    def test_casa_d_has_a_vine_to_its_eaves(self):
        # The controller cannot climb a stack of balconies: the one over you is
        # your ceiling, and a hang leap reaches 1.2 m, not a storey. So the
        # roofs' way is casa_d's old vine: a climb from the quay to its eaves
        # (ending there, so the climber mantles onto the roof), against its
        # front, beside its balconies and clear of them. Only casa_d has one.
        recipe = kit_recipes.PIECES["casa_d"]
        self.assertEqual(len(recipe.get("climbs", [])), 1)
        x, y, z, sx, sy, sz, yaw = recipe["climbs"][0]
        self.assertLessEqual(y - sy / 2.0, 0.1)
        self.assertAlmostEqual(y + sy / 2.0, recipe["eaves"], delta=0.3)
        self.assertAlmostEqual(z - sz / 2.0, recipe["front"], places=2)
        self.assertAlmostEqual(yaw, 0.0)

        for c in balconies(recipe):
            self.assertGreaterEqual(abs(x) - sx / 2.0, abs(c[0]) + c[3] / 2.0 - 1e-6)

        self.assertTrue(any(s["slot"] == "ivy" for s in recipe["shapes"]))

        for name in CASAS:
            if name != "casa_d":
                self.assertEqual(kit_recipes.PIECES[name].get("climbs", []), [], name)

    def test_the_arcade_is_paved(self):
        # Its walkway is floored (the quay ends at its front): a collider
        # whose top is the ground, the bay's width, the walkway's depth.
        cols = kit_recipes.PIECES["arcade_ribeira_6"]["cols"]
        paving = [c for c in cols if abs(c[1] + c[4] / 2.0) < 1e-3 and c[3] >= 6.0 - 1e-3 and c[5] >= 4.0 - 1e-3]
        self.assertEqual(len(paving), 1)

    def test_the_arcade_is_walked_under(self):
        # The Ribeira's arcade: 2.2 m and more under its arches, its walkway
        # clear (its paving, under the ground, is no obstacle), a floor over it
        # for the house.
        cols = kit_recipes.PIECES["arcade_ribeira_6"]["cols"]

        for c in cols:
            if abs(c[0]) - c[3] / 2.0 < 2.2 - 1e-3 and c[1] - c[4] / 2.0 < 2.6 - 1e-3 and c[1] + c[4] / 2.0 > 1e-3:
                self.fail("in the arcade's way: %s" % c)

    def test_house_doors_meet_the_metrics(self):
        for name in CASAS:
            door = kit_recipes.PIECES[name]["door"]
            self.assertGreaterEqual(door[0], 1.2, name)
            self.assertGreaterEqual(door[1], 2.2, name)

    def test_roofs_are_walkable(self):
        for name in CASAS:
            roof = [c for c in kit_recipes.PIECES[name]["cols"] if abs(c[8]) > 1.0]
            self.assertEqual(len(roof), 2, name)
            self.assertTrue(all(abs(c[8]) <= 25.0 for c in roof), name)

    def test_the_houses_differ(self):
        looks = {(kit_recipes.PIECES[n]["slot"], kit_recipes.PIECES[n]["size"][1]) for n in CASAS}
        self.assertEqual(len(looks), len(CASAS))

    def test_granite_and_render_walls_exist(self):
        for name in ("wall_granite_door", "wall_granite_4", "wall_render_window", "wall_render_4"):
            self.assertIn(name, kit_recipes.PIECES)

    def test_flights_keep_the_metrics(self):
        steps = treads(kit_recipes.PIECES["granite_flight_3"])
        self.assertEqual(len(steps), 10)
        self.assertTrue(all(abs(b[0] - a[0] - kit_recipes.RISER) < 1e-6 for a, b in zip(steps, steps[1:])))
        self.assertTrue(all(abs(d - kit_recipes.TREAD) < 1e-6 for _, d in steps))
        water = treads(kit_recipes.PIECES["water_stair_20"])
        self.assertAlmostEqual(water[-1][0], 2.3, places=3)
        self.assertLess(water[0][0], 0.0)


class Harbour(unittest.TestCase):
    def test_budgets(self):
        pieces = dict(family("quay"), **family("harbour"), **family("dressing"))
        self.assertGreaterEqual(len([n for n in pieces if n.startswith(("quay", "mole", "nave", "galley", "crane", "slipway"))]), 11)

        for name, recipe in pieces.items():
            self.assertLessEqual(tris(recipe), recipe.get("budget", kit_shapes.PIECE_TRIS), name)

    def test_a_quay_meets_the_sea(self):
        # Its top at 2.5 over the sea, its face down to -3, its coping a lip
        # a hand can hold, standing proud of the face.
        for name in ("quay_8", "quay_4"):
            cols = kit_recipes.PIECES[name]["cols"]
            body = max(cols, key=lambda c: c[3] * c[4] * c[5])
            self.assertAlmostEqual(top_of(body), 2.5, places=3)
            self.assertAlmostEqual(body[1] - body[4] / 2.0, -3.0, places=3)
            coping = [c for c in cols if c is not body and abs(top_of(c) - 2.5) < 1e-3]
            self.assertTrue(coping, name)
            self.assertGreaterEqual(coping[0][2] + coping[0][5] / 2.0 - (body[2] + body[5] / 2.0), 0.05)
            self.assertGreaterEqual(coping[0][5], rules.LIP)

    def test_quay_steps_go_down_to_the_sea(self):
        steps = treads(kit_recipes.PIECES["quay_steps_8"])
        self.assertAlmostEqual(steps[-1][0], 2.3, places=3)
        self.assertLessEqual(steps[0][0], 0.1)
        self.assertTrue(all(abs(b[0] - a[0] - kit_recipes.RISER) < 1e-6 for a, b in zip(steps, steps[1:])))

    def test_the_mole_is_walked_and_its_parapet_climbed(self):
        cols = kit_recipes.PIECES["mole_8"]["cols"]
        body = max(cols, key=lambda c: c[3] * c[4] * c[5])
        self.assertAlmostEqual(top_of(body), 3.5, places=3)
        parapet = [c for c in cols if abs(top_of(c) - 5.5) < 1e-3]
        self.assertTrue(parapet)
        # From the boulders at its seaward foot a mantle up, then a hang to
        # the parapet's top.
        boulders = [c for c in cols if c[2] > 7.0]
        self.assertTrue(boulders)
        self.assertLessEqual(max(top_of(c) for c in boulders), rules.MANTLE)
        self.assertLessEqual(5.5 - max(top_of(c) for c in boulders), rules.HANG)

    def test_nave_bays_tile(self):
        pier = kit_recipes.PIECES["nave_pier"]
        vault = kit_recipes.PIECES["nave_vault"]
        arch = kit_recipes.PIECES["nave_arch_x"]
        self.assertAlmostEqual(arch["size"][0], 8.4, places=3)
        self.assertAlmostEqual(vault["size"][0], 8.4, places=3)
        self.assertAlmostEqual(vault["size"][2], 8.4, places=3)
        self.assertAlmostEqual(max(top_of(c) for c in vault["cols"]), 13.0, places=3)
        # (Slightly pointed arches over 7.2 m to an apex at 10.9 spring at
        # 7.1: the piers' tops.)
        self.assertAlmostEqual(max(top_of(c) for c in pier["cols"]), 7.1, places=3)
        # The arch leaves the nave clear under its apex.
        for c in arch["cols"]:
            self.assertGreaterEqual(c[1] - c[4] / 2.0, 10.9 - 1e-3)

    def test_the_galley_scaffold_climbs(self):
        galley = kit_recipes.PIECES["galley_stocks"]
        planks = sorted({round(top_of(c), 3) for c in galley["cols"] if c[4] <= 0.15 and c[3] > 20.0})
        self.assertEqual(len(planks), 2)
        self.assertLessEqual(planks[0], rules.MANTLE)
        self.assertLessEqual(planks[1] - planks[0], rules.MANTLE)
        climbs = galley["climbs"]
        self.assertTrue(any(c[1] + c[4] / 2.0 >= planks[1] - 0.1 and c[1] - c[4] / 2.0 <= 0.1 for c in climbs))

    def test_small_dressing_stops_nobody_but_the_big_does(self):
        for name in ("net_hung", "rope_coil", "basket_fish", "lobster_pots"):
            self.assertEqual(kit_recipes.PIECES[name]["cols"], [], name)

        for name in ("crate_stack", "barrel_row", "cargo_bales", "anchor_big"):
            self.assertTrue(kit_recipes.PIECES[name]["cols"], name)


class Ships(unittest.TestCase):
    def test_budgets(self):
        pieces = family("ship")
        self.assertGreaterEqual(len(pieces), 6)

        for name, recipe in pieces.items():
            self.assertLessEqual(tris(recipe), recipe.get("budget", kit_shapes.PIECE_TRIS), name)

    def test_the_carrack_shrouds_reach_the_top(self):
        rig = kit_recipes.PIECES["carrack_rig"]
        top = max(top_of(c) for c in rig["cols"] if c[3] >= 2.0 and c[5] >= 2.0)
        self.assertAlmostEqual(top, 20.0, places=2)
        # Both sides: from the main deck to a mantle under the top.
        up = [c for c in rig["climbs"] if c[1] - c[4] / 2.0 <= 2.0 + 0.3 and c[1] + c[4] / 2.0 >= top - rules.MANTLE]
        self.assertEqual(len(up), 2)

    def test_the_top_is_a_floor(self):
        rig = kit_recipes.PIECES["carrack_rig"]
        floors = [c for c in rig["cols"] if abs(top_of(c) - 20.0) < 1e-3]
        self.assertTrue(floors)
        self.assertGreaterEqual(min(floors[0][3], floors[0][5]), 2.0)

    def test_decks_meet_their_bulwarks(self):
        cols = kit_recipes.PIECES["carrack_hull"]["cols"]
        self.assertTrue(any(abs(top_of(c) - 2.0) < 1e-3 and c[3] > 10.0 for c in cols))
        self.assertTrue(any(abs(top_of(c) - 3.0) < 1e-3 and c[4] <= 1.05 for c in cols))
        self.assertTrue(any(abs(top_of(c) - 6.5) < 1e-3 for c in cols))
        self.assertTrue(any(abs(top_of(c) - 5.0) < 1e-3 for c in cols))

    def test_the_cabin_door(self):
        door = kit_recipes.PIECES["carrack_hull"]["door"]
        self.assertGreaterEqual(door[0], 1.2)
        self.assertGreaterEqual(door[1], 2.0)

    def test_the_mainyard_is_a_beam_to_walk(self):
        cols = kit_recipes.PIECES["carrack_mainyard"]["cols"]
        self.assertEqual(len(cols), 1)
        self.assertGreaterEqual(cols[0][3], 20.0)
        self.assertLessEqual(cols[0][5], 0.5)

    def test_ladders_up_the_castles(self):
        hull = kit_recipes.PIECES["carrack_hull"]
        tops = sorted(round(c[1] + c[4] / 2.0, 1) for c in hull["climbs"])
        self.assertTrue(any(t >= 5.0 for t in tops) and any(t >= 6.5 for t in tops))

    def test_bulwarks_are_seen_from_the_deck(self):
        # Over the main deck the ship's sides are drawn inward as well: from
        # its deck nobody sees through them to the sea.
        part = kit_shapes.build(kit_recipes.PIECES["carrack_hull"]["shapes"])
        inward = 0

        for indices, _, _ in part["faces"]:
            points = [part["verts"][i] for i in indices]
            middle = [sum(p[c] for p in points) / len(points) for c in range(3)]
            n = kit_shapes._normal(points)

            if middle[1] > 2.2 and abs(middle[2]) > 2.5 and n[2] * middle[2] < 0.0 and abs(n[1]) < 0.5 * abs(n[2]):
                inward += 1

        self.assertGreaterEqual(inward, 12)

    def test_the_boats_can_be_stood_in(self):
        for name in ("rowboat", "boat_fishing"):
            cols = kit_recipes.PIECES[name]["cols"]
            self.assertTrue(any(c[4] <= 0.2 and c[3] >= 2.0 for c in cols), name)


PLANTS = ["palm_date", "cypress", "orange_tree", "agave"]
MASSING = ["mass_houses_20", "mass_houses_tall_20", "mass_terrace_wall_40", "mass_cathedral", "mass_belltower", "mass_palace", "mass_mirador",
           "mass_aqueduct_40", "mass_bridge", "mass_curtain_30", "mass_castle_tower", "mass_keep"]


class PlantingAndMassing(unittest.TestCase):
    def test_budgets(self):
        for name in PLANTS + MASSING:
            recipe = kit_recipes.PIECES[name]
            self.assertLessEqual(tris(recipe), recipe.get("budget", kit_shapes.PIECE_TRIS), name)

    def test_massing_is_its_own_family_and_low(self):
        for name in MASSING:
            recipe = kit_recipes.PIECES[name]
            self.assertEqual(recipe["family"], "massing", name)
            self.assertLessEqual(tris(recipe), 900, name)
            self.assertTrue(recipe["cols"], name)

    def test_massing_casts_no_shadow(self):
        pieces = [{"name": "keep.001", "piece": "mass_keep"}, {"name": "quay.001", "piece": "quay_8"}]
        self.assertEqual(kit_recipes.shadowless(pieces), ["keep.001"])

    def test_the_keep_is_the_crown(self):
        part = kit_shapes.build(kit_recipes.PIECES["mass_keep"]["shapes"])
        self.assertAlmostEqual(100.0 + max(v[1] for v in part["verts"]), 155.0, delta=0.6)

    def test_the_belltower_reaches_its_height(self):
        part = kit_shapes.build(kit_recipes.PIECES["mass_belltower"]["shapes"])
        self.assertAlmostEqual(45.0 + max(v[1] for v in part["verts"]), 140.0, delta=1.0)

    def test_trees_stand_on_their_trunks_and_plants_stop_nobody(self):
        for name in ("palm_date", "cypress", "orange_tree"):
            self.assertTrue(kit_recipes.PIECES[name]["cols"], name)

        self.assertEqual(kit_recipes.PIECES["agave"]["cols"], [])


if __name__ == "__main__":
    unittest.main(verbosity=1)
