"""The old town's grammar (plan B1a, Task 2; kit_town): the grid, fronts
true to what opens (an honest opening leaves its wall whole, a live one is a
way through), floors, stairs that climb a storey, rooms with doors between
them, roofs that are stood on.

    python3 tools/level/test_town.py
"""

import os
import sys
import unittest

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import geo  # noqa: E402
import kit_recipes  # noqa: E402
import kit_shapes  # noqa: E402
import kit_town  # noqa: E402
import rules  # noqa: E402
from test_rules import checks, marker, piece  # noqa: E402

Opening = kit_town.Opening


def boxes(cols):
    """A design's colliders as world boxes (the piece at the origin)."""
    return geo.piece_boxes({"cols": cols}, [0.0, 0.0, 0.0], geo.IDENTITY)


def clear(cols, a, b):
    """No collider between a and b (a segment's ray)."""
    d = [b[i] - a[i] for i in range(3)]
    length = sum(c * c for c in d) ** 0.5
    unit = [c / length for c in d]
    return all(t is None or t > length for t in (box.ray(a, unit) for box in boxes(cols)))


def first_hit_cols(cols, origin, direction):
    hits = [t for t in (b.ray(origin, direction) for b in boxes(cols)) if t is not None]
    return min(hits) if hits else None


def stood_on(shapes, cols):
    """The roof faces (slot roof*, facing up) with no collider within 0.45 m
    under their middle: [] when every one is stood on."""
    built = kit_shapes.build(shapes)
    under = boxes(cols)
    sunk = []

    for face in built["faces"]:
        points = [built["verts"][i] for i in face[0]]

        if not face[1].startswith("roof") or kit_shapes._normal(points)[1] <= 0.5 * sum(c * c for c in kit_shapes._normal(points)) ** 0.5:
            continue

        middle = [sum(p[i] for p in points) / len(points) for i in range(3)]
        hits = [t for t in (box.ray([middle[0], middle[1] + 0.05, middle[2]], [0.0, -1.0, 0.0]) for box in under) if t is not None]

        if not hits or min(hits) > 0.5:
            sunk.append([round(c, 2) for c in middle])

    return sunk


