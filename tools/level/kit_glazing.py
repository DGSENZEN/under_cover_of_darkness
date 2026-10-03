"""A real window (the real-windows spec, section 2): an opening through a
wall's whole thickness with leaded glass set back in it, for any kit.

    glazed   everything inside the opening's rectangle: its reveals (the
             outer half in the wall's slot, the inner half in the room's),
             the spandrels over a round or pointed head on both faces, the
             glass (`glazing`, which the moon goes through), the lead 1 cm
             in front of it (painted, cut: its bars cast into the patch), a
             glass collider filling it, and its record for the exporter
    strips   the wall's two faces round its holes (and its ends and top),
             its colliders split so none spans a hole (a whole collider
             would stop sight through the glass and occlude the view)
    around   a planar face (a hull's curved bulkhead) less rectangular holes
    moved    records turned and moved as kit_shapes.moved turns shapes

A wall's frame: x along it, y up, its outer face at `face_z` looking +z, its
inner face at `face_z - thickness`. A record: {"outline": the glass's
corners, "normal": out of the building, "lead", "outside"/"inside": the
wall's outer/inner face from the glass}; a piece carries its own as
PIECES[name]["windows"], and world_windows puts them in the world for the
manifest. Pure data, as the kits.
"""

import math

import geo
import kit_shapes as ks

# The glass's depth behind the wall's outer face (m).
SETBACK = 0.15
# A lead's painting (its slot).
LEADS = {"quarries": "quarries", "casement": "casement", "grille": "window_grille"}
# A round head's segments; a pointed head's, a side.
ROUND = 8
POINTED = 4


def hole(x, sill, width, height):
    """The opening's rectangle (x0, x1, y0, y1) in the wall."""
    return (x - width / 2.0, x + width / 2.0, sill, sill + height)


def outline(x, sill, width, height, shape="square"):
    """The opening's outline [[x, y], ...], counter-clockwise seen from
    outside, from the sill's left corner: "square" 4 corners; "round" the
    sill's corners, then its head from the right springing over to the left
    in ROUND segments; "arched" (pointed, equilateral) POINTED a side."""
    x0, x1, top = x - width / 2.0, x + width / 2.0, sill + height
    out = [[x0, sill], [x1, sill]]

    if shape == "square":
        return out + [[x1, top], [x0, top]]

    if shape == "round":
        r = width / 2.0
        spring = top - r
        return out + [[x + r * math.cos(math.pi * i / ROUND), spring + r * math.sin(math.pi * i / ROUND)] for i in range(ROUND + 1)]

    if shape == "arched":
        spring = top - width * math.sin(math.radians(60.0))
        right = [[x0 + width * math.cos(math.radians(60.0 * i / POINTED)), spring + width * math.sin(math.radians(60.0 * i / POINTED))]
                 for i in range(POINTED + 1)]
        left = [[x1 + width * math.cos(math.radians(120.0 + 60.0 * i / POINTED)), spring + width * math.sin(math.radians(120.0 + 60.0 * i / POINTED))]
                for i in range(1, POINTED + 1)]
        return out + right + left

    raise ValueError("no window shape '%s'" % shape)


def facing(points, normal, slot, uvs=None):
    """A face through `points` wound to look along `normal`."""
    n = ks._normal(points)

    if sum(n[i] * normal[i] for i in range(3)) < 0.0:
        points = list(reversed(points))
        uvs = list(reversed(uvs)) if uvs is not None else None

    return ks.polygon(points, slot, uvs)


