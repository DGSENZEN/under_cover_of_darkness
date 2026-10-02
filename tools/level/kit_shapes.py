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
    gable    a triangular end under a pitched roof
    card     a flat rectangle drawn both ways (foliage, a photographed front),
             its photo across it (UVs 0..1)
    lathe    a profile turned about an upright axis (a bowl, a tankard, a
             jug, a keg on its side, a spire), tipped by yaw/pitch/roll
    disc     a flat n-gon drawn both ways, its photo across it (a rose
             window's glass, a shield's face)
    slab     a board through four corners with a thickness under it, its
             photo laid along its first edge (a roof's slope, its rows along
             the eaves)

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


def arched_wall(width, height, depth, opening, spring, rise, sill, slot, pointed=False, piers=True, x=0.0, horseshoe=0.0, z=0.0, yaw=0.0,
                jambs=True, y=0.0):
    """A wall `width` x `height` x `depth` (its foot at y, centred on x,
    its middle at z, then turned `yaw` about the piece's upright) with an
    opening `opening` wide from `sill` up to `spring`, its head a round arch
    `rise` high (pointed: a gothic one; 0: flat). Without piers, only the
    band over the opening (between two columns); `jambs` False leaves the
    reveals under its springing to the piers the band stands on. `horseshoe`:
    the Moorish arch, its circle (`opening` across, centred at `spring`)
    running on that share of its radius below the springing, onto jambs
    narrower than the arch."""
    return [{"kind": "arched", "width": width, "height": height, "depth": depth, "opening": opening, "spring": spring,
             "rise": rise, "sill": sill, "slot": slot, "pointed": pointed, "piers": piers, "x": x, "horseshoe": horseshoe,
             "z": z, "yaw": yaw, "jambs": jambs, "y": y}]


def gable(cx, cy, cz, width, rise, depth, slot, yaw=0.0):
    """A triangle `width` across and `rise` high (its base at cy), `depth`
    thick: a gable end under a pitched roof."""
    return {"kind": "gable", "centre": [cx, cy, cz], "width": width, "rise": rise, "depth": depth, "slot": slot, "turn": [yaw, 0.0, 0.0]}


def card(cx, cy, cz, width, height, slot, yaw=0.0, pitch=0.0, round=None):
    """A rectangle `width` x `height` facing +z (turned by yaw), drawn from
    both sides, its photo across it. `round` (a point in the piece's frame):
    its normals point out from there on both faces, so cards gathered round
    it light as one mass (a tree's crown), not as flat boards."""
    shape = {"kind": "card", "centre": [cx, cy, cz], "size": [width, height], "slot": slot, "turn": [yaw, pitch, 0.0]}

    if round is not None:
        shape["round"] = [float(c) for c in round]

    return shape


def lathe(cx, cy, cz, profile, sides, slot, yaw=0.0, pitch=0.0, roll=0.0, caps=True, closed=False):
    """`profile` [[radius, height], ...] from the bottom up (heights from
    cy) turned `sides` round an upright axis through (cx, cz), then tipped
    by yaw/pitch/roll. `caps` closes an end whose radius is above 0;
    `closed` joins its last ring to its first (a ring's section)."""
    return {"kind": "lathe", "centre": [cx, cy, cz], "profile": [list(p) for p in profile], "sides": int(sides), "slot": slot,
            "turn": [yaw, pitch, roll], "caps": caps, "closed": closed}


def disc(cx, cy, cz, radius, sides, slot, yaw=0.0, pitch=0.0):
    """A flat `sides`-gon of `radius` facing +z (turned by yaw/pitch),
    drawn both ways, its photo across it."""
    return {"kind": "disc", "centre": [cx, cy, cz], "radius": radius, "sides": int(sides), "slot": slot, "turn": [yaw, pitch, 0.0]}


def slab(corners, thickness, slot, under=None, edge=None, tile=1.0, up=(0.0, 1.0, 0.0)):
    """A board whose top runs through `corners` (four, in the piece's
    frame), `thickness` beneath it: its top in `slot`, facing the `up` side,
    its photo laid along it (u along corner 0 to 1, v along 0 to 3, one photo
    every `tile` m, or [along, down]); its underside in `under`, its edges in `edge` (both
    `slot` if not given)."""
    return {"kind": "slab", "corners": [list(c) for c in corners], "thickness": thickness, "slot": slot,
            "under": under or slot, "edge": edge or slot, "tile": tile, "up": list(up)}


