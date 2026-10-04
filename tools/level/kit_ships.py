"""The harbour's ships (kit v1): a carrack (its hull with the castles fore
and aft and the captain's cabin, its rig with a fighting top to climb up
to, its main yard apart so the level can brace it), a lateen caravel, a
fishing boat and a rowboat. Pure data, as kit_recipes (which imports this at
its end).

After a nau of c.1500-1550 (the Mary Rose, the Pepper Wreck, the Matarò
model; docs/superpowers/refs/ships_harbour.md): a round, full hull widest
at the waterline and falling in above it, a strong sheer, wales broken by
beam ends and skids, a forecastle overhanging the stem, an aftcastle
stepped up aft over a plain transom; nothing drawn as a single sheet where
it shows an edge (bulwarks, rails, decks have their thickness).

A ship's pivot is at the waterline under its mainmast, its bow to +x. The
carrack's hull is lofted from stations along x (each a section from the
keel up its side, the stem raking forward, the sternpost aft); open boats
are drawn inside too. Shrouds are separate lines with our painted ratlines
between them; the player climbs straight up, so each set of shrouds has an
upright climb (`climbs`: boxes [x, y, z, sx, sy, sz, yaw], their -z into
what they lean on) inside their lean, from the deck to a mantle under the
top.

Ratlines are strips of our ratlines painting (textures/painted/ratlines.png)
laid between each pair of shrouds by their own UVs (kit_shapes.polygon's
`uvs`), only the painting's ratlines on them, repeating up the shrouds.
"""

import math

import kit_recipes as k
import kit_shapes as ks

MAIN_DECK = 2.0
BULWARK = 1.0
CASTLE_DECK = 5.0
POOP_DECK = 8.0
FORE_DECK = 6.5
TOP = 20.0
TOP_RADIUS = 1.6
DOOR = (1.2, 2.2)
YARD = 26.0
# The main yard hangs this far forward of the mainmast (the layout puts it
# there): the shrouds' climb goes up aft of it, clear of it.
MAIN_YARD_X = 1.05
# A rope ladder over the starboard waist into the sea (its rungs' middle
# along x, their spacing, how deep it reaches): the way aboard from the
# water. Its line (y, out from the middle line) as it hangs: off the rail's
# cap (its top 3.06), over the upper wale, clear of a chain plate's beam and
# the middle wale to the lower wale, then plumb into the water (measured off
# the hull's faces; test_ships keeps each rope and rung clear of them).
JACOB = (3.15, 0.36, -0.9)
JACOB_DRAPE = [(3.09, 4.30), (2.55, 4.445), (0.8, 4.595), (-0.9, 4.595)]


def col(cx, cy, cz, sx, sy, sz, yaw=0.0, pitch=0.0, roll=0.0):
    return [cx, cy, cz, sx, sy, sz, "wood", yaw, pitch, roll]


def _ship(name, slot, shapes, cols, size, budget, climbs=None):
    k.piece(name, "ship", slot, "wood", [], cols=cols, size=size)
    k.model(name, [s for s in shapes if s is not None])
    k.PIECES[name]["budget"] = budget
    k.PIECES[name]["climbs"] = climbs or []


# ---------------------------------------------------------------------------
# Drawing: faces, lofts, tubes and ropes, sweeps along a rail
# ---------------------------------------------------------------------------

def _add(a, b):
    return [a[0] + b[0], a[1] + b[1], a[2] + b[2]]


def _sub(a, b):
    return [a[0] - b[0], a[1] - b[1], a[2] - b[2]]


def _mul(a, s):
    return [a[0] * s, a[1] * s, a[2] * s]


def _dot(a, b):
    return a[0] * b[0] + a[1] * b[1] + a[2] * b[2]


def _cross(a, b):
    return [a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0]]


def _unit(a):
    length = math.sqrt(_dot(a, a))
    return [c / length for c in a] if length > 1e-9 else [0.0, 0.0, 0.0]


def _lerp(a, b, t):
    return [a[i] + (b[i] - a[i]) * t for i in range(3)]


def _mid(points):
    return [sum(p[i] for p in points) / len(points) for i in range(3)]


def _smooth(t):
    t = min(1.0, max(0.0, t))
    return t * t * (3.0 - 2.0 * t)


def _area(points):
    """Its normal, as long as twice its area (counter-clockwise: toward the
    viewer)."""
    n = [0.0, 0.0, 0.0]

    for i in range(len(points)):
        a, b = points[i], points[(i + 1) % len(points)]
        n[0] += (a[1] - b[1]) * (a[2] + b[2])
        n[1] += (a[2] - b[2]) * (a[0] + b[0])
        n[2] += (a[0] - b[0]) * (a[1] + b[1])

    return n


def _face(points, slot, out=None, uvs=None):
    """A face through `points` (repeats dropped; nothing where it has no
    area), turned to look along `out`; `uvs` one per point (a cut-out
    painting laid on it)."""
    kept, kept_uvs = [], []

    for i, p in enumerate(points):
        if not kept or max(abs(p[c] - kept[-1][c]) for c in range(3)) > 1e-6:
            kept.append([float(c) for c in p])
            kept_uvs.append(uvs[i] if uvs else None)

    if len(kept) > 2 and max(abs(kept[0][c] - kept[-1][c]) for c in range(3)) < 1e-6:
        kept.pop()
        kept_uvs.pop()

    if len(kept) < 3:
        return None

    n = _area(kept)

    if _dot(n, n) < 1e-10:
        return None

    if out is not None and _dot(n, out) < 0.0:
        kept.reverse()
        kept_uvs.reverse()

    shape = ks.polygon(kept, slot)

    if uvs:
        shape["uvs"] = [list(uv) for uv in kept_uvs]

    return shape


def _both(points, slot):
    """A face drawn both ways (cloth, a flag)."""
    n = _area(points)
    return [_face(points, slot, n), _face(points, slot, _mul(n, -1.0))]


def _loft(rows, slot, out):
    """Faces between each row of points and the next (rows as long): `slot`
    a slot or a function of a face's corners, `out` a function of them (the
    way it looks)."""
    shapes = []

    for r0, r1 in zip(rows, rows[1:]):
        for i in range(len(r0) - 1):
            quad = [r0[i], r0[i + 1], r1[i + 1], r1[i]]
            shapes.append(_face(quad, slot(quad) if callable(slot) else slot, out(quad)))

    return shapes


def _rings(rings, axis, slot, caps=True, closed=True):
    """Faces round consecutive rings of points (a section each, `closed` or
    open: a wale's against the hull) about `axis` (a point per ring),
    looking out from it; their ends capped."""
    shapes = []

    for i in range(len(rings) - 1):
        middle = _lerp(axis[i], axis[i + 1], 0.5)
        n = len(rings[i])

        for k in range(n if closed else n - 1):
            j = (k + 1) % n
            quad = [rings[i][k], rings[i][j], rings[i + 1][j], rings[i + 1][k]]
            shapes.append(_face(quad, slot, _sub(_mid(quad), middle)))

    if caps:
        shapes.append(_face(rings[0], slot, _sub(axis[0], axis[1])))
        shapes.append(_face(rings[-1], slot, _sub(axis[-1], axis[-2])))

    return shapes


def _frame(path):
    """Two directions square to the path's run, the second as near up (or
    along x when it runs upright) as can be."""
    run = _unit(_sub(path[-1], path[0]))
    ref = [0.0, 1.0, 0.0] if abs(run[1]) < 0.9 else [1.0, 0.0, 0.0]
    across = _unit(_cross(run, ref))
    return across, _cross(across, run)


def _tube(path, radius, slot, sides=6, caps=True, squash=1.0, turn=0.0):
    """A round tube along `path`, `radius` one for all or one per point (a
    mast's taper, a furled sail's lumps), `squash` its section's height to
    its width."""
    radii = list(radius) if isinstance(radius, (list, tuple)) else [radius] * len(path)
    rings = []

    for i, p in enumerate(path):
        a, b = path[max(0, i - 1)], path[min(len(path) - 1, i + 1)]
        run = _unit(_sub(b, a))
        ref = _frame(path)[1]
        across = _unit(_cross(run, ref))
        up = _cross(across, run)
        ring = []

        for s in range(sides):
            angle = 2.0 * math.pi * s / sides + math.radians(turn)
            ring.append(_add(p, _add(_mul(across, radii[i] * math.cos(angle)), _mul(up, radii[i] * squash * math.sin(angle)))))

        rings.append(ring)

    return _rings(rings, path, slot, caps)


def _rope(a, b, radius=0.03, slot="pitch", sides=3, sag=0.0, steps=1):
    """A rope from a to b, sagging `sag` at its middle."""
    path = [_add(_lerp(a, b, i / steps), [0.0, -4.0 * sag * (i / steps) * (1.0 - i / steps), 0.0]) for i in range(steps + 1)]
    return _tube(path, radius, slot, sides, caps=False)


def _sweep(path, profile, slot, flip=1.0, caps=True, closed=True):
    """A moulding along `path`: its section `profile` [(out, up)] at each
    point, `out` level and square to the path (toward +z for a path running
    +x; `flip` -1 the other way); not `closed`, its section's ends lie on
    what it stands on."""
    rings = []

    for i, p in enumerate(path):
        a, b = path[max(0, i - 1)], path[min(len(path) - 1, i + 1)]
        run = _unit([b[0] - a[0], 0.0, b[2] - a[2]])
        out = _mul(_unit(_cross(run, [0.0, 1.0, 0.0])), flip)
        rings.append([_add(p, _add(_mul(out, o), [0.0, u, 0.0])) for o, u in profile])

    return _rings(rings, path, slot, caps, closed)


def _card(cx, cy, cz, width, height, slot, yaw=0.0, pitch=0.0, roll=0.0):
    """A card (kit_shapes') also turned in its own plane."""
    shape = ks.card(cx, cy, cz, width, height, slot, yaw, pitch)
    shape["turn"][2] = roll
    return shape


def _post(x, y0, y1, z, size, slot, yaw=0.0):
    """A square post from y0 to y1 (its ends hidden: on a deck, under a
    rail)."""
    return ks.prism(x, (y0 + y1) / 2.0, z, size / math.sqrt(2.0), y1 - y0, 4, slot, yaw=yaw + 45.0, caps=False)


def _stud(x, y0, y1, z, size, slot, out):
    """A square post against a wall, its three faces that show (`out` the
    way it looks off the wall)."""
    h = size / 2.0
    run = _unit([-out[2], 0.0, out[0]])
    o = _unit([out[0], 0.0, out[2]])
    back = [x, 0.0, z]
    corners = [_add(back, _add(_mul(run, -h), _mul(o, -h))), _add(back, _add(_mul(run, -h), _mul(o, h))),
               _add(back, _add(_mul(run, h), _mul(o, h))), _add(back, _add(_mul(run, h), _mul(o, -h)))]
    shapes = []

    for a, b in zip(corners, corners[1:]):
        quad = [[a[0], y0, a[2]], [b[0], y0, b[2]], [b[0], y1, b[2]], [a[0], y1, a[2]]]
        shapes.append(_face(quad, slot, _sub(_mid(quad), [x, (y0 + y1) / 2.0, z])))

    return shapes


def _block(x, y, z, sx, sy, sz, slot, out, yaw=0.0):
    """A box against a wall, its face to the wall left out (a beam's end,
    a gunport's lid): `out` +1 or -1, the way it looks along z."""
    turn = math.radians(yaw)
    ax, az = [math.cos(turn), 0.0, -math.sin(turn)], [math.sin(turn), 0.0, math.cos(turn)]
    shapes = []

    def at(i, j, k):
        return _add([x, y, z], _add(_mul(ax, i * sx / 2.0), _add([0.0, j * sy / 2.0, 0.0], _mul(az, k * sz / 2.0))))

    for n, quad in (([0.0, 0.0, out], [at(-1, -1, out), at(1, -1, out), at(1, 1, out), at(-1, 1, out)]),
                    ([0.0, 1.0, 0.0], [at(-1, 1, -1), at(1, 1, -1), at(1, 1, 1), at(-1, 1, 1)]),
                    ([0.0, -1.0, 0.0], [at(-1, -1, -1), at(1, -1, -1), at(1, -1, 1), at(-1, -1, 1)]),
                    ([1.0, 0.0, 0.0], [at(1, -1, -1), at(1, 1, -1), at(1, 1, 1), at(1, -1, 1)]),
                    ([-1.0, 0.0, 0.0], [at(-1, -1, -1), at(-1, 1, -1), at(-1, 1, 1), at(-1, -1, 1)])):
        shapes.append(_face(quad, slot, _sub(_mid(quad), [x, y, z])))

    return shapes


def _ladder(x, y0, y1, z, yaw):
    """A ladder's rails and rungs (every 0.3 m) from y0 to y1, turned by yaw."""
    out = [ks.box(-0.25, (y0 + y1) / 2.0, 0.0, 0.07, y1 - y0, 0.09, "timber"), ks.box(0.25, (y0 + y1) / 2.0, 0.0, 0.07, y1 - y0, 0.09, "timber")]

    for rung in range(int((y1 - y0) / 0.3)):
        out.append(ks.prism(0.0, y0 + 0.3 + rung * 0.3, 0.0, 0.03, 0.5, 3, "timber", roll=90.0, caps=False))

    return ks.moved(out, yaw, (x, 0.0, z))


def _arc(cx, cy, cz, inner, outer, height, a0, a1, segments, slot, flare=0.0):
    """A curved wall round (cx, cz) from angle a0 to a1 (degrees, from +x
    toward +z), standing `height` on cy, leaning out `flare` at its top."""
    def at(r, a, y):
        return [cx + r * math.cos(math.radians(a)), y, cz + r * math.sin(math.radians(a))]

    angles = [a0 + (a1 - a0) * i / segments for i in range(segments + 1)]
    outside = [[at(outer, a, cy), at(outer + flare, a, cy + height)] for a in angles]
    inside = [[at(inner, a, cy), at(inner + flare, a, cy + height)] for a in angles]
    shapes = []
    middle = [cx, cy + height / 2.0, cz]

    for i in range(segments):
        for quad in ([outside[i][0], outside[i + 1][0], outside[i + 1][1], outside[i][1]],):
            shapes.append(_face(quad, slot, _sub(_mid(quad), middle)))

        quad = [inside[i][0], inside[i + 1][0], inside[i + 1][1], inside[i][1]]
        shapes.append(_face(quad, slot, _sub(middle, _mid(quad))))
        shapes.append(_face([inside[i][1], inside[i + 1][1], outside[i + 1][1], outside[i][1]], slot, [0.0, 1.0, 0.0]))

    for i, sign in ((0, -1.0), (segments, 1.0)):
        tangent = [-math.sin(math.radians(angles[i])) * sign, 0.0, math.cos(math.radians(angles[i])) * sign]
        shapes.append(_face([inside[i][0], outside[i][0], outside[i][1], inside[i][1]], slot, tangent))

    return shapes


# ---------------------------------------------------------------------------
# The carrack's hull: 30 m on the waterline, 9 across, its castles stepped
# up fore and aft
# ---------------------------------------------------------------------------

STERN = -15.2
STEM = 15.0
KEEL = -3.5
TUCK = -0.9
YMAX = 0.8
POOP_FRONT = -11.0
CASTLE_FRONT = -6.0
FORE_BACK = 8.0
WAIST_RAIL = MAIN_DECK + BULWARK
CASTLE_SOLID = 5.45
CASTLE_RAIL = 6.1
POOP_SOLID = 8.45
POOP_RAIL = 9.1
FORE_SOLID = 4.3
FORE_TOP_SOLID = 6.95
FORE_RAIL = 7.6
NOSE = 18.2
SKIN = 0.22
# Heights the hull's stations are drawn through (the waterline's wet band
# from WET to DRY), clipped to each part's top.
WET, DRY = -0.35, 0.3
ROWS = [KEEL, -2.75, -1.5, TUCK, WET, DRY, YMAX, 1.35, 1.9, 2.45, WAIST_RAIL, FORE_SOLID, CASTLE_SOLID, 6.95, POOP_SOLID]
# Stations (x on the waterline) of each part of the hull, stern to stem:
# the poop, the aftcastle, the waist, the bow under the forecastle.
PARTS = [((STERN, -14.6, -13.7, -12.4, POOP_FRONT), POOP_SOLID),
         ((POOP_FRONT, -9.4, -7.7, CASTLE_FRONT), CASTLE_SOLID),
         ((CASTLE_FRONT, -4.2, -1.5, 1.0, 3.5, 5.8, FORE_BACK), WAIST_RAIL),
         ((FORE_BACK, 9.4, 10.6, 11.7, 12.6, 13.4, 14.0, 14.5, STEM), FORE_SOLID)]


def _waist_top(x):
    """The waist's rail: level over the middle of the deck (where a jump
    from the quay comes aboard), sweeping up to the castles."""
    return WAIST_RAIL + 0.35 * _smooth((abs(x - 1.0) - 2.5) / 4.5)


def _fore_top(x):
    """The top of the forecastle's planking, rising to its nose."""
    return FORE_TOP_SOLID + 0.9 * _smooth((x - 9.0) / (NOSE - 9.0))


