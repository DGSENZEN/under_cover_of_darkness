"""The curandera's corridor stall (docs/superpowers/refs/underground/cards/stall.md),
the Metro Underground's hero piece and the first model built to the new
standard: chunky forms, soft bevels, details big enough to read. Built in
Blender, its atlas made and baked, exported to assets/eclipse/lab/stall.*;
the geometry gate decides whether it stands.

    Blender -b --factory-startup --python tools/eclipse/stall.py

Blender axes: X across the stall, -Y its front (the corridor), Z up. The
origin is the front face of the counter's carcass, centred, on the floor.
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
# board, an enamel sign and its blank face, basalt, dried chiles.
SLOTS = ["steel", "wood", "cloth", "brass", "tin", "paper", "wax", "herb", "herb_dry", "marigold", "clay", "glass", "neon",
         "cloth_patch", "paint_blue", "enamel", "sign", "stone", "chile"]
BUDGET = 30000

# The Company's frame: square posts, round conduit rails, the back higher so
# the canvas sheds the drips from the pipes above (m).
POST = 0.07
POST_X = 1.12
FRONT_Y, BACK_Y = 0.08, 1.26
FRONT_H, BACK_H = 2.05, 2.25
RAIL_R = 0.032
# The side rails tie the posts this far under the canvas, which rides the front and back rails.
SIDE_RAIL_DROP = 0.09
FITTING = 0.14
# The shoe that went missing: a wooden block stands in for it.
LOST_SHOE = (1.12, 0.08)
SHOE = (0.17, 0.08)                  # the cast feet: across, tall
# The counter.
COUNTER_X = 1.02
COUNTER_TOP = 0.92
SLAB = (1.1, -0.07, 0.56, 0.07)      # half width, front, back, thickness
PLANK_T = 0.05
# The back shelving.
SHELF_Y = (0.92, 1.3)
SHELF_X = 1.0
UPRIGHT = 0.07
SHELVES = (0.5, 1.0, 1.5)
SHELF_T = 0.05
# The sign over the front rail.
SIGN = (-0.78, 0.78, 2.13, 2.6)      # x0, x1, z0, z1
SIGN_Y = (0.0, 0.14)
SIGN_RIM = (0.06, 0.05)              # border width, how far it stands proud
# The canvas.
AWNING_X = 1.25
AWNING_FRONT = -0.15
AWNING_T = 0.025
FLAP = (0.15, 0.06, 7)               # depth to the scallops' tops, their depth, how many
ROD_R = 0.03
# The herb pole across the front posts.
POLE_Z, POLE_R = 1.9, 0.025

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
    box(m, (POST_X - h, BACK_Y - h, BACK_H), (POST_X + h, BACK_Y + h, 2.4), "steel")
    box(m, (POST_X - 0.07, BACK_Y - 0.06, 2.36), (POST_X + 0.07, BACK_Y + 0.06, 2.54), "steel")

    # Conduit rails, each ending in its fittings' hearts.
    for y, z in ((FRONT_Y, FRONT_H), (BACK_Y, BACK_H)):
        pipe(m, [(-POST_X, y, z), (POST_X, y, z)], RAIL_R, 12, "steel")

    for x in (-POST_X, POST_X):
        drop = SIDE_RAIL_DROP
        pipe(m, [(x, FRONT_Y, FRONT_H - drop), (x, BACK_Y, BACK_H - drop)], RAIL_R, 12, "steel")

    # The herb pole, its ends in the front posts.
    pipe(m, [(-POST_X, FRONT_Y, POLE_Z), (POST_X, FRONT_Y, POLE_Z)], POLE_R, 10, "wood")

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
    for x in (-0.55, 0.55):
        box(m, (x - 0.025, FRONT_Y - 0.025, FRONT_H), (x + 0.025, FRONT_Y + 0.025, z0 + 0.025), "steel", r=0.02)


def frame_detail(m):
    # Bolts on the shoes.
    for x in (-POST_X, POST_X):
        for y in (FRONT_Y, BACK_Y):
            if (x, y) == LOST_SHOE:
                continue

            for dx, dy in ((-1, -1), (1, -1), (-1, 1), (1, 1)):
                bolt(m, x + dx * 0.058, y + dy * 0.058, SHOE[1])

    # Brass collars where the Company joined offcuts, slightly crooked.
    for x, y, z, tilt in ((-POST_X, FRONT_Y, 1.32, 0.04), (POST_X, FRONT_Y, 0.66, -0.05), (-POST_X, BACK_Y, 1.05, 0.03)):
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
    pipe(m, [(rx, ry, 2.05), (rx, ry, 1.35)], 0.015, 8, "paper")
    for k in range(16):
        a = k * 2.4
        z = 1.95 - k * 0.04
        turned(m, [(0.013, 0.0), (0.026, 0.02), (0.02, 0.07), (0.012, 0.1)], 5, "chile",
               at=(rx + 0.01 * math.cos(a), ry + 0.01 * math.sin(a), z), lean=2.3, towards=a, twist=a)

    # The cable from the sign's back to the junction box (the corridor's power).
    m.shell()
    shapes.sag(m, (0.62, SIGN_Y[1] - 0.04, 2.42), (POST_X - 0.02, BACK_Y - 0.03, 2.45), 0.015, 8, 0.07, 10, "steel")


def frame():
    main = _object("stall_frame", frame_main)
    detail = _object("stall_frame_detail", frame_detail)
    return join(main, [detail])


# --- the counter --------------------------------------------------------------------------------

def counter_main(m):
    # The carcass and its plinth, the front planks standing proud of it.
    box(m, (-COUNTER_X, PLANK_T, 0.06), (COUNTER_X, 0.5, COUNTER_TOP), "wood")
    box(m, (-COUNTER_X + 0.04, 0.1, 0.0), (COUNTER_X - 0.04, 0.46, 0.1), "wood")
    gap = 0.012
    widths = [rng.uniform(0.17, 0.28) for _ in range(9)]
    scale = (2 * COUNTER_X - gap * (len(widths) - 1)) / sum(widths)
    x = -COUNTER_X

    for k, w in enumerate(widths):
        w *= scale
        lift = rng.uniform(-0.02, 0.02)
        # The fifth board split once; she nailed in a board off a Metro hoarding.
        box(m, (x, 0.0, 0.07 + lift), (x + w, PLANK_T, 0.895 + lift), "paint_blue" if k == 4 else "wood", r=0.02)
        x += w + gap

    # Two battens nailed across the boards' faces.
    for z in (0.2, 0.72):
        box(m, (-COUNTER_X + 0.03, -0.05, z), (COUNTER_X - 0.03, 0.0, z + 0.075), "wood", r=0.02)

    # A batten across each end.
    for sx in (-1, 1):
        inner, outer = sx * COUNTER_X, sx * (COUNTER_X + 0.05)
        box(m, (min(inner, outer), 0.08, 0.42), (max(inner, outer), 0.47, 0.5), "wood", r=0.02)

    hw, front, back, t = SLAB
    box(m, (-hw, front, COUNTER_TOP), (hw, back, COUNTER_TOP + t), "wood")


def counter():
    return _object("stall_counter", counter_main)


# --- the shelving -------------------------------------------------------------------------------

def shelves_main(m):
    y0, y1 = SHELF_Y
    u = UPRIGHT / 2

    for sx in (-1, 1):
        box(m, (sx * SHELF_X - u, y0, 0.0), (sx * SHELF_X + u, y1, 2.0), "wood")

    for z in SHELVES:
        box(m, (-SHELF_X, y0, z), (SHELF_X, y1 - 0.02, z + SHELF_T), "wood")

    # The middle shelf sagged: a block under its middle holds it up.
    box(m, (-0.06, y0 + 0.05, SHELVES[1] - 0.12), (0.06, y1 - 0.06, SHELVES[1]), "wood", r=0.02)

    boards = 5
    for k in range(boards):
        z = 0.02 + k * 0.4
        if k == 2:
            # A back board gone; a shorter one, salvaged blue, in its place: the wall shows past it.
            box(m, (-SHELF_X, y1, z), (0.35, y1 + PLANK_T, z + 0.385), "paint_blue")
        else:
            box(m, (-SHELF_X, y1, z), (SHELF_X, y1 + PLANK_T, z + 0.385), "wood")


def shelves():
    return _object("stall_shelves", shelves_main)


# --- the canvas ---------------------------------------------------------------------------------

def _canvas_under(x, y):
    """Where the canvas's underside lies: on the rails' line, sagging
    between them, drooping past the side rails and over the front."""
    z = _rail_top(y) + RAIL_R + 0.004

    if FRONT_Y <= y <= BACK_Y:
        between = math.sin(math.pi * (y - FRONT_Y) / (BACK_Y - FRONT_Y))
        z -= 0.05 * between * math.cos(0.5 * math.pi * x / AWNING_X)
        z += 0.012 * between * math.sin(5.0 * math.pi * x / AWNING_X)
    elif y < FRONT_Y:
        z -= 0.05 * ((FRONT_Y - y) / (FRONT_Y - AWNING_FRONT)) ** 2

    beyond = max(0.0, abs(x) - POST_X) / (AWNING_X - POST_X)
    return z - 0.05 * beyond ** 2


def awning_main(m):
    cols, rows = 25, 11
    grid = []

    for i in range(rows):
        y = AWNING_FRONT + (BACK_Y + 0.14 - AWNING_FRONT) * i / (rows - 1)
        grid.append([(-AWNING_X + 2 * AWNING_X * j / (cols - 1), y,
                      _canvas_under(-AWNING_X + 2 * AWNING_X * j / (cols - 1), y)) for j in range(cols)])

    patches = [(range(3, 7), range(2, 5)), (range(15, 18), range(5, 8)), (range(20, 23), range(1, 3))]
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

def candle(m, x, y, z, r=0.04, h=0.2, sides=8):
    """A pillar candle, its top melted into a lip."""
    turned(m, [(r, 0.0), (r, h - 0.03), (r * 1.08, h - 0.012), (r * 0.9, h)], sides, "wax", at=(x, y, z),
           twist=rng.uniform(0, 1))


def jar(m, x, y, z, r=0.075, h=0.19, filling="herb", make="apothecary"):
    """A remedy jar, something steeping inside: an apothecary jar with a tin
    lid, a round-bellied one, or a tall bottle with a cork."""
    # What steeps inside keeps 4.5 cm clear of the glass, never thinner than the gate allows.
    c = max(0.02, r - 0.045)
    steeping = lambda top, base=0.035: turned(m, [(c, base), (c, top), (c * 0.85, top + 0.025)], 7, filling, at=(x, y, z),
                                  jitter=0.05)
    if make == "bottle":
        turned(m, [(r, 0.0), (r, h * 0.6), (r * 0.42, h * 0.78), (r * 0.42, h)], 10, "glass", at=(x, y, z))
        turned(m, [(r * 0.46, h), (r * 0.5, h + 0.035)], 8, "wood", at=(x, y, z))
        steeping(h * 0.4)
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


def clutter_main(m):
    # The shelves: candles in families, jars between.
    rows = {SHELVES[0] + SHELF_T: "candles", SHELVES[1] + SHELF_T: "jars", SHELVES[2] + SHELF_T: "mixed"}

    for z, kind in rows.items():
        x = -0.88

        while x < 0.86:
            pick = kind if kind != "mixed" else rng.choice(["candles", "jars", "pot"])

            if pick == "candles":
                n = rng.choice([2, 3])
                # Neighbours a hand apart: closer, their sides would sit near-parallel under the gate.
                for k in range(n):
                    candle(m, x + k * 0.12, 1.1 + rng.uniform(-0.03, 0.03), z, h=rng.uniform(0.14, 0.3))
                x += n * 0.12 + 0.06
            elif pick == "jars":
                # A huddle of two to four, then a gap: kept apart by their widest.
                for k in range(rng.choice([2, 3, 4])):
                    make = rng.choice(["apothecary", "apothecary", "belly", "bottle"])
                    r = rng.uniform(0.06, 0.08)
                    widest = r * (1.15 if make == "belly" else 1.0)
                    if x + widest > 0.9:
                        break
                    jar(m, x + widest, 1.1 + rng.uniform(-0.015, 0.015), z, r=r, h=rng.uniform(0.15, 0.26),
                        filling=rng.choice(["herb", "herb_dry", "wax", "clay"]), make=make)
                    x += 2 * widest + 0.035
                x += rng.uniform(0.08, 0.16)
            else:
                pot(m, x + 0.06, 1.1, z)
                x += 0.24

    # On top of the shelving, under the canvas.
    shelf_top = 2.0
    turned(m, [(0.11, 0.0), (0.15, 0.08), (0.16, 0.12)], 10, "herb_dry", at=(-0.6, 1.1, shelf_top))
    turned(m, [(0.11, 0.1), (0.15, 0.15), (0.06, 0.19)], 9, "herb", at=(-0.6, 1.1, shelf_top), jitter=0.2)
    box(m, (-0.2, 1.0, shelf_top), (0.12, 1.24, shelf_top + 0.12), "tin", r=0.025)
    turned(m, [(0.05, 0.0), (0.05, 0.1), (0.055, 0.11)], 8, "tin", at=(0.45, 1.12, shelf_top))

    for k in range(3):
        a = 2 * math.pi * k / 3
        turned(m, [(0.016, 0.06), (0.016, 0.24)], 6, "wax", at=(0.45 + 0.022 * math.cos(a), 1.12 + 0.022 * math.sin(a),
                                                               shelf_top), lean=0.12, towards=a)

    # The counter: copal smoking in a censer, eggs for a limpia, packets of herbs.
    top = COUNTER_TOP + SLAB[3]
    turned(m, [(0.05, 0.0), (0.05, 0.03), (0.035, 0.05)], 8, "tin", at=(0.62, 0.22, top))
    turned(m, [(0.035, 0.05), (0.09, 0.09), (0.1, 0.14), (0.085, 0.15)], 10, "tin", at=(0.62, 0.22, top))
    turned(m, [(0.06, 0.13), (0.07, 0.17), (0.045, 0.205)], 8, "wax", at=(0.62, 0.22, top), jitter=0.2)
    turned(m, [(0.07, 0.0), (0.12, 0.05), (0.13, 0.08), (0.12, 0.085)], 10, "clay", at=(0.18, 0.12, top))

    for k, (dx, dy) in enumerate(((-0.04, 0.0), (0.04, 0.02), (0.0, -0.045))):
        turned(m, [(0.015, 0.0), (0.035, 0.02), (0.033, 0.055), (0.015, 0.075)], 8, "paper",
               at=(0.18 + dx, 0.12 + dy, top + 0.05 - k * 0.002))

    for k in range(3):
        m.shell()
        shapes.obox(m, (-0.3 + k * 0.03, 0.3, top + 0.0175 + k * 0.036), (0.16, 0.11, 0.035),
                    (0.0, 0.0, rng.uniform(-0.3, 0.3)), "paper")

    # A molcajete and its pestle, basalt, on three stubby legs.
    mx, my = -0.52, 0.36
    for k in range(3):
        a = k * 2 * math.pi / 3 + 0.3
        turned(m, [(0.022, 0.0), (0.024, 0.04)], 6, "stone", at=(mx + 0.06 * math.cos(a), my + 0.06 * math.sin(a), top))
    turned(m, [(0.06, 0.035), (0.115, 0.06), (0.125, 0.1), (0.105, 0.115)], 10, "stone", at=(mx, my, top), jitter=0.06)
    turned(m, [(0.026, 0.09), (0.036, 0.14), (0.03, 0.19)], 7, "stone", at=(mx, my, top), lean=0.45, towards=0.8)

    # Her hand bell, brass, at the counter's end; her tin cash box at the back.
    bx, by = 0.9, 0.3
    turned(m, [(0.06, 0.0), (0.062, 0.012), (0.05, 0.04), (0.04, 0.075), (0.022, 0.095)], 12, "brass", at=(bx, by, top))
    turned(m, [(0.014, 0.09), (0.014, 0.13), (0.026, 0.145), (0.022, 0.17)], 8, "wood", at=(bx, by, top))
    box(m, (0.18, 0.4, top), (0.4, 0.53, top + 0.085), "tin", r=0.02)

    # A salvaged enamel sign bolted across the boards between the battens, its face blank (the user's words).
    m.shell()
    shapes.panel(m, (-0.62, -0.045, 0.32), (-0.08, 0.0, 0.68), 0.04, "enamel", "sign")
    for sx in (-0.6, -0.1):
        for sz in (0.34, 0.66):
            stud(m, (sx, -0.045, sz), math.pi / 2, 0.0, "steel", r=0.02)

    # Nail heads along the battens.
    for z in (0.2375, 0.7575):
        for k in range(7):
            stud(m, (-0.9 + k * 0.3 + rng.uniform(-0.02, 0.02), -0.05, z), math.pi / 2, 0.0, "steel", r=0.02)

    # Price cards on twine from the top shelf's lip, hanging in front of the jars.
    for k, cx in enumerate((-0.62, -0.18, 0.28, 0.66)):
        drop = 0.04 + 0.025 * (k % 2)
        pipe(m, [(cx, 0.9, SHELVES[2] + 0.01), (cx, 0.9, SHELVES[2] - drop)], 0.011, 6, "paper")
        box(m, (cx - 0.045, 0.862, SHELVES[2] - drop - 0.06), (cx + 0.045, 0.886, SHELVES[2] - drop), "paper", r=0.0)

    # A bundle of tapers tied with twine on the top shelf's end.
    tx, ty, tz = 0.75, 1.1, SHELVES[2] + SHELF_T
    for k in range(5):
        a = k * 2 * math.pi / 5
        turned(m, [(0.016, 0.0), (0.016, 0.26)], 6, "wax", at=(tx + 0.03 * math.cos(a), ty + 0.03 * math.sin(a), tz))
    ring = [(tx + 0.058 * math.cos(a), ty + 0.058 * math.sin(a), tz + 0.12) for a in (2 * math.pi * n / 8 for n in range(8))]
    pipe(m, ring, 0.012, 6, "paper", closed=True)

    # Behind the counter: her stool, and a crate of bottles.
    box(m, (0.25, 0.68, 0.58), (0.6, 0.86, 0.64), "wood", r=0.02)
    for lx in (0.29, 0.56):
        for ly in (0.71, 0.83):
            box(m, (lx - 0.025, ly - 0.025, 0.0), (lx + 0.025, ly + 0.025, 0.58), "wood", r=0.0)
    box(m, (-0.85, 0.62, 0.0), (-0.45, 0.88, 0.28), "wood", r=0.025)
    for k in range(3):
        turned(m, [(0.04, 0.0), (0.04, 0.16), (0.017, 0.22), (0.017, 0.27)], 8, "glass", at=(-0.75 + k * 0.12, 0.75, 0.28))

    # Herbs hung from the pole, clear of the ofrenda.
    herbs = random.Random(9)

    for k in range(9):
        bundle(m, -0.55 + k * 0.19 + herbs.uniform(-0.03, 0.03), herbs.uniform(0.3, 0.46), herbs.uniform(0.06, 0.09),
               herbs.choice(["herb", "herb", "herb_dry"]), seed=100 + k)

def clutter():
    return _object("stall_clutter", clutter_main)


# --- the bulb (its own object: it sways in the corridor's draught) --------------------------------

BULB_AT = (0.0, 0.62, 1.84)


def bulb_main(m):
    """The bulb on its cord under the canvas, the cord's top just inside the cloth."""
    x, y, z = BULB_AT
    pipe(m, [(x, y, _canvas_under(x, y) + 0.012), (x, y, z + 0.02)], 0.011, 6, "steel")
    turned(m, [(0.024, -0.03), (0.024, 0.01), (0.018, 0.02)], 8, "brass", at=BULB_AT)
    turned(m, [(0.02, -0.03), (0.045, -0.07), (0.05, -0.11), (0.03, -0.15), (0.015, -0.16)], 10, "glass", at=BULB_AT)


