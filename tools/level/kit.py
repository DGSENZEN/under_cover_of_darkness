"""Builds the kit (assets/level/source/kit.blend) from kit_recipes.PIECES:
a mesh `kit_<piece>` for each piece (its boxes, or kit v1's shapes with their
UVs; one material per slot) and
an object of it laid out in a grid by family, for looking at. Levels link
the meshes, so building the kit again updates every level.

    Blender -b --factory-startup --python tools/level/kit.py
"""

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import bpy  # noqa: E402

import common  # noqa: E402
import geo  # noqa: E402
import kit_recipes  # noqa: E402
import kit_shapes  # noqa: E402

# A box's corners, by (x > 0) + 2 (y > 0) + 4 (z > 0); its faces, outward.
FACES = [(0, 4, 6, 2), (1, 3, 7, 5), (0, 1, 5, 4), (2, 6, 7, 3), (0, 2, 3, 1), (4, 5, 7, 6)]


def box_corners(b):
    rot = geo.rotation(b[7] if len(b) > 7 else 0.0, b[8] if len(b) > 8 else 0.0, b[9] if len(b) > 9 else 0.0)
    half = [s / 2.0 for s in b[3:6]]
    out = []

    for i in range(8):
        local = [half[0] * (1 if i & 1 else -1), half[1] * (1 if i & 2 else -1), half[2] * (1 if i & 4 else -1)]
        out.append(geo.to_blender(geo.add(b[0:3], geo.apply(rot, local))))

    return out


material = common.material


def make_modelled(name, recipe):
    """Kit v1: the piece drawn from its shapes (kit_shapes), with its UVs."""
    part = kit_shapes.build(recipe["shapes"])
    slots = []

    for _, slot, _ in part["faces"]:
        if slot not in slots:
            slots.append(slot)

    mesh = bpy.data.meshes.new(common.KIT_PREFIX + name)
    mesh.from_pydata([geo.to_blender(v) for v in part["verts"]], [], [f[0] for f in part["faces"]])

    for slot in slots:
        mesh.materials.append(material(slot))

    layer = mesh.uv_layers.new(name="UVMap")

    for polygon, (indices, slot, uvs) in zip(mesh.polygons, part["faces"]):
        polygon.material_index = slots.index(slot)

        # (kit_shapes' v runs down the photo; Blender's up it.)
        for loop, uv in zip(polygon.loop_indices, uvs):
            layer.data[loop].uv = (uv[0], 1.0 - uv[1])

    # Faces that carry their own normals (rounded cards: a crown lit as a
    # mass); the rest keep their flat ones.
    if part["normals"]:
        mesh.update()
        loops = [None] * len(mesh.loops)

        for index, polygon in enumerate(mesh.polygons):
            own = part["normals"].get(index)

            for k, loop in enumerate(polygon.loop_indices):
                loops[loop] = tuple(geo.to_blender(own[k])) if own is not None else tuple(polygon.normal)

        mesh.normals_split_custom_set(loops)

    mesh.update()
    mesh.use_fake_user = True
    return mesh


def make_mesh(name, recipe):
    if recipe.get("shapes"):
        return make_modelled(name, recipe)

    verts, faces, slots, face_slots = [], [], [], []

    for b in recipe["boxes"]:
        slot = b[6]

        if slot not in slots:
            slots.append(slot)

        base = len(verts)
        verts.extend(box_corners(b))

        for face in FACES:
            faces.append(tuple(base + i for i in face))
            face_slots.append(slots.index(slot))

    mesh = bpy.data.meshes.new(common.KIT_PREFIX + name)
    mesh.from_pydata(verts, [], faces)

    for slot in slots:
        mesh.materials.append(material(slot))

    for polygon, index in zip(mesh.polygons, face_slots):
        polygon.material_index = index

    mesh.update()
    mesh.use_fake_user = True
    return mesh


def main():
    scene = common.scene_fresh()
    families = {}

    for name in kit_recipes.names():
        recipe = kit_recipes.PIECES[name]
        mesh = make_mesh(name, recipe)
        family = recipe["family"]

        if family not in families:
            collection = bpy.data.collections.new(family)
            scene.collection.children.link(collection)
            families[family] = [collection, 0]

        collection, count = families[family]
        obj = bpy.data.objects.new(common.KIT_PREFIX + name, mesh)
        obj["kit_piece"] = name
        obj.location = (count * 6.0, list(families).index(family) * 8.0, 0.0)
        collection.objects.link(obj)
        families[family][1] = count + 1

    common.SOURCE.mkdir(parents=True, exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=str(common.KIT))
    print("level: kit of %d pieces -> %s" % (len(kit_recipes.PIECES), common.KIT.relative_to(common.ROOT)))


main()