def ring(cx, cy, cz, inner, outer, depth, start, end, segments, slot, yaw=0.0):
    """An arc of a ring in the plane facing +z (turned by yaw), centred on
    (cx, cy, cz): from `inner` to `outer` out, `depth` thick, from `start`
    to `end` degrees (0 to the right, 90 up) in `segments` (an arch's hood,
    a rose window's frame, a shield's rim)."""
    return {"kind": "ring", "centre": [cx, cy, cz], "inner": inner, "outer": outer, "depth": depth, "start": start, "end": end,
            "segments": int(segments), "slot": slot, "turn": [yaw, 0.0, 0.0]}


def polygon(points, slot, uvs=None):
    """One face through `points` (in the piece's frame), drawn from the side
    they wind counter-clockwise toward only: a vault's web, a hull's panel.
    `uvs` one per point (metres on its own plane if not given)."""
    shape = {"kind": "polygon", "points": [list(p) for p in points], "slot": slot}

    if uvs is not None:
        shape["uvs"] = [list(uv) for uv in uvs]

    return shape


def moved(shapes, yaw=0.0, offset=(0.0, 0.0, 0.0)):
    """Copies of `shapes` turned `yaw` degrees about the piece's upright
    axis, then moved by `offset` (a roof laid along z instead of x)."""
    turn = geo.rotation(yaw)
    out = []

    for shape in shapes:
        shape = dict(shape)

        if shape["kind"] == "arched":
            raise ValueError("an arched wall is placed by its piece, not moved")

        if shape["kind"] == "slab":
            shape["corners"] = [geo.add(geo.apply(turn, c), offset) for c in shape["corners"]]
            shape["up"] = geo.apply(turn, shape["up"])
        elif shape["kind"] == "polygon":
            shape["points"] = [geo.add(geo.apply(turn, p), offset) for p in shape["points"]]
        else:
            shape["centre"] = geo.add(geo.apply(turn, shape["centre"]), offset)
            shape["turn"] = [shape["turn"][0] + yaw, shape["turn"][1], shape["turn"][2]]

            if "round" in shape:
                shape["round"] = geo.add(geo.apply(turn, shape["round"]), offset)

        out.append(shape)

    return out


# ---------------------------------------------------------------------------
# Building
# ---------------------------------------------------------------------------

def build(shapes):
    """The shapes' corners and faces: {verts, faces: [(indices, slot, uvs)],
    normals: {face index: [a normal per corner]} for the faces that carry
    their own (rounded cards), the rest flat}."""
    part = {"verts": [], "faces": [], "normals": {}}
    makers = {"box": _box, "prism": _prism, "arched": _arched, "gable": _gable, "card": _card, "lathe": _lathe, "disc": _disc,
              "slab": _slab, "ring": _ring, "polygon": lambda part, shape: _add_face(part, shape["points"], shape["slot"], shape.get("uvs"))}

    for shape in shapes:
        makers[shape["kind"]](part, shape)

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

    if shape.get("horseshoe", 0.0) > 0.0:
        # From the left jamb's top round over the apex to the right's: the
        # circle through them all, past a half turn by `beyond` either side.
        beyond = math.asin(shape["horseshoe"])
        steps = segments + 4
        return [[half * math.cos(math.pi + beyond - (math.pi + 2.0 * beyond) * i / steps),
                 spring + half * math.sin(math.pi + beyond - (math.pi + 2.0 * beyond) * i / steps)] for i in range(steps + 1)]

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


def _turned(shape, p):
    """An arched wall's point moved to its y and z and turned by its yaw."""
    q = [p[0], p[1] + shape.get("y", 0.0), p[2] + shape.get("z", 0.0)]
    return geo.apply(geo.rotation(shape["yaw"]), q) if shape.get("yaw", 0.0) else q


