"""The rare-book librarian's shop, its room (docs/superpowers/specs/2026-10-17-librarian-shop-design.md;
docs/superpowers/refs/underground/recipe.md): an old vaulted room off the Metro corridor, cut into
the brick of an older building when the line was dug past it.

- room_vault: a segmental barrel vault of bare brick in courses, laid in running bond on its mortar,
  springing from limewashed side walls with a dark wooden skirting.
- room_back: the back wall, limewashed, a patch fallen where the brick shows (behind his rack).
- room_front: the shopfront wall, an arch of old dressed stone through it; on the corridor's side a
  bookseller's front of painted wood, pilasters and a fascia board (its face blank: the sign is the
  user's), limewash inside.
- room_floor: worn boards over the room, a few replaced in another wood; the corridor's Metro tile
  under the arch.
- room_rug: a runner from the arch to his desk, worn pale down its middle.

The frame: x across (the room's middle at 0), the floor's top at z = 0, the shopfront's corridor face
at y = -FRONT_T, the room from y = 0 to DEPTH (Godot's -z, the corridor at Godot's +z). Built to any
width, depth and crown (`build`), so it fits the place the real map gives it.

    Blender -b --factory-startup --python tools/eclipse/library_room.py
"""

import math
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import common  # noqa: E402
import underground_shapes  # noqa: E402
from underground_shapes import box, smooth_object  # noqa: E402

NAME = "library_room"
ATLAS = 4096
# The atlas's islands packed with a margin of 5 px round each (the vault's thousands of bricks; the
# painter grows each by 2, so no two pieces share a texel).
PACK_MARGIN = 0.0012
SLOTS = ["brick", "mortar", "limewash", "stone_old", "boards", "wood", "shopfront", "sign", "tile_cream", "tile_dark",
         "grout", "rug"]

rng = random.Random(1924)

# The room (m).
WIDTH = 8.0
DEPTH = 6.0
SPRING = 3.0
CROWN = 4.5
# The shopfront: its wall's thickness, its arch's opening, springing and crown.
FRONT_T = 0.4
FRONT_W = 3.0
FRONT_SPRING = 2.3
FRONT_CROWN = 2.9
# The side and back walls' thickness, the limewash skin on them, the skirting's height and how proud.
WALL_T = 0.35
SKIN = 0.08
SKIRT = (0.22, 0.035)
# The vault's bricks: along the room (y), up the arc, how deep; the joint between; the mortar bed behind.
BRICK_L = 0.3
BRICK_H = 0.1
BRICK_D = 0.045
JOINT = 0.014
BED = 0.05
# The floor: the boards' width and thickness, the bed under them; the corridor's tiles under the arch.
BOARD_W = 0.2
BOARD_T = 0.035
BOARD_GAP = 0.01
FLOOR_BED = 0.05
TILE = 0.3
TILE_T = 0.035
# The runner: its width, where it starts and stops (y), its thickness.
RUG = (1.2, 0.3, 2.4, 0.015)


def _hexa(m, corners, slot):
    """A closed solid of six quads from its eight corners: the four of one end, then the other's in step."""
    m.shell()
    a, b = corners[:4], corners[4:]
    m.face(a, slot)
    m.face(list(reversed(b)), slot)

    for k in range(4):
        m.face([a[k], a[(k + 1) % 4], b[(k + 1) % 4], b[k]], slot)


def _arc(width, spring, crown):
    """The segmental arc of an opening `width` across springing at `spring`, its crown at `crown`: its
    radius, its centre's height and its half-angle."""
    s, h = width / 2, crown - spring
    r = (h * h + s * s) / (2 * h)
    return r, crown - r, math.asin(s / r)


def _on_arc(r, zc, a, out=0.0):
    """The point at angle `a` from the crown (positive toward +x) on the arc, `out` beyond it (x, z)."""
    return ((r + out) * math.sin(a), zc + (r + out) * math.cos(a))


def _arc_band(m, r, zc, a0, a1, out0, out1, y0, y1, slot):
    """A solid between angles a0..a1 of the arc, from `out0` to `out1` beyond it, along y0..y1."""
    pts = []
    for y in (y0, y1):
        for a, out in ((a0, out0), (a1, out0), (a1, out1), (a0, out1)):
            x, z = _on_arc(r, zc, a, out)
            pts.append((x, y, z))
    _hexa(m, pts, slot)


def _bond(length, unit, offset):
    """Running bond along `length`: the courses' unit edges, the first cut short by `offset`."""
    edges = [0.0]
    x = unit - offset if offset else unit

    while x < length - 0.05:
        edges.append(x)
        x += unit

    edges.append(length)
    return list(zip(edges, edges[1:]))


