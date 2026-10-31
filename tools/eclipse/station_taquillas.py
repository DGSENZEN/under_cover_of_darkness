"""The Zócalo station's taquillas (docs/superpowers/specs/2026-10-27-metro-station-design.md; plan
docs/superpowers/plans/2026-10-30-metro-station.md, Task 7): the Light Company sells the rides here, through brass bars,
from wooden booths with a lamp over each window.

The Company drew the booth (its joinery, its brass, its lamps); the city's masons built its stone in the neocolonial
revival's manner (the 1917-1920 exemption for viceregal building): a tezontle plinth, chiluca estípites between the
windows with the heads stepped in over them, a stepped fret along the frieze, a stepped crown and over the middle a crest
bearing the Company's emblem (its face the user's). Talavera under each window, a broken tile or two boarded over with
the Company's wood. Over each window a blank sign (the user's words) and the Company's ward lamp: caged, obsidian lenses
on its four sides, the lamps that keep the dead off the till. Inside, the seller's boarded floor raised so they look
down over the counter, a desk behind each window, a ticket rack and a stool, and the seller's own things: a saint's card,
marigolds in a tin.

Maps/metro_station.gd stands them in the hall.

Frames (Blender: x along the booth, -y out toward the hall, z up; Godot turns -y into +z): a booth centred on x = 0, its
back on the wall's face at y = 0, its front at y = -DEPTH, standing on the floor at z = 0.

    Blender -b --factory-startup --python tools/eclipse/station_taquillas.py
"""

import math
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import common  # noqa: E402
import shapes  # noqa: E402
import underground_shapes  # noqa: E402
from underground_shapes import box, pipe, smooth_object, stud, turned  # noqa: E402

NAME = "station_taquillas"
ATLAS = 4096
SLOTS = ["wood", "chiluca", "tezontle", "brass", "iron", "obsidian", "mortar", "talavera_cobalt", "talavera_glaze",
         "talavera_yellow", "paper", "sign", "print_saint", "tin", "marigold", "glass"]

# The booths: the east (the plan's ticket booth, against the hall's north wall) with three windows, the west with two.
WINDOWS = {"taquilla_east": 3, "taquilla_west": 2}
# From the wall's face to the posts' fronts (m).
DEPTH = 2.0
# The corner posts' side, the piers' width between windows, the walls' thickness, how far the walls stand back from
# the posts' faces (m).
POST = 0.36
PIER = 0.4
WALL = 0.1
INSET = 0.04
# The tezontle plinth: its height and how far it stands proud of the posts (m).
PLINTH = (0.3, 0.05)
# The chiluca counter: its top, its thickness, how far it reaches out in front of the posts and back in behind them as
# the desk (m).
COUNTER = 1.05
COUNTER_THICK = 0.08
COUNTER_OUT = 0.32
DESK = 0.6
# A window: its width, its head; the brass frame's bar, the bars' line behind the posts' faces, a bar's radius (m).
WINDOW = (1.4, 2.3)
FRAME = 0.045
BARS_AT = 0.05
BAR_R = 0.022
# At most this between two bars' middles (m).
BAR_GAP = 0.13
# The transom over the bars, the fan over it.
TRANSOM = 1.95
# The window's head stepped in at its corners, a Mayan corbel: each step's height and how far in from the jamb.
CORBEL = [(2.06, 0.12), (2.18, 0.24)]
# The slot under the bars the money and the tickets pass through: its width and height; the dish let into the counter
# under it: its half-width along, its reach out and in from the bars' line, how deep under the counter's top, how far
# its bowl hangs under the counter (m).
SLOT = (0.36, 0.14)
DISH = (0.22, 0.14, 0.16, 0.035, 0.045)
# The estípite between two windows: an inverted pyramid from its block on the counter to its capital; its half-widths
# at its foot and its head (m).
ESTIPITE = (1.11, 2.02)
ESTIPITE_HALF = (0.1, 0.2)
# The frieze over the windows; the sign over each window (m: its foot and top), how far the sign and its frame stand
# proud.
FRIEZE = 2.95
SIGN = (2.38, 2.68)
SIGN_WIDE = 1.1
SIGN_PROUD = (0.04, 0.065)
# The stepped fret along the frieze over the signs (m: its foot and top), how far its steps stand proud, a motif's
# length.
FRET = (2.76, 2.92)
FRET_PROUD = 0.04
FRET_UNIT = 0.32
# The crown over the frieze: its tiers (m: foot, top, how far out from the frieze's face), each over the cornice set
# further back; its top.
CROWN = [(2.95, 3.07, 0.14), (3.07, 3.14, 0.04), (3.14, 3.2, -0.04)]
TOP = 3.2
# The crest over the booth's middle: its tiers (m: wide, tall, how far back from the frieze's face), its depth; the
# Company's emblem on its face (m: foot, top over the floor).
CREST = [(1.6, 0.24, 0.04), (1.1, 0.14, 0.1), (0.6, 0.12, 0.16)]
CREST_DEEP = 0.6
EMBLEM = (TOP + 0.04, TOP + 0.2)
# A ward lamp: its middle out from the wall's face and up (m), its cage's half-side, its foot and top.
LAMP = (-DEPTH - 0.45, 2.86)
CAGE = (0.13, 2.72, 3.0)
# The Talavera under each window (m: its foot and top), its tiles across and up.
TILES = (0.38, 0.869)
TILE_GRID = (9, 4)
TILE_WIDE = 1.1
# The seller's boarded floor (m).
FLOOR = 0.3
# The back boards' thickness (m).
BOARDS = 0.035
# The door in the east end: its width, its height over the plinth (m).
DOOR = (0.8, 1.85)


