"""The old town's street furniture (plan B1a, Task 8; kit_street): corner
lamps' arms, shrines and their lamps, tile panels of the comet and the
forgotten king, fountains and their water.

    python3 tools/level/test_street.py
"""

import os
import sys
import unittest

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import kit_recipes  # noqa: E402
import kit_street  # noqa: E402,F401
from test_kits import tris  # noqa: E402

PIECES = kit_recipes.PIECES


def cards(name, slot):
    return [s for s in PIECES[name]["shapes"] if s["kind"] == "card" and s["slot"] == slot]


def drawn_over(name, step=0.1, slack=0.15, skip=()):
    """Where the piece (at the origin) draws an upward face more than
    `slack` over its colliders' top (or over none), sampled every `step`
    across its reach, `skip` slots (glass, water) left out: [(x, z, drawn,
    solid)]."""
    import geo
    import kit_shapes
    recipe = PIECES[name]
    built = kit_shapes.build(recipe["shapes"])
    v = built["verts"]
    tris_ = []

    for face in built["faces"]:
        if face[1] in skip:
            continue

        ring = face[0]
        tris_ += [(v[ring[0]], v[ring[i]], v[ring[i + 1]]) for i in range(1, len(ring) - 1)]

    boxes = geo.piece_boxes(recipe, [0.0, 0.0, 0.0], geo.IDENTITY)
    xs, zs = [p[0] for p in v], [p[2] for p in v]
    out = []
    # (Off the grid of exact edges a box's face would graze.)
    x = min(xs) + step / 2.0 + 0.0037

    while x < max(xs):
        z = min(zs) + step / 2.0 + 0.0041

        while z < max(zs):
            drawn = None

            for a, b, c in tris_:
                area = (b[0] - a[0]) * (c[2] - a[2]) - (b[2] - a[2]) * (c[0] - a[0])

                if abs(area) < 1e-9:
                    continue

                u = ((b[0] - x) * (c[2] - z) - (b[2] - z) * (c[0] - x)) / area
                w = ((c[0] - x) * (a[2] - z) - (c[2] - z) * (a[0] - x)) / area

                if u >= -1e-9 and w >= -1e-9 and u + w <= 1.0 + 1e-9:
                    y = u * a[1] + w * b[1] + (1.0 - u - w) * c[1]
                    drawn = y if drawn is None else max(drawn, y)

            if drawn is not None:
                hits = [t for t in (box.ray([x, 50.0, z], [0.0, -1.0, 0.0]) for box in boxes) if t is not None]
                solid = 50.0 - min(hits) if hits else None

                if solid is None or drawn - solid > slack:
                    out.append((round(x, 2), round(z, 2), round(drawn, 2), solid))

            z += step

        x += step

    return out


def solid_over(name, step=0.05, slack=0.15, near=0.1):
    """Where the piece's colliders stand more than `slack` over anything
    drawn within `near` of the point (an invisible wall or step):
    [(x, z, solid, drawn)]."""
    import geo
    import kit_shapes
    recipe = PIECES[name]
    built = kit_shapes.build(recipe["shapes"])
    v = built["verts"]
    tris_ = []

    for face in built["faces"]:
        ring = face[0]
        tris_ += [(v[ring[0]], v[ring[i]], v[ring[i + 1]]) for i in range(1, len(ring) - 1)]

    def drawn_at(x, z):
        best = None

        for a, b, c in tris_:
            area = (b[0] - a[0]) * (c[2] - a[2]) - (b[2] - a[2]) * (c[0] - a[0])

            if abs(area) < 1e-9:
                continue

            u = ((b[0] - x) * (c[2] - z) - (b[2] - z) * (c[0] - x)) / area
            w = ((c[0] - x) * (a[2] - z) - (c[2] - z) * (a[0] - x)) / area

            if u >= -1e-9 and w >= -1e-9 and u + w <= 1.0 + 1e-9:
                y = u * a[1] + w * b[1] + (1.0 - u - w) * c[1]
                best = y if best is None else max(best, y)

        return best

    boxes = geo.piece_boxes(recipe, [0.0, 0.0, 0.0], geo.IDENTITY)
    lo = [min(b.centre[i] - sum(abs(b.axes()[j][i]) * b.half[j] for j in range(3)) for b in boxes) for i in range(3)]
    hi = [max(b.centre[i] + sum(abs(b.axes()[j][i]) * b.half[j] for j in range(3)) for b in boxes) for i in range(3)]
    out = []
    x = lo[0] + step / 2.0 + 0.0037

    while x < hi[0]:
        z = lo[2] + step / 2.0 + 0.0041

        while z < hi[2]:
            hits = [t for t in (box.ray([x, 50.0, z], [0.0, -1.0, 0.0]) for box in boxes) if t is not None]

            if hits:
                solid = 50.0 - min(hits)
                around = [drawn_at(x + dx, z + dz) for dx in (-near, 0.0, near) for dz in (-near, 0.0, near)]
                drawn = max([d for d in around if d is not None], default=None)

                if drawn is None or solid - drawn > slack:
                    out.append((round(x, 2), round(z, 2), round(solid, 2), drawn))

            z += step

        x += step

    return out


