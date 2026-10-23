"""The library's glyph atlases (docs/superpowers/specs/2026-10-17-librarian-shop-design.md, "Words"; Part 2 plan,
Task 5): the words that crawl out of his books are drawn from a signed distance field atlas, so they stay sharp at any
distance, beside a map of where each character sits.

- The invented script (`script`): our own, about forty glyphs drawn as strokes in one hand (a stem, hooks, loops,
  bars, tails, dots), on private-use characters U+E000 on. The temporary words until the user writes theirs.
- Any font (`--font=FILE`): its characters, Spanish and Latin with their accents by default, for the user's readable
  words. (examples_dd3d/Roboto-Bold.ttf, Apache 2.0, bakes `latin`.)

    python3 tools/textures/library_glyphs.py              both atlases
"""

import json
import math
import random
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFont
from scipy import ndimage

ROOT = Path(__file__).resolve().parents[2]
OUT_PNG = ROOT / "textures" / "painted" / "library"
OUT_JSON = ROOT / "assets" / "eclipse" / "source"
## Each cell's size in the atlas (px), how far the field reaches (px, at that size), how much larger it is drawn first.
CELL = 64
SPREAD = 6.0
SUPER = 2
COLS = 8
## The invented script's first character, how many glyphs.
FIRST = 0xE000
COUNT = 40
## A stroke's width (of the cell).
WIDTH = 0.085
LATIN = ("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789.,;:!?'\"-()"
         "áéíóúñüÁÉÍÓÚÑÜ¿¡çÇàèìòùâêîôû")


# --- the invented script ---------------------------------------------------------------------------------------

def _arc(cx, cy, r, a0, a1, steps=8):
    return [(round(cx + r * math.cos(a0 + (a1 - a0) * i / steps), 3), round(cy + r * math.sin(a0 + (a1 - a0) * i / steps), 3))
            for i in range(steps + 1)]


def _glyph(rng):
    """One glyph's strokes (each a list of points in the cell, 0..1, y down; a single point is a dot)."""
    strokes = []
    slant = rng.uniform(-0.08, 0.08)
    x = rng.uniform(0.38, 0.62)
    top, foot = rng.uniform(0.18, 0.3), rng.uniform(0.7, 0.82)
    stem = [(round(x + slant, 3), round(top, 3)), (round(x - slant, 3), round(foot, 3))]
    if rng.random() < 0.85:
        strokes.append(stem)
    parts = rng.sample(["hook", "loop", "bar", "tail", "dot", "chevron", "wave"], rng.randint(1, 3))
    for part in parts:
        side = rng.choice([-1, 1])
        if part == "hook":
            # Over the stem's head and down its side: a half turn from the stem, arching up (y down).
            r = rng.uniform(0.1, 0.16)
            cx = x + slant + side * r
            a0 = math.pi if side > 0 else 0.0
            strokes.append(_arc(cx, top + 0.02 + r * 0.2, r, a0, a0 + side * math.pi, 6))
        elif part == "loop":
            r = rng.uniform(0.1, 0.15)
            cy = rng.uniform(0.38, 0.62)
            a0 = rng.uniform(0.0, math.pi)
            strokes.append(_arc(x + side * r * 0.9, cy, r, a0, a0 + rng.uniform(1.4, 1.9) * math.pi, 10))
        elif part == "bar":
            y = round(rng.uniform(0.35, 0.6), 3)
            strokes.append([(round(x - rng.uniform(0.15, 0.25), 3), y), (round(x + rng.uniform(0.15, 0.25), 3), round(y + rng.uniform(-0.04, 0.04), 3))])
        elif part == "tail":
            # Out of the stem's foot, curling up to one side: a quarter turn and a little more.
            r = rng.uniform(0.1, 0.15)
            cx = x - slant + side * r
            a0 = math.pi if side > 0 else 0.0
            strokes.append(_arc(cx, foot - 0.02 - r * 0.2, r, a0, a0 - side * math.pi * 0.65, 5))
        elif part == "dot":
            strokes.append([(round(x + side * rng.uniform(0.18, 0.26), 3), round(rng.uniform(0.2, 0.35), 3))])
        elif part == "chevron":
            y = rng.uniform(0.42, 0.6)
            w = rng.uniform(0.12, 0.2)
            strokes.append([(round(x - w, 3), round(y - 0.1, 3)), (round(x, 3), round(y + 0.06, 3)), (round(x + w, 3), round(y - 0.1, 3))])
        else:
            y = rng.uniform(0.3, 0.7)
            strokes.append([(round(x - 0.24 + 0.08 * i, 3), round(y + (0.05 if i % 2 else -0.05), 3)) for i in range(7)])
    # Kept within the cell's margin.
    return [[(min(max(px, 0.14), 0.86), min(max(py, 0.14), 0.86)) for px, py in s] for s in strokes]


