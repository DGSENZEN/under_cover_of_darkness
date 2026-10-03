"""The coast (kit v1), after docs/superpowers/refs/coast_life.md: granite
shaped by its joints, not by noise (blocks along two joint sets with rounded
tops and cracks between them: tors, ledges stepping along the sheet joints,
boulder fields half buried at the cliffs' feet, a block undercut at the
waterline); the plants of an Atlantic shore (gorse pruned into cushions by
the wind at the cliff's edge and grown into bushes behind it, sea fennel in
the cracks over the black band, stone pines in the shelter and maritime
pines leaning from the sea, a fig out of a wall); and what lives on it (gulls
on the ridges and the boats, nets drying on poles, washing between windows,
a tavern's bush over its door). The rock's bands by height (wet under high
water, black lichen over it) are its slot's (Materials' shore rock). Pure
data, as kit_recipes (which imports this at its end).
"""

import math
import random

import geo
import kit_shapes as ks
from kit_nature import _crossed, _crown, _limb, _plant
from kit_recipes import PIECES, model, piece

ROCK = "rock_shore"


def col(cx, cy, cz, sx, sy, sz, yaw=0.0, pitch=0.0, roll=0.0, surface="stone"):
    return [cx, cy, cz, sx, sy, sz, surface, yaw, pitch, roll]


def block(foot, size, rounding, slot=ROCK, yaw=0.0, tilt=(0.0, 0.0), steps=2):
    """A block of granite standing on `foot` (x, y, z), `size` (x, y, z) m:
    its upright edges chamfered and its top rounded by `rounding` in `steps`
    (weathered along its joints), turned `yaw` and tipped `tilt` (pitch,
    roll) degrees. Its faces wound outward, and its collider."""
    sx, sy, sz = size
    hx, hz = sx / 2.0, sz / 2.0
    r = min(rounding, hx * 0.7, hz * 0.7, sy * 0.6)
    c = min(r * 0.8 + 0.04, hx * 0.4, hz * 0.4)

    def ring(inset, y):
        ax, az = hx - inset, hz - inset
        cc = max(0.02, min(c - inset * 0.4, ax * 0.45, az * 0.45))
        return [[ax, y, -az + cc], [ax, y, az - cc], [ax - cc, y, az], [-ax + cc, y, az], [-ax, y, az - cc], [-ax, y, -az + cc],
                [-ax + cc, y, -az], [ax - cc, y, -az]]

    rings = [ring(0.0, 0.0), ring(0.0, sy - r)]
    rings += [ring(r * 0.45, sy - r * 0.3)] if steps > 1 else []
    rings.append(ring(r, sy))
    turn = geo.rotation(yaw, tilt[0], tilt[1])
    placed = [[geo.add(foot, geo.apply(turn, p)) for p in points] for points in rings]
    centre = geo.add(foot, geo.apply(turn, [0.0, sy / 2.0, 0.0]))
    faces = [placed[-1], placed[0]]

    for a, b in zip(placed, placed[1:]):
        for i in range(8):
            j = (i + 1) % 8
            faces.append([a[i], a[j], b[j], b[i]])

    out = []

    for face in faces:
        middle = [sum(p[k] for p in face) / len(face) for k in range(3)]

        if geo.dot(ks._normal(face), geo.sub(middle, centre)) < 0.0:
            face = face[::-1]

        out.append(ks.polygon(face, slot))

    return out, col(centre[0], centre[1], centre[2], sx, sy, sz, yaw, tilt[0], tilt[1])


def _blocks(specs):
    shapes, cols = [], []

    for spec in specs:
        more, c = block(**spec)
        shapes += more
        cols.append(c)

    return shapes, cols


def _row(rng, x0, width, y, depth, height, count, yaw, z=0.0, rounding=0.3, crack=(0.06, 0.16), lean=6.0):
    """A row of `count` blocks along the joint set's x from x0, `width` in
    all with cracks between, `depth` through, about `height` tall, on y."""
    shares = [rng.uniform(0.7, 1.3) for _ in range(count)]
    gaps = [rng.uniform(*crack) for _ in range(count - 1)]
    room = width - sum(gaps)
    x = x0
    turn = geo.rotation(yaw)
    out = []

    for i, share in enumerate(shares):
        w = room * share / sum(shares)
        local = [x + w / 2.0, y, z + rng.uniform(-0.15, 0.15)]
        foot = geo.apply(turn, local)
        out.append(dict(foot=foot, size=(w, height * rng.uniform(0.85, 1.15), depth * rng.uniform(0.85, 1.0)), rounding=rounding * rng.uniform(0.8, 1.3),
                        yaw=yaw + rng.uniform(-4.0, 4.0), tilt=(rng.uniform(-lean, lean), rng.uniform(-lean, lean))))
        x += w + (gaps[i] if i < len(gaps) else 0.0)

    return out


