"""The Pasaje's bills (docs/superpowers/specs/2026-10-26-pasaje-market-design.md; the user's word on Oct 26 2026: "torn
bills... environmental storytelling that tell this is a metropolis where magic and the occult and the supernatural
are part of it"): what the city pastes on the market's walls, a 4 x 3 sheet the set cuts into its decals.

Cheap printing in one or two inks on aged paper, every one torn: the missing person, their face scratched out of the
photograph; the reward for a nahual gone astray; the curandero's card; the exorcist's handbill; a cabaret's night; a
lucha night; the Company's notice, defaced; a lotería; a wanted bill for a spirit; a fiesta's. Their fields for words
are left empty, ruled boxes, for the user's words. And two sheets of tatters: scraps of older bills torn back.

Paper grain, tearing, damp and paste come from the user's brush sheets (textures/brushes).

    python3 tools/textures/pasaje_bills.py
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

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "textures" / "painted" / "underground"
COLS, ROWS = 4, 3
CELL = 512
BIG = CELL * 2
BORDER = 8
BILLS = ["missing", "nahual_reward", "curandero", "exorcist", "cabaret", "lucha_night", "company_notice", "loteria",
         "wanted_spirit", "fiesta", "tatters", "tatters"]

# (Off the tiles' cream: newsprint gone yellow, white gone cool, the rest the street's bright stock.)
NEWSPRINT, WHITE, YELLOW, PINK = (204, 188, 146), (208, 218, 224), (236, 200, 90), (236, 150, 168)
GREEN, KRAFT, NIGHT = (176, 208, 164), (192, 156, 116), (40, 30, 36)
INK, RED, BLUE, GOLD = (30, 26, 28), (178, 38, 40), (40, 70, 150), (212, 168, 66)
ORANGE, TEAL, VIOLET, GREY = (220, 110, 34), (36, 150, 146), (96, 64, 120), (122, 118, 110)

# Each bill's sheet within its cell (fractions: x from, y from, x to, y to) and its paper.
SHEETS = {"missing": ((0.16, 0.08, 0.84, 0.92), NEWSPRINT), "nahual_reward": ((0.12, 0.1, 0.88, 0.9), YELLOW),
          "curandero": ((0.26, 0.24, 0.74, 0.76), WHITE), "exorcist": ((0.18, 0.08, 0.82, 0.92), WHITE),
          "cabaret": ((0.16, 0.06, 0.84, 0.94), NIGHT), "lucha_night": ((0.12, 0.08, 0.88, 0.92), YELLOW),
          "company_notice": ((0.14, 0.06, 0.86, 0.94), WHITE), "loteria": ((0.14, 0.1, 0.86, 0.9), PINK),
          "wanted_spirit": ((0.16, 0.08, 0.84, 0.92), KRAFT), "fiesta": ((0.14, 0.1, 0.86, 0.9), GREEN)}


class Sheet:
    """A bill's paper on the big canvas: points in its own frame (u, v from 0 to 1 across and down it)."""

    def __init__(self, box):
        self.x0, self.y0, self.x1, self.y1 = (c * BIG for c in box)
        self.ink = Image.new("RGBA", (BIG, BIG), (0, 0, 0, 0))
        self.draw = ImageDraw.Draw(self.ink)

    def p(self, u, v):
        return (self.x0 + u * (self.x1 - self.x0), self.y0 + v * (self.y1 - self.y0))

    def box(self, u0, v0, u1, v1):
        (a, b), (c, d) = self.p(u0, v0), self.p(u1, v1)
        return (a, b, c, d)

    def w(self, f):
        return f * (self.x1 - self.x0)

    def field(self, u0, v0, u1, v1, colour=INK, width=3):
        """An empty ruled field where its words go (the user's)."""
        self.draw.rectangle(self.box(u0, v0, u1, v1), outline=colour + (255,), width=width)

    def ellipse(self, u, v, ru, rv, colour, outline=None, width=0):
        (cx, cy) = self.p(u, v)
        rx, ry = self.w(ru), ru * 0 + rv * (self.y1 - self.y0)
        self.draw.ellipse((cx - rx, cy - ry, cx + rx, cy + ry), fill=None if colour is None else colour + (255,),
                          outline=None if outline is None else outline + (255,), width=width)

    def poly(self, points, colour):
        self.draw.polygon([self.p(u, v) for u, v in points], fill=colour + (255,))

    def line(self, points, colour, width):
        self.draw.line([self.p(u, v) for u, v in points], fill=colour + (255,), width=int(width), joint="curve")

    def star(self, u, v, r, colour, points=5):
        pts = []
        for k in range(points * 2):
            a = math.pi * k / points - math.pi / 2
            rr = r if k % 2 == 0 else r * 0.45
            pts.append((u + rr * math.cos(a), v + rr * math.sin(a) * (self.x1 - self.x0) / (self.y1 - self.y0)))
        self.poly(pts, colour)


