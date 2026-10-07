"""The old town's terraces and the ground below them (its spec, sections 4.3
and 6; old_town_porto.md section 1, old_town_lisbon.md section 1,
old_town_spain.md section 4): pieces named by their measures, registered
when asked for (and, from the lot plan, when the kit is built).

    parapet     a parapet on a terrace's edge over its drop
    footing     solid granite under a city wall whose foot steps up over a
                terrace
    rampart     the old wall on a rim over a drop
    yard_front  a light plot's walled front on its lane, a barred gate
    retaining   a granite retaining wall between two terraces, its face to
                +z, its coping the upper terrace's lip (a hang under
                rules.HANG high), a parapet on it if asked
    stair_lane  a stair-lane up +z: flights of 6-12 steps of RISER on
                TREAD, a LANDING between them
    ramp        a sloping lane
    arch_over   a house over a lane: its arch clear CLEAR at its crown
    vault       a vaulted tunnel along z: the Baixa's sewer (2.2 x 3.1), the
                vaulted stream (a channel beside a walkway ledge); with a
                door, a square chamber where a cellar opens onto it
    cascade     where the stream steps up a terrace: a tall chamber, the
                water falling down its step, a ladder up beside it
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
    wall_steps  a straight stone stair up a wall's inner face to its walk,
                a parapet on its open side, a landing at its head
    stair_tower a tower up a cliff, its door on the street at its foot, a
                switchback stair inside, its door at the top onto the
                terrace over the cliff
    corbels     stone corbels up a cliff's face a mantle apart, zig-zagging
                (a timber gallery's, burnt with the Baixa): the thief's way
    postern     a city wall's footing with a postern's passage into it, dark
                past its open gate (the Guindais gate)
    tannery     a tannery's yard: vats of liquor, hides drying on racks, a
                lean-to against its back wall, the tanners' work spot
    bricked     an alley's mouth bricked up
    gateway     a whitewashed wall across a lane, a segmental arch in it, an
                iron fanlight over its gate (live: hung by the layout; or
                barred shut)
    fill        a terrace carried forward between its retaining walls:
                solid, paved at its top
    bridge      a room over a stair-lane between two houses, borne on their
                party walls
"""

import math
import random

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
# street a hatch's collar stands (flush: it fills the ground's cut cell).
# (A man a metre across down it with room round him.)
SHAFT = 1.6
COLLAR_PROUD = 0.0
# A hatch's grate dragged aside: how far off its shaft's wall, its bars each
# way.
GRATE_GAP = 0.15
GRATE_BARS = 5
# A scaffold: its decks a lift apart, off the wall (clear of a balcony) and
# deep; the hole a ladder comes up through.
# (A man walks upright under the deck over him: his body 2.0 m tall.)
LIFT = 2.3
DECK_OFF = 0.65
# (Its hole at its back, its front walk before it.)
DECK_WALK = 1.25
DECK = 1.2 + DECK_WALK
LADDER_HOLE = 1.2
# (Along the deck, wider: a man takes hold of a ladder a little to one side.)
LADDER_HOLE_ALONG = 1.8
# (How far in front of a climb's plane the controller holds a climber's
# middle: his radius and its gap.)
CLIMB_HOLD = 0.58
# A door chamber's door's height; a cascade's length (its step at z 0).
STREAM_DOOR = 2.2
CASCADE = 3.2
# A wall stair's landing at its head; its parapet's thickness and height.
WALL_LANDING = 1.4
RAIL = (0.25, 0.9)
RAIL_PROUD = 0.01
# A stair tower: its walls, its flights' width and their spine between,
# the most steps a flight, their tread, its landings' depth, its top
# storey's height.
TOWER_WALL = 0.5
TOWER_FLIGHT = 1.2
TOWER_SPINE = 0.3
TOWER_STEPS = 10
TOWER_TREAD = 0.28
TOWER_LANDING = 1.4
TOWER_TOP = 2.6
# A corbel: along the face, out from it, thick; the most a corbel is over
# the one under it (a mantle), and how far either side of the line they
# zig-zag.
CORBEL = (1.0, 0.8, 0.35)
CORBEL_RISE = 2.2
CORBEL_SWAY = 0.7
# A postern's passage into its footing.
POSTERN_DEPTH = 1.6


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


def stair_lane(width, steps, riser=RISER):
    """A stair-lane `width` wide of `steps` steps of `riser` (dividing a
    terrace's step exactly) up +z from its foot at the origin: its `head`
    [0, rise, z], `flights`, and the `tour` up it."""
    name = "stair_lane_%d_%d%s" % (_cm(width), steps, "" if abs(riser - RISER) < 1e-9 else "_r%d" % int(round(riser * 10000)))

    if name in k.PIECES:
        return name

    shapes, cols, tour = [], [], [[0.0, 0.0, -0.5, "walk"]]
    z, y = 0.0, 0.0
    runs = flights(steps)

    for i, n in enumerate(runs):
        for s in range(n):
            top = y + (s + 1) * riser
            box = (0.0, top / 2.0, z + s * TREAD + TREAD / 2.0, width, top, TREAD)
            shapes.append(ks.box(*box, "stair_stone"))
            cols.append(town.col(*box))

        tour += [[0.0, y + riser, z + TREAD / 2.0, "stairs"], [0.0, y + n * riser, z + (n - 1) * TREAD + TREAD / 2.0, "stairs"]]
        z += n * TREAD
        y += n * riser

        if i < len(runs) - 1:
            # (Granite like its steps, paved on top.)
            box = (0.0, (y - 0.1) / 2.0, z + LANDING / 2.0, width, y - 0.1, LANDING)
            top = (0.0, y - 0.05, z + LANDING / 2.0, width, 0.1, LANDING)
            shapes += [ks.box(*box, "stair_stone"), ks.box(*top, "calcada")]
            cols += [town.col(*box), town.col(*top)]
            tour.append([0.0, y, z + LANDING / 2.0, "walk"])
            z += LANDING

    tour.append([0.0, y, z + 0.5, "walk"])
    return _register(name, "stair", "granite", shapes, cols, [width, y, z], head=[0.0, y, z], tour=tour, flights=runs)


def retaining(length, height, parapet=False, slot="rubble_warm", flush=False):
    """A retaining wall `length` along x, `height` high, its face at z 0 to
    the lower terrace (+z), its body WALL_THICK behind in `slot` (rubble; a
    dressed face where asked), a mossy coping at its top standing COPING[1]
    proud (the upper terrace's lip; `flush` where a stair stands against
    it), a PARAPET on it."""
    name = "retaining_%d_%d%s%s%s" % (_cm(length), _cm(height), "_parapet" if parapet else "", "" if slot == "rubble_warm" else "_" + slot,
                                      "_flush" if flush else "")

    if name in k.PIECES:
        return name

    t, (ct, proud) = WALL_THICK, COPING
    proud = 0.0 if flush else proud
    body = (0.0, (height - ct) / 2.0, -t / 2.0, length, height - ct, t)
    coping = (0.0, height - ct / 2.0, -t / 2.0 + proud / 2.0, length, ct, t + proud)
    shapes = [ks.box(*body, slot), ks.box(*coping, "coping_moss")]
    cols = [town.col(*body), town.col(*coping)]

    if parapet:
        ph, pt = PARAPET
        wall = (0.0, height + ph / 2.0, -pt / 2.0 - 0.05, length, ph, pt)
        shapes.append(ks.box(*wall, "ashlar_weathered"))
        cols.append(town.col(*wall))

    return _register(name, "wall", slot, shapes, cols, [length, height + (PARAPET[0] if parapet else 0.0), t + proud])


def parapet(length):
    """A parapet `length` along x guarding a drop to +z: PARAPET high on
    the terrace, its face at z 0."""
    name = "parapet_%d" % _cm(length)

    if name in k.PIECES:
        return name

    ph, pt = PARAPET
    box = (0.0, ph / 2.0, -pt / 2.0, length, ph, pt)
    shapes = [ks.box(*box, "ashlar_weathered"), ks.box(0.0, ph + 0.04, -pt / 2.0, length + 0.02, 0.08, pt + 0.08, "coping_moss")]
    return _register(name, "wall", "ashlar_weathered", shapes, [town.col(*box), town.col(0.0, ph + 0.04, -pt / 2.0, length + 0.02, 0.08, pt + 0.08)],
                     [length, ph + 0.08, pt + 0.08])


