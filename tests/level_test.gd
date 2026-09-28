extends Node3D
## Levels built with the kit (tools/level) put together in Godot
## (scripts/Level): the fixture level (tools/level/layouts/fixture.py), then
## the garrison.
##   Godot --headless --fixed-fps 60 --path . res://tests/level_test.tscn

const LevelLoader := preload("res://scripts/Level/LevelLoader.gd")
const Materials := preload("res://scripts/Visual/Materials.gd")
const GARRISON := preload("res://maps/garrison.tscn")
const MapScript := preload("res://maps/npc_showcase.gd")

var results: Array[String] = []


func _ready() -> void:
	await _fixture()
	await _garrison()
	print("\n==== RESULTS ====")

	for r in results:
		print(r)

	get_tree().quit()


func _fixture() -> void:
	var environment := Environment.new()
	var world := WorldEnvironment.new()
	world.environment = environment
	add_child(world)
	var level: RefCounted = LevelLoader.load_level(self, "res://assets/level/fixture")
	await _frames(3)

	# K1 its sectors, drawn in their slots' materials
	var meshes: Array = level.root.find_children("*", "MeshInstance3D", true, false)
	var dressed: bool = meshes.any(func(m): return range((m as MeshInstance3D).get_surface_override_material_count()).any(
		func(i): return (m as MeshInstance3D).get_surface_override_material(i) == Materials.surface(&"cobble")))
	_check("K1 the level's sectors come in, their surfaces in their slots' materials",
		level.sectors.has("yard") and level.sectors.has("room") and meshes.size() >= 2 and dressed,
		"sectors %s, meshes %d, cobble dressed %s" % [level.sectors.keys(), meshes.size(), dressed])

	# K2 floors say what they are underfoot
	var yard_floor := _ray(Vector3(1, 2, 1), Vector3(1, -1, 1))
	var room_floor := _ray(Vector3(1, 2, -8.6), Vector3(1, -1, -8.6))
	_check("K2 a foot on the yard's cobbles is on stone, on the room's boards on wood",
		_surface(yard_floor) == "stone" and _surface(room_floor) == "wood", "yard %s, room %s" % [_surface(yard_floor), _surface(room_floor)])

	# K3 a wall stands in the way; its doorway does not
	var walled := _ray(Vector3(-3, 1.2, -4), Vector3(-3, 1.2, -8))
	var doorway := _ray(Vector3(0, 1.2, -4), Vector3(0, 1.2, -8))
	_check("K3 the wall blocks, its doorway lets through", not walled.is_empty() and doorway.is_empty(), "wall hit %s, doorway hit %s" % [not walled.is_empty(), not doorway.is_empty()])

	# K4 every marker comes through: its own kinds made, the rest handed on
	var vantages := get_tree().get_nodes_in_group(&"cine_vantage")
	var hides := get_tree().get_nodes_in_group(&"hide_spot")
	var areas := get_tree().get_nodes_in_group(&"hunt_area")
	var guard: Dictionary = level.get_marker("Hendrik")
	var bench: Dictionary = level.get_marker("bench_seat")
	var facing: Vector3 = -(bench["transform"] as Transform3D).basis.z if not bench.is_empty() else Vector3.ZERO
	var ok4: bool = vantages.size() == 1 and StringName((vantages[0] as Node).get_meta(&"lens", &"")) == &"long" and hides.size() == 1 \
		and areas.size() == 1 and ((areas[0] as Node).get_meta(&"box") as AABB).has_point(Vector3(3, 1, 3)) and level.marks.has("well_spot") \
		and level.marks.has("start") and guard.get("props", {}).get("archetype") == "watchman" and guard["props"].get("route") == "yard_round" \
		and bench.get("props", {}).get("kind") == "sit" and facing.distance_to(Vector3(0, 0, 1)) < 0.01 and level.of("waypoint").size() == 2
	_check("K4 the markers come through: vantages, hide spots, hunt areas and marks made; guards, stations and routes handed on",
		ok4, "vantages %d, hides %d, areas %d, marks %s, bench faces %s" % [vantages.size(), hides.size(), areas.size(), level.marks.keys(), facing])

	# K5 an atmosphere zone: the camera in it eases its grade in
	var camera := Camera3D.new()
	add_child(camera)
	camera.make_current()
	camera.global_position = Vector3(0, 1.6, 3)
	await _seconds(1.5)
	var outside: String = level.zones.current
	camera.global_position = Vector3(0, 1.6, -8.6)
	await _seconds(0.3)
	var partway := float(level.zones.look()["saturation"])
	await _seconds(2.5)
	var inside: String = level.zones.current
	var saturation := environment.adjustment_saturation
	_check("K5 the camera walking into a zone eases its grade in (indoors: warm, saturation 1.05)",
		outside == "outside" and inside == "indoors" and absf(saturation - 1.05) < 0.01 and partway < 1.04 and environment.adjustment_color_correction != null,
		"outside %s, inside %s, saturation %.3f (after 0.3 s %.3f)" % [outside, inside, saturation, partway])
	level.root.queue_free()
	camera.queue_free()
	world.queue_free()
	await _frames(2)


