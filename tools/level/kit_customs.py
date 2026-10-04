"""The customs house on the quay (kit v1), after Lisbon's Casa dos Bicos and
the Manueline of its age: its front of diamond-pointed limestone over a
loggia where the king's beam weighs what is landed (twisted columns,
basket arches, a beamed ceiling); behind the loggia the hall's front, its
door a Manueline portal (twisted colonnettes, a rope archivolt round the
king's arms) between barred windows; rope-framed windows over the loggia,
an armillary sphere over each, an azulejo panel of a caravel, a loading
door under a hoist; a watchtower on its corner (quoins, a balcony to the
harbour, a lookout of twin arches, a tiled pyramid and its sphere);
whitewashed sides with granite quoins, plinth and courses; a hipped roof of
canal tiles, laid strip by strip up to its hips, its beirado along the
eaves. Pure data, as kit_recipes (which imports this at its end).

Its frame (HOUSE): x across its front (east to the shipyard's wall), z out
to the quay, y up from the quay's top; its walls' outer faces at x -12 and
12, z -14 and 14. Each piece is drawn in it and stored about its own middle
(PIECE_AT); the layout puts each at the house's origin plus that.
"""

import math

import geo
import kit_glazing as kg
import kit_iberian as ki
import kit_recipes as k
import kit_shapes as ks

HOUSE = (24.0, 28.0)
X0, X1, Z0, Z1 = -12.0, 12.0, -14.0, 14.0
UP = 4.0
EAVES = 7.5
# Its tower on the front's west corner; its top; its roof's rise.
TOWER = (-12.0, -6.0, 8.0, 14.0)
TOWER_TOP = 14.0
TOWER_RISE = 3.2
# The loggia under the front, the hall's front behind it; the columns
# (their middles along x), their springing, the arches' rise.
LOGGIA = 4.0
HALL_FRONT = Z1 - LOGGIA
COLUMNS = [-1.5, 3.0, 7.5]
BAYS = [-6.0, -1.5, 3.0, 7.5, 12.0]
SPRING = 2.77
ARCH_RISE = 0.8
# The portal (its middle, its door's size), the barred windows beside it.
PORTAL = (3.0, 1.6, 2.6)
BARRED = [-1.5, 7.5]
# Over the loggia: the windows, the azulejo panel, the loading door.
WINDOWS = [-3.75, 0.75, 5.25]
PANEL = (3.0, 2.0, 1.6)
LOADING = (9.75, 1.4, 2.4)
WALL = 0.6
PITCH = 20.0
OVER = 0.4
BRICK = 0.0
# A diamond point's cell (across, up), its stone's face within it, how far
# its point stands out.
BICO = (0.56, 0.4, 0.5, 0.34, 0.12)
# Each piece's middle in the house's frame.
PIECE_AT = {}


def col(cx, cy, cz, sx, sy, sz, yaw=0.0, pitch=0.0, roll=0.0, surface="stone"):
    return [cx, cy, cz, sx, sy, sz, surface, yaw, pitch, roll]


def _piece(name, slot, shapes, cols, middle, size, budget, surface="stone", windows=None):
    """A piece drawn in the house's frame, stored about `middle`; its glazed
    windows' records (kit_glazing) moved with it."""
    offset = (-middle[0], -middle[1], -middle[2])
    k.piece(name, "iberian", slot, surface, [], cols=[[c[0] + offset[0], c[1] + offset[1], c[2] + offset[2]] + c[3:] for c in cols], size=size)
    k.model(name, ks.moved(shapes, 0.0, offset))
    k.PIECES[name]["budget"] = budget
    PIECE_AT[name] = list(middle)

    if windows:
        k.PIECES[name]["windows"] = kg.moved(windows, 0.0, offset)


# Ornament: rope, spheres, points

def _rope(points, radius, slot="rope_lay"):
    """A carved rope along `points` (x, y, z): a six-sided rod between each
    two, its photo a rope's lay."""
    out = []

    for a, b in zip(points, points[1:]):
        d = geo.sub(b, a)
        length = math.sqrt(geo.dot(d, d))

        if length < 1e-6:
            continue

        middle = [(a[i] + b[i]) / 2.0 for i in range(3)]
        yaw = math.degrees(math.atan2(d[0], d[2])) if abs(d[0]) + abs(d[2]) > 1e-9 else 0.0
        tilt = math.degrees(math.atan2(math.hypot(d[0], d[2]), d[1]))
        # (No caps: each rod runs into the next, its ends hidden.)
        out.append(ks.prism(middle[0], middle[1], middle[2], radius, length + radius, 6, slot, yaw, tilt, 0.0, caps=False))

    return out


def _sphere(x, y, z, r, slot="iron"):
    """An armillary sphere: its meridian and its equator and an ecliptic
    hoop, on a short stem."""
    return [ks.ring(x, y, z, r - 0.025, r, 0.03, 0.0, 360.0, 10, slot), ks.ring(x, y, z, r - 0.025, r, 0.03, 0.0, 360.0, 10, slot, 90.0),
            ks.ring(x, y, z, r * 0.92 - 0.025, r * 0.92, 0.03, 0.0, 360.0, 10, slot, 45.0),
            ks.prism(x, y - r - 0.08, z, 0.025, 0.16, 4, slot)]


def _bicos(x0, x1, y0, y1, z, holes):
    """Diamond points over the face at z (looking +z) from x0 to x1, y0 to
    y1, none in `holes` [(x0, x1, y0, y1)]: each a pyramid of four faces."""
    cw, ch, sw, sh, out_ = BICO
    out = []
    cols = int((x1 - x0) / cw)
    rows = int((y1 - y0) / ch)
    ox = x0 + ((x1 - x0) - cols * cw) / 2.0
    oy = y0 + ((y1 - y0) - rows * ch) / 2.0

    for i in range(cols):
        for j in range(rows):
            cx, cy = ox + (i + 0.5) * cw, oy + (j + 0.5) * ch

            if any(h[0] - cw / 2.0 < cx < h[1] + cw / 2.0 and h[2] - ch / 2.0 < cy < h[3] + ch / 2.0 for h in holes):
                continue

            a, b = [cx - sw / 2.0, cy - sh / 2.0, z], [cx + sw / 2.0, cy - sh / 2.0, z]
            c, d = [cx + sw / 2.0, cy + sh / 2.0, z], [cx - sw / 2.0, cy + sh / 2.0, z]
            tip = [cx, cy, z + out_]

            for p, q in ((a, b), (b, c), (c, d), (d, a)):
                out.append(ks.polygon([p, q, tip], "ashlar_gold"))

    return out


