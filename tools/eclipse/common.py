"""What every style-lab piece's Blender script shares (tools/eclipse): making
meshes from boxes, prisms, tubes and fans; material slots by the card's
names; one atlas for the whole piece (UVs projected, averaged to one texel
density, packed with identical islands merged); the baked ambient occlusion
and the region map the atlas painter reads; the glTF and the .blend; and the
piece's faces for the geometry gate.

Runs inside Blender (bpy, bmesh, numpy). Blender is Z up; the card's metres
are Blender's, with the stair's run along +Y. The glTF is exported Y up.
"""

import json
import math
import os
import sys
from pathlib import Path

import bmesh
import bpy
import numpy as np
from mathutils import Vector

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
OUT = ROOT / "assets" / "eclipse" / "lab"
# The .blend and the maps the atlas painter reads: kept from Godot (.gdignore).
SOURCE = ROOT / "assets" / "eclipse" / "source"

sys.path.insert(0, str(HERE))

import gate  # noqa: E402

# Viewport colours for the joint renders, by slot (not the game's look).
SHOW = {
    "iron": (0.08, 0.14, 0.10), "brass": (0.55, 0.40, 0.14), "glass": (0.6, 0.75, 0.8),
    "tile_line2": (0.2, 0.3, 0.55), "stone_step": (0.5, 0.5, 0.52), "sign": (0.45, 0.45, 0.45),
    "tezontle": (0.42, 0.14, 0.11), "chiluca": (0.58, 0.57, 0.6), "lime": (0.85, 0.82, 0.72),
    "steel": (0.3, 0.3, 0.33), "wood_door": (0.3, 0.17, 0.1), "tile_floor": (0.45, 0.4, 0.3),
}
MARGIN = 0.006
# Slots drawn by their own material, not the atlas: no room in it for them.
ATLAS_FREE = ("glass",)


# Scene

def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def slot(name):
    """The material for a card slot, made once."""
    material = bpy.data.materials.get(name)

    if material is None:
        material = bpy.data.materials.new(name)
        material.diffuse_color = (*SHOW.get(name, (0.5, 0.5, 0.5)), 1.0)

    return material


