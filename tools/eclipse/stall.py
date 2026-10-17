"""The curandera's corridor stall (docs/superpowers/refs/underground/cards/stall.md),
the Metro Underground's hero piece and the first model built to the new
standard: chunky forms, soft bevels, details big enough to read. Built in
Blender, its atlas made and baked, exported to assets/eclipse/lab/stall.*;
the geometry gate decides whether it stands.

    Blender -b --factory-startup --python tools/eclipse/stall.py

Blender axes: X across the stall, -Y its front (the corridor), Z up. The
origin is the frame's middle at the counter's front face, on the floor.
"""

import math
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import bmesh  # noqa: E402
import bpy  # noqa: E402
from mathutils import Euler, Matrix, Vector  # noqa: E402

import common  # noqa: E402
import shapes  # noqa: E402

NAME = "stall"
ATLAS = 2048
# The card's slots, and what years at the pitch added: canvas patches, a salvaged Metro-blue
# board, an enamel sign and its blank face, basalt, dried chiles; tinted glass, wax seals,
# her ofrenda's bread and cut paper.
SLOTS = ["steel", "wood", "cloth", "brass", "tin", "paper", "wax", "herb", "herb_dry", "marigold", "clay", "glass", "neon",
         "cloth_patch", "paint_blue", "enamel", "sign", "stone", "chile", "glass_amber", "glass_green", "seal", "bread",
         "picado", "picado_b"]
BUDGET = 40000

# The Company's frame: square posts, round conduit rails, the back higher so
# the canvas sheds the drips from the pipes above (m). Wide and deep enough for
# her to stand and work behind the counter, and to walk in past its end.
POST = 0.07
POST_X = 1.5
# (Sized for the game's body too: a capsule 1 m across and 2 m tall walks in and along behind the counter.)
FRONT_Y, BACK_Y = 0.08, 2.17
FRONT_H, BACK_H = 2.35, 2.55
RAIL_R = 0.032
# The side rails tie the posts this far under the canvas, which rides the front and back rails.
SIDE_RAIL_DROP = 0.09
FITTING = 0.14
# The shoe that went missing: a wooden block stands in for it.
LOST_SHOE = (1.5, 0.08)
SHOE = (0.17, 0.08)                  # the cast feet: across, tall
# The junction box on the back right post: its bottom and top.
JUNCTION = (2.7, 2.85)
# The counter: from its left end to its right, short of the right post so she can walk in.
COUNTER_X = (-1.42, 0.35)
COUNTER_TOP = 0.92
SLAB = (-1.48, 0.41, -0.07, 0.56, 0.07)   # x from, x to, front, back, thickness
PLANK_T = 0.05
BATTENS = (0.2, 0.72)
# The back shelving, an aisle's width behind the counter.
SHELF_Y = (1.72, 2.09)
SHELF_MID = 1.9
SHELF_X = 1.3
UPRIGHT = 0.07
SHELVES = (0.5, 1.0, 1.5)
SHELF_T = 0.05
SHELF_TOP = 2.15
# The sign over the front rail.
SIGN = (-0.95, 0.95, 2.43, 2.87)     # x0, x1, z0, z1
SIGN_Y = (0.0, 0.14)
SIGN_RIM = (0.06, 0.05)              # border width, how far it stands proud
# The canvas.
AWNING_X = 1.62
AWNING_FRONT = -0.15
AWNING_T = 0.025
FLAP = (0.15, 0.06, 9)               # depth to the scallops' tops, their depth, how many
ROD_R = 0.03
# The herb pole across the front posts.
POLE_Z, POLE_R = 2.15, 0.025
# Where it stops, short of the way in.
POLE_END = 0.4
# Where things stand: the censer on the counter, the bulb over her aisle, her ofrenda on the counter's left end.
CENSER_AT = (0.0, 0.22)
BULB_AT = (0.1, 1.1, 2.26)
OFRENDA = (-1.4, -0.86, 0.08, 0.5)

rng = random.Random(1923)


# --- shapes the common ones lack ---------------------------------------------------------------

def turned(m, profile, sides, slot, at=(0.0, 0.0, 0.0), twist=0.0, jitter=0.0, lean=0.0, towards=0.0):
    """A closed solid turned about Z through `at` from [(r, z)] (every r > 0;
    each end capped by one polygon, which the gate reads as one face, unlike
    a fan of thin triangles). `jitter` roughens the inner rings' radii; `lean`
    (radians) tips the whole about `at`, its far end swinging `towards` that
    heading."""
    m.shell()
    rings = []
    tip = Matrix.Rotation(towards, 3, "Z") @ Matrix.Rotation(lean, 3, "X") @ Matrix.Rotation(-towards, 3, "Z")

    for i, (r, z) in enumerate(profile):
        inner = 0 < i < len(profile) - 1
        ring = []

        for k in range(sides):
            a = twist + 2 * math.pi * k / sides
            rr = r * (1 + rng.uniform(-jitter, jitter)) if inner and jitter else r
            p = tip @ Vector((rr * math.cos(a), rr * math.sin(a), z))
            ring.append((at[0] + p.x, at[1] + p.y, at[2] + p.z))

        rings.append(ring)

    shapes.loft(m, rings, slot, caps=True)


def pipe(m, points, r, sides, slot, closed=False):
    """A tube along a polyline, its rings carried along without twisting;
    a closed loop joins its last ring to its first."""
    m.shell()
    pts = [Vector(p) for p in points]
    n = len(pts)

    def ahead(i):
        if closed:
            return (pts[(i + 1) % n] - pts[i - 1]).normalized()
        return (pts[min(i + 1, n - 1)] - pts[max(i - 1, 0)]).normalized()

    t = ahead(0)
    side = t.cross(Vector((0, 0, 1)) if abs(t.z) < 0.9 else Vector((1, 0, 0))).normalized()
    rings = []

    for i in range(n):
        t = ahead(i)
        side = (side - t * side.dot(t)).normalized()
        up = t.cross(side)
        rings.append([tuple(pts[i] + (side * math.cos(2 * math.pi * k / sides) + up * math.sin(2 * math.pi * k / sides)) * r)
                      for k in range(sides)])

    if closed:
        shapes.loft(m, rings + [rings[0]], slot, caps=False)
    else:
        shapes.loft(m, rings, slot, caps=True)


