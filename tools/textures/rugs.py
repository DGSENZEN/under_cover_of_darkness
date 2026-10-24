"""The librarian's rugs (docs/superpowers/plans/2026-10-19-librarian-shop-part-2.md, dressing): drawn knot by knot,
a pixel a knot (or a strand of palm), for the shop's nearest-texel look. Each comes with the estates he buys his
books from, or is his own:

- zapotec: a Teotitlan del Valle rug for the left aisle: undyed cream wool, cochineal red, indigo, pecan brown and
  lichen gold; an indigo band round it, a greca (the stepped fret, its hooks turned back at the rug's middle as the
  weaver turns them) down each side and across each end, a stepped diamond, the eye, in the middle of its field;
- persian: a faded Heriz-like runner for the right aisle, as Mexico City's oriental-rug dealers brought them in from
  1921: a madder field with three angular navy medallions down it (sky and gold within), a navy border with an angular vine;
- petate: a palm mat under the front table, where his customers stand: palm strips in a two-over-two twill, a band
  of dyed strips near each end, a bound edge;
- sarape: a Saltillo sarape folded into his kneeler before the quarantine cage: fine bright stripes round a serrated
  diamond.

`make(kind, worn=True)`: the rug's image (RGB), across the rug its width, along it its height. Worn, it has its
knots' unevenness, the colour banding of hand-dyed wool, the path down its middle paled by feet, its edges darkened.

    python3 tools/textures/rugs.py        writes textures/painted/underground/rug_<kind>.png
"""

import sys
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "textures" / "painted" / "underground"

# Each rug: across (m), along (m), knots (pixels) a metre.
RUGS = {"zapotec": (1.05, 1.9, 100), "persian": (0.8, 2.6, 100), "petate": (1.4, 0.85, 200),
        "sarape": (0.55, 0.4, 200)}
# The fringe at each end of the knotted rugs (rows).
FRINGE = 5
PALETTES = {
    "zapotec": {"cream": "#e6d9bd", "indigo": "#2a3a66", "cochineal": "#a2282c", "pecan": "#6a4a2f",
                "gold": "#b48e3a", "gap": "#4a3b2e", "wear": "#d8c7a4"},
    "persian": {"madder": "#8d332c", "navy": "#22304b", "ivory": "#e2d4b2", "sky": "#5f7f9c", "gold": "#b9893c",
                "brown": "#3b2619", "gap": "#4a3b2e", "wear": "#c9a98a"},
    "petate": {"straw": "#cdb06a", "straw_dark": "#a88a45", "gap": "#6b5530", "magenta": "#8e3058",
               "green": "#4d6a3c", "binding": "#8a6d38"},
    "sarape": {"black": "#1e1a1a", "saffron": "#d39a2b", "rose": "#b23a4e", "indigo": "#2c3c6c", "cream": "#e3d6bc",
               "green": "#3c6a48"},
}

# The Teotitlan rug: its greca band's columns (from its edge), the greca's period along the rug (rows).
ZAPOTEC_GRECA = (4, 15)
ZAPOTEC_GRECA_PERIOD = 12
# The greca's hook (R the cochineal fret, . the cream ground): two hooks interlock in each period, the second the first
# turned half round.
HOOK = ["RRRRR.",
        "R...R.",
        "R.R.R.",
        "R.RRR.",
        "R.....",
        "RRRRRR"]
# The Persian runner: how many medallions, its field's rows (between its end borders).
PERSIAN_MEDALLIONS = 3
PERSIAN_END = 22
PERSIAN_FIELD = (PERSIAN_END, round(RUGS["persian"][1] * RUGS["persian"][2]) - PERSIAN_END)
# The petate: a palm strip's width (pixels).
PETATE_STRAND = 4


def _rgb(code):
    return np.array([int(code[i:i + 2], 16) for i in (1, 3, 5)], np.float64)


def _size(kind):
    width, length, density = RUGS[kind]
    return round(length * density), round(width * density)


