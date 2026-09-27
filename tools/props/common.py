"""Shared by the props tools (they run inside Blender)."""

import hashlib
import json
import math
import shutil
import sys
import time
from pathlib import Path

import bpy

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "assets" / "props" / "source"
OUT = ROOT / "assets" / "props" / "lights"
BACKUP = SOURCE / "backup"

# Texel density: every surface gets this many texels a metre of a TEXTURE_PX
# photo (the 128 px ps2ify textures), within DENSITY_BAND either way.
PX_PER_M = 64.0
TEXTURE_PX = 128.0
DENSITY_BAND = 0.5


def fail(message):
    print("props: " + message)
    sys.exit(1)


def scene_fresh():
    """An empty scene, nothing left of the last fixture."""
    bpy.ops.wm.read_factory_settings(use_empty=True)
    return bpy.context.scene


def tri_count(obj):
    return sum(len(polygon.vertices) - 2 for polygon in obj.data.polygons)


def is_collider(obj):
    return obj.name.endswith("-colonly")


def to_godot(v):
    """Blender (Z up) to glTF / Godot (Y up)."""
    return (v[0], v[2], -v[1])


def recipe_hash(recipe):
    return hashlib.md5(json.dumps(recipe, sort_keys=True, default=str).encode()).hexdigest()


def backup(path):
    """A copy of `path` in the backup folder before it is written over."""
    path = Path(path)

    if path.exists():
        BACKUP.mkdir(parents=True, exist_ok=True)
        shutil.copy2(path, BACKUP / ("%s.%d%s" % (path.stem, int(time.time()), path.suffix)))


def uv_scale():
    return PX_PER_M / TEXTURE_PX


def face_density(face_3d_area, face_uv_area):
    """Texels a metre across a face (of a TEXTURE_PX photo)."""
    if face_3d_area <= 1e-12:
        return PX_PER_M

    return math.sqrt(max(face_uv_area, 0.0) / face_3d_area) * TEXTURE_PX
