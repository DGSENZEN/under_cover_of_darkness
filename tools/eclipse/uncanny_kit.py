"""The uncanny kit (docs/superpowers/refs/mexico_city/cards/street_life.md,
the Zócalo's family 1b, in a Hellboy and Deadlock register): the god that
will not stay buried breaking up through the setts, El Secreto's barriers,
sealed hatches and cage traps, the Line of the Dead and the testimony
booth, claw-scored stone under dead lamps, marigolds and candles for the
dead, the offerings at the Bound God's foot. Each piece its own object at
the origin; one atlas, exported to assets/eclipse/kit/. Every face for words
or pictures is a blank canvas (`sign`) for the user.

    Blender -b --factory-startup --python tools/eclipse/uncanny_kit.py

Blender axes: a piece's middle on the ground at the origin (the setts at
z 0), Z up, its front -Y.
"""

import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import common  # noqa: E402
import shapes  # noqa: E402
from street_dims import HATCH, HATCH_FRAME, SKIRT  # noqa: E402

NAME = "uncanny_kit"
ATLAS = 1024
SLOTS = ["basalt", "chiluca", "iron", "brass", "wood", "marigold", "wax", "sign", "glass", "obsidian", "flesh", "steel",
         "canvas", "seeped"]
PROUD = 0.04


def _object(name, build):
    m = common.Mesh(name, outward=True)
    build(m)
    return m.make()


def _hash(*keys):
    return (math.sin(sum(k * (12.9898 + 7.0 * i) for i, k in enumerate(keys))) * 43758.5453) % 1.0


# The god's traces

def idol_surfacing(m):
    """A god's head and hand breaking up through the sinking setts: blunt
    stone, blank eyes, the setts heaved and broken round it (an invented
    god, not a copied one). The head's parts are laid in its own tilted frame."""
    from mathutils import Euler, Vector

    tilt = (math.radians(-12), math.radians(8), 0.0)
    turn = Euler(tilt, "XYZ").to_matrix()
    centre = Vector((0.0, 0.1, 0.25))
    at = lambda x, y, z: tuple(centre + turn @ Vector((x, y, z)))
    shapes.obox(m, tuple(centre), (0.9, 0.8, 1.0), tilt, "basalt")

    for offset, size, slot in (((0.0, -0.45, 0.28), (1.0, 0.2, 0.16), "basalt"),
                               ((-0.2, -0.43, 0.12), (0.16, 0.1, 0.1), "obsidian"),
                               ((0.2, -0.43, 0.12), (0.16, 0.1, 0.1), "obsidian"),
                               ((0.0, -0.38, -0.45), (0.7, 0.3, 0.2), "basalt")):
        m.shell()
        shapes.obox(m, at(*offset), size, tilt, slot)

    # The hand, its fingers clawing up out of the palm (laid in the palm's frame).
    palm_tilt = (0.0, math.radians(-10), math.radians(20))
    palm_turn = Euler(palm_tilt, "XYZ").to_matrix()
    palm = Vector((0.95, -0.2, 0.05))
    m.shell()
    shapes.obox(m, tuple(palm), (0.5, 0.4, 0.22), palm_tilt, "basalt")

    for k in range(4):
        m.shell()
        shapes.obox(m, tuple(palm + palm_turn @ Vector((0.15, -0.12 + 0.08 * k, 0.25))), (0.06, 0.06, 0.4), palm_tilt,
                    "basalt")

    # The setts it broke, heaved askew round it.
    for k in range(7):
        a = 2 * math.pi * k / 7 + 0.3
        r = 1.0 + 0.25 * _hash(k, 1)
        m.shell()
        shapes.obox(m, (r * math.cos(a), r * math.sin(a), 0.0), (0.24, 0.18, 0.16),
                    (math.radians(25 * (_hash(k, 2) - 0.5)), math.radians(35 * (_hash(k, 3) - 0.5)), a), "basalt")


