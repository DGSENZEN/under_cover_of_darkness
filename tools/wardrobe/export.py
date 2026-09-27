"""Sends a source .blend's parts to the game (spec §6.6), if they pass.

    tools/wardrobe/wardrobe.sh export watchman|heads|headgear|all

Each part is checked first against every rule (validate.py), textures
included; if anything fails, nothing is written and every failure is
printed. Whatever it writes over is kept first (source/backup). Then: a GLB (mesh and skeleton, material slots only), its JSON, and
beside a new GLB an .import that turns Godot's automatic LODs off (PS2 meshes
keep their silhouette at a distance). Each .blend gets an `export.py` text
block too: after a hand edit, Text > Run Script sends it again.

A kind's export reads its heads' and headgear's JSON for the heaviest NPC it
can make, so `all` exports heads and headgear first.
"""

import json
import os
import pathlib
import re
import sys

# No __pycache__ beside the tools (Blender would write one each run).
sys.dont_write_bytecode = True
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import bpy  # noqa: E402

import common  # noqa: E402
import recipes  # noqa: E402
import validate  # noqa: E402

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


# A texture's import settings: lossless, mipmapped (the shader samples
# nearest-mipmap), and never switched to VRAM compression when the editor
# sees it on a 3D mesh: that would smear the palette.
PNG_IMPORT = """[remap]

importer="texture"
type="CompressedTexture2D"

[deps]

source_file="{source}"

[params]

compress/mode=0
mipmaps/generate=true
detect_3d/compress_to=0
"""


def lossless(path):
    """`path`'s import settings held lossless (PNG_IMPORT's rules), written
    beside it or put right in the ones Godot made."""
    settings = path.parent / (path.name + ".import")

    if settings.exists():
        text = re.sub(r"compress/mode=\d+", "compress/mode=0", settings.read_text())
        text = re.sub(r"detect_3d/compress_to=\d+", "detect_3d/compress_to=0", text)
        settings.write_text(text)
    else:
        relative = "res://" + str(path.relative_to(common.ROOT)).replace(os.sep, "/")
        settings.write_text(PNG_IMPORT.format(source=relative))


def main():
    target, _ = common.args()

    if target in common.PART_TARGETS and not common.parts_of(common.part_table(common.PART_TARGETS[target][0]),
                                                              common.PART_TARGETS[target][1]):
        print("wardrobe: no %s %s in the recipes: nothing to export" % common.PART_TARGETS[target][::-1])
        return

    path = common.SOURCE / ("%s.blend" % target)

    if not path.exists() or bpy.data.filepath != str(path):
        common.fail("no source/%s.blend" % target)

    if target in recipes.KINDS:
        export_kind(recipes.KINDS[target])
    elif target in common.PART_TARGETS:
        folder, body = common.PART_TARGETS[target]
        export_parts("Head_" if folder == "heads" else "Hair_", folder, body)
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
    # (Built before the rule, the watchman's batch 0 outfit takes it here.)
    opened = common.open_necklines(outfit, armature)

    if opened:
        print("wardrobe: %s: %d faces round his neckline drawn from both sides" % (kind, opened))
        common.save(common.SOURCE / ("%s.blend" % kind))

    combined = common.tri_count(outfit) + heaviest_parts(recipe)
    messages = validate.check(outfit, armature=armature, reference_joints=reference_joints(recipe["body"]),
                              cloth_bones=[b for c in chains for b in c["bones"]],
                              images=[(albedo, (256, 256), True), (mask, (256, 256), False)],
                              combined_tris=combined, budget=common.budget_of(kind), bare=set(recipe["bare"]))

    if messages:
        refuse(messages)

    glb(outfit, armature, common.WARDROBE / ("%s.glb" % kind))

    for image in (albedo, mask):
        lossless(pathlib.Path(image))

    bones = {b.name: b for b in armature.data.bones}
    data = {
        "kind": kind,
        "body": recipe["body"],
        "triangles": common.tri_count(outfit),
        "budget": common.budget_of(kind),
        "cloth": chains,
        "colliders": [{"bone": c["bone"], "radius": c["radius"], "height": round(bones[c["bone"]].length, 4)}
                      for c in recipe["colliders"]],
        "metal": recipe["metal"],
        "skin_tones": recipes.TONES,
        "probe": json.loads(scene.get("wardrobe_probe", "[]")),
        "options": recipe["options"],
        "marks": kind_marks(recipe, outfit),
    }
    write_json(common.WARDROBE / ("%s.json" % kind), data)
    print("wardrobe: exported %s: %d triangles, %d with head and headgear" % (kind, data["triangles"], combined))


