"""The astral passages' glyphs (docs/superpowers/specs/2026-10-26-astral-passages-design.md, round two), from the
invented script (tools/textures/library_glyphs.py), standing in for the user's own:

- astral_rings.png: the ward-gate's three rings side by side, each a band of glyphs round a circle between thin ruled
  circles, the glyphs turned to face out, small ticks between them; white on clear (the gate tints them);
- astral_constellations.json: six glyphs as the deep's constellations, their strokes (points 0..1).

    python3 tools/textures/astral_glyphs.py
"""

import json
import math
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

sys.path.insert(0, str(Path(__file__).resolve().parent))

import library_glyphs  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "textures" / "painted" / "underground"
CELL = 1024
# Drawn at twice the size, then brought down.
BIG = CELL * 2
# Each ring: [its inner radius, its outer (of the cell), how many glyphs round it, its seed].
RINGS = [(0.4, 0.48, 22, 1941), (0.29, 0.37, 16, 1942), (0.17, 0.25, 11, 1943)]
LINE = 0.004
SEED = 1888


def _ring(inner, outer, count, seed):
    image = Image.new("L", (BIG, BIG), 0)
    draw = ImageDraw.Draw(image)
    script = library_glyphs.script_glyphs(seed=SEED)
    rng = np.random.default_rng(seed)
    c = BIG / 2
    w = max(2, round(LINE * BIG))
    # Its ruled circles.
    for r in (inner + 0.006, outer - 0.006):
        draw.ellipse((c - r * BIG, c - r * BIG, c + r * BIG, c + r * BIG), outline=255, width=w)
    size = (outer - inner) * 0.62
    middle = (inner + outer) / 2
    for k in range(count):
        a = 2 * math.pi * k / count
        glyph = script[int(rng.integers(len(script)))]
        # (Turned to face out: its up along the radius.)
        out = (math.cos(a), math.sin(a))
        along = (-math.sin(a), math.cos(a))
        at = (c + out[0] * middle * BIG, c + out[1] * middle * BIG)
        for stroke in glyph:
            pts = []
            for px, py in stroke:
                u, v = (px - 0.5) * size * BIG, (py - 0.5) * size * BIG
                pts.append((at[0] + along[0] * u - out[0] * v, at[1] + along[1] * u - out[1] * v))
            if len(pts) > 1:
                draw.line(pts, fill=255, width=w * 2, joint="curve")
            else:
                x, y = pts[0]
                draw.ellipse((x - w, y - w, x + w, y + w), fill=255)
        # A tick between it and the next.
        b = a + math.pi / count
        for r0, r1 in ((inner + 0.006, inner + 0.016), (outer - 0.016, outer - 0.006)):
            draw.line([(c + math.cos(b) * r0 * BIG, c + math.sin(b) * r0 * BIG),
                       (c + math.cos(b) * r1 * BIG, c + math.sin(b) * r1 * BIG)], fill=255, width=w)
    return image.resize((CELL, CELL), Image.LANCZOS)


def make_rings():
    """The three rings side by side: white on clear, their alpha the ink."""
    sheet = np.zeros((CELL, CELL * 3, 4), np.uint8)
    for k, (inner, outer, count, seed) in enumerate(RINGS):
        ink = np.asarray(_ring(inner, outer, count, seed))
        sheet[:, k * CELL:(k + 1) * CELL, :3] = 255
        sheet[:, k * CELL:(k + 1) * CELL, 3] = ink
    return Image.fromarray(sheet, "RGBA")


def constellations(seed=1939, count=6):
    """`count` glyphs of the script, as their strokes (each a list of [x, y], 0..1)."""
    script = library_glyphs.script_glyphs(seed=SEED)
    rng = np.random.default_rng(seed)
    picks = rng.choice(len(script), size=count, replace=False)
    return [[[[float(px), float(py)] for px, py in stroke] for stroke in script[int(i)]] for i in picks]


if __name__ == "__main__":
    OUT.mkdir(parents=True, exist_ok=True)
    make_rings().save(OUT / "astral_rings.png")
    (OUT / "astral_constellations.json").write_text(json.dumps(constellations()))
    print("wrote", (OUT / "astral_rings.png").relative_to(ROOT), "and astral_constellations.json")
