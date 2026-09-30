"""The skyline round the showcase yard (or the city on the rock's: `city`),
modelled and rendered in Blender.

Run by tools/skyline/skyline.sh (headless Blender):
    Blender -b --factory-startup --python skyline.py -- <out.png> [city]

Everything is built here from code, the same every run (random.Random(1932)):
far hills all round, tree lines to the west, the town to the east and north
with a church spire and a keep, the canal to the south with its warehouses and
masts, a few lit windows. It is rendered as a 360 degree panorama strip from
2 degrees below the horizon to 28 above (Cycles, the silhouettes on a
transparent sky), then turned into the sky shader's frame: column u is
atan(x, z) / TAU + 0.5 in Godot's axes (night_sky.gdshader), row 0 is 28 deg.

Positions below are in Godot's axes (x east, y up, z south); Blender's are
(x, -z, y).
"""

import math
import random
import sys

import bpy
import numpy as np

WIDTH = 4096
HEIGHT = 384
LAT_MIN = -2.0
LAT_MAX = 28.0

# Colours: nearer is darker; the far hills fade toward the haze.
TOWN = (0.010, 0.012, 0.018)
TREES = (0.013, 0.017, 0.020)
CANAL = (0.011, 0.013, 0.019)
HILLS = (0.028, 0.034, 0.050)
WINDOW = (1.0, 0.62, 0.30)
COAST = (0.020, 0.024, 0.036)
FAR = (0.040, 0.046, 0.064)
SEA = (0.010, 0.013, 0.020)
# Toward the moon (Godot), for the faint rim on the silhouettes (the city's:
# up the other way from maps/city.gd's MOON_TOWARD, the light's way).
MOON_TOWARD = (-0.62, 0.5, -0.6)
CITY_MOON_TOWARD = (-0.3, 0.57, 0.77)

rng = random.Random(1932)


def blender(x, y, z):
    """Godot (x, y, z) -> Blender (x, -z, y)."""
    return (x, -z, y)


def at(azimuth_deg, distance, height=0.0):
    """A point `distance` m off toward `azimuth_deg` (0 south, 90 east, 180 north)."""
    a = math.radians(azimuth_deg)
    return (math.sin(a) * distance, height, math.cos(a) * distance)


def material(name, colour, strength=1.0, rim=True):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    nodes = mat.node_tree.nodes
    links = mat.node_tree.links
    nodes.clear()
    out = nodes.new("ShaderNodeOutputMaterial")
    emission = nodes.new("ShaderNodeEmission")
    emission.inputs["Color"].default_value = (*colour, 1.0)
    emission.inputs["Strength"].default_value = strength

    if rim:
        diffuse = nodes.new("ShaderNodeBsdfDiffuse")
        diffuse.inputs["Color"].default_value = (0.05, 0.055, 0.07, 1.0)
        add = nodes.new("ShaderNodeAddShader")
        links.new(emission.outputs[0], add.inputs[0])
        links.new(diffuse.outputs[0], add.inputs[1])
        links.new(add.outputs[0], out.inputs["Surface"])
    else:
        links.new(emission.outputs[0], out.inputs["Surface"])

    return mat


def mesh_object(name, verts, faces, mat):
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata([blender(*v) for v in verts], [], faces)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    obj.data.materials.append(mat)
    bpy.context.scene.collection.objects.link(obj)
    return obj


def box(name, centre, size, yaw, mat):
    """A box standing on centre.y, turned `yaw` rad about the vertical."""
    cx, cy, cz = centre
    sx, sy, sz = size[0] / 2, size[1], size[2] / 2
    c, s = math.cos(yaw), math.sin(yaw)
    corners = []

    for y in (cy, cy + sy):
        for dx, dz in ((-sx, -sz), (sx, -sz), (sx, sz), (-sx, sz)):
            corners.append((cx + dx * c - dz * s, y, cz + dx * s + dz * c))

    faces = [(0, 1, 2, 3), (4, 7, 6, 5), (0, 4, 5, 1), (1, 5, 6, 2), (2, 6, 7, 3), (3, 7, 4, 0)]
    return mesh_object(name, corners, faces, mat)


def gable(name, centre, width, depth, eave, ridge, yaw, mat):
    """A gabled roof over a box of width x depth whose walls stop at `eave`."""
    cx, cy, cz = centre
    w, d = width / 2 + 0.4, depth / 2 + 0.3
    c, s = math.cos(yaw), math.sin(yaw)

    def p(dx, y, dz):
        return (cx + dx * c - dz * s, y, cz + dx * s + dz * c)

    verts = [p(-w, eave, -d), p(w, eave, -d), p(w, eave, d), p(-w, eave, d), p(0, eave + ridge, -d), p(0, eave + ridge, d)]
    faces = [(0, 4, 5, 3), (1, 2, 5, 4), (0, 1, 4), (2, 3, 5), (0, 3, 2, 1)]
    return mesh_object(name, verts, faces, mat)


