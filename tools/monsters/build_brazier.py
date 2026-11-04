"""The brazier: an iron church censer packed with coals rather than incense, because that is what people on the old lakebed
learned keeps the drowned down. Built as a thurible is: a footed bowl, a pierced lid with a cross on it, three chains from the bowl
up to a conical plate with a ring, and a fourth chain through the plate to the lid. Heavier than a church would carry, and the lid
stepped as the city's own work is. It hangs from its ring: the origin. Closed meshes only.

blender --background --factory-startup --python tools/monsters/build_brazier.py -- <project>
BRAZIER_PICTURES=<folder> renders it, close, from all round.
"""

import math
import os
import random
import sys

import bmesh
import bpy
from mathutils import Matrix, Vector, noise

PROJECT = sys.argv[sys.argv.index("--") + 1] if "--" in sys.argv else os.getcwd()
GLB = os.path.join(PROJECT, "assets/weapons/brazier.glb")
PICTURES = os.environ.get("BRAZIER_PICTURES", "")

SIDES = 48
## How big it's made, once it's built: a church's would be smaller, and you have to see it hanging from your hand.
HEAD_SCALE = 0.72
## How far its ring's top is above its foot, for hanging it from the origin (m).
TOP = 0.722
## Where its bowl's rim is, its plate is, how far out its lugs and plate holes are (m).
RIM_Z = 0.192
PLATE_Z = 0.62
LUG_R = 0.146
PLATE_HOLE_R = 0.05

IRON = (0.1, 0.092, 0.086)
WORN = (0.3, 0.28, 0.26)
RUST = (0.24, 0.115, 0.06)
SOOT = (0.018, 0.016, 0.015)
LEATHER = (0.11, 0.065, 0.04)


def mix(a, b, t):
    t = max(0.0, min(1.0, t))
    return tuple(a[i] + (b[i] - a[i]) * t for i in range(3))


def smooth(a, b, x):
    t = max(0.0, min(1.0, (x - a) / (b - a)))
    return t * t * (3.0 - 2.0 * t)


def lathe(name, profile, sides=SIDES):
    """A solid of revolution round z: `profile` is [r, z] from a point on the axis to another. Closed by being so."""
    bm = bmesh.new()
    first = bm.verts.new((0.0, 0.0, profile[0][1]))
    last = bm.verts.new((0.0, 0.0, profile[-1][1]))
    rings = []

    for r, z in profile[1:-1]:
        ring = []

        for i in range(sides):
            a = i / sides * math.tau
            ring.append(bm.verts.new((math.cos(a) * r, math.sin(a) * r, z)))

        rings.append(ring)

    for i in range(sides):
        j = (i + 1) % sides
        bm.faces.new((first, rings[0][j], rings[0][i]))
        bm.faces.new((last, rings[-1][i], rings[-1][j]))

        for k in range(len(rings) - 1):
            bm.faces.new((rings[k][i], rings[k][j], rings[k + 1][j], rings[k + 1][i]))

    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return made(name, bm)


def made(name, bm):
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    return obj


def closed(obj):
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    bad = [e for e in bm.edges if len(e.link_faces) != 2]
    where = [(len(e.link_faces), tuple(round(c, 4) for c in e.verts[0].co), tuple(round(c, 4) for c in e.verts[1].co)) for e in bad[:8]]
    bm.free()

    if bad:
        raise RuntimeError("%s has %d open edges, as %s" % (obj.name, len(bad), where))


def active(obj):
    for other in bpy.context.selected_objects:
        other.select_set(False)

    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj


def cut(obj, cutters):
    for cutter in cutters:
        modifier = obj.modifiers.new("Cut", "BOOLEAN")
        modifier.operation = "DIFFERENCE"
        modifier.solver = "EXACT"
        modifier.object = cutter
        active(obj)
        bpy.ops.object.modifier_apply(modifier=modifier.name)
        bpy.data.objects.remove(cutter)

    # (A cut can leave a sliver with no area in it, three points in a line: that isn't a hole in the iron.)
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=0.00002)
    bmesh.ops.dissolve_degenerate(bm, dist=0.00002, edges=bm.edges)
    bmesh.ops.holes_fill(bm, edges=[e for e in bm.edges if len(e.link_faces) == 1], sides=8)
    bm.to_mesh(obj.data)
    bm.free()


