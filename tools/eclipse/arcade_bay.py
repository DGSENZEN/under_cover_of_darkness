"""One bay of the Zócalo's merchants' arcade
(docs/superpowers/refs/mexico_city/cards/arcade_bay.md): tezontle framed in
chiluca, a round arch on a column, a balcony window above, the shop behind;
the bay's left column may be stone or the seeped riveted steel one. Built in
Blender, its atlas made, baked and exported to assets/eclipse/lab/arcade_bay.*;
the geometry gate decides whether it stands, alone and as two bays side by
side.

    Blender -b --factory-startup --python tools/eclipse/arcade_bay.py

Blender axes: +X along the arcade (bays tile every 4.5 m), +Y from the
plaza into the building, Z up. The origin is the left column's centre at
the arcade floor's front edge, at street level.
"""

import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import bpy  # noqa: E402

import common  # noqa: E402
import gate  # noqa: E402

NAME = "arcade_bay"
# 768, not 512: a 9.75 m façade cannot hold the kiosk's ~48 px/m in 512 (the lab's finding).
ATLAS = 768
SLOTS = ["tezontle", "chiluca", "lime", "steel", "iron", "brass", "wood_door", "tile_floor"]

BAY = 4.5
FLOOR = 0.25                      # the arcade floor above the street
FRONT = -0.3                      # the façade's face (the plaza is -y)
WALL_BACK = 0.3                   # the arcade wall's inner face
DEEP = 4.0                        # the shop front's face
BACK_OUT = 4.3                    # the block's back
FLOOR_EDGE = -0.35
# The arch: columns 0.5 across, so a 4.0 clear span.
SPRING = 3.25
RADIUS = 2.0
RING = 0.25                       # voussoirs, to radius 2.25: the ring meets the bay's edges
CENTRE = BAY / 2
ARC = 12
CORNICE = (5.5, 6.0)
CORNICE_OUT = -0.45
# The upper storey and its balcony window.
UPPER_BACK = 0.0
WINDOW = (1.25, 2.25)             # width, height; its sill on the balcony at 6.0
FRAME = 0.15
REVEAL = 0.0                      # the shutters stand back to here
BALCONY_OUT = -0.8
BALCONY_Z = 5.85
RAIL_H = 1.0
ROOF = 9.0
PARAPET = (9.6, 9.75)             # coping from, to
COPING_OUT = -0.35
# The shop door.
DOOR = (1.5, 2.75)
DOOR_FRAME = 0.2
DOOR_BACK = 4.15
# The beams and the column.
BEAM = 0.2
BEAMS_X = [0.75, 2.25, 3.75]
FLOOR_TILE = 1.5                  # floor, ceiling and roof are tiles sharing one island each


def _arc(radius, steps=ARC):
    """Points on the semicircle over the opening, from the left spring round to the right."""
    return [(CENTRE - radius * math.cos(math.pi * i / steps), SPRING + radius * math.sin(math.pi * i / steps))
            for i in range(steps + 1)]


def _xz(m, points, y, slot_name, facing):
    """A face in the plane y = const from (x, z) points counter-clockwise as
    seen from -y; turned round if it faces +y."""
    pts = [(x, y, z) for x, z in points]
    m.face(pts if facing < 0 else list(reversed(pts)), slot_name)


def _rect_xz(m, x0, x1, z0, z1, y, slot_name, facing):
    _xz(m, [(x0, z0), (x1, z0), (x1, z1), (x0, z1)], y, slot_name, facing)


def floor():
    """Tile slabs (shared island) on the arcade floor, the chiluca curb in front."""
    m = common.Mesh("bay_floor")
    tile = m  # one tile; repeat_faces lays the rest
    tile.face([(0, FLOOR_EDGE, FLOOR), (FLOOR_TILE, FLOOR_EDGE, FLOOR), (FLOOR_TILE, FLOOR_EDGE + FLOOR_TILE, FLOOR),
               (0, FLOOR_EDGE + FLOOR_TILE, FLOOR)], "tile_floor")
    obj = m.make()
    curb = common.Mesh("bay_floor_curb")
    _rect_xz(curb, 0, BAY, 0, FLOOR, FLOOR_EDGE, "chiluca", -1)
    curb.make()
    return obj


