extends Node3D
## Saving and loading the game (the save and load spec, sections 3-6): the
## save manager gathering and applying (G1-G7), the per-map store (G17).
##   Godot --headless --fixed-fps 60 --path . res://tests/save_test.tscn

const SaveFiles := preload("res://scripts/Save/SaveFiles.gd")
const FIXTURE := preload("res://tests/fixtures/save/fixture_map.tscn")
const FIXTURE_B := preload("res://tests/fixtures/save/fixture_map_b.tscn")
const PLAYER := preload("res://Player.tscn")
const Props := preload("res://scripts/Interaction/Props.gd")
const TorchScript := preload("res://scripts/Visual/Torch.gd")
const Ticker := preload("res://tests/fixtures/save/Ticker.gd")

var results: Array[String] = []
@onready var save: Node = get_node("/root/SaveGame")
@onready var city: Node = get_node("/root/CityState")


func _ready() -> void:
	SaveFiles.use_root("user://test_saves")
	await _g1_round_trip()
	await _g2_gone()
	await _g3_duplicates()
	_g4_city()
	await _g5_can_save()
	await _g6_missing()
	await _g17_maps()
	await _g8_player()
	await _g9_world_things()
	await _g11_camera_settles()
	await _g12_taken_stays_gone()
	_g18_fields()
	await _g13_metro_round_trip()
	await _g14_schedules_carry_on()
	await _g15_shade()
	await _g16_zocalo_round_trip()
	# (G10, the gates still carrying what he has, is city_test's, run beside this.)
	# Last: it changes the scene (this suite stays, under the root).
	await _g7_through_the_cover()
	print("\n==== RESULTS ====")

	for line in results:
		print(line)

	var failed := results.filter(func(r): return r.begins_with("FAIL")).size()
	print("\n%d pass, %d fail" % [results.size() - failed, failed])
	get_tree().quit()


## A fresh fixture map as this suite's child, named `Fixture`.
func _fixture(packed: PackedScene = FIXTURE) -> Node3D:
	var map := packed.instantiate() as Node3D
	map.name = "Fixture"
	# (Each check its own map: nothing an earlier one freed is gone here.)
	save.gone.clear()
	add_child(map)
	return map


func _drop(node: Node) -> void:
	remove_child(node)
	node.free()


func _g1_round_trip() -> void:
	var map := _fixture()
	map.get_node("StubA").value = 7
	map.get_node("StubA").position = Vector3(1, 2, 3)
	map.get_node("Room/StubB").value = -4
	var body: Dictionary = save.gather()
	_drop(map)
	var fresh := _fixture()
	var problems: Array = save.apply(body)
	var a := fresh.get_node("StubA")
	var b := fresh.get_node("Room/StubB")
	_check("G1 round trip", problems.is_empty() and a.value == 7 and a.position == Vector3(1, 2, 3) and b.value == -4
		and body["saveables"].has("Fixture/StubA"), "%s %s" % [problems, body.get("saveables", {}).keys()])
	_drop(fresh)


func _g2_gone() -> void:
	var map := _fixture()
	map.get_node("StubGone").queue_free()
	await get_tree().process_frame
	var body: Dictionary = save.gather()
	_drop(map)
	var fresh := _fixture()
	save.apply(body)
	await get_tree().process_frame
	_check("G2 gone stays gone", body["gone"].has("Fixture/StubGone") and fresh.get_node_or_null("StubGone") == null, str(body["gone"]))
	_drop(fresh)


func _g3_duplicates() -> void:
	var map := _fixture()
	map.get_node("StubA").fixed_id = "same"
	map.get_node("Room/StubB").fixed_id = "same"
	var clashes: Array = save.duplicate_ids()
	var body: Dictionary = save.gather()
	_check("G3 duplicate ids refused", clashes.size() == 1 and String(clashes[0]).contains("StubA") and String(clashes[0]).contains("StubB") and body.is_empty(),
		str(clashes))
	_drop(map)


