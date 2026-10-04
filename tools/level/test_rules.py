"""The level check's rules against small levels, right and broken.

    python3 tools/level/test_rules.py
"""

import copy
import math
import os
import sys
import tempfile
import unittest

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import geo  # noqa: E402
import jobs  # noqa: E402
import kit_recipes  # noqa: E402
import rules  # noqa: E402
import terrain  # noqa: E402

I = geo.IDENTITY


def piece(name, kind, at, yaw=0.0, sector="yard"):
    return {"name": name, "piece": kind, "sector": sector, "position": list(at), "basis": geo.rotation(yaw)}


def marker(name, ucd, at, props=None, size=None, sector="yard"):
    return {"name": name, "ucd": ucd, "sector": sector, "position": list(at), "basis": I, "size": size, "props": props or {}}


def good():
    return {
        "level": "fixture",
        "pieces": [piece("floor", "floor_cobble_4", (0, 0, 0)), piece("floor2", "floor_cobble_4", (4, 0, 0)),
                   piece("wall", "wall_ashlar_4", (0, 0, -2.2))],
        "markers": [
            marker("bench_spot", "station", (0, 0, 0), {"kind": "sit"}),
            marker("round", "route", (1, 0, 1)),
            marker("round_1", "waypoint", (0.5, 0, 0.5), {"route": "round", "order": 1}),
            marker("round_2", "waypoint", (4.5, 0, 0.5), {"route": "round", "order": 2}),
            marker("Hendrik", "guard", (1, 0, 1), {"archetype": "watchman", "route": "round"}),
            marker("yard_zone", "zone", (2, 1.5, 0), {"grade": "outside"}, size=[8, 3, 4]),
        ],
    }


def checks(route, points):
    """A route's checks: [((x, y, z), move), ...] in order."""
    return [marker("%s_%d" % (route, i + 1), "route_check", at, {"route": route, "order": i + 1, "move": move})
            for i, (at, move) in enumerate(points)]


def gap_level(gap):
    """Two floors, the first to x = 2, the second from x = 2 + gap on."""
    return {"level": "fixture", "markers": [],
            "pieces": [piece("near", "floor_cobble_4", (0, 0, 0)),
                       piece("far", "floor_cobble_4", (2.0 + gap + 2.0, 0, 0)),
                       piece("far_2", "floor_cobble_4", (2.0 + gap + 6.0, 0, 0))]}


def ledge_level(top):
    """A floor in front (z > 0) of a ledge `top` high and 0.4 deep (z -0.4 to 0)."""
    name = "test_ledge_%d" % int(round(top * 100))
    kit_recipes.piece(name, "wall", "ashlar", "stone", [kit_recipes.box(0.0, top / 2.0, -0.2, 4.0, top, 0.4, "ashlar")])
    TEST_PIECES.append(name)
    return {"level": "fixture", "markers": [],
            "pieces": [piece("front", "floor_cobble_4", (0, 0, 2)), piece("ledge", name, (0, 0, 0))]}


def flat_terrain(name, y, x0, x1, z0=-4.0, z1=4.0):
    """A flat patch of terrain as a level reads it back (its triangles)."""
    a, b, c, d = [x0, y, z0], [x1, y, z0], [x1, y, z1], [x0, y, z1]
    return {"name": name, "sector": "yard", "surface": "gravel", "occluder": False, "tris": [[a, c, b], [a, d, c]]}


# Test-only pieces, removed after each test.
TEST_PIECES = []


class Rules(unittest.TestCase):
    def setUp(self):
        kit_recipes.piece("beam_low", "beam", "timber", "wood", [kit_recipes.box(0.0, 1.7, 0.0, 0.3, 0.2, 3.0, "timber")])
        kit_recipes.piece("crate_stack", "dressing", "boards", "wood", [kit_recipes.box(0.0, 1.0, 0.0, 1.0, 2.0, 1.0, "boards")])
        TEST_PIECES.extend(["beam_low", "crate_stack"])

    def tearDown(self):
        for name in TEST_PIECES:
            kit_recipes.PIECES.pop(name, None)

        TEST_PIECES.clear()

    def test_a_jump_names_its_class(self):
        # two floors 4.6 m apart edge to edge, the same height; the landing
        # 0.3 m past the far edge
        data = gap_level(4.6)
        data["markers"] += checks("leap", [((0, 0, 0), "walk"), ((6.9, 0, 0), "jump")])
        self.assertTrue(any("sprint" in p for p in rules.problems(data)))
        data["markers"][-1]["props"]["move"] = "sprint_jump"
        self.assertEqual(rules.problems(data), [])

    def test_the_uncertain_and_never_gaps(self):
        for gap, word in ((6.3, "uncertain"), (6.6, "never")):
            data = gap_level(gap)
            data["markers"] += checks("leap", [((0, 0, 0), "walk"), ((gap + 2.3, 0, 0), "assist_jump")])
            self.assertTrue(any(word in p for p in rules.problems(data)), gap)

    def test_a_hang_needs_room_under_its_lip(self):
        data = ledge_level(3.6)
        data["markers"] += checks("up", [((0, 0, 1.0), "walk"), ((0, 3.6, -0.2), "hang")])
        self.assertEqual(rules.problems(data), [])
        data["pieces"].append(piece("crate_in_the_way", "crate_stack", (0, 0, 0.6)))
        self.assertTrue(any("room under" in p for p in rules.problems(data)))

    def test_a_mantle_too_high(self):
        data = ledge_level(2.6)
        data["markers"] += checks("up", [((0, 0, 1.0), "walk"), ((0, 2.6, -0.2), "mantle")])
        self.assertTrue(any("mantle" in p and "2.6" in p for p in rules.problems(data)))

    def test_a_drop_too_far(self):
        data = ledge_level(5.0)
        data["markers"] += checks("down", [((0, 5.0, -0.2), "walk"), ((0, 0, 1.0), "drop")])
        self.assertTrue(any("drop" in p for p in rules.problems(data)))

    def test_a_guard_route_under_a_low_beam(self):
        data = good()
        data["pieces"].append(piece("beam", "beam_low", (2.5, 0, 0.5)))
        self.assertTrue(any("headroom" in p for p in rules.problems(data)))

    def test_a_locked_door_needs_its_key_or_a_pick(self):
        data = good()
        data["markers"].append(marker("office_door", "door", (0, 0, -2.2), {"locked": True, "key": "office", "pick": False}))
        self.assertTrue(any("no key 'office'" in p for p in rules.problems(data)))
        data["markers"].append(marker("office_key", "key", (0.5, 0, 0.5), {"key_id": "office"}))
        self.assertEqual(rules.problems(data), [])

    def test_a_marker_on_the_terrain(self):
        data = good()
        data["terrain"] = [flat_terrain("ground", y=0.0, x0=6, x1=14)]
        data["markers"].append(marker("on_ground", "hide", (10, 0.0, 0)))
        self.assertEqual(rules.problems(data), [])

    def test_a_marker_under_the_terrain(self):
        data = good()
        data["terrain"] = [flat_terrain("mound", y=1.2, x0=6, x1=14)]
        data["markers"].append(marker("buried", "hide", (10, 0.0, 0)))
        self.assertTrue(any("under the ground" in p for p in rules.problems(data)))

    def test_a_key_or_loot_under_the_terrain(self):
        # Not only the markers that stand: a key sculpted over is a door
        # never opened.
        data = good()
        data["terrain"] = [flat_terrain("mound", y=1.2, x0=6, x1=14)]
        data["markers"] += [marker("lost_key", "key", (10, 0.0, 0), {"key_id": "nowhere"}),
                            marker("lost_cup", "loot", (11, 0.3, 1), {"value": 10})]
        found = rules.problems(data)
        self.assertTrue(any("lost_key" in p and "under the ground" in p for p in found), found)
        self.assertTrue(any("lost_cup" in p and "under the ground" in p for p in found), found)

    def test_a_guard_deep_under_the_terrain(self):
        # On a kit floor (the quay) with the ground sculpted 3 m over it.
        data = good()
        data["terrain"] = [flat_terrain("bank", y=3.0, x0=-2, x1=2)]
        found = rules.problems(data)
        self.assertTrue(any("Hendrik" in p and "under the ground" in p for p in found), found)

    def test_a_marker_under_a_cave_roof_is_not_buried(self):
        # The ground's underside (a cave's roof, facing down at him) is over
        # him, not the ground he is under.
        data = good()
        roof = flat_terrain("cave_roof", y=3.0, x0=6, x1=14)
        roof["tris"] = [list(reversed(t)) for t in roof["tris"]]
        data["terrain"] = [flat_terrain("cave_floor", y=0.0, x0=6, x1=14), roof]
        data["markers"] += [marker("in_the_cave", "hide", (10, 0.0, 0)),
                            marker("cave_cup", "loot", (11, 0.3, 1), {"value": 10})]
        self.assertEqual(rules.problems(data), [])

    def test_a_marker_in_a_tunnel_under_the_terrain_is_not_buried(self):
        # (A sewer under a street: the first thing over him is its vault,
        # not the ground; the ground over the vault is the street's.)
        data = good()
        name = "test_tunnel_roof"
        kit_recipes.piece(name, "wall", "ashlar", "stone", [kit_recipes.box(10.0, 2.6, 0.0, 4.0, 0.2, 4.0, "ashlar"),
                                                             kit_recipes.box(10.0, -0.1, 0.0, 4.0, 0.2, 4.0, "ashlar")])
        TEST_PIECES.append(name)
        data["pieces"].append(piece("tunnel", name, (0, 0, 0)))
        data["terrain"] = [flat_terrain("street", y=3.5, x0=6, x1=14)]
        data["markers"] += [marker("in_the_sewer", "hide", (10, 0.0, 0)), marker("sewer_cup", "loot", (11, 0.3, 1), {"value": 10})]
        self.assertEqual([p for p in rules.problems(data) if "under the ground" in p], [])
        # (Out of the tunnel, under the same ground, he is buried.)
        data["markers"].append(marker("beside_it", "loot", (13.0, 0.3, 3.0), {"value": 10}))
        data["pieces"][-1] = piece("tunnel", name, (0, 0, -5))
        self.assertTrue(any("sewer_cup" in p and "under the ground" in p for p in rules.problems(data)))

    def test_the_ground_faces_up(self):
        # The generator's ground is wound to face the sky (what the rules
        # take as its top).
        ground = terrain.grid("g", "yard", 0.0, 0.0, 4.0, 4.0, 1.0, lambda x, z: 0.1 * x, lambda x, y, z, s: "grass")

        for face in ground["faces"]:
            self.assertGreater(geo.facing_up([ground["verts"][i] for i in face]), 0.0)

    def test_a_terrain_renamed_in_blender(self):
        data = good()
        data["terrain"] = [flat_terrain("bank.001", y=0.0, x0=6, x1=14)]
        self.assertTrue(any("bank.001" in p and "name" in p for p in rules.problems(data)))

    def test_a_jump_onto_the_terrain(self):
        # the far side is ground, not a piece
        data = gap_level(3.0)
        data["pieces"] = data["pieces"][:1]
        data["terrain"] = [flat_terrain("far_bank", y=0.0, x0=5.0, x1=12.0)]
        data["markers"] += checks("leap", [((0, 0, 0), "walk"), ((5.5, 0, 0), "jump")])
        self.assertEqual(rules.problems(data), [])

    def test_a_key_to_nothing(self):
        data = good()
        data["markers"].append(marker("stray", "key", (0.5, 0, 0.5), {"key_id": "nowhere"}))
        self.assertTrue(any("opens nothing" in p for p in rules.problems(data)))

    def test_a_good_level_passes(self):
        self.assertEqual(rules.problems(good()), [])

    def test_an_unknown_piece(self):
        data = good()
        data["pieces"].append(piece("odd", "wall_marble_9", (0, 0, 0)))
        self.assertTrue(any("no kit piece" in p for p in rules.problems(data)))

    def test_a_decal_of_no_known_kind(self):
        data = good()
        data["markers"].append(marker("stain", "decal", (0, 1, -2), {"kind": "graffiti"}, size=[1, 1, 0.3]))
        self.assertTrue(any("decal kind" in p for p in rules.problems(data)))
        data["markers"][-1]["props"]["kind"] = "leak_1"
        self.assertEqual(rules.problems(data), [])

    def test_a_scaled_piece(self):
        # Scaled in Blender, its mesh would export scaled but its colliders
        # come from the recipe: told, not shipped.
        data = good()
        data["pieces"][2]["scale"] = [1.0, 1.5, 1.0]
        self.assertTrue(any("wall" in p and "scaled" in p for p in rules.problems(data)))
        data["pieces"][2]["scale"] = [1.0, 1.00001, 1.0]
        self.assertEqual(rules.problems(data), [])

    def test_an_unknown_marker(self):
        data = good()
        data["markers"].append(marker("x", "teleporter", (0, 0, 0)))
        self.assertTrue(any("no marker called" in p for p in rules.problems(data)))

    def test_a_station_without_its_kind(self):
        data = good()
        data["markers"][0]["props"] = {}
        self.assertTrue(any("needs 'kind'" in p for p in rules.problems(data)))

    def test_a_guard_on_a_route_that_is_not_there(self):
        data = good()
        data["markers"][4]["props"]["route"] = "nowhere"
        self.assertTrue(any("is not a route" in p for p in rules.problems(data)))

    def test_a_route_of_one_waypoint(self):
        data = good()
        data["markers"] = [m for m in data["markers"] if m["name"] != "round_2"]
        self.assertTrue(any("two waypoints" in p for p in rules.problems(data)))

    def test_a_station_in_the_air(self):
        data = good()
        data["markers"][0]["position"] = [0, 3.0, 0]
        self.assertTrue(any("no floor under it" in p for p in rules.problems(data)))

    def test_a_station_in_a_wall(self):
        data = good()
        data["markers"][0]["position"] = [0, 0, -2.2]
        self.assertTrue(any("inside something" in p for p in rules.problems(data)))

    def test_a_box_marker_without_its_size(self):
        data = good()
        data["markers"][5]["size"] = None
        self.assertTrue(any("needs a size" in p for p in rules.problems(data)))

    def test_a_turned_piece_turns_its_colliders(self):
        # A wall turned a quarter turn at x = 3 stands across x, not z.
        data = good()
        data["pieces"].append(piece("side", "wall_ashlar_4", (3.0, 0, 0), yaw=90.0))
        data["markers"][0]["position"] = [3.0, 0, 1.0]
        self.assertTrue(any("inside something" in p for p in rules.problems(data)))

    def test_over_budget(self):
        data = good()
        data["tris"] = {"floor_cobble_4": 70000}
        self.assertTrue(any("triangles" in p for p in rules.problems(data)))

    def test_two_markers_one_name(self):
        data = good()
        data["markers"].append(copy.deepcopy(data["markers"][0]))
        self.assertTrue(any("two markers have this name" in p for p in rules.problems(data)))

    def test_the_new_markers_pass_when_right(self):
        data = good()
        data["markers"] += [
            marker("purse", "loot", (0.5, 0, 0.5), {"value": 25}),
            marker("seal", "loot", (1.0, 0, 0.5), {"value": 0, "special": True, "kind": "seal", "label": "the harbourmaster's seal"}),
            marker("office_key", "key", (1.5, 0, 0.5), {"key_id": "office"}),
            marker("office_door", "door", (0, 0, -2.2), {"locked": True, "key": "office"}),
            marker("flask", "tool", (2.0, 0, 0.5), {"tool": "flask", "count": 2}),
            marker("crate_1", "prop", (2.5, 0, 0.5), {"kind": "crate"}),
            marker("rope_1", "rope", (3.0, 4, 0.5), {"length": 4.0}),
            marker("roar", "noise_zone", (0, 1, 0), {"db": 30.0}, size=[4, 3, 4]),
            marker("gate_up", "portcullis", (0, 0, -2), {"state": "up"}),
            marker("to_old_town", "exit", (0, 1, 1), {"label": "the old town"}, size=[2, 2, 2]),
            marker("see_moon", "probe", (1, 1, 1), {"expect": "moon"}),
            marker("chimney", "smoke", (2, 9, 2), {}),
        ]
        self.assertEqual(rules.problems(data), [])

    def test_an_unknown_property(self):
        data = good()
        data["markers"][0]["props"]["colour"] = "red"
        self.assertTrue(any("no property 'colour'" in p for p in rules.problems(data)))

    def test_bad_enums(self):
        for ucd, props, word in (("tool", {"tool": "grenade"}, "tool"), ("prop", {"kind": "piano"}, "prop kind"),
                                 ("probe", {"expect": "sun"}, "expect"), ("guard", {"archetype": "watchman", "light": "flare"}, "light")):
            data = good()
            data["markers"].append(marker("odd", ucd, (0.5, 0, 0.5), props))
            self.assertTrue(any(word in p for p in rules.problems(data)), ucd)

    def test_the_city_layouts_check_clean(self):
        # The harbour and the city's massing, as their layouts make them.
        sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "layouts"))
        import city_harbour  # noqa: E402
        import city_massing  # noqa: E402

        for module in (city_harbour, city_massing):
            data = module.layout()
            self.assertEqual(rules.problems(data, "stage2"), [], data["level"])

    def test_the_headland_stands_over_its_cave_not_the_mole(self):
        # The east headland (the harbour's ground): its rock over the
        # smugglers' cave, the blowhole's mouth up on it, the mole and the
        # channel before the cliff open to the sky; each cliff faces the sea
        # (inland was turned the wrong way: the plateau lay over the mole and
        # the cave in the open sea).
        sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "layouts"))
        from harbour import ground  # noqa: E402

        for x, z in ((230.0, 26.0), (229.0, 10.0), (226.0, 40.0)):
            self.assertGreater(ground.headland(x, z), 20.0, (x, z))

        self.assertGreater(ground.headland(232.0, 6.0), 20.0)

        for x, z in ((165.0, 60.0), (172.0, 100.0), (190.0, 60.0), (176.0, 118.0)):
            self.assertLess(ground.headland(x, z), 0.0, (x, z))

        for a, b in zip(ground.COAST, ground.COAST[1:]):
            dx, dz = b[0] - a[0], b[1] - a[1]
            length = (dx * dx + dz * dz) ** 0.5
            face = (dz / length, -dx / length)
            mx, mz = (a[0] + b[0]) / 2.0, (a[1] + b[1]) / 2.0
            self.assertLess(ground.headland(mx + face[0] * 6.0, mz + face[1] * 6.0), 0.0, (a, b))
            self.assertGreater(ground.headland(mx - face[0] * 3.0, mz - face[1] * 3.0), 20.0, (a, b))

    def test_the_cave_opens_through_its_cliff(self):
        # The smugglers' cave runs into the headland through the gap in its
        # cliff (its first stretch square to the cliff, its mouth the gap's
        # width), the rock round its arch filling the gap; its chest and loot
        # inside it (it ran along behind the cliff, its side showing in the
        # gap: a flat slab, not a mouth).
        sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "layouts"))
        from harbour import ground  # noqa: E402
        import city_harbour  # noqa: E402

        a, b = ground.COAST[ground.MOUTH[0]], ground.COAST[ground.MOUTH[1]]
        gap = math.hypot(b[0] - a[0], b[1] - a[1])
        sea = ((b[1] - a[1]) / gap, -(b[0] - a[0]) / gap)
        (x0, _, z0), (x1, _, z1) = ground.CAVE[0], ground.CAVE[1]
        run = math.hypot(x1 - x0, z1 - z0)
        self.assertGreater(-((x1 - x0) * sea[0] + (z1 - z0) * sea[1]) / run, math.cos(math.radians(15.0)))
        self.assertAlmostEqual(2.0 * ground.CAVE_RADII[0][0], gap, delta=1.0)
        data = city_harbour.layout()
        mouth = [t for t in data["terrain"] if t["name"] == "cave_mouth"]
        self.assertTrue(mouth and mouth[0]["faces"])

        def inside(x, z):
            for (ax, _, az), (bx, _, bz), ra, rb in zip(ground.CAVE, ground.CAVE[1:], ground.CAVE_RADII, ground.CAVE_RADII[1:]):
                dx, dz = bx - ax, bz - az
                t = max(0.0, min(1.0, ((x - ax) * dx + (z - az) * dz) / (dx * dx + dz * dz)))

                if math.hypot(x - ax - dx * t, z - az - dz * t) < ra[0] + (rb[0] - ra[0]) * t - 0.8:
                    return True

            return False

        for m in data["markers"]:
            if m["name"] in ("smugglers_chest", "brandy", "lace", "silver_dish", "probe_beach"):
                self.assertTrue(inside(m["position"][0], m["position"][2]), m["name"])

    def test_the_blowhole_opens_in_a_funnel_of_rock(self):
        # Its shaft ends under the headland's top (it stood 3 m out of it, a
        # stone box), flaring into a funnel wider than the hole cut in the
        # ground round it.
        sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "layouts"))
        from harbour import BLOWHOLE, ground  # noqa: E402
        import city_harbour  # noqa: E402

        data = city_harbour.layout()
        shaft = [t for t in data["terrain"] if t["name"] == "blowhole_shaft"][0]
        top = max(v[1] for v in shaft["verts"])
        rim = min(ground.headland(BLOWHOLE[0] + 6.0 * math.cos(a), BLOWHOLE[1] + 6.0 * math.sin(a)) for a in [i * math.pi / 8 for i in range(16)])
        self.assertLess(top, rim)
        land = geo.TriGrid(terrain.triangles([t for t in data["terrain"] if t["name"] == "east_headland"][0]))
        hole = max(math.hypot(dx * 0.25, dz * 0.25) for dx in range(-36, 37) for dz in range(-36, 37)
                   if math.hypot(dx * 0.25, dz * 0.25) < 9.0 and not land.heights(BLOWHOLE[0] + dx * 0.25, BLOWHOLE[1] + dz * 0.25))
        funnel = max(math.hypot(v[0] - BLOWHOLE[0], v[2] - BLOWHOLE[1]) for v in shaft["verts"])
        self.assertGreater(funnel, hole)

    def test_the_rivers_banks_step_up_in_strata(self):
        # Both banks of the river granite in strata, steep faces over ledges
        # (the east bank was one smooth 30 m slab up to the Guindais stair).
        sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "layouts"))
        from harbour import ground  # noqa: E402

        for bank, x0, x1 in ((ground.west_bank, -258.0, -236.0), (ground.east_bank, -193.0, -186.0)):
            for z in (-30.0, -60.0, -90.0):
                xs = [x0 + (x1 - x0) * i / 140.0 for i in range(141)]
                ys = [bank(x, z) for x in xs]
                slopes = [math.degrees(math.atan2(abs(b - a), (x1 - x0) / 140.0)) for a, b in zip(ys, ys[1:])]
                faces = sum(1 for a, b in zip(slopes, slopes[1:]) if a <= 50.0 < b)
                ledges = sum(1 for s in slopes if s < 20.0)
                self.assertGreaterEqual(faces, 3, (bank.__name__, z))
                self.assertGreater(ledges, 20, (bank.__name__, z))

    def test_the_kit_keeps_the_metrics(self):
        self.assertEqual(rules.kit_problems(), [])

    def test_every_piece_is_well_formed(self):
        for name, recipe in kit_recipes.PIECES.items():
            for b in recipe["boxes"] + recipe["cols"]:
                self.assertGreaterEqual(len(b), 7, name)
                self.assertTrue(all(s > 0.0 for s in b[3:6]), name)


