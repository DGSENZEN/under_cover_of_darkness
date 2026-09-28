"""Builds a level's .blend (assets/level/source/<level>.blend) from its
layout (tools/level/layouts/<level>.py, whose layout() returns the level's
data: pieces and markers, see rules.py). Each piece is an object linking the
kit's mesh (kit.blend), in its sector's collection; each marker an empty
(a cube for a box marker) with `ucd` and its properties, in the sector's
"<sector> markers" collection. After this the .blend is the user's to edit:
check and export read it back.

    Blender -b --factory-startup --python tools/level/build.py -- <level>
"""

import importlib
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import bpy  # noqa: E402

import common  # noqa: E402
import geo  # noqa: E402
import markers as schema  # noqa: E402


def collection(scene, name, parent=None):
    found = bpy.data.collections.get(name)

    if found is None:
        found = bpy.data.collections.new(name)
        (parent or scene.collection).children.link(found)

    return found


def build(level):
    sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "layouts"))
    data = importlib.import_module(level).layout()
    scene = common.scene_fresh()

    if not common.KIT.exists():
        common.fail("no kit: run `level.sh kit` first")

    wanted = sorted({common.KIT_PREFIX + p["piece"] for p in data["pieces"]})

    with bpy.data.libraries.load(str(common.KIT), link=True, relative=True) as (source, target):
        missing = [n for n in wanted if n not in source.meshes]

        if missing:
            common.fail("the kit has no %s (run `level.sh kit`)" % ", ".join(missing))

        target.meshes = wanted

    meshes = {m.name: m for m in bpy.data.meshes if m.library is not None}

    for p in data["pieces"]:
        sector = collection(scene, p["sector"])
        obj = bpy.data.objects.new(p["name"], meshes[common.KIT_PREFIX + p["piece"]])
        obj.matrix_world = common.matrix(p["position"], p["basis"])
        obj["kit_piece"] = p["piece"]
        sector.objects.link(obj)

    for m in data["markers"]:
        sector = collection(scene, p_sector := m["sector"])
        holder = collection(scene, p_sector + " markers", sector)
        empty = bpy.data.objects.new(m["name"], None)
        size = m.get("size")

        if size:
            empty.empty_display_type = "CUBE"
            empty.matrix_world = common.matrix(m["position"], m["basis"], (size[0] / 2.0, size[2] / 2.0, size[1] / 2.0))
        else:
            empty.empty_display_type = "SINGLE_ARROW" if m["ucd"] in ("guard", "spawn", "vantage", "light") else "PLAIN_AXES"
            empty.empty_display_size = 0.5
            empty.matrix_world = common.matrix(m["position"], m["basis"])

        empty["ucd"] = m["ucd"]

        for key, value in m.get("props", {}).items():
            empty[key] = value

        holder.objects.link(empty)

    scene["level"] = level
    scene["layout_hash"] = common.data_hash(data)
    path = common.level_path(level)
    path.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=str(path), relative_remap=True)
    print("level: %s: %d pieces, %d markers -> %s" % (level, len(data["pieces"]), len(data["markers"]), path.relative_to(common.ROOT)))


args = common.argv()

if not args:
    common.fail("build needs a level")

build(args[0])