# --- the bills -------------------------------------------------------------------------------------------

def _missing(s, rng):
    s.field(0.1, 0.04, 0.9, 0.15)
    s.draw.rectangle(s.box(0.18, 0.19, 0.82, 0.62), fill=GREY + (255,))
    s.ellipse(0.5, 0.35, 0.13, 0.08, (84, 80, 76))
    s.ellipse(0.5, 0.6, 0.27, 0.12, (84, 80, 76))
    s.draw.rectangle(s.box(0.18, 0.62, 0.82, 0.64), fill=NEWSPRINT + (255,))
    # Their face scratched out of the photograph, over and over.
    for _ in range(46):
        u, v = rng.uniform(0.38, 0.62), rng.uniform(0.25, 0.45)
        s.line([(u, v), (u + rng.uniform(-0.12, 0.12), v + rng.uniform(-0.06, 0.06))],
               INK if rng.random() < 0.7 else (220, 216, 206), rng.uniform(2, 5))
    for v in (0.68, 0.76, 0.84):
        s.field(0.1, v, 0.9, v + 0.06)
    s.ellipse(0.76, 0.74, 0.11, 0.07, None, RED, 5)


def _nahual_reward(s, rng):
    s.field(0.08, 0.04, 0.92, 0.17, INK, 4)
    s.ellipse(0.46, 0.46, 0.27, 0.1, INK)
    s.ellipse(0.76, 0.36, 0.09, 0.07, INK)
    s.poly([(0.7, 0.32), (0.72, 0.22), (0.76, 0.31)], INK)
    s.poly([(0.78, 0.31), (0.83, 0.22), (0.83, 0.34)], INK)
    s.poly([(0.82, 0.36), (0.94, 0.4), (0.82, 0.42)], INK)
    for u in (0.26, 0.34, 0.54, 0.62):
        s.draw.rectangle(s.box(u, 0.5, u + 0.035, 0.64), fill=INK + (255,))
    s.line([(0.2, 0.44), (0.1, 0.36), (0.12, 0.26)], INK, s.w(0.03))
    # Its eyes still burning in the print.
    for u in (0.75, 0.8):
        s.ellipse(u, 0.345, 0.02, 0.012, (250, 236, 120))
    s.field(0.18, 0.69, 0.82, 0.84, RED, 6)
    s.field(0.22, 0.715, 0.78, 0.815, RED, 2)
    for k in range(6):
        u = 0.15 + 0.14 * k
        s.ellipse(u, 0.91, 0.02, 0.012, INK)
        for d in (-0.025, 0.0, 0.025):
            s.ellipse(u + d, 0.885, 0.008, 0.006, INK)


