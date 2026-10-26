extends SceneTree
## A scripted tour of the whole menu for a showcase video: the title, each
## word and its painting, the Lore and Settings pages, Quit's confirm, the
## archetypes and their sounds, each archetype's transition, and a real New
## Game into the Metro. Record it with Godot's movie maker:
## godot --path . --resolution 1600x900 --fixed-fps 30 --write-movie out.avi --script res://tests/visual/menu_showcase.gd
var menu: MainMenu

func _initialize() -> void:
	call_deferred("run")

func pause(seconds: float) -> void:
	await create_timer(seconds).timeout

## The pointer glides to a control over a few frames (so hovers fire as a hand would).
func point_at(control: Control, frames := 8) -> void:
	var to := control.get_global_rect().get_center()
	var from: Vector2 = root.get_meta("pointer", to + Vector2(0, 80))
	for i in range(1, frames + 1):
		var at := from.lerp(to, float(i) / frames)
		var motion := InputEventMouseMotion.new()
		motion.position = at
		motion.global_position = at
		root.push_input(motion, true)
		await process_frame
	root.set_meta("pointer", to)

func click() -> void:
	var at: Vector2 = root.get_meta("pointer", Vector2.ZERO)
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
		event.physical_keycode = code
		event.pressed = down
		root.push_input(event, true)
		await process_frame

func run() -> void:
	Input.warp_mouse(Vector2(4000, 4000))
	menu = load("res://main_menu.tscn").instantiate()
	root.add_child(menu)
	current_scene = menu
	root.set_meta("pointer", Vector2(1500, 860))
	# The title, and the city breathing.
	await pause(5.0)
	# Each word and its painting.
	for i in range(menu.words.size()):
		await point_at(menu.words[i], 10)
		await pause(1.8)
	# Lore, then Settings: their pages.
	await point_at(menu.words[3])
	await click()
	await pause(4.5)
	await key(KEY_ESCAPE)
	await pause(1.2)
	await point_at(menu.words[2])
	await click()
	await pause(3.5)
	await key(KEY_ESCAPE)
	await pause(1.2)
	# Quit asks first; No.
	await point_at(menu.words[4])
	await click()
	await pause(2.0)
	await point_at(menu.confirm_no)
	await pause(0.8)
	await click()
	await pause(1.2)
	# New Game: who you are.
	await point_at(menu.words[0])
	await pause(0.8)
	await click()
	await pause(2.5)
	var screen := menu.archetypes
	for i in [0, 2, 1]:
		await point_at(screen.cards[i], 12)
		await pause(3.2)
	# Back out, and in again.
	await point_at(screen.back)
	await pause(0.6)
	await click()
	await pause(1.8)
	await point_at(menu.words[0])
	await click()
	await pause(2.0)
	# Each archetype's way in (the first two stop at the dark, for the tour).
	screen.confirmed.disconnect(menu._start_game)
	for i in [0, 1]:
		await point_at(screen.cards[i], 10)
		await pause(1.6)
		await click()
		await pause(ArchetypeScreen.SURGE_HOLD)
		menu.music.press(MainMenu.ARCHETYPE_JINGLES + i)
		await menu.play_transition(i)
		await pause(0.8)
		menu.transition.clear()
		screen.open()
		await pause(1.6)
	screen.confirmed.connect(menu._start_game)
	# Factotum, for real: into the game.
	await point_at(screen.cards[2], 10)
	await pause(2.0)
	await click()
	var deadline := Time.get_ticks_msec() + 180000
	while Time.get_ticks_msec() < deadline:
		if current_scene != menu and current_scene != null and current_scene.get("loading_complete") == true and root.get_node_or_null("ArtLoading") == null:
			break
		await process_frame
	await pause(4.0)
	quit()
