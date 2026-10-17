"""The Underground's grime decals, painted from the user's brush sheets
(brushes.py): water drips run down from a pipe or a ledge, soot over a
lamp or a candle, grime where feet and spills wear the floor. Dark,
transparent at their borders, laid in game as Decal nodes.

    python3 tools/textures/decals.py

Writes textures/painted/underground/decal_<kind>.png (512 square, RGBA).
"""

import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageFilter

import brushes as brush_sheets

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "textures" / "painted" / "underground"
KINDS = ("drip", "soot", "grime")
SIZE = 512
BORDER = 8
COLOURS = {"drip": (34, 30, 26), "soot": (18, 16, 18), "grime": (40, 34, 28)}


def _sheet(name, brushes_dir):
    values = brush_sheets.load(name, brushes_dir)
    image = Image.fromarray((values * 255).astype(np.uint8), "L").resize((SIZE, SIZE), Image.BILINEAR)
    return np.asarray(image, np.float64) / 255.0


def _fade(size, edge):
    """1 inside, falling smoothly to 0 over `edge` px to a clear border."""
    ramp = np.clip((np.arange(size) - BORDER) / edge, 0.0, 1.0)
    ramp = np.minimum(ramp, ramp[::-1])
    t = ramp * ramp * (3 - 2 * ramp)
    return np.minimum.outer(t, t)


def make(kind, brushes_dir=brush_sheets.BRUSHES):
    """A decal of `kind` as an RGBA image."""
    rng = np.random.default_rng({"drip": 3, "soot": 5, "grime": 7}[kind])
    y = np.linspace(0.0, 1.0, SIZE)[:, None]          # 0 at the top
    x = np.linspace(0.0, 1.0, SIZE)[None, :]

    if kind == "drip":
        # Streaks: columns of varying length hanging from a wet band at the top.
        streaks = np.zeros((SIZE, SIZE))
        for _ in range(14):
            cx, width, length = rng.uniform(0.1, 0.9), rng.uniform(0.01, 0.035), rng.uniform(0.3, 0.9)
            column = np.exp(-((x - cx) / width) ** 2)
            streaks = np.maximum(streaks, column * np.clip(1.0 - y / length, 0.0, 1.0) ** 0.7)
        band = np.clip(1.0 - y / 0.15, 0.0, 1.0)
        alpha = np.maximum(streaks, band) * (0.55 + 0.45 * _sheet("brush_04", brushes_dir))
    elif kind == "soot":
        # A plume: darkest at the top, spreading as it rises.
        centre = np.exp(-((x - 0.5) / (0.18 + 0.25 * (1.0 - y))) ** 2)
        alpha = centre * (1.0 - y) ** 1.2 * (0.6 + 0.4 * _sheet("brush_03", brushes_dir))
    else:
        # A worn, spilt patch: blotches from the chipped sheet, round at its edges.
        r = np.sqrt((x - 0.5) ** 2 + (y - 0.5) ** 2)
        alpha = np.clip(1.0 - r / 0.48, 0.0, 1.0) ** 0.6 * _sheet("brush_04", brushes_dir)

    alpha = np.clip(alpha, 0.0, 1.0) * _fade(SIZE, 48)
    alpha[:BORDER] = alpha[-BORDER:] = 0.0
    alpha[:, :BORDER] = alpha[:, -BORDER:] = 0.0
    rgb = np.broadcast_to(np.array(COLOURS[kind], np.float64), (SIZE, SIZE, 3))
    out = np.dstack([rgb, alpha * 255]).round().astype(np.uint8)
    return Image.fromarray(out, "RGBA").filter(ImageFilter.SMOOTH)


if __name__ == "__main__":
    OUT.mkdir(parents=True, exist_ok=True)

    for kind in KINDS:
        path = OUT / ("decal_%s.png" % kind)
        image = make(kind)
        a = np.asarray(image).copy()
        a[:BORDER, :, 3] = a[-BORDER:, :, 3] = 0
        a[:, :BORDER, 3] = a[:, -BORDER:, 3] = 0
        Image.fromarray(a, "RGBA").save(path)
        print("wrote", path.relative_to(ROOT))

    sys.exit(0)