def _curandero(s, rng):
    for k in range(22):
        a = 2 * math.pi * k / 22
        s.ellipse(0.5 + 0.43 * math.cos(a), 0.5 + 0.43 * math.sin(a), 0.035, 0.02, (60, 130, 70))
    s.draw.rounded_rectangle(s.box(0.36, 0.34, 0.64, 0.64), radius=s.w(0.05), fill=INK + (255,))
    for k, (u, top) in enumerate(((0.38, 0.14), (0.45, 0.1), (0.52, 0.11), (0.59, 0.16))):
        s.draw.rounded_rectangle(s.box(u, top, u + 0.06, 0.38), radius=s.w(0.03), fill=INK + (255,))
    s.draw.rounded_rectangle(s.box(0.24, 0.42, 0.38, 0.5), radius=s.w(0.03), fill=INK + (255,))
    s.ellipse(0.5, 0.5, 0.09, 0.04, WHITE)
    s.ellipse(0.5, 0.5, 0.035, 0.03, (60, 130, 70))
    s.ellipse(0.5, 0.5, 0.015, 0.012, INK)
    s.field(0.16, 0.72, 0.84, 0.8)
    s.field(0.22, 0.83, 0.78, 0.89)


def _exorcist(s, rng):
    s.field(0.1, 0.04, 0.9, 0.14, INK, 4)
    s.ellipse(0.5, 0.45, 0.3, 0.18, VIOLET)
    s.poly([(0.28, 0.32), (0.24, 0.17), (0.36, 0.3)], VIOLET)
    s.poly([(0.72, 0.32), (0.76, 0.17), (0.64, 0.3)], VIOLET)
    for k in range(16):
        a = 2 * math.pi * k / 16
        s.line([(0.5 + 0.2 * math.cos(a), 0.45 + 0.13 * math.sin(a)), (0.5 + 0.4 * math.cos(a), 0.45 + 0.26 * math.sin(a))],
               INK, 3)
    s.draw.rectangle(s.box(0.46, 0.22, 0.54, 0.72), fill=INK + (255,))
    s.draw.rectangle(s.box(0.32, 0.34, 0.68, 0.41), fill=INK + (255,))
    for v in (0.77, 0.85):
        s.field(0.12, v, 0.88, v + 0.06)


def _cabaret(s, rng):
    for k in range(9):
        a = math.pi * (0.1 + 0.8 * k / 8)
        s.line([(0.5, 0.7), (0.5 + 0.45 * math.cos(a + math.pi), 0.7 + 0.42 * math.sin(a + math.pi))], GOLD, 4)
    for r in (0.18, 0.3):
        (cx, cy) = s.p(0.5, 0.7)
        rr = s.w(r)
        s.draw.arc((cx - rr, cy - rr, cx + rr, cy + rr), 180, 360, fill=GOLD + (255,), width=5)
    s.ellipse(0.76, 0.18, 0.08, 0.05, GOLD)
    s.ellipse(0.79, 0.165, 0.07, 0.045, NIGHT)
    for u, v in ((0.2, 0.15), (0.3, 0.25), (0.62, 0.12), (0.15, 0.4)):
        s.star(u, v, 0.03, GOLD)
    s.draw.rectangle(s.box(0.44, 0.46, 0.56, 0.6), fill=GOLD + (255,))
    s.draw.rectangle(s.box(0.38, 0.6, 0.62, 0.63), fill=GOLD + (255,))
    s.line([(0.66, 0.64), (0.7, 0.4)], GOLD, 5)
    s.field(0.12, 0.76, 0.88, 0.86, GOLD, 4)
    s.field(0.25, 0.88, 0.75, 0.94, GOLD, 2)


def _mask(s, u, v, colour):
    s.ellipse(u, v, 0.15, 0.12, colour)
    for d in (-0.055, 0.055):
        s.ellipse(u + d, v - 0.02, 0.04, 0.02, YELLOW)
    s.ellipse(u, v + 0.06, 0.04, 0.02, YELLOW)


