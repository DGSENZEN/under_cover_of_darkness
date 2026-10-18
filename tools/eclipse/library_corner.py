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
from mathutils import Vector  # noqa: E402
import underground_shapes  # noqa: E402
from underground_shapes import box, pipe, smooth_object, turned  # noqa: E402

NAME = "library_corner"
ATLAS = 2048
SLOTS = ["wood", "brass", "felt_green", "leather_old", "paper", "glass", "glass_green", "cotton_white", "bone",
         "steel", "paper_kraft", "coat_black", "cloth_patch", "hat_felt", "velvet_purple", "silver", "wax_white"]

rng = random.Random(1897)

# Where the corner stands in the room (Godot: x, z), and the desk's writing top (m).
CORNER_AT = (0.0, -(library_room.DEPTH - 1.6))
DESK_TOP = 1.05
# The desk's half-width and half-depth; the customers' side at -DESK_D.
DESK_W = 0.8
DESK_D = 0.36
# What lies on the desk sits this far above its top.
LIFT = 0.003
# His lamp's arm: its weighted foot on the desk, its knuckle, the arm's bend, the shade's head.
LAMP_FOOT = (-0.6, 0.2, DESK_TOP + LIFT)
LAMP_JOINT = (LAMP_FOOT[0], LAMP_FOOT[1], LAMP_FOOT[2] + 0.4)
LAMP_HEAD = (-0.32, 0.04, DESK_TOP + 0.46)
LAMP_MID = ((LAMP_JOINT[0] + LAMP_HEAD[0]) / 2, (LAMP_JOINT[1] + LAMP_HEAD[1]) / 2, LAMP_JOINT[2] + 0.07)


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
        # (Tipped toward heading pi: out of the drawer, +y. A heading a points the axis along (sin a, -cos a).)
        turned(m, [(0.022, 0.0), (0.022, 0.02), (0.017, 0.035)], 8, "brass", at=((x0 + x1) / 2, d - 0.02, 0.835),
               lean=math.pi / 2, towards=math.pi)


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
    foot = LAMP_FOOT
    turned(m, [(0.085, 0.0), (0.085, 0.022), (0.05, 0.035)], 14, "brass", at=foot)
    joint = LAMP_JOINT
    pipe(m, [(foot[0], foot[1], foot[2] + 0.035), joint], 0.016, 8, "brass")
    turned(m, [(0.017, -0.022), (0.03, -0.012), (0.03, 0.012), (0.017, 0.022)], 10, "brass", at=joint)
    head = LAMP_HEAD
    pipe(m, [joint, LAMP_MID, head], 0.015, 8, "brass")
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


# --- the rite --------------------------------------------------------------------------------------------

def _book(m, centre, size, yaw, cover, pages, spine=-1, lip=0.011):
    """A closed book lying flat, `size` (across, along, thick), `centre` its bottom's middle, turned `yaw`: its
    boards overhanging the pages' fore-edge by `lip` (the pages `pages` between them, the boards and the rounded
    spine `cover`); the spine on its -x side (`spine` -1) or +x (1). Lofted along the book's length."""
    cx, cy, cz = centre
    w, length, h = size
    # Its section, from the spine round to the fore-edge and back (x across from the spine, z up).
    outline = [(0.012, 0.0), (w, 0.0), (w, lip), (w - lip, lip), (w - lip, h - lip), (w, h - lip), (w, h), (0.012, h),
               (0.004, h * 0.8), (0.0, h * 0.5), (0.004, h * 0.2)]
    edge_slots = [cover, cover, cover, pages, cover, cover, cover, cover, cover, cover, cover]
    rings = []

    for y in (-length / 2, length / 2):
        ring = []
        for x, z in outline:
            px = (x - w / 2) * (-spine)
            ring.append(_rot((cx + px, cy + y, cz + z), yaw, (cx, cy)))
        rings.append(ring)

    m.shell()
    shapes.loft(m, rings, edge_slots)


def _band(m, path, width, thick, across, slot):
    """A flat band along `path` (a stole, a ribbon): `width` along `across` (kept square to the path), `thick`
    the other way; closed at both ends."""
    rings = []
    for i, p in enumerate(path):
        p = Vector(p)
        ahead = (Vector(path[min(i + 1, len(path) - 1)]) - Vector(path[max(i - 1, 0)])).normalized()
        w = Vector(across)
        n = ahead.cross(w).normalized()
        w = n.cross(ahead).normalized()
        rings.append([tuple(p + w * sw * width / 2 + n * sn * thick / 2) for sw, sn in ((-1, -1), (1, -1), (1, 1), (-1, 1))])
    m.shell()
    shapes.loft(m, rings, slot)


def _bands(m, at, stations, sides):
    """A closed solid turned about the vertical through `at` from [(r, z, slot)], each slot painting from its
    station to the next (a tin's label)."""
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


# His Rituale on the desk's front corner: its middle, and how it is turned (its fore-edge, local +x, toward the
# customers, a little askew).
RITUALE_AT = (-0.6, -0.16, DESK_TOP + LIFT)
RITUALE_YAW = math.radians(-75.0)


