"""Kit v1's shapes: what a modelled piece is drawn with (pure Python, no
Blender: kit.py turns them into meshes, test_kit_shapes.py checks them).

A piece's "shapes" (kit_recipes) is a list of these, in the piece's own
frame (Godot's axes, as the boxes: x along it, y up, z through it):

    box      as kit v0's boxes (a centre, a size, a slot, yaw/pitch/roll)
    prism    an n-sided upright prism about a centre (a column's shaft, a
             barrel, a post, a candle): radius, height, sides, a narrower or
             wider top, bulging rings; tipped by yaw/pitch/roll
    arched   a wall with an opening whose head is round, pointed or flat,
             its reveals (jambs, soffit, sill) drawn; without its piers it is
             the band over an arch between two columns
    card     a flat rectangle drawn both ways (foliage, a photographed front),
             its photo across it (UVs 0..1)

build(shapes) makes them one mesh part: {"verts": [[x, y, z], ...],
"faces": [(indices, slot, uvs), ...]}, each face wound outward
(counter-clockwise from outside), its uvs one per corner (metres on the
face's own plane, or 0..1 across a card).

A piece's colliders stay its v0 boxes: modelling moves nothing men walk on.
"""

import math

import geo

# A modelled piece is at most this many triangles (the PS2 budget: a sector
# of the garrison holds a few hundred pieces).
PIECE_TRIS = 800
# How finely curves are drawn.
ARCH_SEGMENTS = 8


# ---------------------------------------------------------------------------
# The shapes, as data
# ---------------------------------------------------------------------------

def box(cx, cy, cz, sx, sy, sz, slot, yaw=0.0, pitch=0.0, roll=0.0):
    return {"kind": "box", "centre": [cx, cy, cz], "size": [sx, sy, sz], "slot": slot, "turn": [yaw, pitch, roll]}


def prism(cx, cy, cz, radius, height, sides, slot, yaw=0.0, pitch=0.0, roll=0.0, top=None, rings=None, caps=True):
    """An upright prism `height` tall centred on (cx, cy, cz), `radius` to
    its corners; `top` its radius at the top (a taper); `rings` [[height
    fraction, radius], ...] in between (a barrel's bulge)."""
    return {"kind": "prism", "centre": [cx, cy, cz], "radius": radius, "height": height, "sides": int(sides), "slot": slot,
            "turn": [yaw, pitch, roll], "top": radius if top is None else top, "rings": rings or [], "caps": caps}


def arched_wall(width, height, depth, opening, spring, rise, sill, slot, pointed=False, piers=True, x=0.0):
    """A wall `width` x `height` x `depth` (its foot at y 0, centred on x)
    with an opening `opening` wide from `sill` up to `spring`, its head a
    round arch `rise` high (pointed: a gothic one; 0: flat). Without piers,
    only the band over the opening (between two columns)."""
    return [{"kind": "arched", "width": width, "height": height, "depth": depth, "opening": opening, "spring": spring,
             "rise": rise, "sill": sill, "slot": slot, "pointed": pointed, "piers": piers, "x": x}]


def card(cx, cy, cz, width, height, slot, yaw=0.0, pitch=0.0):
    """A rectangle `width` x `height` facing +z (turned by yaw), drawn from
    both sides, its photo across it."""
    return {"kind": "card", "centre": [cx, cy, cz], "size": [width, height], "slot": slot, "turn": [yaw, pitch, 0.0]}


# ---------------------------------------------------------------------------
# Building
# ---------------------------------------------------------------------------

def build(shapes):
    part = {"verts": [], "faces": []}

    for shape in shapes:
        {"box": _box, "prism": _prism, "arched": _arched, "card": _card}[shape["kind"]](part, shape)

    return part


def _add_face(part, points, slot, uvs=None):
    """A face through `points` (outward, counter-clockwise from outside)."""
    base = len(part["verts"])
    part["verts"].extend([list(p) for p in points])
    part["faces"].append((tuple(range(base, base + len(points))), slot, uvs if uvs is not None else _planar_uvs(points)))


def _planar_uvs(points):
    """Metres across the face's own plane (its biggest axis dropped)."""
    normal = _normal(points)
    axis = max(range(3), key=lambda i: abs(normal[i]))
    keep = [i for i in range(3) if i != axis]
    return [[p[keep[0]], p[keep[1]]] for p in points]


def _normal(points):
    n = [0.0, 0.0, 0.0]

    for i in range(len(points)):
        a, b = points[i], points[(i + 1) % len(points)]
        n[0] += (a[1] - b[1]) * (a[2] + b[2])
        n[1] += (a[2] - b[2]) * (a[0] + b[0])
        n[2] += (a[0] - b[0]) * (a[1] + b[1])

    return n


def _placed(shape, local):
    turn = shape.get("turn", [0.0, 0.0, 0.0])
    return geo.add(shape["centre"], geo.apply(geo.rotation(turn[0], turn[1], turn[2]), local))


def _box(part, shape):
    hx, hy, hz = [s / 2.0 for s in shape["size"]]
    c = [_placed(shape, [hx * (1 if i & 1 else -1), hy * (1 if i & 2 else -1), hz * (1 if i & 4 else -1)]) for i in range(8)]

    for face in ((0, 4, 6, 2), (1, 3, 7, 5), (0, 1, 5, 4), (2, 6, 7, 3), (0, 2, 3, 1), (4, 5, 7, 6)):
        _add_face(part, [c[i] for i in face], shape["slot"])