def footing(length, height, thick):
    """A wall's footing: solid granite `length` along x, `height` up from 0
    to the wall's foot, `thick` through z: under a city wall whose foot
    steps up over a terrace."""
    name = "footing_%d_%d_%d" % (_cm(length), _cm(height), _cm(thick))

    if name in k.PIECES:
        return name

    box = (0.0, height / 2.0, 0.0, length, height, thick)
    return _register(name, "wall", "granite_rough", [ks.box(*box, "granite_rough")], [town.col(*box)], [length, height, thick])


def rampart(length, height, below, thick=WALL_THICK + 1.2):
    """The old wall along a rim: `length` along x, `height` over its
    terrace, on down `below` it over the drop to +z (its outer face at z 0,
    the terrace to -z), `thick`, a coping."""
    name = "rampart_%d_%d_%d" % (_cm(length), _cm(height), _cm(below))

    if name in k.PIECES:
        return name

    body = (0.0, (height - below) / 2.0, -thick / 2.0, length, height + below, thick)
    coping = (0.0, height + 0.06, -thick / 2.0, length + 0.02, 0.12, thick + 0.12)
    shapes = [ks.box(*body, "granite_rough"), ks.box(*coping, "granite")]
    return _register(name, "wall", "granite_rough", shapes, [town.col(*body), town.col(*coping)], [length, height + below + 0.12, thick + 0.12])


# (A garden's wall a thief mantles from the lane standing, its coping
# 0.1 over it; a gateway's piers and lintel GATEWAY high round its gate.)
YARD_WALL = (2.1, 0.3)
GATEWAY = (2.7, 0.45)
YARD_GATE = 2.2


def yard_front(width, live=False):
    """A light plot's front on its lane: a whitewashed wall `width` along x
    YARD_WALL high, its face at z 0, a coping; in its middle a gateway, its
    piers and lintel GATEWAY high round a barred gate YARD_GATE high (`live`,
    a gate a man walks through: its door hung by the layout)."""
    name = "yard_front_%d%s" % (_cm(width), "_gate" if live else "")

    if name in k.PIECES:
        return name

    h, t = YARD_WALL
    high, pier = GATEWAY
    gate = town.Opening(0.0, 0.0, min(1.4, width - 1.0), YARD_GATE, "door" if live else "barred")
    pier = min(pier, (width - gate.width) / 2.0)
    span = gate.width + 2.0 * pier
    shapes, cols = town.wall(span, high, t, [gate], "whitewash", (0.0, -t / 2.0, 0.0), frames=False)
    shapes.append(ks.box(0.0, high + 0.05, -t / 2.0, span + 0.04, 0.1, t + 0.1, "granite"))
    cols.append(town.col(0.0, high + 0.05, -t / 2.0, span + 0.04, 0.1, t + 0.1))
    run = (width - span) / 2.0

    # (Its runs either side of the gateway, low.)
    if run > 0.01:
        for s in (-1.0, 1.0):
            x = s * (span + run) / 2.0
            body = (x, h / 2.0, -t / 2.0, run, h, t)
            coping = (x, h + 0.05, -t / 2.0, run + 0.02, 0.1, t + 0.1)
            shapes += [ks.box(*body, "whitewash"), ks.box(*coping, "granite")]
            cols += [town.col(*body), town.col(*coping)]

    keys = {"doors": [[0.0, 0.0, -t / 2.0, 0.0, gate.width, gate.height]]} if live else {}
    return _register(name, "wall", "whitewash", shapes, cols, [width, high + 0.1, t + 0.1], **keys)


def garden_wall(length):
    """A walled garden's end: a whitewashed wall `length` along x YARD_WALL
    high about z 0, a granite coping, shut."""
    name = "garden_wall_%d" % _cm(length)

    if name in k.PIECES:
        return name

    h, t = YARD_WALL
    body = (0.0, h / 2.0, 0.0, length, h, t)
    coping = (0.0, h + 0.05, 0.0, length + 0.04, 0.1, t + 0.1)
    shapes = [ks.box(*body, "whitewash"), ks.box(*coping, "granite")]
    return _register(name, "wall", "whitewash", shapes, [town.col(*body), town.col(*coping)], [length + 0.04, h + 0.1, t + 0.1])


HEDGE = (2.4, 0.8)


def garden_glimpse(width, depth):
    """What a barred gate shows of a garden beyond it: gravel `width` along
    x from the gate (z 0) back to -depth, its top at 0, box hedges HEDGE
    high and thick along its back and both sides."""
    name = "garden_glimpse_%d_%d" % (_cm(width), _cm(depth))

    if name in k.PIECES:
        return name

    h, t = HEDGE
    boxes = [((0.0, -0.1, -depth / 2.0, width, 0.2, depth), "gravel"),
             ((0.0, h / 2.0, -depth + t / 2.0, width, h, t), "hedge"),
             ((-width / 2.0 + t / 2.0, h / 2.0, -(depth - t) / 2.0, t, h, depth - t), "hedge"),
             ((width / 2.0 - t / 2.0, h / 2.0, -(depth - t) / 2.0, t, h, depth - t), "hedge")]
    shapes = [ks.box(*box, slot) for box, slot in boxes]
    return _register(name, "wall", "hedge", shapes, [town.col(*box) for box, _slot in boxes], [width, h, depth])


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


def _bed(width, length, ledge, y, z, add):
    """A tunnel's floor `length` long about z at y: a ledge walk beside a
    channel CHANNEL deep (the ledge's top at y), or flagstones."""
    r = width / 2.0

    if ledge:
        lx = r - ledge / 2.0
        add((lx, y - 0.15, z, ledge, 0.3, length), "flagstone")
        add((-ledge / 2.0, y - CHANNEL - 0.15, z, width - ledge, 0.3, length), "stone_moss")
        add((r - ledge - 0.05, y - CHANNEL / 2.0, z, 0.1, CHANNEL, length), "stone_moss")
    else:
        add((0.0, y - 0.15, z, width + 2.0 * VAULT_WALL, 0.3, length), "flagstone")


