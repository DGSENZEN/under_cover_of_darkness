"""Pictures of a source .blend: front, three-quarter, side and back.

    tools/wardrobe/wardrobe.sh preview watchman [--out=<dir>] [--with=heads,headgear] [--textured]
                                                [--at=<height>] [--distance=<metres>]

Workbench, flat colours from each face's fabric colour (wr_base) before the
bake; the baked textures with --textured. --with brings in other source
files' parts (the low-poly heads and headgear, not their bake sources).
Headless: the pictures are for looking at, nothing is checked.
"""

import math
import os
import sys

# No __pycache__ beside the tools (Blender would write one each run).
sys.dont_write_bytecode = True
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import bpy  # noqa: E402
from mathutils import Vector  # noqa: E402

import common  # noqa: E402

TEXTURED = "--textured" in sys.argv
VIEWS = {"front": -90.0, "three_quarter": -50.0, "side": 0.0, "back": 90.0}
LOOK_AT = Vector((0.0, 0.0, 0.93))
DISTANCE = 3.6


def main():
    target, options = common.args()
    path = common.SOURCE / ("%s.blend" % target)

    if not path.exists() or bpy.data.filepath != str(path):
        common.fail("no source/%s.blend" % target)

    out = options.get("out") or os.path.join(os.environ.get("TMPDIR", "/tmp"), "wardrobe_preview")
    os.makedirs(out, exist_ok=True)

    for name in (options.get("with") or "").split(","):
        if name:
            bring(name)

    for obj in bpy.data.objects:
        if obj.name == "Reference" or obj.name.startswith("High_"):
            obj.hide_render = True
        elif options.get("textured") and obj.type == "MESH":
            wear_bake(obj, target)

    scene = bpy.context.scene
    scene.render.engine = "BLENDER_WORKBENCH"
    scene.render.resolution_x = 480
    scene.render.resolution_y = 720
    shading = scene.display.shading
    shading.light = "STUDIO"
    shading.color_type = "TEXTURE" if options.get("textured") else "VERTEX"
    shading.show_backface_culling = False
    shading.background_type = "VIEWPORT" if hasattr(shading, "background_type") else shading.background_type

    camera = bpy.data.objects.new("PreviewCamera", bpy.data.cameras.new("PreviewCamera"))
    camera.data.lens = 50
    scene.collection.objects.link(camera)
    scene.camera = camera

    look_at = Vector((0.0, 0.0, float(options.get("at") or LOOK_AT.z)))
    distance = float(options.get("distance") or DISTANCE)

    for view, degrees in VIEWS.items():
        angle = math.radians(degrees)
        camera.location = look_at + Vector((math.cos(angle), math.sin(angle), 0.08)) * distance
        camera.rotation_euler = (look_at - camera.location).to_track_quat("-Z", "Y").to_euler()
        scene.render.filepath = os.path.join(out, "%s_%s.png" % (target, view))
        bpy.ops.render.render(write_still=True)

    print("wardrobe: previews in %s" % out)


def wear_bake(obj, target):
    """Its baked texture (assets/characters/wardrobe) as its only material."""
    if obj.name == "Outfit":
        path = common.WARDROBE / ("%s.png" % target)
    elif obj.name.startswith("Head_"):
        path = common.WARDROBE / "heads" / ("%s_light.png" % obj.name[len("Head_"):])
    elif obj.name.startswith("Gear_"):
        path = common.WARDROBE / "headgear" / ("%s.png" % obj.name[len("Gear_"):])
    else:
        return

    if not path.exists():
        return

    material = bpy.data.materials.new("preview_" + obj.name)
    material.use_nodes = True
    node = material.node_tree.nodes.new("ShaderNodeTexImage")
    node.image = bpy.data.images.load(str(path), check_existing=True)
    node.interpolation = "Closest"
    material.node_tree.nodes.active = node
    obj.data.materials.clear()
    obj.data.materials.append(material)

    for polygon in obj.data.polygons:
        polygon.material_index = 0


def bring(name):
    """The low-poly parts of source/<name>.blend, linked into this scene."""
    path = common.SOURCE / ("%s.blend" % name)

    if not path.exists():
        print("wardrobe: no source/%s.blend to bring" % name)
        return

    with bpy.data.libraries.load(str(path)) as (source, target):
        target.objects = [n for n in source.objects if n.startswith(("Head_", "Gear_"))]

    for obj in target.objects:
        if obj is not None:
            bpy.context.scene.collection.objects.link(obj)

            if TEXTURED:
                wear_bake(obj, name)


main()