def ceiling():
    m = common.Mesh("bay_ceiling")
    # One strip between two beams' centres, facing down; repeated along x and y.
    w = BEAMS_X[1] - BEAMS_X[0]
    m.face([(0, WALL_BACK, CORNICE[0]), (0, WALL_BACK + 1.85, CORNICE[0]), (w, WALL_BACK + 1.85, CORNICE[0]),
            (w, WALL_BACK, CORNICE[0])], "lime")
    obj = m.make()
    beams = common.Mesh("bay_beams")

    for x in BEAMS_X:
        beams.box((x - BEAM / 2, WALL_BACK, CORNICE[0] - BEAM), (x + BEAM / 2, DEEP, CORNICE[0]), "wood_door",
                  skip=("-y", "+y", "+z"))

    beams.make()
    return obj


def roof():
    m = common.Mesh("bay_roof")
    m.face([(0, UPPER_BACK, ROOF), (FLOOR_TILE, UPPER_BACK, ROOF), (FLOOR_TILE, UPPER_BACK + 1.433, ROOF),
            (0, UPPER_BACK + 1.433, ROOF)], "lime")
    return m.make()


def rear():
    """The block's rear façade: plain lime-plaster from the street to the
    roof, facing away from the plaza (without it the block stands open
    behind). One 1.5 m tile; _tiles lays the rest, sharing its island."""
    m = common.Mesh("bay_back_exterior")
    m.face([(FLOOR_TILE, BACK_OUT, 0.0), (0.0, BACK_OUT, 0.0), (0.0, BACK_OUT, 1.5), (FLOOR_TILE, BACK_OUT, 1.5)], "lime")
    return m.make()


def column_stone(name="bay_column_stone"):
    m = common.Mesh(name)
    m.box((-0.3, -0.3, FLOOR), (0.3, 0.3, FLOOR + 0.2), "chiluca", skip=("-z",))
    m.tube((0, 0, FLOOR + 0.2), (0, 0, SPRING - 0.3), 0.25, 12, "chiluca", caps=(False, False))
    m.tube((0, 0, SPRING - 0.3), (0, 0, SPRING - 0.2), 0.29, 12, "chiluca", caps=(True, False))
    m.box((-0.325, -0.325, SPRING - 0.2), (0.325, 0.325, SPRING), "chiluca")
    return m.make()


def column_steel():
    """The seeped column: a riveted I-section on a base plate, an iron
    bracket for a capital, held to the old stone by a brass plate."""
    m = common.Mesh("bay_column_steel")
    z0, z1 = FLOOR + 0.03, SPRING - 0.25
    m.box((-0.3, -0.3, FLOOR), (0.3, 0.3, z0), "steel", skip=("-z",))
    # Flanges front and back (the arch's plane is x-z), the web between them.
    for y0, y1 in ((-0.2, -0.17), (0.17, 0.2)):
        m.box((-0.2, y0, z0), (0.2, y1, z1), "steel", skip=("-z", "+z"))

    m.box((-0.01, -0.17, z0), (0.01, 0.17, z1), "steel", skip=("-z", "+z", "-y", "+y"))
    # Rivets: two rows down the front flange.
    for x in (-0.13, 0.13):
        for i in range(7):
            z = z0 + 0.25 + i * (z1 - z0 - 0.5) / 6
            m.box((x - 0.018, -0.215, z - 0.018), (x + 0.018, -0.2, z + 0.018), "steel", skip=("+y",))

    m.box((-0.325, -0.325, z1), (0.325, 0.325, SPRING), "iron")
    # The patch over the bracket's front, a little crooked.
    a = math.radians(4)
    c = (0.0, (z1 + SPRING) / 2)
    pts = [(-0.24, -0.08), (0.24, -0.08), (0.24, 0.08), (-0.24, 0.08)]
    rot = [(c[0] + x * math.cos(a) - z * math.sin(a), c[1] + x * math.sin(a) + z * math.cos(a)) for x, z in pts]
    # A plate 4 cm thick on the bracket's face (laid flat on it, it would
    # fight it for depth at a distance).
    back, front = -0.325, -0.365
    m.face([(x, front, z) for x, z in rot], "brass")

    for i in range(4):
        (ax, az), (bx, bz) = rot[i], rot[(i + 1) % 4]
        m.face([(ax, back, az), (bx, back, bz), (bx, front, bz), (ax, front, az)], "brass")
    return m.make()


def arch():
    """The arch's ring and soffit, front and back."""
    m = common.Mesh("bay_arch")
    inner, outer = _arc(RADIUS), _arc(RADIUS + RING)

    for i in range(ARC):
        quad = [inner[i + 1], inner[i], outer[i], outer[i + 1]]
        _xz(m, quad[::-1], FRONT, "chiluca", -1)
        _xz(m, quad[::-1], WALL_BACK, "chiluca", 1)
        (ax, az), (bx, bz) = inner[i], inner[i + 1]
        # The soffit faces the arch's centre.
        m.face([(ax, FRONT, az), (ax, WALL_BACK, az), (bx, WALL_BACK, bz), (bx, FRONT, bz)], "chiluca")

    return m.make()


