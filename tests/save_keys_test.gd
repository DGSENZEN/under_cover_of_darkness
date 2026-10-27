extends Node
## Quicksave, quickload and the autosave on arriving, in the real Metro (the
## save and load spec, sections 2 and 4; K1-K8); a first save in a game begun
## without New Game keeps what the city remembers (K9); quickload does
## nothing under a cover that is not a load (K10). It changes the scene, so it
## hands the scene a stand-in first and stays under the root itself.
##   Godot --headless --fixed-fps 60 --path . res://tests/save_keys_test.tscn

const SaveFiles := preload("res://scripts/Save/SaveFiles.gd")
const SaveWords := preload("res://scripts/Save/SaveWords.gd")
const ArtLoading := preload("res://scripts/UI/ArtLoadingScreen.gd")
const OpenTalk := preload("res://tests/fixtures/save/OpenTalk.gd")
const METRO := "res://maps/metro.tscn"

var results: Array[String] = []
var covers := 0
@onready var save: Node = get_node("/root/SaveGame")
@onready var city: Node = get_node("/root/CityState")


func _ready() -> void:
	SaveFiles.use_root("user://test_saves")
	_wipe(ProjectSettings.globalize_path("user://test_saves"))
	# Stay when the scene changes: the scene is a stand-in.
	var stand_in := Node.new()
	get_tree().root.add_child.call_deferred(stand_in)
	await get_tree().process_frame
	get_tree().current_scene = stand_in
	get_tree().root.child_entered_tree.connect(func(node): if String(node.name).begins_with("ArtLoading"): covers += 1)
	var run: String = save.begin_run(&"derive")
	await _k3_autosave_on_arrival(run)
	await _k1_quicksave(run)
	await _k2_held_while_talking(run)
	await _k8_quick_and_off_the_main_thread(run)
	await _k6_failure(run)
	await _k4_quickload(run)
	await _k5_one_load(run)
	await _k7_after_a_load(run)
	await _k9_first_save_with_no_run()
	await _k10_no_load_under_another_cover()
	print("\n==== RESULTS ====")

	for line in results:
		print(line)

	var failed := results.filter(func(r): return r.begins_with("FAIL")).size()
	print("\n%d pass, %d fail" % [results.size() - failed, failed])
	get_tree().quit()


func _wipe(path: String) -> void:
	var dir := DirAccess.open(path)

	if dir == null:
		return

	for sub in dir.get_directories():
		_wipe(path.path_join(sub))

	for file in dir.get_files():
		dir.remove(file)

	DirAccess.remove_absolute(path)


func _player() -> Node:
	return get_tree().get_first_node_in_group(&"player")


func _press(action: StringName) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	Input.parse_input_event(event)


## Frames until `done` holds, at most `frames`; whether it did.
func _until(done: Callable, frames := 600) -> bool:
	for i in frames:
		if done.call():
			return true

		await get_tree().process_frame

	return done.call()


func _kinds(run: String, kind: StringName) -> Array:
	return SaveFiles.saves(run).filter(func(s): return s.get("kind") == kind)


func _k3_autosave_on_arrival(run: String) -> void:
	var cover: CanvasLayer = ArtLoading.open(get_tree())
	await cover.change_to(METRO)
	var wrote: bool = await _until(func(): return _kinds(run, &"auto").size() == 1)
	_check("K3 arriving in the Metro autosaves", wrote, str(SaveFiles.saves(run).map(func(s): return s["slot"])))


func _k1_quicksave(run: String) -> void:
	_press(&"quick_save")
	var hud: Node = _player().hud
	var wrote: bool = await _until(func(): return _kinds(run, &"quick").size() == 1 and hud._caption.text == SaveWords.SAVED)
	var picture: String = _kinds(run, &"quick")[0]["picture"] if wrote else ""
	# (Headless there is nothing drawn to take a picture of.)
	var pictured := picture != "" or DisplayServer.get_name() == "headless"
	_check("K1 quicksave writes quick_1 and says so", wrote and pictured and hud._caption.text == SaveWords.SAVED, "%s '%s'" % [wrote, hud._caption.text])


func _k2_held_while_talking(run: String) -> void:
	var talk: Node = OpenTalk.new()
	add_child(talk)
	_player().frob._talk = talk
	_press(&"quick_save")
	var early: bool = await _until(func(): return _kinds(run, &"quick").size() == 2, 30)
	var said: String = _player().hud._caption.text
	talk.open = false
	var after: bool = await _until(func(): return _kinds(run, &"quick").size() == 2)
	await _until(func(): return false, 30)
	_player().frob._talk = null
	talk.queue_free()
	_check("K2 a quicksave while talking waits for the talk to end", not early and said == SaveWords.HELD and after and _kinds(run, &"quick").size() == 2,
		"early %s said '%s' after %s" % [early, said, after])


func _k8_quick_and_off_the_main_thread(run: String) -> void:
	var started := Time.get_ticks_usec()
	save.gather()
	var took := (Time.get_ticks_usec() - started) / 1000.0
	SaveFiles.wrote_on_main = true
	save.request_save(&"named")
	var wrote: bool = await _until(func(): return _kinds(run, &"named").size() == 1)
	print("gather in the Metro: %.2f ms" % took)
	_check("K8 gathering is quick and the write is off the main thread", took < 16.0 and wrote and not SaveFiles.wrote_on_main, "%.2f ms" % took)


