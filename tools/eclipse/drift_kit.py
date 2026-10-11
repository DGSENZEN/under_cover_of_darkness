"""The drift kit (the effects plan, Task 2): what the wind carries and the
ground keeps: two cempasúchil petals, curled, and two fallen leaves (an
ash's, a laurel's, dry), each a thin closed solid at its middle, drawn by the
petals' and leaves' GPU particles (scripts/Level/Vfx.gd).

    Blender -b --factory-startup --python tools/eclipse/drift_kit.py

Blender axes: each piece's middle at the origin, its length along X, its
face up (+Z).
"""

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import common  # noqa: E402
import shapes  # noqa: E402

NAME = "drift_kit"
ATLAS = 512
# (The leaves are the dry season's: old leaves shed ochre and russet.)
SLOTS = ["marigold", "leaf_dry", "leaf_dry_dark"]
# Thin as a petal can be and still pass the 1 cm sliver rule.
THICK = 0.014


def _blade(m, length, widths, curl, slot, twist=0.0):
    """A thin blade along X: diamond sections `widths` wide, its tips no
    narrower than 2 cm, curled up `curl` (m) at its ends."""
    n = len(widths)
    sections = []

    for k, w in enumerate(widths):
        t = k / (n - 1)
        x = (t - 0.5) * length
        z = curl * (2 * t - 1) ** 2 + twist * (t - 0.5)
        half = max(w, 0.02) / 2
        sections.append((x, [(-half, z), (0.0, z + THICK / 2), (half, z), (0.0, z - THICK / 2)]))

    m.shell()
    shapes.loft_x(m, sections, slot, caps=True)


def petal_a(m):
    _blade(m, 0.1, [0.02, 0.045, 0.055, 0.045, 0.02], 0.012, "marigold")


def petal_b(m):
    _blade(m, 0.08, [0.02, 0.05, 0.06, 0.04, 0.02], 0.02, "marigold", twist=0.01)


def leaf_ash(m):
    _blade(m, 0.13, [0.02, 0.04, 0.05, 0.04, 0.02], 0.01, "leaf_dry")


def leaf_laurel(m):
    _blade(m, 0.15, [0.02, 0.05, 0.065, 0.05, 0.02], 0.016, "leaf_dry_dark", twist=-0.008)


PIECES = [petal_a, petal_b, leaf_ash, leaf_laurel]
JOINTS = {}
WEATHER = {"coarse": {f.__name__: 1.0 for f in PIECES}, "blendable": [], "foot": []}


def build():
    common.reset()

    for f in PIECES:
        m = common.Mesh(f.__name__, outward=True)
        f(m)
        m.make()


def main():
    build()
    common.export_piece(NAME, ATLAS, SLOTS, weather=WEATHER, out=common.ROOT / "assets" / "eclipse" / "kit",
                        sets_each=True)


if __name__ == "__main__":
    main()
