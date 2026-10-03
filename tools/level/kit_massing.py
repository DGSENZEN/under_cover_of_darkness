"""The city behind the harbour as silhouettes (kit v1), until each district
is built: terraces of houses in whitewash under Spanish tiles, a retaining
wall, the cathedral and its bell tower, the palace of waters and its
mirador, a span of the aqueduct, the Great Bridge, the castle's curtain and
towers and its keep (the crown, 155 m over the sea on the summit). Few
triangles each, lit windows sparse and warm, drawn without shadows (the
export lists them: kit_recipes.shadowless); boxes to stop anything that
gets there. Pure data, as kit_recipes (which imports this at its end).
Pivots on the ground (the terrace, the gorge's floor, the summit) in their
middles.
"""

import math
import random

import kit_iberian
import kit_recipes as k
import kit_shapes as ks


def col(cx, cy, cz, sx, sy, sz, yaw=0.0):
    return [cx, cy, cz, sx, sy, sz, "stone", yaw, 0.0, 0.0]


def _mass(name, slot, shapes, cols, size, budget=600):
    k.piece(name, "massing", slot, "stone", [], cols=cols, size=size)
    k.model(name, shapes)
    k.PIECES[name]["budget"] = budget


def _lit(x, y, z, yaw=0.0, w=0.8, h=1.2):
    return ks.card(x, y, z, w, h, "glass_lit", yaw)


# A house: its walls down into the ground FOOT m (the rock undulates under
# a row); its roof's pitch, its eaves and verges standing out; a painted
# front (paint.py FACADE: windows every 3 m from 1.5 m along each wall, a
# storey every 3.5 m, its openings 0.9 to 2.5 m over a floor, 0.9 m wide),
# a few of its windows lit in their openings.
FOOT = -2.0
PITCH = 25.0
EAVES = 0.45
VERGE = 0.25
WINDOW_EVERY = 3.0
WINDOW_FIRST = 1.5
STOREY = 3.5
OPENING = (0.9, 2.5, 0.9)
FACADES = ("facade_white", "facade_ochre", "facade_salmon", "facade_blue")


def _wall(points, along, slot):
    """A wall's face through `points` (wound outward) in `slot`, laid in
    metres: along it from its left corner (seen from outside) and up."""
    return ks.polygon(points, slot, uvs=[[along(p), -p[1]] for p in points])


def _windows(length, height):
    """The window openings' middles on a wall `length` m along and
    `height` m up: [(along, up)]."""
    out = []
    floor = 0.0

    while floor + OPENING[1] < height - 0.3:
        u = WINDOW_FIRST

        while u + OPENING[2] / 2.0 < length - 0.4:
            out.append((u, floor + (OPENING[0] + OPENING[1]) / 2.0))
            u += WINDOW_EVERY

        floor += STOREY

    return out


