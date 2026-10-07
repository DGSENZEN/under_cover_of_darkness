"""A district's workshop: assets/level/source/workshop_<district>.blend, its
buildings (workshop_groups) and their kit pieces to edit in Blender, read
back into the game by yours.py.

Each building is a collection of its own, side by side along x:

    <building> · building    its pieces as the level places them, locked in
                             place (moving them moves nothing in the game:
                             the level's .blend places pieces)
    <building> · kit         one of each piece it is the home of, in rows in
                             front of it, named after the piece, a label
                             over each
    <building> · colliders   each kit piece's collider boxes (hidden at
                             first), children of their piece
    <building> · from the level  swept ground shown from the level's .blend
                             (the mole's body, the causeway): edit it there

A piece's mesh is shared by every object of it, so editing it in place in
the building edits the kit piece. An edited mesh, or a piece's colliders
moved, added or deleted, is yours: yours.py finds it, kit.py builds it
into the kit instead of the generated one, and building this file again
keeps it (a piece whose generator has changed since is listed under
"Changed under your edits"). Materials are the kit's slots (pick from the
ones in the file); they show the game's photos where textures/ps2 has
them, and are never packed into the file.

    Blender -b --factory-startup --python tools/level/workshop.py -- harbour|old_town
    LEVEL_WORKSHOP_OUT  another .blend to write
    LEVEL_WORKSHOP_GROUPS  only these buildings ("Sea fort,Mole")
    LEVEL_WORKSHOP_DIR  where the workshops are (yours.json names files there)
"""

import json
import math
import os
import re
import sys
from pathlib import Path

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import bpy  # noqa: E402
from mathutils import Matrix  # noqa: E402

import common  # noqa: E402
import geo  # noqa: E402
import kit  # noqa: E402
import kit_recipes  # noqa: E402
import workshop_groups  # noqa: E402
import yours_data  # noqa: E402

LEVELS = {"harbour": "city_harbour", "old_town": "old_town"}
# Between buildings; between a building and its kit rows; between rows (m).
GAP = 30.0
ROWS_FROM = 12.0
ROW_SPACE = 6.0
# A kit row is at least this long before it wraps (m).
ROW_MIN = 80.0
LABEL = 0.9
COLLIDER_MESH = "collider_box"
SLOTS_GD = common.ROOT / "scripts" / "Visual" / "Materials.gd"
SUFFIX = re.compile(r"\.\d{3}$")

README = """WORKSHOP: {district}

Each building is a collection: its pieces as the level places them (locked:
the level's .blend places pieces), its kit pieces in rows in front of it,
their colliders (hidden: show the "colliders" collections), and ground swept
by the level shown from the level's .blend (edit that there).

EDIT a piece: select it (in the building or its row), Tab, edit. Every copy
shares one mesh. Use the materials already in the file (they are the
game's slots; a new one shows magenta in the game).

COLLIDERS are wire boxes, children of their kit piece: move, scale, rotate,
duplicate (Shift+D) or delete them. Each has a "surface" (stone, wood,
metal...) and "occluder" custom property.

INTO THE GAME (from the repository's root):
    tools/level/level.sh kit                  reads your edits, builds the kit
    tools/level/level.sh export city_harbour  (and old_town) into the game
    tools/level/level.sh navmesh harbour      (and old_town) after collider edits

GIVE A PIECE BACK to its generator: set its mesh's custom property
kit_revert to 1, then tools/level/level.sh workshop {district}.

REBUILD this file (new pieces from the generators; yours kept):
    tools/level/level.sh workshop {district}
Only kit meshes and colliders are kept: anything else added here is not.
"""


def base_name(name):
    return SUFFIX.sub("", name)


def _rounded(v):
    return "%.4f" % (0.0 if abs(v) < 5e-5 else v)


