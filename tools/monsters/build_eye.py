"""The floating eye: mal de ojo got loose, envy made flesh, grown through the
stepped crown of a Mayan-Revival lintel it tore away (silhouette C, the user's
pick; docs/superpowers/refs/hunt/eye_silhouettes.png). A chunky stepped frame of
oxblood tezontle with a pale cantera rim round an almond, raw swollen meat
bulging through its notches and packed round a bloodshot ball, folded lids
that close over it, maguey spines driven through crown and lid (the old
bloodletting rite: someone tried to kill it), a torn optic nerve threaded through
the last stones with a tin milagro nailed into it, and shreds of nerve behind.

Every part is a closed solid: the script refuses anything with an open edge.
The ball, the pupil and the lids turn about the ball's middle; the tail swings
from its top. Blender's axes: +Y is where it looks (the game's -Z), +Z up, +X
right.

    /Applications/Blender.app/Contents/MacOS/Blender --background --factory-startup \\
        --python tools/monsters/build_eye.py -- <repo root>

Saves assets/monsters/source/floating_eye.blend, exports
assets/monsters/floating_eye.glb and assets/monsters/source/eye_*.png previews.
"""

import math
import os
import random
import sys

import bmesh
import bpy
from mathutils import Matrix, Vector

ROOT = sys.argv[sys.argv.index("--") + 1] if "--" in sys.argv else os.getcwd()
SOURCE = os.path.join(ROOT, "assets", "monsters", "source")
GLB = os.path.join(ROOT, "assets", "monsters", "floating_eye.glb")

# The sheet's drawing, half-width 168 units, to 0.47 m: so its notches still
# cover the back shell behind them.
UNIT = 0.47 / 168.0
# Stepped outer outline (x, z), from the drawing, clockwise from top left. Its
# middle sits 6 units under the drawing's origin: the almond's middle is ours.
STEPS = [(-30, 146), (30, 146), (30, 118), (66, 118), (66, 90), (102, 90), (102, 62), (138, 62), (138, 30), (168, 0),
    (138, -30), (138, -56), (102, -56), (102, -88), (66, -88), (66, -118), (-66, -118), (-66, -88), (-102, -88),
    (-102, -56), (-138, -56), (-138, -30), (-168, 0), (-138, 30), (-138, 62), (-102, 62), (-102, 90), (-66, 90),
    (-66, 118), (-30, 118)]

ALMOND_HALF = (0.3, 0.172)
RIM_GROW = (1.16, 1.42)
FRAME_Y = (0.05, 0.15)
# The second tier of the crown, stepped back in from the first.
TIER_SCALE = 0.9
TIER_Y = (0.13, 0.215)
RIM_Y = (0.2, 0.275)
# The ball sits back in the stone, so the lids tuck in behind the rim.
BALL_AT = Vector((0.0, -0.02, 0.0))
BALL_RADIUS = 0.3
# Behind it, a flattened dish of black, inside the frame's outline from the front.
SOCKET_AT = Vector((0.0, -0.03, 0.0))
SOCKET_RADIUS = 0.305
SOCKET_FLAT = 0.68
LID_RADIUS = 0.32
LID_THICK = 0.008
# The lower lid closes under the upper, and clear of the pupil, facets and all.
BOTTOM_LID_RADIUS = 0.31
# A lid runs this far from its pole in front, and only this far behind.
LID_BEHIND = math.radians(35.0)
# The stone shell over its back, from straight behind to just into the frame.
BACK_RADIUS = 0.33
BACK_HALF = math.radians(106.0)
# A lid is a dome this wide from its pole, tipped back this far when open: its
# front edge then lies on the almond's edge.
LID_HALF = math.radians(78.0)
LID_TIP = math.radians(20.0)
# The upper lid hangs lower: it glares.
TOP_LID_TIP = math.radians(7.0)
IRIS_ANGLE = 0.42
PUPIL_ANGLE = 0.19
TAIL_AT = Vector((0.0, 0.12, -0.315))

TEZONTLE = (0.2, 0.048, 0.034)
CANTERA = (0.36, 0.335, 0.28)
SOCKET_BLACK = (0.012, 0.009, 0.009)
LID_FLESH = (0.36, 0.055, 0.05)
TIN = (0.5, 0.48, 0.42)
PUPIL_BLACK = (0.006, 0.004, 0.004)


def material(name, colour, metallic=0.0, roughness=0.85, painted=None, toned=False):
    """`painted`: an image for its colour. `toned`: multiplied by the vertex colour
    (shade), as the game does too."""
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    tree = m.node_tree
    bsdf = tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = (*colour, 1.0)
    bsdf.inputs["Metallic"].default_value = metallic
    bsdf.inputs["Roughness"].default_value = roughness
    colour_out = None

    if painted is not None:
        tex = tree.nodes.new("ShaderNodeTexImage")
        tex.image = painted
        colour_out = tex.outputs["Color"]

    if toned:
        attribute = tree.nodes.new("ShaderNodeVertexColor")
        attribute.layer_name = "Color"

        if colour_out is None:
            colour_out = attribute.outputs["Color"]
        else:
            mix = tree.nodes.new("ShaderNodeMix")
            mix.data_type = "RGBA"
            mix.blend_type = "MULTIPLY"
            mix.inputs[0].default_value = 1.0
            tree.links.new(colour_out, mix.inputs[6])
            tree.links.new(attribute.outputs["Color"], mix.inputs[7])
            colour_out = mix.outputs[2]

    if colour_out is not None:
        tree.links.new(colour_out, bsdf.inputs["Base Color"])

    return m


