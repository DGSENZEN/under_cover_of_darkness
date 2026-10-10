"""A district plan drawn as sheets for the user's approval (the Zócalo spec,
section 2): street, roofs, underground, canal, events, and all of them. North
up, a 10 m grid (every 100 m darker), a scale bar, developer labels (element
names only).

    python3 tools/level/plan_draw.py <plan.json> <out dir>
"""

import json
import os
import sys
from pathlib import Path

from PIL import Image, ImageDraw

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "layouts"))

import plan  # noqa: E402

SHEETS = ("street", "roofs", "underground", "canal", "events", "all")
MARGIN = 40
PAPER = (238, 232, 220)
NIGHT = (22, 22, 28)
INK = (40, 36, 34)

GROUND_COLOURS = {
    "plaza": (214, 208, 196), "street": (190, 184, 176), "atrium": (204, 196, 178), "courtyard": (200, 190, 168),
    "market": (210, 186, 150), "canal": (70, 110, 150), "landing": (120, 140, 156), "dig": (150, 120, 92),
    "well": (90, 90, 100),
}
# One colour per kit family the Zócalo uses; any other family is grey.
FAMILY_COLOURS = {
    "house": (172, 92, 74), "arcade": (196, 150, 110), "cathedral": (120, 112, 128), "sagrario": (140, 120, 138),
    "palace": (150, 70, 60), "pawnshop": (110, 80, 120), "iturbide": (160, 110, 90), "inquisition": (80, 60, 70),
    "evangelistas": (190, 160, 120), "church": (130, 120, 112), "deco_tower": (70, 130, 110),
    "market_hall": (90, 120, 120), "stall": (200, 170, 90), "town_hall": (170, 120, 100),
}
OTHER_FAMILY = (150, 150, 150)
ROUTE_COLOURS = {"roof_link": (220, 120, 40), "climb": (240, 200, 40), "stair": (40, 160, 200),
                 "bridge": (60, 60, 60), "tunnel": (200, 80, 200)}
EVENT_COLOURS = {"subsidence": (230, 60, 50), "water": (50, 110, 240), "seepage": (60, 220, 110),
                 "use": (240, 170, 40)}
# What each sheet names (its own layer only, so names do not pile up).
LABELS = {"street": ("ground", "plots"), "roofs": ("plots",), "underground": ("spaces",), "canal": ("ground",),
          "events": (), "all": ("ground", "plots")}
# The event sheet samples the fields every this many metres.
EVENT_STEP = 4.0


def projection(data, px_per_m):
    """(x, z) to pixels, north up: x grows right, z (south) grows down."""
    xs = [p[0] for p in data["brink"]]
    zs = [p[1] for p in data["brink"]]
    x0, z0 = min(xs), min(zs)
    return lambda x, z: (MARGIN + (x - x0) * px_per_m, MARGIN + (z - z0) * px_per_m)


def _size(data, px_per_m):
    xs = [p[0] for p in data["brink"]]
    zs = [p[1] for p in data["brink"]]
    return (int(round((max(xs) - min(xs)) * px_per_m)) + 2 * MARGIN,
            int(round((max(zs) - min(zs)) * px_per_m)) + 2 * MARGIN)


def _fade(colour, k, toward=PAPER):
    return tuple(int(c * (1 - k) + t * k) for c, t in zip(colour, toward))


def _poly(draw, to_px, polygon, fill=None, outline=None, width=1):
    draw.polygon([to_px(*p) for p in polygon], fill=fill, outline=outline, width=width)


def _grid(draw, data, to_px, colour, hundred=None):
    """Lines every 10 m in `colour`, every 100 m in `hundred` (ink)."""
    HUNDRED = hundred or _fade(INK, 0.55)
    xs = [p[0] for p in data["brink"]]
    zs = [p[1] for p in data["brink"]]
    x0, x1, z0, z1 = min(xs), max(xs), min(zs), max(zs)
    k = 0

    while x0 + k * 10 <= x1 + 1e-6:
        x = x0 + k * 10
        draw.line([to_px(x, z0), to_px(x, z1)], fill=colour if k % 10 else HUNDRED, width=1)
        k += 1

    k = 0

    while z0 + k * 10 <= z1 + 1e-6:
        z = z0 + k * 10
        draw.line([to_px(x0, z), to_px(x1, z)], fill=colour if k % 10 else HUNDRED, width=1)
        k += 1


def _furniture(draw, data, to_px, px_per_m, ink):
    """The scale bar (100 m) and a north mark."""
    x = MARGIN
    y = _size(data, px_per_m)[1] - MARGIN // 2
    draw.line([(x, y), (x + 100 * px_per_m, y)], fill=ink, width=3)
    draw.text((x + 100 * px_per_m + 6, y - 6), "100 m", fill=ink)
    draw.text((_size(data, px_per_m)[0] - MARGIN, 8), "N ^", fill=ink)


