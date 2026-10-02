extends Node3D
## The harbour's look, staged for judging (the harbour plan, Task 17): the city
## as it is played, then a still from each vantage (the level's "vantage"
## markers: the mole at the start, the quay up at the rock, the Terreiro, the
## Sea Gate, the Ribeira, a nave, the galley, the carrack's top, the golden
## tower's terrace, the cave) under a clear night, a cloudy one and rain.
##   Godot --path . --resolution 1920x1080 res://tests/city_stills.tscn -- --out=/tmp/city-stills
##   (-- --weather=clear  for one weather; --only=view_ribeira  for one view)

const City := preload("res://maps/city.tscn")
const WEATHERS := [&"clear", &"cloudy", &"rain"]
## The lenses: a vantage marked "wide", the rest.
const WIDE := 82.0
const NORMAL := 66.0

var out := "/tmp/city-stills/"


func _ready() -> void:
	var weathers: Array = WEATHERS
	var only := ""

	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.trim_prefix("--out=").trim_suffix("/") + "/"
		elif arg.begins_with("--weather="):
			weathers = [StringName(arg.trim_prefix("--weather="))]
		elif arg.begins_with("--only="):
			only = arg.trim_prefix("--only=")

	DirAccess.make_dir_recursive_absolute(out)
	AudioServer.set_bus_mute(0, true)
	var city: Node3D = City.instantiate()
	add_child(city)
	await city.ready_to_play
	# (The thief out of it: his HUD hidden, him still.)
	city.player.set_physics_process(false)

	if city.player.get("hud") != null:
		city.player.hud.visible = false

	var camera := Camera3D.new()
	camera.far = 1500.0
	add_child(camera)
	camera.current = true
	var views: Array = []

	for district in city.levels:
		for m in city.levels[district].of("vantage"):
			if only == "" or String(m["name"]) == only:
				views.append(m)

	for weather in weathers:
		city.night.to(weather, 0.0)
		await _frames(90)

		for m in views:
			camera.global_transform = m["transform"]
			camera.fov = WIDE if String(m["props"].get("lens", "")) == "wide" else NORMAL
			await _shot("%s_%s" % [m["name"], weather])

	print("PASS %d stills to %s" % [views.size() * weathers.size(), out])
	get_tree().quit()


func _shot(label: String) -> void:
	await _frames(25)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out + label + ".png")


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame
