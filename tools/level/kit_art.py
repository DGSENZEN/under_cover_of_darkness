"""Kit v1's building dressing: the gatehouse's arches, banners on their rods,
the barracks' plaster and board walls framed in dark oak, joists under its
floors and trusses over its mess hall. Pure data, as kit_recipes (which
imports this at its end).
"""

import math

import kit_recipes as k
import kit_shapes as ks

# A frame's timbers: how wide their faces are, how far they stand out of
# the wall (within the kit's wall slack).
POST = 0.18
PLATE = 0.24
RAIL = 0.12
PROUD = 0.05


# Banners: the garrison's arms on cloth, hung from an iron rod on two
# brackets into the wall behind (local -z), its tails at its foot (y 0).

BANNER = (1.0, 2.5)

k.PIECES["banner"]["size"] = [1.4, BANNER[1] + 0.1, 0.2]
k.model("banner", [ks.card(0.0, BANNER[1] / 2.0, 0.035, BANNER[0], BANNER[1], "banner"),
                   ks.box(0.0, BANNER[1] + 0.03, 0.055, BANNER[0] + 0.24, 0.035, 0.035, "iron"),
                   ks.lathe(-(BANNER[0] / 2.0 + 0.14), BANNER[1] + 0.03, 0.055, [[0.0, -0.035], [0.035, 0.0], [0.0, 0.035]], 6, "iron"),
                   ks.lathe(BANNER[0] / 2.0 + 0.14, BANNER[1] + 0.03, 0.055, [[0.0, -0.035], [0.035, 0.0], [0.0, 0.035]], 6, "iron"),
                   ks.box(-BANNER[0] / 2.0 + 0.05, BANNER[1] + 0.03, 0.02, 0.03, 0.03, 0.07, "iron"),
                   ks.box(BANNER[0] / 2.0 - 0.05, BANNER[1] + 0.03, 0.02, 0.03, 0.03, 0.07, "iron")])


# The gate's arches: a round arch over each end of the passage, standing
# proud of the gatehouse's faces up to their tops, its hood of voussoirs, a
# keystone, imposts at its springing, a course at the walk's level. Its top
# (over the walk's floor) is the walk's parapet there, and solid; the rest
# hangs over the passage, never in it.

GATE = {"width": 5.0, "height": 6.0, "depth": 0.3, "opening": 3.9, "spring": 2.55, "walk": 4.8}


def _gate_arch():
    g = GATE
    half = g["opening"] / 2.0
    face = g["depth"] / 2.0
    out = ks.arched_wall(g["width"], g["height"], g["depth"], g["opening"], g["spring"], half, 0.0, "ashlar")
    out.append(ks.ring(0.0, g["spring"], face + 0.06, half, half + 0.42, 0.12, 0.0, 180.0, 12, "ashlar"))
    out.append(ks.box(0.0, g["spring"] + half + 0.22, face + 0.1, 0.46, 0.62, 0.2, "ashlar"))

    for side in (-1.0, 1.0):
        out.append(ks.box(side * (half + 0.25), g["spring"] - 0.06, face + 0.06, 0.5, 0.16, 0.12, "ashlar"))

    out.append(ks.box(0.0, g["walk"] + 0.1, face + 0.05, g["width"] + 0.1, 0.2, 0.1, "ashlar"))
    return out


_parapet = GATE["height"] - GATE["walk"]
k.piece("gate_arch", "column", "ashlar", "stone", [],
        cols=[[0.0, GATE["walk"] + _parapet / 2.0, 0.0, GATE["width"], _parapet, GATE["depth"], "stone", 0.0, 0.0, 0.0]],
        size=[GATE["width"], GATE["height"], GATE["depth"]])
k.model("gate_arch", _gate_arch())


# Framed walls: the barracks' plaster between dark oak posts, rails and
# braces; its board partitions between posts and plates. On both faces
# (which one is indoors depends on how a run is laid).

def _timber(x0, y0, x1, y1, z, width):
    length = math.hypot(x1 - x0, y1 - y0)
    angle = math.degrees(math.atan2(y1 - y0, x1 - x0))
    return ks.box((x0 + x1) / 2.0, (y0 + y1) / 2.0, z, length, width, 2.0 * PROUD, "beam", 0.0, 0.0, angle)


def _spans(length, gap):
    """The stretches of a wall `length` long either side of an opening `gap`
    wide in its middle (all of it without one)."""
    half = length / 2.0

    if not gap:
        return [(-half, half)]

    return [(-half, -gap / 2.0), (gap / 2.0, half)]


