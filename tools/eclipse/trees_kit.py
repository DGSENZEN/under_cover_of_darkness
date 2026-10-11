"""The trees kit (docs/superpowers/specs/2026-10-10-zocalo-scenes-design.md):
the Zócalo's garden as it stood from the 1860s to 1958, and the street's
trees. Ash for the garden and a few side streets, Canary palms along its
paths (a Porfirian taste), a laurel de la India shading the market hall's
doors, weeping willows on the canal, and one ancient ahuehuete by the dig,
split to its fork and half dead where the ground sank under the surfacing
idol, hung with the devoted's ex-votos (blank: the user's to paint). The
garden's iron: tree guards, benches, hooped edging.

Trunks and limbs are closed solids in the atlas; crowns are leaf cards (the
plan's Ruling 1: our own paintings, textures/painted/<slot>.png, cut out
and stirred by the wind in Godot), their normals rounded from the crown's
middle.

    Blender -b --factory-startup --python tools/eclipse/trees_kit.py

Blender axes: a trunk's foot at the origin, Z up.
"""

import math
import os
import random
import sys

from mathutils import Matrix, Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import common  # noqa: E402
import shapes  # noqa: E402

NAME = "trees_kit"
ATLAS = 1536
CARDS = ("leaf_crown", "palm_frond", "willow", "laurel", "twigs", "leaf_shrub", "garden_flowers")
SLOTS = ["bark", "iron", "wood", "sign"] + list(CARDS)

UP = Vector((0.0, 0.0, 1.0))


def _object(name, build):
    m = common.Mesh(name, outward=True)
    build(m)
    return m.make()


def _ring(centre, axis, radius, sides, twist=0.0):
    axis = Vector(axis).normalized()
    side = axis.orthogonal().normalized()
    other = axis.cross(side)
    return [tuple(Vector(centre) + (side * math.cos(twist + 2 * math.pi * k / sides)
                                    + other * math.sin(twist + 2 * math.pi * k / sides)) * radius)
            for k in range(sides)]


def _rings(centres, axes, radii, sides, twist=0.0):
    """Rings round a bent line, each turned on from the one before (its
    `side` carried along, never picked afresh), so the faces between them
    never twist into slivers."""
    out = []
    side = None

    for c, axis, r in zip(centres, axes, radii):
        axis = Vector(axis).normalized()
        side = (Matrix.Rotation(twist, 3, axis) @ axis.orthogonal()) if side is None else side - axis * side.dot(axis)
        side.normalize()
        other = axis.cross(side)
        out.append([tuple(Vector(c) + (side * math.cos(2 * math.pi * k / sides) + other * math.sin(2 * math.pi * k / sides))
                          * r) for k in range(sides)])

    return out


def limb(m, a, b, r0, r1, sides=6, bend=None, slot="bark", twist=None):
    """A tapering limb from a to b (bowed toward `bend` at its middle), r0 at
    its foot to r1 at its tip, a closed solid."""
    a, b = Vector(a), Vector(b)
    mid = (a + b) / 2 + (Vector(bend) if bend is not None else Vector())
    m.shell()
    # Each limb turned its own way about its axis (from where it starts), so
    # two limbs leaving one place together never lay a face along each other.
    twist = (a.x * 7.31 + a.y * 3.17 + b.x * 5.13 + b.y * 2.71) % (2 * math.pi) if twist is None else twist
    shapes.loft(m, _rings([a, mid, b], [mid - a, b - a, b - mid], [r0, (r0 + r1) * 0.55, r1], sides, twist), slot,
                caps=True, fan=True)


def trunk(m, profile, sides=8, slot="bark", at=(0.0, 0.0, 0.0)):
    m.shell()
    shapes.lathe(m, profile, sides, slot, at=at)


