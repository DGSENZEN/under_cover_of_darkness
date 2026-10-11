"""The Bound God, a placeholder (the user: "for the God's look, let's have a
basic placeholder"): the idol that would not stay buried, made the Zócalo's
Patron by El Secreto. A blocky seated basalt god, 6 m, its blank eyes
obsidian, chained at the wrists inside an iron cage open on its south side,
on a stepped chiluca plinth with a blank plaque (cards/street_life.md). One
object of shells, exported to assets/eclipse/kit/.

    Blender -b --factory-startup --python tools/eclipse/bound_god.py

Blender axes: the plinth's middle on the pavement at the origin, Z up, the
cage's open side (and the offerings) to -Y.
"""

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import common  # noqa: E402
import shapes  # noqa: E402

NAME = "bound_god"
# A landmark walked up to: 1024 left it at 27 px/m.
ATLAS = 1536
SLOTS = ["basalt", "iron", "brass", "chiluca", "sign", "obsidian"]

PLINTH = [(3.0, 0.0, 0.4), (2.6, 0.4, 0.8), (2.2, 0.8, 1.2)]     # half-width, from, to
TOP = 1.2
CAGE = 2.0                       # its half-width
CAGE_TOP = TOP + 7.0
BAR = 0.04                       # a bar's half-width
OPEN = 0.8                       # the open side's half-width (south)


# El Secreto's seals on the chains, their middles (filled by build()): where
# the chains spark on a deep exhale (scripts/Level/Occult.gd).
SEALS = []


def build():
    common.reset()
    SEALS.clear()
    m = common.Mesh(NAME, outward=True)

    # The plinth, stepped, its plaque on the south face of the bottom step.
    for k, (half, z0, z1) in enumerate(PLINTH):
        if k:
            m.shell()
        m.box((-half, -half, z0), (half, half, z1), "chiluca")

    m.shell()
    shapes.panel(m, (-0.9, -3.0 - 0.05, 0.06), (0.9, -3.0, 0.34), 0.04, "brass", "sign")

    # The god, seated: folded legs, torso, arms down to the lap, jaw, head,
    # brow, blank eyes.
    for lo, hi in (((-1.3, -1.0, TOP), (1.3, 1.0, TOP + 1.4)), ((-1.0, -0.7, TOP + 1.4), (1.0, 0.7, TOP + 3.6)),
                   ((-0.45, -0.4, TOP + 3.6), (0.45, 0.4, TOP + 3.8)), ((-0.85, -0.75, TOP + 3.8), (0.85, 0.55, TOP + 4.2)),
                   ((-0.8, -0.7, TOP + 4.2), (0.8, 0.7, TOP + 6.0))):
        m.shell()
        m.box(lo, hi, "basalt")

    m.shell()
    m.box((-0.9, -0.88, TOP + 5.1), (0.9, -0.62, TOP + 5.35), "basalt")

    for x in (-0.38, 0.38):
        m.shell()
        m.box((x - 0.2, -0.76, TOP + 4.75), (x + 0.2, -0.66, TOP + 5.05), "obsidian")

    for side in (-1, 1):
        m.shell()
        m.box((side * 1.0 - (0.0 if side > 0 else 0.45), -0.4, TOP + 1.2),
              (side * 1.0 + (0.45 if side > 0 else 0.0), 0.3, TOP + 3.5), "basalt")
        # The shackle at its wrist.
        m.shell()
        m.box((side * 1.225 - 0.3, -0.48, TOP + 1.35), (side * 1.225 + 0.3, 0.38, TOP + 1.65), "iron")

    # The cage: bars round three sides and the south side's edges, rings, a lid.
    def bar(x, y):
        m.shell()
        m.box((x - BAR, y - BAR, TOP), (x + BAR, y + BAR, CAGE_TOP), "iron")

    steps = [-CAGE + 0.5 * k for k in range(9)]

    for t in steps:
        bar(t, CAGE)
        bar(-CAGE, t) if abs(t) < CAGE - 1e-6 else None
        bar(CAGE, t) if abs(t) < CAGE - 1e-6 else None

        if abs(t) > OPEN:
            bar(t, -CAGE)

    # Two rings round three sides, each one U-shaped solid 9 cm out from the
    # bars' axes (well clear of their faces), open where the south side is.
    o, i, gap = CAGE + 0.09, CAGE - 0.09, 1.0
    ring = [(-gap, -o), (-o, -o), (-o, o), (o, o), (o, -o), (gap, -o),
            (gap, -i), (i, -i), (i, i), (-i, i), (-i, -i), (-gap, -i)]

    for z in (TOP + 2.4, TOP + 4.8):
        m.shell()
        m.prism(ring, z - 0.03, z + 0.03, "iron")

    m.shell()
    m.box((-CAGE - 0.1, -CAGE - 0.1, CAGE_TOP), (CAGE + 0.1, CAGE + 0.1, CAGE_TOP + 0.15), "iron")

    # The chains from the cage's back corners to its wrists, El Secreto's seals on them.
    for side in (-1, 1):
        a = (side * (CAGE - 0.15), CAGE - 0.15, CAGE_TOP - 0.4)
        b = (side * 1.55, 0.0, TOP + 1.5)
        m.shell()
        shapes.sag(m, a, b, 0.05, 6, 0.4, 10, "iron")

        for t in (0.35, 0.65):
            c = tuple(a[k] + (b[k] - a[k]) * t for k in range(3))
            SEALS.append((c[0], c[1], c[2] - 0.5 * t))
            m.shell()
            m.box((c[0] - 0.12, c[1] - 0.12, c[2] - 0.5 * t - 0.15), (c[0] + 0.12, c[1] + 0.12, c[2] - 0.5 * t + 0.15),
                  "brass")

    return m.make()


SETTS = (0.32, 0.30, 0.33)
JOINTS = {
    "10_bound_god": {"eye": (6.0, -10.0, 4.0), "target": (0.0, 0.0, 4.0), "show": [(NAME, (0, 0, 0), 0)],
                     "planes": [(-30, -30, 30, 30, -0.002, SETTS)]},
    "10b_chains_cage": {"eye": (2.0, -4.0, 6.5), "target": (0.0, 0.0, 5.0), "show": [(NAME, (0, 0, 0), 0)],
                        "planes": [(-30, -30, 30, 30, -0.002, SETTS)]},
}

WEATHER = {"coarse": {NAME: 3.0}, "blendable": ["basalt", "iron", "chiluca"], "foot": ["chiluca", "basalt"]}


def write_seals(path=None):
    """SEALS in Godot's axes (x, z, -y), over the god's spot, for the game."""
    import json
    path = path or common.SOURCE / (NAME + "_seals.json")
    path.write_text(json.dumps([[round(x, 4), round(z, 4), round(-y, 4)] for x, y, z in SEALS], indent=1))


def main():
    build()
    write_seals()
    common.export_piece(NAME, ATLAS, SLOTS, weather=WEATHER, out=common.ROOT / "assets" / "eclipse" / "kit")


if __name__ == "__main__":
    main()
