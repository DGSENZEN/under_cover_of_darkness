"""The scene kit (docs/superpowers/specs/2026-10-10-zocalo-scenes-design.md):
the props the Zócalo's scenes are staged with: the organ grinder's barrel
organ, the evangelistas' typewriter desks, a wake's coffin on two chairs,
braziers, comales and ollas, baskets, crates, the canary's cage and card box,
a censer, lanterns, an overturned fruit cart and its spilled crates, pulque
barrels, a market cart covered for the night, washing on a line, an
ex-voto, a soapbox, a press camera, firewood. Each its own object at the
origin, resting on the ground (the line hangs from its hooks at 3.2 m);
things carried (a lantern, a censer, a basket, a bundle) rest on the ground
too and the scene lifts them to a figure's hand. Every word or picture is a
blank canvas (`sign`) for the user.

    Blender -b --factory-startup --python tools/eclipse/scene_kit.py

Blender axes: a piece's middle on the ground at the origin, Z up, its front
-Y.
"""

import math
import os
import random
import sys

from mathutils import Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import common  # noqa: E402
import shapes  # noqa: E402

NAME = "scene_kit"
ATLAS = 1536
CARDS = ("laundry",)
SLOTS = ["wood", "iron", "brass", "canvas", "clay_pot", "wax", "marigold", "sign", "glass", "chiluca", "steel", "coal",
         "fruit"] + list(CARDS)

HUNG = ("laundry_line",)


def _ring(centre, axis, radius, sides):
    axis = Vector(axis).normalized()
    side = axis.orthogonal().normalized()
    other = axis.cross(side)
    return [tuple(Vector(centre) + (side * math.cos(2 * math.pi * k / sides) + other * math.sin(2 * math.pi * k / sides))
                  * radius) for k in range(sides)]


def turned(m, profile, axis, at, sides, slot):
    """A lathe about any `axis` through `at`: profile [(r, t)] along it (an
    upright one closes at a point where r is 0, shapes.lathe)."""
    m.shell()
    axis = Vector(axis).normalized()

    if abs(axis.z - 1.0) < 1e-9:
        shapes.lathe(m, [(r, at[2] + t) for r, t in profile], sides, slot, at=(at[0], at[1], 0.0))
        return

    shapes.loft(m, [_ring(Vector(at) + axis * t, axis, r, sides) for r, t in profile], slot, caps=True, fan=True)


def wheel(m, x, y, z, radius, width=0.05, sides=10, axis=(1.0, 0.0, 0.0)):
    a = Vector(axis).normalized()
    c = Vector((x, y, z))
    m.shell()
    m.tube(tuple(c - a * width / 2), tuple(c + a * width / 2), radius, sides, "wood", caps=(True, True))


def leg(m, x, y, z0, z1, w=0.04, slot="wood"):
    m.shell()
    m.box((x - w / 2, y - w / 2, z0), (x + w / 2, y + w / 2, z1), slot)


def chair(m, at=(0.0, 0.0), back=1):
    """A wooden chair, its seat at 0.47, its back on the side `back` (+1: +Y)."""
    cx, cy = at
    m.shell()
    m.box((cx - 0.21, cy - 0.2, 0.43), (cx + 0.21, cy + 0.2, 0.47), "wood")

    for sx in (-1, 1):
        for sy in (-1, 1):
            leg(m, cx + sx * 0.17, cy + sy * 0.16, 0.0, 0.43)

        leg(m, cx + sx * 0.17, cy + back * 0.16, 0.47, 0.95)

    for z in (0.66, 0.82):
        m.shell()
        m.box((cx - 0.15, cy + back * 0.16 - 0.015, z), (cx + 0.15, cy + back * 0.16 + 0.015, z + 0.08), "wood")


# The pieces