def secreto_barrier(m):
    """El Secreto's barrier: two sawhorses, a chain between, its sealed tag."""
    for x in (-1.0, 1.0):
        m.shell()
        m.box((x - 0.5, -0.05, 0.75), (x + 0.5, 0.05, 0.85), "wood")

        for dx in (-0.4, 0.4):
            for dy in (-1, 1):
                m.shell()
                m.bar((x + dx, 0.0, 0.76), (x + dx * 1.15, dy * 0.3, 0.05), 0.05, 0.05, "wood", caps=(True, True))
                m.shell()
                m.box((x + dx * 1.15 - 0.04, dy * 0.3 - 0.04, 0.0), (x + dx * 1.15 + 0.04, dy * 0.3 + 0.04, 0.04), "iron")

    m.shell()
    shapes.sag(m, (-0.5, 0.0, 0.92), (0.5, 0.0, 0.92), 0.02, 6, 0.08, 8, "iron")
    m.shell()
    shapes.panel(m, (-0.12, -0.03 - PROUD, 0.58), (0.12, -0.03, 0.8), 0.03, "brass", "sign")


def _scored_profile(top):
    """The slab's section with four claw scores across it (V-grooves 4 cm
    wide, 2.5 cm deep); `top` False is the section at a score's tapered end."""
    out = [(-0.75, 0.0)]

    for c in (-0.3, -0.1, 0.1, 0.3):
        out += [(c - 0.02, 0.0), (c, -0.025 if top else -0.002), (c + 0.02, 0.0)]

    out.append((0.75, 0.0))
    return out


def claw_scored_slab(m):
    """Setts scored by claws round a dead lamp's foot (flush, an inlay): four
    gouges across a 1.5 m slab, tapering out at their ends."""
    full, faded = _scored_profile(True), _scored_profile(False)
    sections = [(-0.75, faded), (-0.45, full), (0.45, full), (0.75, faded)]
    shapes.loft_x(m, [(x, p + [(y, SKIRT) for y, _ in reversed(p)]) for x, p in sections], "basalt", caps=False)
    half = len(faded)

    for x in (-0.75, 0.75):
        for i in range(half - 1):
            a, b = faded[i], faded[i + 1]
            m.face([(x, a[0], a[1]), (x, b[0], b[1]), (x, b[0], SKIRT), (x, a[0], SKIRT)], "basalt")


def _mound(m, x, y, r, h, slot="marigold", sides=10):
    m.shell()
    shapes.lathe(m, [(r, 0.0), (r * 0.85, h * 0.6), (r * 0.45, h * 0.95), (0.0, h)], sides, slot, at=(x, y, 0.0))


def petals_marigold(m):
    """Marigold petals laid to guide the dead past a door: a heap and its strewing."""
    _mound(m, 0.0, 0.0, 0.5, 0.07)

    for k in range(5):
        a = 2 * math.pi * k / 5
        _mound(m, 0.85 * math.cos(a), 0.85 * math.sin(a), 0.16 + 0.06 * _hash(k, 4), 0.045, sides=7)


def _candle(m, x, y, z, h, w=0.05):
    m.shell()
    m.box((x - w / 2, y - w / 2, z), (x + w / 2, y + w / 2, z + h), "wax")


def candles_drift(m):
    """A drift of votive candles at a wall's foot (the wall at y 0.3): wax
    runs, marigolds, two photographs propped against the wall (blank)."""
    k = 0

    for row in range(3):
        for col in range(10):
            x = -0.9 + 0.2 * col + 0.07 * (row % 2)
            y = 0.18 - 0.17 * row
            if _hash(row, col) < 0.2:
                continue
            _candle(m, x, y, 0.0, 0.08 + 0.16 * _hash(row, col, 1))
            k += 1

    _mound(m, -1.2, 0.05, 0.22, 0.05, sides=7)
    _mound(m, 1.2, 0.1, 0.2, 0.05, sides=7)

    for x, a in ((-0.4, 12), (0.35, -9)):
        m.shell()
        shapes.obox(m, (x, 0.24, 0.13), (0.18, 0.04, 0.24), (math.radians(14), 0.0, math.radians(a)), "sign")


# The dead's booths

