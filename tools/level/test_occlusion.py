"""Visual occlusion choices must not remove movement colliders."""
import unittest

import geo
import kit_recipes


class Occlusion(unittest.TestCase):
    def test_crane_wheel_keeps_collision_without_sealing_its_opening(self):
        boxes = geo.piece_boxes(kit_recipes.PIECES["crane_jib"], [132, 2.5, -3], geo.IDENTITY)
        self.assertEqual(len(boxes), 3)
        wheel = boxes[2]
        self.assertEqual(wheel.centre, [130.7, 4.7, -3.0])
        self.assertEqual(wheel.half, [0.55, 2.0, 2.0])
        self.assertTrue(wheel.contains(wheel.centre))
        self.assertFalse(getattr(wheel, "occluder", True))

    def test_solid_wall_retains_default_occlusion(self):
        boxes = geo.piece_boxes(kit_recipes.PIECES["mass_palace"], [0, 0, 0], geo.IDENTITY)
        self.assertTrue(all(getattr(box, "occluder", True) for box in boxes))

    def test_rotated_crane_keeps_the_same_occlusion_choice(self):
        boxes = geo.piece_boxes(kit_recipes.PIECES["crane_jib"], [20, 0, 10], geo.rotation(90))
        self.assertFalse(getattr(boxes[2], "occluder", True))
        self.assertAlmostEqual(boxes[2].centre[0], 20)
        self.assertAlmostEqual(boxes[2].centre[2], 11.3)


if __name__ == "__main__":
    unittest.main()