def room_vault(m, width, depth, crown):
    """The vault: brick courses up its arc in running bond on a mortar bed, from wall to wall; under it the
    side walls, limewashed, with their skirting."""
    r, zc, half = _arc(width, SPRING, crown)
    # (An odd count, so a course runs along the crown, not a joint.)
    courses = max(3, round(2 * r * half / (BRICK_H + JOINT)) | 1)
    step = 2 * half / courses
    gap = JOINT / r / 2

    for k in range(courses):
        a0, a1 = -half + step * k + gap, -half + step * (k + 1) - gap
        for y0, y1 in _bond(depth, BRICK_L + JOINT, (BRICK_L + JOINT) / 2 if k % 2 else 0.0):
            _arc_band(m, r, zc, a0, a1, 0.0, BRICK_D, y0 + JOINT / 2, y1 - JOINT / 2, "brick")

    # The bed behind the bricks, in the joints; it reaches over the walls' tops.
    for k in range(courses):
        _arc_band(m, r, zc, -half + step * k, -half + step * (k + 1), BRICK_D, BRICK_D + BED, 0.0, depth, "mortar")

    for side in (-1, 1):
        # Mirrored: the wall from the room's face (x = width / 2) outward, its limewash skin toward the room
        # above the skirting, which stands proud of the skin.
        def at(d):
            return side * (width / 2 + d)

        def span(d0, d1):
            return sorted((at(d0), at(d1)))

        x0, x1 = span(SKIN, WALL_T)
        box(m, (x0, 0.0, 0.0), (x1, depth, SPRING), "brick", r=0.0)
        x0, x1 = span(0.0, SKIN)
        box(m, (x0, 0.0, SKIRT[0]), (x1, depth, SPRING), "limewash", r=0.0)
        x0, x1 = span(-SKIRT[1], SKIN)
        box(m, (x0, 0.0, 0.0), (x1, depth, SKIRT[0]), "wood", r=0.0)


def room_back(m, width, depth, crown):
    """The back wall: brick behind, limewashed toward the room, up past the crown to close the vault; the
    limewash fallen in a patch along the courses to the brick, behind where his rack hangs."""
    x0, x1 = -width / 2 - WALL_T, width / 2 + WALL_T
    top = crown + BRICK_D + BED + 0.05
    face = depth
    box(m, (x0, face + SKIN, 0.0), (x1, face + WALL_T, top), "brick", r=0.0)
    # The skirting along its foot.
    box(m, (-width / 2, face - SKIRT[1], 0.0), (width / 2, face + SKIN, SKIRT[0]), "wood", r=0.0)

    # The limewash, in courses so its fallen edge follows the brick's: in the patch's rows a gap, ragged.
    patch = (1.55, 3.05, 1.05, 2.05)
    z = SKIRT[0]
    row = 0

    while z < top - 1e-6:
        z1 = min(top, z + BRICK_H + JOINT)
        middle = (z + z1) / 2
        if patch[2] < middle < patch[3]:
            cut0 = patch[0] + 0.15 * math.sin(row * 1.9) + rng.uniform(-0.08, 0.08)
            cut1 = patch[1] + 0.2 * math.sin(row * 1.3 + 1.0) + rng.uniform(-0.08, 0.08)
            box(m, (x0, face, z), (cut0, face + SKIN, z1), "limewash", r=0.0)
            box(m, (cut1, face, z), (x1, face + SKIN, z1), "limewash", r=0.0)
            # The brick showing, set back behind the limewash's face.
            for b0, b1 in _bond(cut1 - cut0, BRICK_L + JOINT, (BRICK_L + JOINT) / 2 if row % 2 else 0.0):
                box(m, (cut0 + b0 + JOINT / 2, face + SKIN / 2, z + JOINT / 2), (cut0 + b1 - JOINT / 2, face + SKIN, z1 - JOINT / 2),
                    "brick", r=0.0)
        else:
            box(m, (x0, face, z), (x1, face + SKIN, z1), "limewash", r=0.0)
        z = z1
        row += 1