class Mesh:
    """A piece's object being built: faces added with their slot."""

    def __init__(self, name):
        self.name = name
        self.bm = bmesh.new()
        self.slots = []
        self.smooth = False

    def _index(self, slot_name):
        if slot_name not in self.slots:
            self.slots.append(slot_name)

        return self.slots.index(slot_name)

    def face(self, points, slot_name):
        verts = [self.bm.verts.new(p) for p in points]
        f = self.bm.faces.new(verts)
        f.material_index = self._index(slot_name)
        return f

    def box(self, lo, hi, slot_name, skip=()):
        """An axis-aligned box from corner lo to hi; `skip` names faces left
        out (hidden against another piece): -x +x -y +y -z +z."""
        x0, y0, z0 = lo
        x1, y1, z1 = hi
        quads = {
            "-x": [(x0, y0, z0), (x0, y0, z1), (x0, y1, z1), (x0, y1, z0)],
            "+x": [(x1, y0, z0), (x1, y1, z0), (x1, y1, z1), (x1, y0, z1)],
            "-y": [(x0, y0, z0), (x1, y0, z0), (x1, y0, z1), (x0, y0, z1)],
            "+y": [(x0, y1, z0), (x0, y1, z1), (x1, y1, z1), (x1, y1, z0)],
            "-z": [(x0, y0, z0), (x0, y1, z0), (x1, y1, z0), (x1, y0, z0)],
            "+z": [(x0, y0, z1), (x1, y0, z1), (x1, y1, z1), (x0, y1, z1)],
        }

        for key, quad in quads.items():
            if key not in skip:
                self.face(quad, slot_name)

    def prism(self, outline, z0, z1, slot_name, caps=(True, True)):
        """A flat outline (x, y, counter-clockwise from above) stood up from
        z0 to z1: its walls, and its caps unless left out."""
        n = len(outline)

        for i in range(n):
            (ax, ay), (bx, by) = outline[i], outline[(i + 1) % n]
            self.face([(ax, ay, z0), (bx, by, z0), (bx, by, z1), (ax, ay, z1)], slot_name)

        if caps[0]:
            self.face([(x, y, z0) for x, y in reversed(outline)], slot_name)

        if caps[1]:
            self.face([(x, y, z1) for x, y in outline], slot_name)

    def tube(self, a, b, radius, sides, slot_name, caps=(False, True), twist=0.0):
        """A prism of `sides` round the line a-b, open at its ends unless capped."""
        a, b = Vector(a), Vector(b)
        axis = (b - a).normalized()
        side = axis.orthogonal().normalized()
        up = axis.cross(side)
        rings = []

        for end in (a, b):
            ring = []

            for i in range(sides):
                t = twist + 2 * math.pi * i / sides
                ring.append(end + (side * math.cos(t) + up * math.sin(t)) * radius)

            rings.append(ring)

        for i in range(sides):
            j = (i + 1) % sides
            self.face([rings[0][i], rings[0][j], rings[1][j], rings[1][i]], slot_name)

        if caps[0]:
            self.face(list(reversed(rings[0])), slot_name)

        if caps[1]:
            self.face(rings[1], slot_name)

    def bar(self, a, b, width, height, slot_name, caps=(False, False)):
        """A rectangular bar along a-b, `width` across and `height` up."""
        a, b = Vector(a), Vector(b)
        axis = (b - a).normalized()
        across = axis.cross(Vector((0, 0, 1)))

        if across.length < 1e-6:
            across = Vector((1, 0, 0))

        across.normalize()
        # (across, up, axis) right-handed, so the faces wind outward.
        up = axis.cross(across).normalized()
        w, h = across * (width / 2), up * (height / 2)
        ring = lambda p: [p - w - h, p + w - h, p + w + h, p - w + h]
        ra, rb = ring(a), ring(b)

        for i in range(4):
            j = (i + 1) % 4
            self.face([ra[i], ra[j], rb[j], rb[i]], slot_name)

        if caps[0]:
            self.face(list(reversed(ra)), slot_name)

        if caps[1]:
            self.face(rb, slot_name)

    def sphere(self, centre, radius, rings, segments, slot_name):
        c = Vector(centre)
        pts = [[c + Vector((math.sin(math.pi * r / rings) * math.cos(2 * math.pi * s / segments),
                            math.sin(math.pi * r / rings) * math.sin(2 * math.pi * s / segments),
                            math.cos(math.pi * r / rings))) * radius
                for s in range(segments)] for r in range(rings + 1)]

        for r in range(rings):
            for s in range(segments):
                t = (s + 1) % segments

                if r == 0:
                    self.face([pts[0][0], pts[1][s], pts[1][t]], slot_name)
                elif r == rings - 1:
                    self.face([pts[r][s], pts[r + 1][0], pts[r][t]], slot_name)
                else:
                    self.face([pts[r][s], pts[r + 1][s], pts[r + 1][t], pts[r][t]], slot_name)

        self.smooth = True

    def make(self):
        """The object, its faces welded where they share corners."""
        bmesh.ops.remove_doubles(self.bm, verts=self.bm.verts, dist=1e-5)
        mesh = bpy.data.meshes.new(self.name)
        self.bm.to_mesh(mesh)
        self.bm.free()

        for name in self.slots:
            mesh.materials.append(slot(name))

        for poly in mesh.polygons:
            poly.use_smooth = self.smooth

        obj = bpy.data.objects.new(self.name, mesh)
        bpy.context.scene.collection.objects.link(obj)
        return obj


