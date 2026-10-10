"""The street and canal kit's shared dimensions (street_dims.py), which the
pieces' scripts and the district's dresser both read.

    python3 tools/eclipse/test_street_dims.py
"""

import math
import os
import sys
import unittest

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import street_dims  # noqa: E402


def _area(polygon):
    return abs(sum(a[0] * b[1] - b[0] * a[1] for a, b in zip(polygon, polygon[1:] + polygon[:1]))) / 2.0


class Dims(unittest.TestCase):
    def test_curve_centreline(self):
        line = street_dims.curve_centreline(16)
        self.assertEqual(len(line), 17)
        self.assertAlmostEqual(line[0][0], 0.0)
        self.assertAlmostEqual(line[0][1], 0.0)
        self.assertAlmostEqual(line[-1][0], 12.0)
        self.assertAlmostEqual(line[-1][1], 12.0)

        for x, y in line:
            self.assertAlmostEqual(math.hypot(x, y - 12.0), 12.0)

    def test_curve_footprint(self):
        outline = street_dims.footprint("tram_track_curve")
        self.assertAlmostEqual(_area(outline), 2.4 * math.pi / 2 * 12, delta=0.01 * 2.4 * math.pi / 2 * 12)

    def test_pitches(self):
        for piece, pitch in street_dims.PITCH.items():
            self.assertIn(pitch, (3.0,) if piece == "causeway_band" else (1.5, 4.5), piece)

    def test_flush_footprints(self):
        self.assertEqual(street_dims.footprint("tram_track"), [(0.0, -1.2), (4.5, -1.2), (4.5, 1.2), (0.0, 1.2)])
        self.assertAlmostEqual(_area(street_dims.footprint("hatch")), 1.44)
        self.assertAlmostEqual(_area(street_dims.footprint("causeway_band")), 9.0)


if __name__ == "__main__":
    unittest.main()
