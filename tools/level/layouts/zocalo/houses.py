"""The colonial house blocks that fill the Zócalo out to the brink: lots of
about 20 m frontage and 14 m depth round each block's street sides, two or
three storeys, the block's middle left open as its patios. A lot that would
face no street, or would stand on a landmark already laid, is left out."""

import zlib

import plan
import plan_check
from plan import rect

FRONT = 20.0
DEPTH = 14.0
HEIGHTS = {2: 9.0, 3: 13.0}

# (name, x0, z0, x1, z1, sides with lots: n s w e)
BLOCKS = [
    ("a", -215, -110, -140, 35, "nsw"),
    ("b", -310, -110, -235, 35, "nse"),
    ("c", -310, 50, -235, 160, "nse"),
    ("d", -215, 50, -120, 160, "nswe"),
    ("d2", -120, 130, -100, 160, "ns"),
    ("nw", -310, -305, -235, -125, "nse"),
    ("sds", -215, -210, -140, -125, "nswe"),
    ("pawn", -120, -265, -90, -130, "nswe"),
    ("nw_strip", -310, -340, -120, -325, "s"),
    ("n_strip", -120, -340, 310, -285, "s"),
    ("dn", 60, -265, 200, -225, "nswe"),
    ("de", 150, -225, 200, -145, "nswe"),
    ("pn", 120, -130, 200, -105, "nswe"),
    ("se", 120, 105, 200, 160, "nswe"),
    ("e0", 100, 130, 120, 160, "ns"),
    ("e1", 220, -265, 310, -145, "nsw"),
    ("e2", 220, -130, 310, 0, "nsw"),
    ("e3", 220, 15, 310, 160, "nsw"),
]


def _storeys(name):
    return 2 + zlib.crc32(name.encode()) % 2


def _run(a, b, n):
    step = (b - a) / n
    return [(a + i * step, a + (i + 1) * step) for i in range(n)]


def lots(x0, z0, x1, z1, sides):
    """The block's lots as rectangles, round its given sides."""
    d = min(DEPTH, (z1 - z0) / (2 if "n" in sides and "s" in sides else 1), (x1 - x0) / (2 if "w" in sides and "e" in sides else 1))
    out = []
    n = max(1, round((x1 - x0) / FRONT))

    if "n" in sides:
        out += [rect(a, z0, b, z0 + d) for a, b in _run(x0, x1, n)]
    if "s" in sides:
        out += [rect(a, z1 - d, b, z1) for a, b in _run(x0, x1, n)]

    za = z0 + (d if "n" in sides else 0)
    zb = z1 - (d if "s" in sides else 0)

    if zb - za > 4:
        m = max(1, round((zb - za) / FRONT))

        if "w" in sides:
            out += [rect(x0, a, x0 + d, b) for a, b in _run(za, zb, m)]
        if "e" in sides:
            out += [rect(x1 - d, a, x1, b) for a, b in _run(za, zb, m)]

    return out


def lay(P):
    data = P.data()
    # A house faces a street, a plaza or the canal, never only a dig.
    frontage = [g for g in data["ground"] if g["kind"] in plan.FRONTAGE_KINDS and g["kind"] != "dig"]

    for name, x0, z0, x1, z1, sides in BLOCKS:
        for i, lot in enumerate(lots(x0, z0, x1, z1, sides)):
            if any(plan_check.overlap_area(p["polygon"], lot) >= plan_check.OVERLAP for p in P.plots):
                continue

            middles = [((a[0] + b[0]) / 2, (a[1] + b[1]) / 2) for a, b in plan_check._edges(lot)]

            if not any(plan_check.near(m, g["polygon"], plan_check.FRONTAGE) for m in middles for g in frontage):
                continue

            lot_name = "house_%s_%d" % (name, i + 1)
            storeys = _storeys(lot_name)
            P.plot(lot_name, "house", lot, storeys=storeys, height=HEIGHTS[storeys])
