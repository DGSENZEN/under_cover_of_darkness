#!/usr/bin/env python3
"""Turns the bought textures.com photos into PS2 textures.

    python3 tools/textures/ps2ify.py import [folder]    TCom_* files -> textures/source/
    python3 tools/textures/ps2ify.py build [name ...]   recipes -> textures/ps2/<name>.png

Each texture has a small recipe in tools/textures/recipes/<name>.json: which
photo, what size, how many colours, a crop, a tint and so on (see RECIPE).
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
    """Dark blotches the size of a few texels: 8 px cells, smoothed up."""
    width, height = size
    rng = np.random.default_rng(seed)
    cells = rng.random((max(height // 8, 1) + 1, max(width // 8, 1) + 1))
    blotch = Image.fromarray((cells * 255).astype(np.uint8), "L").resize((width, height), Image.Resampling.BILINEAR)
    return 1.0 - strength * (1.0 - np.asarray(blotch, dtype=np.float64) / 255.0)


def convert(image, recipe):
    """One photo made a PS2 texture, as the recipe says. Pure: reads and writes no files."""
    recipe = {**RECIPE, **recipe}
    image = _eight_bit(image)

    if recipe["crop"]:
        x, y, w, h = recipe["crop"]
        width, height = image.size
        image = image.crop((round(x * width), round(y * height), round((x + w) * width), round((y + h) * height)))

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

    rgb = Image.fromarray(np.clip(pixels, 0, 255).astype(np.uint8), "RGB")

    if recipe["key"]:
        r, g, b, tolerance = recipe["key"]
        distance = np.abs(np.asarray(rgb, dtype=np.int32) - np.array([r, g, b])).max(axis=2)
        keyed = np.asarray(alpha, dtype=np.uint8).copy()
        keyed[distance <= tolerance] = 0
        alpha = Image.fromarray(keyed, "L")

    palette = rgb.quantize(colors=int(recipe["colours"]), dither=Image.Dither.NONE).convert("RGB")
    out = palette.convert("RGBA")

    if recipe["alpha"] == "threshold":
        cut = int(recipe["threshold"])
        alpha = alpha.point(lambda a: 255 if a >= cut else 0)
        out.putalpha(alpha)
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
