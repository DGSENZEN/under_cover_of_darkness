"""The city's harbour (kit v1): granite quays with their coping, rings and
steps down to the sea; the mole and its head; bollards; the royal
shipyard's brick naves (after Seville's Atarazanas and Barcelona's
Drassanes: piers, slightly pointed arches, groin vaults under a walkable
terrace), its slipway, a galley half-built on the stocks with a scaffold
to climb; a jib crane; the quays' dressing (nets, baskets, anchors, oars,
crates, rope, pots, barrels, bales). Pure data, as kit_recipes (which
imports this at its end).

Quays and the mole are built with their pivot at sea level (y 0): a quay's
top is at 2.5, its face (+z, to the water) down to -3, the mole's top at
3.5. A nave bay is 8.4 m square: piers on its corners, arches between them
springing at 7.1 to 10.9, a groin vault over it under a terrace at 13.
"""

import math
import random

import geo
import kit_fort
import kit_recipes as k
import kit_shapes as ks

QUAY_TOP = 2.5
QUAY_FOOT = -3.0
QUAY_DEPTH = 6.0
MOLE_TOP = 3.5
MOLE_WIDTH = 14.0
PARAPET_TOP = 5.5
NAVE = 8.4
SPRING = 7.1
APEX = 10.9
TERRACE = 13.0
PIER = 1.2
BAND = 0.8
PLANKS = (2.2, 4.4)


def col(cx, cy, cz, sx, sy, sz, yaw=0.0, pitch=0.0, roll=0.0, surface="stone"):
    return [cx, cy, cz, sx, sy, sz, surface, yaw, pitch, roll]


def _piece(name, family, slot, shapes, cols, size, budget=None, surface="stone"):
    k.piece(name, family, slot, surface, [], cols=cols, size=size)
    k.model(name, shapes)

    if budget:
        k.PIECES[name]["budget"] = budget


def _down(points, slot):
    """A face through `points` turned to look down (a vault's web)."""
    a, b, c = points[0], points[1], points[2]
    ny = (b[2] - a[2]) * (c[0] - a[0]) - (b[0] - a[0]) * (c[2] - a[2])
    return ks.polygon(points if ny < 0.0 else points[::-1], slot)


# Quays: granite, the sea's marks on the face under 1.2 m (the waterline
# photo is anchored to the sea's height), a coping standing proud, rings.

def _quay(length):
    height = QUAY_TOP - QUAY_FOOT
    front = QUAY_DEPTH / 2.0
    shapes = [ks.box(0.0, (QUAY_TOP + QUAY_FOOT) / 2.0, 0.0, length, height, QUAY_DEPTH, "granite"),
              ks.box(0.0, (1.2 + QUAY_FOOT) / 2.0, front + 0.02, length, 1.2 - QUAY_FOOT, 0.04, "waterline_tide"),
              ks.box(0.0, QUAY_TOP - 0.15, front - 0.1, length, 0.3, 0.6, "granite")]

    for x in ([-length / 4.0, length / 4.0] if length > 5.0 else [0.0]):
        shapes.append(ks.ring(x, 1.6, front + 0.06, 0.12, 0.17, 0.04, 0.0, 360.0, 6, "iron"))

    cols = [col(0.0, (QUAY_TOP + QUAY_FOOT) / 2.0, 0.0, length, height, QUAY_DEPTH),
            col(0.0, QUAY_TOP - 0.15, front - 0.1, length, 0.3, 0.6)]
    return shapes, cols


def _quay_corner():
    size = QUAY_DEPTH
    shapes, cols = [ks.box(0.0, (QUAY_TOP + QUAY_FOOT) / 2.0, 0.0, size, QUAY_TOP - QUAY_FOOT, size, "granite")], []
    cols.append(col(0.0, (QUAY_TOP + QUAY_FOOT) / 2.0, 0.0, size, QUAY_TOP - QUAY_FOOT, size))

    for yaw in (0.0, 90.0):
        shapes += ks.moved([ks.box(0.0, (1.2 + QUAY_FOOT) / 2.0, size / 2.0 + 0.02, size, 1.2 - QUAY_FOOT, 0.04, "waterline_tide"),
                            ks.box(0.1, QUAY_TOP - 0.15, size / 2.0 - 0.1, size + 0.2, 0.3, 0.6, "granite")], yaw)
        centre = ks.moved([ks.box(0.1, 0.0, size / 2.0 - 0.1, 1.0, 1.0, 1.0, "stone")], yaw)[0]["centre"]
        cols.append(col(centre[0], QUAY_TOP - 0.15, centre[2], size + 0.2, 0.3, 0.6, yaw))

    return shapes, cols


for _length in (8, 4):
    _shapes, _cols = _quay(float(_length))
    _piece("quay_%d" % _length, "quay", "granite", _shapes, _cols, [float(_length), QUAY_TOP - QUAY_FOOT, QUAY_DEPTH + 0.5])

_shapes, _cols = _quay_corner()
_piece("quay_corner", "quay", "granite", _shapes, _cols, [QUAY_DEPTH + 0.5, QUAY_TOP - QUAY_FOOT, QUAY_DEPTH + 0.5])

# Steps down a quay's face to the sea, along it (standing out 1.2 m before
# it, their back at -z against it): 13 risers of 0.2 from 0.2 under the quay
# to under the water, down toward +x, solid to the sea bed.
_steps = 13
_run = _steps * k.TREAD
k.piece("quay_steps_8", "quay", "granite", "stone",
        [k.box(-_run + (i + 0.5) * k.TREAD, (QUAY_TOP - 0.2 - 0.2 * i + QUAY_FOOT) / 2.0, 0.0, k.TREAD, QUAY_TOP - 0.2 - 0.2 * i - QUAY_FOOT, 1.2,
               "granite") for i in range(_steps)],
        size=[8.0, QUAY_TOP - QUAY_FOOT, 1.4])

_piece("bollard", "quay", "granite", [ks.lathe(0.0, 0.0, 0.0, [[0.25, 0.0], [0.25, 0.5], [0.3, 0.56], [0.2, 0.68], [0.0, 0.72]], 8, "granite")],
       [col(0.0, 0.36, 0.0, 0.5, 0.72, 0.5)], [0.6, 0.72, 0.6])


# The mole: its top a quay on the harbour side (-z), a parapet to the sea
# (+z), battered and its foot heaped with boulders; its round head.

BED = -6.0


def _boulders(rng, count, x0, x1, z0, z1, top):
    shapes, cols = [], []

    for i in range(count):
        x = x0 + (x1 - x0) * (i + 0.5) / count + rng.uniform(-0.6, 0.6)
        z = rng.uniform(z0, z1)
        radius = rng.uniform(1.0, 1.4)
        peak = rng.uniform(top - 0.5, top)
        height = peak + 1.5
        yaw = rng.uniform(0.0, 60.0)
        shapes.append(ks.prism(x, peak - height / 2.0, z, radius, height, 6, "rock", yaw=yaw, pitch=rng.uniform(-8.0, 8.0),
                               top=radius * rng.uniform(0.55, 0.75)))
        cols.append(col(x, peak - height / 2.0, z, radius * 1.3, height, radius * 1.3, yaw))

    return shapes, cols