def _lucha_night(s, rng):
    s.field(0.08, 0.04, 0.92, 0.17, RED, 5)
    _mask(s, 0.3, 0.42, RED)
    _mask(s, 0.7, 0.42, BLUE)
    for v in (0.58, 0.62, 0.66):
        s.line([(0.06, v), (0.94, v)], INK, 3)
    for u in (0.5, 0.15, 0.85):
        s.star(u, 0.28, 0.04, INK)
    s.field(0.12, 0.72, 0.88, 0.82, BLUE, 4)
    s.field(0.2, 0.85, 0.8, 0.92, INK, 2)


def _company_notice(s, rng):
    (cx, cy) = s.p(0.5, 0.11)
    r = s.w(0.08)
    s.draw.ellipse((cx - r, cy - r, cx + r, cy + r), outline=BLUE + (255,), width=8)
    s.draw.rectangle((cx - r * 1.3, cy - r * 0.2, cx + r * 1.3, cy + r * 0.2), fill=BLUE + (255,))
    s.field(0.1, 0.2, 0.9, 0.28, BLUE, 3)
    # Its ruled lines for the notice's words (the user's), in their blocks.
    for block, (v0, n) in enumerate(((0.32, 6), (0.55, 5), (0.74, 4))):
        for k in range(n):
            v = v0 + 0.032 * k
            s.line([(0.12, v), (0.88 if k < n - 1 else 0.6, v)], (150, 150, 156), 2)
    s.ellipse(0.74, 0.86, 0.1, 0.05, None, RED, 5)
    # Defaced: sprayed over with a cross.
    s.line([(0.12, 0.3), (0.88, 0.82)], INK, s.w(0.05))
    s.line([(0.86, 0.3), (0.14, 0.84)], INK, s.w(0.05))


def _loteria(s, rng):
    cards = [((0.06, 0.06), "sun"), ((0.52, 0.06), "moon"), ((0.06, 0.52), "heart"), ((0.52, 0.52), "skull")]
    for (u, v), icon in cards:
        s.draw.rectangle(s.box(u, v, u + 0.42, v + 0.42), fill=WHITE + (255,), outline=RED + (255,), width=6)
        cu, cv = u + 0.21, v + 0.17
        if icon == "sun":
            for k in range(12):
                a = 2 * math.pi * k / 12
                s.line([(cu, cv), (cu + 0.13 * math.cos(a), cv + 0.09 * math.sin(a))], ORANGE, 5)
            s.ellipse(cu, cv, 0.07, 0.05, YELLOW)
        elif icon == "moon":
            s.ellipse(cu, cv, 0.09, 0.065, BLUE)
            s.ellipse(cu + 0.04, cv - 0.02, 0.08, 0.06, WHITE)
        elif icon == "heart":
            s.ellipse(cu - 0.045, cv - 0.02, 0.05, 0.035, RED)
            s.ellipse(cu + 0.045, cv - 0.02, 0.05, 0.035, RED)
            s.poly([(cu - 0.094, cv - 0.01), (cu + 0.094, cv - 0.01), (cu, cv + 0.08)], RED)
        else:
            s.ellipse(cu, cv - 0.01, 0.08, 0.06, INK)
            for d in (-0.035, 0.035):
                s.ellipse(cu + d, cv - 0.015, 0.022, 0.016, WHITE)
            s.draw.rectangle(s.box(cu - 0.045, cv + 0.04, cu + 0.045, cv + 0.075), fill=INK + (255,))
        s.field(u + 0.05, v + 0.32, u + 0.37, v + 0.38, INK, 2)


def _wanted_spirit(s, rng):
    s.field(0.1, 0.04, 0.9, 0.15, INK, 5)
    ghost = Image.new("L", (BIG, BIG), 0)
    g = ImageDraw.Draw(ghost)
    for k in range(14):
        u = 0.5 + 0.08 * math.sin(k * 1.7)
        v = 0.25 + 0.03 * k
        (cx, cy) = s.p(u, v)
        r = s.w(0.12 + 0.05 * math.sin(k))
        g.ellipse((cx - r, cy - r * 0.8, cx + r, cy + r * 0.8), fill=255)
    ghost = ghost.filter(ImageFilter.GaussianBlur(14))
    layer = Image.new("RGBA", (BIG, BIG), (70, 60, 80, 0))
    layer.putalpha(ghost.point(lambda a: int(a * 0.85)))
    s.ink.alpha_composite(layer)
    for d in (-0.06, 0.06):
        s.ellipse(0.5 + d, 0.32, 0.035, 0.028, INK)
    s.field(0.15, 0.76, 0.85, 0.86, INK, 4)