def spandrels():
    """The wall round the ring, up to the cornice: tezontle outside, lime in."""
    m = common.Mesh("bay_spandrels")
    outer = _arc(RADIUS + RING)
    outline = [(0, CORNICE[0]), (0, SPRING)] + outer[1:-1] + [(BAY, SPRING), (BAY, CORNICE[0])]
    _xz(m, list(reversed(outline)), FRONT, "tezontle", -1)
    _xz(m, list(reversed(outline)), WALL_BACK, "lime", 1)
    return m.make()


def cornice():
    m = common.Mesh("bay_cornice")
    m.box((0, CORNICE_OUT, CORNICE[0]), (BAY, WALL_BACK, CORNICE[1]), "chiluca", skip=("-x", "+x", "+y"))
    return m.make()


def upper():
    """The upper storey's front: tezontle round a chiluca-framed window, the
    reveals, the shutters, the parapet's face to its coping."""
    w, h = WINDOW
    x0, x1 = CENTRE - w / 2, CENTRE + w / 2
    sill, head = CORNICE[1], CORNICE[1] + h
    f0, f1, top = x0 - FRAME, x1 + FRAME, head + FRAME
    wall = common.Mesh("bay_upper_wall")
    _rect_xz(wall, 0, f0, sill, PARAPET[0], FRONT, "tezontle", -1)
    _rect_xz(wall, f1, BAY, sill, PARAPET[0], FRONT, "tezontle", -1)
    _rect_xz(wall, f0, f1, top, PARAPET[0], FRONT, "tezontle", -1)
    wall.make()

    win = common.Mesh("bay_window")
    _rect_xz(win, f0, x0, sill, top, FRONT, "chiluca", -1)
    _rect_xz(win, x1, f1, sill, top, FRONT, "chiluca", -1)
    _rect_xz(win, x0, x1, head, top, FRONT, "chiluca", -1)
    # Reveals: the jambs face into the opening, the soffit down.
    win.face([(x0, FRONT, sill), (x0, REVEAL, sill), (x0, REVEAL, head), (x0, FRONT, head)], "chiluca")
    win.face([(x1, FRONT, sill), (x1, FRONT, head), (x1, REVEAL, head), (x1, REVEAL, sill)], "chiluca")
    win.face([(x0, FRONT, head), (x0, REVEAL, head), (x1, REVEAL, head), (x1, FRONT, head)], "chiluca")
    # The sill is the cornice's top.
    _rect_xz(win, x0, x1, sill, head, REVEAL, "wood_door", -1)
    win.make()

    balcony = common.Mesh("bay_balcony")
    balcony.box((f0 - 0.15, BALCONY_OUT, BALCONY_Z), (f1 + 0.15, CORNICE_OUT, sill), "chiluca", skip=("+y",))
    balcony.make()

    rails = common.Mesh("bay_rails")
    bx0, bx1, by = f0 - 0.1, f1 + 0.1, BALCONY_OUT + 0.05
    r = 0.025

    for x in [bx0 + i * (bx1 - bx0) / 3 for i in range(4)]:
        rails.tube((x, by, sill), (x, by, sill + RAIL_H), r, 6, "steel", caps=(False, True))

    for z in (sill + RAIL_H / 2, sill + RAIL_H - r):
        # Run past the corners by a radius, so the welds close.
        rails.tube((bx0 - r, by, z), (bx1 + r, by, z), r, 6, "steel", caps=(True, True))

        for x in (bx0, bx1):
            rails.tube((x, by - r, z), (x, FRONT, z), r, 6, "steel")

    rails.make()

    parapet = common.Mesh("bay_parapet")
    parapet.box((0, COPING_OUT, PARAPET[0]), (BAY, UPPER_BACK, PARAPET[1]), "chiluca", skip=("-x", "+x"))
    _rect_xz(parapet, 0, BAY, ROOF, PARAPET[0], UPPER_BACK, "tezontle", 1)
    parapet.make()


