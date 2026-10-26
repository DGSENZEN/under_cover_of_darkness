"""The marks of what happened in the Pasaje (docs/superpowers/specs/2026-10-26-pasaje-market-design.md; plan Task 7,
at the user's word on Oct 26 2026: "environmental storytelling that tell this is a metropolis where magic and the
occult and the supernatural are part of it"): four marks on a 2 x 2 sheet the set cuts into its decals, and their
normal map, for the two that are cut into the tile.

- scorch: the wall behind the north circle, where the rite went wrong: the soot of a fire that stood at the wall's
  foot, risen in a plume that widened as it climbed, billowed and streaked; at its root the plaster burned clean and
  pale where it was hottest, black char round that, crazed and flaking;
- gouges: four claws dug into the floor at the candle lane's mouth and dragged out into the street: the glaze
  shattered where they bit, the tile's bisque bared down their walls, grime at their bottoms, their lips chipped,
  lifting and thinning as they went, the chips flung out at their ends;
- hand: under the canopy, a soot hand too big to be a person's pressed on the wall, its fingers long and clawed:
  powdery, heavy at its pads and rim and light in its hollow, its creases broken gaps, its heel smeared down where
  it slid;
- spiral: the floor beside the north circle cracked in a spiral out from where something struck, branching, a few
  cracks running straight out from the heart, the tile crushed and sunk there, its glaze chipped along the cracks.

Grain comes from the user's brush sheets (textures/brushes).

    python3 tools/textures/pasaje_marks.py
"""

import math
import random
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage
from scipy.spatial import cKDTree

sys.path.insert(0, str(Path(__file__).resolve().parent))

import brushes as brush_sheets  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "textures" / "painted" / "underground"
GRID = 2
CELL = 512
BORDER = 8
# Drawn at twice the cell, then brought down.
BIG = CELL * 2
MARKS = ["scorch", "gouges", "hand", "spiral"]
SOOT, CHAR, BAKED, ASH = (20, 17, 15), (9, 7, 7), (98, 62, 38), (196, 188, 174)
GRIME, BISQUE, GLAZE = (30, 25, 22), (158, 112, 82), (214, 204, 186)
CRACK, STAIN = (22, 18, 16), (58, 46, 38)
# How far a cut's walls tilt the normal: its depth in cell pixels.
GOUGE_DEPTH, CRACK_DEPTH = 5.0, 3.0


def _grain(name, brushes_dir):
    values = brush_sheets.load(name, brushes_dir)
    image = Image.fromarray((values * 255).astype(np.uint8), "L").resize((CELL, CELL), Image.BILINEAR)
    return np.asarray(image, np.float64) / 255.0


def _noise(rng, sigma, stretch=(1.0, 1.0), size=CELL):
    """A smooth noise about 0..1 (mean 0.5), its blobs `sigma` px, drawn out by `stretch` (x, y)."""
    field = np.random.default_rng(rng.randrange(1 << 30)).standard_normal((size, size))
    field = ndimage.gaussian_filter(field, (sigma * stretch[1], sigma * stretch[0]), mode="wrap")
    return np.clip(0.5 + 0.18 * (field - field.mean()) / (field.std() + 1e-9), 0, 1)


def _mottle(rng, grain):
    """Powder and grain: the brush sheet's grain broken by fine noise, about 0..1."""
    return np.clip(0.5 * grain + 0.35 * _noise(rng, 1.2) + 0.3 * _noise(rng, 5) - 0.08, 0, 1)


def _down(values):
    """A float field at BIG brought down to the cell."""
    image = Image.fromarray(np.clip(values * 255, 0, 255).astype(np.uint8), "L")
    return np.asarray(image.resize((CELL, CELL), Image.LANCZOS), np.float64) / 255.0


def _canvas():
    return Image.new("L", (BIG, BIG), 0)


def _f(canvas):
    return np.asarray(canvas, np.float64) / 255.0


def _mix(a, b, t):
    return np.array(a, np.float64) * (1 - t[..., None]) + np.array(b, np.float64) * t[..., None]


