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
    "band_ochre": (0.54, 0.29, 0.2),
    "lioz": (0.81, 0.78, 0.69),
    "ashlar_weathered": (0.43, 0.42, 0.41), "rubble_warm": (0.42, 0.39, 0.31), "coping_moss": (0.34, 0.35, 0.24), "stair_stone": (0.54, 0.51, 0.45), "zellige_diamond": (0.54, 0.43, 0.45), "zellige_star": (0.43, 0.42, 0.36), "stucco_carved": (0.6, 0.48, 0.37), "stucco_lattice": (0.76, 0.74, 0.68), "azulejo_mural": (0.55, 0.6, 0.72), "render_pink": (0.71, 0.44, 0.42), "render_green": (0.56, 0.69, 0.6), "render_white": (0.84, 0.82, 0.77), "azulejo_souls": (0.55, 0.48, 0.56),
    "ashlar": (0.42, 0.40, 0.37), "stone": (0.37, 0.35, 0.33), "plaster": (0.62, 0.58, 0.50), "timber": (0.30, 0.21, 0.14),
    "cobble": (0.33, 0.32, 0.30), "flagstone": (0.40, 0.38, 0.35), "boards": (0.36, 0.26, 0.17), "grass": (0.20, 0.26, 0.14),
    "mud": (0.24, 0.19, 0.13), "gravel": (0.38, 0.36, 0.33), "hedge": (0.23, 0.29, 0.18), "tannery_liquor": (0.23, 0.17, 0.09), "pebbles": (0.42, 0.40, 0.36), "carpet": (0.45, 0.10, 0.08), "slate": (0.18, 0.19, 0.22),
    "iron": (0.16, 0.16, 0.16), "straw": (0.55, 0.45, 0.22), "cloth": (0.50, 0.08, 0.08), "leaves": (0.12, 0.18, 0.09),
    "bark": (0.24, 0.18, 0.13), "leaf_crown": (0.18, 0.27, 0.13), "leaf_shrub": (0.19, 0.29, 0.13), "yew": (0.11, 0.18, 0.11),
    "twigs": (0.23, 0.2, 0.16), "grass_blades": (0.29, 0.37, 0.17), "weed_broad": (0.24, 0.35, 0.15), "reeds": (0.37, 0.4, 0.2),
    "ivy": (0.13, 0.22, 0.12), "glass_lit": (1.0, 0.72, 0.38), "proxy": (1.0, 1.0, 1.0), "proxy_lit": (1.0, 0.72, 0.38), "wax": (0.85, 0.79, 0.64), "pitch": (0.09, 0.07, 0.05),
    "plaster_damaged": (0.58, 0.54, 0.47), "roof_clay": (0.42, 0.23, 0.16), "stone_moss": (0.31, 0.32, 0.27),
    "wood_studded": (0.23, 0.17, 0.12), "shutters": (0.42, 0.40, 0.35), "stained_glass": (0.48, 0.23, 0.17),
    "stained_glass_small": (0.37, 0.42, 0.29), "relief_frieze": (0.55, 0.51, 0.44), "relief_angels": (0.55, 0.51, 0.44),
    "arcade": (0.49, 0.46, 0.42), "ornament": (0.49, 0.46, 0.42),
    "roof_slate": (0.18, 0.19, 0.22), "roof_fish": (0.20, 0.21, 0.24), "roof_tiles": (0.40, 0.22, 0.16), "roof_shingle": (0.26, 0.19, 0.14),
    "door_1": (0.30, 0.21, 0.14), "door_2": (0.30, 0.27, 0.22), "band": (0.52, 0.49, 0.45), "limewash": (0.56, 0.52, 0.45),
    "plaster_ochre": (0.55, 0.43, 0.27), "tiles_chancel": (0.48, 0.30, 0.19), "banner": (0.45, 0.08, 0.08), "rose_window": (0.23, 0.23, 0.55),
    "altar_frontal": (0.42, 0.06, 0.10), "shield_1": (0.48, 0.17, 0.10), "shield_2": (0.17, 0.23, 0.42), "shield_3": (0.17, 0.15, 0.13),
    "glass_dark": (0.10, 0.12, 0.16), "pottery": (0.43, 0.26, 0.16), "pewter": (0.48, 0.48, 0.46), "bread": (0.61, 0.42, 0.20),
    "cheese": (0.79, 0.64, 0.29), "meat": (0.43, 0.17, 0.12), "herbs": (0.30, 0.35, 0.17), "burlap": (0.54, 0.46, 0.31),
    "leather": (0.29, 0.18, 0.11), "rope": (0.49, 0.42, 0.28), "clay": (0.54, 0.32, 0.21), "brass": (0.55, 0.42, 0.21),
    "roof_clay_uv": (0.42, 0.23, 0.16), "beam": (0.17, 0.12, 0.08),
    # The city's harbour.
    "granite": (0.37, 0.37, 0.35), "granite_rough": (0.42, 0.40, 0.37), "ashlar_gold": (0.54, 0.46, 0.35),
    "render_ochre": (0.69, 0.51, 0.24), "render_salmon": (0.66, 0.40, 0.29), "render_blue": (0.55, 0.62, 0.66),
    "render_straw": (0.76, 0.67, 0.49), "whitewash": (0.71, 0.68, 0.64),
    "facade_white": (0.72, 0.70, 0.65), "facade_ochre": (0.70, 0.52, 0.25), "facade_salmon": (0.67, 0.40, 0.30), "facade_blue": (0.56, 0.63, 0.67), "azulejo_green": (0.18, 0.42, 0.23),
    "azulejo_cube": (0.49, 0.53, 0.44), "azulejo_blue": (0.37, 0.44, 0.56), "azulejo_blue2": (0.35, 0.43, 0.56),
    "azulejo_border": (0.24, 0.37, 0.55), "waterline_tide": (0.33, 0.34, 0.30), "waterline_algae": (0.29, 0.31, 0.25),
    "calcada": (0.61, 0.59, 0.54), "terracotta": (0.56, 0.29, 0.19), "terracotta_hex": (0.43, 0.22, 0.16),
    "roof_spanish": (0.54, 0.30, 0.20), "brick": (0.48, 0.29, 0.22), "brick_coursed": (0.48, 0.29, 0.22), "azulejo_ship": (0.55, 0.6, 0.72), "arms_royal": (0.63, 0.54, 0.44), "azulejo_comet": (0.55, 0.6, 0.72), "azulejo_king": (0.49, 0.55, 0.71), "tile_frame": (0.24, 0.37, 0.55), "sea_chart": (0.78, 0.7, 0.55), "parchment": (0.82, 0.76, 0.61), "book_spines": (0.35, 0.24, 0.14), "rock": (0.49, 0.48, 0.45), "cliff": (0.54, 0.52, 0.47),
    "hull_tarred": (0.17, 0.16, 0.16), "hull_bare": (0.37, 0.29, 0.21), "sailcloth": (0.72, 0.69, 0.63), "rope_lay": (0.49, 0.42, 0.28),
    "rope_coil": (0.56, 0.49, 0.36), "net": (0.43, 0.35, 0.24), "manueline": (0.56, 0.53, 0.47), "iron_rail": (0.20, 0.20, 0.18),
    "window_grille": (0.20, 0.20, 0.18), "casement": (0.83, 0.81, 0.75), "glazing": (0.33, 0.40, 0.36), "quarries": (0.16, 0.16, 0.17), "rock_shore": (0.42, 0.41, 0.39), "cliff_shore": (0.47, 0.45, 0.41), "gorse": (0.17, 0.26, 0.14), "fennel": (0.42, 0.49, 0.35), "pine": (0.13, 0.22, 0.16), "laundry": (0.75, 0.71, 0.64), "feather": (0.79, 0.79, 0.76), "feather_dark": (0.30, 0.31, 0.32), "beak": (0.70, 0.57, 0.20), "cork": (0.56, 0.42, 0.27), "sash": (0.83, 0.81, 0.75), "lattice": (0.19, 0.28, 0.21), "ratlines": (0.15, 0.13, 0.10), "palm_frond": (0.31, 0.38, 0.20), "cypress": (0.12, 0.18, 0.12),
    "agave": (0.36, 0.47, 0.43), "orange_leaves": (0.13, 0.25, 0.16), "wood_old": (0.29, 0.21, 0.14),
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