def mesh_hash(mesh):
    """A mesh's shape, faces, UVs and slots, rounded: what an edit changes."""
    import hashlib

    h = hashlib.sha1()
    h.update(";".join(",".join(_rounded(c) for c in v.co) for v in mesh.vertices).encode())
    slots = [base_name(m.name) if m is not None else "" for m in mesh.materials]
    h.update(";".join("%s:%s" % (",".join(str(i) for i in p.vertices), slots[p.material_index] if p.material_index < len(slots) else "")
                      for p in mesh.polygons).encode())

    if mesh.uv_layers:
        h.update(";".join("%s,%s" % (_rounded(d.uv[0]), _rounded(d.uv[1])) for d in mesh.uv_layers[0].data).encode())

    return h.hexdigest()


# The game's photos, by slot (Materials.gd's SLOTS).


def slot_photos():
    """{slot: {"photo", "painted", "tile", "uv_tile", "cut"}} read from Materials.gd."""
    out = {}

    for line in SLOTS_GD.read_text().splitlines():
        m = re.match(r'\s*&"(\w+)":\s*\{(.*)\},?\s*$', line)

        if not m:
            continue

        body = m.group(2)
        entry = {}
        photo = re.search(r'"photo":\s*"(\w*)"', body)
        entry["photo"] = photo.group(1) if photo else ""
        entry["painted"] = '"painted": true' in body
        entry["cut"] = '"cut": true' in body
        tile = re.search(r'"tile":\s*(\[[^\]]*\]|[\d.]+)', body)

        if tile:
            value = json.loads(tile.group(1))
            entry["tile"] = value if isinstance(value, list) else [value, value]

        uv = re.search(r'"uv_tile":\s*(\[[^\]]*\])', body)

        if uv:
            entry["uv_tile"] = json.loads(uv.group(1))

        out[m.group(1)] = entry

    return out


def preview(mat, entry):
    """`mat` drawn with its slot's photo (nearest, as the game draws it):
    mapped every "tile" metres of the piece (a box projection, as the
    game's world triplanar), else by its UVs. Its preview colour stays its
    viewport colour. Tagged so kit.py never takes it into the kit."""
    mat["workshop"] = 1

    if not entry or not entry.get("photo"):
        return

    folder = common.ROOT / "textures" / ("painted" if entry["painted"] else "ps2")
    path = folder / (entry["photo"] + ".png")

    if not path.exists():
        return

    image = bpy.data.images.get(path.name) or bpy.data.images.load(str(path), check_existing=True)
    tree = mat.node_tree
    principled = tree.nodes.get("Principled BSDF")
    tex = tree.nodes.new("ShaderNodeTexImage")
    tex.image = image
    tex.interpolation = "Closest"
    tex.location = (-500, 300)
    mapping = tree.nodes.new("ShaderNodeMapping")
    mapping.location = (-700, 300)

    if entry.get("tile"):
        # (The piece's own metres: Blender picks a box projection's face by
        # the object's axes, so world positions would smear a turned wall.)
        coords = tree.nodes.new("ShaderNodeTexCoord")
        tree.links.new(coords.outputs["Object"], mapping.inputs["Vector"])
        tex.projection = "BOX"
        tex.projection_blend = 0.1
        sx, sy = entry["tile"]
        mapping.inputs["Scale"].default_value = (1.0 / sx, 1.0 / sx, 1.0 / sy)
    else:
        coords = tree.nodes.new("ShaderNodeTexCoord")
        tree.links.new(coords.outputs["UV"], mapping.inputs["Vector"])

        if entry.get("uv_tile"):
            mapping.inputs["Scale"].default_value = (1.0 / entry["uv_tile"][0], 1.0 / entry["uv_tile"][1], 1.0)

    coords.location = (-900, 300)
    tree.links.new(mapping.outputs["Vector"], tex.inputs["Vector"])
    tree.links.new(tex.outputs["Color"], principled.inputs["Base Color"])

    if entry.get("cut"):
        tree.links.new(tex.outputs["Alpha"], principled.inputs["Alpha"])
        mat.surface_render_method = "DITHERED"


# Placing.


