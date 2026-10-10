"""The furniture kit (docs/superpowers/refs/mexico_city/cards/street_life.md,
the Zócalo's family 1b): the street's bollards and guard stones, the Light
Company's poles, wires, lamps and wards, signs, posters and boards (every
face for words a blank canvas for the user), and the seeped future crashed
into it. Each piece its own object at the origin; one atlas, exported to
assets/eclipse/kit/.

    Blender -b --factory-startup --python tools/eclipse/furniture_kit.py

Blender axes: a post's foot at the origin on the ground (z 0), Z up, its
street side -Y. A wall piece's back at y 0, its face looking -Y.
"""

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import common  # noqa: E402
import shapes  # noqa: E402

NAME = "furniture_kit"
# Poles 8 m high and a 12 m2 hoarding outrun a 1024 atlas (32 px/m).
ATLAS = 1536
SLOTS = ["iron", "steel", "brass", "chiluca", "obsidian", "glass", "sign", "talavera", "wood", "seeped"]

# The Company's overhead (m): the trolley wire over the rail top, the span
# wires, the lamps, the poles.
TROLLEY = 5.5
SPAN = 6.0
LAMP = 6.5
POLE = 8.0
# A wire's or chain's radius: 3 cm across, never thinner (sliver gate).
WIRE = 0.015
CHAIN = 0.02


def _object(name, build):
    m = common.Mesh(name, outward=True)
    build(m)
    return m.make()


# Bollards

def bollard_guardstone(m):
    shapes.lathe(m, [(0.2, -0.3), (0.22, 0.0), (0.21, 0.45), (0.17, 0.62), (0.09, 0.7), (0.0, 0.72)], 10, "chiluca")


def bollard_cannon(m):
    """An old cannon barrel set muzzle-down: its breech and knob up."""
    shapes.lathe(m, [(0.14, -0.3), (0.15, 0.0), (0.14, 0.5), (0.165, 0.55), (0.165, 0.6), (0.12, 0.75), (0.08, 0.8),
                     (0.06, 0.84), (0.07, 0.88), (0.0, 0.92)], 10, "iron")


def bollard_company(m):
    """The Company's cast-iron bollard, a fret collar at its shoulder."""
    shapes.lathe(m, [(0.14, -0.2), (0.15, 0.0), (0.15, 0.08), (0.12, 0.12), (0.11, 0.6), (0.145, 0.62), (0.145, 0.68),
                     (0.11, 0.7), (0.09, 0.85), (0.0, 0.9)], 8, "iron")


def bollard_chain_post(m):
    shapes.lathe(m, [(0.07, -0.2), (0.07, 0.5), (0.09, 0.52), (0.09, 0.58), (0.0, 0.6)], 8, "iron")

    for side in (-1, 1):
        m.shell()
        m.box((min(side * 0.06, side * 0.11), -0.02, 0.42), (max(side * 0.06, side * 0.11), 0.02, 0.48), "iron")


def chain_span(m):
    """The chain between two posts 1.5 m apart (stretched by the dresser)."""
    shapes.sag(m, (0.11, 0.0, 0.45), (1.39, 0.0, 0.45), CHAIN, 6, 0.12, 10, "iron")


def bollard_seeped(m):
    """A 1980s concrete traffic bollard, its phosphor band, among the guard stones."""
    shapes.lathe(m, [(0.13, -0.3), (0.13, 0.0), (0.125, 0.55)], 10, "chiluca")
    m.shell()
    shapes.lathe(m, [(0.125, 0.55), (0.125, 0.65)], 10, "seeped")
    m.shell()
    shapes.lathe(m, [(0.125, 0.65), (0.12, 0.75), (0.1, 0.8), (0.0, 0.82)], 10, "chiluca")


# The Company's poles

