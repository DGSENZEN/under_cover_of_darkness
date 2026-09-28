"""The lanes' houses (kit v1): timber-framed town houses round the garrison,
each its own (house_a .. house_f). Pure data, as kit_recipes (which imports
this at its end).

A house is 6 m across its front (x) and 7 m deep (z), its pivot in the middle
of its footprint, its front toward +z. A stone or plastered ground floor
with its door and a shuttered window; one or two storeys over it, each
jettied out over the lane on its joists, framed in timber (braced panels or
close studs) round leaded windows, a few of them lit; a steep roof, its
gable to the lane or its eaves with a dormer; a chimney stack at the back.

Its collider is its body up to the eaves: the lane is walked, the house is
not entered.
"""

import math

import kit_recipes as k
import kit_shapes as ks

WIDTH = 6.0
DEPTH = 7.0
GROUND = 3.0
STOREY = 2.7
JETTY = 0.45
# A timber's face, how far it stands out of the plaster; a window's size.
MEMBER = 0.16
PROUD = 0.07
WINDOW = (1.0, 1.05)
# The most triangles a house is drawn with (a lane holds fourteen).
HOUSE_TRIS = 1800


def _member(x0, y0, x1, y1, z, width=MEMBER, slot="beam"):
    """A timber on a front (the plane z) from (x0, y0) to (x1, y1)."""
    length = math.hypot(x1 - x0, y1 - y0)
    angle = math.degrees(math.atan2(y1 - y0, x1 - x0))
    return ks.box((x0 + x1) / 2.0, (y0 + y1) / 2.0, z + PROUD - 0.05, length, width, 0.1, slot, 0.0, 0.0, angle)


def _window(x, y, z, lit, shutters=False, size=WINDOW):
    """A window on the front z, its middle at (x, y): its glass (dark, or lit
    and leaded), its frame and sill; shutters swung back either side."""
    w, h = size
    out = [ks.card(x, y, z + 0.02, w, h, "glass_lit" if lit else "glass_dark"),
           _member(x - w / 2.0, y - h / 2.0, x - w / 2.0, y + h / 2.0, z, 0.1),
           _member(x + w / 2.0, y - h / 2.0, x + w / 2.0, y + h / 2.0, z, 0.1),
           _member(x - w / 2.0 - 0.05, y + h / 2.0, x + w / 2.0 + 0.05, y + h / 2.0, z, 0.12),
           ks.box(x, y - h / 2.0 - 0.03, z + 0.08, w + 0.24, 0.07, 0.16, "beam")]

    if lit:
        # Leading: a mullion and a transom across the lit glass.
        out.append(_member(x, y - h / 2.0, x, y + h / 2.0, z - 0.02, 0.05, "iron"))
        out.append(_member(x - w / 2.0, y + h * 0.1, x + w / 2.0, y + h * 0.1, z - 0.02, 0.05, "iron"))

    if shutters:
        for side in (-1.0, 1.0):
            out.append(ks.card(x + side * (w * 0.75 + 0.07), y, z + 0.05, w / 2.0, h, "shutters"))

    return out


def _door(x, z, slot):
    """A door on the front z (its foot on the ground), framed, a step before it."""
    return [ks.card(x, 1.02, z + 0.02, 1.0, 2.04, slot),
            _member(x - 0.56, 0.0, x - 0.56, 2.12, z, 0.14),
            _member(x + 0.56, 0.0, x + 0.56, 2.12, z, 0.14),
            _member(x - 0.72, 2.16, x + 0.72, 2.16, z, 0.2),
            ks.box(x, 0.07, z + 0.2, 1.4, 0.14, 0.4, "stone")]


def _framing(y0, height, z, style, windows, lit):
    """An upper storey's front framed: its sole and top plates, corner posts,
    rails at its sills and heads, posts beside each window and, `style`
    "braced", St Andrew's crosses under the windows and long braces in the
    end panels, or "studded", close studs everywhere else."""
    half = WIDTH / 2.0
    sill, head = y0 + 0.9, y0 + 0.9 + WINDOW[1] + 0.1
    out = [_member(-half, y0 + 0.1, half, y0 + 0.1, z, 0.2), _member(-half, y0 + height - 0.1, half, y0 + height - 0.1, z, 0.2),
           _member(-half + 0.08, y0, -half + 0.08, y0 + height, z), _member(half - 0.08, y0, half - 0.08, y0 + height, z),
           _member(-half, sill, half, sill, z, 0.12), _member(-half, head, half, head, z, 0.12)]

    for i, x in enumerate(windows):
        out += _window(x, (sill + head) / 2.0, z, (i in lit))

        for side in (-1.0, 1.0):
            out.append(_member(x + side * (WINDOW[0] / 2.0 + 0.08), y0 + 0.2, x + side * (WINDOW[0] / 2.0 + 0.08), y0 + height - 0.2, z))

        if style == "braced":
            a, b = x - WINDOW[0] / 2.0, x + WINDOW[0] / 2.0
            out.append(_member(a, y0 + 0.2, b, sill - 0.06, z, 0.1))
            out.append(_member(a, sill - 0.06, b, y0 + 0.2, z, 0.1))

    if style == "braced":
        edge = max(abs(x) + WINDOW[0] / 2.0 + 0.16 for x in windows)
        out.append(_member(-half + 0.16, y0 + 0.2, -edge, head, z, 0.14))
        out.append(_member(half - 0.16, y0 + 0.2, edge, head, z, 0.14))
        out.append(_member(0.0, y0 + 0.2, 0.0, y0 + height - 0.2, z))
    else:
        clear = [(x - WINDOW[0] / 2.0 - 0.1, x + WINDOW[0] / 2.0 + 0.1) for x in windows]
        x = -half + 0.5

        while x < half - 0.4:
            if not any(a < x < b for a, b in clear):
                out.append(_member(x, y0 + 0.2, x, y0 + height - 0.2, z, 0.12))
            else:
                # Short studs under and over a window.
                out.append(_member(x, y0 + 0.2, x, sill, z, 0.12))
                out.append(_member(x, head, x, y0 + height - 0.2, z, 0.12))
            x += 0.5

    return out


