"""The way to the fort (layouts/harbour/spit.py): the bridge from the quay
and the causeway along the spit, whole underfoot, walled, open under its
arches. Pure Python, no Blender.

    python3 tools/level/test_spit.py
"""

import math
import os
import sys
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
sys.path.insert(0, os.path.join(HERE, "layouts"))

from harbour import CAUSEWAY, QUAY, spit  # noqa: E402
from harbour.sweep import mitred  # noqa: E402
from test_mole import _hit, _normal  # noqa: E402


class Spit(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        m = spit.body()
        cls.tris = [tuple(m.verts[i] for i in f) for f in m.faces]
        cls.slots = m.slots

    def _down(self, x, z):
        hit = _hit(self.tris, [x, 20.0, z], [0.0, -1.0, 0.0])
        return None if hit is None else 20.0 - hit[0]

    def _along(self, step=1.0):
        """Points every `step` m along the way's middle line, from the top
        of the bridge's steps to the bastion: [(x, z, (dx, dz))]."""
        line = [(CAUSEWAY[0][0], CAUSEWAY[0][1] + spit.STEPS[0] * spit.STEPS[1] + 0.2)] + list(CAUSEWAY[1:])
        out = []

        for (x0, z0), (x1, z1) in zip(line, line[1:]):
            length = math.hypot(x1 - x0, z1 - z0)
            d = ((x1 - x0) / length, (z1 - z0) / length)

            for i in range(int(length / step)):
                out.append((x0 + d[0] * i * step, z0 + d[1] * i * step, d))

        return out

    def test_its_deck_is_whole_underfoot_to_the_bastion(self):
        holes = []

        for x, z, d in self._along():
            for s in (-2.2, 0.0, 2.2):
                px, pz = x + d[1] * s, z - d[0] * s
                y = self._down(px, pz)

                if y is None or abs(y - spit.DECK) > 1e-3:
                    holes.append((round(px, 1), round(pz, 1), y and round(y, 2)))

        self.assertEqual(holes, [])

    def test_its_steps_climb_from_the_quay(self):
        n, tread = spit.STEPS
        rise = (spit.DECK - QUAY) / n
        tops = [round(self._down(CAUSEWAY[0][0], CAUSEWAY[0][1] + tread * (k + 0.5)), 3) for k in range(n)]
        self.assertEqual(tops, [round(QUAY + rise * (k + 1), 3) for k in range(n)])
        self.assertLessEqual(rise, 0.2)

    def test_it_is_walled_both_sides_all_the_way(self):
        # From its middle at a man's waist, out either side: a parapet's
        # inner face (further out over a refuge), never open.
        open_at = []

        for x, z, d in self._along(2.0):
            # (At a bend a ray sideways runs down the other stretch.)
            if min(math.hypot(x - cx, z - cz) for cx, cz in CAUSEWAY[1:-1]) < 3.5:
                continue

            for side in (-1.0, 1.0):
                out = [d[1] * side, 0.0, -d[0] * side]
                hit = _hit(self.tris, [x, spit.DECK + 0.5, z], out)

                if hit is None or hit[0] > spit.HALF + spit.CUT + 0.1:
                    open_at.append((round(x, 1), round(z, 1), side))

        self.assertEqual(open_at, [])

    def test_its_arches_leave_the_water_open(self):
        # Under each span's middle, across the bridge at the water: nothing.
        for a0, a1 in spit.spans():
            z = CAUSEWAY[0][1] + (a0 + a1) / 2.0
            self.assertIsNone(_hit(self.tris, [CAUSEWAY[0][0] - 10.0, 0.5, z], [1.0, 0.0, 0.0]), (a0, a1))
            # (Its soffit over: the arch's crown under the deck.)
            up = _hit(self.tris, [CAUSEWAY[0][0], 0.5, z], [0.0, 1.0, 0.0])
            self.assertIsNotNone(up)
            self.assertAlmostEqual(0.5 + up[0], spit.SPRING + spit.RISE, delta=0.05)

    def test_its_faces_look_out(self):
        wrong = []

        for (a, b, c), slot in zip(self.tris, self.slots):
            n = _normal(a, b, c)
            flat = abs(a[1] - b[1]) < 1e-6 and abs(b[1] - c[1]) < 1e-6

            # (The deck and the refuges' floors up; the caps' tops up.)
            if flat and abs(a[1] - spit.DECK) < 1e-6 and n[1] < 0.99:
                wrong.append(("deck", [round(v, 2) for v in a]))

        self.assertEqual(wrong, [])

    def test_it_meets_the_bastion_at_its_gate(self):
        x, z = CAUSEWAY[-1]
        self.assertAlmostEqual(self._down(x, z - 0.05), spit.DECK, places=3)
        # (Its parapets end in the bastion's face, square to it.)
        line = mitred(spit._causeway_line())
        self.assertAlmostEqual(line[-1][3][0], 0.0, places=6)


if __name__ == "__main__":
    unittest.main()
