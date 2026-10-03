"""Rooms lived and worked in (kit v1): the harbourmaster's office and the
customs house's hall and store, the carrack's great cabin. A writing desk
heaped with ledgers, an armchair, a cabinet of pigeonholes full of rolled
papers, shelves of ledgers, a chart table and a sea chart on the wall, a
globe, a clerk's standing desk, a bench, a notice board; racked casks,
bolts of cloth, spice chests, olive jars; a captain's box bed, his sea
chest, a washstand, a rack of swords, a cloak and hat on their pegs, his
instruments spread on his chart. Each about its own middle, its foot on
the floor; colliders on what a man walks into, none on what sits on a
table. Pure data, as kit_recipes (which imports this at its end).
"""

import math

import kit_recipes as k
import kit_shapes as ks

TOP = 0.84


def col(cx, cy, cz, sx, sy, sz, yaw=0.0, surface="wood"):
    return [cx, cy, cz, sx, sy, sz, surface, yaw, 0.0, 0.0]


def _prop(name, slot, shapes, cols, size, budget=600):
    k.piece(name, "dressing", slot, "wood", [], cols=cols, size=size)
    k.model(name, shapes)
    k.PIECES[name]["budget"] = budget
    # (A room's furniture stands under its roof: kit_recipes.roofed.)
    k.PIECES[name]["roofed"] = True


def _legs(w, d, h, inset=0.06, thick=0.07, slot="wood_old"):
    return [ks.box(sx * (w / 2.0 - inset), h / 2.0, sz * (d / 2.0 - inset), thick, h, thick, slot) for sx in (-1.0, 1.0) for sz in (-1.0, 1.0)]


def _book(x, y, z, w, h, d, slot="leather", yaw=0.0, lean=0.0):
    return ks.box(x, y + h / 2.0, z, w, h, d, slot, yaw, 0.0, lean)


def _candle(x, y, z, height=0.14):
    return [ks.lathe(x, y, z, [[0.05, 0.0], [0.06, 0.01], [0.02, 0.03], [0.02, 0.04]], 6, "brass"),
            ks.prism(x, y + 0.04 + height / 2.0, z, 0.016, height, 6, "wax")]


def _papers(x, y, z, n, rng_seed):
    out = []

    for i in range(n):
        a = (rng_seed * 37 + i * 53) % 40 - 20
        out.append(ks.card(x + (i - n / 2.0) * 0.06, y + 0.003 + i * 0.002, z + ((i * 7) % 5 - 2) * 0.03, 0.21, 0.3, "parchment", float(a), -90.0))

    return out


# The harbourmaster's office

def _desk():
    """A writing desk (its front +z): pedestals of drawers, the top, a
    ledger open on it, more stacked, papers, an inkwell and quill, a seal,
    a sand box, a candle."""
    w, d = 1.8, 0.85
    shapes = [ks.box(0.0, TOP - 0.03, 0.0, w, 0.06, d, "wood_old")]

    for sx in (-1.0, 1.0):
        x = sx * (w / 2.0 - 0.25)
        shapes.append(ks.box(x, (TOP - 0.06) / 2.0, 0.0, 0.48, TOP - 0.06, d - 0.06, "wood_old"))

        for j in range(3):
            y = 0.12 + j * 0.24
            shapes.append(ks.box(x, y + 0.1, d / 2.0 - 0.02, 0.42, 0.2, 0.02, "timber"))
            shapes.append(ks.box(x, y + 0.1, d / 2.0 + 0.0, 0.06, 0.03, 0.03, "brass"))

    shapes.append(ks.box(0.0, TOP - 0.14, -d / 2.0 + 0.04, w - 1.0, 0.2, 0.03, "wood_old"))
    # The open ledger, its two pages raised a little at the spine.
    shapes += [ks.card(-0.17, TOP + 0.015, 0.05, 0.32, 0.42, "parchment", 0.0, -84.0), ks.card(0.17, TOP + 0.015, 0.05, 0.32, 0.42, "parchment", 0.0, -96.0),
               ks.box(0.0, TOP + 0.006, 0.05, 0.7, 0.012, 0.46, "leather")]
    # Stacked ledgers, a heap of papers, the inkwell and quill, the seal.
    shapes += [_book(-0.7, TOP, -0.2, 0.34, 0.07, 0.45), _book(-0.69, TOP + 0.07, -0.21, 0.32, 0.06, 0.43, "cloth", 8.0),
               _book(-0.7, TOP + 0.13, -0.2, 0.3, 0.08, 0.4, "leather", -6.0), _book(0.72, TOP, -0.22, 0.3, 0.05, 0.4, "leather", 20.0)]
    shapes += _papers(0.55, TOP, 0.12, 4, 3)
    shapes += [ks.prism(0.36, TOP + 0.04, -0.22, 0.05, 0.08, 6, "pewter"), ks.box(0.39, TOP + 0.16, -0.22, 0.01, 0.26, 0.04, "feather", 0.0, 0.0, -25.0),
               ks.prism(0.5, TOP + 0.05, -0.28, 0.03, 0.1, 6, "brass"), ks.lathe(0.5, TOP + 0.1, -0.28, [[0.04, 0.0], [0.04, 0.02], [0.0, 0.03]], 6, "brass"),
               ks.box(0.22, TOP + 0.03, -0.28, 0.12, 0.06, 0.08, "wood_old")]
    shapes += _candle(-0.35, TOP, -0.28)
    return shapes, [col(0.0, TOP / 2.0, 0.0, w, TOP, d)]


