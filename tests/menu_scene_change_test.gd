extends SceneTree
## New Game for real: the scene changes, and the menu's music outlives the
## menu until its phrase has ended, then frees itself.
## godot --headless --path . --script res://tests/menu_scene_change_test.gd
var failures := 0

func check(ok: bool, message: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + message)
	if not ok:
		failures += 1

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var menu: MainMenu = load("res://main_menu.tscn").instantiate()
	menu.music_score = "res://tests/fixtures/menu_score/score.json"
	menu.game_scene = "res://tests/fixtures/tiny_game.tscn"
	root.add_child(menu)
	current_scene = menu
	for i in range(3):
		await process_frame
	var music: MenuMusic = menu.music
	check(music != null and music.available and music.get_parent() == root, "the menu's music is under the root")
	# Real time through the archetype's transition, then a fast clock, so the
	# phrase ends within a second or so once the game is in.
	var started_ms := Time.get_ticks_msec()
	var changed_ms := [-1]
	music.position_source = func() -> float:
		var now := Time.get_ticks_msec()
		if changed_ms[0] < 0:
			return 2.0 + (now - started_ms) / 1000.0
		return 2.0 + (changed_ms[0] - started_ms) / 1000.0 + (now - changed_ms[0]) / 1000.0 * 20.0
	scene_changed.connect(func(): changed_ms[0] = Time.get_ticks_msec(), CONNECT_ONE_SHOT)
	var ended := [false]
	music.ended.connect(func(): ended[0] = true)
	menu.words[0].pressed.emit()
	await create_timer(MenuMotion.PRESS + 0.1).timeout
	menu.archetypes.confirm()
	await scene_changed
	check(current_scene != null and current_scene.name == "TinyGame", "New Game changed the scene")
	check(is_instance_valid(music) and music.get_parent() == root and music.state == MenuMusic.State.STARTING and not ended[0], "the music is still finishing its phrase after the menu is gone")
	var deadline := Time.get_ticks_msec() + 8000
	while not ended[0] and Time.get_ticks_msec() < deadline:
		await process_frame
	check(ended[0], "the phrase ends")
	await create_timer(0.4).timeout
	check(not is_instance_valid(music), "then the music frees itself")
	print("==== RESULTS ====")
	quit(1 if failures else 0)
