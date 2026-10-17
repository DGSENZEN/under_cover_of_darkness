"""A district plan as plain geometry to walk before any kit exists (the
Zócalo spec, section 5, step 2): the street as one ground cut round its
sunken places, each sunken place a floor and walls, each plot a block with
its roof, each underground space a room with gaps at its openings, each
route a stair, slab, plank, climbing board or tunnel. A plan with no brink
(the Metro Underground) has no street ground and no cliff. Overlap-gated
here, and no two spaces may share any volume (stacked rooms keep a slab
between); Godot only loads it (scripts/Level/GreyboxLoader.gd).

    python3 tools/level/greybox.py <plan.json> <greybox.json>   (exits 1 if the gate fails)
"""

import json
import math
import os
import sys
from collections import defaultdict
from pathlib import Path

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
sys.path.insert(0, os.path.join(HERE, "layouts"))

import overlap  # noqa: E402
import plan  # noqa: E402
import plan_check  # noqa: E402

# How far the brink's cliff falls into the void (m).
CLIFF = 20.0
# Openings in walls (m): their height; how near an opening must lie to a wall.
GAP_HEIGHT = 3.0
ON_WALL = 0.05
# Routes (m): stair width; bridge width and thickness; plank width and
# thickness; how far decks stand proud of what they rest on; the climbing
# board's width and depth; tunnel width and height.
STAIR_WIDTH = 2.4
BRIDGE = (4.0, 0.4)
PLANK = (0.8, 0.15)
PROUD = 0.1
BOARD = (0.6, 0.05)
# The board stands this far off the wall (m).
BOARD_OFF = 0.02
TUNNEL = (3.0, 3.0)
# Same-facing faces nearer than this (m) fight (tools/eclipse/gate.py's
# LAYER_GAP; checked by bucket here, there pair by pair).
LAYER_GAP = 0.03


# Faces

def _sub(a, b):
    return [a[0] - b[0], a[1] - b[1], a[2] - b[2]]


def _newell(points):
    n = [0.0, 0.0, 0.0]

    for a, b in zip(points, points[1:] + points[:1]):
        n[0] += (a[1] - b[1]) * (a[2] + b[2])
        n[1] += (a[2] - b[2]) * (a[0] + b[0])
        n[2] += (a[0] - b[0]) * (a[1] + b[1])

    return n


def _unit(v):
    length = math.sqrt(sum(c * c for c in v))
    return [c / length for c in v] if length > 1e-12 else [0.0, 1.0, 0.0]


def face(points, facing):
    """A planar face turned to look the way of `facing`, with its normal."""
    points = [[float(c) for c in p] for p in points]
    n = _newell(points)

    if sum(n[k] * facing[k] for k in range(3)) < 0:
        points.reverse()
        n = [-c for c in n]

    return {"points": points, "normal": _unit(n)}


def _quad(a, b, y0, y1, facing):
    """A vertical quad over the ground line a-b (x, z), from y0 to y1."""
    return face([(a[0], y0, a[1]), (b[0], y0, b[1]), (b[0], y1, b[1]), (a[0], y1, a[1])], facing)


def _outward(a, b):
    dx, dz = b[0] - a[0], b[1] - a[1]
    length = math.hypot(dx, dz)
    return (dz / length, -dx / length)


def _edges(polygon):
    pts = [tuple(p) for p in polygon]
    return list(zip(pts, pts[1:] + pts[:1]))


def _wall(a, b, y0, y1, facing, gaps=(), solid=()):
    """A wall over a-b from y0 to y1, cut by gaps (t0, t1, gy0, gy1) along
    it in metres from a; (t0, t1) in `solid` are left out altogether."""
    length = math.hypot(b[0] - a[0], b[1] - a[1])
    cuts = {0.0, length}

    for t0, t1, *_ in list(gaps) + list(solid):
        cuts.update((max(0.0, min(length, t0)), max(0.0, min(length, t1))))

    cuts = sorted(cuts)
    out = []
    at = lambda t: (a[0] + (b[0] - a[0]) * t / length, a[1] + (b[1] - a[1]) * t / length)

    for u, v in zip(cuts, cuts[1:]):
        if v - u < 1e-6:
            continue

        m = (u + v) / 2

        if any(t0 <= m <= t1 for t0, t1 in solid):
            continue

        spans = [(y0, y1)]

        for t0, t1, gy0, gy1 in gaps:
            if t0 <= m <= t1:
                spans = [s for lo, hi in spans for s in ((lo, min(hi, gy0)), (max(lo, gy1), hi))]

        for lo, hi in spans:
            if hi - lo > 1e-6:
                out.append(_quad(at(u), at(v), lo, hi, facing))

    return out


