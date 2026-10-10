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

import kuwahara
import scan_prep

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
# The painterly brief (docs/superpowers/refs/mexico_city/painterly_texturing.md):
# values in a few bands, ramps that cool into shadow and warm into light, the
# scan's fine detail laid back over the bands, one light Kuwahara to fuse it
# all, then each slot cut to a few colours of its own (in Oklab, no dither).
BANDS = 5
COOL_HUE, COOL_TURN, COOL_PUSH = 264.0, 20.0, 0.025
WARM_HUE, WARM_TURN, WARM_PUSH = 80.0, 15.0, 0.015
DETAIL = 0.35
DETAIL_SIGMA = 6.0
FUSE_RADIUS = 2
FUSE_TILE = 512
SLOT_COLOURS = 10
# Brush strokes laid over the bands (per 64 atlas texels), at four times the
# atlas: long enough and wide enough to read as marks at 1x (2+ texels).
STROKES = 5
STROKE_LENGTH = (20, 44)
STROKE_WIDTH = (7, 12)
STROKE_RELIEF = 0.8
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
    colour, normal, size = scan       # scan_prep.prepare: colour 0-1, normals -1..1, metres
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


# Oklab (Björn Ottosson, 2020): lightness and two opponent axes, where equal
# steps look equal.

_M1 = np.array([[0.4122214708, 0.5363325363, 0.0514459929], [0.2119034982, 0.6806995451, 0.1073969566],
                [0.0883024619, 0.2817188376, 0.6299787005]])
_M2 = np.array([[0.2104542553, 0.7936177850, -0.0040720468], [1.9779984951, -2.4285922050, 0.4505937099],
                [0.0259040371, 0.7827717662, -0.8086757660]])


def to_oklab(rgb):
    """sRGB 0-1 to Oklab."""
    linear = np.where(rgb <= 0.04045, rgb / 12.92, ((np.clip(rgb, 0, None) + 0.055) / 1.055) ** 2.4)
    return np.cbrt(linear @ _M1.T) @ _M2.T


def from_oklab(lab):
    """Oklab to sRGB 0-1."""
    linear = np.clip((lab @ np.linalg.inv(_M2).T) ** 3 @ np.linalg.inv(_M1).T, 0.0, 1.0)
    return np.where(linear <= 0.0031308, linear * 12.92, 1.055 * linear ** (1 / 2.4) - 0.055)


def _turned(lab, hue, degrees, push):
    """Colours turned up to `degrees` toward a hue and nudged toward it by
    `push` of chroma (a grey takes the nudge; a colour takes both)."""
    a, b = lab[..., 1], lab[..., 2]
    own = np.arctan2(b, a)
    gap = (np.radians(hue) - own + np.pi) % (2 * np.pi) - np.pi
    turn = np.clip(gap, -np.radians(degrees), np.radians(degrees))
    c, s = np.cos(turn), np.sin(turn)
    out = lab.copy()
    out[..., 1] = a * c - b * s + push * math.cos(math.radians(hue))
    out[..., 2] = a * s + b * c + push * math.sin(math.radians(hue))
    return out


def _ramp(value, base_lab, dark_lab, light_lab):
    """A value (0 dark, 0.5 the base, 1 light) on the slot's ramp: dark to
    base to light in Oklab, the shadow end turned cool, the light end warm."""
    t = value[..., None]
    cool = _turned(dark_lab, COOL_HUE, COOL_TURN, COOL_PUSH)
    warm = _turned(light_lab, WARM_HUE, WARM_TURN, WARM_PUSH)
    below = cool + (base_lab - cool) * np.clip(t * 2, 0, 1)
    above = base_lab + (warm - base_lab) * np.clip(t * 2 - 1, 0, 1)
    return np.where(t < 0.5, below, above)


def _fuse(canvas):
    """One light anisotropic Kuwahara over the whole drawing, in tiles."""
    out = canvas.copy()
    reach = FUSE_RADIUS * 2 + 2
    h, w = canvas.shape[:2]

    for y in range(0, h, FUSE_TILE):
        for x in range(0, w, FUSE_TILE):
            ys = np.arange(y - reach, min(h, y + FUSE_TILE) + reach) % h
            xs = np.arange(x - reach, min(w, x + FUSE_TILE) + reach) % w
            tile = kuwahara.anisotropic(canvas[np.ix_(ys, xs)], FUSE_RADIUS)
            out[y:y + FUSE_TILE, x:x + FUSE_TILE] = tile[reach:reach + min(FUSE_TILE, h - y), reach:reach + min(FUSE_TILE, w - x)]

    return out


