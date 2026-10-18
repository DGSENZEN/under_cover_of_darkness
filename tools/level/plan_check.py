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

A map with no street (the Metro Underground) checks by UNDERGROUND_RULES:
reach starts from the spaces holding its arrival, and neither the brink's
size nor the event fields are asked for.
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
# far outside its outline (m); an opening lies on a wall within ON_WALL (m).
ROUTE_REST = 0.05
ON_WALL = 0.05
# An opening joins two floors no further apart than a step down (m).
STEP = 0.6
EDGE_SLACK = 0.3
# Surfaces at one height closer than this (m) are joined.
JOIN = 0.01
SIZE = (500.0, 700.0)

# What a map is held to. size: the brink's sides (m), or None for any brink
# (still everything inside one, if drawn); events: every event kind present;
# reach_from: "street", or a tuple of landmark kinds whose surfaces reach
# starts from.
ZOCALO_RULES = {"size": SIZE, "events": True, "reach_from": "street"}
UNDERGROUND_RULES = {"size": None, "events": False, "reach_from": ("arrival",)}
# A landmark given with its height stands on a surface this near it (m).
STANDS_ON = 1.5


def _edges(polygon):
    pts = [tuple(p) for p in polygon]
    return list(zip(pts, pts[1:] + pts[:1]))


def convex(polygon):
    """True for a convex polygon (collinear corners allowed): every turn the
    same way, and no edge crossing another (a star turns one way too)."""
    signs = set()
    edges = _edges(polygon)

    for (a, b), (_, c) in zip(edges, edges[1:] + edges[:1]):
        cross = (b[0] - a[0]) * (c[1] - b[1]) - (b[1] - a[1]) * (c[0] - b[0])

        if abs(cross) > 1e-9:
            signs.add(cross > 0)

    if len(signs) > 1:
        return False

    n = len(edges)

    for i in range(n):
        for j in range(i + 2, n):
            if i == 0 and j == n - 1:
                continue

            if _crossing(edges[i][0], edges[i][1], edges[j][0], edges[j][1]):
                return False

    return True


def _crossing(a, b, c, d):
    """Two segments crossing at a point inside both (not at their ends)."""
    def orient(p, q, r):
        return (q[0] - p[0]) * (r[1] - p[1]) - (q[1] - p[1]) * (r[0] - p[0])

    o1, o2, o3, o4 = orient(a, b, c), orient(a, b, d), orient(c, d, a), orient(c, d, b)
    return o1 * o2 < -1e-12 and o3 * o4 < -1e-12


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


# Two surfaces are one if they overlap or share this much edge (m): a corner
# or a line they merely both lie on is not a way across.
SHARED_EDGE = 0.5


def _collinear_overlap(a, b, c, d):
    """How long a stretch c-d shares with a-b when both lie on one line."""
    length = math.hypot(b[0] - a[0], b[1] - a[1])

    if length < 1e-9:
        return 0.0

    for p in (c, d):
        if abs((p[0] - a[0]) * (b[1] - a[1]) - (p[1] - a[1]) * (b[0] - a[0])) / length > 1e-4:
            return 0.0

    t = [((p[0] - a[0]) * (b[0] - a[0]) + (p[1] - a[1]) * (b[1] - a[1])) / length for p in (c, d)]
    return max(0.0, min(length, max(t)) - max(0.0, min(t)))


def touching(p1, p2):
    """Two surfaces one can walk between: they overlap, or share an edge
    SHARED_EDGE long or longer."""
    clipper, subject = (p2, p1) if convex(p2) else (p1, p2)

    if convex(clipper) and overlap_area(subject, clipper) > 0.01:
        return True

    return any(_collinear_overlap(a, b, c, d) >= SHARED_EDGE for a, b in _edges(p1) for c, d in _edges(p2))


def walkable(data):
    """Every surface one can stand on: ground areas at their level, walkable
    roofs at their top, underground spaces' floors."""
    out = [{"name": g["name"], "polygon": g["polygon"], "y": g["level"], "street": (g["kind"] == "street" and abs(g["level"]) < 1e-6)
            or g["kind"] in plan.RAISED_KINDS} for g in data["ground"]]
    out += [{"name": p["name"], "polygon": p["polygon"], "y": plan.top(p), "street": False}
            for p in data["plots"] if p["roof"]]
    out += [{"name": s["name"], "polygon": s["polygon"], "y": s["floor"], "street": False} for s in data["spaces"]]
    return out


