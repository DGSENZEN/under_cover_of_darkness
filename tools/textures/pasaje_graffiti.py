"""The Pasaje's graffiti (docs/superpowers/specs/2026-10-26-pasaje-market-design.md; plan Task 7, redone at the
user's word on Oct 26 2026: "actual graffiti... a metropolis where magic and the occult and the supernatural are
part of it"): sixteen pieces of the market's wall paint on a 4 x 4 sheet the set cuts into its decals.

- tags: names sprayed fast in a marker hand, slanted and joined, an underline swooped under them;
- throw-ups: fat outlined letters filled in a hurry, their outlines doubled, shine on them, the paint run;
- sigils: ward circles painted where the uncanny comes close, their band written round with glyphs, a star in them,
  an eye at the heart;
- stencils: a calavera, the eye against the evil eye, a moon and its stars, the Company's roundel crossed out.

The lettering is the invented script (tools/textures/library_glyphs.py), standing in for the user's own designs;
real words are the user's. Grain and overspray come from the user's brush sheets (textures/brushes).

    python3 tools/textures/pasaje_graffiti.py
"""

import math
import random
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter
from scipy import ndimage

sys.path.insert(0, str(Path(__file__).resolve().parent))

import brushes as brush_sheets  # noqa: E402
import library_glyphs  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "textures" / "painted" / "underground"
GRID = 4
CELL = 512
BORDER = 8
# Drawn at twice the cell, then brought down.
BIG = CELL * 2
SCRIPT_SEED = 1888
KINDS = ["tag", "tag", "tag", "tag", "throwup", "throwup", "throwup", "throwup", "sigil", "sigil", "sigil",
         "calavera", "eye", "moon", "roundel", "tag"]
# The market's paint, as it comes out of a can in the Metro's damp.
BLACK, WHITE, CHROME = (24, 22, 24), (232, 228, 216), (196, 200, 206)
RED, BLOOD, BLUE, TEAL = (204, 40, 46), (150, 24, 28), (34, 92, 196), (32, 166, 160)
YELLOW, ORANGE, PINK, GREEN, VIOLET = (236, 196, 40), (226, 104, 30), (226, 92, 150), (54, 156, 74), (122, 62, 168)
CHALK, OCHRE = (226, 222, 206), (196, 140, 52)


def spelling(seed=SCRIPT_SEED):
    """Which of the invented script's glyphs each lettered cell spells: {cell: [glyph indices]}."""
    rng = random.Random(seed + 7)
    count = len(library_glyphs.script_glyphs(seed=SCRIPT_SEED))
    out = {}
    for k, kind in enumerate(KINDS):
        if kind == "tag":
            out[k] = [rng.randrange(count) for _ in range(rng.randint(4, 6))]
        elif kind == "throwup":
            out[k] = [rng.randrange(count) for _ in range(rng.randint(3, 4))]
        elif kind == "sigil":
            out[k] = [rng.randrange(count) for _ in range(10)]
    return out


# --- drawing ------------------------------------------------------------------------------------------

def _canvas():
    return Image.new("L", (BIG, BIG), 0)


def _draw_glyph(draw, strokes, at, size, width, slant=0.0, turn=0.0):
    """A glyph's strokes (its cell 0..1, y down) drawn `size` across with its middle at `at`, slanted, turned."""
    c, s = math.cos(turn), math.sin(turn)

    def place(px, py):
        u, v = (px - 0.5 + slant * (0.5 - py)) * size, (py - 0.5) * size
        return (at[0] + u * c - v * s, at[1] + u * s + v * c)

    for stroke in strokes:
        pts = [place(px, py) for px, py in stroke]
        if len(pts) > 1:
            draw.line(pts, fill=255, width=max(1, int(width)), joint="curve")
        for px, py in (pts if len(pts) == 1 else [pts[0], pts[-1]]):
            r = width * (0.8 if len(pts) == 1 else 0.5)
            draw.ellipse((px - r, py - r, px + r, py + r), fill=255)


def _word(glyphs, script, rng, size, width, advance, slant, middle_y, wave):
    """A word of glyphs on one canvas, centred, its baseline waving."""
    ink = _canvas()
    draw = ImageDraw.Draw(ink)
    span = advance * size * (len(glyphs) - 1)
    for i, g in enumerate(glyphs):
        x = BIG / 2 - span / 2 + i * advance * size
        y = middle_y + wave * size * math.sin(i * 1.3 + rng.uniform(0, 0.6))
        _draw_glyph(draw, script[g], (x, y), size * rng.uniform(0.92, 1.1), width, slant)
    return ink, span