def paint_stone(name, base, seed, strokes, pocks, cracks, light, dark):
    """A repeating painted stone: broad strokes of two paints near the base over it,
    then irregular pocks, as a brush would dab them, and a few cracks. No outside
    picture. `light` and `dark` are the second and third paints."""
    size = 512
    rng = random.Random(seed)
    image_data = [list(base) for _ in range(size * size)]

    def blend(x, y, colour, k):
        at = (y % size) * size + (x % size)
        px = image_data[at]
        image_data[at] = [px[i] + (colour[i] - px[i]) * k for i in range(3)]

    def stroke(colour, strength, long_side, thick):
        cx = rng.uniform(0, size)
        cy = rng.uniform(0, size)
        heading = rng.uniform(-0.5, 0.5) + rng.choice((0.0, math.pi / 2.0))
        bend = rng.uniform(-0.002, 0.002)

        # Dry at its ends: the bristles lift off in streaks.
        for along in range(-int(long_side), int(long_side), 2):
            t = along / long_side
            side = thick * (1.0 - t * t * 0.7)
            heading_here = heading + bend * along
            px = cx + math.cos(heading_here) * along
            py = cy + math.sin(heading_here) * along

            for across in range(-int(side), int(side) + 1):
                bristle = math.sin(across * 1.7 + seed) * 0.5 + 0.5

                if abs(t) > 0.72 and bristle < (abs(t) - 0.72) * 3.2:
                    continue

                k = strength * (0.75 + bristle * 0.25)

                for dx in (0, 1):
                    blend(int(px - math.sin(heading_here) * across) + dx, int(py + math.cos(heading_here) * across), colour, k)

    for _ in range(strokes):
        stroke(light if rng.random() < 0.55 else dark, rng.uniform(0.16, 0.34), rng.uniform(26, 70), rng.uniform(5, 13))

    black = (base[0] * 0.2, base[1] * 0.2, base[2] * 0.2)
    pale = (base[0] + (light[0] - base[0]) * 1.6, base[1] + (light[1] - base[1]) * 1.6, base[2] + (light[2] - base[2]) * 1.6)

    # Pocks: lumpy flat black, in clusters, each with a lit lower lip.
    for _ in range(pocks):
        cx = rng.randrange(size)
        cy = rng.randrange(size)

        for _member in range(rng.randrange(1, 5)):
            ox = cx + rng.randrange(-14, 15)
            oy = cy + rng.randrange(-14, 15)
            r = rng.uniform(1.6, 6.5)
            a1 = rng.uniform(0, TAU)

            for dy in range(-9, 10):
                for dx in range(-9, 10):
                    angle = math.atan2(dy, dx)
                    reach = r * (1.0 + 0.35 * math.sin(angle * 3.0 + a1))
                    d = math.hypot(dx, dy)

                    if d <= reach:
                        blend(ox + dx, oy + dy, black, 0.92)
                    elif d <= reach + 1.4 and dy > 0:
                        blend(ox + dx, oy + dy, pale, 0.5)

    for _ in range(cracks):
        x = rng.uniform(0, size)
        y = rng.uniform(0, size)
        heading = rng.uniform(0, TAU)

        for _step in range(rng.randrange(70, 190)):
            heading += rng.uniform(-0.28, 0.28)
            x += math.cos(heading)
            y += math.sin(heading)
            blend(int(x), int(y), black, 0.85)

    pixels = [0.0] * (size * size * 4)

    for i, px in enumerate(image_data):
        pixels[i * 4:i * 4 + 4] = [px[0], px[1], px[2], 1.0]

    image = bpy.data.images.new(name, size, size, alpha=False)
    image.pixels = pixels
    image.pack()
    return image


def paint_value(c):
    """A colour for a colour layer, which the exporter takes for sRGB and turns to
    linear: so this is what comes out as `c` in the game."""
    return (max(c[0], 0.0) ** (1.0 / 2.2), max(c[1], 0.0) ** (1.0 / 2.2), max(c[2], 0.0) ** (1.0 / 2.2), 1.0)


def box_uv(bm, per_metre=1.7):
    """Each face mapped flat along its own main axis: the stone's grain stays even
    on the fronts and the risers alike."""
    layer = bm.loops.layers.uv.verify()

    for f in bm.faces:
        n = f.normal
        axis = max(range(3), key=lambda i: abs(n[i]))
        keep = [i for i in range(3) if i != axis]

        for loop in f.loops:
            co = loop.vert.co
            loop[layer].uv = (co[keep[0]] * per_metre, co[keep[1]] * per_metre)


def shade(bm, tone, tint=(1.0, 1.0, 1.0), ink=0.0):
    """Paints a colour per face corner: tone(position) is how lit it is, 0..1. With
    `ink`, the bevel's thin faces go black: a drawn line round every edge."""
    layer = bm.loops.layers.color.new("Color")

    for f in bm.faces:
        inked = ink > 0.0 and min(e.calc_length() for e in f.edges) < ink

        for loop in f.loops:
            k = 0.02 if inked else tone(loop.vert.co)
            loop[layer] = paint_value((tint[0] * k, tint[1] * k, tint[2] * k))


