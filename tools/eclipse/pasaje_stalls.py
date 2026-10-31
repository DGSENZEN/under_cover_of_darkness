"""The Pasaje's stalls (docs/superpowers/specs/2026-10-26-pasaje-market-design.md; plan
docs/superpowers/plans/2026-10-26-pasaje-market.md, Task 4): what the market's stallholders built against the Company's
tiles, in the hero stall's language (tools/eclipse/stall.py: the Company's pipe frame, its back higher so the cover
sheds the pipes' drips) and in what came to hand. maps/pasaje.gd puts each stall together from them:

- frames, each in WIDTHS: pipe_frame (four pipe posts in cast shoes, rails and fittings, the back posts strapped to
  the wall), booth (plank sides, a fascia, a shelf on the wall), lean_to (two timber posts and a beam, a ledger bolted
  to the wall, braces);
- covers, each in WIDTHS, all on the one slope the frames carry: awning_canvas (scalloped flaps), awning_tin
  (corrugated, its edge rolled), awning_tarp (a blue tarpaulin, its front rolled and roped down);
- counter, in WIDTHS: a board on legs, a skirt across its front, short of its right end so the keeper can get in;
  the floor open under it (room for what lives there);
- neon_box_<w>: the sign over the stall, its face blank for the user's words in an enamel border, and neon_tube_<w>,
  its tube (a NeonSign lights it);
- barrow: the fruit seller's barrow, on two wheels and two legs;
- vitrina, plancha: the tortas stall's glass case and griddle, on its counter (the card's).

Every piece is built in a stall's frame: x along the wall (the stall's middle at 0), the wall's tiles at y = 0, the
street toward -y, z up from the floor.

    Blender -b --factory-startup --python tools/eclipse/pasaje_stalls.py
"""

import math
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import common  # noqa: E402
import underground_shapes  # noqa: E402
from candle_lane import _extrude_x  # noqa: E402
from underground_shapes import box, pipe, smooth_object, stud, turned  # noqa: E402

NAME = "pasaje_stalls"
# (Its many small pieces want the shell's density: 2048 left them at 53 px/m.)
ATLAS = 4096
SLOTS = ["steel", "wood", "cloth", "cloth_patch", "cloth_blue", "tin", "iron", "rubber", "enamel", "sign", "neon", "glass",
         "brass", "paint_blue"]

rng = random.Random(1931)

WIDTHS = (1.6, 2.2, 2.8)
FRAMES = ("pipe_frame", "booth", "lean_to")
AWNINGS = ("awning_canvas", "awning_tin", "awning_tarp")
NEON_WIDTHS = (0.9, 1.3)

# The stall's depth: its back posts' and front posts' middles (y), how far its cover reaches over the street, the
# frame's heights at the back and the front (the cover rides 3 cm over them), the highest any of it stands (under the
# mains on the walls).
BACK_Y, FRONT_Y = -0.06, -1.40
REACH = 1.62
BACK_H, FRONT_H = 2.55, 2.05
RIDE = 0.03
TOP = 2.85
# The counter: its front and back, its top's height and thickness, how far short of the right end it stops (the
# keeper's way in), its skirt's foot (the floor open under it).
COUNTER_Y = (-1.45, -0.86)
COUNTER_TOP = 0.92
COUNTER_T = 0.04
KEEPER_WAY = 0.45
SKIRT_FOOT = 0.42
# The neon box: its face's y, its depth, its foot and height over the cover; its enamel border.
NEON_FACE = -1.42
NEON_DEEP = 0.12
NEON_FOOT, NEON_HIGH = 2.36, 0.42
NEON_BORDER = 0.05
TUBE_R = 0.009


def piece_name(family, width):
    return "%s_%d" % (family, round(width * 10))


def cover_z(y):
    """The cover's underside over `y` (the slope from the back rail to the front)."""
    return BACK_H + RIDE + (y - BACK_Y) * (BACK_H - FRONT_H) / (BACK_Y - FRONT_Y)


def _sloped(m, x0, x1, y_back, y_front, thick, slot, lift=0.0):
    """A board or sheet on the cover's slope from `y_back` to `y_front`, `thick` deep, `lift` over the underside."""
    outline = [(y_back, cover_z(y_back) + lift), (y_front, cover_z(y_front) + lift),
               (y_front, cover_z(y_front) + lift + thick), (y_back, cover_z(y_back) + lift + thick)]
    _extrude_x(m, outline, x0, x1, slot)