def barrel_organ(m):
    """An organillero's barrel organ on its two-wheeled stand: the case, its
    painted front (the user's), the crank."""
    for side in (-1, 1):
        wheel(m, side * 0.42, 0.0, 0.3, 0.3)

    m.shell()
    m.tube((-0.4, 0.0, 0.3), (0.4, 0.0, 0.3), 0.025, 6, "iron", caps=(True, True))
    m.shell()
    m.box((-0.38, -0.25, 0.45), (0.38, 0.25, 0.5), "wood")
    m.shell()
    m.box((-0.34, -0.21, 0.5), (0.34, 0.21, 1.05), "wood")
    m.shell()
    shapes.panel(m, (-0.28, -0.25, 0.58), (0.28, -0.21, 0.98), 0.04, "brass", "sign")
    m.shell()
    m.box((-0.36, -0.23, 1.05), (0.36, 0.23, 1.09), "brass")
    m.shell()
    m.bar((0.34, 0.0, 0.8), (0.46, 0.0, 0.8), 0.03, 0.03, "iron", caps=(True, True))
    m.shell()
    m.bar((0.46, 0.0, 0.8), (0.46, 0.0, 0.62), 0.03, 0.03, "iron", caps=(True, True))
    m.shell()
    m.bar((0.0, -0.22, 0.47), (0.0, -0.48, 0.0), 0.05, 0.05, "wood", caps=(True, True))

    for side in (-1, 1):
        m.shell()
        m.bar((side * 0.3, 0.24, 0.48), (side * 0.3, 0.62, 0.7), 0.04, 0.04, "wood", caps=(True, True))


def typewriter_desk(m):
    """A letter-writer's folding table with its typewriter, a sheet in it."""
    m.shell()
    m.box((-0.4, -0.25, 0.7), (0.4, 0.25, 0.74), "wood")

    for sx in (-1, 1):
        for sy in (-1, 1):
            leg(m, sx * 0.35, sy * 0.2, 0.0, 0.7)

    m.shell()
    m.box((-0.15, -0.1, 0.74), (0.15, 0.12, 0.83), "iron")
    m.shell()
    shapes.obox(m, (0.0, -0.13, 0.775), (0.26, 0.08, 0.04), (math.radians(14), 0.0, 0.0), "iron")
    m.shell()
    m.tube((-0.19, 0.08, 0.87), (0.19, 0.08, 0.87), 0.035, 6, "steel", caps=(True, True))
    m.shell()
    m.box((-0.1, 0.07, 0.9), (0.1, 0.09, 1.1), "sign")


def stool(m):
    m.shell()
    m.box((-0.17, -0.17, 0.42), (0.17, 0.17, 0.46), "wood")

    for sx in (-1, 1):
        for sy in (-1, 1):
            leg(m, sx * 0.12, sy * 0.12, 0.0, 0.42, w=0.035)


def chair_piece(m):
    chair(m)


def coffin_on_chairs(m):
    """A wake on the pavement: a coffin laid on two chairs, back to back."""
    chair(m, (0.0, -0.78), back=-1)
    chair(m, (0.0, 0.78), back=1)
    outline = [(-0.2, -0.9), (0.2, -0.9), (0.3, 0.45), (0.22, 0.9), (-0.22, 0.9), (-0.3, 0.45)]
    m.shell()
    m.prism(outline, 0.47, 0.8, "wood")
    lid = [(x * 0.85, y * 0.95) for x, y in outline]
    m.shell()
    m.prism(lid, 0.8, 0.85, "wood")


def brazier(m):
    """An iron brazier on three legs, heaped with coals."""
    turned(m, [(0.08, 0.55), (0.36, 0.8)], (0, 0, 1), (0, 0, 0), 10, "iron")
    turned(m, [(0.33, 0.8), (0.22, 0.86), (0.0, 0.9)], (0, 0, 1), (0, 0, 0), 10, "coal")

    for k in range(3):
        a = 2 * math.pi * k / 3
        m.shell()
        m.bar((0.18 * math.cos(a), 0.18 * math.sin(a), 0.62), (0.4 * math.cos(a), 0.4 * math.sin(a), 0.03), 0.04, 0.04,
              "iron", caps=(True, True))
        m.shell()
        m.box((0.4 * math.cos(a) - 0.035, 0.4 * math.sin(a) - 0.035, 0.0),
              (0.4 * math.cos(a) + 0.035, 0.4 * math.sin(a) + 0.035, 0.05), "iron")