def solid(name, bm, mats, at=Vector((0.0, 0.0, 0.0)), smooth=False, mapped=False, tone=None, tint=(1.0, 1.0, 1.0), ink=0.0):
    """Refuses an open edge: nothing sawn off."""
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=0.0005)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)

    if mapped:
        box_uv(bm)

    if tone is not None:
        shade(bm, tone, tint, ink)

    open_edges = [e for e in bm.edges if not e.is_manifold]

    if open_edges:
        raise RuntimeError("%s: %d open edges" % (name, len(open_edges)))

    for f in bm.faces:
        f.smooth = smooth

    bmesh.ops.triangulate(bm, faces=[f for f in bm.faces if len(f.verts) > 4])
    tris = sum(len(f.verts) - 2 for f in bm.faces)
    data = bpy.data.meshes.new(name)
    bm.to_mesh(data)
    bm.free()

    # The paint is the one the exporter must take as COLOR_0.
    if len(data.color_attributes) > 0:
        data.color_attributes.active_color_index = 0
        data.color_attributes.render_color_index = 0

    obj = bpy.data.objects.new(name, data)
    bpy.context.collection.objects.link(obj)

    for m in mats:
        data.materials.append(m)

    obj.location = at
    print("PART %s: %d tris, closed" % (name, tris))
    return obj


def almond(half_w, half_h, per=10):
    points = []

    for i in range(per + 1):
        x = -half_w + 2.0 * half_w * i / per
        points.append((x, half_h * (1.0 - (x / half_w) ** 2)))

    for i in range(per - 1, 0, -1):
        x = -half_w + 2.0 * half_w * i / per
        points.append((x, -half_h * (1.0 - (x / half_w) ** 2)))

    return points


def inside(point, loop):
    x, z = point
    hit = False

    for i in range(len(loop)):
        x0, z0 = loop[i]
        x1, z1 = loop[(i + 1) % len(loop)]

        if (z0 > z) != (z1 > z) and x < x0 + (z - z0) * (x1 - x0) / (z1 - z0):
            hit = not hit

    return hit


def bevel_hard(bm, width):
    """Only the real corners: a bevel across a flat face's own triangles would
    chew it up."""
    hard = [e for e in bm.edges if e.is_manifold and e.calc_face_angle(0.0) > math.radians(25.0)]
    bmesh.ops.bevel(bm, geom=hard, offset=width, segments=1, affect="EDGES", profile=0.5, clamp_overlap=True)


def band(outer, inner, y0, y1, bevel=0.0):
    """A closed band between two loops of the same count, all clean quads."""
    bm = bmesh.new()
    rows = [[bm.verts.new((x, y1, z)) for x, z in outer], [bm.verts.new((x, y1, z)) for x, z in inner],
        [bm.verts.new((x, y0, z)) for x, z in inner], [bm.verts.new((x, y0, z)) for x, z in outer]]
    count = len(outer)

    for r in range(4):
        for i in range(count):
            k = (i + 1) % count
            a = rows[r]
            b = rows[(r + 1) % 4]
            bm.faces.new((a[i], b[i], b[k], a[k]))

    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)

    if bevel > 0.0:
        bevel_hard(bm, bevel)

    return bm


def ring(outer, inner, y0, y1, bevel=0.0):
    """A slab with the outline `outer` and a hole `inner`, y0 to y1 deep."""
    bm = bmesh.new()
    edges = []

    for loop in (outer, inner):
        verts = [bm.verts.new((x, y1, z)) for x, z in loop]

        for i in range(len(verts)):
            edges.append(bm.edges.new((verts[i], verts[(i + 1) % len(verts)])))

    filled = bmesh.ops.triangle_fill(bm, use_beauty=True, use_dissolve=False, edges=edges)
    drop = []

    for f in filled["geom"]:
        if isinstance(f, bmesh.types.BMFace):
            c = f.calc_center_median()

            if inside((c.x, c.z), inner):
                drop.append(f)

    bmesh.ops.delete(bm, geom=drop, context="FACES_ONLY")
    faces = list(bm.faces)
    made = bmesh.ops.extrude_face_region(bm, geom=faces + list(bm.edges) + list(bm.verts))
    moved = [v for v in made["geom"] if isinstance(v, bmesh.types.BMVert)]
    bmesh.ops.translate(bm, verts=moved, vec=(0.0, y0 - y1, 0.0))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)

    if bevel > 0.0:
        bevel_hard(bm, bevel)

    return bm


def dome(radius, half_angle, rings, segments, thickness, pole, behind=None, front=Vector((0.0, 1.0, 0.0))):
    """A closed shell about `pole`: outside, rim, inside. With `behind`, it runs
    only that far from the pole on the side away from `front`, easing round to
    half_angle on the side toward it."""
    turn = pole.to_track_quat("Z", "Y").to_matrix()
    # The way round the pole that points at `front`.
    local_front = turn.inverted() @ front
    facing = math.atan2(local_front.y, local_front.x)
    bm = bmesh.new()
    loops = {}

    for layer, r in (("out", radius), ("in", radius - thickness)):
        top = bm.verts.new(turn @ Vector((0.0, 0.0, r)))
        rows = []

        for i in range(1, rings + 1):
            row = []

            for j in range(segments):
                around = TAU * j / segments
                reach = half_angle

                if behind is not None:
                    # Full over the whole front: it only draws in round the back.
                    toward = max(0.0, min(1.0, (math.cos(around - facing) + 0.75) / 0.9))
                    reach = behind + (half_angle - behind) * toward

                a = reach * i / rings
                row.append(bm.verts.new(turn @ (Vector((math.sin(a) * math.cos(around), math.sin(a) * math.sin(around), math.cos(a))) * r)))

            rows.append(row)

        loops[layer] = rows

        for j in range(segments):
            k = (j + 1) % segments
            bm.faces.new((top, rows[0][j], rows[0][k]) if layer == "out" else (top, rows[0][k], rows[0][j]))

            for i in range(rings - 1):
                quad = (rows[i][j], rows[i + 1][j], rows[i + 1][k], rows[i][k])
                bm.faces.new(quad if layer == "out" else tuple(reversed(quad)))

    for j in range(segments):
        k = (j + 1) % segments
        bm.faces.new((loops["out"][-1][j], loops["in"][-1][j], loops["in"][-1][k], loops["out"][-1][k]))

    return bm


