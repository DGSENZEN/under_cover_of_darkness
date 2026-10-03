extends RefCounted
## The city's districts (the old town's spec, section 3A): data/districts.json,
## read here and by the level pipeline (tools/level/districts.py). Each
## district is its own map; "start" is where the mission begins; "unbuilt"
## names districts an exit may lead to before anyone can go there.

const PATH := "res://data/districts.json"

static var _registry := {}


## The registry, read once.
static func registry() -> Dictionary:
	if _registry.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		_registry = parsed if parsed is Dictionary else {"start": "", "districts": {}, "unbuilt": []}

	return _registry


## A district's entry ({"map", "levels", "massing", "proxy"}), or {}.
static func entry(district: StringName) -> Dictionary:
	return registry()["districts"].get(String(district), {})


## A district's name as the player reads it (its "label"; its id if none).
static func label(district: StringName) -> String:
	return String(entry(district).get("label", String(district)))


## Whether a district is built (has a map one can go to).
static func is_built(district: StringName) -> bool:
	return registry()["districts"].has(String(district))