class Street(unittest.TestCase):
    def test_street_pieces_hold_no_invisible_walls(self):
        # (No collider stands where nothing is drawn: a fountain's round
        # steps are stopped round, not by squares whose corners stand out
        # past them.)
        for name in ("fountain_bowls", "fountain_carmo", "fountain_wall", "shrine_alminha", "shrine_retablo"):
            self.assertEqual(solid_over(name)[:5], [], name)

    def test_street_pieces_are_solid_where_drawn(self):
        # (A man brushing past a shrine, a fountain's bowl or a lifted
        # grate meets the stone and iron he sees; the water and the glass
        # are not stood on.)
        import kit_terrace
        names = ["fountain_bowls", "fountain_wall", "fountain_carmo", "shrine_alminha", "shrine_retablo", "corner_lamp",
                 kit_terrace.grate_hatch(0.3, 2.5)]

        for name in names:
            self.assertEqual(drawn_over(name, skip=("glass_dark", "water")), [], name)

    def test_the_lookouts_bench_is_stone_with_a_tiled_back(self):
        # (The miradouro's azulejo bench: a stone seat at a sitter's height,
        # its back tiled blue, solid where drawn and nowhere else.)
        recipe = PIECES["bench_azulejo"]
        tiled = [s for s in recipe["shapes"] if s.get("slot") == "azulejo_blue"]
        self.assertTrue(tiled)
        self.assertTrue(any(abs(s["centre"][1] + s["size"][1] / 2.0 - 0.45) < 0.03 for s in recipe["shapes"] if s["kind"] == "box"))
        self.assertEqual(drawn_over("bench_azulejo"), [])
        self.assertEqual(solid_over("bench_azulejo")[:5], [])
        self.assertLessEqual(tris(recipe), 300)

    def test_the_pergola_is_walked_under(self):
        # (Stone piers along its two sides, timber beams across them and
        # joists along over a man's head: under it a man walks.)
        import geo
        recipe = PIECES["pergola"]
        self.assertEqual(drawn_over("pergola"), [])
        self.assertEqual(solid_over("pergola")[:5], [])
        boxes = geo.piece_boxes(recipe, [0.0, 0.0, 0.0], geo.IDENTITY)
        self.assertFalse(any(b.contains([0.0, y, 0.0], 0.45) for b in boxes for y in (0.3, 1.0, 1.9)))
        self.assertTrue(any(s.get("slot") == "timber" for s in recipe["shapes"]))
        self.assertGreaterEqual(recipe["size"][1], 2.6)

    def test_a_panel_is_4_by_6_tiles(self):
        for name, slot in (("panel_comet", "azulejo_comet"), ("panel_king", "azulejo_king")):
            face = cards(name, slot)
            self.assertEqual(len(face), 1, name)
            self.assertAlmostEqual(face[0]["size"][0], 0.56, delta=0.01)
            self.assertAlmostEqual(face[0]["size"][1], 0.84, delta=0.01)
            self.assertTrue(any(s["slot"] == "tile_frame" for s in PIECES[name]["shapes"]), name)

    def test_a_shrine_has_its_lamp(self):
        lamp = PIECES["shrine_alminha"]["sockets"]["lamp"][0]
        niche = kit_street.NICHE
        self.assertLessEqual(abs(lamp[0]), niche[0] / 2.0)
        self.assertTrue(kit_street.NICHE_SILL <= lamp[1] <= kit_street.NICHE_SILL + niche[1])
        self.assertTrue(cards("shrine_alminha", "azulejo_souls"))
        retablo = PIECES["shrine_retablo"]["sockets"]["lamp"][0]
        self.assertAlmostEqual(retablo[1], 2.5, delta=0.3)
        self.assertTrue(cards("shrine_retablo", "azulejo_comet"))

    def test_a_shrines_painting_shows_on_its_wall(self):
        # (The shrine is laid on a solid front, its wall's face at z 0: its
        # painting lies on that face, the surround and sill standing out
        # round it, the votive lamp before the painting on the sill.)
        king = cards("shrine_alminha", "azulejo_souls")[0]
        surround = [sh for sh in PIECES["shrine_alminha"]["shapes"] if sh["kind"] == "box" and sh["slot"] == "granite"]
        front = min(sh["centre"][2] + sh["size"][2] / 2.0 for sh in surround)
        self.assertTrue(0.0 < king["centre"][2] < 0.05, king["centre"])
        self.assertTrue(all(sh["centre"][2] - sh["size"][2] / 2.0 >= -0.01 for sh in surround))
        lamp = PIECES["shrine_alminha"]["sockets"]["lamp"][0]
        self.assertTrue(king["centre"][2] + 0.05 < lamp[2] <= front, (lamp, front))

    def test_the_corner_lamp_hangs_two_lanterns_from_its_arm(self):
        hooks = PIECES["corner_lamp"]["sockets"]["lamp"]
        self.assertEqual(len(hooks), 2)
        self.assertTrue(all(abs(h[1] - kit_street.ARM_HEIGHT) < 0.2 and h[2] > 0.6 for h in hooks))

    def test_the_rossio_fountain_has_a_rimmed_basin(self):
        # (A square's fountain: water standing below a coped rim wall with
        # an inside, a thick upper bowl, the whole on two steps.)
        from test_terrace import _tri
        import kit_shapes
        recipe = PIECES["fountain_bowls"]
        water = recipe["sockets"]["water"][0]
        built = kit_shapes.build(recipe["shapes"])
        v = built["verts"]

        def hits(origin, direction):
            out = []

            for face in built["faces"]:
                if face[1] == "glass_dark":
                    continue

                ring = face[0]

                for i in range(1, len(ring) - 1):
                    t = _tri(origin, direction, v[ring[0]], v[ring[i]], v[ring[i + 1]])

                    if t is not None:
                        out.append(t)

            # (One surface once, where the ray crosses two triangles' edge.)
            unique = []

            for t in sorted(out):
                if not unique or t - unique[-1] > 1e-3:
                    unique.append(t)

            return unique

        # (Out from the middle just over the water: the rim's inside face.)
        out = hits([0.0, water[1] + 0.05, 1.2], [0.0, 0.0, 1.0])
        self.assertTrue(out and 0.6 <= out[0] <= 1.4, out)
        rim = 10.0 - hits([0.0, 10.0, 2.25], [0.0, -1.0, 0.0])[0]
        self.assertGreater(rim, water[1] + 0.1)
        # (Down through the upper bowl: its top and its underside.)
        bowl = hits([0.75, 10.0, 0.0], [0.0, -1.0, 0.0])
        self.assertTrue(len(bowl) >= 2 and bowl[1] - bowl[0] >= 0.04, bowl)
        # (The two steps it stands on.)
        self.assertAlmostEqual(10.0 - hits([0.0, 10.0, 3.1], [0.0, -1.0, 0.0])[0], 0.18, delta=0.02)
        self.assertAlmostEqual(10.0 - hits([0.0, 10.0, 2.75], [0.0, -1.0, 0.0])[0], 0.36, delta=0.02)

    def test_fountains_have_their_water(self):
        for name in ("fountain_carmo", "fountain_wall", "fountain_bowls"):
            self.assertTrue(PIECES[name]["sockets"].get("water"), name)
            self.assertTrue(PIECES[name]["cols"], name)

    def test_street_budget(self):
        for name, most in (("fountain_wall", 500), ("fountain_bowls", 900), ("fountain_carmo", 2000), ("corner_lamp", 300),
                           ("shrine_alminha", 300), ("shrine_retablo", 300), ("panel_comet", 120), ("panel_king", 120)):
            self.assertLessEqual(tris(PIECES[name]), most, name)
            self.assertLessEqual(tris(PIECES[name]), PIECES[name].get("budget", 800), name)


if __name__ == "__main__":
    unittest.main()
