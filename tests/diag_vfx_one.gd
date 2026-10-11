extends Node3D
## One effect up close, day and night, for looking at (diagnostic):
##   Godot --path . --resolution 960x540 res://tests/diag_vfx_one.tscn -- --effect=copal --out=/tmp/fx1

const RetroScript := preload("res://scripts/Visual/Retro.gd")


func _ready() -> void:
	var effect := "copal"
	var out := "/tmp/fx1/"

	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--effect="):
			effect = arg.trim_prefix("--effect=")
		elif arg.begins_with("--out="):
			out = arg.trim_prefix("--out=").trim_suffix("/") + "/"

	DirAccess.make_dir_recursive_absolute(out)
	var day := Environment.new()
	var sky := Sky.new()
	sky.sky_material = ProceduralSkyMaterial.new()
	day.sky = sky
	day.background_mode = Environment.BG_SKY
	day.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	var world := WorldEnvironment.new()
	world.environment = day
	add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(deg_to_rad(-45), deg_to_rad(-30), 0)
	add_child(sun)
	add_child(Ground.build(Rect2(-20, -20, 40, 40), [], [], 3, {"tile": &"ground_flags", "level": 0.0}))
	var eye := Camera3D.new()
	add_child(eye)
	eye.make_current()
	eye.global_transform = Transform3D(Basis(), Vector3(0, 1.6, 3.2)).looking_at(Vector3(0, 1.3, 0), Vector3.UP)
	var node: Node3D = Vfx.system(effect)
	add_child(node)
	Vfx.emit(node, true)
	await _seconds(4.0)
	get_viewport().get_texture().get_image().save_png(out + effect + "_day.png")
	world.environment = RetroScript.night_environment()
	sun.visible = false
	var lamp := OmniLight3D.new()
	lamp.light_color = Color("#e8d8a8")
	lamp.omni_range = 14.0
	lamp.light_energy = 1.6
	lamp.position = Vector3(1.5, 5.0, 1.0)
	add_child(lamp)
	await _seconds(2.0)
	get_viewport().get_texture().get_image().save_png(out + effect + "_night.png")
	print("diag: ", out)
	get_tree().quit()


func _seconds(s: float) -> void:
	var start := Time.get_ticks_msec()

	while Time.get_ticks_msec() - start < s * 1000.0:
		await get_tree().process_frame

	RenderingServer.force_draw()
