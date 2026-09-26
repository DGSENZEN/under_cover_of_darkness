"""Draws the old and new movement feel side by side from the traces
tests/visual/stage_motion.tscn writes (motion_old.csv, motion_new.csv).

    python3 tools/plot_motion.py <folder>

Writes <folder>/motion_compare.png: one row per measure (speed, the view's
height, forward and sideways offset, its pitch and roll, the FOV, the hands'
height), the old feel in grey and the new in amber, footsteps as ticks
under each row, and the phases of the script across the top. Needs Pillow.
"""

import csv
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

WIDTH = 1800
LEFT = 190
RIGHT = 30
TOP = 64
ROW = 150
GAP = 26
BACKGROUND = (21, 21, 26)
GRID = (52, 52, 60)
TEXT = (226, 219, 204)
DIM = (150, 144, 132)
OLD = (140, 140, 146)
NEW = (240, 176, 64)

# (label, unit, how to read it from a row)
MEASURES = [
    ("speed", "m/s", lambda r: float(r["speed"])),
    ("view height", "cm", lambda r: float(r["view_y"]) * 100.0),
    ("view forward", "cm", lambda r: -float(r["view_z"]) * 100.0),
    ("view sideways", "cm", lambda r: float(r["view_x"]) * 100.0),
    ("view pitch", "deg", lambda r: float(r["pitch_deg"])),
    ("view roll", "deg", lambda r: float(r["roll_deg"])),
    ("field of view", "deg", lambda r: float(r["fov"])),
    ("hands height", "cm", lambda r: float(r["hand_y"]) * 100.0),
]


def read(path):
    with open(path, newline="") as handle:
        return list(csv.DictReader(handle))


def font(size):
    try:
        return ImageFont.load_default(size=size)
    except TypeError:
        return ImageFont.load_default()


def main():
    if len(sys.argv) < 2:
        print(__doc__)
        return 2

    folder = Path(sys.argv[1])
    old = read(folder / "motion_old.csv")
    new = read(folder / "motion_new.csv")
    span = max(float(old[-1]["t"]), float(new[-1]["t"]))
    height = TOP + len(MEASURES) * (ROW + GAP) + 20
    image = Image.new("RGB", (WIDTH, height), BACKGROUND)
    draw = ImageDraw.Draw(image)
    small = font(14)
    label_font = font(16)
    title = font(20)

    def x_at(t):
        return LEFT + (WIDTH - LEFT - RIGHT) * t / span

    draw.text((LEFT, 12), "Movement feel: old (grey) and new (amber), same inputs", fill=TEXT, font=title)

    # The phases, across the top and down every row.
    start = 0.0
    phase = new[0]["phase"]

    for r in new + [{"t": str(span + 1.0), "phase": ""}]:
        if r["phase"] != phase:
            end = float(r["t"])
            draw.text((x_at(start) + 4, TOP - 24), phase, fill=DIM, font=small)
            draw.line([(x_at(end), TOP - 6), (x_at(end), height - 20)], fill=GRID, width=1)
            start, phase = end, r["phase"]

    for n, (label, unit, value) in enumerate(MEASURES):
        top = TOP + n * (ROW + GAP)
        bottom = top + ROW
        olds = [value(r) for r in old]
        news = [value(r) for r in new]
        low = min(olds + news)
        high = max(olds + news)

        if high - low < 1e-6:
            low -= 1.0
            high += 1.0

        pad = (high - low) * 0.08
        low -= pad
        high += pad

        def y_at(v):
            return bottom - (bottom - top) * (v - low) / (high - low)

        draw.rectangle([LEFT, top, WIDTH - RIGHT, bottom], outline=GRID)
        draw.text((12, top + 6), label, fill=TEXT, font=label_font)
        draw.text((12, top + 28), unit, fill=DIM, font=small)
        draw.text((LEFT - 70, top), "%.2f" % high, fill=DIM, font=small)
        draw.text((LEFT - 70, bottom - 16), "%.2f" % low, fill=DIM, font=small)

        if low < 0.0 < high:
            draw.line([(LEFT, y_at(0.0)), (WIDTH - RIGHT, y_at(0.0))], fill=GRID, width=1)

        for rows, values, colour, lift in ((old, olds, OLD, 0), (new, news, NEW, 7)):
            points = [(x_at(float(r["t"])), y_at(v)) for r, v in zip(rows, values)]
            draw.line(points, fill=colour, width=2)

            # Footsteps: short ticks along the bottom of the row.
            for r in rows:
                if r["step"] == "1":
                    x = x_at(float(r["t"]))
                    draw.line([(x, bottom - 2 - lift), (x, bottom - 6 - lift)], fill=colour, width=1)

    out = folder / "motion_compare.png"
    image.save(out)
    print("wrote", out)
    return 0


if __name__ == "__main__":
    sys.exit(main())
