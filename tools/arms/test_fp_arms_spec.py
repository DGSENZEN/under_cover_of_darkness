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

    def test_relaxed_curls_more_toward_the_pinky(self):
        relaxed = SPEC["poses"]["Relaxed"][0]
        own = SPEC["pose_fingers"]["Relaxed"]
        firsts = [own.get(f, relaxed)[0] for f in ("index", "middle", "ring", "pinky")]
        self.assertEqual(firsts, sorted(firsts))
        self.assertGreater(firsts[0], 5.0)
        self.assertLess(firsts[-1], 50.0)

    def test_fingers_drawn_together_except_open_and_push(self):
        # (Not the fist: its fingers pack together as they curl, and closing
        # them further drives the index into the thumb resting on it.)
        for pose in ("Relaxed", "Hook", "Wrap", "SwordGrip"):
            self.assertGreater(SPEC["pose_together"][pose], 0.5, pose)
        for pose in ("Open", "Push"):
            self.assertEqual(SPEC["pose_together"].get(pose, 0.0), 0.0, pose)

    def test_together_turns_each_finger_toward_the_middle(self):
        # Swinging a finger by its together angle brings it nearer the middle
        # finger's line (right hand; the left is mirrored).
        for finger in ("index", "ring", "pinky"):
            before, after = build_fp_arms.together_check(finger)
            self.assertLess(after, before, finger)

    def test_push_is_flat(self):
        for curl in SPEC["poses"]["Push"][0]:
            self.assertLessEqual(curl, 10.0)

    def test_wrap_closes_less_than_fist(self):
        wrap, fist = SPEC["poses"]["Wrap"][0], SPEC["poses"]["Fist"][0]
        # (Round a 9 cm drainpipe: a looser hand than a fist's.)
        for k in (0, 1):
            self.assertLess(wrap[k], fist[k])
            self.assertGreater(wrap[k], 35.0)

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


def _edges(part):
    count = {}
    for face in part.faces:
        for k in range(len(face)):
            e = tuple(sorted((face[k], face[(k + 1) % len(face)])))
            count[e] = count.get(e, 0) + 1
    return count


def _islands(part):
    """Groups of faces joined by shared vertices."""
    parent = list(range(len(part.verts)))

    def find(i):
        while parent[i] != i:
            parent[i] = parent[parent[i]]
            i = parent[i]
        return i

    for face in part.faces:
        for i in face[1:]:
            parent[find(i)] = find(face[0])

    groups = {}
    for f, face in enumerate(part.faces):
        groups.setdefault(find(face[0]), []).append(f)
    return list(groups.values())


def _wound_out(test, part, closed=True):
    """Each edge walked once each way (wound alike), and each closed island
    encloses a positive volume (its faces face out)."""
    directed = {}
    for face in part.faces:
        for k in range(len(face)):
            e = (face[k], face[(k + 1) % len(face)])
            directed[e] = directed.get(e, 0) + 1
    test.assertEqual([e for e, n in directed.items() if n > 1], [], "faces wound against each other")

    if not closed:
        return

    for island in _islands(part):
        volume = 0.0
        for f in island:
            face = part.faces[f]
            a = part.verts[face[0]]
            for k in range(1, len(face) - 1):
                b, c = part.verts[face[k]], part.verts[face[k + 1]]
                volume += (a[0] * (b[1] * c[2] - b[2] * c[1]) - a[1] * (b[0] * c[2] - b[2] * c[0]) + a[2] * (b[0] * c[1] - b[1] * c[0])) / 6.0
        test.assertGreater(volume, 0.0, "an island faces in")


def _right_sleeve():
    import sleeve_form
    j = build_fp_arms.joints(1)
    return sleeve_form.sleeve(j["shoulder"], j["elbow"], j["wrist"], "r")