def _poop_top(x):
    """The top of the poop's planking, rising to the stern."""
    return POOP_SOLID + 0.4 * _smooth((POOP_FRONT - x) / (POOP_FRONT - STERN))


def _top_at(top, xr):
    """A part's top at xr: the waist's and the poop's follow the sheer."""
    return _waist_top(xr) if top == WAIST_RAIL else _poop_top(xr) if top == POOP_SOLID else top


def _breadth(x):
    """The hull's greatest half-breadth along it (at YMAX): full amidships,
    a bluff bow, a broad stern."""
    if x >= 3.0:
        return 4.4 * math.sqrt(max(0.0, 1.0 - ((x - 3.0) / (STEM - 3.0)) ** 2))

    if x >= -4.0:
        return 4.4

    return 4.4 - 0.9 * min(1.0, (-4.0 - x) / (-4.0 - STERN)) ** 1.6


def _half(x, y):
    """The hull's half-breadth outside at station x (on the waterline),
    height y: round below its greatest breadth, falling in above it."""
    b = _breadth(x)

    if y >= YMAX:
        tumble = 0.55 * min(1.0, (y - YMAX) / 4.2) ** 1.5 + 0.11 * max(0.0, y - 5.0)
        return max(0.16, b - tumble * min(1.0, b / 3.2))

    t = min(1.0, (YMAX - y) / (YMAX - KEEL))
    n = 2.5 - 1.1 * _smooth((x - 5.0) / 10.0) - 0.8 * _smooth((-7.0 - x) / 8.2)
    run = 1.0 - 0.7 * _smooth((-9.0 - x) / 6.2) * t ** 1.3
    return max(0.16, b * (1.0 - t ** n) ** (1.0 / n) * run)


def _stem_x(y):
    """The stem at height y: raking forward over the water, the forefoot
    curving back under it to the keel."""
    if y >= 0.0:
        return STEM + 1.1 * (y / FORE_SOLID) ** 1.2

    return STEM - 2.6 * (-y / -KEEL) ** 1.7


def _x_at(xr, y):
    """Where the station drawn through xr on the waterline is at height y
    (the bow's follow the stem, the stern's the sternpost under the tuck)."""
    bow = _smooth((xr - 7.0) / (STEM - 7.0))
    stern = _smooth((POOP_FRONT - xr) / (POOP_FRONT - STERN))
    post = 0.8 * max(0.0, (TUCK - y) / (TUCK - KEEL))
    return xr + (_stem_x(y) - STEM) * bow + post * stern


def _hull_point(xr, y, side=1.0):
    """A point of the hull's skin (the sternpost under the tuck, the stem)."""
    if xr <= STERN and y < TUCK:
        z = 0.16
    else:
        z = _half(xr, y)

    return [_x_at(xr, y), y, side * z]


def _inside(xr, y, side=1.0):
    """The bulwark's or a castle's inside: SKIN in from the skin."""
    p = _hull_point(xr, y, side)
    return [p[0], y, side * (abs(p[2]) - SKIN)]


def _rise(x):
    """How much the wales sweep up toward the ends (the sheer)."""
    if x > 3.0:
        return ((x - 3.0) / (STEM - 3.0)) ** 2

    if x < -3.0:
        return ((-3.0 - x) / (-3.0 - STERN)) ** 2

    return 0.0


def _hull_slot(quad):
    y = _mid(quad)[1]
    return "limewash" if y < WET else "pitch" if y < DRY else "hull_tarred" if y < 2.45 else "hull_bare"


def _skin():
    """The hull's planking from the keel up each part, both sides, and the
    transom."""
    shapes = []

    for stations, top in PARTS:
        heights = [h for h in ROWS if h < top - 1e-6]

        for side in (1.0, -1.0):
            rows = [[_hull_point(xr, y, side) for y in heights + [_top_at(top, xr)]] for xr in stations]
            shapes += _loft(rows, _hull_slot, lambda q, s=side: [0.0, -0.2, s])

    # The transom: flat, from the tuck up to the poop's planking.
    heights = [h for h in ROWS if TUCK - 1e-6 <= h < POOP_SOLID - 1e-6] + [_poop_top(STERN)]
    bands = [(TUCK, DRY, "pitch"), (DRY, 2.45, "hull_tarred"), (2.45, _poop_top(STERN), "hull_bare")]

    for y0, y1, slot in bands:
        left = [_hull_point(STERN, y, 1.0) for y in heights if y0 - 1e-6 <= y <= y1 + 1e-6]
        right = [_hull_point(STERN, y, -1.0) for y in heights if y0 - 1e-6 <= y <= y1 + 1e-6]
        shapes.append(_face(left + right[::-1], slot, [-1.0, 0.0, 0.0]))

    # The keel under it all, the stem and the sternpost.
    keel = [[x, KEEL, 0.0] for x in (_x_at(STERN, KEEL), 0.0, _x_at(STEM, KEEL))]
    shapes += _sweep(keel, [(-0.18, 0.0), (0.18, 0.0), (0.18, -0.4), (-0.18, -0.4)], "hull_tarred")
    stem = [[_stem_x(y) + 0.02, y, 0.0] for y in (KEEL, -2.5, -1.5, -0.5, 0.5, 1.5, 2.5, 3.5, FORE_SOLID)]
    shapes += _tube(stem, 0.2, "hull_tarred", 4, turn=45.0)
    post = [[_x_at(STERN, y) - 0.05, y, 0.0] for y in (KEEL, TUCK)]
    shapes += _tube(post, 0.18, "hull_tarred", 4, turn=45.0)
    return shapes


def _deck_rows(stations, y, camber=0.06, steps=4):
    """A deck at y between the bulwarks' insides along `stations`, crowned
    `camber` at its middle (half above y, half below)."""
    rows = []

    for xr in stations:
        width = abs(_inside(xr, y)[2])
        rows.append([[_x_at(xr, y), y + camber * (0.5 - (2.0 * i / steps - 1.0) ** 2), width * (2.0 * i / steps - 1.0)] for i in range(steps + 1)])

    return rows


def _decks():
    shapes = []
    # The main deck from the transom to the forecastle (the cabin's floor
    # aft), the aftcastle's deck forward of the poop, the poop's.
    waist = [STERN + SKIN, -14.6, -12.4, POOP_FRONT, -8.5, CASTLE_FRONT, -3.0, 0.0, 3.0, 5.8, 7.0, FORE_BACK]
    shapes += _loft(_deck_rows(waist, MAIN_DECK), "boards", lambda q: [0.0, 1.0, 0.0])
    shapes += _loft(_deck_rows([POOP_FRONT, -8.5, CASTLE_FRONT], CASTLE_DECK, 0.0, 2), "boards", lambda q: [0.0, 1.0, 0.0])
    shapes += _loft(_deck_rows([STERN + SKIN, -13.0, POOP_FRONT], POOP_DECK, 0.0, 2), "boards", lambda q: [0.0, 1.0, 0.0])
    return shapes


def _bulwarks():
    """The bulwarks' insides over each deck (ceiling planks, the frames'
    heads standing out of them), the waterway at their foot, a rail capping
    the top of every side and every castle's solid planking; the cabin's
    panelled sides."""
    shapes = []

    for side in (1.0, -1.0):
        inward = [0.0, 0.0, -side]

        for stations, y0, y1 in ((list(PARTS[2][0]), MAIN_DECK, WAIST_RAIL),
                                 ([POOP_FRONT, -9.4, -7.7, CASTLE_FRONT], CASTLE_DECK, CASTLE_SOLID),
                                 ([STERN + SKIN, -14.6, -13.7, -12.4, POOP_FRONT], POOP_DECK, POOP_SOLID)):
            rows = [[_inside(xr, y, side) for y in (y0, (y0 + y1) / 2.0, _top_at(y1, xr))] for xr in stations]
            shapes += _loft(rows, "hull_bare", lambda q, n=inward: n)

            if y0 > MAIN_DECK:
                shapes += _sweep([_add(_inside(xr, _top_at(y1, xr), side), [0.0, 0.0, side * SKIN / 2.0]) for xr in stations],
                                 [(-0.19, -0.06), (0.19, -0.06), (0.19, 0.06), (-0.19, 0.06)], "timber", flip=side)
                continue

            # (The waterway along the deck's edge.)
            shapes += _sweep([_add(_inside(xr, y0, side), [0.0, 0.0, -side * 0.08]) for xr in stations],
                             [(-0.09, 0.0), (-0.09, 0.09), (0.09, 0.09), (0.09, 0.0)], "timber", flip=side, closed=False)
            # (The cap on the planking's top edge.)
            shapes += _sweep([_add(_inside(xr, _waist_top(xr), side), [0.0, 0.0, side * SKIN / 2.0]) for xr in stations],
                             [(-0.19, -0.06), (0.19, -0.06), (0.19, 0.06), (-0.19, 0.06)], "timber", flip=side)
            # (The frames' heads, every 0.7 m.)
            x0, x1 = _x_at(stations[0], y0), _x_at(stations[-1], y0)
            count = int((x1 - x0) / 0.7)

            for i in range(1, count):
                x = x0 + (x1 - x0) * i / count
                z = abs(_inside(x, (y0 + y1) / 2.0)[2]) - 0.07
                shapes += _stud(x, y0, _waist_top(x) - 0.06, side * z, 0.14, "timber", inward)

        # The cabin's sides, panelled.
        stations = [STERN + SKIN, -14.6, -13.7, -12.4, POOP_FRONT, -9.4, -7.7, CASTLE_FRONT]
        rows = [[_inside(xr, y, side) for y in (MAIN_DECK, 3.5, CASTLE_DECK)] for xr in stations]
        shapes += _loft(rows, "wood_old", lambda q, n=inward: n)

    return shapes


# Where each mast's shrouds come down to the hull: their feet along x, the
# channel they stand on (its height and how far out its edge is from the
# skin), the lower deadeyes over it.
CHANNELS = {"main": ([-3.0 + 0.6 * i for i in range(9)], 2.62, 0.32),
            "fore": ([8.95 + 0.5 * i for i in range(6)], 7.75, 0.42),
            "mizzen": ([-10.0 + 0.6 * i for i in range(4)], 4.25, 0.42)}
DEADEYE = 0.15


def _fore_half(x, y=FORE_SOLID):
    """The forecastle's half-breadth outside at x (a rounded triangle in
    plan, its nose beyond the stem), standing out over the bow."""
    curve = 4.1 * (1.0 - (max(0.0, x - 9.5) / (NOSE - 9.5)) ** 1.5)
    return max(0.3, curve, _bow_half(x) + 0.25) - 0.06 * (y - FORE_SOLID)


def _bow_half(x, y=FORE_SOLID):
    """The hull's half-breadth at x (where it is, not a station) and height
    y on the bow."""
    points = [_hull_point(xr, y) for xr in PARTS[3][0]]

    if x <= points[0][0]:
        return abs(points[0][2])

    for a, b in zip(points, points[1:]):
        if a[0] <= x <= b[0]:
            return a[2] + (b[2] - a[2]) * (x - a[0]) / (b[0] - a[0])

    return 0.0


def _skin_at(x, y):
    """The hull's half-breadth at x (where it is) and height y, anywhere
    along it."""
    stations = sorted({xr for part, _ in PARTS for xr in part})
    points = [_hull_point(xr, y) for xr in stations]

    for a, b in zip(points, points[1:]):
        if a[0] <= x <= b[0]:
            return a[2] + (b[2] - a[2]) * (x - a[0]) / max(1e-6, b[0] - a[0])

    return abs(points[0][2]) if x < points[0][0] else 0.0


def _channel_point(mast, x, side=1.0):
    """A lower deadeye's middle on its channel's edge (the rig's shrouds
    come down to over it)."""
    feet, y, out = CHANNELS[mast]
    skin = _fore_half(x, y) - SKIN / 2.0 + 0.19 if mast == "fore" else _skin_at(x, y)
    return [x, y + 0.08 + DEADEYE, side * (skin + out - 0.06)]


# The wales: their middle and height amidships, how much they rise to the
# bow and the stern.
WALES = [(0.67, 0.26, 0.6, 0.35), (1.78, 0.26, 1.0, 0.6), (2.45, 0.2, 1.3, 0.8)]
WALE_STATIONS = [STERN, -13.7, POOP_FRONT, -8.5, CASTLE_FRONT, -3.0, 0.0, 3.0, 5.8, FORE_BACK, 9.4, 10.6, 11.7, 12.6, 13.4, 14.0, 14.5, STEM]
GUNPORTS = [-9.0, -6.1, -3.2, -0.3, 2.4, 5.0]
SKIDS = [(-13.2, 7.9), (-10.6, 4.9), (-4.8, _waist_top(-4.8) - 0.08), (3.7, _waist_top(3.7) - 0.08), (6.4, _waist_top(6.4) - 0.08)]


def _wale_y(wale, x):
    middle, _, bow, stern = wale
    return middle + _rise(x) * (bow if x > 0.0 else stern)


def _sides():
    """What stands out of the hull's sides: wales sweeping up to the ends,
    the castles' deck lines, beam ends, the skids over them, gunports and
    their lids (three open to seaward, a gun run out), swivel ports in the castles,
    hawse holes."""
    shapes = []

    for side in (1.0, -1.0):
        for wale in WALES:
            rings, axis = [], []

            for xr in WALE_STATIONS:
                middle = _wale_y(wale, xr)
                proud = 0.13 * (1.0 - 0.6 * _smooth((xr - 12.0) / 3.0))
                low, high = _hull_point(xr, middle - wale[1] / 2.0, side), _hull_point(xr, middle + wale[1] / 2.0, side)
                rings.append([low, _add(low, [0.0, 0.0, side * proud]), _add(high, [0.0, 0.0, side * proud]), high])
                axis.append(_lerp(low, high, 0.5))

            shapes += _rings(rings, axis, "timber", caps=True, closed=False)

        # The castles' deck lines.
        for stations, y in (([STERN, -13.7, -12.4, POOP_FRONT, -9.4, -7.7, CASTLE_FRONT], CASTLE_DECK),
                            ([STERN, -13.7, -12.4, POOP_FRONT], POOP_DECK)):
            rings, axis = [], []

            for xr in stations:
                low, high = _hull_point(xr, y - 0.08, side), _hull_point(xr, y + 0.08, side)
                rings.append([low, _add(low, [0.0, 0.0, side * 0.1]), _add(high, [0.0, 0.0, side * 0.1]), high])
                axis.append(_lerp(low, high, 0.5))

            shapes += _rings(rings, axis, "timber", caps=True, closed=False)

        # Beam ends: the main deck's over the main wale, the castles' under
        # their deck lines.
        beams = [(x, _wale_y(WALES[1], x) + 0.33) for x in (-14.2, -12.8, -11.4, -9.9, -8.4, -6.9, -5.6, -4.3, 3.0, 4.3, 5.6, 6.9)]
        beams += [(x, CASTLE_DECK - 0.24) for x in (-14.4, -13.0, -11.6, -6.9)] + [(x, POOP_DECK - 0.24) for x in (-14.2, -12.8, -11.5)]

        for x, y in beams:
            shapes += _block(x, y, side * (_skin_at(x, y) + 0.03), 0.22, 0.22, 0.22, "beam", side)

        # Skids: upright timbers standing on the wales.
        for x, top in SKIDS:
            heights = [0.45, 1.35, 2.45] + [h for h in (CASTLE_DECK - 0.5,) if 2.45 < h < top] + [top]
            rings, axis = [], []

            for y in heights:
                skin = _skin_at(x, y)
                inner, outer = side * (skin + 0.12), side * (skin + 0.26)
                rings.append([[x - 0.1, y, inner], [x - 0.1, y, outer], [x + 0.1, y, outer], [x + 0.1, y, inner]])
                axis.append([x, y, inner])

            shapes += _rings(rings, axis, "timber", caps=True, closed=False)

        # The gunports of the gun deck, their lids on two iron straps: shut on
        # the quay's side, three open to seaward, guns run out in them.
        for x in GUNPORTS:
            skin = _skin_at(x, 1.25)
            run = math.degrees(math.atan2(side * (_skin_at(x + 0.3, 1.25) - _skin_at(x - 0.3, 1.25)), 0.6))
            yaw = -run
            # (On the quay's side an open lid would swing into the quay.)
            open_ = side > 0 and x in (-6.1, -0.3, 2.4)

            if open_:
                # (Its lid swung up, a gun's muzzle in it.)
                shapes += _block(x, 1.25, side * (skin - 0.02), 0.5, 0.5, 0.1, "pitch", side, yaw)
                angle = 70.0
                hinge = [x, 1.56, side * (skin + 0.04)]
                down = [0.0, -math.cos(math.radians(angle)), side * math.sin(math.radians(angle))]
                centre = _add(hinge, _mul(down, 0.31))
                shapes.append(ks.box(centre[0], centre[1], centre[2], 0.62, 0.62, 0.08, "hull_tarred", yaw, -side * angle))

                for dx in (-0.2, 0.2):
                    strap = _add(hinge, _mul(down, 0.36))
                    shapes.append(ks.box(x + dx, strap[1] + 0.02, strap[2], 0.05, 0.74, 0.02, "iron", yaw, -side * angle))

                shapes.append(ks.prism(x, 1.25, side * (skin + 0.2), 0.11, 0.7, 6, "iron", pitch=90.0, top=0.09))
            else:
                shapes += _block(x, 1.25, side * (skin + 0.04), 0.62, 0.62, 0.08, "hull_tarred", side, yaw)

                for dx in (-0.2, 0.2):
                    shapes += _block(x + dx, 1.33, side * (skin + 0.09), 0.05, 0.62, 0.02, "iron", side, yaw)

        # Swivel ports in the castles.
        for x, y in ((-14.0, 4.0), (-12.2, 4.0), (-6.8, 4.0), (-14.2, 7.0), (-12.6, 7.0)):
            shapes.append(ks.card(x, y, side * (_skin_at(x, y) + 0.02), 0.28, 0.28, "pitch"))

        # Hawse holes, two a side under the forecastle.
        for x in (13.15, 13.85):
            y = 3.0
            skin = _bow_half(x, y)
            slope = (_bow_half(x + 0.2, y) - _bow_half(x - 0.2, y)) / 0.4
            yaw = math.degrees(math.atan2(-slope, 1.0)) if side > 0 else 180.0 + math.degrees(math.atan2(slope, 1.0))
            shapes.append(ks.disc(x, y, side * (skin + 0.08), 0.15, 6, "pitch", yaw))
            shapes += _block(x, y, side * (skin + 0.03), 0.48, 0.48, 0.1, "timber", side, yaw if side > 0 else yaw - 180.0)

    return shapes