def _window(x, sill, z, width=1.0, height=1.7, lit=False, flush=False):
    """A Manueline window in a face at z (looking +z): its round head, a
    carved rope up its jambs and round its head, its sill on a corbel, an
    armillary sphere over it. Glazed through the wall (kit_glazing, the
    caller's) unless `flush`: a casement on the face of a solid body (the
    tower's), lit or dark."""
    r = width / 2.0
    spring = sill + height - r
    out = []

    if flush:
        out = [ks.card(x, sill + (height - r) / 2.0, z + 0.01, width, height - r, "glass_lit" if lit else "glass_dark"),
               ks.card(x, sill + (height - r) / 2.0, z + 0.02, width, height - r, "casement"),
               ks.disc(x, spring, z + 0.008, r, 8, "glass_lit" if lit else "glass_dark")]
    out += _rope([[x - r - 0.08, sill, z + 0.05], [x - r - 0.08, spring, z + 0.05]], 0.07)
    out += _rope([[x + r + 0.08, sill, z + 0.05], [x + r + 0.08, spring, z + 0.05]], 0.07)
    out.append(ks.ring(x, spring, z + 0.05, r + 0.02, r + 0.16, 0.12, 0.0, 180.0, 8, "rope_lay"))
    # (The sill stands out from the face, 1 mm proud of the reveal's.)
    out.append(ks.box(x, sill - 0.06, z + 0.131, width + 0.4, 0.12, 0.26, "granite"))
    out.append(ks.box(x, sill - 0.24, z + 0.05, 0.36, 0.24, 0.16, "granite"))
    out += _sphere(x, spring + r + 0.42, z + 0.1, 0.17)
    return out


# The loggia: columns, arches, its ceiling

def _arch(a0, a1):
    """A basket arch from a0 to a1 (x) springing at SPRING: [(x, y)]."""
    half, middle = (a1 - a0) / 2.0, (a0 + a1) / 2.0
    return [(middle - half * math.cos(math.pi * i / 10), SPRING + ARCH_RISE * math.sin(math.pi * i / 10)) for i in range(11)]


def _loggia():
    shapes, cols = [], []
    front, back = Z1, Z1 - WALL

    for x in COLUMNS:
        shapes += [ks.box(x, 0.15, Z1 - WALL / 2.0, 0.62, 0.3, 0.62, "granite"), ks.prism(x, 0.36, Z1 - WALL / 2.0, 0.28, 0.12, 8, "granite"),
                   ks.prism(x, 1.485, Z1 - WALL / 2.0, 0.22, 2.13, 8, "ashlar_gold"), ks.prism(x, 2.56, Z1 - WALL / 2.0, 0.28, 0.08, 8, "ashlar_gold"),
                   ks.box(x, 2.66, Z1 - WALL / 2.0, 0.66, 0.22, 0.66, "ashlar_gold")]

        # Its twist: two carved strands wound up the shaft, two and a half turns.
        for strand in (0.0, math.pi):
            turns = [[x + 0.22 * math.cos(strand + t * math.tau * 2.5 / 20.0), 0.45 + t * 2.08 / 20.0,
                      Z1 - WALL / 2.0 + 0.22 * math.sin(strand + t * math.tau * 2.5 / 20.0)] for t in range(21)]
            shapes += _rope(turns, 0.06)
        cols.append(col(x, SPRING / 2.0, Z1 - WALL / 2.0, 0.45, SPRING, 0.45))

    # Responds against the tower and the shipyard's wall.
    for x, s in ((BAYS[0], 1.0), (BAYS[-1], -1.0)):
        shapes += [ks.box(x + s * 0.175, SPRING / 2.0, Z1 - WALL / 2.0, 0.35, SPRING, 0.6, "granite"),
                   ks.box(x + s * 0.2, 2.66, Z1 - WALL / 2.0, 0.4, 0.22, 0.66, "ashlar_gold")]
        cols.append(col(x + s * 0.175, SPRING / 2.0, Z1 - WALL / 2.0, 0.35, SPRING, 0.6))

    # The arcade over them: each bay's face, front and back, from its column
    # (or respond) up over its arch; its soffit.
    for i, (b0, b1) in enumerate(zip(BAYS, BAYS[1:])):
        a0 = b0 + (0.35 if i == 0 else 0.33)
        a1 = b1 - (0.35 if i == len(BAYS) - 2 else 0.33)
        arch = _arch(a0, a1)
        outline = [(b0, SPRING), (a0, SPRING)] + arch[1:-1] + [(a1, SPRING), (b1, SPRING), (b1, UP), (b0, UP)]

        for z, look in ((front, 1.0), (back, -1.0)):
            for tri in _triangles(outline):
                pts = [[outline[t][0], outline[t][1], z] for t in tri]

                if ks._normal(pts)[2] * look < 0.0:
                    pts = pts[::-1]

                shapes.append(ks.polygon(pts, "granite"))

        for (x0, y0), (x1, y1) in zip(arch, arch[1:]):
            quad = [[x0, y0, back], [x1, y1, back], [x1, y1, front], [x0, y0, front]]

            if ks._normal(quad)[1] > 0.0:
                quad = quad[::-1]

            shapes.append(ks.polygon(quad, "granite"))

        cols.append(col((b0 + b1) / 2.0, (SPRING + ARCH_RISE + UP) / 2.0, Z1 - WALL / 2.0, b1 - b0, UP - SPRING - ARCH_RISE, WALL))

    # A course over the arcade, under the diamond points.
    # (Deep enough to hide the upper floor's edge behind it.)
    shapes.append(ks.box((BAYS[0] + BAYS[-1]) / 2.0, UP - 0.04, Z1 + 0.07, BAYS[-1] - BAYS[0], 0.34, 0.14, "granite"))
    # Its ceiling: boards on beams running back to the hall.
    shapes.append(ks.box((BAYS[0] + BAYS[-1]) / 2.0, UP - 0.32, (HALL_FRONT + back) / 2.0, BAYS[-1] - BAYS[0], 0.04, back - HALL_FRONT, "boards"))

    for i in range(13):
        x = BAYS[0] + 0.7 + i * (BAYS[-1] - BAYS[0] - 1.4) / 12.0
        shapes.append(ks.box(x, UP - 0.46, (HALL_FRONT + back) / 2.0, 0.18, 0.24, back - HALL_FRONT, "beam"))

    return shapes, cols