def rituale(m):
    """His Rituale Romanum, the rite of exorcism: worn leather, closed on the desk's front corner, its pages toward
    the customers and its ribbon markers spilling out of them onto the felt."""
    yaw = RITUALE_YAW
    at = RITUALE_AT
    _book(m, at, (0.17, 0.24, 0.05), yaw, "leather_old", "paper", spine=-1)
    # The markers: out of the fore-edge (the book's +x), each drooping from mid-page to the desk.
    edge = 0.085
    for k, (dy, slot) in enumerate(((-0.06, "velvet_purple"), (0.0, "silver"), (0.07, "velvet_purple"))):
        root = _rot((at[0] + edge, at[1] + dy, at[2] + 0.025), yaw, at[:2])
        mid = _rot((at[0] + edge + 0.03, at[1] + dy + 0.005 * k, at[2] + 0.012), yaw, at[:2])
        tip = _rot((at[0] + edge + 0.065, at[1] + dy + 0.01 * k, at[2] + 0.0055), yaw, at[:2])
        # (Lying flat: its width across the book, square to the way it runs.)
        _band(m, [root, mid, tip], 0.014, 0.011, _rot((0.0, 1.0, 0.0), yaw), slot)


def stole(m):
    """His purple stole, the exorcist's, hung over the lamp's arm where he took it off: a long band falling either
    side of the arm, one end longer."""
    a, b = Vector(LAMP_JOINT), Vector(LAMP_MID)
    arm = (b - a).normalized()
    top = a + (b - a) * 0.45
    side = Vector((arm.y, -arm.x, 0.0)).normalized()
    over = 0.015 + 0.008
    path = [top + side * 0.065 + Vector((0, 0, -0.3)), top + side * 0.062 + Vector((0, 0, -0.12)),
            top + side * 0.04 + Vector((0, 0, -0.02)), top + Vector((0, 0, over)), top - side * 0.04 + Vector((0, 0, -0.02)),
            top - side * 0.062 + Vector((0, 0, -0.1)), top - side * 0.066 + Vector((0, 0, -0.2))]
    _band(m, [tuple(p) for p in path], 0.1, 0.014, tuple(arm), "velvet_purple")


def crucifix(m):
    """A plain standing cross of dark wood on a heavy foot, its arms capped in silver."""
    x, y, z = -0.25, 0.29, DESK_TOP + LIFT
    # (Its foot one block: steps less than 3 cm apart would lay their faces too near each other.)
    box(m, (x - 0.05, y - 0.035, z), (x + 0.05, y + 0.035, z + 0.04), "wood", r=0.012)
    box(m, (x - 0.0125, y - 0.0125, z + 0.04), (x + 0.0125, y + 0.0125, z + 0.27), "wood", r=0.0)
    box(m, (x - 0.065, y - 0.0125, z + 0.18), (x - 0.0125, y + 0.0125, z + 0.205), "wood", r=0.0)
    box(m, (x + 0.0125, y - 0.0125, z + 0.18), (x + 0.065, y + 0.0125, z + 0.205), "wood", r=0.0)
    for cx, cz in ((x - 0.065, z + 0.1925), (x + 0.065, z + 0.1925)):
        box(m, (cx - (0.012 if cx < x else 0.0), y - 0.015, cz - 0.015), (cx + (0.0 if cx < x else 0.012), y + 0.015, cz + 0.015),
            "silver", r=0.0)
    box(m, (x - 0.015, y - 0.015, z + 0.27), (x + 0.015, y + 0.015, z + 0.282), "silver", r=0.0)


def aspergillum(m):
    """His holy-water sprinkler lying along the desk's front: a turned wooden handle, a pierced silver ball."""
    z = DESK_TOP + LIFT
    pipe(m, [(0.03, -0.27, z + 0.013), (0.26, -0.27, z + 0.013)], 0.013, 6, "wood")
    turned(m, [(0.017, -0.032), (0.03, -0.018), (0.032, 0.0), (0.03, 0.018), (0.017, 0.032)], 12, "silver",
           at=(0.3, -0.27, z + 0.032), lean=math.pi / 2, towards=0.0)


def salt_tin(m):
    """A tin of blessed salt, its paper label (blank: what it says is the user's), its lid."""
    _bands(m, (0.06, 0.29, DESK_TOP + LIFT), [(0.042, 0.0, "steel"), (0.042, 0.015, "paper"), (0.042, 0.052, "steel"),
                                              (0.044, 0.066, "steel"), (0.044, 0.082, "steel")], 14)


def oil_phial(m):
    """A phial of holy oil, the glass, its neck stopped and sealed in white wax."""
    x, y, z = 0.15, -0.195, DESK_TOP + LIFT
    turned(m, [(0.026, 0.0), (0.026, 0.055), (0.02, 0.068), (0.02, 0.085)], 12, "glass", at=(x, y, z))
    turned(m, [(0.022, 0.0), (0.022, 0.02), (0.018, 0.035)], 10, "wax_white", at=(x, y, z + 0.085))