def _jagged(points, rng, amp):
    """A path broken into a crack's jags: each point pushed off sideways by a random walk."""
    out, walk = [], 0.0
    for k, (x, y) in enumerate(points):
        walk = 0.6 * walk + rng.uniform(-amp, amp)
        if 0 < k < len(points) - 1:
            dx, dy = points[k + 1][0] - points[k - 1][0], points[k + 1][1] - points[k - 1][1]
            n = math.hypot(dx, dy) or 1.0
            out.append((x - dy / n * walk, y + dx / n * walk))
        else:
            out.append((x, y))
    return out


def _wave(rng, terms=7, low=3, high=19):
    """A 1-D noise as a sum of sines: f(t) in about [-1, 1]."""
    parts = [(rng.uniform(low, high), rng.uniform(0, 2 * math.pi), rng.uniform(0.4, 1.0)) for _ in range(terms)]
    total = sum(a for _, _, a in parts)
    return lambda t: sum(a * np.sin(f * t + p) for f, p, a in parts) / total


def _crack_line(draw, pts, widths):
    for k in range(len(pts) - 1):
        draw.line([(pts[k][0] * BIG, pts[k][1] * BIG), (pts[k + 1][0] * BIG, pts[k + 1][1] * BIG)], fill=255,
                  width=max(1, int(round(widths[k]))))


# --- the marks -----------------------------------------------------------------------------------------
# Each returns (rgb at the cell, alpha 0..1 at the cell, height at the cell in pixels, 0 the surface, below it less).

def _scorch(rng, grain):
    y, x = np.mgrid[0:CELL, 0:CELL] / CELL
    sx, sy = 0.5, 0.86
    # The smoke's roll: the plume pushed about by a slow noise, more the higher it climbed.
    rise = np.clip(sy - y, 0, None)
    wx = x + (_noise(rng, 26) - 0.5) * 0.28 * (0.2 + rise)
    wy = y + (_noise(rng, 22) - 0.5) * 0.12 * rise
    rise = np.clip(sy - wy, 0, None)
    width = 0.05 + 0.3 * (rise / 0.72) ** 0.7
    lateral = np.exp(-((wx - sx) / width) ** 2 * 1.4)
    climb = np.clip(1 - rise / 0.74, 0, 1) ** 0.8
    below = np.exp(-(np.clip(wy - sy, 0, None) / 0.035) ** 2)
    density = lateral * climb * below
    # Billows and the streaks the heat drew up through them.
    density *= 0.5 + 0.8 * _noise(rng, 9)
    density *= 0.7 + 0.6 * _noise(rng, 2.5, (1.0, 7.0))
    density = np.clip(density * 1.25, 0, 1)
    # The fire's root: charred black, and in it the plaster burned clean and pale where it was hottest.
    # (Both rooted in the plume, widening up it: the burn's V.)
    root = np.hypot((wx - sx) / (0.05 + 0.45 * rise), rise / 0.3) * (wy < sy + 0.02)
    char = np.clip(1.2 - root, 0, 1) * (0.7 + 0.5 * _noise(rng, 3)) * (wy < sy + 0.02)
    clean = np.clip(1 - np.hypot((wx - sx) / (0.012 + 0.22 * rise), (rise - 0.05) / 0.08), 0, 1) ** 1.5 * 0.6
    # The char crazed in fine lines (where two nearest seeds tie), the baked plaster showing through.
    gy, gx = np.mgrid[0:BIG, 0:BIG] / BIG
    seeds = np.array([(sx + rng.gauss(0, 0.1), sy - 0.06 + rng.gauss(0, 0.1)) for _ in range(140)])
    near, _ = cKDTree(seeds).query(np.dstack([gx, gy]).reshape(-1, 2), k=2)
    craze = _down(((near[:, 1] - near[:, 0]) < 0.0016).reshape(BIG, BIG).astype(np.float64)) * np.clip(char * 1.5, 0, 1)
    tone = density ** 0.55
    rgb = _mix(BAKED, SOOT, tone)
    rgb = _mix(rgb, CHAR, np.clip(char, 0, 1))
    rgb = _mix(rgb, BAKED, np.clip(craze * 1.4, 0, 1))
    rgb = _mix(rgb, ASH, clean)
    mottle = _mottle(rng, grain)
    alpha = np.clip(density * 1.3, 0, 0.96) * (0.7 + 0.45 * mottle)
    alpha = np.maximum(alpha, np.clip(char * 1.4, 0, 0.97))
    # Flakes of char come away, small, the plaster bare under them.
    flakes = (_noise(rng, 1.4) > 0.8) & (char > 0.3)
    alpha *= np.where(flakes, 0.55, 1.0)
    rgb *= (0.86 + 0.24 * mottle)[..., None]
    return rgb, np.clip(alpha, 0, 1), np.zeros((CELL, CELL))


