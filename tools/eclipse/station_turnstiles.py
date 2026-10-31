"""The Zócalo station's turnstile banks (docs/superpowers/specs/2026-10-27-metro-station-design.md; plan
docs/superpowers/plans/2026-10-30-metro-station.md, Task 8): two banks across the ticket hall at x -14 and x 14, the
paid zone between them.

The Light Company drew the bank: chunky iron cabinets on tezontle, a brass band round each, their tops stepped in twice
(the Mayan-Revival setbacks) under a brass fare box with its slot and the Company's tally dial (its face the user's). On
each cabinet's entry end the Company's ward eye, an obsidian lens in a brass bezel: the turnstiles count who passes. A
tripod of brass arms turns in each lane. A stepped chiluca pylon over each outer cabinet, a blank plaque on both faces
(the user's words) and a ward eye near its crown. From the outer cabinets to the hall's walls a railing: chiluca newels
with stepped caps on a tezontle curb, a brass handrail on an iron bar, a stepped fret in iron between them, open to see
through; a staff gate in one bay, chained shut.

The west bank's north half (the plan's `jammed_turnstiles`, the hall's z -4…0) was fused open by the surge on the
Eclipse's first night: its cabinets blackened, their arms melted and hanging, their ward eyes blown out of their bezels,
and nobody has paid there since. The people leave the dead's fare on the dead slots instead (coins, a saint's card,
marigolds in the arms, a candle). The Company patched the bank's other half with its own planks.

Maps/metro_station_dressing.gd stands them in the hall and turns the working arms.

Frames (Blender: x along the bank, from wall to wall; y across it, the walk, the paid side at +y; z up): a bank centred
on x = 0 (the hall's z = 0) and y = 0, standing on the floor at z = 0. The rotor's origin is its hub, on its axis.

    Blender -b --factory-startup --python tools/eclipse/station_turnstiles.py
"""

import math
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from mathutils import Matrix, Vector  # noqa: E402

import common  # noqa: E402
import underground_shapes  # noqa: E402
from underground_shapes import box, pipe, smooth_object, stud, turned  # noqa: E402

NAME = "station_turnstiles"
ATLAS = 4096
SLOTS = ["iron", "brass", "tezontle", "chiluca", "obsidian", "sign", "leather_black", "scorched", "brass_burnt",
         "chiluca_scorched", "hollow", "wood", "copper", "silver", "print_saint", "marigold", "wax"]

# From the bank's middle to the hall's wall faces (m: 14 less the station's wall and its tiles' face).
HALF = 14.0 - 0.3 - 0.067
# The cabinets: their count, their width (x), their length (y, the walk), the lanes' clear between them (m).
CABINETS = 5
CAB = (0.56, 1.7)
LANE = 1.3
# The tezontle plinth under a cabinet (m: its height, how far proud).
PLINTH = (0.12, 0.03)
# The body's top, the brass band round it (m: foot, top, how far proud).
BODY = 0.9
BAND = (0.62, 0.7, 0.035)
# The top stepped in: tiers (m: foot, top, half-width) over the body.
STEPS = [(0.9, 0.95, 0.31), (0.95, 1.0, 0.24), (1.0, 1.04, 0.19)]
TOP = 1.04
# The fare box on the top at the entry end (m: y from, y to, its top), its cap; the tally dial on its entry face
# (m: radius, height).
FARE = (-0.74, -0.42, 1.2)
FARE_CAP = 1.26
DIAL = (0.065, 1.12)
# The ward eye on the entry end (m: its height, the bezel's radius, the lens's radius).
EYE = (0.5, 0.11, 0.075)
# The arms' hub: its height, how far out from the cabinet's face (m); the axis tipped down into the lane (radians);
# an arm's length and its grip (m), its radius.
HUB = (0.86, 0.07)
TILT = math.radians(45.0)
ARM = (0.95, 0.14, 0.03)
# The fused arms' radius, melted thinner (m).
FUSED_R = 0.024
# The pylons over the outer cabinets: their tiers (m: foot, top, half-width across x, half-depth along y), the plaques
# on their faces (m: foot, top, half-width), the ward eye near the crown (m: height).
PYLON = [(1.04, 1.92, 0.2, 0.32), (1.92, 2.0, 0.24, 0.36), (2.0, 2.08, 0.17, 0.29), (2.08, 2.16, 0.11, 0.22)]
PLAQUE = (1.3, 1.62, 0.15)
PYLON_EYE = 1.76
# The railing: the curb (m: height, half-depth), the newels (m: side, the cap's tiers [(foot, top, half)]), the
# bars (m: side), the bottom bar's top, the top bar's foot, the handrail's radius.
CURB = (0.12, 0.12)
NEWEL = 0.22
NEWEL_CAP = [(1.0, 1.06, 0.14), (1.06, 1.11, 0.1), (1.11, 1.15, 0.06)]
BAR = 0.04
BOTTOM_BAR = 0.2
TOP_BAR = 0.92
HANDRAIL = 0.028
BAYS = 4
# The fret's motifs per bay.
MOTIFS = 4


