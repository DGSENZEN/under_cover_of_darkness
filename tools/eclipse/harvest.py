"""The user's vertex-paint strokes read from a piece's existing .blend
before it is rebuilt (weather.harvest). Run by lab.sh with Blender opened on
assets/eclipse/source/<piece>.blend:

    Blender -b assets/eclipse/source/kiosk.blend --python tools/eclipse/harvest.py -- kiosk
"""

import sys
from pathlib import Path

import bpy

sys.path.insert(0, str(Path(__file__).resolve().parent))

import weather  # noqa: E402

name = sys.argv[sys.argv.index("--") + 1]
objects = [o for o in bpy.context.scene.objects if o.type == "MESH"]
print("harvest: %s %d touched values" % (name, weather.harvest(objects, name)))
