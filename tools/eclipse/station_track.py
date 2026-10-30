"""The Zócalo station's track, laid for the MP-68 (docs/superpowers/specs/2026-10-27-metro-station-design.md; plan
docs/superpowers/plans/2026-10-30-metro-station.md, Task 5): the rubber-tyred cars run on two concrete pads, the steel
safety rails between them on their sleepers, a guide bar either side (bolted to the pit's face on the platform's side,
on a low kerb under a timber guard board between the tracks, on the mouths' walls in the dark), stopping in flares
where the staff cross to the track steps; the drain down the middle of the bed under its iron grating.

Maps/metro_station_dressing.gd lays them out; maps/metro_station.gd cuts the drain's trench and makes the pads, the
kerbs and the grating solid.

Frames (Blender: x along, y across, z up; Godot turns -y into +z):
- track_bed: MODULE along +x from 0, the track's centre at y = 0, the pads' tops at z = 0 (the set's PAD_TOP), the bed's
  top BED under them;
- guide_bar: a metre along +x, its face toward the car at y = 0, the bar and its brackets behind it (+y), its heights
  over the pads' tops;
- guide_flare, guide_flare_l: a bar's end FLARE[0] long turning FLARE[1] away from the car at its far end (+x; the _l's
  at its near end, x = 0), on a post from the bed;
- guide_kerb: a metre of the kerb the bar is bolted to between the tracks, behind its face (y >= 0), the guard board
  over the bar;
- drain: DRAIN_LONG along +x from 0, centred across y, its grating's top at z = 0 (the bed's top), its channel DRAIN[1]
  deep under it; drain_end: its stop, STOP along +x from 0, its top at z = 0.

    Blender -b --factory-startup --python tools/eclipse/station_track.py
"""

import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import common  # noqa: E402
from underground_shapes import box, pipe, smooth_object  # noqa: E402

NAME = "station_track"
ATLAS = 4096
SLOTS = ["cement", "cement_cast", "stone", "rubber", "steel", "iron", "wood", "soot_black"]

# A module of track along x (m).
MODULE = 10.0
# The running pads: centred this far either side of the track's centre, this wide (m).
PAD_FROM = 1.0
PAD_WIDE = 0.3
# The band down a pad's middle the tyres wear black (m).
WORN = 0.2
# The bed's top under the pads' tops (the bed slabs', m).
BED = -0.19
# The safety rails' gauge (standard, between the heads' middles) and their heads' tops under the pads' (m).
GAUGE = 1.435
RAIL_TOP = -0.03
# The sleepers under the rails: one a metre, this long across and wide along (m).
SLEEPER = (1.56, 0.2)
# The guide bar: its bottom, middle and top over the pads' tops, its thickness; its brackets reach this far back (m).
BAR = (0.05, 0.125, 0.2)
BAR_THICK = 0.035
BRACKET = 0.15
# A flare: its length along, and how far it turns away from the car (m).
FLARE = (0.4, 0.08)
# The kerb between the tracks: its face behind the bar's, its back; its top, the guard board's top (m).
KERB = (0.05, 0.3, 0.26, 0.3)
# The drain: its width, its depth; a piece's length; its grating's bars along it (m).
DRAIN = (0.4, 0.15)
DRAIN_LONG = 1.2
GRATING = 0.1
# The drain's stop at either end (m along).
STOP = 0.1


def _extrude(m, profile, x0, x1, slot, sides=None):
    """A profile (y, z, round) stood along x from x0 to x1: its sides (each edge's own slot in `sides`, if given) and its
    two ends."""
    m.shell()
    n = len(profile)
    for i in range(n):
        (ay, az), (by, bz) = profile[i], profile[(i + 1) % n]
        m.face([(x0, ay, az), (x1, ay, az), (x1, by, bz), (x0, by, bz)], sides[i] if sides else slot)
    m.face([(x0, y, z) for y, z in profile], slot)
    m.face([(x1, y, z) for y, z in reversed(profile)], slot)


def _rail(m, y, x0, x1):
    """A flat-bottomed rail along x (iron: the tyres ride the pads, the rails only catch a car that loses one), its head's middle at `y`, its foot on the sleepers."""
    foot = RAIL_TOP - 0.1
    half = [(0.06, foot), (0.06, foot + 0.012), (0.008, foot + 0.02), (0.008, RAIL_TOP - 0.025),
            (0.03, RAIL_TOP - 0.02), (0.03, RAIL_TOP)]
    profile = [(y + dy, z) for dy, z in half] + [(y - dy, z) for dy, z in reversed(half)]
    _extrude(m, profile, x0, x1, "iron")


def track_bed(m):
    """A module of one track: its two concrete pads, the sleepers between them and the two safety rails on them."""
    for side in (-1, 1):
        # (Cast in three strips: its two edges, and between them the band the tyres run, worn black a hair under them.)
        y0, y1 = side * PAD_FROM - PAD_WIDE / 2, side * PAD_FROM + PAD_WIDE / 2
        w0, w1 = side * PAD_FROM - WORN / 2, side * PAD_FROM + WORN / 2
        box(m, (0.0, y0, BED - 0.02), (MODULE, w0, 0.0), "cement", r=0.0)
        box(m, (0.0, w0, BED - 0.02), (MODULE, w1, -0.001), "rubber", r=0.0)
        box(m, (0.0, w1, BED - 0.02), (MODULE, y1, 0.0), "cement", r=0.0)
    for k in range(int(MODULE)):
        x = k + 0.5
        box(m, (x - SLEEPER[1] / 2, -SLEEPER[0] / 2, BED - 0.01), (x + SLEEPER[1] / 2, SLEEPER[0] / 2, RAIL_TOP - 0.1),
            "stone", r=0.01)
    for side in (-1, 1):
        _rail(m, side * GAUGE / 2, 0.0, MODULE)


