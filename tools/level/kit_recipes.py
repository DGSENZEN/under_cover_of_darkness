"""The level kit (tools/level): every piece a level is built from.

Pure data (no Blender): `kit.py` builds assets/level/source/kit.blend from it,
`check.py` reads its metrics, `export.py` its colliders.

A piece is described in Godot's axes (x right, y up, z toward you), its
pivot at the middle of its footprint on the floor, its length along x and
its depth (a wall's thickness) along z:

    {"family": "wall", "slot": "ashlar", "surface": "stone",
     "boxes": [[cx, cy, cz, sx, sy, sz, slot, yaw, pitch, roll], ...],
     "cols":  [[cx, cy, cz, sx, sy, sz, surface, yaw, pitch, roll], ...],
     "sockets": {"torch": [[x, y, z], ...]},
     "size": [length, height, depth],
     "opening": [width, height] or None}

Kit v0 (stage 1) is every piece as plain boxes at its true size; kit v1
(the art pass) models the same pieces under the same names, so a level
built from v0 updates without being placed again. On a 0.25 m grid;
metrics from the canal-quarter spec, section 5 (storey 3.0 m, outer walls
0.4 m, partitions 0.2 m, doors 1.2 x 2.2 m, windows 0.9 x 1.3 m with sills
at 0.9 m, stairs 0.3 m treads and 0.2 m risers).
"""

import math

import kit_shapes as ks

STOREY = 3.0
OUTER = 0.4
INNER = 0.2
DOOR = (1.2, 2.2)
WINDOW = (0.9, 1.3, 0.9)
ARCH = (1.8, 2.6)
TREAD = 0.3
RISER = 0.2
# The curtain wall: its walk on top, how thick, the parapet.
CURTAIN_HEIGHT = 5.0
CURTAIN_DEPTH = 2.4
PARAPET = 1.1

# Wall materials: the photo slot each is drawn with, and what it sounds like.
WALLS = {
    "ashlar": ("ashlar", "stone"),
    "rubble": ("stone", "stone"),
    "plaster": ("plaster", "stone"),
    "timber": ("timber", "wood"),
    # The city's: granite (the harbour's customs house, its quay walls) and
    # ochre render.
    "granite": ("granite", "stone"),
    "render": ("render_ochre", "stone"),
}

PIECES = {}


def box(cx, cy, cz, sx, sy, sz, slot, yaw=0.0, pitch=0.0, roll=0.0):
    return [cx, cy, cz, sx, sy, sz, slot, yaw, pitch, roll]


def piece(name, family, slot, surface, boxes, cols=None, sockets=None, size=None, opening=None):
    """A piece; its colliders are its boxes (each with the piece's surface)
    unless given."""
    if cols is None:
        cols = [b[:6] + [surface] + b[7:] for b in boxes]

    PIECES[name] = {
        "family": family, "slot": slot, "surface": surface, "boxes": boxes, "cols": cols,
        "sockets": sockets or {}, "size": size, "opening": opening, "shapes": None,
    }


def model(name, shapes):
    """Kit v1: `name` drawn with `shapes` (kit_shapes) instead of its boxes;
    its colliders stay its boxes'."""
    PIECES[name]["shapes"] = shapes


# Walls: plain runs, a door, a window, an arch, an arrow slit, a corner post;
# one storey high, OUTER thick (INNER for the partitions).

def _with_opening(width, depth, height, gap_w, gap_h, sill, slot):
    """A wall `width` long with a hole gap_w x gap_h from `sill` up."""
    side = (width - gap_w) / 2.0
    out = [
        box(-(gap_w + side) / 2.0, height / 2.0, 0.0, side, height, depth, slot),
        box((gap_w + side) / 2.0, height / 2.0, 0.0, side, height, depth, slot),
    ]
    top = height - sill - gap_h

    if top > 0.0:
        out.append(box(0.0, sill + gap_h + top / 2.0, 0.0, gap_w, top, depth, slot))

    if sill > 0.0:
        out.append(box(0.0, sill / 2.0, 0.0, gap_w, sill, depth, slot))

    return out


for material, (slot, surface) in WALLS.items():
    for depth, suffix in ((OUTER, ""), (INNER, "_thin")):
        for length, label in ((1.0, "1"), (2.0, "2"), (2.4, "2p4"), (4.0, "4")):
            piece("wall_%s%s_%s" % (material, suffix, label), "wall", slot, surface,
                  [box(0.0, STOREY / 2.0, 0.0, length, STOREY, depth, slot)],
                  size=[length, STOREY, depth])

        piece("wall_%s%s_door" % (material, suffix), "wall", slot, surface,
              _with_opening(2.0, depth, STOREY, DOOR[0], DOOR[1], 0.0, slot),
              sockets={"torch": [[1.0, 2.3, depth / 2.0 + 0.3]]}, size=[2.0, STOREY, depth], opening=list(DOOR))
        piece("wall_%s%s_window" % (material, suffix), "wall", slot, surface,
              _with_opening(2.0, depth, STOREY, WINDOW[0], WINDOW[1], WINDOW[2], slot),
              size=[2.0, STOREY, depth], opening=[WINDOW[0], WINDOW[1]])
        piece("wall_%s%s_arch" % (material, suffix), "wall", slot, surface,
              _with_opening(2.4, depth, STOREY, ARCH[0], ARCH[1], 0.0, slot),
              size=[2.4, STOREY, depth], opening=list(ARCH))

    piece("wall_%s_slit" % material, "wall", slot, surface,
          _with_opening(1.0, OUTER, STOREY, 0.15, 1.2, 1.1, slot), size=[1.0, STOREY, OUTER])
    piece("wall_%s_corner" % material, "wall", slot, surface,
          [box(0.0, STOREY / 2.0, 0.0, OUTER, STOREY, OUTER, slot)], size=[OUTER, STOREY, OUTER])

# A low wall: the top of a storey that stops under a floor 1.8 m up (the
# gatehouse's passage walls, under its walk).
LOW = 1.8