def _chains():
    """The channels (rigging's, drawn with the rig): boards out from the
    sides on knees, the lower deadeyes on their edges, chainplates down over
    the wales."""
    shapes = []

    for side in (1.0, -1.0):
        for mast, (feet, y, out) in CHANNELS.items():
            x0, x1 = feet[0] - 0.35, feet[-1] + 0.35
            a, b = _channel_point(mast, x0, side), _channel_point(mast, x1, side)
            length = math.hypot(b[0] - a[0], b[2] - a[2])
            yaw = -math.degrees(math.atan2(b[2] - a[2], b[0] - a[0]))
            centre = [(x0 + x1) / 2.0, y, (a[2] + b[2]) / 2.0 - side * (out / 2.0 - 0.06)]
            shapes.append(ks.box(centre[0], centre[1], centre[2], length, 0.1, out + 0.1, "timber", yaw))

            for x in (x0 + 0.5, x1 - 0.5):
                edge = _channel_point(mast, x, side)
                shapes.append(ks.box(x, y - 0.25, edge[2] - side * out * 0.55, 0.1, 0.4, out * 0.6, "timber", yaw, 0.0, 0.0))

            for x in feet:
                p = _channel_point(mast, x, side)
                shapes.append(ks.prism(p[0], p[1], p[2], DEADEYE, 0.12, 5, "beam", pitch=90.0))

                if mast == "fore":
                    continue

                low = y - 0.95 if mast == "main" else y - 0.7
                skin = _skin_at(x, low) + (0.15 if mast == "main" else 0.05)
                top = [p[0], p[1] - DEADEYE, p[2]]
                bottom = [x, low, side * skin]
                shapes += _tube([top, bottom], 0.035, "iron", 3, caps=False)

    return shapes


def _open_tier(points, y0, y1, side, shields=True, every=0.7, slot="timber"):
    """An open rail along `points` (its middle, at any height): posts every
    `every` m from y0 up to a cap rail at y1 (either a height or one along x),
    painted shields hung outside it (`side` 1 to the right of its run, toward
    +z for a rail running +x; -1 to its left)."""
    shapes = []
    low = y0 if callable(y0) else (lambda x: y0)
    high = y1 if callable(y1) else (lambda x: y1)
    path = [[p[0], high(p[0]) - 0.06, p[2]] for p in points]
    shapes += _sweep(path, [(-0.17, -0.06), (0.17, -0.06), (0.17, 0.06), (-0.17, 0.06)], slot, flip=side)
    length = sum(math.hypot(b[0] - a[0], b[2] - a[2]) for a, b in zip(points, points[1:]))
    count = max(1, int(round(length / every)))
    marks = []

    for i in range(count + 1):
        s = length * i / count
        for a, b in zip(points, points[1:]):
            step = math.hypot(b[0] - a[0], b[2] - a[2])

            if s <= step + 1e-6:
                marks.append(_lerp(a, b, s / step if step > 1e-6 else 0.0))
                break

            s -= step

    for p in marks:
        shapes.append(_post(p[0], low(p[0]), high(p[0]) - 0.12, p[2], 0.12, slot))

    if shields:
        for i, (a, b) in enumerate(zip(marks, marks[1:])):
            middle = _lerp(a, b, 0.5)
            run = _unit([b[0] - a[0], 0.0, b[2] - a[2]])
            out = _mul([-run[2], 0.0, run[0]], side)
            yaw = math.degrees(math.atan2(out[0], out[2]))
            centre = _add(middle, _mul(out, 0.13))
            y0, y1 = low(centre[0]), high(centre[0])
            shapes.append(ks.disc(centre[0], (y0 + y1) / 2.0 + 0.02, centre[2], min(0.38, (y1 - y0) / 2.0 + 0.1), 6,
                                  "shield_%d" % (1 + (i + int(abs(middle[0]) * 7)) % 3), yaw))

    return shapes


def _castles():
    """The castles' open tiers over their solid planking (posts, a cap
    rail, pavises), the breastwork at the aftcastle's front and the poop's,
    the taffrail; their bulkheads: the cabin's with its door, the poop's,
    the forecastle's."""
    shapes = []

    for side in (1.0, -1.0):
        shapes += _open_tier([_add(_inside(xr, CASTLE_SOLID, side), [0.0, 0.0, side * SKIN / 2.0]) for xr in (POOP_FRONT, -9.4, -7.7, CASTLE_FRONT)],
                             CASTLE_SOLID, CASTLE_RAIL, side)
        shapes += _open_tier([_add(_inside(xr, _poop_top(xr), side), [0.0, 0.0, side * SKIN / 2.0]) for xr in (STERN + 0.1, -13.7, -12.4, POOP_FRONT)],
                             _poop_top, lambda x: _poop_top(x) + POOP_RAIL - POOP_SOLID, side)

    # The taffrail across the stern.
    w = abs(_hull_point(STERN, _poop_top(STERN))[2]) - SKIN / 2.0
    shapes += _open_tier([[STERN + 0.1, 0.0, w], [STERN + 0.1, 0.0, -w]], _poop_top(STERN), _poop_top(STERN) + POOP_RAIL - POOP_SOLID, -1.0, every=0.65)
    # The breastworks: across the aftcastle's front (gaps at the ladders'
    # heads) and the poop's (a gap at its ladder).
    w = abs(_inside(CASTLE_FRONT, CASTLE_RAIL)[2]) + SKIN / 2.0
    x = CASTLE_FRONT + 0.06

    for z0, z1 in ((-w, -3.05), (-1.75, 1.75), (3.05, w)):
        shapes += _open_tier([[x, 0.0, z1], [x, 0.0, z0]], CASTLE_DECK, CASTLE_RAIL, 1.0, shields=False)

    w = abs(_inside(POOP_FRONT, POOP_RAIL)[2]) + SKIN / 2.0
    x = POOP_FRONT + 0.06

    for z0, z1 in ((-w, 1.05), (2.15, w)):
        shapes += _open_tier([[x, 0.0, z1], [x, 0.0, z0]], POOP_DECK, POOP_RAIL, 1.0, shields=False)

    # The cabin's bulkhead, its door's opening (the level hangs the door in
    # it), posts either side, two windows; the poop's front with its door
    # and windows over the aftcastle's deck.
    for face, out in ((CASTLE_FRONT + 0.1, 1.0), (CASTLE_FRONT - 0.1, -1.0)):
        for s in (1.0, -1.0):
            edge = [[face, y, s * abs(_hull_point(CASTLE_FRONT, y)[2])] for y in (MAIN_DECK, 2.45, WAIST_RAIL, FORE_SOLID, CASTLE_DECK)]
            shapes.append(_face([[face, MAIN_DECK, s * DOOR[0] / 2.0]] + edge + [[face, CASTLE_DECK, s * DOOR[0] / 2.0]], "hull_bare", [out, 0.0, 0.0]))

        shapes.append(_face([[face, MAIN_DECK + DOOR[1], -DOOR[0] / 2.0], [face, MAIN_DECK + DOOR[1], DOOR[0] / 2.0],
                             [face, CASTLE_DECK, DOOR[0] / 2.0], [face, CASTLE_DECK, -DOOR[0] / 2.0]], "hull_bare", [out, 0.0, 0.0]))

    for s in (1.0, -1.0):
        z = s * DOOR[0] / 2.0
        shapes.append(_face([[CASTLE_FRONT - 0.1, MAIN_DECK, z], [CASTLE_FRONT + 0.1, MAIN_DECK, z], [CASTLE_FRONT + 0.1, MAIN_DECK + DOOR[1], z],
                             [CASTLE_FRONT - 0.1, MAIN_DECK + DOOR[1], z]], "timber", [0.0, 0.0, -s]))
        shapes.append(_post(CASTLE_FRONT + 0.16, MAIN_DECK, CASTLE_DECK, s * (DOOR[0] / 2.0 + 0.12), 0.2, "beam"))
        shapes.append(ks.box(CASTLE_FRONT + 0.13, 3.55, s * 1.4, 0.06, 0.8, 0.7, "timber"))
        shapes.append(ks.card(CASTLE_FRONT + 0.17, 3.55, s * 1.4, 0.5, 0.6, "glass_dark", 90.0))

    shapes.append(_face([[CASTLE_FRONT - 0.1, MAIN_DECK + DOOR[1], -DOOR[0] / 2.0], [CASTLE_FRONT + 0.1, MAIN_DECK + DOOR[1], -DOOR[0] / 2.0],
                         [CASTLE_FRONT + 0.1, MAIN_DECK + DOOR[1], DOOR[0] / 2.0], [CASTLE_FRONT - 0.1, MAIN_DECK + DOOR[1], DOOR[0] / 2.0]],
                        "timber", [0.0, -1.0, 0.0]))
    shapes.append(ks.box(CASTLE_FRONT + 0.16, MAIN_DECK + DOOR[1] + 0.1, 0.0, 0.12, 0.2, DOOR[0] + 0.5, "beam"))
    # (The aftcastle deck's edge over the bulkhead.)
    w = abs(_hull_point(CASTLE_FRONT, CASTLE_DECK)[2])
    shapes.append(ks.box(CASTLE_FRONT + 0.12, CASTLE_DECK - 0.1, 0.0, 0.24, 0.2, 2.0 * w, "timber"))
    # The poop's front.
    edge = [[POOP_FRONT + 0.02, y, abs(_hull_point(POOP_FRONT, y)[2])] for y in (CASTLE_DECK, 6.95, POOP_SOLID)]
    shapes.append(_face(edge + [[p[0], p[1], -p[2]] for p in reversed(edge)], "hull_bare", [1.0, 0.0, 0.0]))
    shapes.append(ks.box(POOP_FRONT + 0.06, CASTLE_DECK + 1.05, 0.0, 0.06, 2.2, 1.25, "timber"))
    shapes.append(ks.card(POOP_FRONT + 0.1, CASTLE_DECK + 1.0, 0.0, 1.0, 2.0, "door_1", 90.0))
    shapes.append(ks.box(POOP_FRONT + 0.12, POOP_DECK - 0.1, 0.0, 0.24, 0.2, 2.0 * abs(_hull_point(POOP_FRONT, POOP_DECK)[2]), "timber"))

    shapes.append(ks.box(POOP_FRONT + 0.05, 6.4, -1.5, 0.06, 0.7, 0.6, "timber"))
    shapes.append(ks.card(POOP_FRONT + 0.09, 6.4, -1.5, 0.42, 0.52, "glass_dark", 90.0))

    return shapes


def _forecastle():
    """The forecastle: a rounded triangle in plan over the bow, its nose a
    good way past the stem on knees; its solid tier, its deck, an open tier
    of pavises over it; its bulkhead to the waist; catheads and anchors."""
    shapes = []
    xs = [FORE_BACK, 9.0, 10.3, 11.6, 12.9, 14.1, 15.2, 16.2, 16.9, NOSE]

    for side in (1.0, -1.0):
        rows = [[[x, y, side * _fore_half(x, y)] for y in (FORE_SOLID, 5.6, _fore_top(x))] for x in xs]
        shapes += _loft(rows, "hull_bare", lambda q, s=side: [0.0, 0.0, s])
        inside = [[[x, y, side * (_fore_half(x, y) - SKIN)] for y in (FORE_DECK, _fore_top(x))] for x in xs[:-1]]
        shapes += _loft(inside, "hull_bare", lambda q, s=side: [0.0, 0.0, -s])

        # Mouldings: the overhang's edge, the deck line; the cap on the solid
        # tier; the open tier over it.
        for y, h, proud in ((FORE_SOLID, 0.2, 0.14), (5.45, 0.12, 0.08), (FORE_DECK, 0.16, 0.1)):
            path = [[x, y, side * _fore_half(x, y)] for x in xs]
            shapes += _sweep(path, [(0.0, -h / 2.0), (proud, -h / 2.0), (proud, h / 2.0), (0.0, h / 2.0)], "timber", flip=side, closed=False)

        shapes += _sweep([[x, _fore_top(x), side * (_fore_half(x, FORE_TOP_SOLID) - SKIN / 2.0)] for x in xs[:-1]],
                         [(-0.19, -0.06), (0.19, -0.06), (0.19, 0.06), (-0.19, 0.06)], "timber", flip=side)
        shapes += _open_tier([[x, 0.0, side * (_fore_half(x, 7.3) - SKIN / 2.0)] for x in xs[:-1]] + [[NOSE - 0.15, 0.0, 0.0]],
                             _fore_top, lambda x: _fore_top(x) + FORE_RAIL - FORE_TOP_SOLID, side)
        # (Beam ends under the deck line.)
        for x in (9.2, 10.6, 12.0, 13.4, 14.8):
            shapes += _block(x, FORE_DECK - 0.25, side * (_fore_half(x, 6.2) + 0.02), 0.2, 0.2, 0.2, "beam", side)

        # Brackets under the overhang.
        for x in (10.3, 11.6, 12.9, 14.1, 15.2):
            inner, outer = _bow_half(x, 3.75), _fore_half(x)
            angle = math.degrees(math.atan2(outer + 0.05 - inner, 0.6))
            shapes.append(ks.box(x, 4.0, side * (inner + outer) / 2.0, 0.16, 0.7, 0.16, "timber", 0.0, side * angle))

        # A swivel port or two.
        for x in (12.9, 14.6):
            shapes.append(ks.box(x, 5.75, side * (_fore_half(x, 5.75) + 0.01), 0.28, 0.28, 0.06, "pitch"))

        # Its cathead, an anchor catted and fished along the bow under it.
        root = [13.6, 5.35, side * _fore_half(13.6, 5.35)]
        tip = [14.5, 5.45, side * (_fore_half(13.6, 5.35) + 0.95)]
        shapes += _tube([root, tip], 0.15, "timber", 4, turn=45.0)
        shapes += _anchor([tip[0], 5.15, tip[2]], [12.4, 1.75, side * (_skin_at(12.4, 1.75) + 0.2)])

    # The nose's front, the soffit under the whole overhang, the knee under
    # the nose.
    w = _fore_half(NOSE)
    shapes.append(_face([[NOSE, FORE_SOLID, -w], [NOSE, FORE_SOLID, w], [NOSE, _fore_top(NOSE), w - 0.08], [NOSE, _fore_top(NOSE), -w + 0.08]], "hull_bare",
                        [1.0, 0.0, 0.0]))
    outline = [[x, FORE_SOLID, _fore_half(x)] for x in xs] + [[x, FORE_SOLID, -_fore_half(x)] for x in reversed(xs)]
    shapes.append(_face(outline, "hull_bare", [0.0, -1.0, 0.0]))
    stem_top = _stem_x(FORE_SOLID)
    shapes += _tube([[_stem_x(2.4), 2.4, 0.0], [stem_top + 0.2, 3.6, 0.0], [NOSE - 0.25, FORE_SOLID - 0.05, 0.0]], 0.17, "timber", 4, turn=45.0)

    # Its deck, its bulkhead to the waist (two doors, ports over them), the
    # rail along its back with a gap at the ladder's head.
    deck = [[x, FORE_DECK, _fore_half(x, FORE_DECK) - SKIN] for x in xs[:-1] + [NOSE - 0.45]]
    shapes.append(_face([[FORE_BACK, FORE_DECK, -deck[0][2]]] + deck + [[x, y, -z] for x, y, z in reversed(deck)][:-1], "boards", [0.0, 1.0, 0.0]))
    low = [[FORE_BACK, y, abs(_hull_point(FORE_BACK, y)[2])] for y in (MAIN_DECK, 2.45, WAIST_RAIL, FORE_SOLID)]
    high = [[FORE_BACK, y, _fore_half(FORE_BACK, y)] for y in (FORE_SOLID, FORE_TOP_SOLID)]

    for part in (low, high):
        shapes.append(_face(part + [[x, y, -z] for x, y, z in reversed(part)], "hull_bare", [-1.0, 0.0, 0.0]))

    for s in (1.0, -1.0):
        shapes.append(ks.box(FORE_BACK - 0.03, MAIN_DECK + 1.02, s * 1.75, 0.06, 2.1, 1.25, "timber"))
        shapes.append(ks.card(FORE_BACK - 0.07, MAIN_DECK + 0.98, s * 1.75, 1.0, 1.95, "door_1", 90.0))
        shapes.append(ks.box(FORE_BACK - 0.02, 5.4, s * 1.75, 0.04, 0.28, 0.28, "pitch"))

    w = _fore_half(FORE_BACK, FORE_RAIL) - SKIN / 2.0

    for z0, z1 in ((-w, -0.65), (0.65, w)):
        shapes += _open_tier([[FORE_BACK + 0.06, 0.0, z0], [FORE_BACK + 0.06, 0.0, z1]], FORE_TOP_SOLID, FORE_RAIL, -1.0, shields=False)

    shapes.append(ks.box(FORE_BACK - 0.1, FORE_DECK - 0.1, 0.0, 0.2, 0.2, 2.0 * _fore_half(FORE_BACK), "timber"))
    return shapes


