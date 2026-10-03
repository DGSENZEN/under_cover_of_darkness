"""The mole: from the quay's east end south, bending round (BEND_RADIUS on
its middle line) to run south-west to its head; one body of stone swept
along its line, round its bend without a seam: its harbour face with the
tide's mark under its coping, its paved top, a parapet to the sea on a
battered face, riprap at its foot, mooring rings and bollards on its
harbour side. Each of its surfaces ends where it meets the head's sixteen
flats (no overlap there to shimmer, no gap to fall through). The golden
tower on its head (after Seville's Torre del Oro), the windlass in its
room, the ladder up to its terrace; the chain across the harbour's mouth to
the fort."""

import math

import geo
import kit_harbour
import terrain

from . import CHAIN_Z, FORT, MOLE_BEND, MOLE_HEAD, MOLE_X, QUAY

HEAD_RADIUS = 12.0
HEAD_SIDES = 16
TOP = 3.5
STAGES = (18.0, 9.0)
BED = kit_harbour.BED
# Its line round the bend: a circle this far from the bend's middle line.
BEND_RADIUS = 26.0
# How finely it is swept (m): along its straights, round its bend.
STEP = 4.0
ARC_STEP = 2.5
# Its section across its line (s: out to sea from its middle line, y up):
# the outline from the harbour face's foot up, over the top and the
# parapet, down the battered face to its foot; each point with the slot of
# the face from it to the next.
WAVE = 1.2
COPING = (0.2, 0.3)
PARAPET = (5.8, 7.0, kit_harbour.PARAPET_TOP)
CAP = (0.05, 0.12)
BATTER = (7.6, -1.0)
SECTION = [(-7.0, BED, "waterline_tide"), (-7.0, WAVE, "granite"), (-7.0, TOP - COPING[1], "granite"),
           (-7.0 - COPING[0], TOP - COPING[1], "granite"), (-7.0 - COPING[0], TOP, "granite"),
           (PARAPET[0], TOP, "granite_rough"), (PARAPET[0], PARAPET[2], "ashlar_gold"),
           (PARAPET[0] - CAP[0], PARAPET[2], "ashlar_gold"), (PARAPET[0] - CAP[0], PARAPET[2] + CAP[1], "ashlar_gold"),
           (PARAPET[1] + CAP[0], PARAPET[2] + CAP[1], "ashlar_gold"), (PARAPET[1] + CAP[0], PARAPET[2], "ashlar_gold"),
           (PARAPET[1], PARAPET[2], "granite_rough"), (PARAPET[1], TOP, "granite_rough"), (BATTER[0], BATTER[1], "granite_rough"),
           (BATTER[0], BED, None)]
# The parapet's part of it (its points' indexes): closed at its ends.
PARAPET_POINTS = range(5, 13)


def head_yaw():
    """The yaw that turns the head's landward gap (and the tower's door and
    ladder: their -z) toward where the mole comes in."""
    angle = math.degrees(math.atan2(MOLE_BEND - MOLE_HEAD[1], MOLE_X - MOLE_HEAD[0]))
    return 270.0 - (angle % 360.0)


def head_outline():
    """The head's sixteen corners (x, z), round it."""
    turn = geo.rotation(head_yaw())
    corner = HEAD_RADIUS / math.cos(math.pi / HEAD_SIDES)
    out = []

    for k in range(HEAD_SIDES):
        # (Its flats at 0, 22.5 ... degrees: its corners halfway between.)
        a = math.radians(180.0 / HEAD_SIDES + k * 360.0 / HEAD_SIDES)
        p = geo.apply(turn, [corner * math.cos(a), 0.0, corner * math.sin(a)])
        out.append((MOLE_HEAD[0] + p[0], MOLE_HEAD[1] + p[2]))

    return out


def _unit(dx, dz):
    length = math.hypot(dx, dz)
    return dx / length, dz / length


