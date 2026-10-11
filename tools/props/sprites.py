"""The drifting sprites, drawn here and nowhere else (no downloaded effects):
marigold petals blown round the god and the wakes, and leaves falling from
the trees, each four frames of 32 px in a 2 x 2 sheet, cut out clean, drawn
at four times the size and shrunk.

    python3 tools/props/sprites.py      assets/vfx/petal.png, assets/vfx/leaf.png
"""

import math
import random
from pathlib import Path

from PIL import Image, ImageDraw

VFX = Path(__file__).resolve().parents[2] / "assets" / "vfx"
SCALE = 4
FRAME = 32

MARIGOLD = [(242, 162, 12), (230, 130, 10), (217, 102, 10), (250, 186, 40)]
LEAVES = [(92, 112, 44), (120, 128, 52), (150, 120, 50), (128, 92, 42), (76, 98, 40)]


def _leaf_shape(cx, cy, length, width, angle):
    points = []

    for i in range(13):
        t = i / 12
        points.append((t * length - length / 2, width * 0.5 * math.sin(math.pi * t) ** 0.8))

    outline = points + [(x, -y) for x, y in reversed(points[1:-1])]
    ca, sa = math.cos(angle), math.sin(angle)
    return [(cx + x * ca - y * sa, cy + x * sa + y * ca) for x, y in outline]


def _sheet(draw_frame, seed):
    size = FRAME * SCALE
    sheet = Image.new("RGBA", (size * 2, size * 2), (0, 0, 0, 0))
    rng = random.Random(seed)

    for k in range(4):
        frame = Image.new("RGBA", (size, size), (0, 0, 0, 0))
        draw_frame(ImageDraw.Draw(frame), size, rng, k)
        sheet.alpha_composite(frame, ((k % 2) * size, (k // 2) * size))

    small = sheet.resize((FRAME * 2, FRAME * 2), Image.Resampling.BOX)
    alpha = small.getchannel("A").point(lambda a: 255 if a >= 128 else 0)
    out = small.convert("RGB").quantize(colors=24, dither=Image.Dither.NONE).convert("RGBA")
    out.putalpha(alpha)
    return out


def petal():
    """A few marigold petals each frame, ragged at their tips, the frames
    turned so a tumbling petal seems to roll."""
    def frame(draw, size, rng, k):
        c = size / 2

        for p in range(3):
            angle = k * math.pi / 4 + p * 2.2 + rng.uniform(-0.3, 0.3)
            off = (math.cos(angle) * size * 0.12, math.sin(angle) * size * 0.12)
            shape = _leaf_shape(c + off[0], c + off[1], size * 0.42, size * 0.26 * (1.0 - 0.3 * (k % 2)), angle)
            colour = MARIGOLD[(k + p) % len(MARIGOLD)]
            draw.polygon(shape, fill=colour + (255,), outline=tuple(int(v * 0.75) for v in colour) + (255,))

    return _sheet(frame, 17)


def leaf():
    """A fallen leaf each frame, seen flat, on edge and between as it turns,
    its vein drawn darker."""
    def frame(draw, size, rng, k):
        c = size / 2
        width = size * (0.36, 0.22, 0.13, 0.26)[k]
        angle = rng.uniform(0, math.pi)
        colour = LEAVES[k % len(LEAVES)]
        shape = _leaf_shape(c, c, size * 0.72, width, angle)
        draw.polygon(shape, fill=colour + (255,), outline=tuple(int(v * 0.7) for v in colour) + (255,))
        a, b = shape[0], shape[12]
        draw.line([a, b], fill=tuple(int(v * 0.6) for v in colour) + (255,), width=max(1, SCALE))

    return _sheet(frame, 23)


def main():
    VFX.mkdir(parents=True, exist_ok=True)

    for name, make in (("petal", petal), ("leaf", leaf)):
        make().save(VFX / (name + ".png"))
        print("sprites: %s" % (VFX / (name + ".png")))


if __name__ == "__main__":
    main()
