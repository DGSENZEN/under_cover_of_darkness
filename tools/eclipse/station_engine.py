"""The Light Company's engine at the Zócalo station's hall middle (docs/superpowers/specs/2026-10-31-station-machinery-
design.md, item 5; the patron's hall in the user's Deadlock frames; the user, Oct 31: "it looks like a toy instead of a
gigantic engine ... more things going on at the same time").

A machine run day and night: a stepped chiluca plinth the crowd can climb, a brass-railed walk round a tezontle housing
(the Mayan-Revival talud and tablero), gear trains turning behind its corbelled windows; four great flywheels sunk in
slots in the walk, each crank driving a piston up into its cylinder on the cornice; on the housing the dynamo's drum,
iron ribs over a core glowing the Company's blue, under a riveted dome where every cable run in the hall goes in through
Talavera bushings; a governor spinning on the crown under a brass spine into the coffers; four rows of big tubes rising
off the cornice and leaning out into the ceiling, gauge boards strapped across their feet. Where the tubes go and what
the dials read is left to interpretation (the user, Oct 31).

Two static pieces, each on its own atlas: `engine` (the stone: plinth, housing, cornice, railing) in station_engine and
`engine_works` (the iron and brass) with the moving pieces in station_engine_works. The moving pieces are stood and run
by Godot from station_engine.json: the gears and the governor spun by Clockwork, each flywheel with its conrod and
crosshead by EngineCrank (the linkage below: `crosshead_height`).

The kit's frame: the engine centred on (0, 0), standing on z = 0, its top at z = 5.0 (the hall's ceiling); it is placed
at the set frame's (0, 6, 0) with no turn, so a point (x, y, z) of the set frame is (x, -z, y - 6) here. Angles below
are the set frame's (from +x toward +z, as the cable runs are laid). A face's own axes are n (out from the middle) and
u (across it).

    Blender -b --factory-startup --python tools/eclipse/station_engine.py
"""

import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import common  # noqa: E402
from underground_shapes import bolt, box, pipe, smooth_object, turned  # noqa: E402

NAME = "station_engine"
WORKS = "station_engine_works"
ATLAS = 4096
SLOTS = ["chiluca", "tezontle", "talavera_cobalt", "iron", "brass", "copper"]
WORKS_SLOTS = ["iron", "brass", "copper", "steel", "talavera_cobalt", "glass_core", "glass_gauge", "glass_lamp",
               "glass_dial"]
CARDS = ("glass_dial",)
JSON = common.ROOT / "assets" / "eclipse" / "kit" / "station_engine.json"

TOP = 5.0
# The coffers' beams' soffit over the hall's floor (station_shell's coffer hung under the 11 m ceiling, 0.32 deep).
BEAMS = 5.0 - 0.01 - 0.32
# Where the hall's cable runs meet (the set frame's (0, 9.45, 0)), and where the trays end in the tubes.
TERMINAL = (0.0, 0.0, 3.45)
TRAY_ENDS = [(2.8, -1.6, 4.315), (-2.8, 1.6, 4.315)]
# The runs leave the dome through Talavera bushings (the two pairs a few degrees apart through one wider bushing): the
# set frame's heading, the bushing's scale.
BUSHINGS = [(-22.35, 1.3), (59.7, 1.0), (157.65, 1.3), (239.7, 1.0)]

# The plinth's steps, foot to deck: (circumradius, top, rise); the deck; the railing's apothem and height, its gates
# (on the faces toward the windows) this wide.
STEPS = [(4.6, 0.18, 0.18), (4.4, 0.36, 0.18), (4.15, 0.54, 0.18)]
DECK = 0.54
RAIL = 3.72
RAIL_HIGH = 1.0
GATE = 1.2
# The housing: the talud (its foot's and head's apothem, its head's height), the tablero's core and face (apothems),
# the cornice (its foot, its outer apothem, its top).
TALUD = (2.5, 2.38, 1.1)
CORE = 1.9
FACE = 2.3
CORNICE = (2.26, 2.62, 2.5)
# The windows, on the faces between the flywheels: each a corbelled opening (the Maya's false arch: jambs, then steps
# in to a flat head) in a chiluca frame FRAME wide.
WINDOW_ANGLES = [45.0, 135.0, 225.0, 315.0]
OPENING = [(0.0, 1.3), (-0.55, 1.3), (-0.55, 1.78), (-0.45, 1.78), (-0.45, 1.87), (-0.35, 1.87), (-0.35, 1.96),
           (-0.25, 1.96), (-0.25, 2.05), (0.0, 2.05)]
FRAME = 0.14
# The flywheels, on the faces toward the lanes and the stairs: the wheel's plane (n), its centre's height, its radius,
# half its rim's width; the crank (its throw, the conrod's length, the piston rod over the crosshead's pin); how far out
# of the wheel's plane the conrod swings; the slide bars (from z, to z); the cylinder's span (z) and radius.
CRANK_ANGLES = [0.0, 90.0, 180.0, 270.0]
WHEEL = (2.7, 1.05, 1.0, 0.08)
CRANK = (0.32, 0.95, 0.75)
CONROD_OUT = 0.27
SLIDES = (1.55, 2.36)
CYLINDER_SPAN = (2.32, 3.12)
CYLINDER_R = 0.24
# The dynamo: its glowing core (radius, from z, to z); the dome over it; the governor's seat.
CORE_GLOW = (1.85, 2.42, 3.14)
DOME = [(2.06, 3.06), (2.06, 3.14), (1.88, 3.3), (1.55, 3.5), (1.05, 3.66), (0.6, 3.76), (0.36, 3.8)]
GOVERNOR_AT = 3.94
# The brass ring in the floor: inner and outer radius, how far proud.
RING = (4.66, 4.78, 0.035)