def _prism(part, shape):
    n = shape["sides"]
    h = shape["height"]
    levels = [[0.0, shape["radius"]]] + sorted(shape["rings"]) + [[1.0, shape["top"]]]
    rings = []

    for fraction, radius in levels:
        y = -h / 2.0 + fraction * h
        rings.append([_placed(shape, [radius * math.cos(2 * math.pi * k / n), y, radius * math.sin(2 * math.pi * k / n)]) for k in range(n)])

    for a, b in zip(rings, rings[1:]):
        for k in range(n):
            j = (k + 1) % n
            _add_face(part, [a[k], a[j], b[j], b[k]][::-1], shape["slot"])

    if shape["caps"]:
        _add_face(part, rings[0], shape["slot"])
        _add_face(part, rings[-1][::-1], shape["slot"])


def _head(shape):
    """The opening's head from its left jamb to its right, [x, y] points
    (x rising), in the wall's frame."""
    half = shape["opening"] / 2.0
    spring, rise = shape["spring"], shape["rise"]
    segments = ARCH_SEGMENTS

    if rise <= 0.0:
        return [[-half, spring], [half, spring]]

    if not shape["pointed"]:
        return [[-half * math.cos(math.pi * i / segments), spring + rise * math.sin(math.pi * i / segments)] for i in range(segments + 1)]

    # A gothic head: each side an arc of a circle centred on the far side of
    # the springing line, meeting at the apex (spring + rise).
    k = ((rise / half) ** 2 - 1.0) / 2.0
    centre = half * k
    radius = half * (1.0 + k)
    start = math.pi
    end = math.acos(-centre / radius)
    left = []

    for i in range(segments // 2 + 1):
        angle = start + (end - start) * i / (segments // 2)
        left.append([centre + radius * math.cos(angle), spring + radius * math.sin(angle)])

    left[-1] = [0.0, spring + rise]
    right = [[-x, y] for x, y in reversed(left[:-1])]
    return left + right


def _arched(part, shape):
    w, height, d = shape["width"] / 2.0, shape["height"], shape["depth"] / 2.0
    half, sill, spring = shape["opening"] / 2.0, shape["sill"], shape["spring"]
    ox = shape["x"]
    slot = shape["slot"]
    head = _head(shape)

    def front(x, y):
        return [ox + x, y, d]

    def back(x, y):
        return [ox + x, y, -d]

    def both(quad):
        """A face on the front (its points as given, x/y) and its mirror at the back."""
        _add_face(part, [front(x, y) for x, y in quad], slot)
        _add_face(part, [back(x, y) for x, y in reversed(quad)], slot)

    low = 0.0 if shape["piers"] else spring

    if shape["piers"]:
        # The piers either side, and under a sill the wall beneath it.
        both([[-w, 0.0], [-half, 0.0], [-half, height], [-w, height]])
        both([[half, 0.0], [w, 0.0], [w, height], [half, height]])

        if sill > 0.0:
            both([[-half, 0.0], [half, 0.0], [half, sill], [-half, sill]])

    # Over the head up to the top, a strip at a time.
    for (x0, y0), (x1, y1) in zip(head, head[1:]):
        both([[x0, y0], [x1, y1], [x1, height], [x0, height]])

    if not shape["piers"]:
        # Between the head's ends and the band's ends (over the columns).
        both([[-w, low], [-half, low], [-half, height], [-w, height]])
        both([[half, low], [w, low], [w, height], [half, height]])

    # The reveals: jambs, the soffit round the head, the sill.
    if spring > sill:
        _add_face(part, [front(-half, sill), back(-half, sill), back(-half, spring), front(-half, spring)], slot)
        _add_face(part, [back(half, sill), front(half, sill), front(half, spring), back(half, spring)], slot)

    for (x0, y0), (x1, y1) in zip(head, head[1:]):
        _add_face(part, [front(x0, y0), front(x1, y1), back(x1, y1), back(x0, y0)], slot)

    if sill > 0.0:
        _add_face(part, [front(-half, sill), front(half, sill), back(half, sill), back(-half, sill)], slot)

    # The wall's ends and its top (its foot stands on the floor).
    _add_face(part, [front(-w, low), front(-w, height), back(-w, height), back(-w, low)], slot)
    _add_face(part, [back(w, low), back(w, height), front(w, height), front(w, low)], slot)
    _add_face(part, [front(-w, height), front(w, height), back(w, height), back(-w, height)], slot)

    if not shape["piers"]:
        # Under the band's ends (on the columns).
        _add_face(part, [front(-w, low), back(-w, low), back(-half, low), front(-half, low)], slot)
        _add_face(part, [front(half, low), back(half, low), back(w, low), front(w, low)], slot)


def _card(part, shape):
    hw, hh = shape["size"][0] / 2.0, shape["size"][1] / 2.0
    corners = [_placed(shape, [x, y, 0.0]) for x, y in ((-hw, -hh), (hw, -hh), (hw, hh), (-hw, hh))]
    uvs = [[0.0, 1.0], [1.0, 1.0], [1.0, 0.0], [0.0, 0.0]]
    _add_face(part, corners, shape["slot"], uvs)
    _add_face(part, corners[::-1], shape["slot"], uvs[::-1])
