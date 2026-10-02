extends Node3D
## Windowed production sky/water captures, including obstruction and shore exit.
const Water := preload("res://scripts/Interaction/WaterVolume.gd")
const Night := preload("res://scripts/Night/Night.gd")
const Props := preload("res://scripts/Interaction/Props.gd")
var out := "/tmp/water-shots/"
var camera: Camera3D
var failed := false

func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.trim_prefix("--out=").trim_suffix("/") + "/"
	DirAccess.make_dir_recursive_absolute(out)
	AudioServer.set_bus_mute(0, true)
	var moon := DirectionalLight3D.new()
	moon.name = "Moon"
	moon.rotation_degrees = Vector3(-40, 0, 0)
	moon.light_energy = 0.45
	moon.light_color = Color(0.65, 0.75, 1.0)
	add_child(moon)
	var world := WorldEnvironment.new()
	world.environment = Environment.new()
	world.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	world.environment.ambient_light_color = Color(0.3, 0.4, 0.5)
	world.environment.ambient_light_energy = 0.3
	world.environment.ssr_enabled = true
	add_child(world)
	var night := Night.new()
	night.moon = moon
	night.environment = world.environment
	night.seed = 17
	add_child(night)
	night.set_process(false)
	Props.block(self, Vector3(0, -4.5, 0), Vector3(26, 1, 26))
	Props.block(self, Vector3(-13, -1.5, 0), Vector3(1, 8, 26))
	Props.block(self, Vector3(13, -1.5, 0), Vector3(1, 8, 26))
	Props.block(self, Vector3(0, -1.5, -13), Vector3(26, 8, 1))
	for x in [-7, 7]:
		Props.block(self, Vector3(x, -2, 3), Vector3(0.7, 8, 0.7))
		var lamp := OmniLight3D.new()
		lamp.position = Vector3(x, 2.0, 3)
		lamp.light_color = Color(1, 0.5, 0.18)
		lamp.light_energy = 3
		lamp.omni_range = 12
		add_child(lamp)
	var water := Water.build(self, Vector3(0, -1.5, 0), Vector3(25, 5, 25))
	water.clarity = 0.55
	camera = Camera3D.new()
	camera.fov = 75
	add_child(camera)
	camera.current = true
	camera.position = Vector3(0, 2.5, -7)
	camera.look_at(Vector3(0, 0.5, 7))
	await _shot("00_surface")
	camera.position = Vector3(0, -1.0, -7)
	camera.look_at(camera.position + moon.global_basis.z * 20)
	await _shot("01_moon_underwater")
	var view: Node = get_viewport().get_node("WaterView")
	var strength: float = view.ray_strength
	_check("underwater moon strength %.3f" % strength, strength > 0.1)
	# Freeze source data and compare the actual rendered pass with shafts off.
	view.set_process(false)
	var with_rays := get_viewport().get_texture().get_image()
	view._material.set_shader_parameter("ray_strength", 0.0)
	await _shot("01b_same_view_without_shafts")
	var without_rays := get_viewport().get_texture().get_image()
	var gain := 0.0
	var pixels := 0
	for y in range(20, with_rays.get_height() - 20, 8):
		for x in range(20, with_rays.get_width() - 20, 8):
			var lit := with_rays.get_pixel(x, y).get_luminance()
			var unlit := without_rays.get_pixel(x, y).get_luminance()
			gain += lit - unlit
			pixels += 1
	gain /= pixels
	_check("GPU shafts change underwater pixels, average luminance gain %.4f" % gain, gain > 0.008)
	view.set_process(true)
	camera.look_at(Vector3(0, -3, 3))
	await _shot("02_submerged_floor")
	camera.look_at(camera.position + moon.global_basis.z * 20)
	var roof := Props.block(self, Vector3(0, 2.5, 0), Vector3(25, 0.4, 25))
	await _shot("03_roof_blocks_rays")
	_check("roof strength %.3f" % view.ray_strength, view.ray_strength < 0.001)
	roof.queue_free()
	# Coverage emerges from the ordinary moving weather field. Advance its
	# simulation between captures; do not place a cloud over the moon.
	night.to(&"cloudy", 60.0)
	var found_cloud := false
	for i in 3000:
		night._process(0.1)
		if night.cloud_cover() > 0.35 and night.cloud_cover() < 0.8:
			found_cloud = true
			break
	await _shot("04_clouds_dim_rays")
	_check("natural clouds dim underwater rays %.3f" % view.ray_strength, found_cloud and view.ray_strength < strength * 0.7)
	camera.position.y = 1.3
	await _shot("05_surfaced")
	get_tree().quit(1 if failed else 0)

func _shot(label: String) -> void:
	for i in 40:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out + label + ".png")

func _check(label: String, okay: bool) -> void:
	failed = failed or not okay
	print(("PASS " if okay else "FAIL ") + label)
