"""The layered painter: an atlas painted the way the new standard asks
(docs/superpowers/specs/2026-10-16-metro-underground-design.md, section 4),
in layers over each slot's texels:

  1. a flat colour field designed per material,
  2. a light falling from the top (up-facing lighter) and with height,
  3. bright worn edges (the bake's convexity) and dark grime in crevices
     (its cavity, where the occlusion is deep),
  4. brush-stroke breakup from the user's sheets, laid by world position,
  5. Mignola's solid black in the deepest recesses.

Beside eclipse_atlas.py (the Zócalo's scan painter), not instead of it. It
reads what tools/eclipse/common.export_piece wrote for a piece and writes
<out>/<piece>_base.png; a user overpaint <piece>.png still wins in game.

    python3 tools/textures/layered_atlas.py <piece> [--recipes=underground] [--out=dir]
"""

import json
import sys
from pathlib import Path

import numpy as np
from PIL import Image

import brushes as brush_sheets
from eclipse_atlas import _frame, _grey, _rgb, _sample, from_oklab, to_oklab

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "assets" / "eclipse" / "source"
OUT = ROOT / "textures" / "painted" / "underground"
RECIPES = Path(__file__).resolve().parent / "recipes"
# Slots drawn by their own materials in game (glass of every tint, the neon's tubes).
ATLAS_FREE = ("glass", "neon")
# How far each layer can move Oklab lightness at full strength.
TOP_LIGHT = 0.15
HEIGHT_LIGHT = 0.1
# Convexity from which an edge starts to wear, and over how much it is fully worn.
WEAR_FROM, WEAR_OVER = 0.2, 0.35
# The Mignola black, and how much lighter than it everything else stays.
BLACK = "#0b0a0c"
BLACK_GAP = 0.03
# Texels each painted region is grown by into the empty atlas, for mipmaps.
GROW = 4


def _lab(colour):
    return to_oklab(_rgb(colour) / 255.0)


def _mix(lab, target, weight):
    w = weight[..., None]
    return lab * (1 - w) + target * w


def paint_slot(texels, mask, ao, recipe, brushes):
    """One slot's texels painted (H x W x 3, sRGB 0-1; zero outside `mask`).
    `texels` as tools/eclipse/common.texels wrote them (row 0 the top), `ao`
    at the atlas's size (1 open), `brushes` the sheets by name."""
    h, w = mask.shape
    lab = np.broadcast_to(_lab(recipe["colour"]), (h, w, 3)).copy()
    normal = texels["normal"].astype(np.float64)
    occlusion = 1.0 - np.asarray(ao, np.float64)

    if recipe.get("light", 0.0):
        lab[..., 0] += recipe["light"] * TOP_LIGHT * normal[..., 2]

    if recipe.get("height_light", 0.0):
        z = texels["position"][..., 2].astype(np.float64)
        low, high = z[mask].min(), z[mask].max()
        lab[..., 0] += recipe["height_light"] * HEIGHT_LIGHT * ((z - low) / max(high - low, 1e-6) - 0.5)

    if recipe.get("wear", 0.0):
        worn = np.clip((texels["wear"] - WEAR_FROM) / WEAR_OVER, 0.0, 1.0) * recipe["wear"]
        lab = _mix(lab, _lab(recipe["wear_colour"]), worn)

    deep = texels["cavity"].astype(np.float64) * occlusion

    if recipe.get("grime", 0.0):
        lab = _mix(lab, _lab(recipe["grime_colour"]), np.clip(deep * recipe["grime"], 0.0, 1.0))

    if recipe.get("brush_amount", 0.0):
        _, _, _, a, b = _frame(texels)
        scale = recipe["brush_scale_m"]
        stroke = _sample(brushes[recipe["brush"]][..., None], a / scale, b / scale)[..., 0]
        lab[..., 0] += recipe["brush_amount"] * np.clip((stroke - 0.5) * 2.0, -1.0, 1.0)

    black = _lab(BLACK)

    if recipe.get("black", 0.0):
        recess = deep >= 1.0 - recipe["black"]
        lab[..., 0] = np.maximum(lab[..., 0], black[0] + BLACK_GAP)
        lab[recess] = black
    else:
        lab[..., 0] = np.maximum(lab[..., 0], black[0] + BLACK_GAP)

    rgb = np.clip(from_oklab(lab), 0.0, 1.0)

    if recipe.get("black", 0.0):
        rgb[recess] = _rgb(BLACK) / 255.0

    rgb[~mask] = 0.0
    return rgb


def _grow(rgb, filled, steps=GROW):
    """Painted colour spread into the empty texels round each region."""
    rgb, filled = rgb.copy(), filled.copy()

    for _ in range(steps):
        total = np.zeros_like(rgb)
        count = np.zeros(filled.shape)

        for dy, dx in ((0, 1), (0, -1), (1, 0), (-1, 0)):
            total += np.roll(rgb * filled[..., None], (dy, dx), axis=(0, 1))
            count += np.roll(filled, (dy, dx), axis=(0, 1))

        new = (~filled) & (count > 0)
        rgb[new] = total[new] / count[new][..., None]
        filled |= new

    return rgb


def paint(piece, source_dir=SOURCE, out_dir=OUT, recipes_dir=RECIPES / "underground", brushes_dir=brush_sheets.BRUSHES):
    """The piece's atlas painted from its recipes; returns the path written."""
    source_dir, out_dir, recipes_dir = Path(source_dir), Path(out_dir), Path(recipes_dir)
    meta = json.loads((source_dir / (piece + "_regions.json")).read_text())
    slots, px = meta["slots"], meta["atlas_px"]

    with np.load(source_dir / (piece + "_texels.npz")) as data:
        texels = {k: data[k] for k in data.files}

    recipes = {}

    for name in slots:
        if name in ATLAS_FREE or name.startswith("glass"):
            continue

        path = recipes_dir / (name + ".json")

        if not path.exists():
            sys.exit("no recipe for slot %s (%s)" % (name, path))

        recipes[name] = json.loads(path.read_text())

    sheets = {r["brush"]: brush_sheets.load(r["brush"], brushes_dir) for r in recipes.values() if r.get("brush")}
    ao = _grey(source_dir / (piece + "_ao.png"), px)
    index = texels["slot"].astype(np.int32)
    canvas = np.zeros((px, px, 3))

    for i, name in enumerate(slots):
        mask = index == i

        if name in recipes and mask.any():
            canvas[mask] = paint_slot(texels, mask, ao, recipes[name], sheets)[mask]

    painted = np.isin(index, [i for i, name in enumerate(slots) if name in recipes])
    canvas = _grow(canvas, painted)
    out_dir.mkdir(parents=True, exist_ok=True)
    path = out_dir / (piece + "_base.png")
    Image.fromarray((canvas * 255).round().astype(np.uint8), "RGB").save(path)
    return path


def _option(args, name, default):
    for a in args:
        if a.startswith("--%s=" % name):
            return a.split("=", 1)[1]
    return default


if __name__ == "__main__":
    args = sys.argv[1:]
    pieces = [a for a in args if not a.startswith("--")]

    if not pieces:
        sys.exit("usage: python3 tools/textures/layered_atlas.py <piece> [--recipes=underground] [--out=dir]")

    recipes = _option(args, "recipes", "underground")
    recipes = Path(recipes) if "/" in recipes else RECIPES / recipes

    for piece in pieces:
        written = paint(piece, Path(_option(args, "source", SOURCE)), Path(_option(args, "out", OUT)), recipes,
                        Path(_option(args, "brushes", brush_sheets.BRUSHES)))
        print("wrote", written)