def vault(width, height, length, ledge=0.0, prefix="vault", slot="brick", door=0.0):
    """A vaulted tunnel along z, `width` clear between its walls, `height`
    clear at its crown (a round barrel over walls up to its springing), its
    floor's top at 0; with a `ledge` (a walkway that wide along its +x side)
    the rest is a channel CHANNEL deep for the layout's water; `ledge` is
    the walkway's middle. With a `door` (its width), a square chamber where
    a cellar opens onto it: upright walls, a flat roof, its ends closed round
    the barrel, a doorway STREAM_DOOR high through its +x wall at z 0."""
    name = "%s_%d_%d_%d%s%s" % (prefix, _cm(width), _cm(height), _cm(length), "_ledge%d" % _cm(ledge) if ledge else "",
                                "_door%d" % _cm(door) if door else "")

    if name in k.PIECES:
        return name

    r = width / 2.0
    spring = height - r
    shapes, cols = [], []

    def add(box, slot_of, roll=0.0):
        shapes.append(ks.box(*box, slot_of, 0.0, 0.0, roll))
        cols.append(town.col(*box, "stone", 0.0, 0.0, roll))

    _bed(width, length, ledge, 0.0, 0.0, add)
    foot = -CHANNEL if ledge else 0.0
    keys = {"ledge": r - ledge / 2.0} if ledge else {}

    if door:
        outer = width + 2.0 * VAULT_WALL
        x = r + VAULT_WALL / 2.0
        top = min(STREAM_DOOR, height - 0.2)
        side = (length - door) / 2.0
        add((-x, (foot + height) / 2.0, 0.0, VAULT_WALL, height - foot, length), slot)

        for sz in (-1.0, 1.0):
            add((x, (foot + height) / 2.0, sz * (door + side) / 2.0, VAULT_WALL, height - foot, side), slot)

        add((x, (top + height) / 2.0, 0.0, VAULT_WALL, height - top, door), slot)
        add((x, (foot - 0.02) / 2.0, 0.0, VAULT_WALL, -foot - 0.02, door), slot)
        # (Its threshold, flush with the ledge.)
        add((x, -0.15, 0.0, VAULT_WALL, 0.3, door), "granite")
        add((0.0, height + 0.15, 0.0, outer, 0.3, length), slot)

        for sz in (-1.0, 1.0):
            shapes += ks.arched_wall(outer, height + 0.3, 0.1, width, spring, r, 0.0, slot, z=sz * (length / 2.0 - 0.05))

        keys["door"] = [x, 0.0, 0.0, 90.0]
        return _register(name, "vault", slot, shapes, cols, [outer, height + 0.5, length], **keys)

    for s in (-1.0, 1.0):
        add((s * (r + VAULT_WALL / 2.0), (foot + spring) / 2.0, 0.0, VAULT_WALL, spring - foot, length), slot)

    # The barrel: five slabs round its half-circle, tangent to it.
    segments = 5
    chord = 2.0 * r * math.sin(math.pi / (2.0 * segments)) * 1.08

    for i in range(segments):
        theta = math.pi * (i + 0.5) / segments
        cx, cy = math.cos(theta) * (r + 0.15), spring + math.sin(theta) * (r + 0.15)
        add((cx, cy, 0.0, chord, 0.3, length), slot, math.degrees(theta) - 90.0)

    return _register(name, "vault", slot, shapes, cols, [width + 2.0 * VAULT_WALL, height + 0.5, length], **keys)


def cascade(width, height, drop, ledge=0.8, slot="brick", up=1.0):
    """Where a vaulted stream `width` x `height` (its `ledge` walk along +x)
    steps up `drop`: a chamber CASCADE long about z 0, square in section,
    the lower tunnel's floor (0) to -z, the upper's (drop) to +z, the step
    between them at z 0 with the water falling down it over the channel and
    a ladder up it beside the ledge; its ends closed round the barrels; its
    `ledge` (the walk's middle), `climbs` and `tour` up it. `up` -1: the
    upper tunnel to -z (its ledge still along +x)."""
    name = "cascade_%d_%d_%d_ledge%d%s" % (_cm(width), _cm(height), _cm(drop), _cm(ledge), "_n" if up < 0 else "")

    if name in k.PIECES:
        return name

    r = width / 2.0
    half = CASCADE / 2.0
    outer = width + 2.0 * VAULT_WALL
    lx = r - ledge / 2.0
    roof = drop + height
    shapes, cols = [], []

    def add(box, slot_of, roll=0.0):
        shapes.append(ks.box(*box, slot_of, 0.0, 0.0, roll))
        cols.append(town.col(*box, "stone", 0.0, 0.0, roll))

    _bed(width, half, ledge, 0.0, -up * half / 2.0, add)
    _bed(width, half, ledge, drop, up * half / 2.0, add)
    # (The step under the upper floor: brick from the lower channel's bed up.)
    base = -CHANNEL - 0.3
    add((lx, (base + drop - 0.3) / 2.0, up * half / 2.0, ledge, drop - 0.3 - base, half), slot)
    add((-ledge / 2.0, (base + drop - CHANNEL - 0.3) / 2.0, up * half / 2.0, width - ledge, drop - CHANNEL - 0.3 - base, half), slot)

    for sx in (-1.0, 1.0):
        add((sx * (r + VAULT_WALL / 2.0), (base + roof) / 2.0, 0.0, VAULT_WALL, roof - base, CASCADE), slot)

    add((0.0, roof + 0.15, 0.0, outer, 0.3, CASCADE), slot)
    shapes += ks.arched_wall(outer, roof + 0.3, 0.1, width, height - r, r, 0.0, slot, z=-up * (half - 0.05))
    shapes += ks.arched_wall(outer, height + 0.3, 0.1, width, height - r, r, 0.0, slot, z=up * (half - 0.05), y=drop)
    # (The fall: a sheet of water down the step over the channel, the step's
    # face wet under it.)
    low, high = -CHANNEL + 0.4, drop - CHANNEL + 0.4
    shapes.append(ks.card(-ledge / 2.0, (low + high) / 2.0, -up * 0.06, width - ledge, high - low + 0.1, "glass_dark"))
    shapes.append(ks.card(-ledge / 2.0, (base + high) / 2.0, -up * 0.02, width - ledge, high - base, "waterline_algae"))
    # (The ladder up the step beside the ledge: rails and rungs.)
    shapes += [ks.box(lx + sx * 0.22, (drop + 0.9) / 2.0, -up * 0.06, 0.05, drop + 0.9, 0.05, "iron") for sx in (-1.0, 1.0)]
    shapes += [ks.box(lx, 0.3 * (i + 1), -up * 0.06, 0.44, 0.03, 0.03, "iron") for i in range(int((drop + 0.6) / 0.3))]
    climbs = [[lx, (drop + 0.6) / 2.0, -up * 0.2, 0.8, drop + 0.6, 0.8, 0.0]]
    tour = [[lx, 0.0, -up * (half - 0.2), "walk"], [lx, 0.0, -up * 0.5, "walk"], [lx, drop, up * 0.5, "climb"], [lx, drop, up * (half - 0.2), "walk"]]
    return _register(name, "vault", slot, shapes, cols, [outer, roof - base + 0.3, CASCADE], ledge=lx, climbs=climbs, tour=tour)


def cistern(length):
    """A cistern's vault (an aljibe), 3.0 wide and high, its walkway along
    its water."""
    return vault(3.0, 3.0, length, ledge=0.8, prefix="cistern", slot="stone_moss")


def grate_hatch(depth, collar=0.0):
    """A way down from the street `depth` deep: a shaft SHAFT square, its
    ladder drawn down a wall from its foot to the street (its climb over
    the street), the grate lifted aside, nothing across its mouth; with a
    `collar`, the paving round it that wide (or (across x, along z): a
    ground's cell longer one way), COLLAR_PROUD over the street (the
    ground's hole is whole cells)."""
    cx, cz = collar if isinstance(collar, (tuple, list)) else (collar, collar)
    tag = "" if not cx else "_c%d" % _cm(cx) if abs(cx - cz) < 1e-9 else "_c%dx%d" % (_cm(cx), _cm(cz))
    name = "grate_hatch_%d%s" % (_cm(depth), tag)

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

    if cx:
        ax, az, inner = cx / 2.0, cz / 2.0, SHAFT / 2.0 + t
        y, h = top - 0.125, 0.25

        # (Paved as the street round it.)
        for box in ((0.0, y, (inner + az) / 2.0, cx, h, az - inner), (0.0, y, -(inner + az) / 2.0, cx, h, az - inner),
                    ((inner + ax) / 2.0, y, 0.0, ax - inner, h, 2.0 * inner), (-(inner + ax) / 2.0, y, 0.0, ax - inner, h, 2.0 * inner)):
            add(box, "calcada")

    # (The grate's iron rim round the mouth, the grate leant aside on its
    # -z side: a man takes hold from -x and climbs out to +x.)
    rim = SHAFT / 2.0 + 0.05
    shapes += [ks.box(0.0, top + 0.01, s * rim, SHAFT + 0.2, 0.03, 0.1, "iron") for s in (-1.0, 1.0)]
    shapes += [ks.box(s * rim, top + 0.01, 0.0, 0.1, 0.03, SHAFT, "iron") for s in (-1.0, 1.0)]
    # (The grate dragged off it onto the paving: a frame, bars both ways,
    # solid underfoot.)
    near = SHAFT / 2.0 + t + GRATE_GAP
    mid = -(near + SHAFT / 2.0)
    frame, bar, high = 0.06, 0.03, 0.05
    shapes += [ks.box(s * (SHAFT - frame) / 2.0, top + high / 2.0, mid, frame, high, SHAFT, "iron") for s in (-1.0, 1.0)]
    shapes += [ks.box(0.0, top + high / 2.0, mid + s * (SHAFT - frame) / 2.0, SHAFT - 2.0 * frame, high, frame, "iron") for s in (-1.0, 1.0)]

    for i in range(1, GRATE_BARS + 1):
        at = -SHAFT / 2.0 + SHAFT * i / (GRATE_BARS + 1)
        shapes += [ks.box(at, top + high / 2.0, mid, bar, high * 0.8, SHAFT - 2.0 * frame, "iron"),
                   ks.box(0.0, top + high / 2.0, mid + at, SHAFT - 2.0 * frame, high * 0.8, bar, "iron")]

    cols.append(town.col(0.0, top + high / 2.0, mid, SHAFT, high, SHAFT, "metal"))

    # (The ladder down its +x wall: two rails, a rung every 0.3 m.)
    wall_x = SHAFT / 2.0 - 0.06
    shapes += [ks.box(wall_x, (top - depth) / 2.0, s * 0.22, 0.05, depth + top, 0.05, "iron") for s in (-1.0, 1.0)]
    shapes += [ks.box(wall_x, -depth + 0.3 * (i + 1), 0.0, 0.03, 0.03, 0.44, "iron") for i in range(int((depth + top) / 0.3))]
    # (Its climb faces the ladder (its normal -x), across the shaft and out
    # over the street on its -x side, where a man takes hold of it; its
    # plane the ladder's wall, behind the box's middle.)
    reach = SHAFT + 0.6
    climbs = [[SHAFT / 2.0 - reach / 2.0, (-depth + 0.6) / 2.0, 0.0, SHAFT, depth + 0.6, reach, -90.0, 0.0, {"plane_back": reach / 2.0}]]
    return _register(name, "vault", "stone_moss", shapes, cols, [max(cx, SHAFT + 2.0 * t), depth, max(cz, SHAFT + 2.0 * t)], climbs=climbs)