def _kmeans(lab, k, rounds=10):
    """`lab` (n x 3) cut to k colours: their centres, and each one's centre."""
    order = np.argsort(lab[:, 0], kind="stable")
    centres = lab[order[np.linspace(0, len(lab) - 1, k).astype(int)]].copy()

    for _ in range(rounds):
        nearest = np.argmin(((lab[:, None, :] - centres[None]) ** 2).sum(-1), axis=1)

        for j in range(k):
            if np.any(nearest == j):
                centres[j] = lab[nearest == j].mean(axis=0)

    return centres, np.argmin(((lab[:, None, :] - centres[None]) ** 2).sum(-1), axis=1)


def _strokes(colour, banded, mask, rng, count):
    """Brush strokes over a slot: gathered where its value bands meet, lying
    along the edges (the image's own structure), each dragging the paint of
    the band beside it; and the impasto they leave, a ridge along each one.
    Works on the slot's bounding box. Returns (colour, height 0-1)."""
    height = np.zeros(mask.shape)

    if count <= 0 or not mask.any():
        return colour, height

    ys, xs = np.nonzero(mask)
    pad = STROKE_LENGTH[1]
    y0, y1 = max(0, ys.min() - pad), min(mask.shape[0], ys.max() + pad + 1)
    x0, x1 = max(0, xs.min() - pad), min(mask.shape[1], xs.max() + pad + 1)
    box_mask = mask[y0:y1, x0:x1]
    box_value = banded[y0:y1, x0:x1]
    box_colour = colour[y0:y1, x0:x1]
    angle, _ = kuwahara.structure(box_value[..., None], sigma=4.0)
    gy, gx = np.gradient(box_value)
    edges = kuwahara.gaussian(np.hypot(gx, gy), 3.0)
    weight = np.where(box_mask, 0.25 + edges / max(float(edges.max()), 1e-9), 0.0).ravel()
    picks = rng.choice(weight.size, size=count, p=weight / weight.sum())
    h, w = box_mask.shape
    paint = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    ridge = Image.new("L", (w, h), 0)
    draw, raise_ = ImageDraw.Draw(paint), ImageDraw.Draw(ridge)

    for k in picks:
        y, x = divmod(int(k), w)
        along = float(angle[y, x])
        length = rng.uniform(*STROKE_LENGTH)
        width = rng.uniform(*STROKE_WIDTH)
        # The paint dragged in from across the edge, on one side or the other.
        side = width * 0.9 * (1 if rng.random() < 0.5 else -1)
        sy = int(np.clip(y + math.cos(along) * side, 0, h - 1))
        sx = int(np.clip(x - math.sin(along) * side, 0, w - 1))
        r, g, b = (int(c) for c in np.clip(box_colour[sy, sx], 0, 255))
        _dab(draw, x, y, length, width, along, (r, g, b, int(rng.uniform(150, 210))))
        _dab(raise_, x, y, length, width, along, 110)
        _dab(raise_, x, y, length * 0.85, width * 0.4, along, 255)

    layer = np.asarray(paint, dtype=np.float64)
    alpha = (layer[..., 3:4] / 255.0) * box_mask[..., None]
    out = colour.copy()
    out[y0:y1, x0:x1] = box_colour * (1 - alpha) + layer[..., :3] * alpha
    soft = np.asarray(ridge.filter(ImageFilter.GaussianBlur(1.5)), dtype=np.float64) / 255.0
    height[y0:y1, x0:x1] = soft * box_mask
    return out, height


def _despeckle(lab, cells, rounds=2):
    """A texel unlike all four of its neighbours (in its slot) takes the
    colour most of them share: marks are shapes, not grain."""
    for _ in range(rounds):
        changed = False
        neighbours = [np.roll(lab, (dy, dx), axis=(0, 1)) for dy, dx in ((0, 1), (0, -1), (1, 0), (-1, 0))]
        inside = [np.roll(cells, (dy, dx), axis=(0, 1)) for dy, dx in ((0, 1), (0, -1), (1, 0), (-1, 0))]
        same = [np.all(np.abs(n - lab) < 1e-9, axis=-1) | ~c for n, c in zip(neighbours, inside)]
        alone = cells & ~np.logical_or.reduce(same)

        for y, x in zip(*np.nonzero(alone)):
            seen = [tuple(np.round(n[y, x], 9)) for n, c in zip(neighbours, inside) if c[y, x]]

            if seen:
                lab[y, x] = max(set(seen), key=seen.count)
                changed = True

        if not changed:
            break

    return lab


