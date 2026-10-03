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
                grate lifted aside
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
SHAFT = 1.0


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


def grate_hatch(depth):
    """A way down from the street `depth` deep: a shaft SHAFT square, its
    ladder from its foot to over the street, the grate lifted aside."""
    name = "grate_hatch_%d" % _cm(depth)

    if name in k.PIECES:
        return name

    t = 0.2
    shapes, cols = [], []

    for x, z, w, d in ((0.0, SHAFT / 2.0 + t / 2.0, SHAFT + 2.0 * t, t), (0.0, -SHAFT / 2.0 - t / 2.0, SHAFT + 2.0 * t, t),
                       (SHAFT / 2.0 + t / 2.0, 0.0, t, SHAFT), (-SHAFT / 2.0 - t / 2.0, 0.0, t, SHAFT)):
        shapes.append(ks.box(x, -depth / 2.0, z, w, depth, d, "stone_moss"))
        cols.append(town.col(x, -depth / 2.0, z, w, depth, d))

    shapes += [ks.box(0.0, 0.02, 0.0, SHAFT + 0.5, 0.04, SHAFT + 0.5, "iron"),
               ks.card(SHAFT * 0.9, 0.4, 0.0, SHAFT, 0.8, "window_grille", 90.0, 60.0)]
    climbs = [[0.0, (-depth + 0.6) / 2.0, 0.0, 0.8, depth + 0.6, 0.8, 0.0]]
    return _register(name, "vault", "stone_moss", shapes, cols, [SHAFT + 0.4, depth, SHAFT + 0.4], climbs=climbs)