for length, label in ((1.0, "1"), (2.0, "2"), (4.0, "4")):
    piece("wall_ashlar_low_%s" % label, "wall", "ashlar", "stone", [box(0.0, LOW / 2.0, 0.0, length, LOW, OUTER, "ashlar")], size=[length, LOW, OUTER])

# A tall wall: two storeys in one (the chapel's, the gatehouse's front).
for material, (slot, surface) in WALLS.items():
    piece("wall_%s_tall_2" % material, "wall", slot, surface,
          [box(0.0, STOREY, 0.0, 2.0, STOREY * 2.0, OUTER, slot)], size=[2.0, STOREY * 2.0, OUTER])
    piece("wall_%s_tall_lancet" % material, "wall", slot, surface,
          _with_opening(2.0, OUTER, STOREY * 2.0, 0.9, 3.6, 1.8, slot), size=[2.0, STOREY * 2.0, OUTER], opening=[0.9, 3.6])

# The curtain wall: a walk on top (CURTAIN_HEIGHT), a crenellated parapet on
# its outer (+z) side; a gap for the gate; a corner block.

def _curtain(length, slot="ashlar"):
    out = [box(0.0, CURTAIN_HEIGHT / 2.0, 0.0, length, CURTAIN_HEIGHT, CURTAIN_DEPTH, slot)]
    merlons = int(round(length))

    for i in range(merlons):
        x = -length / 2.0 + (i + 0.5) * (length / merlons)
        out.append(box(x, CURTAIN_HEIGHT + PARAPET / 2.0, CURTAIN_DEPTH / 2.0 - 0.25, length / merlons * 0.55, PARAPET, 0.5, slot))

    out.append(box(0.0, CURTAIN_HEIGHT + 0.35, CURTAIN_DEPTH / 2.0 - 0.25, length, 0.7, 0.5, slot))
    return out


for length in (2, 4):
    piece("curtain_%d" % length, "curtain", "ashlar", "stone", _curtain(float(length)),
          size=[float(length), CURTAIN_HEIGHT + PARAPET, CURTAIN_DEPTH])

# The postern: a curtain segment with a door-sized tunnel through it (the walk
# carries on over it).
_postern = [box(-1.3, CURTAIN_HEIGHT / 2.0, 0.0, 1.4, CURTAIN_HEIGHT, CURTAIN_DEPTH, "ashlar"),
            box(1.3, CURTAIN_HEIGHT / 2.0, 0.0, 1.4, CURTAIN_HEIGHT, CURTAIN_DEPTH, "ashlar"),
            box(0.0, (CURTAIN_HEIGHT + DOOR[1]) / 2.0, 0.0, 1.2, CURTAIN_HEIGHT - DOOR[1], CURTAIN_DEPTH, "ashlar")]
piece("curtain_postern_4", "curtain", "ashlar", "stone", _postern + _curtain(4.0)[1:],
      size=[4.0, CURTAIN_HEIGHT + PARAPET, CURTAIN_DEPTH], opening=list(DOOR))

# A breach: a curtain segment whose parapet has fallen in the middle (a gap
# of BREACH over the outer face, its stones lying on the walk's inner edge).
BREACH = 2.0
_breach = [box(0.0, CURTAIN_HEIGHT / 2.0, 0.0, 4.0, CURTAIN_HEIGHT, CURTAIN_DEPTH, "ashlar")]

for side in (-1.0, 1.0):
    _breach.append(box(side * (BREACH / 2.0 + 0.5), CURTAIN_HEIGHT + PARAPET / 2.0, CURTAIN_DEPTH / 2.0 - 0.25, 1.0, PARAPET, 0.5, "ashlar"))
    _breach.append(box(side * (BREACH / 2.0 + 0.2), CURTAIN_HEIGHT + 0.15, CURTAIN_DEPTH / 2.0 - 0.3, 0.5, 0.3, 0.4, "stone", side * 20.0))

_breach.append(box(0.3, CURTAIN_HEIGHT + 0.12, -CURTAIN_DEPTH / 2.0 + 0.3, 0.45, 0.24, 0.35, "stone", 35.0))
piece("curtain_breach_4", "curtain", "ashlar", "stone", _breach, size=[4.0, CURTAIN_HEIGHT + PARAPET, CURTAIN_DEPTH])

piece("curtain_corner", "curtain", "ashlar", "stone",
      [box(0.0, CURTAIN_HEIGHT / 2.0, 0.0, CURTAIN_DEPTH, CURTAIN_HEIGHT, CURTAIN_DEPTH, "ashlar"),
       box(0.0, CURTAIN_HEIGHT + PARAPET / 2.0, 0.0, CURTAIN_DEPTH, PARAPET, CURTAIN_DEPTH, "ashlar")],
      cols=[[0.0, CURTAIN_HEIGHT / 2.0, 0.0, CURTAIN_DEPTH, CURTAIN_HEIGHT, CURTAIN_DEPTH, "stone", 0, 0, 0]],
      size=[CURTAIN_DEPTH, CURTAIN_HEIGHT + PARAPET, CURTAIN_DEPTH])

# Floors (their top at the pivot), ceilings, a roof slope.

FLOORS = {"cobble": ("cobble", "stone"), "flag": ("flagstone", "stone"), "board": ("boards", "wood"),
          "grass": ("grass", "grass"), "mud": ("mud", "dirt"), "gravel": ("gravel", "gravel"),
          "carpet": ("carpet", "carpet"),
          # The city's: the Terreiro's calcada, granite (quays, naves, the
          # Sea Gate's passage), terracotta (houses, the customs house).
          "calcada": ("calcada", "stone"), "granite": ("granite", "stone"), "terracotta": ("terracotta", "stone")}

for kind, (slot, surface) in FLOORS.items():
    for size in (2, 4):
        piece("floor_%s_%d" % (kind, size), "floor", slot, surface,
              [box(0.0, -0.1, 0.0, float(size), 0.2, float(size), slot)], size=[float(size), 0.2, float(size)])

