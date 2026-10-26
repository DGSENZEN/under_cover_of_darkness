extends SceneTree
## Native captures of the archetype screen: each archetype chosen, two frames
## of its effects a beat apart, and the confirm's surge.
## godot --path . --script res://tests/visual/archetype_preview.gd
var failures := 0

func check(ok: bool, message: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + message)
	if not ok:
		failures += 1

func _initialize() -> void:
	call_deferred("run")

func capture(path: String) -> Image:
	await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	image.save_png(path)
	print("Captured ", path)
	return image

func run() -> void:
	root.size = Vector2i(1280, 720)
	var menu: MainMenu = load("res://main_menu.tscn").instantiate()
	menu.game_scene = "res://tests/fixtures/tiny_game.tscn"
	root.add_child(menu)
	current_scene = menu
	Input.warp_mouse(Vector2(1270, 710))
	await create_timer(1.0).timeout
	menu.words[0].pressed.emit()
	await create_timer(MenuMotion.PRESS + 1.2).timeout
	var screen := menu.archetypes
	for i in [1, 0, 2]:
		screen.select(i)
		await create_timer(1.6).timeout
		var a := await capture("/private/tmp/archetype-%d.png" % i)
		await create_timer(0.35).timeout
		var b := await capture("/private/tmp/archetype-%d-b.png" % i)
		var moved := 0
		for y in range(0, a.get_height(), 8):
			for x in range(0, a.get_width(), 8):
				if (a.get_pixel(x, y) - b.get_pixel(x, y)).get_luminance() > 0.03:
					moved += 1
		check(moved > 20, "archetype %d's effects move (%d samples changed)" % [i, moved])
	screen.select(1)
	await create_timer(1.2).timeout
	root.size = Vector2i(2560, 1080)
	await create_timer(0.3).timeout
	await capture("/private/tmp/archetype-wide.png")
	root.size = Vector2i(1280, 720)
	await create_timer(0.3).timeout
	# Each archetype's transition, without leaving for the game.
	screen.confirmed.disconnect(menu._start_game)
	for i in [0, 1, 2]:
		menu.transition.clear()
		screen.open()
		await create_timer(1.0).timeout
		screen.select(i)
		await create_timer(0.8).timeout
		screen.confirm()
		await create_timer(ArchetypeScreen.SURGE_HOLD + 0.05).timeout
		menu.transition.play(i, screen.cards[i].get_global_rect().get_center())
		for f in [0.1, 0.25, 0.4, 0.55, 0.7, 0.85, 1.0]:
			while menu.transition.progress < f - 0.001:
				await process_frame
			var shot := await capture("/private/tmp/archetype-go-%d-%d.png" % [i, int(f * 100)])
			if f >= 1.0:
				var lit := 0
				for y in range(0, shot.get_height(), 16):
					for x in range(0, shot.get_width(), 16):
						if shot.get_pixel(x, y).get_luminance() > 0.08:
							lit += 1
				check(lit == 0, "archetype %d's transition ends in the dark (%d lit samples)" % [i, lit])
	print("==== RESULTS ====")
	quit(1 if failures else 0)