def cone(name, centre, radius, height, mat, sides=8):
    cx, cy, cz = centre
    verts = [(cx + math.cos(i / sides * math.tau) * radius, cy, cz + math.sin(i / sides * math.tau) * radius) for i in range(sides)]
    verts.append((cx, cy + height, cz))
    faces = [(i, (i + 1) % sides, sides) for i in range(sides)] + [tuple(reversed(range(sides)))]
    return mesh_object(name, verts, faces, mat)


def facing_origin(point):
    return math.atan2(-point[0], -point[2])


def window(name, house_centre, width, eave, yaw, mat):
    """A lit window on the face of a house toward the yard."""
    cx, cy, cz = house_centre
    wy = cy + rng.uniform(2.5, max(eave - 2.0, 3.0))
    offset = rng.uniform(-width / 3, width / 3)
    toward = (-cx, -cz)
    length = math.hypot(*toward)
    nx, nz = toward[0] / length, toward[1] / length
    # 4 m in front of the facade's centre line is enough at this distance.
    fx, fz = cx + nx * 4.6 + (-nz) * offset, cz + nz * 4.6 + nx * offset
    ax, az = -nz * 0.45, nx * 0.45
    verts = [(fx - ax, wy, fz - az), (fx + ax, wy, fz + az), (fx + ax, wy + 0.9, fz + az), (fx - ax, wy + 0.9, fz - az)]
    return mesh_object(name, verts, [(0, 1, 2, 3), (3, 2, 1, 0)], mat)


def hills(mat):
    """A ring of far hills, 1.5 km off, 2 to 6 degrees up."""
    verts = []
    faces = []
    steps = 360

    for i in range(steps):
        a = i / steps * 360.0
        h = 55.0 + 45.0 * math.sin(math.radians(a * 3.0 + 20)) + 30.0 * math.sin(math.radians(a * 7.0 + 60)) + rng.uniform(-6, 6)
        h = max(h, 20.0)
        # Lower where the town stands, so the town shows against the sky.
        if 95.0 < a < 215.0:
            h *= 0.55
        x, _, z = at(a, 1500.0)
        verts.append((x, -120.0, z))
        verts.append((x, h, z))

    for i in range(steps):
        j = (i + 1) % steps
        faces.append((i * 2, j * 2, j * 2 + 1, i * 2 + 1))

    mesh_object("hills", verts, faces, mat)


def trees(mat):
    """Tree lines to the west, lumpy crowns on trunks."""
    count = 0
    a = 232.0

    while a < 305.0:
        distance = rng.uniform(105.0, 150.0)
        height = rng.uniform(9.0, 15.0)
        crown = rng.uniform(4.0, 6.5)
        base = at(a, distance)
        box("trunk%d" % count, base, (0.8, height * 0.6, 0.8), 0.0, mat)
        bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1, radius=crown, location=blender(base[0], height, base[2]))
        ball = bpy.context.object
        ball.scale = (1.0, 1.0, rng.uniform(0.8, 1.2))
        ball.data.materials.append(mat)
        count += 1
        a += rng.uniform(1.2, 3.0)


def town(mat, lit):
    """The town, east round to north: rows of gabled houses, chimneys, a
    church with its spire, a keep."""
    count = 0
    a = 95.0

    while a < 215.0:
        distance = rng.uniform(95.0, 140.0)
        width = rng.uniform(6.0, 11.0)
        depth = rng.uniform(7.0, 10.0)
        eave = rng.uniform(9.0, 15.0)
        centre = at(a, distance)
        yaw = facing_origin(centre) + rng.uniform(-0.25, 0.25)
        box("house%d" % count, centre, (width, eave, depth), yaw, mat)
        gable("roof%d" % count, centre, width, depth, eave, rng.uniform(4.0, 6.5), yaw, mat)

        if rng.random() < 0.55:
            chimney = (centre[0] + rng.uniform(-2, 2), 0.0, centre[2] + rng.uniform(-2, 2))
            box("chimney%d" % count, chimney, (1.0, eave + rng.uniform(4.0, 7.0), 1.0), yaw, mat)

        if rng.random() < 0.4:
            window("window%d" % count, centre, width, eave, yaw, lit)

        count += 1
        a += width / distance * 57.3 * rng.uniform(0.85, 1.3)

    # The church, north-north-east: a nave, a tower and its spire.
    church = at(165.0, 150.0)
    yaw = facing_origin(church)
    box("nave", church, (12.0, 16.0, 26.0), yaw, mat)
    gable("nave_roof", church, 12.0, 26.0, 16.0, 7.0, yaw, mat)
    tower = at(163.0, 138.0)
    box("church_tower", tower, (7.0, 36.0, 7.0), yaw, mat)
    cone("spire", (tower[0], 36.0, tower[2]), 5.0, 30.0, mat)
    window("church_window", tower, 4.0, 30.0, yaw, lit)
    # A keep, east-north-east, crenellated.
    keep = at(118.0, 190.0)
    box("keep", keep, (16.0, 32.0, 16.0), facing_origin(keep), mat)

    for i in range(4):
        side = i / 4 * math.tau
        box("merlon%d" % i, (keep[0] + math.cos(side) * 6.5, 0.0, keep[2] + math.sin(side) * 6.5), (2.5, 34.5, 2.5), 0.0, mat)