def mirror_faces(obj, select, about=0.0):
    """Copies of the faces `select` picks, mirrored across x = `about` and
    turned to face the other way, their UVs kept (a wall and its mirror share
    one island)."""
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    chosen = [f for f in bm.faces if select(f)]
    made = bmesh.ops.duplicate(bm, geom=chosen)["geom"]
    verts = [g for g in made if isinstance(g, bmesh.types.BMVert)]
    faces = [g for g in made if isinstance(g, bmesh.types.BMFace)]

    for v in verts:
        v.co.x = 2 * about - v.co.x

    bmesh.ops.reverse_faces(bm, faces=faces)
    bm.to_mesh(obj.data)
    bm.free()


def turned_copy(obj, name):
    """A new object of `obj`'s faces facing the other way, its UVs kept (the
    same island: a run's start caps are its end caps turned round)."""
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    bmesh.ops.reverse_faces(bm, faces=bm.faces[:])
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()

    for m in obj.data.materials:
        mesh.materials.append(m)

    copy = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(copy)
    return copy


def repeat_faces(obj, offsets):
    """Copies of all of `obj`'s faces at each offset, their UVs kept (so
    identical pieces, a stair's steps, share one island of the atlas)."""
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    original = bm.faces[:]

    for offset in offsets:
        made = bmesh.ops.duplicate(bm, geom=original)["geom"]
        bmesh.ops.translate(bm, verts=[g for g in made if isinstance(g, bmesh.types.BMVert)], vec=offset)

    bm.to_mesh(obj.data)
    bm.free()


# The atlas

def meshes():
    return [o for o in bpy.context.scene.objects if o.type == "MESH"]


def _edit_all(objects):
    bpy.ops.object.mode_set(mode="OBJECT") if bpy.context.object and bpy.context.object.mode != "OBJECT" else None
    bpy.ops.object.select_all(action="DESELECT")

    for o in objects:
        o.select_set(True)

    bpy.context.view_layer.objects.active = objects[0]
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")


def unwrap(objects):
    """Each object's UVs projected by angle into islands at one scale (the
    same metres per UV unit everywhere). Run before repeat_faces."""
    _edit_all(objects)
    bpy.ops.uv.smart_project(angle_limit=math.radians(60), island_margin=0.0, scale_to_bounds=False,
                             correct_aspect=True)
    bpy.ops.object.mode_set(mode="OBJECT")


def _uv_area(mesh):
    uv = mesh.uv_layers.active.data
    total = 0.0

    for poly in mesh.polygons:
        pts = [Vector(uv[i].uv) for i in poly.loop_indices]
        total += sum(abs((pts[k] - pts[0]).cross(pts[k + 1] - pts[0])) / 2 for k in range(1, len(pts) - 1))

    return total


def _free(o):
    """Wholly of slots that draw without the atlas (glass)."""
    return all(m.name in ATLAS_FREE for m in o.data.materials)


def to_metres(objects):
    """Each object's UVs scaled to one UV unit a metre (smart_project fits
    each object to the square on its own, so their scales differ); objects
    that draw without the atlas shrunk to a speck of it."""
    for i, o in enumerate(objects):
        mesh = o.data
        uv_area = _uv_area(mesh)
        world = sum(p.area for p in mesh.polygons)
        # Each object's islands start far from every other's: the packer merges
        # islands that overlap, which must only be an object's own copies (a
        # stair's steps, a wall's mirror), never two objects that happen to
        # lie on each other after unwrapping.
        apart = 1000.0 * (i + 1)

        if uv_area > 0:
            k = 0.002 if _free(o) else math.sqrt(world / uv_area)

            for loop in mesh.uv_layers.active.data:
                loop.uv = (loop.uv[0] * k + apart, loop.uv[1] * k)


def pack(objects):
    """All islands packed into one atlas, the same texel density everywhere,
    identical islands (a stair's steps) merged into one."""
    _edit_all(objects)
    bpy.ops.uv.select_all(action="SELECT")
    bpy.ops.uv.pack_islands(rotate=True, scale=True, merge_overlap=True, margin_method="FRACTION",
                            margin=MARGIN, shape_method="CONCAVE")
    bpy.ops.object.mode_set(mode="OBJECT")


