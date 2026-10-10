"""The canal kit (docs/superpowers/refs/mexico_city/cards/street_canal.md,
the Zócalo's family 1): the Acequia Real's walls come back, two eras on top
of each other (colonial ashlar below, the hasty rubble that raised them
after the drain failed in 1900), their chiluca coping, the landings' low
walls and their inside corner, a silted drain and the walkway's mouth, the
landing's steps, the iron rings worn bright. Each piece its own object at
the origin, built to street_dims.py; one atlas, exported to
assets/eclipse/kit/.

    Blender -b --factory-startup --python tools/eclipse/canal_kit.py

Blender axes: a wall runs from the origin along +X, its face at y 0
looking -Y over the water (or the landing), its body buried behind it, the
street at z 0.
"""

import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import common  # noqa: E402
import shapes  # noqa: E402
from street_dims import (CORNER, COPING_BACK, COPING_DEPTH, COPING_PROUD, STEP_RISE, STEP_TREAD,  # noqa: E402
                         STEP_WIDTH, WALL_FOOT, WALL_LENGTH, WALL_SHORT, WALL_THICK, WATER)

NAME = "canal_kit"
ATLAS = 1024
SLOTS = ["chiluca", "ashlar", "rubble", "basalt", "iron", "brass"]

# The rubble raised over the ashlar stands this far back from its face (m),
# the old courses' top a ledge where the water once stood.
SET_BACK = 0.04
# The two eras' joint along a 4.5 m wall, ragged (z at each fifth of it);
# a short wall's, at its ends and middle. Every wall's ends meet at ERA.
ERA = -1.1
RAGGED = [ERA, -1.0, -1.18, -1.04, ERA]
RAGGED_SHORT = [ERA, -1.04, ERA]
# The coping's front edge, worn round.
COPING_ROUND = 0.04


def wall_profile(era=ERA, top=0.0, foot=WALL_FOOT, two_eras=True):
    """A canal wall's section (y back from its face, z) and each edge's slot:
    ashlar from its buried foot to the era joint, the rubble set back above
    it to the coping, the coping proud of the face and flush with the
    street, the body behind buried. Heights from `top` (its street)."""
    c = top - COPING_DEPTH
    points = [(0.0, foot)]
    slots = ["ashlar"]

    if two_eras:
        points += [(0.0, era), (SET_BACK, era)]
        slots += ["ashlar", "rubble"]
        under = SET_BACK
    else:
        points += [(0.0, c)]
        slots += ["chiluca"]
        under = 0.0

    if two_eras:
        points += [(under, c)]
        slots += ["chiluca"]

    points += [(-COPING_PROUD, c), (-COPING_PROUD, top - COPING_ROUND), (-COPING_PROUD + COPING_ROUND, top),
               (COPING_BACK, top), (COPING_BACK, c), (WALL_THICK, c), (WALL_THICK, foot)]
    slots += ["chiluca", "chiluca", "chiluca", "chiluca", "chiluca", "chiluca", "chiluca"]
    return points, slots


def _wall(name, length, ragged):
    m = common.Mesh(name, outward=True)
    stations = [length * k / (len(ragged) - 1) for k in range(len(ragged))]
    sections = [(x, wall_profile(era)[0]) for x, era in zip(stations, ragged)]
    shapes.loft_x(m, sections, wall_profile()[1], cap_slot="ashlar")
    return m.make()


def canal_wall():
    return _wall("canal_wall", WALL_LENGTH, RAGGED)


def canal_wall_short():
    return _wall("canal_wall_short", WALL_SHORT, RAGGED_SHORT)


# The landings' walls: a metre from the street down to the landing (and
# from the landing to the water), colonial ashlar to the coping.
LOW = 1.0
LOW_FOOT = -1.3


def canal_wall_low(name="canal_wall_low", length=WALL_LENGTH):
    m = common.Mesh(name, outward=True)
    profile, slots = wall_profile(foot=LOW_FOOT, two_eras=False)
    shapes.loft_x(m, [(0.0, profile), (length, profile)], slots, cap_slot="ashlar")
    return m.make()


def canal_wall_corner():
    """The landing's inside corner, a metre high: the low wall turning 90°
    with its coping mitred, a CORNER-long leg each way from the corner (at
    the origin) along +X and -Y, both faces looking into the landing
    (x > 0, y < 0); the runs start where its legs end."""
    m = common.Mesh("canal_wall_corner", outward=True)
    profile, slots = wall_profile(foot=LOW_FOOT, two_eras=False)
    rings = [[(CORNER, d, z) for d, z in profile],
             [(-d, d, z) for d, z in profile],
             [(-d, -CORNER, z) for d, z in profile]]
    shapes.loft(m, rings, slots, cap_slot="ashlar")
    return m.make()


# The drain: an arch of 1.2 m springing at -1.75 (its crown under the old
# courses' top), silt banked in it, its throat dark behind.
DRAIN = (1.2, -1.75)
DRAIN_ARCH = 8
SILT_BACK = -1.8
THROAT = 0.45


