"""What lies on the Metro Underground's floor (docs/superpowers/refs/underground/recipe.md):
litter from customers and commuters, a vendor's stock, a cable run, a child's
top, marigold heads for a trail. Each piece its own object at the origin,
resting on the floor; the bay (maps/underground_lab.gd) stages them as scenes.

    Blender -b --factory-startup --python tools/eclipse/underground_ground.py
"""

import math
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import common  # noqa: E402
import underground_shapes  # noqa: E402
from underground_shapes import box, pipe, slab, smooth_object, turned  # noqa: E402

NAME = "underground_ground"
ATLAS = 2048
SLOTS = ["paper_kraft", "clay", "newsprint", "burlap", "wood", "corn", "rubber", "paint_red", "marigold", "steel"]

rng = random.Random(1924)


def grounded(name, build, squash=(1.0, 1.0, 1.0)):
    """A piece built, squashed (a sack's slump), set down so its lowest point is on the floor."""
    o = smooth_object(name, build)
    low = min(v.co.z for v in o.data.vertices)

    for v in o.data.vertices:
        v.co.x *= squash[0]
        v.co.y *= squash[1]
        v.co.z = (v.co.z - low) * squash[2]

    o.data.update()
    return o


# --- litter -------------------------------------------------------------------------------------

def cone_crushed(m):
    """A paper cone of herbs, emptied, lying on its side and trodden half flat
    (the squash in PIECES), its mouth still open wide."""
    turned(m, [(0.026, 0.0), (0.036, 0.05), (0.052, 0.11), (0.066, 0.162), (0.072, 0.18)], 8, "paper_kraft",
           jitter=0.1, lean=math.pi / 2, towards=0.4)


def jarrito(m):
    """A clay jarrito of atole, dropped on its side when its drinker ran for a train."""
    body = [(0.03, 0.0), (0.043, 0.022), (0.048, 0.047), (0.038, 0.074), (0.044, 0.094)]
    turned(m, body, 9, "clay", jitter=0.04)
    handle = [(0.034, 0.0, 0.022), (0.072, 0.0, 0.05), (0.034, 0.0, 0.08)]
    pipe(m, handle, 0.015, 6, "clay")


def _crumple(x, y):
    return 0.012 * (math.sin(x * 23.0 + 1.3) * math.sin(y * 17.0) + 1.0) + 0.006 * math.sin(x * 51.0 + y * 37.0)


def news_spread(m):
    """A newspaper dropped open, crumpled by feet."""
    cols, rows, w, d = 7, 6, 0.56, 0.4
    grid = [[(-w / 2 + w * j / (cols - 1), -d / 2 + d * i / (rows - 1), 0.012 + _crumple(j, i)) for j in range(cols)]
            for i in range(rows)]
    slab(m, grid, (0.0, 0.0, -0.012), "newsprint")


def news_folded(m):
    """A newspaper folded small, its upper fold lifted."""
    box(m, (-0.15, -0.19, 0.0), (0.15, 0.19, 0.035), "newsprint", r=0.0)
    box(m, (-0.13, -0.17, 0.035), (0.13, 0.02, 0.07), "newsprint", r=0.0)


# --- her stock ----------------------------------------------------------------------------------

SACK = [(0.14, 0.0), (0.22, 0.06), (0.24, 0.25), (0.2, 0.42), (0.1, 0.5), (0.065, 0.55), (0.09, 0.62)]


def sack_slumped(m):
    """A burlap sack of beans slumped against a wall, tied at the neck."""
    turned(m, SACK, 10, "burlap", jitter=0.09)
    ring = [(0.085 * math.cos(a), 0.085 * math.sin(a), 0.54) for a in (2 * math.pi * n / 8 for n in range(8))]
    pipe(m, ring, 0.022, 8, "paper_kraft", closed=True)


def sack_lying(m):
    """A sack laid down on its side, its neck tied and folded short."""
    turned(m, SACK[:5] + [(0.07, 0.53)], 10, "burlap", jitter=0.09)
    ring = [(0.075 * math.cos(a), 0.075 * math.sin(a), 0.5) for a in (2 * math.pi * n / 8 for n in range(8))]
    pipe(m, ring, 0.022, 8, "paper_kraft", closed=True)
    _lay_down(m)


def _lay_down(m):
    """Everything built so far on this piece tipped onto its side (about X)."""
    for v in m.bm.verts:
        v.co.y, v.co.z = -v.co.z, v.co.y


def _crate(m, w=0.5, d=0.35, h=0.3):
    """A slatted crate, open at the top."""
    post = 0.05
    for sx in (-1, 1):
        for sy in (-1, 1):
            x, y = sx * (w / 2 - post / 2), sy * (d / 2 - post / 2)
            box(m, (x - post / 2, y - post / 2, 0.0), (x + post / 2, y + post / 2, h), "wood", r=0.019)

    box(m, (-w / 2 + post, -d / 2 + post, 0.0), (w / 2 - post, d / 2 - post, 0.02), "wood", r=0.0)

    for k in range(3):
        z0 = 0.03 + k * 0.09
        for sy in (-1, 1):
            y = sy * (d / 2 - 0.01)
            box(m, (-w / 2 + post, y - 0.01, z0), (w / 2 - post, y + 0.01, z0 + 0.06), "wood", r=0.0)
        for sx in (-1, 1):
            x = sx * (w / 2 - 0.01)
            box(m, (x - 0.01, -d / 2 + post, z0), (x + 0.01, d / 2 - post, z0 + 0.06), "wood", r=0.0)


