#!/usr/bin/env python3
"""Textures we paint ourselves (no photo in them, so they are committed):
the garrison's banner, the chapel's rose window, altar frontal and runner,
the mess hall's shields, the moon, and the nature round the walls: leaves for a
tree's crown and a shrub, a yew's needles, bare twigs, grass, broad weeds,
reeds, ivy, and bark.

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

import azulejo

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


# Nature: leaves, needles, twigs, grass, weeds, reeds, ivy (cut out), bark

def _tinted(colour, bright):
    return tuple(int(max(0, min(255, c * bright))) for c in colour)


def _leaf(draw, mask, x, y, length, width, angle, fill, edge, vein=None):
    """A pointed leaf from its stalk at (x, y), `length` along `angle`."""
    ca, sa = math.cos(angle), math.sin(angle)
    points = []

    for i in range(11):
        t = i / 10.0
        points.append((t * length, width * 0.5 * math.sin(math.pi * t) ** 0.8 * (1.0 - 0.25 * t)))

    outline = points + [(px, -py) for px, py in reversed(points[1:-1])]
    placed = [(x + px * ca - py * sa, y + px * sa + py * ca) for px, py in outline]
    draw.polygon(placed, fill=fill, outline=edge)
    mask.polygon(placed, fill=255)

    if vein is not None:
        draw.line([(x, y), (x + length * 0.85 * ca, y + length * 0.85 * sa)], fill=vein, width=max(1, int(width * 0.08)))


def _blob_points(rng, centres, count):
    """`count` points spread through overlapping round blobs [(x, y, r)],
    thicker toward each middle."""
    areas = np.array([r * r for _, _, r in centres], dtype=np.float64)
    picks = rng.choice(len(centres), size=count, p=areas / areas.sum())
    out = []

    for k in picks:
        cx, cy, r = centres[k]
        a = rng.random() * math.tau
        d = r * math.sqrt(rng.random())
        out.append((cx + math.cos(a) * d, cy + math.sin(a) * d))

    return out


def _crown(size, final, leaves, leaf_len, leaf_w, palette, blobs, seed, twigs=True, fruit=None, heart=0.0):
    """Leaves in lumpy blobs, lit from above: the lower and inner ones darker,
    drawn first; the outer and upper ones lighter, over them; a few twigs
    showing through the gaps; `fruit` (count, radius, colour) among them;
    `heart` (a share of the size) a dense shadowed middle under them all."""
    rng = np.random.default_rng(seed)
    image = Image.new("RGB", (size, size), (20, 26, 16))
    mask_image = Image.new("L", (size, size), 0)
    draw = ImageDraw.Draw(image)
    mask = ImageDraw.Draw(mask_image)
    c = size / 2.0

    if heart > 0.0:
        r = size * heart
        draw.ellipse([c - r, c - r, c + r, c + r], fill=_tinted(palette[0], 0.7))
        mask.ellipse([c - r, c - r, c + r, c + r], fill=255)

    if twigs:
        for cx, cy, _ in blobs:
            draw.line([(c, size * 0.98), (cx, cy)], fill=(40, 32, 24), width=int(size * 0.012))
            mask.line([(c, size * 0.98), (cx, cy)], fill=255, width=int(size * 0.012))

    placed = []

    for x, y in _blob_points(rng, blobs, leaves):
        up = (c - y) / c
        out = math.hypot(x - c, y - c) / c
        bright = 0.62 + 0.28 * up + 0.22 * out + rng.uniform(-0.12, 0.12)
        placed.append((bright, x, y))

    placed.sort()

    for bright, x, y in placed:
        colour = palette[int(rng.integers(len(palette)))]
        outward = math.atan2(y - c, x - c) + rng.uniform(-1.1, 1.1)
        length = leaf_len * rng.uniform(0.8, 1.2)
        _leaf(draw, mask, x, y, length, leaf_w * rng.uniform(0.8, 1.2), outward, _tinted(colour, bright), _tinted(colour, bright * 0.7), _tinted(colour, bright * 1.15))

    if fruit is not None:
        count, radius, colour = fruit

        for x, y in _blob_points(rng, blobs, count):
            r = radius * rng.uniform(0.85, 1.15)
            draw.ellipse([x - r, y - r, x + r, y + r], fill=_tinted(colour, rng.uniform(0.8, 1.0)), outline=_tinted(colour, 0.6))
            draw.ellipse([x - r * 0.55, y - r * 0.6, x - r * 0.1, y - r * 0.15], fill=_tinted(colour, 1.2))
            mask.ellipse([x - r, y - r, x + r, y + r], fill=255)

    return _finish(image, (final, final), 32, mask_image)


OAK = [(34, 52, 26), (44, 66, 30), (56, 80, 36), (70, 92, 40), (84, 104, 48), (104, 110, 50)]


def leaf_crown():
    """A tree's leaves in a lumpy spray (a card of its crown): oak greens,
    a few turning."""
    size = 256 * SCALE
    rng = np.random.default_rng(41)
    blobs = [(size * 0.5, size * 0.52, size * 0.26)]

    for k in range(8):
        a = k * math.tau / 8 + rng.uniform(-0.3, 0.3)
        d = size * rng.uniform(0.2, 0.3)
        blobs.append((size * 0.5 + math.cos(a) * d, size * 0.5 + math.sin(a) * d, size * rng.uniform(0.09, 0.16)))

    return _crown(size, 256, 1100, size * 0.05, size * 0.022, OAK, blobs, 43)


def leaf_shrub():
    """A shrub's leaves, smaller and thicker together, in a rounder spray."""
    size = 128 * SCALE
    rng = np.random.default_rng(51)
    blobs = [(size * 0.5, size * 0.55, size * 0.28)]

    for k in range(6):
        a = k * math.tau / 6 + rng.uniform(-0.3, 0.3)
        blobs.append((size * 0.5 + math.cos(a) * size * 0.22, size * 0.52 + math.sin(a) * size * 0.2, size * rng.uniform(0.1, 0.16)))

    return _crown(size, 128, 700, size * 0.075, size * 0.035, [(38, 60, 28), (50, 74, 32), (62, 88, 38), (78, 100, 44), (60, 70, 30)], blobs, 53, twigs=False)


def yew():
    """A yew's needles in flat sprays: near-black greens, a little lighter at
    their tips."""
    size = 256 * SCALE
    rng = np.random.default_rng(61)
    image = Image.new("RGB", (size, size), (16, 22, 16))
    mask_image = Image.new("L", (size, size), 0)
    draw = ImageDraw.Draw(image)
    mask = ImageDraw.Draw(mask_image)
    c = size / 2.0
    blobs = [(c, c * 1.05, size * 0.3)] + [(c + math.cos(a) * size * 0.25, c + math.sin(a) * size * 0.22, size * 0.13) for a in np.linspace(0, math.tau, 7, endpoint=False)]
    palette = [(20, 34, 22), (26, 42, 26), (32, 50, 30), (40, 60, 34), (52, 72, 40)]
    sprays = sorted(((c - y) / c + rng.uniform(-0.3, 0.3), x, y) for x, y in _blob_points(rng, blobs, 230))

    for up, x, y in sprays:
        # (Outward at the rim, any way at all in the thick of it.)
        rim = math.hypot(x - c, y - c) / (size * 0.35)
        angle = math.atan2(y - c, x - c) + rng.uniform(-0.8, 0.8) if rng.random() < rim else rng.uniform(0.0, math.tau)
        length = size * rng.uniform(0.06, 0.11)
        bright = 0.8 + 0.3 * up
        colour = palette[int(rng.integers(len(palette)))]
        ca, sa = math.cos(angle), math.sin(angle)
        end = (x + ca * length, y + sa * length)
        draw.line([(x, y), end], fill=_tinted((40, 34, 24), bright), width=int(size * 0.006))
        mask.line([(x, y), end], fill=255, width=int(size * 0.006))

        for t in np.linspace(0.1, 1.0, 9):
            px, py = x + ca * length * t, y + sa * length * t
            needle = size * 0.022 * (1.1 - 0.4 * t)

            for side in (-1.0, 1.0):
                na = angle + side * 1.0
                tip = (px + math.cos(na) * needle, py + math.sin(na) * needle)
                shade = _tinted(colour, bright * (0.9 + 0.3 * t))
                draw.line([(px, py), tip], fill=shade, width=int(size * 0.007))
                mask.line([(px, py), tip], fill=255, width=int(size * 0.007))

    return _finish(image, (256, 256), 24, mask_image)


def twigs():
    """Bare twigs against the sky (a dead tree's crown): branching from the
    bottom, finer as they go."""
    size = 256 * SCALE
    rng = np.random.default_rng(71)
    image = Image.new("RGB", (size, size), (30, 26, 22))
    mask_image = Image.new("L", (size, size), 0)
    draw = ImageDraw.Draw(image)
    mask = ImageDraw.Draw(mask_image)

    def grow(x, y, angle, length, width, depth):
        end = (x + math.cos(angle) * length, y + math.sin(angle) * length)
        shade = _tinted((58, 50, 42), 0.8 + 0.3 * rng.random())
        draw.line([(x, y), end], fill=shade, width=int(width))
        mask.line([(x, y), end], fill=255, width=int(width))

        if depth == 0:
            return

        for _ in range(2 + int(rng.random() < 0.45)):
            grow(end[0], end[1], angle + rng.uniform(-0.75, 0.75), length * rng.uniform(0.62, 0.8), max(width * 0.7, 7.0), depth - 1)

    for start in (0.35, 0.5, 0.65):
        grow(size * start, size, -math.pi / 2 + rng.uniform(-0.5, 0.5), size * 0.24, size * 0.03, 6)

    return _finish(image, (256, 256), 16, mask_image)


def grass():
    """A tuft of grass: blades from its root, bending, green and some straw,
    darker at the root."""
    w = h = 128 * SCALE
    rng = np.random.default_rng(81)
    image = Image.new("RGB", (w, h), (30, 40, 20))
    mask_image = Image.new("L", (w, h), 0)
    draw = ImageDraw.Draw(image)
    mask = ImageDraw.Draw(mask_image)
    palette = [(56, 80, 34), (70, 94, 40), (84, 104, 46), (102, 112, 54), (122, 118, 70)]

    for _ in range(80):
        base = w * (0.5 + rng.normal(0.0, 0.14))
        height = h * rng.uniform(0.4, 0.95)
        lean = rng.uniform(-0.45, 0.45) * height
        colour = palette[int(rng.integers(len(palette)))]
        root_w = w * rng.uniform(0.02, 0.03)
        left, right = [], []

        for i in range(9):
            t = i / 8.0
            x = base + lean * t * t
            y = h - height * t
            half = root_w * (1.0 - 0.8 * t) * 0.5
            left.append((x - half, y))
            right.append((x + half, y))

        draw.polygon(left + right[::-1], fill=_tinted(colour, 0.7 + 0.5 * rng.random()))
        mask.polygon(left + right[::-1], fill=255)

    return _finish(image, (128, 128), 24, mask_image)


