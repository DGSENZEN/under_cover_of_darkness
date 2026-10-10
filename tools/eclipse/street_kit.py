"""The street kit (docs/superpowers/refs/mexico_city/cards/street_canal.md,
the Zócalo's family 1): the plaza's kerbs and their drop, the gutter's
grate, the old causeway's band of darker stone, the tram's track, its curve
and the seeped third rail, the Line 2 service hatch, the Company's junction
box. Each piece its own object at the origin, built to street_dims.py;
one atlas for the kit, baked and exported to assets/eclipse/kit/.

    Blender -b --factory-startup --python tools/eclipse/street_kit.py

Blender axes: a run's piece starts at the origin and runs along +X, its
front (the street side) looking -Y, Z up, the setts' top at z 0.
"""

import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import bpy  # noqa: E402

import common  # noqa: E402
import shapes  # noqa: E402
from street_dims import (BAND, CONDUCTOR_OFF, CURVE_RADIUS, DROP_FLAT, DROP_LENGTH, DROP_LOW, DROP_RAMP,  # noqa: E402
                         GAUGE, GRATE_DEPTH, GRATE_LENGTH, HATCH, HATCH_FRAME, KERB_DEPTH, KERB_FOOT,
                         KERB_LENGTH, KERB_PROUD, KERB_ROUND, SKIRT, STRIP_HALF, TRACK_LENGTH, curve_centreline)

NAME = "street_kit"
ATLAS = 1024
SLOTS = ["basalt", "chiluca", "granite", "steel", "iron", "brass", "sign"]


# Kerbs

def kerb_profile(top=KERB_PROUD, chipped=False):
    """The kerb's section (y back from its front, z): its foot buried, its
    top front edge worn round in two steps; chipped, broken further back."""
    if chipped:
        corner = [(0.0, top - 0.07), (0.03, top - 0.04), (0.065, top)]
    else:
        corner = [(0.0, top - KERB_ROUND), (0.012, top - 0.012), (KERB_ROUND, top)]

    return [(0.0, KERB_FOOT)] + corner + [(KERB_DEPTH, top), (KERB_DEPTH, KERB_FOOT)]


def kerb_straight():
    m = common.Mesh("kerb_straight", outward=True)
    shapes.loft_x(m, [(0.0, kerb_profile()), (KERB_LENGTH, kerb_profile())], "chiluca")
    return m.make()


# How far the heaved kerb has turned on its back top edge, its front sunk.
HEAVE = math.radians(2.0)


def _heaved(profile):
    pivot_y, pivot_z = KERB_DEPTH, KERB_PROUD
    c, s = math.cos(HEAVE), math.sin(HEAVE)
    return [(pivot_y + (y - pivot_y) * c - (z - pivot_z) * s, pivot_z + (y - pivot_y) * s + (z - pivot_z) * c)
            for y, z in profile]


def kerb_heaved():
    """The subsidence variant: tipped toward the street on its back top edge
    (flush with the pavement still), a corner broken off where it sank."""
    m = common.Mesh("kerb_heaved", outward=True)
    chipped, whole = _heaved(kerb_profile(chipped=True)), _heaved(kerb_profile())
    shapes.loft_x(m, [(0.0, chipped), (0.18, chipped), (0.24, whole), (KERB_LENGTH, whole)], "chiluca")
    return m.make()


# The corner's legs, along each face from the plaza's corner (m).
CORNER_LEG = 0.6


def kerb_corner():
    """The kerb turning round the plaza's corner (outside, mitred): its legs
    run CORNER_LEG along each face from the corner at the origin, -X and -Y
    its street faces; the runs start where the legs end."""
    m = common.Mesh("kerb_corner", outward=True)
    profile = kerb_profile()
    rings = [[(d, CORNER_LEG, z) for d, z in profile],
             [(d, d, z) for d, z in profile],
             [(CORNER_LEG, d, z) for d, z in profile]]
    shapes.loft(m, rings, "chiluca")
    return m.make()


# At its ends the drop stands a hair under the kerbs it meets, so its ends'
# outlines have no three points in a line (their triangles keep an area).
DROP_EDGE = KERB_PROUD - 0.002