def hatch_chamber(width, height, length, ledge=0.0):
    """Where a hatch's shaft comes down into a vault `width` x `height`: a
    chamber `length` long, square in section, its walls the vault's, a flat
    roof (its top `roof`) with the shaft's hole SHAFT square against its +x
    wall (the hatch over it stands SHAFT/2 - width/2 off the vault's axis),
    a ladder up that wall; each end walled round the vault's barrel (its
    arch open). With a `ledge` (a stream's), its floor the stream's, the
    channel running on through it under the ledge's walk."""
    name = "hatch_chamber_%d_%d_%d%s" % (_cm(width), _cm(height), _cm(length), "_ledge%d" % _cm(ledge) if ledge else "")

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

    _bed(width, length, ledge, 0.0, 0.0, add)
    foot = -CHANNEL if ledge else 0.0

    for s in (-1.0, 1.0):
        add((s * (r + VAULT_WALL / 2.0), (foot + height) / 2.0, 0.0, VAULT_WALL, height - foot, length), "brick")
        # (The roof round the hole: across its ends, then either side of it.)
        add((0.0, height + 0.15, s * (hole + length / 2.0) / 2.0, outer, 0.3, length / 2.0 - hole), "brick")
        shapes += ks.arched_wall(outer, roof, 0.1, width, height - r, r, 0.0, "brick", z=s * (length / 2.0 - 0.05))

    add(((-outer / 2.0 + west) / 2.0, height + 0.15, 0.0, west + outer / 2.0, 0.3, 2.0 * hole), "brick")
    add(((r + outer / 2.0) / 2.0, height + 0.15, 0.0, outer / 2.0 - r, 0.3, 2.0 * hole), "brick")
    # (The ladder up its +x wall: rails and rungs.)
    wall_x = r - 0.06
    shapes += [ks.box(wall_x, roof / 2.0, s * 0.22, 0.05, roof, 0.05, "iron") for s in (-1.0, 1.0)]
    shapes += [ks.box(wall_x, 0.3 * (i + 1), 0.0, 0.03, 0.03, 0.44, "iron") for i in range(int(roof / 0.3))]
    climbs = [[r - 0.4, roof / 2.0, 0.0, SHAFT, roof + 0.2, 0.8, -90.0]]
    return _register(name, "vault", "brick", shapes, cols, [outer, roof, length], climbs=climbs, roof=roof)


def vault_end(width, height, channel=False):
    """A vault `width` x `height` walled up at its end (the wall 0.3 thick
    about z 0), an iron grating in it over the dark; down past a stream's
    `channel` too."""
    name = "vault_end_%d_%d%s" % (_cm(width), _cm(height), "_ch" if channel else "")

    if name in k.PIECES:
        return name

    outer = width + 2.0 * VAULT_WALL
    foot = -CHANNEL - 0.3 if channel else -0.3
    box = (0.0, (height + 0.5 + foot) / 2.0, 0.0, outer, height + 0.5 - foot, 0.3)
    shapes = [ks.box(*box, "brick"), ks.card(0.0, 1.0, 0.17, 1.2, 1.4, "pitch"), ks.card(0.0, 1.0, 0.19, 1.2, 1.4, "window_grille")]
    return _register(name, "vault", "brick", shapes, [town.col(*box)], [outer, height + 0.5, 0.3])


def scaffold(height, width):
    """A builder's scaffold `width` wide up a front whose eaves are `height`
    up (its back on the wall at z 0, standing out to +z): poles, a deck
    every LIFT to the last under the eaves (`top`), DECK_OFF off the wall
    (clear of its balconies) and DECK deep, a rail along its front; ladders
    between them turn about at its ends, each at the street's edge of a hole
    LADDER_HOLE deep and LADDER_HOLE_ALONG long at the deck's back, its climber behind it in the hole
    (held CLIMB_HOLD off it) and up off its top forward onto the deck's
    front walk (DECK_WALK deep, a man stands there). Its `tour` from the
    street to the top deck."""
    name = "scaffold_%d_%d" % (_cm(height), _cm(width))

    if name in k.PIECES:
        return name

    lifts = int((height - 0.1) / LIFT)
    top = lifts * LIFT
    z0, z1 = DECK_OFF, DECK_OFF + DECK
    plane = z0 + LADDER_HOLE
    walk, held = plane + DECK_WALK / 2.0, plane - CLIMB_HOLD
    half = width / 2.0
    side = half - LADDER_HOLE_ALONG / 2.0 - 0.1
    shapes, cols = [], []

    def add(box, slot, solid=True):
        shapes.append(ks.box(*box, slot))

        if solid:
            cols.append(town.col(*box, "wood"))

    for x in (-half, 0.0, half):
        for z in (z0, z1):
            add((x, (top + 1.2) / 2.0, z, 0.08, top + 1.2, 0.08), "timber", x != 0.0 or z == z1)

    climbs = []
    ladder_x = [(side if n % 2 == 0 else -side) for n in range(lifts)]
    # (Round a ladder's end, from its deck's front walk to behind it.)
    round_x = [x - (1.0 if x > 0.0 else -1.0) for x in ladder_x]
    tour = [[ladder_x[0], 0.0, z1 + 1.0, "walk"], [round_x[0], 0.0, z1 - 0.5, "walk"], [round_x[0], 0.0, held, "walk"],
            [ladder_x[0], 0.0, held, "walk"]]

    for n in range(1, lifts + 1):
        y = n * LIFT
        below = ladder_x[n - 1]
        h0, h1 = below - LADDER_HOLE_ALONG / 2.0, below + LADDER_HOLE_ALONG / 2.0
        zm = (z0 + z1) / 2.0
        # (The deck round the hole the ladder from under it comes up through,
        # at its back: either side of it, and its front walk before it.)
        for a, b in ((-half, h0), (h1, half)):
            if b - a > 0.01:
                add(((a + b) / 2.0, y - 0.04, zm, b - a, 0.08, DECK), "boards")

        add((below, y - 0.04, (plane + z1) / 2.0, LADDER_HOLE_ALONG, 0.08, z1 - plane), "boards")
        add((0.0, y + 1.0, z1 - 0.04, width, 0.06, 0.06), "timber")
        # (The ladder up to it from the deck under it at the hole's street
        # edge, its rails and rungs to the deck (nothing over it to go round
        # going off it forward); solid, what its climber is held to.)
        y0 = y - LIFT
        rungs = plane + 0.03
        shapes += [ks.box(below + s * 0.25, (y0 + y) / 2.0, rungs, 0.06, LIFT, 0.06, "timber") for s in (-1.0, 1.0)]
        shapes += [ks.box(below, y0 + 0.3 * (i + 1), rungs, 0.5, 0.04, 0.04, "timber") for i in range(int((LIFT - 0.1) / 0.3))]
        cols.append(town.col(below, (y0 + y) / 2.0, rungs, 0.56, LIFT, 0.06, "wood"))
        # (Its climb faces the house (normal -z), its plane on the ladder.)
        climbs.append([below, y0 + (LIFT + 0.6) / 2.0, plane - 0.4, 1.0, LIFT + 0.6, 1.2, 180.0, 0.0, {"plane_back": 0.4}])
        tour.append([below, y, walk, "climb"])

        if n < lifts:
            tour += [[round_x[n], y, walk, "walk"], [round_x[n], y, held, "walk"], [ladder_x[n], y, held, "walk"]]

    tour.append([0.0, top, walk, "walk"])
    # (Half a house's front of timber: its own budget.)
    return _register(name, "street", "timber", shapes, cols, [width + 0.2, top + 1.2, z1 + 0.1], climbs=climbs, tour=tour, top=top, budget=1500)