def _triangles(outline):
    """A simple polygon's triangles, by ear clipping (indices)."""
    pts = list(outline)
    area = sum(pts[i][0] * pts[(i + 1) % len(pts)][1] - pts[(i + 1) % len(pts)][0] * pts[i][1] for i in range(len(pts)))
    order = list(range(len(pts))) if area > 0.0 else list(reversed(range(len(pts))))
    out = []

    def convex(a, b, c):
        return (b[0] - a[0]) * (c[1] - a[1]) - (b[1] - a[1]) * (c[0] - a[0]) > 1e-9

    def inside(a, b, c, p):
        return convex(a, b, p) and convex(b, c, p) and convex(c, a, p)

    while len(order) > 3:
        for n in range(len(order)):
            i, j, m = order[n - 1], order[n], order[(n + 1) % len(order)]

            if convex(pts[i], pts[j], pts[m]) and not any(inside(pts[i], pts[j], pts[m], pts[q]) for q in order if q not in (i, j, m)):
                out.append([i, j, m])
                order.pop(n)
                break
        else:
            raise ValueError("kit_customs: an outline that will not triangulate")

    out.append(order)
    return out


# The hall's front behind the loggia: the portal, the barred windows

def _portal_wall():
    z0, z1 = HALL_FRONT - WALL, HALL_FRONT
    zc = (z0 + z1) / 2.0
    door_x, door_w, door_h = PORTAL
    sill, head, ww = 1.0, 2.4, 1.0
    # The wall round its barred windows (glazed behind their grilles) and
    # the portal; its colliders split round them, the glass's in each.
    cuts = [kg.hole(x, sill, ww, head - sill) for x in BARRED] + [(door_x - door_w / 2.0, door_x + door_w / 2.0, 0.0, door_h)]
    shapes, cols = kg.strips(BAYS[0], BAYS[-1], 0.0, UP, zc, WALL, cuts, "granite", open=[cuts[-1]])
    records = []

    for x in BARRED:
        glass, glass_cols, record = kg.glazed(x, sill, ww, head - sill, z1, WALL, lead="grille", slot="granite", inner_slot="granite")
        shapes += glass
        cols += glass_cols
        records.append(record)
        shapes += ki._frame(x, sill, z1 + 0.011, ww, head - sill)
        shapes.append(ks.box(x, sill - 0.05, z1 + 0.091, ww + 0.36, 0.1, 0.18, "granite"))

    # The portal: twisted colonnettes on their bases, capitals with a
    # sphere on each, the lintel, the king's arms in the tympanum under a
    # rope archivolt, pinnacles beside it.
    r = 0.6
    for s in (-1.0, 1.0):
        cx = door_x + s * (door_w / 2.0 + 0.14)
        shapes += [ks.box(cx, 0.12, z1 + 0.1, 0.3, 0.24, 0.24, "ashlar_gold"),
                   ks.prism(cx, 0.24 + (door_h - 0.18) / 2.0, z1 + 0.1, 0.09, door_h - 0.18, 6, "rope_lay"),
                   ks.box(cx, door_h + 0.1, z1 + 0.1, 0.3, 0.2, 0.26, "ashlar_gold")]
        shapes += _sphere(cx, door_h + 0.42, z1 + 0.12, 0.12)
        px = door_x + s * (door_w / 2.0 + r + 0.3)
        shapes += [ks.box(px, door_h + 0.15, z1 + 0.06, 0.2, 0.3, 0.14, "ashlar_gold"),
                   ks.prism(px, door_h + 0.55, z1 + 0.06, 0.09, 0.5, 4, "ashlar_gold", 45.0, top=0.0)]

    shapes.append(ks.box(door_x, door_h + 0.12, z1 + 0.06, door_w + 0.2, 0.24, 0.14, "ashlar_gold"))
    shapes.append(ks.disc(door_x, door_h + 0.24, z1 + 0.02, r, 10, "ashlar_gold"))
    shapes.append(ks.card(door_x, door_h + 0.24 + r * 0.42, z1 + 0.06, r * 1.15, r * 1.15, "arms_royal"))
    shapes.append(ks.ring(door_x, door_h + 0.24, z1 + 0.08, r, r + 0.13, 0.12, 0.0, 180.0, 10, "rope_lay"))
    return shapes, cols, records


# Over the loggia: the diamond-pointed front

