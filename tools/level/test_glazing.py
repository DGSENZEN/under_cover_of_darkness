"""The glazed window (tools/level/kit_glazing.py): an opening through the
wall's whole thickness, its glass set back and its lead in front, a glass
collider filling it, and the record the exporter writes: pure Python, no
Blender.

    python3 tools/level/test_glazing.py
"""

import os
import sys
import unittest

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import geo  # noqa: E402
import kit_recipes  # noqa: E402  (first: it registers every kit)
import kit_customs  # noqa: E402
import kit_glazing  # noqa: E402
import overlap  # noqa: E402
import kit_shapes  # noqa: E402


def polygon_area(points):
    """A planar polygon's area (the length of its cross-product sum)."""
    sx = sy = sz = 0.0

    for i in range(len(points)):
        a, b = points[i], points[(i + 1) % len(points)]
        sx += a[1] * b[2] - a[2] * b[1]
        sy += a[2] * b[0] - a[0] * b[2]
        sz += a[0] * b[1] - a[1] * b[0]

    return 0.5 * (sx * sx + sy * sy + sz * sz) ** 0.5


def tris(recipe):
    return sum(len(f[0]) - 2 for f in kit_shapes.build(recipe["shapes"])["faces"]) if recipe.get("shapes") else len(recipe["boxes"]) * 12


def box_holds(box, point):
    """`point` strictly inside a geo box."""
    d = [point[i] - box.centre[i] for i in range(3)]
    axes = box.axes()
    return all(abs(sum(d[i] * axes[k][i] for i in range(3))) < box.half[k] - 1e-6 for k in range(3))


def middle_of(record):
    return [sum(p[i] for p in record["outline"]) / len(record["outline"]) for i in range(3)]


def face_holds(shapes, point, tol=1e-3):
    """Some face of `shapes` passes through `point` (on its plane, inside it)."""
    built = kit_shapes.build(shapes)
    verts = built["verts"]

    for indices, _slot, _uvs in built["faces"]:
        pts = [verts[i] for i in indices]
        n = kit_shapes._normal(pts)
        length = sum(c * c for c in n) ** 0.5

        if length < 1e-9:
            continue

        n = [c / length for c in n]

        if abs(sum(n[i] * (point[i] - pts[0][i]) for i in range(3))) > tol:
            continue

        drop = max(range(3), key=lambda i: abs(n[i]))
        keep = [i for i in range(3) if i != drop]
        flat = [(p[keep[0]], p[keep[1]]) for p in pts]
        x, y = point[keep[0]], point[keep[1]]
        inside = False

        for k in range(len(flat)):
            (ax, ay), (bx, by) = flat[k], flat[(k + 1) % len(flat)]

            if (ay > y) != (by > y) and x < ax + (y - ay) * (bx - ax) / (by - ay):
                inside = not inside

        if inside:
            return True

    return False


