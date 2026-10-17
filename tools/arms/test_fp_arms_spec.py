"""The first-person arms' spec (tools/arms/build_fp_arms.py SPEC): a real
arm's proportions and every bone the arm solver needs. Pure Python.

    python3 tools/arms/test_fp_arms_spec.py
"""

import os
import sys
import unittest

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import build_fp_arms  # noqa: E402

SPEC = build_fp_arms.SPEC


class Spec(unittest.TestCase):
    def test_arm_is_a_real_arms_length(self):
        self.assertAlmostEqual(SPEC["upper"] + SPEC["fore"], 0.65, places=3)
        self.assertAlmostEqual(SPEC["upper"], 0.34, places=3)

    def test_shoulders_apart(self):
        self.assertAlmostEqual(SPEC["shoulder_width"], 0.38, places=3)

    def test_every_bone_the_solver_needs(self):
        names = build_fp_arms.bone_names()
        self.assertEqual(len(names), 39)
        for side in ("l", "r"):
            for bone in ("clavicle", "upperarm", "lowerarm", "hand"):
                self.assertIn("%s_%s" % (bone, side), names)
            for finger in ("index", "middle", "ring", "pinky", "thumb"):
                for joint in ("01", "02", "03"):
                    self.assertIn("%s_%s_%s" % (finger, joint, side), names)
        self.assertIn("root", names)

    def test_blockout_poses(self):
        for pose in ("Open", "Fist", "Hook"):
            self.assertIn(pose, SPEC["poses"])


if __name__ == "__main__":
    unittest.main()