TAU = math.tau


def add_box(bm, size, at, bevel=0.012):
    made = bmesh.ops.create_cube(bm, size=1.0)
    verts = made["verts"]
    bmesh.ops.scale(bm, vec=size, verts=verts)
    bmesh.ops.translate(bm, vec=at, verts=verts)
    edges = list({e for v in verts for e in v.link_edges})
    bmesh.ops.bevel(bm, geom=edges, offset=bevel, segments=1, affect="EDGES", profile=0.5, clamp_overlap=True)


def smooth(edge0, edge1, x):
    t = max(0.0, min(1.0, (x - edge0) / (edge1 - edge0)))
    return t * t * (3.0 - 2.0 * t)


def paint_ball():
    """Clean cream round an amber iris with a jade edge, and a few real veins that
    run in from the rim and fork, thick to thin. Mapped flat from the front
    (ball_uv), so the middle of the picture is where it looks."""
    size = 512
    image = bpy.data.images.new("eye_ball", size, size, alpha=False)
    rng = random.Random(11)
    veins = {}

    def stamp(x, y, width, strength):
        reach = int(width + 2)

        for py in range(int(y) - reach, int(y) + reach + 1):
            for px in range(int(x) - reach, int(x) + reach + 1):
                d = math.hypot(px - x, py - y)
                k = strength * (1.0 - smooth(width - 0.7, width + 0.7, d))

                if k > veins.get((px, py), 0.0):
                    veins[(px, py)] = k

    def walk(a, r, width, forks):
        # It wanders by turning, little by little, so it stays one line.
        drift = rng.uniform(-0.004, 0.004)

        while r > IRIS_ANGLE * 0.86 and width > 0.4:
            drift = drift * 0.97 + rng.uniform(-0.0008, 0.0008)
            a += drift
            r -= 0.0028
            width *= 0.9965
            stamp((0.5 + math.cos(a) * r * 0.5) * size, (0.5 + math.sin(a) * r * 0.5) * size, width, 0.85)

            if forks > 0 and rng.random() < 0.012:
                walk(a + rng.choice((-1.0, 1.0)) * 0.02, r, width * 0.72, forks - 1)

    for start in range(9):
        walk(TAU * start / 9.0 + rng.uniform(-0.25, 0.25), 0.97, rng.uniform(1.6, 2.4), 2)

    pixels = [0.0] * (size * size * 4)

    for y in range(size):
        for x in range(size):
            u = (x + 0.5) / size * 2.0 - 1.0
            v = (y + 0.5) / size * 2.0 - 1.0
            r = math.hypot(u, v)
            angle = math.asin(min(r, 1.0))
            turn = math.atan2(v, u)
            out = smooth(0.5, 1.2, angle)
            c = [0.74 - 0.2 * out, 0.68 - 0.26 * out, 0.5 - 0.26 * out]
            vein = veins.get((x, y), 0.0)
            c = [c[0] * (1.0 - vein) + 0.3 * vein, c[1] * (1.0 - vein) + 0.018 * vein, c[2] * (1.0 - vein) + 0.018 * vein]
            # The iris, drawn rather than rendered: flat hard bands, a heavy black
            # ring, and black strokes tapering in from it.
            t = angle / IRIS_ANGLE

            if t < 1.0:
                band_colour = (0.86, 0.46, 0.05) if t < 0.62 else ((0.62, 0.2, 0.025) if t < 0.84 else (0.05, 0.16, 0.11))
                teeth = 0.5 + 0.5 * math.cos(turn * 24.0)
                # A stroke runs in from the rim, narrowing as it comes.
                stroke_in = t > 0.5 + 0.5 * (1.0 - teeth ** 6)
                k = 0.0 if stroke_in else 1.0
                edge = smooth(0.97, 0.9, t)
                c = [band_colour[i] * k * edge + 0.008 for i in range(3)]
            elif t < 1.1:
                c = [0.008, 0.007, 0.007]

            at = (y * size + x) * 4
            pixels[at:at + 4] = [c[0], c[1], c[2], 1.0]

    image.pixels = pixels
    image.pack()
    return image


def ball_uv(bm):
    layer = bm.loops.layers.uv.new("UVMap")

    for f in bm.faces:
        for loop in f.loops:
            n = loop.vert.co.normalized()
            loop[layer].uv = (0.5 + n.x * 0.5, 0.5 + n.z * 0.5)


