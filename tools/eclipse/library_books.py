"""The rare-book librarian's books (docs/superpowers/specs/2026-10-17-librarian-shop-design.md;
docs/superpowers/refs/underground/recipe.md): the books his shelves are filled with, the stacks among them, and
the live book (the ones that open as the player comes near) in its parts; the lectern his spellbooks lie open on,
the table of novels by his door.

- book_<k>: twelve books standing (folio to octavo, thick and thin, leather, cloth and vellum), each its section
  lofted up its height: a rounded spine (some with gilt bands, some with a blank label (the user's title, painted on its aged paper)), the
  pages' fore-edge set back between the boards on the bigger ones. Each in its own frame: its spine's foot at
  y = 0 (toward the room), up z, its thickness across x.
- book_stack_<k>: three or four books lying one on another, a little askew.
- live_cover_back, live_block_right, live_block_left, live_cover_front, live_spine_back, live_spine_front,
  live_leaf: the live book lying shut, its boards from x = 0, its spine's two halves outside them (x < 0), its hinge
  line at LIVE_HINGE along the spine's outer face; opened about it, its front half (board, left pages, upper spine)
  lands flat beside the back half (the bay turns them; the leaves fan between).
- lectern, front_table.

    Blender -b --factory-startup --python tools/eclipse/library_books.py
"""

import math
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import common  # noqa: E402
import underground_shapes  # noqa: E402
from underground_shapes import box, smooth_object, turned  # noqa: E402

NAME = "library_books"
ATLAS = 4096
SLOTS = ["leather_red", "leather_brown", "leather_green", "leather_black", "cloth_blue", "vellum", "gilt", "page_edge",
         "paper", "label", "wood", "brass"]

rng = random.Random(1888)

# The books standing: (thickness, width spine to fore-edge, height, cover, a label on the spine, gilt bands).
BOOKS = [(0.065, 0.26, 0.37, "leather_brown", True, True), (0.05, 0.22, 0.29, "leather_red", True, True),
         (0.036, 0.16, 0.22, "cloth_blue", False, False), (0.09, 0.24, 0.31, "leather_green", True, True),
         (0.036, 0.2, 0.27, "leather_black", False, True), (0.055, 0.22, 0.28, "vellum", False, False),
         (0.06, 0.23, 0.3, "leather_red", False, True), (0.045, 0.19, 0.25, "leather_brown", True, False),
         (0.07, 0.25, 0.34, "leather_black", True, True), (0.04, 0.18, 0.24, "leather_green", False, True),
         (0.05, 0.21, 0.26, "cloth_blue", True, False), (0.075, 0.27, 0.36, "vellum", True, True)]
TALLEST = 0.38
# Books under this thick have no boards overhanging their pages (the overhang would lie too near the board's face).
LIP_FROM = 0.05
LIP = 0.011
# The live book shut: across (from its spine), along, thick; its spine's thickness; its hinge line's place (x, y, z),
# along the spine's outer face at the book's middle depth (opened, each half turns about it and lands flat beside
# the other, the spine's halves side by side under the gutter); its parts' depths.
LIVE_SIZE = (0.24, 0.32, 0.06)
LIVE_SPINE = 0.012
LIVE_HINGE = (-LIVE_SPINE, 0.0, 0.03)
LIVE_BOARD = 0.012
# The lectern's sloping desk (its middle, how far it slopes); the front table's top.
LECTERN_TOP = (0.0, 0.0, 1.08)
LECTERN_SLOPE = math.radians(20.0)
TABLE_TOP = 0.85


def _section(t, w):
    """A book's section across its spine, (u from the spine to the fore-edge, v across its thickness), and each
    edge's part: "cover", "pages" (the fore-edge) or "spine"."""
    if t >= LIP_FROM:
        outline = [(0.012, 0.0), (w, 0.0), (w, LIP), (w - LIP, LIP), (w - LIP, t - LIP), (w, t - LIP), (w, t), (0.012, t),
                   (0.004, t * 0.8), (0.0, t * 0.5), (0.004, t * 0.2)]
        parts = ["cover", "cover", "cover", "pages", "cover", "cover", "cover", "spine", "spine", "spine", "spine"]
    else:
        outline = [(0.012, 0.0), (w, 0.0), (w, t), (0.012, t), (0.004, t * 0.8), (0.0, t * 0.5), (0.004, t * 0.2)]
        parts = ["cover", "pages", "cover", "spine", "spine", "spine", "spine"]
    return outline, parts