# The tube rows: each the set frame's (x, z) of its top row's middle, in a coffer's recess clear of its beams and its
# fitting, its tubes (slot, radius) side by side along x there, ROW apart; their feet side by side across the cornice
# at FOOT_R, toward their tops.
ROW = 0.5
TUBES = [("brass", 0.2), ("brass", 0.24), ("copper", 0.18)]
BUNDLES = [
    ((2.4, 1.68), TUBES),
    ((-2.4, 2.99), TUBES),
    ((-2.4, -1.68), TUBES),
    ((2.4, -2.99), TUBES),
]
FOOT_R = 2.36
# Where a row stops rising straight and leans out to its top, and where it is straight again.
BEND = (3.45, 4.35)
# The gauge boards across the rows' feet (from n, to n) and their faces: (radius, height, across).
PLATE = (2.56, 2.68)
BOARD = (2.55, 3.38)
LENS = 0.075
# Each gauge's dial card this far out of its board, in front of its case's face (0.075), under its glass.
DIAL_AT = 0.088
GAUGE_CLUSTERS = [
    (0, [(0.17, 2.92, 0.0), (0.11, 3.16, -0.42), (0.11, 3.16, 0.42), (0.09, 2.82, -0.48), (0.09, 2.82, 0.48)]),
    (1, [(0.15, 2.9, -0.25), (0.13, 2.95, 0.25), (0.08, 3.18, 0.0), (0.08, 2.76, 0.52)]),
    (2, [(0.17, 2.92, 0.0), (0.11, 3.16, 0.42), (0.11, 3.16, -0.42), (0.09, 2.82, 0.48), (0.09, 2.82, -0.48)]),
    (3, [(0.15, 2.9, 0.25), (0.13, 2.95, -0.25), (0.08, 3.18, 0.0), (0.08, 2.76, -0.52)]),
]

# The clockwork: each piece's teeth, its root and tip radius; its rim's half thickness.
GEAR_SHAPES = {"gear_big": (28, 0.4, 0.46), "gear_mid": (19, 0.26, 0.32), "gear_small": (13, 0.165, 0.21)}
GEAR_HALF = 0.035

# The Company's crowned blade signs standing on the deck by the railing: the set frame's heading, how far out.
BLADES = [(22.5, 3.62), (202.5, 3.62)]


def _at(angle, r, z):
    """The set frame's heading `angle` (degrees), `r` out, `z` up: this frame's point."""
    a = math.radians(angle)
    return (r * math.cos(a), -r * math.sin(a), z)


def _from_set(x, z, y):
    """The set frame's (x, y over the hall's floor, z): this frame's point."""
    return (x, -z, y)


def _heading(angle):
    """The `towards` that leans a turned solid's axis out along the set frame's `angle`."""
    return math.radians(-angle) + math.pi / 2


def _axes(angle):
    a = math.radians(-angle)
    return (math.cos(a), math.sin(a)), (-math.sin(a), math.cos(a))


def _on_face(angle, n, u, z):
    (nx, ny), (ux, uy) = _axes(angle)
    return (n * nx + u * ux, n * ny + u * uy, z)


def _block(m, angle, n0, n1, u0, u1, z0, z1, slot, r=0.02):
    """A block on the face at the set frame's `angle`: from n0 to n1 out from the middle, u0 to u1 across it."""
    a = math.radians(-angle)
    c = _on_face(angle, (n0 + n1) / 2, (u0 + u1) / 2, (z0 + z1) / 2)
    hx, hy, hz = (n1 - n0) / 2, (u1 - u0) / 2, (z1 - z0) / 2
    box(m, (c[0] - hx, c[1] - hy, c[2] - hz), (c[0] + hx, c[1] + hy, c[2] + hz), slot, r=r, turn=(0.0, 0.0, a))


def _out(m, angle, n, u, z, profile, sides, slot):
    """A solid turned about the face's n through (n, u, z), its profile's heights measured out along n."""
    turned(m, profile, sides, slot, at=_on_face(angle, n, u, z), lean=math.pi / 2, towards=_heading(angle))


def _offset(half, w):
    """A left half outline (from its bottom middle round to its top middle, every corner square) moved `w` outward."""
    out = []
    for i, (u, z) in enumerate(half):
        normals = []
        for a, b in ((half[i - 1], half[i]) if i > 0 else (None, None), (half[i], half[i + 1]) if i + 1 < len(half)
                     else (None, None)):
            if a is not None:
                du, dz = b[0] - a[0], b[1] - a[1]
                length = math.hypot(du, dz)
                normals.append((-dz / length, du / length))
        ou, oz = sum(nn[0] for nn in normals), sum(nn[1] for nn in normals)
        out.append((u + w * ou, z + w * oz))
    return out


