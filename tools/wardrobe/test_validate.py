"""The export's validation rules, one broken scene at a time.

    tools/wardrobe/wardrobe.sh test

Each case builds a tiny clean part (a weighted, unwrapped mesh on a small
armature, with a 256 px texture) and breaks exactly one thing; the rules must
report exactly that one thing, and nothing for the clean part. Runs in a
factory-fresh Blender, headless. Exit code 1 on any failure.
"""

import os
import sys
import tempfile

import bpy
import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import common  # noqa: E402
import validate  # noqa: E402

TMP = tempfile.mkdtemp(prefix="wardrobe_test_")


def fresh():
    """An empty scene."""
    bpy.ops.wm.read_factory_settings(use_empty=True)


def armature():
    """A tiny armature: root, and pelvis above it."""
    data = bpy.data.armatures.new("Arm")
    arm = bpy.data.objects.new("Armature", data)
    bpy.context.scene.collection.objects.link(arm)
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.mode_set(mode="EDIT")
    root = data.edit_bones.new("root")
    root.head, root.tail = (0, 0, 0), (0, 0, 0.1)
    pelvis = data.edit_bones.new("pelvis")
    pelvis.head, pelvis.tail = (0, 0, 1.0), (0, 0, 1.1)
    pelvis.parent = root
    bpy.ops.object.mode_set(mode="OBJECT")
    return arm


