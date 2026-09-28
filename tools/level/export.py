"""Exports the open level .blend for Godot, if it passes the check: its
shading baked into vertex colours (bake: shade.py), a glTF
of each sector's pieces (assets/level/<level>/<sector>.glb) and the level's
manifest (<level>.json: its sectors, every collider as an oriented box with
its surface, every marker with its properties and defaults), plus the
marker schema (markers.json). scripts/Level/LevelLoader.gd reads them.

    Blender -b assets/level/source/<level>.blend --python tools/level/export.py [-- stage2]
"""

import json
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import bmesh  # noqa: E402
import bpy  # noqa: E402
from mathutils import Vector  # noqa: E402
from mathutils.bvhtree import BVHTree  # noqa: E402

import check as checker  # noqa: E402
import common  # noqa: E402
import geo  # noqa: E402
import kit_recipes  # noqa: E402
import markers as schema  # noqa: E402
import shade  # noqa: E402

# The bake (shade.py): the families whose faces are cut finer (to about
# GRADE_EDGE) so the shading grades across them; occlusion measured with
# AO_RAYS rays out to AO_REACH (m); pieces drawn unlit keep no colours.
GRADED = ("wall", "curtain", "floor", "stair", "column", "roof", "quay", "vault")
GRADE_EDGE = 1.0
AO_RAYS = 12
AO_REACH = 1.2
UNLIT = ("stained_glass", "stained_glass_small")

IMPORT = """[remap]

importer="scene"
importer_version=1
type="PackedScene"

[deps]

source_file="{source}"

[params]

nodes/root_type=""
nodes/root_name=""
nodes/apply_root_scale=true
nodes/root_scale=1.0
nodes/import_as_skeleton_bones=false
nodes/use_name_suffixes=false
nodes/use_node_type_suffixes=false
meshes/ensure_tangents=false
meshes/generate_lods=false
meshes/create_shadow_meshes=true
meshes/light_baking=1
meshes/lightmap_texel_size=0.2
meshes/force_disable_compression=false
skins/use_named_skins=true
animation/import=false
import_script/path=""
materials/extract=0
_subresources={{}}
gltf/naming_version=2
gltf/embedded_image_handling=1
"""


def rounded(v, digits=4):
    return [round(float(x), digits) for x in v]


def manifest(data):
    colliders = []

    for p in data["pieces"]:
        recipe = kit_recipes.PIECES[p["piece"]]

        for box in geo.piece_boxes(recipe, p["position"], p["basis"]):
            colliders.append({"sector": p["sector"], "centre": rounded(box.centre), "basis": [rounded(r) for r in box.basis],
                              "size": rounded([h * 2.0 for h in box.half]), "surface": box.surface})

    sockets = []

    for p in data["pieces"]:
        for kind, points in kit_recipes.PIECES[p["piece"]].get("sockets", {}).items():
            for point in points:
                sockets.append({"piece": p["name"], "kind": kind, "sector": p["sector"],
                                "position": rounded(geo.add(p["position"], geo.apply(p["basis"], point)))})

    found = []

    for m in data["markers"]:
        m = schema.with_defaults(m)
        found.append({"name": m["name"], "ucd": m["ucd"], "sector": m["sector"], "position": rounded(m["position"]),
                      "basis": [rounded(r) for r in m["basis"]], "size": rounded(m["size"]) if m.get("size") else None,
                      "props": m["props"]})

    return {"level": data["level"], "sectors": data["sectors"], "colliders": colliders, "markers": found, "sockets": sockets,
            "pieces": len(data["pieces"])}


def _subdivide(mesh):
    """Its long edges halved until none is much over GRADE_EDGE."""
    bm = bmesh.new()
    bm.from_mesh(mesh)

    for _ in range(4):
        long_edges = [e for e in bm.edges if e.calc_length() > GRADE_EDGE * 1.5]

        if not long_edges:
            break

        bmesh.ops.subdivide_edges(bm, edges=long_edges, cuts=1, use_grid_fill=True)

    bm.to_mesh(mesh)
    bm.free()


def _hemisphere(count):
    """`count` directions over the +z hemisphere, cosine-spread (a fixed set)."""
    out = []

    for i in range(count):
        u = (i + 0.5) / count
        r = math.sqrt(u)
        angle = i * 2.399963
        out.append(Vector((r * math.cos(angle), r * math.sin(angle), math.sqrt(max(0.0, 1.0 - u)))))

    return out


