"""The city's Iberian buildings (kit v1): the Ribeira's tall narrow houses
(after Porto's riverfront: fronts tiled or washed inside granite frames,
iron balconies laddering up them, Spanish tiles on low roofs) over their
granite arcade; the Terreiro's arcaded bays (after Lisbon's Praca do
Comercio, its yellow and stone) and their corner; the columns at its water
stair; granite flights for the Guindais stair; the king on his horse; a
wall shrine. Pure data, as kit_recipes (which imports this at its end).

A house (casa_a .. casa_h) stands on the quay: its pivot the middle of its
footprint on the ground, its front to +z. Its first storey starts over the
arcade (GROUND), the arcade piece (arcade_ribeira_6) standing under its
front (ARCADE deep) before its ground floor. Its balconies are the thief's
ladder in the rules' measure (each a hang from the one under it), but the
controller cannot climb a stack of them (the one over you is your ceiling,
and a hang leap reaches 1.2 m): casa_d's old vine up its front beside them is
the climb to its eaves. Their iron rails are drawn only (a rail's bar is no
lip to hang from).
"""

import math

import geo
import kit_houses
import kit_recipes as k
import kit_shapes as ks

WIDTH = 6.0
DEPTH = 14.0
ARCADE = 4.0
GROUND = 3.6
STOREY = 3.0
FRONT = DEPTH / 2.0
# A balcony: its width (a running one crosses the front), its slab's
# thickness, how far it stands out (deeper than Porto's 0.5 m: a thief
# stands on it).
BALCONY = (1.7, 0.15, 0.9)
# Its rails: their handrail's top over its floor, and how thick a collider
# stops a man at them.
RAIL = 0.95
RAIL_THICK = 0.1
RUNNING = 5.0
PITCH = 20.0
CASA_TRIS = 5200
DOOR = (1.2, 2.2)
# Where casa_d's vine climbs its front: up its right windows (its balconies
# are on its left), with room for a climber on its roof clear of the taller
# house beside it.
VINE_X = 1.4
# The wall plate along each eaves (m over the wall's top): hidden under the
# drawn eaves, it covers the roof slab's tilted end.
EAVES_PLATE = 0.3

# The front, after Porto's casa burguesa (docs/superpowers/refs/
# houses_ribeira.md): a skin of tiles or render SKIN thick over the body, its
# face at FACE; two openings WINDOW_X either side of a blank pier, each
# OPENING wide between granite jambs JAMB wide that run through the skin and
# stand a little proud of it, a lintel over with its keystone; the glass
# GLASS, 13 cm back from the face (the frame shallow outside, the deep
# reveal inside). A door's foot is the floor band's top (THRESHOLD over its
# storey's floor), a window's its sill (SILL); their heads HEAD over the
# floor, the top storey's lower (TOP_HEAD) under the cornice.
SKIN = 0.2
FACE = FRONT + 0.05
BODY = FACE - SKIN
WINDOW_X = 1.4
OPENING = 1.0
JAMB = 0.2
LINTEL = 0.3
HEAD = 2.45
TOP_HEAD = 2.15
SILL = 0.9
THRESHOLD = 0.11
GLASS = FACE - 0.13
# The eaves: a granite cornice stepping out three times (CORNICE: its
# courses' bottoms under the wall's top and how far each stands out), on it
# a beirado of canal-tile rows on lime mortar, each lower row further out
# (ROWS: how far each row's mouths stand out, three at the front, two at the
# back). The slopes' canal tiles in section: a channel and a cap every PERIOD
# across, the caps CAP over the channels. Party walls stand PARAPET over the
# slopes at each side, coped in granite.
CORNICE = ((0.55, 0.47, 0.12), (0.47, 0.35, 0.19), (0.35, 0.27, 0.27))
ROWS = (0.47, 0.36, 0.25)
ROW_RISE = 0.1
PERIOD = 0.3
CAP = 0.07
PARAPET = 0.25
TILE_PHOTO = 2.0


def col(cx, cy, cz, sx, sy, sz, yaw=0.0, pitch=0.0, roll=0.0):
    return [cx, cy, cz, sx, sy, sz, "stone", yaw, pitch, roll]


def roof_cols(length, span, rise, y, yaw=0.0):
    """The colliders of a double-pitched roof (`length` along its ridge,
    `span` across its walls, `rise` to the ridge, its walls' top at y): a slab
    under each slope, stopping short of its eaves by what its tilted end would
    stand out past the wall, and a wall plate along each eaves flush with the
    wall, so a climber at the eaves meets an upright face to mantle over
    (the scanner turns a sloped one away). Stood on everywhere it is drawn."""
    half = span / 2.0
    pitch = math.degrees(math.atan2(rise, half))
    slope = math.hypot(half, rise)
    lift = k.ROOF_THICK / 2.0 / math.cos(math.radians(pitch))
    trim = k.ROOF_THICK * math.tan(math.radians(pitch))
    inward, up = trim / 2.0 * math.cos(math.radians(pitch)), trim / 2.0 * math.sin(math.radians(pitch))
    out = []

    for s in (-1.0, 1.0):
        out.append(col(0.0, y + rise / 2.0 + lift + up, s * (half / 2.0 - inward), length, k.ROOF_THICK, slope - trim, 0.0, s * pitch))
        out.append(col(0.0, y + EAVES_PLATE / 2.0, s * (half - 0.1), length, EAVES_PLATE, 0.2))

    return [_turned_col(c, yaw) for c in out] if yaw else out


def _turned_col(c, yaw):
    a = math.radians(yaw)
    x, z = c[0] * math.cos(a) + c[2] * math.sin(a), -c[0] * math.sin(a) + c[2] * math.cos(a)
    return [x, c[1], z, c[3], c[4], c[5], c[6], c[7] + yaw, c[8], c[9]]


