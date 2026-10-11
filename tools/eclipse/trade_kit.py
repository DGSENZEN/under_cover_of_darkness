"""The trade kit (docs/superpowers/refs/mexico_city/cards/street_life.md,
the Zócalo's family 1b): the street's carts, kiosks and stands, and the
market's pulp, the curiosity stand, the monster wagon, the luchadores'
shrine, the spirit photographer, El Secreto's relic crates. Each piece its
own object at the origin, resting on the ground; one atlas, exported to
assets/eclipse/kit/. Every face for words or pictures is a blank canvas
(`sign`) for the user.

    Blender -b --factory-startup --python tools/eclipse/trade_kit.py

Blender axes: a piece's middle on the ground at the origin, Z up, its
front (where the trade faces the street) -Y.
"""

import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import common  # noqa: E402
import shapes  # noqa: E402

NAME = "trade_kit"
ATLAS = 1536
SLOTS = ["wood", "iron", "canvas", "brass", "glass", "sign", "flesh", "obsidian", "marigold", "steel", "wax"]

# Anything laid on a face stands at least this proud of it (gate.LAYER_GAP is 3 cm).
PROUD = 0.04


def _object(name, build):
    m = common.Mesh(name, outward=True)
    build(m)
    return m.make()


def wheel(m, x, y, radius, width=0.06, sides=10):
    """A cartwheel turning about X, its rim on the ground."""
    m.shell()
    m.tube((x - width / 2, y, radius), (x + width / 2, y, radius), radius, sides, "wood", caps=(True, True))


def cart_bed(m, length=1.6, width=1.0, height=0.55, sides=0.25, shafts=True, wheel_r=0.45):
    """A two-wheeled cart's bed and sides, its shafts down on the ground in
    front (-Y), the wheels either side."""
    hw, hl = width / 2, length / 2
    m.shell()
    m.box((-hw, -hl, height), (hw, hl, height + 0.06), "wood")

    for side in (-1, 1):
        m.shell()
        m.box((side * hw - 0.03, -hl, height + 0.06), (side * hw + 0.03, hl, height + 0.06 + sides), "wood")
        wheel(m, side * (hw + 0.06), 0.0, wheel_r)

    if shafts:
        for side in (-1, 1):
            m.shell()
            m.bar((side * (hw - 0.1), -hl + 0.1, height), (side * (hw - 0.1), -hl - 1.1, 0.04), 0.06, 0.06, "wood",
                  caps=(True, True))
            # A block under each shaft's end, so it rests on the ground.
            m.shell()
            m.box((side * (hw - 0.1) - 0.07, -hl - 1.15, 0.0), (side * (hw - 0.1) + 0.07, -hl - 1.0, 0.06), "wood")

    return height + 0.06


def sack(m, x, y, z, w=0.4, d=0.3, h=0.35):
    m.shell()
    shapes.bevelled_box(m, (x - w / 2, y - d / 2, z), (x + w / 2, y + d / 2, z + h), "canvas", 0.05)


def cart_hand(m):
    top = cart_bed(m)

    for x, y, h in ((-0.22, -0.45, 0.35), (0.2, -0.3, 0.3), (-0.2, 0.3, 0.35), (0.22, 0.42, 0.28)):
        sack(m, x, y, top, h=h)


def cart_flower(m):
    top = cart_bed(m)
    m.shell()
    shapes.lathe(m, [(0.4, 0.0), (0.38, 0.12), (0.28, 0.26), (0.0, 0.32)], 10, "marigold", at=(0.0, -0.36, top))
    m.shell()
    shapes.lathe(m, [(0.33, 0.0), (0.31, 0.14), (0.2, 0.26), (0.0, 0.3)], 10, "marigold", at=(0.05, 0.42, top))

    for k in range(5):
        a = 2 * math.pi * k / 5
        m.shell()
        m.bar((0.25 * math.cos(a), 0.05 + 0.25 * math.sin(a), top), (0.32 * math.cos(a), 0.05 + 0.32 * math.sin(a),
                                                                       top + 0.6), 0.03, 0.03, "wax", caps=(True, True))


