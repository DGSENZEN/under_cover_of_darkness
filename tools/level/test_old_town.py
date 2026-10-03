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

import math  # noqa: E402

import geo  # noqa: E402
import kit_porto  # noqa: E402
import kit_recipes  # noqa: E402
import kit_terrace  # noqa: E402
import kit_town  # noqa: E402
import old_town  # noqa: E402
import old_town as town_layout  # noqa: E402
import rules  # noqa: E402
import town  # noqa: E402
from town import baixa  # noqa: E402
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

    def test_the_ground_meets_the_massings_rock(self):
        # (The rock leaves the old town's footprint on its own grid lines:
        # the old town's ground reaches them, no crack between; the harbour
        # stands in the footprint's south-east corner.)
        import city_massing
        x0, z0, x1, z1 = city_massing.OLD_TOWN
        edge = [(x1 - 0.5, z0 + 0.5 + k) for k in range(int(-73.2 - z0))] + [(x0 + 0.5 + k, z0 + 0.5) for k in range(int(x1 - x0) - 1)]
        edge += [(x0 + 0.5, z0 + 0.5 + k) for k in range(int(z1 - z0) - 1)]
        gaps = [(x, z) for x, z in edge if town.height(x, z) <= town.HOLE + 1.0]
        self.assertEqual(gaps[:5], [], len(gaps))

    def test_every_lot_is_as_wide_as_its_house(self):
        # (Lots are laid side by side by their widths: a house wider or
        # narrower than its lot overlaps its neighbour or leaves a slit.)
        # (The house's own width, not its balconies' reach.)
        for each in town.all_lots():
            call, args = kit_town._family_args(each)
            self.assertAlmostEqual(call(**args)["size"][0], each.width, delta=0.01, msg=each.name)


# The Baixa (plan B1a, Task 14)

def pieces_in(box, prefix=""):
    """The layout's pieces whose piece name starts with prefix, inside the
    box (x0, z0, x1, z1)."""
    return [p for p in layout()["pieces"] if p["piece"].startswith(prefix) and town.inside(p["position"][0], p["position"][2], (box[0], box[2], box[1], box[3]))]


def markers_named(prefix, ucd=None):
    return [m for m in layout()["markers"] if m["name"].startswith(prefix) and (ucd is None or m["ucd"] == ucd)]


def across(boxes, x, y, z):
    """How wide a street is at (x, z), y up: from wall to wall along x."""
    out = 0.0

    for sign in (-1.0, 1.0):
        hits = [t for t in (box.ray([x, y, z], [sign, 0.0, 0.0]) for box in boxes) if t is not None]
        out += min(hits) if hits else 1000.0

    return out


def routes(prefix):
    """The route checks of every route named prefix..., in order: {route: [marker]}."""
    out = {}

    for m in layout()["markers"]:
        if m["ucd"] == "route_check" and m["props"]["route"].startswith(prefix):
            out.setdefault(m["props"]["route"], []).append(m)

    for points in out.values():
        points.sort(key=lambda m: int(m["props"]["order"]))

    return out


def overlap(a, b):
    """The area two rectangles (x0, z0, x1, z1) share."""
    return max(0.0, min(a[2], b[2]) - max(a[0], b[0])) * max(0.0, min(a[3], b[3]) - max(a[1], b[1]))


