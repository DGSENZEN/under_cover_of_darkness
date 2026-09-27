"""The props pipeline's build and bake tests, run inside Blender:

    tools/props/props.sh test

A fixture rebuilt is the same fixture; its baked soot darkens what is above
its flame and not what is below.
"""

import os
import sys
import unittest

import bpy
from mathutils import Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bake  # noqa: E402
import build  # noqa: E402
import common  # noqa: E402
import recipes  # noqa: E402


def luminance(colour):
    return 0.2126 * colour[0] + 0.7152 * colour[1] + 0.0722 * colour[2]


class BuildTest(unittest.TestCase):
    def test_rebuild_same(self):
        build.build_fixture("wall_torch", recipes.FIXTURES["wall_torch"])
        first = bpy.context.scene["recipe_hash"]
        build.build_fixture("wall_torch", recipes.FIXTURES["wall_torch"])
        self.assertEqual(bpy.context.scene["recipe_hash"], first)
        self.assertEqual(first, common.recipe_hash(recipes.FIXTURES["wall_torch"]))

    def test_soot_above_flame(self):
        recipe = recipes.FIXTURES["wall_torch"]
        build.build_fixture("wall_torch", recipe)
        bake.bake_fixture(recipe, gpu=False)
        flame = Vector(recipe["sockets"]["flame"][0])
        above, below = [], []

        for obj in bpy.context.scene.objects:
            if obj.type != "MESH" or common.is_collider(obj):
                continue

            mesh = obj.data
            colours = mesh.color_attributes["Col"]

            for loop in mesh.loops:
                point = mesh.vertices[loop.vertex_index].co
                near = (Vector((point.x, point.y)) - Vector((flame.x, flame.y))).length < 0.2

                if near and point.z > flame.z - 0.05:
                    above.append(luminance(colours.data[loop.index].color))
                elif point.z < flame.z - 0.25:
                    below.append(luminance(colours.data[loop.index].color))

        self.assertTrue(above and below)
        self.assertLess(sum(above) / len(above), 0.8 * sum(below) / len(below))


if __name__ == "__main__":
    result = unittest.main(argv=["test_build"], exit=False).result
    sys.exit(0 if result.wasSuccessful() else 1)