def _upper_front():
    z0, z1 = Z1 - 0.5, Z1
    zc = (z0 + z1) / 2.0
    lx, lw, lh = LOADING
    x0, x1 = BAYS[0], BAYS[-1]
    sill = UP + 0.6
    wr = 0.5
    head = sill + 1.7
    # The body round its windows (glazed through it: the moon goes in) and
    # the loading door; its colliders split round them, the glass's in each.
    cuts = [kg.hole(x, sill, 2.0 * wr, head - sill) for x in WINDOWS] + [(lx - lw / 2.0, lx + lw / 2.0, UP, UP + lh)]
    shapes, cols = kg.strips(x0, x1, UP, EAVES, zc, 0.5, cuts, "ashlar_gold", open=[cuts[-1]])
    records = []

    for x in WINDOWS:
        glass, glass_cols, record = kg.glazed(x, sill, 2.0 * wr, head - sill, z1, 0.5, shape="round", lead="quarries", slot="ashlar_gold",
                                              inner_slot="ashlar_gold")
        shapes += glass
        cols += glass_cols
        records.append(record)

    holes = [(x - 0.75, x + 0.75, sill - 0.5, sill + 2.4) for x in WINDOWS]
    px, pw, ph = PANEL
    py = UP + 1.6
    holes.append((px - pw / 2.0 - 0.15, px + pw / 2.0 + 0.15, py - ph / 2.0 - 0.15, py + ph / 2.0 + 0.15))
    holes.append((lx - lw / 2.0 - 0.25, lx + lw / 2.0 + 0.25, UP, UP + lh + 0.35))
    shapes += _bicos(x0, x1, UP + 0.2, EAVES - 0.45, z1, holes)

    for i, x in enumerate(WINDOWS):
        shapes += _window(x, sill, z1, lit=i == 1)

    # The azulejos in a granite frame.
    shapes.append(ks.card(px, py, z1 + 0.02, pw, ph, "azulejo_ship"))

    for dx, dy, sx, sy in ((0.0, ph / 2.0 + 0.07, pw + 0.28, 0.14), (0.0, -ph / 2.0 - 0.07, pw + 0.28, 0.14),
                           (pw / 2.0 + 0.07, 0.0, 0.14, ph), (-pw / 2.0 - 0.07, 0.0, 0.14, ph)):
        shapes.append(ks.box(px + dx, py + dy, z1 + 0.05, sx, sy, 0.1, "granite"))

    # The loading door: its frame, its threshold out over the loggia's
    # course, the dark of the store inside, its leaves folded back in.
    # (Its frame stands on the face, 1 mm proud: not in the reveal's plane.)
    shapes += ki._frame(lx, UP, z1 + 0.011, lw, lh)
    shapes.append(ks.box(lx, UP + 0.05, z1 + 0.15, lw + 0.3, 0.1, 0.3, "granite"))
    shapes.append(ks.card(lx, UP + lh / 2.0, z0 + 0.02, lw, lh, "glass_dark"))

    for s in (-1.0, 1.0):
        shapes.append(ks.box(lx + s * (lw / 2.0 - 0.04), UP + lh / 2.0, z0 - 0.3, 0.06, lh, 0.68, "door_1"))

    # The cornice under the eaves.
    for bottom, top, reach in ki.CORNICE:
        shapes.append(ks.box((x0 + x1) / 2.0, EAVES - (bottom + top) / 2.0, z1 + (reach - 0.15) / 2.0, x1 - x0, bottom - top, reach + 0.15, "granite"))

    return shapes, cols, records


# The tower on the front's west corner

def _quoins(x, z, y0, y1, sx, sz):
    """Granite quoins up a corner at (x, z) whose faces look along sx (x)
    and sz (z): long and short stones by turns."""
    out = []
    y = y0
    n = 0

    while y < y1 - 0.2:
        h = min(0.42, y1 - y)
        long_x = n % 2 == 0
        lx, lz = (0.62, 0.36) if long_x else (0.36, 0.62)
        out.append(ks.box(x - sx * lx / 2.0 + sx * 0.03, y + h / 2.0, z - sz * lz / 2.0 + sz * 0.03, lx + 0.06, h - 0.02, lz + 0.06, "granite"))
        y += h
        n += 1

    return out


def _tower():
    x0, x1, z0, z1 = TOWER
    xc, zc = (x0 + x1) / 2.0, (z0 + z1) / 2.0
    w, d = x1 - x0, z1 - z0
    top = TOWER_TOP
    shapes = [ks.box(xc, top / 2.0, zc, w, top, d, "whitewash"), ks.box(xc, 0.3, zc, w + 0.12, 0.6, d + 0.12, "granite")]
    cols = [col(xc, top / 2.0, zc, w, top, d)]

    for y in (UP, EAVES, 10.8):
        shapes.append(ks.box(xc, y, zc, w + 0.14, 0.16, d + 0.14, "granite"))

    for sx, sz in ((-1.0, 1.0), (1.0, 1.0), (-1.0, -1.0)):
        shapes += _quoins(xc + sx * w / 2.0, zc + sz * d / 2.0, 0.6, top, sx, sz)

    # A slit to the quay and one to the lane; a rope-framed window to the
    # harbour over the loggia's floor.
    for face in ("south", "west"):
        if face == "south":
            shapes += ki._frame(xc, 1.4, z1, 0.3, 1.3)
            shapes.append(ks.card(xc, 2.05, z1 + 0.01, 0.3, 1.3, "glass_dark"))
        else:
            slit = ks.moved(ki._frame(0.0, 1.4, 0.0, 0.3, 1.3) + [ks.card(0.0, 2.05, 0.01, 0.3, 1.3, "glass_dark")], -90.0, (x0, 0.0, zc))
            shapes += slit

    shapes += _window(xc, UP + 0.8, z1, flush=True)
    # The lookout: twin arches on each face over the last course, a
    # twisted colonnette between them.
    for yaw, (ox, oz) in ((0.0, (xc, z1)), (180.0, (xc, z0)), (90.0, (x1, zc)), (-90.0, (x0, zc))):
        look = []

        for s in (-1.0, 1.0):
            look.append(ks.card(s * 0.62, 11.95, 0.01, 1.0, 1.7, "glass_dark"))
            look.append(ks.disc(s * 0.62, 12.8, -0.005, 0.5, 8, "glass_dark"))
            look.append(ks.ring(s * 0.62, 12.8, 0.05, 0.5, 0.62, 0.1, 0.0, 180.0, 8, "granite"))
            look.append(ks.box(s * 1.18, 11.95, 0.05, 0.12, 1.7, 0.1, "granite"))

        look.append(ks.prism(0.0, 11.95, 0.06, 0.07, 1.7, 6, "rope_lay"))
        look.append(ks.box(0.0, 11.1, 0.08, 2.6, 0.12, 0.2, "granite"))
        shapes += ks.moved(look, yaw, (ox, 0.0, oz))

    # The balcony to the harbour on its corbels, its iron rail.
    by = 10.88
    shapes.append(ks.box(xc, by, z1 + 0.45, 3.0, 0.16, 0.9, "granite"))

    for s in (-1.0, 0.0, 1.0):
        shapes.append(ks.box(xc + s * 1.2, by - 0.28, z1 + 0.25, 0.22, 0.4, 0.5, "granite"))

    shapes.append(ks.card(xc, by + 0.5, z1 + 0.86, 2.9, 0.85, "iron_rail"))

    for s in (-1.0, 1.0):
        shapes.append(ks.card(xc + s * 1.46, by + 0.5, z1 + 0.45, 0.85, 0.85, "iron_rail", 90.0))

    shapes.append(ks.box(xc, by + 0.95, z1 + 0.88, 3.0, 0.05, 0.06, "iron"))
    cols.append(col(xc, by, z1 + 0.45, 3.0, 0.16, 0.9))
    cols.append(col(xc, by + 0.5, z1 + 0.86, 3.0, 1.0, 0.08))

    # Its cornice, its tiled pyramid, the sphere on its spike.
    for bottom, tp, reach in ki.CORNICE:
        shapes.append(ks.box(xc, top - (bottom + tp) / 2.0, zc, w + 2.0 * reach, bottom - tp, d + 2.0 * reach, "granite"))

    roof, roof_cols = _hipped(x0 - xc, x1 - xc, z0 - zc, z1 - zc, TOWER_RISE / (w / 2.0), 0.35, set())
    shapes += ks.moved(roof, 0.0, (xc, top, zc))
    cols += [[c[0] + xc, c[1] + top, c[2] + zc] + c[3:] for c in roof_cols]
    apex = top + TOWER_RISE + 0.15
    shapes.append(ks.prism(xc, apex + 0.6, zc, 0.04, 1.2, 4, "iron"))
    shapes += _sphere(xc, apex + 1.0, zc, 0.32)
    return shapes, cols


