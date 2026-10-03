"""The way to the fort: a stone bridge from the Ribeira quay's west end due
south over the water (four segmental arches on cutwater piers, a refuge
over each cutwater, steps up from the quay between two posts), then the
causeway on along the spit's crest, its dog-leg before the bastion (south,
east along its front, south into its gate). One mesh laid as terrain (its
collider exactly what is drawn): the deck at the bastion's top, the
parapets each one sweep from the quay to the bastion (round every refuge
and bend, mitred: no seam anywhere), a string course under them, arch rings
standing proud of the bridge's faces."""

import math

import terrain

from . import CAUSEWAY, CAUSEWAY_DECK, QUAY
from .sweep import Mesh, mitred, sweep

DECK = CAUSEWAY_DECK
HALF = 2.8
BED = -7.0
# The bridge along its first stretch (a: from the quay's face, south): its
# steps, its spans and piers, its arches (segmental: springing, rise), a
# pier's cutwaters out each side; the causeway on from its end.
STEPS = (8, 0.3)
ABUTMENT = 3.0
SPAN = 8.0
PIER = 2.4
SPANS = 4
SPRING = 1.0
RISE = 2.2
CUT = 2.0
RING = 0.5
PROUD = 0.04
ARC = 10
BRIDGE_END = ABUTMENT + SPANS * SPAN + (SPANS - 1) * PIER
# The parapet (thick, tall), its cap (over it, standing out), the string
# course under it (standing out, its bottom under the deck).
PARAPET = (0.45, 0.9)
CAP = (0.05, 0.12)
COURSE = (0.08, 0.25, 0.05)
# A post at each parapet's foot on the quay: its side, its top.
POST = (0.7, DECK + 1.3)


def _bridge_x():
    return CAUSEWAY[0][0]


def _w(a, s, y):
    """A point of the bridge (a along it from the quay, s across it to its
    east) in the world."""
    return [_bridge_x() + s, y, CAUSEWAY[0][1] + a]


def spans():
    """Each span's ends (a)."""
    out = []
    a = ABUTMENT

    for k in range(SPANS):
        out.append((a, a + SPAN))
        a += SPAN + PIER

    return out


def piers():
    return [(b, b + PIER) for (_, b) in spans()[:-1]]


def arch(out=0.0):
    """A span's arch across it from its left foot to its right [(u, y)]
    (u from its middle), `out` m outside its intrados (the same centre)."""
    half = SPAN / 2.0
    radius = (half * half + RISE * RISE) / (2.0 * RISE)
    centre = SPRING + RISE - radius
    foot = math.asin((SPRING - centre) / radius)
    pts = []

    for i in range(ARC + 1):
        t = math.pi - foot - (math.pi - 2.0 * foot) * i / ARC
        pts.append(((radius + out) * math.cos(t), centre + (radius + out) * math.sin(t)))

    return pts


def _parapet_section():
    """Across a parapet's outer line (its outward to the left): up its inner
    face from the deck, over its cap, down its outer face, the string
    course standing out under it."""
    t, h = PARAPET
    o, c = CAP
    p, low, high = COURSE
    return [(-t, DECK, "granite"), (-t, DECK + h, "ashlar_gold"), (-t - o, DECK + h, "ashlar_gold"), (-t - o, DECK + h + c, "ashlar_gold"),
            (o, DECK + h + c, "ashlar_gold"), (o, DECK + h, "ashlar_gold"), (0.0, DECK + h, "granite"), (0.0, DECK - high, "ashlar_gold"),
            (p, DECK - high, "ashlar_gold"), (p, DECK - low, "ashlar_gold"), (0.0, DECK - low, None)]


def _body_section():
    """The causeway's body across it (s to its left): its battered foot,
    its faces up to the string course, its deck between the parapets
    (which, with the course, are swept on their own)."""
    t = PARAPET[0]
    low = COURSE[1]
    return [(-HALF - 0.5, BED, "granite_rough"), (-HALF, 1.2, "granite"), (-HALF, DECK - low, None), (-HALF + t, DECK, "granite"),
            (HALF - t, DECK, None), (HALF, DECK - low, "granite"), (HALF, 1.2, "granite_rough"), (HALF + 0.5, BED, None)]