def _labels(draw, data, to_px, ink, which=("ground", "plots", "spaces")):
    for key in which:
        for e in data[key]:
            if key == "plots" and e["family"] in ("house", "stall"):
                continue

            cx, cz = plan.centroid(e["polygon"])
            px, py = to_px(cx, cz)
            draw.text((px + 3, py + 3), e["name"], fill=ink)


def _street(draw, data, to_px, faded=0.0):
    for g in data["ground"]:
        _poly(draw, to_px, g["polygon"], fill=_fade(GROUND_COLOURS[g["kind"]], faded))

    for p in data["plots"]:
        _poly(draw, to_px, p["polygon"], fill=_fade(FAMILY_COLOURS.get(p["family"], OTHER_FAMILY), faded),
              outline=_fade(INK, max(faded, 0.5)))


def _routes(draw, data, to_px, kinds, width=3):
    for r in data["routes"]:
        if r["kind"] in kinds:
            draw.line([to_px(p[0], p[2]) for p in r["points"]], fill=ROUTE_COLOURS[r["kind"]], width=width)


def _sheet(data, sheet, px_per_m):
    to_px = projection(data, px_per_m)
    image = Image.new("RGB", _size(data, px_per_m), NIGHT if sheet == "events" else PAPER)
    draw = ImageDraw.Draw(image)
    ink = (220, 220, 220) if sheet == "events" else INK

    if sheet == "events":
        _event_fields(image, data, to_px, px_per_m)
        draw = ImageDraw.Draw(image)
        _grid(draw, data, to_px, (40, 40, 48), (90, 90, 104))

        for p in data["plots"]:
            _poly(draw, to_px, p["polygon"], outline=(200, 200, 200))
    else:
        _grid(draw, data, to_px, _fade(INK, 0.85))
        _street(draw, data, to_px, faded={"street": 0.0, "all": 0.0}.get(sheet, 0.7))

    if sheet in ("street", "all"):
        if data["tram"]:
            draw.line([to_px(*p) for p in data["tram"] + data["tram"][:1]], fill=(150, 40, 40), width=2)

        for m in data["landmarks"]:
            px, py = to_px(m["at"][0], m["at"][-1])
            draw.ellipse([px - 4, py - 4, px + 4, py + 4], fill=(30, 30, 160))

    if sheet in ("roofs", "all"):
        for p in data["plots"]:
            if p["roof"]:
                shade = max(0, min(255, int(255 - plan.top(p) * 3)))
                _poly(draw, to_px, p["polygon"], fill=None if sheet == "all" else (shade, shade, 255 - shade // 3),
                      outline=INK)

        _routes(draw, data, to_px, ("roof_link", "climb"))

    if sheet in ("underground", "all"):
        for s in data["spaces"]:
            depth = max(0, min(255, int(-s["floor"] * 12)))
            _poly(draw, to_px, s["polygon"], fill=None if sheet == "all" else (60 + depth // 2, 60, 120 + depth // 2),
                  outline=(120, 40, 160), width=2)

        for g in data["ground"]:
            if g["kind"] == "well":
                _poly(draw, to_px, g["polygon"], fill=GROUND_COLOURS["well"])

        _routes(draw, data, to_px, ("stair", "tunnel"))

    if sheet in ("canal", "all"):
        for g in data["ground"]:
            if g["kind"] in ("canal", "landing"):
                _poly(draw, to_px, g["polygon"], fill=GROUND_COLOURS[g["kind"]], outline=INK)

        _routes(draw, data, to_px, ("bridge",), width=5)

    if len(data["brink"]) >= 3:
        _poly(draw, to_px, data["brink"], outline=ink, width=3)

    _labels(draw, data, to_px, ink, LABELS[sheet])
    _furniture(draw, data, to_px, px_per_m, ink)
    return image


def _event_fields(image, data, to_px, px_per_m):
    xs = [p[0] for p in data["brink"]]
    zs = [p[1] for p in data["brink"]]
    draw = ImageDraw.Draw(image)
    step = EVENT_STEP
    x = min(xs)

    while x < max(xs):
        z = min(zs)

        while z < max(zs):
            cx, cz = x + step / 2, z + step / 2
            colour = [NIGHT[i] for i in range(3)]

            for kind, rgb in EVENT_COLOURS.items():
                f = plan.field(data, kind, cx, cz)

                for i in range(3):
                    colour[i] += rgb[i] * f

            draw.rectangle([to_px(x, z), to_px(x + step, z + step)], fill=tuple(min(255, int(c)) for c in colour))
            z += step

        x += step


def draw(data, out_dir, px_per_m=2.0):
    """Every sheet written to out_dir as plan_<sheet>.png; their paths."""
    out_dir = Path(out_dir)
    out_dir.mkdir(parents=True, exist_ok=True)
    paths = []

    for sheet in SHEETS:
        path = out_dir / ("plan_%s.png" % sheet)
        _sheet(data, sheet, px_per_m).save(path)
        paths.append(path)

    return paths


if __name__ == "__main__":
    print("\n".join(str(p) for p in draw(json.loads(Path(sys.argv[1]).read_text()), sys.argv[2])))
