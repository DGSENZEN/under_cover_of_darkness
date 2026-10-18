"""The rare-book librarian's corner (docs/superpowers/specs/2026-10-17-librarian-shop-design.md;
docs/superpowers/refs/underground/recipe.md): what says who he is before he is ever seen. A Catholic
exorcist, a specialist hunter, and a dealer in rare books.

The dealer (this file's first family):
- desk: a high clerk's desk facing the customers, a green felt writing inlay in its top, a brass rail along
  the customers' edge, a brass kick plate where their boots have scuffed it, his drawers on his side;
- desk_chair: his tall clerk's chair, pushed back and half-turned as he left it;
- lamp: a green-shaded lamp on a jointed brass arm at the desk's back corner (its bulb a wick, for the bay's
  light);
- ledger: the acquisitions ledger lying open (its pages blank: what he wrote is the user's);
- magnifier, gloves (white cotton, a pair), repair_kit (a bone folder, a glue pot with its brush, a spool of
  waxed thread);
- coat_hook: a coat stand beside the desk, his black coat on it with its torn hem mended, his black felt hat.

The frame: the desk's middle at the origin on the floor, the customers' side toward -y (Godot's +z, the
shopfront), x across. The bay sets it at CORNER_AT.

    Blender -b --factory-startup --python tools/eclipse/library_corner.py
"""

import math
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import common  # noqa: E402
import library_room  # noqa: E402
import shapes  # noqa: E402
import underground_shapes  # noqa: E402
from underground_shapes import box, pipe, smooth_object, turned  # noqa: E402

NAME = "library_corner"
ATLAS = 2048
SLOTS = ["wood", "brass", "felt_green", "leather_old", "paper", "glass", "glass_green", "cotton_white", "bone",
         "steel", "paper_kraft", "coat_black", "cloth_patch", "hat_felt"]

rng = random.Random(1897)

# Where the corner stands in the room (Godot: x, z), and the desk's writing top (m).
CORNER_AT = (0.0, -(library_room.DEPTH - 1.6))
DESK_TOP = 1.05
# The desk's half-width and half-depth; the customers' side at -DESK_D.
DESK_W = 0.8
DESK_D = 0.36
# What lies on the desk sits this far above its top.
LIFT = 0.003


def _rot(p, yaw, about=(0.0, 0.0)):
    """A point turned `yaw` (radians) about the vertical through `about`."""
    c, s = math.cos(yaw), math.sin(yaw)
    x, y = p[0] - about[0], p[1] - about[1]
    return (about[0] + c * x - s * y, about[1] + s * x + c * y) + tuple(p[2:])


def _block(m, centre, size, yaw, top, rest):
    """A box at `centre` (its bottom's middle) `size` across, turned `yaw`; its top face `top`, the rest `rest`."""
    cx, cy, cz = centre
    sx, sy, sz = size[0] / 2, size[1] / 2, size[2]
    m.shell()
    lo = [_rot((cx + dx, cy + dy, cz), yaw, (cx, cy)) for dx, dy in ((-sx, -sy), (sx, -sy), (sx, sy), (-sx, sy))]
    hi = [(x, y, z + sz) for x, y, z in lo]
    m.face(list(reversed(lo)), rest)
    m.face(hi, top)

    for k in range(4):
        m.face([lo[k], lo[(k + 1) % 4], hi[(k + 1) % 4], hi[k]], rest)


# --- the dealer --------------------------------------------------------------------------------------------

