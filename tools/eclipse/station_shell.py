"""The Zócalo station's shell dressed (docs/superpowers/specs/2026-10-27-metro-station-design.md; plan
docs/superpowers/plans/2026-10-30-metro-station.md, Task 4): the Company's tile up the hall's 5 m walls, the platforms'
5.5 m and the stairwells' 11 m (underground_walls' panel at each height: the dark skirting, the line's band, the cap,
plaster above), plaster sheets over the doors, the doors' cement reveals and the tunnels' portals; the terrazzo
floor's slabs, the platforms' stone copings with the yellow line, the pit's concrete faces under them; the hall's
tiled columns and the plain ones between the tracks; the hall's coffered ceiling, a fluorescent fitting in each
coffer, the platforms' plaster and their strip fittings; the flights' treads and handrails; the hanging direction
signs and the line map, their faces blank (the user's words).

Maps/metro_station.gd lays them all out (in MultiMeshes: there are thousands).

Frames (Blender: x along, -y out toward the room, z up; Godot turns -y into +z):
- wall_<h>, wall_<h>_worn: a panel as underground_walls builds one, PANEL along +x from 0, the wall's face at y = 0,
  floor (z = 0) to h;
- plaster_sheet: PANEL along +x, 1 m up from z = 0, on the wall's face;
- pit_face: PANEL along +x, the pit's face toward -y, the bed (z = 0) up to the platform's underside;
- floor_slab_a/b/c: MODULE square centred on the origin, its top at z = 0;
- coping: PANEL along +x, its edge at y = 0, reaching COPING in along +y, its top at z = 0;
- column_hall, column_track: centred on the origin, from z = 0 up;
- coffer: COFFER square centred on the origin, hung from the ceiling's underside at z = 0; ceiling_panel: MODULE
  square centred, its underside at z = 0; strip_fitting: PANEL along +x, hung from z = 0;
- tread: FLIGHT wide across x, centred, its nose at y = 0 reaching TREAD back along +y, its top at z = 0;
- handrail: RAIL along +x, its top 0.9 m over z = 0, a post at x = 0;
- reveal_<w>x<h>x<d>: an opening's cement lining, w wide centred on x = 0, h up from z = 0, d deep along +y from 0;
- portal_mouth, portal_tunnel: a cement frame round an opening (the mouth's, the tunnel's) on the face at y = 0;
- sign_board: hung on two rods from z = 0, its two faces the `sign` slot; line_map: on the wall's face (y = 0).

    Blender -b --factory-startup --python tools/eclipse/station_shell.py
"""

import math
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import common  # noqa: E402
import underground_shapes  # noqa: E402
import underground_walls  # noqa: E402
from underground_shapes import box, pipe, smooth_object  # noqa: E402

NAME = "station_shell"
ATLAS = 4096
SLOTS = ["tile_wall", "tile_dark", "tile_line", "tile_odd", "mortar", "plaster_wall", "plaster_vault", "cement", "cement_cast", "stone",
         "stone_old", "paint_yellow", "steel", "iron", "brass", "sign", "glass"]

rng = random.Random(1969)

