"""The services along the Metro Underground's walls (docs/superpowers/refs/underground/recipe.md):
the mains painted in the Company's colour code (green water, red fire, ochre
gas, blue air), the Company's cable tray in its orange with a fat bundle of
power, heavy cables swagged on hooks, and the orange conduit that takes a
stall's power up into the tray.

Every wall piece is built in the wall's frame: the wall face is y = 0, the
piece stands out into -y, its run goes along +x from 0, and z = 0 is the
height the bay hangs it at (a main's centre, the tray's rungs, the hooks'
arms). The bay (maps/underground_lab.gd) lines them up along its walls.

    Blender -b --factory-startup --python tools/eclipse/underground_services.py
"""

import math
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import common  # noqa: E402
import underground_shapes  # noqa: E402
from underground_shapes import box, pipe, smooth_object, stud, turned  # noqa: E402

NAME = "underground_services"
ATLAS = 2048
SLOTS = ["pipe_green", "pipe_red", "pipe_ochre", "pipe_blue", "metro_orange", "paint_band", "steel", "rubber",
         "cloth_black"]

rng = random.Random(1969)

# The mains: their colour, bore radius, how far their centre stands off the wall
# beyond their radius, and how many sides they are turned with.
MAINS = {
    "green": ("pipe_green", 0.09, 0.09, 16),
    "red": ("pipe_red", 0.075, 0.075, 16),
    "ochre": ("pipe_ochre", 0.05, 0.06, 12),
    "blue": ("pipe_blue", 0.035, 0.05, 10),
}
FLANGE = 0.035          # how far a flange stands proud of its pipe
FLANGE_T = 0.04         # each flange's thickness (a joint is two, bolted)
BAND = 0.12             # a painted band's width, near each section's start
CLAMP_T = 0.012         # a saddle clamp's strap (half its square section)

# The cable tray: its rails from the wall, its rungs, its brackets, its bundle.
TRAY_BACK, TRAY_FRONT = 0.06, 0.42
RAIL_T, RAIL_H = 0.02, 0.08
RUNG_EVERY, RUNG_W, RUNG_T = 0.3, 0.04, 0.02
TRAY_BRACKETS = (0.5, 2.5)
# The bundle: bottom row radii, top row radii, the gap kept between cables.
BUNDLE_LOW = (0.03, 0.025, 0.035, 0.028, 0.032)
BUNDLE_HIGH = (0.022, 0.026, 0.02)
BUNDLE_GAP = 0.006

# The swag: hooks every SPAN, three heavy cables lying on each hook's arm.
SPAN = 3.0
HOOK_OUT = 0.29
SWAG = ((0.03, 0.07, 0.2, "rubber"), (0.034, 0.145, 0.24, "cloth_black"), (0.026, 0.222, 0.28, "rubber"))

# The orange conduit from a stall's junction box (its origin, the box's top) up
# past the mains into the tray (tools/eclipse/stall.py's junction; the bay's mains).
CONDUIT_R = 0.022
CONDUIT_OUT = 0.19
CONDUIT_RISE = 0.75


# --- shapes ------------------------------------------------------------------------------------

def along_x(m, stations, sides, y, z=0.0):
    """A closed solid turned about the line (y, z) along X: `stations` as
    [(x, r, slot)], each slot painting from its station to the next; the
    ends capped, a step in radius at one x drawn as a ring face."""
    m.shell()
    rings = []

    for x, r, _ in stations:
        rings.append([(x, y + r * math.sin(2 * math.pi * k / sides), z + r * math.cos(2 * math.pi * k / sides))
                      for k in range(sides)])

    m.face(list(reversed(rings[0])), stations[0][2])

    for i in range(len(rings) - 1):
        a, b, slot = rings[i], rings[i + 1], stations[i][2]
        for k in range(sides):
            m.face([a[k], a[(k + 1) % sides], b[(k + 1) % sides], b[k]], slot)

    m.face(rings[-1], stations[-1][2])


def flange_bolts(m, x, y, r, slot="steel", count=6):
    """The bolts through a joint's two flanges, standing proud of both faces."""
    for k in range(count):
        a = 2 * math.pi * (k + 0.5) / count
        cy, cz = y + (r + FLANGE * 0.55) * math.sin(a), (r + FLANGE * 0.55) * math.cos(a)
        pipe(m, [(x - FLANGE_T - 0.02, cy, cz), (x + 0.02, cy, cz)], 0.012, 6, slot)


def saddle(m, x, d, r):
    """A strap clamp round the front of a pipe whose centre is `d` off the wall,
    its feet bolted flat to the wall."""
    big = r + CLAMP_T + 0.002
    path = [(x, 0.0, big)]

    for i in range(9):
        t = math.pi * i / 8
        path.append((x, -d - big * math.sin(t), big * math.cos(t)))

    path.append((x, 0.0, -big))
    pipe(m, path, CLAMP_T, 4, "steel")

    for z in (big + 0.03, -big - 0.03):
        box(m, (x - 0.03, -0.014, z - 0.03), (x + 0.03, 0.0, z + 0.03), "steel", r=0.0)
        stud(m, (x, -0.014, z), math.pi / 2, 0.0, r=0.02)


def main_section(m, colour, length):
    """A length of a main: a flange at each end (each joint two flanges, bolted
    through at the start), a painted band near its start, saddle clamps (one
    on a short length, two on a long)."""
    slot, r, standoff, sides = MAINS[colour]
    d = r + standoff
    big = r + FLANGE
    along_x(m, [(0.0, big, "steel"), (FLANGE_T, big, slot), (FLANGE_T, r, slot), (0.3, r, "paint_band"),
                (0.3 + BAND, r, slot), (length - FLANGE_T, r, slot), (length - FLANGE_T, big, "steel"),
                (length, big, "steel")], sides, -d)
    flange_bolts(m, FLANGE_T, -d, r)

    for x in (length / 2,) if length <= 2 else (1.0, length - 1.0):
        saddle(m, x, d, r)


# --- the mains ---------------------------------------------------------------------------------

def pipe_green_4(m):
    """The water main, four metres: it weeps at its joints."""
    main_section(m, "green", 4.0)


def pipe_green_2(m):
    main_section(m, "green", 2.0)


def pipe_ochre_4(m):
    """The gas line, painted ochre."""
    main_section(m, "ochre", 4.0)


def pipe_red_4(m):
    """The fire main, painted red."""
    main_section(m, "red", 4.0)


def pipe_red_valve(m):
    """Four metres of the fire main with a gate valve in it, its handwheel on top."""
    slot, r, standoff, sides = MAINS["red"]
    d = r + standoff
    big = r + FLANGE
    mid = 2.0
    along_x(m, [(0.0, big, "steel"), (FLANGE_T, big, slot), (FLANGE_T, r, slot), (0.3, r, "paint_band"),
                (0.3 + BAND, r, slot), (mid - 0.2, r, slot), (mid - 0.2, big, slot), (mid - 0.12, big, slot),
                (mid - 0.1, r + 0.05, slot), (mid + 0.1, r + 0.05, slot), (mid + 0.12, big, slot),
                (mid + 0.2, big, slot), (mid + 0.2, r, slot), (4.0 - FLANGE_T, r, slot),
                (4.0 - FLANGE_T, big, "steel"), (4.0, big, "steel")], sides, -d)
    flange_bolts(m, FLANGE_T, -d, r)
    # The bonnet standing up off the body, the stem, the wheel.
    turned(m, [(0.05, 0.0), (0.05, 0.16), (0.034, 0.2), (0.034, 0.24)], 12, slot, at=(mid, -d, r + 0.02))
    pipe(m, [(mid, -d, r + 0.24), (mid, -d, r + 0.36)], 0.015, 8, "steel")
    wheel_z, wheel_r = r + 0.33, 0.13
    pipe(m, [(mid + wheel_r * math.cos(a), -d + wheel_r * math.sin(a), wheel_z)
             for a in (2 * math.pi * k / 16 for k in range(16))], 0.014, 6, slot, closed=True)

    for k in range(4):
        a = math.pi / 4 + math.pi / 2 * k
        pipe(m, [(mid + 0.02 * math.cos(a), -d + 0.02 * math.sin(a), wheel_z),
                 (mid + (wheel_r - 0.01) * math.cos(a), -d + (wheel_r - 0.01) * math.sin(a), wheel_z)], 0.011, 6, slot)

    for x in (0.9, 3.1):
        saddle(m, x, d, r)


