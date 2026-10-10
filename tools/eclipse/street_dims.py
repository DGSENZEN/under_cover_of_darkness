"""The street and canal kit's dimensions (docs/superpowers/refs/mexico_city/
cards/street_canal.md), in one place: the pieces' Blender scripts build to
them and the district's dresser (tools/level/dress.py) lays by them, so a
flush piece's outline cut from the ground is the piece's own. Pure Python.

A run's piece in Blender axes: X along the run from its start (the origin),
its front (street, water, landing) looking -Y, Z up, the street at z 0.
"""

import math

# The street and the plaza's pavement (m).
STREET = 0.0
SKIRT = -0.3                    # flush pieces' sides reach down this far
# Kerbs: 1.5 long, 0.3 deep, 0.2 proud of the setts, their foot buried.
KERB_LENGTH = 1.5
KERB_DEPTH = 0.3
KERB_PROUD = 0.2
KERB_FOOT = -0.15
KERB_ROUND = 0.04               # the worn top front edge
# The drop at a crossing: 3 m of kerb fallen to DROP_LOW over its middle
# 2 m, a ramp behind it up to the pavement.
DROP_LENGTH = 3.0
DROP_FLAT = 2.0
DROP_LOW = 0.02
DROP_RAMP = 1.2
# The gutter grate before a kerb.
GRATE_LENGTH = 1.5
GRATE_DEPTH = 0.5
# The causeway band.
BAND = 3.0
# The tram: a strip of setts 2.4 wide, standard gauge, curves of radius 12.
TRACK_LENGTH = 4.5
STRIP_HALF = 1.2
GAUGE = 1.435
CURVE_RADIUS = 12.0
CURVE_SEGMENTS = 16
CONDUCTOR_OFF = 0.9             # the seeped third rail off the centreline
# The service hatch, square, centred on its origin.
HATCH = 1.2
HATCH_FRAME = 0.15

# The canal: street 0, landings -1, water and floor -2.
WALL_LENGTH = 4.5
WALL_SHORT = 1.5
LANDING = -1.0
WATER = -2.0
WALL_FOOT = -2.3                # buried under the canal's floor
WALL_THICK = 0.6
COPING_DEPTH = 0.35
COPING_PROUD = 0.15
COPING_BACK = COPING_DEPTH - COPING_PROUD     # how far the coping reaches behind the wall's face
ASHLAR_TOP = -1.1               # the colonial courses end here, the raised rubble begins
CORNER = 0.6                    # the landing's inside-corner block, square
STEP_RISE = 1.0 / 6.0
STEP_TREAD = 0.3
STEP_WIDTH = 2.4

# The bridges: across the canal (12 m) and its two quays' edges, 22 m.
BRIDGE_LENGTH = 22.0
BRIDGE_WIDTH = 4.0
PARAPET = 0.9
CROWN = 0.6
CANAL_WIDTH = 12.0

# How far apart a run's pieces stand.
PITCH = {"kerb_straight": KERB_LENGTH, "kerb_heaved": KERB_LENGTH, "gutter_grate": GRATE_LENGTH,
         "causeway_band": BAND, "tram_track": TRACK_LENGTH, "tram_track_shimmed": TRACK_LENGTH,
         "tram_conductor": TRACK_LENGTH, "canal_wall": WALL_LENGTH, "canal_wall_short": WALL_SHORT,
         "canal_wall_low": WALL_LENGTH, "culvert": WALL_LENGTH, "culvert_open": WALL_LENGTH}


def curve_centreline(segments=CURVE_SEGMENTS):
    """The tram curve's centreline: from (0, 0) heading +X, turning to +Y
    round (0, CURVE_RADIUS), ending at (R, R) heading +Y."""
    r = CURVE_RADIUS
    return [(r * math.sin(math.pi / 2 * i / segments), r - r * math.cos(math.pi / 2 * i / segments))
            for i in range(segments + 1)]


def _ring(inner, outer, segments=CURVE_SEGMENTS):
    r = CURVE_RADIUS
    arc = lambda radius, i: (radius * math.sin(math.pi / 2 * i / segments),
                             r - radius * math.cos(math.pi / 2 * i / segments))
    return [arc(outer, i) for i in range(segments + 1)] + [arc(inner, i) for i in range(segments, -1, -1)]


def _rect(x0, y0, x1, y1):
    return [(float(x0), float(y0)), (float(x1), float(y0)), (float(x1), float(y1)), (float(x0), float(y1))]


def footprint(piece):
    """A flush piece's outline in its own Blender x, y: what the ground is
    cut round where it lies. A drop's is its ramp and kerb, which the
    pavement opens for."""
    outlines = {
        "tram_track": lambda: _rect(0, -STRIP_HALF, TRACK_LENGTH, STRIP_HALF),
        "tram_track_shimmed": lambda: _rect(0, -STRIP_HALF, TRACK_LENGTH, STRIP_HALF),
        "tram_track_curve": lambda: _ring(CURVE_RADIUS - STRIP_HALF, CURVE_RADIUS + STRIP_HALF),
        "causeway_band": lambda: _rect(0, -BAND / 2, BAND, BAND / 2),
        "hatch": lambda: _rect(-HATCH / 2, -HATCH / 2, HATCH / 2, HATCH / 2),
        "gutter_grate": lambda: _rect(0, -GRATE_DEPTH, GRATE_LENGTH, 0),
        "kerb_drop": lambda: _rect(0, 0, DROP_LENGTH, KERB_DEPTH + DROP_RAMP),
    }
    return outlines[piece]()
