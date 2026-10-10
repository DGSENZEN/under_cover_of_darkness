"""The seeped steel bridge (street_canal.md): two riveted plate girders over
the Acequia Real on stepped deco piers of the old stone standing in the
canal, the Company's brass patch plates where the steel meets the stone,
their ends in the canal walls, a steel deck lying on the quays beyond,
railings. One object, exported to assets/eclipse/kit/.

    Blender -b --factory-startup --python tools/eclipse/bridge_steel.py
"""

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import common  # noqa: E402
import shapes  # noqa: E402
from bridges import HALF, SPAN, deck, stations  # noqa: E402
from street_dims import BRIDGE_WIDTH, PARAPET, WALL_THICK, WATER  # noqa: E402

NAME = "bridge_steel"
# Its surfaces outrun a 1024 atlas (24 px/m); 1536 keeps it near the lab's.
ATLAS = 1536
SLOTS = ["steel", "brass", "chiluca"]

CROWN = 0.3
PLATE = 0.05                     # the deck plate's thickness
# The girders: centred at y +-GIRDER_Y, an I 1 m deep.
GIRDER_Y = 1.7
GIRDER = (0.3, 0.04, 0.03, 1.0)  # flange width, flange thickness, web thickness, depth
# The deco piers in the canal against each wall: three tiers, each 0.15 in.
TIERS = [(0.8, 2.2, WATER, -1.6), (0.65, 2.05, -1.6, -1.2), (0.5, 1.9, -1.2, None)]
# The girders end inside the canal walls (short of their backs, which face
# the walkway); the patch plates where they sit on the piers.
GIRDER_END = SPAN + WALL_THICK - 0.1
PATCH_AT = SPAN - 0.35
PATCH = (0.6, 0.6, 0.04)
# The railing: posts every RAIL_EVERY, two rails.
# The railing stands outside the deck's edge, its posts bolted to its side
# (never over the plate, which tilts with the deck).
POST = 0.12                      # chunky, the rails well inside it
RAIL_Y = BRIDGE_WIDTH / 2 + POST / 2
RAIL = (0.05, 0.05)
RAIL_EVERY = 1.5


def _girder_ring(x, y0):
    w, t, web, depth = GIRDER
    top = deck(x, CROWN) - PLATE
    f, h = w / 2, web / 2
    ring = [(-f, 0), (f, 0), (f, -t), (h, -t), (h, -depth + t), (f, -depth + t), (f, -depth), (-f, -depth),
            (-f, -depth + t), (-h, -depth + t), (-h, -t), (-f, -t)]
    return [(y0 + y, top + z) for y, z in ring]


def _rail_ring(x, side, height):
    d = deck(x, CROWN) + height
    a, b = RAIL
    return [(side * RAIL_Y - a / 2, d - b), (side * RAIL_Y + a / 2, d - b), (side * RAIL_Y + a / 2, d),
            (side * RAIL_Y - a / 2, d)]


