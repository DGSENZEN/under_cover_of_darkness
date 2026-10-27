extends Node
## The Load and Save pages (SavePage) and the pause menu's Save and Load (the
## save and load spec, section 5): runs listed with the last played open,
## saves newest first, loading one, deleting after asking, the Save page's
## new save and overwriting after asking, a damaged save shown but not
## loadable (P1-P4, P7), the pause menu's six words and Escape (P5), a load
## from the pause leaving the game unpaused (P6).
##   Godot --headless --fixed-fps 60 --path . res://tests/save_pages_test.tscn

const SaveFiles := preload("res://scripts/Save/SaveFiles.gd")
const SaveWords := preload("res://scripts/Save/SaveWords.gd")
const ROOT := "user://test_saves/save_pages"

var results: Array[String] = []
var run_a := ""
var run_b := ""
@onready var save: Node = get_node("/root/SaveGame")
@onready var city: Node = get_node("/root/CityState")


func _ready() -> void:
	SaveFiles.use_root(ROOT)
	_wipe(ProjectSettings.globalize_path(ROOT))
	_saves()
	await _p1_lists()
	await _p2_load_chosen()
	await _p3_delete_asks()
	await _p4_save_page()
	await _p7_damaged()
	await _p5_pause_words()
	await _p6_load_from_the_pause()
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


func _write(run: String, slot: String, kind: StringName, date: int) -> void:
	SaveFiles.write(run, slot, {"version": 1, "run": run, "slot": slot, "kind": kind, "name": "", "map": "res://maps/metro.tscn", "place": "The Metro",
		"archetype": &"derive", "date": date, "played": 60.0}, {"version": 1}, null)


## Two runs: A older, B played last (three saves).
func _saves() -> void:
	run_a = SaveFiles.new_run(&"derive")
	_write(run_a, "named_1", &"named", 100)
	run_b = SaveFiles.new_run(&"thaumaturge")
	_write(run_b, "auto_1", &"auto", 200)
	_write(run_b, "quick_1", &"quick", 300)
	_write(run_b, "named_1", &"named", 250)
	SaveFiles.set_last_run(run_b)
	city.run_id = run_b


func _page(mode: StringName) -> SavePage:
	var page := SavePage.new()
	add_child(page)
	page.open(mode, city.run_id)
	await get_tree().process_frame
	return page


func _drop(page: Node) -> void:
	remove_child(page)
	page.free()


func _p1_lists() -> void:
	var page := await _page(&"load")
	var runs := page.rows.filter(func(r): return r.get_meta(&"what") == &"run").map(func(r): return r.get_meta(&"run"))
	var saves := page.rows.filter(func(r): return r.get_meta(&"what") == &"save").map(func(r): return r.get_meta(&"slot"))
	_check("P1 runs listed, the last played first and open, its saves newest first", runs == [run_b, run_a] and page.open_run == run_b
		and saves == ["quick_1", "named_1", "auto_1"], "%s %s" % [runs, saves])
	_drop(page)


func _p2_load_chosen() -> void:
	var page := await _page(&"load")
	var chosen := []
	page.load_chosen.connect(func(run, slot): chosen.append([run, slot]))
	page.row_for(run_b, "named_1").pressed.emit()
	# Opening the other run shows its saves; choosing one loads it.
	page.row_for(run_a).pressed.emit()
	await get_tree().process_frame
	page.row_for(run_a, "named_1").pressed.emit()
	_check("P2 choosing a save loads it", chosen == [[run_b, "named_1"], [run_a, "named_1"]] and page.open_run == run_a, str(chosen))
	_drop(page)


func _p3_delete_asks() -> void:
	var page := await _page(&"load")
	page.ask_delete(page.row_for(run_b, "auto_1"))
	var asked: String = page.question.text
	page.answer(false)
	var kept := FileAccess.file_exists(SaveFiles.root().path_join(run_b).path_join("auto_1.save"))
	page.ask_delete(page.row_for(run_b, "auto_1"))
	page.answer(true)
	await get_tree().process_frame
	var gone := not FileAccess.file_exists(SaveFiles.root().path_join(run_b).path_join("auto_1.save")) and page.row_for(run_b, "auto_1") == null
	page.ask_delete(page.row_for(run_a))
	var asked_run: String = page.question.text
	page.answer(true)
	await get_tree().process_frame
	var run_gone := not SaveFiles.runs().any(func(r): return r["id"] == run_a)
	_check("P3 deleting asks first; No keeps, Yes deletes (a save or a whole run)", asked == SaveWords.DELETE_SAVE and kept and gone and asked_run == SaveWords.DELETE_RUN
		and run_gone, "%s %s %s %s" % [asked, kept, gone, run_gone])
	_drop(page)