def drop_profile(top):
    """The drop's section at a kerb top height `top`: the kerb, then the
    ramp behind it rising to the pavement."""
    return [(0.0, KERB_FOOT), (0.0, top - KERB_ROUND), (0.012, top - 0.012), (KERB_ROUND, top),
            (KERB_DEPTH, top), (KERB_DEPTH + DROP_RAMP, KERB_PROUD), (KERB_DEPTH + DROP_RAMP, KERB_FOOT)]


def kerb_drop():
    """A crossing: the kerb falls to DROP_LOW over its middle DROP_FLAT, the
    pavement behind it dished down to meet it."""
    m = common.Mesh("kerb_drop", outward=True)
    ease = (DROP_LENGTH - DROP_FLAT) / 2
    sections = [(0.0, DROP_EDGE), (ease, DROP_LOW), (DROP_LENGTH - ease, DROP_LOW), (DROP_LENGTH, DROP_EDGE)]
    shapes.loft_x(m, [(x, drop_profile(top)) for x, top in sections], "chiluca")
    return m.make()


# Flush pieces

def frame(m, outer, inner, z0, z1, slot_name, pocket=None):
    """A solid frame between two rectangles (x0, y0, x1, y1) from z0 to z1;
    with `pocket` (a depth), the inner rectangle is a pocket that deep, its
    floor closed, instead of a hole through."""
    o = [(outer[0], outer[1]), (outer[2], outer[1]), (outer[2], outer[3]), (outer[0], outer[3])]
    i = [(inner[0], inner[1]), (inner[2], inner[1]), (inner[2], inner[3]), (inner[0], inner[3])]

    for k in range(4):
        j = (k + 1) % 4
        m.face([(*o[k], z1), (*o[j], z1), (*i[j], z1), (*i[k], z1)], slot_name)
        m.face([(*o[k], z0), (*o[j], z0), (*o[j], z1), (*o[k], z1)], slot_name)
        bottom = z1 - pocket if pocket is not None else z0
        m.face([(*i[k], bottom), (*i[j], bottom), (*i[j], z1), (*i[k], z1)], slot_name)

        if pocket is None:
            m.face([(*o[k], z0), (*o[j], z0), (*i[j], z0), (*i[k], z0)], slot_name)

    if pocket is not None:
        m.face([(*p, z0) for p in o], slot_name)
        m.face([(*p, z1 - pocket) for p in i], slot_name)


# The grate: its frame's width round the sump, the sump's depth, its bars.
GRATE_RIM = (0.15, 0.1)          # at the ends, at the sides
SUMP = 0.1
BARS = 4                         # along the gutter, as the water runs
BAR = (0.03, 0.04)               # across, deep


def gutter_grate():
    """An iron grate over a sump in a basalt gutter stone, laid before a
    kerb: the stone's top flush with the setts, the bars a little under it."""
    m = common.Mesh("gutter_grate", outward=True)
    ex, ey = GRATE_RIM
    inner = (ex, -GRATE_DEPTH + ey, GRATE_LENGTH - ex, -ey)
    frame(m, (0.0, -GRATE_DEPTH, GRATE_LENGTH, 0.0), inner, SKIRT, 0.0, "basalt", pocket=SUMP)
    gap = (inner[3] - inner[1] - BARS * BAR[0]) / (BARS + 1)

    for k in range(BARS):
        y = inner[1] + gap * (k + 1) + BAR[0] * k
        m.box((inner[0], y, -0.005 - BAR[1]), (inner[2], y + BAR[0], -0.005), "iron")

    return m.make()


# The band's slabs: three across it, as long as the piece; the joints
# between them V-grooves 2 cm deep and 4 cm across (a piece's ends each
# half of one).
SLAB_JOINT = 0.02


def band_profile(top=True):
    """The band's section (y, z): three slabs' tops bevelled down into the
    grooves between them and at the band's edges; `top` False is the floor
    of a groove across the band, every top at the grooves' depth."""
    half = BAND / 2
    j = SLAB_JOINT
    width = (BAND - 2 * j) / 3
    rim = 0.0 if top else -j
    points = [(-half, -j)]

    for k in range(3):
        a = -half + k * (width + j)
        b = a + width

        if k > 0:
            points.append((a, -j))

        points += [(a + j, rim), (b - j, rim), (b, -j)]

    # Down to the skirt under every point, so the ends close as strips.
    return points + [(y, SKIRT) for y, _ in reversed(points)]