def _drips(mask, rng, count, width, reach):
    """Runs of paint down from the lowest edges of `mask`."""
    ink = np.asarray(mask) > 128
    cols = np.nonzero(ink.any(axis=0))[0]
    out = _canvas()
    draw = ImageDraw.Draw(out)
    if cols.size == 0:
        return out
    for _ in range(count):
        x = int(rng.choice(cols))
        y = int(np.nonzero(ink[:, x])[0].max())
        length = reach * rng.uniform(0.3, 1.0)
        for i in range(16):
            f = i / 16
            w = width * (1.0 - 0.5 * f)
            draw.rectangle((x - w / 2, y + length * f, x + w / 2, y + length * (f + 1 / 16) + 1), fill=255)
        draw.ellipse((x - width * 0.6, y + length - width * 0.6, x + width * 0.6, y + length + width * 0.8), fill=255)
    return out


def _f(mask):
    """A canvas as a float mask at the cell's size."""
    return np.asarray(mask.resize((CELL, CELL), Image.LANCZOS), np.float64) / 255.0


def _grow(ink, r):
    """`ink` (bool, at BIG) grown by `r` px."""
    return ndimage.distance_transform_edt(~ink) <= r


def _img(ink):
    return Image.fromarray((ink * 255).astype(np.uint8), "L")


# --- the pieces --------------------------------------------------------------------------------------

def _tag(glyphs, script, rng):
    size = BIG * rng.uniform(0.24, 0.28)
    ink, span = _word(glyphs, script, rng, size, BIG * 0.024, 0.56, rng.uniform(0.25, 0.38), BIG * 0.46, 0.06)
    draw = ImageDraw.Draw(ink)
    # The underline swooped under it, its end hooked back.
    y = BIG * 0.46 + size * 0.62
    x0, x1 = BIG / 2 - span / 2 - size * 0.3, BIG / 2 + span / 2 + size * 0.45
    pts = [(x0 + (x1 - x0) * t, y + size * 0.12 * math.sin(math.pi * t)) for t in np.linspace(0, 1, 14)]
    pts += [(x1 + size * 0.08, y - size * 0.25)]
    draw.line(pts, fill=255, width=int(BIG * 0.014), joint="curve")
    paint = [BLACK, WHITE, RED, CHROME, BLUE, TEAL][rng.randrange(6)]
    layers = []
    if rng.random() < 0.5:
        shadow = _img(np.roll(np.asarray(ink) > 128, (6, 6), axis=(0, 1)))
        layers.append((_f(shadow), [BLACK, BLUE, RED][rng.randrange(3)] if paint != BLACK else WHITE, "spray"))
    layers.append((_f(ink), paint, "spray"))
    layers.append((_f(_drips(ink, rng, rng.randint(1, 4), BIG * 0.008, BIG * 0.12)), paint, "spray"))
    return layers


