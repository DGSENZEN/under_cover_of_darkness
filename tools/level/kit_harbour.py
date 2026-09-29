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


# ---------------------------------------------------------------------------
# Quays: granite, the sea's marks on the face under 1.2 m (the waterline
# photo is anchored to the sea's height), a coping standing proud, rings.
# ---------------------------------------------------------------------------

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


# ---------------------------------------------------------------------------
# The mole: its top a quay on the harbour side (-z), a parapet to the sea
# (+z), battered and its foot heaped with boulders; its round head.
# ---------------------------------------------------------------------------

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
_shapes, _cols = _mole_head()
_piece("mole_head", "quay", "granite_rough", _shapes, _cols, [30.0, PARAPET_TOP - BED, 30.0], budget=1200)

# The slip: a ramp from the nave's floor (2.5) down into the water (-2).
_ramp = math.degrees(math.atan2(QUAY_TOP + 2.0, 8.0))
_piece("slipway_8", "quay", "granite",
       [ks.slab([[-NAVE / 2.0, QUAY_TOP, -4.0], [NAVE / 2.0, QUAY_TOP, -4.0], [NAVE / 2.0, -2.0, 4.0], [-NAVE / 2.0, -2.0, 4.0]], 0.4, "granite",
                tile=2.0)],
       [col(0.0, (QUAY_TOP - 2.0) / 2.0 - 0.2, 0.0, NAVE, 0.4, math.hypot(8.0, QUAY_TOP + 2.0), 0.0, _ramp)], [NAVE, QUAY_TOP + 2.4, 8.0])


# ---------------------------------------------------------------------------
# The royal shipyard's naves, built of one bay: a pier, an arch (along x or
# z), a groin vault under the terrace; a nave's end wall with a high window.
# Floors are the level's own (its pivot on the nave's floor).
# ---------------------------------------------------------------------------

def _pier():
    shapes = [ks.box(0.0, SPRING / 2.0, 0.0, PIER, SPRING, PIER, "brick"), ks.box(0.0, 0.2, 0.0, PIER + 0.3, 0.4, PIER + 0.3, "ashlar_gold"),
              ks.box(0.0, SPRING - 0.15, 0.0, PIER + 0.4, 0.3, PIER + 0.4, "ashlar_gold")]
    return shapes, [col(0.0, SPRING / 2.0, 0.0, PIER, SPRING, PIER)]


def _arch(yaw):
    opening = NAVE - PIER
    shapes = ks.arched_wall(NAVE, TERRACE, BAND, opening, SPRING, APEX - SPRING, 0.0, "brick", pointed=True, piers=False, yaw=yaw, jambs=False)
    return shapes, [col(0.0, (APEX + TERRACE) / 2.0, 0.0, NAVE if yaw == 0.0 else BAND, TERRACE - APEX, BAND if yaw == 0.0 else NAVE)]


def _vault():
    """Four webs meeting at the groins (the diagonals) and the crown, each
    springing from an arch's inner face; the terrace over them."""
    inner = NAVE / 2.0 - BAND / 2.0
    edge = (NAVE - PIER) / 2.0
    crown = APEX + 0.4
    shapes = []

    for yaw in (0.0, 90.0, 180.0, 270.0):
        a, b = [-edge, SPRING, inner], [-edge / 2.0, APEX - 0.6, inner]
        m, b2, a2 = [0.0, APEX, inner], [edge / 2.0, APEX - 0.6, inner], [edge, SPRING, inner]
        g1, g2, c = [-inner / 2.0, APEX - 0.9, inner / 2.0], [inner / 2.0, APEX - 0.9, inner / 2.0], [0.0, crown, 0.0]
        web = [_down(t, "brick") for t in ([a, b, g1], [b, m, c], [b, c, g1], [m, b2, c], [b2, g2, c], [b2, a2, g2])]
        shapes += ks.moved(web, yaw)

    shapes.append(ks.box(0.0, TERRACE - 0.15, 0.0, NAVE, 0.3, NAVE, "granite"))
    return shapes, [col(0.0, (APEX + TERRACE) / 2.0, 0.0, NAVE, TERRACE - APEX, NAVE)]


def _end_wall():
    shapes = ks.arched_wall(NAVE, TERRACE, BAND, 1.2, 10.4, 0.6, 9.0, "brick")
    cols = [col(-(NAVE / 2.0 + 0.6) / 2.0, TERRACE / 2.0, 0.0, NAVE / 2.0 - 0.6, TERRACE, BAND),
            col((NAVE / 2.0 + 0.6) / 2.0, TERRACE / 2.0, 0.0, NAVE / 2.0 - 0.6, TERRACE, BAND),
            col(0.0, 4.5, 0.0, 1.2, 9.0, BAND), col(0.0, (11.0 + TERRACE) / 2.0, 0.0, 1.2, TERRACE - 11.0, BAND)]
    return shapes, cols


_shapes, _cols = _pier()
_piece("nave_pier", "harbour", "brick", _shapes, _cols, [PIER + 0.4, SPRING, PIER + 0.4])
_shapes, _cols = _arch(0.0)
_piece("nave_arch_x", "harbour", "brick", _shapes, _cols, [NAVE, TERRACE, BAND])
_shapes, _cols = _arch(90.0)
_piece("nave_arch_z", "harbour", "brick", _shapes, _cols, [BAND, TERRACE, NAVE])
_shapes, _cols = _vault()
_piece("nave_vault", "harbour", "brick", _shapes, _cols, [NAVE, TERRACE - SPRING, NAVE])
_shapes, _cols = _end_wall()
_piece("nave_end_wall", "harbour", "brick", _shapes, _cols, [NAVE, TERRACE, BAND])


# ---------------------------------------------------------------------------
# A galley half-built on the stocks: its keel on blocks, its frames up (the
# middle planked below), stem and stern posts, a scaffold both sides with
# planks at 2.2 and 4.4 (a mantle each), two ladders.
# ---------------------------------------------------------------------------

GALLEY = (40.0, 5.5)


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
        z = side * (beam / 2.0 + 1.1)

        for x in range(-16, 17, 4):
            shapes.append(ks.prism(float(x), 2.6, z + side * 0.35, 0.09, 5.2, 4, "timber", caps=False))

        for y in PLANKS:
            shapes.append(ks.box(0.0, y - 0.05, z, length - 4.0, 0.1, 0.7, "boards"))
            cols.append(col(0.0, y - 0.05, z, length - 4.0, 0.1, 0.7, surface="wood"))

    # Two ladders up the +z scaffold, from the floor to the upper planks.
    climbs = []
    z = beam / 2.0 + 1.1 + 0.55

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


# ---------------------------------------------------------------------------
# A timber jib crane with its treadwheel.
# ---------------------------------------------------------------------------

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


# ---------------------------------------------------------------------------
# The quays' dressing.
# ---------------------------------------------------------------------------

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
