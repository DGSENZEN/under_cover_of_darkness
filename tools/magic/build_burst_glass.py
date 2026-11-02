"""The Burst's black glass (docs/superpowers/specs/2026-11-02-burst-floor-wave-design.md): five
thick spikes that tear up through a floor, six broken chunks they fall into, and the Shard's head. Flaked: curved
scooped hollows meeting at ridges, on a bent line, a blade or two grown from the same root. They
wear scripts/Magic/burst_glass.gdshader; their colours tell it how near a ridge each corner is
(red) and how deep in a flake (green). The user's pick, from the look that read as amethyst.

Each is one closed solid: blades are unioned into their spike. The script refuses an open edge.
A spike's root is at the origin, it runs a metre up +Z (the game's +Y), and it starts a little
below the floor, so it stands in it whichever way it leans.

    /Applications/Blender.app/Contents/MacOS/Blender --background --factory-startup \\
        --python tools/magic/build_burst_glass.py -- <repo root>

Saves assets/magic/source/burst_glass.blend, exports assets/magic/burst_glass.glb and
assets/magic/source/burst_glass_*.png previews.
"""

import math
import os
import random
import sys

import bmesh
import bpy
from mathutils import Matrix, Vector

ROOT = sys.argv[sys.argv.index("--") + 1]
SOURCE = os.path.join(ROOT, "assets", "magic", "source")
GLB = os.path.join(ROOT, "assets", "magic", "burst_glass.glb")

## How far below the floor a spike starts (m).
BELOW = 0.14
## Each spike: its width at the root, its faces round, how far its line bends, whether its tip
## has snapped off, and the blades grown from it [height, width, lean, turn].
SPIKES = (
    {"seed": 11, "wide": 0.34, "sides": 6, "bend": 0.1, "snapped": False, "blades": [(0.5, 0.16, 0.38, 0.6)]},
    {"seed": 23, "wide": 0.28, "sides": 5, "bend": 0.17, "snapped": False, "blades": []},
    {"seed": 37, "wide": 0.36, "sides": 7, "bend": 0.07, "snapped": True, "blades": [(0.62, 0.15, 0.3, 2.4), (0.36, 0.13, 0.5, 4.5)]},
    {"seed": 41, "wide": 0.25, "sides": 5, "bend": 0.2, "snapped": False, "blades": [(0.4, 0.11, 0.42, 3.6)]},
    {"seed": 53, "wide": 0.31, "sides": 6, "bend": 0.12, "snapped": True, "blades": []},
)
## Up a spike: how far along each ring of facets is, how wide against its root, how far its
## corners wander.
RINGS = ((0.0, 1.0, 0.1), (0.3, 0.78, 0.22), (0.62, 0.45, 0.3), (0.86, 0.17, 0.35))
CHUNKS = 6
## The Shard's flying head (and what stays in what it hits): how long (m), how wide against that,
## how many triangles it keeps.
HEAD_LONG = 0.32
HEAD_WIDE = 0.2
HEAD_TRIS = 420
CHUNK_SIZE = (0.16, 0.3)
## How fine it is cut before it is flaked (m), how many triangles it keeps.
VOXEL = 0.0125
SPIKE_TRIS = 1500
CHUNK_TRIS = 220
## The flakes: how many to a square metre of it, how wide (m), how deep against that.
FLAKES_PER_M2 = 150
FLAKE_WIDE = (0.05, 0.13)
FLAKE_DEEP = (0.1, 0.17)


def loft(rng, tall, wide, sides, bend, snapped, turn=0.0, lean=0.0):
    """A knapped blade as a bmesh: rings of few wandering corners, each turned from the last so
    its facets are triangles and not columns; closed at the root; to a point, or a snapped end."""
    bm = bmesh.new()
    bend_turn = rng.uniform(0.0, math.tau)
    bend_way = Vector((math.cos(bend_turn), math.sin(bend_turn), 0.0))
    lean_way = Vector((math.cos(turn), math.sin(turn), 0.0))
    rings = []
    rings_used = RINGS[:3] if snapped else RINGS

    for k, (along, share, wander) in enumerate(rings_used):
        at = Vector((0.0, 0.0, -BELOW + (tall + BELOW) * along)) + bend_way * bend * along * along * tall + lean_way * lean * along * tall
        offset = float(k) * 0.5
        ring = []

        for j in range(sides):
            angle = (float(j) + offset + rng.uniform(-0.17, 0.17)) * math.tau / float(sides)
            size = wide * 0.5 * share * (1.0 + rng.uniform(-wander, wander))
            # A flattened section: broken glass is a blade, not a cone.
            ring.append(bm.verts.new(at + Vector((math.cos(angle) * size, math.sin(angle) * size * 0.78, rng.uniform(-0.02, 0.02)))))

        rings.append(ring)

    for k in range(len(rings) - 1):
        low, high = rings[k], rings[k + 1]

        for j in range(sides):
            n = (j + 1) % sides
            bm.faces.new((low[j], low[n], high[j]))
            bm.faces.new((low[n], high[n], high[j]))

    bm.faces.new(rings[0][::-1])
    top = rings[-1]

    if snapped:
        # Snapped off: a low jagged break, its peak to one side.
        middle = sum((v.co for v in top), Vector()) / sides
        peak = bm.verts.new(middle + Vector((rng.uniform(-0.03, 0.03), rng.uniform(-0.03, 0.03), 0.05 * tall)))
    else:
        tip_at = Vector((0.0, 0.0, tall)) + bend_way * bend * tall + lean_way * lean * tall
        peak = bm.verts.new(tip_at)

    for j in range(sides):
        bm.faces.new((top[j], top[(j + 1) % sides], peak))

    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return bm