def world(position, basis):
    """A Godot position and basis as a Blender matrix."""
    m = Matrix([list(r) for r in geo.to_blender_basis(basis)]).to_4x4()
    m.translation = geo.to_blender(position)
    return m


def collider_matrix(col):
    """A collider [cx, cy, cz, sx, sy, sz, surface, yaw, pitch, roll] (the
    piece's frame) as the matrix of a unit cube in Blender's."""
    angles = [float(a) for a in col[7:10]]
    basis = geo.rotation(*(angles + [0.0] * (3 - len(angles))))
    scaled = [[basis[r][c] * col[3 + c] for c in range(3)] for r in range(3)]
    return world(col[0:3], scaled)


def size_of(piece):
    return kit_recipes.PIECES[piece].get("size") or [2.0, 2.0, 2.0]


def extent(placed):
    """The ground a building's pieces cover: (x0, x1, z0, z1)."""
    if not placed:
        return (0.0, 0.0, 0.0, 0.0)

    xs, zs = [], []

    for p in placed:
        half = max(size_of(p["piece"])[0], size_of(p["piece"])[2]) / 2.0
        xs += [p["position"][0] - half, p["position"][0] + half]
        zs += [p["position"][2] - half, p["position"][2] + half]

    return (min(xs), max(xs), min(zs), max(zs))


def rows(pieces, length):
    """Kit pieces wrapped into rows `length` long: [(piece, x, row)], and
    each row's depth."""
    out, depths, x, row = [], [0.0], 0.0, 0

    for piece in pieces:
        w, _, d = size_of(piece)

        if x > 0.0 and x + w > length:
            x, row = 0.0, row + 1
            depths.append(0.0)

        out.append((piece, x + w / 2.0, row))
        depths[row] = max(depths[row], d)
        x += w + workshop_groups.ROW_GAP

    return out, depths


def collection(name, parent):
    found = bpy.data.collections.new(name)
    parent.children.link(found)
    return found


def label(text, at, size, into):
    curve = bpy.data.curves.new(text, "FONT")
    curve.body = text
    curve.size = size
    curve.align_x = "CENTER"
    obj = bpy.data.objects.new("label " + text, curve)
    obj.location = at
    obj.rotation_euler = (math.radians(90.0), 0.0, 0.0)
    obj.hide_select = True
    into.objects.link(obj)
    return obj


# The pieces' meshes.


def mine(here):
    """yours.json's pieces, each marked whether this workshop is its home
    for the mesh and for the colliders."""
    yours = yours_data.load()
    return {name: dict(y, mesh_here=y.get("file") == here, cols_here=y.get("cols_file") == here) for name, y in yours.items()}


def meshes(pieces, yours, folder, stale):
    """Each piece's mesh: yours if you edited it (its base what you started
    from), else made from its recipe (its base its own hash)."""
    made = {}

    for name in pieces:
        recipe = kit_recipes.PIECES[name]
        generated = kit.make_mesh(name, recipe)
        fresh = mesh_hash(generated)
        mine_ = yours.get(name)

        if mine_ and mine_.get("mesh"):
            generated.name = "_generated"
            mesh = kit.yours_mesh(name, mine_["file"], folder)
            bpy.data.meshes.remove(generated)
            mesh.name = common.KIT_PREFIX + name

            if mine_["mesh_here"]:
                mesh["kit_base"] = mine_["base"]

                if mine_["base"] != fresh:
                    stale.append(name)
            else:
                # (Another workshop's: yours there, edited here only if changed.)
                mesh["kit_base"] = mesh_hash(mesh)
                mesh["kit_from"] = mine_["file"]
        else:
            mesh = generated
            mesh["kit_base"] = fresh

        mesh["kit_generated"] = fresh
        mesh.use_fake_user = True
        made[name] = mesh

    return made