def _jetty(y0, z_below, z_front):
    """Where a storey juts out: the bressumer along its foot, the joists'
    ends under it, a bracket at either corner."""
    half = WIDTH / 2.0
    out = [ks.box(0.0, y0 + 0.13, z_front + 0.03, WIDTH + 0.12, 0.26, 0.18, "beam")]

    for i in range(7):
        out.append(ks.box(-half + 0.3 + i * (WIDTH - 0.6) / 6.0, y0 - 0.07, (z_below + z_front) / 2.0, 0.13, 0.14, z_front - z_below + 0.02, "beam"))

    rise, run = 0.9, z_front - z_below - 0.06
    length = math.hypot(rise, run)
    pitch = -math.degrees(math.atan2(rise, run))

    for side in (-1.0, 1.0):
        out.append(ks.box(side * (half - 0.12), y0 - rise / 2.0, z_below + run / 2.0, 0.14, 0.14, length, "beam", 0.0, pitch, 0.0))

    return out


def _gable_front(y0, z, rise, slot, lit):
    """A gable to the lane on the front z: its triangle framed (a tie beam, a
    king post, a collar, raking struts), a window under the collar."""
    half = WIDTH / 2.0
    collar = y0 + rise * 0.5
    reach = half * (1.0 - 0.5) - 0.2
    out = [ks.gable(0.0, y0, z - 0.1, WIDTH, rise, 0.2, slot),
           _member(-half, y0 + 0.14, half, y0 + 0.14, z, 0.26),
           _member(-reach, collar, reach, collar, z, 0.16),
           _member(0.0, collar, 0.0, y0 + rise - 0.35, z),
           _member(-half + 0.3, y0 + 0.2, -reach + 0.1, collar, z, 0.14),
           _member(half - 0.3, y0 + 0.2, reach - 0.1, collar, z, 0.14)]
    out += _window(0.0, y0 + 1.05, z, lit, size=(0.8, 0.8))
    return out


def _chimney(x, z, top, slot):
    """A stack from the ground behind the house to `top`, its cap and pots."""
    return [ks.box(x, top / 2.0, z, 0.9, top, 0.9, slot), ks.box(x, top + 0.1, z, 1.1, 0.2, 1.1, slot),
            ks.lathe(x - 0.2, top + 0.2, z, [[0.12, 0.0], [0.1, 0.28], [0.13, 0.38]], 6, "clay"),
            ks.lathe(x + 0.2, top + 0.2, z, [[0.12, 0.0], [0.1, 0.22], [0.13, 0.3]], 6, "clay")]