func _g4_city() -> void:
	city.run_id = "run_test"
	city.played = 42.0
	city.archetype = &"factotum"
	city.job.done.append("a_goal")
	city.people.set_flag("curandera", "asked_book")
	city.people.add_mood("librarian", -1)
	var state: Dictionary = city.save_state()
	city.run_id = ""
	city.played = 0.0
	city.archetype = &""
	city.job.reset()
	city.people.load_state({})
	city.load_state(state)
	var back: bool = city.run_id == "run_test" and city.played == 42.0 and city.archetype == &"factotum" and city.job.done.has("a_goal") \
		and city.people.said.get("curandera", []).has("asked_book") and city.people.mood_of("librarian") == -1 and city.job.people == city.people
	city.begin()
	var kept: bool = city.run_id == "run_test" and city.people.said.get("curandera", []).has("asked_book") and not city.job.done.has("a_goal")
	_check("G4 city state", back and kept, "back %s kept %s" % [back, kept])


func _g5_can_save() -> void:
	var player := PLAYER.instantiate()
	add_child(player)
	await get_tree().physics_frame
	var free_to: bool = save.can_save()
	save.hold(&"scene")
	var held: bool = not save.can_save()
	save.release(&"scene")
	save.loading = true
	var while_loading: bool = not save.can_save()
	save.loading = false
	player.is_dead = true
	var dead: bool = not save.can_save()
	player.is_dead = false
	var again: bool = save.can_save()
	_drop(player)
	var no_player: bool = not save.can_save()
	_check("G5 can save", free_to and held and while_loading and dead and again and no_player,
		"%s %s %s %s %s %s" % [free_to, held, while_loading, dead, again, no_player])


func _g6_missing() -> void:
	var map := _fixture()
	var body: Dictionary = save.gather()
	body["saveables"]["Fixture/NotHere"] = {"value": 1}
	body["saveables"]["Fixture/StubA"] = {"value": 99, "pos": Vector3.ZERO}
	var problems: Array = save.apply(body)
	_check("G6 missing id", problems.size() == 1 and String(problems[0]).contains("NotHere") and map.get_node("StubA").value == 99, str(problems))
	_drop(map)


func _g17_maps() -> void:
	city.maps.clear()
	var a := _fixture()
	a.get_node("StubA").value = 5
	save.leave_map(a)
	_drop(a)
	var b := _fixture(FIXTURE_B)
	var state: Dictionary = city.save_state()
	city.maps.clear()
	city.load_state(state)
	_drop(b)
	var fresh := _fixture()
	save.enter_map(fresh)
	_check("G17 maps you left", fresh.get_node("StubA").value == 5 and city.maps.has(FIXTURE.resource_path), str(city.maps.keys()))
	_drop(fresh)
	city.maps.clear()


## A map of the things that saved themselves before saving to disk: a door,
## a locked chest, a key and a torch, named as a level's markers name them.
func _things_map() -> Node3D:
	save.gone.clear()
	var map := Node3D.new()
	map.name = "Things"
	add_child(map)
	var door := Props.door(map, Vector3(0, 0, -4))
	door.name = "door_cellar"
	var chest := Props.chest(map, Vector3(3, 0, -4), 0.0, Vector3(0.9, 0.55, 0.55), true, &"strong", "strongbox")
	chest.name = "chest_strong"
	var key := Props.key(map, Vector3(5, 0.6, -1), &"cellar", "cellar key")
	key.name = "key_cellar"
	var torch: Node3D = TorchScript.new()
	torch.name = "torch_gate"
	torch.position = Vector3(-3, 2, 0)
	map.add_child(torch)
	return map