def weed_broad():
    """Broad weeds (dock and nettle): big leaves from the root, toothed,
    veined, and a stalk or two gone to seed."""
    size = 128 * SCALE
    rng = np.random.default_rng(91)
    image = Image.new("RGB", (size, size), (26, 36, 18))
    mask_image = Image.new("L", (size, size), 0)
    draw = ImageDraw.Draw(image)
    mask = ImageDraw.Draw(mask_image)
    root = (size * 0.5, size * 0.97)

    for _ in range(3):
        top = (size * rng.uniform(0.3, 0.7), size * rng.uniform(0.08, 0.25))
        draw.line([root, top], fill=(70, 62, 36), width=int(size * 0.012))
        mask.line([root, top], fill=255, width=int(size * 0.012))

        for k in range(6):
            t = 0.6 + 0.4 * k / 5.0
            px, py = root[0] + (top[0] - root[0]) * t, root[1] + (top[1] - root[1]) * t
            r = size * 0.018
            draw.ellipse([px - r, py - r, px + r, py + r], fill=(96, 78, 44))
            mask.ellipse([px - r, py - r, px + r, py + r], fill=255)

    palette = [(52, 78, 32), (62, 90, 36), (74, 100, 42), (58, 84, 30)]

    # Broad dock leaves, rounded, the outer ones lolling low; smaller
    # toothed nettle leaves up the middle.
    for k in range(8):
        angle = -math.pi / 2 + (k / 7.0 - 0.5) * 2.9 + rng.uniform(-0.15, 0.15)
        colour = palette[int(rng.integers(len(palette)))]
        length = size * rng.uniform(0.32, 0.44)
        width = length * rng.uniform(0.5, 0.62)
        bright = 0.7 + 0.25 * (1.0 - abs(k / 7.0 - 0.5) * 2.0) + rng.uniform(-0.1, 0.1)
        _leaf(draw, mask, root[0], root[1], length, width, angle, _tinted(colour, bright), _tinted(colour, bright * 0.65), _tinted(colour, bright * 1.25))

    for k in range(12):
        t = 0.25 + 0.055 * k
        stalk = (root[0] + (0.08 if k % 2 else -0.08) * size * (1.0 - t), root[1] - size * t)
        side = 1.0 if k % 2 else -1.0
        colour = palette[int(rng.integers(len(palette)))]
        bright = 0.85 + 0.3 * rng.random()
        _leaf(draw, mask, stalk[0], stalk[1], size * rng.uniform(0.1, 0.14), size * 0.055, -math.pi / 2 + side * rng.uniform(0.7, 1.1),
              _tinted(colour, bright), _tinted(colour, bright * 0.65), _tinted(colour, bright * 1.2))

    return _finish(image, (128, 128), 24, mask_image)


def reeds():
    """Reeds by the water: tall narrow blades leaning a little, a few bulrush
    heads on their stalks."""
    w, h = 128 * SCALE, 256 * SCALE
    rng = np.random.default_rng(101)
    image = Image.new("RGB", (w, h), (40, 44, 24))
    mask_image = Image.new("L", (w, h), 0)
    draw = ImageDraw.Draw(image)
    mask = ImageDraw.Draw(mask_image)
    palette = [(78, 92, 44), (92, 104, 50), (108, 110, 58), (130, 122, 72)]

    for _ in range(4):
        x = w * rng.uniform(0.25, 0.75)
        top = h * rng.uniform(0.08, 0.3)
        draw.line([(x, h), (x + rng.uniform(-20, 20), top)], fill=(96, 96, 52), width=int(w * 0.02))
        mask.line([(x, h), (x, top)], fill=255, width=int(w * 0.02))
        draw.ellipse([x - w * 0.045, top - h * 0.01, x + w * 0.045, top + h * 0.11], fill=(84, 56, 32))
        mask.ellipse([x - w * 0.045, top - h * 0.01, x + w * 0.045, top + h * 0.11], fill=255)

    for _ in range(42):
        base = w * (0.5 + rng.normal(0.0, 0.16))
        height = h * rng.uniform(0.5, 1.0)
        lean = rng.uniform(-0.25, 0.25) * height
        colour = palette[int(rng.integers(len(palette)))]
        root_w = w * rng.uniform(0.03, 0.045)
        left, right = [], []

        for i in range(9):
            t = i / 8.0
            x = base + lean * t * t
            y = h - height * t
            half = root_w * (1.0 - 0.85 * t) * 0.5
            left.append((x - half, y))
            right.append((x + half, y))

        draw.polygon(left + right[::-1], fill=_tinted(colour, 0.7 + 0.45 * rng.random()))
        mask.polygon(left + right[::-1], fill=255)

    return _finish(image, (128, 256), 24, mask_image)


def ivy():
    """Ivy on stone: stems wandering up, five-lobed leaves along them in
    dark glossy greens, pale-veined; gaps where the wall shows."""
    size = 256 * SCALE
    rng = np.random.default_rng(111)
    image = Image.new("RGB", (size, size), (22, 30, 18))
    mask_image = Image.new("L", (size, size), 0)
    draw = ImageDraw.Draw(image)
    mask = ImageDraw.Draw(mask_image)
    palette = [(26, 50, 26), (32, 58, 28), (40, 68, 32), (50, 80, 38), (36, 54, 26)]

    for k in range(13):
        # Stems from the foot, most toward the middle; each gives out
        # somewhere up the wall, the outer ones soonest (ragged, creeping
        # up, never a rectangle).
        x = size * (0.5 + 0.34 * math.sin(k * 2.1) + rng.uniform(-0.08, 0.08))
        y = size * 1.02
        heading = -math.pi / 2 + rng.uniform(-0.4, 0.4)
        side = 1.0
        reach = size * (1.02 - rng.uniform(0.35, 1.0) * (1.0 - 0.9 * abs(x / size - 0.5)))

        while y > max(reach, -size * 0.05):
            step = size * 0.03
            heading += rng.uniform(-0.35, 0.35)
            heading = max(-math.pi * 0.85, min(-math.pi * 0.15, heading))
            nx, ny = x + math.cos(heading) * step, y + math.sin(heading) * step
            draw.line([(x, y), (nx, ny)], fill=(62, 48, 32), width=int(size * 0.007))
            mask.line([(x, y), (nx, ny)], fill=255, width=int(size * 0.007))
            x, y = nx, ny
            side = -side

            climb = 1.0 - y / size

            if rng.random() < 0.8 * (1.0 - 0.45 * climb):
                leaf = size * rng.uniform(0.028, 0.045) * (1.0 - 0.3 * climb)
                lx, ly = x + math.cos(heading + side * 1.4) * leaf * 0.8, y + math.sin(heading + side * 1.4) * leaf * 0.8
                colour = palette[int(rng.integers(len(palette)))]
                bright = 0.75 + 0.45 * rng.random()
                points = []

                for i in range(20):
                    a = i / 20.0 * math.tau
                    r = leaf * (0.62 + 0.38 * abs(math.cos(a * 2.5)))
                    points.append((lx + math.cos(a - math.pi / 2 + side * 0.3) * r, ly + math.sin(a - math.pi / 2 + side * 0.3) * r))

                draw.polygon(points, fill=_tinted(colour, bright), outline=_tinted(colour, bright * 0.6))
                mask.polygon(points, fill=255)
                draw.line([(lx, ly + leaf * 0.5), (lx, ly - leaf * 0.5)], fill=_tinted((120, 140, 96), bright * 0.8), width=max(1, int(size * 0.003)))

    return _finish(image, (256, 256), 24, mask_image)


def bark():
    """Bark that tiles both ways: furrows running up the trunk, ridges
    between them, fine grain; grey-browns."""
    size = 256
    rng = np.random.default_rng(121)
    y, x = np.mgrid[0:size * SCALE, 0:size * SCALE] / float(size * SCALE)
    field = np.zeros_like(x)

    # Furrows: waves round the trunk (many), slow ones up it (few), each a
    # whole number of times across so it tiles.
    for _ in range(26):
        fx = int(rng.integers(6, 28))
        fy = int(rng.integers(0, 4))
        field += rng.uniform(0.3, 1.0) / (1.0 + fx * 0.05) * np.cos(math.tau * (fx * x + fy * y) + rng.uniform(0, math.tau))

    for _ in range(14):
        fx = int(rng.integers(20, 60))
        fy = int(rng.integers(2, 10))
        field += rng.uniform(0.1, 0.3) * np.cos(math.tau * (fx * x + fy * y) + rng.uniform(0, math.tau))

    field = (field - field.min()) / (field.max() - field.min())
    tone = np.where(field < 0.34, 0.35 + field * 0.6, 0.55 + (field - 0.34) * 0.75)
    pixels = tone[:, :, None] * np.array([150.0, 132.0, 112.0])[None, None, :]
    image = Image.fromarray(np.clip(pixels, 0, 255).astype(np.uint8), "RGB")
    return image.resize((size, size), Image.Resampling.BOX).quantize(colors=24, dither=Image.Dither.NONE).convert("RGB")