def framing(length, depth, kind="plain", gap=0.0, braced=True, height=k.STOREY):
    """The frame on both faces of a wall `length` x `height`, `depth` thick:
    sole and top plates, a post at its left end (the next piece's is at its
    right), a mid rail and braces for plaster; round an opening (`kind`
    "door", "window", "arch" of width `gap`) posts either side, a lintel or
    head rail, no sole across a doorway."""
    out = []
    half = length / 2.0

    for face in (1.0, -1.0):
        z = face * depth / 2.0

        for a, b in _spans(length, gap if kind in ("door", "arch") else 0.0):
            out.append(_timber(a, PLATE / 2.0, b, PLATE / 2.0, z, PLATE))

        out.append(_timber(-half, height - 0.14, half, height - 0.14, z, 0.28))

        # (A door's or an arch's own post stands where the end post would.)
        if kind not in ("door", "arch"):
            out.append(_timber(-half + POST / 2.0, 0.0, -half + POST / 2.0, height, z, POST))

        if length >= 3.9 and kind == "plain":
            out.append(_timber(0.0, 0.0, 0.0, height, z, POST))

        if kind != "plain":
            for side in (-1.0, 1.0):
                x = side * (gap / 2.0 + POST / 2.0)
                out.append(_timber(x, 0.0, x, height, z, POST))

        if kind == "door":
            out.append(_timber(-gap / 2.0 - POST, k.DOOR[1] + 0.1, gap / 2.0 + POST, k.DOOR[1] + 0.1, z, 0.2))
        elif kind == "window":
            head = k.WINDOW[2] + k.WINDOW[1] + 0.06
            out.append(_timber(-half, head, half, head, z, RAIL))

        if braced and kind in ("plain", "window"):
            out.append(_timber(-half, k.WINDOW[2] - 0.02, half, k.WINDOW[2] - 0.02, z, RAIL))

        if braced and kind == "plain" and length >= 1.9:
            for start in ([-half] if length < 3.9 else [-half, 0.0]):
                out.append(_timber(start + POST, k.WINDOW[2] + 0.06, start + POST + 1.0, height - 0.3, z, 0.14))

    return out


for _suffix, _depth in (("", k.OUTER), ("_thin", k.INNER)):
    for _material, _braced in (("plaster", True), ("timber", False)):
        _slot = k.WALLS[_material][0]

        for _length, _label in ((1.0, "1"), (2.0, "2"), (2.4, "2p4"), (4.0, "4")):
            k.model("wall_%s%s_%s" % (_material, _suffix, _label),
                    [ks.box(0.0, k.STOREY / 2.0, 0.0, _length, k.STOREY, _depth, _slot)] + framing(_length, _depth, braced=_braced))

        # A framed wall's door is flat-headed under its lintel.
        k.model("wall_%s%s_door" % (_material, _suffix),
                ks.arched_wall(2.0, k.STOREY, _depth, k.DOOR[0], k.DOOR[1], 0.0, 0.0, _slot)
                + framing(2.0, _depth, "door", k.DOOR[0], _braced))
        k.model("wall_%s%s_window" % (_material, _suffix),
                ks.arched_wall(2.0, k.STOREY, _depth, k.WINDOW[0], k.WINDOW[2] + k.WINDOW[1], 0.0, k.WINDOW[2], _slot)
                + [ks.box(0.0, k.WINDOW[2] - 0.04, _depth / 2.0 + 0.03, k.WINDOW[0] + 0.2, 0.08, 0.06, "beam")]
                + framing(2.0, _depth, "window", k.WINDOW[0], _braced))
        k.model("wall_%s%s_arch" % (_material, _suffix),
                ks.arched_wall(2.4, k.STOREY, _depth, k.ARCH[0], k.ARCH[1] - k.ARCH[0] / 2.0, k.ARCH[0] / 2.0, 0.0, _slot)
                + framing(2.4, _depth, "arch", k.ARCH[0], _braced))


# Joists under the barracks' upper floor (three to a 2 m strip, their tops
# at the pivot: the floor's underside), and trusses across the mess hall.
# Drawn only.

JOIST = (0.14, 0.2)

for _tenths in (22, 44, 72, 76):
    _length = _tenths / 10.0
    _name = "joists_%d" % _tenths
    k.piece(_name, "dressing", "beam", "wood", [], cols=[], size=[_length, JOIST[1], 2.0])
    k.model(_name, [ks.box(0.0, -JOIST[1] / 2.0, z, _length, JOIST[1], JOIST[0], "beam") for z in (-0.67, 0.0, 0.67)])


def _hall_truss(span, tie_y, ceiling):
    """A truss across a hall `span` wide (x), its tie beam at `tie_y` under a
    ceiling at `ceiling`: wall posts on stone corbels, curved braces up to
    the tie beam, queen posts to the ceiling."""
    half = span / 2.0
    out = [ks.box(0.0, tie_y, 0.0, span, 0.34, 0.3, "beam")]

    for side in (-1.0, 1.0):
        post_x = side * (half - 0.15)
        out.append(ks.box(post_x, tie_y - 1.0, 0.0, 0.26, 2.0, 0.26, "beam"))
        out.append(ks.box(side * (half - 0.2), tie_y - 2.1, 0.0, 0.4, 0.3, 0.4, "ashlar"))
        # The brace: a quarter curve in three straight lengths.
        points = []

        for i in range(4):
            a = math.radians(90.0 * i / 3.0)
            points.append((post_x - side * (1.6 - 1.6 * math.cos(a)), tie_y - 0.17 - 1.4 * (1.0 - math.sin(a))))

        for (x0, y0), (x1, y1) in zip(points, points[1:]):
            length = math.hypot(x1 - x0, y1 - y0)
            angle = math.degrees(math.atan2(y1 - y0, x1 - x0))
            out.append(ks.box((x0 + x1) / 2.0, (y0 + y1) / 2.0, 0.0, length + 0.08, 0.18, 0.2, "beam", 0.0, 0.0, angle))

        out.append(ks.box(side * half * 0.35, (tie_y + ceiling) / 2.0, 0.0, 0.2, ceiling - tie_y, 0.2, "beam"))

    return out


k.piece("hall_truss_15", "dressing", "beam", "wood", [], cols=[], size=[15.2, 6.0, 0.4])
k.model("hall_truss_15", _hall_truss(15.2, 5.45, 6.0))
