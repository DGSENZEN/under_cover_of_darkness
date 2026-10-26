extends Node
## Menu navigation must remain usable without a save or an unfinished score.
const Settings := preload("res://scripts/UI/Settings.gd")
var failures := 0

func check(ok: bool, message: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + message)
	if not ok:
		failures += 1

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
	check(menu.buttons.size() == 4, "four painted actions are available")
	check(menu.game_scene == "res://maps/metro.tscn", "New Game enters the actual Metro Underground scene")
	var title_lines: Array[String] = []
	for child in menu._design.get_children():
		if child is Label:
			title_lines.append(child.text)
	check(title_lines == ["UNDER COVER", "OF DARKNESS"], "main screen contains only the title and painted actions")
	var atlas: Image = menu.BUTTONS.get_image()
	check(atlas.get_pixel(0, 0).a == 0.0 and atlas.get_pixel(atlas.get_width() / 2, 200).a == 0.0, "sheet exterior and button gutters are transparent")
	check(menu.buttons[0].caption == "New Game" and menu.buttons[1].caption == "Continue" and menu.buttons[2].caption == "Settings" and menu.buttons[3].caption == "Lore", "paintings use the requested reading order")
	menu.buttons[1].pressed.emit()
	check(menu.panel.visible and menu.panel_title.text == "Continue" and menu.panel_body.text.contains("save"), "Continue explains the missing save rather than starting a new game")
	menu.close_panel()
	menu.buttons[2].pressed.emit()
	check(menu.panel.visible and menu.panel_title.text == "Settings" and menu.settings_box.visible, "Settings opens existing game preferences")
	var volume: HSlider = menu.settings_box.get_node("Volume")
	volume.value = 0.35
	await get_tree().process_frame
	Settings.reload()
	check(is_equal_approx(Settings.master_volume(), 0.35) and is_equal_approx(db_to_linear(AudioServer.get_bus_volume_db(0)), 0.35), "volume changes reach the audio bus and survive a settings reload")
	Settings.set_awareness_marks(false)
	Settings.reload()
	check(not Settings.awareness_marks() and is_equal_approx(Settings.master_volume(), 0.35), "awareness and volume settings preserve each other")
	menu.close_panel()
	check(not menu.panel.visible and menu.buttons[2].has_focus(), "closing an overlay returns keyboard focus to its button")
	menu.buttons[3].pressed.emit()
	check(menu.panel.visible and menu.panel_title.text == "Lore" and not menu.panel_body.text.is_empty(), "Lore opens the city's existing setting")
	menu.close_panel()
	menu.music_marker(&"continue", 0.8)
	check(menu.buttons[1].music_energy > 0.7 and menu.buttons[0].music_energy == 0.0, "authored music markers target a particular painting")
	menu.buttons[0].set_highlighted(true)
	await get_tree().create_timer(0.35).timeout
	check(menu.buttons[0].paint.scale.x > 1.04, "hover enlarges the painted button")
	check(menu.buttons[0].get_node("Paint").material != menu.buttons[1].get_node("Paint").material, "paintings animate independently")
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