def _frame(x, y0, z, w, h, slot="granite"):
    """A granite surround on the front z: jambs and a lintel round an
    opening w x h whose foot is at y0."""
    return [ks.box(x - w / 2.0 - 0.09, y0 + h / 2.0, z + 0.04, 0.18, h, 0.1, slot),
            ks.box(x + w / 2.0 + 0.09, y0 + h / 2.0, z + 0.04, 0.18, h, 0.1, slot),
            ks.box(x, y0 + h + 0.12, z + 0.05, w + 0.44, 0.24, 0.12, slot)]


def _between(z0, z1):
    """A box's centre and depth along z from z0 to z1."""
    return (z0 + z1) / 2.0, z1 - z0


def _opening(x, y0, kind, lit, top, dressing, turn):
    """An opening at x on the storey whose floor is y0: a "door" (onto a
    balcony, or behind a low iron "guard") or a "window" over a granite
    sill. Its jambs, lintel and keystone; its glass (lit or dark) back in
    the reveal, its glazing just in front (a door's casement, a window's
    sashes); `dressing` "shutters" (louvred, folded back on the face) or
    "lattice" (a window's rotula: propped out from its head, shut in the
    reveal, or open, by `turn`). Returns (shapes, foot, head)."""
    head = y0 + (TOP_HEAD if top else HEAD)
    foot = y0 + (SILL if kind == "window" else THRESHOLD)
    h = head - foot
    half = OPENING / 2.0
    out = [ks.card(x, foot + h / 2.0, GLASS, OPENING, h, "glass_lit" if lit else "glass_dark"),
           ks.card(x, foot + h / 2.0, GLASS + 0.01, OPENING, h, "sash" if kind == "window" else "casement")]
    z, d = _between(BODY, FACE + 0.03)

    for s in (-1.0, 1.0):
        out.append(ks.box(x + s * (half + JAMB / 2.0), foot + h / 2.0, z, JAMB, h, d, "granite"))

    z, d = _between(BODY, FACE + 0.04)
    out.append(ks.box(x, head + LINTEL / 2.0, z, OPENING + 2.0 * JAMB + 0.1, LINTEL, d, "granite"))
    z, d = _between(BODY, FACE + 0.06)
    out.append(ks.box(x, head + (LINTEL - 0.04) / 2.0, z, 0.24, LINTEL + 0.04, d, "granite"))

    if kind == "window":
        z, d = _between(BODY, FACE + 0.12)
        out.append(ks.box(x, foot - 0.04, z, OPENING + 0.24, 0.12, d, "granite"))
    elif kind == "guard":
        out.append(ks.card(x, foot + 0.45, FACE - 0.02, OPENING, 0.85, "iron_rail"))
        out.append(ks.box(x, foot + 0.9, FACE - 0.02, OPENING, 0.04, 0.05, "iron"))

    if dressing == "shutters":
        for s in (-1.0, 1.0):
            out.append(ks.card(x + s * (half + JAMB + 0.25), foot + h / 2.0, FACE + 0.02, 0.5, h, "shutters"))
    elif dressing == "lattice" and kind == "window" and turn % 3 == 0:
        a = math.radians(25.0)
        out.append(ks.card(x, head - h / 2.0 * math.cos(a), FACE - 0.03 + h / 2.0 * math.sin(a), OPENING + 0.04, h, "lattice", 0.0, -25.0))
    elif dressing == "lattice" and kind == "window" and turn % 3 == 1:
        out.append(ks.card(x, foot + h / 2.0, FACE - 0.04, OPENING, h, "lattice"))

    return out, foot, head


def _balcony(x, y0, width, carried, wall=FRONT, depth=BALCONY[2]):
    """A balcony at x on the storey whose floor is y0, `width` across, out
    `depth` from the wall at `wall` (the house's front): its
    granite slab, its front edge moulded (a roll over a fillet), granite
    corbels under it (`carried`: the first storey's stands on the arcade);
    iron rails across its front (a panel every 1.7 m at most, the bars
    staying a hand apart) and back to the wall at its ends, a handrail along
    their tops, a post and a finial at each front corner."""
    bt, bd = BALCONY[1], depth
    front = wall + bd
    roll = bt / 2.0 * math.cos(math.pi / 6.0)
    z, d = _between(wall - 0.1, front - roll)
    out = [ks.box(x, y0 - bt / 2.0, z, width, bt, d, "granite"),
           ks.prism(x, y0 - bt / 2.0, front - roll, bt / 2.0, width, 6, "granite", 0.0, 0.0, 90.0)]
    z, d = _between(wall - 0.1, front - 0.12)
    out.append(ks.box(x, y0 - bt - 0.03, z, width - 0.08, 0.06, d, "granite"))

    if carried:
        count = max(2, int(round(width / 1.4)))
        under = y0 - bt - 0.06

        for i in range(count):
            cx = x - width / 2.0 + 0.3 + i * (width - 0.6) / (count - 1)
            z, d = _between(wall - 0.1, wall + 0.54)
            out.append(ks.box(cx, under - 0.06, z, 0.18, 0.12, d, "granite"))
            out.append(ks.ring(cx, under - 0.12, wall, 0.03, 0.4, 0.16, 180.0, 270.0, 3, "granite", 90.0))

    panels = int(math.ceil((width - 0.06) / 1.7))
    span = (width - 0.06) / panels

    for i in range(panels):
        out.append(ks.card(x - (width - 0.06) / 2.0 + span * (i + 0.5), y0 + 0.47, front - 0.03, span, 0.88, "iron_rail"))

    out.append(ks.box(x, y0 + 0.93, front - 0.03, width, 0.04, 0.06, "iron"))

    for s in (-1.0, 1.0):
        end = x + s * (width / 2.0 - 0.03)
        out += [ks.card(end, y0 + 0.47, wall + bd / 2.0, bd - 0.06, 0.88, "iron_rail", 90.0),
                ks.box(end, y0 + 0.93, wall + bd / 2.0, 0.06, 0.04, bd, "iron"),
                ks.box(end, y0 + 0.47, front - 0.03, 0.05, 0.94, 0.05, "iron"),
                ks.prism(end, y0 + 1.02, front - 0.03, 0.05, 0.14, 4, "iron", 45.0, top=0.0)]

    return out


