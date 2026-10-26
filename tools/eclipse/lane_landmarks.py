"""The candle lane's landmarks (docs/superpowers/specs/2026-10-24-lane-landmarks-design.md; plan
docs/superpowers/plans/2026-10-25-lane-landmarks.md): what makes the curandera's stall and the librarian's shop read from
the Pasaje.
- garland: her cempasúchil garland strung across the lane from a riser lashed to her stall's east front post to an iron
  hook-plate on the south wall, sagging, papel picado flags hung under it (cut abstract, no letters). She strings it
  each season for the dead she prays for. Over the walk (lane z 0.2-2.6) nothing of it hangs under 2.6 m.
- milagro_heart: a pressed-tin sacred heart (its raised rim, a crown of thorns, gilt flames and a cross at its top, tin
  rays round it), built with its hanging ring at its own origin so the lane turns it there. Offerings left by those she
  healed are nailed to her frame; this big one hangs out over the walk to be seen.
- milagro_bracket: the scrolled iron arm it hangs from, off her stall's west front post.
Built where they stand in the lane (x along it, y the lane's -z, z up: Godot's x, -z, y) and set at the lane's origin.
    Blender -b --factory-startup --python tools/eclipse/lane_landmarks.py
"""

import math
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import common  # noqa: E402
import underground_shapes  # noqa: E402
from mathutils import Vector  # noqa: E402
from underground_shapes import box, pipe, smooth_object, turned  # noqa: E402

NAME = "lane_landmarks"
ATLAS = 2048
SLOTS = ["marigold", "herb", "picado", "picado_b", "iron", "tin", "brass", "wax_red", "glass_red"]
# (The garland is a rope of heads ~15 cm thick, three round the cord at each step, so it reads from the Pasaje.)
BUDGET = {"garland": 6000, "milagro_heart": 2000, "milagro_bracket": 1200, "red_lantern": 2500}
# Cords, flags and lashings are millimetres across by nature: a face there is a sliver under 4 mm.
SLIVER = {name: 0.004 for name in BUDGET}

rng = random.Random(2410)

# The lane (maps/candle_lane.gd): its south wall's tile face (lane z).
FAR_WALL = 4.55
# Her stall (tools/eclipse/stall.py): its east front post (lane x), its front rail's height.
POST_X = 1.5
FRONT_H = 2.35
# The garland (lane x, z, height): the riser's top (where it ties on), the hook on the south wall, how far it sags, its heads' size and
# spacing, its flags (across, tall) and how many.
TIE = (POST_X + 0.07, -0.04, 3.32)
HOOK = (1.95, FAR_WALL - 0.1, 3.42)
SAG = 0.28
HEAD_R = 0.055
HEAD_EVERY = 0.075
HEADS_ROUND = 3
FLAG = (0.24, 0.28)
FLAGS = 7
# The tin heart (its own frame: the ring at the origin, the heart's face toward -x, the mouth): its body's height and
# width, its plate's thickness, the flames' height. Her stall's west front post (lane x) and where the bracket's hook
# hangs (lane x, z, height).
HEART = (0.46, 0.46)
HEART_T = 0.022
FLAME_H = 0.13
WEST_POST_X = -1.5
HOOK_AT = (-1.35, 0.45, 3.0)
# Her votive for those she healed, in a tin cup on an iron ring on the same post, under the heart: the cup's middle
# (lane x, z, height), its size, the candle stub's height (its wick is CANDLE_WICK, where the lane lights its flame).
CUP_AT = (-1.55, 0.12, 2.42)
CUP = (0.04, 0.07)
STUB_H = 0.05
CANDLE_WICK = (CUP_AT[0], CUP_AT[1], CUP_AT[2] + CUP[1] / 2 + STUB_H + 0.01)
# His red lantern over the arch (lane x, z, height): the arch's middle, its bracket's height on the wall (above the fire
# main, its flanges' top at 3.21), how far out it hangs, the lantern's square and its glass's height, the cap's.
ARCH_X = 6.2
ARM_H = 3.4
LANTERN_Z = 3.9
LANTERN_W = 0.2
GLASS = (2.95, 3.22)
CAP_H = 0.1
# (Base and cap rim 4.5 cm deep: at 3 cm the glass's top and bottom lay over theirs, layered.)
PLATE_T = 0.045


