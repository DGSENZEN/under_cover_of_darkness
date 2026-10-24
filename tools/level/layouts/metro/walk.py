"""Walking the plan (the Metro Underground spec, section 8: the spine): a
graph of the places one walks between, its doors (openings between floors a
step apart) and its routes' ends, joined within each space in straight lines
and along each route; the shortest walk between two landmarks.

The path's waypoints carry a run-up before each stair and a step off after
it (APPROACH along the flight), so a walker meets a flight head on, never
across its side."""

import heapq
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))   # tools/level

import plan_check  # noqa: E402

APPROACH = 1.5
# A run-up stands this clear of the walls (m: a capsule's radius and more),
# and no nearer its flight's end than NEAREST.
CLEAR = 0.8
NEAREST = 0.3
# Past this far across a flight's line (m: its half width and a capsule),
# the way to its run-up would cut across it.
FLIGHT_HALF = 1.2 + 0.6
# A landmark stands in a space whose floor is this near its height (m).
STANDS = 1.5


def _length(points):
    return sum(math.dist(a, b) for a, b in zip(points, points[1:]))


def graph(data, climbs=False):
    """(nodes, edges): nodes [{"at": (x, y, z), "spaces": set}], edges
    {i: [(j, metres, via)]}, via a space's or a route's name. Climbs are
    left out unless asked for: a walk is walked."""
    floors = {s["name"]: s["floor"] for s in data["spaces"]}
    tunnels = {tuple(sorted(r["between"])) for r in data["routes"] if r["kind"] == "tunnel" and "between" in r}
    nodes, edges, seen = [], {}, set()

    def add(at, spaces):
        nodes.append({"at": tuple(float(v) for v in at), "spaces": set(spaces)})
        edges[len(nodes) - 1] = []
        return len(nodes) - 1

    def link(i, j, metres, via):
        edges[i].append((j, metres, via))
        edges[j].append((i, metres, via))

    for s in data["spaces"]:
        for o in s["openings"]:
            pair = tuple(sorted((s["name"], o["to"])))
            key = (pair, round(o["at"][0], 2), round(o["at"][1], 2))

            if key in seen or o["to"] not in floors or pair in tunnels:
                continue

            seen.add(key)

            if abs(floors[s["name"]] - floors[o["to"]]) <= plan_check.STEP:
                add((o["at"][0], max(floors[s["name"]], floors[o["to"]]), o["at"][1]), pair)

    surfaces = plan_check.walkable(data)

    for r in data["routes"]:
        if r["kind"] == "climb" and not climbs:
            continue

        ends = [r["points"][0], r["points"][-1]]
        a = add(ends[0], plan_check._rests_on(ends[0], surfaces, []))
        b = add(ends[1], plan_check._rests_on(ends[1], surfaces, []))
        link(a, b, _length(r["points"]), r["name"])

    for m in data["landmarks"]:
        x, y, z = m["at"]
        inside = [s["name"] for s in data["spaces"]
                  if plan_check.inside((x, z), s["polygon"]) and abs(y - s["floor"]) <= STANDS]
        nodes_for = add(m["at"], inside)
        nodes[nodes_for]["landmark"] = m["name"]

    by_space = {}

    for i, n in enumerate(nodes):
        for s in n["spaces"]:
            by_space.setdefault(s, []).append(i)

    for s, members in by_space.items():
        for k, i in enumerate(members):
            for j in members[k + 1:]:
                link(i, j, math.dist(nodes[i]["at"], nodes[j]["at"]), s)

    return nodes, edges


def shortest(data, start, goals, climbs=False):
    """The shortest walk from the landmark `start` to the nearest of the
    landmarks `goals`: {"length", "nodes": [(x, y, z)], "via": [names],
    "goal"}; None if none is reached."""
    nodes, edges = graph(data, climbs)
    index = {n.get("landmark"): i for i, n in enumerate(nodes) if "landmark" in n}
    targets = {index[g] for g in goals if g in index}
    best = {index[start]: 0.0}
    back = {}
    queue = [(0.0, index[start])]

    while queue:
        d, i = heapq.heappop(queue)

        if i in targets:
            order, vias = [i], []

            while order[-1] in back:
                j, via = back[order[-1]]
                order.append(j)
                vias.append(via)

            order.reverse()
            vias.reverse()
            return {"length": d, "nodes": [nodes[k]["at"] for k in order], "via": vias, "goal": nodes[i]["landmark"]}

        if d > best.get(i, math.inf):
            continue

        for j, metres, via in edges[i]:
            if d + metres < best.get(j, math.inf):
                best[j] = d + metres
                back[j] = (i, via)
                heapq.heappush(queue, (d + metres, j))

    return None


def waypoints(data, walk):
    """The walk's points with a run-up before and a step off after each
    stair it takes (APPROACH along the stair, level with its end, kept
    CLEAR of the walls), and, when the way to the run-up would cut across
    the flight, a turn level with the run-up first."""
    routes = {r["name"]: r for r in data["routes"]}
    out = [list(walk["nodes"][0])]

    for k, via in enumerate(walk["via"]):
        a, b = walk["nodes"][k], walk["nodes"][k + 1]

        if via in routes and routes[via]["kind"] == "stair":
            dx, dz = b[0] - a[0], b[2] - a[2]
            n = math.hypot(dx, dz) or 1.0
            ux, uz = dx / n, dz / n
            run_up = _clear(data, a, (-ux, -uz))
            step_off = _clear(data, b, (ux, uz))

            if math.dist(out[-1], a) < 1e-6:
                out.pop()

            # Level with the run-up, as far across as the last point.
            last = out[-1]
            across = -(last[0] - a[0]) * uz + (last[2] - a[2]) * ux
            behind = (last[0] - a[0]) * ux + (last[2] - a[2]) * uz

            if abs(across) > FLIGHT_HALF and behind > -APPROACH:
                out.append([run_up[0] - uz * across, a[1], run_up[2] + ux * across])

            out += [run_up, list(a), list(b), step_off]
        else:
            out.append(list(b))

    # (Consecutive repeats dropped.)
    return [p for i, p in enumerate(out) if i == 0 or math.dist(p, out[i - 1]) > 1e-6]


def _clear(data, end, direction):
    """The point APPROACH from a flight's end along `direction`, at its
    height, drawn back until it stands CLEAR of the walls of the space it
    is in (never nearer the end than NEAREST)."""
    rooms = [s for s in data["spaces"] if abs(end[1] - s["floor"]) < 0.01
             and plan_check.near((end[0], end[2]), s["polygon"], 0.05)]
    reach = APPROACH

    while reach > NEAREST:
        x, z = end[0] + direction[0] * reach, end[2] + direction[1] * reach

        if not rooms or any(plan_check.inside((x, z), s["polygon"])
                            and plan_check.boundary_distance((x, z), s["polygon"]) >= CLEAR for s in rooms):
            break

        reach -= 0.05

    return [end[0] + direction[0] * reach, end[1], end[2] + direction[1] * reach]
