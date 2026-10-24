"""The candle lane's own pieces (docs/superpowers/specs/2026-10-23-candle-lane-design.md; plan Task 5): what the bay
does not already have at the lane's two ends.

- chapel_door: the chapel's doorway in the lane's east end, a cantera frame round its 3.0 x 2.8 m opening (two
  pilasters on plinths under their imposts, the lintel and its cornice, a keystone), its sill worn hollow by feet;
- votive_ledges: a stone ledge on each wall before the doorway (plan x 22-28) on its corbels, thick with candles burnt
  to every height, their wax hung in drips off the ledges' edges (each candle's wick a wick: its flame stands there);
- milagros_board: a framed velvet board on the end wall beside the doorway, tin milagros pinned over it in rows (as on
  the librarian's cage: a heart, an eye, a leg, a hand);
- puesto: a Pasaje market stall, its pipe frame, canvas awning, counter, sacks and back shelf, its sign board's face
  blank;
- enamel_sign: the station's sign hung from the vault at the lane's mouth, both faces blank in their blue border;
- arrow_east, arrow_west: wall plates pointing along the lane, their faces blank for the words, the point the line's
  blue;
- mouth_portal: the cement bulkhead framing the lane's mouth on the Pasaje, down both walls and across under the vault,
  where the lane's pipes and cables run into the wall.

Faces left for the user's words and glyphs are the `sign` slot. The frames: chapel_door, votive_ledges,
milagros_board and mouth_portal are built where they stand in the lane (x along it, y the lane's -z, z up: Godot's x,
-z, y), and set
at the lane's origin; the puesto stands on its own floor with its front toward -y (Godot's +z); the sign hangs from
its rods' tops at the origin (the vault's underside); an arrow plate's back is at the origin on the wall, its face
toward -y.

    Blender -b --factory-startup --python tools/eclipse/candle_lane.py
"""

import math
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import common  # noqa: E402
import underground_shapes  # noqa: E402
from library_hangings import _charm  # noqa: E402
from mathutils import Vector  # noqa: E402
from underground_shapes import box, pipe, smooth_object, turned  # noqa: E402

NAME = "candle_lane"
ATLAS = 2048
SLOTS = ["stone_old", "stone", "wax_white", "wax", "wax_red", "wood", "cloth", "tin", "brass", "steel", "burlap",
         "enamel", "tile_line", "sign", "cement"]
# Two ledges crowded with dozens of candles are most of the lane's triangles.
BUDGET = {"chapel_door": 3000, "votive_ledges": 5000, "milagros_board": 3000, "puesto": 3000, "enamel_sign": 3000,
          "arrow_east": 3000, "arrow_west": 3000, "mouth_portal": 3000}
# Candles' lips and drips and the tin are millimetres across by nature: a face there is a sliver under 4 mm (the
# gate's 1 cm elsewhere).
SLIVER = {"chapel_door": 0.01, "votive_ledges": 0.004, "milagros_board": 0.004, "puesto": 0.01, "enamel_sign": 0.01,
          "arrow_east": 0.01, "arrow_west": 0.01, "mouth_portal": 0.01}

rng = random.Random(1531)

