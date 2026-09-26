"""Builds what a recipe says into its source .blend (spec §6.3).

    tools/wardrobe/wardrobe.sh build watchman [--force]

A kind: the Quaternius body cut down to PS2 size; the garments made on it
(shells of the body pushed out, lofted skirts and panels, rings, props);
the body they hide cut away; weights copied from the full body; cloth bones
for what swings; one UV atlas. Saved as source/<kind>.blend: `Outfit` on
`Armature`, with the full body kept (hidden) as `Reference`.

Everything symmetric is built on his left half (+X) and mirrored, so both
halves share their texels, as PS2 artists did; props (a pouch on one hip, a
scabbard on the other) are built whole.

Refuses to overwrite a file edited by hand since its last build, unless
--force; a dated backup is kept either way (source/backup).
"""

import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import bmesh  # noqa: E402
import bpy  # noqa: E402
from mathutils import Matrix, Vector  # noqa: E402
from mathutils.kdtree import KDTree  # noqa: E402

import common  # noqa: E402
import recipes  # noqa: E402

# Texels per metre, relative: more where the eye goes, less on soles.
DENSITY = {"base": 0.8, "shell": 1.0, "mittens": 0.8, "boots": 0.8, "collar": 0.8, "skirt": 1.0,
           "tabard": 1.3, "belt": 0.8, "prop": 0.6}
SKIN = (0.78, 0.6, 0.5)
# How far under a garment a body face still counts as covered, when the
# build cuts the hidden body away (validation is stricter: thickness + 5 mm).
COVERED = 0.1
# How far past its thickness a smoothed garment may stand.
BULGE = 0.015


def main():
    target, options = common.args()

    if target in recipes.KINDS:
        build_kind(recipes.KINDS[target], bool(options.get("force")))
    elif target == "heads":
        build_heads(bool(options.get("force")))
    elif target == "headgear":
        build_headgear(bool(options.get("force")))
    else:
        common.fail("nothing to build called '%s'" % target)


def guard(path, force):
    """Stops a build that would lose hand edits (see the module's doc)."""
    if not path.exists() or force:
        return

    bpy.ops.wm.open_mainfile(filepath=str(path))
    scene = bpy.context.scene
    stored = scene.get("wardrobe_hash")
    made = [bpy.data.objects[name] for name in scene.get("wardrobe_objects", []) if name in bpy.data.objects]

    if stored and made and common.generated_hash(made) != stored:
        common.fail("%s was edited by hand since the last build; use --force to build over it" % path.name)


# ---------------------------------------------------------------------------
# A kind
# ---------------------------------------------------------------------------

class Kind:
    """What one build knows: the recipe, the skeleton, the full body, and
    what has been made so far."""

    def __init__(self, recipe, armature, reference):
        self.recipe = recipe
        self.arm = armature
        self.ref = reference
        self.ref_tree = common.bvh([reference])
        self.base = None
        self.parts = []
        self.props = []
        self.chains = {}
        self.made = {}
        self.rims = {}
        self.types = {}
        # The base's faces a shell was made from: under that shell, gone.
        self.covered = set()

    def at(self, spec):
        return common.point(self.arm, spec)

    def z(self, spec):
        return self.at(spec).z

    def normal_at(self, co):
        normal = self.ref_tree.find_nearest(co)[1]
        return normal if normal is not None else Vector((0.0, 0.0, 1.0))

    def centre(self, z):
        """The middle of his trunk at height z (front to back, on x = 0)."""
        ys = [v.co.y for v in self.ref.data.vertices if abs(v.co.z - z) < 0.015 and abs(v.co.x) < 0.3]
        return Vector((0.0, (min(ys) + max(ys)) * 0.5 if ys else 0.02, z))

    def belt_z(self):
        return self.z(self.recipe["belt"])

    def add(self, obj, g, part, kind, strip=False, dye=False, fabric=None, colour=None, whole=False):
        common.set_faces(obj, part, recipes.FABRICS.index(fabric or g["fabric"]), g.get("thickness", 0.004), strip, dye,
                         colour or g["colour"])
        self.types[obj.name] = kind
        (self.props if whole else self.parts).append(obj)
        self.made.setdefault(g["name"], obj)
        return obj


def build_kind(recipe, force):
    path = common.SOURCE / ("%s.blend" % recipe["kind"])
    guard(path, force)
    common.scene_fresh("AUCOD_%s" % recipe["kind"])
    armature, reference, extras = common.import_quaternius(recipe["body"])

    for extra in extras:
        bpy.data.objects.remove(extra)

    armature.name = "Armature"
    reference.name = "Reference"
    kind = Kind(recipe, armature, reference)
    kind.base = low_poly_base(kind)

    for part, g in enumerate(recipe["garments"], start=1):
        BUILDERS[g["type"]](kind, g, part)

    hide_body(kind)
    # A body wholly covered (the watchman's) leaves nothing to unwrap.
    everything = [obj for obj in [kind.base] + kind.parts + kind.props if len(obj.data.polygons) > 0]
    common.unwrap(everything, {obj.name: DENSITY[kind.types.get(obj.name, "base")] for obj in everything})

    for obj in [kind.base] + kind.parts:
        if len(obj.data.polygons) > 0:
            common.mirror(obj)
            swap_sides(obj)

    outfit = join([kind.base] + kind.parts + kind.props)
    materials(outfit)
    weigh(outfit, reference)
    chains = add_chains(kind)
    outfit.parent = armature
    modifier = outfit.modifiers.new("Armature", "ARMATURE")
    modifier.object = armature
    reference.hide_render = True
    reference.hide_set(True)

    scene = bpy.context.scene
    scene["wardrobe_kind"] = recipe["kind"]
    scene["wardrobe_chains"] = common.dump(chains)
    scene["wardrobe_probe"] = common.dump(probes(outfit, reference))
    scene["wardrobe_objects"] = ["Outfit"]
    scene["wardrobe_hash"] = common.generated_hash([outfit])
    common.save(path)
    print("wardrobe: built %s: Outfit %d triangles, %d cloth bones" % (path.name, common.tri_count(outfit), sum(len(c["bones"]) for c in chains)))