def _gouges(rng, grain):
    y, x = np.mgrid[0:BIG, 0:BIG] / BIG
    pixels = np.dstack([x, y]).reshape(-1, 2)
    across = np.full(BIG * BIG, 9.0)
    depth_at = np.zeros(BIG * BIG)
    ragged = np.repeat(np.repeat(_noise(rng, 1.5), 2, 0), 2, 1).reshape(-1)
    sway = rng.uniform(-0.05, 0.05)
    bits = _canvas()
    draw = ImageDraw.Draw(bits)
    for g in range(4):
        spread = g - 1.5
        start, end = 0.1 + 0.04 * abs(spread) + rng.uniform(0, 0.03), 0.9 - 0.06 * abs(spread) - rng.uniform(0, 0.04)
        t = np.linspace(0, 1, 800)
        ys = start + (end - start) * t
        xs = 0.5 + spread * (0.105 + 0.04 * t) + sway * np.sin(t * math.pi * 0.9) + 0.008 * np.sin(t * 7 + g)
        wobble = _wave(rng, 6, 8, 40)(t)
        # It bit in hard and fast, then lifted as it went: widest and deepest just past where it bit.
        width = (0.031 - 0.004 * abs(spread)) * np.clip(t / 0.05, 0, 1) ** 0.35 * (1 - t) ** 0.5 * (1 + 0.2 * wobble)
        width += 0.0015
        depth = np.clip(t / 0.04, 0, 1) ** 0.4 * (1 - t) ** 0.7
        dist, k = cKDTree(np.dstack([xs, ys])[0]).query(pixels)
        rel = dist / (width[k] * (0.82 + 0.36 * ragged))
        closer = rel < across
        across = np.where(closer, rel, across)
        depth_at = np.where(closer, depth[k], depth_at)
        # Where it bit: the glaze shattered round the point, its shards flung forward.
        bx, by = xs[0], ys[0]
        for _ in range(rng.randint(6, 10)):
            a, r = rng.uniform(0, 2 * math.pi), rng.uniform(0.008, 0.03)
            px, py, s = bx + math.cos(a) * r, by + math.sin(a) * r, rng.uniform(1.5, 3.5)
            draw.polygon([((px + rng.uniform(-1, 1) * s / BIG) * BIG, (py + rng.uniform(-1, 1) * s / BIG) * BIG)
                          for _ in range(4)], fill=255)
        # Where it left the floor, the tile it tore up flung on ahead.
        for _ in range(rng.randint(6, 11)):
            px, py = xs[-1] + rng.gauss(0, 0.018), ys[-1] + abs(rng.gauss(0.025, 0.03))
            s = rng.uniform(1.5, 4.5)
            draw.ellipse((px * BIG - s, py * BIG - s, px * BIG + s, py * BIG + s), fill=255)
    # Scratches the claws' hooks left alongside, too faint to be grooves.
    scratch = _canvas()
    sdraw = ImageDraw.Draw(scratch)
    for _ in range(7):
        sx, sy = 0.5 + rng.uniform(-0.27, 0.27), rng.uniform(0.15, 0.45)
        length = rng.uniform(0.12, 0.32)
        pts = [(sx + 0.01 * math.sin(s * 4), sy + length * s) for s in np.linspace(0, 1, 30)]
        sdraw.line([(px * BIG, py * BIG) for px, py in _jagged(pts, rng, 0.002)], fill=255, width=2)
    across = across.reshape(BIG, BIG)
    depth_at = depth_at.reshape(BIG, BIG)
    cut = np.clip(1 - across ** 2, 0, 1) * depth_at
    h = -GOUGE_DEPTH * _down(cut)
    inner = _down(((across < 1.0) * (0.6 + 0.4 * depth_at)).astype(np.float64))
    lip_band = _down(((across >= 0.95) & (across < 1.45)).astype(np.float64))
    bottom = _down(np.clip(1 - across, 0, 1) * depth_at)
    shards, scratched = _down(_f(bits)), _down(_f(scratch))
    mottle = _mottle(rng, grain)
    # Down its walls the bisque bared, a thin band under the lip; grime gathered over the rest, down to its bottom.
    rgb = _mix(BISQUE, GRIME, np.clip(bottom * 3.0 + 0.2, 0, 1))
    chipped = lip_band * (_noise(rng, 1.3) > 0.52)
    rgb = np.where((inner < 0.2)[..., None], _mix(GLAZE, BISQUE, np.clip(chipped * 0.7 + shards * 0.5, 0, 1)), rgb)
    rgb = np.where((scratched > 0.3)[..., None] & (inner < 0.2)[..., None], np.array(GRIME, np.float64), rgb)
    alpha = np.clip(inner * 1.4, 0, 0.97)
    alpha = np.maximum(alpha, chipped * 0.72)
    alpha = np.maximum(alpha, shards * 0.7)
    alpha = np.maximum(alpha, scratched * 0.4)
    # Grit dragged along with the claws, a haze down their tracks.
    haze = np.clip(ndimage.gaussian_filter(inner, 7) * 0.45, 0, 0.2) * (0.4 + mottle)
    rgb = np.where((alpha < haze)[..., None], np.array(GRIME, np.float64), rgb)
    alpha = np.maximum(alpha, haze)
    # Grit lying in the grooves.
    grit = (_noise(rng, 0.8) > 0.68) & (inner > 0.3)
    rgb = np.where(grit[..., None], np.array(BISQUE, np.float64) * 0.8, rgb)
    rgb *= (0.84 + 0.28 * mottle)[..., None]
    return rgb, np.clip(alpha, 0, 1), h


