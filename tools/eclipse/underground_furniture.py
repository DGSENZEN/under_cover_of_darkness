"""The Metro Underground corridor's furniture (docs/superpowers/refs/underground/recipe.md):
a Metro bench, a tamale seller's cart with its steamer and her stool, a
bin in the Company's orange, a Virgin's niche built out from the wall with
its candles, and a vent grille breathing warm air. Free pieces stand on the
floor at their origin; wall pieces are built in the wall's frame (the wall
face is y = 0, the piece out into -y, the floor z = 0). The bay
(maps/underground_lab.gd) stages them, each with its cause.

    Blender -b --factory-startup --python tools/eclipse/underground_furniture.py
"""

import math
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import common  # noqa: E402
import underground_shapes  # noqa: E402
from underground_shapes import box, pipe, smooth_object, stud, turned  # noqa: E402

NAME = "underground_furniture"
ATLAS = 2048
SLOTS = ["wood", "steel", "tin", "clay", "wax", "glass", "marigold", "paint_red", "paint_blue", "paint_band",
         "metro_orange", "paper_kraft", "rubber", "sign", "print_saint", "paint_cart", "paint_trim", "soot_black", "herb",
         "newsprint"]

rng = random.Random(1931)

# The bench's seat, its slats' top (m).
BENCH_SEAT = 0.45
SLAT_T = 0.035
# The tamale cart: its steamer stands on its top board; the lid's knob is the top of all.
CART_TOP = 0.86
POT_AT = (0.15, 0.0)
POT_TOP = (POT_AT[0], POT_AT[1], CART_TOP + 0.65)
# The niche's shelf (its sill's top) on the wall.
NICHE_SILL = 1.05


def lathe_z(m, stations, sides, at=(0.0, 0.0, 0.0)):
    """A closed solid turned about the vertical through `at`: `stations` as
    [(r, z, slot)], each slot painting from its station to the next."""
    m.shell()
    ax, ay, az = at
    rings = [[(ax + r * math.cos(2 * math.pi * k / sides), ay + r * math.sin(2 * math.pi * k / sides), az + z)
              for k in range(sides)] for r, z, _ in stations]
    m.face(list(reversed(rings[0])), stations[0][2])

    for i in range(len(rings) - 1):
        a, b = rings[i], rings[i + 1]
        for k in range(sides):
            m.face([a[k], a[(k + 1) % sides], b[(k + 1) % sides], b[k]], stations[i][2])

    m.face(rings[-1], stations[-1][2])


def ring(m, centre, radius, tube, axis, slot, sides=6, steps=16):
    """A closed ring of tube about `centre`, in the plane across `axis` ("x", "y" or "z")."""
    cx, cy, cz = centre
    points = []

    for k in range(steps):
        a = 2 * math.pi * k / steps
        u, v = radius * math.cos(a), radius * math.sin(a)
        points.append({"x": (cx, cy + u, cz + v), "y": (cx + u, cy, cz + v), "z": (cx + u, cy + v, cz)}[axis])

    pipe(m, points, tube, sides, slot, closed=True)


# --- a Metro bench ------------------------------------------------------------------------------

