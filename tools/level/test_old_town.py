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
from town import judiaria as jud_plan  # noqa: E402
from town import stairs as stairs_plan  # noqa: E402
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

    def test_every_piece_laid_is_in_the_kit(self):
        # (The kit is built in a process of its own, from kit_recipes alone:
        # a piece the layout makes as it runs is missing from it.)
        import subprocess
        code = "import sys; sys.path.insert(0, %r); import kit_recipes; print('\\n'.join(sorted(kit_recipes.PIECES)))" % HERE
        kit = set(subprocess.run([sys.executable, "-c", code], capture_output=True, text=True, check=True).stdout.split())
        laid = {p["piece"] for p in layout()["pieces"]}
        self.assertEqual(sorted(laid - kit), [])

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


# The stairs quarter (plan B1a, Task 15)

def edge_faults(quarter, openings, step=1.0):
    """Where a terrace of `quarter` ends over lower ground (or none) with
    nothing guarding the drop at a man's waist within a metre and a half of
    it, or (over lower ground) no face down it: [(x, z, what)]. Openings:
    boxes (x0, z0, x1, z1) where a stair or a door leads on over the edge."""
    boxes = rules.colliders(layout())
    out = []

    for plate in [t for t in town.TERRACES if t[1] == quarter]:
        _name, _q, x0, z0, x1, z1, ys, yn = plate
        y = (ys + yn) / 2.0

        for (ax, az), (bx, bz), (nx, nz) in (((x0, z1), (x1, z1), (0.0, 1.0)), ((x0, z0), (x1, z0), (0.0, -1.0)),
                                             ((x0, z0), (x0, z1), (-1.0, 0.0)), ((x1, z0), (x1, z1), (1.0, 0.0))):
            length = math.hypot(bx - ax, bz - az)
            n = max(1, int(length / step))

            for i in range(n):
                t = (i + 0.5) / n
                ex, ez = ax + (bx - ax) * t, az + (bz - az) * t

                if any(o[0] <= ex <= o[2] and o[1] <= ez <= o[3] for o in openings):
                    continue

                # (What is underfoot past the edge: the ground there, or
                # anything built, a wall's walk.)
                there = town.height(ex + nx * 0.6, ez + nz * 0.6)
                over = [h for h in (b.ray([ex + nx * 0.6, y + 3.0, ez + nz * 0.6], [0.0, -1.0, 0.0]) for b in boxes) if h is not None]

                if over:
                    there = max(there, y + 3.0 - min(over))

                if there > y - 1.0:
                    continue

                # (Either side of the point by 2 cm: a ray along the face two
                # neighbours' walls share meets neither.)
                hits = []

                for side in (-0.02, 0.02):
                    start = [ex - nx * 1.0 + nz * side, y + 0.7, ez - nz * 1.0 + nx * side]
                    hits += [h for h in (b.ray(start, [nx, 0.0, nz]) for b in boxes) if h is not None]

                if not hits or min(hits) > 1.3:
                    out.append((round(ex, 1), round(ez, 1), "unguarded"))

                if there > town.HOLE + 1.0:
                    mid = [ex + nx * 0.6, (y + there) / 2.0, ez + nz * 0.6]
                    hits = [h for h in (b.ray(mid, [-nx, 0.0, -nz]) for b in boxes) if h is not None]

                    if not hits or min(hits) > 0.9:
                        out.append((round(ex, 1), round(ez, 1), "faceless"))

    return out


def lot_rect(each):
    """A lot's footprint (x0, z0, x1, z1): its front at z, deep behind it
    (yaw 0: to -z; yaw 180: to +z)."""
    if abs(each.yaw - 180.0) < 0.01:
        return (each.x - each.width / 2.0, each.z, each.x + each.width / 2.0, each.z + each.depth)

    return (each.x - each.width / 2.0, each.z - each.depth, each.x + each.width / 2.0, each.z)


def stairs_openings():
    """The stairs quarter's openings over its edges: each stair-lane's head,
    each two-level house's back door (phase 1-2)."""
    out = []

    for step in stairs_plan.STEPS:
        for c in step["gaps"]:
            out.append((c - stairs_plan.GAP / 2.0, step["z"] - 0.6, c + stairs_plan.GAP / 2.0, step["z"] + 0.6))

    for _plate, z, _ground, _quarter in stairs_plan.TOWERS:
        out.append((stairs_plan.EAST - 0.6, z - 0.6, stairs_plan.EAST + 0.6, z + 0.6))

    for lot in stairs_plan.LOTS:
        if lot.quirk == "two_level":
            for d in kit_recipes.PIECES[town.design_key(lot)]["doors"]:
                if d[1] > 0.5:
                    x = lot.x + d[0]
                    out.append((x - 0.9, lot.z - lot.depth - 0.6, x + 0.9, lot.z - lot.depth + 0.6))

    return out