def _box(centre_a, centre_b, width, y_top, thickness):
    """A slab from a to b (x, z), its top at y_top (one height or a pair)."""
    tops = y_top if isinstance(y_top, tuple) else (y_top, y_top)
    dx, dz = centre_b[0] - centre_a[0], centre_b[1] - centre_a[1]
    length = math.hypot(dx, dz)
    px, pz = -dz / length * width / 2, dx / length * width / 2
    top = [(centre_a[0] + px, tops[0], centre_a[1] + pz), (centre_b[0] + px, tops[1], centre_b[1] + pz),
           (centre_b[0] - px, tops[1], centre_b[1] - pz), (centre_a[0] - px, tops[0], centre_a[1] - pz)]
    bottom = [(x, y - thickness, z) for x, y, z in top]
    faces = [face(top, (0, 1, 0)), face(bottom, (0, -1, 0))]

    for i in range(4):
        j = (i + 1) % 4
        mid = [(top[i][0] + top[j][0]) / 2 - (centre_a[0] + centre_b[0]) / 2, 0.0,
               (top[i][2] + top[j][2]) / 2 - (centre_a[1] + centre_b[1]) / 2]
        faces.append(face([top[i], top[j], bottom[j], bottom[i]], mid))

    return faces


# The parts of a greybox

def _grid(box, cuts, y, extra_xs=(), extra_zs=()):
    """Up-facing cells over box (x0, z0, x1, z1) at height y, lines at every
    cut's edges, the cells inside a cut left out."""
    xs = sorted({box[0], box[2]} | {v for c in cuts for v in (c[0], c[2]) if box[0] < v < box[2]} | set(extra_xs))
    zs = sorted({box[1], box[3]} | {v for c in cuts for v in (c[1], c[3]) if box[1] < v < box[3]} | set(extra_zs))
    faces = []

    for x0, x1 in zip(xs, xs[1:]):
        for z0, z1 in zip(zs, zs[1:]):
            cx, cz = (x0 + x1) / 2, (z0 + z1) / 2

            if any(c[0] < cx < c[2] and c[1] < cz < c[3] for c in cuts):
                continue

            faces.append(face([(x0, y, z0), (x1, y, z0), (x1, y, z1), (x0, y, z1)], (0, 1, 0)))

    return faces


def _ground(data, cut):
    """The street at 0, cut round the sunken and raised places."""
    brink = _bounds(data["brink"])
    return _grid(brink, [g["box"] for g in cut], 0.0, [p[0] for p in data["brink"]], [p[1] for p in data["brink"]])


def _raised(g, sunken):
    """A pavement up: its top at its level, cut round the sunken places in
    it, its sides from the street up facing out."""
    inside = [s["box"] for s in sunken if _within(s["box"], g["box"])]
    faces = _grid(g["box"], inside, g["level"])

    for a, b in _edges(g["polygon"]):
        n = _outward(a, b)
        faces.append(_quad(a, b, 0.0, g["level"], (n[0], 0, n[1])))

    return faces


def _within(inner, outer):
    return outer[0] <= inner[0] and outer[1] <= inner[1] and inner[2] <= outer[2] and inner[3] <= outer[3]


def _top_of(g, raised):
    """The level a sunken place's walls rise to: the pavement it is cut in, else the street."""
    return next((r["level"] for r in raised if _within(g["box"], r["box"])), 0.0)


def _brink(data):
    return [_quad(a, b, -CLIFF, 0.0, (_outward(a, b)[0], 0, _outward(a, b)[1])) for a, b in _edges(data["brink"])]


