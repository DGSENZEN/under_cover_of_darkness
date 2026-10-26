extends SceneTree
## Native-renderer visual regression captures, followed by a real New Game.
## godot --path . --script res://tests/visual/main_menu_preview.gd
var failures := 0

func check(ok: bool, message: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + message)
	if not ok:
		failures += 1

func click_control(control: Control) -> void:
	var at := control.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = at
	motion.global_position = at
	root.push_input(motion, true)
	await process_frame
	for down in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.position = at
		event.global_position = at
		event.pressed = down
		root.push_input(event, true)
		await process_frame

func key(code: Key) -> void:
	for down in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.pressed = down
		root.push_input(event, true)
		await process_frame

func _initialize() -> void:
	call_deferred("run")

func capture(path: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(path)
	print("Captured ", path)

func run() -> void:
	root.size = Vector2i(1280, 720)
	var menu: CanvasLayer = load("res://main_menu.tscn").instantiate()
	root.add_child(menu)
	current_scene = menu
	await create_timer(1.0).timeout
	await capture("/private/tmp/main-menu-idle.png")
	var first_paint := root.get_texture().get_image()
	await create_timer(2.0).timeout
	await RenderingServer.frame_post_draw
	var later_paint := root.get_texture().get_image()
	# Compare as shown on screen (8-bit), not the viewport's float buffer.
	first_paint.convert(Image.FORMAT_RGBA8)
	later_paint.convert(Image.FORMAT_RGBA8)
	# Map painting pixels to the screen (aspect-covered) and compare.
	var masks: Image = load("res://assets/ui/main_menu/city_masks.png").get_image()
	var shown := Vector2(masks.get_size()) * maxf(1280.0 / masks.get_width(), 720.0 / masks.get_height())
	var offset := (Vector2(1280, 720) - shown) * 0.5
	var rng := RandomNumberGenerator.new()
	rng.seed = 23
	var still := 0
	var tried := 0
	var sky_moved := 0
	var attempts := 0
	while tried < 20 and attempts < 5000:
		attempts += 1
		var at := Vector2i(rng.randi_range(0, masks.get_width() - 1), rng.randi_range(int(masks.get_height() * 0.3), masks.get_height() - 1))
		var mask := masks.get_pixelv(at)
		var screen := Vector2i((Vector2(at) / Vector2(masks.get_size()) * shown + offset).round())
		# Right of the words' veil, on painting that nothing is meant to stir.
		if screen.x < 520 or screen.x >= 1280 or screen.y >= 720 or mask.r + mask.g + mask.b + mask.a > 0.0:
			continue
		tried += 1
		# The viewport dithers by a hair each frame; real motion is far larger.
		var a := first_paint.get_pixelv(screen)
		var b := later_paint.get_pixelv(screen)
		if absf(a.r - b.r) + absf(a.g - b.g) + absf(a.b - b.b) < 0.02:
			still += 1
	var sky_seen := 0
	for y in range(10, 200, 4):
		for x in range(600, 1270, 4):
			sky_seen += 1
			var before := first_paint.get_pixel(x, y)
			var after := later_paint.get_pixel(x, y)
			if absf(before.r - after.r) + absf(before.g - after.g) + absf(before.b - after.b) > 0.01:
				sky_moved += 1
	check(still == 20, "the painted architecture never moves (%d/20 identical)" % still)
	check(sky_moved > sky_seen / 100, "the sky lives (%d of %d sky pixels changed)" % [sky_moved, sky_seen])
	for region in [Rect2i(0, 0, 640, 240), Rect2i(380, 160, 520, 260), Rect2i(0, 480, 1280, 220)]:
		later_paint.get_region(region).save_png("/private/tmp/main-menu-city-%d-%d.png" % [region.position.x, region.position.y])
	for i in range(4):
		menu.select(i)
		await create_timer(0.9).timeout
		await capture("/private/tmp/main-menu-band-%d.png" % i)
	var full := root.get_texture().get_image()
	full.get_region(Rect2i(820, 230, 400, 300)).save_png("/private/tmp/main-menu-band-edge.png")
	print("Captured /private/tmp/main-menu-band-edge.png")
	menu.select(1)
	await create_timer(0.2).timeout
	await capture("/private/tmp/main-menu-band-glide.png")
	menu.words[0].button_down.emit()
	await capture("/private/tmp/main-menu-click.png")
	await click_control(menu.words[2])
	await create_timer(0.9).timeout
	check(menu.page_open == 2 and menu.pages.title_label.text == "Settings", "mouse click opens Settings")
	await capture("/private/tmp/main-menu-page-settings.png")
	await key(KEY_ESCAPE)
	await create_timer(0.6).timeout
	check(menu.page_open == -1 and menu.words[2].has_focus(), "Escape restores the selected word")
	await key(KEY_UP)
	await key(KEY_DOWN)
	await key(KEY_DOWN)
	check(menu.words[3].has_focus(), "arrow keys move through the column")
	await key(KEY_ENTER)
	await create_timer(0.9).timeout
	check(menu.page_open == 3 and menu.pages.title_label.text == "Lore", "Enter activates the focused word")
	await capture("/private/tmp/main-menu-page-lore.png")
	await key(KEY_ESCAPE)
	await create_timer(0.6).timeout
	menu.open_page(1)
	await create_timer(0.9).timeout
	await capture("/private/tmp/main-menu-page-continue.png")
	menu.close_page()
	await create_timer(0.6).timeout
	root.size = Vector2i(2560, 1080)
	await create_timer(0.3).timeout
	await capture("/private/tmp/main-menu-wide.png")
	root.size = Vector2i(900, 900)
	await capture("/private/tmp/main-menu-square.png")
	root.size = Vector2i(1280, 720)
	await process_frame
	await click_control(menu.words[0])
	var deadline := Time.get_ticks_msec() + 120000
	var captured_loading := false
	while Time.get_ticks_msec() < deadline:
		var cover := root.get_node_or_null("ArtLoading")
		if cover != null and not captured_loading:
			await capture("/private/tmp/main-menu-loading.png")
			captured_loading = true
		if current_scene != menu and current_scene != null and current_scene.get("loading_complete") == true and cover == null:
			break
		await process_frame
	var started := current_scene != menu and current_scene != null and current_scene.scene_file_path == "res://maps/metro.tscn"
	check(captured_loading, "New Game displays the artwork loading cover")
	check(started and current_scene.get("player") != null and current_scene.get("loading_complete") == true, "New Game loads the actual Metro Underground with its player and candle lane")
	var lane := current_scene.get_node_or_null("candle_lane") if started else null
	var library: Node = lane.get("shop") if lane != null and "shop" in lane else null
	check(lane != null and lane.get("loading_complete") == true and library != null and library.get("loading_complete") == true and library.get("effects") != null, "the built candle lane and library finish loading, beyond the greybox")
	check(not paused and root.get_node_or_null("ArtLoading") == null, "completed loading reveals and unpauses the map")
	if started:
		await capture("/private/tmp/main-menu-metro.png")
		var player: CharacterBody3D = current_scene.player
		check(current_scene.spawn_point().distance_to(lane.global_position) < 8.0, "Metro spawn is within the authored candle lane")
		var shade: Node3D = lane.shades["curandera"]
		player.global_position = lane.to_global(Vector3(-0.09, 1.0, 0.64))
		player.velocity = Vector3.ZERO
		await create_timer(0.2).timeout
		var neck: Node3D = player.get_node("Neck")
		var direction := (shade.global_position + Vector3(0, 1.2, 0) - neck.global_position).normalized()
		player.rotation.y = atan2(-direction.x, -direction.z)
		neck.rotation.x = asin(direction.y)
		await create_timer(0.3).timeout
		check(player.frob.target == shade and player.frob.current_prompt() == "Talk", "aiming across the curandera's counter offers Talk")
		Input.action_press("frob")
		await physics_frame
		await physics_frame
		Input.action_release("frob")
		await create_timer(0.7).timeout
		var box: Node = player.frob.talking()
		check(box != null and player.talk_hold and box.skin.backdrop != null, "E opens the existing painted conversation UI in the actual Metro")
		await capture("/private/tmp/metro-dialogue.png")
		if box != null:
			box.interrupt()
		await create_timer(0.3).timeout
		check(not player.talk_hold, "ending the conversation returns player control")
	quit(1 if failures else 0)
