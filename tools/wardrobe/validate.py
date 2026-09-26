"""The export's rules (spec §6.7): a part that breaks any of them is not
written. check() returns one message per broken rule, each starting with the
rule's id (budget, influences, unweighted, bone, uv, texture, palette, joint,
hidden, bare, shading); an empty list means the part may go out.
"""

import os

import bpy
import numpy as np

import common
import recipes


def check(mesh, *, armature=None, reference_joints=None, cloth_bones=(), images=(), palette=common.PALETTE,
          combined_tris=None, budget=common.NPC_BUDGET, bare=None):
    """Every rule `mesh` breaks.

    armature: its skeleton, when it is skinned (weights are checked, and its
        joints against `reference_joints`, the Quaternius skeleton's).
    cloth_bones: bones it may be weighted to besides the game's.
    images: (path, (width, height), palettized) for each texture it wears.
    combined_tris: the heaviest NPC it can be part of, if not itself alone.
    bare: the body regions (common.REGIONS) his recipe leaves uncovered;
        his skin showing anywhere else is a hole in a garment.
    """
    messages = []
    total = combined_tris if combined_tris is not None else common.tri_count(mesh)

    if total > budget:
        messages.append("budget: %d triangles, limit %d" % (total, budget))

    if armature is not None:
        messages += _weights(mesh, armature, reference_joints, cloth_bones)

    messages += _uvs(mesh)

    for path, size, palettized in images:
        messages += _image(path, size, palettized, palette)

    if armature is not None and reference_joints is not None:
        messages += _joints(armature, reference_joints)

    messages += _hidden(mesh)
    messages += _shading(mesh)

    if bare is not None:
        messages += _bare(mesh, bare)

    return messages


def _weights(mesh, armature, reference_joints, cloth_bones):
    names = {group.index: group.name for group in mesh.vertex_groups}
    allowed = set(reference_joints) if reference_joints is not None else {bone.name for bone in armature.data.bones}
    allowed |= set(cloth_bones)
    over = 0
    unweighted = 0
    unknown = set()

    for vertex in mesh.data.vertices:
        weights = [(names[g.group], g.weight) for g in vertex.groups if g.weight > 1e-6]

        if len(weights) > 4:
            over += 1

        if sum(weight for _, weight in weights) <= 1e-6:
            unweighted += 1

        unknown |= {name for name, _ in weights if name not in allowed}

    messages = []

    if over:
        messages.append("influences: %d vertices on more than 4 bones" % over)

    if unweighted:
        messages.append("unweighted: %d vertices on no bone" % unweighted)

    if unknown:
        messages.append("bone: weighted to unknown bones %s" % sorted(unknown))

    return messages


def _uvs(mesh):
    layers = mesh.data.uv_layers

    if not layers:
        return ["uv: no UV map"]

    data = layers.active.data
    uv = np.empty(len(data) * 2, dtype=np.float32)
    data.foreach_get("uv", uv)
    outside = int(np.count_nonzero(np.any((uv.reshape(-1, 2) < -1e-4) | (uv.reshape(-1, 2) > 1.0 + 1e-4), axis=1)))
    return ["uv: %d loops outside 0-1" % outside] if outside else []


def _image(path, size, palettized, palette):
    name = os.path.basename(path)

    if not os.path.exists(path):
        return ["texture: %s is missing" % name]

    image = bpy.data.images.load(path, check_existing=False)
    width, height = image.size
    messages = []

    if (width, height) != tuple(size):
        messages.append("texture: %s is %dx%d, expected %dx%d" % (name, width, height, size[0], size[1]))

    if palettized:
        pixels = np.empty(width * height * 4, dtype=np.float32)
        image.pixels.foreach_get(pixels)
        rgb = np.round(pixels.reshape(-1, 4)[:, :3] * 255.0).astype(np.int64)
        colours = len(np.unique(rgb[:, 0] * 65536 + rgb[:, 1] * 256 + rgb[:, 2]))

        if colours > palette:
            messages.append("palette: %s has %d colours, limit %d" % (name, colours, palette))

    bpy.data.images.remove(image)
    return messages


def _joints(armature, reference_joints):
    actual = common.joints(armature)
    off = []

    for name, reference in reference_joints.items():
        if name not in actual:
            off.append("%s missing" % name)
            continue

        distance = sum((a - b) ** 2 for a, b in zip(actual[name], reference)) ** 0.5

        if distance > 0.001:
            off.append("%s %.1f mm" % (name, distance * 1000.0))

    return ["joint: %d bones off the Quaternius skeleton (%s)" % (len(off), ", ".join(off))] if off else []


def _bare(mesh, bare):
    """Body faces showing outside the regions `bare` names."""
    parts = mesh.data.attributes.get("wr_part")
    fabrics = mesh.data.attributes.get("wr_fabric")

    if parts is None or fabrics is None:
        return []

    skin = recipes.FABRICS.index("skin")
    regions = common.vertex_regions(mesh)
    shown = []

    for polygon in mesh.data.polygons:
        if parts.data[polygon.index].value != 0 or fabrics.data[polygon.index].value != skin:
            continue

        values = [regions[i] for i in polygon.vertices]
        # The commonest region; ties go the same way on every run.
        if max(sorted(set(values)), key=values.count) not in bare:
            shown.append(polygon.center)

    if not shown:
        return []

    at = shown[0]
    return ["bare: %d body faces show outside %s (one at %.3f, %.3f, %.3f)" % (len(shown), sorted(bare), at.x, at.y, at.z)]


def _shading(mesh):
    """Faces drawn flat, or normals set by hand (the imported body's, which
    go stale once it is cut and pushed about): PS2 characters are drawn
    smooth, hard only along their creases (sharp edges)."""
    data = mesh.data
    flat = sum(1 for polygon in data.polygons if not polygon.use_smooth)
    messages = ["shading: %d faces drawn flat" % flat] if flat else []

    if data.has_custom_normals:
        messages.append("shading: normals set by hand (custom normals)")

    return messages


def _hidden(mesh):
    """Body faces a garment covers, within its thickness + MARGIN."""
    hidden = common.hidden_faces(mesh)
    return ["hidden: %d body faces under garments" % len(hidden)] if hidden else []