def as_object(bm, name):
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    return obj


def union(base, other):
    modifier = base.modifiers.new("Union", "BOOLEAN")
    modifier.operation = "UNION"
    modifier.object = other
    modifier.solver = "EXACT"
    bpy.ops.object.select_all(action="DESELECT")
    base.select_set(True)
    bpy.context.view_layer.objects.active = base
    bpy.ops.object.modifier_apply(modifier="Union")
    bpy.data.objects.remove(other)


def apply(obj, kind, **settings):
    modifier = obj.modifiers.new("Do", kind)

    for key, value in settings.items():
        setattr(modifier, key, value)

    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.modifier_apply(modifier="Do")


def tris_of(obj):
    return sum(len(p.vertices) - 2 for p in obj.data.polygons)


def flake(obj, rng, sharp_top):
    """Finely cut, then scooped by spheres from outside, so each flake is a curved hollow and they
    meet in ridges; the point drawn back out. Returns the flakes."""
    apply(obj, "REMESH", mode="VOXEL", voxel_size=VOXEL, use_smooth_shade=False)
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    bm.normal_update()
    top = max(v.co.z for v in bm.verts)
    area = sum(f.calc_area() for f in bm.faces)
    faces = list(bm.faces)
    flakes = []

    for i in range(int(area * FLAKES_PER_M2) + 6):
        face = rng.choice(faces)
        at = face.calc_center_median()

        # (Thin glass near the point takes small flakes, or it would be cut through.)
        thin = 1.0 - max(0.0, at.z / max(top, 0.01)) * 0.72
        wide = rng.uniform(*FLAKE_WIDE) * thin
        deep = wide * rng.uniform(*FLAKE_DEEP)
        radius = (wide * wide + deep * deep) / (2.0 * deep)
        flakes.append((at + face.normal * (radius - deep), radius))

    for centre, radius in flakes:
        for v in bm.verts:
            off = v.co - centre

            if off.length < radius:
                v.co = centre + off.normalized() * radius

    if sharp_top:
        peak = max(bm.verts, key=lambda w: w.co.z).co.copy()

        for v in bm.verts:
            share = (v.co.z - top * 0.84) / (top * 0.16)

            if share > 0.0:
                axis = Vector((peak.x, peak.y, v.co.z))
                # (Not quite all the way: nothing folds onto itself at the point.)
                v.co = v.co.lerp(axis, min(share, 1.0) ** 1.6 * 0.93)

    bm.to_mesh(obj.data)
    bm.free()
    return flakes


def finish(obj, flakes, budget):
    """Down to its budget. Refuses it open. Smooth inside each flake, a hard edge between them,
    and its colours say how near a ridge, how deep in a flake."""
    # (A collapse can now and then pinch an edge: try again a little finer, or refuse it.)
    whole = obj.data.copy()
    ratio = min(1.0, budget / max(tris_of(obj), 1))

    for attempt in range(8):
        obj.data = whole.copy()
        apply(obj, "DECIMATE", ratio=ratio)
        bm = bmesh.new()
        bm.from_mesh(obj.data)
        bmesh.ops.triangulate(bm, faces=bm.faces)
        bad = [e for e in bm.edges if len(e.link_faces) != 2]

        if not bad:
            break

        bm.free()
        ratio *= 1.03

    if bad:
        raise RuntimeError("%s has %d open edges" % (obj.name, len(bad)))

    bpy.data.meshes.remove(whole)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.normal_update()

    def flake_of(point):
        best = -1
        best_off = 1e9

        for i, (centre, radius) in enumerate(flakes):
            off = abs((point - centre).length - radius)

            if off < best_off:
                best_off = off
                best = i

        return best if best_off < 0.006 else -1

    owner = {f: flake_of(f.calc_center_median()) for f in bm.faces}
    ridge_verts = set()
    sharp = []

    for e in bm.edges:
        a, b = e.link_faces
        bent = a.normal.angle(b.normal, 0.0)

        if owner[a] != owner[b] and bent > math.radians(14) or bent > math.radians(38):
            sharp.append(e)
            ridge_verts.update(e.verts)

    for e in bm.edges:
        e.smooth = e not in sharp

    layer = bm.loops.layers.color.new("Color")

    for face in bm.faces:
        face.smooth = True
        deep = 1.0 if owner[face] >= 0 else 0.0

        for loop in face.loops:
            loop[layer] = (1.0 if loop.vert in ridge_verts else 0.0, deep, 0.0, 1.0)

    bm.to_mesh(obj.data)
    bm.free()
    obj.data.color_attributes.active_color_index = 0
    obj.data.color_attributes.render_color_index = 0