def low_poly_base(kind):
    """His left half, without the head (a part of its own) or the hands if
    mittens replace them, cut to half the recipe's triangles."""
    base = kind.ref.copy()
    base.data = kind.ref.data.copy()
    base.name = "Base"
    base.modifiers.clear()
    base.parent = None
    bpy.context.scene.collection.objects.link(base)
    common.weld(base)
    common.keep_positive_x(base)
    dropped = {"head"} | ({"hand"} if any(g["type"] == "mittens" for g in kind.recipe["garments"]) else set())
    regions = common.vertex_regions(base)
    bm = bmesh.new()
    bm.from_mesh(base.data)
    doomed = [face for face in bm.faces if majority([regions[v.index] for v in face.verts]) in dropped]
    bmesh.ops.delete(bm, geom=doomed, context="FACES")
    bm.to_mesh(base.data)
    bm.free()
    decimate = base.modifiers.new("Decimate", "DECIMATE")
    decimate.ratio = min(1.0, kind.recipe["base_tris"] * 0.5 / max(common.tri_count(base), 1))
    decimate.use_collapse_triangulate = True
    common.select_only([base])
    bpy.ops.object.modifier_apply(modifier=decimate.name)

    bm = bmesh.new()
    bm.from_mesh(base.data)

    for vertex in bm.verts:
        if abs(vertex.co.x) < 0.002:
            vertex.co.x = 0.0

    # Faces lying in the mirror plane (decimation leaves slivers there) are
    # walls inside him once mirrored: gone.
    flat = [f for f in bm.faces if all(v.co.x == 0.0 for v in f.verts) or f.calc_area() < 1e-8]
    bmesh.ops.delete(bm, geom=flat, context="FACES")
    bmesh.ops.dissolve_degenerate(bm, dist=1e-5, edges=bm.edges[:])
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context="VERTS")
    bm.to_mesh(base.data)
    bm.free()
    kind.types[base.name] = "base"
    return base


def majority(values):
    """The commonest value; ties go the same way on every run."""
    return max(sorted(set(values)), key=values.count)


def smoothstep(a, b, x):
    t = min(max((x - a) / (b - a), 0.0), 1.0)
    return t * t * (3.0 - 2.0 * t)


# ---------------------------------------------------------------------------
# Garments
# ---------------------------------------------------------------------------

def shell(kind, g, part):
    """Body regions copied from the low-poly base and pushed out by the
    fabric's thickness (and its padding); open edges turn in to the body so
    nothing shows through an opening. Keeps the base's weights."""
    z_lo = kind.z(g["bottom"]) if "bottom" in g else -1e9
    z_hi = kind.z(g["top"]) if "top" in g else 1e9
    x_hi = kind.at(g["sleeve_end"]).x - g.get("sleeve_back", 0.0) if "sleeve_end" in g else 1e9
    obj = kind.base.copy()
    obj.data = kind.base.data.copy()
    obj.name = g["name"]
    bpy.context.scene.collection.objects.link(obj)
    regions = common.vertex_regions(obj)
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    wanted = set(g["regions"])
    doomed = [f for f in bm.faces if not (majority([regions[v.index] for v in f.verts]) in wanted
                                          and z_lo <= f.calc_center_median().z <= z_hi and f.calc_center_median().x <= x_hi)]
    kind.covered |= {f.index for f in bm.faces} - {f.index for f in doomed}
    bmesh.ops.delete(bm, geom=doomed, context="FACES")
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context="VERTS")
    offset_verts(kind, bm, lambda co, n: g["thickness"] + pad(kind, g, co, n), g.get("smooth", 1))
    kind.rims[g["name"]] = [v.co.copy() for v in bm.verts if v.is_boundary]
    lips(bm, kind, g.get("lips", []))
    bm.to_mesh(obj.data)
    bm.free()
    kind.add(obj, g, part, "shell")


def offset_verts(kind, bm, amount, iterations=1):
    """Each vertex out along the full body's normal there by amount(co, n),
    then smoothed `iterations` times, each time pushed back out to at least
    that far from the body: a padded hull that loses the muscles under it.
    The seam stays on x = 0 and the rims stay put."""
    layer = bm.verts.layers.float_vector.get("wr_rest") or bm.verts.layers.float_vector.new("wr_rest")

    for vertex in bm.verts:
        vertex[layer] = vertex.co.copy()
        normal = kind.normal_at(vertex.co)
        seam = abs(vertex.co.x) < 1e-4
        vertex.co += normal * amount(vertex.co, normal)

        if seam:
            vertex.co.x = 0.0

    inner = [v for v in bm.verts if not v.is_boundary and abs(v.co.x) > 1e-4]
    seam = [v for v in bm.verts if not v.is_boundary and abs(v.co.x) <= 1e-4]

    for _ in range(iterations):
        bmesh.ops.smooth_vert(bm, verts=inner, factor=0.5, use_axis_x=True, use_axis_y=True, use_axis_z=True)
        bmesh.ops.smooth_vert(bm, verts=seam, factor=0.5, use_axis_x=False, use_axis_y=True, use_axis_z=True)

        for vertex in bm.verts:
            near, normal, _, _ = kind.ref_tree.find_nearest(vertex.co)

            if near is None:
                continue

            need = amount(vertex.co, normal)
            depth = (vertex.co - near).dot(normal)

            # Padded, not inflated: never under its thickness, never more
            # than BULGE past it (smoothing bridges hollows: the neck's slope
            # into the shoulder would stand far off him otherwise).
            if depth < need:
                vertex.co += normal * (need - depth)
            elif depth > need + BULGE:
                vertex.co -= normal * (depth - need - BULGE)

            if abs(vertex[layer].x) < 1e-4:
                vertex.co.x = 0.0


def lips(bm, kind, where):
    """Open edges turned in, back to where the body was, so nothing shows
    through an opening: at the sleeves (out along his arms) and the bottom
    (below the belt), as `where` asks. Never the seam."""
    layer = bm.verts.layers.float_vector.get("wr_rest")
    belt = kind.belt_z()

    def wanted(edge):
        mid = (edge.verts[0].co + edge.verts[1].co) * 0.5
        return ("sleeve" in where and mid.x > 0.45) or ("bottom" in where and mid.z < belt and mid.x < 0.45)

    edges = [e for e in bm.edges if e.is_boundary and not all(abs(v.co.x) < 1e-4 for v in e.verts) and wanted(e)]

    if not edges or layer is None:
        return

    rim = {v for e in edges for v in e.verts}
    tree = KDTree(len(rim))
    rim = list(rim)

    for i, vertex in enumerate(rim):
        tree.insert(vertex.co, i)

    tree.balance()
    made = bmesh.ops.extrude_edge_only(bm, edges=edges)["geom"]

    for vertex in (item for item in made if isinstance(item, bmesh.types.BMVert)):
        source = rim[tree.find(vertex.co)[1]]
        vertex.co = Vector(source[layer])