def booth_line_of_dead(m):
    """The Line of the Dead: a seeped 1980s payphone the Company boxed in
    carved wood and brass, a clerk's slot, a centavo box, its name board
    blank."""
    m.box((-0.55, -0.5, 0.0), (0.55, 0.55, 0.12), "chiluca")
    m.shell()
    m.box((-0.5, 0.4, 0.12), (0.5, 0.5, 2.3), "wood")

    for side in (-1, 1):
        m.shell()
        m.box((side * 0.5 - 0.05, -0.45, 0.12), (side * 0.5 + 0.05, 0.4, 2.3), "wood")

    m.shell()
    m.box((-0.6, -0.55, 2.3), (0.6, 0.6, 2.42), "brass")
    m.shell()
    shapes.lathe(m, [(0.45, 0.0), (0.3, 0.25), (0.06, 0.4), (0.0, 0.42)], 8, "brass", at=(0.0, 0.0, 2.42))
    # The seeped phone on the back wall, its handset, the bell box above.
    m.shell()
    m.box((-0.15, 0.24, 1.1), (0.15, 0.4, 1.65), "seeped")
    m.shell()
    m.box((-0.07, 0.16, 1.25), (0.07, 0.24, 1.5), "steel")
    m.shell()
    m.box((-0.12, 0.28, 1.85), (0.12, 0.4, 2.05), "brass")
    # The clerk's slot and the centavo box on the side wall.
    m.shell()
    m.box((0.33, -0.1, 1.0), (0.45, 0.2, 1.2), "brass")
    m.shell()
    shapes.panel(m, (-0.45, -0.55 - PROUD, 2.0), (0.45, -0.55, 2.28), 0.04, "brass", "sign")


def booth_testimony(m):
    """El Secreto's testimony booth: an iron confessional where the dead give
    evidence through a speaking grille, under its seal (blank)."""
    w, d, h = 1.3, 1.0, 2.4
    m.box((-w / 2, -d / 2, 0.0), (w / 2, d / 2, 0.15), "iron")
    m.shell()
    m.box((-w / 2, d / 2 - 0.1, 0.15), (w / 2, d / 2, h), "iron")

    for side in (-1, 1):
        m.shell()
        m.box((side * w / 2 - 0.1 if side > 0 else -w / 2, -d / 2, 0.15), (w / 2 if side > 0 else -w / 2 + 0.1, d / 2 - 0.1, h),
              "iron")

    # The front: solid below and above a grilled window, a dark hollow behind.
    m.shell()
    m.box((-w / 2 + 0.1, -d / 2, 0.15), (w / 2 - 0.1, -d / 2 + 0.1, 1.2), "iron")
    m.shell()
    m.box((-w / 2 + 0.1, -d / 2, 1.8), (w / 2 - 0.1, -d / 2 + 0.1, h), "iron")
    m.shell()
    m.box((-w / 2 + 0.1, -d / 2 + 0.3, 1.2), (w / 2 - 0.1, d / 2 - 0.1, 1.8), "obsidian")

    for k in range(7):
        x = -w / 2 + 0.1 + (w - 0.2) * (k + 0.5) / 7
        m.shell()
        m.box((x - 0.02, -d / 2 + 0.02, 1.2), (x + 0.02, -d / 2 + 0.08, 1.8), "iron")

    m.shell()
    m.box((-w / 2 - 0.08, -d / 2 - 0.08, h), (w / 2 + 0.08, d / 2 + 0.08, h + 0.15), "iron")
    m.shell()
    shapes.disc(m, (0.0, -d / 2, 2.1), 0.18, 0.05, 12, 0.04, "brass", "sign")


# El Secreto's containment