# --- the frames ----------------------------------------------------------------------------------

def _post_top(y):
    return BACK_H if y == BACK_Y else FRONT_H


def _pipe_frame(width):
    def made(m):
        half = width / 2 - 0.05
        r, fit = 0.024, 0.04
        for x in (-half, half):
            for y in (BACK_Y, FRONT_Y):
                top = _post_top(y)
                # The cast shoe, the post up from it to its fitting.
                box(m, (x - 0.06, y - 0.06, 0.0), (x + 0.06, y + 0.06, 0.05), "iron", r=0.0)
                pipe(m, [(x, y, 0.05), (x, y, top)], r, 8, "steel")
                box(m, (x - fit, y - fit, top - fit), (x + fit, y + fit, top + fit), "iron", r=0.0)
            # The side rail along the top, and a tie at counter height.
            pipe(m, [(x, BACK_Y, BACK_H), (x, FRONT_Y, FRONT_H)], 0.02, 8, "steel")
            pipe(m, [(x, BACK_Y, 1.1), (x, FRONT_Y, 1.1)], 0.016, 8, "steel")
            # The back post strapped to the wall's tiles.
            box(m, (x - 0.05, -0.012, 1.6), (x + 0.05, 0.0, 1.72), "iron", r=0.0)
            pipe(m, [(x, -0.012, 1.66), (x, BACK_Y - r, 1.66)], 0.01, 6, "steel")
        for y in (BACK_Y, FRONT_Y):
            pipe(m, [(-half, y, _post_top(y)), (half, y, _post_top(y))], 0.02, 8, "steel")
    return made


def _booth(width):
    def made(m):
        half = width / 2
        side = 0.035
        boards = 3
        span = (BACK_Y + 0.04 - (FRONT_Y - 0.05)) / boards
        for sign in (-1, 1):
            x0, x1 = sorted((sign * half, sign * (half - side)))
            for k in range(boards):
                y_b = BACK_Y + 0.04 - k * span
                y_f = y_b - span + 0.012
                tall = [(y_b, 0.0), (y_f, 0.0), (y_f, cover_z(y_f) - RIDE), (y_b, cover_z(y_b) - RIDE)]
                _extrude_x(m, tall, x0, x1, "wood")
        # The fascia across the front's top between the sides, and the shelf on the wall.
        box(m, (-half + side, FRONT_Y - 0.05, FRONT_H - 0.26), (half - side, FRONT_Y - 0.02, FRONT_H - 0.02), "paint_blue",
            r=0.0)
        box(m, (-half + side, -0.33, 1.5), (half - side, -0.02, 1.535), "wood", r=0.0)
        # Its brackets under it, and a hook rail under the fascia.
        for x in (-half / 2, half / 2):
            box(m, (x - 0.015, -0.3, 1.3), (x + 0.015, -0.012, 1.5), "iron", r=0.0)
        pipe(m, [(-half + side, FRONT_Y + 0.02, FRONT_H - 0.3), (half - side, FRONT_Y + 0.02, FRONT_H - 0.3)], 0.012, 6,
             "steel")
    return made


def _lean_to(width):
    def made(m):
        half = width / 2
        t = 0.08
        for x in (-half + 0.06, half - 0.06):
            box(m, (x - t / 2, FRONT_Y - t / 2, 0.0), (x + t / 2, FRONT_Y + t / 2, FRONT_H - 0.1), "wood", r=0.0)
            # A brace from the post up into the beam.
            inward = 1 if x < 0 else -1
            pipe(m, [(x + inward * 0.04, FRONT_Y, 1.7), (x + inward * 0.42, FRONT_Y, FRONT_H - 0.1)], 0.018, 6, "wood")
        box(m, (-half, FRONT_Y - t / 2, FRONT_H - 0.1), (half, FRONT_Y + t / 2, FRONT_H), "wood", r=0.0)
        # The ledger on the wall, bolted through to it.
        box(m, (-half, -0.08, BACK_H - 0.1), (half, -0.0, BACK_H), "wood", r=0.0)
        for x in (-half + 0.25, 0.0, half - 0.25):
            stud(m, (x, -0.08, BACK_H - 0.05), math.pi / 2, 0.0, slot="iron", r=0.016)
    return made