PANEL = underground_walls.PANEL
FACE = underground_walls.FACE
MORTAR = underground_walls.MORTAR
# The tiled panels' height (to just over their cap: the plaster above them is plaster_sheet's, the atlas kept for the
# tiles).
HEIGHTS = {"low": underground_walls.CAP[1]}
# The terrazzo floor's slabs, its stone copings (reaching in from the edge; the yellow line's place in it), the pit's
# depth under a platform.
MODULE = 1.2
SLAB = 0.05
COPING = 0.6
LINE = (0.45, 0.55)
PIT = 1.2
# The columns: the hall's (square, tiled), the track's (bed to ceiling).
COLUMN_HALL = (0.6, 5.0)
COLUMN_TRACK = (0.5, 6.7)
# The ceiling: the hall's coffers (square, deep), the strip fittings' housing.
COFFER = 2.4
COFFER_DEPTH = 0.32
BEAM = 0.25
FITTING = (0.18, 0.1)          # its housing's width and depth
TUBE = 0.019
# The flights: their width, a tread's depth and rise; a handrail's run.
FLIGHT = 2.4
TREAD = 0.4
RISE = 0.17
RAIL = 1.0
# The openings' linings: [width, height, depth] (maps/metro_station.gd picks one per gap); its lining's thickness and
# its architrave's width and how proud.
REVEALS = [(3.0, 3.0, 0.6), (3.0, 3.0, 0.31), (4.0, 3.0, 0.31), (2.0, 6.7, 0.3)]
LINING = 0.05
ARCH = (0.16, 0.04)
# The portals: the track's mouths and the centre's tunnels (width, height); their frame's width and depth.
MOUTH = (3.0, 4.6)
TUNNEL = (3.0, 3.0)
FRAME = (0.4, 0.45)
# The hanging signs (board width, height, thickness; rods' drop), the line map (width, height).
BOARD = (1.6, 0.4, 0.05)
DROP = 0.6
MAP = (2.4, 1.2)


def reveal_name(w, h, d):
    return "reveal_%dx%dx%d" % (round(w * 100), round(h * 100), round(d * 100))


# --- the walls -----------------------------------------------------------------------------------

def _panel(height, build):
    """underground_walls' panel `build`, standing `height`."""
    def made(m):
        saved = underground_walls.PANEL, underground_walls.HEIGHT
        underground_walls.PANEL, underground_walls.HEIGHT = PANEL, height
        try:
            build(m)
        finally:
            underground_walls.PANEL, underground_walls.HEIGHT = saved

    return made


def _courses():
    """underground_walls' courses in running bond, but where a course's tile is cut by the panel's edge its half ends
    flush with it, so the next panel's half makes it whole: no joint runs straight up the wall at every panel's edge."""
    places = []
    joint = underground_walls.JOINT
    for k, (z0, z1, width, slot) in enumerate(underground_walls.COURSES):
        edges = [0.0]
        x = width / 2 if k % 2 else width
        while x < PANEL - 1e-6:
            edges.append(x)
            x += width
        edges.append(PANEL)
        for i, (a, b) in enumerate(zip(edges, edges[1:])):
            cut = k % 2 == 1
            a0 = a if cut and i == 0 else a + joint / 2
            b0 = b if cut and i == len(edges) - 2 else b - joint / 2
            places.append((a0, b0, z0 + joint / 2, z1 - joint / 2, slot, k))
    return places


def _tiled(worn):
    """A tiled panel to just over its cap, its tiles in the flush bond; worn, where the years show (tiles fallen to the
    mortar, others replaced with whatever was to hand, one cracked across)."""
    def made(m):
        box(m, (0.0, -MORTAR, 0.0), (PANEL, 0.0, underground_walls.CAP[1]), "mortar", r=0.0)
        places = _courses()
        fallen, odd, cracked = set(), set(), -1
        if worn:
            field = [i for i, p in enumerate(places) if p[4] == "tile_wall" and p[5] < len(underground_walls.COURSES) - 1]
            rng.shuffle(field)
            fallen, odd, cracked = set(field[:7]), set(field[7:12]), field[12]
        for i, (x0, x1, z0, z1, slot, _) in enumerate(places):
            if i in fallen:
                continue
            if i == cracked:
                cut = x0 + (x1 - x0) * 0.4
                underground_walls._tile(m, x0, cut - 0.002, z0, z1, slot)
                underground_walls._tile(m, cut + 0.002, x1, z0, z1, slot)
                continue
            underground_walls._tile(m, x0, x1, z0, z1, "tile_odd" if i in odd else slot)

    return made


def plaster_sheet(m):
    box(m, (0.0, -MORTAR, 0.0), (PANEL, 0.0, 1.0), "plaster_wall", r=0.0)


def lining(m):
    """A cast cement board lining a wall's bare end or an opening's head: 1 m along x, 1 m up z, its face toward -y."""
    box(m, (0.0, -0.04, 0.0), (1.0, 0.0, 1.0), "cement_cast", r=0.0)