def cabinet_xs():
    """Each cabinet's middle along x."""
    pitch = CAB[0] + LANE
    return [(k - (CABINETS - 1) / 2) * pitch for k in range(CABINETS)]


def lane_xs():
    """Each lane's middle along x."""
    xs = cabinet_xs()
    return [(a + b) / 2 for a, b in zip(xs, xs[1:])]


def hub_at(k):
    """The hub of lane k's arms, on the +x face of the cabinet before it."""
    return (cabinet_xs()[k] + CAB[0] / 2 + HUB[1], 0.0, HUB[0])


def axis():
    """The arms' axis: out of the cabinet into the lane (+x), tipped down."""
    return Vector((math.cos(TILT), 0.0, -math.sin(TILT)))


def arm_directions():
    """The three arms: one level across the lane, the others turned a third about the axis (down, before and behind)."""
    a = axis()
    return [Matrix.Rotation(2 * math.pi * k / 3, 3, a) @ Vector((1.0, 0.0, 0.0)) for k in range(3)]


def _lean(d):
    """turned()'s lean and heading tipping +Z onto the direction d."""
    d = Vector(d).normalized()
    return math.acos(max(-1.0, min(1.0, d.z))), math.atan2(d.x, -d.y)


def _strip(m, path, w, y0, y1, slot):
    """A square bar w wide along an orthogonal path [(x, z)] in the plane y0..y1, its corners mitred: one solid, its
    faces welded (no faces stacked where two lengths would cross)."""
    m.shell()
    n = len(path)
    left, right = [], []
    for i in range(n):
        normals = []
        segs = []
        if i > 0:
            segs.append((path[i - 1], path[i]))
        if i < n - 1:
            segs.append((path[i], path[i + 1]))
        for a, b in segs:
            dx, dz = b[0] - a[0], b[1] - a[1]
            k = math.hypot(dx, dz)
            normals.append((-dz / k, dx / k))
        if len(normals) == 2 and abs(normals[0][0] * normals[1][0] + normals[0][1] * normals[1][1]) > 0.99:
            normals = normals[:1]
        nx, nz = (normals[0][0] + normals[1][0], normals[0][1] + normals[1][1]) if len(normals) == 2 else normals[0]
        left.append((path[i][0] + nx * w / 2, path[i][1] + nz * w / 2))
        right.append((path[i][0] - nx * w / 2, path[i][1] - nz * w / 2))
    outline = left + list(reversed(right))
    m.face([(x, y0, z) for x, z in outline], slot)
    m.face([(x, y1, z) for x, z in reversed(outline)], slot)
    for i in range(len(outline)):
        (ax, az), (bx, bz) = outline[i], outline[(i + 1) % len(outline)]
        m.face([(ax, y0, az), (ax, y1, az), (bx, y1, bz), (bx, y0, bz)], slot)


def _eye(m, x, y, z, facing, blown):
    """The Company's ward eye on a face at (x, y, z) looking along `facing` (a unit axis): a brass bezel, its obsidian
    lens; `blown`, the lens gone, the bezel blackened round its empty socket."""
    lean, towards = _lean(facing)
    if blown:
        turned(m, [(EYE[1], 0.0), (EYE[1], 0.04)], 20, "brass_burnt", at=(x, y, z), lean=lean, towards=towards)
        turned(m, [(EYE[2], 0.035), (EYE[2], 0.075)], 20, "hollow", at=(x, y, z), lean=lean, towards=towards)
    else:
        turned(m, [(EYE[1], 0.0), (EYE[1], 0.04)], 20, "brass", at=(x, y, z), lean=lean, towards=towards)
        turned(m, [(EYE[2], 0.035), (EYE[2] * 0.85, 0.075), (EYE[2] * 0.4, 0.085)], 20, "obsidian", at=(x, y, z),
               lean=lean, towards=towards)