def _stamp_path(draw, points, radii):
    for (px, py), r in zip(points, radii):
        draw.ellipse((px * BIG - r, py * BIG - r, px * BIG + r, py * BIG + r), fill=255)


def _finger(base, direction, lengths, bends, radius, rng):
    """A finger's path: its joints bending smoothly off one another from the base, then its claw, hooked inwards."""
    pts, radii = [], []
    x, y = base
    a = direction
    r = radius
    for length, bend in zip(lengths, bends):
        for s in np.linspace(0, 1, 40, endpoint=False):
            b = a + bend * s
            x, y = x + math.sin(b) * length / 40, y - math.cos(b) * length / 40
            pts.append((x, y))
            # A knuckle swells a little at each joint.
            radii.append(r * BIG * (1 - 0.12 * s + 0.08 * math.exp(-((s - 0.0) / 0.12) ** 2)))
        a += bend
        r *= 0.86
    hook = -0.3 if direction > 0 else 0.3
    claw = 0.06 + rng.uniform(0, 0.015)
    for s in np.linspace(0, 1, 40):
        b = a + hook * s
        x, y = x + math.sin(b) * claw / 40, y - math.cos(b) * claw / 40
        pts.append((x, y))
        radii.append(max(1.0, r * BIG * (1 - s) ** 1.3))
    return pts, radii