func _g8_player() -> void:
	save.gone.clear()
	var player := PLAYER.instantiate()
	add_child(player)
	await get_tree().physics_frame
	await get_tree().physics_frame
	player.teleport(Transform3D(Basis(Vector3.UP, 1.1), Vector3(2, 3.5, -1)))
	player.neck.rotation.x = deg_to_rad(-30.0)
	player.velocity = Vector3(0, -2, 1)
	player.revolver.loaded = {&"cylinder": 3, &"shot": 0}
	player.revolver.barrel = &"shot"
	player.caster.select(&"ward")
	player.power.power = 40.0
	var body: Dictionary = save.gather()
	_drop(player)
	var fresh := PLAYER.instantiate()
	add_child(fresh)
	await get_tree().physics_frame
	save.apply(body)
	var ok: bool = fresh.global_position.distance_to(Vector3(2, 3.5, -1)) < 0.001 and absf(fresh.neck.rotation.x - deg_to_rad(-30.0)) < 0.001 \
		and absf(fresh.rotation.y - 1.1) < 0.001 and fresh.velocity.is_equal_approx(Vector3(0, -2, 1)) and fresh.revolver.loaded == {&"cylinder": 3, &"shot": 0} \
		and fresh.revolver.barrel == &"shot" and fresh.caster.selected == &"ward" and is_equal_approx(fresh.power.power, 40.0)
	_check("G8 the player", ok, "at %s look %.3f yaw %.3f v %s loaded %s barrel %s spell %s power %.1f" % [fresh.global_position, fresh.neck.rotation.x,
		fresh.rotation.y, fresh.velocity, fresh.revolver.loaded, fresh.revolver.barrel, fresh.caster.selected, fresh.power.power])
	_drop(fresh)


func _g9_world_things() -> void:
	var map := _things_map()
	await get_tree().physics_frame
	var door := map.get_node("door_cellar")
	door.load_state({"open": true, "locked": false, "angle": deg_to_rad(70.0)})
	var chest := map.get_node("chest_strong")
	chest.load_state({"open": false, "locked": false})
	map.get_node("torch_gate").load_state({"lit": false})
	await get_tree().physics_frame
	var body: Dictionary = save.gather()
	_drop(map)
	var fresh := _things_map()
	await get_tree().physics_frame
	save.apply(body)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var states := [fresh.get_node("door_cellar").save_state(), fresh.get_node("chest_strong").save_state(), fresh.get_node("torch_gate").save_state()]
	var ok: bool = states[0]["open"] == true and is_equal_approx(states[0]["angle"], deg_to_rad(70.0)) and states[1]["locked"] == false and states[2]["lit"] == false \
		and body["saveables"].has("Things/key_cellar")
	_check("G9 doors, chests, pickups, torches", ok, "%s %s" % [states, body["saveables"].keys()])
	_drop(fresh)


func _g11_camera_settles() -> void:
	save.gone.clear()
	var player := PLAYER.instantiate()
	add_child(player)
	await get_tree().physics_frame
	player.teleport(Transform3D(Basis(), Vector3(8, 1, 8)))
	var body: Dictionary = save.gather()
	_drop(player)
	var fresh := PLAYER.instantiate()
	add_child(fresh)
	await get_tree().physics_frame
	await get_tree().process_frame
	save.apply(body)
	# As under the cover: one tick of the world, then the first drawn frame.
	await get_tree().physics_frame
	await get_tree().process_frame
	await get_tree().process_frame
	var camera: Camera3D = fresh.camera
	var seen := Vector2(camera.global_position.x, camera.global_position.z)
	_check("G11 nothing slides into place", seen.distance_to(Vector2(8, 8)) < 0.05 and fresh.global_position.distance_to(Vector3(8, 1, 8)) < 0.05,
		"camera %s body %s" % [camera.global_position, fresh.global_position])
	_drop(fresh)


func _g12_taken_stays_gone() -> void:
	var map := _things_map()
	await get_tree().physics_frame
	var key := map.get_node("key_cellar")
	key.taken = true
	key.queue_free()
	await get_tree().process_frame
	var body: Dictionary = save.gather()
	_drop(map)
	var fresh := _things_map()
	await get_tree().physics_frame
	save.apply(body)
	await get_tree().process_frame
	_check("G12 taken stays gone", body["gone"].has("Things/key_cellar") and fresh.get_node_or_null("key_cellar") == null, str(body["gone"]))
	_drop(fresh)


func _g18_fields() -> void:
	var a: Node3D = Ticker.new()
	add_child(a)
	a.tick(9.5)
	var state: Dictionary = a.save_state()
	var b: Node3D = Ticker.new()
	add_child(b)
	b.load_state(state)
	var same: bool = b.clock == a.clock and b.next == a.next and b.seen == a.seen and b.seen is Array[int]
	var rolls_a := [a.roll(), a.roll(), a.roll()]
	var rolls_b := [b.roll(), b.roll(), b.roll()]
	_check("G18 a schedule's fields and dice", same and rolls_a == rolls_b and not a.seen.is_empty(), "%s %s %s" % [state, rolls_a, rolls_b])
	_drop(a)
	_drop(b)


