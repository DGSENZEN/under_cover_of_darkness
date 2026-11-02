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
const SaveWords := preload("res://scripts/Save/SaveWords.gd")
const ArtLoading := preload("res://scripts/UI/ArtLoadingScreen.gd")
## How long the HUD's notes about saving stay up (s).
const NOTE_FOR := 1.5

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
## What the last load could not put back ("nothing in <map> has the id <id>").
var last_problems: Array[String] = []
## A load is under way (from asking until it is applied).
var loading := false
## The frame on screen as the pause opened (a named save's picture).
var paused_frame: Image
## Why gather() last refused, if it did.
var last_error := ""

var _registered: Array[Node] = []
var _gone_scene: Node = null
var _holds := {}
## Saves asked for and waiting until saving is allowed: [{kind, named, slot}].
var _waiting: Array[Dictionary] = []
## A save is being gathered or written (one at a time).
var _saving := false
## The scene now came in by a load (no autosave for arriving in it).
var _arrived_by_load := false
## The write under way on a worker thread (-1: none).
var _task := -1


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().scene_changed.connect(_on_scene_changed)


## Quitting mid-write: the write finishes first (a thread cut off as the
## engine stops takes the game down with it).
func _exit_tree() -> void:
	if _task >= 0:
		WorkerThreadPool.wait_for_task_completion(_task)
		_task = -1


func _process(_delta: float) -> void:
	if not _waiting.is_empty() and not _saving and can_save():
		var asked: Dictionary = _waiting.pop_front()
		_save_now(asked["kind"], asked["named"], asked["slot"])


func _unhandled_input(event: InputEvent) -> void:
	if not _in_game_map() or covered():
		return

	if InputMap.has_action(&"quick_save") and event.is_action_pressed(&"quick_save"):
		get_viewport().set_input_as_handled()
		request_save(&"quick")
	elif InputMap.has_action(&"quick_load") and event.is_action_pressed(&"quick_load"):
		get_viewport().set_input_as_handled()
		quickload()


## The current scene is a map of the game (not a gym or the menu).
func _in_game_map() -> bool:
	var scene := get_tree().current_scene
	return scene != null and scene.is_in_group(&"game_map")


## A new scene: a map of the game come into, not by a load, saves itself
## once the loading cover has gone (the request waits for it).
func _on_scene_changed() -> void:
	var by_load := _arrived_by_load
	_arrived_by_load = false
	var city := _city()

	if not by_load and _in_game_map() and city != null and city.run_id != "":
		request_save(&"auto")


# Who saves

## `node` saves itself: called in its _ready.
func register(node: Node) -> void:
	_scene_check()

	if _registered.has(node):
		return

	_registered.append(node)
	node.tree_exiting.connect(_exiting.bind(node), CONNECT_ONE_SHOT)


func is_registered(node: Node) -> bool:
	return _registered.has(node)


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
	if not _holds.is_empty() or loading or covered():
		return false

	var player := _player()

	if player == null or bool(player.get("is_dead")):
		return false

	var frob: Variant = player.get("frob")
	return not (frob != null and is_instance_valid(frob) and frob.has_method("talking") and frob.talking() != null)


## A loading cover is up (a load's, or one on its way to another scene).
func covered() -> bool:
	return not get_tree().get_nodes_in_group(&"loading_cover").is_empty()


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


## A save of `kind` (&"quick", &"auto" or &"named"; `named` its name, `slot`
## one to write over, else the kind's next): now if it may be, else as soon
## as it may (the HUD says it waits).
func request_save(kind: StringName, named := "", slot := "") -> void:
	if _saving or not can_save():
		if not _waiting.any(func(w): return w["kind"] == kind and w["slot"] == slot):
			_waiting.append({"kind": kind, "named": named, "slot": slot})

		save_held.emit(&"busy" if _saving else &"not_now")

		if kind != &"auto":
			_note(SaveWords.HELD)

		return

	_save_now(kind, named, slot)