def card_at(m, centre, normal, width, height, slot, round=None, roll=0.0):
    """A card about `centre` facing `normal`, its painting's up toward the
    world's up (turned `roll` degrees)."""
    n = Vector(normal).normalized()
    side = UP.cross(n)

    if side.length < 1e-4:
        side = Vector((1.0, 0.0, 0.0))

    side.normalize()
    up = n.cross(side).normalized()
    turn = Matrix.Rotation(math.radians(roll), 3, n)
    side, up = turn @ side, turn @ up
    c = Vector(centre)
    w, h = side * (width / 2), up * (height / 2)
    m.card([tuple(c - w - h), tuple(c + w - h), tuple(c + w + h), tuple(c - w + h)], slot, round=round)


def crown(m, seed, centre, radii, count, slot, sizes, shell=(0.5, 1.0), floor=None):
    """`count` cards over an ellipsoid round `centre`, each facing out from
    the middle, tipped a little; none lower than `floor`."""
    rng = random.Random(seed)
    c = Vector(centre)

    for i in range(count):
        up = 1.0 - 2.0 * (i + 0.5) / count
        around = i * 2.399963 + rng.uniform(-0.4, 0.4)
        flat = math.sqrt(max(1.0 - up * up, 0.0))
        out = rng.uniform(*shell)
        at = c + Vector((math.cos(around) * flat * radii[0], math.sin(around) * flat * radii[1], up * radii[2])) * out
        size = rng.uniform(*sizes)

        if floor is not None:
            at.z = max(at.z, floor + size * 0.6)

        facing = (at - c).normalized() + Vector((rng.uniform(-0.3, 0.3), rng.uniform(-0.3, 0.3), rng.uniform(-0.2, 0.2)))
        card_at(m, at, facing, size, size * rng.uniform(0.88, 1.04), slot, round=tuple(c), roll=rng.uniform(-25, 25))


def _trunk(m, base_r, fork, lean, sides=8):
    """A trunk from its flared roots to its fork at `fork` m, leaning `lean`
    (x, y) there (bent, more toward the top); returns the fork's middle."""
    at = lambda z: Vector((lean[0] * (z / fork) ** 2, lean[1] * (z / fork) ** 2, z))
    heights = (0.0, 0.3, fork * 0.45, fork)
    radii = (base_r * 1.5, base_r * 1.12, base_r, base_r * 0.82)
    # (The roots' ring lies flat on the ground; the rest follow the lean.)
    axes = [UP] + [(at(min(z + 0.1, fork)) - at(z)) if z < fork else (at(fork) - at(fork - 0.1)) for z in heights[1:]]
    m.shell()
    shapes.loft(m, _rings([at(z) for z in heights], axes, radii, sides), "bark", caps=True, fan=True)
    return at(fork)


def _spots(rng, centre, radii, count, up=(-0.35, 1.0), shell=(0.55, 0.85)):
    """`count` points over an ellipsoid round `centre`, evenly round it (a
    golden-angle spiral), its lower part left out (`up`: the band of heights)."""
    c = Vector(centre)
    out = []

    for i in range(count):
        h = up[1] - (up[1] - up[0]) * (i + 0.5) / count
        around = i * 2.399963 + rng.uniform(-0.35, 0.35)
        flat = math.sqrt(max(1.0 - h * h, 0.0))
        r = rng.uniform(*shell)
        out.append(c + Vector((math.cos(around) * flat * radii[0], math.sin(around) * flat * radii[1], h * radii[2])) * r)

    return out