def cart_tamale(m):
    top = cart_bed(m, length=1.2, width=0.8, height=0.45, sides=0.15, wheel_r=0.35)
    m.shell()
    shapes.lathe(m, [(0.24, 0.0), (0.26, 0.05), (0.26, 0.55), (0.28, 0.58), (0.2, 0.66), (0.06, 0.7), (0.0, 0.74)],
                 10, "steel", at=(0.0, -0.15, top))
    m.shell()
    shapes.lathe(m, [(0.16, 0.0), (0.22, 0.2), (0.0, 0.2)], 8, "wood", at=(0.12, 0.35, top))
    # The tamalera's stool beside it.
    for x, y in ((-0.85, -0.1), (-0.65, -0.1), (-0.85, 0.1), (-0.65, 0.1)):
        m.shell()
        m.box((x - 0.025, y - 0.025, 0.0), (x + 0.025, y + 0.025, 0.4), "wood")

    m.shell()
    m.box((-0.9, -0.15, 0.4), (-0.6, 0.15, 0.45), "wood")


def cart_ice(m):
    top = cart_bed(m)
    m.shell()
    m.box((-0.45, -0.75, top), (0.45, 0.05, top + 0.5), "wood")
    m.shell()
    shapes.bevelled_box(m, (-0.35, 0.15, top), (0.35, 0.7, top + 0.35), "canvas", 0.06)

    for k in range(5):
        m.shell()
        shapes.lathe(m, [(0.045, 0.0), (0.045, 0.18), (0.03, 0.24), (0.03, 0.3)], 6, "glass",
                     at=(-0.3 + 0.15 * k, -0.35, top + 0.5))


def cart_firewood(m):
    top = cart_bed(m, sides=0.35)

    for row in range(3):
        for k in range(4 - row):
            x = -0.33 + 0.22 * k + 0.11 * row
            m.shell()
            m.tube((x, -0.75, top + 0.1 + 0.19 * row), (x, 0.75, top + 0.1 + 0.19 * row), 0.09, 6, "wood",
                   caps=(True, True))


def _booth(m, w, d, h, roof_over=0.15):
    """A wooden booth's body and its overhanging roof."""
    m.box((-w / 2, -d / 2, 0.0), (w / 2, d / 2, h), "wood")
    m.shell()
    m.box((-w / 2 - roof_over, -d / 2 - roof_over, h), (w / 2 + roof_over, d / 2 + roof_over, h + 0.12), "wood")


def kiosk_news(m):
    """The voceador's kiosk: a booth with a counter window, its shutters
    propped out, blank headline boards on its front and sides."""
    _booth(m, 1.8, 1.4, 2.5)
    m.shell()
    m.box((-0.8, -0.95, 0.95), (0.8, -0.7, 1.0), "wood")
    for side in (-1, 1):
        m.shell()
        m.bar((side * 0.5, -0.74, 2.3), (side * 0.5, -1.4, 2.6), 0.9, 0.04, "wood", caps=(True, True))

    m.shell()
    shapes.panel(m, (-0.7, -0.7 - PROUD, 1.2), (0.7, -0.7, 1.9), 0.05, "wood", "sign")

    for side in (-1, 1):
        m.shell()
        x = side * (0.9 + PROUD)
        m.box((min(x, side * 0.9), -0.5, 0.6), (max(x, side * 0.9), 0.5, 1.8), "sign")


def kiosk_lottery(m):
    _booth(m, 1.2, 1.0, 2.3)
    m.shell()
    m.box((-0.5, -0.65, 0.9), (0.5, -0.5, 0.95), "wood")
    m.shell()
    shapes.panel(m, (-0.5, -0.5 - PROUD, 1.1), (0.5, -0.5, 2.0), 0.05, "brass", "sign")


