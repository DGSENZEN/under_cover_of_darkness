"""A district plan's checks (the Zócalo spec, section 6): one problem a line,
each naming the elements involved; none means the plan is clean.

    plots          convex; never overlapping another plot or a street, the
                   plaza or the canal; each facing one of them
    sunken ground  axis-aligned rectangles (the greybox cuts them out)
    routes         each end resting on a surface: inside its outline, within
                   ROUTE_REST of its height
    reach          every walkable roof and every underground space reachable
                   from the street, over joined surfaces and routes
    size           the brink 500-700 m a side, everything inside it
    events         every kind of event field present, inside the brink
"""

import math
import os
import sys
from collections import deque

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "layouts"))

import plan  # noqa: E402

# Overlaps smaller than this (m2) are a shared edge, not an overlap.
OVERLAP = 0.5
# A plot faces a street if an edge's middle lies this near one (m).
FRONTAGE = 0.5
# A route's end rests on a surface within this of its height (m), and this
# far outside its outline (m).
ROUTE_REST = 0.6
EDGE_SLACK = 0.3
# Surfaces at one height closer than this (m) are joined.
JOIN = 0.01
SIZE = (500.0, 700.0)


def _edges(polygon):
    pts = [tuple(p) for p in polygon]
    return list(zip(pts, pts[1:] + pts[:1]))


def convex(polygon):
    """True for a convex polygon (collinear corners allowed)."""
    signs = set()

    for (a, b), (_, c) in zip(_edges(polygon), _edges(polygon)[1:] + _edges(polygon)[:1]):
        cross = (b[0] - a[0]) * (c[1] - b[1]) - (b[1] - a[1]) * (c[0] - b[0])

        if abs(cross) > 1e-9:
            signs.add(cross > 0)

    return len(signs) <= 1


def _clip(subject, clipper):
    """Sutherland-Hodgman: the subject cut to a convex clipper."""
    clipper = plan.oriented(clipper)
    out = [tuple(p) for p in subject]

    for a, b in _edges(clipper):
        if not out:
            break

        inside = lambda p: (b[0] - a[0]) * (p[1] - a[1]) - (b[1] - a[1]) * (p[0] - a[0]) >= 0
        src, out = out, []

        for p, q in zip(src, src[1:] + src[:1]):
            if inside(q):
                if not inside(p):
                    out.append(_cross_point(p, q, a, b))
                out.append(q)
            elif inside(p):
                out.append(_cross_point(p, q, a, b))

    return out


def _cross_point(p, q, a, b):
    d1 = (q[0] - p[0], q[1] - p[1])
    d2 = (b[0] - a[0], b[1] - a[1])
    denom = d1[0] * d2[1] - d1[1] * d2[0]

    if abs(denom) < 1e-12:
        return q

    t = ((a[0] - p[0]) * d2[1] - (a[1] - p[1]) * d2[0]) / denom
    return (p[0] + t * d1[0], p[1] + t * d1[1])


def overlap_area(subject, convex_clipper):
    shared = _clip(subject, convex_clipper)
    return plan.area(shared) if len(shared) >= 3 else 0.0


def _segment_distance(p, a, b):
    return plan._segment_distance(p, a, b)


def inside(p, polygon):
    """Ray casting: is the point (x, z) inside the polygon?"""
    x, z = p
    hit = False

    for a, b in _edges(polygon):
        if (a[1] > z) != (b[1] > z):
            if x < a[0] + (z - a[1]) * (b[0] - a[0]) / (b[1] - a[1]):
                hit = not hit

    return hit


def boundary_distance(p, polygon):
    return min(_segment_distance(p, a, b) for a, b in _edges(polygon))


def near(p, polygon, slack):
    """Inside the polygon, or within slack of its outline."""
    return inside(p, polygon) or boundary_distance(p, polygon) <= slack


def _segments_meet(a, b, c, d):
    def orient(p, q, r):
        return (q[0] - p[0]) * (r[1] - p[1]) - (q[1] - p[1]) * (r[0] - p[0])

    return (orient(a, b, c) * orient(a, b, d) <= 0) and (orient(c, d, a) * orient(c, d, b) <= 0)


def touching(p1, p2, slack=JOIN):
    """Two polygons that share an edge, cross or overlap."""
    if any(near(v, p2, slack) for v in p1) or any(near(v, p1, slack) for v in p2):
        return True

    for a, b in _edges(p1):
        for c, d in _edges(p2):
            if _segments_meet(a, b, c, d):
                return True

    return False


def walkable(data):
    """Every surface one can stand on: ground areas at their level, walkable
    roofs at their top, underground spaces' floors."""
    out = [{"name": g["name"], "polygon": g["polygon"], "y": g["level"], "street": g["kind"] in ("plaza", "street")
            and abs(g["level"]) < 1e-6} for g in data["ground"]]
    out += [{"name": p["name"], "polygon": p["polygon"], "y": plan.top(p), "street": False}
            for p in data["plots"] if p["roof"]]
    out += [{"name": s["name"], "polygon": s["polygon"], "y": s["floor"], "street": False} for s in data["spaces"]]
    return out