def _mole():
    rng = random.Random(1947)
    half = MOLE_WIDTH / 2.0
    length = 8.0
    shapes = [ks.box(0.0, (MOLE_TOP + BED) / 2.0, 0.0, length, MOLE_TOP - BED, MOLE_WIDTH, "granite"),
              ks.box(0.0, (1.2 + BED) / 2.0, -half - 0.02, length, 1.2 - BED, 0.04, "waterline_tide"),
              ks.box(0.0, MOLE_TOP - 0.15, -half + 0.1, length, 0.3, 0.6, "granite"),
              ks.slab([[-length / 2.0, MOLE_TOP, half], [length / 2.0, MOLE_TOP, half], [length / 2.0, -1.0, half + 0.6], [-length / 2.0, -1.0, half + 0.6]],
                      0.3, "granite_rough", up=(0.0, 0.13, 1.0), tile=2.5),
              ks.box(0.0, MOLE_TOP + 1.0, half - 0.6, length, 2.0, 1.2, "granite_rough"),
              ks.box(0.0, PARAPET_TOP + 0.06, half - 0.6, length + 0.02, 0.12, 1.3, "ashlar_gold")]
    cols = [col(0.0, (MOLE_TOP + BED) / 2.0, 0.0, length, MOLE_TOP - BED, MOLE_WIDTH),
            col(0.0, MOLE_TOP + 1.0, half - 0.6, length, 2.0, 1.2),
            col(0.0, MOLE_TOP - 0.15, -half + 0.1, length, 0.3, 0.6)]

    for x in (-2.0, 2.0):
        shapes.append(ks.ring(x, 1.6, -half - 0.06, 0.12, 0.17, 0.04, 0.0, 360.0, 6, "iron", 180.0))

    more, more_cols = _boulders(rng, 4, -length / 2.0, length / 2.0, half + 1.2, half + 2.4, 2.1)
    return shapes + more, cols + more_cols


def _mole_head():
    rng = random.Random(1948)
    radius = 12.0
    shapes = [kit_fort._polygon_prism(radius, BED, MOLE_TOP - BED, 16, "granite_rough")]
    cols = kit_fort._polygon_cols(16, radius, BED, MOLE_TOP - BED)
    flat = 2.0 * radius * math.tan(math.pi / 16)

    # A parapet round all but its landward flats (-z, where the mole comes).
    for i in range(16):
        angle = i * 360.0 / 16

        if 225.0 < angle < 315.0:
            continue

        a = math.radians(angle)
        r = radius - 0.6
        yaw = kit_fort._yaw_out(angle)
        shapes.append(ks.box(r * math.cos(a), MOLE_TOP + 1.0, r * math.sin(a), flat + 0.1, 2.0, 1.2, "granite_rough", yaw))
        cols.append(col(r * math.cos(a), MOLE_TOP + 1.0, r * math.sin(a), flat, 2.0, 1.2, yaw))

    for i in range(10):
        angle = math.radians(i * 30.0 - 30.0)
        r = radius + 1.4
        x, z = r * math.cos(angle), r * math.sin(angle)
        more, more_cols = _boulders(rng, 1, x - 0.1, x + 0.1, z - 0.3, z + 0.3, 2.1)
        shapes += more
        cols += more_cols

    return shapes, cols


_shapes, _cols = _mole()
_piece("mole_8", "quay", "granite", _shapes, _cols, [8.0, PARAPET_TOP - BED, 2.0 * (MOLE_WIDTH / 2.0 + 3.7)], budget=700)
# The mole itself is swept along its line (layouts/harbour/mole.py); what
# stands along it is the kit's: the riprap at its seaward foot (8 m of it
# along x, about its line), a mooring ring on its harbour face (its frame
# the face's: +z out of it).
RIPRAP = MOLE_WIDTH / 2.0 + 1.8
_shapes, _cols = _boulders(random.Random(1947), 4, -4.0, 4.0, -0.6, 0.6, 2.1)
_piece("riprap_8", "quay", "rock", _shapes, _cols, [12.0, 4.0, 4.6], budget=200)
# A flight up from a quay onto the mole's root (1 m: five risers of 0.2,
# treads of 0.3), across the mole's walk; climbing to +z, its top step's
# back at z 0 (the mole's end), its foot on the quay at the pivot.
MOLE_STEPS = (13.0, 5, 0.2, 0.3)
_w, _n, _rise, _tread = MOLE_STEPS
_shapes = [ks.box(0.0, _rise * (i + 1) / 2.0, -_tread * (_n - i) + _tread / 2.0, _w, _rise * (i + 1), _tread, "granite") for i in range(_n)]
_piece("mole_steps", "quay", "granite", _shapes, [col(c["centre"][0], c["centre"][1], c["centre"][2], *c["size"]) for c in _shapes],
       [_w, _rise * _n, 2.0 * _tread * _n + 0.2])
# A post at a bridge's parapet's foot (its pivot on the quay): a granite
# pillar, its cap, a ball on it.
_post = 2.8
_shapes = [ks.box(0.0, _post / 2.0, 0.0, 0.7, _post, 0.7, "granite"), ks.box(0.0, _post + 0.07, 0.0, 0.86, 0.14, 0.86, "ashlar_gold"),
           ks.lathe(0.0, _post + 0.14, 0.0, [[0.14, 0.0], [0.22, 0.06], [0.27, 0.2], [0.27, 0.32], [0.2, 0.46], [0.0, 0.52]], 8, "ashlar_gold")]
_piece("bridge_post", "quay", "granite", _shapes, [col(0.0, _post / 2.0, 0.0, 0.7, _post, 0.7)], [0.9, _post + 0.7, 0.9])
_piece("mooring_ring", "dressing", "iron", [ks.box(0.0, 0.0, 0.03, 0.22, 0.14, 0.06, "iron"),
                                            ks.ring(0.0, -0.2, 0.08, 0.12, 0.17, 0.04, 0.0, 360.0, 6, "iron")], [], [0.4, 0.5, 0.2])
_shapes, _cols = _mole_head()
_piece("mole_head", "quay", "granite_rough", _shapes, _cols, [30.0, PARAPET_TOP - BED, 30.0], budget=1200)

# The slip: a ramp from the nave's floor (2.5) down into the water (-2),
# walled both sides from the floor down to the basin's bed (the floors
# beside it stand on the walls; no gap under them along the ramp).
_ramp = math.degrees(math.atan2(QUAY_TOP + 2.0, 8.0))
_shapes = [ks.slab([[-NAVE / 2.0, QUAY_TOP, -4.0], [NAVE / 2.0, QUAY_TOP, -4.0], [NAVE / 2.0, -2.0, 4.0], [-NAVE / 2.0, -2.0, 4.0]], 0.4, "granite",
                   tile=2.0)]
_cols = [col(0.0, (QUAY_TOP - 2.0) / 2.0 - 0.2, 0.0, NAVE, 0.4, math.hypot(8.0, QUAY_TOP + 2.0), 0.0, _ramp)]