def slab(m, grid, offset, slot, slot_of=None):
    """A sheet given its thickness: `grid` rows of points for one face, the
    other `offset` away, the borders closed; `slot_of(i, j)` (if given) the
    slot of each cell's two faces (a patch sewn in)."""
    m.shell()
    rows, cols = len(grid), len(grid[0])
    a = [[tuple(p) for p in row] for row in grid]
    b = [[tuple(Vector(p) + Vector(offset)) for p in row] for row in grid]

    for i in range(rows - 1):
        for j in range(cols - 1):
            cell = slot_of(i, j) if slot_of else slot
            m.face([a[i][j], a[i][j + 1], a[i + 1][j + 1], a[i + 1][j]], cell)
            m.face([b[i][j], b[i + 1][j], b[i + 1][j + 1], b[i][j + 1]], cell)

    ring = ([(0, j) for j in range(cols - 1)] + [(i, cols - 1) for i in range(rows - 1)]
            + [(rows - 1, j) for j in range(cols - 1, 0, -1)] + [(i, 0) for i in range(rows - 1, 0, -1)])

    for p, q in zip(ring, ring[1:] + ring[:1]):
        m.face([a[p[0]][p[1]], a[q[0]][q[1]], b[q[0]][q[1]], b[p[0]][p[1]]], slot)


# A rounded edge's corner patch is about 0.6 of its radius thick (2 segments,
# measured): the least radius that keeps it over the gate's 1 cm sliver.
ROUND_LEAST = 0.0185


def box(m, lo, hi, slot, r=0.03, turn=None):
    """A box with every edge rounded `r` (2 segments), bevelled on its own
    so nothing near it pinches the bevel; never so far that the flat left
    between two roundings is under 1.2 cm. `turn` (Euler radians) tilts it
    about its centre.
    Too thin to round over the sliver gate, it stays square."""
    size = Vector(hi) - Vector(lo)
    # The flat left between two roundings must stay over the sliver too.
    r = min(r, 0.4 * min(size), (min(size) - 0.012) / 2)
    m.shell()

    if r < ROUND_LEAST:
        if turn:
            shapes.obox(m, tuple((Vector(hi) + Vector(lo)) / 2), tuple(size), turn, slot)
        else:
            m.box(lo, hi, slot)
        return

    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    centre = (Vector(hi) + Vector(lo)) / 2
    bmesh.ops.transform(bm, matrix=Matrix.Diagonal((*size, 1.0)), verts=bm.verts)
    bmesh.ops.bevel(bm, geom=list(bm.edges) + list(bm.verts), offset=r, segments=2, profile=0.5, affect="EDGES",
                    clamp_overlap=False)
    place = Matrix.Translation(centre) @ (Euler(turn, "XYZ").to_matrix().to_4x4() if turn else Matrix.Identity(4))
    bmesh.ops.transform(bm, matrix=place, verts=bm.verts)

    for f in bm.faces:
        m.face([tuple(v.co) for v in f.verts], slot)

    bm.free()


def bolt(m, x, y, z, r=0.026):
    """A hex bolt head with a pyramid crown, standing on a +Z face."""
    m.shell()
    shapes.lathe(m, [(r, 0.0), (r, 0.014), (0.0, 0.026)], 6, "steel", at=(x, y, z))


def stud(m, at, lean, towards, slot="steel", r=0.026):
    """A domed stud (nail head, rivet) on a face, tipped from +Z by `lean`
    towards the heading `towards` (radians)."""
    turned(m, [(r, 0.0), (r, 0.012), (r * 0.6, 0.024)], 6, slot, at=at, lean=lean, towards=towards)


def join(target, others):
    """Others' faces made part of `target` (its name and its materials kept)."""
    with bpy.context.temp_override(active_object=target, object=target,
                                   selected_editable_objects=[target, *others]):
        bpy.ops.object.join()
    return target


# Faces meeting harder than this stay sharp; softer, they shade smooth (a
# rounded edge's strips meet at 45 degrees, a turned piece's sides at 30-72).
SMOOTH_ANGLE = 50.0


def _object(name, build):
    m = common.Mesh(name, outward=True)
    build(m)
    o = m.make()

    for poly in o.data.polygons:
        poly.use_smooth = True

    o.data.set_sharp_from_angle(angle=math.radians(SMOOTH_ANGLE))
    return o


# --- the frame ----------------------------------------------------------------------------------

def _rail_top(y):
    """The height of the rails' line at y (front rail to back rail)."""
    return FRONT_H + (y - FRONT_Y) * (BACK_H - FRONT_H) / (BACK_Y - FRONT_Y)


def frame_main(m):
    h = POST / 2

    for x in (-POST_X, POST_X):
        for y, top in ((FRONT_Y, FRONT_H), (BACK_Y, BACK_H)):
            # The cast shoe, the post standing in it from half its height; one
            # was lost long ago and a block of wood stands in for it.
            s = SHOE[0] / 2
            if (x, y) == LOST_SHOE:
                box(m, (x - s, y - s, 0.0), (x + s, y + s, SHOE[1] + 0.04), "wood", r=0.025)
            else:
                box(m, (x - s, y - s, 0.0), (x + s, y + s, SHOE[1]), "steel")
            box(m, (x - h, y - h, SHOE[1] / 2), (x + h, y + h, top), "steel")
            f = FITTING / 2
            box(m, (x - f, y - f, top - f), (x + f, y + f, top + f), "steel")

    # The back right post carries on up to the junction box.
    box(m, (POST_X - h, BACK_Y - h, BACK_H), (POST_X + h, BACK_Y + h, JUNCTION[0]), "steel")
    box(m, (POST_X - 0.07, BACK_Y - 0.06, JUNCTION[0] - 0.04), (POST_X + 0.07, BACK_Y + 0.06, JUNCTION[1]), "steel")

    # Conduit rails, each ending in its fittings' hearts; the side rails tie the posts under the canvas.
    for y, z in ((FRONT_Y, FRONT_H), (BACK_Y, BACK_H)):
        pipe(m, [(-POST_X, y, z), (POST_X, y, z)], RAIL_R, 12, "steel")

    for x in (-POST_X, POST_X):
        drop = SIDE_RAIL_DROP
        pipe(m, [(x, FRONT_Y, FRONT_H - drop), (x, BACK_Y, BACK_H - drop)], RAIL_R, 12, "steel")

    # Knee braces at the front corners: the Company's frames rack without them. The left one
    # across the front; the right one along the side, out of the way in.
    x = -POST_X
    pipe(m, [(x + 0.02, FRONT_Y, FRONT_H - 0.42), (x + 0.4, FRONT_Y, FRONT_H - 0.02)], 0.022, 10, "steel")
    pipe(m, [(POST_X, FRONT_Y + 0.02, FRONT_H - 0.42), (POST_X, FRONT_Y + 0.4, _rail_top(FRONT_Y + 0.4) - SIDE_RAIL_DROP)],
         0.022, 10, "steel")

    # The herb pole, from the left post to short of the way in, its free end hung from the front rail.
    pipe(m, [(-POST_X, FRONT_Y, POLE_Z), (POLE_END, FRONT_Y, POLE_Z)], POLE_R, 10, "wood")
    pipe(m, [(POLE_END - 0.04, FRONT_Y, POLE_Z), (POLE_END - 0.04, FRONT_Y, FRONT_H)], 0.015, 8, "steel")

    # The sign: a deep box, a border standing proud round its face.
    x0, x1, z0, z1 = SIGN
    y0, y1 = SIGN_Y
    w, d = SIGN_RIM
    box(m, (x0, y0 + d, z0), (x1, y1, z1), "steel")
    box(m, (x0, y0, z1 - w), (x1, y0 + d, z1), "steel")
    box(m, (x0, y0, z0), (x1, y0 + d, z0 + w), "steel")
    box(m, (x0, y0, z0 + w), (x0 + w, y0 + d, z1 - w), "steel")
    box(m, (x1 - w, y0, z0 + w), (x1, y0 + d, z1 - w), "steel")

    # Its two uprights, from the front rail's heart into the box.
    for x in (-0.7, 0.7):
        box(m, (x - 0.025, FRONT_Y - 0.025, FRONT_H), (x + 0.025, FRONT_Y + 0.025, z0 + 0.025), "steel", r=0.019)