def density(objects, atlas_px):
    """Atlas pixels per metre: the UV length of each edge over its length in
    the world, the median over every edge longer than 10 cm."""
    ratios = []

    for o in [o for o in objects if not _free(o)]:
        mesh = o.data
        uv = mesh.uv_layers.active.data

        for poly in mesh.polygons:
            loops = list(poly.loop_indices)

            for k in range(len(loops)):
                a, b = loops[k], loops[(k + 1) % len(loops)]
                va = o.matrix_world @ mesh.vertices[mesh.loops[a].vertex_index].co
                vb = o.matrix_world @ mesh.vertices[mesh.loops[b].vertex_index].co
                world = (va - vb).length

                if world > 0.1:
                    ratios.append((Vector(uv[a].uv) - Vector(uv[b].uv)).length * atlas_px / world)

    return float(np.median(ratios)) if ratios else 0.0


def _image(name, px, colour):
    image = bpy.data.images.get(name) or bpy.data.images.new(name, px, px, alpha=False)
    image.generated_color = colour
    return image


def bake_ao(objects, name, px, skip_slots=ATLAS_FREE, sets=None):
    """Ambient occlusion baked into the atlas (Cycles), white where open.
    Objects wholly of a skipped slot neither take it nor cast it. With
    `sets` (lists of object names seen together), each set is baked with only
    itself present, so alternatives for one place (a stone and a steel
    column) do not shade each other; an object takes the bake of the first
    set it is in."""
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.samples = 64
    scene.cycles.device = "CPU"

    if scene.world is None:
        scene.world = bpy.data.worlds.new("lab")

    scene.world.light_settings.distance = 1.0
    image = _image(name + "_ao", px, (1, 1, 1, 1))
    free = {o.name for o in objects if all(m.name in skip_slots for m in o.data.materials)}
    sets = list(sets) if sets is not None else [[o.name for o in objects]]
    baked = set()
    first = True

    for names in sets:
        takers = [o for o in objects if o.name in names and o.name not in free and o.name not in baked]

        if not takers:
            continue

        for o in objects:
            o.hide_render = o.name not in names or o.name in free

        for m in {m for o in takers for m in o.data.materials}:
            m.use_nodes = True
            node = m.node_tree.nodes.get("bake") or m.node_tree.nodes.new("ShaderNodeTexImage")
            node.name = "bake"
            node.image = image
            m.node_tree.nodes.active = node

        bpy.ops.object.select_all(action="DESELECT")

        for o in takers:
            o.select_set(True)

        bpy.context.view_layer.objects.active = takers[0]
        bpy.ops.object.bake(type="AO", margin=4, use_clear=first)
        first = False
        baked |= {o.name for o in takers}

        for m in {m for o in takers for m in o.data.materials}:
            m.node_tree.nodes.remove(m.node_tree.nodes["bake"])

    for o in objects:
        o.hide_render = False

    return image


def _fill_triangle(grid, a, b, c, value):
    """Every texel whose centre is inside the UV triangle abc set to value."""
    px = grid.shape[0]
    pts = np.array([a, b, c]) * px - 0.5
    lo = np.floor(pts.min(axis=0)).astype(int).clip(0, px - 1)
    hi = np.ceil(pts.max(axis=0)).astype(int).clip(0, px - 1)
    xs, ys = np.meshgrid(np.arange(lo[0], hi[0] + 1), np.arange(lo[1], hi[1] + 1))
    (ax, ay), (bx, by), (cx, cy) = pts
    d = (by - cy) * (ax - cx) + (cx - bx) * (ay - cy)

    if abs(d) < 1e-12:
        return

    l1 = ((by - cy) * (xs - cx) + (cx - bx) * (ys - cy)) / d
    l2 = ((cy - ay) * (xs - cx) + (ax - cx) * (ys - cy)) / d
    inside = (l1 >= -1e-3) & (l2 >= -1e-3) & (1 - l1 - l2 >= -1e-3)
    grid[ys[inside], xs[inside]] = value