def _rail_cols(x, y0, width, wall=FRONT, depth=BALCONY[2]):
    """What stops a man on a balcony (_balcony's): its rails as colliders,
    across its front and back to the wall at each end, as high as its
    handrail (too thin to hide anything: no occluders)."""
    front, high = wall + depth, RAIL
    out = [col(x, y0 + high / 2.0, front - 0.03, width, high, RAIL_THICK)]

    for s in (-1.0, 1.0):
        out.append(col(x + s * (width / 2.0 - 0.03), y0 + high / 2.0, wall + depth / 2.0, RAIL_THICK, high, depth))

    return out


def _profile(x0, x1):
    """Across x0..x1, where a run of canal tiles' section turns and how
    high it stands there over its channels' bottoms: a channel at every
    PERIOD, a cap between (a quarter, a half and three quarters through)."""
    shape = (0.0, 0.45, 1.0, 0.45)
    step = PERIOD / 4.0
    out = []
    i = int(math.floor(x0 / step))

    while i * step < x1 + 1e-9:
        out.append((i * step, shape[i % 4] * CAP))
        i += 1

    out.append((out[-1][0] + step, shape[i % 4] * CAP))

    def at(x):
        for (a, ha), (b, hb) in zip(out, out[1:]):
            if a - 1e-9 <= x <= b + 1e-9:
                return ha + (hb - ha) * (x - a) / (b - a)

        return 0.0

    return [(x0, at(x0))] + [p for p in out if x0 + 1e-9 < p[0] < x1 - 1e-9] + [(x1, at(x1))]


def _tiles(x0, x1, start, end, up, mouths=False):
    """Canal tiles across x0..x1, their channels' bottoms running from
    `start` to `end` (points at x 0), the caps standing `up` (a unit vector)
    over them: one face per strip of the section, the photo laid along the
    run. `mouths`: each cap's dark open end at `end`."""
    run = geo.sub(end, start)
    length = math.sqrt(geo.dot(run, run))
    out = []
    section = _profile(x0, x1)

    def point(x, h, at):
        return [at[0] + x + up[0] * h, at[1] + up[1] * h, at[2] + up[2] * h]

    for (xa, ha), (xb, hb) in zip(section, section[1:]):
        quad = [point(xa, ha, start), point(xb, hb, start), point(xb, hb, end), point(xa, ha, end)]
        uvs = [[xa / TILE_PHOTO, 0.0], [xb / TILE_PHOTO, 0.0], [xb / TILE_PHOTO, length / TILE_PHOTO], [xa / TILE_PHOTO, length / TILE_PHOTO]]

        if geo.dot(ks._normal(quad), up) < 0.0:
            quad, uvs = quad[::-1], uvs[::-1]

        out.append(ks.polygon(quad, "roof_spanish", uvs=uvs))

    if mouths:
        first = int(math.ceil(x0 / PERIOD))

        while (first + 1) * PERIOD <= x1 + 1e-9:
            a = first * PERIOD
            points = [point(a + PERIOD * f, h * CAP, end) for f, h in ((0.25, 0.0), (0.25, 0.45), (0.5, 1.0), (0.75, 0.45), (0.75, 0.0))]

            if geo.dot(ks._normal(points), run) < 0.0:
                points = points[::-1]

            out.append(ks.polygon(points, "pitch"))
            first += 1

    return out


def _beirado(eaves, s):
    """The eaves along the front (s 1) or the back (-1): the cornice's three
    courses, the beirado's rows of tiles on their mortar (each lower row
    further out, its mouths showing), mortar packed up under the slope's
    last tiles."""
    out = []
    inner = FRONT - 0.15
    rows = ROWS if s > 0 else ROWS[:2]

    for bottom, top, reach in CORNICE:
        z, d = _between(inner, FRONT + reach)
        out.append(ks.box(0.0, eaves - (bottom + top) / 2.0, s * z, WIDTH, bottom - top, d, "granite"))

    bed = eaves - CORNICE[-1][1]

    for i, reach in enumerate(rows):
        y = bed + i * ROW_RISE
        z, d = _between(inner, FRONT + reach - 0.05)
        out.append(ks.box(0.0, y + 0.015, s * z, WIDTH, 0.03, d, "limewash"))
        out += _tiles(-WIDTH / 2.0, WIDTH / 2.0, [0.0, y + 0.03, s * inner], [0.0, y + 0.03, s * (FRONT + reach)], [0.0, 1.0, 0.0], mouths=True)

    top = bed + (len(rows) - 1) * ROW_RISE + 0.03 + CAP
    z, d = _between(inner, FRONT + 0.1)
    lip = eaves + k.ROOF_THICK / math.cos(math.radians(PITCH)) - 0.1 * math.tan(math.radians(PITCH)) - 0.45 * CAP
    out.append(ks.box(0.0, (top + lip) / 2.0, s * z, WIDTH, lip - top, d, "limewash"))
    return out


def _roof(eaves, rise, side):
    """The roof over the walls' top: its canal tiles down both slopes to the
    eaves (their section's middle the slopes' colliders' top), a ridge roll,
    party walls standing PARAPET over the slopes at either side under their
    granite copings."""
    a = math.radians(PITCH)
    lift = k.ROOF_THICK / math.cos(a)
    inside = WIDTH / 2.0 - 0.2
    out = []

    for s in (-1.0, 1.0):
        reach = FRONT + 0.12
        start = [0.0, eaves + lift + rise - 0.45 * CAP, 0.0]
        end = [0.0, eaves + lift + rise - 0.45 * CAP - reach * math.tan(a), s * reach]
        out += _tiles(-inside, inside, start, end, [0.0, math.cos(a), s * math.sin(a)])
        out += _beirado(eaves, s)

    out.append(ks.prism(0.0, eaves + lift + rise + 0.02, 0.0, 0.12, 2.0 * inside, 6, "roof_spanish", 0.0, 0.0, 90.0))
    base = eaves + lift + PARAPET

    for s in (-1.0, 1.0):
        x = s * (WIDTH / 2.0 - 0.1)
        out += [ks.box(x, (eaves + base) / 2.0, 0.0, 0.2, base - eaves, DEPTH, side),
                ks.gable(x, base, 0.0, DEPTH, rise, 0.2, side, 90.0)]

        for t in (-1.0, 1.0):
            out.append(ks.box(x, base + rise / 2.0 + 0.03, t * FRONT / 2.0, 0.28, 0.06, FRONT / math.cos(a) + 0.05, "granite", 0.0, t * PITCH))

    return out