def bench(m):
    """A Metro bench against the wall: cast-iron ends bolted to the floor and
    to the wall, chunky slats worn pale where people sit."""
    length = 1.8
    seat_y = [(-0.5, -0.41), (-0.39, -0.3), (-0.28, -0.19), (-0.17, -0.08)]

    for x in (0.12, length - 0.12):
        # The cast end: a front leg, a rear leg leaning back up to the wall, the bearer under the seat.
        pipe(m, [(x, -0.47, 0.03), (x, -0.46, 0.2), (x, -0.44, BENCH_SEAT - SLAT_T - 0.03)], 0.022, 4, "steel")
        pipe(m, [(x, -0.12, 0.03), (x, -0.1, 0.4), (x, -0.06, 0.66), (x, -0.035, 0.86)], 0.022, 4, "steel")
        box(m, (x - 0.025, -0.52, BENCH_SEAT - SLAT_T - 0.05), (x + 0.025, -0.06, BENCH_SEAT - SLAT_T), "steel", r=0.0)

        for y in (-0.47, -0.12):
            box(m, (x - 0.05, y - 0.05, 0.0), (x + 0.05, y + 0.05, 0.03), "steel", r=0.0)
            stud(m, (x + 0.03, y, 0.03), 0.0, 0.0, r=0.02)

        box(m, (x - 0.04, -0.014, 0.76), (x + 0.04, 0.0, 0.9), "steel", r=0.0)
        stud(m, (x, -0.014, 0.83), math.pi / 2, 0.0, r=0.02)

    for y0, y1 in seat_y:
        box(m, (0.02, y0, BENCH_SEAT - SLAT_T), (length - 0.02, y1, BENCH_SEAT), "wood")

    # The back: two slats leaning with the rear legs.
    for z, y in ((0.58, -0.085), (0.76, -0.06)):
        box(m, (0.02, y - SLAT_T / 2, z - 0.05), (length - 0.02, y + SLAT_T / 2, z + 0.05), "wood",
            turn=(math.radians(-8), 0.0, 0.0))


# --- the tamale seller's cart -------------------------------------------------------------------

def _wheel(m, x, y, r=0.3):
    """A cart wheel: a rubber tyre, a hub, eight spokes."""
    ring(m, (x, y, r), r - 0.025, 0.025, "y", "rubber", sides=8, steps=20)
    turned(m, [(0.05, 0.0), (0.05, 0.08)], 8, "steel", at=(x, y + 0.04, r), lean=math.pi / 2, towards=0.0)

    for k in range(8):
        a = 2 * math.pi * k / 8 + 0.2
        pipe(m, [(x + 0.045 * math.cos(a), y, r + 0.045 * math.sin(a)),
                 (x + (r - 0.045) * math.cos(a), y, r + (r - 0.045) * math.sin(a))], 0.012, 6, "steel")