def colliders(obj, name, yours, into, unit):
    """The piece's colliders as wire unit cubes, children of `obj`; its
    recipe's (yours applied: kit_recipes read yours.json) as their base."""
    recipe = kit_recipes.PIECES[name]
    cols = recipe["cols"]
    hidden = set(recipe.get("occlusion_exclude", []))
    obj["kit_cols_base"] = json.dumps(cols)
    obj["kit_cols_exclude"] = json.dumps(sorted(hidden))
    obj["kit_cols_generated"] = json.dumps([recipe.get("generated_cols", cols), recipe.get("generated_exclude", sorted(hidden))])
    obj["kit_cols_yours"] = 1 if yours.get(name, {}).get("cols_here") else 0

    for i, col in enumerate(cols):
        box = bpy.data.objects.new("%s collider %d" % (name, i + 1), unit)
        box.display_type = "WIRE"
        box.hide_render = True
        box.parent = obj
        box.matrix_parent_inverse = Matrix.Identity(4)
        box.matrix_basis = collider_matrix(col)
        box["collider_of"] = name
        box["collider_index"] = i
        box["collider_name"] = box.name
        box["surface"] = col[6] if len(col) > 6 else recipe["surface"]
        box["occluder"] = 0 if (i in hidden or box["surface"] == "glass") else 1
        box["m"] = [v for row in collider_matrix(col) for v in row]
        into.objects.link(box)


def unit_cube():
    mesh = bpy.data.meshes.new(COLLIDER_MESH)
    h = 0.5
    verts = [(x, y, z) for x in (-h, h) for y in (-h, h) for z in (-h, h)]
    mesh.from_pydata(verts, [], [(0, 1, 3, 2), (4, 6, 7, 5), (0, 4, 5, 1), (2, 3, 7, 6), (0, 2, 6, 4), (1, 5, 7, 3)])
    mesh.use_fake_user = True
    return mesh


def context(level_blend, names, offset, into):
    """The level's own objects (its swept ground) as they are in its .blend,
    moved with their building; not to be edited here."""
    if not names or not level_blend.exists():
        return

    with bpy.data.libraries.load(str(level_blend), link=False) as (source, target):
        target.objects = [n for n in names if n in source.objects]

    for obj in target.objects:
        if obj is None:
            continue

        for i, m in enumerate(obj.data.materials):
            if m is not None:
                obj.data.materials[i] = common.material(base_name(m.name))

        obj.matrix_basis = Matrix.Translation(geo.to_blender(offset)) @ obj.matrix_basis
        obj.name = "%s (edit in %s)" % (obj.name, level_blend.name)
        obj.hide_select = True
        into.objects.link(obj)


def views():
    """The file opens looking at the photos, far enough to see a district."""
    for screen in bpy.data.screens:
        for area in screen.areas:
            if area.type == "VIEW_3D":
                for space in area.spaces:
                    if space.type == "VIEW_3D":
                        space.shading.type = "MATERIAL"
                        space.clip_end = 5000.0
                        space.clip_start = 0.05