class Sleeve(unittest.TestCase):
    """The trench sleeve, shoulder to cuff (tools/arms/sleeve_form.py)."""

    def test_closed_except_the_cuff(self):
        part = _right_sleeve()
        open_edges = [e for e, n in _edges(part).items() if n != 2]
        end = set(part.rings[-1])
        self.assertEqual(len(open_edges), len(part.rings[-1]))
        self.assertTrue(all(a in end and b in end for a, b in open_edges))

    def test_profile_tapers(self):
        import sleeve_form
        part = _right_sleeve()

        def mean_radius(k):
            c = part.centres[k]
            ring = part.rings[k]
            return sum(math.dist(part.verts[i], c) for i in ring) / len(ring)

        elbow = min(range(len(part.rings)), key=lambda k: abs(part.ring_s[k] - part.elbow_s))
        self.assertGreater(mean_radius(0), mean_radius(elbow))
        self.assertGreater(mean_radius(elbow), mean_radius(len(part.rings) - 1))

    def test_sleeve_faces_out(self):
        _wound_out(self, _right_sleeve(), closed=False)

    def test_weights_sum_to_one(self):
        for w in _right_sleeve().weights:
            self.assertAlmostEqual(sum(w.values()), 1.0, places=5)

    def test_elbow_point_blends_wider_than_crook(self):
        import sleeve_form
        point = sleeve_form.lower_share(0.02, -1.0)
        crook = sleeve_form.lower_share(0.02, 1.0)
        self.assertLess(point, crook - 0.15)

    def test_top_on_the_clavicle(self):
        part = _right_sleeve()
        for i in part.rings[0]:
            self.assertGreaterEqual(part.weights[i].get("clavicle_r", 0.0), 0.95)

    def test_folds_only_in_the_crook(self):
        import sleeve_form
        for d in [x * 0.002 for x in range(-20, 21)]:
            self.assertAlmostEqual(sleeve_form.fold_offset(d, math.pi), 0.0, delta=0.0005)
        deepest = max(abs(sleeve_form.fold_offset(x * 0.001, 0.0)) for x in range(-40, 41))
        self.assertGreater(deepest, 0.003)

    def test_back_seam_is_a_groove(self):
        import sleeve_form
        for side in ("l", "r"):
            a = sleeve_form.seam_angle(side)
            self.assertTrue(-0.0015 <= sleeve_form.seam_offset(a, a, 0.06) <= -0.001)
            self.assertEqual(sleeve_form.seam_offset(a + 0.5, a, 0.06), 0.0)
            # Its edges are modelled: angles within 4 mm of arc each side.
            angles = sleeve_form.ring_angles(side)
            near = [x for x in angles if 0.0 < abs(x - a) * 0.06 <= 0.004]
            self.assertGreaterEqual(len(near), 2)

    def test_triangle_budget(self):
        part = _right_sleeve()
        tris = sum(len(f) - 2 for f in part.faces)
        self.assertLessEqual(tris * 2, 6000)


def _right_cuffs():
    import sleeve_form
    j = build_fp_arms.joints(1)
    return sleeve_form.cuffs(j["shoulder"], j["elbow"], j["wrist"], "r"), j


class Cuffs(unittest.TestCase):
    """The coat's turned cuff with its lining, the shirt's barrel cuff."""

    def test_cuffs_closed(self):
        part, _ = _right_cuffs()
        self.assertTrue(part.faces)
        self.assertEqual([e for e, n in _edges(part).items() if n != 2], [])

    def test_cuffs_face_out(self):
        for side in (1, -1):
            import sleeve_form
            j = build_fp_arms.joints(side)
            _wound_out(self, sleeve_form.cuffs(j["shoulder"], j["elbow"], j["wrist"], "r" if side > 0 else "l"))

    def test_lining_material_present(self):
        part, _ = _right_cuffs()
        for mat in ("coat", "lining", "cuff", "button"):
            self.assertIn(mat, part.face_mats)

    def _along(self, part, mat, j):
        import sleeve_form
        fore = sleeve_form._norm(sleeve_form._sub(j["wrist"], j["elbow"]))
        end = sleeve_form._add(j["wrist"], fore, -sleeve_form.SHORT_OF_WRIST)
        verts = {i for f, m in zip(part.faces, part.face_mats) if m == mat for i in f}
        out = []
        for i in verts:
            d = sleeve_form._sub(part.verts[i], end)
            x = sleeve_form._dot(d, fore)
            r = math.sqrt(max(sleeve_form._dot(d, d) - x * x, 0.0))
            out.append((x, r))
        return out

    def test_cuff_shows_past_the_coat(self):
        part, j = _right_cuffs()
        coat_end = max(x for x, _ in self._along(part, "coat", j) + self._along(part, "lining", j))
        shirt_end = max(x for x, _ in self._along(part, "cuff", j))
        self.assertTrue(0.020 <= shirt_end - coat_end <= 0.030, shirt_end - coat_end)

    def test_shirt_cuff_inside_coat(self):
        part, j = _right_cuffs()
        lining = min(r for _, r in self._along(part, "lining", j))
        shirt = max(r for _, r in self._along(part, "cuff", j))
        self.assertLess(shirt, lining)