def line():
    """Its middle line as stations [(x, z, (dx, dz))] (its way along it,
    root to head), straight to the bend, round it, straight on until well
    inside the head."""
    a = _unit(0.0, 1.0)
    b = _unit(MOLE_HEAD[0] - MOLE_X, MOLE_HEAD[1] - MOLE_BEND)
    turn = math.acos(max(-1.0, min(1.0, a[0] * b[0] + a[1] * b[1])))
    reach = BEND_RADIUS * math.tan(turn / 2.0)
    stations = []
    run = MOLE_BEND - reach
    n = max(1, int(round(run / STEP)))

    for i in range(n + 1):
        stations.append((MOLE_X, run * i / n, a))

    # (Round the bend: turning to its right, the harbour's side; its centre
    # that side of the line.)
    centre = (MOLE_X - BEND_RADIUS, run)
    m = max(2, int(round(BEND_RADIUS * turn / ARC_STEP)))

    for i in range(1, m + 1):
        t = turn * i / m
        stations.append((centre[0] + BEND_RADIUS * math.cos(t), centre[1] + BEND_RADIUS * math.sin(t), (-math.sin(t), math.cos(t))))

    start = (MOLE_X + b[0] * reach, MOLE_BEND + b[1] * reach)
    length = math.hypot(MOLE_HEAD[0] - start[0], MOLE_HEAD[1] - start[1])
    n = max(1, int(round(length / STEP)))

    for i in range(1, n + 1):
        stations.append((start[0] + b[0] * length * i / n, start[1] + b[1] * length * i / n, b))

    return stations


def _sea(d):
    """Out to sea from the line going along d: its left."""
    return d[1], -d[0]


def _enter(outline, p, d):
    """How far along d from p the head's outline is first met (or None)."""
    best = None

    for k in range(len(outline)):
        (ax, az), (bx, bz) = outline[k], outline[(k + 1) % len(outline)]
        ex, ez = bx - ax, bz - az
        det = d[0] * (-ez) - d[1] * (-ex)

        if abs(det) < 1e-12:
            continue

        rx, rz = ax - p[0], az - p[1]
        t = (rx * (-ez) - rz * (-ex)) / det
        u = (d[0] * rz - d[1] * rx) / det

        if -1e-9 <= u <= 1.0 + 1e-9 and t > -1e-6 and (best is None or t < best):
            best = t

    return best


def _section():
    """SECTION with points added where the head's corners fall across the
    line (so each surface's end follows the head's flats, not a chord over
    a corner): [(s, y, slot)]."""
    outline = head_outline()
    d = _unit(MOLE_HEAD[0] - MOLE_X, MOLE_HEAD[1] - MOLE_BEND)
    sea = _sea(d)
    # (The head is round: its corners on either side of its middle fall
    # at the same places across the line.)
    cuts = sorted({round(sea[0] * (x - MOLE_HEAD[0]) + sea[1] * (z - MOLE_HEAD[1]), 6) for x, z in outline})
    out = []

    for (s0, y0, slot), (s1, y1, _) in zip(SECTION, SECTION[1:] + [SECTION[-1]]):
        out.append((s0, y0, slot))

        if slot is None or abs(s1 - s0) < 1e-6:
            continue

        for c in cuts:
            if min(s0, s1) + 0.05 < c < max(s0, s1) - 0.05:
                f = (c - s0) / (s1 - s0)
                out.append((c, y0 + (y1 - y0) * f, slot))

    # (Each added point in order along its face.)
    return out