def _tor(seed, layers, sunk=0.4):
    """A tor: rows of blocks stacked from the ground up, each row
    narrower and set on the one below; `layers` [(width, depth, height,
    count, rounding), ...]. Sunk `sunk` into the ground."""
    rng = random.Random(seed)
    yaw = rng.uniform(0.0, 90.0)
    y = -sunk
    specs = []

    for width, depth, height, count, rounding in layers:
        x0 = -width / 2.0 + rng.uniform(-0.3, 0.3)
        row = _row(rng, x0, width, y, depth, height, count, yaw, z=rng.uniform(-0.3, 0.3), rounding=rounding)
        specs += row
        y += min(s["size"][1] for s in row) - 0.05

    return _blocks(specs)


def _boulders(seed, count, area, sizes, sunk=0.35):
    """A field of boulders over `area` (x, z) m: rounded by the sea, half
    buried, none in another."""
    rng = random.Random(seed)
    placed, specs = [], []

    while len(specs) < count:
        s = rng.uniform(*sizes)
        x, z = rng.uniform(-area[0] / 2.0 + s / 2.0, area[0] / 2.0 - s / 2.0), rng.uniform(-area[1] / 2.0 + s / 2.0, area[1] / 2.0 - s / 2.0)

        if any(math.hypot(x - px, z - pz) < (s + ps) * 0.55 for px, pz, ps in placed):
            continue

        placed.append((x, z, s))
        h = s * rng.uniform(0.55, 0.8)
        specs.append(dict(foot=[x, -h * sunk, z], size=(s * rng.uniform(0.9, 1.2), h, s * rng.uniform(0.75, 1.0)), rounding=h * 0.45,
                          yaw=rng.uniform(0.0, 180.0), tilt=(rng.uniform(-10.0, 10.0), rng.uniform(-10.0, 10.0)), steps=1 if s < 0.9 else 2))

    return _blocks(specs)


def _rock(name, shapes, cols, budget):
    xs = [p[0] for s in shapes for p in s["points"]]
    ys = [p[1] for s in shapes for p in s["points"]]
    zs = [p[2] for s in shapes for p in s["points"]]
    size = [2.0 * max(abs(min(xs)), abs(max(xs))), max(ys), 2.0 * max(abs(min(zs)), abs(max(zs)))]
    piece(name, "coast", ROCK, "stone", [], cols=cols, size=size)
    model(name, shapes)
    PIECES[name]["budget"] = budget


# The tors: a big one with a capstone, a low ridge, a tall stack.
_rock("tor_a", *_tor(301, [(5.2, 3.2, 1.6, 3, 0.5), (3.6, 2.6, 1.3, 2, 0.55), (1.9, 1.9, 1.1, 1, 0.7)]), 500)
_rock("tor_b", *_tor(302, [(6.4, 2.6, 1.6, 4, 0.5), (3.8, 2.0, 1.2, 2, 0.6)]), 500)
_rock("tor_c", *_tor(303, [(3.4, 2.8, 2.0, 2, 0.5), (2.8, 2.4, 1.7, 2, 0.55), (1.6, 1.8, 1.2, 1, 0.65)]), 400)
# Ledges along the sheet joints: wide thin slabs stepping back and up.
_rock("ledge_a", *_tor(311, [(7.6, 5.0, 0.6, 3, 0.15), (6.4, 3.6, 0.5, 2, 0.15), (4.2, 2.2, 0.45, 2, 0.18)], sunk=0.2), 500)
_rock("ledge_b", *_tor(312, [(8.4, 4.2, 0.8, 4, 0.2), (5.6, 2.6, 0.6, 3, 0.2)], sunk=0.3), 500)
# Boulder fields at the cliffs' feet and the shore.
_rock("boulders_a", *_boulders(321, 9, (7.0, 6.0), (0.5, 1.6)), 600)
_rock("boulders_b", *_boulders(322, 6, (5.0, 4.0), (0.8, 2.0)), 500)
_rock("boulders_c", *_boulders(323, 12, (9.0, 5.0), (0.35, 1.1)), 650)
_rock("boulder_big", *_blocks([dict(foot=[0.0, -0.5, 0.0], size=(3.2, 2.4, 2.6), rounding=1.0, yaw=17.0, tilt=(4.0, -3.0))]), 120)
# A block undercut at the waterline: the notch under its overhang.
_rock("notch_rock", *_blocks([dict(foot=[0.0, -1.0, -0.8], size=(5.2, 2.4, 2.2), rounding=0.25, yaw=0.0, tilt=(0.0, 0.0)),
                              dict(foot=[0.2, 1.4, 0.0], size=(5.8, 2.2, 4.0), rounding=0.45, yaw=3.0, tilt=(-3.0, 2.0))]), 200)


