"""What a level's markers are (tools/level): gameplay placed in Blender as
empties (or box volumes) carrying the custom property `ucd` and its own.

The check reads this to refuse a level with an unknown marker or one missing
what it needs; `export.py` writes a JSON copy beside each level
(markers.json) that the Godot side (scripts/Level/LevelLoader.gd) reads.
An object's name is its id: links (a guard's route, a door's key) use it.

Each entry: the properties it must have, those it may have (with their
defaults), and whether it is a box (its extent is its size).
"""

import json

SCHEMA = {
    # The canal spec's (section 6.3), as the garrison uses them.
    "spawn": {"required": [], "optional": {}, "box": False},
    "guard": {"required": ["archetype"], "optional": {"temperament": "", "route": "", "lookout": False, "stations": "",
                                                      "voice": "", "look_seed": 0, "role": ""}, "box": False},
    "route": {"required": [], "optional": {}, "box": False},
    "waypoint": {"required": ["route", "order"], "optional": {"wait": 0.0}, "box": False},
    "door": {"required": [], "optional": {"kind": "hinged", "locked": False, "key": "", "label": "", "width": 1.2,
                                          "height": 2.2, "barred": False}, "box": False},
    "light": {"required": ["kind"], "optional": {"lit": True, "energy": 0.0, "range": 0.0, "color": "", "cookie": "",
                                                 "douse": True}, "box": False},
    "bell": {"required": [], "optional": {"db": 90.0}, "box": False},
    "ladder": {"required": [], "optional": {"rope": False}, "box": True},
    "landmark": {"required": ["label"], "optional": {}, "box": False},
    "trigger": {"required": ["event"], "optional": {}, "box": True},
    "sector": {"required": [], "optional": {"label": ""}, "box": True},
    "water": {"required": [], "optional": {"murk": 0.6}, "box": True},
    # The garrison's own (the garrison spec, section 5.3).
    "station": {"required": ["kind"], "optional": {"chest": "", "drop_to": ""}, "box": False},
    "hide": {"required": [], "optional": {"label": ""}, "box": False},
    "hunt_area": {"required": ["label"], "optional": {}, "box": True},
    "vantage": {"required": [], "optional": {"lens": ""}, "box": False},
    "zone": {"required": ["grade"], "optional": {"fog": 1.0, "fog_color": ""}, "box": True},
    "mark": {"required": [], "optional": {}, "box": False},
}

STATION_KINDS = ["sit", "eat", "sleep", "rummage", "carry", "chop", "lean", "pray", "drill"]
LIGHT_KINDS = ["torch", "brazier", "candle", "lantern", "window", "chandelier", "window_shaft", "hearth", "fire", "glow", "lamp_post"]
ARCHETYPES = ["watchman", "swordsman", "archer", "duelist", "brute", "arms_master"]
GRADES = ["outside", "indoors", "chapel", "cellar", "hearth"]


def problems(marker):
    """What is wrong with one marker (a dict: name, ucd, props, size), as
    sentences; none if it is right."""
    out = []
    ucd = marker.get("ucd", "")
    props = marker.get("props", {})

    if ucd not in SCHEMA:
        return ["%s: no marker called '%s'" % (marker.get("name", "?"), ucd)]

    entry = SCHEMA[ucd]

    for key in entry["required"]:
        if key not in props or props[key] in ("", None):
            out.append("%s (%s): needs '%s'" % (marker["name"], ucd, key))

    if entry["box"] and not marker.get("size"):
        out.append("%s (%s): a box marker needs a size" % (marker["name"], ucd))

    if ucd == "station" and props.get("kind") not in STATION_KINDS:
        out.append("%s: no station kind '%s'" % (marker["name"], props.get("kind")))

    if ucd == "light" and props.get("kind") not in LIGHT_KINDS:
        out.append("%s: no light kind '%s'" % (marker["name"], props.get("kind")))

    if ucd == "guard" and props.get("archetype") not in ARCHETYPES:
        out.append("%s: no archetype '%s'" % (marker["name"], props.get("archetype")))

    if ucd == "zone" and props.get("grade") not in GRADES:
        out.append("%s: no grade '%s'" % (marker["name"], props.get("grade")))

    return out


def with_defaults(marker):
    props = dict(SCHEMA.get(marker["ucd"], {}).get("optional", {}))
    props.update(marker.get("props", {}))
    return dict(marker, props=props)


def write_json(path):
    with open(path, "w") as out:
        json.dump({"schema": SCHEMA, "station_kinds": STATION_KINDS, "light_kinds": LIGHT_KINDS, "grades": GRADES}, out, indent=1)