def frame_detail(m):
    # Bolts on the shoes.
    for x in (-POST_X, POST_X):
        for y in (FRONT_Y, BACK_Y):
            if (x, y) == LOST_SHOE:
                continue

            for dx, dy in ((-1, -1), (1, -1), (-1, 1), (1, 1)):
                bolt(m, x + dx * 0.058, y + dy * 0.058, SHOE[1])

    # Brass collars where the Company joined offcuts, slightly crooked.
    for x, y, z, tilt in ((-POST_X, FRONT_Y, 1.32, 0.04), (POST_X, FRONT_Y, 0.66, -0.05), (-POST_X, BACK_Y, 1.05, 0.03),
                          (POST_X, BACK_Y, 1.6, -0.03)):
        box(m, (x - 0.085, y - 0.085, z - 0.05), (x + 0.085, y + 0.085, z + 0.05), "brass", r=0.025, turn=(0.0, tilt, 0.0))

    # The canvas lashed to the front posts under their fittings: two turns of rope.
    for x in (-POST_X, POST_X):
        for k in range(2):
            z = FRONT_H - FITTING / 2 - 0.03 - k * 0.028
            ring = [(x + 0.058 * math.cos(a), FRONT_Y + 0.058 * math.sin(a), z)
                    for a in (2 * math.pi * n / 8 for n in range(8))]
            pipe(m, ring, 0.012, 6, "paper", closed=True)

    # The Company's tin tag on a wire from the front right collar (its stamp is the user's to paint).
    pipe(m, [(POST_X, FRONT_Y - 0.075, 0.6), (POST_X, FRONT_Y - 0.075, 0.5)], 0.015, 8, "steel")
    box(m, (POST_X - 0.04, FRONT_Y - 0.087, 0.41), (POST_X + 0.04, FRONT_Y - 0.063, 0.505), "tin", r=0.0)

    # A ristra of dried chiles on the back left post, outside the shelving.
    rx, ry = -POST_X - 0.075, BACK_Y
    pipe(m, [(rx, ry, 2.15), (rx, ry, 1.4)], 0.015, 8, "paper")
    for k in range(18):
        a = k * 2.4
        z = 2.05 - k * 0.04
        turned(m, [(0.013, 0.0), (0.026, 0.02), (0.02, 0.07), (0.012, 0.1)], 5, "chile",
               at=(rx + 0.01 * math.cos(a), ry + 0.01 * math.sin(a), z), lean=2.3, towards=a, twist=a)

    # The cable from the sign's back to the junction box (the corridor's power), clipped to the back rail.
    m.shell()
    shapes.sag(m, (0.8, SIGN_Y[1] - 0.04, SIGN[2] + 0.25), (POST_X - 0.02, BACK_Y - 0.03, JUNCTION[0] + 0.02),
               0.015, 8, 0.07, 12, "steel")


def frame():
    main = _object("stall_frame", frame_main)
    detail = _object("stall_frame_detail", frame_detail)
    return join(main, [detail])


# --- the counter --------------------------------------------------------------------------------

def counter_main(m):
    x0, x1 = COUNTER_X
    # The carcass and its plinth, the front planks standing proud of it.
    box(m, (x0, PLANK_T, 0.06), (x1, 0.5, COUNTER_TOP), "wood")
    box(m, (x0 + 0.04, 0.1, 0.0), (x1 - 0.04, 0.46, 0.1), "wood")
    gap = 0.012
    widths = [rng.uniform(0.17, 0.28) for _ in range(9)]
    scale = (x1 - x0 - gap * (len(widths) - 1)) / sum(widths)
    x = x0

    for k, w in enumerate(widths):
        w *= scale
        lift = rng.uniform(-0.02, 0.02)
        # The sixth board split once; she nailed in a board off a Metro hoarding.
        box(m, (x, 0.0, 0.07 + lift), (x + w, PLANK_T, 0.895 + lift), "paint_blue" if k == 5 else "wood", r=0.02)
        x += w + gap

    # Two battens nailed across the boards' faces.
    for z in BATTENS:
        box(m, (x0 + 0.03, -0.05, z), (x1 - 0.03, 0.0, z + 0.075), "wood", r=0.02)

    # A batten across each end.
    for end, out in ((x0, -0.05), (x1, 0.05)):
        box(m, (min(end, end + out), 0.08, 0.42), (max(end, end + out), 0.47, 0.5), "wood", r=0.02)

    # Her side: a drawer for the takings, a shelf under the counter.
    box(m, (-0.5, 0.5, 0.7), (0.1, 0.55, 0.86), "wood", r=0.02)
    box(m, (x0 + 0.04, 0.5, 0.3), (x1 - 0.04, 0.6, 0.35), "wood", r=0.02)

    sx0, sx1, front, back, t = SLAB
    box(m, (sx0, front, COUNTER_TOP), (sx1, back, COUNTER_TOP + t), "wood")


