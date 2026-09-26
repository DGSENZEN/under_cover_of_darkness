"""Bakes a source .blend's parts into PS2 textures (spec §6.5).

    tools/wardrobe/wardrobe.sh bake watchman|heads|headgear|all

For each part, Cycles bakes at 4x size: where each texel is on him, which
way it faces, its fabric, colour and dye (emission passes), and ambient
occlusion. fabrics.py paints the fabric; then the light is painted in the
PS2 way (occlusion and a soft top light), dirt gathers low and in creases,
the texels no island covers take their neighbours' colours (no black bleeding
into mipmaps), the picture is shrunk to size and cut to 64 colours. A kind
also gets its mask (red the dye, green bare skin, blue the dirt); a head is
baked from the detailed Quaternius head (skin, eyes, brows) and then weathered.

Writes into assets/characters/wardrobe; export.py validates and ships. The
.blend itself is left as it was.
"""

import os
import sys

# No __pycache__ beside the tools (Blender would write one each run).
sys.dont_write_bytecode = True
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import bpy  # noqa: E402
import numpy as np  # noqa: E402

import common  # noqa: E402
import fabrics  # noqa: E402
import recipes  # noqa: E402

SUPERSAMPLE = 4
AO_DISTANCE = 0.3
LUMA = np.array([0.299, 0.587, 0.114])


def main():
    target, _ = common.args()
    path = common.SOURCE / ("%s.blend" % target)

    if not path.exists() or bpy.data.filepath != str(path):
        common.fail("no source/%s.blend" % target)

    cycles()

    if target in recipes.KINDS:
        bake_kind(recipes.KINDS[target])
    elif target == "heads":
        bake_heads()
    elif target == "headgear":
        bake_headgear()
    else:
        common.fail("nothing to bake called '%s'" % target)


def cycles():
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"

    try:
        preferences = bpy.context.preferences.addons["cycles"].preferences
        preferences.compute_device_type = "METAL"
        preferences.get_devices()

        for device in preferences.devices:
            device.use = True

        scene.cycles.device = "GPU"
    except Exception:
        scene.cycles.device = "CPU"

    scene.cycles.samples = 16
    scene.render.bake.margin = 2 * SUPERSAMPLE
    scene.render.bake.margin_type = "EXTEND"

    if scene.world is None:
        scene.world = bpy.data.worlds.new("World")

    scene.world.light_settings.distance = AO_DISTANCE


# ---------------------------------------------------------------------------
# Passes
# ---------------------------------------------------------------------------

def working_copy(obj):
    """A copy to bake from, alone in its material slot, no modifiers."""
    copy = obj.copy()
    copy.data = obj.data.copy()
    copy.name = obj.name + "_bake"
    copy.modifiers.clear()
    copy.parent = None
    copy.matrix_world = obj.matrix_world.copy()
    bpy.context.scene.collection.objects.link(copy)
    copy.hide_render = False
    copy.hide_set(False)
    return copy


def image(name, size, data=True):
    found = bpy.data.images.get(name)

    if found is not None:
        bpy.data.images.remove(found)

    made = bpy.data.images.new(name, size, size, alpha=True, float_buffer=data)
    made.colorspace_settings.name = "Non-Color" if data else "sRGB"
    made.generated_color = (0.0, 0.0, 0.0, 0.0)
    return made


def emit_material(obj, target, build):
    """One material on `obj` emitting what build(nodes, links) returns,
    baking into `target`."""
    material = bpy.data.materials.new("wr_emit")
    material.use_nodes = True
    nodes, links = material.node_tree.nodes, material.node_tree.links
    nodes.clear()
    out = nodes.new("ShaderNodeOutputMaterial")
    emission = nodes.new("ShaderNodeEmission")
    links.new(build(nodes, links), emission.inputs["Color"])
    links.new(emission.outputs["Emission"], out.inputs["Surface"])
    texture = nodes.new("ShaderNodeTexImage")
    texture.image = target
    nodes.active = texture
    obj.data.materials.clear()
    obj.data.materials.append(material)

    for polygon in obj.data.polygons:
        polygon.material_index = 0

    return material


def target_node(obj, target):
    """Every material of `obj` bakes into `target` (its active node)."""
    for material in obj.data.materials:
        if material is None:
            continue

        material.use_nodes = True
        node = material.node_tree.nodes.new("ShaderNodeTexImage")
        node.image = target
        material.node_tree.nodes.active = node