def _tiled_roof(length, span, rise, y, overhang=0.35):
    """A double-pitched roof of canal tiles `length` along x over walls
    `span` apart whose top is at y, `rise` to its ridge: the tiles down both
    slopes (their section's middle the top of its colliders, roof_cols) and
    `overhang` past the walls, their mouths dark along the eaves, a board
    soffit under the overhang, a ridge roll."""
    half = span / 2.0
    a = math.atan2(rise, half)
    lift = k.ROOF_THICK / math.cos(a)
    ridge = y + lift + rise - 0.45 * CAP
    out = []

    for s in (-1.0, 1.0):
        reach = half + overhang
        end = [0.0, ridge - reach * math.tan(a), s * reach]
        out += _tiles(-length / 2.0, length / 2.0, [0.0, ridge, 0.0], end, [0.0, math.cos(a), s * math.sin(a)], mouths=True)
        wall, eave = ridge - half * math.tan(a) - 0.03, end[1] - 0.03
        out.append(ks.slab([[-length / 2.0, wall, s * (half - 0.2)], [length / 2.0, wall, s * (half - 0.2)], [length / 2.0, eave, s * reach],
                            [-length / 2.0, eave, s * reach]], 0.05, "boards", edge="timber", up=(0.0, 1.0, s)))

    out.append(ks.prism(0.0, ridge + 0.45 * CAP + 0.02, 0.0, 0.12, length, 6, "roof_spanish", 0.0, 0.0, 90.0))
    return out


def _vine(eaves):
    """An old vine up a front from the quay to the eaves (up its right
    windows, hanging over the arcade's arch below them): its gnarled trunk,
    mats of our painted ivy, and the climb up it (ending at the eaves, so the
    climber mantles onto the roof)."""
    x = VINE_X
    shapes = [ks.box(x - 0.05, 1.3, FRONT + 0.15, 0.14, 2.6, 0.12, "bark", 0.0, 0.0, 4.0),
              ks.box(x + 0.04, 2.6 + (eaves - 0.5 - 2.6) / 2.0, FRONT + 0.16, 0.11, eaves - 0.5 - 2.6, 0.1, "bark", 0.0, 0.0, -1.5)]
    # (Mats of ivy up it, overlapping a little, the last one up to the
    # cornice however short.)
    mats = int(math.ceil((eaves - 0.45 - 0.8) / 2.8))
    h = (eaves - 0.45 - 0.8 + 0.2 * (mats - 1)) / mats

    for k in range(mats):
        y = 0.8 + k * (h - 0.2)
        shapes.append(ks.card(x + (0.12 if k % 2 else -0.1), y + h / 2.0, FRONT + 0.24, 1.1 - 0.1 * (k % 2), h, "ivy"))

    climb = [x, eaves / 2.0, FRONT + 0.25, 0.7, eaves, 0.5, 0.0]
    return shapes, climb