def counter():
    return _object("stall_counter", counter_main)


# --- the shelving -------------------------------------------------------------------------------

def shelves_main(m):
    y0, y1 = SHELF_Y
    u = UPRIGHT / 2

    # Three uprights: two bays.
    for x in (-SHELF_X, 0.0, SHELF_X):
        box(m, (x - u, y0, 0.0), (x + u, y1, SHELF_TOP), "wood")

    for z in SHELVES:
        for bx0, bx1 in ((-SHELF_X, 0.0), (0.0, SHELF_X)):
            box(m, (bx0, y0, z), (bx1, y1 - 0.02, z + SHELF_T), "wood")

    # The bottom shelf's lip, so a bump does not walk the candles off it.
    box(m, (-SHELF_X + u, y0 - 0.0, SHELVES[0] + SHELF_T - 0.01), (SHELF_X - u, y0 + 0.05, SHELVES[0] + SHELF_T + 0.06),
        "wood", r=0.019)

    # Brackets under each shelf at the outer uprights: wooden knees.
    for z in SHELVES[1:]:
        for sx in (-1, 1):
            m.shell()
            ux = sx * (SHELF_X - u)
            knee = lambda y: [(ux, y, z), (ux - sx * 0.12, y, z), (ux, y, z - 0.12)]
            shapes.loft(m, [knee(y0 + 0.08), knee(y0 + 0.13)], "wood", caps=True)

    # The cornice: a board overhanging the top.
    box(m, (-SHELF_X - 0.06, y0 - 0.06, SHELF_TOP), (SHELF_X + 0.06, y1 + 0.02, SHELF_TOP + 0.06), "wood")

    # The middle shelf of the left bay sagged: a block under its middle holds it up.
    box(m, (-SHELF_X / 2 - 0.06, y0 + 0.05, SHELVES[1] - 0.12), (-SHELF_X / 2 + 0.06, y1 - 0.06, SHELVES[1]), "wood",
        r=0.02)

    boards = 5
    for k in range(boards):
        z = 0.02 + k * (SHELF_TOP / boards)
        hi = z + SHELF_TOP / boards - 0.015
        if k == 2:
            # A back board gone; a shorter one, salvaged blue, in its place: the wall shows past it.
            box(m, (-SHELF_X, y1, z), (0.45, y1 + PLANK_T, hi), "paint_blue")
        else:
            box(m, (-SHELF_X, y1, z), (SHELF_X, y1 + PLANK_T, hi), "wood")


def shelves():
    return _object("stall_shelves", shelves_main)


# --- the canvas ---------------------------------------------------------------------------------

def _canvas_under(x, y):
    """Where the canvas's underside lies: on the rails' line, sagging
    between them, drooping past the side rails and over the front."""
    z = _rail_top(y) + RAIL_R + 0.004

    if FRONT_Y <= y <= BACK_Y:
        between = math.sin(math.pi * (y - FRONT_Y) / (BACK_Y - FRONT_Y))
        z -= 0.06 * between * math.cos(0.5 * math.pi * x / AWNING_X)
        z += 0.014 * between * math.sin(6.0 * math.pi * x / AWNING_X)
    elif y < FRONT_Y:
        z -= 0.05 * ((FRONT_Y - y) / (FRONT_Y - AWNING_FRONT)) ** 2

    beyond = max(0.0, abs(x) - POST_X) / (AWNING_X - POST_X)
    return z - 0.05 * beyond ** 2


def awning_main(m):
    cols, rows = 31, 15
    grid = []

    for i in range(rows):
        y = AWNING_FRONT + (BACK_Y + 0.12 - AWNING_FRONT) * i / (rows - 1)
        grid.append([(-AWNING_X + 2 * AWNING_X * j / (cols - 1), y,
                      _canvas_under(-AWNING_X + 2 * AWNING_X * j / (cols - 1), y)) for j in range(cols)])

    patches = [(range(4, 8), range(2, 5)), (range(18, 21), range(6, 10)), (range(25, 28), range(1, 3)),
               (range(10, 12), range(11, 13))]
    patched = lambda i, j: "cloth_patch" if any(j in cs and i in rs for cs, rs in patches) else "cloth"
    slab(m, grid, (0.0, 0.0, AWNING_T), "cloth", slot_of=patched)

    # The front rod the canvas wraps, and the scalloped flap hanging from it.
    rod_z = _canvas_under(0.0, AWNING_FRONT) + AWNING_T / 2
    pipe(m, [(-AWNING_X - 0.02, AWNING_FRONT, rod_z), (AWNING_X + 0.02, AWNING_FRONT, rod_z)], ROD_R, 10, "wood")
    depth, scallop, count = FLAP
    xs = [-AWNING_X + 2 * AWNING_X * k / (count * 6) for k in range(count * 6 + 1)]
    top = [(x, AWNING_FRONT - 0.015, rod_z) for x in xs]
    bottom = [(x, AWNING_FRONT - 0.015,
               rod_z - depth - scallop * math.sin(math.pi * ((x + AWNING_X) / (2 * AWNING_X) * count % 1.0))) for x in xs]
    slab(m, [top, bottom], (0.0, 0.03, 0.0), "cloth")


def awning():
    return _object("stall_awning", awning_main)


# --- what she sells -----------------------------------------------------------------------------

def candle(m, x, y, z, r=0.04, h=0.2, sides=8, lit=False):
    """A pillar candle, its top melted into a lip; a lit one's wick recorded
    for its flame (common.WICKS: the piece's _wicks.json)."""
    turned(m, [(r, 0.0), (r, h - 0.03), (r * 1.08, h - 0.012), (r * 0.9, h)], sides, "wax", at=(x, y, z),
           twist=rng.uniform(0, 1))

    if lit:
        m.wick((x, y, z + h + 0.005))