def kind_marks(recipe, outfit):
    """Where his garments are, for the game's checks to find them rather
    than hold recipe numbers: the front centre line (x = 0, his front) of
    each garment riding another's chains, top to bottom, in the game's frame
    (y up, his front +z)."""
    names = [g["name"] for g in recipe["garments"]]
    parts = outfit.data.attributes["wr_part"].data
    vertices = outfit.data.vertices
    marks = {}

    for g in recipe["garments"]:
        if "rides" not in g:
            continue

        part = 1 + names.index(g["name"])
        line = {tuple(round(c, 4) for c in vertices[i].co) for p in outfit.data.polygons if parts[p.index].value == part
                for i in p.vertices if abs(vertices[i].co.x) < 1e-4 and vertices[i].co.y < 0.0}
        marks["%s_front" % g["name"]] = [[x, z, -y] for x, y, z in sorted(line, key=lambda c: -c[2])]

    return marks


def heaviest_parts(recipe):
    """The heaviest head, hair, beard and headgear set the kind can roll
    (common.heaviest_combination, from their exported JSON)."""
    heaviest = common.heaviest_combination(recipe["options"], read)

    if heaviest is None:
        common.fail("export heads, hair and headgear first: %s needs their triangle counts" % recipe["kind"])

    return heaviest


def read(relative):
    path = common.WARDROBE / relative
    return json.loads(path.read_text()) if path.exists() else None


def dye_base(obj):
    """The colour a part's dyed faces were baked in (sRGB), or None."""
    dyed = obj.data.attributes.get("wr_dye")
    base = obj.data.color_attributes.get("wr_base")

    if dyed is None or base is None:
        return None

    for polygon in obj.data.polygons:
        if dyed.data[polygon.index].value:
            colour = base.data[polygon.loop_indices[0]].color_srgb
            return [round(colour[0], 4), round(colour[1], 4), round(colour[2], 4)]

    return None


def export_parts(prefix, folder, body="male"):
    """Every head (or hair piece, or headgear piece) in this file, made for
    `body`, each its own GLB on this file's skeleton (that body's)."""
    armature = bpy.data.objects.get("Armature")
    parts = [o for o in bpy.data.objects if o.name.startswith(prefix) and o.type == "MESH"]
    joints = reference_joints(body)
    chains = json.loads(bpy.context.scene.get("wardrobe_chains", "[]"))
    messages = []

    for obj in parts:
        name = obj.name[len(prefix):]
        cloth = [b for c in chains if c.get("piece") == name for b in c["bones"]]

        if folder == "heads":
            images = [(str(common.WARDROBE / folder / ("%s_%s.png" % (name, tone))), (128, 128), True)
                      for tone in recipes.HEADS[name]["tones"]]
        else:
            images = [(str(common.WARDROBE / folder / ("%s.png" % name)), (128, 128), True),
                      (str(common.WARDROBE / folder / ("%s_mask.png" % name)), (128, 128), False)]

        cap = common.part_limit(folder, name)

        found = validate.check(obj, armature=armature, reference_joints=joints, cloth_bones=cloth, images=images,
                               combined_tris=common.tri_count(obj), budget=cap)
        messages += ["%s %s" % (obj.name, m) for m in found]

    if messages:
        refuse(messages)

    for obj in parts:
        name = obj.name[len(prefix):]
        # Its own cloth bones only (one armature carries every piece's).
        glb(obj, armature, common.WARDROBE / folder / ("%s.glb" % name),
            cloth=[b for c in chains if c.get("piece") == name for b in c["bones"]])

        for image in (common.WARDROBE / folder).glob("%s*.png" % name):
            lossless(image)

        if folder == "heads":
            data = {"face": name, "body": recipes.HEADS[name]["body"], "triangles": common.tri_count(obj)}

            if "hair_colours" in recipes.HEADS[name]:
                data["hair_colours"] = recipes.HEADS[name]["hair_colours"]
        elif folder == "hair":
            h = recipes.HAIR[name]
            data = {"style": name, "kind": h["kind"], "body": h.get("body", "male"), "triangles": common.tri_count(obj),
                    "dye_base": dye_base(obj) or [0.5, 0.5, 0.5]}
        else:
            # Skinned wholly to its bones: no rigid pieces (batch 1 decision 3).
            g = recipes.HEADGEAR[name]
            bones = {b.name: b for b in armature.data.bones}
            own = [{key: value for key, value in {**c, **g["chains"][c["chain"]]}.items() if key != "piece"}
                   for c in chains if c.get("piece") == name]
            # Its recipe's heights, for the game's checks to find its parts
            # by: a hood's cape top and the line above which it rides his
            # head alone; a helm's foot.
            marks = {"cape_top": g.get("cape", {}).get("top_z"), "rigid_above": g.get("rigid_above"), "foot": g.get("base_z")}
            data = {"piece": name, "body": g.get("body", "male"), "triangles": common.tri_count(obj),
                    "metal": g["metal"], "hides_hair": g["hides_hair"], "allows_beard": g["allows_beard"],
                    "cloth": own,
                    "colliders": [{"bone": c["bone"], "radius": c["radius"], "height": round(bones[c["bone"]].length, 4)}
                                  for c in g.get("colliders", [])],
                    "marks": {key: value for key, value in marks.items() if value is not None}}
            dyed = dye_base(obj)

            if dyed is not None:
                data["dye_base"] = dyed

        write_json(common.WARDROBE / folder / ("%s.json" % name), data)
        print("wardrobe: exported %s/%s: %d triangles" % (folder, name, data["triangles"]))


