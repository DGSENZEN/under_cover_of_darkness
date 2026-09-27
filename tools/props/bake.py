"""A built fixture's shading baked into its vertex colours ("Col"):

    Blender -b assets/props/source/<name>.blend --python bake.py -- <name>

  ambient occlusion  Cycles, from the fixture's own parts (a cup darkens
                     where the stick goes in, a bowl inside), softened to
                     0.5..1 so thin iron never goes black
  grime              blotches, 0.8..1 (seeded, the same every bake)
  soot               above every flame, darkest right over it:
                     1 - 0.7 exp(-d^2 / 0.02) with d the distance across

Always on the CPU: props are small, and Metal kernel compiles have crashed
headless Blender before (the wardrobe, Sept 26).
"""

import math
import os
import random
import sys

import bpy
from mathutils import Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import common  # noqa: E402
import recipes  # noqa: E402

ATTRIBUTE = "Col"
AO_DISTANCE = 0.25
AO_SAMPLES = 32
AO_FLOOR = 0.5


def _meshes():
    return [o for o in bpy.context.scene.objects if o.type == "MESH" and not common.is_collider(o)]


def _cycles(gpu):
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.device = "CPU"
    scene.cycles.samples = AO_SAMPLES
    scene.cycles.use_denoising = False

    if scene.world is None:
        scene.world = bpy.data.worlds.new("Bake")

    scene.world.light_settings.distance = AO_DISTANCE
    del gpu  # props always bake on the CPU (see the module's words)


def bake_ao(gpu=False):
    _cycles(gpu)
    meshes = _meshes()

    for obj in meshes:
        colours = obj.data.color_attributes.get(ATTRIBUTE)

        if colours is None:
            colours = obj.data.color_attributes.new(name=ATTRIBUTE, type="BYTE_COLOR", domain="CORNER")

        obj.data.color_attributes.active_color = colours
        obj.data.color_attributes.render_color_index = obj.data.color_attributes.active_color_index

    bpy.ops.object.select_all(action="DESELECT")

    for obj in meshes:
        obj.select_set(True)

    bpy.context.view_layer.objects.active = meshes[0]
    bpy.ops.object.bake(type="AO", target="VERTEX_COLORS")


def soot_at(point, flames):
    """How much of its colour a point keeps under the soot of `flames`."""
    keep = 1.0

    for flame in flames:
        if point.z > flame.z - 0.05:
            across = (Vector((point.x, point.y)) - Vector((flame.x, flame.y))).length

            if across < 0.35:
                keep *= 1.0 - 0.7 * math.exp(-(across * across) / 0.02)

    return keep


def grime_and_soot(recipe):
    flames = [Vector(p) for p in recipe.get("sockets", {}).get("flame", [])]
    rng = random.Random(common.recipe_hash(recipe))

    for obj in _meshes():
        mesh = obj.data
        colours = mesh.color_attributes[ATTRIBUTE]
        grime = [0.8 + 0.2 * rng.random() for _ in mesh.vertices]

        for loop in mesh.loops:
            point = mesh.vertices[loop.vertex_index].co
            keep = grime[loop.vertex_index] * soot_at(point, flames)
            r, g, b, a = colours.data[loop.index].color
            r, g, b = [AO_FLOOR + (1.0 - AO_FLOOR) * c for c in (r, g, b)]
            colours.data[loop.index].color = (r * keep, g * keep, b * keep, a)


def bake_fixture(recipe, gpu=False):
    bake_ao(gpu)
    grime_and_soot(recipe)


def main(argv):
    name = argv[0] if argv else bpy.context.scene.get("fixture", "")

    if name not in recipes.FIXTURES:
        common.fail("no fixture called '%s'" % name)

    if bpy.context.scene.get("recipe_hash") != common.recipe_hash(recipes.FIXTURES[name]):
        common.fail("%s.blend is older than its recipe: build it again first" % name)

    bake_fixture(recipes.FIXTURES[name])
    path = common.SOURCE / (name + ".blend")
    common.backup(path)
    bpy.ops.wm.save_as_mainfile(filepath=str(path))
    print("props: baked %s" % name)


if __name__ == "__main__":
    main(sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else [])