def causeway_band():
    """The old causeway's stone: slabs of darker basalt three across a 3 m
    band, each piece's 3 m long, bedded flush with the setts, their joints
    cut into one solid (nothing stacked under them)."""
    m = common.Mesh("causeway_band", outward=True)
    low, whole = band_profile(top=False), band_profile()
    sections = [(0.0, low), (SLAB_JOINT, whole), (BAND - SLAB_JOINT, whole), (BAND, low)]
    shapes.loft_x(m, sections, "basalt", caps=False)
    half = len(low) // 2

    for x in (0.0, BAND):
        for i in range(half - 1):
            top_a, top_b = low[i], low[i + 1]
            m.face([(x, *top_a), (x, *top_b), (x, top_b[0], SKIRT), (x, top_a[0], SKIRT)], "basalt")

    return m.make()


# The tram: rail heads 7 cm, the flangeway 4 cm wide and deep inside each,
# their heads crowned a little down at the outer edge.
RAIL_HEAD = 0.07
FLANGEWAY = 0.04
CROWN = 0.003
RAILS = (-GAUGE / 2, GAUGE / 2)


def track_profile(lift=0.0):
    """The track's section (y, z) and each edge's slot: granite setts, the
    two rails' heads and flangeways steel; `lift` raises the heads (shimmed)."""
    g = GAUGE / 2
    out, inn = g + RAIL_HEAD / 2, g - RAIL_HEAD / 2
    lip = (-out, lift - CROWN)
    points = [(-STRIP_HALF, SKIRT), (-STRIP_HALF, 0.0)]
    slots = ["granite", "granite"]

    if lift:
        points += [(-out, 0.0)]
        slots += ["steel"]

    points += [lip, (-inn, lift), (-inn, -FLANGEWAY), (-inn + FLANGEWAY, -FLANGEWAY), (-inn + FLANGEWAY, 0.0),
               (inn - FLANGEWAY, 0.0), (inn - FLANGEWAY, -FLANGEWAY), (inn, -FLANGEWAY), (inn, lift), (out, lift - CROWN)]
    slots += ["steel", "steel", "steel", "granite", "granite", "granite", "steel", "steel", "steel"]

    if lift:
        points += [(out, 0.0)]
        slots += ["steel"]

    points += [(STRIP_HALF, 0.0), (STRIP_HALF, SKIRT)]
    slots += ["granite", "granite", "granite"]
    return points, slots


def tram_track():
    m = common.Mesh("tram_track", outward=True)
    profile, slots = track_profile()
    shapes.loft_x(m, [(0.0, profile), (TRACK_LENGTH, profile)], slots, cap_slot="granite")
    return m.make()


# The shims: the rails packed up a centimetre, the Company's brass bolts
# along their feet.
SHIM = 0.015
BOLTS_AT = (0.6, 1.5, 2.4, 3.3, 4.2)
SHIM_BOLT = (0.04, 0.012)


def tram_track_shimmed():
    """Subsidence: the ground fell away under the rails and they were packed
    up a centimetre, their feet bolted down again in brass."""
    m = common.Mesh("tram_track_shimmed", outward=True)
    profile, slots = track_profile(lift=SHIM)
    shapes.loft_x(m, [(0.0, profile), (TRACK_LENGTH, profile)], slots, cap_slot="granite")
    foot = GAUGE / 2 + RAIL_HEAD / 2 + 0.04

    for x in BOLTS_AT:
        for side in (-1, 1):
            y = side * foot
            m.box((x - SHIM_BOLT[0] / 2, y - SHIM_BOLT[0] / 2, 0.0), (x + SHIM_BOLT[0] / 2, y + SHIM_BOLT[0] / 2, SHIM_BOLT[1]),
                  "brass")

    return m.make()


def tram_track_curve():
    """The track round a quarter turn, radius 12 on its centreline (the
    ring's corners): sections laid radially through curve_centreline()."""
    m = common.Mesh("tram_track_curve", outward=True)
    profile, slots = track_profile()
    line = curve_centreline()
    rings = []

    for k, (cx, cy) in enumerate(line):
        phi = math.pi / 2 * k / (len(line) - 1)
        nx, ny = -math.sin(phi), math.cos(phi)       # toward the curve's centre: +Y at its start
        rings.append([(cx + y * nx, cy + y * ny, z) for y, z in profile])

    shapes.loft(m, rings, slots, cap_slot="granite")
    return m.make()