def jar(m, x, y, z, r=0.075, h=0.19, filling="herb", make="apothecary"):
    """A remedy jar or bottle of several makes: a clear apothecary jar with a
    tin lid and something steeping in it; a round-bellied jar; a tinted
    bottle with a paper label and a cork sealed in wax; a squat tinted
    flask with a cork."""
    # What steeps inside keeps 4.5 cm clear of the glass, never thinner than the gate allows.
    c = max(0.02, r - 0.045)
    steeping = lambda top, base=0.035: turned(m, [(c, base), (c, top), (c * 0.85, top + 0.025)], 7, filling,
                                              at=(x, y, z), jitter=0.05)

    if make in ("bottle_amber", "bottle_green"):
        glass = "glass_amber" if make == "bottle_amber" else "glass_green"
        # Stacked bands, each its own closed piece: glass, its paper label, glass, the neck.
        # (Each band and stopper over 3 cm tall: stacked closer, their caps would layer under the gate.)
        turned(m, [(r, 0.0), (r, h * 0.25)], 10, glass, at=(x, y, z))
        turned(m, [(r, h * 0.25), (r, h * 0.55)], 10, "paper", at=(x, y, z))
        turned(m, [(r, h * 0.55), (r, h * 0.62), (r * 0.42, h * 0.78), (r * 0.42, h)], 10, glass, at=(x, y, z))
        turned(m, [(r * 0.46, h), (r * 0.5, h + 0.04)], 8, "wood", at=(x, y, z))
        turned(m, [(r * 0.56, h + 0.04), (r * 0.6, h + 0.055), (r * 0.4, h + 0.075)], 8, "seal", at=(x, y, z))
        return

    if make == "flask":
        turned(m, [(r * 0.9, 0.0), (r * 1.2, h * 0.3), (r * 1.1, h * 0.6), (r * 0.4, h * 0.82), (r * 0.4, h)], 10,
               "glass_green", at=(x, y, z))
        turned(m, [(r * 0.44, h), (r * 0.48, h + 0.035)], 8, "wood", at=(x, y, z))
        return

    if make == "belly":
        turned(m, [(r * 0.8, 0.0), (r * 1.15, h * 0.35), (r, h * 0.75), (r * 0.62, h * 0.88), (r * 0.62, h)], 10, "glass",
               at=(x, y, z))
        turned(m, [(r * 0.7, h), (r * 0.7, h + 0.03), (r * 0.5, h + 0.045)], 10, "tin", at=(x, y, z))
        steeping(h * 0.45, base=0.055)
        return

    turned(m, [(r, 0.0), (r, h * 0.82), (r * 0.72, h * 0.92), (r * 0.72, h)], 10, "glass", at=(x, y, z))
    turned(m, [(r * 0.8, h), (r * 0.8, h + 0.03), (r * 0.6, h + 0.045)], 10, "tin", at=(x, y, z))
    steeping(h * 0.55)


def pot(m, x, y, z, r=0.09, h=0.13):
    """A clay pot of cut herbs."""
    turned(m, [(r * 0.7, 0.0), (r, h * 0.45), (r * 0.85, h), (r * 0.95, h + 0.02)], 9, "clay", at=(x, y, z))
    turned(m, [(r * 0.55, h - 0.02), (r * 1.1, h + 0.1), (r * 0.9, h + 0.2), (r * 0.4, h + 0.26)], 7, "herb",
           at=(x, y, z), jitter=0.2, twist=rng.uniform(0, 1))


def bundle(m, x, length, width, slot, seed):
    """A bundle of herbs hung head down from the pole by its twine: sprigs
    splayed from where the twine binds their stems (its own `seed`)."""
    rng = random.Random(seed)
    top = POLE_Z - POLE_R - 0.05
    pipe(m, [(x, FRONT_Y, POLE_Z + 0.005), (x, FRONT_Y, top - 0.03)], 0.011, 6, "paper")
    sprigs = rng.randint(4, 6)
    turn = rng.uniform(0, 2 * math.pi)

    for k in range(sprigs):
        long = length * rng.uniform(0.7, 1.0)
        wide = width * rng.uniform(0.45, 0.7)
        profile = [(0.013, 0.0), (0.016, -0.05), (wide * 0.8, -long * 0.35), (wide, -long * 0.62),
                   (wide * 0.55, -long * 0.88), (0.014, -long)]
        turned(m, profile, 5, slot, at=(x, FRONT_Y, top), twist=rng.uniform(0, 1), jitter=0.25,
               lean=rng.uniform(0.1, 0.32), towards=turn + 2 * math.pi * k / sprigs)


def _shelf_row(m, z, kind, x_from, x_to):
    """One bay's shelf filled: candles in families, jars and bottles in huddles."""
    x = x_from

    while x < x_to - 0.1:
        pick = kind if kind != "mixed" else rng.choice(["candles", "jars", "pot"])

        if pick == "candles":
            n = rng.choice([2, 3])
            if x + n * 0.12 > x_to:
                break
            # Neighbours a hand apart: closer, their sides would sit near-parallel under the gate.
            for k in range(n):
                candle(m, x + 0.05 + k * 0.12, SHELF_MID + rng.uniform(-0.03, 0.03), z, h=rng.uniform(0.14, 0.3))
            x += n * 0.12 + 0.06
        elif pick == "jars":
            # A huddle of two to four, then a gap: kept apart by their widest.
            for k in range(rng.choice([2, 3, 4])):
                make = rng.choice(["apothecary", "apothecary", "belly", "bottle_amber", "bottle_green", "flask"])
                r = rng.uniform(0.06, 0.08)
                widest = r * (1.2 if make in ("belly", "flask") else 1.0)
                if x + 2 * widest > x_to:
                    break
                jar(m, x + widest, SHELF_MID + rng.uniform(-0.015, 0.015), z, r=r, h=rng.uniform(0.15, 0.27),
                    filling=rng.choice(["herb", "herb_dry", "wax", "clay"]), make=make)
                x += 2 * widest + 0.035
            x += rng.uniform(0.08, 0.16)
        else:
            if x + 0.2 > x_to:
                break
            pot(m, x + 0.1, SHELF_MID, z)
            x += 0.26