def glazed(x, sill, width, height, face_z, thickness, shape="square", lead="casement", setback=SETBACK, slot="granite", inner_slot="plaster"):
    """A glazed opening, its middle `x` along the wall, from `sill` up,
    `width` by `height`: (shapes, cols, record). The wall round it is the
    caller's (strips, with the same hole)."""
    pts = outline(x, sill, width, height, shape)
    x0, x1, top = x - width / 2.0, x + width / 2.0, sill + height
    inner, middle = face_z - thickness, face_z - thickness / 2.0
    shapes = []

    # The reveals: each edge of the outline drawn through the wall, looking
    # into the opening (left of the edge, the outline being counter-clockwise).
    for i in range(len(pts)):
        a, b = pts[i], pts[(i + 1) % len(pts)]
        into = (-(b[1] - a[1]), b[0] - a[0], 0.0)

        for z0, z1, s in ((face_z, middle, slot), (middle, inner, inner_slot)):
            shapes.append(facing([[a[0], a[1], z0], [b[0], b[1], z0], [b[0], b[1], z1], [a[0], a[1], z1]], into, s))

    # Over a round or pointed head, the rectangle's corners filled on both
    # faces (each a fan from its corner, which sees the whole arc).
    if shape != "square":
        head = pts[2:]
        apex = len(head) // 2

        for corner, arc in (([x1, top], head[:apex + 1]), ([x0, top], head[apex:])):
            ring = [corner] + list(reversed(arc))

            for z, look, s in ((face_z, 1.0, slot), (inner, -1.0, inner_slot)):
                shapes.append(facing([[p[0], p[1], z] for p in ring], (0.0, 0.0, look), s))

    # The glass, and the lead in front of it, both ways, their pictures
    # spanning the rectangle.
    uvs = [[(p[0] - x0) / width, (top - p[1]) / height] for p in pts]
    glass_z = face_z - setback

    for z, s in ((glass_z, "glazing"), (glass_z + 0.01, LEADS[lead])):
        ring = [[p[0], p[1], z] for p in pts]
        shapes.append(ks.polygon(ring, s, uvs))
        shapes.append(ks.polygon(list(reversed(ring)), s, list(reversed(uvs))))

    cols = [[x, sill + height / 2.0, middle, width, height, thickness, "glass", 0.0, 0.0, 0.0]]
    record = {"outline": [[p[0], p[1], glass_z] for p in pts], "normal": [0.0, 0.0, 1.0], "lead": lead,
              "outside": setback, "inside": thickness - setback}
    return shapes, cols, record


def split(x0, x1, y0, y1, holes):
    """The rectangle x0..x1 by y0..y1 less `holes` ((x0, x1, y0, y1) each),
    as rectangles that cover it: cut into strips at every hole's sides,
    each strip less the holes across it (kit_town's own, until its session
    takes this one)."""
    cuts = sorted({x0, x1} | {h[i] for h in holes for i in (0, 1) if x0 < h[i] < x1})
    out = []

    for u, v in zip(cuts, cuts[1:]):
        if v - u < 1e-6:
            continue

        across = sorted((max(h[2], y0), min(h[3], y1)) for h in holes if h[0] < v - 1e-6 and h[1] > u + 1e-6 and h[3] > y0 and h[2] < y1)
        at = y0

        for lo, hi in across:
            if lo > at + 1e-6:
                out.append((u, v, at, lo))

            at = max(at, hi)

        if y1 > at + 1e-6:
            out.append((u, v, at, y1))

    return out


def strips(x0, x1, y0, y1, zc, thickness, holes, slot, surface="stone", inner_slot=None):
    """A wall x0..x1 by y0..y1, `thickness` through z about zc, less its
    holes: its outer face (+z) and inner face round them, its ends and its
    top; a collider for each rectangle of `split`."""
    front, back = zc + thickness / 2.0, zc - thickness / 2.0
    shapes, cols = [], []

    for a0, a1, b0, b1 in split(x0, x1, y0, y1, holes):
        shapes.append(facing([[a0, b0, front], [a1, b0, front], [a1, b1, front], [a0, b1, front]], (0.0, 0.0, 1.0), slot))
        shapes.append(facing([[a0, b0, back], [a1, b0, back], [a1, b1, back], [a0, b1, back]], (0.0, 0.0, -1.0), inner_slot or slot))
        cols.append([(a0 + a1) / 2.0, (b0 + b1) / 2.0, zc, a1 - a0, b1 - b0, thickness, surface, 0.0, 0.0, 0.0])

    for x, look in ((x0, -1.0), (x1, 1.0)):
        shapes.append(facing([[x, y0, back], [x, y0, front], [x, y1, front], [x, y1, back]], (look, 0.0, 0.0), slot))

    shapes.append(facing([[x0, y1, back], [x1, y1, back], [x1, y1, front], [x0, y1, front]], (0.0, 1.0, 0.0), slot))
    return shapes, cols


