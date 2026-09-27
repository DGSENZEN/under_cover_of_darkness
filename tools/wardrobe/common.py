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
from mathutils.kdtree import KDTree

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
    """The region of each vertex: its heaviest bone's (TRANSFER, the mark on
    a vertex whose weights are copied later, is no bone)."""
    names = {group.index: group.name for group in obj.vertex_groups}
    regions = []

    for vertex in obj.data.vertices:
        best = max((g for g in vertex.groups if names[g.group] != TRANSFER), key=lambda g: g.weight, default=None)
        regions.append(region_of_bone(names[best.group]) if best is not None else "torso")

    return regions


def dominant_bone(obj, vertex):
    names = {group.index: group.name for group in obj.vertex_groups}
    best = max(obj.data.vertices[vertex].groups, key=lambda g: g.weight, default=None)
    return names[best.group] if best is not None else ""


def bvh(objects, keep=None):
    """One tree over several objects' faces (all at the origin, unrotated);
    only those `keep(obj, polygon)` passes, given."""
    vertices, polygons = [], []

    for obj in objects:
        start = len(vertices)
        vertices += [vertex.co.copy() for vertex in obj.data.vertices]
        polygons += [tuple(start + i for i in polygon.vertices) for polygon in obj.data.polygons
                     if keep is None or keep(obj, polygon)]

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


def set_faces(obj, part, fabric, thickness, strip, dye, colour, faces=None):
    """Every face of `obj` (or those indexed in `faces`) is garment `part` of
    `fabric`...: the attributes the bake, the export and validation read."""
    mesh = obj.data
    values = {"wr_part": part, "wr_fabric": fabric, "wr_thickness": thickness, "wr_strip": strip, "wr_dye": dye}
    chosen = range(len(mesh.polygons)) if faces is None else list(faces)

    for name, kind in FACE_ATTRIBUTES.items():
        attribute = mesh.attributes.get(name) or mesh.attributes.new(name, kind, "FACE")

        for index in chosen:
            attribute.data[index].value = values[name]

    base = mesh.color_attributes.get("wr_base") or mesh.color_attributes.new("wr_base", "BYTE_COLOR", "CORNER")

    # The recipes' colours are sRGB; `color` would take them as linear.
    for index in chosen:
        for loop in mesh.polygons[index].loop_indices:
            base.data[loop].color_srgb = (colour[0], colour[1], colour[2], 1.0)

    mesh.color_attributes.active_color = base
    mesh.attributes.render_color_index = mesh.color_attributes.find("wr_base")


def smooth(obj, crease):
    """Drawn smooth (Gouraud, as the PS2 drew), hard only where its faces
    meet at more than `crease` degrees; the normals it came with (the
    imported body's, stale once it is cut and pushed about) dropped."""
    select_only([obj])

    if obj.data.has_custom_normals:
        bpy.ops.mesh.customdata_custom_splitnormals_clear()

    obj.data.shade_smooth()
    obj.data.set_sharp_from_angle(angle=math.radians(crease))


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


def hidden_faces(mesh_obj, reach=None, bare=None):
    """Body faces (wr_part 0) a garment covers: a ray out along the face's
    normal meets a garment face within its thickness + MARGIN (or within
    `reach`, when given). A face of a limb his recipe leaves `bare`
    (common.REGIONS) counts only under a garment riding that limb (a bracer,
    his mittens, a pauldron; a garment not yet weighted rides what it
    covers), and only wholly under such garments (at its centre and near
    each corner, within their thickness + MARGIN, even with `reach`): one
    riding his trunk
    (a mantle on his collarbones over his upper arm, as he stands in the
    rest pose) stays put when the limb moves, and cutting the limb there, or
    a big face half out of a bracer, leaves a hole in it."""
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
    bones = face_bones(mesh_obj) if bare else None
    hidden = []

    def under(point, normal, limb):
        """A garment riding `limb` (or not yet weighted) lies on `point`."""
        found = tree.ray_cast(point + normal * 1e-5, normal, limit)

        if found[2] is None or found[3] > thickness[garments[found[2]].index] + MARGIN:
            return False

        over = bones[garments[found[2]].index]
        return not over or limb_of(over) == limb

    for polygon in data.polygons:
        if parts[polygon.index] != 0:
            continue

        hit = tree.ray_cast(polygon.center + polygon.normal * 1e-5, polygon.normal, limit)

        if hit[2] is None:
            continue

        near = hit[3] <= thickness[garments[hit[2]].index] + MARGIN

        if reach is None and not near:
            continue

        if bones is not None and region_of_bone(bones[polygon.index]) in bare:
            limb, over = limb_of(bones[polygon.index]), bones[garments[hit[2]].index]

            if limb is not None and (not near or over and limb_of(over) != limb or not all(
                    under(polygon.center.lerp(data.vertices[v].co, 0.9), polygon.normal, limb) for v in polygon.vertices)):
                continue

        hidden.append(polygon.index)

    return hidden


