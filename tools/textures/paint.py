#!/usr/bin/env python3
"""Textures we paint ourselves (no photo in them, so they are committed):
the garrison's banner, the chapel's rose window and altar frontal, the mess
hall's shields.

    python3 tools/textures/paint.py            every one -> textures/painted/<name>.png
    python3 tools/textures/paint.py banner     just those named

Each is drawn at four times its size with Pillow, shrunk by averaging and cut
down to its own palette without dithering, as ps2ify.py treats the photos
(the Retro screen dithers the whole frame).

Needs Pillow and numpy.
"""

import math
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "textures" / "painted"
SCALE = 4

CRIMSON = (122, 20, 24)
GOLD = (196, 152, 64)
BONE = (214, 200, 168)
LEAD = (18, 16, 18)
IRON = (52, 50, 48)


def _finish(image, size, colours, alpha=None):
    """Shrunk by averaging, cut to `colours` without dithering; `alpha`
    (a mask at the drawn size) cut clean at half."""
    small = image.convert("RGB").resize(size, Image.Resampling.BOX)
    out = small.quantize(colors=colours, dither=Image.Dither.NONE).convert("RGBA")

    if alpha is not None:
        out.putalpha(alpha.resize(size, Image.Resampling.BOX).point(lambda a: 255 if a >= 128 else 0))

    return out


def _cloth(width, height, colour, folds=3, seed=3):
    """A field of cloth: `colour` in soft vertical folds, a little weave."""
    x = np.linspace(0.0, 1.0, width)[None, :]
    y = np.linspace(0.0, 1.0, height)[:, None]
    shade = 0.84 + 0.16 * np.cos(x * math.tau * folds + 0.6) * (0.6 + 0.4 * y)
    rng = np.random.default_rng(seed)
    weave = 1.0 + 0.04 * (rng.random((height, width)) - 0.5)
    pixels = np.asarray(colour, dtype=np.float64)[None, None, :] * (shade * weave)[:, :, None]
    return Image.fromarray(np.clip(pixels, 0, 255).astype(np.uint8), "RGB")


def _tower(draw, cx, base, width, height, fill, dark):
    """The garrison's device: a keep of three merlons, its door and windows."""
    left, right = cx - width / 2, cx + width / 2
    top = base - height
    merlon = width / 5
    draw.rectangle([left, top + merlon, right, base], fill=fill)

    for i in (0, 2, 4):
        draw.rectangle([left + i * merlon, top, left + (i + 1) * merlon, top + merlon + 2], fill=fill)

    door_w = width * 0.3
    draw.rectangle([cx - door_w / 2, base - height * 0.32, cx + door_w / 2, base], fill=dark)
    draw.ellipse([cx - door_w / 2, base - height * 0.32 - door_w / 2, cx + door_w / 2, base - height * 0.32 + door_w / 2], fill=dark)

    for side in (-1, 1):
        wx = cx + side * width * 0.24
        draw.rectangle([wx - width * 0.05, top + height * 0.3, wx + width * 0.05, top + height * 0.46], fill=dark)


