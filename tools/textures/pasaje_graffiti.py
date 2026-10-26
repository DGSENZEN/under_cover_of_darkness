"""The Pasaje's graffiti (docs/superpowers/specs/2026-10-26-pasaje-market-design.md: "graffiti (painted marks, no
letterforms)"; plan Task 7): sixteen marks sprayed and brushed on the market's walls, on a 4 x 4 sheet the set cuts
into its decals. Every mark is a mark, never a letter: spray bursts broken into a scatter of spots, blots fuller than
any letter's stroke, runs of separate drips, stencilled dots in rows. Their edges and grain come from the user's
brush sheets (textures/brushes).

    python3 tools/textures/pasaje_graffiti.py
"""

import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

sys.path.insert(0, str(Path(__file__).resolve().parent))

import brushes as brush_sheets  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "textures" / "painted" / "underground"
GRID = 4
CELL = 256
BORDER = 6
# The market's paint, faded by the damp and the years: red, blue, yellow, green, white, black, orange, violet.
PAINTS = [(196, 48, 58), (40, 104, 186), (232, 196, 56), (52, 150, 92), (226, 222, 208), (26, 24, 26), (214, 98, 36),
          (140, 66, 160)]
KINDS = ("burst", "blot", "drips", "spots")


def _grain(name, brushes_dir):
    values = brush_sheets.load(name, brushes_dir)
    image = Image.fromarray((values * 255).astype(np.uint8), "L").resize((CELL, CELL), Image.BILINEAR)
    return np.asarray(image, np.float64) / 255.0


def _burst(draw, rng, s):
    """A spray burst: a cloud of spots thickest at its heart."""
    for _ in range(int(rng.integers(45, 80))):
        x, y = rng.normal(s / 2, s * 0.16, 2)
        r = rng.uniform(2.0, 9.0) * (2 if rng.random() < 0.15 else 1)
        draw.ellipse((x - r, y - r, x + r, y + r), fill=255)


def _blot(draw, rng, s):
    """A blot: a wide irregular splash, fuller than any stroke, its rim thrown out in lobes, spatter thrown off it."""
    t = np.linspace(0, 2 * np.pi, 40, endpoint=False)
    r = s * (0.33 + 0.06 * np.sin(3 * t + rng.uniform(0, 6)) + 0.04 * np.sin(7 * t + rng.uniform(0, 6))
             + 0.02 * rng.standard_normal(t.size))
    points = [(s / 2 + rr * np.cos(a), s / 2 + rr * np.sin(a)) for rr, a in zip(r, t)]
    draw.polygon(points, fill=255)
    for _ in range(int(rng.integers(8, 16))):
        a, d = rng.uniform(0, 2 * np.pi), s * rng.uniform(0.38, 0.47)
        x, y, rr = s / 2 + d * np.cos(a), s / 2 + d * np.sin(a), rng.uniform(2.0, 6.0)
        draw.ellipse((x - rr, y - rr, x + rr, y + rr), fill=255)


def _drips(draw, rng, s):
    """Paint run down the wall in separate drips, each from its own ragged sprayed head, thinning as it runs, a bead
    at its foot."""
    count = int(rng.integers(4, 7))
    for k in range(count):
        x = s * (0.18 + 0.64 * k / (count - 1)) + rng.uniform(-8, 8)
        top = s * rng.uniform(0.1, 0.24)
        for _ in range(9):
            hx, hy = x + rng.normal(0, s * 0.025), top + rng.normal(0, s * 0.018)
            hr = s * rng.uniform(0.012, 0.03)
            draw.ellipse((hx - hr, hy - hr, hx + hr, hy + hr), fill=255)
        length = s * rng.uniform(0.32, 0.62)
        w0 = s * rng.uniform(0.014, 0.022)
        steps = 24
        for i in range(steps):
            f = i / steps
            w = w0 * (1.0 - 0.6 * f)
            y = top + length * f
            wob = 1.5 * np.sin(f * 9 + k)
            draw.rectangle((x + wob - w / 2, y, x + wob + w / 2, y + length / steps + 1), fill=255)
        bead = w0 * 0.9
        draw.ellipse((x - bead, top + length - bead, x + bead, top + length + bead * 1.4), fill=255)