class Glazed(unittest.TestCase):
    def setUp(self):
        self.shapes, self.cols, self.rec = kit_glazing.glazed(0.0, 1.0, 1.0, 1.7, 0.0, 0.6, shape="round", lead="quarries")

    def test_the_outline_is_a_round_head_of_eight_segments(self):
        pts = kit_glazing.outline(0.0, 1.0, 1.0, 1.7, "round")
        self.assertEqual(len(pts), 11)
        self.assertAlmostEqual(max(p[1] for p in pts), 2.7, places=6)
        self.assertAlmostEqual(pts[2][1], 2.2, places=6)  # the right springing

    def test_a_pointed_head_meets_at_the_top_and_springs_level(self):
        pts = kit_glazing.outline(2.0, 1.0, 1.0, 2.0, "arched")
        self.assertEqual(len(pts), 11)
        apex = max(pts, key=lambda p: p[1])
        self.assertAlmostEqual(apex[0], 2.0, places=6)
        self.assertAlmostEqual(apex[1], 3.0, places=6)
        self.assertAlmostEqual(pts[2][1], pts[-1][1], places=6)
        self.assertEqual((pts[2][0], pts[-1][0]), (2.5, 1.5))

    def test_the_reveals_go_through_the_whole_wall(self):
        built = kit_shapes.build(self.shapes)
        zs = [v[2] for v in built["verts"]]
        self.assertAlmostEqual(max(zs), 0.0, places=4)
        self.assertAlmostEqual(min(zs), -0.6, places=4)

    def test_the_glass_is_set_back_and_the_lead_in_front(self):
        glass = [s for s in self.shapes if s.get("slot") == "glazing"]
        lead = [s for s in self.shapes if s.get("slot") == "quarries"]
        self.assertTrue(glass and lead)
        gz = {round(p[2], 4) for s in glass for p in s["points"]}
        lz = {round(p[2], 4) for s in lead for p in s["points"]}
        self.assertEqual(gz, {-0.15})
        self.assertEqual(lz, {-0.14})

    def test_the_collider_fills_the_opening_as_glass(self):
        self.assertEqual(len(self.cols), 1)
        c = self.cols[0]
        self.assertEqual(c[6], "glass")
        self.assertEqual([round(v, 4) for v in c[:6]], [0.0, 1.85, -0.3, 1.0, 1.7, 0.6])

    def test_the_record_is_the_glass(self):
        self.assertEqual(self.rec["normal"], [0.0, 0.0, 1.0])
        self.assertEqual(self.rec["lead"], "quarries")
        self.assertEqual(len(self.rec["outline"]), 11)
        self.assertTrue(all(abs(p[2] + 0.15) < 1e-6 for p in self.rec["outline"]))
        # (How far the wall's faces are from the glass: a shaft's mouth is
        # the beam's cross-section at the room's face.)
        self.assertAlmostEqual(self.rec["outside"], 0.15, places=6)
        self.assertAlmostEqual(self.rec["inside"], 0.45, places=6)


class Walls(unittest.TestCase):
    def test_no_strip_collider_spans_a_hole(self):
        holes = [kit_glazing.hole(2.0, 1.0, 1.0, 1.5), kit_glazing.hole(5.0, 0.0, 1.2, 2.2)]
        shapes, cols = kit_glazing.strips(0.0, 8.0, 0.0, 4.0, -0.3, 0.6, holes, "whitewash")

        for c in cols:
            for x0, x1, y0, y1 in holes:
                overlap = (min(c[0] + c[3] / 2, x1) - max(c[0] - c[3] / 2, x0) > 1e-6
                           and min(c[1] + c[4] / 2, y1) - max(c[1] - c[4] / 2, y0) > 1e-6)
                self.assertFalse(overlap, c)

        area = sum(c[3] * c[4] for c in cols)
        self.assertAlmostEqual(area, 32.0 - 1.5 - 1.2 * 2.2, places=6)

    def test_around_leaves_the_holes_and_covers_the_rest(self):
        # An x-plane, narrowing upward.
        outline = [[0.0, 0.0, -2.0], [0.0, 0.0, 2.0], [0.0, 3.0, 1.6], [0.0, 3.0, -1.6]]
        holes = [(-1.5, -1.0, 1.2, 1.8), (1.0, 1.5, 1.2, 1.8)]
        faces = kit_glazing.around(outline, holes, "x", "wood_old", (1.0, 0.0, 0.0))
        area = sum(polygon_area(f["points"]) for f in faces)
        self.assertAlmostEqual(area, 0.5 * (4.0 + 3.2) * 3.0 - 2 * 0.5 * 0.6, places=4)

        for f in faces:
            n = kit_shapes._normal(f["points"])
            self.assertGreater(n[0] / sum(c * c for c in n) ** 0.5, 0.99)
            cx = sum(p[2] for p in f["points"]) / len(f["points"])
            cy = sum(p[1] for p in f["points"]) / len(f["points"])
            self.assertFalse(any(u0 < cx < u1 and v0 < cy < v1 for u0, u1, v0, v1 in holes))

    def test_moved_records_turn_like_shapes(self):
        rec = kit_glazing.glazed(0.0, 1.0, 1.0, 1.5, 0.0, 0.6)[2]
        turned = kit_glazing.moved([rec], -90.0, (10.0, 0.0, 5.0))[0]
        probe = kit_shapes.moved([kit_shapes.polygon(rec["outline"], "glazing")], -90.0, (10.0, 0.0, 5.0))[0]["points"]

        for a, b in zip(turned["outline"], probe):
            self.assertTrue(all(abs(a[i] - b[i]) < 1e-6 for i in range(3)))

        self.assertAlmostEqual(abs(turned["normal"][0]), 1.0, places=6)