def _clump(m, rng, centre, crown, radius, count, slot, sizes, floor=None):
    """A clump of leaf cards round `centre`, each facing out from it and
    from the crown's middle together; its normals rounded half from each,
    so a crown lights as lumps of one mass."""
    c, k = Vector(centre), Vector(crown)
    rounded = tuple(c * 0.5 + k * 0.5)

    for i in range(count):
        up = 1.0 - 2.0 * (i + 0.5) / count
        around = i * 2.399963 + rng.uniform(-0.5, 0.5)
        flat = math.sqrt(max(1.0 - up * up, 0.0))
        at = c + Vector((math.cos(around) * flat, math.sin(around) * flat, up * 0.8)) * radius * rng.uniform(0.35, 0.9)
        size = rng.uniform(*sizes)

        if floor is not None:
            at.z = max(at.z, floor + size * 0.6)

        facing = ((at - c).normalized() * 0.6 + (at - k).normalized() * 0.4
                  + Vector((rng.uniform(-0.25, 0.25), rng.uniform(-0.25, 0.25), rng.uniform(-0.15, 0.25))))
        card_at(m, at, facing, size, size * rng.uniform(0.85, 1.05), slot, round=rounded, roll=rng.uniform(-30, 30))


def _branches(m, rng, fork, tips, r0, r1, primaries=5):
    """Limbs from the fork to `primaries` tips spread as widely round it as
    they can be, and to each other tip from the middle of the limb it leaves
    at 30 degrees or more (two limbs along each other would lie in each
    other's faces)."""
    fork = Vector(fork)
    way = lambda t: (t - fork).normalized()
    firsts = [min(tips, key=lambda t: t.z)]

    while len(firsts) < min(primaries, len(tips)):
        rest = [t for t in tips if all(t is not f for f in firsts)]
        firsts.append(max(rest, key=lambda t: min(way(t).angle(way(f)) for f in firsts)))

    # Each limb's middle, and the ways of every limb leaving there (its own first).
    middles = []

    for tip in firsts:
        bow = Vector((0.0, 0.0, (tip - fork).length * 0.1))
        limb(m, fork, tip, r0, r1 * 1.4, sides=6, bend=bow)
        middles.append((fork + (tip - fork) * 0.55 + bow * 0.9, [way(tip)]))

    for tip in [t for t in tips if all(t is not f for f in firsts)]:
        clear = lambda mid, ways: all((tip - mid).normalized().angle(d) >= math.radians(30) for d in ways)
        apart = [(mid, ways) for mid, ways in middles if (tip - mid).length > 0.3 and clear(mid, ways)]
        foot, ways = min(apart or middles, key=lambda mw: (mw[0] - tip).length)

        if not apart:
            # (No limb it may leave: it leaves its nearest a third of the way further on.)
            foot = foot + ways[0] * 0.4

        ways.append((tip - foot).normalized())
        limb(m, foot, tip, r0 * 0.5, r1, sides=5, bend=(0.0, 0.0, (tip - foot).length * 0.08))


def broadleaf(m, seed, trunk_r, fork, lean, crown, radii, clumps, per_clump, clump_r, slot, sizes, floor=None,
              primaries=5):
    """A broadleaf tree: its trunk, a crown of `clumps` leaf clumps each at
    a limb's end, a few cards in its heart; returns the clumps' middles."""
    rng = random.Random(seed)
    top = _trunk(m, trunk_r, fork, lean)
    middles = _spots(rng, crown, radii, clumps)
    # Limbs stop inside their clumps, never through them.
    tips = [top + (c - top) * 0.88 for c in middles]
    _branches(m, rng, top, tips, trunk_r * 0.6, 0.045, primaries)

    for c in middles:
        _clump(m, rng, c, crown, clump_r, per_clump, slot, sizes, floor)

    _clump(m, rng, crown, crown, min(radii) * 0.45, 4, slot, sizes, floor)
    return middles


def tree_ash(m):
    """An ash (fresno), 10 m: a grey trunk leaning a little, forking at 3 m
    into limbs that each end in a clump of leaves, the crown open and lumpy,
    lifted clear of a man's head."""
    broadleaf(m, 11, 0.24, 3.2, (0.3, 0.1), (0.3, 0.1, 6.8), (3.3, 3.0, 2.9), 13, 8, 1.15, "leaf_crown",
              (1.3, 1.9), floor=2.5, primaries=4)