# Named ways of painting, for comparing in the lab: each overrides some of the
# module's settings for one painting.
STYLES = {
    # Calmer surfaces: fewer value bands, less of the scan's grain, fewer
    # and bigger strokes, a broader fuse.
    "calm": {"BANDS": 4, "DETAIL": 0.12, "STROKES": 3, "STROKE_LENGTH": (32, 64), "STROKE_WIDTH": (11, 17),
             "FUSE_RADIUS": 3},
}


def paint_atlas(piece, source_dir=SOURCE, out_dir=OUT, recipes=None, scans_dir=SCANS, prep=None, style=None):
    """The piece's atlas painted to out_dir/<piece>_base.png and its normal
    map to <piece>_normal_base.png; the atlas's path. `prep` overrides the
    scans' preparation (scan_prep.prepare's settings); `style` (a dict, or
    the name of one of STYLES) overrides this module's settings for this
    painting only."""
    style = STYLES[style] if isinstance(style, str) else (style or {})
    kept = {k: globals()[k] for k in style}
    globals().update(style)

    try:
        return _paint(piece, source_dir, out_dir, recipes, scans_dir, prep)
    finally:
        globals().update(kept)


def _paint(piece, source_dir, out_dir, recipes, scans_dir, prep):
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
    ao = _up(_grey(source_dir / (piece + "_ao.png"), px), big, smooth=True)
    height = texels["position"][..., 2].astype(np.float64)
    angle = _upright(texels)
    wear_map = _up(texels.get("wear", np.zeros((px, px))).astype(np.float64), big, smooth=True)
    cavity = _up(texels.get("cavity", np.zeros((px, px))).astype(np.float64), big, smooth=True)
    damp = _up(np.clip(1.0 - height / DAMP, 0.0, 1.0), big, smooth=True)
    height_big = _up(height, big, smooth=True)
    stain = 0.6 + 0.4 * _noise(big, rng)
    # Wear tells its story in a few places: every convex edge a little, those a lot.
    story = 0.35 + 0.65 * np.clip((_noise(big, rng, 6) - 0.45) * 3.0, 0.0, 1.0)

    canvas = np.zeros((big, big, 3))
    relief = np.zeros((big, big))
    scan_normals = np.dstack([np.zeros((big, big)), np.zeros((big, big)), np.ones((big, big))])
    scans = {}

    for i, slot_name in enumerate(slots):
        mask = index == i

        if not mask.any() or slot_name not in recipes:
            continue

        recipe = recipes[slot_name]
        shape = recipe.get("relief", {})
        mask_big = _up(mask.astype(np.float64), big) > 0.5
        base_rgb = np.broadcast_to(_rgb(recipe["base"]) / 255.0, (big, big, 3)).copy()

        if "band" in recipe:   # a stripe at a world height (the Metro's line-colour band)
            band = recipe["band"]
            base_rgb[(height_big >= band["from"]) & (height_big <= band["to"])] = _rgb(band["colour"]) / 255.0

        base_lab = to_oklab(base_rgb)
        dark_lab = base_lab + (to_oklab(_rgb(recipe["dark"]) / 255.0) - to_oklab(_rgb(recipe["base"]) / 255.0))
        light_lab = base_lab + (to_oklab(_rgb(recipe["light"]) / 255.0) - to_oklab(_rgb(recipe["base"]) / 255.0))

        # The value: the scan's own light and dark round the slot's middle...
        value = np.full((big, big), 0.5)
        detail = np.zeros((big, big))
        photo = None

        if "scan" in recipe:
            spec = recipe["scan"]

            if spec["name"] not in scans:
                prepared = scan_prep.prepare(spec["name"], scans_dir, **(prep or {}))
                scans[spec["name"]] = _project(texels, big, prepared, texels["tangent_u"], texels["tangent_v"])

            photo, photo_normals = scans[spec["name"]]
            lightness = to_oklab(photo)[..., 0]
            mean, spread = lightness[mask_big].mean(), max(float(lightness[mask_big].std()), 1e-3)
            value = 0.5 + 0.18 * spec.get("contrast", 1.0) * (lightness - mean) / spread
            detail = (lightness - kuwahara.gaussian(lightness, DETAIL_SIGMA)) * spec.get("detail", DETAIL)
            scan_normals[mask_big] = photo_normals[mask_big]

        area = mask.sum()
        count = int(recipe.get("mottle", 0) * area / 64)

        if count:
            value += 0.15 * (_dabs(mask_big, count, rng, big, angle) - _dabs(mask_big, count, rng, big, angle))

        # ...shaded by what the place did to it: occlusion and cavities darken,
        # damp rises from the street, wear lifts the convex edges it reached.
        worn = wear_map * story * recipe.get("wear", 0.0)
        value = (value - 0.35 * (1.0 - ao) - 0.25 * cavity - 0.4 * recipe.get("grime", 0.0) * damp * stain
                 + 0.45 * worn)

        # Big shapes first: a few value bands, each a colour off the ramp.
        bands = min(recipe.get("bands", BANDS), BANDS)
        banded = (np.floor(np.clip(value, 0.0, 0.999) * bands) + 0.5) / bands
        lab = _ramp(banded, base_lab, dark_lab, light_lab)
        lab[..., 0] += detail
        colour = from_oklab(lab) * 255.0

        if photo is not None and recipe["scan"].get("tint", 1.0) < 1.0:   # the photograph itself, in part
            tint = recipe["scan"]["tint"]
            colour = colour * tint + photo * 255.0 * (1 - tint)

        # Strokes over the bands, and the ridges of paint they leave.
        count = int(recipe.get("strokes", STROKES) * area / 64)
        colour, ridges = _strokes(colour, banded, mask_big, rng, count)
        bump = (shape.get("brush", 0.0) * detail * 4.0 - shape.get("bevel", 0.0) * wear_map ** 2
                + recipe.get("stroke_relief", STROKE_RELIEF) * ridges)

        if shape.get("pores", 0):
            pits = _dabs(mask_big, int(shape["pores"] * area / 64), rng, big, angle, (0.6, 1.4), (0.5, 1.1), 0.35)
            bump -= pits * 0.9

        if "blocks" in shape:
            joints, tone = _courses(texels, shape["blocks"], big, rng)
            bump -= joints
            mortar = _rgb(shape["blocks"].get("colour", recipe["light"]))
            colour = colour * (1 - joints[..., None]) + mortar * joints[..., None]

        canvas[mask_big] = colour[mask_big]
        relief[mask_big] = bump[mask_big]

    empty = ~(_up(filled.astype(np.float64), big) > 0.5)
    canvas[empty] = EMPTY
    canvas = _fuse(canvas / 255.0) * 255.0
    canvas[empty] = EMPTY
    relief[empty] = 0.0

    # Shrunk to the atlas, then each slot cut to a few colours of its own.
    small = np.asarray(Image.fromarray(np.clip(canvas, 0, 255).astype(np.uint8), "RGB")
                       .resize((px, px), Image.Resampling.BOX), dtype=np.float64) / 255.0
    lab = to_oklab(small)

    for i in range(len(slots)):
        cells = index == i

        if cells.sum() > SLOT_COLOURS:
            centres, nearest = _kmeans(lab[cells], SLOT_COLOURS)
            lab[cells] = centres[nearest]
            lab = _despeckle(lab, cells)

    out = np.where(filled[..., None], from_oklab(lab), np.array(EMPTY) / 255.0)
    out_dir.mkdir(parents=True, exist_ok=True)
    path = out_dir / (piece + "_base.png")
    Image.fromarray(np.clip(np.round(out * 255), 0, 255).astype(np.uint8), "RGB").save(path)
    Image.fromarray(_normals(relief, px, scan_normals), "RGB").save(out_dir / (piece + "_normal_base.png"))
    return path


def main(argv):
    """Pieces to paint; --style=<name> one of STYLES, --out=<dir> elsewhere."""
    style = next((a.split("=", 1)[1] for a in argv if a.startswith("--style=")), None)
    out = next((Path(a.split("=", 1)[1]) for a in argv if a.startswith("--out=")), OUT)

    for piece in [a for a in argv if not a.startswith("--")] or ["kiosk", "arcade_bay"]:
        print("eclipse_atlas:", paint_atlas(piece, out_dir=out, style=style))


if __name__ == "__main__":
    main(sys.argv[1:])