def _cabinet(m, cx, state, hub, scorch_left=False, plank_right=False):
    """A cabinet at cx: `state` "working", "fused" or "patched"; `hub`, its +x face carries a lane's hub."""
    hw, hl = CAB[0] / 2, CAB[1] / 2
    body = "scorched" if state == "fused" else "iron"
    trim = "brass_burnt" if state == "fused" else "brass"
    box(m, (cx - hw - PLINTH[1], -hl - PLINTH[1], 0.0), (cx + hw + PLINTH[1], hl + PLINTH[1], PLINTH[0]), "tezontle",
        r=0.015)
    box(m, (cx - hw, -hl, PLINTH[0]), (cx + hw, hl, BODY), body, r=0.02)
    p = BAND[2]
    box(m, (cx - hw - p, -hl - p, BAND[0]), (cx + hw + p, hl + p, BAND[1]), trim, r=0.012)
    for z0, z1, h in STEPS:
        d = hl - (hw - h)
        box(m, (cx - h, -d, z0), (cx + h, d, z1), trim if z1 == TOP else body, r=0.012)
    # (The fare box at the entry end, its cap, the slot's lip; the tally dial on its face.)
    box(m, (cx - 0.16, FARE[0], TOP), (cx + 0.16, FARE[1], FARE[2]), trim, r=0.015)
    box(m, (cx - 0.11, FARE[0] + 0.05, FARE[2]), (cx + 0.11, FARE[1] - 0.05, FARE_CAP), trim, r=0.012)
    box(m, (cx - 0.07, -0.66, FARE_CAP), (cx + 0.07, -0.58, FARE_CAP + 0.035), "iron", r=0.0)
    if state != "fused":
        lean, towards = _lean((0.0, -1.0, 0.0))
        turned(m, [(DIAL[0], 0.0), (DIAL[0], 0.035)], 20, "sign", at=(cx, FARE[0], DIAL[1]), lean=lean,
               towards=towards)
    # (The ward eye on the entry end; a kick plate on the exit end.)
    _eye(m, cx, -hl, EYE[0], (0.0, -1.0, 0.0), blown=state == "fused")
    box(m, (cx - hw + 0.05, hl, PLINTH[0] + 0.02), (cx + hw - 0.05, hl + 0.035, PLINTH[0] + 0.2), trim, r=0.0)
    # (The boss the arms turn in.)
    if hub:
        lean, towards = _lean((1.0, 0.0, 0.0))
        turned(m, [(0.1, 0.0), (0.1, HUB[1] * 0.6), (0.07, HUB[1])], 20, trim, at=(cx + hw, 0.0, HUB[0]), lean=lean,
               towards=towards)
    if state == "patched":
        _planks(m, cx, sides=(-1, 1))
    if scorch_left:
        box(m, (cx - hw - 0.035, -hl + 0.12, PLINTH[0] + 0.06), (cx - hw, hl - 0.12, BAND[0] - 0.04), "scorched",
            r=0.0)
    if plank_right:
        _planks(m, cx, sides=(1,))


def _planks(m, cx, sides):
    """The Company's planks nailed over a cabinet's lane faces, under its band, an iron strap across them."""
    hw, hl = CAB[0] / 2, CAB[1] / 2
    rng = random.Random(int(cx * 100))
    for side in sides:
        face = cx + side * hw
        out = face + side * 0.04
        a, b = sorted((face, out))
        y = -hl + 0.06
        while y < hl - 0.25:
            w = rng.uniform(0.18, 0.26)
            y1 = min(y + w, hl - 0.06)
            foot, head = PLINTH[0] + 0.04 + rng.uniform(0, 0.03), BAND[0] - 0.03 - rng.uniform(0, 0.03)
            box(m, (a, y, foot), (b, y1 - 0.012, head), "wood", r=0.0)
            for z in (PLINTH[0] + 0.12, BAND[0] - 0.12):
                stud(m, (out, (y + y1) / 2, z), math.pi / 2, math.pi / 2 if side > 0 else -math.pi / 2, slot="iron",
                     r=0.016)
            y = y1