def regions(objects, slots, px):
    """The region map: each texel the index of the slot drawn there (+1;
    0 where nothing is), grown by two texels so the painter's margins match
    the bake's. Row 0 is the atlas's bottom (V = 0)."""
    grid = np.zeros((px, px), dtype=np.int32)

    for o in objects:
        mesh = o.data
        uv = mesh.uv_layers.active.data

        for poly in mesh.polygons:
            value = slots.index(mesh.materials[poly.material_index].name) + 1
            loops = list(poly.loop_indices)

            for k in range(1, len(loops) - 1):
                _fill_triangle(grid, uv[loops[0]].uv, uv[loops[k]].uv, uv[loops[k + 1]].uv, value)

    for _ in range(2):
        grown = grid.copy()

        for dy, dx in ((0, 1), (0, -1), (1, 0), (-1, 0)):
            shifted = np.roll(grid, (dy, dx), axis=(0, 1))
            grown = np.where(grown == 0, shifted, grown)

        grid = grown

    return grid


def _fill_triangle_vectors(grid, a, b, c, values):
    """Every texel whose centre is inside the UV triangle abc set to the
    vectors at its corners (3 x k), interpolated."""
    px = grid.shape[0]
    pts = np.array([a, b, c]) * px - 0.5
    lo = np.floor(pts.min(axis=0)).astype(int).clip(0, px - 1)
    hi = np.ceil(pts.max(axis=0)).astype(int).clip(0, px - 1)
    xs, ys = np.meshgrid(np.arange(lo[0], hi[0] + 1), np.arange(lo[1], hi[1] + 1))
    (ax, ay), (bx, by), (cx, cy) = pts
    d = (by - cy) * (ax - cx) + (cx - bx) * (ay - cy)

    if abs(d) < 1e-12:
        return

    l1 = ((by - cy) * (xs - cx) + (cx - bx) * (ys - cy)) / d
    l2 = ((cy - ay) * (xs - cx) + (ax - cx) * (ys - cy)) / d
    l3 = 1 - l1 - l2
    inside = (l1 >= -1e-3) & (l2 >= -1e-3) & (l3 >= -1e-3)
    v = np.asarray(values, dtype=np.float64)
    grid[ys[inside], xs[inside]] = (l1[..., None] * v[0] + l2[..., None] * v[1] + l3[..., None] * v[2])[inside]


def _tangents(p, uv):
    """The world directions of +U and +V across a triangle."""
    e1, e2 = p[1] - p[0], p[2] - p[0]
    du1, dv1 = uv[1] - uv[0]
    du2, dv2 = uv[2] - uv[0]
    det = du1 * dv2 - du2 * dv1

    if abs(det) < 1e-12:
        return np.zeros(3), np.zeros(3)

    t = (e1 * dv2 - e2 * dv1) / det
    b = (e2 * du1 - e1 * du2) / det
    return t / max(np.linalg.norm(t), 1e-9), b / max(np.linalg.norm(b), 1e-9)