func _p4_save_page() -> void:
	var page := await _page(&"save")
	var chosen := []
	page.save_chosen.connect(func(slot): chosen.append(slot))
	var first: Button = page.rows[0]
	var named := page.rows.filter(func(r): return r.get_meta(&"what") == &"save").map(func(r): return r.get_meta(&"slot"))
	first.pressed.emit()
	page.row_for(run_b, "named_1").pressed.emit()
	var asked: String = page.question.text
	var before_yes := chosen.duplicate()
	page.answer(true)
	_check("P4 the Save page: a new save first, then this run's named saves, overwriting after asking", first.get_meta(&"what") == &"new" and named == ["named_1"]
		and before_yes == [""] and asked == SaveWords.OVERWRITE and chosen == ["", "named_1"], "%s %s %s" % [named, chosen, asked])
	_drop(page)


func _p7_damaged() -> void:
	var path := SaveFiles.root().path_join(run_b).path_join("named_1.save")
	var bytes := FileAccess.get_file_as_bytes(path)
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_buffer(bytes.slice(0, 10))
	file.close()
	var page := await _page(&"load")
	var row := page.row_for(run_b, "named_1")
	var chosen := []
	page.load_chosen.connect(func(run, slot): chosen.append(slot))
	row.pressed.emit()
	_check("P7 a damaged save is listed but cannot be loaded", row != null and row.disabled and row.text.contains(SaveWords.UNREADABLE) and chosen.is_empty(),
		"%s '%s'" % [row.disabled if row else null, row.text if row else ""])
	_drop(page)


func _p5_pause_words() -> void:
	var pause := PauseMenu.new()
	add_child(pause)
	pause.set_open(true)
	await get_tree().process_frame
	var order: Array = pause.words.duplicate()
	order.sort_custom(func(a, b): return a.position.y < b.position.y)
	var shown: Array = order.map(func(w): return w.text)
	pause.open_saves(&"load")
	var opened: bool = pause.saves_open and pause.saves.visible
	pause.back()
	var folded: bool = not pause.saves_open and pause.visible
	var resumed := [false]
	pause.resume_requested.connect(func(): resumed[0] = true)
	pause.back()
	_check("P5 the pause menu reads Resume, Save, Load, Settings, Main menu, Quit; Escape folds the page, then resumes",
		shown == ["Resume", "Save", "Load", "Settings", "Main menu", "Quit"] and opened and folded and resumed[0], "%s %s %s %s" % [shown, opened, folded, resumed[0]])
	remove_child(pause)
	pause.free()


func _p6_load_from_the_pause() -> void:
	# The game in the Metro, a save made, the game paused, Load chosen.
	var stand_in := Node.new()
	get_tree().root.add_child(stand_in)
	get_tree().current_scene = stand_in
	var run: String = save.begin_run(&"derive")
	var cover: CanvasLayer = load("res://scripts/UI/ArtLoadingScreen.gd").open(get_tree())
	await cover.change_to("res://maps/metro.tscn")
	for i in 30:
		await get_tree().process_frame
	save.request_save(&"named")
	for i in 120:
		if SaveFiles.saves(run).any(func(s): return s["kind"] == &"named"):
			break
		await get_tree().process_frame
	get_tree().paused = true
	var error: Error = await save.load_slot(run, "named_1")
	for i in 5:
		await get_tree().process_frame
	var hud: Node = get_tree().get_first_node_in_group(&"player").hud
	_check("P6 a load from the pause leaves the game playing", error == OK and not get_tree().paused and not save.loading and not hud._pause.visible,
		"%s paused %s pause %s" % [error, get_tree().paused, hud._pause.visible])


func _check(test_name: String, ok: bool, detail: String) -> void:
	results.append("%s  %s   [%s]" % ["PASS" if ok else "FAIL", test_name, detail])
