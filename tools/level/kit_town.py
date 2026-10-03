"""The old town's grammar (its spec, sections 5.1-5.3; plan B1a, Task 2):
what every house of the four families is built from, on one 0.5 m grid.

    wall     a run of wall with its openings: an HONEST one (shutters shut,
             a door barred, boarded up, lit behind shutters ajar, blind) is
             drawn in its recess and leaves the wall's collider whole; a
             LIVE one (a door, an open window, a hatch) is a hole a man goes
             through. So no door looks openable that is not (the spec's
             rule 22), and every one that is, is.
    floors   0.2 m slabs at each storey, a stair's hole left in them
    stair    a flight (straight, two flights about a half-landing, a spiral)
             of stepped boxes, as the kit's own stair_straight
    rooms    the partitions between a house's rooms, a door in each where
             asked
    roof     gable, hipped (or four-pitched), mansard, flat (an azotea and
             its parapet), every slope stood on
    register a design made a kit piece, its doors, ways in, climbs,
             chimneys and places carried on its recipe for the layout

A piece's frame is the kit's: x along its front, y up from its foot, its
front to +z. Shapes are kit_shapes', colliders [cx, cy, cz, sx, sy, sz,
surface, yaw, pitch, roll]. Pure data, as kit_recipes (which imports this at
its end).
"""

import math
from dataclasses import dataclass

import geo
import kit_recipes as k  # (first: it registers every kit, kit_iberian among them)
import kit_iberian as ib
import kit_shapes as ks

# The plan grid (the spec's 5.1).
GRID = 0.5
# What an opening is: drawn shut (the wall whole behind it), or a way through.
HONEST = ("shut", "barred", "boarded", "lit", "blind")
LIVE = ("door", "window", "hatch")
# An honest opening's leaves stand this far back from the wall's face.
REVEAL = 0.15
# A floor's slab; a stair's rise and going; a partition and its door.
SLAB = 0.2
RISER = 0.18
TREAD = 0.25
PARTITION = 0.1
ROOM_DOOR = (0.9, 2.1)
# A flat roof's (an azotea's) parapet and its thickness; a mansard's two
# pitches and the height of its steep lower slope.
PARAPET = 1.0
PARAPET_THICK = 0.25
MANSARD = (65.0, 25.0)
MANSARD_HEIGHT = 2.5
# What a roof is drawn in, and how far its eaves stand out.
ROOFS = ("gable", "hipped", "four", "mansard", "flat")
OVERHANG = 0.35


def snap(v):
    """v on the grid (halves round up)."""
    return math.floor(v / GRID + 0.5) * GRID


@dataclass(frozen=True)
class Opening:
    """An opening in a wall: its middle `x` along the wall, its foot `y`
    over the wall's, `width` by `height`, its kind (HONEST or LIVE), the
    face of the house it is in."""
    x: float
    y: float
    width: float
    height: float
    kind: str
    face: str = "front"

    @property
    def live(self):
        return self.kind in LIVE


def col(cx, cy, cz, sx, sy, sz, surface="stone", yaw=0.0, pitch=0.0, roll=0.0):
    return [cx, cy, cz, sx, sy, sz, surface, yaw, pitch, roll]


def placed(shapes, cols, x=0.0, z=0.0, yaw=0.0, y=0.0):
    """Shapes and colliders turned `yaw` about the upright and moved to
    (x, y, z), as kit_shapes.moved turns shapes."""
    turn = geo.rotation(yaw)
    out = []

    for c in cols:
        centre = geo.add(geo.apply(turn, c[0:3]), [x, y, z])
        out.append(centre + list(c[3:7]) + [c[7] + yaw] + list(c[8:10]))

    return ks.moved(shapes, yaw, (x, y, z)), out