def tree_ash_young(m):
    broadleaf(m, 21, 0.13, 2.3, (0.1, -0.05), (0.1, 0.0, 4.3), (1.9, 1.8, 1.6), 7, 6, 0.8, "leaf_crown", (1.0, 1.4),
              floor=2.3, primaries=4)


def palm_canary(m):
    """A Canary palm, 8.5 m: a thick trunk ringed by old leaf scars, a
    pineapple-swollen crown, two tiers of fronds arching out and down, a
    skirt of dead ones hanging under them."""
    profile = [(0.5, 0.0), (0.44, 0.3)]

    for k in range(1, 12):
        z = 0.3 + 6.9 * k / 11
        profile.append((0.42 - 0.05 * k / 11 + (0.035 if k % 2 else 0.0), z))

    profile += [(0.55, 7.5), (0.5, 8.0), (0.22, 8.3)]
    trunk(m, profile, sides=9)
    rng = random.Random(31)
    top = Vector((0.0, 0.0, 8.0))

    def frond(a, droop, length, height, lift):
        out = Vector((math.cos(a), math.sin(a), 0.0))
        r = (out * math.cos(droop) - UP * math.sin(droop)).normalized()
        u = (UP * math.cos(droop) + out * math.sin(droop)).normalized()
        base = top + out * 0.3 + UP * lift - u * height * 0.2
        m.card([tuple(base), tuple(base + r * length), tuple(base + r * length + u * height), tuple(base + u * height)],
               "palm_frond", round=(0.0, 0.0, 6.8))

    for k in range(14):
        frond(math.radians(k * 360 / 14 + rng.uniform(-6, 6)), math.radians(rng.uniform(-30, -5)), 3.6, 1.8, 0.15)

    for k in range(12):
        frond(math.radians(k * 30 + 15 + rng.uniform(-6, 6)), math.radians(rng.uniform(10, 38)), 3.8, 1.8, -0.1)

    for k in range(7):
        frond(math.radians(k * 51 + rng.uniform(-8, 8)), math.radians(rng.uniform(68, 80)), 2.6, 1.3, -0.35)


def tree_laurel(m):
    """A laurel de la India, 8 m: a thick buttressed trunk, heavy limbs, a
    wide low dark crown that shades a whole doorway, aerial roots hanging
    from its limbs."""
    middles = broadleaf(m, 41, 0.42, 2.2, (0.0, 0.1), (0.0, 0.1, 5.5), (4.6, 4.4, 2.3), 16, 8, 1.3, "laurel",
                        (1.4, 2.0), floor=2.7, primaries=6)
    rng = random.Random(43)

    # From the low clumps, where their limbs end, roots hanging to a man's
    # shoulder.
    for c in sorted(middles, key=lambda c: c.z)[:6]:
        top = c - Vector((0.0, 0.0, 0.3))
        root = Vector((top.x + rng.uniform(-0.15, 0.15), top.y + rng.uniform(-0.15, 0.15), rng.uniform(1.4, 1.9)))
        limb(m, top, root, 0.05, 0.04, sides=5)


def tree_willow(m):
    """A weeping willow, 7 m, leaning out over the water: limbs arching up
    and over, and from every clump its strands hanging nearly to the ground."""
    rng = random.Random(51)
    crown = Vector((1.1, 0.0, 5.3))
    middles = broadleaf(m, 51, 0.27, 2.6, (0.9, 0.0), tuple(crown), (2.9, 2.7, 1.5), 9, 5, 0.9, "leaf_crown",
                        (1.0, 1.4), primaries=4)

    for c in middles:
        for k in range(3):
            a = rng.uniform(0, 2 * math.pi)
            top = c + Vector((math.cos(a) * 0.5, math.sin(a) * 0.5, -0.2))
            width, height = rng.uniform(1.0, 1.4), rng.uniform(2.3, 3.4)
            out = Vector((top.x - crown.x, top.y - crown.y, 0.0))
            out = out.normalized() if out.length > 1e-3 else Vector((1.0, 0.0, 0.0))
            facing = math.atan2(out.y, out.x) + rng.uniform(-0.6, 0.6)
            side = Vector((-math.sin(facing), math.cos(facing), 0.0)) * width / 2
            foot = top - UP * height + out * 0.3
            m.card([tuple(foot - side), tuple(foot + side), tuple(top + side), tuple(top - side)], "willow",
                   round=tuple(crown))