# A strip of flags 4 x 1 m: a floor ended flush with a wall's face.
piece("floor_flag_strip_4", "floor", "flagstone", "stone", [box(0.0, -0.1, 0.0, 4.0, 0.2, 1.0, "flagstone")], size=[4.0, 0.2, 1.0])

# A ceiling under a pitched roof (boards, its underside the room's ceiling):
# its colliders stop sight and what is thrown, but it is never walked on
# (surface "ceiling": LevelLoader leaves it out of the navmesh).
for size in (2, 4):
    piece("ceiling_board_%d" % size, "ceiling", "boards", "ceiling",
          [box(0.0, -0.1, 0.0, float(size), 0.2, float(size), "boards")], size=[float(size), 0.2, float(size)])

for size in (2, 4):
    piece("roof_slope_%d" % size, "roof", "slate", "stone",
          [box(0.0, 0.0, 0.0, float(size), 0.2, float(size) * math.sqrt(2.0), "slate", 0.0, 45.0, 0.0)],
          size=[float(size), float(size), float(size)])
    piece("beam_%d" % size, "beam", "timber", "wood",
          [box(0.0, 0.0, 0.0, float(size), 0.25, 0.25, "timber")], size=[float(size), 0.25, 0.25])

# Stairs: a straight flight up one storey (along +z from its pivot, 1.2 m
# wide); a spiral turn (a quarter turn, a quarter storey, round a post).

_steps = int(round(STOREY / RISER))
piece("stair_straight", "stair", "flagstone", "stone",
      [box(0.0, (i + 1) * RISER / 2.0, i * TREAD + TREAD / 2.0, 1.2, (i + 1) * RISER, TREAD, "flagstone") for i in range(_steps)],
      size=[1.2, STOREY, _steps * TREAD])

# A tower's steep flight: a storey in 3 m (0.25 risers and treads), so a
# flight runs from one corner landing to the next inside a tower 7.2 m
# across (the ordinary flight's 4.5 m ran under the next landing).
TOWER_STEP = 0.25
_tower_steps = int(round(STOREY / TOWER_STEP))
piece("stair_tower", "stair", "flagstone", "stone",
      [box(0.0, (i + 1) * TOWER_STEP / 2.0, i * TOWER_STEP + TOWER_STEP / 2.0, 1.3, (i + 1) * TOWER_STEP, TOWER_STEP, "flagstone") for i in range(_tower_steps)],
      size=[1.3, STOREY, _tower_steps * TOWER_STEP])

# The flight up to the wall-walk (CURTAIN_HEIGHT), 1.4 m wide.
_curtain_steps = int(round(CURTAIN_HEIGHT / RISER))
piece("stair_curtain", "stair", "ashlar", "stone",
      [box(0.0, (i + 1) * RISER / 2.0, i * TREAD + TREAD / 2.0, 1.4, (i + 1) * RISER, TREAD, "ashlar") for i in range(_curtain_steps)],
      size=[1.4, CURTAIN_HEIGHT, _curtain_steps * TREAD])
# A landing at the head of a wall's flight, as wide as the flight: its top
# at the pivot, running into the walk beside it.
piece("landing_walk", "floor", "ashlar", "stone", [box(0.0, -0.15, 0.0, 1.4, 0.3, 1.4, "ashlar")], size=[1.4, 0.3, 1.4])
# A landing: a slab whose top is at the pivot, 2 x 2 m.
piece("landing_2", "floor", "flagstone", "stone", [box(0.0, -0.15, 0.0, 2.0, 0.3, 2.0, "flagstone")], size=[2.0, 0.3, 2.0])

_spiral = []

for i in range(4):
    angle = i * 22.5
    a = math.radians(angle + 11.25)
    _spiral.append(box(math.sin(a) * 1.0, (i + 1) * RISER - RISER / 2.0, math.cos(a) * 1.0, 1.4, RISER, 0.55, "flagstone", angle, 0.0, 0.0))

_spiral.append(box(0.0, 0.5, 0.0, 0.4, 1.0, 0.4, "ashlar"))
piece("stair_spiral_quarter", "stair", "flagstone", "stone", _spiral, size=[3.0, 4 * RISER, 3.0])

# Columns and arches (the colonnade), vault ribs, a buttress.

piece("column", "column", "ashlar", "stone", [box(0.0, STOREY / 2.0, 0.0, 0.45, STOREY, 0.45, "ashlar")], size=[0.45, STOREY, 0.45])
piece("arch_span_3", "column", "ashlar", "stone", [box(0.0, STOREY - 0.3, 0.0, 3.0, 0.6, 0.45, "ashlar")], size=[3.0, 0.6, 0.45])
piece("rib_8", "vault", "ashlar", "stone", [box(0.0, 0.0, 0.0, 8.0, 0.35, 0.35, "ashlar")], cols=[], size=[8.0, 0.35, 0.35])
piece("buttress", "column", "ashlar", "stone", [box(0.0, STOREY, 0.0, 0.8, STOREY * 2.0, 1.2, "ashlar")], size=[0.8, STOREY * 2.0, 1.2])

# The quay: its wall down to the water, steps, a post, a boat, the crane.

piece("quay_wall_4", "quay", "stone", "stone", [box(0.0, -1.25, 0.0, 4.0, 2.5, 1.0, "stone")], size=[4.0, 2.5, 1.0])
piece("quay_steps", "quay", "stone", "stone",
      [box(0.0, -0.2 - i * 0.2 - 0.1, i * TREAD, 1.6, 0.2 + i * 0.0, TREAD, "stone") for i in range(8)], size=[1.6, 1.6, 8 * TREAD])
piece("mooring_post", "quay", "timber", "wood", [box(0.0, 0.5, 0.0, 0.3, 1.0, 0.3, "timber")], size=[0.3, 1.0, 0.3])
piece("boat", "quay", "boards", "wood",
      [box(0.0, -0.9, 0.0, 1.6, 0.5, 5.0, "boards"), box(0.0, -0.55, 0.0, 1.8, 0.2, 5.2, "boards")], cols=[], size=[1.8, 0.7, 5.2])