def texels(objects, slots, px):
    """What every texel of the atlas shows: its slot's index (-1 where
    nothing is), world position, normal, and the world directions of +U and
    +V, grown by two texels so the painter's margins match the bake's. In
    image order: row 0 is the top (V = 1). For the atlas painter."""
    grid = np.full((px, px, 14), np.nan)
    edges = []   # by polygon id: [(a, b, convexity -1..1), ...] in the world
    # Which object first drew each texel, and texels another object drew too.
    owner = np.full((px, px), -1, dtype=np.int64)
    clashes = {}

    for oi, o in enumerate(objects):
        mesh = o.data
        uv = mesh.uv_layers.active.data
        to_world = o.matrix_world
        bm = bmesh.new()
        bm.from_mesh(mesh)
        bm.faces.ensure_lookup_table()

        for poly in mesh.polygons:
            face_edges = []

            for e in bm.faces[poly.index].edges:
                bend = e.calc_face_angle_signed() if len(e.link_faces) == 2 else 0.0
                ends = [np.array(to_world @ v.co) for v in e.verts]
                face_edges.append((ends[0], ends[1], max(-1.0, min(1.0, bend / (math.pi / 2)))))

            pid = len(edges)
            edges.append(face_edges)
            index = slots.index(mesh.materials[poly.material_index].name)
            normal = np.array(to_world.to_3x3() @ poly.normal)
            normal /= max(np.linalg.norm(normal), 1e-9)
            loops = list(poly.loop_indices)
            world = [np.array(to_world @ mesh.vertices[mesh.loops[i].vertex_index].co) for i in loops]
            uvs = [np.array(uv[i].uv) for i in loops]

            for k in range(1, len(loops) - 1):
                tri = [0, k, k + 1]
                tu, tv = _tangents([world[j] for j in tri], [uvs[j] for j in tri])
                rows = [np.concatenate([[index], world[j], normal, tu, tv, [pid]]) for j in tri]
                _fill_triangle_vectors(grid, uvs[0], uvs[k], uvs[k + 1], rows)
                mark = np.full((px, px), np.nan)
                _fill_triangle_vectors(mark[..., None], uvs[0], uvs[k], uvs[k + 1], [[1.0], [1.0], [1.0]])
                drawn = ~np.isnan(mark)
                theirs = drawn & (owner >= 0) & (owner != oi)

                for other in np.unique(owner[theirs]):
                    pair = tuple(sorted((objects[other].name, o.name)))
                    clashes[pair] = clashes.get(pair, 0) + int((owner[theirs] == other).sum())

                owner[drawn & (owner < 0)] = oi

        bm.free()

    for _ in range(2):
        for dy, dx in ((0, 1), (0, -1), (1, 0), (-1, 0)):
            shifted = np.roll(grid, (dy, dx), axis=(0, 1))
            grid = np.where(np.isnan(grid), shifted, grid)

    grid = grid[::-1]
    empty = np.isnan(grid[..., 0])
    grid = np.nan_to_num(grid)
    slot = np.where(empty, -1, np.round(grid[..., 0])).astype(np.int16)
    wear, cavity = _bends(grid[..., 1:4], np.where(empty, -1, np.round(grid[..., 13])).astype(np.int64), edges)
    texels.clashes = clashes
    return {"slot": slot, "position": grid[..., 1:4].astype(np.float32), "normal": grid[..., 4:7].astype(np.float32),
            "tangent_u": grid[..., 7:10].astype(np.float32), "tangent_v": grid[..., 10:13].astype(np.float32),
            "wear": wear.astype(np.float32), "cavity": cavity.astype(np.float32)}


# How far from an edge (m) its wear and its cavity reach.
WEAR_REACH = 0.05
CAVITY_REACH = 0.12


def _bends(position, poly, edges):
    """For every texel: how near it lies to a convex edge of its own face
    (where paint and stone wear), and to a concave one (where dirt sits),
    each 0-1, by distance in the world along the face."""
    wear = np.zeros(poly.shape)
    cavity = np.zeros(poly.shape)
    flat = poly.ravel()
    order = np.argsort(flat, kind="stable")
    ids, starts = np.unique(flat[order], return_index=True)
    ends = list(starts[1:]) + [len(order)]

    for pid, start, end in zip(ids, starts, ends):
        if pid < 0:
            continue

        cells = order[start:end]
        p = position.reshape(-1, 3)[cells]
        near_convex = np.zeros(len(cells))
        near_concave = np.zeros(len(cells))

        for a, b, bend in edges[pid]:
            if abs(bend) < 0.05:
                continue

            ab = b - a
            t = np.clip(((p - a) @ ab) / max(ab @ ab, 1e-12), 0.0, 1.0)
            d = np.linalg.norm(p - (a + t[:, None] * ab), axis=1)

            if bend > 0:
                near_convex = np.maximum(near_convex, bend * np.clip(1.0 - d / WEAR_REACH, 0.0, 1.0))
            else:
                near_concave = np.maximum(near_concave, -bend * np.clip(1.0 - d / CAVITY_REACH, 0.0, 1.0))

        wear.ravel()[cells] = near_convex
        cavity.ravel()[cells] = near_concave

    return wear, cavity


