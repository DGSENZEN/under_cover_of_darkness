"""The Pasaje's bills (docs/superpowers/specs/2026-10-26-pasaje-market-design.md): what the city pastes on the
market's walls, a 4 x 3 sheet the set cuts into its paper sheets.

Left empty, at the user's word (Oct 26 2026: the drawn bills were "too simplistic, let's keep em empty"): each kind
its paper stock and size (the missing person's newsprint, the reward for a nahual's yellow, the curandero's small
white card, the exorcist's white, the cabaret's black, the lucha night's yellow, the Company's white notice, the
lotería's pink, the wanted spirit's kraft, the fiesta's green), torn, aged, damp, pasted and stapled, nothing printed:
the user's own bills go on them. And two sheets of tatters: scraps of older bills torn back.

Paper grain, tearing, damp and paste come from the user's brush sheets (textures/brushes).

    python3 tools/textures/pasaje_bills.py
"""

import random
import sys
from pathlib import Path

import numpy as np
from PIL import Image
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

# Each bill's sheet within its cell (fractions: x from, y from, x to, y to) and its paper.
SHEETS = {"missing": ((0.16, 0.08, 0.84, 0.92), NEWSPRINT), "nahual_reward": ((0.12, 0.1, 0.88, 0.9), YELLOW),
          "curandero": ((0.26, 0.24, 0.74, 0.76), WHITE), "exorcist": ((0.18, 0.08, 0.82, 0.92), WHITE),
          "cabaret": ((0.16, 0.06, 0.84, 0.94), NIGHT), "lucha_night": ((0.12, 0.08, 0.88, 0.92), YELLOW),
          "company_notice": ((0.14, 0.06, 0.86, 0.94), WHITE), "loteria": ((0.14, 0.1, 0.86, 0.9), PINK),
          "wanted_spirit": ((0.16, 0.08, 0.84, 0.92), KRAFT), "fiesta": ((0.14, 0.1, 0.86, 0.9), GREEN)}


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
    """A kind's sheet of paper, empty: its stock, grained, aged, torn, its edge rimmed, stapled at its top corners."""
    box, paper = SHEETS[kind]
    x0, y0, x1, y1 = (c * BIG for c in box)
    y, x = np.mgrid[0:BIG, 0:BIG]
    inside = (x >= x0) & (x <= x1) & (y >= y0) & (y <= y1)
    rgb = np.broadcast_to(np.array(paper, np.float64), (BIG, BIG, 3)) * (0.9 + 0.16 * grain)[..., None]
    rgb = _aged(rgb.copy(), inside, (x0, y0, x1, y1), grain, rng)
    keep = _torn(inside, (x0, y0, x1, y1), grain, rng, bites=rng.randint(1, 3), strip=rng.random() < 0.4)
    # The grime and paste gathered along its torn edge, which sets the sheet off the wall.
    rgb = _rimmed(rgb, keep)
    # Staples at its top corners.
    for cx in (x0 + 18, x1 - 18):
        rgb[int(y0) + 12:int(y0) + 16, int(cx) - 8:int(cx) + 8] = (150, 150, 156)
    out = np.dstack([np.clip(rgb, 0, 255), keep * 255.0]).astype(np.uint8)
    return np.asarray(Image.fromarray(out, "RGBA").resize((CELL, CELL), Image.LANCZOS))


def _tatters(rng, grain):
    """Scraps of older bills torn back: strips left hanging where a bill was ripped down, corners still pasted on,
    each scrap a different paper, as empty as the bills."""
    out = np.zeros((BIG, BIG, 4))
    papers = [NEWSPRINT, YELLOW, PINK, GREEN, WHITE, KRAFT]
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
