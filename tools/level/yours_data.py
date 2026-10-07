"""Your pieces: the kit pieces you edited in a district's workshop .blend
(workshop.py), found there by yours.py and written to
assets/level/source/yours.json:

    {"pieces": {"<piece>": {"file": "workshop_harbour.blend",  (your mesh's)
                            "mesh": true,      your mesh is the piece's (kit.py)
                            "base": "<hash>",  the generated mesh you started from
                            "cols": [...],     your colliders, or null for the recipe's
                            "occlusion_exclude": [...],
                            "cols_file": "workshop_harbour.blend"}}}

kit_recipes applies your colliders at its end (so the rules, the export and
the tests all see them); kit.py takes your mesh in place of the generated
one. Pure Python, no Blender. LEVEL_YOURS: another file to read, or "off"
for none (the generators' own tests).
"""

import json
import os
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
DEFAULT = ROOT / "assets" / "level" / "source" / "yours.json"


def path():
    """yours.json's path, or None when LEVEL_YOURS is "off"."""
    own = os.environ.get("LEVEL_YOURS")

    if own == "off":
        return None

    return Path(own) if own else DEFAULT


def load():
    """{piece: yours} from yours.json; {} without one."""
    p = path()

    if p is None or not p.exists():
        return {}

    return json.loads(p.read_text()).get("pieces", {})


def save(pieces, to=None):
    p = Path(to) if to else path()
    p.write_text(json.dumps({"pieces": {k: pieces[k] for k in sorted(pieces)}}, indent=1, sort_keys=True) + "\n")


def apply(pieces, yours):
    """Your colliders in place of each recipe's (and which of its boxes do
    not hide what is behind them); a piece whose mesh is yours marked
    `yours_mesh` with the workshop it is in. Returns the names no longer in
    the kit (orphans: left in yours.json, used by nothing)."""
    orphans = []

    for name, mine in yours.items():
        recipe = pieces.get(name)

        if recipe is None:
            orphans.append(name)
            continue

        if mine.get("cols") is not None:
            # (The generator's kept: a workshop tells yours from its.)
            recipe.setdefault("generated_cols", recipe["cols"])
            recipe.setdefault("generated_exclude", list(recipe.get("occlusion_exclude", [])))
            recipe["cols"] = [list(c) for c in mine["cols"]]
            recipe["occlusion_exclude"] = list(mine.get("occlusion_exclude", []))
            recipe["yours_cols"] = True

        if mine.get("mesh"):
            recipe["yours_mesh"] = mine["file"]

    return sorted(orphans)