def _anchor(ring, crown):
    """An anchor hanging from its ring down to its crown: iron shank, two
    arms with their flukes, its wooden stock across the shank's head."""
    shapes = _tube([ring, crown], 0.09, "iron", 4, caps=False)
    run = _unit(_sub(crown, ring))
    along = _unit(_cross(run, [0.0, 0.0, 1.0]))

    for sign in (1.0, -1.0):
        arm = _unit(_add(_mul(run, -0.6), _mul(along, sign)))
        tip = _add(crown, _mul(arm, 1.1))
        shapes += _tube([crown, tip], 0.08, "iron", 4)
        shapes += _tube([_add(tip, _mul(arm, -0.35)), _add(tip, _mul(arm, 0.08))], 0.2, "iron", 4, squash=0.25)

    head = _add(ring, _mul(run, 0.45))
    shapes += _tube([_add(head, [-1.0, 0.0, 0.0]), _add(head, [1.0, 0.0, 0.0])], 0.12, "wood_old", 4, turn=45.0)
    shapes.append(ks.ring(ring[0], ring[1] + 0.05, ring[2], 0.12, 0.18, 0.05, 0.0, 360.0, 6, "iron", 90.0))
    return shapes


def _stern():
    """The transom's mouldings, the cabin's windows (lit) and the poop's,
    the helm port, the rudder on its pintles; two great lanterns on the
    taffrail and the iron the level's lantern hangs from."""
    shapes = []
    x = STERN - 0.04

    for y, h in ((DRY + 0.05, 0.16), (MAIN_DECK, 0.18), (CASTLE_DECK, 0.18), (POOP_DECK, 0.18)):
        w = abs(_hull_point(STERN, y)[2])
        shapes.append(ks.box(x, y, 0.0, 0.12, h, 2.0 * w + 0.1, "timber"))

    for s in (1.0, -1.0):
        shapes.append(ks.box(STERN - 0.02, 3.6, s * 1.25, 0.06, 0.95, 0.8, "timber"))
        shapes.append(ks.card(STERN - 0.07, 3.6, s * 1.25, 0.6, 0.72, "glass_lit", 90.0))
        shapes.append(ks.card(STERN + SKIN + 0.03, 3.6, s * 1.25, 0.6, 0.72, "glass_lit", 90.0))
        shapes.append(ks.box(STERN - 0.02, 6.6, s * 0.95, 0.06, 0.66, 0.56, "timber"))
        shapes.append(ks.card(STERN - 0.06, 6.6, s * 0.95, 0.4, 0.48, "glass_dark", 90.0))

    # The transom's corners.
    for s in (1.0, -1.0):
        corner = [[STERN - 0.03, y, s * (abs(_hull_point(STERN, y)[2]) - 0.06)] for y in (TUCK, DRY, YMAX, 2.45, FORE_SOLID, CASTLE_SOLID, 6.95, _poop_top(STERN))]
        shapes += _tube(corner, 0.13, "timber", 4, turn=45.0)

    # The cabin's back: the transom's inside.
    heights = [MAIN_DECK, 3.5, CASTLE_DECK]
    left = [_inside(STERN + SKIN, y, 1.0) for y in heights]
    shapes.append(_face(left + [[p[0], p[1], -p[2]] for p in reversed(left)], "wood_old", [1.0, 0.0, 0.0]))
    # The helm port, the rudder's head in it.
    shapes.append(ks.box(STERN - 0.01, 1.45, 0.0, 0.06, 0.6, 0.56, "pitch"))
    fwd = lambda y: _x_at(STERN, y) - 0.12 if y < TUCK else STERN - 0.12
    edge = [(fwd(y), y) for y in (-3.4, -2.2, TUCK, DRY, 1.75)]
    back = [(STERN - 0.55, 1.75), (STERN - 0.62, 1.0), (STERN - 0.85, DRY), (fwd(TUCK) - 1.05, TUCK), (fwd(-2.2) - 1.3, -2.2), (fwd(-3.4) - 1.5, -3.3)]
    outline = edge + back

    for z, out in ((0.14, 1.0), (-0.14, -1.0)):
        shapes.append(_face([[px, py, z] for px, py in outline], "timber", [0.0, 0.0, out]))

    for (ax, ay), (bx, by) in zip(outline, outline[1:] + outline[:1]):
        quad = [[ax, ay, 0.14], [bx, by, 0.14], [bx, by, -0.14], [ax, ay, -0.14]]
        shapes.append(_face(quad, "timber", [by - ay, -(bx - ax), 0.0]))

    for y in (-2.9, -1.9, -0.9, 0.15, 1.1):
        x0 = fwd(y)
        shapes.append(ks.box(x0 - 0.38, y, 0.0, 0.8, 0.09, 0.32, "iron"))
        shapes.append(ks.box(x0 + 0.2, y + 0.12, 0.0, 0.5, 0.09, 0.44, "iron"))

    # The lanterns.
    rail = _poop_top(STERN) + POOP_RAIL - POOP_SOLID

    for s in (1.0, -1.0):
        z = s * 2.0
        shapes.append(_post(STERN + 0.1, rail, rail + 0.6, z, 0.08, "iron"))
        shapes.append(ks.lathe(STERN + 0.1, rail + 0.6, z, [[0.12, 0.0], [0.26, 0.12], [0.3, 0.55], [0.22, 0.75]], 6, "glass_lit"))
        shapes.append(ks.lathe(STERN + 0.1, rail + 1.35, z, [[0.25, 0.0], [0.12, 0.22], [0.02, 0.4]], 6, "iron"))

    # (The level's lantern hangs at -15.8, 10.2 off the stern.)
    shapes.append(_post(STERN + 0.1, rail, 10.32, 0.0, 0.07, "iron"))
    shapes.append(ks.box(-15.48, 10.27, 0.0, 0.76, 0.06, 0.06, "iron"))
    shapes += _tube([[STERN + 0.1, 9.85, 0.0], [-15.6, 10.25, 0.0]], 0.03, "iron", 4)
    return shapes


def _waist():
    """On the main deck: the main hatch with the ship's boat on it, a
    grating, the capstan aft of the mainmast, the jeer bitts, the pump,
    water casks and coils of rope; the cabin's table, bench and cot."""
    shapes = []
    y = MAIN_DECK + 0.03
    # The hatch's coaming, the boat on chocks over it.
    shapes += [ks.box(4.1, y + 0.12, 0.75 + s * 0.85, 4.4, 0.25, 0.14, "timber") for s in (1.0, -1.0)]
    shapes += [ks.box(4.1 + s * 2.13, y + 0.12, 0.75, 0.14, 0.25, 1.56, "timber") for s in (1.0, -1.0)]
    shapes += _boat(4.1, y + 0.3, 0.75, 4.6, 1.6, 0.62)
    shapes += [ks.box(x, y + 0.27, 0.75, 0.2, 0.12, 1.5, "wood_old") for x in (2.6, 5.6)]
    # The grating abaft the mast.
    shapes.append(ks.box(-1.8, y + 0.07, 0.0, 1.3, 0.14, 1.1, "timber"))
    shapes += [ks.box(-1.8 + dx, y + 0.15, 0.0, 0.05, 0.04, 1.0, "beam") for dx in (-0.45, -0.15, 0.15, 0.45)]
    # The capstan.
    shapes.append(ks.lathe(-3.4, y, 1.3, [[0.55, 0.0], [0.55, 0.12], [0.36, 0.2], [0.3, 0.75], [0.48, 0.8], [0.48, 1.0], [0.0, 1.02]], 8, "timber"))

    for angle in (0.0, 90.0):
        shapes.append(ks.box(-3.4, y + 0.9, 1.3, 1.5, 0.08, 0.08, "wood_old", angle))

    # The jeer bitts and the partners round the mast.
    for s in (1.0, -1.0):
        shapes.append(ks.box(0.85, y + 0.55, s * 0.6, 0.26, 1.1, 0.26, "beam"))

    shapes.append(ks.box(0.85, y + 0.85, 0.0, 0.18, 0.18, 1.5, "beam"))
    shapes.append(ks.box(0.0, y + 0.08, 0.0, 1.2, 0.16, 1.2, "timber"))
    # The pump, casks against the bulwark, coils.
    shapes.append(ks.prism(-1.9, y + 0.5, 1.45, 0.16, 1.0, 6, "wood_old"))
    shapes.append(ks.box(-1.9, y + 0.95, 1.2, 0.06, 0.06, 0.7, "iron", 0.0, 20.0))

    for x in (2.2, 2.95):
        shapes.append(ks.prism(x, y + 0.42, 3.35, 0.32, 0.84, 8, "wood_old", rings=[[0.5, 0.37]]))

    for x, z in ((0.85, 1.2), (6.6, 3.2), (-8.0, 2.8)):
        shapes.append(ks.disc(x, y + 0.04 if x > -6.0 else CASTLE_DECK + 0.04, z, 0.42, 8, "rope_coil", pitch=-90.0))
        shapes.append(ks.lathe(x, (y if x > -6.0 else CASTLE_DECK) - 0.02, z, [[0.43, 0.0], [0.43, 0.08]], 8, "rope", caps=False))

    # The cabin: table (the level's candles stand on it at 2.85), bench,
    # a carpet, a shelf, the frames up its sides; the deckhead and its beams.
    shapes.append(_face([[-13.4, MAIN_DECK + 0.035, -1.3], [-10.4, MAIN_DECK + 0.035, -1.3], [-10.4, MAIN_DECK + 0.035, 1.3],
                         [-13.4, MAIN_DECK + 0.035, 1.3]], "carpet", [0.0, 1.0, 0.0]))
    shapes.append(ks.box(STERN + SKIN + 0.15, 4.1, 0.0, 0.3, 0.06, 1.6, "wood_old"))

    for side in (1.0, -1.0):
        for x in (-14.0, -12.6, -11.2, -9.8, -8.4, -7.0):
            rings, axis = [], []

            for y in (MAIN_DECK, 3.5, CASTLE_DECK - 0.1):
                z = abs(_inside(x, y)[2])
                rings.append([[x - 0.08, y, side * z], [x - 0.08, y, side * (z - 0.12)], [x + 0.08, y, side * (z - 0.12)], [x + 0.08, y, side * z]])
                axis.append([x, y, side * z])

            shapes += _rings(rings, axis, "beam", caps=False, closed=False)

    shapes.append(ks.box(-12.0, 2.81, 0.0, 1.8, 0.06, 1.0, "wood_old"))
    shapes += [ks.box(-12.0 + dx, 2.4, 0.0, 0.1, 0.78, 0.8, "wood_old") for dx in (-0.7, 0.7)]
    shapes.append(ks.box(-12.0, 2.15, 0.0, 1.4, 0.06, 0.1, "wood_old"))
    shapes.append(ks.box(-12.0, 2.45, -0.95, 1.5, 0.06, 0.36, "wood_old"))
    shapes += [ks.box(-12.0 + dx, 2.22, -0.95, 0.06, 0.44, 0.3, "wood_old") for dx in (-0.6, 0.6)]
    # (His box bed is the level's: kit_interiors cot_box.)
    deckhead = _deck_rows([STERN + SKIN, -12.4, POOP_FRONT, -8.5, CASTLE_FRONT - 0.1], CASTLE_DECK - 0.04, 0.0, 2)
    shapes += _loft(deckhead, "boards", lambda q: [0.0, -1.0, 0.0])

    for x in (-14.0, -12.6, -11.2, -9.8, -8.4, -7.0):
        w = abs(_inside(x, CASTLE_DECK)[2])
        shapes.append(ks.box(x, CASTLE_DECK - 0.15, 0.0, 0.2, 0.22, 2.0 * w, "beam"))

    return shapes


def _boat(x, y, z, length, beam, depth):
    """The ship's boat, upright, its keel at y: lofted out and in, thwarts."""
    stations = [(-0.5, 0.55, 0.3), (-0.3, 0.95, 0.05), (0.0, 1.0, 0.0), (0.3, 0.85, 0.05), (0.5, 0.06, 0.2)]
    rows = []

    for f, w, lift in stations:
        section = [(0.05, lift * depth), (0.75 * w, 0.25 * depth + lift * depth * 0.6), (w, depth + lift * depth * 0.5)]
        rows.append([[x + f * length, y + py, z + s * pz * beam / 2.0] for s in (-1.0, 1.0) for pz, py in (section if s > 0 else section[::-1])])

    shapes = _loft(rows, "hull_bare", lambda q: _sub(_mid(q), [x, y + depth, z]))
    shapes += _loft(rows, "boards", lambda q: _sub([x, y + depth, z], _mid(q)))
    shapes += [ks.box(x + dx, y + depth * 0.6, z, 0.18, 0.04, beam * 0.9, "timber") for dx in (-0.9, 0.2, 1.1)]
    return shapes


