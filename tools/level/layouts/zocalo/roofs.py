"""The roofs' routes: wherever two walkable roofs of different heights meet,
a climb from the lower to the higher; then one climb up from the street to
every cluster of roofs not yet reached (roofs of one height that meet are
one surface already)."""

import math

import plan
import plan_check

# A climb's ends sit this far either side of the edge it crosses (m).
REACH = 1.0
# Edges shorter than this are corners, not walls (m).
LEAST_SHARED = 2.0


def _outward(a, b):
    dx, dz = b[0] - a[0], b[1] - a[1]
    length = math.hypot(dx, dz)
    return (dz / length, -dx / length)


def _line_distance(p, a, b):
    """How far p lies from the line through a and b."""
    dx, dz = b[0] - a[0], b[1] - a[1]
    return abs((p[0] - a[0]) * dz - (p[1] - a[1]) * dx) / math.hypot(dx, dz)


def shared_edge(pa, pb):
    """Where plot a's outline runs along plot b's: the middle of the shared
    stretch and a's outward normal there; None if they do not share one."""
    for a1, a2 in plan_check._edges(pa):
        length = math.hypot(a2[0] - a1[0], a2[1] - a1[1])

        for b1, b2 in plan_check._edges(pb):
            if _line_distance(b1, a1, a2) > 0.01 or _line_distance(b2, a1, a2) > 0.01:
                continue

            t = [((p[0] - a1[0]) * (a2[0] - a1[0]) + (p[1] - a1[1]) * (a2[1] - a1[1])) / (length * length)
                 for p in (b1, b2)]
            lo, hi = max(min(t), 0.0), min(max(t), 1.0)

            if (hi - lo) * length >= LEAST_SHARED:
                m = (lo + hi) / 2
                return ((a1[0] + m * (a2[0] - a1[0]), a1[1] + m * (a2[1] - a1[1])), _outward(a1, a2))

    return None


def lay(P):
    data = P.data()
    roofs = [p for p in data["plots"] if p["roof"]]
    index = {p["name"]: i for i, p in enumerate(roofs)}
    parent = list(range(len(roofs)))

    def find(i):
        while parent[i] != i:
            parent[i] = parent[parent[i]]
            i = parent[i]
        return i

    for i, a in enumerate(roofs):
        for b in roofs[i + 1:]:
            edge = shared_edge(a["polygon"], b["polygon"])

            if edge is None:
                continue

            parent[find(i)] = find(index[b["name"]])
            ta, tb = plan.top(a), plan.top(b)

            if abs(ta - tb) > 1e-6:
                (mx, mz), (nx, nz) = edge
                lower, higher, sign = (a, b, 1.0) if ta < tb else (b, a, -1.0)
                lo = (mx - sign * nx * REACH, mz - sign * nz * REACH)
                hi = (mx + sign * nx * REACH, mz + sign * nz * REACH)
                P.route("climb_%s_%s" % (lower["name"], higher["name"]), "climb",
                        [(lo[0], plan.top(lower), lo[1]), (hi[0], plan.top(higher), hi[1])])

    streets = [g for g in data["ground"] if abs(g["level"]) < 1e-6 and g["kind"] in plan.FRONTAGE_KINDS]
    done = set()

    for i, p in sorted(enumerate(roofs), key=lambda e: e[1]["name"]):
        root = find(i)

        if root in done:
            continue

        for a, b in plan_check._edges(p["polygon"]):
            mx, mz = (a[0] + b[0]) / 2, (a[1] + b[1]) / 2
            nx, nz = _outward(a, b)
            out = (mx + nx * REACH, mz + nz * REACH)
            into = (mx - nx * REACH, mz - nz * REACH)

            if any(plan_check.inside(out, g["polygon"]) for g in streets):
                P.route("climb_up_%s" % p["name"], "climb", [(out[0], 0.0, out[1]), (into[0], plan.top(p), into[1])])
                done.add(root)
                break
