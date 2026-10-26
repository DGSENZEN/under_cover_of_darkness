extends Node3D
## Nothing in the playable maps goes unsaved without a reason (the save and
## load spec, section 7): every node with a script in the Metro (with the
## candle lane and the Pasaje set in) and in the Zócalo (V1, V2) is saved (registered
## with SaveGame, or the player and what he holds), or its script is listed
## in data/save/stateless.txt (it holds nothing that changes) or in
## data/save/stage2.txt (its live state comes with stage 2) with a reason;
## and everything saved has a name of its own, the same on every build (V3, V4).
##   Godot --headless --fixed-fps 60 --path . res://tests/save_coverage_test.tscn

const STATELESS := "res://data/save/stateless.txt"
const STAGE2 := "res://data/save/stage2.txt"
const MAPS := {"V1 the Metro": "res://maps/metro.tscn", "V2 the Zócalo": "res://maps/zocalo.tscn"}
## Frames each map plays before it is walked (what it makes as it runs counts).
const FRAMES := 120

var results: Array[String] = []
@onready var save: Node = get_node("/root/SaveGame")


func _ready() -> void:
	var listed := _listed(STATELESS)
	listed.merge(_listed(STAGE2))

	for check in MAPS:
		var map: Node = (load(MAPS[check]) as PackedScene).instantiate()
		add_child(map)

		for i in FRAMES:
			await get_tree().process_frame

		var unsaved := _unsaved(map, listed)
		_check(check, unsaved.is_empty(), "%d unsaved scripts" % unsaved.size())
		# A name Godot made up (@Node@123) is not the same on the next build:
		# what saves itself must have a name of its own.
		var unstable := _unstable(map)
		_check(check.replace("V1", "V3").replace("V2", "V4") + ": every saved thing has a name of its own", unstable.is_empty(), str(unstable.slice(0, 6)))

		for script_path in unsaved:
			print("UNSAVED %s  e.g. %s" % [script_path, unsaved[script_path]])

		remove_child(map)
		map.free()

	print("\n==== RESULTS ====")

	for line in results:
		print(line)

	var failed := results.filter(func(r): return r.begins_with("FAIL")).size()
	print("\n%d pass, %d fail" % [results.size() - failed, failed])
	get_tree().quit()


## The ids of the saved things in `map` that hold a made-up name.
func _unstable(map: Node) -> Array[String]:
	var found: Array[String] = []
	var stack: Array[Node] = [map]

	while not stack.is_empty():
		var node: Node = stack.pop_back()
		stack.append_array(node.get_children())

		if save.is_registered(node) and save.id_of(node).contains("@"):
			found.append(save.id_of(node))

	return found


## {script path: true} from a list file: a path, then "#" and why.
func _listed(path: String) -> Dictionary:
	var found := {}

	for line in FileAccess.get_file_as_string(path).split("\n"):
		var script_path := line.get_slice("#", 0).strip_edges()

		if script_path != "":
			found[script_path] = true

	return found


## {script path: an example node} of every script in `map` neither saved nor listed.
func _unsaved(map: Node, listed: Dictionary) -> Dictionary:
	var unsaved := {}
	var player: Node = get_tree().get_first_node_in_group(&"player")
	var stack: Array[Node] = [map]

	while not stack.is_empty():
		var node: Node = stack.pop_back()
		stack.append_array(node.get_children())
		var script: Script = node.get_script()

		if script == null or save.is_registered(node) or (player != null and (node == player or player.is_ancestor_of(node))):
			continue

		var script_path := script.resource_path if script.resource_path != "" else "(built in)"

		if not listed.has(script_path) and not unsaved.has(script_path):
			unsaved[script_path] = str(map.get_path_to(node))

	return unsaved


func _check(test_name: String, ok: bool, detail: String) -> void:
	results.append("%s  %s   [%s]" % ["PASS" if ok else "FAIL", test_name, detail])
