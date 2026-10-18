"""The Metro Underground's uncanny (docs/superpowers/refs/underground/supernatural_refs.md):
the nahual, the old man who sits on the bench every night become an enormous black dog,
lying beside it with its head up; and the old man's palm hat, left on the bench by his paper.

The dog lies along +X (its head that way), on the floor (z = 0). Its head is its own object,
its origin the neck (NECK on the body) so the bay can turn it to watch; its snout along +X.
It is modelled as one smooth skin over a skeleton (Blender's Skin, then Subdivision), on a
xoloitzcuintle's build: the Aztec dog that guides the dead through Mictlan. Mignola's way:
one black shape with nothing drawn inside it but two ember eyes.

    Blender -b --factory-startup --python tools/eclipse/underground_uncanny.py
"""

import math
import os
import random
import sys

from mathutils import Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import bmesh  # noqa: E402
import bpy  # noqa: E402

import common  # noqa: E402
import gate  # noqa: E402
import underground_shapes  # noqa: E402
from underground_shapes import pipe, smooth_object, turned  # noqa: E402

NAME = "underground_uncanny"
ATLAS = 1024
SLOTS = ["nahual_black", "ember", "palm"]

rng = random.Random(1521)

# Where the head turns on the body: the top of the neck. Where the chest is deepest and the
# waist most tucked (a xolo's build).
NECK = (0.88, 0.0, 0.64)
CHEST_X = 0.55
WAIST_X = 0.3
SIDES = 10
# How smooth the skin is made (Subdivision levels), and the voxels its parts are fused on (m).
SMOOTH = 2
BODY_VOXEL = 0.018
HEAD_VOXEL = 0.0125


def skinned(name, joints, bones, slot, smooth=SMOOTH):
    """An organic closed form from a skeleton (the Skin modifier, then Subdivision): `joints`
    [(at, (radius across, radius up))], `bones` [(i, j)] between them; joint 0 its root."""
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata([j[0] for j in joints], list(bones), [])
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(obj)
    skin = obj.modifiers.new("skin", "SKIN")
    skin.use_smooth_shade = True
    skin.branch_smoothing = 0.6

    for i, (_, (across, up)) in enumerate(joints):
        mesh.skin_vertices[0].data[i].radius = (across, up)

    mesh.skin_vertices[0].data[0].use_root = True
    sub = obj.modifiers.new("smooth", "SUBSURF")
    sub.levels = smooth
    sub.render_levels = smooth
    depsgraph = bpy.context.evaluated_depsgraph_get()
    solid = bpy.data.meshes.new_from_object(obj.evaluated_get(depsgraph))
    obj.modifiers.clear()
    obj.data = solid
    bpy.data.meshes.remove(mesh)
    solid.materials.clear()
    solid.materials.append(common.slot(slot))

    for poly in solid.polygons:
        poly.material_index = 0
        poly.use_smooth = True

    return obj


def chain(name, joints, slot="nahual_black", smooth=SMOOTH):
    """One unbranched limb skinned from its joints in order (every limb its own skin, rooted
    inside what it grows from; `fused` joins them into one surface)."""
    return skinned(name, joints, [(i, i + 1) for i in range(len(joints) - 1)], slot, smooth)


def leaf(name, root, tip, width, thick, cup, slot="nahual_black"):
    """A broad leaf (a bat ear): wide at its root, tapering to a rounded point at its tip,
    `thick` through, its front cupped in by `cup`; root and tip (x, y, z), its face toward +x."""
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=16, v_segments=12, radius=1.0)
    r, t = Vector(root), Vector(tip)
    length = (t - r).length
    up = (t - r).normalized()
    side = up.cross(Vector((1.0, 0.0, 0.0))).normalized()
    front = side.cross(up).normalized()

    for v in bm.verts:
        x, y, z = v.co
        along = (z + 1.0) / 2.0                       # 0 root, 1 tip
        w = width * (1.0 - 0.7 * along ** 1.4)        # wide at the root, narrowing to a rounded tip
        depth = thick * (1.0 - 0.2 * along) * x - cup * (1.0 - y * y) * (1.0 if x > 0 else 0.0)
        v.co = r + up * (along * length) + side * (y * w * 0.5) + front * depth

    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(obj)
    mesh.materials.append(common.slot(slot))
    return obj