def _house(x, width, height, depth, slot, lit, chimney=None, z=0.0, roofed=True):
    """A house `width` along x, `depth` deep (its front +z), its walls
    `height` to the eaves, closed gable ends under a roof of two slopes
    (its ridge along x); `lit` (a random.Random) lights about a quarter of
    its windows front and back; `chimney` (along x from its middle) a stack
    through its back slope; not `roofed`, its walls stop flat at `height`
    (for what stands on it). Returns shapes, colliders, chimney tops."""
    x0, x1 = x - width / 2.0, x + width / 2.0
    zf, zb = z + depth / 2.0, z - depth / 2.0
    rise = depth / 2.0 * math.tan(math.radians(PITCH)) if roofed else 0.0
    top = height + rise
    shapes = [_wall([[x0, FOOT, zf], [x1, FOOT, zf], [x1, height, zf], [x0, height, zf]], lambda p: p[0] - x0, slot),
              _wall([[x1, FOOT, zb], [x0, FOOT, zb], [x0, height, zb], [x1, height, zb]], lambda p: x1 - p[0], slot),
              _wall([[x1, FOOT, zf], [x1, FOOT, zb], [x1, height, zb]] + ([[x1, top, z]] if roofed else []) + [[x1, height, zf]],
                    lambda p: zf - p[2], slot),
              _wall([[x0, FOOT, zb], [x0, FOOT, zf], [x0, height, zf]] + ([[x0, top, z]] if roofed else []) + [[x0, height, zb]],
                    lambda p: p[2] - zb, slot)]
    # The slopes from the ridge out over the eaves, the verges past the
    # gables; their undersides (the eaves seen from the street) in timber.
    drop = EAVES * math.tan(math.radians(PITCH))

    for side in (1.0, -1.0) if roofed else ():
        eave = z + side * (depth / 2.0 + EAVES)
        corners = [[x0 - VERGE, top, z], [x1 + VERGE, top, z], [x1 + VERGE, height - drop, eave], [x0 - VERGE, height - drop, eave]]
        shapes.append(ks.slab(corners, 0.16, "roof_spanish", under="timber", edge="roof_spanish"))

    cols = [col(x, (height + FOOT) / 2.0, z, width, height - FOOT, depth)]

    if roofed:
        shapes.append(ks.box(x, top + 0.06, z, width + VERGE * 2.0, 0.16, 0.34, "roof_spanish"))
        cols += [[c[0] + x, c[1], c[2] + z] + c[3:] for c in kit_iberian.roof_cols(width, depth, rise, height)]
    chimneys = []

    if chimney is not None:
        cz = z - depth * 0.22
        base = height + rise * (1.0 - (depth * 0.22) / (depth / 2.0))
        shapes += [ks.box(x + chimney, base + 0.9, cz, 0.8, 2.6, 0.8, slot), ks.box(x + chimney, base + 2.25, cz, 1.0, 0.14, 1.0, "granite")]
        chimneys.append([x + chimney, base + 2.3, cz])

    # Lit windows in their openings, front and back.
    for face, sign, start, yaw in ((zf, 1.0, x0, 0.0), (zb, -1.0, x1, 180.0)):
        for u, v in _windows(width, height):
            if lit.random() < 0.26:
                shapes.append(_lit(start + sign * u, v, face + sign * 0.03, yaw, w=OPENING[2] - 0.1, h=OPENING[1] - OPENING[0] - 0.1))

    return shapes, cols, chimneys


def _houses(rows, seed, depth=12.0):
    """A terrace of houses along x, 20 m: `rows` [(height, facade,
    chimney)], each its own height under its own roof; some set back."""
    shapes, cols, chimneys = [], [], []
    width = 20.0 / len(rows)
    lit = random.Random(seed)

    for i, (h, slot, chimney) in enumerate(rows):
        x = -10.0 + (i + 0.5) * width
        back = (lit.random() - 0.5) * 0.8
        # (Each a little into its neighbours: no slit between them.)
        made, made_cols, tops = _house(x, width + 0.04, h, depth - abs(back), slot, lit, chimney, z=back / 2.0)
        shapes += made
        cols += made_cols
        chimneys += tops

    return shapes, cols, chimneys


W, O, S, B = FACADES
for _name, _rows, _seed, _size in (
        ("mass_houses_20", [(9.0, W, 1.2), (12.0, O, None), (10.5, W, -1.0)], 11, [20.6, 16.5, 13.1]),
        ("mass_houses_tall_20", [(15.0, O, 1.0), (18.0, S, None), (16.0, W, -0.8), (19.0, B, 0.9)], 12, [20.6, 24.0, 13.1]),
        ("mass_houses_low_20", [(7.5, W, None), (9.5, S, 1.0), (8.0, W, -1.2)], 13, [20.6, 13.0, 13.1]),
        ("mass_houses_mixed_20", [(11.0, B, 0.8), (14.0, W, None), (9.5, O, -0.9), (12.5, W, 1.1)], 14, [20.6, 18.0, 13.1])):
    _shapes, _cols, _tops = _houses(_rows, _seed)
    _mass(_name, _rows[0][1], _shapes, _cols, _size, budget=900)
    k.PIECES[_name]["sockets"] = {"chimney": _tops}