# --- the covers ----------------------------------------------------------------------------------

def _canvas(width):
    def made(m):
        half = width / 2 + 0.08
        _sloped(m, -half, half, -0.03, -REACH + 0.02, 0.025, "cloth")
        # The scalloped flaps along its front.
        count = int(2 * half / 0.19)
        pitch = 2 * half / count
        z = cover_z(-REACH + 0.02)
        for k in range(count):
            x0 = -half + k * pitch + 0.015
            box(m, (x0, -REACH + 0.02, z - 0.14), (x0 + pitch - 0.03, -REACH + 0.04, z), "cloth_patch" if k % 2 else "cloth",
                r=0.0)
    return made


def _tin(width):
    def made(m):
        half = width / 2 + 0.08
        rib = 0.07
        count = int(2 * half / rib)
        pitch = 2 * half / count
        for k in range(count):
            _sloped(m, -half + k * pitch, -half + (k + 1) * pitch, -0.03, -REACH + 0.04, 0.012, "tin",
                    lift=0.018 if k % 2 else 0.0)
        # Its front edge rolled over a pipe.
        z = cover_z(-REACH + 0.04)
        pipe(m, [(-half + 0.03, -REACH + 0.04, z), (half - 0.03, -REACH + 0.04, z)], 0.018, 8, "tin")
    return made


def _tarp(width):
    def made(m):
        half = width / 2 + 0.08
        _sloped(m, -half, half, -0.03, -REACH + 0.05, 0.02, "cloth_blue")
        # Its front rolled, roped down to the frame's front corners.
        z = cover_z(-REACH + 0.05)
        pipe(m, [(-half + 0.03, -REACH + 0.05, z - 0.01), (half - 0.03, -REACH + 0.05, z - 0.01)], 0.03, 8, "cloth_blue")
        for sign in (-1, 1):
            pipe(m, [(sign * (half - 0.08), -REACH + 0.06, z - 0.03), (sign * (width / 2 - 0.05), FRONT_Y, FRONT_H - 0.35)],
                 0.008, 4, "rubber")
    return made


# --- the counter ---------------------------------------------------------------------------------

def _counter(width):
    def made(m):
        x0, x1 = -width / 2 + 0.1, width / 2 - KEEPER_WAY
        front, back = COUNTER_Y
        box(m, (x0, front, COUNTER_TOP - COUNTER_T), (x1, back, COUNTER_TOP), "wood", r=0.0)
        leg = 0.05
        for x in (x0 + 0.03, x1 - 0.03 - leg):
            for y in (front + 0.05, back - 0.05 - leg):
                box(m, (x, y, 0.0), (x + leg, y + leg, COUNTER_TOP - COUNTER_T), "wood", r=0.0)
            # A rail between its end legs, front to back, clear of the floor.
            box(m, (x + 0.01, front + 0.05 + leg, 0.24), (x + leg - 0.01, back - 0.05 - leg, 0.28), "wood", r=0.0)
        # The skirt across its front, its foot well off the floor.
        box(m, (x0 + 0.01, front + 0.005, SKIRT_FOOT), (x1 - 0.01, front + 0.045, COUNTER_TOP - COUNTER_T), "paint_blue",
            r=0.0)
    return made


# --- the neon ------------------------------------------------------------------------------------

