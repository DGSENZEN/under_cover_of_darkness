"""The old town's terraces and the ground below them (its spec, sections 4.3
and 6; old_town_porto.md section 1, old_town_lisbon.md section 1,
old_town_spain.md section 4): pieces named by their measures, registered
when asked for (and, from the lot plan, when the kit is built).

    retaining   a granite retaining wall between two terraces, its face to
                +z, its coping the upper terrace's lip (a hang under
                rules.HANG high), a parapet on it if asked
    stair_lane  a stair-lane up +z: flights of 6-12 steps of RISER on
                TREAD, a LANDING between them
    ramp        a sloping lane
    arch_over   a house over a lane: its arch clear CLEAR at its crown
    vault       a vaulted tunnel along z: the Baixa's sewer (2.2 x 3.1), the
                vaulted stream (a channel beside a walkway ledge)
    cistern     a cistern's vault, 3.0 wide, its walkway along its water
    grate_hatch a way down from the street: a shaft and its ladder, the
                grate lifted aside; a paved collar round it where the
                ground leaves a hole of whole cells
    hatch_chamber  where a hatch's shaft comes down into a vault: a square
                chamber its width and height, a flat roof with the shaft's
                hole, its ends closed round the vault's barrel
    vault_end   a vault's end walled up, a grating in it
    scaffold    a builder's scaffold up a front (the Baixa still rebuilding
                after the fire): decks a LIFT apart off the wall, ladders
                between them, the top deck under the eaves
"""

import math

import kit_recipes as k
import kit_shapes as ks
import kit_town as town

RISER = 0.18
TREAD = 0.32
LANDING = 2.0
FLIGHT = (6, 12)
WALL_THICK = 0.8
COPING = (0.2, 0.1)
PARAPET = (1.0, 0.3)
CLEAR = 2.2
ARCH_RISE = 0.6
VAULT_WALL = 0.4
CHANNEL = 0.8
# A shaft's inside (the player's capsule is 1.0 m across), how proud of the
# street a hatch's collar stands.
SHAFT = 1.2
COLLAR_PROUD = 0.05
# A scaffold: its decks a lift apart, off the wall (clear of a balcony) and
# deep; the hole a ladder comes up through.
LIFT = 2.0
DECK_OFF = 0.65
DECK = 1.6
LADDER_HOLE = 1.2


def _cm(v):
    return int(round(v * 10.0))


def _register(name, family, slot, shapes, cols, size, **keys):
    if name not in k.PIECES:
        town.register(name, family, slot, dict({"shapes": shapes, "cols": cols, "size": size}, **keys))

    return name


def flights(steps):
    """A run of `steps` split into flights of FLIGHT[0]-FLIGHT[1] steps."""
    if steps <= FLIGHT[1]:
        return [steps]

    count = int(math.ceil(steps / float(FLIGHT[1])))
    base, extra = divmod(steps, count)
    return [base + (1 if i < extra else 0) for i in range(count)]


def stair_lane(width, steps):
    """A stair-lane `width` wide of `steps` steps up +z from its foot at
    the origin: its `head` [0, rise, z], `flights`, and the `tour` up it."""
    name = "stair_lane_%d_%d" % (_cm(width), steps)

    if name in k.PIECES:
        return name

    shapes, cols, tour = [], [], [[0.0, 0.0, -0.5, "walk"]]
    z, y = 0.0, 0.0
    runs = flights(steps)

    for i, n in enumerate(runs):
        for s in range(n):
            top = y + (s + 1) * RISER
            box = (0.0, top / 2.0, z + s * TREAD + TREAD / 2.0, width, top, TREAD)
            shapes.append(ks.box(*box, "granite"))
            cols.append(town.col(*box))

        tour += [[0.0, y + RISER, z + TREAD / 2.0, "stairs"], [0.0, y + n * RISER, z + (n - 1) * TREAD + TREAD / 2.0, "stairs"]]
        z += n * TREAD
        y += n * RISER

        if i < len(runs) - 1:
            box = (0.0, y / 2.0, z + LANDING / 2.0, width, y, LANDING)
            shapes.append(ks.box(*box, "calcada"))
            cols.append(town.col(*box))
            tour.append([0.0, y, z + LANDING / 2.0, "walk"])
            z += LANDING

    tour.append([0.0, y, z + 0.5, "walk"])
    return _register(name, "stair", "granite", shapes, cols, [width, y, z], head=[0.0, y, z], tour=tour, flights=runs)