def split(a0, a1, b0, b1, holes):
    """The rectangle a0..a1 by b0..b1 less `holes` ((a0, a1, b0, b1) each),
    as rectangles (a0, a1, b0, b1) that cover it: cut into strips at every
    hole's edges, each strip less the holes across it."""
    cuts = sorted({a0, a1} | {h[i] for h in holes for i in (0, 1) if a0 < h[i] < a1})
    out = []

    for u, v in zip(cuts, cuts[1:]):
        if v - u < 1e-6:
            continue

        across = sorted((max(h[2], b0), min(h[3], b1)) for h in holes if h[0] < v - 1e-6 and h[1] > u + 1e-6 and h[3] > b0 and h[2] < b1)
        at = b0

        for lo, hi in across:
            if lo > at + 1e-6:
                out.append((u, v, at, lo))

            at = max(at, hi)

        if b1 > at + 1e-6:
            out.append((u, v, at, b1))

    return out


def honest(o, slot, z=0.0):
    """An honest opening drawn in its recess (the wall's face at z): its
    shutters shut, its door barred, boards across it, lit glass behind
    shutters ajar, or plastered blind in the wall's own slot."""
    back = z - REVEAL
    cy = o.y + o.height / 2.0

    if o.kind == "shut":
        # (Both leaves in one board: the photo shows the pair.)
        return [ks.box(o.x, cy, back, o.width - 0.04, o.height, 0.04, "shutters")]

    if o.kind == "barred":
        return [ks.box(o.x, cy, back, o.width, o.height, 0.06, "door_1"),
                ks.box(o.x, o.y + o.height * 0.55, back + 0.06, o.width + 0.2, 0.08, 0.05, "iron")]

    if o.kind == "boarded":
        out = [ks.box(o.x, cy, back - 0.05, o.width, o.height, 0.04, "pitch")]

        for i, tilt in enumerate((8.0, -6.0, 10.0)):
            out.append(ks.box(o.x, o.y + o.height * (0.25 + 0.25 * i), back + 0.03, o.width + 0.16, 0.18, 0.03, "boards", 0.0, 0.0, tilt))

        return out

    if o.kind == "lit":
        leaf = o.width / 2.0
        out = [ks.card(o.x, cy, back - 0.05, o.width, o.height, "glass_lit")]

        for s in (-1.0, 1.0):
            # (A leaf hung on its jamb, swung 60 degrees out of the recess.)
            hinge = o.x + s * o.width / 2.0
            out.append(ks.box(hinge - s * leaf / 2.0 * math.cos(math.radians(60.0)), cy, back + leaf / 2.0 * math.sin(math.radians(60.0)),
                              leaf, o.height, 0.04, "shutters", -s * 60.0))

        return out

    if o.kind == "blind":
        return [ks.box(o.x, cy, back + 0.05, o.width, o.height, 0.1, slot)]

    raise ValueError("no honest opening '%s'" % o.kind)


def facing(points, normal, slot):
    """A face through `points` wound to face along `normal`."""
    n = ks._normal(points)
    ok = sum(n[i] * normal[i] for i in range(3)) >= 0.0
    return ks.polygon(points if ok else list(reversed(points)), slot)


# What a flat honest opening shows on a plain wall's face (a back's).
FLAT = {"shut": "shutters", "lit": "glass_lit", "barred": "door_1", "boarded": "boards"}


