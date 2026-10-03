"""A fixture's recipe (recipes.py) made into assets/props/source/<name>.blend.

    Blender -b --factory-startup --python build.py -- <fixture>

Every part is its own mesh object, named after the part, built in place (its
object transform stays identity, so what the exporter and the sockets see is
what the recipe says). Surfaces are named after their slots ("iron",
"horn_glow" ...). UVs are box-projected at a fixed texel density (64 texels
a metre of a 128 px photo), so every photo tiles at the same scale on every
fixture. Sockets are empties named "socket:<name>:<index>". Colliders are
boxes named "<name>-colonly" (Godot makes them static bodies).
"""

import math
import os
import random
import sys

import bmesh
import bpy
from mathutils import Euler, Matrix, Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import common  # noqa: E402
import recipes  # noqa: E402

# Faces meeting sharper than this get a hard edge; softer ones shade smooth.
SHARP = math.radians(50.0)


# The parts: each returns a bmesh and the slots of its material indices

def _circle(radius, segments, z=0.0, turn=0.0):
    return [Vector((radius * math.cos(turn + math.tau * i / segments), radius * math.sin(turn + math.tau * i / segments), z)) for i in range(segments)]


def _loft(bm, rings, cap_start=True, cap_end=True, material=0):
    """Faces between consecutive rings of vertices (a ring of one is a pole)."""
    for a, b in zip(rings, rings[1:]):
        if len(a) == 1 and len(b) == 1:
            continue

        count = max(len(a), len(b))

        for i in range(count):
            j = (i + 1) % count

            if len(a) == 1:
                face = bm.faces.new((a[0], b[j], b[i]))
            elif len(b) == 1:
                face = bm.faces.new((a[i], a[j], b[0]))
            else:
                face = bm.faces.new((a[i], a[j], b[j], b[i]))

            face.material_index = material
            face.smooth = True

    for ring, wanted in ((rings[0], cap_start), (rings[-1], cap_end)):
        if wanted and len(ring) > 2:
            face = bm.faces.new(ring)
            face.material_index = material


def lathe(part, noise=0.0):
    """A profile [(radius, z)...] turned round the Z axis."""
    bm = bmesh.new()
    segments = part.get("segments", 8)
    rng = random.Random(part.get("seed", 0))
    rings = []

    for radius, z in part["profile"]:
        if radius <= 1e-6:
            rings.append([bm.verts.new((0.0, 0.0, z))])
        else:
            ring = []

            for point in _circle(radius, segments, z):
                if noise > 0.0:
                    point = point * (1.0 + rng.uniform(-1.0, 1.0) * noise / radius)

                ring.append(bm.verts.new(point))

            rings.append(ring)

    _loft(bm, rings)
    return bm, [part["slot"]]


def blob(part):
    """A lathe with its radius roughened: tow heads, wax, drips, coal beds."""
    return lathe(part, noise=part.get("noise", 0.004))


def tube(part):
    """A bar swept along points [(x, y, z)...]: square with 4 sides."""
    bm = bmesh.new()
    points = [Vector(p) for p in part["points"]]
    sides = part.get("sides", 6)
    radius = part["radius"]
    rings = []
    normal = None

    for i, point in enumerate(points):
        ahead = (points[min(i + 1, len(points) - 1)] - points[max(i - 1, 0)]).normalized()

        if normal is None:
            # Any direction square to the first stretch, then carried along.
            helper = Vector((0.0, 0.0, 1.0)) if abs(ahead.z) < 0.9 else Vector((1.0, 0.0, 0.0))
            normal = ahead.cross(helper).normalized()
        else:
            normal = (normal - ahead * normal.dot(ahead)).normalized()

        binormal = ahead.cross(normal).normalized()
        ring = []

        for k in range(sides):
            angle = math.tau * k / sides + (math.pi / sides if sides == 4 else 0.0)
            ring.append(bm.verts.new(point + (normal * math.cos(angle) + binormal * math.sin(angle)) * radius))

        rings.append(ring)

    _loft(bm, rings)

    if sides <= 4:
        for face in bm.faces:
            face.smooth = False

    return bm, [part["slot"]]


def box(part):
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    sx, sy, sz = part["size"]

    for vertex in bm.verts:
        vertex.co = Vector((vertex.co.x * sx, vertex.co.y * sy, vertex.co.z * sz))

    return bm, [part["slot"]]


def _torus(bm, major, minor, sides, segments, stretch=0.0, material=0):
    rings = []

    for i in range(segments):
        angle = math.tau * i / segments
        out = Vector((math.cos(angle), math.sin(angle), 0.0))
        centre = out * major + Vector((stretch * (1.0 if out.x >= 0 else -1.0), 0.0, 0.0))
        ring = []

        for k in range(sides):
            a = math.tau * k / sides
            ring.append(bm.verts.new(centre + out * math.cos(a) * minor + Vector((0.0, 0.0, math.sin(a) * minor))))

        rings.append(ring)

    for i in range(segments):
        a, b = rings[i], rings[(i + 1) % segments]

        for k in range(sides):
            face = bm.faces.new((a[k], b[k], b[(k + 1) % sides], a[(k + 1) % sides]))
            face.material_index = material
            face.smooth = True


