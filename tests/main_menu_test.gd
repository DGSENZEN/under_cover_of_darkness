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
	menu.music_score = "res://tests/fixtures/menu_score/score.json"
	add_child(menu)
	await get_tree().process_frame
	await get_tree().process_frame
	check(menu.music != null and menu.music.get_parent() == get_tree().root and menu.music.available, "the menu's music lives under the root")
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

	# Piece 1: the bundled typefaces.
	check(MenuType.title().get_font_name().contains("Poiret") and MenuType.choice().get_font_name().contains("Cormorant SC") and MenuType.body().get_font_name().contains("Cormorant Garamond") and MenuType.body_italic().get_font_style() & TextServer.FONT_ITALIC, "the bundled typefaces load")

	# Task 1: the word column and one selection path.
	check(menu.words.size() == 5 and menu.words.map(func(w): return w.text) == ["New Game", "Continue", "Settings", "Lore", "Quit"], "five words in reading order")
	var title_labels: Array = menu._design.get_children().filter(func(n): return n is Label)
	check(title_labels.size() == 2 and title_labels.all(func(l): return l.get_theme_font("font").get_font_name().contains("Poiret")), "the title is set in deco capitals")
	check(menu._design.get_node_or_null("Hairline") is TextureRect, "a gold hairline under the title")
	check(menu.words[0].get_theme_font("font").get_font_name().contains("Cormorant SC") and menu.words[0].get_node_or_null("Tick") == null, "the choices are book small capitals, with no marker")
	check(menu.words[1].position.y - menu.words[0].position.y >= 56.0, "words have room between them")
	check(menu.words.all(func(w): return is_equal_approx(w.position.x, menu.words[0].position.x)), "words sit in one column")
	check(menu.selected == -1, "nothing is selected before input")
	check(menu.washes_showing() == 0, "no painting before input")
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
	check(menu.music.selected == 3 and menu.music.last_jingle.get("button") == 3 and menu.music.last_jingle.get("kind") == "hover", "choosing a word sounds its instrument")
	check(not menu.has_method("music_marker"), "the old music marker hook is gone")
	menu.select(1)
	await get_tree().create_timer(0.25).timeout
	check(is_equal_approx(menu.words[1].step_x, MenuWord.STEP) and is_equal_approx(menu.words[1].modulate.a, 1.0) and absf(menu.words[0].modulate.a - MenuWord.DIM) < 0.01, "the chosen word steps forward and lights within 0.2 s; the rest dim")

	# Piece 1: a painterly wash per word.
	menu.select(0)
	await get_tree().create_timer(0.7).timeout
	check(menu.words[0].wash.level > 0.99 and menu.washes_showing() == 1, "the selected word's painting blooms in")
	check(is_equal_approx(menu.city_dim(), 0.72) and is_equal_approx(menu.background.dim, 0.72), "the city dims a little behind it")
	check(MenuBand.boil_step(0.0) == MenuBand.boil_step(0.1) and MenuBand.boil_step(0.0) != MenuBand.boil_step(0.12), "edges boil in steps at ~9 fps")
	check(menu.words[0].wash.size.is_equal_approx(MenuWash.SIZE) and menu.words[0].wash.get_parent().get_index() < menu.words[0].get_index(), "a small wash, behind every word")
	menu.select(1)
	await get_tree().create_timer(0.08).timeout
	check(menu.words[0].wash.level > 0.05 and menu.words[1].wash.level > 0.05, "the old painting fades while the new one blooms")
	await get_tree().create_timer(0.7).timeout
	check(menu.words[0].wash.level < 0.01 and menu.words[1].wash.level > 0.99, "then only the new one shows")
	var at: Vector2 = menu.words[1].wash.get_global_rect().position
	menu.select(2)
	menu.select(1)
	await get_tree().create_timer(0.7).timeout
	check(menu.words[1].wash.get_global_rect().position.distance_to(at) < 12.0, "washes never travel between words")
	menu.select(0)
	await get_tree().create_timer(0.7).timeout
	var most := 0
	for k in range(3):
		await key(KEY_DOWN)
		most = maxi(most, menu.washes_showing())
	check(most <= 2, "fast keys: never more than two paintings at once (saw %d)" % most)
	await get_tree().create_timer(0.7).timeout
	check(menu.washes_showing() == 1, "and it settles on one")
	menu.words[menu.selected].mouse_exited.emit()
	await get_tree().create_timer(0.5).timeout
	check(menu.washes_showing() == 1, "leaving the words keeps the selection's painting")
	check(menu.words[4].wash == null, "Quit has no painting")
	for i in range(8):
		menu.words[i % 4].mouse_entered.emit()
		await get_tree().process_frame
	await get_tree().create_timer(0.7).timeout
	check(menu.selected == 3 and menu.words[3].wash.level > 0.99 and menu.washes_showing() == 1, "hover spam ends on the last word's painting")

	# Piece 1: a press-in, then the action.
	menu.words[2].pressed.emit()
	await get_tree().create_timer(0.05).timeout
	check(menu.words[2].scale.x < 0.99 and menu.page_open == -1, "pressing a word presses it in first")
	await get_tree().create_timer(0.25).timeout
	check(is_equal_approx(menu.words[2].scale.x, 1.0) and menu.page_open == 2, "then it springs back and its page opens")
	menu.close_page()
	await get_tree().create_timer(0.6).timeout

	# Review fixes: pages reach the screen's edges on any window shape.
	var tall: Rect2 = MainMenu.visible_design_rect(Vector2(2560, 1600))
	var ultra: Rect2 = MainMenu.visible_design_rect(Vector2(2560, 1080))
	check(tall.is_equal_approx(Rect2(0, -50, 1600, 1000)) and absf(ultra.position.x + 266.667) < 0.01 and absf(ultra.end.x - 1866.667) < 0.01, "the visible screen in design space")

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
	await get_tree().process_frame
	var art_last: float = menu.band.art_left()
	var widest := 0.0
	menu.open_page(3)
	for i in range(45):
		await get_tree().process_frame
		widest = maxf(widest, absf(menu.band.art_left() - art_last))
		art_last = menu.band.art_left()
	check(widest < 40.0, "the picture glides when a page opens, it does not jump (largest step %.0f px)" % widest)
	check(menu.pages.title_label.text == "Lore" and not menu.pages.body_label.text.is_empty(), "Lore opens the city's existing setting")
	check(menu.music.state == MenuMusic.State.LORE, "the music knows Lore is open")
	await get_tree().create_timer(0.6).timeout
	check(float((menu.background.material as ShaderMaterial).get_shader_parameter("fx")) > 0.5, "the occult layer stirs the city while Lore is open")
	var shown: Rect2 = MainMenu.visible_design_rect(get_viewport().get_visible_rect().size)
	check(menu.band.page and menu.band.band_rect().is_equal_approx(Rect2(530, shown.position.y, shown.end.x - 530, shown.size.y)), "Lore spreads its band over the right of the screen (%s on %s)" % [menu.band.band_rect(), get_viewport().get_visible_rect().size])
	check(is_equal_approx(menu.band.material.get_shader_parameter("page"), 1.0), "the band's edges turn into a page's")
	for screen in [tall, ultra, MainMenu.visible_design_rect(Vector2(1024, 768))]:
		menu.band.set_screen(screen)
		var page_rect: Rect2 = menu.band.band_rect()
		check(is_equal_approx(page_rect.position.y, screen.position.y) and is_equal_approx(page_rect.end.y, screen.end.y) and is_equal_approx(page_rect.end.x, screen.end.x) and is_equal_approx(page_rect.position.x, 530.0), "the page reaches the screen's top, bottom and right at %s" % screen.size)
	menu.band.set_screen(MainMenu.visible_design_rect(get_viewport().get_visible_rect().size))
	check(menu.words[0].modulate.a < 0.4 and menu.words[0].visible, "other words dim but stay")
	check(menu.find_children("*", "PanelContainer", true, false).is_empty(), "the grey panel is gone")
	await key(KEY_ESCAPE)
	await get_tree().create_timer(0.7).timeout
	check(menu.page_open == -1 and menu.words[3].has_focus() and not menu.band.page, "Escape folds the page back to its word")
	check(absf(menu.words[0].modulate.a - MenuWord.DIM) < 0.01, "words come back when the page closes")
	check(ResourceLoader.exists(menu.game_scene), "New Game points at an existing playable scene")
	var starts := [0]
	menu.music.started.connect(func(): starts[0] += 1)
	menu.game_scene = "res://tests/fixtures/no_such_game.tscn"
	var covers := [0]
	var count_covers := func(n: Node): if n.name.begins_with("ArtLoading"): covers[0] += 1
	get_tree().root.child_entered_tree.connect(count_covers)
	menu.words[0].pressed.emit()
	await get_tree().process_frame
	menu.words[0].pressed.emit()
	await get_tree().create_timer(MenuMotion.PRESS + 0.05).timeout
	get_tree().root.child_entered_tree.disconnect(count_covers)
	check(starts[0] == 1 and covers[0] == 1, "pressing New Game twice starts one game (one cover)")
	await get_tree().create_timer(0.3).timeout
	check(menu.page_open == 0 and menu.music != null and is_instance_valid(menu.music) and menu.music.state != MenuMusic.State.STARTING, "a game that will not open: the menu says so and its music returns")
	menu.close_page()
	var old_music: Node = menu.music
	check(ProjectSettings.get_setting("application/run/main_scene") == "res://main_menu.tscn", "normal game launch opens the new menu")
	menu.queue_free()
	await get_tree().process_frame
	check(not is_instance_valid(old_music) or old_music.is_queued_for_deletion(), "leaving the menu (not for a game) stops its music")
	DirAccess.remove_absolute(Settings.path)
	Settings.path = original_path
	Settings.reload()
	AudioServer.set_bus_volume_db(0, original_volume)
	print("==== RESULTS ====")
	get_tree().quit(1 if failures else 0)
