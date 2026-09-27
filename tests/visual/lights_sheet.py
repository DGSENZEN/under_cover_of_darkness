"""The lights stager's review sheet (tests/visual/stage_lights.gd).

    python3 tests/visual/lights_sheet.py <shots dir>

Reads <dir>/rows.txt (a fixture a line) and its shots, <fixture>_<lit|out>_<1|3|8>m.png,
and the wide shots bay_<1..4>.png; writes <dir>/sheet.png: the bays along the
top, then a labelled row a fixture: lit at 1, 3, 8 m, then out at 1, 3, 8 m.
"""

import sys
from pathlib import Path

from PIL import Image, ImageDraw

THUMB = (256, 144)
LABEL = 200
GAP = 4
INK = (235, 225, 205)
PAPER = (18, 16, 14)


def thumb(path):
    if not path.exists():
        return Image.new("RGB", THUMB, (90, 0, 0))

    return Image.open(path).convert("RGB").resize(THUMB, Image.NEAREST)


def main(folder):
    folder = Path(folder)
    rows = [line.strip() for line in (folder / "rows.txt").read_text().splitlines() if line.strip()]
    columns = [(state, d) for state in ("lit", "out") for d in (1, 3, 8)]
    width = LABEL + len(columns) * (THUMB[0] + GAP)
    bay_w = (width - GAP * 3) // 4
    bay_h = bay_w * 9 // 16
    top = 24 + bay_h + GAP + 20
    sheet = Image.new("RGB", (width, top + len(rows) * (THUMB[1] + GAP)), PAPER)
    draw = ImageDraw.Draw(sheet)
    draw.text((6, 6), "the bays", fill=INK)

    for i in range(4):
        path = folder / ("bay_%d.png" % (i + 1))

        if path.exists():
            sheet.paste(Image.open(path).convert("RGB").resize((bay_w, bay_h), Image.NEAREST), (i * (bay_w + GAP), 24))

    for c, (state, d) in enumerate(columns):
        draw.text((LABEL + c * (THUMB[0] + GAP) + 4, top - 16), "%s %d m" % (state, d), fill=INK)

    for r, fixture in enumerate(rows):
        y = top + r * (THUMB[1] + GAP)
        draw.text((6, y + THUMB[1] // 2 - 6), fixture, fill=INK)

        for c, (state, d) in enumerate(columns):
            sheet.paste(thumb(folder / ("%s_%s_%dm.png" % (fixture, state, d))), (LABEL + c * (THUMB[0] + GAP), y))

    sheet.save(folder / "sheet.png")
    print("sheet: %d fixtures -> %s" % (len(rows), folder / "sheet.png"))


if __name__ == "__main__":
    main(sys.argv[1])