# Sides and back: whitewash, granite plinth, quoins, courses, windows

def _side(length, openings, door=None):
    """A side wall along x from 0 to `length`, its outer face at z 0
    (looking +z), WALL thick back to -WALL, two storeys: `openings` [x]
    (barred below, a casement above), `door` (x) a door on the ground."""
    holes = [h for x in openings for h in (kg.hole(x, 1.2, 0.9, 1.2), kg.hole(x, UP + 0.9, 0.9, 1.5))]

    if door is not None:
        holes.append(kg.hole(door, 0.0, 1.2, 2.2))

    shapes, cols = kg.strips(0.0, length, 0.0, EAVES, -WALL / 2.0, WALL, holes, "whitewash", open=holes[-1:] if door is not None else [])
    shapes.append(ks.box(length / 2.0, UP, 0.06, length, 0.16, 0.12, "granite"))
    records = []

    # The plinth along its foot, broken for the door.
    runs = [(0.0, length)] if door is None else [(0.0, door - 0.6), (door + 0.6, length)]

    for a, b in runs:
        shapes.append(ks.box((a + b) / 2.0, 0.3, 0.05, b - a, 0.6, 0.1, "granite"))

    for x in openings:
        # Barred below, a casement above, both glazed through the wall.
        for sill, height, lead in ((1.2, 1.2, "grille"), (UP + 0.9, 1.5, "casement")):
            glass, glass_cols, record = kg.glazed(x, sill, 0.9, height, 0.0, WALL, lead=lead, slot="whitewash", inner_slot="whitewash")
            shapes += glass
            cols += glass_cols
            records.append(record)

        # (Frames and sills on the face, 1 mm proud: not in the reveals'
        # planes, where they would flicker.)
        shapes += ki._frame(x, 1.2, 0.011, 0.9, 1.2)
        shapes.append(ks.box(x, 1.15, 0.091, 1.2, 0.1, 0.18, "granite"))
        shapes += ki._frame(x, UP + 0.9, 0.011, 0.9, 1.5)
        shapes.append(ks.box(x, UP + 0.85, 0.111, 1.2, 0.1, 0.22, "granite"))

        for s in (-1.0, 1.0):
            shapes.append(ks.card(x + s * 0.72, UP + 1.65, 0.03, 0.45, 1.5, "shutters"))

    if door is not None:
        shapes += ki._frame(door, 0.0, 0.011, 1.2, 2.2)
        shapes.append(ks.box(door, 2.6, 0.08, 1.6, 0.1, 0.18, "granite"))

    return shapes, cols, records


def _west_wall():
    x0, x1, z0, z1 = TOWER
    length = z0 - Z0
    shapes, cols, records = _side(length, [length - 4.0, length - 10.0, length - 16.0])
    # (Turned so its face looks west, from the back's corner to the tower.)
    shapes = ks.moved(shapes, -90.0, (X0, 0.0, Z0))
    cols = [_turned(c, -90.0, (X0, 0.0, Z0)) for c in cols]
    records = kg.moved(records, -90.0, (X0, 0.0, Z0))
    shapes += _quoins(X0, Z0, 0.6, EAVES, -1.0, -1.0)

    for bottom, top, reach in ki.CORNICE:
        shapes.append(ks.box(X0 - (reach - 0.15) / 2.0, EAVES - (bottom + top) / 2.0, (Z0 + z0) / 2.0, reach + 0.15, bottom - top, z0 - Z0, "granite"))

    return shapes, cols, records


def _back_wall():
    length = X1 - X0
    # (Its door at x 8: turned, the side's x runs back from the east.)
    shapes, cols, records = _side(length, [6.0, 12.0, 18.0], door=X1 - 8.0)
    shapes = ks.moved(shapes, 180.0, (X1, 0.0, Z0))
    cols = [_turned(c, 180.0, (X1, 0.0, Z0)) for c in cols]
    records = kg.moved(records, 180.0, (X1, 0.0, Z0))

    for bottom, top, reach in ki.CORNICE:
        shapes.append(ks.box(0.0, EAVES - (bottom + top) / 2.0, Z0 - (reach - 0.15) / 2.0, length, bottom - top, reach + 0.15, "granite"))

    return shapes, cols, records


def _turned(c, yaw, offset):
    centre = geo.add(geo.apply(geo.rotation(yaw), c[0:3]), list(offset))
    return [centre[0], centre[1], centre[2]] + c[3:7] + [c[7] + yaw if len(c) > 7 else yaw] + list(c[8:10] if len(c) > 9 else [0.0, 0.0])