def fused(obj, voxel, calm=4, slot="nahual_black"):
    """Its parts fused into one smooth surface (the Colima dogs' one burnished volume): a voxel
    remesh unions them, then smoothing burnishes away the voxels' steps and the joins."""
    remesh = obj.modifiers.new("fuse", "REMESH")
    remesh.mode = "VOXEL"
    remesh.voxel_size = voxel
    remesh.adaptivity = 0.0
    smooth = obj.modifiers.new("burnish", "SMOOTH")
    smooth.factor = 0.6
    smooth.iterations = calm
    depsgraph = bpy.context.evaluated_depsgraph_get()
    solid = bpy.data.meshes.new_from_object(obj.evaluated_get(depsgraph))
    old = obj.data
    obj.modifiers.clear()
    obj.data = solid
    bpy.data.meshes.remove(old)
    tidy(solid)
    solid.materials.clear()
    solid.materials.append(common.slot(slot))

    for poly in solid.polygons:
        poly.material_index = 0
        poly.use_smooth = True

    return obj


def tidy(mesh, weld=0.001, least=200):
    """A fused surface tidied: corners closer than `weld` merged (the faces smoothing squeezed to
    nothing), and loose fragments under `least` faces (crumbs the voxels left at thin tips) gone."""
    bm = bmesh.new()
    bm.from_mesh(mesh)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=weld)
    bm.faces.ensure_lookup_table()
    seen, crumbs = set(), []

    for f in bm.faces:
        if f in seen:
            continue
        island, todo = {f}, [f]
        while todo:
            g = todo.pop()
            for e in g.edges:
                for h in e.link_faces:
                    if h not in island:
                        island.add(h)
                        todo.append(h)
        seen |= island
        if len(island) < least:
            crumbs.extend(island)

    if crumbs:
        bmesh.ops.delete(bm, geom=crumbs, context="FACES")

    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(mesh)
    bm.free()


def nahual_body():
    """The dog lying sphinx-like (a sighthound's pose), a xoloitzcuintle's build made enormous:
    a deep chest on the floor line, the waist tucked up behind it, the haunch rising again,
    the hind legs folded flat beside the belly, the forelegs straight out and parallel, a long
    low tail curled round to its feet, the neck rising long to its head."""
    torso = chain("nahual_body", [
        ((-0.04, 0.0, 0.28), (0.1, 0.11)),     # the rump
        ((0.1, 0.0, 0.29), (0.13, 0.14)),      # the haunch
        ((WAIST_X, 0.0, 0.33), (0.09, 0.085)),  # the tucked waist
        ((CHEST_X, 0.0, 0.31), (0.14, 0.22)),  # the ribs, deep to the floor line
        ((0.7, 0.0, 0.36), (0.13, 0.22)),      # the brisket
        ((0.8, 0.0, 0.5), (0.085, 0.1)),       # the neck's root
        (NECK, (0.07, 0.08))])                 # the neck's top
    limbs = []

    for sy in (-1, 1):
        # A foreleg straight out and parallel: from inside the brisket, the elbow tucked, the
        # forearm laid forward on the floor, the paw.
        limbs.append(chain("foreleg_%d" % sy, [((0.72, sy * 0.06, 0.28), (0.065, 0.065)), ((0.72, sy * 0.085, 0.16), (0.06, 0.06)),
                                                ((0.75, sy * 0.09, 0.06), (0.046, 0.046)), ((0.9, sy * 0.092, 0.045), (0.036, 0.036)),
                                                ((1.04, sy * 0.093, 0.04), (0.033, 0.033)), ((1.12, sy * 0.093, 0.035), (0.045, 0.034))], smooth=1))
        # A hind leg folded flat beside the belly: the thigh forward and out, the shank back to the
        # hock on the floor, the foot forward along it.
        limbs.append(chain("thigh_%d" % sy, [((0.1, sy * 0.05, 0.27), (0.09, 0.09)), ((0.14, sy * 0.11, 0.2), (0.09, 0.095)),
                                              ((0.3, sy * 0.15, 0.12), (0.07, 0.07))], smooth=1))
        limbs.append(chain("shank_%d" % sy, [((0.3, sy * 0.155, 0.115), (0.058, 0.058)), ((0.18, sy * 0.17, 0.075), (0.046, 0.046)),
                                              ((0.07, sy * 0.175, 0.045), (0.042, 0.042))], smooth=1))
        limbs.append(chain("hindfoot_%d" % sy, [((0.06, sy * 0.178, 0.04), (0.038, 0.034)), ((0.17, sy * 0.183, 0.033), (0.034, 0.03)),
                                                 ((0.28, sy * 0.185, 0.032), (0.04, 0.031))], smooth=1))

    # The tail: long, low-set, tapering, curled round along the floor to the hind feet.
    limbs.append(chain("tail", [((0.0, 0.0, 0.27), (0.045, 0.045)), ((-0.12, 0.0, 0.23), (0.035, 0.035)),
                                ((-0.2, -0.03, 0.13), (0.03, 0.03)), ((-0.2, -0.14, 0.045), (0.026, 0.026)),
                                ((-0.06, -0.25, 0.035), (0.024, 0.024)), ((0.1, -0.27, 0.032), (0.022, 0.022))], smooth=1))
    underground_shapes.join(torso, limbs)
    fused(torso, BODY_VOXEL)
    low = min(v.co.z for v in torso.data.vertices)

    for v in torso.data.vertices:
        v.co.z -= low

    return torso