def _tower_house():
    """A tower house (a merchant's mirante): five storeys 7 m square, an
    open belvedere on top under a pyramid of tiles, one of its arches lit."""
    side, body = 7.0, 18.5
    shapes, cols, _ = _house(0.0, side, body, side, "facade_ochre", random.Random(21), roofed=False)
    shapes += [ks.box(0.0, body + 0.1, 0.0, side + 0.3, 0.2, side + 0.3, "granite")]

    for sx, sz in ((1, 1), (1, -1), (-1, 1), (-1, -1)):
        shapes.append(ks.box(sx * (side / 2.0 - 0.35), body + 1.6, sz * (side / 2.0 - 0.35), 0.7, 3.0, 0.7, "whitewash"))

    for yaw in (0.0, 90.0, 180.0, 270.0):
        shapes += ks.moved([ks.card(-1.4, body + 1.5, side / 2.0 - 1.2, 2.2, 2.6, "pitch"), ks.card(1.4, body + 1.5, side / 2.0 - 1.2, 2.2, 2.6, "pitch")], yaw)

    shapes.append(_lit(1.4, body + 1.5, -side / 2.0 + 1.15, 180.0, w=2.0, h=2.4))
    shapes += [ks.box(0.0, body + 3.2, 0.0, side + 0.6, 0.3, side + 0.6, "whitewash"),
               ks.prism(0.0, body + 4.6, 0.0, (side + 1.0) / math.sqrt(2.0), 2.6, 4, "roof_spanish", yaw=45.0, top=0.0)]
    cols = [col(0.0, (body + FOOT) / 2.0, 0.0, side, body - FOOT, side), col(0.0, body + 3.0, 0.0, side + 0.6, 2.0, side + 0.6)]
    return shapes, cols


def _parish():
    """A parish church: its nave 11 m across and 24 long (its front +z,
    toward the harbour) under a gable roof, a round window over its door, a
    belfry tower on its front's west corner to 30 m, its bell openings
    dark, a pyramid cap and an iron cross."""
    width, length, height = 11.0, 24.0, 12.0
    shapes, cols, _ = _house(0.0, length, height, width, "whitewash", random.Random(31))
    # (Turned: its ridge along z, its gable to the front.)
    shapes = [s2 for s2 in shapes if s2["kind"] != "card"]
    shapes = ks.moved(shapes, 90.0)
    # (Each collider's middle turned with it, and the collider itself.)
    cols = [[c[2], c[1], -c[0]] + c[3:7] + [c[7] + 90.0] + c[8:] for c in cols]
    front = length / 2.0
    shapes += [ks.disc(0.0, height + 1.4, front + 0.03, 1.2, 10, "glass_lit"), ks.card(0.0, 2.4, front + 0.03, 2.0, 4.0, "pitch"),
               ks.box(0.0, 4.7, front + 0.1, 2.8, 0.4, 0.3, "granite")]

    for zz in (-6.0, 0.0, 6.0):
        for side in (1.0, -1.0):
            shapes.append(ks.card(side * (width / 2.0 + 0.03), 7.5, zz, 1.0, 3.6, "pitch", 90.0 * side))

    tx, tz, ts, th = -width / 2.0 + 2.5, front - 2.5, 5.5, 30.0
    shapes += [ks.box(tx, (th + FOOT) / 2.0, tz, ts, th - FOOT, ts, "whitewash"), ks.box(tx, th - 6.0, tz, ts + 0.4, 0.4, ts + 0.4, "granite"),
               ks.box(tx, th + 0.2, tz, ts + 0.5, 0.4, ts + 0.5, "granite"),
               ks.prism(tx, th + 2.4, tz, (ts + 0.4) / math.sqrt(2.0), 4.0, 4, "roof_spanish", yaw=45.0, top=0.0),
               ks.box(tx, th + 5.4, tz, 0.16, 2.2, 0.16, "iron"), ks.box(tx, th + 5.8, tz, 1.0, 0.16, 0.16, "iron")]

    for yaw in (0.0, 90.0, 180.0, 270.0):
        shapes += ks.moved([ks.card(0.0, th - 3.0, ts / 2.0 + 0.03, 1.6, 3.6, "pitch")], yaw, offset=(tx, 0.0, tz))

    shapes.append(_lit(tx, th - 14.0, tz + ts / 2.0 + 0.03, w=0.7, h=1.2))
    # (Its pyramid stood on: two steps under it.)
    cols += [col(tx, (th + FOOT) / 2.0, tz, ts, th - FOOT, ts), col(tx, th + 1.2, tz, 4.4, 2.0, 4.4), col(tx, th + 2.8, tz, 2.2, 1.2, 2.2)]
    return shapes, cols