def wall(length, height, thickness, openings, slot, place=(0.0, 0.0, 0.0), surface="stone", frames=True, inside=False, flat=False):
    """A wall `length` along x (its middle at 0), `height` up from 0,
    `thickness` through z (its face at +thickness / 2), with `openings`;
    its collider cut round the LIVE ones only. Drawn as its faces: its face
    round its openings (and, `inside`, its back: a house walked in), each
    opening's reveals (an honest one's only as deep as its recess), its
    ends and its top; granite surrounds on its face (not on a plain wall,
    `frames` False: fronts carry the detail, the spec's 10); honest
    openings drawn shut in their recess, or (`flat`, a back's) on its face
    with the wall not cut round them; open windows on a sill, doors on a
    threshold. Then turned and moved to `place` (x, z, yaw)."""
    face = thickness / 2.0
    cut = [o for o in openings if o.live or not flat]
    holes = [(o.x - o.width / 2.0, o.x + o.width / 2.0, o.y, o.y + o.height) for o in cut]
    live = [(o.x - o.width / 2.0, o.x + o.width / 2.0, o.y, o.y + o.height) for o in openings if o.live]
    shapes = []

    for a0, a1, b0, b1 in split(-length / 2.0, length / 2.0, 0.0, height, holes):
        shapes.append(facing([[a0, b0, face], [a1, b0, face], [a1, b1, face], [a0, b1, face]], (0.0, 0.0, 1.0), slot))

        if inside:
            shapes.append(facing([[a0, b0, -face], [a1, b0, -face], [a1, b1, -face], [a0, b1, -face]], (0.0, 0.0, -1.0), slot))

    for s in (-1.0, 1.0):
        x = s * length / 2.0
        shapes.append(facing([[x, 0.0, -face], [x, 0.0, face], [x, height, face], [x, height, -face]], (s, 0.0, 0.0), slot))

    shapes.append(facing([[-length / 2.0, height, -face], [length / 2.0, height, -face], [length / 2.0, height, face],
                          [-length / 2.0, height, face]], (0.0, 1.0, 0.0), slot))

    for o in cut:
        x0, x1, y0, y1 = o.x - o.width / 2.0, o.x + o.width / 2.0, o.y, o.y + o.height
        back = -face if o.live else face - REVEAL - 0.02
        shapes += [facing([[x0, y0, back], [x0, y0, face], [x0, y1, face], [x0, y1, back]], (1.0, 0.0, 0.0), slot),
                   facing([[x1, y0, back], [x1, y0, face], [x1, y1, face], [x1, y1, back]], (-1.0, 0.0, 0.0), slot),
                   facing([[x0, y1, back], [x1, y1, back], [x1, y1, face], [x0, y1, face]], (0.0, -1.0, 0.0), slot)]

        if y0 > 0.01:
            shapes.append(facing([[x0, y0, back], [x1, y0, back], [x1, y0, face], [x0, y0, face]], (0.0, 1.0, 0.0), slot))

    cols = [col((a0 + a1) / 2.0, (b0 + b1) / 2.0, 0.0, a1 - a0, b1 - b0, thickness, surface)
            for a0, a1, b0, b1 in split(-length / 2.0, length / 2.0, 0.0, height, live)]

    for o in openings:
        if frames and o.kind != "hatch":
            shapes += ib._frame(o.x, o.y, face, o.width, o.height)

        if not o.live:
            if not flat:
                shapes += honest(o, slot, face)
            elif o.kind in FLAT:
                shapes.append(ks.card(o.x, o.y + o.height / 2.0, face + 0.01, o.width, o.height, FLAT[o.kind]))
        elif o.kind == "window":
            shapes.append(ks.box(o.x, o.y - 0.04, face - 0.05, o.width + 0.2, 0.08, thickness * 0.5, "granite"))
        elif o.kind == "door":
            # (Its threshold: a floor through the wall's thickness.)
            shapes.append(ks.box(o.x, o.y - SLAB / 2.0, 0.0, o.width, SLAB, thickness, "granite"))
            cols.append(col(o.x, o.y - SLAB / 2.0, 0.0, o.width, SLAB, thickness, surface))

    x, z, yaw = place
    return placed(shapes, cols, x, z, yaw)


def balcony(x, y, width, depth, wall_z=0.0, slot="granite"):
    """A balcony on the storey whose floor is y, `width` across, `depth`
    out from a wall's face at wall_z (facing +z): its slab on two corbels,
    iron rails (cards) round it under a handrail; its colliders, the slab
    and the rails (kit_iberian's)."""
    t = 0.15
    shapes = [ks.box(x, y - t / 2.0, wall_z + depth / 2.0, width, t, depth, slot),
              ks.card(x, y + ib.RAIL / 2.0, wall_z + depth - 0.03, width - 0.04, ib.RAIL - 0.05, "iron_rail"),
              ks.box(x, y + ib.RAIL, wall_z + depth - 0.03, width, 0.05, 0.05, "iron")]

    for s in (-1.0, 1.0):
        shapes += [ks.box(x + s * (width / 2.0 - 0.2), y - t - 0.15, wall_z + depth * 0.4, 0.15, 0.3, depth * 0.7, slot),
                   ks.card(x + s * (width / 2.0 - 0.02), y + ib.RAIL / 2.0, wall_z + depth / 2.0, depth - 0.04, ib.RAIL - 0.05, "iron_rail", 90.0)]

    cols = [col(x, y - t / 2.0, wall_z + depth / 2.0, width, t, depth)] + ib._rail_cols(x, y, width, wall_z, depth)
    return shapes, cols