def _armchair():
    """An armchair (facing +z): its seat in leather, its back, arms, legs."""
    s = 0.5
    shapes = _legs(0.56, 0.52, 0.46, thick=0.06) + [ks.box(0.0, 0.48, 0.0, 0.58, 0.06, 0.54, "wood_old"),
                                                     ks.box(0.0, 0.52, 0.02, 0.5, 0.04, 0.46, "leather"),
                                                     ks.box(0.0, 0.92, -0.26, 0.56, 0.8, 0.06, "wood_old"),
                                                     ks.box(0.0, 0.9, -0.225, 0.46, 0.6, 0.02, "leather")]

    for sx in (-1.0, 1.0):
        shapes += [ks.box(sx * 0.27, 0.68, 0.0, 0.06, 0.04, 0.5, "wood_old"), ks.box(sx * 0.27, 0.6, 0.22, 0.05, 0.16, 0.05, "wood_old")]

    shapes.append(ks.prism(0.0, 1.36, -0.26, 0.04, 0.08, 6, "brass"))
    return shapes, [col(0.0, 0.5, 0.0, 0.58, 1.0, 0.56)]


def _pigeonholes():
    """A tall cabinet of pigeonholes (its front +z) on a cupboard, rolled
    papers and bundles in its holes, a ledger lying on its top."""
    w, h, d = 1.4, 2.3, 0.45
    shapes = [ks.box(0.0, 0.45, 0.0, w, 0.9, d, "wood_old"), ks.box(0.0, 0.92, 0.0, w + 0.06, 0.04, d + 0.04, "timber")]

    for sx in (-1.0, 1.0):
        shapes.append(ks.box(sx * w / 4.0, 0.45, d / 2.0 + 0.01, w / 2.0 - 0.06, 0.78, 0.02, "timber"))
        shapes.append(ks.box(sx * 0.06, 0.5, d / 2.0 + 0.03, 0.04, 0.08, 0.02, "brass"))

    # The cabinet: back, sides, top, its grid; papers in its holes.
    top = h
    shapes += [ks.box(0.0, (0.94 + top) / 2.0, -d / 2.0 + 0.02, w, top - 0.94, 0.04, "timber"),
               ks.box(-w / 2.0 + 0.02, (0.94 + top) / 2.0, 0.0, 0.04, top - 0.94, d, "wood_old"),
               ks.box(w / 2.0 - 0.02, (0.94 + top) / 2.0, 0.0, 0.04, top - 0.94, d, "wood_old"),
               ks.box(0.0, top, 0.0, w + 0.08, 0.06, d + 0.06, "wood_old")]
    cols, rows = 5, 5
    cw, ch = (w - 0.04) / cols, (top - 0.96) / rows

    for i in range(1, cols):
        shapes.append(ks.box(-w / 2.0 + 0.02 + i * cw, (0.94 + top) / 2.0, 0.01, 0.02, top - 0.94, d - 0.06, "wood_old"))

    for j in range(1, rows):
        shapes.append(ks.box(0.0, 0.94 + j * ch, 0.01, w - 0.06, 0.02, d - 0.06, "wood_old"))

    for i in range(cols):
        for j in range(rows):
            if (i * 3 + j * 5) % 7 == 0:
                continue

            x, y = -w / 2.0 + 0.02 + (i + 0.5) * cw, 0.96 + j * ch
            n = 1 + (i + j) % 3

            for m in range(n):
                shapes.append(ks.prism(x - 0.06 + m * 0.06, y + 0.05, 0.05, 0.03, d - 0.12, 4, "parchment", 0.0, 90.0, 0.0))

    shapes.append(_book(0.2, top + 0.03, 0.0, 0.4, 0.08, 0.3))
    return shapes, [col(0.0, top / 2.0, 0.0, w, top, d)]