def build():
    tezontle = material("tezontle", TEZONTLE, roughness=0.95, painted=paint_stone("tezontle", TEZONTLE, 3, 260, 90, 5, (0.3, 0.075, 0.042), (0.11, 0.022, 0.024)), toned=True)
    cantera = material("cantera", CANTERA, roughness=0.9, painted=paint_stone("cantera", CANTERA, 8, 240, 26, 7, (0.52, 0.46, 0.34), (0.24, 0.23, 0.22)), toned=True)
    black = material("socket", SOCKET_BLACK, roughness=0.6)
    flesh = material("lid", (1.0, 1.0, 1.0), roughness=0.6, toned=True)
    back_stone = material("back_stone", (TEZONTLE[0] * 0.55, TEZONTLE[1] * 0.55, TEZONTLE[2] * 0.55), roughness=0.95)
    tin = material("milagro_tin", TIN, metallic=0.75, roughness=0.42)
    wet = material("wet_meat", (1.0, 1.0, 1.0), roughness=0.28, toned=True)
    bone = material("spine", (1.0, 1.0, 1.0), roughness=0.55, toned=True)
    nerve = material("nerve", (1.0, 1.0, 1.0), roughness=0.3, toned=True)
    pupil_black = material("pupil", PUPIL_BLACK, roughness=0.2)
    white = material("eye_ball", (1.0, 1.0, 1.0), roughness=0.5)
    nodes = white.node_tree
    tex = nodes.nodes.new("ShaderNodeTexImage")
    tex.image = paint_ball()
    nodes.links.new(tex.outputs["Color"], nodes.nodes.get("Principled BSDF").inputs["Base Color"])

    parts = {}
    outer = [(x * UNIT, z * UNIT) for x, z in STEPS]
    hole = almond(*ALMOND_HALF)
    rim_hole = almond(*ALMOND_HALF, 16)
    rim_out = almond(ALMOND_HALF[0] * RIM_GROW[0], ALMOND_HALF[1] * RIM_GROW[1], 16)
    # Lit from above, blacks spotted in low down: Mignola's shadow, painted in.
    stone_tone = lambda co: 0.58 + 0.42 * smooth(-0.34, 0.2, co.z)
    parts["Frame"] = solid("Frame", ring(outer, hole, FRAME_Y[0], FRAME_Y[1], bevel=0.012), [tezontle], mapped=True, tone=stone_tone, ink=0.018)
    inner_tier = [(x * TIER_SCALE, z * TIER_SCALE) for x, z in outer]
    parts["Tier"] = solid("Tier", ring(inner_tier, hole, TIER_Y[0], TIER_Y[1], bevel=0.01), [tezontle], mapped=True, tone=stone_tone, ink=0.015)
    parts["Rim"] = solid("Rim", band(rim_out, rim_hole, RIM_Y[0], RIM_Y[1], bevel=0.008), [cantera], mapped=True, tone=lambda co: 0.5 + 0.5 * smooth(-0.26, 0.2, co.z), ink=0.012)

    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=14, v_segments=8, radius=SOCKET_RADIUS)
    bmesh.ops.scale(bm, vec=(1.0, SOCKET_FLAT, 1.0), verts=bm.verts)
    parts["Socket"] = solid("Socket", bm, [black], SOCKET_AT, smooth=True)
    # The meat: behind everything, through the crown's notches, packed round the ball.
    lumps = [(Vector((0.0, -0.11, 0.0)), 0.3), (Vector((0.12, -0.14, 0.1)), 0.2), (Vector((-0.15, -0.13, -0.08)), 0.2), (Vector((0.02, -0.2, -0.14)), 0.16)]

    for x, z in [(66, 90), (-66, 90), (102, 62), (-102, 62), (102, -56), (-102, -56), (66, -88), (-66, -88), (30, 118), (-30, 118), (138, 30), (-138, -30)]:
        at = Vector((x * UNIT, 0.0, z * UNIT))
        lumps.append((Vector((at.x * 0.96, -0.01, at.z * 0.96)), 0.085))
        lumps.append((Vector((at.x * 1.02, 0.08, at.z * 1.02)), 0.05))

    for x, z in almond(ALMOND_HALF[0] * 0.99, ALMOND_HALF[1] * 1.02, 11):
        reach = math.hypot(x, z)
        y = BALL_AT.y + math.sqrt(max(BALL_RADIUS ** 2 - reach ** 2, 0.0)) if reach < BALL_RADIUS else 0.09
        lumps.append((Vector((x, min(y, 0.17), z)), 0.042))

    parts["Flesh"] = blob("Flesh", lumps, 0.016, 0.024, 0.14, meat_colour, [wet])

    # Maguey spines, driven through the crown into the meat.
    bm = bmesh.new()
    bases = [Vector((0.08, 0.04, 0.2)), Vector((-0.2, 0.05, 0.16)), Vector((0.26, 0.04, -0.03)), Vector((-0.24, 0.04, -0.14)), Vector((0.12, 0.04, -0.22)), Vector((-0.05, 0.05, 0.27))]
    tips = [Vector((0.2, 0.3, 0.62)), Vector((-0.55, 0.22, 0.42)), Vector((0.72, 0.26, 0.1)), Vector((-0.66, 0.2, -0.36)), Vector((0.3, 0.27, -0.58)), Vector((-0.12, 0.2, 0.7))]

    for base, tip in zip(bases, tips):
        add_spine(bm, base, tip, 0.024)

    paint_verts(bm, spine_colour_from(bases))
    parts["Spines"] = solid("Spines", bm, [bone], smooth=False)

    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=28, v_segments=14, radius=BALL_RADIUS)
    # Its poles out of sight: top and bottom, under the lids.
    ball_uv(bm)
    parts["Ball"] = solid("Ball", bm, [white], BALL_AT, smooth=True)

    parts["Pupil"] = solid("Pupil", dome(BALL_RADIUS + 0.004, PUPIL_ANGLE, 2, 20, 0.003, Vector((0.0, 1.0, 0.0))), [pupil_black], BALL_AT, smooth=True)

    top_pole = Vector((0.0, -math.sin(TOP_LID_TIP), math.cos(TOP_LID_TIP)))
    bottom_pole = Vector((0.0, -math.sin(LID_TIP), -math.cos(LID_TIP)))
    # The lash line: each lid goes to black along its edge.
    edge_of = lambda pole: (lambda co: (1.0 - 0.94 * smooth(0.5, 0.2, co.normalized().dot(pole))) * (0.55 + 0.45 * (0.5 + 0.5 * math.sin(math.acos(max(-1.0, min(1.0, co.normalized().dot(pole)))) * 26.0))))
    top_lid = dome(LID_RADIUS, LID_HALF, 11, 24, LID_THICK, top_pole, LID_BEHIND)
    bottom_lid = dome(BOTTOM_LID_RADIUS, LID_HALF, 11, 24, 0.006, bottom_pole, LID_BEHIND)
    wrinkle(top_lid, top_pole, 0.007)
    wrinkle(bottom_lid, bottom_pole, 0.0035)
    parts["LidTop"] = solid("LidTop", top_lid, [flesh], BALL_AT, smooth=True, tone=edge_of(top_pole), tint=LID_FLESH)
    parts["LidBottom"] = solid("LidBottom", bottom_lid, [flesh], BALL_AT, smooth=True, tone=edge_of(bottom_pole), tint=LID_FLESH)

    # Two spines through the upper lid, which ride with it.
    bm = bmesh.new()
    in_lid = [Vector((0.12, 0.21, 0.2)), Vector((-0.1, 0.24, 0.17))]
    out_lid = [Vector((0.28, 0.43, 0.42)), Vector((-0.3, 0.46, 0.38))]

    for base, tip in zip(in_lid, out_lid):
        add_spine(bm, base, tip, 0.015, 5, 3)

    paint_verts(bm, spine_colour_from(in_lid))
    parts["LidSpines"] = solid("LidSpines", bm, [bone], BALL_AT)
    parts["LidSpines"].parent = parts["LidTop"]
    parts["LidSpines"].location = Vector((0.0, 0.0, 0.0))

    # The torn nerve: a thick cord threaded through the last stones of the crown,
    # the milagro nailed into it. U says how free each part is to sway.
    bm = bmesh.new()
    uv = bm.loops.layers.uv.new("UVMap")
    path = [Vector((0.0, -0.06, 0.1)), Vector((0.01, -0.01, -0.02)), Vector((-0.02, 0.0, -0.12)), Vector((0.03, 0.0, -0.21)), Vector((-0.02, 0.0, -0.31)), Vector((0.02, 0.0, -0.41)), Vector((-0.04, 0.0, -0.52)), Vector((-0.01, 0.0, -0.62)), Vector((-0.05, 0.0, -0.72))]
    widths = [0.058, 0.052, 0.044, 0.05, 0.036, 0.04, 0.026, 0.02, 0.006]
    path, widths = curve(path, widths)
    weights = [max(0.0, -p.z) / 0.72 for p in path]
    sweep(bm, path, widths, 8, weights, uv)
    tones = {}
    tones_of_nerve = lambda co: meat_colour(co)
    before = set(bm.verts)
    add_box(bm, (0.13, 0.11, 0.08), (0.005, 0.0, -0.05))
    add_box(bm, (0.1, 0.09, 0.07), (0.03, 0.0, -0.24))
    stones = set(bm.verts) - before
    heart = [(0.0, -0.075), (0.055, -0.015), (0.062, 0.022), (0.036, 0.045), (0.0, 0.025), (-0.036, 0.045), (-0.062, 0.022), (-0.055, -0.015)]
    down = -0.46
    front = [bm.verts.new((x + 0.02, 0.058, z + down)) for x, z in heart]
    back = [bm.verts.new((x + 0.02, 0.04, z + down)) for x, z in heart]
    bm.faces.new(front)
    bm.faces.new(list(reversed(back)))

    for i in range(len(heart)):
        k = (i + 1) % len(heart)
        bm.faces.new((front[i], back[i], back[k], front[k]))

    tin_verts = set(front + back)
    before = set(bm.verts)
    add_box(bm, (0.014, 0.13, 0.014), (0.02, 0.0, down + 0.012), bevel=0.003)
    nail = set(bm.verts) - before
    colour_layer = bm.loops.layers.color.new("Color")

    for f in bm.faces:
        for loop in f.loops:
            v = loop.vert

            if v in stones:
                c = (TEZONTLE[0] * 0.8, TEZONTLE[1] * 0.8, TEZONTLE[2] * 0.8)
            elif v in tin_verts:
                c = (0.52, 0.5, 0.44)
            elif v in nail:
                c = (0.03, 0.025, 0.02)
            else:
                c = meat_colour(v.co)

            loop[colour_layer] = paint_value(c)

            if v in stones or v in tin_verts or v in nail:
                loop[uv].uv = (max(0.0, -v.co.z) / 0.72, 0.0)

    parts["Nerve"] = solid("Nerve", bm, [nerve], TAIL_AT, smooth=True)

    # Shreds of nerve torn from behind it, trailing. Each starts inside the meat.
    bm = bmesh.new()
    uv = bm.loops.layers.uv.new("UVMap")
    rng = random.Random(5)

    for i in range(6):
        turn = TAU * i / 6.0 + rng.uniform(-0.3, 0.3)
        start = Vector((math.cos(turn) * 0.2, -0.26, math.sin(turn) * 0.2 - 0.04))
        length = rng.uniform(0.3, 0.55)
        points = []

        for j in range(6):
            t = j / 5.0
            points.append(start + Vector((math.cos(turn) * t * 0.1 + math.sin(t * 7.0 + i) * 0.025, -t * length * 0.9, -t * length * 0.5 + math.sin(t * 5.0 + i * 2.0) * 0.02)))

        points, thick = curve(points, [0.018 * (1.0 - t / 6.0) + 0.002 for t in range(6)], 3)
        sweep(bm, points, thick, 5, [t / (len(points) - 1.0) for t in range(len(points))], uv)

    paint_verts(bm, lambda co: (0.3 + 0.2 * math.sin(co.x * 40.0), 0.05, 0.05))
    parts["Shreds"] = solid("Shreds", bm, [nerve], Vector((0.0, 0.0, 0.0)), smooth=True)
    return parts