def bat():
    """A bat against the night sky, two frames side by side (its wings up, its
    wings down): a black body, ears, membranes between long fingers."""
    w, h = 128 * SCALE, 64 * SCALE
    image = Image.new("RGB", (w, h), (14, 12, 14))
    mask_image = Image.new("L", (w, h), 0)
    draw = ImageDraw.Draw(image)
    mask = ImageDraw.Draw(mask_image)
    frame = w // 2

    for k, lift in enumerate((-0.55, 0.45)):
        cx, cy = frame * k + frame / 2.0, h * 0.55
        body = [(cx - 5 * SCALE, cy - 9 * SCALE), (cx + 5 * SCALE, cy - 9 * SCALE), (cx + 4 * SCALE, cy + 11 * SCALE), (cx - 4 * SCALE, cy + 11 * SCALE)]
        ears = [(cx - 5 * SCALE, cy - 9 * SCALE), (cx - 4 * SCALE, cy - 15 * SCALE), (cx - 1 * SCALE, cy - 9 * SCALE), (cx + 1 * SCALE, cy - 9 * SCALE),
                (cx + 4 * SCALE, cy - 15 * SCALE), (cx + 5 * SCALE, cy - 9 * SCALE)]

        for side in (-1.0, 1.0):
            # The arm out to the wrist, three fingers from it; the membrane
            # scalloped between their tips and the body.
            wrist = (cx + side * 18 * SCALE, cy - lift * 14 * SCALE - 4 * SCALE)
            tips = [(cx + side * 29 * SCALE, cy - lift * 22 * SCALE - 2 * SCALE), (cx + side * 30 * SCALE, cy - lift * 8 * SCALE + 6 * SCALE),
                    (cx + side * 22 * SCALE, cy - lift * 2 * SCALE + 12 * SCALE)]
            web = [(cx + side * 4 * SCALE, cy - 6 * SCALE), wrist, tips[0]]

            for a, b in zip(tips, tips[1:] + [(cx + side * 5 * SCALE, cy + 9 * SCALE)]):
                mid = ((a[0] + b[0]) / 2.0 - side * 2 * SCALE, (a[1] + b[1]) / 2.0 - 2 * SCALE)
                web += [mid, b]

            draw.polygon(web, fill=(30, 26, 30))
            mask.polygon(web, fill=255)

            for tip in tips:
                draw.line([wrist, tip], fill=(10, 8, 10), width=SCALE)
                mask.line([wrist, tip], fill=255, width=SCALE)

            draw.line([(cx, cy - 6 * SCALE), wrist], fill=(10, 8, 10), width=2 * SCALE)
            mask.line([(cx, cy - 6 * SCALE), wrist], fill=255, width=2 * SCALE)

        draw.polygon(body, fill=(20, 16, 18))
        mask.polygon(body, fill=255)
        draw.polygon(ears, fill=(20, 16, 18))
        mask.polygon(ears, fill=255)

    return _finish(image, (128, 64), 8, mask_image)


# The ground lived on: decals laid on the floors (garrison_markers.decals).
# Each fades out well inside its square; soot and dirt in a few steps of
# alpha (a PS2's soft edge), straw and leaves cut clean.

ALPHA_STEPS = [0, 72, 140, 200, 255]


def _noise(size, rng, octaves=4, base=4):
    """A soft field in 0..1: random grids from coarse to fine, each smoothed
    up to `size` and weighted half the one before."""
    field = np.zeros((size, size))
    weight, total = 1.0, 0.0

    for o in range(octaves):
        cells = base * 2 ** o
        grid = Image.fromarray((rng.random((cells, cells)) * 255).astype(np.uint8), "L")
        field += weight * np.asarray(grid.resize((size, size), Image.Resampling.BICUBIC), dtype=np.float64) / 255.0
        total += weight
        weight *= 0.5

    field /= total
    return (field - field.min()) / max(field.max() - field.min(), 1e-6)


def _patch(size, rng, reach, rag, lumps=4):
    """How thick a patch lies (0..1) at each point: lumps round the middle,
    their edges eaten into by noise (`rag`), nothing past `reach` of the
    half-width."""
    y, x = np.mgrid[0:size, 0:size] / float(size) - 0.5
    thick = np.zeros((size, size))

    for _ in range(lumps):
        cx, cy = rng.uniform(-0.12, 0.12, 2)
        r = rng.uniform(0.22, 0.34) * reach / 0.46
        thick = np.maximum(thick, 1.0 - np.hypot(x - cx, y - cy) / r)

    # Eaten into, never grown out of: no islands off the patch.
    thick = np.where(thick > 0.0, thick - rag * (_noise(size, rng) - 0.5), 0.0)
    thick[np.hypot(x, y) > reach] = 0.0
    return np.clip(thick, 0.0, 1.0)


def _stepped(thick, size):
    """Its thickness shrunk to `size` and stepped to ALPHA_STEPS."""
    small = np.asarray(Image.fromarray((thick * 255).astype(np.uint8), "L").resize((size, size), Image.Resampling.BOX), dtype=np.float64)
    steps = np.array(ALPHA_STEPS, dtype=np.float64)
    picked = steps[np.abs(small[:, :, None] - steps[None, None, :]).argmin(axis=2)]
    picked[:4], picked[-4:], picked[:, :4], picked[:, -4:] = 0, 0, 0, 0
    return Image.fromarray(picked.astype(np.uint8), "L")


def _soft_finish(pixels, thick, size, colours):
    image = Image.fromarray(np.clip(pixels, 0, 255).astype(np.uint8), "RGB").resize((size, size), Image.Resampling.BOX)
    out = image.quantize(colors=colours, dither=Image.Dither.NONE).convert("RGBA")
    out.putalpha(_stepped(thick, size))
    return out


def decal_soot():
    """Soot and ash under a brazier: grey ash fallen through its grate in the
    middle, black soot round it thinning out in ragged steps, charcoal
    crumbs."""
    size = 128
    big = size * SCALE
    rng = np.random.default_rng(311)
    thick = _patch(big, rng, 0.46, 0.55, lumps=3) ** 0.8
    grain = _noise(big, rng, octaves=5, base=8)
    tone = 16.0 + 14.0 * grain + 34.0 * np.clip((thick - 0.72) / 0.28, 0.0, 1.0) * (0.6 + 0.4 * grain)
    pixels = np.stack([tone * 1.05, tone, tone * 0.95], axis=2)
    ash = (_noise(big, rng, octaves=3, base=16) > 0.8) & (thick > 0.3)
    pixels[ash] = [70.0, 67.0, 63.0]
    crumbs = rng.random((big, big)) > 0.996
    pixels[crumbs] = [6.0, 5.0, 5.0]
    # (Never quite solid: the stones show through it.)
    return _soft_finish(pixels, thick * 0.78, size, 12)


def decal_dirt():
    """Trodden dirt over the stones: browns in blotches, darker wet hollows,
    pale dust; its edge ragged, fading in steps."""
    size = 256
    big = size * SCALE
    rng = np.random.default_rng(422)
    thick = _patch(big, rng, 0.47, 0.9, lumps=5) ** 0.7
    grain = _noise(big, rng, octaves=5, base=6)
    brown = np.array([88.0, 66.0, 44.0])
    pixels = brown[None, None, :] * (0.72 + 0.5 * grain)[:, :, None]
    wet = _noise(big, rng, octaves=3, base=5) > 0.7
    pixels[wet] *= 0.8
    dust = _noise(big, rng, octaves=4, base=12) > 0.8
    pixels[dust] = pixels[dust] * 0.5 + np.array([128.0, 110.0, 82.0]) * 0.5
    return _soft_finish(pixels, thick * 0.9, size, 16)


def decal_straw():
    """Straw spilled on the ground: pale gold strands every way, thickest in
    the middle and thinning to single straws."""
    size = 256
    big = size * SCALE
    rng = np.random.default_rng(533)
    image = Image.new("RGB", (big, big), (160, 130, 70))
    mask_image = Image.new("L", (big, big), 0)
    draw = ImageDraw.Draw(image)
    mask = ImageDraw.Draw(mask_image)
    golds = [(196, 164, 92), (176, 146, 78), (214, 188, 116), (150, 120, 64), (186, 150, 70)]

    for _ in range(520):
        r = abs(rng.normal(0.0, 0.17)) * big

        if r > big * 0.4:
            continue

        a = rng.random() * math.tau
        x, y = big / 2 + math.cos(a) * r, big / 2 + math.sin(a) * r
        length = rng.uniform(14, 44) * SCALE
        turn = rng.random() * math.tau
        bend = rng.uniform(-0.25, 0.25)
        mid = (x + math.cos(turn) * length * 0.5 + math.cos(turn + math.pi / 2) * length * bend * 0.3,
               y + math.sin(turn) * length * 0.5 + math.sin(turn + math.pi / 2) * length * bend * 0.3)
        end = (x + math.cos(turn + bend) * length, y + math.sin(turn + bend) * length)
        width = int(rng.integers(1, 3)) * SCALE
        colour = golds[int(rng.integers(len(golds)))]
        draw.line([(x, y), mid, end], fill=colour, width=width)
        mask.line([(x, y), mid, end], fill=255, width=width)

    edge = int(big * 0.03)
    mask.rectangle([0, 0, big, edge], fill=0)
    mask.rectangle([0, big - edge, big, big], fill=0)
    mask.rectangle([0, 0, edge, big], fill=0)
    mask.rectangle([big - edge, 0, big, big], fill=0)
    return _finish(image, (size, size), 12, mask_image)


def decal_leaves():
    """Fallen leaves blown together: browns, rust, ochre and dry olive, each
    with its rib, scattered thick in the middle and few at the edges."""
    size = 256
    big = size * SCALE
    rng = np.random.default_rng(644)
    image = Image.new("RGB", (big, big), (90, 60, 30))
    mask_image = Image.new("L", (big, big), 0)
    draw = ImageDraw.Draw(image)
    mask = ImageDraw.Draw(mask_image)
    autumn = [(120, 72, 34), (146, 92, 40), (98, 60, 30), (160, 110, 50), (110, 90, 40), (80, 52, 28), (134, 58, 30), (170, 124, 58)]

    for _ in range(170):
        r = abs(rng.normal(0.0, 0.16)) * big

        if r > big * 0.38:
            continue

        a = rng.random() * math.tau
        x, y = big / 2 + math.cos(a) * r, big / 2 + math.sin(a) * r
        length = rng.uniform(9, 17) * SCALE
        fill = _tinted(autumn[int(rng.integers(len(autumn)))], rng.uniform(0.8, 1.1))
        _leaf(draw, mask, x, y, length, length * rng.uniform(0.45, 0.65), rng.random() * math.tau, fill, _tinted(fill, 0.7), _tinted(fill, 0.6))

    return _finish(image, (size, size), 20, mask_image)


def carpet():
    """The chapel's runner, tiling both ways: a deep red weave (warp and weft
    threads), a lattice of darker diamonds with a gold knot at each crossing,
    worn paler in soft patches."""
    size = 128
    big = size * SCALE
    rng = np.random.default_rng(755)
    y, x = np.mgrid[0:big, 0:big] / float(big)
    # Threads: fine waves across and along, a whole number to the tile.
    weave = 0.5 + 0.25 * np.cos(math.tau * 64 * x) * np.cos(math.tau * 64 * y) + 0.1 * np.cos(math.tau * 128 * (x + y))
    # Diamonds: |x| + |y| in each of four cells to the tile, banded.
    cx = np.abs(((x * 4.0) % 1.0) - 0.5)
    cy = np.abs(((y * 4.0) % 1.0) - 0.5)
    diamond = cx + cy
    band = (np.abs(diamond - 0.36) < 0.035)
    knot = np.hypot(cx - 0.5, cy - 0.5) < 0.07
    # Wear: slow, tiling.
    wear = np.zeros_like(x)

    for _ in range(6):
        fx, fy = int(rng.integers(1, 4)), int(rng.integers(1, 4))
        wear += rng.uniform(0.3, 1.0) * np.cos(math.tau * (fx * x + fy * y) + rng.uniform(0, math.tau))

    wear = (wear - wear.min()) / (wear.max() - wear.min())
    red = np.array([112.0, 22.0, 20.0])
    pixels = red[None, None, :] * (0.78 + 0.35 * weave)[:, :, None]
    pixels[band] = np.array([62.0, 10.0, 12.0])
    pixels[knot] = np.array([176.0, 132.0, 58.0])
    pixels *= (0.92 + 0.22 * wear)[:, :, None]
    image = Image.fromarray(np.clip(pixels, 0, 255).astype(np.uint8), "RGB")
    return image.resize((size, size), Image.Resampling.BOX).quantize(colors=16, dither=Image.Dither.NONE).convert("RGB")


