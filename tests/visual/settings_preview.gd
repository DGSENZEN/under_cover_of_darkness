extends SceneTree
## Native captures of the settings book on the main menu, each tab.
## godot --path . --script res://tests/visual/settings_preview.gd
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
	var menu: MainMenu = load("res://main_menu.tscn").instantiate()
	root.add_child(menu)
	current_scene = menu
	Input.warp_mouse(Vector2(4000, 4000))
	await create_timer(1.0).timeout
	menu.open_page(2)
	await create_timer(1.0).timeout
	for i in range(4):
		menu.pages.settings.show_tab(i)
		await create_timer(0.3).timeout
		await capture("/private/tmp/settings-tab-%d.png" % i)
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://settings_preview.cfg"))
	quit()
