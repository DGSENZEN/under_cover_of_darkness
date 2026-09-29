"""A level's data read back from its open .blend (the user may have edited
it): its pieces, its markers, its terrain, its sectors and the kit's
triangle counts, in Godot's axes (see rules.py)."""

import bpy

import common
import geo
import markers as schema

SKIP = {"ucd"}


def sector_of(obj):
    for collection in obj.users_collection:
        return collection.name[:-len(" markers")] if collection.name.endswith(" markers") else collection.name

    return ""


def value(key, raw, ucd):
    """A custom property as the schema wants it (Blender keeps bools as ints)."""
    default = schema.SCHEMA.get(ucd, {}).get("optional", {}).get(key)

    if isinstance(default, bool):
        return bool(raw)

    if isinstance(default, float) and isinstance(raw, int):
        return float(raw)

    if hasattr(raw, "to_list"):
        return raw.to_list()

    return raw


def terrain_of(obj):
    """A terrain object as the rules read it: its triangles in the world, in
    Godot's axes (as sculpted, if it was)."""
    mesh = obj.data
    mesh.calc_loop_triangles()
    to_world = obj.matrix_world
    corners = [geo.from_blender(list(to_world @ v.co)) for v in mesh.vertices]
    return {"name": obj.name, "sector": sector_of(obj), "surface": obj.get("surface", "stone"), "occluder": bool(obj.get("occluder", 0)),
            "tris": [[corners[i] for i in tri.vertices] for tri in mesh.loop_triangles]}


def read():
    pieces, found, tris, ground = [], [], {}, []

    for obj in bpy.context.scene.objects:
        if obj.type == "MESH" and obj.get("terrain"):
            ground.append(terrain_of(obj))
        elif "kit_piece" in obj.keys():
            position, basis, scale = common.unpack(obj)
            piece = obj["kit_piece"]
            pieces.append({"name": obj.name, "piece": piece, "sector": sector_of(obj), "position": position, "basis": basis,
                           "scale": scale})

            if obj.type == "MESH" and piece not in tris:
                tris[piece] = sum(len(p.vertices) - 2 for p in obj.data.polygons)
        elif "ucd" in obj.keys():
            ucd = obj["ucd"]
            position, basis, scale = common.unpack(obj)
            box = obj.empty_display_type == "CUBE"
            size = [scale[0] * 2.0 * obj.empty_display_size, scale[2] * 2.0 * obj.empty_display_size, scale[1] * 2.0 * obj.empty_display_size] if box else None
            props = {k: value(k, obj[k], ucd) for k in obj.keys() if k not in SKIP and not k.startswith("_")}
            found.append({"name": obj.name, "ucd": ucd, "sector": sector_of(obj), "position": position, "basis": basis,
                          "size": size, "props": props})

    return {"level": bpy.context.scene.get("level", ""), "pieces": pieces, "markers": found, "tris": tris, "terrain": ground,
            "sectors": sorted({p["sector"] for p in pieces} | {m["sector"] for m in found} | {t["sector"] for t in ground})}