def _bounds(polygon):
    xs = [p[0] for p in polygon]
    zs = [p[1] for p in polygon]
    return (min(xs), min(zs), max(xs), max(zs))


def _along(a, b, p):
    """How far along a-b (m) the point p (x, z) projects, and how far off."""
    length = math.hypot(b[0] - a[0], b[1] - a[1])
    t = ((p[0] - a[0]) * (b[0] - a[0]) + (p[1] - a[1]) * (b[1] - a[1])) / length
    off = abs((p[0] - a[0]) * (b[1] - a[1]) - (p[1] - a[1]) * (b[0] - a[0])) / length
    return t, off, length


def _collinear_span(a, b, c, d):
    """The stretch (t0, t1) of a-b that c-d covers when they lie on one line."""
    tc, oc, length = _along(a, b, c)
    td, od, _ = _along(a, b, d)

    if oc > 1e-4 or od > 1e-4:
        return None

    lo, hi = max(0.0, min(tc, td)), min(length, max(tc, td))
    return (lo, hi) if hi - lo > 1e-6 else None


def _gaps(a, b, openings, y_of):
    """Gaps in the wall a-b for the openings that lie on it."""
    out = []

    for o in openings:
        t, off, length = _along(a, b, o["at"])

        if off <= ON_WALL and -1e-6 <= t <= length + 1e-6:
            y0 = y_of(o)
            out.append((t - o["width"] / 2, t + o["width"] / 2, y0, y0 + o.get("height", GAP_HEIGHT)))

    return out


def _sunken(g, sunken, plots, openings, raised=()):
    """A sunken place: its floor, and its walls up to the street except
    where another sunken place or a plot standing in it takes over."""
    faces = [face([(x, g["level"], z) for x, z in g["polygon"]], (0, 1, 0))]

    for a, b in _edges(g["polygon"]):
        n = _outward(a, b)
        inward = (-n[0], 0, -n[1])
        solid, steps = [], []

        mid = ((a[0] + b[0]) / 2, (a[1] + b[1]) / 2)

        for other in sunken:
            if other is g:
                continue

            # Only a pit across the line (outside this one) takes over its wall.
            ox, oz = plan.centroid(other["polygon"])

            if (ox - mid[0]) * n[0] + (oz - mid[1]) * n[1] <= 0:
                continue

            for c, d in _edges(other["polygon"]):
                span = _collinear_span(a, b, c, d)

                if span:
                    if other["level"] > g["level"]:
                        steps.append((span, other["level"]))
                    solid.append(span)

        for p in plots:
            if p["base"] <= g["level"] + 1e-6:
                for c, d in _edges(p["polygon"]):
                    span = _collinear_span(a, b, c, d)

                    if span:
                        solid.append(span)

        # An opening's gap starts at the higher of the two floors, as the
        # room's own wall's does.
        mine = [o for o in openings if o["to"] == g["name"]]
        gaps = _gaps(a, b, mine, lambda o: max(g["level"], o.get("floor", g["level"])))
        faces += _wall(a, b, g["level"], _top_of(g, raised), inward, gaps, solid)

        for (t0, t1), level in steps:
            length = math.hypot(b[0] - a[0], b[1] - a[1])
            pa = (a[0] + (b[0] - a[0]) * t0 / length, a[1] + (b[1] - a[1]) * t0 / length)
            pb = (a[0] + (b[0] - a[0]) * t1 / length, a[1] + (b[1] - a[1]) * t1 / length)
            faces.append(_quad(pa, pb, g["level"], level, inward))

    return faces


def _plot(p):
    faces = [face([(x, plan.top(p), z) for x, z in p["polygon"]], (0, 1, 0))]

    for a, b in _edges(p["polygon"]):
        n = _outward(a, b)
        faces.append(_quad(a, b, p["base"], plan.top(p), (n[0], 0, n[1])))

    return faces