def reliquary(m):
    """A small reliquary, a monstrance's shape: a turned brass foot, a glass cylinder with a saint's bone standing in it
    (held on a pin unseen), a crowned brass cap and a cross on it."""
    x, y, z = -0.15, -0.23, DESK_TOP + LIFT
    turned(m, [(0.06, 0.0), (0.06, 0.015), (0.045, 0.025), (0.045, 0.04)], 16, "brass", at=(x, y, z))
    base = z + 0.04
    # (The bone 3.5 cm clear of the glass's ends and sides, so no face of it lies near one of the glass's.)
    tall = 0.13
    turned(m, [(0.052, 0.0), (0.052, tall)], 16, "glass", at=(x, y, base))
    turned(m, [(0.02, 0.0), (0.017, 0.015), (0.017, 0.045), (0.02, 0.06)], 8, "bone", at=(x, y, base + 0.035))
    cap = base + tall
    turned(m, [(0.056, 0.0), (0.056, 0.02), (0.035, 0.04)], 16, "brass", at=(x, y, cap))
    top = cap + 0.04
    box(m, (x - 0.0125, y - 0.0125, top), (x + 0.0125, y + 0.0125, top + 0.06), "brass", r=0.0)
    box(m, (x - 0.035, y - 0.0125, top + 0.025), (x - 0.0125, y + 0.0125, top + 0.05), "brass", r=0.0)
    box(m, (x + 0.0125, y - 0.0125, top + 0.025), (x + 0.035, y + 0.0125, top + 0.05), "brass", r=0.0)


def benedict_medal(m):
    """A St Benedict medal nailed to the desk's front edge, facing whoever comes in (its face, the cross and the
    letters, is the user's)."""
    edge = -DESK_D - 0.02
    zc = (0.98 + DESK_TOP) / 2
    turned(m, [(0.03, 0.0), (0.03, 0.012)], 16, "silver", at=(0.0, edge, zc), lean=math.pi / 2, towards=0.0)
    turned(m, [(0.017, 0.0), (0.017, 0.02)], 8, "steel", at=(0.0, edge - 0.012, zc + 0.012),
           lean=math.pi / 2, towards=0.0)


# --- the hunt --------------------------------------------------------------------------------------------

# The back wall's face in the corner's frame; the rack's board, out from it, and the plane its things hang in.
WALL_Y = library_room.DEPTH + CORNER_AT[1]
BOARD = (-0.95, 0.95, 1.15, 2.85)
HANG_Y = WALL_Y - 0.09
# The pegs each thing hangs from (x, z), out of the board's face; the shelf the rounds stand on (x from, to, its top).
PEGS = {"trap_jaws": [(0.0, 2.77)], "crossbow": [(-0.45, 2.1), (0.15, 2.1)], "sword_cane": [(-0.55, 1.85), (0.35, 1.85)],
        "stakes": [(-0.75, 1.6)], "bandolier": [(-0.35, 1.6)], "chains": [(0.15, 1.6)], "revolver": [(0.55, 1.6)]}
SHELF = (0.6, 0.95, 1.19)
PEG_R = 0.018


def _peg_top(x, z):
    return z + PEG_R


def _wall_ring(m, centre, radius, tube, plane, slot, steps=8):
    """A closed ring of tube (a chain's link, a ring), about `centre`, in the wall's plane ("xz") or across it
    ("yz")."""
    cx, cy, cz = centre
    points = []
    for k in range(steps):
        a = 2 * math.pi * k / steps
        u, v = radius * math.cos(a), radius * math.sin(a)
        points.append((cx + u, cy, cz + v) if plane == "xz" else (cx, cy + u, cz + v))
    pipe(m, points, tube, 6, slot, closed=True)


def _spike(m, centre, radius, sides, length, twist, slot):
    """A point whittled or cast: a pyramid of `sides` from its base ring (radius, about the vertical through
    `centre`, at centre's height) down to its tip `length` below."""
    cx, cy, cz = centre
    ring = [(cx + radius * math.cos(twist + 2 * math.pi * k / sides), cy + radius * math.sin(twist + 2 * math.pi * k / sides), cz)
            for k in range(sides)]
    tip = (cx, cy, cz - length)
    m.shell()
    m.face(ring, slot)
    for k in range(sides):
        m.face([ring[(k + 1) % sides], ring[k], tip], slot)


def _wall_loop(m, points, width, thick, y, slot):
    """A closed flat band lying in the wall's plane at `y` (a belt hung in a loop), its broad face toward the room:
    `points` its middle line (x, z), `width` across it in the plane, `thick` along y."""
    n = len(points)
    rings = []
    for i, (x, z) in enumerate(points):
        (ax, az), (bx, bz) = points[i - 1], points[(i + 1) % n]
        tx, tz = bx - ax, bz - az
        k = math.hypot(tx, tz)
        nx, nz = -tz / k, tx / k
        rings.append([(x + sw * nx * width / 2, y + sy * thick / 2, z + sw * nz * width / 2)
                      for sw, sy in ((-1, -1), (1, -1), (1, 1), (-1, 1))])
    m.shell()
    shapes.loft(m, rings + [rings[0]], slot, caps=False)