def _hull_cols():
    """The hull's colliders: its body under each deck, the bulwarks
    following the sides, the cabin's walls and door, the castles' decks and
    rails, the forecastle's body, deck and rails, what stands on the deck."""
    cols = [col(-12.6, (MAIN_DECK + KEEL) / 2.0, 0.0, 5.2, MAIN_DECK - KEEL, 6.8),
            col(-1.0, (MAIN_DECK + KEEL) / 2.0, 0.0, 18.0, MAIN_DECK - KEEL, 8.6),
            col(10.0, (FORE_DECK + KEEL + 0.5) / 2.0, 0.0, 4.0, FORE_DECK - KEEL - 0.5, 7.4),
            col(13.25, (FORE_DECK - 1.5) / 2.0, 0.0, 2.5, FORE_DECK + 1.5, 4.6)]

    def along(stations, y0, y1, side, offset, thick):
        """Boxes from station to station along a side, their middles
        `offset` out from its inside at mid height."""
        out = []
        ym = (y0 + y1) / 2.0

        for a, b in zip(stations, stations[1:]):
            pa, pb = _inside(a, ym, side), _inside(b, ym, side)
            za, zb = pa[2] + side * offset, pb[2] + side * offset
            length = math.hypot(pb[0] - pa[0], zb - za)
            yaw = -math.degrees(math.atan2(zb - za, pb[0] - pa[0]))
            out.append(col((pa[0] + pb[0]) / 2.0, ym, (za + zb) / 2.0, length + 0.05, y1 - y0, thick, yaw))

        return out

    for side in (1.0, -1.0):
        # (The test of the decks knows the waist's bulwark by its top at 3.0.
        # Where it sweeps up to the castles a box a metre or so long, each as
        # high as its higher end: none stands much over the rail beside it,
        # as one long box would over the rope ladder's head, JACOB.)
        aft = [CASTLE_FRONT + (-1.5 - CASTLE_FRONT) * i / 3.0 for i in range(4)]
        fore = [3.5 + (FORE_BACK - 3.5) * i / 4.0 for i in range(5)]

        for a, b in list(zip(aft, aft[1:])) + [(-1.5, 3.5)] + list(zip(fore, fore[1:])):
            cols += along([a, b], MAIN_DECK, max(_waist_top(a), _waist_top(b)), side, SKIN / 2.0, 0.25)

        cols += along([STERN + SKIN, -12.4, -9.4, CASTLE_FRONT], MAIN_DECK, CASTLE_DECK, side, 0.1, 0.2)
        cols += along([POOP_FRONT, CASTLE_FRONT], CASTLE_DECK, CASTLE_RAIL, side, SKIN / 2.0, 0.25)
        cols += along([STERN + SKIN, POOP_FRONT], POOP_DECK, _poop_top(STERN) + POOP_RAIL - POOP_SOLID, side, SKIN / 2.0, 0.25)
        # The forecastle's rails, along its plan.
        xs = [FORE_BACK, 10.3, 12.9, 15.2, NOSE]

        for a, b in zip(xs, xs[1:]):
            za, zb = side * (_fore_half(a, 7.0) - SKIN / 2.0), side * (_fore_half(b, 7.0) - SKIN / 2.0)
            length = math.hypot(b - a, zb - za)
            yaw = -math.degrees(math.atan2(zb - za, b - a))
            top = max(_fore_top(a), _fore_top(b)) + FORE_RAIL - FORE_TOP_SOLID
            cols.append(col((a + b) / 2.0, (FORE_DECK + top) / 2.0, (za + zb) / 2.0, length + 0.1, top - FORE_DECK, 0.25, yaw))

    # The cabin: its back, its bulkhead either side of the door and over it,
    # its deckhead (the aftcastle's deck), the poop over its after part.
    w = abs(_inside(CASTLE_FRONT, MAIN_DECK)[2])
    cols += [col(STERN + 0.1, (MAIN_DECK + POOP_DECK) / 2.0, 0.0, 0.3, POOP_DECK - MAIN_DECK, 2.0 * abs(_hull_point(STERN, 3.0)[2])),
             col(CASTLE_FRONT, (MAIN_DECK + CASTLE_DECK) / 2.0, (w + DOOR[0] / 2.0) / 2.0, 0.2, CASTLE_DECK - MAIN_DECK, w - DOOR[0] / 2.0),
             col(CASTLE_FRONT, (MAIN_DECK + CASTLE_DECK) / 2.0, -(w + DOOR[0] / 2.0) / 2.0, 0.2, CASTLE_DECK - MAIN_DECK, w - DOOR[0] / 2.0),
             col(CASTLE_FRONT, (MAIN_DECK + DOOR[1] + CASTLE_DECK) / 2.0, 0.0, 0.2, CASTLE_DECK - MAIN_DECK - DOOR[1], DOOR[0]),
             col((STERN + CASTLE_FRONT) / 2.0, CASTLE_DECK - 0.05, 0.0, CASTLE_FRONT - STERN, 0.1, 2.0 * abs(_inside(-9.0, CASTLE_DECK)[2])),
             col((STERN + POOP_FRONT) / 2.0, (CASTLE_DECK + POOP_DECK) / 2.0, 0.0, POOP_FRONT - STERN, POOP_DECK - CASTLE_DECK,
                 2.0 * abs(_inside(-13.0, POOP_DECK)[2]))]
    # The breastworks: the aftcastle's (gaps at the ladders' heads), the
    # poop's (a gap at its ladder), the forecastle's (one at its ladder).
    w = abs(_inside(CASTLE_FRONT, CASTLE_RAIL)[2])

    for z0, z1 in ((-w, -3.05), (-1.75, 1.75), (3.05, w)):
        cols.append(col(CASTLE_FRONT + 0.06, (CASTLE_DECK + CASTLE_RAIL) / 2.0, (z0 + z1) / 2.0, 0.2, CASTLE_RAIL - CASTLE_DECK, z1 - z0))

    w = abs(_inside(POOP_FRONT, POOP_RAIL)[2])

    for z0, z1 in ((-w, 1.05), (2.15, w)):
        cols.append(col(POOP_FRONT + 0.06, (POOP_DECK + POOP_RAIL) / 2.0, (z0 + z1) / 2.0, 0.2, POOP_RAIL - POOP_DECK, z1 - z0))

    rail = _poop_top(STERN) + POOP_RAIL - POOP_SOLID
    w = abs(_hull_point(STERN, rail)[2])
    cols.append(col(STERN + 0.1, (POOP_DECK + rail) / 2.0, 0.0, 0.25, rail - POOP_DECK, 2.0 * w))
    w = _fore_half(FORE_BACK, FORE_RAIL)

    for z0, z1 in ((-w, -0.65), (0.65, w)):
        cols.append(col(FORE_BACK + 0.06, (FORE_DECK + FORE_RAIL) / 2.0, (z0 + z1) / 2.0, 0.2, FORE_RAIL - FORE_DECK, z1 - z0))

    # The forecastle's deck over the bow and its nose.
    cols += [col(15.4, FORE_DECK - 0.1, 0.0, 2.0, 0.2, 2.0 * _fore_half(15.4) - 0.5), col(17.1, FORE_DECK - 0.1, 0.0, 1.4, 0.2, 2.0 * _fore_half(17.1) - 0.3)]
    # On the deck: the boat on its hatch, the capstan, the bitts, the pump.
    y = MAIN_DECK
    cols += [col(4.1, y + 0.55, 0.75, 4.7, 1.1, 1.75), col(-3.4, y + 0.5, 1.3, 1.0, 1.0, 1.0), col(0.85, y + 0.55, 0.6, 0.3, 1.1, 0.3),
             col(0.85, y + 0.55, -0.6, 0.3, 1.1, 0.3), col(-1.9, y + 0.5, 1.45, 0.35, 1.0, 0.35), col(-12.0, 2.4, 0.0, 1.8, 0.84, 1.0)]
    return cols


def _carrack_hull():
    shapes = _skin() + _decks() + _bulwarks() + _sides() + _castles() + _forecastle() + _stern() + _waist()

    # Ladders up to the aftcastle's deck, the forecastle's, and (last, so the
    # others keep their markers' names) the poop's from the aftcastle's.
    climbs = []

    for z in (2.4, -2.4):
        shapes += _ladder(-5.7, MAIN_DECK, CASTLE_DECK + 0.3, z, 90.0)
        climbs.append([-5.6, (MAIN_DECK + CASTLE_DECK + 0.3) / 2.0, z, 0.8, CASTLE_DECK + 0.3 - MAIN_DECK, 0.5, 90.0])

    shapes += _ladder(7.7, MAIN_DECK, FORE_DECK + 0.3, 0.0, -90.0)
    climbs.append([7.6, (MAIN_DECK + FORE_DECK + 0.3) / 2.0, 0.0, 0.8, FORE_DECK + 0.3 - MAIN_DECK, 0.5, -90.0])
    shapes += _ladder(POOP_FRONT + 0.3, CASTLE_DECK, POOP_DECK + 0.3, 1.6, 90.0)
    climbs.append([POOP_FRONT + 0.4, (CASTLE_DECK + POOP_DECK + 0.3) / 2.0, 1.6, 0.8, POOP_DECK + 0.3 - CASTLE_DECK, 0.5, 90.0])
    # The rope ladder down the starboard waist into the sea: up it from the
    # water, over the bulwark onto the deck.
    shapes += _jacob()
    # (Upright, its wall the hull: the climber is held off the hull itself,
    # in and out with the wales the ladder rests on.)
    x, _, deep = JACOB
    top = _waist_top(x) + 0.3
    climbs.append([x, (deep - 0.3 + top) / 2.0, 4.45, 0.8, top - deep + 0.3, 0.6, 0.0])
    return shapes, _hull_cols(), climbs


def _drape_at(y):
    """How far out the rope ladder hangs at height y (JACOB_DRAPE)."""
    for (ya, za), (yb, zb) in zip(JACOB_DRAPE, JACOB_DRAPE[1:]):
        if yb <= y <= ya:
            return za + (zb - za) * (ya - y) / (ya - yb)

    return JACOB_DRAPE[0][1] if y > JACOB_DRAPE[0][0] else JACOB_DRAPE[-1][1]


def _jacob():
    """The rope ladder over the starboard waist (JACOB): its two ropes lying
    over the rail's cap and down the side along JACOB_DRAPE into the water,
    wooden rungs between them on that line."""
    x, every, deep = JACOB
    shapes = []

    for dx in (-0.22, 0.22):
        line = [[x + dx, 3.09, 4.02]] + [[x + dx, y, z] for y, z in JACOB_DRAPE]

        for a, b in zip(line, line[1:]):
            shapes += _rope(a, b, 0.025, "rope", 3)

    y = _waist_top(x) - every

    # (Rungs down to a swimmer's reach under the surface, its ropes deeper.)
    while y > deep + 0.4:
        z = _drape_at(y)
        shapes += _rope([x - 0.25, y, z], [x + 0.25, y, z], 0.03, "wood_old", 3)
        y -= every

    return shapes


# ---------------------------------------------------------------------------
# The carrack's rig: fore and main square-rigged with topmasts, a lateen
# mizzen and bonaventure, the bowsprit and its spritsail yard; the sails
# furled on their yards (the main yard is its own piece). Tops are tubs
# (their sides fore and aft, open over the shrouds where the climbs come
# up and the main yard leads off).
# ---------------------------------------------------------------------------

# Each mast: its x, its foot, its lower masthead, its radius at the foot and
# at the head; the top on it (height, radius, its tub's sides' half arc fore
# and aft, or 180: all round); the topmast (x, heel, head, radius) and the
# height of its own small top.
MASTS = {"main": (0.0, MAIN_DECK, 21.6, 0.38, 0.27, (TOP, TOP_RADIUS, 26.0), (0.6, 19.8, 30.6, 0.21), 27.6),
         "fore": (10.0, FORE_DECK, 17.5, 0.3, 0.22, (16.0, 1.45, 22.0), (10.5, 15.8, 24.4, 0.16), 22.4),
         "mizzen": (-9.0, CASTLE_DECK, 16.2, 0.24, 0.16, (14.5, 0.8, 180.0), None, None),
         "bonaventure": (-13.9, POOP_DECK, 15.2, 0.17, 0.12, None, None, None)}
# The shrouds' heads: how high under the top, how far out from the mast,
# their spread fore and aft.
HEADS = {"main": (TOP - 0.45, 1.35, 1.2), "fore": (15.55, 1.15, 0.9), "mizzen": (14.3, 0.6, 0.5)}
# A climber on a shroud climb's front hangs this far out from its plane
# (the player's capsule's radius and its gap, PlayerController/ClimbVolume);
# how deep a shroud climb's box is (either side of its plane: it takes hold
# of a man on the deck at the bulwark, behind it).
CLIMBER_OUT = 0.58
SHROUD_DEPTH = 3.4


def _shroud_climb(x, width, foot, low, top, side):
    """An open climb leaning up a set of shrouds on one side (`side` +1 the
    ship's +z): its plane through the shrouds at `foot` (y, out from the
    middle line), down to the deck at `low`, up to `top` (y, out), out past
    the shrouds' heads there, so a climber on its front comes up clear of the
    top's edge and mantles onto it. Ratlines are climbed from behind too
    (from the deck): round to the front near the top (ClimbVolume.open).
    [x, y, z, size x, y, z, yaw, pitch, props] about `x`, `width` wide."""
    (fy, fz), (ty, tz) = foot, top
    lean = math.atan2(fz - tz, ty - fy)
    bottom = fz + (fy - low) * math.tan(lean)
    length = (ty - low) / math.cos(lean)
    return [x, (low + ty) / 2.0, side * (bottom + tz) / 2.0, width, length, SHROUD_DEPTH, 0.0 if side > 0 else 180.0,
            -math.degrees(lean), {"open": True}]


def _shroud_foot(mast, x):
    """Where a mast's shrouds leave their upper deadeyes (y, out) at x."""
    p = _foot(mast, x, 1.0)
    return p[1] + DEADEYE, p[2]


def _yard(path, radius, sail, slot="hull_bare"):
    """A yard along `path` (its arms to its middle, thicker where two spars
    are fished), its sail furled under it in a lumpy bundle lashed with
    gaskets (`sail` the bundle's thickness at its middle, 0 for none)."""
    a, b = path[0], path[-1]
    points = [_lerp(a, b, t) for t in (0.0, 0.2, 0.5, 0.8, 1.0)]
    shapes = _tube(points, [radius * 0.55, radius * 0.85, radius, radius * 0.85, radius * 0.55], slot, 8)

    if sail > 0.0:
        run = _unit(_sub(b, a))
        down = _unit(_sub([0.0, -1.0, 0.0], _mul(run, -run[1])))
        ts = [0.04 + 0.92 * i / 10.0 for i in range(11)]
        bundle = [_add(_lerp(a, b, t), _mul(down, radius + sail * (0.55 + 0.25 * math.sin(math.pi * t)))) for t in ts]
        radii = [sail * (0.45 + 0.55 * math.sin(math.pi * t)) * (1.08 if i % 2 else 0.94) for i, t in enumerate(ts)]
        shapes += _tube(bundle, radii, "sailcloth", 6)

        for i in (2, 5, 8):
            p, r = bundle[i], radii[i] + 0.03
            shapes += _tube([_add(p, _mul(run, -0.05)), _add(p, _mul(run, 0.05))], r, "rope", 6, caps=False)

    return shapes


def _tub(x, y, radius, arc, slot="hull_bare", shields=True):
    """A top: its floor (a shallow bowl underneath) and, fore and aft, a
    tub's sides `arc` degrees either way hung with pavises; a low rim all
    round; the trestle- and crosstrees under it."""
    shapes = [ks.lathe(x, y - 0.42, 0.0, [[0.3, 0.0], [radius - 0.1, 0.3], [radius + 0.06, 0.42]], 10, slot, caps=False),
              ks.disc(x, y + 0.004, 0.0, radius, 10, "boards", pitch=-90.0),
              ks.lathe(x, y - 0.06, 0.0, [[radius + 0.06, 0.0], [radius + 0.08, 0.24], [radius - 0.02, 0.24]], 10, "timber", caps=False)]

    for middle in (0.0, 180.0) if arc < 90.0 else (90.0,):
        a0, a1 = middle - arc, middle + arc
        shapes += _arc(x, y, 0.0, radius - 0.05, radius + 0.04, 0.9, a0, a1, max(3, min(10, int(arc / 9.0))), slot, flare=0.12)

        for i in range((3 if arc < 90.0 else 6) if shields else 0):
            angle = math.radians(a0 + (a1 - a0) * (i + 0.5) / (3 if arc < 90.0 else 6))
            out = [math.cos(angle), 0.0, math.sin(angle)]
            centre = _add([x, y + 0.5, 0.0], _mul(out, radius + 0.17))
            shapes.append(ks.disc(centre[0], centre[1], centre[2], min(0.3, radius * 0.4), 6, "shield_%d" % (1 + i % 3),
                                  math.degrees(math.atan2(out[0], out[2])), -7.0))

    for dz in (-0.45, 0.45):
        shapes.append(ks.box(x, y - 0.5, dz, 2.0 * radius - 0.3, 0.18, 0.2, "timber"))

    for dx in (-0.7, 0.7):
        shapes.append(ks.box(x + dx * radius / 1.6, y - 0.32, 0.0, 0.2, 0.16, 2.0 * radius - 0.2, "timber"))

    return shapes


def _tub_cols(x, y, radius, arc):
    """The top's floor and its sides' colliders, a box to each third of a
    side's arc."""
    cols = [col(x, y - 0.05, 0.0, 2.0 * radius - 0.2, 0.1, 2.0 * radius - 0.2)]

    for middle in (0.0, 180.0):
        for k in range(3):
            angle = middle - arc + 2.0 * arc * (k + 0.5) / 3.0
            r = math.radians(angle)
            chord = 2.0 * radius * math.sin(math.radians(arc / 3.0))
            cols.append(col(x + radius * math.cos(r), y + 0.45, radius * math.sin(r), chord, 0.9, 0.12, -90.0 - angle))

    return cols


def _masts():
    """Each mast: tapering, rope woldings round its lower part, cheeks under
    its top; the topmast in its cap ahead of the lower masthead."""
    shapes = []

    for name, (x, foot, head, r0, r1, top, topmast, nest) in MASTS.items():
        shapes += _tube([[x, foot - 0.1, 0.0], [x, (foot + head) / 2.0, 0.0], [x, head, 0.0]], [r0, (r0 + r1) / 2.0 + 0.02, r1], "hull_bare", 8)

        for i in range(1, 6 if name == "main" else 4):
            y = foot + 0.9 + i * 1.3
            r = r0 + (r1 - r0) * (y - foot) / (head - foot) + 0.035
            shapes += _tube([[x, y, 0.0], [x, y + 0.16, 0.0]], r, "rope", 8, caps=False)

        if top is not None:
            ty, radius, arc = top
            shapes.append(ks.box(x, ty - 1.9, 0.0, 0.5, 2.6, 2.0 * r1 + 0.2, "timber"))
            shapes += _tub(x, ty, radius, arc)

        if topmast is not None:
            tx, heel, tip, r = topmast
            shapes += _tube([[tx, heel, 0.0], [tx, tip, 0.0]], [r, r * 0.6], "hull_bare", 6)
            shapes.append(ks.box((x + tx) / 2.0, head - 0.15, 0.0, tx - x + 0.75, 0.3, 0.6, "timber"))
            shapes.append(ks.lathe(tx, nest, 0.0, [[0.25, 0.0], [0.7, 0.25], [0.78, 0.75], [0.7, 0.75]], 8, "hull_bare", caps=False))
            shapes.append(ks.disc(tx, nest + 0.26, 0.0, 0.66, 8, "boards", pitch=-90.0))
            shapes += _tube([[tx, tip, 0.0], [tx, tip + 2.2, 0.0]], [r * 0.5, r * 0.25], "hull_bare", 4)

    # The bowsprit from the forecastle out over the nose, lashed down.
    heel, end = [12.6, FORE_DECK + 0.3, 0.0], [27.2, 12.4, 0.0]
    shapes += _tube([heel, _lerp(heel, end, 0.4), end], [0.34, 0.3, 0.15], "hull_bare", 8)

    for t in (0.37, 0.4, 0.43):
        p = _lerp(heel, end, t)
        shapes += _tube([[p[0], p[1] + 0.4, 0.0], [p[0] - 0.4, p[1] - 1.6, 0.0]], 0.06, "rope", 3, caps=False)

    return shapes