def kiosk_sweets(m):
    """A sweets stand: a table of jars and trays under a canvas awning."""
    for x, y in ((-0.75, -0.35), (0.75, -0.35), (-0.75, 0.35), (0.75, 0.35)):
        m.shell()
        m.box((x - 0.03, y - 0.03, 0.0), (x + 0.03, y + 0.03, 0.85), "wood")
        m.shell()
        m.box((x * 1.1 - 0.025, y * 1.6 - 0.025, 0.0), (x * 1.1 + 0.025, y * 1.6 + 0.025, 2.2 if y < 0 else 1.9), "wood")

    m.shell()
    m.box((-0.8, -0.4, 0.85), (0.8, 0.4, 0.9), "wood")
    m.shell()
    m.face([(-0.95, -0.7, 2.2), (0.95, -0.7, 2.2), (0.95, 0.7, 1.9), (-0.95, 0.7, 1.9)], "canvas")
    m.face([(-0.95, -0.7, 2.16), (-0.95, 0.7, 1.86), (0.95, 0.7, 1.86), (0.95, -0.7, 2.16)], "canvas")
    m.face([(-0.95, -0.7, 2.16), (0.95, -0.7, 2.16), (0.95, -0.7, 2.2), (-0.95, -0.7, 2.2)], "canvas")
    m.face([(-0.95, 0.7, 1.86), (-0.95, 0.7, 1.9), (0.95, 0.7, 1.9), (0.95, 0.7, 1.86)], "canvas")
    m.face([(-0.95, -0.7, 2.16), (-0.95, -0.7, 2.2), (-0.95, 0.7, 1.9), (-0.95, 0.7, 1.86)], "canvas")
    m.face([(0.95, -0.7, 2.16), (0.95, 0.7, 1.86), (0.95, 0.7, 1.9), (0.95, -0.7, 2.2)], "canvas")

    for k in range(4):
        m.shell()
        shapes.lathe(m, [(0.08, 0.0), (0.08, 0.2), (0.05, 0.24), (0.0, 0.25)], 8, "glass", at=(-0.5 + 0.33 * k, 0.15, 0.9))

    m.shell()
    m.box((-0.6, -0.3, 0.9), (0.6, -0.05, 0.96), "wood")


def shoeshine_stand(m):
    m.box((-0.3, -0.25, 0.0), (0.3, 0.25, 0.5), "wood")
    m.shell()
    m.box((-0.25, -0.2, 0.5), (0.25, 0.2, 0.56), "wood")
    m.shell()
    m.box((-0.25, 0.16, 0.56), (0.25, 0.22, 1.05), "wood")

    for x in (-0.12, 0.12):
        m.shell()
        m.bar((x, -0.25, 0.3), (x, -0.5, 0.35), 0.04, 0.04, "iron", caps=(True, True))
        m.shell()
        m.box((x - 0.06, -0.58, 0.32), (x + 0.06, -0.44, 0.38), "iron")

    m.shell()
    shapes.lathe(m, [(0.08, 0.0), (0.08, 0.06), (0.0, 0.07)], 10, "brass", at=(-0.6, 0.0, 0.0))


