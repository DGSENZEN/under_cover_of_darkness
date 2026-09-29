"""The city's fortifications (kit v1): its walls and their stairs, drum and
square towers, the golden tower on the mole's head (after Seville's Torre
del Oro), the fort on its bastion at the harbour's mouth (after the Torre de
Belem), the Sea Gate, machicolations, the Nasrid water gate into the
shipyard, the harbour chain and its windlass. Pure data, as kit_recipes
(which imports this at its end).

Battlements are the castles' (the city spec, section 13): bays of 3.0 m, a
merlon 2.1 m wide and a crenel 0.9 m, over a breastwork 0.9 m high on the
wall's outer (+z) side; half a crenel at each end of a run, so runs join.
Walls are 2.4 m thick, battered at the foot. Everything in a piece's own
frame (x along it, y up, z through it, +z out), its pivot on the ground in
its middle. Colliders are boxes (round towers: strips across their flats,
which together are exactly their polygon).
"""

import math

import kit_recipes as k
import kit_shapes as ks

DEPTH = 2.4
BAY = 3.0
MERLON = 2.1
BREAST = 0.9
MERLON_UP = 0.9
PARAPET = 0.6
# The batter at a wall's foot: how high it rises, how far out it stands.
BATTER = (4.0, 0.6)
# The golden tower's three stages: across their flats (m) and how tall.
GOLD = [(15.0, 18.0), (9.0, 9.0), (4.5, 5.5)]
# The Nasrid water gate's arch: across, its circle's middle, its horseshoe.
NASRID = (7.0, 6.5, 0.33)


def col(cx, cy, cz, sx, sy, sz, yaw=0.0, pitch=0.0, roll=0.0):
    return [cx, cy, cz, sx, sy, sz, "stone", yaw, pitch, roll]


def _fort(name, slot, shapes, cols, size, budget=None):
    k.piece(name, "fort", slot, "stone", [], cols=cols, size=size)
    k.model(name, shapes)

    if budget:
        k.PIECES[name]["budget"] = budget


def _yaw_out(angle):
    """The yaw that turns a shape's +z to look out at `angle` (degrees, from
    +x toward +z) round an upright axis (its x then runs along the face)."""
    return 90.0 - angle


