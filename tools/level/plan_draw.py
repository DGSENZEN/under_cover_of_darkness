"""A district plan drawn as sheets for the user's approval (the Zócalo spec,
section 2): street, roofs, underground, canal, events, and all of them. North
up, a 10 m grid (every 100 m darker), a scale bar, developer labels (element
names only).

A map whose spaces stack (the Metro Underground) is also drawn one sheet per
depth band, plan_underground_<label>.png: only the spaces whose floor lies in
the band, and the routes and landmarks with an end or a foot in it, each
space named with its floor; the other bands' spaces faint behind. The bands
come from draw(bands=) or the plan's own "bands". A plan with no brink is
drawn over the bounds of what it holds.

    python3 tools/level/plan_draw.py <plan.json> <out dir> [px per m, 2]
"""

import json
import math
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
# A space's colour on the band sheets by its layer (Line 2's blue for the
# station, ochre for the market, temple red for the old passages).
LAYER_COLOURS = {1: (60, 110, 200), 2: (205, 150, 60), 3: (170, 70, 70), None: (120, 120, 120)}
LANDMARK_COLOURS = {"arrival": (20, 170, 60), "exit_zocalo": (20, 170, 60), "exit_cathedral": (20, 170, 60),
                    "sign": (40, 70, 200), "character_place": (200, 40, 160), "scene": (230, 110, 20),
                    "puesto": (150, 110, 40)}
# Without a brink, the sheet reaches this far past what the plan holds (m),
# its edges on the 10 m grid.
PAD = 20.0


def extent(data):
    """(x0, z0, x1, z1): the brink's bounds, or with no brink the bounds of
    everything in the plan, PAD out and on the 10 m grid."""
    if len(data["brink"]) >= 3:
        xs = [p[0] for p in data["brink"]]
        zs = [p[1] for p in data["brink"]]
        return min(xs), min(zs), max(xs), max(zs)

    points = [p for key in ("ground", "plots", "spaces") for e in data[key] for p in e["polygon"]]
    points += [(p[0], p[2]) for r in data["routes"] for p in r["points"]]
    points += [(m["at"][0], m["at"][-1]) for m in data["landmarks"]]
    xs = [p[0] for p in points] or [0.0]
    zs = [p[1] for p in points] or [0.0]
    down = lambda v: math.floor((v - PAD) / 10.0) * 10.0
    up = lambda v: math.ceil((v + PAD) / 10.0) * 10.0
    return down(min(xs)), down(min(zs)), up(max(xs)), up(max(zs))


def projection(data, px_per_m):
    """(x, z) to pixels, north up: x grows right, z (south) grows down."""
    x0, z0, _, _ = extent(data)
    return lambda x, z: (MARGIN + (x - x0) * px_per_m, MARGIN + (z - z0) * px_per_m)


def _size(data, px_per_m):
    x0, z0, x1, z1 = extent(data)
    return (int(round((x1 - x0) * px_per_m)) + 2 * MARGIN, int(round((z1 - z0) * px_per_m)) + 2 * MARGIN)


def _fade(colour, k, toward=PAPER):
    return tuple(int(c * (1 - k) + t * k) for c, t in zip(colour, toward))


def _poly(draw, to_px, polygon, fill=None, outline=None, width=1):
    draw.polygon([to_px(*p) for p in polygon], fill=fill, outline=outline, width=width)


def _grid(draw, data, to_px, colour, hundred=None):
    """Lines every 10 m in `colour`, every 100 m in `hundred` (ink)."""
    HUNDRED = hundred or _fade(INK, 0.55)
    x0, z0, x1, z1 = extent(data)
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

        # The causeway's band of darker stone.
        if data.get("causeway"):
            draw.line([to_px(*p) for p in data["causeway"]], fill=(60, 50, 70), width=4)

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
    bx0, bz0, bx1, bz1 = extent(data)
    draw = ImageDraw.Draw(image)
    step = EVENT_STEP
    x = bx0

    while x < bx1:
        z = bz0

        while z < bz1:
            cx, cz = x + step / 2, z + step / 2
            colour = [NIGHT[i] for i in range(3)]

            for kind, rgb in EVENT_COLOURS.items():
                f = plan.field(data, kind, cx, cz)

                for i in range(3):
                    colour[i] += rgb[i] * f

            draw.rectangle([to_px(x, z), to_px(x + step, z + step)], fill=tuple(min(255, int(c)) for c in colour))
            z += step

        x += step