def limb_of(bone):
    """The limb a bone moves ("arm_l", "leg_r"...: an arm from the shoulder
    down, not its collarbone), or None for his trunk and head."""
    for limb, prefixes in (("arm", ("upperarm_", "lowerarm_", "hand_", "index_", "middle_", "pinky_", "ring_", "thumb_")),
                           ("leg", ("thigh_", "calf_", "foot_", "ball_"))):
        if bone.startswith(prefixes):
            return limb + bone[-2:]

    return None


def face_bones(obj):
    """Each face's bone: the commonest of its vertices' heaviest bones (ties
    go the same way on every run); "" where none is weighted yet (a part
    whose weights are copied later, TRANSFER, has none of its own)."""
    names = {group.index: group.name for group in obj.vertex_groups}
    heaviest = []

    for vertex in obj.data.vertices:
        best = max((g for g in vertex.groups if names[g.group] != TRANSFER), key=lambda g: g.weight, default=None)
        heaviest.append(names[best.group] if best is not None else "")

    out = []

    for polygon in obj.data.polygons:
        values = [heaviest[i] for i in polygon.vertices]
        out.append(max(sorted(set(values)), key=values.count))

    return out


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


# Each body's heads and hair in their own file, on their own skeleton: a
# target names its folder and body ("heads" is the male body's heads).
PART_TARGETS = {"heads": ("heads", "male"), "heads_female": ("heads", "female"),
                "hair": ("hair", "male"), "hair_female": ("hair", "female")}


def part_target(folder, body):
    """The target (and source file) of `folder`'s parts for `body`."""
    target = next((target for target, made in PART_TARGETS.items() if made == (folder, body)), None)

    if target is None:
        fail("no %s for the %s body" % (folder, body))

    return target


def heaviest_combination(options, read):
    """The most triangles a kind's options can put on a man besides his
    outfit: over each headgear set, his heaviest face, his heaviest hair
    unless a piece of the set hides it, his heaviest beard unless one
    forbids it, and the set. `read(relative)` gives a part's exported JSON
    (heads/<face>.json, hair/<style>.json, headgear/<piece>.json) or None;
    "" is none. None if any part named has no JSON yet."""
    def most(folder, names):
        found = [read("%s/%s.json" % (folder, name)) for name in names if name != ""]
        return None if any(f is None for f in found) else max((f["triangles"] for f in found), default=0)

    face, hair, beard = most("heads", options["faces"]), most("hair", options.get("hair", [])), most("hair", options.get("beards", []))
    top = 0

    for pieces in options.get("headgear", [[]]) or [[]]:
        gear = [read("headgear/%s.json" % piece) for piece in pieces]

        if None in (face, hair, beard) or any(g is None for g in gear):
            return None

        hides = any(g.get("hides_hair", False) for g in gear)
        forbids = any(not g.get("allows_beard", True) for g in gear)
        top = max(top, face + (0 if hides else hair) + (0 if forbids else beard) + sum(g["triangles"] for g in gear))

    return top


def part_table(folder):
    """The recipes of a folder's parts: recipes.HEADS or recipes.HAIR."""
    import recipes

    return recipes.HEADS if folder == "heads" else recipes.HAIR


def parts_of(table, body):
    """The names in `table` (recipes.HEADS or recipes.HAIR) made for `body`
    (an entry naming none is the male body's), in the table's order."""
    return [name for name, entry in table.items() if entry.get("body", "male") == body]


# How far round a garment's open edge at his neck its faces are drawn from
# both sides (open_necklines), and how far from his neck's middle an edge
# counts as round it.
NECKLINE = 0.06
NECK_REACH = 0.14