def clutter_main(m):
    # The shelves, both bays.
    u = UPRIGHT / 2
    kinds = ["candles", "jars", "mixed"]

    for z, kind in zip(SHELVES, kinds):
        for bx0, bx1 in ((-SHELF_X + u, -u), (u, SHELF_X - u)):
            _shelf_row(m, z + SHELF_T, kind, bx0 + 0.02, bx1 - 0.02)

    # On the cornice, under the canvas: a basket of dried herbs, a tin box, tapers in a tin.
    top_of = SHELF_TOP + 0.06
    turned(m, [(0.11, 0.0), (0.15, 0.08), (0.16, 0.12)], 10, "herb_dry", at=(-0.8, SHELF_MID, top_of))
    turned(m, [(0.11, 0.1), (0.15, 0.15), (0.06, 0.19)], 9, "herb", at=(-0.8, SHELF_MID, top_of), jitter=0.2)
    box(m, (-0.3, SHELF_MID - 0.12, top_of), (0.05, SHELF_MID + 0.12, top_of + 0.12), "tin", r=0.025)
    turned(m, [(0.05, 0.0), (0.05, 0.1), (0.055, 0.11)], 8, "tin", at=(0.6, SHELF_MID, top_of))

    for k in range(3):
        a = 2 * math.pi * k / 3
        turned(m, [(0.016, 0.06), (0.016, 0.24)], 6, "wax", at=(0.6 + 0.022 * math.cos(a), SHELF_MID + 0.022 * math.sin(a),
                                                               top_of), lean=0.12, towards=a)

    # Pouches of her mixtures hung under the top shelves by their drawstrings.
    for px in (-0.95, -0.35, 0.4, 0.95):
        pipe(m, [(px, SHELF_Y[0] + 0.1, SHELVES[2]), (px, SHELF_Y[0] + 0.1, SHELVES[2] - 0.06)], 0.011, 6, "paper")
        turned(m, [(0.018, -0.06), (0.05, -0.1), (0.06, -0.16), (0.04, -0.2)], 8, "cloth_patch",
               at=(px, SHELF_Y[0] + 0.1, SHELVES[2]), jitter=0.1)

    # The counter: copal smoking in a censer, eggs for a limpia, packets of herbs.
    top = COUNTER_TOP + SLAB[4]
    cx, cy = CENSER_AT
    turned(m, [(0.05, 0.0), (0.05, 0.03), (0.035, 0.05)], 8, "tin", at=(cx, cy, top))
    turned(m, [(0.035, 0.05), (0.09, 0.09), (0.1, 0.14), (0.085, 0.15)], 10, "tin", at=(cx, cy, top))
    turned(m, [(0.06, 0.13), (0.07, 0.17), (0.045, 0.205)], 8, "wax", at=(cx, cy, top), jitter=0.2)
    ex, ey = -0.2, 0.12
    turned(m, [(0.07, 0.0), (0.12, 0.05), (0.13, 0.08), (0.12, 0.085)], 10, "clay", at=(ex, ey, top))

    for k, (dx, dy) in enumerate(((-0.04, 0.0), (0.04, 0.02), (0.0, -0.045))):
        turned(m, [(0.015, 0.0), (0.035, 0.02), (0.033, 0.055), (0.015, 0.075)], 8, "paper",
               at=(ex + dx, ey + dy, top + 0.05 - k * 0.002))

    for k in range(3):
        m.shell()
        shapes.obox(m, (-0.47 + k * 0.03, 0.3, top + 0.0175 + k * 0.036), (0.16, 0.11, 0.035),
                    (0.0, 0.0, rng.uniform(-0.3, 0.3)), "paper")

    # A limpia bunch laid on the counter: sprigs lying together, tied.
    # (Lying front to back: tipped towards pi, a sprig's tip runs +Y.)
    for k in range(3):
        turned(m, [(0.013, 0.0), (0.03, 0.1), (0.04, 0.2), (0.02, 0.3)], 5, "herb", at=(0.15, 0.04, top + 0.04),
               lean=math.pi / 2 - 0.05, towards=math.pi + (k - 1) * 0.2, jitter=0.2)

    # Marigold heads fallen out of her ofrenda onto the counter.
    for k, (px, py) in enumerate(((-0.8, 0.07), (-0.68, 0.13))):
        marigold(m, px, py, top, lean=1.3, towards=k * 2.0)

    # A molcajete and its pestle, basalt, on three stubby legs.
    mx, my = -0.7, 0.36
    for k in range(3):
        a = k * 2 * math.pi / 3 + 0.3
        turned(m, [(0.022, 0.0), (0.024, 0.04)], 6, "stone", at=(mx + 0.06 * math.cos(a), my + 0.06 * math.sin(a), top))
    turned(m, [(0.06, 0.035), (0.115, 0.06), (0.125, 0.1), (0.105, 0.115)], 10, "stone", at=(mx, my, top), jitter=0.06)
    turned(m, [(0.026, 0.09), (0.036, 0.14), (0.03, 0.19)], 7, "stone", at=(mx, my, top), lean=0.45, towards=0.8)

    # Her hand bell at the counter's open end; her tin cash box at the back.
    bx, by = 0.3, 0.42
    turned(m, [(0.06, 0.0), (0.062, 0.012), (0.05, 0.04), (0.04, 0.075), (0.022, 0.095)], 12, "brass", at=(bx, by, top))
    turned(m, [(0.014, 0.09), (0.014, 0.13), (0.026, 0.145), (0.022, 0.17)], 8, "wood", at=(bx, by, top))
    box(m, (-0.12, 0.42, top), (0.09, 0.54, top + 0.085), "tin", r=0.02)

    # A brass scale hung from the herb pole over the counter's right: beam, chains, two pans.
    sx, sz = 0.2, POLE_Z
    pipe(m, [(sx, FRONT_Y, sz), (sx, FRONT_Y, sz - 0.16)], 0.012, 6, "brass")
    pipe(m, [(sx - 0.14, FRONT_Y, sz - 0.17), (sx + 0.14, FRONT_Y, sz - 0.17)], 0.014, 8, "brass")
    for side in (-1, 1):
        px = sx + side * 0.13
        pipe(m, [(px, FRONT_Y, sz - 0.17), (px, FRONT_Y, sz - 0.43)], 0.011, 6, "steel")
        turned(m, [(0.03, -0.45), (0.08, -0.43), (0.09, -0.41)], 12, "brass", at=(px, FRONT_Y, sz))

    # A salvaged enamel sign bolted across the boards between the battens, its face blank (the user's words).
    m.shell()
    shapes.panel(m, (-0.92, -0.045, 0.32), (-0.38, 0.0, 0.68), 0.04, "enamel", "sign")
    for sx2 in (-0.9, -0.4):
        for sz2 in (0.34, 0.66):
            stud(m, (sx2, -0.045, sz2), math.pi / 2, 0.0, "steel", r=0.02)

    # Nail heads along the battens.
    nails = int((COUNTER_X[1] - COUNTER_X[0] - 0.24) / 0.28) + 1

    for z in BATTENS:
        for k in range(nails):
            stud(m, (COUNTER_X[0] + 0.12 + k * 0.28 + rng.uniform(-0.02, 0.02), -0.05, z + 0.0375), math.pi / 2, 0.0,
                 "steel", r=0.02)

    # Price cards on twine from the top shelf's lip, hanging in front of the jars.
    for k, cx2 in enumerate((-1.0, -0.55, -0.15, 0.3, 0.75, 1.1)):
        drop = 0.04 + 0.025 * (k % 2)
        pipe(m, [(cx2, SHELF_Y[0] - 0.02, SHELVES[2] + 0.01), (cx2, SHELF_Y[0] - 0.02, SHELVES[2] - drop)], 0.011, 6,
             "paper")
        box(m, (cx2 - 0.045, SHELF_Y[0] - 0.058, SHELVES[2] - drop - 0.06), (cx2 + 0.045, SHELF_Y[0] - 0.034, SHELVES[2] - drop),
            "paper", r=0.0)

    # In her aisle, out of her way: her stool by the open end, a crate and a wicker demijohn at the far end.
    box(m, (-0.95, 1.15, 0.58), (-0.63, 1.45, 0.64), "wood", r=0.02)
    for lx in (-0.91, -0.67):
        for ly in (1.19, 1.41):
            box(m, (lx - 0.025, ly - 0.025, 0.0), (lx + 0.025, ly + 0.025, 0.58), "wood", r=0.0)
    box(m, (-1.38, 0.64, 0.0), (-0.98, 0.98, 0.28), "wood", r=0.025)
    for k in range(3):
        turned(m, [(0.04, 0.0), (0.04, 0.16), (0.017, 0.22), (0.017, 0.27)], 8, "glass_amber",
               at=(-1.28 + k * 0.12, 0.81, 0.28))
    dx, dy = -1.17, 1.3
    turned(m, [(0.11, 0.0), (0.16, 0.08), (0.17, 0.2), (0.12, 0.33)], 12, "herb_dry", at=(dx, dy, 0.0))
    turned(m, [(0.06, 0.33), (0.045, 0.4), (0.045, 0.46)], 10, "glass_green", at=(dx, dy, 0.0))
    turned(m, [(0.05, 0.46), (0.055, 0.5)], 8, "wood", at=(dx, dy, 0.0))

    # Herbs hung from the pole, between the ofrenda and the scale.
    herbs = random.Random(9)

    for k in range(5):
        bundle(m, -0.78 + k * 0.15 + herbs.uniform(-0.02, 0.02), herbs.uniform(0.3, 0.46), herbs.uniform(0.06, 0.09),
               herbs.choice(["herb", "herb", "herb_dry"]), seed=200 + k)