def stepped_window(at_angle, z, wide, tall, steps=2):
    """A hole through the lid, radially: a cross stepped at its corners, the fret the city puts on everything it builds."""
    half_w = wide * 0.5
    half_t = tall * 0.5
    outline = []
    # (One corner's steps, then mirrored round.)
    corner = [(half_w, half_t * 0.34), (half_w * 0.66, half_t * 0.34), (half_w * 0.66, half_t * 0.66), (half_w * 0.34, half_t * 0.66), (half_w * 0.34, half_t)]

    if steps < 2:
        corner = [(half_w, half_t * 0.4), (half_w * 0.4, half_t * 0.4), (half_w * 0.4, half_t)]

    outline += corner
    outline += [(-x, y) for x, y in reversed(corner)]
    outline += [(-x, -y) for x, y in corner]
    outline += [(x, -y) for x, y in reversed(corner)]
    bm = bmesh.new()
    near = [bm.verts.new((0.03, x, y + z)) for x, y in outline]
    far = [bm.verts.new((0.2, x, y + z)) for x, y in outline]
    bm.faces.new(near)
    bm.faces.new(reversed(far))

    for i in range(len(outline)):
        j = (i + 1) % len(outline)
        bm.faces.new((near[i], near[j], far[j], far[i]))

    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bmesh.ops.rotate(bm, verts=bm.verts, matrix=Matrix.Rotation(at_angle, 3, "Z"), cent=(0.0, 0.0, 0.0))
    return made("Window", bm)


def link_bm(bm, length, wide, wire, matrix, rows=8, around=5):
    """One forged link: a closed loop of round wire, its long sides straight."""
    half_straight = (length - wide) * 0.5
    bend = (wide - wire * 2.0) * 0.5
    centres = []

    for i in range(rows):
        t = i / rows
        a = t * math.tau
        x = math.cos(a) * bend
        y = math.sin(a) * bend + (half_straight if math.sin(a) >= 0.0 else -half_straight)
        tangent = Vector((-math.sin(a), math.cos(a), 0.0))
        centres.append((Vector((x, y, 0.0)), tangent))

    rings = []

    for centre, tangent in centres:
        out = tangent.cross(Vector((0.0, 0.0, 1.0))).normalized()
        ring = []

        for k in range(around):
            b = k / around * math.tau
            ring.append(bm.verts.new(matrix @ (centre + out * math.cos(b) * wire + Vector((0.0, 0.0, 1.0)) * math.sin(b) * wire)))

        rings.append(ring)

    faces = []

    for i in range(rows):
        j = (i + 1) % rows

        for k in range(around):
            m = (k + 1) % around
            faces.append(bm.faces.new((rings[i][k], rings[i][m], rings[j][m], rings[j][k])))

    bmesh.ops.recalc_face_normals(bm, faces=faces)


def chain_between(name, start, end, length, wide, wire):
    """Links, each turned a quarter from the last, from one point to another. Taut: the bowl's weight is on them."""
    bm = bmesh.new()
    way = (end - start)
    pitch = length - wire * 2.0
    count = max(int(round(way.length / pitch)), 2)
    along = way.normalized()
    side = along.cross(Vector((0.13, 0.91, 0.27))).normalized()
    other = side.cross(along).normalized()

    for i in range(count):
        at = start + way * ((i + 0.5) / count)
        turned = side if i % 2 == 0 else other
        z_axis = along.cross(turned).normalized()
        basis = Matrix(((turned.x, along.x, z_axis.x, at.x), (turned.y, along.y, z_axis.y, at.y), (turned.z, along.z, z_axis.z, at.z), (0.0, 0.0, 0.0, 1.0)))
        link_bm(bm, way.length / count + wire * 2.0, wide, wire, basis)

    return made(name, bm)