def booth_photographer(m):
    """The spirit photographer's booth: a box camera on a tripod under its
    black hood, a painted backdrop on its frame, the proofs on an easel
    (every picture the user's)."""
    for a in (0.0, 2.1, 4.2):
        fx, fy = 0.45 * math.cos(a), -0.8 + 0.45 * math.sin(a)
        m.shell()
        m.bar((0.0, -0.8, 1.2), (fx, fy, 0.05), 0.04, 0.04, "wood", caps=(True, True))
        # Its foot, flat on the ground.
        m.shell()
        m.box((fx - 0.04, fy - 0.04, 0.0), (fx + 0.04, fy + 0.04, 0.04), "brass")

    m.shell()
    m.box((-0.18, -1.05, 1.2), (0.18, -0.6, 1.55), "wood")
    m.shell()
    m.tube((0.0, -0.6, 1.375), (0.0, -0.45, 1.375), 0.08, 8, "brass", caps=(True, True))
    m.shell()
    shapes.bevelled_box(m, (-0.26, -1.25, 1.15), (0.26, -0.98, 1.7), "canvas", 0.05)
    # The backdrop, its frame and feet.
    m.shell()
    shapes.panel(m, (-1.1, 1.0, 0.15), (1.1, 1.06, 2.35), 0.08, "wood", "sign")

    for x in (-1.1, 1.1):
        m.shell()
        m.box((x - 0.05, 0.85, 0.0), (x + 0.05, 1.25, 0.15), "wood")

    # The proofs on an easel.
    for a, b in (((1.6, -0.2, 0.05), (1.6, -0.05, 1.5)), ((1.9, -0.2, 0.05), (1.9, -0.05, 1.5)),
                 ((1.75, 0.3, 0.05), (1.75, 0.0, 1.45))):
        m.shell()
        m.bar(a, b, 0.04, 0.04, "wood", caps=(True, True))
        m.shell()
        m.box((a[0] - 0.04, a[1] - 0.04, 0.0), (a[0] + 0.04, a[1] + 0.04, 0.04), "brass")

    m.shell()
    shapes.panel(m, (1.45, -0.2, 0.75), (2.05, -0.14, 1.35), 0.05, "wood", "sign")


def _jar(m, x, y, z, r=0.09, h=0.26, thing=True):
    """A glass jar on a shelf, a thing growing in it (closed, inside)."""
    m.shell()
    shapes.lathe(m, [(r, 0.0), (r, h), (r * 0.7, h + 0.03), (r * 0.7, h + 0.06), (0.0, h + 0.07)], 8, "glass",
                 at=(x, y, z))

    if thing:
        m.shell()
        shapes.lathe(m, [(0.0, 0.03), (r * 0.55, 0.07), (r * 0.45, h * 0.6), (r * 0.25, h * 0.85), (0.0, h * 0.9)], 6,
                     "flesh", at=(x, y, z))


def stand_curiosities(m):
    """The curiosity stand: a table and a stepped shelf of jars with hands
    growing in them, a pickled ahuízotl, hummingbird charms, a coiled snake,
    obsidian blades, ex-voto milagros."""
    for x, y in ((-0.8, -0.35), (0.8, -0.35), (-0.8, 0.35), (0.8, 0.35)):
        m.shell()
        m.box((x - 0.03, y - 0.03, 0.0), (x + 0.03, y + 0.03, 0.8), "wood")

    m.shell()
    m.box((-0.85, -0.4, 0.8), (0.85, 0.4, 0.85), "wood")
    m.shell()
    m.box((-0.85, 0.1, 0.85), (0.85, 0.4, 1.1), "wood")

    for k in range(4):
        _jar(m, -0.6 + 0.4 * k, 0.25, 1.1)

    _jar(m, -0.55, -0.15, 0.85, r=0.16, h=0.42)

    for k in range(3):
        m.shell()
        m.box((0.05 + 0.2 * k, -0.3, 0.85), (0.15 + 0.2 * k, -0.05, 0.9), "obsidian")

    m.shell()
    shapes.sag(m, (0.2, -0.05, 0.9 + 0.025), (0.7, -0.05, 0.9 + 0.025), 0.025, 6, -0.04, 8, "flesh")

    for k in range(5):
        m.shell()
        m.box((-0.8 + 0.12 * k, -0.42, 0.55), (-0.72 + 0.12 * k, -0.4 - PROUD - 0.02, 0.65), "brass")


