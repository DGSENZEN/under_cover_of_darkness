extends RefCounted
## A district's memory (the old town's spec, section 3A): everything done in
## it, captured from its changeable things (each one's save_state()) and
## applied again to a fresh build of it (load_state()), keyed by marker name.
##
##   made: the district's {level name: LevelGameplay.build_all's dictionary}
##   guards: {marker name: guard} as its map made them (a downed one freed);
##           apply drops the names of men who are down or away
##   visitors: {name: Guard.spec()} of the men who followed the player in
##             through a gate (CityState), kept even once they are down
##
## The state: {"doors", "chests", "pickups", "lights": {name: state},
## "props": {name: Transform3D}, "mechanisms": {name: state string},
## "guards": {name: state, or {"down": true}, or {"away": true}},
## "bodies": [GuardBody.save_state()], "visitors": {name: {"spec", "state"
## or "down"}}}.

const LevelGameplay := preload("res://scripts/Level/LevelGameplay.gd")

## The kinds kept as {name: node} by build_all whose nodes save themselves.
const KINDS := ["doors", "chests", "pickups", "lights"]
## The guard scene, loaded when a man who followed the player in is made again.
const GUARD_SCENE := "res://Guard.tscn"


## What was done in the district: see above.
static func capture(parent: Node, made: Dictionary, guards: Dictionary, visitors := {}) -> Dictionary:
	var state := {"doors": {}, "chests": {}, "pickups": {}, "lights": {}, "props": {}, "mechanisms": {}, "guards": {}, "bodies": [],
		"visitors": {}}

	for level in made:
		var built: Dictionary = made[level]

		for kind in KINDS:
			for marker_name in built.get(kind, {}):
				var node: Variant = built[kind][marker_name]

				if node == null or not is_instance_valid(node):
					# (A pickup frees itself when it is taken.)
					if kind == "pickups":
						state["pickups"][marker_name] = {"taken": true}

					continue

				if node.has_method("save_state"):
					state[kind][marker_name] = node.save_state()

		for node in built.get("props", []):
			if is_instance_valid(node):
				state["props"][String(node.name)] = (node as Node3D).global_transform

		for node in built.get("mechanisms", []):
			if is_instance_valid(node):
				state["mechanisms"][String(node.name)] = String(node.get_meta(&"state", ""))

	for marker_name in guards:
		var g: Variant = guards[marker_name]

		if visitors.has(marker_name):
			continue

		var up: bool = g != null and is_instance_valid(g) and not bool(g.get("_knocked_out"))
		state["guards"][marker_name] = g.save_state() if up else {"down": true}

	for visitor_name in visitors:
		var g: Variant = guards.get(visitor_name)
		var up: bool = g != null and is_instance_valid(g) and not bool(g.get("_knocked_out"))
		state["visitors"][visitor_name] = {"spec": visitors[visitor_name], "state": g.save_state()} if up \
			else {"spec": visitors[visitor_name], "down": true}

	for body in parent.get_tree().get_nodes_in_group(&"bodies"):
		if parent.is_ancestor_of(body) and body.has_method("save_state"):
			state["bodies"].append(body.save_state())

	return state


## A fresh build of the district put as it was left (capture). The men who
## followed the player in are made again (LevelGameplay.visitor) and added to
## `guards` and `visitors`.
static func apply(parent: Node3D, made: Dictionary, guards: Dictionary, state: Dictionary, visitors := {}) -> void:
	for level in made:
		var built: Dictionary = made[level]

		for kind in KINDS:
			for marker_name in state.get(kind, {}):
				var node: Variant = built.get(kind, {}).get(marker_name)

				if node != null and is_instance_valid(node) and node.has_method("load_state"):
					node.load_state(state[kind][marker_name])

		for node in built.get("props", []):
			if is_instance_valid(node) and state.get("props", {}).has(String(node.name)):
				var body := node as RigidBody3D
				body.global_transform = state["props"][String(node.name)]
				body.linear_velocity = Vector3.ZERO
				body.sleeping = true
				body.reset_physics_interpolation()

		for node in built.get("mechanisms", []):
			if not is_instance_valid(node) or not state.get("mechanisms", {}).has(String(node.name)):
				continue

			var was: String = state["mechanisms"][String(node.name)]

			if String(node.get_meta(&"kind", "")) == "portcullis":
				LevelGameplay.raise(node, was == "up")
			else:
				node.set_meta(&"state", was)

	for visitor_name in state.get("visitors", {}):
		var entry: Dictionary = state["visitors"][visitor_name]
		var at: Transform3D = entry["state"]["transform"] if entry.has("state") else Transform3D.IDENTITY
		var g := LevelGameplay.visitor(parent, entry["spec"], at, load(GUARD_SCENE) as PackedScene)
		guards[visitor_name] = g
		visitors[visitor_name] = entry["spec"]

		if entry.has("state"):
			g.load_state(entry["state"])

	var bodies := {}

	for body in state.get("bodies", []):
		bodies[String(body["guard"])] = body

	var guard_states: Dictionary = state.get("guards", {})
	var visitor_states: Dictionary = state.get("visitors", {})

	for marker_name in guard_states.keys() + visitor_states.keys():
		var saved: Dictionary = guard_states.get(marker_name, visitor_states.get(marker_name, {}))
		var g: Variant = guards.get(marker_name)

		if g == null or not is_instance_valid(g):
			continue

		if saved.has("away"):
			g.queue_free()
			guards.erase(marker_name)
		elif saved.has("down"):
			if bodies.has(marker_name):
				var body: Dictionary = bodies[marker_name]
				g.restore_downed(body["transform"], bool(body["dead"]), bool(body["discovered"]))
			else:
				g.queue_free()

			guards.erase(marker_name)
		elif guard_states.has(marker_name):
			g.load_state(saved)