def banner():
    """The garrison's banner: crimson, a gold border, the keep in bone over
    two crossed keys; a swallowtail with a gold fringe."""
    w, h = 64 * SCALE, 160 * SCALE
    image = _cloth(w, h, CRIMSON, folds=2)
    draw = ImageDraw.Draw(image)
    tail = h * 0.86
    notch = h * 0.74
    # The sleeve the pole goes through.
    draw.rectangle([0, 0, w, 11 * SCALE], fill=(88, 14, 18))
    draw.line([0, 11 * SCALE, w, 11 * SCALE], fill=GOLD, width=SCALE)
    # A gold border inside the edges, down to the tails.
    inset = 5 * SCALE
    draw.line([inset, 14 * SCALE, inset, tail - inset], fill=GOLD, width=2 * SCALE)
    draw.line([w - inset, 14 * SCALE, w - inset, tail - inset], fill=GOLD, width=2 * SCALE)
    draw.line([inset, 14 * SCALE, w - inset, 14 * SCALE], fill=GOLD, width=2 * SCALE)
    draw.line([inset, tail - inset, w / 2, notch - inset], fill=GOLD, width=2 * SCALE)
    draw.line([w - inset, tail - inset, w / 2, notch - inset], fill=GOLD, width=2 * SCALE)
    # Crossed keys behind the keep.
    cx, cy = w / 2, h * 0.47

    for side in (-1, 1):
        angle = math.radians(side * 38)
        dx, dy = math.sin(angle) * h * 0.2, math.cos(angle) * h * 0.2
        draw.line([cx - dx, cy + dy, cx + dx, cy - dy], fill=GOLD, width=3 * SCALE)
        bow = (cx + dx, cy - dy)
        draw.ellipse([bow[0] - 5 * SCALE, bow[1] - 5 * SCALE, bow[0] + 5 * SCALE, bow[1] + 5 * SCALE], outline=GOLD, width=2 * SCALE)
        bit = (cx - dx, cy + dy)
        x0, x1 = sorted((bit[0] - side * 5 * SCALE, bit[0]))
        draw.rectangle([x0, bit[1] - 2 * SCALE, x1, bit[1] + 2 * SCALE], fill=GOLD)

    _tower(draw, cx, cy + h * 0.12, w * 0.42, h * 0.26, BONE, (60, 12, 16))
    # A star over it.
    sx, sy, r = cx, h * 0.18, 6 * SCALE
    points = []

    for i in range(10):
        a = -math.pi / 2 + i * math.pi / 5
        points.append((sx + math.cos(a) * (r if i % 2 == 0 else r * 0.45), sy + math.sin(a) * (r if i % 2 == 0 else r * 0.45)))

    draw.polygon(points, fill=GOLD)
    # The swallowtail (cut out) and its fringe.
    mask = Image.new("L", (w, h), 255)
    ImageDraw.Draw(mask).polygon([(0, tail), (w / 2, notch), (w, tail), (w, h), (0, h)], fill=0)

    for i in range(0, w, 3 * SCALE):
        t = i / w
        edge = tail - (tail - notch) * (1.0 - abs(t - 0.5) * 2.0)
        draw.line([i, edge - 1 * SCALE, i, edge + 5 * SCALE], fill=GOLD, width=SCALE)
        ImageDraw.Draw(mask).line([i, edge, i, edge + 5 * SCALE], fill=255, width=SCALE)

    return _finish(image, (64, 160), 24, mask)


def _mottle(draw, box, colour, rng, spots=6):
    """Glass: a flat colour with a few lighter and darker streaks."""
    x0, y0, x1, y1 = box
    draw.rectangle(box, fill=colour)

    for _ in range(spots):
        k = rng.uniform(0.75, 1.3)
        c = tuple(int(min(255, v * k)) for v in colour)
        cx, cy = rng.uniform(x0, x1), rng.uniform(y0, y1)
        r = rng.uniform(4, 16) * SCALE
        draw.ellipse([cx - r, cy - r * 0.6, cx + r, cy + r * 0.6], fill=c)


