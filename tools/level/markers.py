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
                                                      "voice": "", "look_seed": 0, "role": "", "light": ""}, "box": False},
    "route": {"required": [], "optional": {}, "box": False},
    "waypoint": {"required": ["route", "order"], "optional": {"wait": 0.0}, "box": False},
    "door": {"required": [], "optional": {"kind": "hinged", "locked": False, "key": "", "label": "", "width": 1.2,
                                          "height": 2.2, "barred": False, "pick": True}, "box": False},
    "light": {"required": ["kind"], "optional": {"lit": True, "energy": 0.0, "range": 0.0, "color": "", "cookie": "",
                                                 "douse": True, "chain": 0.0}, "box": False},
    "bell": {"required": [], "optional": {"db": 90.0}, "box": False},
    "ladder": {"required": [], "optional": {"rope": False, "open": False}, "box": True},
    # A piece laid loose (Layout.put loose=): a body in the game, picked up
    # and thrown; `piece` its name, `mass` its weight (kg).
    "loose": {"required": ["piece", "mass"], "optional": {}, "box": False},
    "landmark": {"required": ["label"], "optional": {}, "box": False},
    "trigger": {"required": ["event"], "optional": {}, "box": True},
    "sector": {"required": [], "optional": {"label": ""}, "box": True},
    "water": {"required": [], "optional": {"murk": 0.6, "shore_area": [], "swim_area": []}, "box": True},
    # The garrison's own (the garrison spec, section 5.3).
    "station": {"required": ["kind"], "optional": {"chest": "", "drop_to": ""}, "box": False},
    "hide": {"required": [], "optional": {"label": ""}, "box": False},
    "hunt_area": {"required": ["label"], "optional": {}, "box": True},
    # Under a roof: the dressing inside it casts no shadow in moonlight
    # (kit_recipes.roofed).
    "roofed": {"required": [], "optional": {}, "box": True},
    # The distance's effects (scripts/Visual/Distance.gd): a far light (a
    # torch on a wall far off, the balefire), its air (mist, corpse-lights).
    "far_light": {"required": ["kind"], "optional": {}, "box": False},
    "far_air": {"required": ["kind"], "optional": {}, "box": True},
    "vantage": {"required": [], "optional": {"lens": ""}, "box": False},
    "zone": {"required": ["grade"], "optional": {"fog": 1.0, "fog_color": ""}, "box": True},
    "mark": {"required": [], "optional": {}, "box": False},
    # Dressing: a decal (grime, a leak, moss; on a floor soot, dirt, straw,
    # leaves) projected onto what is behind it (local -z: into the wall;
    # "floor": straight down instead).
    "decal": {"required": ["kind"], "optional": {"floor": False}, "box": True},
    # The city's (the city spec, section 8): things to take, things to use,
    # the mission's places, the air's noise, and what the level's own tests
    # check; the mechanisms (stubs until their sub-project) are below.
    "loot": {"required": ["value"], "optional": {"label": "goblet", "kind": "", "special": False}, "box": False},
    "key": {"required": ["key_id"], "optional": {"label": "key"}, "box": False},
    "tool": {"required": ["tool"], "optional": {"count": 1, "label": ""}, "box": False},
    "chest": {"required": [], "optional": {"locked": False, "key": "", "pick": True, "label": "chest", "large": False}, "box": False},
    "prop": {"required": ["kind"], "optional": {"mass": 0.0}, "box": False},
    # A rope or a chain hanging from the marker, `length` down.
    "rope": {"required": ["length"], "optional": {"chain": False}, "box": False},
    "objective": {"required": ["label"], "optional": {"kind": "steal"}, "box": False},
    # A way out of the district: `to` names the district it leads to (one of
    # data/districts.json's, or an unbuilt one: sealed), `arrive` the
    # arrival there.
    "exit": {"required": ["label"], "optional": {"to": "", "arrive": ""}, "box": True},
    # Where a player coming through a gate from another district stands,
    # facing in.
    "arrival": {"required": [], "optional": {"label": ""}, "box": False},
    "secret": {"required": [], "optional": {"label": ""}, "box": True},
    # Inside it, sound is masked by `db` (a blowhole's roar, a fountain).
    "noise_zone": {"required": ["db"], "optional": {"period": 0.0, "label": ""}, "box": True},
    # A chimney's smoke, breathed off its pots (over them).
    "smoke": {"required": [], "optional": {}, "box": False},
    # Words to read where it lies or hangs: `slot` names its text in the
    # district's job file (data/jobs/<district>.job); `kind` how it is held.
    "readable": {"required": ["slot"], "optional": {"kind": "paper"}, "box": False},
    # A point the light is checked at: "moon", "shadow" or "lamp".
    "probe": {"required": ["expect"], "optional": {}, "box": False},
    # A point on a way through the level, and the move that reaches it from
    # the one before (the check measures the move: rules.py).
    "route_check": {"required": ["route", "order", "move"], "optional": {}, "box": False},
}

# The mechanisms, one schema each: what they work, the state they start in,
# a portcullis's opening.
MECHANISMS = ["lever", "wheel", "portcullis", "sluice", "hoist", "slider"]