def common_quads(lo, hi, front="felt_green"):
    """A box's six faces as (quad, slot): its -y face `front`, the rest left to the caller (None)."""
    x0, y0, z0 = lo
    x1, y1, z1 = hi
    return [([(x0, y0, z0), (x1, y0, z0), (x1, y0, z1), (x0, y0, z1)], front),
            ([(x0, y1, z0), (x0, y1, z1), (x1, y1, z1), (x1, y1, z0)], None),
            ([(x0, y0, z0), (x0, y0, z1), (x0, y1, z1), (x0, y1, z0)], None),
            ([(x1, y0, z0), (x1, y1, z0), (x1, y1, z1), (x1, y0, z1)], None),
            ([(x0, y0, z0), (x0, y1, z0), (x1, y1, z0), (x1, y0, z0)], None),
            ([(x0, y0, z1), (x1, y0, z1), (x1, y1, z1), (x0, y1, z1)], None)]


def hunt_rack(m):
    """His rack on the back wall behind the desk: a framed board with turned pegs for his working tools, a shelf at
    its foot, a cross carved on its crest."""
    x0, x1, z0, z1 = BOARD
    # The board, its face a dark green baize as a gunsmith lays out his tools (the frame stands over its edges).
    m.shell()
    lo, hi = (x0, WALL_Y - 0.04, z0), (x1, WALL_Y, z1)
    for quad, slot in common_quads(lo, hi):
        m.face(quad, slot if slot else "wood")
    # The frame round its face (standing 3.5 cm off it), the crest over it, the cross on the crest.
    f = 0.05
    for lo, hi in (((x0, z0), (x1, z0 + f)), ((x0, z1 - f), (x1, z1)), ((x0, z0 + f), (x0 + f, z1 - f)), ((x1 - f, z0 + f), (x1, z1 - f))):
        box(m, (lo[0], WALL_Y - 0.075, lo[1]), (hi[0], WALL_Y - 0.04, hi[1]), "wood", r=0.0)
    box(m, (x0 - 0.03, WALL_Y - 0.08, z1), (x1 + 0.03, WALL_Y, z1 + 0.12), "wood", r=0.02)
    box(m, (-0.016, WALL_Y - 0.115, z1 + 0.005), (0.016, WALL_Y - 0.08, z1 + 0.115), "wood", r=0.0)
    box(m, (-0.05, WALL_Y - 0.115, z1 + 0.06), (-0.016, WALL_Y - 0.08, z1 + 0.09), "wood", r=0.0)
    box(m, (0.016, WALL_Y - 0.115, z1 + 0.06), (0.05, WALL_Y - 0.08, z1 + 0.09), "wood", r=0.0)
    # The shelf at its foot on its brackets.
    sx0, sx1, top = SHELF
    box(m, (sx0, WALL_Y - 0.2, top - 0.04), (sx1, WALL_Y - 0.075, top), "wood", r=0.0)
    for bx in (sx0 + 0.04, sx1 - 0.04):
        box(m, (bx - 0.015, WALL_Y - 0.17, top - 0.16), (bx + 0.015, WALL_Y - 0.075, top - 0.04), "wood", r=0.0)
    # The pegs, turned, each knobbed at its end.
    for pegs in PEGS.values():
        for px, pz in pegs:
            turned(m, [(PEG_R, 0.0), (PEG_R, 0.08), (0.026, 0.092), (0.026, 0.11)], 8, "wood", at=(px, WALL_Y - 0.04, pz),
                   lean=math.pi / 2, towards=0.0)


def crossbow(m):
    """A crossbow laid across two pegs: its stock and butt, its steel prod, the string drawn back to the nut, the
    stirrup at its head, the trigger lever under it."""
    (ax, az), (bx, bz) = PEGS["crossbow"]
    low = _peg_top(ax, az)
    y = HANG_Y
    box(m, (-0.6, y - 0.025, low), (0.3, y + 0.025, low + 0.06), "wood", r=0.012)
    box(m, (-0.7, y - 0.03, low - 0.02), (-0.6, y + 0.03, low + 0.09), "wood", r=0.015)
    z0 = low + 0.03
    pipe(m, [(0.27, y, z0 - 0.2), (0.315, y, z0 - 0.1), (0.33, y, z0), (0.315, y, z0 + 0.1), (0.27, y, z0 + 0.2)], 0.017, 8,
         "steel")
    pipe(m, [(0.27, y - 0.032, z0 - 0.19), (-0.05, y - 0.032, z0), (0.27, y - 0.032, z0 + 0.19)], 0.013, 6, "paper_kraft")
    _wall_ring(m, (0.39, y, z0), 0.045, 0.012, "xz", "steel")
    box(m, (-0.25, y - 0.012, low - 0.07), (-0.21, y + 0.012, low), "steel", r=0.0)