for _s in (-1.0, 1.0):
    _x = _s * (NAVE / 2.0 + 0.3)
    _shapes += [ks.box(_x, (QUAY_TOP - 0.02 + QUAY_FOOT) / 2.0, 0.0, 0.6, QUAY_TOP - 0.02 - QUAY_FOOT, 8.0, "granite"),
                ks.box(_x - _s * 0.29, (1.2 + QUAY_FOOT) / 2.0, 0.0, 0.04, 1.2 - QUAY_FOOT, 8.0, "waterline_tide")]
    _cols.append(col(_x, (QUAY_TOP + QUAY_FOOT) / 2.0, 0.0, 0.6, QUAY_TOP - QUAY_FOOT, 8.0))

_piece("slipway_8", "quay", "granite", _shapes, _cols, [NAVE + 1.4, QUAY_TOP + 2.4, 8.0])


# The royal shipyard's naves (after Seville's Atarazanas), built of one bay:
# square brick piers on granite plinths, an impost where the arches spring;
# pointed arches a pier deep, their soffits coursed round the curve and a
# ring of voussoirs on each face; over each bay a groin vault, two pointed
# barrels meeting at sharp groins, springing PROUD up the arches' faces (so
# the arches stand out of it as bands); against the walls half piers
# (responds) and wall arches; the terrace over all. A bay's lines (piers,
# arches, the walls' faces) are NAVE apart; the opening between two piers'
# faces 2 x HALF. Floors are the level's own (its pivot on the nave's floor).

HALF = (NAVE - PIER) / 2.0
PROUD = 0.22
RING = 0.5
SEGMENTS = 12
SLAB = 0.3
PLINTH = (0.3, 0.2, 0.14)
# The brick photo's size (m): brick_coursed's UVs are metres over it.
BRICK = (1.5, 0.75)
IMPOST = (0.2, 0.2, 0.16)