for _kind in MECHANISMS:
    SCHEMA[_kind] = {"required": [], "optional": {"target": "", "state": "", "label": "", "hold": False, "width": 4.0, "height": 5.0},
                     "box": False}

STATION_KINDS = ["sit", "eat", "sleep", "rummage", "carry", "chop", "lean", "pray", "drill"]
LIGHT_KINDS = ["torch", "brazier", "candle", "lantern", "window", "chandelier", "window_shaft", "hearth", "fire", "glow", "lamp_post"]
ARCHETYPES = ["watchman", "swordsman", "archer", "duelist", "brute", "arms_master"]
GRADES = ["outside", "indoors", "chapel", "cellar", "hearth"]
DECAL_KINDS = ["leak_1", "leak_2", "moss", "grime", "soot", "dirt", "straw", "leaves", "salt"]
TOOL_KINDS = ["flask", "flash_bomb", "lockpick", "arrows"]
PROP_KINDS = ["crate", "crate_small"]
MOVES = ["walk", "stairs", "mantle", "hang", "jump", "sprint_jump", "assist_jump", "drop", "climb", "rope", "swim", "balance"]
PROBE_EXPECT = ["moon", "shadow", "lamp"]
READABLE_KINDS = ["notice", "paper", "ledger"]
# What a guard carries on his rounds (Guard.rounds_light).
ROUNDS_LIGHTS = ["", "lantern", "torch"]


def problems(marker):
    """Return list[str] schema failures; [] passes, without mutating marker.

    marker is a dict with name, ucd, props, and size (three-vector or None).
    Unknown ucd returns one failure; properties must match its SCHEMA entry.
    """
    out = []
    ucd = marker.get("ucd", "")
    props = marker.get("props", {})

    if ucd not in SCHEMA:
        return ["%s: no marker called '%s'" % (marker.get("name", "?"), ucd)]

    entry = SCHEMA[ucd]

    for key in entry["required"]:
        if key not in props or props[key] in ("", None):
            out.append("%s (%s): needs '%s'" % (marker["name"], ucd, key))

    for key in props:
        if key not in entry["required"] and key not in entry["optional"]:
            out.append("%s (%s): no property '%s'" % (marker["name"], ucd, key))

    if entry["box"] and not marker.get("size"):
        out.append("%s (%s): a box marker needs a size" % (marker["name"], ucd))

    if ucd == "station" and props.get("kind") not in STATION_KINDS:
        out.append("%s: no station kind '%s'" % (marker["name"], props.get("kind")))

    if ucd == "readable" and props.get("kind", "paper") not in READABLE_KINDS:
        out.append("%s: no readable kind '%s' (%s)" % (marker["name"], props.get("kind"), ", ".join(READABLE_KINDS)))

    if ucd == "light" and props.get("kind") not in LIGHT_KINDS:
        out.append("%s: no light kind '%s'" % (marker["name"], props.get("kind")))

    if ucd == "guard" and props.get("archetype") not in ARCHETYPES:
        out.append("%s: no archetype '%s'" % (marker["name"], props.get("archetype")))

    if ucd == "zone" and props.get("grade") not in GRADES:
        out.append("%s: no grade '%s'" % (marker["name"], props.get("grade")))

    if ucd == "decal" and props.get("kind") not in DECAL_KINDS:
        out.append("%s: no decal kind '%s'" % (marker["name"], props.get("kind")))

    if ucd == "tool" and props.get("tool") not in TOOL_KINDS:
        out.append("%s: no tool '%s'" % (marker["name"], props.get("tool")))

    if ucd == "prop" and props.get("kind") not in PROP_KINDS:
        out.append("%s: no prop kind '%s'" % (marker["name"], props.get("kind")))

    if ucd == "probe" and props.get("expect") not in PROBE_EXPECT:
        out.append("%s: a probe cannot expect '%s'" % (marker["name"], props.get("expect")))

    if ucd == "route_check" and props.get("move") not in MOVES:
        out.append("%s: no move '%s'" % (marker["name"], props.get("move")))

    if ucd == "guard" and props.get("light", "") not in ROUNDS_LIGHTS:
        out.append("%s: no rounds light '%s'" % (marker["name"], props.get("light")))

    return out


def with_defaults(marker):
    """Return a shallow marker dict with fresh props; explicit values win.

    Input is a marker dict with ucd and optional props; unknown kinds gain no
    defaults. Other nested fields retain their original references.
    """
    props = dict(SCHEMA.get(marker["ucd"], {}).get("optional", {}))
    props.update(marker.get("props", {}))
    return dict(marker, props=props)


def write_json(path):
    """Write schema/options JSON to a filesystem path; return None."""
    with open(path, "w") as out:
        json.dump({"schema": SCHEMA, "station_kinds": STATION_KINDS, "light_kinds": LIGHT_KINDS, "grades": GRADES,
                   "tool_kinds": TOOL_KINDS, "prop_kinds": PROP_KINDS, "moves": MOVES, "probe_expect": PROBE_EXPECT,
                   "rounds_lights": ROUNDS_LIGHTS, "mechanisms": MECHANISMS}, out, indent=1)