def sword_cane(m):
    """His sword cane across two pegs, its silver knob, a hand's breadth of its blade drawn from the shaft."""
    (ax, az), _ = PEGS["sword_cane"]
    zc = _peg_top(ax, az) + 0.016
    y = HANG_Y
    turned(m, [(0.022, 0.0), (0.03, 0.03), (0.03, 0.07), (0.022, 0.1)], 12, "silver", at=(-0.82, y, zc), lean=math.pi / 2,
           towards=math.pi / 2)
    box(m, (-0.72, y - 0.006, zc - 0.01), (-0.62, y + 0.006, zc + 0.01), "steel", r=0.0)
    turned(m, [(0.018, 0.0), (0.016, 0.03), (0.016, 1.01), (0.018, 1.04)], 8, "wood", at=(-0.62, y, zc), lean=math.pi / 2,
           towards=math.pi / 2)
    turned(m, [(0.018, 0.0), (0.018, 0.05)], 8, "brass", at=(0.42, y, zc), lean=math.pi / 2, towards=math.pi / 2)


def stakes(m):
    """Three stakes whittled six-sided from ash, their points shod in silver, bound with a strap looped over a peg."""
    px, pz = PEGS["stakes"][0]
    y = HANG_Y
    # (Turned so no side of a stake lies square to the strap's: they would lie too near each other.)
    twist = math.radians(-15.0)
    for dx in (-0.06, 0.0, 0.06):
        turned(m, [(0.025, 1.3), (0.025, 1.52)], 6, "wood", at=(px + dx, y, 0.0), twist=twist)
        _spike(m, (px + dx, y, 1.3), 0.025, 6, 0.06, twist, "silver")
    box(m, (px - 0.1, y - 0.035, 1.44), (px + 0.1, y + 0.035, 1.47), "leather_old", r=0.0)
    top = _peg_top(px, pz) + 0.007
    _band(m, [(px - 0.05, y, 1.47), (px - 0.035, y, top - 0.04), (px, y, top), (px + 0.035, y, top - 0.04), (px + 0.05, y, 1.47)],
          0.03, 0.016, (0.0, 1.0, 0.0), "leather_old")


def bandolier(m):
    """A bandolier of holy-water phials hung in a loop on its peg, a phial in each loop down both its sides."""
    px, pz = PEGS["bandolier"][0]
    top = _peg_top(px, pz) + 0.02
    y = HANG_Y
    loop = [(px, top), (px + 0.05, top - 0.03), (px + 0.08, top - 0.12), (px + 0.09, top - 0.27), (px + 0.07, top - 0.36),
            (px, top - 0.39), (px - 0.07, top - 0.36), (px - 0.09, top - 0.27), (px - 0.08, top - 0.12), (px - 0.05, top - 0.03)]
    _wall_loop(m, loop, 0.045, 0.014, y, "leather_old")
    front = y - 0.007 - 0.019
    for x, z in ((px + 0.085, top - 0.2), (px + 0.088, top - 0.31), (px - 0.085, top - 0.2), (px - 0.088, top - 0.31)):
        turned(m, [(0.019, 0.0), (0.019, 0.06)], 8, "glass", at=(x, front, z - 0.03))
        turned(m, [(0.017, 0.0), (0.017, 0.02)], 8, "paper_kraft", at=(x, front, z + 0.03))


def chains(m):
    """A length of chain hung from its peg, its links alternately in the wall's plane and across it."""
    px, pz = PEGS["chains"][0]
    y = HANG_Y
    r, t = 0.035, 0.013
    centre = _peg_top(px, pz) - (r - t)
    for k in range(6):
        _wall_ring(m, (px, y, centre - 0.05 * k), r, t, "xz" if k % 2 == 0 else "yz", "steel")


def revolver(m):
    """A heavy revolver hung by its trigger guard: its frame, cylinder and barrel hanging down, its grip up and back."""
    px, pz = PEGS["revolver"][0]
    y = HANG_Y
    guard = _peg_top(px, pz) - (0.032 - 0.013)
    _wall_ring(m, (px, y, guard), 0.032, 0.013, "xz", "steel")
    box(m, (px - 0.035, y - 0.016, guard - 0.13), (px + 0.045, y + 0.016, guard - 0.035), "steel", r=0.0)
    # (Twelve-sided and untwisted, so no side of it lies square to the frame's; its ends over 3 cm from the
    # frame's.)
    turned(m, [(0.034, 0.0), (0.034, 0.065)], 12, "steel", at=(px + 0.005, y, guard - 0.165))
    pipe(m, [(px + 0.005, y, guard - 0.165), (px + 0.005, y, guard - 0.33)], 0.016, 8, "steel")
    # The grip beside the frame, up and back (beside it, not over it: their faces would lie too near).
    box(m, (px + 0.045, y - 0.015, guard - 0.09), (px + 0.082, y + 0.015, guard + 0.03), "wood", r=0.0)