def _gap_floor(s, data):
    """The height a space's opening's gap starts at: a tunnel's end, else
    the higher of the two floors; and the names its tunnels join it to."""
    floors = {o["name"]: o["floor"] for o in data["spaces"]}
    floors.update({g["name"]: g["level"] for g in data["ground"]})
    tunnels = {}

    for r in data["routes"]:
        if r["kind"] == "tunnel" and s["name"] in r.get("between", ()):
            end = r["points"][0] if r["between"][0] == s["name"] else r["points"][-1]
            other = r["between"][1] if r["between"][0] == s["name"] else r["between"][0]
            tunnels[other] = end[1]

    def gap_floor(o):
        if o["to"] in tunnels:
            return tunnels[o["to"]]

        return max(s["floor"], floors.get(o["to"], 0.0))

    return gap_floor, tunnels


def _gap_spans(s, data):
    """Each gap a space's openings cut into its walls to another space (not
    a tunnel's): {"to", "a", "b" (its ends, x z), "y0", "y1" (cut to the
    space's ceiling)}."""
    gap_floor, tunnels = _gap_floor(s, data)
    spaces = {o["name"] for o in data["spaces"]}
    ceiling = s["floor"] + s["height"]
    out = []

    for a, b in _edges(s["polygon"]):
        length = math.hypot(b[0] - a[0], b[1] - a[1])
        at = lambda t: [a[0] + (b[0] - a[0]) * t / length, a[1] + (b[1] - a[1]) * t / length]

        for o in s["openings"]:
            if o["to"] in tunnels or o["to"] not in spaces:
                continue

            for t0, t1, y0, y1 in _gaps(a, b, [o], gap_floor):
                t0, t1 = max(0.0, t0), min(length, t1)

                if t1 - t0 > 1e-6 and min(y1, ceiling) - y0 > 1e-6:
                    out.append({"to": o["to"], "a": at(t0), "b": at(t1), "y0": y0, "y1": min(y1, ceiling)})

    return out


def _space(s, data):
    floor, ceiling = s["floor"], s["floor"] + s["height"]
    faces = [face([(x, floor, z) for x, z in s["polygon"]], (0, 1, 0)),
             face([(x, ceiling, z) for x, z in s["polygon"]], (0, -1, 0))]
    gap_floor, _ = _gap_floor(s, data)

    for a, b in _edges(s["polygon"]):
        n = _outward(a, b)
        faces += _wall(a, b, floor, ceiling, (-n[0], 0, -n[1]), _gaps(a, b, s["openings"], gap_floor))

    return faces


def _route(r):
    a, b = r["points"][0], r["points"][-1]

    if r["kind"] == "stair":
        top, bottom = (a, b) if a[1] >= b[1] else (b, a)
        dx, dz = bottom[0] - top[0], bottom[2] - top[2]
        length = math.hypot(dx, dz)
        px, pz = -dz / length * STAIR_WIDTH / 2, dx / length * STAIR_WIDTH / 2
        t1 = (top[0] + px, top[1], top[2] + pz)
        t2 = (top[0] - px, top[1], top[2] - pz)
        b1 = (bottom[0] + px, bottom[1], bottom[2] + pz)
        b2 = (bottom[0] - px, bottom[1], bottom[2] - pz)
        faces = [face([t1, b1, b2, t2], (0, 1, 0))]
        faces.append(face([t1, b1, (t1[0], bottom[1], t1[2])], (px, 0, pz)))
        faces.append(face([t2, b2, (t2[0], bottom[1], t2[2])], (-px, 0, -pz)))
        return faces

    if r["kind"] == "bridge":
        return _box((a[0], a[2]), (b[0], b[2]), BRIDGE[0], max(a[1], b[1]) + PROUD, BRIDGE[1])

    if r["kind"] == "roof_link":
        return _box((a[0], a[2]), (b[0], b[2]), PLANK[0], (a[1] + PROUD, b[1] + PROUD), PLANK[1])

    if r["kind"] == "climb":
        # The ladder's board against the wall, on the side it is climbed
        # from (Godot makes it a ladder; the board has no collider).
        lower, upper = (a, b) if a[1] <= b[1] else (b, a)
        mx, mz = (a[0] + b[0]) / 2, (a[2] + b[2]) / 2
        dx, dz = upper[0] - lower[0], upper[2] - lower[2]
        length = math.hypot(dx, dz)

        if length < 1e-6:
            return []

        ux, uz = dx / length, dz / length
        near, far = (mx - ux * (BOARD_OFF + BOARD[1]), mz - uz * (BOARD_OFF + BOARD[1])), (mx - ux * BOARD_OFF, mz - uz * BOARD_OFF)
        return _box(near, far, BOARD[0], upper[1], upper[1] - lower[1])

    if r["kind"] == "tunnel":
        w, h = TUNNEL
        dx, dz = b[0] - a[0], b[2] - a[2]
        length = math.hypot(dx, dz)
        px, pz = -dz / length * w / 2, dx / length * w / 2
        fa1, fa2 = (a[0] + px, a[1], a[2] + pz), (a[0] - px, a[1], a[2] - pz)
        fb1, fb2 = (b[0] + px, b[1], b[2] + pz), (b[0] - px, b[1], b[2] - pz)
        up = lambda p: (p[0], p[1] + h, p[2])
        return [face([fa1, fb1, fb2, fa2], (0, 1, 0)), face([up(fa1), up(fb1), up(fb2), up(fa2)], (0, -1, 0)),
                face([fa1, fb1, up(fb1), up(fa1)], (-px, 0, -pz)), face([fa2, fb2, up(fb2), up(fa2)], (px, 0, pz))]

    return []


