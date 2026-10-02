extends Node3D
## The crane's wheel stays solid to movement, while its open center stays visible.
const Loader := preload("res://scripts/Level/LevelLoader.gd")
var failed := false

func _ready() -> void:
	print("==== RESULTS ====")
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/level/city_harbour/city_harbour.json"))
	var wheel: Dictionary
	for c in manifest["colliders"]:
		if c["sector"] == "shipyard" and c["centre"] == [130.7, 4.7, -3.0] and c["size"] == [1.1, 4.0, 4.0]:
			wheel = c
			break
	_check("MC1 the shipped crane wheel excludes its solid visual proxy", not wheel.is_empty() and wheel.get("occluder", true) == false)
	if wheel.is_empty():
		get_tree().quit(1)
		return
	var level := Loader.Level.new()
	level.root = self
	var solid := wheel.duplicate(true)
	solid["centre"] = [0, 10, 0]
	solid["occluder"] = true
	Loader._occluders(level, [wheel, solid])
	var occ := find_children("*", "OccluderInstance3D", true, false)
	_check("MC2 an open wheel cannot occlude, while a solid box still can", occ.size() == 1 and (occ[0] as Node3D).position.distance_to(Vector3(0, 10, 0)) < 0.01)
	Loader._colliders(level, [wheel])
	for i in 3:
		await get_tree().physics_frame
	var query := PhysicsRayQueryParameters3D.create(Vector3(128, 4.7, -3), Vector3(133, 4.7, -3), 1)
	_check("MC3 the crane retains its original movement collision", not get_world_3d().direct_space_state.intersect_ray(query).is_empty())
	get_tree().quit(1 if failed else 0)

func _check(label: String, okay: bool) -> void:
	failed = failed or not okay
	print("%s %s" % ["PASS" if okay else "FAIL", label])
