#!/usr/bin/env python3
"""The painterly look's own brush and palettes (the Eclipse city's style lab):
a seamless tile of brush strokes the painterly shader projects onto walls
from the world's three axes, and each district's palette the shader maps
colours onto. Drawn by us, so they are committed.

    python3 tools/textures/painterly.py     -> textures/painted/eclipse/brush.png
                                               and palette_zocalo.png

The brush is drawn at four times its size, each dab at its nine tiled
offsets so the tile wraps, then shrunk by averaging as paint.py does
(without cutting it to a palette: it is a greyscale mask).

Needs Pillow and numpy.
"""

import math
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "textures" / "painted" / "eclipse"

# Dark to light. Design values (the eclipse city spec, section 4); the user
# may repaint the PNG. The second entry is añil, Line 2's blue.
ZOCALO = [
    "#14121a", "#2f4c7a", "#3a3340", "#5a5560", "#8a8790", "#b9b4b0", "#3d1f1c", "#6e2f26",
    "#9a4a3a", "#2a3b2e", "#3f7a52", "#7fd18a", "#7a5a24", "#c49a40", "#e8d8a8", "#d8e4f0",
]

# The brush tile, after the user's reference (Oct 9 2026): plaster worked
# with a broad brush. Soft, low contrast, sweeping strokes at several sizes
# with bristle streaks inside them, mostly one shallow diagonal way.
BRUSH_SIZE = 256
# The sweep's heading (degrees, image space) and how far strokes stray from it.
SWEEP = 15.0
SWEEP_SPREAD = 20.0
# On the 2x canvas. Soft smudges under everything, and smears any way at all
# (the calm patches): (count, length px, width px, alpha, tone).
SMUDGES = (26, (160, 380), (60, 130), (0.10, 0.18), (8, 20))
SMEARS = (50, (30, 110), (30, 90), (0.14, 0.24), (8, 22))
# Strokes built of their bristles: (count, length px, width px, lanes, tone).
STROKES = (190, (40, 140), (20, 64), (12, 24), (12, 32))
# Dry-brush scratches over the whole tile: (count, length px, tone).
SCRATCHES = (1400, (6, 26), (10, 36))
# A fine grain under it all, as the paper or plaster's tooth (grey levels).
GRAIN = 3.0
# The tile's contrast once painted (grey levels, standard deviation).
CONTRAST = 12.0


def _path(rng, size, length, any_way=False):
    """A gently curved stroke: points along a quadratic curve heading SWEEP
    (or any way at all)."""
    heading = rng.uniform(0, 2 * math.pi) if any_way else math.radians(rng.normal(SWEEP, SWEEP_SPREAD))
    x0, y0 = rng.uniform(0, size), rng.uniform(0, size)
    dx, dy = math.cos(heading) * length, math.sin(heading) * length
    bend = rng.normal(0, 0.18) * length
    cx, cy = x0 + dx / 2 - math.sin(heading) * bend, y0 + dy / 2 + math.cos(heading) * bend
    out = []

    for i in range(17):
        t = i / 16
        out.append(((1 - t) ** 2 * x0 + 2 * (1 - t) * t * cx + t * t * (x0 + dx),
                    (1 - t) ** 2 * y0 + 2 * (1 - t) * t * cy + t * t * (y0 + dy)))

    return out, heading


def _wrapped_line(points, width, size):
    """A soft stroke along points, drawn at its nine tiled places so it wraps."""
    mask = Image.new("L", (size, size), 0)
    draw = ImageDraw.Draw(mask)

    for ox in (-size, 0, size):
        for oy in (-size, 0, size):
            draw.line([(x + ox, y + oy) for x, y in points], fill=255, width=max(1, int(width)), joint="curve")

    return mask