def rounds(m):
    """A box of his engraved rounds on the rack's shelf (its label the user's), three stood out in front of it."""
    x0, x1, top = SHELF
    box(m, (0.7, WALL_Y - 0.155, top), (0.84, WALL_Y - 0.085, top + 0.055), "paper_kraft", r=0.0)
    for x in (0.7, 0.76, 0.82):
        turned(m, [(0.017, 0.0), (0.017, 0.035), (0.016, 0.05)], 8, "brass", at=(x, WALL_Y - 0.18, top + 0.017),
               lean=math.pi / 2, towards=math.pi / 2)


def trap_jaws(m):
    """The jaws of a great trap hung as a trophy over his rack: open, toothed all round, the trigger plate between
    them, hung by a ring and a short chain."""
    px, pz = PEGS["trap_jaws"][0]
    y = HANG_Y
    ring = _peg_top(px, pz) - (0.035 - 0.013)
    _wall_ring(m, (px, y, ring), 0.035, 0.013, "xz", "steel")
    _wall_ring(m, (px, y, ring - 0.05), 0.035, 0.013, "yz", "steel")
    r = 0.15
    zc = ring - 0.075 - r
    for start in (0.0, math.pi):
        arc = [(px + r * math.cos(start + math.pi * k / 10), y, zc + r * math.sin(start + math.pi * k / 10)) for k in range(11)]
        pipe(m, arc, 0.017, 8, "steel")
    for k in range(16):
        a = 2 * math.pi * (k + 0.5) / 16
        c = (px + 0.12 * math.cos(a), y, zc + 0.12 * math.sin(a))
        box(m, (c[0] - 0.017, c[1] - 0.012, c[2] - 0.01), (c[0] + 0.017, c[1] + 0.012, c[2] + 0.01), "steel", r=0.0,
            turn=(0.0, -a, 0.0))
    turned(m, [(0.06, 0.0), (0.06, 0.014)], 14, "steel", at=(px, y + 0.007, zc), lean=math.pi / 2, towards=0.0)
    for side in (-1, 1):
        box(m, (px + side * r - 0.025, y - 0.02, zc - 0.025), (px + side * r + 0.025, y + 0.02, zc + 0.025), "steel", r=0.0)


# --- the work in progress ----------------------------------------------------------------------------------

# The book he is working on, chained and nailed shut on a rest bolted to the desk's left end: its middle, its
# width (spine to fore-edge, along x), length (along y), the height of its pages and of its cover.
CHAINED_AT = (-1.06, 0.0)
CHAINED = (0.24, 0.32, 0.045, 0.014)
REST = (-1.32, -0.8, -0.22, 0.22)
# The staple the chain is locked to: on the cover's top by its fore-edge (x from the book's middle, its middle's
# height over the cover).
STAPLE = (CHAINED[0] / 2 - 0.04, 0.036)
# Where the chain is bolted to the desk's top (its front-left rim, clear of the Rituale): a good run of chain
# from the book to it.
DESK_RING = (-0.76, -0.31)
# The quarantine cage against the back wall left of the rack: x from, to; its depth and height; its shelves' tops.
CAGE = (-2.35, -1.35, 0.45, 1.85)
CAGE_SHELVES = (0.1, 0.655, 1.215)
CAGE_BAR_Y = WALL_Y - CAGE[2] + 0.015
CAGE_BAR_Z = (0.18, 1.72)
CAGE_BARS = [((x - 0.015, x + 0.015), (CAGE_BAR_Y - 0.015, CAGE_BAR_Y + 0.015), CAGE_BAR_Z)
             for x in [CAGE[0] + 0.08 + 0.093 * k for k in range(10)]]
# The books in quarantine: (shelf, x, thickness, width, height, lean in degrees), each its own object.
QUARANTINE = [(0, -2.22, 0.07, 0.24, 0.33, 0.0), (0, -2.1, 0.06, 0.22, 0.3, 6.0), (0, -1.72, 0.08, 0.26, 0.34, -4.0),
              (1, -2.15, 0.065, 0.23, 0.29, 0.0), (1, -1.6, 0.07, 0.25, 0.32, 8.0), (2, -2.0, 0.06, 0.21, 0.27, -6.0),
              (2, -1.75, 0.075, 0.24, 0.3, 0.0)]


def _book_section(w, h, lip):
    """A book's section across its spine (u from the spine to the fore-edge, v up its thickness), its boards
    overhanging the pages' fore-edge by `lip`, its spine rounded; and each edge's part (cover or pages)."""
    outline = [(0.012, 0.0), (w, 0.0), (w, lip), (w - lip, lip), (w - lip, h - lip), (w, h - lip), (w, h), (0.012, h),
               (0.004, h * 0.8), (0.0, h * 0.5), (0.004, h * 0.2)]
    parts = ["cover", "cover", "cover", "pages", "cover", "cover", "cover", "cover", "cover", "cover", "cover"]
    return outline, parts