def casa(storeys, front, side, balconies, lit, chimney=1.0, vine=False, upper="door", dressing=None, pipe=False, oculus=False):
    """A house: `storeys` over the arcade, its front skin `front` (tiles or
    render), its sides and back `side`; balconies "all" (every storey's two)
    or "top" (the top storey's) or "left" (every storey's left one) or
    "running" (one across the front on every storey); `lit` [(storey,
    window 0 or 1)]; the openings off the balconies `upper` ("door": behind
    a low iron guard, or "window": over a sill), `dressing` theirs and the
    balconies' ("shutters", "lattice" or None); the chimney to the left (-1)
    or right; `pipe` a downpipe down its right corner; `oculus` a round window in
    the top storey's pier; `vine` its old vine up its front (the climb to
    its roof). Returns (shapes, colliders, size, eaves, climbs)."""
    height = storeys * STOREY
    eaves = GROUND + height
    rise = FRONT * math.tan(math.radians(PITCH))
    under = eaves - CORNICE[0][0]
    z, d = _between(-FRONT, BODY)
    shapes = [ks.box(0.0, GROUND / 2.0, -ARCADE / 2.0 - 0.0, WIDTH, GROUND, DEPTH - ARCADE, "granite"),
              ks.box(0.0, GROUND + height / 2.0, z, WIDTH, height, d, side)]
    cols = [col(0.0, GROUND / 2.0, -ARCADE / 2.0, WIDTH, GROUND, DEPTH - ARCADE),
            col(0.0, GROUND + height / 2.0, 0.0, WIDTH, height, DEPTH)]

    # The ground floor behind the arcade: its door, a shop's grilled window.
    ground = FRONT - ARCADE
    shapes.append(ks.card(1.3, DOOR[1] / 2.0, ground + 0.02, DOOR[0], DOOR[1], "door_1"))
    shapes += _frame(1.3, 0.0, ground, DOOR[0], DOOR[1])
    shapes.append(ks.card(-1.2, 1.5, ground + 0.02, 1.8, 2.0, "glass_dark"))
    shapes.append(ks.card(-1.2, 1.5, ground + 0.06, 1.8, 2.0, "window_grille"))

    # The front: granite quoins at its corners, its skin's piers between the
    # openings (up to the cornice), a granite band at every floor; each
    # storey's openings, the skin over them (and under a window).
    edge = WINDOW_X + OPENING / 2.0 + JAMB
    z, d = _between(BODY, FACE)

    for s in (-1.0, 1.0):
        qz, qd = _between(BODY, FACE + 0.04)
        shapes.append(ks.box(s * (WIDTH / 2.0 - 0.2), (GROUND + under) / 2.0, qz, 0.4, under - GROUND, qd, "granite"))
        shapes.append(ks.box(s * (WIDTH / 2.0 - 0.4 + edge) / 2.0, (GROUND + under) / 2.0, z, WIDTH / 2.0 - 0.4 - edge, under - GROUND, d, front))

    inner = WINDOW_X - OPENING / 2.0 - JAMB
    shapes.append(ks.box(0.0, (GROUND + under) / 2.0, z, 2.0 * inner, under - GROUND, d, front))

    for storey in range(storeys):
        y0 = GROUND + storey * STOREY
        top = storey == storeys - 1
        bz, bd = _between(BODY, FRONT + 0.13)
        shapes.append(ks.box(0.0, y0 + 0.02, bz, WIDTH, 0.18, bd, "granite"))

        if balconies == "running":
            shapes += _balcony(0.0, y0, RUNNING, storey > 0)
            cols.append(col(0.0, y0 - BALCONY[1] / 2.0, FRONT + BALCONY[2] / 2.0, RUNNING, BALCONY[1], BALCONY[2]))
            cols += _rail_cols(0.0, y0, RUNNING)

        for i, x in enumerate((-WINDOW_X, WINDOW_X)):
            on_balcony = balconies in ("all", "running") or (balconies == "left" and i == 0) or (balconies == "top" and top)
            kind = "door" if on_balcony else ("guard" if upper == "door" else "window")
            more, foot, head = _opening(x, y0, kind, (storey + 1, i) in lit, top, dressing, storey + i)
            shapes += more
            ceiling = under if top else y0 + STOREY

            if ceiling - head - LINTEL > 0.01:
                shapes.append(ks.box(x, (head + LINTEL + ceiling) / 2.0, z, OPENING + 2.0 * JAMB, ceiling - head - LINTEL, d, front))

            if kind == "window":
                shapes.append(ks.box(x, (y0 + foot) / 2.0, z, OPENING + 2.0 * JAMB, foot - y0, d, front))

            if on_balcony and balconies != "running":
                shapes += _balcony(x, y0, BALCONY[0], storey > 0)
                cols.append(col(x, y0 - BALCONY[1] / 2.0, FRONT + BALCONY[2] / 2.0, BALCONY[0], BALCONY[1], BALCONY[2]))
                cols += _rail_cols(x, y0, BALCONY[0])

    if oculus:
        y = eaves - STOREY + 1.55
        shapes += [ks.ring(0.0, y, FACE + 0.02, 0.2, 0.34, 0.08, 0.0, 360.0, 12, "granite"),
                   ks.disc(0.0, y, FACE - 0.04, 0.22, 12, "glass_dark")]

    if pipe:
        x = WIDTH / 2.0 - 0.25
        shapes += [ks.prism(x, (GROUND + under - 0.1) / 2.0, FACE + 0.1, 0.045, under - 0.1 - GROUND, 6, "iron"),
                   ks.box(x, under - 0.1, FACE + 0.12, 0.2, 0.16, 0.18, "iron")]

    # The roof: canal tiles at 20 degrees, its eaves to the quay and the back
    # on their cornices, its party walls to the neighbours; a chimney at the
    # back.
    shapes += _roof(eaves, rise, side)
    cols += roof_cols(WIDTH, DEPTH, rise, eaves)

    top = eaves + rise + 1.0
    shapes += kit_houses._chimney(chimney * 1.8, -FRONT + 1.5, top, side)[:2]
    climbs = []

    if vine:
        more, climb = _vine(eaves)
        shapes += more
        climbs.append(climb)

    return shapes, cols, [WIDTH + 0.4, top + 0.3, 2.0 * (FRONT + BALCONY[2])], eaves, climbs


# The eight: storeys over the arcade, their fronts and sides, which have
# balconies all the way up (or running across), which windows are lit, how
# their other openings are made and dressed.
CASAS = {
    "casa_a": dict(storeys=5, front="azulejo_green", side="render_ochre", balconies="all", lit=[(2, 0), (4, 1)], chimney=1.0, pipe=True),
    "casa_b": dict(storeys=4, front="azulejo_cube", side="whitewash", balconies="top", lit=[(3, 1)], chimney=-1.0, upper="window",
                   dressing="lattice", oculus=True),
    "casa_c": dict(storeys=6, front="azulejo_blue", side="render_salmon", balconies="running", lit=[(1, 1), (5, 0)], chimney=1.0),
    "casa_d": dict(storeys=3, front="render_ochre", side="render_ochre", balconies="left", lit=[(2, 1)], chimney=-1.0, vine=True,
                   dressing="shutters"),
    "casa_e": dict(storeys=5, front="render_salmon", side="render_salmon", balconies="top", lit=[], chimney=1.0, upper="window",
                   dressing="shutters", pipe=True),
    "casa_f": dict(storeys=4, front="render_blue", side="whitewash", balconies="all", lit=[(1, 0), (4, 0)], chimney=-1.0, dressing="shutters"),
    "casa_g": dict(storeys=6, front="whitewash", side="whitewash", balconies="top", lit=[(6, 1)], chimney=1.0, upper="window",
                   dressing="lattice", pipe=True),
    "casa_h": dict(storeys=4, front="azulejo_blue2", side="render_blue", balconies="top", lit=[(2, 0)], chimney=-1.0, oculus=True),
}

for _name, _spec in CASAS.items():
    _shapes, _cols, _size, _eaves, _climbs = casa(**_spec)
    k.piece(_name, "casa", _spec["front"], "stone", [], cols=_cols, size=_size)
    k.model(_name, _shapes)
    k.PIECES[_name]["budget"] = CASA_TRIS
    k.PIECES[_name]["front"] = FRONT
    k.PIECES[_name]["door"] = list(DOOR)
    k.PIECES[_name]["eaves"] = _eaves
    k.PIECES[_name]["climbs"] = _climbs


def _iberian(name, slot, shapes, cols, size, budget=None):
    k.piece(name, "iberian", slot, "stone", [], cols=cols, size=size)
    k.model(name, shapes)

    if budget:
        k.PIECES[name]["budget"] = budget