class Baixa(unittest.TestCase):
    def test_the_main_street_is_13_2(self):
        # Front to front over the shop doors, all along its blocks from the Sea
        # Gate's square to the Rossio; the east secondary 8.8.
        boxes = rules.colliders(layout())
        # (Over the shops' doors, under the balconies.)
        y = baixa.GROUND + 3.5
        main = (baixa.MAIN[0] + baixa.MAIN[1]) / 2.0
        east = (baixa.EAST[0] + baixa.EAST[1]) / 2.0
        self.assertAlmostEqual(main, town_layout.GATES["sea_gate"][0][0])
        north, south = baixa.ROSSIO[3], baixa.SEA_GATE_SQUARE[1]

        for k in range(1, 10):
            z = south + (north - south) * k / 10.0
            self.assertAlmostEqual(across(boxes, main, y, z), 13.2, delta=0.05, msg=z)
            self.assertAlmostEqual(across(boxes, east, y, z), 8.8, delta=0.05, msg=z)

    def test_blocks_are_about_70_by_25(self):
        # Each block 25-27 m across and 45-72 long (the longest about 70),
        # tiled by its lots: none out of it, none over another, no gap.
        lengths = []

        for name, block in baixa.BLOCKS.items():
            x0, z0, x1, z1 = block
            self.assertTrue(25.0 <= x1 - x0 <= 27.0, name)
            self.assertTrue(45.0 <= z1 - z0 <= 72.0, name)
            lengths.append(z1 - z0)
            lots = [each for each in baixa.LOTS if town.inside(each.x, each.z, (x0 - 0.01, x1 + 0.01, z0 - 0.01, z1 + 0.01))]
            rects = [town._rect(each) for each in lots]

            for each, r in zip(lots, rects):
                self.assertTrue(r[0] >= x0 - 0.01 and r[2] <= x1 + 0.01 and r[1] >= z0 - 0.01 and r[3] <= z1 + 0.01, each.name)

            for i, a in enumerate(rects):
                for b in rects[i + 1:]:
                    self.assertLess(overlap(a, b), 0.01, (name, a, b))

            self.assertAlmostEqual(sum((r[2] - r[0]) * (r[3] - r[1]) for r in rects), (x1 - x0) * (z1 - z0), delta=0.5, msg=name)

        self.assertTrue(any(68.0 <= n <= 72.0 for n in lengths), lengths)

    def test_fire_walls_every_2_to_6(self):
        # Down each long front, the runs between fire walls (and the
        # front's ends) are 2-6 buildings; a fire wall stands only on a
        # gabled building (corners are four-pitched, mansards have none).
        lots = {each.name: each for each in baixa.LOTS}

        for block, face, names in baixa.ROWS:
            row = [lots[n] for n in names]
            run, runs = 1, []

            for a, b in zip(row, row[1:]):
                if dict(a.params).get("fire_walls", (False, False))[1] or dict(b.params).get("fire_walls", (False, False))[0]:
                    runs.append(run)
                    run = 1
                else:
                    run += 1

            runs.append(run)
            self.assertTrue(len(runs) >= 2, (block, face, runs))
            self.assertTrue(all(2 <= n <= 6 for n in runs), (block, face, runs))

            for each in row:
                if any(dict(each.params).get("fire_walls", (False, False))):
                    self.assertNotEqual(dict(each.params).get("kind"), "corner", each.name)
                    self.assertNotEqual(each.quirk, "mansard", each.name)

    def test_neighbours_read_as_two_buildings(self):
        # (Two houses side by side on a street in one cladding run together
        # into one front: down each row, and the two corners meeting on a
        # block's short face, they differ.)
        lots = {each.name: each for each in baixa.LOTS}
        front = {name: dict(each.params)["front"] for name, each in lots.items()}

        for block, face, names in baixa.ROWS:
            for a, b in zip(names, names[1:]):
                self.assertNotEqual(front[a], front[b], (a, b))
                self.assertFalse(lots[a].quirk == lots[b].quirk == "mansard", (a, b))

        for block in baixa.BLOCKS:
            east = [n for b, f, n in baixa.ROWS if b == block and f == "e"][0]
            west = [n for b, f, n in baixa.ROWS if b == block and f == "w"][0]
            # (South face: the east row's first and the west row's last;
            # north face: the east row's last and the west row's first.)
            self.assertNotEqual(front[east[0]], front[west[-1]], block)
            self.assertNotEqual(front[east[-1]], front[west[0]], block)

    def test_the_sewer_runs_under_the_main_street_with_two_hatches(self):
        main = (baixa.MAIN[0] + baixa.MAIN[1]) / 2.0
        street = (baixa.MAIN[0], baixa.SEA_GATE_SQUARE[1] - 60.0, baixa.MAIN[1], baixa.SEA_GATE_SQUARE[3])
        vaults = pieces_in(street, "vault_22_31_")
        self.assertTrue(vaults)
        reach = []

        for p in vaults:
            recipe = kit_recipes.PIECES[p["piece"]]
            # (Off the axis by its hatches' cells: its 3 m wholly under the
            # street's 13.2.)
            self.assertAlmostEqual(p["position"][0], main, delta=1.0)
            # (Its barrel's top under the street.)
            self.assertLess(p["position"][1] + recipe["size"][1], baixa.GROUND)
            reach += [p["position"][2] - recipe["size"][2] / 2.0, p["position"][2] + recipe["size"][2] / 2.0]

        self.assertLessEqual(min(reach), baixa.ROSSIO[3] + 6.0)
        self.assertGreaterEqual(max(reach), baixa.SEA_GATE_SQUARE[1] - 6.0)
        self.assertEqual(len(pieces_in(street, "grate_hatch_")), 2)
        below = routes("below_baixa_")
        self.assertEqual(len(below), 2)

        for points in below.values():
            self.assertEqual(points[0]["props"]["way"], "below")
            self.assertIn("climb", [m["props"]["move"] for m in points])
            self.assertLess(points[-1]["position"][1], baixa.GROUND - 3.0)

    def test_a_hatch_takes_one_cell_of_the_street(self):
        # (Its collar paves the one cell of ground cut round it, flush with
        # the street: no wide pale square, no lip.)
        ground = rules.ground_of(layout())
        hatches = pieces_in((-100.0, -170.0, 15.0, -73.0), "grate_hatch_")

        for p in hatches:
            x, y, z = p["position"]
            self.assertEqual(ground.heights(x, z), [], p["name"])

            for dx, dz in ((1.4, 0.0), (-1.4, 0.0), (0.0, 1.4), (0.0, -1.4)):
                self.assertTrue(ground.heights(x + dx, z + dz), (p["name"], dx, dz))

            # (Its paving one cell: the grate leans aside past it.)
            recipe = kit_recipes.PIECES[p["piece"]]
            self.assertLessEqual(max(abs(c[0]) + c[3] / 2.0 for c in recipe["cols"] if not any(c[7:10])), 1.26)

        self.assertEqual(len(hatches), 2)
        self.assertEqual(kit_terrace.COLLAR_PROUD, 0.0)

    def test_a_marker_in_the_sewer_is_not_buried(self):
        found = rules.problems(layout(), "stage2")
        self.assertEqual([p for p in found if "under the ground" in p and "below_baixa" in p], [])

    def test_the_sea_gate_arrival_stands_on_the_square(self):
        arrival = markers_named("from_harbour_sea_gate")[0]
        x, y, z = arrival["position"]
        x0, z0, x1, z1 = baixa.SEA_GATE_SQUARE
        self.assertTrue(x0 + 4.0 <= x <= x1 - 4.0 and z0 + 4.0 <= z <= z1 - 4.0, (x, z))
        self.assertAlmostEqual(y, baixa.GROUND)
        boxes = rules.colliders(layout())

        # (Open round him: nothing at a man's height within 4 m.)
        for k in range(16):
            a = math.radians(k * 22.5)

            for r in (1.0, 2.5, 4.0):
                p = [x + math.cos(a) * r, y + 1.2, z + math.sin(a) * r]
                self.assertFalse(any(box.contains(p) for box in boxes), p)

    def test_the_way_back_through_the_sea_gate_is_floored(self):
        # (From the arrival on the square through the passage to the exit
        # back to the harbour: the passage's floor is the old town's to lay,
        # the harbour's own is not shared.)
        way = routes("sea_gate_way")["sea_gate_way"]
        self.assertAlmostEqual(way[0]["position"][2], markers_named("from_harbour_sea_gate")[0]["position"][2], delta=0.5)
        exit_z = markers_named("to_harbour_sea_gate")[0]["position"][2]
        self.assertLess(abs(way[-1]["position"][2] - exit_z), 2.0)
        self.assertEqual([p for p in rules.problems(layout(), "stage2") if "sea_gate_way" in p], [])
        boxes, ground = rules.colliders(layout()), rules.ground_of(layout())

        for k in range(40):
            z = -72.5 - k * 0.5
            self.assertIsNotNone(rules.floor_under(boxes, [-55.0, baixa.GROUND, z], ground), z)

    def test_the_baixa_roofs_chain(self):
        # 2-3 roof chains, each on the roofs of 3-6 houses over 25-60 m, up
        # a ladder from the street (the watch's way up, in sight).
        chains = routes("roof_baixa_")
        self.assertTrue(2 <= len(chains) <= 3, sorted(chains))
        rects = [(each.name, town._rect(each)) for each in baixa.LOTS]

        for route, points in chains.items():
            self.assertEqual(points[0]["props"]["way"], "roof", route)
            first = points[0]["position"]
            self.assertAlmostEqual(first[1], town.height(first[0], first[2]), delta=0.05, msg=route)
            self.assertIn("climb", [m["props"]["move"] for m in points[:6]], route)
            high = [m["position"] for m in points if m["position"][1] > baixa.GROUND + 12.0]
            houses = {name for name, r in rects for p in high if r[0] <= p[0] <= r[2] and r[1] <= p[2] <= r[3]}
            self.assertTrue(3 <= len(houses) <= 6, (route, sorted(houses)))
            span = max(math.hypot(a[0] - b[0], a[2] - b[2]) for a in high for b in high)
            self.assertTrue(25.0 <= span <= 60.0, (route, span))

    def test_the_lanes_are_lamp_lit(self):
        # The main street and the secondaries: a lamp at least every 40 m
        # from the Sea Gate's square to the Rossio, each lamp's two
        # lanterns lit on dark nights only.
        lamps = pieces_in((-100.0, -170.0, 15.0, -73.0), "corner_lamp")
        lights = markers_named("baixa_lamp_", "light")
        self.assertEqual(len(lights), 2 * len(lamps))
        self.assertTrue(all(m["props"]["dark_only"] for m in lights))

        for lane in (baixa.MAIN, baixa.EAST, baixa.WEST):
            zs = sorted([p["position"][2] for p in lamps if lane[0] - 0.5 <= p["position"][0] <= lane[1] + 0.5] +
                        [baixa.ROSSIO[3] + 10.0, baixa.SEA_GATE_SQUARE[1] - 10.0])
            self.assertTrue(len(zs) >= 3, lane)
            self.assertTrue(all(b - a <= 40.0 for a, b in zip(zs, zs[1:])), (lane, zs))

    def test_the_rossio_has_its_fountain(self):
        fountains = pieces_in(baixa.ROSSIO, "fountain_bowls")
        self.assertEqual(len(fountains), 1)
        self.assertAlmostEqual(fountains[0]["position"][0], (baixa.MAIN[0] + baixa.MAIN[1]) / 2.0, delta=0.5)
        # (Level ground under its whole platform: no step buried uphill or
        # floating downhill.)
        x, y, z = fountains[0]["position"]
        reach = kit_recipes.PIECES["fountain_bowls"]["size"][0] / 2.0

        for dx, dz in ((reach, 0.0), (-reach, 0.0), (0.0, reach), (0.0, -reach)):
            self.assertAlmostEqual(town.height(x + dx, z + dz), y, delta=0.03, msg=(dx, dz))

        noise = markers_named("baixa_fountain", "noise_zone")
        self.assertEqual(len(noise), 1)
        self.assertLess(math.hypot(noise[0]["position"][0] - fountains[0]["position"][0], noise[0]["position"][2] - fountains[0]["position"][2]), 0.5)

    def test_the_comet_is_inside_the_sea_gate(self):
        self.assertEqual(len(pieces_in((-58.0, -91.0, -52.0, -75.0), "panel_comet")), 1)

    def test_the_trades_are_marked_by_street(self):
        for name, lane in (("trade_gold", baixa.WEST), ("trade_cloth", baixa.MAIN), ("trade_silver", baixa.EAST)):
            found = markers_named(name, "mark")
            self.assertEqual(len(found), 1, name)
            self.assertTrue(lane[0] <= found[0]["position"][0] <= lane[1], name)

    def test_the_squares_have_their_vantages(self):
        # (Unlit, high over the square's mouth: a scout's spot.)
        lights = [m["position"] for m in layout()["markers"] if m["ucd"] == "light"]

        for square in (baixa.SEA_GATE_SQUARE, baixa.ROSSIO):
            x0, z0, x1, z1 = square
            near = [m["position"] for m in markers_named("baixa_vantage", "vantage")
                    if x0 - 20.0 <= m["position"][0] <= x1 + 20.0 and z0 - 20.0 <= m["position"][2] <= z1 + 20.0]
            self.assertTrue(any(p[1] >= baixa.GROUND + 6.0 and all(math.dist(p, q) > 8.0 for q in lights) for p in near), square)

    def test_the_baixa_is_outside(self):
        zones = markers_named("zone_baixa", "zone")
        self.assertEqual(len(zones), 1)
        self.assertEqual(zones[0]["props"]["grade"], "outside")

    def test_about_one_house_in_five_or_six_is_entered(self):
        entered = [each for each in baixa.LOTS if each.enterable]
        self.assertTrue(len(baixa.LOTS) / 7.0 <= len(entered) <= len(baixa.LOTS) / 4.0, (len(entered), len(baixa.LOTS)))
        self.assertTrue(all(1 <= each.rooms <= 3 for each in entered))
        self.assertTrue(1 <= sum(each.lived for each in entered) <= len(entered) / 2.0 + 0.5)

    def test_the_bakers_oven_is_kept(self):
        # (A townsfolk's work place, reserved: on the ground floor of a
        # house walked in.)
        work = [m for m in markers_named("baixa_", "work") if m["props"]["kind"] == "baker"]
        self.assertEqual(len(work), 1)
        x, y, z = work[0]["position"]
        homes = [each for each in baixa.LOTS if each.enterable and town._rect(each)[0] <= x <= town._rect(each)[2] and town._rect(each)[1] <= z <= town._rect(each)[3]]
        self.assertEqual(len(homes), 1)
        self.assertAlmostEqual(y, baixa.GROUND, delta=0.1)

    def test_the_baixa_checks_clean(self):
        self.assertGreaterEqual(len(baixa.LOTS), 20)
        self.assertEqual([p for p in rules.problems(layout(), "stage2") if "baixa" in p], [])


if __name__ == "__main__":
    unittest.main()
