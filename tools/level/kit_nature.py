"""Kit: the nature round the walls (the art pass's nature): trees with
trunks, limbs and crowns of leaf cards lit as one mass (rounded normals), a
churchyard yew, a dead tree against the moon, shrubs, tufts of grass, broad
weeds, reeds by the water, ivy up the stone. Their leaves are our own
paintings (tools/textures/paint.py) and sway in the wind (Materials'
foliage). Imported by kit_recipes at its end.
"""

import math
import random

import kit_shapes as ks
from kit_recipes import PIECES, box, model, piece


def _crown(seed, centre, radii, count, slot, sizes, shell=(0.5, 1.0), droop=0.0):
    """`count` cards of `slot` over an ellipsoid round `centre` (`radii`),
    between `shell` of the way out: each faces out from the middle, tipped a
    little, sized within `sizes`, its normals rounded from the middle; the
    lower ones lean out (`droop`), so the crown is leaves seen from beneath
    too."""
    rng = random.Random(seed)
    cards = []

    for i in range(count):
        # Even round the crown (a golden-angle spiral), each nudged.
        up = 1.0 - 2.0 * (i + 0.5) / count
        around = i * 2.399963 + rng.uniform(-0.4, 0.4)
        flat = math.sqrt(max(1.0 - up * up, 0.0))
        out = rng.uniform(*shell)
        at = [centre[0] + math.cos(around) * flat * radii[0] * out, centre[1] + up * radii[1] * out, centre[2] + math.sin(around) * flat * radii[2] * out]
        yaw = math.degrees(math.atan2(at[0] - centre[0], at[2] - centre[2])) + rng.uniform(-35.0, 35.0)
        pitch = rng.uniform(-30.0, 30.0) - up * 35.0 + (droop if up < -0.2 else 0.0)
        size = rng.uniform(*sizes)
        cards.append(ks.card(at[0], at[1], at[2], size, size * rng.uniform(0.85, 1.05), slot, yaw, pitch, round=centre))

    return cards


def _limb(x, y, z, length, base, tip, yaw, pitch, sides=6, slot="bark"):
    """A limb from (x, y, z) leaning `pitch` degrees off upright toward
    `yaw`, tapering from `base` to `tip` over `length`."""
    return ks.lathe(x, y, z, [[base, 0.0], [(base + tip) * 0.55, length * 0.55], [tip, length]], sides, slot, yaw, pitch)


def _crossed(width, height, slot, cards=3, y=None, below=4.0):
    """Cards crossed round the upright (a tuft, a clump), their normals
    rounded from well below, so they light as ground cover (from above)."""
    y = height / 2.0 if y is None else y
    return [ks.card(0.0, y, 0.0, width, height, slot, i * 180.0 / cards, 0.0, round=[0.0, -below, 0.0]) for i in range(cards)]


def _plant(name, slot, surface, size, shapes, cols=None, budget=None):
    piece(name, "dressing", slot, surface, [box(0.0, size[1] / 2.0, 0.0, size[0], size[1], size[2], slot)], cols=[] if cols is None else cols, size=list(size))
    model(name, shapes)

    if budget is not None:
        PIECES[name]["budget"] = budget


# Trees

# An oak: a trunk flared at its foot, four limbs out of it, a broad crown of
# leaf cards over them (and under, for the man beneath it).
_OAK_TRUNK = [ks.lathe(0.0, 0.0, 0.0, [[0.62, 0.0], [0.42, 0.35], [0.34, 1.4], [0.3, 2.8], [0.24, 3.8], [0.14, 5.0]], 8, "bark")]
_OAK_LIMBS = [_limb(0.0, 3.0 + 0.3 * i, 0.0, 3.0 - 0.3 * i, 0.2, 0.07, 40.0 + i * 92.0, 48.0 - i * 4.0) for i in range(4)]
_plant("tree_oak", "leaf_crown", "wood", [8.8, 9.4, 8.8],
       _OAK_TRUNK + _OAK_LIMBS
       + _crown(11, [0.0, 6.4, 0.0], [3.4, 2.5, 3.4], 34, "leaf_crown", (2.0, 2.9), shell=(0.55, 1.0), droop=25.0)
       + _crown(12, [0.0, 6.2, 0.0], [1.8, 1.4, 1.8], 8, "leaf_crown", (1.8, 2.4), shell=(0.1, 0.7)),
       cols=[[0.0, 2.5, 0.0, 0.8, 5.0, 0.8, "wood", 0, 0, 0]], budget=600)

