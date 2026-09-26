"""Sends a source .blend's parts to the game (spec §6.6), if they pass.

    tools/wardrobe/wardrobe.sh export watchman|heads|headgear|all

Each part is checked first against every rule (validate.py), textures
included; if anything fails, nothing is written and every failure is
printed. Then: a GLB (mesh and skeleton, material slots only), its JSON, and
beside a new GLB an .import that turns Godot's automatic LODs off (PS2 meshes
keep their silhouette at a distance). Each .blend gets an `export.py` text
block too: after a hand edit, Text > Run Script sends it again.

A kind's export reads its heads' and headgear's JSON for the heaviest NPC it
can make, so `all` exports heads and headgear first.
"""

import json
import os
import sys

# No __pycache__ beside the tools (Blender would write one each run).
sys.dont_write_bytecode = True
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import bpy  # noqa: E402

import common  # noqa: E402
import recipes  # noqa: E402
import validate  # noqa: E402

HEAD_LIMIT = 450
GEAR_LIMIT = {"coif": 200}
GEAR_DEFAULT = 300
# Godot's import settings for a wardrobe GLB (Boots_Male.glb's, LODs and
# tangents off: no normal maps, and no automatic LODs eating silhouettes).
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


def main():
    target, _ = common.args()
    path = common.SOURCE / ("%s.blend" % target)

    if not path.exists() or bpy.data.filepath != str(path):
        common.fail("no source/%s.blend" % target)

    if target in recipes.KINDS:
        export_kind(recipes.KINDS[target])
    elif target == "heads":
        export_parts("Head_", "heads")
    elif target == "headgear":
        export_parts("Gear_", "headgear")
    else:
        common.fail("nothing to export called '%s'" % target)

    add_button(target)


def reference_joints(body):
    before = set(bpy.data.objects)
    armature, _, _ = common.import_quaternius(body)
    joints = common.joints(armature)

    for obj in [o for o in bpy.data.objects if o not in before]:
        bpy.data.objects.remove(obj)

    return joints


def refuse(messages):
    for message in messages:
        print("wardrobe: " + message)

    common.fail("export refused: %d rule(s) broken, nothing written" % len(messages))


def export_kind(recipe):
    kind = recipe["kind"]
    outfit = bpy.data.objects.get("Outfit")
    armature = bpy.data.objects.get("Armature")

    if outfit is None or armature is None:
        common.fail("no Outfit on an Armature in this file")

    scene = bpy.context.scene
    # The chains' bones come from the build; their settings from the recipe
    # as it is now (tuning cloth needs only an export).
    chains = [{**c, **recipe["chains"][c["chain"]]} for c in json.loads(scene.get("wardrobe_chains", "[]"))]
    albedo = str(common.WARDROBE / ("%s.png" % kind))
    mask = str(common.WARDROBE / ("%s_mask.png" % kind))
    combined = common.tri_count(outfit) + heaviest_parts(recipe)
    messages = validate.check(outfit, armature=armature, reference_joints=reference_joints(recipe["body"]),
                              cloth_bones=[b for c in chains for b in c["bones"]],
                              images=[(albedo, (256, 256), True), (mask, (256, 256), False)],
                              combined_tris=combined, budget=common.budget_of(kind), bare=set(recipe["bare"]))

    if messages:
        refuse(messages)

    glb(outfit, armature, common.WARDROBE / ("%s.glb" % kind))
    bones = {b.name: b for b in armature.data.bones}
    data = {
        "kind": kind,
        "body": recipe["body"],
        "triangles": common.tri_count(outfit),
        "cloth": chains,
        "colliders": [{"bone": c["bone"], "radius": c["radius"], "height": round(bones[c["bone"]].length, 4)}
                      for c in recipe["colliders"]],
        "metal": recipe["metal"],
        "skin_tones": recipes.TONES,
        "probe": json.loads(scene.get("wardrobe_probe", "[]")),
        "options": recipe["options"],
    }
    write_json(common.WARDROBE / ("%s.json" % kind), data)
    print("wardrobe: exported %s: %d triangles, %d with head and headgear" % (kind, data["triangles"], combined))