def crate(m):
    _crate(m)


def crate_corn(m):
    """A crate heaped with dried corn cobs."""
    _crate(m)
    for k in range(11):
        a = rng.uniform(0, 2 * math.pi)
        x, y = rng.uniform(-0.12, 0.12), rng.uniform(-0.06, 0.06)
        turned(m, [(0.026, -0.085), (0.036, -0.045), (0.034, 0.04), (0.022, 0.085)], 8, "corn",
               at=(x, y, 0.25 + 0.025 * (k % 3)), jitter=0.08, lean=math.pi / 2 - rng.uniform(0.0, 0.35), towards=a)


# --- a cable run --------------------------------------------------------------------------------

# Where the cable run stands, in the stall's frame (tools/eclipse/stall.py: the
# junction box on the back right post at x 1.5, y 2.17, its bottom at 2.66; the
# post's cast shoe below it, 17 cm across); the bay places the piece here.
CABLE_AT = (1.55, 2.2)
CABLE_R = 0.016
# The riser's two cables, side by side in the gap between the post and the box's
# side; the floor run's two, nearer the wall; how far the run goes.
RISER_Y = (2.135, 2.17)
RUN_Y = (2.25, 2.285)
RUN_X = (1.8, 5.8)


def cable_run(m):
    """Two cables dropped from the stall's junction box beside its post, kicked
    out over the post's cast shoe, then snaking 4 m along the wall's foot,
    held down by wooden cleats nailed to the floor: one ends taped off where the
    next stall will stand, the other's spare is coiled on the floor beyond."""
    ox, oy = CABLE_AT
    r = CABLE_R

    for k in range(2):
        rx, ry, wy = 1.5525, RISER_Y[k], RUN_Y[k]
        riser = [(rx, ry, 2.70), (rx, ry, 0.4), (rx + 0.03, ry + 0.2 * (wy - ry), 0.26),
                 (rx + 0.09, ry + 0.6 * (wy - ry), 0.13), (rx + 0.16, wy, 0.05), (RUN_X[0] - 0.02, wy, r)]
        end = RUN_X[1] - (0.2 if k == 0 else 0.0)
        steps = 24
        run = [(RUN_X[0] + (end - RUN_X[0]) * i / steps,
                wy + 0.02 * math.sin(i * 0.6 + 1.7 * k) * min(1.0, i / 3), r) for i in range(steps + 1)]
        points = riser + run

        if k == 1:
            # The spare, dropped in loose loops: a spiral inward from where the run ends,
            # long one way and kinked where it was bent, never a neat round.
            cx, cy, turns = RUN_X[1] + 0.15, 2.1, 1.7
            start = math.atan2(wy - cy, RUN_X[1] - cx)
            outer = math.hypot(RUN_X[1] - cx, wy - cy)
            for i in range(1, 31):
                t = i / 30
                a = start - t * turns * 2 * math.pi
                rr = (outer - t * (outer - 0.1)) * (1.0 + 0.08 * math.sin(3.0 * a + 0.8))
                points.append((cx + 1.2 * rr * math.cos(a), cy + rr * math.sin(a), r))

        pipe(m, [(x - ox, y - oy, z) for x, y, z in points], r, 8, "rubber")

        if k == 0:
            # Its end bound in black tape, waiting for the next stall.
            x, y, _ = run[-1]
            turned(m, [(0.022, 0.0), (0.024, 0.03), (0.02, 0.06)], 8, "rubber", at=(x - ox - 0.04, y - oy, 0.024),
                   lean=math.pi / 2, towards=-math.pi / 2)

    for k in range(5):
        x = RUN_X[0] + 0.4 + k * 0.8 - ox
        box(m, (x - 0.03, RUN_Y[0] - 0.045 - oy, 0.0), (x + 0.03, RUN_Y[1] + 0.045 - oy, 0.042), "wood", r=0.0)


# --- a child's top, a marigold head ---------------------------------------------------------------

def trompo(m):
    """A child's spinning top, red, its string trailing."""
    turned(m, [(0.016, 0.0), (0.03, 0.03), (0.045, 0.06), (0.04, 0.075), (0.02, 0.088), (0.018, 0.115)], 7,
           "paint_red", lean=math.pi / 2 - 0.25, towards=0.6)
    points = [(0.06 + 0.03 * i, 0.04 * math.sin(i * 0.9), 0.013) for i in range(12)]
    pipe(m, points, 0.013, 6, "paper_kraft")


def marigold_head(m):
    turned(m, [(0.018, 0.0), (0.042, 0.014), (0.038, 0.026), (0.046, 0.038), (0.041, 0.05), (0.04, 0.062),
               (0.02, 0.078)], 8, "marigold", jitter=0.08, lean=1.2, towards=0.3)


PIECES = [(cone_crushed, (1.0, 1.0, 0.5)), (jarrito, None), (news_spread, None), (news_folded, None),
          (sack_slumped, (1.0, 0.75, 1.0)), (sack_lying, (1.0, 1.0, 0.72)), (crate, None), (crate_corn, None),
          (cable_run, None), (trompo, None), (marigold_head, None)]


def build():
    common.reset()
    underground_shapes.rng = rng
    rng.seed(1924)

    for f, squash in PIECES:
        grounded(f.__name__, f, squash or (1.0, 1.0, 1.0))


def main():
    build()
    common.export_piece(NAME, ATLAS, SLOTS, out=common.ROOT / "assets" / "eclipse" / "kit", sets_each=True, budget=2400)


if __name__ == "__main__":
    main()