def _rests_on(point, surfaces, holes):
    """The surfaces a route's end rests on: within ROUTE_REST of its height,
    inside its outline (or EDGE_SLACK off it), and not over a hole another
    level cuts through it."""
    x, y, z = point
    out = []

    for s in surfaces:
        if abs(y - s["y"]) > ROUTE_REST or not near((x, z), s["polygon"], EDGE_SLACK):
            continue

        if any(h["name"] != s["name"] and abs(h["level"] - s["y"]) > 1e-6 and inside((x, z), _inset(h["polygon"]))
               for h in holes):
            continue

        out.append(s["name"])

    return out


def _inset(polygon, by=0.05):
    """An axis-aligned rectangle shrunk on every side (a point on its edge is
    not over its hole)."""
    xs = [p[0] for p in polygon]
    zs = [p[1] for p in polygon]
    return plan.rect(min(xs) + by, min(zs) + by, max(xs) - by, max(zs) - by)


def _opens(data):
    """Pairs (space, other) that an opening joins, both ways."""
    out = set()

    for s in data["spaces"]:
        for o in s["openings"]:
            out.add((s["name"], o["to"]))
            out.add((o["to"], s["name"]))

    return out


def _graph(data):
    surfaces = walkable(data)
    links = {s["name"]: set() for s in surfaces}
    spaces = {s["name"] for s in data["spaces"]}
    opens = _opens(data)
    holes = [g for g in data["ground"] if g["kind"] in plan.SUNKEN_KINDS]

    for i, a in enumerate(surfaces):
        for b in surfaces[i + 1:]:
            if a["name"] in spaces or b["name"] in spaces:
                # Rooms are walled: only an opening joins them to what is beside.
                if (a["name"], b["name"]) not in opens or abs(a["y"] - b["y"]) > STEP:
                    continue
            elif abs(a["y"] - b["y"]) > 1e-6 or not touching(a["polygon"], b["polygon"]):
                continue

            links[a["name"]].add(b["name"])
            links[b["name"]].add(a["name"])

    dangling = []

    for r in data["routes"]:
        ends = []

        for i, point in enumerate(r["points"]):
            if i not in (0, len(r["points"]) - 1):
                continue

            on = _rests_on(point, surfaces, holes)

            if not on:
                dangling.append("route %s end %d dangles at (%.1f, %.1f, %.1f)" % (r["name"], i, *point))

            ends.append(on)

        if len(ends) == 2:
            for a in ends[0]:
                for b in ends[1]:
                    links[a].add(b)
                    links[b].add(a)

    return surfaces, links, dangling


def _openings_on_walls(data):
    """An opening lies on its room's wall and, unless a tunnel joins the two,
    on the wall of what it opens to."""
    outlines = {g["name"]: g["polygon"] for g in data["ground"]}
    outlines.update({s["name"]: s["polygon"] for s in data["spaces"]})
    tunnels = {tuple(sorted(r["between"])) for r in data["routes"] if r["kind"] == "tunnel" and "between" in r}
    problems = []

    for s in data["spaces"]:
        for o in s["openings"]:
            at = tuple(o["at"])

            if boundary_distance(at, s["polygon"]) > ON_WALL:
                problems.append("opening of %s to %s is not on its wall" % (s["name"], o["to"]))
            elif o["to"] in outlines and tuple(sorted((s["name"], o["to"]))) not in tunnels \
                    and boundary_distance(at, outlines[o["to"]]) > ON_WALL:
                problems.append("opening of %s to %s is not on %s's wall" % (s["name"], o["to"], o["to"]))

    return problems


def _starts(data, surfaces, reach_from):
    """The surfaces reach starts from: the street's, or those under the
    landmarks of the given kinds (at its height, when the landmark has one)."""
    if reach_from == "street":
        return {s["name"] for s in surfaces if s["street"]}

    out = set()

    for m in data["landmarks"]:
        if m["kind"] not in reach_from:
            continue

        for s in surfaces:
            if inside((m["at"][0], m["at"][-1]), s["polygon"]) and (len(m["at"]) < 3 or abs(m["at"][1] - s["y"]) <= STANDS_ON):
                out.add(s["name"])

    return out


def reach(data, reach_from="street"):
    """The names of every surface reachable from the street (or from the
    landmarks of the kinds reach_from names)."""
    surfaces, links, _ = _graph(data)
    seen = _starts(data, surfaces, reach_from)
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


