"""A kit piece's vertex paint (docs/superpowers/specs/2026-10-09-eclipse-vertex-paint-design.md,
section 3): the piece cut on a world-aligned grid so colour has somewhere to
change, what is round each face corner measured with rays, and the rules
(weather_rules.py) baked into a colour attribute `rules`.

Colours live on face corners, not vertices: a box's corner is one vertex for
its top and its side, and the top's bleach must not bleed down the side.

Runs inside Blender (bpy, bmesh, mathutils, numpy).
"""

import math
import sys
from pathlib import Path

import bmesh
import bpy
import numpy as np
from mathutils import Matrix, Vector
from mathutils.bvhtree import BVHTree

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))

import weather_rules  # noqa: E402

# The grid every piece is cut on (m), and how near a cut may come to an
# existing edge (m): nearer, and the face is left uncut there (no slivers).
GRID = 0.5
SNAP = 0.02
# Ambient occlusion: rays per corner and how far they look (m).
RAYS = 24
REACH = 3.0
# Off the surface before a ray sets out (m).
LIFT = 1e-3
# The stand-in ground the occlusion rays see (the piece stands on the
# district's ground at z 0): its cell size (m) and how far it reaches past
# the piece (m).
GROUND_CELL = 1.0
GROUND_PAST = REACH + 1.0
AXES = "xyz"


# Densify

def _planes(lo, hi, size, lines):
    """The cuts for one object: grid planes inside its bounds and the story
    lines, each story line snapped to a grid line within SNAP."""
    planes = set()

    for axis in range(3):
        for k in range(math.ceil(lo[axis] / size - 1e-9), math.floor(hi[axis] / size + 1e-9) + 1):
            planes.add((axis, round(k * size, 6)))

    for name, value in lines:
        axis = AXES.index(name)
        snapped = round(value / size) * size

        if abs(value - snapped) < SNAP:
            value = snapped

        planes.add((axis, round(value, 6)))

    return sorted(planes)


def _crossed(face, axis, value):
    """A face the plane passes through, every corner on the plane or at
    least SNAP from it."""
    c = [v.co[axis] - value for v in face.verts]

    if not (min(c) < -1e-6 and max(c) > 1e-6):
        return False

    return all(abs(d) <= 1e-6 or abs(d) >= SNAP for d in c)


def densify(objects, lines=(), grid=GRID, coarse=None):
    """Every object's faces cut by the world-aligned grid (its own size in
    `coarse` by object name) and the story lines [(axis, value)]. Planar
    cuts: the shape does not change; UVs are interpolated."""
    coarse = coarse or {}

    for o in objects:
        bm = bmesh.new()
        bm.from_mesh(o.data)
        to_world = o.matrix_world.copy()
        bm.transform(to_world)
        size = coarse.get(o.name, grid)
        lo = [min(v.co[a] for v in bm.verts) for a in range(3)]
        hi = [max(v.co[a] for v in bm.verts) for a in range(3)]

        for axis, value in _planes(lo, hi, size, lines):
            faces = [f for f in bm.faces if _crossed(f, axis, value)]

            if not faces:
                continue

            edges = {e for f in faces for e in f.edges}
            verts = {v for f in faces for v in f.verts}
            normal = Vector((0.0, 0.0, 0.0))
            normal[axis] = 1.0
            point = Vector((0.0, 0.0, 0.0))
            point[axis] = value
            bmesh.ops.bisect_plane(bm, geom=list(verts) + list(edges) + faces, dist=1e-6, plane_co=point,
                                   plane_no=normal)

        bm.transform(to_world.inverted())
        bm.to_mesh(o.data)
        bm.free()
        o.data.update()


# Measure

def _hemisphere():
    """RAYS cosine-weighted directions round +Z (a Fibonacci spiral)."""
    out = []

    for i in range(RAYS):
        r = math.sqrt((i + 0.5) / RAYS)
        a = i * math.pi * (3.0 - math.sqrt(5.0))
        out.append(Vector((r * math.cos(a), r * math.sin(a), math.sqrt(max(0.0, 1.0 - r * r)))))

    return out


