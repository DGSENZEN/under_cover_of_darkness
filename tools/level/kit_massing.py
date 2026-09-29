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


def _houses(heights, depth=12.0, slot="whitewash"):
    """A terrace of houses along x, 20 m, each its own height and roof, a
    few windows lit on the front (+z)."""
    shapes, cols = [], []
    width = 20.0 / len(heights)

    for i, h in enumerate(heights):
        x = -10.0 + (i + 0.5) * width
        shapes.append(ks.box(x, h / 2.0, 0.0, width - 0.1, h, depth, slot))
        shapes.append(ks.gable(x, h, 0.0, depth, 2.2, width - 0.1, "roof_spanish", 90.0))
        cols.append(col(x, h / 2.0, 0.0, width, h, depth))

        for j, fy in enumerate((0.35, 0.7)):
            if (i + j) % 2 == 0:
                shapes.append(_lit(x + (j - 0.5) * width * 0.4, h * fy, depth / 2.0 + 0.02))

    return shapes, cols


_shapes, _cols = _houses([9.0, 12.0, 10.5])
_mass("mass_houses_20", "whitewash", _shapes, _cols, [20.0, 12.5, 12.2])
_shapes, _cols = _houses([15.0, 18.0, 16.0, 19.0], slot="render_ochre")
_mass("mass_houses_tall_20", "render_ochre", _shapes, _cols, [20.0, 21.5, 12.2])

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

    return shapes, [col(0.0, 12.5, 0.0, 10.0, 25.0, 10.0)]


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


for _name, _slot, _build, _size, _budget in (
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