def _neon_box(width):
    def made(m):
        half, b, h = width / 2, NEON_BORDER, NEON_HIGH
        xs = [-half, -half + b, half - b, half]
        zs = [0.0, b, h - b, h]
        # The face in nine cells (the middle blank for the words, the rest the enamel border), its outline through
        # every cell's corner on the rim.
        rim = [(xs[0], zs[0]), (xs[1], zs[0]), (xs[2], zs[0]), (xs[3], zs[0]), (xs[3], zs[1]), (xs[3], zs[2]),
               (xs[3], zs[3]), (xs[2], zs[3]), (xs[1], zs[3]), (xs[0], zs[3]), (xs[0], zs[2]), (xs[0], zs[1])]

        def at(u, v, d=0.0):
            return (u, NEON_FACE + d, NEON_FOOT + v)

        m.shell()
        for i in range(3):
            for j in range(3):
                cell = [(xs[i], zs[j]), (xs[i + 1], zs[j]), (xs[i + 1], zs[j + 1]), (xs[i], zs[j + 1])]
                m.face([at(u, v) for u, v in cell], "sign" if (i, j) == (1, 1) else "enamel")
        m.face([at(u, v, NEON_DEEP) for u, v in reversed(rim)], "enamel")
        for k in range(len(rim)):
            (u0, v0), (u1, v1) = rim[k], rim[(k + 1) % len(rim)]
            m.face([at(u0, v0), at(u0, v0, NEON_DEEP), at(u1, v1, NEON_DEEP), at(u1, v1)], "enamel")
        # Its two legs down through the cover to the frame's front rail.
        for x in (-half + 0.12, half - 0.12):
            pipe(m, [(x, NEON_FACE + NEON_DEEP / 2, NEON_FOOT), (x, NEON_FACE + NEON_DEEP / 2, FRONT_H)], 0.015, 6,
                 "steel")
    return made


def _neon_tube(width):
    """The tube, a loop round the face inside its border, standing off it on its own."""
    def made(m):
        half = width / 2 - NEON_BORDER - 0.04
        low, high = NEON_FOOT + NEON_BORDER + 0.04, NEON_FOOT + NEON_HIGH - NEON_BORDER - 0.04
        y = NEON_FACE - 0.03
        corner = 0.05
        points = []
        for cx, cz, start in ((half - corner, high - corner, 0.0), (-half + corner, high - corner, 0.5),
                              (-half + corner, low + corner, 1.0), (half - corner, low + corner, 1.5)):
            for k in range(4):
                a = math.pi * (start + 0.5 * k / 3)
                points.append((cx + corner * math.cos(a), y, cz + corner * math.sin(a)))
        pipe(m, points, TUBE_R, 6, "neon", closed=True)
    return made


# --- the barrow and the tortas stall's fittings ------------------------------------------------------

def barrow(m):
    """The fruit seller's barrow: a plank tray with sides on two wheels and two legs, its handles toward the end."""
    x0, x1, y0, y1, low = -0.75, 0.75, -1.05, -0.25, 0.7
    box(m, (x0, y0, low), (x1, y1, low + 0.04), "wood", r=0.0)
    side = 0.035
    for ya, yb in ((y0 - side, y0), (y1, y1 + side)):
        box(m, (x0 - side, ya, low), (x1 + side, yb, low + 0.18), "paint_blue", r=0.0)
    for xa, xb in ((x0 - side, x0), (x1, x1 + side)):
        box(m, (xa, y0, low + 0.04), (xb, y1, low + 0.18), "paint_blue", r=0.0)
    # Two wheels on an axle under its right end; two legs under its left; the handles out past them.
    for y in (y0 - 0.1, y1 + 0.1):
        turned(m, [(0.2, -0.03), (0.2, 0.03)], 14, "rubber", at=(0.5, y, 0.2), lean=math.pi / 2)
        turned(m, [(0.05, -0.065), (0.05, 0.065)], 8, "iron", at=(0.5, y, 0.2), lean=math.pi / 2)
    pipe(m, [(0.5, y0 - 0.06, 0.2), (0.5, y1 + 0.06, 0.2)], 0.018, 6, "iron")
    for y in (y0 + 0.05, y1 - 0.05):
        box(m, (-0.62, y - 0.025, 0.0), (-0.57, y + 0.025, low), "wood", r=0.0)
        pipe(m, [(x0 + 0.1, y, low - 0.02), (x0 - 0.3, y, low + 0.08)], 0.02, 6, "wood")
        # (Its axle's hangers from the tray.)
        box(m, (0.48, y - 0.015, 0.2), (0.52, y + 0.015, low), "iron", r=0.0)


def vitrina(m):
    """The tortas stall's glass case on its counter: a steel tray, the glass, a steel lid."""
    x0, x1, y0, y1, z0 = -0.85, -0.15, -1.36, -1.02, COUNTER_TOP
    box(m, (x0, y0, z0), (x1, y1, z0 + 0.04), "steel", r=0.0)
    box(m, (x0 + 0.01, y0 + 0.01, z0 + 0.04), (x1 - 0.01, y1 - 0.01, z0 + 0.3), "glass", r=0.0)
    box(m, (x0, y0, z0 + 0.3), (x1, y1, z0 + 0.34), "steel", r=0.0)