def blob(name, lumps, voxel, roughness, keep, colour_of, mats, at=Vector((0.0, 0.0, 0.0))):
    """Lumps run together into one closed, organic skin: voxel-remeshed, roughened
    with noise, thinned to `keep` of its faces, and coloured."""
    bm = bmesh.new()

    for centre, radius in lumps:
        made = bmesh.ops.create_icosphere(bm, subdivisions=2, radius=radius)
        bmesh.ops.translate(bm, vec=centre, verts=made["verts"])

    data = bpy.data.meshes.new(name + "_lumps")
    bm.to_mesh(data)
    bm.free()
    obj = bpy.data.objects.new(name + "_lumps", data)
    bpy.context.collection.objects.link(obj)
    remesh = obj.modifiers.new("remesh", "REMESH")
    remesh.mode = "VOXEL"
    remesh.voxel_size = voxel
    remesh.use_smooth_shade = True
    noise = bpy.data.textures.new(name + "_noise", "CLOUDS")
    noise.noise_scale = 0.05
    displace = obj.modifiers.new("displace", "DISPLACE")
    displace.texture = noise
    displace.strength = roughness
    displace.mid_level = 0.5
    thin = obj.modifiers.new("thin", "DECIMATE")
    thin.ratio = keep
    depsgraph = bpy.context.evaluated_depsgraph_get()
    done = obj.evaluated_get(depsgraph).to_mesh()
    out = bmesh.new()
    out.from_mesh(done)
    obj.evaluated_get(depsgraph).to_mesh_clear()
    bpy.data.objects.remove(obj, do_unlink=True)
    bmesh.ops.recalc_face_normals(out, faces=out.faces)
    layer = out.loops.layers.color.new("Color")
    open_now = [e for e in out.edges if not e.is_manifold]

    if open_now:
        bmesh.ops.holes_fill(out, edges=open_now, sides=8)

    for f in out.faces:
        for loop in f.loops:
            loop[layer] = paint_value(colour_of(loop.vert.co))

    return solid(name, out, mats, at, smooth=True)