def house(storeys, ground, walls, roof, gable, rise, style, door, door_x, lit, shop=False, chimney=1.0, roof_tile=1.2):
    """A house: `storeys` jettied over its `ground` floor, framed `style` in
    `walls`, roofed in `roof` (`gable` "front": its gable to the lane; "side":
    its eaves with a dormer) `rise` high; its door `door` at `door_x`; `lit`
    [(storey, window), ...] its lit windows (storey 0 the ground's, the
    gable's the storey over the last); `shop` a counter and awning for its
    ground window; its chimney at the back to the left (-1) or right (1).
    Returns (shapes, colliders, front)."""
    half, front = WIDTH / 2.0, DEPTH / 2.0
    out = [ks.box(0.0, GROUND / 2.0, 0.0, WIDTH, GROUND, DEPTH, ground)]
    # The ground floor's front: its door, its window (a shop's counter under
    # a propped awning, or shutters); timbers round them if plastered.
    out += _door(door_x, front, door)
    wx = -door_x

    if shop:
        out += _window(wx, 1.45, front, (0, 0) in lit, size=(1.6, 1.1))
        out.append(ks.box(wx, 0.86, front + 0.25, 1.9, 0.08, 0.5, "boards"))
        out.append(ks.slab([[wx - 1.0, 2.2, front + 0.02], [wx + 1.0, 2.2, front + 0.02], [wx + 1.0, 1.95, front + 0.75], [wx - 1.0, 1.95, front + 0.75]],
                           0.05, "boards", edge="timber", up=(0.0, 1.0, 1.0)))
    else:
        out += _window(wx, 1.5, front, (0, 0) in lit, shutters=True)

    if ground != "stone":
        out += [_member(-half, 0.12, half, 0.12, front, 0.24), _member(-half + 0.08, 0.0, -half + 0.08, GROUND, front),
                _member(half - 0.08, 0.0, half - 0.08, GROUND, front)]

    z_below = front

    for storey in range(1, storeys + 1):
        y0 = GROUND + (storey - 1) * STOREY
        z = front + JETTY * storey
        out.append(ks.box(0.0, y0 + STOREY / 2.0, (z - front) / 2.0, WIDTH, STOREY, DEPTH + (z - front), walls))
        out += _jetty(y0, z_below, z)
        out += _framing(y0, STOREY, z, style, [-1.4, 1.4], [w for s, w in lit if s == storey])
        z_below = z

    top = GROUND + storeys * STOREY
    z_top = front + JETTY * storeys
    length = z_top + front
    middle = (z_top - front) / 2.0

    if gable == "front":
        out += ks.moved(k.pitched(length, WIDTH, rise, slot=roof, tile=roof_tile, overhang=0.28), 90.0, (0.0, top, middle))
        out += _gable_front(top, z_top, rise, walls, (storeys + 1, 0) in lit)
        out.append(ks.gable(0.0, top, -front + 0.1, WIDTH, rise, 0.2, walls))
        ridge = top + rise
    else:
        # (Its verges kept short: the next house's wall is there.)
        out += ks.moved(k.pitched(WIDTH, length, rise, slot=roof, tile=roof_tile, overhang=0.45, verge=0.12), 0.0, (0.0, top, middle))

        for side in (-1.0, 1.0):
            out.append(ks.gable(side * (half - 0.1), top, middle, length, rise, 0.2, walls, 90.0))

        # A dormer on the front slope: its cheeks, its window, its own roof.
        dz = z_top - 0.3
        out.append(ks.box(0.0, top + 0.75, dz - 1.1, 1.8, 1.5, 2.2, walls))
        out += _window(0.0, top + 0.8, dz, (storeys + 1, 0) in lit, size=(0.9, 0.8))
        out += ks.moved(k.pitched(2.2, 1.8, 0.8, slot=roof, tile=roof_tile, overhang=0.15, verge=0.1), 90.0, (0.0, top + 1.5, dz - 1.1))
        out.append(ks.gable(0.0, top + 1.5, dz - 0.05, 1.8, 0.8, 0.1, walls))
        ridge = top + rise

    out += _chimney(chimney * (half - 0.6), -front + 0.9, ridge + 1.1, "stone" if ground == "stone" else "ashlar")
    cols = [[0.0, top / 2.0, 0.0, WIDTH, top, DEPTH, "stone", 0.0, 0.0, 0.0]]
    return out, cols, front


# The six: which storeys, floors, walls, roofs and lights each has.
HOUSES = {
    "house_a": dict(storeys=2, ground="stone", walls="limewash", roof="roof_slate", gable="front", rise=4.6, style="braced",
                    door="door_1", door_x=-1.5, lit=[(1, 1), (2, 0)], chimney=1.0),
    "house_b": dict(storeys=1, ground="plaster", walls="plaster", roof="roof_tiles", gable="side", rise=4.0, style="studded",
                    door="door_2", door_x=1.6, lit=[(0, 0)], chimney=-1.0, roof_tile=1.0),
    "house_c": dict(storeys=2, ground="plaster_ochre", walls="plaster_ochre", roof="roof_shingle", gable="front", rise=5.0, style="braced",
                    door="door_1", door_x=1.7, lit=[(0, 0), (2, 1)], shop=True, chimney=-1.0),
    "house_d": dict(storeys=1, ground="stone", walls="plaster", roof="roof_slate", gable="side", rise=3.6, style="braced",
                    door="door_2", door_x=-1.6, lit=[(1, 0)], chimney=1.0),
    "house_e": dict(storeys=2, ground="limewash", walls="limewash", roof="roof_tiles", gable="front", rise=4.2, style="studded",
                    door="door_2", door_x=1.5, lit=[(3, 0)], chimney=1.0, roof_tile=1.0),
    "house_f": dict(storeys=1, ground="stone", walls="plaster_ochre", roof="roof_fish", gable="front", rise=5.4, style="braced",
                    door="door_1", door_x=-1.6, lit=[(1, 0), (1, 1)], chimney=-1.0),
}

for _name, _spec in HOUSES.items():
    _shapes, _cols, _front = house(**_spec)
    _reach = _front + JETTY * _spec["storeys"] + 0.45
    k.piece(_name, "house", _spec["walls"], "stone", [], cols=_cols, size=[WIDTH, GROUND + _spec["storeys"] * STOREY + _spec["rise"], 2.0 * _reach])
    k.model(_name, _shapes)
    k.PIECES[_name]["front"] = _front
    k.PIECES[_name]["budget"] = HOUSE_TRIS
