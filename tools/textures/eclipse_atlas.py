#!/usr/bin/env python3
"""The style lab's painted atlases and their painted normal maps: each
piece's atlas painted from what its Blender script baked
(assets/eclipse/source/<piece>_texels.npz: for every texel its slot, world
position, normal and the world directions of +U and +V; _ao.png: how open)
and a recipe per slot (tools/textures/recipes/eclipse/<slot>.json).

Light and wear are painted in, as the painterly look wants: a base mottled
toward its light and dark in brush dabs that stand upright in the world
(whichever way the island was packed), rims worn pale, grime and damp rising
from the street, the occlusion laid over. Beside the colour a relief is
painted (pores, mortar joints and tile grout laid along the world's courses,
the dabs' impasto, softened rims) and turned into a tangent-space normal
map (+U right, +V up, the OpenGL convention Godot reads).

    python3 tools/textures/eclipse_atlas.py kiosk arcade_bay
        -> textures/painted/eclipse/<piece>_base.png, <piece>_normal_base.png

It writes only the _base files. <piece>.png and <piece>_normal.png are the
user's overpaint, which the game takes first; this never touches them.

Drawn at four times the atlas, shrunk by averaging; the colour cut to 64
colours without dithering, as paint.py does. Needs Pillow and numpy.

A recipe: {"base", "light", "dark": "#rrggbb", "grime", "wear": 0-1,
"mottle": dabs per 64 texels, "band": {"colour", "from", "to" (m)},
"relief": {"pores": pits per 64 texels, "brush": impasto 0-1,
"bevel": rim softening 0-1, "blocks": {"course", "length", "joint" (m),
"colour", "stagger": bool, "irregular": bool, "tone": 0-1}},
"scan": {"name": a scan in textures/scans, "tint": 0-1 toward the slot's
colours, "contrast": the scan's light and dark, 1 as photographed}}.
"""

import json
import math
import sys
import zlib
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "assets" / "eclipse" / "source"
OUT = ROOT / "textures" / "painted" / "eclipse"
RECIPES = Path(__file__).resolve().parent / "recipes" / "eclipse"
# The CC0 photo scans (fetch_scans.py).
SCANS = ROOT / "textures" / "scans"
SCALE = 4
COLOURS = 64
# Damp and dirt reach this high above the street (m).
DAMP = 1.2
# How dark the worst grime and the deepest occlusion go.
GRIME_DARK = 0.45
AO_FLOOR = 0.35
EMPTY = (128, 128, 128)
# How steep the relief's slopes come out in the normal map.
STEEPNESS = 2.5
UP = np.array([0.0, 0.0, 1.0])
NORTH = np.array([0.0, 1.0, 0.0])


def _rgb(colour):
    return np.array([int(colour[i:i + 2], 16) for i in (1, 3, 5)], dtype=np.float64)


def load_recipes(slots):
    return {s: json.loads((RECIPES / (s + ".json")).read_text()) for s in slots if (RECIPES / (s + ".json")).exists()}


def _grey(path, px):
    image = Image.open(path).convert("L")

    if image.size != (px, px):
        image = image.resize((px, px), Image.Resampling.BILINEAR)

    return np.asarray(image, dtype=np.float64) / 255.0


def _up(values, big, smooth=False):
    """A float map at the atlas's size brought up to the drawing's."""
    image = Image.fromarray(values.astype(np.float32), "F")
    image = image.resize((big, big), Image.Resampling.BILINEAR if smooth else Image.Resampling.NEAREST)
    return np.asarray(image, dtype=np.float64)


def _noise(big, rng, cells=12):
    """Soft value noise, 0-1."""
    small = Image.fromarray((rng.random((cells, cells)) * 255).astype(np.uint8), "L")
    return np.asarray(small.resize((big, big), Image.Resampling.BICUBIC), dtype=np.float64) / 255.0


def _shrink(mask):
    out = mask.copy()

    for dy, dx in ((0, 1), (0, -1), (1, 0), (-1, 0)):
        out &= np.roll(mask, (dy, dx), axis=(0, 1))

    return out


def _rim(mask, width=2):
    """0 deep inside a region, rising to 1 at its border, over `width` texels."""
    out = np.zeros(mask.shape)
    inner = mask

    for k in range(width):
        shrunk = _shrink(inner)
        out[inner & ~shrunk] = 1.0 - k / width
        inner = shrunk

    return out