# The roof: hipped, of canal tiles laid strip by strip up to its hips

def _hipped(x0, x1, z0, z1, slope, over, skip, east_over=None):
    """A hipped roof over the walls x0..x1, z0..z1 (their tops at y 0),
    rising `slope` (rise over run) to its ridge (or apex), `over` past the
    walls (east `east_over`): each slope's canal tiles strip by strip from
    its eaves up to where its hips (or the ridge) stop it, their mouths
    along the eaves; the rolls along the hips and the ridge; a collider
    row by row up each slope. `skip`: (side, lateral from, to) strips
    left out (where a tower stands in it)."""
    shapes, cols = [], []
    pitch = math.atan(slope)
    half = min(x1 - x0, z1 - z0) / 2.0
    base = 0.12
    east_over = over if east_over is None else east_over
    sides = {
        # side: (outward (x, z), lateral axis (x, z), the wall line, its lateral extent, its overhang)
        "south": ((0.0, 1.0), (1.0, 0.0), z1, (x0, x1), over),
        "north": ((0.0, -1.0), (-1.0, 0.0), -z0, (-x1, -x0), over),
        "west": ((-1.0, 0.0), (0.0, 1.0), -x0, (z0, z1), over),
        "east": ((1.0, 0.0), (0.0, -1.0), x1, (-z1, -z0), east_over),
    }
    up = math.cos(pitch)
    out_ = math.sin(pitch)

    for side, (n, t, wall, (t0, t1), o) in sides.items():
        def at(u, dd, h, n=n, t=t, wall=wall):
            # (u along the eaves, dd in from the wall line, h off the slope.)
            plan = [n[0] * (wall - dd) + t[0] * u, n[1] * (wall - dd) + t[1] * u]
            return [plan[0] + n[0] * out_ * h, base + dd * slope + up * h, plan[1] + n[1] * out_ * h]

        def reach(u, t0=t0, t1=t1):
            return min(u - t0, t1 - u, half)

        section = ki._profile(t0 - o, t1 + o)
        normal = [n[0] * out_, up, n[1] * out_]

        for (ua, ha), (ub, hb) in zip(section, section[1:]):
            if any(s == side and lo <= (ua + ub) / 2.0 <= hi for s, lo, hi in skip):
                continue

            ra, rb = reach(ua), reach(ub)

            if ra <= -o + 1e-6 and rb <= -o + 1e-6:
                continue

            ra, rb = max(ra, -o), max(rb, -o)
            quad = [at(ua, -o, ha), at(ub, -o, hb), at(ub, rb, hb), at(ua, ra, ha)]
            length = (ra + o) / math.cos(pitch)
            lb = (rb + o) / math.cos(pitch)
            uvs = [[ua / ki.TILE_PHOTO, 0.0], [ub / ki.TILE_PHOTO, 0.0], [ub / ki.TILE_PHOTO, lb / ki.TILE_PHOTO],
                   [ua / ki.TILE_PHOTO, length / ki.TILE_PHOTO]]

            if geo.dot(ks._normal(quad), normal) < 0.0:
                quad, uvs = quad[::-1], uvs[::-1]

            shapes.append(ks.polygon(quad, "roof_spanish", uvs=uvs))

            # Its mouth along the eaves, where a cap stands.
            if ha > 0.5 * ki.CAP and o > 0.0:
                mouth = [at(ua, -o, 0.0), at(ub, -o, 0.0), at((ua + ub) / 2.0, -o, max(ha, hb))]

                if geo.dot(ks._normal(mouth), [n[0], 0.0, n[1]]) < 0.0:
                    mouth = mouth[::-1]

                shapes.append(ks.polygon(mouth, "pitch"))

        # Its colliders: rows up the slope, each as wide as its top edge.
        rows = 4

        for r in range(rows):
            d0 = -o + (half + o) * r / rows
            d1 = -o + (half + o) * (r + 1) / rows
            lo, hi = t0 + max(d1, 0.0), t1 - max(d1, 0.0)

            if hi - lo < 0.3:
                continue

            for s, a, b in skip:
                if s == side:
                    lo = max(lo, b) if a <= lo else lo
                    hi = min(hi, a) if b >= hi else hi

            if hi - lo < 0.3:
                continue

            mid = at((lo + hi) / 2.0, (d0 + d1) / 2.0, 0.0)
            run = (d1 - d0) / math.cos(pitch)
            depth = 0.3
            centre = [mid[0] - normal[0] * depth / 2.0, mid[1] - normal[1] * depth / 2.0, mid[2] - normal[2] * depth / 2.0]
            yaw = math.degrees(math.atan2(n[0], n[1]))
            # (Its run out along the slope's fall: pitched down by the slope.)
            cols.append(col(centre[0], centre[1], centre[2], hi - lo, depth, run, yaw, math.degrees(pitch)))

    # The hips and the ridge.
    ridge_y = base + half * slope + 0.45 * ki.CAP
    rx0, rx1 = (x0 + half, x1 - half) if (x1 - x0) >= (z1 - z0) else ((x0 + x1) / 2.0, (x0 + x1) / 2.0)
    rz0, rz1 = ((z0 + z1) / 2.0, (z0 + z1) / 2.0) if (x1 - x0) >= (z1 - z0) else (z0 + half, z1 - half)

    for (cx, cz), (ex, ez) in (((x0 - over, z1 + over), (rx0, rz1)), ((x1 + east_over, z1 + over), (rx1, rz1)),
                               ((x0 - over, z0 - over), (rx0, rz0)), ((x1 + east_over, z0 - over), (rx1, rz0))):
        start = [cx, base - over * slope + 0.45 * ki.CAP, cz]
        end = [ex, ridge_y, ez]

        for s, a, b in skip:
            # (A hip running into the tower starts where it leaves it.)
            if s == "hip" and abs(cx - a) < 1e-6 and abs(cz - b) < 1e-6:
                f = 0.5
                start = [cx + (ex - cx) * f, start[1] + (end[1] - start[1]) * f, cz + (ez - cz) * f]

        shapes += _rope([start, end], 0.11, "roof_spanish")

    if abs(rx1 - rx0) + abs(rz1 - rz0) > 1e-6:
        shapes += _rope([[rx0, ridge_y, rz0], [rx1, ridge_y, rz1]], 0.11, "roof_spanish")

    return shapes, cols