def shop():
    """The back of the arcade: a lime-washed shop front, a chiluca door frame,
    the door set back in its reveals."""
    w, h = DOOR
    x0, x1 = CENTRE - w / 2, CENTRE + w / 2
    d0, d1, top = x0 - DOOR_FRAME, x1 + DOOR_FRAME, FLOOR + h + DOOR_FRAME
    # The left half (wall, jamb, reveal); the right half is its mirror about
    # the door's middle, made after unwrapping so the two share islands.
    back = common.Mesh("bay_back_wall")
    _rect_xz(back, 0, d0, FLOOR, CORNICE[0], DEEP, "lime", -1)
    _rect_xz(back, d0, d1, top, CORNICE[0], DEEP, "lime", -1)
    _rect_xz(back, d0, x0, FLOOR, top, DEEP, "chiluca", -1)
    _rect_xz(back, x0, x1, FLOOR + h, top, DEEP, "chiluca", -1)
    back.face([(x0, DEEP, FLOOR), (x0, DOOR_BACK, FLOOR), (x0, DOOR_BACK, FLOOR + h), (x0, DEEP, FLOOR + h)], "chiluca")
    back.face([(x0, DEEP, FLOOR + h), (x0, DOOR_BACK, FLOOR + h), (x1, DOOR_BACK, FLOOR + h), (x1, DEEP, FLOOR + h)], "chiluca")
    back_obj = back.make()
    door = common.Mesh("bay_door")
    _rect_xz(door, x0, x1, FLOOR, FLOOR + h, DOOR_BACK, "wood_door", -1)
    door.make()
    return back_obj


def end_column():
    """The run's closing column at its own x = 0, with the caps that close the
    walls' ends there (facing +x); and the run's start caps (facing -x)."""
    column_stone("bay_end_column")
    sections = [  # (y0, y1, z0, z1): the bay's cross-section, no two overlapping
        (FLOOR_EDGE, DEEP, 0, FLOOR),
        (DEEP, BACK_OUT, FLOOR, CORNICE[0]),
        (FRONT, WALL_BACK, SPRING, CORNICE[0]),
        (CORNICE_OUT, WALL_BACK, CORNICE[0], CORNICE[1]),
        (WALL_BACK, BACK_OUT, CORNICE[0], CORNICE[1]),
        (FRONT, BACK_OUT, CORNICE[1], ROOF),
        (FRONT, UPPER_BACK, ROOF, PARAPET[0]),
        (COPING_OUT, UPPER_BACK, PARAPET[0], PARAPET[1]),
    ]

    m = common.Mesh("bay_end_caps")

    for y0, y1, z0, z1 in sections:
        m.face([(0, y0, z0), (0, y1, z0), (0, y1, z1), (0, y0, z1)], "tezontle")   # faces +x

    # The start caps are these turned round (made after unwrapping: one island).
    return m.make()


# The joint renders show the stone bay at a run's start unless told otherwise.
HIDDEN = ("bay_column_steel", "bay_end_column", "bay_end_caps")
STEEL = ("bay_column_stone", "bay_end_column", "bay_end_caps", "bay_start_caps")

# Where to look at each of the card's joints: (eye, target[, hidden]), Blender metres.
JOINTS = {
    "01_column_base": ((1.2, -1.4, 1.0), (0.0, 0.0, 0.35)),
    "02_capital_springer": ((1.0, -1.6, 2.6), (0.1, 0.0, 3.25)),
    "02b_steel_springer": ((1.0, -1.6, 2.6), (0.1, 0.0, 3.25), STEEL),
    "03_voussoirs_spandrel": ((0.8, -2.5, 3.0), (0.6, -0.3, 4.4)),
    "04_keystone": ((2.25, -2.6, 4.2), (2.25, -0.3, 5.3)),
    "05_arch_cornice": ((3.6, -2.4, 5.0), (3.5, -0.3, 5.6)),
    "06_cornice_upper_wall": ((0.8, -2.4, 6.4), (1.0, -0.3, 6.1)),
    "07_window_frame": ((2.6, -2.6, 7.6), (2.0, -0.3, 7.3)),
    "08_balcony_wall": ((3.9, -2.0, 5.4), (3.2, -0.5, 5.95)),
    "09_rails_slab": ((3.8, -2.2, 7.0), (3.2, -0.75, 6.4)),
    "10_parapet_coping": ((2.0, -2.0, 10.4), (1.5, -0.2, 9.6)),
    "11_beams_walls": ((2.0, 2.0, 3.8), (0.75, 0.4, 5.4)),
    "12_back_wall_floor": ((2.6, 2.4, 1.0), (1.0, 4.0, 0.3)),
    "13_door_frame": ((2.0, 2.2, 1.8), (2.25, 4.0, 2.0)),
    "14_steel_patch": ((0.6, -1.3, 2.9), (0.0, -0.3, 3.1), STEEL),
    "14b_steel_base": ((1.2, -1.4, 1.0), (0.0, 0.0, 0.35), STEEL),
    "15_bay_seam": ((4.5, -2.4, 4.6), (4.5, -0.3, 4.6), HIDDEN, (BAY, 0, 0)),
    "15b_bay_seam_inside": ((3.0, 2.0, 2.0), (4.5, 0.3, 4.0), HIDDEN, (BAY, 0, 0)),
}