def rose_window():
    """A rose: a gold heart and a red quatrefoil, eight petals in ruby and
    sapphire, sixteen roundels round them, all in lead on deep blue."""
    size = 256 * SCALE
    c = size / 2
    rng = np.random.default_rng(11)
    image = Image.new("RGB", (size, size), LEAD)
    draw = ImageDraw.Draw(image)
    ruby, sapphire, emerald, amber, white = (170, 26, 30), (34, 58, 150), (30, 110, 60), (220, 150, 40), (220, 210, 170)
    # The ground: deep blue quarries.
    draw.ellipse([c - c * 0.97, c - c * 0.97, c + c * 0.97, c + c * 0.97], fill=(22, 34, 98))
    step = 14 * SCALE

    for i in range(-20, 21):
        draw.line([c + i * step - c, 0, c + i * step + c, size], fill=(14, 20, 60), width=SCALE)
        draw.line([c + i * step + c, 0, c + i * step - c, size], fill=(14, 20, 60), width=SCALE)

    lead = 5 * SCALE
    # Sixteen roundels round the edge.
    for i in range(16):
        a = i * math.tau / 16
        x, y, r = c + math.cos(a) * c * 0.8, c + math.sin(a) * c * 0.8, c * 0.13
        colour = ruby if i % 2 == 0 else amber
        draw.ellipse([x - r, y - r, x + r, y + r], fill=LEAD)
        draw.ellipse([x - r + lead, y - r + lead, x + r - lead, y + r - lead], fill=colour)
        draw.ellipse([x - r * 0.4, y - r * 0.4, x + r * 0.4, y + r * 0.4], fill=white if i % 2 == 0 else emerald)

    # Eight petals: pointed lobes from the heart outward.
    for i in range(8):
        a = i * math.tau / 8 + math.tau / 16
        colour = sapphire if i % 2 == 0 else ruby
        outer, inner, half = c * 0.66, c * 0.27, math.radians(17)
        points = [(c + math.cos(a) * inner, c + math.sin(a) * inner)]

        for k in range(9):
            t = -half + 2 * half * k / 8
            r = outer * (0.78 + 0.22 * math.cos(t / half * math.pi / 2))
            points.append((c + math.cos(a + t) * r, c + math.sin(a + t) * r))

        draw.polygon(points, fill=LEAD)
        shrunk = [(c + (px - c) * 0.9 + math.cos(a) * c * 0.03, c + (py - c) * 0.9 + math.sin(a) * c * 0.03) for px, py in points]
        draw.polygon(shrunk, fill=colour)
        mx, my = c + math.cos(a) * c * 0.48, c + math.sin(a) * c * 0.48
        r = c * 0.07
        draw.ellipse([mx - r, my - r, mx + r, my + r], fill=LEAD)
        draw.ellipse([mx - r + lead / 2, my - r + lead / 2, mx + r - lead / 2, my + r - lead / 2], fill=white if i % 2 == 0 else amber)

    # The heart: gold, a red quatrefoil in it.
    r = c * 0.25
    draw.ellipse([c - r, c - r, c + r, c + r], fill=LEAD)
    draw.ellipse([c - r + lead, c - r + lead, c + r - lead, c + r - lead], fill=amber)

    for i in range(4):
        a = i * math.tau / 4
        x, y, q = c + math.cos(a) * r * 0.42, c + math.sin(a) * r * 0.42, r * 0.36
        draw.ellipse([x - q, y - q, x + q, y + q], fill=ruby)

    draw.ellipse([c - r * 0.2, c - r * 0.2, c + r * 0.2, c + r * 0.2], fill=white)
    # Glass is never one flat colour: streaks through it all.
    pixels = np.asarray(image, dtype=np.float64)
    streak = 0.88 + 0.24 * rng.random((size // (8 * SCALE) + 1, size // (8 * SCALE) + 1))
    streak = np.asarray(Image.fromarray((streak * 127).astype(np.uint8), "L").resize((size, size), Image.Resampling.BILINEAR), dtype=np.float64) / 127
    image = Image.fromarray(np.clip(pixels * streak[:, :, None], 0, 255).astype(np.uint8), "RGB")
    # The stone ring's edge.
    ImageDraw.Draw(image).ellipse([c - c * 0.99, c - c * 0.99, c + c * 0.99, c + c * 0.99], outline=LEAD, width=6 * SCALE)
    return _finish(image, (256, 256), 40)


def altar_frontal():
    """The altar's cloth: crimson, a gold orphrey round it, a cross between
    two fleurs."""
    w, h = 128 * SCALE, 64 * SCALE
    image = _cloth(w, h, (104, 16, 28), folds=5, seed=5)
    draw = ImageDraw.Draw(image)
    draw.rectangle([0, 0, w, 7 * SCALE], fill=GOLD)
    draw.rectangle([0, h - 5 * SCALE, w, h], fill=GOLD)
    draw.line([0, 9 * SCALE, w, 9 * SCALE], fill=(150, 110, 40), width=SCALE)
    cx, cy = w / 2, h * 0.55
    arm = 16 * SCALE
    draw.rectangle([cx - 3 * SCALE, cy - arm, cx + 3 * SCALE, cy + arm], fill=GOLD)
    draw.rectangle([cx - arm * 0.7, cy - arm * 0.45, cx + arm * 0.7, cy - arm * 0.45 + 6 * SCALE], fill=GOLD)

    for side in (-1, 1):
        fx = cx + side * w * 0.3
        draw.ellipse([fx - 4 * SCALE, cy - 9 * SCALE, fx + 4 * SCALE, cy + 1 * SCALE], fill=GOLD)
        draw.ellipse([fx - 10 * SCALE, cy - 3 * SCALE, fx - 2 * SCALE, cy + 3 * SCALE], fill=GOLD)
        draw.ellipse([fx + 2 * SCALE, cy - 3 * SCALE, fx + 10 * SCALE, cy + 3 * SCALE], fill=GOLD)
        draw.rectangle([fx - 1.5 * SCALE, cy, fx + 1.5 * SCALE, cy + 10 * SCALE], fill=GOLD)

    return _finish(image, (128, 64), 24)


def _shield(field):
    """A round shield's face: `field(draw, size)` paints its arms; an iron
    rim studded round it."""
    size = 64 * SCALE
    image = Image.new("RGB", (size, size), IRON)
    arms = Image.new("RGB", (size, size), IRON)
    field(ImageDraw.Draw(arms), size)
    # Old paint: worn, knocked.
    rng = np.random.default_rng(len(str(field)))
    pixels = np.asarray(arms, dtype=np.float64) * (0.82 + 0.18 * rng.random((size, size)))[:, :, None]
    arms = Image.fromarray(np.clip(pixels, 0, 255).astype(np.uint8), "RGB")
    mask = Image.new("L", (size, size), 0)
    rim = 5 * SCALE
    ImageDraw.Draw(mask).ellipse([rim, rim, size - rim, size - rim], fill=255)
    image.paste(arms, (0, 0), mask)
    draw = ImageDraw.Draw(image)

    for i in range(12):
        a = i * math.tau / 12
        x, y = size / 2 + math.cos(a) * (size / 2 - rim / 2), size / 2 + math.sin(a) * (size / 2 - rim / 2)
        draw.ellipse([x - 1.5 * SCALE, y - 1.5 * SCALE, x + 1.5 * SCALE, y + 1.5 * SCALE], fill=(120, 116, 108))

    return _finish(image, (64, 64), 16)


def shield_1():
    """Quartered, crimson and gold."""
    def field(draw, s):
        draw.rectangle([0, 0, s, s], fill=GOLD)
        draw.rectangle([0, 0, s / 2, s / 2], fill=CRIMSON)
        draw.rectangle([s / 2, s / 2, s, s], fill=CRIMSON)

    return _shield(field)


def shield_2():
    """Blue, a bone chevron."""
    def field(draw, s):
        draw.rectangle([0, 0, s, s], fill=(34, 50, 110))
        draw.polygon([(0, s * 0.78), (s / 2, s * 0.3), (s, s * 0.78), (s, s * 0.98), (s / 2, s * 0.5), (0, s * 0.98)], fill=BONE)

    return _shield(field)


def shield_3():
    """Black, a gold cross."""
    def field(draw, s):
        draw.rectangle([0, 0, s, s], fill=(26, 24, 24))
        draw.rectangle([s * 0.42, 0, s * 0.58, s], fill=GOLD)
        draw.rectangle([0, s * 0.42, s, s * 0.58], fill=GOLD)

    return _shield(field)


def moon():
    """The full moon's face as seen from the garrison: grey highlands, the
    dark maria where they lie on the near side, a few bright rayed craters,
    darker at its limb; clear outside its disc."""
    size = 128 * SCALE
    c = size / 2.0
    yy, xx = np.mgrid[0:size, 0:size]
    r = np.hypot(xx + 0.5 - c, yy + 0.5 - c) / c
    rng = np.random.default_rng(29)
    # Highlands: pale grey, mottled.
    field = np.zeros((size, size))

    for octave, scale in ((1.0, 12), (0.5, 28), (0.25, 64)):
        cells = rng.random((scale + 1, scale + 1))
        field += octave * np.asarray(Image.fromarray((cells * 255).astype(np.uint8), "L").resize((size, size), Image.Resampling.BICUBIC), dtype=np.float64) / 255.0

    field /= 1.75
    tone = 0.72 + 0.16 * (field - 0.5)
    # The maria, placed as the near side's (Imbrium and Procellarum spilling
    # into each other on the west, Serenitatis, Tranquillitatis, Fecunditatis
    # and Nectaris down the east, Crisium alone at the edge, Nubium low):
    # overlapping blobs on warped ground, so their shores wander.
    warp_x = (field - 0.5) * 0.28
    cells = rng.random((9, 9))
    warp_y = (np.asarray(Image.fromarray((cells * 255).astype(np.uint8), "L").resize((size, size), Image.Resampling.BICUBIC), dtype=np.float64) / 255.0 - 0.5) * 0.28
    u = (xx + 0.5 - c) / c + warp_x
    v = (yy + 0.5 - c) / c + warp_y
    sea = np.zeros((size, size))

    for mx, my, sx, sy in ((-0.3, -0.34, 0.26, 0.2), (-0.55, -0.05, 0.2, 0.34), (-0.42, 0.22, 0.16, 0.14), (0.1, -0.3, 0.15, 0.13),
                           (0.22, -0.06, 0.18, 0.14), (0.38, 0.14, 0.12, 0.13), (0.25, 0.28, 0.1, 0.09), (0.6, -0.16, 0.09, 0.11),
                           (-0.12, 0.3, 0.14, 0.1), (-0.05, -0.02, 0.1, 0.08)):
        d = np.hypot((u - mx) / sx, (v - my) / sy)
        sea = np.maximum(sea, np.clip((1.0 - d) / 0.35, 0.0, 1.0))

    tone = tone * (1.0 - 0.36 * sea) + 0.03 * sea * (field - 0.5)

    # Rayed craters (Tycho low, Copernicus, Kepler): a bright ring, fine rays
    # broken by the ground.
    for cx, cy, cr, reach in ((-0.08, 0.62, 0.03, 0.45), (-0.3, -0.06, 0.028, 0.28), (-0.52, -0.02, 0.018, 0.2)):
        dx, dy = (xx + 0.5 - c) / c - cx, (yy + 0.5 - c) / c - cy
        d = np.hypot(dx, dy)
        tone += 0.2 * np.exp(-((d - cr) / (cr * 0.45)) ** 2)
        angle = np.arctan2(dy, dx)
        rays = np.clip(np.cos(angle * 17.0 + cx * 20.0) * np.cos(angle * 5.0 + cy * 9.0), 0.0, 1.0) ** 3
        tone += 0.07 * rays * np.exp(-d / reach) * (d > cr) * (field > 0.45)

    tone *= 1.0 - 0.28 * r ** 3
    grey = np.clip(tone, 0.0, 1.0)[:, :, None] * np.array([232.0, 236.0, 244.0])[None, None, :]
    image = Image.fromarray(grey.astype(np.uint8), "RGB")
    mask = Image.fromarray(((r <= 0.985) * 255).astype(np.uint8), "L")
    return _finish(image, (128, 128), 24, mask)


PAINTINGS = {"moon": moon, "banner": banner, "rose_window": rose_window, "altar_frontal": altar_frontal,
             "shield_1": shield_1, "shield_2": shield_2, "shield_3": shield_3}


def main(argv):
    OUT.mkdir(parents=True, exist_ok=True)

    for name in argv or sorted(PAINTINGS):
        path = OUT / (name + ".png")
        PAINTINGS[name]().save(path)
        print("%-14s -> %s" % (name, path.relative_to(ROOT)))

    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
