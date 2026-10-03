"""The old town's lot plan and its ground (its spec, sections 4.1-4.3 and
5.1; plan B1a, Task 13): pure data, read both by the kit (kit_town
registers one piece per distinct house design when the kit is built) and
by the layout (layouts/old_town places each lot, its doors and its ways).

    Lot          a house on its lot: its family, where its front's middle is
                 (x, z, on the street at y, the house behind it turned by
                 yaw), its size, storeys, quirk, whether it is walked in
    design_key   the piece a lot's design is built as (equal designs share
                 one, whatever their place)
    TERRACES     the ground: flat (or gently sloping) plates, quarter by
                 quarter, at the spec's heights; height(x, z) reads them
    QUARTERS     each quarter's box; sector_of(x, z) the sector a place is in
    all_lots     every quarter's lots (town/<quarter>.py, LOTS)
    slits        neighbours that leave a slit a foot falls into (0.05-1.0 m)
    terrace_pieces  every terrace piece the quarters ask for (TERRACE)

Godot's axes: x east, y up, z south (the harbour to +z); a quarter's
"north" is -z.
"""

import hashlib
import math
from dataclasses import dataclass

# A height no ground has: the passage through the Sea Gate, where its own
# floor is the floor.
HOLE = -100.0
PASSAGE = (-58.0, -52.0, -91.0, -75.0)

QUARTERS = {
    "baixa": (-100.0, -170.0, 15.0, -73.0),
    "stairs": (-180.0, -290.0, -100.0, -21.0),
    "judiaria": (15.0, -290.0, 150.0, -73.0),
    "carmo": (-100.0, -290.0, 15.0, -170.0),
    "upper": (-180.0, -380.0, 150.0, -290.0),
}

# The ground's plates: (name, quarter, x0, z0, x1, z1, y at z1 (south), y at
# z0 (north)). Each quarter steps up to the north; the steps between plates
# are the quarters' retaining walls and stairs (Tasks 14-18).
TERRACES = [
    # The Baixa: low behind the Sea Gate at the quays' height, rising
    # gently north to its square.
    ("baixa_low", "baixa", -100.0, -115.0, 15.0, -73.0, 2.5, 2.5),
    ("baixa_slope", "baixa", -100.0, -170.0, 15.0, -115.0, 2.5, 6.0),
    # The Carmo hill: its lookout terrace 20 m over the Baixa's north edge,
    # the ruin's square, a step up toward the upper town.
    ("carmo_lookout", "carmo", -100.0, -185.0, 15.0, -170.0, 26.0, 26.0),
    ("carmo_square", "carmo", -100.0, -265.0, 15.0, -185.0, 28.0, 28.0),
    ("carmo_high", "carmo", -100.0, -290.0, 15.0, -265.0, 40.0, 40.0),
    # The stairs: terraces up the west side from behind the Ribeira (its
    # houses' tops), the Guindais gate's terrace at the harbour's postern.
    ("stairs_1", "stairs", -180.0, -45.0, -100.0, -21.0, 14.0, 14.0),
    ("stairs_2", "stairs", -180.0, -70.0, -100.0, -45.0, 18.5, 18.5),
    ("stairs_3", "stairs", -180.0, -110.0, -100.0, -70.0, 26.77, 26.77),
    ("stairs_4", "stairs", -180.0, -135.0, -100.0, -110.0, 31.0, 31.0),
    ("stairs_5", "stairs", -180.0, -160.0, -100.0, -135.0, 36.0, 36.0),
    ("stairs_6", "stairs", -180.0, -185.0, -100.0, -160.0, 41.0, 41.0),
    ("stairs_7", "stairs", -180.0, -210.0, -100.0, -185.0, 46.0, 46.0),
    ("stairs_8", "stairs", -180.0, -235.0, -100.0, -210.0, 50.5, 50.5),
    ("stairs_9", "stairs", -180.0, -260.0, -100.0, -235.0, 55.0, 55.0),
    ("stairs_10", "stairs", -180.0, -290.0, -100.0, -260.0, 60.0, 60.0),
    # The Judiaria: behind the east wall at its walk's height, up to the
    # upper town.
    ("judiaria_1", "judiaria", 15.0, -100.0, 150.0, -73.0, 14.0, 14.0),
    ("judiaria_2", "judiaria", 15.0, -130.0, 150.0, -100.0, 19.0, 19.0),
    ("judiaria_3", "judiaria", 15.0, -160.0, 150.0, -130.0, 24.0, 24.0),
    ("judiaria_4", "judiaria", 15.0, -190.0, 150.0, -160.0, 29.0, 29.0),
    ("judiaria_5", "judiaria", 15.0, -220.0, 150.0, -190.0, 35.0, 35.0),
    ("judiaria_6", "judiaria", 15.0, -250.0, 150.0, -220.0, 41.0, 41.0),
    ("judiaria_7", "judiaria", 15.0, -265.0, 150.0, -250.0, 48.0, 48.0),
    ("judiaria_8", "judiaria", 15.0, -290.0, 150.0, -265.0, 55.0, 55.0),
    # The upper town, up to the upper gate at +85.
] + [("upper_%d%s" % (i + 1, side), "upper", x0, z0, x1, z1, y, y)
     for i, (z0, z1, y) in enumerate(((-310.0, -290.0, 62.0), (-335.0, -310.0, 68.0), (-355.0, -335.0, 75.0), (-380.0, -355.0, 85.0)))
     # (Its plates halved at x -15: the upper town's two sectors.)
     for side, x0, x1 in (("w", -180.0, -15.0), ("e", -15.0, 150.0))]