piece("crane", "quay", "timber", "wood",
      [box(0.0, 3.0, 0.0, 0.4, 6.0, 0.4, "timber"), box(0.0, 5.8, 1.5, 0.3, 0.3, 3.4, "timber")],
      cols=[[0.0, 3.0, 0.0, 0.4, 6.0, 0.4, "wood", 0, 0, 0]], size=[0.4, 6.0, 3.4])

# Dressing: what the men sleep on, eat at, drill at, pray at, and the rest.

def _thing(name, slot, surface, boxes, solid=True, sockets=None):
    cols = None if solid else []
    size_x = max(abs(b[0]) + b[3] / 2.0 for b in boxes) * 2.0
    size_y = max(b[1] + b[4] / 2.0 for b in boxes)
    size_z = max(abs(b[2]) + b[5] / 2.0 for b in boxes) * 2.0
    piece(name, "dressing", slot, surface, boxes, cols=cols, sockets=sockets, size=[size_x, size_y, size_z])


_thing("bunk", "boards", "wood", [box(0.0, 0.35, 0.0, 0.9, 0.1, 2.0, "boards"), box(0.0, 1.45, 0.0, 0.9, 0.1, 2.0, "boards"),
                                  box(-0.42, 1.0, -0.95, 0.08, 2.0, 0.08, "timber"), box(0.42, 1.0, -0.95, 0.08, 2.0, 0.08, "timber"),
                                  box(-0.42, 1.0, 0.95, 0.08, 2.0, 0.08, "timber"), box(0.42, 1.0, 0.95, 0.08, 2.0, 0.08, "timber")])
_thing("table_long", "boards", "wood", [box(0.0, 0.75, 0.0, 4.0, 0.08, 0.9, "boards"), box(-1.8, 0.37, 0.0, 0.12, 0.74, 0.7, "timber"),
                                        box(1.8, 0.37, 0.0, 0.12, 0.74, 0.7, "timber")])
_thing("bench", "boards", "wood", [box(0.0, 0.45, 0.0, 3.0, 0.08, 0.35, "boards"), box(-1.3, 0.22, 0.0, 0.1, 0.44, 0.3, "timber"),
                                   box(1.3, 0.22, 0.0, 0.1, 0.44, 0.3, "timber")])
_thing("pew", "boards", "wood", [box(0.0, 0.45, 0.0, 2.4, 0.08, 0.45, "boards"), box(0.0, 0.85, 0.2, 2.4, 0.8, 0.06, "boards"),
                                 box(-1.15, 0.5, 0.0, 0.08, 1.0, 0.5, "boards"), box(1.15, 0.5, 0.0, 0.08, 1.0, 0.5, "boards")])
_thing("altar", "ashlar", "stone", [box(0.0, 0.5, 0.0, 2.4, 1.0, 1.0, "ashlar"), box(0.0, 1.03, 0.0, 2.6, 0.06, 1.1, "carpet")],
       sockets={"candle": [[-0.9, 1.1, 0.0], [0.9, 1.1, 0.0]]})
_thing("rack", "timber", "wood", [box(0.0, 0.9, 0.0, 2.0, 1.8, 0.3, "timber")])
_thing("straw_man", "straw", "dirt", [box(0.0, 0.9, 0.0, 0.1, 1.8, 0.1, "timber"), box(0.0, 1.3, 0.0, 0.5, 0.7, 0.3, "straw")])
_thing("grindstone", "stone", "stone", [box(0.0, 0.45, 0.0, 0.6, 0.9, 0.5, "stone")])
_thing("barrel", "boards", "wood", [box(0.0, 0.45, 0.0, 0.6, 0.9, 0.6, "boards")])
_thing("crate", "boards", "wood", [box(0.0, 0.35, 0.0, 0.7, 0.7, 0.7, "boards")])
_thing("sacks", "cloth", "dirt", [box(0.0, 0.25, 0.0, 1.2, 0.5, 0.8, "cloth")])
_thing("cart", "boards", "wood", [box(0.0, 0.8, 0.0, 1.6, 0.1, 3.0, "boards"), box(-0.85, 0.5, 0.4, 0.1, 1.0, 1.0, "timber"),
                                  box(0.85, 0.5, 0.4, 0.1, 1.0, 1.0, "timber")])
_thing("well", "stone", "stone", [box(0.0, 0.45, 0.0, 1.6, 0.9, 1.6, "stone"), box(0.0, 2.2, 0.0, 1.8, 0.15, 0.2, "timber")])
_thing("hearth", "ashlar", "stone", [box(0.0, 1.4, 0.0, 3.0, 2.8, 1.0, "ashlar"), box(0.0, 0.1, 0.6, 2.0, 0.2, 0.6, "stone")],
       sockets={"fire": [[0.0, 0.3, 0.6]]})
_thing("stove", "iron", "metal", [box(0.0, 0.5, 0.0, 0.8, 1.0, 0.8, "iron")], sockets={"fire": [[0.0, 0.6, 0.45]]})
_thing("map_table", "boards", "wood", [box(0.0, 0.85, 0.0, 1.8, 0.08, 1.2, "boards"), box(0.0, 0.42, 0.0, 0.3, 0.84, 0.3, "timber")])
_thing("bed", "boards", "wood", [box(0.0, 0.3, 0.0, 1.2, 0.3, 2.1, "boards")])
_thing("bedroll", "cloth", "dirt", [box(0.0, 0.03, 0.0, 0.9, 0.06, 2.0, "cloth")], solid=False)
_thing("candle_stand", "iron", "metal", [box(0.0, 0.7, 0.0, 0.2, 1.4, 0.2, "iron")], sockets={"candle": [[0.0, 1.45, 0.0]]})
_thing("banner", "cloth", "dirt", [box(0.0, 1.6, 0.0, 1.0, 2.4, 0.04, "cloth")], solid=False)
_thing("chandelier", "iron", "metal", [box(0.0, 0.0, 0.0, 1.6, 0.1, 1.6, "iron"), box(0.0, 1.5, 0.0, 0.05, 3.0, 0.05, "iron")], solid=False,
       sockets={"candle": [[math.sin(i * math.tau / 6) * 0.7, 0.1, math.cos(i * math.tau / 6) * 0.7] for i in range(6)]})