def _occlusion(tree, point, normal, rays):
    """How shut in `point` is (0..1): its rays that hit within AO_REACH,
    nearer counting more."""
    tangent = normal.orthogonal().normalized()
    bitangent = normal.cross(tangent)
    start = point + normal * 0.02
    shut = 0.0

    for d in rays:
        direction = tangent * d.x + bitangent * d.y + normal * d.z
        hit = tree.ray_cast(start, direction, AO_REACH)

        if hit[0] is not None:
            shut += 1.0 - hit[3] / AO_REACH

    return shut / len(rays)


def bake(data):
    """The level's shading into its pieces' vertex colours (shade.py): each
    piece its own copy of its mesh (the .blend is not saved after), the big
    faces cut finer, occlusion measured against the whole level."""
    objects = [o for o in bpy.context.scene.objects if o.type == "MESH" and "kit_piece" in o.keys()]

    for obj in objects:
        obj.data = obj.data.copy()

        if kit_recipes.PIECES[obj["kit_piece"]]["family"] in GRADED:
            _subdivide(obj.data)

    verts, polys = [], []

    for obj in objects:
        base = len(verts)
        verts.extend([obj.matrix_world @ v.co for v in obj.data.vertices])
        polys.extend([[base + i for i in p.vertices] for p in obj.data.polygons])

    tree = BVHTree.FromPolygons(verts, polys)
    rays = _hemisphere(AO_RAYS)
    flames = [{"kind": m["props"].get("kind"), "position": m["position"]} for m in data["markers"] if m["ucd"] == "light"]
    memo = {}

    for obj in objects:
        mesh = obj.data

        if any(m is not None and m.name in UNLIT for m in mesh.materials):
            continue

        attribute = mesh.color_attributes.new("Col", "FLOAT_COLOR", "CORNER")
        to_world = obj.matrix_world
        turn = to_world.to_3x3()

        for polygon in mesh.polygons:
            normal = (turn @ polygon.normal).normalized()

            for loop in polygon.loop_indices:
                point = to_world @ mesh.vertices[mesh.loops[loop].vertex_index].co
                key = (round(point.x, 2), round(point.y, 2), round(point.z, 2), round(normal.x, 1), round(normal.y, 1), round(normal.z, 1))

                if key not in memo:
                    occlusion = _occlusion(tree, point, normal, rays)
                    memo[key] = shade.colour(geo.from_blender(list(point)), geo.from_blender(list(normal)), occlusion, flames)

                attribute.data[loop].color = (*memo[key], 1.0)

        mesh.color_attributes.active_color = attribute

    print("level: shading baked into %d pieces (%d corners measured)" % (len(objects), len(memo)))


def export(stage="stage1"):
    data, problems = checker.check(stage)

    if problems:
        common.fail("not exported: %d problems" % len(problems))

    level = data["level"]
    out = common.out_dir(level)
    out.mkdir(parents=True, exist_ok=True)
    bake(data)

    for sector in data["sectors"]:
        names = {p["name"] for p in data["pieces"] if p["sector"] == sector}

        if not names:
            continue

        bpy.ops.object.select_all(action="DESELECT")

        for obj in bpy.context.scene.objects:
            if obj.name in names:
                obj.select_set(True)

        path = out / (sector + ".glb")
        bpy.ops.export_scene.gltf(
            filepath=str(path), export_format="GLB", use_selection=True, export_materials="EXPORT",
            export_image_format="NONE", export_vertex_color="ACTIVE", export_yup=True, export_apply=True,
            export_texcoords=True, export_normals=True, export_animations=False, export_skins=False, export_extras=False,
        )
        settings = path.with_suffix(".glb.import")

        if not settings.exists():
            settings.write_text(IMPORT.format(source="res://" + str(path.relative_to(common.ROOT)).replace(os.sep, "/")))

    (out / (level + ".json")).write_text(json.dumps(manifest(data), indent=None, separators=(",", ":")) + "\n")
    schema.write_json(out / "markers.json")
    print("level: exported %s: %d sectors -> %s" % (level, len(data["sectors"]), out.relative_to(common.ROOT)))


if __name__ == "__main__":
    args = common.argv()
    export(args[0] if args else "stage1")