def heaviest_parts(recipe):
    options = recipe["options"]
    heads = [read("heads/%s.json" % face) for face in options["faces"]]
    sets = [[read("headgear/%s.json" % piece) for piece in pieces] for pieces in options["headgear"]]

    if any(h is None for h in heads) or any(p is None for s in sets for p in s):
        common.fail("export heads and headgear first: %s needs their triangle counts" % recipe["kind"])

    return max(h["triangles"] for h in heads) + max((sum(p["triangles"] for p in s) for s in sets), default=0)


def read(relative):
    path = common.WARDROBE / relative
    return json.loads(path.read_text()) if path.exists() else None


def export_parts(prefix, folder):
    """Every head (or headgear piece) in this file, each its own GLB."""
    armature = bpy.data.objects.get("Armature")
    parts = [o for o in bpy.data.objects if o.name.startswith(prefix) and o.type == "MESH"]
    joints = reference_joints("male")
    messages = []

    for obj in parts:
        name = obj.name[len(prefix):]

        if folder == "heads":
            images = [(str(common.WARDROBE / folder / ("%s_%s.png" % (name, tone))), (128, 128), True)
                      for tone in recipes.HEADS[name]["tones"]]
            cap = HEAD_LIMIT
        else:
            images = [(str(common.WARDROBE / folder / ("%s.png" % name)), (128, 128), True)]
            cap = GEAR_LIMIT.get(name, GEAR_DEFAULT)

        found = validate.check(obj, armature=armature, reference_joints=joints, images=images,
                               combined_tris=common.tri_count(obj), budget=cap)
        messages += ["%s %s" % (obj.name, m) for m in found]

    if messages:
        refuse(messages)

    for obj in parts:
        name = obj.name[len(prefix):]
        glb(obj, armature, common.WARDROBE / folder / ("%s.glb" % name))

        if folder == "heads":
            data = {"face": name, "body": recipes.HEADS[name]["body"], "triangles": common.tri_count(obj)}
        else:
            g = recipes.HEADGEAR[name]
            data = {"piece": name, "triangles": common.tri_count(obj), "rigid": False, "bone": "", "offset": [],
                    "metal": g["metal"], "hides_hair": g["hides_hair"], "allows_beard": g["allows_beard"],
                    "cloth": [], "colliders": []}

        write_json(common.WARDROBE / folder / ("%s.json" % name), data)
        print("wardrobe: exported %s/%s: %d triangles" % (folder, name, data["triangles"]))


def glb(obj, armature, path):
    """`obj` on its skeleton as a GLB: mesh, skin and named material slots
    (the game makes its own materials, choosing by name: WR_strips is drawn
    from both sides), no textures, no animation. Placeholder materials would
    lose the names on Godot's import."""
    path.parent.mkdir(parents=True, exist_ok=True)
    common.select_only([obj, armature], active=obj)
    bpy.ops.export_scene.gltf(filepath=str(path), export_format="GLB", use_selection=True, export_materials="EXPORT",
                              export_image_format="NONE", export_animations=False, export_skins=True, export_yup=True,
                              export_texcoords=True, export_normals=True, export_vertex_color="NONE", export_apply=False)
    settings = path.with_suffix(".glb.import")

    if not settings.exists():
        relative = "res://" + str(path.relative_to(common.ROOT)).replace(os.sep, "/")
        settings.write_text(IMPORT.format(source=relative))


def write_json(path, data):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(data, indent=1) + "\n")


def add_button(target):
    """The Export button: a text block that sends this file again after a
    hand edit (Text > Run Script). Saved into the file."""
    code = ("# Sends this file's parts to the game again after a hand edit:\n"
            "# Text > Run Script (or tools/wardrobe/wardrobe.sh export %s).\n"
            "import runpy, sys\n"
            "sys.argv = [sys.argv[0], '--', %r]\n"
            "runpy.run_path(%r, run_name='__main__')\n" % (target, target, str(common.ROOT / "tools" / "wardrobe" / "export.py")))
    text = bpy.data.texts.get("export.py") or bpy.data.texts.new("export.py")

    if text.as_string() != code:
        text.clear()
        text.write(code)
        common.save(common.SOURCE / ("%s.blend" % target))


main()
