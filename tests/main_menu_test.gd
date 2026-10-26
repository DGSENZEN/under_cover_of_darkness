extends Node
## Menu navigation must remain usable without a save or an unfinished score.
const Settings := preload("res://scripts/UI/Settings.gd")
var failures := 0

func check(ok: bool, message: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + message)
	if not ok:
		failures += 1

func key(code: Key) -> void:
	for down in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = down
		get_viewport().push_input(event, true)
		await get_tree().process_frame

func _ready() -> void:
	var original_path := Settings.path
	var original_volume := AudioServer.get_bus_volume_db(0)
	Settings.path = "/private/tmp/main-menu-settings-test.cfg"
	DirAccess.remove_absolute(Settings.path)
	Settings.reload()
	if not ResourceLoader.exists("res://main_menu.tscn"):
		check(false, "game has a playable main menu")
		get_tree().quit(1)
		return
	var scene: PackedScene = load("res://main_menu.tscn")
	var menu := scene.instantiate()
	add_child(menu)
	await get_tree().process_frame
	check(menu.game_scene == "res://maps/metro.tscn", "New Game enters the actual Metro Underground scene")
	var title_lines: Array[String] = []
	for child in menu._design.get_children():
		if child is Label:
			title_lines.append(child.text)
	check(title_lines == ["UNDER COVER", "OF DARKNESS"], "main screen contains only the title and the menu")

	# Task 1: the word column and one selection path.
	check(menu.words.size() == 4 and menu.words.map(func(w): return w.text) == ["NEW GAME", "CONTINUE", "SETTINGS", "LORE"], "four words in reading order")
	check(menu.words[1].position.y - menu.words[0].position.y >= 56.0, "words have room between them")
	check(menu.words.all(func(w): return is_equal_approx(w.position.x, menu.words[0].position.x)), "words sit in one column")
	check(menu.selected == -1, "nothing is selected before input")
	check(not menu.band.showing, "no band before input")
	await key(KEY_DOWN)
	check(menu.selected == 0 and menu.words[0].has_focus(), "first key press selects New Game")
	await key(KEY_DOWN)
	check(menu.selected == 1, "down moves through the column")
	await key(KEY_UP)
	await key(KEY_UP)
	check(menu.selected == 0, "up stops at the top, no wrap")
	menu.words[3].mouse_entered.emit()
	await get_tree().process_frame
	check(menu.selected == 3 and menu.words.filter(func(w): return w.selected).size() == 1, "mouse after keyboard: one selection, the latest")
	check(not menu.has_method("music_marker"), "the old music marker hook is gone")

	# Task 2: the painted band.
	menu.select(2)
	await get_tree().create_timer(0.7).timeout
	var r: Rect2 = menu.band.band_rect()
	var wc: float = menu.words[2].position.y + menu.words[2].size.y * 0.5
	check(absf(r.get_center().y - wc) < 2.0 and is_equal_approx(r.size.y, 360.0), "band is centred on the selected word")
	check(absf(menu.band.position.y + menu.band.size.y * 0.5 - wc) < 2.0, "band has glided to the word")
	var mat: ShaderMaterial = menu.band.material
	check((mat.get_shader_parameter("glaze") as Color).is_equal_approx(Color("929fdb")) and is_equal_approx(mat.get_shader_parameter("glaze_amount"), 0.28), "band is glazed in its choice's colour")
	check(MenuBand.boil_step(0.0) == MenuBand.boil_step(0.1) and MenuBand.boil_step(0.0) != MenuBand.boil_step(0.12), "edges boil in steps at ~9 fps")
	for i in range(4):
		check(menu.band.art_scale(i) <= MenuBand.ART_MAX_SCALE, "painting %d is never enlarged past 1.5x design" % i)
	check(is_equal_approx(menu.city_dim(), 0.72), "city dims behind the band")
	menu.select(3)
	await get_tree().process_frame
	check(mat.get_shader_parameter("mix_ab") < 0.5, "art cross-fades, not re-wiped")
	await get_tree().create_timer(0.7).timeout
	var home := get_window().size
	for screen in [Vector2i(2560, 1080), Vector2i(1024, 768)]:
		get_window().size = screen
		await get_tree().process_frame
		await get_tree().process_frame
		var c: float = menu.band.get_global_rect().get_center().y
		var w: float = menu.words[3].get_global_rect().get_center().y
		check(absf(c - w) < 3.0, "band stays on its word at %s" % screen)
	get_window().size = home
	await get_tree().process_frame

	# Task 3 re-enables the page checks against open_page/close_page.
	check(ResourceLoader.exists(menu.game_scene), "New Game points at an existing playable scene")
	check(ProjectSettings.get_setting("application/run/main_scene") == "res://main_menu.tscn", "normal game launch opens the new menu")
	menu.queue_free()
	await get_tree().process_frame
	DirAccess.remove_absolute(Settings.path)
	Settings.path = original_path
	Settings.reload()
	AudioServer.set_bus_volume_db(0, original_volume)
	print("==== RESULTS ====")
	get_tree().quit(1 if failures else 0)