def torus(name, centre, axis, major, minor, rows=18, around=7):
    bm = bmesh.new()
    axis = axis.normalized()
    side = axis.cross(Vector((0.31, 0.17, 0.93))).normalized()
    other = axis.cross(side).normalized()
    rings = []

    for i in range(rows):
        a = i / rows * math.tau
        out = side * math.cos(a) + other * math.sin(a)
        ring = []

        for k in range(around):
            b = k / around * math.tau
            ring.append(bm.verts.new(centre + out * (major + math.cos(b) * minor) + axis * math.sin(b) * minor))

        rings.append(ring)

    faces = []

    for i in range(rows):
        j = (i + 1) % rows

        for k in range(around):
            m = (k + 1) % around
            faces.append(bm.faces.new((rings[i][k], rings[i][m], rings[j][m], rings[j][k])))

    bmesh.ops.recalc_face_normals(bm, faces=faces)
    return made(name, bm)


def rivet(at, normal, size=0.0075):
    """A rivet's head, sat in what it holds."""
    bm = bmesh.new()
    bmesh.ops.create_icosphere(bm, subdivisions=1, radius=size)
    bmesh.ops.scale(bm, verts=bm.verts, vec=(1.0, 1.0, 0.55))
    rotation = Vector((0.0, 0.0, 1.0)).rotation_difference(normal).to_matrix().to_4x4()
    bmesh.ops.transform(bm, verts=bm.verts, matrix=Matrix.Translation(at) @ rotation)
    return made("Rivet", bm)


def box(name, centre, size, turned=0.0):
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    bmesh.ops.scale(bm, verts=bm.verts, vec=size)
    bmesh.ops.rotate(bm, verts=bm.verts, matrix=Matrix.Rotation(turned, 3, "Z"), cent=(0.0, 0.0, 0.0))
    bmesh.ops.translate(bm, verts=bm.verts, vec=centre)
    return made(name, bm)


def hammered(obj, amount=0.0014, scale=46.0):
    """The bowl was beaten, not spun."""
    for v in obj.data.vertices:
        v.co += v.normal * noise.noise(v.co * scale) * amount


def paint(obj, base=IRON, heat_inside=False):
    """Iron: worn on what sticks out, rust in what doesn't, soot over the holes; alpha is how hot it is, from the coals."""
    mesh = obj.data
    colours = mesh.color_attributes.new("Col", "FLOAT_COLOR", "CORNER")
    mesh.calc_loop_triangles()

    for poly in mesh.polygons:
        for loop_index in poly.loop_indices:
            v = mesh.vertices[mesh.loops[loop_index].vertex_index]
            c = v.co
            n = poly.normal
            rough = noise.noise(c * 31.0) * 0.5 + 0.5
            fine = noise.noise(c * 113.0) * 0.5 + 0.5
            tone = mix(base, WORN, smooth(0.62, 0.84, rough) * 0.8 * smooth(-0.2, 0.8, n.z + abs(n.x) * 0.4))
            tone = mix(tone, RUST, smooth(0.5, 0.78, noise.noise(c * 13.0 + Vector((5.0, 0.0, 0.0))) * 0.5 + 0.5) * 0.7 * fine)
            r = math.hypot(c.x, c.y)
            heat = 0.0

            if heat_inside:
                # What faces in, over the coals, takes the heat; the soot climbs the outside from the holes.
                inward = -(n.x * c.x + n.y * c.y) / max(r, 0.001)
                heat = smooth(0.1, 0.7, inward) * 0.8
                tone = mix(tone, SOOT, smooth(0.0, 0.5, inward) * 0.9)
                tone = mix(tone, SOOT, smooth(0.24, 0.42, c.z) * smooth(0.45, 0.8, fine + rough * 0.3) * 0.75)

            colours.data[loop_index].color = (tone[0], tone[1], tone[2], heat)

    mesh.color_attributes.active_color = colours


def smoothed(obj, angle=0.62):
    """Round where it's round; a true edge where it's forged."""
    bm = bmesh.new()
    bm.from_mesh(obj.data)

    for f in bm.faces:
        f.smooth = True

    for e in bm.edges:
        e.smooth = len(e.link_faces) == 2 and e.calc_face_angle(0.0) < angle

    bm.to_mesh(obj.data)
    bm.free()