func _garrison() -> void:
	MapScript.run_show = false
	var map: Node3D = GARRISON.instantiate()
	add_child(map)
	var frames := [0]

	while not (map.get("_baker") != null and map._baker.is_baked) and frames[0] < 3600:
		await get_tree().process_frame
		frames[0] += 1

	await _frames(30)

	# G1 the garrison builds, bakes and is peopled
	_check("G1 the garrison builds, its navmesh bakes and its twelve are at their places",
		map._baker.is_baked and map.cast.size() == 12, "baked %s after %d frames, cast %d" % [map._baker.is_baked, frames[0], map.cast.size()])

	# G2 every man's place, station, hiding spot and round is on the navmesh
	# and reachable from the courtyard
	var nav_map: RID = map.get_world_3d().navigation_map
	var start := NavigationServer3D.map_get_closest_point(nav_map, Vector3(0, 0, 10))
	var level: RefCounted = map.level
	var lost := []

	for m in level.markers:
		if not (m["ucd"] in ["station", "hide", "guard", "waypoint"]):
			continue

		var at: Vector3 = (m["transform"] as Transform3D).origin
		var on := NavigationServer3D.map_get_closest_point(nav_map, at)

		if on.distance_to(at) > 0.8:
			lost.append("%s off the mesh (%.1f m)" % [m["name"], on.distance_to(at)])
			continue

		var path := NavigationServer3D.map_get_path(nav_map, start, on, true)

		if path.is_empty() or path[path.size() - 1].distance_to(on) > 0.8:
			lost.append("%s unreachable (the way ends at %s)" % [m["name"], path[path.size() - 1].snapped(Vector3.ONE * 0.1) if not path.is_empty() else "nowhere"])

	_check("G2 every post, station, hiding place and round point is on the navmesh and reachable from the courtyard",
		lost.is_empty(), "%s" % [lost.slice(0, 12)])

	# G3 its doors, its lights
	var doors := get_tree().get_nodes_in_group(&"doors")
	var torches := get_tree().get_nodes_in_group(&"torches")
	_check("G3 every door is made (21), and the lights are lit (torches and the rest)",
		doors.size() == 21 and torches.size() >= 20 and map.fire != null, "doors %d, torches %d, fire %s" % [doors.size(), torches.size(), map.fire != null])

	# G4 a zone: the camera in the chapel is in its red and gold
	var camera := Camera3D.new()
	add_child(camera)
	camera.make_current()
	camera.global_position = Vector3(4, 1.7, -20.8)
	await _seconds(2.5)
	_check("G4 the camera in the chapel is in the chapel's grade", level.zones.current == "chapel", "grade %s" % level.zones.current)
	camera.queue_free()
	map.queue_free()
	await _frames(3)
	MapScript.run_show = true


func _ray(from: Vector3, to: Vector3) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(from, to, 1)
	return get_world_3d().direct_space_state.intersect_ray(query)


func _surface(hit: Dictionary) -> String:
	var body: Object = hit.get("collider")
	return String(body.get_meta(&"surface", "")) if body != null else ""


func _seconds(seconds: float) -> void:
	for f in int(round(seconds * 60.0)):
		await get_tree().process_frame


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _check(test_name: String, ok: bool, detail: String) -> void:
	results.append("%s  %s   [%s]" % ["PASS" if ok else "FAIL", test_name, detail])