def _arms(m, at, slot, grip):
    """A tripod of arms about the hub at `at`."""
    a = axis()
    centre = Vector(at)
    lean, towards = _lean(a)
    turned(m, [(0.06, -0.02), (0.065, 0.03), (0.045, 0.07)], 16, slot, at=tuple(centre), lean=lean, towards=towards)
    for d in arm_directions():
        root = centre + a * 0.03
        pipe(m, [tuple(root), tuple(root + d * (ARM[0] - ARM[1]))], ARM[2], 10, slot)
        pipe(m, [tuple(root + d * (ARM[0] - ARM[1])), tuple(root + d * ARM[0])], ARM[2] + 0.004, 10, grip)


def _fused_arms(m, at):
    """A tripod the surge melted: each arm bent down at its root and hanging against its cabinet, blackened."""
    centre = Vector(at)
    a = axis()
    lean, towards = _lean(a)
    turned(m, [(0.06, -0.02), (0.07, 0.025), (0.05, 0.06)], 16, "brass_burnt", at=tuple(centre), lean=lean,
           towards=towards)
    for k, d in enumerate(arm_directions()):
        root = centre + a * 0.02
        bend = root + Vector((d.x * 0.03, d.y * 0.06, min(d.z, 0.0) * 0.05))
        # (It sagged out of its line and hangs, the wall of its cabinet behind it, a bead of brass run to its tip.)
        hang = Vector((at[0] + 0.035 + 0.01 * k, bend.y + d.y * 0.08, 0.3 + 0.07 * k))
        path = [root, bend, bend.lerp(hang, 0.5) + Vector((0.0, 0.0, -0.04)), hang]
        pipe(m, [tuple(p) for p in path], FUSED_R, 10, "brass_burnt")
        turned(m, [(0.012, -0.05), (0.03, -0.025), (0.026, 0.0), (0.014, 0.02)], 10, "brass_burnt",
               at=(hang.x, hang.y, hang.z - 0.005), jitter=0.12)
    # (The hub run down over the cabinet's face as it cooled: a slumped lump of metal.)
    turned(m, [(0.045, 0.0), (0.08, 0.05), (0.07, 0.12), (0.05, 0.19), (0.03, 0.25)], 14, "brass_burnt",
           at=(at[0] - HUB[1] + 0.045, 0.0, at[2] + 0.04), jitter=0.15, lean=math.pi)


def _pylon(m, cx, blown):
    """The stepped chiluca pylon over an outer cabinet: a blank plaque each way (the user's words), the ward eye over
    them, facing the entry."""
    # (The one over the fused cabinets smoked black by the fire, darkest at its foot.)
    stone = "chiluca_scorched" if blown else "chiluca"
    for z0, z1, hx, hy in PYLON:
        box(m, (cx - hx, -hy, z0), (cx + hx, hy, z1), stone, r=0.015)
    hx, hy = PYLON[0][2], PYLON[0][3]
    for side in (-1, 1):
        y = side * hy
        a, b = sorted((y, y + side * 0.04))
        box(m, (cx - PLAQUE[2], a, PLAQUE[0]), (cx + PLAQUE[2], b, PLAQUE[1]), "sign", r=0.0)
    _eye(m, cx, -hy, PYLON_EYE, (0.0, -1.0, 0.0), blown=blown)