def _pierced(m, angle, outer, inner, n0, n1, slot):
    """A slab on the face at `angle`, from n0 to n1, between two outlines symmetric about u = 0 (each given as its
    left half, bottom middle round to top middle): one closed solid, its front and back each two polygons meeting on
    the middle line."""
    m.shell()
    right_o = [(-u, z) for u, z in outer]
    right_i = [(-u, z) for u, z in inner]
    left = outer + list(reversed(inner))
    right = list(reversed(right_o)) + right_i
    for poly in (left, right):
        m.face([_on_face(angle, n1, u, z) for u, z in poly], slot)
        m.face([_on_face(angle, n0, u, z) for u, z in reversed(poly)], slot)
    for loop, out in ((outer + list(reversed(right_o))[1:-1], True), (inner + list(reversed(right_i))[1:-1], False)):
        n = len(loop)
        for i in range(n):
            (ua, za), (ub, zb) = loop[i], loop[(i + 1) % n]
            q = [_on_face(angle, n0, ua, za), _on_face(angle, n0, ub, zb), _on_face(angle, n1, ub, zb),
                 _on_face(angle, n1, ua, za)]
            m.face(q if out else list(reversed(q)), slot)


def _ring(m, r0, r1, z0, z1, slot, sides=72):
    """A flat annulus about z, closed."""
    m.shell()
    ring = [(math.cos(2 * math.pi * k / sides), math.sin(2 * math.pi * k / sides)) for k in range(sides)]
    for (ca, sa), (cb, sb) in zip(ring, ring[1:] + ring[:1]):
        a0, a1 = (r0 * ca, r0 * sa), (r1 * ca, r1 * sa)
        b0, b1 = (r0 * cb, r0 * sb), (r1 * cb, r1 * sb)
        m.face([(*a0, z1), (*a1, z1), (*b1, z1), (*b0, z1)], slot)
        m.face([(*b0, z0), (*b1, z0), (*a1, z0), (*a0, z0)], slot)
        m.face([(*a1, z0), (*b1, z0), (*b1, z1), (*a1, z1)], slot)
        m.face([(*b0, z0), (*a0, z0), (*a0, z1), (*b0, z1)], slot)


def _flat_frame(m, angle, n0, n1, u0, u1, w, z0, z1, slot):
    """A flat rectangular frame on the deck (n0..n1 by u0..u1 outside, `w` wide), closed."""
    m.shell()
    outer = [(n0, u0), (n1, u0), (n1, u1), (n0, u1)]
    inner = [(n0 + w, u0 + w), (n1 - w, u0 + w), (n1 - w, u1 - w), (n0 + w, u1 - w)]
    for i in range(4):
        j = (i + 1) % 4
        (an, au), (bn, bu) = outer[i], outer[j]
        (cn, cu), (dn, du) = inner[i], inner[j]
        m.face([_on_face(angle, an, au, z1), _on_face(angle, bn, bu, z1), _on_face(angle, dn, du, z1),
                _on_face(angle, cn, cu, z1)], slot)
        m.face([_on_face(angle, cn, cu, z0), _on_face(angle, dn, du, z0), _on_face(angle, bn, bu, z0),
                _on_face(angle, an, au, z0)], slot)
        m.face([_on_face(angle, an, au, z0), _on_face(angle, bn, bu, z0), _on_face(angle, bn, bu, z1),
                _on_face(angle, an, au, z1)], slot)
        m.face([_on_face(angle, dn, du, z0), _on_face(angle, cn, cu, z0), _on_face(angle, cn, cu, z1),
                _on_face(angle, dn, du, z1)], slot)


def _octagon(r_apothem):
    """A turned octagon's circumradius from its apothem (its flats facing the set frame's axes)."""
    return r_apothem / math.cos(math.pi / 8)


TWIST = math.pi / 8


def _wheel(angle):
    """A flywheel's centre, this frame's."""
    n, z, _, _ = WHEEL
    return _on_face(angle, n, 0.0, z)


def crosshead_height(t):
    """The crosshead's pin's height when its crank has turned `t` (radians, from across the face, rising first)."""
    rho, length, _ = CRANK
    return WHEEL[1] + rho * math.sin(t) + math.sqrt(length * length - (rho * math.cos(t)) ** 2)


# ---- The stone ----

def _plinth(m):
    """The stepped plinth in one stone, the brass ring in the floor round it."""
    rings = [(STEPS[0][0], 0.0), (STEPS[0][0], STEPS[0][1])]
    for (r, top, _) in STEPS[1:]:
        rings += [(r, rings[-1][1]), (r, top)]
    turned(m, rings, 8, "chiluca", twist=TWIST)
    _ring(m, RING[0], RING[1], 0.0, RING[2], "brass")


