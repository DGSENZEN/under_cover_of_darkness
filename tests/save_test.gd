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
