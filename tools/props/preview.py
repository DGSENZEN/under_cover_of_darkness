"""Pictures of a built fixture from four sides, each surface its slot's flat
colour times its baked vertex colour (Cycles, a key light and a dim sky),
for the user:

    Blender -b assets/props/source/<name>.blend --python preview.py -- <name> --out=<dir>
"""

import math
import os
import sys

import bpy
from mathutils import Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import common  # noqa: E402


def bounds():
    points = []

    for obj in bpy.context.scene.objects:
        if obj.type == "MESH" and not common.is_collider(obj):
            points += [obj.matrix_world @ Vector(corner) for corner in obj.bound_box]

    low = Vector((min(p.x for p in points), min(p.y for p in points), min(p.z for p in points)))
    high = Vector((max(p.x for p in points), max(p.y for p in points), max(p.z for p in points)))
    return low, high


def _shade_by_colours():
    """Every surface: its slot's flat colour times the baked "Col"."""
    for material in bpy.data.materials:
        material.use_nodes = True
        nodes = material.node_tree.nodes
        links = material.node_tree.links
        nodes.clear()
        colours = nodes.new("ShaderNodeAttribute")
        colours.attribute_name = "Col"
        tint = nodes.new("ShaderNodeRGB")
        tint.outputs[0].default_value = material.diffuse_color
        mix = nodes.new("ShaderNodeMix")
        mix.data_type = "RGBA"
        mix.blend_type = "MULTIPLY"
        mix.inputs["Factor"].default_value = 1.0
        links.new(tint.outputs[0], mix.inputs[6])
        links.new(colours.outputs["Color"], mix.inputs[7])
        shader = nodes.new("ShaderNodeBsdfPrincipled")
        shader.inputs["Roughness"].default_value = 0.85
        links.new(mix.outputs[2], shader.inputs["Base Color"])

        if material.name.endswith("_glow"):
            links.new(mix.outputs[2], shader.inputs["Emission Color"])
            shader.inputs["Emission Strength"].default_value = 2.0

        out = nodes.new("ShaderNodeOutputMaterial")
        links.new(shader.outputs[0], out.inputs["Surface"])


def main(argv):
    name = argv[0] if argv else bpy.context.scene.get("fixture", "fixture")
    out = next((a.split("=", 1)[1] for a in argv if a.startswith("--out=")), str(common.ROOT / "assets" / "props" / "preview"))
    os.makedirs(out, exist_ok=True)
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.device = "CPU"
    scene.cycles.samples = 24
    scene.cycles.use_denoising = False
    _shade_by_colours()
    sun_data = bpy.data.lights.new("Key", "SUN")
    sun_data.energy = 3.0
    sun = bpy.data.objects.new("Key", sun_data)
    sun.rotation_euler = (math.radians(50.0), 0.0, math.radians(30.0))
    scene.collection.objects.link(sun)
    scene.render.resolution_x = 512
    scene.render.resolution_y = 512
    scene.render.film_transparent = False
    world = scene.world or bpy.data.worlds.new("Preview")
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs["Color"].default_value = (0.05, 0.05, 0.06, 1.0)
    world.node_tree.nodes["Background"].inputs["Strength"].default_value = 1.5
    scene.world = world

    for obj in scene.objects:
        if common.is_collider(obj):
            obj.hide_render = True

    low, high = bounds()
    centre = (low + high) * 0.5
    size = max((high - low).length, 0.1)
    camera_data = bpy.data.cameras.new("Preview")
    camera_data.type = "ORTHO"
    camera_data.ortho_scale = size * 1.15
    camera = bpy.data.objects.new("Preview", camera_data)
    scene.collection.objects.link(camera)
    scene.camera = camera

    for index, angle in enumerate([0.0, 90.0, 180.0, 270.0]):
        turn = math.radians(angle)
        offset = Vector((math.sin(turn), -math.cos(turn), 0.35)).normalized() * size * 3.0
        camera.location = centre + offset
        camera.rotation_euler = (centre - camera.location).to_track_quat("-Z", "Y").to_euler()
        scene.render.filepath = os.path.join(out, "%s_%d.png" % (name, index))
        bpy.ops.render.render(write_still=True)

    print("props: previews of %s in %s" % (name, out))


if __name__ == "__main__":
    main(sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else [])