def comal_pots(m):
    """A clay comal on three stones over the fire's place, two pots beside it."""
    for k in range(3):
        a = 2 * math.pi * k / 3 + 0.3
        m.shell()
        shapes.obox(m, (0.2 * math.cos(a), 0.2 * math.sin(a), 0.09), (0.16, 0.13, 0.18), (0.0, 0.0, a), "chiluca")

    turned(m, [(0.3, 0.18), (0.33, 0.225)], (0, 0, 1), (0, 0, 0), 12, "clay_pot")
    turned(m, [(0.1, 0.0), (0.18, 0.12), (0.15, 0.26), (0.12, 0.3)], (0, 0, 1), (0.55, 0.15, 0), 9, "clay_pot")
    turned(m, [(0.08, 0.0), (0.13, 0.1), (0.1, 0.2)], (0, 0, 1), (0.45, -0.3, 0), 8, "clay_pot")


def _basket(m, at, r=0.22, h=0.26, fill="fruit"):
    x, y, z = at
    turned(m, [(r * 0.7, 0.0), (r, h)], (0, 0, 1), (x, y, z), 9, "wood")
    turned(m, [(r * 0.92, h), (r * 0.55, h + 0.06), (0.0, h + 0.08)], (0, 0, 1), (x, y, z), 9, fill)


def basket(m):
    _basket(m, (0.0, 0.0, 0.0))


def baskets_stack(m):
    _basket(m, (-0.24, 0.0, 0.0))
    _basket(m, (0.24, 0.02, 0.0), fill="marigold")
    _basket(m, (0.0, 0.05, 0.34), r=0.2, fill="fruit")


def _crate(m, lo, hi):
    m.shell()
    m.box(lo, hi, "wood")
    x0, y0, z0 = lo
    x1, y1, z1 = hi

    for y, d in ((y0, -1), (y1, 1)):
        m.shell()
        m.box((x0 + 0.04, min(y, y + d * 0.04), z0 + 0.04), (x0 + 0.1, max(y, y + d * 0.04), z1 - 0.04), "wood")
        m.shell()
        m.box((x1 - 0.1, min(y, y + d * 0.04), z0 + 0.04), (x1 - 0.04, max(y, y + d * 0.04), z1 - 0.04), "wood")


def crate(m):
    _crate(m, (-0.25, -0.2, 0.0), (0.25, 0.2, 0.4))


def crate_soapbox(m):
    """A preacher's (or a barker's) box to stand on."""
    _crate(m, (-0.3, -0.2, 0.0), (0.3, 0.2, 0.35))


def canary_box(m):
    """The pajarito de la suerte: a little table, the canary's brass cage, the
    box of fortunes it picks from (their faces the user's)."""
    m.shell()
    m.box((-0.3, -0.2, 0.68), (0.3, 0.2, 0.72), "wood")

    for sx in (-1, 1):
        for sy in (-1, 1):
            leg(m, sx * 0.25, sy * 0.15, 0.0, 0.68)

    m.shell()
    m.box((-0.24, -0.12, 0.72), (0.0, 0.12, 0.76), "brass")

    for k in range(6):
        a = 2 * math.pi * k / 6
        m.shell()
        m.box((-0.12 + 0.09 * math.cos(a) - 0.0125, 0.09 * math.sin(a) - 0.0125, 0.76),
              (-0.12 + 0.09 * math.cos(a) + 0.0125, 0.09 * math.sin(a) + 0.0125, 0.98), "brass")

    turned(m, [(0.12, 0.98), (0.06, 1.06), (0.0, 1.1)], (0, 0, 1), (-0.12, 0, 0), 6, "brass")
    m.shell()
    m.sphere((-0.12, 0.0, 0.83), 0.035, 3, 5, "wax")
    m.shell()
    m.box((0.06, -0.12, 0.72), (0.26, 0.1, 0.8), "wood")
    m.shell()
    m.box((0.09, -0.09, 0.8), (0.23, 0.07, 0.86), "sign")