# The Ribeira's arcade: a bay of low heavy granite (a segmental arch 4.4 m
# wide on piers, 2.6 m to its springing), a barrel vault over the walkway
# behind it. Its pivot is the middle of the walkway (the arch at +z), the
# house's ground floor at its back.

def _arcade():
    width, height, walk = 6.0, GROUND, ARCADE
    arch_z = walk / 2.0 - 0.45
    shapes = ks.arched_wall(width, height, 0.9, 4.4, 2.6, 0.8, 0.0, "granite", z=arch_z)
    span = walk - 0.9
    rise = 0.5
    radius = ((span / 2.0) ** 2 + rise ** 2) / (2.0 * rise)
    crown = 3.4
    spring = math.degrees(math.asin((span / 2.0) / radius))
    walk_mid = (arch_z - 0.45 - walk / 2.0) / 2.0
    shapes.append(ks.ring(0.0, crown - radius, walk_mid, radius, radius + 0.25, width, 90.0 - spring, 90.0 + spring, 4, "granite", 90.0))
    # (Solid over the vault: the house's first floor stands on it.)
    # Its walkway paved (the quay ends at its front).
    shapes.append(ks.box(0.0, -0.1, 0.0, width, 0.2, walk, "granite"))
    cols = [col(-(2.2 + 0.4), height / 2.0, arch_z, 0.8, height, 0.9), col(2.2 + 0.4, height / 2.0, arch_z, 0.8, height, 0.9),
            col(0.0, 3.5, arch_z, 4.4, 0.2, 0.9), col(0.0, 3.5, walk_mid, width, 0.2, span), col(0.0, -0.1, 0.0, width, 0.2, walk)]
    return shapes, cols


_shapes, _cols = _arcade()
_iberian("arcade_ribeira_6", "granite", _shapes, _cols, [6.0, GROUND, ARCADE], budget=600)


# The Terreiro: a bay of its arcade (round arches 6 m high in Lisbon's
# yellow, granite dressings, a walkway 4 m deep, rooms behind; a balconied
# window over each arch, a cornice, a low roof), and the corner where two
# arcades meet. Pivot: the bay's middle on the ground, the arches at +z.

BAY = {"width": 6.0, "arcade": 6.5, "top": 11.0, "depth": 8.0, "walk": 4.0, "opening": 4.0, "spring": 4.0}


def _upper_window(z, y0, width, top):
    """The tall window over a Terreiro arch, on the front z (its storey's
    body set back SKIN behind it, `width` across, up to `top`): the skin
    round it, granite jambs, lintel and keystone, the glass back in its
    reveal under a casement, a balcony before it (its edge moulded, its rails
    and returns; on the band over the arch, without corbels)."""
    w, h = 1.2, 2.6
    foot, head = y0 + 0.1, y0 + 0.1 + h
    half = w / 2.0
    body = z - SKIN
    out = [ks.card(0.0, foot + h / 2.0, z - 0.13, w, h, "glass_dark"),
           ks.card(0.0, foot + h / 2.0, z - 0.12, w, h, "casement")]
    jz, jd = _between(body, z + 0.03)

    for s in (-1.0, 1.0):
        out.append(ks.box(s * (half + JAMB / 2.0), foot + h / 2.0, jz, JAMB, h, jd, "granite"))

    lz, ld = _between(body, z + 0.04)
    out.append(ks.box(0.0, head + LINTEL / 2.0, lz, w + 2.0 * JAMB + 0.1, LINTEL, ld, "granite"))
    kz, kd = _between(body, z + 0.06)
    out.append(ks.box(0.0, head + (LINTEL - 0.04) / 2.0, kz, 0.24, LINTEL + 0.04, kd, "granite"))
    sz, sd = _between(body, z)
    edge = half + JAMB

    for s in (-1.0, 1.0):
        out.append(ks.box(s * (width / 2.0 + edge) / 2.0, (y0 + top) / 2.0, sz, width / 2.0 - edge, top - y0, sd, "render_ochre"))

    out += [ks.box(0.0, (head + LINTEL + top) / 2.0, sz, 2.0 * edge, top - head - LINTEL, sd, "render_ochre"),
            ks.box(0.0, (y0 + foot) / 2.0, sz, 2.0 * edge, foot - y0, sd, "render_ochre")]
    out += _balcony(0.0, y0, 1.8, False, wall=z, depth=0.8)
    return out