def desk(m):
    """A high clerk's desk: its plinth, its carcass with raised fields toward the customers and a brass kick
    plate their boots have scuffed bright, its top with a green felt inlay, a brass rail along their edge, his
    drawers behind."""
    w, d = DESK_W, DESK_D
    box(m, (-w + 0.02, -d + 0.02, 0.0), (w - 0.02, d - 0.02, 0.08), "wood", r=0.02)
    box(m, (-w + 0.04, -d + 0.04, 0.08), (w - 0.04, d - 0.06, 0.98), "wood", r=0.02)
    # The customers' side: two raised fields, and the kick plate under them.
    for x0, x1 in ((-w + 0.1, -0.04), (0.04, w - 0.1)):
        box(m, (x0, -d, 0.2), (x1, -d + 0.04, 0.9), "wood", r=0.02)
    box(m, (-w + 0.06, -d - 0.005, 0.085), (w - 0.06, -d + 0.04, 0.17), "brass", r=0.0)
    # The top: a board under, then a frame round a felt inlay (the inlay level with the frame: no layered faces).
    box(m, (-w, -d - 0.02, 0.98), (w, d, DESK_TOP - 0.035), "wood", r=0.02)
    rim = 0.09
    box(m, (-w, -d - 0.02, DESK_TOP - 0.035), (w, -d - 0.02 + rim, DESK_TOP), "wood", r=0.0)
    box(m, (-w, d - rim, DESK_TOP - 0.035), (w, d, DESK_TOP), "wood", r=0.0)
    box(m, (-w, -d - 0.02 + rim, DESK_TOP - 0.035), (-w + rim, d - rim, DESK_TOP), "wood", r=0.0)
    box(m, (w - rim, -d - 0.02 + rim, DESK_TOP - 0.035), (w, d - rim, DESK_TOP), "wood", r=0.0)
    box(m, (-w + rim, -d - 0.02 + rim, DESK_TOP - 0.035), (w - rim, d - rim, DESK_TOP), "felt_green", r=0.0)
    # The brass rail along the customers' edge, on its posts.
    for x in (-w + 0.08, 0.0, w - 0.08):
        turned(m, [(0.018, 0.0), (0.018, 0.075)], 8, "brass", at=(x, -d + 0.03, DESK_TOP))
    pipe(m, [(-w + 0.04, -d + 0.03, DESK_TOP + 0.075), (w - 0.04, -d + 0.03, DESK_TOP + 0.075)], 0.016, 8, "brass")
    # His drawers, behind, their knobs.
    for k, (x0, x1) in enumerate(((-w + 0.08, -0.27), (-0.23, 0.23), (0.27, w - 0.08))):
        box(m, (x0, d - 0.06, 0.74), (x1, d - 0.02, 0.93), "wood", r=0.02)
        turned(m, [(0.022, 0.0), (0.022, 0.02), (0.017, 0.035)], 8, "brass", at=((x0 + x1) / 2, d - 0.02, 0.835),
               lean=math.pi / 2, towards=math.pi / 2)


def desk_chair(m):
    """His tall clerk's chair: a turned seat on four splayed legs with a footrest ring, a bowed back; pushed back
    from the desk and half-turned, as he left it."""
    at = (0.12, 0.82)
    yaw = math.radians(35.0)
    seat = 0.72
    turned(m, [(0.2, seat - 0.05), (0.21, seat - 0.02), (0.2, seat)], 12, "wood", at=(at[0], at[1], 0.0))

    for k in range(4):
        a = yaw + math.pi / 4 + k * math.pi / 2
        top = (at[0] + 0.14 * math.cos(a), at[1] + 0.14 * math.sin(a), seat - 0.05)
        foot = [at[0] + 0.22 * math.cos(a), at[1] + 0.22 * math.sin(a), 0.0]
        # (The splayed leg's end ring tips below its foot: lifted so the ring's lowest point is on the floor.)
        splay = math.atan2(0.08, top[2])
        foot[2] = 0.019 * math.sin(splay)
        pipe(m, [tuple(foot), top], 0.019, 8, "wood")

    ring = []
    for k in range(16):
        a = 2 * math.pi * k / 16
        ring.append((at[0] + 0.19 * math.cos(a), at[1] + 0.19 * math.sin(a), 0.3))
    pipe(m, ring, 0.015, 8, "brass", closed=True)

    # The back: two posts up from the seat's rear and a bowed rail over them.
    back = []
    for k in range(7):
        a = yaw + math.pi / 2 + math.radians(-50 + 100 * k / 6)
        back.append((at[0] + 0.17 * math.cos(a), at[1] + 0.17 * math.sin(a), seat + 0.3))
    pipe(m, back, 0.02, 8, "wood")
    for p in (back[0], back[-1]):
        pipe(m, [(p[0], p[1], seat), p], 0.018, 8, "wood")