def pad(kind, g, co, normal):
    total = 0.0

    for p in g.get("pads", []):
        if abs(co.x) > 0.2 or (p.get("front") and normal.y > -0.2):
            continue

        z0, z1 = kind.z(p["from"]), kind.z(p["to"])
        window = smoothstep(z0 - 0.03, z0 + 0.03, co.z) * (1.0 - smoothstep(z1 - 0.03, z1 + 0.03, co.z))
        facing = min(1.0, (-normal.y - 0.2) / 0.5) if p.get("front") else 1.0
        total += p["amount"] * window * facing

    return total


def mittens(kind, g, part):
    """A mitten and a thumb on his left hand, lofted along the finger bones
    and sized off the full body's hand (the fingers as one)."""
    thick = 0.008
    wrist = kind.at(("hand_l", 0.0))
    knuckles = kind.at(("middle_01_l", 0.0))
    tips = kind.at(("middle_04_leaf_l", 1.0))
    stations = [wrist.x - g["cuff_into_sleeve"], wrist.x, knuckles.x, tips.x - 0.006]
    names = {group.index: group.name for group in kind.ref.vertex_groups}
    rings = []
    last = (wrist.y, wrist.z, 0.03, 0.025)

    for x in stations:
        near = [v for v in kind.ref.data.vertices if abs(v.co.x - x) < 0.008 and v.co.x > 0.5
                and not names[max(v.groups, key=lambda gr: gr.weight).group].startswith("thumb_")]

        if near:
            ys = [v.co.y for v in near]
            zs = [v.co.z for v in near]
            last = ((min(ys) + max(ys)) * 0.5, (min(zs) + max(zs)) * 0.5, (max(ys) - min(ys)) * 0.5 + thick,
                    (max(zs) - min(zs)) * 0.5 + thick)

        yc, zc, a, b = last
        rings.append([Vector((x, yc + a * math.cos(t), zc + b * math.sin(t))) for t in (math.radians(d) for d in range(0, 360, 60))])

    hand = common.loft("mittens", rings, closed=True, cap=Vector((tips.x + 0.004, last[0], last[1])))
    thumb = thumb_loft(kind)
    obj = join_two(hand, thumb, g["name"])
    outward(obj)
    common.group(obj, common.TRANSFER, 1.0)
    kind.add(obj, g, part, "mittens")


def thumb_loft(kind):
    points = [kind.at(("thumb_01_l", 0.0)), kind.at(("thumb_03_l", 0.0)), kind.at(("thumb_04_leaf_l", 0.7))]
    rings = []

    for i, p in enumerate(points):
        along = (points[min(i + 1, len(points) - 1)] - points[max(i - 1, 0)]).normalized()
        side = along.cross(Vector((0.0, 0.0, 1.0))).normalized()
        up = side.cross(along).normalized()
        a, b = (0.016, 0.013) if i < 1 else (0.013, 0.011)
        rings.append([p + side * a * math.cos(t) + up * b * math.sin(t) for t in (math.radians(d) for d in (45, 135, 225, 315))])

    return common.loft("thumb", rings, closed=True, cap=points[-1] + (points[-1] - points[-2]).normalized() * 0.008)


def join_two(a, b, name):
    common.select_only([a, b], active=a)
    bpy.ops.object.join()
    a.name = name
    a.data.name = name
    return a


def outward(obj):
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(obj.data)
    bm.free()


def boots(kind, g, part):
    """His feet and lower calves in leather, a thin sole under them, and a
    cuff turned down over the top."""
    top = kind.z(g["top"])
    obj = kind.base.copy()
    obj.data = kind.base.data.copy()
    obj.name = g["name"]
    bpy.context.scene.collection.objects.link(obj)
    regions = common.vertex_regions(obj)
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    doomed = [f for f in bm.faces if not (majority([regions[v.index] for v in f.verts]) in ("foot", "calf")
                                          and f.calc_center_median().z <= top)]
    kind.covered |= {f.index for f in bm.faces} - {f.index for f in doomed}
    bmesh.ops.delete(bm, geom=doomed, context="FACES")
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context="VERTS")
    offset_verts(kind, bm, lambda co, n: g["sole"] if n.z < -0.6 else g["thickness"], g.get("smooth", 1))
    bm.to_mesh(obj.data)
    bm.free()
    kind.add(obj, g, part, "boots")

    # The cuff, round the calf where the boot ends.
    # Over the whole rim (its jagged top included), so none of it shows.
    rim_top = max(v.co.z for v in obj.data.vertices) if obj.data.vertices else top
    rim_top = min(rim_top, top + 0.04)
    calf = kind.arm.data.bones["calf_l"]
    t = (calf.head_local.z - rim_top) / max(calf.head_local.z - calf.tail_local.z, 1e-6)
    centre = calf.head_local.lerp(calf.tail_local, t)
    tree = common.bvh([obj])
    ring0, ring1, ring2 = [], [], []

    # Its size is read a little below the rim, where the boot is whole.
    t_low = (calf.head_local.z - (top - 0.02)) / max(calf.head_local.z - calf.tail_local.z, 1e-6)
    low = calf.head_local.lerp(calf.tail_local, t_low)

    for d in range(0, 360, 45):
        direction = Vector((math.cos(math.radians(d)), math.sin(math.radians(d)), 0.0))
        hit = common.outer_hit(tree, low, direction, 0.3)
        radius = Vector((hit.x - low.x, hit.y - low.y, 0.0)).length if hit is not None else 0.065
        at = Vector((centre.x, centre.y, rim_top)) + direction * (radius + 0.004)
        ring0.append(at)
        ring1.append(at + direction * 0.01 + Vector((0.0, 0.0, 0.006)))
        ring2.append(at + direction * 0.02 - Vector((0.0, 0.0, g["cuff"])))

    cuff = common.loft("boots_cuff", [ring0, ring1, ring2], closed=True)
    common.group(cuff, common.TRANSFER, 1.0)
    kind.add(cuff, g, part, "boots", strip=True)