class Readables(unittest.TestCase):
    """A readable marker names a slot in its district's job file (the
    harbour's job plan, Task 3)."""

    def _harbour(self, slot, kind="notice"):
        data = good()
        data["level"] = "city_harbour"
        data["markers"].append(marker("r", "readable", (0.5, 0, 0.5), {"slot": slot, "kind": kind}))
        return data

    def test_readable_slot_known(self):
        found = rules.problems(self._harbour("curfew"))
        self.assertEqual([p for p in found if p.startswith("r")], [])

    def test_readable_slot_unknown(self):
        found = rules.problems(self._harbour("nope"))
        self.assertIn("r: reads slot 'nope', not in the district's job file", found)

    def test_readable_kind_checked(self):
        found = rules.problems(self._harbour("curfew", "scroll"))
        self.assertTrue(any(p.startswith("r:") and "scroll" in p for p in found), found)

    def test_readable_outside_a_district(self):
        data = good()
        data["markers"].append(marker("r", "readable", (0.5, 0, 0.5), {"slot": "curfew"}))
        self.assertIn("r: a readable in a level of no district", rules.problems(data))

    def test_jobs_reads_headers(self):
        with tempfile.TemporaryDirectory() as folder:
            with open(os.path.join(folder, "x.job"), "w") as f:
                f.write("# a comment\n== readable a\ntext: hm\n\n== note b\ntext: hm\n")

            self.assertEqual(jobs.readable_slots("x", folder), {"a"})
            self.assertEqual(jobs.readable_slots("nowhere", folder), set())


if __name__ == "__main__":
    unittest.main(verbosity=1)