def length(count):
    return count * WINDOW[0] + (count - 1) * PIER + 2 * POST


def window_xs(count):
    """Each window's middle along x."""
    x0 = -length(count) / 2
    return [x0 + POST + WINDOW[0] / 2 + k * (WINDOW[0] + PIER) for k in range(count)]


def bar_xs(cx):
    """The bars' middles across the window centred on `cx`."""
    inner = WINDOW[0] - 2 * FRAME
    gaps = int(math.ceil(inner / BAR_GAP))
    return [cx - inner / 2 + inner * k / gaps for k in range(1, gaps)]


def _sweep(m, profile, path, slot):
    """A profile [(out, z)] swept along a polyline `path` [(x, y)] round the booth, `out` measured outward from it
    (to the path's right-hand side going along it), mitred at its corners, capped at its ends."""
    rings = []
    n = len(path)
    for i in range(n):
        normals = []
        if i > 0:
            d = (path[i][0] - path[i - 1][0], path[i][1] - path[i - 1][1])
            k = math.hypot(*d)
            normals.append((d[1] / k, -d[0] / k))
        if i < n - 1:
            d = (path[i + 1][0] - path[i][0], path[i + 1][1] - path[i][1])
            k = math.hypot(*d)
            normals.append((d[1] / k, -d[0] / k))
        # (A corner's offset along its mitre: the two normals' sum, square corners only.)
        nx, ny = (sum(c[0] for c in normals), sum(c[1] for c in normals)) if len(normals) == 2 else normals[0]
        rings.append([(path[i][0] + nx * o, path[i][1] + ny * o, z) for o, z in profile])
    shapes.loft(m, rings, slot, caps=True)