def canal(mat, lit):
    """The canal to the south: warehouses along the quay, boats' masts."""
    a = -40.0
    count = 0

    while a < 40.0:
        distance = rng.uniform(85.0, 100.0)
        centre = at(a, distance)
        yaw = facing_origin(centre)

        if rng.random() < 0.6:
            width = rng.uniform(10.0, 16.0)
            eave = rng.uniform(7.0, 10.0)
            box("warehouse%d" % count, centre, (width, eave, 9.0), yaw, mat)
            gable("warehouse_roof%d" % count, centre, width, 9.0, eave, 4.0, yaw, mat)

            if rng.random() < 0.3:
                window("warehouse_window%d" % count, centre, width, eave, yaw, lit)

            a += width / distance * 57.3 * 1.1
        else:
            mast = at(a, distance - 12.0)
            box("mast%d" % count, mast, (0.35, rng.uniform(12.0, 17.0), 0.35), 0.0, mat)
            a += rng.uniform(2.0, 4.0)

        count += 1


def ridge(name, mat, start, end, distance, height, step=1.0, foot=-150.0):
    """A ridge from azimuth `start` to `end` (degrees: 0 south, 90 east),
    `distance` m off, its crest height(azimuth) m over the sea, down to
    `foot`."""
    verts, faces = [], []
    count = int(round((end - start) / step)) + 1

    for i in range(count):
        a = start + (end - start) * i / (count - 1)
        x, _, z = at(a, distance)
        verts.append((x, foot, z))
        verts.append((x, max(0.0, height(a)), z))

    for i in range(count - 1):
        faces.append((i * 2, (i + 1) * 2, (i + 1) * 2 + 1, i * 2 + 1))

    return mesh_object(name, verts, faces, mat)


def city():
    """The city on the rock's horizon (skyline.sh city; maps/city.gd): hills
    to the north behind the rock, 3 km off; the coast east and west, 2 km
    off, stepping down to the sea; open sea to the south but for a faint
    far headland to the south-south-west and its light."""
    lit = material("window", WINDOW, 2.5, rim=False)
    hills_mat = material("hills", HILLS)
    coast_mat = material("coast", COAST)
    far_mat = material("far", FAR, rim=False)
    sea_mat = material("sea", SEA, rim=False)
    wobble = [rng.uniform(-1.0, 1.0) for _ in range(400)]

    def rough(a, amount):
        return amount * wobble[int(a) % 400]

    def taper(a, start, end, span):
        """Down to nothing at either end, over `span` degrees."""
        t0, t1 = max(0.0, min(1.0, (a - start) / span)), max(0.0, min(1.0, (end - a) / span))
        return t0 * t0 * (3.0 - 2.0 * t0) * t1 * t1 * (3.0 - 2.0 * t1)

    # (Each falls away at its ends: into the sea at the south, behind the
    # hills at the north.)
    ridge("north_hills", hills_mat, 80.0, 280.0, 3000.0,
          lambda a: (190.0 + 90.0 * math.sin(math.radians(a * 4.0 + 30.0)) + 45.0 * math.sin(math.radians(a * 11.0)) + rough(a, 8.0))
          * taper(a, 80.0, 280.0, 14.0))
    ridge("east_coast", coast_mat, 30.0, 112.0, 2200.0,
          lambda a: (15.0 + 110.0 * max(0.0, (a - 30.0) / 82.0) ** 1.4 + 18.0 * math.sin(math.radians(a * 9.0)) + rough(a, 4.0))
          * taper(a, 30.0, 112.0, 10.0), foot=0.0)
    ridge("west_coast", coast_mat, 248.0, 330.0, 2200.0,
          lambda a: (15.0 + 130.0 * max(0.0, (330.0 - a) / 82.0) ** 1.3 + 16.0 * math.sin(math.radians(a * 7.0)) + rough(a, 4.0))
          * taper(a, 248.0, 330.0, 10.0), foot=0.0)
    def headland(a):
        """Up gently from the land to its height near its end, then down
        steeply into the sea."""
        rise = max(0.0, min(1.0, (a - 322.0) / 24.0)) ** 1.6
        fall = math.cos(math.radians(max(0.0, a - 346.0) / 6.0 * 90.0)) if a < 352.0 else 0.0
        return (110.0 * rise + rough(a * 3.0, 5.0)) * fall

    ridge("far_headland", far_mat, 322.0, 352.0, 4600.0, headland, step=0.5, foot=0.0)
    # The sea all round below the horizon, past where the harbour's ends.
    ridge("far_sea", sea_mat, 0.0, 360.0, 2600.0, lambda a: 0.0, step=2.0)
    # (Its light: a lantern on its end, and a few windows on the coasts.)
    box("far_light", at(342.0, 4560.0, 88.0), (10.0, 9.0, 10.0), 0.0, lit)

    for i in range(7):
        a = rng.uniform(44.0, 96.0) if i % 2 else rng.uniform(262.0, 318.0)
        box("coast_window_%d" % i, at(a, 2150.0, rng.uniform(12.0, 40.0)), (3.0, 2.2, 3.0), 0.0, lit)