# The lane (maps/underground_lab.gd, maps/candle_lane.gd): its half length, its walls' tile faces (lane z), the end
# wall's tiles' depth and its thickness.
HALF = 16.8
BACK_WALL = -2.35
FAR_WALL = 4.55
WALL_FACE = 0.067
WALL = 0.3
# The doorway: its width and height, its middle across the lane (lane z); where its frame's reveal begins (the end
# wall's face behind its tiles, lane x).
DOOR = (3.0, 2.8)
DOOR_Z = 0.2
DOOR_X = HALF + WALL_FACE
# The frame: the pilasters' width, how far the stone stands out of the tiles toward the lane (the shaft's face) and
# past the wall's back into the chapel.
PILASTER = 0.6
SHAFT_X = HALF - 0.06
BACK_X = DOOR_X + WALL + 0.033
# The ledges: their top, depth from the tiles, thickness; where each runs along the lane (lane x; the far wall's
# clear of the shopfront, which ends at 10.2).
LEDGE_TOP = 1.0
LEDGE_DEPTH = 0.29
LEDGE_THICK = 0.08
LEDGES = [(BACK_WALL, (9.2, 15.2)), (FAR_WALL, (10.6, 15.2))]
# The milagros board on the end wall south of the doorway: its middle across (lane z) and up, its size, depth and the
# velvet's recess; the rows of charms.
BOARD = (2.85, 1.5)
BOARD_SIZE = (0.7, 0.95)
BOARD_DEPTH = 0.05
BOARD_RECESS = 0.022
CHARM_ROWS = 5
CHARM_COLUMNS = 5
# The puesto: width, depth, its awning's height at its front edge and at its back, how far it reaches past the
# front, the counter's height.
STALL = (2.2, 1.3)
AWNING = (2.08, 2.48)
REACH = 0.45
COUNTER = 0.9
# The enamel sign: its size, thickness, border, how far its rods hang it below the vault.
SIGN_SIZE = (2.4, 0.55)
SIGN_THICK = 0.035
SIGN_BORDER = 0.045
ROD = 0.8
# The mouth's portal: the lane's height, how far it reaches in from the mouth (and stands out past it into the
# Pasaje), how far its jambs stand out of the walls (past the pipes and the tray), its beam's depth under the vault,
# the haunch where they meet.
HEIGHT = 4.0
PORTAL_IN = 0.6
PORTAL_OUT = 0.05
PORTAL_JAMB = 0.45
PORTAL_BEAM = 0.6
PORTAL_HAUNCH = 0.15
# An arrow plate: its length, height, thickness, the point's length, how far it stands off the wall.
ARROW = (1.0, 0.28)
ARROW_THICK = 0.025
ARROW_POINT = 0.16
STANDOFF = 0.04


def _lane(x, z, y):
    """A point given in the lane's (x along, z across, y up), in Blender's axes."""
    return (x, -z, y)


def _extrude_y(m, outline, y0, y1, slot):
    """An outline [(x, z)] drawn across y from y0 to y1 (Blender): one solid, its two ends one face each."""
    m.shell()
    front = [(x, y0, z) for x, z in outline]
    back = [(x, y1, z) for x, z in outline]
    m.face(front, slot)
    m.face(back[::-1], slot)
    n = len(outline)
    for k in range(n):
        m.face([front[k], front[(k + 1) % n], back[(k + 1) % n], back[k]], slot)


def _extrude_x(m, outline, x0, x1, slot):
    """An outline [(y, z)] drawn along x from x0 to x1 (Blender)."""
    m.shell()
    front = [(x0, y, z) for y, z in outline]
    back = [(x1, y, z) for y, z in outline]
    m.face(front, slot)
    m.face(back[::-1], slot)
    n = len(outline)
    for k in range(n):
        m.face([front[k], front[(k + 1) % n], back[(k + 1) % n], back[k]], slot)


def _plate(m, outline, point_at, thick, slot, faces=None, back_slot=None, facing=(0.0, -1.0, 0.0), up=(0.0, 0.0, 1.0)):
    """A flat plate: `outline` [(across, up)] about `point_at` on its face, `thick` deep behind it, its face toward
    `facing`; its face one polygon of `slot`, or `faces` [(polygon, slot)] tiling the outline (a blank for words, a
    border round it). Its back and edges are `slot` (its back `back_slot` if given)."""
    facing, up = Vector(facing).normalized(), Vector(up).normalized()
    across = up.cross(facing).normalized()
    origin = Vector(point_at)

    def at(u, v, d):
        return tuple(origin + across * u + up * v - facing * d)

    m.shell()
    for poly, part in faces or [(outline, slot)]:
        m.face([at(u, v, 0.0) for u, v in poly], part)
    m.face([at(u, v, thick) for u, v in outline[::-1]], back_slot or slot)
    n = len(outline)
    for k in range(n):
        (a, b) = outline[k], outline[(k + 1) % n]
        m.face([at(*b, 0.0), at(*a, 0.0), at(*a, thick), at(*b, thick)], slot)


# The chapel's doorway