def censer(m):
    """A copal censer: its pot, its pierced lid, its chain gathered to a ring."""
    turned(m, [(0.06, 0.0), (0.1, 0.06), (0.09, 0.12)], (0, 0, 1), (0, 0, 0), 8, "brass")
    turned(m, [(0.085, 0.12), (0.05, 0.18), (0.0, 0.22)], (0, 0, 1), (0, 0, 0), 8, "brass")
    m.shell()
    m.box((-0.015, -0.015, 0.21), (0.015, 0.015, 0.62), "iron")
    turned(m, [(0.04, 0.62), (0.04, 0.65)], (0, 0, 1), (0, 0, 0), 6, "iron")


def _lantern(m, s):
    m.shell()
    m.box((-0.08 * s, -0.08 * s, 0.0), (0.08 * s, 0.08 * s, 0.04 * s), "iron")
    m.shell()
    m.box((-0.04 * s, -0.04 * s, 0.04 * s), (0.04 * s, 0.04 * s, 0.22 * s), "glass")

    for sx in (-1, 1):
        for sy in (-1, 1):
            m.shell()
            m.box((sx * 0.065 * s - 0.01 * s, sy * 0.065 * s - 0.01 * s, 0.04 * s),
                  (sx * 0.065 * s + 0.01 * s, sy * 0.065 * s + 0.01 * s, 0.22 * s), "iron")

    turned(m, [(0.09 * s, 0.22 * s), (0.03 * s, 0.3 * s)], (0, 0, 1), (0, 0, 0), 8, "iron")

    for a, b in (((-0.06, 0.0, 0.3), (-0.06, 0.0, 0.4)), ((-0.06, 0.0, 0.4), (0.06, 0.0, 0.4)),
                 ((0.06, 0.0, 0.4), (0.06, 0.0, 0.3))):
        m.shell()
        m.bar(tuple(v * s for v in a), tuple(v * s for v in b), 0.02 * s, 0.02 * s, "iron", caps=(True, True))


def lantern_carried(m):
    _lantern(m, 1.0)


def lantern_set(m):
    _lantern(m, 1.6)


def cart_overturned(m):
    """A fruit cart knocked on its side at the rails: its bed stood up, one
    wheel in the air, the other come off and lying by it, its shafts askew."""
    m.shell()
    m.box((-0.8, -0.03, 0.0), (0.8, 0.03, 1.0), "wood")

    for z0 in (0.0, 0.94):
        m.shell()
        m.box((-0.8, 0.03, z0), (0.8, 0.28, z0 + 0.06), "wood")

    wheel(m, 0.0, -0.09, 0.5, 0.45, axis=(0.0, 1.0, 0.0))
    wheel(m, 1.25, -0.6, 0.025, 0.45, axis=(0.0, 0.0, 1.0))

    for z in (0.15, 0.85):
        m.shell()
        m.bar((-0.7, -0.03, z), (-1.75, -0.4, z * 0.4 + 0.03), 0.06, 0.06, "wood", caps=(True, True))


def crates_spilled(m):
    """Two crates thrown down, fruit rolled out round them."""
    m.shell()
    shapes.obox(m, (-0.3, 0.1, 0.2), (0.5, 0.4, 0.4), (0.0, 0.0, 0.4), "wood")
    m.shell()
    shapes.obox(m, (0.45, -0.2, 0.2), (0.4, 0.5, 0.4), (0.0, math.radians(90), 0.9), "wood")
    rng = random.Random(7)

    for k in range(12):
        a = rng.uniform(0, 2 * math.pi)
        d = rng.uniform(0.55, 1.3)
        r = rng.uniform(0.04, 0.06)
        m.shell()
        m.sphere((0.1 + d * math.cos(a), d * math.sin(a), r), r, 3, 6, "fruit")


def _barrel(m, at, axis):
    turned(m, [(0.25, 0.0), (0.3, 0.4), (0.25, 0.8)], axis, at, 10, "wood")

    for t in (0.18, 0.62):
        turned(m, [(0.3, t), (0.3, t + 0.05)], axis, at, 10, "iron")