_thing("woodpile", "timber", "wood", [box(0.0, 0.5, 0.0, 2.4, 1.0, 1.0, "timber")])
_thing("chopping_block", "timber", "wood", [box(0.0, 0.3, 0.0, 0.6, 0.6, 0.6, "timber")])
_thing("chest", "boards", "wood", [box(0.0, 0.3, 0.0, 1.0, 0.6, 0.6, "boards")])
_thing("fire_ring", "stone", "stone", [box(0.0, 0.1, 0.0, 1.6, 0.2, 1.6, "stone")], sockets={"fire": [[0.0, 0.25, 0.0]]})
_thing("portcullis", "iron", "metal", [box(0.0, 2.5, 0.0, 4.0, 5.0, 0.15, "iron")], solid=False)
_thing("bush", "leaves", "grass", [box(0.0, 0.6, 0.0, 1.6, 1.2, 1.6, "leaves")], solid=False)
_thing("tree", "bark", "wood", [box(0.0, 2.0, 0.0, 0.5, 4.0, 0.5, "bark"), box(0.0, 5.0, 0.0, 3.5, 3.0, 3.5, "leaves")])

# Foreground to frame through (the references' rule 7): a palisade fence, a
# lattice screen (a brazier behind it throws silhouettes), a railing, a
# balcony; a lit window panel (an emissive stand-in until the art pass).
_thing("palisade_2", "timber", "wood", [box(-0.75 + i * 0.3, 1.1, 0.0, 0.2, 2.2, 0.2, "timber") for i in range(6)])
_thing("lattice_screen", "timber", "wood", [box(0.0, 1.2, 0.0, 2.0, 0.08, 0.06, "timber")] + [box(-0.9 + i * 0.3, 1.2, 0.0, 0.05, 2.4, 0.05, "timber") for i in range(7)] +
       [box(0.0, 0.1 + i * 0.4, 0.0, 2.0, 0.05, 0.05, "timber") for i in range(6)], solid=False)
_thing("railing_2", "timber", "wood", [box(0.0, 1.0, 0.0, 2.0, 0.08, 0.08, "timber"), box(-0.95, 0.5, 0.0, 0.08, 1.0, 0.08, "timber"),
                                       box(0.95, 0.5, 0.0, 0.08, 1.0, 0.08, "timber")])
_thing("balcony_2", "boards", "wood", [box(0.0, -0.1, 0.6, 2.0, 0.2, 1.2, "boards"), box(0.0, 0.9, 1.15, 2.0, 0.08, 0.08, "timber")])
_thing("window_lit", "glass_lit", "stone", [box(0.0, 1.55, 0.0, 0.85, 1.25, 0.05, "glass_lit")], solid=False)
# A ladder against a wall (its back on local +z, the wall's side): two rails
# and rungs; its climb is a ladder marker's (ClimbVolume).
_thing("ladder_3", "timber", "wood", [box(side * 0.25, 1.7, 0.0, 0.07, 3.4, 0.07, "timber") for side in (-1.0, 1.0)] +
       [box(0.0, 0.3 + i * 0.32, 0.0, 0.5, 0.05, 0.05, "timber") for i in range(10)], solid=False)
# A lean-to against a wall's outer face (its back on local -z): a boarded
# roof at LEAN_TO_ROOF on two posts, a way down off the wall for the
# desperate (the navmesh links wall, roof and ground by drops).
LEAN_TO_ROOF = 2.5
_thing("lean_to_4", "boards", "wood", [box(0.0, LEAN_TO_ROOF - 0.06, 0.0, 4.0, 0.12, 2.6, "slate"),
                                       box(-1.85, (LEAN_TO_ROOF - 0.12) / 2.0, 1.15, 0.2, LEAN_TO_ROOF - 0.12, 0.2, "timber"),
                                       box(1.85, (LEAN_TO_ROOF - 0.12) / 2.0, 1.15, 0.2, LEAN_TO_ROOF - 0.12, 0.2, "timber"),
                                       box(0.0, LEAN_TO_ROOF - 0.25, 1.15, 4.0, 0.2, 0.2, "timber")])

# A ramp of ground: the bank, a slope up `rise` over `run`.
for rise, run in ((1.0, 4.0), (2.0, 8.0)):
    angle = math.degrees(math.atan2(rise, run))
    length = math.hypot(rise, run)
    piece("ramp_grass_%d" % int(rise), "floor", "grass", "grass",
          [box(0.0, rise / 2.0 - 0.1, 0.0, 4.0, 0.2, length, "grass", 0.0, -angle, 0.0)], size=[4.0, rise, run])


def names():
    return sorted(PIECES)


def roofed(pieces, markers=()):
    """The placed pieces (a level's, by name) that stand under a roof: a
    recipe made only for under one ("roofed": a room's furniture, the
    naves' vaults), or dressing inside a "roofed" box marker (what is stored
    in a hall). The city's moon casts no shadow from them (Layers.ROOFED):
    its shadow pass is spared what it could never reach."""
    boxes = []

    for m in markers:
        if m["ucd"] == "roofed":
            boxes.append((m["position"], m["basis"], [s / 2.0 for s in m["size"]]))

    def inside(at):
        for centre, basis, half in boxes:
            d = [at[i] - centre[i] for i in range(3)]
            # (Into the box's frame: its basis's columns are its axes.)
            if all(abs(sum(basis[r][c] * d[r] for r in range(3))) <= half[c] for c in range(3)):
                return True

        return False

    out = []

    for p in pieces:
        recipe = PIECES.get(p["piece"], {})

        if recipe.get("roofed") or (recipe.get("family") == "dressing" and boxes and inside(p["position"])):
            out.append(p["name"])

    return out


# Merged pieces are joined a MERGE_CELL m square at a time (culling still
# finds each cell).
MERGE_CELL = 34.0


