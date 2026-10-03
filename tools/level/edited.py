"""Whether the open level .blend has been edited since it was built (its
pieces, markers and ground no longer read back as build saved them, the
ground's paint included): exits non-zero if so, and `level.sh build` then
will not overwrite it.

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
else:
    data = read.read()
    level = bpy.context.scene.get("level", "<level>")

    if common.content_hash(data) == stored:
        print("level: unedited since it was built")
    elif common.content_hash(data, common.SHAPE) == stored:
        # (Built when the guard hashed the ground's shape only: its paint
        # cannot be told from the build's, so it is taken as the user's.)
        common.fail("%s.blend was built before the guard looked at the ground's paint, so a repainted ground cannot be told; "
                    "not overwriting it (level.sh build %s --force builds over it)" % (level, level))
    else:
        common.fail("%s.blend has been edited since it was built; not overwriting it (level.sh build %s --force builds over it)"
                    % (level, level))