def _fiesta(s, rng):
    s.line([(0.02, 0.08), (0.98, 0.1)], INK, 2)
    colours = [PINK, ORANGE, TEAL, YELLOW, VIOLET]
    for k in range(9):
        u = 0.06 + 0.105 * k
        s.poly([(u, 0.085), (u + 0.09, 0.09), (u + 0.045, 0.2)], colours[k % len(colours)])
    for k in range(12):
        a = 2 * math.pi * k / 12
        s.ellipse(0.5 + 0.12 * math.cos(a), 0.42 + 0.085 * math.sin(a), 0.05, 0.035, ORANGE)
    s.ellipse(0.5, 0.42, 0.06, 0.045, (150, 70, 20))
    s.ellipse(0.24, 0.6, 0.08, 0.06, (120, 70, 30))
    s.ellipse(0.24, 0.5, 0.06, 0.045, (120, 70, 30))
    s.line([(0.24, 0.45), (0.24, 0.24)], INK, 6)
    s.field(0.12, 0.72, 0.88, 0.82, INK, 4)
    s.field(0.22, 0.85, 0.78, 0.91, INK, 2)


DRAW = {"missing": _missing, "nahual_reward": _nahual_reward, "curandero": _curandero, "exorcist": _exorcist,
        "cabaret": _cabaret, "lucha_night": _lucha_night, "company_notice": _company_notice, "loteria": _loteria,
        "wanted_spirit": _wanted_spirit, "fiesta": _fiesta}


# --- paper, its years and its tearing ---------------------------------------------------------------------

def _grain(name, brushes_dir):
    values = brush_sheets.load(name, brushes_dir)
    image = Image.fromarray((values * 255).astype(np.uint8), "L").resize((BIG, BIG), Image.BILINEAR)
    return np.asarray(image, np.float64) / 255.0


def _aged(rgb, inside, box, grain, rng):
    """The paper's years: yellowed toward its edges, damp risen from below, folded, paste run down it."""
    x0, y0, x1, y1 = box
    y, x = np.mgrid[0:BIG, 0:BIG]
    edge = np.minimum(np.minimum(x - x0, x1 - x), np.minimum(y - y0, y1 - y)) / max(x1 - x0, 1)
    yellow = np.clip(1.0 - edge / 0.12, 0, 1)[..., None] * np.array([0.0, -10.0, -36.0])
    damp = np.clip((y - (y0 + 0.75 * (y1 - y0))) / (0.25 * (y1 - y0)), 0, 1) ** 1.4 * (0.5 + 0.5 * grain)
    rgb = rgb + yellow - damp[..., None] * np.array([60.0, 66.0, 70.0])
    for fold in (np.abs(x - (x0 + x1) / 2) < 2, np.abs(y - (y0 + 0.47 * (y1 - y0))) < 2):
        rgb[fold & inside] *= 0.86
    for _ in range(rng.randint(2, 5)):
        px = rng.uniform(x0, x1)
        run = (np.abs(x - px - 6 * np.sin(y * 0.02)) < rng.uniform(5, 14)) & (y < y0 + rng.uniform(0.2, 0.6) * (y1 - y0))
        rgb[run & inside] *= 0.9
    return rgb


def _fine(rng, blur=1.6):
    """A fine wander for a tear's edge (0..1), the paper's fibres pulling."""
    noise = ndimage.gaussian_filter(np.random.default_rng(rng.randrange(1 << 30)).random((BIG, BIG)), blur)
    return (noise - noise.min()) / max(np.ptp(noise), 1e-6)