def wall_steps(rise, run, width):
    """A straight stone stair `width` wide up `rise` over `run` along +z
    from its foot at the origin, solid under its steps (a wall's inner face
    along its +x side): steps of about RISER, a landing WALL_LANDING deep at
    its head (`head` [0, rise, run]) walled across its end and along its
    -x side, a raking parapet along that side the length of its steps; its
    `tour` up it. Off its landing to +x, the wall's walk."""
    name = "wall_steps_%d_%d_%d" % (_cm(rise), _cm(run), _cm(width))

    if name in k.PIECES:
        return name

    steps = int(math.ceil(rise / RISER - 1e-9))
    riser = rise / steps
    flight = run - WALL_LANDING
    tread = flight / steps
    shapes, cols = [], []

    def add(box, slot, pitch=0.0):
        shapes.append(ks.box(*box, slot, 0.0, pitch, 0.0))
        cols.append(town.col(*box, "stone", 0.0, pitch, 0.0))

    for i in range(steps):
        top = (i + 1) * riser
        add((0.0, top / 2.0, i * tread + tread / 2.0, width, top, tread), "stair_stone")

    add((0.0, rise / 2.0, run - WALL_LANDING / 2.0, width, rise, WALL_LANDING), "stair_stone")
    t, h = RAIL
    # (A hair proud of the steps' open side: no two faces on one plane.)
    x = -width / 2.0 + t / 2.0 - RAIL_PROUD
    # (Its parapet rakes with the steps' nosings, as high over them as a
    # landing's is.)
    pitch = math.degrees(math.atan2(rise, flight))
    add((x, rise / 2.0, flight / 2.0, t, 2.0 * h, math.hypot(flight, rise)), "ashlar_weathered", -pitch)
    add((x, rise + h / 2.0, run - WALL_LANDING / 2.0, t, h, WALL_LANDING), "ashlar_weathered")
    add((t / 2.0, rise + h / 2.0, run - t / 2.0, width - t, h, t), "ashlar_weathered")
    side = t / 2.0 + 0.1
    tour = [[side, 0.0, -0.6, "walk"], [side, riser, tread / 2.0, "stairs"], [side, rise, flight - tread / 2.0, "stairs"],
            [side, rise, run - WALL_LANDING / 2.0 - 0.1, "walk"]]
    # (Twelve triangles a step, a hundred for its landing and parapets.)
    return _register(name, "stair", "granite", shapes, cols, [width, rise + h, run], head=[0.0, rise, run], tour=tour, budget=12 * steps + 100)


def _along(yaw, z):
    """Where along a wall turned `yaw` (its length on its own x) a point at
    the piece's z falls."""
    import geo
    return z / geo.apply(geo.rotation(yaw), [1.0, 0.0, 0.0])[2]


def stair_tower(height):
    """A stair tower up a cliff `height` high: its back (-x) against the
    cliff's face, its length along it (z). Its door on the street at its
    foot through its +x face; a switchback inside, flights of at most
    TOWER_STEPS either side of a spine wall, a landing at each end; its door
    at the top through its back onto the terrace over the cliff; a top
    storey TOWER_TOP high under a hipped roof, slits up its faces. Its
    `foot` and `top` (outside its doorways), `arches` (its doorways, open:
    no leaf), `tour` up it."""
    name = "stair_tower_%d" % _cm(height)

    if name in k.PIECES:
        return name

    per = min(TOWER_STEPS, int(math.ceil(height / RISER - 1e-9)))
    flights = int(math.ceil(height / (per * RISER) - 1e-9))
    riser = height / (flights * per)
    run = per * TOWER_TREAD
    w = TOWER_WALL
    inner_x = 2.0 * TOWER_FLIGHT + TOWER_SPINE
    inner_z = run + 2.0 * TOWER_LANDING
    outer_x, outer_z = inner_x + 2.0 * w, inner_z + 2.0 * w
    eaves = height + TOWER_TOP
    lift = per * riser
    middle = TOWER_SPINE / 2.0 + TOWER_FLIGHT / 2.0
    shapes, cols = [], []

    def add(box, slot):
        shapes.append(ks.box(*box, slot))
        cols.append(town.col(*box))

    def end(n):
        """The landing flight n sets off from: -z for even, +z for odd."""
        return -1.0 if n % 2 == 0 else 1.0

    land_z = run / 2.0 + TOWER_LANDING / 2.0
    # (Its floor, lifted off the street that runs on under it.)
    add((0.0, town.GROUND_LIFT - 0.15, 0.0, inner_x, 0.3, inner_z), "stair_stone")

    for n in range(1, flights + 1):
        y = n * lift
        add((0.0, y - 0.15, end(n) * land_z, inner_x, 0.3, TOWER_LANDING), "stair_stone")

    for n in range(flights):
        sx, dz = (1.0, 1.0) if n % 2 == 0 else (-1.0, -1.0)
        y0 = n * lift

        for i in range(per):
            top = y0 + (i + 1) * riser
            z = -dz * run / 2.0 + dz * (i + 0.5) * TOWER_TREAD
            low = 0.0 if n == 0 else top - 0.35
            add((sx * middle, (low + top) / 2.0, z, TOWER_FLIGHT, top - low, TOWER_TREAD), "stair_stone")

    add((0.0, height / 2.0, 0.0, TOWER_SPINE, height, run), "ashlar_weathered")
    # (The top landing's edge over the well, railed where no flight comes up.)
    last = flights - 1
    rail_x = 1.0 if last % 2 == 1 else -1.0
    rail_z = end(flights) * run / 2.0
    add((rail_x * middle, height + 0.5, rail_z - end(flights) * 0.05, TOWER_FLIGHT, 1.0, 0.1), "timber")
    shapes.append(ks.box(0.0, eaves - 0.1, 0.0, inner_x, 0.2, inner_z, "boards"))
    cols.append(town.col(0.0, eaves - 0.1, 0.0, inner_x, 0.2, inner_z))
    # (Its walls: the long ones run the full length, the ends between them.)
    foot_z, top_z = end(0) * land_z, end(flights) * land_z
    door_w, door_h = k.DOOR
    slits = [height * f for f in (0.2, 0.45, 0.7)]
    walls = (((outer_x - w) / 2.0, 90.0, outer_z, [town.Opening(_along(90.0, foot_z), 0.0, door_w, door_h, "door")]
              + [town.Opening(_along(90.0, -foot_z), y, 0.3, 1.0, "barred") for y in slits]),
             (-(outer_x - w) / 2.0, -90.0, outer_z, [town.Opening(_along(-90.0, top_z), height, door_w, door_h, "door"),
                                                     town.Opening(_along(-90.0, -top_z), height + 0.9, 0.6, 1.0, "barred")]))

    for x, yaw, length, openings in walls:
        s, c = town.wall(length, eaves, w, openings, "ashlar_weathered", (x, 0.0, yaw), inside=True, frames=False)
        shapes, cols = shapes + s, cols + c

    for sz in (-1.0, 1.0):
        openings = [town.Opening(0.0, y + 1.0, 0.3, 1.0, "barred") for y in slits[1:]]
        s, c = town.wall(inner_x, eaves, w, openings, "ashlar_weathered", (0.0, sz * (outer_z - w) / 2.0, 0.0 if sz > 0 else 180.0), inside=True,
                         frames=False)
        shapes, cols = shapes + s, cols + c

    rs, rc = town.roof("hipped", outer_x, outer_z, eaves, 30.0, "ashlar_weathered")
    shapes, cols = shapes + rs, cols + rc
    doors = [[(outer_x - w) / 2.0, 0.0, foot_z, 90.0], [-(outer_x - w) / 2.0, height, top_z, -90.0]]
    foot = [outer_x / 2.0 + 1.0, 0.0, foot_z]
    top = [-outer_x / 2.0 - 1.0, height, top_z]
    tour = [foot + ["walk"], [middle, town.GROUND_LIFT, foot_z, "walk"]]

    for n in range(flights):
        sx, dz = (1.0, 1.0) if n % 2 == 0 else (-1.0, -1.0)
        y0 = n * lift
        tour += [[sx * middle, y0 + riser, -dz * run / 2.0 + dz * TOWER_TREAD / 2.0, "stairs"],
                 [sx * middle, y0 + lift, dz * run / 2.0 - dz * TOWER_TREAD / 2.0, "stairs"],
                 [sx * middle, y0 + lift, dz * land_z, "walk"]]

        # (Across the landing round the spine's end to the next flight.)
        if n < flights - 1:
            tour.append([0.0, y0 + lift, dz * land_z, "walk"])

    tour += [[-middle, height, top_z, "walk"], top + ["walk"]]
    budget = 1500 + 30 * flights * per
    # (Its doorways open arches: a leaf swung in across a landing shuts the
    # flight off.)
    return _register(name, "town", "ashlar_weathered", shapes, cols, [outer_x, eaves + 3.0, outer_z], arches=doors, foot=foot, top=top, tour=tour,
                     budget=budget)