# The vertex paint (tools/eclipse/weather.py): damp lines from the street,
# the balcony window's jambs and head (the door's sit on the grid already);
# soot over the shop door and the window.
WINDOW_X = (CENTRE - WINDOW[0] / 2, CENTRE + WINDOW[0] / 2)
WINDOW_HEAD = 6.0 + WINDOW[1]
WEATHER = {"lines": [("z", 0.3), ("z", 1.2), ("x", WINDOW_X[0]), ("x", WINDOW_X[1]), ("z", WINDOW_HEAD)],
           "blendable": ["lime", "iron"]}


def soot():
    for name, place in (("soot_door", (CENTRE, DEEP - 0.05, FLOOR + DOOR[1])),
                        ("soot_window", (CENTRE, UPPER_BACK - 0.05, WINDOW_HEAD))):
        empty = bpy.data.objects.new(name, None)
        bpy.context.scene.collection.objects.link(empty)
        empty.location = place


def build():
    common.reset()
    tiles = (floor(), ceiling(), roof(), rear())
    column_stone()
    column_steel()
    arch()
    spandrels()
    cornice()
    upper()
    back = shop()
    caps = end_column()
    soot()
    return tiles, back, caps


def _tiles(floor_tile, ceiling_strip, roof_tile, back_tile):
    """The floor, ceiling and roof laid from their one tile each."""
    along = [i * FLOOR_TILE for i in range(3)]
    common.repeat_faces(floor_tile, [(x, y * FLOOR_TILE, 0) for x in along for y in range(3)
                                     if (x, y) != (0, 0)])
    w = BEAMS_X[1] - BEAMS_X[0]
    common.repeat_faces(ceiling_strip, [(x * w, y * 1.85, 0) for x in range(3) for y in range(2) if (x, y) != (0, 0)])
    common.repeat_faces(roof_tile, [(x, y * 1.433, 0) for x in along for y in range(3) if (x, y) != (0, 0)])
    common.repeat_faces(back_tile, [(x, 0, z * 1.5) for x in along for z in range(6) if (x, z) != (0, 0)])


ALTERNATES = ("bay_column_stone", "bay_column_steel", "bay_end_column", "bay_end_caps", "bay_start_caps")


def gate_sets():
    """What is seen together: the bay with its stone column, with its steel
    one, and the run's end pieces on their own."""
    bay = [o.name for o in common.meshes() if o.name not in ALTERNATES]
    return [bay + ["bay_column_stone", "bay_start_caps"], bay + ["bay_column_steel"], ["bay_end_column", "bay_end_caps"]]


class _Sets:
    """gate_sets(), read when the gate runs (after the start caps are made)."""

    def __iter__(self):
        return iter(gate_sets())


def _shifted(faces, dx, tag):
    return [{"owner": tag + f["owner"], "normal": f["normal"], "points": [(x + dx, y, z) for x, y, z in f["points"]]}
            for f in faces]


def _gate_two_bays():
    """A run: a stone bay, a steel bay 4.5 m along, and the end piece at 9 m;
    none may fight another."""
    by_name = {o.name: o for o in common.meshes()}
    first, steel, end = gate_sets()
    a, _, uvs = common.dump_faces([by_name[n] for n in first])
    b, _, _ = common.dump_faces([by_name[n] for n in steel])
    c, _, _ = common.dump_faces([by_name[n] for n in end])
    problems = gate.check(a + _shifted(b, BAY, "next_") + _shifted(c, 2 * BAY, "end_"), 0, uvs)

    for p in problems:
        print("%s: two bays: %s" % (NAME, p))

    if problems:
        sys.exit(1)

    print("%s: two bays clean" % NAME)


def main():
    tiles, back, caps = build()

    def merge():
        _tiles(*tiles)
        # Only the left half: the pieces across the middle (the band, the
        # lintel, the head) mirrored onto themselves would lie twice in one place.
        common.mirror_faces(back, lambda f: f.calc_center_median().x < CENTRE - 0.01, about=CENTRE)
        common.turned_copy(caps, "bay_start_caps")

    common.export_piece(NAME, ATLAS, SLOTS, merge=merge, gate_sets=_Sets(),
                        share=[("bay_end_caps", "bay_start_caps")], weather=WEATHER)
    _gate_two_bays()


if __name__ == "__main__":
    main()
