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
	_check("G3 every door is made (20), and the lights are lit (torches and the rest)",
		doors.size() == 20 and torches.size() >= 20 and map.fire != null, "doors %d, torches %d, fire %s" % [doors.size(), torches.size(), map.fire != null])

	# G4 a zone: the camera in the chapel is in its red and gold
	var camera := Camera3D.new()
	add_child(camera)
	camera.make_current()
	camera.global_position = Vector3(4, 1.7, -20.8)
	await _seconds(2.5)
	_check("G4 the camera in the chapel is in the chapel's grade", level.zones.current == "chapel", "grade %s" % level.zones.current)

	# G6 lightning through the stained glass: the chapel's shafts of light
	# flare with a flash and die back after it
	var shafts: Array = get_tree().get_nodes_in_group(&"glass_shafts")
	var calm6: Array = shafts.map(func(s): return float((s as Light3D).light_energy))
	map.night.flash()
	await _frames(3)
	var lit6: Array = shafts.map(func(s): return float((s as Light3D).light_energy))
	await _seconds(2.0)
	var after6: Array = shafts.map(func(s): return float((s as Light3D).light_energy))
	var flared6 := not shafts.is_empty() and range(shafts.size()).all(func(i): return lit6[i] >= 3.0 * calm6[i] and after6[i] <= calm6[i] * 1.1)
	_check("G6 a lightning flash flares the chapel's shafts of light through the glass, and they die back after it",
		flared6, "shafts %d, calm %s, in the flash %s, after %s" % [shafts.size(), calm6, lit6, after6])

	# G7 the story's ways: every leg the intruder runs is on the navmesh end
	# to end (over the wall and into the canal by the breach and the roof)
	var legs := [["drop_in", "colonnade_wait"], ["colonnade_post", "gone_to_ground"], ["gone_to_ground", "sneak_3"], ["gone_to_ground", "sneak_1"], ["sneak_1", "sneak_2"],
		["sneak_2", "sneak_3"], ["sneak_3", "chapel_hide"], ["chapel_fight", "captain_door_at"], ["captain_door_at", "escape_stairs"],
		["escape_stairs", "escape_door"], ["escape_door", "escape_climb"], ["escape_climb", "escape_walk"], ["escape_walk", "escape_over"],
		["escape_over", "canal_edge"], ["canal_edge", "canal_swim"], ["captain_door_at", "courtyard_fight"], ["courtyard_fight", "gate_out"]]
	var broken7 := []

	for leg in legs:
		if not (map.marks.has(leg[0]) and map.marks.has(leg[1])):
			broken7.append("%s-%s: no mark" % leg)
			continue

		var a := NavigationServer3D.map_get_closest_point(nav_map, map.marks[leg[0]])
		var b := NavigationServer3D.map_get_closest_point(nav_map, map.marks[leg[1]])
		var way := NavigationServer3D.map_get_path(nav_map, a, b, true)

		if a.distance_to(map.marks[leg[0]]) > 1.0 or b.distance_to(map.marks[leg[1]]) > 1.0 or way.is_empty() or way[way.size() - 1].distance_to(b) > 0.8:
			broken7.append("%s-%s ends at %s" % [leg[0], leg[1], way[way.size() - 1].snapped(Vector3.ONE * 0.1) if not way.is_empty() else "nowhere"])

	# (Over the wall by the breach and the lean-to's roof, not round by the
	# postern.)
	var over7 := NavigationServer3D.map_get_path(nav_map, NavigationServer3D.map_get_closest_point(nav_map, map.marks.get("escape_walk", Vector3.ZERO)),
		NavigationServer3D.map_get_closest_point(nav_map, map.marks.get("escape_over", Vector3.ZERO)), true)
	var over_length := 0.0

	for i in range(1, over7.size()):
		over_length += over7[i - 1].distance_to(over7[i])

	# (And from the chapel's loft straight through onto the barracks' gallery.)
	var loft7 := NavigationServer3D.map_get_path(nav_map, NavigationServer3D.map_get_closest_point(nav_map, map.marks.get("sneak_3", Vector3.ZERO)),
		NavigationServer3D.map_get_closest_point(nav_map, map.marks.get("sneak_2", Vector3.ZERO)), true)
	var loft_length := 0.0

	for i in range(1, loft7.size()):
		loft_length += loft7[i - 1].distance_to(loft7[i])

	# (Up onto the range's roof by the crates: somewhere to go to ground.)
	var roof7: bool = map.marks.has("gone_to_ground") and (map.marks["gone_to_ground"] as Vector3).y > 3.0

	_check("G7 every leg of the intruder's night is a way on the navmesh, onto the range's roof, over the wall (by the breach), through the loft, and into the canal",
		broken7.is_empty() and roof7 and over_length > 0.0 and over_length < 12.0 and loft_length > 0.0 and loft_length < 20.0,
		"%s; to ground on the roof %s, over the wall %.1f m, the loft to the gallery %.1f m" % [broken7, roof7, over_length, loft_length])

	# G5 a man at prayer in the chapel: down on his knees, his head bowed, a
	# murmured line now and then; stirred, he gets up off his knees
	var gideon: Node3D = map.cast["Gideon"]
	var gideon_said := []
	gideon.barked.connect(func(t): gideon_said.append([t, gideon.last_delivery]))
	gideon._rota.set_stations([map._stations["pray_0"]])
	var seen5 := {}
	var bowed5 := [0.0]
	var frame5 := [0]
	await _until(func():
		frame5[0] += 1
		seen5[StringName(gideon.activity())] = true
		if StringName(gideon.activity()) == &"pray":
			bowed5[0] = minf(bowed5[0], gideon._head.rotation.x)
		return seen5.has(&"pray") and gideon_said.any(func(l): return l[1] == &"murmur" and gideon._rota.PRAY_LINES.has(l[0])) and frame5[0] > 600, 5400)
	gideon._rota.stir()
	await _frames(2)
	var rose5 := StringName(gideon.activity())
	var at5: float = gideon.global_position.distance_to((map._stations["pray_0"] as Node3D).global_position)
	_check("G5 a man at prayer kneels at the pew, bows his head and murmurs; stirred, he gets up off his knees",
		seen5.has(&"kneel_down") and seen5.has(&"pray") and bowed5[0] < -0.3 and gideon_said.any(func(l): return l[1] == &"murmur" and gideon._rota.PRAY_LINES.has(l[0])) and rose5 == &"kneel_up" and at5 < 1.0,
		"showed %s, head %.2f, said %s, stirred: %s, %.1f m from the pew" % [seen5.keys(), bowed5[0], gideon_said, rose5, at5])

	# G8 the divided hunt's ground: men sent to search a hunt area look only
	# in it, whatever word comes from outside it, and keep at it
	var areas8 := {}

	for node in get_tree().get_nodes_in_group(&"hunt_area"):
		areas8[String(node.name)] = node.get_meta(&"box")

	var sent8 := {"Col": "area_barracks", "Osric": "area_barracks", "Ned": "area_west", "Piers": "area_west"}
	var spots8 := {}
	var stray8 := []

	for name in sent8:
		var man: Node3D = map.cast[name]
		# Word of him in the courtyard, then the orders: each his ground.
		man.last_known_position = Vector3(0, 0, 10)
		man.has_last_known = true
		man.send_to_search(areas8[sent8[name]], StringName(sent8[name]))
		spots8[name] = []

	await _until(func():
		for name in sent8:
			var man: Node3D = map.cast[name]
			var spot: Dictionary = man._spot
			if not spot.is_empty() and not (spots8[name] as Array).has(spot["stand"]):
				(spots8[name] as Array).append(spot["stand"])
				if not (areas8[sent8[name]] as AABB).grow(0.3).has_point(spot["stand"]):
					stray8.append("%s at %s" % [name, (spot["stand"] as Vector3).snapped(Vector3.ONE * 0.1)])
		return false, 2400)
	# A call from outside his ground (another group's find) he leaves to
	# them; one from inside it he answers.
	var col8: Node3D = map.cast["Col"]
	col8.hear_call(Vector3(0, 0, 10))
	# (And word called out through Comms: "He's there!", the bell.)
	col8._hear_message({"message": {"what": &"spotted", "where": Vector3(0, 0, 10), "time": 9999.0}, "position": col8.global_position, "range": 200.0})
	col8._hear_message({"message": {"what": &"alarm", "where": Vector3(0, 0, 10)}, "position": col8.global_position, "range": 200.0})
	var ignored8: bool = (areas8["area_barracks"] as AABB).grow(0.3).has_point(col8.last_known_position)
	col8.hear_call(Vector3(22, 0, 4))
	var answered8: bool = col8.last_known_position.distance_to(Vector3(22, 0, 4)) < 0.1
	var kept8: bool = ignored8 and answered8 and sent8.keys().all(func(n): return int((map.cast[n] as Node).state) == 3 and (map.cast[n] as Node).get_meta(&"hunt_group", &"") == StringName(sent8[n]))
	# Called off: his ground is anywhere again.
	var called8: Node3D = map.cast["Piers"]
	called8.call_off_search()
	var free8: bool = not called8.has_meta(&"hunt_area") and not called8.has_meta(&"hunt_group")
	var counts8 := {}

	for name in sent8:
		counts8[name] = (spots8[name] as Array).size()

	_check("G8 men sent to a hunt area search only inside it and keep at it; called off, anywhere again",
		stray8.is_empty() and kept8 and free8 and counts8.values().all(func(c): return int(c) >= 3),
		"outside their ground %s, a call from outside ignored %s, from inside answered %s, still searching in their groups %s, called off %s, places searched %s" % [stray8.slice(0, 6), ignored8, answered8, kept8, free8, counts8])

	# G9 sent to the bell: a man who is no lookout runs to it and rings it
	var rung9 := [null]
	for bell in get_tree().get_nodes_in_group(&"alarm_bells"):
		bell.rung.connect(func(by): rung9[0] = by)
	var tam9: Node3D = map.cast["Tam"]
	tam9.last_known_position = Vector3(-17.6, 0, -1.5)
	tam9.has_last_known = true
	tam9.send_to_bell()
	await _until(func(): return rung9[0] != null, 3600)
	_check("G9 a man sent to the bell runs to it and rings it", rung9[0] == tam9,
		"rung by %s, Tam at %s" % [rung9[0].name if rung9[0] != null else "nobody", tam9.global_position.snapped(Vector3.ONE * 0.1)])
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


func _until(cond: Callable, max_frames: int) -> void:
	for i in max_frames:
		if cond.call():
			return

		await get_tree().physics_frame


func _check(test_name: String, ok: bool, detail: String) -> void:
	results.append("%s  %s   [%s]" % ["PASS" if ok else "FAIL", test_name, detail])