class Manifest(unittest.TestCase):
    def setUp(self):
        shapes, cols, rec = kit_glazing.glazed(0.0, 1.0, 1.0, 1.5, 0.0, 0.6)
        wall = [0.0, 3.0, -0.3, 4.0, 1.0, 0.6, "stone", 0, 0, 0]
        self.recipe = {"family": "dressing", "slot": "stone", "surface": "stone", "boxes": [], "cols": cols + [wall], "windows": [rec],
                       "sockets": {}, "size": None, "opening": None, "shapes": shapes}
        self.rec = rec

    def test_windows_are_put_in_the_world(self):
        basis = [[0.0, 0.0, 1.0], [0.0, 1.0, 0.0], [-1.0, 0.0, 0.0]]  # turned 90 degrees
        pieces = [{"name": "probe", "piece": "glazing_probe", "sector": "s", "position": [10.0, 0.0, 5.0], "basis": basis},
                  {"name": "plain", "piece": "plain_probe", "sector": "s", "position": [0.0, 0.0, 0.0], "basis": geo.IDENTITY}]
        out = kit_glazing.world_windows(pieces, {"glazing_probe": self.recipe, "plain_probe": dict(self.recipe, windows=[])})
        self.assertEqual(len(out), 1)
        w = out[0]
        self.assertEqual((w["piece"], w["sector"], w["lead"]), ("probe", "s", "casement"))
        self.assertEqual((w["outside"], w["inside"]), (0.15, 0.45))
        self.assertEqual(w["normal"], [round(v, 4) for v in geo.apply(basis, [0.0, 0.0, 1.0])])
        first = geo.add([10.0, 0.0, 5.0], geo.apply(basis, self.rec["outline"][0]))
        self.assertEqual(w["outline"][0], [round(v, 4) for v in first])

    def test_glass_never_occludes(self):
        boxes = geo.piece_boxes(self.recipe, [0.0, 0.0, 0.0], geo.IDENTITY)
        self.assertEqual([b.occluder for b in boxes if b.surface == "glass"], [False])
        self.assertEqual([b.occluder for b in boxes if b.surface == "stone"], [True])