def _pole(m):
    shapes.lathe(m, [(0.16, -0.5), (0.16, 0.0), (0.15, 0.45), (0.12, 0.5), (0.1, 3.0), (0.08, POLE - 0.2),
                     (0.1, POLE - 0.15), (0.1, POLE - 0.08), (0.0, POLE)], 8, "iron")
    # The fret band at its foot, a collar round it.
    m.shell()
    shapes.lathe(m, [(0.2, 0.0), (0.2, 0.32), (0.17, 0.38)], 8, "iron")
    # The span wire's bracket and its insulator, out over the street (-Y).
    m.shell()
    m.bar((0.0, 0.0, SPAN), (0.0, -0.32, SPAN), 0.06, 0.06, "iron", caps=(True, True))
    m.shell()
    shapes.lathe(m, [(0.04, -0.06), (0.05, 0.0), (0.04, 0.06)], 6, "glass", at=(0.0, -0.34, SPAN))


def tram_pole(m):
    _pole(m)


def _lamp_arm(m):
    m.shell()
    m.bar((0.0, -0.05, LAMP - 0.4), (0.0, -1.05, LAMP + 0.05), 0.07, 0.07, "iron", caps=(True, True))
    # The lamp's cap, iron, over its globe.
    m.shell()
    shapes.lathe(m, [(0.06, 0.12), (0.22, 0.2), (0.12, 0.3), (0.0, 0.34)], 8, "iron", at=(0.0, -1.15, LAMP))


def tram_pole_lamp(m):
    _pole(m)
    _lamp_arm(m)
    m.shell()
    shapes.lathe(m, [(0.0, -0.22), (0.12, -0.18), (0.19, -0.04), (0.18, 0.08), (0.06, 0.12)], 8, "glass",
                 at=(0.0, -1.15, LAMP))


def lamp_dead(m):
    """A pole lamp gone dark: its globe cracked to a jagged stub."""
    _pole(m)
    _lamp_arm(m)
    m.shell()
    shapes.lathe(m, [(0.08, 0.02), (0.17, -0.02), (0.15, 0.06), (0.06, 0.12)], 7, "glass", twist=0.4,
                 at=(0.0, -1.15, LAMP))


def ward_cage_lamp(m):
    """A Company lamp in a square brass cage, obsidian lenses at its four
    sides: blunt, the ward made hardware."""
    tram_pole_lamp(m)
    cx, cy, cz = 0.0, -1.15, LAMP - 0.05
    r = 0.27
    corners = [(cx + r, cy + r), (cx - r, cy + r), (cx - r, cy - r), (cx + r, cy - r)]

    for x, y in corners:
        m.shell()
        m.bar((x, y, cz - 0.25), (x, y, cz + 0.18), 0.035, 0.035, "brass", caps=(True, True))

    for z in (cz - 0.25, cz + 0.18):
        for k in range(4):
            (ax, ay), (bx, by) = corners[k], corners[(k + 1) % 4]
            m.shell()
            m.bar((ax, ay, z), (bx, by, z), 0.03, 0.03, "brass", caps=(True, True))

    # The lenses: obsidian slabs set in the cage's sides.
    for x, y, along_x in [(cx + r + 0.03, cy, False), (cx, cy + r + 0.03, True), (cx - r - 0.03, cy, False),
                          (cx, cy - r - 0.03, True)]:
        dx, dy = (0.07, 0.02) if along_x else (0.02, 0.07)
        m.shell()
        m.box((x - dx, y - dy, cz - 0.07), (x + dx, y + dy, cz + 0.07), "obsidian")


# Wires

def span_wire(m):
    """Across the street from pole to pole (10.8 m, stretched to fit), a
    hanger at its middle down to the trolley wire."""
    shapes.sag(m, (0.0, 0.0, SPAN), (10.8, 0.0, SPAN), WIRE, 6, 0.3, 12, "steel")
    m.shell()
    m.bar((5.4, 0.0, SPAN - 0.3 + 0.01), (5.4, 0.0, TROLLEY + 0.02), 0.03, 0.03, "steel", caps=(True, True))