def chapel_door(m):
    """Two pilasters, the lintel with its cornice and keystone, the attic over it up to the vault, the worn sill: one
    stone frame, its opening 3.0 wide and 2.8 high, through the end wall."""
    w, h = DOOR
    # (A pilaster in profile, lane x by height: its plinth, its shaft, its impost flaring under the lintel.)
    pilaster = [(BACK_X, -0.02), (SHAFT_X - 0.06, -0.02), (SHAFT_X - 0.06, 0.34), (SHAFT_X, 0.42), (SHAFT_X, h - 0.24),
                (SHAFT_X - 0.08, h - 0.16), (SHAFT_X - 0.08, h), (BACK_X, h)]
    for side in (-1, 1):
        inner = DOOR_Z + side * w / 2
        outer = DOOR_Z + side * (w / 2 + PILASTER)
        _extrude_y(m, pilaster, -inner, -outer, "stone_old")
    # (Its cornice, then the attic set back over it to the vault: the end wall's tiles come out over the doorway.)
    lintel = [(BACK_X, h), (SHAFT_X - 0.04, h), (SHAFT_X - 0.04, h + 0.5), (SHAFT_X - 0.12, h + 0.58),
              (SHAFT_X - 0.12, h + 0.68), (SHAFT_X, h + 0.68), (SHAFT_X, HEIGHT), (BACK_X, HEIGHT)]
    span = w / 2 + PILASTER + 0.08
    _extrude_y(m, lintel, -(DOOR_Z - span), -(DOOR_Z + span), "stone_old")
    # The keystone, a wedge standing proud of the lintel's face and over its cornice.
    key = [(-0.11, h + 0.1), (0.11, h + 0.1), (0.15, h + 0.75), (-0.15, h + 0.75)]
    _extrude_x(m, [(-DOOR_Z + y, z) for y, z in key], SHAFT_X - 0.16, SHAFT_X + 0.02, "stone_old")
    # The sill across the opening, its top hollowed by a century of feet.
    sill = [(-w / 2 - 0.02, -0.06), (w / 2 + 0.02, -0.06), (w / 2 + 0.02, 0.02), (1.1, 0.018), (0.5, 0.007),
            (-0.5, 0.007), (-1.1, 0.018), (-w / 2 - 0.02, 0.02)]
    _extrude_x(m, [(-DOOR_Z - y, z) for y, z in sill], SHAFT_X - 0.1, BACK_X + 0.01, "stone")


# The votive ledges


def _candle(m, x, y, r, h, slot, z0):
    """One candle on a ledge: its foot flared and sunk into the stone, its side a little uneven, its top melted into
    a cup under a lip, a run or two of wax down its side; its wick over the cup."""
    turned(m, [(r * 1.3, z0 - 0.012), (r * 1.22, z0 + 0.004), (r * 1.04, z0 + 0.014), (r * 1.02, z0 + 0.014 + (h - 0.026) * 0.4),
               (r, z0 + h - 0.012), (r * 1.07, z0 + h - 0.002), (r * 0.6, z0 + h - 0.009)], 5, slot, at=(x, y, 0.0),
           jitter=0.06, twist=rng.uniform(0, 1))
    if h > 0.06 and rng.random() < 0.6:
        a = rng.uniform(0, 2 * math.pi)
        out = r * 1.03
        run = rng.uniform(h * 0.3, h * 0.6)

        def at(d, z):
            return (x + (out + d) * math.cos(a), y + (out + d) * math.sin(a), z)

        pipe(m, [at(0.0015, z0 + h - 0.004), at(0.002, z0 + h - 0.004 - run)], 0.0045, 4, slot)
    m.wick((x, y, z0 + h - 0.009 + 0.01))