def wagon_monster(m):
    """A travelling show's barred wagon: a glass tank in it where an ahuízotl
    circles, a barker's board on its side (blank)."""
    w, l, h = 1.8, 3.0, 0.8
    m.box((-w / 2, -l / 2, h), (w / 2, l / 2, h + 0.1), "wood")

    for side in (-1, 1):
        for y in (-1.0, 1.0):
            wheel(m, side * (w / 2 + 0.06), y, 0.4)

    # The cage's bars and its roof.
    for k in range(9):
        y = -l / 2 + 0.05 + (l - 0.1) * k / 8

        for side in (-1, 1):
            m.shell()
            # (4 cm either side of the end walls' plane: never within the gate's 3 cm.)
            m.box((side * w / 2 - 0.04, y - 0.025, h + 0.1), (side * w / 2 + 0.04, y + 0.025, h + 2.1), "iron")

    m.shell()
    m.box((-w / 2 - 0.1, -l / 2 - 0.1, h + 2.1), (w / 2 + 0.1, l / 2 + 0.1, h + 2.22), "wood")

    for y in (-l / 2, l / 2):
        m.shell()
        m.box((-w / 2, y - 0.03, h + 0.1), (w / 2, y + 0.03, h + 2.1), "wood")

    # The tank and what swims in it.
    m.shell()
    m.box((-0.6, -1.1, h + 0.1), (0.6, 1.1, h + 1.4), "glass")
    m.shell()
    shapes.lathe(m, [(0.0, 0.0), (0.18, 0.1), (0.22, 0.45), (0.16, 0.8), (0.0, 0.95)], 8, "flesh", at=(0.0, -0.35, h + 0.45))
    m.shell()
    m.tube((0.0, 0.3, h + 0.7), (0.0, 0.8, h + 0.75), 0.07, 6, "flesh", caps=(True, True))
    # The barker's board, standing out beside the wagon's front corner.
    bx0, bx1 = -w / 2 - 1.5, -w / 2 - 0.2
    m.shell()
    shapes.panel(m, (bx0, -l / 2 - 0.3 - PROUD, 0.7), (bx1, -l / 2 - 0.3, 1.9), 0.08, "wood", "sign")

    for x in (bx0 + 0.1, bx1 - 0.1):
        m.shell()
        m.box((x - 0.05, -l / 2 - 0.3, 0.0), (x + 0.05, -l / 2 - 0.2, 0.7), "wood")


def shrine_luchador(m):
    """A masked luchador's shrine: his mask on a post, candles, a cracked
    belt, his bills on a little board (the mask's face and the bills the
    user's)."""
    m.box((-0.5, -0.3, 0.0), (0.5, 0.3, 0.6), "wood")
    m.shell()
    m.box((-0.05, 0.0, 0.6), (0.05, 0.1, 1.5), "wood")
    m.shell()
    shapes.lathe(m, [(0.0, 0.0), (0.11, 0.04), (0.13, 0.15), (0.12, 0.26), (0.0, 0.32)], 10, "sign", at=(0.0, -0.06, 1.2))

    for k in range(5):
        m.shell()
        shapes.lathe(m, [(0.035, 0.0), (0.035, 0.12 + 0.04 * (k % 3)), (0.0, 0.14 + 0.04 * (k % 3))], 6, "wax",
                     at=(-0.35 + 0.17 * k, -0.18, 0.6))
        m.wick((-0.35 + 0.17 * k, -0.18, 0.6 + 0.14 + 0.04 * (k % 3)))

    m.shell()
    m.box((0.12, 0.05, 0.6), (0.42, 0.17, 0.68), "brass")
    m.shell()
    shapes.panel(m, (-0.5, 0.3, 0.7), (0.5, 0.36, 1.4), 0.05, "wood", "sign")


