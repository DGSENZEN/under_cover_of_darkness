"""The figures kit (docs/superpowers/specs/2026-10-10-zocalo-scenes-design.md):
the scenes' stand-ins until the NPCs come. Faceless clay mannequins in the
poses the scenes need, street dogs and a pigeon, one object each, plain clay
grey so they never read as finished art. What a figure carries (a basket, a
lantern, a censer) belongs to the scene kit, never the figure.

    Blender -b --factory-startup --python tools/eclipse/figures_kit.py

Blender axes: the figure's feet (or seat) on the ground at the origin, Z up,
facing -Y (its right hand at -X).

A figure is one skeleton posed by a table of angles (degrees):
  lean      the torso tipped forward from the hips (back if negative)
  head      the head bowed
  arms      (right, left), each (pitch forward, roll out from the side, elbow)
  legs      (right, left), each (pitch forward, roll out, knee, foot?) where
            foot (optional) is the foot's own pitch, else flat on the ground
Limbs are tubes from joint to joint: end to end where a joint is nearly
straight (two coaxial tubes would lie within the gate's 3 cm), overlapping
into the next where it bends.
"""

import math
import os
import sys

from mathutils import Matrix, Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import common  # noqa: E402
import shapes  # noqa: E402

NAME = "figures_kit"
ATLAS = 1024
SLOTS = ["clay"]

# The adult's proportions (m): standing, the head's top at 1.70.
ADULT = {"foot_h": 0.07, "shin": 0.45, "thigh": 0.45, "torso": 0.50, "neck": 0.06, "head_r": 0.1, "upper": 0.29,
         "fore": 0.26, "hand": 0.09, "hip_x": 0.1, "shoulder_x": 0.2, "limb_r": (0.06, 0.05, 0.045, 0.038)}
# A child's: shorter limbs, a larger head for its size.
CHILD = {"foot_h": 0.05, "shin": 0.29, "thigh": 0.29, "torso": 0.33, "neck": 0.04, "head_r": 0.085, "upper": 0.19,
         "fore": 0.17, "hand": 0.065, "hip_x": 0.07, "shoulder_x": 0.13, "limb_r": (0.045, 0.038, 0.034, 0.03)}
SIDES = 5
# The lower limb turned half a side against the upper, so a bent joint's
# two tubes never lay a face along each other.
TWIST = math.pi / SIDES
BENT = 25.0       # a joint bent this much (deg) or more: the limbs overlap into it

# Each figure's hands at their fingertips' middle, in its own frame (Blender
# axes, set on the ground): {name: {"right": (x, y, z), "left": ...}}.
HANDS = {}

DOWN = Vector((0.0, 0.0, -1.0))
FORWARD = Vector((0.0, -1.0, 0.0))

STILL = [(0, 6, 4), (0, 6, 4)]
UPRIGHT = [(0, 3, 0), (0, 3, 0)]

POSES = {
    "fig_stand": {"arms": STILL, "legs": UPRIGHT},
    "fig_queue": {"head": 6, "arms": [(18, -14, 55), (18, -14, 55)], "legs": UPRIGHT},
    "fig_walk": {"lean": 4, "arms": [(-20, 6, 15), (22, 6, 30)], "legs": [(14, 2, 3), (-12, 2, 20)]},
    "fig_kneel_pray": {"lean": 6, "head": 28, "arms": [(30, -14, 105), (30, -14, 105)],
                       "legs": [(0, 6, 90, 180), (0, 6, 90, 180)]},
    "fig_sit_kerb": {"lean": 14, "head": 10, "arms": [(46, 14, 40), (46, 14, 40)],
                     "legs": [(120, 12, 90, 0), (120, 12, 90, 0)]},
    "fig_sit_chair": {"lean": 4, "arms": [(28, 8, 60), (28, 8, 60)], "legs": [(90, 6, 90), (90, 6, 90)]},
    "fig_lean_wall": {"lean": -6, "head": 4, "arms": [(30, -26, 110), (30, -26, 110)],
                      "legs": [(0, 4, 0), (-12, 4, 90)]},
    "fig_push_cart": {"lean": 22, "arms": [(68, 8, 22), (68, 8, 22)], "legs": [(26, 3, 10), (-22, 3, 20)]},
    "fig_carry_basket": {"arms": [(14, 40, 100), (0, 6, 4)], "legs": UPRIGHT},
    "fig_point": {"arms": [(88, 16, 0), (0, 6, 4)], "legs": UPRIGHT},
    "fig_crouch_inspect": {"lean": 32, "head": 30, "arms": [(64, 4, 6), (30, 30, 70)],
                           "legs": [(100, 14, 130, 0), (100, 14, 130, 0)]},
    "fig_hold_lantern": {"arms": [(26, 10, 72), (0, 6, 4)], "legs": UPRIGHT},
    "fig_type": {"lean": 10, "head": 16, "arms": [(46, 10, 48), (46, 10, 48)], "legs": [(90, 6, 90), (90, 6, 90)]},
    "fig_dictate": {"head": -4, "arms": [(40, 22, 64), (0, 6, 4)], "legs": UPRIGHT},
    "fig_barker": {"head": -8, "arms": [(158, 20, 10), (10, 42, 96)], "legs": [(6, 6, 0), (-4, 6, 0)]},
    "fig_photographer": {"lean": 48, "head": 22, "arms": [(40, 12, 60), (40, 12, 60)],
                         "legs": [(8, 6, 4), (-6, 6, 4)]},
    "fig_mourner": {"lean": 8, "head": 34, "arms": [(18, -16, 42), (18, -16, 42)], "legs": UPRIGHT},
    "fig_child": {"head": -6, "arms": STILL, "legs": UPRIGHT, "body": CHILD},
    "fig_sleep_wall": {"lean": -24, "head": 38, "arms": [(14, 18, 30), (14, 18, 30)],
                       "legs": [(90, 8, 0, 90), (84, 12, 6, 90)]},
}