def _railing(m, x0, x1, gate):
    """A railing from x0 to x1 (x0 at the cabinets): the curb, the newels, the bars, the fret, the handrail; `gate`,
    the bay next to the cabinets a staff gate chained to its newel."""
    sign = 1 if x1 > x0 else -1
    a, b = sorted((x0, x1))
    box(m, (a, -CURB[1], 0.0), (b, CURB[1], CURB[0]), "tezontle", r=0.0)
    run = abs(x1 - x0)
    bay = (run - (BAYS + 1) * NEWEL) / BAYS
    posts = [x0 + sign * (NEWEL / 2 + k * (bay + NEWEL)) for k in range(BAYS + 1)]
    h = NEWEL / 2
    for k, px in enumerate(posts):
        # (The last newel stands against the wall.)
        px = x1 - sign * h if k == BAYS else px
        posts[k] = px
        box(m, (px - h, -h, CURB[0]), (px + h, h, NEWEL_CAP[0][0]), "chiluca", r=0.015)
        for z0, z1, c in NEWEL_CAP:
            # (The wall's newel's cap stops at the wall.)
            box(m, (max(px - c, -HALF), -c, z0), (min(px + c, HALF), c, z1), "chiluca", r=0.012)
    t = BAR / 2
    for k in range(BAYS):
        p0, p1 = sorted((posts[k] + sign * h, posts[k + 1] - sign * h))
        if gate and k == 0:
            _gate(m, p0, p1, sign)
            continue
        box(m, (p0, -t, BOTTOM_BAR - BAR), (p1, t, BOTTOM_BAR), "iron", r=0.0)
        box(m, (p0, -t, TOP_BAR), (p1, t, TOP_BAR + BAR), "iron", r=0.0)
        pipe(m, [(p0 - 0.03, 0.0, TOP_BAR + BAR + HANDRAIL), (p1 + 0.03, 0.0, TOP_BAR + BAR + HANDRAIL)], HANDRAIL, 12,
             "brass")
        _fret(m, p0, p1, -t + 0.004, t - 0.004)


def _fret(m, p0, p1, y0, y1):
    """A stepped fret between two newels: each motif a stepped pyramid, its feet on the bottom bar, its crown under
    the top bar, one bar from end to end."""
    w = BAR * 0.8
    zb, zt = BOTTOM_BAR + w / 2, TOP_BAR - w / 2
    unit = (p1 - p0) / MOTIFS
    steps = 3
    rise = (zt - zb) / steps
    run = unit * 0.32 / steps
    path = [(p0 - 0.02, zb)]
    for k in range(MOTIFS):
        u = p0 + k * unit + unit * 0.12
        x = u
        path.append((x, zb))
        for s in range(steps):
            path += [(x, zb + (s + 1) * rise), (x + run, zb + (s + 1) * rise)]
            x += run
        x += unit * 0.12
        path.append((x, zt))
        for s in range(steps):
            path += [(x, zt - (s + 1) * rise), (x + run, zt - (s + 1) * rise)]
            x += run
    path.append((p1 + 0.02, zb))
    # (Runs of three points in one line are one length.)
    clean = [path[0]]
    for q in path[1:]:
        if q == clean[-1]:
            continue
        if len(clean) >= 2:
            (ax, az), (bx, bz) = clean[-2], clean[-1]
            if (ax == bx == q[0]) or (az == bz == q[1]):
                clean[-1] = q
                continue
        clean.append(q)
    _strip(m, clean, w, y0, y1, "iron")


def _gate(m, p0, p1, sign):
    """The staff gate filling a bay: its frame, a fret of its own, hung on the far newel, chained to the near one with
    the Company's padlock."""
    t = BAR / 2
    g0, g1 = p0 + 0.03, p1 - 0.03
    box(m, (g0, -t, BOTTOM_BAR - BAR), (g1, t, BOTTOM_BAR), "iron", r=0.0)
    box(m, (g0, -t, TOP_BAR), (g1, t, TOP_BAR + BAR), "iron", r=0.0)
    box(m, (g0, -t, BOTTOM_BAR), (g0 + BAR, t, TOP_BAR), "iron", r=0.0)
    box(m, (g1 - BAR, -t, BOTTOM_BAR), (g1, t, TOP_BAR), "iron", r=0.0)
    _fret(m, g0 + BAR, g1 - BAR, -t + 0.004, t - 0.004)
    # (The hinges on the far newel, the chain round the near one, the padlock.)
    far = p1 if sign > 0 else p0
    near = p0 if sign > 0 else p1
    for z in (BOTTOM_BAR + 0.08, TOP_BAR - 0.08):
        pipe(m, [(far - sign * 0.01, 0.0, z - 0.06), (far - sign * 0.01, 0.0, z + 0.06)], 0.022, 10, "iron")
    # (Wrapped three times round the near newel and the gate's stile.)
    cx, rx = near - sign * 0.075, 0.175
    for k in range(3):
        z = 0.64 + 0.04 * k
        ring = [(cx + rx * math.cos(2 * math.pi * j / 12), 0.14 * math.sin(2 * math.pi * j / 12), z) for j in range(12)]
        pipe(m, ring, 0.008, 6, "iron", closed=True)
    box(m, (near + sign * 0.06 - 0.035, -0.14, 0.56), (near + sign * 0.06 + 0.035, -0.115, 0.63), "iron", r=0.0)
    box(m, (near + sign * 0.06 - 0.045, -0.165, 0.5), (near + sign * 0.06 + 0.045, -0.12, 0.57), "brass", r=0.01)


