#!/usr/bin/env python3
"""Turns the bought textures.com photos into PS2 textures.

    python3 tools/textures/ps2ify.py import [folder]    TCom_* files -> textures/source/
    python3 tools/textures/ps2ify.py build [name ...]   recipes -> textures/ps2/<name>.png

Each texture has a small recipe in tools/textures/recipes/<name>.json: which
photo, what size, how many colours, a crop, a tint and so on (see RECIPE).
"alpha" is "none", "threshold" (the photo's own mask, cut at "threshold") or
"luma" (no mask: what is darker than "threshold" is cut out, as the gaps
between leaves); "mask" names a second file whose light is kept and dark cut
out (a photo's own alpha map, or "painted/<name>.png", one of ours); "ao" a
second file multiplied into the colour (an AO or height map: the gaps
between roof tiles). "seamless" makes a photo that does not tile tile both
ways (shifted half its size and cross-faded over its old edges); "seams"
[every px, px wide, how dark] darkens columns (a sail's seams).
The photo is cropped, shrunk by averaging (never sharpened), graded, and cut
down to its own palette WITHOUT dithering: the Retro screen dithers the
whole frame, and dithering twice turns into noise at 128 px.

textures/source/ and textures/ps2/ are gitignored. The repository is public
and textures.com's licence forbids passing their photos on, even edited, so
only the recipes are committed; Materials.gd falls back to flat colours
where a converted texture is missing.

Needs Pillow and numpy.
"""

import json
import shutil
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageEnhance

ROOT = Path(__file__).resolve().parents[2]
RECIPES = Path(__file__).resolve().parent / "recipes"
SOURCE = ROOT / "textures" / "source"
OUT = ROOT / "textures" / "ps2"
PAINTED = ROOT / "textures" / "painted"
DOWNLOADS = Path.home() / "Downloads"

# Every key a recipe may give, and what it is when left out.
RECIPE = {
    "source": None,
    "size": [128, 128],
    "colours": 32,
    "crop": None,
    "tint": [1.0, 1.0, 1.0],
    "contrast": 1.0,
    "brightness": 1.0,
    "desaturate": 0.0,
    "grime": 0.0,
    "ao": None,
    "alpha": "none",
    "threshold": 128,
    "key": None,
    "mask": None,
    "seams": None,
    "seamless": False,
}


def load_recipe(path):
    recipe = dict(RECIPE)
    recipe.update(json.loads(Path(path).read_text()))

    if not recipe["source"]:
        raise ValueError("%s names no source photo" % path)

    return recipe


def _eight_bit(image):
    """Any photo as 8-bit RGBA: 16-bit TIFFs are scaled down, not clipped."""
    if image.mode in ("I;16", "I;16B", "I;16L", "I"):
        deep = np.asarray(image, dtype=np.float64)
        peak = 65535.0 if image.mode.startswith("I;16") else max(float(deep.max()), 1.0)
        grey = np.clip(deep / peak * 255.0, 0, 255).astype(np.uint8)
        return Image.fromarray(grey, "L").convert("RGBA")

    return image.convert("RGBA")