def build(data):
    """The plan's greybox: {"meshes": [{"name", "kind", "faces": [...]}]}."""
    sunken = [dict(g, box=_bounds(g["polygon"])) for g in data["ground"] if g["kind"] in plan.SUNKEN_KINDS]
    raised = [dict(g, box=_bounds(g["polygon"])) for g in data["ground"]
              if g["kind"] in plan.RAISED_KINDS and g["level"] > 1e-6]
    openings = [dict(o, floor=s["floor"]) for s in data["spaces"] for o in s["openings"]]
    meshes = []

    if len(data["brink"]) >= 3:
        meshes += [{"name": "ground", "kind": "ground", "faces": _ground(data, sunken + raised)},
                   {"name": "brink", "kind": "brink", "faces": _brink(data)}]

    meshes += [{"name": g["name"], "kind": "raised", "faces": _raised(g, sunken)} for g in raised]
    meshes += [{"name": g["name"], "kind": "sunken", "faces": _sunken(g, sunken, data["plots"], openings, raised)}
               for g in sunken]
    meshes += [{"name": p["name"], "kind": "plot", "family": p["family"], "faces": _plot(p)} for p in data["plots"]]
    meshes += [{"name": s["name"], "kind": "space", "polygon": s["polygon"], "floor": s["floor"], "height": s["height"],
                "gaps": _gap_spans(s, data), "faces": _space(s, data)} for s in data["spaces"]]
    meshes += [{"name": r["name"], "kind": "route", "route": r["kind"], "points": r["points"], "faces": _route(r)}
               for r in data["routes"]]
    return {"name": data["name"], "meshes": meshes}


# The gate

def faces(box):
    """Every face as overlap.py takes them."""
    return [{"owner": m["name"], "normal": f["normal"], "points": [tuple(p) for p in f["points"]]}
            for m in box["meshes"] for f in m["faces"]]


def _layered(all_faces, gap=LAYER_GAP):
    """tools/eclipse/gate.py's layered(), bucketed by plane: same-facing
    faces gap or nearer that overlap, in one object or two (one plane across
    two objects is fights()'s)."""
    buckets = defaultdict(list)
    normals = [overlap._unit(f["normal"]) for f in all_faces]
    distances = [overlap._dot(n, f["points"][0]) for n, f in zip(normals, all_faces)]

    for i, n in enumerate(normals):
        buckets[(round(n[0], 2), round(n[1], 2), round(n[2], 2), math.floor(distances[i] / gap))].append(i)

    found = []

    for key, members in buckets.items():
        near = members + [j for k in (1,) for j in buckets.get((key[0], key[1], key[2], key[3] + k), [])]

        for x, i in enumerate(members):
            for j in near[x + 1:]:
                apart = abs(distances[i] - distances[j])

                if apart > gap or apart <= overlap.TOLERANCE or overlap._dot(normals[i], normals[j]) < overlap.SAME_WAY:
                    continue

                axes = overlap._axes(normals[i])
                pi, pj = overlap._flat(all_faces[i]["points"], axes), overlap._flat(all_faces[j]["points"], axes)
                bi, bj = overlap._box(pi), overlap._box(pj)

                if bi[2] <= bj[0] or bj[2] <= bi[0] or bi[3] <= bj[1] or bj[3] <= bi[1]:
                    continue

                shared = overlap._clipped(pi, pj)
                area = overlap._area(shared) if len(shared) >= 3 else 0.0

                if area >= overlap.LEAST:
                    found.append((i, j, apart, area))

    return found