def ring(part):
    """A ring of `radius` round the chosen axis (its hole along that axis)."""
    bm = bmesh.new()
    _torus(bm, part["radius"], part["thickness"] * 0.5, part.get("sides", 4), part.get("segments", 8))
    turn = {"Z": Matrix.Identity(3), "X": Matrix.Rotation(math.pi * 0.5, 3, "Y"), "Y": Matrix.Rotation(math.pi * 0.5, 3, "X")}[part.get("axis", "Z")]

    for vertex in bm.verts:
        vertex.co = turn @ vertex.co

    return bm, [part["slot"]]


def chain(part):
    """Links from `start` to `end`, each turned a quarter from the last."""
    bm = bmesh.new()
    start, end = Vector(part["start"]), Vector(part["end"])
    length, width, wire = part.get("link", (0.05, 0.028, 0.006))
    pitch = max(length - 2.0 * wire, 0.005)
    span = (end - start).length
    count = max(int(span / pitch), 1)
    axis = (end - start).normalized() if span > 1e-6 else Vector((0.0, 0.0, -1.0))
    align = Vector((0.0, 0.0, 1.0)).rotation_difference(axis).to_matrix()

    for i in range(count):
        link = bmesh.new()
        _torus(link, width * 0.5 - wire * 0.5, wire * 0.5, 3, 6, stretch=(length - width) * 0.5)
        # Lying along Z, every other one turned a quarter round it.
        stand = Matrix.Rotation(math.pi * 0.5, 3, "Y")
        twist = Matrix.Rotation(math.pi * 0.5 * (i % 2), 3, "Z")

        for vertex in link.verts:
            vertex.co = align @ (twist @ (stand @ vertex.co)) + start + axis * (pitch * (i + 0.5))

        _merge(bm, link)

    return bm, [part["slot"]]


def stones(part):
    """A ring of rough stones round the Z axis, sitting on z = 0."""
    bm = bmesh.new()
    rng = random.Random(part.get("seed", 0))
    size = Vector(part["size"])
    jitter = part.get("jitter", 0.2)

    for i in range(part["count"]):
        stone = bmesh.new()
        bmesh.ops.create_cube(stone, size=1.0)
        scale = Vector((size.x * (1.0 + rng.uniform(-jitter, jitter)), size.y * (1.0 + rng.uniform(-jitter, jitter)), size.z * (1.0 + rng.uniform(-jitter, jitter))))
        angle = math.tau * i / part["count"] + rng.uniform(-0.1, 0.1)
        turn = Matrix.Rotation(angle + rng.uniform(-0.3, 0.3), 3, "Z")

        for vertex in stone.verts:
            rough = Vector((rng.uniform(-1, 1), rng.uniform(-1, 1), rng.uniform(-1, 1))) * jitter * 0.25
            local = Vector((vertex.co.x * scale.x, vertex.co.y * scale.y, vertex.co.z * scale.z)) + Vector((rough.x * scale.x, rough.y * scale.y, rough.z * scale.z))
            vertex.co = turn @ local + Vector((math.cos(angle), math.sin(angle), 0.0)) * part["radius"] + Vector((0.0, 0.0, scale.z * 0.5))

        _merge(bm, stone)

    return bm, [part["slot"]]


def logs(part):
    """Logs [(from, to, radius)...], their cut ends charred."""
    bm = bmesh.new()
    sides = part.get("sides", 6)

    for start, end, radius in part["logs"]:
        start, end = Vector(start), Vector(end)
        axis = (end - start).normalized()
        align = Vector((0.0, 0.0, 1.0)).rotation_difference(axis).to_matrix()
        rings = []

        for point in (start, end):
            rings.append([bm.verts.new(point + align @ p) for p in _circle(radius, sides)])

        _loft(bm, rings, cap_start=False, cap_end=False)

        for ring_verts in (list(reversed(rings[0])), rings[1]):
            face = bm.faces.new(ring_verts)
            face.material_index = 1

    return bm, [part["slot"], "char"]