def _grime(size, strength, seed=7):
    """Dark blotches the size of a few texels: 8 px cells, smoothed up, and
    wrapping round the tile (its left edge runs on into its right, its top
    into its bottom: a wall it tiles shows no seam)."""
    width, height = size
    rng = np.random.default_rng(seed)
    ny, nx = max(height // 8, 1), max(width // 8, 1)
    cells = rng.random((ny, nx))
    u = (np.arange(width) + 0.5) / width * nx - 0.5
    v = (np.arange(height) + 0.5) / height * ny - 0.5
    i0, j0 = np.floor(u).astype(int), np.floor(v).astype(int)
    fu, fv = (u - i0)[None, :], (v - j0)[:, None]
    i0, j0 = i0 % nx, j0 % ny
    i1, j1 = (i0 + 1) % nx, (j0 + 1) % ny
    top = cells[j0][:, i0] * (1.0 - fu) + cells[j0][:, i1] * fu
    bottom = cells[j1][:, i0] * (1.0 - fu) + cells[j1][:, i1] * fu
    blotch = top * (1.0 - fv) + bottom * fv
    return 1.0 - strength * (1.0 - blotch)


def _seamless(image):
    """`image` made to tile: a copy shifted half its size either way (its
    old edges now in the middle, its new ones meeting as the photo did in
    its middle) shows at the edges, the photo itself in the middle, a
    smooth window between."""
    pixels = np.asarray(image, dtype=np.float64)
    height, width = pixels.shape[:2]
    shifted = np.roll(np.roll(pixels, width // 2, axis=1), height // 2, axis=0)
    wx = np.sin(np.linspace(0.0, np.pi, width)) ** 0.5
    wy = np.sin(np.linspace(0.0, np.pi, height)) ** 0.5
    window = (wy[:, None] * wx[None, :])[:, :, None]
    blended = pixels * window + shifted * (1.0 - window)
    return Image.fromarray(np.clip(blended, 0, 255).astype(np.uint8), image.mode)


def convert(image, recipe):
    """One photo made a PS2 texture, as the recipe says. Pure: reads and writes no files."""
    recipe = {**RECIPE, **recipe}
    image = _eight_bit(image)

    if recipe["crop"]:
        x, y, w, h = recipe["crop"]
        width, height = image.size
        image = image.crop((round(x * width), round(y * height), round((x + w) * width), round((y + h) * height)))

    if recipe["seamless"]:
        image = _seamless(image)

    size = tuple(int(v) for v in recipe["size"])
    image = image.resize(size, Image.Resampling.BOX)
    alpha = image.getchannel("A")
    rgb = image.convert("RGB")

    if recipe["desaturate"]:
        rgb = ImageEnhance.Color(rgb).enhance(1.0 - float(recipe["desaturate"]))

    if recipe["brightness"] != 1.0:
        rgb = ImageEnhance.Brightness(rgb).enhance(float(recipe["brightness"]))

    if recipe["contrast"] != 1.0:
        rgb = ImageEnhance.Contrast(rgb).enhance(float(recipe["contrast"]))

    pixels = np.asarray(rgb, dtype=np.float64) * np.asarray(recipe["tint"], dtype=np.float64)

    if recipe.get("_ao") is not None:
        ao = np.asarray(recipe["_ao"].convert("L").resize(size, Image.Resampling.BOX), dtype=np.float64) / 255.0
        pixels *= ao[:, :, None]

    if recipe["grime"]:
        pixels *= _grime(size, float(recipe["grime"]))[:, :, None]

    if recipe["seams"]:
        period, wide, dark = recipe["seams"]
        columns = (np.arange(size[0]) % int(period)) < int(wide)
        pixels[:, columns] *= float(dark)

    rgb = Image.fromarray(np.clip(pixels, 0, 255).astype(np.uint8), "RGB")

    if recipe["key"]:
        r, g, b, tolerance = recipe["key"]
        distance = np.abs(np.asarray(rgb, dtype=np.int32) - np.array([r, g, b])).max(axis=2)
        keyed = np.asarray(alpha, dtype=np.uint8).copy()
        keyed[distance <= tolerance] = 0
        alpha = Image.fromarray(keyed, "L")

    palette = rgb.quantize(colors=int(recipe["colours"]), dither=Image.Dither.NONE).convert("RGB")
    out = palette.convert("RGBA")

    if recipe.get("_mask") is not None:
        cut = int(recipe["threshold"])
        mask = _eight_bit(recipe["_mask"]).convert("L").resize(size, Image.Resampling.BOX)
        out.putalpha(mask.point(lambda v: 255 if v >= cut else 0))
    elif recipe["alpha"] == "threshold":
        cut = int(recipe["threshold"])
        alpha = alpha.point(lambda a: 255 if a >= cut else 0)
        out.putalpha(alpha)
    elif recipe["alpha"] == "luma":
        # No mask in the photo: what is darker than the threshold (the gaps
        # between leaves) is cut out.
        cut = int(recipe["threshold"])
        out.putalpha(rgb.convert("L").point(lambda v: 255 if v >= cut else 0))
    elif recipe["key"]:
        out.putalpha(alpha)
    else:
        return palette

    return out


def build(name, source_dir=SOURCE, out_dir=OUT, recipes_dir=RECIPES):
    """textures/ps2/<name>.png from its recipe and photo; the path written."""
    recipe = load_recipe(Path(recipes_dir) / (name + ".json"))
    source = Path(source_dir) / recipe["source"]

    if not source.exists():
        raise FileNotFoundError("%s: its photo %s is not in %s (run 'ps2ify.py import')" % (name, recipe["source"], source_dir))

    if recipe["ao"]:
        ao = Path(source_dir) / recipe["ao"]

        if not ao.exists():
            raise FileNotFoundError("%s: its AO map %s is not in %s" % (name, recipe["ao"], source_dir))

        recipe["_ao"] = Image.open(ao)

    if recipe["mask"]:
        mask = (PAINTED / recipe["mask"][len("painted/"):]) if recipe["mask"].startswith("painted/") else Path(source_dir) / recipe["mask"]

        if not mask.exists():
            raise FileNotFoundError("%s: its mask %s is not there (%s)" % (name, recipe["mask"], mask))

        recipe["_mask"] = Image.open(mask)

    out = Path(out_dir) / (name + ".png")
    out.parent.mkdir(parents=True, exist_ok=True)
    convert(Image.open(source), recipe).save(out)
    return out


def import_photos(folder=DOWNLOADS, source_dir=SOURCE):
    source_dir.mkdir(parents=True, exist_ok=True)
    copied = 0

    for photo in sorted(Path(folder).glob("TCom_*")):
        if photo.is_file():
            shutil.copy2(photo, source_dir / photo.name)
            copied += 1

    print("copied %d photo(s) into %s" % (copied, source_dir))


def main(argv):
    verb = argv[0] if argv else ""

    if verb == "import":
        import_photos(Path(argv[1]).expanduser() if len(argv) > 1 else DOWNLOADS)
        return 0

    if verb == "build":
        names = argv[1:] or sorted(p.stem for p in RECIPES.glob("*.json"))
        failed = []

        for name in names:
            try:
                print("%-14s -> %s" % (name, build(name).relative_to(ROOT)))
            except Exception as error:  # noqa: BLE001 - every failure is reported by name
                print("%-14s FAILED: %s" % (name, error))
                failed.append(name)

        if failed:
            print("failed: %s" % ", ".join(failed))
            return 1

        return 0

    print(__doc__)
    return 1


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