def _shelves():
    """Shelves of ledgers (front +z): four boards, rows of spines on each,
    a few leaning, a box and a bundle."""
    w, h, d = 1.8, 2.2, 0.4
    shapes = [ks.box(0.0, h / 2.0, -d / 2.0 + 0.02, w, h, 0.04, "timber")]

    for sx in (-1.0, 1.0):
        shapes.append(ks.box(sx * (w / 2.0 - 0.03), h / 2.0, 0.0, 0.06, h, d, "wood_old"))

    for j in range(5):
        y = 0.08 + j * 0.52
        shapes.append(ks.box(0.0, y, 0.0, w - 0.06, 0.04, d, "wood_old"))

        if j < 4:
            span = w - 0.5 if j % 2 == 0 else w - 0.3
            shapes.append(ks.card(-w / 2.0 + 0.06 + span / 2.0, y + 0.22, d / 2.0 - 0.06, span, 0.4, "book_spines"))
            shapes.append(ks.box(-w / 2.0 + 0.06 + span / 2.0, y + 0.2, -0.03, span, 0.36, d - 0.14, "leather"))
            shapes.append(_book(w / 2.0 - 0.2, y + 0.02, 0.0, 0.05, 0.34, 0.26, "cloth" if j % 2 else "leather", 0.0, 18.0))

    shapes.append(ks.box(w / 2.0 - 0.2, h + 0.1, 0.0, 0.3, 0.2, 0.25, "wood_old"))
    return shapes, [col(0.0, h / 2.0, 0.0, w, h, d)]


def _chart_table():
    """A chart table: a sea chart spread on it, held by weights, dividers
    and a rule on it."""
    w, d = 2.0, 1.1
    shapes = _legs(w, d, TOP - 0.05, thick=0.09) + [ks.box(0.0, TOP - 0.03, 0.0, w, 0.06, d, "wood_old"),
                                                     ks.box(0.0, 0.2, 0.0, w - 0.2, 0.04, d - 0.2, "wood_old")]
    shapes.append(ks.card(0.0, TOP + 0.004, 0.0, 1.5, 0.9, "sea_chart", 0.0, -90.0))

    for x, z in ((-0.72, -0.42), (0.72, 0.42), (-0.72, 0.42)):
        shapes.append(ks.box(x, TOP + 0.03, z, 0.08, 0.06, 0.08, "iron"))

    shapes += [ks.box(0.15, TOP + 0.012, 0.1, 0.02, 0.012, 0.3, "brass", 25.0), ks.box(0.2, TOP + 0.012, 0.12, 0.02, 0.012, 0.3, "brass", 40.0),
               ks.box(-0.3, TOP + 0.01, -0.15, 0.6, 0.01, 0.05, "wood_old", -15.0)]
    return shapes, [col(0.0, TOP / 2.0, 0.0, w, TOP, d)]


def _wall_chart():
    """A sea chart in a frame on a wall (its face +z, its back at z 0)."""
    w, h = 1.6, 1.1
    shapes = [ks.card(0.0, 0.0, 0.03, w, h, "sea_chart")]

    for x, y, sx, sy in ((0.0, h / 2.0, w + 0.1, 0.05), (0.0, -h / 2.0, w + 0.1, 0.05), (w / 2.0, 0.0, 0.05, h), (-w / 2.0, 0.0, 0.05, h)):
        shapes.append(ks.box(x, y, 0.025, sx, sy, 0.05, "wood_old"))

    return shapes, []


def _globe():
    """A terrestrial globe on its stand, its meridian ring of brass."""
    profile = [[0.0, -0.28], [0.14, -0.24], [0.24, -0.14], [0.28, 0.0], [0.24, 0.14], [0.14, 0.24], [0.0, 0.28]]
    shapes = [ks.lathe(0.0, 1.0, 0.0, profile, 10, "parchment"), ks.ring(0.0, 1.0, 0.0, 0.3, 0.33, 0.02, 0.0, 360.0, 12, "brass", 90.0),
              ks.lathe(0.0, 0.0, 0.0, [[0.24, 0.0], [0.24, 0.04], [0.05, 0.08], [0.04, 0.6], [0.09, 0.66], [0.12, 0.7]], 8, "wood_old")]

    for a in (0.0, 120.0, 240.0):
        shapes.append(ks.box(0.18 * math.cos(math.radians(a)), 0.03, 0.18 * math.sin(math.radians(a)), 0.3, 0.05, 0.06, "wood_old", -a))

    return shapes, [col(0.0, 0.6, 0.0, 0.5, 1.2, 0.5)]