def _foot(mast, x, side):
    """A shroud's upper deadeye (over its lower one on the channel)."""
    p = _channel_point(mast, x, side)
    return [p[0], p[1] + 0.62, p[2]]


def _shrouds(mast, side):
    """A mast's shrouds on one side: upper deadeyes and lanyards to the
    channel's, each shroud up to under its top, our painted ratlines
    between each pair (a strip of the painting between two of its shrouds,
    so the modelled shrouds are the only ones seen)."""
    feet, _, _ = CHANNELS[mast]
    y_head, out, spread = HEADS[mast]
    x0 = MASTS[mast][0]
    lines = []
    shapes = []

    for i, x in enumerate(feet):
        foot = _foot(mast, x, side)
        head = [x0 - spread / 2.0 + spread * i / (len(feet) - 1), y_head, side * out]
        lines.append((_add(foot, [0.0, DEADEYE, 0.0]), head))
        shapes.append(ks.prism(foot[0], foot[1], foot[2], DEADEYE, 0.12, 5, "beam", pitch=90.0))
        shapes += _rope(_channel_point(mast, x, side), foot, 0.03, "rope", 3)
        shapes += _rope(lines[-1][0], head, 0.035, "pitch", 3)

    low, high = lines[0][0][1] + 0.9, y_head - 0.5

    def at(line, y):
        a, b = line
        return _lerp(a, b, (y - a[1]) / (b[1] - a[1]))

    for a, b in zip(lines, lines[1:]):
        quad = [at(a, low), at(b, low), at(b, high), at(a, high)]
        rise = math.dist(quad[0], quad[3]) / 5.4
        shapes.append(_face(quad, "ratlines", [0.0, 0.0, side], [[0.53, rise], [0.575, rise], [0.575, 0.0], [0.53, 0.0]]))

    # The futtock shrouds from the top's rim in to the mast under it.
    if mast in ("main", "fore"):
        ty, radius = MASTS[mast][5][0], MASTS[mast][5][1]

        for i in range(4):
            x = x0 - radius * 0.5 + radius * i / 3.0
            shapes += _rope([x, ty - 0.1, side * radius * 0.92], [x0 + (x - x0) * 0.3, ty - 2.0, side * 0.32], 0.03, "pitch", 3)

    return shapes


def _carrack_rig():
    shapes = _masts() + _chains()

    for side in (1.0, -1.0):
        for mast in ("main", "fore", "mizzen"):
            shapes += _shrouds(mast, side)

        # The topmasts' shrouds, from the tops' rims at the ends of their
        # sides (clear of the climbs' way up) to the topmasts' heads.
        for mast in ("main", "fore"):
            x, _, _, _, _, (ty, radius, arc), (tx, _, tip, _), _ = MASTS[mast]

            for middle in (0.0, 180.0):
                angle = math.radians(middle + side * (arc + 4.0) if middle == 0.0 else middle - side * (arc + 4.0))
                rim = [x + radius * math.cos(angle), ty + 0.9, radius * math.sin(angle)]
                shapes.append(ks.prism(rim[0], rim[1], rim[2], 0.09, 0.08, 5, "beam", pitch=90.0))
                shapes += _rope(rim, [tx, tip - 1.4, side * 0.18], 0.03, "pitch", 3)

        # The bonaventure's shrouds to the poop's rail.
        for x in (-14.6, -13.5):
            rail = _poop_top(x) + POOP_RAIL - POOP_SOLID
            z = side * (abs(_hull_point(x, rail)[2]) + 0.12)
            shapes += _rope([x, rail, z], [-13.9, 14.2, side * 0.18], 0.03, "pitch", 3)

    # Stays: the main (heavy, to the stem beside the foremast), the fore to
    # the bowsprit, the topmasts' forward, the mizzen's and bonaventure's.
    shapes += _rope([0.25, TOP - 0.6, 0.0], [16.4, 7.9, 0.95], 0.08, "pitch", 6)
    shapes.append(ks.prism(1.0, TOP - 1.1, 0.04, 0.17, 0.5, 6, "pitch", roll=53.0))
    shapes += _rope([10.25, 15.4, 0.0], [21.0, 9.9, 0.0], 0.07, "pitch", 5)
    shapes += _rope([0.7, 29.6, 0.0], [10.0, 16.9, 0.0], 0.04, "pitch", 3)
    shapes += _rope([10.6, 23.6, 0.0], [26.4, 12.1, 0.0], 0.035, "pitch", 3)
    shapes += _rope([-8.8, 15.3, 0.0], [-0.45, 4.0, 0.0], 0.045, "pitch", 3)
    shapes += _rope([-13.7, 14.6, 0.0], [-9.2, 9.0, 0.0], 0.035, "pitch", 3)
    # Crowsfeet: from the main top's rim fanned down to the mainstay.
    stay = _lerp([0.25, TOP - 0.6, 0.0], [16.4, 7.9, 0.95], 0.26)

    for k in range(-3, 4):
        angle = math.radians(k * 11.0)
        shapes += _rope([TOP_RADIUS * math.cos(angle), TOP - 0.1, TOP_RADIUS * math.sin(angle)], stay, 0.015, "rope", 3)

    stay = _lerp([10.25, 15.4, 0.0], [21.0, 9.9, 0.0], 0.3)

    for k in range(-2, 3):
        angle = math.radians(k * 12.0)
        shapes += _rope([10.0 + 1.3 * math.cos(angle), 15.9, 1.3 * math.sin(angle)], stay, 0.015, "rope", 3)

    # The yards: the fore course and both topsails, the spritsail under the
    # bowsprit's end, the lateens of the mizzen and bonaventure.
    shapes += _yard([[10.45, 14.6, -8.5], [10.45, 14.6, 8.5]], 0.2, 0.34)
    shapes += _yard([[0.95, 26.6, -6.0], [0.95, 26.6, 6.0]], 0.15, 0.24)
    shapes += _yard([[10.8, 21.4, -4.2], [10.8, 21.4, 4.2]], 0.12, 0.19)
    shapes += _yard([[23.6, 9.2, -4.5], [23.6, 9.2, 4.5]], 0.13, 0.22)
    mizzen = (-9.3, 12.0)
    shapes += _yard([[mizzen[0] + 4.6, mizzen[1] - 5.4, 0.3], [mizzen[0] - 4.6, mizzen[1] + 5.4, 0.3]], 0.15, 0.26)
    shapes += _yard([[-11.4, 10.6, 0.25], [-16.6, 15.3, 0.25]], 0.1, 0.17)

    # Running rigging: lifts from the mastheads to the yardarms (only the
    # main yard's to its south arm: its north arm is walked), braces aft,
    # the main yard's tie and jeers down to the bitts.
    for side in (1.0, -1.0):
        shapes += _rope([10.1, 17.3, side * 0.25], [10.45, 14.75, side * 8.3], 0.022, "rope", 3)
        shapes += _rope([0.75, 30.2, side * 0.15], [0.95, 26.7, side * 5.8], 0.02, "rope", 3)
        shapes += _rope([10.6, 24.1, side * 0.12], [10.8, 21.5, side * 4.0], 0.018, "rope", 3)
        shapes += _rope([10.45, 14.5, side * 8.4], [2.0, 16.4, side * 0.5], 0.022, "rope", 3, sag=0.25, steps=3)
        shapes += _rope([MAIN_YARD_X, 17.85, side * 12.5], [-14.6, POOP_RAIL + 0.3, side * 2.6], 0.025, "rope", 3, sag=0.35, steps=3)
        shapes += _rope([0.95, 26.5, side * 5.9], [-9.0, 15.0, side * 0.6], 0.02, "rope", 3, sag=0.3, steps=3)
        shapes += _rope([23.6, 9.1, side * 4.4], [15.6, 7.9, side * 1.4], 0.02, "rope", 3, sag=0.2, steps=2)
        shapes += _rope([0.45, TOP - 0.7, side * 0.25], [0.85, MAIN_DECK + 1.1, side * 0.6], 0.03, "rope", 3)

    shapes += _rope([0.0, 21.5, 0.3], [MAIN_YARD_X, 18.15, 12.4], 0.025, "rope", 3)
    # (The tie from the yard's middle up to the masthead.)
    shapes += _rope([MAIN_YARD_X - 0.2, 18.2, 0.0], [0.42, TOP - 0.3, 0.0], 0.07, "rope", 4)
    # A long streamer from the main topmast, the banner of the castle on
    # the fore and mizzen.
    shapes += _streamer([0.6, 32.6, 0.0], 7.0, "cloth")
    shapes += _streamer([-9.0, 16.2, 0.0], 3.5, "cloth")
    shapes.append(ks.card(10.95, 25.5, 0.0, 0.8, 2.0, "banner"))

    cols = _tub_cols(0.0, *MASTS["main"][5]) + _tub_cols(10.0, *MASTS["fore"][5])
    cols += [col(0.0, 15.0, 0.0, 0.6, 26.0, 0.6), col(0.6, 25.2, 0.0, 0.4, 10.8, 0.4), col(10.0, 14.25, 0.0, 0.5, 15.5, 0.5),
             col(-9.0, 11.0, 0.0, 0.4, 12.0, 0.4)]
    # The climbs: up the shrouds in their lean, from the deck to the top,
    # its plane out past the shrouds' heads up there (at the top's edge, so
    # a climber on its front comes up clear of the top and within the
    # scanner's reach of its edge); no wider than the gap in the tub's
    # sides; the main's aft of the main yard (it hangs at MAIN_YARD_X), so no
    # climber's head meets it.
    climbs = []

    for side in (1.0, -1.0):
        climbs.append(_shroud_climb(-0.4, 1.4, _shroud_foot("main", -0.4), MAIN_DECK, (TOP, TOP_RADIUS), side))
        fore = MASTS["fore"][5]
        climbs.append(_shroud_climb(10.0, 1.2, _shroud_foot("fore", 10.0), FORE_DECK, (fore[0], fore[1]), side))

    return shapes, cols, climbs


def _streamer(at, length, slot):
    """A long pennant hanging from `at` and stirring a little."""
    shapes = []
    points = [[at[0] - length * t * 0.25, at[1] - length * t * 0.95, 0.35 * math.sin(t * 5.0)] for t in [i / 6.0 for i in range(7)]]
    widths = [0.5 * (1.0 - 0.8 * i / 6.0) for i in range(7)]

    for (a, wa), (b, wb) in zip(zip(points, widths), zip(points[1:], widths[1:])):
        shapes += _both([a, b, _add(b, [-wb, 0.0, 0.0]), _add(a, [-wa, 0.0, 0.0])], slot)

    return shapes


def _mainyard():
    """The main yard (26 m: its arm reaches over the sea wall's walk with
    the carrack alongside the quay), thick at its middle where its two
    spars are fished and bound, its top a beam to walk; its course furled
    under it in a great bundle, gaskets round it, the footrope sagging
    below on its forward side. Pivot: its middle, on the mast."""
    half = YARD / 2.0
    xs = [-half, -half * 0.6, -half * 0.25, 0.0, half * 0.25, half * 0.6, half]
    radii = [0.14, 0.2, 0.25, 0.27, 0.25, 0.2, 0.14]
    # (Its top kept level with the collider's: the beam walked.)
    shapes = _tube([[x, 0.25 - r, 0.0] for x, r in zip(xs, radii)], radii, "hull_bare", 8)

    for x in (-3.4, -1.9, 1.9, 3.4):
        r = 0.26
        shapes += _tube([[x - 0.06, 0.25 - r, 0.0], [x + 0.06, 0.25 - r, 0.0]], r + 0.03, "rope", 8, caps=False)

    shapes += _tube([[-0.25, -0.02, 0.0], [0.25, -0.02, 0.0]], 0.33, "rope", 8, caps=False)
    ts = [i / 12.0 for i in range(13)]
    bundle = [[-half * 0.94 + YARD * 0.94 * t, -0.25 - 0.32 * math.sin(math.pi * t), 0.06] for t in ts]
    sizes = [(0.16 + 0.24 * math.sin(math.pi * t)) * (1.1 if i % 2 else 0.92) for i, t in enumerate(ts)]
    shapes += _tube(bundle, sizes, "sailcloth", 6)

    for i in (2, 4, 6, 8, 10):
        p, r = bundle[i], sizes[i] + 0.035
        shapes += _tube([_add(p, [-0.05, 0.0, 0.0]), _add(p, [0.05, 0.0, 0.0])], r, "rope", 6, caps=False)

    for s in (1.0, -1.0):
        shapes += _rope([s * (half - 0.4), -0.05, 0.32], [s * 0.6, -0.05, 0.32], 0.025, "rope", 3, sag=0.85, steps=6)

        for x in (half * 0.33, half * 0.66):
            sag = 0.85 * 4.0 * (x / half) * (1.0 - x / half)
            shapes += _rope([s * x, 0.1, 0.18], [s * x, -0.05 - sag, 0.32], 0.015, "rope", 3)

        shapes.append(ks.box(s * (half - 0.25), 0.07, 0.0, 0.12, 0.12, 0.34, "beam"))

    return shapes, [col(0.0, 0.2, 0.0, YARD, 0.1, 0.45)]


_shapes, _cols, _climbs = _carrack_hull()
_ship("carrack_hull", "hull_tarred", _shapes, _cols, [36.6, 12.5, 10.6], 9000, _climbs)
k.PIECES["carrack_hull"]["door"] = list(DOOR)
_shapes, _cols, _climbs = _carrack_rig()
_ship("carrack_rig", "hull_bare", _shapes, _cols, [54.6, 28.5, 25.2], 7000, _climbs)
_shapes, _cols = _mainyard()
_ship("carrack_mainyard", "hull_bare", _shapes, _cols, [YARD, 1.2, 1.0], 600)


# ---------------------------------------------------------------------------
# A caravel (after the Vera Cruz and the Boa Esperança: 20 m, lateen-rigged
# on two masts raked forward, her yards longer than she is; an open low bow,
# the tolda aft over her tiller, a lookout's basket on the mainmast).
# ---------------------------------------------------------------------------

CV_STERN, CV_STEM, CV_KEEL, CV_TUCK = -10.0, 10.2, -2.5, -0.5
CV_DECK, CV_TOLDA, CV_FRONT = 1.5, 3.5, -6.0
CV_SOLID, CV_RAIL = 3.85, 4.4
# Her mainmast's foot (x), its rake forward; the lookout's basket on it.
CV_MAST, CV_RAKE, CV_NEST, CV_NEST_RADIUS = 1.0, 2.5, 13.0, 0.95
CV_ROWS = [CV_KEEL, -1.6, -0.9, CV_TUCK, -0.3, DRY, 0.5, 1.0, CV_DECK, 2.0, 2.6, 3.2]
CV_PARTS = [((CV_STERN, -9.0, -7.6, CV_FRONT), CV_SOLID), ((CV_FRONT, -4.0, -1.5, 1.0, 3.5, 5.5, 7.2, 8.4, 9.3, CV_STEM), None)]


def _cv_breadth(x):
    if x >= 2.0:
        return 3.0 * max(0.0, 1.0 - ((x - 2.0) / (CV_STEM - 2.0)) ** 1.8) ** 0.6

    if x >= -3.0:
        return 3.0

    return 3.0 - 0.6 * ((-3.0 - x) / 7.0) ** 1.5


def _cv_half(x, y):
    b = _cv_breadth(x)

    if y >= 0.5:
        return max(0.12, b - 0.3 * min(1.0, (y - 0.5) / 2.5) ** 1.4 * min(1.0, b / 2.4))

    t = min(1.0, (0.5 - y) / (0.5 - CV_KEEL))
    n = 2.1 - 0.8 * _smooth((x - 3.0) / 7.0) - 0.5 * _smooth((-5.0 - x) / 5.0)
    run = 1.0 - 0.6 * _smooth((-6.0 - x) / 4.0) * t ** 1.2
    return max(0.12, b * (1.0 - t ** n) ** (1.0 / n) * run)


def _cv_stem_x(y):
    return CV_STEM + 0.9 * (y / 2.9) ** 1.2 if y >= 0.0 else CV_STEM - 1.8 * (-y / -CV_KEEL) ** 1.6


def _cv_x(xr, y):
    bow = _smooth((xr - 4.0) / (CV_STEM - 4.0))
    stern = _smooth((-7.6 - xr) / 2.4)
    post = 0.6 * max(0.0, (CV_TUCK - y) / (CV_TUCK - CV_KEEL))
    return xr + (_cv_stem_x(y) - CV_STEM) * bow + post * stern


def _cv_point(xr, y, side=1.0):
    z = 0.12 if xr <= CV_STERN and y < CV_TUCK else _cv_half(xr, y)
    return [_cv_x(xr, y), y, side * z]


def _cv_inside(xr, y, side=1.0):
    p = _cv_point(xr, y, side)
    return [p[0], y, side * (abs(p[2]) - 0.16)]