def bulb():
    return _object("stall_bulb", bulb_main)


# --- her ofrenda --------------------------------------------------------------------------------

def ofrenda_main(m):
    x0, x1, y0, y1 = -1.07, -0.69, 0.12, 0.46
    z0 = COUNTER_TOP + SLAB[3]
    t = 0.05
    wall = 0.44
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
    top = z0 + wall

    for side in (-1, 1):
        # Up the slope from the wall's outer top edge towards the middle, and out of the board.
        up = Vector((-side * math.cos(pitch), 0.0, math.sin(pitch)))
        out = Vector((side * math.sin(pitch), 0.0, math.cos(pitch)))
        edge = Vector((mid + side * span, 0.0, top))
        centre = edge + up * (length / 2 - eave) + out * (board / 2)
        box(m, (centre.x - length / 2, y0 - 0.06, centre.z - board / 2),
            (centre.x + length / 2, y1 + 0.03, centre.z + board / 2), "wood", r=0.02, turn=(0.0, side * pitch, 0.0))

    box(m, (mid - 0.035, y0 - 0.07, top + rise), (mid + 0.035, y1 + 0.04, top + rise + 0.07), "wood", r=0.02)
    m.shell()
    gable = lambda y: [(x0 + 0.01, y, top - 0.01), (x1 - 0.01, y, top - 0.01), (mid, y, top + rise - 0.02)]
    shapes.loft(m, [gable(y1 - t), gable(y1)], "wood", caps=True)

    # The saint's print in a brass frame on the back wall.
    m.shell()
    shapes.panel(m, (-0.98, y1 - t - 0.05, z0 + 0.12), (-0.78, y1 - t, z0 + 0.4), 0.035, "brass", "paper")

    # Marigolds in a clay jar, and a candle.
    cx, cy = -0.95, 0.2
    turned(m, [(0.035, 0.0), (0.045, 0.05), (0.03, 0.09), (0.035, 0.1)], 8, "clay", at=(cx, cy, z0 + t))

    heads = [(0.0, 0.0, 0.16)] + [(0.045 * math.cos(k * 2 * math.pi / 6), 0.045 * math.sin(k * 2 * math.pi / 6),
                                     0.1 + rng.uniform(0.0, 0.05)) for k in range(6)]

    for dx, dy, dz in heads:
        fx, fy, fz = cx + dx, cy + dy, z0 + t + dz
        turned(m, [(0.018, 0.0), (0.042, 0.014), (0.038, 0.026), (0.046, 0.038), (0.041, 0.05), (0.04, 0.062), (0.02, 0.078)], 8, "marigold",
               at=(fx, fy, fz), jitter=0.08, twist=rng.uniform(0, 1))

    candle(m, -0.8, 0.22, z0 + t, r=0.04, h=0.12)

    m.shell()
    shapes.panel(m, (-0.88, 0.29, z0 + t), (-0.76, 0.33, z0 + t + 0.15), 0.025, "brass", "paper")
    box(m, (-1.0, 0.13, z0 + t), (-0.93, 0.2, z0 + t + 0.065), "wax", r=0.02)
    for ex in (-0.982, -0.948):
        stud(m, (ex, 0.13, z0 + t + 0.042), math.pi / 2, 0.0, "marigold", r=0.017)

    for fx, fy in ((-0.86, 0.33), (-0.8, 0.36)):
        turned(m, [(0.018, 0.0), (0.042, 0.014), (0.038, 0.026), (0.046, 0.038), (0.041, 0.05), (0.04, 0.062), (0.02, 0.078)], 8, "marigold",
               at=(fx, fy, z0 + t), jitter=0.08, twist=rng.uniform(0, 1))


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
    "01_shoe_post": ((-0.7, -0.5, 0.4), (-POST_X, FRONT_Y, 0.06)),
    "02_counter_front": ((0.6, -1.1, 0.9), (0.0, 0.0, 0.5)),
    "03_counter_slab_post": ((1.6, -0.6, 1.3), (POST_X, FRONT_Y, COUNTER_TOP)),
    "04_shelves": ((0.4, 0.2, 1.5), (0.0, 1.1, 1.1)),
    "05_rail_fittings": ((-0.6, -0.6, 2.4), (-POST_X, FRONT_Y, FRONT_H)),
    "06_awning_flap": ((0.5, -1.2, 1.9), (0.0, AWNING_FRONT, 1.95)),
    "07_sign_uprights": ((0.9, -0.8, 2.2), (0.55, FRONT_Y, 2.1)),
    "08_neon_standoffs": ((0.5, -0.7, 2.5), (0.6, 0.0, 2.35)),
    "09_herbs_pole": ((0.3, -0.8, 1.8), (0.0, FRONT_Y, 1.7)),
    "10_ofrenda": ((-0.6, -0.5, 1.3), (-0.88, 0.3, 1.2)),
    "11_censer_eggs": ((0.4, -0.5, 1.3), (0.4, 0.2, 1.05)),
    "12_junction_cable": ((1.6, 0.6, 2.8), (POST_X, BACK_Y, 2.45)),
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