# The level's sectors (at most about 100 m): each quarter's halves, the
# ground below, the shared wall.
SECTORS = {
    "baixa": [("baixa_s", -115.0), ("baixa_n", -1000.0)],
    "stairs": [("stairs_lo", -160.0), ("stairs_hi", -1000.0)],
    "judiaria": [("judiaria_lo", -180.0), ("judiaria_hi", -1000.0)],
    "carmo": [("carmo", -1000.0)],
    "upper": [("upper_w", None), ("upper_e", None)],
}


def inside(x, z, box):
    """Whether (x, z) is in box (x0, x1, z0, z1)."""
    return box[0] <= x <= box[1] and box[2] <= z <= box[3]


def plate_at(x, z):
    """The plate (x, z) is on, or None."""
    for plate in TERRACES:
        _name, _q, x0, z0, x1, z1, _ys, _yn = plate

        if x0 <= x <= x1 and z0 <= z <= z1:
            return plate

    return None


def plate_height(plate, z):
    """A plate's ground at z: its south height at z1 to its north at z0."""
    _name, _q, _x0, z0, _x1, z1, south, north = plate
    t = 0.0 if z1 == z0 else (z1 - z) / (z1 - z0)
    return south + (north - south) * min(1.0, max(0.0, t))


def height(x, z):
    """The old town's ground at (x, z): its plate's, or HOLE (the Sea Gate's
    passage, or nowhere in the old town)."""
    if inside(x, z, PASSAGE):
        return HOLE

    plate = plate_at(x, z)
    return HOLE if plate is None else plate_height(plate, z)


def quarter_of(x, z):
    for name, (x0, z0, x1, z1) in QUARTERS.items():
        if x0 <= x <= x1 and z0 <= z <= z1:
            return name

    return None


def sector_of(x, z):
    """The level's sector a place is in (by its quarter, then north or south
    of the quarter's cut; the upper town west or east of x -15)."""
    quarter = quarter_of(x, z)

    if quarter is None:
        return "wall"

    if quarter == "upper":
        return "upper_w" if x < -15.0 + 1e-6 else "upper_e"

    for name, cut in SECTORS[quarter]:
        if z >= cut:
            return name

    return SECTORS[quarter][-1][0]


@dataclass(frozen=True)
class Lot:
    """A house on its lot: see the module's doc. `params` its family's
    further design arguments, (key, value) pairs."""
    name: str
    family: str
    x: float
    z: float
    y: float
    yaw: float
    width: float
    depth: float
    storeys: int
    quirk: str = ""
    enterable: bool = False
    rooms: int = 0
    lived: bool = False
    sector: str = ""
    params: tuple = ()

    def footprint(self):
        """Its four corners (x, z) in the world: its front's line, its back."""
        a = math.radians(self.yaw)
        cos, sin = math.cos(a), math.sin(a)
        out = []

        for lx, lz in ((-self.width / 2.0, 0.0), (self.width / 2.0, 0.0), (self.width / 2.0, -self.depth), (-self.width / 2.0, -self.depth)):
            out.append((self.x + cos * lx + sin * lz, self.z - sin * lx + cos * lz))

        return out


def design_key(lot):
    """The piece a lot's design is built as: its family, measures, quirk,
    whether it is walked in and its family's arguments; never its place."""
    fields = (lot.family, round(lot.width, 2), round(lot.depth, 2), lot.storeys, lot.quirk, lot.enterable, lot.rooms, lot.params)
    digest = hashlib.md5(repr(fields).encode()).hexdigest()[:6]
    return "town_%s_%dx%d_s%d%s%s_%s" % (lot.family, int(round(lot.width * 10)), int(round(lot.depth)), lot.storeys,
                                         "_" + lot.quirk if lot.quirk else "", "_e%d" % lot.rooms if lot.enterable else "", digest)


def all_lots():
    """Every quarter's lots, in quarter order."""
    from town import baixa, carmo, judiaria, stairs, upper
    return list(baixa.LOTS) + list(stairs.LOTS) + list(judiaria.LOTS) + list(carmo.LOTS) + list(upper.LOTS)


def terrace_pieces():
    """Every terrace piece the quarters ask for: (kind, args) pairs."""
    from town import baixa, carmo, judiaria, stairs, upper
    out = []

    for q in (baixa, stairs, judiaria, carmo, upper):
        out += list(getattr(q, "TERRACE", []))

    return out


def _rect(lot):
    """A lot turned to an axis-aligned rectangle (x0, z0, x1, z1): lots are
    laid square to the streets (yaw a quarter turn)."""
    xs = [p[0] for p in lot.footprint()]
    zs = [p[1] for p in lot.footprint()]
    return min(xs), min(zs), max(xs), max(zs)


def slits(lots):
    """Pairs of lots side by side with a gap between them more than a
    shared wall's slack (0.05 m) and less than a lane (1.0 m): a slit a
    foot falls in. [(a, b, gap)]."""
    out = []
    rects = [(lot, _rect(lot)) for lot in lots]

    for i, (a, ra) in enumerate(rects):
        for b, rb in rects[i + 1:]:
            gap_x = max(rb[0] - ra[2], ra[0] - rb[2])
            gap_z = max(rb[1] - ra[3], ra[1] - rb[3])
            # (Side by side: overlapping along one axis, apart along the
            # other.)
            if gap_z < 0.0 and 0.05 < gap_x < 1.0:
                out.append((a.name, b.name, round(gap_x, 3)))
            elif gap_x < 0.0 and 0.05 < gap_z < 1.0:
                out.append((a.name, b.name, round(gap_z, 3)))

    return out