def _sharing(box):
    """Pairs of spaces sharing volume: their outlines overlapping (more than
    a shared edge) and their heights overlapping."""
    spaces = [m for m in box["meshes"] if m["kind"] == "space" and "polygon" in m]
    out = []

    for i, a in enumerate(spaces):
        for b in spaces[i + 1:]:
            low = max(a["floor"], b["floor"])
            high = min(a["floor"] + a["height"], b["floor"] + b["height"])

            if high - low <= 1e-6:
                continue

            ax0, az0, ax1, az1 = _bounds(a["polygon"])
            bx0, bz0, bx1, bz1 = _bounds(b["polygon"])

            if min(ax1, bx1) - max(ax0, bx0) <= 1e-6 or min(az1, bz1) - max(az0, bz0) <= 1e-6:
                continue

            # (Clipped by whichever outline is convex; two that are not
            # count their bounds' overlap.)
            if plan_check.convex(b["polygon"]):
                area = plan_check.overlap_area(a["polygon"], b["polygon"])
            elif plan_check.convex(a["polygon"]):
                area = plan_check.overlap_area(b["polygon"], a["polygon"])
            else:
                area = (min(ax1, bx1) - max(ax0, bx0)) * (min(az1, bz1) - max(az0, bz0))

            if area > 0.01:
                out.append((a["name"], b["name"], area, high - low))

    return out


def _unbacked(box):
    """Gaps in a space's wall with nothing behind them: some of the gap
    off the other space's wall, or above its ceiling or below its floor."""
    spaces = {m["name"]: m for m in box["meshes"] if m["kind"] == "space" and "polygon" in m}
    out = []

    for m in spaces.values():
        for g in m.get("gaps", []):
            other = spaces.get(g["to"])

            if other is None:
                continue

            along = [[g["a"][k] + (g["b"][k] - g["a"][k]) * t / 4.0 for k in (0, 1)] for t in range(5)]
            off = any(plan_check.boundary_distance(p, other["polygon"]) > ON_WALL for p in along)
            high = g["y1"] > other["floor"] + other["height"] + 1e-6 or g["y0"] < other["floor"] - 1e-6

            if off or high:
                out.append("gap: %s to %s opens onto nothing (%s)" % (m["name"], g["to"], "past its wall" if off else
                                                                     "above its ceiling"))

    return out


def gate(box):
    """One line a problem: faces of two objects fighting in one plane,
    same-facing faces within LAYER_GAP of each other, two spaces sharing
    volume, or a gap in a wall opening onto nothing."""
    all_faces = faces(box)
    out = ["fight: %s and %s share %.3f m2" % (all_faces[i]["owner"], all_faces[j]["owner"], area)
           for i, j, area in overlap.fights(all_faces)]
    out += ["layered: %s and %s %.1f cm apart, %.3f m2" % (all_faces[i]["owner"], all_faces[j]["owner"], apart * 100, area)
            for i, j, apart, area in _layered(all_faces)]
    out += ["volume: %s and %s share %.1f m2 over %.1f m" % v for v in _sharing(box)]
    out += _unbacked(box)
    return out


if __name__ == "__main__":
    data = json.loads(Path(sys.argv[1]).read_text())
    box = build(data)
    Path(sys.argv[2]).write_text(json.dumps(box))
    problems = gate(box)

    for p in problems[:40]:
        print("greybox:", p)

    print("greybox: %d meshes, %d faces, %d problems -> %s" % (len(box["meshes"]), len(faces(box)), len(problems), sys.argv[2]))
    sys.exit(1 if problems else 0)