def _greca_tile():
    """The greca's period: two hooks interlocking, 12 rows by 11 columns (True: the fret)."""
    tile = np.zeros((12, 11), bool)
    hook = np.array([[c == "R" for c in row] for row in HOOK])
    tile[0:6, 0:6] |= hook
    tile[6:12, 5:11] |= hook[::-1, ::-1]
    return tile


def _mirrored(quarter_fn, h, w):
    """A design drawn by `quarter_fn(y, x)` (arrays, the rug's upper left quarter) and mirrored across and along."""
    hh, hw = (h + 1) // 2, (w + 1) // 2
    y, x = np.mgrid[0:hh, 0:hw]
    quarter = quarter_fn(y, x)
    top = np.concatenate([quarter, quarter[:, :w - hw][:, ::-1]], axis=1)
    return np.concatenate([top, top[:h - hh][::-1]], axis=0)


def _zapotec():
    h, w = _size("zapotec")
    p = {k: _rgb(v) for k, v in PALETTES["zapotec"].items()}
    tile = _greca_tile()
    cx, cy = (w - 1) / 2.0, (h - 1) / 2.0

    def quarter(y, x):
        out = np.broadcast_to(p["cream"], y.shape + (3,)).copy()
        # The field's eye: a stepped diamond, its bands outward from a cream middle.
        d = np.floor(np.abs(x - cx) / 2.0) + np.floor(np.abs(y - cy) / 3.0)
        for lo, hi, colour in ((3, 6, "cochineal"), (6, 10, "indigo"), (10, 12, "gold"), (12, 15, "cochineal"),
                               (15, 17, "pecan"), (17, 18, "indigo")):
            out[(d >= lo) & (d < hi)] = p[colour]
        # Small stepped diamonds in the field's corners.
        small = np.floor(np.abs(x - 30) / 2.0) + np.floor(np.abs(y - 42) / 3.0)
        out[small < 3] = p["pecan"]
        out[small < 1] = p["cochineal"]
        # Down each side: the indigo band, a cream line, the greca, a brown line.
        out[x < 3] = p["indigo"]
        band = (x >= ZAPOTEC_GRECA[0]) & (x < ZAPOTEC_GRECA[1])
        fret = tile[y % ZAPOTEC_GRECA_PERIOD, np.clip(x - ZAPOTEC_GRECA[0], 0, 10)]
        out[band] = p["cream"]
        out[band & fret] = p["cochineal"]
        out[x == ZAPOTEC_GRECA[1]] = p["pecan"]
        out[(x > ZAPOTEC_GRECA[1]) & (x < ZAPOTEC_GRECA[1] + 2)] = p["indigo"]
        # Across each end: a kilim's brown, indigo, cream, the greca turned across, brown.
        e = y - FRINGE
        end = e < 22
        out[end & (e < 2)] = p["pecan"]
        out[end & (e >= 2) & (e < 5)] = p["indigo"]
        out[end & (e >= 5) & (e < 6)] = p["cream"]
        across = end & (e >= 6) & (e < 17) & (x >= 3)
        out[across] = p["cream"]
        out[across & tile[np.clip(x - 3, 0, None) % ZAPOTEC_GRECA_PERIOD, np.clip(e - 6, 0, 10)]] = p["cochineal"]
        out[end & (e >= 17) & (e < 18)] = p["pecan"]
        out[end & (e >= 18) & (e < 20)] = p["indigo"]
        out[end & (e >= 20) & (x < 3)] = p["indigo"]
        # The fringe: cream warp threads, dark between.
        fringe = y < FRINGE
        out[fringe] = p["cream"]
        out[fringe & (np.abs(x - cx) % 3 < 1)] = p["gap"]
        return out

    return _mirrored(quarter, h, w)