def retaining(length, height, parapet=False):
    """A retaining wall `length` along x, `height` high, its face at z 0 to
    the lower terrace (+z), its body WALL_THICK behind, a coping at its top
    standing COPING[1] proud (the upper terrace's lip), a PARAPET on it."""
    name = "retaining_%d_%d%s" % (_cm(length), _cm(height), "_parapet" if parapet else "")

    if name in k.PIECES:
        return name

    t, (ct, proud) = WALL_THICK, COPING
    body = (0.0, (height - ct) / 2.0, -t / 2.0, length, height - ct, t)
    coping = (0.0, height - ct / 2.0, -t / 2.0 + proud / 2.0, length, ct, t + proud)
    shapes = [ks.box(*body, "granite_rough"), ks.box(*coping, "granite")]
    cols = [town.col(*body), town.col(*coping)]

    if parapet:
        ph, pt = PARAPET
        wall = (0.0, height + ph / 2.0, -pt / 2.0 - 0.05, length, ph, pt)
        shapes.append(ks.box(*wall, "granite"))
        cols.append(town.col(*wall))

    return _register(name, "wall", "granite_rough", shapes, cols, [length, height + (PARAPET[0] if parapet else 0.0), t + proud])


def ramp(width, length, rise):
    """A lane `width` wide sloping up `rise` over `length` along +z from the
    origin."""
    name = "ramp_%d_%d_%d" % (_cm(width), _cm(length), _cm(rise))

    if name in k.PIECES:
        return name

    pitch = math.degrees(math.atan2(rise, length))
    slope = math.hypot(length, rise)
    box = (0.0, rise / 2.0 - 0.1, length / 2.0, width, 0.2, slope)
    shapes = [ks.box(*box, "calcada", 0.0, -pitch, 0.0)]
    cols = [town.col(*box, "stone", 0.0, -pitch, 0.0)]
    return _register(name, "floor", "calcada", shapes, cols, [width, rise, length])


def arch_over(span, clear=CLEAR, depth=4.0):
    """A house over a lane `span` wide (the lane along z): granite piers
    each side, a segmental arch CLEAR high at its crown, a storey over it
    under a gable roof across the lane."""
    name = "arch_over_%d" % _cm(span)

    if name in k.PIECES:
        return name

    pier = 0.6
    width = span + 2.0 * pier
    base = clear + 0.5
    top = base + 3.2
    shapes = ks.arched_wall(width, base, depth, span, clear - ARCH_RISE, ARCH_RISE, 0.0, "granite")
    shapes += [ks.box(0.0, (base + top) / 2.0, 0.0, width, top - base, depth, "render_ochre")]

    for s in (-1.0, 1.0):
        shapes += [ks.card(0.0, base + 1.6, s * (depth / 2.0 + 0.02), 0.9, 1.3, "shutters", 0.0 if s > 0 else 180.0)]

    rs, rc = town.roof("gable", width, depth, top, 27.0, "render_ochre")
    shapes += rs
    cols = [town.col(s * (span / 2.0 + pier / 2.0), base / 2.0, 0.0, pier, base, depth) for s in (-1.0, 1.0)]
    cols += [town.col(0.0, (clear + base) / 2.0, 0.0, span, base - clear, depth), town.col(0.0, (base + top) / 2.0, 0.0, width, top - base, depth)]
    cols += rc
    return _register(name, "town", "render_ochre", shapes, cols, [width, top + 2.0, depth])


