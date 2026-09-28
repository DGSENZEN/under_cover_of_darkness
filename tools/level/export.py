"""Exports the open level .blend for Godot, if it passes the check: a glTF
of each sector's pieces (assets/level/<level>/<sector>.glb) and the level's
manifest (<level>.json: its sectors, every collider as an oriented box with
its surface, every marker with its properties and defaults), plus the
marker schema (markers.json). scripts/Level/LevelLoader.gd reads them.

    Blender -b assets/level/source/<level>.blend --python tools/level/export.py [-- stage2]
"""

import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import bpy  # noqa: E402

import check as checker  # noqa: E402
import common  # noqa: E402
import geo  # noqa: E402
import kit_recipes  # noqa: E402
import markers as schema  # noqa: E402

IMPORT = """[remap]

importer="scene"
importer_version=1
type="PackedScene"

[deps]

source_file="{source}"

[params]

nodes/root_type=""
nodes/root_name=""
nodes/apply_root_scale=true
nodes/root_scale=1.0
nodes/import_as_skeleton_bones=false
nodes/use_name_suffixes=false
nodes/use_node_type_suffixes=false
meshes/ensure_tangents=false
meshes/generate_lods=false
meshes/create_shadow_meshes=true
meshes/light_baking=1
meshes/lightmap_texel_size=0.2
meshes/force_disable_compression=false
skins/use_named_skins=true
animation/import=false
import_script/path=""
materials/extract=0
_subresources={{}}
gltf/naming_version=2
gltf/embedded_image_handling=1
"""


def rounded(v, digits=4):
    return [round(float(x), digits) for x in v]


def manifest(data):
    colliders = []

    for p in data["pieces"]:
        recipe = kit_recipes.PIECES[p["piece"]]

        for box in geo.piece_boxes(recipe, p["position"], p["basis"]):
            colliders.append({"sector": p["sector"], "centre": rounded(box.centre), "basis": [rounded(r) for r in box.basis],
                              "size": rounded([h * 2.0 for h in box.half]), "surface": box.surface})

    sockets = []

    for p in data["pieces"]:
        for kind, points in kit_recipes.PIECES[p["piece"]].get("sockets", {}).items():
            for point in points:
                sockets.append({"piece": p["name"], "kind": kind, "sector": p["sector"],
                                "position": rounded(geo.add(p["position"], geo.apply(p["basis"], point)))})

    found = []

    for m in data["markers"]:
        m = schema.with_defaults(m)
        found.append({"name": m["name"], "ucd": m["ucd"], "sector": m["sector"], "position": rounded(m["position"]),
                      "basis": [rounded(r) for r in m["basis"]], "size": rounded(m["size"]) if m.get("size") else None,
                      "props": m["props"]})

    return {"level": data["level"], "sectors": data["sectors"], "colliders": colliders, "markers": found, "sockets": sockets,
            "pieces": len(data["pieces"])}


def export(stage="stage1"):
    data, problems = checker.check(stage)

    if problems:
        common.fail("not exported: %d problems" % len(problems))

    level = data["level"]
    out = common.out_dir(level)
    out.mkdir(parents=True, exist_ok=True)

    for sector in data["sectors"]:
        names = {p["name"] for p in data["pieces"] if p["sector"] == sector}

        if not names:
            continue

        bpy.ops.object.select_all(action="DESELECT")

        for obj in bpy.context.scene.objects:
            if obj.name in names:
                obj.select_set(True)

        path = out / (sector + ".glb")
        bpy.ops.export_scene.gltf(
            filepath=str(path), export_format="GLB", use_selection=True, export_materials="EXPORT",
            export_image_format="NONE", export_vertex_color="ACTIVE", export_yup=True, export_apply=True,
            export_texcoords=True, export_normals=True, export_animations=False, export_skins=False, export_extras=False,
        )
        settings = path.with_suffix(".glb.import")

        if not settings.exists():
            settings.write_text(IMPORT.format(source="res://" + str(path.relative_to(common.ROOT)).replace(os.sep, "/")))

    (out / (level + ".json")).write_text(json.dumps(manifest(data), indent=None, separators=(",", ":")) + "\n")
    schema.write_json(out / "markers.json")
    print("level: exported %s: %d sectors -> %s" % (level, len(data["sectors"]), out.relative_to(common.ROOT)))


if __name__ == "__main__":
    args = common.argv()
    export(args[0] if args else "stage1")
