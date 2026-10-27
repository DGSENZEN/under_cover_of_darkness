extends Node3D
## Diagnostic: what in the Metro judders. The project interpolates physics, so whatever is drawn interpolated but moved
## between physics ticks (in _process) stutters against the interpolated camera. With the physics at 20 ticks a
## second under 60 frames, every interpolated visual whose transform changes on a frame with no tick before it is
## named, grouped by the script that owns it. The player is carried through the Pasaje, the candle lane and both astral
## passages so all of it wakes. Headless:
##   Godot --headless --path . --fixed-fps 60 res://tests/diag_judder.tscn
const MAP := preload("res://maps/metro.tscn")
const SPOTS := [Vector3(-9.0, -11.0, 70.0), Vector3(-9.0, -11.0, 60.0), Vector3(-2.0, -11.0, 75.45),
	Vector3(19.0, -11.0, 78.0), Vector3(-10.0, -11.0, 40.0), Vector3(-9.0, -11.0, 105.0), Vector3(-9.0, -11.0, 88.0)]

var map: Node3D
var found := {}


func _ready() -> void:
	map = MAP.instantiate()
	add_child(map)
	await _frames(30)
	Engine.physics_ticks_per_second = 20
	for spot: Vector3 in SPOTS:
		map.player.global_position = spot + Vector3(0.0, 1.05, 0.0)
		await _frames(30)
		await _watch(90)
	var by_script := {}
	for path: String in found:
		var owner_script: String = found[path]
		by_script[owner_script] = by_script.get(owner_script, []) + [path]
	print("diag: %d juddering nodes, %d owners" % [found.size(), by_script.size()])
	for owner_script: String in by_script:
		var paths: Array = by_script[owner_script]
		print("diag: %-50s %4d  e.g. %s" % [owner_script, paths.size(), paths[0]])
	get_tree().quit(0)


## `n` frames, naming every interpolated visual moved on a frame with no physics tick before it.
func _watch(n: int) -> void:
	var was := {}
	var ticks := Engine.get_physics_frames()
	for node: Node in map.find_children("*", "VisualInstance3D", true, false):
		was[node] = (node as Node3D).global_transform
	for i in n:
		await get_tree().process_frame
		get_tree().paused = false
		var ticked := Engine.get_physics_frames() != ticks
		ticks = Engine.get_physics_frames()
		for node: Node3D in was:
			if not is_instance_valid(node):
				continue
			var now := node.global_transform
			if not ticked and node.is_visible_in_tree() and node.is_physics_interpolated_and_enabled() \
					and not now.is_equal_approx(was[node]):
				found[String(map.get_path_to(node))] = _owner_script(node)
			was[node] = now


## The nearest script up the tree from `node` (its file's name), or its own class.
func _owner_script(node: Node) -> String:
	var up := node
	while up != null and up != map:
		var script: Script = up.get_script()
		if script != null and script.resource_path != "":
			return script.resource_path.get_file()
		up = up.get_parent()
	return node.get_class()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame
		get_tree().paused = false