def _save_png(path, rgba, px):
    image = bpy.data.images.new(path.stem, px, px, alpha=True)
    image.pixels.foreach_set(rgba.astype(np.float32).ravel())
    image.filepath_raw = str(path)
    image.file_format = "PNG"
    image.save()
    bpy.data.images.remove(image)


def dump_faces(objects):
    """Every face in the world, as overlap.py takes them; the triangle count
    and every UV, for the gate."""
    faces, uvs, tris = [], [], 0

    for o in objects:
        mesh = o.data
        uv = mesh.uv_layers.active.data if mesh.uv_layers.active else None

        for poly in mesh.polygons:
            points = [tuple(o.matrix_world @ mesh.vertices[v].co) for v in poly.vertices]
            normal = tuple((o.matrix_world.to_3x3() @ poly.normal).normalized())
            faces.append({"owner": o.name, "normal": normal, "points": points})
            tris += len(poly.vertices) - 2

            if uv is not None:
                uvs.extend(tuple(uv[i].uv) for i in poly.loop_indices)

    return faces, tris, uvs


def _weather(objects, name, settings, gate_sets=None):
    """The piece densified and its vertex paint baked: the rules, then the
    user's strokes over them (any lost listed), then fresh painting layers;
    `rules` is what goes out as COLOR_0. The soot empties go once baked."""
    import weather

    weather.densify(objects, lines=settings.get("lines", ()), coarse=settings.get("coarse"))
    # Measured as the AO bake is: each set seen together on its own, glass
    # shading nothing.
    weather.bake(objects, name, blendable_slots=tuple(settings.get("blendable", ())),
                 ground_holes=tuple(settings.get("ground_holes", ())),
                 foot_slots=tuple(settings.get("foot", settings.get("blendable", ()))),
                 sets=[list(names) for names in gate_sets] if gate_sets is not None else None,
                 free=[o.name for o in objects if _free(o)])

    for line in weather.apply(objects, name):
        print("%s: %s" % (name, line))

    weather.paint_layers(objects)

    for o in objects:
        rules = o.data.color_attributes["rules"]
        o.data.color_attributes.active_color = rules
        o.data.color_attributes.render_color_index = o.data.color_attributes.find("rules")

    for o in [o for o in bpy.context.scene.objects if o.type == "EMPTY" and o.name.startswith("soot_")]:
        bpy.data.objects.remove(o)

    (SOURCE / "PAINTING.md").write_text(weather.PAINTING_NOTE)
    _probe(objects, name, weather)


def _probe(objects, name, weather):
    """One corner whose colour is most mid-grey (so sRGB and linear tell
    apart), written for Godot's import test: its place and facing in the
    glTF's Y-up axes, and its RGBA."""
    best = None

    for o in objects:
        rules = weather.read(o.data, "rules")
        points, normals = weather._corners(o.data)
        middle = np.minimum(rules, 1.0 - rules)[:, :3].max(axis=1)
        i = int(np.argmax(middle))

        if best is None or middle[i] > best[0]:
            p = o.matrix_world @ Vector(points[i])
            n = (o.matrix_world.to_3x3() @ Vector(normals[i])).normalized()
            best = (middle[i], o.name, [p.x, p.z, -p.y], [n.x, n.z, -n.y], list(rules[i]))

    (SOURCE / (name + "_probe.json")).write_text(json.dumps({"object": best[1], "position": best[2],
                                                               "normal": best[3], "rgba": best[4]}, indent=1))


