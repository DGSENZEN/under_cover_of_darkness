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
import random
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "textures" / "painted" / "eclipse"
SIZE = 128
SCALE = 4

# Dark to light. Design values (the eclipse city spec, section 4); the user
# may repaint the PNG. The second entry is añil, Line 2's blue.
ZOCALO = [
    "#14121a", "#2f4c7a", "#3a3340", "#5a5560", "#8a8790", "#b9b4b0", "#3d1f1c", "#6e2f26",
    "#9a4a3a", "#2a3b2e", "#3f7a52", "#7fd18a", "#7a5a24", "#c49a40", "#e8d8a8", "#d8e4f0",
]

DABS = 140
LENGTH = (18, 40)
WIDTH = (3, 7)
# Mostly upright, as a brush goes down a wall.
ANGLE = (70, 110)


def _dab(draw, x, y, length, width, angle, shade):
    """A stroke that tapers to a point at both ends, as a laden brush does."""
    dx, dy = math.cos(math.radians(angle)), math.sin(math.radians(angle))
    nx, ny = -dy, dx
    half = length / 2.0
    points = []

    for i in range(9):
        t = i / 8.0
        along = -half + t * length
        w = width * math.sin(math.pi * t) / 2.0
        points.append((x + dx * along + nx * w, y + dy * along + ny * w))

    for i in range(8, -1, -1):
        t = i / 8.0
        along = -half + t * length
        w = width * math.sin(math.pi * t) / 2.0
        points.append((x + dx * along - nx * w, y + dy * along - ny * w))

    draw.polygon(points, fill=shade)


def brush(seed: int = 11) -> Image.Image:
    """The stroke tile: 128 x 128 greyscale, seamless, mid-grey on average."""
    rng = random.Random(seed)
    big = SIZE * SCALE
    canvas = Image.new("L", (big, big), 128)
    draw = ImageDraw.Draw(canvas)

    for _ in range(DABS):
        x, y = rng.uniform(0, big), rng.uniform(0, big)
        length = rng.uniform(*LENGTH) * SCALE
        width = rng.uniform(*WIDTH) * SCALE
        angle = rng.uniform(*ANGLE)
        shade = rng.choice([rng.randint(20, 90), rng.randint(166, 240)])

        for ox in (-big, 0, big):
            for oy in (-big, 0, big):
                _dab(draw, x + ox, y + oy, length, width, angle, shade)

    # Soft edges, as paint has; blurred on a tiled copy so the wrap holds.
    tiled = Image.new("L", (big * 3, big * 3))

    for ox in range(3):
        for oy in range(3):
            tiled.paste(canvas, (ox * big, oy * big))

    soft = tiled.filter(ImageFilter.GaussianBlur(SCALE * 0.6)).crop((big, big, big * 2, big * 2))
    return soft.resize((SIZE, SIZE), Image.Resampling.BOX)


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
    print("painterly: brush.png, palette_zocalo.png ->", OUT)


if __name__ == "__main__":
    main(sys.argv[1:])