# A yew, old and squat, dark as a hole in the night: a thick short trunk, a
# dome of needles to the ground nearly.
_plant("tree_yew", "yew", "wood", [6.4, 6.4, 6.4],
       [ks.lathe(0.0, 0.0, 0.0, [[0.7, 0.0], [0.55, 0.5], [0.5, 1.8], [0.3, 2.6]], 8, "bark")]
       + [_limb(0.0, 1.5, 0.0, 2.0, 0.24, 0.08, 20.0 + i * 120.0, 42.0) for i in range(3)]
       + _crown(21, [0.0, 3.4, 0.0], [2.8, 2.7, 2.8], 38, "yew", (1.6, 2.3), shell=(0.6, 1.0), droop=30.0)
       + _crown(22, [0.0, 3.4, 0.0], [1.5, 1.6, 1.5], 8, "yew", (1.4, 1.9), shell=(0.1, 0.6)),
       cols=[[0.0, 1.3, 0.0, 1.0, 2.6, 1.0, "wood", 0, 0, 0]], budget=600)

# A dead tree: a tall grey trunk, bare limbs reaching, twigs at their ends:
# a black lace against the moon.
_DEAD_LIMBS = [_limb(0.0, 2.4 + 0.55 * i, 0.0, 3.2 - 0.25 * i, 0.16, 0.04, 15.0 + i * 71.0, 55.0 - i * 5.0, sides=5) for i in range(6)]
_DEAD_TWIGS = []

for _i in range(6):
    _yaw = math.radians(15.0 + _i * 71.0)
    _lean = math.radians(55.0 - _i * 5.0)
    _len = 3.2 - 0.25 * _i
    _tip = [math.sin(_yaw) * math.sin(_lean) * _len, 2.4 + 0.55 * _i + math.cos(_lean) * _len, math.cos(_yaw) * math.sin(_lean) * _len]
    _DEAD_TWIGS.append(ks.card(_tip[0], _tip[1] + 0.5, _tip[2], 2.4, 2.4, "twigs", math.degrees(_yaw), -10.0, round=[0.0, 5.5, 0.0]))
    _DEAD_TWIGS.append(ks.card(_tip[0], _tip[1] + 0.5, _tip[2], 2.0, 2.2, "twigs", math.degrees(_yaw) + 90.0, 10.0, round=[0.0, 5.5, 0.0]))

_plant("tree_dead", "twigs", "wood", [7.6, 8.4, 7.6],
       [ks.lathe(0.0, 0.0, 0.0, [[0.5, 0.0], [0.34, 0.4], [0.27, 2.4], [0.18, 4.6], [0.08, 6.4]], 7, "bark")]
       + _DEAD_LIMBS + _DEAD_TWIGS
       + [ks.card(0.0, 6.8, 0.0, 2.6, 2.6, "twigs", yaw, 0.0, round=[0.0, 5.5, 0.0]) for yaw in (0.0, 90.0)],
       cols=[[0.0, 2.2, 0.0, 0.7, 4.4, 0.7, "wood", 0, 0, 0]], budget=500)

# Shrubs and ground cover

# A shrub: a dome of leaf cards (a man crouched behind it is hidden).
PIECES["bush"]["size"] = [2.2, 1.6, 2.2]
model("bush", _crown(31, [0.0, 0.95, 0.0], [0.95, 0.6, 0.95], 13, "leaf_shrub", (1.0, 1.35), shell=(0.35, 0.9)))

_plant("grass_tuft", "grass_blades", "grass", [0.8, 0.6, 0.8], _crossed(0.75, 0.55, "grass_blades"))
PIECES["weeds"]["size"] = [0.9, 0.8, 0.9]
model("weeds", _crossed(0.85, 0.75, "weed_broad"))
_plant("reeds_clump", "reeds", "grass", [1.2, 1.9, 1.2], _crossed(0.95, 1.9, "reeds", cards=4))

# Ivy up a wall: a mat of it just before the stone (the wall at the piece's
# back, local z 0; its front +z), a ragged top.
_plant("ivy_2x3", "ivy", "stone", [2.0, 3.0, 0.2], [ks.card(0.0, 1.5, 0.06, 2.0, 3.0, "ivy")])
_plant("ivy_1x2", "ivy", "stone", [1.0, 2.0, 0.2], [ks.card(0.0, 1.0, 0.05, 1.0, 2.0, "ivy")])