def pipe_red_drop(m):
    """Where the fire main ends: it bends down the wall to a hydrant valve at
    hand height (2.3 m below the main), blanked off below, bracketed to the wall."""
    slot, r, standoff, sides = MAINS["red"]
    d = r + standoff
    big = r + FLANGE
    along_x(m, [(0.0, big, "steel"), (FLANGE_T, big, slot), (FLANGE_T, r, slot), (0.12, r, slot)], sides, -d)
    flange_bolts(m, FLANGE_T, -d, r)
    bend, drop = 0.24, 2.3
    path = [(0.1, -d, 0.0)]

    for i in range(1, 9):
        a = math.pi / 2 * i / 8
        path.append((0.12 + bend * math.sin(a), -d, -bend + bend * math.cos(a)))

    path.append((0.12 + bend, -d, -drop + 0.1))
    pipe(m, path, r, sides, slot)
    x = 0.12 + bend
    # The blank flange that closes it off below.
    pipe(m, [(x, -d, -drop + 0.12), (x, -d, -drop - 0.04)], big, sides, "steel")
    # The hydrant: a short outlet out from the wall with its coupling and wheel.
    out = -drop + 0.4
    pipe(m, [(x, -d, out), (x, -d - 0.24, out)], 0.045, 12, slot)
    pipe(m, [(x, -d - 0.22, out), (x, -d - 0.3, out)], 0.062, 12, "steel")
    turned(m, [(0.03, 0.0), (0.03, 0.12)], 10, slot, at=(x, -d - 0.12, out + 0.04))
    pipe(m, [(x, -d - 0.12, out + 0.15), (x, -d - 0.12, out + 0.22)], 0.014, 8, "steel")
    wz, wr = out + 0.23, 0.1
    pipe(m, [(x + wr * math.cos(a), -d - 0.12 + wr * math.sin(a), wz)
             for a in (2 * math.pi * k / 14 for k in range(14))], 0.014, 6, slot, closed=True)

    for k in range(3):
        a = 2 * math.pi * k / 3
        pipe(m, [(x + 0.02 * math.cos(a), -d - 0.12 + 0.02 * math.sin(a), wz),
                 (x + (wr - 0.01) * math.cos(a), -d - 0.12 + (wr - 0.01) * math.sin(a), wz)], 0.011, 6, slot)

    for z in (-0.8, -1.45):
        _saddle_vertical(m, x, z, d, r)


def _saddle_vertical(m, x, z, d, r):
    """A strap clamp round a pipe running down the wall."""
    big = r + CLAMP_T + 0.002
    path = [(x - big, 0.0, z)]

    for i in range(9):
        t = math.pi * i / 8
        path.append((x - big * math.cos(t), -d - big * math.sin(t), z))

    path.append((x + big, 0.0, z))
    pipe(m, path, CLAMP_T, 4, "steel")

    for sx in (-1, 1):
        cx = x + sx * (big + 0.03)
        box(m, (cx - 0.03, -0.014, z - 0.03), (cx + 0.03, 0.0, z + 0.03), "steel", r=0.0)
        stud(m, (cx, -0.014, z), math.pi / 2, 0.0, r=0.02)


def pipe_blue_4(m):
    """The air line, painted blue, thin, clamped close."""
    main_section(m, "blue", 4.0)


# --- the Company's cable tray -------------------------------------------------------------------

def bundle(length, wander_phase=0.0, steps=16):
    """The tray's cables as (radius, slot, points): a bottom row laid side by
    side on the rungs, a top row on them, all wandering together across the
    tray so none ever touches another."""
    cables = []
    y = -TRAY_BACK - RAIL_T - BUNDLE_GAP

    for i, r in enumerate(BUNDLE_LOW):
        y -= r
        cables.append((r, y, RUNG_T + r, "rubber" if i % 2 else "cloth_black"))
        y -= r + BUNDLE_GAP

    top = RUNG_T + 2 * max(BUNDLE_LOW) + BUNDLE_GAP
    y = -TRAY_BACK - RAIL_T - BUNDLE_GAP - 0.02

    for i, r in enumerate(BUNDLE_HIGH):
        y -= r
        cables.append((r, y, top + r, "rubber"))
        y -= r + BUNDLE_GAP

    out = []

    for r, cy, cz, slot in cables:
        points = [(length * i / steps, cy + 0.006 * math.sin(i * 0.9 + wander_phase), cz) for i in range(steps + 1)]
        out.append((r, slot, points))

    return out


