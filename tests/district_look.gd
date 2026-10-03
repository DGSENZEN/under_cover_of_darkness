extends Node3D
## A district's map looked at closely, for judging its geometry (the user's
## standing rule: joints seen at full size before a place is called done):
## views from a JSON list ([{name, at: [x, y, z], look: [x, y, z], fov}]),
## under a flat day (a sun, sky light, no fog, the retro grid off) or as
## played (--night). The map: --map (the harbour's by default).
##   Godot --path . --resolution 1920x1080 res://tests/district_look.tscn -- --map=res://maps/old_town.tscn --out=/tmp/look --views=/tmp/views.json [--night]

var out := "/tmp/look/"


func _ready() -> void:
	var views_path := ""
	var map_path := "res://maps/city.tscn"
	var day := true

	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.trim_prefix("--out=").trim_suffix("/") + "/"
		elif arg.begins_with("--views="):
			views_path = arg.trim_prefix("--views=")
		elif arg.begins_with("--map="):
			map_path = arg.trim_prefix("--map=")
		elif arg == "--night":
			day = false

	DirAccess.make_dir_recursive_absolute(out)
	AudioServer.set_bus_mute(0, true)
	var views: Array = JSON.parse_string(FileAccess.get_file_as_string(views_path))
	var map: Node3D = (load(map_path) as PackedScene).instantiate()
	add_child(map)
	await map.ready_to_play

	# (The loading screen gone before any picture; the player out of view.)
	for screen in get_tree().root.find_children("LoadingScreen", "CanvasLayer", true, false):
		screen.queue_free()

	map.player.set_physics_process(false)
	map.player.visible = false

	if map.player.get("hud") != null:
		map.player.hud.visible = false

	if day:
		_day(map)

	var camera := Camera3D.new()
	camera.far = 2500.0
	add_child(camera)
	camera.current = true
	await _frames(30)

	for v in views:
		var at := Vector3(v["at"][0], v["at"][1], v["at"][2])
		var look := Vector3(v["look"][0], v["look"][1], v["look"][2])
		camera.global_transform = Transform3D(Basis(), at).looking_at(look, Vector3.UP)
		camera.fov = float(v.get("fov", 70.0))
		await _frames(12)
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(out + String(v["name"]) + ".png")

	print("LOOK %d views to %s" % [views.size(), out])
	get_tree().quit()


## A flat day to judge shapes by: the night stopped, a plain sky, sky light,
## no fog, one sun casting.
func _day(map: Node3D) -> void:
	var retro := get_node_or_null(^"/root/Retro")

	if retro != null:
		retro.set("enabled", false)

	var night: Node = map.get("night")

	if night != null:
		night.process_mode = Node.PROCESS_MODE_DISABLED

	var env: Environment = map.get("environment")
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.62, 0.72, 0.85)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.8, 0.82, 0.9)
	env.ambient_light_energy = 0.55
	env.fog_enabled = false
	env.volumetric_fog_enabled = false
	env.tonemap_exposure = 1.0
	env.glow_enabled = false

	for light in map.find_children("*", "DirectionalLight3D", true, false):
		(light as DirectionalLight3D).visible = false

	var sun := DirectionalLight3D.new()
	sun.light_color = Color(1.0, 0.96, 0.88)
	sun.light_energy = 1.6
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 250.0
	add_child(sun)
	sun.global_basis = Basis.looking_at(Vector3(-0.45, -0.7, -0.55).normalized(), Vector3.UP)

	for node in map.find_children("*", "GPUParticles3D", true, false):
		(node as GPUParticles3D).emitting = false


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame
