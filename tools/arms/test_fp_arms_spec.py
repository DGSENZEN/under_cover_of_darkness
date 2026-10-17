"""The first-person arms' spec (tools/arms/build_fp_arms.py SPEC): a real
arm's proportions and every bone the arm solver needs. Pure Python.

    python3 tools/arms/test_fp_arms_spec.py
"""

import math
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

    def test_full_pose_library(self):
        for pose in ("Open", "Fist", "Hook", "Wrap", "Push", "SwordGrip"):
            self.assertIn(pose, SPEC["poses"])

    def test_push_is_flat(self):
        for curl in SPEC["poses"]["Push"][0]:
            self.assertLessEqual(curl, 10.0)

    def test_wrap_closes_less_than_fist(self):
        wrap, fist = SPEC["poses"]["Wrap"][0], SPEC["poses"]["Fist"][0]
        for k in (0, 1):
            self.assertLess(wrap[k], fist[k])
            self.assertGreater(wrap[k], 40.0)

    def test_sword_grip_index_looser(self):
        own = SPEC["pose_fingers"]["SwordGrip"]
        middle = own.get("middle", SPEC["poses"]["SwordGrip"][0])
        self.assertLess(own["index"][1], middle[1])


class HandWeights(unittest.TestCase):
    """Skin weights from the base hand's joints (right hand, local space:
    wrist at the origin, fingers along +Y)."""

    J = build_fp_arms.HAND_JOINTS["fingers"]

    def weights(self, co, finger):
        w = build_fp_arms.hand_weights(co, finger)
        self.assertAlmostEqual(sum(w.values()), 1.0, places=5)
        return w

    def test_hand_is_a_mans_hand(self):
        tip = self.J["middle"][3]
        self.assertAlmostEqual(math.sqrt(sum(c * c for c in tip)), SPEC["hand_length"], delta=0.003)

    def test_fingertip_follows_its_last_joint(self):
        for finger in ("index", "middle", "ring", "pinky", "thumb"):
            w = self.weights(self.J[finger][3], FINGERS.index(finger) + 1)
            self.assertGreater(w.get(finger + "_03", 0.0), 0.99, finger)

    def test_middle_of_a_phalanx_is_rigid(self):
        a, b = self.J["ring"][1], self.J["ring"][2]
        w = self.weights([(a[i] + b[i]) * 0.5 for i in range(3)], 3)
        self.assertGreater(w.get("ring_02", 0.0), 0.99)

    def test_joint_is_shared(self):
        w = self.weights(self.J["index"][2], 1)
        self.assertAlmostEqual(w.get("index_02", 0.0), 0.5, delta=0.1)
        self.assertAlmostEqual(w.get("index_03", 0.0), 0.5, delta=0.1)

    def test_back_of_a_joint_blends_wider(self):
        # Just past a finger joint: the back of the finger stretches round it
        # (wide), the pad side folds sharp (narrow).
        a, b, c = self.J["middle"][1], self.J["middle"][2], self.J["middle"][3]
        d = [(c[i] - b[i]) for i in range(3)]
        n = math.sqrt(sum(x * x for x in d))
        past = [b[i] + d[i] / n * 0.003 for i in range(3)]
        nail = build_fp_arms.HAND_JOINTS["nails"]["middle"]
        back = build_fp_arms.hand_weights(past, 2, tuple(nail))
        pad = build_fp_arms.hand_weights(past, 2, tuple(-x for x in nail))
        self.assertLess(back.get("middle_03", 0.0), pad.get("middle_03", 0.0) - 0.1)

    def test_back_of_the_hand_follows_the_hand(self):
        w = self.weights([0.0, 0.045, 0.012], 0)
        self.assertGreater(w.get("hand", 0.0), 0.99)

    def test_wrist_stump_follows_the_forearm(self):
        w = self.weights([0.0, -0.04, 0.0], 0)
        self.assertGreater(w.get("lowerarm", 0.0), 0.99)

    def test_palm_skin_over_a_knuckle_bends_with_its_finger(self):
        k = self.J["middle"][0]
        w = self.weights([k[0], k[1] + 0.004, k[2] + 0.01], 0)
        self.assertGreater(w.get("middle_01", 0.0), 0.3)
        self.assertEqual(w.get("ring_01", 0.0) + w.get("index_01", 0.0) + w.get("pinky_01", 0.0), 0.0)


class Aging(unittest.TestCase):
    """An older man's hand: bony knuckles, knobbed joints, tendons on the
    back. Offsets along the skin's normal (right hand, local space)."""

    J = build_fp_arms.HAND_JOINTS["fingers"]
    UP = (0.0, 0.0, 1.0)
    DOWN = (0.0, 0.0, -1.0)

    def push(self, co, normal):
        o = build_fp_arms.age_offset(co, normal)
        return sum(o[i] * normal[i] for i in range(3))

    def test_knuckle_heads_stand_out(self):
        for finger in ("index", "middle", "ring", "pinky"):
            k = self.J[finger][0]
            self.assertGreater(self.push((k[0], k[1], k[2] + 0.01), self.UP), 0.0015, finger)

    def test_tendon_ridges_the_back_of_the_hand(self):
        k = self.J["middle"][0]
        on = self.push((k[0] * 0.6, k[1] * 0.6, 0.012), self.UP)
        between = self.push(((k[0] + self.J["ring"][0][0]) * 0.3, k[1] * 0.6, 0.012), self.UP)
        self.assertGreater(on, between + 0.0004)

    def test_palm_is_left_alone(self):
        k = self.J["middle"][0]
        self.assertEqual(self.push((k[0], k[1], k[2] - 0.01), self.DOWN), 0.0)

    def test_forearm_under_the_cuff_is_left_alone(self):
        self.assertEqual(self.push((0.0, -0.05, 0.02), self.UP), 0.0)

    def test_finger_joints_are_knobbed(self):
        a, b = self.J["index"][1], self.J["index"][2]
        at_joint = self.push((a[0], a[1], a[2] + 0.008), self.UP)
        mid = [(a[i] + b[i]) * 0.5 for i in range(3)]
        between = self.push((mid[0], mid[1], mid[2] + 0.008), self.UP)
        self.assertGreater(at_joint, between + 0.0004)


FINGERS = build_fp_arms.FINGERS


if __name__ == "__main__":
    unittest.main()