def _roof():
    x0, x1, z0, z1 = TOWER
    skip = {("south", X0 - OVER, x1), ("west", z0, Z1 + OVER), ("hip", X0 - OVER, Z1 + OVER)}
    shapes, cols = _hipped(X0, X1, Z0, Z1, math.tan(math.radians(PITCH)), OVER, skip, east_over=0.0)
    shapes = ks.moved(shapes, 0.0, (0.0, EAVES, 0.0))
    cols = [[c[0], c[1] + EAVES, c[2]] + c[3:] for c in cols]
    # The ceiling under it over the upper floor (the tower solid in its
    # corner): boards on the roof's tie beams; it stops what is thrown.
    for bx0, bx1, bz0, bz1 in ((X0, X1, Z0, z0), (x1, X1, z0, Z1)):
        shapes.append(ks.box((bx0 + bx1) / 2.0, EAVES - 0.03, (bz0 + bz1) / 2.0, bx1 - bx0, 0.06, bz1 - bz0, "boards"))
        cols.append(col((bx0 + bx1) / 2.0, EAVES + 0.05, (bz0 + bz1) / 2.0, bx1 - bx0, 0.1, bz1 - bz0, surface="ceiling"))

    for i in range(7):
        z = Z0 + 2.0 + i * 4.0
        shapes.append(ks.box(0.0 if z < z0 else (x1 + X1) / 2.0, EAVES - 0.16, z, X1 - X0 if z < z0 else X1 - x1, 0.22, 0.2, "beam"))

    # Two chimneys on the west slope, their cone caps.
    for z in (-6.0, 4.0):
        cx = X0 + 3.2
        shapes += [ks.box(cx, EAVES + 2.1, z, 0.8, 2.8, 0.8, "whitewash"), ks.box(cx, EAVES + 3.55, z, 1.0, 0.1, 1.0, "granite"),
                   ks.prism(cx, EAVES + 4.05, z, 0.45, 0.9, 4, "whitewash", 45.0, top=0.0)]
        cols.append(col(cx, EAVES + 2.1, z, 0.8, 2.8, 0.8))

    return shapes, cols


# A flight up the west wall inside: twenty risers of 0.2 to the upper floor

STAIR = (20, 0.2, 0.28, 1.3)


def _stair():
    n, rise, tread, width = STAIR
    shapes = [ks.box(0.0, rise * (i + 1) / 2.0, tread * i + tread / 2.0 - n * tread / 2.0, width, rise * (i + 1), tread, "granite") for i in range(n)]
    cols = [col(c["centre"][0], c["centre"][1], c["centre"][2], *c["size"]) for c in shapes]
    # Its balustrade on its open side: a granite rail on the slope.
    run = n * tread
    shapes.append(ks.slab([[width / 2.0 - 0.08, rise + 0.9, -run / 2.0], [width / 2.0 + 0.08, rise + 0.9, -run / 2.0],
                           [width / 2.0 + 0.08, n * rise + 0.9, run / 2.0], [width / 2.0 - 0.08, n * rise + 0.9, run / 2.0]], 0.12, "granite"))

    for i in range(0, n, 4):
        shapes.append(ks.box(width / 2.0, rise * (i + 1) + 0.45, tread * i + tread / 2.0 - run / 2.0, 0.12, 0.9, 0.12, "granite"))

    return shapes, cols


# The king's beam in the loggia, the hoist over the loading door

def _kings_beam():
    hang = UP - 0.5
    arm = 2.6
    shapes = [ks.box(0.0, hang - 0.4, 0.0, 0.05, 0.8, 0.05, "iron"), ks.box(0.0, hang - 0.85, 0.0, arm, 0.1, 0.12, "iron"),
              ks.prism(0.0, hang - 0.62, 0.0, 0.03, 0.4, 4, "brass")]

    for s in (-1.0, 1.0):
        x = s * (arm / 2.0 - 0.06)

        for a in (0.0, 120.0, 240.0):
            dx, dz = 0.3 * math.cos(math.radians(a)), 0.3 * math.sin(math.radians(a))
            shapes.append(ks.box(x + dx / 2.0, (hang - 0.85 + 1.0) / 2.0, dz / 2.0, 0.015, hang - 1.85, 0.015, "iron", 0.0, 0.0,
                                 math.degrees(math.atan2(dx, hang - 1.85))))

        shapes.append(ks.lathe(x, 0.95, 0.0, [[0.32, 0.0], [0.36, 0.06], [0.36, 0.1]], 10, "pewter"))

    shapes.append(ks.box(arm / 2.0 - 0.06, 1.25, 0.0, 0.5, 0.35, 0.4, "burlap"))
    # Its weights stacked by it, a bench, the sacks waiting.
    for i, (w, h) in enumerate(((0.3, 0.24), (0.24, 0.18), (0.18, 0.14), (0.12, 0.1))):
        shapes.append(ks.prism(-1.7, sum(hh for _, hh in ((0.3, 0.24), (0.24, 0.18), (0.18, 0.14), (0.12, 0.1))[:i]) + h / 2.0 + 0.5, 0.6, w,
                               h, 8, "iron"))

    shapes += [ks.box(-1.7, 0.45, 0.6, 1.2, 0.08, 0.5, "wood_old"), ks.box(-2.2, 0.21, 0.6, 0.08, 0.42, 0.4, "wood_old"),
               ks.box(-1.2, 0.21, 0.6, 0.08, 0.42, 0.4, "wood_old")]
    return shapes, [col(-1.7, 0.35, 0.6, 1.2, 0.7, 0.5, surface="wood")]