def _persian():
    h, w = _size("persian")
    p = {k: _rgb(v) for k, v in PALETTES["persian"].items()}
    cx, cy = (w - 1) / 2.0, (h - 1) / 2.0
    medallions = [cy + k * 80 for k in range(-(PERSIAN_MEDALLIONS // 2), PERSIAN_MEDALLIONS // 2 + 1)]

    def quarter(y, x):
        out = np.broadcast_to(p["madder"], y.shape + (3,)).copy()
        # The medallions: stepped octagons, navy within an ivory line, a sky diamond and a gold heart within.
        for m in medallions:
            d = np.abs(x - cx) + 0.6 * np.abs(y - m)
            d = np.floor(d / 2.0) * 2.0
            out[d < 18] = p["ivory"]
            out[d < 16] = p["navy"]
            out[d < 9] = p["sky"]
            out[d < 4] = p["gold"]
        # Ivory spandrels at the field's corners.
        corner = (np.abs(x - cx) > 12) & (np.abs(y - cy) > 105)
        out[corner & ((np.floor(x / 2) + np.floor(y / 2)) % 3 == 0)] = p["ivory"]
        # The border down each side: navy guard, ivory stripe with madder beads, the main navy border with its
        # angular vine (ivory, gold where it turns), a sky guard.
        out[x < 2] = p["navy"]
        stripe = (x >= 2) & (x < 6)
        out[stripe] = p["ivory"]
        out[stripe & (x == 4) & (y % 4 == 0)] = p["madder"]
        main = (x >= 6) & (x < 17)
        out[main] = p["navy"]
        vine = 7 + np.abs((y % 16) - 8)
        out[main & (np.abs(x - vine) < 1)] = p["ivory"]
        out[main & (np.abs(x - vine) < 2) & (y % 16 == 8)] = p["gold"]
        out[(x >= 17) & (x < 19)] = p["sky"]
        # Across each end the same, turned.
        e = y - FRINGE
        end = (e >= 0) & (e < PERSIAN_END - FRINGE)
        out[end & (e < 2)] = p["navy"]
        out[end & (e >= 2) & (e < 6) & (x >= 2)] = p["ivory"]
        across = end & (e >= 6) & (e < 15) & (x >= 6)
        out[across] = p["navy"]
        out[across & (np.abs(e - (7 + np.abs((x % 16) - 8) * 0.5)) < 1)] = p["ivory"]
        out[end & (e >= 15) & (x >= 17)] = p["sky"]
        # The fringe.
        fringe = y < FRINGE
        out[fringe] = p["ivory"]
        out[fringe & (np.abs(x - cx) % 3 < 1)] = p["gap"]
        return out

    return _mirrored(quarter, h, w)


def _petate():
    h, w = _size("petate")
    p = {k: _rgb(v) for k, v in PALETTES["petate"].items()}
    y, x = np.mgrid[0:h, 0:w]
    s = PETATE_STRAND
    # Two over, two under, each strip of the next row a strip along: the twill's diagonal.
    upright = ((x // s) + (y // s)) % 4 < 2
    out = np.where(upright[..., None], p["straw"], p["straw_dark"])
    # Each strip rounded: lighter down its middle, a dark line between strips.
    across = np.where(upright, x % s, y % s)
    out = out * (0.9 + 0.12 * np.sin(np.pi * (across + 0.5) / s))[..., None]
    out[across == 0] = p["gap"]
    # A band of dyed strips near each end (the crossing strips there dyed).
    for lo, colour in ((14, "magenta"), (h - 22, "magenta"), (24, "green"), (h - 32, "green")):
        band = (y >= lo) & (y < lo + 2 * s) & ~upright
        out[band] = p[colour] * (0.9 + 0.12 * np.sin(np.pi * ((y[band] % s) + 0.5) / s))[..., None]
    # The bound edge.
    edge = (x < 6) | (x >= w - 6) | (y < 6) | (y >= h - 6)
    out[edge] = p["binding"] * (0.85 + 0.15 * ((x[edge] + y[edge]) % 3 == 0))[..., None]
    return out


def _sarape():
    h, w = _size("sarape")
    p = {k: _rgb(v) for k, v in PALETTES["sarape"].items()}
    cx, cy = (w - 1) / 2.0, (h - 1) / 2.0
    stripes = ["black", "saffron", "rose", "cream", "indigo", "rose", "green", "saffron"]
    rings = ["cream", "black", "rose", "saffron", "indigo", "green", "rose", "black", "saffron", "cream", "indigo"]

    def quarter(y, x):
        # Fine stripes across, from its middle out.
        k = (np.floor(np.abs(y - cy) / 2.0)).astype(int) % len(stripes)
        out = np.stack([p[stripes[i]] for i in range(len(stripes))])[k]
        # The diamond: serrated rings, their edges zigzagging two knots.
        d = np.abs(x - cx) + 1.4 * np.abs(y - cy)
        d = d + 2.0 * ((np.floor(np.abs(y - cy)) % 2) == 1)
        ring = np.floor(d / 4.0).astype(int)
        inside = ring < len(rings)
        coloured = np.stack([p[rings[i]] for i in range(len(rings))])[np.clip(ring, 0, len(rings) - 1)]
        out[inside] = coloured[inside]
        # Its edge: a black line, cream beyond.
        out[x < 2] = p["black"]
        out[(x >= 2) & (x < 4)] = p["cream"]
        return out

    return _mirrored(quarter, h, w)


DRAW = {"zapotec": _zapotec, "persian": _persian, "petate": _petate, "sarape": _sarape}


def _worn(kind, image, rng):
    """The rug as it has lived: knots uneven, dyes banded, the path down its middle paled by feet, its edges and
    ends darker with grime."""
    h, w = image.shape[:2]
    out = image.copy()
    # Each knot a little off its neighbours; the wool's dye lots banded across the rug (abrash).
    out *= rng.uniform(0.93, 1.06, (h, w, 1))
    if kind in ("zapotec", "persian", "sarape"):
        rows = np.cumsum(rng.integers(8, 24, h))
        bands = rng.uniform(0.93, 1.05, len(rows) + 1)
        out *= bands[np.searchsorted(rows, np.arange(h), side="right")][:, None, None]
    y, x = np.mgrid[0:h, 0:w]
    across = (x - (w - 1) / 2.0) / (w / 2.0)
    along = (y - (h - 1) / 2.0) / (h / 2.0)
    if kind in ("zapotec", "persian"):
        # Worn down the middle: the pile gone to its paler ground, most where most feet go.
        path = np.exp(-(across / 0.32) ** 2) * (1.0 - 0.4 * along ** 2)
        wear = _rgb(PALETTES[kind]["wear"])
        out = out + (wear - out) * (0.42 * path)[..., None]
    if kind == "petate":
        # Darkened where the customers stand.
        out *= (1.0 - 0.12 * np.exp(-(across / 0.5) ** 2 - (along / 0.6) ** 2))[..., None]
    # Grime at the edges.
    edge = np.minimum.reduce([x, w - 1 - x, y, h - 1 - y]).astype(float)
    out *= (0.82 + 0.18 * np.clip(edge / 8.0, 0.0, 1.0))[..., None]
    return out


def make(kind, worn=True):
    """The rug `kind`'s image (RGB): across the rug its width, along it its height."""
    image = DRAW[kind]().astype(np.float64)
    if worn:
        image = _worn(kind, image, np.random.default_rng({"zapotec": 3, "persian": 5, "petate": 7, "sarape": 9}[kind]))
    return Image.fromarray(np.clip(image, 0, 255).round().astype(np.uint8), "RGB")


if __name__ == "__main__":
    OUT.mkdir(parents=True, exist_ok=True)
    for kind in RUGS:
        path = OUT / ("rug_%s.png" % kind)
        make(kind).save(path)
        print("wrote", path.relative_to(ROOT))
    sys.exit(0)