def meat_colour(co):
    """Dark liver in the folds, wet red on the swells, yellow fat here and there."""
    a = 0.5 + 0.5 * math.sin(co.x * 31.0 + math.sin(co.z * 27.0) * 2.0) * math.sin(co.y * 23.0 + co.z * 19.0)
    b = smooth(0.62, 0.9, 0.5 + 0.5 * math.sin(co.x * 13.0 - co.z * 17.0 + math.sin(co.y * 29.0)))
    # Flat reds in big shapes: liver in the folds, blood on the swells.
    a = smooth(0.3, 0.62, a)
    c = (0.08 + a * 0.4, 0.008 + a * 0.03, 0.012 + a * 0.025)
    b *= 0.35
    return (c[0] * (1.0 - b) + 0.42 * b, c[1] * (1.0 - b) + 0.2 * b, c[2] * (1.0 - b) + 0.08 * b)


def add_spine(bm, base, tip, radius, sides=6, rings=4, bloody=None):
    """A maguey thorn: a slightly bent closed cone."""
    way = tip - base
    length = way.length
    turn = way.to_track_quat("Z", "Y").to_matrix()
    bend = turn @ Vector((length * 0.06, 0.0, 0.0))
    rows = []

    for i in range(rings):
        t = i / rings
        r = radius * (1.0 - t) ** 0.8
        middle = base + way * t + bend * math.sin(t * math.pi)
        rows.append([bm.verts.new(middle + turn @ Vector((math.cos(TAU * j / sides) * r, math.sin(TAU * j / sides) * r, 0.0))) for j in range(sides)])

    point = bm.verts.new(tip)

    for j in range(sides):
        k = (j + 1) % sides

        for i in range(rings - 1):
            bm.faces.new((rows[i][j], rows[i][k], rows[i + 1][k], rows[i + 1][j]))

        bm.faces.new((rows[-1][j], rows[-1][k], point))

    bm.faces.new(list(reversed(rows[0])))


def spine_colour_from(bases):
    """Pale bone at the tip, blackened and blooded toward where it went in."""
    def colour(co):
        near = min((co - b).length for b in bases)
        k = smooth(0.02, 0.17, near)
        return (0.09 + k * 0.27, 0.01 + k * 0.23, 0.01 + k * 0.15)

    return colour


def paint_verts(bm, colour_of):
    layer = bm.loops.layers.color.new("Color")

    for f in bm.faces:
        for loop in f.loops:
            loop[layer] = paint_value(colour_of(loop.vert.co))