def _hand(rng, grain):
    print_ = _canvas()
    draw = ImageDraw.Draw(print_)
    pads, creases = _canvas(), _canvas()
    pdraw, cdraw = ImageDraw.Draw(pads), ImageDraw.Draw(creases)
    # The palm, a little skewed, and the wrist running down out of it.
    palm = [(0.37, 0.54), (0.5, 0.515), (0.63, 0.525), (0.665, 0.62), (0.65, 0.72), (0.6, 0.84), (0.5, 0.86),
            (0.42, 0.85), (0.365, 0.76), (0.35, 0.66)]
    draw.polygon([(px * BIG, py * BIG) for px, py in palm], fill=255)
    draw.polygon([(px * BIG, py * BIG) for px, py in [(0.43, 0.8), (0.59, 0.8), (0.575, 0.955), (0.455, 0.955)]],
                 fill=255)
    # Four fingers, too long, splayed; the middle one longest.
    for bx, a, lengths in ((0.395, -0.17, [0.12, 0.1, 0.08]), (0.46, -0.06, [0.14, 0.12, 0.09]),
                           (0.535, 0.04, [0.135, 0.115, 0.09]), (0.605, 0.16, [0.11, 0.09, 0.07])):
        bends = [rng.uniform(-0.05, 0.05), rng.uniform(-0.14, 0.14), rng.uniform(-0.16, 0.16)]
        pts, radii = _finger((bx, 0.56), a, lengths, bends, 0.031, rng)
        _stamp_path(draw, pts, radii)
        # The pads, where it pressed hardest: each joint's middle, the last most.
        for lo, hi in ((10, 30), (50, 70), (85, 118)):
            _stamp_path(pdraw, pts[lo:hi], [rr * 0.75 for rr in radii[lo:hi]])
        for k in (40, 80):
            jx, jy = pts[k]
            cdraw.line([((jx - 0.028) * BIG, (jy + rng.uniform(-0.004, 0.004)) * BIG),
                        ((jx + 0.028) * BIG, (jy + rng.uniform(-0.004, 0.004)) * BIG)], fill=255, width=4)
    # The thumb, from low on the palm's side, splayed out.
    pts, radii = _finger((0.37, 0.72), -0.9, [0.09, 0.08], [rng.uniform(-0.05, 0.05), 0.18], 0.035, rng)
    _stamp_path(draw, pts, radii)
    _stamp_path(pdraw, pts[45:78], [rr * 0.75 for rr in radii[45:78]])
    # The palm's own lines, where its creases kept off the wall.
    for line in ([(0.39, 0.625), (0.5, 0.605), (0.63, 0.585)], [(0.37, 0.68), (0.47, 0.7), (0.57, 0.78)],
                 [(0.5, 0.84), (0.515, 0.7), (0.55, 0.57)]):
        pts = [tuple(np.array(line[0]) * (1 - s) ** 2 + 2 * np.array(line[1]) * s * (1 - s) + np.array(line[2]) * s ** 2)
               for s in np.linspace(0, 1, 30)]
        cdraw.line([(px * BIG, py * BIG) for px, py in _jagged(pts, rng, 0.003)], fill=255, width=4)
    blurred = _down(ndimage.gaussian_filter(_f(print_), 2.5))
    # Its edge broken where the soot took and didn't.
    m = np.clip((blurred - 0.5 + 0.35 * (_noise(rng, 1.3) - 0.5)) * 5 + 0.5, 0, 1)
    rim = np.clip(1 - ndimage.distance_transform_edt(m > 0.5) / 7, 0, 1) * (m > 0.5)
    p = _down(ndimage.gaussian_filter(_f(pads), 10))
    c = _down(_f(creases)) * (_noise(rng, 2) > 0.42)
    y, x = np.mgrid[0:CELL, 0:CELL] / CELL
    hollow = np.clip(1 - np.hypot((x - 0.51) / 0.1, (y - 0.68) / 0.1), 0, 1)
    # The wrist pressed lightly, fading off below the heel: no edge where an arm would be.
    wrist = np.clip((y - 0.82) / 0.13, 0, 1) ** 0.8 * (0.85 + 0.3 * (_noise(rng, 3, (1.0, 4.0)) - 0.5))
    pressure = np.clip(0.8 + 0.2 * p + 0.2 * rim - 0.4 * hollow - 0.6 * c - 0.95 * wrist, 0, 1)
    mottle = _mottle(rng, grain)
    alpha = np.clip(m * pressure * (0.72 + 0.5 * mottle), 0, 0.97)
    # Its heel smeared down where it slid, in streaks; the soot it shed fallen below.
    columns = _noise(rng, 3, (1.0, 12.0))
    drag = np.zeros_like(m)
    heel = m * (y > 0.74)
    for step in range(1, 30):
        drag = np.maximum(drag, np.roll(heel, step, axis=0) * (1 - step / 30) ** 1.3)
    drag *= np.clip(columns * 1.8 - 0.3, 0, 1)
    alpha = np.maximum(alpha, drag * 0.55 * (0.6 + 0.5 * mottle))
    mist = np.clip(ndimage.gaussian_filter(m, 6) * 0.2, 0, 0.15) * (0.5 + mottle)
    alpha = np.maximum(alpha, mist)
    rgb = _mix((70, 64, 58), SOOT, np.clip(alpha * 1.5, 0, 1))
    rgb *= (0.84 + 0.28 * mottle)[..., None]
    return rgb, np.clip(alpha, 0, 1), np.zeros((CELL, CELL))