def _hoist():
    """The hoist's beam out of the front over the loading door (its pivot
    at the face, under the beam's end in the wall), its braces, its block."""
    length = 1.8
    shapes = [ks.box(0.0, 0.0, length / 2.0 - 0.3, 0.26, 0.26, length + 0.6, "beam"),
              ks.box(0.0, -0.75, 0.5, 0.16, 0.16, 1.4, "beam", 0.0, 45.0, 0.0),
              ks.box(0.0, -0.32, length - 0.15, 0.18, 0.3, 0.22, "timber"),
              ks.disc(0.11, -0.32, length - 0.15, 0.13, 8, "iron", 90.0), ks.ring(0.0, -0.14, length - 0.15, 0.04, 0.07, 0.04, 0.0, 360.0, 6, "iron", 90.0)]
    return shapes, [col(0.0, 0.0, length / 2.0, 0.26, 0.26, length)]


# Upstairs: the harbourmaster's office in the north-east corner, its
# partitions floor to ceiling, its door into the upper hall.
OFFICE = (2.0, -2.0, 5.0)


def _office():
    ox, oz, door = OFFICE
    h = EAVES - UP
    t = 0.16
    shapes, cols = [], []

    def wall(x0, z0, x1, z1):
        shapes.append(ks.box((x0 + x1) / 2.0, UP + h / 2.0, (z0 + z1) / 2.0, max(x1 - x0, t), h, max(z1 - z0, t), "whitewash"))
        shapes.append(ks.box((x0 + x1) / 2.0, UP + 0.08, (z0 + z1) / 2.0, max(x1 - x0, t) + 0.04, 0.16, max(z1 - z0, t) + 0.04, "timber"))
        cols.append(col((x0 + x1) / 2.0, UP + h / 2.0, (z0 + z1) / 2.0, max(x1 - x0, t), h, max(z1 - z0, t)))

    wall(ox - t / 2.0, Z0 + WALL, ox + t / 2.0, oz)
    wall(ox, oz - t / 2.0, door - 0.6, oz + t / 2.0)
    wall(door + 0.6, oz - t / 2.0, X1, oz + t / 2.0)
    shapes.append(ks.box(door, UP + 2.2 + (h - 2.2) / 2.0, oz, 1.2, h - 2.2, t, "whitewash"))
    cols.append(col(door, UP + 2.2 + (h - 2.2) / 2.0, oz, 1.2, h - 2.2, t))
    shapes += ks.moved(ki._frame(0.0, UP, 0.0, 1.2, 2.2, "timber"), 0.0, (door, 0.0, oz))
    return shapes, cols


# The hall's frame: a row of posts with their braces carrying a girder down
# its middle, beams across from wall to wall on it, under the upper floor
# (its foot on the hall's floor; posts at z in its frame).
HALL_POSTS = (1.0, [5.4, 1.2, -3.0, -7.2, -11.4])


def _hall_frame():
    x, posts = HALL_POSTS
    under = UP - 0.2
    shapes, cols = [], []
    shapes.append(ks.box(x, under - 0.16, (Z0 + WALL + HALL_FRONT - WALL) / 2.0, 0.3, 0.32, HALL_FRONT - WALL - Z0 - WALL, "beam"))

    for z in posts:
        shapes += [ks.box(x, (under - 0.32) / 2.0, z, 0.32, under - 0.32, 0.32, "beam"), ks.box(x, 0.1, z, 0.5, 0.2, 0.5, "granite")]
        cols.append(col(x, under / 2.0, z, 0.32, under, 0.32, surface="wood"))

        for s in (-1.0, 1.0):
            shapes.append(ks.box(x, under - 0.62, z + s * 0.45, 0.14, 0.14, 1.1, "beam", 0.0, s * 45.0, 0.0))

    z = Z0 + WALL + 1.0

    while z < HALL_FRONT - WALL - 0.5:
        # (Across the hall, the tower's corner left out of the last.)
        x0 = X0 + WALL if z < TOWER[2] else TOWER[1]
        shapes.append(ks.box((x0 + X1) / 2.0, under - 0.1, z, X1 - x0, 0.2, 0.18, "beam"))
        z += 2.2

    return shapes, cols


# The pieces

for _name, _maker, _slot, _budget in (("customs_loggia", _loggia, "granite", 2900), ("customs_portal_wall", _portal_wall, "granite", 1100),
                                      ("customs_upper_front", _upper_front, "ashlar_gold", 2400), ("customs_tower", _tower, "whitewash", 4200),
                                      ("customs_west_wall", _west_wall, "whitewash", 900), ("customs_back_wall", _back_wall, "whitewash", 900),
                                      ("customs_roof", _roof, "roof_spanish", 9000), ("customs_office", _office, "whitewash", 300),
                                      ("customs_hall_frame", _hall_frame, "beam", 600)):
    _made = _maker()
    _shapes, _cols = _made[0], _made[1]
    _part = ks.build(_shapes)
    _lo = [min(v[i] for v in _part["verts"]) for i in range(3)]
    _hi = [max(v[i] for v in _part["verts"]) for i in range(3)]
    _middle = [(_lo[0] + _hi[0]) / 2.0, 0.0, (_lo[2] + _hi[2]) / 2.0]
    _size = [_hi[0] - _lo[0] + 0.1, _hi[1] - _lo[1] + 0.1, _hi[2] - _lo[2] + 0.1]
    _piece(_name, _slot, _shapes, _cols, _middle, _size, _budget, windows=_made[2] if len(_made) > 2 else None)

_shapes, _cols = _stair()
k.piece("customs_stair", "iberian", "granite", "stone", [], cols=_cols, size=[STAIR[3] + 0.4, STAIR[0] * STAIR[1] + 1.0, STAIR[0] * STAIR[2] + 0.2])
k.model("customs_stair", _shapes)
# (Inside, under the roof: kit_recipes.roofed.)
for _name in ("customs_office", "customs_hall_frame", "customs_stair"):
    k.PIECES[_name]["roofed"] = True

_shapes, _cols = _kings_beam()
k.piece("kings_beam", "dressing", "iron", "metal", [], cols=_cols, size=[5.0, UP, 1.6])
k.model("kings_beam", _shapes)
_shapes, _cols = _hoist()
k.piece("customs_hoist", "dressing", "beam", "wood", [], cols=_cols, size=[0.6, 1.8, 4.4])
k.model("customs_hoist", _shapes)