def _lane(x, z, y):
    """A point given in the lane's (x along, z across, y up), in Blender's axes."""
    return Vector((x, -z, y))


def _rope(a, b, sag, n=24):
    """Points along a cord from `a` to `b` (Blender), sagging `sag` at its middle."""
    return [a.lerp(b, k / n) - Vector((0, 0, sag * 4 * (k / n) * (1 - k / n))) for k in range(n + 1)]


def garland(m):
    """Her cempasúchil garland across the lane, from her riser to the south wall's hook, its flags under it."""
    tie = _lane(*TIE)
    hook = _lane(*HOOK)
    # The riser: an iron rod lashed to her post above the rail, its top bent into an eye.
    foot = _lane(TIE[0], TIE[1], FRONT_H - 0.12)
    pipe(m, [foot, tie + Vector((0, 0, 0.04))], 0.016, 6, "iron")
    for h in (FRONT_H - 0.05, FRONT_H + 0.25):
        m.shell()
        ring = [_lane(TIE[0] - 0.035 + 0.05 * math.cos(a), TIE[1] + 0.05 * math.sin(a), h)
                for a in (2 * math.pi * k / 6 for k in range(6))]
        pipe(m, ring, 0.009, 4, "herb", closed=True)
    # The hook-plate on the wall, its ring.
    box(m, _lane(HOOK[0] - 0.07, FAR_WALL - 0.018, HOOK[2] - 0.09), _lane(HOOK[0] + 0.07, FAR_WALL, HOOK[2] + 0.09),
        "iron", r=0.006)
    pipe(m, [_lane(HOOK[0], FAR_WALL - 0.018, HOOK[2]), hook], 0.01, 6, "iron")
    # The cord and its heads, crowded along it.
    cord = _rope(tie, hook, SAG)
    pipe(m, cord, 0.008, 4, "herb")
    length = sum((cord[k + 1] - cord[k]).length for k in range(len(cord) - 1))
    heads = int(length / HEAD_EVERY)
    for k in range(1, heads):
        t = k / heads
        on = tie.lerp(hook, t) - Vector((0, 0, SAG * 4 * t * (1 - t)))
        across = (hook - tie).normalized().cross(Vector((0, 0, 1))).normalized()
        # (Three round the cord, turned a little at each step: a rope of heads, not a string of beads.)
        for j in range(HEADS_ROUND):
            a = 2 * math.pi * j / HEADS_ROUND + k * 0.9
            at = on + across * math.cos(a) * HEAD_R * 0.75 + Vector((0, 0, math.sin(a) * HEAD_R * 0.75 - HEAD_R * 0.3))
            at += Vector((rng.uniform(-0.01, 0.01), rng.uniform(-0.01, 0.01), rng.uniform(-0.01, 0.01)))
            m.shell()
            m.sphere(tuple(at), HEAD_R * rng.uniform(0.85, 1.1), 3, 6, "marigold")
    # The flags, hung from the cord between the heads, each a little turned in the draught.
    along = (hook - tie).normalized()
    side = along.cross(Vector((0, 0, 1))).normalized()
    w, h = FLAG
    for k in range(1, FLAGS + 1):
        t = (k - 0.5) / FLAGS
        top = tie.lerp(hook, t) - Vector((0, 0, SAG * 4 * t * (1 - t) + HEAD_R * 1.4))
        turn = side * rng.uniform(-0.03, 0.03)
        corners = [top - along * w / 2, top + along * w / 2, top + along * w / 2 - Vector((0, 0, h)) + turn,
                   top - along * w / 2 - Vector((0, 0, h)) + turn]
        front = [c - side * 0.006 for c in corners]
        back = [c + side * 0.006 for c in corners]
        slot = "picado" if k % 2 else "picado_b"
        m.shell()
        m.face(front, slot)
        m.face(back[::-1], slot)
        for i in range(4):
            m.face([front[(i + 1) % 4], front[i], back[i], back[(i + 1) % 4]], slot)