def tamale_cart(m):
    """Her cart: a turquoise body with red posts and a yellow top, on two wheels
    and two legs, push handles behind; on top the big tin steamer of tamales
    with its lid on, a clay olla of champurrado with its ladle, and her sign
    on a stick (its words are the user's)."""
    w, d, low = 0.5, 0.3, 0.36
    post = 0.06

    for sx in (-1, 1):
        for sy in (-1, 1):
            x, y = sx * (w - post / 2), sy * (d - post / 2)
            box(m, (x - post / 2, y - post / 2, low - 0.04), (x + post / 2, y + post / 2, CART_TOP), "paint_trim")

    # The panels between the posts, set in from their faces; the bottom board; the top board.
    inset = 0.02
    for sy in (-1, 1):
        y = sy * (d - inset - 0.02)
        box(m, (-w + post, y - 0.02, low), (w - post, y + 0.02, CART_TOP - 0.04), "paint_cart")
    for sx in (-1, 1):
        x = sx * (w - inset - 0.02)
        box(m, (x - 0.02, -d + post, low), (x + 0.02, d - post, CART_TOP - 0.04), "paint_cart")
    box(m, (-w + post, -d + post, low), (w - post, d - post, low + 0.04), "wood", r=0.0)
    box(m, (-w + post, -d + post, CART_TOP - 0.04), (w - post, d - post, CART_TOP), "paint_band")

    # Two wheels on an axle under the middle, two legs at the handle end.
    pipe(m, [(POT_AT[0], -d - 0.08, 0.3), (POT_AT[0], d + 0.08, 0.3)], 0.02, 8, "steel")
    for sy in (-1, 1):
        _wheel(m, POT_AT[0], sy * (d + 0.09))
    for sy in (-1, 1):
        pipe(m, [(-w + 0.06, sy * (d - 0.08), low), (-w + 0.04, sy * (d - 0.06), 0.03)], 0.02, 6, "steel")
        box(m, (-w + 0.0, sy * (d - 0.06) - 0.04, 0.0), (-w + 0.08, sy * (d - 0.06) + 0.04, 0.03), "rubber", r=0.0)

    # The push handles, their grips bound in rubber.
    for sy in (-1, 1):
        pipe(m, [(-w + 0.02, sy * 0.2, 0.72), (-w - 0.2, sy * 0.2, 0.8), (-w - 0.34, sy * 0.2, 0.86)], 0.02, 8, "steel")
        pipe(m, [(-w - 0.24, sy * 0.2, 0.82), (-w - 0.38, sy * 0.2, 0.88)], 0.028, 8, "rubber")

    # The steamer: tall, tin, dented a little, its lid on, a handle each side.
    px, py = POT_AT
    lathe_z(m, [(0.17, 0.0, "tin"), (0.2, 0.03, "tin"), (0.2, 0.46, "tin"), (0.212, 0.5, "tin")], 14,
            at=(px, py, CART_TOP))
    lathe_z(m, [(0.215, 0.5, "tin"), (0.205, 0.53, "tin"), (0.13, 0.58, "tin"), (0.05, 0.6, "tin")], 14,
            at=(px, py, CART_TOP))
    lathe_z(m, [(0.03, 0.6, "steel"), (0.036, 0.63, "steel"), (0.02, 0.65, "steel")], 8, at=(px, py, CART_TOP))

    for sy in (-1, 1):
        pipe(m, [(px - 0.05, py + sy * 0.198, CART_TOP + 0.38), (px - 0.04, py + sy * 0.25, CART_TOP + 0.4),
                 (px + 0.04, py + sy * 0.25, CART_TOP + 0.4), (px + 0.05, py + sy * 0.198, CART_TOP + 0.38)],
             0.015, 6, "steel")

    # The champurrado's olla and its ladle.
    ox, oy = -0.27, 0.06
    lathe_z(m, [(0.08, 0.0, "clay"), (0.13, 0.08, "clay"), (0.12, 0.2, "clay"), (0.09, 0.25, "clay"),
                (0.1, 0.28, "clay")], 12, at=(ox, oy, CART_TOP))
    pipe(m, [(ox + 0.02, oy, CART_TOP + 0.24), (ox + 0.06, oy - 0.02, CART_TOP + 0.36), (ox + 0.12, oy - 0.04, CART_TOP + 0.44)],
         0.012, 6, "wood")

    # Her sign on its stick at the front corner (left plain: the words are the user's).
    sx, sy = w - 0.03, -d + 0.03
    pipe(m, [(sx, sy, CART_TOP), (sx, sy, 1.3)], 0.016, 6, "wood")
    box(m, (sx - 0.18, sy - 0.05, 1.16), (sx + 0.18, sy - 0.015, 1.38), "sign")


def stool(m):
    """Her stool: a round wooden seat on three splayed legs."""
    top = 0.42
    lathe_z(m, [(0.16, top - 0.04, "wood"), (0.16, top, "wood")], 12)

    for k in range(3):
        a = 2 * math.pi * k / 3 + 0.3
        pipe(m, [(0.08 * math.cos(a), 0.08 * math.sin(a), top - 0.04), (0.17 * math.cos(a), 0.17 * math.sin(a), 0.02)],
             0.02, 6, "wood")
        box(m, (0.17 * math.cos(a) - 0.03, 0.17 * math.sin(a) - 0.03, 0.0), (0.17 * math.cos(a) + 0.03, 0.17 * math.sin(a) + 0.03, 0.02),
            "wood", r=0.0)


# --- a bin ---------------------------------------------------------------------------------------