def _loft(m, rings, slot_of, cap):
    """A closed solid through `rings` (each a loop of the same count), `slot_of(i, j)` the slot of the face between
    rings i and i + 1 along edge j; both ends capped `cap`."""
    m.shell()
    n = len(rings[0])
    m.face(list(reversed(rings[0])), cap)
    for i in range(len(rings) - 1):
        a, b = rings[i], rings[i + 1]
        for j in range(n):
            m.face([a[j], a[(j + 1) % n], b[(j + 1) % n], b[j]], slot_of(i, j))
    m.face(rings[-1], cap)


def _standing(k):
    t, w, h, cover, label, bands = BOOKS[k]

    def book(m):
        outline, parts = _section(t, w)
        # Its rows up its height: the gilt bands near its head and foot, the label between.
        rows = [0.0, h]
        if bands:
            rows += [0.03, 0.045, h - 0.045, h - 0.03]
        if label:
            rows += [h * 0.55, h * 0.72]
        rows = sorted(set(round(z, 4) for z in rows))
        rings = [[(v - t / 2, u, z) for u, v in outline] for z in rows]

        def slot_of(i, j):
            part = parts[j]
            if part == "pages":
                return "page_edge"
            if part == "cover":
                return cover
            lo, hi = rows[i], rows[i + 1]
            if bands and (abs(lo - 0.03) < 1e-4 or abs(lo - (h - 0.045)) < 1e-4):
                return "gilt"
            if label and abs(lo - round(h * 0.55, 4)) < 1e-4:
                return "label"
            return cover

        _loft(m, rings, slot_of, "page_edge")

    book.__name__ = "book_%d" % k
    return book


def _lying(m, at, t, w, length, yaw, cover):
    """A book lying shut (no overhang), its bottom's middle at `at`, its spine to its -x side, turned `yaw`."""
    outline = [(0.012, 0.0), (w, 0.0), (w, t), (0.012, t), (0.004, t * 0.8), (0.0, t * 0.5), (0.004, t * 0.2)]
    parts = [cover, "page_edge", cover, cover, cover, cover, cover]
    c, s = math.cos(yaw), math.sin(yaw)
    rings = []
    for y in (-length / 2, length / 2):
        ring = []
        for u, v in outline:
            x = u - w / 2
            ring.append((at[0] + c * x - s * y, at[1] + s * x + c * y, at[2] + v))
        rings.append(ring)
    _loft(m, rings, lambda i, j: parts[j], "page_edge")


STACKS = [[(0.06, 0.26, 0.33, 0.04, "leather_brown"), (0.05, 0.23, 0.3, -0.06, "leather_red"), (0.045, 0.2, 0.26, 0.1, "cloth_blue")],
          [(0.07, 0.27, 0.34, -0.03, "leather_black"), (0.055, 0.24, 0.31, 0.07, "vellum")],
          [(0.05, 0.25, 0.32, 0.02, "leather_green"), (0.045, 0.22, 0.29, -0.08, "leather_brown"),
           (0.04, 0.2, 0.25, 0.05, "leather_red"), (0.04, 0.18, 0.22, -0.02, "cloth_blue")]]


def _stack(k):
    def stack(m):
        z = 0.0
        for t, w, length, yaw, cover in STACKS[k]:
            _lying(m, (0.0, 0.0, z), t, w, length, yaw, cover)
            z += t

    stack.__name__ = "book_stack_%d" % k
    return stack


# --- the live book --------------------------------------------------------------------------------------------

def live_cover_back(m):
    w, length, _ = LIVE_SIZE
    box(m, (0.0, -length / 2, 0.0), (w, length / 2, LIVE_BOARD), "leather_black", r=0.0)


def live_block_right(m):
    w, length, t = LIVE_SIZE
    box(m, (0.004, -length / 2 + 0.005, LIVE_BOARD), (w - 0.008, length / 2 - 0.005, LIVE_HINGE[2]), "paper", r=0.0)