def _throwup(glyphs, script, rng):
    size = BIG * rng.uniform(0.3, 0.34)
    word, _ = _word(glyphs, script, rng, size, BIG * 0.06, 0.52, rng.uniform(0.05, 0.15), BIG * 0.47, 0.04)
    fill = np.asarray(word) > 128
    outline = _grow(fill, BIG * 0.018)
    outer = np.roll(_grow(outline, BIG * 0.012), (BIG // 80, BIG // 110), axis=(0, 1))
    shine = fill & ~np.roll(fill, (BIG // 90, BIG // 90), axis=(0, 1))
    fill_c, line_c, outer_c = [(CHROME, BLACK, RED), (PINK, BLACK, TEAL), (YELLOW, BLACK, BLUE), (TEAL, BLACK, VIOLET),
                               (ORANGE, BLACK, WHITE)][rng.randrange(5)]
    layers = [(_f(_img(outer)), outer_c, "spray"), (_f(_img(outline)), line_c, "spray"), (_f(_img(fill)), fill_c, "spray"),
              (_f(_img(shine)), WHITE, "spray"),
              (_f(_drips(_img(fill), rng, rng.randint(3, 6), BIG * 0.012, BIG * 0.16)), fill_c, "spray")]
    # A few sparkles on it.
    sparkle = _canvas()
    d = ImageDraw.Draw(sparkle)
    for _ in range(rng.randint(2, 4)):
        x, y = rng.uniform(0.2, 0.8) * BIG, rng.uniform(0.3, 0.6) * BIG
        r = BIG * rng.uniform(0.018, 0.03)
        d.polygon([(x, y - r), (x + r * 0.2, y - r * 0.2), (x + r, y), (x + r * 0.2, y + r * 0.2), (x, y + r),
                   (x - r * 0.2, y + r * 0.2), (x - r, y), (x - r * 0.2, y - r * 0.2)], fill=255)
    layers.append((_f(sparkle), WHITE, "spray"))
    return layers


def _eye_mask(draw, cx, cy, w, h, iris, pupil):
    """An almond eye: its lids, its iris, its pupil (three canvases' worth drawn on one: lids 255, iris cut)."""
    top = [(cx + w * (t - 0.5), cy - h * math.sin(math.pi * t)) for t in np.linspace(0, 1, 20)]
    low = [(cx + w * (0.5 - t), cy + h * 0.8 * math.sin(math.pi * t)) for t in np.linspace(0, 1, 20)]
    draw.polygon(top + low, fill=255)
    draw.ellipse((cx - iris, cy - iris, cx + iris, cy + iris), fill=0)
    draw.ellipse((cx - pupil, cy - pupil, cx + pupil, cy + pupil), fill=255)


def _sigil(glyphs, script, rng, paint=None, line=0.011):
    cx = cy = BIG / 2
    r1, r2 = BIG * 0.44, BIG * 0.35
    line = BIG * line
    ink = _canvas()
    draw = ImageDraw.Draw(ink)
    for r in (r1, r2):
        draw.ellipse((cx - r, cy - r, cx + r, cy + r), outline=255, width=int(line))
    band = (r1 + r2) / 2
    for i, g in enumerate(glyphs):
        a = 2 * math.pi * i / len(glyphs) - math.pi / 2
        _draw_glyph(draw, script[g], (cx + band * math.cos(a), cy + band * math.sin(a)), (r1 - r2) * 0.95, line * 0.9,
                    turn=a + math.pi / 2)
    points = rng.choice([5, 7, 9])
    step = 2 if points == 5 else 3
    star = [(cx + r2 * 0.94 * math.cos(2 * math.pi * k / points - math.pi / 2),
             cy + r2 * 0.94 * math.sin(2 * math.pi * k / points - math.pi / 2)) for k in range(points)]
    for k in range(points):
        draw.line([star[k], star[(k + step) % points]], fill=255, width=int(line))
    r3 = BIG * 0.11
    draw.ellipse((cx - r3, cy - r3, cx + r3, cy + r3), outline=255, width=int(line))
    _eye_mask(draw, cx, cy, r3 * 1.5, r3 * 0.55, r3 * 0.32, r3 * 0.14)
    paint = paint or [CHALK, BLOOD, OCHRE][rng.randrange(3)]
    return [(_f(ink), paint, "chalk" if paint == CHALK else "brush")]


def _calavera(rng):
    ink = _canvas()
    d = ImageDraw.Draw(ink)
    s = BIG
    d.ellipse((s * 0.2, s * 0.12, s * 0.8, s * 0.66), fill=255)
    d.rounded_rectangle((s * 0.3, s * 0.5, s * 0.7, s * 0.82), radius=s * 0.06, fill=255)
    for ex in (0.38, 0.62):
        d.ellipse((s * (ex - 0.09), s * 0.36, s * (ex + 0.09), s * 0.52), fill=0)
        for k in range(8):
            a = 2 * math.pi * k / 8
            px, py = s * ex + s * 0.125 * math.cos(a), s * 0.44 + s * 0.11 * math.sin(a)
            d.ellipse((px - s * 0.014, py - s * 0.014, px + s * 0.014, py + s * 0.014), fill=0)
    d.polygon([(s * 0.5, s * 0.62), (s * 0.45, s * 0.55), (s * 0.55, s * 0.55)], fill=0)
    for k in range(6):
        x = s * (0.36 + 0.056 * k)
        d.rectangle((x, s * 0.68, x + s * 0.04, s * 0.77), fill=0)
    for k in range(5):
        a = 2 * math.pi * k / 5 - math.pi / 2
        px, py = s * 0.5 + s * 0.045 * math.cos(a), s * 0.25 + s * 0.045 * math.sin(a)
        d.ellipse((px - s * 0.028, py - s * 0.028, px + s * 0.028, py + s * 0.028), fill=0)
    return [(_f(ink), [WHITE, TEAL, PINK, BLACK][rng.randrange(4)], "stencil")]


def _eye(rng):
    s = BIG
    white, blue, black = _canvas(), _canvas(), _canvas()
    _eye_mask(ImageDraw.Draw(white), s / 2, s * 0.46, s * 0.7, s * 0.24, 0.0, 0.0)
    ImageDraw.Draw(blue).ellipse((s * 0.37, s * 0.33, s * 0.63, s * 0.59), fill=255)
    ImageDraw.Draw(blue).ellipse((s * 0.43, s * 0.39, s * 0.57, s * 0.53), fill=0)
    ImageDraw.Draw(black).ellipse((s * 0.465, s * 0.425, s * 0.535, s * 0.495), fill=255)
    lashes = _canvas()
    d = ImageDraw.Draw(lashes)
    for k in range(11):
        t = 0.1 + 0.8 * k / 10
        x, y = s / 2 + s * 0.7 * (t - 0.5), s * 0.46 - s * 0.24 * math.sin(math.pi * t)
        a = math.atan2(y - s * 0.6, x - s / 2)
        d.line([(x, y), (x + s * 0.08 * math.cos(a), y + s * 0.08 * math.sin(a))], fill=255, width=int(s * 0.012))
    tear = _canvas()
    ImageDraw.Draw(tear).polygon([(s * 0.5, s * 0.66), (s * 0.47, s * 0.74), (s * 0.5, s * 0.78), (s * 0.53, s * 0.74)],
                                 fill=255)
    return [(_f(white), WHITE, "spray"), (_f(blue), BLUE, "spray"), (_f(black), BLACK, "spray"),
            (_f(lashes), BLACK, "spray"), (_f(tear), BLUE, "spray")]


def _moon(rng):
    s = BIG
    ink = np.zeros((BIG, BIG), bool)
    y, x = np.mgrid[0:BIG, 0:BIG]
    ink |= np.hypot(x - s * 0.48, y - s * 0.48) < s * 0.3
    ink &= ~(np.hypot(x - s * 0.6, y - s * 0.4) < s * 0.27)
    stars = _canvas()
    d = ImageDraw.Draw(stars)
    for _ in range(5):
        cx, cy, r = rng.uniform(0.55, 0.85) * s, rng.uniform(0.2, 0.75) * s, s * rng.uniform(0.02, 0.045)
        d.polygon([(cx, cy - r), (cx + r * 0.25, cy - r * 0.25), (cx + r, cy), (cx + r * 0.25, cy + r * 0.25),
                   (cx, cy + r), (cx - r * 0.25, cy + r * 0.25), (cx - r, cy), (cx - r * 0.25, cy - r * 0.25)], fill=255)
    paint = [YELLOW, CHALK, ORANGE][rng.randrange(3)]
    moon = _img(ink)
    return [(_f(moon), paint, "spray"), (_f(stars), paint, "spray"),
            (_f(_drips(moon, rng, 3, BIG * 0.01, BIG * 0.12)), paint, "spray")]


def _roundel(rng):
    s = BIG
    y, x = np.mgrid[0:BIG, 0:BIG]
    d = np.hypot(x - s / 2, y - s / 2)
    ring = (d < s * 0.33) & (d > s * 0.24)
    bar = (np.abs(y - s / 2) < s * 0.055) & (np.abs(x - s / 2) < s * 0.4)
    cross = _canvas()
    c = ImageDraw.Draw(cross)
    c.line([(s * 0.18, s * 0.2), (s * 0.82, s * 0.8)], fill=255, width=int(s * 0.05))
    c.line([(s * 0.8, s * 0.18), (s * 0.22, s * 0.82)], fill=255, width=int(s * 0.05))
    return [(_f(_img(ring)), BLUE, "stencil"), (_f(_img(bar)), WHITE, "stencil"), (_f(cross), RED, "spray"),
            (_f(_drips(cross, rng, 4, BIG * 0.014, BIG * 0.14)), RED, "spray")]


# --- the sheet ---------------------------------------------------------------------------------------

def _grain(name, brushes_dir):
    values = brush_sheets.load(name, brushes_dir)
    image = Image.fromarray((values * 255).astype(np.uint8), "L").resize((CELL, CELL), Image.BILINEAR)
    return np.asarray(image, np.float64) / 255.0


def _cell(layers, grain):
    """The cell's layers painted one over another: spray misted and grained, chalk broken by the grain, stencils
    sharp with a little mist, brushed paint streaked."""
    rgb = np.zeros((CELL, CELL, 3))
    alpha = np.zeros((CELL, CELL))
    for mask, colour, how in layers:
        if how == "spray":
            mist = ndimage.gaussian_filter(mask, 6.0)
            a = np.clip(mask * (0.7 + 0.45 * grain), 0, 1)
            a = np.maximum(a, np.clip(mist * 0.35, 0, 0.3) * (0.5 + grain))
        elif how == "chalk":
            a = mask * np.where(grain > 0.4, 0.95, 0.45)
        elif how == "stencil":
            a = np.maximum(mask * 0.95, np.clip(ndimage.gaussian_filter(mask, 2.5) * 0.25, 0, 0.2))
        else:
            a = np.clip(mask * (0.75 + 0.35 * grain), 0, 1)
        shade = (0.86 + 0.22 * grain)[..., None]
        rgb = rgb * (1 - a[..., None]) + np.array(colour, np.float64) * shade * a[..., None]
        alpha = alpha + a * (1 - alpha)
    out = np.dstack([np.clip(rgb / np.maximum(alpha, 1e-6)[..., None] * (alpha > 0)[..., None], 0, 255), alpha * 255])
    out = out.round().astype(np.uint8)
    out[:BORDER, :, 3] = out[-BORDER:, :, 3] = 0
    out[:, :BORDER, 3] = out[:, -BORDER:, 3] = 0
    return out


def make(brushes_dir=brush_sheets.BRUSHES):
    """The sheet: GRID x GRID pieces, each in its own cell, laid out as KINDS."""
    rng = random.Random(1934)
    script = library_glyphs.script_glyphs(seed=SCRIPT_SEED)
    spelt = spelling()
    grains = [_grain("brush_%02d" % i, brushes_dir) for i in range(5)]
    sheet = np.zeros((GRID * CELL, GRID * CELL, 4), np.uint8)
    for k, kind in enumerate(KINDS):
        if kind == "tag":
            layers = _tag(spelt[k], script, rng)
        elif kind == "throwup":
            layers = _throwup(spelt[k], script, rng)
        elif kind == "sigil":
            layers = _sigil(spelt[k], script, rng)
        else:
            layers = {"calavera": _calavera, "eye": _eye, "moon": _moon, "roundel": _roundel}[kind](rng)
        j, i = divmod(k, GRID)
        sheet[j * CELL:(j + 1) * CELL, i * CELL:(i + 1) * CELL] = _cell(layers, grains[k % len(grains)])
    return Image.fromarray(sheet, "RGBA")


# --- the wards ------------------------------------------------------------------------------------------

# The wards' sheet (2 x 2): the circle drawn round a rite on the floor in charcoal (chalk and ochre are lost on the
# chequer's cream and terracotta), its glyph band, its star, salt dropped round it; the arc drawn out from a wall, the
# candles' places marked on it; the salt line laid across a threshold; the ward sigil painted on a wall beside a
# doorway.
WARD_GRID = 2
WARDS = ["circle", "arc", "salt", "ward"]
SALT = (240, 238, 232)


def _salt_dots(draw, rng, centre, radius, spread, count):
    for _ in range(count):
        a = rng.uniform(0, 2 * math.pi)
        d = radius + rng.gauss(0, spread)
        x, y = centre[0] + d * math.cos(a), centre[1] + d * math.sin(a)
        r = rng.uniform(1.5, 3.5)
        draw.ellipse((x - r, y - r, x + r, y + r), fill=255)


def _ward_circle(script, rng):
    layers = _sigil([rng.randrange(len(script)) for _ in range(12)], script, rng, BLACK, line=0.024)
    salt = _canvas()
    _salt_dots(ImageDraw.Draw(salt), rng, (BIG / 2, BIG / 2), BIG * 0.465, BIG * 0.008, 900)
    return layers + [(_f(salt), SALT, "stencil")]


def _ward_arc(script, rng):
    """The arc drawn in charcoal out from a wall (the image's top), its band written round, the candles' places ringed on it."""
    cx, cy = BIG / 2, BIG * 0.08
    r1, r2 = BIG * 0.44, BIG * 0.34
    line = BIG * 0.024
    ink = _canvas()
    draw = ImageDraw.Draw(ink)
    for r in (r1, r2):
        draw.arc((cx - r, cy - r, cx + r, cy + r), 0, 180, fill=255, width=int(line))
    draw.line([(cx - r1, cy), (cx + r1, cy)], fill=255, width=int(line))
    band = (r1 + r2) / 2
    for k in range(9):
        a = math.pi * (k + 0.5) / 9
        g = script[rng.randrange(len(script))]
        _draw_glyph(draw, g, (cx + band * math.cos(a), cy + band * math.sin(a)), (r1 - r2) * 0.9, line * 0.9,
                    turn=a - math.pi / 2)
    for k in range(5):
        a = math.pi * k / 4
        x, y = cx + r1 * 1.02 * math.cos(a), cy + r1 * 1.02 * math.sin(a)
        rr = BIG * 0.03
        draw.ellipse((x - rr, y - rr, x + rr, y + rr), outline=255, width=int(line * 0.8))
    _eye_mask(draw, cx, cy + BIG * 0.17, BIG * 0.16, BIG * 0.06, BIG * 0.025, BIG * 0.011)
    return [(_f(ink), BLACK, "brush")]


def _salt_line(rng):
    """Salt poured across a threshold: a line of grains, thick down its middle, scuffed where feet crossed it."""
    salt = _canvas()
    draw = ImageDraw.Draw(salt)
    for _ in range(4200):
        x = rng.uniform(0.06, 0.94) * BIG
        if abs(x - BIG * 0.4) < BIG * 0.05 and rng.random() < 0.7:
            continue
        y = BIG / 2 + rng.gauss(0, BIG * 0.09)
        r = rng.uniform(3.0, 7.0)
        draw.ellipse((x - r, y - r, x + r, y + r), fill=255)
    return [(_f(salt), SALT, "stencil")]


def _ward_sigil(script, rng):
    """A ward painted on a wall by a doorway: rings, a cross whose arms end in crossbars (centred on the arm, never
    turned one way: a hooked cross would read as something else entirely), dots, an eye at its heart, in blood-red
    ochre."""
    cx = cy = BIG / 2
    line = BIG * 0.02
    ink = _canvas()
    draw = ImageDraw.Draw(ink)
    for r in (BIG * 0.4, BIG * 0.3):
        draw.ellipse((cx - r, cy - r, cx + r, cy + r), outline=255, width=int(line))
    for k in range(4):
        a = math.pi / 2 * k
        x0, y0 = cx + BIG * 0.1 * math.cos(a), cy + BIG * 0.1 * math.sin(a)
        x1, y1 = cx + BIG * 0.36 * math.cos(a), cy + BIG * 0.36 * math.sin(a)
        draw.line([(x0, y0), (x1, y1)], fill=255, width=int(line))
        h = a + math.pi / 2
        bar = BIG * 0.06
        draw.line([(x1 - bar * math.cos(h), y1 - bar * math.sin(h)), (x1 + bar * math.cos(h), y1 + bar * math.sin(h))],
                  fill=255, width=int(line))
        d = a + math.pi / 4
        x, y, r = cx + BIG * 0.35 * math.cos(d), cy + BIG * 0.35 * math.sin(d), BIG * 0.022
        draw.ellipse((x - r, y - r, x + r, y + r), fill=255)
    _eye_mask(draw, cx, cy, BIG * 0.16, BIG * 0.06, BIG * 0.026, BIG * 0.012)
    return [(_f(ink), BLOOD, "brush")]


def make_wards(brushes_dir=brush_sheets.BRUSHES):
    """The wards' sheet: WARD_GRID x WARD_GRID, laid out as WARDS."""
    rng = random.Random(1935)
    script = library_glyphs.script_glyphs(seed=SCRIPT_SEED)
    grains = [_grain("brush_%02d" % i, brushes_dir) for i in range(5)]
    sheet = np.zeros((WARD_GRID * CELL, WARD_GRID * CELL, 4), np.uint8)
    for k, kind in enumerate(WARDS):
        layers = {"circle": lambda: _ward_circle(script, rng), "arc": lambda: _ward_arc(script, rng),
                  "salt": lambda: _salt_line(rng), "ward": lambda: _ward_sigil(script, rng)}[kind]()
        j, i = divmod(k, WARD_GRID)
        sheet[j * CELL:(j + 1) * CELL, i * CELL:(i + 1) * CELL] = _cell(layers, grains[(k + 2) % len(grains)])
    return Image.fromarray(sheet, "RGBA")


if __name__ == "__main__":
    OUT.mkdir(parents=True, exist_ok=True)
    for name, made in (("pasaje_graffiti.png", make), ("pasaje_wards.png", make_wards)):
        path = OUT / name
        made().save(path)
        print("wrote", path.relative_to(ROOT))