def _torn(inside, box, grain, rng, bites=2, strip=False):
    """Its edge torn: in from each side by the grain's own wander, a few bites out, sometimes a strip torn away."""
    x0, y0, x1, y1 = box
    y, x = np.mgrid[0:BIG, 0:BIG]
    d = np.minimum(np.minimum(x - x0, x1 - x), np.minimum(y - y0, y1 - y))
    wander = ndimage.gaussian_filter(grain, 3.0)
    keep = inside & (d > 3 + 22 * wander + 20 * _fine(rng))
    for _ in range(bites):
        side = rng.randrange(4)
        cx = rng.uniform(x0, x1) if side < 2 else (x0 if side == 2 else x1)
        cy = (y0 if side == 0 else y1) if side < 2 else rng.uniform(y0, y1)
        r = rng.uniform(0.05, 0.14) * (x1 - x0)
        keep &= np.hypot(x - cx, y - cy) > r * (0.8 + 0.4 * wander)
    if strip:
        # A strip torn away down from one top corner, its tear wandering.
        a = rng.uniform(0.6, 1.0)
        across = (x - x0) if rng.random() < 0.5 else (x1 - x)
        line = across * a + (y - y0) - rng.uniform(0.35, 0.55) * (x1 - x0)
        keep &= line + 30 * (wander - 0.5) > 0
    return keep


def _rimmed(rgb, keep, width=7):
    """A sheet darkened along its edge (`width` px in), as dirt and paste gather at a pasted sheet's edge."""
    inside = ndimage.distance_transform_edt(keep)
    shade = np.clip(inside / width, 0.0, 1.0) * 0.5 + 0.5
    return rgb * shade[..., None]


def _bill(kind, rng, grain):
    box, paper = SHEETS[kind]
    s = Sheet(box)
    base = Image.new("RGBA", (BIG, BIG), (0, 0, 0, 0))
    ImageDraw.Draw(base).rectangle((s.x0, s.y0, s.x1, s.y1), fill=paper + (255,))
    DRAW[kind](s, rng)
    # (The press's second ink a hair out of register.)
    base.alpha_composite(s.ink.transform(s.ink.size, Image.AFFINE, (1, 0, -2, 0, 1, -1)) if kind in ("lucha_night", "fiesta")
                         else s.ink)
    arr = np.asarray(base, np.float64)
    inside = arr[..., 3] > 0
    rgb = arr[..., :3] * (0.9 + 0.16 * grain)[..., None]
    rgb = _aged(rgb, inside, (s.x0, s.y0, s.x1, s.y1), grain, rng)
    keep = _torn(inside, (s.x0, s.y0, s.x1, s.y1), grain, rng, bites=rng.randint(1, 3), strip=rng.random() < 0.4)
    # The grime and paste gathered along its torn edge, which sets the sheet off the wall.
    rgb = _rimmed(rgb, keep)
    # Staples at its top corners.
    for cx in (s.x0 + 18, s.x1 - 18):
        rgb[int(s.y0) + 12:int(s.y0) + 16, int(cx) - 8:int(cx) + 8] = (150, 150, 156)
    out = np.dstack([np.clip(rgb, 0, 255), keep * 255.0]).astype(np.uint8)
    return np.asarray(Image.fromarray(out, "RGBA").resize((CELL, CELL), Image.LANCZOS))