def _tray(m, length, spill):
    """A ladder tray on two wall brackets with its bundle; `spill` lets one top
    cable out over the front rail in a hanging loop and back in."""
    for y0, y1 in ((-TRAY_BACK - RAIL_T, -TRAY_BACK), (-TRAY_FRONT, -TRAY_FRONT + RAIL_T)):
        box(m, (0.0, y0, 0.0), (length, y1, RAIL_H), "metro_orange")

    x = RUNG_EVERY / 2
    while x < length:
        box(m, (x - RUNG_W / 2, -TRAY_FRONT + RAIL_T, 0.0), (x + RUNG_W / 2, -TRAY_BACK - RAIL_T, RUNG_T), "metro_orange",
            r=0.0)
        x += RUNG_EVERY

    for x in TRAY_BRACKETS:
        box(m, (x - 0.02, -TRAY_FRONT - 0.01, -0.04), (x + 0.02, 0.0, 0.0), "steel", r=0.0)
        box(m, (x - 0.04, -0.014, -0.21), (x + 0.04, 0.0, -0.0), "steel", r=0.0)
        pipe(m, [(x, -0.02, -0.18), (x, -0.28, -0.045)], 0.012, 4, "steel")
        stud(m, (x, -0.014, -0.17), math.pi / 2, 0.0, r=0.02)

    cables = bundle(length)

    for k, (r, slot, points) in enumerate(cables):
        if spill and k == len(cables) - 1:
            # Let loose: out of the tray over its front rail, a loop hanging, back in.
            _, cy, cz = points[0]
            path = [p for p in points if p[0] <= 1.1]
            path += [(1.3, -TRAY_FRONT + 0.02, RAIL_H + r + 0.03), (1.45, -TRAY_FRONT - 0.06, RAIL_H - 0.05)]
            for i in range(1, 10):
                t = i / 10
                path.append((1.45 + 1.0 * t, -TRAY_FRONT - 0.06, RAIL_H - 0.05 - 0.55 * math.sin(math.pi * t)))
            path += [(2.45, -TRAY_FRONT - 0.06, RAIL_H - 0.05), (2.6, -TRAY_FRONT + 0.02, RAIL_H + r + 0.03)]
            path += [p for p in points if p[0] >= 2.8]
            points = path
        pipe(m, points, r, 8, slot)


def cable_tray_4(m):
    """Four metres of the Company's tray, its rails in the Company's orange."""
    _tray(m, 4.0, False)


def cable_tray_4_spill(m):
    """The same, where a cable has come loose and hangs out in a loop."""
    _tray(m, 4.0, True)


# --- heavy cables on hooks ----------------------------------------------------------------------

def _hook(m, x):
    """A J-hook: a plate bolted to the wall, an arm out, its tip turned up."""
    box(m, (x - 0.04, -0.014, -0.12), (x + 0.04, 0.0, 0.04), "steel", r=0.0)
    stud(m, (x, -0.014, -0.08), math.pi / 2, 0.0, r=0.02)
    box(m, (x - 0.02, -HOOK_OUT, -0.035), (x + 0.02, -0.014, 0.0), "steel", r=0.0)
    box(m, (x - 0.02, -HOOK_OUT, 0.0), (x + 0.02, -HOOK_OUT + 0.025, 0.06), "steel", r=0.0)


def cable_swag(m):
    """Three heavy cables swagging one span from a hook to the next one's place
    (the next span's hook carries them on), each sagging its own depth."""
    _hook(m, 0.0)

    for r, out, sag, slot in SWAG:
        steps = 14
        pipe(m, [(SPAN * i / steps, -out, r - sag * math.sin(math.pi * i / steps)) for i in range(steps + 1)],
             r, 8, slot)


def cable_hook(m):
    """The last hook of a swag run, holding the cables' ends."""
    _hook(m, 0.0)


# --- a stall's power up into the tray -----------------------------------------------------------

def conduit_path():
    """The conduit's centreline from the junction box's top (the origin; the box
    against its stall's back, CONDUIT_OUT clear of the mains in front of them)."""
    path = [(0.0, 0.0, 0.0), (0.0, 0.0, 0.05)]

    for i in range(1, 9):
        t = i / 8
        path.append((0.0, -CONDUIT_OUT * (1 - math.cos(math.pi * t)) / 2, 0.05 + 0.2 * t))

    path.append((0.0, -CONDUIT_OUT, CONDUIT_RISE))
    return path


def conduit_drop(m):
    """The orange conduit that carries a stall's power from its junction box up
    past the mains into the Company's tray, strapped to the wall's tray bracket."""
    pipe(m, conduit_path(), CONDUIT_R, 8, "metro_orange")
    # Its couplings, a hand's width apart.
    for z in (0.42, 0.62):
        pipe(m, [(0.0, -CONDUIT_OUT, z - 0.025), (0.0, -CONDUIT_OUT, z + 0.025)], CONDUIT_R + 0.012, 8, "steel")


PIECES = [pipe_green_4, pipe_green_2, pipe_ochre_4, pipe_red_4, pipe_red_valve, pipe_red_drop, pipe_blue_4,
          cable_tray_4, cable_tray_4_spill, cable_swag, cable_hook, conduit_drop]


def build():
    common.reset()
    underground_shapes.rng = rng
    rng.seed(1969)

    for f in PIECES:
        smooth_object(f.__name__, f)


def main():
    build()
    common.export_piece(NAME, ATLAS, SLOTS, out=common.ROOT / "assets" / "eclipse" / "kit", sets_each=True, budget=6000)


if __name__ == "__main__":
    main()