def _rot(axis, degrees):
    return Matrix.Rotation(math.radians(degrees), 3, axis)


def _direction(pitch, roll, side):
    """Down, rolled out from the body to `side` (-1 right, +1 left), then
    pitched forward (toward -Y)."""
    return _rot("X", -pitch) @ _rot("Y", -side * roll) @ DOWN


def _limb(m, a, b, radius, into_a=0.0, into_b=0.0, twist=0.0):
    """A tube from a to b, run on past either end by `into_*` (overlapping a bent joint)."""
    a, b = Vector(a), Vector(b)
    axis = (b - a).normalized()
    m.shell()
    m.tube(a - axis * into_a, b + axis * into_b, radius, SIDES, "clay", caps=(True, True), twist=twist)


def _bend(u, v):
    return math.degrees(math.acos(max(-1.0, min(1.0, u.dot(v)))))


def figure(m, pose, at=(0.0, 0.0, 0.0), yaw=0.0, lift=None, hands=None):
    """One figure in `pose` (a POSES entry) with its root at `at`, turned
    `yaw` degrees about Z; returns its points' lowest z. `lift`, when given,
    is the pelvis's height; otherwise the pelvis stands where the legs put it
    and the caller sets the figure on the ground. `hands` (a dict) is given
    the hands' points."""
    b = pose.get("body", ADULT)
    r_thigh, r_shin, r_upper, r_fore = b["limb_r"]
    turn = _rot("Z", yaw)
    origin = Vector(at)
    place = lambda p: origin + turn @ p
    hip = Vector((0.0, 0.0, lift if lift is not None else b["foot_h"] + b["shin"] + b["thigh"]))
    # (A turn about +X by +a tips +Z toward -Y: forward.)
    body = _rot("X", pose.get("lean", 0.0))
    up = body @ Vector((0.0, 0.0, 1.0))

    # The torso, a loft of hexagons from the pelvis to the shoulders.
    rings = []

    scale = b["torso"] / ADULT["torso"]

    for rise, hx, hy in ((-0.16, 0.17, 0.11), (0.4, 0.14, 0.1), (0.84, 0.19, 0.12), (1.0, 0.15, 0.1)):
        ring = []

        for k in range(6):
            a = math.radians(60 * k)
            p = Vector((hx * scale * math.cos(a), hy * scale * math.sin(a), rise * b["torso"]))
            ring.append(tuple(place(hip + body @ p)))

        rings.append(ring)

    m.shell()
    shapes.loft(m, rings, "clay", caps=True, fan=True)

    neck_base = hip + up * (b["torso"] - 0.03)
    neck_top = hip + up * (b["torso"] + b["neck"])
    _limb(m, place(neck_base), place(neck_top), b["head_r"] * 0.45)
    head_axis = body @ _rot("X", pose.get("head", 0.0)) @ Vector((0.0, 0.0, 1.0))
    centre = neck_top + head_axis * (b["head_r"] * 0.8)
    m.shell()
    m.sphere(tuple(place(centre)), b["head_r"], 4, 6, "clay")

    # Arms, from the shoulders.
    for side, (pitch, roll, elbow) in zip((-1, 1), pose["arms"]):
        shoulder = hip + body @ Vector((side * b["shoulder_x"], 0.0, b["torso"] - 0.05))
        d1 = body @ _direction(pitch, roll, side)
        d2 = body @ _direction(pitch + elbow, roll, side)
        el = shoulder + d1 * b["upper"]
        wrist = el + d2 * b["fore"]
        bent = _bend(d1, d2) >= BENT
        _limb(m, place(shoulder), place(el), r_upper, into_b=r_fore if bent else 0.0)
        _limb(m, place(el), place(wrist), r_fore, twist=TWIST)
        m.shell()
        m.bar(tuple(place(wrist)), tuple(place(wrist + d2 * b["hand"])), r_fore * 2.0, r_fore * 1.2, "clay",
              caps=(True, True))

        if hands is not None:
            hands["right" if side < 0 else "left"] = place(wrist + d2 * (b["hand"] * 0.6))

    # Legs, from the hips.
    for side, leg in zip((-1, 1), pose["legs"]):
        pitch, roll, knee = leg[:3]
        joint = hip + Vector((side * b["hip_x"], 0.0, 0.0))
        d1 = _direction(pitch, roll, side)
        d2 = _direction(pitch - knee, roll, side)
        kn = joint + d1 * b["thigh"]
        ankle = kn + d2 * b["shin"]
        bent = _bend(d1, d2) >= BENT
        _limb(m, place(joint), place(kn), r_thigh, into_b=r_shin if bent else 0.0)
        _limb(m, place(kn), place(ankle), r_shin, twist=TWIST)
        foot_pitch = leg[3] if len(leg) > 3 else 0.0
        toe = _rot("X", -foot_pitch) @ FORWARD
        heel = ankle - toe * 0.04 + Vector((0.0, 0.0, 0.0))
        m.shell()
        m.bar(tuple(place(heel)), tuple(place(ankle + toe * b["foot_h"] * 2.6)), r_shin * 1.8, b["foot_h"], "clay",
              caps=(True, True))