## The differences between two gathered bodies: "path: a != b", floats
## within `tolerance`.
func _diff(a: Variant, b: Variant, path := "", tolerance := 1e-4) -> Array[String]:
	var found: Array[String] = []

	if a is Dictionary and b is Dictionary:
		for key in a:
			if not b.has(key):
				found.append("%s/%s: missing after" % [path, key])
			else:
				found.append_array(_diff(a[key], b[key], "%s/%s" % [path, key], tolerance))

		for key in b:
			if not a.has(key):
				found.append("%s/%s: new after" % [path, key])
	elif a is Array and b is Array:
		if a.size() != b.size():
			found.append("%s: %d items != %d" % [path, a.size(), b.size()])
		else:
			for i in a.size():
				found.append_array(_diff(a[i], b[i], "%s[%d]" % [path, i], tolerance))
	elif (a is float or a is int) and (b is float or b is int):
		if absf(float(a) - float(b)) > tolerance:
			found.append("%s: %s != %s" % [path, a, b])
	elif a is Vector3 and b is Vector3:
		if not (a as Vector3).is_equal_approx(b) and (a as Vector3).distance_to(b) > tolerance:
			found.append("%s: %s != %s" % [path, a, b])
	elif a is Transform3D and b is Transform3D:
		if (a as Transform3D).origin.distance_to((b as Transform3D).origin) > tolerance or not (a as Transform3D).basis.is_equal_approx((b as Transform3D).basis):
			found.append("%s: %s != %s" % [path, a, b])
	elif (a is Quaternion and b is Quaternion) or (a is Vector2 and b is Vector2) or (a is Color and b is Color) or (a is Basis and b is Basis) or (a is AABB and b is AABB):
		if not a.is_equal_approx(b):
			found.append("%s: %s != %s" % [path, a, b])
	elif a != b:
		found.append("%s: %s != %s" % [path, a, b])

	return found


## A map built as this suite's child, named `Map`, played `frames` frames.
func _map(path: String, frames: int) -> Node:
	save.gone.clear()
	var map: Node = (load(path) as PackedScene).instantiate()
	map.name = "Map"
	add_child(map)

	for i in frames:
		await get_tree().physics_frame

	return map


func _g13_metro_round_trip() -> void:
	var map: Node = await _map("res://maps/metro.tscn", 600)
	var before: Dictionary = save.gather()
	var file := SaveFiles.new_run(&"derive")
	SaveFiles.write(file, "named_1", {"version": 1, "run": file, "slot": "named_1", "kind": &"named", "date": 1}, before, null)
	var read: Dictionary = SaveFiles.read(SaveFiles.root().path_join(file).path_join("named_1.save"))
	_drop(map)
	var fresh: Node = await _map("res://maps/metro.tscn", 1)
	var problems: Array = save.apply(read["body"])
	var after: Dictionary = save.gather()
	var differences := _diff(before["saveables"], after["saveables"], "saveables")
	differences.append_array(_diff(before["player"], after["player"], "player", 1e-3))
	var misspelt: Array = load("res://scripts/Save/SaveFields.gd").missing
	_check("G13 the Metro comes back as it was", problems.is_empty() and differences.is_empty() and before["saveables"].size() > 10 and misspelt.is_empty(),
		"%d saved, problems %s, differences %s, no such fields %s" % [before["saveables"].size(), problems.slice(0, 5), differences.slice(0, 8), misspelt])
	_drop(fresh)


## The schedules' states after `frames` more frames of `map`.
func _schedules_after(map: Node, frames: int) -> Dictionary:
	for i in frames:
		await get_tree().physics_frame

	var lane := map.get_node("candle_lane")
	return {"train": lane.get_node("train").save_state(), "dark": lane.get_node("dark_train").save_state(),
		"procession": lane.get_node("procession").save_state(), "bay": lane.save_state()}