def merge_groups(pieces, roofed=()):
    """The placed pieces (a level's) joined into one mesh at export: those of a
    recipe flagged "merge" (dense structure found by no one by name: the
    naves' piers, arches and vaults), by sector, by MERGE_CELL m cell, those
    under a roof (`roofed`, names) apart from those in the open:
    [{"name", "sector", "roofed", "members": [names]}]. A cell's pieces are
    then a draw a material, not a draw a piece."""
    under = set(roofed)
    groups = {}

    for p in pieces:
        if not PIECES.get(p["piece"], {}).get("merge"):
            continue

        cell = (int(math.floor(p["position"][0] / MERGE_CELL)), int(math.floor(p["position"][2] / MERGE_CELL)))
        groups.setdefault((p["sector"], p["name"] in under, cell), []).append(p["name"])

    return [{"name": "merged_%s_%s_%d_%d" % (sector, "roofed" if is_roofed else "open", cx, cz), "sector": sector, "roofed": is_roofed,
             "members": sorted(members)} for (sector, is_roofed, (cx, cz)), members in sorted(groups.items())]


def shadowless(pieces):
    """The placed pieces (a level's, by name) drawn without a shadow: the
    city's far massing (the moon's shadow pass need not draw a district
    that is only a silhouette)."""
    return [p["name"] for p in pieces if PIECES.get(p["piece"], {}).get("family") == "massing"]


# Kit v1 (the art pass): the pieces that read as boxes, modelled low-poly
# (kit_shapes); their colliders stay the boxes above.

# Openings with their heads and reveals: doors round-headed, windows flat
# with a sill standing out, arches round, the chapel's lancets pointed.
for material, (slot, surface) in WALLS.items():
    for depth, suffix in ((OUTER, ""), (INNER, "_thin")):
        model("wall_%s%s_door" % (material, suffix),
              ks.arched_wall(2.0, STOREY, depth, DOOR[0], DOOR[1] - DOOR[0] / 2.0, DOOR[0] / 2.0, 0.0, slot))
        model("wall_%s%s_window" % (material, suffix),
              ks.arched_wall(2.0, STOREY, depth, WINDOW[0], WINDOW[2] + WINDOW[1], 0.0, WINDOW[2], slot)
              + [ks.box(0.0, WINDOW[2] - 0.04, depth / 2.0 + 0.03, WINDOW[0] + 0.2, 0.08, 0.06, slot)])
        model("wall_%s%s_arch" % (material, suffix),
              ks.arched_wall(2.4, STOREY, depth, ARCH[0], ARCH[1] - ARCH[0] / 2.0, ARCH[0] / 2.0, 0.0, slot))

    model("wall_%s_tall_lancet" % material, ks.arched_wall(2.0, STOREY * 2.0, OUTER, 0.9, 3.9, 1.5, 1.8, slot, pointed=True))

# The colonnade: octagonal shafts on square bases under square capitals, and
# round arches between them (the band over each, its springing on the
# capitals).
model("column", [ks.box(0.0, 0.12, 0.0, 0.45, 0.24, 0.45, "ashlar"), ks.prism(0.0, 0.26, 0.0, 0.26, 0.04, 8, "ashlar", top=0.2),
                 ks.prism(0.0, 1.43, 0.0, 0.2, 2.3, 8, "ashlar"), ks.prism(0.0, 2.64, 0.0, 0.2, 0.12, 8, "ashlar", top=0.27),
                 ks.box(0.0, 2.85, 0.0, 0.45, 0.3, 0.45, "ashlar")])
model("arch_span_3", ks.arched_wall(3.0, STOREY, 0.45, 2.55, 2.1, 0.62, 0.0, "ashlar", piers=False))
model("buttress", [ks.box(0.0, 2.0, 0.0, 0.8, 4.0, 1.2, "ashlar"), ks.box(0.0, 4.6, -0.2, 0.8, 1.2, 0.8, "ashlar"),
                   ks.box(0.0, 5.55, -0.25, 0.8, 0.9, 0.7, "ashlar", 0.0, 32.0, 0.0)])

# Round things: barrels, the well, candle stands; the cart on its wheels.
model("barrel", [ks.prism(0.0, 0.45, 0.0, 0.26, 0.9, 10, "boards", rings=[[0.3, 0.3], [0.7, 0.3]]),
                 ks.prism(0.0, 0.2, 0.0, 0.29, 0.05, 10, "iron", caps=False), ks.prism(0.0, 0.7, 0.0, 0.29, 0.05, 10, "iron", caps=False)])
model("well", [ks.prism(0.0, 0.45, 0.0, 0.8, 0.9, 12, "stone"), ks.prism(0.0, 0.905, 0.0, 0.62, 0.01, 12, "pitch"),
               ks.box(-0.8, 1.35, 0.0, 0.12, 1.8, 0.12, "timber"), ks.box(0.8, 1.35, 0.0, 0.12, 1.8, 0.12, "timber"),
               ks.box(0.0, 2.2, 0.0, 1.8, 0.15, 0.2, "timber"), ks.prism(0.0, 1.9, 0.0, 0.1, 0.25, 8, "boards", 0.0, 0.0, 90.0)])
model("candle_stand", [ks.prism(0.0, 0.03, 0.0, 0.16, 0.06, 6, "iron", top=0.1), ks.prism(0.0, 0.73, 0.0, 0.025, 1.34, 6, "iron"),
                       ks.prism(0.0, 1.41, 0.0, 0.1, 0.03, 6, "iron", top=0.12), ks.prism(0.0, 1.5, 0.0, 0.035, 0.16, 6, "wax")])
model("cart", [ks.box(0.0, 0.8, 0.0, 1.6, 0.1, 3.0, "boards"), ks.box(-0.75, 1.0, 0.0, 0.08, 0.3, 3.0, "boards"),
               ks.box(0.75, 1.0, 0.0, 0.08, 0.3, 3.0, "boards"), ks.box(0.0, 0.65, 0.4, 1.9, 0.1, 0.1, "timber"),
               ks.prism(-0.85, 0.5, 0.4, 0.5, 0.08, 10, "timber", 0.0, 0.0, 90.0), ks.prism(0.85, 0.5, 0.4, 0.5, 0.08, 10, "timber", 0.0, 0.0, 90.0)])