def _counter(m, x0, x1, holes):
    """The chiluca counter, one slab from x0 to x1 with a hole over each dish (holes [(x0, x1, y0, y1)]), its every
    face welded into one solid (no joints across its top)."""
    m.shell()
    y0, y1 = -DEPTH - COUNTER_OUT, -DEPTH + DESK
    z0, z1 = COUNTER - COUNTER_THICK, COUNTER
    xs = sorted({x0, x1, *[h[0] for h in holes], *[h[1] for h in holes]})
    ys = sorted({y0, y1, *[h[2] for h in holes], *[h[3] for h in holes]})

    def hole(i, j):
        cx, cy = (xs[i] + xs[i + 1]) / 2, (ys[j] + ys[j + 1]) / 2
        return any(h[0] < cx < h[1] and h[2] < cy < h[3] for h in holes)

    for i in range(len(xs) - 1):
        for j in range(len(ys) - 1):
            if hole(i, j):
                continue
            a, b, c, d = xs[i], xs[i + 1], ys[j], ys[j + 1]
            m.face([(a, c, z1), (b, c, z1), (b, d, z1), (a, d, z1)], "chiluca")
            m.face([(a, c, z0), (a, d, z0), (b, d, z0), (b, c, z0)], "chiluca")
            # (Its sides where a cell meets the outside or a hole.)
            if j == 0 or hole(i, j - 1):
                m.face([(a, c, z0), (b, c, z0), (b, c, z1), (a, c, z1)], "chiluca")
            if j == len(ys) - 2 or hole(i, j + 1):
                m.face([(a, d, z0), (a, d, z1), (b, d, z1), (b, d, z0)], "chiluca")
            if i == 0 or hole(i - 1, j):
                m.face([(a, c, z0), (a, c, z1), (a, d, z1), (a, d, z0)], "chiluca")
            if i == len(xs) - 2 or hole(i + 1, j):
                m.face([(b, c, z0), (b, d, z0), (b, d, z1), (b, c, z1)], "chiluca")


def _window(m, cx):
    """A window's brass: its frame, the bars over the slot and beside it, the transom and the sun over it, the dish;
    its head stepped in at its corners in chiluca."""
    front = -DEPTH
    y = front + BARS_AT
    y0, y1 = y - FRAME / 2, y + FRAME / 2
    half = WINDOW[0] / 2
    # (The frame: the jambs against the piers, the head under the frieze, the transom.)
    for x in (cx - half, cx + half - FRAME):
        box(m, (x, y0, COUNTER), (x + FRAME, y1, WINDOW[1]), "brass", r=0.0)
    box(m, (cx - half + FRAME, y0, WINDOW[1] - FRAME), (cx + half - FRAME, y1, WINDOW[1]), "brass", r=0.0)
    box(m, (cx - half + FRAME, y0, TRANSOM), (cx + half - FRAME, y1, TRANSOM + FRAME), "brass", r=0.0)
    # (The slot's lintel; the bars over it stand on it, the others on the counter.)
    lintel = COUNTER + SLOT[1]
    box(m, (cx - SLOT[0] / 2 - 0.03, y0, lintel), (cx + SLOT[0] / 2 + 0.03, y1, lintel + FRAME), "brass", r=0.0)
    for x in bar_xs(cx):
        foot = lintel + FRAME if abs(x - cx) < SLOT[0] / 2 + 0.03 else COUNTER
        pipe(m, [(x, y, foot), (x, y, TRANSOM)], BAR_R, 10, "brass")
    # (The sun: its boss on the transom, its rays to the frame, a half ring round the boss.)
    hub = TRANSOM + FRAME
    head = WINDOW[1] - FRAME
    inner = half - FRAME
    rays = 7
    for k in range(1, rays):
        a = math.pi * k / rays
        dx, dz = math.cos(a), math.sin(a)
        t = min(inner / abs(dx) if abs(dx) > 1e-6 else 99.0, (head - hub) / dz)
        pipe(m, [(cx + dx * 0.06, y, hub + dz * 0.06), (cx + dx * t, y, hub + dz * t)], 0.016, 8, "brass")
    ring = [(cx + 0.34 * math.cos(math.pi * k / 16), y, hub + 0.2 * math.sin(math.pi * k / 16)) for k in range(17)]
    pipe(m, ring, 0.016, 8, "brass")
    turned(m, [(0.08, -0.06), (0.08, 0.04), (0.065, 0.06)], 20, "brass", at=(cx, y, hub), lean=math.pi / 2)
    # (The dish under the slot, sunk in the counter, worn by the coins; its bowl hangs under the counter, clear of the
    # slab's underside and the wall's top under it.)
    box(m, (cx - DISH[0], y - DISH[1] - 0.02, COUNTER - COUNTER_THICK - DISH[4]),
        (cx + DISH[0], y + DISH[2] + 0.02, COUNTER - DISH[3]), "brass", r=0.0)
    # (The head stepped in over the corners, in front of the frame.)
    for side in (-1, 1):
        edge = cx + side * half
        for z0, reach in CORBEL:
            a, b = sorted((edge, edge - side * reach))
            box(m, (a, front - 0.05, z0), (b, front + 0.02, WINDOW[1] if z0 == CORBEL[-1][0] else z0 + 0.12), "chiluca",
                r=0.0)