def build():
    common.reset()
    m = common.Mesh(NAME, outward=True)
    xs = stations()
    half = BRIDGE_WIDTH / 2
    shapes.loft_x(m, [(x, [(-half, deck(x, CROWN) - PLATE), (half, deck(x, CROWN) - PLATE), (half, deck(x, CROWN)),
                           (-half, deck(x, CROWN))]) for x in xs], "steel")
    # Through every station the deck is, so the flanges keep their distance
    # from its plate; their ends short of the abutments' ends.
    girder_xs = [x for x in xs if abs(x) < GIRDER_END - 1e-9]
    girder_xs = [-GIRDER_END] + girder_xs + [GIRDER_END]

    for y0 in (-GIRDER_Y, GIRDER_Y):
        m.shell()
        shapes.loft_x(m, [(x, _girder_ring(x, y0)) for x in girder_xs], "steel")

    for side in (-1, 1):
        # The pier: tiers standing on the canal's floor against the wall.
        for depth, width, z0, z1 in TIERS:
            m.shell()
            # (Its back 4 cm off the wall's face, more than the gate's 3 cm from what lies behind it.)
            x_in, x_back = side * (SPAN - depth), side * (SPAN - 0.04)
            top = z1 if z1 is not None else deck(side * (SPAN - depth / 2), CROWN) - PLATE - GIRDER[3]
            m.box((min(x_in, x_back), -width / 2, z0), (max(x_in, x_back), width / 2, top), "chiluca")

        # The brass patches where each girder sits on its pier.
        for y0 in (-GIRDER_Y, GIRDER_Y):
            m.shell()
            w, h, t = PATCH
            web = GIRDER[2] / 2
            out = 1 if y0 > 0 else -1
            y_face = y0 + out * web
            a0 = PATCH_AT
            top = deck(side * a0, CROWN) - PLATE - GIRDER[1] - 0.05
            m.box((side * a0 - w / 2, min(y_face, y_face + out * t), top - h),
                  (side * a0 + w / 2, max(y_face, y_face + out * t), top), "brass")

        # The railing.
        # (The rails through every other station: they touch nothing that tilts.)
        rail_xs = xs[::2] if len(xs) % 2 else xs[::2] + [xs[-1]]
        m.shell()
        shapes.loft_x(m, [(x, _rail_ring(x, side, PARAPET)) for x in rail_xs], "steel")
        m.shell()
        shapes.loft_x(m, [(x, _rail_ring(x, side, PARAPET * 0.55)) for x in rail_xs], "steel")
        k = 0

        while -HALF + 0.5 + k * RAIL_EVERY <= HALF - 0.5 + 1e-6:
            x = -HALF + 0.5 + k * RAIL_EVERY
            m.shell()
            m.box((x - POST / 2, side * RAIL_Y - POST / 2, deck(x, CROWN) - 0.06),
                  (x + POST / 2, side * RAIL_Y + POST / 2, deck(x, CROWN) + PARAPET - RAIL[1]), "steel")
            k += 1

    return m.make()


SETTS = (0.24, 0.23, 0.26)
JOINTS = {
    "11_steel_abutment": {"eye": (-9.0, -5.0, -1.2), "target": (-6.6, -1.7, -0.6), "show": [(NAME, (0.0, 0.0, 0.0), 0)],
                          "planes": [(-20.0, -20.0, -6.2, 20.0, -0.002, SETTS)]},
    "11c_patch": {"eye": (-6.6, -3.2, -0.5), "target": (-6.6, -1.7, -0.6), "show": [(NAME, (0.0, 0.0, 0.0), 0)],
                  "planes": [(-20.0, -20.0, -6.2, 20.0, -0.002, SETTS)]},
    "12_steel_deck_end": {"eye": (-13.0, 0.5, 1.7), "target": (-10.0, 0.0, 0.1), "show": [(NAME, (0.0, 0.0, 0.0), 0)],
                          "planes": [(-20.0, -20.0, -6.2, 20.0, -0.002, SETTS)]},
    "11d_piers": {"eye": (0.0, -9.0, -1.0), "target": (0.0, 0.0, -0.5), "show": [(NAME, (0.0, 0.0, 0.0), 0)],
                  "planes": [(-20.0, -20.0, -6.2, 20.0, -0.002, SETTS), (6.2, -20.0, 20.0, 20.0, -0.002, SETTS)]},
}

WEATHER = {"coarse": {NAME: 3.0}, "blendable": ["steel", "chiluca"], "foot": ["chiluca"],
           "tide": {NAME: (-2.0, -1.55)}, "ground_holes": [(-6.0, -20.0, 6.0, 20.0)]}


def main():
    build()
    common.export_piece(NAME, ATLAS, SLOTS, weather=WEATHER, out=common.ROOT / "assets" / "eclipse" / "kit")


if __name__ == "__main__":
    main()