def corbels(height):
    """Stone corbels up a cliff's face `height` high (the face at z 0, the
    drop to +z): CORBEL out from it, each at most CORBEL_RISE over the one
    under it (the first over the street's foot), zig-zagging CORBEL_SWAY
    either side of the line so none is over a man's head on the one under
    it; the last a CORBEL_RISE under the cliff's top. Its `tops` (where a
    man stands on each)."""
    name = "corbels_%d" % _cm(height)

    if name in k.PIECES:
        return name

    count = int(math.ceil(height / CORBEL_RISE - 1e-9))
    rise = height / count
    along, out, thick = CORBEL
    shapes, cols, tops = [], [], []

    for i in range(1, count):
        top = i * rise
        x = CORBEL_SWAY if i % 2 else -CORBEL_SWAY

        for box in ((x, top - thick / 2.0, out / 2.0, along, thick, out), (x, top - thick - 0.15, out * 0.3, along * 0.8, 0.3, out * 0.6)):
            shapes.append(ks.box(*box, "granite"))
            cols.append(town.col(*box))

        tops.append([x, top, out * 0.6])

    return _register(name, "wall", "granite", shapes, cols, [2.0 * CORBEL_SWAY + along, height, out], tops=tops)


# (Its underside never over 1.3 m above what a man stands on under it: the
# controller's head meets a higher overhang before its face, and takes it
# for a stair.)
LEDGE = (1.6, 1.2, 0.7)
LEDGE_RISE = 2.0


# A buttress against a high cliff: its stages (up to a share of its height,
# width along the face, depth out from it), each set back from the one under
# it; its top this far under the cliff's.
BUTTRESS_STAGES = ((0.4, 1.8, 1.3), (0.75, 1.5, 0.9), (1.0, 1.2, 0.55))
BUTTRESS_UNDER = 0.6


def buttress(height):
    """A granite buttress against a cliff's face `height` high (the face at
    z 0, out to +z): BUTTRESS_STAGES, each shallower than the one under it,
    a weathered setback on each, its top BUTTRESS_UNDER under the cliff's."""
    name = "buttress_%d" % _cm(height)

    if name in k.PIECES:
        return name

    shapes, cols = [], []
    y0, top = 0.0, height - BUTTRESS_UNDER

    for share, width, depth in BUTTRESS_STAGES:
        y1 = top * share
        box = (0.0, (y0 + y1) / 2.0, depth / 2.0, width, y1 - y0, depth)
        shapes.append(ks.box(*box, "granite_rough"))
        cols.append(town.col(*box))
        # (Its setback's coping, a little proud.)
        cap = (0.0, y1 - 0.06, depth / 2.0 + 0.03, width + 0.08, 0.12, depth + 0.06)
        shapes.append(ks.box(*cap, "granite"))
        cols.append(town.col(*cap))
        y0 = y1

    return _register(name, "wall", "granite_rough", shapes, cols, [BUTTRESS_STAGES[0][1] + 0.1, height, BUTTRESS_STAGES[0][2] + 0.1])


def ledges(height):
    """Stone ledges up a cliff's face `height` high (the face at z 0, the
    drop to +z): each LEDGE long along the face, out from it and thick (a
    man stands on one: the controller lands a mantle half a metre in and
    needs his body to fit), at most LEDGE_RISE over the last (a mantle),
    marching along +x from x 0 so the next is always straight ahead (not
    zig-zagging back: the one two over would stand over a man mantling).
    The first a mantle from the street, the top a mantle from the last. A bracket under each. Its `tops` (where a man
    stands on each), `span` along the face, `tour` up it (the street in
    front of the first to the top behind the face over the last)."""
    name = "ledges_%d" % _cm(height)

    if name in k.PIECES:
        return name

    along, out, thick = LEDGE
    count = int(math.ceil(height / LEDGE_RISE - 1e-9)) - 1
    rise = height / (count + 1)
    shapes, cols, tops = [], [], []
    tour = [[along / 2.0, 0.0, out + 1.2, "walk"]]

    for i in range(count):
        top = (i + 1) * rise
        x0 = i * along

        for box, slot in (((x0 + along / 2.0, top - thick / 2.0, out / 2.0, along, thick, out), "granite"),
                          ((x0 + along / 2.0, top - thick - 0.2, out * 0.35, along * 0.6, 0.4, out * 0.7), "granite_rough")):
            shapes.append(ks.box(*box, slot))
            cols.append(town.col(*box))

        tops.append([x0 + along / 2.0, top, out / 2.0])

        if i == 0:
            tour.append([along / 2.0, top, out / 2.0, "mantle"])
        else:
            # (From the last one's far end onto this one, straight ahead.)
            tour += [[x0 - 0.55, top - rise, out / 2.0, "walk"], [x0 + 0.6, top, out / 2.0, "mantle"]]

    last = tops[-1]
    tour += [[last[0], last[1], out / 2.0, "walk"], [last[0], height, -0.6, "mantle"]]
    span = count * along
    return _register(name, "wall", "granite", shapes, cols, [span, height, out], tops=tops, tour=tour, span=span,
                     arrival=[last[0], height, -0.6])


# A lead downpipe: its radius, its middle out from the wall; a bracket every
# PIPE_BRACKET up it.
PIPE = (0.055, 0.1)
PIPE_BRACKET = 1.6