def ahuehuete_split(m):
    """The ancient ahuehuete by the dig, 12 m: a vast flared trunk split
    from its fork where the ground sank under the surfacing idol, one half
    green and living, the other dead, grey and bare; the devoted's ex-votos
    nailed round it at a hand's reach (their pictures the user's to paint)."""
    rng = random.Random(61)
    _trunk(m, 0.95, 2.3, (0.0, 0.0), sides=10)

    for side in (-1, 1):
        foot = Vector((side * 0.35, 0.0, 2.1))
        top = Vector((side * 1.7, 0.25 * side, 6.6))
        limb(m, foot, top, 0.55, 0.28, sides=8, bend=(side * 0.35, 0.0, 0.0))
        crown = Vector((side * 2.4, 0.25 * side, 8.6))

        if side < 0:
            middles = _spots(rng, crown, (3.3, 3.1, 2.3), 10)
            _branches(m, rng, top, [top + (c - top) * 0.88 for c in middles], 0.3, 0.05, 4)

            for c in middles:
                _clump(m, rng, c, crown, 1.15, 8, "leaf_crown", (1.4, 2.0), floor=5.0)
        else:
            tips = _spots(rng, crown, (3.0, 2.8, 2.2), 8, shell=(0.75, 1.0))
            _branches(m, rng, top, tips, 0.28, 0.04, 4)

            for k, tip in enumerate(tips):
                for turn in (0.0, 90.0):
                    a = math.radians(turn + 37 * k)
                    card_at(m, tip + Vector((0.0, 0.0, 0.9)), (math.cos(a), math.sin(a), 0.0), 2.2, 2.2, "twigs",
                            round=tuple(top))

    # The ex-votos, each standing 4 cm proud of the bark.
    radius = lambda z: 0.95 - 0.17 * (z - 1.035) / 1.265

    for k in range(8):
        a = math.radians(k * 45 + 12)
        z = 1.4 + 0.8 * ((k * 3) % 8) / 7
        out = Vector((math.cos(a), math.sin(a), 0.0))
        centre = out * (radius(z) + 0.01)
        m.shell()
        shapes.obox(m, tuple(centre + Vector((0.0, 0.0, z))), (0.24, 0.06, 0.3), (0.0, 0.0, a + math.pi / 2), "sign")


def tree_guard(m):
    """The iron cage round a young tree, 1.2 m: two rings of eight bars and
    eight uprights between their corners."""
    sides = 8
    corner = lambda k, z: (0.47 * math.cos(2 * math.pi * k / sides), 0.47 * math.sin(2 * math.pi * k / sides), z)

    for z in (0.1, 1.1):
        for k in range(sides):
            m.shell()
            m.bar(corner(k, z), corner(k + 1, z), 0.04, 0.05, "iron", caps=(True, True))

    for k in range(sides):
        a = 2 * math.pi * (k + 0.5) / sides
        m.shell()
        m.box((0.47 * math.cos(a) - 0.02, 0.47 * math.sin(a) - 0.02, 0.0),
              (0.47 * math.cos(a) + 0.02, 0.47 * math.sin(a) + 0.02, 1.2), "iron")