def _heart_outline(n=28):
    """The heart's edge [(y, z)] (Blender, its face toward -x), its notch at the top (index 0), its tip at the bottom
    (index n/2); HEART tall and wide, its top at z 0. Its points are spaced evenly along it (the curve's own steps
    bunch at the tip into slivers), one half mirrored onto the other."""
    dense = []
    for k in range(401):
        t = math.pi * k / 400
        dense.append((16 * math.sin(t) ** 3,
                      13 * math.cos(t) - 5 * math.cos(2 * t) - 2 * math.cos(3 * t) - math.cos(4 * t)))
    run = [0.0]
    for a, b in zip(dense, dense[1:]):
        run.append(run[-1] + math.dist(a, b))
    half = n // 2
    right = []
    j = 0
    for k in range(half + 1):
        want = run[-1] * k / half
        while j < len(run) - 2 and run[j + 1] < want:
            j += 1
        right.append(dense[j])
    pts = right + [(-y, z) for y, z in reversed(right[1:-1])]
    ys = [p[0] for p in pts]
    zs = [p[1] for p in pts]
    sy = HEART[1] / (max(ys) - min(ys))
    sz = HEART[0] / (max(zs) - min(zs))
    top = max(zs)
    return [(y * sy, (z - top) * sz) for y, z in pts]


def _fan_plate(m, outline, x0, x1, slot, centre, parts=None):
    """An outline [(y, z)] drawn across x from x0 to x1 (Blender): its two faces fans of triangles about `centre`
    (every face convex, the outline star-shaped about it), or `parts` [(indices, centre)], polygons of the outline's
    points that tile it, each fanned about its own centre; its edge quads."""
    m.shell()
    n = len(outline)
    for indices, (cy, cz) in parts or [(list(range(n)), centre)]:
        poly = [outline[k % n] for k in indices]
        for a, b in zip(poly, poly[1:] + poly[:1]):
            m.face([(x0, cy, cz), (x0, b[0], b[1]), (x0, a[0], a[1])], slot)
            m.face([(x1, cy, cz), (x1, a[0], a[1]), (x1, b[0], b[1])], slot)
    for k in range(n):
        a, b = outline[k], outline[(k + 1) % n]
        m.face([(x0, a[0], a[1]), (x0, b[0], b[1]), (x1, b[0], b[1]), (x1, a[0], a[1])], slot)


def milagro_heart(m):
    """The tin sacred heart, its ring at the origin: flames and a cross over the notch, the heart under them, its rim
    raised, a crown of thorns round it, rays standing out round its edge."""
    ring_r = 0.022
    m.shell()
    ring = [(0.0, ring_r * math.cos(a), -ring_r - ring_r * math.sin(a)) for a in (2 * math.pi * k / 8 for k in range(8))]
    pipe(m, ring, 0.005, 4, "iron", closed=True)
    # The flames: three tongues rising off the notch, the middle tallest, a little cross out of it.
    under = -2 * ring_r - 0.004
    heart_top = under - FLAME_H
    for dy, h in ((-0.045, 0.75), (0.0, 1.0), (0.045, 0.75)):
        base = heart_top + 0.01
        tip = base + FLAME_H * h
        tongue = [(dy - 0.03, base), (dy + 0.03, base), (dy + 0.022, base + (tip - base) * 0.5), (dy, tip),
                  (dy - 0.022, base + (tip - base) * 0.5)]
        _fan_plate(m, tongue, -0.008, 0.008, "brass", (dy, base + (tip - base) * 0.3))
    box(m, (-0.006, -0.004, under - 0.03), (0.006, 0.004, under + 0.004), "brass", r=0.002)
    box(m, (-0.006, -0.016, under - 0.018), (0.006, 0.016, under - 0.01), "brass", r=0.002)
    # The heart itself, its raised rim, the crown of thorns across it.
    # (Four polygons tile it, each fanned from its own middle: the two lobes, the tip, and the triangle between the
    # notch and the sides. One centre made slivers at the notch or the tip, where the edges run at it.)
    outline = [(y, heart_top + z) for y, z in _heart_outline()]

    def middle(indices):
        return (sum(outline[k % 28][0] for k in indices) / len(indices),
                sum(outline[k % 28][1] for k in indices) / len(indices))

    right, tip, left, notch = list(range(0, 11)), list(range(10, 19)), list(range(18, 29)), [0, 10, 18]
    _fan_plate(m, outline, -HEART_T / 2, HEART_T / 2, "tin", None,
               parts=[(right, middle(right)), (tip, middle(tip)), (left, middle(left)), (notch, middle(notch))])
    m.shell()
    rim = [(-HEART_T / 2 - 0.004, y * 0.94, heart_top + z * 0.94 - HEART[0] * 0.03) for y, z in _heart_outline()]
    pipe(m, rim, 0.006, 4, "tin", closed=True)
    m.shell()
    thorns = [(-HEART_T / 2 - 0.006, 0.12 * math.cos(a), heart_top - HEART[0] * 0.42 + 0.035 * math.sin(a))
              for a in (2 * math.pi * k / 12 for k in range(12))]
    pipe(m, thorns, 0.007, 4, "iron", closed=True)
    # The rays, standing out round the heart's edge (outside it, never behind it).
    cy, cz = 0.0, heart_top - HEART[0] * 0.5
    for k in range(14):
        a = math.pi * 0.15 + (math.pi * 1.7) * k / 13
        d = (math.sin(a), -math.cos(a))
        inner = HEART[0] * 0.62 + 0.01
        outer = inner + (0.06 if k % 2 else 0.035)
        p0 = (cy + d[0] * inner, cz + d[1] * inner)
        p1 = (cy + d[0] * outer, cz + d[1] * outer)
        side = (-d[1] * 0.008, d[0] * 0.008)
        ray = [(p0[0] - side[0], p0[1] - side[1]), (p0[0] + side[0], p0[1] + side[1]), p1]
        # (A ray is a triangle already: one face a side, not a fan of slivers.)
        m.shell()
        m.face([(-0.004, y, z) for y, z in ray[::-1]], "tin")
        m.face([(0.004, y, z) for y, z in ray], "tin")
        for a, b in zip(ray, ray[1:] + ray[:1]):
            m.face([(-0.004, a[0], a[1]), (-0.004, b[0], b[1]), (0.004, b[0], b[1]), (0.004, a[0], a[1])], "tin")


