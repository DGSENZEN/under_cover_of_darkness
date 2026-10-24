"""The ownerless shadow's silhouette (docs/superpowers/refs/underground/supernatural_refs.md): the
procession's dead man in his sombrero, walking, drawn from the side as one black shape on clear
(Mignola's black), for the bay's decal to throw on a wall.

    Blender -b --factory-startup --python tools/textures/shadow_figure.py

Writes textures/painted/underground/shadow_figure.png (512 x 1024, black, its alpha the shape).
"""

import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "eclipse"))

import bpy  # noqa: E402
from mathutils import Vector  # noqa: E402

import common  # noqa: E402
import underground_uncanny  # noqa: E402

OUT = common.ROOT / "textures" / "painted" / "underground" / "shadow_figure.png"


def main():
    underground_uncanny.build()

    for o in bpy.context.scene.objects:
        o.hide_render = o.name != "dead_man"

    man = bpy.data.objects["dead_man"]
    top = max((man.matrix_world @ v.co).z for v in man.data.vertices)
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_WORKBENCH"
    scene.display.shading.light = "FLAT"
    scene.display.shading.color_type = "SINGLE"
    scene.display.shading.single_color = (0.0, 0.0, 0.0)
    scene.render.film_transparent = True
    scene.render.resolution_x, scene.render.resolution_y = 512, 1024
    scene.render.image_settings.color_mode = "RGBA"
    camera = bpy.data.objects.new("side", bpy.data.cameras.new("side"))
    scene.collection.objects.link(camera)
    camera.data.type = "ORTHO"
    camera.data.ortho_scale = top * 1.04
    # From his side, so his sombrero's brim, his candle held out before him, read in silhouette.
    camera.location = (0.0, -5.0, top / 2.0)
    camera.rotation_euler = (math.radians(90.0), 0.0, 0.0)
    scene.camera = camera
    scene.render.filepath = str(OUT)
    bpy.ops.render.render(write_still=True)
    print("wrote", OUT)


if __name__ == "__main__":
    main()