def _rug(w, d):
    return [ks.card(0.0, 0.006, 0.0, w, d, "carpet", 0.0, -90.0)], []


# The hall and the store

def _clerk_desk():
    """A clerk's standing desk, its slope with an open ledger, a stool by it."""
    shapes = _legs(1.2, 0.6, 1.05, thick=0.07) + [ks.slab([[-0.6, 1.2, -0.3], [0.6, 1.2, -0.3], [0.6, 1.05, 0.3], [-0.6, 1.05, 0.3]], 0.04,
                                                           "wood_old"),
                                                   ks.box(0.0, 0.3, 0.0, 1.1, 0.04, 0.5, "wood_old")]
    shapes += [ks.card(-0.15, 1.15, 0.02, 0.28, 0.4, "parchment", 0.0, -76.0), ks.card(0.15, 1.15, 0.02, 0.28, 0.4, "parchment", 0.0, -76.0)]
    shapes += [ks.prism(0.0, 0.33, 0.75, 0.2, 0.06, 8, "wood_old")] + [ks.box(0.0 + 0.12 * math.cos(math.radians(a)), 0.15, 0.75 + 0.12 * math.sin(math.radians(a)),
                                                                              0.04, 0.3, 0.04, "wood_old") for a in (0.0, 120.0, 240.0)]
    return shapes, [col(0.0, 0.6, 0.0, 1.2, 1.2, 0.6)]


def _bench():
    shapes = _legs(2.0, 0.4, 0.42, thick=0.07) + [ks.box(0.0, 0.44, 0.0, 2.0, 0.05, 0.4, "wood_old"), ks.box(0.0, 0.2, 0.0, 1.8, 0.04, 0.05, "wood_old")]
    return shapes, [col(0.0, 0.23, 0.0, 2.0, 0.46, 0.4)]


def _notices():
    """A notice board (its face +z, back at 0): the king's tariffs and the
    seized ships' names pinned to it."""
    shapes = [ks.box(0.0, 0.0, 0.02, 1.4, 1.0, 0.04, "wood_old")]

    for i, (x, y, a) in enumerate(((-0.4, 0.2, 3.0), (0.05, 0.25, -4.0), (0.45, 0.15, 6.0), (-0.3, -0.25, -2.0), (0.25, -0.22, 5.0))):
        shapes.append(ks.card(x, y, 0.045 + i * 0.002, 0.3, 0.4, "parchment", 0.0, 0.0))
        shapes[-1]["turn"][2] = a

    return shapes, []


def _cask_rack():
    """A rack of casks on their sides, two tiers (its long side along x)."""
    shapes = []

    for x in (-1.5, 0.0, 1.5):
        shapes += [ks.box(x, 0.06, 0.0, 0.12, 0.12, 1.4, "beam"), ks.box(x, 0.86, 0.0, 0.12, 0.12, 1.4, "beam")]

    for x in (-1.5, 1.5):
        for z in (-0.6, 0.6):
            shapes.append(ks.box(x, 0.8, z, 0.12, 1.6, 0.12, "beam"))

    for tier, y in enumerate((0.48, 1.28)):
        for x in (-0.95, 0.0, 0.95):
            shapes.append(ks.prism(x, y, 0.0, 0.36 if tier == 0 else 0.32, 1.2, 8, "wood_old", 0.0, 90.0, 0.0,
                                   rings=[[0.5, 0.4 if tier == 0 else 0.36]]))
            shapes.append(ks.disc(x, y, 0.61, 0.33 if tier == 0 else 0.29, 8, "wood_old"))
            shapes.append(ks.prism(x, y, 0.62, 0.04, 0.04, 6, "timber", 0.0, 90.0, 0.0))

    return shapes, [col(0.0, 0.8, 0.0, 3.2, 1.6, 1.4)]


