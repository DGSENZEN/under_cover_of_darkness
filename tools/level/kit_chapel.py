"""The chapel's art (kit v1): open to its rafters under arch-braced trusses on
wall shafts, a carved frieze under them, a rose window in its east gable and
an oculus and bell-cote in its west, a fleche on its ridge; outside,
buttresses, a plinth, a string course, a corbelled cornice and a stepped
portal round its door; inside, a tiled chancel step, a dressed altar before
a reredos, pews with carved ends. Pure data, as kit_recipes (which imports
this at its end).

The nave is 20 m long (x -6..14) and 9.6 across its walls (z -25.6..-16,
inside -25.2..-16.4), 12 m to its wall tops.
"""

import math

import kit_recipes as k
import kit_shapes as ks

NAVE = 9.6
INSIDE = 9.2
WALLS_TOP = 12.0
RISE = 5.0


def _drawn(name, family, slot, shapes, size):
    """A piece drawn only (nothing stops on it)."""
    k.piece(name, family, slot, "stone", [], cols=[], size=size)
    k.model(name, shapes)


# ---------------------------------------------------------------------------
# The ceiling under the roof stays what stops sight and anything thrown, but
# it is not drawn: the nave is open to its rafters.
# ---------------------------------------------------------------------------

k.piece("ceiling_hidden_4", "ceiling", "boards", "ceiling", [], cols=[[0.0, -0.1, 0.0, 4.0, 0.2, 4.0, "ceiling", 0.0, 0.0, 0.0]],
        size=[4.0, 0.2, 4.0])


# ---------------------------------------------------------------------------
# The gables (across the nave, their faces along its axis): the east's rose,
# the west's oculus under a bell-cote. Glass on both faces (it glows from
# within at night and from without by day), a stone ring and tracery round
# it.
# ---------------------------------------------------------------------------

def _rose(y, radius, spokes, face):
    z = face * (k.OUTER / 2.0 + 0.005)
    out = [ks.disc(0.0, y, z, radius, 16, "rose_window"),
           ks.ring(0.0, y, face * (k.OUTER / 2.0 + 0.05), radius - 0.03, radius + 0.25, 0.1, 0.0, 360.0, 12, "ashlar")]

    if spokes:
        out.append(ks.ring(0.0, y, face * (k.OUTER / 2.0 + 0.03), radius * 0.2, radius * 0.28, 0.06, 0.0, 360.0, 8, "ashlar"))

        for i in range(spokes):
            a = i * 360.0 / spokes + 180.0 / spokes
            r = radius * 0.64
            out.append(ks.box(math.cos(math.radians(a)) * r, y + math.sin(math.radians(a)) * r, face * (k.OUTER / 2.0 + 0.03),
                              radius * 0.72, 0.06, 0.06, "ashlar", 0.0, 0.0, a))

    return out


def _bell_cote(y):
    """An open bell-cote on a gable's apex: two piers, a round arch, a small
    gable and cross over it, the bell hung in it."""
    return [ks.box(0.0, y - 0.15, 0.0, 1.5, 0.5, 0.5, "ashlar"),
            ks.box(-0.55, y + 0.8, 0.0, 0.3, 1.6, 0.45, "ashlar"), ks.box(0.55, y + 0.8, 0.0, 0.3, 1.6, 0.45, "ashlar"),
            ks.ring(0.0, y + 1.3, 0.0, 0.4, 0.55, 0.45, 0.0, 180.0, 6, "ashlar"),
            ks.box(0.0, y + 2.0, 0.0, 1.45, 0.3, 0.55, "ashlar"),
            ks.gable(0.0, y + 2.15, 0.0, 1.5, 0.75, 0.55, "ashlar"),
            ks.box(0.0, y + 3.25, 0.0, 0.07, 0.6, 0.07, "iron"), ks.box(0.0, y + 3.35, 0.0, 0.36, 0.07, 0.07, "iron"),
            ks.lathe(0.0, y + 0.95, 0.0, [[0.26, -0.32], [0.24, -0.26], [0.17, -0.1], [0.14, 0.08], [0.09, 0.16], [0.0, 0.18]], 8, "brass"),
            ks.box(0.0, y + 0.55, 0.0, 0.04, 0.2, 0.04, "iron")]


