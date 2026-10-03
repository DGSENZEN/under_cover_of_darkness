"""The city's districts (the old town's spec, section 3A): each its own map,
joined to the others by gates. The registry (data/districts.json) is read
here, by the rules that check the gates across levels, and by Godot
(scripts/Level/Districts.gd).

    {"start": district the mission begins in,
     "districts": {name: {"map": its scene, "levels": its levels,
                          "massing": its sector of city_massing (left out
                                     where it is built), "proxy": whether
                                     other maps draw its proxy instead}},
     "unbuilt": districts an exit may name but no one can go to yet}
"""

import json
from pathlib import Path

PATH = Path(__file__).resolve().parents[2] / "data" / "districts.json"


def load(path=PATH):
    """Return the registry dictionary read from `path`."""
    return json.loads(Path(path).read_text())


def district_of(registry, level):
    """Return the name of the district `level` belongs to, or None."""
    for name, entry in registry["districts"].items():
        if level in entry.get("levels", []):
            return name

    return None
