"""The Burst's black glass (docs/superpowers/specs/2026-11-02-burst-floor-wave-design.md): five
thick spikes that tear up through a floor, and six broken chunks they fall into. Knapped, not
turned: few big flat facets, a bent line, a shoulder broken out here and there, a blade or two
grown from the same root. They wear scripts/Magic/burst_glass.gdshader, which draws a hairline
along each real ridge, not along the triangles a flat facet is cut into: each corner's colour is
half its barycentric corner, and half more for an edge that is no ridge.

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
CHUNK_SIZE = (0.16, 0.3)
## How sharply two faces must meet to be a ridge (degrees).
RIDGE_BENDS = 20.0


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


def finish(obj):
    """Refuses it open; then triangles, flat, each with its corners in its colours."""
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=0.0005)
    bmesh.ops.dissolve_degenerate(bm, edges=bm.edges, dist=0.0005)
    bmesh.ops.triangulate(bm, faces=bm.faces)
    bad = [e for e in bm.edges if len(e.link_faces) != 2]

    if bad:
        raise RuntimeError("%s has %d open edges" % (obj.name, len(bad)))

    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.normal_update()
    layer = bm.loops.layers.color.new("Color")

    def ridge(edge):
        a, b = edge.link_faces
        return a.normal.angle(b.normal, 0.0) > math.radians(RIDGE_BENDS)

    for face in bm.faces:
        face.smooth = False
        loops = list(face.loops)
        # What is opposite each corner: the edge from the next corner to the one after.
        no_ridge = [0.0 if ridge(loops[(k + 1) % 3].edge) else 0.5 for k in range(3)]

        for k, loop in enumerate(loops):
            values = [(0.5 if i == k else 0.0) + no_ridge[i] for i in range(3)]
            # (The export takes colours as sRGB: as paint_value does for the face.)
            loop[layer] = (values[0] ** (1.0 / 2.2), values[1] ** (1.0 / 2.2), values[2] ** (1.0 / 2.2), 1.0)

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

    finish(obj)
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
    finish(obj)
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
    previews(spikes, chunks)
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(SOURCE, "burst_glass.blend"))
    bpy.ops.export_scene.gltf(filepath=GLB, export_format="GLB", export_yup=True, export_materials="NONE", export_normals=True, export_apply=False, export_vertex_color="ACTIVE", export_all_vertex_colors=False)
    print("TRIS", [sum(len(p.vertices) - 2 for p in o.data.polygons) for o in spikes + chunks])
    print("WROTE", GLB)


main()