def hatch_sealed(m):
    """A Line 2 hatch over a shaft too near Mictlán: flush in its frame,
    chained across, padlocked, a sigil disc laid on it (its iron scored from
    below in the paint)."""
    h, plate = HATCH / 2, HATCH / 2 - HATCH_FRAME
    corners = lambda a, z: [(-a, -a, z), (a, -a, z), (a, a, z), (-a, a, z)]
    o, i = corners(h, 0.0), corners(plate, 0.0)

    for k in range(4):
        j = (k + 1) % 4
        m.face([o[k], o[j], i[j], i[k]], "basalt")

    m.face(i, "iron")
    bottom = corners(h, SKIRT)

    for k in range(4):
        j = (k + 1) % 4
        m.face([bottom[k], bottom[j], o[j], o[k]], "basalt")

    m.face(bottom, "basalt")

    for a, b in (((-0.5, -0.5, 0.02), (0.5, 0.5, 0.02)), ((-0.5, 0.5, 0.02), (0.5, -0.5, 0.02))):
        m.shell()
        m.tube(a, b, 0.02, 6, "iron", caps=(True, True))

    m.shell()
    m.box((-0.06, -0.04, 0.04), (0.06, 0.04, 0.18), "iron")
    m.shell()
    shapes.lathe(m, [(0.16, 0.0), (0.16, 0.04)], 12, "iron", at=(0.3, -0.05, 0.0))


def _cage(m, x, y, z, r=0.25, h=0.55):
    """A hanging birdcage of iron bars, its floor and dome."""
    for k in range(8):
        a = 2 * math.pi * k / 8
        m.shell()
        m.box((x + r * math.cos(a) - 0.015, y + r * math.sin(a) - 0.015, z), (x + r * math.cos(a) + 0.015,
                                                                          y + r * math.sin(a) + 0.015, z + h), "iron")

    m.shell()
    shapes.lathe(m, [(r + 0.04, 0.0), (r + 0.04, 0.04)], 8, "iron", at=(x, y, z - 0.04))
    m.shell()
    shapes.lathe(m, [(r + 0.04, 0.0), (r * 0.6, 0.15), (0.05, 0.25), (0.0, 0.27)], 8, "iron", at=(x, y, z + h))


def _cage_post(m):
    """The post the cage hangs from, its arm and the cage's wards."""
    m.box((-0.06, -0.06, 0.0), (0.06, 0.06, 2.6), "iron")
    m.shell()
    m.box((-0.02, -0.85, 2.42), (0.02, 0.0, 2.5), "iron")
    # The shackle the cage hangs by, chunkier than the arm (never within 3 cm of its faces).
    m.shell()
    m.box((-0.06, -0.84, 2.2), (0.06, -0.72, 2.42), "iron")

    for k in range(2):
        m.shell()
        shapes.panel(m, (-0.07, -0.06 - PROUD, 1.6 - 0.25 * k), (0.07, -0.06, 1.8 - 0.25 * k), 0.02, "brass", "sign")

    _cage(m, 0.0, -0.78, 1.38)


def cage_trap(m):
    _cage_post(m)


def cage_trap_chaneque(m):
    """A chaneque caught and dried in a cage trap: small, crouched, wrong."""
    _cage_post(m)
    m.shell()
    shapes.lathe(m, [(0.0, 0.0), (0.12, 0.06), (0.1, 0.22), (0.05, 0.27), (0.08, 0.32), (0.08, 0.4), (0.0, 0.44)], 6,
                 "flesh", at=(0.0, -0.78, 1.38))


def cage_trap_lechuza(m):
    """A lechuza, the owl-witch, in a cage trap: its feathers like knives."""
    _cage_post(m)
    m.shell()
    shapes.lathe(m, [(0.0, 0.0), (0.13, 0.08), (0.14, 0.25), (0.09, 0.38), (0.0, 0.45)], 8, "flesh", at=(0.0, -0.78, 1.38))

    for side in (-1, 1):
        m.shell()
        shapes.obox(m, (side * 0.05, -0.9, 1.72), (0.05, 0.04, 0.05), (0.0, 0.0, 0.0), "obsidian")

    for k in range(5):
        a = math.radians(-60 + 30 * k)
        m.shell()
        shapes.obox(m, (0.16 * math.sin(a), -0.78 + 0.16 * math.cos(a) * 0.3, 1.6), (0.04, 0.14, 0.04),
                    (math.radians(30), 0.0, a), "obsidian")