def floors(width, depth, levels, hole=None, slot="boards", surface="wood"):
    """A slab at each of `levels` (its top there) over width x depth about
    the middle, less `hole` (x0, z0, x1, z1) where a stair comes up."""
    holes = [hole] if hole else []
    shapes, cols = [], []

    for y in levels:
        for x0, x1, z0, z1 in split(-width / 2.0, width / 2.0, -depth / 2.0, depth / 2.0,
                                    [(h[0], h[2], h[1], h[3]) for h in holes]):
            shapes.append(ks.box((x0 + x1) / 2.0, y - SLAB / 2.0, (z0 + z1) / 2.0, x1 - x0, SLAB, z1 - z0, slot))
            cols.append(col((x0 + x1) / 2.0, y - SLAB / 2.0, (z0 + z1) / 2.0, x1 - x0, SLAB, z1 - z0, surface))

    return shapes, cols


def _steps(rise):
    n = max(1, int(math.ceil(rise / RISER - 1e-9)))
    return n, rise / n


def stair_reach(kind, width, rise):
    """Where a stair goes, laid at its place's origin facing +z: `run` (its
    first flight's length along z), `landing` (the half-landing's height,
    or the top), `steps`, `riser` and `footprint` (x0, z0, x1, z1)."""
    n, r = _steps(rise)

    if kind == "straight":
        return {"run": n * TREAD, "landing": rise, "steps": n, "riser": r, "footprint": (-width / 2.0, 0.0, width / 2.0, n * TREAD)}

    if kind == "two_flight":
        n1 = n // 2
        run = n1 * TREAD
        return {"run": run, "landing": n1 * r, "steps": n, "riser": r,
                "footprint": (-width, min(0.0, run - (n - n1) * TREAD), width, run + width)}

    if kind == "spiral":
        reach = width + 0.15
        return {"run": 0.0, "landing": rise, "steps": n, "riser": r, "footprint": (-reach, -reach, reach, reach)}

    raise ValueError("no stair '%s'" % kind)


def _tread(x, top, z, width, solid):
    """A step whose top is `top`: from the floor (solid), or a slab."""
    if solid:
        return (x, top / 2.0, z, width, top, TREAD, 0.0)

    return (x, top - SLAB / 2.0, z, width, SLAB, TREAD, 0.0)


def stair(kind, width, rise, at=(0.0, 0.0, 0.0), yaw=0.0, slot="flagstone", surface="stone", solid=True):
    """A stair `width` wide climbing `rise` from its foot at `at` (x, y,
    z), facing +z turned by `yaw`:
        straight    one flight up +z
        two_flight  up +z on the left (x < 0) to a half-landing a width
                    deep, then back down -z on the right to the top
        spiral      round a post, sixteen steps a turn, starting toward +z
    Its steps stepped boxes from the floor, as stair_straight's; not
    `solid`, slabs (stairs stacked in a stairwell, a storey apart, each
    under the one over it)."""
    n, r = _steps(rise)
    boxes = []

    if kind == "straight":
        boxes = [_tread(0.0, (i + 1) * r, i * TREAD + TREAD / 2.0, width, solid) for i in range(n)]
    elif kind == "two_flight":
        n1 = n // 2
        run = n1 * TREAD
        boxes = [_tread(-width / 2.0, (i + 1) * r, i * TREAD + TREAD / 2.0, width, solid) for i in range(n1)]
        boxes.append((0.0, n1 * r / 2.0, run + width / 2.0, 2.0 * width, n1 * r, width, 0.0) if solid else
                     (0.0, n1 * r - SLAB / 2.0, run + width / 2.0, 2.0 * width, SLAB, width, 0.0))

        for j in range(n - n1):
            boxes.append(_tread(width / 2.0, (n1 + j + 1) * r, run - j * TREAD - TREAD / 2.0, width, solid))
    elif kind == "spiral":
        step = 360.0 / 16.0
        middle = 0.15 + width / 2.0
        deep = 2.0 * math.pi * middle / 16.0 * 1.15

        for i in range(n):
            a = math.radians(i * step)
            top = (i + 1) * r
            boxes.append((math.sin(a) * middle, top - 0.1, math.cos(a) * middle, deep, 0.2, width, i * step + 90.0))

        boxes.append((0.0, rise / 2.0, 0.0, 0.3, rise, 0.3, 0.0))
    else:
        raise ValueError("no stair '%s'" % kind)

    shapes = [ks.box(b[0], b[1], b[2], b[3], b[4], b[5], slot, b[6]) for b in boxes]
    cols = [col(b[0], b[1], b[2], b[3], b[4], b[5], surface, b[6]) for b in boxes]
    shapes, cols = placed(shapes, cols, at[0], at[2], yaw, at[1])
    return shapes, cols


