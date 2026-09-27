"""A built, baked fixture out to the game:

    Blender -b assets/props/source/<name>.blend --python export.py -- <name>

  assets/props/lights/<name>.glb    its meshes (surfaces named by slot, no
                                    images: the game looks the photos up by
                                    slot), its baked vertex colours, its
                                    colliders ("-colonly": static bodies)
  assets/props/lights/<name>.json   what the game needs besides: sockets (in
                                    Godot's space), slots, glowing parts, the
                                    burner, soot and cookie, triangles, hash
"""

import json
import os
import sys

import bpy

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import common  # noqa: E402
import recipes  # noqa: E402

# Godot's import settings for a fixture (as the wardrobe's GLBs).
IMPORT = """[remap]

importer="scene"
importer_version=1
type="PackedScene"

[deps]

source_file="{source}"

[params]

nodes/root_type=""
nodes/root_name=""
nodes/root_script=null
nodes/apply_root_scale=true
nodes/root_scale=1.0
nodes/import_as_skeleton_bones=false
nodes/use_name_suffixes=true
nodes/use_node_type_suffixes=true
meshes/ensure_tangents=false
meshes/generate_lods=false
meshes/create_shadow_meshes=true
meshes/light_baking=1
meshes/lightmap_texel_size=0.2
meshes/force_disable_compression=false
skins/use_named_skins=true
animation/import=false
animation/fps=30
animation/trimming=false
animation/remove_immutable_tracks=true
animation/import_rest_as_RESET=false
import_script/path=""
materials/extract=0
materials/extract_format=0
materials/extract_path=""
_subresources={{}}
gltf/naming_version=2
gltf/embedded_image_handling=1
"""


def spec(name, recipe):
    meshes = [o for o in bpy.context.scene.objects if o.type == "MESH" and not common.is_collider(o)]
    sockets = {}

    for obj in bpy.context.scene.objects:
        if obj.type == "EMPTY" and obj.name.startswith("socket:"):
            _, socket, index = obj.name.split(":")
            sockets.setdefault(socket, []).append((int(index), [round(v, 5) for v in common.to_godot(obj.location)]))

    slots = sorted({m.name for o in meshes for m in o.data.materials if m is not None})
    return {
        "fixture": name,
        "family": recipe["family"],
        "mount": recipe.get("mount", ""),
        "tris": sum(common.tri_count(o) for o in meshes),
        "slots": slots,
        "glow_parts": [p["name"] for p in recipe["parts"] if p.get("glow")],
        "shadow_parts": list(recipe.get("shadow_parts", [])),
        "sockets": {k: [point for _, point in sorted(v)] for k, v in sockets.items()},
        "burner": recipe.get("burner", {}),
        "soot": recipe.get("soot", False),
        "cookie": recipe.get("cookie", False),
        "hash": common.recipe_hash(recipe),
    }


def export_fixture(name, recipe, out=common.OUT):
    out.mkdir(parents=True, exist_ok=True)
    path = out / (name + ".glb")
    common.backup(path)
    bpy.ops.object.select_all(action="DESELECT")

    for obj in bpy.context.scene.objects:
        if obj.type == "MESH":
            obj.select_set(True)

    bpy.ops.export_scene.gltf(
        filepath=str(path), export_format="GLB", use_selection=True, export_materials="EXPORT",
        export_image_format="NONE", export_vertex_color="ACTIVE", export_yup=True, export_apply=False,
        export_texcoords=True, export_normals=True, export_animations=False, export_skins=False,
    )

    settings = path.with_suffix(".glb.import")

    if not settings.exists():
        settings.write_text(IMPORT.format(source="res://" + str(path.relative_to(common.ROOT)).replace(os.sep, "/")))

    (out / (name + ".json")).write_text(json.dumps(spec(name, recipe), indent=1) + "\n")
    return path


def main(argv):
    name = argv[0] if argv else bpy.context.scene.get("fixture", "")

    if name not in recipes.FIXTURES:
        common.fail("no fixture called '%s'" % name)

    if bpy.context.scene.get("recipe_hash") != common.recipe_hash(recipes.FIXTURES[name]):
        common.fail("%s.blend is older than its recipe: build and bake it again first" % name)

    path = export_fixture(name, recipes.FIXTURES[name])
    print("props: exported %s" % path.relative_to(common.ROOT))


if __name__ == "__main__":
    main(sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else [])
