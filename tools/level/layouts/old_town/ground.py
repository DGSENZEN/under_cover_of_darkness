"""The old town's ground (its spec, section 4.3; town.TERRACES): a terrain
for each plate, flat (the Baixa's rising gently), CELL a vertex, the Sea
Gate's passage left out (its own floor is its floor). The steps between
plates are the quarters' retaining walls and stairs. A quarter's HOLES
(the middles of cells) are left out, one cell each (a hatch's collar paves
it)."""

import terrain

import town

CELL = 2.5
# What each quarter is paved with.
# (The Judiaria's lanes river pebbles, Santa Cruz's empedrado.)
SLOTS = {"baixa": "calcada", "stairs": "cobble", "judiaria": "pebbles", "carmo": "flagstone", "upper": "cobble"}


def cells(plate):
    """A plate's ground's cells across x and along z (terrain.grid's: its
    extent over the whole number of CELLs nearest)."""
    _name, _q, x0, z0, x1, z1, _s, _n = plate
    return (x1 - x0) / max(1, int(round((x1 - x0) / CELL))), (z1 - z0) / max(1, int(round((z1 - z0) / CELL)))


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
            # (The grid's cells: its extent over a whole number of them.)
            cx, cz = cells(plate)
            fx, fz = (hx - x0) / cx - 0.5, (hz - z0) / cz - 0.5

            if x0 < hx < x1 and z0 < hz < z1 and (abs(fx - round(fx)) > 1e-6 or abs(fz - round(fz)) > 1e-6):
                raise ValueError("the hole at (%.2f, %.2f) is not in the middle of one of %s's cells" % (hx, hz, name))

        def ground(x, z, plate=plate):
            return town.HOLE if _passage(x, z) else town.plate_height(plate, z)

        def cut(x, z):
            return any(abs(x - hx) < 0.01 and abs(z - hz) < 0.01 for hx, hz in holes)

        def slot(x, y, z, slope, quarter=quarter):
            return SLOTS[quarter]

        L.terrain(terrain.grid("ground_" + name, town.sector_of((x0 + x1) / 2.0, (z0 + z1) / 2.0), x0, z0, x1, z1, CELL, ground, slot,
                               surface="stone", keep=lambda ys: min(ys) > town.HOLE + 1.0, cut=cut))

    # (The passage's floor through the Sea Gate, level with the square
    # before it: the harbour's own is not shared.)
    x0, z0, x1, z1 = PASSAGE_FLOOR
    L.floor(x0, z0, x1, z1, kind="granite", y=town.height((x0 + x1) / 2.0, z0 - 5.0), sector="wall")