def stair_tour(kind, width, rise, at=(0.0, 0.0, 0.0), yaw=0.0):
    """The way up a stair laid as stair() lays it: from a step before its
    foot to a step past its head (round its hole in the floor it comes out
    on), as [[x, y, z, move], ...] for route checks."""
    reach = stair_reach(kind, width, rise)
    run, landing, r = reach["run"], reach["landing"], reach["riser"]
    half = TREAD / 2.0

    # (Each flight from its first tread's middle to its last's, along its
    # nosings: over open treads a straight line from floor to landing would
    # pass under them.)
    if kind == "straight":
        local = [[0.0, 0.0, -0.25, "walk"], [0.0, r, half, "stairs"], [0.0, rise, run - half, "stairs"], [0.0, rise, run + 0.4, "walk"]]
    elif kind == "two_flight":
        head = reach["footprint"][1]
        n2 = reach["steps"] - reach["steps"] // 2
        # (Up the first flight to the landing's middle, across it, down the
        # second from its far end to a step past its head, round the hole.)
        local = [[-width / 2.0, 0.0, -0.4, "walk"], [-width / 2.0, r, half, "stairs"], [-width / 2.0, landing, run - half, "stairs"],
                 [-width / 2.0, landing, run + 0.5, "walk"], [width / 2.0, landing, run + 0.5, "walk"],
                 [width / 2.0, landing + r, run - half, "stairs"], [width / 2.0, rise, run - (n2 - 1) * TREAD - half, "stairs"],
                 [width / 2.0, rise, head - 0.3, "walk"], [width + 0.5, rise, head - 0.3, "walk"]]
    else:
        raise ValueError("no tour up a '%s' stair" % kind)

    turn = geo.rotation(yaw)
    return [geo.add(geo.apply(turn, p[:3]), list(at)) + [p[3]] for p in local]


# Triangles for a house: a bay's openings up its front, a storey's band
# across it, and an enterable one's floors and stairs (a 2-bay 4-storey
# house 2320, 3220 enterable; the harbour's casas are 5200).
BUDGET_BAY = 400
BUDGET_STOREY = 380
BUDGET_INSIDE = 900


def house_budget(bays, storeys, enterable):
    return BUDGET_BAY * bays + BUDGET_STOREY * storeys + (BUDGET_INSIDE if enterable else 0)


