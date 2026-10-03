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
# The player's capsule's radius (Player.tscn): what a climb must leave room for.
CLIMBER = 0.5


def k_lift():
    """How far a roof's top stands over its wall's top, at the wall."""
    import kit_iberian as ki
    return kit_recipes.ROOF_THICK / math.cos(math.radians(ki.PITCH))


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

        # The climber (the player's capsule, 0.5 m round) passes the balconies
        # and lands on the roof clear of the next house (a taller one: no room
        # for him there, and the mantle is refused).
        for c in balconies(recipe):
            self.assertGreaterEqual(abs(x - c[0]) - c[3] / 2.0, CLIMBER + 0.05, c)

        self.assertLessEqual(abs(x) + CLIMBER, recipe["size"][0] / 2.0 - 0.2 - 0.05)
        self.assertGreaterEqual(len(balconies(recipe)), 3)
        self.assertTrue(any(s["slot"] == "ivy" for s in recipe["shapes"]))

        for name in CASAS:
            if name != "casa_d":
                self.assertEqual(kit_recipes.PIECES[name].get("climbs", []), [], name)

    def test_every_city_roof_is_stood_on(self):
        # Wherever a city piece draws roof tiles, a collider holds a man up
        # within 0.4 m of them: nobody sinks into a roof (the Terreiro's
        # arcades drew theirs 2.4 m over a flat collider at the eaves).
        sunk = []

        for name, recipe in kit_recipes.PIECES.items():
            if recipe["family"] not in ("iberian", "casa", "harbour", "fort", "massing") or not recipe.get("shapes"):
                continue

            built = kit_shapes.build(recipe["shapes"])
            boxes = geo.piece_boxes(recipe, [0.0, 0.0, 0.0], geo.IDENTITY)

            for face in built["faces"]:
                if not face[1].startswith("roof"):
                    continue

                points = [built["verts"][i] for i in face[0]]
                normal = kit_shapes._normal(points)

                if normal[1] < 0.5:
                    continue

                middle = [sum(p[k] for p in points) / len(points) for k in range(3)]
                t = None

                for box in boxes:
                    hit = box.ray([middle[0], middle[1] + 0.05, middle[2]], [0.0, -1.0, 0.0])

                    if hit is not None and (t is None or hit < t):
                        t = hit

                # (Except the eaves' overhang: tiles out past a wall's top,
                # within 0.8 m of it and no more than 0.6 m over it. A roof
                # drawn far over its collider is still caught.)
                if (t is None or t > 0.45) and not any(b.contains([middle[0] + dx * d, middle[1] - dy, middle[2] + dz * d])
                                                       for b in boxes for d in (0.2, 0.4, 0.6, 0.8) for dy in (0.0, 0.2, 0.4, 0.6)
                                                       for dx, dz in ((1, 0), (-1, 0), (0, 1), (0, -1))):
                    sunk.append("%s at %s (%s)" % (name, [round(v, 1) for v in middle], "nothing under" if t is None else "%.2f m" % t))
                    break

        self.assertEqual(sunk, [])

    def test_the_roofs_stop_at_the_walls(self):
        # A climber at the eaves (casa_d's vine) must meet the wall's upright
        # face, not the tilted end of a roof's collider standing out past it
        # (the scanner turns a sloped face away: "not a wall").
        for name in CASAS:
            recipe = kit_recipes.PIECES[name]

            for box in geo.piece_boxes(recipe, [0.0, 0.0, 0.0], geo.IDENTITY):
                if box.centre[1] < recipe["eaves"]:
                    continue

                for corner in _corners(box):
                    self.assertLessEqual(abs(corner[2]), recipe["front"] + 1e-3, "%s: %s" % (name, [round(v, 3) for v in corner]))

    def test_the_eaves_show_a_climber_a_wall(self):
        # Just over the wall's top a climber's scan meets an upright wall plate
        # (flush with the front and back), not the end of a roof's slab, which
        # tilts and is turned away as "not a wall".
        for name in CASAS:
            recipe = kit_recipes.PIECES[name]
            boxes = geo.piece_boxes(recipe, [0.0, 0.0, 0.0], geo.IDENTITY)

            for s in (1.0, -1.0):
                for x in (-2.5, 0.0, 2.55):
                    for up in (0.05, 0.15, 0.25):
                        point = [x, recipe["eaves"] + up, s * (recipe["front"] - 0.02)]
                        self.assertTrue(any(b.contains(point) for b in boxes), "%s: %s" % (name, point))

    def test_windows_are_set_in_reveals_with_glazing(self):
        # (The user, Oct 2: the Ribeira's windows should feel more real.) Each
        # upper window's glass sits 10-15 cm back from the front's face (the
        # reveal, after Porto's: the frame shallow outside), glazing bars just
        # in front of it, a granite jamb either side standing proud of the face.
        import kit_iberian as ki
        for name in CASAS:
            recipe = kit_recipes.PIECES[name]
            shapes = recipe["shapes"]
            glass = [s for s in shapes if s["kind"] == "card" and s["slot"] in ("glass_dark", "glass_lit") and s["centre"][1] > ki.GROUND + 0.5]
            storeys = int(round((recipe["eaves"] - ki.GROUND) / ki.STOREY))
            self.assertEqual(len(glass), 2 * storeys, name)

            for g in glass:
                x, y, z = g["centre"]
                self.assertTrue(ki.FACE - 0.16 <= z <= ki.FACE - 0.09, "%s: glass at z %.2f" % (name, z))
                bars = [s for s in shapes if s["kind"] == "card" and s["slot"] in ("casement", "sash")
                        and abs(s["centre"][0] - x) < 0.01 and abs(s["centre"][1] - y) < 0.01 and 0.0 < s["centre"][2] - z < 0.03]
                self.assertEqual(len(bars), 1, "%s: glazing over the glass at %s" % (name, g["centre"]))
                half = g["size"][0] / 2.0
                jambs = [s for s in shapes if s["kind"] == "box" and s["slot"] == "granite" and half < abs(s["centre"][0] - x) < half + 0.25
                         and s["centre"][2] + s["size"][2] / 2.0 > ki.FACE + 0.01 and s["centre"][2] - s["size"][2] / 2.0 <= z
                         and abs(s["centre"][1] - y) < 0.05 and s["size"][1] >= g["size"][1] - 0.05]
                self.assertEqual(len(jambs), 2, "%s: jambs either side of %s" % (name, g["centre"]))

    def test_balconies_are_carried_and_railed(self):
        # Over the arcade each balcony stands on granite corbels (cachorros),
        # its slab's front edge moulded; iron rails across its front and back
        # to the wall at each end (returns), a handrail along their tops, a
        # post and a finial at each front corner.
        import kit_iberian as ki
        for name in CASAS:
            recipe = kit_recipes.PIECES[name]
            shapes = recipe["shapes"]

            for c in balconies(recipe):
                lip, x0, x1 = top_of(c), c[0] - c[3] / 2.0, c[0] + c[3] / 2.0
                front = c[2] + c[5] / 2.0
                inside = [s for s in shapes if "centre" in s and x0 - 0.05 <= s["centre"][0] <= x1 + 0.05]

                if lip > ki.GROUND + 0.5:
                    corbels = [s for s in inside if s["kind"] == "ring" and s["slot"] == "granite" and s["centre"][1] < lip - c[4]]
                    self.assertGreaterEqual(len(corbels), 2, "%s: corbels under %.1f" % (name, lip))

                edge = [s for s in inside if s["kind"] == "prism" and s["slot"] == "granite" and abs(s["centre"][2] - front) < 0.12
                        and abs(s["centre"][1] - (lip - c[4] / 2.0)) < 0.05]
                self.assertEqual(len(edge), 1, "%s: a moulded edge at %.1f" % (name, lip))
                rails = [s for s in inside if s["kind"] == "card" and s["slot"] == "iron_rail" and lip < s["centre"][1] < lip + 1.0]
                fronts = [s for s in rails if abs(s["turn"][0]) < 1.0 and abs(s["centre"][2] - front) < 0.08]
                returns = [s for s in rails if abs(abs(s["turn"][0]) - 90.0) < 1.0]
                self.assertGreaterEqual(sum(s["size"][0] for s in fronts), c[3] - 0.15, "%s: rail across %.1f" % (name, lip))
                # (No rail stretched: its bars stay a hand apart.)
                self.assertTrue(all(s["size"][0] <= 1.8 for s in fronts), name)
                self.assertEqual(len(returns), 2, "%s: returns at %.1f" % (name, lip))
                iron = [s for s in inside if s["slot"] == "iron" and lip + 0.85 < s["centre"][1] < lip + 1.15]
                self.assertGreaterEqual(len([s for s in iron if s["kind"] == "box"]), 3, "%s: handrails at %.1f" % (name, lip))
                self.assertEqual(len([s for s in iron if s["kind"] == "prism"]), 2, "%s: finials at %.1f" % (name, lip))

    def test_a_balconys_rails_stop_a_man(self):
        # A man on a balcony (dropped onto it from a roof) walks into its
        # rails, not through them: across its front and at both ends, the
        # handrail's height over its floor.
        for name in CASAS:
            recipe = kit_recipes.PIECES[name]
            boxes = geo.piece_boxes(recipe, [0.0, 0.0, 0.0], geo.IDENTITY)

            for c in balconies(recipe):
                lip, x0, x1 = top_of(c), c[0] - c[3] / 2.0, c[0] + c[3] / 2.0
                wall, front = c[2] - c[5] / 2.0, c[2] + c[5] / 2.0
                knee, waist = lip + 0.3, lip + 0.85
                # (Where the rails are drawn: 3 cm in from its front and ends.)
                outward = [[x, y, front - 0.03] for x in (x0 + 0.3, (x0 + x1) / 2.0, x1 - 0.3) for y in (knee, waist)]
                sideways = [[x, y, (wall + front) / 2.0] for x in (x0 + 0.03, x1 - 0.03) for y in (knee, waist)]

                for point in outward + sideways:
                    self.assertTrue(any(b.contains(point) for b in boxes), "%s: no rail at %s over %.1f" % (name, point, lip))

    def test_the_eaves_are_stepped_rows_of_tile(self):
        # The beirado: rows of canal tile stepping out over a granite cornice,
        # three at the front and two at the back, each showing its row of
        # round tile mouths (dark under each cap), never a roof plane ending
        # in a knife edge.
        for name in CASAS:
            recipe = kit_recipes.PIECES[name]
            built = kit_shapes.build(recipe["shapes"])
            rows = {1.0: set(), -1.0: set()}
            count = {1.0: 0, -1.0: 0}

            for face in built["faces"]:
                if face[1] != "pitch":
                    continue

                points = [built["verts"][i] for i in face[0]]
                z = sum(p[2] for p in points) / len(points)

                if abs(z) > recipe["front"] + 0.1:
                    s = 1.0 if z > 0 else -1.0
                    rows[s].add(round(min(p[1] for p in points), 2))
                    count[s] += 1

            self.assertEqual(len(rows[1.0]), 3, "%s: front rows %s" % (name, sorted(rows[1.0])))
            self.assertEqual(len(rows[-1.0]), 2, "%s: back rows %s" % (name, sorted(rows[-1.0])))
            self.assertGreaterEqual(count[1.0], 3 * 15, name)

    def test_the_roof_is_corrugated_and_ends_on_its_party_walls(self):
        # Canal tiles in section (channels and caps: faces leaning both ways
        # across each slope), a ridge roll, and party walls standing over
        # the slopes at both sides with their copings.
        import kit_iberian as ki
        rise = ki.FRONT * math.tan(math.radians(ki.PITCH))

        for name in CASAS:
            recipe = kit_recipes.PIECES[name]
            built = kit_shapes.build(recipe["shapes"])
            lean = {1: 0, -1: 0}

            for face in built["faces"]:
                points = [built["verts"][i] for i in face[0]]

                if face[1] == "roof_spanish" and abs(sum(p[2] for p in points) / len(points)) < recipe["front"]:
                    n = kit_shapes._normal(points)
                    length = math.sqrt(sum(c * c for c in n))

                    if n[1] > 0 and abs(n[0]) / length > 0.1:
                        lean[1 if n[0] > 0 else -1] += 1

            self.assertGreaterEqual(min(lean.values()), 30, "%s: %s" % (name, lean))
            ridge = [s for s in recipe["shapes"] if s["kind"] == "prism" and s["slot"] == "roof_spanish" and s["centre"][1] > recipe["eaves"] + rise]
            self.assertEqual(len(ridge), 1, name)

            for side in (-1.0, 1.0):
                walls = [s for s in recipe["shapes"] if s["kind"] == "gable" and abs(s["centre"][0] - side * (ki.WIDTH / 2.0 - 0.1)) < 0.01]
                self.assertEqual(len(walls), 1, name)
                self.assertGreaterEqual(walls[0]["centre"][1], recipe["eaves"] + k_lift() + 0.2, name)
                copings = [s for s in recipe["shapes"] if s["kind"] == "box" and s["slot"] == "granite" and abs(s["centre"][0] - side * (ki.WIDTH / 2.0 - 0.1)) < 0.01
                           and abs(abs(s["turn"][1]) - ki.PITCH) < 0.5]
                self.assertEqual(len(copings), 2, name)

    def test_the_terreiro_windows_and_roofs_are_made_like_the_houses(self):
        # Its windows over the arcade in reveals (the glass 13 cm back, a
        # casement over it, granite jambs either side), a moulded balcony with
        # rails and returns; its roofs canal tiles in section with their
        # mouths along both eaves.
        import kit_iberian as ki
        face = ki.BAY["depth"] / 2.0

        for name in ("terreiro_bay_6", "terreiro_corner"):
            recipe = kit_recipes.PIECES[name]
            shapes = recipe["shapes"]
            face = ki.BAY["depth"] / 2.0 if name == "terreiro_bay_6" else 4.0
            glass = [s for s in shapes if s["kind"] == "card" and s["slot"] in ("glass_dark", "glass_lit") and s["centre"][1] > ki.BAY["arcade"]]
            self.assertEqual(len(glass), 1 if name == "terreiro_bay_6" else 2, name)

            for g in glass:
                out = max(abs(g["centre"][0]), abs(g["centre"][2]))
                self.assertTrue(face - 0.16 <= out <= face - 0.09, "%s: glass %.2f in" % (name, face - out))
                bars = [s for s in shapes if s["kind"] == "card" and s["slot"] == "casement" and abs(s["centre"][1] - g["centre"][1]) < 0.01
                        and 0.0 < max(abs(s["centre"][0]), abs(s["centre"][2])) - out < 0.03
                        and abs(s["centre"][0] - g["centre"][0]) + abs(s["centre"][2] - g["centre"][2]) < 0.03]
                self.assertEqual(len(bars), 1, name)

            edges = [s for s in shapes if s["kind"] == "prism" and s["slot"] == "granite" and abs(s["centre"][1] - ki.BAY["arcade"] + 0.075) < 0.05]
            self.assertEqual(len(edges), len(glass), name)
            returns = [s for s in shapes if s["kind"] == "card" and s["slot"] == "iron_rail" and abs(abs(s["turn"][0] - (s["turn"][0] // 180) * 180) - 90.0) < 1.0]
            self.assertGreaterEqual(len(returns), 2 * len(glass), name)
            built = kit_shapes.build(shapes)
            mouths = sum(1 for f in built["faces"] if f[1] == "pitch")
            self.assertGreaterEqual(mouths, 2 * 15, name)
            lean = {1: 0, -1: 0}

            for f in built["faces"]:
                if f[1] == "roof_spanish":
                    n = kit_shapes._normal([built["verts"][i] for i in f[0]])
                    length = math.sqrt(sum(c * c for c in n))

                    if n[1] > 0 and abs(n[0]) / length > 0.1:
                        lean[1 if n[0] > 0 else -1] += 1

            self.assertGreaterEqual(min(lean.values()), 30, "%s: %s" % (name, lean))

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

    def test_a_shroud_climber_comes_up_within_reach_of_his_top(self):
        # A climb's wall is its box's middle (ClimbVolume.get_plane_point):
        # the climber hangs 0.38 m out from it (his radius and climb_distance).
        # Up the shrouds he must pass the top clear of it overhead, and come
        # up within the scanner's reach (1.2 m) of its edge to mantle onto it.
        rig = kit_recipes.PIECES["carrack_rig"]
        tops = [c for c in rig["cols"] if c[4] <= 0.15]

        for c in rig["climbs"]:
            top = min(tops, key=lambda t: abs(t[0] - c[0]))
            half = top[5] / 2.0
            hangs = abs(c[2]) + 0.38
            self.assertGreaterEqual(hangs - 0.3, half + 0.05, c)
            self.assertLessEqual(hangs - half, 1.0, c)

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


class Coast(unittest.TestCase):
    ROCKS = ["tor_a", "tor_b", "tor_c", "ledge_a", "ledge_b", "boulders_a", "boulders_b", "boulders_c", "boulder_big", "notch_rock"]
    PLANTS = ["gorse_cushion", "gorse_bush", "fennel_clump", "pine_stone", "pine_maritime", "fig_wall"]
    LIFE = ["gull", "gull_sitting", "net_poles", "laundry_2", "tavern_bush"]

    def test_budgets(self):
        for name in self.ROCKS + self.PLANTS + self.LIFE:
            recipe = kit_recipes.PIECES[name]
            self.assertLessEqual(tris(recipe), recipe.get("budget", kit_shapes.PIECE_TRIS), name)

    def test_rock_is_blocks_along_its_joints_each_stood_on(self):
        # Granite in blocks, not noise: every block (an octagon in plan, its
        # top rounded in) carries a collider round it, so the thief climbs
        # and stands on what he sees; their tops are smaller than their feet.
        for name in self.ROCKS:
            recipe = kit_recipes.PIECES[name]
            self.assertEqual(recipe["family"], "coast")
            self.assertTrue(all(s["slot"] == "rock_shore" for s in recipe["shapes"]), name)
            tops = [s for s in recipe["shapes"] if len(s["points"]) == 8 and kit_shapes._normal(s["points"])[1] > 0.0]
            feet = [s for s in recipe["shapes"] if len(s["points"]) == 8 and kit_shapes._normal(s["points"])[1] < 0.0]
            self.assertEqual(len(tops), len(recipe["cols"]), name)
            self.assertEqual(len(feet), len(recipe["cols"]), name)

            def spread(face):
                xs, zs = [p[0] for p in face["points"]], [p[2] for p in face["points"]]
                return (max(xs) - min(xs)) * (max(zs) - min(zs))

            self.assertLess(sum(spread(t) for t in tops), sum(spread(f) for f in feet), name)

            for top in tops:
                middle = [sum(p[k] for p in top["points"]) / 8.0 for k in range(3)]
                below = [b for b in geo.piece_boxes(recipe, [0.0, 0.0, 0.0], geo.IDENTITY) if b.contains([middle[0], middle[1] - 0.1, middle[2]])]
                self.assertTrue(below, "%s: nothing under its top at %s" % (name, middle))

    def test_a_tor_is_stacked_with_cracks_between(self):
        # Rows of blocks one on another, a crack between blocks in a row.
        for name in ("tor_a", "tor_b", "tor_c"):
            cols = kit_recipes.PIECES[name]["cols"]
            tops = sorted({round(c[1] + c[4] / 2.0, 1) for c in cols})
            self.assertGreaterEqual(max(c[1] + c[4] / 2.0 for c in cols) - min(c[1] - c[4] / 2.0 for c in cols), 2.5, name)
            self.assertGreaterEqual(len(tops), 2, name)

    def test_boulders_are_half_buried(self):
        for name in ("boulders_a", "boulders_b", "boulders_c"):
            cols = kit_recipes.PIECES[name]["cols"]
            self.assertGreaterEqual(len(cols), 6, name)
            self.assertTrue(all(c[1] - c[4] / 2.0 < -0.05 for c in cols), name)

    def test_the_notch_overhangs_its_foot(self):
        cols = sorted(kit_recipes.PIECES["notch_rock"]["cols"], key=lambda c: c[1])
        foot, over = cols
        self.assertGreater(over[2] + over[5] / 2.0, foot[2] + foot[5] / 2.0 + 0.8)

    def test_the_plants_and_the_life_are_their_paintings(self):
        slots = {"gorse_cushion": "gorse", "gorse_bush": "gorse", "fennel_clump": "fennel", "pine_stone": "pine", "pine_maritime": "pine",
                 "fig_wall": "leaf_crown", "laundry_2": "laundry", "net_poles": "net", "tavern_bush": "leaf_shrub", "gull": "feather"}

        for name, slot in slots.items():
            self.assertTrue(any(s["slot"] == slot for s in kit_recipes.PIECES[name]["shapes"]), name)

        # Trees stop a man at their trunks; cushions and washing do not.
        for name in ("pine_stone", "pine_maritime", "net_poles"):
            self.assertTrue(kit_recipes.PIECES[name]["cols"], name)

        for name in ("gorse_cushion", "fennel_clump", "laundry_2", "gull"):
            self.assertEqual(kit_recipes.PIECES[name]["cols"], [], name)


if __name__ == "__main__":
    unittest.main(verbosity=1)