def _pointed(out=0.0):
    """The arch's curve from its left foot over the apex to its right
    [(u, y, (nu, ny))]: its intrados (the arch's underside), or `out` m out
    from it (the same two centres, their radii grown); each point's normal
    turned in toward the arch's middle. The apex is in it twice, once for
    each side (its normals differ: a pointed crown)."""
    rise = APEX - SPRING
    k = ((rise / HALF) ** 2 - 1.0) / 2.0
    centre = HALF * k
    radius = HALF * (1.0 + k) + out
    # (The left side's circle about (+centre, SPRING), from where it is at
    # the pier's face, u = -HALF, or the springing's height if lower, to its
    # crossing of the middle.)
    foot = math.acos(max(-1.0, min(1.0, (-HALF - centre) / radius)))
    top = math.acos(-centre / radius)
    left = []

    for i in range(SEGMENTS // 2 + 1):
        a = foot + (top - foot) * i / (SEGMENTS // 2)
        u, y = centre + radius * math.cos(a), SPRING + radius * math.sin(a)
        left.append((u, y, (-math.cos(a), -math.sin(a))))

    left[-1] = (0.0, left[-1][1], left[-1][2])
    right = [(-u, y, (-n[0], n[1])) for u, y, n in reversed(left)]
    return left + right


def _lengths(curve):
    """How far along `curve` each point is (m)."""
    out = [0.0]

    for a, b in zip(curve, curve[1:]):
        out.append(out[-1] + math.hypot(b[0] - a[0], b[1] - a[1]))

    return out


def _web():
    """The web of a groin vault over the bay's square (2 x HALF) lying
    against its +x side: the barrel whose section is the arch's curve
    PROUD out (across z), running along x from that side in to the groins
    (|z| = x); strips between its generators, shaded round the curve, its
    bricks coursed along them."""
    curve = _pointed(PROUD)
    s = _lengths(curve)
    shapes = []

    for i in range(len(curve) - 1):
        (z0, y0, n0), (z1, y1, n1) = curve[i], curve[i + 1]

        if abs(z0 - z1) < 1e-9 and abs(y0 - y1) < 1e-9:
            continue

        # (Under, its normals down into the bay: (0, ny, nu) as the curve's
        # turned in.)
        a, b, c, d = [HALF, y0, z0], [HALF, y1, z1], [abs(z1), y1, z1], [abs(z0), y0, z0]
        na, nb = [0.0, n0[1], n0[0]], [0.0, n1[1], n1[0]]
        uvs = [[p[0] / BRICK[0], t / BRICK[1]] for p, t in ((a, s[i]), (b, s[i + 1]), (c, s[i + 1]), (d, s[i]))]
        points, normals = [a, b, c, d], [na, nb, nb, na]

        if abs(c[0] - d[0]) < 1e-9 and abs(c[2] - d[2]) < 1e-9:
            points, uvs, normals = points[:3], uvs[:3], normals[:3]

        if ks._normal(points)[1] > 0.0:
            points, uvs, normals = points[::-1], uvs[::-1], normals[::-1]

        shapes.append(ks.polygon(points, "brick_coursed", uvs=uvs, normals=normals))

    return shapes


def _band(near, far, faces):
    """An arch over the opening between two piers' faces (u -HALF..HALF,
    along x), its soffit from z `near` to `far`; its faces (`faces`: the
    sides drawn, "near" and/or "far") from the soffit up to the terrace:
    a ring of voussoirs RING deep round the curve, plain brick over it. No
    top (the terrace's slab) and no ends (in the piers' heads)."""
    inner = _pointed()
    ring = _pointed(RING)
    s = _lengths(inner)
    shapes = []

    for i in range(len(inner) - 1):
        (u0, y0, n0), (u1, y1, n1) = inner[i], inner[i + 1]

        if abs(u0 - u1) < 1e-9 and abs(y0 - y1) < 1e-9:
            continue

        # The soffit: across the band, round the curve (its bricks along it).
        points = [[u0, y0, near], [u1, y1, near], [u1, y1, far], [u0, y0, far]]
        normals = [[n0[0], n0[1], 0.0], [n1[0], n1[1], 0.0], [n1[0], n1[1], 0.0], [n0[0], n0[1], 0.0]]
        uvs = [[t / BRICK[0], z / BRICK[1]] for t, z in ((s[i], near), (s[i + 1], near), (s[i + 1], far), (s[i], far))]

        if geo.dot(ks._normal(points), [(n0[0] + n1[0]) / 2.0, (n0[1] + n1[1]) / 2.0, 0.0]) < 0.0:
            points, normals, uvs = points[::-1], normals[::-1], uvs[::-1]

        shapes.append(ks.polygon(points, "brick_coursed", uvs=uvs, normals=normals))

        for side, z in (("near", near), ("far", far)):
            if side not in faces:
                continue

            look = 1.0 if z > (near + far) / 2.0 else -1.0
            (r0, q0, _), (r1, q1, _) = ring[i], ring[i + 1]
            # The voussoirs: their bricks laid out from the curve.
            v = [[u0, y0, z], [u1, y1, z], [r1, q1, z], [r0, q0, z]]
            v_uvs = [[r / BRICK[0], t / BRICK[1]] for r, t in ((0.0, s[i]), (0.0, s[i + 1]), (RING, s[i + 1]), (RING, s[i]))]
            # Over them, up to the terrace.
            o = [[r0, q0, z], [r1, q1, z], [r1, TERRACE, z], [r0, TERRACE, z]]

            for quad, quad_uvs in ((v, v_uvs), (o, None)):
                if ks._normal(quad)[2] * look < 0.0:
                    quad = quad[::-1]
                    quad_uvs = quad_uvs[::-1] if quad_uvs else None

                shapes.append(ks.polygon(quad, "brick_coursed" if quad_uvs else "brick", uvs=quad_uvs))

    return shapes


def _pier_shapes(x0, x1, z0, z1, foot=0.0):
    """A pier's shaft over x0..x1, z0..z1 (from `foot`, under the floor
    where it stands in water), its plinth on the floor and its impost at
    the springing, each standing out round its open sides (a respond's
    against a wall stay flush with it: a side at the wall's face is not
    stood out). The head over the springing is hidden in the arches."""
    shapes = [ks.box((x0 + x1) / 2.0, (foot + SPRING) / 2.0, (z0 + z1) / 2.0, x1 - x0, SPRING - foot, z1 - z0, "brick")]

    if foot < 0.0:
        shapes.append(ks.box((x0 + x1) / 2.0, foot / 2.0, (z0 + z1) / 2.0, x1 - x0 + 0.3, -foot, z1 - z0 + 0.3, "granite_rough"))

    for y0, height, grow, slot in ((0.0, PLINTH[0], PLINTH[1], "granite"), (PLINTH[0], PLINTH[2], PLINTH[1] / 2.0, "granite"),
                                   (SPRING - IMPOST[0], IMPOST[0], IMPOST[1], "ashlar_gold"),
                                   (SPRING - IMPOST[0] - IMPOST[2], IMPOST[2], IMPOST[1] / 2.0, "ashlar_gold")):
        # (Grown on the sides away from a wall: a respond's wall side at
        # x0 = 0 or z0 = 0 stays put.)
        a0 = x0 - (0.0 if x0 == 0.0 and x1 < PIER else grow)
        a1 = x1 + grow
        b0 = z0 - (0.0 if z0 == 0.0 else grow)
        b1 = z1 + grow
        shapes.append(ks.box((a0 + a1) / 2.0, y0 + height / 2.0, (b0 + b1) / 2.0, a1 - a0, height, b1 - b0, slot))

    return shapes


def _pier(foot=0.0):
    h = PIER / 2.0
    return _pier_shapes(-h, h, -h, h, foot), [col(0.0, TERRACE / 2.0, 0.0, PIER, TERRACE, PIER)]


def _respond(foot=0.0):
    """Half a pier against a wall (its face at z 0, the respond out to +z),
    PIER wide along it."""
    h = PIER / 2.0
    return _pier_shapes(-h, h, 0.0, h, foot), [col(0.0, TERRACE / 2.0, h / 2.0, PIER, TERRACE, h)]


def _corner_respond():
    """A quarter of a pier in the corner of two walls (their faces at x 0
    and z 0)."""
    h = PIER / 2.0
    return _pier_shapes(0.0, h, 0.0, h), [col(h / 2.0, TERRACE / 2.0, h / 2.0, h, TERRACE, h)]


def _arch(yaw):
    shapes = ks.moved(_band(-PIER / 2.0, PIER / 2.0, ("near", "far")), yaw)
    along = yaw == 0.0
    return shapes, [col(0.0, (APEX + TERRACE) / 2.0, 0.0, 2.0 * HALF if along else PIER, TERRACE - APEX, PIER if along else 2.0 * HALF)]


def _wall_arch():
    """A wall arch (formeret): half a band against a wall (its face at z 0,
    out to +z), along x: a vault's web against the wall springs from it."""
    h = PIER / 2.0
    return _band(0.0, h, ("far",)), [col(0.0, (APEX + TERRACE) / 2.0, h / 2.0, 2.0 * HALF, TERRACE - APEX, h)]


def _vault():
    """The groin vault over the bay's open square, its four webs; the
    terrace's slab over the whole bay."""
    shapes = []

    for yaw in (0.0, 90.0, 180.0, 270.0):
        shapes += ks.moved(_web(), yaw)

    shapes.append(ks.box(0.0, TERRACE - SLAB / 2.0, 0.0, NAVE, SLAB, NAVE, "granite"))
    return shapes, [col(0.0, (APEX + TERRACE) / 2.0, 0.0, NAVE, TERRACE - APEX, NAVE)]


def _terrace_edge():
    """The terrace's open edge over an outer arcade (its line at z 0, out
    to +z): the band's top paved, a cornice under it (a brick course,
    dentils, a granite coping standing out)."""
    h = PIER / 2.0
    shapes = [ks.box(0.0, TERRACE - SLAB / 2.0, h / 2.0, NAVE, SLAB, h, "granite"),
              ks.box(0.0, TERRACE - 0.08, h + 0.12, NAVE, 0.16, 0.24, "granite"),
              ks.box(0.0, TERRACE - 0.62, h + 0.05, NAVE, 0.14, 0.1, "brick")]

    for i in range(21):
        shapes.append(ks.box(-NAVE / 2.0 + 0.2 + i * 0.4, TERRACE - 0.36, h + 0.06, 0.2, 0.2, 0.12, "brick"))

    return shapes, []


def _end_wall():
    shapes = ks.arched_wall(NAVE, TERRACE, BAND, 1.2, 10.4, 0.6, 9.0, "brick")
    cols = [col(-(NAVE / 2.0 + 0.6) / 2.0, TERRACE / 2.0, 0.0, NAVE / 2.0 - 0.6, TERRACE, BAND),
            col((NAVE / 2.0 + 0.6) / 2.0, TERRACE / 2.0, 0.0, NAVE / 2.0 - 0.6, TERRACE, BAND),
            col(0.0, 4.5, 0.0, 1.2, 9.0, BAND), col(0.0, (11.0 + TERRACE) / 2.0, 0.0, 1.2, TERRACE - 11.0, BAND)]
    return shapes, cols


# (Below the floor, a pier or respond standing in the slip's basin: its
# foot on the basin's bed.)
DEEP = -5.5

_shapes, _cols = _pier()
_piece("nave_pier", "harbour", "brick", _shapes, _cols, [PIER + 0.4, TERRACE, PIER + 0.4])
_shapes, _cols = _pier(DEEP)
_piece("nave_pier_deep", "harbour", "brick", _shapes, _cols, [PIER + 0.4, TERRACE - DEEP, PIER + 0.4])
_shapes, _cols = _respond()
_piece("nave_respond", "harbour", "brick", _shapes, _cols, [PIER + 0.4, TERRACE, PIER + 0.4])
_shapes, _cols = _respond(DEEP)
_piece("nave_respond_deep", "harbour", "brick", _shapes, _cols, [PIER + 0.4, TERRACE - DEEP, PIER + 0.4])
_shapes, _cols = _corner_respond()
_piece("nave_respond_corner", "harbour", "brick", _shapes, _cols, [PIER + 0.4, TERRACE, PIER + 0.4])
_shapes, _cols = _arch(0.0)
_piece("nave_arch_x", "harbour", "brick", _shapes, _cols, [NAVE, TERRACE, PIER])
_shapes, _cols = _arch(90.0)
_piece("nave_arch_z", "harbour", "brick", _shapes, _cols, [PIER, TERRACE, NAVE])
_shapes, _cols = _wall_arch()
_piece("nave_wall_arch", "harbour", "brick", _shapes, _cols, [NAVE, TERRACE, PIER])
_shapes, _cols = _vault()
_piece("nave_vault", "harbour", "brick", _shapes, _cols, [NAVE, TERRACE - SPRING, NAVE])
# (Under the terrace, the vaults and the arches between bays never see the
# moon: kit_recipes.roofed. The east arcade's arches face the night.)
for _name in ("nave_vault", "nave_arch_x"):
    k.PIECES[_name]["roofed"] = True

_shapes, _cols = _terrace_edge()
_piece("nave_terrace_edge", "harbour", "granite", _shapes, _cols, [NAVE, 0.7, PIER + 0.6])
_shapes, _cols = _end_wall()
_piece("nave_end_wall", "harbour", "brick", _shapes, _cols, [NAVE, TERRACE, BAND])

# (Hundreds of them, found by no one by name: joined at export, a mesh a
# cell (kit_recipes.merge_groups), a draw a material instead of a draw a
# piece.)
for _name in ("nave_pier", "nave_pier_deep", "nave_respond", "nave_respond_deep", "nave_respond_corner", "nave_arch_x", "nave_arch_z",
              "nave_wall_arch", "nave_vault", "nave_terrace_edge", "nave_end_wall"):
    k.PIECES[_name]["merge"] = True


# A galley half-built on the stocks: its keel on blocks, its frames up (the
# middle planked below), stem and stern posts, a scaffold both sides with
# planks at 2.2 and 4.4 (a mantle each), two ladders.

GALLEY = (40.0, 4.4)
# The scaffold stands this far out from the galley's side (it and the galley
# fit a nave's 7.2 m between its piers).
SCAFFOLD = 0.8


def _galley():
    length, beam = GALLEY
    shapes = [ks.box(0.0, 1.1, 0.0, length - 4.0, 0.3, 0.35, "hull_bare")]
    cols = [col(0.0, 2.1, 0.0, length - 10.0, 2.4, beam - 1.6, surface="wood")]

    for x in range(-14, 16, 4):
        shapes.append(ks.box(float(x), 0.5, 0.0, 0.8, 1.0, 1.2, "beam"))

    for side in (-1.0, 1.0):
        shapes.append(ks.box(side * (length / 2.0 - 3.0), 2.8, 0.0, 0.3, 3.8, 0.3, "hull_bare", 0.0, 0.0, side * -25.0))

    for i in range(14):
        x = -length / 2.0 + 4.0 + i * (length - 8.0) / 13.0
        r = max(0.8, beam / 2.0 * math.sqrt(max(0.0, 1.0 - (x / (length / 2.0 - 1.0)) ** 2)))
        shapes.append(ks.ring(x, 1.2 + r, 0.0, r, r + 0.18, 0.22, 150.0, 390.0, 6, "hull_bare", 90.0))

    for side in (-1.0, 1.0):
        z0, z1 = side * 0.2, side * (beam / 2.0 - 0.2)
        shapes.append(ks.slab([[-8.0, 1.25, z0], [8.0, 1.25, z0], [8.0, 2.4, z1], [-8.0, 2.4, z1]], 0.08, "hull_bare",
                              up=(0.0, 1.0, side * 0.8), tile=2.0))
        # The scaffold: poles, and its planks.
        z = side * (beam / 2.0 + SCAFFOLD)

        for x in range(-16, 17, 4):
            shapes.append(ks.prism(float(x), 2.6, z + side * 0.35, 0.09, 5.2, 4, "timber", caps=False))

        for y in PLANKS:
            shapes.append(ks.box(0.0, y - 0.05, z, length - 4.0, 0.1, 0.7, "boards"))
            cols.append(col(0.0, y - 0.05, z, length - 4.0, 0.1, 0.7, surface="wood"))

    # Two ladders up the +z scaffold, from the floor to the upper planks.
    climbs = []
    z = beam / 2.0 + SCAFFOLD + 0.55

    for x in (-12.0, 12.0):
        for dx in (-0.25, 0.25):
            shapes.append(ks.box(x + dx, PLANKS[1] / 2.0 + 0.3, z, 0.06, PLANKS[1] + 0.6, 0.06, "timber"))

        for rung in range(int(PLANKS[1] / 0.3)):
            shapes.append(ks.prism(x, 0.3 + rung * 0.3, z, 0.025, 0.5, 3, "timber", roll=90.0, caps=False))

        climbs.append([x, (PLANKS[1] + 0.4) / 2.0, z, 0.7, PLANKS[1] + 0.4, 0.5, 0.0])

    return shapes, cols, climbs


_shapes, _cols, _climbs = _galley()
_piece("galley_stocks", "harbour", "hull_bare", _shapes, _cols, [GALLEY[0], 5.2, 2.0 * (GALLEY[1] / 2.0 + 2.0)], budget=2500, surface="wood")
k.PIECES["galley_stocks"]["climbs"] = _climbs


# A timber jib crane with its treadwheel.

def _crane():
    shapes = [ks.box(0.0, 0.15, 0.0, 3.0, 0.3, 3.0, "beam"), ks.prism(0.0, 3.8, 0.0, 0.28, 7.0, 6, "timber"),
              ks.box(0.0, 6.5, 2.2, 0.26, 0.26, 6.2, "timber", 0.0, -40.0, 0.0), ks.box(0.0, 3.2, 3.9, 0.03, 4.8, 0.03, "rope"),
              ks.ring(0.0, 0.8, 3.9, 0.1, 0.15, 0.05, 180.0, 360.0, 3, "iron"),
              ks.ring(-1.3, 2.2, 0.0, 1.8, 2.0, 1.1, 0.0, 360.0, 12, "timber", 90.0)]

    for angle in range(0, 180, 30):
        shapes.append(ks.box(-1.3, 2.2, 0.0, 0.1, 3.6, 0.1, "timber", 0.0, float(angle), 0.0))

    for yaw in (0.0, 90.0, 180.0, 270.0):
        shapes += ks.moved([ks.box(0.0, 1.3, 0.8, 0.16, 2.4, 0.16, "timber", 0.0, 30.0, 0.0)], yaw)

    return shapes, [col(0.0, 0.15, 0.0, 3.0, 0.3, 3.0), col(0.0, 3.8, 0.0, 0.5, 7.0, 0.5), col(-1.3, 2.2, 0.0, 1.1, 4.0, 4.0)]


_shapes, _cols = _crane()
_piece("crane_jib", "harbour", "timber", _shapes, _cols, [4.0, 10.0, 9.4], budget=900, surface="wood")
# The wheel's movement barrier fills its center; it cannot hide the view
# through the rim and spokes. The base and upright keep their usual policy.
k.PIECES["crane_jib"]["occlusion_exclude"] = [2]


# The quays' dressing.

def _dressing(name, slot, shapes, cols, size, surface="wood", budget=400):
    _piece(name, "dressing", slot, shapes, cols, size, budget=budget, surface=surface)


def _anchor(scale):
    s = scale
    return [ks.box(0.0, 0.12 * s, 0.0, 2.4 * s, 0.14 * s, 0.14 * s, "iron"),
            ks.box(1.0 * s, 0.1 * s, 0.45 * s, 0.12 * s, 0.12 * s, 1.1 * s, "iron", 40.0),
            ks.box(1.0 * s, 0.1 * s, -0.45 * s, 0.12 * s, 0.12 * s, 1.1 * s, "iron", -40.0),
            ks.box(1.3 * s, 0.1 * s, 0.85 * s, 0.35 * s, 0.05 * s, 0.25 * s, "iron", 40.0),
            ks.box(1.3 * s, 0.1 * s, -0.85 * s, 0.35 * s, 0.05 * s, 0.25 * s, "iron", -40.0),
            ks.box(-1.0 * s, 0.14 * s, 0.0, 0.25 * s, 0.25 * s, 2.0 * s, "wood_old"),
            ks.ring(-1.3 * s, 0.05 * s, 0.0, 0.14 * s, 0.2 * s, 0.05 * s, 0.0, 360.0, 6, "iron", 0.0)]


_dressing("anchor_big", "iron", _anchor(1.0), [col(0.0, 0.25, 0.0, 2.8, 0.5, 2.0, surface="metal")], [2.8, 0.5, 2.2], surface="metal")
_dressing("anchor_small", "iron", _anchor(0.5), [], [1.4, 0.3, 1.1], surface="metal")
_dressing("net_hung", "net", [ks.prism(-1.5, 1.25, 0.0, 0.06, 2.5, 6, "timber"), ks.prism(1.5, 1.25, 0.0, 0.06, 2.5, 6, "timber"),
                              ks.box(0.0, 2.45, 0.0, 3.2, 0.08, 0.08, "timber"), ks.card(0.0, 1.45, 0.02, 3.0, 1.9, "net")], [], [3.3, 2.5, 0.4])
_dressing("net_pile", "rope", [ks.lathe(0.0, 0.0, 0.0, [[0.9, 0.0], [0.8, 0.25], [0.4, 0.45], [0.0, 0.5]], 8, "rope"),
                               ks.card(0.0, 0.5, 0.0, 1.6, 1.4, "net", 0.0, -85.0)], [], [2.0, 0.6, 2.0])
_dressing("basket_fish", "straw", [ks.lathe(0.0, 0.0, 0.0, [[0.24, 0.0], [0.32, 0.3], [0.34, 0.4], [0.3, 0.4]], 8, "straw", caps=False),
                                   ks.disc(0.0, 0.3, 0.0, 0.3, 8, "pewter", pitch=-90.0)], [], [0.8, 0.45, 0.8])
_dressing("oars_stack", "timber", [ks.box(0.0, 0.05 + i * 0.07, -0.3 + i * 0.15, 4.0, 0.06, 0.06, "timber", 0.0, 0.0, 2.0 * i)
                                   for i in range(5)] + [ks.box(1.8, 0.05 + i * 0.07, -0.3 + i * 0.15, 0.8, 0.02, 0.14, "timber") for i in range(5)],
          [], [4.2, 0.5, 1.0])
_dressing("crate_stack", "wood_old", [ks.box(-0.45, 0.4, 0.0, 0.8, 0.8, 0.8, "wood_old"), ks.box(0.45, 0.4, 0.1, 0.8, 0.8, 0.8, "wood_old", 8.0),
                                      ks.box(-0.2, 1.1, 0.05, 0.6, 0.6, 0.6, "wood_old", -12.0)],
          [col(-0.45, 0.4, 0.0, 0.8, 0.8, 0.8, surface="wood"), col(0.45, 0.4, 0.1, 0.8, 0.8, 0.8, 8.0, surface="wood"),
           col(-0.2, 1.1, 0.05, 0.6, 0.6, 0.6, -12.0, surface="wood")], [1.9, 1.4, 1.1])
_dressing("rope_coil", "rope_coil", [ks.disc(0.0, 0.08, 0.0, 0.45, 8, "rope_coil", pitch=-90.0),
                                     ks.lathe(0.0, 0.0, 0.0, [[0.46, 0.0], [0.46, 0.08]], 8, "rope", caps=False)], [], [1.0, 0.1, 1.0])
_dressing("lobster_pots", "straw", [ks.lathe(x, 0.0, z, [[0.3, 0.0], [0.3, 0.25], [0.2, 0.4], [0.0, 0.45]], 8, "straw")
                                    for x, z in ((-0.35, 0.0), (0.35, 0.1), (0.0, 0.6))], [], [1.4, 0.5, 1.4])
_dressing("barrel_row", "wood_old", [ks.prism(x, 0.45, 0.0, 0.35, 0.9, 8, "wood_old", rings=[[0.5, 0.4]]) for x in (-0.8, 0.0, 0.8)]
          + [ks.lathe(x, 0.12, 0.0, [[0.37, 0.0], [0.37, 0.06]], 8, "iron", caps=False) for x in (-0.8, 0.0, 0.8)],
          [col(0.0, 0.45, 0.0, 2.4, 0.9, 0.8, surface="wood")], [2.5, 0.9, 0.9])
_dressing("cargo_bales", "burlap", [ks.box(x, 0.35 + y, 0.0, 1.0, 0.7, 0.7, "burlap", yaw) for x, y, yaw in
                                    ((-0.55, 0.0, 0.0), (0.55, 0.0, 5.0), (0.0, 0.7, -8.0), (1.6, 0.0, 90.0))]
          + [ks.box(x, 0.35, 0.0, 0.05, 0.72, 0.72, "rope") for x in (-0.8, -0.3, 0.3, 0.8)],
          [col(0.0, 0.35, 0.0, 2.1, 0.7, 0.7, surface="wood"), col(0.0, 1.05, 0.0, 1.0, 0.7, 0.7, -8.0, surface="wood"),
           col(1.6, 0.35, 0.0, 0.7, 0.7, 1.0, surface="wood")], [4.0, 1.4, 1.1])


# The yard at work, nave by nave (each piece's length along its z, the
# naves' way; its foot on the floor): squared timbers and planks stacked on
# their bearers, a mast on trestles, a carpenter's bench and his tools, a
# log on a saw trestle, a new keel on its blocks with its first frames, a
# sail spread out to be sewn, tar in barrels, blocks and tackle hung from an
# arch's crown, a smith's forge, oars racked.

def _timber_stack():
    shapes, cols = [], []

    for z in (-2.6, 0.0, 2.6):
        shapes.append(ks.box(0.0, 0.08, z, 1.9, 0.16, 0.2, "beam"))

    for layer in range(3):
        y = 0.16 + layer * 0.38
        n = 4 - (layer % 2)

        for i in range(n):
            x = (i - (n - 1) / 2.0) * 0.42
            shapes.append(ks.box(x, y + 0.17, 0.0, 0.34, 0.34, 6.0 - layer * 0.3, "timber"))

        if layer < 2:
            for z in (-2.2, 0.0, 2.2):
                shapes.append(ks.box(0.0, y + 0.36, z, 1.8, 0.04, 0.08, "wood_old"))

    cols.append(col(0.0, 0.62, 0.0, 1.8, 1.24, 6.0, surface="wood"))
    return shapes, cols


def _plank_stack():
    shapes = [ks.box(0.0, 0.07, z, 1.6, 0.14, 0.16, "beam") for z in (-2.0, 0.0, 2.0)]

    for layer in range(8):
        y = 0.14 + layer * 0.09

        for i in range(4):
            shapes.append(ks.box((i - 1.5) * 0.36, y + 0.03, 0.0, 0.32, 0.06, 5.0 - (layer % 3) * 0.2, "boards"))

        if layer % 3 == 2:
            for z in (-1.8, 0.0, 1.8):
                shapes.append(ks.box(0.0, y + 0.075, z, 1.5, 0.03, 0.05, "wood_old"))

    return shapes, [col(0.0, 0.5, 0.0, 1.5, 1.0, 5.0, surface="wood")]


def _mast_trestles():
    length = 14.0
    shapes = [ks.prism(0.0, 1.15, 0.0, 0.36, length, 8, "timber", 0.0, 90.0, 0.0, top=0.24),
              ks.ring(0.0, 1.15, -length / 2.0 + 1.0, 0.36, 0.4, 0.12, 0.0, 360.0, 8, "iron")]

    for z in (-4.0, 4.0):
        for s in (-1.0, 1.0):
            shapes.append(ks.box(s * 0.35, 0.4, z, 0.12, 0.95, 0.12, "beam", 0.0, 0.0, s * 20.0))

        shapes.append(ks.box(0.0, 0.78, z, 1.1, 0.14, 0.16, "beam"))

    shapes += [ks.box(0.4, 0.05, -1.5, 0.3, 0.1, 0.5, "wood_old", 30.0), ks.box(-0.3, 0.04, 2.5, 0.06, 0.02, 0.9, "iron", 70.0)]
    return shapes, [col(0.0, 0.75, 0.0, 1.0, 1.5, length, surface="wood")]


def _workbench():
    """A carpenter's bench (along z): its legs and rails, a vice, a saw, an
    adze, a mallet, a plane, a square, offcuts under it."""
    w, d, h = 0.75, 2.6, 0.85
    shapes = [ks.box(0.0, h - 0.05, 0.0, w, 0.1, d, "wood_old"), ks.box(0.0, 0.25, 0.0, w - 0.1, 0.05, d - 0.3, "wood_old")]
    shapes += [ks.box(sx * (w / 2.0 - 0.08), (h - 0.1) / 2.0, sz * (d / 2.0 - 0.15), 0.1, h - 0.1, 0.1, "wood_old") for sx in (-1.0, 1.0) for sz in (-1.0, 1.0)]
    shapes += [ks.box(w / 2.0 + 0.05, h - 0.12, d / 2.0 - 0.35, 0.08, 0.22, 0.3, "wood_old"),
               ks.prism(w / 2.0 + 0.12, h - 0.12, d / 2.0 - 0.35, 0.02, 0.4, 6, "iron", 0.0, 0.0, 90.0),
               ks.box(-0.1, h + 0.01, -0.6, 0.18, 0.01, 0.65, "iron", 12.0), ks.box(-0.1, h + 0.04, -0.98, 0.1, 0.07, 0.14, "wood_old", 12.0),
               ks.box(0.15, h + 0.03, 0.2, 0.06, 0.05, 0.45, "timber", -20.0), ks.box(0.2, h + 0.06, 0.42, 0.14, 0.08, 0.06, "iron", -20.0),
               ks.box(-0.15, h + 0.05, 0.75, 0.09, 0.1, 0.28, "wood_old"), ks.box(-0.15, h + 0.12, 0.7, 0.03, 0.05, 0.03, "wood_old"),
               ks.prism(0.12, h + 0.06, -0.15, 0.06, 0.18, 6, "wood_old", 0.0, 0.0, 90.0), ks.box(0.12, h + 0.06, -0.3, 0.03, 0.03, 0.28, "timber"),
               ks.box(-0.2, h + 0.008, 1.05, 0.3, 0.01, 0.03, "iron"), ks.box(-0.06, h + 0.008, 0.93, 0.03, 0.01, 0.25, "iron"),
               ks.box(0.0, 0.32, -0.6, 0.12, 0.1, 0.9, "timber", 15.0), ks.box(0.1, 0.32, 0.5, 0.1, 0.08, 0.6, "timber", -25.0)]
    return shapes, [col(0.0, h / 2.0, 0.0, w, h, d, surface="wood")]


def _saw_trestle():
    """A log on a high trestle over a sawyer's stand, the long saw through
    it, the cut planks leaning by it."""
    shapes = [ks.prism(0.0, 1.95, 0.0, 0.42, 6.0, 8, "bark", 0.0, 90.0, 0.0)]

    for z in (-2.2, 2.2):
        for s in (-1.0, 1.0):
            shapes.append(ks.box(s * 0.55, 0.85, z, 0.14, 1.75, 0.14, "beam", 0.0, 0.0, s * 15.0))

        shapes.append(ks.box(0.0, 1.55, z, 1.4, 0.16, 0.18, "beam"))

    shapes += [ks.box(0.0, 1.6, 0.8, 0.02, 2.2, 0.22, "iron"), ks.box(0.0, 2.72, 0.8, 0.5, 0.06, 0.06, "timber"), ks.box(0.0, 0.48, 0.8, 0.5, 0.06, 0.06, "timber")]

    for i in range(3):
        shapes.append(ks.box(-0.9 - i * 0.07, 1.2, -1.0 + i * 0.4, 0.05, 2.4, 0.3, "boards", 0.0, 0.0, 12.0))

    return shapes, [col(0.0, 1.0, 0.0, 1.4, 2.0, 6.0, surface="wood")]


def _keel_frames():
    """A new hull begun: her keel on its blocks, stem and sternpost raised,
    her first frames up and shored."""
    length = 16.0
    shapes = [ks.box(0.0, 0.85, 0.0, 0.36, 0.42, length, "hull_bare")]

    for z in range(-7, 8, 2):
        shapes.append(ks.box(0.0, 0.32, float(z), 0.9, 0.64, 0.5, "beam"))

    for s in (-1.0, 1.0):
        shapes.append(ks.box(0.0, 2.6, s * (length / 2.0 + 0.4), 0.3, 3.6, 0.3, "hull_bare", 0.0, s * 18.0, 0.0))

    for i, z in enumerate((-4.5, -2.5, -0.5, 1.5, 3.5)):
        r = 2.1 - abs(z) * 0.12
        shapes.append(ks.ring(0.0, 1.05 + r, z, r, r + 0.18, 0.2, 200.0, 340.0, 6, "hull_bare", 90.0))

        for s in (-1.0, 1.0):
            shapes.append(ks.box(s * (r + 0.9), 1.4, z, 0.1, 2.9, 0.1, "timber", 0.0, 0.0, s * 35.0))

    shapes.append(ks.box(0.0, 3.0, 0.0, 0.14, 0.14, 9.0, "timber"))
    return shapes, [col(0.0, 0.55, 0.0, 0.9, 1.1, length, surface="wood")]


def _sail_spread():
    """A mainsail spread on the floor to be sewn: the canvas, a bench, a
    sailmaker's palm and needles, a bolt of rope, a roll of new cloth."""
    shapes = [ks.card(0.0, 0.01, 0.0, 5.0, 7.0, "sailcloth", 0.0, -90.0), ks.box(0.0, 0.015, 3.45, 5.0, 0.02, 0.12, "rope"),
              ks.box(2.1, 0.22, -1.0, 0.4, 0.04, 1.8, "wood_old"), ks.box(2.1, 0.1, -1.6, 0.35, 0.2, 0.06, "wood_old"),
              ks.box(2.1, 0.1, -0.4, 0.35, 0.2, 0.06, "wood_old"), ks.box(2.1, 0.25, -1.2, 0.08, 0.03, 0.12, "leather"),
              ks.prism(1.2, 0.18, 2.5, 0.18, 1.6, 8, "sailcloth", 0.0, 0.0, 90.0), ks.disc(-1.6, 0.06, -2.4, 0.35, 8, "rope_coil", pitch=-90.0)]
    return shapes, []


def _tar_barrels():
    shapes = []

    for x, z in ((-0.5, 0.0), (0.4, 0.15), (0.0, 0.85)):
        shapes += [ks.prism(x, 0.45, z, 0.35, 0.9, 8, "wood_old", rings=[[0.5, 0.39]]), ks.disc(x, 0.905, z, 0.33, 8, "pitch", pitch=-90.0),
                   ks.lathe(x, 0.12, z, [[0.37, 0.0], [0.37, 0.06]], 8, "iron", caps=False)]

    shapes.append(ks.box(0.0, 0.93, 0.85, 0.06, 0.04, 0.9, "wood_old", 30.0))
    return shapes, [col(-0.05, 0.45, 0.4, 1.6, 0.9, 1.6, surface="wood")]


def _block_tackle():
    """Blocks and tackle hung from an arch's crown (its top at the pivot's
    APEX): the fall and its blocks, a hook with a timber slung in it."""
    top = APEX
    shapes = [ks.box(0.0, top - 0.25, 0.0, 0.22, 0.45, 0.16, "timber"), ks.disc(0.12, top - 0.25, 0.0, 0.14, 8, "iron", 90.0)]

    for x in (-0.06, 0.06):
        shapes.append(ks.box(x, (top - 0.45 + 4.3) / 2.0, 0.0, 0.025, top - 0.45 - 4.3, 0.025, "rope"))

    shapes += [ks.box(0.0, 4.15, 0.0, 0.2, 0.36, 0.15, "timber"), ks.ring(0.0, 3.7, 0.0, 0.08, 0.12, 0.04, 180.0, 360.0, 4, "iron", 90.0),
               ks.box(0.4, (top - 0.45 + 2.0) / 2.0, 0.08, 0.02, top - 0.45 - 2.0, 0.02, "rope", 0.0, 0.0, 3.0),
               ks.box(0.0, 3.35, 0.0, 0.3, 0.3, 4.5, "timber", 0.0, 8.0, 0.0)]

    for z in (-1.2, 1.2):
        shapes.append(ks.box(0.0, 3.55, z * 0.5, 0.02, 0.4, 0.02, "rope", 0.0, z * 25.0, 0.0))

    return shapes, []


def _forge():
    """A smith's forge in a nave's corner: its brick hearth and hood, the
    coals glowing, bellows, an anvil on its stump, a quench tub, tongs."""
    shapes = [ks.box(0.0, 0.45, 0.0, 1.6, 0.9, 1.4, "brick"), ks.box(0.0, 0.92, 0.0, 1.0, 0.06, 0.8, "glass_lit"),
              ks.box(0.0, 2.4, -0.2, 1.6, 0.9, 1.0, "brick"), ks.box(0.0, 3.6, -0.4, 0.6, 1.6, 0.6, "brick"),
              ks.box(-1.05, 0.9, 0.0, 0.5, 0.3, 0.8, "leather", 0.0, 0.0, 10.0), ks.box(-1.05, 1.1, 0.4, 0.06, 0.06, 0.6, "wood_old"),
              ks.prism(0.0, 0.35, 1.6, 0.22, 0.7, 6, "bark"), ks.box(0.0, 0.8, 1.6, 0.6, 0.2, 0.2, "iron"),
              ks.prism(0.3, 0.8, 1.6, 0.09, 0.3, 4, "iron", 0.0, 0.0, 90.0, top=0.0),
              ks.prism(1.2, 0.25, 1.3, 0.38, 0.5, 8, "wood_old", rings=[[0.5, 0.4]]), ks.disc(1.2, 0.46, 1.3, 0.34, 8, "glass_dark", pitch=-90.0),
              ks.box(0.4, 0.95, 0.5, 0.04, 0.02, 0.6, "iron", 25.0)]
    return shapes, [col(0.0, 0.45, 0.0, 1.6, 0.9, 1.4), col(0.0, 0.35, 1.6, 0.6, 0.7, 0.4, surface="metal"), col(1.2, 0.25, 1.3, 0.8, 0.5, 0.8, surface="wood")]


def _oars_rack():
    """A rack of oars for the galleys, standing against its rail."""
    shapes = [ks.box(0.0, 2.2, 0.0, 0.12, 0.12, 4.0, "beam")]

    for z in (-1.9, 1.9):
        shapes.append(ks.box(0.0, 1.1, z, 0.14, 2.2, 0.14, "beam"))

    for i in range(11):
        z = -1.7 + i * 0.34
        shapes.append(ks.box(0.25, 2.2, z, 0.06, 4.6, 0.06, "timber", 0.0, 0.0, -8.0))
        shapes.append(ks.box(0.48, 0.45, z, 0.03, 0.9, 0.18, "timber", 0.0, 0.0, -8.0))

    return shapes, [col(0.2, 1.2, 0.0, 0.6, 2.4, 4.0, surface="wood")]


for _name, _maker, _slot, _size, _budget in (
        ("timber_stack", _timber_stack, "timber", [2.0, 1.3, 6.2], 400), ("plank_stack", _plank_stack, "boards", [1.7, 1.0, 5.2], 600),
        ("mast_trestles", _mast_trestles, "timber", [1.4, 1.6, 14.4], 300), ("workbench", _workbench, "wood_old", [1.1, 1.0, 2.8], 400),
        ("saw_trestle", _saw_trestle, "bark", [2.2, 2.9, 6.2], 400), ("keel_frames", _keel_frames, "hull_bare", [7.8, 4.6, 18.4], 800),
        ("sail_spread", _sail_spread, "sailcloth", [5.2, 0.5, 7.2], 200), ("tar_barrels", _tar_barrels, "wood_old", [1.9, 1.0, 2.6], 300),
        ("block_tackle", _block_tackle, "timber", [1.0, APEX + 0.1, 4.8], 300), ("forge", _forge, "brick", [3.4, 4.5, 3.8], 400),
        ("oars_rack", _oars_rack, "timber", [1.4, 2.6, 4.2], 600)):
    _shapes, _cols = _maker()
    _dressing(_name, _slot, _shapes, _cols, _size, budget=_budget)
    # (The yard's work stands under the naves' vaults.)
    k.PIECES[_name]["roofed"] = True
