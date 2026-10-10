"""The stone bridge (street_canal.md): a low segmental arch of chiluca
voussoirs over the Acequia Real, its spandrels rubble, its parapets capped,
its deck flush with the quays at both ends. One object, exported to
assets/eclipse/kit/.

    Blender -b --factory-startup --python tools/eclipse/bridge_stone.py
"""

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import common  # noqa: E402
import shapes  # noqa: E402
from bridges import HALF, QUAY_FOOT, SPAN, deck, soffit, stations  # noqa: E402
from street_dims import BRIDGE_WIDTH, CROWN, PARAPET  # noqa: E402

NAME = "bridge_stone"
ATLAS = 1024
SLOTS = ["chiluca", "rubble", "basalt"]

# The arch springs from the walls' faces below their coping, so the coping
# runs on into the bridge; its soffit's crown under the deck's. In the
# walls' thickness its underside rises to the quays' foot (bridges.QUAY_FOOT).
SPRING = -0.6
SOFFIT_CROWN = 0.25
# The voussoirs' depth on the faces, and at least this much spandrel over them.
RING = 0.45
OVER_RING = 0.1
# The parapet: thickness, its coping's overhang and depth.
WALL = 0.35
CAP = (0.05, 0.15)
NEWEL = (0.55, 1.2)              # square, height over the street


def _body_ring(x):
    """The bridge's section at x (y, z): its underside (the arch over the
    canal, the abutments' foot over the quays), the voussoirs' band up the
    faces, the spandrels to the deck."""
    half = BRIDGE_WIDTH / 2
    top = deck(x, CROWN)
    # Over the canal the arch; in the wall's thickness its springing; over the
    # quays clear of the walkway under the south one.
    bottom = soffit(x, SPRING, SOFFIT_CROWN) if abs(x) <= SPAN + 1e-9 else QUAY_FOOT
    # (Where the bridge thins to nothing at the quays, its two bands halve it.)
    band = max(min(bottom + RING, top - OVER_RING), (bottom + top) / 2)
    return [(-half, bottom), (half, bottom), (half, band), (half, top), (-half, top), (-half, band)]


def _parapet_ring(x, side):
    half = BRIDGE_WIDTH / 2
    d = deck(x, CROWN)
    inner, over, cap = half - WALL, CAP[0], CAP[1]
    ring = [(inner, d), (half, d), (half, d + PARAPET - cap), (half + over, d + PARAPET - cap),
            (half + over, d + PARAPET), (inner - over, d + PARAPET), (inner - over, d + PARAPET - cap),
            (inner, d + PARAPET - cap)]
    return [(side * y, z) for y, z in ring]


def build():
    common.reset()
    m = common.Mesh(NAME, outward=True)
    xs = stations()
    shapes.loft_x(m, [(x, _body_ring(x)) for x in xs], ["chiluca", "chiluca", "rubble", "basalt", "rubble", "chiluca"],
                  fan=True)
    parapet_slots = ["rubble", "rubble", "chiluca", "chiluca", "chiluca", "chiluca", "chiluca", "rubble"]

    for side in (-1, 1):
        m.shell()
        shapes.loft_x(m, [(x, _parapet_ring(x, side)) for x in xs], parapet_slots, cap_slot="chiluca")

        for end in (-1, 1):
            m.shell()
            w, h = NEWEL
            y0 = side * (BRIDGE_WIDTH / 2 + CAP[0] + 0.05)
            x0 = end * (HALF + 0.05)
            m.box((min(x0, x0 - end * w), min(y0, y0 - side * w), -0.3), (max(x0, x0 - end * w), max(y0, y0 - side * w), h),
                  "chiluca")

    return m.make()


# The joints: abutment to quay, deck end to setts.
SETTS = (0.24, 0.23, 0.26)
JOINTS = {
    "11_abutment_quay": {"eye": (-14.0, -6.0, 1.6), "target": (-9.0, 0.0, 0.0), "show": [(NAME, (0.0, 0.0, 0.0), 0)],
                         "planes": [(-20.0, -20.0, -6.2, 20.0, -0.002, SETTS)]},
    "12_deck_end": {"eye": (-13.0, 0.5, 1.7), "target": (-10.0, 0.0, 0.1), "show": [(NAME, (0.0, 0.0, 0.0), 0)],
                    "planes": [(-20.0, -20.0, -6.2, 20.0, -0.002, SETTS)]},
    "11b_arch": {"eye": (0.0, -9.0, -1.0), "target": (0.0, 0.0, 0.0), "show": [(NAME, (0.0, 0.0, 0.0), 0)],
                 "planes": [(-20.0, -20.0, -6.2, 20.0, -0.002, SETTS), (6.2, -20.0, 20.0, 20.0, -0.002, SETTS)]},
}

WEATHER = {"coarse": {NAME: 3.0}, "blendable": ["chiluca", "rubble", "basalt"], "foot": ["rubble"],
           "tide": {NAME: (-2.0, -1.55)}, "ground_holes": [(-6.0, -20.0, 6.0, 20.0)]}


def main():
    build()
    common.export_piece(NAME, ATLAS, SLOTS, weather=WEATHER, out=common.ROOT / "assets" / "eclipse" / "kit")


if __name__ == "__main__":
    main()