def _railing(m):
    """Iron posts at the deck's corners, between them and at the gates, two brass rails through them."""
    corners = [45.0 * k + 22.5 for k in range(8)]
    rc = _octagon(RAIL)
    tops = (DECK + RAIL_HIGH - 0.04, DECK + 0.5)

    def post(p):
        turned(m, [(0.04, DECK - 0.04), (0.04, DECK + RAIL_HIGH), (0.06, DECK + RAIL_HIGH + 0.03),
                   (0.03, DECK + RAIL_HIGH + 0.08)], 8, "iron", at=(p[0], p[1], 0.0))

    for k in range(8):
        a, b = _at(corners[k], rc, 0.0), _at(corners[(k + 1) % 8], rc, 0.0)
        side = corners[k] + 22.5
        post(a)
        if side in WINDOW_ANGLES:
            # (A gate in the middle of the side: the rails stop at its posts.)
            g0, g1 = _on_face(side, RAIL, GATE / 2, 0.0), _on_face(side, RAIL, -GATE / 2, 0.0)
            near_a, near_b = (g0, g1) if math.dist(g0[:2], a[:2]) < math.dist(g1[:2], a[:2]) else (g1, g0)
            post(near_a)
            post(near_b)
            for h in tops:
                pipe(m, [(a[0], a[1], h), (near_a[0], near_a[1], h)], 0.025, 8, "brass")
                pipe(m, [(near_b[0], near_b[1], h), (b[0], b[1], h)], 0.025, 8, "brass")
        else:
            post(_on_face(side, RAIL, 0.0, 0.0))
            for h in tops:
                pipe(m, [(a[0], a[1], h), (b[0], b[1], h)], 0.025, 8, "brass")


def _housing(m):
    """The talud and the tablero's core in one stone; on each window face a tezontle wall pierced by a corbelled
    opening in its chiluca frame, two conduits up it with their valves; on each flywheel face a wall with a panel of
    the Company's Talavera; a stepped pilaster at each corner; the cornice; the flywheels' slots through the deck."""
    t_foot, t_head, t_top = TALUD
    turned(m, [(_octagon(t_foot), DECK - 0.04), (_octagon(t_head), t_top), (_octagon(CORE), t_top),
               (_octagon(CORE), 2.38)], 8, "tezontle", twist=TWIST)
    edge = FACE * math.tan(math.pi / 8) - 0.04
    wall = [(0.0, 1.06), (-edge, 1.06), (-edge, 2.3), (0.0, 2.3)]
    for k in range(8):
        angle = 45.0 * k
        if angle in WINDOW_ANGLES:
            _pierced(m, angle, wall, _offset(OPENING, FRAME - 0.04), CORE - 0.04, FACE, "tezontle")
            _pierced(m, angle, _offset(OPENING, FRAME), OPENING, CORE - 0.08, FACE + 0.06, "chiluca")
            for side in (-1, 1):
                u = side * 0.82
                pipe(m, [_on_face(angle, FACE + 0.1, u, 1.06), _on_face(angle, FACE + 0.1, u, 2.34)], 0.045, 10,
                     "copper")
                _out(m, angle, FACE + 0.1, u, 1.72, [(0.02, 0.0), (0.02, 0.1)], 6, "iron")
                rim = [_on_face(angle, FACE + 0.2, u + 0.08 * math.cos(2 * math.pi * j / 16),
                                1.72 + 0.08 * math.sin(2 * math.pi * j / 16)) for j in range(16)]
                pipe(m, rim, 0.014, 6, "brass", closed=True)
        else:
            _block(m, angle, CORE - 0.04, FACE, -edge, edge, 1.02, 2.34, "tezontle")
            _block(m, angle, FACE - 0.04, FACE + 0.04, -0.65, 0.65, 1.5, 2.12, "talavera_cobalt", r=0.01)
    for k in range(8):
        corner = 45.0 * k + 22.5
        rc = _octagon(FACE)
        _block(m, corner, rc - 0.2, rc + 0.06, -0.13, 0.13, 0.98, 2.4, "chiluca")
        _block(m, corner, rc - 0.16, rc + 0.12, -0.09, 0.09, 1.2, 2.0, "chiluca", r=0.015)
    c0, c1, ctop = CORNICE
    turned(m, [(_octagon(2.25), c0), (_octagon(2.5), c0 + 0.1), (_octagon(2.5), c0 + 0.15), (_octagon(c1), 2.44),
               (_octagon(c1), ctop)], 8, "chiluca", twist=TWIST)
    for angle in CRANK_ANGLES:
        n = WHEEL[0]
        _flat_frame(m, angle, n - 0.22, n + 0.22, -1.03, 1.03, 0.08, DECK - 0.08, DECK + 0.04, "iron")


def engine(m):
    _plinth(m)
    _railing(m)
    _housing(m)


# ---- The works ----