def open_necklines(outfit, armature):
    """A garment's faces round his neckline drawn from both sides, as its
    strips are: a garment stands off his neck, and from three-quarters the
    far side of its opening shows its inside, which a closed part culls:
    the background showed through beside the bare-hat watchman's neck (his
    tabard), the arms master's (his doublet) and the duelist's. The faces
    with a vertex within NECKLINE of a garment's open edge within NECK_REACH
    of his neck's middle, over the foot of his neck. Idempotent (export
    applies it to every kind, the watchman's batch 0 outfit too); returns
    how many faces it opened."""
    neck = armature.data.bones["neck_01"].head_local
    data = outfit.data
    parts = data.attributes["wr_part"].data
    strips = data.attributes["wr_strip"].data
    bm = bmesh.new()
    bm.from_mesh(data)
    bm.faces.ensure_lookup_table()
    edge = []

    for e in bm.edges:
        if not e.is_boundary or any(parts[f.index].value == 0 for f in e.link_faces):
            continue

        mid = (e.verts[0].co + e.verts[1].co) * 0.5

        if mid.z > neck.z - 0.1 and math.hypot(mid.x, mid.y - neck.y) < NECK_REACH:
            edge += [e.verts[0].co.copy(), e.verts[1].co.copy()]

    opened = 0

    if edge:
        tree = KDTree(len(edge))

        for i, p in enumerate(edge):
            tree.insert(p, i)

        tree.balance()

        for f in bm.faces:
            if parts[f.index].value > 0 and not strips[f.index].value \
                    and any(tree.find(v.co)[2] < NECKLINE for v in f.verts):
                strips[f.index].value = True
                data.polygons[f.index].material_index = 1
                opened += 1

    bm.free()
    return opened


# Under this height a head of the body has no open edge but its neck's.
NECK_EDGE_BELOW = {"male": 1.6, "female": 1.54}

# Where his head meets his body: one seam round the foot of his neck
# (cut_at_neck), the head above it, his body and the shells that reach
# his neck below, each cut on it and laid on the full body's surface there.
# Its heights in front, at his sides and behind are where the full body's
# bone weights part (between the head region's lowest vertex and the rest's
# highest), and it runs smooth between them. Cut at the bone weights and
# decimated apart, head and collar each ended in a row of teeth, and his
# neck looked sawn off.
NECK_CUT = {"male": {"front": 1.515, "side": 1.562, "back": 1.537},
            "female": {"front": 1.477, "side": 1.491, "back": 1.493}}


def neck_cut_z(body, co, neck_y):
    """The seam's height at co's bearing round his neck (its middle at y =
    neck_y, on x = 0): a0 + a1 cos(t) + a2 cos(2t), t 0 in front, through
    NECK_CUT's three heights."""
    cut = NECK_CUT[body]
    t = math.atan2(abs(co.x), -(co.y - neck_y))
    a1 = (cut["front"] - cut["back"]) * 0.5
    a0 = ((cut["front"] + cut["back"]) * 0.5 + cut["side"]) * 0.5
    a2 = (cut["front"] + cut["back"]) * 0.5 - a0
    return a0 + a1 * math.cos(t) + a2 * math.cos(2.0 * t)


# The seam's points round his neck: every 360 / NECK_RING degrees, in front
# (0) and behind (180) among them. Head and body are cut apart, so each
# keeps exactly these on its edge and no others: laid on the full body, the
# two edges are one line (with their own points, a long edge of one passed
# inside a point of the other and left a slit).
NECK_RING = 24


def bearing(co, neck_y):
    """Degrees round his neck from the front, positive to his left (+x)."""
    return math.degrees(math.atan2(co.x, -(co.y - neck_y)))


