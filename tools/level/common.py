"""Shared by the level tools that run inside Blender (kit, build, read,
check, export)."""

import hashlib
import json
import os
import sys
from pathlib import Path

import bpy
from mathutils import Matrix

import geo

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "assets" / "level" / "source"
KIT = SOURCE / "kit.blend"
KIT_PREFIX = "kit_"

# A preview colour per slot (the .blend only; the game's are Materials').
SLOT_COLOURS = {
    "ashlar": (0.42, 0.40, 0.37), "stone": (0.37, 0.35, 0.33), "plaster": (0.62, 0.58, 0.50), "timber": (0.30, 0.21, 0.14),
    "cobble": (0.33, 0.32, 0.30), "flagstone": (0.40, 0.38, 0.35), "boards": (0.36, 0.26, 0.17), "grass": (0.20, 0.26, 0.14),
    "mud": (0.24, 0.19, 0.13), "gravel": (0.38, 0.36, 0.33), "carpet": (0.45, 0.10, 0.08), "slate": (0.18, 0.19, 0.22),
    "iron": (0.16, 0.16, 0.16), "straw": (0.55, 0.45, 0.22), "cloth": (0.50, 0.08, 0.08), "leaves": (0.12, 0.18, 0.09),
    "bark": (0.24, 0.18, 0.13), "glass_lit": (1.0, 0.72, 0.38),
}


def fail(message):
    print("level: " + message)
    sys.exit(1)


def argv():
    return sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []


def scene_fresh():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    return bpy.context.scene


def matrix(position, basis, scale=(1.0, 1.0, 1.0)):
    """A Blender world matrix from a Godot position and basis (and a Blender
    scale)."""
    b = geo.to_blender_basis(basis)
    t = geo.to_blender(position)
    m = Matrix(((b[0][0], b[0][1], b[0][2], t[0]), (b[1][0], b[1][1], b[1][2], t[1]), (b[2][0], b[2][1], b[2][2], t[2]), (0, 0, 0, 1)))
    return m @ Matrix.Diagonal((scale[0], scale[1], scale[2], 1.0))


def unpack(obj):
    """An object's Godot position, basis (unscaled) and Blender scale."""
    loc, rot, scale = obj.matrix_world.decompose()
    r = rot.to_matrix()
    basis = geo.from_blender_basis([[r[i][j] for j in range(3)] for i in range(3)])
    return geo.from_blender(list(loc)), basis, list(scale)


def data_hash(data):
    return hashlib.md5(json.dumps(data, sort_keys=True, default=str).encode()).hexdigest()


def level_path(level):
    """A level's .blend: in assets/level/source, or LEVEL_SOURCE if set (the
    guard's test builds into a scratch folder)."""
    return Path(os.environ.get("LEVEL_SOURCE", str(SOURCE))) / (level + ".blend")


def _rounded(value):
    if isinstance(value, float):
        return round(value, 4) + 0.0

    if isinstance(value, list):
        return [_rounded(v) for v in value]

    if isinstance(value, dict):
        return {k: _rounded(v) for k, v in value.items()}

    return value


def content_hash(data):
    """A level's pieces and markers as read back from its .blend (read.read),
    its numbers rounded: saved as it is built, so an edit since then can be
    told (build will not overwrite it without --force)."""
    return data_hash(_rounded({"pieces": data["pieces"], "markers": data["markers"]}))


def out_dir(level):
    return ROOT / "assets" / "level" / level
