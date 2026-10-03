"""The old town's ground (its spec, section 4.3; town.TERRACES): a terrain
for each plate, flat (the Baixa's rising gently), CELL a vertex, the Sea
Gate's passage left out (its own floor is its floor). The steps between
plates are the quarters' retaining walls and stairs."""

import terrain

import town

CELL = 2.5
# What each quarter is paved with.
SLOTS = {"baixa": "calcada", "stairs": "cobble", "judiaria": "calcada", "carmo": "flagstone", "upper": "cobble"}


def lay(L):
    for plate in town.TERRACES:
        name, quarter, x0, z0, x1, z1, _south, _north = plate

        def ground(x, z, plate=plate):
            return town.HOLE if town.inside(x, z, town.PASSAGE) else town.plate_height(plate, z)

        def slot(x, y, z, slope, quarter=quarter):
            return SLOTS[quarter]

        L.terrain(terrain.grid("ground_" + name, town.sector_of((x0 + x1) / 2.0, (z0 + z1) / 2.0), x0, z0, x1, z1, CELL, ground, slot,
                               surface="stone", keep=lambda ys: min(ys) > town.HOLE + 1.0))
