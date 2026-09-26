"""The bake's passes (bake.py) on tiny parts, and what the bake and the
export write over.

    tools/wardrobe/wardrobe.sh test

Each case bakes a small clean part and checks what the bake saw, or writes
over a file and checks what was kept. Runs in a factory-fresh Blender,
headless (Cycles). Exit code 1 on any failure.
"""

import os
import sys

# No __pycache__ beside the tools (Blender would write one each run).
sys.dont_write_bytecode = True
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import bpy  # noqa: E402

import pathlib  # noqa: E402
import tempfile  # noqa: E402

import numpy as np  # noqa: E402

import bake  # noqa: E402
import common  # noqa: E402
import export  # noqa: E402


def fresh():
    """An empty scene, set up to bake."""
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bake.cycles()


def plate(name, z=0.0):
    """A flat 20 cm square facing up at height z, unwrapped, a garment."""
    bpy.ops.mesh.primitive_plane_add(size=0.2, location=(0.0, 0.0, z))
    obj = bpy.context.object
    obj.name = name
    bpy.ops.object.transform_apply(location=True)
    common.set_faces(obj, 1, 1, 0.004, False, False, (0.5, 0.5, 0.5))
    return obj


def occlusion(obj):
    low, high = bake.bounds(obj)
    passes = bake.data_passes(obj, 32, low, high)
    return passes["ao"][passes["covered"]]


def case_alone():
    """Nothing over a lone flat part: nothing darkens it (the part itself,
    under the copy the bake works on, must not)."""
    fresh()
    ao = occlusion(plate("Part"))
    return [] if ao.size and ao.mean() > 0.95 else ["ao: a lone flat part baked occluded (mean %.2f)" % ao.mean()]


def case_others():
    """Another part 5 cm over it (a hat over a coif): each part is baked on
    its own, since it may be worn without the other."""
    fresh()
    part = plate("Part")
    plate("Over", z=0.05)
    ao = occlusion(part)
    return [] if ao.size and ao.mean() > 0.95 else ["ao: another part darkened this one (mean %.2f)" % ao.mean()]


def kept(write, name):
    """A file written over by `write`: its old bytes kept in the backup
    folder (a repainted texture, a hand-edited JSON)."""
    folder = pathlib.Path(tempfile.mkdtemp(prefix="wardrobe_kept_"))
    common.BACKUP = folder / "backup"
    path = folder / name
    path.write_bytes(b"painted by hand")
    write(path)
    copies = list(common.BACKUP.glob("*")) if common.BACKUP.exists() else []
    return [] if any(c.read_bytes() == b"painted by hand" for c in copies) else ["kept: %s written over, no copy kept" % name]


def case_png():
    """The bake writes over a texture: the one there (maybe repainted by
    hand) is kept first."""
    fresh()
    return kept(lambda path: bake.save_png(np.zeros((4, 4, 3)), str(path)), "face.png")


def case_json():
    """The export writes over a part's JSON: the one there is kept first."""
    fresh()
    return kept(lambda path: export.write_json(path, {"piece": "test"}), "piece.json")


CASES = {"alone": case_alone, "others": case_others, "png": case_png, "json": case_json}


def main():
    failed = 0

    for name, run in CASES.items():
        try:
            messages = run()
        except Exception as error:  # a crash is a failure of that case
            messages = ["crash: %r" % error]

        print("%s %s%s" % ("PASS" if not messages else "FAIL", name, "" if not messages else ": %s" % messages))
        failed += 1 if messages else 0

    print("bake: %d/%d" % (len(CASES) - failed, len(CASES)))
    sys.exit(1 if failed else 0)


main()