def joined(name, objs):
    active(objs[0])

    for obj in objs:
        obj.select_set(True)

    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.object.join()
    objs[0].name = name
    objs[0].data.name = name
    return objs[0]


## The bowl's outside, foot to rim: [r, z]. Its straps follow this.
BOWL_OUTSIDE = [(0.078, 0.0), (0.084, 0.006), (0.084, 0.016), (0.07, 0.022), (0.05, 0.032), (0.046, 0.044), (0.062, 0.052), (0.098, 0.075), (0.114, 0.098), (0.118, 0.1), (0.118, 0.106), (0.123, 0.11), (0.129, 0.135), (0.13, 0.16), (0.133, 0.162), (0.133, 0.168), (0.13, 0.17),
    (0.128, 0.172), (0.136, 0.176), (0.138, 0.186), (0.13, 0.192)]


def bowl_at(z):
    """How far out the bowl's outside is at this height."""
    for i in range(len(BOWL_OUTSIDE) - 1):
        r0, z0 = BOWL_OUTSIDE[i]
        r1, z1 = BOWL_OUTSIDE[i + 1]

        if z0 <= z <= z1 and z1 > z0:
            return r0 + (r1 - r0) * (z - z0) / (z1 - z0)

    return BOWL_OUTSIDE[-1][0]


def strap(angle):
    """An iron strap beaten to the bowl's own curve, a spear's point at its foot, carrying the weight up over the rim to its lug. It lies on the bowl, a little into it."""
    out = Vector((math.cos(angle), math.sin(angle), 0.0))
    tangent = Vector((-math.sin(angle), math.cos(angle), 0.0))
    up = Vector((0.0, 0.0, 1.0))
    bm = bmesh.new()
    rows = []
    bottom = 0.062
    top = 0.186
    steps = 13

    for i in range(steps + 1):
        z = bottom + (top - bottom) * i / steps
        t = i / steps
        half = 0.016 * smooth(0.0, 0.2, t) * (1.0 - 0.28 * smooth(0.25, 0.42, t) * (1.0 - smooth(0.42, 0.6, t))) + 0.0012
        r = max(bowl_at(z), bowl_at(max(z - 0.008, 0.0)), bowl_at(min(z + 0.008, 0.192)) if z < 0.17 else 0.0)
        inner = r - 0.004
        outer = r + 0.0055 * smooth(0.0, 0.15, t) + 0.0005
        at = up * z
        rows.append([
            bm.verts.new(at + out * inner - tangent * half), bm.verts.new(at + out * outer - tangent * half * 0.84),
            bm.verts.new(at + out * outer + tangent * half * 0.84), bm.verts.new(at + out * inner + tangent * half)])

    faces = [bm.faces.new(rows[0]), bm.faces.new(reversed(rows[-1]))]

    for i in range(steps):
        for k in range(4):
            m = (k + 1) % 4
            faces.append(bm.faces.new((rows[i][k], rows[i][m], rows[i + 1][m], rows[i + 1][k])))

    bmesh.ops.recalc_face_normals(bm, faces=faces)
    return made("Strap", bm)


def fret(angle, z):
    """One stepped tile of the band round its belly: the fret again, in relief, sat into the iron."""
    bm = bmesh.new()
    r = bowl_at(z)
    out = Vector((math.cos(angle), math.sin(angle), 0.0))
    tangent = Vector((-math.sin(angle), math.cos(angle), 0.0))
    up = Vector((0.0, 0.0, 1.0))

    for wide, tall, depth in ((0.024, 0.018, 0.0028), (0.016, 0.012, 0.005), (0.007, 0.006, 0.0068)):
        centre = out * (r - 0.002) + up * z
        faces = []
        corners = []

        for near_far in (0.0, depth + 0.002):
            ring = []

            for sx, sy in ((-1, -1), (1, -1), (1, 1), (-1, 1)):
                ring.append(bm.verts.new(centre + out * near_far + tangent * sx * wide * 0.5 + up * sy * tall * 0.5))

            corners.append(ring)

        faces.append(bm.faces.new(corners[0]))
        faces.append(bm.faces.new(reversed(corners[1])))

        for k in range(4):
            m = (k + 1) % 4
            faces.append(bm.faces.new((corners[0][k], corners[0][m], corners[1][m], corners[1][k])))

        bmesh.ops.recalc_face_normals(bm, faces=faces)

    return made("Fret", bm)