def room_front(m, width, depth, crown):
    """The shopfront wall: piers either side of an arch of old dressed stone (its voussoirs proud of both
    faces); above it the wall up past the vault's crown; on the corridor's side a bookseller's painted
    front, pilasters and a fascia board (blank, the user's sign) under a cornice."""
    x0, x1 = -width / 2 - WALL_T, width / 2 + WALL_T
    y0, y1 = -FRONT_T, 0.0
    top = crown + BRICK_D + BED + 0.05
    s = FRONT_W / 2
    r, zc, half = _arc(FRONT_W, FRONT_SPRING, FRONT_CROWN)
    ring = 0.32
    proud = 0.04

    jamb = 0.3
    pier = s + jamb
    _, z_end = _on_arc(r, zc, half, ring)
    edge = _on_arc(r, zc, half, ring)[0]

    # The piers, limewashed both faces, from the floor past the vault's crown, outside the jambs (the corridor's
    # tiles go on the outside beyond the shop's front).
    box(m, (x0, y0, 0.0), (-pier, y1, top), "limewash", r=0.0)
    box(m, (pier, y0, 0.0), (x1, y1, top), "limewash", r=0.0)

    # Over the arch: the wall in slices down to the ring's back, the outermost reaching to the piers.
    slices = 12

    for k in range(slices):
        a0, a1 = -half + 2 * half * k / slices, -half + 2 * half * (k + 1) / slices
        (xa, za), (xb, zb) = _on_arc(r, zc, a0, ring), _on_arc(r, zc, a1, ring)
        if k == 0:
            xa = -pier
        if k == slices - 1:
            xb = pier
        _hexa(m, [(xa, y0, za), (xb, y0, zb), (xb, y0, top), (xa, y0, top),
                  (xa, y1, za), (xb, y1, zb), (xb, y1, top), (xa, y1, top)], "limewash")

    # The ring of old stone: its voussoirs, a keystone proud of the rest, through the wall and out of both faces.
    stones = 11
    for k in range(stones):
        a0, a1 = -half + 2 * half * k / stones + 0.004, -half + 2 * half * (k + 1) / stones - 0.004
        key = k == stones // 2
        _arc_band(m, r, zc, a0, a1, 0.0, ring + (0.06 if key else 0.0), y0 - proud - (0.02 if key else 0.0),
                  y1 + proud, "stone_old")

    for side in (-1, 1):
        # The jambs, dressed stone up each side of the opening to the springing; on each a springer block
        # carrying the ring's foot out to the pier.
        jx = sorted((side * s, side * pier))
        box(m, (jx[0], y0 - proud, 0.0), (jx[1], y1 + proud, FRONT_SPRING - 0.004), "stone_old", r=0.02)
        foot = [(side * s, FRONT_SPRING), (side * pier, FRONT_SPRING), (side * pier, z_end), (side * edge, z_end)]
        _hexa(m, [(x, y0 - proud, z) for x, z in foot] + [(x, y1 + proud, z) for x, z in foot], "stone_old")

    # The bookseller's front on the corridor side: pilasters, their capitals; the fascia and its cornice.
    face = y0
    for side in (-1, 1):
        px = sorted((side * (s + 0.36), side * (s + 0.82)))
        box(m, (px[0], face - 0.08, 0.0), (px[1], face, 2.6), "shopfront", r=0.025)
        box(m, (px[0] - 0.05, face - 0.13, 2.6), (px[1] + 0.05, face, 2.78), "shopfront", r=0.025)
        box(m, (px[0] + 0.06, face - 0.12, 0.0), (px[1] - 0.06, face - 0.08, 0.3), "wood", r=0.0)

    fascia = (-s - 0.9, s + 0.9)
    box(m, (fascia[0], face - 0.07, 3.4), (fascia[1], face, 3.95), "shopfront", r=0.02)
    box(m, (fascia[0] + 0.08, face - 0.115, 3.48), (fascia[1] - 0.08, face - 0.07, 3.87), "sign", r=0.0)
    box(m, (fascia[0] - 0.08, face - 0.18, 3.95), (fascia[1] + 0.08, face, 4.09), "shopfront", r=0.03)


def room_floor(m, width, depth, crown):
    """Boards along the room on their bed, butt-jointed where one length ends, a few replaced in another wood;
    under the arch the corridor's tiles come in on their grout."""
    box(m, (-width / 2, 0.0, -BOARD_T - FLOOR_BED), (width / 2, depth, -BOARD_T), "grout", r=0.0)
    lanes = max(1, round(width / BOARD_W))
    w = width / lanes

    for i in range(lanes):
        x0, x1 = -width / 2 + w * i + BOARD_GAP / 2, -width / 2 + w * (i + 1) - BOARD_GAP / 2
        y = 0.0
        while y < depth - 1e-6:
            length = rng.uniform(1.2, 3.0)
            y1 = depth if depth - (y + length) < 0.5 else y + length
            slot = "wood" if rng.random() < 0.1 else "boards"
            box(m, (x0, y + BOARD_GAP / 2, -BOARD_T), (x1, y1 - BOARD_GAP / 2, 0.0), slot, r=0.0)
            y = y1

    s = FRONT_W / 2
    box(m, (-s, -FRONT_T, -TILE_T - FLOOR_BED), (s, 0.0, -TILE_T), "grout", r=0.0)
    cols = round(FRONT_W / TILE)

    for i in range(cols):
        for j in range(2):
            ya, yb = -FRONT_T + j * FRONT_T / 2, -FRONT_T + (j + 1) * FRONT_T / 2
            box(m, (-s + TILE * i + 0.004, ya + 0.004, -TILE_T), (-s + TILE * (i + 1) - 0.004, yb - 0.004, 0.0),
                "tile_dark" if (i + j) % 2 else "tile_cream", r=0.0)


def room_rug(m, width, depth, crown):
    """The runner from the arch to his desk."""
    w, y0, stop, t = RUG
    box(m, (-w / 2, y0, 0.0), (w / 2, depth - stop, t), "rug", r=0.0)


PIECES = [room_vault, room_back, room_front, room_floor, room_rug]


def build(width=WIDTH, depth=DEPTH, crown=CROWN):
    common.reset()
    underground_shapes.rng = rng
    rng.seed(1924)

    for f in PIECES:
        smooth_object(f.__name__, lambda m, f=f: f(m, width, depth, crown))


def main():
    build()
    common.export_piece(NAME, ATLAS, SLOTS, out=common.ROOT / "assets" / "eclipse" / "kit", sets_each=True, budget=24000,
                        pack_margin=PACK_MARGIN)


if __name__ == "__main__":
    main()
