"""Shared ground for the wardrobe's Blender scripts (tools/wardrobe).

Where things live, the PS2 budgets every part is held to, and the small
helpers each step uses. Runs inside Blender (bpy); see wardrobe.sh.

The wardrobe builds each kind of NPC as one low-poly PS2 character from the
Quaternius body: docs/superpowers/specs/2026-09-25-npc-ps2-look-design.md.
"""

import hashlib
import json
import math
import shutil
import time
from pathlib import Path

import bmesh
import bpy
from mathutils import Vector  # noqa: F401 (the builders' vectors)
from mathutils.bvhtree import BVHTree

ROOT = Path(__file__).resolve().parents[2]
WARDROBE = ROOT / "assets" / "characters" / "wardrobe"
SOURCE = WARDROBE / "source"
BACKUP = SOURCE / "backup"
QUATERNIUS = {
    "male": ROOT / "assets" / "characters" / "base" / "Superhero_Male_FullBody.gltf",
    "female": ROOT / "assets" / "characters" / "base" / "Superhero_Female_FullBody.gltf",
}

# Colours an albedo may use (PS2's colour-table textures).
PALETTE = 64
# Triangles a whole NPC may use, every worn part together, weapon aside.
NPC_BUDGET = 3000
BUDGETS = {"brute": 3500}
# How close under a garment a body face may be before it counts as hidden.
MARGIN = 0.005


def budget_of(kind):
    return BUDGETS.get(kind, NPC_BUDGET)


def tri_count(obj):
    """Triangles in a mesh object's own data (its modifiers aside)."""
    return sum(len(p.vertices) - 2 for p in obj.data.polygons)


def joints(armature):
    """Where each bone's joint (its head) sits, in the armature's space."""
    return {bone.name: tuple(bone.head_local) for bone in armature.data.bones}


def import_quaternius(body):
    """The Quaternius base character ('male' or 'female') imported into the
    current scene: (armature, body mesh, [the other meshes: eyes, brows]).
    The glTF importer's defaults keep the bones' frames exactly (the boots'
    round trip showed no difference at all)."""
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=str(QUATERNIUS[body]))
    imported = [obj for obj in bpy.data.objects if obj not in before]
    armature = next(obj for obj in imported if obj.type == "ARMATURE")
    meshes = sorted((obj for obj in imported if obj.type == "MESH"), key=lambda obj: len(obj.data.polygons), reverse=True)
    return armature, meshes[0], meshes[1:]


# ---------------------------------------------------------------------------
# Building: the skeleton's places, regions, casting, lofts, weights, UVs
# ---------------------------------------------------------------------------

# Which part of him a bone moves (the dominant bone of a vertex decides).
REGIONS = {
    "head": ("Head", "neck_01"),
    "hand": ("hand_", "index_", "middle_", "pinky_", "ring_", "thumb_"),
    "upper": ("upperarm_", "clavicle_"),
    "lower": ("lowerarm_",),
    "torso": ("spine_01", "spine_02", "spine_03"),
    "pelvis": ("pelvis", "root"),
    "thigh": ("thigh_",),
    "calf": ("calf_",),
    "foot": ("foot_", "ball_"),
}

# The generated parts carry these face attributes (the Data contracts).
FACE_ATTRIBUTES = {"wr_part": "INT", "wr_fabric": "INT", "wr_thickness": "FLOAT", "wr_strip": "BOOLEAN", "wr_dye": "BOOLEAN"}
TRANSFER = "wr_transfer"


def region_of_bone(name):
    for region, prefixes in REGIONS.items():
        if any(name.startswith(prefix) for prefix in prefixes):
            return region

    return "torso"


def point(armature, spec):
    """Where (bone, fraction) is: that far from the bone's head to its tail."""
    bone = armature.data.bones[spec[0]]
    return bone.head_local.lerp(bone.tail_local, spec[1])


def scene_fresh(name):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.context.scene.name = name


def mesh_object(name, bm):
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(obj)
    return obj


def vertex_regions(obj):
    """The region of each vertex: its heaviest bone's."""
    names = {group.index: group.name for group in obj.vertex_groups}
    regions = []

    for vertex in obj.data.vertices:
        best = max(vertex.groups, key=lambda g: g.weight, default=None)
        regions.append(region_of_bone(names[best.group]) if best is not None else "torso")

    return regions


def dominant_bone(obj, vertex):
    names = {group.index: group.name for group in obj.vertex_groups}
    best = max(obj.data.vertices[vertex].groups, key=lambda g: g.weight, default=None)
    return names[best.group] if best is not None else ""