def _cv_top(x):
    """Her sheer: low amidships, rising to her open bow and aft to the tolda."""
    return 2.3 + 0.65 * _smooth((x - 2.0) / (CV_STEM - 2.0)) + 0.2 * _smooth((-1.0 - x) / 5.0)


def _cv_mast_x(foot, y, rake):
    return foot[0] + (y - foot[1]) * math.tan(math.radians(rake))


def _caravel():
    shapes = []
    slot = lambda q: "limewash" if _mid(q)[1] < -0.3 else "pitch" if _mid(q)[1] < DRY else "hull_tarred" if _mid(q)[1] < 1.75 else "hull_bare"

    for stations, top in CV_PARTS:
        heights = [h for h in CV_ROWS if h < (top or 2.3) - 1e-6]

        for side in (1.0, -1.0):
            rows = [[_cv_point(xr, y, side) for y in heights + [top or _cv_top(xr)]] for xr in stations]
            shapes += _loft(rows, slot, lambda q, s=side: [0.0, -0.2, s])

    heights = [h for h in CV_ROWS if h >= CV_TUCK] + [CV_SOLID]

    for y0, y1, s in ((CV_TUCK, DRY, "pitch"), (DRY, CV_DECK, "hull_tarred"), (CV_DECK, CV_SOLID, "hull_bare")):
        band = [h for h in heights if y0 - 1e-6 <= h <= y1 + 1e-6]
        left = [_cv_point(CV_STERN, h) for h in band]
        shapes.append(_face(left + [[p[0], p[1], -p[2]] for p in reversed(left)], s, [-1.0, 0.0, 0.0]))

    stem = [[_cv_stem_x(y) + 0.02, y, 0.0] for y in (CV_KEEL, -1.2, 0.0, 1.2, 2.4, _cv_top(CV_STEM) + 0.45)]
    shapes += _tube(stem, 0.15, "hull_tarred", 4, turn=45.0)
    shapes += _sweep([[_cv_x(CV_STERN, CV_KEEL), CV_KEEL, 0.0], [_cv_stem_x(CV_KEEL), CV_KEEL, 0.0]],
                     [(-0.14, 0.0), (0.14, 0.0), (0.14, -0.3), (-0.14, -0.3)], "hull_tarred")

    for side in (1.0, -1.0):
        inward = [0.0, 0.0, -side]
        # Two light wales sweeping up to the bow.
        for middle, height, bow, stern in ((0.55, 0.18, 0.5, 0.3), (1.35, 0.16, 0.75, 0.45)):
            rings, axis = [], []

            for xr in (CV_STERN, -8.0, CV_FRONT, -3.0, 0.0, 3.0, 5.5, 7.2, 8.4, 9.3, CV_STEM):
                rise = ((xr - 2.0) / (CV_STEM - 2.0)) ** 2 * bow if xr > 2.0 else ((-2.0 - xr) / 8.0) ** 2 * stern if xr < -2.0 else 0.0
                y = middle + rise
                proud = 0.1 * (1.0 - 0.6 * _smooth((xr - 8.0) / 2.2))
                low, high = _cv_point(xr, y - height / 2.0, side), _cv_point(xr, y + height / 2.0, side)
                rings.append([low, _add(low, [0.0, 0.0, side * proud]), _add(high, [0.0, 0.0, side * proud]), high])
                axis.append(_lerp(low, high, 0.5))

            shapes += _rings(rings, axis, "timber", caps=True, closed=False)

        # The bulwarks inside: the waist's, the tolda's; caps, frames' heads.
        stations = list(CV_PARTS[1][0][:-1])
        rows = [[_cv_inside(xr, y, side) for y in (CV_DECK, (CV_DECK + _cv_top(xr)) / 2.0, _cv_top(xr))] for xr in stations]
        shapes += _loft(rows, "hull_bare", lambda q, n=inward: n)
        shapes += _sweep([_add(_cv_inside(xr, _cv_top(xr), side), [0.0, 0.0, side * 0.08]) for xr in stations],
                         [(-0.14, -0.05), (0.14, -0.05), (0.14, 0.05), (-0.14, 0.05)], "timber", flip=side)
        stern = list(CV_PARTS[0][0])
        rows = [[_cv_inside(xr, y, side) for y in (CV_TOLDA, CV_SOLID)] for xr in stern]
        shapes += _loft(rows, "hull_bare", lambda q, n=inward: n)
        shapes += _open_tier([_add(_cv_inside(xr, CV_SOLID, side), [0.0, 0.0, side * 0.08]) for xr in stern], CV_SOLID, CV_RAIL, side,
                             shields=False, every=0.8)

        for i in range(1, 14):
            x = CV_FRONT + (8.6 - CV_FRONT) * i / 14.0
            z = abs(_cv_inside(x, 2.0)[2]) - 0.06
            shapes += _stud(x, CV_DECK, _cv_top(x) - 0.05, side * z, 0.12, "timber", inward)

        # Her shrouds' chains at the rail, the mainmast's set up with tackles.
        for x in (CV_MAST - 1.0, CV_MAST, CV_MAST + 1.0, -5.4, -4.4):
            z = side * (abs(_cv_point(x, 2.0)[2]) + 0.1)
            shapes.append(ks.box(x, 1.95, z, 0.12, 0.5, 0.05, "iron"))

    # The tolda: its deck, its front over the door to the steerage, the open
    # rail round it but for a gap in its front to climb up through, the
    # taffrail.
    w = abs(_cv_inside(CV_FRONT, CV_TOLDA)[2])
    shapes += _loft(_cv_deck_rows([CV_STERN + 0.16, -8.0, CV_FRONT], CV_TOLDA, 0.0, 2), "boards", lambda q: [0.0, 1.0, 0.0])
    shapes += _loft(_cv_deck_rows([CV_FRONT - 0.2, -3.0, 0.0, 3.0, 5.5, 7.2, 8.4, 9.3], CV_DECK, 0.05, 4), "boards", lambda q: [0.0, 1.0, 0.0])
    edge = [[CV_FRONT + 0.02, y, abs(_cv_point(CV_FRONT, y)[2])] for y in (CV_DECK, 2.3, CV_TOLDA)]
    shapes.append(_face(edge + [[p[0], p[1], -p[2]] for p in reversed(edge)], "hull_bare", [1.0, 0.0, 0.0]))
    shapes.append(ks.box(CV_FRONT + 0.05, CV_DECK + 0.98, 0.0, 0.06, 2.0, 1.15, "timber"))
    shapes.append(ks.card(CV_FRONT + 0.09, CV_DECK + 0.95, 0.0, 0.9, 1.85, "door_1", 90.0))
    shapes.append(ks.box(CV_FRONT + 0.1, CV_TOLDA - 0.08, 0.0, 0.2, 0.16, 2.0 * w + 0.3, "timber"))

    for z0, z1 in ((-w, -0.8), (0.8, w)):
        shapes += _open_tier([[CV_FRONT + 0.05, 0.0, z1], [CV_FRONT + 0.05, 0.0, z0]], CV_TOLDA, CV_RAIL, 1.0, shields=False, every=0.8)

    w = abs(_cv_point(CV_STERN, CV_SOLID)[2]) - 0.08
    shapes += _open_tier([[CV_STERN + 0.08, 0.0, w], [CV_STERN + 0.08, 0.0, -w]], CV_SOLID, CV_RAIL, -1.0, shields=False, every=0.8)

    for y in (DRY + 0.05, CV_DECK, CV_TOLDA):
        shapes.append(ks.box(CV_STERN - 0.04, y, 0.0, 0.1, 0.14, 2.0 * abs(_cv_point(CV_STERN, y)[2]) + 0.06, "timber"))

    for s in (1.0, -1.0):
        shapes.append(ks.box(CV_STERN - 0.02, 2.75, s * 0.8, 0.05, 0.6, 0.5, "timber"))
        shapes.append(ks.card(CV_STERN - 0.06, 2.75, s * 0.8, 0.36, 0.44, "glass_dark", 90.0))

    # Her rudder on its pintles; the iron the level's lantern hangs from.
    fwd = lambda y: _cv_x(CV_STERN, y) - 0.1 if y < CV_TUCK else CV_STERN - 0.1
    outline = [(fwd(-2.4), -2.4), (fwd(CV_TUCK), CV_TUCK), (CV_STERN - 0.1, 1.2), (CV_STERN - 0.42, 1.2), (CV_STERN - 0.6, DRY),
               (fwd(CV_TUCK) - 0.8, CV_TUCK), (fwd(-2.4) - 1.05, -2.3)]

    for z, out in ((0.11, 1.0), (-0.11, -1.0)):
        shapes.append(_face([[px, py, z] for px, py in outline], "timber", [0.0, 0.0, out]))

    for (ax, ay), (bx, by) in zip(outline, outline[1:] + outline[:1]):
        shapes.append(_face([[ax, ay, 0.11], [bx, by, 0.11], [bx, by, -0.11], [ax, ay, -0.11]], "timber", [by - ay, -(bx - ax), 0.0]))

    for y in (-1.9, -0.6, 0.6):
        shapes.append(ks.box(fwd(y) - 0.3, y, 0.0, 0.65, 0.08, 0.26, "iron"))

    shapes.append(_post(-9.72, CV_TOLDA, 5.15, 0.0, 0.07, "iron"))
    shapes.append(ks.box(-9.6, 5.1, 0.0, 0.3, 0.05, 0.05, "iron"))
    # Her deck beams' ends along her sides.
    for side in (1.0, -1.0):
        for x in (-8.6, -7.2, -4.6, -3.2, -1.8, 2.6, 4.0, 5.4, 6.8):
            y = 1.62 + (((x - 2.0) / (CV_STEM - 2.0)) ** 2 * 0.75 if x > 2.0 else ((-2.0 - x) / 8.0) ** 2 * 0.45 if x < -2.0 else 0.0)
            shapes += _block(x, y, side * (abs(_cv_point(x, y)[2]) + 0.02), 0.18, 0.18, 0.18, "beam", side)

    # The windlass in her bow between its bitts, a pump abaft the mast.
    shapes += _tube([[8.0, CV_DECK + 0.55, -1.0], [8.0, CV_DECK + 0.55, 1.0]], 0.22, "wood_old", 8)
    shapes += [ks.box(8.0, CV_DECK + 0.45, s * 1.1, 0.3, 0.9, 0.22, "beam") for s in (1.0, -1.0)]
    shapes.append(ks.prism(-0.6, CV_DECK + 0.45, -0.9, 0.14, 0.9, 6, "wood_old"))
    # On deck: a hatch, the firebox, casks, a coil, an anchor on the bow.
    shapes += [ks.box(3.4, CV_DECK + 0.12, s * 0.7, 1.7, 0.24, 0.12, "timber") for s in (1.0, -1.0)]
    shapes += [ks.box(3.4 + s * 0.8, CV_DECK + 0.12, 0.0, 0.12, 0.24, 1.3, "timber") for s in (1.0, -1.0)]
    shapes.append(ks.box(3.4, CV_DECK + 0.18, 0.0, 1.5, 0.08, 1.3, "boards"))
    shapes.append(ks.box(5.3, CV_DECK + 0.4, -1.1, 1.0, 0.8, 0.8, "wood_old"))
    shapes.append(ks.box(5.3, CV_DECK + 0.45, -0.69, 0.5, 0.35, 0.03, "pitch"))

    for x, z in ((-3.2, 2.2), (-2.5, 2.25)):
        shapes.append(ks.prism(x, CV_DECK + 0.38, z, 0.3, 0.76, 8, "wood_old", rings=[[0.5, 0.34]]))

    shapes.append(ks.disc(-1.5, CV_DECK + 0.05, -1.7, 0.4, 8, "rope_coil", pitch=-90.0))
    shapes += _anchor([8.9, 2.75, 1.9], [7.3, 1.0, 2.55])

    # The rig.
    rig, cols_rig, climbs = _caravel_rig()
    shapes += rig
    cols = [col(-2.0, (CV_DECK + CV_KEEL) / 2.0, 0.0, 12.0, CV_DECK - CV_KEEL, 5.6), col(5.5, (CV_DECK - 2.0) / 2.0, 0.0, 3.0, CV_DECK + 2.0, 4.6),
            col(8.0, (CV_DECK - 1.6) / 2.0, 0.0, 2.0, CV_DECK + 1.6, 3.0), col(9.4, (CV_DECK - 0.8) / 2.0, 0.0, 0.8, CV_DECK + 0.8, 1.4),
            col(-9.0, (CV_DECK + CV_KEEL + 0.6) / 2.0, 0.0, 2.0, CV_DECK - CV_KEEL - 0.6, 4.2),
            col((CV_STERN + CV_FRONT) / 2.0, (CV_DECK + CV_TOLDA) / 2.0, 0.0, CV_FRONT - CV_STERN, CV_TOLDA - CV_DECK, 2.0 * abs(_cv_inside(-8.0, CV_TOLDA)[2])),
            col(3.4, CV_DECK + 0.12, 0.0, 1.8, 0.24, 1.5), col(5.3, CV_DECK + 0.4, -1.1, 1.0, 0.8, 0.8), col(8.0, CV_DECK + 0.45, 0.0, 0.5, 0.9, 2.4)]

    for side in (1.0, -1.0):
        for a, b in ((CV_FRONT, -1.5), (-1.5, 3.5), (3.5, 7.2), (7.2, 9.3)):
            pa, pb = _cv_inside(a, 2.0, side), _cv_inside(b, 2.0, side)
            za, zb = pa[2] + side * 0.08, pb[2] + side * 0.08
            top = max(_cv_top(a), _cv_top(b))
            cols.append(col((pa[0] + pb[0]) / 2.0, (CV_DECK + top) / 2.0, (za + zb) / 2.0, math.hypot(pb[0] - pa[0], zb - za) + 0.05, top - CV_DECK, 0.2,
                            -math.degrees(math.atan2(zb - za, pb[0] - pa[0]))))

        z = side * (abs(_cv_inside(-8.0, CV_RAIL)[2]) + 0.08)
        cols.append(col((CV_STERN + CV_FRONT) / 2.0, (CV_TOLDA + CV_RAIL) / 2.0, z, CV_FRONT - CV_STERN, CV_RAIL - CV_TOLDA, 0.2))
        w = abs(_cv_inside(CV_FRONT, CV_TOLDA)[2])
        cols.append(col(CV_FRONT + 0.05, (CV_TOLDA + CV_RAIL) / 2.0, side * (w + 0.8) / 2.0, 0.15, CV_RAIL - CV_TOLDA, w - 0.8))

    cols.append(col(CV_STERN + 0.08, (CV_TOLDA + CV_RAIL) / 2.0, 0.0, 0.15, CV_RAIL - CV_TOLDA, 2.0 * abs(_cv_point(CV_STERN, CV_SOLID)[2])))
    return shapes, cols + cols_rig, climbs


def _cv_deck_rows(stations, y, camber, steps):
    rows = []

    for xr in stations:
        width = abs(_cv_inside(xr, y)[2])
        rows.append([[_cv_x(xr, y), y + camber * (0.5 - (2.0 * i / steps - 1.0) ** 2), width * (2.0 * i / steps - 1.0)] for i in range(steps + 1)])

    return rows