def _drum(m):
    """The dynamo's core glowing behind its iron ribs, the rings that hold them riveted, copper belts round it; the
    dome over it with brass straps, the runs going into it through Talavera bushings; the governor's seat; the spine
    from the governor up into the beam over the middle."""
    r, z0, z1 = CORE_GLOW
    turned(m, [(r, z0), (r, z1)], 32, "glass_core")
    _ring(m, 1.6, 2.02, 2.46, 2.6, "iron", sides=48)
    _ring(m, 1.5, 2.02, 2.96, 3.1, "iron", sides=48)
    for k in range(24):
        _block(m, 15.0 * k + 7.5, 1.82, 1.98, -0.05, 0.05, 2.56, 3.0, "iron", r=0.015)
    for h in (2.68, 2.88):
        pipe(m, [(math.cos(2 * math.pi * k / 48) * 2.0, math.sin(2 * math.pi * k / 48) * 2.0, h) for k in range(48)],
             0.035, 8, "copper", closed=True)
    for k in range(32):
        a = 2 * math.pi * (k + 0.5) / 32
        bolt(m, 1.76 * math.cos(a), 1.76 * math.sin(a), 3.1)
    turned(m, DOME, 32, "iron")
    for k in range(8):
        a = math.radians(45.0 * k + 22.5)
        pipe(m, [((rr + 0.015) * math.cos(a), (rr + 0.015) * math.sin(a), z) for rr, z in DOME[1:]], 0.03, 8,
             "brass")
    for heading, scale in BUSHINGS:
        sheds = [(0.15, 0.0), (0.15, 0.06), (0.2, 0.08), (0.2, 0.12), (0.15, 0.14), (0.15, 0.2), (0.2, 0.22),
                 (0.2, 0.26), (0.15, 0.28), (0.15, 0.34)]
        turned(m, [(rr * scale, z) for rr, z in sheds], 16, "talavera_cobalt", at=_at(heading, 1.74, 3.3),
               lean=math.radians(97.0), towards=_heading(heading))
    turned(m, [(0.36, 3.76), (0.3, 3.84), (0.2, 3.9), (0.2, GOVERNOR_AT)], 24, "brass")
    turned(m, [(0.22, 4.5), (0.22, 4.56), (0.5, BEAMS - 0.05), (0.5, BEAMS + 0.03)], 24, "brass")


def _cranks(m):
    """At each flywheel: the axle out of a boss in the wall to the wheel's hub, its bearing on a pedestal; the cylinder
    on the cornice on its bracket, flanged, its head bolted, a steam pipe from its head into the dome; the slide bars
    hung under it, braced to the deck."""
    n, wz, _, _ = WHEEL
    lo, hi = CYLINDER_SPAN
    cn = n + CONROD_OUT
    s0, s1 = SLIDES
    for angle in CRANK_ANGLES:
        _out(m, angle, FACE - 0.04, 0.0, wz, [(0.3, 0.0), (0.3, 0.1), (0.2, 0.14), (0.2, 0.2)], 16, "iron")
        _out(m, angle, FACE + 0.1, 0.0, wz, [(0.09, 0.0), (0.09, n - FACE - 0.1)], 12, "steel")
        _block(m, angle, 2.4, 2.58, -0.22, 0.22, DECK - 0.08, wz - 0.07, "iron")
        _out(m, angle, 2.36, 0.0, wz, [(0.16, 0.0), (0.16, 0.16)], 16, "brass")
        c = _on_face(angle, cn, 0.0, 0.0)
        turned(m, [(0.2, lo - 0.02), (CYLINDER_R + 0.03, lo), (CYLINDER_R + 0.03, lo + 0.08), (CYLINDER_R, lo + 0.1),
                   (CYLINDER_R, hi - 0.12), (CYLINDER_R + 0.04, hi - 0.1), (CYLINDER_R + 0.04, hi - 0.02),
                   (0.2, hi - 0.02), (0.2, hi + 0.04)], 20, "iron", at=(c[0], c[1], 0.0))
        for j in range(8):
            a = 2 * math.pi * (j + 0.5) / 8
            bolt(m, c[0] + 0.24 * math.cos(a), c[1] + 0.24 * math.sin(a), hi - 0.02, r=0.022)
        for z in (lo + 0.3, lo + 0.55):
            pipe(m, [(c[0] + (CYLINDER_R + 0.005) * math.cos(2 * math.pi * j / 20),
                      c[1] + (CYLINDER_R + 0.005) * math.sin(2 * math.pi * j / 20), z) for j in range(20)],
                 0.02, 6, "brass", closed=True)
        _block(m, angle, 2.56, cn - 0.1, -0.12, 0.12, CORNICE[2] + 0.06, CORNICE[2] + 0.26, "iron")
        pipe(m, [_on_face(angle, cn, 0.0, hi + 0.02), _on_face(angle, cn, 0.0, hi + 0.14),
                 _on_face(angle, cn - 0.12, 0.0, hi + 0.22), _on_face(angle, 2.3, 0.0, hi + 0.22),
                 _on_face(angle, 1.7, 0.0, 3.36)], 0.055, 10, "copper")
        for side in (-1, 1):
            _block(m, angle, cn - 0.03, cn + 0.03, side * 0.21, side * 0.25, s0, s1, "steel", r=0.01)
            pipe(m, [_on_face(angle, cn + 0.02, side * 0.23, s0 + 0.04),
                     _on_face(angle, cn + 0.4, side * 0.36, DECK - 0.04)], 0.03, 8, "iron")


def bundle_tops():
    """Each row's top middle, this frame's (x, y)."""
    return [(x, -z) for (x, z), _ in BUNDLES]


def _bundle_angle(k):
    (x, z), _ = BUNDLES[k]
    return math.degrees(math.atan2(z, x))