class Grammar(unittest.TestCase):
    def tearDown(self):
        for name in ("test_stair", "test_top_floor", "test_foot_floor"):
            kit_recipes.PIECES.pop(name, None)

    def test_the_grid_snaps(self):
        self.assertEqual(kit_town.snap(4.26), 4.5)
        self.assertEqual(kit_town.snap(4.24), 4.0)
        self.assertEqual(kit_town.snap(4.25), 4.5)

    def test_an_honest_opening_leaves_the_wall_whole(self):
        for kind in kit_town.HONEST:
            shapes, cols = kit_town.wall(6.0, 7.0, 0.6, [Opening(0.0, 3.0, 1.25, 1.5, kind)], "render_ochre")
            self.assertFalse(clear(cols, [0.0, 3.75, 2.0], [0.0, 3.75, -2.0]), kind)
            self.assertTrue(shapes, kind)

    def test_a_live_door_is_a_way_through(self):
        _shapes, cols = kit_town.wall(6.0, 7.0, 0.6, [Opening(0.0, 0.0, 1.2, 2.2, "door")], "render_ochre")

        for y in (0.2, 1.0, 2.0):
            self.assertTrue(clear(cols, [0.0, y, 2.0], [0.0, y, -2.0]), y)

        # (Beside it, and over it, the wall.)
        self.assertFalse(clear(cols, [1.2, 1.0, 2.0], [1.2, 1.0, -2.0]))
        self.assertFalse(clear(cols, [0.0, 2.6, 2.0], [0.0, 2.6, -2.0]))

    def test_a_placed_wall_turns_with_its_place(self):
        # (Turned 90 degrees and set at x 5: its door faces +x there.)
        _shapes, cols = kit_town.wall(6.0, 7.0, 0.6, [Opening(0.0, 0.0, 1.2, 2.2, "door")], "render_ochre", (5.0, 0.0, 90.0))
        self.assertTrue(clear(cols, [7.0, 1.0, 0.0], [3.0, 1.0, 0.0]))
        self.assertFalse(clear(cols, [7.0, 1.0, 1.5], [3.0, 1.0, 1.5]))

    def test_a_stair_climbs_a_storey(self):
        shapes, cols = kit_town.stair("two_flight", 1.0, 3.2, (0.0, 0.0, 0.0), 0.0)
        kit_town.register("test_stair", "town", "flagstone", {"shapes": shapes, "cols": cols, "size": [2.0, 3.2, 5.0]})
        reach = kit_town.stair_reach("two_flight", 1.0, 3.2)
        # (The floor it starts from, before its foot, and the floor it comes
        # out on, behind its second flight's head.)
        kit_recipes.piece("test_foot_floor", "floor", "flagstone", "stone", [kit_recipes.box(-0.5, -0.1, -1.0, 1.0, 0.2, 2.0, "flagstone")])
        kit_recipes.piece("test_top_floor", "floor", "flagstone", "stone", [kit_recipes.box(0.5, 3.1, -1.0, 1.0, 0.2, 2.0, "flagstone")])
        data = {"level": "fixture", "pieces": [piece("stair", "test_stair", (0, 0, 0)), piece("foot", "test_foot_floor", (0, 0, 0)),
                                               piece("top", "test_top_floor", (0, 0, 0))],
                "markers": checks("up", [((-0.5, 0.0, -0.5), "walk"), ((-0.5, reach["landing"], reach["run"] + 0.5), "stairs"),
                                         ((0.5, reach["landing"], reach["run"] + 0.5), "walk"), ((0.5, 3.2, -0.5), "stairs")])}
        self.assertEqual(rules.problems(data), [])

    def test_rooms_leave_doors_between_them(self):
        # Three rooms down a 6 x 12 plan, a door between each pair.
        plan = [(-3.0, -6.0, 3.0, -2.0), (-3.0, -2.0, 3.0, 2.0), (-3.0, 2.0, 3.0, 6.0)]
        _shapes, cols = kit_town.rooms(plan, 0.0, 3.2, [(1.5, -2.0), (-1.5, 2.0)])
        self.assertTrue(clear(cols, [1.5, 1.0, -4.0], [1.5, 1.0, 0.0]))
        self.assertTrue(clear(cols, [-1.5, 1.0, 0.0], [-1.5, 1.0, 4.0]))
        # (And a partition, where there is no door.)
        self.assertFalse(clear(cols, [-1.5, 1.0, -4.0], [-1.5, 1.0, 0.0]))

    def test_floors_leave_the_stair_hole(self):
        _shapes, cols = kit_town.floors(6.0, 12.0, [3.2], (-3.0, -6.0, -1.0, -1.0))
        self.assertTrue(clear(cols, [-2.0, 4.0, -3.0], [-2.0, 2.0, -3.0]))
        self.assertFalse(clear(cols, [1.0, 4.0, 3.0], [1.0, 2.0, 3.0]))

    def test_every_roof_kind_is_stood_on(self):
        for kind in kit_town.ROOFS:
            shapes, cols = kit_town.roof(kind, 6.0, 12.0, 10.0, 27.0, "render_ochre")
            self.assertTrue(shapes, kind)
            self.assertEqual(stood_on(shapes, cols), [], kind)

    def test_a_walked_in_wall_is_plastered_inside(self):
        # (A tiled or rendered front is plaster on its room's side; a stone
        # wall is stone through.)
        for slot, inner in (("azulejo_blue", "plaster"), ("render_ochre", "plaster"), ("granite", "granite")):
            shapes, _cols = kit_town.wall(6.0, 3.0, 0.6, [Opening(0.0, 0.0, 1.2, 2.2, "door")], slot, inside=True)
            back = [sh["slot"] for sh in shapes if sh.get("kind") == "polygon" and all(abs(p[2] + 0.3) < 1e-6 for p in sh["points"])]
            front = [sh["slot"] for sh in shapes if sh.get("kind") == "polygon" and all(abs(p[2] - 0.3) < 1e-6 for p in sh["points"])]
            self.assertTrue(back and set(back) == {inner}, (slot, set(back)))
            self.assertEqual(set(front), {slot})

    def test_a_ground_floor_stands_proud_of_the_street(self):
        # (The street's ground runs on under a house: a floor drawn on it
        # would flicker with it.)
        _shapes, cols = kit_town.floors(4.0, 4.0, [0.0, 3.2])
        tops = sorted({round(c[1] + c[4] / 2.0, 4) for c in cols})
        self.assertEqual(tops, [kit_town.GROUND_LIFT, 3.2])
        self.assertTrue(0.01 <= kit_town.GROUND_LIFT <= 0.05)

    def test_a_walked_in_walls_honest_openings_are_closed_inside(self):
        # (From the room, a barred door or a shut window is a niche closed
        # at its back: no look into the wall's hollow and out past the back
        # of its outer face, which is not drawn from inside.)
        from test_terrace import _tri
        for kind in ("barred", "shut", "lit"):
            shapes, _cols = kit_town.wall(6.0, 3.0, 0.6, [Opening(0.0, 0.0, 1.2, 2.2, kind)], "render_ochre", inside=True)
            built = kit_shapes.build(shapes)
            v = built["verts"]

            def first_front(origin, direction):
                best = None

                for face in built["faces"]:
                    ring = face[0]
                    n = kit_shapes._normal([v[i] for i in ring])

                    if sum(n[i] * direction[i] for i in range(3)) >= 0.0:
                        continue

                    for i in range(1, len(ring) - 1):
                        t = _tri(origin, direction, v[ring[0]], v[ring[i]], v[ring[i + 1]])

                        if t is not None and (best is None or t < best):
                            best = t

                return best

            for x in (0.3, 0.55, -0.55):
                origin = [x - 1.5 * (1.0 if x > 0 else -1.0), 1.0, -2.0]
                aim = [x + 0.3 * (1.0 if x > 0 else -1.0), 1.0, 0.1]
                d = [aim[i] - origin[i] for i in range(3)]
                length = sum(c * c for c in d) ** 0.5
                d = [c / length for c in d]
                t = first_front(origin, d)
                self.assertIsNotNone(t, (kind, x))
                self.assertLess(origin[2] + d[2] * t, 0.3 - 0.01, (kind, x))

    def test_a_gables_verges_are_capped(self):
        # (The canal tiles' open ends along a verge show the sky between
        # them where the neighbour is lower: a coping covers them, solid.)
        import math
        from test_terrace import _tri
        eaves, pitch, width, depth = 10.0, 27.0, 6.0, 12.0
        shapes, cols = kit_town.roof("gable", width, depth, eaves, pitch, "granite")
        built = kit_shapes.build(shapes)
        v = built["verts"]
        tan, lift = math.tan(math.radians(pitch)), kit_recipes.ROOF_THICK / math.cos(math.radians(pitch))

        def meets(origin, direction, reach):
            for face in built["faces"]:
                ring = face[0]

                for i in range(1, len(ring) - 1):
                    t = _tri(origin, direction, v[ring[0]], v[ring[i]], v[ring[i + 1]])

                    if t is not None and t <= reach:
                        return True

            return False

        for side in (-1.0, 1.0):
            for d in (0.5, 2.0, 4.0, 5.5):
                for s in (-1.0, 1.0):
                    y = eaves + d * tan + lift + 0.09
                    z = s * (depth / 2.0 - d)
                    self.assertTrue(meets([side * (width / 2.0 + 1.0), y, z], [-side, 0.0, 0.0], 1.35), (side, d, s))
                    self.assertIsNotNone(first_hit_cols(cols, [side * (width / 2.0 - 0.1), y + 1.0, z], [0.0, -1.0, 0.0]))
                    self.assertLess(first_hit_cols(cols, [side * (width / 2.0 - 0.1), y + 1.0, z], [0.0, -1.0, 0.0]), 1.0, (side, d, s))

    def test_a_mansard_is_closed_at_its_ends(self):
        # (Its steep lower slopes end at the party walls: an end drawn up
        # from the eaves to its gable, or the sky shows through beside a
        # lower neighbour.)
        from test_terrace import _tri
        shapes, _cols = kit_town.roof("mansard", 6.0, 12.0, 10.0, 27.0, "render_ochre")
        built = kit_shapes.build(shapes)
        v = built["verts"]

        def meets(origin, direction):
            for face in built["faces"]:
                ring = face[0]

                for i in range(1, len(ring) - 1):
                    if _tri(origin, direction, v[ring[0]], v[ring[i]], v[ring[i + 1]]) is not None:
                        return True

            return False

        for side in (-1.0, 1.0):
            for y, z in ((10.5, 5.0), (11.5, -4.5), (12.2, 0.0)):
                self.assertTrue(meets([side * 8.0, y, z], [-side, 0.0, 0.0]), (side, y, z))

    def test_a_mansards_steep_slopes_stop_a_man_where_drawn(self):
        # (Its lower slopes lean out 65 degrees over its eaves: what stops
        # a man there is the slope, not the wall's top under it.)
        import math
        eaves, (lower, _upper) = 10.0, kit_town.MANSARD
        _shapes, cols = kit_town.roof("mansard", 6.0, 12.0, eaves, 27.0, "render_ochre")
        under = boxes(cols)
        inset = kit_town.MANSARD_HEIGHT / math.tan(math.radians(lower))

        for side in (-1.0, 1.0):
            for k in range(1, 8):
                d = inset * k / 8.0
                drawn = eaves + d * math.tan(math.radians(lower))
                hits = [t for t in (box.ray([0.5, 30.0, side * (6.0 - d)], [0.0, -1.0, 0.0]) for box in under) if t is not None]
                top = 30.0 - min(hits) if hits else eaves
                self.assertGreaterEqual(top, drawn - 0.4, (side, d))
                self.assertLessEqual(top, drawn + 0.35, (side, d))

    def test_a_hipped_roof_is_stood_on_where_it_is_drawn(self):
        # (Its colliders' top over every point of its plan: never over its
        # tiles, never more than a hand's breadth under them; a slab under
        # a hip's slope stops at the hip, not at the roof's side.)
        import math

        for kind, width, depth in (("four", 13.0, 7.5), ("hipped", 7.5, 13.0), ("four", 10.0, 10.0)):
            eaves, pitch = 10.0, 27.0
            _shapes, cols = kit_town.roof(kind, width, depth, eaves, pitch, "render_ochre")
            under = boxes(cols)
            tan, lift = math.tan(math.radians(pitch)), kit_recipes.ROOF_THICK / math.cos(math.radians(pitch))

            for i in range(1, 26):
                for j in range(1, 26):
                    x, z = -width / 2.0 + width * i / 26.0, -depth / 2.0 + depth * j / 26.0
                    true = eaves + min(width / 2.0 - abs(x), depth / 2.0 - abs(z)) * tan + lift
                    hits = [t for t in (box.ray([x, 30.0, z], [0.0, -1.0, 0.0]) for box in under) if t is not None]
                    top = 30.0 - min(hits)
                    self.assertLessEqual(top, true + 0.03, (kind, x, z))
                    self.assertGreaterEqual(top, true - 0.4, (kind, x, z))

    def test_register_carries_the_designs_keys(self):
        shapes, cols = kit_town.wall(6.0, 3.0, 0.6, [Opening(0.0, 0.0, 1.2, 2.2, "door")], "render_ochre")
        name = kit_town.register("test_stair", "town", "render_ochre", {"shapes": shapes, "cols": cols, "size": [6.0, 3.0, 0.6],
                                                                        "doors": [[0.0, 0.0, 0.3, 0.0]], "chimneys": [[1.0, 9.0, 0.0]],
                                                                        "places": {"altar": [0.0, 0.0, 0.0]}})
        recipe = kit_recipes.PIECES[name]
        self.assertEqual(recipe["doors"], [[0.0, 0.0, 0.3, 0.0]])
        self.assertEqual(recipe["sockets"], {"chimney": [[1.0, 9.0, 0.0]]})
        self.assertEqual(recipe["places"], {"altar": [0.0, 0.0, 0.0]})
        self.assertEqual(recipe["family"], "town")


if __name__ == "__main__":
    unittest.main()