_shapes, _cols = _tower_house()
_mass("mass_tower_house", "facade_ochre", _shapes, _cols, [8.4, 26.0, 8.4], budget=700)
_shapes, _cols = _parish()
_mass("mass_parish", "whitewash", _shapes, _cols, [12.0, 37.0, 25.0], budget=900)

_mass("mass_terrace_wall_40", "granite_rough",
      [ks.box(0.0, 6.0, 0.0, 40.0, 12.0, 2.0, "granite_rough")] + [ks.box(x, 5.0, 1.4, 1.2, 10.0, 0.8, "granite_rough") for x in (-15.0, -5.0, 5.0, 15.0)],
      [col(0.0, 6.0, 0.0, 40.0, 12.0, 2.0)], [40.0, 12.0, 3.6])


def _cathedral():
    """90 m of nave (x) and aisles in golden sandstone to 40 m over its
    terrace, flying buttresses as fins down its sides, a transept, a rose
    in its west front (-x)."""
    shapes = [ks.box(0.0, 16.0, 0.0, 90.0, 32.0, 16.0, "ashlar_gold"), ks.gable(0.0, 32.0, 0.0, 90.0, 8.0, 16.0, "roof_spanish"),
              ks.box(0.0, 9.0, 12.0, 90.0, 18.0, 8.0, "ashlar_gold"), ks.box(0.0, 9.0, -12.0, 90.0, 18.0, 8.0, "ashlar_gold"),
              ks.box(15.0, 16.0, 0.0, 16.0, 32.0, 44.0, "ashlar_gold"), ks.gable(15.0, 32.0, 0.0, 44.0, 8.0, 16.0, "roof_spanish", 90.0),
              ks.prism(46.0, 14.0, 0.0, 9.0, 28.0, 8, "ashlar_gold"),
              ks.disc(-45.05, 24.0, 0.0, 5.0, 12, "rose_window", -90.0)]

    for x in range(-36, 45, 12):
        for side in (1.0, -1.0):
            shapes.append(ks.box(float(x), 21.0, side * 18.0, 1.4, 22.0, 6.0, "ashlar_gold"))
            shapes.append(ks.card(float(x) + 6.0, 24.0, side * 8.05, 2.0, 8.0, "stained_glass", 0.0 if side > 0 else 180.0))

    cols = [col(0.0, 20.0, 0.0, 90.0, 40.0, 32.0), col(15.0, 20.0, 0.0, 16.0, 40.0, 44.0)]
    return shapes, cols


def _belltower():
    """The bell tower: 13.5 m square, 95 m over the terrace; a belfry of
    arches, a lantern and its weather vane (the Giralda's)."""
    side = 13.5
    shapes = [ks.box(0.0, 35.0, 0.0, side, 70.0, side, "ashlar_gold"), ks.box(0.0, 76.0, 0.0, side - 1.0, 12.0, side - 1.0, "ashlar_gold"),
              ks.box(0.0, 84.0, 0.0, side - 3.0, 4.0, side - 3.0, "ashlar_gold"),
              ks.prism(0.0, 89.0, 0.0, 3.2, 6.0, 8, "ashlar_gold", top=2.2), ks.lathe(0.0, 92.0, 0.0, [[2.2, 0.0], [1.4, 1.4], [0.0, 2.2]], 8, "brass"),
              ks.prism(0.0, 94.4, 0.0, 0.2, 1.2, 4, "brass")]

    for yaw in (0.0, 90.0, 180.0, 270.0):
        shapes += ks.moved([ks.card(-3.0, 76.0, side / 2.0 - 0.45, 2.2, 7.0, "pitch"), ks.card(3.0, 76.0, side / 2.0 - 0.45, 2.2, 7.0, "pitch"),
                            ks.card(0.0, 40.0, side / 2.0 + 0.02, 1.4, 3.0, "pitch"), _lit(0.0, 60.0, side / 2.0 + 0.02)], yaw)

    return shapes, [col(0.0, 41.0, 0.0, side, 82.0, side)]