def vault(width, height, length, ledge=0.0, prefix="vault", slot="brick"):
    """A vaulted tunnel along z, `width` clear between its walls, `height`
    clear at its crown (a round barrel over walls up to its springing), its
    floor's top at 0; with a `ledge` (a walkway that wide along its +x side)
    the rest is a channel CHANNEL deep for the layout's water; `ledge` is
    the walkway's middle."""
    name = "%s_%d_%d_%d%s" % (prefix, _cm(width), _cm(height), _cm(length), "_ledge%d" % _cm(ledge) if ledge else "")

    if name in k.PIECES:
        return name

    r = width / 2.0
    spring = height - r
    shapes, cols = [], []

    def add(box, slot_of, roll=0.0):
        shapes.append(ks.box(*box, slot_of, 0.0, 0.0, roll))
        cols.append(town.col(*box, "stone", 0.0, 0.0, roll))

    if ledge:
        lx = r - ledge / 2.0
        add((lx, -0.15, 0.0, ledge, 0.3, length), "flagstone")
        add((-ledge / 2.0, -CHANNEL - 0.15, 0.0, width - ledge, 0.3, length), "stone_moss")
        add((r - ledge - 0.05, -CHANNEL / 2.0, 0.0, 0.1, CHANNEL, length), "stone_moss")
    else:
        add((0.0, -0.15, 0.0, width + 2.0 * VAULT_WALL, 0.3, length), "flagstone")

    for s in (-1.0, 1.0):
        foot = -CHANNEL if ledge else 0.0
        add((s * (r + VAULT_WALL / 2.0), (foot + spring) / 2.0, 0.0, VAULT_WALL, spring - foot, length), slot)

    # The barrel: five slabs round its half-circle, tangent to it.
    segments = 5
    chord = 2.0 * r * math.sin(math.pi / (2.0 * segments)) * 1.08

    for i in range(segments):
        theta = math.pi * (i + 0.5) / segments
        cx, cy = math.cos(theta) * (r + 0.15), spring + math.sin(theta) * (r + 0.15)
        add((cx, cy, 0.0, chord, 0.3, length), slot, math.degrees(theta) - 90.0)

    keys = {"ledge": r - ledge / 2.0} if ledge else {}
    return _register(name, "vault", slot, shapes, cols, [width + 2.0 * VAULT_WALL, height + 0.5, length], **keys)


def cistern(length):
    """A cistern's vault (an aljibe), 3.0 wide and high, its walkway along
    its water."""
    return vault(3.0, 3.0, length, ledge=0.8, prefix="cistern", slot="stone_moss")


def grate_hatch(depth, collar=0.0):
    """A way down from the street `depth` deep: a shaft SHAFT square, its
    ladder drawn down a wall from its foot to the street (its climb over
    the street), the grate lifted aside, nothing across its mouth; with a
    `collar`, the paving round it that wide, COLLAR_PROUD over the street
    (the ground's hole is whole cells)."""
    name = "grate_hatch_%d%s" % (_cm(depth), "_c%d" % _cm(collar) if collar else "")

    if name in k.PIECES:
        return name

    t = 0.2
    top = COLLAR_PROUD if collar else 0.0
    shapes, cols = [], []

    def add(box, slot):
        shapes.append(ks.box(*box, slot))
        cols.append(town.col(*box))

    for x, z, w, d in ((0.0, SHAFT / 2.0 + t / 2.0, SHAFT + 2.0 * t, t), (0.0, -SHAFT / 2.0 - t / 2.0, SHAFT + 2.0 * t, t),
                       (SHAFT / 2.0 + t / 2.0, 0.0, t, SHAFT), (-SHAFT / 2.0 - t / 2.0, 0.0, t, SHAFT)):
        add((x, (top - depth) / 2.0, z, w, depth + top, d), "stone_moss")

    if collar:
        c, inner = collar / 2.0, SHAFT / 2.0 + t
        y, h = top - 0.125, 0.25

        # (Paved as the street round it.)
        for box in ((0.0, y, (inner + c) / 2.0, collar, h, c - inner), (0.0, y, -(inner + c) / 2.0, collar, h, c - inner),
                    ((inner + c) / 2.0, y, 0.0, c - inner, h, 2.0 * inner), (-(inner + c) / 2.0, y, 0.0, c - inner, h, 2.0 * inner)):
            add(box, "calcada")

    # (The grate's iron rim round the mouth, the grate leant aside.)
    rim = SHAFT / 2.0 + 0.05
    shapes += [ks.box(0.0, top + 0.01, s * rim, SHAFT + 0.2, 0.03, 0.1, "iron") for s in (-1.0, 1.0)]
    shapes += [ks.box(s * rim, top + 0.01, 0.0, 0.1, 0.03, SHAFT, "iron") for s in (-1.0, 1.0)]
    shapes.append(ks.card(SHAFT * 0.9, top + 0.4, 0.0, SHAFT, 0.8, "window_grille", 90.0, 60.0))

    # (The ladder down its +x wall: two rails, a rung every 0.3 m.)
    wall_x = SHAFT / 2.0 - 0.06
    shapes += [ks.box(wall_x, (top - depth) / 2.0, s * 0.22, 0.05, depth + top, 0.05, "iron") for s in (-1.0, 1.0)]
    shapes += [ks.box(wall_x, -depth + 0.3 * (i + 1), 0.0, 0.03, 0.03, 0.44, "iron") for i in range(int((depth + top) / 0.3))]
    climbs = [[0.0, (-depth + 0.6) / 2.0, 0.0, 0.8, depth + 0.6, 0.8, 0.0]]
    reach = max(collar, SHAFT + 2.0 * t)
    return _register(name, "vault", "stone_moss", shapes, cols, [reach, depth, reach], climbs=climbs)


