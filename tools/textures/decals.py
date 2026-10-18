"""The Underground's grime decals, painted from the user's brush sheets
(brushes.py): water drips run down from a pipe or a ledge, soot over a
lamp or a candle, grime where feet and spills wear the floor, a cart's
oil, standing wet; and loose marigold petals strewn along a trail. All
transparent at their borders, laid in game as Decal nodes.

    python3 tools/textures/decals.py

Writes textures/painted/underground/decal_<kind>.png (512 square, RGBA).
"""

import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

import brushes as brush_sheets

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "textures" / "painted" / "underground"
GRIME = ("drip", "soot", "grime", "oil", "wet")
# The librarian's ward round his desk (docs/superpowers/specs/2026-10-17-librarian-shop-design.md): his chalk
# circle, its glyph band left blank for Part 2's script, and the line of blessed salt that closes its open side.
WARD = ("ward_circle", "salt_line")
KINDS = GRIME + ("petals", "poster") + WARD
# Loose marigold petals strewn along a trail: how many, their size in px, their colours
# (fresh orange to yellow, a few gone brown underfoot).
PETALS = 1400
PETAL_PX = (9, 17)
PETAL_COLOURS = [(236, 140, 22), (248, 168, 30), (226, 110, 18), (250, 186, 52), (232, 128, 20), (150, 82, 24)]
SIZE = 512
BORDER = 8
COLOURS = {"drip": (34, 30, 26), "soot": (18, 16, 18), "grime": (40, 34, 28), "oil": (20, 16, 12), "wet": (38, 44, 52)}


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


def _petals(brushes_dir):
    """Petals strewn in a band along the image's width, thickest down its middle,
    their edge broken by the chipped sheet; each petal a small rotated oval."""
    rng = np.random.default_rng(13)
    canvas = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    draw = ImageDraw.Draw(canvas)
    chips = _sheet("brush_04", brushes_dir)
    placed = 0

    while placed < PETALS:
        x, y = rng.uniform(BORDER + 12, SIZE - BORDER - 12), rng.normal(SIZE / 2, SIZE * 0.13)
        if not BORDER + 12 < y < SIZE - BORDER - 12 or chips[int(y), int(x)] < 0.25:
            continue

        length, width = rng.uniform(*PETAL_PX), rng.uniform(0.45, 0.65)
        turn = rng.uniform(0, np.pi)
        t = np.linspace(0, 2 * np.pi, 10, endpoint=False)
        px = np.cos(t) * length / 2
        py = np.sin(t) * length * width / 2
        outline = list(zip(x + px * np.cos(turn) - py * np.sin(turn), y + px * np.sin(turn) + py * np.cos(turn)))
        colour = PETAL_COLOURS[rng.integers(len(PETAL_COLOURS)) if rng.random() < 0.9 else -1]
        shade = rng.uniform(0.85, 1.05)
        draw.polygon(outline, fill=tuple(int(min(255, c * shade)) for c in colour) + (240,))
        placed += 1

    out = np.asarray(canvas).copy()
    out[:BORDER, :, 3] = out[-BORDER:, :, 3] = 0
    out[:, :BORDER, 3] = out[:, -BORDER:, 3] = 0
    return Image.fromarray(out, "RGBA")


def _poster(brushes_dir):
    """A bill pasted to the tiles and gone yellow: its printed rule round a plain field
    (what it says is the user's to paint), folded twice, stained by the damp from below,
    its edge torn ragged and a corner bitten away by someone tearing it down."""
    rng = np.random.default_rng(17)
    y = np.linspace(0.0, 1.0, SIZE)[:, None]
    x = np.linspace(0.0, 1.0, SIZE)[None, :]
    chips = _sheet("brush_04", brushes_dir)
    strokes = _sheet("brush_02", brushes_dir)
    # The paper's edge, torn: its distance in from each side roughened by the chipped sheet.
    edge = 0.08 + 0.025 * (chips - 0.5)
    inside = np.minimum(np.minimum(x, 1 - x), np.minimum(y, 1 - y)) > edge
    torn = 0.07 * (chips - 0.5) + 0.03 * (strokes - 0.5)
    bite = np.sqrt((x - 0.12) ** 2 + (y - 0.1) ** 2) < 0.14 + torn
    paper = inside & ~bite
    # Pale paper, so each bill's own colour (the decal's modulate in game) shows on it.
    rgb = np.broadcast_to(np.array([236.0, 230.0, 212.0]), (SIZE, SIZE, 3)).copy()
    rgb *= (0.97 + 0.04 * (strokes - 0.5))[..., None]
    # Yellowed toward its edges, stained by damp rising from below.
    rim = np.clip(1.0 - np.minimum(np.minimum(x, 1 - x), np.minimum(y, 1 - y)) / 0.2, 0.0, 1.0)
    damp = np.clip((y - 0.72) / 0.28, 0.0, 1.0) ** 1.5 * (0.6 + 0.4 * chips)
    rgb *= (1.0 - 0.18 * rim - 0.35 * damp)[..., None]
    # The printed rule round the field, and the two folds.
    d = np.minimum(np.minimum(x, 1 - x), np.minimum(y, 1 - y))
    rule = (d > 0.135) & (d < 0.15)
    rgb[rule] = rgb[rule] * 0.35 + np.array([106.0, 42.0, 32.0]) * 0.65
    for fold in (np.abs(x - 0.5) < 0.004, np.abs(y - 0.48) < 0.004):
        rgb[np.broadcast_to(fold, (SIZE, SIZE))] *= 0.86
    alpha = paper * 255.0
    out = np.dstack([np.clip(rgb, 0, 255), alpha]).round().astype(np.uint8)
    out[:BORDER, :, 3] = out[-BORDER:, :, 3] = 0
    out[:, :BORDER, 3] = out[:, -BORDER:, 3] = 0
    return Image.fromarray(out, "RGBA")