def body():
    """The mole's body: (verts, triangles, slots) for terrain.mesh, its
    sections at each station, each surface ending on the head's outline."""
    stations = line()
    section = _section()
    outline = head_outline()
    last = stations[-1]
    verts, faces, slots = [], [], []

    def at(st, s, y):
        sea = _sea(st[2])
        return [st[0] + sea[0] * s, y, st[1] + sea[1] * s]

    def ends(s):
        """The stations a point s across the line is swept through, to where
        it meets the head: the last a station of its own there (its middle
        line s back from the meeting)."""
        out = []

        for st in stations:
            sea = _sea(st[2])

            if _inside(outline, (st[0] + sea[0] * s, st[1] + sea[1] * s)):
                break

            out.append(st)

        st = out[-1]
        sea = _sea(st[2])
        p = (st[0] + sea[0] * s, st[1] + sea[1] * s)
        t = _enter(outline, p, st[2])
        q = (p[0] + st[2][0] * t, p[1] + st[2][1] * t)
        out.append((q[0] - sea[0] * s, q[1] - sea[1] * s, st[2]))
        return out

    tracks = [ends(s) for s, _, _ in section]

    for i in range(len(section) - 1):
        s0, y0, slot = section[i]
        s1, y1, _ = section[i + 1]

        if slot is None:
            continue

        # A strip along the line between section points i and i + 1: their
        # tracks run to their own ends at the head (one may stop a station
        # short of the other: its last quad a triangle there).
        ta, tb = tracks[i], tracks[i + 1]
        count = max(len(ta), len(tb))
        ia = [verts.append(at(st, s0, y0)) or len(verts) - 1 for st in ta]
        ib = [verts.append(at(st, s1, y1)) or len(verts) - 1 for st in tb]
        out = _outward(s0, y0, s1, y1)

        for k in range(count - 1):
            a0, a1 = ia[min(k, len(ia) - 1)], ia[min(k + 1, len(ia) - 1)]
            b0, b1 = ib[min(k, len(ib) - 1)], ib[min(k + 1, len(ib) - 1)]
            st = stations[min(k, len(stations) - 1)]
            sea = _sea(st[2])
            toward = [sea[0] * out[0], out[1], sea[1] * out[0]]

            for tri in ((a0, a1, b1), (a0, b1, b0)):
                if len(set(tri)) < 3:
                    continue

                faces.append(terrain._facing(verts, list(tri), toward))
                slots.append(slot)

    # The root's end against the quay, and the parapet's against the head
    # (each piece of it on the flat it meets: the head's outline bends at
    # its corners).
    root = [(sv, yv) for sv, yv, _ in SECTION]

    for tri in _triangulate(root):
        points = [at(stations[0], root[k][0], root[k][1]) for k in tri]
        _face(verts, faces, slots, points, [-stations[0][2][0], 0.0, -stations[0][2][1]], "granite")

    corners = [c for c in sorted({round(sea * 1.0, 6) for sea in _cuts()}) if PARAPET[0] - CAP[0] < c < PARAPET[1] + CAP[0]]

    def on_head(s, y):
        st = last
        sea = _sea(st[2])
        back = (MOLE_HEAD[0] + sea[0] * s - st[2][0] * 40.0, MOLE_HEAD[1] + sea[1] * s - st[2][1] * 40.0)
        t = _enter(outline, back, st[2])
        return [back[0] + st[2][0] * t, y, back[1] + st[2][1] * t]

    for (s0, s1), (y0, y1), slot in (((PARAPET[0], PARAPET[1]), (TOP, PARAPET[2]), "granite_rough"),
                                     ((PARAPET[0] - CAP[0], PARAPET[1] + CAP[0]), (PARAPET[2], PARAPET[2] + CAP[1]), "ashlar_gold")):
        cut = [s0] + [c for c in corners if s0 < c < s1] + [s1]

        for a, b in zip(cut, cut[1:]):
            _face(verts, faces, slots, [on_head(a, y0), on_head(b, y0), on_head(b, y1), on_head(a, y1)], [last[2][0], 0.0, last[2][1]], slot)

    return verts, faces, slots


def _cuts():
    """Where the head's corners fall across its line (s)."""
    d = _unit(MOLE_HEAD[0] - MOLE_X, MOLE_HEAD[1] - MOLE_BEND)
    sea = _sea(d)
    return [sea[0] * (x - MOLE_HEAD[0]) + sea[1] * (z - MOLE_HEAD[1]) for x, z in head_outline()]


def _face(verts, faces, slots, points, toward, slot):
    """A flat face through `points` (3 or 4, in order round it), looking
    `toward`."""
    base = len(verts)
    verts.extend([list(p) for p in points])

    for tri in ([0, 1, 2], [0, 2, 3])[:len(points) - 2]:
        ids = [base + k for k in tri]

        if terrain._area(*(verts[i] for i in ids)) > 1e-6:
            faces.append(terrain._facing(verts, ids, toward))
            slots.append(slot)


def _triangulate(polygon):
    """A simple polygon's triangles (indices), by clipping its ears."""
    area = sum(polygon[k][0] * polygon[(k + 1) % len(polygon)][1] - polygon[(k + 1) % len(polygon)][0] * polygon[k][1]
               for k in range(len(polygon)))
    order = list(range(len(polygon))) if area > 0.0 else list(reversed(range(len(polygon))))
    out = []

    def convex(a, b, c):
        return (b[0] - a[0]) * (c[1] - a[1]) - (b[1] - a[1]) * (c[0] - a[0]) > 1e-9

    def holds(a, b, c, p):
        return convex(a, b, p) and convex(b, c, p) and convex(c, a, p)

    while len(order) > 3:
        for k in range(len(order)):
            i, j, m = order[k - 1], order[k], order[(k + 1) % len(order)]
            a, b, c = polygon[i], polygon[j], polygon[m]

            if not convex(a, b, c):
                continue

            if any(holds(a, b, c, polygon[q]) for q in order if q not in (i, j, m)):
                continue

            out.append([i, j, m])
            order.pop(k)
            break
        else:
            raise ValueError("mole: its section will not triangulate")

    out.append(order)
    return out


