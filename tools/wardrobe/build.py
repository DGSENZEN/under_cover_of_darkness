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

# No __pycache__ beside the tools (Blender would write one each run).
sys.dont_write_bytecode = True
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import bmesh  # noqa: E402
import bpy  # noqa: E402
from mathutils import Matrix, Vector  # noqa: E402
from mathutils.bvhtree import BVHTree  # noqa: E402
from mathutils.kdtree import KDTree  # noqa: E402

import common  # noqa: E402
import recipes  # noqa: E402

# Texels per metre, relative: more where the eye goes, less on soles. Kept
# after the stager: at 256 px the quilting and the mail read at 2 m, and the
# tabard's panels (1.3) keep their stripe's edges straight.
DENSITY = {"base": 0.8, "shell": 1.0, "mittens": 0.8, "boots": 0.8, "collar": 0.8, "skirt": 1.0,
           "tabard": 1.3, "panels": 1.0, "belt": 0.8, "sash": 1.0, "pauldron": 1.0, "bracer": 1.0, "prop": 0.6,
           "mantle": 1.0, "puff": 1.0, "half_cape": 1.0}
# What cloth hangs clear of (and what props stand off): every part made
# before it of these types.
WORN = ("shell", "boots", "skirt", "panels", "tabard")
# Bare skin: the detailed heads' skin (their texture where their faces
# sample it: the male's (0.62, 0.41, 0.29), the female's (0.65, 0.44,
# 0.31)), before his tone, so a bare arm is his face's colour.
SKIN = (0.63, 0.42, 0.30)
# How far under a garment a body face still counts as covered, when the
# build cuts the hidden body away (validation is stricter: thickness + 5 mm).
COVERED = 0.1
# How far past its thickness a smoothed garment may stand.
BULGE = 0.015
# Where a part's shading turns hard (degrees between faces): belts, boxes,
# brims and cuffs keep their edges; cloth and bodies are smooth. A head is
# smooth all over (a low face with hard creases looks carved).
CREASE = 45.0
HEAD_CREASE = 180.0


def main():
    target, options = common.args()

    if target in recipes.KINDS:
        build_kind(recipes.KINDS[target], bool(options.get("force")))
    elif target in common.PART_TARGETS:
        folder, body = common.PART_TARGETS[target]
        (build_heads if folder == "heads" else build_hair)(bool(options.get("force")), body)
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


# A kind

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
        # Each shell's base faces, in its object's order (one_owner).
        self.shell_faces = {}
        # Garments that leave the body under them (`"hides": False`: they
        # stand clear of it, and it shows under their rims).
        self.open_over = set()
        # The faces of his neck's foot kept under the seam round it
        # (low_poly_base), by index (the base keeps its faces' numbers until
        # hide_body).
        self.neck_faces = set()
        # Trim for the bake to paint on the outfit (bake.trim): pauldrons'.
        self.details = {}
        # Headgear's chains, as the export reads them (each tagged with its
        # piece).
        self.gear_chains = []
        # Panels that ride another garment's chain: (object, chain, first
        # vertex below their hip row).
        self.riders = []

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

    def recipe_garment(self, name):
        return next(g for g in self.recipe["garments"] if g["name"] == name)

    def add(self, obj, g, part, kind, strip=False, dye=None, fabric=None, colour=None, whole=False):
        # Dyed as its recipe says (a dyed shell: the archer's tunic), unless
        # its builder says otherwise; a piece of its own fabric or colour (a
        # buckle, fittings, fletchings) is not the garment's cloth: undyed.
        if dye is None:
            dye = g.get("dye", False) and fabric is None and colour is None
        # (Its faces' thickness says how far under them the body is hidden:
        # none under a garment that stands clear.)
        common.set_faces(obj, part, recipes.FABRICS.index(fabric or g["fabric"]),
                         g.get("thickness", 0.004) if g.get("hides", True) else 0.0, strip, dye, colour or g["colour"])
        self.types[obj.name] = kind

        if not g.get("hides", True):
            self.open_over.add(obj.name)

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

    ride_chains(kind)
    hide_body(kind)
    # A body wholly covered (the watchman's) leaves nothing to unwrap.
    everything = [obj for obj in [kind.base] + kind.parts + kind.props if len(obj.data.polygons) > 0]
    common.unwrap(everything, {obj.name: DENSITY[kind.types.get(obj.name, "base")] for obj in everything})

    for obj in [kind.base] + kind.parts:
        if len(obj.data.polygons) > 0:
            common.mirror(obj)
            swap_sides(obj)

    # One-sided garments (not props) hide the body under them now it is
    # whole, with every other garment (a face half under a bracer and half
    # under a mitten's cuff is wholly covered).
    sided = [obj for obj in kind.props if kind.types[obj.name] != "prop"]

    if sided:
        hide_body(kind, sided + kind.parts)

    outfit = join([kind.base] + kind.parts + kind.props)

    if kind.details:
        outfit["wr_details"] = common.dump(kind.details)

    if recipe.get("batch") != 0:
        strips_face_out(outfit, armature)

    common.smooth(outfit, CREASE)
    materials(outfit)
    common.open_necklines(outfit, armature)
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
    mittens replace them, cut to half the recipe's triangles. His neck is
    cut on the seam the heads are cut on (common.cut_at_neck), its edge laid
    on the full body where theirs is: one seam, where the bone weights cut
    each in teeth. (Batch 0's watchman is built as approved: cut at the
    head's bone weights.)"""
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
    seam = kind.recipe.get("batch") != 0
    body = kind.recipe["body"]
    neck_y = kind.at(("neck_01", 0.0)).y
    # (Kept a little over the seam: cut there once decimated.)
    kept_neck = [face for face in bm.faces if seam and majority([regions[v.index] for v in face.verts]) == "head"
                 and face.calc_center_median().z < common.neck_cut_z(body, face.calc_center_median(), neck_y) + 0.025]
    doomed = [face for face in bm.faces if majority([regions[v.index] for v in face.verts]) in dropped
              and face not in kept_neck]
    marked = sorted({v.index for face in kept_neck for v in face.verts})
    bmesh.ops.delete(bm, geom=doomed, context="FACES")
    bm.to_mesh(base.data)
    bm.free()

    # (Its vertices marked through the decimation and the cut: the garments
    # measure past the neck kept.)
    if marked:
        base.vertex_groups.new(name="wr_neck").add(marked, 1.0, "REPLACE")

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

    if seam:
        # Its edge's weights copied from the full body at the end (weigh),
        # as the heads' are: where they meet, they move alike.
        common.group(base, common.TRANSFER, 1.0, common.cut_at_neck(base, body, neck_y, False, kind.ref_tree, half=True))

    group = base.vertex_groups.get("wr_neck")

    if group is not None:
        on_neck = {v.index for v in base.data.vertices if any(g.group == group.index and g.weight > 0.5 for g in v.groups)}
        kind.neck_faces = {p.index for p in base.data.polygons if any(i in on_neck for i in p.vertices)}
        base.vertex_groups.remove(group)

    kind.types[base.name] = "base"
    return base


def majority(values):
    """The commonest value; ties go the same way on every run."""
    return max(sorted(set(values)), key=values.count)


def smoothstep(a, b, x):
    t = min(max((x - a) / (b - a), 0.0), 1.0)
    return t * t * (3.0 - 2.0 * t)


# Garments

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

    def within(f):
        c = f.calc_center_median()
        return z_lo <= c.z <= z_hi and c.x <= x_hi

    # Regions another of his shells is cut from: where two garments meet (a
    # notch is filled only there: at bare skin, his skin stays as it was).
    others = {r for other in kind.recipe["garments"] if other["type"] == "shell" and other["name"] != g["name"]
              for r in other["regions"]}

    def near(f):
        """Within 2.5 cm of its cuts, where another shell meets it: a notch
        at a hem is filled past it (cut at face centres, a hem ran in
        teeth)."""
        c = f.calc_center_median()
        return z_lo - 0.025 <= c.z <= z_hi + 0.025 and c.x <= x_hi + 0.025 \
            and majority([regions[v.index] for v in f.verts]) in others

    chosen = {f for f in bm.faces if majority([regions[v.index] for v in f.verts]) in wanted and within(f)}

    # (Batch 0's watchman is built as approved: recipes.WATCHMAN "batch".)
    if kind.recipe.get("batch") != 0:
        clean_edge(chosen, near)

        # Up to the seam round his neck, from wherever it reaches his neck
        # (the base keeps his neck's foot, under the seam, as the head's):
        # a clean neckline, not the teeth of his bone weights. A bare neck
        # (the brute's) stays skin, all of its foot.
        if kind.recipe.get("bare_neck"):
            foot = neck_foot(kind)
            chosen -= {f for f in chosen if f.index in foot}
        else:
            neck = {f for f in bm.faces if majority([regions[v.index] for v in f.verts]) == "head" and within(f)}
            grown = set()

            while True:
                more = {other for f in chosen | grown for e in f.edges for other in e.link_faces
                        if other in neck and other not in grown}

                if not more:
                    break

                grown |= more

            chosen |= grown

        one_owner(kind, g, chosen)

    doomed = [f for f in bm.faces if f not in chosen]
    kind.covered |= {f.index for f in bm.faces} - {f.index for f in doomed}
    kind.shell_faces[g["name"]] = sorted(f.index for f in chosen)
    # Each face tagged with the base face it is (a lip, -1): its faces' order
    # is not kept (bmesh fills the gaps the cut leaves with the lips' faces,
    # differently from build to build), and one_owner takes faces by it.
    # (Batch 0 as approved.)
    base_of = None

    if kind.recipe.get("batch") != 0:
        # (A new layer leaves the faces held stale: fetched again.)
        doomed = [f.index for f in doomed]
        base_of = bm.faces.layers.int.new(BASE_FACE)
        bm.faces.ensure_lookup_table()
        doomed = [bm.faces[i] for i in doomed]

        for f in bm.faces:
            f[base_of] = f.index

    bmesh.ops.delete(bm, geom=doomed, context="FACES")
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context="VERTS")
    offset_verts(kind, bm, lambda co, n: g["thickness"] + pad(kind, g, co, n), g.get("smooth", 1))
    # (Its open edges, not its mirror seam: down his spine, that ran a
    # collar's back down to his shoulder blades. Batch 0 as approved.)
    kind.rims[g["name"]] = [v.co.copy() for v in bm.verts if v.is_boundary and (kind.recipe.get("batch") == 0 or any(
        e.is_boundary and not all(abs(w.co.x) < 1e-4 for w in e.verts) for e in v.link_edges))]
    made = lips(bm, kind, g.get("lips", []) + (["neck"] if kind.recipe.get("batch") != 0 else []))

    if base_of is not None:
        for f in made:
            f[base_of] = -1

    bm.to_mesh(obj.data)
    bm.free()
    kind.add(obj, g, part, "shell")

    if "studs" in g:
        # Iron studs over it (a studded jerkin), left for the bake.
        kind.details.setdefault("studs", []).append({"part": part, "spacing": g["studs"]["spacing"],
                                                     "centre_y": kind.centre(kind.z(("spine_02", 0.0))).y})


# A shell's faces' base face (shell, one_owner): -1 on a lip.
BASE_FACE = "wr_base_face"


def one_owner(kind, g, chosen):
    """Each face of his body in one shell only, the thickest that chose it:
    a thinner shell under a thicker one there is hidden, and where the
    thicker's smoothing pulled it in the thinner came through (the archer's
    tunic through his jerkin at his chest). Faces a thicker shell made
    earlier holds leave `chosen`; faces a thinner shell made earlier holds
    leave it (its object loses them)."""
    mine = {f.index for f in chosen}

    for name, kept in list(kind.shell_faces.items()):
        shared = mine & set(kept)

        if not shared:
            continue

        if kind.recipe_garment(name).get("thickness", 0.0) >= g["thickness"]:
            chosen -= {f for f in chosen if f.index in shared}
            mine -= shared
            continue

        # (By the base face each of its faces is, BASE_FACE; a lip turned in
        # from a face it loses goes with it, not left hanging at his neck.)
        other = next(obj for obj in kind.parts if obj.name == name)
        bm = bmesh.new()
        bm.from_mesh(other.data)
        base_of = bm.faces.layers.int[BASE_FACE]
        lost = [f for f in bm.faces if f[base_of] in shared]
        lost_lips = {f for face in lost for e in face.edges for f in e.link_faces if f[base_of] == -1}
        bmesh.ops.delete(bm, geom=lost + sorted(lost_lips, key=lambda f: f.index), context="FACES")
        bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context="VERTS")
        bm.to_mesh(other.data)
        bm.free()
        kind.shell_faces[name] = [base for base in kept if base not in shared]


