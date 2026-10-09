#!/usr/bin/env python3
"""The style lab's painted atlases: each piece's atlas painted from the maps
its Blender script baked (assets/eclipse/source/<piece>_regions.png: which
slot is where; _ao.png: how open; _height.png: how high in the world) and a
recipe per slot (tools/textures/recipes/eclipse/<slot>.json). Light and wear
are painted in, as the painterly look wants: a base mottled toward its light
and dark, edges worn pale, grime and damp rising from the street, the
occlusion laid over.

    python3 tools/textures/eclipse_atlas.py kiosk arcade_bay
        -> textures/painted/eclipse/<piece>_base.png

It writes only <piece>_base.png. <piece>.png is the user's overpaint, which
the game takes first; this never touches it.

Drawn at four times the atlas, shrunk by averaging and cut to 64 colours
without dithering, as paint.py does. Needs Pillow and numpy.
"""

import json
import sys
import zlib
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "assets" / "eclipse" / "source"
OUT = ROOT / "textures" / "painted" / "eclipse"
RECIPES = Path(__file__).resolve().parent / "recipes" / "eclipse"
SCALE = 4
COLOURS = 64
# Damp and dirt reach this high above the street (m).
DAMP = 1.2
# How dark the worst grime and the deepest occlusion go.
GRIME_DARK = 0.45
AO_FLOOR = 0.35
EMPTY = (128, 128, 128)


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
    """A map at the atlas's size brought up to the drawing's."""
    image = Image.fromarray((np.clip(values, 0, 1) * 255).astype(np.uint8), "L")
    image = image.resize((big, big), Image.Resampling.BILINEAR if smooth else Image.Resampling.NEAREST)
    return np.asarray(image, dtype=np.float64) / 255.0


def _noise(big, rng, cells=12):
    """Soft value noise, 0-1."""
    small = Image.fromarray((rng.random((cells, cells)) * 255).astype(np.uint8), "L")
    return np.asarray(small.resize((big, big), Image.Resampling.BICUBIC), dtype=np.float64) / 255.0


def _edges(mask, width=2):
    """The texels within `width` of a region's border (an island's rim)."""
    inner = mask.copy()

    for _ in range(width):
        shrunk = inner.copy()

        for dy, dx in ((0, 1), (0, -1), (1, 0), (-1, 0)):
            shrunk &= np.roll(inner, (dy, dx), axis=(0, 1))

        inner = shrunk

    return mask & ~inner


def _dabs(mask_big, count, rng, big):
    """A soft mask of `count` upright brush dabs laid where the region is."""
    layer = Image.new("L", (big, big), 0)
    draw = ImageDraw.Draw(layer)
    ys, xs = np.nonzero(mask_big)

    if len(xs) == 0:
        return np.zeros((big, big))

    for k in rng.integers(0, len(xs), size=count):
        x, y = xs[k], ys[k]
        w, h = rng.uniform(2, 5) * SCALE, rng.uniform(6, 14) * SCALE
        draw.ellipse([x - w / 2, y - h / 2, x + w / 2, y + h / 2], fill=int(rng.uniform(90, 200)))

    return np.asarray(layer.filter(ImageFilter.GaussianBlur(SCALE * 0.8)), dtype=np.float64) / 255.0


def paint_atlas(piece, source_dir=SOURCE, out_dir=OUT, recipes=None):
    """The piece's atlas painted to out_dir/<piece>_base.png; its path."""
    source_dir, out_dir = Path(source_dir), Path(out_dir)
    meta = json.loads((source_dir / (piece + "_regions.json")).read_text())
    slots, px = meta["slots"], meta["atlas_px"]
    low, high = meta.get("height_range", [-4.0, 12.0])
    recipes = recipes or load_recipes(slots)
    rng = np.random.default_rng(zlib.crc32(piece.encode()))
    big = px * SCALE

    regions = np.asarray(Image.open(source_dir / (piece + "_regions.png")).convert("RGBA"))
    filled = regions[..., 3] > 0
    index = np.where(filled, (regions[..., 0].astype(np.int32) + 8) // 16, -1)
    ao = _grey(source_dir / (piece + "_ao.png"), px)
    height = low + _grey(source_dir / (piece + "_height.png"), px) * (high - low)

    canvas = np.zeros((big, big, 3))
    grime = np.zeros((big, big))
    damp = _up(np.clip(1.0 - height / DAMP, 0.0, 1.0), big, smooth=True)
    height_big = low + _up((height - low) / (high - low), big, smooth=True) * (high - low)
    stain = 0.6 + 0.4 * _noise(big, rng)

    for i, slot_name in enumerate(slots):
        mask = index == i

        if not mask.any() or slot_name not in recipes:
            continue

        recipe = recipes[slot_name]
        mask_big = _up(mask.astype(np.float64), big) > 0.5
        base, light, dark = _rgb(recipe["base"]), _rgb(recipe["light"]), _rgb(recipe["dark"])
        base_map = np.broadcast_to(base, (big, big, 3)).copy()

        if "band" in recipe:   # a stripe at a world height (the Metro's line-colour band)
            band = recipe["band"]
            within = (height_big >= band["from"]) & (height_big <= band["to"])
            base_map[within] = _rgb(band["colour"])

        area = mask.sum()
        count = int(recipe.get("mottle", 4) * area / 64)
        lit = _dabs(mask_big, count, rng, big) * 0.6 if count else np.zeros((big, big))
        shade = _dabs(mask_big, count, rng, big) * 0.6 if count else np.zeros((big, big))
        colour = base_map * (1 - lit - shade)[..., None] + light * lit[..., None] + dark * shade[..., None]
        worn = _up(_edges(mask).astype(np.float64), big, smooth=True) * recipe.get("wear", 0.0) * 0.6
        colour = colour * (1 - worn[..., None]) + light * worn[..., None]
        canvas[mask_big] = colour[mask_big]
        grime[mask_big] = recipe.get("grime", 0.0)

    canvas *= (1.0 - GRIME_DARK * grime * damp * stain)[..., None]
    canvas *= (AO_FLOOR + (1.0 - AO_FLOOR) * _up(ao, big, smooth=True))[..., None]
    empty = ~(_up(filled.astype(np.float64), big) > 0.5)
    canvas[empty] = EMPTY

    image = Image.fromarray(np.clip(canvas, 0, 255).astype(np.uint8), "RGB")
    small = image.resize((px, px), Image.Resampling.BOX)
    out = small.quantize(colors=COLOURS, dither=Image.Dither.NONE).convert("RGB")
    out_dir.mkdir(parents=True, exist_ok=True)
    path = out_dir / (piece + "_base.png")
    out.save(path)
    return path


def main(argv):
    for piece in argv or ["kiosk", "arcade_bay"]:
        print("eclipse_atlas:", paint_atlas(piece))


if __name__ == "__main__":
    main(sys.argv[1:])
