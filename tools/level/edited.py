"""Whether the open level .blend has been edited since it was built (its
pieces and markers no longer read back as build saved them): exits non-zero
if so, and `level.sh build` then will not overwrite it.

    Blender -b assets/level/source/<level>.blend --python tools/level/edited.py
"""

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import bpy  # noqa: E402

import common  # noqa: E402
import read  # noqa: E402

stored = bpy.context.scene.get("content_hash")

if stored is None:
    # (Built before builds kept one: nothing to tell an edit by.)
    print("level: no build hash in this .blend; taking it as unedited")
elif common.content_hash(read.read()) != stored:
    common.fail("%s.blend has been edited since it was built; not overwriting it (level.sh build %s --force builds over it)"
                % (bpy.context.scene.get("level", "the level"), bpy.context.scene.get("level", "<level>")))
else:
    print("level: unedited since it was built")