def bake(obj, kind, target, **settings):
    common.select_only([obj])
    bpy.ops.object.bake(type=kind, use_clear=True, margin=2 * SUPERSAMPLE, **settings)
    pixels = np.empty(target.size[0] * target.size[1] * 4, dtype=np.float32)
    target.pixels.foreach_get(pixels)
    return pixels.reshape(target.size[1], target.size[0], 4)


def data_passes(obj, size, low, high):
    """Position (metres), normal, fabric, dye, colour (linear) and
    occlusion of every texel of `obj`, and which texels any island covers."""
    work = working_copy(obj)
    target = image("wr_pass", size)
    span = high - low

    def position(nodes, links):
        coords = nodes.new("ShaderNodeTexCoord")
        shift = nodes.new("ShaderNodeVectorMath")
        shift.operation = "SUBTRACT"
        shift.inputs[1].default_value = tuple(low)
        scale = nodes.new("ShaderNodeVectorMath")
        scale.operation = "DIVIDE"
        scale.inputs[1].default_value = tuple(span)
        links.new(coords.outputs["Object"], shift.inputs[0])
        links.new(shift.outputs["Vector"], scale.inputs[0])
        return scale.outputs["Vector"]

    def ids(nodes, links):
        fabric = nodes.new("ShaderNodeAttribute")
        fabric.attribute_name = "wr_fabric"
        dye = nodes.new("ShaderNodeAttribute")
        dye.attribute_name = "wr_dye"
        eighth = nodes.new("ShaderNodeMath")
        eighth.operation = "DIVIDE"
        eighth.inputs[1].default_value = 8.0
        links.new(fabric.outputs["Fac"], eighth.inputs[0])
        combine = nodes.new("ShaderNodeCombineXYZ")
        links.new(eighth.outputs["Value"], combine.inputs["X"])
        links.new(dye.outputs["Fac"], combine.inputs["Y"])
        combine.inputs["Z"].default_value = 1.0
        return combine.outputs["Vector"]

    def colour(nodes, links):
        base = nodes.new("ShaderNodeAttribute")
        base.attribute_name = "wr_base"
        return base.outputs["Color"]

    # Only its own shape shades it: the part itself, under the copy, would
    # black it out, and another part (a hat over a coif) is shaded by the
    # game's own shadows, not painted into a part that may be worn alone.
    others = [o for o in bpy.data.objects if o is not work and o.type == "MESH" and not o.hide_render]

    for other in others:
        other.hide_render = True

    passes = {}

    try:
        emit_material(work, target, position)
        passes["position"] = bake(work, "EMIT", target)
        emit_material(work, target, ids)
        passes["ids"] = bake(work, "EMIT", target)
        emit_material(work, target, colour)
        passes["colour"] = bake(work, "EMIT", target)
        passes["normal"] = bake(work, "NORMAL", target, normal_space="OBJECT")
        passes["ao"] = bake(work, "AO", target)
    finally:
        for other in others:
            other.hide_render = False

    bpy.data.objects.remove(work)

    covered = passes["ids"][..., 2] > 0.5
    return {
        "covered": covered,
        "position": low + passes["position"][..., :3] * span,
        "normal": passes["normal"][..., :3] * 2.0 - 1.0,
        "fabric": np.rint(passes["ids"][..., 0] * 8.0).astype(np.int64),
        "dye": passes["ids"][..., 1] > 0.5,
        "colour": passes["colour"][..., :3],
        "ao": passes["ao"][..., 0],
    }


def bounds(obj):
    xs = np.array([v.co[:] for v in obj.data.vertices])
    return xs.min(0) - 0.01, xs.max(0) + 0.01


# ---------------------------------------------------------------------------
# Painting
# ---------------------------------------------------------------------------

def smoothstep(a, b, x):
    t = np.clip((x - a) / (b - a), 0.0, 1.0)
    return t * t * (3.0 - 2.0 * t)


def light(albedo, passes):
    """The light painted in: occlusion and a soft top light.

    Tuned by eye (stage_wardrobe, Sept 25 2026): occlusion 0.35 + 0.65 ao
    (0.5 + 0.5 flattened the gambeson's folds and underarms at 2 m: the
    painted depth is the PS2 look); top light 0.78 + 0.22 n.z (the game's
    own lights do the rest)."""
    return albedo * ((0.35 + 0.65 * passes["ao"]) * (0.78 + 0.22 * passes["normal"][..., 2]))[..., None]