# ---------------------------------------------------------------------------
# Plants
# ---------------------------------------------------------------------------

# Gorse: a cushion at the cliff's edge (the wind's), a bush behind it.
_plant("gorse_cushion", "gorse", "grass", [1.4, 0.6, 1.4],
       _crossed(1.3, 0.6, "gorse", cards=3, below=1.5) + [ks.card(0.0, 0.5, 0.0, 1.1, 1.1, "gorse", 0.0, -90.0, round=[0.0, -1.5, 0.0])],
       budget=60)
_plant("gorse_bush", "gorse", "grass", [2.4, 1.5, 2.4],
       _crossed(2.2, 1.5, "gorse", cards=4, below=2.0) + _crown(331, [0.0, 0.9, 0.0], [0.9, 0.5, 0.9], 6, "gorse", (1.0, 1.3)),
       budget=100)
_plant("fennel_clump", "fennel", "grass", [0.8, 0.7, 0.8], _crossed(0.75, 0.65, "fennel", cards=3, below=1.5), budget=40)


def _stone_pine():
    """A stone pine: a trunk leaning a little, forking into limbs that
    spread up and out to its umbrella, a flat crown of needle tufts."""
    trunk = [ks.lathe(0.0, 0.0, 0.0, [[0.45, 0.0], [0.34, 0.5], [0.3, 3.0], [0.26, 6.0], [0.2, 7.2]], 8, "bark", 20.0, 6.0)]
    top = [math.sin(math.radians(6.0)) * 7.2 * math.sin(math.radians(20.0)), 7.2, math.sin(math.radians(6.0)) * 7.2 * math.cos(math.radians(20.0))]
    limbs = [_limb(top[0], top[1] - 0.4, top[2], 3.6, 0.18, 0.07, yaw, 50.0) for yaw in (10.0, 130.0, 250.0)]
    crown = _crown(341, [top[0], 9.6, top[2]], [4.6, 0.9, 4.6], 26, "pine", (2.6, 3.4), shell=(0.25, 1.0))
    crown += [ks.card(top[0] + math.sin(math.radians(a)) * 2.2, 9.3, top[2] + math.cos(math.radians(a)) * 2.2, 3.4, 3.4, "pine", a, -82.0,
                      round=[top[0], 7.0, top[2]]) for a in range(0, 360, 60)]
    return trunk + limbs + crown


def _maritime_pine():
    """A maritime pine leaning from the sea: a tall bare trunk, a few short
    limbs at its head, a small flattened crown."""
    trunk = [ks.lathe(0.0, 0.0, 0.0, [[0.36, 0.0], [0.28, 0.6], [0.24, 5.0], [0.18, 10.0], [0.12, 12.0]], 8, "bark", 0.0, 12.0)]
    lean = math.sin(math.radians(12.0))
    top = [0.0, 12.0 * math.cos(math.radians(12.0)), 12.0 * lean]
    limbs = [_limb(top[0], top[1] - 1.5, top[2], 2.2, 0.12, 0.05, yaw, 60.0) for yaw in (40.0, 160.0, 280.0)]
    crown = _crown(351, [top[0], top[1] + 0.4, top[2] + 0.4], [2.8, 1.1, 2.6], 16, "pine", (2.0, 2.6), shell=(0.3, 1.0))
    return trunk + limbs + crown


def _fig():
    """A fig out of a wall's joint at its foot: a low gnarled trunk leaning
    out of the wall (+z) and forking, a broad crown of big leaves."""
    trunk = [ks.lathe(0.0, 0.0, 0.2, [[0.3, 0.0], [0.24, 0.6], [0.22, 1.6], [0.16, 2.2]], 7, "bark", 0.0, 28.0)]
    limbs = [_limb(0.0, 1.8, 1.2, 2.4, 0.13, 0.05, yaw, pitch) for yaw, pitch in ((-40.0, 45.0), (35.0, 50.0), (0.0, 25.0))]
    crown = _crown(361, [0.0, 3.2, 2.0], [2.6, 1.5, 2.2], 20, "leaf_crown", (1.3, 1.8), shell=(0.35, 1.0), droop=12.0)
    return trunk + limbs + crown