def _estipite(m, px):
    """The chiluca estípite on the pier at px (its left edge): its block on the counter, the inverted pyramid, its
    capital under the frieze."""
    front = -DEPTH
    cx = px + PIER / 2
    box(m, (cx - 0.14, front - 0.07, COUNTER), (cx + 0.14, front, ESTIPITE[0]), "chiluca", r=0.0)
    m.shell()
    rings = []
    for z, half, out in ((ESTIPITE[0], ESTIPITE_HALF[0], 0.06), (ESTIPITE[1], ESTIPITE_HALF[1], 0.09)):
        rings.append([(cx - half, front - out, z), (cx + half, front - out, z), (cx + half, front + 0.01, z),
                      (cx - half, front + 0.01, z)])
    shapes.loft(m, rings, "chiluca", caps=True)
    box(m, (px, front - 0.1, ESTIPITE[1]), (px + PIER, front + 0.01, WINDOW[1]), "chiluca", r=0.02)


def _sign(m, cx):
    """The blank sign over a window (the user's words), in its frame."""
    front = -DEPTH
    half = SIGN_WIDE / 2
    box(m, (cx - half, front - SIGN_PROUD[0], SIGN[0]), (cx + half, front, SIGN[1]), "sign", r=0.0)
    w = 0.04
    for z0, z1 in ((SIGN[0] - w, SIGN[0]), (SIGN[1], SIGN[1] + w)):
        box(m, (cx - half - w, front - SIGN_PROUD[1], z0), (cx + half + w, front, z1), "wood", r=0.012)
    for x0, x1 in ((cx - half - w, cx - half), (cx + half, cx + half + w)):
        box(m, (x0, front - SIGN_PROUD[1], SIGN[0]), (x1, front, SIGN[1]), "wood", r=0.012)