def build_head(rng):
    """The bowl and lid, the chains and the plate: rigid, the weight keeps them taut."""
    bowl = lathe("Bowl", [(0.0, 0.0)] + BOWL_OUTSIDE + [(0.118, 0.192), (0.112, 0.18), (0.11, 0.14), (0.098, 0.105), (0.07, 0.078), (0.04, 0.066), (0.0, 0.062)])
    hammered(bowl)
    # The lid sits on the rim with a lip down inside it, a dark line between them. Stepped, as the city's towers are; each step's wall tall enough to pierce, and its shell the same thickness all the way up.
    lid = lathe("Lid", [
        (0.0, 0.53), (0.026, 0.53), (0.031, 0.524), (0.026, 0.516), (0.022, 0.494), (0.042, 0.486), (0.044, 0.474), (0.048, 0.432), (0.062, 0.428), (0.066, 0.42), (0.072, 0.372), (0.087, 0.368), (0.091, 0.36),
        (0.098, 0.306), (0.113, 0.302), (0.117, 0.294), (0.125, 0.232), (0.131, 0.226), (0.133, 0.206), (0.131, 0.197), (0.121, 0.197), (0.108, 0.197), (0.106, 0.178), (0.098, 0.178), (0.1, 0.2), (0.108, 0.284), (0.1, 0.292), (0.083, 0.296), (0.077, 0.352), (0.074, 0.36), (0.058, 0.364),
        (0.053, 0.412), (0.05, 0.42), (0.032, 0.426), (0.0, 0.44)])
    windows = []

    # (Each row in the wall of its own step: nothing crosses a step.)
    for i in range(8):
        a = i / 8 * math.tau + 0.2
        windows.append(stepped_window(a, 0.2637, 0.0623, 0.0461))

    for i in range(8):
        windows.append(stepped_window(i / 8 * math.tau + 0.2 + math.tau / 16, 0.3343, 0.0503, 0.0407))

    for i in range(6):
        windows.append(stepped_window(i / 6 * math.tau + 0.2, 0.3937, 0.036, 0.0313, 1))

    cut(lid, windows)
    closed(bowl)
    closed(lid)
    plate = lathe("Plate", [
        (0.0, PLATE_Z - 0.012), (0.06, PLATE_Z - 0.012), (0.068, PLATE_Z - 0.006), (0.066, PLATE_Z + 0.004), (0.05, PLATE_Z + 0.012), (0.034, PLATE_Z + 0.022), (0.018, PLATE_Z + 0.042), (0.014, PLATE_Z + 0.056), (0.019, PLATE_Z + 0.062), (0.0, PLATE_Z + 0.066)], 24)
    parts = [bowl, lid, plate]
    parts.append(torus("Ring", Vector((0.0, 0.0, PLATE_Z + 0.082)), Vector((0.0, 1.0, 0.0)), 0.022, 0.0065))
    # The cross on the lid: square iron, flared ends, set in its boss.
    parts.append(box("Upright", (0.0, 0.0, 0.558), (0.012, 0.012, 0.062)))
    parts.append(box("Arm", (0.0, 0.0, 0.566), (0.044, 0.012, 0.012)))

    for side in (-1.0, 1.0):
        parts.append(box("ArmEnd", (side * 0.024, 0.0, 0.566), (0.008, 0.017, 0.02)))

    parts.append(box("Top", (0.0, 0.0, 0.591), (0.02, 0.017, 0.008)))

    # A band of the fret round its belly.
    for i in range(18):
        a = i / 18 * math.tau + 0.1

        # (Not under a strap.)
        if min(abs(math.remainder(a - (k / 3 * math.tau + math.pi / 6.0), math.tau)) for k in range(3)) > 0.2:
            parts.append(fret(a, 0.135))

    # Three straps on the bowl, three lugs, three chains to the plate, rivets where they take the weight.
    for i in range(3):
        a = i / 3 * math.tau + math.pi / 6.0
        out = Vector((math.cos(a), math.sin(a), 0.0))
        tangent = Vector((-math.sin(a), math.cos(a), 0.0))
        lug_at = out * LUG_R + Vector((0.0, 0.0, 0.183))
        hole_at = out * PLATE_HOLE_R + Vector((0.0, 0.0, PLATE_Z - 0.002))
        parts.append(strap(a))
        parts.append(torus("Lug", lug_at, tangent, 0.012, 0.0048))

        for z, across in ((0.092, 0.0), (0.122, 0.0), (0.152, -0.009), (0.152, 0.009)):
            r = bowl_at(z) + 0.0055
            parts.append(rivet(out * r + tangent * across + Vector((0.0, 0.0, z)), out + Vector((0.0, 0.0, 0.1))))

        parts.append(chain_between("Chain", lug_at + (hole_at - lug_at).normalized() * 0.012, hole_at, 0.044, 0.024, 0.0048))
        parts.append(torus("Eye", hole_at, tangent, 0.009, 0.0036))

    # And the lid's own, in the middle, to lift it by.
    parts.append(chain_between("LidChain", Vector((0.0, 0.0, 0.592)), Vector((0.0, 0.0, PLATE_Z - 0.008)), 0.024, 0.015, 0.0032))

    head_parts = []

    for part in parts:
        paint(part, heat_inside=part.name.startswith(("Bowl", "Lid")) and not part.name.startswith("LidChain"))
        head_parts.append(part)

    head = joined("Head", head_parts)

    # (Hung from its ring.)
    for v in head.data.vertices:
        v.co.z -= TOP

    closed(head)
    return head