def _world(objects, ground_holes):
    """One BVH over every object in the world, and one over them and the
    stand-in ground (cells of GROUND_CELL round the piece, none inside a
    hole (x0, y0, x1, y1))."""
    verts, polys = [], []

    for o in objects:
        base = len(verts)
        verts.extend(o.matrix_world @ v.co for v in o.data.vertices)
        polys.extend([base + i for i in p.vertices] for p in o.data.polygons)

    pieces = BVHTree.FromPolygons(verts, polys, epsilon=0.0)
    lo = [min(v[a] for v in verts) - GROUND_PAST for a in range(2)]
    hi = [max(v[a] for v in verts) + GROUND_PAST for a in range(2)]
    ground_verts, ground_polys = list(verts), list(polys)
    x = lo[0]

    while x < hi[0]:
        y = lo[1]

        while y < hi[1]:
            cx, cy = x + GROUND_CELL / 2, y + GROUND_CELL / 2

            if not any(h[0] <= cx <= h[2] and h[1] <= cy <= h[3] for h in ground_holes):
                base = len(ground_verts)
                ground_verts.extend([Vector((x, y, 0.0)), Vector((x + GROUND_CELL, y, 0.0)),
                                     Vector((x + GROUND_CELL, y + GROUND_CELL, 0.0)), Vector((x, y + GROUND_CELL, 0.0))])
                ground_polys.append([base, base + 1, base + 2, base + 3])

            y += GROUND_CELL

        x += GROUND_CELL

    return pieces, BVHTree.FromPolygons(ground_verts, ground_polys, epsilon=0.0)


def _edges(o):
    """The object's bent edges in the world: ends (k, 3) twice and bend
    (k,), +1 a right-angled convex edge, -1 a concave one."""
    bm = bmesh.new()
    bm.from_mesh(o.data)
    bm.transform(o.matrix_world)
    a, b, bend = [], [], []

    for e in bm.edges:
        if len(e.link_faces) != 2:
            continue

        k = max(-1.0, min(1.0, e.calc_face_angle_signed() / (math.pi / 2)))

        if abs(k) > 0.05:
            a.append(tuple(e.verts[0].co))
            b.append(tuple(e.verts[1].co))
            bend.append(k)

    bm.free()
    return np.array(a).reshape(-1, 3), np.array(b).reshape(-1, 3), np.array(bend)


def _near_edges(points, a, b, bend):
    """Per point: proximity to convex edges (within WEAR_REACH) and to
    concave ones (within CAVITY_REACH), each 0-1."""
    convex = np.zeros(len(points))
    concave = np.zeros(len(points))

    if len(bend) == 0:
        return convex, concave

    ab = b - a
    length = np.maximum((ab * ab).sum(1), 1e-12)

    for i, p in enumerate(points):
        t = np.clip(((p - a) * ab).sum(1) / length, 0.0, 1.0)
        d = np.linalg.norm(p - (a + t[:, None] * ab), axis=1)
        convex[i] = (np.clip(bend, 0.0, 1.0) * np.clip(1.0 - d / weather_rules.WEAR_REACH, 0.0, 1.0)).max()
        concave[i] = (np.clip(-bend, 0.0, 1.0) * np.clip(1.0 - d / weather_rules.CAVITY_REACH, 0.0, 1.0)).max()

    return convex, concave


def _frame(n):
    """A rotation taking +Z to n."""
    return Vector((0.0, 0.0, 1.0)).rotation_difference(n).to_matrix()