def votive_ledges(m):
    """A ledge on each wall on its corbels, its candles crowded along it, the wax hung off its edge."""
    for wall, (x0, x1) in LEDGES:
        out = 1 if wall < 0 else -1
        z_in, z_out = wall - out * 0.01, wall + out * LEDGE_DEPTH
        lo, hi = _lane(x0, min(z_in, z_out), LEDGE_TOP - LEDGE_THICK), _lane(x1, max(z_in, z_out), LEDGE_TOP)
        box(m, (lo[0], min(lo[1], hi[1]), lo[2]), (hi[0], max(lo[1], hi[1]), hi[2]), "stone", r=0.02)
        # Its corbels: tapered blocks under it, into the wall.
        for k in range(3):
            cx = x0 + 0.35 + k * (x1 - x0 - 0.7) / 2
            corbel = [(wall - out * 0.02, LEDGE_TOP - LEDGE_THICK + 0.01), (wall + out * (LEDGE_DEPTH - 0.06),
                      LEDGE_TOP - LEDGE_THICK + 0.01), (wall + out * 0.05, LEDGE_TOP - LEDGE_THICK - 0.3),
                      (wall - out * 0.02, LEDGE_TOP - LEDGE_THICK - 0.34)]
            _extrude_x(m, [(-z, y) for z, y in corbel], cx - 0.08, cx + 0.08, "stone")
        # The candles: tall ones toward the wall, stubs toward the edge, packed thick in clusters.
        x = x0 + 0.12
        while x < x1 - 0.12:
            depth = rng.uniform(0.05, LEDGE_DEPTH - 0.06)
            tall = depth < 0.13 and rng.random() < 0.45
            r = rng.uniform(0.028, 0.04) if tall else rng.uniform(0.022, 0.032)
            h = rng.uniform(0.16, 0.28) if tall else rng.uniform(0.045, 0.11)
            slot = "wax_red" if tall and rng.random() < 0.6 else rng.choice(["wax_white", "wax_white", "wax"])
            p = _lane(x, wall + out * depth, 0.0)
            _candle(m, p[0], p[1], r, h, slot, LEDGE_TOP)
            x += rng.uniform(0.08, 0.24)
        # The wax that ran off its edge, hung under it in drips.
        for _ in range(int((x1 - x0) * 2.2)):
            dx = rng.uniform(x0 + 0.05, x1 - 0.05)
            edge = wall + out * (LEDGE_DEPTH + 0.002)
            drop = rng.uniform(0.03, 0.14)
            top = _lane(dx, edge, LEDGE_TOP - 0.03)
            bottom = _lane(dx, edge, LEDGE_TOP - LEDGE_THICK - drop)
            pipe(m, [top, bottom], rng.uniform(0.004, 0.007), 4, rng.choice(["wax_white", "wax", "wax_red"]))


# The milagros board


def milagros_board(m):
    """A wooden frame on the end wall, the velvet in it, rows of tin milagros pinned to the velvet."""
    zc, yc = BOARD
    wz, hy = BOARD_SIZE
    back_x = HALF - 0.01
    front_x = back_x - BOARD_DEPTH
    rail = 0.06
    # (One solid: the frame's face round the velvet recessed in it.)
    outer = [(-wz / 2, -hy / 2), (wz / 2, -hy / 2), (wz / 2, hy / 2), (-wz / 2, hy / 2)]
    inner = [(u * (wz / 2 - rail) / (wz / 2), v * (hy / 2 - rail) / (hy / 2)) for u, v in outer]

    def p(x, uv):
        u, v = uv
        return (x, -(zc + u), yc + v)

    m.shell()
    m.face([p(back_x, c) for c in outer], "wood")
    for k in range(4):
        a, b = k, (k + 1) % 4
        m.face([p(front_x, outer[b]), p(front_x, outer[a]), p(back_x, outer[a]), p(back_x, outer[b])], "wood")
        m.face([p(front_x, outer[a]), p(front_x, outer[b]), p(front_x, inner[b]), p(front_x, inner[a])], "wood")
        m.face([p(front_x, inner[a]), p(front_x, inner[b]), p(front_x + BOARD_RECESS, inner[b]),
                p(front_x + BOARD_RECESS, inner[a])], "wood")
    m.face([p(front_x + BOARD_RECESS, c) for c in inner], "cloth")
    # The milagros, each on its pin, a little askew.
    kinds = ["heart", "eye", "leg", "hand"]
    velvet = front_x + BOARD_RECESS
    for row in range(CHARM_ROWS):
        for col in range(CHARM_COLUMNS):
            u = -wz / 2 + rail + 0.06 + col * (wz - 2 * rail - 0.12) / (CHARM_COLUMNS - 1) + rng.uniform(-0.012, 0.012)
            v = hy / 2 - rail - 0.06 - row * (hy - 2 * rail - 0.14) / (CHARM_ROWS - 1) + rng.uniform(-0.01, 0.01)
            tilt = rng.uniform(-0.25, 0.25)
            up = (0.0, -math.sin(tilt), math.cos(tilt))
            outline = _charm(rng.choice(kinds))
            top = Vector(p(velvet - 0.008, (u, v + 0.02)))
            _plate(m, outline, tuple(top), 0.005, "tin", facing=(-1.0, 0.0, 0.0), up=up)
            # Its pin through the tin's top into the velvet.
            pin = Vector(p(velvet, (u, v + 0.012)))
            pipe(m, [tuple(pin + Vector((0.002, 0, 0))), tuple(pin - Vector((0.016, 0, 0)))], 0.003, 4, "brass")


# The Pasaje's puesto