model("chandelier", [ks.prism(0.0, 0.0, 0.0, 0.8, 0.06, 12, "iron"), ks.box(0.0, 1.5, 0.0, 0.05, 3.0, 0.05, "iron")]
      + [ks.prism(math.sin(i * math.tau / 6) * 0.7, 0.11, math.cos(i * math.tau / 6) * 0.7, 0.035, 0.16, 6, "wax") for i in range(6)])

# Foliage as crossed cards (a man hides behind them): a tree on its trunk, a
# bush; banners of crimson cloth on their poles.
model("tree", [ks.prism(0.0, 2.0, 0.0, 0.28, 4.0, 7, "bark", top=0.16)]
      + [ks.card(0.0, 5.0, 0.0, 3.6, 3.2, "leaves", yaw) for yaw in (0.0, 60.0, 120.0)] + [ks.card(0.0, 4.4, 0.0, 3.0, 3.0, "leaves", 0.0, 90.0)])
PIECES["tree"]["cols"] = [[0.0, 2.0, 0.0, 0.5, 4.0, 0.5, "wood", 0, 0, 0]]
model("bush", [ks.card(0.0, 0.6, 0.0, 1.7, 1.2, "leaves", yaw) for yaw in (0.0, 60.0, 120.0)])
model("banner", [ks.box(0.0, 2.85, 0.0, 1.2, 0.06, 0.06, "timber"), ks.card(0.0, 1.6, 0.0, 1.0, 2.4, "cloth")])

# Pitched roofs over the barracks and the chapel (drawn only: their flat
# ceilings stay what stops sight and feet), their gable ends, chimneys over
# the hearths and stoves.
ROOF_OVERHANG = 0.4
ROOF_VERGE = 0.3
ROOF_THICK = 0.2
BARGE = 0.32