def _horseshoe(part, shape):
    """A wall with a horseshoe arch through it: its piers to the jambs'
    tops, the wall over and round the arch in a fan from its circle out to
    its sides and top (the circle bulges wider than the jambs, so the
    round arch's strips cannot be used), the reveals, its ends and top."""
    w, height, d = shape["width"] / 2.0, shape["height"], shape["depth"] / 2.0
    ox, slot, sill, spring = shape["x"], shape["slot"], shape["sill"], shape["spring"]
    head = _head(shape)
    jamb, foot = abs(head[0][0]), head[0][1]

    def front(x, y):
        return _turned(shape, [ox + x, y, d])

    def back(x, y):
        return _turned(shape, [ox + x, y, -d])

    def both(points):
        _add_face(part, [front(x, y) for x, y in points], slot)
        _add_face(part, [back(x, y) for x, y in reversed(points)], slot)

    def rim(x, y):
        """Where the ray from the circle's middle through (x, y) meets the
        wall's sides or top (no lower than the jambs' tops)."""
        dx, dy = x, y - spring
        hits = []

        if abs(dx) > 1e-9:
            t = (w if dx > 0 else -w) / dx
            hits.append((t, [w if dx > 0 else -w, max(foot, spring + dy * t)]))

        if dy > 1e-9:
            t = (height - spring) / dy
            hits.append((t, [dx * t, height]))

        return min(hits, key=lambda h: h[0])[1]

    both([[-w, 0.0], [-jamb, 0.0], [-jamb, foot], [-w, foot]])
    both([[jamb, 0.0], [w, 0.0], [w, foot], [jamb, foot]])

    if sill > 0.0:
        both([[-jamb, 0.0], [jamb, 0.0], [jamb, sill], [-jamb, sill]])

    def along(p):
        """How far round the wall's edge p is: up its left side, across its
        top, down its right."""
        if p[0] <= -w + 1e-9:
            return p[1] - foot

        if p[1] >= height - 1e-9:
            return (height - foot) + (p[0] + w)

        return (height - foot) + 2.0 * w + (height - p[1])

    corners = [(height - foot, [-w, height]), (height - foot + 2.0 * w, [w, height])]

    # The head runs clockwise over the arch (seen from the front); each fan
    # face goes along it, out to the edge, back along the edge (round any
    # corner it passes) and in again: counter-clockwise.
    for (x0, y0), (x1, y1) in zip(head, head[1:]):
        a, b = rim(x0, y0), rim(x1, y1)
        passed = [c for s, c in sorted(corners, reverse=True) if along(a) + 1e-9 < s < along(b) - 1e-9]
        both([[x0, y0], [x1, y1], b] + passed + [a])

    if foot > sill:
        _add_face(part, [front(-jamb, sill), back(-jamb, sill), back(-jamb, foot), front(-jamb, foot)], slot)
        _add_face(part, [back(jamb, sill), front(jamb, sill), front(jamb, foot), back(jamb, foot)], slot)

    for (x0, y0), (x1, y1) in zip(head, head[1:]):
        _add_face(part, [front(x0, y0), front(x1, y1), back(x1, y1), back(x0, y0)], slot)

    if sill > 0.0:
        _add_face(part, [front(-jamb, sill), front(jamb, sill), back(jamb, sill), back(-jamb, sill)], slot)

    _add_face(part, [front(-w, 0.0), front(-w, height), back(-w, height), back(-w, 0.0)], slot)
    _add_face(part, [back(w, 0.0), back(w, height), front(w, height), front(w, 0.0)], slot)
    _add_face(part, [front(-w, height), front(w, height), back(w, height), back(-w, height)], slot)


def _arched(part, shape):
    if shape.get("horseshoe", 0.0) > 0.0:
        return _horseshoe(part, shape)

    w, height, d = shape["width"] / 2.0, shape["height"], shape["depth"] / 2.0
    half, sill, spring = shape["opening"] / 2.0, shape["sill"], shape["spring"]
    ox = shape["x"]
    slot = shape["slot"]
    head = _head(shape)

    def front(x, y):
        return _turned(shape, [ox + x, y, d])

    def back(x, y):
        return _turned(shape, [ox + x, y, -d])

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
    if spring > sill and shape.get("jambs", True):
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


def _gable(part, shape):
    hw, h, hd = shape["width"] / 2.0, shape["rise"], shape["depth"] / 2.0
    f = [_placed(shape, p) for p in ([-hw, 0.0, hd], [hw, 0.0, hd], [0.0, h, hd])]
    b = [_placed(shape, p) for p in ([-hw, 0.0, -hd], [hw, 0.0, -hd], [0.0, h, -hd])]
    slot = shape["slot"]
    _add_face(part, f, slot)
    _add_face(part, [b[2], b[1], b[0]], slot)
    _add_face(part, [f[1], b[1], b[2], f[2]], slot)
    _add_face(part, [b[0], f[0], f[2], b[2]], slot)
    _add_face(part, [f[0], b[0], b[1], f[1]], slot)


def _card(part, shape):
    hw, hh = shape["size"][0] / 2.0, shape["size"][1] / 2.0
    corners = [_placed(shape, [x, y, 0.0]) for x, y in ((-hw, -hh), (hw, -hh), (hw, hh), (-hw, hh))]
    uvs = [[0.0, 1.0], [1.0, 1.0], [1.0, 0.0], [0.0, 0.0]]
    _add_face(part, corners, shape["slot"], uvs)
    _add_face(part, corners[::-1], shape["slot"], uvs[::-1])

    if "round" in shape:
        out = []

        for c in corners:
            d = [c[i] - shape["round"][i] for i in range(3)]
            length = max(sum(x * x for x in d) ** 0.5, 1e-6)
            out.append([x / length for x in d])

        part["normals"][len(part["faces"]) - 2] = out
        part["normals"][len(part["faces"]) - 1] = out[::-1]


