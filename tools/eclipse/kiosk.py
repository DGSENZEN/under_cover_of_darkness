"""The Metro kiosk (docs/superpowers/refs/mexico_city/cards/kiosk.md): the
Light Company's iron round a stair seeped in from 1969. Built in Blender,
its atlas made, baked and exported to assets/eclipse/lab/kiosk.*; the
geometry gate decides whether it stands.

    Blender -b --factory-startup --python tools/eclipse/kiosk.py

Blender axes: X across the opening, +Y down the stair's run (into the
station), Z up. The origin is the middle of the entry edge at street level.
"""

import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import bpy  # noqa: E402

import common  # noqa: E402

NAME = "kiosk"
# 768: with its landing and passage under the street the kiosk outgrew 512 at ~50 px/m.
ATLAS = 768
# The card's slots, in the card's order (the region map's indices).
SLOTS = ["iron", "brass", "glass", "tile_line2", "stone_step", "sign"]

# The opening and its coping (m).
HALF = 1.5
RUN = 6.0
COPING = 0.375
COPING_H = 0.25
LINE = HALF + COPING / 2           # the balustrade's centreline, either side
FAR = RUN + COPING / 2             # and across the far end
# The 1969 stair: 20 steps.
STEPS = 20
RISE = 0.15
TREAD = 0.30
# The balustrade.
POST = 0.08                        # posts square, this across
POST_TOP = 1.33
FINIAL = 1.43
RAIL = 0.05
LOW_RAIL = (0.35, 0.41)
TOP_RAIL = (1.19, 1.25)
FRET_T = 0.03                      # the fret panel's thickness
BAND = 0.07                        # the fret's band
# The lamps and the sign.
LAMP_Y = 0.15
PLINTH = 0.26
PLINTH_TOP = 0.55
SHAFT_R = 0.055
GLOBE_Z = 3.5
GLOBE_R = 0.1875
COLLAR = (0.09, 3.2, 3.33)         # radius, from, to
SIGN = (1.5, 0.5, 2.55)            # width, height, bottom (its holder's underside at 2.5)
# The canopy: a fan from a hub over the sign back over the stair head.
HUB = (0.0, LAMP_Y, 3.45)
FAN_R = 2.6
FAN_ANGLES = [-60, -40, -20, 0, 20, 40, 60]
RIM_Z = 3.0
EIGHT = math.pi / 8                # turns an 8-sided tube to face +-x


def apothem(radius, sides):
    return radius * math.cos(math.pi / sides)


def ccw(outline):
    area = sum(a[0] * b[1] - b[0] * a[1] for a, b in zip(outline, outline[1:] + outline[:1]))
    return outline if area > 0 else list(reversed(outline))


def coping():
    m = common.Mesh("kiosk_coping")
    x0, x1, y1 = HALF + COPING, HALF, RUN + COPING
    outline = ccw([(-x0, 0), (-x1, 0), (-x1, RUN), (x1, RUN), (x1, 0), (x0, 0), (x0, y1), (-x0, y1)])
    m.prism(outline, 0.0, COPING_H, "stone_step", caps=(False, True))
    return m.make()


# The landing at the stair's foot and the passage over it, under the street.
LANDING = 1.8
FOOT = -RISE * STEPS                # the landing's floor
CEILING = -0.45                     # the street slab's underside over the passage
SLAB = 0.2                          # the landing slab's depth


def stair():
    """One step: a solid block under its tread (tread on top, the riser below
    it at the back, the riser facing down the stair the way one walks), its
    ends and underside closed. The other 19 are copies sharing its UVs."""
    m = common.Mesh("kiosk_stair")
    m.box((-HALF, 0.0, -2 * RISE), (HALF, TREAD, -RISE), "stone_step")
    return m.make()


def stair_ends():
    """The rise from the street down onto the first tread, and the landing
    at the foot: solid, their tops the floor walked on."""
    m = common.Mesh("kiosk_stair_ends")
    # The first riser: the street's edge, facing down the stair.
    m.face([(-HALF, 0.0, -RISE), (HALF, 0.0, -RISE), (HALF, 0.0, 0.0), (-HALF, 0.0, 0.0)][::-1], "stone_step")
    m.box((-HALF, RUN, FOOT - SLAB), (HALF, RUN + LANDING, FOOT), "stone_step", skip=("-y",))
    return m.make()