# The conductor rail: on insulated chairs 0.9 m off the centreline.
CHAIRS = 5
# Each part stands more than 3 cm over the one under it (gate.LAYER_GAP).
CHAIR = (0.14, 0.16, 0.04)
INSULATOR = (0.08, 0.08, 0.04)
CONDUCTOR = (0.05, 0.035)        # across, deep


def tram_conductor():
    """The seeped third rail for the transport that runs the ring: steel on
    iron chairs, the Company's brass insulators between, laid over a track."""
    m = common.Mesh("tram_conductor", outward=True)
    y = CONDUCTOR_OFF
    rail_bottom = CHAIR[2] + INSULATOR[2]

    for k in range(CHAIRS):
        x = TRACK_LENGTH * (k + 0.5) / CHAIRS
        m.box((x - CHAIR[0] / 2, y - CHAIR[1] / 2, 0.0), (x + CHAIR[0] / 2, y + CHAIR[1] / 2, CHAIR[2]), "iron")
        m.box((x - INSULATOR[0] / 2, y - INSULATOR[1] / 2, CHAIR[2]), (x + INSULATOR[0] / 2, y + INSULATOR[1] / 2, rail_bottom),
              "brass")

    m.box((0.0, y - CONDUCTOR[0] / 2, rail_bottom), (TRACK_LENGTH, y + CONDUCTOR[0] / 2, rail_bottom + CONDUCTOR[1]), "steel")
    return m.make()


# The hatch: an iron plate in a basalt frame, a blank plaque for the user's
# number, four bolt heads.
PLAQUE = (0.4, 0.25)
BOLT = (0.04, 0.012)


def hatch():
    """A Line 2 service hatch, 1.2 m square, centred on its origin, flush:
    one solid, its top the basalt frame, the iron plate and the plaque."""
    m = common.Mesh("hatch", outward=True)
    h, plate = HATCH / 2, HATCH / 2 - HATCH_FRAME
    px, py = PLAQUE[0] / 2, PLAQUE[1] / 2
    rings = [(h, h), (plate, plate), (px, py)]
    corners = lambda ax, ay, z: [(-ax, -ay, z), (ax, -ay, z), (ax, ay, z), (-ax, ay, z)]

    for (ax, ay), (bx, by), slot_name in ((rings[0], rings[1], "basalt"), (rings[1], rings[2], "iron")):
        o, i = corners(ax, ay, 0.0), corners(bx, by, 0.0)

        for k in range(4):
            j = (k + 1) % 4
            m.face([o[k], o[j], i[j], i[k]], slot_name)

    m.face(corners(px, py, 0.0), "sign")
    top, bottom = corners(h, h, 0.0), corners(h, h, SKIRT)

    for k in range(4):
        j = (k + 1) % 4
        m.face([bottom[k], bottom[j], top[j], top[k]], "basalt")

    m.face(bottom, "basalt")
    b = plate - 0.08

    for sx in (-1, 1):
        for sy in (-1, 1):
            m.box((sx * b - BOLT[0] / 2, sy * b - BOLT[0] / 2, 0.0), (sx * b + BOLT[0] / 2, sy * b + BOLT[0] / 2, BOLT[1]),
                  "iron")

    return m.make()


# The junction box (m): its body, the plinth under it, the lid's overhang.
BOX = (0.6, 0.35, 0.9)
PLINTH = (0.7, 0.45, 0.1)
LID = (0.02, 0.04)               # overhang, thickness
CONDUIT = (0.04, 6)              # radius, sides


