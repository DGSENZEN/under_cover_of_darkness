#!/usr/bin/env python3
"""Textures we paint ourselves (no photo in them, so they are committed):
the garrison's banner, the chapel's rose window and altar frontal, the mess
hall's shields, the moon, and the nature round the walls: leaves for a
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


# ---------------------------------------------------------------------------
# Nature: leaves, needles, twigs, grass, weeds, reeds, ivy (cut out), bark
# ---------------------------------------------------------------------------

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


def _crown(size, final, leaves, leaf_len, leaf_w, palette, blobs, seed, twigs=True):
    """Leaves in lumpy blobs, lit from above: the lower and inner ones darker,
    drawn first; the outer and upper ones lighter, over them; a few twigs
    showing through the gaps."""
    rng = np.random.default_rng(seed)
    image = Image.new("RGB", (size, size), (20, 26, 16))
    mask_image = Image.new("L", (size, size), 0)
    draw = ImageDraw.Draw(image)
    mask = ImageDraw.Draw(mask_image)
    c = size / 2.0

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


PAINTINGS = {"moon": moon, "banner": banner, "rose_window": rose_window, "altar_frontal": altar_frontal,
             "shield_1": shield_1, "shield_2": shield_2, "shield_3": shield_3,
             "leaf_crown": leaf_crown, "leaf_shrub": leaf_shrub, "yew": yew, "twigs": twigs, "grass": grass,
             "weed_broad": weed_broad, "reeds": reeds, "ivy": ivy, "bark": bark}


def main(argv):
    OUT.mkdir(parents=True, exist_ok=True)

    for name in argv or sorted(PAINTINGS):
        path = OUT / (name + ".png")
        PAINTINGS[name]().save(path)
        print("%-14s -> %s" % (name, path.relative_to(ROOT)))

    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