def grime(passes):
    """Where dirt gathers: low on him (boots, hems) and in creases. Up to
    his knees (0.8 m): a watchman walks the mud, and a mask that stopped at
    his shins left his hems clean however dirty the roll made him."""
    p = passes["position"]
    flat = p.reshape(-1, 3)
    speckle = fabrics.noise(fabrics.mirrored(flat), 25.0, 71).reshape(p.shape[:2])
    low = 1.0 - smoothstep(0.12, 0.8, p[..., 2])
    return np.clip(0.65 * low * (0.7 + 0.6 * speckle) + 0.45 * (1.0 - passes["ao"]), 0.0, 1.0)


def fill(rgb, covered):
    """Texels no island covers take their neighbours' colours, outward from
    the islands, so shrinking and mipmapping never bleed black in."""
    out = rgb.copy()
    known = covered.copy()

    for _ in range(64):
        if known.all():
            break

        grow = np.zeros_like(out)
        count = np.zeros(known.shape)

        for dy, dx in ((0, 1), (0, -1), (1, 0), (-1, 0)):
            shifted = np.roll(np.roll(out * known[..., None], dy, 0), dx, 1)
            grow += shifted
            count += np.roll(np.roll(known, dy, 0), dx, 1)

        new = (~known) & (count > 0)
        out[new] = grow[new] / count[new][:, None]
        known |= new

    return out