## Gathers the game now; takes the picture on the next frame drawn (without
## the HUD), or the one grabbed as the pause opened; writes off the main
## thread; says how it went.
func _save_now(kind: StringName, named: String, slot: String) -> void:
	_saving = true
	var city := _city()

	# A game begun without New Game (a map run on its own): a run of its own
	# now, before the city's memory is gathered, and nothing of it forgotten.
	if city != null and city.run_id == "":
		_start_run(city.archetype)

	var body := gather()

	if body.is_empty():
		_saving = false
		_note(SaveWords.FAILED)
		saved.emit("", slot, ERR_INVALID_DATA)
		return

	var run_id: String = city.run_id if city != null else ""
	var into := slot if slot != "" else SaveFiles.next_slot(run_id, kind)
	var scene := get_tree().current_scene
	var header := {"version": SaveMigrations.CURRENT, "run": run_id, "slot": into, "kind": kind, "name": named, "map": scene.scene_file_path,
		"place": SaveWords.PLACES.get(scene.scene_file_path, SaveWords.SOMEWHERE), "archetype": city.archetype if city != null else &"",
		"date": Time.get_unix_time_from_system(), "played": city.played if city != null else 0.0}
	var picture := await _picture()
	var played: float = header["played"]
	_task = WorkerThreadPool.add_task(func():
		var error := SaveFiles.write(run_id, into, header, body, picture)
		SaveFiles.set_played(run_id, played)
		_written.call_deferred(run_id, into, kind, error))


func _written(run_id: String, slot: String, kind: StringName, error: Error) -> void:
	_saving = false

	if _task >= 0:
		WorkerThreadPool.wait_for_task_completion(_task)
		_task = -1

	if error != OK:
		_note(SaveWords.FAILED)
	elif kind != &"auto":
		_note(SaveWords.SAVED)

	saved.emit(run_id, slot, error)


## The game as it was last drawn, without the HUD: a frame from the pause's
## opening when paused, else the next frame with the HUD hidden for it. None
## where nothing is drawn (headless).
func _picture() -> Image:
	if get_tree().paused:
		return paused_frame

	if DisplayServer.get_name() == "headless":
		return null

	var player := _player()
	var hud: CanvasLayer = player.get("hud") if player != null else null
	var was_shown := hud != null and hud.visible

	if was_shown:
		hud.visible = false

	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()

	if was_shown and is_instance_valid(hud):
		hud.visible = true

	return image


## A short line on the player's HUD.
func _note(text: String) -> void:
	var player := _player()
	var hud: Node = player.get("hud") if player != null else null

	if hud != null and hud.has_method("show_caption"):
		hud.show_caption(text, NOTE_FOR)


# Loading

## Loads the run's newest quicksave (nothing while a load is under way).
func quickload() -> Error:
	if loading or covered():
		return ERR_BUSY

	var city := _city()
	var run_id: String = city.run_id if city != null and city.run_id != "" else SaveFiles.last_run()
	var quick := SaveFiles.saves(run_id).filter(func(s): return s["kind"] == &"quick" and s["readable"])

	# The newest that reads whole (a damaged one is passed over).
	for entry in quick:
		var error: Error = await load_slot(run_id, entry["slot"])

		if error != ERR_FILE_CORRUPT:
			return error

	_note(SaveWords.NOTHING_TO_LOAD)
	return ERR_DOES_NOT_EXIST


## Loads a save: read, then its map built under the loading cover and the
## save set on it before the game plays on (unpaused, the pause gone).
func load_slot(run_id: String, slot: String) -> Error:
	if loading or covered():
		return ERR_BUSY

	var read := SaveFiles.read(SaveFiles.root().path_join(run_id).path_join(slot + ".save"))

	if read.has("error"):
		push_warning("save: %s" % read["error"])
		_note(SaveWords.UNREADABLE)
		return ERR_FILE_CORRUPT

	loading = true
	pending = read
	_waiting.clear()
	_arrived_by_load = true
	var city := _city()

	if city != null:
		city.run_id = run_id

	SaveFiles.set_last_run(run_id)
	get_tree().paused = false
	var cover := ArtLoading.open(get_tree())
	cover.fade_in(0.25)
	var error: Error = await cover.change_to(String(read["header"]["map"]))

	if error != OK:
		pending = {}
		loading = false
		_arrived_by_load = false
		_note(SaveWords.UNREADABLE)
	else:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	return error


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

	last_problems = apply(body)

	for problem in last_problems:
		push_warning("save: %s" % problem)

	loading = false
	loaded.emit(String(header.get("run", "")), String(header.get("slot", "")))
	return OK


# Runs and maps

## A new playthrough as `archetype`: a run of its own on disk, the city's
## memory begun again.
func begin_run(archetype: StringName) -> String:
	var city := _city()

	if city != null:
		city.new_game()

	_waiting.clear()
	return _start_run(archetype)


## A run on disk for the game being played, as `archetype`; returns its id.
func _start_run(archetype: StringName) -> String:
	var id := SaveFiles.new_run(archetype)
	var city := _city()

	if city != null:
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
