"""The harbour's ships (kit v1): a carrack (its hull with the castles fore
and aft and the captain's cabin, its rig with a fighting top to climb up
to, its main yard apart so the level can brace it), a lateen caravel, a
fishing boat and a rowboat. Pure data, as kit_recipes (which imports this at
its end).

A ship's pivot is at the waterline under its mainmast, its bow to +x. Hulls
are lofted from stations along x (each a section from the keel up its
side), tarred below the wale, bare above; open boats are drawn inside too.
Shrouds are cards of our painted ratlines; the player climbs straight up,
so each set of shrouds has an upright climb (`climbs`: boxes [x, y, z, sx,
sy, sz, yaw], their -z into what they lean on) inside their lean, from the
deck to a mantle under the top.
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


def col(cx, cy, cz, sx, sy, sz, yaw=0.0, pitch=0.0, roll=0.0):
    return [cx, cy, cz, sx, sy, sz, "wood", yaw, pitch, roll]


def _ship(name, slot, shapes, cols, size, budget, climbs=None):
    k.piece(name, "ship", slot, "wood", [], cols=cols, size=size)
    k.model(name, shapes)
    k.PIECES[name]["budget"] = budget
    k.PIECES[name]["climbs"] = climbs or []


def _face(points, out, slot):
    """A face through `points` (duplicates dropped) turned to look along
    `out`."""
    kept = []

    for p in points:
        if not kept or max(abs(p[i] - kept[-1][i]) for i in range(3)) > 1e-6:
            kept.append(list(p))

    if len(kept) > 2 and max(abs(kept[0][i] - kept[-1][i]) for i in range(3)) < 1e-6:
        kept.pop()

    if len(kept) < 3:
        return None

    a, b, c = kept[0], kept[1], kept[2]
    n = [(b[1] - a[1]) * (c[2] - a[2]) - (b[2] - a[2]) * (c[1] - a[1]),
         (b[2] - a[2]) * (c[0] - a[0]) - (b[0] - a[0]) * (c[2] - a[2]),
         (b[0] - a[0]) * (c[1] - a[1]) - (b[1] - a[1]) * (c[0] - a[0])]

    if sum(n[i] * out[i] for i in range(3)) < 0.0:
        kept = kept[::-1]

    return ks.polygon(kept, slot)


def hull(stations, wale, low="hull_tarred", high="hull_bare", inside=None, lining=None):
    """The hull lofted through `stations` [(x, [(z, y) or (z, y, dx), ...]
    from the keel up the +z side)] (dx: that point forward of its station, a
    stem's rake), mirrored: its faces under `wale` in `low`, over it in
    `high`; `inside` (a slot) draws it all from within too (an open boat),
    `lining` (a slot) only its last band, the bulwarks over a deck."""
    shapes = []

    def at(x, p, side):
        return [x + (p[2] if len(p) > 2 else 0.0), p[1], side * p[0]]

    for (x0, s0), (x1, s1) in zip(stations, stations[1:]):
        for i in range(len(s0) - 1):
            for side in (1.0, -1.0):
                quad = [at(x0, s0[i], side), at(x1, s1[i], side), at(x1, s1[i + 1], side), at(x0, s0[i + 1], side)]
                slot = low if max(p[1] for p in quad) <= wale + 1e-6 else high
                face = _face(quad, [0.0, 0.0, side], slot)

                if face is not None:
                    shapes.append(face)

                within = inside if inside is not None else (lining if i == len(s0) - 2 else None)

                if within is not None:
                    face = _face(quad, [0.0, 0.0, -side], within)

                    if face is not None:
                        shapes.append(face)

    # The transom: the first station's outline, looking aft (and in).
    x, section = stations[0]
    outline = [at(x, p, 1.0) for p in section] + [at(x, p, -1.0) for p in reversed(section)]

    for out, slot in (([-1.0, 0.0, 0.0], high),) + ((([1.0, 0.0, 0.0], inside),) if inside else ()):
        face = _face(outline, out, slot)

        if face is not None:
            shapes.append(face)

    return shapes


def deck(stations, y, slot="boards", tile=1.5):
    """A deck at y across the hull between its sides (the stations' widths
    there), looking up."""
    shapes = []

    for (x0, w0), (x1, w1) in zip(stations, stations[1:]):
        face = _face([[x0, y, -w0], [x1, y, -w1], [x1, y, w1], [x0, y, w0]], [0.0, 1.0, 0.0], slot)

        if face is not None:
            shapes.append(face)

    return shapes


def _ladder(x, y0, y1, z, yaw):
    """A ladder's rails and rungs (every 0.3 m) from y0 to y1, turned by yaw."""
    out = [ks.box(-0.25, (y0 + y1) / 2.0, 0.0, 0.06, y1 - y0, 0.06, "timber"), ks.box(0.25, (y0 + y1) / 2.0, 0.0, 0.06, y1 - y0, 0.06, "timber")]

    for rung in range(int((y1 - y0) / 0.3)):
        out.append(ks.prism(0.0, y0 + 0.3 + rung * 0.3, 0.0, 0.025, 0.5, 3, "timber", roll=90.0, caps=False))

    return ks.moved(out, yaw, (x, 0.0, z))


# ---------------------------------------------------------------------------
# The carrack: 30 m, 9 across, three masts; its sterncastle holds the
# captain's cabin (a door in its forward bulkhead off the main deck, lit
# windows in its transom), a poop over its after part; a forecastle to the
# bow. Ladders up to both castles.
# ---------------------------------------------------------------------------

# Half its beam at its main deck, along it (x: its transom at -15, its stem
# at 15).
CARRACK = [(-15.0, 3.6), (-10.0, 4.3), (-4.0, 4.5), (2.0, 4.5), (8.0, 4.1), (12.0, 3.0), (15.0, 0.3)]


def _sheer(x):
    """How much the gunwale rises over the main deck's bulwark toward the
    ends (the carrack's sweep up to its castles)."""
    return 0.9 * (abs(x) / 15.0) ** 2


def _carrack_section(x, w):
    keel = -3.5 if x < 12.0 else -2.4
    # (At the stem the section rakes forward as it rises.)
    rake = [0.0, 0.0, 0.0, 0.0, 0.0] if x < 15.0 else [-2.4, -1.4, -0.6, 0.0, 0.5]
    points = [(0.25, keel), (0.8 * w, keel + 1.2), (0.97 * w, 0.0), (w, MAIN_DECK + _sheer(x) * 0.5), (0.94 * w, MAIN_DECK + BULWARK + _sheer(x))]
    return (x, [(z, y, dx) for (z, y), dx in zip(points, rake)])


def _castle(x0, x1, y0, y1, width, taper=0.95):
    """A castle's sides (x0..x1, y0..y1) standing on the hull's sides,
    their half widths `width(x)`, leaning in a little; drawn out and in (its
    bulwarks are seen from its deck)."""
    shapes = []

    for side in (1.0, -1.0):
        quad = [[x0, y0, side * width(x0)], [x1, y0, side * width(x1)], [x1, y1, side * width(x1) * taper], [x0, y1, side * width(x0) * taper]]
        shapes.append(_face(quad, [0.0, 0.0, side], "hull_bare"))
        shapes.append(_face(quad, [0.0, 0.0, -side], "boards"))

    return shapes


def _width(x):
    for (x0, w0), (x1, w1) in zip(CARRACK, CARRACK[1:]):
        if x0 <= x <= x1:
            return w0 + (w1 - w0) * (x - x0) / (x1 - x0)

    return CARRACK[-1][1]


def _carrack_hull():
    stations = [_carrack_section(x, w) for x, w in CARRACK]
    shapes = hull(stations, 0.6, lining="boards")
    shapes += deck([(x, w * 0.99) for x, w in CARRACK], MAIN_DECK)

    # The sterncastle (-15 .. -6) to its deck at 5, the poop (-15 .. -11) to 8;
    # the forecastle (8 .. 14) to its deck at 6.5.
    edge = lambda x: _width(x) * 0.94
    # (The forecastle runs on past the stem to a point, as a carrack's does.)
    bow = lambda x: edge(x) if x <= 12.0 else edge(12.0) * max(0.08, (16.5 - x) / 4.5)
    shapes += _castle(-15.0, -6.0, MAIN_DECK + BULWARK, CASTLE_DECK + BULWARK, edge)
    shapes += _castle(-15.0, -11.0, CASTLE_DECK + BULWARK, POOP_DECK + BULWARK, lambda x: edge(x) * 0.95, 0.96)
    shapes += _castle(8.0, 12.0, MAIN_DECK + BULWARK, FORE_DECK + BULWARK, bow)
    shapes += _castle(12.0, 16.5, MAIN_DECK + BULWARK + 0.9, FORE_DECK + BULWARK, bow)
    shapes.append(_face([[12.0, MAIN_DECK + BULWARK + 0.9, -bow(12.0)], [16.5, MAIN_DECK + BULWARK + 0.9, -bow(16.5)],
                         [16.5, MAIN_DECK + BULWARK + 0.9, bow(16.5)], [12.0, MAIN_DECK + BULWARK + 0.9, bow(12.0)]], [0.0, -1.0, 0.0], "hull_bare"))
    shapes += deck([(-15.0, edge(-15.0) * 0.97), (-10.0, edge(-10.0) * 0.97), (-6.0, edge(-6.0) * 0.97)], CASTLE_DECK)
    shapes += deck([(-15.0, edge(-15.0) * 0.9), (-11.0, edge(-11.0) * 0.9)], POOP_DECK)
    shapes += deck([(8.0, bow(8.0) * 0.97), (12.0, bow(12.0) * 0.97), (14.5, bow(14.5) * 0.97), (16.5, bow(16.5) * 0.97)], FORE_DECK)

    # Bulkheads: the sterncastle's forward one with the cabin's door, the
    # poop's, the forecastle's aft one with its own.
    for x, y0, y1, w, out in ((-6.0, MAIN_DECK, CASTLE_DECK, edge(-6.0), 1.0), (-11.0, CASTLE_DECK, POOP_DECK, edge(-11.0) * 0.95, 1.0),
                              (8.0, MAIN_DECK, FORE_DECK, edge(8.0), -1.0)):
        shapes.append(_face([[x, y0, -w], [x, y0, w], [x, y1, w], [x, y1, -w]], [out, 0.0, 0.0], "hull_bare"))
        shapes.append(ks.card(x + out * 0.03, MAIN_DECK + DOOR[1] / 2.0 if y0 == MAIN_DECK else y0 + 1.0, 0.0, DOOR[0], DOOR[1] if y0 == MAIN_DECK else 1.6,
                              "door_1" if y0 == MAIN_DECK else "shutters", 90.0))

    # The cabin inside: its walls, a table; its lit windows in the transom.
    shapes += [ks.box(-10.5, (MAIN_DECK + CASTLE_DECK) / 2.0, 3.95, 8.8, 3.0, 0.1, "boards"),
               ks.box(-10.5, (MAIN_DECK + CASTLE_DECK) / 2.0, -3.95, 8.8, 3.0, 0.1, "boards"),
               ks.box(-14.85, (MAIN_DECK + CASTLE_DECK) / 2.0, 0.0, 0.1, 3.0, 6.6, "boards"),
               ks.box(-10.5, CASTLE_DECK - 0.1, 0.0, 8.8, 0.1, 7.8, "boards"),
               ks.box(-12.0, MAIN_DECK + 0.4, 0.0, 1.8, 0.8, 1.0, "wood_old")]

    for z in (-1.8, 0.0, 1.8):
        shapes.append(ks.card(-15.02, 3.6, z, 1.0, 1.1, "glass_lit", 90.0))

    # Wales along each side following the hull (at the waterline's rise, the
    # bilge's and the deck's), gunports shut, the chain-wales the shrouds
    # stand on.
    for side in (1.0, -1.0):
        for (x0, w0), (x1, w1) in zip(CARRACK[:-2], CARRACK[1:-1]):
            angle = math.degrees(math.atan2(w1 - w0, x1 - x0)) * side
            length = math.hypot(x1 - x0, w1 - w0)

            for y, share in ((0.6, 0.985), (1.35, 0.995), (MAIN_DECK - 0.1, 1.0)):
                shapes.append(ks.box((x0 + x1) / 2.0, y + _sheer((x0 + x1) / 2.0) * 0.3 * (y / MAIN_DECK), side * ((w0 + w1) / 2.0 * share + 0.06),
                                     length, 0.18, 0.12, "hull_bare", -angle))

        for x in (-8.0, -3.0, 3.0):
            shapes.append(ks.box(x, 1.2, side * (_width(x) * 0.99 + 0.02), 0.6, 0.6, 0.04, "pitch"))

        for x in (0.0, 10.0):
            shapes.append(ks.box(x, MAIN_DECK + 1.2, side * (_width(x) + 0.35), 3.0, 0.2, 0.7, "hull_bare"))

    # Ladders up to the sterncastle's deck and the forecastle's.
    climbs = []

    for z in (2.4, -2.4):
        shapes += _ladder(-5.7, MAIN_DECK, CASTLE_DECK + 0.3, z, 90.0)
        climbs.append([-5.6, (MAIN_DECK + CASTLE_DECK + 0.3) / 2.0, z, 0.8, CASTLE_DECK + 0.3 - MAIN_DECK, 0.5, 90.0])

    shapes += _ladder(7.7, MAIN_DECK, FORE_DECK + 0.3, 0.0, -90.0)
    climbs.append([7.6, (MAIN_DECK + FORE_DECK + 0.3) / 2.0, 0.0, 0.8, FORE_DECK + 0.3 - MAIN_DECK, 0.5, -90.0])

    cols = [col(-1.0, (MAIN_DECK - 3.5) / 2.0, 0.0, 18.0, MAIN_DECK + 3.5, 8.6), col(10.0, (MAIN_DECK - 3.0) / 2.0, 0.0, 4.0, MAIN_DECK + 3.0, 6.8),
            col(13.2, (MAIN_DECK - 2.4) / 2.0, 0.0, 2.4, MAIN_DECK + 2.4, 3.0), col(-12.5, (MAIN_DECK - 3.5) / 2.0, 0.0, 5.0, MAIN_DECK + 3.5, 7.4),
            # the main deck's bulwarks
            col(1.0, MAIN_DECK + BULWARK / 2.0, 4.25, 14.0, BULWARK, 0.2), col(1.0, MAIN_DECK + BULWARK / 2.0, -4.25, 14.0, BULWARK, 0.2),
            # the forecastle
            col(10.0, (MAIN_DECK + FORE_DECK) / 2.0, 0.0, 4.0, FORE_DECK - MAIN_DECK, 7.4),
            col(13.0, (MAIN_DECK + FORE_DECK) / 2.0, 0.0, 2.0, FORE_DECK - MAIN_DECK, 4.2),
            col(11.0, FORE_DECK + BULWARK / 2.0, 3.4, 6.0, BULWARK, 0.15), col(11.0, FORE_DECK + BULWARK / 2.0, -3.4, 6.0, BULWARK, 0.15),
            # the cabin: its sides, its back, its bulkhead either side of its
            # door and the lintel over it, its deckhead (the castle's deck)
            col(-10.5, (MAIN_DECK + CASTLE_DECK) / 2.0, 4.0, 9.0, 3.0, 0.2), col(-10.5, (MAIN_DECK + CASTLE_DECK) / 2.0, -4.0, 9.0, 3.0, 0.2),
            col(-14.9, (MAIN_DECK + CASTLE_DECK) / 2.0, 0.0, 0.2, 3.0, 7.2),
            col(-6.0, (MAIN_DECK + CASTLE_DECK) / 2.0, 2.3, 0.2, 3.0, 3.4), col(-6.0, (MAIN_DECK + CASTLE_DECK) / 2.0, -2.3, 0.2, 3.0, 3.4),
            col(-6.0, (MAIN_DECK + DOOR[1] + CASTLE_DECK) / 2.0, 0.0, 0.2, CASTLE_DECK - MAIN_DECK - DOOR[1], DOOR[0]),
            col(-10.5, CASTLE_DECK - 0.05, 0.0, 9.0, 0.1, 8.0),
            col(-8.5, CASTLE_DECK + BULWARK / 2.0, 3.9, 5.0, BULWARK, 0.15), col(-8.5, CASTLE_DECK + BULWARK / 2.0, -3.9, 5.0, BULWARK, 0.15),
            # the poop
            col(-13.0, (CASTLE_DECK + POOP_DECK) / 2.0, 0.0, 4.0, POOP_DECK - CASTLE_DECK, 7.0)]
    return shapes, cols, climbs


def _furled(x, y, z, length, yaw=0.0, pitch=0.0, roll=0.0):
    """A sail furled on its yard: a lumpy roll of canvas under the spar."""
    return ks.prism(x, y, z, 0.32, length * 0.9, 6, "sailcloth", yaw=yaw, pitch=pitch, roll=roll, rings=[[0.3, 0.4], [0.7, 0.36]])


def _mast(x, y0, y1, radius):
    return ks.prism(x, (y0 + y1) / 2.0, 0.0, radius, y1 - y0, 8, "hull_bare", top=radius * 0.62)


def _top(x, y, radius):
    """A fighting top: a round platform, a low rail round it."""
    return [ks.lathe(x, y - 0.25, 0.0, [[0.25, 0.0], [radius, 0.25], [radius, 0.6], [radius - 0.06, 0.6], [radius - 0.06, 0.25]], 10, "hull_bare"),
            ks.disc(x, y + 0.001, 0.0, radius - 0.06, 10, "boards", pitch=-90.0)]


def _shrouds(x, y0, y1, z0, z1, width, side):
    """A set of shrouds and ratlines on one side: one card from the channel
    (z0, y0) up to under the top (z1, y1), leaning in."""
    lean = math.degrees(math.atan2(z0 - z1, y1 - y0))
    return ks.card(x, (y0 + y1) / 2.0, side * (z0 + z1) / 2.0, width, math.hypot(y1 - y0, z0 - z1), "ratlines", 0.0 if side > 0 else 180.0,
                   -lean)


def _carrack_rig():
    shapes = [_mast(0.0, MAIN_DECK, 28.0, 0.36), _mast(10.0, FORE_DECK, 22.0, 0.28), _mast(-9.0, CASTLE_DECK, 17.0, 0.22)]
    shapes += _top(0.0, TOP, TOP_RADIUS) + _top(10.0, 16.0, 1.1)
    # The fore yard and the main topsail yard, furled; the mizzen's lateen.
    shapes += [ks.prism(10.0, 14.6, 0.0, 0.18, 15.0, 8, "hull_bare", roll=90.0, yaw=90.0), _furled(10.0, 14.25, 0.0, 15.0, 90.0, 0.0, 90.0),
               ks.prism(0.0, 25.0, 0.0, 0.12, 10.0, 6, "hull_bare", roll=90.0, yaw=90.0), _furled(0.0, 24.75, 0.0, 10.0, 90.0, 0.0, 90.0),
               ks.prism(-9.0, 12.5, 0.0, 0.14, 14.0, 6, "hull_bare", roll=55.0), _furled(-9.2, 12.3, 0.0, 14.0, 0.0, 0.0, 55.0)]

    # Shrouds: main (from the channels to under the top), fore, mizzen.
    for side in (1.0, -1.0):
        shapes.append(_shrouds(0.0, MAIN_DECK + 1.2, TOP - 0.3, 4.8, TOP_RADIUS, 3.6, side))
        shapes.append(_shrouds(10.0, FORE_DECK + 0.6, 15.7, 3.8, 1.1, 2.6, side))
        shapes.append(_shrouds(-9.0, CASTLE_DECK + 1.0, 13.0, 3.9, 0.6, 2.0, side))
        shapes.append(_shrouds(0.0, TOP + 0.6, 26.5, TOP_RADIUS - 0.1, 0.3, 1.4, side))

    # The stays: fore and aft from the mastheads.
    for a, b in (((0.0, 27.5), (10.0, 21.0)), ((10.0, 21.5), (16.5, 4.0)), ((0.0, 27.0), (-9.0, 16.5)), ((-9.0, 16.5), (-15.0, 9.0))):
        (x0, y0), (x1, y1) = a, b
        length = math.hypot(x1 - x0, y1 - y0)
        angle = math.degrees(math.atan2(y1 - y0, x1 - x0))
        shapes.append(ks.box((x0 + x1) / 2.0, (y0 + y1) / 2.0, 0.0, length, 0.06, 0.06, "rope", 0.0, 0.0, angle))

    cols = [col(0.0, TOP - 0.05, 0.0, 2.0 * TOP_RADIUS - 0.2, 0.1, 2.0 * TOP_RADIUS - 0.2), col(10.0, 15.95, 0.0, 2.0, 0.1, 2.0),
            col(0.0, 15.0, 0.0, 0.6, 26.0, 0.6), col(10.0, 14.25, 0.0, 0.5, 15.5, 0.5), col(-9.0, 11.0, 0.0, 0.4, 12.0, 0.4)]
    # The climbs: upright, inside the shrouds' lean, from the deck to a
    # mantle under the top; their backs on the side toward the mast.
    climbs = []

    for side, yaw in ((1.0, 0.0), (-1.0, 180.0)):
        climbs.append([0.0, (MAIN_DECK + TOP - 0.4) / 2.0, side * (TOP_RADIUS + 1.15), 3.0, TOP - 0.4 - MAIN_DECK, 2.3, yaw])
        climbs.append([10.0, (FORE_DECK + 15.7) / 2.0, side * (1.1 + 0.9), 2.2, 15.7 - FORE_DECK, 1.8, yaw])

    return shapes, cols, climbs


YARD = 26.0


def _mainyard():
    """The main yard (26 m: its arm reaches over the sea wall's walk with
    the carrack alongside the quay), furled sail under it, a footrope
    below; its top a beam to walk. Pivot: its middle, on the mast."""
    shapes = [ks.prism(0.0, 0.0, 0.0, 0.25, YARD, 8, "hull_bare", roll=90.0, top=0.25, rings=[[0.5, 0.3]]),
              _furled(0.0, -0.35, 0.0, YARD - 1.0, 0.0, 0.0, 90.0),
              ks.box(0.0, -1.05, 0.35, YARD - 2.0, 0.04, 0.04, "rope")]
    return shapes, [col(0.0, 0.2, 0.0, YARD, 0.1, 0.45)]


_shapes, _cols, _climbs = _carrack_hull()
_ship("carrack_hull", "hull_tarred", _shapes, _cols, [33.0, 12.5, 10.6], 2800, _climbs)
k.PIECES["carrack_hull"]["door"] = list(DOOR)
_shapes, _cols, _climbs = _carrack_rig()
_ship("carrack_rig", "hull_bare", _shapes, _cols, [34.0, 28.5, 15.4], 1400, _climbs)
_shapes, _cols = _mainyard()
_ship("carrack_mainyard", "hull_bare", _shapes, _cols, [YARD, 1.2, 1.0], 300)


# ---------------------------------------------------------------------------
# A caravel (20 m, lateen-rigged on two masts), a fishing boat and a
# rowboat (open, drawn inside too; floors to stand on).
# ---------------------------------------------------------------------------

CARAVEL = [(-10.0, 2.4), (-6.0, 2.9), (0.0, 3.0), (5.0, 2.7), (8.0, 1.8), (10.0, 0.2)]


def _caravel():
    deck_y, bulwark = 1.5, 0.8
    stations = [(x, [(0.2, -2.5 if x < 8.0 else -1.8), (0.8 * w, -1.5), (0.97 * w, 0.0), (w, deck_y), (0.95 * w, deck_y + bulwark)])
                for x, w in CARAVEL]
    shapes = hull(stations, 0.4, lining="boards")
    shapes += deck([(x, w * 0.99) for x, w in CARAVEL], deck_y)
    # A small aftercastle to 3.5, its door; two lateen masts, their yards.
    after = lambda x: [w for xx, w in CARAVEL if xx == x][0] * 0.95
    shapes += _castle(-10.0, -6.0, deck_y + bulwark, 3.5 + 0.8, after)
    shapes += deck([(-10.0, after(-10.0) * 0.97), (-6.0, after(-6.0) * 0.97)], 3.5)
    shapes.append(_face([[-6.0, deck_y, -after(-6.0)], [-6.0, deck_y, after(-6.0)], [-6.0, 3.5, after(-6.0)], [-6.0, 3.5, -after(-6.0)]],
                        [1.0, 0.0, 0.0], "hull_bare"))
    shapes.append(ks.card(-5.97, deck_y + 1.0, 0.0, 1.0, 2.0, "door_1", 90.0))
    shapes += [_mast(0.0, deck_y, 16.0, 0.26), _mast(-5.0, 3.5, 12.0, 0.2),
               ks.prism(0.5, 11.0, 0.0, 0.14, 18.0, 6, "hull_bare", roll=60.0), _furled(0.3, 10.8, 0.0, 17.0, 0.0, 0.0, 60.0),
               ks.prism(-4.7, 9.0, 0.0, 0.12, 12.0, 6, "hull_bare", roll=60.0), _furled(-4.9, 8.8, 0.0, 11.0, 0.0, 0.0, 60.0)]

    for side in (1.0, -1.0):
        shapes.append(_shrouds(0.0, deck_y + 0.8, 13.0, 3.1, 0.5, 2.4, side))

    climbs = [[0.0, (deck_y + 12.5) / 2.0, 1.4, 2.2, 12.5 - deck_y, 1.6, 0.0]]
    cols = [col(-1.0, (deck_y - 2.5) / 2.0, 0.0, 14.0, deck_y + 2.5, 5.6), col(7.5, (deck_y - 1.8) / 2.0, 0.0, 3.0, deck_y + 1.8, 3.2),
            col(-8.0, (deck_y + 3.5) / 2.0, 0.0, 4.0, 3.5 - deck_y, 4.6), col(0.0, 8.5, 0.0, 0.5, 14.0, 0.5),
            col(0.0, deck_y + bulwark / 2.0, 2.85, 12.0, bulwark, 0.15), col(0.0, deck_y + bulwark / 2.0, -2.85, 12.0, bulwark, 0.15)]
    return shapes, cols, climbs


def _open_boat(stations, floor, thwarts, slot="hull_bare"):
    """An open boat: its hull drawn out and in, its floor boards (to stand
    on), its thwarts."""
    shapes = hull(stations, 0.1, low=slot, high=slot, inside=slot)
    length = stations[-1][0] - stations[0][0]
    shapes.append(ks.box((stations[0][0] + stations[-1][0]) / 2.0 - length * 0.05, floor, 0.0, length * 0.7, 0.04, 0.9, "boards"))

    for x in thwarts:
        shapes.append(ks.box(x, floor + 0.35, 0.0, 0.25, 0.05, 1.3, "boards"))

    return shapes


def _rowboat():
    stations = [(-2.25, [(0.1, -0.2), (0.55, 0.05), (0.62, 0.55)]), (-0.8, [(0.1, -0.35), (0.65, -0.05), (0.75, 0.55)]),
                (0.9, [(0.08, -0.3), (0.55, -0.05), (0.66, 0.6)]), (2.25, [(0.02, 0.0), (0.03, 0.3), (0.04, 0.75)])]
    shapes = _open_boat(stations, -0.15, (-0.8, 0.6))
    shapes += [ks.box(0.2, 0.62, 0.45, 3.0, 0.05, 0.05, "timber", 8.0), ks.box(0.1, 0.62, -0.45, 3.0, 0.05, 0.05, "timber", -6.0)]
    cols = [col(0.0, -0.17, 0.0, 3.2, 0.1, 1.0), col(0.0, 0.2, 0.68, 3.6, 0.8, 0.1), col(0.0, 0.2, -0.68, 3.6, 0.8, 0.1)]
    return shapes, cols


def _fishing_boat():
    stations = [(-4.0, [(0.1, -0.5), (0.9, 0.0), (1.05, 0.9)]), (-1.5, [(0.1, -0.8), (1.1, -0.1), (1.2, 0.9)]),
                (1.5, [(0.1, -0.75), (1.0, -0.1), (1.12, 0.95)]), (4.0, [(0.02, -0.2), (0.05, 0.4), (0.06, 1.2)])]
    shapes = _open_boat(stations, -0.45, (-1.8, 1.0))
    shapes += [ks.prism(0.6, 2.0, 0.0, 0.1, 4.8, 6, "hull_bare"), _furled(0.6, 2.8, 0.0, 4.0, 0.0, 0.0, 70.0),
               ks.lathe(-2.4, -0.43, 0.0, [[0.6, 0.0], [0.5, 0.2], [0.2, 0.35], [0.0, 0.4]], 8, "rope"),
               ks.card(-2.4, -0.05, 0.0, 1.1, 1.0, "net", 0.0, -80.0)]
    cols = [col(0.0, -0.47, 0.0, 5.6, 0.1, 1.6), col(0.0, 0.3, 1.12, 7.0, 1.3, 0.12), col(0.0, 0.3, -1.12, 7.0, 1.3, 0.12)]
    return shapes, cols


_shapes, _cols, _climbs = _caravel()
_ship("caravel", "hull_tarred", _shapes, _cols, [21.0, 16.5, 7.0], 1800, _climbs)
_shapes, _cols = _fishing_boat()
_ship("boat_fishing", "hull_bare", _shapes, _cols, [8.2, 5.0, 2.6], 400)
_shapes, _cols = _rowboat()
_ship("rowboat", "hull_bare", _shapes, _cols, [4.6, 1.2, 1.6], 180)