def chained_book_rest(m):
    """A stout rest bolted to the desk's left end, iron brackets under it, where the chained book lies."""
    x0, x1, y0, y1 = REST
    box(m, (x0, y0, 0.98 + 0.035), (x1, y1, DESK_TOP), "wood", r=0.015)
    for y in (y0 + 0.06, y1 - 0.06):
        box(m, (x0 + 0.14, y - 0.02, 0.8), (-DESK_W + 0.04, y + 0.02, 0.98 + 0.035), "steel", r=0.0)


def chained_book_block(m):
    """The chained book's pages on its lower board: its section lofted along it, its spine to -x."""
    cx, cy = CHAINED_AT
    w, length, h, _ = CHAINED
    outline = [(0.012, 0.0), (w, 0.0), (w, 0.011), (w - 0.011, 0.011), (w - 0.011, h), (0.012, h), (0.004, h * 0.75),
               (0.0, h * 0.45), (0.004, h * 0.15)]
    slots = ["leather_old", "leather_old", "leather_old", "paper", "paper", "leather_old", "leather_old", "leather_old",
             "leather_old"]
    z = DESK_TOP + LIFT
    rings = [[(cx - w / 2 + u, cy + y, z + v) for u, v in outline] for y in (-length / 2, length / 2)]
    m.shell()
    shapes.loft(m, rings, slots, cap_slot="paper")


def chained_book_cover(m):
    """Its upper board, shut on it and nailed through with iron, a staple at its fore-edge for the chain; it lifts
    on its hinge along the spine (the hinge's ends are its wicks, for the bay)."""
    cx, cy = CHAINED_AT
    w, length, h, t = CHAINED
    z = DESK_TOP + LIFT + h
    box(m, (cx - w / 2, cy - length / 2, z), (cx + w / 2, cy + length / 2, z + t), "leather_old", r=0.0)
    for dx, dy in ((-0.08, -0.12), (0.08, -0.12), (-0.08, 0.12), (0.08, 0.12), (0.0, 0.0)):
        underground_shapes.stud(m, (cx + dx, cy + dy, z + t), 0.0, 0.0, "steel", r=0.022)
    sx, sz = STAPLE
    _link(m, (cx + sx, cy, z + t + sz), (1, 0, 0), (0, 0, 1), 0.035, 0.013, "steel")
    m.wick((cx - w / 2, cy - length / 2, z))
    m.wick((cx - w / 2, cy + length / 2, z))


def _link(m, centre, e1, e2, radius, tube, slot, steps=8, sides=6):
    """A ring of tube (a chain's link) about `centre` in the plane of `e1`, `e2`: a torus built straight from its
    axes, so no seam twists its faces thin however it is turned."""
    c, e1, e2 = Vector(centre), Vector(e1).normalized(), Vector(e2).normalized()
    n = e1.cross(e2).normalized()

    def at(i, j):
        t, f = 2 * math.pi * i / steps, 2 * math.pi * j / sides
        out = e1 * math.cos(t) + e2 * math.sin(t)
        return tuple(c + out * (radius + tube * math.cos(f)) + n * tube * math.sin(f))

    m.shell()
    for i in range(steps):
        for j in range(sides):
            m.face([at(i, j), at(i + 1, j), at(i + 1, j + 1), at(i, j + 1)], slot)


def _chain(m, points, radius, tube, pitch, slot):
    """Links along the polyline `points`, `pitch` apart, each turned a quarter from the last."""
    pts = [Vector(q) for q in points]
    places = []
    for a, b in zip(pts, pts[1:]):
        n = max(1, round((b - a).length / pitch))
        places += [(a + (b - a) * (k / n), (b - a).normalized()) for k in range(n)]
    places.append((pts[-1], (pts[-1] - pts[-2]).normalized()))

    for k, (c, d) in enumerate(places):
        side = d.cross(Vector((0, 0, 1)))
        side = side.normalized() if side.length > 1e-4 else Vector((1, 0, 0))
        across = side if k % 2 == 0 else d.cross(side).normalized()
        _link(m, c, d, across, radius, tube, slot)


def chained_book_chain(m):
    """The chain from the book's staple across to a ring bolted on the desk's top, sagging between; a padlock on it
    by the book."""
    cx, cy = CHAINED_AT
    w, length, h, t = CHAINED
    staple = Vector((cx + STAPLE[0], cy, DESK_TOP + LIFT + h + t + STAPLE[1]))
    rx, ry = DESK_RING
    box(m, (rx - 0.035, ry - 0.035, DESK_TOP), (rx + 0.035, ry + 0.035, DESK_TOP + 0.012), "steel", r=0.0)
    ring = Vector((rx, ry, DESK_TOP + 0.012 + 0.035))
    _link(m, ring, (1, 0, 0), (0, 0, 1), 0.035, 0.013, "steel")
    start = staple + Vector((0.035, 0, 0))
    end = ring + Vector((-0.035, 0, 0))
    sag = (start + end) / 2 + Vector((0, 0, -0.03))
    _chain(m, [start, sag, end], 0.035, 0.013, 0.05, "steel")
    # (Its two ends, the desk's ring and the book's staple, are its wicks: the bay swings it after the staple.)
    m.wick(tuple(ring))
    m.wick(tuple(staple))
    # The padlock hung from a link at the sag.
    lock = sag + Vector((0.0, 0.0, -0.065))
    box(m, (lock.x - 0.022, lock.y - 0.013, lock.z - 0.03), (lock.x + 0.022, lock.y + 0.013, lock.z + 0.02), "brass", r=0.0)