def _spots(draw, rng, s):
    """Dots stencilled in rows through a card, a few missing, the card shifted a little between them."""
    rows, cols = int(rng.integers(3, 5)), int(rng.integers(3, 5))
    for j in range(rows):
        for i in range(cols):
            if rng.random() < 0.15:
                continue
            r = s * rng.uniform(0.04, 0.058)
            x = s * (0.2 + 0.6 * i / max(cols - 1, 1)) + rng.normal(0, 2.5)
            y = s * (0.2 + 0.6 * j / max(rows - 1, 1)) + rng.normal(0, 2.5)
            draw.ellipse((x - r, y - r * rng.uniform(0.85, 1.0), x + r, y + r), fill=255)


DRAWS = {"burst": _burst, "blot": _blot, "drips": _drips, "spots": _spots}


def _mark(k, rng, grains):
    """One cell's mark: its ink drawn large and smoothed, roughened by a brush sheet's grain, in one paint (a blot
    with a second paint's ring in it)."""
    big = CELL * 2
    ink = Image.new("L", (big, big), 0)
    DRAWS[KINDS[k % len(KINDS)]](ImageDraw.Draw(ink), rng, big)
    halo = np.asarray(ink.filter(ImageFilter.GaussianBlur(14)).resize((CELL, CELL), Image.LANCZOS), np.float64) / 255.0
    ink = ink.filter(ImageFilter.GaussianBlur(1.5)).resize((CELL, CELL), Image.LANCZOS)
    alpha = np.asarray(ink, np.float64) / 255.0
    grain = grains[k % len(grains)]
    # Its edge chewed by the grain, its body thinned where the spray was light, the overspray misted round it.
    alpha = np.clip(alpha * (0.6 + 0.6 * grain) - 0.25 * (1.0 - grain) * (alpha < 0.95), 0.0, 1.0)
    alpha = np.maximum(alpha, np.clip(halo * 0.9, 0.0, 0.32) * (0.5 + grain))
    paint = np.array(PAINTS[int(rng.integers(len(PAINTS)))], np.float64)
    rgb = np.broadcast_to(paint, (CELL, CELL, 3)) * (0.82 + 0.25 * grain)[..., None]
    if KINDS[k % len(KINDS)] == "blot":
        y, x = np.mgrid[0:CELL, 0:CELL]
        d = np.hypot(x - CELL / 2, y - CELL / 2) / CELL
        ring = (d > 0.17) & (d < 0.23)
        rgb = rgb.copy()
        rgb[ring] = np.array(PAINTS[(int(rng.integers(len(PAINTS))) + 3) % len(PAINTS)], np.float64)
    out = np.dstack([np.clip(rgb, 0, 255), alpha * 255.0]).round().astype(np.uint8)
    out[:BORDER, :, 3] = out[-BORDER:, :, 3] = 0
    out[:, :BORDER, 3] = out[:, -BORDER:, 3] = 0
    return out


def make(brushes_dir=brush_sheets.BRUSHES):
    """The sheet: GRID x GRID marks, each in its own cell."""
    rng = np.random.default_rng(1934)
    grains = [_grain("brush_%02d" % i, brushes_dir) for i in range(5)]
    sheet = np.zeros((GRID * CELL, GRID * CELL, 4), np.uint8)
    for k in range(GRID * GRID):
        j, i = divmod(k, GRID)
        sheet[j * CELL:(j + 1) * CELL, i * CELL:(i + 1) * CELL] = _mark(k, rng, grains)
    return Image.fromarray(sheet, "RGBA")


if __name__ == "__main__":
    OUT.mkdir(parents=True, exist_ok=True)
    path = OUT / "pasaje_graffiti.png"
    make().save(path)
    print("wrote", path.relative_to(ROOT))