def measure(objects, ground_holes=()):
    """By object name, per face corner (the mesh's loop order): points and
    normals in the world, and
      floor_gap     down to an up-facing face (or to z 0 when nothing is
                    hit and the corner is above it); inf for floors themselves
      overhang_gap  up to a down-facing face; inf if none
      convex, concave  proximity to bent edges, 0-1
      open_sky      the share of RAYS cosine-weighted rays that see out
                    within REACH (the stand-in ground blocks them)."""
    pieces, grounded = _world(objects, ground_holes)
    hemisphere = _hemisphere()
    out = {}

    for o in objects:
        mesh = o.data
        to_world = o.matrix_world
        turn = to_world.to_3x3().inverted().transposed()
        n_loops = len(mesh.loops)
        points = np.zeros((n_loops, 3))
        normals = np.zeros((n_loops, 3))
        floor_gap = np.full(n_loops, np.inf)
        overhang_gap = np.full(n_loops, np.inf)
        open_sky = np.ones(n_loops)
        seen = {}

        for poly in mesh.polygons:
            n = (turn @ poly.normal).normalized()
            frame = _frame(n)

            for li in poly.loop_indices:
                vi = mesh.loops[li].vertex_index
                p = to_world @ mesh.vertices[vi].co
                points[li] = tuple(p)
                normals[li] = tuple(n)
                key = (vi, round(n.x, 3), round(n.y, 3), round(n.z, 3))

                if key in seen:
                    floor_gap[li], overhang_gap[li], open_sky[li] = seen[key]
                    continue

                start = p + n * LIFT

                if n.z <= 0.7:
                    hit, hit_n, _, d = pieces.ray_cast(start, Vector((0.0, 0.0, -1.0)))

                    if hit is not None:
                        floor_gap[li] = d if hit_n.z > 0.7 else np.inf
                    elif p.z >= -1e-6:
                        floor_gap[li] = p.z

                hit, hit_n, _, d = pieces.ray_cast(start, Vector((0.0, 0.0, 1.0)))

                if hit is not None and hit_n.z < -0.7:
                    overhang_gap[li] = d

                # Each corner's rays turned about its normal by its own angle.
                angle = (math.sin(p.x * 12.9898 + p.y * 78.233 + p.z * 37.719) * 43758.5453) % 1.0 * 2 * math.pi
                spin = frame @ Matrix.Rotation(angle, 3, "Z")
                blocked = sum(1 for h in hemisphere if grounded.ray_cast(start, spin @ h, REACH)[0] is not None)
                open_sky[li] = 1.0 - blocked / RAYS
                seen[key] = (floor_gap[li], overhang_gap[li], open_sky[li])

        a, b, bend = _edges(o)
        convex, concave = _near_edges(points, a, b, bend)
        out[o.name] = {"points": points, "normals": normals, "floor_gap": floor_gap, "overhang_gap": overhang_gap,
                       "convex": convex, "concave": concave, "open_sky": open_sky}

    return out


# Bake

def soot_origins():
    """Where the builder placed its soot plumes: every empty named soot_*."""
    return [np.array(o.matrix_world.translation) for o in bpy.context.scene.objects
            if o.type == "EMPTY" and o.name.startswith("soot_")]


def _write(mesh, name, rgba):
    attribute = mesh.color_attributes.get(name)

    if attribute is None:
        attribute = mesh.color_attributes.new(name, "FLOAT_COLOR", "CORNER")

    attribute.data.foreach_set("color", np.asarray(rgba, dtype=np.float32).ravel())
    return attribute


def read(mesh, name):
    """A corner colour attribute as (n_loops, 4)."""
    attribute = mesh.color_attributes[name]
    values = np.zeros(len(attribute.data) * 4, dtype=np.float32)
    attribute.data.foreach_get("color", values)
    return values.reshape(-1, 4).astype(np.float64)


def bake(objects, name, blendable_slots=(), soot=None, ground_holes=()):
    """The rules baked into each object's corner colour attribute `rules`."""
    measured = measure(objects, ground_holes)
    soot = soot_origins() if soot is None else soot
    seed = weather_rules.seed_of(name)

    for o in objects:
        m = measured[o.name]
        mesh = o.data
        corner_slot = np.zeros(len(mesh.loops), dtype=bool)

        for poly in mesh.polygons:
            material = mesh.materials[poly.material_index] if mesh.materials else None
            corner_slot[list(poly.loop_indices)] = material is not None and material.name in blendable_slots

        rgba = weather_rules.rules(m["points"], m["normals"], m["floor_gap"], m["overhang_gap"], m["convex"],
                                   m["concave"], m["open_sky"], corner_slot, soot, seed)
        _write(mesh, "rules", rgba)