def grid(name, tris, z=0.0, part=None, thickness=0.0):
    """A flat strip of `tris` triangles at height z, UVs inside 0-1, every
    vertex wholly on pelvis. With `part`, faces carry wr_part/wr_thickness."""
    quads = max(1, tris // 2)
    verts, faces, uvs = [], [], []

    for i in range(quads + 1):
        verts += [(i * 0.01, 0.0, z), (i * 0.01, 0.01, z)]

    for i in range(quads):
        a = i * 2
        faces += [(a, a + 2, a + 3), (a, a + 3, a + 1)]

    faces = faces[:tris] if tris >= 2 else faces[:1]
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(verts, [], faces)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(obj)
    layer = mesh.uv_layers.new(name="UVMap")

    for loop in mesh.loops:
        x, y, _ = mesh.vertices[loop.vertex_index].co
        layer.data[loop.index].uv = (min(x / (quads * 0.01 + 1e-9), 1.0) * 0.98 + 0.01, y * 50 + 0.25)

    group = obj.vertex_groups.new(name="pelvis")
    group.add(list(range(len(verts))), 1.0, "REPLACE")

    if part is not None:
        parts = mesh.attributes.new("wr_part", "INT", "FACE")
        thick = mesh.attributes.new("wr_thickness", "FLOAT", "FACE")

        for f in range(len(mesh.polygons)):
            parts.data[f].value = part
            thick.data[f].value = thickness

    return obj


def join(objects, name):
    """One mesh of several (the body and a garment of a part)."""
    bpy.ops.object.select_all(action="DESELECT")

    for obj in objects:
        obj.select_set(True)

    bpy.context.view_layer.objects.active = objects[0]
    bpy.ops.object.join()
    objects[0].name = name
    return objects[0]


def texture(name, size, colours):
    """A PNG of `size` with `colours` distinct colours; its path."""
    w, h = size
    pixels = np.zeros((h, w, 4), dtype=np.float32)
    pixels[..., 3] = 1.0
    flat = pixels.reshape(-1, 4)

    for i in range(len(flat)):
        c = i % colours
        flat[i, 0] = (c % 16) / 15.0
        flat[i, 1] = ((c // 16) % 16) / 15.0
        flat[i, 2] = (c // 256) / 15.0

    image = bpy.data.images.new(name, w, h, alpha=True)
    image.pixels.foreach_set(flat.ravel())
    path = os.path.join(TMP, name + ".png")
    image.filepath_raw = path
    image.file_format = "PNG"
    image.save()
    return path


def clean(**overrides):
    """A clean part and the arguments that check it; `overrides` break one."""
    fresh()
    arm = armature()
    reference = common.joints(arm)
    mesh = grid("Part", 20)
    args = dict(armature=arm, reference_joints=reference, cloth_bones=(),
                images=[(texture("albedo", (256, 256), 40), (256, 256), True)],
                palette=64, combined_tris=None, budget=3000)
    return mesh, arm, args


def case_clean():
    mesh, _, args = clean()
    return validate.check(mesh, **args)


def case_budget():
    mesh, _, args = clean()
    big = grid("Big", 3010)
    args["combined_tris"] = common.tri_count(big)
    return validate.check(big, **args)


def case_influences():
    mesh, _, args = clean()

    for name in ("spine_01", "spine_02", "spine_03", "neck_01"):
        mesh.vertex_groups.new(name=name).add([0], 0.2, "REPLACE")

    args["cloth_bones"] = ("spine_01", "spine_02", "spine_03", "neck_01")
    return validate.check(mesh, **args)


def case_unweighted():
    mesh, _, args = clean()
    mesh.vertex_groups["pelvis"].remove([0])
    return validate.check(mesh, **args)


def case_bone():
    mesh, _, args = clean()
    mesh.vertex_groups["pelvis"].remove([0])
    mesh.vertex_groups.new(name="not_a_bone").add([0], 1.0, "REPLACE")
    return validate.check(mesh, **args)


def case_uv():
    mesh, _, args = clean()
    mesh.data.uv_layers[0].data[0].uv = (1.2, 0.5)
    return validate.check(mesh, **args)


def case_texture():
    mesh, _, args = clean()
    args["images"] = [(texture("wrong", (300, 300), 40), (256, 256), True)]
    return validate.check(mesh, **args)


def case_palette():
    mesh, _, args = clean()
    args["images"] = [(texture("busy", (256, 256), 100), (256, 256), True)]
    return validate.check(mesh, **args)


def case_joint():
    mesh, arm, args = clean()
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.mode_set(mode="EDIT")
    arm.data.edit_bones["pelvis"].head.z += 0.002
    bpy.ops.object.mode_set(mode="OBJECT")
    return validate.check(mesh, **args)


def case_hidden():
    mesh, _, args = clean()
    bpy.data.objects.remove(mesh)
    body = grid("Body", 2, z=0.0, part=0, thickness=0.0)
    # 1 cm above the body, a garment 6 mm thick: within its thickness + 5 mm.
    garment = grid("Garment", 2, z=0.01, part=1, thickness=0.006)
    part = join([body, garment], "Part")
    return validate.check(part, **args)


def case_colour():
    """The recipes' colours are sRGB: a part's base colour is stored so the
    bake reads its linear value (not the sRGB number, a gamma step lighter)."""
    fresh()
    part = grid("Part", 2)
    common.set_faces(part, 1, 0, 0.004, False, False, (0.34, 0.34, 0.36))
    stored = part.data.color_attributes["wr_base"].data[0].color[0]
    want = ((0.34 + 0.055) / 1.055) ** 2.4
    return [] if abs(stored - want) < 0.01 else ["colour: sRGB 0.34 stored as %.3f linear, want %.3f" % (stored, want)]


CASES = {
    "clean": (case_clean, None),
    "budget": (case_budget, "budget:"),
    "influences": (case_influences, "influences:"),
    "unweighted": (case_unweighted, "unweighted:"),
    "bone": (case_bone, "bone:"),
    "uv": (case_uv, "uv:"),
    "texture": (case_texture, "texture:"),
    "palette": (case_palette, "palette:"),
    "joint": (case_joint, "joint:"),
    "hidden": (case_hidden, "hidden:"),
    "colour": (case_colour, None),
}


def main():
    failed = 0

    for name, (run, prefix) in CASES.items():
        try:
            messages = run()
        except Exception as error:  # a crash is a failure of that case
            messages = ["crash: %r" % error]

        ok = messages == [] if prefix is None else (len(messages) == 1 and messages[0].startswith(prefix))
        print("%s %s%s" % ("PASS" if ok else "FAIL", name, "" if ok else ": %s" % messages))
        failed += 0 if ok else 1

    print("validate: %d/%d" % (len(CASES) - failed, len(CASES)))
    sys.exit(1 if failed else 0)


main()
