"""The Zócalo's plan (layouts/city_zocalo.py) against its spec
(docs/superpowers/specs/2026-10-10-zocalo-district-design.md, section 3).

    python3 tools/level/test_zocalo_plan.py
"""

import os
import sys
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
sys.path.insert(0, os.path.join(HERE, "layouts"))

import city_zocalo  # noqa: E402
import plan  # noqa: E402
import plan_check  # noqa: E402

DATA = city_zocalo.plan()


def _bounds(polygons):
    xs = [p[0] for poly in polygons for p in poly]
    zs = [p[1] for poly in polygons for p in poly]
    return min(xs), min(zs), max(xs), max(zs)


def _ground(name):
    return next(g for g in DATA["ground"] if g["name"] == name)


def _plots(family):
    return [p for p in DATA["plots"] if p["family"] == family]


def _space(name):
    return next(s for s in DATA["spaces"] if s["name"] == name)


class Plan(unittest.TestCase):
    def test_the_plan_is_clean(self):
        problems = plan_check.check(DATA)
        self.assertEqual(problems, [], "\n".join(problems))

    def test_plaza_size(self):
        x0, z0, x1, z1 = _bounds([_ground("plaza")["polygon"]])
        self.assertAlmostEqual(x1 - x0, 200, delta=1)
        self.assertAlmostEqual(z1 - z0, 220, delta=1)

        for side in ("north_street", "south_street", "west_street", "east_street"):
            sx0, sz0, sx1, sz1 = _bounds([_ground(side)["polygon"]])
            self.assertAlmostEqual(min(sx1 - sx0, sz1 - sz0), 20, delta=1, msg=side)

        ring = [_ground(s)["polygon"] for s in ("north_street", "south_street", "west_street", "east_street")]
        self.assertGreaterEqual(len(DATA["tram"]), 4)

        for p in DATA["tram"]:
            self.assertTrue(any(plan_check.near(p, r, 0.01) for r in ring), p)

    def test_canal(self):
        canal = _ground("canal")
        x0, z0, x1, z1 = _bounds([canal["polygon"]])
        self.assertGreater(x1 - x0, z1 - z0)
        self.assertAlmostEqual(z1 - z0, 12, delta=1)
        self.assertEqual(canal["level"], -2.0)
        self.assertGreater(z0, _bounds([_ground("plaza")["polygon"]])[3])
        bridges = [r for r in DATA["routes"] if r["kind"] == "bridge"]
        self.assertEqual(len(bridges), 3)

        for b in bridges:
            zs = sorted(p[2] for p in b["points"])
            self.assertLess(zs[0], z0)
            self.assertGreater(zs[-1], z1)

    def test_north(self):
        church = _plots("cathedral") + _plots("sagrario")
        x0, _, x1, _ = _bounds([p["polygon"] for p in church])
        self.assertTrue(100 <= x1 - x0 <= 130, x1 - x0)
        dig = [g for g in DATA["ground"] if g["kind"] == "dig"]
        dx0, dz0, dx1, dz1 = _bounds([g["polygon"] for g in dig])
        self.assertAlmostEqual(dx1 - dx0, 90, delta=5)
        self.assertAlmostEqual(dz1 - dz0, 80, delta=5)
        cx, cz = plan.centroid([(dx0, dz0), (dx1, dz0), (dx1, dz1), (dx0, dz1)])
        cathedral = plan.centroid(_plots("cathedral")[0]["polygon"])
        self.assertGreater(cx, cathedral[0])
        self.assertLessEqual(cz, cathedral[1] + 40)
        tower = _plots("deco_tower")[0]
        tx, tz = plan.centroid(tower["polygon"])
        self.assertTrue(dx0 < tx < dx1 and dz0 < tz < dz1)
        self.assertGreaterEqual(tower["height"], 60)
        sd = _ground("santo_domingo")
        sx0, sz0, sx1, sz1 = _bounds([sd["polygon"]])
        self.assertEqual(sd["kind"], "plaza")
        self.assertAlmostEqual(sx1 - sx0, 60, delta=5)
        self.assertAlmostEqual(sz1 - sz0, 80, delta=5)
        self.assertTrue(-270 <= (sz0 + sz1) / 2 <= -230)
        inquisition = _plots("inquisition")[0]
        self.assertGreaterEqual(len(inquisition["polygon"]), 5)
        self.assertTrue(plan_check.convex(inquisition["polygon"]))
        ix, iz = plan.centroid(inquisition["polygon"])
        self.assertTrue(ix > (sx0 + sx1) / 2 and iz > (sz0 + sz1) / 2)

    def test_palace(self):
        palace = _plots("palace")
        x0, z0, x1, z1 = _bounds([p["polygon"] for p in palace])
        self.assertAlmostEqual(z1 - z0, 200, delta=10)
        self.assertAlmostEqual(x1 - x0, 80, delta=5)
        self.assertGreater(x0, _bounds([_ground("plaza")["polygon"]])[2])

    def test_west(self):
        plaza_x0 = _bounds([_ground("plaza")["polygon"]])[0]
        arcade = [p for p in _plots("arcade") if plan.centroid(p["polygon"])[0] < plaza_x0]
        _, z0, _, z1 = _bounds([p["polygon"] for p in arcade])
        self.assertTrue(28 * 4.5 <= z1 - z0 <= 32 * 4.5, z1 - z0)
        madero = _ground("madero")
        mx0, mz0, mx1, mz1 = _bounds([madero["polygon"]])
        self.assertEqual(madero["kind"], "street")
        self.assertAlmostEqual(mz1 - mz0, 15, delta=1)
        self.assertLess(mx0, plaza_x0 - 100)
        self.assertTrue(_plots("pawnshop") and _plots("iturbide"))

    def test_station(self):
        hall = _space("station_hall")
        x0, z0, x1, z1 = _bounds([hall["polygon"]])
        self.assertAlmostEqual(x1 - x0, 60, delta=2)
        self.assertAlmostEqual(z1 - z0, 30, delta=2)
        self.assertEqual(hall["floor"], -8.0)
        platforms = [s for s in DATA["spaces"] if s["name"].startswith("platform")]
        self.assertTrue(platforms)
        self.assertTrue(all(s["floor"] == -14.0 for s in platforms))
        entrances = [m for m in DATA["landmarks"] if m["kind"] == "metro_entrance"]
        self.assertEqual(len(entrances), 4)
        px0, pz0, px1, pz1 = _bounds([_ground("plaza")["polygon"]])

        for corner in ((px0, pz0), (px1, pz0), (px0, pz1), (px1, pz1)):
            near = [m for m in entrances if abs(m["at"][0] - corner[0]) <= 30 and abs(m["at"][-1] - corner[1]) <= 30]
            self.assertEqual(len(near), 1, corner)
            wells = [g for g in DATA["ground"] if g["kind"] == "well"
                     and plan_check.near((near[0]["at"][0], near[0]["at"][-1]), g["polygon"], 1.0)]
            self.assertEqual(len(wells), 1, corner)
            stairs = [r for r in DATA["routes"] if r["kind"] == "stair"
                      and any(plan_check.near((p[0], p[2]), wells[0]["polygon"], 0.5) for p in r["points"])]
            self.assertTrue(stairs, corner)

        tunnels = {tuple(sorted(r["between"])) for r in DATA["routes"] if r["kind"] == "tunnel"}
        self.assertIn(("crypt", "station_hall"), tunnels)
        self.assertIn(("crypt", "templo_shells"), tunnels)

    def test_platform_cut_off_without_its_stair(self):
        # The east platform lines up with the west one; that must not join them.
        cut = dict(DATA, routes=[r for r in DATA["routes"] if r["name"] != "platform_e_stair"],
                   spaces=[dict(s, openings=[o for o in s["openings"] if o["to"] != "platform_e"]) for s in DATA["spaces"]])
        problems = plan_check.check(cut)
        self.assertTrue(any("platform_e" in p for p in problems), problems)

    def test_stairs_start_at_the_edge_they_drop_from(self):
        # A stair's top lies on the edge of what it goes down into (no slot
        # between the floor it leaves and the stair).
        lower = {g["name"]: g["polygon"] for g in DATA["ground"]}
        lower.update({s["name"]: s["polygon"] for s in DATA["spaces"]})

        for r in DATA["routes"]:
            if r["kind"] != "stair":
                continue

            top, bottom = sorted(r["points"], key=lambda p: -p[1])[0], sorted(r["points"], key=lambda p: p[1])[0]
            into = [n for n, poly in lower.items() if plan_check.inside((bottom[0], bottom[2]), poly)
                    and n in plan_check.reach(DATA) and _level(n) == bottom[1]]
            self.assertTrue(into, r["name"])
            self.assertLessEqual(plan_check.boundary_distance((top[0], top[2]), lower[into[0]]), 0.05, r["name"])

    def test_canal_walkway(self):
        """The canal's lower walkway (spec 3.3): a room along the canal's
        south side under the quay and market, a step below the canal's floor,
        tall enough to walk, opening on to the canal, which the street's
        landings reach."""
        walk = _space("canal_walkway")
        reached = plan_check.reach(DATA)
        _, cz0, _, cz1 = _bounds([_ground("canal")["polygon"]])
        _, wz0, _, _ = _bounds([walk["polygon"]])
        self.assertAlmostEqual(wz0, cz1, delta=0.01)
        self.assertLessEqual(walk["floor"], -2.0)
        self.assertGreaterEqual(walk["height"], 2.2)
        self.assertLess(walk["floor"] + walk["height"], 0.0)
        self.assertGreaterEqual(sum(1 for o in walk["openings"] if o["to"] == "canal"), 2)
        self.assertIn("canal", reached)
        self.assertIn("canal_walkway", reached)

    def test_doors(self):
        """Every interior a player goes into has a door on its outline that
        opens on to the street (or a plaza, courtyard or atrium)."""
        doors = [m for m in DATA["landmarks"] if m["kind"] == "door"]
        street = [g for g in DATA["ground"] if g["kind"] in plan.FRONTAGE_KINDS and abs(g["level"]) < 1e-6]

        for p in DATA["plots"]:
            if not p["interior"]:
                continue

            mine = [d for d in doors if plan_check.boundary_distance((d["at"][0], d["at"][-1]), p["polygon"]) <= 0.05]
            self.assertTrue(mine, p["name"])
            c = plan.centroid(p["polygon"])
            at = (mine[0]["at"][0], mine[0]["at"][-1])
            dx, dz = at[0] - c[0], at[1] - c[1]
            length = (dx * dx + dz * dz) ** 0.5
            # Look outward along the face it sits on: a metre out is street.
            out = (at[0] + dx / length * 0.01, at[1] + dz / length * 0.01)
            self.assertTrue(any(plan_check.near(out, g["polygon"], 1.0) for g in street), p["name"])

    def test_interiors(self):
        inside = {p["name"] for p in DATA["plots"] if p["interior"]} | {s["name"] for s in DATA["spaces"]
                                                                         if s["interior"]}
        inside |= {g["name"] for g in DATA["ground"] if g["kind"] == "courtyard"}

        for name in ("pawnshop", "pawn_vault", "inquisition_rooms", "palace_courtyard", "scribe_office"):
            self.assertIn(name, inside)

    def test_houses(self):
        houses = _plots("house")
        self.assertGreaterEqual(len(houses), 40)
        self.assertTrue(all(h["storeys"] in (2, 3) for h in houses))

    def test_size(self):
        x0, z0, x1, z1 = _bounds([DATA["brink"]])
        self.assertTrue(600 <= x1 - x0 <= 660)
        self.assertTrue(600 <= z1 - z0 <= 660)

    def test_events_shape_the_map(self):
        field = lambda kind, at: plan.field(DATA, kind, *at)
        cathedral = plan.centroid(_plots("cathedral")[0]["polygon"])
        palace = plan.centroid(_bounds_poly([p["polygon"] for p in _plots("palace")]))
        canal = plan.centroid(_ground("canal")["polygon"])
        hall = plan.centroid(_space("station_hall")["polygon"])
        market = plan.centroid(_ground("market_lanes_n")["polygon"])
        self.assertGreaterEqual(field("subsidence", cathedral), 0.6)
        self.assertLess(field("subsidence", palace), 0.2)
        self.assertGreaterEqual(field("water", (0, canal[1])), 0.6)
        self.assertGreaterEqual(field("seepage", hall), 0.6)
        self.assertGreaterEqual(field("seepage", palace), 0.6)
        self.assertGreaterEqual(field("use", market), 0.4)

    def test_cameras(self):
        cameras = [m for m in DATA["landmarks"] if m["kind"] == "camera"]
        self.assertGreaterEqual(len(cameras), 8)

        for c in cameras:
            self.assertTrue(plan_check.near((c["at"][0], c["at"][-1]), DATA["brink"], 0.01), c["name"])
            self.assertIn("look_at", c["props"])

    def test_spawn_on_the_south_ring(self):
        spawn = [m for m in DATA["landmarks"] if m["kind"] == "spawn"]
        self.assertEqual(len(spawn), 1)
        self.assertTrue(plan_check.near((spawn[0]["at"][0], spawn[0]["at"][-1]), _ground("south_street")["polygon"], 0))


def _level(name):
    for g in DATA["ground"]:
        if g["name"] == name:
            return g["level"]

    return next(s["floor"] for s in DATA["spaces"] if s["name"] == name)


def _bounds_poly(polygons):
    x0, z0, x1, z1 = _bounds(polygons)
    return [(x0, z0), (x1, z0), (x1, z1), (x0, z1)]


if __name__ == "__main__":
    unittest.main()