def lamp(m):
    """A green-shaded lamp on a jointed brass arm, its weighted foot at the desk's back corner, its shade over
    the ledger; its bulb in the shade's hollow is a wick (the bay's light stands there)."""
    foot = (-0.6, 0.2, DESK_TOP + LIFT)
    turned(m, [(0.085, 0.0), (0.085, 0.022), (0.05, 0.035)], 14, "brass", at=foot)
    joint = (foot[0], foot[1], foot[2] + 0.4)
    pipe(m, [(foot[0], foot[1], foot[2] + 0.035), joint], 0.016, 8, "brass")
    turned(m, [(0.017, -0.022), (0.03, -0.012), (0.03, 0.012), (0.017, 0.022)], 10, "brass", at=joint)
    head = (-0.32, 0.04, DESK_TOP + 0.46)
    pipe(m, [joint, ((joint[0] + head[0]) / 2, (joint[1] + head[1]) / 2, joint[2] + 0.07), head], 0.015, 8, "brass")
    # The shade: a thick emerald bowl, open below, hung from the arm's end.
    shade = (head[0], head[1], head[2] - 0.11)
    turned(m, [(0.025, 0.1), (0.07, 0.07), (0.115, 0.0), (0.1, 0.0), (0.06, 0.045), (0.018, 0.06)], 16,
           "glass_green", at=shade)
    turned(m, [(0.02, 0.0), (0.02, 0.03)], 8, "brass", at=(shade[0], shade[1], shade[2] + 0.1))
    m.wick((shade[0], shade[1], shade[2] + 0.035))


def ledger(m):
    """The acquisitions ledger lying open: two thick halves meeting at its gutter, their pages (blank: what he
    wrote is the user's) on leather boards."""
    yaw = math.radians(-7.0)
    middle = (-0.12, 0.04)
    z = DESK_TOP + LIFT

    # (Meeting at the gutter: a lower spine between them would lie too near their pages.)
    for side in (-1, 1):
        c = _rot((middle[0] + side * 0.127, middle[1], z), yaw, middle)
        _block(m, c, (0.25, 0.33, 0.032), yaw, "paper", "leather_old")


def magnifier(m):
    """A big reading glass lying on the desk, its lens in a brass rim, a turned wooden handle."""
    at = (0.28, 0.25)
    zc = DESK_TOP + LIFT + 0.016
    turned(m, [(0.045, zc - 0.007), (0.045, zc + 0.007)], 20, "glass", at=(at[0], at[1], 0.0))
    ring = [(at[0] + 0.062 * math.cos(2 * math.pi * k / 20), at[1] + 0.062 * math.sin(2 * math.pi * k / 20), zc)
            for k in range(20)]
    pipe(m, ring, 0.016, 8, "brass", closed=True)
    pipe(m, [(at[0] + 0.07, at[1] - 0.02, zc), (at[0] + 0.21, at[1] - 0.07, zc)], 0.016, 8, "wood")


def _glove(m, at, yaw, mirror):
    """One white cotton glove lying flat, palm down: its cuff, palm, four fingers and thumb."""
    z = DESK_TOP + LIFT
    t = 0.016
    parts = [((0.0, -0.075), (0.085, 0.05)),                      # cuff
             ((0.0, 0.0), (0.09, 0.1))]                           # palm
    for k, (length, dx) in enumerate(((0.06, -0.031), (0.072, -0.0105), (0.068, 0.0105), (0.055, 0.031))):
        parts.append(((dx, 0.05 + length / 2 + 0.002), (0.018, length)))
    parts.append(((0.06, 0.0), (0.03, 0.05)))                     # thumb, out to its side

    for (dx, dy), (sx, sy) in parts:
        c = _rot((at[0] + dx * mirror, at[1] + dy, z), yaw, at)
        _block(m, c, (sx, sy, t), yaw, "cotton_white", "cotton_white")


def gloves(m):
    """His white cotton gloves for handling the old books, a pair, dropped side by side."""
    _glove(m, (0.47, -0.2), math.radians(80.0), 1)
    _glove(m, (0.6, -0.04), math.radians(105.0), -1)