def _tube_lines(k):
    """Each tube of a row, foot to top, this frame's points: its feet side by side across the cornice, its tops side
    by side along x, the two rows in the same order."""
    (x, z), tubes = BUNDLES[k]
    angle = _bundle_angle(k)
    _, (ux, _) = _axes(angle)
    sign = 1.0 if ux >= 0.0 else -1.0
    b0, b1 = BEND
    lines = []
    for j, (slot, r) in enumerate(tubes):
        off = (j - (len(tubes) - 1) / 2) * ROW
        foot = _on_face(angle, FOOT_R, sign * off, CORNICE[2] - 0.04)
        top = _from_set(x + off, z, TOP - 0.04)
        line = [foot, (foot[0], foot[1], b0)]
        for i in range(1, 6):
            t = i / 6
            s = t * t * (3 - 2 * t)
            line.append((foot[0] + (top[0] - foot[0]) * s, foot[1] + (top[1] - foot[1]) * s, b0 + (b1 - b0) * t))
        line += [(top[0], top[1], b1), top]
        lines.append((slot, r, line))
    return lines


def _bundles(m):
    """Each row's tubes, iron bands round them where they rise straight, a brass plate where they enter the coffers;
    an iron box round the two rows the trays end in."""
    for k, ((x, z), _) in enumerate(BUNDLES):
        for slot, r, line in _tube_lines(k):
            pipe(m, line, r, 16, slot)
            for (cx, cy, _), h in ((line[0], 2.75), (line[0], 3.45), (line[-1], 4.6)):
                pipe(m, [(cx + (r + 0.014) * math.cos(2 * math.pi * j / 16),
                          cy + (r + 0.014) * math.sin(2 * math.pi * j / 16), h) for j in range(16)],
                     0.026, 6, "iron", closed=True)
        cx, cy, _ = _from_set(x, z, 0.0)
        box(m, (cx - 0.85, cy - 0.33, TOP - 0.14), (cx + 0.85, cy + 0.33, TOP), "brass", r=0.02)
    for (x, z), _ in (BUNDLES[0], BUNDLES[2]):
        cx, cy, _ = _from_set(x, z, 0.0)
        box(m, (cx - 0.88, cy - 0.34, 4.22), (cx + 0.88, cy + 0.34, 4.45), "iron", r=0.02)


def gauges():
    """Each board's faces: (centre of its lens, the way it looks, its radius), this frame's."""
    out = []
    for k, faces in GAUGE_CLUSTERS:
        angle = _bundle_angle(k)
        (nx, ny), _ = _axes(angle)
        out.append([(_on_face(angle, PLATE[1] + 0.06 + LENS, side, z), (nx, ny, 0.0), r) for r, z, side in faces])
    return out


GAUGES = gauges()


def _gauges(m):
    """A brass board strapped across each row's feet: a gauge per face on it (an iron case, a glass lens, a brass
    rim), a row of indicator lamps along its head, a lever at its side."""
    for (k, faces), cluster in zip(GAUGE_CLUSTERS, GAUGES):
        angle = _bundle_angle(k)
        z0, z1 = BOARD
        _block(m, angle, PLATE[0], PLATE[1], -0.72, 0.72, z0, z1, "brass", r=0.02)
        for (r, _, _), (at, n, _) in zip(faces, cluster):
            base = tuple(at[i] - n[i] * (0.06 + LENS) for i in range(3))
            towards = _heading(angle)
            turned(m, [(r + 0.035, -0.045), (r + 0.035, 0.06), (r + 0.01, 0.075)], 24, "iron", at=base,
                   lean=math.pi / 2, towards=towards)
            turned(m, [(r, 0.035), (r, 0.065), (r * 0.7, 0.06 + LENS * 0.8), (r * 0.25, 0.06 + LENS)], 24,
                   "glass_gauge", at=base, lean=math.pi / 2, towards=towards)
            rim = [tuple(base[i] + n[i] * 0.073 + (r + 0.012) * (math.cos(2 * math.pi * j / 32) * (0, 0, 1)[i] +
                         math.sin(2 * math.pi * j / 32) * (-n[1], n[0], 0.0)[i]) for i in range(3))
                   for j in range(32)]
            pipe(m, rim, 0.016, 8, "brass", closed=True)
            # (Its dial under the glass: a card of its own, drawn and its needle moved by Godot's engine_dial shader.)
            c = [base[i] + n[i] * DIAL_AT for i in range(3)]
            right, up = (-n[1], n[0], 0.0), (0.0, 0.0, 1.0)
            m.card([tuple(c[i] + (sx * right[i] + sy * up[i]) * r for i in range(3))
                    for sx, sy in ((-1, -1), (1, -1), (1, 1), (-1, 1))], "glass_dial")
        for j in range(5):
            u = -0.48 + 0.24 * j
            _out(m, angle, PLATE[1] - 0.04, u, z1 - 0.07, [(0.03, 0.0), (0.03, 0.08), (0.02, 0.1)], 10, "iron")
            _out(m, angle, PLATE[1] + 0.06, u, z1 - 0.07, [(0.024, 0.0), (0.02, 0.03), (0.008, 0.042)], 10,
                 "glass_lamp")
        side = 0.66 if k % 2 == 0 else -0.66
        _out(m, angle, PLATE[1] - 0.04, side, z0 + 0.12, [(0.045, 0.0), (0.045, 0.1)], 12, "iron")
        pipe(m, [_on_face(angle, PLATE[1] + 0.04, side, z0 + 0.12),
                 _on_face(angle, PLATE[1] + 0.2, side, z0 + 0.36)], 0.016, 8, "steel")
        turned(m, [(0.012, -0.04), (0.04, -0.02), (0.04, 0.02), (0.012, 0.04)], 10, "brass",
               at=_on_face(angle, PLATE[1] + 0.2, side, z0 + 0.36))