def _settle(obj, hands=None):
    """Sets an object on the ground: its lowest point to z 0 (its hands with it)."""
    low = min(v.co.z for v in obj.data.vertices)

    for v in obj.data.vertices:
        v.co.z -= low

    if hands is not None:
        HANDS[obj.name] = {k: (round(p.x, 4), round(p.y, 4), round(p.z - low, 4)) for k, p in hands.items()}


def _figure_object(name, pose):
    m = common.Mesh(name, outward=True)
    hands = {}
    figure(m, pose, hands=hands)
    obj = m.make()
    _settle(obj, hands)
    return obj


def child_held():
    """An adult with a child sat on its shoulders, holding the child's shins."""
    m = common.Mesh("fig_child_held", outward=True)
    adult = {"head": -4, "arms": [(150, 14, 34), (150, 14, 34)], "legs": UPRIGHT}
    hands = {}
    figure(m, adult, hands=hands)
    stand = ADULT["foot_h"] + ADULT["shin"] + ADULT["thigh"]
    # The child's pelvis behind the adult's head, on its shoulders.
    child = {"lean": 4, "arms": [(70, 12, 70), (70, 12, 70)], "legs": [(90, 26, 80), (90, 26, 80)], "body": CHILD}
    figure(m, child, at=(0.0, 0.1, 0.0), lift=stand + ADULT["torso"] + 0.06)
    obj = m.make()
    _settle(obj, hands)
    return obj


def dog(name, kind):
    """A street dog, about 0.55 m at the shoulder: a body, a head and snout,
    four legs, ears and a tail, all bars, facing -Y."""
    m = common.Mesh(name, outward=True)
    leg = 0.36 if kind != "lie" else 0.0
    body_z = leg + 0.1 if kind != "lie" else 0.12
    tilt = 0.1 if kind == "sit" else 0.0      # the sitting dog's back slopes down to its haunches

    front, back = Vector((0.0, -0.3, body_z + tilt)), Vector((0.0, 0.3, body_z - tilt))
    m.shell()
    m.bar(tuple(back), tuple(front), 0.24, 0.22, "clay", caps=(True, True))
    sniff = kind == "sniff"
    neck = front + Vector((0.0, -0.08, 0.06 if not sniff else -0.08))
    head = neck + Vector((0.0, -0.12, 0.08 if not sniff else -0.18))
    m.shell()
    m.bar(tuple(front + Vector((0.0, 0.06, 0.02))), tuple(head), 0.08, 0.13, "clay", caps=(True, True))
    m.shell()
    m.bar(tuple(head - Vector((0.0, 0.05, 0.0))), tuple(head + Vector((0.0, -0.17, -0.03))), 0.08, 0.08, "clay",
          caps=(True, True))

    for side in (-1, 1):
        m.shell()
        ear = head + Vector((side * 0.05, 0.03, 0.06))
        m.bar(tuple(ear), tuple(ear + Vector((side * 0.02, 0.03, 0.09))), 0.05, 0.03, "clay", caps=(True, True))

    if kind == "lie":
        for side in (-1, 1):
            for y in (-0.36, 0.22):
                m.shell()
                foot = Vector((side * 0.16, y, 0.035))
                m.bar(tuple(foot), tuple(foot + Vector((0.0, -0.2, 0.0))), 0.06, 0.07, "clay", caps=(True, True))
    else:
        for side in (-1, 1):
            m.shell()
            top = front + Vector((side * 0.05, 0.04, -0.05))
            m.bar(tuple(top), (top.x, top.y - 0.02, 0.0), 0.06, 0.06, "clay", caps=(True, True))
            m.shell()

            if kind == "sit":
                haunch = back + Vector((side * 0.12, -0.05, -0.04))
                m.bar(tuple(haunch), (haunch.x, haunch.y - 0.18, 0.0), 0.08, 0.1, "clay", caps=(True, True))
            else:
                hind = back + Vector((side * 0.05, -0.04, -0.05))
                m.bar(tuple(hind), (hind.x, hind.y + 0.04, 0.0), 0.06, 0.06, "clay", caps=(True, True))

    m.shell()
    tail = back + Vector((0.0, 0.06, 0.06))
    m.bar(tuple(tail), tuple(tail + Vector((0.0, 0.2, 0.14 if kind != "lie" else 0.02))), 0.04, 0.04, "clay",
          caps=(True, True))
    obj = m.make()
    _settle(obj)
    return obj


