"""The old town's ground (its spec, section 4.3; town.TERRACES): a terrain
for each plate, flat (the Baixa's rising gently), CELL a vertex, the Sea
Gate's passage left out (its own floor is its floor). The steps between
plates are the quarters' retaining walls and stairs. A quarter's HOLES
(vertices) are left out: the cells round each (a hatch's collar paves
them)."""

import terrain

import town

CELL = 2.5
# What each quarter is paved with.
SLOTS = {"baixa": "calcada", "stairs": "cobble", "judiaria": "calcada", "carmo": "flagstone", "upper": "cobble"}


def _passage(x, z):
    """The vertices left out under the Sea Gate's passage: the cells round
    them run from its mouth's line (z PASSAGE_MOUTH) to under the gate's
    front, where the layout lays the passage's floor (PASSAGE_FLOOR)."""
    x0, x1, z0, z1 = town.PASSAGE
    return x0 < x < x1 and z0 + CELL - 1e-6 <= z <= z1 + 1e-6


# The passage's own floor (x0, z0, x1, z1): its mouth on the square a cell
# in from the passage's end (the ground's cells meet it there), on under the
# gate's front.
PASSAGE_FLOOR = (-57.0, -90.0, -53.0, -72.0)


def lay(L):
    holes = town.ground_holes()

    for plate in town.TERRACES:
        name, quarter, x0, z0, x1, z1, _south, _north = plate

        for hx, hz in holes:
            if x0 < hx < x1 and z0 < hz < z1 and (abs((hx - x0) / CELL - round((hx - x0) / CELL)) > 1e-6 or
                                                  abs((hz - z0) / CELL - round((hz - z0) / CELL)) > 1e-6 or
                                                  abs((x1 - x0) / CELL - round((x1 - x0) / CELL)) > 1e-6 or
                                                  abs((z1 - z0) / CELL - round((z1 - z0) / CELL)) > 1e-6):
                raise ValueError("the hole at (%.2f, %.2f) is not on %s's vertices" % (hx, hz, name))

        def ground(x, z, plate=plate):
            if _passage(x, z) or any(abs(x - hx) < 0.01 and abs(z - hz) < 0.01 for hx, hz in holes):
                return town.HOLE

            return town.plate_height(plate, z)

        def slot(x, y, z, slope, quarter=quarter):
            return SLOTS[quarter]

        L.terrain(terrain.grid("ground_" + name, town.sector_of((x0 + x1) / 2.0, (z0 + z1) / 2.0), x0, z0, x1, z1, CELL, ground, slot,
                               surface="stone", keep=lambda ys: min(ys) > town.HOLE + 1.0))

    # (The passage's floor through the Sea Gate, level with the square
    # before it: the harbour's own is not shared.)
    x0, z0, x1, z1 = PASSAGE_FLOOR
    L.floor(x0, z0, x1, z1, kind="granite", y=town.height((x0 + x1) / 2.0, z0 - 5.0), sector="wall")
