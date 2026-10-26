extends RefCounted
## save_state() and load_state() for a schedule or an effect whose state is
## a few plain member variables (the save and load spec, section 5): it lists
## them, and these keep them. A RandomNumberGenerator is kept as its state, so
## its dice carry on where they were; arrays and dictionaries are copied (a
## typed array keeps its type). Nodes are never kept: a script holding them
## writes its own save_state.
##
##   const SAVED := ["_next", "_clock", "_rng"]
##   func save_state() -> Dictionary: return SaveFields.save(self, SAVED)
##   func load_state(state: Dictionary) -> void: SaveFields.restore(self, state, SAVED)

## The fields asked for that the owner does not have ("Script.gd: field"):
## a misspelt list saves nothing for them (the save suite fails on any).
static var missing: Array[String] = []


static func save(owner: Object, fields: Array) -> Dictionary:
	var state := {}

	for field in fields:
		if not (field in owner):
			var where := "%s: %s" % [(owner.get_script() as Script).resource_path.get_file() if owner.get_script() else owner.get_class(), field]

			if not missing.has(where):
				missing.append(where)
				push_error("SaveFields: no field %s" % where)

			continue

		var value: Variant = owner.get(field)

		if value is RandomNumberGenerator:
			state[field] = {"rng_state": (value as RandomNumberGenerator).state}
		elif value is Array or value is Dictionary:
			state[field] = value.duplicate(true)
		else:
			state[field] = value

	return state


## Back as `state` had them: only the listed `fields` (a state can carry
## other keys of the owner's own).
static func restore(owner: Object, state: Dictionary, fields: Array) -> void:
	for field in fields:
		if not state.has(field):
			continue

		var current: Variant = owner.get(field)
		var value: Variant = state[field]

		if current is RandomNumberGenerator:
			(current as RandomNumberGenerator).state = int((value as Dictionary).get("rng_state", (current as RandomNumberGenerator).state))
		elif current is Array:
			(current as Array).assign(value)
		elif current is Dictionary:
			(current as Dictionary).clear()
			(current as Dictionary).merge((value as Dictionary).duplicate(true))
		else:
			owner.set(field, value)