def nahual_head():
    """Its head, from the neck (the origin): a stub of neck back into the body; a wedge, the
    skull and the muzzle nearly equal and their planes nearly parallel; the jaw's line, the
    cheekbones, the brow; its great bat ears, broad leaves set obliquely and cupped forward;
    and its two round ember eyes sunk in."""
    # (Its collar flush with the body's neck where it meets it; the stub inside the body closes the gap
    # as it turns.)
    head = chain("nahual_head", [((-0.12, 0.0, -0.12), (0.068, 0.074)), # the neck stub, into the body
                                 ((0.0, 0.0, 0.0), (0.07, 0.078)),      # the collar at the neck's top
                                 ((0.07, 0.0, 0.06), (0.09, 0.082)),    # the back of the skull, broad
                                 ((0.15, 0.0, 0.065), (0.08, 0.07)),    # the brow
                                 ((0.22, 0.0, 0.05), (0.062, 0.055)),   # the stop
                                 ((0.3, 0.0, 0.035), (0.05, 0.045)),    # the muzzle, level with the skull
                                 ((0.37, 0.0, 0.025), (0.042, 0.038))], smooth=1)  # the nose, blunt
    flesh = [chain("jaw", [((0.04, 0.0, -0.02), (0.06, 0.04)), ((0.17, 0.0, -0.01), (0.048, 0.034)),
                           ((0.3, 0.0, -0.005), (0.034, 0.028))], smooth=1)]
    eyes = []

    for sy in (-1, 1):
        flesh.append(chain("cheek_%d" % sy, [((0.07, sy * 0.045, 0.02), (0.036, 0.03)), ((0.17, sy * 0.04, 0.03), (0.034, 0.028))], smooth=1))
        # A great bat ear, a broad leaf: its root on the skull's crown, standing tall and a little out.
        # (Its root sunk deep in the skull: a leaf comes to a point at its root, and must overlap to fuse.)
        flesh.append(leaf("ear_%d" % sy, root=(0.07, sy * 0.035, 0.0), tip=(0.0, sy * 0.2, 0.34), width=0.17, thick=0.034,
                          cup=0.014))
        # An eye, round, sunk half into the skull beside the brow, looking forward and out.
        m = common.Mesh("eye_%d" % sy, outward=True)
        turned(m, [(0.012, 0.0), (0.022, 0.012), (0.022, 0.026), (0.012, 0.036)], 8, "ember",
               at=(0.15, sy * 0.05, 0.075), lean=math.pi / 2, towards=(math.pi - 0.5) if sy > 0 else 0.5)
        eyes.append(m.make())

    underground_shapes.join(head, flesh)
    fused(head, HEAD_VOXEL)
    underground_shapes.join(head, eyes)
    return head


# --- the procession: the dead in white, candles in their hands (supernatural_refs.md) ------------
# Real human bodies: Quaternius's Universal Base Characters (CC0, assets/characters/base), posed here
# (arms forward, hands together holding a candle, head a little bowed), dressed (a rebozo and long
# skirt, a sarape and sombrero, a child's dress) and fused into one pale silhouette each.

BASE = common.ROOT / "assets" / "characters" / "base"
# Where the hands meet, in the body's own frame before it is turned and scaled (it faces -y): before
# the chest, a little below it.
HANDS_AT = (0.0, -0.27, 1.12)
# Each figure: its base body, its scale, the hands' meeting point once turned to face +x and scaled.
FIGURES = {"dead_woman": ("Superhero_Female_FullBody.gltf", 0.9), "dead_man": ("Superhero_Male_FullBody.gltf", 0.93),
           "dead_child": ("Superhero_Female_FullBody.gltf", 0.62)}