def glb(obj, armature, path, cloth=None):
    """`obj` on its skeleton as a GLB: mesh, skin and named material slots
    (the game makes its own materials, choosing by name: WR_strips is drawn
    from both sides), no textures, no animation. Placeholder materials would
    lose the names on Godot's import. Given `cloth` (a piece's own cloth
    bones), the skeleton leaves out every other cloth bone: headgear.blend's
    one armature carries every piece's chains, and a guard takes in every
    bone of what he wears."""
    path.parent.mkdir(parents=True, exist_ok=True)
    common.backup(path)
    others = [b.name for b in armature.data.bones if b.name.startswith("cloth_") and b.name not in cloth] if cloth is not None else []
    rig = stand_in(obj, armature, others) if others else armature

    try:
        common.select_only([obj, rig], active=obj)
        bpy.ops.export_scene.gltf(filepath=str(path), export_format="GLB", use_selection=True, export_materials="EXPORT",
                                  export_image_format="NONE", export_animations=False, export_skins=True, export_yup=True,
                                  export_texcoords=True, export_normals=True, export_vertex_color="NONE", export_apply=False)
    finally:
        if rig is not armature:
            put_back(obj, armature, rig)

    settings = path.with_suffix(".glb.import")

    if not settings.exists():
        relative = "res://" + str(path.relative_to(common.ROOT)).replace(os.sep, "/")
        settings.write_text(IMPORT.format(source=relative))


def stand_in(obj, armature, drop):
    """A copy of `armature` without the bones `drop`, standing in for it
    (under its name, as `obj`'s parent and its Armature modifier's object)
    until put_back."""
    rig = armature.copy()
    rig.data = armature.data.copy()
    bpy.context.scene.collection.objects.link(rig)
    common.select_only([rig], active=rig)
    bpy.ops.object.mode_set(mode="EDIT")

    for name in drop:
        rig.data.edit_bones.remove(rig.data.edit_bones[name])

    bpy.ops.object.mode_set(mode="OBJECT")
    rig["wr_stands_for"] = armature.name
    armature.name, rig.name = armature.name + "_all", armature.name

    for modifier in obj.modifiers:
        if modifier.type == "ARMATURE" and modifier.object == armature:
            modifier.object = rig

    if obj.parent == armature:
        inverse = obj.matrix_parent_inverse.copy()
        obj.parent = rig
        obj.matrix_parent_inverse = inverse

    return rig


def put_back(obj, armature, rig):
    """Undoes stand_in: `obj` on `armature` again, under its own name; the
    stand-in gone."""
    for modifier in obj.modifiers:
        if modifier.type == "ARMATURE" and modifier.object == rig:
            modifier.object = armature

    if obj.parent == rig:
        inverse = obj.matrix_parent_inverse.copy()
        obj.parent = armature
        obj.matrix_parent_inverse = inverse

    name, data = rig["wr_stands_for"], rig.data
    bpy.data.objects.remove(rig)
    bpy.data.armatures.remove(data)
    armature.name = name


def write_json(path, data):
    """`data` as `path`; the one there kept first (source/backup)."""
    path.parent.mkdir(parents=True, exist_ok=True)
    common.backup(path)
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


if __name__ == "__main__":
    main()
