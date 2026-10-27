extends Node
## The main menu and the saves (the save and load spec, section 1): New Game
## begins a run as the archetype chosen (M1); Continue loads the newest save
## of the run played last (M2), or says there is none, and a double press
## loads once (M3).
##   Godot --headless --fixed-fps 60 --path . res://tests/save_menu_test.tscn

const SaveFiles := preload("res://scripts/Save/SaveFiles.gd")
const SaveWords := preload("res://scripts/Save/SaveWords.gd")
const ROOT := "user://test_saves/save_menu"

var results: Array[String] = []
@onready var city: Node = get_node("/root/CityState")


func _ready() -> void:
	SaveFiles.use_root(ROOT)
	_wipe(ProjectSettings.globalize_path(ROOT))
	await _m3_no_save()
	await _m1_new_game_begins_a_run()
	await _m2_continue_loads()
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


func _menu() -> Node:
	var menu: Node = load("res://main_menu.tscn").instantiate()
	menu.music_score = "res://tests/fixtures/menu_score/score.json"
	add_child(menu)
	await get_tree().process_frame
	await get_tree().process_frame
	return menu


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _m3_no_save() -> void:
	var menu := await _menu()
	var asked := [0]
	menu.continue_game = func(_target): asked[0] += 1; return OK
	menu.words[1].pressed.emit()
	await _wait(MenuMotion.PRESS + 0.3)
	_check("M3 Continue with no save says so", asked[0] == 0 and menu.page_open == 1 and menu.pages.body_label.text == SaveWords.NO_SAVE,
		"asked %d page %d '%s'" % [asked[0], menu.page_open, menu.pages.body_label.text])
	menu.queue_free()
	await get_tree().process_frame


func _m1_new_game_begins_a_run() -> void:
	var menu := await _menu()
	# The game will not open (a fixture that is not there): the run is begun all the same.
	menu.game_scene = "res://tests/fixtures/no_such_game.tscn"
	menu.words[0].pressed.emit()
	await _wait(MenuMotion.PRESS + 0.8)
	menu.archetypes.select(2)
	menu.archetypes.confirm()
	await _wait(ArchetypeScreen.SURGE_HOLD + ArchetypeTransition.TIME + 0.6)
	var runs := SaveFiles.runs()
	_check("M1 New Game begins a run as the archetype chosen", runs.size() == 1 and runs[0]["archetype"] == &"factotum" and city.run_id == runs[0]["id"]
		and city.archetype == &"factotum", "%s %s" % [runs, city.run_id])
	menu.queue_free()
	await get_tree().process_frame


func _m2_continue_loads() -> void:
	var run: String = SaveFiles.runs()[0]["id"]
	SaveFiles.write(run, "quick_1", {"version": 1, "run": run, "slot": "quick_1", "kind": &"quick", "map": "res://maps/metro.tscn", "date": 50},
		{"version": 1}, null)
	SaveFiles.write(run, "named_1", {"version": 1, "run": run, "slot": "named_1", "kind": &"named", "map": "res://maps/metro.tscn", "date": 90},
		{"version": 1}, null)
	var menu := await _menu()
	var asked: Array = []
	menu.continue_game = func(target): asked.append([target["run"], target["slot"]]); return OK
	menu.words[1].pressed.emit()
	menu.words[1].pressed.emit()
	await _wait(MenuMotion.PRESS + 0.3)
	menu.words[1].pressed.emit()
	await _wait(MenuMotion.PRESS + 0.3)
	_check("M2 Continue loads the newest save of the last run, once", asked == [[run, "named_1"]], str(asked))
	menu.queue_free()
	await get_tree().process_frame


func _check(test_name: String, ok: bool, detail: String) -> void:
	results.append("%s  %s   [%s]" % ["PASS" if ok else "FAIL", test_name, detail])