def collar(kind, g, part):
    """A standing collar on a shell's neck edge, leaning in to the throat."""
    rim = [p for p in kind.rims[g["on"]] if p.z > kind.z(("spine_03", 0.6)) and abs(p.x) < 0.17]
    axis = Vector((0.0, sum(p.y for p in rim) / len(rim), 0.0))
    ring0, ring1 = [], []

    floor = min(p.z for p in rim) - 0.01
    ceiling = max(p.z for p in rim)

    for d in [i * 22.5 for i in range(9)]:
        direction = Vector((math.sin(math.radians(d)), -math.cos(math.radians(d)), 0.0))
        best = max(rim, key=lambda p: Vector((p.x, p.y - axis.y, 0.0)).normalized().dot(direction))
        low = Vector((best.x, best.y, floor)) + direction * 0.01

        if d in (0.0, 180.0):
            low.x = 0.0

        flat = Vector((low.x, low.y - axis.y, 0.0))
        # Tall enough to stand over the whole rim, however ragged.
        high = low + Vector((0.0, 0.0, max(g["height"], ceiling - floor + 0.015))) - flat * g["lean_in"]
        ring0.append(low)
        ring1.append(high)

    obj = common.loft(g["name"], [ring0, ring1])
    common.group(obj, common.TRANSFER, 1.0)
    kind.add(obj, g, part, "collar", strip=True)