def export_piece(name, atlas_px, slots, merge=None, gate_sets=None, share=None, weather=None):
    """The piece's atlas made (unwrap, any repeats, pack), its AO and region
    maps, glTF and .blend written; then the gate. `merge` is a function run
    between unwrap and pack (repeat_faces for identical parts). `weather`
    ({"lines", "coarse", "blendable", "foot", "ground_holes"}) densifies the piece
    after its atlas is made and bakes its vertex paint, the user's strokes
    over the rules (tools/eclipse/weather.py). Exits non-zero if the gate
    finds a problem."""
    OUT.mkdir(parents=True, exist_ok=True)
    SOURCE.mkdir(parents=True, exist_ok=True)
    (SOURCE / ".gdignore").touch()
    objects = meshes()
    unwrap(objects)
    to_metres(objects)

    if merge is not None:
        merge()
        objects = meshes()

    pack(objects)
    px_per_m = density(objects, atlas_px)

    ao = bake_ao(objects, name, atlas_px, sets=list(gate_sets) if gate_sets is not None else None)
    ao.filepath_raw = str(SOURCE / (name + "_ao.png"))
    ao.file_format = "PNG"
    ao.save()

    grid = regions(objects, slots, atlas_px)
    rgba = np.zeros((atlas_px, atlas_px, 4))
    rgba[..., 0] = np.where(grid > 0, (grid - 1) * 16, 0) / 255.0
    rgba[..., 3] = np.where(grid > 0, 1.0, 0.0)
    _save_png(SOURCE / (name + "_regions.png"), rgba, atlas_px)
    (SOURCE / (name + "_regions.json")).write_text(json.dumps({"slots": slots, "atlas_px": atlas_px,
                                                               "px_per_m": round(px_per_m, 2)}, indent=1))
    np.savez_compressed(SOURCE / (name + "_texels.npz"), **texels(objects, slots, atlas_px))
    # Two objects painted on the same texels show each other's paint (the
    # kiosk's risers drew the brass plates'): only declared pairs may share.
    shared = {tuple(sorted(pair)) for pair in (share or [])}
    clashes = {pair: n for pair, n in texels.clashes.items() if pair not in shared and n > 0}

    for (a, b), n in sorted(clashes.items()):
        print("%s: atlas overlap: %s and %s share %d texels" % (name, a, b, n))

    if clashes:
        sys.exit(1)

    if weather is not None:
        _weather(objects, name, weather, gate_sets)

    bpy.ops.export_scene.gltf(filepath=str(OUT / (name + ".glb")), export_format="GLB", export_yup=True,
                              export_materials="EXPORT", export_texcoords=True, export_normals=True,
                              export_tangents=True, use_selection=False,
                              export_vertex_color="NAME" if weather is not None else "NONE",
                              export_vertex_color_name="rules", export_all_vertex_colors=False)
    bpy.context.preferences.filepaths.save_version = 0   # no .blend1 beside it
    bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE / (name + ".blend")))

    # Alternatives for one place (a stone or a steel column) are never seen
    # together: each set that can be is gated on its own.
    problems = []
    tris = 0

    for names in gate_sets or [[o.name for o in objects]]:
        faces, set_tris, uvs = dump_faces([o for o in objects if o.name in names])
        problems += [p for p in gate.check(faces, set_tris, uvs) if p not in problems]
        tris = max(tris, set_tris)

    for p in problems:
        print("%s: %s" % (name, p))

    if problems:
        sys.exit(1)

    print("%s: clean, %d tris, %.1f px/m" % (name, tris, px_per_m))
    return tris, px_per_m