east = [ks.gable(0.0, 0.0, 0.0, NAVE, RISE, k.OUTER, "ashlar")] + _rose(1.75, 1.1, 8, 1.0) + _rose(1.75, 1.1, 8, -1.0)
west = [ks.gable(0.0, 0.0, 0.0, NAVE, RISE, k.OUTER, "ashlar")] + _rose(1.6, 0.75, 0, 1.0) + _rose(1.6, 0.75, 0, -1.0) + _bell_cote(RISE)
_drawn("gable_chapel_east", "roof", "ashlar", east, [NAVE, RISE, k.OUTER])
_drawn("gable_chapel_west", "roof", "ashlar", west, [NAVE, RISE + 3.7, k.OUTER])


# ---------------------------------------------------------------------------
# The fleche: a timber lantern straddling the ridge, its slated spire, a
# gilt ball and an iron cross. Its pivot is the roof's apex under the ridge.
# ---------------------------------------------------------------------------

fleche = [ks.box(0.0, 0.6, 0.0, 1.3, 1.6, 1.3, "beam"), ks.box(0.0, 1.45, 0.0, 1.5, 0.12, 1.5, "beam"),
          ks.box(0.0, 2.15, 0.0, 0.9, 1.3, 0.9, "pitch"), ks.box(0.0, 2.85, 0.0, 1.45, 0.12, 1.45, "beam")]

for _i in range(8):
    _a = _i * math.tau / 8 + math.tau / 16
    fleche.append(ks.prism(math.cos(_a) * 0.55, 2.15, math.sin(_a) * 0.55, 0.05, 1.3, 4, "beam"))

fleche += [ks.lathe(0.0, 2.9, 0.0, [[0.72, 0.0], [0.05, 6.0], [0.0, 6.1]], 8, "roof_fish"),
           ks.lathe(0.0, 9.05, 0.0, [[0.0, -0.1], [0.1, 0.0], [0.0, 0.1]], 6, "brass"),
           ks.box(0.0, 9.5, 0.0, 0.06, 0.8, 0.06, "iron"), ks.box(0.0, 9.65, 0.0, 0.4, 0.06, 0.06, "iron")]
_drawn("fleche", "roof", "roof_fish", fleche, [1.5, 10.0, 1.5])


# ---------------------------------------------------------------------------
# Inside: an arch-braced tie-beam truss every bay (across the nave, x),
# its posts on stone corbels, its pivot at the walls' top; the shafts up the
# walls under the corbels; a carved frieze along the walls under them.
# ---------------------------------------------------------------------------

def _beam(x0, y0, x1, y1, width=0.24, depth=0.24, slot="beam"):
    length = math.hypot(x1 - x0, y1 - y0)
    return ks.box((x0 + x1) / 2.0, (y0 + y1) / 2.0, 0.0, length, width, depth, slot, 0.0, 0.0, math.degrees(math.atan2(y1 - y0, x1 - x0)))


def _truss():
    half = INSIDE / 2.0
    out = [ks.box(0.0, 0.15, 0.0, INSIDE, 0.34, 0.3, "beam"), ks.box(0.0, 2.45, 0.0, 0.24, 4.3, 0.24, "beam"),
           ks.box(0.0, 2.9, 0.0, 3.6, 0.26, 0.24, "beam")]

    for side in (-1.0, 1.0):
        post = side * (half - 0.15)
        out += [ks.box(post, -1.1, 0.0, 0.26, 2.2, 0.26, "beam"),
                ks.box(side * (half - 0.18), -2.35, 0.0, 0.42, 0.3, 0.42, "ashlar"),
                ks.box(side * (half - 0.14), -2.6, 0.0, 0.3, 0.22, 0.3, "ashlar"),
                _beam(side * (half - 0.1), 0.32, side * 0.12, 4.5, 0.26)]
        points = [(post - side * (2.0 - 2.0 * math.cos(math.radians(30.0 * i))), -0.02 - 1.85 * (1.0 - math.sin(math.radians(30.0 * i))))
                  for i in range(4)]

        for (x0, y0), (x1, y1) in zip(points, points[1:]):
            out.append(_beam(x0, y0, x1, y1, 0.2, 0.22))

    return out


_drawn("chapel_truss", "dressing", "beam", _truss(), [INSIDE, 7.3, 0.4])

# A shaft up the wall (its back on the wall, local -z) from the floor to a
# truss's corbel.
_drawn("wall_shaft", "column", "ashlar",
       [ks.box(0.0, 0.2, 0.14, 0.46, 0.4, 0.28, "ashlar"), ks.prism(0.0, 4.8, 0.12, 0.13, 8.8, 8, "ashlar"),
        ks.lathe(0.0, 9.2, 0.12, [[0.13, 0.0], [0.2, 0.25], [0.2, 0.35]], 8, "ashlar")], [0.46, 9.6, 0.3])


