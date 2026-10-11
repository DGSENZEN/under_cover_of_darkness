"""Flat effect sheets drawn here (the effects plan, Task 2; its Ruling: flat
strokes need no render):

  sparks.png         four frames of a spark's streak, 32 px each
  sigil_strokes.png  a ward sigil of our own invention, Aztec-styled (an
                     outer ring, a stepped-fret band, four spokes, an eye),
                     its red channel the order its strokes are drawn in
                     (0 first .. 1 last: write-on by threshold), its alpha
                     where it is drawn. A placeholder: the real glyphs are
                     the user's to paint.

    python3 tools/vfx/sprites_2d.py
"""

import json
import math
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

VFX = Path(__file__).resolve().parents[2] / "assets" / "vfx"
SCALE = 4


def sparks():
    """Four streaks, each a hot core tapering to a tail, a little bent."""
    px = 32 * SCALE
    frames = []

    for k in range(4):
        image = Image.new("RGBA", (px, px), (0, 0, 0, 0))
        draw = ImageDraw.Draw(image)
        length = px * (0.55 + 0.1 * k)
        bend = (k - 1.5) * 0.06
        points = [(px * 0.5 + bend * px * (t / 10) ** 2, px * 0.5 + length * (t / 10 - 0.5)) for t in range(11)]

        for t, ((ax, ay), (bx, by)) in enumerate(zip(points, points[1:])):
            width = max(1, int(px * 0.06 * (1.0 - t / 10)))
            heat = int(255 - 90 * t / 10)
            draw.line([(ax, ay), (bx, by)], fill=(255, heat, int(heat * 0.6), 255), width=width)

        frames.append(image.resize((32, 32), Image.Resampling.BOX))

    sheet = Image.new("RGBA", (128, 32), (0, 0, 0, 0))

    for k, f in enumerate(frames):
        sheet.paste(f, (k * 32, 0))

    alpha = sheet.getchannel("A").point(lambda a: 255 if a >= 70 else 0)
    sheet.putalpha(alpha)
    return sheet


def _sigil_path():
    """The sigil's strokes in drawing order: [(x, y)] polylines, 0..1 square."""
    strokes = []
    c = 0.5
    # The outer ring, from the top, sunwise.
    strokes.append([(c + 0.42 * math.sin(a), c - 0.42 * math.cos(a)) for a in np.linspace(0, math.tau, 97)])

    # The stepped fret round it (a xicalcoliuhqui's hooked steps): eight
    # steps, each climbing out in two treads and hooking back in.
    fret = []

    for k in range(8):
        a0 = math.tau * k / 8
        w = math.tau / 8

        for r, f in ((0.29, 0.0), (0.29, 0.25), (0.33, 0.25), (0.33, 0.5), (0.37, 0.5), (0.37, 0.85), (0.32, 0.85),
                     (0.32, 0.7), (0.35, 0.7)):
            a = a0 + w * f
            fret.append((c + r * math.sin(a), c - r * math.cos(a)))

        fret.append((c + 0.29 * math.sin(a0 + w), c - 0.29 * math.cos(a0 + w)))

    strokes.append(fret)

    # Four spokes to the eye.
    for k in range(4):
        a = math.pi / 4 + k * math.pi / 2
        strokes.append([(c + r * math.sin(a), c - r * math.cos(a)) for r in np.linspace(0.27, 0.13, 8)])

    # The eye and its pupil.
    strokes.append([(c + 0.11 * math.sin(a), c - 0.11 * math.cos(a)) for a in np.linspace(0, math.tau, 49)])
    strokes.append([(c + 0.03 * math.sin(a), c - 0.03 * math.cos(a)) for a in np.linspace(0, math.tau, 17)])
    return strokes


def sigil_strokes(px=512):
    """The sigil, its red channel the order of its strokes."""
    big = px * 2
    order = np.full((big, big), np.inf)
    strokes = _sigil_path()
    lengths = [sum(math.dist(a, b) for a, b in zip(s, s[1:])) for s in strokes]
    total = sum(lengths)
    done = 0.0
    width = 0.016 * big
    ys, xs = np.mgrid[0:big, 0:big]

    for stroke, length in zip(strokes, lengths):
        walked = 0.0

        for a, b in zip(stroke, stroke[1:]):
            seg = math.dist(a, b)
            steps = max(1, int(seg * big / 2))

            for k in range(steps + 1):
                t = k / steps
                x, y = (a[0] + (b[0] - a[0]) * t) * big, (a[1] + (b[1] - a[1]) * t) * big
                at = (done + walked + seg * t) / total
                x0, x1 = int(max(0, x - width)), int(min(big, x + width + 1))
                y0, y1 = int(max(0, y - width)), int(min(big, y + width + 1))
                near = (xs[y0:y1, x0:x1] - x) ** 2 + (ys[y0:y1, x0:x1] - y) ** 2 <= width ** 2
                block = order[y0:y1, x0:x1]
                block[near] = np.minimum(block[near], at)

            walked += seg

        done += length

    drawn = np.isfinite(order)
    rgba = np.zeros((big, big, 4))
    rgba[..., 0] = np.where(drawn, order, 0.0)
    rgba[..., 1] = np.where(drawn, 1.0, 0.0)
    rgba[..., 2] = np.where(drawn, 1.0, 0.0)
    rgba[..., 3] = drawn.astype(float)
    image = Image.fromarray((rgba * 255).astype(np.uint8), "RGBA").resize((px, px), Image.Resampling.NEAREST)
    return image


def main():
    VFX.mkdir(parents=True, exist_ok=True)
    sparks().save(VFX / "sparks.png")
    (VFX / "sparks.json").write_text(json.dumps({"grid": [4, 1], "frames": 4, "px": 32}))
    sigil_strokes().save(VFX / "sigil_strokes.png")
    (VFX / "sigil_strokes.json").write_text(json.dumps({"grid": [1, 1], "frames": 1, "px": 512}))
    print("sprites_2d: sparks, sigil_strokes -> %s" % VFX)


if __name__ == "__main__":
    main()