def skirt(kind, g, part):
    """Panels hanging from the belt, clear of what is under them, flaring
    to the hem; each rides a chain of cloth bones."""
    top, hem = kind.belt_z(), kind.z(g["hem"])
    mid = (top + hem) * 0.5
    tree = common.bvh([obj for obj in kind.parts if kind.types[obj.name] in ("shell", "boots")])

    def radial(z, degrees):
        centre = kind.centre(z)
        direction = Vector((math.sin(math.radians(degrees)), -math.cos(math.radians(degrees)), 0.0))
        hit = common.outer_hit(tree, centre, direction)
        return centre, direction, (Vector((hit.x, hit.y - centre.y, 0.0)).length if hit else None)

    for name, (a0, a1) in g["panels"].items():
        if a1 <= 0:
            continue

        a0 = max(a0, 0)
        a1 = min(a1, 180)
        steps = max(2, round((a1 - a0) / 19.0))
        rows = [[], [], []]

        for i in range(steps + 1):
            degrees = a0 + (a1 - a0) * i / steps
            c_top, d, r_top = radial(top, degrees)
            r_top = (r_top or 0.16) + 0.004
            c_mid, _, r_mid = radial(mid, degrees)
            r_mid = max(r_mid or 0.0, r_top) + g["clearance"] * 0.5
            c_hem, _, r_hem = radial(hem, degrees)
            r_hem = max((r_hem or 0.0) + g["clearance"], r_top * g["flare"])

            for row, (c, r, z) in enumerate(((c_top, r_top, top), (c_mid, r_mid, mid), (c_hem, r_hem, hem))):
                p = Vector((0.0, c.y, z)) + d * r
                p.x = 0.0 if degrees in (0, 180) else p.x
                rows[row].append(p)

        obj = common.loft("%s_%s" % (g["name"], name), rows)
        count = steps + 1
        common.group(obj, common.TRANSFER, 1.0, range(0, count))
        chain = g["chains"][name]
        shared = chain.startswith("tabard")
        common.group(obj, "cloth_%s_1" % chain, 1.0, range(count, 2 * count))
        common.group(obj, "cloth_%s_%d" % (chain, 1 if shared else 2), 1.0, range(2 * count, 3 * count))

        if not shared:
            c = (steps // 2)
            points = [rows[0][c], rows[1][c], rows[2][c]]
            kind.chains[chain] = {"parent": "pelvis", "points": points}
            mirrored = chain[:-2] + "_r" if chain.endswith("_l") else None

            if mirrored:
                kind.chains[mirrored] = {"parent": "pelvis", "points": [Vector((-p.x, p.y, p.z)) for p in points]}

        kind.add(obj, g, part, "skirt", strip=True)

    kind.skirt_hem = hem


def tabard(kind, g, part):
    """Front and back panels from the shoulders over the belt and the skirt
    to the knee, the lower part hanging on its own chain."""
    top, belt, hem = kind.z(g["top"]), kind.belt_z(), kind.z(g["hem"])
    skirt_hem = getattr(kind, "skirt_hem", (belt + hem) * 0.5)
    heights = [top, top + (belt - top) * 0.4, top + (belt - top) * 0.75, belt, skirt_hem, hem]
    columns = [0.0, g["width"] * 0.25, g["width"] * 0.5]
    body = common.bvh([obj for obj in kind.parts if kind.types[obj.name] in ("shell", "boots")])

    for side, sign in (("front", -1.0), ("back", 1.0)):
        rows = []

        for i, z in enumerate(heights):
            # A tabard drapes flat: each row hangs just clear of whatever
            # stands out furthest under it (across its width, and half-way
            # to the rows either side), not tucked into every hollow.
            span = 0.5 * min(abs(z - heights[max(i - 1, 0)]) or 0.1, abs(heights[min(i + 1, len(heights) - 1)] - z) or 0.1)
            extreme = None

            for dz in (-span, 0.0, span):
                for k in range(9):
                    x = g["width"] * 0.5 * k / 8.0
                    hit = common.outer_hit(body, Vector((x, 0.02, z + dz)), Vector((0.0, sign, 0.0)), 0.8)

                    if hit is not None and (extreme is None or hit.y * sign > extreme * sign):
                        extreme = hit.y

            if z > belt - 1e-4:
                y = (extreme if extreme is not None else 0.02 + sign * 0.14) + sign * 0.012
            else:
                # Below the belt it falls from where the belt holds it, a little
                # A-line to the skirt's hem, then straight: clear of his legs.
                held = rows[3][0].y
                t = min((belt - z) / max(belt - skirt_hem, 1e-3), 1.0)
                y = held + sign * g.get("flare", 0.035) * t

                if extreme is not None and (extreme + sign * 0.03 - y) * sign > 0:
                    y = extreme + sign * 0.03

            rows.append([Vector((x, y, z)) for x in columns])

        obj = common.loft("%s_%s" % (g["name"], side), rows)
        n = len(columns)
        common.group(obj, common.TRANSFER, 1.0, range(0, 4 * n))
        chain = "tabard_%s" % side
        common.group(obj, "cloth_%s_1" % chain, 1.0, range(4 * n, 5 * n))
        common.group(obj, "cloth_%s_2" % chain, 1.0, range(5 * n, 6 * n))
        kind.chains[chain] = {"parent": "pelvis", "points": [rows[3][0], rows[4][0], rows[5][0]]}
        kind.add(obj, g, part, "tabard", strip=True, dye=True)


def belt(kind, g, part):
    """A band round the waist over whatever is there, and its buckle."""
    z = kind.belt_z()
    tree = common.bvh([obj for obj in kind.parts if kind.types[obj.name] in ("shell", "skirt", "tabard")])
    low, high, inner = [], [], []

    for d in [i * 30.0 for i in range(7)]:
        direction = Vector((math.sin(math.radians(d)), -math.cos(math.radians(d)), 0.0))

        for ring, dz in ((low, -g["height"] * 0.5), (high, g["height"] * 0.5)):
            centre = kind.centre(z + dz)
            hit = common.outer_hit(tree, centre, direction) or centre + direction * 0.17
            p = hit + direction * 0.005
            p.x = 0.0 if d in (0.0, 180.0) else p.x
            ring.append(p)

        top = high[-1]
        centre = kind.centre(z)
        flat = Vector((top.x, top.y - centre.y, 0.0))
        inner.append(top - flat.normalized() * 0.012)

    obj = common.loft(g["name"], [low, high, inner])
    common.group(obj, common.TRANSFER, 1.0)
    kind.add(obj, g, part, "belt")
    kind.belt_ring = (low, high)

    b = g["buckle"]
    front = (low[0] + high[0]) * 0.5
    buckle = common.box("buckle", front + Vector((0.0, -b["size"][1] * 0.5, 0.0)), Vector((1, 0, 0)), Vector((0, 1, 0)),
                        Vector((0, 0, 1)), b["size"])
    common.keep_positive_x(buckle)
    common.group(buckle, common.TRANSFER, 1.0)
    kind.add(buckle, g, part, "belt", fabric=b["fabric"], colour=b["colour"])


def prop(kind, g, part):
    """A pouch, a key ring or a scabbard: whole (not mirrored), rigid on its
    bone, hung from the belt at `at` degrees round from his front (negative:
    his right)."""
    degrees = abs(g["at"])
    side = 1.0 if g["at"] >= 0 else -1.0
    low, high = kind.belt_ring
    i = min(range(len(low)), key=lambda k: abs(k * 30.0 - degrees))
    anchor = (low[i] + high[i]) * 0.5
    anchor = Vector((anchor.x * side, anchor.y, anchor.z))
    radial = Vector((anchor.x, anchor.y - kind.centre(anchor.z).y, 0.0)).normalized()
    up = Vector((0.0, 0.0, 1.0))
    tangent = up.cross(radial).normalized()
    below = anchor - up * (kind.recipe_belt_height if hasattr(kind, "recipe_belt_height") else 0.025)
    made = []

    if g["shape"] == "pouch":
        w, d, h = g["size"]
        made.append(common.box(g["name"], below + radial * (d * 0.5 + 0.006) - up * (h * 0.5 - 0.01), tangent, radial, up, g["size"]))
    elif g["shape"] == "keyring":
        centre = below + radial * 0.012 - up * 0.03
        ring = [[centre + tangent * 0.022 * math.cos(t) + up * 0.022 * math.sin(t) + radial * s for t in
                 (math.radians(a) for a in range(0, 360, 60))] for s in (-0.003, 0.003)]
        made.append(common.loft(g["name"], ring, closed=True))

        for k, lean in enumerate((-0.35, 0.3)):
            hang = (-up + tangent * lean).normalized()
            made.append(common.box("key_%d" % k, centre - up * 0.02 + hang * 0.03, tangent.cross(hang).normalized(), radial, hang,
                                   (0.008, 0.004, 0.05)))
    elif g["shape"] == "scabbard":
        w, d, length = g["size"]
        down = Matrix.Rotation(math.radians(g["back"]) * side, 4, tangent) @ -up
        down = (down + radial * 0.1).normalized()
        start = below + radial * 0.03
        across = radial.cross(down).normalized()
        cuts = [0.0, 0.07, 0.9, 1.0]
        widths = [(w, d), (w * 0.95, d * 0.95), (w * 0.72, d * 0.8), (w * 0.3, d * 0.5)]
        rings = [[start + down * length * t + across * a * sx * 0.5 + radial * b * sy * 0.5
                  for sx, sy in ((-1, -1), (1, -1), (1, 1), (-1, 1))] for t, (a, b) in zip(cuts, widths)]
        fit = g["fittings"]
        made.append(common.loft(g["name"], rings[1:3], closed=True))
        made.append(common.loft("%s_locket" % g["name"], rings[0:2], closed=True))
        made.append(common.loft("%s_chape" % g["name"], rings[2:4], closed=True, cap=start + down * (length + 0.01)))

        for obj in made[1:]:
            kind.add(obj, g, part, "prop", fabric=fit["fabric"], colour=fit["colour"], whole=True)
            common.group(obj, g["bone"], 1.0)

        made = made[:1]

    for obj in made:
        outward(obj) if g["shape"] != "keyring" else None
        common.group(obj, g["bone"], 1.0)
        kind.add(obj, g, part, "prop", whole=True)


def belt_first(kind, g, part):
    kind.recipe_belt_height = g["height"] * 0.5
    belt(kind, g, part)


BUILDERS = {"shell": shell, "mittens": mittens, "boots": boots, "collar": collar, "skirt": skirt,
            "tabard": tabard, "belt": belt_first, "prop": prop}


# ---------------------------------------------------------------------------
# Putting him together
# ---------------------------------------------------------------------------

def hide_body(kind):
    """The body faces a garment hides, gone (spec §6.3 step 4)."""
    base = kind.base
    common.set_faces(base, 0, recipes.FABRICS.index("skin"), 0.0, False, False, SKIN)
    garments = [obj for obj in kind.parts if kind.types[obj.name] != "base"]
    trial = [base] + [obj.copy() for obj in garments]

    for copy in trial[1:]:
        copy.data = copy.data.copy()
        bpy.context.scene.collection.objects.link(copy)

    common.select_only(trial, active=trial[0])
    probe = base.copy()
    probe.data = base.data.copy()
    bpy.context.scene.collection.objects.link(probe)
    common.select_only([probe] + trial[1:], active=probe)
    bpy.ops.object.join()
    hidden = set(common.hidden_faces(probe, reach=COVERED)) | kind.covered
    bpy.data.objects.remove(probe)
    bm = bmesh.new()
    bm.from_mesh(base.data)
    bm.faces.ensure_lookup_table()
    bmesh.ops.delete(bm, geom=[bm.faces[i] for i in sorted(hidden) if i < len(bm.faces)], context="FACES")
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context="VERTS")
    bm.to_mesh(base.data)
    bm.free()
    print("wardrobe: %d body faces hidden, %d left" % (len(hidden), len(base.data.polygons)))


def swap_sides(obj):
    """Mirroring keeps cloth groups named for his left on both sides: the
    right side's vertices go to the right-hand chain."""
    for g in list(obj.vertex_groups):
        if "_l_" not in g.name or not g.name.startswith("cloth_"):
            continue

        right = obj.vertex_groups.get(g.name.replace("_l_", "_r_")) or obj.vertex_groups.new(name=g.name.replace("_l_", "_r_"))
        moved = []

        for vertex in obj.data.vertices:
            if vertex.co.x < -1e-4:
                for item in vertex.groups:
                    if item.group == g.index:
                        moved.append((vertex.index, item.weight))

        for index, weight in moved:
            right.add([index], weight, "REPLACE")
            g.remove([index])


