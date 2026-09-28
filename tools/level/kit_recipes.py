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
        "sockets": sockets or {}, "size": size, "opening": opening,
    }


# ---------------------------------------------------------------------------
# Walls: plain runs, a door, a window, an arch, an arrow slit, a corner post;
# one storey high, OUTER thick (INNER for the partitions).
# ---------------------------------------------------------------------------

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

# A tall wall: two storeys in one (the chapel's, the gatehouse's front).
for material, (slot, surface) in WALLS.items():
    piece("wall_%s_tall_2" % material, "wall", slot, surface,
          [box(0.0, STOREY, 0.0, 2.0, STOREY * 2.0, OUTER, slot)], size=[2.0, STOREY * 2.0, OUTER])
    piece("wall_%s_tall_lancet" % material, "wall", slot, surface,
          _with_opening(2.0, OUTER, STOREY * 2.0, 0.9, 3.6, 1.8, slot), size=[2.0, STOREY * 2.0, OUTER], opening=[0.9, 3.6])

# ---------------------------------------------------------------------------
# The curtain wall: a walk on top (CURTAIN_HEIGHT), a crenellated parapet on
# its outer (+z) side; a gap for the gate; a corner block.
# ---------------------------------------------------------------------------

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

# ---------------------------------------------------------------------------
# Floors (their top at the pivot), ceilings, a roof slope.
# ---------------------------------------------------------------------------

FLOORS = {"cobble": ("cobble", "stone"), "flag": ("flagstone", "stone"), "board": ("boards", "wood"),
          "grass": ("grass", "grass"), "mud": ("mud", "dirt"), "gravel": ("gravel", "gravel"),
          "carpet": ("carpet", "carpet")}

for kind, (slot, surface) in FLOORS.items():
    for size in (2, 4):
        piece("floor_%s_%d" % (kind, size), "floor", slot, surface,
              [box(0.0, -0.1, 0.0, float(size), 0.2, float(size), slot)], size=[float(size), 0.2, float(size)])

for size in (2, 4):
    piece("roof_slope_%d" % size, "roof", "slate", "stone",
          [box(0.0, 0.0, 0.0, float(size), 0.2, float(size) * math.sqrt(2.0), "slate", 0.0, 45.0, 0.0)],
          size=[float(size), float(size), float(size)])
    piece("beam_%d" % size, "beam", "timber", "wood",
          [box(0.0, 0.0, 0.0, float(size), 0.25, 0.25, "timber")], size=[float(size), 0.25, 0.25])

# ---------------------------------------------------------------------------
# Stairs: a straight flight up one storey (along +z from its pivot, 1.2 m
# wide); a spiral turn (a quarter turn, a quarter storey, round a post).
# ---------------------------------------------------------------------------

_steps = int(round(STOREY / RISER))
piece("stair_straight", "stair", "flagstone", "stone",
      [box(0.0, (i + 1) * RISER / 2.0, i * TREAD + TREAD / 2.0, 1.2, (i + 1) * RISER, TREAD, "flagstone") for i in range(_steps)],
      size=[1.2, STOREY, _steps * TREAD])

# The flight up to the wall-walk (CURTAIN_HEIGHT), 1.4 m wide.
_curtain_steps = int(round(CURTAIN_HEIGHT / RISER))
piece("stair_curtain", "stair", "ashlar", "stone",
      [box(0.0, (i + 1) * RISER / 2.0, i * TREAD + TREAD / 2.0, 1.4, (i + 1) * RISER, TREAD, "ashlar") for i in range(_curtain_steps)],
      size=[1.4, CURTAIN_HEIGHT, _curtain_steps * TREAD])
# A landing: a slab whose top is at the pivot, 2 x 2 m.
piece("landing_2", "floor", "flagstone", "stone", [box(0.0, -0.15, 0.0, 2.0, 0.3, 2.0, "flagstone")], size=[2.0, 0.3, 2.0])

_spiral = []