def milagro_bracket(m):
    """The scrolled iron arm off her stall's west front post that the heart hangs from, its hook over the walk."""
    hx, hz, hy = HOOK_AT
    post = _lane(WEST_POST_X, 0.0, hy + 0.12)
    out = _lane(hx, hz, hy + 0.12)
    pipe(m, [post, out], 0.012, 6, "iron")
    # The stay under it, and the scroll at its end.
    m.shell()
    pipe(m, [_lane(WEST_POST_X, 0.0, hy - 0.2), _lane((WEST_POST_X + hx) / 2, hz * 0.55, hy + 0.11)], 0.008, 4, "iron")
    m.shell()
    # (Curling in to a third of its size, never back onto where it started.)
    scroll = [out + Vector((0.0, -0.035 * math.sin(a) * (1 - 0.07 * k), 0.035 * (math.cos(a) - 1) * (1 - 0.07 * k)))
              for k, a in enumerate(2.2 * math.pi * j / 10 for j in range(11))]
    pipe(m, scroll, 0.007, 4, "iron")
    # The plate it is bolted to on the post, the hook the ring hangs on.
    box(m, post + Vector((-0.04, -0.01, -0.06)), post + Vector((0.04, 0.03, 0.06)), "iron", r=0.004)
    m.shell()
    pipe(m, [out, _lane(hx, hz, hy + 0.02), _lane(hx, hz - 0.02, hy)], 0.005, 4, "iron")
    # Her votive under it: an iron ring off the post holding a tin cup, a red candle stub in it.
    cx, cz, cy = CUP_AT
    r, h = CUP
    m.shell()
    pipe(m, [_lane(WEST_POST_X, 0.0, cy - h / 2), _lane(cx, cz, cy - h / 2)], 0.006, 4, "iron")
    m.shell()
    ring = [_lane(cx + (r + 0.006) * math.cos(a), cz + (r + 0.006) * math.sin(a), cy - h / 2)
            for a in (2 * math.pi * k / 8 for k in range(8))]
    pipe(m, ring, 0.005, 4, "iron", closed=True)
    turned(m, [(r * 0.8, -h / 2), (r, -h / 2 + 0.006), (r, h / 2), (r * 0.72, h / 2)], 10, "tin",
           at=tuple(_lane(cx, cz, cy)))
    turned(m, [(r * 0.55, h / 2 - 0.01), (r * 0.55, h / 2 + STUB_H), (r * 0.15, h / 2 + STUB_H + 0.004)], 8, "wax_red",
           at=tuple(_lane(cx, cz, cy)))