def sill(m):
    """A door's stone threshold: 1 m wide along x, reaching 1 m back along +y from its front edge, its top at z = 0."""
    box(m, (0.0, 0.0, -0.06), (1.0, 1.0, 0.0), "stone_old", r=0.008)


def bed_slab(m):
    """The track's concrete bed: a MODULE square centred on the origin, its top at z = 0."""
    h = MODULE / 2 - 0.004
    box(m, (-h, -h, -SLAB), (h, h, 0.0), "cement", r=0.004)


def rail_post(m):
    """A handrail's end post: its iron upright and the rail's brass end over it."""
    pipe(m, [(0.0, 0.0, 0.0), (0.0, 0.0, 0.875)], 0.02, 6, "iron")
    pipe(m, [(-0.02, 0.0, 0.9), (0.03, 0.0, 0.9)], 0.03, 8, "brass")


def pit_face(m):
    """The pit's face under a platform's edge: rough concrete."""
    box(m, (0.0, -0.04, 0.0), (PANEL, 0.0, PIT), "cement_cast", r=0.0)


# --- the floor -------------------------------------------------------------------------------------

def _slab(worn):
    """A terrazzo slab, its edges eased; worn, a corner patched in cement."""
    def made(m):
        h = MODULE / 2 - 0.004
        if not worn:
            box(m, (-h, -h, -SLAB), (h, h, 0.0), "stone", r=0.006)
            return
        # (The slab short of its broken corner, and the cement patch sunk a little into the corner, a joint round it.)
        x, y, joint = h - 0.35, h - 0.3, 0.004
        box(m, (-h, -h, -SLAB), (x - joint, h, 0.0), "stone", r=0.006)
        box(m, (x, -h, -SLAB), (h, y - joint, 0.0), "stone", r=0.006)
        box(m, (x, y, -SLAB), (h, h, -0.003), "cement", r=0.0)

    return made


def coping(m):
    """The platform's edge: a stone coping, its nose rounded over the pit, the yellow line let into it."""
    joint = 0.004
    box(m, (0.002, 0.0, -0.12), (PANEL - 0.002, LINE[0] - joint, 0.0), "stone_old", r=0.02)
    box(m, (0.002, LINE[0], -0.12), (PANEL - 0.002, LINE[1], -0.001), "paint_yellow", r=0.0)
    box(m, (0.002, LINE[1] + joint, -0.12), (PANEL - 0.002, COPING, 0.0), "stone_old", r=0.0)


# --- columns ---------------------------------------------------------------------------------------

def column_hall(m):
    """A hall column: tiled square to the cap as the walls are, the line's band round it, plaster above, a cap."""
    w, h = COLUMN_HALL
    s = w / 2
    box(m, (-s, -s, 0.0), (s, s, 0.3), "tile_dark", r=0.0)
    box(m, (-s, -s, 0.3), (s, s, 1.3), "tile_wall", r=0.0)
    box(m, (-s, -s, 1.3), (s, s, 1.5), "tile_line", r=0.0)
    box(m, (-s, -s, 1.5), (s, s, 2.42), "tile_wall", r=0.0)
    box(m, (-s - 0.02, -s - 0.02, 2.42), (s + 0.02, s + 0.02, 2.5), "tile_dark", r=0.0)
    box(m, (-s + 0.01, -s + 0.01, 2.5), (s - 0.01, s - 0.01, h - 0.15), "plaster_wall", r=0.0)
    box(m, (-s - 0.06, -s - 0.06, h - 0.15), (s + 0.06, s + 0.06, h), "plaster_wall", r=0.02)


def column_track(m):
    """A column between the tracks: plain concrete, chamfered, a plinth the ballast water has stained."""
    w, h = COLUMN_TRACK
    s = w / 2
    box(m, (-s - 0.05, -s - 0.05, 0.0), (s + 0.05, s + 0.05, 0.3), "cement_cast", r=0.02)
    box(m, (-s, -s, 0.3), (s, s, h), "cement_cast", r=0.03)


# --- the ceilings ----------------------------------------------------------------------------------