def junction_box():
    """The Company's steel box on the pavement behind a kerb, its back to
    the plaza: conduit out of its back into the ground, a blank plate let
    into its front for the user's words, brass hinge knuckles at its edge."""
    m = common.Mesh("junction_box", outward=True)
    w, d, h = BOX
    pw, pd, ph = PLINTH
    m.box((-pw / 2, -pd / 2, 0.0), (pw / 2, pd / 2, ph), "basalt")
    # The body, its front face split round the plate.
    x0, x1, y0, y1, z0, z1 = -w / 2, w / 2, -d / 2, d / 2, ph, ph + h
    m.box((x0, y0, z0), (x1, y1, z1), "steel", skip=("-y",))
    plate = (-0.15, ph + 0.45, 0.15, ph + 0.65)
    outer = [(x0, z0), (x1, z0), (x1, z1), (x0, z1)]
    inner = [(plate[0], plate[1]), (plate[2], plate[1]), (plate[2], plate[3]), (plate[0], plate[3])]

    for k in range(4):
        j = (k + 1) % 4
        m.face([(outer[k][0], y0, outer[k][1]), (outer[j][0], y0, outer[j][1]), (inner[j][0], y0, inner[j][1]),
                (inner[k][0], y0, inner[k][1])], "steel")

    m.face([(x, y0, z) for x, z in inner], "sign")
    over, thick = LID
    m.box((x0 - over, y0 - over, z1), (x1 + over, y1 + over, z1 + thick), "steel")
    r, sides = CONDUIT

    for x in (-0.18, 0.18):
        m.tube((x, y1 + r, SKIRT), (x, y1 + r, z1 - 0.1), r, sides, "steel", caps=(True, True))

    for low in (z0 + 0.12, z0 + 0.62):
        m.tube((x0, y0, low), (x0, y0, low + 0.14), 0.018, 6, "brass", caps=(True, True))

    return m.make()


# The joints' close-ups (tools/eclipse/joints.py): each a scene of pieces
# placed as the dresser lays them, on stand-in setts at 0 and pavement at
# 0.2: {"eye", "target", "show": [(piece, (x, y, z), turn degrees)],
# "planes": [(x0, y0, x1, y1, z, colour)]}.
SETTS = (0.24, 0.23, 0.26)
FLAGS = (0.32, 0.30, 0.33)
STREET = (-12.0, -12.0, 12.0, 0.0, -0.002, SETTS)
PAVEMENT = (-12.0, KERB_DEPTH, 12.0, 12.0, KERB_PROUD - 0.002, FLAGS)


def _around(plane, hole):
    """A stand-in plane (x0, y0, x1, y1, z, colour) with a rectangle (x0,
    y0, x1, y1) left open, as four planes."""
    x0, y0, x1, y1, z, colour = plane
    hx0, hy0, hx1, hy1 = hole
    return [(x0, y0, x1, hy0, z, colour), (x0, hy1, x1, y1, z, colour),
            (x0, hy0, hx0, hy1, z, colour), (hx1, hy0, x1, hy1, z, colour)]


def _kerbs(x0, n):
    return [("kerb_straight", (x0 + KERB_LENGTH * k, 0.0, 0.0), 0) for k in range(n)]