def quarantine_cage(m):
    """The quarantine cage behind him: a heavy cabinet against the back wall, its front barred in iron and padlocked;
    inside, on its shelves, the books still waiting to be exorcised."""
    x0, x1, depth, height = CAGE
    back = WALL_Y
    front = WALL_Y - depth
    # (Every panel and rail over 3 cm through: thinner, their faces would lie too near each other.)
    t = 0.035
    box(m, (x0, back - t, 0.0), (x1, back, height), "wood", r=0.0)
    for sx0, sx1 in ((x0, x0 + 0.04), (x1 - 0.04, x1)):
        box(m, (sx0, front, 0.0), (sx1, back - t, height), "wood", r=0.0)
    box(m, (x0 + 0.04, front, 0.0), (x1 - 0.04, back - t, CAGE_SHELVES[0]), "wood", r=0.0)
    box(m, (x0 + 0.04, front, height - 0.05), (x1 - 0.04, back - t, height), "wood", r=0.0)
    for top in CAGE_SHELVES[1:]:
        box(m, (x0 + 0.04, front + 0.04, top - 0.035), (x1 - 0.04, back - t, top), "wood", r=0.0)
    # The barred front: its iron rails and the bars between them.
    box(m, (x0 + 0.04, front, CAGE_BAR_Z[1]), (x1 - 0.04, front + t, height - 0.05), "steel", r=0.0)
    box(m, (x0 + 0.04, front, CAGE_SHELVES[0]), (x1 - 0.04, front + t, CAGE_BAR_Z[0]), "steel", r=0.0)
    for (bx0, bx1), _, (bz0, bz1) in CAGE_BARS:
        bx = (bx0 + bx1) / 2
        pipe(m, [(bx, CAGE_BAR_Y, bz0), (bx, CAGE_BAR_Y, bz1)], 0.015, 8, "steel")
    # The hasp and its padlock.
    box(m, (x1 - 0.08, front - 0.012, 0.95), (x1 - 0.04, front, 1.05), "steel", r=0.0)
    box(m, (x1 - 0.085, front - 0.04, 0.88), (x1 - 0.035, front - 0.012, 0.95), "brass", r=0.0)


def _quarantine_book(k):
    """One of the books in quarantine standing on its shelf, its spine to the bars: its section lofted up its
    height, leaning as it was left."""
    shelf, x, thick, width, height, lean = QUARANTINE[k]

    def book(m):
        outline, parts = _book_section(width, thick, 0.011)
        slots = ["leather_old" if part == "cover" else "paper" for part in parts]
        front = WALL_Y - CAGE[2] + 0.05
        z0 = CAGE_SHELVES[shelf] + LIFT
        tip = math.radians(lean)
        pivot = (x + (thick / 2 if lean > 0 else -thick / 2), z0)

        def place(u, v, h):
            # The section's u back from the spine (toward the wall), v across its thickness; h up it; then leant.
            px, pz = x - thick / 2 + v, z0 + h
            dx, dz = px - pivot[0], pz - pivot[1]
            return (pivot[0] + dx * math.cos(tip) + dz * math.sin(tip), front + u, pivot[1] - dx * math.sin(tip) + dz * math.cos(tip))

        rings = [[place(u, v, h) for u, v in outline] for h in (0.0, height)]
        m.shell()
        shapes.loft(m, rings, slots, cap_slot="paper")

    book.__name__ = "quarantine_book_%d" % k
    return book


DEALER = [desk, desk_chair, lamp, ledger, magnifier, gloves, repair_kit, coat_hook]
RITE = [rituale, stole, crucifix, aspergillum, salt_tin, oil_phial, reliquary, benedict_medal]
HUNT = [hunt_rack, crossbow, sword_cane, stakes, bandolier, chains, revolver, rounds, trap_jaws]
WORK = [chained_book_rest, chained_book_block, chained_book_cover, chained_book_chain, quarantine_cage] \
    + [_quarantine_book(k) for k in range(len(QUARANTINE))]


def build():
    common.reset()
    underground_shapes.rng = rng
    rng.seed(1897)

    for f in DEALER + RITE + HUNT + WORK:
        smooth_object(f.__name__, f)


def main():
    build()
    common.export_piece(NAME, ATLAS, SLOTS, out=common.ROOT / "assets" / "eclipse" / "kit", sets_each=True, budget=6000)


if __name__ == "__main__":
    main()