func _k6_failure(run: String) -> void:
	var slot := SaveFiles.next_slot(run, &"quick")
	var folder := SaveFiles.root().path_join(run)
	var other := "quick_1" if slot != "quick_1" else "quick_2"
	var before := FileAccess.get_file_as_bytes(folder.path_join(other + ".save"))
	DirAccess.make_dir_recursive_absolute(folder.path_join(slot + ".tmp"))
	var outcome := [null]
	var wrote_slot := [""]
	# (Only this save's outcome: an earlier one may still be finishing.)
	var heard := func(_r, written, error):
		if written == slot:
			outcome[0] = error
			wrote_slot[0] = written
	save.saved.connect(heard)
	_press(&"quick_save")
	await _until(func(): return outcome[0] != null)
	DirAccess.remove_absolute(folder.path_join(slot + ".tmp"))
	save.saved.disconnect(heard)
	_check("K6 a save that cannot be written says so and harms nothing", outcome[0] != null and outcome[0] != OK and _player().hud._caption.text == SaveWords.FAILED
		and FileAccess.get_file_as_bytes(folder.path_join(other + ".save")) == before, "%s '%s' blocked %s wrote %s" % [outcome[0], _player().hud._caption.text, slot, wrote_slot[0]])


func _k4_quickload(run: String) -> void:
	var newest_quick: Dictionary = _kinds(run, &"quick")[0]
	var saved_at: Vector3 = (SaveFiles.read(newest_quick["path"])["body"]["player"]["place"]["transform"] as Transform3D).origin
	_player().teleport(Transform3D(Basis(), saved_at + Vector3(4, 0, 4)))
	_press(&"quick_load")
	var loaded: bool = await _until(func(): return not save.loading and _player() != null and _player().global_position.distance_to(saved_at) < 0.05, 900)
	_check("K4 quickload puts things back as the quicksave had them", loaded, "%s / %s" % [_player().global_position if _player() else null, saved_at])


func _k5_one_load(run: String) -> void:
	await _until(func(): return get_tree().root.get_node_or_null("ArtLoading") == null)
	covers = 0
	_press(&"quick_load")
	_press(&"quick_load")
	await _until(func(): return save.loading, 30)
	_press(&"quick_load")
	await _until(func(): return not save.loading, 900)
	_check("K5 quickload pressed again and again loads once", covers == 1, "%d covers" % covers)


func _k7_after_a_load(run: String) -> void:
	await _until(func(): return get_tree().root.get_node_or_null("ArtLoading") == null)
	var autos := _kinds(run, &"auto").size()
	await _until(func(): return false, 120)
	var no_autosave := _kinds(run, &"auto").size() == autos
	save.loading = true
	var named := _kinds(run, &"named").size()
	save.request_save(&"named")
	var early: bool = await _until(func(): return _kinds(run, &"named").size() > named, 30)
	save.loading = false
	var later: bool = await _until(func(): return _kinds(run, &"named").size() > named)
	_check("K7 no autosave after a load; a save asked for mid-load waits for it", no_autosave and not early and later,
		"autosaves %d->%d early %s later %s" % [autos, _kinds(run, &"auto").size(), early, later])


func _k9_first_save_with_no_run() -> void:
	await _until(func(): return get_tree().root.get_node_or_null("ArtLoading") == null)
	# Played straight from the editor: no run, but the city remembers.
	city.run_id = ""
	city.people.set_flag("curandera", "asked_book")
	var runs_before := SaveFiles.runs().size()
	_press(&"quick_save")
	var wrote: bool = await _until(func(): return city.run_id != "" and _kinds(city.run_id, &"quick").size() == 1)
	var body: Dictionary = SaveFiles.read(_kinds(city.run_id, &"quick")[0]["path"])["body"] if wrote else {}
	_check("K9 a first save with no run makes one run and forgets nothing", wrote and SaveFiles.runs().size() == runs_before + 1
		and city.people.said.get("curandera", []).has("asked_book") and body.get("city", {}).get("run") == city.run_id,
		"wrote %s runs %d->%d remembers %s saved run '%s'" % [wrote, runs_before, SaveFiles.runs().size(), city.people.said.get("curandera", []),
		body.get("city", {}).get("run", "")])


func _k10_no_load_under_another_cover() -> void:
	await _until(func(): return get_tree().root.get_node_or_null("ArtLoading") == null)
	covers = 0
	# Out to the main menu (the pause's Main menu), F9 pressed on the way.
	var cover: CanvasLayer = ArtLoading.open(get_tree())
	cover.change_to("res://main_menu.tscn")
	await get_tree().process_frame
	save.quickload()
	var at_menu := func() -> bool:
		var scene := get_tree().current_scene
		return scene != null and scene.scene_file_path == "res://main_menu.tscn" and get_tree().root.get_node_or_null("ArtLoading") == null
	await _until(at_menu, 900)
	await _until(func(): return false, 60)
	_check("K10 quickload does nothing under the cover to the menu", covers == 1 and not save.loading and save.pending.is_empty()
		and get_tree().current_scene.scene_file_path == "res://main_menu.tscn", "%d covers, at %s" % [covers, get_tree().current_scene.scene_file_path])


func _check(test_name: String, ok: bool, detail: String) -> void:
	results.append("%s  %s   [%s]" % ["PASS" if ok else "FAIL", test_name, detail])
