"""The Carmo ruin (the old town's spec, sections 4.3, 4.4 and 16;
old_town_lisbon.md section 7): the great church that burned in the fire,
left roofless as a memorial; the watch keeps its convent. Its parts are
pieces the layout strings along its axis (z, the front at z 0 of each
part, the church going -z to its apse); pure data, as kit_recipes (which
imports this at its end).

    carmo_front       the west front: its portal open, its rose window
                      empty, its gable
    carmo_bay_whole   a nave bay BAY long: two piers at its east end, the
    carmo_bay_broken  arcade's pointed arches to the aisles, the aisles'
                      outer walls AISLE_H high, a tall empty window in
                      each, a side chapel off the north aisle; the arch
                      across the nave at its east end whole (to NAVE_H,
                      24.64) or broken off at its haunches
    carmo_transept    the fifth bay, its arms out to TRANSEPT wide
    carmo_apse        the apse APSE long, roofed (APSE_H high), its east
                      window's tracery broken, the altar under it
                      (places["altar"]: the comet's red light falls on it,
                      the spec's 16)
    carmo_buttress    a flying buttress: its pier and its flyer leaning in
                      to the nave (five along the south side)

Open to the sky but for the apse: its piers cast the moon's shadows.
"""

import math

import kit_recipes as k  # noqa: F401 (first: it registers every kit)
import kit_shapes as ks
import kit_town as town

FRONT = 3.0
BAY = 11.0
APSE = 14.0
NAVE = 10.0
PIER = 1.6
AISLE = 6.0
WALL = 1.2
NAVE_H = 24.64
AISLE_H = 18.7
ARCADE_SPRING = 12.0
ARCADE_RISE = 4.0
TRANSVERSE_SPRING = 16.0
APSE_H = 15.4
TRANSEPT = 33.0
WINDOW = (3.0, 10.0, 4.0)
EAST_WINDOW = (2.0, 7.0, 4.0)
PORTAL = (4.0, 8.0)
CHAPEL = (5.0, 4.0, 8.0)
BUTTRESS = (1.5, 13.0, 3.0, 9.4, 18.0)
# A broken arch stands to this share of its rise.
BROKEN = 0.35

PIER_X = NAVE / 2.0 + PIER / 2.0
AISLE_IN = PIER_X + PIER / 2.0 + AISLE
OUTER = AISLE_IN + WALL


def _floor(length, half):
    s, c = town.floors(2.0 * half, length, [0.0], None, "flagstone", "stone")
    return town.placed(s, c, z=-length / 2.0)


def _pointed(width, spring, rise, z, thick, slot="ashlar", along_z=False, x=0.0, broken=False):
    """A pointed arch's band `width` across springing at `spring`, `rise`
    to its crown, `thick` through: drawn as voussoir boxes round its two
    arcs (broken: only their haunches), its collider a box over its crown
    (a broken one's, its stubs). Across x at z (or along z at x)."""
    half = width / 2.0
    radius = (half * half + rise * rise) / (2.0 * half)
    shapes, cols = [], []
    steps = 5

    for side in (-1.0, 1.0):
        # (Each arc's centre on the springing line, its far side's radius.)
        cx = -side * (radius - half)
        top = 1.0 if not broken else BROKEN

        for i in range(steps):
            t0, t1 = i / steps * top, (i + 1) / steps * top
            # (Angles from the springing up to the crown.)
            full = math.asin(min(1.0, rise / radius))
            q0, q1 = full * t0, full * t1
            p0 = (cx + side * radius * math.cos(q0), spring + radius * math.sin(q0))
            p1 = (cx + side * radius * math.cos(q1), spring + radius * math.sin(q1))
            mx, my = (p0[0] + p1[0]) / 2.0, (p0[1] + p1[1]) / 2.0
            length = math.hypot(p1[0] - p0[0], p1[1] - p0[1]) + 0.1
            roll = math.degrees(math.atan2(p1[1] - p0[1], p1[0] - p0[0]))

            if along_z:
                shapes.append(ks.box(x, my + 0.35, z + mx, thick, 0.9, length, slot, 0.0, -roll, 0.0))
            else:
                shapes.append(ks.box(mx, my + 0.35, z, length, 0.9, thick, slot, 0.0, 0.0, roll))


    crown = spring + rise if not broken else spring + rise * BROKEN
    if not broken:
        if along_z:
            cols.append(town.col(x, crown + 0.4, z, thick, 0.8, 1.6))
        else:
            cols.append(town.col(0.0, crown + 0.4, z, 1.6, 0.8, thick))

    return shapes, cols, crown + 0.8