def _inside(outline, p, margin=0.0):
    """Whether p (x, z) is inside the head's outline (more than `margin` m
    in from it)."""
    sign = None

    for k in range(len(outline)):
        (ax, az), (bx, bz) = outline[k], outline[(k + 1) % len(outline)]
        length = math.hypot(bx - ax, bz - az)
        c = ((bx - ax) * (p[1] - az) - (bz - az) * (p[0] - ax)) / length

        if sign is None:
            sign = 1.0 if c > 0.0 else -1.0

        if c * sign <= margin:
            return False

    return True


def _outward(s0, y0, s1, y1):
    """The face from section point 0 to 1 looks out (s, y): the outline
    runs up the harbour face, over and down the sea's, so outward is to the
    travel's left."""
    ds, dy = s1 - s0, y1 - y0
    length = math.hypot(ds, dy)
    return -dy / length, ds / length


def _placed(st):
    """The yaw that runs a mole piece's x along a station's line, its +z
    out to sea (the kit's mole frame)."""
    return math.degrees(math.atan2(st[2][1], -st[2][0]))


def lay(L):
    verts, faces, slots = body()
    # (Darker and greener under the tide's mark.)
    L.terrain(terrain.mesh("mole_body", "mole", verts, faces, slots, surface="stone",
                           tint=lambda x, y, z: [0.72, 0.76, 0.7] if y < WAVE - 0.1 else [1.0, 1.0, 1.0], occluder=True))
    stations = line()
    walked = 0.0
    previous = None

    # Along it: riprap at its seaward foot every 8 m, a ring on its harbour
    # face every 12 m (none in the last stretch, before the head). (Its
    # bollards and gear are the coast's: coast.py.)
    for k, st in enumerate(stations[:-2]):
        if previous is not None:
            walked += math.hypot(st[0] - previous[0], st[1] - previous[1])

        previous = st
        sea = _sea(st[2])
        yaw = _placed(st)

        if k % 2 == 1:
            L.put("riprap_8", (st[0] + sea[0] * kit_harbour.RIPRAP, 0.0, st[1] + sea[1] * kit_harbour.RIPRAP), yaw, "mole")

        if k % 3 == 1:
            L.put("mooring_ring", (st[0] - sea[0] * 7.0, 1.7, st[1] - sea[1] * 7.0), yaw + 180.0, "mole")

    # Up onto its root from the quay, across its walk.
    sea = _sea(stations[0][2])
    middle = (kit_harbour.MOLE_WIDTH / 2.0 * -1.0 - COPING[0] + PARAPET[0]) / 2.0
    L.put("mole_steps", (stations[0][0] + sea[0] * middle, QUAY, stations[0][1] + sea[1] * middle), 0.0, "mole")

    turn = head_yaw()
    L.put("mole_head", (MOLE_HEAD[0], 0.0, MOLE_HEAD[1]), turn, "mole")
    L.put("gold_stage_1", (MOLE_HEAD[0], TOP, MOLE_HEAD[1]), turn, "mole", climbs=True)
    L.put("gold_stage_2", (MOLE_HEAD[0], TOP + STAGES[0], MOLE_HEAD[1]), turn, "mole")
    L.put("gold_stage_3", (MOLE_HEAD[0], TOP + STAGES[0] + STAGES[1], MOLE_HEAD[1]), turn, "mole")
    L.put("windlass", (MOLE_HEAD[0], TOP, MOLE_HEAD[1]), turn + 90.0, "mole")

    # The chain from the tower's foot to the fort's bastion.
    x = MOLE_HEAD[0] - 8.0 - 6.0

    while x > FORT[0] + 15.0 + 6.0:
        L.put("chain_span_12", (x, 0.0, CHAIN_Z), 0.0, "mole")
        x -= 12.0