def bvh(objects):
    """One tree over several objects' faces (all at the origin, unrotated)."""
    vertices, polygons = [], []

    for obj in objects:
        start = len(vertices)
        vertices += [vertex.co.copy() for vertex in obj.data.vertices]
        polygons += [tuple(start + i for i in polygon.vertices) for polygon in obj.data.polygons]

    return BVHTree.FromPolygons(vertices, polygons)


def outer_hit(tree, centre, direction, reach=0.8):
    """The outermost surface met coming in from `reach` along `direction`
    toward `centre`: the hit point, or None."""
    direction = direction.normalized()
    hit = tree.ray_cast(centre + direction * reach, -direction, reach)
    return hit[0]


def loft(name, rings, closed=False, cap=None):
    """Quads between consecutive rings (lists of Vectors of one length);
    `closed` joins each ring's ends, `cap` (a point) fans the last ring to it."""
    bm = bmesh.new()
    verts = [[bm.verts.new(p) for p in ring] for ring in rings]
    count = len(rings[0])

    for a, b in zip(verts, verts[1:]):
        for i in range(count if closed else count - 1):
            j = (i + 1) % count
            bm.faces.new((a[i], a[j], b[j], b[i]))

    if cap is not None:
        tip = bm.verts.new(cap)

        for i in range(count if closed else count - 1):
            bm.faces.new((verts[-1][i], verts[-1][(i + 1) % count], tip))

    bm.normal_update()
    return mesh_object(name, bm)


def box(name, centre, x_axis, y_axis, z_axis, size):
    """A box of `size` (along the three axes) about `centre`."""
    bm = bmesh.new()
    hx, hy, hz = (s * 0.5 for s in size)
    corners = [centre + x_axis * sx * hx + y_axis * sy * hy + z_axis * sz * hz
               for sz in (-1, 1) for sy in (-1, 1) for sx in (-1, 1)]
    v = [bm.verts.new(c) for c in corners]

    for face in ((0, 1, 3, 2), (4, 6, 7, 5), (0, 4, 5, 1), (2, 3, 7, 6), (0, 2, 6, 4), (1, 5, 7, 3)):
        bm.faces.new([v[i] for i in face])

    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return mesh_object(name, bm)


def weld(obj):
    """glTF splits vertices along UV seams: the imported body is cut open
    along every one. Welded, it is one skin again (UVs live on the corners,
    so nothing is lost), and smoothing and cutting treat it as one."""
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-5)
    bm.to_mesh(obj.data)
    bm.free()


def keep_positive_x(obj):
    """Cuts `obj` at x = 0 and keeps the +X half (his left: mirrored later)."""
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    geom = list(bm.verts) + list(bm.edges) + list(bm.faces)
    bmesh.ops.bisect_plane(bm, geom=geom, plane_co=(0, 0, 0), plane_no=(1, 0, 0), clear_inner=True)

    for vertex in bm.verts:
        if abs(vertex.co.x) < 1e-4:
            vertex.co.x = 0.0

    bm.to_mesh(obj.data)
    bm.free()


def set_faces(obj, part, fabric, thickness, strip, dye, colour):
    """Every face of `obj` is garment `part` of `fabric`...: the attributes
    the bake, the export and validation read."""
    mesh = obj.data
    values = {"wr_part": part, "wr_fabric": fabric, "wr_thickness": thickness, "wr_strip": strip, "wr_dye": dye}

    for name, kind in FACE_ATTRIBUTES.items():
        attribute = mesh.attributes.get(name) or mesh.attributes.new(name, kind, "FACE")

        for item in attribute.data:
            item.value = values[name]

    base = mesh.color_attributes.get("wr_base") or mesh.color_attributes.new("wr_base", "BYTE_COLOR", "CORNER")

    # The recipes' colours are sRGB; `color` would take them as linear.
    for item in base.data:
        item.color_srgb = (colour[0], colour[1], colour[2], 1.0)

    mesh.color_attributes.active_color = base
    mesh.attributes.render_color_index = mesh.color_attributes.find("wr_base")


def group(obj, name, weight, vertices=None):
    """`vertices` (all if None) of `obj` in vertex group `name` at `weight`."""
    found = obj.vertex_groups.get(name) or obj.vertex_groups.new(name=name)
    found.add(list(range(len(obj.data.vertices))) if vertices is None else list(vertices), weight, "REPLACE")


def select_only(objects, active=None):
    bpy.ops.object.mode_set(mode="OBJECT") if bpy.context.object and bpy.context.object.mode != "OBJECT" else None
    bpy.ops.object.select_all(action="DESELECT")

    for obj in objects:
        obj.select_set(True)

    bpy.context.view_layer.objects.active = active or objects[0]