def puesto(m):
    """A market stall: four pipe poles, its canvas awning sloping out over the front, the sign board hung from the
    awning's edge (its face blank), the counter, sacks on it, a shelf behind."""
    w, d = STALL
    back = Vector((0.0, d + 0.02, AWNING[1]))
    front = Vector((0.0, -REACH, AWNING[0]))
    slope = math.atan2(back.z - front.z, back.y - front.y)

    def under(y):
        """The awning's middle over `y`: the poles end in it."""
        return front.z + (y - front.y) * math.tan(slope)

    for x in (-w / 2 + 0.05, w / 2 - 0.05):
        for y in (0.05, d - 0.05):
            pipe(m, [(x, y, 0.0), (x, y, under(y))], 0.022, 6, "steel")
    mid = (back + front) / 2
    length = (back - front).length
    box(m, (-w / 2 - 0.08, mid.y - length / 2, mid.z - 0.01), (w / 2 + 0.08, mid.y + length / 2, mid.z + 0.01), "cloth",
        r=0.0, turn=(slope, 0.0, 0.0))
    # (Its frame's crossbars under the canvas, front and back.)
    for y in (0.05, d - 0.05):
        pipe(m, [(-w / 2 + 0.05, y, under(y) - 0.04), (w / 2 - 0.05, y, under(y) - 0.04)], 0.018, 6, "steel")
    # The sign board under the awning's edge.
    edge = front + Vector((0.0, 0.03, -0.03))
    board = [(-w / 2 - 0.05, -0.3), (w / 2 + 0.05, -0.3), (w / 2 + 0.05, 0.0), (-w / 2 - 0.05, 0.0)]
    _plate(m, board, tuple(edge), 0.03, "wood", faces=[(board, "sign")])
    # Hangers from the awning's edge down to it.
    for x in (-w / 2 + 0.2, w / 2 - 0.2):
        pipe(m, [(x, edge.y + 0.015, edge.z + 0.08), (x, edge.y + 0.015, edge.z - 0.02)], 0.008, 4, "steel")
    # The counter, its top board overhanging.
    box(m, (-w / 2 + 0.08, 0.08, 0.0), (w / 2 - 0.08, 0.6, COUNTER - 0.04), "wood", r=0.02)
    box(m, (-w / 2 + 0.03, 0.03, COUNTER - 0.04), (w / 2 - 0.03, 0.66, COUNTER), "wood", r=0.012)
    for k in range(3):
        x = -0.6 + k * 0.55 + rng.uniform(-0.05, 0.05)
        r = rng.uniform(0.12, 0.16)
        turned(m, [(r * 0.8, COUNTER), (r, COUNTER + 0.06), (r * 0.95, COUNTER + 0.24), (r * 0.6, COUNTER + 0.3),
                   (r * 0.7, COUNTER + 0.34)], 8, "burlap", at=(x, 0.35, 0.0), jitter=0.12, twist=rng.uniform(0, 1))
    # The shelf behind, across the back poles, its jars.
    box(m, (-w / 2 + 0.03, d - 0.32, 1.38), (w / 2 - 0.03, d - 0.02, 1.42), "wood", r=0.0)
    for k in range(5):
        x = -0.85 + k * 0.42 + rng.uniform(-0.04, 0.04)
        r = rng.uniform(0.05, 0.07)
        turned(m, [(r * 0.9, 1.42), (r, 1.44), (r, 1.42 + 0.16), (r * 0.6, 1.42 + 0.19), (r * 0.62, 1.42 + 0.22)], 8,
               rng.choice(["tin", "brass", "wax"]), at=(x, d - 0.17, 0.0), twist=rng.uniform(0, 1))


# The way's signs


def _bordered(width, height, border):
    """A rectangle's outline (about its middle) and its face cut into a border round a middle: [(outline, slot)]."""
    o = [(-width / 2, -height / 2), (width / 2, -height / 2), (width / 2, height / 2), (-width / 2, height / 2)]
    i = [(u - math.copysign(border, u), v - math.copysign(border, v)) for u, v in o]
    parts = [(i, "sign")]
    for k in range(4):
        a, b = k, (k + 1) % 4
        parts.append(([o[a], o[b], i[b], i[a]], "tile_line"))
    return o, parts