def hatch_chamber(width, height, length):
    """Where a hatch's shaft comes down into a vault `width` x `height`: a
    chamber `length` long, square in section, its walls the vault's, a flat
    roof (its top `roof`) with the shaft's hole SHAFT square against its +x
    wall (the hatch over it stands SHAFT/2 - width/2 off the vault's axis),
    a ladder up that wall; each end walled round the vault's barrel (its
    arch open)."""
    name = "hatch_chamber_%d_%d_%d" % (_cm(width), _cm(height), _cm(length))

    if name in k.PIECES:
        return name

    r = width / 2.0
    outer = width + 2.0 * VAULT_WALL
    roof = height + 0.3
    hole = SHAFT / 2.0
    west = r - SHAFT
    shapes, cols = [], []

    def add(box, slot):
        shapes.append(ks.box(*box, slot))
        cols.append(town.col(*box))

    add((0.0, -0.15, 0.0, outer, 0.3, length), "flagstone")

    for s in (-1.0, 1.0):
        add((s * (r + VAULT_WALL / 2.0), height / 2.0, 0.0, VAULT_WALL, height, length), "brick")
        # (The roof round the hole: across its ends, then either side of it.)
        add((0.0, height + 0.15, s * (hole + length / 2.0) / 2.0, outer, 0.3, length / 2.0 - hole), "brick")
        shapes += ks.arched_wall(outer, roof, 0.1, width, height - r, r, 0.0, "brick", z=s * (length / 2.0 - 0.05))

    add(((-outer / 2.0 + west) / 2.0, height + 0.15, 0.0, west + outer / 2.0, 0.3, 2.0 * hole), "brick")
    add(((r + outer / 2.0) / 2.0, height + 0.15, 0.0, outer / 2.0 - r, 0.3, 2.0 * hole), "brick")
    # (The ladder up its +x wall: rails and rungs.)
    wall_x = r - 0.06
    shapes += [ks.box(wall_x, roof / 2.0, s * 0.22, 0.05, roof, 0.05, "iron") for s in (-1.0, 1.0)]
    shapes += [ks.box(wall_x, 0.3 * (i + 1), 0.0, 0.03, 0.03, 0.44, "iron") for i in range(int(roof / 0.3))]
    climbs = [[r - 0.4, roof / 2.0, 0.0, 0.8, roof + 0.2, 0.8, 0.0]]
    return _register(name, "vault", "brick", shapes, cols, [outer, roof, length], climbs=climbs, roof=roof)