def script_glyphs(seed=1888, count=COUNT):
    """`count` glyphs of the invented script, none too like another."""
    rng = random.Random(seed)
    glyphs = []
    drawn = []
    while len(glyphs) < count:
        g = _glyph(rng)
        ink = draw_strokes(g, 48) > 0
        if ink.mean() < 0.05 or any(np.mean(ink != other) < 0.04 for other in drawn):
            continue
        glyphs.append(g)
        drawn.append(ink)
    return glyphs


def draw_strokes(strokes, size):
    """A glyph's strokes drawn white on black at `size` px (a uint8 array)."""
    image = Image.new("L", (size, size), 0)
    draw = ImageDraw.Draw(image)
    w = max(1, round(WIDTH * size))
    for s in strokes:
        pts = [(px * size, py * size) for px, py in s]
        if len(pts) > 1:
            draw.line(pts, fill=255, width=w, joint="curve")
        for px, py in (pts if len(pts) == 1 else [pts[0], pts[-1]]):
            r = w * (0.75 if len(pts) == 1 else 0.5)
            draw.ellipse([px - r, py - r, px + r, py + r], fill=255)
    return np.asarray(image)


# --- the distance field ------------------------------------------------------------------------------------------

def _edt(feature):
    """Each pixel's distance to the nearest `feature` pixel."""
    return ndimage.distance_transform_edt(~feature)


def signed_distance(ink, spread=SPREAD):
    """0.5 at the edge, rising inside, falling outside, over `spread` px either way; 0..1."""
    if not ink.any():
        return np.zeros(ink.shape)
    outside = _edt(ink)
    inside = _edt(~ink)
    return np.clip(0.5 + (inside - outside) / (2.0 * spread), 0.0, 1.0)


# --- the atlases ------------------------------------------------------------------------------------------------

def _pack(cells, name, out_png, out_json, chars, advances):
    rows = math.ceil(len(cells) / COLS)
    atlas = np.zeros((rows * CELL, COLS * CELL), np.uint8)
    for i, cell in enumerate(cells):
        r, c = divmod(i, COLS)
        atlas[r * CELL:(r + 1) * CELL, c * CELL:(c + 1) * CELL] = np.round(cell * 255).astype(np.uint8)
    out_png, out_json = Path(out_png), Path(out_json)
    out_png.mkdir(parents=True, exist_ok=True)
    out_json.mkdir(parents=True, exist_ok=True)
    png = out_png / ("glyphs_%s.png" % name)
    Image.fromarray(atlas, "L").save(png)
    meta = {"cell": CELL, "cols": COLS, "rows": rows, "spread": SPREAD,
            "chars": {ch: [i % COLS, i // COLS] for i, ch in enumerate(chars)},
            "advance": {ch: advances[i] for i, ch in enumerate(chars)},
            "fallback": [(len(cells) - 1) % COLS, (len(cells) - 1) // COLS]}
    js = out_json / ("glyphs_%s.json" % name)
    js.write_text(json.dumps(meta, ensure_ascii=False, indent=1) + "\n")
    return png, js


def _cell(ink_big):
    """A glyph drawn SUPER times larger turned into its cell's distance field."""
    sdf = signed_distance(ink_big, SPREAD * SUPER)
    return sdf.reshape(CELL, SUPER, CELL, SUPER).mean(axis=(1, 3))


def _fallback():
    """A small blot, for characters the atlas does not have."""
    return draw_strokes([[(0.5, 0.55)]], CELL * SUPER) > 0


def bake_script(name="script", seed=1888, out_png=OUT_PNG, out_json=OUT_JSON):
    glyphs = script_glyphs(seed)
    cells = [_cell(draw_strokes(g, CELL * SUPER) > 0) for g in glyphs] + [_cell(_fallback())]
    chars = [chr(FIRST + i) for i in range(len(glyphs))]
    return _pack(cells, name, out_png, out_json, chars, [0.7] * len(chars))


def bake_font(name, font_path, chars=LATIN, out_png=OUT_PNG, out_json=OUT_JSON):
    size = CELL * SUPER
    font = ImageFont.truetype(str(font_path), int(size * 0.62))
    cells = []
    advances = []
    for ch in chars:
        image = Image.new("L", (size, size), 0)
        draw = ImageDraw.Draw(image)
        width = draw.textlength(ch, font=font)
        # (On one baseline, so the words sit in a line.)
        draw.text((size / 2 - width / 2, size * 0.76), ch, font=font, fill=255, anchor="ls")
        cells.append(_cell(np.asarray(image) > 127))
        advances.append(round(max(0.25, width / size), 3))
    cells.append(_cell(_fallback()))
    return _pack(cells, name, out_png, out_json, list(chars), advances)


if __name__ == "__main__":
    print(bake_script())
    roboto = ROOT / "examples_dd3d" / "Roboto-Bold.ttf"
    font = next((a.split("=", 1)[1] for a in sys.argv[1:] if a.startswith("--font=")), str(roboto))
    print(bake_font("latin", font))
