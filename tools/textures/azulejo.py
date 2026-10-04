"""The old town's azulejo story panels, painted as tin-glaze tiles are: the
design washed and hatched in cobalt over the white glaze (pale washes laid
first, the shade hatched over them, the contour last), the yellow of
antimony, the purple-brown of manganese and the comet's iron red in their
own places; then each tile fired a little differently, crazed, chipped at a
corner, grouted. Drawn at SCALE times its size, shrunk by averaging and cut
to its own palette (paint.py's _finish).

    azulejo_comet   the red comet low over the city on its rock, the sea
    azulejo_king    the forgotten king as a saint in his niche: crowned,
                    haloed, his face a blank in the glaze, his sword broken
    azulejo_souls   an alminha: the king above in clouds, the souls in the
                    comet's red fire below, pleading
    tile_frame      the panels' border: an acanthus scroll in cobalt and
                    yellow between two cobalt bands

Each panel 4 x 6 tiles of 32 px; the frame a strip of 4 tiles.
"""

import math

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

SCALE = 4
TILE = 32 * SCALE
GLAZE = np.array([233.0, 229.0, 212.0])
# Cobalt by how much is laid: the glaze, a pale wash, light, mid, deep, the
# contour's.
RAMP = [(0.0, (233, 229, 212)), (0.2, (184, 198, 224)), (0.45, (118, 146, 202)), (0.7, (58, 84, 164)), (0.88, (30, 46, 120)), (1.0, (18, 28, 86))]
YELLOW = np.array([222.0, 176.0, 66.0])
YELLOW_DARK = np.array([158.0, 106.0, 30.0])
MANGANESE = np.array([92.0, 52.0, 66.0])
RED = np.array([180.0, 48.0, 34.0])
RED_PALE = np.array([222.0, 128.0, 84.0])
TERRACOTTA = np.array([186.0, 112.0, 78.0])


