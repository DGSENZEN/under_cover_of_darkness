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

# Triangles per piece (the style lab's plan, global constraints).
BUDGET = 2500
# Faces smaller than this (m2) are slivers.
LEAST_AREA = 1e-6
# UVs this far outside [0, 1] still count as inside (float noise).
UV_SLACK = 1e-4


def _area(face):
    flat = overlap._flat(face["points"], overlap._axes(face["normal"]))
    return abs(overlap._area(flat))


def check(faces, tris, uvs):
    problems = []

    for loser, winner, shared in overlap.fights(faces):
        problems.append("overlap: %s and %s share %.4f m2 in one plane"
                        % (faces[loser]["owner"], faces[winner]["owner"], shared))

    for face in faces:
        if _area(face) < LEAST_AREA:
            problems.append("degenerate: a face of %s has %.2e m2" % (face["owner"], _area(face)))

    outside = [uv for uv in uvs if not (-UV_SLACK <= uv[0] <= 1 + UV_SLACK and -UV_SLACK <= uv[1] <= 1 + UV_SLACK)]

    if outside:
        problems.append("uv outside: %d UVs outside the atlas, e.g. %s" % (len(outside), outside[0]))

    if tris > BUDGET:
        problems.append("over budget: %d triangles, at most %d" % (tris, BUDGET))

    return problems
