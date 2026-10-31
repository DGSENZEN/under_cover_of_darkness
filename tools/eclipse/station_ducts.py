"""The Zócalo station's ducts (the user, Oct 31 2026: "more engrained towards the terrain"): the floor's mains half sunk
along the walls' feet, the cable trays under the coffers, the floor's fuming mouths and their feeds. Their shapes live
in station_pipes (one machine, one set of measures); they paint on an atlas of their own, so the pipework keeps its
texel density.

    Blender -b --factory-startup --python tools/eclipse/station_ducts.py
"""

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import common  # noqa: E402
import station_pipes  # noqa: E402
from underground_shapes import smooth_object  # noqa: E402

NAME = "station_ducts"
ATLAS = 4096
SLOTS = ["iron", "brass", "rubber"]
PIECES = station_pipes.DUCT_PIECES
BUDGET = {n: 24000 for n, _ in PIECES}
SLIVER = {n: 0.004 for n, _ in PIECES}


def build():
    common.reset()
    for name, f in PIECES:
        smooth_object(name, f)


def main():
    build()
    common.export_piece(NAME, ATLAS, SLOTS, out=common.ROOT / "assets" / "eclipse" / "kit", sets_each=True,
                        budget=max(BUDGET.values()), sliver=min(SLIVER.values()), pack_margin=0.0015)


if __name__ == "__main__":
    main()
