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