class Stairs(unittest.TestCase):
    def test_its_sectors_are_about_100_m(self):
        for name in ("stairs_lo", "stairs_mid", "stairs_hi"):
            zs = [z for t in town.TERRACES if t[1] == "stairs" for z in (t[3], t[5]) if town.sector_of(-140.0, (t[3] + t[5]) / 2.0) == name]
            self.assertTrue(zs, name)
            self.assertLessEqual(max(zs) - min(zs), 100.0, name)

    def test_each_step_is_climbed_by_two_stair_lanes(self):
        # (Their heads level with the terrace above, on its edge; their feet
        # on the terrace below.)
        lanes = [p for p in layout()["pieces"] if p["piece"].startswith("stair_lane_") and town.quarter_of(p["position"][0], p["position"][2]) == "stairs"]

        for step in stairs_plan.STEPS:
            mine = []

            for p in lanes:
                head = geo.add(p["position"], geo.apply(p["basis"], kit_recipes.PIECES[p["piece"]]["head"]))

                if abs(head[2] - step["z"]) < 0.05:
                    mine.append(p)
                    self.assertAlmostEqual(head[1], step["y"] + step["rise"], delta=0.02)
                    self.assertAlmostEqual(p["position"][1], step["y"], delta=0.02)

            self.assertEqual(len(mine), 2, step["z"])

    def test_each_step_has_a_two_level_house(self):
        # (Its front door on the lane below, its back door on the lane above,
        # on the step's line: a thief's way up through it.)
        for step in stairs_plan.STEPS:
            found = []

            for lot in stairs_plan.LOTS:
                if lot.quirk != "two_level" or abs(lot.z - lot.depth - step["z"]) > 0.05:
                    continue

                doors = kit_recipes.PIECES[town.design_key(lot)]["doors"]
                ys = sorted(lot.y + d[1] for d in doors)
                found.append(ys)

            self.assertEqual(len(found), 1, step["z"])
            self.assertAlmostEqual(found[0][0], step["y"], delta=0.02)
            self.assertAlmostEqual(found[0][-1], step["y"] + step["rise"], delta=0.02)

    def test_the_wall_pieces_are_the_harbours(self):
        import edges
        import city_harbour
        theirs = sorted((round(p["position"][2], 2), round(p["position"][1], 2)) for p in edges.shared_edge(city_harbour.layout())
                        if abs(p["position"][0] - stairs_plan.WALL_X) < 0.01 and p["piece"].startswith("city_wall_12_") and p["position"][2] < -22.0)
        ours = sorted((round(z, 2), round(base, 2)) for z, _length, base in stairs_plan.WALL_PIECES)
        self.assertEqual(ours, theirs)

    def test_the_city_wall_stands_on_its_footing(self):
        # (Where its foot steps up over a terrace, nothing open under it.)
        boxes = rules.colliders(layout())
        # (But the Guindais postern's passage, open into the footing.)
        postern = [p for p in layout()["pieces"] if p["piece"].startswith("postern_")][0]
        door = geo.add(postern["position"], geo.apply(postern["basis"], kit_recipes.PIECES[postern["piece"]]["door"]))

        for z, length, base in stairs_plan.WALL_PIECES:
            ground = min(town.height(-176.0, z + dz) for dz in (-length / 2.0 + 0.2, length / 2.0 - 0.2))

            for k in range(1, 6):
                y = ground + (base - ground) * k / 6.0

                if base - ground > 0.3 and not (abs(z - door[2]) < kit_recipes.DOOR[0] / 2.0 and y < door[1] + kit_recipes.DOOR[1]):
                    self.assertTrue(any(b.contains([stairs_plan.WALL_X, y, z]) for b in boxes), (z, y))

    def test_its_edges_are_walled(self):
        self.assertEqual(edge_faults("stairs", stairs_openings())[:8], [])

    def test_its_lanes_run_clear(self):
        # (Along each terrace's lane at a man's chest, from end to end:
        # nothing in the way.)
        boxes = rules.colliders(layout())

        for plate in stairs_plan.PLATES:
            if not stairs_plan.ROWS[plate[0]]:
                continue

            z = stairs_plan.south(plate) - stairs_plan.LANE / 2.0
            start = [stairs_plan.WEST + 0.6, stairs_plan.level(plate) + 1.2, z]
            hits = [h for h in (b.ray(start, [1.0, 0.0, 0.0]) for b in boxes) if h is not None]
            reach = stairs_plan.east(plate) - stairs_plan.WEST - 1.2
            self.assertTrue(not hits or min(hits) >= reach, (plate[0], min(hits) if hits else None))

    def test_seven_lanes_meet_at_the_fountain(self):
        # (The wall fountain on the square; a way from before it out along
        # each of seven lanes, their mouths on the square's edge 2 m apart
        # at least, each clear at a man's chest all its way.)
        x0, z0, x1, z1 = stairs_plan.SQUARE
        fountains = [p for p in layout()["pieces"] if p["piece"] == "fountain_wall" and x0 <= p["position"][0] <= x1
                     and z0 - 0.5 <= p["position"][2] <= z1]
        self.assertEqual(len(fountains), 1)
        lanes = routes("stairs_square_lane_")
        self.assertEqual(len(lanes), 7)
        boxes = rules.colliders(layout())
        mouths = []

        for name, points in lanes.items():
            self.assertLess(math.dist(points[0]["position"], fountains[0]["position"]), 6.0, name)
            mouth = points[1]["position"]
            self.assertLess(min(abs(mouth[0] - x0), abs(mouth[0] - x1), abs(mouth[2] - z0), abs(mouth[2] - z1)), 0.4, name)
            mouths.append(mouth)

            for a, b in zip(points, points[1:]):
                pa = geo.add(a["position"], [0.0, 1.5, 0.0])
                pb = geo.add(b["position"], [0.0, 1.5, 0.0])
                length = math.dist(pa, pb)
                d = [(pb[i] - pa[i]) / length for i in range(3)]
                hits = [t for t in (box.ray(pa, d) for box in boxes) if t is not None and t < length]
                self.assertEqual(hits, [], (name, a["name"]))

        for i, a in enumerate(mouths):
            for b in mouths[i + 1:]:
                self.assertGreater(math.hypot(a[0] - b[0], a[2] - b[2]), 2.0)

    def test_the_stream_is_vaulted_with_houses_on_it(self):
        # (From a grating in the Ribeira wall north under the bottom three
        # terraces, 3 m under each, unbroken; walled at both ends; houses
        # over it; the tavern's cellar door opening onto it.)
        parts = [p for p in layout()["pieces"] if p["name"].startswith("stairs_stream_")]
        ends = [p for p in parts if p["piece"].startswith("vault_end_")]
        chain = sorted([p for p in parts if p not in ends], key=lambda p: -p["position"][2])
        self.assertEqual(len(ends), 2)
        spans = []

        levels = [stairs_plan.level(t) - stairs_plan.STREAM_DEPTH for t in stairs_plan.PLATES]
        floor = None

        for p in chain:
            self.assertAlmostEqual(p["position"][0], stairs_plan.STREAM_X, delta=0.01)
            recipe = kit_recipes.PIECES[p["piece"]]
            length = recipe["size"][2]
            spans.append((p["position"][2] - length / 2.0, p["position"][2] + length / 2.0))
            # (Each floor a terrace's level less STREAM_DEPTH, on from the one
            # before, up a cascade's drop.)
            y = p["position"][1]
            self.assertTrue(any(abs(y - level) < 0.01 for level in levels), p["name"])

            if floor is not None:
                self.assertAlmostEqual(y, floor, delta=0.01, msg=p["name"])

            drop = recipe["tour"][-1][1] if p["piece"].startswith("cascade_") else 0.0
            floor = y + drop
            # (Under the ground all its length, a hand's breadth of it over
            # its roof.)
            top = y + drop + stairs_plan.STREAM_SIZE[1] + 0.3

            for z in (spans[-1][0] + 0.05, p["position"][2], spans[-1][1] - 0.05):
                self.assertLessEqual(top, town.height(p["position"][0], z) - 0.25 + 0.01, (p["name"], z))

        self.assertAlmostEqual(spans[0][1], stairs_plan.RIBEIRA, delta=0.05)

        for (a0, _a1), (_b0, b1) in zip(spans, spans[1:]):
            self.assertAlmostEqual(a0, b1, delta=0.05)

        tips = sorted(e["position"][2] for e in ends)
        self.assertLess(abs(tips[0] - spans[-1][0]), 0.3)
        self.assertLess(abs(tips[1] - spans[0][1]), 0.3)
        # (Half its length and more under houses and the tavern's yard, a
        # house over it on each terrace it runs under.)
        over = [lot_rect(each) for each in stairs_plan.LOTS if lot_rect(each)[0] < stairs_plan.STREAM_X < lot_rect(each)[2]]
        tx, tz, _yaw = stairs_plan.TAVERN
        depth, width = stairs_plan.TAVERN_SIZE
        yard = (tx - depth - 6.0, tz - width / 2.0, tx - depth, tz + width / 2.0)
        self.assertTrue(yard[0] < stairs_plan.STREAM_X < yard[2])
        covered = sorted((max(r[1], spans[-1][0]), min(r[3], spans[0][1])) for r in over + [yard])
        length, end = 0.0, spans[-1][0]

        for a, b in covered:
            a = max(a, end)

            if b > a:
                length += b - a
                end = b

        self.assertGreater(length, (spans[0][1] - spans[-1][0]) / 2.0)

        for plate in stairs_plan.PLATES[:3]:
            self.assertTrue(any(r[1] < plate[5] and r[3] > plate[3] for r in over), plate[0])
        tavern = [p for p in layout()["pieces"] if p["piece"] == "tavern"][0]
        door = [geo.add(tavern["position"], geo.apply(tavern["basis"], d[0:3])) for d in kit_recipes.PIECES["tavern"]["doors"] if d[1] < -1.0][0]
        chamber = [p for p in chain if "_door" in p["piece"]][0]
        theirs = geo.add(chamber["position"], geo.apply(chamber["basis"], kit_recipes.PIECES[chamber["piece"]]["door"][0:3]))
        self.assertLess(math.dist(door, theirs), 0.5)

    def test_the_tavern_is_entered_four_ways(self):
        house = [m for m in layout()["markers"] if m["ucd"] == "household" and m["props"]["label"] == "tavern"]
        self.assertEqual(len(house), 1)
        self.assertEqual(int(house[0]["props"]["ways"]), 4)
        kinds = {points[0]["props"]["kind"] for points in routes("stairs_tavern_way_").values() if points[0]["props"].get("into") == "tavern"}
        self.assertEqual(kinds, {"door", "yard", "window", "below"})
        self.assertEqual([p for p in rules.way_problems(layout()) if "tavern" in p], [])
        self.assertEqual(len(markers_named("stairs_tavern_seat_", "seat")), 12)
        tavern = [p for p in layout()["pieces"] if p["piece"] == "tavern"][0]
        self.assertEqual(town.quarter_of(tavern["position"][0], tavern["position"][2]), "stairs")

    def test_two_level_houses_join_terraces(self):
        # (A thief's way through each: in at its front door off the lane
        # below, up its stair, out at its back door onto the lane above.)
        for each in stairs_plan.LOTS:
            if each.quirk != "two_level":
                continue

            points = routes("stairs_through_%s" % each.name).get("stairs_through_%s" % each.name)
            self.assertTrue(points, each.name)
            first, last = points[0], points[-1]
            self.assertEqual(first["props"]["way"], "thief")
            self.assertAlmostEqual(first["position"][1], each.y, delta=0.05)
            self.assertGreater(first["position"][2], each.z)
            step = [st for st in stairs_plan.STEPS if abs(st["z"] - (each.z - each.depth)) < 0.05][0]
            self.assertAlmostEqual(last["position"][1], step["y"] + step["rise"], delta=0.05)
            self.assertLess(last["position"][2], step["z"])

    def test_the_undercroft_is_sealed(self):
        # (The tavern cellar's barred door: a way to the undercroft, sealed
        # until it is built, about where the spec puts it.)
        exits = [m for m in layout()["markers"] if m["ucd"] == "exit" and m["props"].get("to") == "undercroft"]
        self.assertEqual(len(exits), 1)
        self.assertIn("sealed", exits[0]["props"]["label"])
        tavern = [p for p in layout()["pieces"] if p["piece"] == "tavern"][0]
        door = geo.add(tavern["position"], geo.apply(tavern["basis"], kit_recipes.PIECES["tavern"]["places"]["undercroft_door"]))
        self.assertLess(math.dist(exits[0]["position"], door), 1.5)
        self.assertLess(math.hypot(door[0] + 140.0, door[2] + 60.0), 8.0)

    def test_the_guindais_gate_opens_into_its_postern(self):
        # (The way back to the harbour's Guindais stair: through a postern
        # in the city wall's footing, its gate open, dark beyond.)
        posterns = [p for p in layout()["pieces"] if p["piece"].startswith("postern_")]
        self.assertEqual(len(posterns), 1)
        p = posterns[0]
        mouth = geo.add(p["position"], geo.apply(p["basis"], kit_recipes.PIECES[p["piece"]]["door"]))
        out = markers_named("to_harbour_guindais", "exit")[0]
        box = geo.Box(out["position"], out["basis"], out["size"])
        self.assertTrue(box.contains(geo.add(mouth, [0.3, 1.0, 0.0])))

    def test_the_west_wall_is_climbed_from_the_first_lane(self):
        points = routes("stairs_west_wall").get("stairs_west_wall")
        self.assertTrue(points)
        first, last = points[0]["position"], points[-1]["position"]
        lane = stairs_plan.PLATES[0]
        self.assertAlmostEqual(first[1], stairs_plan.level(lane), delta=0.05)
        self.assertTrue(stairs_plan.south(lane) - stairs_plan.LANE <= first[2] <= stairs_plan.south(lane))
        self.assertLess(abs(last[0] - stairs_plan.WALL_X), 1.0)
        walk = [base + 12.0 for mid, length, base in stairs_plan.WALL_PIECES if mid - length / 2.0 <= last[2] <= mid + length / 2.0]
        self.assertAlmostEqual(last[1], walk[0], delta=0.05)

    def test_the_tannery_is_kept_for_its_tanners(self):
        works = [m for m in layout()["markers"] if m["ucd"] == "work" and m["props"].get("kind") == "tannery"]
        self.assertEqual(len(works), 1)
        x0, z0, x1, z1 = stairs_plan.TANNERY
        self.assertTrue(x0 < works[0]["position"][0] < x1 and z0 < works[0]["position"][2] < z1)
        self.assertEqual(town.quarter_of(works[0]["position"][0], works[0]["position"][2]), "stairs")

    def test_the_slot_house_and_the_bricked_alley_are_secrets(self):
        secrets = [m for m in layout()["markers"] if m["ucd"] == "secret"]
        slots = [each for each in stairs_plan.LOTS if each.quirk == "slot"]
        self.assertEqual(len(slots), 1)
        a = lot_rect(slots[0])
        middle = [(a[0] + a[2]) / 2.0, slots[0].y + 1.5, (a[1] + a[3]) / 2.0]
        self.assertTrue(any(geo.Box(m["position"], m["basis"], m["size"]).contains(middle) for m in secrets))
        x0, z0, x1, z1 = stairs_plan.ALLEY
        y = stairs_plan.level([t for t in stairs_plan.PLATES if t[0] == "stairs_4"][0])
        inside = [(x0 + x1) / 2.0, y + 1.5, (z0 + z1) / 2.0]
        self.assertTrue(any(geo.Box(m["position"], m["basis"], m["size"]).contains(inside) for m in secrets))
        boxes = rules.colliders(layout())
        hits = [t for t in (b.ray([(x0 + x1) / 2.0, y + 1.5, z1 + 1.0], [0.0, 0.0, -1.0]) for b in boxes) if t is not None]
        self.assertTrue(hits and min(hits) < 1.5)

    def test_the_baixa_and_the_carmo_are_climbed_from_the_stairs(self):
        # (Each boundary step: two stair towers up its cliff, public; corbels
        # beside one of them, a thief's; each way from the lower quarter's
        # ground up to a terrace of the stairs.)
        found = {}

        for points in routes("stairs_").values():
            props = points[0]["props"]

            if props.get("step") in ("stairs_step_baixa", "stairs_step_carmo"):
                found.setdefault(props["step"], []).append(points)

        for step, low, quarter in (("stairs_step_baixa", 2.5, "baixa"), ("stairs_step_carmo", 28.0, "carmo")):
            ways = found.get(step, [])
            self.assertEqual(sorted(w[0]["props"]["way"] for w in ways), ["public", "public", "thief"], step)

            for points in ways:
                first, last = points[0]["position"], points[-1]["position"]
                self.assertAlmostEqual(first[1], low, delta=0.05)
                self.assertEqual(town.quarter_of(first[0], first[2]), quarter)
                self.assertEqual(town.quarter_of(last[0], last[2]), "stairs")
                self.assertTrue(any(abs(last[1] - stairs_plan.level(t)) < 0.05 for t in stairs_plan.PLATES))

    def test_each_tower_opens_at_its_terrace(self):
        # (Its top door where the plan puts it, on its terrace's edge.)
        towers = sorted((p for p in layout()["pieces"] if p["piece"].startswith("stair_tower_") and p["name"].startswith("stairs_")),
                        key=lambda p: -p["position"][2])
        self.assertEqual(len(towers), len(stairs_plan.TOWERS))

        for p, (plate, top_z, _ground, _quarter) in zip(towers, stairs_plan.TOWERS):
            door = geo.add(p["position"], geo.apply(p["basis"], kit_recipes.PIECES[p["piece"]]["doors"][1]))
            self.assertAlmostEqual(door[2], top_z, delta=0.05)
            self.assertAlmostEqual(door[1], stairs_plan.level([t for t in stairs_plan.PLATES if t[0] == plate][0]), delta=0.05)
            self.assertLess(abs(door[0] - stairs_plan.EAST), 0.6)

    def test_each_step_is_crossed_publicly_and_by_a_thief(self):
        labels = {m["props"]["label"] for m in layout()["markers"] if m["ucd"] == "terrace_step" and m["props"]["label"].startswith("stairs_step_")}
        self.assertEqual(labels, {"stairs_step_%d" % (k + 1) for k in range(len(stairs_plan.STEPS))} | {"stairs_step_baixa", "stairs_step_carmo"})
        self.assertEqual([p for p in rules.way_problems(layout()) if "stairs_step_" in p], [])

    def test_the_lanes_are_torch_lit(self):
        # (Torches on the fronts along each terrace's lane, 40 m apart at
        # most and 20 m from its ends; each one the player can douse.)
        torches = [m for m in layout()["markers"] if m["ucd"] == "light" and m["props"]["kind"] == "torch" and m["name"].startswith("stairs_")]
        self.assertTrue(all(m["props"].get("douse", True) for m in torches))

        for plate in stairs_plan.PLATES:
            z1 = stairs_plan.south(plate)
            xs = sorted(m["position"][0] for m in torches if z1 - stairs_plan.LANE - 1.0 <= m["position"][2] <= z1 + 0.5
                        and abs(m["position"][1] - stairs_plan.level(plate) - 2.6) < 0.5)
            self.assertTrue(xs, plate[0])
            self.assertLessEqual(xs[0] - stairs_plan.WEST, 20.0, plate[0])
            self.assertLessEqual(stairs_plan.EAST - xs[-1], 20.0, plate[0])
            self.assertTrue(all(b - a <= 40.0 for a, b in zip(xs, xs[1:])), (plate[0], xs))

    def test_the_stairs_have_their_vantages(self):
        # (At each stair-lane's head, at each terrace's east end, on the
        # bastion and the miradouro: unlit.)
        vantages = [m["position"] for m in layout()["markers"] if m["ucd"] == "vantage" and m["name"].startswith("stairs_")]
        lights = [m["position"] for m in layout()["markers"] if m["ucd"] == "light"]

        def near(point, reach):
            return any(math.dist(v, point) <= reach for v in vantages)

        for w in stairs_plan.WALLS["stair"]:
            name = getattr(kit_terrace, w["kind"])(*w["args"])
            head = geo.add(list(w["at"]), geo.apply(geo.rotation(w["yaw"]), kit_recipes.PIECES[name]["head"]))
            self.assertTrue(near(head, 3.0), head)

        for plate in stairs_plan.PLATES:
            self.assertTrue(near([stairs_plan.EAST - 1.0, stairs_plan.level(plate), stairs_plan.south(plate) - stairs_plan.LANE / 2.0], 3.0), plate[0])

        for v in vantages:
            self.assertFalse(any(math.dist(v, light) < 4.0 for light in lights), v)

    def test_the_stairs_is_outside(self):
        zones = [m for m in layout()["markers"] if m["ucd"] == "zone" and m["name"].startswith("stairs_")]
        grades = {m["props"]["grade"] for m in zones}
        self.assertEqual(grades, {"outside", "indoors", "cellar"})

        def graded(point):
            # (As the game reads them: the smallest box a point is in.)
            inside = [m for m in zones if geo.Box(m["position"], m["basis"], m["size"]).contains(point)]
            return min(inside, key=lambda m: m["size"][0] * m["size"][1] * m["size"][2])["props"]["grade"] if inside else None

        self.assertEqual(graded([-140.0, 32.0, -120.0]), "outside")
        tx, tz, _yaw = stairs_plan.TAVERN
        self.assertEqual(graded([tx - 5.0, stairs_plan.level(stairs_plan.PLATES[1]) + 1.0, tz]), "indoors")
        self.assertEqual(graded([stairs_plan.STREAM_X, stairs_plan.level(stairs_plan.PLATES[0]) - 2.0, -35.0]), "cellar")

    def test_the_stairs_roofs_chain(self):
        # (Two or three chains over the roofs, each 3-6 houses and 25-60 m,
        # each got onto from a lane.)
        chains = routes("roof_stairs_")
        self.assertTrue(2 <= len(chains) <= 3, sorted(chains))
        rects = [(lot_rect(each), each) for each in stairs_plan.LOTS]

        for name, points in chains.items():
            self.assertEqual(points[0]["props"]["way"], "roof")
            houses = {each.name for r, each in rects for m in points if r[0] <= m["position"][0] <= r[2] and r[1] <= m["position"][2] <= r[3]
                      and m["position"][1] > each.y + 3.0}
            self.assertTrue(3 <= len(houses) <= 6, (name, sorted(houses)))
            length = sum(math.hypot(b["position"][0] - a["position"][0], b["position"][2] - a["position"][2]) for a, b in zip(points, points[1:]))
            self.assertTrue(25.0 <= length <= 60.0, (name, length))
            # (Its way up from a lane: a scaffold's ladders or a mantle.)
            self.assertTrue(any(abs(points[0]["position"][1] - stairs_plan.level(t)) < 0.05 for t in stairs_plan.PLATES), name)
            self.assertTrue(any(m["props"]["move"] in ("climb", "mantle", "hang") for m in points[1:4]), name)

    def test_houses_bridge_the_stair_lanes(self):
        # (Rooms over two stair-lanes at least, each between two houses, a
        # man's height and more clear over the steps under it.)
        bridges = [p for p in layout()["pieces"] if p["piece"].startswith("bridge_")]
        self.assertGreaterEqual(len(bridges), 2)
        boxes = rules.colliders(layout())

        for p in bridges:
            x, y, z = p["position"]
            under = [t for t in (b.ray([x, y - 0.5, z], [0.0, -1.0, 0.0]) for b in boxes) if t is not None]
            clear = min(under) + 0.5 if under else y - town.height(x, z)
            self.assertGreaterEqual(clear, 2.4, p["name"])

            for sx in (-1.0, 1.0):
                beside = [each for each in stairs_plan.LOTS if lot_rect(each)[0] - 0.05 <= x + sx * 1.6 <= lot_rect(each)[2] + 0.05
                          and lot_rect(each)[1] <= z <= lot_rect(each)[3]]
                self.assertTrue(beside, (p["name"], sx))

    def test_each_lanes_dead_end_has_its_end(self):
        # (Where a terrace's lane ends at the city wall or the old rampart: a
        # payoff, a hatch, a vantage, a way on, or a secret.)
        ends = [m for m in layout()["markers"] if m["name"].startswith("payoff_") or m["ucd"] in ("vantage", "exit", "secret")
                or (m["ucd"] == "route_check" and m["props"].get("route", "").startswith(("stairs_west_wall",)))]

        for plate in stairs_plan.PLATES:
            end = [stairs_plan.WEST + 1.0, stairs_plan.level(plate), stairs_plan.south(plate) - stairs_plan.LANE / 2.0]
            self.assertTrue(any(math.dist(m["position"], end) < 6.0 for m in ends), plate[0])

    def test_no_blank_side_stands_open(self):
        # (Every side of a stairs house with nothing within 4 m of it at its
        # first floor (a square, a yard, the tannery, the cliff, a strip by
        # it) has its windows: a corner house's; narrow lanes and alleys
        # keep their party walls.)
        boxes = rules.colliders(layout())
        bare = []

        for each in stairs_plan.LOTS:
            recipe = kit_recipes.PIECES[town.design_key(each)]
            r = lot_rect(each)
            y = each.y + kit_porto.SHOP + kit_porto.UPPER / 2.0
            # (A house facing north has its east side at -x.)
            for name, x, out in (("west", r[0] - 0.05, -1.0), ("east", r[2] + 0.05, 1.0)):
                local = name if abs(each.yaw) < 0.01 else {"west": "east", "east": "west"}[name]
                hits = [h for h in (b.ray([x, y, (r[1] + r[3]) / 2.0], [out, 0.0, 0.0]) for b in boxes) if h is not None]

                if (not hits or min(hits) > 4.0) and not any(o[1] == local for o in recipe["openings"]):
                    bare.append((each.name, name))

        self.assertEqual(bare, [])

    def test_no_story_panel_clads_a_front(self):
        # (The comet's, the king's, the souls' and the customs' panels are
        # pictures for a frame, not tiles for a house's front.)
        panels = {"azulejo_ship", "azulejo_comet", "azulejo_king", "azulejo_souls", "azulejo_mural"}

        for each in town.all_lots():
            self.assertNotIn(dict(each.params).get("front"), panels, each.name)

    def test_the_stairs_checks_clean(self):
        self.assertGreaterEqual(len(stairs_plan.LOTS), 60)
        self.assertEqual([p for p in rules.problems(layout(), "stage2") if "stairs" in p], [])