def pitched(length, span, rise, slot="roof_slate", under="boards", tile=1.5, rafters=0.0, verge=ROOF_VERGE, overhang=ROOF_OVERHANG):
    """A double-pitched roof `length` along x (and its verges past either
    end), `span` across (z) at its walls: its underside at y 0 on the walls
    and `rise` at the ridge. Two slopes falling from the ridge to the eaves
    (their photo's rows along the eaves), a ridge, fascia boards along the
    eaves, bargeboards at its ends; rafters under it every `rafters` m (0:
    none, a ceiling hides them)."""
    half = span / 2.0
    a = math.atan2(rise, half)
    lift = ROOF_THICK / math.cos(a)
    run = overhang * math.cos(a)
    eave_y = -overhang * math.sin(a) + lift
    top = rise + lift
    x0, x1 = -length / 2.0 - verge, length / 2.0 + verge
    out = []

    for side in (1.0, -1.0):
        z = side * (half + run)
        out.append(ks.slab([[x0, top, 0.0], [x1, top, 0.0], [x1, eave_y, z], [x0, eave_y, z]], ROOF_THICK, slot, under=under,
                           edge="timber", tile=tile, up=(0.0, 1.0, side)))
        # The fascia along the eaves; the bargeboards down the ends.
        out.append(ks.box(0.0, eave_y - ROOF_THICK * 0.6, z + side * 0.03, x1 - x0, 0.28, 0.05, "timber"))

        for end, x in ((-1.0, x0 - 0.03), (1.0, x1 + 0.03)):
            out.append(ks.slab([[x, top + 0.04, 0.0], [x, eave_y + 0.04, z], [x, eave_y + 0.04 - BARGE, z], [x, top + 0.04 - BARGE, 0.0]],
                               0.05, "timber", up=(end, 0.0, 0.0)))

        if rafters > 0.0:
            count = int(length // rafters)
            depth = 0.18
            along = math.hypot(half, rise)

            for i in range(count + 1):
                x = -length / 2.0 + 0.1 + i * (length - 0.2) / max(count, 1)
                out.append(ks.box(x, rise / 2.0 - depth / 2.0 * math.cos(a), side * (half / 2.0 - depth / 2.0 * math.sin(a)), 0.12, depth, along,
                                  "timber", 0.0, side * math.degrees(a), 0.0))

    # The ridge: a row of tiles over where the slopes meet.
    out.append(ks.box(0.0, top, 0.0, x1 - x0, 0.26, 0.26, slot, 0.0, 45.0, 0.0))
    return out


def _roof(name, length, span, rise, **options):
    piece(name, "roof", options.get("slot", "roof_slate"), "stone", [], cols=[],
          size=[length + 2 * ROOF_VERGE, rise + 0.6, span + 2 * (ROOF_OVERHANG + 0.1)])
    PIECES[name]["span"] = span
    model(name, pitched(length, span, rise, **options))


# The barracks' (38 m along its wing, 16 across, slate) and the chapel's
# (20 m along its nave, 9.6 across, steeper, fish-scale slates, open to its
# rafters inside).
_roof("roof_16x38", 38.0, 16.0, 5.0)
_roof("roof_10x21", 20.0, 9.6, 5.0, slot="roof_fish", tile=1.2, rafters=0.9)


def _framed_gable(span, rise, depth, slot):
    """A gable end, its timbers on both faces: the tie beam, a king post, a
    collar, two struts; a louvred vent up in it."""
    out = [ks.gable(0.0, 0.0, 0.0, span, rise, depth, slot)]
    collar_y = rise * 0.5
    collar_w = span * (1.0 - collar_y / rise) - 0.3

    for face in (1.0, -1.0):
        z = face * (depth / 2.0 + 0.02)
        out.append(ks.box(0.0, 0.14, z, span - 0.2, 0.28, 0.08, "timber"))
        out.append(ks.box(0.0, rise * 0.45, z, 0.22, rise * 0.9 - 0.2, 0.08, "timber"))
        out.append(ks.box(0.0, collar_y, z, collar_w, 0.22, 0.08, "timber"))

        for side in (-1.0, 1.0):
            length = math.hypot(span * 0.22, collar_y - 0.3)
            angle = math.degrees(math.atan2(collar_y - 0.3, span * 0.22))
            out.append(ks.box(side * span * 0.14, 0.3 + (collar_y - 0.3) / 2.0, z, length, 0.18, 0.08, "timber", 0.0, 0.0, -side * angle))

        out.append(ks.card(0.0, rise * 0.7, face * (depth / 2.0 + 0.045), 0.7, 0.7, "shutters", 0.0 if face > 0 else 180.0))

    return out


piece("gable_16", "roof", "plaster", "stone", [], cols=[], size=[16.0, 5.0, OUTER])
model("gable_16", _framed_gable(16.0, 5.0, OUTER, "plaster"))

piece("chimney_6", "roof", "ashlar", "stone", [], cols=[], size=[1.3, 6.6, 1.3])
model("chimney_6", [ks.box(0.0, 3.0, 0.0, 1.0, 6.0, 1.0, "ashlar"), ks.box(0.0, 6.12, 0.0, 1.25, 0.25, 1.25, "ashlar"),
                    ks.lathe(-0.22, 6.25, 0.0, [[0.13, 0.0], [0.11, 0.3], [0.14, 0.42]], 8, "clay"),
                    ks.lathe(0.22, 6.25, 0.0, [[0.13, 0.0], [0.11, 0.24], [0.14, 0.34]], 8, "clay"),
                    ks.prism(-0.22, 6.66, 0.0, 0.12, 0.02, 8, "pitch"), ks.prism(0.22, 6.58, 0.0, 0.12, 0.02, 8, "pitch")])


# A window lit from within, leaded: its glass in the opening's outer face,
# a mullion and two transoms of lead over it.
model("window_lit", [ks.card(0.0, 1.55, 0.0, 0.85, 1.25, "glass_lit"), ks.box(0.0, 1.55, 0.02, 0.03, 1.25, 0.02, "iron")]
      + [ks.box(0.0, y, 0.02, 0.85, 0.03, 0.02, "iron") for y in (1.2, 1.9)])


# The chapel's hero pieces: stained glass in the lancets (a pane the size of
# the opening; the wall hides its corners round the pointed head), reliefs
# for its walls (a frieze, the angels over the altar). Drawn only.
for name, width, height, slot in (("glass_lancet", 0.9, 3.6, "stained_glass"), ("relief_panel", 2.6, 1.13, "relief_frieze"),
                                  ("relief_altar", 3.2, 1.6, "relief_angels")):
    piece(name, "dressing", slot, "stone", [], cols=[], size=[width, height, 0.1])
    model(name, [ks.card(0.0, height / 2.0, 0.0, width, height, slot)])


# Weeds: a clump of three small crossed leaf cards (at wall feet, in the
# yards' corners). Drawn only.
piece("weeds", "dressing", "leaves", "grass", [], cols=[], size=[0.7, 0.45, 0.7])
model("weeds", [ks.card(0.0, 0.2, 0.0, 0.7, 0.4, "leaves", yaw) for yaw in (0.0, 60.0, 120.0)])


# The lanes' houses (kit_houses: house_a .. house_f).
import kit_houses  # noqa: E402,F401

# The building dressing (kit_art: banners, the gate's arches, framed walls,
# joists, trusses).
import kit_art  # noqa: E402,F401

# The chapel's art (kit_chapel).
import kit_chapel  # noqa: E402,F401

# The props (kit_props: the mess hall's and kitchen's, the dressing modelled).
import kit_props  # noqa: E402,F401

# The nature round the walls (kit_nature: trees, shrubs, grass, reeds, ivy).
import kit_nature  # noqa: E402,F401

# The city's fortifications (kit_fort: walls, towers, the golden tower, the
# fort, the Sea Gate, the Nasrid gate, the chain).
import kit_fort  # noqa: E402,F401

# The city's Iberian buildings (kit_iberian: the Ribeira's houses and
# arcade, the Terreiro's arcades, granite stairs, the statue, a shrine).
import kit_iberian  # noqa: E402,F401

# The city's harbour (kit_harbour: quays, the mole, the shipyard's naves,
# the galley on the stocks, a crane, the quays' dressing).
import kit_harbour  # noqa: E402,F401

# The customs house (kit_customs: Manueline, after Lisbon's Casa dos Bicos).
import kit_customs  # noqa: E402,F401

# Rooms lived in: the harbourmaster's office, the customs hall, the great
# cabin (kit_interiors).
import kit_interiors  # noqa: E402,F401

# The harbour's ships (kit_ships: the carrack, a caravel, boats).
import kit_ships  # noqa: E402,F401

# Mediterranean planting (kit_planting) and the rest of the city as
# silhouettes until it is built (kit_massing).
import kit_planting  # noqa: E402,F401
import kit_massing  # noqa: E402,F401

# The coast's rock, plants and life (kit_coast: tors, ledges, boulders;
# gorse, fennel, pines, a fig; gulls, nets, washing, a tavern's bush).
import kit_coast  # noqa: E402,F401

# The old town's grammar (kit_town: walls true to what opens, floors,
# stairs, rooms, roofs), which its house families are built from.
import kit_town  # noqa: E402,F401

# The old town's terraces and the ground below them (kit_terrace: retaining
# walls, stair-lanes, arches over lanes, vaults, cisterns, hatches).
import kit_terrace  # noqa: E402,F401

# Its street furniture (kit_street: corner lamps' arms, shrines, the comet's
# and the forgotten king's tile panels, fountains).
import kit_street  # noqa: E402,F401

# Its key buildings, made by hand, each entered several ways (kit_tavern,
# kit_watch).
import kit_tavern  # noqa: E402,F401
import kit_watch  # noqa: E402,F401

# Dense structure found by no one by name, joined at export (merge_groups) in
# the levels that ask for it (export.MERGE_LEVELS): floors, the city's
# walls, quays, the Terreiro's arcade bays (the naves' are flagged in
# kit_harbour).
for _name in PIECES:
    if _name.startswith(("floor_", "city_wall_", "quay_", "terreiro_bay", "terreiro_corner")):
        PIECES[_name]["merge"] = True