def _terreiro_bay():
    b = BAY
    front = b["depth"] / 2.0
    arch_z = front - 0.5
    shapes = ks.arched_wall(b["width"], b["arcade"], 1.0, b["opening"], b["spring"], b["opening"] / 2.0, 0.0, "render_ochre", z=arch_z)
    shapes.append(ks.ring(0.0, b["spring"], front + 0.04, b["opening"] / 2.0, b["opening"] / 2.0 + 0.45, 0.1, 0.0, 180.0, 6, "granite"))

    for s in (-1.0, 1.0):
        shapes.append(ks.box(s * (b["width"] / 2.0 - 0.25), b["top"] / 2.0, front + 0.06, 0.5, b["top"], 0.14, "granite"))
        shapes.append(ks.box(s * (b["opening"] / 2.0 + 0.25), b["spring"] - 0.12, front + 0.06, 0.6, 0.24, 0.16, "granite"))

    upper = b["top"] - b["arcade"]
    back = b["depth"] - b["walk"] - 1.0
    shapes += [ks.box(0.0, b["arcade"] + upper / 2.0, -SKIN / 2.0, b["width"], upper, b["depth"] - SKIN, "render_ochre"),
               ks.box(0.0, b["arcade"] / 2.0, -front + back / 2.0, b["width"], b["arcade"], back, "render_ochre"),
               ks.box(0.0, b["arcade"] - 0.25, arch_z - 0.5 - b["walk"] / 2.0, b["width"], 0.5, b["walk"], "render_ochre"),
               ks.box(0.0, b["top"] - 0.2, front + 0.2, b["width"] + 0.1, 0.4, 0.6, "granite"),
               ks.box(0.0, b["arcade"], front + 0.07, b["width"], 0.2, 0.14, "granite"),
               ks.card(1.4, 1.1, -front + back + 0.02, 1.2, 2.2, "door_2")]
    shapes += _frame(1.4, 0.0, -front + back, 1.2, 2.2)
    shapes += _upper_window(front, b["arcade"], b["width"], b["top"])
    shapes += _tiled_roof(b["width"], b["depth"], 2.0, b["top"])
    walk_mid = arch_z - 0.5 - b["walk"] / 2.0
    cols = [col(-(b["opening"] / 2.0 + (b["width"] - b["opening"]) / 4.0), b["arcade"] / 2.0, arch_z, (b["width"] - b["opening"]) / 2.0,
                b["arcade"], 1.0),
            col(b["opening"] / 2.0 + (b["width"] - b["opening"]) / 4.0, b["arcade"] / 2.0, arch_z, (b["width"] - b["opening"]) / 2.0,
                b["arcade"], 1.0),
            col(0.0, (b["arcade"] + b["spring"] + b["opening"] / 2.0) / 2.0, arch_z, b["opening"], b["arcade"] - b["spring"] - b["opening"] / 2.0, 1.0),
            col(0.0, b["arcade"] + upper / 2.0, 0.0, b["width"], upper, b["depth"]),
            col(0.0, b["arcade"] / 2.0, -front + back / 2.0, b["width"], b["arcade"], back),
            col(0.0, b["arcade"] - 0.25, walk_mid, b["width"], 0.5, b["walk"]),
            col(0.0, b["arcade"] - 0.08, front + 0.4, 1.8, 0.16, 0.8)]
    cols += roof_cols(b["width"], b["depth"], 2.0, b["top"])
    return shapes, cols


def _terreiro_corner():
    """The corner where two arcades meet: arches on +z and on +x, the
    walkway turning the corner behind them, a room in the corner, the
    storey over it all under a gabled roof."""
    b = BAY
    size = 8.0
    half = size / 2.0
    shapes, cols = [], []

    for yaw in (0.0, 90.0):
        shapes += ks.arched_wall(size, b["arcade"], 1.0, b["opening"], b["spring"], b["opening"] / 2.0, 0.0, "render_ochre", z=half - 0.5,
                                 yaw=yaw)
        face = [ks.ring(0.0, b["spring"], half + 0.04, b["opening"] / 2.0, b["opening"] / 2.0 + 0.45, 0.1, 0.0, 180.0, 6, "granite"),
                ks.box(0.0, b["top"] - 0.2, half + 0.2, size + 0.1, 0.4, 0.6, "granite"),
                ks.box(0.0, b["arcade"], half + 0.07, size, 0.2, 0.14, "granite")]
        face += _upper_window(half, b["arcade"], size, b["top"])
        shapes += ks.moved(face, yaw)
        # Piers either side of its arch, the band over it.
        side = (size - b["opening"]) / 2.0

        for s in (-1.0, 1.0):
            centre = ks.moved([ks.box(s * (b["opening"] / 2.0 + side / 2.0), 0.0, half - 0.5, 1.0, 1.0, 1.0, "stone")], yaw)[0]["centre"]
            cols.append(col(centre[0], b["arcade"] / 2.0, centre[2], side, b["arcade"], 1.0, yaw))

        centre = ks.moved([ks.box(0.0, 0.0, half - 0.5, 1.0, 1.0, 1.0, "stone")], yaw)[0]["centre"]
        cols.append(col(centre[0], (b["arcade"] + b["spring"] + b["opening"] / 2.0) / 2.0, centre[2], b["opening"],
                        b["arcade"] - b["spring"] - b["opening"] / 2.0, 1.0, yaw))

    # The corner's granite quoin, the room at the back corner, the ceiling
    # over the turning walkway, the storey over all, a hipped roof.
    shapes.append(ks.box(half - 0.23, b["top"] / 2.0, half - 0.23, 0.54, b["top"], 0.54, "granite"))
    upper = b["top"] - b["arcade"]
    shapes += [ks.box(-half / 2.0, b["arcade"] / 2.0, -half / 2.0, half, b["arcade"], half, "render_ochre"),
               ks.box(-SKIN / 2.0, b["arcade"] + upper / 2.0, -SKIN / 2.0, size - SKIN, upper, size - SKIN, "render_ochre"),
               ks.box(0.0, b["arcade"] - 0.25, 0.0, size, 0.5, size, "render_ochre"),
               ks.gable(-(half - 0.1), b["top"], 0.0, size, 2.2, 0.2, "render_ochre", 90.0),
               ks.gable(half - 0.1, b["top"], 0.0, size, 2.2, 0.2, "render_ochre", 90.0)]
    shapes += _tiled_roof(size, size, 2.2, b["top"])
    cols += [col(-half / 2.0, b["arcade"] / 2.0, -half / 2.0, half, b["arcade"], half),
             col(0.0, b["arcade"] + upper / 2.0, 0.0, size, upper, size),
             col(0.0, b["arcade"] - 0.25, 0.0, size, 0.5, size)]
    cols += roof_cols(size, size, 2.2, b["top"])
    return shapes, cols


_shapes, _cols = _terreiro_bay()
_iberian("terreiro_bay_6", "render_ochre", _shapes, _cols, [BAY["width"] + 0.2, BAY["top"] + 2.4, BAY["depth"] + 1.6], budget=1300)
_shapes, _cols = _terreiro_corner()
_iberian("terreiro_corner", "render_ochre", _shapes, _cols, [9.6, BAY["top"] + 2.4, 9.6], budget=1700)


# The water stair and its two columns (the Cais das Colunas), the granite
# flights of the Guindais stair with their landings and parapets.