def _upright(texels):
    """For every texel, the image-space direction (x right, y down) in which
    the world's up runs across it; north on floors and ceilings."""
    tu, tv, normal = texels["tangent_u"], texels["tangent_v"], texels["normal"]
    flat = np.abs(normal[..., 2]) > 0.7
    ref = np.where(flat[..., None], NORTH, UP)
    du = (tu * ref).sum(-1)
    dv = (tv * ref).sum(-1)
    return np.arctan2(-dv, du)          # image y runs down, V up


def _dab(draw, x, y, length, width, angle, fill):
    """An ellipse `length` along `angle` (radians, image space), `width` across."""
    c, s = math.cos(angle), math.sin(angle)
    pts = []

    for k in range(12):
        t = 2 * math.pi * k / 12
        a, b = math.cos(t) * length / 2, math.sin(t) * width / 2
        pts.append((x + a * c - b * s, y + a * s + b * c))

    draw.polygon(pts, fill=fill)


def _dabs(mask_big, count, rng, big, angle, length=(6, 14), width=(2, 5), soft=0.8):
    """A soft mask of `count` brush dabs laid where the region is, each along
    the world's up at its spot."""
    layer = Image.new("L", (big, big), 0)
    draw = ImageDraw.Draw(layer)
    ys, xs = np.nonzero(mask_big)

    if len(xs) == 0 or count <= 0:
        return np.zeros((big, big))

    for k in rng.integers(0, len(xs), size=count):
        x, y = xs[k], ys[k]
        _dab(draw, x, y, rng.uniform(*length) * SCALE, rng.uniform(*width) * SCALE,
             angle[y // SCALE, x // SCALE] + rng.normal(0, 0.12), int(rng.uniform(90, 200)))

    return np.asarray(layer.filter(ImageFilter.GaussianBlur(SCALE * soft)), dtype=np.float64) / 255.0


def _hash(*keys):
    """0-1 per integer key, the same every run."""
    h = np.zeros(np.broadcast(*keys).shape, dtype=np.uint64)

    for k in keys:
        h = (h ^ (np.asarray(k).astype(np.int64).astype(np.uint64) + np.uint64(0x9E3779B9))) * np.uint64(0x85EBCA6B)
        h ^= h >> np.uint64(13)

    return (h % np.uint64(10007)).astype(np.float64) / 10007.0


def _frame(texels):
    """Each texel's world frame for laying a material on it: B runs up the
    wall (north on floors and ceilings), A across it, N out of it, with
    A x B = N; and its coordinates (a, b) in metres along A and B."""
    position, normal = texels["position"].astype(np.float64), texels["normal"].astype(np.float64)
    flat = np.abs(normal[..., 2]) > 0.7
    b_axis = np.where(flat[..., None], NORTH, UP)
    a_axis = np.cross(b_axis, normal)
    a_axis /= np.maximum(np.linalg.norm(a_axis, axis=-1, keepdims=True), 1e-6)
    b_axis = np.cross(normal, a_axis)
    return a_axis, b_axis, normal, (position * a_axis).sum(-1), (position * b_axis).sum(-1)


def _sample(image, u, v):
    """An image (rows from the top) sampled bilinearly and wrapped at (u, v),
    v up."""
    h, w = image.shape[:2]
    x = (u % 1.0) * w - 0.5
    y = (1.0 - (v % 1.0)) * h - 0.5
    x0, y0 = np.floor(x).astype(int), np.floor(y).astype(int)
    fx, fy = (x - x0)[..., None], (y - y0)[..., None]
    x0, y0 = x0 % w, y0 % h
    x1, y1 = (x0 + 1) % w, (y0 + 1) % h
    top = image[y0, x0] * (1 - fx) + image[y0, x1] * fx
    bottom = image[y1, x0] * (1 - fx) + image[y1, x1] * fx
    return top * (1 - fy) + bottom * fy


def _scan(scans_dir, name):
    folder = Path(scans_dir) / name
    info = json.loads((folder / "info.json").read_text())
    size = np.array(info.get("dimensions_mm") or [1000, 1000], dtype=np.float64)[:2] / 1000.0
    colour = np.asarray(Image.open(folder / "diffuse.jpg").convert("RGB"), dtype=np.float64)
    normal = np.asarray(Image.open(folder / "normal.jpg").convert("RGB"), dtype=np.float64) / 255.0 * 2 - 1
    return colour, normal, size


def _project(texels, big, scan, tu, tv):
    """A scan laid on the texels by world position: its colour, and its
    normals turned into each island's own UV frame (x along +U, y along +V)."""
    colour, normal, size = scan
    a_axis, b_axis, n_axis, a, b = _frame(texels)
    up = lambda m: _up(m, big, smooth=True)
    u, v = up(a) / size[0], up(b) / size[1]
    painted = _sample(colour, u, v)
    n = _sample(normal, u, v)
    near = lambda m: np.dstack([_up(m[..., k], big) for k in range(3)])
    world = n[..., 0:1] * near(a_axis) + n[..., 1:2] * near(b_axis) + n[..., 2:3] * near(n_axis)
    framed = np.dstack([(world * near(tu)).sum(-1), (world * near(tv)).sum(-1), (world * near(n_axis)).sum(-1)])
    framed /= np.maximum(np.linalg.norm(framed, axis=-1, keepdims=True), 1e-6)
    return painted, framed


def _courses(texels, blocks, big, rng):
    """How much of a mortar joint lies on each texel (0-1), and each stone's
    own tone (-1..1): horizontal joints every `course` of world height,
    vertical ones every `length` along the wall, staggered course by course;
    on floors, a grid in x and y. Irregular stones (tezontle) vary in length
    course by course, and their joints wander a little."""
    a, b = _frame(texels)[3:]
    a, b = _up(a, big, smooth=True), _up(b, big, smooth=True)
    course, length, joint = blocks["course"], blocks["length"], blocks["joint"]
    irregular = blocks.get("irregular", False)

    if irregular:   # joints that wander, as rough-squared stone sets
        b = b + (_noise(big, rng, 40) - 0.5) * joint
        a = a + (_noise(big, rng, 40) - 0.5) * joint

    row = np.floor(b / course)
    near_b = np.abs(b / course - np.round(b / course)) * course

    if irregular:
        stretch = 0.7 + 0.6 * _hash(row, 1)
        shifted = a / (length * stretch) + _hash(row, 2)
    else:
        stretch = 1.0
        shifted = a / length + (row % 2) * (0.5 if blocks.get("stagger", True) else 0.0)

    near_a = np.abs(shifted - np.round(shifted)) * length * stretch
    lines = np.clip(1.0 - np.minimum(near_a, near_b) / (joint / 2), 0.0, 1.0)
    tone = (_hash(row, np.floor(shifted), 3) * 2 - 1) if irregular else np.zeros_like(a)
    return np.clip(lines * 2.0, 0.0, 1.0), tone


def _normals(height, px, base=None):
    """The relief's tangent-space normals, folded over `base` (the scans'
    normals, x along +U, y along +V) if given, at the atlas's size, 0-255."""
    gy, gx = np.gradient(height)                 # per drawn texel; rows run down
    n = np.dstack([-gx * STEEPNESS, gy * STEEPNESS, np.ones_like(height)])
    n /= np.linalg.norm(n, axis=-1, keepdims=True)

    if base is not None:   # whiteout blend: the slopes add, the depths multiply
        n = np.dstack([n[..., 0] + base[..., 0], n[..., 1] + base[..., 1], n[..., 2] * base[..., 2]])
        n /= np.maximum(np.linalg.norm(n, axis=-1, keepdims=True), 1e-6)

    image = Image.fromarray(((n * 0.5 + 0.5) * 255).round().astype(np.uint8), "RGB")
    small = np.asarray(image.resize((px, px), Image.Resampling.BOX), dtype=np.float64) / 255.0 * 2 - 1
    small /= np.maximum(np.linalg.norm(small, axis=-1, keepdims=True), 1e-6)
    return ((small * 0.5 + 0.5) * 255).round().astype(np.uint8)


def paint_atlas(piece, source_dir=SOURCE, out_dir=OUT, recipes=None, scans_dir=SCANS):
    """The piece's atlas painted to out_dir/<piece>_base.png and its normal
    map to <piece>_normal_base.png; the atlas's path."""
    source_dir, out_dir = Path(source_dir), Path(out_dir)
    meta = json.loads((source_dir / (piece + "_regions.json")).read_text())
    slots, px = meta["slots"], meta["atlas_px"]
    recipes = recipes or load_recipes(slots)
    rng = np.random.default_rng(zlib.crc32(piece.encode()))
    big = px * SCALE

    with np.load(source_dir / (piece + "_texels.npz")) as data:
        texels = {k: data[k] for k in data.files}

    index = texels["slot"].astype(np.int32)
    filled = index >= 0
    ao = _grey(source_dir / (piece + "_ao.png"), px)
    height = texels["position"][..., 2].astype(np.float64)
    angle = _upright(texels)

    canvas = np.zeros((big, big, 3))
    relief = np.zeros((big, big))
    scan_normals = np.dstack([np.zeros((big, big)), np.zeros((big, big)), np.ones((big, big))])
    scans = {}
    grime = np.zeros((big, big))
    damp = _up(np.clip(1.0 - height / DAMP, 0.0, 1.0), big, smooth=True)
    height_big = _up(height, big, smooth=True)
    stain = 0.6 + 0.4 * _noise(big, rng)

    for i, slot_name in enumerate(slots):
        mask = index == i

        if not mask.any() or slot_name not in recipes:
            continue

        recipe = recipes[slot_name]
        shape = recipe.get("relief", {})
        mask_big = _up(mask.astype(np.float64), big) > 0.5
        base, light, dark = _rgb(recipe["base"]), _rgb(recipe["light"]), _rgb(recipe["dark"])
        base_map = np.broadcast_to(base, (big, big, 3)).copy()

        if "band" in recipe:   # a stripe at a world height (the Metro's line-colour band)
            band = recipe["band"]
            base_map[(height_big >= band["from"]) & (height_big <= band["to"])] = _rgb(band["colour"])

        if "scan" in recipe:   # the photo under the paint: its detail, pulled toward the slot's colours
            spec = recipe["scan"]

            if spec["name"] not in scans:
                scans[spec["name"]] = _project(texels, big, _scan(scans_dir, spec["name"]),
                                               texels["tangent_u"], texels["tangent_v"])

            photo, photo_normals = scans[spec["name"]]
            luma = photo @ np.array([0.299, 0.587, 0.114])
            mean = max(float(luma[mask_big].mean()), 1.0)
            relative = (luma / mean) ** spec.get("contrast", 1.0)
            tint = spec.get("tint", 0.8)
            base_map = photo * (1 - tint) + base_map * relative[..., None] * tint
            scan_normals[mask_big] = photo_normals[mask_big]

        area = mask.sum()
        count = int(recipe.get("mottle", 4) * area / 64)
        lit = _dabs(mask_big, count, rng, big, angle) * 0.6
        shade = _dabs(mask_big, count, rng, big, angle) * 0.6
        colour = base_map * (1 - lit - shade)[..., None] + light * lit[..., None] + dark * shade[..., None]
        rim = _up(_rim(mask), big, smooth=True)
        worn = rim * recipe.get("wear", 0.0) * 0.6
        colour = colour * (1 - worn[..., None]) + light * worn[..., None]
        bump = shape.get("brush", 0.0) * (lit - shade) - shape.get("bevel", 0.0) * rim ** 2

        if shape.get("pores", 0):
            pits = _dabs(mask_big, int(shape["pores"] * area / 64), rng, big, angle, (0.6, 1.4), (0.5, 1.1), 0.35)
            bump -= pits * 0.9
            colour = colour * (1 - 0.35 * pits[..., None]) + dark * 0.35 * pits[..., None]

        if "blocks" in shape:
            joints, tone = _courses(texels, shape["blocks"], big, rng)
            bump -= joints
            # Each stone a shade of its own, toward the light or the dark.
            toward = np.where(tone[..., None] > 0, light, dark)
            k = np.abs(tone)[..., None] * shape["blocks"].get("tone", 0.0)
            colour = colour * (1 - k) + toward * k
            mortar = _rgb(shape["blocks"].get("colour", recipe["light"]))
            colour = colour * (1 - joints[..., None]) + mortar * joints[..., None]

        canvas[mask_big] = colour[mask_big]
        relief[mask_big] = bump[mask_big]
        grime[mask_big] = recipe.get("grime", 0.0)

    canvas *= (1.0 - GRIME_DARK * grime * damp * stain)[..., None]
    canvas *= (AO_FLOOR + (1.0 - AO_FLOOR) * _up(ao, big, smooth=True))[..., None]
    empty = ~(_up(filled.astype(np.float64), big) > 0.5)
    canvas[empty] = EMPTY
    relief[empty] = 0.0

    out_dir.mkdir(parents=True, exist_ok=True)
    image = Image.fromarray(np.clip(canvas, 0, 255).astype(np.uint8), "RGB")
    small = image.resize((px, px), Image.Resampling.BOX)
    path = out_dir / (piece + "_base.png")
    small.quantize(colors=COLOURS, dither=Image.Dither.NONE).convert("RGB").save(path)
    Image.fromarray(_normals(relief, px, scan_normals), "RGB").save(out_dir / (piece + "_normal_base.png"))
    return path


def main(argv):
    for piece in argv or ["kiosk", "arcade_bay"]:
        print("eclipse_atlas:", paint_atlas(piece))


if __name__ == "__main__":
    main(sys.argv[1:])
