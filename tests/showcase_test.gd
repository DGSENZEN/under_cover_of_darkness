extends Node
## The NPC showcase (maps/npc_showcase.tscn): the yard and its people, the
## director's acts and beats, the camera and the viewer's overlay.
##
##   Godot --headless --fixed-fps 60 --quit-after 3000000 --path . res://tests/showcase_test.tscn

const MAP := preload("res://maps/npc_showcase.tscn")
const MapScript := preload("res://maps/npc_showcase.gd")
const SquadScript := preload("res://scripts/AISystem/Squad.gd")
const GarrisonScript := preload("res://scripts/AISystem/Garrison.gd")
const GuardScript := preload("res://scripts/AISystem/Guard.gd")

## Who is at which kind of station at the start of the night.
const STATIONED := {"Piers": &"sit", "Col": &"eat", "Tam": &"sleep", "Gideon": &"rummage", "Ned": &"carry", "Brand": &"chop"}
## What each station's man shows at it.
const SHOWS := {
	&"sit": [&"sit", &"sit_talk", &"sit_down"],
	&"eat": [&"eat", &"", &"talk", &"listen", &"fold_arms", &"drink"],
	&"sleep": [&"sleep", &"lie_down"],
	&"rummage": [&"lid", &"rummage", &""],
	&"carry": [&"carry", &"lift", &"set_down", &""],
	&"chop": [&"chop", &"drink"],
}

var results: Array[String] = []


func _ready() -> void:
	await _run()
	GuardScript.randomize_on = true
	print("\n==== RESULTS ====")
	for r in results:
		print(r)
	get_tree().quit()


func _run() -> void:
	# D1 the yard builds and bakes, and its people are where they belong
	var map := await _map(false)
	await _frames(1200)
	var missing := []

	for name in MapScript.CAST_NAMES:
		if not map.cast.has(name) or not is_instance_valid(map.cast[name]):
			missing.append(name)

	var wrong := []

	for name in STATIONED:
		var man: Node = map.cast.get(name)

		if man == null or not is_instance_valid(man) or not (StringName(man.activity()) in SHOWS[STATIONED[name]]) or man._rota._held() == null:
			wrong.append("%s:%s" % [name, man.activity() if man != null and is_instance_valid(man) else "gone"])

	var jory: Node3D = map.cast.get("Jory")
	var posted: bool = jory != null and jory.global_position.distance_to(map.marks["postern_post"]) < 1.2
	var nav := get_viewport().world_3d.navigation_map
	var path := NavigationServer3D.map_get_path(nav, map.marks["gate"], map.marks["postern_post"], true)
	var length := 0.0

	for i in range(1, path.size()):
		length += path[i - 1].distance_to(path[i])

	var straight: float = (map.marks["gate"] as Vector3).distance_to(map.marks["postern_post"])
	_check("D1 the yard builds and bakes, every cast member stands at his place, and each station has its man",
		missing.is_empty() and wrong.is_empty() and posted and path.size() > 1 and length < straight * 1.6,
		"missing %s, not at their stations %s, Jory at his post %s, gate to postern %.1f m walked for %.1f m straight" % [missing, wrong, posted, length, straight])

	# D1b the carrier really carries: crates from the cart to the store
	var drop: Vector3 = map.get_node("CratesDrop").global_position
	await _until(func(): return _crates_near(drop, 2.2) >= 1, 3600)
	_check("D1b Ned carries crates off the cart to the store's north end",
		_crates_near(drop, 2.2) >= 1,
		"crates at the store %d, Ned %s at %s" % [_crates_near(drop, 2.2), map.cast["Ned"].activity(), map.cast["Ned"].global_position])
	await _unload(map)


func _crates_near(point: Vector3, reach: float) -> int:
	var count := 0

	for crate in get_tree().get_nodes_in_group(&"cargo"):
		if Vector2(crate.global_position.x - point.x, crate.global_position.z - point.z).length() < reach:
			count += 1

	return count


## The showcase, loaded; `show` false leaves the director out (the people
## just live).
func _map(show: bool) -> Node:
	MapScript.run_show = show
	var map: Node = MAP.instantiate()
	add_child(map)
	await map.ready_to_show
	return map


func _unload(map: Node) -> void:
	map.queue_free()
	await _frames(3)
	SquadScript.clear_all()
	GarrisonScript.clear_all()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _until(cond: Callable, max_frames: int) -> void:
	for i in max_frames:
		if cond.call():
			return
		await get_tree().physics_frame


func _check(test_name: String, ok: bool, detail: String) -> void:
	results.append("%s  %s   [%s]" % ["PASS" if ok else "FAIL", test_name, detail])
