"""The geometry gate a style-lab piece must pass before anyone looks at it:
no two faces fighting in one plane (z-fighting, found by
tools/level/overlap.py), no sliver faces, its UVs inside the atlas, and its
triangles within budget. Pure Python.

    check(faces, tris, uvs)   the problems, each a sentence; [] when clean

A face is overlap.py's {"owner", "normal", "points"}; the owner is the
piece's object it came from.
"""

import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "level"))

import overlap  # noqa: E402

# Triangles per piece: densified on a 0.5 m grid for vertex paint (the
# vertex-paint plan, Oct 9 2026; it was 2500).
BUDGET = 5000
# Faces smaller than this (m2) are degenerate.
LEAST_AREA = 1e-6
# Faces thinner than this (m: area over longest edge) are slivers. A steel
# column's flange is 1.5 cm by design; weather.densify keeps its own cuts
# 2 cm from any edge.
SLIVER = 0.01
# UVs this far outside [0, 1] still count as inside (float noise).
UV_SLACK = 1e-4


def _area(face):
    flat = overlap._flat(face["points"], overlap._axes(face["normal"]))
    return abs(overlap._area(flat))


def _thickness(face):
    """A face's thinnest extent: its area over its longest edge."""
    points = face["points"]
    longest = max(sum((a - b) ** 2 for a, b in zip(points[i], points[(i + 1) % len(points)])) ** 0.5
                  for i in range(len(points)))
    return _area(face) / max(longest, 1e-12)


# Faces facing the same way closer than this (m), and overlapping, fight for
# depth at a distance however carefully they were placed (a plate laid a
# centimetre off a wall): details are joined into the surface, not stacked on it.
LAYER_GAP = 0.03


def layered(faces, gap=LAYER_GAP):
    """Pairs of faces, of one object or two, facing the same way in planes
    `gap` or nearer, overlapping by overlap.LEAST or more: (i, j, gap, area)."""
    found = []
    normals = [overlap._unit(f["normal"]) for f in faces]
    distances = [overlap._dot(n, f["points"][0]) for n, f in zip(normals, faces)]
    boxes = [overlap._box(overlap._flat(f["points"], overlap._axes(n))) for f, n in zip(faces, normals)]

    for i in range(len(faces)):
        for j in range(i + 1, len(faces)):
            if overlap._dot(normals[i], normals[j]) < overlap.SAME_WAY:
                continue

            apart = abs(distances[i] - distances[j])

            if apart > gap or (apart <= overlap.TOLERANCE and faces[i]["owner"] != faces[j]["owner"]):
                continue   # far enough apart; or one plane across two objects, which fights() reports

            axes = overlap._axes(normals[i])
            bi = overlap._box(overlap._flat(faces[i]["points"], axes))
            bj = overlap._box(overlap._flat(faces[j]["points"], axes))

            if bi[2] <= bj[0] or bj[2] <= bi[0] or bi[3] <= bj[1] or bj[3] <= bi[1]:
                continue

            shared = overlap._clipped(overlap._flat(faces[i]["points"], axes), overlap._flat(faces[j]["points"], axes))
            area = abs(overlap._area(shared)) if len(shared) >= 3 else 0.0

            if area >= overlap.LEAST:
                found.append((i, j, apart, area))

    return found


def check(faces, tris, uvs):
    problems = []

    for i, j, apart, area in layered(faces):
        problems.append("layered: %s over %s, %.1f cm apart, %.4f m2" % (faces[j]["owner"], faces[i]["owner"],
                                                                         apart * 100, area))

    for loser, winner, shared in overlap.fights(faces):
        problems.append("overlap: %s and %s share %.4f m2 in one plane"
                        % (faces[loser]["owner"], faces[winner]["owner"], shared))

    for face in faces:
        if _area(face) < LEAST_AREA:
            problems.append("degenerate: a face of %s has %.2e m2" % (face["owner"], _area(face)))
        elif _thickness(face) < SLIVER:
            problems.append("sliver: a face of %s is %.1f cm thin" % (face["owner"], _thickness(face) * 100))

    outside = [uv for uv in uvs if not (-UV_SLACK <= uv[0] <= 1 + UV_SLACK and -UV_SLACK <= uv[1] <= 1 + UV_SLACK)]

    if outside:
        problems.append("uv outside: %d UVs outside the atlas, e.g. %s" % (len(outside), outside[0]))

    if tris > BUDGET:
        problems.append("over budget: %d triangles, at most %d" % (tris, BUDGET))

    return problems
