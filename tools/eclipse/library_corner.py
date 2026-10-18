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


DEALER = [desk, desk_chair, lamp, ledger, magnifier, gloves, repair_kit, coat_hook]
RITE = [rituale, stole, crucifix, aspergillum, salt_tin, oil_phial, reliquary, benedict_medal]


def build():
    common.reset()
    underground_shapes.rng = rng
    rng.seed(1897)

    for f in DEALER + RITE:
        smooth_object(f.__name__, f)


def main():
    build()
    common.export_piece(NAME, ATLAS, SLOTS, out=common.ROOT / "assets" / "eclipse" / "kit", sets_each=True, budget=6000)


if __name__ == "__main__":
    main()