def _in_band(y, band):
    return band[0] < y <= band[1]


def _band_sheet(data, band, px_per_m):
    """The spaces whose floor lies in the band, coloured by layer and named
    with their floor; the routes with an end in it; its landmarks; every
    other space faint behind."""
    to_px = projection(data, px_per_m)
    image = Image.new("RGB", _size(data, px_per_m), PAPER)
    draw = ImageDraw.Draw(image)
    _grid(draw, data, to_px, _fade(INK, 0.85))
    mine = [s for s in data["spaces"] if _in_band(s["floor"], band)]

    for s in data["spaces"]:
        if s not in mine:
            _poly(draw, to_px, s["polygon"], outline=_fade(INK, 0.75))

    for s in mine:
        colour = LAYER_COLOURS.get(s.get("layer"), LAYER_COLOURS[None])
        _poly(draw, to_px, s["polygon"], fill=_fade(colour, 0.45), outline=colour, width=2)

    for r in data["routes"]:
        if any(_in_band(p[1], band) for p in (r["points"][0], r["points"][-1])):
            draw.line([to_px(p[0], p[2]) for p in r["points"]], fill=ROUTE_COLOURS[r["kind"]], width=3)

    for m in data["landmarks"]:
        if len(m["at"]) == 3 and _in_band(m["at"][1], band):
            px, py = to_px(m["at"][0], m["at"][2])
            colour = LANDMARK_COLOURS.get(m["kind"], INK)
            r = 4 if m["kind"] in ("arrival", "exit_zocalo", "exit_cathedral") else 2
            draw.ellipse([px - r, py - r, px + r, py + r], fill=colour)

    for s in mine:
        cx, cz = plan.centroid(s["polygon"])
        px, py = to_px(cx, cz)
        draw.text((px + 3, py + 3), "%s %g" % (s["name"], s["floor"]), fill=INK)

    draw.text((MARGIN, 8), "%s: floors %g to %g m" % (band[2], band[0], band[1]), fill=INK)
    _legend(draw, data, px_per_m)
    _furniture(draw, data, to_px, px_per_m, INK)
    return image


def _legend(draw, data, px_per_m):
    """What the band sheets' colours mean, along the head of the sheet."""
    keys = [("station", LAYER_COLOURS[1], 6), ("market", LAYER_COLOURS[2], 6), ("old", LAYER_COLOURS[3], 6)]
    keys += [(kind.replace("_", " "), LANDMARK_COLOURS[kind], 3) for kind in
             ("arrival", "sign", "character_place", "scene", "puesto")]
    keys += [(kind, ROUTE_COLOURS[kind], 0) for kind in ("stair", "climb", "tunnel")]
    x = MARGIN + 180
    y = 14

    for label, colour, r in keys:
        if r:
            draw.ellipse([x, y - r, x + 2 * r, y + r], fill=colour)
        else:
            draw.line([(x, y), (x + 12, y)], fill=colour, width=3)

        draw.text((x + 16, y - 6), label, fill=INK)
        x += 16 + 6 * len(label) + 12


def draw(data, out_dir, px_per_m=2.0, bands=None):
    """Every sheet written to out_dir as plan_<sheet>.png, and one
    plan_underground_<label>.png per depth band (lowest, highest, label) in
    `bands` or the plan's "bands"; their paths."""
    out_dir = Path(out_dir)
    out_dir.mkdir(parents=True, exist_ok=True)
    paths = []

    # (With no brink there is no street, roof, canal or event to draw.)
    for sheet in SHEETS if len(data["brink"]) >= 3 else ("underground", "all"):
        path = out_dir / ("plan_%s.png" % sheet)
        _sheet(data, sheet, px_per_m).save(path)
        paths.append(path)

    for band in bands if bands is not None else data.get("bands", []):
        path = out_dir / ("plan_underground_%s.png" % band[2])
        _band_sheet(data, band, px_per_m).save(path)
        paths.append(path)

    return paths


if __name__ == "__main__":
    print("\n".join(str(p) for p in draw(json.loads(Path(sys.argv[1]).read_text()), sys.argv[2],
                                         float(sys.argv[3]) if len(sys.argv) > 3 else 2.0)))