def rooms(plan, y, height, doors, slot="plaster", surface="stone"):
    """The partitions between a storey's rooms (`plan`: (x0, z0, x1, z1)
    each), PARTITION thick, `height` up from y, along each edge two rooms
    share; a ROOM_DOOR in it at each of `doors` ((x, z) on that edge)."""
    shapes, cols = [], []
    eps = 1e-6

    for i, a in enumerate(plan):
        for b in plan[i + 1:]:
            for xa, xb in ((a[2], b[0]), (b[2], a[0])):
                lo, hi = max(a[1], b[1]), min(a[3], b[3])

                if abs(xa - xb) < eps and hi - lo > eps:
                    middle = (lo + hi) / 2.0
                    # (Turned 90 degrees the wall's x runs to -z.)
                    holes = [kit_door(middle - dz) for dx, dz in doors if abs(dx - xa) < 0.3 and lo < dz < hi]
                    s, c = wall(hi - lo, height, PARTITION, holes, slot, (xa, middle, 90.0), surface)
                    shapes, cols = shapes + s, cols + c

            for za, zb in ((a[3], b[1]), (b[3], a[1])):
                lo, hi = max(a[0], b[0]), min(a[2], b[2])

                if abs(za - zb) < eps and hi - lo > eps:
                    middle = (lo + hi) / 2.0
                    holes = [kit_door(dx - middle) for dx, dz in doors if abs(dz - za) < 0.3 and lo < dx < hi]
                    s, c = wall(hi - lo, height, PARTITION, holes, slot, (middle, za, 0.0), surface)
                    shapes, cols = shapes + s, cols + c

    return placed(shapes, cols, y=y)


def kit_door(x):
    """A room's door in a partition, its middle x along it."""
    return Opening(x, 0.0, ROOM_DOOR[0], ROOM_DOOR[1], "door")


def _up_face(points, slot):
    """A roof face through `points`, wound to face up."""
    n = ks._normal(points)
    return ks.polygon(points if n[1] >= 0.0 else list(reversed(points)), slot)


def _slope_col(length, span, rise, y, along_z=False, side=1.0, surface="stone", eaves=None):
    """One pitched slab under a slope `span` / 2 wide rising `rise` from y
    to its ridge, `length` along it, on `side` (+1 or -1) of the middle:
    a slope down to +-z (or, along_z, a hipped end's down to +-x) whose
    eaves are `eaves` out from the middle (span / 2 when not given)."""
    half = span / 2.0
    out = (half if eaves is None else eaves) - half / 2.0
    pitch = math.degrees(math.atan2(rise, half))
    slope = math.hypot(half, rise)
    lift = k.ROOF_THICK / 2.0 / math.cos(math.radians(pitch))
    centre_y = y + rise / 2.0 + lift - 0.02

    if along_z:
        return col(side * out, centre_y, 0.0, slope, k.ROOF_THICK, length, surface, 0.0, 0.0, -side * pitch)

    return col(0.0, centre_y, side * out, length, k.ROOF_THICK, slope, surface, 0.0, side * pitch, 0.0)