def body_profile(era=ERA, foot=WALL_FOOT):
    """The wall under its coping (y, z), and each edge's slot."""
    c = -COPING_DEPTH
    return ([(0.0, foot), (0.0, era), (SET_BACK, era), (SET_BACK, c), (WALL_THICK, c), (WALL_THICK, foot)],
            ["ashlar", "ashlar", "rubble", "chiluca", "chiluca", "chiluca"])


def head_profile(soffit, era=ERA):
    """The wall over an opening, its underside at `soffit` through it."""
    c = -COPING_DEPTH
    return ([(0.0, soffit), (0.0, era), (SET_BACK, era), (SET_BACK, c), (WALL_THICK, c), (WALL_THICK, soffit)],
            ["ashlar", "ashlar", "rubble", "chiluca", "chiluca", "ashlar"])


def coping(m, x0=0.0, x1=WALL_LENGTH):
    """The coping as a solid of its own, x0 to x1 (over an opening, its lintel)."""
    c = -COPING_DEPTH
    profile = [(-COPING_PROUD, c), (-COPING_PROUD, -COPING_ROUND), (-COPING_PROUD + COPING_ROUND, 0.0),
               (COPING_BACK, 0.0), (COPING_BACK, c)]
    m.shell()
    shapes.loft_x(m, [(x0, profile), (x1, profile)], "chiluca")


def _piers(m, a, b):
    """The wall's body either side of an opening from x a to b, each a solid,
    their ends the opening's jambs; the coping over the whole length."""
    profile, slots = body_profile()

    for x0, x1 in ((0.0, a), (b, WALL_LENGTH)):
        m.shell()
        shapes.loft_x(m, [(x0, profile), (x1, profile)], slots, cap_slot="ashlar")

    coping(m)


def culvert():
    """A colonial drain's mouth in the wall, choked with the silt the
    returning water left: its arch in the old courses, a dark throat."""
    m = common.Mesh("culvert", outward=True)
    span, spring = DRAIN
    a, b = (WALL_LENGTH - span) / 2, (WALL_LENGTH + span) / 2
    _piers(m, a, b)
    r = span / 2
    arch = [(a + r - r * math.cos(math.pi * k / DRAIN_ARCH), spring + r * math.sin(math.pi * k / DRAIN_ARCH))
            for k in range(DRAIN_ARCH + 1)]
    m.shell()
    _, slots = head_profile(spring)
    shapes.loft_x(m, [(x, head_profile(s)[0]) for x, s in arch], slots, cap_slot="ashlar")
    # The silt banked up the throat from the canal's floor; the throat's back.
    m.shell()
    silt = [(0.0, WALL_FOOT), (0.0, WATER), (THROAT, SILT_BACK), (THROAT, WALL_FOOT)]
    shapes.loft_x(m, [(a, silt), (b, silt)], "basalt")
    m.shell()
    # (Its back and foot short of the wall's, its ends into the piers, so it never
    # lies in a plane with the head.)
    m.box((a - 0.05, THROAT, WALL_FOOT + 0.05), (b + 0.05, WALL_THICK - 0.05, spring + r), "basalt")
    return m.make()


# The walkway's mouth: 3 m wide, from the canal's floor to the coping, which
# spans it as a lintel; the walkway's floor half a metre down behind.
MOUTH = 3.0


def culvert_open():
    """The canal walkway's way in: the wall cut through below the coping,
    the coping its lintel, a sill at the canal's floor."""
    m = common.Mesh("culvert_open", outward=True)
    a, b = (WALL_LENGTH - MOUTH) / 2, (WALL_LENGTH + MOUTH) / 2
    _piers(m, a, b)
    m.shell()
    m.box((a, 0.0, WALL_FOOT), (b, WALL_THICK, WATER), "ashlar")
    return m.make()


# The steps: a platform beside the wall, then six risers down a metre.
PLATFORM = 1.2
RISERS = 6


def canal_landing_steps():
    """A metre's flight, solid, its sides closed: from the street (or the
    landing) at z 0 a platform PLATFORM long beside the wall, then down
    along +X to z -1; STEP_WIDTH across (y), centred on its origin."""
    m = common.Mesh("canal_landing_steps", outward=True)
    side = [(0.0, -1.0), (0.0, 0.0), (PLATFORM, 0.0)]

    for k in range(1, RISERS):
        x = PLATFORM + STEP_TREAD * (k - 1)
        side += [(x, -STEP_RISE * k), (x + STEP_TREAD, -STEP_RISE * k)]

    side.append((PLATFORM + STEP_TREAD * (RISERS - 1), -1.0))
    half = STEP_WIDTH / 2
    rings = [[(x, -half, z) for x, z in side], [(x, half, z) for x, z in side]]
    shapes.loft(m, rings, "chiluca")
    return m.make()


# The ring: on a stone let into the coping, its top 4 cm proud (more than
# the gate's 3 cm), a ring of iron lying on it.
# (Its sides well inside the coping's faces: more than the gate's 3 cm.)
RING_STONE = (0.2, 0.04)
RING = (0.1, 0.025, 12)          # radius, section, segments