def _cloth_bolts():
    """Shelves of seized cloth (front +z): bolts lying in colours, a few
    standing."""
    shapes = [ks.box(0.0, 1.0, -0.3, 2.4, 2.0, 0.04, "timber")]

    for sx in (-1.0, 1.0):
        shapes.append(ks.box(sx * 1.17, 1.0, 0.0, 0.06, 2.0, 0.64, "wood_old"))

    slots = ["cloth", "burlap", "sailcloth", "carpet", "laundry", "leather"]

    for j, y in enumerate((0.1, 0.75, 1.4)):
        shapes.append(ks.box(0.0, y, 0.0, 2.3, 0.04, 0.6, "wood_old"))

        for i in range(6):
            r = 0.12 + (i * 7 + j * 3) % 4 * 0.015
            shapes.append(ks.prism(-0.95 + i * 0.38, y + 0.02 + r, 0.0, r, 0.56, 8, slots[(i + j * 2) % len(slots)], 0.0, 90.0, 0.0))

    shapes.append(ks.prism(0.6, 2.25, 0.0, 0.1, 0.5, 8, "cloth", 0.0, 0.0, 0.0))
    return shapes, [col(0.0, 1.0, 0.0, 2.4, 2.0, 0.64)]


def _spice_chests():
    """Chests of pepper and cloves from the Indies, iron-cornered, stacked,
    the king's seal on each."""
    shapes, cols = [], []

    for x, y, z, w, a in ((-0.5, 0.0, 0.0, 0.8, 4.0), (0.45, 0.0, 0.05, 0.8, -3.0), (0.0, 0.5, 0.02, 0.7, 8.0), (-0.45, 0.0, 0.75, 0.6, -10.0)):
        h = 0.5 if y == 0.0 else 0.4
        shapes.append(ks.box(x, y + h / 2.0, z, w, h, 0.55, "wood_old", a))

        for cx in (-1.0, 1.0):
            shapes.append(ks.box(x + cx * (w / 2.0 - 0.04), y + h / 2.0, z, 0.04, h + 0.01, 0.57, "iron", a))

        shapes.append(ks.disc(x, y + h / 2.0, z + 0.28, 0.06, 6, "cloth", a))

    cols.append(col(0.0, 0.45, 0.2, 1.8, 0.9, 1.3))
    return shapes, cols


def _jars():
    """Olive jars in a row in straw, one on its side."""
    shapes = []
    profile = [[0.08, 0.0], [0.2, 0.15], [0.24, 0.4], [0.2, 0.62], [0.08, 0.72], [0.07, 0.78], [0.09, 0.8]]

    for i in range(4):
        shapes.append(ks.lathe(-0.8 + i * 0.52, 0.0, 0.0, profile, 8, "clay"))

    shapes.append(ks.lathe(1.25, 0.24, 0.1, profile, 8, "clay", 0.0, 0.0, 90.0))
    shapes.append(ks.card(0.0, 0.02, 0.0, 2.6, 0.7, "straw", 0.0, -90.0))
    return shapes, [col(0.2, 0.4, 0.0, 2.6, 0.8, 0.5)]


# The great cabin

def _cot():
    """The captain's box bed (its open side +z): its frame and posts, the
    mattress, a pillow, the blanket, curtains drawn back."""
    w, d = 1.9, 0.95
    shapes = [ks.box(0.0, 0.2, 0.0, w, 0.4, d, "wood_old"), ks.box(0.0, 0.46, 0.0, w - 0.1, 0.12, d - 0.1, "sailcloth"),
              ks.box(-0.7, 0.56, 0.0, 0.35, 0.1, d - 0.25, "laundry"), ks.box(0.2, 0.53, 0.05, 1.2, 0.05, d - 0.05, "cloth", 0.0, 0.0, 1.0),
              ks.box(0.0, 1.6, 0.0, w + 0.06, 0.06, d + 0.06, "wood_old"), ks.box(0.0, 0.9, -d / 2.0 + 0.02, w, 1.4, 0.04, "timber")]

    for sx in (-1.0, 1.0):
        shapes.append(ks.box(sx * (w / 2.0 - 0.03), 0.8, d / 2.0 - 0.03, 0.06, 1.6, 0.06, "wood_old"))
        shapes.append(ks.box(sx * (w / 2.0 - 0.03), 0.8, -d / 2.0 + 0.03, 0.06, 1.6, 0.06, "wood_old"))
        shapes.append(ks.card(sx * (w / 2.0 - 0.18), 1.08, d / 2.0 + 0.01, 0.3, 1.0, "cloth"))

    return shapes, [col(0.0, 0.3, 0.0, w, 0.6, d)]


