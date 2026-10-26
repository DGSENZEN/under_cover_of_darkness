extends Node
## The pause menu: opening, Resume, the settings book, the confirms, Escape.
const PATH := "user://settings_pause_test.cfg"
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

func wait(seconds: float) -> void:
	await get_tree().create_timer(seconds, true, false, true).timeout

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var original := GameSettings.current_path()
	GameSettings.use_path(PATH)
	GameSettings.reread()
	var layer := CanvasLayer.new()
	add_child(layer)
	var menu := PauseMenu.new()
	layer.add_child(menu)
	var resumes := [0]
	menu.resume_requested.connect(func(): resumes[0] += 1)
	var quits := [0]
	var leaves := [0]
	menu.quit_game = func(): quits[0] += 1
	menu.leave_to_menu = func(): leaves[0] += 1
	await get_tree().process_frame
	check(not menu.visible, "hidden until the game is paused")
	get_tree().paused = true
	menu.set_open(true)
	await wait(0.3)
	check(menu.visible and menu.words.map(func(w): return w.text) == ["Resume", "Settings", "Main menu", "Quit"], "paused: the four words")
	check(menu.selected == 0 and menu.words[0].has_focus(), "Resume is ready")
	var shown := get_viewport().get_visible_rect()
	check(shown.encloses(menu.menu_rect()) and menu.menu_rect().position.x < shown.size.x * 0.3, "the words sit on the screen's left, like the main menu's")
	# A click on the painting, not on a word, does not resume.
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = shown.size * Vector2(0.75, 0.5)
	click.global_position = click.position
	get_viewport().push_input(click, true)
	var up: InputEventMouseButton = click.duplicate()
	up.pressed = false
	get_viewport().push_input(up, true)
	await wait(0.1)
	check(resumes[0] == 0 and menu.visible, "a click on the painting does not resume")
	menu.words[0].pressed.emit()
	await wait(MenuMotion.PRESS + 0.1)
	check(resumes[0] == 1, "Resume asks to resume")
	# Settings: the book; Escape folds it, a second Escape resumes.
	menu.words[1].pressed.emit()
	await wait(MenuMotion.PRESS + 0.3)
	check(menu.settings_open and menu.settings.is_visible_in_tree() and menu.settings.rows()[0].has_focus(), "Settings opens the book, its first row ready")
	menu.settings.show_tab(2)
	menu.settings.row_for("keys/jump").press()
	# (The book takes that Escape; it never reaches the HUD's back().)
	await key(KEY_ESCAPE)
	check(menu.settings.capturing == null and menu.settings_open, "Escape while a key row waits cancels only the wait")
	menu.back()
	check(not menu.settings_open and menu.words[1].has_focus() and resumes[0] == 1, "Escape folds the book back to its word")
	menu.back()
	check(resumes[0] == 2, "and Escape again resumes")
	# Quit asks first; No goes back, Yes quits.
	menu.words[3].pressed.emit()
	await wait(MenuMotion.PRESS + 0.3)
	check(menu.asking == 3 and menu.confirm_no.has_focus() and quits[0] == 0, "Quit asks first, with No ready")
	menu.back()
	check(menu.asking == -1 and menu.words[3].has_focus(), "Escape answers no")
	menu.words[3].pressed.emit()
	await wait(MenuMotion.PRESS + 0.3)
	menu.confirm_yes.pressed.emit()
	await wait(MenuMotion.PRESS + 0.1)
	check(quits[0] == 1, "Yes quits")
	menu.close_confirm()
	menu.words[2].pressed.emit()
	await wait(MenuMotion.PRESS + 0.3)
	check(menu.asking == 2 and leaves[0] == 0, "Main menu asks first")
	menu.confirm_yes.pressed.emit()
	await wait(MenuMotion.PRESS + 0.1)
	check(leaves[0] == 1, "Yes leaves for the main menu")
	menu.close_confirm()
	menu.set_open(false)
	get_tree().paused = false
	check(not menu.visible, "unpaused, it goes")
	menu.set_open(true)
	check(menu.visible and not menu.settings_open and menu.asking == -1 and menu.selected == 0, "opening again starts fresh, on Resume")
	menu.set_open(false)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))
	GameSettings.use_path(original)
	GameSettings.reread()
	print("==== RESULTS ====")
	get_tree().quit(1 if failures else 0)