def mooring_ring():
    """An iron mooring ring on its stone, set into the coping, centred on
    its origin (the coping's middle, its top at z 0)."""
    m = common.Mesh("mooring_ring", outward=True)
    h = RING_STONE[0] / 2
    m.box((-h, -h, -0.25), (h, h, RING_STONE[1]), "chiluca")
    r, t, n = RING
    z = RING_STONE[1] + t / 2

    for k in range(n):
        a0, a1 = 2 * math.pi * k / n, 2 * math.pi * (k + 1) / n
        m.bar((r * math.cos(a0), r * math.sin(a0), z), (r * math.cos(a1), r * math.sin(a1), z), t, t, "iron",
              caps=(True, True))

    return m.make()


# The joints' close-ups (tools/eclipse/joints.py), on stand-in quay setts
# at 0, the landing at -1 and the canal's floor at -2.
SETTS = (0.24, 0.23, 0.26)
SILT = (0.2, 0.22, 0.18)
QUAY = (-12.0, COPING_BACK, 12.0, 12.0, -0.002, SETTS)
FLOOR = (-12.0, -12.0, 12.0, 0.0, WATER - 0.002, SILT)


def _walls(x0, n, piece="canal_wall"):
    return [(piece, (x0 + WALL_LENGTH * k, 0.0, 0.0), 0) for k in range(n)]


JOINTS = {
    "07_coping_quay": {"eye": (2.5, -1.2, 0.9), "target": (2.0, 0.2, -0.1), "show": _walls(-4.5, 3),
                       "planes": [QUAY, FLOOR]},
    "08_ashlar_rubble": {"eye": (2.25, -4.0, -1.0), "target": (2.25, 0.0, -1.1), "show": _walls(-4.5, 3),
                         "planes": [QUAY, FLOOR]},
    "09_landing_steps": {"eye": (6.0, -6.0, 1.5), "target": (1.5, 0.0, -0.6),
                         "show": [("canal_wall_corner", (0.0, 0.0, 0.0), 0),
                                  ("canal_wall_low", (CORNER, 0.0, 0.0), 0),
                                  ("canal_landing_steps", (CORNER + 0.4, -STEP_WIDTH / 2 - COPING_PROUD, 0.0), 0)],
                         "planes": [(-12.0, COPING_BACK, 12.0, 12.0, -0.002, SETTS),
                                    (-12.0, -12.0, 12.0, 0.0, -1.002, SETTS)]},
    "10_culvert": {"eye": (2.25, -3.0, -1.2), "target": (2.25, 0.0, -1.5), "show": _walls(-4.5, 1) + [("culvert", (0.0, 0.0, 0.0), 0)] + _walls(4.5, 1),
                   "planes": [QUAY, FLOOR]},
    "10b_walkway_mouth": {"eye": (2.25, -3.5, -1.0), "target": (2.25, 0.0, -1.2),
                          "show": _walls(-4.5, 1) + [("culvert_open", (0.0, 0.0, 0.0), 0)] + _walls(4.5, 1),
                          "planes": [QUAY, FLOOR]},
    "07b_mooring_ring": {"eye": (0.9, -0.9, 0.7), "target": (0.0, 0.0, 0.0),
                         "show": _walls(-2.25, 1) + [("mooring_ring", (0.0, (COPING_BACK - COPING_PROUD) / 2, 0.0), 0)],
                         "planes": [QUAY, FLOOR]},
}


# The vertex paint: the waterline's band where the water stands (the low
# wall's wet twin stands a metre lower, under a landing's mouth).
WEATHER = {"coarse": {"canal_wall": 1.0, "canal_wall_short": 1.0, "canal_wall_low": 1.0, "canal_wall_low_wet": 1.0,
                      "canal_wall_low_short": 1.0, "canal_wall_low_wet_short": 1.0,
                      "canal_wall_corner": 1.0, "culvert": 1.0, "culvert_open": 1.0, "canal_landing_steps": 1.0,
                      "mooring_ring": 1.0},
           "blendable": ["chiluca", "ashlar", "rubble"], "foot": [],
           "tide": {"canal_wall": (WATER, -1.55), "canal_wall_short": (WATER, -1.55), "culvert": (WATER, -1.55),
                    "culvert_open": (WATER, -1.55), "canal_wall_low_wet": (WATER + LOW, -1.55 + LOW),
                    "canal_wall_low_wet_short": (WATER + LOW, -1.55 + LOW)},
           "ground_holes": [(-20.0, -20.0, 20.0, 0.0)]}


def build():
    common.reset()
    canal_wall()
    canal_wall_short()
    canal_wall_low()
    canal_wall_low("canal_wall_low_short", WALL_SHORT)
    canal_wall_low("canal_wall_low_wet")
    canal_wall_low("canal_wall_low_wet_short", WALL_SHORT)
    canal_wall_corner()
    culvert()
    culvert_open()
    canal_landing_steps()
    mooring_ring()


def main():
    build()
    common.export_piece(NAME, ATLAS, SLOTS, weather=WEATHER, out=common.ROOT / "assets" / "eclipse" / "kit",
                        sets_each=True)


if __name__ == "__main__":
    main()
