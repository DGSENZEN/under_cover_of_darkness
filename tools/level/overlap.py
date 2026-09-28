"""Faces of two pieces lying in one plane, facing the same way and
overlapping: they fight for the same pixels (z-fighting) and shimmer as the
camera moves (walls laid over walls along a run, a floor's edge flush with a
wall, floors overlapping). The export (export.py) pushes the earlier piece's
face back behind the later one's, RECESS, so the later piece is seen.

Pure Python: a face is {"owner": its piece's place in the layout's order,
"normal": (x, y, z), "points": [(x, y, z), ...]}.

    fights(faces)     [(loser, winner, shared area m2), ...] by face index
    recessed(faces)   the faces with every loser pushed back, round after
                      round until none fights
"""

import math
from collections import defaultdict

# Faces this near one plane fight (m); a loser is pushed back this far (m:
# out of the tolerance, too little to see); overlaps smaller than this do
# not count (m2).
TOLERANCE = 0.004
RECESS = 0.008
LEAST = 0.002
# Normals this near parallel face the same way.
SAME_WAY = 0.999
# At most this many rounds of pushing back (a stack this deep in one plane).
ROUNDS = 6


def _dot(a, b):
    return a[0] * b[0] + a[1] * b[1] + a[2] * b[2]


def _cross(a, b):
    return (a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0])


def _unit(a):
    length = math.sqrt(_dot(a, a))
    return (a[0] / length, a[1] / length, a[2] / length) if length > 0.0 else a


def _axes(normal):
    other = (1.0, 0.0, 0.0) if abs(normal[0]) < 0.9 else (0.0, 1.0, 0.0)
    u = _unit(_cross(normal, other))
    return u, _unit(_cross(normal, u))


def _flat(points, axes):
    u, v = axes
    return [(_dot(p, u), _dot(p, v)) for p in points]


def _area(poly):
    total = 0.0

    for i in range(len(poly)):
        x1, y1 = poly[i]
        x2, y2 = poly[(i + 1) % len(poly)]
        total += x1 * y2 - x2 * y1

    return abs(total) * 0.5


def _clipped(subject, clipper):
    """`subject` cut to the convex `clipper` (Sutherland-Hodgman)."""
    turn = 0.0

    for i in range(len(clipper)):
        x1, y1 = clipper[i]
        x2, y2 = clipper[(i + 1) % len(clipper)]
        turn += x1 * y2 - x2 * y1

    sign = 1.0 if turn > 0.0 else -1.0

    def inside(p, a, b):
        return sign * ((b[0] - a[0]) * (p[1] - a[1]) - (b[1] - a[1]) * (p[0] - a[0])) >= -1e-9

    def crossing(p, q, a, b):
        den = (p[0] - q[0]) * (a[1] - b[1]) - (p[1] - q[1]) * (a[0] - b[0])

        if abs(den) < 1e-12:
            return q

        t = ((p[0] - a[0]) * (a[1] - b[1]) - (p[1] - a[1]) * (a[0] - b[0])) / den
        return (p[0] + t * (q[0] - p[0]), p[1] + t * (q[1] - p[1]))

    out = list(subject)

    for i in range(len(clipper)):
        a, b = clipper[i], clipper[(i + 1) % len(clipper)]
        given, out = out, []

        if not given:
            break

        s = given[-1]

        for e in given:
            if inside(e, a, b):
                if not inside(s, a, b):
                    out.append(crossing(s, e, a, b))

                out.append(e)
            elif inside(s, a, b):
                out.append(crossing(s, e, a, b))

            s = e

    return out


def _box(poly):
    xs = [p[0] for p in poly]
    ys = [p[1] for p in poly]
    return min(xs), min(ys), max(xs), max(ys)


def fights(faces, tolerance=TOLERANCE):
    """Every pair of faces of two pieces in one plane (within `tolerance`),
    facing the same way, overlapping by LEAST or more: (loser, winner, area),
    the loser the one earlier in the layout."""
    planes = defaultdict(list)
    normals = []
    distances = []

    for i, face in enumerate(faces):
        n = _unit(face["normal"])
        d = _dot(n, face["points"][0])
        normals.append(n)
        distances.append(d)
        planes[(round(n[0], 2), round(n[1], 2), round(n[2], 2), math.floor(d / tolerance))].append(i)

    found = []

    for key, members in planes.items():
        near = members + planes.get((key[0], key[1], key[2], key[3] + 1), [])
        own = len(members)

        for a in range(own):
            i = near[a]

            for b in range(a + 1, len(near)):
                j = near[b]

                if faces[i]["owner"] == faces[j]["owner"] or abs(distances[i] - distances[j]) > tolerance:
                    continue

                if _dot(normals[i], normals[j]) < SAME_WAY:
                    continue

                axes = _axes(normals[i])
                pi = _flat(faces[i]["points"], axes)
                pj = _flat(faces[j]["points"], axes)
                bi, bj = _box(pi), _box(pj)

                if bi[2] <= bj[0] or bj[2] <= bi[0] or bi[3] <= bj[1] or bj[3] <= bi[1]:
                    continue

                shared = _clipped(pi, pj)
                area = _area(shared) if len(shared) >= 3 else 0.0

                if area >= LEAST:
                    loser, winner = (i, j) if faces[i]["owner"] < faces[j]["owner"] else (j, i)
                    found.append((loser, winner, area))

    return found


def losers(faces, tolerance=TOLERANCE):
    """The faces that give way (each once)."""
    return sorted({loser for loser, _, _ in fights(faces, tolerance)})


def recessed(faces, tolerance=TOLERANCE):
    """`faces` with each loser pushed back RECESS against its own normal,
    round after round (a stack of three in one plane: the first round pushes
    both lower ones back together, the next the lowest again) until none
    fights, or ROUNDS."""
    out = list(faces)

    for _ in range(ROUNDS):
        beaten = losers(out, tolerance)

        if not beaten:
            break

        for i in beaten:
            n = _unit(out[i]["normal"])
            moved = dict(out[i])
            moved["points"] = [(p[0] - n[0] * RECESS, p[1] - n[1] * RECESS, p[2] - n[2] * RECESS) for p in out[i]["points"]]
            out[i] = moved

    return out
