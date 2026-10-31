"""The Zócalo station's Company lamps (docs/superpowers/specs/2026-10-31-station-machinery-design.md; plan
docs/superpowers/plans/2026-10-31-station-machinery.md, Task 1): the Light Company's cold blue ward lamps on brackets,
on the hall's columns and the platforms' back walls, the blue against the station's warm haze (Deadlock's key).

V2 on the user's note (Oct 31: "more work to look like lamps, more aesthetically distinct"): a stepped Mayan-deco
back plate on the face, a gooseneck arm out and over, a tall eight-sided glass lantern hung from it (mostly glass, read
as a lamp across the hall), a stepped crown ringed by a low brass sunburst under a turned knob, the Company's obsidian ward eye on the
glass's front (the lamps are wards), and a tin milagro someone tied under it.

Frames (Blender: the face at y = 0, the arm reaching out along -y; Godot turns -y into +z): the back plate's middle at
the origin, on the face. The globe's middle at GLOBE.

    Blender -b --factory-startup --python tools/eclipse/station_lamps.py
"""

import math
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from mathutils import Vector  # noqa: E402

import common  # noqa: E402
import shapes  # noqa: E402
import underground_shapes  # noqa: E402
from underground_shapes import box, pipe, smooth_object, stud, turned  # noqa: E402

NAME = "station_lamps"
ATLAS = 2048
SLOTS = ["iron", "brass", "obsidian", "glass", "tin"]

# The stepped back plate's tiers (m: half-width, from z, to z, how far out from the face), Mayan setbacks to its top.
PLATE = [(0.18, -0.32, 0.18, 0.04), (0.13, 0.18, 0.28, 0.04), (0.08, 0.28, 0.34, 0.04)]
# The lantern's middle (m: out along -y, down), its glass (m: across its flats, tall), its corners.
GLOBE = (-0.62, -0.52)
LANTERN = (0.3, 0.5)
SIDES = 8
# The crown's tiers over the glass (m: half-width, from, to over the glass's top), the sunburst's height over the
# glass's top and its rays' reach, the spike.
CROWN = [(0.2, 0.0, 0.05), (0.15, 0.05, 0.11), (0.1, 0.11, 0.17)]
SUN_AT = 0.065
SUN_REACH = 0.25
SPIKE = 0.12
# The arm's radius; everything of it within this under its mount (m).
ARM_R = 0.025
MOUNT_DROP = 1.05


def neck_points():
    """The gooseneck's path: off the corbel, a cubic Bezier up and over, straight down into the socket over the
    finial."""
    gy, gz = GLOBE
    tip = gz + LANTERN[1] / 2 + CROWN[-1][2] + SPIKE
    p0, p1, p2, p3 = Vector((0.0, -0.1, 0.04)), Vector((0.0, -0.2, 0.42)), Vector((0.0, gy, 0.42)), Vector((0.0, gy, 0.2))
    points = [tuple((1 - t) ** 3 * p0 + 3 * (1 - t) ** 2 * t * p1 + 3 * (1 - t) * t ** 2 * p2 + t ** 3 * p3)
              for t in (k / 16 for k in range(17))]
    return points + [(0.0, gy, tip + 0.03)]


def brace_points():
    """The brace: a quarter curve from the back plate's foot out and up, ending on the neck."""
    y0, z0 = -PLATE[0][3], PLATE[0][1] + 0.1
    _, yt, zt = neck_points()[5]
    return [(0.0, y0 + (yt - y0) * math.sin(math.pi / 2 * k / 8), z0 + (zt - z0) * (1 - math.cos(math.pi / 2 * k / 8)))
            for k in range(9)]


def _turned_at(m, profile, slot, at, sides=SIDES):
    turned(m, profile, sides, slot, at=at, twist=math.pi / SIDES)


