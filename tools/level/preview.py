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


def frame(scene):
    """The middle of the level's pieces seen from above (Blender's x, y) and
    how wide a picture holds them all (100 m at the least)."""
    lo, hi = [float("inf")] * 2, [float("-inf")] * 2

    for obj in scene.objects:
        if obj.type != "MESH" or "kit_piece" not in obj.keys():
            continue

        for corner in obj.bound_box:
            w = obj.matrix_world @ Vector(corner)

            for i in range(2):
                lo[i], hi[i] = min(lo[i], w[i]), max(hi[i], w[i])

    if lo[0] == float("inf"):
        return (0.0, 0.0), 100.0

    return ((lo[0] + hi[0]) / 2.0, (lo[1] + hi[1]) / 2.0), max(100.0, (hi[0] - lo[0]) * 1.05, (hi[1] - lo[1]) * 1.05 * 4.0 / 3.0)


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
    # (Framed on the level's pieces: a courtyard or a whole harbour.)
    (cx, cy), span = frame(scene)
    render(scene, os.path.join(out, level + "_plan.png"), (cx, cy, span + 20.0), (cx, cy, 0), ortho=span)

    for i, (sx, sy) in enumerate(((1, -1), (-1, -1), (-1, 1), (1, 1))):
        render(scene, os.path.join(out, "%s_view_%d.png" % (level, i)), (cx + sx * span * 0.55, cy + sy * span * 0.55, span * 0.4 + 5.0),
               (cx, cy, 0))

    print("level: previews -> %s" % out)


main()