def _soft(mask, radius, size):
    """A mask blurred across the tile's edges."""
    tiled = Image.new("L", (size * 3, size * 3))

    for ox in range(3):
        for oy in range(3):
            tiled.paste(mask, (ox * size, oy * size))

    return np.asarray(tiled.filter(ImageFilter.GaussianBlur(radius)).crop((size, size, size * 2, size * 2)),
                      dtype=np.float64) / 255.0


def _lanes(points, heading, width, lanes, rng, size):
    """A stroke made of its bristles: `lanes` thin lines along its path across
    its width, each pressed a little differently (a mask, 0-255)."""
    mask = Image.new("L", (size, size), 0)
    draw = ImageDraw.Draw(mask)
    across = (-math.sin(heading), math.cos(heading))

    for _ in range(lanes):
        k = rng.uniform(-0.5, 0.5) * width
        press = int(rng.uniform(120, 255))
        thick = max(1, int(rng.uniform(1, 3)))
        lane = [(x + across[0] * k, y + across[1] * k) for x, y in points]
        # Each bristle lifts off before the stroke ends: a share of its length.
        cut = int(len(lane) * rng.uniform(0.55, 1.0))
        start = int(rng.uniform(0, len(lane) - cut + 1))

        for ox in (-size, 0, size):
            for oy in (-size, 0, size):
                draw.line([(x + ox, y + oy) for x, y in lane[start:start + cut]], fill=press, width=thick)

    return mask