def _bracket(m, x, back):
    """A bracket bolting the bar to what stands behind it, `back` behind the bar's face."""
    box(m, (x - 0.04, BAR_THICK, BAR[1] - 0.035), (x + 0.04, back, BAR[1] + 0.035), "iron", r=0.008)


def guide_bar(m):
    """A metre of guide bar: the steel bar on edge, its bracket behind it."""
    box(m, (0.0, 0.0, BAR[0]), (1.0, BAR_THICK, BAR[2]), "steel", r=0.004)
    _bracket(m, 0.5, BRACKET)


def _flare(m, bent_at_far):
    """A bar's end turning away from the car toward one end, on an iron post from the bed."""
    length, away = FLARE
    m.shell()
    # (Its face from the straight end to the bent one, its back a bar's thickness behind it along its normal.)
    a = (0.0, 0.0) if bent_at_far else (0.0, away)
    b = (length, away) if bent_at_far else (length, 0.0)
    dx, dy = b[0] - a[0], b[1] - a[1]
    run = math.hypot(dx, dy)
    nx, ny = -dy / run * BAR_THICK, dx / run * BAR_THICK
    face = [a, b, (b[0] + nx, b[1] + ny), (a[0] + nx, a[1] + ny)]
    z0, z1 = BAR[0], BAR[2]
    for i in range(4):
        (px, py), (qx, qy) = face[i], face[(i + 1) % 4]
        m.face([(px, py, z0), (qx, qy, z0), (qx, qy, z1), (px, py, z1)], "steel")
    m.face([(x, y, z0) for x, y in reversed(face)], "steel")
    m.face([(x, y, z1) for x, y in face], "steel")
    # (Its post behind its bent half, from the bed up to the bar's middle, a short arm to it.)
    t = 0.75 if bent_at_far else 0.25
    px = a[0] + dx * t
    py = a[1] + dy * t + BAR_THICK + 0.035
    pipe(m, [(px, py, BED - 0.01), (px, py, BAR[1] + 0.02)], 0.02, 6, "iron")
    box(m, (px - 0.03, py - 0.035, BAR[1] - 0.025), (px + 0.03, py, BAR[1] + 0.025), "iron", r=0.0)


def guide_flare(m):
    _flare(m, True)


def guide_flare_l(m):
    _flare(m, False)


def guide_kerb(m):
    """A metre of the kerb between the tracks the bar is bolted to, and the timber guard board over the bar."""
    face, back, top, board = KERB
    box(m, (0.0, face, BED - 0.01), (1.0, back, top), "cement_cast", r=0.01)
    box(m, (0.0, 0.0, top), (1.0, back + 0.02, board), "wood", r=0.006)


def drain(m):
    """A length of the drain down the bed's middle: its channel lined, dark at its floor, under an iron grating."""
    wide, deep = DRAIN
    half = wide / 2
    wall = 0.02
    frame = 0.03
    bar = 0.03
    # (Its channel one cast U, its floor dark with the wet.)
    floor = -deep + 0.02
    u = [(-half, -deep), (half, -deep), (half, -0.035), (half - wall, -0.035), (half - wall, floor), (-half + wall, floor),
         (-half + wall, -0.035), (-half, -0.035)]
    _extrude(m, u, 0.0, DRAIN_LONG, "cement_cast", sides=["cement_cast"] * 4 + ["soot_black"] + ["cement_cast"] * 3)
    for side in (-1, 1):
        f0, f1 = sorted((side * half, side * (half - frame)))
        box(m, (0.0, f0, -0.035), (DRAIN_LONG, f1, 0.0), "iron", r=0.0)
    count = int(round(DRAIN_LONG / GRATING))
    for k in range(count):
        x = (k + 0.5) * DRAIN_LONG / count
        box(m, (x - 0.01, -half + frame, -bar), (x + 0.01, half - frame, 0.0), "iron", r=0.0)


def drain_end(m):
    """The drain's cast stop where its trench meets the walkers' tunnels: STOP long, the channel filled, its top the bed's."""
    wide, deep = DRAIN
    box(m, (0.0, -wide / 2, -deep), (STOP, wide / 2, 0.0), "cement_cast", r=0.0)


PIECES = [("track_bed", track_bed), ("guide_bar", guide_bar), ("guide_flare", guide_flare),
          ("guide_flare_l", guide_flare_l), ("guide_kerb", guide_kerb), ("drain", drain),
          ("drain_end", drain_end)]

BUDGET = {n: 3000 for n, _ in PIECES}
SLIVER = {n: 0.004 for n, _ in PIECES}


def build():
    common.reset()
    for name, f in PIECES:
        smooth_object(name, f)


def main():
    build()
    common.export_piece(NAME, ATLAS, SLOTS, out=common.ROOT / "assets" / "eclipse" / "kit", sets_each=True,
                        budget=max(BUDGET.values()), sliver=min(SLIVER.values()))


if __name__ == "__main__":
    main()