def build_spike(index, spec):
    rng = random.Random(spec["seed"])
    tall = 0.72 if spec["snapped"] else 1.0
    obj = as_object(loft(rng, tall, spec["wide"], spec["sides"], spec["bend"], spec["snapped"]), "Spike_%d" % index)

    for height, wide, lean, turn in spec["blades"]:
        union(obj, as_object(loft(rng, height, wide, 5, 0.05, False, turn, lean), "Blade"))

    flakes = flake(obj, rng, not spec["snapped"])
    finish(obj, flakes, SPIKE_TRIS)
    return obj


def build_chunk(index):
    """A broken piece: the hull of a few points in a splintered shape."""
    rng = random.Random(100 + index)
    bm = bmesh.new()
    size = rng.uniform(*CHUNK_SIZE)
    points = []

    for i in range(rng.randint(8, 11)):
        points.append(bm.verts.new(Vector((rng.gauss(0.0, 0.42) * size * 0.55, rng.gauss(0.0, 0.42) * size * 0.4, rng.gauss(0.0, 0.42) * size))))

    bmesh.ops.convex_hull(bm, input=points, use_existing_faces=False)
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context="VERTS")
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    obj = as_object(bm, "Chunk_%d" % index)
    flakes = flake(obj, rng, False)
    finish(obj, flakes, CHUNK_TRIS)
    return obj


def build_head():
    """The Shard's spearhead: the same flaked glass, drawn in at its heel. Its middle at the origin,
    its point up +Z (the game's +Y)."""
    rng = random.Random(71)
    obj = as_object(loft(rng, 1.0, HEAD_WIDE, 6, 0.02, False), "Head")
    flakes = flake(obj, rng, True)
    finish(obj, flakes, HEAD_TRIS)

    for v in obj.data.vertices:
        drawn = 0.45 + 0.55 * min(max((v.co.z + BELOW) / 0.3, 0.0), 1.0)
        v.co.x *= drawn
        v.co.y *= drawn

    low = min(v.co.z for v in obj.data.vertices)
    high = max(v.co.z for v in obj.data.vertices)
    obj.data.transform(Matrix.Scale(HEAD_LONG / (high - low), 4) @ Matrix.Translation((0.0, 0.0, -(low + high) * 0.5)))
    return obj


def previews(spikes, chunks):
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_EEVEE"
    scene.render.resolution_x = 900
    scene.render.resolution_y = 600
    world = bpy.data.worlds.new("World")
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs[0].default_value = (0.2, 0.21, 0.24, 1.0)
    scene.world = world
    look = bpy.data.materials.new("Glass")
    look.use_nodes = True
    principled = look.node_tree.nodes["Principled BSDF"]
    principled.inputs["Base Color"].default_value = (0.02, 0.02, 0.026, 1.0)
    principled.inputs["Roughness"].default_value = 0.2
    placed = []

    for i, obj in enumerate(spikes + chunks):
        obj.data.materials.append(look)
        placed.append((obj, obj.location.copy()))
        obj.location = Vector((float(i) * 0.5 - 1.0, 0.0, 0.0)) if i < 5 else Vector((float(i - 5) * 0.4 - 1.0, -0.55, 0.1))

    sun = bpy.data.objects.new("Sun", bpy.data.lights.new("Sun", "SUN"))
    sun.data.energy = 5.0
    sun.rotation_euler = (math.radians(55), math.radians(15), math.radians(30))
    bpy.context.collection.objects.link(sun)
    camera = bpy.data.objects.new("Camera", bpy.data.cameras.new("Camera"))
    camera.data.lens = 50
    bpy.context.collection.objects.link(camera)
    scene.camera = camera
    camera.location = (0.0, -3.2, 1.1)
    camera.rotation_euler = (Vector((0.0, 0.0, 0.42)) - camera.location).to_track_quat("-Z", "Y").to_euler()
    scene.render.filepath = os.path.join(SOURCE, "burst_glass_all.png")
    bpy.ops.render.render(write_still=True)

    for obj, was in placed:
        obj.location = was
        obj.data.materials.clear()

    bpy.data.objects.remove(sun)
    bpy.data.objects.remove(camera)


def main():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    spikes = [build_spike(i + 1, spec) for i, spec in enumerate(SPIKES)]
    chunks = [build_chunk(i + 1) for i in range(CHUNKS)]
    head = build_head()
    head.hide_render = True
    previews(spikes, chunks)
    head.hide_render = False
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(SOURCE, "burst_glass.blend"))
    bpy.ops.export_scene.gltf(filepath=GLB, export_format="GLB", export_yup=True, export_materials="NONE", export_normals=True, export_apply=False, export_vertex_color="ACTIVE", export_all_vertex_colors=False)
    print("TRIS", [sum(len(p.vertices) - 2 for p in o.data.polygons) for o in spikes + chunks])
    print("WROTE", GLB)


main()