def roof(kind, width, depth, eaves_y, pitch, slot, surface="stone", tiles="roof_spanish"):
    """A roof over walls width (x) by depth (z) whose top is at eaves_y:
        gable    ridge along x, slopes to the front and back, the ends
                 walled up in `slot` (the party walls' gables)
        hipped   four slopes, a ridge along the longer side (four: the same,
                 the Pombaline corner's)
        mansard  steep lower slopes (MANSARD[0]) MANSARD_HEIGHT up, then a
                 gable at MANSARD[1]
        flat     an azotea: a floor at eaves_y inside a PARAPET
    Every slope a man can stand on has a slab under it (the kit's
    roof_cols for the long slopes, pitched slabs for the ends)."""
    if kind == "flat":
        return _flat(width, depth, eaves_y, slot, surface)

    if kind == "mansard":
        lower, upper = MANSARD
        inset = MANSARD_HEIGHT / math.tan(math.radians(lower))
        top = eaves_y + MANSARD_HEIGHT
        shapes, cols = [], []

        for s in (-1.0, 1.0):
            shapes.append(_up_face([[-width / 2.0, eaves_y, s * depth / 2.0], [width / 2.0, eaves_y, s * depth / 2.0],
                                    [width / 2.0, top, s * (depth / 2.0 - inset)], [-width / 2.0, top, s * (depth / 2.0 - inset)]], tiles))

        # (The steep slopes are walls to a climber: an upright face under
        # them, its top the gable's eaves.)
        cols.append(col(0.0, (eaves_y + top) / 2.0, 0.0, width, MANSARD_HEIGHT, depth - 2.0 * inset, surface))
        s2, c2 = roof("gable", width, depth - 2.0 * inset, top, upper, slot, surface, tiles)
        return shapes + s2, cols + c2

    rise = depth / 2.0 * math.tan(math.radians(pitch))

    if kind == "gable":
        shapes = ib._tiled_roof(width, depth, rise, eaves_y, OVERHANG)
        cols = ib.roof_cols(width, depth, rise, eaves_y)

        for s in (-1.0, 1.0):
            shapes.append(ks.gable(s * (width / 2.0 - 0.1), eaves_y, 0.0, depth, rise, 0.2, slot, 90.0))

        return shapes, cols

    if kind in ("hipped", "four"):
        # (A ridge along the longer side, short by the shorter's span.)
        long_x = width >= depth
        span, length = (depth, width) if long_x else (width, depth)
        rise = span / 2.0 * math.tan(math.radians(pitch))
        ridge = max(0.0, length - span) / 2.0
        y1 = eaves_y + rise
        ex, ez = width / 2.0, depth / 2.0
        shapes, cols = [], []

        if long_x:
            r0, r1 = [-ridge, y1, 0.0], [ridge, y1, 0.0]

            for s in (-1.0, 1.0):
                shapes.append(_up_face([[-ex, eaves_y, s * ez], [ex, eaves_y, s * ez], r1, r0], tiles))
                shapes.append(_up_face([[s * ex, eaves_y, -ez], [s * ex, eaves_y, ez], r1 if s > 0 else r0], tiles))
                cols.append(_slope_col(width, depth, rise, eaves_y, False, s, surface))
                cols.append(_slope_col(depth, depth, rise, eaves_y, True, s, surface, ex))
        else:
            r0, r1 = [0.0, y1, -ridge], [0.0, y1, ridge]

            for s in (-1.0, 1.0):
                shapes.append(_up_face([[s * ex, eaves_y, -ez], [s * ex, eaves_y, ez], r1, r0], tiles))
                shapes.append(_up_face([[-ex, eaves_y, s * ez], [ex, eaves_y, s * ez], r1 if s > 0 else r0], tiles))
                cols.append(_slope_col(depth, width, rise, eaves_y, True, s, surface))
                cols.append(_slope_col(width, width, rise, eaves_y, False, s, surface, ez))

        return shapes, cols

    raise ValueError("no roof '%s'" % kind)


def _flat(width, depth, y, slot, surface):
    """An azotea: its floor's top at y over the whole roof, a PARAPET
    round it."""
    t = PARAPET_THICK
    shapes = [ks.box(0.0, y - SLAB / 2.0, 0.0, width, SLAB, depth, "terracotta")]
    cols = [col(0.0, y - SLAB / 2.0, 0.0, width, SLAB, depth, surface)]

    for s in (-1.0, 1.0):
        for c in ((0.0, s * (depth / 2.0 - t / 2.0), width, t), (s * (width / 2.0 - t / 2.0), 0.0, t, depth - 2.0 * t)):
            shapes.append(ks.box(c[0], y + PARAPET / 2.0, c[1], c[2], PARAPET, c[3], slot))
            cols.append(col(c[0], y + PARAPET / 2.0, c[1], c[2], PARAPET, c[3], surface))

    return shapes, cols


# Every key a design may carry onto its recipe as it is (the layout reads
# them): its live doors [x, y, z, yaw], the kinds of way into it, climbs
# [x, y, z, sx, sy, sz, yaw], ways in (key buildings), places, seats, beds,
# what stands under its roof, its budget, its eaves.
CARRIED = ("budget", "doors", "entries", "climbs", "ways", "roofed", "places", "seats", "beds", "eaves", "front", "door", "rooms_at")


def register(name, family, slot, design, surface="stone"):
    """`design` (shapes, cols, size; and any of CARRIED, chimneys) made the
    kit piece `name`; returns the name."""
    k.piece(name, family, slot, surface, [], cols=design["cols"], size=design["size"])
    k.model(name, design["shapes"])
    recipe = k.PIECES[name]

    for key, value in design.items():
        if key not in ("shapes", "cols", "size", "chimneys"):
            recipe[key] = value

    if design.get("chimneys"):
        recipe["sockets"] = {"chimney": [list(p) for p in design["chimneys"]]}

    return name