def repair_kit(m):
    """A book-mender's few things: a bone folder, a tin glue pot with its brush stood in it, a spool of waxed
    thread."""
    z = DESK_TOP + LIFT
    _block(m, (0.66, 0.28, z), (0.2, 0.034, 0.013), math.radians(12.0), "bone", "bone")
    turned(m, [(0.036, 0.0), (0.038, 0.05), (0.034, 0.06)], 12, "steel", at=(0.6, 0.15, z))
    pipe(m, [(0.6, 0.15, z + 0.045), (0.63, 0.165, z + 0.15)], 0.012, 6, "wood")
    turned(m, [(0.031, 0.0), (0.031, 0.012), (0.0168, 0.012), (0.0168, 0.042), (0.031, 0.042), (0.031, 0.054)], 10,
           "paper_kraft", at=(0.73, 0.13, z))


def coat_hook(m):
    """A coat stand beside the desk on his side: three splayed feet, a turned pole, hooks; on it his long black
    coat, its torn hem mended with another cloth, and on its crown his black felt hat."""
    at = (1.18, 0.42)
    for k in range(3):
        a = math.radians(90 + 120 * k)
        pipe(m, [(at[0], at[1], 0.12), (at[0] + 0.3 * math.cos(a), at[1] + 0.3 * math.sin(a), 0.0)], 0.02, 8, "wood")
    turned(m, [(0.028, 0.0), (0.028, 1.78), (0.04, 1.8), (0.028, 1.84)], 10, "wood", at=(at[0], at[1], 0.06))

    for k in range(4):
        a = math.radians(45 + 90 * k)
        root = (at[0] + 0.02 * math.cos(a), at[1] + 0.02 * math.sin(a), 1.66)
        pipe(m, [root, (at[0] + 0.12 * math.cos(a), at[1] + 0.12 * math.sin(a), 1.72),
                 (at[0] + 0.15 * math.cos(a), at[1] + 0.15 * math.sin(a), 1.8)], 0.012, 6, "brass")

    # The coat, hung by its loop from the hook toward the desk: a narrow collar, shoulders falling away from
    # it, the body widening to the hem, both sleeves hanging at its sides; its front's hem torn and mended.
    cx, cy = at[0] - 0.02, at[1] - 0.14
    # Its sections, top down: (z, half-width, half-depth).
    sections = [(1.7, 0.045, 0.04), (1.64, 0.1, 0.06), (1.57, 0.2, 0.085), (1.5, 0.235, 0.1), (1.3, 0.225, 0.105),
                (1.05, 0.21, 0.1), (0.8, 0.235, 0.105), (0.6, 0.26, 0.11), (0.5, 0.27, 0.11)]
    sides = 16

    def ring(z, w, d):
        return [(cx + w * math.cos(2 * math.pi * k / sides), cy + d * math.sin(2 * math.pi * k / sides), z)
                for k in range(sides)]

    m.shell()
    shapes.loft(m, [ring(*sec) for sec in sections], "coat_black")
    # The hem band below the body, its front (toward -y) mended with another cloth.
    hem = [(0.5, 0.27, 0.11), (0.42, 0.275, 0.11)]
    front = ["cloth_patch" if 10 <= k <= 13 else "coat_black" for k in range(sides)]
    m.shell()
    shapes.loft(m, [ring(*sec) for sec in hem], front)

    for side in (-1, 1):
        # (Each sleeve starts inside the shoulder, so its end never shows.)
        pipe(m, [(cx + side * 0.165, cy, 1.53), (cx + side * 0.215, cy, 1.45), (cx + side * 0.255, cy + 0.01, 1.28), (cx + side * 0.25, cy - 0.01, 1.04),
                 (cx + side * 0.24, cy - 0.02, 0.92)], 0.055, 8, "coat_black")

    # (One solid: a brim and a crown stacked would lay faces too near each other.)
    top = (at[0], at[1], 1.9)
    turned(m, [(0.17, 0.0), (0.17, 0.014), (0.1, 0.02), (0.095, 0.03), (0.095, 0.11), (0.07, 0.13), (0.03, 0.115)],
           16, "hat_felt", at=top)


DEALER = [desk, desk_chair, lamp, ledger, magnifier, gloves, repair_kit, coat_hook]


def build():
    common.reset()
    underground_shapes.rng = rng
    rng.seed(1897)

    for f in DEALER:
        smooth_object(f.__name__, f)


def main():
    build()
    common.export_piece(NAME, ATLAS, SLOTS, out=common.ROOT / "assets" / "eclipse" / "kit", sets_each=True, budget=6000)


if __name__ == "__main__":
    main()