def ward_bracket(m):
    underground_shapes.rng = random.Random(5)
    gy, gz = GLOBE
    r = LANTERN[0] / 2 / math.cos(math.pi / SIDES)
    z0, z1 = gz - LANTERN[1] / 2, gz + LANTERN[1] / 2
    # The back plate, stepped, studded, a corbel at the arm's root.
    for half, a, b, out in PLATE:
        box(m, (-half, -out, a), (half, 0.0, b), "iron", r=0.01)
    box(m, (-0.07, -0.12, -0.06), (0.07, -0.04, 0.1), "iron", r=0.015)
    for z in (PLATE[0][1] + 0.07, PLATE[0][2] - 0.07):
        for x in (-PLATE[0][0] + 0.045, PLATE[0][0] - 0.045):
            stud(m, (x, -PLATE[0][3], z), math.pi / 2, 0.0, slot="brass", r=0.018)
    # The gooseneck: up off the corbel, over and out, down to the socket over the spike.
    tip = z1 + CROWN[-1][2] + SPIKE
    pipe(m, neck_points(), ARM_R, 12, "iron")
    turned(m, [(0.045, tip), (0.045, tip + 0.04), (0.03, tip + 0.07)], 12, "brass", at=(0.0, gy, 0.0))
    pipe(m, brace_points(), 0.016, 8, "iron")
    # The lantern: brass rings top and foot, its glass, a mullion at each corner.
    _turned_at(m, [(r * 0.97, z0), (r, z0 + 0.04), (r, z1 - 0.07), (r * 0.97, z1 - 0.03)], "glass",
               (0.0, gy, 0.0))
    # (The glass's ends sit 3 cm inside its rings', never in a plane with theirs.)
    for a, b in ((z0 - 0.03, z0 + 0.012), (z1 - 0.045, z1)):
        _turned_at(m, [(r + 0.025, a), (r + 0.025, b)], "brass", (0.0, gy, 0.0))
    for k in range(SIDES):
        ang = math.pi / SIDES + 2 * math.pi * k / SIDES
        x, y = (r + 0.015) * math.cos(ang), gy + (r + 0.015) * math.sin(ang)
        pipe(m, [(x, y, z0 + 0.012), (x, y, z1 - 0.045)], 0.013, 6, "brass")
    # The crown: stepped, a sunburst round its second tier, the spike.
    for half, a, b in CROWN:
        _turned_at(m, [(half / math.cos(math.pi / SIDES), z1 + a), (half / math.cos(math.pi / SIDES), z1 + b)], "brass",
                   (0.0, gy, 0.0))
    rays = 16
    for k in range(rays):
        ang = 2 * math.pi * (k + 0.5) / rays
        reach = SUN_REACH if k % 2 == 0 else SUN_REACH - 0.03
        # (Standing on the first tier, clear of the second's corners: no face of a ray in a plane with a tier's.)
        # A blade tapering to its point, lifting a little as it goes out.
        inner = CROWN[1][0] / math.cos(math.pi / SIDES) + 0.001
        c, sn = math.cos(ang), math.sin(ang)
        foot = z1 + CROWN[0][2]
        rings = []
        for d, half, tall, lift in ((inner, 0.018, 0.03, 0.0), (reach, 0.008, 0.014, 0.0)):
            x, y = c * d, gy + sn * d
            rings.append([(x - sn * half, y + c * half, foot + lift), (x + sn * half, y - c * half, foot + lift),
                          (x + sn * half, y - c * half, foot + lift + tall),
                          (x - sn * half, y + c * half, foot + lift + tall)])
        m.shell()
        shapes.loft(m, rings, "brass", caps=True)
    # (A turned knob over the crown, the arm's socket on it.)
    base = z1 + CROWN[-1][2]
    turned(m, [(0.04, base), (0.03, base + 0.03), (0.034, base + 0.06), (0.045, base + 0.08), (0.03, base + 0.105),
               (0.016, tip)], 12, "brass", at=(0.0, gy, 0.0))
    # The Company's eye on the glass's front: a brass bezel, its obsidian lens.
    face = gy - LANTERN[0] / 2
    turned(m, [(0.08, 0.0), (0.08, 0.035)], 20, "brass", at=(0.0, face, gz), lean=math.pi / 2)
    turned(m, [(0.055, 0.03), (0.048, 0.065), (0.02, 0.075)], 20, "obsidian", at=(0.0, face, gz), lean=math.pi / 2)
    # The foot: stepped under the glass, a drop finial, and a tin milagro someone tied to it.
    _turned_at(m, [(r * 0.75, z0 - 0.07), (r * 0.75, z0 - 0.03)], "brass", (0.0, gy, 0.0))
    turned(m, [(0.045, z0 - 0.07), (0.035, z0 - 0.1), (0.03, z0 - 0.12), (0.014, z0 - 0.15)], 10, "brass",
           at=(0.0, gy, 0.0))
    knot = z0 - 0.15
    pipe(m, [(0.0, gy, knot + 0.01), (0.0, gy, knot - 0.02)], 0.006, 6, "iron")
    box(m, (-0.028, gy - 0.006, knot - 0.075), (0.028, gy + 0.006, knot - 0.02), "tin", r=0.008)


PIECES = [("ward_bracket", ward_bracket)]

BUDGET = {"ward_bracket": 8000}
SLIVER = {"ward_bracket": 0.004}


def build():
    common.reset()
    for name, f in PIECES:
        smooth_object(name, f)


def main():
    build()
    common.export_piece(NAME, ATLAS, SLOTS, out=common.ROOT / "assets" / "eclipse" / "kit", sets_each=True,
                        budget=max(BUDGET.values()), sliver=min(SLIVER.values()), pack_margin=0.0015)


if __name__ == "__main__":
    main()