def _fret(m, a0, a1, place):
    """The stepped fret along a face of the frieze from a0 to a1: each motif a stepped pyramid raised on its ground;
    `place(u0, u1, z0, z1)` stands one block of it on that face."""
    count = int((a1 - a0) // FRET_UNIT)
    start = (a0 + a1) / 2 - count * FRET_UNIT / 2
    h = (FRET[1] - FRET[0]) / 3
    for k in range(count):
        u = start + k * FRET_UNIT
        for step, (a, b) in enumerate(((0.02, 0.30), (0.07, 0.25), (0.12, 0.20))):
            place(u + a, u + b, FRET[0] + step * h, FRET[0] + (step + 1) * h)


def _crest(m):
    """The stepped crest over the booth's middle, the Company's emblem on its face (the user's)."""
    front = -DEPTH
    z = TOP
    for wide, tall, back in CREST:
        box(m, (-wide / 2, front + back, z), (wide / 2, front + CREST_DEEP, z + tall), "chiluca", r=0.02)
        z += tall
    back = CREST[0][2]
    box(m, (-0.3, front + back - 0.04, EMBLEM[0]), (0.3, front + back, EMBLEM[1]), "sign", r=0.0)


def _ward_lamp(m, cx):
    """The Company's ward lamp over a window: a swan neck up off the cornice's conduit, out over the counter and down to
    a brass cage, its glass globe inside, an obsidian lens on each of its four sides."""
    gy, gz = LAMP
    half, z0, z1 = CAGE
    root = -DEPTH + 0.12
    crown = TOP + 0.2
    neck = [(cx, root, TOP + 0.018), (cx, root, crown)]
    ry, yc = (root - gy) / 2, (root + gy) / 2
    for k in range(1, 12):
        a = math.pi * k / 12
        neck.append((cx, yc + ry * math.cos(a), crown + 0.1 * math.sin(a)))
    neck += [(cx, gy, crown), (cx, gy, z1 + 0.1)]
    pipe(m, neck, 0.016, 8, "brass")
    # (Its stepped roof, its foot, its corner posts.)
    for k, (h, a, b) in enumerate(((half + 0.03, z1, z1 + 0.04), (half - 0.03, z1 + 0.04, z1 + 0.08),
                                   (0.05, z1 + 0.08, z1 + 0.12))):
        box(m, (cx - h, gy - h, a), (cx + h, gy + h, b), "brass", r=0.0)
    box(m, (cx - half - 0.02, gy - half - 0.02, z0 - 0.04), (cx + half + 0.02, gy + half + 0.02, z0), "brass", r=0.0)
    turned(m, [(0.04, z0 - 0.04), (0.04, z0 - 0.07), (0.0, z0 - 0.1)], 12, "brass", at=(cx, gy, 0.0))
    p = 0.035
    for sx in (-1, 1):
        for sy in (-1, 1):
            x, yy = cx + sx * (half - p / 2), gy + sy * (half - p / 2)
            box(m, (x - p / 2, yy - p / 2, z0), (x + p / 2, yy + p / 2, z1), "brass", r=0.0)
    turned(m, [(0.05, z0 + 0.03), (0.08, z0 + 0.08), (0.08, z1 - 0.08), (0.05, z1 - 0.03)], 16, "glass",
           at=(cx, gy, 0.0))
    # (The lenses, each held top and bottom by a bar from post to post.)
    lz0, lz1, lh, t = gz - 0.06, gz + 0.06, 0.06, 0.025
    for side in (-1, 1):
        f = gy + side * (half - t / 2)
        box(m, (cx - lh, f - t / 2, lz0), (cx + lh, f + t / 2, lz1), "obsidian", r=0.0)
        g = cx + side * (half - t / 2)
        box(m, (g - t / 2, gy - lh, lz0), (g + t / 2, gy + lh, lz1), "obsidian", r=0.0)
        for z in (lz0 - 0.012, lz1 + 0.012):
            pipe(m, [(cx - half + p, f, z), (cx + half - p, f, z)], 0.012, 6, "brass")
            pipe(m, [(g, gy - half + p, z), (g, gy + half - p, z)], 0.012, 6, "brass")


def _talavera(m, cx, broken):
    """The Talavera under a window: a cobalt border round a cream field, yellow at its heart, set in mortar in a chiluca
    frame; `broken`, two tiles kicked out of its foot, the Company's plank nailed over the hole."""
    front = -DEPTH
    cols, rows = TILE_GRID
    pitch = TILE_WIDE / cols
    x0 = cx - TILE_WIDE / 2
    box(m, (x0, front, TILES[0]), (x0 + TILE_WIDE, front + INSET, TILES[1]), "mortar", r=0.0)
    gap = 0.003
    for i in range(cols):
        for j in range(rows):
            if broken and j == 0 and i in (5, 6):
                continue
            border = i in (0, cols - 1) or j in (0, rows - 1)
            heart = j in (1, 2) and i in (cols // 2 - 1, cols // 2 + 1) or j in (1, 2) and i == cols // 2 and j == 1
            slot = "talavera_cobalt" if border else "talavera_yellow" if heart else "talavera_glaze"
            a, b = x0 + i * pitch + gap, TILES[0] + j * pitch + gap
            box(m, (a, front - 0.04, b), (a + pitch - 2 * gap, front, b + pitch - 2 * gap), slot, r=0.0)
    w = 0.05
    fy0, fy1 = front - 0.08, front + INSET
    box(m, (x0 - w, fy0, TILES[0] - w), (x0 + TILE_WIDE + w, fy1, TILES[0]), "chiluca", r=0.0)
    box(m, (x0 - w, fy0, TILES[1]), (x0 + TILE_WIDE + w, fy1, TILES[1] + w), "chiluca", r=0.0)
    for a, b in ((x0 - w, x0), (x0 + TILE_WIDE, x0 + TILE_WIDE + w)):
        box(m, (a, fy0, TILES[0]), (b, fy1, TILES[1]), "chiluca", r=0.0)
    if broken:
        px0, px1 = x0 + 4.6 * pitch, x0 + 7.4 * pitch
        pz0, pz1 = TILES[0] + 0.03, TILES[0] + pitch + 0.02
        box(m, (px0, front - 0.08, pz0), (px1, front - 0.04, pz1), "wood", r=0.0)
        for x in (px0 + 0.04, px1 - 0.04):
            for z in (pz0 + 0.035, pz1 - 0.035):
                stud(m, (x, front - 0.08, z), math.pi / 2, 0.0, slot="iron", r=0.019)


def _end_notice(m, x0):
    """The Company's notice on the west end (the user's words), in a chiluca frame."""
    face = x0 + INSET
    ya, yb = -DEPTH + POST + 0.15, -POST - 0.15
    za, zb = 1.0, 2.0
    box(m, (face - SIGN_PROUD[0], ya, za), (face, yb, zb), "sign", r=0.0)
    w = 0.05
    fx = face - SIGN_PROUD[1]
    box(m, (fx, ya - w, za - w), (face, yb + w, za), "chiluca", r=0.0)
    box(m, (fx, ya - w, zb), (face, yb + w, zb + w), "chiluca", r=0.0)
    for a, b in ((ya - w, ya), (yb, yb + w)):
        box(m, (fx, a, za), (face, b, zb), "chiluca", r=0.0)


def booth(m, count):
    L = length(count)
    x0, x1 = -L / 2, L / 2
    front = -DEPTH
    xs = window_xs(count)
    underground_shapes.rng = random.Random(count)
    path = [(x0, 0.0), (x0, front), (x1, front), (x1, 0.0)]

    # The tezontle plinth under it all, round the front and both ends.
    m.shell()
    _sweep(m, [(-WALL, 0.0), (PLINTH[1], 0.0), (PLINTH[1], PLINTH[0] - 0.05), (0.0, PLINTH[0]), (-WALL, PLINTH[0])],
           path, "tezontle")
    # The corner posts and the back posts against the wall, from the plinth to the frieze.
    for px in (x0, x1 - POST):
        box(m, (px, front, PLINTH[0]), (px + POST, front + POST, WINDOW[1]), "wood", r=0.04)
        box(m, (px, -POST, PLINTH[0]), (px + POST, 0.0, WINDOW[1]), "wood", r=0.04)
    # The piers between the windows, on the counter, an estípite before each.
    for k in range(count - 1):
        px = xs[k] + WINDOW[0] / 2
        box(m, (px, front, COUNTER), (px + PIER, front + WALL, WINDOW[1]), "wood", r=0.0)
        _estipite(m, px)
    # The front's wall under the counter, set back between the corner posts; Talavera under each window.
    box(m, (x0 + POST, front + INSET, PLINTH[0]), (x1 - POST, front + INSET + WALL, COUNTER - COUNTER_THICK), "wood",
        r=0.0)
    for k, cx in enumerate(xs):
        _talavera(m, cx, broken=k == count - 1)
    # The ends' walls between their posts, set back: the Company's notice on the west, the door in the east.
    box(m, (x0 + INSET, front + POST, PLINTH[0]), (x0 + INSET + WALL, -POST, WINDOW[1]), "wood", r=0.0)
    _end_notice(m, x0)
    wx = x1 - INSET - WALL
    d0, d1 = -POST - DOOR[0], -POST
    box(m, (wx, front + POST, PLINTH[0]), (wx + WALL, d0, WINDOW[1]), "wood", r=0.0)
    box(m, (wx, d0, PLINTH[0] + DOOR[1]), (wx + WALL, d1, WINDOW[1]), "wood", r=0.0)
    # (The door: its leaf set back in its casing, two panels on it, a brass knob, the Company's hasp and padlock.)
    box(m, (wx + 0.03, d0, PLINTH[0]), (wx + 0.07, d1, PLINTH[0] + DOOR[1]), "wood", r=0.0)
    box(m, (x1 - INSET, d0 - 0.06, PLINTH[0]), (x1 + 0.02, d0, PLINTH[0] + DOOR[1] + 0.06), "wood", r=0.012)
    box(m, (x1 - INSET, d0, PLINTH[0] + DOOR[1]), (x1 + 0.02, d1, PLINTH[0] + DOOR[1] + 0.06), "wood", r=0.012)
    leaf = wx + 0.07
    for z0, z1 in ((0.12, 0.78), (1.12, 1.72)):
        box(m, (leaf - 0.005, d0 + 0.15, PLINTH[0] + z0), (leaf + 0.035, d1 - 0.1, PLINTH[0] + z1), "wood", r=0.019)
    turned(m, [(0.03, 0.0), (0.03, 0.03), (0.04, 0.06), (0.0, 0.075)], 14, "brass",
           at=(leaf, d0 + 0.08, PLINTH[0] + 0.95), lean=-math.pi / 2, towards=-math.pi / 2)
    box(m, (leaf, d0 + 0.05, PLINTH[0] + 1.0), (leaf + 0.04, d0 + 0.22, PLINTH[0] + 1.07), "iron", r=0.0)
    box(m, (leaf + 0.01, d0 + 0.13, PLINTH[0] + 0.91), (leaf + 0.08, d0 + 0.21, PLINTH[0] + 1.0), "iron", r=0.019)

    # The counter along the front, the dishes' holes in it.
    holes = [(cx - DISH[0] + 0.02, cx + DISH[0] - 0.02, front + BARS_AT - DISH[1], front + BARS_AT + DISH[2])
             for cx in xs]
    _counter(m, x0 + POST, x1 - POST, holes)
    for cx in xs:
        _window(m, cx)
        _sign(m, cx)
        _ward_lamp(m, cx)

    # The chiluca frieze round the front and ends, the fret along its face, the stepped crown over it, the crest over
    # the middle; the roof inside.
    m.shell()
    _sweep(m, [(-WALL, WINDOW[1]), (0.0, WINDOW[1]), (0.0, FRIEZE), (-WALL, FRIEZE)], path, "chiluca")
    _fret(m, x0 + 0.1, x1 - 0.1, lambda a, b, z0, z1: box(m, (a, front - FRET_PROUD, z0), (b, front, z1), "chiluca",
                                                          r=0.0))
    _fret(m, front + 0.1, -0.1, lambda a, b, z0, z1: box(m, (x0 - FRET_PROUD, a, z0), (x0, b, z1), "chiluca", r=0.0))
    _fret(m, front + 0.1, -0.1, lambda a, b, z0, z1: box(m, (x1, a, z0), (x1 + FRET_PROUD, b, z1), "chiluca", r=0.0))
    crown = [(-WALL, CROWN[0][0]), (0.0, CROWN[0][0]), (CROWN[0][2], CROWN[0][0] + 0.04)]
    for i, (z0, z1, out) in enumerate(CROWN):
        crown += [(out, z1)] + ([(CROWN[i + 1][2], z1)] if i + 1 < len(CROWN) else [])
    crown += [(-WALL, TOP)]
    m.shell()
    _sweep(m, crown, path, "chiluca")
    box(m, (x0 + WALL, front + WALL, FRIEZE), (x1 - WALL, 0.0, TOP), "wood", r=0.0)
    _crest(m)
    # (The conduit feeding the lamps along the crown's top and back to the wall at the east end.)
    pipe(m, [(x0 + 0.15, front + 0.12, TOP + 0.018), (x1 - 0.15, front + 0.12, TOP + 0.018),
             (x1 - 0.15, 0.0, TOP + 0.018)], 0.018, 8, "iron")

    # Inside: the seller's floor, the back boards, the desk's rack and stool at each window, the seller's own things.
    box(m, (x0 + INSET + WALL, front + INSET + WALL, 0.0), (x1 - INSET - WALL, -BOARDS, FLOOR), "wood", r=0.0)
    box(m, (x0 + POST, -BOARDS, 0.0), (x1 - POST, 0.0, FRIEZE), "wood", r=0.0)
    for k, cx in enumerate(xs):
        _rack(m, cx)
        _stool(m, cx - 0.25, front + 1.0)
        _desk(m, cx, k)
    _keepsakes(m, xs[0])


def _rack(m, cx):
    """The ticket rack on the back boards behind a window: pigeonholes of the day's tickets."""
    w, z0, z1, d, t = 0.7, 1.2, 1.9, 0.26, 0.035
    y1 = -BOARDS
    y0 = y1 - d
    for x in (cx - w / 2, cx + w / 2 - t):
        box(m, (x, y0, z0), (x + t, y1, z1), "wood", r=0.0)
    rows, cols = 4, 4
    shelf = [z0 + (z1 - z0 - t) * k / rows for k in range(rows + 1)]
    for z in shelf:
        box(m, (cx - w / 2 + t, y0, z), (cx + w / 2 - t, y1, z + t), "wood", r=0.0)
    for k in range(1, cols):
        x = cx - w / 2 + t + (w - 2 * t) * k / cols
        box(m, (x - 0.01, y0 + 0.04, z0 + t), (x + 0.01, y1, z1 - t), "wood", r=0.0)
    rng = random.Random(int(cx * 100))
    for row in range(rows):
        for col in range(cols):
            if rng.random() < 0.25:
                continue
            x = cx - w / 2 + t + (w - 2 * t) * (col + 0.5) / cols
            h = rng.uniform(0.05, 0.11)
            box(m, (x - 0.05, y0 + 0.05, shelf[row] + t), (x + 0.05, y0 + 0.11, shelf[row] + t + h), "paper", r=0.0)


def _desk(m, cx, k):
    """What the seller keeps on the desk behind a window: the Company's cash box, the next rolls of tickets."""
    y0 = -DEPTH + BARS_AT + DISH[2] + 0.06
    x = cx + (0.3 if k % 2 == 0 else -0.55)
    box(m, (x, y0, COUNTER), (x + 0.28, y0 + 0.2, COUNTER + 0.12), "iron", r=0.019)
    box(m, (x + 0.09, y0 - 0.035, COUNTER + 0.06), (x + 0.19, y0 + 0.02, COUNTER + 0.095), "brass", r=0.0)
    for j in range(2 + k % 2):
        turned(m, [(0.045, 0.0), (0.045, 0.06)], 14, "paper", at=(cx - 0.35 + 0.11 * j + (0.85 if k % 2 else 0.0),
                                                                    y0 + 0.12, COUNTER))


def _keepsakes(m, cx):
    """The seller's own things at the first window: a saint's card on the boards beside the rack, marigolds in a tin
    on the desk."""
    box(m, (cx + 0.42, -BOARDS - 0.035, 1.45), (cx + 0.6, -BOARDS, 1.71), "print_saint", r=0.0)
    y = -DEPTH + BARS_AT + DISH[2] + 0.16
    x = cx - 0.6
    turned(m, [(0.05, 0.0), (0.05, 0.11)], 14, "tin", at=(x, y, COUNTER))
    for dx, dy, dz in ((0.0, 0.0, 0.16), (0.04, 0.02, 0.13), (-0.035, 0.025, 0.14), (0.01, -0.04, 0.12)):
        turned(m, [(0.02, -0.03), (0.035, -0.012), (0.035, 0.012), (0.02, 0.03)], 12, "marigold",
               at=(x + dx, y + dy, COUNTER + dz))


def _stool(m, x, y):
    """The seller's stool, worn."""
    seat = FLOOR + 0.62
    turned(m, [(0.17, seat - 0.04), (0.17, seat)], 12, "wood", at=(x, y, 0.0))
    for k in range(3):
        a = 2 * math.pi * k / 3 + 0.4
        pipe(m, [(x + math.cos(a) * 0.1, y + math.sin(a) * 0.1, seat - 0.04),
                 (x + math.cos(a) * 0.17, y + math.sin(a) * 0.17, FLOOR)], 0.018, 8, "wood")


def taquilla_east(m):
    booth(m, WINDOWS["taquilla_east"])


def taquilla_west(m):
    booth(m, WINDOWS["taquilla_west"])


PIECES = [("taquilla_east", taquilla_east), ("taquilla_west", taquilla_west)]

BUDGET = {n: 40000 for n, _ in PIECES}
SLIVER = {n: 0.004 for n, _ in PIECES}


def build():
    common.reset()
    for name, f in PIECES:
        smooth_object(name, f)


def main():
    build()
    common.export_piece(NAME, ATLAS, SLOTS, out=common.ROOT / "assets" / "eclipse" / "kit", sets_each=True,
                        budget=max(BUDGET.values()), sliver=min(SLIVER.values()), pack_margin=0.0015)


if __name__ == "__main__":
    main()