def _columns():
    shapes, cols = [], []

    for x in (-7.0, 7.0):
        shapes += [ks.box(x, 0.7, 0.0, 1.6, 1.4, 1.6, "ashlar_gold"), ks.box(x, 1.5, 0.0, 1.3, 0.2, 1.3, "ashlar_gold"),
                   ks.prism(x, 1.6 + 2.5, 0.0, 0.5, 5.0, 8, "ashlar_gold", top=0.44),
                   ks.lathe(x, 6.6, 0.0, [[0.44, 0.0], [0.62, 0.3], [0.62, 0.45]], 8, "ashlar_gold"),
                   ks.box(x, 7.12, 0.0, 1.2, 0.25, 1.2, "ashlar_gold"),
                   ks.lathe(x, 7.25, 0.0, [[0.25, 0.0], [0.35, 0.2], [0.3, 0.45], [0.0, 0.6]], 8, "ashlar_gold")]
        cols += [col(x, 0.8, 0.0, 1.6, 1.6, 1.6), col(x, 4.1, 0.0, 0.9, 5.0, 0.9)]

    return shapes, cols


_shapes, _cols = _columns()
_iberian("cais_colunas", "ashlar_gold", _shapes, _cols, [16.2, 7.9, 1.8], budget=400)

# The water stair: 17 steps of 0.2 down to +z from the square's edge (its
# top step 0.2 under the square) into the sea, solid down to the sea bed.
_steps = 17
_water = [k.box(0.0, (2.3 - 0.2 * i - 1.5) / 2.0, -_steps * k.TREAD / 2.0 + (i + 0.5) * k.TREAD, 20.0, 2.3 - 0.2 * i + 1.5, k.TREAD, "granite")
          for i in range(_steps)]
k.piece("water_stair_20", "iberian", "granite", "stone", _water, size=[20.0, 3.8, _steps * k.TREAD])

# A Guindais flight: 10 risers of 0.2 up to +z from its foot (its pivot), 3 m
# wide, solid 4 m down (the slope it climbs); a landing (its top at the
# pivot) and a parapet along a flight's side.
k.piece("granite_flight_3", "iberian", "granite", "stone",
        [k.box(0.0, ((i + 1) * k.RISER - 4.0) / 2.0, i * k.TREAD + k.TREAD / 2.0, 3.0, (i + 1) * k.RISER + 4.0, k.TREAD, "granite") for i in range(10)],
        size=[3.0, 2.0, 10 * k.TREAD])
k.piece("granite_landing_3", "iberian", "granite", "stone", [k.box(0.0, -2.0, 0.0, 3.0, 4.0, 3.0, "granite")], size=[3.0, 4.0, 3.0])
_rake = math.degrees(math.atan2(2.0, 3.0))
k.piece("granite_parapet_3", "iberian", "granite", "stone",
        [k.box(0.0, 1.0 + 0.55, 1.5, 0.3, 1.1, math.hypot(3.0, 2.0) + 0.1, "granite", 0.0, -_rake, 0.0)], size=[0.3, 3.2, 3.2])


# The king on his horse (bronze) on a stone pedestal; a wall shrine (an
# alminha: a tiled panel of the souls, a niche for a candle).

def _statue():
    shapes = [ks.box(0.0, 1.0, 0.0, 3.2, 2.0, 5.2, "granite"), ks.box(0.0, 2.6, 0.0, 2.6, 1.2, 4.4, "ashlar_gold"),
              ks.box(0.0, 3.35, 0.0, 2.9, 0.3, 4.7, "ashlar_gold"),
              # the horse, walking, its head up
              ks.box(0.0, 5.0, 0.0, 0.8, 0.9, 2.1, "brass"), ks.box(0.0, 5.75, 1.05, 0.45, 1.1, 0.5, "brass", 0.0, -35.0, 0.0),
              ks.box(0.0, 6.2, 1.45, 0.35, 0.35, 0.7, "brass", 0.0, 20.0, 0.0), ks.box(0.0, 5.2, -1.2, 0.2, 0.8, 0.2, "brass", 0.0, 25.0, 0.0)]

    for x, z, lift in ((-0.25, 0.8, 0.3), (0.25, 0.7, 0.0), (-0.25, -0.8, 0.0), (0.25, -0.75, 0.15)):
        shapes.append(ks.prism(x, 3.5 + 0.55 + lift / 2.0, z + lift * 0.5, 0.1, 1.1 - lift, 5, "brass", pitch=lift * 60.0))

    # the king: seated, cloaked, crowned, his sceptre raised
    shapes += [ks.box(0.0, 6.05, -0.1, 0.5, 0.8, 0.4, "brass"), ks.lathe(0.0, 6.45, -0.05, [[0.14, 0.0], [0.16, 0.2], [0.12, 0.3], [0.0, 0.34]], 6, "brass"),
               ks.lathe(0.0, 6.72, -0.05, [[0.15, 0.0], [0.17, 0.12]], 6, "brass", caps=False),
               ks.slab([[-0.35, 6.4, -0.3], [0.35, 6.4, -0.3], [0.5, 5.2, -0.65], [-0.5, 5.2, -0.65]], 0.06, "brass", up=(0.0, 0.3, -1.0)),
               ks.box(0.3, 6.3, 0.15, 0.12, 0.5, 0.12, "brass", 0.0, 40.0, 0.0), ks.prism(0.34, 6.8, 0.4, 0.03, 0.9, 4, "brass", pitch=25.0)]
    return shapes, [col(0.0, 1.75, 0.0, 3.2, 3.5, 5.2)]


def _alminha():
    shapes = [ks.box(0.0, 1.4, 0.0, 1.0, 1.6, 0.25, "ashlar_gold"), ks.card(0.0, 1.45, 0.13, 0.7, 0.9, "azulejo_blue"),
              ks.gable(0.0, 2.2, 0.02, 1.1, 0.35, 0.3, "ashlar_gold"), ks.box(0.0, 0.85, 0.15, 0.8, 0.08, 0.3, "ashlar_gold"),
              ks.prism(0.0, 0.95, 0.18, 0.04, 0.14, 6, "wax")]
    return shapes


_shapes, _cols = _statue()
_iberian("statue_king", "brass", _shapes, _cols, [3.4, 7.2, 5.4], budget=1200)
_iberian("alminha", "ashlar_gold", _alminha(), [], [1.1, 2.6, 0.6], budget=200)