def _rests_on(point, surfaces):
    x, y, z = point
    return [s["name"] for s in surfaces if abs(y - s["y"]) <= ROUTE_REST and near((x, z), s["polygon"], EDGE_SLACK)]


def _graph(data):
    surfaces = walkable(data)
    links = {s["name"]: set() for s in surfaces}

    for i, a in enumerate(surfaces):
        for b in surfaces[i + 1:]:
            if abs(a["y"] - b["y"]) < 1e-6 and touching(a["polygon"], b["polygon"]):
                links[a["name"]].add(b["name"])
                links[b["name"]].add(a["name"])

    dangling = []

    for r in data["routes"]:
        ends = []

        for i, point in enumerate(r["points"]):
            if i not in (0, len(r["points"]) - 1):
                continue

            on = _rests_on(point, surfaces)

            if not on:
                dangling.append("route %s end %d dangles at (%.1f, %.1f, %.1f)" % (r["name"], i, *point))

            ends.append(on)

        if len(ends) == 2:
            for a in ends[0]:
                for b in ends[1]:
                    links[a].add(b)
                    links[b].add(a)

    return surfaces, links, dangling


def reach(data):
    """The names of every surface reachable from the street."""
    surfaces, links, _ = _graph(data)
    seen = {s["name"] for s in surfaces if s["street"]}
    queue = deque(seen)

    while queue:
        for nxt in links[queue.popleft()]:
            if nxt not in seen:
                seen.add(nxt)
                queue.append(nxt)

    return seen


def _bounds(polygon):
    xs = [p[0] for p in polygon]
    zs = [p[1] for p in polygon]
    return min(xs), min(zs), max(xs), max(zs)


def check(data):
    problems = []
    plots = data["plots"]
    grounds = data["ground"]
    frontage = [g for g in grounds if g["kind"] in plan.FRONTAGE_KINDS]

    # Plots.
    for p in plots:
        if not convex(p["polygon"]):
            problems.append("plot %s is not convex" % p["name"])

    shapes = [p for p in plots if convex(p["polygon"])]

    for i, a in enumerate(shapes):
        for b in shapes[i + 1:]:
            shared = overlap_area(a["polygon"], b["polygon"])

            if shared >= OVERLAP:
                problems.append("plots %s and %s overlap by %.1f m2" % (a["name"], b["name"], shared))

        for g in frontage:
            shared = overlap_area(g["polygon"], a["polygon"])

            if shared >= OVERLAP:
                problems.append("plot %s stands in %s (%.1f m2)" % (a["name"], g["name"], shared))

    for p in plots:
        middles = [((a[0] + b[0]) / 2, (a[1] + b[1]) / 2) for a, b in _edges(p["polygon"])]

        if not any(near(m, g["polygon"], FRONTAGE) for m in middles for g in frontage):
            problems.append("plot %s faces no street" % p["name"])

    # Sunken ground.
    for g in grounds:
        if g["kind"] in plan.SUNKEN_KINDS:
            x0, z0, x1, z1 = _bounds(g["polygon"])

            if len(g["polygon"]) != 4 or abs(plan.area(g["polygon"]) - (x1 - x0) * (z1 - z0)) > 1e-6:
                problems.append("sunken %s is not a rectangle" % g["name"])

    # Routes and reach.
    _, _, dangling = _graph(data)
    problems += dangling
    reached = reach(data)

    for p in plots:
        if p["roof"] and p["name"] not in reached:
            problems.append("roof of %s cannot be reached from the street" % p["name"])

    for s in data["spaces"]:
        if s["name"] not in reached:
            problems.append("space %s cannot be reached from the street" % s["name"])

    # Size.
    brink = data["brink"]

    if len(brink) < 3:
        problems.append("%s has no brink" % data["name"])
    else:
        x0, z0, x1, z1 = _bounds(brink)

        if not (SIZE[0] <= x1 - x0 <= SIZE[1] and SIZE[0] <= z1 - z0 <= SIZE[1]):
            problems.append("%s: the brink is %.0f x %.0f m, not %d-%d m a side" % (data["name"], x1 - x0, z1 - z0,
                                                                                   *SIZE))

        def out(points):
            return any(not near(p, brink, 0.01) for p in points)

        for e in grounds + plots + data["spaces"]:
            if out(e["polygon"]):
                problems.append("%s lies outside the brink" % e["name"])

        for r in data["routes"]:
            if out([(p[0], p[2]) for p in r["points"]]):
                problems.append("route %s lies outside the brink" % r["name"])

        for m in data["landmarks"]:
            if out([(m["at"][0], m["at"][-1])]):
                problems.append("landmark %s lies outside the brink" % m["name"])

        for e in data["events"]:
            if out([e["centre"]] if "centre" in e else e["line"]):
                problems.append("a %s event lies outside the brink" % e["kind"])

    # Events.
    for kind in plan.EVENT_KINDS:
        if not any(e["kind"] == kind for e in data["events"]):
            problems.append("no %s event field" % kind)

    return problems