JOINTS = {
    "01_kerb_setts": {"eye": (1.5, -1.6, 0.9), "target": (1.5, 0.15, 0.1), "show": _kerbs(-1.5, 4),
                      "planes": [STREET, PAVEMENT]},
    "01b_kerb_drop": {"eye": (1.5, -2.2, 1.2), "target": (1.5, 0.6, 0.05),
                      "show": _kerbs(-3.0, 2) + [("kerb_drop", (0.0, 0.0, 0.0), 0)] + _kerbs(3.0, 2),
                      "planes": [STREET, (-12.0, KERB_DEPTH, 0.0, 12.0, 0.198, FLAGS),
                                 (3.0, KERB_DEPTH, 12.0, 12.0, 0.198, FLAGS),
                                 (0.0, KERB_DEPTH + DROP_RAMP, 3.0, 12.0, 0.198, FLAGS)]},
    "01c_kerb_corner": {"eye": (-1.4, -1.4, 1.0), "target": (0.3, 0.3, 0.1),
                        "show": [("kerb_corner", (0.0, 0.0, 0.0), 0)]
                        + [("kerb_straight", (CORNER_LEG + KERB_LENGTH * k, 0.0, 0.0), 0) for k in range(2)]
                        + [("kerb_straight", (0.0, CORNER_LEG + KERB_LENGTH * (k + 1), 0.0), -90) for k in range(2)],
                        "planes": [(-12.0, -12.0, 12.0, 12.0, -0.002, SETTS),
                                   (KERB_DEPTH, KERB_DEPTH, 12.0, 12.0, 0.198, FLAGS)]},
    "01d_kerb_heaved": {"eye": (2.2, -1.4, 0.7), "target": (1.5, 0.15, 0.1),
                        "show": _kerbs(-1.5, 1) + [("kerb_heaved", (0.0, 0.0, 0.0), 0)] + _kerbs(1.5, 2),
                        "planes": [STREET, PAVEMENT]},
    "02_grate_kerb": {"eye": (0.8, -1.8, 1.1), "target": (0.75, -0.2, 0.0),
                      "show": _kerbs(-1.5, 3) + [("gutter_grate", (0.0, 0.0, 0.0), 0)],
                      "planes": _around(STREET, (0.0, -GRATE_DEPTH, GRATE_LENGTH, 0.0)) + [PAVEMENT]},
    "03_band_setts": {"eye": (-2.0, -3.5, 1.6), "target": (1.5, 0.0, 0.0),
                      "show": [("causeway_band", (0.0, 0.0, 0.0), 0), ("causeway_band", (BAND, 0.0, 0.0), 0)],
                      "planes": [(-12.0, -12.0, 12.0, 12.0, -0.002, SETTS)]},
    "04_track_setts": {"eye": (2.0, -3.0, 1.5), "target": (4.5, 0.0, 0.0),
                       "show": [("tram_track", (0.0, 0.0, 0.0), 0), ("tram_track", (TRACK_LENGTH, 0.0, 0.0), 0)],
                       "planes": [(-12.0, -12.0, 12.0, 12.0, -0.002, SETTS)]},
    "04b_curve_straight": {"eye": (-3.0, -3.0, 2.0), "target": (1.0, 0.5, 0.0),
                           "show": [("tram_track", (-TRACK_LENGTH, 0.0, 0.0), 0), ("tram_track_curve", (0.0, 0.0, 0.0), 0)],
                           "planes": [(-12.0, -12.0, 16.0, 16.0, -0.002, SETTS)]},
    "04c_shimmed": {"eye": (2.0, -2.2, 0.9), "target": (1.0, -0.7, 0.0),
                    "show": [("tram_track", (-TRACK_LENGTH, 0.0, 0.0), 0), ("tram_track_shimmed", (0.0, 0.0, 0.0), 0)],
                    "planes": [(-12.0, -12.0, 12.0, 12.0, -0.002, SETTS)]},
    "05_conductor_strip": {"eye": (1.2, 2.4, 0.8), "target": (2.0, 0.9, 0.0),
                           "show": [("tram_track", (0.0, 0.0, 0.0), 0), ("tram_conductor", (0.0, 0.0, 0.0), 0)],
                           "planes": [(-12.0, -12.0, 12.0, 12.0, -0.002, SETTS)]},
    "06_hatch_setts": {"eye": (1.2, -1.6, 1.4), "target": (0.0, 0.0, 0.0), "show": [("hatch", (0.0, 0.0, 0.0), 0)],
                       "planes": [(-12.0, -12.0, 12.0, 12.0, -0.002, FLAGS)]},
    "06b_junction_box": {"eye": (1.2, -1.8, 1.3), "target": (0.0, 0.0, 0.6),
                         "show": [("junction_box", (0.0, 0.0, 0.0), 0)],
                         "planes": [(-12.0, -12.0, 12.0, 12.0, -0.002, FLAGS)]},
}


# The vertex paint (tools/eclipse/weather.py): the small pieces on a 1 m
# grid, the curve on a coarser one (its sections are dense already).
WEATHER = {"coarse": {"kerb_straight": 1.0, "kerb_heaved": 1.0, "kerb_corner": 1.0, "kerb_drop": 1.0,
                      "gutter_grate": 1.0, "causeway_band": 1.5, "hatch": 1.0, "junction_box": 2.0,
                      "tram_conductor": 1.5, "tram_track": 1.5, "tram_track_shimmed": 1.5, "tram_track_curve": 6.0},
           "blendable": ["basalt", "chiluca", "granite"], "foot": ["chiluca", "basalt"]}


def build():
    common.reset()
    kerb_straight()
    kerb_heaved()
    kerb_corner()
    kerb_drop()
    gutter_grate()
    causeway_band()
    tram_track()
    tram_track_shimmed()
    tram_track_curve()
    tram_conductor()
    hatch()
    junction_box()


def main():
    build()
    common.export_piece(NAME, ATLAS, SLOTS, weather=WEATHER, out=common.ROOT / "assets" / "eclipse" / "kit",
                        sets_each=True)


if __name__ == "__main__":
    main()