def unwrap(objects, density):
    """One atlas for all `objects`: each unwrapped, islands evened to one
    texel size, scaled by `density` (name -> weight: more texels where the eye
    goes), and packed together. Each keeps one UV map, named UVMap (the
    Quaternius body's second one would ship as a stray second set)."""
    for obj in objects:
        layers = obj.data.uv_layers

        while len(layers) > 1:
            layers.remove(layers[-1])

        if not layers:
            layers.new(name="UVMap")

        layers[0].name = "UVMap"
        layers.active = layers[0]

    select_only(objects)
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.smart_project(angle_limit=math.radians(66), island_margin=0.01)
    bpy.ops.uv.select_all(action="SELECT")
    bpy.ops.uv.average_islands_scale()
    bpy.ops.object.mode_set(mode="OBJECT")

    for obj in objects:
        weight = density.get(obj.name, 1.0)
        layer = obj.data.uv_layers.active.data

        for loop in layer:
            loop.uv *= weight

    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.uv.select_all(action="SELECT")
    bpy.ops.uv.pack_islands(rotate=True, margin=0.006)
    bpy.ops.object.mode_set(mode="OBJECT")


def mirror(obj):
    """`obj` made whole from its +X half: the halves share their UVs (half
    the texels), and _l/_r weights swap sides."""
    select_only([obj])
    modifier = obj.modifiers.new("Mirror", "MIRROR")
    modifier.use_axis[0] = True
    modifier.use_clip = True
    modifier.use_mirror_merge = True
    modifier.merge_threshold = 0.0005
    modifier.use_mirror_vertex_groups = True
    modifier.use_mirror_u = False
    modifier.use_mirror_v = False
    bpy.ops.object.modifier_apply(modifier=modifier.name)


def hidden_faces(mesh_obj, reach=None):
    """Body faces (wr_part 0) a garment covers: a ray out along the face's
    normal meets a garment face within its thickness + MARGIN (or within
    `reach`, when given)."""
    data = mesh_obj.data

    if "wr_part" not in data.attributes or "wr_thickness" not in data.attributes:
        return []

    parts = [item.value for item in data.attributes["wr_part"].data]
    thickness = [item.value for item in data.attributes["wr_thickness"].data]
    garments = [polygon for polygon in data.polygons if parts[polygon.index] > 0]

    if not garments:
        return []

    tree = BVHTree.FromPolygons([vertex.co for vertex in data.vertices], [tuple(polygon.vertices) for polygon in garments])
    limit = reach if reach is not None else max(thickness[polygon.index] for polygon in garments) + MARGIN
    hidden = []

    for polygon in data.polygons:
        if parts[polygon.index] != 0:
            continue

        hit = tree.ray_cast(polygon.center + polygon.normal * 1e-5, polygon.normal, limit)

        if hit[2] is not None and (reach is not None or hit[3] <= thickness[garments[hit[2]].index] + MARGIN):
            hidden.append(polygon.index)

    return hidden


def to_gltf(v):
    """Blender (Z up, facing -Y) to glTF/Godot model space (Y up, facing +Z)."""
    return [round(v[0], 6), round(v[2], 6), round(-v[1], 6)]


def generated_hash(objects):
    """What the build made, as a fingerprint: a later hand edit changes it."""
    digest = hashlib.sha1()

    for obj in sorted(objects, key=lambda o: o.name):
        digest.update(obj.name.encode())
        names = {group.index: group.name for group in obj.vertex_groups}

        for vertex in obj.data.vertices:
            digest.update(("%.5f %.5f %.5f" % tuple(vertex.co)).encode())

            for g in sorted(vertex.groups, key=lambda g: names[g.group]):
                digest.update(("%s %.4f" % (names[g.group], g.weight)).encode())

    return digest.hexdigest()


def backup(path):
    """A dated copy of `path` in source/backup before it is written over."""
    if not path.exists():
        return

    BACKUP.mkdir(parents=True, exist_ok=True)
    shutil.copy2(path, BACKUP / ("%s-%s%s" % (path.stem, time.strftime("%Y%m%d-%H%M%S"), path.suffix)))


def save(path):
    SOURCE.mkdir(parents=True, exist_ok=True)
    (SOURCE / ".gdignore").touch()
    backup(path)
    bpy.ops.wm.save_as_mainfile(filepath=str(path))


def fail(message):
    print("wardrobe: " + message)
    raise SystemExit(1)


def args():
    """The words after '--' on Blender's command line: (target, options)."""
    import sys
    words = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    target = words[0] if words else ""
    options = {}

    for word in words[1:]:
        if word.startswith("--"):
            key, _, value = word[2:].partition("=")
            options[key] = value if value else True

    return target, options


def dump(value):
    return json.dumps(value)