CANDLE_HELD = {n: (-HANDS_AT[1] * k, HANDS_AT[0] * k, HANDS_AT[2] * k) for n, (_, k) in FIGURES.items()}
# The voxels each is fused on, at its own size (m): a child's thin forearms and hands need finer ones.
FIGURE_VOXEL = {"dead_woman": 0.024, "dead_man": 0.024, "dead_child": 0.014}


def _aim(rig, bone, target):
    """A pose bone turned so it points from its head at `target` (the rig's own space)."""
    bpy.context.view_layer.update()
    pb = rig.pose.bones[bone]
    head, tail = pb.head.copy(), pb.tail.copy()
    turn = (tail - head).normalized().rotation_difference((Vector(target) - head).normalized())
    matrix = pb.matrix.copy()
    at = matrix.translation.copy()
    turned_matrix = turn.to_matrix().to_4x4() @ matrix
    turned_matrix.translation = at
    pb.matrix = turned_matrix
    bpy.context.view_layer.update()


def _posed_body(file):
    """A base body imported, posed holding its candle, its pose baked into its mesh; returns the mesh
    object, everything else of the import removed."""
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=str(BASE / file))
    new = [o for o in bpy.data.objects if o not in before]
    rig = next(o for o in new if o.type == "ARMATURE")
    body = max((o for o in new if o.type == "MESH"), key=lambda o: len(o.data.vertices))
    to_rig = rig.matrix_world.inverted()
    hands = to_rig @ Vector(HANDS_AT)

    for sx in ("l", "r"):
        side = 1.0 if sx == "l" else -1.0
        elbow = to_rig @ Vector((side * 0.19, -0.1, 1.17))
        hand = hands + to_rig.to_3x3() @ Vector((side * 0.035, 0.0, 0.0))
        _aim(rig, "upperarm_" + sx, elbow)
        _aim(rig, "lowerarm_" + sx, hand)
        _aim(rig, "hand_" + sx, hands + to_rig.to_3x3() @ Vector((side * 0.01, -0.12, 0.02)))

    head = rig.pose.bones["Head"]
    head.rotation_mode = "XYZ"
    head.rotation_euler.rotate_axis("X", math.radians(14.0))
    bpy.context.view_layer.update()

    with bpy.context.temp_override(active_object=body, object=body, selected_objects=[body],
                                   selected_editable_objects=[body]):
        for mod in list(body.modifiers):
            if mod.type == "ARMATURE":
                bpy.ops.object.modifier_apply(modifier=mod.name)

    world = body.matrix_world.copy()
    body.parent = None
    body.matrix_world = world

    for o in new:
        if o is not body:
            bpy.data.objects.remove(o, do_unlink=True)

    with bpy.context.temp_override(active_object=body, object=body, selected_objects=[body],
                                   selected_editable_objects=[body]):
        bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)

    return body


def _dress(body, garments, name, scale, extras=()):
    """The posed body and its garments fused into one surface, turned to face +x, scaled, set on the
    floor; `extras` (a hat) joined on after."""
    underground_shapes.join(body, garments)
    fused(body, FIGURE_VOXEL[name] / scale)

    for v in body.data.vertices:
        x, y, z = v.co
        v.co = Vector((-y, x, z)) * scale

    low = min(v.co.z for v in body.data.vertices)

    for v in body.data.vertices:
        v.co.z -= low

    if extras:
        for e in extras:
            for v in e.data.vertices:
                x, y, z = v.co
                v.co = Vector((-y, x, z - low / scale)) * scale
        underground_shapes.join(body, list(extras))

    body.name = name
    body.data.name = name
    return body


def _skirt(waist, hem, top=0.98, bottom=0.03):
    """A long skirt (the body's frame, facing -y): a cone from the waist to a hem on the floor."""
    m = common.Mesh("skirt", outward=True)
    turned(m, [(hem, bottom), (hem * 0.93, bottom + 0.25), (waist * 1.25, top - 0.35), (waist, top)], 18, "nahual_black",
           at=(0.0, 0.03, 0.0))
    return m.make()


def _bodice():
    """A loose blouse over the chest and shoulders to the waist (the body's frame)."""
    return chain("bodice", [((0.0, 0.01, 0.93), (0.16, 0.13)), ((0.0, 0.0, 1.18), (0.19, 0.15)),
                            ((0.0, 0.01, 1.38), (0.18, 0.12)), ((0.0, 0.03, 1.47), (0.09, 0.08))], smooth=1)