def moonlight(toward_moon=None):
    sun = bpy.data.lights.new("moon", "SUN")
    sun.energy = 0.25
    sun.color = (0.6, 0.7, 1.0)
    obj = bpy.data.objects.new("moon", sun)
    bpy.context.scene.collection.objects.link(obj)
    toward = blender(*(toward_moon or MOON_TOWARD))
    length = math.sqrt(sum(c * c for c in toward))
    direction = [c / length for c in toward]
    # A sun shines along its -Z: point -Z away from the moon.
    obj.rotation_mode = "QUATERNION"
    from mathutils import Vector
    obj.rotation_quaternion = Vector(direction).to_track_quat("Z", "Y")


def render(path):
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.device = "CPU"
    scene.cycles.samples = 32
    scene.cycles.use_denoising = False
    scene.render.film_transparent = True
    scene.render.resolution_x = WIDTH
    scene.render.resolution_y = HEIGHT
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGBA"
    scene.view_settings.view_transform = "Standard"
    world = bpy.data.worlds.new("sky")
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs["Strength"].default_value = 0.0
    scene.world = world
    data = bpy.data.cameras.new("panorama")
    data.type = "PANO"
    data.panorama_type = "EQUIRECTANGULAR"
    data.latitude_min = math.radians(LAT_MIN)
    data.latitude_max = math.radians(LAT_MAX)
    data.clip_end = 5000.0
    camera = bpy.data.objects.new("panorama", data)
    scene.collection.objects.link(camera)
    camera.location = blender(0.0, 2.0, 0.0)
    camera.rotation_euler = (math.radians(90), 0.0, 0.0)
    scene.camera = camera
    raw = path + ".raw.png"
    scene.render.filepath = raw
    bpy.ops.render.render(write_still=True)

    # Blender's panorama has column u = 1.5 - the shader's u (east where the
    # shader has it, north and south swapped): flip it and roll it half round.
    image = bpy.data.images.load(raw)
    pixels = np.array(image.pixels[:], dtype=np.float32).reshape(HEIGHT, WIDTH, 4)
    pixels = np.roll(pixels[:, ::-1, :], WIDTH // 2, axis=1)
    out = bpy.data.images.new("skyline", WIDTH, HEIGHT, alpha=True)
    out.pixels = pixels.ravel()
    out.filepath_raw = path
    out.file_format = "PNG"
    out.save()


def main():
    args = sys.argv[sys.argv.index("--") + 1:]
    path = args[0]
    scene = args[1] if len(args) > 1 else "yard"
    bpy.ops.wm.read_factory_settings(use_empty=True)

    if scene == "city":
        city()
        moonlight(CITY_MOON_TOWARD)
    else:
        lit = material("window", WINDOW, 2.5, rim=False)
        hills(material("hills", HILLS))
        trees(material("trees", TREES))
        town(material("town", TOWN), lit)
        canal(material("canal", CANAL), lit)
        moonlight()

    render(path)


main()