# Routes are walked every this many metres for what they pass through (m),
# their ends' first and last stretch left out (they rest on something).
ROUTE_STEP = 0.5
ROUTE_END = 0.3


def _through_solid(data):
    """A stair, bridge or plank passing through a plot (below its roof) or
    buried in solid ground (below the street, in no sunken place or room).
    Tunnels carve their own way and climbs cross a wall by design."""
    problems = []
    holes = [g for g in data["ground"] if g["kind"] in plan.SUNKEN_KINDS]

    for r in data["routes"]:
        if r["kind"] not in ("stair", "bridge", "roof_link"):
            continue

        a, b = r["points"][0], r["points"][-1]
        length = math.dist(a, b)
        hit, buried = set(), False
        k = ROUTE_END

        while k <= length - ROUTE_END:
            t = k / length
            x, y, z = (a[i] + (b[i] - a[i]) * t for i in range(3))

            for p in data["plots"]:
                if y < plan.top(p) - 0.05 and convex(p["polygon"]) and inside((x, z), p["polygon"]) \
                        and boundary_distance((x, z), p["polygon"]) > 0.05:
                    hit.add(p["name"])

            if y < -0.05 and not any(near((x, z), h["polygon"], 0.05) and h["level"] <= y + 0.01 for h in holes) \
                    and not any(near((x, z), s["polygon"], 0.05) and s["floor"] - 0.01 <= y <= s["floor"] + s["height"]
                                for s in data["spaces"]):
                buried = True

            k += ROUTE_STEP

        problems += ["route %s passes through plot %s" % (r["name"], n) for n in sorted(hit)]

        if buried:
            problems.append("route %s runs through solid ground" % r["name"])

    return problems


def check(data, rules=ZOCALO_RULES):
    problems = []
    origin = "the street" if rules["reach_from"] == "street" else "the " + "/".join(rules["reach_from"])
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
        # A dig is frontage only for what stands down in it.
        faces = [g for g in frontage if g["kind"] != "dig" or p["base"] < -1e-6]

        if not any(near(m, g["polygon"], FRONTAGE) for m in middles for g in faces):
            problems.append("plot %s faces no street" % p["name"])

        for g in grounds:
            if g["kind"] in plan.SUNKEN_KINDS and p["base"] > g["level"] + 1e-6 and convex(p["polygon"]) \
                    and overlap_area(g["polygon"], p["polygon"]) >= OVERLAP:
                problems.append("plot %s stands over %s" % (p["name"], g["name"]))

    # Sunken ground.
    for g in grounds:
        if g["kind"] in plan.SUNKEN_KINDS:
            x0, z0, x1, z1 = _bounds(g["polygon"])

            if len(g["polygon"]) != 4 or abs(plan.area(g["polygon"]) - (x1 - x0) * (z1 - z0)) > 1e-6:
                problems.append("sunken %s is not a rectangle" % g["name"])

    # Routes and reach.
    _, _, dangling = _graph(data)
    problems += dangling
    problems += _openings_on_walls(data)
    problems += _through_solid(data)
    reached = reach(data, rules["reach_from"])

    if rules["reach_from"] != "street" and not _starts(data, walkable(data), rules["reach_from"]):
        problems.append("%s has no %s to reach from" % (data["name"], " or ".join(rules["reach_from"])))

    for p in plots:
        if p["roof"] and p["name"] not in reached:
            problems.append("roof of %s cannot be reached from %s" % (p["name"], origin))

    for s in data["spaces"]:
        if s["name"] not in reached:
            problems.append("space %s cannot be reached from %s" % (s["name"], origin))

    # Size.
    brink = data["brink"]
    size = rules["size"]

    if len(brink) < 3:
        if size is not None:
            problems.append("%s has no brink" % data["name"])
    else:
        x0, z0, x1, z1 = _bounds(brink)

        if size is not None and not (size[0] <= x1 - x0 <= size[1] and size[0] <= z1 - z0 <= size[1]):
            problems.append("%s: the brink is %.0f x %.0f m, not %d-%d m a side" % (data["name"], x1 - x0, z1 - z0,
                                                                                   *size))

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
    for kind in plan.EVENT_KINDS if rules["events"] else ():
        if not any(e["kind"] == kind for e in data["events"]):
            problems.append("no %s event field" % kind)

    return problems