def trash_bin(m):
    """A steel drum bin in the Company's orange with a cream band, rolled hoops,
    its lid propped half open, a crumpled paper caught on its rim."""
    lathe_z(m, [(0.2, 0.0, "metro_orange"), (0.21, 0.03, "metro_orange"), (0.21, 0.3, "paint_band"),
                (0.21, 0.4, "metro_orange"), (0.21, 0.68, "metro_orange"), (0.2, 0.7, "metro_orange")], 16)

    for z in (0.17, 0.53):
        ring(m, (0.0, 0.0, z), 0.215, 0.014, "z", "steel", sides=6, steps=20)

    # The lid, hinged at the back of the rim, propped open on the rubbish.
    hinge, opened = (-0.2, 0.0, 0.705), 0.9
    turned(m, [(0.215, 0.0), (0.215, 0.03), (0.15, 0.05)], 16, "metro_orange",
           at=(hinge[0] + 0.215 * math.cos(opened), 0.0, hinge[2] + 0.215 * math.sin(opened)),
           lean=opened, towards=-math.pi / 2)
    box(m, (-0.235, -0.06, 0.66), (-0.205, 0.06, 0.73), "steel", r=0.0)
    # A newspaper crumpled into a ball, caught on the rim.
    turned(m, [(0.03, 0.0), (0.07, 0.03), (0.075, 0.07), (0.05, 0.11), (0.02, 0.13)], 9, "newsprint",
           at=(0.08, 0.06, 0.62), jitter=0.3)


# --- the Virgin's niche --------------------------------------------------------------------------

def _candle(m, x, y, z, r, h, slot="wax"):
    """A candle on the shelf, a wax candle's foot flared where it has run and pooled."""
    foot = [(r + 0.022, 0.0, "wax"), (r + 0.01, 0.014, "wax"), (r, 0.03, slot)] if slot == "wax" else [(r, 0.0, slot)]
    lathe_z(m, foot + [(r, h - 0.02, slot), (r * 0.85, h, slot)], 8, at=(x, y, z))
    m.wick((x, y, z + h + 0.005))