def stair_walls():
    """The tiled walls down the stair and along the passage at its foot, the
    passage's ceiling (the street slab's underside) and its end wall."""
    m = common.Mesh("kiosk_stair_walls")
    far = RUN + LANDING
    under = -2 * RISE - RUN * RISE / TREAD      # below the steps' undersides
    # The left wall, faces +x; the right is its mirror, made after unwrapping.
    left = [(0.0, -2 * RISE), (RUN, under), (far, under), (far, CEILING), (RUN, CEILING), (RUN, 0.0), (0.0, 0.0)]
    m.face([(-HALF, y, z) for y, z in ccw_yz(left)], "tile_line2")
    # The fascia over the passage's mouth (under the far coping), facing the stair.
    m.face([(-HALF, RUN, CEILING), (HALF, RUN, CEILING), (HALF, RUN, 0.0), (-HALF, RUN, 0.0)], "tile_line2")
    # The passage's ceiling, facing down.
    m.face([(-HALF, RUN, CEILING), (-HALF, far, CEILING), (HALF, far, CEILING), (HALF, RUN, CEILING)], "tile_line2")
    # The passage's end wall, facing back up it (the ticket hall comes with the station kit).
    m.face([(-HALF, far, FOOT), (HALF, far, FOOT), (HALF, far, CEILING), (-HALF, far, CEILING)], "tile_line2")
    return m.make()


def ccw_yz(points):
    """(y, z) points ordered counter-clockwise, so a face in x = const faces +x."""
    area = sum(a[0] * b[1] - b[0] * a[1] for a, b in zip(points, points[1:] + points[:1]))
    return points if area > 0 else list(reversed(points))


def patches():
    """Brass plates over the joint of 1920s coping and 1969 wall, a little crooked."""
    m = common.Mesh("kiosk_patches")
    plates = [(-1, 1.2, 3), (-1, 3.3, -4), (-1, 5.1, 2), (1, 2.1, -3), (1, 4.4, 5)]
    # Plates 4 cm thick: a thinner one laid on the wall fights it for depth at a distance.
    half_y, z_lo, z_hi, t = 0.2, -0.18, 0.12, 0.04
    zc = (z_lo + z_hi) / 2

    for side, y, degrees in plates:
        a = math.radians(degrees)
        # The corners counter-clockwise in (y, z), turned about the wall's normal.
        corners = [(y + dy * math.cos(a) - dz * math.sin(a), zc + dy * math.sin(a) + dz * math.cos(a))
                   for dy, dz in ((-half_y, z_lo - zc), (half_y, z_lo - zc), (half_y, z_hi - zc), (-half_y, z_hi - zc))]
        wall = side * HALF
        front = wall - side * t                 # stands off the wall into the opening
        f = [(front, cy, cz) for cy, cz in corners]
        b = [(wall, cy, cz) for cy, cz in corners]
        edges = [[b[i], b[(i + 1) % 4], f[(i + 1) % 4], f[i]] for i in range(4)]

        if side < 0:   # the left wall: the plate faces +x
            m.face(f, "brass")

            for quad in edges:
                m.face(quad, "brass")
        else:          # the right wall: faces -x
            m.face(list(reversed(f)), "brass")

            for quad in edges:
                m.face(list(reversed(quad)), "brass")

    return m.make()


def posts():
    """Positions along the three closed sides, corners shared."""
    long_side = [0.375 + i * (FAR - 0.375) / 6 for i in range(7)]
    far_side = [-LINE + i * (2 * LINE) / 3 for i in range(4)]
    return long_side, far_side


def balustrade():
    m = common.Mesh("kiosk_balustrade")
    long_side, far_side = posts()
    spots = [(-LINE, y) for y in long_side] + [(LINE, y) for y in long_side] + [(x, FAR) for x in far_side[1:-1]]
    half = POST / 2

    for x, y in spots:
        # A square tube from the coping to under its finial, then a point.
        m.box((x - half, y - half, COPING_H), (x + half, y + half, POST_TOP), "iron", skip=("-z", "+z"))
        top = [(x - half, y - half, POST_TOP), (x + half, y - half, POST_TOP), (x + half, y + half, POST_TOP),
               (x - half, y + half, POST_TOP)]
        tip = (x, y, FINIAL)

        for i in range(4):
            m.face([top[i], top[(i + 1) % 4], tip], "iron")

    r = RAIL / 2

    for z0, z1 in (LOW_RAIL, TOP_RAIL):
        for side in (-LINE, LINE):
            for a, b in zip(long_side, long_side[1:]):
                m.box((side - r, a + half, z0), (side + r, b - half, z1), "iron", skip=("-y", "+y"))

        for a, b in zip(far_side, far_side[1:]):
            m.box((a + half, FAR - r, z0), (b - half, FAR + r, z1), "iron", skip=("-x", "+x"))

    return m.make()


def _fret_outline(w, h, mirror):
    """The stepped fret, a band climbing in three steps from the low rail to
    the top rail, counter-clockwise in (u, v)."""
    t = BAND
    s = (w - t) / 3
    rh = (h - t) / 2
    pts = [(0, 0), (s + t, 0), (s + t, rh), (2 * s + t, rh), (2 * s + t, h - t), (w, h - t), (w, h),
           (2 * s, h), (2 * s, rh + t), (s, rh + t), (s, t), (0, t)]

    if mirror:
        pts = [(w - u, v) for u, v in reversed(pts)]

    return pts