def _bay(length, broken, half_width=None, transept=False):
    """A nave bay (see the module's doc)."""
    shapes, cols = [], []
    s, c = _floor(length, AISLE_IN)
    shapes, cols = shapes + s, cols + c
    z_end = -length

    # Two piers at its east end, their capitals.
    for sx in (-1.0, 1.0):
        shapes += [ks.prism(sx * PIER_X, TRANSVERSE_SPRING / 2.0, z_end, PIER / 2.0, TRANSVERSE_SPRING, 8, "ashlar"),
                   ks.box(sx * PIER_X, TRANSVERSE_SPRING + 0.2, z_end, PIER + 0.3, 0.4, PIER + 0.3, "ashlar")]
        cols.append(town.col(sx * PIER_X, TRANSVERSE_SPRING / 2.0 + 0.2, z_end, PIER, TRANSVERSE_SPRING + 0.4, PIER))

        # The arcade's arch along the bay to the aisle on that side.
        s, c, _top = _pointed(length - PIER, ARCADE_SPRING, ARCADE_RISE, -length / 2.0, PIER * 0.8, along_z=True, x=sx * PIER_X)
        shapes, cols = shapes + s, cols + c

    # The arch across the nave at its east end: whole, or its haunches.
    s, c, crown = _pointed(2.0 * PIER_X, TRANSVERSE_SPRING, NAVE_H - TRANSVERSE_SPRING - 0.8, z_end, PIER * 0.8, broken=broken)
    shapes, cols = shapes + s, cols + c

    # The aisles' outer walls (the transept's arms further out), their tall
    # windows; a side chapel off the north aisle.
    out_x = (TRANSEPT / 2.0 - WALL / 2.0) if transept else AISLE_IN + WALL / 2.0
    w, h, sill = WINDOW

    for sx in (-1.0, 1.0):
        x = sx * out_x
        holes = [(-w / 2.0, w / 2.0, sill, sill + h)]

        for a0, a1, b0, b1 in town.split(-length / 2.0, length / 2.0, 0.0, AISLE_H, holes):
            box = (x, (b0 + b1) / 2.0, -length / 2.0 + (a0 + a1) / 2.0, WALL, b1 - b0, a1 - a0)
            shapes.append(ks.box(*box, "ashlar"))
            cols.append(town.col(*box))

    if transept:
        # (The arms: their floors from the aisles out, their end walls'
        # faces along the nave's line closing them.)
        for sx in (-1.0, 1.0):
            s, c = town.floors(TRANSEPT / 2.0 - AISLE_IN, length, [0.0], None, "flagstone", "stone")
            s, c = town.placed(s, c, sx * (AISLE_IN + (TRANSEPT / 2.0 - AISLE_IN) / 2.0), -length / 2.0)
            shapes, cols = shapes + s, cols + c
    else:
        cw, cd, ch = CHAPEL
        cz = -length / 2.0
        x0 = -(AISLE_IN + WALL)
        for box in ((x0 - cd / 2.0, ch / 2.0, cz - cw / 2.0 - 0.3, cd, ch, 0.6), (x0 - cd / 2.0, ch / 2.0, cz + cw / 2.0 + 0.3, cd, ch, 0.6),
                    (x0 - cd - 0.3, ch / 2.0, cz, 0.6, ch, cw + 1.2)):
            shapes.append(ks.box(*box, "ashlar"))
            cols.append(town.col(*box))

        s, c = town.floors(cd, cw, [0.0], None, "flagstone", "stone")
        s, c = town.placed(s, c, x0 - cd / 2.0, cz)
        shapes, cols = shapes + s, cols + c

    return {"shapes": shapes, "cols": cols, "size": [2.0 * (out_x + WALL), NAVE_H + 1.0, 2.0 * length], "length": length, "arch_crown": crown,
            "budget": 4000}


def _front():
    """The west front: its wall with the portal open through it and an
    empty rose window, its gable over the nave."""
    pw, ph = PORTAL
    shapes, cols = [], []
    width = 2.0 * OUTER

    for a0, a1, b0, b1 in town.split(-OUTER, OUTER, 0.0, AISLE_H, [(-pw / 2.0, pw / 2.0, 0.0, ph)]):
        box = ((a0 + a1) / 2.0, (b0 + b1) / 2.0, -1.0, a1 - a0, b1 - b0, 2.0)
        shapes.append(ks.box(*box, "ashlar"))
        cols.append(town.col(*box))

    shapes += [ks.gable(0.0, AISLE_H, -1.0, 2.0 * PIER_X + PIER, NAVE_H - AISLE_H + 2.0, 2.0, "ashlar"),
               ks.ring(0.0, 13.0, 0.05, 2.0, 2.6, 0.3, 0.0, 360.0, 12, "ashlar")]
    shapes += _pointed(pw, ph - 1.5, 1.5, 0.05, 0.3)[0]
    s, c = _floor(FRONT, AISLE_IN)
    shapes, cols = shapes + s, cols + c
    return {"shapes": shapes, "cols": cols, "size": [width, NAVE_H + 2.0, 2.0 * FRONT], "length": FRONT, "budget": 4000}