def enamel_sign(m):
    """The station's sign, hung across the lane's mouth on two rods from the vault: both faces blank in their blue
    border."""
    width, height = SIGN_SIZE
    outline, parts = _bordered(width, height, SIGN_BORDER)
    middle = Vector((0.0, 0.0, -ROD - height / 2))
    # (One solid: the face toward -y and its back toward +y, each cut the same way.)
    m.shell()
    front = middle - Vector((0.0, SIGN_THICK / 2, 0.0))
    back = middle + Vector((0.0, SIGN_THICK / 2, 0.0))
    for poly, slot in parts:
        m.face([tuple(front + Vector((u, 0.0, v))) for u, v in poly], slot)
        m.face([tuple(back + Vector((u, 0.0, v))) for u, v in poly[::-1]], slot)
    for k in range(4):
        (a, b) = outline[k], outline[(k + 1) % 4]
        m.face([tuple(front + Vector((b[0], 0, b[1]))), tuple(front + Vector((a[0], 0, a[1]))),
                tuple(back + Vector((a[0], 0, a[1]))), tuple(back + Vector((b[0], 0, b[1])))], "tile_line")
    for x in (-width / 2 + 0.25, width / 2 - 0.25):
        pipe(m, [(x, 0.0, 0.02), (x, 0.0, -ROD - 0.03)], 0.012, 6, "steel")
        box(m, (x - 0.04, -0.03, -0.012), (x + 0.04, 0.03, 0.0), "steel", r=0.0)


def _arrow(m, pointing):
    """A plate along the wall, its face blank for the words, its point (the line's blue) toward `pointing` (+1 or -1
    along x); two brackets behind it on the wall."""
    length, height = ARROW
    tip = length / 2
    neck = tip - ARROW_POINT
    s = pointing
    outline = [(-s * tip, -height / 2), (s * neck, -height / 2), (s * tip, 0.0), (s * neck, height / 2),
               (-s * tip, height / 2)]
    if s < 0:
        outline = outline[::-1]
    body = [(-s * tip, -height / 2), (s * neck, -height / 2), (s * neck, height / 2), (-s * tip, height / 2)]
    point = [(s * neck, -height / 2), (s * tip, 0.0), (s * neck, height / 2)]
    if s < 0:
        body, point = body[::-1], point[::-1]
    _plate(m, outline, (0.0, -STANDOFF - ARROW_THICK, 0.0), ARROW_THICK, "tile_line",
           faces=[(body, "sign"), (point, "tile_line")], back_slot="enamel")
    for x in (-tip + 0.15, neck - 0.1):
        box(m, (s * x - 0.02, -STANDOFF, -0.02), (s * x + 0.02, 0.0, 0.02), "steel", r=0.0)


def arrow_east(m):
    _arrow(m, 1)


def arrow_west(m):
    _arrow(m, -1)


# The mouth


def mouth_portal(m):
    """The bulkhead round the lane's mouth: a jamb down each wall and the beam across under the vault, haunched where
    they meet; one solid, the lane's services running into it."""
    b, f = BACK_WALL - 0.01, FAR_WALL + 0.01
    j, h = PORTAL_JAMB, HEIGHT - PORTAL_BEAM
    x0, x1 = -HALF - PORTAL_OUT, -HALF + PORTAL_IN
    # (Its jambs and beam each a box, the haunches wedges in their corners: one concave outline packs badly.)
    for z0, z1 in ((b, b + j), (f - j, f)):
        box(m, (x0, -z1, -0.02), (x1, -z0, h), "cement", r=0.0)
    box(m, (x0, -f, h), (x1, -b, HEIGHT), "cement", r=0.0)
    for corner, out in ((b + j, 1), (f - j, -1)):
        wedge = [(corner, h + 0.01), (corner, h - PORTAL_HAUNCH), (corner + out * PORTAL_HAUNCH, h + 0.01)]
        _extrude_x(m, [(-z, y) for z, y in wedge], x0, x1, "cement")


def build():
    common.reset()
    underground_shapes.rng = rng
    rng.seed(1531)
    for f in (chapel_door, votive_ledges, milagros_board, puesto, enamel_sign, arrow_east, arrow_west, mouth_portal):
        smooth_object(f.__name__, f)


def main():
    build()
    common.export_piece(NAME, ATLAS, SLOTS, out=common.ROOT / "assets" / "eclipse" / "kit", sets_each=True,
                        budget=max(BUDGET.values()), sliver=min(SLIVER.values()))


if __name__ == "__main__":
    main()