def _panel(m, origin, u_axis, v_axis, outline, thick, slot_name):
    """A flat outline stood in space: origin + u*U + v*V, `thick` along U x V."""
    n = [u_axis[1] * v_axis[2] - u_axis[2] * v_axis[1], u_axis[2] * v_axis[0] - u_axis[0] * v_axis[2],
         u_axis[0] * v_axis[1] - u_axis[1] * v_axis[0]]
    at = lambda u, v, k: tuple(origin[i] + u * u_axis[i] + v * v_axis[i] + k * n[i] * thick / 2 for i in range(3))
    front = [at(u, v, 1) for u, v in outline]
    back = [at(u, v, -1) for u, v in outline]
    m.face(front, slot_name)
    m.face(list(reversed(back)), slot_name)

    for i in range(len(outline)):
        j = (i + 1) % len(outline)
        m.face([back[i], back[j], front[j], front[i]], slot_name)


def frets():
    m = common.Mesh("kiosk_frets")
    long_side, far_side = posts()
    half = POST / 2
    h = TOP_RAIL[0] - LOW_RAIL[1]
    k = 0

    for side in (-LINE, LINE):
        for a, b in zip(long_side, long_side[1:]):
            w = (b - half) - (a + half)
            _panel(m, (side, a + half, LOW_RAIL[1]), (0, 1, 0), (0, 0, 1), _fret_outline(w, h, k % 2 == 1), FRET_T, "iron")
            k += 1

    for a, b in zip(far_side, far_side[1:]):
        w = (b - half) - (a + half)
        _panel(m, (a + half, FAR, LOW_RAIL[1]), (1, 0, 0), (0, 0, 1), _fret_outline(w, h, k % 2 == 1), FRET_T, "iron")
        k += 1

    return m.make()


def lamp(side):
    name = "kiosk_lamp_left" if side < 0 else "kiosk_lamp_right"
    m = common.Mesh(name)
    x = side * LINE
    p = PLINTH / 2
    m.box((x - p, LAMP_Y - p, COPING_H), (x + p, LAMP_Y + p, PLINTH_TOP), "iron", skip=("-z",))
    m.tube((x, LAMP_Y, PLINTH_TOP), (x, LAMP_Y, COLLAR[1]), SHAFT_R, 8, "iron", caps=(False, False), twist=EIGHT)
    m.tube((x, LAMP_Y, COLLAR[1]), (x, LAMP_Y, COLLAR[2]), COLLAR[0], 8, "brass", caps=(True, True), twist=EIGHT)
    obj = m.make()

    g = common.Mesh(name + "_globe")
    g.sphere((x, LAMP_Y, GLOBE_Z), GLOBE_R, 6, 8, "glass")
    g.make()
    return obj


def sign():
    m = common.Mesh("kiosk_sign")
    reach = LINE - apothem(SHAFT_R, 8)
    w, h, z0 = SIGN
    y0, y1 = LAMP_Y - 0.03, LAMP_Y + 0.03
    m.box((-reach, y0, z0 - 0.05), (reach, y1, z0), "iron", skip=("-x", "+x"))
    m.box((-reach, y0, z0 + h), (reach, y1, z0 + h + 0.05), "iron", skip=("-x", "+x"))

    for x0, x1 in ((-w / 2 - 0.04, -w / 2), (w / 2, w / 2 + 0.04)):
        m.box((x0, y0, z0), (x1, y1, z0 + h), "iron", skip=("-z", "+z"))

    m.make()

    panel = common.Mesh("kiosk_sign_panel")
    py0, py1 = LAMP_Y - 0.015, LAMP_Y + 0.015
    panel.face([(-w / 2, py0, z0), (w / 2, py0, z0), (w / 2, py0, z0 + h), (-w / 2, py0, z0 + h)], "sign")   # -y, the street
    panel.face([(-w / 2, py1, z0), (-w / 2, py1, z0 + h), (w / 2, py1, z0 + h), (w / 2, py1, z0)], "iron")   # +y
    panel.make()