def drainpipe(height):
    """A lead downpipe up a wall's face to its eaves `height` up (the face at
    z 0, out to +z): brackets every PIPE_BRACKET, a hopper head under the
    eaves, a shoe at its foot; drawn only (a man walks by it). Its climb from
    the street to the eaves out from the wall, facing out (a thief's way up);
    its `tour` (the street, up it, onto the roof behind its top)."""
    name = "drainpipe_%d" % _cm(height)

    if name in k.PIECES:
        return name

    r, out = PIPE
    foot, head = 0.25, height - 0.55
    shapes = [ks.prism(0.0, (foot + head) / 2.0, out, r, head - foot, 6, "iron"),
              ks.box(0.0, foot / 2.0 + 0.02, out + 0.06, 2.0 * r, foot, 2.0 * r + 0.12, "iron"),
              ks.box(0.0, head + 0.15, out + 0.03, 0.32, 0.3, 0.26, "iron")]
    y = 1.0

    while y < head - 0.3:
        shapes.append(ks.box(0.0, y, out / 2.0, 0.16, 0.05, out + 0.06, "iron"))
        y += PIPE_BRACKET

    climbs = [[0.0, height / 2.0, 0.3, 0.8, height, 0.6, 0.0]]
    # (Its climb point against the wall: up it pushing into it, as one takes hold.)
    tour = [[0.0, 0.0, 1.2, "walk"], [0.0, 0.0, 0.5, "walk"], [0.0, height - 0.6, 0.2, "climb"], [0.0, height, -0.6, "mantle"]]
    return _register(name, "wall", "iron", shapes, [], [0.4, height, 0.4], climbs=climbs, tour=tour)


# Ivy's cards: about this square, the photo's own scale (its leaves never
# stretched), each a little over its cell so they overlap.
IVY_CARD = 1.1
# How far apart its cards are laid: closer than they are big, their clumps
# (each card cut to one, paint.ivy_clump) running together.
IVY_STEP = 0.75


def ivy(width, height):
    """Ivy over a wall's face `width` along x and `height` up (the face at z
    0, out to +z): the user's Ivy0024 cut out ("leaves"), cards IVY_CARD
    about laid over it, a little off the wall and each other, ragged at its
    top; drawn only. Its climb over it, facing out; its `tour` (the street,
    up it, onto what is behind its top)."""
    name = "ivy_%d_%d" % (_cm(width), _cm(height))

    if name in k.PIECES:
        return name

    rng = random.Random(_cm(width) * 31 + _cm(height))
    shapes = []
    rows = max(2, int(math.ceil(height / IVY_STEP)))

    for j in range(rows):
        y = (j + 0.5) * height / rows
        # (Each row reaches out its own way either side, and narrows to a
        # crown over the top third: grown, not a panel.)
        crown = min(1.0, max(0.0, (y - height * 0.65) / (height * 0.35)))
        half = width / 2.0 * (1.0 - 0.55 * crown)
        lo = -half + rng.uniform(-0.35, 0.35)
        hi = half + rng.uniform(-0.35, 0.35)
        across = max(1, int(round((hi - lo) / IVY_STEP)))

        for i in range(across):
            if crown > 0.0 and rng.random() < 0.3 * crown:
                continue

            size = IVY_CARD * rng.uniform(1.0, 1.35)
            x = lo + (hi - lo) * (i + 0.5) / across + rng.uniform(-0.12, 0.12)
            cy = min(y + rng.uniform(-0.15, 0.15), height + 0.3 - size / 2.0)
            # (A third of them leaning off the wall at their top, kept off
            # it at their foot; the rest flat, each a little off the next.)
            pitch = rng.uniform(4.0, 6.0) if rng.random() < 0.35 else 0.0
            z = 0.03 + math.sin(math.radians(pitch)) * size / 2.0 if pitch else 0.03 + 0.012 * ((i + 2 * j) % 6)
            shapes.append(ks.card(x, cy, z, size * rng.uniform(0.95, 1.05), size, "leaves", 0.0, -pitch))

    climbs = [[0.0, height / 2.0, 0.3, width, height, 0.6, 0.0]]
    # (Its climb point against the wall: up it pushing into it, as one takes hold.)
    tour = [[0.0, 0.0, 1.2, "walk"], [0.0, 0.0, 0.5, "walk"], [0.0, height - 0.6, 0.2, "climb"], [0.0, height, -0.6, "mantle"]]
    return _register(name, "wall", "leaves", shapes, [], [width, height, 0.2], climbs=climbs, tour=tour)


def postern(height, thick, length=6.0):
    """A city wall's footing `length` along x, `height` up, `thick` through
    z (as footing), with a postern's passage into it from its +z face: a
    door's width and height, POSTERN_DEPTH deep, its gate swung open
    against its side, dark past it (the way on through the wall: an exit);
    a granite surround round it. Its `door` [x, y, z]: the passage's mouth."""
    name = "postern_%d_%d_%d" % (_cm(length), _cm(height), _cm(thick))

    if name in k.PIECES:
        return name

    door_w, door_h = k.DOOR
    face = thick / 2.0
    back = face - POSTERN_DEPTH
    side = (length - door_w) / 2.0
    shapes, cols = [], []

    def add(box, slot):
        shapes.append(ks.box(*box, "granite_rough" if slot is None else slot))
        cols.append(town.col(*box))

    for sx in (-1.0, 1.0):
        add((sx * (door_w + side) / 2.0, height / 2.0, 0.0, side, height, thick), None)

    add((0.0, (door_h + height) / 2.0, 0.0, door_w, height - door_h, thick), None)
    add((0.0, door_h / 2.0, (back - face) / 2.0, door_w, door_h, back + face), None)
    add((0.0, 0.02, (back + face) / 2.0, door_w, 0.04, POSTERN_DEPTH), "granite")
    shapes += [ks.card(0.0, door_h / 2.0, back + 0.02, door_w, door_h, "pitch"),
               ks.card(-door_w / 2.0 + 0.04, door_h / 2.0, face - door_w / 2.0 - 0.05, door_w, door_h - 0.05, "window_grille", 90.0)]
    shapes += [ks.box(sx * (door_w / 2.0 + 0.15), door_h / 2.0, face + 0.05, 0.3, door_h, 0.1, "granite") for sx in (-1.0, 1.0)]
    shapes.append(ks.box(0.0, door_h + 0.2, face + 0.06, door_w + 0.6, 0.4, 0.12, "granite"))
    return _register(name, "wall", "granite_rough", shapes, cols, [length, height, thick + 0.2], door=[0.0, 0.0, face])


# A tannery's vats: outside across, their rim's thickness, their rim's
# height, their liquor's; their rows and columns' spacing.
VAT = (1.8, 0.2, 0.6, 0.45)
VAT_SPACING = 3.2