def pulque_barrels(m):
    """Pulque barrels at a door: two standing, one rolled on its side."""
    _barrel(m, (-0.35, 0.0, 0.0), (0, 0, 1))
    _barrel(m, (0.35, 0.05, 0.0), (0, 0, 1))
    _barrel(m, (0.0, -0.75, 0.3), (1, 0, 0))


def cart_covered(m):
    """A market cart covered for the night: canvas tied over its load."""
    m.shell()
    m.box((-0.5, -0.8, 0.55), (0.5, 0.8, 0.61), "wood")

    for side in (-1, 1):
        wheel(m, side * 0.58, 0.0, 0.45, 0.45)

    m.shell()
    m.tube((-0.56, 0.0, 0.45), (0.56, 0.0, 0.45), 0.025, 6, "iron", caps=(True, True))
    tarp = [(-0.5, 0.61), (0.5, 0.61), (0.44, 1.0), (0.0, 1.15), (-0.44, 1.0)]
    m.shell()
    shapes.loft(m, [[(x, y, z) for x, z in tarp] for y in (-0.82, 0.82)], "canvas", caps=True)

    for side in (-1, 1):
        m.shell()
        m.bar((side * 0.38, -0.8, 0.58), (side * 0.38, -1.8, 0.04), 0.06, 0.06, "wood", caps=(True, True))
        m.shell()
        m.box((side * 0.38 - 0.04, -1.84, 0.0), (side * 0.38 + 0.04, -1.76, 0.05), "wood")


def laundry_line(m):
    """Washing on a line strung across a side street, 8 m from its west hook
    (the origin, at the wall's foot) along +X, hung at 3.2 m and sagging
    0.25; its washing (our painting) on cards under it. Stretched to fit."""
    drop = 0.25
    m.shell()
    shapes.sag(m, (0.0, 0.0, 3.2), (8.0, 0.0, 3.2), 0.015, 4, drop, 12, "iron")
    sag = lambda x: 3.2 - drop * 4 * (x / 8.0) * (1 - x / 8.0)

    for k in range(4):
        x0, x1 = 0.1 + 2.0 * k, 1.9 + 2.0 * k
        top0, top1 = sag(x0) - 0.01, sag(x1) - 0.01
        h = 0.95
        m.card([(x0, 0.0, top0 - h), (x1, 0.0, top1 - h), (x1, 0.0, top1), (x0, 0.0, top0)], "laundry",
               round=((x0 + x1) / 2, -3.0, top0 - h / 2))


def exvoto_plate(m):
    """An ex-voto: a tin plate (its picture the user's) propped on a stone."""
    m.shell()
    shapes.obox(m, (0.0, 0.02, 0.15), (0.24, 0.02, 0.3), (math.radians(-14), 0.0, 0.0), "sign")
    m.shell()
    m.box((-0.07, 0.06, 0.0), (0.07, 0.2, 0.12), "chiluca")


def camera_tripod(m):
    """A press camera on its tripod: a box camera, its lens, its cloth hood."""
    for k in range(3):
        a = 2 * math.pi * k / 3 + math.pi / 2
        foot = (0.42 * math.cos(a), 0.42 * math.sin(a))
        m.shell()
        m.bar((0.06 * math.cos(a), 0.06 * math.sin(a), 1.22), (foot[0], foot[1], 0.04), 0.03, 0.03, "wood",
              caps=(True, True))
        m.shell()
        m.box((foot[0] - 0.025, foot[1] - 0.025, 0.0), (foot[0] + 0.025, foot[1] + 0.025, 0.05), "iron")

    m.shell()
    m.box((-0.12, -0.15, 1.24), (0.12, 0.15, 1.44), "wood")
    m.shell()
    m.tube((0.0, -0.15, 1.34), (0.0, -0.27, 1.34), 0.05, 8, "brass", caps=(True, True))
    m.shell()
    m.box((-0.17, 0.15, 1.18), (0.17, 0.45, 1.52), "canvas")


def _log(m, a, b, r=0.06):
    m.shell()
    m.tube(a, b, r, 6, "wood", caps=(True, True))