def trolley_wire(m):
    shapes.sag(m, (0.0, 0.0, TROLLEY), (30.0, 0.0, TROLLEY), WIRE, 6, 0.15, 10, "steel")


# Wards, signs and the seeped future

def ward_plate(m):
    shapes.panel(m, (-0.15, -0.03, -0.2), (0.15, 0.0, 0.2), 0.03, "brass", "sign")


def sigil_disc(m):
    shapes.disc(m, (0.0, 0.0, 0.0), 0.2, 0.04, 16, 0.04, "iron", "sign")


def tram_stop(m):
    shapes.lathe(m, [(0.05, -0.3), (0.05, 2.6), (0.0, 2.65)], 8, "iron")
    m.shell()
    shapes.panel(m, (-0.3, -0.08, 2.0), (0.3, -0.05, 2.5), 0.04, "iron", "sign")
    # A little shelter: two posts, a bench, a glazed roof on its frame.
    for x in (-1.2, 1.2):
        m.shell()
        m.box((x - 0.04, 0.6, 0.0), (x + 0.04, 0.68, 2.4), "iron")

    m.shell()
    m.box((-1.15, 0.3, 0.42), (1.15, 0.68, 0.48), "wood")
    m.shell()
    m.box((-1.3, 0.2, 2.4), (1.3, 0.9, 2.45), "iron")
    m.shell()
    m.box((-1.25, 0.25, 2.45), (1.25, 0.85, 2.49), "glass")


def traffic_light_dead(m):
    """A 1980s traffic light hung from a span wire, never lit: its hanging
    point at the origin, the housing below it."""
    m.bar((0.0, 0.0, 0.0), (0.0, 0.0, -0.3), 0.04, 0.04, "steel", caps=(True, True))
    m.shell()
    m.box((-0.15, -0.12, -1.2), (0.15, 0.12, -0.3), "seeped")

    for k, z in enumerate((-0.48, -0.75, -1.02)):
        m.shell()
        shapes.disc(m, (0.0, -0.12, z), 0.1, 0.03, 10, 0.02, "steel", "glass")
        m.shell()
        m.box((-0.12, -0.27, z + 0.08), (0.12, -0.12, z + 0.12), "seeped")


def payphone_seeped(m):
    """A 1980s payphone fused to a pole, wired to a brass Company bell box:
    its back at y 0 against the pole, 1.1 m up."""
    m.box((-0.13, -0.16, 1.1), (0.13, 0.0, 1.62), "seeped")
    m.shell()
    m.box((-0.06, -0.24, 1.25), (0.06, -0.16, 1.5), "steel")
    m.shell()
    m.box((-0.1, -0.12, 1.82), (0.1, 0.0, 2.0), "brass")
    m.shell()
    shapes.sag(m, (0.08, -0.06, 1.62), (0.06, -0.06, 1.82), 0.015, 6, -0.04, 4, "steel")


def parking_meter(m):
    shapes.lathe(m, [(0.04, -0.3), (0.04, 1.1), (0.05, 1.12), (0.0, 1.14)], 8, "steel")
    m.shell()
    m.box((-0.11, -0.09, 1.14), (0.11, 0.09, 1.5), "seeped")
    m.shell()
    shapes.disc(m, (0.0, -0.09, 1.35), 0.07, 0.02, 10, 0.015, "steel", "glass")


def sign_bus_stop(m):
    shapes.lathe(m, [(0.04, -0.3), (0.04, 2.4), (0.0, 2.45)], 8, "steel")
    m.shell()
    shapes.disc(m, (0.0, -0.04, 2.2), 0.28, 0.03, 16, 0.05, "seeped", "sign")


def plaque_talavera(m):
    shapes.panel(m, (-0.3, -0.04, -0.2), (0.3, 0.0, 0.2), 0.07, "talavera", "sign")