def shrink(values):
    """The supersampled picture down to size (the average of each block)."""
    h, w = values.shape[:2]
    s = SUPERSAMPLE
    return values.reshape(h // s, s, w // s, s, *values.shape[2:]).mean(axis=(1, 3))


def to_srgb(linear):
    linear = np.clip(linear, 0.0, 1.0)
    return np.where(linear <= 0.0031308, linear * 12.92, 1.055 * np.power(linear, 1.0 / 2.4) - 0.055)


def to_linear(srgb):
    return np.where(srgb <= 0.04045, srgb / 12.92, np.power((srgb + 0.055) / 1.055, 2.4))


def palettize(srgb, colours=common.PALETTE, iterations=12):
    """Cut to `colours` colours (k-means, starting from colours spread over
    the picture's brightness): PS2's colour-table textures."""
    pixels = np.round(srgb.reshape(-1, 3) * 255.0)
    unique = np.unique(pixels, axis=0)

    if len(unique) <= colours:
        return pixels.reshape(srgb.shape) / 255.0

    order = unique[np.argsort(unique @ LUMA)]
    centres = order[np.linspace(0, len(order) - 1, colours).astype(int)].astype(np.float64)

    for _ in range(iterations):
        label = ((pixels[:, None, :] - centres[None, :, :]) ** 2).sum(-1).argmin(1)

        for c in range(colours):
            members = pixels[label == c]

            if len(members):
                centres[c] = members.mean(0)

    centres = np.round(centres)
    label = ((pixels[:, None, :] - centres[None, :, :]) ** 2).sum(-1).argmin(1)
    return centres[label].reshape(srgb.shape) / 255.0


def save_png(rgb, path, colour=True):
    """An 8-bit PNG of `rgb` (0..1; sRGB when `colour`)."""
    h, w = rgb.shape[:2]
    made = bpy.data.images.new("wr_out", w, h, alpha=False, float_buffer=False)
    made.colorspace_settings.name = "sRGB" if colour else "Non-Color"
    rgba = np.ones((h, w, 4), dtype=np.float32)
    rgba[..., :3] = np.clip(rgb, 0.0, 1.0)
    made.pixels.foreach_set(rgba.ravel())
    os.makedirs(os.path.dirname(path), exist_ok=True)
    made.filepath_raw = path
    made.file_format = "PNG"
    made.save()
    bpy.data.images.remove(made)
    print("wardrobe: baked %s" % os.path.relpath(path, common.ROOT))


def paint_part(obj, size, stripe=None):
    """A garment part's lit, dirtied albedo (linear, supersampled), its dirt,
    its dye and its skin masks."""
    low, high = bounds(obj)
    passes = data_passes(obj, size * SUPERSAMPLE, low, high)
    covered = passes["covered"]
    albedo = np.zeros(passes["colour"].shape)
    flat = covered
    albedo[flat] = fabrics.paint(passes["fabric"][flat], passes["position"][flat], passes["normal"][flat], passes["colour"][flat])
    dye = passes["dye"] & covered

    if stripe is not None:
        band = dye & (np.abs(passes["position"][..., 0]) < stripe["half_width"])
        albedo[band] = albedo[band] / np.maximum(passes["colour"][band], 1e-4) * to_linear(np.array(stripe["colour"]))
        dye &= ~band

    dirt = grime(passes) * covered
    lit = light(albedo, passes) * (1.0 - 0.22 * dirt)[..., None]
    return lit, covered, dye, (passes["fabric"] == fabrics.SKIN) & covered, dirt


# Palettes: common.PALETTE (64) colours an albedo. Tuned by eye: at 32 the
# faces' skin bands on the brow and cheeks; the outfit and mail look the same
# either way, and 64 is the spec's ceiling.
def finish(lit, covered, path):
    rgb = to_srgb(shrink(fill(lit, covered)))
    save_png(palettize(rgb), path)


# ---------------------------------------------------------------------------
# What gets baked
# ---------------------------------------------------------------------------

def bake_kind(recipe):
    outfit = bpy.data.objects["Outfit"]
    tabard = next((g for g in recipe["garments"] if g.get("stripe")), None)
    stripe = {"colour": tabard["stripe"], "half_width": 0.035} if tabard else None
    lit, covered, dye, skin, dirt = paint_part(outfit, 256, stripe)
    finish(lit, covered, str(common.WARDROBE / ("%s.png" % recipe["kind"])))
    mask = np.stack([dye, skin, dirt], axis=-1).astype(np.float64)
    save_png(shrink(fill(mask, covered)), str(common.WARDROBE / ("%s_mask.png" % recipe["kind"])), colour=False)


def bake_headgear():
    for obj in [o for o in bpy.data.objects if o.name.startswith("Gear_") and o.type == "MESH"]:
        lit, covered, _, _, _ = paint_part(obj, 128)
        finish(lit, covered, str(common.WARDROBE / "headgear" / ("%s.png" % obj.name[len("Gear_"):])))


def bake_heads():
    for low in [o for o in bpy.data.objects if o.name.startswith("Head_") and o.type == "MESH"]:
        face = low.name[len("Head_"):]
        recipe = recipes.HEADS[face]
        size = 128 * SUPERSAMPLE
        lo, hi = bounds(low)
        passes = data_passes(low, size, lo, hi)
        sources = [o for o in bpy.data.objects if o.name.startswith("High_%s" % face)]

        for source in sources:
            if source.name.endswith("_brows"):
                tint(source, recipe["brows"])

        skin = skin_image(sources)
        original = np.empty(skin.size[0] * skin.size[1] * 4, dtype=np.float32)
        skin.pixels.foreach_get(original)

        for tone, multiplier in recipe["tones"].items():
            # His skin in this tone: the Quaternius skin times the tone (in
            # linear light), written into the image the detailed head wears.
            toned = original.reshape(-1, 4).copy()
            toned[:, :3] = to_srgb(to_linear(toned[:, :3]) * np.array(multiplier))
            skin.pixels.foreach_set(toned.ravel())
            skin.update()
            albedo = skin_from(low, sources, size)
            albedo = weather(albedo, passes, recipe["grit"]) * passes["covered"][..., None]
            lit = light(albedo, passes)
            finish(lit, passes["covered"], str(common.WARDROBE / "heads" / ("%s_%s.png" % (face, tone))))

        skin.pixels.foreach_set(original)


def tint(source, colour):
    """A detailed part's texture multiplied by `colour` (sRGB): the brows, a
    Quaternius hair card of pale grey strands, in his hair's colour."""
    for material in source.data.materials:
        if material is None or not material.use_nodes:
            continue

        nodes, links = material.node_tree.nodes, material.node_tree.links
        principled = next((n for n in nodes if n.type == "BSDF_PRINCIPLED"), None)

        if principled is None or not principled.inputs["Base Color"].is_linked:
            continue

        feed = principled.inputs["Base Color"].links[0].from_socket
        mix = nodes.new("ShaderNodeMix")
        mix.data_type = "RGBA"
        mix.blend_type = "MULTIPLY"
        mix.inputs[0].default_value = 1.0
        mix.inputs[7].default_value = (*to_linear(np.array(colour)), 1.0)
        links.new(feed, mix.inputs[6])
        links.new(mix.outputs[2], principled.inputs["Base Color"])


def skin_image(sources):
    """The skin texture the detailed head wears (its base colour image)."""
    for source in sources:
        for material in source.data.materials:
            if material is None or not material.use_nodes or "Superhero" not in material.name:
                continue

            for node in material.node_tree.nodes:
                if node.type == "TEX_IMAGE" and node.image is not None and "Normal" not in node.image.name \
                        and "Roughness" not in node.image.name:
                    return node.image

    common.fail("the detailed head has no skin texture")


def skin_from(low, sources, size):
    """The detailed head (skin, eyes, brows) baked onto the low head: its
    colours, linear, no light."""
    for source in sources:
        source.hide_render = False
        source.hide_set(False)

    work = working_copy(low)
    target = image("wr_skin", size)
    material = bpy.data.materials.new("wr_target")
    material.use_nodes = True
    work.data.materials.clear()
    work.data.materials.append(material)
    target_node(work, target)
    common.select_only(sources + [work], active=work)
    bpy.ops.object.bake(type="DIFFUSE", pass_filter={"COLOR"}, use_selected_to_active=True, cage_extrusion=0.01,
                        max_ray_distance=0.03, use_clear=True, margin=2 * SUPERSAMPLE)
    pixels = np.empty(size * size * 4, dtype=np.float32)
    target.pixels.foreach_get(pixels)
    bpy.data.objects.remove(work)
    return pixels.reshape(size, size, 4)[..., :3].astype(np.float64)


def weather(albedo, passes, grit):
    """A hard life on his face: stubble, bags under the eyes, lines on the
    brow, a scar, and duller eyes (positions are the Quaternius head's)."""
    p = passes["position"]
    n = passes["normal"]
    ax = np.abs(p[..., 0])
    flat = p.reshape(-1, 3)
    fine = fabrics.noise(fabrics.mirrored(flat), 500.0, 81).reshape(p.shape[:2])
    out = albedo.copy()

    # Stubble: jaw, chin and upper lip, speckled; not on the lips.
    mouth = np.sqrt((p[..., 0] / 1.6) ** 2 + (p[..., 1] + 0.085) ** 2 + (p[..., 2] - 1.623) ** 2)
    jaw = smoothstep(1.66, 1.635, p[..., 2]) * smoothstep(1.54, 1.575, p[..., 2]) * (n[..., 1] < 0.35) * (mouth > 0.011)
    out *= (1.0 - grit["stubble"] * 0.32 * jaw * (0.55 + 0.9 * (fine > 0.45)))[..., None]

    # Bags under the eyes.
    bags = np.exp(-(((ax - 0.035) / 0.014) ** 2 + ((p[..., 2] - 1.683) / 0.007) ** 2 + ((p[..., 1] + 0.072) / 0.02) ** 2))
    out *= (1.0 - grit["bags"] * 0.25 * bags)[..., None]

    # Lines across the brow.
    brow = smoothstep(1.735, 1.745, p[..., 2]) * smoothstep(1.785, 1.772, p[..., 2]) * (n[..., 1] < -0.3)
    out *= (1.0 - grit["lines"] * 0.12 * brow * (np.sin(p[..., 2] * np.pi / 0.006) > 0.6))[..., None]

    # Duller eyes: the whites of the eyes greyed.
    eyes = np.exp(-(((ax - 0.035) / 0.016) ** 2 + ((p[..., 2] - 1.699) / 0.01) ** 2)) * (n[..., 1] < -0.3)
    bright = (albedo @ LUMA) > 0.35
    out *= (1.0 - 0.3 * eyes * bright)[..., None]

    # A scar down his left cheek: a pale seam.
    if grit.get("scar") == "left_cheek":
        a, b = np.array([0.054, -0.068, 1.668]), np.array([0.036, -0.082, 1.632])
        t = np.clip(((p - a) @ (b - a)) / ((b - a) @ (b - a)), 0.0, 1.0)
        distance = np.linalg.norm(p - (a + t[..., None] * (b - a)), axis=-1)
        scar = np.clip(1.0 - distance / 0.0022, 0.0, 1.0) * (p[..., 0] > 0)
        out = out * (1.0 - scar[..., None]) + (out * np.array([1.25, 1.1, 1.08])) * scar[..., None]

    return out


if __name__ == "__main__":
    main()