def tannery():
    """A tannery's yard about the origin (its back wall to -z): six vats of
    liquor in two columns a man walks between, two racks of hides drying
    along its +x side, a lean-to against its back wall over its -x half;
    its `vats` ([x, z]) and `work` (the tanners' spot among the vats)."""
    name = "tannery"

    if name in k.PIECES:
        return name

    outer, rim, high, liquor = VAT
    shapes, cols, vats = [], [], []

    def add(box, slot, solid=True):
        shapes.append(ks.box(*box, slot))

        if solid:
            cols.append(town.col(*box))

    for cx in (-3.6, -3.6 + VAT_SPACING):
        for cz in (-VAT_SPACING, 0.0, VAT_SPACING):
            vats.append([cx, cz])
            inner = outer - 2.0 * rim

            for sx, sz, w, d in ((0.0, 1.0, outer, rim), (0.0, -1.0, outer, rim), (1.0, 0.0, rim, inner), (-1.0, 0.0, rim, inner)):
                add((cx + sx * (outer - rim) / 2.0, high / 2.0, cz + sz * (outer - rim) / 2.0, w, high, d), "granite_rough")

            # (The liquor, stood in to the knee: solid to its face.)
            add((cx, liquor / 2.0, cz, inner, liquor, inner), "tannery_liquor")

    for rx in (3.4, 5.2):
        for pz in (-5.0, -1.5, 2.0, 5.5):
            add((rx, 1.1, pz, 0.12, 2.2, 0.12), "timber")

        add((rx, 2.0, 0.25, 0.08, 0.08, 10.6), "timber")
        add((rx, 1.3, 0.25, 0.06, 0.06, 10.6), "timber")

        for i in range(9):
            z = -4.6 + i * 1.2
            shapes.append(ks.card(rx + (0.05 if i % 2 else -0.05), 1.45, z, 1.0, 1.1, "leather", 90.0))

    # (The lean-to: posts along its front, its roof falling from the wall.)
    lean = (-7.0, 0.0, -8.2, -5.4)
    x0, x1, zb, zf = lean
    for px in (x0 + 0.3, (x0 + x1) / 2.0, x1 - 0.3):
        add((px, 1.1, zf + 0.1, 0.15, 2.2, 0.15), "timber")

    pitch = math.degrees(math.atan2(0.6, zf - zb))
    roof = ((x0 + x1) / 2.0, 2.5, (zb + zf) / 2.0, x1 - x0, 0.12, math.hypot(zf - zb, 0.6))
    shapes.append(ks.box(*roof, "roof_clay", 0.0, pitch, 0.0))
    cols.append(town.col(*roof, "stone", 0.0, pitch, 0.0))
    for bx in (-6.0, -4.8, -3.6):
        shapes.append(ks.prism(bx, 0.45, -7.4, 0.26, 0.9, 10, "boards", rings=[[0.3, 0.3], [0.7, 0.3]]))
        cols.append(town.col(bx, 0.45, -7.4, 0.6, 0.9, 0.6, "wood"))

    return _register(name, "street", "mud", shapes, cols, [14.0, 3.0, 16.6], vats=vats, work=[-2.0, 0.0, -1.6], budget=1600)


def bricked(width, height):
    """An alley's mouth `width` across walled up in brick `height` high
    (its face at z 0, 0.4 thick behind it), a granite coping, the brick
    patched with older stones."""
    name = "bricked_%d_%d" % (_cm(width), _cm(height))

    if name in k.PIECES:
        return name

    t = 0.4
    body = (0.0, (height - 0.1) / 2.0, -t / 2.0, width, height - 0.1, t)
    coping = (0.0, height - 0.05, -t / 2.0, width + 0.04, 0.1, t + 0.06)
    shapes = [ks.box(*body, "brick"), ks.box(*coping, "granite")]
    shapes += [ks.box(x, y, 0.01, 0.5, 0.3, 0.04, "granite_rough") for x, y in ((-0.6, 0.4), (0.5, 1.3), (-0.2, 2.2))]
    return _register(name, "wall", "brick", shapes, [town.col(*body), town.col(*coping)], [width + 0.04, height, t + 0.06])


def fill(width, depth, height):
    """Solid ground `width` along x by `depth` along z about the origin,
    `height` up from 0 (a terrace carried forward between its retaining
    walls), paved at its top in calcada."""
    name = "fill_%d_%d_%d" % (_cm(width), _cm(depth), _cm(height))

    if name in k.PIECES:
        return name

    body = (0.0, (height - 0.1) / 2.0, 0.0, width, height - 0.1, depth)
    top = (0.0, height - 0.05, 0.0, width, 0.1, depth)
    shapes = [ks.box(*body, "granite_rough"), ks.box(*top, "calcada")]
    return _register(name, "floor", "calcada", shapes, [town.col(*body), town.col(*top)], [width, height, depth])


# A bridge's room: its floor's beams and boards, its walls' height and
# thickness, how far it bears into each neighbour's party wall.
BRIDGE_FLOOR = (0.2, 0.25)
BRIDGE_ROOM = (2.4, 0.25)
BRIDGE_BEARING = 0.15


def bridge(span, depth):
    """A room over a lane `span` wide (the lane along z) between two
    houses, borne `BRIDGE_BEARING` into their party walls: beams across
    under its boards (their feet at 0), plastered walls to the lane each
    side with a shut or lit window, granite corbels under its ends, a tiled
    roof falling to the lane each way; its `top`."""
    name = "bridge_%d_%d" % (_cm(span), _cm(depth))

    if name in k.PIECES:
        return name

    beam, boards = BRIDGE_FLOOR
    room, t = BRIDGE_ROOM
    width = span + 2.0 * BRIDGE_BEARING
    floor = beam + boards
    shapes, cols = [], []

    def add(box, slot, solid=True):
        shapes.append(ks.box(*box, slot))

        if solid:
            cols.append(town.col(*box))

    for i in range(4):
        z = -depth / 2.0 + 0.3 + i * (depth - 0.6) / 3.0
        add((0.0, beam / 2.0, z, width, beam, 0.18), "timber")

    add((0.0, beam + boards / 2.0, 0.0, width, boards, depth), "boards")

    for sz, kind in ((1.0, "shut"), (-1.0, "lit")):
        s, c = town.wall(width, room, t, [town.Opening(0.0, 0.8, 0.9, 1.1, kind)], "plaster", (0.0, sz * (depth / 2.0 - t / 2.0), 0.0 if sz > 0 else 180.0),
                         frames=False)
        s, c = town.placed(s, c, y=floor)
        shapes, cols = shapes + s, cols + c

    for sx in (-1.0, 1.0):
        for sz in (-1.0, 1.0):
            shapes.append(ks.box(sx * (span / 2.0 - 0.1), -0.25, sz * (depth / 2.0 - 0.3), 0.2, 0.5, 0.3, "granite"))

    # (Its ridge across the lane, its gables in its neighbours' walls.)
    rs, rc = town.roof("gable", width, depth, floor + room, 27.0, "plaster")
    shapes, cols = shapes + rs, cols + rc
    top = floor + room + (depth / 2.0) * math.tan(math.radians(27.0)) + 0.3
    return _register(name, "town", "plaster", shapes, cols, [width, top, depth], top=top, budget=900)


GATE_ARCH = 0.6
GATE_WALL = 0.5


def gateway(width, height, opening, opening_h, live=True, slot="whitewash"):
    """A wall `width` along x, `height` high, GATE_WALL thick about z 0 (its
    faces to either side), an opening `opening` wide `opening_h` high at its
    crown under a segmental arch GATE_ARCH high, an iron fanlight filling
    the arch over the gate; `live`, the gate (hung by the layout: its
    `doors`) under the springing; else barred shut, solid; a granite
    coping."""
    name = "gateway_%d_%d_%d_%d%s%s" % (_cm(width), _cm(height), _cm(opening), _cm(opening_h), "" if live else "_barred",
                                      "" if slot == "whitewash" else "_" + slot)

    if name in k.PIECES:
        return name

    t = GATE_WALL
    spring = opening_h - GATE_ARCH
    shapes = ks.arched_wall(width, height, t, opening, spring, GATE_ARCH, 0.0, slot)
    side = (width - opening) / 2.0
    cols = [town.col(s * (opening + side) / 2.0, height / 2.0, 0.0, side, height, t) for s in (-1.0, 1.0)]
    cols.append(town.col(0.0, (spring + height) / 2.0, 0.0, opening, height - spring, t))

    for s in (-1.0, 1.0):
        shapes.append(ks.card(0.0, spring + GATE_ARCH / 2.0, s * 0.03, opening, GATE_ARCH, "window_grille", 0.0 if s > 0 else 180.0))

    shapes.append(ks.box(0.0, height + 0.06, 0.0, width + 0.06, 0.12, t + 0.1, "granite"))
    cols.append(town.col(0.0, height + 0.06, 0.0, width + 0.06, 0.12, t + 0.1))
    keys = {}

    if live:
        keys["doors"] = [[0.0, 0.0, 0.0, 0.0, opening, spring]]
    else:
        for s in (-1.0, 1.0):
            shapes.append(ks.card(0.0, spring / 2.0, s * 0.05, opening, spring, "window_grille", 0.0 if s > 0 else 180.0))

        cols.append(town.col(0.0, spring / 2.0, 0.0, opening, spring, 0.1))

    return _register(name, "wall", slot, shapes, cols, [width + 0.06, height + 0.12, t + 0.1], **keys)
