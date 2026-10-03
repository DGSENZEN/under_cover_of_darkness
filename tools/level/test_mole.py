"""The mole, swept along its line (layouts/harbour/mole.py): whole round its
bend, ending on its head's flats. Pure Python, no Blender.

    python3 tools/level/test_mole.py
"""

import math
import os
import sys
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
sys.path.insert(0, os.path.join(HERE, "layouts"))

from harbour import mole  # noqa: E402


def _hit(tris, origin, direction):
    """The nearest of `tris` a ray meets: (distance, triangle index) or
    None."""
    best = None

    for k, (a, b, c) in enumerate(tris):
        e1 = [b[i] - a[i] for i in range(3)]
        e2 = [c[i] - a[i] for i in range(3)]
        p = [direction[1] * e2[2] - direction[2] * e2[1], direction[2] * e2[0] - direction[0] * e2[2], direction[0] * e2[1] - direction[1] * e2[0]]
        det = sum(e1[i] * p[i] for i in range(3))

        if abs(det) < 1e-12:
            continue

        t0 = [origin[i] - a[i] for i in range(3)]
        u = sum(t0[i] * p[i] for i in range(3)) / det

        if u < -1e-9 or u > 1.0 + 1e-9:
            continue

        q = [t0[1] * e1[2] - t0[2] * e1[1], t0[2] * e1[0] - t0[0] * e1[2], t0[0] * e1[1] - t0[1] * e1[0]]
        v = sum(direction[i] * q[i] for i in range(3)) / det

        if v < -1e-9 or u + v > 1.0 + 1e-9:
            continue

        t = sum(e2[i] * q[i] for i in range(3)) / det

        if t > 1e-6 and (best is None or t < best[0]):
            best = (t, k)

    return best


def _normal(a, b, c):
    n = [(b[1] - a[1]) * (c[2] - a[2]) - (b[2] - a[2]) * (c[1] - a[1]), (b[2] - a[2]) * (c[0] - a[0]) - (b[0] - a[0]) * (c[2] - a[2]),
         (b[0] - a[0]) * (c[1] - a[1]) - (b[1] - a[1]) * (c[0] - a[0])]
    length = math.sqrt(sum(x * x for x in n)) or 1.0
    return [x / length for x in n]


class Mole(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        verts, faces, slots = mole.body()
        cls.tris = [tuple(verts[i] for i in f) for f in faces]
        cls.slots = slots
        cls.stations = mole.line()
        cls.outline = mole.head_outline()

    def _along(self):
        """Points along the middle line every 1.5 m, to the head's outline:
        [(x, z, (dx, dz))]."""
        out = []

        for a, b in zip(self.stations, self.stations[1:]):
            length = math.hypot(b[0] - a[0], b[1] - a[1])

            for i in range(max(1, int(length / 1.5))):
                f = i / max(1, int(length / 1.5))
                out.append((a[0] + (b[0] - a[0]) * f, a[1] + (b[1] - a[1]) * f, a[2]))

        return out

    def test_its_top_is_whole_underfoot_round_the_bend_to_the_head(self):
        holes = []

        for x, z, d in self._along():
            sea = mole._sea(d)

            for s in (-7.15, -5.0, -2.0, 0.0, 2.5, 5.5):
                p = (x + sea[0] * s, z + sea[1] * s)

                if mole._inside(self.outline, p):
                    continue

                hit = _hit(self.tris, [p[0], 10.0, p[1]], [0.0, -1.0, 0.0])

                if hit is None or abs((10.0 - hit[0]) - mole.TOP) > 1e-3:
                    holes.append((round(p[0], 2), round(p[1], 2), s, None if hit is None else round(10.0 - hit[0], 2)))

        self.assertEqual(holes, [])

    def test_its_parapet_runs_unbroken_to_the_head(self):
        # From its top toward the sea, a man's height up: the parapet's face.
        gaps = []

        for x, z, d in self._along():
            sea = mole._sea(d)
            p = (x + sea[0] * 4.0, z + sea[1] * 4.0)

            # (Where it meets the head, along the head's outline: its end.)
            if any(mole._inside(self.outline, (x + sea[0] * s, z + sea[1] * s)) for s in (5.75, 7.05)):
                continue

            hit = _hit(self.tris, [p[0], 4.5, p[1]], [sea[0], 0.0, sea[1]])

            if hit is None or abs(hit[0] - 1.8) > 0.05 or self.slots[hit[1]] != "granite_rough":
                gaps.append((round(x, 1), round(z, 1), hit and round(hit[0], 2)))

        self.assertEqual(gaps, [])

    def test_its_faces_look_out(self):
        # The top's faces up, the harbour face's toward the harbour, the
        # parapet's cap up: none turned inside out.
        wrong = 0

        for (a, b, c), slot in zip(self.tris, self.slots):
            n = _normal(a, b, c)
            y = (a[1] + b[1] + c[1]) / 3.0

            if slot == "granite" and abs(y - mole.TOP) < 1e-6 and abs(a[1] - b[1]) < 1e-6 and abs(b[1] - c[1]) < 1e-6 and n[1] < 0.99:
                wrong += 1

        self.assertEqual(wrong, 0)

    def test_nothing_of_it_is_inside_the_head(self):
        inside = []

        for tri in self.tris:
            middle = [(tri[0][i] + tri[1][i] + tri[2][i]) / 3.0 for i in range(3)]

            if mole._inside(self.outline, (middle[0], middle[2]), 0.01):
                inside.append([round(m, 2) for m in middle])

        self.assertEqual(inside, [])

    def test_it_meets_the_head_all_the_way_across(self):
        # Along the last stretch, just short of the head: its top; just
        # past its ends (on the head's outline), the head.
        d = self.stations[-1][2]
        sea = mole._sea(d)
        short = []

        for s in [k * 0.5 - 7.0 for k in range(26)]:
            far = (self.stations[-1][0] + sea[0] * s, self.stations[-1][1] + sea[1] * s)
            back = (far[0] - d[0] * 30.0, far[1] - d[1] * 30.0)
            t = mole._enter(self.outline, back, d)
            p = (back[0] + d[0] * (t - 0.05), back[1] + d[1] * (t - 0.05))
            hit = _hit(self.tris, [p[0], 10.0, p[1]], [0.0, -1.0, 0.0])

            if hit is None or abs((10.0 - hit[0]) - mole.TOP) > 1e-3:
                short.append(s)

        self.assertEqual(short, [])


if __name__ == "__main__":
    unittest.main()