def around(outline_points, holes, axis, slot, look):
    """A planar face through `outline_points` (on axis = constant, "x" or
    "z"; monotone in y) less `holes` ((u0, u1, v0, v1) with u the plane's
    other axis: z on an x-plane, x on a z-plane; v its y), looking along
    `look`. Cut into bands at every corner's and hole's height, each band a
    trapezoid less the holes across it."""
    k = 0 if axis == "x" else 2
    uk = 2 if axis == "x" else 0
    plane = outline_points[0][k]
    flat = [(p[uk], p[1]) for p in outline_points]
    vs = [p[1] for p in flat]
    v_lo, v_hi = min(vs), max(vs)
    cuts = sorted({v for v in vs} | {h[i] for h in holes for i in (2, 3) if v_lo < h[i] < v_hi})
    shapes = []

    def span(v):
        """The outline's u at height v: (left, right)."""
        found = []

        for i in range(len(flat)):
            (au, av), (bu, bv) = flat[i], flat[(i + 1) % len(flat)]

            if min(av, bv) <= v <= max(av, bv) and abs(bv - av) > 1e-12:
                found.append(au + (v - av) * (bu - au) / (bv - av))

        return min(found), max(found)

    def point(u, v):
        return [plane, v, u] if axis == "x" else [u, v, plane]

    for va, vb in zip(cuts, cuts[1:]):
        if vb - va < 1e-6:
            continue

        e = min(1e-6, (vb - va) / 4.0)
        la, ra = span(va + e)
        lb, rb = span(vb - e)
        across = sorted((h[0], h[1]) for h in holes if h[2] <= va + e and h[3] >= vb - e)
        # The pieces: from the left edge to the first hole, between holes,
        # from the last hole to the right edge.
        edges = [(la, lb)] + [(u, u) for h in across for u in h] + [(ra, rb)]

        for (a_lo, b_lo), (a_hi, b_hi) in zip(edges[0::2], edges[1::2]):
            if a_hi - a_lo < 1e-6 and b_hi - b_lo < 1e-6:
                continue

            shapes.append(facing([point(a_lo, va), point(a_hi, va), point(b_hi, vb), point(b_lo, vb)], look, slot))

    return shapes


def moved(records, yaw=0.0, offset=(0.0, 0.0, 0.0)):
    """Copies of `records` turned `yaw` degrees about the upright, then moved
    by `offset`, as kit_shapes.moved does shapes (the normal only turned)."""
    turn = geo.rotation(yaw)
    out = []

    for r in records:
        r = dict(r)
        r["outline"] = [geo.add(geo.apply(turn, p), list(offset)) for p in r["outline"]]
        r["normal"] = geo.apply(turn, r["normal"])
        out.append(r)

    return out


def world_windows(pieces, recipes):
    """Every placed piece's records in the world, for the manifest: each
    {piece, sector, lead, outline, normal}, rounded to 4 places (its points
    through the piece's position and basis, its normal through its basis)."""
    out = []

    for p in pieces:
        for r in recipes[p["piece"]].get("windows", []):
            out.append({"piece": p["name"], "sector": p["sector"], "lead": r["lead"],
                        "outside": round(r.get("outside", 0.0), 4), "inside": round(r.get("inside", 0.0), 4),
                        "outline": [[round(v, 4) for v in geo.add(p["position"], geo.apply(p["basis"], q))] for q in r["outline"]],
                        "normal": [round(v, 4) for v in geo.apply(p["basis"], r["normal"])]})

    return out