def panes(part):
    """A lantern's body: `sides` panes round the Z axis between iron bars,
    with a rim top and bottom."""
    bm = bmesh.new()
    sides = part["sides"]
    radius = part["radius"]
    height = part["height"]
    bar = part.get("bars", 0.008)
    turn = math.pi / sides
    bottom = [bm.verts.new(p) for p in _circle(radius * 0.97, sides, 0.0, turn)]
    top = [bm.verts.new(p) for p in _circle(radius * 0.97, sides, height, turn)]
    _loft(bm, [bottom, top], cap_start=False, cap_end=False, material=0)

    for face in bm.faces:
        face.smooth = False

    frame = bmesh.new()

    for corner in _circle(radius, sides, 0.0, turn):
        post = bmesh.new()
        bmesh.ops.create_cube(post, size=1.0)

        for vertex in post.verts:
            vertex.co = Vector((vertex.co.x * bar * 2.0, vertex.co.y * bar * 2.0, (vertex.co.z + 0.5) * height)) + corner

        _merge(frame, post)

    for z in (0.0, height):
        rim = bmesh.new()
        _torus(rim, radius, bar, 4, sides)

        for vertex in rim.verts:
            vertex.co = Matrix.Rotation(turn, 3, "Z") @ vertex.co + Vector((0.0, 0.0, z))

        _merge(frame, rim)

    for face in frame.faces:
        face.material_index = 1

    _merge(bm, frame)
    return bm, [part["slot"], part.get("frame_slot", "iron")]


def collider(part):
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    sx, sy, sz = part["size"]

    for vertex in bm.verts:
        vertex.co = Vector((vertex.co.x * sx, vertex.co.y * sy, vertex.co.z * sz))

    return bm, []


BUILDERS = {
    "lathe": lathe, "blob": blob, "tube": tube, "box": box, "ring": ring, "chain": chain,
    "stones": stones, "logs": logs, "panes": panes, "collider": collider,
}


def _merge(into, other):
    """Copies bmesh `other`'s geometry into `into` (keeping material indices and smoothing)."""
    mesh = bpy.data.meshes.new("tmp")
    other.to_mesh(mesh)
    other.free()
    into.from_mesh(mesh)
    bpy.data.meshes.remove(mesh)


# Finishing a part

def _place(bm, part):
    rotate = part.get("rotate", (0.0, 0.0, 0.0))
    turn = Euler([math.radians(a) for a in rotate], "XYZ").to_matrix()
    at = Vector(part.get("at", (0.0, 0.0, 0.0)))

    for vertex in bm.verts:
        vertex.co = turn @ vertex.co + at


def unwrap(bm):
    """Box projection: each face onto the plane its normal faces most."""
    layer = bm.loops.layers.uv.verify()
    scale = common.uv_scale()
    bm.normal_update()

    for face in bm.faces:
        n = face.normal
        axis = max(range(3), key=lambda k: abs(n[k]))

        for loop in face.loops:
            co = loop.vert.co
            u, v = [(co.y, co.z), (co.x, co.z), (co.x, co.y)][axis]
            loop[layer].uv = (u * scale, v * scale)


def _harden(bm):
    """Hard edges where faces meet sharper than SHARP."""
    for edge in bm.edges:
        if len(edge.link_faces) == 2:
            a, b = edge.link_faces
            edge.smooth = a.normal.angle(b.normal, 0.0) < SHARP


def _material(name):
    material = bpy.data.materials.get(name)

    if material is None:
        material = bpy.data.materials.new(name)
        hex_colour = recipes.SLOT_COLOURS.get(name.removesuffix("_glow"), "FF00FF")
        srgb = [int(hex_colour[i:i + 2], 16) / 255.0 for i in (0, 2, 4)]
        linear = [c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4 for c in srgb]
        material.diffuse_color = (*linear, 1.0)

    return material


def build_part(part):
    bm, slots = BUILDERS[part["type"]](part)
    _place(bm, part)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-6)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    unwrap(bm)
    _harden(bm)
    name = part["name"] + ("-colonly" if part["type"] == "collider" else "")
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(obj)

    for index, slot in enumerate(slots):
        glowing = part.get("glow", False) and index == 0
        mesh.materials.append(_material(slot + ("_glow" if glowing else "")))

    return obj


def build_fixture(name, recipe):
    """A fresh scene holding the fixture; returns part name -> object."""
    scene = common.scene_fresh()
    scene["fixture"] = name
    scene["recipe_hash"] = common.recipe_hash(recipe)
    objects = {}

    for part in recipe["parts"]:
        objects[part["name"]] = build_part(part)

    for socket, points in recipe.get("sockets", {}).items():
        for index, point in enumerate(points):
            empty = bpy.data.objects.new("socket:%s:%d" % (socket, index), None)
            empty.empty_display_size = 0.03
            empty.location = point
            scene.collection.objects.link(empty)

    return objects


def main(argv):
    if not argv:
        common.fail("build.py -- <fixture>")

    name = argv[0]

    if name not in recipes.FIXTURES:
        common.fail("no fixture called '%s'" % name)

    build_fixture(name, recipes.FIXTURES[name])
    common.SOURCE.mkdir(parents=True, exist_ok=True)
    path = common.SOURCE / (name + ".blend")
    common.backup(path)
    bpy.ops.wm.save_as_mainfile(filepath=str(path))
    print("props: built %s" % path.relative_to(common.ROOT))


if __name__ == "__main__":
    main(sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else [])