def _ward_circle(brushes_dir):
    """His chalk ward: two rings drawn by hand round the desk, broken where the chalk skipped on the boards, the
    band between them blank (its glyphs come with Part 2's script); the middle clear."""
    n = SIZE
    y, x = np.mgrid[0:n, 0:n]
    r = np.hypot(x - n / 2, y - n / 2) / (n / 2)
    a = np.arctan2(y - n / 2, x - n / 2)
    chips = _sheet("brush_04", brushes_dir)
    # Drawn by hand: each ring's radius wanders a little round it.
    wander = 0.008 * np.sin(a * 3.0 + 1.0) + 0.005 * np.sin(a * 7.0)
    rings = np.zeros((n, n))
    for radius, width in ((0.7, 0.03), (0.91, 0.028)):
        rings = np.maximum(rings, np.clip(1.0 - np.abs(r - radius - wander) / width, 0.0, 1.0) ** 0.6)
    # Left open toward the customers (the image's foot, the shopfront's side in game): the salt line closes it.
    opening = np.abs(np.angle(np.exp(1j * (a - np.pi / 2)))) < np.radians(24.0)
    alpha = rings * np.where(chips > 0.22, 0.95, 0.35) * ~opening
    alpha[:BORDER] = alpha[-BORDER:] = 0.0
    alpha[:, :BORDER] = alpha[:, -BORDER:] = 0.0
    rgb = np.broadcast_to(np.array([232.0, 228.0, 216.0]), (n, n, 3))
    return Image.fromarray(np.dstack([rgb, alpha * 255]).round().astype(np.uint8), "RGBA")


def _salt_line(brushes_dir):
    """A line of blessed salt poured across the floor: white grains thick along its middle, scattering out."""
    rng = np.random.default_rng(23)
    canvas = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    draw = ImageDraw.Draw(canvas)

    for _ in range(4200):
        x = rng.uniform(BORDER + 4, SIZE - BORDER - 4)
        y = rng.normal(SIZE / 2, 13.0) if rng.random() < 0.85 else rng.normal(SIZE / 2, 30.0)
        if not BORDER + 4 < y < SIZE - BORDER - 4 or abs(y - SIZE / 2) > 70:
            continue
        g = rng.uniform(0.8, 1.9)
        shade = int(rng.uniform(228, 252))
        draw.ellipse((x - g, y - g, x + g, y + g), fill=(shade, shade, shade - 6, 235))

    out = np.asarray(canvas).copy()
    out[:BORDER, :, 3] = out[-BORDER:, :, 3] = 0
    out[:, :BORDER, 3] = out[:, -BORDER:, 3] = 0
    return Image.fromarray(out, "RGBA")


def make(kind, brushes_dir=brush_sheets.BRUSHES):
    """A decal of `kind` as an RGBA image."""
    if kind == "ward_circle":
        return _ward_circle(brushes_dir)
    if kind == "salt_line":
        return _salt_line(brushes_dir)
    if kind == "petals":
        return _petals(brushes_dir)
    if kind == "poster":
        return _poster(brushes_dir)

    rng = np.random.default_rng({"drip": 3, "soot": 5, "grime": 7, "oil": 9, "wet": 11}[kind])
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
    elif kind == "oil":
        # Where a cart's axle grease has dripped and spread: a dark heart, its edge
        # broken into spatters by the chipped sheet.
        r = np.sqrt((x - 0.5) ** 2 + ((y - 0.5) * 1.3) ** 2)
        heart = np.clip(1.0 - r / 0.32, 0.0, 1.0) ** 0.5
        spatter = (_sheet("brush_04", brushes_dir) > 0.55) * np.clip(1.0 - r / 0.47, 0.0, 1.0)
        alpha = np.maximum(heart * 0.9, spatter * 0.6)
    elif kind == "wet":
        # Standing wet: a soft, broad patch, its edge rippled by the stroke sheet.
        r = np.sqrt((x - 0.5) ** 2 + (y - 0.5) ** 2) + 0.06 * (_sheet("brush_02", brushes_dir) - 0.5)
        alpha = np.clip(1.0 - r / 0.45, 0.0, 1.0) ** 0.35 * 0.75
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