def niche(m):
    """Built out from the wall by those who pray here: a glazed cabinet on a
    shelf, its inside the Virgin's blue, a place for her image (the user's
    painting), a gabled top with a cross, a rosary hung from it; on the shelf
    pillar candles and glass veladoras lit, wax run over, flowers in jars."""
    s = NICHE_SILL
    # The shelf on two corbels.
    box(m, (-0.44, -0.32, s - 0.06), (0.44, 0.0, s), "paint_band")
    for x in (-0.3, 0.3):
        box(m, (x - 0.03, -0.18, s - 0.26), (x + 0.03, 0.0, s - 0.06), "paint_band")

    # The cabinet: its sides, back, top and floor; its glass front.
    h = 0.75
    for sx in (-1, 1):
        box(m, (sx * 0.3 - 0.03, -0.2, s), (sx * 0.3 + 0.03, 0.0, s + h), "paint_blue")
    box(m, (-0.27, -0.035, s), (0.27, 0.0, s + h), "paint_blue")
    box(m, (-0.33, -0.22, s + h), (0.33, 0.0, s + h + 0.04), "paint_blue")
    box(m, (-0.16, -0.07, s + 0.12), (0.16, -0.035, s + 0.6), "print_saint")
    box(m, (-0.27, -0.19, s + 0.01), (0.27, -0.16, s + h - 0.01), "glass", r=0.0)
    box(m, (0.22, -0.23, s + 0.33), (0.25, -0.19, s + 0.4), "steel", r=0.0)

    # The gabled top and its cross.
    for sx in (-1, 1):
        cx = sx * 0.15
        box(m, (cx - 0.2, -0.22, s + h + 0.1), (cx + 0.2, 0.0, s + h + 0.14), "paint_red",
            turn=(0.0, sx * math.radians(26), 0.0))
    box(m, (-0.02, -0.13, s + h + 0.2), (0.02, -0.09, s + h + 0.42), "paint_band", r=0.0)
    box(m, (-0.08, -0.13, s + h + 0.31), (0.08, -0.09, s + h + 0.35), "paint_band", r=0.0)

    # A rosary hung from the gable's ends, its cross dangling below the cabinet's door.
    beads = []
    for k in range(17):
        t = k / 16
        beads.append((-0.3 + 0.6 * t, -0.24, s + h - 0.06 - 0.28 * math.sin(math.pi * t)))
    for x, y, z in beads[::2]:
        turned(m, [(0.012, 0.0), (0.016, 0.012), (0.012, 0.024)], 6, "wood", at=(x, y, z - 0.012))
    box(m, (-0.012, -0.255, s + h - 0.5), (0.012, -0.225, s + h - 0.36), "steel", r=0.0)
    box(m, (-0.04, -0.255, s + h - 0.42), (0.04, -0.225, s + h - 0.395), "steel", r=0.0)

    # On the shelf: pillar candles pooled in their run wax, veladoras in glass, two jars of flowers.
    for x, r, hgt in ((-0.24, 0.032, 0.22), (-0.15, 0.028, 0.15), (0.13, 0.03, 0.18), (0.2, 0.026, 0.11),
                      (0.27, 0.03, 0.26)):
        _candle(m, x, -0.25, s, r, hgt)
    for x in (-0.04, 0.04):
        _candle(m, x, -0.27, s, 0.034, 0.2, slot="glass")
    for x, slot in ((-0.37, "marigold"), (0.37, "paint_red")):
        lathe_z(m, [(0.035, 0.0, "clay"), (0.045, 0.06, "clay"), (0.03, 0.12, "clay"), (0.036, 0.14, "clay")], 8,
                at=(x, -0.16, s))
        for k in range(3):
            a = 2 * math.pi * k / 3 + rng.uniform(0, 1)
            tip = (x + 0.06 * math.cos(a), -0.16 + 0.06 * math.sin(a), s + 0.3 + 0.04 * k)
            pipe(m, [(x, -0.16, s + 0.1), tip], 0.011, 6, "herb")
            turned(m, [(0.02, 0.0), (0.04, 0.02), (0.035, 0.045), (0.015, 0.06)], 8, slot,
                   at=(tip[0], tip[1], tip[2] - 0.01), jitter=0.1)


# --- a vent grille ------------------------------------------------------------------------------

def vent_grille(m):
    """A cast-iron grille low in the wall, louvred, screwed at its corners:
    warm air breathes out of the dark behind it."""
    lo, hi = 0.15, 0.55
    box(m, (-0.32, -0.05, lo), (0.32, 0.0, lo + 0.04), "steel", r=0.0)
    box(m, (-0.32, -0.05, hi - 0.04), (0.32, 0.0, hi), "steel", r=0.0)
    for sx in (-1, 1):
        box(m, (sx * 0.3 - 0.02, -0.05, lo + 0.04), (sx * 0.3 + 0.02, 0.0, hi - 0.04), "steel", r=0.0)
    box(m, (-0.28, -0.012, lo + 0.04), (0.28, 0.0, hi - 0.04), "soot_black", r=0.0)

    z = lo + 0.075
    while z < hi - 0.06:
        box(m, (-0.28, -0.046, z - 0.006), (0.28, -0.016, z + 0.006), "steel", r=0.0, turn=(math.radians(35), 0.0, 0.0))
        z += 0.055

    for sx in (-1, 1):
        for zz in (lo + 0.02, hi - 0.02):
            stud(m, (sx * 0.3, -0.05, zz), math.pi / 2, 0.0, r=0.02)


PIECES = [bench, tamale_cart, stool, trash_bin, niche, vent_grille]


def build():
    common.reset()
    underground_shapes.rng = rng
    rng.seed(1931)

    for f in PIECES:
        smooth_object(f.__name__, f)


def main():
    build()
    common.export_piece(NAME, ATLAS, SLOTS, out=common.ROOT / "assets" / "eclipse" / "kit", sets_each=True, budget=9000)


if __name__ == "__main__":
    main()
