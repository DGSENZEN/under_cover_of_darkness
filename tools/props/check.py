"""A built fixture against its rules; nothing written.

    Blender -b assets/props/source/<name>.blend --python check.py -- <name>

  budget   its visible triangles within the recipe's budget
  sockets  a flame at least; a flame needs its corona; a wall fixture its
           mount; a hanging one its hang; a carried one its grip
  slots    every surface a known slot (or that slot glowing)
  density  every face within 64 texels a metre +/- 50% of a 128 px photo

Exits 1 naming the rules broken.
"""

import os
import sys

import bpy

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import common  # noqa: E402
import recipes  # noqa: E402

RULES = ["budget", "sockets", "slots", "density"]


def sockets_in_scene():
    found = {}

    for obj in bpy.context.scene.objects:
        if obj.type == "EMPTY" and obj.name.startswith("socket:"):
            found.setdefault(obj.name.split(":")[1], []).append(obj)

    return found


def _uv_area(mesh, polygon, layer):
    points = [layer.data[i].uv for i in polygon.loop_indices]
    area = 0.0

    for a, b in zip(points, points[1:] + points[:1]):
        area += a.x * b.y - b.x * a.y

    return abs(area) * 0.5


def check(name, recipe):
    meshes = [o for o in bpy.context.scene.objects if o.type == "MESH" and not common.is_collider(o)]
    broken = set()

    if sum(common.tri_count(o) for o in meshes) > recipe["budget"]:
        broken.add("budget")

    sockets = sockets_in_scene()
    needed = ["flame"]

    if "flame" in sockets:
        needed.append("corona")

    needed += {"wall": ["mount"], "hang": ["hang"], "carried": ["grip"]}.get(recipe.get("mount", ""), [])

    if any(socket not in sockets for socket in needed):
        broken.add("sockets")

    for obj in meshes:
        for material in obj.data.materials:
            if material is None or material.name.removesuffix("_glow") not in recipes.SLOTS:
                broken.add("slots")

    low = common.PX_PER_M * (1.0 - common.DENSITY_BAND)
    high = common.PX_PER_M * (1.0 + common.DENSITY_BAND)

    for obj in meshes:
        mesh = obj.data
        mesh.update()
        layer = mesh.uv_layers.active

        if layer is None:
            broken.add("density")
            continue

        for polygon in mesh.polygons:
            if polygon.area < 1e-6:
                continue

            density = common.face_density(polygon.area, _uv_area(mesh, polygon, layer))

            if density < low or density > high:
                broken.add("density")
                break

    return [rule for rule in RULES if rule in broken]


def main(argv):
    name = argv[0] if argv else bpy.context.scene.get("fixture", "")

    if name not in recipes.FIXTURES:
        common.fail("no fixture called '%s'" % name)

    broken = check(name, recipes.FIXTURES[name])
    tris = sum(common.tri_count(o) for o in bpy.context.scene.objects if o.type == "MESH" and not common.is_collider(o))

    if broken:
        common.fail("%s breaks %s (%d triangles, budget %d)" % (name, ", ".join(broken), tris, recipes.FIXTURES[name]["budget"]))

    print("props: %s is clean (%d of %d triangles)" % (name, tris, recipes.FIXTURES[name]["budget"]))


if __name__ == "__main__":
    main(sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else [])