def _causeway_line():
    """The causeway's middle line, from the bridge's end on."""
    (x0, z0), (x1, z1) = CAUSEWAY[0], CAUSEWAY[1]
    length = math.hypot(x1 - x0, z1 - z0)
    f = BRIDGE_END / length
    return [(x0 + (x1 - x0) * f, z0 + (z1 - z0) * f)] + list(CAUSEWAY[1:])


def parapet_line(side):
    """A parapet's outer line (side +1 east, -1 west of the bridge), from
    the quay's posts to the bastion, round each refuge."""
    line = [(_bridge_x() + side * HALF, CAUSEWAY[0][1] + POST[0])]

    for p0, p1 in piers():
        line.append((_bridge_x() + side * HALF, CAUSEWAY[0][1] + p0))
        line.append((_bridge_x() + side * (HALF + CUT), CAUSEWAY[0][1] + (p0 + p1) / 2.0))
        line.append((_bridge_x() + side * HALF, CAUSEWAY[0][1] + p1))

    for x, z, across, _ in mitred(_causeway_line()):
        line.append((x + across[0] * HALF * side, z + across[1] * HALF * side))

    return line


def _bridge(m):
    top = DECK - COURSE[1]

    # Its steps up from the quay, between cheeks (the parapets' inner faces
    # carried down beside them).
    n, tread = STEPS
    rise = (DECK - QUAY) / n
    inner = HALF - PARAPET[0]

    for k in range(n):
        y0, y1, a0, a1 = QUAY + rise * k, QUAY + rise * (k + 1), tread * k, tread * (k + 1)
        m.face([_w(a0, -inner, y0), _w(a0, inner, y0), _w(a0, inner, y1), _w(a0, -inner, y1)], [0.0, 0.0, -1.0], "granite")
        m.face([_w(a0, -inner, y1), _w(a0, inner, y1), _w(a1, inner, y1), _w(a1, -inner, y1)], [0.0, 1.0, 0.0], "granite")

    for side in (-1.0, 1.0):
        m.face([_w(0.0, side * inner, QUAY), _w(n * tread, side * inner, QUAY), _w(n * tread, side * inner, DECK), _w(0.0, side * inner, DECK)],
               [-side, 0.0, 0.0], "granite")

    # Its deck, and a refuge's floor over each cutwater.
    m.face([_w(n * tread, -inner, DECK), _w(n * tread, inner, DECK), _w(BRIDGE_END, inner, DECK), _w(BRIDGE_END, -inner, DECK)], [0.0, 1.0, 0.0], "granite")

    for p0, p1 in piers():
        for side in (-1.0, 1.0):
            m.face([_w(p0, side * inner, DECK), _w(p1, side * inner, DECK), _w(p1, side * HALF, DECK), _w((p0 + p1) / 2.0, side * (HALF + CUT), DECK),
                    _w(p0, side * HALF, DECK)], [0.0, 1.0, 0.0], "granite")

    # Its faces: the abutment's by the quay, over each span's arch.
    for side in (-1.0, 1.0):
        look = [side, 0.0, 0.0]
        m.face([_w(0.0, side * HALF, BED), _w(ABUTMENT, side * HALF, BED), _w(ABUTMENT, side * HALF, top), _w(0.0, side * HALF, top)], look,
               "granite")

        for a0, a1 in spans():
            middle = (a0 + a1) / 2.0
            outline = [(a0, top)] + [(middle + u, y) for u, y in arch()] + [(a1, top)]
            m.polygon(outline, lambda a, y, side=side: _w(a, side * HALF, y), look, "granite")

            # The arch's ring standing proud of the face, its edges (the
            # intrados's looking in to the arch's centre, the extrados's
            # out from it).
            inner_ring, outer_ring = arch(), arch(RING)
            s = side * (HALF + PROUD)
            centre = SPRING + RISE - (SPAN * SPAN / 4.0 + RISE * RISE) / (2.0 * RISE)

            for (u0, y0), (u1, y1), (v0, q0), (v1, q1) in zip(inner_ring, inner_ring[1:], outer_ring, outer_ring[1:]):
                m.face([_w(middle + u0, s, y0), _w(middle + u1, s, y1), _w(middle + v1, s, q1), _w(middle + v0, s, q0)], look, "ashlar_gold")
                u, y = (u0 + u1) / 2.0, (y0 + y1) / 2.0
                m.face([_w(middle + u0, side * HALF, y0), _w(middle + u1, side * HALF, y1), _w(middle + u1, s, y1), _w(middle + u0, s, y0)],
                       [0.0, centre - y, -u], "ashlar_gold")
                v, q = (v0 + v1) / 2.0, (q0 + q1) / 2.0
                m.face([_w(middle + v0, side * HALF, q0), _w(middle + v1, side * HALF, q1), _w(middle + v1, s, q1), _w(middle + v0, s, q0)],
                       [0.0, q - centre, v], "ashlar_gold")

    # Under each arch, its soffit.
    for a0, a1 in spans():
        middle = (a0 + a1) / 2.0
        ring = arch()

        for (u0, y0), (u1, y1) in zip(ring, ring[1:]):
            m.face([_w(middle + u0, -HALF, y0), _w(middle + u1, -HALF, y1), _w(middle + u1, HALF, y1), _w(middle + u0, HALF, y0)],
                   [0.0, -1.0, -(u0 + u1) / 2.0 * 0.2], "granite")

    # The abutment's face under the first arch; each pier's faces to its
    # spans and its cutwaters up to the refuge.
    m.face([_w(ABUTMENT, -HALF, BED), _w(ABUTMENT, HALF, BED), _w(ABUTMENT, HALF, SPRING), _w(ABUTMENT, -HALF, SPRING)], [0.0, 0.0, 1.0], "granite")

    for p0, p1 in piers():
        m.face([_w(p0, -HALF, BED), _w(p0, HALF, BED), _w(p0, HALF, SPRING), _w(p0, -HALF, SPRING)], [0.0, 0.0, -1.0], "granite")
        m.face([_w(p1, -HALF, BED), _w(p1, HALF, BED), _w(p1, HALF, SPRING), _w(p1, -HALF, SPRING)], [0.0, 0.0, 1.0], "granite")

        for side in (-1.0, 1.0):
            tip = ((p0 + p1) / 2.0, side * (HALF + CUT))
            # (Each of its two faces looks out from the cutwater's middle.)
            inside = ((p0 + p1) / 2.0, side * (HALF + CUT / 3.0))

            for (a0, s0), (a1, s1) in (((p0, side * HALF), tip), (tip, (p1, side * HALF))):
                n = (s1 - s0, -(a1 - a0))

                if n[0] * ((a0 + a1) / 2.0 - inside[0]) + n[1] * ((s0 + s1) / 2.0 - inside[1]) < 0.0:
                    n = (-n[0], -n[1])

                m.face([_w(a0, s0, BED), _w(a1, s1, BED), _w(a1, s1, top), _w(a0, s0, top)], [n[1], 0.0, n[0]], "granite_rough")


def body():
    """The bridge and the causeway: one Mesh."""
    m = Mesh()
    _bridge(m)
    # The causeway's body from the bridge's end (its start, under the last
    # arch, closed: the arch springs from it) to the bastion (its end in
    # the bastion's batter, open).
    sweep(m, _body_section(), mitred(_causeway_line()), start=True, end=False)

    # The parapets: east from the quay south, west from the bastion north
    # (each so its outer side is to its left).
    for side in (1.0, -1.0):
        line = parapet_line(side)
        sweep(m, _parapet_section(), mitred(line if side > 0 else line[::-1]), start=True, end=True)

    return m


def lay(L):
    m = body()
    L.terrain(m.data("spit_causeway", "fort", surface="stone", tint=lambda x, y, z: [0.74, 0.78, 0.72] if y < 1.0 else [1.0, 1.0, 1.0]))

    # The posts at the parapets' feet on the quay.
    for side in (-1.0, 1.0):
        L.put("bridge_post", (_bridge_x() + side * (HALF - POST[0] / 2.0 + 0.125), QUAY, CAUSEWAY[0][1] + POST[0] / 2.0), 0.0, "fort")