def coffer(m):
    """A coffer of the hall's ceiling: its beams round a recess, a fluorescent fitting across it."""
    c = COFFER / 2
    b = BEAM
    _beams(m, c, b, COFFER_DEPTH, 0.02)
    box(m, (-c + b, -c + b, -0.04), (c - b, c - b, 0.0), "plaster_vault", r=0.0)
    _fitting(m, -c + b + 0.1, c - b - 0.1, -0.04)


def _beams(m, c, b, d, r):
    """A coffer's ring of beams, half of each beam its neighbour's: one profile swept round the square, its outside
    square (two coffers' soffits meet flat, no groove between them to catch the light) and its edge on the recess
    rounded `r` in two segments."""
    k = math.sqrt(0.5)
    profile = [(c, 0.0), (c, -d), (c - b + r, -d), (c - b + r * (1.0 - k), -d + r * (1.0 - k)), (c - b, -d + r),
               (c - b, 0.0)]
    m.shell()
    for (s0, z0), (s1, z1) in zip(profile, profile[1:] + profile[:1]):
        for (ax, ay), (bx, by) in zip(CORNERS, CORNERS[1:] + CORNERS[:1]):
            m.face([(ax * s0, ay * s0, z0), (bx * s0, by * s0, z0), (bx * s1, by * s1, z1), (ax * s1, ay * s1, z1)],
                   "plaster_vault")


# A square's corners, counter-clockwise from above.
CORNERS = [(1.0, 1.0), (-1.0, 1.0), (-1.0, -1.0), (1.0, -1.0)]


def ceiling_panel(m):
    """A MODULE square of the plastered ceiling centred on the origin, its top at z = 0: met by the next, seamless."""
    h = MODULE / 2
    box(m, (-h, -h, -0.04), (h, h, 0.0), "plaster_vault", r=0.0)


def _fitting(m, x0, x1, top):
    """A fluorescent fitting along x: its steel housing, two tubes under it."""
    w, d = FITTING
    box(m, (x0, -w / 2, top - d), (x1, w / 2, top), "steel", r=0.01)
    for y in (-w / 4, w / 4):
        pipe(m, [(x0 + 0.04, y, top - d - TUBE - 0.004), (x1 - 0.04, y, top - d - TUBE - 0.004)], TUBE, 8, "glass")


def strip_fitting(m):
    _fitting(m, 0.0, PANEL, 0.0)


# --- the flights -----------------------------------------------------------------------------------

def tread(m):
    """A flight's tread: stone, a steel nosing at its front edge."""
    h = FLIGHT / 2
    box(m, (-h, 0.05, -RISE), (h, TREAD, 0.0), "stone", r=0.01)
    box(m, (-h, 0.0, -RISE), (h, 0.05, 0.0), "steel", r=0.0)


def handrail(m):
    """A run of handrail: a brass tube 0.9 m up, a post at its start."""
    pipe(m, [(0.0, 0.0, 0.9), (RAIL, 0.0, 0.9)], 0.025, 8, "brass")
    pipe(m, [(0.0, 0.0, 0.0), (0.0, 0.0, 0.875)], 0.02, 6, "iron")


# --- openings --------------------------------------------------------------------------------------

def _reveal(w, h, d):
    """An opening's cast cement lining: its jambs and head through the wall's depth, an architrave round it either face."""
    def made(m):
        a, proud = ARCH
        x0, x1 = -w / 2, w / 2
        for x, inward in ((x0, 1), (x1, -1)):
            lo, hi = sorted((x, x + inward * LINING))
            box(m, (lo, 0.0, 0.0), (hi, d, h), "cement_cast", r=0.0)
        box(m, (x0 + LINING, 0.0, h - LINING), (x1 - LINING, d, h), "cement_cast", r=0.0)
        for y0, y1 in ((-proud, 0.0), (d, d + proud)):
            for x, away in ((x0, -1), (x1, 1)):
                lo, hi = sorted((x, x + away * a))
                box(m, (lo, y0, 0.0), (hi, y1, h), "cement_cast", r=0.0)
            box(m, (x0 - a, y0, h), (x1 + a, y1, h + a), "cement_cast", r=0.0)

    return made


