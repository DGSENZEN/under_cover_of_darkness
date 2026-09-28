"""Pictures of the open level .blend: a plan from above and a bird's-eye view
from each corner (Workbench, the slots' colours, markers shown as small
coloured posts), written to <out>/<level>_*.png.

    Blender -b assets/level/source/<level>.blend --python tools/level/preview.py -- <out dir>
"""

import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import bpy  # noqa: E402
from mathutils import Vector  # noqa: E402

import common  # noqa: E402

MARKER_COLOURS = {"guard": (1.0, 0.2, 0.2), "light": (1.0, 0.8, 0.2), "door": (0.2, 0.6, 1.0), "station": (0.3, 1.0, 0.3),
                  "hide": (0.7, 0.3, 1.0), "vantage": (1.0, 1.0, 1.0), "mark": (1.0, 0.5, 0.0)}


def posts(scene):
    """A small coloured post at each marker (gone again after)."""
    made = []

    for obj in list(scene.objects):
        ucd = obj.get("ucd")

        if ucd not in MARKER_COLOURS:
            continue

        bpy.ops.mesh.primitive_cube_add(size=0.5, location=obj.matrix_world.translation + Vector((0, 0, 0.6)))
        post = bpy.context.object
        post.scale = (0.6, 0.6, 2.4)
        post.color = (*MARKER_COLOURS[ucd], 1.0)
        made.append(post)

    return made


def render(scene, path, location, target, ortho=None):
    data = bpy.data.cameras.new("preview")
    camera = bpy.data.objects.new("preview", data)
    scene.collection.objects.link(camera)
    camera.location = location
    direction = Vector(target) - Vector(location)
    camera.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()

    if ortho:
        data.type = "ORTHO"
        data.ortho_scale = ortho

    data.clip_end = 1000.0
    scene.camera = camera
    scene.render.filepath = path
    bpy.ops.render.render(write_still=True)
    bpy.data.objects.remove(camera)


def main():
    out = common.argv()[0] if common.argv() else str(common.ROOT / "tmp_preview")
    os.makedirs(out, exist_ok=True)
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_WORKBENCH"
    scene.display.shading.light = "STUDIO"
    scene.display.shading.color_type = "MATERIAL"
    scene.display.shading.show_shadows = True
    scene.display.shading.show_cavity = True
    scene.render.resolution_x = 1600
    scene.render.resolution_y = 1200
    level = scene.get("level", "level")
    made = posts(scene)

    for obj in made:
        obj.active_material = None

    scene.display.shading.color_type = "MATERIAL"
    render(scene, os.path.join(out, level + "_plan.png"), (0, 0, 120), (0, 0, 0), ortho=100.0)

    for i, (x, y) in enumerate(((70, -70), (-70, -70), (-70, 70), (70, 70))):
        render(scene, os.path.join(out, "%s_view_%d.png" % (level, i)), (x, y, 55), (0, 0, 0))

    print("level: previews -> %s" % out)


main()
