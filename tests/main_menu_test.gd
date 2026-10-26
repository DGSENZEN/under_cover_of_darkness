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

	# Task 4: a still painting that lives.
	check(menu.background is LivingCity, "background is the living city")
	check(not FileAccess.get_file_as_string("res://scripts/UI/city_life.gdshader").contains("paint_phase") and not ResourceLoader.exists("res://scripts/UI/living_paint.gdshader"), "the flow warp is retired")
	check((menu.background.material as ShaderMaterial).get_shader_parameter("masks") != null, "the city's masks are loaded")

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
	check(is_equal_approx(menu.city_dim(), 0.72) and is_equal_approx(menu.background.dim, 0.72), "city dims behind the band")
	menu.select(3)
	await get_tree().process_frame
	check(mat.get_shader_parameter("mix_ab") < 0.5, "art cross-fades, not re-wiped")
	await get_tree().create_timer(0.7).timeout
	for i in range(8):
		menu.words[i % 4].mouse_entered.emit()
		await get_tree().process_frame
	await get_tree().create_timer(0.7).timeout
	var last_word: float = menu.words[3].position.y + menu.words[3].size.y * 0.5
	check(menu.selected == 3 and absf(menu.band.position.y + menu.band.size.y * 0.5 - last_word) < 2.0, "hover spam ends with the band on the last word")
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

	# Task 3: pages open inside the band.
	menu.open_page(1)
	await get_tree().create_timer(0.7).timeout
	check(menu.page_open == 1 and menu.pages.title_label.text == "Continue" and menu.pages.body_label.text.contains("save"), "Continue explains the missing save rather than starting a new game")
	check(menu.pages.body_label.text == "No saved game yet. Choose New Game to begin.", "Continue says it in one line")
	menu.close_page()
	await get_tree().create_timer(0.7).timeout
	menu.open_page(2)
	await get_tree().create_timer(0.7).timeout
	check(menu.page_open == 2 and menu.pages.title_label.text == "Settings" and menu.pages.volume.is_visible_in_tree(), "Settings opens existing game preferences")
	check(menu.pages.volume.has_theme_stylebox_override("slider") and menu.pages.volume.has_theme_icon_override("grabber"), "settings controls are painted, not default")
	menu.pages.volume.value = 0.35
	await get_tree().process_frame
	Settings.reload()
	check(is_equal_approx(Settings.master_volume(), 0.35) and is_equal_approx(db_to_linear(AudioServer.get_bus_volume_db(0)), 0.35), "volume changes reach the audio bus and survive a settings reload")
	Settings.set_awareness_marks(false)
	Settings.reload()
	check(not Settings.awareness_marks() and is_equal_approx(Settings.master_volume(), 0.35), "awareness and volume settings preserve each other")
	menu.close_page()
	await get_tree().create_timer(0.7).timeout
	check(menu.page_open == -1 and menu.words[2].has_focus(), "closing a page returns keyboard focus to its word")
	menu.open_page(3)
	await get_tree().create_timer(0.7).timeout
	check(menu.pages.title_label.text == "Lore" and not menu.pages.body_label.text.is_empty(), "Lore opens the city's existing setting")
	check(menu.band.page and menu.band.band_rect() == Rect2(530, 0, 1070, 900), "Lore spreads its band over the right two-thirds")
	check(is_equal_approx(menu.band.material.get_shader_parameter("page"), 1.0), "the band's edges turn into a page's")
	check(menu.words[0].modulate.a < 0.4 and menu.words[0].visible, "other words dim but stay")
	check(menu.find_children("*", "PanelContainer", true, false).is_empty(), "the grey panel is gone")
	await key(KEY_ESCAPE)
	await get_tree().create_timer(0.7).timeout
	check(menu.page_open == -1 and menu.words[3].has_focus() and not menu.band.page, "Escape folds the page back to its word")
	check(menu.words[0].modulate.a > 0.5, "words come back when the page closes")
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