def _lathe(part, shape):
    n = shape["sides"]
    rings = []

    for radius, height in shape["profile"]:
        rings.append([_placed(shape, [radius * math.cos(2 * math.pi * k / n), height, radius * math.sin(2 * math.pi * k / n)]) for k in range(n)])

    pairs = list(zip(rings, rings[1:]))

    if shape["closed"]:
        pairs.append((rings[-1], rings[0]))

    for a, b in pairs:
        for k in range(n):
            j = (k + 1) % n
            _add_face(part, [a[k], a[j], b[j], b[k]][::-1], shape["slot"])

    if shape["caps"] and not shape["closed"]:
        if shape["profile"][0][0] > 1e-6:
            _add_face(part, rings[0], shape["slot"])

        if shape["profile"][-1][0] > 1e-6 and len(shape["profile"]) > 1 and shape["profile"][-1][1] > shape["profile"][0][1] + 1e-6 \
                and _closes_top(shape["profile"]):
            _add_face(part, rings[-1][::-1], shape["slot"])


def _closes_top(profile):
    """A lathe's top is closed unless its profile rises to an open mouth (its
    last point further out than the one before it: a bowl, a tankard)."""
    if len(profile) < 2:
        return True

    return profile[-1][0] <= profile[-2][0] + 1e-6


def _disc(part, shape):
    n, r = shape["sides"], shape["radius"]
    local = [[r * math.cos(2 * math.pi * k / n + math.pi / 2), r * math.sin(2 * math.pi * k / n + math.pi / 2)] for k in range(n)]
    points = [_placed(shape, [x, y, 0.0]) for x, y in local]
    uvs = [[0.5 + x / (2 * r), 0.5 - y / (2 * r)] for x, y in local]
    # (Its photo across it: stretched so the n-gon's corners reach its edges.)
    us = [u for u, _ in uvs]
    vs = [v for _, v in uvs]
    uvs = [[(u - min(us)) / (max(us) - min(us)), (v - min(vs)) / (max(vs) - min(vs))] for u, v in uvs]
    _add_face(part, points, shape["slot"], uvs)
    _add_face(part, points[::-1], shape["slot"], uvs[::-1])


def _slab(part, shape):
    top = [list(c) for c in shape["corners"]]
    a, b, d = top[0], top[1], top[3]
    across = geo.sub(b, a)
    down = geo.sub(d, a)
    across = [c / math.sqrt(geo.dot(across, across)) for c in across]
    down = [c / math.sqrt(geo.dot(down, down)) for c in down]
    tile = shape["tile"] if isinstance(shape["tile"], (list, tuple)) else (shape["tile"], shape["tile"])
    uvs = [[geo.dot(geo.sub(p, a), across) / tile[0], geo.dot(geo.sub(p, a), down) / tile[1]] for p in top]
    normal = _normal(top)

    if geo.dot(normal, shape["up"]) < 0.0:
        top, uvs = top[::-1], uvs[::-1]
        normal = [-c for c in normal]

    length = math.sqrt(geo.dot(normal, normal))
    offset = [-c / length * shape["thickness"] for c in normal]
    bottom = [geo.add(p, offset) for p in top]
    _add_face(part, top, shape["slot"], uvs)
    _add_face(part, bottom[::-1], shape["under"])

    for i in range(4):
        j = (i + 1) % 4
        _add_face(part, [top[j], top[i], bottom[i], bottom[j]], shape["edge"])


def _ring(part, shape):
    n, d = shape["segments"], shape["depth"] / 2.0
    whole = abs((shape["end"] - shape["start"]) % 360.0) < 1e-6
    angles = [math.radians(shape["start"] + (shape["end"] - shape["start"]) * i / n) for i in range(n + 1)]

    def at(radius, angle, z):
        return _placed(shape, [radius * math.cos(angle), radius * math.sin(angle), z])

    for a0, a1 in zip(angles, angles[1:]):
        ri, ro = shape["inner"], shape["outer"]
        _add_face(part, [at(ri, a0, d), at(ro, a0, d), at(ro, a1, d), at(ri, a1, d)], shape["slot"])
        _add_face(part, [at(ri, a1, -d), at(ro, a1, -d), at(ro, a0, -d), at(ri, a0, -d)], shape["slot"])
        _add_face(part, [at(ro, a0, d), at(ro, a0, -d), at(ro, a1, -d), at(ro, a1, d)], shape["slot"])
        _add_face(part, [at(ri, a1, d), at(ri, a1, -d), at(ri, a0, -d), at(ri, a0, d)], shape["slot"])

    if not whole:
        for angle, flip in ((angles[0], False), (angles[-1], True)):
            quad = [at(shape["inner"], angle, d), at(shape["inner"], angle, -d), at(shape["outer"], angle, -d), at(shape["outer"], angle, d)]
            _add_face(part, quad[::-1] if flip else quad, shape["slot"])
