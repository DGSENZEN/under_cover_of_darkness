"""Close-ups of a lab piece's joints in flat daylight, to look at before
anyone else does (the style lab's plan, Task 3): each joint its piece's
script names in JOINTS, from its eye to its target, 768 x 768, Eevee, a sun,
each slot in a plain colour.

    Blender -b --factory-startup --python tools/eclipse/joints.py -- kiosk
        -> /tmp/eclipse-joints/kiosk_<joint>.png
"""

import importlib
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import bpy  # noqa: E402
from mathutils import Vector  # noqa: E402

import common  # noqa: E402

OUT = "/tmp/eclipse-joints"


def main():
    piece = sys.argv[sys.argv.index("--") + 1]
    module = importlib.import_module(piece)
    joints = module.JOINTS
    # Alternatives for one place are never seen together: a joint shows the
    # objects not hidden by default, or the ones its third entry names hidden.
    hidden_by_default = set(getattr(module, "HIDDEN", ()))
    bpy.ops.wm.open_mainfile(filepath=str(common.SOURCE / (piece + ".blend")))
    scene = bpy.context.scene

    try:
        scene.render.engine = "BLENDER_EEVEE"
    except TypeError:
        scene.render.engine = "BLENDER_EEVEE_NEXT"

    scene.render.resolution_x = scene.render.resolution_y = 768
    scene.render.film_transparent = False
    world = scene.world or bpy.data.worlds.new("day")
    scene.world = world
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs[0].default_value = (0.55, 0.62, 0.72, 1)
    world.node_tree.nodes["Background"].inputs[1].default_value = 0.6

    for m in bpy.data.materials:
        m.use_nodes = True
        bsdf = next((n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED"), None)

        if bsdf is not None:
            bsdf.inputs["Base Color"].default_value = (*common.SHOW.get(m.name, (0.5, 0.5, 0.5)), 1)
            bsdf.inputs["Roughness"].default_value = 0.8

    sun = bpy.data.objects.new("sun", bpy.data.lights.new("sun", "SUN"))
    sun.data.energy = 3.0
    sun.rotation_euler = (math.radians(50), 0, math.radians(30))
    scene.collection.objects.link(sun)
    camera = bpy.data.objects.new("eye", bpy.data.cameras.new("eye"))
    camera.data.lens = 28
    camera.data.clip_start = 0.02
    scene.collection.objects.link(camera)
    scene.camera = camera
    os.makedirs(OUT, exist_ok=True)

    for name, view in joints.items():
        if isinstance(view, dict):
            _stage(scene, view)
            _shoot(scene, camera, piece, name, view["eye"], view["target"])
            continue

        eye, target = view[0], view[1]
        hidden = set(view[2]) if len(view) > 2 else hidden_by_default

        for o in [o for o in scene.objects if o.name.startswith("copy_")]:
            bpy.data.objects.remove(o)

        for o in scene.objects:
            if o.type == "MESH":
                o.hide_render = o.name in hidden

        # A fourth entry places a copy of what is shown that far along (a bay's neighbour).
        if len(view) > 3:
            for o in [o for o in scene.objects if o.type == "MESH" and not o.hide_render]:
                copy = bpy.data.objects.new("copy_" + o.name, o.data)
                copy.location = Vector(view[3])
                scene.collection.objects.link(copy)

        _shoot(scene, camera, piece, name, eye, target)


def _shoot(scene, camera, piece, name, eye, target):
    camera.location = Vector(eye)
    camera.rotation_euler = (Vector(target) - Vector(eye)).to_track_quat("-Z", "Y").to_euler()
    scene.render.filepath = os.path.join(OUT, "%s_%s.png" % (piece, name))
    bpy.ops.render.render(write_still=True)
    print("joints: %s_%s" % (piece, name))


def _stage(scene, view):
    """A kit's joint as the dresser lays it: every piece hidden, copies of
    those `show` names placed and turned, and stand-in ground planes
    (x0, y0, x1, y1, z, colour) round them."""
    for o in [o for o in scene.objects if o.name.startswith(("copy_", "plane_"))]:
        bpy.data.objects.remove(o)

    for o in scene.objects:
        if o.type == "MESH":
            o.hide_render = True

    for k, (name, at, turn) in enumerate(view["show"]):
        copy = bpy.data.objects.new("copy_%d_%s" % (k, name), bpy.data.objects[name].data)
        copy.location = Vector(at)
        copy.rotation_euler = (0.0, 0.0, math.radians(turn))
        scene.collection.objects.link(copy)

    for k, (x0, y0, x1, y1, z, colour) in enumerate(view.get("planes", [])):
        mesh = bpy.data.meshes.new("plane_%d" % k)
        mesh.from_pydata([(x0, y0, z), (x1, y0, z), (x1, y1, z), (x0, y1, z)], [], [(0, 1, 2, 3)])
        material = bpy.data.materials.new("plane_%d" % k)
        material.use_nodes = True
        bsdf = next(n for n in material.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
        bsdf.inputs["Base Color"].default_value = (*colour, 1)
        bsdf.inputs["Roughness"].default_value = 0.9
        mesh.materials.append(material)
        plane = bpy.data.objects.new("plane_%d" % k, mesh)
        scene.collection.objects.link(plane)


main()