def _polygon_cols(sides, apothem, y0, height):
    """A regular polygon (flats at 0, 360/sides ... degrees) as boxes: a
    strip across each pair of opposite flats, as wide as a flat."""
    flat = 2.0 * apothem * math.tan(math.pi / sides)
    out = []

    for i in range(sides // 2):
        angle = i * 360.0 / sides
        out.append(col(0.0, y0 + height / 2.0, 0.0, 2.0 * apothem, height, flat, -angle))

    return out


def _polygon_prism(apothem, y0, height, sides, slot, top=None):
    """An upright polygon prism, its flats at 0, 360/sides ... degrees."""
    corner = apothem / math.cos(math.pi / sides)
    top_corner = None if top is None else top / math.cos(math.pi / sides)
    return ks.prism(0.0, y0 + height / 2.0, 0.0, corner, height, sides, slot, yaw=180.0 / sides, top=top_corner)


def _battlements(length, top, z, slot="granite", merlons=True):
    """A breastwork along x at z over a walk at `top`, a merlon in every bay,
    each with its coping and an arrow slit; shapes and colliders."""
    shapes = [ks.box(0.0, top + BREAST / 2.0, z, length, BREAST, PARAPET, slot)]
    cols = [col(0.0, top + BREAST / 2.0, z, length, BREAST, PARAPET)]
    bays = max(1, int(round(length / BAY)))

    for i in range(bays if merlons else 0):
        x = -length / 2.0 + (i + 0.5) * length / bays
        width = min(MERLON, length / bays - 0.3)
        y = top + BREAST + MERLON_UP / 2.0
        shapes.append(ks.box(x, y, z, width, MERLON_UP, PARAPET, slot))
        shapes.append(ks.box(x, top + BREAST + MERLON_UP + 0.05, z, width + 0.1, 0.1, PARAPET + 0.1, "ashlar_gold"))
        shapes.append(ks.box(x, y, z + PARAPET / 2.0 + 0.01, 0.12, 0.6, 0.02, "pitch"))
        cols.append(col(x, y, z, width, MERLON_UP, PARAPET))

    return shapes, cols


def _ring_battlements(apothem, top, sides, merlons, slot, pyramids=False):
    """A breastwork round a polygon's rim at `top` and merlons on it
    (Moorish pyramids, or square), and their colliders."""
    corner = apothem / math.cos(math.pi / sides)
    inner = corner - PARAPET
    shapes = [ks.lathe(0.0, top, 0.0, [[inner, 0.0], [corner, 0.0], [corner, BREAST], [inner, BREAST]], sides, slot, yaw=180.0 / sides,
                       closed=True)]
    flat = 2.0 * apothem * math.tan(math.pi / sides)
    cols = []

    for i in range(sides):
        angle = i * 360.0 / sides
        a = math.radians(angle)
        r = apothem - PARAPET / 2.0
        cols.append(col(r * math.cos(a), top + BREAST / 2.0, r * math.sin(a), flat, BREAST, PARAPET, _yaw_out(angle)))

    for i in range(merlons):
        angle = (i + 0.5) * 360.0 / merlons
        a = math.radians(angle)
        r = apothem - PARAPET / 2.0
        x, z = r * math.cos(a), r * math.sin(a)
        wide = min(1.2, 2.0 * math.pi * r / merlons * 0.55)
        yaw = _yaw_out(angle)

        if pyramids:
            # (Almohad merlons: a block under a stepped pyramid, big enough
            # to read against the sky from the quays.)
            wide = min(1.8, 2.0 * math.pi * r / merlons * 0.62)
            shapes.append(ks.box(x, top + BREAST + 0.45, z, wide, 0.9, PARAPET + 0.1, slot, yaw))
            shapes.append(ks.prism(x, top + BREAST + 0.9 + 0.45, z, wide * 0.72, 0.9, 4, slot, yaw=yaw + 45.0, top=0.0))
        else:
            shapes.append(ks.box(x, top + BREAST + MERLON_UP / 2.0, z, wide, MERLON_UP, PARAPET, slot, yaw))

        cols.append(col(x, top + BREAST + 0.45, z, wide, 0.9, PARAPET, yaw))

    return shapes, cols


# ---------------------------------------------------------------------------
# The city's walls: 12 m (the sea wall, the wall behind the Terreiro) and
# 10 m (the older wall behind the Ribeira), 6 and 3 m runs and a corner.
# ---------------------------------------------------------------------------

def _city_wall(height, length):
    d = DEPTH
    shapes = [ks.box(0.0, height / 2.0, 0.0, length, height, d, "granite"),
              ks.slab([[-length / 2.0, BATTER[0], d / 2.0], [length / 2.0, BATTER[0], d / 2.0], [length / 2.0, 0.0, d / 2.0 + BATTER[1]],
                       [-length / 2.0, 0.0, d / 2.0 + BATTER[1]]], 0.3, "granite_rough", up=(0.0, 0.15, 1.0), tile=2.5),
              ks.box(0.0, BATTER[0] + 0.1, d / 2.0 + 0.06, length, 0.2, 0.12, "ashlar_gold")]
    lean = math.degrees(math.atan2(BATTER[1], BATTER[0]))
    cols = [col(0.0, height / 2.0, 0.0, length, height, d),
            col(0.0, BATTER[0] / 2.0, d / 2.0 + BATTER[1] / 2.0 - 0.1, length, BATTER[0] + 0.05, 0.3, 0.0, -lean)]
    more, more_cols = _battlements(length, height, d / 2.0 - PARAPET / 2.0)
    return shapes + more, cols + more_cols


def _city_corner(height):
    d = DEPTH
    shapes = [ks.box(0.0, height / 2.0, 0.0, d, height, d, "granite")]
    cols = [col(0.0, height / 2.0, 0.0, d, height, d)]

    # Batter and battlements on its two outer faces (+z, and +x: the same
    # turned a quarter; the two batters meet at the corner).
    for yaw in (0.0, 90.0):
        batter = [[-d / 2.0, BATTER[0], d / 2.0], [d / 2.0 + BATTER[1], BATTER[0], d / 2.0],
                  [d / 2.0 + BATTER[1], 0.0, d / 2.0 + BATTER[1]], [-d / 2.0, 0.0, d / 2.0 + BATTER[1]]]
        shapes += ks.moved([ks.slab(batter, 0.3, "granite_rough", up=(0.0, 0.15, 1.0), tile=2.5)], yaw)
        top, top_cols = _battlements(d, height, d / 2.0 - PARAPET / 2.0)
        shapes += ks.moved(top, yaw)

        for c in top_cols:
            turned = ks.moved([ks.box(c[0], c[1], c[2], 1.0, 1.0, 1.0, "stone")], yaw)[0]["centre"]
            cols.append(col(turned[0], turned[1], turned[2], c[3], c[4], c[5], yaw))

    return shapes, cols


for _height in (12, 10):
    for _length in (6, 3):
        _shapes, _cols = _city_wall(float(_height), float(_length))
        _fort("city_wall_%d_%d" % (_height, _length), "granite", _shapes, _cols,
              [float(_length), _height + BREAST + MERLON_UP + 0.1, DEPTH + 2.0 * BATTER[1]])

    _shapes, _cols = _city_corner(float(_height))
    _fort("city_wall_%d_corner" % _height, "granite", _shapes, _cols,
          [DEPTH + 2.0 * BATTER[1], _height + BREAST + MERLON_UP + 0.1, DEPTH + 2.0 * BATTER[1]])


# ---------------------------------------------------------------------------
# A stair up a wall's inner face to its walk: along x, rising to +x, 1.5 m
# wide; risers 0.2, treads 0.3, a landing (1.2 m) every ten risers.
# ---------------------------------------------------------------------------

LANDING = 1.2
STAIR_WIDTH = 1.5


def _wall_stair(height):
    steps = int(round(height / k.RISER))
    runs = [LANDING if (i + 1) % 10 == 0 and i + 1 < steps else k.TREAD for i in range(steps)]
    total = sum(runs)
    boxes, x = [], -total / 2.0

    for i, run in enumerate(runs):
        top = (i + 1) * k.RISER
        boxes.append(k.box(x + run / 2.0, top / 2.0, 0.0, run, top, STAIR_WIDTH, "granite"))
        x += run

    return boxes, total


for _height in (12, 10):
    _boxes, _run = _wall_stair(float(_height))
    k.piece("wall_stair_%d" % _height, "fort", "granite", "stone", _boxes, size=[_run, float(_height), STAIR_WIDTH])


# ---------------------------------------------------------------------------
# Towers: a drum 8 m across and a square one 8 m, both 20 m, battered.
# ---------------------------------------------------------------------------

def _drum():
    r = 4.0
    shapes = [_polygon_prism(r + 0.5, 0.0, BATTER[0], 16, "granite_rough", top=r), _polygon_prism(r, BATTER[0], 20.0 - BATTER[0], 16, "granite"),
              ks.lathe(0.0, BATTER[0], 0.0, [[r / math.cos(math.pi / 16) - 0.01, 0.0], [r / math.cos(math.pi / 16) + 0.1, 0.0],
                                              [r / math.cos(math.pi / 16) + 0.1, 0.2], [r / math.cos(math.pi / 16) - 0.01, 0.2]], 16, "ashlar_gold",
                       yaw=180.0 / 16, closed=True)]
    cols = _polygon_cols(16, r, 0.0, 20.0)
    top, top_cols = _ring_battlements(r, 20.0, 16, 8, "granite")

    for i, y in enumerate((8.0, 15.0)):
        for j in range(4):
            angle = j * 90.0 + i * 45.0 + 22.5
            a = math.radians(angle)
            shapes.append(ks.box(math.cos(a) * (r + 0.01), y, math.sin(a) * (r + 0.01), 0.14, 1.0, 0.03, "pitch", _yaw_out(angle)))

    return shapes + top, cols + top_cols


def _square_tower():
    half = 4.0
    corner = half * math.sqrt(2.0)
    shapes = [ks.prism(0.0, BATTER[0] / 2.0, 0.0, corner + 0.6, BATTER[0], 4, "granite_rough", yaw=45.0, top=corner),
              ks.prism(0.0, BATTER[0] + (20.0 - BATTER[0]) / 2.0, 0.0, corner, 20.0 - BATTER[0], 4, "granite", yaw=45.0)]
    cols = [col(0.0, 10.0, 0.0, 8.0, 20.0, 8.0)]

    for sx, sz in ((1, 1), (1, -1), (-1, 1), (-1, -1)):
        shapes.append(ks.box(sx * (half - 0.15), 12.0, sz * (half - 0.15), 0.4, 16.0, 0.4, "ashlar_gold"))

    for yaw in (0.0, 90.0, 180.0, 270.0):
        top, top_cols = _battlements(8.0, 20.0, half - PARAPET / 2.0)
        shapes += ks.moved(top, yaw)

        for c in top_cols:
            turned = ks.moved([ks.box(c[0], c[1], c[2], 1.0, 1.0, 1.0, "stone")], yaw)[0]["centre"]
            cols.append(col(turned[0], turned[1], turned[2], c[3], c[4], c[5], yaw))

    return shapes, cols


_shapes, _cols = _drum()
_fort("tower_drum_8", "granite", _shapes, _cols, [9.0, 21.9, 9.0])
_shapes, _cols = _square_tower()
_fort("tower_square_8", "granite", _shapes, _cols, [9.2, 21.9, 9.2])


# ---------------------------------------------------------------------------
# The golden tower: three twelve-sided stages in straw-coloured lime, their
# corners dressed in golden stone, blind horseshoe arches on the first
# two, Moorish pyramid merlons round their terraces, a domed lantern on the
# third. The first stage is hollow at the ground (the windlass's room, its
# door looking -z), an iron ladder up its -z face to its terrace.
# ---------------------------------------------------------------------------

ROOM = 5.0
WALL = 1.5


def _corners(apothem, y0, height, sides=12):
    corner = apothem / math.cos(math.pi / sides)
    out = []

    for i in range(sides):
        angle = (i + 0.5) * 360.0 / sides
        a = math.radians(angle)
        out.append(ks.prism(math.cos(a) * (corner - 0.1), y0 + height / 2.0, math.sin(a) * (corner - 0.1), 0.3, height, 4, "ashlar_gold",
                            yaw=_yaw_out(angle) + 45.0, caps=False))

    return out


def _blind_arches(apothem, y, radius, sides=12, skip=()):
    out = []

    for i in range(sides):
        if i in skip:
            continue

        angle = i * 360.0 / sides
        a = math.radians(angle)
        at = apothem + 0.05
        out.append(ks.ring(math.cos(a) * at, y, math.sin(a) * at, radius, radius + 0.3, 0.1, -20.0, 200.0, 3, "ashlar_gold", _yaw_out(angle)))

    return out


def _gold_stage_1():
    apothem, height = GOLD[0][0] / 2.0, GOLD[0][1]
    corner = apothem / math.cos(math.pi / 12)
    flat = 2.0 * apothem * math.tan(math.pi / 12)
    shapes = [_polygon_prism(apothem + 0.3, 0.0, 0.6, 12, "ashlar_gold"), _polygon_prism(apothem, ROOM, height - ROOM, 12, "render_straw")]
    cols = _polygon_cols(12, apothem, ROOM, height - ROOM)
    # The room's walls at the ground: a slab to each flat, the door's (at
    # 270 degrees, -z) in three about its opening.
    door = (1.6, 2.6)

    for i in range(12):
        angle = i * 360.0 / 12
        yaw = _yaw_out(angle)
        a = math.radians(angle)
        mid = apothem - WALL / 2.0
        cx, cz = math.cos(a) * mid, math.sin(a) * mid

        if i == 9:
            side = (flat - door[0]) / 2.0

            for s in (-1.0, 1.0):
                offset = s * (door[0] + side) / 2.0
                x, z = cx + math.cos(a + math.pi / 2.0) * offset, cz + math.sin(a + math.pi / 2.0) * offset
                shapes.append(ks.box(x, ROOM / 2.0, z, side + 0.35, ROOM, WALL, "render_straw", yaw))
                cols.append(col(x, ROOM / 2.0, z, side + 0.35, ROOM, WALL, yaw))

            shapes.append(ks.box(cx, (ROOM + door[1]) / 2.0, cz, door[0] + 0.1, ROOM - door[1], WALL, "render_straw", yaw))
            cols.append(col(cx, (ROOM + door[1]) / 2.0, cz, door[0], ROOM - door[1], WALL, yaw))
            # Its frame in golden stone, a horseshoe arch over it.
            out = apothem + 0.06
            fx, fz = math.cos(a) * out, math.sin(a) * out
            shapes.append(ks.ring(fx, door[1] - 0.2, fz, door[0] / 2.0, door[0] / 2.0 + 0.3, 0.12, -20.0, 200.0, 4, "ashlar_gold", yaw))
        else:
            shapes.append(ks.box(cx, ROOM / 2.0, cz, flat + 0.35, ROOM, WALL, "render_straw", yaw))
            cols.append(col(cx, ROOM / 2.0, cz, flat, ROOM, WALL, yaw))

    shapes += _corners(apothem, 0.6, height - 0.6)
    shapes += _blind_arches(apothem, 10.5, 1.2, skip=(9,))
    # Slit windows high up, the ladder's rungs up the -z flat to the terrace.
    for angle in (0.0, 90.0, 180.0):
        a = math.radians(angle)
        shapes.append(ks.box(math.cos(a) * (apothem + 0.01), 14.5, math.sin(a) * (apothem + 0.01), 0.16, 1.4, 0.03, "pitch", _yaw_out(angle)))

    for x in (-0.35, 0.35):
        shapes.append(ks.box(x - 1.5, (ROOM + 0.5 + height + 1.0) / 2.0, -apothem - 0.1, 0.06, height + 0.5 - ROOM, 0.06, "iron"))

    # (Rungs as three-sided rods, open at their ends: 6 triangles each.)
    for rung in range(int((height - ROOM - 0.3) / 0.3)):
        shapes.append(ks.prism(-1.5, ROOM + 0.3 + rung * 0.3, -apothem - 0.1, 0.025, 0.7, 3, "iron", roll=90.0, caps=False))

    top, top_cols = _ring_battlements(apothem, height, 12, 12, "render_straw", pyramids=True)
    return shapes + top, cols + top_cols


def _gold_stage(index):
    apothem, height = GOLD[index][0] / 2.0, GOLD[index][1]
    shapes = [_polygon_prism(apothem, 0.0, height, 12, "render_straw")]
    cols = _polygon_cols(12, apothem, 0.0, height)
    shapes += _corners(apothem, 0.0, height)

    if index == 1:
        shapes += _blind_arches(apothem, height * 0.55, 0.8)
        top, top_cols = _ring_battlements(apothem, height, 12, 12, "render_straw", pyramids=True)
        return shapes + top, cols + top_cols

    # The lantern: a window in every other flat (lit from within at night),
    # the golden dome over a cornice, a finial.
    for i in range(0, 12, 3):
        angle = i * 30.0
        a = math.radians(angle)
        shapes.append(ks.box(math.cos(a) * (apothem + 0.01), height * 0.5, math.sin(a) * (apothem + 0.01), 0.7, 1.6, 0.03, "glass_lit",
                             _yaw_out(angle)))

    corner = apothem / math.cos(math.pi / 12)
    shapes.append(ks.lathe(0.0, height, 0.0, [[corner + 0.25, 0.0], [corner + 0.25, 0.3], [corner, 0.3]], 12, "ashlar_gold", yaw=15.0))
    shapes.append(ks.lathe(0.0, height + 0.3, 0.0, [[corner, 0.0], [corner * 0.93, corner * 0.4], [corner * 0.72, corner * 0.72],
                                                     [corner * 0.4, corner * 0.93], [0.0, corner]], 12, "ashlar_gold", yaw=15.0))
    shapes.append(ks.lathe(0.0, height + 0.3 + corner, 0.0, [[0.12, 0.0], [0.2, 0.3], [0.05, 0.9]], 6, "brass"))
    return shapes, cols


_shapes, _cols = _gold_stage_1()
_fort("gold_stage_1", "render_straw", _shapes, _cols, [GOLD[0][0] + 1.2, GOLD[0][1] + 2.1, GOLD[0][0] + 1.2], budget=1400)

for _index in (1, 2):
    _shapes, _cols = _gold_stage(_index)
    _fort("gold_stage_%d" % (_index + 1), "render_straw", _shapes, _cols,
          [GOLD[_index][0] + 0.8, GOLD[_index][1] + (2.1 if _index == 1 else GOLD[_index][0] / 2.0 + 1.3), GOLD[_index][0] + 0.8],
          budget=1200)


# ---------------------------------------------------------------------------
# The fort at the harbour's mouth: a bastion in the water (a prow to +z),
# embrasures at the waterline, a parapet of merlons with shields; its tower,
# pale limestone, a loggia to the sea, a rope band round it; domed garitas
# for the bastion's corners.
# ---------------------------------------------------------------------------

BASTION = [(-15.0, -12.0), (15.0, -12.0), (15.0, 4.0), (6.0, 12.0), (-6.0, 12.0), (-15.0, 4.0)]
BASTION_TOP = 4.0


def _bastion():
    shapes, cols = [], []
    ring = BASTION

    for (x0, z0), (x1, z1) in zip(ring, ring[1:] + ring[:1]):
        # Each face battered a little, looking out.
        dx, dz = x1 - x0, z1 - z0
        length = math.hypot(dx, dz)
        nx, nz = dz / length, -dx / length
        shapes.append(ks.slab([[x0, BASTION_TOP, z0], [x1, BASTION_TOP, z1], [x1 + nx * 0.5, -1.0, z1 + nz * 0.5], [x0 + nx * 0.5, -1.0, z0 + nz * 0.5]],
                              0.4, "granite_rough", up=(nx, 0.1, nz), tile=2.5))
        # Embrasures at the waterline, the parapet over the face, merlons
        # with a shield on each.
        for f in (0.33, 0.66):
            x, z = x0 + dx * f, z0 + dz * f
            angle = math.degrees(math.atan2(nz, nx))
            shapes.append(ks.box(x + nx * 0.12, 1.5, z + nz * 0.12, 1.0, 0.7, 0.05, "pitch", _yaw_out(angle)))

        angle = math.degrees(math.atan2(nz, nx))
        yaw = _yaw_out(angle)
        px, pz = (x0 + x1) / 2.0 - nx * PARAPET / 2.0, (z0 + z1) / 2.0 - nz * PARAPET / 2.0
        shapes.append(ks.box(px, BASTION_TOP + BREAST / 2.0, pz, length, BREAST, PARAPET, "ashlar_gold", yaw))
        cols.append(col(px, BASTION_TOP + BREAST / 2.0, pz, length, BREAST, PARAPET, yaw))
        bays = max(1, int(round(length / BAY)))

        for i in range(bays):
            f = (i + 0.5) / bays
            mx, mz = x0 + dx * f - nx * PARAPET / 2.0, z0 + dz * f - nz * PARAPET / 2.0
            shapes.append(ks.box(mx, BASTION_TOP + BREAST + 0.4, mz, 1.3, 0.8, PARAPET, "ashlar_gold", yaw))
            shapes.append(ks.box(mx + nx * (PARAPET / 2.0 + 0.03), BASTION_TOP + BREAST + 0.4, mz + nz * (PARAPET / 2.0 + 0.03), 0.6, 0.6, 0.06,
                                 "manueline", yaw))
            cols.append(col(mx, BASTION_TOP + BREAST + 0.4, mz, 1.3, 0.8, PARAPET, yaw))

    # Its top: the platform (two slabs: behind the prow and the prow).
    shapes.append(ks.slab([[-15.0, BASTION_TOP, -12.0], [15.0, BASTION_TOP, -12.0], [15.0, BASTION_TOP, 4.0], [-15.0, BASTION_TOP, 4.0]], 0.3,
                          "granite", tile=2.0))
    shapes.append(ks.slab([[-15.0, BASTION_TOP, 4.0], [15.0, BASTION_TOP, 4.0], [6.0, BASTION_TOP, 12.0], [-6.0, BASTION_TOP, 12.0]], 0.3,
                          "granite", tile=2.0))
    # Its colliders: the body behind the prow, the prow's middle, its two
    # chamfers (a box laid along each, inward).
    cols.append(col(0.0, (BASTION_TOP - 1.0) / 2.0, -4.0, 30.0, BASTION_TOP + 1.0, 16.0))
    cols.append(col(0.0, (BASTION_TOP - 1.0) / 2.0, 8.0, 12.0, BASTION_TOP + 1.0, 8.0))

    for sx in (-1.0, 1.0):
        (x0, z0), (x1, z1) = (sx * 15.0, 4.0), (sx * 6.0, 12.0)
        length = math.hypot(x1 - x0, z1 - z0)
        inward = (-(z1 - z0) / length * sx, (x1 - x0) / length * sx)
        angle = math.degrees(math.atan2(z1 - z0, x1 - x0))
        cx, cz = (x0 + x1) / 2.0 + inward[0] * 1.5, (z0 + z1) / 2.0 + inward[1] * 1.5
        cols.append(col(cx, (BASTION_TOP - 1.0) / 2.0, cz, length, BASTION_TOP + 1.0, 3.0, -angle))

    return shapes, cols


def _fort_tower():
    side, height = 12.0, 30.0
    shapes = [ks.box(0.0, height / 2.0, 0.0, side, height, side, "ashlar_gold")]
    cols = [col(0.0, height / 2.0, 0.0, side, height, side)]

    for y in (10.0, 20.0):
        shapes.append(ks.box(0.0, y, 0.0, side + 0.3, 0.3, side + 0.3, "ashlar_gold"))

    # The rope band, twisted stone (its photo is a rope's lay).
    shapes.append(ks.box(0.0, 24.0, 0.0, side + 0.4, 0.35, side + 0.4, "rope_lay"))

    # The loggia to the sea (+z): a balcony on five columns, its roof.
    front = side / 2.0
    shapes.append(ks.box(0.0, 12.0, front + 1.0, 9.0, 0.3, 2.0, "ashlar_gold"))
    shapes.append(ks.box(0.0, 15.6, front + 1.0, 9.0, 0.4, 2.0, "ashlar_gold"))
    shapes.append(ks.box(0.0, 13.9, front + 0.01, 8.6, 3.2, 0.03, "pitch"))
    cols.append(col(0.0, 12.0, front + 1.0, 9.0, 0.3, 2.0))

    for i in range(5):
        shapes.append(ks.prism(-4.0 + i * 2.0, 13.8, front + 1.8, 0.14, 3.3, 6, "ashlar_gold"))

    # Arched windows, a medallion of the rope carving on each face.
    for yaw in (0.0, 90.0, 180.0, 270.0):
        window = [ks.box(0.0, 20.0 + 1.9, front + 0.01, 1.0, 1.8, 0.03, "pitch"),
                  ks.ring(0.0, 21.8, front + 0.05, 0.5, 0.7, 0.1, 0.0, 180.0, 3, "ashlar_gold"),
                  ks.card(0.0, 26.5, front + 0.03, 2.0, 2.0, "manueline")]
        shapes += ks.moved(window, yaw)

        if yaw in (90.0, 270.0):
            shapes += ks.moved([ks.box(0.0, 6.5, front + 0.01, 0.7, 1.4, 0.03, "pitch")], yaw)

        top, top_cols = _battlements(side, height, front - PARAPET / 2.0, "ashlar_gold")
        shapes += ks.moved(top, yaw)

        for c in top_cols:
            turned = ks.moved([ks.box(c[0], c[1], c[2], 1.0, 1.0, 1.0, "stone")], yaw)[0]["centre"]
            cols.append(col(turned[0], turned[1], turned[2], c[3], c[4], c[5], yaw))

    return shapes, cols


def _garita():
    profile = [[0.25, 0.0], [1.2, 1.0], [1.2, 3.2], [1.32, 3.3], [1.32, 3.5], [1.15, 3.5]]
    dome = [[1.15, 0.0], [1.06, 0.45], [0.82, 0.85], [0.45, 1.12], [0.0, 1.22]]
    shapes = [ks.lathe(0.0, 0.0, 0.0, profile, 10, "ashlar_gold"), ks.lathe(0.0, 3.5, 0.0, dome, 10, "ashlar_gold"),
              ks.lathe(0.0, 4.72, 0.0, [[0.1, 0.0], [0.16, 0.18], [0.03, 0.55]], 6, "ashlar_gold")]

    for angle in (0.0, 120.0, 240.0):
        a = math.radians(angle)
        shapes.append(ks.box(math.cos(a) * 1.21, 2.2, math.sin(a) * 1.21, 0.12, 0.8, 0.03, "pitch", _yaw_out(angle)))

    return shapes, [col(0.0, 2.25, 0.0, 2.0, 2.5, 2.0)]


_shapes, _cols = _bastion()
_fort("fort_bastion", "granite_rough", _shapes, _cols, [31.2, BASTION_TOP + 2.8, 25.2], budget=1200)
_shapes, _cols = _fort_tower()
_fort("fort_tower", "ashlar_gold", _shapes, _cols, [12.6, 31.9, 16.4], budget=1600)
_shapes, _cols = _garita()
_fort("turret_domed", "ashlar_gold", _shapes, _cols, [2.7, 5.3, 2.7])


# ---------------------------------------------------------------------------
# The Sea Gate: its arched front between its drum towers (a passage 4 m wide
# and 5 m high, the portcullis's groove in its reveals, a machicolation
# gallery over it, the arms of the city), and the vaulted passage through
# the wall (16 m, three murder holes in the vault).
# ---------------------------------------------------------------------------

GATE = {"width": 12.0, "height": 14.0, "depth": 3.0, "opening": 4.0, "spring": 3.0}


def _machicolation(length, z, top, slot="granite"):
    """Corbels out from a face at z under a parapet set out on them, merlons
    over it (the murder holes between the corbels)."""
    shapes, cols = [], []
    corbels = int(round(length))

    for i in range(corbels + 1):
        x = -length / 2.0 + i * length / corbels
        shapes.append(ks.box(x, top - 1.2, z + 0.25, 0.4, 0.4, 0.5, slot))
        shapes.append(ks.box(x, top - 0.8, z + 0.5, 0.4, 0.4, 1.0, slot))

    shapes.append(ks.box(0.0, top - 0.3, z + 0.85, length, 0.6, 0.3, slot))
    wall, wall_cols = _battlements(length, top, z + 0.85, slot)
    shapes += wall
    cols += wall_cols
    cols.append(col(0.0, top - 0.3, z + 0.85, length, 0.6, 0.3))
    return shapes, cols


def _gate_front():
    g = GATE
    half = g["opening"] / 2.0
    d = g["depth"] / 2.0
    shapes = ks.arched_wall(g["width"], g["height"], g["depth"], g["opening"], g["spring"], half, 0.0, "granite")
    cols = [col(-(g["width"] / 2.0 + half) / 2.0, g["height"] / 2.0, 0.0, g["width"] / 2.0 - half, g["height"], g["depth"]),
            col((g["width"] / 2.0 + half) / 2.0, g["height"] / 2.0, 0.0, g["width"] / 2.0 - half, g["height"], g["depth"]),
            col(0.0, (g["height"] + g["spring"] + half) / 2.0, 0.0, g["opening"], g["height"] - g["spring"] - half, g["depth"])]

    # The portcullis's grooves, the voussoirs round the arch, the arms.
    for side in (-1.0, 1.0):
        shapes.append(ks.box(side * (half + 0.06), (g["spring"] + half) / 2.0, d - 0.5, 0.12, g["spring"] + half, 0.2, "pitch"))

    shapes.append(ks.ring(0.0, g["spring"], d + 0.05, half, half + 0.6, 0.1, 0.0, 180.0, 6, "ashlar_gold"))
    shapes.append(ks.card(0.0, 7.6, d + 0.05, 1.6, 2.0, "shield_2"))
    shapes.append(ks.box(0.0, 6.35, d + 0.1, 2.2, 0.25, 0.2, "ashlar_gold"))
    gallery, gallery_cols = _machicolation(g["width"], d, g["height"])
    return shapes + gallery, cols + gallery_cols


def _gate_passage():
    g = GATE
    half = g["opening"] / 2.0
    length = 16.0
    side = (g["width"] / 2.0 - half)
    shapes = [ks.box(-(half + side / 2.0), g["height"] / 2.0, 0.0, side, g["height"], length, "granite"),
              ks.box(half + side / 2.0, g["height"] / 2.0, 0.0, side, g["height"], length, "granite"),
              ks.box(0.0, (g["height"] + g["spring"] + half + 0.3) / 2.0, 0.0, g["opening"], g["height"] - g["spring"] - half - 0.3, length, "granite"),
              ks.ring(0.0, g["spring"], 0.0, half, half + 0.3, length, 0.0, 180.0, 8, "granite")]

    for z in (-5.0, 0.0, 5.0):
        shapes.append(ks.disc(0.0, g["spring"] + half - 0.02, z, 0.35, 6, "pitch", pitch=90.0))

    cols = [col(-(half + side / 2.0), g["height"] / 2.0, 0.0, side, g["height"], length),
            col(half + side / 2.0, g["height"] / 2.0, 0.0, side, g["height"], length),
            col(0.0, (g["height"] + g["spring"] + half) / 2.0, 0.0, g["opening"], g["height"] - g["spring"] - half, length)]
    return shapes, cols


_shapes, _cols = _gate_front()
_fort("gate_front", "granite", _shapes, _cols, [GATE["width"], GATE["height"] + BREAST + MERLON_UP + 0.1, GATE["depth"] + 2.2])
_shapes, _cols = _gate_passage()
_fort("gate_passage_16", "granite", _shapes, _cols, [GATE["width"], GATE["height"], 16.0])
_shapes, _cols = _machicolation(6.0, 0.0, 0.0)
_fort("machicolation_6", "granite", _shapes, _cols, [6.0, 3.1, 2.4])


# ---------------------------------------------------------------------------
# The Nasrid water gate: a piece of the sea wall standing in the water (its
# foot at the sea, its walk at 14.5 like the wall's on the quay), a
# horseshoe arch through it under an alfiz, its voussoirs brick and stone
# in turn.
# ---------------------------------------------------------------------------

def _nasrid_gate():
    width, height = 12.0, 14.5
    across, spring, horseshoe = NASRID
    r = across / 2.0
    d = DEPTH / 2.0
    jamb = r * math.cos(math.asin(horseshoe))
    beyond = math.degrees(math.asin(horseshoe))
    shapes = ks.arched_wall(width, height, DEPTH, across, spring, r, 0.0, "granite", horseshoe=horseshoe)
    stones = 12

    for i in range(stones):
        start = -beyond + (180.0 + 2.0 * beyond) * i / stones
        end = -beyond + (180.0 + 2.0 * beyond) * (i + 1) / stones
        shapes.append(ks.ring(0.0, spring, d + 0.05, r, r + 0.8, 0.1, start, end, 1, "brick" if i % 2 == 0 else "ashlar_gold"))

    # The alfiz: a frame round the arch, up from its springing.
    frame = r + 1.1
    shapes.append(ks.box(0.0, spring + frame, d + 0.06, 2.0 * frame + 0.3, 0.3, 0.12, "ashlar_gold"))

    for side in (-1.0, 1.0):
        shapes.append(ks.box(side * frame, spring + frame / 2.0 - 0.3, d + 0.06, 0.3, frame + 0.6, 0.12, "ashlar_gold"))

    cols = [col(-(width / 2.0 + jamb) / 2.0, height / 2.0, 0.0, width / 2.0 - jamb, height, DEPTH),
            col((width / 2.0 + jamb) / 2.0, height / 2.0, 0.0, width / 2.0 - jamb, height, DEPTH),
            col(0.0, (height + spring + r) / 2.0, 0.0, 2.0 * jamb, height - spring - r, DEPTH)]
    top, top_cols = _battlements(width, height, d - PARAPET / 2.0)
    return shapes + top, cols + top_cols


_shapes, _cols = _nasrid_gate()
_fort("nasrid_gate", "granite", _shapes, _cols, [12.0, 14.5 + BREAST + MERLON_UP + 0.1, DEPTH + 0.4], budget=1000)


# ---------------------------------------------------------------------------
# The harbour chain: a span of great links on a float, sagging into the sea
# between floats (the next span's); and the windlass that hauls it.
# ---------------------------------------------------------------------------

def _chain_span():
    length = 12.0
    links = 24
    shapes = [ks.prism(0.0, 0.1, 0.0, 0.6, 1.6, 8, "hull_bare", pitch=90.0)]

    for i in range(links):
        x = -length / 2.0 + (i + 0.5) * length / links
        t = abs(x) / (length / 2.0)
        y = 0.45 - 0.75 * t * t
        slope = math.degrees(math.atan(-1.5 * t / (length / 2.0) * (1.0 if x > 0 else -1.0)))
        shapes.append(ks.box(x, y, 0.0, 0.55, 0.24 if i % 2 == 0 else 0.08, 0.08 if i % 2 == 0 else 0.24, "iron", 0.0, 0.0, slope))

    return shapes


def _windlass():
    shapes = []

    for x in (-1.6, 1.6):
        for z in (-0.9, 0.9):
            shapes.append(ks.box(x, 1.15, z * 0.55, 0.22, 2.4, 0.22, "beam", 0.0, z * 12.0, 0.0))

        shapes.append(ks.box(x, 0.1, 0.0, 0.3, 0.2, 2.6, "beam"))

    shapes.append(ks.prism(0.0, 1.6, 0.0, 0.42, 3.0, 8, "beam", roll=90.0))
    shapes.append(ks.prism(0.0, 1.6, 0.0, 0.5, 1.6, 8, "iron", roll=90.0))

    for angle in (0.0, 90.0):
        shapes.append(ks.box(1.75, 1.6, 0.0, 0.1, 2.4, 0.1, "beam", 0.0, angle, 0.0))

    return shapes, [col(0.0, 1.2, 0.0, 3.6, 2.4, 1.4)]


_fort("chain_span_12", "iron", _chain_span(), [], [12.0, 1.0, 1.6])
_shapes, _cols = _windlass()
_fort("windlass", "beam", _shapes, _cols, [4.0, 2.8, 3.0])