def join(objects):
    objects = [obj for obj in objects if len(obj.data.polygons) > 0]
    common.select_only(objects, active=objects[0])
    bpy.ops.object.join()
    outfit = objects[0]
    outfit.name = "Outfit"
    outfit.data.name = "Outfit"
    return outfit


def materials(outfit):
    """Two slots the game fills with its own shader: closed parts, and cloth
    strips drawn from both sides."""
    outfit.data.materials.clear()

    for name in ("WR_closed", "WR_strips"):
        outfit.data.materials.append(bpy.data.materials.get(name) or bpy.data.materials.new(name))

    strips = outfit.data.attributes["wr_strip"].data

    for polygon in outfit.data.polygons:
        polygon.material_index = 1 if strips[polygon.index].value else 0


def weigh(outfit, reference):
    """Weights for what has none of its own (wr_transfer), copied from the
    full body; then at most 4 bones a vertex, and normalized."""
    common.select_only([outfit])
    modifier = outfit.modifiers.new("Weights", "DATA_TRANSFER")
    modifier.object = reference
    modifier.use_vert_data = True
    modifier.data_types_verts = {"VGROUP_WEIGHTS"}
    modifier.vert_mapping = "POLYINTERP_NEAREST"
    modifier.layers_vgroup_select_src = "ALL"
    modifier.layers_vgroup_select_dst = "NAME"
    modifier.vertex_group = common.TRANSFER
    modifier.mix_mode = "REPLACE"
    modifier.mix_factor = 1.0
    bpy.ops.object.datalayout_transfer(modifier=modifier.name)
    bpy.ops.object.modifier_apply(modifier=modifier.name)
    outfit.vertex_groups.remove(outfit.vertex_groups[common.TRANSFER])
    bpy.ops.object.vertex_group_clean(group_select_mode="ALL", limit=0.01)
    bpy.ops.object.vertex_group_limit_total(group_select_mode="ALL", limit=4)
    bpy.ops.object.vertex_group_normalize_all(group_select_mode="ALL", lock_active=False)


def add_chains(kind):
    """The cloth bones: two a chain, from where the cloth hangs to its hem."""
    common.select_only([kind.arm])
    bpy.ops.object.mode_set(mode="EDIT")
    bones = kind.arm.data.edit_bones
    out = []

    for chain, spec in sorted(kind.chains.items()):
        head, joint, tail = spec["points"]
        first = bones.new("cloth_%s_1" % chain)
        first.head, first.tail = head, joint
        first.parent = bones[spec["parent"]]
        second = bones.new("cloth_%s_2" % chain)
        second.head, second.tail = joint, tail
        second.parent = first

        for bone in (first, second):
            bone.use_deform = True
            bone.use_connect = False

        settings = kind.recipe["chains"][chain]
        out.append({"chain": chain, "parent": spec["parent"], "bones": [first.name, second.name],
                    "tip": round((tail - joint).length, 4), **settings})

    bpy.ops.object.mode_set(mode="OBJECT")
    return out


def probes(outfit, reference):
    """Eight outfit vertices off the cloth (chest, back, upper arms, forearms,
    thighs) and the body point each covers, in glTF space: the game checks
    its re-bound skin against them (K3)."""
    strip_verts = set()
    strips = outfit.data.attributes["wr_strip"].data

    for polygon in outfit.data.polygons:
        if strips[polygon.index].value:
            strip_verts |= set(polygon.vertices)

    tree = common.bvh([reference])
    wanted = [(0.06, -0.14, 1.36), (0.06, 0.18, 1.36), (0.33, 0.07, 1.5), (-0.33, 0.07, 1.5),
              (0.58, 0.07, 1.49), (-0.58, 0.07, 1.49), (0.12, -0.05, 0.84), (-0.12, -0.05, 0.84)]
    out = []

    for target in wanted:
        target = Vector(target)
        best = min((v for v in outfit.data.vertices if v.index not in strip_verts), key=lambda v: (v.co - target).length)
        near = tree.find_nearest(best.co)[0]
        out.append({"rest": common.to_gltf(best.co), "near_body": common.to_gltf(near)})

    return out


# ---------------------------------------------------------------------------
# Heads
# ---------------------------------------------------------------------------

def start(name, body="male"):
    """A fresh scene with the Quaternius skeleton and its full body kept as
    `Reference` (hidden later); its eyes and brows returned."""
    common.scene_fresh("AUCOD_%s" % name)
    armature, reference, extras = common.import_quaternius(body)
    armature.name = "Armature"
    reference.name = "Reference"
    keep = {}

    for extra in extras:
        if extra.name.startswith("Eye") and "brow" not in extra.name.lower():
            keep["eyes"] = extra
        elif "brow" in extra.name.lower():
            keep["brows"] = extra
        else:
            bpy.data.objects.remove(extra)

    return armature, reference, keep


def head_region(reference, name):
    """His head and neck, as their own mesh: every face mostly moved by the
    Head or the neck, welded whole."""
    obj = reference.copy()
    obj.data = reference.data.copy()
    obj.name = name
    obj.modifiers.clear()
    obj.parent = None
    bpy.context.scene.collection.objects.link(obj)
    common.weld(obj)
    regions = common.vertex_regions(obj)
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    doomed = [f for f in bm.faces if sum(1 for v in f.verts if regions[v.index] == "head") < 2]
    bmesh.ops.delete(bm, geom=doomed, context="FACES")
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context="VERTS")
    bm.to_mesh(obj.data)
    bm.free()
    return obj


def reshape(objects, shape, kind):
    """The recipe's pushes, mirrored, on every object alike (the bake's
    source and the low head must match)."""
    for obj in objects:
        for vertex in obj.data.vertices:
            co = vertex.co.copy()
            moved = co.copy()

            for push in shape:
                at = Vector(push["at"])

                for side in ((1.0,) if at.x == 0.0 else (1.0, -1.0)):
                    centre = Vector((at.x * side, at.y, at.z))
                    distance = (co - centre).length

                    if distance >= push["radius"]:
                        continue

                    weight = (1.0 - (distance / push["radius"]) ** 2) ** 2

                    if "along_normal" in push:
                        moved += kind.normal_at(co) * push["along_normal"] * weight

                    if "move" in push:
                        move = Vector(push["move"])
                        moved += Vector((move.x * side, move.y, move.z)) * weight

            vertex.co = moved


def shrink_eyes(eyes, factor):
    """Each eyeball smaller about its own centre."""
    for side in (1.0, -1.0):
        verts = [v for v in eyes.data.vertices if v.co.x * side > 0]

        if not verts:
            continue

        centre = sum((v.co for v in verts), Vector()) / len(verts)

        for v in verts:
            v.co = centre + (v.co - centre) * factor


def head_uv(obj):
    """A PS2 head's map: one cylinder round the head, the seam at the back,
    the face given the most room (one piece, easy to repaint by hand)."""
    mesh = obj.data

    while mesh.uv_layers:
        mesh.uv_layers.remove(mesh.uv_layers[0])

    layer = mesh.uv_layers.new(name="UVMap")
    ys = [v.co.y for v in mesh.vertices]
    zs = [v.co.z for v in mesh.vertices]
    yc = (min(ys) + max(ys)) * 0.5
    z0, z1 = min(zs), max(zs)

    for polygon in mesh.polygons:
        for index in polygon.loop_indices:
            co = mesh.vertices[mesh.loops[index].vertex_index].co
            angle = math.atan2(co.x, -(co.y - yc))

            if abs(co.x) < 1e-6 and co.y > yc:
                angle = math.pi if polygon.center.x > 0 else -math.pi

            reach = abs(angle / math.pi) ** 0.8
            layer.data[index].uv = (0.5 + math.copysign(reach, angle) * 0.49, 0.01 + (co.z - z0) / (z1 - z0) * 0.98)


def build_heads(force):
    path = common.SOURCE / "heads.blend"
    guard(path, force)
    armature, reference, extras = start("heads")
    kind = Kind({"belt": ("spine_01", 0.0), "garments": []}, armature, reference)
    made = []

    for face, recipe in recipes.HEADS.items():
        high = head_region(reference, "High_%s" % face)
        sources = [high]

        for part in ("eyes", "brows"):
            if part in extras:
                copy = extras[part].copy()
                copy.data = extras[part].data.copy()
                copy.name = "High_%s_%s" % (face, part)
                copy.modifiers.clear()
                copy.parent = None
                bpy.context.scene.collection.objects.link(copy)
                sources.append(copy)

        if "eyes" in extras:
            shrink_eyes(sources[1], recipe["eyes"])

        low = head_region(reference, "Head_%s" % face)
        reshape(sources + [low], recipe["shape"], kind)
        decimate = low.modifiers.new("Decimate", "DECIMATE")
        decimate.ratio = min(1.0, recipe["tris"] / max(common.tri_count(low), 1))
        decimate.use_collapse_triangulate = True
        decimate.use_symmetry = True
        decimate.symmetry_axis = "X"
        common.select_only([low])
        bpy.ops.object.modifier_apply(modifier=decimate.name)
        split_at_seam(low)
        common.select_only([low])
        bpy.ops.object.vertex_group_limit_total(group_select_mode="ALL", limit=4)
        bpy.ops.object.vertex_group_normalize_all(group_select_mode="ALL", lock_active=False)
        head_uv(low)
        low.data.materials.clear()
        low.data.materials.append(bpy.data.materials.get("WR_closed") or bpy.data.materials.new("WR_closed"))
        common.set_faces(low, 1, recipes.FABRICS.index("skin"), 0.0, False, False, SKIN)
        low.parent = armature
        low.modifiers.new("Armature", "ARMATURE").object = armature

        for source in sources:
            source.hide_render = True

        made.append(low)
        print("wardrobe: head %s %d triangles" % (face, common.tri_count(low)))

    for extra in extras.values():
        bpy.data.objects.remove(extra)

    finish(path, made, reference)


def split_at_seam(obj):
    """Cuts every face that crosses x = 0, so the map's back seam can open."""
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    geom = list(bm.verts) + list(bm.edges) + list(bm.faces)
    bmesh.ops.bisect_plane(bm, geom=geom, plane_co=(0, 0, 0), plane_no=(1, 0, 0), clear_inner=False, clear_outer=False)
    bm.to_mesh(obj.data)
    bm.free()


def finish(path, made, reference):
    reference.hide_render = True
    reference.hide_set(True)
    scene = bpy.context.scene
    scene["wardrobe_objects"] = [obj.name for obj in made]
    scene["wardrobe_hash"] = common.generated_hash(made)
    common.save(path)
    print("wardrobe: built %s: %s" % (path.name, ", ".join("%s %d" % (o.name, common.tri_count(o)) for o in made)))


# ---------------------------------------------------------------------------
# Headgear
# ---------------------------------------------------------------------------

def build_headgear(force):
    path = common.SOURCE / "headgear.blend"
    guard(path, force)
    armature, reference, extras = start("headgear")

    for extra in extras.values():
        bpy.data.objects.remove(extra)

    kind = Kind({"belt": ("spine_01", 0.0), "garments": []}, armature, reference)
    made = {}

    for piece, g in recipes.HEADGEAR.items():
        made[piece] = coif(kind, g, piece) if g["type"] == "coif" else imported(kind, g, piece, made)

    for obj in made.values():
        common.unwrap([obj], {obj.name: 1.0})
        obj.data.materials.clear()
        obj.data.materials.append(bpy.data.materials.get("WR_closed") or bpy.data.materials.new("WR_closed"))
        obj.parent = armature
        obj.modifiers.new("Armature", "ARMATURE").object = armature

    finish(path, list(made.values()), reference)


def coif(kind, g, piece):
    """A mail hood: his head's shape pushed out and smoothed, open from brow
    to chin (the edge turned in), and a short cape from the neck over the
    shoulders."""
    obj = head_region(kind.ref, "Gear_%s" % piece)
    decimate = obj.modifiers.new("Decimate", "DECIMATE")
    decimate.ratio = min(1.0, g["tris"] / max(common.tri_count(obj), 1))
    decimate.use_collapse_triangulate = True
    decimate.use_symmetry = True
    decimate.symmetry_axis = "X"
    common.select_only([obj])
    bpy.ops.object.modifier_apply(modifier=decimate.name)
    hole = g["opening"]

    def in_opening(p):
        return abs(p.x) < hole["x"] + 0.01 and hole["from_z"] - 0.01 < p.z < hole["to_z"] + 0.01 and p.y < -0.02

    bm = bmesh.new()
    bm.from_mesh(obj.data)
    # Its lower edge cut level, just inside the cape's top: no notches, no
    # spikes hanging into the cape.
    geom = list(bm.verts) + list(bm.edges) + list(bm.faces)
    bmesh.ops.bisect_plane(bm, geom=geom, plane_co=(0.0, 0.0, g["cape"]["top_z"]), plane_no=(0.0, 0.0, 1.0), clear_inner=True)
    doomed = [f for f in bm.faces if abs(f.calc_center_median().x) < hole["x"] and hole["from_z"] < f.calc_center_median().z < hole["to_z"]
              and f.normal.y < -0.3]
    bmesh.ops.delete(bm, geom=doomed, context="FACES")
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context="VERTS")

    offset_verts(kind, bm, lambda co, n: g["thickness"], g["smooth"])
    opening = [e for e in bm.edges if e.is_boundary and in_opening((e.verts[0].co + e.verts[1].co) * 0.5)]

    # Its face edge turned in to his face, so the mail shows its thickness.
    made = bmesh.ops.extrude_edge_only(bm, edges=opening)["geom"]

    for vertex in (item for item in made if isinstance(item, bmesh.types.BMVert)):
        near = kind.ref_tree.find_nearest(vertex.co)[0]

        if near is not None:
            vertex.co = near + (vertex.co - near) * 0.3

    bm.to_mesh(obj.data)
    bm.free()
    obj = join_two(obj, cape_shell(kind, g), obj.name)
    common.group(obj, common.TRANSFER, 1.0)
    weigh_part(obj, kind.ref)
    common.set_faces(obj, 1, recipes.FABRICS.index(g["fabric"]), g["thickness"], False, False, g["colour"])
    print("wardrobe: coif %d triangles" % common.tri_count(obj))
    return obj


def cape_shell(kind, g):
    """The coif's cape: a bell of three rings round his neck, snug under the
    hood at the top, hung out and down like a cone (steep over chest and
    back, shallow over the shoulders), then smoothed and pushed out until it
    stands `clear` of him everywhere: it drapes over whatever he wears."""
    cape = g["cape"]
    neck = kind.at(("neck_01", 0.0))
    top = cape["top_z"] + 0.012
    axis = Vector((0.0, neck.y, top))
    rings = [[], [], []]

    for d in range(0, 360, 30):
        theta = math.radians(d)
        side = math.sin(theta) ** 2
        tilt = math.radians(cape["tilt_front"] + (cape["tilt_side"] - cape["tilt_front"]) * side)
        length = cape["length_front"] + (cape["length_side"] - cape["length_front"]) * side
        out = Vector((math.sin(theta), -math.cos(theta), 0.0))
        hit = kind.ref_tree.ray_cast(axis, out, 0.3)
        snug = (Vector((hit[0].x, hit[0].y - neck.y, 0.0)).length if hit[0] is not None else 0.06) + 0.01
        down = Vector((out.x * math.cos(tilt), out.y * math.cos(tilt), -math.sin(tilt)))
        rings[0].append(axis + out * snug)
        rings[1].append(axis + out * snug + down * length * 0.45)
        rings[2].append(axis + out * snug + down * length)

    for _ in range(4):
        for ring in rings[1:]:
            smoothed = [(ring[i - 1] + ring[i] * 2.0 + ring[(i + 1) % len(ring)]) * 0.25 for i in range(len(ring))]

            for i, point in enumerate(smoothed):
                near, normal, _, _ = kind.ref_tree.find_nearest(point)
                depth = (point - near).dot(normal) if near is not None else 1.0

                if depth < cape["clear"]:
                    point = point + normal * (cape["clear"] - depth)

                ring[i] = point

    return common.loft("cape", rings, closed=True)


def weigh_part(obj, reference):
    """Weights for a part, from the full body (see weigh)."""
    obj.vertex_groups.clear()
    common.group(obj, common.TRANSFER, 1.0)
    weigh(obj, reference)


def imported(kind, g, piece, made):
    """A piece already made (assets/armour): put on his head as it sits in
    the game, scaled just enough to clear what it goes over, and skinned
    wholly to its bone."""
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=str(common.ROOT / g["from"]))
    new = [o for o in bpy.data.objects if o not in before]
    obj = next(o for o in new if o.type == "MESH")

    for other in new:
        if other is not obj:
            bpy.data.objects.remove(other)

    obj.name = "Gear_%s" % piece
    obj.data.name = obj.name
    obj.parent = None
    bone = kind.arm.data.bones[g["bone"]].head_local
    obj.data.transform(Matrix.Translation(bone) @ obj.matrix_world)
    obj.matrix_world = Matrix.Identity(4)

    if g.get("over") in made:
        fit_over(obj, made[g["over"]], bone, g["clearance"])

    names = [m.name for m in obj.data.materials]
    common.set_faces(obj, 1, 0, 0.004, False, False, (0.5, 0.5, 0.5))
    fabric = obj.data.attributes["wr_fabric"].data
    base = obj.data.color_attributes["wr_base"].data

    for polygon in obj.data.polygons:
        name = names[polygon.material_index] if polygon.material_index < len(names) else ""
        spec = g["fabrics"].get(name.split(".")[0], ("iron", (0.34, 0.34, 0.36)))
        fabric[polygon.index].value = recipes.FABRICS.index(spec[0])

        for index in polygon.loop_indices:
            base[index].color_srgb = (spec[1][0], spec[1][1], spec[1][2], 1.0)

    obj.vertex_groups.clear()
    common.group(obj, g["bone"], 1.0)
    print("wardrobe: %s %d triangles" % (piece, common.tri_count(obj)))
    return obj


def fit_over(obj, under, pivot, clearance):
    """Scales `obj` about `pivot` until its inside clears `under` by
    `clearance` everywhere above his ears."""
    inside = common.bvh([obj])
    beneath = common.bvh([under])
    centre = pivot + Vector((0.0, 0.0, 0.1))
    scale = 1.0

    for elevation in (25, 45, 65, 85):
        for azimuth in range(0, 360, 30):
            e, a = math.radians(elevation), math.radians(azimuth)
            direction = Vector((math.cos(e) * math.sin(a), -math.cos(e) * math.cos(a), math.sin(e)))
            hat = inside.ray_cast(centre, direction, 0.5)
            coif = beneath.ray_cast(centre, direction, 0.5)

            if hat[0] is not None and coif[0] is not None:
                scale = max(scale, (coif[3] + clearance) / max(hat[3], 1e-4))

    if scale > 1.0:
        for vertex in obj.data.vertices:
            vertex.co = pivot + (vertex.co - pivot) * scale

    print("wardrobe: %s scaled %.3f to clear %s" % (obj.name, scale, under.name))


main()
