"""The build's own parts (build.py, common.py), on tiny scenes.

    tools/wardrobe/wardrobe.sh test

Each case builds a little and checks what came out. Runs in a
factory-fresh Blender, headless. Exit code 1 on any failure.
"""

import os
import sys

# No __pycache__ beside the tools (Blender would write one each run).
sys.dont_write_bytecode = True
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import bpy  # noqa: E402
from mathutils import Vector  # noqa: E402

import common  # noqa: E402


def fresh():
    """An empty scene."""
    bpy.ops.wm.read_factory_settings(use_empty=True)


def armature():
    """A tiny armature: root, and pelvis above it."""
    data = bpy.data.armatures.new("Arm")
    arm = bpy.data.objects.new("Armature", data)
    bpy.context.scene.collection.objects.link(arm)
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.mode_set(mode="EDIT")
    root = data.edit_bones.new("root")
    root.head, root.tail = (0, 0, 0), (0, 0, 0.1)
    pelvis = data.edit_bones.new("pelvis")
    pelvis.head, pelvis.tail = (0, 0, 1.0), (0, 0, 1.1)
    pelvis.parent = root
    bpy.ops.object.mode_set(mode="OBJECT")
    return arm


def case_chain_bones():
    """Four points make three bones in order, the first under the parent."""
    import build

    fresh()
    arm = armature()
    names = build.chain_bones(arm, "test", "pelvis", [Vector((0, 0, 1)), Vector((0, 0, 0.8)), Vector((0, 0, 0.6)), Vector((0, 0, 0.4))])
    bones = arm.data.bones
    ok = names == ["cloth_test_1", "cloth_test_2", "cloth_test_3"] and bones["cloth_test_1"].parent.name == "pelvis" \
        and bones["cloth_test_3"].parent.name == "cloth_test_2" and all(bones[n].use_deform for n in names)
    return [] if ok else ["chain: %s" % names]


def case_limits():
    """One place says how many triangles each part may have."""
    ok = (common.part_limit("heads", "weathered"), common.part_limit("headgear", "coif"),
          common.part_limit("headgear", "kettlehat"), common.part_limit("hair", "parted")) == (450, 240, 300, 220)
    return [] if ok else ["limits"]


CASES = {"chain": case_chain_bones, "limits": case_limits}


def main():
    failed = 0

    for name, run in CASES.items():
        try:
            messages = run()
        except BaseException as error:  # a crash (or a script's exit) fails that case
            messages = ["crash: %r" % error]

        print("%s %s%s" % ("PASS" if not messages else "FAIL", name, "" if not messages else ": %s" % messages))
        failed += 1 if messages else 0

    print("build: %d/%d" % (len(CASES) - failed, len(CASES)))
    sys.exit(1 if failed else 0)


main()