def brush(seed: int = 11) -> Image.Image:
    """The stroke tile: BRUSH_SIZE square, greyscale, seamless, mid grey on
    average, sweeping one shallow way, dry-brushed."""
    rng = np.random.default_rng(seed)
    big = BRUSH_SIZE * 2
    canvas = np.full((big, big), 128.0)

    for any_way, (count, length, width, alpha, tone) in ((False, SMUDGES), (True, SMEARS)):
        for _ in range(count):
            points, _ = _path(rng, big, rng.uniform(*length), any_way=any_way)
            w = rng.uniform(*width)
            shade = rng.uniform(*tone) * (1 if rng.random() < 0.5 else -1)
            canvas += _soft(_wrapped_line(points, w, big), w * 0.45, big) * shade * rng.uniform(*alpha) * 4.0

    count, length, width, lanes, tone = STROKES

    for _ in range(count):
        points, heading = _path(rng, big, rng.uniform(*length))
        mask = _lanes(points, heading, rng.uniform(*width), int(rng.uniform(*lanes)), rng, big)
        shade = rng.uniform(*tone) * (1 if rng.random() < 0.5 else -1)
        canvas += _soft(mask, 1.1, big) * shade * rng.uniform(0.3, 0.6)

    count, length, tone = SCRATCHES
    patches = np.clip((_soft(Image.fromarray((rng.random((big // 32, big // 32)) * 255).astype(np.uint8)).resize(
        (big, big), Image.Resampling.BICUBIC), 6.0, big) - 0.35) * 2.5, 0.0, 1.0)

    for sign in (1, -1):
        mask = Image.new("L", (big, big), 0)
        draw = ImageDraw.Draw(mask)

        for _ in range(count // 2):
            points, _ = _path(rng, big, rng.uniform(*length))
            press = int(255 * rng.uniform(tone[0], tone[1]) / tone[1])

            for ox in (-big, 0, big):
                for oy in (-big, 0, big):
                    draw.line([(x + ox, y + oy) for x, y in points[::4]], fill=press, width=1)

        # In patches, not everywhere: where the brush ran dry.
        canvas += _soft(mask, 0.5, big) * patches * sign * tone[1] * 0.6

    canvas += rng.normal(0.0, GRAIN, canvas.shape)
    small = np.asarray(Image.fromarray(np.clip(canvas, 0, 255).astype(np.uint8), "L").resize(
        (BRUSH_SIZE, BRUSH_SIZE), Image.Resampling.BOX), dtype=np.float64)
    small = 128.0 + (small - small.mean()) * (CONTRAST / max(small.std(), 1e-6))
    return Image.fromarray(np.clip(np.round(small), 0, 255).astype(np.uint8), "L")


# The light ramp (variant D, after TF2's warped diffuse): from no light to
# full, the colour a surface takes. Stops (position 0-1, colour) held flat
# and joined in soft steps. A starting point for the user to repaint.
RAMP_SIZE = 64
# The stops are sRGB; the shader reads the ramp as linear light, so they are
# chosen for their linear values: about 0.07 cool, 0.31 cool-neutral, 0.66
# warm-neutral, 0.95 warm.
RAMP_STOPS = [(0.0, "#454a63"), (0.3, "#9494a1"), (0.55, "#d9d4cf"), (0.8, "#fffaf2")]
RAMP_STEP = 0.05


def ramp() -> Image.Image:
    """The ramp: RAMP_SIZE x 1, plateaus at each stop, soft steps between."""
    stops = [(t, np.array([int(c[k:k + 2], 16) for k in (1, 3, 5)], dtype=np.float64)) for t, c in RAMP_STOPS]
    out = np.zeros((1, RAMP_SIZE, 3))

    for i in range(RAMP_SIZE):
        t = i / (RAMP_SIZE - 1)
        colour = stops[0][1]

        for (t0, _), (t1, c1) in zip(stops, stops[1:]):
            # Each step sits halfway between two stops, RAMP_STEP wide.
            mid = (t0 + t1) / 2
            k = np.clip((t - (mid - RAMP_STEP / 2)) / RAMP_STEP, 0.0, 1.0)
            k = k * k * (3 - 2 * k)
            colour = colour * (1 - k) + c1 * k

        out[0, i] = colour

    return Image.fromarray(np.clip(np.round(out), 0, 255).astype(np.uint8), "RGB")


# A Company lamp's painted pool of light (variant D): a splash, its edge broken
# by the brush tile.
POOL_SIZE = 128
POOL_EDGE = 0.32        # the edge's radius, of the tile's width
POOL_BREAK = 0.5        # how far the brush pushes the edge in and out


def pool() -> Image.Image:
    """The pool: POOL_SIZE square, greyscale, bright at its heart, its edge
    stroked, nothing at its rim."""
    tile = np.asarray(brush().resize((POOL_SIZE, POOL_SIZE), Image.Resampling.BOX), dtype=np.float64) / 255.0
    yy, xx = np.mgrid[:POOL_SIZE, :POOL_SIZE] - (POOL_SIZE - 1) / 2
    r = np.hypot(yy, xx) / POOL_SIZE
    # The edge pushed in and out by the strokes, stronger the further out.
    edge = POOL_EDGE + (tile - 0.5) * POOL_BREAK * 0.6
    light = np.clip(1.0 - (r - edge * 0.55) / (edge * 0.6), 0.0, 1.0)
    light = light * light * (3 - 2 * light)
    light *= np.clip((0.5 - r) / 0.05, 0.0, 1.0)            # nothing at the rim
    return Image.fromarray(np.clip(np.round(light * 255), 0, 255).astype(np.uint8), "L")


def palette(colours: list) -> Image.Image:
    """A district's palette: one pixel per colour, dark to light, 16 x 1."""
    image = Image.new("RGB", (len(colours), 1))

    for i, colour in enumerate(colours):
        image.putpixel((i, 0), tuple(int(colour[k:k + 2], 16) for k in (1, 3, 5)))

    return image


def main(argv):
    OUT.mkdir(parents=True, exist_ok=True)
    brush().save(OUT / "brush.png")
    palette(ZOCALO).save(OUT / "palette_zocalo.png")
    ramp().save(OUT / "ramp_zocalo.png")
    pool().save(OUT / "lamp_pool.png")
    print("painterly: brush.png, palette_zocalo.png, ramp_zocalo.png, lamp_pool.png ->", OUT)


if __name__ == "__main__":
    main(sys.argv[1:])