def plate_street(m):
    shapes.panel(m, (-0.25, -0.03, -0.075), (0.25, 0.0, 0.075), 0.02, "iron", "sign")


def poster_column(m):
    """A round advertising column papered in blank sheets under an iron dome."""
    shapes.lathe(m, [(0.62, -0.1), (0.62, 0.25), (0.56, 0.3)], 16, "chiluca")
    m.shell()
    shapes.lathe(m, [(0.55, 0.3), (0.55, 2.8)], 16, "sign")
    m.shell()
    shapes.lathe(m, [(0.62, 2.8), (0.62, 2.9), (0.45, 3.15), (0.12, 3.3), (0.06, 3.5), (0.0, 3.55)], 16, "iron")


def poster_cluster(m):
    """Posters pasted over posters on a board 4 cm deep: its face a patchwork
    of blank sheets (the user's) and the bare board between them; every side
    split on the same grid, so the board stays one closed solid."""
    y0, y1 = -0.04, 0.0
    xs = [0.0, 0.15, 0.85, 1.0, 1.6, 1.75, 2.25, 2.4]
    zs = [0.0, 0.1, 0.55, 0.7, 1.45, 1.6]
    paper = {(1, 1), (1, 2), (1, 3), (2, 3), (3, 1), (3, 2), (3, 3), (4, 2), (5, 1), (5, 3), (5, 2), (4, 3)}

    for i in range(len(xs) - 1):
        for j in range(len(zs) - 1):
            a, b, c, d = xs[i], xs[i + 1], zs[j], zs[j + 1]
            m.face([(a, y0, c), (b, y0, c), (b, y0, d), (a, y0, d)], "sign" if (i, j) in paper else "wood")
            m.face([(a, y1, c), (a, y1, d), (b, y1, d), (b, y1, c)], "wood")

    for a, b in zip(xs, xs[1:]):
        for z in (zs[0], zs[-1]):
            m.face([(a, y0, z), (b, y0, z), (b, y1, z), (a, y1, z)], "wood")

    for c, d in zip(zs, zs[1:]):
        for x in (xs[0], xs[-1]):
            m.face([(x, y0, c), (x, y1, c), (x, y1, d), (x, y0, d)], "wood")


def notice_board(m):
    """El Secreto's registry notice board on two posts under a little roof."""
    for x in (-0.65, 0.65):
        m.shell()
        m.box((x - 0.05, -0.05, -0.3), (x + 0.05, 0.05, 2.3), "wood")

    m.shell()
    shapes.panel(m, (-0.6, -0.04, 0.9), (0.6, 0.04, 1.9), 0.06, "wood", "sign")
    m.shell()
    m.face([(-0.8, -0.3, 2.2), (0.8, -0.3, 2.2), (0.8, 0.0, 2.38), (-0.8, 0.0, 2.38)], "wood")
    m.face([(-0.8, 0.3, 2.2), (-0.8, 0.0, 2.38), (0.8, 0.0, 2.38), (0.8, 0.3, 2.2)], "wood")
    m.face([(-0.8, -0.3, 2.16), (-0.8, 0.3, 2.16), (0.8, 0.3, 2.16), (0.8, -0.3, 2.16)], "wood")
    m.face([(-0.8, -0.3, 2.16), (-0.8, -0.3, 2.2), (-0.8, 0.0, 2.38), (-0.8, 0.3, 2.2), (-0.8, 0.3, 2.16)], "wood")
    m.face([(0.8, -0.3, 2.16), (0.8, 0.3, 2.16), (0.8, 0.3, 2.2), (0.8, 0.0, 2.38), (0.8, -0.3, 2.2)], "wood")
    m.face([(-0.8, -0.3, 2.16), (0.8, -0.3, 2.16), (0.8, -0.3, 2.2), (-0.8, -0.3, 2.2)], "wood")
    m.face([(-0.8, 0.3, 2.16), (-0.8, 0.3, 2.2), (0.8, 0.3, 2.2), (0.8, 0.3, 2.16)], "wood")