def plancha(m):
    """The tortas stall's griddle on its counter: a black iron plate on short legs, a grease trough along its front."""
    x0, x1, y0, y1, z0 = 0.0, 0.5, -1.32, -0.98, COUNTER_TOP
    for x in (x0 + 0.03, x1 - 0.07):
        for y in (y0 + 0.03, y1 - 0.07):
            box(m, (x, y, z0), (x + 0.04, y + 0.04, z0 + 0.06), "iron", r=0.0)
    box(m, (x0, y0, z0 + 0.06), (x1, y1, z0 + 0.095), "iron", r=0.0)
    box(m, (x0 + 0.02, y0 - 0.06, z0 + 0.045), (x1 - 0.02, y0, z0 + 0.08), "steel", r=0.0)


# The kiosk (in its own frame: x across it, its hatch toward -y, z up): its body's half width and half depth, its
# walls' thickness, its hatch (sill and lintel), its eaves, the ridge's height, the sign board's top (under the
# canopy, which sags to 3.0 m over the street's middle), its wings' length and how far they open.
KIOSK_X, KIOSK_Y = 1.2, 0.6
KIOSK_WALL = 0.06
KIOSK_SILL, KIOSK_LINTEL = 1.0, 1.9
KIOSK_EAVES, KIOSK_RIDGE = 2.3, 2.72
KIOSK_SIGN_TOP = 2.95
KIOSK_WING, KIOSK_OPEN = 0.75, math.radians(45.0)