def cut_at_neck(obj, body, neck_y, keep_above, tree, snap=0.002, half=False):
    """`obj` cut on the seam round his neck (NECK_CUT): what lies above it
    kept (`keep_above`, a head) or what lies below (his body). Bent flat
    (each vertex lowered by the seam's height at its bearing), bisected,
    and bent back: a vertex within `snap` of the seam goes onto it (no
    sliver of a face beside the cut). Its edge then has the seam's points
    (NECK_RING) and only those: each edge split where it passes one, each
    other vertex on it merged into its neighbour along it; every point laid
    on the full body's surface (`tree`), out from his neck's middle. On a
    `half` (his left, mirrored later), a face the merging laid in the mirror
    plane goes: a wall inside him once mirrored. Returns the seam's vertex
    indices."""
    step = 360.0 / NECK_RING
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    # (Vertices at one place welded first: a decimated half left some on
    # its mirror plane, and each copy got a seam of its own.)
    bmesh.ops.remove_doubles(bm, verts=bm.verts[:], dist=1e-6)

    for vertex in bm.verts:
        vertex.co.z -= neck_cut_z(body, vertex.co, neck_y)

    geom = list(bm.verts) + list(bm.edges) + list(bm.faces)
    bmesh.ops.bisect_plane(bm, geom=geom, dist=snap, plane_co=(0.0, 0.0, 0.0), plane_no=(0.0, 0.0, 1.0),
                           clear_inner=keep_above, clear_outer=not keep_above)
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context="VERTS")
    seam = {vertex for vertex in bm.verts if abs(vertex.co.z) <= snap and vertex.is_boundary}

    for vertex in seam:
        vertex.co.z = 0.0

    def along(e):
        return e.is_boundary and all(v in seam for v in e.verts)

    def point(v):
        """The seam point v is (a whole number of steps round), or None."""
        k = round(bearing(v.co, neck_y) / step)
        return k if abs(bearing(v.co, neck_y) - k * step) < 0.01 else None

    # Split where an edge passes a point (its bearings unwrapped behind him).
    for e in [e for e in bm.edges if along(e)]:
        a, b = e.verts
        ba, bb = bearing(a.co, neck_y), bearing(b.co, neck_y)

        if abs(bb - ba) > 180.0:
            bb += 360.0 if bb < ba else -360.0

        lo, hi = min(ba, bb), max(ba, bb)
        ks = [k for k in range(math.ceil(lo / step - 1e-3), math.floor(hi / step + 1e-3) + 1)
              if lo + 0.5 < k * step < hi - 0.5]

        # (Farthest first along a to b: each split leaves `e` from a.)
        for k in sorted(ks, key=lambda k: -abs(k * step - ba)):
            c = math.radians(k * step)
            d = Vector((math.sin(c), -math.cos(c)))
            o = Vector((0.0, neck_y))
            pa, pb = a.co.xy - o, e.other_vert(a).co.xy - o
            den = (pb - pa).cross(d)
            fac = min(max(-pa.cross(d) / den, 0.0), 1.0) if abs(den) > 1e-12 else 0.5
            _, made = bmesh.utils.edge_split(e, a, fac)
            # At the point's bearing (and laid on the body below).
            r = (made.co.xy - o).length
            made.co = Vector((o.x + d.x * r, o.y + d.y * r, 0.0))
            seam.add(made)
            e = next(x for x in a.link_edges if made in x.verts)

    # Every other vertex on it merged into its neighbour along it, the
    # nearer by bearing, until only points are left (round from his front,
    # the same way every build: a set's order is not).
    while True:
        loose = [v for v in seam if v.is_valid and point(v) is None]

        if not loose:
            break

        v = min(loose, key=lambda v: (bearing(v.co, neck_y), v.co.x, v.co.y))
        neighbours = [e.other_vert(v) for e in v.link_edges if along(e)]

        if not neighbours:
            seam.discard(v)
            continue

        target = min(neighbours, key=lambda n: abs((bearing(n.co, neck_y) - bearing(v.co, neck_y) + 180.0) % 360.0 - 180.0))
        bmesh.ops.weld_verts(bm, targetmap={v: target})
        seam.discard(v)

    bmesh.ops.dissolve_degenerate(bm, dist=1e-6, edges=bm.edges[:])

    if half:
        bmesh.ops.delete(bm, geom=[f for f in bm.faces if all(v.co.x == 0.0 for v in f.verts)], context="FACES")
        bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context="VERTS")

    seam = {v for v in seam if v.is_valid}

    for vertex in bm.verts:
        vertex.co.z += neck_cut_z(body, vertex.co, neck_y)

    for vertex in seam:
        c = math.radians(point(vertex) * step)
        d = Vector((math.sin(c), -math.cos(c), 0.0))
        z = neck_cut_z(body, Vector((d.x, neck_y + d.y, 0.0)), neck_y)
        hit = tree.ray_cast(Vector((0.0, neck_y, z)), d, 0.4)

        if hit[0] is not None:
            vertex.co = Vector((0.0 if abs(d.x) < 1e-9 else hit[0].x, hit[0].y, z))

    bm.verts.index_update()
    indices = [vertex.index for vertex in seam if vertex.is_valid]
    bm.to_mesh(obj.data)
    bm.free()
    return indices


def part_limit(folder, name):
    """How many triangles a part may have (spec §5: ~400 a head; hair,
    beard and headgear ~600 together): a head 450; headgear its recipe's
    `limit` (the coif 240), else 300; hair 220, a beard 150."""
    import recipes

    if folder == "heads":
        return 450

    if folder == "hair":
        return 150 if recipes.HAIR.get(name, {}).get("kind") == "beard" else 220

    return recipes.HEADGEAR.get(name, {}).get("limit", 300)


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