def _tatters(rng, grain):
    """Scraps of older bills torn back: strips left hanging where a bill was ripped down, corners still pasted on,
    each scrap a different paper with a fragment of its print (a ruled field, a band of ink, part of a stamp)."""
    out = np.zeros((BIG, BIG, 4))
    papers = [NEWSPRINT, YELLOW, PINK, GREEN, WHITE, KRAFT]
    inks = [INK, RED, BLUE, ORANGE]
    y, x = np.mgrid[0:BIG, 0:BIG]
    wander = ndimage.gaussian_filter(grain, 3.0)
    fine = _fine(rng)
    # The scraps: [x from, y from, x to, y to] (fractions), a tall strip or a stuck corner each, apart.
    scraps = [(0.08, 0.06, 0.24, 0.62), (0.3, 0.06, 0.42, 0.44), (0.5, 0.08, 0.9, 0.3), (0.72, 0.36, 0.92, 0.9),
              (0.1, 0.7, 0.44, 0.92), (0.48, 0.5, 0.64, 0.86)]
    for k, (u0, v0, u1, v1) in enumerate(scraps[:rng.randint(5, 6)]):
        x0, y0, x1, y1 = u0 * BIG, v0 * BIG, u1 * BIG, v1 * BIG
        tilt = rng.uniform(-0.12, 0.12)
        xx = x - tilt * (y - y0)
        d = np.minimum(np.minimum(xx - x0, x1 - xx), np.minimum(y - y0, y1 - y))
        # Torn across its foot on a long slant, its sides ragged.
        foot = (y1 - y) - (xx - x0) * rng.uniform(-0.4, 0.4)
        piece = (d > 2 + 20 * wander + 16 * fine) & (foot > 10 + 30 * fine)
        colour = np.array(papers[(k + rng.randrange(3)) % len(papers)], np.float64)
        rgb = np.broadcast_to(colour, (BIG, BIG, 3)) * (0.82 + 0.2 * grain)[..., None]
        ink = np.array(inks[rng.randrange(len(inks))], np.float64)
        kind = k % 3
        if kind == 0:
            mark = np.zeros_like(piece)
            for r in range(4):
                v = y0 + (0.2 + 0.15 * r) * (y1 - y0)
                mark |= (np.abs(y - v) < 2) & (xx > x0 + 14) & (xx < x1 - 14)
        elif kind == 1:
            mark = np.abs(y - (y0 + 0.35 * (y1 - y0))) < 0.06 * (y1 - y0)
        else:
            cx, cy = x0 + 0.7 * (x1 - x0), y0 + 0.6 * (y1 - y0)
            mark = np.abs(np.hypot(x - cx, y - cy) - 0.25 * (x1 - x0)) < 5
        rgb = np.where(mark[..., None], ink, rgb)
        out[piece, :3] = rgb[piece]
        out[piece, 3] = 255
    out[..., :3] *= (1.0 - 0.12 * (1.0 - grain))[..., None]
    out[..., :3] = _rimmed(out[..., :3], out[..., 3] > 0, 5)
    return np.asarray(Image.fromarray(np.clip(out, 0, 255).astype(np.uint8), "RGBA").resize((CELL, CELL), Image.LANCZOS))


def make(brushes_dir=brush_sheets.BRUSHES):
    """The sheet: COLS x ROWS bills, laid out as BILLS."""
    rng = random.Random(1937)
    grains = [_grain("brush_%02d" % i, brushes_dir) for i in range(5)]
    sheet = np.zeros((ROWS * CELL, COLS * CELL, 4), np.uint8)
    for k, kind in enumerate(BILLS):
        grain = grains[k % len(grains)]
        cell = _tatters(rng, grain) if kind == "tatters" else _bill(kind, rng, grain)
        cell = cell.copy()
        cell[:BORDER, :, 3] = cell[-BORDER:, :, 3] = 0
        cell[:, :BORDER, 3] = cell[:, -BORDER:, 3] = 0
        j, i = divmod(k, COLS)
        sheet[j * CELL:(j + 1) * CELL, i * CELL:(i + 1) * CELL] = cell
    return Image.fromarray(sheet, "RGBA")


if __name__ == "__main__":
    OUT.mkdir(parents=True, exist_ok=True)
    path = OUT / "pasaje_bills.png"
    make().save(path)
    print("wrote", path.relative_to(ROOT))