def build(district):
    here_out = os.environ.get("LEVEL_WORKSHOP_OUT") or str(common.SOURCE / ("workshop_%s.blend" % district))
    folder = os.environ.get("LEVEL_WORKSHOP_DIR") or str(common.SOURCE)
    here = Path(here_out).name
    only = {n for n in os.environ.get("LEVEL_WORKSHOP_GROUPS", "").split(",") if n}
    groups = [g for g in workshop_groups.groups(district) if not only or g["name"] in only]
    yours = {n: y for n, y in mine(here).items() if n in kit_recipes.PIECES}
    # (Every piece shown: a building left out may be another's pieces' home.)
    pieces = list(dict.fromkeys([p for g in groups for p in g["kit"]] + [p["piece"] for g in groups for p in g["placed"]]))

    common.scene_fresh()
    scene = bpy.context.scene
    stale = []
    made = meshes(pieces, yours, folder, stale)
    # (What came in with your meshes: the previews are made afresh below.)
    kit._photos_out()
    photos = slot_photos()

    # (Every slot, so any can be picked.)
    for slot in sorted(set(common.SLOT_COLOURS) | set(photos)):
        common.material(slot).use_fake_user = True

    for mat in bpy.data.materials:
        preview(mat, photos.get(mat.name))

    unit = unit_cube()
    level_blend = common.SOURCE / (LEVELS[district] + ".blend")
    root = collection("Workshop: " + district, scene.collection)
    changed = collection("Changed under your edits", root) if stale else None
    x = 0.0

    for g in groups:
        x0, x1, z0, z1 = extent(g["placed"])
        length = max(x1 - x0, ROW_MIN)
        laid, depths = rows(g["kit"], length)
        width = max(x1 - x0, max([lx + size_of(p)[0] / 2.0 for p, lx, _ in laid] or [0.0]))
        # (The building's left edge at x; its rows in front, +z.)
        spot = [x - x0, 0.0, 0.0]
        top = collection(g["name"], root)
        building = collection(g["name"] + " · building", top)
        row_into = collection(g["name"] + " · kit", top)
        cols_into = collection(g["name"] + " · colliders", top)
        notes = collection(g["name"] + " · labels", top)

        for p in g["placed"]:
            obj = bpy.data.objects.new(p["name"], made[p["piece"]])
            obj.matrix_world = world(geo.add(spot, p["position"]), p["basis"])
            obj.lock_location = obj.lock_rotation = obj.lock_scale = (True, True, True)
            obj["kit_piece"] = p["piece"]
            building.objects.link(obj)

        title_z = z1 + ROWS_FROM / 2.0
        label(g["name"], geo.to_blender([x + width / 2.0, 0.05, title_z]), 2.4, notes)
        label(g["note"], geo.to_blender([x + width / 2.0, 0.05, title_z + 2.0]), 0.8, notes)
        row_z = [z1 + ROWS_FROM]

        for d in depths[:-1]:
            row_z.append(row_z[-1] + d + ROW_SPACE + 2.0)

        for piece, lx, row in laid:
            at = [x + lx, 0.0, row_z[row] + depths[row] / 2.0]
            obj = bpy.data.objects.new(piece, made[piece])
            obj.location = geo.to_blender(at)
            obj["kit_piece"] = piece
            obj["kit_home"] = g["name"]
            row_into.objects.link(obj)
            colliders(obj, piece, yours, cols_into, unit)
            label(piece, geo.to_blender([at[0], size_of(piece)[1] + 0.6, at[2] + depths[row] / 2.0]), LABEL, notes)

            if changed is not None and piece in stale:
                changed.objects.link(obj)

        if g["context"]:
            context(level_blend, g["context"], geo.sub(spot, g["origin"]), collection(g["name"] + " · from the level", top))

        x += width + GAP

    # (Colliders hidden at first; labels not selectable.)
    for layer in scene.view_layers:
        def walk(lc):
            for child in lc.children:
                if child.name.endswith(" · colliders"):
                    child.hide_viewport = True

                walk(child)

        walk(layer.layer_collection)

    text = bpy.data.texts.new("README")
    text.write(README.format(district=district))
    text.use_fake_user = True
    views()
    bpy.context.view_layer.update()

    # (Everything brought in was appended: the file links nothing.)
    for library in list(bpy.data.libraries):
        bpy.data.libraries.remove(library)

    for image in bpy.data.images:
        if image.packed_file is not None:
            common.fail("workshop: %s would be packed into the file" % image.name)

    bpy.ops.wm.save_as_mainfile(filepath=here_out, compress=True, relative_remap=True)
    print("workshop: %d buildings, %d kit pieces (%d yours) -> %s" % (len(groups), len(pieces), sum(1 for n in pieces if n in yours), here_out))

    for name in stale:
        print("workshop: %s: its generator has changed since you edited it (yours kept; see \"Changed under your edits\")" % name)


if __name__ == "__main__":
    args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []

    if not args or args[0] not in LEVELS:
        common.fail("workshop: which district? " + "|".join(LEVELS))

    build(args[0])