def live_block_left(m):
    w, length, t = LIVE_SIZE
    box(m, (0.004, -length / 2 + 0.005, LIVE_HINGE[2]), (w - 0.008, length / 2 - 0.005, t - LIVE_BOARD), "paper", r=0.0)


def live_cover_front(m):
    w, length, t = LIVE_SIZE
    box(m, (0.0, -length / 2, t - LIVE_BOARD), (w, length / 2, t), "leather_black", r=0.0)


def live_spine_back(m):
    """The spine's lower half, along the back half's height, outside the boards."""
    _, length, _ = LIVE_SIZE
    box(m, (-LIVE_SPINE, -length / 2, 0.0), (0.0, length / 2, LIVE_HINGE[2]), "leather_black", r=0.0)


def live_spine_front(m):
    """The spine's upper half, turning with the front board."""
    _, length, t = LIVE_SIZE
    box(m, (-LIVE_SPINE, -length / 2, LIVE_HINGE[2]), (0.0, length / 2, t), "leather_black", r=0.0)


def live_leaf(m):
    """One leaf, its edge on the hinge line (x = 0, z = 0 here; the bay hangs it at the hinge and fans it)."""
    w, length, _ = LIVE_SIZE
    box(m, (0.004, -length / 2 + 0.008, 0.0), (w - 0.012, length / 2 - 0.008, 0.012), "paper", r=0.0)


def lectern(m):
    """A reading stand for his spellbooks: a turned column on a round foot, a sloping desk with a ledge to hold the
    book."""
    turned(m, [(0.2, 0.0), (0.2, 0.03), (0.12, 0.06), (0.05, 0.1)], 16, "wood", at=(0.0, 0.0, 0.0))
    turned(m, [(0.04, 0.0), (0.04, 0.8), (0.06, 0.84), (0.06, 0.9)], 10, "wood", at=(0.0, 0.0, 0.1))
    cx, cy, cz = LECTERN_TOP
    box(m, (cx - 0.24, cy - 0.18, cz - 0.03), (cx + 0.24, cy + 0.18, cz), "wood", r=0.01, turn=(LECTERN_SLOPE, 0.0, 0.0))
    # Its ledge along the desk's low edge (toward the reader, -y).
    ly = cy - 0.18 * math.cos(LECTERN_SLOPE)
    lz = cz - 0.18 * math.sin(LECTERN_SLOPE)
    box(m, (cx - 0.24, ly - 0.035, lz - 0.02), (cx + 0.24, ly, lz + 0.03), "brass", r=0.0)


def front_table(m):
    """The table of novels just inside his door: a plain top on four turned legs, an apron under it."""
    w, d = 0.9, 0.5
    box(m, (-w / 2, -d / 2, TABLE_TOP - 0.04), (w / 2, d / 2, TABLE_TOP), "wood", r=0.015)
    box(m, (-w / 2 + 0.05, -d / 2 + 0.05, TABLE_TOP - 0.12), (w / 2 - 0.05, d / 2 - 0.05, TABLE_TOP - 0.04), "wood", r=0.0)
    for x in (-w / 2 + 0.06, w / 2 - 0.06):
        for y in (-d / 2 + 0.06, d / 2 - 0.06):
            turned(m, [(0.03, 0.0), (0.024, 0.1), (0.024, 0.6), (0.032, 0.66), (0.032, TABLE_TOP - 0.12)], 10, "wood",
                   at=(x, y, 0.0))


PIECES = [_standing(k) for k in range(len(BOOKS))] + [_stack(k) for k in range(len(STACKS))] + [
    live_cover_back, live_block_right, live_block_left, live_cover_front, live_spine_back, live_spine_front, live_leaf,
    lectern, front_table]


def build():
    common.reset()
    underground_shapes.rng = rng
    rng.seed(1888)

    for f in PIECES:
        smooth_object(f.__name__, f)


def main():
    build()
    common.export_piece(NAME, ATLAS, SLOTS, out=common.ROOT / "assets" / "eclipse" / "kit", sets_each=True, budget=4000)


if __name__ == "__main__":
    main()