class Customs(unittest.TestCase):
    EXPECTED = {"customs_upper_front": (3, {"quarries"}), "customs_west_wall": (6, {"casement", "grille"}),
                "customs_back_wall": (6, {"casement", "grille"}), "customs_portal_wall": (2, {"grille"})}

    def test_each_wall_carries_its_windows(self):
        for name, (count, leads) in self.EXPECTED.items():
            recs = kit_recipes.PIECES[name].get("windows", [])
            self.assertEqual(len(recs), count, name)
            self.assertEqual({r["lead"] for r in recs}, leads, name)

    def test_no_collider_but_glass_spans_a_window(self):
        for name in self.EXPECTED:
            recipe = kit_recipes.PIECES[name]

            for rec in recipe["windows"]:
                mid = middle_of(rec)
                inside = [mid[i] - 0.25 * rec["normal"][i] for i in range(3)]

                for box in geo.piece_boxes(recipe, [0.0, 0.0, 0.0], geo.IDENTITY):
                    if box.surface != "glass":
                        self.assertFalse(box_holds(box, mid) or box_holds(box, inside), (name, mid))

    def test_the_back_walls_door_is_open(self):
        # (The back wall is turned 180 degrees about its east end: its door,
        # 4 m from that end along the side, stands at x X1 - 4 in the house.)
        recipe = kit_recipes.PIECES["customs_back_wall"]
        at = kit_customs.PIECE_AT["customs_back_wall"]
        door = [kit_customs.X1 - 4.0 - at[0], 1.1 - at[1], kit_customs.Z0 + kit_customs.WALL / 2.0 - at[2]]
        self.assertFalse(any(box_holds(b, door) for b in geo.piece_boxes(recipe, [0.0, 0.0, 0.0], geo.IDENTITY)))

    def test_the_loading_door_is_open_through(self):
        # (Its doorway shows the harbour from the store and the store from
        # the quay: nothing drawn across it at any depth.)
        lx, lw, lh = kit_customs.LOADING
        at = kit_customs.PIECE_AT["customs_upper_front"]
        shapes = kit_recipes.PIECES["customs_upper_front"]["shapes"]

        for z in (kit_customs.Z1 - 0.01, kit_customs.Z1 - 0.25, kit_customs.Z1 - 0.48, kit_customs.Z1 - 0.6):
            for dx in (-0.3, 0.0, 0.3):
                point = [lx + dx - at[0], kit_customs.UP + lh / 2.0 - at[1], z - at[2]]
                self.assertFalse(face_holds(shapes, point), (dx, z))

    def test_the_portals_tympanum_stays_over_its_lintel(self):
        # (A half round over the door, not a whole disc hanging into it.)
        px, pw, ph = kit_customs.PORTAL
        at = kit_customs.PIECE_AT["customs_portal_wall"]
        shapes = kit_recipes.PIECES["customs_portal_wall"]["shapes"]
        z = kit_customs.HALL_FRONT + 0.02 - at[2]

        for dx in (-0.3, 0.0, 0.3):
            self.assertFalse(face_holds(shapes, [px + dx - at[0], ph - 0.2 - at[1], z]), ("in the doorway", dx))

        self.assertTrue(face_holds(shapes, [px - at[0], ph + 0.6 - at[1], z]), "the tympanum over the lintel")

    def test_budgets_hold(self):
        for name in self.EXPECTED:
            recipe = kit_recipes.PIECES[name]
            self.assertLessEqual(tris(recipe), recipe.get("budget", kit_shapes.PIECE_TRIS), name)


class Carrack(unittest.TestCase):
    # (normal x, middle z, middle y) of her four windows: two in the
    # transom looking astern, two in the cabin's bulkhead onto the waist.
    EXPECTED = [(-1.0, 1.25, 3.6), (-1.0, -1.25, 3.6), (1.0, 1.4, 3.55), (1.0, -1.4, 3.55)]

    def setUp(self):
        self.recipe = kit_recipes.PIECES["carrack_hull"]

    def test_her_cabin_has_four_glazed_windows(self):
        recs = self.recipe.get("windows", [])
        self.assertEqual(len(recs), 4)
        self.assertEqual({r["lead"] for r in recs}, {"quarries"})
        found = sorted((round(r["normal"][0]), round(middle_of(r)[2], 2), round(middle_of(r)[1], 2)) for r in recs)
        self.assertEqual(found, sorted((n, z, y) for n, z, y in self.EXPECTED))

    def test_no_collider_but_glass_spans_a_window(self):
        for rec in self.recipe.get("windows", []):
            mid = middle_of(rec)
            inside = [mid[i] - 0.15 * rec["normal"][i] for i in range(3)]

            for box in geo.piece_boxes(self.recipe, [0.0, 0.0, 0.0], geo.IDENTITY):
                if box.surface != "glass":
                    self.assertFalse(box_holds(box, mid) or box_holds(box, inside), mid)

    def test_her_budget_holds(self):
        self.assertLessEqual(tris(self.recipe), self.recipe.get("budget", kit_shapes.PIECE_TRIS))