def canopy():
    rims = []

    for degrees in FAN_ANGLES:
        a = math.radians(degrees)
        rims.append((FAN_R * math.sin(a), HUB[1] + FAN_R * math.cos(a), RIM_Z))

    girder = common.Mesh("kiosk_girder")
    reach = LINE - apothem(COLLAR[0], 8)
    girder.box((-reach, LAMP_Y - 0.05, COLLAR[1]), (reach, LAMP_Y + 0.05, 3.3), "iron", skip=("-x", "+x"))
    girder.bar((0, LAMP_Y, HUB[2]), rims[3], 0.1, 0.16, "iron", caps=(False, True))
    # The hub well wider than the girder through it, so their sides never lie a hair apart.
    girder.tube((0, LAMP_Y, 3.3), (0, LAMP_Y, 3.52), 0.12, 8, "brass", caps=(False, True), twist=EIGHT)
    girder.make()

    frame = common.Mesh("kiosk_canopy_frame")

    for i, rim in enumerate(rims):
        if i != 3:
            frame.bar(HUB, rim, 0.035, 0.035, "iron", caps=(False, True))

    for a, b in zip(rims, rims[1:]):
        frame.bar(a, b, 0.04, 0.04, "iron")

    frame.make()

    glass = common.Mesh("kiosk_canopy_glass")

    for a, b in zip(rims, rims[1:]):
        # Each pane between its ribs, not through them (glass laid on iron
        # fights it for depth): the triangle drawn in from every edge.
        glass.face(inset([HUB, b, a], PANE_INSET), "glass")

    glass.make()


# How far each canopy pane stands in from its ribs and rim (m): past the
# ribs' half-width, so pane and rib never overlap.
PANE_INSET = 0.03


def inset(triangle, width):
    """A triangle drawn in by `width` from each of its edges (shrunk about its
    incentre: every edge moves in by the same distance)."""
    from mathutils import Vector

    p = [Vector(c) for c in triangle]
    sides = [(p[1] - p[2]).length, (p[2] - p[0]).length, (p[0] - p[1]).length]
    perimeter = sum(sides)
    centre = (p[0] * sides[0] + p[1] * sides[1] + p[2] * sides[2]) / perimeter
    area = (p[1] - p[0]).cross(p[2] - p[0]).length / 2
    radius = 2 * area / perimeter
    k = max(0.0, (radius - width) / radius)
    return [tuple(centre + (c - centre) * k) for c in p]


# Where to look at each of the card's joints: (eye, target), Blender metres.
JOINTS = {
    "01_posts_coping": ((-0.9, 1.6, 0.9), (-1.6875, 2.31, 0.3)),
    "02_fret_rails": ((-0.6, 2.2, 1.2), (-1.6875, 2.8, 0.8)),
    "03_lamp_base": ((-0.8, -0.8, 1.0), (-1.6875, 0.15, 0.4)),
    "04_sign_stalks": ((-0.8, -1.2, 2.6), (-1.6, 0.15, 2.8)),
    "05_girder_stalks": ((-0.9, -1.0, 3.6), (-1.6, 0.15, 3.25)),
    "06_ribs_girder": ((0.6, -0.9, 3.9), (0.0, 0.2, 3.45)),
    "07_glass_ribs": ((0.5, 0.8, 2.2), (0.8, 1.6, 3.2)),
    "08_top_step_coping": ((-0.5, -1.0, 1.0), (-1.5, 0.0, 0.0)),
    "09_walls_coping_patches": ((0.3, 1.3, 0.6), (1.5, 2.1, -0.1)),
    "10_walls_steps": ((0.0, 2.0, -0.4), (-1.5, 3.0, -1.6)),
    "11_landing_walls": ((0.0, 4.8, -1.6), (1.5, 6.0, -2.5)),
    "12_steps_from_below": ((0.0, 6.6, -1.6), (0.0, 3.0, -2.2)),
    "13_passage": ((0.0, 5.2, -1.4), (0.0, 7.8, -1.9)),
    "14_landing_last_step": ((-1.0, 5.2, -2.2), (0.0, 6.0, -3.0)),
}


# The vertex paint (tools/eclipse/weather.py): the stair's 20 blocks on a
# coarser grid, the lamps' soot rising from their globes, the stair's
# opening cut from the stand-in ground the occlusion rays see.
WEATHER = {"lines": [("z", 0.3), ("z", 1.2)], "coarse": {"kiosk_stair": 1.0}, "blendable": ["iron", "stone_step"],
           "ground_holes": [(-HALF, 0.0, HALF, RUN)]}


def soot():
    for side in (-1, 1):
        empty = bpy.data.objects.new("soot_lamp_%d" % side, None)
        bpy.context.scene.collection.objects.link(empty)
        empty.location = (side * LINE, LAMP_Y, GLOBE_Z + GLOBE_R)


def build():
    common.reset()
    coping()
    step = stair()
    stair_ends()
    walls = stair_walls()
    patches()
    balustrade()
    frets()
    lamp(-1)
    lamp(1)
    sign()
    canopy()
    soot()
    return step, walls


def main():
    step, walls = build()

    def merge():
        # The 20 steps share one step's island; the two side walls share one.
        common.repeat_faces(step, [(0, TREAD * i, -RISE * i) for i in range(1, STEPS)])
        common.mirror_faces(walls, lambda f: abs(f.normal.x) > 0.5)

    common.export_piece(NAME, ATLAS, SLOTS, merge=merge, weather=WEATHER)


if __name__ == "__main__":
    main()