def kiosk(m):
    """The newspaper and lottery kiosk the stallholders built in the street's middle under their canopy: a painted box
    on a plinth, its hatch to the north with its shutter propped up over it as an awning, the papers stacked on its
    sill; its display boards hinged open from its front corners; a gable of tin over it and the board on its ridge,
    blank for the user's words; bundles of the morning's papers stacked behind it."""
    x, y, w = KIOSK_X, KIOSK_Y, KIOSK_WALL
    box(m, (-x - 0.05, -y - 0.05, 0.0), (x + 0.05, y + 0.05, 0.12), "iron", r=0.0)
    # Its walls: the sides the full depth, the back and the front between them; the hatch cut in the front.
    for s in (-1, 1):
        box(m, (min(s * x, s * (x - w)), -y, 0.12), (max(s * x, s * (x - w)), y, KIOSK_EAVES), "paint_blue", r=0.0)
    box(m, (-x + w, y - w, 0.12), (x - w, y, KIOSK_EAVES), "paint_blue", r=0.0)
    hatch = x - 0.25
    box(m, (-x + w, -y, 0.12), (x - w, -y + w, KIOSK_SILL), "paint_blue", r=0.0)
    box(m, (-x + w, -y, KIOSK_LINTEL), (x - w, -y + w, KIOSK_EAVES), "paint_blue", r=0.0)
    for s in (-1, 1):
        box(m, (min(s * hatch, s * (x - w)), -y, KIOSK_SILL), (max(s * hatch, s * (x - w)), -y + w, KIOSK_LINTEL),
            "paint_blue", r=0.0)
    # The sill out under the hatch, the papers stacked on it.
    box(m, (-hatch, -y - 0.22, KIOSK_SILL - 0.04), (hatch, -y, KIOSK_SILL + 0.02), "wood", r=0.0)
    for k, (x0, x1, h) in enumerate(((-0.85, -0.45, 0.09), (-0.35, 0.05, 0.14), (0.2, 0.6, 0.06), (0.65, 0.88, 0.11))):
        box(m, (x0, -y - 0.2, KIOSK_SILL + 0.02), (x1, -y - 0.03, KIOSK_SILL + 0.02 + h), "sign", r=0.0)
    # Its shutter propped up over the hatch as an awning, on two struts from the sill's ends.
    lift = math.radians(28.0)
    deep = 0.62
    centre = (0.0, -y - 0.03 - deep / 2 * math.cos(lift), KIOSK_LINTEL + deep / 2 * math.sin(lift))
    box(m, (centre[0] - hatch - 0.05, centre[1] - deep / 2, centre[2] - 0.0175),
        (centre[0] + hatch + 0.05, centre[1] + deep / 2, centre[2] + 0.0175), "tin", r=0.0, turn=(-lift, 0.0, 0.0))
    tip = (-y - 0.03 - deep * math.cos(lift) * 0.92, KIOSK_LINTEL + deep * math.sin(lift) * 0.92 - 0.03)
    for s in (-1, 1):
        pipe(m, [(s * (hatch - 0.05), -y - 0.18, KIOSK_SILL + 0.02), (s * (hatch - 0.05), tip[0], tip[1])], 0.012, 6,
             "steel")
    # The display boards hinged open from its front corners, a frame round each, its hinges.
    for s in (-1, 1):
        way = (s * math.cos(KIOSK_OPEN), -math.sin(KIOSK_OPEN))
        mid = (s * (x + 0.02) + way[0] * KIOSK_WING / 2, -y + way[1] * KIOSK_WING / 2)
        yaw = math.atan2(way[1], way[0])
        box(m, (mid[0] - KIOSK_WING / 2, mid[1] - 0.0175, 0.35), (mid[0] + KIOSK_WING / 2, mid[1] + 0.0175, 2.15),
            "paint_blue", r=0.0, turn=(0.0, 0.0, yaw))
        for z in (0.6, 1.9):
            # (Out on the corner, its faces well off the walls' on both sides.)
            x0, x1 = sorted((s * (x - 0.02), s * (x + 0.06)))
            box(m, (x0, -y - 0.045, z - 0.05), (x1, -y + 0.045, z + 0.05), "iron", r=0.0)
    # The gable of tin over it, its eaves out past the walls, and the board on its ridge.
    _extrude_x(m, [(y + 0.25, KIOSK_EAVES), (-y - 0.25, KIOSK_EAVES), (-y - 0.25, KIOSK_EAVES + 0.06),
                   (0.0, KIOSK_RIDGE), (y + 0.25, KIOSK_EAVES + 0.06)], -x - 0.2, x + 0.2, "tin")
    box(m, (-x + 0.15, -0.04, KIOSK_RIDGE - 0.06), (x - 0.15, 0.04, KIOSK_SIGN_TOP), "enamel", r=0.0)
    box(m, (-x + 0.2, -0.085, KIOSK_RIDGE - 0.02), (x - 0.2, -0.04, KIOSK_SIGN_TOP - 0.04), "sign", r=0.0)
    # The morning's bundles stacked behind it, wrapped in canvas.
    for x0, x1, h in ((-0.95, -0.35, 0.42), (-0.3, 0.2, 0.28), (0.4, 0.95, 0.36)):
        box(m, (x0, y + 0.06, 0.0), (x1, y + 0.36, h), "cloth", r=0.02)


PIECES = []
for _w in WIDTHS:
    PIECES += [(piece_name("pipe_frame", _w), _pipe_frame(_w)), (piece_name("booth", _w), _booth(_w)),
               (piece_name("lean_to", _w), _lean_to(_w)), (piece_name("awning_canvas", _w), _canvas(_w)),
               (piece_name("awning_tin", _w), _tin(_w)), (piece_name("awning_tarp", _w), _tarp(_w)),
               (piece_name("counter", _w), _counter(_w))]
for _w in NEON_WIDTHS:
    PIECES += [("neon_box_%d" % round(_w * 10), _neon_box(_w)), ("neon_tube_%d" % round(_w * 10), _neon_tube(_w))]
PIECES += [("barrow", barrow), ("vitrina", vitrina), ("plancha", plancha), ("kiosk", kiosk)]

BUDGET = {name: 3000 for name, _ in PIECES}
# (The tubes, straps, ropes and rims are millimetres across by nature.)
SLIVER = {name: 0.004 for name in BUDGET}


def build():
    common.reset()
    underground_shapes.rng = rng
    rng.seed(1931)

    for name, f in PIECES:
        smooth_object(name, f)


def main():
    build()
    common.export_piece(NAME, ATLAS, SLOTS, out=common.ROOT / "assets" / "eclipse" / "kit", sets_each=True,
                        budget=max(BUDGET.values()), sliver=min(SLIVER.values()))


if __name__ == "__main__":
    main()