def _palace():
    """The palace of waters: long ochre-red wings round its patios under
    Moorish pyramid merlons, lit windows few."""
    shapes = [ks.box(0.0, 10.0, 0.0, 60.0, 20.0, 40.0, "render_salmon")]
    cols = [col(0.0, 10.0, 0.0, 60.0, 20.0, 40.0)]

    for i in range(20):
        x = -28.5 + i * 3.0

        for z in (20.0, -20.0):
            shapes.append(ks.prism(x, 20.5, z * 0.99, 0.7, 1.0, 4, "render_salmon", yaw=45.0, top=0.0))

    for x, z in ((-20.0, 20.02), (-4.0, 20.02), (12.0, 20.02), (26.0, 20.02)):
        shapes.append(_lit(x, 13.0, z))

    return shapes, cols


def _mirador():
    shapes = [ks.box(0.0, 12.5, 0.0, 10.0, 25.0, 10.0, "render_salmon"), ks.prism(0.0, 26.5, 0.0, 7.2, 3.0, 4, "roof_spanish", yaw=45.0, top=0.0)]

    for yaw in (0.0, 90.0, 180.0, 270.0):
        shapes += ks.moved([ks.card(-2.0, 22.0, 5.02, 1.4, 2.4, "glass_lit"), ks.card(2.0, 22.0, 5.02, 1.4, 2.4, "pitch")], yaw)

    # (Its pyramid roof stood on: two steps under it.)
    return shapes, [col(0.0, 12.5, 0.0, 10.0, 25.0, 10.0), col(0.0, 25.75, 0.0, 5.4, 1.5, 5.4), col(0.0, 26.9, 0.0, 2.4, 0.8, 2.4)]


def _aqueduct():
    """40 m of the aqueduct 40 m over its valley: three great arches under
    six smaller ones, the channel on top."""
    shapes = []

    for i in range(3):
        shapes += ks.arched_wall(40.0 / 3.0, 26.0, 2.6, 10.4, 20.8, 5.2, 0.0, "ashlar_gold", x=-40.0 / 3.0 + i * 40.0 / 3.0)

    for i in range(6):
        shapes += ks.arched_wall(40.0 / 6.0, 12.0, 2.0, 4.8, 8.6, 2.4, 0.0, "ashlar_gold", x=-100.0 / 6.0 + i * 40.0 / 6.0, y=26.0)

    shapes += [ks.box(0.0, 26.1, 0.0, 40.0, 0.4, 3.0, "ashlar_gold"), ks.box(0.0, 39.0, 0.0, 40.0, 2.0, 2.4, "granite")]
    cols = [col(0.0, 20.0, 0.0, 40.0, 40.0, 2.6)]
    return shapes, cols


def _bridge():
    """The Great Bridge: 95 m from the gorge's floor to its deck, a great arch
    through its middle with a chamber over it (its window lit), side arches
    over the water; parapets on its deck."""
    shapes = ks.arched_wall(60.0, 95.0, 14.0, 22.0, 52.0, 11.0, 0.0, "ashlar_gold")
    shapes += [ks.card(0.0, 70.0, 7.02, 2.0, 3.0, "glass_lit"), ks.card(0.0, 70.0, -7.02, 2.0, 3.0, "pitch"),
               ks.box(0.0, 95.6, 6.8, 60.0, 1.2, 0.4, "ashlar_gold"), ks.box(0.0, 95.6, -6.8, 60.0, 1.2, 0.4, "ashlar_gold")]

    for x in (-24.0, 24.0):
        shapes.append(ks.card(x, 60.0, 7.02, 4.0, 10.0, "pitch"))

    cols = [col(-20.5, 47.5, 0.0, 19.0, 95.0, 14.0), col(20.5, 47.5, 0.0, 19.0, 95.0, 14.0), col(0.0, 80.0, 0.0, 22.0, 30.0, 14.0)]
    return shapes, cols