def firewood_stack(m):
    """Firewood brought up from the landing, stacked: four rows of logs."""
    for row in range(4):
        z = 0.06 + row * 0.11
        off = 0.065 if row % 2 else 0.0

        for k in range(5 - row % 2):
            y = -0.3 + off + k * 0.13
            _log(m, (-0.55, y, z), (0.55, y, z))


def firewood_bundle(m):
    """A porter's bundle of firewood, roped twice."""
    for k in range(6):
        a = 2 * math.pi * k / 6
        _log(m, (-0.4, 0.1 * math.cos(a), 0.17 + 0.1 * math.sin(a)), (0.4, 0.1 * math.cos(a), 0.17 + 0.1 * math.sin(a)),
             r=0.055)

    for x in (-0.22, 0.22):
        m.shell()
        m.tube((x - 0.025, 0.0, 0.17), (x + 0.025, 0.0, 0.17), 0.19, 8, "canvas", caps=(True, True))


def atole_pot(m):
    """An atole seller's olla on its iron fire ring."""
    turned(m, [(0.22, 0.0), (0.24, 0.12)], (0, 0, 1), (0, 0, 0), 10, "iron")
    turned(m, [(0.14, 0.12), (0.28, 0.32), (0.26, 0.52), (0.17, 0.62), (0.19, 0.68)], (0, 0, 1), (0, 0, 0), 10,
           "clay_pot")


def flowers_bucket(m):
    """A tin bucket of cempasúchil, the dead's flower."""
    turned(m, [(0.14, 0.0), (0.18, 0.32)], (0, 0, 1), (0, 0, 0), 10, "steel")
    turned(m, [(0.19, 0.32), (0.16, 0.45), (0.0, 0.5)], (0, 0, 1), (0, 0, 0), 9, "marigold")

    for k in range(5):
        a = 2 * math.pi * k / 5
        m.shell()
        m.sphere((0.1 * math.cos(a), 0.1 * math.sin(a), 0.52), 0.06, 3, 6, "marigold")


PIECES = {"barrel_organ": barrel_organ, "typewriter_desk": typewriter_desk, "stool": stool, "chair": chair_piece,
          "coffin_on_chairs": coffin_on_chairs, "brazier": brazier, "comal_pots": comal_pots, "basket": basket,
          "baskets_stack": baskets_stack, "crate": crate, "canary_box": canary_box, "censer": censer,
          "lantern_carried": lantern_carried, "lantern_set": lantern_set, "cart_overturned": cart_overturned,
          "crates_spilled": crates_spilled, "pulque_barrels": pulque_barrels, "cart_covered": cart_covered,
          "laundry_line": laundry_line, "exvoto_plate": exvoto_plate, "crate_soapbox": crate_soapbox,
          "camera_tripod": camera_tripod, "firewood_stack": firewood_stack, "firewood_bundle": firewood_bundle,
          "atole_pot": atole_pot, "flowers_bucket": flowers_bucket}


def _settle(obj):
    low = min(v.co.z for v in obj.data.vertices)

    for v in obj.data.vertices:
        v.co.z -= low


def build():
    common.reset()

    for name, f in PIECES.items():
        m = common.Mesh(name, outward=True)
        f(m)
        obj = m.make()

        if name not in HUNG:
            _settle(obj)


SETTS = (0.24, 0.23, 0.26)
JOINTS = {
    "12_wake": {"eye": (2.5, -3.0, 1.6), "target": (0.0, 0.0, 0.6), "show": [("coffin_on_chairs", (0, 0, 0), 0)],
                "planes": [(-20, -20, 20, 20, -0.002, SETTS)]},
}

WEATHER = {"coarse": {n: 2.0 for n in PIECES}, "blendable": ["wood", "iron", "canvas", "clay_pot"],
           "foot": ["wood", "iron", "clay_pot", "chiluca"]}


def main():
    build()
    common.export_piece(NAME, ATLAS, SLOTS, weather=WEATHER, out=common.ROOT / "assets" / "eclipse" / "kit",
                        sets_each=True, cards=CARDS)


if __name__ == "__main__":
    main()