class Doors(unittest.TestCase):
    """A doorway cut through a wall of strips (kit_glazing.strips' `open`)
    has its reveals through the wall's whole thickness: no seeing into the
    wall's hollow at its jambs or head."""

    def test_an_open_hole_is_closed_through_the_wall(self):
        hole = kit_glazing.hole(4.0, 0.0, 1.2, 2.2)
        shapes, _cols = kit_glazing.strips(0.0, 8.0, 0.0, 4.0, -0.3, 0.6, [hole], "whitewash", open=[hole])

        for point in ([3.4, 1.1, -0.3], [4.6, 1.1, -0.3], [4.0, 2.2, -0.3], [3.4, 1.1, -0.05], [4.6, 1.1, -0.55]):
            self.assertTrue(face_holds(shapes, point), point)

    def test_the_customs_doorways_have_their_reveals(self):
        # (In the house's frame: the portal in the hall's front, the loading
        # door over the loggia, the yard door in the back wall.)
        px, pw, ph = kit_customs.PORTAL
        lx, lw, lh = kit_customs.LOADING
        up, zf = kit_customs.UP, kit_customs.HALL_FRONT - kit_customs.WALL / 2.0
        doors = {"customs_portal_wall": [[px - pw / 2.0, ph / 2.0, zf], [px + pw / 2.0, ph / 2.0, zf], [px, ph, zf]],
                 "customs_upper_front": [[lx - lw / 2.0, up + lh / 2.0, kit_customs.Z1 - 0.25], [lx + lw / 2.0, up + lh / 2.0, kit_customs.Z1 - 0.25],
                                         [lx, up + lh, kit_customs.Z1 - 0.25]],
                 "customs_back_wall": [[kit_customs.X1 - 4.6, 1.1, kit_customs.Z0 + 0.3], [kit_customs.X1 - 3.4, 1.1, kit_customs.Z0 + 0.3],
                                       [kit_customs.X1 - 4.0, 2.2, kit_customs.Z0 + 0.3]]}

        for name, points in doors.items():
            at = kit_customs.PIECE_AT[name]
            shapes = kit_recipes.PIECES[name]["shapes"]

            for p in points:
                self.assertTrue(face_holds(shapes, [p[i] - at[i] for i in range(3)]), (name, p))


class Seams(unittest.TestCase):
    def test_no_frame_or_sill_fights_a_windows_reveal(self):
        # Coplanar faces facing the same way flicker (z-fighting): none of a
        # window's own (frames, sills, reveals) may overlap another there.
        for name in ("customs_upper_front", "customs_west_wall", "customs_back_wall", "customs_portal_wall"):
            recipe = kit_recipes.PIECES[name]
            faces = []

            for owner, shape in enumerate(recipe["shapes"]):
                built = kit_shapes.build([shape])

                for indices, _slot, _uvs in built["faces"]:
                    pts = [built["verts"][i] for i in indices]
                    faces.append({"points": pts, "normal": kit_shapes._normal(pts), "owner": owner, "kind": shape["kind"]})

            near = []

            for rec in recipe["windows"]:
                lo = [min(p[i] for p in rec["outline"]) for i in range(3)]
                hi = [max(p[i] for p in rec["outline"]) for i in range(3)]
                n = rec["normal"]
                a = [lo[i] - 0.3 - abs(n[i]) * (rec["inside"] + 0.1) for i in range(3)]
                b = [hi[i] + 0.3 + abs(n[i]) * (rec["outside"] + 0.3) for i in range(3)]
                near.append((a, b))

            bad = []

            for loser, winner, area in overlap.fights(faces):
                # (The window's own faces are kit_glazing's polygons; an
                # ornament against an ornament is the kit's own business.)
                if faces[loser]["kind"] != "polygon" and faces[winner]["kind"] != "polygon":
                    continue

                mid = [sum(p[i] for p in faces[loser]["points"]) / len(faces[loser]["points"]) for i in range(3)]

                if any(all(a[i] <= mid[i] <= b[i] for i in range(3)) for a, b in near):
                    bad.append((name, [round(v, 2) for v in mid], round(area, 4)))

            self.assertEqual(bad, [], name)


if __name__ == "__main__":
    unittest.main()
