"""A district's proxy: the low-poly stand-in other maps draw far off.

    python3 tools/level/test_proxy.py
"""

import os
import sys
import unittest

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "layouts"))

import proxy  # noqa: E402
from test_rules import marker, piece  # noqa: E402


def level(*pieces, markers=()):
    return {"level": "fixture", "pieces": list(pieces), "markers": list(markers)}


class Proxy(unittest.TestCase):
    def test_small_dressing_is_left_out(self):
        self.assertEqual(proxy.boxes(level(piece("barrel", "barrel", (0, 0, 0)))), [])

    def test_the_shared_edge_is_left_out(self):
        self.assertEqual(proxy.boxes(level(piece("wall", "city_wall_12_6", (0, 0, 0)))), [])

    def test_a_house_keeps_its_slot(self):
        found = proxy.boxes(level(piece("house", "casa_a", (0, 0, 0))))
        self.assertGreater(len(found), 0)
        self.assertTrue(all(slot == "azulejo_green" for _box, slot in found))
        self.assertTrue(all(max(box.half) * 2.0 >= proxy.PROXY_MIN for box, _slot in found))

    def test_the_harbours_proxy_is_cheap(self):
        import city_harbour
        self.assertLessEqual(12 * len(proxy.boxes(city_harbour.layout())), proxy.PROXY_TRIS)

    def test_windows_are_the_window_lights(self):
        lit = marker("lit", "light", (1.0, 4.0, 2.0), {"kind": "window"})
        torch = marker("torch", "light", (3.0, 2.0, 2.0), {"kind": "torch"})
        self.assertEqual(proxy.windows(level(markers=[lit, torch])), [[1.0, 4.0, 2.0]])


if __name__ == "__main__":
    unittest.main()
