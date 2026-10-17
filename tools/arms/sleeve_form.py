"""The Prosecutor's coat on his first-person arms: the trench sleeve, its
cuffs and the coat's shoulders, as plain geometry (vertices, faces, a material
and bone weights per piece). Pure Python, so its shape and weights are tested
without Blender (tools/arms/test_fp_arms_spec.py); build_fp_arms.py turns
each Part into the mesh.

Blender's axes: +Y forward, +Z up, left is -X.
Spec: docs/superpowers/specs/2026-10-16-prosecutor-fp-arms-design.md.
"""

import math

# A ring of the sleeve every this far along the arm (m), this many round.
RING_STEP = 0.012
SEGMENTS = 24
# The coat ends this far short of the wrist (build_fp_arms.SPEC).
SHORT_OF_WRIST = 0.04
# The sleeve's radius along the arm: (share of the way, metres). Shares 0 to
# 1 run shoulder to elbow, 1 to 2 elbow to the coat's end.
PROFILE = ((0.0, 0.064), (0.5, 0.060), (1.0, 0.056), (1.5, 0.050), (2.0, 0.047))
# Cloth hangs: the sleeve a little deeper (crook to point) than wide.
OVAL = 1.04
# How wide the bend's blend runs either side of the elbow (m): wide over the
# point of the elbow (the cloth stretches round it), sharp in the crook (it
# folds there).
ELBOW_BACK = 0.045
ELBOW_CROOK = 0.015
# Near the elbow the rings turn to its bisector, over this far each way (m),
# so they never cross.
ELBOW_TURN = 0.03


class Part:
    """One piece of the coat: vertices, faces (index tuples), a material per
    face, bone weights per vertex. A sleeve also keeps its rings."""

    def __init__(self):
        self.verts = []
        self.faces = []
        self.face_mats = []
        self.weights = []
        self.rings = []
        self.ring_s = []
        self.centres = []
        self.elbow_s = 0.0

    def add(self, other):
        base = len(self.verts)
        self.verts += other.verts
        self.weights += other.weights
        self.faces += [tuple(i + base for i in f) for f in other.faces]
        self.face_mats += other.face_mats


def _sub(a, b):
    return (a[0] - b[0], a[1] - b[1], a[2] - b[2])


def _add(a, b, k=1.0):
    return (a[0] + b[0] * k, a[1] + b[1] * k, a[2] + b[2] * k)


def _dot(a, b):
    return a[0] * b[0] + a[1] * b[1] + a[2] * b[2]


def _cross(a, b):
    return (a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0])


def _norm(a):
    length = math.sqrt(_dot(a, a))
    return (a[0] / length, a[1] / length, a[2] / length)


def _lerp(a, b, t):
    return (a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t)


def _smooth(edge0, edge1, x):
    t = min(max((x - edge0) / (edge1 - edge0), 0.0), 1.0)
    return t * t * (3.0 - 2.0 * t)


def radius_at(share):
    """The sleeve's radius at a share of the way (0-2), eased between the
    profile's points."""
    for (s0, r0), (s1, r1) in zip(PROFILE, PROFILE[1:]):
        if share <= s1:
            t = _smooth(s0, s1, share)
            return r0 + (r1 - r0) * t

    return PROFILE[-1][1]


def lower_share(past, crook):
    """How much of a sleeve vertex `past` metres beyond the elbow's bisector
    follows the forearm. crook: 1 in the crook, -1 over the point."""
    width = ELBOW_BACK + (ELBOW_CROOK - ELBOW_BACK) * (crook + 1.0) * 0.5
    return _smooth(-width, width, past)


def sleeve(shoulder, elbow, wrist, side):
    """The trench sleeve from the shoulder (a closed cap, inside the yoke) to
    the coat's end (open: the cuff closes it), in rings along the arm."""
    up = _norm(_sub(elbow, shoulder))
    fore = _norm(_sub(wrist, elbow))
    end = _add(wrist, fore, -SHORT_OF_WRIST)
    upper = math.dist(shoulder, elbow)
    lower = math.dist(elbow, end)
    bisector = _norm(_add(up, fore))
    # The crook: the side the arm bends toward.
    turn = _sub(fore, up)
    crook = _norm(_sub(turn, _add((0.0, 0.0, 0.0), bisector, _dot(turn, bisector))))
    part = Part()
    part.elbow_s = upper
    count = max(int(round((upper + lower) / RING_STEP)), 2)
    clavicle, upperarm, lowerarm = "clavicle_" + side, "upperarm_" + side, "lowerarm_" + side

    for k in range(count + 1):
        s = (upper + lower) * k / count
        centre = _add(shoulder, up, s) if s <= upper else _add(elbow, fore, s - upper)
        share = s / upper if s <= upper else 1.0 + (s - upper) / lower
        # The ring's plane: the bone's, turning to the bisector at the elbow.
        b = _smooth(-ELBOW_TURN, ELBOW_TURN, s - upper)
        axis = _norm(_lerp(up, bisector, _smooth(-ELBOW_TURN, 0.0, s - upper))) if b < 0.5 \
            else _norm(_lerp(bisector, fore, _smooth(0.0, ELBOW_TURN, s - upper)))
        u = _norm(_sub(crook, _add((0.0, 0.0, 0.0), axis, _dot(crook, axis))))
        v = _cross(axis, u)
        radius = radius_at(share)
        ring = []

        for i in range(SEGMENTS):
            a = i / SEGMENTS * math.tau
            out = _add(_add((0.0, 0.0, 0.0), u, math.cos(a) * OVAL), v, math.sin(a) / OVAL)
            point = _add(centre, out, radius)
            ring.append(len(part.verts))
            part.verts.append(point)

            # Weights: across the elbow by its bisector, the top on the
            # clavicle (a shoulder the solver slides stretches the sleeve).
            low = lower_share(_dot(_sub(point, elbow), bisector), math.cos(a))
            arm = _smooth(0.05, 0.40, s / upper) if s <= upper else 1.0
            w = {lowerarm: low, upperarm: (1.0 - low) * arm, clavicle: (1.0 - low) * (1.0 - arm)}
            part.weights.append({name: x for name, x in w.items() if x > 1e-6})

        part.rings.append(ring)
        part.ring_s.append(s)
        part.centres.append(centre)

    for k in range(count):
        for i in range(SEGMENTS):
            j = (i + 1) % SEGMENTS
            # Wound so the normals face out.
            part.faces.append((part.rings[k][i], part.rings[k][j], part.rings[k + 1][j], part.rings[k + 1][i]))
            part.face_mats.append("coat")

    # The shoulder's cap.
    part.faces.append(tuple(reversed(part.rings[0])))
    part.face_mats.append("coat")
    return part