def _sea_chest():
    """A sea chest: its body, a rounded lid, iron bands, rope handles."""
    w, d, h = 1.0, 0.55, 0.5
    shapes = [ks.box(0.0, h / 2.0, 0.0, w, h, d, "wood_old"), ks.prism(0.0, h, 0.0, d / 2.0, w, 8, "wood_old", 0.0, 0.0, 90.0, caps=True)]
    shapes[-1]["radius"] = d / 2.0
    shapes.append(ks.box(0.0, h, 0.0, w + 0.01, 0.01, d, "wood_old"))

    for x in (-0.35, 0.35):
        shapes.append(ks.box(x, h / 2.0 + 0.05, 0.0, 0.05, h + 0.12, d + 0.02, "iron"))

    shapes.append(ks.box(0.0, h * 0.75, d / 2.0 + 0.01, 0.1, 0.12, 0.02, "iron"))

    for sx in (-1.0, 1.0):
        shapes.append(ks.ring(sx * (w / 2.0 + 0.03), h * 0.7, 0.0, 0.05, 0.07, 0.03, 180.0, 360.0, 4, "rope", 90.0))

    return shapes, [col(0.0, 0.35, 0.0, w, 0.7, d)]


def _washstand():
    shapes = _legs(0.6, 0.45, 0.8, thick=0.05) + [ks.box(0.0, 0.8, 0.0, 0.6, 0.04, 0.45, "wood_old"), ks.box(0.0, 0.25, 0.0, 0.54, 0.03, 0.4, "wood_old"),
                                                  ks.lathe(0.0, 0.82, 0.0, [[0.08, 0.0], [0.2, 0.08], [0.22, 0.1]], 8, "pewter", caps=False),
                                                  ks.lathe(0.15, 0.27, 0.05, [[0.07, 0.0], [0.1, 0.12], [0.06, 0.24], [0.05, 0.3], [0.07, 0.32]], 8, "pottery"),
                                                  ks.card(0.0, 1.35, -0.2, 0.4, 0.5, "glass_dark"), ks.box(0.0, 1.35, -0.21, 0.46, 0.56, 0.02, "brass")]
    return shapes, [col(0.0, 0.42, 0.0, 0.6, 0.84, 0.45)]


def _sword_rack():
    """Swords on a rack on a wall (face +z, back at 0): three blades in their
    scabbards, a buckler hung between."""
    shapes = [ks.box(0.0, 0.0, 0.03, 1.2, 0.1, 0.06, "wood_old"), ks.box(0.0, -0.6, 0.03, 1.2, 0.1, 0.06, "wood_old")]

    for x, a in ((-0.4, 6.0), (0.0, -4.0), (0.4, 3.0)):
        shapes += [ks.box(x, -0.25, 0.1, 0.05, 0.95, 0.03, "leather", 0.0, 0.0, a), ks.box(x, 0.32, 0.1, 0.22, 0.03, 0.03, "brass", 0.0, 0.0, a),
                   ks.box(x, 0.43, 0.1, 0.03, 0.2, 0.03, "leather", 0.0, 0.0, a), ks.prism(x, 0.55, 0.1, 0.03, 0.04, 6, "brass")]

    shapes.append(ks.lathe(0.0, -1.15, 0.08, [[0.0, 0.0], [0.2, 0.02], [0.25, 0.06]], 8, "iron", 0.0, 90.0))
    return shapes, []


def _cloak_pegs():
    """Pegs on a wall (face +z, back at 0): the captain's cloak and hat."""
    shapes = [ks.box(0.0, 0.0, 0.02, 0.8, 0.08, 0.04, "wood_old")]
    shapes += [ks.prism(x, 0.0, 0.07, 0.02, 0.1, 5, "wood_old", 0.0, 90.0, 0.0) for x in (-0.25, 0.25)]
    shapes += [ks.card(-0.25, -0.55, 0.12, 0.6, 1.1, "cloth"), ks.card(-0.25, -0.52, 0.14, 0.45, 1.0, "cloth", 8.0),
               ks.lathe(0.25, -0.02, 0.18, [[0.2, 0.0], [0.22, 0.02], [0.11, 0.04], [0.1, 0.14], [0.07, 0.16], [0.0, 0.17]], 8, "leather", 0.0, 70.0)]
    return shapes, []


def _instruments():
    """The captain's instruments on his chart: an astrolabe, an hourglass,
    dividers, the log open, the chart under them (on a table's top)."""
    shapes = [ks.card(0.0, 0.004, 0.0, 1.2, 0.8, "sea_chart", 0.0, -90.0),
              ks.ring(-0.3, 0.13, -0.15, 0.09, 0.12, 0.015, 0.0, 360.0, 10, "brass"), ks.box(-0.3, 0.13, -0.15, 0.2, 0.01, 0.01, "brass"),
              ks.box(-0.3, 0.27, -0.15, 0.01, 0.06, 0.01, "brass"),
              ks.lathe(0.35, 0.0, -0.2, [[0.05, 0.0], [0.06, 0.01], [0.05, 0.03], [0.01, 0.07], [0.05, 0.11], [0.06, 0.13], [0.05, 0.14]], 6, "glass_dark"),
              ks.box(0.33, 0.07, -0.2, 0.13, 0.14, 0.01, "wood_old"), ks.box(0.0, 0.006, 0.18, 0.02, 0.01, 0.3, "brass", 30.0),
              ks.card(0.3, 0.012, 0.22, 0.26, 0.36, "parchment", 10.0, -86.0), ks.card(0.55, 0.012, 0.22, 0.26, 0.36, "parchment", 10.0, -94.0)]
    return shapes, []