_plant("pine_stone", "pine", "wood", [10.6, 11.8, 10.6], _stone_pine(), cols=[[0.0, 3.5, 0.0, 0.7, 7.0, 0.7, "wood", 0, 0, 0]], budget=350)
_plant("pine_maritime", "pine", "wood", [6.6, 14.2, 9.8], _maritime_pine(), cols=[[0.0, 5.5, 1.2, 0.5, 11.0, 0.5, "wood", 0, 12.0, 0]], budget=250)
_plant("fig_wall", "leaf_crown", "wood", [4.8, 5.2, 9.0], _fig(), budget=300)


# ---------------------------------------------------------------------------
# Life
# ---------------------------------------------------------------------------

def _gull(sitting=False):
    """A gull at rest, facing +z: its body, head and beak, its wings folded
    dark over its back, its tail; low on its feet when `sitting`."""
    y = 0.08 if sitting else 0.14
    out = [ks.prism(0.0, y, 0.0, 0.085, 0.36, 6, "feather", 0.0, 90.0, 0.0, top=0.06),
           ks.prism(0.0, y + 0.1, 0.17, 0.05, 0.12, 6, "feather"),
           ks.box(0.0, y + 0.12, 0.25, 0.025, 0.025, 0.07, "beak"),
           ks.box(0.0, y + 0.05, -0.2, 0.08, 0.02, 0.12, "feather_dark", 0.0, 10.0),
           ks.box(-0.06, y + 0.04, -0.02, 0.03, 0.08, 0.34, "feather_dark", 0.0, 6.0),
           ks.box(0.06, y + 0.04, -0.02, 0.03, 0.08, 0.34, "feather_dark", 0.0, 6.0)]

    if not sitting:
        out += [ks.box(s * 0.035, 0.035, 0.0, 0.012, 0.07, 0.012, "beak") for s in (-1.0, 1.0)]

    return out


_plant("gull", "feather", "wood", [0.3, 0.4, 0.6], _gull(), budget=120)
_plant("gull_sitting", "feather", "wood", [0.3, 0.3, 0.6], _gull(True), budget=100)


def _net_poles():
    """Nets drying: two poles, the net hung sagging between them, cork
    floats along its head."""
    out = [ks.lathe(x, 0.0, 0.0, [[0.06, 0.0], [0.05, 2.3]], 6, "wood_old") for x in (-1.6, 1.6)]
    out += [ks.card(0.0, 1.35, 0.0, 3.2, 1.7, "net"), ks.card(0.0, 1.0, 0.12, 2.8, 1.2, "net", 0.0, 8.0)]
    out += [ks.box(-1.4 + i * 0.35, 2.12 - 0.08 * math.sin(math.pi * i / 8.0), 0.0, 0.08, 0.05, 0.05, "cork") for i in range(9)]
    return out


_plant("net_poles", "net", "wood", [3.6, 2.4, 0.4], _net_poles(), cols=[[x, 1.15, 0.0, 0.14, 2.3, 0.14, "wood", 0, 0, 0] for x in (-1.6, 1.6)],
       budget=200)


def _laundry():
    """Washing on a line from window to window across a front (+z out): its
    two iron brackets on the wall, the cord sagging, the washing on it
    (stirred by the wind)."""
    out = [ks.box(x, 0.0, 0.18, 0.04, 0.04, 0.36, "iron") for x in (-1.3, 1.3)]
    out.append(ks.card(0.0, -0.55, 0.34, 2.6, 1.3, "laundry"))
    return out


_plant("laundry_2", "laundry", "wood", [2.8, 1.4, 0.5], _laundry(), budget=40)


def _tavern_bush():
    """A tavern's sign: a bush of green boughs on an iron bracket out from
    the wall (+z), hung by a chain."""
    out = [ks.box(0.0, 0.0, 0.45, 0.05, 0.05, 0.9, "iron"), ks.box(0.0, -0.18, 0.08, 0.04, 0.4, 0.04, "iron", 0.0, 40.0),
           ks.box(0.0, -0.15, 0.8, 0.02, 0.3, 0.02, "iron")]
    out += _crown(371, [0.0, -0.6, 0.8], [0.32, 0.32, 0.32], 9, "leaf_shrub", (0.45, 0.6), shell=(0.2, 0.8))
    return out


_plant("tavern_bush", "leaf_shrub", "wood", [0.8, 1.2, 2.3], _tavern_bush(), budget=120)
