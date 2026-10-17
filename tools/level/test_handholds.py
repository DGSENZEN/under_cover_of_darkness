"""Handhold markers (free-run climbing): the schema takes the three kinds
and nothing else, and a kit piece's holds are laid as markers with it.
Pure Python, no Blender.

    python3 tools/level/test_handholds.py
"""

import os
import sys
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
sys.path.insert(0, os.path.join(HERE, "layouts"))

import markers  # noqa: E402
import kit_recipes as kit  # noqa: E402
import lay  # noqa: E402


def _marker(kind, **props):
    return {"name": "h", "ucd": "handhold", "props": dict(kind=kind, **props), "size": None}


class Schema(unittest.TestCase):
    def test_each_kind_passes(self):
        for kind in ("ledge", "pole", "point"):
            self.assertEqual(markers.problems(_marker(kind, length=2.0)), [], kind)

    def test_an_unknown_kind_fails(self):
        self.assertTrue(markers.problems(_marker("rung")))

    def test_kind_is_required(self):
        self.assertTrue(markers.problems({"name": "h", "ucd": "handhold", "props": {}, "size": None}))


class Laid(unittest.TestCase):
    def setUp(self):
        kit.PIECES["_test_facade"] = {"holds": [[0.0, 3.4, 0.15, 0.0, "ledge", 1.6], [1.0, 0.0, 0.1, 0.0, "pole", 9.0]]}

    def tearDown(self):
        kit.PIECES.pop("_test_facade", None)

    def test_put_with_holds_marks_each(self):
        layout = lay.Layout("test")
        layout.put("_test_facade", (10.0, 0.0, -5.0), holds=True)
        holds = [m for m in layout.markers if m["ucd"] == "handhold"]
        self.assertEqual(len(holds), 2)
        self.assertEqual(holds[0]["props"], {"kind": "ledge", "length": 1.6})
        self.assertAlmostEqual(holds[0]["position"][1], 3.4)
        self.assertAlmostEqual(holds[1]["position"][0], 11.0)
        self.assertEqual([markers.problems(m) for m in holds], [[], []])

    def test_put_without_holds_marks_none(self):
        layout = lay.Layout("test")
        layout.put("_test_facade", (0.0, 0.0, 0.0))
        self.assertEqual([m for m in layout.markers if m["ucd"] == "handhold"], [])


if __name__ == "__main__":
    unittest.main()