def build_coals(rng):
    """What's in it: packed, heaped up into the lid, so what you see through every hole is coal. A dark core under them shuts out the other side."""
    bm = bmesh.new()

    def add(piece):
        mesh = bpy.data.meshes.new("Coal")
        piece.to_mesh(mesh)
        piece.free()
        bm.from_mesh(mesh)
        bpy.data.meshes.remove(mesh)

    # (Height over its radius: a heap inside the shape of the lid, clear of its shell and lip.)
    def most_up(r):
        return 0.415 - r * 2.25

    for i in range(120):
        a = rng.uniform(0.0, math.tau)
        r = math.sqrt(rng.random()) * 0.085
        z = rng.uniform(0.09, most_up(r))
        size = rng.uniform(0.015, 0.024)
        piece = bmesh.new()
        bmesh.ops.create_icosphere(piece, subdivisions=1, radius=size)

        for v in piece.verts:
            v.co *= 0.82 + 0.36 * rng.random()
            v.co += Vector((math.cos(a) * r, math.sin(a) * r, z - TOP))

        add(piece)

    coals = made("Coals", bm)
    closed(coals)
    return coals


def build_link():
    """One link of the long chain. It runs along y; BrazierChain turns every other a quarter."""
    bm = bmesh.new()
    link_bm(bm, 0.074, 0.04, 0.0072, Matrix.Identity(4), rows=10, around=6)
    link = made("Link", bm)
    closed(link)
    paint(link, IRON)
    return link


def build_grip():
    """What's in your fist: an iron bar wrapped in old leather, a ring the chain comes from at its foot. Up its length is y, as a blade's is; the fist is at the origin."""
    bar = lathe("Bar", [(0.0, -0.075), (0.021, -0.075), (0.024, -0.068), (0.018, -0.06), (0.017, 0.06), (0.024, 0.066), (0.026, 0.08), (0.016, 0.092), (0.0, 0.095)], 12)
    paint(bar, IRON)
    wrap = lathe("Wrap", [(0.0, -0.058)] + [(0.0195 + (0.0035 if i % 2 else 0.0), -0.058 + i * 0.0065) for i in range(19)] + [(0.0, 0.0605)], 12)
    paint(wrap, LEATHER)
    ring = torus("GripRing", Vector((0.0, 0.0, -0.098)), Vector((0.0, 1.0, 0.0)), 0.021, 0.006)
    paint(ring, IRON)
    grip = joined("Grip", [bar, wrap, ring])

    # (Blender's z up its length to the game's y: the export turns it back.)
    for v in grip.data.vertices:
        v.co = Vector((v.co.x, v.co.y, v.co.z))

    closed(grip)
    return grip