# The Judiaria (plan B1a, Task 16)

def placed_head(w):
    """A plan wall's stair's head in the world."""
    name = getattr(kit_terrace, w["kind"])(*w["args"])
    return geo.add(list(w["at"]), geo.apply(geo.rotation(w["yaw"]), kit_recipes.PIECES[name]["head"]))


def judiaria_openings():
    """The Judiaria's openings over its edges: each stair's head, each
    tower's top door, each Carmo stair's landing, the wall-walk's arrival."""
    out = []

    for w in jud_plan.WALLS["stair"]:
        head = placed_head(w)
        z = jud_plan.STEPS[w["step"]]["z"]

        if w["kind"] == "stair_lane":
            half = w["args"][0] / 2.0
            out.append((w["c"] - half, z - 0.6, w["c"] + half, z + 0.6))
        else:
            out.append((head[0] - 1.6, z - 0.6, head[0] + 0.4, z + 0.6))

    for name, z in jud_plan.TOWERS:
        door = jud_plan.tower_at(name, z)[2]
        out.append((jud_plan.WEST - 0.6, door - 0.8, jud_plan.WEST + 0.6, door + 0.8))

    for name, ground, foot in jud_plan.CARMO_STAIRS:
        head = jud_plan.carmo_head(foot, jud_plan.level(jud_plan.plate_named(name)) - ground)
        out.append((jud_plan.WEST - 0.6, head - 0.8, jud_plan.WEST + 0.6, head + 0.8))

    out.append((jud_plan.WALK[0] - 0.5, -76.0, 151.5, -72.0))
    return out