def vault_end(width, height):
    """A vault `width` x `height` walled up at its end (the wall 0.3 thick
    about z 0), an iron grating in it over the dark."""
    name = "vault_end_%d_%d" % (_cm(width), _cm(height))

    if name in k.PIECES:
        return name

    outer = width + 2.0 * VAULT_WALL
    box = (0.0, (height + 0.5) / 2.0 - 0.3, 0.0, outer, height + 0.8, 0.3)
    shapes = [ks.box(*box, "brick"), ks.card(0.0, 1.0, 0.17, 1.2, 1.4, "pitch"), ks.card(0.0, 1.0, 0.19, 1.2, 1.4, "window_grille")]
    return _register(name, "vault", "brick", shapes, [town.col(*box)], [outer, height + 0.5, 0.3])


def scaffold(height, width):
    """A builder's scaffold `width` wide up a front whose eaves are `height`
    up (its back on the wall at z 0, standing out to +z): poles, a deck
    every LIFT to the last under the eaves (`top`), DECK_OFF off the wall
    and DECK deep, ladders between them turn about at its ends (each deck
    holed where the ladder from under it comes up), a rail along its front;
    its `tour` from the street to the top deck."""
    name = "scaffold_%d_%d" % (_cm(height), _cm(width))

    if name in k.PIECES:
        return name

    lifts = int((height - 0.1) / LIFT)
    top = lifts * LIFT
    z0, z1 = DECK_OFF, DECK_OFF + DECK
    zm = (z0 + z1) / 2.0
    half = width / 2.0
    side = half - LADDER_HOLE / 2.0 - 0.1
    shapes, cols = [], []

    def add(box, slot, solid=True):
        shapes.append(ks.box(*box, slot))

        if solid:
            cols.append(town.col(*box, "wood"))

    for x in (-half, 0.0, half):
        for z in (z0, z1):
            add((x, (top + 1.2) / 2.0, z, 0.08, top + 1.2, 0.08), "timber", x != 0.0 or z == z1)

    climbs, tour = [], []
    ladder_x = [(side if n % 2 == 0 else -side) for n in range(lifts)]
    tour += [[ladder_x[0], 0.0, z1 + 1.0, "walk"], [ladder_x[0], 0.0, zm, "walk"]]

    for n in range(1, lifts + 1):
        y = n * LIFT
        below = ladder_x[n - 1]
        h0, h1 = below - LADDER_HOLE / 2.0, below + LADDER_HOLE / 2.0
        # (The deck either side of the hole the ladder from under it comes up through.)
        for a, b in ((-half, h0), (h1, half)):
            if b - a > 0.01:
                add(((a + b) / 2.0, y - 0.04, zm, b - a, 0.08, DECK), "boards")

        for z in (z0 + 0.1, z1 - 0.1):
            add((below, y - 0.04, z, LADDER_HOLE, 0.08, 0.2), "boards")

        add((0.0, y + 1.0, z1 - 0.04, width, 0.06, 0.06), "timber")
        # (The ladder up to it from the deck under it, drawn: rails and rungs.)
        y0 = y - LIFT
        shapes += [ks.box(below + s * 0.25, (y0 + y + 0.9) / 2.0, zm, 0.06, LIFT + 0.9, 0.06, "timber") for s in (-1.0, 1.0)]
        shapes += [ks.box(below, y0 + 0.3 * (i + 1), zm, 0.5, 0.04, 0.04, "timber") for i in range(int((LIFT + 0.6) / 0.3))]
        climbs.append([below, y0 + (LIFT + 0.6) / 2.0, zm, 1.0, LIFT + 0.6, 1.0, 0.0])
        step = -0.8 if below > 0.0 else 0.8
        tour.append([below + step, y, zm, "climb"])

        if n < lifts:
            tour.append([ladder_x[n], y, zm, "walk"])

    tour.append([0.0, top, zm, "walk"])
    # (Half a house's front of timber: its own budget.)
    return _register(name, "street", "timber", shapes, cols, [width + 0.2, top + 1.2, z1 + 0.1], climbs=climbs, tour=tour, top=top, budget=1500)