def _apse():
    """The apse: straight walls then three canted ones closing on the east
    face and its window (its tracery broken), APSE_H high under its vault
    (a roof: the comet's light comes in by the window only); the altar
    under the window."""
    shapes, cols = [], []
    half = NAVE / 2.0
    straight = APSE - 6.0
    t = WALL
    s, c = _floor(APSE, half + 1.0)
    shapes, cols = shapes + s, cols + c

    for sx in (-1.0, 1.0):
        box = (sx * (half + t / 2.0), APSE_H / 2.0, -straight / 2.0, t, APSE_H, straight)
        shapes.append(ks.box(*box, "ashlar"))
        cols.append(town.col(*box))
        # (A canted wall from the straight one's end toward the east face.)
        x0, z0, x1, z1 = sx * (half + t / 2.0), -straight, sx * 2.0, -APSE + t / 2.0
        length = math.hypot(x1 - x0, z1 - z0)
        yaw = math.degrees(math.atan2(x1 - x0, z1 - z0))
        box = ((x0 + x1) / 2.0, APSE_H / 2.0, (z0 + z1) / 2.0, t, APSE_H, length)
        shapes.append(ks.box(*box, "ashlar", yaw))
        cols.append(town.col(*box, "stone", yaw))

    w, h, sill = EAST_WINDOW
    for a0, a1, b0, b1 in town.split(-2.0, 2.0, 0.0, APSE_H, [(-w / 2.0, w / 2.0, sill, sill + h)]):
        box = ((a0 + a1) / 2.0, (b0 + b1) / 2.0, -APSE + t / 2.0, a1 - a0, b1 - b0, t)
        shapes.append(ks.box(*box, "ashlar"))
        cols.append(town.col(*box))

    # (Its tracery broken: a mullion standing, a piece of its head hanging.)
    shapes += [ks.box(0.0, sill + h * 0.35, -APSE + t / 2.0, 0.18, h * 0.7, 0.2, "ashlar"),
               ks.box(-0.45, sill + h - 0.6, -APSE + t / 2.0, 0.9, 0.18, 0.2, "ashlar", 0.0, 0.0, 25.0)]
    shapes.append(ks.box(0.0, APSE_H + 0.3, -APSE / 2.0, NAVE + 2.0 * t, 0.6, APSE, "ashlar"))
    cols.append(town.col(0.0, APSE_H + 0.3, -APSE / 2.0, NAVE + 2.0 * t, 0.6, APSE))
    altar_z = -APSE + t + 1.0
    shapes.append(ks.box(0.0, 0.5, altar_z, 2.2, 1.0, 1.0, "ashlar"))
    cols.append(town.col(0.0, 0.5, altar_z, 2.2, 1.0, 1.0))
    places = {"altar": [0.0, 1.0, altar_z], "cloister_door": [-(half + t + 2.0), 0.0, -straight / 2.0]}
    return {"shapes": shapes, "cols": cols, "size": [NAVE + 2.0 * t + 2.0, APSE_H + 1.0, 2.0 * APSE], "length": APSE, "places": places,
            "east_window": [0.0, sill, w, h, -APSE + t / 2.0], "budget": 4000, "roofed": True}


def _buttress():
    """A flying buttress: its pier, its flyer leaning in from the pier's top
    toward the nave (-x), to the arcade's top."""
    w, h, d, span, top = BUTTRESS
    shapes = [ks.box(0.0, h / 2.0, 0.0, w, h, d, "ashlar"), ks.prism(0.0, h + 0.8, 0.0, w * 0.5, 1.6, 4, "ashlar", 45.0, top=0.05)]
    cols = [town.col(0.0, h / 2.0, 0.0, w, h, d)]
    length = math.hypot(span, top - h)
    roll = math.degrees(math.atan2(top - h, span))
    shapes.append(ks.box(-span / 2.0, (h + top) / 2.0, 0.0, length, 0.7, 0.8, "ashlar", 0.0, 0.0, -roll))
    cols.append(town.col(-span / 2.0, (h + top) / 2.0, 0.0, length, 0.7, 0.8, "stone", 0.0, 0.0, -roll))
    return {"shapes": shapes, "cols": cols, "size": [2.0 * span + w, top + 2.0, d], "budget": 600}


for _name, _design in (("carmo_front", _front()), ("carmo_bay_whole", _bay(BAY, False)), ("carmo_bay_broken", _bay(BAY, True)),
                       ("carmo_transept", _bay(BAY, False, transept=True)), ("carmo_apse", _apse()), ("carmo_buttress", _buttress())):
    town.register(_name, "town", "ashlar", _design)