def _battlements(length, top, z, slot="whitewash", every=3.0):
    return [ks.box(-length / 2.0 + (i + 0.5) * every, top + 0.9, z, 2.1, 1.8, 0.8, slot) for i in range(int(length // every))]


def _curtain():
    shapes = [ks.box(0.0, 7.5, 0.0, 30.0, 15.0, 3.0, "whitewash")] + _battlements(30.0, 15.0, 1.1)
    return shapes, [col(0.0, 7.5, 0.0, 30.0, 15.0, 3.0)]


def _castle_tower():
    shapes = [ks.prism(0.0, 12.5, 0.0, 6.2, 25.0, 12, "whitewash")]

    for i in range(6):
        a = math.radians(i * 60.0 + 30.0)
        shapes.append(ks.box(math.cos(a) * 5.6, 25.8, math.sin(a) * 5.6, 2.2, 1.6, 0.8, "whitewash", 90.0 - i * 60.0 - 30.0))

    return shapes, [col(0.0, 12.5, 0.0, 10.8, 25.0, 10.8)]


def _keep():
    """The keep: 36 m square, lime-white, 51 m to its wall-walk, turrets at
    its corners to 55 m (the crown: 155 m over the sea on the summit)."""
    side, body = 36.0, 51.0
    shapes = [ks.box(0.0, body / 2.0, 0.0, side, body, side, "whitewash"), ks.box(0.0, body - 12.0, 0.0, side + 0.6, 0.5, side + 0.6, "whitewash")]

    for sx, sz in ((1, 1), (1, -1), (-1, 1), (-1, -1)):
        shapes.append(ks.prism(sx * (side / 2.0 - 1.5), (55.0 - 1.8) / 2.0, sz * (side / 2.0 - 1.5), 3.2, 55.0 - 1.8, 8, "whitewash"))
        shapes.append(ks.lathe(sx * (side / 2.0 - 1.5), 55.0 - 1.8, sz * (side / 2.0 - 1.5), [[3.3, 0.0], [3.3, 1.8]], 8, "whitewash", caps=False))

    for yaw in (0.0, 90.0, 180.0, 270.0):
        shapes += ks.moved(_battlements(side - 8.0, body, side / 2.0 - 0.4, every=4.0), yaw)
        shapes += ks.moved([_lit(-6.0, 30.0, side / 2.0 + 0.02), ks.card(6.0, 38.0, side / 2.0 + 0.02, 0.8, 2.0, "pitch")], yaw)

    return shapes, [col(0.0, body / 2.0, 0.0, side, body, side)]


def _colossus():
    """The colossus: a forgotten king's statue, kneeling (his left knee
    down, his right foot planted) with his head bowed under its crown, his
    right hand on the pommel of a great sword driven point down before him,
    his mantle down his back; his left arm broken off at the shoulder and
    lying in the rubble. COLOSSUS_SCALE times a man's 124 m; on its rubble,
    sunk in the hills; its front +z. Read from afar by its outline: the
    crown, the shoulders, the hilt's cross between his knees."""
    S = COLOSSUS_SCALE

    def b(cx, cy, cz, sx, sy, sz, slot="granite", yaw=0.0, pitch=0.0, roll=0.0):
        return ks.box(cx * S, cy * S, cz * S, sx * S, sy * S, sz * S, slot, yaw, pitch, roll)

    def p(cx, cy, cz, r, h, sides, slot="granite", top=None, yaw=0.0, pitch=0.0, roll=0.0):
        return ks.prism(cx * S, cy * S, cz * S, r * S, h * S, sides, slot, yaw, pitch, roll, top=None if top is None else top * S)

    def mantle(points):
        return ks.slab([[x * S, y * S, z * S] for x, y, z in points], 4.0 * S, "granite", up=(0.0, 0.0, -1.0))

    shapes = [
        # Its rubble.
        p(0.0, 2.0, 0.0, 50.0, 16.0, 9, "rock", top=40.0), b(30.0, 5.0, 32.0, 12.0, 8.0, 10.0, "rock", -30.0, 0.0, 12.0),
        b(26.0, 4.0, -32.0, 16.0, 7.0, 9.0, "rock", 60.0),
        # His hips; his right leg forward (thigh, shin, foot); his left knee
        # on the rubble, its shin back along it.
        b(0.0, 50.0, 0.0, 30.0, 16.0, 20.0), b(10.0, 51.0, 16.0, 14.0, 14.0, 32.0), b(10.0, 32.0, 32.0, 12.0, 38.0, 12.0, pitch=4.0),
        b(10.0, 13.0, 37.0, 13.0, 7.0, 18.0), b(-10.0, 33.0, 6.0, 14.0, 36.0, 14.0, pitch=-22.0), b(-10.0, 14.0, -8.0, 12.0, 11.0, 34.0),
        # His waist and chest, bowed a little; his shoulders' pauldrons.
        p(0.0, 66.0, 0.0, 13.0, 22.0, 8, top=17.0, pitch=6.0), b(0.0, 88.0, 2.0, 38.0, 22.0, 18.0, pitch=8.0),
        b(21.0, 97.0, 2.0, 12.0, 9.0, 15.0, roll=-18.0), b(-21.0, 97.0, 2.0, 12.0, 9.0, 15.0, roll=18.0),
        # His mantle from his shoulders down his back, flared to the rubble.
        mantle([[-17.0, 100.0, -8.0], [17.0, 100.0, -8.0], [27.0, 12.0, -30.0], [-27.0, 12.0, -30.0]]),
        # His neck, his head bowed, his crown and its points.
        p(0.0, 103.0, 4.0, 5.5, 7.0, 7, pitch=18.0), p(0.0, 111.0, 7.0, 7.5, 13.0, 8, top=6.5, pitch=18.0),
        p(0.0, 118.5, 9.5, 8.2, 4.0, 8, top=8.6, pitch=18.0),
        # His right arm down to his hand on the pommel; the stump of his
        # left at the shoulder, the arm itself fallen into the rubble.
        b(23.0, 84.0, 8.0, 10.0, 28.0, 10.0, pitch=-24.0, roll=-6.0), b(13.0, 71.0, 24.0, 9.0, 9.0, 26.0, yaw=-30.0),
        b(4.0, 72.0, 35.0, 11.0, 12.0, 11.0), b(-24.0, 90.0, 2.0, 9.0, 10.0, 10.0, roll=30.0),
        b(-40.0, 9.0, 14.0, 10.0, 10.0, 46.0, "granite", 35.0, 0.0, 8.0),
        # The sword: its pommel, its grip, its guard, its blade into the rubble.
        p(0.0, 80.0, 36.0, 4.5, 6.0, 8, top=2.5), p(0.0, 71.0, 36.0, 2.2, 12.0, 6), b(0.0, 64.0, 36.0, 38.0, 3.6, 4.5),
        b(0.0, 37.0, 36.0, 7.5, 52.0, 2.4)]

    for i in range(6):
        a = math.radians(i * 60.0 + 30.0)
        shapes.append(b(math.cos(a) * 7.4, 122.0, 10.5 + math.sin(a) * 7.4, 1.8, 5.0, 1.8, pitch=18.0))

    return shapes, [col(0.0, 62.0 * S, 0.0, 60.0 * S, 124.0 * S, 60.0 * S)]


COLOSSUS_SCALE = 2.0

for _name, _slot, _build, _size, _budget in (
        ("mass_colossus", "granite", _colossus, [116.0 * COLOSSUS_SCALE, 128.0 * COLOSSUS_SCALE, 100.0 * COLOSSUS_SCALE], 900),
        ("mass_cathedral", "ashlar_gold", _cathedral, [110.0, 40.0, 44.0], 600),
        ("mass_belltower", "ashlar_gold", _belltower, [14.0, 95.0, 14.0], 600),
        ("mass_palace", "render_salmon", _palace, [60.0, 21.0, 40.4], 600),
        ("mass_mirador", "render_salmon", _mirador, [10.2, 28.0, 10.2], 600),
        ("mass_aqueduct_40", "ashlar_gold", _aqueduct, [40.0, 40.0, 3.0], 900),
        ("mass_bridge", "ashlar_gold", _bridge, [60.0, 96.2, 14.2], 600),
        ("mass_curtain_30", "whitewash", _curtain, [30.0, 16.8, 3.2], 600),
        ("mass_castle_tower", "whitewash", _castle_tower, [12.6, 26.6, 12.6], 600),
        ("mass_keep", "whitewash", _keep, [40.0, 55.0, 40.0], 600)):
    _shapes, _cols = _build()
    _mass(_name, _slot, _shapes, _cols, _size, _budget)