def engine_works(m):
    _drum(m)
    _cranks(m)
    _bundles(m)
    _gauges(m)


# ---- The moving pieces ----

def _gear(teeth, root, tip):
    def build(m):
        # (Its toothed rim, one solid: each tooth a flat-topped trapezoid off the root circle.)
        m.shell()
        rim = []
        step = 2 * math.pi / teeth
        for t in range(teeth):
            a = step * t
            for f, r in ((0.0, root), (0.18, root), (0.32, tip), (0.68, tip), (0.82, root)):
                rim.append((r, a + f * step))
        inner = root - 0.07
        outer = [(r * math.cos(a), r * math.sin(a)) for r, a in rim]
        hole = [(inner * math.cos(a), inner * math.sin(a)) for _, a in rim]
        h = GEAR_HALF
        n = len(rim)
        for i in range(n):
            j = (i + 1) % n
            (ox0, oy0), (ox1, oy1) = outer[i], outer[j]
            (ix0, iy0), (ix1, iy1) = hole[i], hole[j]
            m.face([(ix0, iy0, h), (ox0, oy0, h), (ox1, oy1, h), (ix1, iy1, h)], "brass")
            m.face([(ix1, iy1, -h), (ox1, oy1, -h), (ox0, oy0, -h), (ix0, iy0, -h)], "brass")
            m.face([(ox0, oy0, -h), (ox1, oy1, -h), (ox1, oy1, h), (ox0, oy0, h)], "brass")
            m.face([(ix1, iy1, -h), (ix0, iy0, -h), (ix0, iy0, h), (ix1, iy1, h)], "brass")
        turned(m, [(0.06, -0.075), (0.06, 0.075)], 16, "iron")
        for s in range(5):
            a = 2 * math.pi * s / 5
            pipe(m, [(0.04 * math.cos(a), 0.04 * math.sin(a), 0.0),
                     ((inner + 0.03) * math.cos(a), (inner + 0.03) * math.sin(a), 0.0)], 0.022, 8, "brass")
    return build


GEARS = list(GEAR_SHAPES)


def gear_spots():
    """Where each gear turns: (piece, this frame's centre, the set frame's heading it faces, turns a second). A train
    of three in each window, meshing, each a layer further out."""
    _, broot, _ = GEAR_SHAPES["gear_big"]
    _, mroot, mtip = GEAR_SHAPES["gear_mid"]
    _, _, stip = GEAR_SHAPES["gear_small"]
    spots = []
    for k, angle in enumerate(WINDOW_ANGLES):
        hand = 1 if k % 2 == 0 else -1
        big = (-0.25 * hand, 1.6)
        a = math.radians(20.0)
        mid = (big[0] + hand * (broot + mtip - 0.012) * math.cos(a), big[1] + (broot + mtip - 0.012) * math.sin(a))
        b = math.radians(-80.0)
        small = (mid[0] + hand * (mroot + stip - 0.012) * math.cos(b), mid[1] + (mroot + stip - 0.012) * math.sin(b))
        turns = 0.06 * hand
        for piece, (u, z), n, spin in (("gear_big", big, CORE + 0.1, turns),
                                       ("gear_mid", mid, CORE + 0.18, -turns * 28 / 19),
                                       ("gear_small", small, CORE + 0.26, turns * 28 / 13)):
            spots.append((piece, _on_face(angle, n, u, z), angle, spin))
    return spots


def flywheel(m):
    """A flywheel about its z: its heavy rim with a steel tyre, six spokes, its hub; the crank's web and pin on its
    outer face (+z), the pin at the crank's throw along +x."""
    _, _, r, half = WHEEL
    rho = CRANK[0]
    _ring(m, r - 0.16, r, -half, half, "iron", sides=48)
    _ring(m, r - 0.04, r + 0.05, -half + 0.04, half - 0.04, "steel", sides=48)
    turned(m, [(0.16, -0.09), (0.16, 0.09)], 16, "iron")
    for s in range(6):
        a = 2 * math.pi * s / 6 + math.pi / 6
        pipe(m, [(0.1 * math.cos(a), 0.1 * math.sin(a), 0.0),
                 ((r - 0.14) * math.cos(a), (r - 0.14) * math.sin(a), 0.0)], 0.045, 8, "iron")
    box(m, (-0.18, -0.09, 0.13), (rho + 0.1, 0.09, 0.21), "iron", r=0.02)
    turned(m, [(0.05, 0.17), (0.05, 0.34)], 12, "steel", at=(rho, 0.0, 0.0))


def conrod(m):
    """The connecting rod along +z from the crank's pin (at the origin) to the crosshead's pin, each eye's axis along
    y."""
    length = CRANK[1]
    for z in (0.0, length):
        turned(m, [(0.075, -0.065), (0.075, 0.065)], 16, "steel", at=(0.0, 0.0, z), lean=math.pi / 2, towards=0.0)
    box(m, (-0.035, -0.025, 0.04), (0.035, 0.025, length - 0.04), "steel", r=0.012)