def red_lantern(m):
    """His lantern of red glass on an iron bracket over the arch: the bracket's plate above the fire main, its arm out
    over the threshold with a stay and a scroll, the lantern hung from its hook (square base, corner posts just outside
    the glass, a peaked cap, a ring). A bookseller who works by night; the glass is old darkroom glass."""
    wall = 4.55
    x = ARCH_X
    # The plate on the wall, the arm, the stay up to it, the scroll at its end, the hook.
    box(m, _lane(x - 0.05, wall - 0.016, ARM_H - 0.09), _lane(x + 0.05, wall, ARM_H + 0.09), "iron", r=0.004)
    pipe(m, [_lane(x, wall - 0.016, ARM_H), _lane(x, LANTERN_Z, ARM_H)], 0.013, 6, "iron")
    m.shell()
    pipe(m, [_lane(x, wall - 0.016, ARM_H - 0.08), _lane(x, (wall + LANTERN_Z) / 2, ARM_H - 0.005)], 0.008, 4, "iron")
    m.shell()
    end = _lane(x, LANTERN_Z, ARM_H)
    scroll = [end + Vector((0.0, 0.035 * math.sin(a) * (1 - 0.07 * k), 0.035 * (math.cos(a) - 1) * (1 - 0.07 * k)))
              for k, a in enumerate(2.2 * math.pi * j / 10 for j in range(11))]
    pipe(m, scroll, 0.007, 4, "iron")
    top = GLASS[1] + PLATE_T + CAP_H
    m.shell()
    pipe(m, [_lane(x, LANTERN_Z + 0.02, ARM_H), _lane(x, LANTERN_Z, ARM_H - 0.04), _lane(x, LANTERN_Z, top + 0.035)],
         0.005, 4, "iron")
    m.shell()
    ring = [_lane(x, LANTERN_Z + 0.018 * math.cos(a), top + 0.018 + 0.018 * math.sin(a))
            for a in (2 * math.pi * k / 8 for k in range(8))]
    pipe(m, ring, 0.004, 4, "iron", closed=True)
    # The lantern: base, glass, posts outside its corners, the cap's rim and its peak.
    h = LANTERN_W / 2
    z = LANTERN_Z
    box(m, _lane(x - h - 0.03, z - h - 0.03, GLASS[0] - PLATE_T), _lane(x + h + 0.03, z + h + 0.03, GLASS[0]), "iron", r=0.004)
    box(m, _lane(x - h, z - h, GLASS[0]), _lane(x + h, z + h, GLASS[1]), "glass_red", r=0.0)
    for sx in (-1, 1):
        for sz in (-1, 1):
            cx, cz = x + sx * (h + 0.012), z + sz * (h + 0.012)
            box(m, _lane(cx - 0.012, cz - 0.012, GLASS[0]), _lane(cx + 0.012, cz + 0.012, GLASS[1]), "iron", r=0.0)
    box(m, _lane(x - h - 0.035, z - h - 0.035, GLASS[1]), _lane(x + h + 0.035, z + h + 0.035, GLASS[1] + PLATE_T), "iron",
        r=0.004)
    m.shell()
    rim = [_lane(x + sx * (h + 0.02), z + sz * (h + 0.02), GLASS[1] + PLATE_T) for sx, sz in ((-1, -1), (1, -1), (1, 1),
                                                                                     (-1, 1))]
    apex = _lane(x, z, top)
    m.face(rim[::-1], "iron")
    for a, b in zip(rim, rim[1:] + rim[:1]):
        m.face([a, b, apex], "iron")
    # The finial under it.
    turned(m, [(0.03, -0.06), (0.012, -0.005), (0.02, 0.0)], 8, "iron", at=tuple(_lane(x, z, GLASS[0] - PLATE_T)))


def build():
    common.reset()
    underground_shapes.rng = rng
    rng.seed(2410)
    for f in (garland, milagro_heart, milagro_bracket, red_lantern):
        smooth_object(f.__name__, f)


def main():
    build()
    common.export_piece(NAME, ATLAS, SLOTS, out=common.ROOT / "assets" / "eclipse" / "kit", sets_each=True,
                        budget=max(BUDGET.values()), sliver=min(SLIVER.values()))


if __name__ == "__main__":
    main()