def _arms_hanging():
    """The king's arms on a hanging of red cloth from a rod (on a wall: its
    face +z, its back at 0, its rod's middle at the pivot)."""
    shapes = [ks.prism(0.0, 0.0, 0.06, 0.03, 1.3, 6, "brass", 0.0, 0.0, 90.0), ks.card(0.0, -0.8, 0.04, 1.0, 1.5, "cloth"),
              ks.card(0.0, -0.75, 0.06, 0.8, 0.8, "arms_royal")]
    shapes += [ks.lathe(sx * 0.68, 0.0, 0.06, [[0.0, -0.05], [0.05, 0.0], [0.0, 0.05]], 6, "brass", 0.0, 0.0, 90.0) for sx in (-1.0, 1.0)]
    return shapes, []


for _name, _maker, _slot, _size, _budget in (
        ("desk_writing", _desk, "wood_old", [1.9, 1.2, 0.9], 700), ("armchair", _armchair, "leather", [0.7, 1.45, 0.7], 400),
        ("cabinet_pigeonholes", _pigeonholes, "wood_old", [1.5, 2.5, 0.5], 900), ("shelves_ledgers", _shelves, "wood_old", [1.9, 2.4, 0.45], 500),
        ("chart_table", _chart_table, "wood_old", [2.1, 0.95, 1.2], 300), ("wall_chart", _wall_chart, "sea_chart", [1.8, 1.2, 0.2], 100),
        ("globe_stand", _globe, "wood_old", [0.7, 1.35, 0.7], 400), ("clerk_desk", _clerk_desk, "wood_old", [1.3, 1.3, 1.8], 300),
        ("bench_plain", _bench, "wood_old", [2.1, 0.5, 0.5], 200), ("notice_board", _notices, "parchment", [1.5, 1.1, 0.2], 100),
        ("cask_rack", _cask_rack, "wood_old", [3.3, 1.7, 1.5], 900), ("cloth_bolts", _cloth_bolts, "cloth", [2.5, 2.6, 0.7], 900),
        ("spice_chests", _spice_chests, "wood_old", [2.0, 1.0, 1.8], 300), ("olive_jars", _jars, "clay", [3.0, 0.9, 0.8], 700),
        ("cot_box", _cot, "wood_old", [2.0, 1.7, 1.1], 300), ("sea_chest", _sea_chest, "wood_old", [1.2, 0.8, 0.7], 300),
        ("washstand", _washstand, "wood_old", [0.7, 1.7, 0.6], 300), ("sword_rack", _sword_rack, "leather", [1.3, 1.6, 0.3], 300),
        ("cloak_pegs", _cloak_pegs, "cloth", [0.9, 1.3, 0.5], 200), ("captains_instruments", _instruments, "sea_chart", [1.3, 0.3, 0.9], 300),
        ("arms_hanging", _arms_hanging, "cloth", [1.5, 1.7, 0.2], 200)):
    _shapes, _cols = _maker()
    _prop(_name, _slot, _shapes, _cols, _size, _budget)

_shapes, _cols = _rug(3.0, 2.0)
_prop("rug_3", "carpet", _shapes, _cols, [3.1, 0.05, 2.1], 20)


# Small loose things (laid loose by the level: a body each, picked up and
# thrown): a book, a ledger, a candlestick, a jug, a tankard, a bottle, a
# plate, a bucket, a coffer, a mallet, an adze, a saw. Each its own small
# collider about its middle, its foot at the pivot.

def _small(name, slot, shapes, box, budget=120):
    w, h, d = box
    k.piece(name, "dressing", slot, "wood", [], cols=[col(0.0, h / 2.0, 0.0, w, h, d)], size=[w + 0.05, h + 0.05, d + 0.05])
    k.model(name, shapes)
    k.PIECES[name]["budget"] = budget