def clutter():
    return _object("stall_clutter", clutter_main)


# --- the bulb (its own object: it sways in the corridor's draught) --------------------------------

def bulb_main(m):
    """The bulb on its cord under the canvas, the cord's top just inside the cloth."""
    x, y, z = BULB_AT
    pipe(m, [(x, y, _canvas_under(x, y) + 0.012), (x, y, z + 0.02)], 0.011, 6, "steel")
    turned(m, [(0.024, -0.03), (0.024, 0.01), (0.018, 0.02)], 8, "brass", at=BULB_AT)
    turned(m, [(0.02, -0.03), (0.045, -0.07), (0.05, -0.11), (0.03, -0.15), (0.015, -0.16)], 10, "glass", at=BULB_AT)


def bulb():
    return _object("stall_bulb", bulb_main)


# --- her ofrenda --------------------------------------------------------------------------------

def marigold(m, x, y, z, lean=0.0, towards=0.0):
    turned(m, [(0.018, 0.0), (0.042, 0.014), (0.038, 0.026), (0.046, 0.038), (0.041, 0.05), (0.04, 0.062), (0.02, 0.078)],
           8, "marigold", at=(x, y, z), jitter=0.08, twist=rng.uniform(0, 1), lean=lean, towards=towards)


def ofrenda_main(m):
    x0, x1, y0, y1 = OFRENDA
    z0 = COUNTER_TOP + SLAB[4]
    t = 0.05
    wall = 0.56
    box(m, (x0, y0, z0), (x1, y1, z0 + t), "wood", r=0.02)
    box(m, (x0, y1 - t, z0 + t - 0.01), (x1, y1, z0 + wall), "wood", r=0.02)

    for x in (x0, x1 - t):
        box(m, (x, y0, z0 + t - 0.01), (x + t, y1 - t + 0.01, z0 + wall), "wood", r=0.02)

    # The pitched roof: two boards resting on the side walls' outer edges,
    # meeting under a ridge piece, overhanging the walls; a gable board closes the back.
    mid, pitch = (x0 + x1) / 2, 0.62
    eave, board = 0.06, 0.05
    span = mid - x0
    length = span / math.cos(pitch) + eave
    rise = math.tan(pitch) * span
    roof = z0 + wall

    for side in (-1, 1):
        up = Vector((-side * math.cos(pitch), 0.0, math.sin(pitch)))
        out = Vector((side * math.sin(pitch), 0.0, math.cos(pitch)))
        edge = Vector((mid + side * span, 0.0, roof))
        centre = edge + up * (length / 2 - eave) + out * (board / 2)
        box(m, (centre.x - length / 2, y0 - 0.06, centre.z - board / 2),
            (centre.x + length / 2, y1 + 0.03, centre.z + board / 2), "wood", r=0.02, turn=(0.0, side * pitch, 0.0))

    ridge = roof + rise
    box(m, (mid - 0.035, y0 - 0.07, ridge), (mid + 0.035, y1 + 0.04, ridge + 0.07), "wood", r=0.02)
    m.shell()
    gable = lambda y: [(x0 + 0.01, y, roof - 0.01), (x1 - 0.01, y, roof - 0.01), (mid, y, ridge - 0.02)]
    shapes.loft(m, [gable(y1 - t), gable(y1)], "wood", caps=True)

    # A little cross over the ridge's front.
    box(m, (mid - 0.02, y0 - 0.02, ridge + 0.07), (mid + 0.02, y0 + 0.03, ridge + 0.25), "wood", r=0.0)
    box(m, (mid - 0.07, y0 - 0.02, ridge + 0.17), (mid + 0.07, y0 + 0.03, ridge + 0.21), "wood", r=0.0)

    # Inside: a stepped altar against the back wall.
    inner0, inner1 = x0 + t, x1 - t
    step1 = (inner0, y1 - t - 0.2, z0 + t), (inner1, y1 - t, z0 + t + 0.09)
    step2 = (inner0, y1 - t - 0.1, z0 + t + 0.09), (inner1, y1 - t, z0 + t + 0.18)
    box(m, *step1, "wood", r=0.02)
    box(m, *step2, "wood", r=0.02)
    s1, s2 = step1[1][2], step2[1][2]

    # The saint's print in a brass frame on the back wall, above the steps.
    m.shell()
    shapes.panel(m, (mid - 0.11, y1 - t - 0.05, s2 + 0.04), (mid + 0.11, y1 - t, s2 + 0.33), 0.035, "brass", "paper")

    # On the top step: two tall candles either side of the saint.
    for sx in (-1, 1):
        candle(m, mid + sx * 0.16, y1 - t - 0.05, s2, r=0.04, h=0.2, lit=True)

    # On the lower step: the photograph of the one she lost, pan de muerto, a glass of water for their thirst.
    m.shell()
    shapes.panel(m, (mid - 0.2, y1 - t - 0.17, s1), (mid - 0.08, y1 - t - 0.13, s1 + 0.15), 0.025, "brass", "paper")
    bx = mid + 0.06
    by = y1 - t - 0.14
    turned(m, [(0.045, 0.0), (0.06, 0.02), (0.056, 0.05), (0.035, 0.075), (0.022, 0.088)], 10, "bread", at=(bx, by, s1))
    for a in (0.4, 0.4 + math.pi / 2):
        box(m, (bx - 0.05, by - 0.012, s1 + 0.05), (bx + 0.05, by + 0.012, s1 + 0.085), "bread", r=0.0,
            turn=(0.0, 0.0, a))
    # A small mezcal for them at the step's end.
    turned(m, [(0.03, 0.0), (0.03, 0.08), (0.015, 0.11), (0.015, 0.14)], 8, "glass_amber", at=(x1 - t - 0.04, by, s1))

    # On the floor of the niche, in a row before the steps: marigolds in a clay jar, a glass of water, a
    # candle, the sugar skull against the wall.
    fx, fy = x0 + t + 0.07, y0 + 0.11
    turned(m, [(0.035, 0.0), (0.045, 0.05), (0.03, 0.09), (0.035, 0.1)], 8, "clay", at=(fx, fy, z0 + t))
    for dx, dy, dz in [(0.0, 0.0, 0.16)] + [(0.045 * math.cos(k * 2 * math.pi / 6), 0.045 * math.sin(k * 2 * math.pi / 6),
                                             0.1 + rng.uniform(0.0, 0.05)) for k in range(6)]:
        marigold(m, fx + dx, fy + dy, z0 + t + dz)

    turned(m, [(0.034, 0.0), (0.04, 0.09)], 10, "glass", at=(fx + 0.13, fy, z0 + t))
    candle(m, fx + 0.26, fy, z0 + t, r=0.04, h=0.11, lit=True)
    sk0 = x1 - t - 0.075
    box(m, (sk0, y0 + 0.06, z0 + t), (sk0 + 0.07, y0 + 0.13, z0 + t + 0.065), "wax", r=0.02)
    for ex in (sk0 + 0.018, sk0 + 0.052):
        stud(m, (ex, y0 + 0.06, z0 + t + 0.042), math.pi / 2, 0.0, "marigold", r=0.017)

    # Papel picado strung across the niche's mouth under the eaves: cut-paper flags.
    py = y0 - 0.04
    string_z = roof - 0.02
    pipe(m, [(x0 - 0.02, py, string_z), (x1 + 0.02, py, string_z)], 0.011, 6, "paper")
    flags = 5
    for k in range(flags):
        fxk = x0 + 0.05 + k * (x1 - x0 - 0.1) / (flags - 1)
        box(m, (fxk - 0.045, py - 0.006, string_z - 0.11), (fxk + 0.045, py + 0.006, string_z - 0.005),
            "picado" if k % 2 == 0 else "picado_b", r=0.0)