class Panel:
    """A panel's paints, each a layer of how much of it lies where (0-1),
    laid one coat over another."""

    def __init__(self, tw, th, seed):
        self.tw, self.th = tw, th
        self.w, self.h = tw * TILE, th * TILE
        self.rng = np.random.default_rng(seed)
        self.layers = {k: np.zeros((self.h, self.w)) for k in ("cobalt", "yellow", "yellow_dark", "manganese", "red", "red_pale")}

    # Masks

    def mask(self, draw_fn, blur=0.0):
        """A mask (0-1) drawn by draw_fn(ImageDraw) on black, softened."""
        m = Image.new("L", (self.w, self.h), 0)
        draw_fn(ImageDraw.Draw(m))

        if blur:
            m = m.filter(ImageFilter.GaussianBlur(blur * SCALE))

        return np.asarray(m, dtype=np.float64) / 255.0

    def coat(self, layer, mask, amount):
        """A coat of `layer` laid over what is there (a wash over a wash
        deepens it)."""
        a = np.clip(mask * amount, 0.0, 1.0)
        self.layers[layer] = 1.0 - (1.0 - self.layers[layer]) * (1.0 - a)

    def scrape(self, mask, amount=1.0):
        """Glaze left white: what lies under the mask lifted (a highlight, a
        blank face)."""
        a = np.clip(mask * amount, 0.0, 1.0)

        for k in self.layers:
            self.layers[k] *= 1.0 - a

    # Strokes

    def stroke(self, layer, points, width, amount, taper=True, blur=0.4):
        """A brush stroke along points, `width` (px at 1x) swelling in its
        middle and tapering at its ends."""
        dense = [points[0]]

        for (ax, ay), (bx, by) in zip(points, points[1:]):
            k = max(1, int(math.hypot(bx - ax, by - ay) / max(1.0, width * SCALE * 0.15)))
            dense += [(ax + (bx - ax) * j / k, ay + (by - ay) * j / k) for j in range(1, k + 1)]

        n = len(dense)

        def draw_fn(d):
            for i, (x, y) in enumerate(dense):
                t = i / max(1, n - 1)
                r = width * SCALE * 0.5 * ((math.sin(t * math.pi) * 0.75 + 0.35) if taper else 1.0)
                d.ellipse([x - r, y - r, x + r, y + r], fill=255)

        self.coat(layer, self.mask(draw_fn, blur), amount)

    def line(self, layer, a, b, width, amount, blur=0.25):
        steps = max(2, int(math.hypot(b[0] - a[0], b[1] - a[1]) / (SCALE * 1.0)))
        self.stroke(layer, [(a[0] + (b[0] - a[0]) * i / steps, a[1] + (b[1] - a[1]) * i / steps) for i in range(steps + 1)], width, amount, False,
                    blur)

    def poly(self, layer, points, amount, blur=0.6, outline=None):
        """A wash over a shape; with `outline` (width), its contour in deep
        cobalt over it."""
        self.coat(layer, self.mask(lambda d: d.polygon(points, fill=255), blur), amount)

        if outline:
            self.contour(points, outline)

    def contour(self, points, width, amount=0.95, layer="cobalt"):
        closed = list(points) + [points[0]]

        for a, b in zip(closed, closed[1:]):
            self.line(layer, a, b, width, amount)

    def hatch(self, region, angle, spacing, width, amount, layer="cobalt"):
        """Parallel lines `spacing` apart (px at 1x) across a region's mask."""
        c, s = math.cos(math.radians(angle)), math.sin(math.radians(angle))
        span = int(math.hypot(self.w, self.h))

        def draw_fn(d):
            for k in range(-span, span, int(spacing * SCALE)):
                x0, y0 = self.w / 2.0 - s * k - c * span, self.h / 2.0 + c * k - s * span
                x1, y1 = self.w / 2.0 - s * k + c * span, self.h / 2.0 + c * k + s * span
                d.line([(x0, y0), (x1, y1)], fill=255, width=int(width * SCALE))

        lines = self.mask(draw_fn, 0.3)
        self.coat(layer, lines * region, amount)

    def region(self, points, blur=0.0):
        return self.mask(lambda d: d.polygon(points, fill=255), blur)

    def disc(self, cx, cy, r, blur=0.0):
        return self.mask(lambda d: d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=255), blur)

    def ring(self, cx, cy, r, width, blur=0.3):
        return self.mask(lambda d: d.ellipse([cx - r, cy - r, cx + r, cy + r], outline=255, width=int(width * SCALE)), blur)

    # Firing

    def fired(self, colours=40, border=True):
        """The painting fired on its tiles: each tile's glaze and blue a
        little its own, crazing, a chipped corner here and there, the
        grout between; shrunk to 32 px a tile."""
        rng = self.rng
        h, w = self.h, self.w
        ys, xs = np.mgrid[0:h, 0:w]
        tile_i, tile_j = xs // TILE, ys // TILE
        glaze_tone = rng.normal(0.0, 4.0, (self.th, self.tw))[tile_j, tile_i]
        blue_fire = (1.0 + rng.normal(0.0, 0.05, (self.th, self.tw)))[tile_j, tile_i]
        cob = np.clip(self.layers["cobalt"] * blue_fire, 0.0, 1.0)
        # (The brush's unevenness: the blue pools a little.)
        grain = Image.fromarray((rng.random((h // SCALE, w // SCALE)) * 255).astype(np.uint8)).resize((w, h), Image.Resampling.BICUBIC)
        cob = np.clip(cob * (0.92 + 0.16 * np.asarray(grain, dtype=np.float64) / 255.0), 0.0, 1.0)
        out = np.empty((h, w, 3))
        stops = [p for p, _c in RAMP]

        for ch in range(3):
            out[:, :, ch] = np.interp(cob, stops, [c[ch] for _p, c in RAMP])

        out += glaze_tone[:, :, None] * (1.0 - cob)[:, :, None]

        for layer, colour in (("yellow", YELLOW), ("yellow_dark", YELLOW_DARK), ("manganese", MANGANESE), ("red_pale", RED_PALE), ("red", RED)):
            m = self.layers[layer][:, :, None]
            out = out * (1.0 - m) + colour * m

        image = Image.fromarray(np.clip(out, 0, 255).astype(np.uint8), "RGB")
        draw = ImageDraw.Draw(image)

        # Crazing: a few fine dark lines a tile, wandering.
        for j in range(self.th):
            for i in range(self.tw):
                for _k in range(int(rng.integers(1, 4))):
                    x, y = (i + rng.random()) * TILE, (j + rng.random()) * TILE
                    pts = [(x, y)]
                    a = rng.random() * math.pi

                    for _s in range(5):
                        a += rng.normal(0.0, 0.5)
                        x, y = x + math.cos(a) * TILE * 0.12, y + math.sin(a) * TILE * 0.12
                        pts.append((x, y))

                    draw.line(pts, fill=(150, 146, 134), width=1)

                # (A chipped corner: the terracotta under the glaze.)
                if rng.random() < 0.28:
                    cx, cy = (i + int(rng.integers(0, 2))) * TILE, (j + int(rng.integers(0, 2))) * TILE
                    r = TILE * (0.06 + 0.06 * rng.random())
                    draw.polygon([(cx + rng.normal(0, r), cy + rng.normal(0, r)) for _ in range(5)], fill=tuple(int(v) for v in TERRACOTTA))

        for i in range(1, self.tw):
            draw.line([(i * TILE, 0), (i * TILE, h)], fill=(168, 160, 142), width=int(SCALE * 1.3))

        for j in range(1, self.th):
            draw.line([(0, j * TILE), (w, j * TILE)], fill=(168, 160, 142), width=int(SCALE * 1.3))

        small = image.resize((self.tw * 32, self.th * 32), Image.Resampling.BOX)
        return small.quantize(colors=colours, dither=Image.Dither.NONE).convert("RGBA")

    # Motifs

    def border(self, inset=0.06):
        """A thin painted border inside the panel's edge: cobalt, then a
        yellow line."""
        b = TILE * inset
        w, h = self.w, self.h
        self.contour([(b, b), (w - b, b), (w - b, h - b), (b, h - b)], 3.0)
        b2 = b + SCALE * 4
        pts = [(b2, b2), (w - b2, b2), (w - b2, h - b2), (b2, h - b2)]
        closed = pts + [pts[0]]

        for a, c in zip(closed, closed[1:]):
            self.line("yellow", a, c, 1.6, 0.9)

    def cloud(self, cx, cy, rx, ry, seed):
        """A cloud as the tile painters drew them: lobes round a body, left
        white, their undersides shaded and outlined."""
        rng = np.random.default_rng(seed)
        lobes = [(cx + rx * math.cos(a) * (0.75 + 0.25 * rng.random()), cy + ry * math.sin(a) * 0.6, ry * (0.45 + 0.25 * rng.random()))
                 for a in np.linspace(math.pi * 0.95, math.pi * 2.05, 7)]
        lobes += [(cx + rx * (k - 1.5) * 0.45, cy + ry * 0.25, ry * 0.5) for k in range(4)]
        body = np.zeros((self.h, self.w))

        for x, y, r in lobes:
            body = np.maximum(body, self.disc(x, y, r))

        self.scrape(body, 0.92)

        # (Each lobe's lower edge shaded, outlined.)
        for x, y, r in lobes:
            under = self.mask(lambda d: d.chord([x - r, y - r, x + r, y + r], 20, 160, fill=255), 0.8)
            self.coat("cobalt", under * body, 0.28)
            self.coat("cobalt", self.mask(lambda d: d.arc([x - r, y - r, x + r, y + r], 15, 165, fill=255, width=int(1.6 * SCALE)), 0.2), 0.75)

    def scroll(self, layer, cx, cy, r, turns, start, width, amount, flip=1.0):
        """A spiral stroke (an acanthus scroll's curl) round cx, cy."""
        pts = []

        for k in range(48):
            t = k / 47.0
            a = start + flip * t * turns * 2.0 * math.pi
            rr = r * (1.0 - 0.75 * t)
            pts.append((cx + math.cos(a) * rr, cy + math.sin(a) * rr))

        self.stroke(layer, pts, width, amount)

    def ribbon(self, x0, y0, x1, y1, seed, scratched=False):
        """A scroll of ribbon across, its ends curled, lettered in short
        strokes (or its lettering scratched out)."""
        rng = np.random.default_rng(seed)
        hgt = (y1 - y0)
        body = [(x0 + hgt, y0), (x1 - hgt, y0), (x1 - hgt * 0.4, (y0 + y1) / 2.0), (x1 - hgt, y1), (x0 + hgt, y1),
                (x0 + hgt * 0.4, (y0 + y1) / 2.0)]
        self.scrape(self.region(body), 1.0)
        self.poly("cobalt", body, 0.12, 0.5, outline=1.4)

        for x, s in ((x0 + hgt * 0.7, 1.0), (x1 - hgt * 0.7, -1.0)):
            self.scroll("cobalt", x, (y0 + y1) / 2.0, hgt * 0.45, 0.8, 0.0, 1.2, 0.85, s)

        x = x0 + hgt * 1.3

        while x < x1 - hgt * 1.4:
            if rng.random() < 0.82:
                top, bot = y0 + hgt * 0.3, y1 - hgt * 0.3
                self.line("cobalt", (x, top), (x + rng.normal(0, SCALE), bot), 1.1, 0.85)

                if rng.random() < 0.5:
                    self.line("cobalt", (x, top + (bot - top) * rng.random()), (x + SCALE * 3, top + (bot - top) * rng.random()), 0.9, 0.7)

            x += SCALE * (3.5 + 2.0 * rng.random())

        if scratched:
            region = self.region([(x0 + hgt, y0), (x1 - hgt, y0), (x1 - hgt, y1), (x0 + hgt, y1)])
            self.hatch(region, 35.0, 2.2, 0.9, 0.8, "manganese")
            self.hatch(region, -40.0, 2.6, 0.9, 0.7, "manganese")


def azulejo_comet():
    """The red comet low over the city on its rock (its spec, section 16):
    a washed sky under scalloped clouds, the comet's iron-red head and its
    tail streaming over the castle, the houses stepping up the rock to the
    keep, the sea curling at its foot and the comet's red glints on it, a
    lettered ribbon. Put up on houses after the great fire."""
    p = Panel(4, 6, 1700)
    w, h = p.w, p.h
    horizon = h * 0.62
    rng = p.rng
    # The sky: a wash deepest at the top, laid in horizontal strokes.
    for k in range(70):
        y = rng.random() * horizon
        amount = 0.16 + 0.38 * (1.0 - y / horizon) ** 1.5
        x = rng.random() * w * 0.4
        p.stroke("cobalt", [(x + t * w * 0.7, y + rng.normal(0, SCALE)) for t in np.linspace(0, 1, 18)], 9 + 6 * rng.random(), amount * 0.5)

    p.coat("cobalt", p.mask(lambda d: d.rectangle([0, 0, w, horizon], fill=255), 2.0), 0.12)

    for cx, cy, rx, ry, seed in ((w * 0.72, h * 0.12, w * 0.26, h * 0.05, 1), (w * 0.2, h * 0.36, w * 0.24, h * 0.045, 2),
                                 (w * 0.8, h * 0.42, w * 0.2, h * 0.04, 3)):
        p.cloud(cx, cy, rx, ry, seed)

    # The comet: its head high at the left in a ring of rays, its tail in
    # long red strokes sweeping down over the castle, palest at their ends.
    hx, hy = w * 0.24, h * 0.16

    for k in range(9):
        bend = 0.04 + 0.025 * k
        length = 0.55 + 0.05 * rng.random()
        pts = [(hx + s * w * length * (1.0 + 0.02 * k), hy + s * h * (0.2 + 0.012 * k) + math.sin(s * math.pi) * h * bend * 0.5)
               for s in np.linspace(0.02, 1.0, 30)]
        p.stroke("red_pale" if k % 3 else "red", pts, 5.5 - k * 0.35, 0.75 if k % 3 else 0.85)

    # (Its coma a soft red haze, its head hard and pale-hearted, hatched
    # round in red as the painters shaded a sphere.)
    p.coat("red_pale", p.disc(hx, hy, SCALE * 16, 3.0), 0.7)
    p.coat("red", p.disc(hx, hy, SCALE * 9, 0.6), 0.95)
    p.scrape(p.disc(hx - SCALE * 2.5, hy - SCALE * 2.5, SCALE * 3.0, 0.8), 0.7)
    p.coat("red_pale", p.disc(hx - SCALE * 2.5, hy - SCALE * 2.5, SCALE * 3.0, 0.8), 0.6)
    p.hatch(p.ring(hx, hy, SCALE * 12, 3.0, 0.6), 60.0, 1.8, 0.8, 0.6, "red")
    # The rock, rising from the sea at the left to the summit at the right;
    # its cliffs hatched, its contour deep.
    rock = [(0, h * 0.8), (w * 0.1, h * 0.74), (w * 0.3, h * 0.7), (w * 0.48, h * 0.63), (w * 0.62, h * 0.57), (w * 0.74, h * 0.52),
            (w, h * 0.5), (w, h * 0.84), (0, h * 0.84)]
    p.poly("cobalt", rock, 0.34, 0.8)
    face = p.region(rock)
    p.hatch(face, 80.0, 3.2, 1.0, 0.55)
    p.contour(rock[:7], 2.4)
    top_x, top_y = [q[0] for q in rock[:7]], [q[1] for q in rock[:7]]

    # Houses stepping up the rock: white fronts, washed roofs, a window or
    # two, their contours.
    x = SCALE * 8

    while x < w * 0.68:
        ground = float(np.interp(x, top_x, top_y))
        hw, hh = SCALE * (9 + 5 * rng.random()), SCALE * (12 + 10 * rng.random())
        front = [(x, ground + SCALE * 2), (x + hw, ground + SCALE * 2), (x + hw, ground - hh), (x, ground - hh)]
        p.scrape(p.region(front), 0.9)
        p.poly("cobalt", [(x - SCALE, ground - hh), (x + hw + SCALE, ground - hh), (x + hw / 2.0, ground - hh - SCALE * 6)], 0.7, 0.3)
        p.contour(front, 1.2, 0.85)

        for wy in (0.35, 0.7):
            p.coat("cobalt", p.disc(x + hw * 0.5, ground - hh * wy, SCALE * 1.6), 0.9)

        x += hw + SCALE * (1 + 3 * rng.random())

    # The castle on the summit: its walls crenellated, its keep tall, the
    # shaded side hatched.
    kx, ky = w * 0.82, h * 0.51
    walls = [(kx - w * 0.16, ky + SCALE * 2), (kx + w * 0.17, ky - SCALE * 2), (kx + w * 0.17, ky - SCALE * 16), (kx - w * 0.16, ky - SCALE * 13)]
    p.scrape(p.region(walls), 0.9)
    p.coat("cobalt", p.region(walls), 0.22)
    p.contour(walls, 1.6)
    keep = [(kx - SCALE * 9, ky - SCALE * 14), (kx + SCALE * 9, ky - SCALE * 14), (kx + SCALE * 9, ky - SCALE * 50), (kx - SCALE * 9, ky - SCALE * 50)]
    p.scrape(p.region(keep), 0.9)
    p.hatch(p.region([(kx + SCALE * 1, ky - SCALE * 14), (kx + SCALE * 9, ky - SCALE * 14), (kx + SCALE * 9, ky - SCALE * 50),
                      (kx + SCALE * 1, ky - SCALE * 50)]), 90.0, 2.0, 0.9, 0.7)
    p.contour(keep, 1.6)

    for i in range(-4, 5):
        bx = kx + i * SCALE * 7
        top = float(np.interp(bx, [kx - w * 0.16, kx + w * 0.17], [ky - SCALE * 13, ky - SCALE * 16]))
        p.poly("cobalt", [(bx - SCALE * 2, top), (bx + SCALE * 2, top), (bx + SCALE * 2, top - SCALE * 4), (bx - SCALE * 2, top - SCALE * 4)], 0.9, 0.2)

    for i in (-1, 0, 1):
        bx = kx + i * SCALE * 6
        p.poly("cobalt", [(bx - SCALE * 2, ky - SCALE * 50), (bx + SCALE * 2, ky - SCALE * 50), (bx + SCALE * 2, ky - SCALE * 55),
                          (bx - SCALE * 2, ky - SCALE * 55)], 0.9, 0.2)

    p.coat("yellow", p.disc(kx, ky - SCALE * 36, SCALE * 2.2), 0.9)
    # The sea: rows of curling waves, deepening downward; the comet's red
    # glints on it.
    for row in range(5):
        y = h * 0.86 + row * h * 0.026
        x = -SCALE * 4 + row * SCALE * 5

        while x < w:
            pts = [(x + math.cos(a) * SCALE * 7, y - math.sin(a) * SCALE * 4) for a in np.linspace(math.pi, 0.1, 12)]
            p.stroke("cobalt", pts, 2.0 + row * 0.35, 0.7 + row * 0.05)
            x += SCALE * 15

    p.coat("cobalt", p.mask(lambda d: d.rectangle([0, h * 0.84, w, h], fill=255), 1.0), 0.18)

    for k in range(7):
        gx, gy = w * (0.2 + 0.09 * k + 0.03 * rng.random()), h * (0.87 + 0.08 * rng.random())
        p.line("red_pale", (gx, gy), (gx + SCALE * 6, gy), 1.4, 0.75)

    p.ribbon(w * 0.08, h * 0.92, w * 0.62, h * 0.965, 1701)
    p.border()
    return p.fired(44)


def azulejo_king():
    """The forgotten king as a saint (its spec, section 16): in a painted
    niche between two columns under a coffered arch, on a rock; robed in
    cobalt in deep folds, an ermine-collared mantle hemmed in yellow; his
    crown and his halo of rays; his face a blank in the glaze, outlined and
    nothing in it; his right hand holding his sword point down, broken, its
    point at his feet; his left on his breast; beneath him a cartouche whose
    name has been scratched out."""
    p = Panel(4, 6, 1710)
    w, h = p.w, p.h
    rng = p.rng
    # The niche: its back washed and hatched dark, its arch coffered, its
    # columns white with shaded flutes.
    niche = [(w * 0.18, h * 0.84), (w * 0.82, h * 0.84), (w * 0.82, h * 0.3)] + \
        [(w * 0.5 + math.cos(a) * w * 0.32, h * 0.3 - math.sin(a) * w * 0.32) for a in np.linspace(0.0, math.pi, 24)] + [(w * 0.18, h * 0.3)]
    p.poly("cobalt", niche, 0.42, 0.6)
    p.hatch(p.region(niche), 90.0, 3.0, 1.0, 0.45)

    for a in np.linspace(0.1, math.pi - 0.1, 9):
        cx, cy = w * 0.5 + math.cos(a) * w * 0.37, h * 0.3 - math.sin(a) * w * 0.37
        p.coat("cobalt", p.disc(cx, cy, SCALE * 4.5), 0.75)
        p.scrape(p.disc(cx, cy, SCALE * 2.2), 0.8)

    p.coat("cobalt", p.ring(w * 0.5, h * 0.3, w * 0.33, 2.0), 0.9)
    p.coat("cobalt", p.ring(w * 0.5, h * 0.3, w * 0.41, 2.0), 0.9)

    for cx in (w * 0.12, w * 0.88):
        col = [(cx - SCALE * 8, h * 0.84), (cx + SCALE * 8, h * 0.84), (cx + SCALE * 7, h * 0.3), (cx - SCALE * 7, h * 0.3)]
        p.scrape(p.region(col), 1.0)

        for f in (-4, 0, 4):
            p.line("cobalt", (cx + f * SCALE, h * 0.32), (cx + f * SCALE, h * 0.82), 1.0, 0.55)

        p.contour(col, 1.4)
        p.poly("cobalt", [(cx - SCALE * 11, h * 0.3), (cx + SCALE * 11, h * 0.3), (cx + SCALE * 9, h * 0.28), (cx - SCALE * 9, h * 0.28)], 0.85, 0.2)
        p.poly("yellow", [(cx - SCALE * 9, h * 0.296), (cx + SCALE * 9, h * 0.296), (cx + SCALE * 9, h * 0.288), (cx - SCALE * 9, h * 0.288)], 0.9, 0.2)

    # The rock he stands on, hatched; his sword's point broken off on it.
    rock = [(w * 0.16, h * 0.86), (w * 0.3, h * 0.8), (w * 0.7, h * 0.8), (w * 0.84, h * 0.86)]
    p.poly("cobalt", rock, 0.35, 0.5)
    p.hatch(p.region(rock), 20.0, 2.6, 0.9, 0.55)
    p.contour(rock, 1.6)
    tip = [(w * 0.64, h * 0.795), (w * 0.73, h * 0.785), (w * 0.745, h * 0.79), (w * 0.645, h * 0.802)]
    p.scrape(p.region(tip), 1.0)
    p.contour(tip, 1.0)
    # His robe: wide from the shoulders to the rock, folds in long strokes,
    # their shadows deep, their ridges left white; its hem in yellow.
    cx, top, foot = w * 0.48, h * 0.38, h * 0.8
    robe = [(cx - w * 0.12, top), (cx + w * 0.12, top), (cx + w * 0.2, foot), (cx - w * 0.2, foot)]
    p.scrape(p.region(robe), 1.0)
    p.poly("cobalt", robe, 0.5, 0.4)

    for f in np.linspace(-0.85, 0.85, 7):
        a = (cx + f * w * 0.1, top + h * 0.06)
        b = (cx + f * w * 0.19 + rng.normal(0, SCALE * 2), foot)
        p.stroke("cobalt", [(a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t) for t in np.linspace(0, 1, 16)], 3.0, 0.75)
        p.scrape(p.mask(lambda d: d.line([(a[0] + SCALE * 4, a[1]), (b[0] + SCALE * 5, b[1])], fill=255, width=int(SCALE * 1.4)), 0.4), 0.55)

    p.contour(robe, 1.8)
    p.poly("yellow", [(cx - w * 0.2, foot - SCALE * 4), (cx + w * 0.2, foot - SCALE * 4), (cx + w * 0.2, foot), (cx - w * 0.2, foot)], 0.9, 0.3)
    # His mantle over his shoulders, its ermine collar, its yellow edge.
    mantle = [(cx - w * 0.15, top - h * 0.01), (cx + w * 0.15, top - h * 0.01), (cx + w * 0.17, top + h * 0.16), (cx, top + h * 0.1),
              (cx - w * 0.17, top + h * 0.16)]
    p.poly("cobalt", mantle, 0.78, 0.4, outline=1.6)
    p.line("yellow", mantle[2], mantle[3], 2.0, 0.9)
    p.line("yellow", mantle[3], mantle[4], 2.0, 0.9)
    collar = [(cx - w * 0.13, top - h * 0.015), (cx + w * 0.13, top - h * 0.015), (cx + w * 0.1, top + h * 0.03), (cx - w * 0.1, top + h * 0.03)]
    p.scrape(p.region(collar), 1.0)
    p.contour(collar, 1.0)

    for k in range(7):
        ex = cx - w * 0.1 + k * w * 0.033
        p.line("cobalt", (ex, top + h * 0.0), (ex, top + h * 0.012), 1.4, 0.95)

    # His halo: a yellow ring, rays out from it; his face a blank oval in
    # the glaze, outlined, nothing in it; his crown.
    hx, hy = cx, h * 0.3
    p.coat("yellow", p.ring(hx, hy, w * 0.12, 2.6), 0.9)

    for a in np.linspace(0, 2 * math.pi, 28, endpoint=False):
        r0, r1 = w * 0.125, w * (0.15 + 0.02 * (int(a * 4.4) % 2))
        p.line("yellow_dark", (hx + math.cos(a) * r0, hy + math.sin(a) * r0), (hx + math.cos(a) * r1, hy + math.sin(a) * r1), 1.0, 0.75)

    face = [(hx + math.cos(a) * w * 0.055, hy + 6 * SCALE + math.sin(a) * w * 0.072) for a in np.linspace(0, 2 * math.pi, 28, endpoint=False)]
    p.scrape(p.region(face), 1.0)
    p.contour(face, 1.3)
    crown = [(hx - w * 0.07, hy - w * 0.035), (hx - w * 0.075, hy - w * 0.1), (hx - w * 0.04, hy - w * 0.06), (hx, hy - w * 0.115),
             (hx + w * 0.04, hy - w * 0.06), (hx + w * 0.075, hy - w * 0.1), (hx + w * 0.07, hy - w * 0.035)]
    p.poly("yellow", crown, 0.92, 0.3, outline=1.3)

    for q in crown[1::2] + [crown[3]]:
        p.coat("cobalt", p.disc(q[0], q[1], SCALE * 2.2), 0.9)

    # His right arm out, his hand on the hilt, the blade broken short; his
    # left hand on his breast.
    shoulder, hand = (cx + w * 0.12, top + h * 0.03), (cx + w * 0.27, h * 0.5)
    p.stroke("cobalt", [(shoulder[0] + (hand[0] - shoulder[0]) * t, shoulder[1] + (hand[1] - shoulder[1]) * t) for t in np.linspace(0, 1, 14)], 9.0,
             0.78, False)
    p.scrape(p.disc(hand[0], hand[1], SCALE * 4.5), 1.0)
    p.contour([(hand[0] + math.cos(a) * SCALE * 4.5, hand[1] + math.sin(a) * SCALE * 4.5) for a in np.linspace(0, 2 * math.pi, 14, endpoint=False)],
              1.0)
    p.line("yellow", (hand[0] - SCALE * 10, hand[1] + SCALE * 6), (hand[0] + SCALE * 10, hand[1] + SCALE * 6), 3.0, 0.95)
    blade = [(hand[0] - SCALE * 2.5, hand[1] + SCALE * 7), (hand[0] + SCALE * 2.5, hand[1] + SCALE * 7), (hand[0] + SCALE * 2.5, hand[1] + h * 0.11),
             (hand[0] + SCALE * 0.5, hand[1] + h * 0.12), (hand[0] - SCALE * 1.2, hand[1] + h * 0.105), (hand[0] - SCALE * 2.5, hand[1] + h * 0.115)]
    p.scrape(p.region(blade), 1.0)
    p.poly("cobalt", blade, 0.22, 0.2, outline=1.1)
    p.stroke("cobalt", [(cx - w * 0.11 + (w * 0.09) * t, top + h * 0.03 + (h * 0.07) * t) for t in np.linspace(0, 1, 12)], 8.0, 0.82, False)
    p.scrape(p.disc(cx - w * 0.02, top + h * 0.1, SCALE * 4), 1.0)
    p.contour([(cx - w * 0.02 + math.cos(a) * SCALE * 4, top + h * 0.1 + math.sin(a) * SCALE * 4) for a in np.linspace(0, 2 * math.pi, 12, endpoint=False)],
              1.0)
    # The cartouche under him, his name scratched out.
    p.ribbon(w * 0.14, h * 0.885, w * 0.86, h * 0.945, 1711, scratched=True)
    p.border()
    return p.fired(44)


def azulejo_souls():
    """An alminha (the souls in purgatory, the wayside shrine's panel): the
    king above in a mandorla of clouds, his face blank, his hands open over
    them; the souls below in the comet's red fire, five heads and their
    raised hands, pleading; a ribbon between, lettered."""
    p = Panel(4, 6, 1720)
    w, h = p.w, p.h
    rng = p.rng
    # The heavens: a wash, deepest at the top.
    p.coat("cobalt", p.mask(lambda d: d.rectangle([0, 0, w, h * 0.5], fill=255), 3.0), 0.3)

    for k in range(30):
        y = rng.random() * h * 0.45
        p.stroke("cobalt", [(rng.random() * w * 0.3 + t * w * 0.7, y) for t in np.linspace(0, 1, 14)], 8.0, 0.18)

    # The mandorla of clouds round him; the king, small, his arms open.
    for a in np.linspace(0, 2 * math.pi, 12, endpoint=False):
        p.cloud(w * 0.5 + math.cos(a) * w * 0.3, h * 0.25 + math.sin(a) * h * 0.17, w * 0.1, h * 0.03, int(a * 100))

    cx, top = w * 0.5, h * 0.2
    body = [(cx - w * 0.09, top), (cx + w * 0.09, top), (cx + w * 0.12, h * 0.38), (cx - w * 0.12, h * 0.38)]
    p.scrape(p.region(body), 1.0)
    p.poly("cobalt", body, 0.55, 0.3, outline=1.4)

    for f in (-0.6, 0.0, 0.6):
        p.line("cobalt", (cx + f * w * 0.05, top + SCALE * 6), (cx + f * w * 0.1, h * 0.38), 2.0, 0.75)

    for s in (-1.0, 1.0):
        p.stroke("cobalt", [(cx + s * w * (0.08 + 0.12 * t), top + SCALE * 4 - t * SCALE * 10) for t in np.linspace(0, 1, 10)], 6.0, 0.8, False)
        p.scrape(p.disc(cx + s * w * 0.21, top - SCALE * 6, SCALE * 3.5), 1.0)

    hx, hy = cx, top - SCALE * 12
    p.coat("yellow", p.ring(hx, hy, SCALE * 15, 2.4), 0.9)
    face = [(hx + math.cos(a) * SCALE * 8, hy + math.sin(a) * SCALE * 10) for a in np.linspace(0, 2 * math.pi, 20, endpoint=False)]
    p.scrape(p.region(face), 1.0)
    p.contour(face, 1.1)
    p.poly("yellow", [(hx - SCALE * 9, hy - SCALE * 8), (hx - SCALE * 10, hy - SCALE * 16), (hx, hy - SCALE * 12), (hx + SCALE * 10, hy - SCALE * 16),
                      (hx + SCALE * 9, hy - SCALE * 8)], 0.9, 0.3, outline=1.1)
    # The ribbon across the middle.
    p.ribbon(w * 0.06, h * 0.47, w * 0.94, h * 0.52, 1721)
    # The fire: tongues of red and pale red licking up from the foot.
    for k in range(26):
        x = w * (k + rng.random()) / 26.0
        base, height = h * 0.97, h * (0.18 + 0.16 * rng.random())
        pts = [(x + math.sin(t * math.pi * 1.6 + k) * SCALE * 6 * t, base - t * height) for t in np.linspace(0, 1, 18)]
        p.stroke("red_pale" if k % 2 else "red", pts, 10.0 - 4.0 * rng.random(), 0.82)

    p.coat("red", p.mask(lambda d: d.rectangle([0, h * 0.9, w, h], fill=255), 2.0), 0.6)
    # (Their smoke rising to the clouds: washed curls, their edges drawn.)
    p.coat("cobalt", p.mask(lambda d: d.rectangle([0, h * 0.52, w, h * 0.72], fill=255), 6.0), 0.14)

    for k in range(9):
        x0, y0 = w * (0.06 + 0.11 * k), h * (0.7 - 0.03 * (k % 3))
        curl = [(x0 + math.sin(t * 5.0 + k) * SCALE * 9 * (1.0 - t), y0 - t * h * 0.17) for t in np.linspace(0, 1, 20)]
        p.stroke("cobalt", curl, 7.0, 0.22)
        p.stroke("cobalt", [(cx2 + SCALE * 3, cy2) for cx2, cy2 in curl], 1.0, 0.6)
    # The souls: busts in the fire, washed and outlined in manganese, their
    # hair in strokes, their eyes turned up, their hands raised.
    for k, sx in enumerate((0.14, 0.32, 0.5, 0.68, 0.86)):
        x, y = w * sx, h * (0.74 + 0.035 * (k % 2))
        side = 1.0 if k % 2 else -1.0
        shoulders = [(x - SCALE * 14, y + SCALE * 26), (x + SCALE * 14, y + SCALE * 26), (x + SCALE * 10, y + SCALE * 11), (x, y + SCALE * 8),
                     (x - SCALE * 10, y + SCALE * 11)]
        p.scrape(p.region(shoulders), 1.0)
        p.coat("cobalt", p.region([(x, y + SCALE * 8), (x + side * SCALE * 10, y + SCALE * 11), (x + side * SCALE * 14, y + SCALE * 26),
                                   (x, y + SCALE * 26)], 0.6), 0.3)
        p.contour(shoulders, 1.1, 0.9, "manganese")
        head = [(x + math.cos(a) * SCALE * 6.5, y + math.sin(a) * SCALE * 8.0) for a in np.linspace(0, 2 * math.pi, 20, endpoint=False)]
        p.scrape(p.region(head), 1.0)
        # (The side away from the fire's light washed.)
        p.coat("cobalt", p.region([(x, y - SCALE * 8), (x + side * SCALE * 7, y - SCALE * 4), (x + side * SCALE * 7, y + SCALE * 4), (x, y + SCALE * 8)],
                                  0.8), 0.28)
        p.contour(head, 1.1, 0.9, "manganese")

        for hk in range(5):
            hx0 = x - SCALE * 6 + hk * SCALE * 3
            p.stroke("manganese", [(hx0, y - SCALE * 7.5), (hx0 + SCALE * (1.5 - hk * 0.7), y - SCALE * 3), (hx0 + SCALE * (1 - hk * 0.6), y + SCALE * 1)],
                     1.0, 0.75)

        for ex in (-2.4, 2.4):
            p.line("manganese", (x + ex * SCALE - SCALE * 0.8, y - SCALE * 0.5), (x + ex * SCALE + SCALE * 0.8, y - SCALE * 1.4), 0.9, 0.9)

        p.line("manganese", (x - SCALE * 1.5, y + SCALE * 4.5), (x + SCALE * 1.5, y + SCALE * 4.5), 0.9, 0.8)

        for s2 in (-1.0, 1.0):
            elbow = (x + s2 * SCALE * 16, y + SCALE * 4)
            hand = (x + s2 * SCALE * 13, y - SCALE * (12 + 4 * (k % 2)))
            arm = [(x + s2 * SCALE * 11, y + SCALE * 14), elbow, hand]
            p.stroke("cobalt", arm, 3.4, 0.35, False)
            p.stroke("manganese", arm, 1.0, 0.85, False)
            palm = [(hand[0] - SCALE * 2.2, hand[1] + SCALE * 2), (hand[0] + SCALE * 2.2, hand[1] + SCALE * 2), (hand[0] + SCALE * 2.0, hand[1] - SCALE * 2.5),
                    (hand[0] - SCALE * 2.0, hand[1] - SCALE * 2.5)]
            p.scrape(p.region(palm), 1.0)
            p.contour(palm, 0.8, 0.9, "manganese")

            for f in (-1.5, -0.5, 0.5, 1.5):
                p.line("manganese", (hand[0] + f * SCALE, hand[1] - SCALE * 2.5), (hand[0] + f * SCALE * 1.2, hand[1] - SCALE * 5), 0.7, 0.85)

    p.border()
    return p.fired(48)


def tile_frame():
    """The panels' border strip (4 tiles in a row): an acanthus scroll
    running along it in cobalt with yellow in its leaves, between a deep
    cobalt band either side."""
    p = Panel(4, 1, 1730)
    w, h = p.w, p.h
    p.coat("cobalt", p.mask(lambda d: d.rectangle([0, 0, w, h * 0.16], fill=255), 0.3), 0.95)
    p.coat("cobalt", p.mask(lambda d: d.rectangle([0, h * 0.84, w, h], fill=255), 0.3), 0.95)
    p.coat("cobalt", p.mask(lambda d: d.rectangle([0, h * 0.16, w, h * 0.84], fill=255), 1.0), 0.12)
    # (The scroll: a wave of stem, a curl at each crest and trough, a leaf
    # off each curl.)
    period = TILE
    stem = [(x, h * 0.5 + math.sin(x / period * 2 * math.pi) * h * 0.16) for x in np.linspace(0, w, 160)]
    p.stroke("cobalt", stem, 3.0, 0.9, False)

    for k in range(8):
        x = (k + 0.25) * period / 2.0
        up = 1.0 if k % 2 == 0 else -1.0
        cy = h * 0.5 - up * h * 0.12
        p.scroll("cobalt", x + period * 0.08, cy, h * 0.13, 0.85, math.pi if up > 0 else 0.0, 2.2, 0.9, up)
        leaf = [(x, h * 0.5), (x + period * 0.18, h * 0.5 + up * h * 0.22), (x + period * 0.3, h * 0.5 + up * h * 0.08)]
        p.poly("yellow", leaf, 0.85, 0.4)
        p.contour(leaf, 1.0, 0.9)
        p.line("yellow_dark", leaf[0], leaf[1], 0.9, 0.7)

    return p.fired(24, border=False)


def window_lit():
    """A window lit from within (64 x 128; the lit_window shader multiplies
    it by each house's warmth): a room's light falling off from a lamp low at
    one side, a curtain drawn back to the other in folds, small panes in a
    dark wooden frame, the old glass a little uneven."""
    w, h = 64 * SCALE, 128 * SCALE
    ys, xs = np.mgrid[0:h, 0:w].astype(np.float64)
    rng = np.random.default_rng(1740)
    lamp_x, lamp_y = w * 0.32, h * 0.62
    d = np.hypot((xs - lamp_x) / w, (ys - lamp_y) / h * 0.6)
    light = np.clip(1.15 - d * 2.1, 0.12, 1.0)
    room = np.stack([255 * light, 196 * light ** 1.25, 120 * light ** 1.7], axis=2)
    # (A beam across the ceiling, the back wall's shadow under it.)
    room[: int(h * 0.12)] *= 0.45
    # The curtain at the right: folds in dark red, lit where they face the lamp.
    cx = w * 0.7
    curtain = xs > cx + np.sin(ys / h * 9.0) * w * 0.03
    folds = 0.55 + 0.45 * np.sin((xs - cx) / w * 40.0) ** 2
    shade = np.clip(1.0 - (xs - cx) / (w - cx) * 0.7, 0.2, 1.0)
    cloth = np.stack([150 * folds * shade, 52 * folds * shade, 40 * folds * shade], axis=2)
    room = np.where(curtain[:, :, None], cloth, room)
    # (The old glass: faint streaks.)
    streaks = 1.0 + 0.06 * np.sin(xs / w * 37.0 + rng.random() * 6.0) * np.sin(ys / h * 11.0)
    room *= streaks[:, :, None]
    image = Image.fromarray(np.clip(room, 0, 255).astype(np.uint8), "RGB")
    draw = ImageDraw.Draw(image)
    bar = int(SCALE * 3.0)
    frame = (34, 22, 14)

    for k in range(1, 2):
        x = w * k / 2.0
        draw.rectangle([x - bar / 2.0, 0, x + bar / 2.0, h], fill=frame)

    for k in range(1, 4):
        y = h * k / 4.0
        draw.rectangle([0, y - bar / 2.0, w, y + bar / 2.0], fill=frame)

    draw.rectangle([0, 0, w - 1, h - 1], outline=frame, width=int(bar * 1.4))
    small = image.resize((64, 128), Image.Resampling.BOX)
    return small.quantize(colors=32, dither=Image.Dither.NONE).convert("RGBA")