def _frieze(length):
    """The carved band along a wall (its back on the wall), a ledge under it."""
    return [ks.slab([[-length / 2.0, 0.34, 0.08], [length / 2.0, 0.34, 0.08], [length / 2.0, 0.02, 0.08], [-length / 2.0, 0.02, 0.08]],
                    0.08, "band", edge="ashlar", tile=[1.25, 0.32], up=(0.0, 0.0, 1.0)),
            ks.box(0.0, 0.0, 0.07, length, 0.06, 0.14, "ashlar"), ks.box(0.0, 0.37, 0.06, length, 0.06, 0.12, "ashlar")]


for _length, _label in ((INSIDE * 2.0 + 0.8, "19p2"), (INSIDE, "9p2")):
    _drawn("chapel_frieze_%s" % _label, "column", "band", _frieze(_length), [_length, 0.4, 0.2])


# ---------------------------------------------------------------------------
# Outside: buttresses (their backs on the wall, local z 0, standing out
# along +z), the plinth, the string course, the cornice on its corbels, the
# portal round a door.
# ---------------------------------------------------------------------------

def _weathering(y, z0, z1, width, rise):
    return ks.slab([[-width / 2.0, y + rise, z0], [width / 2.0, y + rise, z0], [width / 2.0, y, z1], [-width / 2.0, y, z1]], 0.3, "ashlar",
                   up=(0.0, 1.0, 1.0))


k.piece("buttress_chapel", "column", "ashlar", "stone", [], cols=[[0.0, 3.0, 0.45, 0.9, 6.0, 0.9, "stone", 0.0, 0.0, 0.0]], size=[0.9, 11.4, 1.8])
k.model("buttress_chapel", [ks.box(0.0, 3.0, 0.45, 0.9, 6.0, 0.9, "ashlar"), _weathering(6.0, 0.45, 0.92, 0.9, 0.55),
                            ks.box(0.0, 8.25, 0.25, 0.8, 4.5, 0.5, "ashlar"), _weathering(10.5, 0.0, 0.52, 0.8, 0.8)])


def _course(length, height, depth, corbels=False):
    out = [ks.box(0.0, height / 2.0, depth / 2.0, length, height, depth, "ashlar")]

    if corbels:
        for i in range(int(length)):
            out.append(ks.box(-length / 2.0 + 0.5 + i, -0.1, 0.09, 0.16, 0.2, 0.18, "ashlar"))

    return out


for _length in (4.2, 7.0, 11.0):
    _drawn("chapel_plinth_%s" % str(_length).replace(".", "p"), "column", "ashlar", _course(_length, 0.6, 0.12), [_length, 0.6, 0.24])

for _length in (9.6, 20.0):
    _drawn("chapel_course_%s" % str(_length).replace(".", "p"), "column", "ashlar", _course(_length, 0.2, 0.14), [_length, 0.2, 0.28])
    _drawn("chapel_cornice_%s" % str(_length).replace(".", "p"), "column", "ashlar", _course(_length, 0.3, 0.26, True), [_length, 0.4, 0.52])


def _portal():
    """Round a door 1.2 wide springing at 1.6 (round-headed): three orders of
    arch stepping out, their jambs and shafts, a hood, a gablet with a cross."""
    out = []

    for i in range(3):
        inner, proud = 0.62 + 0.14 * i, 0.1 * (i + 1)
        out.append(ks.ring(0.0, 1.6, proud / 2.0, inner, inner + 0.14, proud, 0.0, 180.0, 8, "ashlar"))

        for side in (-1.0, 1.0):
            x = side * (inner + 0.07)
            out.append(ks.box(x, 0.8, proud / 2.0, 0.14, 1.6, proud, "ashlar"))
            out.append(ks.prism(x, 0.8, proud + 0.035, 0.045, 1.5, 6, "ashlar"))

    out.append(ks.ring(0.0, 1.6, 0.34, 1.04, 1.14, 0.08, 0.0, 180.0, 8, "ashlar"))

    for side in (-1.0, 1.0):
        out.append(ks.box(side * 1.09, 1.58, 0.34, 0.16, 0.12, 0.1, "ashlar"))

    out += [ks.gable(0.0, 2.72, 0.2, 2.6, 1.05, 0.2, "ashlar"), ks.box(0.0, 4.05, 0.2, 0.08, 0.5, 0.08, "ashlar"),
            ks.box(0.0, 4.12, 0.2, 0.3, 0.08, 0.08, "ashlar")]
    return out