def clean_edge(chosen, allowed, rounds=6):
    """The faces a shell is cut from (`chosen`, bmesh faces of his left half)
    with a cleaner edge: each notch in it (a face with two chosen neighbours
    or more, `allowed` by the recipe's cuts) filled, until none is left,
    which also gives a face sticking out of it neighbours. Cut at his bone
    weights, a shell's edge ran along his body's triangles in a row of teeth
    (the archer's jerkin at his chest). Faces are only ever added: a face
    dropped left his skin under it bare, which no other garment was cut to
    cover. An edge on the mirror plane (x = 0) joins a chosen face to its own
    mirror image."""
    def neighbours(f):
        n = 0

        for e in f.edges:
            if all(v.co.x == 0.0 for v in e.verts):
                n += 1 if f in chosen else 0
                continue

            n += sum(1 for other in e.link_faces if other is not f and other in chosen)

        return n

    for _ in range(rounds):
        notches = {other for f in chosen for e in f.edges for other in e.link_faces
                   if other not in chosen and allowed(other) and neighbours(other) >= 2}

        if not notches:
            return

        chosen |= notches


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
    through an opening: at the sleeves (out along his arms), the bottom
    (below the belt) and his neck (an edge that was on the seam round it:
    turned in to where his head's edge is), as `where` asks. Never the
    seam. Returns the faces it made."""
    layer = bm.verts.layers.float_vector.get("wr_rest")
    belt = kind.belt_z()
    body = kind.recipe["body"]
    neck_y = kind.at(("neck_01", 0.0)).y

    def on_neck(vertex):
        rest = Vector(vertex[layer])
        return abs(rest.z - common.neck_cut_z(body, rest, neck_y)) < 1e-4

    def wanted(edge):
        mid = (edge.verts[0].co + edge.verts[1].co) * 0.5
        return ("sleeve" in where and mid.x > 0.45) or ("bottom" in where and mid.z < belt and mid.x < 0.45) \
            or ("neck" in where and layer is not None and all(on_neck(v) for v in edge.verts))

    edges = [e for e in bm.edges if e.is_boundary and not all(abs(v.co.x) < 1e-4 for v in e.verts) and wanted(e)]

    if not edges or layer is None:
        return []

    # (In their order: from a set, which of two rim vertices at one place a
    # lip went back to changed from build to build.)
    rim = sorted({v for e in edges for v in e.verts}, key=lambda v: v.index)
    tree = KDTree(len(rim))

    for i, vertex in enumerate(rim):
        tree.insert(vertex.co, i)

    tree.balance()
    made = bmesh.ops.extrude_edge_only(bm, edges=edges)["geom"]

    for vertex in (item for item in made if isinstance(item, bmesh.types.BMVert)):
        source = rim[tree.find(vertex.co)[1]]
        vertex.co = Vector(source[layer])

    return [item for item in made if isinstance(item, bmesh.types.BMFace)]


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
    and sized off the full body's hand (the fingers as one); with a `cuff`,
    a gauntlet's cuff flaring back that far over his sleeve's end."""
    thick = 0.008
    wrist = kind.at(("hand_l", 0.0))
    knuckles = kind.at(("middle_01_l", 0.0))
    tips = kind.at(("middle_04_leaf_l", 1.0))
    stations = [wrist.x - g.get("cuff_into_sleeve", 0.045), wrist.x, knuckles.x, tips.x - 0.006]
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

    if g.get("cuff", 0.0) > 0.0:
        gauntlet_cuff(kind, g, part, obj)


def gauntlet_cuff(kind, g, part, mitten):
    """A cuff round his wrist over the mitten's start, flaring back up his
    forearm `cuff` over his sleeve's end: one sheet, drawn from both sides."""
    bone = kind.arm.data.bones["lowerarm_l"]
    axis = (bone.tail_local - bone.head_local).normalized()
    u, v = across(axis)
    tree = common.bvh([obj for obj in kind.parts if kind.types[obj.name] == "shell"] + [mitten])
    wrist = kind.at(("hand_l", 0.0))
    rings = []

    for back, flare in ((-0.005, 0.0), (g["cuff"], g["cuff"] * 0.5)):
        centre = wrist - axis * back
        ring = []

        for k in range(8):
            d = u * math.cos(k * math.pi / 4.0) + v * math.sin(k * math.pi / 4.0)
            ring.append(centre + d * (reach_out(tree, centre, d, 0.04) + 0.004 + flare))

        rings.append(ring)

    obj = common.loft("%s_cuff" % g["name"], rings, closed=True)
    face_away(obj, bone.head_local, axis)
    common.group(obj, common.TRANSFER, 1.0)
    kind.add(obj, g, part, "mittens", strip=True)


def across(axis):
    """Two directions square to `axis` and to each other: the first level
    (square to up too), the second as near up as it can be."""
    u = axis.cross(Vector((0.0, 0.0, 1.0)))
    u = u.normalized() if u.length > 1e-6 else Vector((1.0, 0.0, 0.0))
    return u, u.cross(axis).normalized()


def reach_out(tree, centre, d, fallback):
    """How far out from `centre` along `d` the outermost surface of `tree`
    is (`fallback` if none is met there)."""
    hit = common.outer_hit(tree, centre, d, 0.3)
    return (hit - centre).dot(d) if hit is not None and (hit - centre).dot(d) > 0.0 else fallback


def face_away(obj, origin, axis):
    """A sheet's or a tube's faces turned to face away from the line through
    `origin` along `axis` (it is lit from outside)."""
    outward(obj)
    away = 0.0

    for polygon in obj.data.polygons:
        c = polygon.center
        foot = origin + axis * (c - origin).dot(axis)
        away += (c - foot).normalized().dot(polygon.normal)

    if away < 0.0:
        obj.data.flip_normals()


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

    if not g["cuff"]:
        return

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
    # In its own fabric if it has one (fur tops).
    kind.add(cuff, g, part, "boots", strip=True, fabric=g.get("cuff_fabric"), colour=g.get("cuff_colour"))


def collar(kind, g, part):
    """A standing collar on a shell's neck edge, leaning in to the throat."""
    rim = [p for p in kind.rims[g["on"]] if p.z > kind.z(("spine_03", 0.6)) and abs(p.x) < 0.17]

    # On the seam round his neck, where his shells now end (the rest of a
    # shell's edges, round a shoulder blade, ran its back down her spine):
    # its foot just inside that clean edge, a centimetre under it all round,
    # its top where it was. (Outside the edge, on a floor under its lowest
    # point, its foot came out through the duelist's doublet in front when
    # she took her guard.)
    seam = kind.recipe.get("batch") != 0

    if seam:
        neck_y = kind.at(("neck_01", 0.0)).y
        rim = [p for p in rim if abs(p.z - common.neck_cut_z(kind.recipe["body"], p, neck_y)) < 0.035] or rim

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

        if seam:
            low = Vector((best.x, best.y, best.z - 0.01)) - direction * 0.004
            low.x = 0.0 if d in (0.0, 180.0) else low.x

        ring0.append(low)
        ring1.append(high)

    obj = common.loft(g["name"], [ring0, ring1])
    common.group(obj, common.TRANSFER, 1.0)
    kind.add(obj, g, part, "collar", strip=True)


def skirt(kind, g, part):
    """Panels hanging from the belt, clear of what is under them, flaring
    to the hem; each rides a chain of `bones` cloth bones (1 or 2). A panel
    across his front (0 degrees round from it) or his back (180) is whole
    and centred, on the chain `<name>_front` or `<name>_back`; a side panel
    is built on his left and mirrored, on `<name>_l` and `<name>_r`. Its
    chains hang from his pelvis; a side panel's, with `ride` "thigh", from
    that side's thigh (a strip over it, as tassets ride: its root goes with
    the leg, which would otherwise swing up round it)."""
    top, hem = kind.belt_z(), kind.z(g["hem"])
    mid = (top + hem) * 0.5
    bones = g.get("bones", 2)
    tree = common.bvh([obj for obj in kind.parts if kind.types[obj.name] in ("shell", "boots")])

    def radial(z, degrees):
        centre = kind.centre(z)
        direction = Vector((math.sin(math.radians(degrees)), -math.cos(math.radians(degrees)), 0.0))
        hit = common.outer_hit(tree, centre, direction)
        return centre, direction, (Vector((hit.x, hit.y - centre.y, 0.0)).length if hit else None)

    for a0, a1 in g["panels"].values():
        if a0 < 0 < a1:
            chain, a0, a1, c = "%s_front" % g["name"], 0, max(a1, -a0), 0
        elif a0 < 180 < a1:
            chain, a0, a1, c = "%s_back" % g["name"], min(a0, 360 - a1), 180, -1
        elif a1 <= 0:
            # His right: his left's mirror.
            continue
        else:
            chain, a0, a1, c = "%s_l" % g["name"], max(a0, 0), min(a1, 180), None

        steps = max(2, round((a1 - a0) / 19.0))
        c = steps // 2 if c is None else c
        rows = [[], [], []] if bones == 2 else [[], []]

        for i in range(steps + 1):
            degrees = a0 + (a1 - a0) * i / steps
            c_top, d, r_top = radial(top, degrees)
            r_top = (r_top or 0.16) + 0.004
            c_mid, _, r_mid = radial(mid, degrees)
            r_mid = max(r_mid or 0.0, r_top) + g["clearance"] * 0.5
            c_hem, _, r_hem = radial(hem, degrees)
            r_hem = max((r_hem or 0.0) + g["clearance"], r_top * g["flare"])
            made = [(c_top, r_top, top), (c_mid, r_mid, mid), (c_hem, r_hem, hem)]

            if bones == 1:
                # One bone: straight from the belt to the hem, so the hem
                # stands out far enough that halfway down it clears him.
                made = [made[0], (c_hem, max(r_hem, 2.0 * r_mid - r_top), hem)]

            for row, (c_at, r, z) in enumerate(made):
                p = Vector((0.0, c_at.y, z)) + d * r
                p.x = 0.0 if degrees in (0, 180) else p.x
                rows[row].append(p)

        # Its chain's joints must rest clear of the capsules the cloth keeps
        # out of: each hanging row pushed out, each point along its own
        # way out, as far as its chain's column must go.
        for row in rows[1:]:
            centre_y = kind.centre(row[c].z).y
            push = collider_push(kind, row[c], Vector((row[c].x, row[c].y - centre_y, 0.0)).normalized(), chain)

            for i, p in enumerate(row):
                out = Vector((p.x, p.y - centre_y, 0.0)).normalized()
                row[i] = p + out * push
                row[i].x = 0.0 if abs(p.x) < 1e-6 else row[i].x

        obj = common.loft("%s_%s" % (g["name"], chain), rows)
        count = steps + 1
        common.group(obj, common.TRANSFER, 1.0, range(0, count))

        for k in range(1, len(rows)):
            common.group(obj, "cloth_%s_%d" % (chain, k), 1.0, range(k * count, (k + 1) * count))

        points = [row[c] for row in rows]
        sided = chain.endswith("_l") and g.get("ride") == "thigh"
        kind.chains[chain] = {"parent": "thigh_l" if sided else "pelvis", "points": points}

        if chain.endswith("_l"):
            kind.chains[chain[:-2] + "_r"] = {"parent": "thigh_r" if sided else "pelvis",
                                              "points": [Vector((-p.x, p.y, p.z)) for p in points]}

        kind.add(obj, g, part, "skirt", strip=True)

    kind.skirt_hem = hem


def tabard(kind, g, part):
    """Above the belt, painted onto what he wears there (`over`), as PS2
    artists did, and swelling `proud` of it: front and back, joined over his
    shoulders. Below the belt, front and back panels (see panels) hang to
    `hem` on `bones` cloth bones each, dyed as the painted part is."""
    painted(kind, g, part)
    panels(kind, g, part, "tabard", dye=True)


def painted(kind, g, part):
    """The tabard over his chest, back and shoulders: the faces of `over`
    within `width` of his middle and above his belt, cut out along those
    lines and made the tabard's. It swells to `proud` inside its edges, which
    stay on `over`: no walls, no triangles but the cuts'."""
    over = kind.made[g["over"]]
    half, belt = g["width"] * 0.5, kind.belt_z()
    bm = bmesh.new()
    bm.from_mesh(over.data)
    # Made before any face is held: a new layer lets go of every face.
    mark = bm.faces.layers.int.new("wr_tabard")

    # Cut only where the cuts are its edges, not all round him.
    for co, no, near in (((half, 0.0, 0.0), (1.0, 0.0, 0.0), lambda c: c.z > belt - 0.05),
                         ((0.0, 0.0, belt), (0.0, 0.0, 1.0), lambda c: c.x < half + 0.05)):
        faces = [f for f in bm.faces if near(f.calc_center_median())]
        geom = faces + list({e for f in faces for e in f.edges}) + list({v for f in faces for v in f.verts})
        bmesh.ops.bisect_plane(bm, geom=geom, plane_co=co, plane_no=no)

    region = {f for f in bm.faces if f.calc_center_median().x < half and f.calc_center_median().z > belt}

    for vertex in {v for f in region for v in f.verts}:
        if all(f in region for f in vertex.link_faces):
            seam = abs(vertex.co.x) < 1e-4
            vertex.co += sum((f.normal for f in vertex.link_faces), Vector()).normalized() * g["proud"]
            vertex.co.x = 0.0 if seam else vertex.co.x

    for face in region:
        face[mark] = 1

    bm.to_mesh(over.data)
    bm.free()
    layer = over.data.attributes["wr_tabard"].data
    chosen = [p.index for p in over.data.polygons if layer[p.index].value]
    over.data.attributes.remove(over.data.attributes["wr_tabard"])
    thickness = kind.recipe_garment(g["over"]).get("thickness", 0.0) + g["proud"]
    common.set_faces(over, part, recipes.FABRICS.index(g["fabric"]), thickness, False, True, g["colour"], chosen)
    print("wardrobe: tabard painted on %d faces of %s" % (len(chosen), over.name))


def panels(kind, g, part, made_as="panels", dye=None):
    """Front and back panels from under the belt (`tuck` over it) to `hem`,
    `width` wide: over the furthest he stands out below the belt (belly,
    seat), a little A-line (`flare`) to the skirt's hem, then straight,
    clear of everything made before them (shells, boots, skirts, earlier
    panels). Each hangs on a chain of `bones` cloth bones (1-3) from its hip
    row, its rows below that even to the hem (over a skirt, the first at the
    skirt's hem): `<name>_front`, `<name>_back`. Under another garment's
    panels (`rides`: its name), it rides that garment's chains instead
    (ride_chains): layered cloth on one set of bones never swings apart."""
    belt, hem = kind.belt_z(), kind.z(g["hem"])
    bones = g.get("bones", 2)
    skirt_hem = getattr(kind, "skirt_hem", (belt + hem) * 0.5)
    columns = [0.0, g["width"] * 0.25, g["width"] * 0.5]
    body = common.bvh([obj for obj in kind.parts if kind.types[obj.name] in WORN])

    def extreme(z, sign, span=0.0):
        """How far out (y) he stands at height z (and span either side),
        across the panel's width; None where nothing is hit."""
        found = None

        for dz in ((-span, 0.0, span) if span else (0.0,)):
            for k in range(9):
                x = g["width"] * 0.5 * k / 8.0
                hit = common.outer_hit(body, Vector((x, 0.02, z + dz)), Vector((0.0, sign, 0.0)), 0.8)

                if hit is not None and (found is None or hit.y * sign > found * sign):
                    found = hit.y

        return found

    for side, sign in (("front", -1.0), ("back", 1.0)):
        # Where he stands out furthest in the top of the skirt: the panel
        # hangs over it (a straight drop from the belt would cut through).
        below = [belt - 0.02 * k for k in range(2, 13) if belt - 0.02 * k > skirt_hem + 0.03] or [belt - 0.04]
        hip = max(below, key=lambda z: (extreme(z, sign) or 0.0) * sign)
        drops = [hip + (hem - hip) * k / bones for k in range(1, bones + 1)]

        # Over a skirt, the first of them at the skirt's hem (where the
        # A-line ends, as the watchman's tabard was made), the rest even.
        if bones > 1 and hasattr(kind, "skirt_hem") and hem < kind.skirt_hem < hip:
            drops = [skirt_hem] + [skirt_hem + (hem - skirt_hem) * k / (bones - 1) for k in range(1, bones)]

        heights = [belt + g.get("tuck", 0.015), hip] + drops
        rows = []

        for i, z in enumerate(heights):
            out = extreme(z, sign, 0.01)

            if i == 0:
                y = (out if out is not None else 0.02 + sign * 0.14) + sign * 0.004
            elif i == 1:
                y = max((out if out is not None else rows[0][0].y) * sign + 0.012, rows[0][0].y * sign) * sign
            else:
                t = min((hip - z) / max(hip - skirt_hem, 1e-3), 1.0)
                y = rows[1][0].y + sign * g.get("flare", 0.035) * t

                if out is not None and (out + sign * 0.03 - y) * sign > 0:
                    y = out + sign * 0.03

            row = [Vector((x, y, z)) for x in columns]

            # Below the hip it swings: its chain's joints (the centre
            # column) must rest clear of the capsules the cloth keeps out of.
            if i >= 2:
                push = collider_push(kind, row[0], Vector((0.0, sign, 0.0)), "%s_%s" % (g.get("rides", g["name"]), side))
                row = [p + Vector((0.0, sign * push, 0.0)) for p in row]

            rows.append(row)

        obj = common.loft("%s_%s" % (g["name"], side), rows)
        n = len(columns)
        # Belt and seat ride his body; below them it swings.
        common.group(obj, common.TRANSFER, 1.0, range(0, 2 * n))
        chain = "%s_%s" % (g["name"], side)

        if "rides" in g:
            kind.riders.append((obj, "%s_%s" % (g["rides"], side), 2 * n))
        else:
            for k in range(1, bones + 1):
                common.group(obj, "cloth_%s_%d" % (chain, k), 1.0, range((k + 1) * n, (k + 2) * n))

            kind.chains[chain] = {"parent": "pelvis", "points": [row[0] for row in rows[1:]]}

        kind.add(obj, g, part, made_as, strip=True, dye=g.get("dye", False) if dye is None else dye)


# How far a guard's stance moves his legs from the rest pose the cloth is
# built in: a joint resting nearer a leg's capsule than this is inside it
# as he stands (the arms master's sash tail was, 9 cm deep at its end).
STANCE = 0.045


def collider_push(kind, point, out, chain, extra=(), stance=STANCE):
    """How far `point` must move along `out` for a joint of `chain` there
    (its recipe radius) to rest clear of every capsule the kind's cloth
    keeps out of (its colliders, and `extra` (head, tail, radius) capsules:
    a limb where he stands, not where the rest pose holds it), `stance` to
    spare (how far his stance moves what it hangs by from those capsules:
    his legs, STANCE). Built inside one (as he stands), a joint is thrown out
    of it as soon as the cloth runs, and a restart (a teleport) puts it
    straight back in: a jump every time."""
    if kind.recipe.get("batch") == 0:
        # Made before cloth was built clear of the legs, as approved.
        return 0.0

    radius = kind.recipe.get("chains", {}).get(chain, {}).get("radius", 0.03) + stance
    capsules = [(kind.arm.data.bones[c["bone"]].head_local, kind.arm.data.bones[c["bone"]].tail_local, c["radius"])
                for c in kind.recipe.get("colliders", [])] + list(extra)

    def clear(p):
        for a, b, r in capsules:
            t = min(max((p - a).dot(b - a) / max((b - a).length_squared, 1e-9), 0.0), 1.0)

            if (p - a.lerp(b, t)).length < r + radius:
                return False

        return True

    push = 0.0

    while push < 0.3 and not clear(point + out * push):
        push += 0.0025

    return push


def ride_chains(kind):
    """Each riding panel's vertices below its hip row on the bone of the
    chain it rides that hangs beside them (by height): it swings with the
    garment over it and never through it."""
    for obj, chain, first in kind.riders:
        if chain not in kind.chains:
            common.fail("%s rides %s, which nothing made" % (obj.name, chain))

        points = kind.chains[chain]["points"]

        for vertex in list(obj.data.vertices)[first:]:
            bone = next((i for i in range(1, len(points)) if vertex.co.z >= points[i].z), len(points) - 1)
            common.group(obj, "cloth_%s_%d" % (chain, bone), 1.0, [vertex.index])


def belt(kind, g, part):
    """A band round the waist over whatever is there, and its buckle."""
    obj, low, high = band(kind, g)
    kind.add(obj, g, part, "belt")
    kind.belt_ring = (low, high)

    b = g["buckle"]
    front = (low[0] + high[0]) * 0.5
    buckle = common.box("buckle", front + Vector((0.0, -b["size"][1] * 0.5, 0.0)), Vector((1, 0, 0)), Vector((0, 1, 0)),
                        Vector((0, 0, 1)), b["size"])
    common.keep_positive_x(buckle)
    common.group(buckle, common.TRANSFER, 1.0)
    kind.add(buckle, g, part, "belt", fabric=b["fabric"], colour=b["colour"])


# A belt's or sash's columns: degrees round from his front, on his left.
BAND_STEP = 15.0


def band(kind, g):
    """A band `height` tall round his waist at the belt, over whatever he
    wears there, its top turned in: (the band, its low and high rings).
    Upright: at each column (every BAND_STEP degrees) it stands 5 mm out
    from the outermost of what is under it at its bottom, middle and top (a
    band sloped from ring to ring, or sampled coarsely, cut inside a panel's
    top and a curved back between them)."""
    z = kind.belt_z()
    tree = common.bvh([obj for obj in kind.parts if kind.types[obj.name] in ("shell", "skirt", "tabard", "panels")])
    half = g["height"] * 0.5
    axis = kind.centre(z)
    low, high, inner = [], [], []

    if kind.recipe.get("batch") == 0:
        return sloped_band(kind, g, tree)

    for i in range(int(round(180.0 / BAND_STEP)) + 1):
        d = i * BAND_STEP
        direction = Vector((math.sin(math.radians(d)), -math.cos(math.radians(d)), 0.0))
        reach = 0.0

        for dz in (-half, 0.0, half):
            hit = common.outer_hit(tree, kind.centre(z + dz), direction)
            reach = max(reach, Vector((hit.x, hit.y - axis.y, 0.0)).length if hit is not None else 0.17)

        for ring, dz in ((low, -half), (high, half)):
            p = Vector((0.0, axis.y, z + dz)) + direction * (reach + 0.005)
            p.x = 0.0 if d in (0.0, 180.0) else p.x
            ring.append(p)

        top = high[-1]
        flat = Vector((top.x, top.y - axis.y, 0.0))
        inner.append(top - flat.normalized() * 0.012)

    obj = common.loft(g["name"], [low, high, inner])
    common.group(obj, common.TRANSFER, 1.0)
    return obj, low, high


def sloped_band(kind, g, tree):
    """Batch 0's band (the approved watchman's belt): every 30 degrees, from
    a ring 5 mm out from what is under its bottom to one 5 mm out from what
    is under its top."""
    z = kind.belt_z()
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
    return obj, low, high


def sash(kind, g, part):
    """A cloth band round his waist (props hang from it, as from a belt) and
    `tails` strips hanging side by side from its knot at `at` degrees round
    from his front (negative: his right), each `length` long on a chain of
    `bones` cloth bones (`<name>_1`, `<name>_2`...), hanging straight down,
    clear of what they hang over: whole, not mirrored."""
    kind.recipe_belt_height = g["height"] * 0.5
    obj, low, high = band(kind, g)
    kind.add(obj, g, part, "sash")
    kind.belt_ring = (low, high)
    tree = common.bvh([o for o in kind.parts if kind.types[o.name] in WORN + ("sash",)])
    side = 1.0 if g["at"] >= 0 else -1.0
    half = g.get("tail_width", 0.056) * 0.5
    spread = math.degrees(2.0 * half / 0.17)
    top = kind.belt_z() - g["height"] * 0.3

    for n in range(1, g["tails"] + 1):
        degrees = abs(g["at"]) + (n - 1 - (g["tails"] - 1) * 0.5) * spread
        a = math.radians(degrees)
        d = Vector((math.sin(a), -math.cos(a), 0.0))
        tangent = Vector((0.0, 0.0, 1.0)).cross(d).normalized()
        rows, radius = [], 0.0

        for k in range(g["bones"] + 1):
            z = top - g["length"] * k / g["bones"]
            centre = kind.centre(z)
            hit = common.outer_hit(tree, centre, d)
            under = Vector((hit.x, hit.y - centre.y, 0.0)).length if hit is not None else 0.15
            # Hanging, not hugging: never nearer him than the row above.
            radius = max(radius, under + (0.008 if k == 0 else 0.02))
            mid = Vector((0.0, centre.y, z)) + d * radius

            # Its joints must rest clear of the capsules the cloth keeps out
            # of (his waist's, his thigh's); hanging, never back in after.
            if k > 0:
                radius += collider_push(kind, mid, d, "%s_%d" % (g["name"], n))
                mid = Vector((0.0, centre.y, z)) + d * radius
            rows.append([mid - tangent * half, mid + tangent * half])

        for row in rows:
            for point in row:
                point.x *= side

        chain = "%s_%d" % (g["name"], n)
        tail = common.loft("%s_tail_%d" % (g["name"], n), rows)
        common.group(tail, common.TRANSFER, 1.0, range(0, 2))

        for k in range(1, len(rows)):
            common.group(tail, "cloth_%s_%d" % (chain, k), 1.0, range(2 * k, 2 * k + 2))

        kind.chains[chain] = {"parent": "pelvis", "points": [(row[0] + row[1]) * 0.5 for row in rows]}
        face_away(tail, Vector((0.0, kind.centre(top).y, 0.0)), Vector((0.0, 0.0, 1.0)))
        kind.add(tail, g, part, "sash", strip=True, whole=True)


def pauldron(kind, g, part):
    """A plate over his left shoulder (mirrored to his right), forged the
    PS2 way over what it goes on (`over`, and the shells under it): `rings`
    rings of 6 points from over his shoulder joint out `reach` along his
    upper arm, each an arc from his front over the top of his arm to his
    back whose ends hang `drop` below its top, every point `clearance` off
    what it covers (looking out from the arm's bone); closed toward his neck
    by a cap from `inset` inside the joint (the top of the plate once his
    arm is down); its outer edge rolled `roll` out. Wholly on upperarm_l.
    An iron one's trim (a bright rim, two painted lames) is left for the
    bake."""
    bone = kind.arm.data.bones["upperarm_l"]
    joint, axis = bone.head_local.copy(), (bone.tail_local - bone.head_local).normalized()
    front, up = across(axis)
    tree = common.bvh([kind.made[g["over"]]] + [obj for obj in kind.parts if kind.types[obj.name] == "shell"])
    off = g["clearance"] + g.get("thickness", 0.004)

    def at(centre, phi):
        d = up * math.cos(phi) + front * math.sin(phi)
        return centre + d * (reach_out(tree, centre, d, 0.07) + off)

    def end(centre, top, sign):
        """How far round (radians) from the top his arc runs, toward his
        front (sign 1) or back (-1), before it hangs `drop` below the top."""
        for step in range(1, 31):
            phi = sign * math.radians(step * 5.0)

            if top - at(centre, phi).z >= g["drop"]:
                return phi

        return sign * math.radians(150.0)

    rings = []

    for i in range(g["rings"]):
        centre = joint + axis * (g["reach"] * i / (g["rings"] - 1))
        top = at(centre, 0.0).z
        first, last = end(centre, top, 1.0), end(centre, top, -1.0)
        rings.append([at(centre, first + (last - first) * k / 5.0) for k in range(6)])

    outer = joint + axis * g["reach"]
    rolled = [p + (p - outer - axis * (p - outer).dot(axis)).normalized() * g["roll"] + axis * g["roll"] * 0.5
              for p in rings[-1]]
    inside = joint - axis * g.get("inset", 0.03)
    cap = at(inside, 0.0)
    obj = common.loft(g["name"], [rolled] + rings[::-1], cap=cap)
    face_away(obj, joint, axis)
    side = g.get("side", "both")

    if side == "right":
        # His right alone: made over his left, turned over to his right.
        for vertex in obj.data.vertices:
            vertex.co.x = -vertex.co.x

        obj.data.flip_normals()
        obj.data.update()
        common.group(obj, "upperarm_r", 1.0)
    else:
        common.group(obj, "upperarm_l", 1.0)

    if side == "both":
        # Mirroring moves a vertex to its side's group only if that group is
        # there already: without it, his right pauldron rides his left arm.
        obj.vertex_groups.new(name="upperarm_r")

    # One side alone is whole: not mirrored (the plates' trim mirrors).
    kind.add(obj, g, part, "pauldron", strip=True, whole=side != "both")

    # The trim is a plate's: a cloth one (the duelist's half-cape over her
    # shoulder) has no bright rim or lames.
    if g["fabric"] == "iron":
        kind.details.setdefault("plates", []).append({"joint": list(joint), "axis": list(axis), "reach": g["reach"],
                                                      "lames": [g["reach"] / 3.0, g["reach"] * 2.0 / 3.0]})


def mantle(kind, g, part):
    """A stiff fur roll over his shoulders, `thickness` thick (the brute's).
    Its underside is a bell round his neck, as cape_shell hangs the coif's
    cape: snug at his neck, then out and down, `depth_front` over his chest,
    `depth_back` over his back, `reach` out over his shoulders (steep front
    and back, flatter over the shoulders), standing `clear` of what he wears
    there (`over`, the shells, his bare neck). Its top is the same bell
    `thickness` over it; closed at his neck and round its rim; `dip` lower
    at his front (fading to nothing at his sides: his beard hangs over it).
    Made on his left and mirrored; rigid on CAPE_BONES as the coif's cape
    rides (no chains: stiff fur)."""
    neck = kind.at(("neck_01", 0.0))
    top = neck.z + g.get("rise", 0.02)
    # (Measured from his body without his neck's foot, kept up to the seam
    # round it: it sits where it sat on the body cut at his head.)
    def not_neck(obj, polygon):
        return obj is not kind.base or polygon.index not in kind.neck_faces

    tree = common.bvh([kind.base, kind.made[g["over"]]] + [obj for obj in kind.parts if kind.types[obj.name] == "shell"],
                      keep=not_neck)
    front_tilt, side_tilt = g.get("tilt_front", 70.0), g.get("tilt_side", 25.0)
    under, normals = [[], [], []], []

    for i in range(9):
        theta = math.radians(i * 22.5)
        side = math.sin(theta) ** 2
        depth = g["depth_front"] if math.cos(theta) >= 0.0 else g["depth_back"]
        length = depth + (g["reach"] - depth) * side
        tilt = math.radians(front_tilt + (side_tilt - front_tilt) * side)
        out = Vector((0.0 if i in (0, 8) else math.sin(theta), -math.cos(theta), 0.0))
        down = Vector((out.x * math.cos(tilt), out.y * math.cos(tilt), -math.sin(tilt)))
        axis = Vector((0.0, neck.y, top - g.get("dip", 0.0) * max(0.0, math.cos(theta))))
        start = axis + out * (reach_out(tree, axis, out, 0.07) + g["clear"])
        under[0].append(start)
        under[1].append(start + down * length * 0.5)
        under[2].append(start + down * length)
        # Square to the bell, away from him (up and out).
        normals.append(Vector((out.x * math.sin(tilt), out.y * math.sin(tilt), math.cos(tilt))))

    # Every point of the bell `clear` of what is under it.
    for ring in under[1:]:
        for i, point in enumerate(ring):
            near, normal, _, _ = tree.find_nearest(point)
            depth = (point - near).dot(normal) if near is not None else 1.0

            if depth < g["clear"]:
                ring[i] = point + normal * (g["clear"] - depth)

            ring[i].x = 0.0 if i in (0, 8) else ring[i].x

    # And the middle of every edge between them, both its ends lifted: each
    # point clear, the edge between two sagged into the round top of a bare
    # shoulder, and the fur came through his skin there.
    for _ in range(4):
        for ring in under[1:]:
            for i in range(len(ring) - 1):
                middle = (ring[i] + ring[i + 1]) * 0.5
                near, normal, _, _ = tree.find_nearest(middle)
                depth = (middle - near).dot(normal) if near is not None else 1.0

                if depth < g["clear"]:
                    for j in (i, i + 1):
                        ring[j] = ring[j] + normal * (g["clear"] - depth)
                        ring[j].x = 0.0 if j in (0, 8) else ring[j].x

    over = [[p + n * g["thickness"] for p, n in zip(ring, normals)] for ring in under]

    for ring in over:
        for i in (0, 8):
            ring[i].x = 0.0

    # Round the roll: in at his neck, over the top, down to the rim, back
    # under to his neck (the first ring again: welded shut).
    obj = common.loft(g["name"], [under[0], over[0], over[1], over[2], under[2], under[1], under[0]])
    common.weld(obj)
    outward(obj)
    weigh_part(obj, kind.ref)
    ride(obj, 1e9, CAPE_BONES)
    # (Mirroring moves weights only to a group that is there already.)
    obj.vertex_groups.get("clavicle_r") or obj.vertex_groups.new(name="clavicle_r")
    kind.add(obj, g, part, "mantle")


def puff(kind, g, part):
    """A puffed sleeve over his left upper arm (mirrored to his right): rings
    of 8 round it from `from` to `to` of the bone, over the sleeve under them
    (looking out from the bone) by a swell that grows to `puff` at `peak` and
    back, both ends tucked 3 mm inside the sleeve, less toward his body (the
    arm presses it flat there); wholly on upperarm_l. Its slashes (`slashes`:
    count, colour) are left for the bake."""
    bone = kind.arm.data.bones["upperarm_l"]
    joint = bone.head_local.copy()
    axis = bone.tail_local - joint
    length = axis.length
    axis = axis.normalized()
    front, up = across(axis)
    tree = common.bvh([obj for obj in kind.parts if kind.types[obj.name] == "shell"])
    rows = []

    for k in range(7):
        t = g["from"] + (g["to"] - g["from"]) * k / 6.0
        rise = (t - g["from"]) / max(g["peak"] - g["from"], 1e-6) if t <= g["peak"] \
            else (g["to"] - t) / max(g["to"] - g["peak"], 1e-6)
        swell = g["puff"] * math.sin(math.pi * 0.5 * min(max(rise, 0.0), 1.0))
        centre = joint + axis * length * t
        ring = []

        for j in range(8):
            a = 2.0 * math.pi * j / 8.0
            d = up * math.cos(a) + front * math.sin(a)
            hit = tree.ray_cast(centre, d, 0.15)[0]
            sleeve = (hit - centre).length if hit is not None else 0.06
            ring.append(centre + d * (sleeve - 0.003 + (swell + 0.003 if swell > 0.0 else 0.0) * (1.0 - 0.65 * max(0.0, -d.x))))

        rows.append(ring)

    obj = common.loft(g["name"], rows, closed=True)
    face_away(obj, joint, axis)
    common.group(obj, "upperarm_l", 1.0)
    obj.vertex_groups.new(name="upperarm_r")
    kind.add(obj, g, part, "puff")
    kind.details.setdefault("slashes", []).append({
        "part": part, "joint": list(joint), "axis": list(axis), "from": g["from"] * length, "to": g["to"] * length,
        "count": g["slashes"]["count"], "colour": list(g["slashes"]["colour"])})


def half_cape(kind, g, part):
    """A short cape over her left shoulder (the duelist's): its top along
    her shoulder line, from the back of her neck (spine_03) out to her left
    shoulder point, over what she wears there; its rows down her back to
    `hem`, each `clear` of what is under it (looking in from behind her);
    its top line runs from `inner` (x, metres: past her spine, negative)
    to `reach` past her shoulder point, and its hem flares `flare` further
    each way (inner, outer: hanging straight down it read as a sash).
    Its `chains` chain columns swing on `<name>_<n>` of `bones` bones under
    spine_03 (a column between two rides both), built clear of her colliders
    (collider_push); its top row rides spine_03 at her neck and clavicle_l at
    her shoulder. Drawn from both sides, facing out; whole (her left alone)."""
    neck = kind.at(("neck_01", 0.0))
    shoulder = kind.arm.data.bones["upperarm_l"].head_local
    hem = kind.z(g["hem"])
    tree = common.bvh([kind.base] + [obj for obj in kind.parts if kind.types[obj.name] in WORN])
    columns = 2 * g["chains"] - 1
    behind = Vector((0.0, 1.0, 0.0))
    slope = Vector((0.0, 0.5, 1.0)).normalized()
    top = []

    for c in range(columns):
        u = c / (columns - 1)
        # Along her shoulder line, just over what she wears there.
        at = Vector((g.get("inner", 0.03), neck.y, neck.z - 0.02)).lerp(
            Vector((shoulder.x + g.get("reach", 0.0), shoulder.y, shoulder.z + 0.02)), u)
        hit = common.outer_hit(tree, at, slope, 0.3)
        top.append((hit if hit is not None else at) + slope * g["clear"])

    rows = [top]

    inner_flare, outer_flare = g.get("flare", (0.0, 0.0))

    for r in range(1, g["bones"] + 1):
        z = top[0].z + (hem - top[0].z) * r / g["bones"]
        row = []

        for c, point in enumerate(top):
            u = c / (columns - 1)
            level = Vector((point.x + (outer_flare * u - inner_flare * (1.0 - u)) * r / g["bones"], kind.centre(z).y, z))
            reach = reach_out(tree, level, behind, 0.12)
            row.append(level + behind * (max(reach + g["clear"], point.y - level.y)))

        rows.append(row)

    # Its chains' joints rest clear of her colliders, and of her left upper
    # arm as she stands (hanging from her shoulder, not out as in the rest
    # pose), each column as far as it must (a column between two chains as
    # far as the farther), `stance` to spare: her spine and arm move little
    # from where it hangs by (built flared out to a leg's margin, gravity
    # swung it back at every restart).
    arm = kind.arm.data.bones["upperarm_l"]
    radius = next((c["radius"] for c in kind.recipe.get("colliders", []) if c["bone"] == "upperarm_l"), 0.05)
    hanging = [(arm.head_local, arm.head_local - Vector((0.0, 0.0, arm.length)), radius)]

    for row in rows[1:]:
        pushes = [collider_push(kind, row[2 * k], behind, "%s_%d" % (g["name"], k + 1), hanging, g.get("stance", STANCE))
                  for k in range(g["chains"])]
        row[:] = [p + behind * (pushes[c // 2] if c % 2 == 0 else max(pushes[c // 2], pushes[c // 2 + 1]))
                  for c, p in enumerate(row)]

    obj = common.loft(g["name"], rows)
    face_away(obj, Vector((0.0, kind.centre(hem).y, 0.0)), Vector((0.0, 0.0, 1.0)))

    for c in range(columns):
        u = c / (columns - 1)

        if u < 1.0:
            common.group(obj, "spine_03", 1.0 - u, [c])

        if u > 0.0:
            common.group(obj, "clavicle_l", u, [c])

    for r in range(1, g["bones"] + 1):
        for c in range(columns):
            index = r * columns + c
            chains = [c // 2] if c % 2 == 0 else [c // 2, c // 2 + 1]

            for k in chains:
                common.group(obj, "cloth_%s_%d_%d" % (g["name"], k + 1, r), 1.0 / len(chains), [index])

    # Hung from the spine bone whose capsule it must clear (`hang_from`):
    # from the one above it, every bend of her back swung that capsule
    # through it.
    for k in range(g["chains"]):
        kind.chains["%s_%d" % (g["name"], k + 1)] = {"parent": g.get("hang_from", "spine_03"), "points": [row[2 * k] for row in rows]}

    kind.add(obj, g, part, "half_cape", strip=True, whole=True)


def bracer(kind, g, part):
    """A leather ring round one forearm (`bone`, from `from` to `to` along
    it), `thickness` over what he wears there (a sleeve, or his bare skin
    `clear` under it), its ends turned in to it: whole (not mirrored),
    wholly on its bone. Every point of his forearm between its ends lies
    under it: a fixed ring over a bare arm let his skin out through its
    rim."""
    bone = kind.arm.data.bones[g["bone"]]
    head, tail = bone.head_local, bone.tail_local
    axis = (tail - head).normalized()
    u, v = across(axis)
    # (His body is his left half as garments are made: a right forearm is
    # measured on his left, mirrored.)
    right = head.x < 0.0
    flip = Vector((-1.0, 1.0, 1.0))
    tree = common.bvh([obj for obj in kind.parts if kind.types[obj.name] == "shell"] + [kind.base])

    def reach(centre, d):
        """His forearm's (or its sleeve's) outermost surface along `d`,
        within 10 cm (further out lies his trunk)."""
        centre, d = (centre * flip, d * flip) if right else (centre, d)
        hit = common.outer_hit(tree, centre, d, 0.1)
        return (hit - centre).dot(d) if hit is not None and (hit - centre).dot(d) > 0.0 else 0.04

    clear = g.get("clear", 0.002)
    rings = []

    for t in (g["from"], g["to"]):
        centre = head.lerp(tail, t)
        under, over = [], []

        for k in range(8):
            d = u * math.cos(k * math.pi / 4.0) + v * math.sin(k * math.pi / 4.0)
            r = reach(centre, d) + clear
            under.append(centre + d * r)
            over.append(centre + d * (r + g["thickness"]))

        rings.append((under, over))

    obj = common.loft(g["name"], [rings[0][0], rings[0][1], rings[1][1], rings[1][0]], closed=True)
    # His forearm's own points between its ends, under its outside.
    span = [(p * flip if right else p) for p in (vtx.co for vtx in kind.base.data.vertices)]
    span = [p for p in span if g["from"] <= (p - head).dot(axis) / bone.length <= g["to"]
            and ((p - head) - axis * (p - head).dot(axis)).length < 0.07]

    def from_axis(p):
        return head + axis * (p - head).dot(axis)

    bm = bmesh.new()
    bm.from_mesh(obj.data)
    enclose(bm, span, from_axis, clear + g["thickness"] * 0.5)
    bm.to_mesh(obj.data)
    bm.free()
    face_away(obj, head, axis)
    common.group(obj, g["bone"], 1.0)
    kind.add(obj, g, part, "bracer", whole=True)


def prop(kind, g, part):
    """A pouch, a key ring or a scabbard: whole (not mirrored), rigid on its
    bone, hung from the belt at `at` degrees round from his front (negative:
    his right)."""
    degrees = abs(g["at"])
    side = 1.0 if g["at"] >= 0 else -1.0
    low, high = kind.belt_ring
    # The belt's column nearest `at` (its columns span his front to his back).
    step = 180.0 / (len(low) - 1)
    i = min(range(len(low)), key=lambda k: abs(k * step - degrees))
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
    elif g["shape"] in ("scabbard", "hanger"):
        w, d, length = g["size"]
        down = hang_down(kind, g["back"], radial, tangent, side)
        # A hanger (a rapier's) holds its scabbard on two straps, its throat
        # a hand under the belt; a scabbard hangs from the belt itself.
        belt_at = below + radial * 0.03
        start = belt_at - up * (0.07 if g["shape"] == "hanger" else 0.0)
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

        if g["shape"] == "hanger":
            # Its straps: from the belt, a hand apart, to its throat and a
            # little way down it.
            for k, (lean, t) in enumerate(((1.0, 0.0), (-1.0, 0.14))):
                high = belt_at + tangent * 0.02 * lean
                low_end = start + down * length * t
                z = (low_end - high).normalized()
                x = radial.cross(z).normalized()
                strap = common.box("%s_strap_%d" % (g["name"], k), (high + low_end) * 0.5, x, z.cross(x), z,
                                   (0.012, 0.004, (low_end - high).length))
                made.append(strap)
    elif g["shape"] == "quiver":
        quiver(kind, g, part, below, radial, tangent, side)
        made = []
    elif g["shape"] == "knife":
        knife(kind, g, part, below, radial, tangent, side)
        made = []

    for obj in made:
        outward(obj) if g["shape"] != "keyring" else None
        common.group(obj, g["bone"], 1.0)
        kind.add(obj, g, part, "prop", whole=True)


def hang_down(kind, back, radial, tangent, side):
    """Which way a prop hung from his belt runs down from where it hangs:
    `back` degrees behind straight down (the bodies face -y), then a little
    out from him. Batch 0's turns about the belt's tangent instead, as
    approved: at his side that swings it in, across his legs."""
    up = Vector((0.0, 0.0, 1.0))

    if kind.recipe.get("batch") == 0:
        down = Matrix.Rotation(math.radians(back) * side, 4, tangent) @ -up
    else:
        down = Matrix.Rotation(math.radians(back), 4, Vector((1.0, 0.0, 0.0))) @ -up

    return (down + radial * 0.1).normalized()


def quiver(kind, g, part, below, radial, tangent, side):
    """A quiver hung from the belt: a tapered leather box `length` long,
    leaning back, its mouth dark and a few arrows' fletchings standing out of
    it; its upper third on its bone, its lower two thirds on a one-bone chain
    (`<name>`) that swings from there. Stood clear of what he wears."""
    up = Vector((0.0, 0.0, 1.0))
    w, d = g.get("size", (0.1, 0.07))
    length = g["length"]
    down = hang_down(kind, g.get("back", 12), radial, tangent, side)
    start = below + radial * (d * 0.5 + 0.01)
    side_to_side = radial.cross(down).normalized()
    cuts = [0.0, 1.0 / 3.0, 1.0]
    widths = [(w, d), (w * 0.95, d * 0.95), (w * 0.75, d * 0.8)]
    rings = [[start + down * length * t + side_to_side * a * sx * 0.5 + radial * b * sy * 0.5
              for sx, sy in ((-1, -1), (1, -1), (1, 1), (-1, 1))] for t, (a, b) in zip(cuts, widths)]
    body = common.loft(g["name"], rings, closed=True, cap=start + down * (length + 0.006))
    outward(body)
    mouth = common.loft("%s_mouth" % g["name"], [rings[0][:2], rings[0][:1:-1]])
    upward(mouth)
    fletching = g.get("fletching", {"fabric": "wool", "colour": (0.76, 0.73, 0.66)})
    feathers = []

    for fx, fy, tall in ((-0.25, -0.2, 0.08), (0.22, -0.15, 0.07), (0.0, 0.22, 0.085), (-0.12, 0.25, 0.065), (0.28, 0.2, 0.075)):
        foot = start + side_to_side * w * fx + radial * d * fy
        for turn in (0.0, 90.0):
            spin = Matrix.Rotation(math.radians(turn + 30.0 * fx), 4, down)
            flat = (spin @ side_to_side).normalized()
            feathers.append(common.loft("%s_fletching" % g["name"], [[foot - flat * 0.01, foot + flat * 0.01],
                                                                   [foot - flat * 0.01 - down * tall, foot + flat * 0.01 - down * tall]]))

    pieces = [body, mouth] + feathers
    stand_clear(kind, pieces, radial, side)
    hinge = (sum((v.co for v in body.data.vertices[4:8]), Vector())) / 4.0
    bottom = (sum((v.co for v in body.data.vertices[8:12]), Vector())) / 4.0
    kind.chains[g["name"]] = {"parent": g["bone"], "points": [hinge, bottom + (bottom - hinge).normalized() * 0.006]}
    common.group(body, g["bone"], 1.0, range(0, 8))
    common.group(body, "cloth_%s_1" % g["name"], 1.0, range(8, len(body.data.vertices)))
    kind.add(body, g, part, "prop", whole=True)
    common.group(mouth, g["bone"], 1.0)
    kind.add(mouth, g, part, "prop", colour=tuple(c * 0.3 for c in g["colour"]), whole=True)

    for feather in feathers:
        common.group(feather, g["bone"], 1.0)
        kind.add(feather, g, part, "prop", fabric=fletching["fabric"], colour=fletching["colour"], strip=True, whole=True)


def knife(kind, g, part, below, radial, tangent, side):
    """A knife in a small sheath on the belt, its grip standing above it (in
    its `fittings`), leaning a little out from him: rigid on its bone, stood
    clear of what he wears."""
    up = Vector((0.0, 0.0, 1.0))
    w, d = g.get("size", (0.04, 0.02))
    length = g.get("length", 0.2)
    down = (-up + radial * 0.12).normalized()
    start = below + radial * (d * 0.5 + 0.006)
    side_to_side = radial.cross(down).normalized()
    cuts = [0.0, 0.8, 1.0]
    widths = [(w, d), (w * 0.8, d * 0.8), (w * 0.3, d * 0.45)]
    rings = [[start + down * length * t + side_to_side * a * sx * 0.5 + radial * b * sy * 0.5
              for sx, sy in ((-1, -1), (1, -1), (1, 1), (-1, 1))] for t, (a, b) in zip(cuts, widths)]
    sheath = common.loft(g["name"], rings, closed=True, cap=start + down * (length + 0.008))
    outward(sheath)
    grip = common.box("%s_grip" % g["name"], start - down * 0.045, side_to_side, radial, -down, (0.022, 0.02, 0.09))
    fit = g.get("fittings", {"fabric": g["fabric"], "colour": g["colour"]})
    stand_clear(kind, [sheath, grip], radial, side)

    for obj, fabric, colour in ((sheath, g["fabric"], g["colour"]), (grip, fit["fabric"], fit["colour"])):
        common.group(obj, g["bone"], 1.0)
        kind.add(obj, g, part, "prop", fabric=fabric, colour=colour, whole=True)


def stand_clear(kind, pieces, radial, side, clearance=0.008):
    """A prop's `pieces` moved out along `radial` together, just far enough
    that every vertex stands `clearance` outside what he wears that is solid
    (his shells, boots, belt or sash; not his cloth, which swings, nor a
    skirt's flare, which would shove the prop off his belt). On his right,
    measured on their left halves (the parts are mirrored later)."""
    tree = common.bvh([o for o in kind.parts if kind.types[o.name] in ("shell", "boots", "belt", "sash")])
    push = Vector((radial.x * side, radial.y, radial.z)).normalized()
    shift = 0.0

    for obj in pieces:
        for vertex in obj.data.vertices:
            co = Vector((vertex.co.x * side, vertex.co.y, vertex.co.z))
            # Anything of his further out along the way it would move: it
            # must move past it; else anything just under it: off it.
            outside = tree.ray_cast(co + push * 0.5, -push, 0.5)

            if outside[0] is not None:
                shift = max(shift, (outside[0] - co).dot(push) + clearance)
            else:
                under = tree.ray_cast(co, -push, clearance)

                if under[0] is not None:
                    shift = max(shift, clearance - under[3])

    for obj in pieces:
        for vertex in obj.data.vertices:
            vertex.co += radial * shift


def belt_first(kind, g, part):
    kind.recipe_belt_height = g["height"] * 0.5
    belt(kind, g, part)


BUILDERS = {"shell": shell, "mittens": mittens, "boots": boots, "collar": collar, "skirt": skirt, "panels": panels,
            "tabard": tabard, "belt": belt_first, "sash": sash, "pauldron": pauldron, "bracer": bracer, "prop": prop,
            "mantle": mantle, "puff": puff, "half_cape": half_cape}


# Putting him together

def hide_body(kind, garments=None):
    """The body faces a garment hides, gone (spec §6.3 step 4): under every
    part, while he is his left half; or, given `garments` (one-sided pieces,
    a right pauldron, with the rest), under those once he is whole. Within COVERED of a
    garment; of one standing clear of him (`"hides": False`: the brute's
    mantle, the body showing under its rim), only where it touches him."""
    base = kind.base
    common.set_faces(base, 0, recipes.FABRICS.index("skin"), 0.0, False, False, SKIN)
    whole = garments is not None
    garments = garments if whole else [obj for obj in kind.parts if kind.types[obj.name] != "base"]
    closed = [obj for obj in garments if obj.name not in kind.open_over]
    opened = [obj for obj in garments if obj.name in kind.open_over]
    # (The shells' covered faces count on his half only: their indices go
    # stale once faces are gone.)
    # (A bare neck's foot stays: the mantle's roll, snug behind his neck,
    # touched it, and his head's edge stood over a hole there.)
    bare_foot = neck_foot(kind) if kind.recipe.get("bare_neck") else set()
    hidden = covered_by(kind, closed, whole, COVERED) | (covered_by(kind, opened, whole, None) - bare_foot) | \
        (set() if whole else kind.covered)
    bm = bmesh.new()
    bm.from_mesh(base.data)
    bm.faces.ensure_lookup_table()
    bmesh.ops.delete(bm, geom=[bm.faces[i] for i in sorted(hidden) if i < len(bm.faces)], context="FACES")
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context="VERTS")
    bm.to_mesh(base.data)
    bm.free()
    print("wardrobe: %d body faces hidden, %d left" % (len(hidden), len(base.data.polygons)))


def neck_foot(kind, depth=0.03, reach=0.12):
    """The base's faces at the foot of his neck, within `depth` under the
    seam round it (common.NECK_CUT) and `reach` of its middle: a bare neck's
    (the brute's), no shell's, and not hidden by a garment standing clear.
    His jerkin took two behind it (cut, their corners weigh more on his
    spine than his neck), and his head's edge stood over a hole there."""
    body = kind.recipe["body"]
    neck_y = kind.at(("neck_01", 0.0)).y
    return {p.index for p in kind.base.data.polygons if math.hypot(p.center.x, p.center.y - neck_y) < reach
            and 0.0 < common.neck_cut_z(body, p.center, neck_y) - p.center.z < depth}


def strips_face_out(outfit, armature):
    """His hanging cloth (strips below his chest) turned to face away from
    him: the bake paints both sides of a strip from the side its faces point
    to, and a skirt facing his legs baked their shadow onto its front (the
    swordsman's surcoat read dark and muddy under his belt)."""
    chest = armature.data.bones["spine_02"].head_local.z
    axis_y = armature.data.bones["spine_01"].head_local.y
    strips = outfit.data.attributes["wr_strip"].data
    bm = bmesh.new()
    bm.from_mesh(outfit.data)
    bm.faces.ensure_lookup_table()
    turned = []

    for f in bm.faces:
        c = f.calc_center_median()

        if strips[f.index].value and c.z < chest:
            out = Vector((c.x, c.y - axis_y, 0.0))

            if out.length > 0.01 and f.normal.dot(out.normalized()) < -0.2:
                turned.append(f)

    bmesh.ops.reverse_faces(bm, faces=turned)
    bm.to_mesh(outfit.data)
    bm.free()


def covered_by(kind, garments, whole, reach):
    """The base's faces `garments` cover (common.hidden_faces: within
    `reach` of them, or with None within their faces' thickness), as he
    will wear them."""
    if not garments:
        return set()

    copies = [obj.copy() for obj in garments]

    for copy in copies:
        copy.data = copy.data.copy()
        bpy.context.scene.collection.objects.link(copy)

        # Whole, as he will wear them: a face by his middle may look across
        # it, under the garment's other half (the mantle over his throat).
        if not whole and len(copy.data.polygons) > 0:
            common.mirror(copy)

    probe = kind.base.copy()
    probe.data = kind.base.data.copy()
    bpy.context.scene.collection.objects.link(probe)
    common.select_only([probe] + copies, active=probe)
    bpy.ops.object.join()
    hidden = set(common.hidden_faces(probe, reach=reach, bare=set(kind.recipe.get("bare", ()))))
    bpy.data.objects.remove(probe)
    return hidden


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


def chain_bones(arm, chain, parent, points):
    """A chain's cloth bones on `arm`: one from each of `points` to the next
    (`cloth_<chain>_1`..`_n`), each under the one before, the first under
    `parent`; all deform. Their names, in order."""
    common.select_only([arm])
    bpy.ops.object.mode_set(mode="EDIT")
    bones = arm.data.edit_bones
    names = []
    above = bones[parent]

    for i, (head, tail) in enumerate(zip(points, points[1:]), start=1):
        bone = bones.new("cloth_%s_%d" % (chain, i))
        bone.head, bone.tail = head, tail
        bone.parent = above
        bone.use_deform = True
        bone.use_connect = False
        names.append(bone.name)
        above = bone

    bpy.ops.object.mode_set(mode="OBJECT")
    return names


def add_chains(kind):
    """The cloth bones: a chain from where the cloth hangs to its hem, as
    many bones as it has points less one."""
    out = []

    for chain, spec in sorted(kind.chains.items()):
        points = spec["points"]
        names = chain_bones(kind.arm, chain, spec["parent"], points)
        settings = kind.recipe["chains"][chain]
        out.append({"chain": chain, "parent": spec["parent"], "bones": names,
                    "tip": round((points[-1] - points[-2]).length, 4), **settings})

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


# Heads

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


def head_region(reference, name, body=None, neck_y=0.0):
    """His head and neck, as their own mesh: every face mostly moved by the
    Head or the neck, welded whole. With `body`, also every face of his
    neck's foot within 3 cm under the seam round it (common.NECK_CUT): the
    head is cut there."""
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

    def foot(f):
        c = f.calc_center_median()
        return body is not None and math.hypot(c.x, c.y - neck_y) < 0.16 and c.z > common.neck_cut_z(body, c, neck_y) - 0.03

    doomed = [f for f in bm.faces if sum(1 for v in f.verts if regions[v.index] == "head") < 2 and not foot(f)]
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


def build_heads(force, body="male"):
    """The heads of `body` (recipes.HEADS) into its own file, on its own
    skeleton: source/heads.blend (male), heads_female.blend (female)."""
    faces = common.parts_of(recipes.HEADS, body)

    if not faces:
        print("wardrobe: no %s heads in the recipes: nothing to build" % body)
        return

    target = common.part_target("heads", body)
    path = common.SOURCE / ("%s.blend" % target)
    guard(path, force)
    armature, reference, extras = start(target, body)
    kind = Kind({"belt": ("spine_01", 0.0), "garments": []}, armature, reference)
    neck_y = kind.at(("neck_01", 0.0)).y
    made = []

    for face in faces:
        recipe = recipes.HEADS[face]
        # (The bake's source runs on past the seam: the low head's edge has
        # something under it to bake from.)
        high = head_region(reference, "High_%s" % face, body, neck_y)
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

        low = head_region(reference, "Head_%s" % face, body, neck_y)
        reshape(sources + [low], recipe["shape"], kind)
        decimate = low.modifiers.new("Decimate", "DECIMATE")
        decimate.ratio = min(1.0, recipe["tris"] / max(common.tri_count(low), 1))
        decimate.use_collapse_triangulate = True
        decimate.use_symmetry = True
        decimate.symmetry_axis = "X"
        common.select_only([low])
        bpy.ops.object.modifier_apply(modifier=decimate.name)
        # Cut on the seam round his neck, its edge laid on the full body and
        # weighed as it is there: where every kind's body is cut and weighed.
        common.group(low, common.TRANSFER, 1.0, common.cut_at_neck(low, body, neck_y, True, kind.ref_tree))
        weigh(low, reference)
        split_at_seam(low)
        head_uv(low)
        faces_of_head = len(low.data.polygons)
        low = join_two(low, neck_sleeve(kind, low, recipes.NECK_SLEEVE[body], body), low.name)
        sleeve_uv(low, faces_of_head)
        common.select_only([low])
        bpy.ops.object.vertex_group_limit_total(group_select_mode="ALL", limit=4)
        bpy.ops.object.vertex_group_normalize_all(group_select_mode="ALL", lock_active=False)
        common.smooth(low, HEAD_CREASE)
        low.data.materials.clear()
        low.data.materials.append(bpy.data.materials.get("WR_closed") or bpy.data.materials.new("WR_closed"))
        common.set_faces(low, 1, recipes.FABRICS.index("skin"), 0.0, False, False, SKIN)
        # (Its sleeve is part 2: bake.neck_fade fades from the head's own
        # open edge, not the sleeve's.)
        common.set_faces(low, 2, recipes.FABRICS.index("skin"), 0.0, False, False, SKIN,
                         faces=range(faces_of_head, len(low.data.polygons)))
        open_neck_edge(low, faces_of_head, body)
        low.parent = armature
        low.modifiers.new("Armature", "ARMATURE").object = armature

        for source in sources:
            source.hide_render = True

        made.append(low)
        print("wardrobe: head %s %d triangles" % (face, common.tri_count(low)))

    for extra in extras.values():
        bpy.data.objects.remove(extra)

    finish(path, made, reference)


def neck_sleeve(kind, low, g, body):
    """A sleeve of skin inside his neck (recipes.NECK_SLEEVE): `segments`
    round, from just over the head's open edge down to `bottom`, sunk
    `tuck` under the full body's neck (the first surface out from its
    middle). Hidden inside his neck and under his collar, it fills the gap
    where the teeth of a low head's edge met a collar standing off his
    neck: the background showed through beside the bare-hat watchman's
    neck (and the duelist's and the arms master's)."""
    bm = bmesh.new()
    bm.from_mesh(low.data)
    top = max(v.co.z for v in bm.verts if v.is_boundary and v.co.z < common.NECK_EDGE_BELOW[body]) + 0.005
    bm.free()
    axis_y = kind.at(("neck_01", 0.0)).y
    rings = []

    for z in (top, g["bottom"]):
        centre = Vector((0.0, axis_y, z))
        ring = []

        for k in range(g["segments"]):
            a = 2.0 * math.pi * k / g["segments"]
            d = Vector((math.sin(a), -math.cos(a), 0.0))
            hit = kind.ref_tree.ray_cast(centre, d, 0.15)
            reach = (hit[0] - centre).length if hit[0] is not None else 0.05
            ring.append(centre + d * (reach - g["tuck"]))

        rings.append(ring)

    sleeve = common.loft("neck_sleeve", rings, closed=True)
    outward(sleeve)
    weigh_part(sleeve, kind.ref)
    return sleeve


def open_neck_edge(obj, faces_of_head, body, reach=0.03):
    """The head's faces within `reach` of its open neck edge drawn from both
    sides (a WR_strips surface, as common.open_necklines draws a garment's):
    seen past the side of his neck, the inside of its flare at his back
    showed the background (the bare-hat watchman)."""
    obj.data.materials.append(bpy.data.materials.get("WR_strips") or bpy.data.materials.new("WR_strips"))
    strips = obj.data.attributes["wr_strip"].data
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    bm.faces.ensure_lookup_table()
    edge = [v.co.copy() for e in bm.edges if e.is_boundary and all(f.index < faces_of_head for f in e.link_faces)
            and max(v.co.z for v in e.verts) < common.NECK_EDGE_BELOW[body] for v in e.verts]

    for f in bm.faces:
        if f.index < faces_of_head and any((v.co - p).length < reach for v in f.verts for p in edge):
            strips[f.index].value = True
            obj.data.polygons[f.index].material_index = 1

    bm.free()


def sleeve_uv(obj, first):
    """The sleeve's faces (`first` on) sample the bottom row of the head's
    map, round as head_uv goes: the foot of the head's neck, faded there to
    his body's skin (bake.neck_fade)."""
    layer = obj.data.uv_layers.active
    ys = [v.co.y for v in obj.data.vertices]
    yc = (min(ys) + max(ys)) * 0.5

    for polygon in obj.data.polygons[first:]:
        for index in polygon.loop_indices:
            co = obj.data.vertices[obj.data.loops[index].vertex_index].co
            angle = math.atan2(co.x, -(co.y - yc))
            reach = abs(angle / math.pi) ** 0.8
            layer.data[index].uv = (0.5 + math.copysign(reach, angle) * 0.49, 0.012)


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


# Headgear

def build_hair(force, body="male"):
    """Every hair and beard of `body` (recipes.HAIR) into its own file, on its
    own skeleton (source/hair.blend, hair_female.blend), each as
    `Hair_<style>`: the Quaternius style cut down to `tris` (evenly either
    side), pushed out until every head of that body it may go on (build them
    first) lies at least `clearance` under it, looking out from the middle
    of the head (as check.fit looks); smooth, weighed on the Head and neck
    alone, all of it hair and dyed (a grey the game tints the hair's
    colour)."""
    styles = common.parts_of(recipes.HAIR, body)

    if not styles:
        print("wardrobe: no %s hair in the recipes: nothing to build" % body)
        return

    target = common.part_target("hair", body)
    path = common.SOURCE / ("%s.blend" % target)
    guard(path, force)
    armature, reference, extras = start(target, body)

    for extra in extras.values():
        bpy.data.objects.remove(extra)

    heads = head_points(body)

    if not heads:
        common.fail("no heads in source/%s.blend: build them first" % common.part_target("heads", body))

    centre = armature.data.bones["Head"].head_local + Vector((0.0, 0.0, 0.1))
    made = []

    for style in styles:
        h = recipes.HAIR[style]
        obj = quaternius_style(h["from"], "Hair_%s" % style)
        common.weld(obj)
        cut_style(obj, h)
        tail = h.get("tail")
        decimate = obj.modifiers.new("Decimate", "DECIMATE")
        decimate.ratio = min(1.0, (h["tris"] - (tail_triangles(tail) if tail else 0)) / max(common.tri_count(obj), 1))
        decimate.use_collapse_triangulate = True
        decimate.use_symmetry = True
        decimate.symmetry_axis = "X"
        common.select_only([obj])
        bpy.ops.object.modifier_apply(modifier=decimate.name)
        bm = bmesh.new()
        bm.from_mesh(obj.data)
        tree = BVHTree.FromBMesh(bm)
        # The head it covers: every head vertex it lies over, and where
        # check.fit's rays (its `fit_rays`) meet the heads under it.
        under = [p for p in heads + head_rays(body, centre, h.get("fit_rays") or CROWN_RAYS)
                 if tree.ray_cast(centre, (p - centre).normalized(), 0.4)[0] is not None]
        # A little over `clearance`, measured as check.fit measures: from
        # inside out, its underside.
        enclose(bm, under, centre, h["clearance"] + 0.001, from_inside=True)
        bm.to_mesh(obj.data)
        bm.free()

        if tail:
            add_tail(obj, tail, heads, h["clearance"])

        common.set_faces(obj, 1, recipes.FABRICS.index("hair"), 0.0, False, True, HAIR_GREY)
        weigh_part(obj, reference)
        ride(obj, 1e9, ("Head", "neck_01"))

        if "hem" in h:
            rest_on_neck(obj, h["hem"])

        common.unwrap([obj], {obj.name: 1.0})
        common.smooth(obj, HEAD_CREASE)
        materials(obj)
        obj.parent = armature
        obj.modifiers.new("Armature", "ARMATURE").object = armature
        made.append(obj)
        print("wardrobe: %s %s %d triangles over %d head vertices" % (h["kind"], style, common.tri_count(obj), len(under)))

    finish(path, made, reference)


def rest_on_neck(obj, hem):
    """A beard's hem resting on his throat: below `from` (under his chin)
    its neck's share of each vertex grows to `neck` at `to`, the rest his
    Head's. Borne by his head alone, a hem hanging to his throat went
    through his collar when he bowed his head (dozing: K33)."""
    neck, head = obj.vertex_groups["neck_01"], obj.vertex_groups["Head"]

    for vertex in obj.data.vertices:
        t = smoothstep(hem["from"], hem["to"], vertex.co.z)

        if t <= 0.0:
            continue

        now = next((g.weight for g in vertex.groups if g.group == neck.index), 0.0)
        share = max(now, now + (hem["neck"] - now) * t)
        neck.add([vertex.index], share, "REPLACE")
        head.add([vertex.index], 1.0 - share, "REPLACE")


def cut_style(obj, h):
    """A Quaternius style cut down to the part of it its recipe keeps: faces
    whose centre lies under `trim.below` dropped; with `keep.box` (two
    corners), only faces whose centre lies inside it kept."""
    trim, keep = h.get("trim"), h.get("keep")

    if not trim and not keep:
        return

    lo, hi = (Vector(keep["box"][0]), Vector(keep["box"][1])) if keep else (None, None)
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    doomed = []

    for face in bm.faces:
        c = face.calc_center_median()

        if (trim and c.z < trim["below"]) or (keep and not all(lo[i] <= c[i] <= hi[i] for i in range(3))):
            doomed.append(face)

    bmesh.ops.delete(bm, geom=doomed, context="FACES")
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context="VERTS")
    bm.to_mesh(obj.data)
    bm.free()


TAIL_RINGS = 5


def tail_triangles(tail):
    """A tail's triangles: `sides` quads between each of its rings, and a
    cone to its tip."""
    return tail["sides"] * 2 * (TAIL_RINGS - 1) + tail["sides"]


def add_tail(obj, tail, heads, clearance):
    """Hair tied back: a tail `length` long, `width` across at its top and
    half that at its tip, of `sides` round, from the back of the head at
    (0, at[0], at[1]) down the back of the neck (leaning a little back),
    each ring moved back until it clears every head of the body (`heads`,
    their points) by `clearance`; joined into `obj`. It leans back `lean`
    (metres back per metre down; 0.15 by default)."""
    down = Vector((0.0, tail.get("lean", 0.15), -1.0)).normalized()
    side = Vector((1.0, 0.0, 0.0))
    back = down.cross(side).normalized()
    start = Vector((0.0, tail["at"][0], tail["at"][1]))
    rings = []

    for i in range(TAIL_RINGS):
        t = i / (TAIL_RINGS - 1)
        centre = start + down * tail["length"] * t
        radius = tail["width"] * 0.5 * (1.0 - 0.5 * t)
        # The back of every head at this height, within the tail's width.
        behind = max((p.y for p in heads if abs(p.z - centre.z) <= 0.012 and abs(p.x) <= radius + 0.01), default=centre.y)
        centre.y = max(centre.y, behind + radius + clearance)
        rings.append([centre + (side * math.cos(a) + back * math.sin(a)) * radius
                      for a in (2.0 * math.pi * k / tail["sides"] for k in range(tail["sides"]))])

    tip = rings[-1][0].lerp(rings[-1][tail["sides"] // 2], 0.5) + down * tail["width"] * 0.4
    piece = common.loft("%s_tail" % obj.name, rings, closed=True, cap=tip)
    outward(piece)
    common.select_only([obj, piece], active=obj)
    bpy.ops.object.join()


# The grey hair is baked in (the game tints it: its JSON's dye_base).
HAIR_GREY = (0.5, 0.5, 0.5)
# check.fit's rays when a piece names none: over his crown.
CROWN_RAYS = {"elevations": [25, 45, 65, 85], "azimuths": list(range(0, 360, 30))}


def head_rays(body, centre, rays):
    """Where rays out from the middle of the head (check.fit's: `rays`,
    elevations and azimuths in degrees) meet each head of `body`: where a
    piece over them must clear them, measured as the check measures (between
    a head's vertices a coarse piece can sag nearer than at them)."""
    path = common.SOURCE / ("%s.blend" % common.part_target("heads", body))

    if not path.exists():
        return []

    with bpy.data.libraries.load(str(path)) as (source, target):
        target.objects = [name for name in source.objects if name.startswith("Head_")]

    found = []

    for obj in [o for o in target.objects if o is not None and o.type == "MESH"]:
        tree = common.bvh([obj])

        for elevation in rays["elevations"]:
            for azimuth in rays["azimuths"]:
                e, a = math.radians(elevation), math.radians(azimuth)
                hit = tree.ray_cast(centre, Vector((math.cos(e) * math.sin(a), -math.cos(e) * math.cos(a), math.sin(e))), 0.5)[0]

                if hit is not None:
                    found.append(hit)

        mesh = obj.data
        bpy.data.objects.remove(obj)
        bpy.data.meshes.remove(mesh)

    return found


def head_points(body="male"):
    """Every vertex of every head of `body` (its heads file): what its hair
    must cover."""
    path = common.SOURCE / ("%s.blend" % common.part_target("heads", body))

    if not path.exists():
        return []

    with bpy.data.libraries.load(str(path)) as (source, target):
        target.objects = [name for name in source.objects if name.startswith("Head_")]

    points = []

    for obj in [o for o in target.objects if o is not None and o.type == "MESH"]:
        mesh = obj.data
        points += [v.co.copy() for v in mesh.vertices]
        bpy.data.objects.remove(obj)
        bpy.data.meshes.remove(mesh)

    return points


def hair_points(styles, body="male", grow=0.0):
    """Every vertex of the hair `styles` of `body` (its hair file), and one
    tree over them grown `grow` out along their normals (None without any):
    what a hood goes over."""
    path = common.SOURCE / ("%s.blend" % common.part_target("hair", body))

    if not styles or not path.exists():
        return [], None

    with bpy.data.libraries.load(str(path)) as (source, target):
        target.objects = [name for name in source.objects if name in ["Hair_%s" % s for s in styles]]

    objects = [o for o in target.objects if o is not None and o.type == "MESH"]
    points = [v.co.copy() for o in objects for v in o.data.vertices]
    grown, polygons = [], []

    for obj in objects:
        start = len(grown)
        grown += [v.co + v.normal * grow for v in obj.data.vertices]
        polygons += [tuple(start + i for i in p.vertices) for p in obj.data.polygons]

    tree = BVHTree.FromPolygons(grown, polygons) if objects else None

    for obj in objects:
        mesh = obj.data
        bpy.data.objects.remove(obj)
        bpy.data.meshes.remove(mesh)

    return points, tree


def quaternius_style(relative, name):
    """A Quaternius hair or beard (a glTF skinned to its own copy of the
    skeleton) as a plain mesh called `name`, where it sits: its skeleton,
    weights, materials and stray pieces dropped."""
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=str(common.ROOT / relative))
    new = [o for o in bpy.data.objects if o not in before]
    obj = max((o for o in new if o.type == "MESH" and o.vertex_groups), key=lambda o: len(o.data.polygons))
    world = obj.matrix_world.copy()

    for other in new:
        if other is not obj:
            bpy.data.objects.remove(other)

    obj.parent = None
    obj.modifiers.clear()
    obj.data.transform(world)
    obj.matrix_world = Matrix.Identity(4)
    obj.vertex_groups.clear()
    obj.data.materials.clear()
    obj.name = name
    obj.data.name = name
    return obj


def build_headgear(force):
    path = common.SOURCE / "headgear.blend"
    guard(path, force)
    armature, reference, extras = start("headgear")

    for extra in extras.values():
        bpy.data.objects.remove(extra)

    kind = Kind({"belt": ("spine_01", 0.0), "garments": []}, armature, reference)
    made = {}

    for piece, g in recipes.HEADGEAR.items():
        made[piece] = HEADGEAR_BUILDERS[g["type"]](kind, g, piece, made)

    bpy.context.scene["wardrobe_chains"] = common.dump(kind.gear_chains)

    for obj in made.values():
        common.unwrap([obj], {obj.name: 1.0})
        common.smooth(obj, CREASE)
        materials(obj)
        obj.parent = armature
        obj.modifiers.new("Armature", "ARMATURE").object = armature

    finish(path, list(made.values()), reference)


def kettle(kind, g, piece, made):
    """A kettle hat forged the PS2 way, fitted over what it goes on (`over`):
    a round bowl of `segments` round, its foot an ellipse at `base_z` on
    the coif's outline there, one ring per `elevations` (degrees round its
    curve) up to a crown over the coif's, never nearer the coif than
    `clearance` + `slack` (looking out from his head's middle, `drop` below
    the band); the band between its first two rings leather; a curved brim
    `brim` wide turning `droop` down to a lip turned `lip` down. Wholly on
    his Head. Its trim (rivets above the band, a bright seam over the crown
    and a bright rim) is left for the bake (wr_details)."""
    # Over the coif, or (on a bare head) over every head and the hair worn
    # under it.
    tree = heads_tree(kind, g.get("over_hair", ())) if g["over"] == "head" else common.bvh([made[g["over"]]])
    centre = Vector((0.0, g["centre_y"], g["base_z"]))
    n = g["segments"]
    around = [2.0 * math.pi * i / n for i in range(n)]
    off = g["clearance"] + g["slack"]

    def flat(a):
        return Vector((math.sin(a), -math.cos(a), 0.0))

    def coif_along(d):
        """How far out the coif is from `centre` along `d`: its outermost
        surface (a ray through an opening, meeting his head's far side, is
        None)."""
        hit = common.outer_hit(tree, centre, d, 0.4)
        return (hit - centre).length if hit is not None and (hit - centre).dot(d) > 0.0 else None

    # The foot: the coif's outline at the band (a ray through the face
    # opening meets his head's far side: none).
    foot = [coif_along(flat(a)) for a in around]
    outline = [centre + flat(a) * r for a, r in zip(around, foot) if r is not None]
    # A round bowl the head sits in, not the head's shape (his crown is
    # narrow: a hat that followed it came out a cone). An ellipsoid on the
    # band's outline, `off` outside it, as tall as the coif's crown + `off`.
    half_x = max(abs(p.x) for p in outline) + off
    front, back = min(p.y for p in outline) - off, max(p.y for p in outline) + off
    middle_y, half_y = (front + back) * 0.5, (back - front) * 0.5
    middle = centre - Vector((0.0, 0.0, g["drop"]))

    def along(d):
        hit = common.outer_hit(tree, middle, d, 0.4)
        return (hit - middle).length if hit is not None and (hit - middle).dot(d) > 0.0 else None

    def need_near(d):
        """How far out the bowl must stand along `d`: over a coif, as far as
        it is there; over bare heads and hair, the most any way round it
        needs, half-way to the next points (a hair's crest rises between
        them, under the bowl's flat faces)."""
        best = along(d)

        if g["over"] != "head":
            return best

        u = d.orthogonal().normalized()
        v = d.cross(u)

        for a in (-0.2, 0.0, 0.2):
            for b in (-0.2, 0.0, 0.2):
                n = along((d + u * a + v * b).normalized())
                best = n if best is None or (n is not None and n > best) else best

        return best

    crown = (need_near(Vector((0.0, 0.0, 1.0))) or 0.13) + off - g["drop"]
    rows = []

    for elevation in [0.0] + list(g["elevations"]):
        phi = math.radians(elevation)
        row = []

        for a in around:
            point = Vector((half_x * math.cos(phi) * math.sin(a), middle_y - half_y * math.cos(phi) * math.cos(a),
                            centre.z + crown * math.sin(phi)))
            # Never nearer the coif than `off`, looking out from his head's
            # middle.
            d = (point - middle).normalized()
            # (The upper bowl only: round its band, the hair under it flares
            # over his ears, the brim's business.)
            need = need_near(d) if elevation >= 30.0 else along(d)

            if need is not None and (point - middle).length < need + off:
                point = middle + d * (need + off)

            row.append(point)

        rows.append(row)

    apex = Vector((0.0, middle_y, centre.z + crown))
    skull = common.loft("kettle_skull", rows, closed=True, cap=apex)
    outward(skull)

    # Curved: nearly flat off the band, turning down toward the lip.
    mid = [p + flat(a) * g["brim"] * 0.55 - Vector((0.0, 0.0, g["droop"] * 0.25)) for p, a in zip(rows[0], around)]
    rim = [p + flat(a) * g["brim"] - Vector((0.0, 0.0, g["droop"])) for p, a in zip(rows[0], around)]
    lip = [p + flat(a) * 0.003 - Vector((0.0, 0.0, g["lip"])) for p, a in zip(rim, around)]
    brim = common.loft("kettle_brim", [rows[0], mid, rim, lip], closed=True)
    upward(brim)

    iron = recipes.FABRICS.index(g["fabric"])
    common.set_faces(skull, 1, iron, 0.004, False, False, g["colour"])
    band_fabric, band_colour = g["band"]
    common.set_faces(skull, 1, recipes.FABRICS.index(band_fabric), 0.004, False, False, band_colour, range(n))
    # One sheet: drawn from both sides (it is seen from below).
    common.set_faces(brim, 1, iron, 0.004, True, False, g["colour"])
    obj = join_two(skull, brim, "Gear_%s" % piece)
    common.weld(obj)
    common.group(obj, g["bone"], 1.0)

    band_top = sum(p.z for p in rows[1]) / n
    obj["wr_details"] = common.dump({
        "centre": list(centre),
        "rivets": [{"z": band_top + 0.009, "count": g["rivets"], "size": 0.0055}],
        # The seam where its two halves were riveted, front to back.
        "comb": {"width": 0.004, "above": band_top + 0.01},
        "rim": {"radius": min(Vector((p.x - centre.x, p.y - centre.y, 0.0)).length for p in lip) - 0.004, "below": g["base_z"]},
    })
    print("wardrobe: %s %d triangles" % (piece, common.tri_count(obj)))
    return obj


def upward(obj):
    """A sheet's faces turned to face up (its top is the side it shows)."""
    outward(obj)

    if sum(p.normal.z for p in obj.data.polygons) < 0.0:
        obj.data.flip_normals()


def coif(kind, g, piece, made=None):
    """A mail hood built the PS2 way: `segments` round, a ring at its foot
    round his neck (`cape.top_z`) and one per `rings` (degrees up from the
    middle of his head), each point `thickness` + `slack` out from his head
    along the way from its middle; the quads over his face (between `open`
    degrees either side of his front, from his chin to his brow) left out,
    the opening's edge turned in; a short cape from the neck over the
    shoulders. It holds his whole skull at least `inside` under it."""
    hole = g["opening"]

    def in_opening(p):
        return abs(p.x) < hole["x"] + 0.01 and hole["from_z"] - 0.01 < p.z < hole["to_z"] + 0.01 and p.y < -0.02

    # Every head it may go over (heads_tree: his own and each low head):
    # fitted to his own alone, the heavy face's jaw came through the hood's
    # rim.
    head = heads_tree(kind)
    # The beards it is worn over (`over_beards`): they hang below his chin
    # in front of his throat, where it closes round his neck.
    beard_points, beards = hair_points(g.get("over_beards", ()), grow=g.get("beard_margin", 0.0))
    middle = kind.arm.data.bones["Head"].head_local + Vector((0.0, 0.0, 0.1))
    n = g["segments"]
    around = [2.0 * math.pi * i / n for i in range(n)]
    off = g["thickness"] + g["slack"]

    def reach(origin, d, fallback):
        hit = common.outer_hit(head, origin, d, 0.4)
        return (hit - origin).length if hit is not None and (hit - origin).dot(d) > 0.0 else fallback

    foot = Vector((0.0, middle.y, g["cape"]["top_z"]))
    rows = [[foot + Vector((math.sin(a), -math.cos(a), 0.0)) * (reach(foot, Vector((math.sin(a), -math.cos(a), 0.0)), 0.07) + off)
             for a in around]]

    for elevation in g["rings"]:
        e = math.radians(elevation)
        row = []

        for a in around:
            d = Vector((math.cos(e) * math.sin(a), -math.cos(e) * math.cos(a), math.sin(e)))
            row.append(middle + d * (reach(middle, d, 0.1) + off))

        rows.append(row)

    crown = middle + Vector((0.0, 0.0, reach(middle, Vector((0.0, 0.0, 1.0)), 0.12) + off))
    obj = common.loft("Gear_%s" % piece, rows, closed=True, cap=crown)
    outward(obj)

    bm = bmesh.new()
    bm.from_mesh(obj.data)
    # The face: the quads within `open` degrees of his front, from his
    # chin to his brow.
    half = math.radians(g["open"])
    doomed = []

    for face in bm.faces:
        c = face.calc_center_median()
        a = math.atan2(c.x - middle.x, -(c.y - middle.y))

        if abs(a) < half and hole["from_z"] - 0.02 < c.z < hole["to_z"] and len(face.verts) == 4:
            doomed.append(face)

    bmesh.ops.delete(bm, geom=doomed, context="FACES")
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context="VERTS")
    skull = [v.co.copy() for v in kind.ref.data.vertices
             if v.co.z > g["rigid_above"] - 0.02 and not in_opening(v.co)]
    # A little over `inside`: the game's low head strays a millimetre or two
    # outside the full one this measures.
    enclose(bm, skull, middle, g["inside"] + 0.004)
    opening = [e for e in bm.edges if e.is_boundary and (e.verts[0].co.z + e.verts[1].co.z) * 0.5 > g["cape"]["top_z"] + 0.005]

    # Its face edge turned in to the faces (resting on a beard it goes over,
    # where one is in its way), so the mail shows its thickness.
    made = bmesh.ops.extrude_edge_only(bm, edges=opening)["geom"]

    for vertex in (item for item in made if isinstance(item, bmesh.types.BMVert)):
        near = head.find_nearest(vertex.co)[0]

        if near is None:
            continue

        to = near + (vertex.co - near) * 0.3
        # Short of a beard in its way: the edge rests on it.
        hit = beards.ray_cast(vertex.co, to - vertex.co, (to - vertex.co).length) if beards is not None else (None,)

        if hit[0] is not None:
            to = vertex.co + (hit[0] - vertex.co) * max(0.0, 1.0 - 0.002 / max((hit[0] - vertex.co).length, 1e-6))

        vertex.co = to

    bm.to_mesh(obj.data)
    bm.free()
    # No face it goes over through it over its cape's top (its turned-in
    # edge lay inside the heavy face's jaw corner, 6 mm).
    over_cape = g["cape"]["top_z"] + 0.01
    clear_through(obj, heads_tree(kind, keep=lambda o, p: p.center.z > over_cape), lambda p: middle)
    fabric = recipes.FABRICS.index(g["fabric"])
    dye = g.get("dye", False)
    common.set_faces(obj, 1, fabric, g["thickness"], False, dye, g["colour"])
    cape = cape_shell(kind, g)

    if g["cape"].get("out"):
        # Faces out from his neck: baked (and lit) from outside, where it is
        # seen.
        face_away(cape, Vector((0.0, kind.at(("neck_01", 0.0)).y, 0.0)), Vector((0.0, 0.0, 1.0)))

    # One sheet of mail: drawn from both sides.
    common.set_faces(cape, 1, fabric, g["thickness"], True, dye, g["colour"])
    obj = join_two(obj, cape, obj.name)

    if beard_points:
        # Every beard it goes over under its mail, `beard_clear` under it
        # looking out from his neck (through its face opening a ray meets no
        # mail: that part shows): its neck and the cape's top hang in front
        # of a beard below his chin, not through it. Then any face of it
        # still within `beard_margin` of a beard (its turned-in edge, where
        # it meets a beard at the corners of his jaw) is pushed out until
        # none is.
        neck_y = kind.at(("neck_01", 0.0)).y

        def from_neck(p):
            return Vector((0.0, neck_y, p.z))

        bm = bmesh.new()
        bm.from_mesh(obj.data)
        enclose(bm, beard_points, from_neck, g["beard_clear"])
        bm.to_mesh(obj.data)
        bm.free()
        clear_through(obj, beards, from_neck)

    common.group(obj, common.TRANSFER, 1.0)
    weigh_part(obj, kind.ref)
    # The cape (and the hood's edge round his neck, which it tucks into).
    ride(obj, g["cape"]["top_z"] + 0.015, CAPE_BONES)
    # Above his ears the hood moves with his head alone: partly on his neck,
    # its big faces lagged when he bowed his head and his skull showed.
    rigid(obj, g["rigid_above"], "Head")

    if "tail" in g:
        obj = join_two(obj, hood_tail(kind, g, piece, obj, middle), obj.name)

    print("wardrobe: %s %d triangles" % (piece, common.tri_count(obj)))
    return obj


def hood_tail(kind, g, piece, hood, middle):
    """A hood's tail (a liripipe): a strip from the back of its crown
    (`elevation` degrees up from the middle of his head), `width` wide and
    tapering to a third, hanging `length` down his back, `clear` of what is
    there (the hood, its cape, his back), on a chain of `bones` cloth bones
    (`<piece>_tail`) under his Head; its top rides his Head. Dyed as the
    hood; one sheet, drawn from both sides."""
    t = g["tail"]
    e = math.radians(t["elevation"])
    d = Vector((0.0, math.cos(e), math.sin(e)))
    top = middle + d * (reach_out(common.bvh([hood]), middle, d, 0.12) + 0.004)
    behind = common.bvh([hood, kind.ref])
    rows, points, y = [], [], top.y

    for k in range(t["bones"] + 1):
        z = top.z - t["length"] * k / t["bones"]

        # Hanging, not hugging: never nearer him than the row above.
        if k > 0:
            back = common.outer_hit(behind, Vector((0.0, 0.0, z)), Vector((0.0, 1.0, 0.0)), 0.5)
            y = max(y, (back.y if back is not None else y) + t["clear"])

        half = t["width"] * 0.5 * (1.0 - 0.66 * k / t["bones"])
        centre = Vector((0.0, y, z))
        rows.append([centre + Vector((half, 0.0, 0.0)), centre - Vector((half, 0.0, 0.0))])
        points.append(centre)

    strip = common.loft("%s_tail" % piece, rows)
    face_away(strip, Vector((0.0, 0.0, 0.0)), Vector((0.0, 0.0, 1.0)))
    common.set_faces(strip, 1, recipes.FABRICS.index(g["fabric"]), g["thickness"], True, g.get("dye", False), g["colour"])
    chain = "%s_tail" % piece
    names = chain_bones(kind.arm, chain, "Head", points)
    common.group(strip, "Head", 1.0, range(0, 2))

    for k, name in enumerate(names, start=1):
        common.group(strip, name, 1.0, range(2 * k, 2 * k + 2))

    kind.gear_chains.append({"chain": chain, "parent": "Head", "bones": names,
                             "tip": round((points[-1] - points[-2]).length, 4), "piece": piece})
    return strip


# What a coif's cape hangs from: his neck, chest and collarbones. Not his
# head (looking round would swing it into his gambeson) or his arms
# (lowering them would pull it in).
CAPE_BONES = ("neck_01", "spine_03", "spine_02", "clavicle_l", "clavicle_r")


def ride(obj, below, bones):
    """The vertices of `obj` under height `below` weighed on `bones` only:
    their other weights dropped, the rest scaled back up to one (none left:
    wholly the first bone)."""
    names = {group.index: group.name for group in obj.vertex_groups}

    for vertex in obj.data.vertices:
        if vertex.co.z >= below:
            continue

        kept = [(names[g.group], g.weight) for g in vertex.groups if names[g.group] in bones and g.weight > 0.0]

        for name in [names[g.group] for g in vertex.groups if names[g.group] not in bones]:
            obj.vertex_groups[name].remove([vertex.index])

        total = sum(weight for _, weight in kept)

        if total <= 0.0:
            kept, total = [(bones[0], 1.0)], 1.0

        for name, weight in kept:
            group = obj.vertex_groups.get(name) or obj.vertex_groups.new(name=name)
            group.add([vertex.index], weight / total, "REPLACE")


def enclose(bm, points, centre, inside, rounds=8, from_inside=False):
    """A shell's vertices pushed out, along rays from `centre` (a point, or
    a function giving one for each of `points`), until every one of
    `points` lies at least `inside` under it: its flat faces sag between
    their corners, and a head shows through a sag. Under its outermost
    surface, or (`from_inside`) its innermost: a shell of two layers (hair)
    must clear the head with the one nearer it."""
    for _ in range(rounds):
        bm.faces.ensure_lookup_table()
        tree = BVHTree.FromBMesh(bm)
        short = {}

        for p in points:
            c = centre(p) if callable(centre) else centre
            d = (p - c).normalized()
            hit = tree.ray_cast(c, d, 0.4) if from_inside else tree.ray_cast(c + d * 0.4, -d, 0.4)

            if hit[0] is None or (hit[0] - c).dot(d) <= 0.0:
                continue

            need = inside - ((hit[0] - c).dot(d) - (p - c).length)

            if need > 0.0:
                for vertex in bm.faces[hit[2]].verts:
                    if need > short.get(vertex, (0.0, c))[0]:
                        short[vertex] = (need, c)

        if not short:
            return

        for vertex, (need, c) in short.items():
            seam = abs(vertex.co.x) < 1e-4
            vertex.co += (vertex.co - c).normalized() * need
            vertex.co.x = 0.0 if seam else vertex.co.x


def clear_through(obj, tree, centre, step=0.001, rounds=80):
    """Each face of `obj` through a face of `tree` pushed out, a `step` at a
    time along the way from `centre` (a function of the vertex), until none
    is; each vertex's mirror twin (across x = 0) pushed with it, and its
    middle seam kept on it."""
    vertices = obj.data.vertices
    twin = {}

    for vertex in vertices:
        mirrored = Vector((-vertex.co.x, vertex.co.y, vertex.co.z))
        other = min(vertices, key=lambda v: (v.co - mirrored).length)
        twin[vertex.index] = other.index if (other.co - mirrored).length < 0.002 else vertex.index

    for _ in range(rounds):
        pairs = common.bvh([obj]).overlap(tree)

        if not pairs:
            return

        pushed = {v for face, _ in pairs for v in obj.data.polygons[face].vertices}

        for index in pushed | {twin[i] for i in pushed}:
            vertex = vertices[index]
            seam = abs(vertex.co.x) < 1e-4
            vertex.co += (vertex.co - centre(vertex.co)).normalized() * step
            vertex.co.x = 0.0 if seam else vertex.co.x

    print("wardrobe: %s still through %d faces after %d rounds" % (obj.name, len(common.bvh([obj]).overlap(tree)), rounds))


def rigid(obj, above, bone):
    """The vertices of `obj` over height `above` wholly on `bone`."""
    names = {group.index: group.name for group in obj.vertex_groups}
    target = obj.vertex_groups.get(bone) or obj.vertex_groups.new(name=bone)

    for vertex in obj.data.vertices:
        if vertex.co.z <= above:
            continue

        for name in [names[g.group] for g in vertex.groups if names[g.group] != bone]:
            obj.vertex_groups[name].remove([vertex.index])

        target.add([vertex.index], 1.0, "REPLACE")


def cape_shell(kind, g):
    """The coif's cape: a bell of three rings round his neck, snug under the
    hood at the top, hung out and down like a cone (steep over chest and
    back, shallower over the shoulders), then smoothed and pushed out until
    it stands `clear` of his trunk (neck, chest, back, collarbones): it
    drapes over whatever he wears there. Not of his arms: raised in the
    rest pose, they would lift it into a plate, where he stands in the game
    with them down."""
    cape = g["cape"]
    trunk = trunk_tree(kind.ref)
    neck = kind.at(("neck_01", 0.0))
    top = cape["top_z"] + 0.012
    axis = Vector((0.0, neck.y, top))
    rings = [[], [], []]

    for i in range(16):
        theta = math.radians(i * 22.5)
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
                near, normal, _, _ = trunk.find_nearest(point)
                depth = (point - near).dot(normal) if near is not None else 1.0

                if depth < cape["clear"]:
                    point = point + normal * (cape["clear"] - depth)

                ring[i] = point

    return common.loft("cape", rings, closed=True)


def trunk_tree(reference):
    """A tree of the faces of his neck, chest, back and collarbones."""
    names = {group.index: group.name for group in reference.vertex_groups}
    heaviest = [names[max(v.groups, key=lambda g: g.weight).group] if v.groups else "" for v in reference.data.vertices]
    faces = [p for p in reference.data.polygons if majority([heaviest[i] for i in p.vertices]) in CAPE_BONES + ("Head", "pelvis")]
    vertices = [v.co.copy() for v in reference.data.vertices]
    return BVHTree.FromPolygons(vertices, [tuple(p.vertices) for p in faces])


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
    # Drawn from both sides: made for the game's old look, its brim is one
    # sheet, and when he bows his head the back of it shows its underside.
    common.set_faces(obj, 1, 0, 0.004, True, False, (0.5, 0.5, 0.5))
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


def heads_tree(kind, hair=(), keep=None):
    """What a helm goes over, as one tree: his own head (the full body's),
    every low head in heads.blend (a low head strays a little outside the
    full one) and the `hair` styles (hair.blend) it is worn over; only the
    faces `keep(obj, polygon)` passes, given."""
    objects = [head_region(kind.ref, "wr_helm_head")]

    for path, names in ((common.SOURCE / "heads.blend", None), (common.SOURCE / "hair.blend", ["Hair_%s" % h for h in hair])):
        if not path.exists() or names == []:
            continue

        with bpy.data.libraries.load(str(path)) as (source, target):
            target.objects = [name for name in source.objects if (name.startswith("Head_") if names is None else name in names)]

        objects += [o for o in target.objects if o is not None and o.type == "MESH"]

    tree = common.bvh(objects, keep=keep)

    for obj in objects:
        mesh = obj.data
        bpy.data.objects.remove(obj)
        bpy.data.meshes.remove(mesh)

    return tree


def helm(kind, g, piece, made):
    """A nasal helm forged the PS2 way, set straight on his head (every
    head it may go on: heads_tree): a round bowl of `segments` round on the
    head's outline at `base_z`, one ring per `elevations` (degrees round its
    curve) up to a crown `point` higher than a round one (its upper rings
    drawn up after it), never nearer his head than `clearance` + `slack`
    (looking out from his head's middle, `drop` below the foot); a brow band
    `band` tall at its foot standing `proud` of the bowl, its lower edge
    turned in toward his brow; a nasal bar (`nasal`: `width` wide, `length`
    down his nose, `proud` off his face). Wholly on his Head. Its foot ring
    is kept for mail to hang from (kind.rims); its trim (rivets round the
    band, a bright seam over the crown) is left for the bake."""
    tree = heads_tree(kind)
    centre = Vector((0.0, g["centre_y"], g["base_z"]))
    n = g["segments"]
    around = [2.0 * math.pi * i / n for i in range(n)]
    off = g["clearance"] + g["slack"]

    def flat(a):
        return Vector((math.sin(a), -math.cos(a), 0.0))

    def head_along(origin, d):
        hit = common.outer_hit(tree, origin, d, 0.4)
        return (hit - origin).length if hit is not None and (hit - origin).dot(d) > 0.0 else None

    under = [head_along(centre, flat(a)) for a in around]
    outline = [centre + flat(a) * r for a, r in zip(around, under) if r is not None]
    half_x = max(abs(p.x) for p in outline) + off
    front, back = min(p.y for p in outline) - off, max(p.y for p in outline) + off
    middle_y, half_y = (front + back) * 0.5, (back - front) * 0.5
    middle = centre - Vector((0.0, 0.0, g["drop"]))
    crown = (head_along(middle, Vector((0.0, 0.0, 1.0))) or 0.13) + off - g["drop"]

    def ring(elevation, rise=0.0, out=0.0):
        phi = math.radians(elevation)
        row = []

        for a in around:
            point = Vector((half_x * math.cos(phi) * math.sin(a), middle_y - half_y * math.cos(phi) * math.cos(a),
                            centre.z + crown * math.sin(phi) + rise))
            d = (point - middle).normalized()
            need = head_along(middle, d)

            if need is not None and (point - middle).length < need + off:
                point = middle + d * (need + off)

            row.append(point + flat(a) * out)

        return row

    band_top = math.degrees(math.asin(min(g["band"] / crown, 1.0)))
    foot = ring(0.0, out=g["proud"])
    # The band's lower edge turned in toward his brow: its thickness shows,
    # and no one sees up into it.
    lip = [c + (p - c) * 0.35 for p, c in
           ((p, centre + flat(a) * (r if r is not None else (p - centre).length - off)) for p, a, r in zip(foot, around, under))]
    rows = [lip, foot, ring(band_top, out=g["proud"]), ring(band_top)]
    rows += [ring(e, rise=g["point"] * math.sin(math.radians(e)) ** 4) for e in g["elevations"]]
    apex = Vector((0.0, middle_y, centre.z + crown + g["point"]))
    skull = common.loft("helm_skull", rows, closed=True, cap=apex)
    outward(skull)
    iron = recipes.FABRICS.index(g["fabric"])
    common.set_faces(skull, 1, iron, 0.004, False, False, g["colour"])
    bar = nasal_bar(g, foot[0], tree)
    common.set_faces(bar, 1, iron, 0.004, False, False, g["colour"])
    obj = join_two(skull, bar, "Gear_%s" % piece)
    common.group(obj, g["bone"], 1.0)
    kind.rims[piece] = foot
    obj["wr_details"] = common.dump({
        "centre": list(centre),
        "rivets": [{"z": g["base_z"] + g["band"] * 0.5, "count": g["rivets"], "size": 0.0045}],
        # The seam where its halves were riveted, front to back.
        "comb": {"width": 0.004, "above": g["base_z"] + g["band"] + 0.012},
    })
    print("wardrobe: %s %d triangles" % (piece, common.tri_count(obj)))
    return obj


def nasal_bar(g, front, tree):
    """A helm's nasal bar: a strip of iron from up inside the band's front
    (`front`, the foot ring there) straight down his nose `length`, `width`
    wide, leaning out as far as it must to stand `proud` off his face all the
    way down."""
    nasal = g["nasal"]
    thick = 0.004
    y0 = front.y - thick * 0.5
    z0 = g["base_z"]
    y1 = y0

    # Where his face is at each height down the bar (the most forward of it
    # across the bar's width), the bar leans out just enough to clear it.
    for step in range(1, 9):
        t = step / 8.0
        z = z0 - nasal["length"] * t
        face = None

        for x in (-nasal["width"] * 0.5, 0.0, nasal["width"] * 0.5):
            hit = common.outer_hit(tree, Vector((x, 0.02, z)), Vector((0.0, -1.0, 0.0)), 0.4)

            if hit is not None and (face is None or hit.y < face):
                face = hit.y

        if face is not None:
            need = face - nasal["proud"] - thick * 0.5
            y1 = min(y1, y0 + (need - y0) / t)

    top = Vector((0.0, y0, z0 + 0.012))
    bottom = Vector((0.0, y1, z0 - nasal["length"]))
    along = (bottom - top).normalized()
    across = Vector((1.0, 0.0, 0.0))
    return common.box("helm_nasal", (top + bottom) * 0.5, across, across.cross(along).normalized(), along,
                      (nasal["width"], thick, (bottom - top).length))


def curtain(kind, g, piece, made):
    """Mail hanging from a helm's foot ring (`on`), tucked `tuck` inside it,
    round his sides and back (open `open` degrees either side of his face):
    three rings, to a hem `length_side` below the foot at his sides and
    `length_back` at his back, laid over him (smoothed and pushed out until
    the hem stands `clear` of his head, neck, chest, back and collarbones,
    the middle half that). Its top ring rides his Head (as the helm does),
    the middle half his Head and half his neck, the hem his neck, chest and
    collarbones. One sheet, drawn from both sides."""
    foot = kind.rims[g["on"]]
    n = len(foot)
    trunk = trunk_tree(kind.ref)
    count = 15
    span = 360.0 - 2.0 * g["open"]
    rows = [[], [], []]

    for i in range(count):
        a = math.radians(g["open"] + span * i / (count - 1))
        out = Vector((math.sin(a), -math.cos(a), 0.0))
        at = a / (2.0 * math.pi) * n
        k = int(math.floor(at)) % n
        top = foot[k].lerp(foot[(k + 1) % n], at - math.floor(at)) - out * g["tuck"]
        length = g["length_side"] + (g["length_back"] - g["length_side"]) * max(0.0, -math.cos(a)) ** 2
        rows[0].append(top)
        rows[1].append(top - Vector((0.0, 0.0, length * 0.5)))
        rows[2].append(top - Vector((0.0, 0.0, length)))

    for _ in range(4):
        for k, clear in ((1, g["clear"] * 0.5), (2, g["clear"])):
            ring = rows[k]
            smoothed = [ring[0]] + [(ring[i - 1] + ring[i] * 2.0 + ring[i + 1]) * 0.25 for i in range(1, count - 1)] + [ring[-1]]

            for i, point in enumerate(smoothed):
                near, normal, _, _ = trunk.find_nearest(point)
                depth = (point - near).dot(normal) if near is not None else 1.0
                ring[i] = point + normal * (clear - depth) if depth < clear else point

    obj = common.loft("Gear_%s" % piece, rows)
    face_away(obj, Vector((0.0, sum(p.y for p in foot) / n, 0.0)), Vector((0.0, 0.0, 1.0)))
    common.set_faces(obj, 1, recipes.FABRICS.index(g["fabric"]), g["thickness"], True, False, g["colour"])
    weigh_part(obj, kind.ref)
    ride(obj, max(p.z for p in rows[2]) + 1e-4, CAPE_BONES)
    only(obj, range(count, 2 * count), {"Head": 0.5, "neck_01": 0.5})
    only(obj, range(0, count), {"Head": 1.0})
    print("wardrobe: %s %d triangles" % (piece, common.tri_count(obj)))
    return obj


def only(obj, vertices, table):
    """`vertices` of `obj` on the bones of `table` ({bone: weight}) alone."""
    names = {group.index: group.name for group in obj.vertex_groups}

    for index in vertices:
        for name in [names[g.group] for g in obj.data.vertices[index].groups]:
            obj.vertex_groups[name].remove([index])

    for bone, weight in table.items():
        group = obj.vertex_groups.get(bone) or obj.vertex_groups.new(name=bone)
        group.add(list(vertices), weight, "REPLACE")


HEADGEAR_BUILDERS = {"coif": coif, "kettle": kettle, "helm": helm, "curtain": curtain, "import": imported}


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


if __name__ == "__main__":
    main()