def _portal(size):
    """A cement frame round an opening on its face: jambs and a deep lintel, a keyed course over it."""
    def made(m):
        w, h = size
        f, d = FRAME
        for x, away in ((-w / 2, -1), (w / 2, 1)):
            lo, hi = sorted((x, x + away * f))
            box(m, (lo, -d, 0.0), (hi, 0.0, h), "cement_cast", r=0.02)
        box(m, (-w / 2 - f, -d, h), (w / 2 + f, 0.0, h + f), "cement_cast", r=0.02)
        box(m, (-w / 2 - f - 0.05, -d - 0.04, h + f), (w / 2 + f + 0.05, 0.0, h + f + 0.12), "stone_old", r=0.02)

    return made


# --- signs -----------------------------------------------------------------------------------------

def sign_board(m):
    """A hanging direction sign: two rods from the ceiling, a framed board, both faces blank (the user's words)."""
    w, h, t = BOARD
    # (Its frame over 3 cm deep: the gate's least between the panel's edge and the frame's face over it.)
    f = 0.035
    for x in (-w / 2 + 0.15, w / 2 - 0.15):
        pipe(m, [(x, 0.0, 0.0), (x, 0.0, -DROP)], 0.012, 6, "steel")
    _framed(m, -w / 2, w / 2, -t / 2, t / 2, -DROP - h, -DROP, f)


def _framed(m, x0, x1, y0, y1, z0, z1, f):
    """A blank face (the `sign` slot) its whole thickness, in a steel frame standing proud of it either side."""
    # (Over 3 cm through: the gate's least between a face and its back.)
    box(m, (x0 + f, y0 + 0.008, z0 + f), (x1 - f, y1 - 0.008, z1 - f), "sign", r=0.0)
    box(m, (x0, y0, z0), (x1, y1, z0 + f), "steel", r=0.0)
    box(m, (x0, y0, z1 - f), (x1, y1, z1), "steel", r=0.0)
    box(m, (x0, y0, z0 + f), (x0 + f, y1, z1 - f), "steel", r=0.0)
    box(m, (x1 - f, y0, z0 + f), (x1, y1, z1 - f), "steel", r=0.0)


def line_map(m):
    """The line's map on the wall: a steel frame, its face blank (the user's)."""
    w, h = MAP
    _framed(m, 0.0, w, -0.05, 0.0, 0.0, h, 0.04)


PIECES = []
for _h, _height in HEIGHTS.items():
    PIECES += [("wall_" + _h, _tiled(False)), ("wall_%s_worn" % _h, _tiled(True))]
PIECES += [("plaster_sheet", plaster_sheet), ("lining", lining), ("sill", sill), ("bed_slab", bed_slab),
           ("rail_post", rail_post), ("pit_face", pit_face), ("floor_slab_a", _slab(False)),
           ("floor_slab_b", _slab(False)), ("floor_slab_c", _slab(True)), ("coping", coping),
           ("column_hall", column_hall), ("column_track", column_track), ("coffer", coffer),
           ("ceiling_panel", ceiling_panel), ("strip_fitting", strip_fitting), ("tread", tread), ("handrail", handrail),
           ("portal_mouth", _portal(MOUTH)), ("portal_tunnel", _portal(TUNNEL)), ("sign_board", sign_board),
           ("line_map", line_map)]
PIECES += [(reveal_name(*r), _reveal(*r)) for r in REVEALS]

BUDGET = {n: 3000 for n, _ in PIECES}
SLIVER = {n: 0.004 for n, _ in PIECES}


def build():
    common.reset()
    underground_shapes.rng = rng
    rng.seed(1969)
    underground_walls.rng.seed(1969)

    for name, f in PIECES:
        smooth_object(name, f)


def main():
    build()
    common.export_piece(NAME, ATLAS, SLOTS, out=common.ROOT / "assets" / "eclipse" / "kit", sets_each=True,
                        budget=max(BUDGET.values()), sliver=min(SLIVER.values()))


if __name__ == "__main__":
    main()