def sweep(bm, points, radii, sides, weights=None, uv=None):
    """A closed tube along `points`, each with its radius. Its U is `weights` (how
    free that point is to sway, for the game's shader)."""
    rows = []
    previous = Vector((1.0, 0.0, 0.0))

    for i, p in enumerate(points):
        ahead = points[min(i + 1, len(points) - 1)] - points[max(i - 1, 0)]
        ahead.normalize()
        side = (previous - ahead * previous.dot(ahead)).normalized()
        other = ahead.cross(side)
        previous = side
        rows.append([bm.verts.new(p + (side * math.cos(TAU * j / sides) + other * math.sin(TAU * j / sides)) * radii[i]) for j in range(sides)])

    made = [bm.faces.new(list(reversed(rows[0])))]

    for i in range(len(rows) - 1):
        for j in range(sides):
            k = (j + 1) % sides
            made.append(bm.faces.new((rows[i][j], rows[i][k], rows[i + 1][k], rows[i + 1][j])))

    made.append(bm.faces.new(rows[-1]))

    if uv is not None and weights is not None:
        lookup = {}

        for i, row in enumerate(rows):
            for v in row:
                lookup[v] = weights[i]

        for f in made:
            for loop in f.loops:
                loop[uv].uv = (lookup[loop.vert], 0.0)


def curve(points, values, per=4):
    """Catmull-Rom through `points`, with `values` eased along it."""
    out_points = []
    out_values = []

    for i in range(len(points) - 1):
        p0 = points[max(i - 1, 0)]
        p1 = points[i]
        p2 = points[i + 1]
        p3 = points[min(i + 2, len(points) - 1)]

        for j in range(per):
            t = j / per
            out_points.append(0.5 * ((2.0 * p1) + (p2 - p0) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t * t + (3.0 * p1 - p0 - 3.0 * p2 + p3) * t * t * t))
            out_values.append(values[i] + (values[i + 1] - values[i]) * t)

    out_points.append(points[-1])
    out_values.append(values[-1])
    return out_points, out_values


def wrinkle(bm, pole, depth):
    """Folds running along a lid: the skin bunched as it pulls back."""
    for v in bm.verts:
        if v.co.length > LID_RADIUS - 0.012 or depth < 0.0:
            a = math.acos(max(-1.0, min(1.0, v.co.normalized().dot(pole))))
            fold = 0.5 + 0.5 * math.sin(a * 26.0)
            v.co = v.co.normalized() * (v.co.length + fold * depth)


def lights_and_camera():
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_EEVEE"
    scene.render.resolution_x = 900
    scene.render.resolution_y = 900
    world = bpy.data.worlds.new("World")
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs[0].default_value = (0.2, 0.21, 0.24, 1.0)
    world.node_tree.nodes["Background"].inputs[1].default_value = 0.7
    scene.world = world
    sun = bpy.data.objects.new("Sun", bpy.data.lights.new("Sun", "SUN"))
    sun.data.energy = 3.0
    sun.rotation_euler = (math.radians(-65), math.radians(-25), math.radians(0))
    bpy.context.collection.objects.link(sun)
    camera = bpy.data.objects.new("Camera", bpy.data.cameras.new("Camera"))
    camera.data.lens = 60
    bpy.context.collection.objects.link(camera)
    scene.camera = camera
    return scene, camera, sun


def shot(scene, camera, at, name, target=Vector((0.0, 0.1, -0.1))):
    camera.location = at
    camera.rotation_euler = (target - camera.location).to_track_quat("-Z", "Y").to_euler()
    scene.render.filepath = os.path.join(SOURCE, "eye_%s.png" % name)
    bpy.ops.render.render(write_still=True)


def main():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    os.makedirs(SOURCE, exist_ok=True)
    parts = build()
    scene, camera, sun = lights_and_camera()
    shot(scene, camera, Vector((0.0, 3.3, -0.15)), "front", Vector((0.0, 0.1, -0.15)))
    shot(scene, camera, Vector((1.9, 2.5, 0.55)), "three_quarter", Vector((0.0, 0.05, -0.15)))
    shot(scene, camera, Vector((3.2, 0.1, -0.15)), "side", Vector((0.0, 0.0, -0.15)))
    shot(scene, camera, Vector((0.7, -3.0, 0.3)), "back", Vector((0.0, 0.0, -0.15)))
    shot(scene, camera, Vector((0.45, 1.0, 0.25)), "close", Vector((0.0, 0.2, 0.0)))
    shot(scene, camera, Vector((0.0, 0.5, -0.75)), "under", Vector((0.0, 0.1, -0.3)))
    parts["LidTop"].rotation_euler = (-math.radians(24.0), 0.0, 0.0)
    parts["LidBottom"].rotation_euler = (math.radians(38.0), 0.0, 0.0)
    shot(scene, camera, Vector((1.5, 2.0, 0.5)), "shut")
    shot(scene, camera, Vector((0.45, 1.0, 0.25)), "shut_close", Vector((0.0, 0.2, 0.0)))
    parts["LidTop"].rotation_euler = (0.0, 0.0, 0.0)
    parts["LidBottom"].rotation_euler = (0.0, 0.0, 0.0)
    bpy.data.objects.remove(sun, do_unlink=True)
    bpy.data.objects.remove(camera, do_unlink=True)
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(SOURCE, "floating_eye.blend"))
    bpy.ops.export_scene.gltf(filepath=GLB, export_format="GLB", export_yup=True, export_materials="EXPORT", export_normals=True, export_apply=False, export_vertex_color="ACTIVE", export_all_vertex_colors=False)
    print("WROTE", GLB)


main()