for i in range(4):
    angle = i * 22.5
    a = math.radians(angle + 11.25)
    _spiral.append(box(math.sin(a) * 1.0, (i + 1) * RISER - RISER / 2.0, math.cos(a) * 1.0, 1.4, RISER, 0.55, "flagstone", angle, 0.0, 0.0))

_spiral.append(box(0.0, 0.5, 0.0, 0.4, 1.0, 0.4, "ashlar"))
piece("stair_spiral_quarter", "stair", "flagstone", "stone", _spiral, size=[3.0, 4 * RISER, 3.0])

# ---------------------------------------------------------------------------
# Columns and arches (the colonnade), vault ribs, a buttress.
# ---------------------------------------------------------------------------

piece("column", "column", "ashlar", "stone", [box(0.0, STOREY / 2.0, 0.0, 0.45, STOREY, 0.45, "ashlar")], size=[0.45, STOREY, 0.45])
piece("arch_span_3", "column", "ashlar", "stone", [box(0.0, STOREY - 0.3, 0.0, 3.0, 0.6, 0.45, "ashlar")], size=[3.0, 0.6, 0.45])
piece("rib_8", "vault", "ashlar", "stone", [box(0.0, 0.0, 0.0, 8.0, 0.35, 0.35, "ashlar")], cols=[], size=[8.0, 0.35, 0.35])
piece("buttress", "column", "ashlar", "stone", [box(0.0, STOREY, 0.0, 0.8, STOREY * 2.0, 1.2, "ashlar")], size=[0.8, STOREY * 2.0, 1.2])

# ---------------------------------------------------------------------------
# The quay: its wall down to the water, steps, a post, a boat, the crane.
# ---------------------------------------------------------------------------

piece("quay_wall_4", "quay", "stone", "stone", [box(0.0, -1.25, 0.0, 4.0, 2.5, 1.0, "stone")], size=[4.0, 2.5, 1.0])
piece("quay_steps", "quay", "stone", "stone",
      [box(0.0, -0.2 - i * 0.2 - 0.1, i * TREAD, 1.6, 0.2 + i * 0.0, TREAD, "stone") for i in range(8)], size=[1.6, 1.6, 8 * TREAD])
piece("mooring_post", "quay", "timber", "wood", [box(0.0, 0.5, 0.0, 0.3, 1.0, 0.3, "timber")], size=[0.3, 1.0, 0.3])
piece("boat", "quay", "boards", "wood",
      [box(0.0, -0.9, 0.0, 1.6, 0.5, 5.0, "boards"), box(0.0, -0.55, 0.0, 1.8, 0.2, 5.2, "boards")], cols=[], size=[1.8, 0.7, 5.2])
piece("crane", "quay", "timber", "wood",
      [box(0.0, 3.0, 0.0, 0.4, 6.0, 0.4, "timber"), box(0.0, 5.8, 1.5, 0.3, 0.3, 3.4, "timber")],
      cols=[[0.0, 3.0, 0.0, 0.4, 6.0, 0.4, "wood", 0, 0, 0]], size=[0.4, 6.0, 3.4])

# ---------------------------------------------------------------------------
# Dressing: what the men sleep on, eat at, drill at, pray at, and the rest.
# ---------------------------------------------------------------------------

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
_thing("pew", "boards", "wood", [box(0.0, 0.45, 0.0, 3.2, 0.08, 0.45, "boards"), box(0.0, 0.85, 0.2, 3.2, 0.8, 0.06, "boards"),
                                 box(-1.55, 0.5, 0.0, 0.08, 1.0, 0.5, "boards"), box(1.55, 0.5, 0.0, 0.08, 1.0, 0.5, "boards")])
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
_thing("house_front", "timber", "wood", [box(0.0, 4.5, 0.0, 6.0, 9.0, 0.4, "timber"), box(0.0, 10.0, -1.5, 6.4, 2.0, 3.2, "slate")])

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
