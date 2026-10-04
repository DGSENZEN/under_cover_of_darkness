"""The city's Mediterranean planting (kit v1): a date palm, a cypress, an
orange tree in its stone planter, an agave. Our own painted foliage on
cards (tools/textures/paint.py), stirred by the wind; trunks stop men,
leaves do not. Pure data, as kit_recipes (which imports this at its end).
"""

import math

import kit_shapes as ks
from kit_nature import _crossed, _crown, _plant


def _palm():
    height = 9.0
    trunk = [ks.lathe(0.0, 0.0, 0.0, [[0.32, 0.0], [0.24, 0.6], [0.22, 3.0], [0.2, 6.0], [0.24, height - 0.3], [0.3, height]], 8, "bark",
                      pitch=3.0)]
    top = [math.sin(math.radians(3.0)) * height, height, 0.0]
    fronds = []

    for i in range(12):
        yaw = i * 30.0 + (10.0 if i % 2 else 0.0)
        a = math.radians(yaw)
        droop = -20.0 if i % 2 == 0 else -38.0
        out = 1.3
        fronds.append(ks.card(top[0] + math.sin(a) * out, top[1] - 0.2, top[2] + math.cos(a) * out, 3.0, 3.0, "palm_frond", yaw + 90.0,
                              droop, round=[top[0], top[1] - 1.5, top[2]]))

    # A few dead fronds hanging under the crown.
    for i in range(4):
        yaw = i * 90.0 + 45.0
        a = math.radians(yaw)
        fronds.append(ks.card(top[0] + math.sin(a) * 0.6, top[1] - 1.4, top[2] + math.cos(a) * 0.6, 1.6, 2.2, "palm_frond", yaw + 90.0, -75.0))

    return trunk + fronds


def _cypress():
    height = 9.5
    return ([ks.lathe(0.0, 0.0, 0.0, [[0.2, 0.0], [0.16, 1.2]], 6, "bark")]
            + [ks.card(0.0, 0.4 + height / 2.0, 0.0, 1.9, height, "cypress", i * 60.0, 0.0, round=[0.0, height * 0.45, 0.0]) for i in range(3)]
            + [ks.card(0.0, 0.4 + height * 0.35, 0.0, 1.6, height * 0.6, "cypress", i * 60.0 + 30.0, 0.0, round=[0.0, height * 0.35, 0.0])
               for i in range(3)])


def _orange_tree():
    return ([ks.box(0.0, 0.3, 0.0, 1.6, 0.6, 1.6, "granite"), ks.box(0.0, 0.58, 0.0, 1.4, 0.05, 1.4, "mud"),
             ks.lathe(0.0, 0.6, 0.0, [[0.14, 0.0], [0.1, 1.1], [0.08, 1.6]], 6, "bark")]
            + _crown(71, [0.0, 2.6, 0.0], [1.3, 1.05, 1.3], 28, "orange_leaves", (1.0, 1.4), shell=(0.6, 0.95), droop=15.0))


_plant("palm_date", "palm_frond", "wood", [7.2, 10.2, 7.2], _palm(), cols=[[0.2, 4.5, 0.0, 0.5, 9.0, 0.5, "wood", 0, 0, 0]], budget=400)
_plant("cypress", "cypress", "wood", [2.2, 10.0, 2.2], _cypress(), cols=[[0.0, 4.5, 0.0, 0.9, 9.0, 0.9, "wood", 0, 0, 0]], budget=300)
_plant("orange_tree", "orange_leaves", "wood", [3.2, 3.8, 3.2], _orange_tree(), cols=[[0.0, 0.3, 0.0, 1.6, 0.6, 1.6, "stone", 0, 0, 0]],
       budget=400)
_plant("agave", "agave", "grass", [1.5, 1.3, 1.5], _crossed(1.4, 1.25, "agave", cards=4, below=2.0), budget=120)