# The harbour's: wrought iron, a ship's ratlines, the rope coil's mask, salt
# on the quays; Mediterranean planting

IRON_LIT = (84, 80, 74)


def _canvas(w, h, ground=(30, 28, 26)):
    image = Image.new("RGB", (w, h), ground)
    mask_image = Image.new("L", (w, h), 0)
    return image, mask_image, ImageDraw.Draw(image), ImageDraw.Draw(mask_image)


def _bar(draw, mask, points, width, fill, lit=None):
    """A bar or a rope along `points`, lit along its top edge."""
    draw.line(points, fill=fill, width=width, joint="curve")
    mask.line(points, fill=255, width=width, joint="curve")

    if lit is not None:
        draw.line([(x, y - width * 0.3) for x, y in points], fill=lit, width=max(1, width // 3))


def iron_rail():
    """A balcony's wrought-iron rail, seen from the street: a handrail and a
    bottom rail, bars between, a band of C-scrolls back to back under the
    handrail (Porto's and Lisbon's balconies)."""
    w, h = 128 * SCALE, 64 * SCALE
    image, mask_image, draw, mask = _canvas(w, h)
    thick = int(SCALE * 2.5)
    _bar(draw, mask, [(0, h * 0.1), (w, h * 0.1)], int(SCALE * 4), IRON, IRON_LIT)
    _bar(draw, mask, [(0, h * 0.93), (w, h * 0.93)], int(SCALE * 3), IRON, IRON_LIT)
    _bar(draw, mask, [(0, h * 0.42), (w, h * 0.42)], int(SCALE * 2), IRON)

    for x in range(0, w + 1, 12 * SCALE):
        _bar(draw, mask, [(x, h * 0.1), (x, h * 0.93)], thick, IRON)

    # The scrolls: a C each way in every bay, between the handrail and the
    # middle rail.
    for x in range(0, w, 12 * SCALE):
        r = 4.2 * SCALE
        for cx, start, end in ((x + 6 * SCALE - r * 0.55, 60, 300), (x + 6 * SCALE + r * 0.55, 240, 480)):
            box = [cx - r, h * 0.26 - r, cx + r, h * 0.26 + r]
            draw.arc(box, start, end, fill=IRON, width=int(SCALE * 2))
            mask.arc(box, start, end, fill=255, width=int(SCALE * 2))

    return _finish(image, (128, 64), 8, mask_image)


def window_grille():
    """A window's iron grille: square bars, two cross bars, a small rosette
    where they meet, a frame round it."""
    w, h = 64 * SCALE, 128 * SCALE
    image, mask_image, draw, mask = _canvas(w, h)
    edge = int(SCALE * 3)
    draw.rectangle([0, 0, w - 1, h - 1], outline=IRON, width=edge)
    mask.rectangle([0, 0, w - 1, h - 1], outline=255, width=edge)
    rows = (h * 0.34, h * 0.67)

    for y in rows:
        _bar(draw, mask, [(0, y), (w, y)], int(SCALE * 2.5), IRON, IRON_LIT)

    for x in np.linspace(w / 5.0, w * 4 / 5.0, 4):
        _bar(draw, mask, [(x, 0), (x, h)], int(SCALE * 2.5), IRON)

        for y in rows:
            r = 3 * SCALE
            draw.ellipse([x - r, y - r, x + r, y + r], fill=IRON, outline=IRON_LIT)
            mask.ellipse([x - r, y - r, x + r, y + r], fill=255)

    return _finish(image, (64, 128), 8, mask_image)


SASH = (212, 206, 190)
SASH_LIT = (236, 232, 220)
SASH_SHADE = (160, 152, 138)


def casement():
    """A balcony door's glazing, as Porto's are painted (Teixeira's casa
    burguesa): a frame, a fixed fan light over a transom, two side-hung
    leaves meeting down the middle, each two panes across and four up, a
    panelled foot; the sashes painted pale, the panes clear (the glass behind
    shows through)."""
    w, h = 64 * SCALE, 128 * SCALE
    image, mask_image, draw, mask = _canvas(w, h, SASH)
    frame, bar = 4 * SCALE, 2 * SCALE
    transom, foot = h * 0.18, h * 0.8

    def solid(box, fill=SASH):
        draw.rectangle(box, fill=fill)
        mask.rectangle(box, fill=255)

    # The frame, the transom bar, the meeting stile; the foot's panels.
    for box in ([0, 0, w, frame], [0, 0, frame, h], [w - frame, 0, w, h], [0, transom - frame / 2, w, transom + frame / 2],
                [w / 2 - frame / 2, transom, w / 2 + frame / 2, h], [0, foot, w, h]):
        solid(box)

    for x0, x1 in ((frame, w / 2 - frame / 2), (w / 2 + frame / 2, w - frame)):
        inset = 3 * SCALE
        draw.rectangle([x0 + inset, foot + inset, x1 - inset, h - inset], outline=SASH_SHADE, width=SCALE)
        draw.line([(x0 + inset, h - inset), (x1 - inset, h - inset)], fill=SASH_LIT, width=SCALE)
        draw.line([(x1 - inset, foot + inset), (x1 - inset, h - inset)], fill=SASH_LIT, width=SCALE)

        # Each leaf's glazing bars: one up its middle, three across.
        mid = (x0 + x1) / 2.0
        solid([mid - bar / 2, transom, mid + bar / 2, foot])

        for k in (1, 2, 3):
            y = transom + (foot - transom) * k / 4.0
            solid([x0, y - bar / 2, x1, y + bar / 2])

    # The fan light: spokes from the transom's middle, a half ring.
    cx, cy = w / 2.0, transom
    radius = transom - frame / 2.0

    for angle in (30.0, 60.0, 90.0, 120.0, 150.0):
        a = math.radians(angle)
        _bar(draw, mask, [(cx, cy), (cx + math.cos(a) * radius, cy - math.sin(a) * radius)], bar, SASH)

    for r in (radius, radius * 0.3):
        draw.arc([cx - r, cy - r, cx + r, cy + r], 180, 360, fill=SASH, width=bar)
        mask.arc([cx - r, cy - r, cx + r, cy + r], 180, 360, fill=255, width=bar)

    draw.pieslice([cx - radius * 0.3, cy - radius * 0.3, cx + radius * 0.3, cy + radius * 0.3], 180, 360, fill=SASH)
    mask.pieslice([cx - radius * 0.3, cy - radius * 0.3, cx + radius * 0.3, cy + radius * 0.3], 180, 360, fill=255)
    # (The frame's inner edges caught by the light on one side.)
    draw.line([(frame, frame), (frame, h)], fill=SASH_SHADE, width=SCALE)
    draw.line([(w - frame, frame), (w - frame, h)], fill=SASH_LIT, width=SCALE)
    return _finish(image, (64, 128), 8, mask_image)


def sash():
    """A window over a sill: a frame, two sashes (the upper over the lower,
    a meeting rail between), three panes across and two up in each; painted
    pale, the panes clear."""
    w, h = 64 * SCALE, 128 * SCALE
    image, mask_image, draw, mask = _canvas(w, h, SASH)
    frame, bar, rail = 4 * SCALE, 2 * SCALE, 4 * SCALE

    def solid(box, fill=SASH):
        draw.rectangle(box, fill=fill)
        mask.rectangle(box, fill=255)

    for box in ([0, 0, w, frame], [0, h - frame, w, h], [0, 0, frame, h], [w - frame, 0, w, h], [0, h / 2 - rail / 2, w, h / 2 + rail / 2]):
        solid(box)

    for k in (1, 2):
        x = frame + (w - 2 * frame) * k / 3.0
        solid([x - bar / 2, 0, x + bar / 2, h])

    for y in (h * 0.25, h * 0.75):
        solid([0, y - bar / 2, w, y + bar / 2])

    # (The lower sash's top rail lit, the upper's bottom rail shaded: the
    # sashes overlap at the meeting rail.)
    draw.line([(0, h / 2 - rail / 2), (w, h / 2 - rail / 2)], fill=SASH_SHADE, width=SCALE)
    draw.line([(0, h / 2 + rail / 2), (w, h / 2 + rail / 2)], fill=SASH_LIT, width=SCALE)
    draw.line([(w - frame, frame), (w - frame, h - frame)], fill=SASH_LIT, width=SCALE)
    return _finish(image, (64, 128), 8, mask_image)


LATH = (48, 72, 54)
LATH_LIT = (74, 102, 78)
LATH_SHADE = (30, 46, 36)


def lattice():
    """A rotula: a window's lattice shutter (hinged at its head, propped
    out at its foot), thin laths crossing on the diagonal in a frame,
    painted green and worn."""
    w, h = 64 * SCALE, 128 * SCALE
    image, mask_image, draw, mask = _canvas(w, h, LATH)
    lath, gap = int(2.5 * SCALE), 9 * SCALE
    rng = np.random.default_rng(29)

    # One family of laths each way, the second over the first (its edges
    # shaded where it crosses), a little paint variation lath to lath.
    for direction, edge in ((1.0, LATH_LIT), (-1.0, LATH_SHADE)):
        for k in range(-h, w + h, gap):
            tint = int(rng.integers(-8, 9))
            colour = tuple(max(0, min(255, c + tint)) for c in LATH)
            a, b = (k, 0), (k + direction * h, h)
            _bar(draw, mask, [a, b], lath, colour)
            draw.line([(a[0] + SCALE, a[1]), (b[0] + SCALE, b[1])], fill=edge, width=max(1, SCALE // 2))

    frame = 4 * SCALE

    for box in ([0, 0, w, frame], [0, h - frame, w, h], [0, 0, frame, h], [w - frame, 0, w, h]):
        draw.rectangle(box, fill=LATH)
        mask.rectangle(box, fill=255)

    draw.line([(frame, frame), (w - frame, frame)], fill=LATH_SHADE, width=SCALE)
    draw.line([(frame, h - frame), (w - frame, h - frame)], fill=LATH_LIT, width=SCALE)
    return _finish(image, (64, 128), 8, mask_image)


def quarries():
    """Leaded lights, as a 16th-century window was glazed: small diamond
    panes (quarries) set in lead cames on the diagonal, a lead frame round
    them; the lead dark, a little lit along one edge; the panes clear (the
    glass behind shows through)."""
    w, h = 64 * SCALE, 128 * SCALE
    image, mask_image, draw, mask = _canvas(w, h, LEAD)
    came = int(1.5 * SCALE)
    lit = (64, 60, 58)
    # Diamonds 16 px across, 24 up: lines rising and falling on that slope.
    across, up = 16 * SCALE, 24 * SCALE
    slope = up / across

    for k in range(-h, w + h, across):
        for direction in (1.0, -1.0):
            a = (k, 0.0)
            b = (k + direction * h / slope, float(h))
            _bar(draw, mask, [a, b], came, LEAD)
            draw.line([(a[0] + came / 3.0, a[1]), (b[0] + came / 3.0, b[1])], fill=lit, width=max(1, SCALE // 2))

    frame = 2 * SCALE

    for box in ([0, 0, w, frame], [0, h - frame, w, h], [0, 0, frame, h], [w - frame, 0, w, h]):
        draw.rectangle(box, fill=LEAD)
        mask.rectangle(box, fill=255)

    return _finish(image, (64, 128), 8, mask_image)


def glazing():
    """Crown glass seen close: grey for how much it hides (the glazing
    shader's grime), faint waves and a few seeds across it, grime gathered
    toward its edges and thickest along its foot where the rain runs."""
    w, h = 64, 128
    rng = np.random.default_rng(41)
    y, x = np.mgrid[0:h, 0:w].astype(float)
    base = 24.0 + 10.0 * np.sin(y / 9.0 + 2.0 * np.sin(x / 13.0)) + 6.0 * np.sin(x / 5.0 + y / 21.0)
    edge = np.minimum(np.minimum(x, w - 1 - x) / (w * 0.18), 1.0)
    foot = np.clip((y - h * 0.82) / (h * 0.18), 0.0, 1.0)
    top = np.minimum(y / (h * 0.08), 1.0)
    grime = 150.0 * (1.0 - edge) ** 1.5 + 120.0 * foot ** 1.2 + 60.0 * (1.0 - top)
    out = base + grime + rng.normal(0.0, 4.0, (h, w))

    # Seeds: little bubbles caught in the glass.
    for _ in range(14):
        cx, cy = rng.integers(4, w - 4), rng.integers(6, h - 6)
        out[max(cy - 1, 0):cy + 1, max(cx - 1, 0):cx + 1] += 40.0

    grey = np.clip(out, 0, 255).astype(np.uint8)
    return Image.fromarray(np.stack([grey] * 3, axis=-1), "RGB")


def ratlines():
    """A ship's shrouds and ratlines on a clear card: the shrouds running up
    from the channel and drawing in toward the masthead, tarred black, the
    ratlines across them a hand's span apart, sagging a little between."""
    w = h = 128 * SCALE
    tar, lit = (38, 32, 26), (74, 62, 46)
    image, mask_image, draw, mask = _canvas(w, h, tar)
    feet = np.linspace(w * 0.06, w * 0.94, 5)
    heads = np.linspace(w * 0.3, w * 0.7, 5)

    for foot, head in zip(feet, heads):
        _bar(draw, mask, [(foot, h), (head, 0)], int(SCALE * 3), tar, lit)

    for y in np.arange(h - 5 * SCALE, 0, -10 * SCALE):
        t = 1.0 - y / h
        xs = [f + (hd - f) * t for f, hd in zip(feet, heads)]

        for a, b in zip(xs, xs[1:]):
            sag = 1.2 * SCALE
            _bar(draw, mask, [(a, y), ((a + b) / 2.0, y + sag), (b, y)], int(SCALE * 1.6), tar)

    return _finish(image, (128, 128), 8, mask_image)


def coil_mask():
    """The rope coil's mask (ps2ify: rope_coil): the coil round, the deck it
    lay on cut away."""
    size = 128 * SCALE
    image = Image.new("L", (size, size), 0)
    ImageDraw.Draw(image).ellipse([size * 0.05, size * 0.05, size * 0.95, size * 0.95], fill=255)
    return image.resize((128, 128), Image.Resampling.BOX).point(lambda v: 255 if v >= 128 else 0)


def decal_salt():
    """Salt dried on a quay's face or a hull: pale tide marks, bands of white
    bloom one over another, fading out raggedly."""
    size = 256
    rng = np.random.default_rng(141)
    y, x = np.mgrid[0:size, 0:size] / float(size)
    wander = (_noise(size, rng) - 0.5) * 0.12
    # The bloom: a band across the middle, its top and foot ragged, fading
    # out toward both ends; three tide lines in it, whiter.
    band = np.clip(1.0 - np.abs(y - 0.5 + wander) / 0.2, 0.0, 1.0)
    ends = np.clip(np.minimum(x, 1.0 - x) / 0.2, 0.0, 1.0)
    lines = np.zeros_like(band)

    for level in (0.38, 0.47, 0.58):
        lines = np.maximum(lines, np.clip(1.0 - np.abs(y - level + wander * 0.6) / 0.012, 0.0, 1.0))

    # Runs of salt left by water trickling down under it.
    drips = np.zeros_like(band)

    for column in rng.choice(size, 18, replace=False):
        length = rng.uniform(0.08, 0.25)
        near = np.clip(1.0 - np.abs(x - column / float(size)) / 0.008, 0.0, 1.0)
        drips = np.maximum(drips, near * ((y > 0.6) & (y < 0.6 + length)) * (1.0 - (y - 0.6) / length))

    thick = np.clip((band * 0.75 * (0.55 + 0.45 * _noise(size, rng)) + lines * 0.5 + drips * 0.6) * ends, 0.0, 1.0)
    thick[thick < 0.12] = 0.0
    mottle = _noise(size, rng)
    pixels = np.empty((size, size, 3))
    pixels[:] = np.array([206.0, 204.0, 192.0])
    pixels *= (0.86 + 0.2 * mottle)[:, :, None]
    return _soft_finish(pixels, thick, 128, 12)


def palm_frond():
    """A date palm's frond on a card: the midrib arching out and down,
    narrow leaflets along it both ways, dusty greens going yellow at the
    tip."""
    size = 128 * SCALE
    rng = np.random.default_rng(151)
    image, mask_image, draw, mask = _canvas(size, size, (40, 50, 30))
    palette = [(58, 76, 40), (72, 90, 46), (88, 102, 52), (106, 110, 58), (124, 118, 64)]
    rib = []

    for i in range(24):
        t = i / 23.0
        rib.append((size * (0.06 + 0.86 * t), size * (0.92 - 1.25 * t + 0.95 * t * t)))

    _bar(draw, mask, rib, int(SCALE * 2.5), (92, 86, 54))

    for (x, y), (nx, ny) in zip(rib[1:-1], rib[2:]):
        along = math.atan2(ny - y, nx - x)
        t = x / size

        for side in (-1.0, 1.0):
            for _ in range(2):
                colour = palette[min(len(palette) - 1, int(t * len(palette) + rng.integers(0, 2)))]
                angle = along + side * rng.uniform(0.5, 0.85)
                length = size * (0.2 - 0.1 * abs(t - 0.4)) * rng.uniform(0.85, 1.1)
                _leaf(draw, mask, x, y, length, size * 0.026, angle, _tinted(colour, rng.uniform(0.8, 1.15)), _tinted(colour, 0.65))

    return _finish(image, (128, 128), 24, mask_image)


def cypress():
    """A cypress: a tall dark flame of close sprays, a little light on its
    moonward side, gaps here and there."""
    w, h = 64 * SCALE, 256 * SCALE
    rng = np.random.default_rng(161)
    image, mask_image, draw, mask = _canvas(w, h, (14, 20, 14))
    palette = [(20, 32, 20), (26, 40, 24), (32, 48, 28), (42, 58, 34)]
    sprays = []

    for _ in range(1400):
        t = rng.random()
        half = w * 0.46 * math.sin(math.pi * min(1.0, (1.0 - t) ** 0.7 * 1.02)) ** 0.9
        x = w / 2.0 + rng.uniform(-1.0, 1.0) * half
        y = h * (0.02 + 0.97 * t)
        sprays.append((x, y))

    for x, y in sorted(sprays, key=lambda p: p[0]):
        colour = palette[int(rng.integers(len(palette)))]
        bright = 0.7 + 0.5 * (x / w)
        _leaf(draw, mask, x, y, w * 0.09, w * 0.035, -math.pi / 2 + rng.uniform(-0.7, 0.7), _tinted(colour, bright), _tinted(colour, bright * 0.7))

    return _finish(image, (64, 256), 16, mask_image)


def agave():
    """An agave from the side: thick pointed leaves fanning up and out from
    the ground, blue-green with yellow edges, a dark spine at each tip."""
    size = 128 * SCALE
    rng = np.random.default_rng(171)
    image, mask_image, draw, mask = _canvas(size, size, (50, 64, 58))
    base = (size / 2.0, size * 0.97)

    for k in range(13):
        angle = -math.pi / 2 + (k - 6) * 0.2 + rng.uniform(-0.06, 0.06)
        length = size * (0.8 - 0.07 * abs(k - 6)) * rng.uniform(0.9, 1.05)
        bright = 0.8 + 0.3 * rng.random()
        _leaf(draw, mask, base[0], base[1], length, size * 0.1, angle, _tinted((92, 122, 112), bright), (168, 160, 88))
        tip = (base[0] + length * math.cos(angle), base[1] + length * math.sin(angle))
        draw.line([tip, (tip[0] - math.cos(angle) * SCALE * 6, tip[1] - math.sin(angle) * SCALE * 6)], fill=(40, 32, 24), width=SCALE * 2)

    return _finish(image, (128, 128), 16, mask_image)


def orange_leaves():
    """An orange tree's crown: glossy dark leaves in a round mass, oranges
    among them."""
    size = 128 * SCALE
    rng = np.random.default_rng(181)
    # (Leaves grow out from where they start: a dense heart keeps the
    # middle of the crown full.)
    blobs = [(size * 0.5, size * 0.52, size * 0.3), (size * 0.5, size * 0.52, size * 0.15), (size * 0.47, size * 0.48, size * 0.1)]

    for k in range(7):
        a = k * math.tau / 7 + rng.uniform(-0.3, 0.3)
        blobs.append((size * 0.5 + math.cos(a) * size * 0.24, size * 0.5 + math.sin(a) * size * 0.22, size * rng.uniform(0.1, 0.15)))

    return _crown(size, 128, 950, size * 0.07, size * 0.032, [(22, 48, 24), (30, 60, 30), (40, 74, 36), (52, 86, 40)], blobs, 183,
                  twigs=False, fruit=(18, size * 0.028, (232, 128, 32)), heart=0.14)


# ---------------------------------------------------------------------------
# The coast's planting (docs/superpowers/refs/coast_life.md): gorse pruned to
# a cushion by the wind, sea fennel in the cracks, a stone pine's umbrella;
# the Ribeira's laundry
# ---------------------------------------------------------------------------

def gorse():
    """Gorse in a low cushion: dark spiny greens, thick together, lit on
    top, yellow flowers scattered over it."""
    size = 128 * SCALE
    rng = np.random.default_rng(171)
    blobs = [(size * 0.5, size * 0.66, size * 0.3)]

    for k in range(7):
        x = size * (0.14 + 0.72 * k / 6.0) + rng.uniform(-6, 6) * SCALE
        blobs.append((x, size * rng.uniform(0.56, 0.7), size * rng.uniform(0.12, 0.18)))

    return _crown(size, 128, 1500, size * 0.045, size * 0.012, [(28, 44, 26), (36, 54, 30), (44, 64, 32), (54, 72, 36)], blobs, 173,
                  twigs=False, fruit=(110, size * 0.011, (222, 186, 44)))


def fennel():
    """Sea fennel: a clump of fleshy grey-green fronds from a crack, its
    yellow-green umbels over them on stiff stalks."""
    w = h = 128 * SCALE
    rng = np.random.default_rng(181)
    image, mask_image, draw, mask = _canvas(w, h, (52, 62, 44))
    palette = [(92, 112, 84), (106, 126, 94), (120, 138, 104), (82, 100, 76)]
    tips = []

    for _ in range(46):
        base = w * (0.5 + rng.normal(0.0, 0.08))
        height = h * rng.uniform(0.25, 0.7)
        lean = rng.uniform(-0.7, 0.7) * height
        colour = palette[int(rng.integers(len(palette)))]
        points = [(base + lean * (i / 8.0) ** 1.5, h - height * (i / 8.0)) for i in range(9)]
        _bar(draw, mask, points, int(SCALE * 2.2), _tinted(colour, rng.uniform(0.8, 1.1)))

        # Its leaflets: short fat blades either side along it.
        for (x, y), (nx, ny) in zip(points[2::2], points[3::2]):
            for side in (-1.0, 1.0):
                angle = math.atan2(ny - y, nx - x) + side * rng.uniform(0.5, 0.9)
                tip = (x + math.cos(angle) * 7 * SCALE, y + math.sin(angle) * 7 * SCALE)
                _bar(draw, mask, [(x, y), tip], int(SCALE * 2.6), _tinted(colour, rng.uniform(0.85, 1.15)))

        if rng.random() < 0.45:
            tips.append(points[-1])

    for x, y in tips:
        stalk = (x + rng.uniform(-4, 4) * SCALE, y - rng.uniform(8, 14) * SCALE)
        _bar(draw, mask, [(x, y), stalk], int(SCALE * 1.5), (110, 120, 70))

        for _ in range(9):
            a = rng.uniform(math.pi * 1.1, math.pi * 1.9)
            end = (stalk[0] + math.cos(a) * 6 * SCALE, stalk[1] + math.sin(a) * 4 * SCALE)
            _bar(draw, mask, [stalk, end], SCALE, (150, 150, 70))
            r = 1.6 * SCALE
            draw.ellipse([end[0] - r, end[1] - r, end[0] + r, end[1] + r], fill=(196, 188, 62))
            mask.ellipse([end[0] - r, end[1] - r, end[0] + r, end[1] + r], fill=255)

    return _finish(image, (128, 128), 24, mask_image)


def pine():
    """A stone pine's crown as it is seen from the ground: an umbrella of
    needle tufts, wide and flat, darker underneath (its limbs are drawn as
    the tree's own)."""
    size = 256 * SCALE
    rng = np.random.default_rng(191)
    image, mask_image, draw, mask = _canvas(size, size, (18, 26, 18))
    c = size / 2.0
    palette = [(26, 42, 30), (32, 52, 34), (40, 62, 40), (50, 74, 46), (62, 86, 52)]
    blobs = [(c, c * 0.92, size * 0.16)]

    for k in range(9):
        x = size * (0.1 + 0.8 * k / 8.0)
        blobs.append((x, c * rng.uniform(0.84, 1.02) - abs(x - c) * 0.08, size * rng.uniform(0.07, 0.11)))

    tufts = sorted(((c - y) / c + rng.uniform(-0.2, 0.2), x, y) for x, y in _blob_points(rng, blobs, 1100))

    for up, x, y in tufts:
        colour = _tinted(palette[int(rng.integers(len(palette)))], 0.75 + 0.45 * up)

        # A tuft: needles fanning up and out from a point.
        for _ in range(7):
            a = -math.pi / 2.0 + rng.uniform(-1.3, 1.3)
            length = size * rng.uniform(0.018, 0.03)
            tip = (x + math.cos(a) * length, y + math.sin(a) * length * 0.7)
            draw.line([(x, y), tip], fill=colour, width=int(size * 0.006))
            mask.line([(x, y), tip], fill=255, width=int(size * 0.006))

    return _finish(image, (256, 256), 24, mask_image)


def laundry():
    """Washing on a line between two windows: a shirt, a sheet, breeches,
    a shift, pegged along a sagging cord; their folds and shadows."""
    w, h = 128 * SCALE, 64 * SCALE
    rng = np.random.default_rng(201)
    image, mask_image, draw, mask = _canvas(w, h, (60, 56, 50))
    line = [(x, h * 0.05 + h * 0.05 * math.sin(math.pi * x / w)) for x in np.linspace(0, w, 17)]
    _bar(draw, mask, line, int(SCALE * 1.5), (70, 62, 50))

    def sag(x):
        return h * 0.05 + h * 0.05 * math.sin(math.pi * x / w)

    # (x0, x1, how far down, its cloth, its shape)
    pieces = [(0.04, 0.22, 0.62, (196, 188, 168), "shirt"), (0.27, 0.56, 0.92, (214, 208, 192), "sheet"),
              (0.61, 0.75, 0.7, (96, 74, 52), "breeches"), (0.8, 0.96, 0.8, (120, 128, 136), "shift")]

    for x0, x1, down, cloth, shape in pieces:
        a, b = w * x0, w * x1
        top = sag((a + b) / 2.0)
        bottom = top + h * down * 0.9

        if shape == "shirt":
            outline = [(a, top), (b, top), (b + 4 * SCALE, top + 10 * SCALE), (b - 4 * SCALE, top + 12 * SCALE), (b - 4 * SCALE, bottom),
                       (a + 4 * SCALE, bottom), (a + 4 * SCALE, top + 12 * SCALE), (a - 4 * SCALE, top + 10 * SCALE)]
        elif shape == "breeches":
            m = (a + b) / 2.0
            outline = [(a, top), (b, top), (b + 1 * SCALE, bottom), (m + 2 * SCALE, bottom), (m, top + (bottom - top) * 0.35),
                       (m - 2 * SCALE, bottom), (a - 1 * SCALE, bottom)]
        else:
            outline = [(a, top), (b, top), (b + 2 * SCALE, bottom), (a - 1 * SCALE, bottom - 2 * SCALE)]

        draw.polygon(outline, fill=cloth)
        mask.polygon(outline, fill=255)

        # Folds: darker runs down it, a lit edge beside each.
        for k in range(3 + int(rng.integers(3))):
            x = a + (b - a) * rng.uniform(0.15, 0.85)
            draw.line([(x, top + 3 * SCALE), (x + rng.uniform(-3, 3) * SCALE, bottom - 2 * SCALE)], fill=_tinted(cloth, 0.72), width=2 * SCALE)
            draw.line([(x + 2 * SCALE, top + 3 * SCALE), (x + 2 * SCALE, bottom - 4 * SCALE)], fill=_tinted(cloth, 1.08), width=SCALE)

        for x in (a + 2 * SCALE, b - 2 * SCALE):
            draw.rectangle([x - SCALE, top - 2 * SCALE, x + SCALE, top + 3 * SCALE], fill=(90, 74, 54))

    return _finish(image, (128, 64), 24, mask_image)


COBALT = (34, 58, 132)
GLAZE = (226, 222, 204)


def azulejo_ship():
    """A panel of azulejos for the customs house's front (5 x 4 tiles): a
    caravel under sail on cobalt waves in a cobalt-and-ochre frame, painted
    in the tin glaze's blues on its white, the joints between the tiles, a
    little crazing and wear."""
    tw, th = 5, 4
    tile = 32 * SCALE
    w, h = tw * tile, th * tile
    image = Image.new("RGB", (w, h), GLAZE)
    draw = ImageDraw.Draw(image)
    rng = np.random.default_rng(1500)
    # The frame: a cobalt band, an ochre line inside it.
    b = int(tile * 0.32)
    draw.rectangle([0, 0, w, h], outline=COBALT, width=b)
    draw.rectangle([b, b, w - b, h - b], outline=(176, 132, 52), width=int(SCALE * 2.5))
    # The sea: rows of cobalt waves, darker below.
    for row in range(5):
        y = h * 0.66 + row * h * 0.055
        for x in range(b, w - b, int(SCALE * 14)):
            draw.arc([x, y - SCALE * 4, x + SCALE * 14, y + SCALE * 4], 200, 340, fill=COBALT, width=int(SCALE * (1.6 + row * 0.4)))
    # The caravel: her hull, castles, lateen and square sails, her flag.
    cx, sea = w * 0.5, h * 0.66
    hull = [(cx - w * 0.2, sea - h * 0.1), (cx + w * 0.22, sea - h * 0.12), (cx + w * 0.16, sea + h * 0.02), (cx - w * 0.15, sea + h * 0.02)]
    draw.polygon(hull, fill=COBALT)
    draw.rectangle([cx - w * 0.2, sea - h * 0.16, cx - w * 0.1, sea - h * 0.1], fill=COBALT)
    for mx, top, sail in ((cx - w * 0.06, 0.5, "square"), (cx + w * 0.08, 0.56, "lateen"), (cx - w * 0.17, 0.32, "lateen")):
        draw.line([(mx, sea - h * 0.1), (mx, sea - h * top)], fill=COBALT, width=int(SCALE * 2))
        if sail == "square":
            draw.polygon([(mx - w * 0.07, sea - h * (top - 0.04)), (mx + w * 0.07, sea - h * (top - 0.04)), (mx + w * 0.08, sea - h * 0.17),
                          (mx - w * 0.08, sea - h * 0.17)], fill=(70, 96, 168), outline=COBALT)
            # (The cross of the Order of Christ on her mainsail.)
            c = w * 0.022
            draw.rectangle([mx - c * 0.35, sea - h * 0.39, mx + c * 0.35, sea - h * 0.27], fill=(156, 34, 30))
            draw.rectangle([mx - c, sea - h * 0.345, mx + c, sea - h * 0.315], fill=(156, 34, 30))
        else:
            draw.polygon([(mx - w * 0.06, sea - h * (top - 0.02)), (mx + w * 0.05, sea - h * 0.16), (mx - w * 0.01, sea - h * 0.16)],
                         fill=(70, 96, 168), outline=COBALT)
        draw.polygon([(mx, sea - h * top), (mx + w * 0.035, sea - h * (top - 0.02)), (mx, sea - h * (top - 0.04))], fill=COBALT)
    # Gulls, a sun of the Order's ochre.
    draw.ellipse([w * 0.72, h * 0.2, w * 0.8, h * 0.31], outline=(176, 132, 52), width=int(SCALE * 3))
    for gx, gy in ((0.25, 0.25), (0.33, 0.2), (0.62, 0.3)):
        draw.arc([w * gx, h * gy, w * gx + SCALE * 8, h * gy + SCALE * 5], 200, 340, fill=COBALT, width=int(SCALE * 1.5))
    # The joints, a little crazing and wear.
    pixels = np.asarray(image, dtype=np.float64)
    pixels *= (0.93 + 0.07 * rng.random((h, w)))[:, :, None]
    image = Image.fromarray(np.clip(pixels, 0, 255).astype(np.uint8), "RGB")
    draw = ImageDraw.Draw(image)
    for i in range(1, tw):
        draw.line([(i * tile, 0), (i * tile, h)], fill=(150, 146, 132), width=int(SCALE * 1.2))
    for j in range(1, th):
        draw.line([(0, j * tile), (w, j * tile)], fill=(150, 146, 132), width=int(SCALE * 1.2))
    return _finish(image, (tw * 32, th * 32), 16)


COMET = (192, 50, 34)
COMET_PALE = (222, 118, 86)
OCHRE = (204, 160, 68)
SKY_BLUE = (70, 96, 168)


def _glazed(tw, th, seed):
    """A panel of tw x th azulejos at the drawn size: its white glaze, a
    cobalt band round it with an ochre line inside; (image, draw, band)."""
    tile = 32 * SCALE
    w, h = tw * tile, th * tile
    image = Image.new("RGB", (w, h), GLAZE)
    draw = ImageDraw.Draw(image)
    b = int(tile * 0.3)
    draw.rectangle([0, 0, w, h], outline=COBALT, width=b)
    draw.rectangle([b, b, w - b, h - b], outline=OCHRE, width=int(SCALE * 2.5))
    return image, draw, b


def _jointed(image, tw, th, seed, colours=20):
    """A painted panel's crazing and wear, and the joints between its tiles,
    shrunk to 32 px a tile."""
    tile = 32 * SCALE
    w, h = image.size
    rng = np.random.default_rng(seed)
    pixels = np.asarray(image, dtype=np.float64)
    pixels *= (0.93 + 0.07 * rng.random((h, w)))[:, :, None]
    image = Image.fromarray(np.clip(pixels, 0, 255).astype(np.uint8), "RGB")
    draw = ImageDraw.Draw(image)

    for i in range(1, tw):
        draw.line([(i * tile, 0), (i * tile, h)], fill=(150, 146, 132), width=int(SCALE * 1.2))

    for j in range(1, th):
        draw.line([(0, j * tile), (w, j * tile)], fill=(150, 146, 132), width=int(SCALE * 1.2))

    return _finish(image, (tw * 32, th * 32), colours)


def arms_royal():
    """The king's arms over the customs house's door, painted on the stone
    of its tympanum: the shield of the five quinas (five blue escutcheons in
    a cross on white, each with its white roundels) in a red bordure of
    gold castles, a closed crown over it."""
    size = 64 * SCALE
    image = Image.new("RGB", (size, size), (120, 112, 96))
    draw = ImageDraw.Draw(image)
    mask = Image.new("L", (size, size), 0)
    m = ImageDraw.Draw(mask)
    top, bottom, left, right = size * 0.26, size * 0.96, size * 0.18, size * 0.82
    shape = [(left, top), (right, top), (right, size * 0.7), (size / 2, bottom), (left, size * 0.7)]
    draw.polygon(shape, fill=(150, 26, 26))
    m.polygon(shape, fill=255)
    inner = [(left + size * 0.07, top + size * 0.06), (right - size * 0.07, top + size * 0.06), (right - size * 0.07, size * 0.68),
             (size / 2, bottom - size * 0.08), (left + size * 0.07, size * 0.68)]
    draw.polygon(inner, fill=(232, 228, 214))
    # The castles round the bordure.
    for x, y in ((0.22, 0.32), (0.22, 0.48), (0.22, 0.64), (0.78, 0.32), (0.78, 0.48), (0.78, 0.64), (0.5, 0.29), (0.36, 0.85), (0.64, 0.85)):
        cx, cy, c = size * x, size * y, size * 0.03
        draw.rectangle([cx - c, cy - c * 0.6, cx + c, cy + c], fill=(214, 172, 60))
        draw.rectangle([cx - c * 0.4, cy - c * 1.2, cx + c * 0.4, cy], fill=(214, 172, 60))
    # The quinas.
    for x, y in ((0.5, 0.42), (0.37, 0.55), (0.5, 0.55), (0.63, 0.55), (0.5, 0.68)):
        cx, cy, q = size * x, size * y, size * 0.058
        draw.polygon([(cx - q, cy - q), (cx + q, cy - q), (cx + q, cy + q * 0.6), (cx, cy + q * 1.3), (cx - q, cy + q * 0.6)], fill=(22, 46, 156))
        for dx, dy in ((-0.5, -0.5), (0.5, -0.5), (0.0, 0.0), (-0.5, 0.5), (0.5, 0.5)):
            r = q * 0.16
            draw.ellipse([cx + dx * q * 0.9 - r, cy + dy * q * 0.9 - r, cx + dx * q * 0.9 + r, cy + dy * q * 0.9 + r], fill=(232, 228, 214))
    # The crown over it.
    crown = [(size * 0.3, size * 0.22), (size * 0.7, size * 0.22), (size * 0.72, size * 0.1), (size * 0.62, size * 0.15), (size * 0.5, size * 0.04),
             (size * 0.38, size * 0.15), (size * 0.28, size * 0.1)]
    draw.polygon(crown, fill=(214, 172, 60))
    m.polygon(crown, fill=255)
    rng = np.random.default_rng(1521)
    pixels = np.asarray(image, dtype=np.float64) * (0.8 + 0.2 * rng.random((size, size)))[:, :, None]
    image = Image.fromarray(np.clip(pixels, 0, 255).astype(np.uint8), "RGB")
    return _finish(image, (64, 64), 24, mask)


VELLUM = (204, 186, 146)
INK = (52, 40, 30)


def sea_chart():
    """A portolan chart on vellum: a coast in ink with its capes and bays
    named in scribbles, rhumb lines from two compass roses, a wind rose in
    red and gold, a cartouche, the vellum stained and worn."""
    w, h = 128 * SCALE, 96 * SCALE
    image = Image.new("RGB", (w, h), VELLUM)
    draw = ImageDraw.Draw(image)
    rng = np.random.default_rng(1492)
    # Rhumb lines from two roses.
    for cx, cy in ((w * 0.36, h * 0.5), (w * 0.72, h * 0.42)):
        for i in range(32):
            a = i * math.tau / 32
            colour = (150, 40, 34) if i % 4 == 0 else ((60, 96, 60) if i % 2 == 0 else (130, 112, 80))
            draw.line([(cx, cy), (cx + math.cos(a) * w, cy + math.sin(a) * w)], fill=colour, width=max(1, SCALE // 2))
    # The coast: a long ragged line across, land shaded behind it.
    pts = []
    for i in range(41):
        x = w * i / 40
        y = h * (0.28 + 0.12 * math.sin(i * 0.5) + 0.05 * math.sin(i * 1.7 + 1.0)) + rng.uniform(-3, 3) * SCALE
        pts.append((x, y))
    draw.polygon(pts + [(w, 0), (0, 0)], fill=(186, 166, 120))
    draw.line(pts, fill=INK, width=int(SCALE * 1.5))
    # Names along the coast: ink scribbles square to it.
    for x, y in pts[2:-2:3]:
        for k in range(int(rng.integers(3, 7))):
            draw.line([(x + k * SCALE * 1.5, y - SCALE * 3), (x + k * SCALE * 1.5, y - SCALE * (3 + rng.uniform(2, 6)))], fill=INK, width=SCALE // 2)
    # The roses.
    for cx, cy, r in ((w * 0.36, h * 0.5, h * 0.14), (w * 0.72, h * 0.42, h * 0.09)):
        for i in range(8):
            a = i * math.tau / 8
            tip = (cx + math.cos(a) * r, cy + math.sin(a) * r)
            side = r * (0.18 if i % 2 == 0 else 0.12)
            l = (cx + math.cos(a + math.pi / 2) * side, cy + math.sin(a + math.pi / 2) * side)
            rr = (cx + math.cos(a - math.pi / 2) * side, cy + math.sin(a - math.pi / 2) * side)
            draw.polygon([tip, l, (cx, cy)], fill=(196, 152, 64) if i % 2 == 0 else (150, 40, 34))
            draw.polygon([tip, rr, (cx, cy)], fill=INK)
        draw.ellipse([cx - r * 0.12, cy - r * 0.12, cx + r * 0.12, cy + r * 0.12], fill=(150, 40, 34))
    # A cartouche, a ship drawn at sea.
    draw.rectangle([w * 0.06, h * 0.72, w * 0.3, h * 0.92], outline=INK, width=SCALE)
    for j in range(3):
        draw.line([(w * 0.08, h * (0.77 + j * 0.05)), (w * 0.28, h * (0.77 + j * 0.05))], fill=INK, width=SCALE // 2)
    sx, sy = w * 0.58, h * 0.75
    draw.polygon([(sx - SCALE * 8, sy), (sx + SCALE * 8, sy), (sx + SCALE * 5, sy + SCALE * 4), (sx - SCALE * 5, sy + SCALE * 4)], fill=INK)
    draw.polygon([(sx, sy - SCALE * 12), (sx + SCALE * 6, sy - SCALE * 3), (sx, sy - SCALE * 2)], fill=(232, 222, 196), outline=INK)
    # Stains and wear.
    pixels = np.asarray(image, dtype=np.float64)
    for _ in range(6):
        cx, cy, r = rng.uniform(0, w), rng.uniform(0, h), rng.uniform(0.05, 0.2) * w
        yy, xx = np.mgrid[0:h, 0:w]
        pixels *= 1.0 - 0.1 * np.exp(-((xx - cx) ** 2 + (yy - cy) ** 2) / (r * r))[:, :, None]
    pixels *= (0.92 + 0.08 * rng.random((h, w)))[:, :, None]
    image = Image.fromarray(np.clip(pixels, 0, 255).astype(np.uint8), "RGB")
    return _finish(image, (128, 96), 40)


def parchment():
    """A written page: lines of ink in a clerk's hand, a seal's red at its
    foot, the paper browned at its edges."""
    w, h = 64 * SCALE, 64 * SCALE
    image = Image.new("RGB", (w, h), (214, 198, 160))
    draw = ImageDraw.Draw(image)
    rng = np.random.default_rng(1530)
    for j in range(13):
        y = h * (0.1 + j * 0.06)
        x = w * 0.1
        while x < w * 0.88:
            word = rng.uniform(4, 12) * SCALE
            draw.line([(x, y), (min(x + word, w * 0.9), y + rng.uniform(-1, 1) * SCALE)], fill=INK, width=SCALE // 2 + 1)
            x += word + 2.5 * SCALE
    draw.ellipse([w * 0.66, h * 0.86, w * 0.8, h * 0.98], fill=(150, 30, 26))
    yy, xx = np.mgrid[0:h, 0:w]
    edge = np.minimum(np.minimum(xx, w - xx), np.minimum(yy, h - yy)) / (w * 0.12)
    pixels = np.asarray(image, dtype=np.float64) * (0.7 + 0.3 * np.clip(edge, 0, 1))[:, :, None]
    pixels *= (0.92 + 0.08 * rng.random((h, w)))[:, :, None]
    return _finish(Image.fromarray(np.clip(pixels, 0, 255).astype(np.uint8), "RGB"), (64, 64), 20)


def book_spines():
    """A shelf's worth of ledgers and books seen end on: leather spines in
    browns, reds and greens, their bands and gilt titles, some leaning."""
    w, h = 128 * SCALE, 64 * SCALE
    image = Image.new("RGB", (w, h), (22, 16, 12))
    draw = ImageDraw.Draw(image)
    rng = np.random.default_rng(1543)
    colours = [(92, 52, 30), (120, 36, 30), (60, 70, 40), (70, 46, 28), (140, 104, 60), (40, 40, 50), (100, 72, 40)]
    x = 0.0
    while x < w:
        bw = rng.uniform(5, 11) * SCALE
        top = h * rng.uniform(0.05, 0.3)
        c = colours[int(rng.integers(0, len(colours)))]
        draw.rectangle([x + SCALE * 0.5, top, x + bw - SCALE * 0.5, h], fill=c)
        for band in (top + h * 0.08, h * 0.82):
            draw.rectangle([x + SCALE * 0.5, band, x + bw - SCALE * 0.5, band + SCALE * 1.5], fill=tuple(int(v * 0.6) for v in c))
        draw.rectangle([x + bw * 0.3, top + h * 0.2, x + bw * 0.7, top + h * 0.3], fill=(190, 150, 70))
        x += bw
    pixels = np.asarray(image, dtype=np.float64) * (0.85 + 0.15 * rng.random((h, w)))[:, :, None]
    return _finish(Image.fromarray(np.clip(pixels, 0, 255).astype(np.uint8), "RGB"), (128, 64), 24)


# The massing's house fronts: FACADE metres across and up (two storeys of
# four windows), FACADE_PX pixels; each window's middle along it, its
# storeys' floors, its opening's sill and head over its floor, its width.
FACADE = (12.0, 7.0)
FACADE_PX = (192, 112)
FACADE_WINDOWS = (1.5, 4.5, 7.5, 10.5)
FACADE_FLOORS = (0.0, 3.5)
FACADE_OPENING = (0.9, 2.5, 0.9)
FACADE_WALLS = {"white": (184, 178, 166), "ochre": (178, 132, 64), "salmon": (170, 102, 76), "blue": (142, 160, 170)}
FACADE_SHUTTERS = {"white": [(48, 74, 54), (82, 58, 40)], "ochre": [(58, 72, 86), (90, 42, 34)], "salmon": [(48, 74, 54), (64, 60, 52)],
                   "blue": [(82, 58, 40), (40, 52, 70)]}


def _facade(wall):
    """A house front in `wall` render (FACADE: two storeys of four
    windows): stone surrounds and sills, shutters open, closed or ajar in
    two colours, one window's glass bare, an iron balcony upstairs, grime
    run down from the sills; the render mottled."""
    w, h = FACADE_PX[0] * SCALE, FACADE_PX[1] * SCALE
    per = w / FACADE[0]
    rng = np.random.default_rng(1640 + sum(FACADE_WALLS[wall]))
    base = np.array(FACADE_WALLS[wall], dtype=np.float64)
    field = _noise(max(w, h), rng, octaves=5, base=3)[:h, :w]
    pixels = base[None, None, :] * (0.86 + 0.2 * field[:, :, None])
    image = Image.fromarray(np.clip(pixels, 0, 255).astype(np.uint8), "RGB")
    draw = ImageDraw.Draw(image)
    px = lambda u: u * per
    py = lambda y: h - y * per
    stone, glass, iron = (204, 196, 180), (22, 20, 26), (30, 28, 28)
    width, sill, head = FACADE_OPENING[2], FACADE_OPENING[0], FACADE_OPENING[1]
    states = ["open", "closed", "ajar", "open", "bare", "open", "closed", "open"]

    for k, floor in enumerate(FACADE_FLOORS):
        for i, u in enumerate(FACADE_WINDOWS):
            x0, x1, y0, y1 = px(u - width / 2.0), px(u + width / 2.0), py(floor + head), py(floor + sill)
            # Grime run down from the sill.
            for g in range(int(per * 1.2)):
                shade = 0.9 + 0.1 * g / (per * 1.2)
                row = int(y1 + per * 0.1 + g)
                if row < h:
                    strip = np.asarray(image.crop((int(x0), row, int(x1), row + 1)), dtype=np.float64) * shade
                    image.paste(Image.fromarray(strip.astype(np.uint8), "RGB"), (int(x0), row))
            band = per * 0.14
            draw.rectangle([x0 - band, y0 - band, x1 + band, y1], fill=stone)
            draw.rectangle([x0 - band * 1.6, y1, x1 + band * 1.6, y1 + per * 0.1], fill=stone)
            draw.rectangle([x0, y0, x1, y1], fill=glass)
            draw.line([((x0 + x1) / 2.0, y0), ((x0 + x1) / 2.0, y1)], fill=(54, 48, 44), width=SCALE)
            draw.line([(x0, (y0 + y1) / 2.0), (x1, (y0 + y1) / 2.0)], fill=(54, 48, 44), width=SCALE)
            colour = FACADE_SHUTTERS[wall][(i + k) % 2]
            state = states[(k * 4 + i) % len(states)]
            leaf = (x1 - x0) / 2.0

            def boards(a, b):
                draw.rectangle([a, y0, b, y1], fill=colour)
                for r in range(1, 6):
                    yy = y0 + (y1 - y0) * r / 6.0
                    draw.line([(a, yy), (b, yy)], fill=tuple(int(c * 0.7) for c in colour), width=max(1, SCALE // 2))

            if state == "open":
                boards(x0 - band - leaf, x0 - band)
                boards(x1 + band, x1 + band + leaf)
            elif state == "closed":
                boards(x0, x1)
            elif state == "ajar":
                boards(x0, x0 + leaf)
                boards(x1 + band, x1 + band + leaf)

    # An iron balcony on the second window upstairs: its slab, its rail.
    u = FACADE_WINDOWS[1]
    floor = FACADE_FLOORS[1]
    x0, x1 = px(u - 0.75), px(u + 0.75)
    draw.rectangle([x0, py(floor + 0.95), x1, py(floor + 0.85)], fill=stone)
    draw.rectangle([x0, py(floor + 1.9), x1, py(floor + 1.85)], fill=iron)
    for b in range(9):
        bx = x0 + (x1 - x0) * b / 8.0
        draw.line([(bx, py(floor + 1.9)), (bx, py(floor + 0.95))], fill=iron, width=SCALE)

    return _finish(image, FACADE_PX, 28)


def facade_white():
    return _facade("white")


def facade_ochre():
    return _facade("ochre")


def facade_salmon():
    return _facade("salmon")


def facade_blue():
    return _facade("blue")


PAINTINGS = {"moon": moon, "banner": banner, "rose_window": rose_window, "altar_frontal": altar_frontal,
             "shield_1": shield_1, "shield_2": shield_2, "shield_3": shield_3,
             "leaf_crown": leaf_crown, "leaf_shrub": leaf_shrub, "yew": yew, "twigs": twigs, "grass": grass,
             "weed_broad": weed_broad, "reeds": reeds, "ivy": ivy, "bark": bark, "bat": bat,
             "decal_soot": decal_soot, "decal_dirt": decal_dirt, "decal_straw": decal_straw, "decal_leaves": decal_leaves,
             "carpet": carpet,
             "iron_rail": iron_rail, "window_grille": window_grille, "casement": casement, "quarries": quarries, "glazing": glazing, "sash": sash, "lattice": lattice, "ratlines": ratlines, "coil_mask": coil_mask,
             "decal_salt": decal_salt, "palm_frond": palm_frond, "cypress": cypress, "agave": agave, "orange_leaves": orange_leaves,
             "gorse": gorse, "fennel": fennel, "pine": pine, "laundry": laundry, "azulejo_ship": azulejo_ship, "arms_royal": arms_royal,
             "azulejo_comet": azulejo.azulejo_comet, "azulejo_king": azulejo.azulejo_king, "azulejo_souls": azulejo.azulejo_souls,
             "tile_frame": azulejo.tile_frame, "window_lit": azulejo.window_lit,
             "sea_chart": sea_chart, "parchment": parchment, "book_spines": book_spines,
             "facade_white": facade_white, "facade_ochre": facade_ochre, "facade_salmon": facade_salmon, "facade_blue": facade_blue}


def main(argv):
    OUT.mkdir(parents=True, exist_ok=True)

    for name in argv or sorted(PAINTINGS):
        path = OUT / (name + ".png")
        PAINTINGS[name]().save(path)
        print("%-14s -> %s" % (name, path.relative_to(ROOT)))

    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