def _spiral(rng, grain):
    cracks = _canvas()
    draw = ImageDraw.Draw(cracks)
    cx, cy = 0.5, 0.5
    end = 2.6 * 2 * math.pi
    b = math.log(0.43 / 0.03) / end
    thetas = np.linspace(0, end, 1000)
    pts = _jagged([(cx + 0.03 * math.exp(b * t) * math.cos(t), cy + 0.03 * math.exp(b * t) * math.sin(t))
                   for t in thetas], rng, 0.0035)
    # Widest near the heart, where it struck, thinning out, its width wandering.
    wander = _wave(rng, 6, 10, 60)(np.linspace(0, 1, len(pts)))
    _crack_line(draw, pts, [max(1.5, (10 - 6 * k / len(pts)) * (1 + 0.35 * wander[k])) for k in range(len(pts))])
    # Branches off the spiral, running outward, forking.
    for _ in range(26):
        k = rng.randrange(80, len(pts) - 2)
        x0, y0 = pts[k]
        out = math.atan2(y0 - cy, x0 - cx) + rng.uniform(-0.7, 0.7)
        length = rng.uniform(0.025, 0.09)
        branch = _jagged([(x0 + math.cos(out) * length * s, y0 + math.sin(out) * length * s)
                          for s in np.linspace(0, 1, 25)], rng, 0.003)
        _crack_line(draw, branch, np.linspace(4.5, 1.5, len(branch)))
        if rng.random() < 0.4:
            fx, fy = branch[len(branch) // 2]
            fork = out + rng.choice((-0.6, 0.6))
            twig = _jagged([(fx + math.cos(fork) * 0.03 * s, fy + math.sin(fork) * 0.03 * s)
                            for s in np.linspace(0, 1, 12)], rng, 0.002)
            _crack_line(draw, twig, np.linspace(3, 1, len(twig)))
    # A few running straight out from the heart.
    for _ in range(5):
        out = rng.uniform(0, 2 * math.pi)
        length = rng.uniform(0.14, 0.3)
        ray = _jagged([(cx + math.cos(out) * length * s, cy + math.sin(out) * length * s)
                       for s in np.linspace(0, 1, 50)], rng, 0.004)
        _crack_line(draw, ray, np.linspace(6, 2, len(ray)))
    # The heart crushed: short cracks every way, the tile sunk there.
    for _ in range(36):
        a = rng.uniform(0, 2 * math.pi)
        r0, r1 = rng.uniform(0, 0.02), rng.uniform(0.03, 0.065)
        draw.line(((cx + math.cos(a) * r0) * BIG, (cy + math.sin(a) * r0) * BIG,
                   (cx + math.cos(a + 0.2) * r1) * BIG, (cy + math.sin(a + 0.2) * r1) * BIG), fill=255, width=2)
    c = _down(_f(cracks))
    y, x = np.mgrid[0:CELL, 0:CELL] / CELL
    r = np.hypot(x - cx, y - cy)
    sunk = np.clip(1 - r / 0.05, 0, 1) ** 1.5
    h = -CRACK_DEPTH * ndimage.gaussian_filter(c, 0.6) - 2.0 * sunk
    mottle = _mottle(rng, grain)
    # The glaze chipped off along the cracks, the bisque under it.
    along = ndimage.gaussian_filter(c, 2.0)
    chipped = (along > 0.08) & (c < 0.25) & (_noise(rng, 1.2) > 0.58)
    rgb = np.zeros((CELL, CELL, 3)) + np.array(CRACK, np.float64)
    alpha = np.clip(c * 1.35, 0, 0.95)
    rgb = np.where(chipped[..., None], np.array(BISQUE, np.float64), rgb)
    alpha = np.where(chipped, np.maximum(alpha, 0.68), alpha)
    # The tile round it stained, as if by heat or the damp the strike drew up; the crushed heart grimed.
    stain = np.clip(1 - r / 0.44, 0, 1) ** 1.4 * 0.3 * (0.35 + 0.9 * mottle)
    stain = np.maximum(stain, sunk * 0.85)
    rgb = np.where((alpha < stain)[..., None], np.array(STAIN, np.float64), rgb)
    alpha = np.maximum(alpha, stain)
    rgb *= (0.86 + 0.24 * mottle)[..., None]
    return rgb, np.clip(alpha, 0, 1), h


def _normal(height):
    """A height field (cell pixels, 0 the surface) as a tangent-space normal map (Y up)."""
    gy, gx = np.gradient(height)
    n = np.dstack([-gx, gy, np.ones_like(height)])
    n /= np.linalg.norm(n, axis=2, keepdims=True)
    return np.round((n * 0.5 + 0.5) * 255).astype(np.uint8)


def make(brushes_dir=brush_sheets.BRUSHES):
    """The sheet and its normal map: GRID x GRID marks, laid out as MARKS."""
    rng = random.Random(1936)
    grains = [_grain("brush_%02d" % i, brushes_dir) for i in range(5)]
    albedo = np.zeros((GRID * CELL, GRID * CELL, 4), np.uint8)
    normal = np.zeros((GRID * CELL, GRID * CELL, 3), np.uint8)
    for k, kind in enumerate(MARKS):
        rgb, alpha, height = {"scorch": _scorch, "gouges": _gouges, "hand": _hand, "spiral": _spiral}[kind](
            rng, grains[(k + 1) % len(grains)])
        # (The engine lays the decal over the wall in linear light, where a share `a` of soot reads only about
        # 1 - (1 - a) ** 2.2 as dark as it does painted here: carried up to that, it reads as painted.)
        alpha = 1 - (1 - alpha) ** 2.2
        cell = np.dstack([np.clip(rgb, 0, 255), alpha * 255]).round().astype(np.uint8)
        cell[:BORDER, :, 3] = cell[-BORDER:, :, 3] = 0
        cell[:, :BORDER, 3] = cell[:, -BORDER:, 3] = 0
        height[:BORDER] = height[-BORDER:] = 0
        height[:, :BORDER] = height[:, -BORDER:] = 0
        j, i = divmod(k, GRID)
        albedo[j * CELL:(j + 1) * CELL, i * CELL:(i + 1) * CELL] = cell
        normal[j * CELL:(j + 1) * CELL, i * CELL:(i + 1) * CELL] = _normal(height)
    return Image.fromarray(albedo, "RGBA"), Image.fromarray(normal, "RGB")


if __name__ == "__main__":
    OUT.mkdir(parents=True, exist_ok=True)
    albedo, normal = make()
    for name, image in (("pasaje_marks.png", albedo), ("pasaje_marks_n.png", normal)):
        path = OUT / name
        image.save(path)
        print("wrote", path.relative_to(ROOT))