class Yoke(unittest.TestCase):
    """The coat's shoulders: the sleeves run into them."""

    def setUp(self):
        import sleeve_form
        self.sleeve_form = sleeve_form
        self.part = sleeve_form.yoke()

    def test_yoke_closed_and_facing_out(self):
        self.assertEqual([e for e, n in _edges(self.part).items() if n != 2], [])
        _wound_out(self, self.part)

    def test_yoke_hides_the_sleeve_tops(self):
        for side, sign in (("l", -1), ("r", 1)):
            j = build_fp_arms.joints(sign)
            sleeve = self.sleeve_form.sleeve(j["shoulder"], j["elbow"], j["wrist"], side)
            near = [p for p in sleeve.verts if math.dist(p, j["shoulder"]) < 0.04 + self.sleeve_form.radius_at(0.0)]
            ring = [sleeve.verts[i] for i in sleeve.rings[0]]
            for p in ring + [p for p in near if math.dist(p, j["shoulder"]) <= 0.07 and self._close_to_top(p, j)]:
                self.assertTrue(self.sleeve_form.inside_yoke(p), p)

    def _close_to_top(self, p, j):
        # Within 4 cm of the shoulder along the arm.
        up = [j["elbow"][i] - j["shoulder"][i] for i in range(3)]
        n = math.sqrt(sum(x * x for x in up))
        return sum((p[i] - j["shoulder"][i]) * up[i] / n for i in range(3)) <= 0.04

    def test_yoke_below_the_eye(self):
        self.assertLess(max(v[2] for v in self.part.verts), 1.56)

    def test_yoke_on_the_root(self):
        for w in self.part.weights:
            self.assertEqual(w, {"root": 1.0})


class Proportions(unittest.TestCase):
    """The sleeve no wider than the hand reads (references: the sleeve at the
    wrist about 1.2 hand widths), the fingers sturdy, not a mannequin's."""

    def test_sleeve_at_the_wrist_against_the_hand(self):
        import sleeve_form
        palm = abs(build_fp_arms.HAND_JOINTS["fingers"]["index"][0][0] - build_fp_arms.HAND_JOINTS["fingers"]["pinky"][0][0]) + 0.02
        sleeve = 2.0 * sleeve_form.radius_at(2.0)
        self.assertLessEqual(sleeve / palm, 1.2)

    def test_fingers_thickened(self):
        j = build_fp_arms.HAND_JOINTS["fingers"]["middle"]
        mid = [(j[1][i] + j[2][i]) * 0.5 for i in range(3)]
        # A point 8 mm off the finger's axis goes out to about 9 mm.
        d = [j[2][i] - j[1][i] for i in range(3)]
        n = math.sqrt(sum(x * x for x in d))
        side = (0.0, 0.0, 0.008)
        out = build_fp_arms.sturdy_offset(tuple(mid[i] + side[i] for i in range(3)), 2)
        moved = [mid[i] + side[i] + out[i] for i in range(3)]
        along = sum((moved[i] - mid[i]) * d[i] / n for i in range(3))
        radial = math.sqrt(max(sum((moved[i] - mid[i]) ** 2 for i in range(3)) - along * along, 0.0))
        self.assertAlmostEqual(radial, 0.008 * build_fp_arms.FINGER_GIRTH, delta=0.0005)

    def test_palm_skin_and_stump_unchanged_by_girth(self):
        self.assertEqual(build_fp_arms.sturdy_offset((0.0, -0.03, 0.0), 0), (0.0, 0.0, 0.0))


FINGERS = build_fp_arms.FINGERS


if __name__ == "__main__":
    unittest.main()