# The pigeon's wings: each a thin swept slab from its root, sunk in the body
# at x WING_ROOT, out to its tip at x WING_TIP, at height WING_Z (before the
# bird is set on the ground: scripts/Visual/pigeon.gdshader's `shoulder`).
WING_ROOT = 0.05
WING_TIP = 0.3
WING_Z = 0.15
WING_THICK = 0.014


def pigeon():
    """A pigeon pecking, 0.3 m long: a body, a head, a tail, two wings whose
    vertices carry their hinge (0 at the root, 1 at the tip) and side (-1
    left, +1 right) for the pigeon shader's flap (the body: 0, 0)."""
    m = common.Mesh("pigeon", outward=True)
    # (Layers first: adding one leaves the vertices made before it stale.)
    hinge = m.bm.verts.layers.float.new("hinge")
    side = m.bm.verts.layers.float.new("side")
    m.shell()
    m.sphere((0.0, 0.0, 0.11), 0.09, 3, 5, "clay")
    m.shell()
    m.bar((0.0, -0.05, 0.14), (0.0, -0.13, 0.17), 0.05, 0.05, "clay", caps=(True, True))
    m.shell()
    m.prism([(-0.035, 0.06), (0.035, 0.06), (0.0, 0.2)], 0.1, 0.13, "clay")

    for way in (1.0, -1.0):
        # Swept back: the leading edge out to the tip, the trailing edge home.
        outline = [(WING_ROOT, -0.04), (WING_TIP, 0.06), (WING_TIP - 0.04, 0.12), (WING_ROOT, 0.08)]
        outline = [(way * x, y) for x, y in outline]
        m.shell()
        m.prism(outline if way > 0 else list(reversed(outline)), WING_Z, WING_Z + WING_THICK, "clay")

        for v in m.shells[-1]:
            v[hinge] = min(max((abs(v.co.x) - WING_ROOT) / (WING_TIP - WING_ROOT), 0.0), 1.0)
            v[side] = way

    obj = m.make()
    _settle(obj)
    return obj


def write_hands(path=None):
    """HANDS in Godot's axes (x, z, -y) for the scene director."""
    import json
    path = path or common.SOURCE / (NAME + "_hands.json")
    path.write_text(json.dumps({n: {k: [p[0], p[2], -p[1]] for k, p in h.items()} for n, h in sorted(HANDS.items())},
                               indent=1))


def build():
    common.reset()
    HANDS.clear()

    for name, pose in POSES.items():
        _figure_object(name, pose)

    child_held()

    for kind in ("sit", "lie", "sniff"):
        dog("dog_" + kind, kind)

    pigeon()


SETTS = (0.24, 0.23, 0.26)
JOINTS = {
    "fig_row": {"eye": (0.0, -5.0, 1.4), "target": (0.0, 0.0, 0.9),
                "show": [(n, (-6.0 + 1.5 * k, 0, 0), 0) for k, n in enumerate(list(POSES)[:9])],
                "planes": [(-20, -20, 20, 20, -0.002, SETTS)]},
}

WEATHER = {"coarse": {n: 3.0 for n in list(POSES) + ["fig_child_held", "dog_sit", "dog_lie", "dog_sniff", "pigeon"]},
           "blendable": [], "foot": ["clay"]}


def main():
    build()
    common.export_piece(NAME, ATLAS, SLOTS, weather=WEATHER, out=common.ROOT / "assets" / "eclipse" / "kit",
                        sets_each=True)
    write_hands()


if __name__ == "__main__":
    main()
