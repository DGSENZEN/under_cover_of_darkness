extends SceneTree
## Native captures of the pause menu over a level: the words, the settings
## book, a confirm. godot --path . --script res://tests/visual/pause_preview.gd
func _initialize() -> void:
	call_deferred("run")

func capture(path: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(path)
	print("Captured ", path)

func run() -> void:
	root.size = Vector2i(1280, 720)
	GameSettings.use_path("user://settings_preview.cfg")
	GameSettings.reread()
	var level: Node = load("res://maps/combat_arena.tscn").instantiate()
	root.add_child(level)
	current_scene = level
	await create_timer(3.0).timeout
	var player := get_first_node_in_group(&"player")
	var esc := InputEventAction.new()
	esc.action = &"ui_cancel"
	esc.pressed = true
	player._unhandled_input(esc)
	await create_timer(0.8, true, false, true).timeout
	var hud = player.hud
	await capture("/private/tmp/pause-menu.png")
	hud._pause.open_settings()
	await create_timer(0.5, true, false, true).timeout
	await capture("/private/tmp/pause-settings.png")
	hud._pause.close_settings()
	hud._pause.open_confirm(3)
	await create_timer(0.5, true, false, true).timeout
	await capture("/private/tmp/pause-quit.png")
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://settings_preview.cfg"))
	quit()
