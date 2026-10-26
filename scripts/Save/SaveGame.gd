extends Node
## Saving and loading the game (the save and load spec, sections 3-4), an
## autoload. Everything in play that can change registers itself here
## (register(self) in its _ready) and answers save_state() and load_state();
## its id is its path from the current scene, or its own save_id(). A save
## gathers them all, with the city's memory (CityState), the player and the
## global holders (register_global), into one body; loading builds the map
## as usual under the loading cover, then sets each thing back before the
## first frame is played. What was taken or destroyed in play (freed) is
## remembered by id as gone, and freed again on a fresh build.
##
## The body: {"version", "map", "city", "saveables": {id: state},
## "gone": [id], "player": {"state", "place"}, "globals": {name: state}}.

const SaveFiles := preload("res://scripts/Save/SaveFiles.gd")
const SaveMigrations := preload("res://scripts/Save/SaveMigrations.gd")

signal saved(run_id: String, slot: String, error: Error)
signal loaded(run_id: String, slot: String)
## A save was asked for while saving is not allowed: it waits (`reason`).
signal save_held(reason: StringName)

## {name: holder}: what holds state outside the map (the score, ...).
var globals := {}
## The ids freed in play in the current scene.
var gone: Array[String] = []
## A save read and waiting for its map to be built: {header, body}.
var pending := {}
## A load is under way (from asking until it is applied).
var loading := false
## The frame on screen as the pause opened (a named save's picture).
var paused_frame: Image
## Why gather() last refused, if it did.
var last_error := ""

var _registered: Array[Node] = []
var _gone_scene: Node = null
var _holds := {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


# Who saves

## `node` saves itself: called in its _ready.
func register(node: Node) -> void:
	_scene_check()

	if _registered.has(node):
		return

	_registered.append(node)
	node.tree_exiting.connect(_exiting.bind(node), CONNECT_ONE_SHOT)


## A holder of state outside the map (an autoload, a static's owner).
func register_global(holder_name: String, holder: Object) -> void:
	globals[holder_name] = holder


func _exiting(node: Node) -> void:
	_registered.erase(node)
	var scene := get_tree().current_scene if get_tree() != null else null

	# Taken, broken, killed: freed while its map plays on.
	if node.is_queued_for_deletion() and scene != null and scene.is_ancestor_of(node) and not scene.is_queued_for_deletion():
		var id := id_of(node)

		if not gone.has(id):
			gone.append(id)


## What was freed belongs to the scene it was freed in.
func _scene_check() -> void:
	var scene := get_tree().current_scene if is_inside_tree() else null

	if scene != _gone_scene:
		_gone_scene = scene
		gone.clear()


## `node`'s id: its own save_id() if it gives one, else its path from `scene`
## (the current scene).
func id_of(node: Node, scene: Node = null) -> String:
	if node.has_method("save_id"):
		var own := String(node.save_id())

		if own != "":
			return own

	if scene == null:
		scene = get_tree().current_scene

	return str(scene.get_path_to(node))


## The registered things inside `scene`, in tree order.
func _in(scene: Node) -> Array[Node]:
	var inside: Array[Node] = []

	for node in _registered:
		if is_instance_valid(node) and scene.is_ancestor_of(node):
			inside.append(node)

	inside.sort_custom(func(a, b): return b.is_greater_than(a))
	return inside


## Every id two things share: "<id>: <path A> and <path B>".
func duplicate_ids() -> Array[String]:
	var clashes: Array[String] = []
	var scene := get_tree().current_scene
	var seen := {}

	for node in _in(scene):
		var id := id_of(node)

		if seen.has(id):
			clashes.append("%s: %s and %s" % [id, seen[id].get_path(), node.get_path()])
		else:
			seen[id] = node

	return clashes


# Saving

func _player() -> Node:
	return get_tree().get_first_node_in_group(&"player") if is_inside_tree() else null


func _city() -> Node:
	return get_node_or_null("/root/CityState")


## Whether a save may be made now: not while held (a scripted moment), while
## loading, under the loading cover, while dead or talking, nor with no
## player in play.
func can_save() -> bool:
	if not _holds.is_empty() or loading or get_tree().root.get_node_or_null("ArtLoading") != null:
		return false

	var player := _player()

	if player == null or bool(player.get("is_dead")):
		return false

	var frob: Variant = player.get("frob")
	return not (frob != null and is_instance_valid(frob) and frob.has_method("talking") and frob.talking() != null)


func hold(reason: StringName) -> void:
	_holds[reason] = true


func release(reason: StringName) -> void:
	_holds.erase(reason)


## The game as it is now: the body of a save ({} if refused: see last_error).
func gather() -> Dictionary:
	_scene_check()
	var clashes := duplicate_ids()

	if not clashes.is_empty():
		last_error = "two things share an id: %s" % ", ".join(clashes)
		push_error(last_error)
		return {}

	last_error = ""
	var scene := get_tree().current_scene
	var player := _player()
	var city := _city()
	var body := {"version": SaveMigrations.CURRENT, "map": scene.scene_file_path, "city": city.save_state() if city != null else {},
		"saveables": _states(scene), "gone": gone.duplicate(), "player": {}, "globals": {}}

	if player != null:
		body["player"] = {"state": player.save_state(), "place": player.save_place() if player.has_method("save_place") else {}}

	for holder_name in globals:
		if is_instance_valid(globals[holder_name]):
			body["globals"][holder_name] = globals[holder_name].save_state()

	return body


func _states(scene: Node) -> Dictionary:
	var states := {}

	for node in _in(scene):
		if not node.is_queued_for_deletion():
			states[id_of(node, scene)] = node.save_state()

	return states


# Loading

## Sets the current scene back as `body` has it, in order: the city's memory,
## what was gone, the things in the map, the player, the global holders.
## Returns the problems found (an id the scene does not have); never stops.
func apply(body: Dictionary) -> Array[String]:
	var scene := get_tree().current_scene
	var city := _city()

	if city != null and body.has("city"):
		city.load_state(body["city"])

	var problems := _apply_world(scene, body.get("saveables", {}), body.get("gone", []))
	gone.assign(body.get("gone", []))
	_gone_scene = scene
	var player := _player()
	var saved_player: Dictionary = body.get("player", {})

	if player != null and not saved_player.is_empty():
		player.load_state(saved_player.get("state", {}))

		if player.has_method("load_place") and not (saved_player.get("place", {}) as Dictionary).is_empty():
			player.load_place(saved_player["place"])

		if player is Node3D:
			(player as Node3D).reset_physics_interpolation()

	var saved_globals: Dictionary = body.get("globals", {})

	for holder_name in saved_globals:
		if globals.has(holder_name) and is_instance_valid(globals[holder_name]):
			globals[holder_name].load_state(saved_globals[holder_name])
		else:
			problems.append("no global %s" % holder_name)

	return problems


## The things in `scene` set back: the gone freed, the rest loaded.
func _apply_world(scene: Node, states: Dictionary, gone_ids: Array) -> Array[String]:
	var problems: Array[String] = []
	var by_id := {}

	for node in _in(scene):
		by_id[id_of(node, scene)] = node

	for id in gone_ids:
		if by_id.has(id):
			by_id[id].queue_free()
			by_id.erase(id)

	for id in states:
		if gone_ids.has(id):
			continue

		if not by_id.has(id):
			problems.append("nothing in %s has the id %s" % [scene.name, id])
			continue

		by_id[id].load_state(states[id])

		if by_id[id] is Node3D:
			(by_id[id] as Node3D).reset_physics_interpolation()

	return problems


## The save waiting for `scene` (built under the loading cover), applied.
func apply_pending(scene: Node) -> Error:
	if pending.is_empty():
		return OK

	var header: Dictionary = pending.get("header", {})
	var body: Dictionary = pending.get("body", {})
	pending = {}

	if scene == null or (body.has("map") and body["map"] != scene.scene_file_path):
		loading = false
		return ERR_CANT_CREATE

	for problem in apply(body):
		push_warning("save: %s" % problem)

	loading = false
	loaded.emit(String(header.get("run", "")), String(header.get("slot", "")))
	return OK


# Runs and maps

## A new playthrough as `archetype`: a run of its own on disk, the city's
## memory begun again.
func begin_run(archetype: StringName) -> String:
	var id := SaveFiles.new_run(archetype)
	var city := _city()

	if city != null:
		city.new_game()
		city.run_id = id
		city.archetype = archetype

	SaveFiles.set_last_run(id)
	return id


## The player leaves `scene` for another map: what changed in it is kept
## (the things in it and what was gone; not the player), to be set back by
## enter_map when he comes back.
func leave_map(scene: Node) -> void:
	var city := _city()

	if city != null:
		city.maps[scene.scene_file_path] = {"saveables": _states(scene), "gone": gone.duplicate() if _gone_scene == scene else []}


## The player comes into `scene` again: it is as he left it.
func enter_map(scene: Node) -> void:
	var city := _city()

	if city == null or not city.maps.has(scene.scene_file_path):
		return

	var kept: Dictionary = city.maps[scene.scene_file_path]

	for problem in _apply_world(scene, kept.get("saveables", {}), kept.get("gone", [])):
		push_warning("save: %s" % problem)