func _g14_schedules_carry_on() -> void:
	var map: Node = await _map("res://maps/metro.tscn", 600)
	# Played on past where a fresh build would be: a train due in 3 s, the
	# dark train's dice rolled on, the procession's next walk soon.
	var lane := map.get_node("candle_lane")
	lane.get_node("train").next = 3.0
	for i in 5:
		lane.get_node("dark_train")._rng.randf()
	lane.get_node("procession")._next = 2.0
	var body: Dictionary = save.gather()
	var went_on: Dictionary = await _schedules_after(map, 300)
	_drop(map)
	var fresh: Node = await _map("res://maps/metro.tscn", 1)
	save.apply(body)
	var goes_on: Dictionary = await _schedules_after(fresh, 300)
	var differences := _diff(went_on, goes_on, "", 1e-3)
	_check("G14 the trains and the procession carry on as if never saved", differences.is_empty(), str(differences.slice(0, 6)))
	_drop(fresh)


func _g15_shade() -> void:
	var map: Node = await _map("res://maps/metro.tscn", 30)
	var shade := map.get_node("candle_lane/shade_curandera")
	shade.set_resting(&"dim")
	shade.face(shade.global_position + Vector3(3, 0, 1))
	for i in 60:
		await get_tree().physics_frame
	var yaw: float = shade.man.rotation.y
	var body: Dictionary = save.gather()
	_drop(map)
	var fresh: Node = await _map("res://maps/metro.tscn", 1)
	save.apply(body)
	var back := fresh.get_node("candle_lane/shade_curandera")
	_check("G15 a dimmed shade comes back dim, facing the same way", back._resting == &"dim" and absf(back.man.rotation.y - yaw) < 0.001,
		"%s yaw %.3f / %.3f" % [back._resting, back.man.rotation.y, yaw])
	_drop(fresh)


func _g16_zocalo_round_trip() -> void:
	var map: Node = await _map("res://maps/zocalo.tscn", 300)
	# A flock up in the air, the night come.
	var pigeons := map.get_node("pigeons")
	pigeons._flocks[0]["flying"] = true
	pigeons._flocks[0]["quiet"] = 0.0
	map.set_day(false)
	for i in 30:
		await get_tree().physics_frame
	var before: Dictionary = save.gather()
	_drop(map)
	var fresh: Node = await _map("res://maps/zocalo.tscn", 1)
	var problems: Array = save.apply(before)
	var after: Dictionary = save.gather()
	var differences := _diff(before["saveables"], after["saveables"], "saveables")
	var up: bool = fresh.get_node("pigeons")._flocks[0]["flying"] == true and not fresh.sun.visible
	_check("G16 the Zócalo comes back as it was, a flock in the air at night", problems.is_empty() and differences.is_empty() and up,
		"%d saved, problems %s, differences %s, flying+night %s" % [before["saveables"].size(), problems.slice(0, 4), differences.slice(0, 6), up])
	_drop(fresh)


func _g7_through_the_cover() -> void:
	# The cover changes the current scene: hand it a stand-in, so this suite
	# stays under the root.
	var stand_in := Node.new()
	get_tree().root.add_child(stand_in)
	get_tree().current_scene = stand_in
	save.pending = {"header": {"run": "run_test", "slot": "quick_1"}, "body": {"version": 1, "map": FIXTURE.resource_path, "city": city.save_state(),
		"saveables": {"StubA": {"value": 3, "pos": Vector3(4, 5, 6)}}, "gone": [], "player": {}, "globals": {}}}
	save.loading = true
	var cover: CanvasLayer = load("res://scripts/UI/ArtLoadingScreen.gd").open(get_tree())
	var error: Error = await cover.change_to(FIXTURE.resource_path)
	var map := get_tree().current_scene
	await get_tree().physics_frame
	await get_tree().physics_frame
	var a := map.get_node_or_null("StubA")
	_check("G7 applied under the cover", error == OK and a != null and a.value == 3 and a.first_physics == Vector3(4, 5, 6) and save.pending.is_empty()
		and not save.loading, "%s %s" % [error, a.first_physics if a else null])


func _check(test_name: String, ok: bool, detail: String) -> void:
	results.append("%s  %s   [%s]" % ["PASS" if ok else "FAIL", test_name, detail])