def _offerings(m, fused):
    """The dead's fare on the dead slots: coins on the fare boxes, a saint's card in a slot, marigolds in the melted
    arms, a candle burned down on a cabinet's top."""
    rng = random.Random(7)
    for cx in fused:
        # (Each coin laid on its own on the top, none on another.)
        for i in range(3):
            for j in range(4):
                if rng.random() < 0.45:
                    continue
                x = cx - 0.12 + 0.12 * i + rng.uniform(-0.02, 0.02)
                y = FARE[1] + 0.06 + 0.075 * j + rng.uniform(-0.015, 0.015)
                slot = "copper" if rng.random() < 0.6 else "silver"
                turned(m, [(0.014, 0.0), (0.014, 0.006)], 8, slot, at=(x, y, TOP))
    cx = fused[-1]
    box(m, (cx - 0.075, -0.625, FARE_CAP - 0.02), (cx + 0.075, -0.613, FARE_CAP + 0.17), "print_saint", r=0.0)
    hub = hub_at(0)
    # (A bunch wedged between the hanging arms and the cabinet, under the lump.)
    for k in range(7):
        turned(m, [(0.02, -0.032), (0.045, -0.014), (0.045, 0.014), (0.02, 0.032)], 12, "marigold",
               at=(hub[0] - 0.01, -0.15 + 0.05 * k, hub[2] - 0.3 + 0.035 * (k % 2)))
    # (A candle burned down into its own pool, one solid.)
    cx = fused[0]
    turned(m, [(0.05, 0.0), (0.055, 0.008), (0.032, 0.018), (0.022, 0.024), (0.022, 0.09), (0.016, 0.1)], 14, "wax",
           at=(cx + 0.05, 0.56, TOP))


def bank(m, fused):
    """A bank across the hall; `fused`, the west's: its first two cabinets (the -x half, set at the hall's z -4…0)
    fused, the middle one scorched on that side and planked on the other, the last two patched."""
    underground_shapes.rng = random.Random(1 if fused else 2)
    xs = cabinet_xs()
    for k, cx in enumerate(xs):
        if not fused:
            _cabinet(m, cx, "working", hub=k < CABINETS - 1)
        elif k < 2:
            _cabinet(m, cx, "fused", hub=True)
        elif k == 2:
            _cabinet(m, cx, "working", hub=True, scorch_left=True, plank_right=True)
        else:
            _cabinet(m, cx, "patched", hub=k < CABINETS - 1)
    for k, cx in enumerate((xs[0], xs[-1])):
        _pylon(m, cx, blown=fused and k == 0)
    edge = xs[-1] + CAB[0] / 2 + PLINTH[1]
    _railing(m, edge, HALF, gate=True)
    _railing(m, -edge, -HALF, gate=False)
    if fused:
        for k in range(2):
            _fused_arms(m, hub_at(k))
        _offerings(m, xs[:2])


def bank_east(m):
    bank(m, fused=False)


def bank_west(m):
    bank(m, fused=True)


def rotor(m):
    """A lane's tripod of brass arms, worn dark at their grips, about its hub at the origin."""
    _arms(m, (0.0, 0.0, 0.0), "brass", "leather_black")


PIECES = [("bank_east", bank_east), ("bank_west", bank_west), ("rotor", rotor)]

BUDGET = {"bank_east": 40000, "bank_west": 40000, "rotor": 4000}
SLIVER = {n: 0.004 for n, _ in PIECES}


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