def ward_hoarding(m):
    """A painted sigil board closing a dark street's end, 4 x 3 m on timber
    legs, braced behind (the sigil is the user's)."""
    shapes.panel(m, (-2.0, -0.06, 0.5), (2.0, 0.0, 3.5), 0.12, "wood", "sign")

    for x in (-1.7, 1.7):
        m.shell()
        m.box((x - 0.08, 0.0, -0.3), (x + 0.08, 0.16, 3.4), "wood")
        m.shell()
        m.bar((x, 0.16, 2.6), (x, 1.6, -0.2), 0.08, 0.08, "wood", caps=(True, True))


PIECES = [bollard_guardstone, bollard_cannon, bollard_company, bollard_chain_post, chain_span, bollard_seeped,
          tram_pole, tram_pole_lamp, lamp_dead, ward_cage_lamp, span_wire, trolley_wire, ward_plate, sigil_disc,
          tram_stop, traffic_light_dead, payphone_seeped, parking_meter, sign_bus_stop, plaque_talavera, plate_street,
          poster_column, poster_cluster, notice_board, ward_hoarding]


# The joints' close-ups, staged as the dresser lays them.
SETTS = (0.24, 0.23, 0.26)
GROUND = (-20.0, -20.0, 20.0, 20.0, -0.002, SETTS)
JOINTS = {
    "01_pole_foot": {"eye": (1.2, -1.4, 1.0), "target": (0.0, 0.0, 0.4), "show": [("tram_pole", (0, 0, 0), 0)],
                     "planes": [GROUND]},
    "02_span_bracket": {"eye": (1.5, -2.5, 6.2), "target": (0.0, -0.3, 6.0),
                        "show": [("tram_pole", (0, 0, 0), 0), ("span_wire", (0, -0.34, 0), -90),
                                 ("trolley_wire", (-15.0, -5.74, 0), 0)], "planes": [GROUND]},
    "03_ward_cage": {"eye": (1.4, -2.6, 6.4), "target": (0.0, -1.15, 6.4), "show": [("ward_cage_lamp", (0, 0, 0), 0)],
                     "planes": [GROUND]},
    "03b_wards_on_pole": {"eye": (0.8, -1.2, 2.2), "target": (0.0, 0.0, 2.0),
                          "show": [("tram_pole", (0, 0, 0), 0), ("sigil_disc", (0, -0.14, 2.3), 0),
                                   ("ward_plate", (0, -0.14, 1.7), 0), ("payphone_seeped", (0, -0.12, 0), 0)],
                          "planes": [GROUND]},
    "06_poster_cluster": {"eye": (1.2, -2.5, 1.2), "target": (1.2, 0.0, 0.8), "show": [("poster_cluster", (0, 0, 0), 0)],
                          "planes": [GROUND]},
    "07_chain_posts": {"eye": (0.75, -1.6, 0.9), "target": (0.75, 0.0, 0.4),
                       "show": [("bollard_chain_post", (0, 0, 0), 0), ("chain_span", (0, 0, 0), 0),
                                ("bollard_chain_post", (1.5, 0, 0), 0)], "planes": [GROUND]},
    "08_bollards": {"eye": (2.0, -2.4, 1.2), "target": (1.2, 0.0, 0.4),
                    "show": [("bollard_guardstone", (0, 0, 0), 0), ("bollard_cannon", (0.8, 0, 0), 0),
                             ("bollard_company", (1.6, 0, 0), 0), ("bollard_seeped", (2.4, 0, 0), 0)],
                    "planes": [GROUND]},
}

WEATHER = {"coarse": {f.__name__: 2.0 for f in PIECES}, "blendable": ["iron", "chiluca", "wood", "brass", "seeped"],
           "foot": ["chiluca", "iron", "wood"]}


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