# What of a terrain the edit guard hashes: its shape (before October 2026,
# only that), then its paint (each triangle's slot, the tint) and properties.
SHAPE = ("name", "sector", "tris")
PAINT = SHAPE + ("slots", "tint", "surface", "occluder")


def content_hash(data, terrain=PAINT):
    """A level's pieces, markers and terrain as read back from its .blend
    (read.read), its numbers rounded: saved as it is built, so an edit since
    then can be told (build will not overwrite it without --force): a piece
    or marker moved, the ground sculpted, repainted or retinted, its surface
    changed. `terrain` names what of the ground counts (SHAPE: as the guard
    hashed it before it saw paint). (A level without terrain hashes as it
    did before terrain was read.)"""
    content = {"pieces": data["pieces"], "markers": data["markers"]}

    if data.get("terrain"):
        content["terrain"] = [{k: t[k] for k in terrain if k in t} for t in data["terrain"]]

    return data_hash(_rounded(content))


def material(slot):
    """The level's material for `slot`, made once: its preview colour (the
    game's look is Materials.gd's; the glTF carries only the slot's name)."""
    existing = bpy.data.materials.get(slot)

    if existing is not None:
        return existing

    mat = bpy.data.materials.new(slot)
    mat.use_nodes = True
    colour = SLOT_COLOURS.get(slot, (1.0, 0.0, 1.0))
    principled = mat.node_tree.nodes.get("Principled BSDF")

    if principled is not None:
        principled.inputs["Base Color"].default_value = (*colour, 1.0)
        principled.inputs["Roughness"].default_value = 0.9

    mat.diffuse_color = (*colour, 1.0)
    return mat


def out_dir(level):
    return ROOT / "assets" / "level" / level