def ofrenda():
    return _object("stall_ofrenda", ofrenda_main)


# --- the neon -----------------------------------------------------------------------------------

def neon_main(m):
    """The sign's outline tube on its standoffs. The words go inside it,
    the user's (the card: needed from the user)."""
    x0, x1, z0, z1 = SIGN
    inset, corner = 0.085, 0.05
    y = SIGN_Y[0] - 0.03
    a, b, c, d = x0 + inset, x1 - inset, z0 + inset, z1 - inset
    path = []

    for (cx, cz, start) in ((b - corner, d - corner, 0.0), (a + corner, d - corner, 90.0),
                            (a + corner, c + corner, 180.0), (b - corner, c + corner, 270.0)):
        for k in range(4):
            ang = math.radians(start + 90.0 * k / 3)
            path.append((cx + corner * math.cos(ang), y, cz + corner * math.sin(ang)))

    pipe(m, path, 0.012, 6, "neon", closed=True)

    for px, pz in ((a, (c + d) / 2), (b, (c + d) / 2), ((a + b) / 2, d), ((a + b) / 2, c)):
        pipe(m, [(px, y + 0.005, pz), (px, SIGN_Y[0] + SIGN_RIM[1] + 0.01, pz)], 0.012, 6, "tin")


def neon():
    return _object("stall_neon", neon_main)


JOINTS = {
    "01_shoe_post": ((-1.1, -0.5, 0.4), (-POST_X, FRONT_Y, 0.06)),
    "02_counter_front": ((0.0, -1.2, 0.9), (-0.4, 0.0, 0.5)),
    "03_counter_end_gap": ((1.9, -0.8, 1.4), (0.4, 0.3, 0.8)),
    "04_shelves": ((0.6, 0.6, 1.6), (0.0, 1.6, 1.1)),
    "05_rail_fittings": ((-1.0, -0.6, 2.5), (-POST_X, FRONT_Y, FRONT_H)),
    "06_awning_flap": ((0.5, -1.2, 2.0), (0.0, AWNING_FRONT, 2.05)),
    "07_sign_uprights": ((1.1, -0.8, 2.3), (0.7, FRONT_Y, 2.2)),
    "08_neon_standoffs": ((0.6, -0.7, 2.6), (0.8, 0.0, 2.45)),
    "09_herbs_scale": ((0.6, -0.8, 1.8), (0.3, FRONT_Y, 1.65)),
    "10_ofrenda": ((-0.8, -0.6, 1.4), (-1.16, 0.3, 1.25)),
    "11_aisle": ((1.1, 0.9, 1.7), (-0.2, 1.1, 0.6)),
    "12_junction_cable": ((1.9, 1.3, 2.9), (POST_X, BACK_Y, 2.6)),
}


def build():
    common.reset()
    rng.seed(1923)
    frame()
    counter()
    shelves()
    awning()
    clutter()
    bulb()
    ofrenda()
    neon()


def main():
    build()
    common.export_piece(NAME, ATLAS, SLOTS, budget=BUDGET)


if __name__ == "__main__":
    main()