def crosshead(m):
    """The crosshead about its pin (the origin, along y): its block between the slide bars, the piston rod up from it
    (its head in the cylinder)."""
    box(m, (-0.2, -0.05, -0.07), (0.2, 0.05, 0.07), "iron", r=0.015)
    turned(m, [(0.04, -0.1), (0.04, 0.1)], 12, "steel", lean=math.pi / 2, towards=0.0)
    turned(m, [(0.045, 0.02), (0.045, CRANK[2])], 12, "steel")


def governor(m):
    """The governor about its z: its shaft, its bell, two arms swinging its brass balls out, the links down to its
    sleeve."""
    turned(m, [(0.035, -0.04), (0.035, 0.56)], 12, "steel")
    turned(m, [(0.08, 0.5), (0.12, 0.55), (0.12, 0.58), (0.05, 0.64)], 16, "brass")
    turned(m, [(0.075, 0.12), (0.075, 0.2)], 16, "brass")
    for side in (-1, 1):
        ball = (side * 0.32, 0.0, 0.3)
        pipe(m, [(side * 0.06, 0.0, 0.53), ball], 0.02, 8, "steel")
        pipe(m, [(side * 0.05, 0.0, 0.18), (side * 0.19, 0.0, 0.42)], 0.016, 8, "steel")
        turned(m, [(0.03, -0.1), (0.08, -0.07), (0.1, 0.0), (0.08, 0.07), (0.03, 0.1)], 16, "brass", at=ball)


def cranks():
    """Each flywheel: (the set frame's heading, its centre (this frame), turns a second, its crank's start)."""
    return [(angle, _wheel(angle), 0.25, math.pi / 2 * k) for k, angle in enumerate(CRANK_ANGLES)]


CRANKS = cranks()

STATIC = ["engine", "engine_works"]
MOVING = GEARS + ["flywheel", "conrod", "crosshead", "governor"]
BASE_PIECES = [("engine", engine)]
WORKS_PIECES = [("engine_works", engine_works)] + [(n, _gear(*GEAR_SHAPES[n])) for n in GEARS] + \
    [("flywheel", flywheel), ("conrod", conrod), ("crosshead", crosshead), ("governor", governor)]
PIECES = BASE_PIECES + WORKS_PIECES

BUDGET = {"engine": 30000, "engine_works": 70000, "gear_big": 4000, "gear_mid": 3000, "gear_small": 3000,
          "flywheel": 6000, "conrod": 1000, "crosshead": 1000, "governor": 3000}
SLIVER = {n: 0.004 for n, _ in PIECES}


def json_data():
    """In the set frame (the engine at (0, 6, 0)): the gears' spots (piece, x, y, z, the heading their faces look along
    in degrees, turns a second), the cranks' (the wheel's centre, heading, turns, start) and their linkage, the
    governor's, the blade signs'; what it breathes out of (each cylinder's head, by crank, and the dome's crown)."""

    def at_set(p):
        return {"x": p[0], "y": p[2] + 6.0, "z": -p[1]}

    gears = [dict(piece=p, heading=angle, turns=turns, **at_set(at)) for p, at, angle, turns in gear_spots()]
    crank = [dict(heading=angle, turns=turns, start=start, **at_set(at)) for angle, at, turns, start in CRANKS]
    blades = [dict(heading=angle, **at_set(_at(angle, r, DECK))) for angle, r in BLADES]
    heads = [at_set(_on_face(angle, WHEEL[0] + CONROD_OUT, 0.0, CYLINDER_SPAN[1] + 0.04)) for angle in CRANK_ANGLES]
    return {
        "gears": gears, "cranks": crank, "blades": blades,
        "linkage": {"throw": CRANK[0], "conrod": CRANK[1], "rod": CRANK[2], "out": CONROD_OUT},
        "governor": dict(turns=0.7, **at_set((0.0, 0.0, GOVERNOR_AT))),
        "heads": heads,
        "dome": at_set((0.0, 0.0, DOME[-1][1])),
    }


def write_json():
    """json_data() into the kit's station_engine.json."""
    import json

    JSON.write_text(json.dumps(json_data(), indent=1))


def _make(pieces):
    for name, f in pieces:
        smooth_object(name, f)


def build():
    """Every piece into one scene (for the kit's tests)."""
    common.reset()
    _make(PIECES)


def main():
    write_json()
    common.reset()
    _make(BASE_PIECES)
    common.export_piece(NAME, ATLAS, SLOTS, out=common.ROOT / "assets" / "eclipse" / "kit", sets_each=True,
                        budget=BUDGET["engine"], sliver=0.004, pack_margin=0.0015)
    common.reset()
    _make(WORKS_PIECES)
    common.export_piece(WORKS, ATLAS, WORKS_SLOTS, out=common.ROOT / "assets" / "eclipse" / "kit", sets_each=True,
                        cards=CARDS, budget=max(BUDGET.values()), sliver=0.004, pack_margin=0.0015)


if __name__ == "__main__":
    main()