def jud_lot(name):
    return [each for each in jud_plan.LOTS if each.name == name][0]


class Judiaria(unittest.TestCase):
    def test_its_sectors_are_about_100_m(self):
        for name in ("judiaria_lo", "judiaria_hi"):
            zs = [z for t in jud_plan.PLATES for z in (t[3], t[5]) if town.sector_of(80.0, (t[3] + t[5]) / 2.0) == name]
            self.assertTrue(zs, name)
            self.assertLessEqual(max(zs) - min(zs), 120.0, name)

    def test_its_lanes_are_paved_in_river_pebbles(self):
        # (Santa Cruz's empedrado: the user's bought Gravel0037, its recipe
        # committed, the photo never.)
        from old_town import ground
        self.assertEqual(ground.SLOTS["judiaria"], "pebbles")
        self.assertTrue(os.path.exists(os.path.join(HERE, "../textures/recipes/pebbles.json")))

    def test_its_houses_turn_inward_behind_blank_walls(self):
        # (Patio houses all; a front a door and iron grilles, no more, at
        # most 15% of it open (a one-storey house's door alone a fifth).)
        self.assertGreaterEqual(len(jud_plan.LOTS), 200)
        self.assertEqual({each.family for each in jud_plan.LOTS}, {"patio"})

        for each in jud_plan.LOTS:
            recipe = kit_recipes.PIECES[town.design_key(each)]
            fronts = [o for o in recipe["openings"] if o[1] == "front"]
            self.assertTrue(all(o[6] in ("door", "barred", "shut") for o in fronts), each.name)
            self.assertEqual(len([o for o in fronts if o[6] in ("door", "barred")]), 1, each.name)
            share = 0.15 if each.storeys > 1 else 0.2
            self.assertLessEqual(sum(o[4] * o[5] for o in fronts), share * each.width * recipe["eaves"] + 1e-6, each.name)

    def test_each_step_is_climbed_by_two_stairs(self):
        # (Their heads level with the terrace above on the step's line,
        # their feet on the terrace below.)
        for k, step in enumerate(jud_plan.STEPS):
            mine = [w for w in jud_plan.WALLS["stair"] if w["step"] == k]
            self.assertEqual(len(mine), 2, k)

            for w in mine:
                head = placed_head(w)
                self.assertAlmostEqual(head[1], step["y"] + step["rise"], delta=0.02)
                self.assertAlmostEqual(w["at"][1], step["y"], delta=0.02)
                self.assertLess(abs(head[2] - step["z"]), 2.0, (k, head))

    def test_its_edges_are_walled(self):
        self.assertEqual(edge_faults("judiaria", judiaria_openings())[:8], [])

    def test_wall_stairs_stand_against_their_cliffs(self):
        # (Each stair up a step's face or the Carmo's cliff stands on the
        # face, no crack between; the wall behind it has its coping flush.)
        def flush_over(walls, along_x, lo, hi, at):
            return any(w["args"][-1] is True and abs(w["at"][2 if along_x else 0] - at) < 0.01
                       and w["at"][0 if along_x else 2] - w["args"][0] / 2.0 <= lo + 0.01 and hi - 0.01 <= w["at"][0 if along_x else 2] + w["args"][0] / 2.0
                       for w in walls if w["kind"] == "retaining" and len(w["args"]) == 5)

        for w in [w for w in jud_plan.WALLS["stair"] if w["kind"] == "wall_steps"]:
            rise, run, width = w["args"]
            z = jud_plan.STEPS[w["step"]]["z"]
            self.assertAlmostEqual(w["at"][2] - width / 2.0, z, delta=0.005)
            self.assertTrue(flush_over(jud_plan.WALLS["retaining"], True, w["at"][0], w["at"][0] + run, z), w["at"])

        for w in jud_plan.WALLS["carmo"]:
            rise, run, width = w["args"]
            self.assertAlmostEqual(w["at"][0] + width / 2.0, jud_plan.WEST, delta=0.005)
            self.assertTrue(flush_over(jud_plan.WALLS["west"], False, w["at"][2], w["at"][2] + run, jud_plan.WEST), w["at"])

    def test_its_lanes_dog_leg(self):
        # (Each terrace's lane in segments of 25 m at most, each jogging
        # its own width off the next: a view along it stops at the next
        # segment's fronts.)
        boxes = rules.colliders(layout())

        for plate in jud_plan.PLATES:
            y = jud_plan.level(plate) + 1.6
            segments = jud_plan.SEGMENTS[plate[0]]
            self.assertGreaterEqual(len(segments), 5, plate[0])

            for (x0, x1, s), (_a, _b, t) in zip(segments, segments[1:]):
                self.assertLessEqual(x1 - x0, 25.5, (plate[0], x0))
                self.assertGreaterEqual(abs(s - t), jud_plan.LANE - 1e-6, (plate[0], x0))
                z = jud_plan.south(plate) - s - jud_plan.LANE / 2.0
                hits = [h for h in (b.ray([x0 + 0.6, y, z], [1.0, 0.0, 0.0]) for b in boxes) if h is not None]
                self.assertTrue(hits, (plate[0], x0))
                self.assertLessEqual(min(hits), x1 - x0 + 0.5, (plate[0], x0, min(hits)))
                self.assertGreaterEqual(min(hits), x1 - x0 - 1.2, (plate[0], x0, min(hits)))

    def test_lanes_narrow_to_one_metre(self):
        # (The adarves: the narrowest a metre and a bit, none too narrow to
        # pass; measured wall to wall at a man's chest.)
        boxes = rules.colliders(layout())
        widths = []

        for name, (x0, w) in jud_plan.ADARVES.items():
            plate = jud_plan.plate_named(name)
            zn, _zs = jud_plan.lane(plate, x0 + w / 2.0)
            width = across(boxes, x0 + w / 2.0, jud_plan.level(plate) + 1.2, zn - 4.0)
            self.assertGreaterEqual(width, 1.0, name)
            widths.append(width)

        self.assertLessEqual(min(widths), 1.3)

    def test_adarves_are_gated_dead_ends(self):
        # (An iron gate across each one's mouth, shut at curfew; a payoff
        # at its end.)
        gates = [m for m in layout()["markers"] if m["ucd"] == "door" and m["props"].get("curfew")]
        payoffs = [m for m in layout()["markers"] if m["name"].startswith("payoff_")]

        for name, (x0, w) in jud_plan.ADARVES.items():
            plate = jud_plan.plate_named(name)
            y = jud_plan.level(plate)
            zn, _zs = jud_plan.lane(plate, x0 + w / 2.0)
            mouth = [x0 + w / 2.0, y, zn]
            gate = [m for m in gates if math.dist(m["position"], mouth) < 0.5]
            self.assertEqual(len(gate), 1, name)
            self.assertEqual(gate[0]["props"]["kind"], "gate")
            end = [x0 + w / 2.0, y, jud_plan.north(plate) + 1.0]
            self.assertTrue(any(math.dist(m["position"], end) < 2.0 for m in payoffs), name)

    def test_two_quarter_gates_shut_at_curfew(self):
        # (Iron gates 2.5 m wide across the courts the Baixa's towers open
        # into, shut at the curfew bell; each tower's way in passes one.)
        gates = [m for m in layout()["markers"] if m["ucd"] == "door" and m["props"].get("label") == "the Judiaria's gate"]
        self.assertEqual(len(gates), 2)
        ways = routes("judiaria_tower_")
        self.assertEqual(len(ways), 2)

        for m in gates:
            self.assertEqual(m["props"]["kind"], "gate")
            self.assertTrue(m["props"]["curfew"])
            self.assertGreaterEqual(m["props"]["width"], 2.5)
            self.assertTrue(any(p["piece"].startswith("gateway_") and math.dist(p["position"], m["position"]) < 0.3 for p in layout()["pieces"]))
            self.assertTrue(any(any(math.dist(c["position"], m["position"]) < 1.5 for c in points) for points in ways.values()), m["name"])

    def test_the_patios_gates_are_iron(self):
        # (Each walked-in patio house's cancela an iron gate: its marker's
        # kind; its street door wood.)
        doors = {m["name"]: m for m in layout()["markers"] if m["ucd"] == "door"}
        walked = [each for each in jud_plan.LOTS if each.enterable]
        self.assertTrue(walked)

        for each in walked:
            self.assertEqual(doors["%s_door_1" % each.name]["props"].get("kind", "hinged"), "hinged", each.name)
            self.assertEqual(doors["%s_door_2" % each.name]["props"].get("kind"), "gate", each.name)

    def test_the_palace_is_sealed(self):
        # (Its garden wall shuts the quarter's east; its gate at x 150, z
        # -230 barred, a sealed exit there.)
        exits = [m for m in layout()["markers"] if m["ucd"] == "exit" and m["props"].get("to") == "palace"]
        self.assertEqual(len(exits), 1)
        m = exits[0]
        self.assertLess(math.hypot(m["position"][0] - 150.0, m["position"][2] + 230.0), 2.5)
        self.assertTrue(m["props"]["label"].endswith("(sealed)"))
        self.assertTrue(any(p["piece"].startswith("gateway_") and "_barred" in p["piece"] and math.dist(p["position"], m["position"]) < 1.5
                            for p in layout()["pieces"]))
        # (Its bars show the palace's garden beyond the wall, not the sky.)
        glimpse = [p for p in layout()["pieces"] if p["piece"].startswith("garden_glimpse_") and abs(p["position"][2] - m["position"][2]) < 1.0
                   and jud_plan.EDGE - 0.05 <= p["position"][0] <= jud_plan.EDGE + 0.5]
        self.assertEqual(len(glimpse), 1)
        boxes = rules.colliders(layout())

        for plate in jud_plan.PLATES:
            y = jud_plan.level(plate) + 1.2

            for i in range(int(jud_plan.south(plate) - jud_plan.north(plate))):
                z = jud_plan.north(plate) + i + 0.5

                if z > jud_plan.WALK[1]:
                    continue

                hits = [h for h in (b.ray([147.0, y, z], [1.0, 0.0, 0.0]) for b in boxes) if h is not None]
                self.assertTrue(hits and min(hits) < 4.5, (plate[0], z))

    def test_the_azotea_highway_runs_house_to_house(self):
        # (Two or three chains of linked roofs, each 3-6 houses and 25-60 m,
        # each up a stair from a plazuela, a lookout on one of its houses,
        # every linked roof walked.)
        chains = routes("roof_judiaria_")
        self.assertTrue(2 <= len(chains) <= 3, sorted(chains))
        rects = [(jud_plan.lot_rect(each), each) for each in jud_plan.LOTS]

        for name, points in chains.items():
            self.assertEqual(points[0]["props"]["way"], "roof")
            houses = {each.name for r, each in rects for m in points if r[0] <= m["position"][0] <= r[2] and r[1] <= m["position"][2] <= r[3]
                      and m["position"][1] > each.y + 3.0}
            self.assertTrue(3 <= len(houses) <= 6, (name, sorted(houses)))
            self.assertTrue(all(jud_lot(h).quirk == "linked" for h in houses), name)
            self.assertTrue(any("lookout" in kit_recipes.PIECES[town.design_key(jud_lot(h))]["places"] for h in houses), name)
            length = sum(math.hypot(b["position"][0] - a["position"][0], b["position"][2] - a["position"][2]) for a, b in zip(points, points[1:]))
            self.assertTrue(25.0 <= length <= 60.0, (name, length))
            self.assertTrue(any(abs(points[0]["position"][1] - jud_plan.level(t)) < 0.05 for t in jud_plan.PLATES), name)

        linked = {each.name for each in jud_plan.LOTS if each.quirk == "linked"}
        walked = {each.name for r, each in rects for points in chains.values() for m in points
                  if r[0] <= m["position"][0] <= r[2] and r[1] <= m["position"][2] <= r[3] and m["position"][1] > each.y + 3.0}
        self.assertEqual(sorted(linked - walked), [])

    def test_cobertizos_bridge_the_stair_lanes(self):
        # (Houses bridging two stair-lanes at least, a room over the lane's
        # foot clear of a man's head, its far end on the next house.)
        boxes = rules.colliders(layout())
        bridges = [each for each in jud_plan.LOTS if each.quirk == "bridge"]
        self.assertGreaterEqual(len(bridges), 2)

        for each in bridges:
            r = jud_plan.lot_rect(each)
            k = [k for k, step in enumerate(jud_plan.STEPS) if abs(step["z"] - r[1]) < 0.05][0]
            self.assertIn((r[2] + jud_plan.COBERTIZO / 2.0, jud_plan.COBERTIZO), [tuple(s) for s in jud_plan.STEPS[k]["stairs"]], each.name)
            x, z = r[2] + jud_plan.COBERTIZO / 2.0, each.z - 2.0
            over = [h for h in (b.ray([x, each.y + 0.2, z], [0.0, 1.0, 0.0]) for b in boxes) if h is not None]
            self.assertTrue(over and 3.5 <= min(over) + 0.2 <= 4.5, (each.name, over and min(over)))

    def test_the_corral_is_kept_for_the_townsfolk(self):
        corral = [each for each in jud_plan.LOTS if dict(each.params).get("kind") == "corral"]
        self.assertEqual(len(corral), 1)
        each = corral[0]
        self.assertTrue(each.lived and each.enterable)
        r = jud_plan.lot_rect(each)
        homes = [m for m in layout()["markers"] if m["ucd"] == "home" and r[0] <= m["position"][0] <= r[2] and r[1] <= m["position"][2] <= r[3]]
        self.assertGreaterEqual(len(homes), 4)

    def test_cisterns_lie_under_two_plazuelas(self):
        # (Down a hatch in each, along a vaulted cistern's ledge over its
        # water: below, a cellar.)
        ways = routes("judiaria_cistern_")
        self.assertEqual(len(ways), 2)
        holes = town.ground_holes()
        waters = [m for m in layout()["markers"] if m["ucd"] == "water" and m["name"].startswith("judiaria_cistern_")]
        self.assertEqual(len(waters), 2)

        ground = rules.ground_of(layout())

        for k, points in zip(jud_plan.CISTERNS, [ways[n] for n in sorted(ways)]):
            hx, hz = jud_plan.cistern(k)[2]
            self.assertIn((hx, hz), holes)
            # (Its hatch takes one cell of the ground, its collar paving it.)
            self.assertEqual(ground.heights(hx, hz), [])

            for dx, dz in ((1.4, 0.0), (-1.4, 0.0), (0.0, 1.4), (0.0, -1.4)):
                self.assertTrue(ground.heights(hx + dx, hz + dz), (k, dx, dz))
            self.assertEqual(points[0]["props"]["way"], "below")
            p = jud_plan.PLAZUELAS[k]
            self.assertTrue(p <= hx <= p + jud_plan.PLAZUELA)
            self.assertLess(points[-1]["position"][1], jud_plan.level(jud_plan.PLATES[k]) - 2.0)

    def test_the_baixa_and_the_carmo_climb_to_it(self):
        # (Each boundary step: two public ways up from the lower quarter's
        # ground to a terrace of the Judiaria, a thief's beside them.)
        found = {}

        for points in routes("judiaria_").values():
            props = points[0]["props"]

            if props.get("step") in ("judiaria_step_baixa", "judiaria_step_carmo"):
                found.setdefault(props["step"], []).append(points)

        for step, quarter in (("judiaria_step_baixa", "baixa"), ("judiaria_step_carmo", "carmo")):
            ways = found.get(step, [])
            self.assertEqual(sorted(w[0]["props"]["way"] for w in ways), ["public", "public", "thief"], step)

            for points in ways:
                first, last = points[0]["position"], points[-1]["position"]
                self.assertEqual(town.quarter_of(first[0], first[2]), quarter)
                self.assertAlmostEqual(first[1], town.height(first[0], first[2]), delta=0.05)
                self.assertEqual(town.quarter_of(last[0], last[2]), "judiaria")
                self.assertTrue(any(abs(last[1] - jud_plan.level(t)) < 0.05 for t in jud_plan.PLATES))

    def test_each_tower_opens_at_its_terrace(self):
        towers = sorted((p for p in layout()["pieces"] if p["piece"].startswith("stair_tower_") and p["name"].startswith("judiaria_")),
                        key=lambda p: -p["position"][2])
        self.assertEqual(len(towers), 2)

        for p, (plate, z) in zip(towers, jud_plan.TOWERS):
            doors = [geo.add(p["position"], geo.apply(p["basis"], d)) for d in kit_recipes.PIECES[p["piece"]]["doors"]]
            self.assertAlmostEqual(doors[0][1], jud_plan.BAIXA_G, delta=0.05)
            self.assertAlmostEqual(doors[1][1], jud_plan.level(jud_plan.plate_named(plate)), delta=0.05)
            self.assertAlmostEqual(doors[1][2], jud_plan.tower_at(plate, z)[2], delta=0.05)
            self.assertLess(abs(doors[1][0] - jud_plan.WEST), 0.6)
            self.assertLess(doors[0][0], jud_plan.WEST - 3.0)

    def test_each_step_is_crossed_publicly_and_by_a_thief(self):
        labels = {m["props"]["label"] for m in layout()["markers"] if m["ucd"] == "terrace_step" and m["props"]["label"].startswith("judiaria_step_")}
        self.assertEqual(labels, {"judiaria_step_%d" % (k + 1) for k in range(len(jud_plan.STEPS))} | {"judiaria_step_baixa", "judiaria_step_carmo"})
        self.assertEqual([p for p in rules.way_problems(layout()) if "judiaria_step_" in p], [])

    def test_the_lanes_are_lamp_lit(self):
        # (Corner lamps on the fronts along each terrace's lane, 40 m apart
        # at most and 25 m from its ends, lit on dark nights only.)
        lamps = [p for p in layout()["pieces"] if p["piece"] == "corner_lamp" and p["name"].startswith("judiaria_")]
        lights = [m for m in layout()["markers"] if m["ucd"] == "light" and m["name"].startswith("judiaria_lamp_")]
        self.assertTrue(lights and all(m["props"].get("dark_only") for m in lights))

        for plate in jud_plan.PLATES:
            xs = sorted(p["position"][0] for p in lamps if abs(p["position"][1] - jud_plan.level(plate)) < 0.05)
            self.assertTrue(xs, plate[0])
            self.assertLessEqual(xs[0] - jud_plan.WEST, 25.0, plate[0])
            self.assertLessEqual(jud_plan.EAST - xs[-1], 25.0, plate[0])
            self.assertTrue(all(b - a <= 40.0 for a, b in zip(xs, xs[1:])), (plate[0], xs))

    def test_the_shrines_burn_all_night(self):
        lights = [m for m in layout()["markers"] if m["ucd"] == "light" and m["props"]["kind"] == "candle"]
        vantages = [m["position"] for m in layout()["markers"] if m["ucd"] == "vantage"]

        for each in jud_plan.LOTS:
            if each.quirk != "shrine":
                continue

            r = jud_plan.lot_rect(each)
            near = [m for m in lights if r[0] - 0.5 <= m["position"][0] <= r[2] + 0.5 and abs(m["position"][2] - each.z) < 0.6]

            if not any(r[0] - 4.5 <= v[0] <= r[2] + 4.5 and abs(v[2] - each.z) < 4.5 for v in vantages):
                self.assertTrue(near and all(m["props"]["douse"] for m in near), each.name)

    def test_the_judiaria_has_its_vantages(self):
        # (At each stair's head, each lane's west end over the cliff, each
        # corbels' top: unlit.)
        vantages = [m["position"] for m in layout()["markers"] if m["ucd"] == "vantage" and m["name"].startswith("judiaria_")]
        lights = [m["position"] for m in layout()["markers"] if m["ucd"] == "light"]

        def near(point, reach):
            return any(math.dist(v, point) <= reach for v in vantages)

        for w in jud_plan.WALLS["stair"]:
            self.assertTrue(near(placed_head(w), 3.5), w["at"])

        for plate in jud_plan.PLATES:
            zn, zs = jud_plan.lane(plate, jud_plan.WEST + 1.0)
            self.assertTrue(near([jud_plan.WEST + 1.0, jud_plan.level(plate), (zn + zs) / 2.0], 3.0), plate[0])

        for v in vantages:
            self.assertFalse(any(math.dist(v, light) < 4.0 for light in lights), v)

    def test_the_judiaria_is_outside(self):
        zones = [m for m in layout()["markers"] if m["ucd"] == "zone" and m["name"].startswith("judiaria_")]
        self.assertEqual({m["props"]["grade"] for m in zones}, {"outside", "indoors", "cellar"})

        def graded(point):
            inside = [m for m in zones if geo.Box(m["position"], m["basis"], m["size"]).contains(point)]
            return min(inside, key=lambda m: m["size"][0] * m["size"][1] * m["size"][2])["props"]["grade"] if inside else None

        for plate in jud_plan.PLATES:
            zn, zs = jud_plan.lane(plate, 80.0)
            self.assertEqual(graded([80.0, jud_plan.level(plate) + 1.0, (zn + zs) / 2.0]), "outside", plate[0])

        (x, z), _h, _door = jud_plan.tower_at(*jud_plan.TOWERS[0])
        self.assertEqual(graded([x, 8.0, z]), "indoors")
        cx, cy, _hatch, back = jud_plan.cistern(jud_plan.CISTERNS[0])
        self.assertEqual(graded([cx, cy + 1.0, back + 2.0]), "cellar")

    def test_the_wall_walks_arrival_is_kept(self):
        # (The harbour's east wall-walk comes in at the first terrace's
        # south-east corner: open ground there, a public way on into the
        # lane.)
        at = [m for m in layout()["markers"] if m["name"] == "from_harbour_wall_walk"][0]["position"]
        boxes = rules.colliders(layout())
        self.assertFalse(any(b.contains([at[0], at[1] + 1.0, at[2]], 0.4) for b in boxes))
        way = routes("judiaria_walk_way")
        self.assertEqual(len(way), 1)
        points = list(way.values())[0]
        self.assertLess(math.dist(points[0]["position"], at), 1.0)
        zn, zs = jud_plan.lane(jud_plan.PLATES[0], points[-1]["position"][0])
        self.assertTrue(zn <= points[-1]["position"][2] <= zs)

    def test_the_judiaria_checks_clean(self):
        self.assertEqual([p for p in rules.problems(layout(), "stage2") if "judiaria" in p], [])


if __name__ == "__main__":
    unittest.main()