def garden_bench(m):
    """A garden bench, 1.8 m: two cast-iron ends (one piece each: legs, seat
    bearer and raked back), wooden slats to sit and lean on."""
    end = [(-0.27, 0.0), (-0.21, 0.0), (-0.19, 0.38), (0.15, 0.38), (0.17, 0.0), (0.23, 0.0), (0.3, 0.9),
           (0.24, 0.9), (0.18, 0.45), (-0.27, 0.45)]

    for x in (-0.82, 0.82):
        m.shell()
        shapes.loft_x(m, [(x - 0.03, end), (x + 0.03, end)], "iron")

    for y in (-0.24, -0.1, 0.04):
        m.shell()
        m.box((-0.9, y, 0.45), (0.9, y + 0.1, 0.49), "wood")

    for z in (0.6, 0.76):
        m.shell()
        m.box((-0.9, 0.28, z), (0.9, 0.32, z + 0.1), "wood")


def garden_shrub(m):
    """A clipped garden shrub, 1 m: a short woody stem, a dome of leaf
    cards (our leaf_shrub painting)."""
    trunk(m, [(0.06, 0.0), (0.05, 0.3), (0.0, 0.42)], sides=5)
    rng = random.Random(71)
    centre = Vector((0.0, 0.0, 0.6))

    for k in range(7):
        up = 1.0 - 2.0 * (k + 0.5) / 7
        a = k * 2.399963
        flat = math.sqrt(max(1.0 - up * up, 0.0))
        at = centre + Vector((math.cos(a) * flat * 0.32, math.sin(a) * flat * 0.32, max(up, -0.2) * 0.22))
        card_at(m, at, (at - centre).normalized() + Vector((0.0, 0.0, 0.3)), 0.75, 0.7, "leaf_shrub",
                round=tuple(centre - Vector((0.0, 0.0, 0.4))), roll=rng.uniform(-30, 30))


def flower_clump(m):
    """A clump of the garden's flowers, 0.6 m: three cards crossed round a
    stub of a stem."""
    trunk(m, [(0.04, 0.0), (0.0, 0.12)], sides=4)

    for k in range(3):
        a = math.radians(k * 60.0)
        card_at(m, (0.0, 0.0, 0.31), (math.cos(a), math.sin(a), 0.0), 0.62, 0.62, "garden_flowers", round=(0.0, 0.0, -1.0))


def garden_edging(m):
    """Low iron hoops edging a bed, 2 m from its origin along +X (stretched
    to fit), each hoop 0.5 m wide and 0.25 high."""
    for k in range(4):
        x0 = 0.5 * k + 0.02
        x1 = x0 + 0.46
        m.shell()
        m.box((x0, -0.015, 0.0), (x0 + 0.03, 0.015, 0.25), "iron")
        m.shell()
        m.box((x1 - 0.03, -0.015, 0.0), (x1, 0.015, 0.25), "iron")
        m.shell()
        m.box((x0 + 0.03, -0.015, 0.22), (x1 - 0.03, 0.015, 0.25), "iron")


PIECES = [tree_ash, tree_ash_young, palm_canary, tree_laurel, tree_willow, ahuehuete_split, tree_guard, garden_bench,
          garden_edging, garden_shrub, flower_clump]

FLAGS = (0.62, 0.6, 0.56)
JOINTS = {
    "11_garden": {"eye": (8.0, -14.0, 3.0), "target": (0.0, 0.0, 3.0),
                  "show": [("tree_ash", (0, 0, 0), 0), ("tree_guard", (0, 0, 0), 0), ("garden_bench", (3, -2, 0), 0),
                           ("palm_canary", (-6, 2, 0), 0)],
                  "planes": [(-30, -30, 30, 30, -0.002, FLAGS)]},
}

WEATHER = {"coarse": {f.__name__: 3.0 for f in PIECES}, "blendable": ["bark", "iron"], "foot": ["bark", "iron"]}


def build():
    common.reset()

    for f in PIECES:
        _object(f.__name__, f)


def main():
    build()
    common.export_piece(NAME, ATLAS, SLOTS, weather=WEATHER, out=common.ROOT / "assets" / "eclipse" / "kit",
                        sets_each=True, cards=CARDS)


if __name__ == "__main__":
    main()