_drawn("chapel_portal", "column", "ashlar", _portal(), [2.6, 4.4, 0.8])

# The ground floor's windows glazed (as the lancets are).
_drawn("glass_window", "dressing", "stained_glass_small", [ks.card(0.0, k.WINDOW[1] / 2.0, 0.0, k.WINDOW[0], k.WINDOW[1], "stained_glass_small")],
       [k.WINDOW[0], k.WINDOW[1], 0.1])


# ---------------------------------------------------------------------------
# The chancel: a step of patterned tiles, the altar on it (its frontal to the
# nave, local +z; linen, a brass cross), the reredos framing the angels
# behind it, the pews' carved ends.
# ---------------------------------------------------------------------------

k.piece("chapel_dais", "floor", "tiles_chancel", "stone", [], cols=[[0.0, 0.075, 0.0, 3.6, 0.15, 6.0, "stone", 0.0, 0.0, 0.0]], size=[3.6, 0.15, 6.0])
k.model("chapel_dais", [ks.box(0.0, 0.075, 0.0, 3.6, 0.15, 6.0, "tiles_chancel"), ks.box(-1.77, 0.08, 0.0, 0.08, 0.16, 6.02, "ashlar")])

k.model("altar", [ks.box(0.0, 0.47, 0.0, 2.3, 0.94, 0.9, "ashlar"), ks.box(0.0, 0.98, 0.0, 2.5, 0.08, 1.05, "ashlar"),
                  ks.box(0.0, 1.03, 0.02, 2.46, 0.02, 1.08, "wax"), ks.card(0.0, 0.5, 0.456, 2.2, 0.88, "altar_frontal"),
                  ks.box(0.0, 1.08, -0.35, 0.2, 0.06, 0.12, "brass"), ks.box(0.0, 1.43, -0.35, 0.06, 0.66, 0.06, "brass"),
                  ks.box(0.0, 1.55, -0.35, 0.36, 0.06, 0.06, "brass")])

# (Its shafts and finials gilt, to catch the candles.)
_reredos = [ks.box(0.0, 1.46, 0.12, 3.9, 0.12, 0.26, "ashlar"), ks.box(0.0, 3.16, 0.1, 3.9, 0.1, 0.2, "brass"),
            ks.gable(0.0, 3.2, 0.08, 3.6, 1.1, 0.16, "ashlar"), ks.ring(0.0, 3.62, 0.17, 0.2, 0.28, 0.04, 0.0, 360.0, 10, "brass"),
            ks.box(0.0, 4.5, 0.08, 0.06, 0.5, 0.06, "brass"), ks.box(0.0, 4.58, 0.08, 0.3, 0.06, 0.06, "brass")]

for _side in (-1.0, 1.0):
    _reredos += [ks.prism(_side * 1.85, 1.9, 0.12, 0.1, 2.6, 8, "brass"),
                 ks.lathe(_side * 1.85, 3.2, 0.12, [[0.15, 0.0], [0.0, 0.7]], 8, "brass"),
                 ks.box(_side * 1.85, 0.3, 0.12, 0.32, 0.6, 0.32, "ashlar")]

_drawn("reredos", "dressing", "ashlar", _reredos, [4.0, 4.3, 0.4])

# (2.4 m: the nave keeps side aisles by its walls, wide enough to walk.)
k.model("pew", [ks.box(0.0, 0.44, -0.02, 2.3, 0.06, 0.42, "boards"), ks.box(0.0, 0.8, 0.2, 2.3, 0.62, 0.05, "boards"),
                ks.box(0.0, 1.13, 0.2, 2.36, 0.06, 0.1, "beam"), ks.box(0.0, 0.97, 0.3, 2.3, 0.04, 0.16, "boards", 0.0, -12.0, 0.0),
                ks.box(0.0, 0.1, -0.4, 2.2, 0.1, 0.14, "leather"), ks.box(0.0, 0.24, 0.1, 2.3, 0.06, 0.06, "beam")]
      + [ks.box(side * 1.17, 0.5, 0.05, 0.06, 1.0, 0.56, "beam") for side in (-1.0, 1.0)]
      + [ks.lathe(side * 1.17, 1.0, 0.2, [[0.06, 0.0], [0.08, 0.08], [0.04, 0.16], [0.0, 0.2]], 6, "beam") for side in (-1.0, 1.0)])
