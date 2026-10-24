"""The Metro Underground corridor's plastered vault (docs/superpowers/refs/underground/recipe.md),
in spans the bay (maps/underground_lab.gd) sets end to end under the vault, each turned one
way or the other so its painting does not repeat: plaster laid on the soffit, painted from
the user's sheets.

A span runs SPAN along x, DEPTH across from the back wall's face (y = 0) to the far wall's,
its underside at z = 0.

    Blender -b --factory-startup --python tools/eclipse/underground_vault.py
"""

import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import common  # noqa: E402
import underground_shapes  # noqa: E402
import underground_walls  # noqa: E402
from underground_shapes import box, smooth_object  # noqa: E402

NAME = "underground_vault"
ATLAS = 2048
SLOTS = ["plaster_vault"]

rng = random.Random(1969)

SPAN = 4.8
# From the back wall's face to the far wall's: the corridor between the tiles and both tiles' depth.
DEPTH = 6.9 + 2 * underground_walls.FACE
THICK = 0.04


def vault_span(m):
    """The soffit's plaster, one span of it."""
    box(m, (0.0, 0.0, 0.0), (SPAN, DEPTH, THICK), "plaster_vault", r=0.0)


def build():
    common.reset()
    underground_shapes.rng = rng
    smooth_object("vault_span", vault_span)


def main():
    build()
    common.export_piece(NAME, ATLAS, SLOTS, out=common.ROOT / "assets" / "eclipse" / "kit", sets_each=True, budget=400)


if __name__ == "__main__":
    main()