def offerings_heap(m):
    """The Bound God's foot: banks of marigolds, drifts of candles, copal
    smoking in brass burners, petitions pinned on boards (blank), kneeling
    cushions before it. It lies along the cage's open side, its back at y 0."""
    for x, r in ((-1.5, 0.55), (0.0, 0.7), (1.5, 0.55)):
        _mound(m, x, -0.5, r, 0.18)

    for row in range(4):
        for col in range(16):
            if _hash(row, col, 5) < 0.25:
                continue
            x = -1.9 + 0.25 * col + 0.1 * (row % 2)
            y = -1.2 - 0.18 * row
            _candle(m, x, y, 0.0, 0.08 + 0.2 * _hash(row, col, 6))

    for x in (-0.9, 0.9):
        m.shell()
        shapes.lathe(m, [(0.12, 0.0), (0.18, 0.12), (0.2, 0.2), (0.0, 0.21)], 8, "brass", at=(x, -0.3, 0.0))

    for x, a in ((-2.2, 8), (2.2, -8)):
        m.shell()
        shapes.obox(m, (x, -0.3, 0.45), (0.6, 0.05, 0.8), (math.radians(10), 0.0, math.radians(a)), "sign")
        m.shell()
        shapes.obox(m, (x, -0.1, 0.4), (0.06, 0.06, 0.8), (math.radians(-15), 0.0, 0.0), "wood")

    for x in (-1.2, -0.4, 0.4, 1.2):
        m.shell()
        shapes.bevelled_box(m, (x - 0.22, -2.3, 0.0), (x + 0.22, -1.95, 0.12), "canvas", 0.03)


PIECES = [idol_surfacing, secreto_barrier, claw_scored_slab, petals_marigold, candles_drift, booth_line_of_dead,
          booth_testimony, hatch_sealed, cage_trap, cage_trap_chaneque, cage_trap_lechuza, offerings_heap]

SETTS = (0.24, 0.23, 0.26)
GROUND = (-20.0, -20.0, 20.0, 20.0, -0.002, SETTS)
JOINTS = {
    "08_idol": {"eye": (2.2, -2.6, 1.6), "target": (0.3, 0.0, 0.3), "show": [("idol_surfacing", (0, 0, 0), 0),
                                                                              ("secreto_barrier", (0, -2.2, 0), 0)],
                "planes": [GROUND]},
    "09_dead_traces": {"eye": (1.5, -2.5, 1.2), "target": (0.0, 0.0, 0.1),
                       "show": [("petals_marigold", (-1.2, 0, 0), 0), ("candles_drift", (1.2, 0, 0), 0)],
                       "planes": [GROUND]},
    "11_hatch_sealed": {"eye": (1.0, -1.5, 1.3), "target": (0.0, 0.0, 0.0), "show": [("hatch_sealed", (0, 0, 0), 0)],
                        "planes": [(-20, -20, 20, -0.6, -0.002, SETTS), (-20, 0.6, 20, 20, -0.002, SETTS),
                                   (-20, -0.6, -0.6, 0.6, -0.002, SETTS), (0.6, -0.6, 20, 0.6, -0.002, SETTS)]},
    "12_booths": {"eye": (2.0, -4.0, 1.8), "target": (0.8, 0.0, 1.2),
                  "show": [("booth_line_of_dead", (0, 0, 0), 0), ("booth_testimony", (1.8, 0, 0), 0)], "planes": [GROUND]},
    "12b_cages": {"eye": (1.6, -3.0, 1.8), "target": (1.0, -0.8, 1.5),
                  "show": [("cage_trap", (0, 0, 0), 0), ("cage_trap_chaneque", (1.0, 0, 0), 0),
                           ("cage_trap_lechuza", (2.0, 0, 0), 0)], "planes": [GROUND]},
    "10_offerings": {"eye": (2.5, -5.0, 2.2), "target": (0.0, -1.0, 0.2), "show": [("offerings_heap", (0, 0, 0), 0)],
                     "planes": [GROUND]},
}

WEATHER = {"coarse": {f.__name__: 2.0 for f in PIECES}, "blendable": ["basalt", "iron", "wood", "brass"],
           "foot": ["basalt", "iron", "wood"]}


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