def crates_relics(m):
    """El Secreto's relic crates chained on a handcart, their seals stencilled
    (blank), one lid pushed up from inside."""
    top = cart_bed(m, sides=0.08)

    for k, (y, h) in enumerate(((-0.45, 0.5), (0.35, 0.45))):
        m.shell()
        shapes.panel(m, (-0.35, y - 0.3, top), (0.35, y + 0.3, top + h), 0.08, "wood", "sign")

    # The lid pushed up off the second crate.
    m.shell()
    m.face([(-0.37, 0.03, top + 0.47), (0.37, 0.03, top + 0.55), (0.37, 0.67, top + 0.55), (-0.37, 0.67, top + 0.47)],
           "wood")
    m.face([(-0.37, 0.03, top + 0.51), (-0.37, 0.67, top + 0.51), (0.37, 0.67, top + 0.59), (0.37, 0.03, top + 0.59)],
           "wood")
    m.face([(-0.37, 0.03, top + 0.47), (-0.37, 0.03, top + 0.51), (0.37, 0.03, top + 0.59), (0.37, 0.03, top + 0.55)],
           "wood")
    m.face([(-0.37, 0.67, top + 0.47), (0.37, 0.67, top + 0.55), (0.37, 0.67, top + 0.59), (-0.37, 0.67, top + 0.51)],
           "wood")
    m.face([(-0.37, 0.03, top + 0.47), (-0.37, 0.67, top + 0.47), (-0.37, 0.67, top + 0.51), (-0.37, 0.03, top + 0.51)],
           "wood")
    m.face([(0.37, 0.03, top + 0.55), (0.37, 0.03, top + 0.59), (0.37, 0.67, top + 0.59), (0.37, 0.67, top + 0.55)],
           "wood")

    for y in (-0.45, -0.15):
        m.shell()
        shapes.sag(m, (-0.4, y, top + 0.52), (0.4, y, top + 0.52), 0.02, 6, -0.02, 6, "iron")


PIECES = [cart_hand, cart_flower, cart_tamale, cart_ice, cart_firewood, kiosk_news, kiosk_lottery, kiosk_sweets,
          shoeshine_stand, booth_photographer, stand_curiosities, wagon_monster, shrine_luchador, crates_relics]

SETTS = (0.24, 0.23, 0.26)
GROUND = (-20.0, -20.0, 20.0, 20.0, -0.002, SETTS)
JOINTS = {
    "04_carts": {"eye": (3.5, -4.0, 2.0), "target": (2.0, 0.0, 0.5),
                 "show": [("cart_hand", (0, 0, 0), 0), ("cart_flower", (1.6, 0, 0), 0), ("cart_ice", (3.2, 0, 0), 0),
                          ("cart_firewood", (4.8, 0, 0), 0)], "planes": [GROUND]},
    "05_kiosks": {"eye": (3.0, -5.0, 2.0), "target": (2.0, 0.0, 1.2),
                  "show": [("kiosk_news", (0, 0, 0), 0), ("kiosk_lottery", (2.4, 0, 0), 0), ("kiosk_sweets", (4.6, 0, 0), 0)],
                  "planes": [GROUND]},
    "05b_pulp": {"eye": (3.0, -5.5, 2.4), "target": (2.0, 0.0, 1.0),
                 "show": [("stand_curiosities", (0, 0, 0), 0), ("wagon_monster", (3.0, 0.6, 0), 0),
                          ("shrine_luchador", (5.6, 0, 0), 0)], "planes": [GROUND]},
    "05c_photographer": {"eye": (2.5, -3.5, 1.8), "target": (0.4, 0.0, 1.2), "show": [("booth_photographer", (0, 0, 0), 0)],
                         "planes": [GROUND]},
}

WEATHER = {"coarse": {f.__name__: 2.0 for f in PIECES}, "blendable": ["wood", "canvas", "iron", "brass"],
           "foot": ["wood"]}


def build():
    common.reset()

    for f in PIECES:
        _object(f.__name__, f)


def main():
    build()
    common.export_piece(NAME, ATLAS, SLOTS, weather=WEATHER, out=common.ROOT / "assets" / "eclipse" / "kit",
                        sets_each=True)


if __name__ == "__main__":
    main()