def dead_woman():
    """A woman in her rebozo, drawn over her head and down her back, her long skirt to the floor,
    her head a little bowed, her hands together at her chest holding her candle."""
    body = _posed_body(FIGURES["dead_woman"][0])
    hood = chain("rebozo", [((0.0, -0.05, 1.68), (0.13, 0.13)), ((0.0, 0.03, 1.6), (0.16, 0.14)),
                            ((0.0, 0.1, 1.42), (0.24, 0.1)), ((0.0, 0.13, 1.15), (0.25, 0.08))], smooth=1)
    ends = [chain("rebozo_end_%d" % sx, [((sx * 0.15, -0.02, 1.45), (0.07, 0.04)), ((sx * 0.18, -0.1, 1.15), (0.07, 0.04)),
                                         ((sx * 0.17, -0.12, 0.88), (0.06, 0.035))], smooth=1) for sx in (-1, 1)]
    # The rebozo crossed over her chest, from her left shoulder to her right hip.
    cross = chain("rebozo_cross", [((0.16, -0.03, 1.46), (0.07, 0.035)), ((0.02, -0.15, 1.24), (0.11, 0.04)),
                                   ((-0.15, -0.11, 0.98), (0.09, 0.035))], smooth=1)
    return _dress(body, [_skirt(0.15, 0.36), _bodice(), hood, cross] + ends, "dead_woman", FIGURES["dead_woman"][1])


def dead_man():
    """A man in white manta, his sarape over his shoulder, his sombrero on, his hands holding his
    candle before his chest."""
    body = _posed_body(FIGURES["dead_man"][0])
    # His manta: a loose shirt to his thighs, loose trousers to his ankles.
    shirt = chain("shirt", [((0.0, 0.02, 0.78), (0.21, 0.17)), ((0.0, 0.01, 1.02), (0.2, 0.16)),
                            ((0.0, 0.0, 1.27), (0.22, 0.16)), ((0.0, 0.02, 1.45), (0.19, 0.13)), ((0.0, 0.04, 1.55), (0.09, 0.08))], smooth=1)
    trousers = [chain("trouser_%d" % sx, [((sx * 0.1, 0.03, 0.92), (0.12, 0.12)), ((sx * 0.12, 0.03, 0.5), (0.105, 0.105)),
                                          ((sx * 0.12, 0.04, 0.14), (0.1, 0.1))], smooth=1) for sx in (-1, 1)]
    # The sarape over his left shoulder, falling before him and behind.
    sarape = chain("sarape", [((0.12, -0.17, 0.95), (0.13, 0.04)), ((0.17, -0.05, 1.5), (0.12, 0.06)),
                              ((0.15, 0.17, 1.02), (0.13, 0.04))], smooth=1)
    m = common.Mesh("sombrero", outward=True)
    # (Seated on his head: its crown wide enough to take it, its brim at his brow.)
    turned(m, [(0.12, 0.0), (0.36, 0.012), (0.38, 0.035), (0.135, 0.05), (0.13, 0.15), (0.1, 0.21), (0.04, 0.225)], 22,
           "nahual_black", at=(0.0, 0.02, 1.6))
    return _dress(body, [shirt, sarape] + trousers, "dead_man", FIGURES["dead_man"][1], [m.make()])


def dead_child():
    """A child in a white dress, holding their candle before them."""
    body = _posed_body(FIGURES["dead_child"][0])
    return _dress(body, [_skirt(0.15, 0.3), _bodice()], "dead_child", FIGURES["dead_child"][1])


def old_hat(m):
    """The old man's palm hat, its brim gone soft, left on the bench."""
    turned(m, [(0.11, 0.0), (0.26, 0.006), (0.265, 0.022), (0.12, 0.03), (0.115, 0.1), (0.09, 0.14), (0.04, 0.155)],
           16, "palm", jitter=0.04)


def build():
    common.reset()
    underground_shapes.rng = rng
    rng.seed(1521)
    nahual_body()
    nahual_head()
    smooth_object("old_hat", old_hat)
    dead_woman()
    dead_man()
    dead_child()


def main():
    build()
    # (Its creature is drawn by its own shader, never from the atlas: gated at gate.CREATURE_SLIVER; the hat
    # is held to the full sliver gate by its kit test.)
    common.export_piece(NAME, ATLAS, SLOTS, out=common.ROOT / "assets" / "eclipse" / "kit", sets_each=True, budget=20000,
                        sliver=gate.CREATURE_SLIVER)


if __name__ == "__main__":
    main()