def render(objs):
    bpy.context.scene.render.engine = "BLENDER_EEVEE"
    bpy.context.scene.render.resolution_x = 900
    bpy.context.scene.render.resolution_y = 900
    world = bpy.data.worlds.new("Sky")
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs[0].default_value = (0.25, 0.25, 0.28, 1.0)
    bpy.context.scene.world = world
    look = bpy.data.materials.new("Paint")
    look.use_nodes = True
    nodes = look.node_tree.nodes
    attribute = nodes.new("ShaderNodeVertexColor")
    attribute.layer_name = "Col"
    look.node_tree.links.new(attribute.outputs[0], nodes["Principled BSDF"].inputs["Base Color"])
    nodes["Principled BSDF"].inputs["Roughness"].default_value = 0.6
    glow = bpy.data.materials.new("Glow")
    glow.use_nodes = True
    glow.node_tree.nodes["Principled BSDF"].inputs["Emission Color"].default_value = (1.0, 0.35, 0.05, 1.0)
    glow.node_tree.nodes["Principled BSDF"].inputs["Emission Strength"].default_value = 6.0

    for obj in objs:
        obj.data.materials.clear()
        obj.data.materials.append(glow if obj.name == "Coals" else look)

    sun = bpy.data.objects.new("Sun", bpy.data.lights.new("Sun", "SUN"))
    bpy.context.collection.objects.link(sun)
    sun.rotation_euler = (0.9, 0.2, 0.7)
    sun.data.energy = 3.0
    camera = bpy.data.objects.new("Camera", bpy.data.cameras.new("Camera"))
    bpy.context.collection.objects.link(camera)
    bpy.context.scene.camera = camera

    shots = {"whole": (Vector((0.8, -0.95, -0.15)), Vector((0.0, 0.0, -0.27)), 50.0), "lid": (Vector((0.3, -0.36, -0.22)), Vector((0.0, 0.0, -0.29)), 42.0), "top": (Vector((0.15, -0.19, 0.04)), Vector((0.0, 0.0, -0.09)), 42.0),
        "under": (Vector((0.25, -0.29, -0.68)), Vector((0.0, 0.0, -0.45)), 42.0), "lug": (Vector((0.22, -0.22, -0.37)), Vector((0.07, -0.04, -0.4)), 34.0), "grip": (Vector((0.28, -0.3, 1.0)), Vector((0.0, 0.0, 0.8)), 30.0), "link": (Vector((0.14, -0.18, 1.1)), Vector((0.0, 0.0, 1.1)), 30.0)}

    for name, (at, target, lens) in shots.items():
        camera.location = at
        camera.rotation_euler = (target - at).to_track_quat("-Z", "Y").to_euler()
        camera.data.lens = lens
        bpy.context.scene.render.filepath = os.path.join(PICTURES, "brazier_%s.png" % name)
        bpy.ops.render.render(write_still=True)


def main():
    for obj in list(bpy.data.objects):
        bpy.data.objects.remove(obj)

    rng = random.Random(29)
    head = build_head(rng)
    coals = build_coals(rng)
    link = build_link()
    grip = build_grip()

    for obj in (head, coals):
        for v in obj.data.vertices:
            v.co *= HEAD_SCALE

    for obj in (head, coals, link, grip):
        smoothed(obj)

    print("TRIS", {o.name: sum(len(p.vertices) - 2 for p in o.data.polygons) for o in (head, coals, link, grip)})
    os.makedirs(os.path.dirname(GLB), exist_ok=True)
    bpy.ops.export_scene.gltf(filepath=GLB, export_format="GLB", export_yup=True, export_materials="NONE", export_normals=True, export_apply=False, export_vertex_color="ACTIVE", export_all_vertex_colors=False)
    print("WROTE", GLB)

    if PICTURES:
        grip.location = (0.0, 0.0, 0.8)
        link.location = (0.0, 0.0, 1.1)
        render([head, coals, link, grip])


main()