_small("book", "leather", [ks.box(0.0, 0.03, 0.0, 0.2, 0.06, 0.28, "leather"), ks.box(0.005, 0.03, 0.0, 0.18, 0.05, 0.27, "parchment")], (0.2, 0.06, 0.28))
_small("ledger", "leather", [ks.box(0.0, 0.045, 0.0, 0.3, 0.09, 0.42, "leather"), ks.box(0.008, 0.045, 0.0, 0.28, 0.075, 0.41, "parchment"),
                             ks.box(0.0, 0.045, -0.19, 0.31, 0.1, 0.04, "brass")], (0.31, 0.1, 0.42))
_small("candlestick", "brass", [ks.lathe(0.0, 0.0, 0.0, [[0.07, 0.0], [0.07, 0.02], [0.02, 0.05], [0.018, 0.2], [0.04, 0.22], [0.04, 0.24], [0.015, 0.25]], 8,
                                         "brass"), ks.prism(0.0, 0.31, 0.0, 0.016, 0.12, 6, "wax")], (0.14, 0.37, 0.14), budget=160)
_small("jug", "pottery", [ks.lathe(0.0, 0.0, 0.0, [[0.07, 0.0], [0.1, 0.06], [0.11, 0.14], [0.07, 0.24], [0.06, 0.27], [0.07, 0.29]], 8, "pottery"),
                          ks.box(0.11, 0.17, 0.0, 0.03, 0.12, 0.02, "pottery")], (0.24, 0.29, 0.22))
_small("tankard", "pewter", [ks.lathe(0.0, 0.0, 0.0, [[0.055, 0.0], [0.055, 0.14], [0.05, 0.14]], 8, "pewter", caps=False),
                             ks.disc(0.0, 0.005, 0.0, 0.055, 8, "pewter", pitch=-90.0), ks.box(0.07, 0.08, 0.0, 0.03, 0.09, 0.015, "pewter")], (0.15, 0.15, 0.12))
_small("bottle", "glass_dark", [ks.lathe(0.0, 0.0, 0.0, [[0.05, 0.0], [0.05, 0.16], [0.02, 0.22], [0.015, 0.28], [0.018, 0.29]], 8, "glass_dark")],
       (0.1, 0.29, 0.1))
_small("plate", "pewter", [ks.lathe(0.0, 0.0, 0.0, [[0.08, 0.0], [0.13, 0.015], [0.14, 0.02]], 10, "pewter", caps=False),
                           ks.disc(0.0, 0.002, 0.0, 0.08, 10, "pewter", pitch=-90.0)], (0.28, 0.03, 0.28))
_small("bucket", "wood_old", [ks.lathe(0.0, 0.0, 0.0, [[0.14, 0.0], [0.17, 0.3]], 8, "wood_old", caps=False),
                              ks.disc(0.0, 0.01, 0.0, 0.14, 8, "wood_old", pitch=-90.0), ks.disc(0.0, 0.22, 0.0, 0.155, 8, "glass_dark", pitch=-90.0),
                              ks.ring(0.0, 0.3, 0.0, 0.16, 0.175, 0.01, 0.0, 180.0, 6, "iron", 0.0)], (0.36, 0.32, 0.36))
_small("coffer", "wood_old", [ks.box(0.0, 0.12, 0.0, 0.42, 0.24, 0.28, "wood_old"), ks.box(0.0, 0.25, 0.0, 0.44, 0.04, 0.3, "wood_old"),
                              ks.box(0.0, 0.13, 0.145, 0.07, 0.08, 0.02, "brass")] +
       [ks.box(sx * 0.19, 0.13, 0.0, 0.03, 0.27, 0.3, "iron") for sx in (-1.0, 1.0)], (0.44, 0.27, 0.3))
_small("mallet", "wood_old", [ks.prism(0.0, 0.07, 0.0, 0.07, 0.24, 8, "wood_old", 0.0, 0.0, 90.0), ks.box(0.0, 0.05, 0.2, 0.03, 0.03, 0.34, "timber")],
       (0.26, 0.14, 0.5))
_small("adze", "iron", [ks.box(0.0, 0.02, 0.0, 0.03, 0.03, 0.62, "timber"), ks.box(0.0, 0.03, -0.32, 0.12, 0.05, 0.06, "iron", 0.0, 20.0, 0.0)],
       (0.13, 0.06, 0.68))
_small("hand_saw", "iron", [ks.box(0.0, 0.01, 0.0, 0.16, 0.01, 0.6, "iron"), ks.box(0.0, 0.02, 0.36, 0.1, 0.03, 0.16, "wood_old")], (0.17, 0.04, 0.78))