def _caravel_rig():
    """Her two masts raked forward, the lookout's basket at the main's head;
    the lateen yards, longer than she is, raked high aft with their sails
    furled along them; few shrouds, set up with tackles, ratlines on the
    main's; the stays and the halyards' tackles."""
    shapes = []
    main, mizzen = (CV_MAST, CV_DECK), (-4.8, CV_DECK)
    head = [_cv_mast_x(main, CV_NEST + 0.6, CV_RAKE), CV_NEST + 0.6, 0.0]
    nest = [_cv_mast_x(main, CV_NEST, CV_RAKE), CV_NEST, 0.0]

    for foot, top, r in ((main, CV_NEST + 1.4, 0.27), (mizzen, 11.6, 0.2)):
        tip = [_cv_mast_x(foot, top, CV_RAKE + 1.0 if foot is mizzen else CV_RAKE), top, 0.0]
        shapes += _tube([[foot[0], foot[1] - 0.1, 0.0], tip], [r, r * 0.6], "hull_bare", 8)

        for i in range(3):
            y = foot[1] + 1.0 + 1.3 * i
            x = _cv_mast_x(foot, y, CV_RAKE)
            shapes += _tube([[x, y, 0.0], [x, y + 0.15, 0.0]], r + 0.03, "rope", 8, caps=False)

    shapes += _tub(nest[0], nest[1], CV_NEST_RADIUS, 18.0, shields=False)
    shapes += _yard([[7.3, 4.5, 0.35], [-8.3, 20.1, 0.35]], 0.17, 0.3)
    shapes += _yard([[-1.0, 4.9, 0.3], [-11.6, 15.5, 0.3]], 0.13, 0.24)

    for side in (1.0, -1.0):
        feet = [CV_MAST - 1.0, CV_MAST, CV_MAST + 1.0]
        lines = []

        for x in feet:
            foot = [x, 2.2, side * (abs(_cv_point(x, 2.0)[2]) + 0.12)]
            block = [x, 2.95, foot[2]]
            shapes.append(ks.box(block[0], block[1], block[2], 0.14, 0.24, 0.1, "beam"))
            shapes += _rope(foot, [x, 2.82, foot[2]], 0.025, "rope", 3)
            top = [head[0] - 0.4 + 0.4 * (x - feet[0]), head[1] - 1.0, side * 0.75]
            lines.append(([x, 3.07, foot[2]], top))
            shapes += _rope(lines[-1][0], top, 0.03, "pitch", 3)

        def at(line, y):
            a, b = line
            return _lerp(a, b, (y - a[1]) / (b[1] - a[1]))

        for a, b in zip(lines, lines[1:]):
            quad = [at(a, 3.9), at(b, 3.9), at(b, CV_NEST - 0.6), at(a, CV_NEST - 0.6)]
            rise = math.dist(quad[0], quad[3]) / 5.4
            shapes.append(_face(quad, "ratlines", [0.0, 0.0, side], [[0.53, rise], [0.575, rise], [0.575, 0.0], [0.53, 0.0]]))

        for x in (-5.4, -4.4):
            foot = [x, 2.25, side * (abs(_cv_point(x, 2.0)[2]) + 0.12)]
            shapes += _rope(foot, [_cv_mast_x(mizzen, 10.4, CV_RAKE + 1.0), 10.4, side * 0.2], 0.025, "pitch", 3)

        shapes += _rope([7.3, 4.4, 0.35], [8.6, _cv_top(8.6), side * 1.4], 0.025, "rope", 3)

    # The forestay to her stem head, the mizzen's to the mainmast; the main
    # halyard's tackle down abaft the mast.
    stem = [_cv_stem_x(_cv_top(CV_STEM)), _cv_top(CV_STEM) + 0.35, 0.0]
    shapes += _rope(head, stem, 0.05, "pitch", 4)
    shapes += _rope([_cv_mast_x(mizzen, 11.2, CV_RAKE + 1.0), 11.2, 0.0], [_cv_mast_x(main, 6.0, CV_RAKE) - 0.25, 6.0, 0.0], 0.03, "pitch", 3)
    shapes += _rope([head[0] - 0.2, head[1] - 0.4, 0.2], [CV_MAST - 1.3, CV_DECK + 1.0, 0.3], 0.04, "rope", 3)
    shapes += _rope([CV_MAST - 1.3, CV_DECK + 1.0, 0.3], [CV_MAST - 1.4, CV_DECK + 0.1, 0.3], 0.04, "rope", 3)
    shapes.append(ks.box(CV_MAST - 1.3, CV_DECK + 1.05, 0.3, 0.16, 0.3, 0.12, "beam"))
    shapes += _streamer([head[0], CV_NEST + 3.5, 0.0], 4.5, "cloth")
    shapes += _tube([[head[0], CV_NEST + 1.4, 0.0], [head[0], CV_NEST + 3.6, 0.0]], [0.07, 0.04], "hull_bare", 4)
    cols = _tub_cols(nest[0], nest[1], CV_NEST_RADIUS, 18.0)
    cols += [col(CV_MAST + 0.25, (CV_DECK + CV_NEST) / 2.0, 0.0, 0.55, CV_NEST - CV_DECK, 0.55), col(-4.55, 6.5, 0.0, 0.45, 10.0, 0.45)]
    # Up her shrouds on the quay's side, in their lean, to a mantle into the
    # basket (its sides fore and aft, open over the shrouds).
    climbs = [_shroud_climb(nest[0], 1.0, (3.07, abs(_cv_point(nest[0], 2.0)[2]) + 0.12), CV_DECK, (CV_NEST, CV_NEST_RADIUS), 1.0)]
    return shapes, cols, climbs


# ---------------------------------------------------------------------------
# Open boats, clinker built (each strake's lower edge lapped over the one
# below, so its edges cast their lines), crescent sheers rising to the
# stem and stern posts; thwarts, frames, thole pins and oars, floor boards
# to stand on (their colliders are the water's test's, kept as they were).
# ---------------------------------------------------------------------------

def _clinker(stations, slots, inside="boards", lap=0.04):
    """An open boat's hull through `stations` [(x, [(z, y), ...] from the
    keel up to the gunwale on the +z side, a point at each strake's
    edge)], both sides: each strake above the bilge's lapped out over the
    one below it, `slots` one per strake from the keel up (a tarred bottom,
    painted bands); smooth within; a transom where the aftmost is wide, the
    gunwale capped."""
    shapes = []
    strakes = len(stations[0][1]) - 1

    for side in (1.0, -1.0):
        for k in range(strakes):
            lapped = k > 1
            rows = []

            for x, section in stations:
                (z0, y0), (z1, y1) = section[k], section[k + 1]
                rows.append([[x, y0 - (0.03 if lapped else 0.0), side * (z0 + (lap if lapped else 0.0))], [x, y1, side * z1]])

            shapes += _loft(rows, slots[k], lambda q, s=side: [0.0, -0.3, s])

            if lapped:
                rows = [[[x, section[k][1], side * section[k][0]], [x, section[k][1] - 0.03, side * (section[k][0] + lap)]] for x, section in stations]
                shapes += _loft(rows, slots[k], lambda q, s=side: [0.0, -1.0, 0.3 * s])

        inner = [[[x, y, side * max(0.0, z - 0.04)] for z, y in section] for x, section in stations]
        shapes += _loft(inner, inside, lambda q, s=side: [0.0, 0.3, -s])
        shapes += _sweep([[x, section[-1][1], side * (section[-1][0] - 0.02)] for x, section in stations],
                         [(-0.05, -0.05), (-0.05, 0.03), (0.05, 0.03), (0.05, -0.05)], "timber", flip=side, closed=False)

    x, section = stations[0]

    if section[-1][0] > 0.2:
        left = [[x, y, z] for z, y in section]
        outline = left + [[p[0], p[1], -p[2]] for p in reversed(left)]
        shapes += [_face(outline, slots[-2], [-1.0, 0.0, 0.0]), _face(outline, inside, [1.0, 0.0, 0.0])]

    return shapes


def _inner_half(section, y):
    """How far out a boat's inside is at height y in its section."""
    for (z0, y0), (z1, y1) in zip(section, section[1:]):
        if y0 <= y <= y1:
            return z0 + (z1 - z0) * (y - y0) / max(1e-6, y1 - y0) - 0.05

    return 0.0


def _floor(stations, y, slot="boards"):
    """Floor boards at y, out to the boat's insides."""
    edge = [[x, y, _inner_half(section, y)] for x, section in stations]
    edge = [p for p in edge if p[2] > 0.08]
    return _face(edge + [[p[0], p[1], -p[2]] for p in reversed(edge)], slot, [0.0, 1.0, 0.0])


def _boat_section(u, half, bottom, keel, gunwale, strakes):
    """A boat's section at u (-1 its stern, 1 its bow): the keel, the turn
    of the bilge, its strakes' edges up to the gunwale."""
    points = [(0.04, keel), (max(0.04, bottom), keel + 0.1)]

    for k in range(1, strakes):
        t = k / float(strakes)
        points.append((bottom + (half - bottom) * t ** 0.6, keel + 0.1 + (gunwale - keel - 0.1) * t))

    return points + [(half, gunwale)]


def _oar(a, b, slot="timber"):
    """An oar from its loom's end a to its blade's tip b."""
    run = _unit(_sub(b, a))
    blade = _add(b, _mul(run, -0.45))
    yaw = -math.degrees(math.atan2(run[2], run[0]))
    middle = _add(blade, _mul(run, 0.22))
    return _tube([a, blade], 0.035, slot, 3) + [_card(middle[0], middle[1], middle[2], 0.5, 0.15, slot, yaw, -90.0)]


def _rowboat():
    """A harbour boat: a narrow transom, her sheer rising to the stem, three
    strakes over the bilge's, the top one painted; two thwarts, floor
    boards, thole pins, a pair of oars."""
    def section(u):
        bow = u > 0.0
        half = 0.76 * (1.0 - (abs(u) ** 2.2 if bow else 0.5 * abs(u) ** 2.2)) ** 0.6
        bottom = 0.48 * (1.0 - u * u) if bow else 0.48 - 0.26 * u * u
        return _boat_section(u, max(0.04, half), max(0.04, bottom), -0.36 + 0.3 * u * u, 0.6 + (0.38 if bow else 0.2) * abs(u) ** 1.8, 3)

    stations = [(2.25 * u, section(u)) for u in (-1.0, -0.5, 0.1, 0.65, 1.0)]
    shapes = _clinker(stations, ["hull_tarred", "hull_tarred", "hull_bare", "render_blue"])
    shapes.append(_floor(stations, -0.12))
    shapes += [ks.box(x, 0.24, 0.0, 0.22, 0.05, 1.42, "boards") for x in (-0.9, 0.55)]
    shapes += _tube([[2.15, -0.1, 0.0], [2.27, 0.45, 0.0], [2.3, 1.06, 0.0]], 0.05, "timber", 3)

    for x in (-0.25, 1.15):
        for s in (1.0, -1.0):
            shapes.append(ks.prism(x, 0.7, s * 0.74, 0.025, 0.2, 3, "wood_old", caps=False))

    shapes += _oar([-1.6, 0.3, 0.42], [1.7, 0.36, 0.3]) + _oar([-1.5, 0.33, -0.4], [1.8, 0.4, -0.25])
    cols = [col(0.0, -0.17, 0.0, 3.2, 0.1, 1.0), col(0.0, 0.2, 0.68, 3.6, 0.8, 0.1), col(0.0, 0.2, -0.68, 3.6, 0.8, 0.1)]
    return shapes, cols


def _fishing_boat():
    """A meia-lua of the coast: flat-floored, her sheer a crescent up to a
    tall stem and a lower stern post, a stumpy mast with its lateen furled;
    nets, baskets and her oars aboard."""
    def section(u):
        half = 1.2 * max(0.0, 1.0 - abs(u) ** 2.2) ** 0.7
        bottom = 0.78 * max(0.0, 1.0 - abs(u) ** 1.8)
        return _boat_section(u, max(0.04, half), max(0.04, bottom), -0.75 + 0.5 * u * u, 0.95 + (1.05 if u > 0.0 else 0.55) * abs(u) ** 2.6, 4)

    stations = [(4.0 * u, section(u)) for u in (-1.0, -0.75, -0.35, 0.1, 0.5, 0.82, 1.0)]
    shapes = _clinker(stations, ["hull_tarred", "hull_tarred", "hull_bare", "straw", "cloth"])
    shapes.append(_floor(stations, -0.42))
    shapes += [ks.box(x, y, 0.0, 0.26, 0.05, 2.0 * w, "boards") for x, y, w in ((-2.0, 0.12, 1.02), (0.05, 0.05, 1.12), (1.9, 0.15, 1.02))]

    for x in (-2.8, -1.0, 1.0, 2.8):
        sec = section(x / 4.0)

        for s in (1.0, -1.0):
            frame = [[x, sec[1][1] + 0.05, s * (sec[1][0] - 0.06)], [x, sec[3][1], s * (sec[3][0] - 0.07)], [x, sec[-1][1] - 0.05, s * (sec[-1][0] - 0.07)]]
            shapes += _tube(frame, 0.04, "timber", 3, caps=False)

    shapes += _tube([[3.75, -0.3, 0.0], [4.04, 0.9, 0.0], [4.1, 2.3, 0.0]], 0.07, "timber", 4)
    shapes += _tube([[-3.75, -0.3, 0.0], [-4.04, 0.8, 0.0], [-4.08, 1.75, 0.0]], 0.07, "timber", 4)

    for x in (-0.9, 0.9):
        shapes.append(ks.prism(x, 1.05, 1.16, 0.03, 0.22, 3, "wood_old", caps=False))
        shapes.append(ks.prism(x, 1.05, -1.16, 0.03, 0.22, 3, "wood_old", caps=False))

    shapes += _tube([[0.7, -0.44, 0.0], [0.75, 4.6, 0.0]], [0.1, 0.06], "hull_bare", 6)
    shapes += _tube([[3.0, 1.2, 0.18], [-1.6, 5.4, 0.18]], [0.06, 0.05], "hull_bare", 4)
    bundle = [_lerp([2.7, 1.25, 0.18], [-1.3, 4.95, 0.18], t) for t in (0.0, 0.3, 0.65, 1.0)]
    shapes += _tube([_add(p, [0.06, -0.16, 0.0]) for p in bundle], [0.08, 0.17, 0.15, 0.07], "sailcloth", 6)
    shapes += _oar([-2.6, 0.2, 0.55], [2.9, 0.3, 0.75]) + _oar([-2.5, 0.25, -0.5], [3.0, 0.35, -0.7])
    shapes.append(ks.lathe(-2.6, -0.42, 0.1, [[0.55, 0.0], [0.45, 0.2], [0.18, 0.32], [0.0, 0.35]], 8, "rope"))
    shapes.append(ks.card(-2.6, -0.1, 0.1, 1.0, 0.9, "net", 15.0, -80.0))
    shapes.append(ks.card(-2.1, 0.2, 0.95, 1.2, 0.9, "net", 0.0, -35.0))

    for x, z in ((1.6, -0.45), (2.3, 0.4)):
        shapes.append(ks.lathe(x, -0.42, z, [[0.2, 0.0], [0.27, 0.32], [0.29, 0.38]], 6, "straw", caps=False))

    # Her floor, her sides following her round to the posts.
    cols = [col(0.0, -0.47, 0.0, 5.0, 0.1, 1.5)]

    for side in (1.0, -1.0):
        for a, b in ((-3.6, -1.4), (-1.4, 1.4), (1.4, 3.6)):
            za, zb = side * (abs(section(a / 4.0)[-1][0]) - 0.06), side * (abs(section(b / 4.0)[-1][0]) - 0.06)
            cols.append(col((a + b) / 2.0, 0.3, (za + zb) / 2.0, math.hypot(b - a, zb - za), 1.3, 0.12, -math.degrees(math.atan2(zb - za, b - a))))

    return shapes, cols


_shapes, _cols, _climbs = _caravel()
_ship("caravel", "hull_tarred", _shapes, _cols, [23.4, 22.0, 7.0], 4500, _climbs)
_shapes, _cols = _fishing_boat()
_ship("boat_fishing", "hull_bare", _shapes, _cols, [8.4, 5.4, 2.6], 900)
_shapes, _cols = _rowboat()
_ship("rowboat", "hull_bare", _shapes, _cols, [4.7, 1.4, 1.6], 350)


# ---------------------------------------------------------------------------
# The carrack's brow: a gangplank from the quay's edge (its pivot, z 0; the
# quay's top at 2.5) up over her waist's rail and down onto her deck (+z),
# cleats across its boards, rope handrails on stanchions; laid at her waist
# BROW_X along her, clear of the jump aboard. Her deck's way ashore (her
# castles' rails stop a guard's drop to the quay): without it her deck is
# an island and the deck watch is off the navmesh.
# ---------------------------------------------------------------------------

BROW_X = 2.5
BROW_WIDTH = 1.1
# Its line (z, top): off the quay, over her rail, down onto her deck.
BROW = [(-1.2, 2.5), (0.3, 3.2), (0.95, 3.2), (2.95, MAIN_DECK)]


def _slope(za, ya, zb, yb):
    """A run's length, its pitch (positive lowers its +z end), its middle."""
    return math.hypot(zb - za, yb - ya), math.degrees(math.atan2(ya - yb, zb - za)), (za + zb) / 2.0, (ya + yb) / 2.0


def _brow():
    shapes, cols = [], []
    thick = 0.1

    for (za, ya), (zb, yb) in zip(BROW, BROW[1:]):
        length, pitch, cz, cy = _slope(za, ya, zb, yb)
        cy -= thick / 2.0 / math.cos(math.radians(pitch))
        shapes.append(ks.box(0.0, cy, cz, BROW_WIDTH, thick, length + 0.02, "boards", 0.0, pitch))
        cols.append(col(0.0, cy, cz, BROW_WIDTH, thick, length + 0.02, 0.0, pitch))

        for i in range(1, int(length / 0.35)):
            f = i * 0.35 / length
            shapes.append(ks.box(0.0, ya + (yb - ya) * f + 0.02, za + (zb - za) * f, BROW_WIDTH - 0.12, 0.04, 0.05, "timber", 0.0, pitch))

    posts = [(-1.05, 2.5), (0.62, 3.2), (2.75, MAIN_DECK + 0.12)]

    for s in (-1.0, 1.0):
        x = s * (BROW_WIDTH / 2.0 - 0.04)

        for z, y in posts:
            shapes.append(ks.box(x, y + 0.45, z, 0.06, 0.9, 0.06, "timber"))

        for (za, ya), (zb, yb) in zip(posts, posts[1:]):
            length, pitch, cz, cy = _slope(za, ya, zb, yb)
            shapes.append(ks.box(x, cy + 0.86, cz, 0.035, 0.035, length, "rope", 0.0, pitch))

    return shapes, cols


_shapes, _cols = _brow()
_ship("carrack_brow", "boards", _shapes, _cols, [1.4, 4.2, 8.6], 300)
