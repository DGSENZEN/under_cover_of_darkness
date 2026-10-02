extends Node3D
## Real renderer: a shallow bed should show through while deep water stays dark.
const Water := preload("res://scripts/Interaction/WaterVolume.gd")
const Props := preload("res://scripts/Interaction/Props.gd")
var failed := false
var out := "/tmp/shore-shots/"

func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.trim_prefix("--out=").trim_suffix("/") + "/"
	DirAccess.make_dir_recursive_absolute(out)
	AudioServer.set_bus_mute(0, true)
	var world := WorldEnvironment.new()
	world.environment = Environment.new()
	world.environment.background_mode = Environment.BG_COLOR
	world.environment.background_color = Color(0.1, 0.15, 0.2)
	world.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	world.environment.ambient_light_color = Color.WHITE
	world.environment.ambient_light_energy = 1.0
	world.environment.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	world.environment.ssr_enabled = true
	add_child(world)
	Props.block(self, Vector3(-3, -0.62, -1.5), Vector3(3, 1, 3), Color(0.8, 0.25, 0.08))
	Props.block(self, Vector3(-3, -0.62, 1.5), Vector3(3, 1, 3), Color(0.1, 0.65, 0.25))
	var deep_bed := Props.block(self, Vector3(3, -2.5, -1.5), Vector3(3, 1, 3), Color(0.8, 0.25, 0.08))
	Props.block(self, Vector3(3, -2.5, 1.5), Vector3(3, 1, 3), Color(0.1, 0.65, 0.25))
	var water := Water.build(self, Vector3(0, -1.5, 0), Vector3(12, 3, 8))
	water.clarity = 0.6
	water._paint.set_shader_parameter("steep", 0.0)
	water._paint.set_shader_parameter("weed_amount", 0.0)
	water._paint.set_shader_parameter("weed_reach", 0.1)
	water.set_process(false)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 13
	add_child(camera)
	camera.current = true
	camera.position = Vector3(0, 12, 0)
	camera.look_at(Vector3.ZERO, Vector3.FORWARD)
	for i in 90:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	image.save_png(out + "00_shallow_and_deep.png")
	var shallow_red := _colour(image, camera, Vector3(-3, 0, -1.5))
	var shallow_green := _colour(image, camera, Vector3(-3, 0, 1.5))
	var deep_red := _colour(image, camera, Vector3(3, 0, -1.5))
	var deep_material := ((deep_bed.get_child(1) as MeshInstance3D).mesh as BoxMesh).material as StandardMaterial3D
	deep_material.albedo_color = Color(0.05, 0.85, 0.8)
	for i in 10:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var changed_image := get_viewport().get_texture().get_image()
	var deep_changed := _colour(changed_image, camera, Vector3(3, 0, -1.5))
	var contrast := shallow_red.r - shallow_green.r + shallow_green.g - shallow_red.g
	_check("shallow water reveals the bed's different colours (%.3f)" % contrast, contrast > 0.2)
	var deep_contrast := absf(deep_red.r - deep_changed.r) + absf(deep_red.g - deep_changed.g)
	_check("deep water retains its opaque body (%.3f)" % deep_contrast, deep_contrast < 0.02)
	await _natural_bank(camera, world.environment)
	get_tree().quit(1 if failed else 0)

func _colour(image: Image, camera: Camera3D, at: Vector3) -> Color:
	var pixel := camera.unproject_position(at)
	return image.get_pixel(int(pixel.x), int(pixel.y))

func _check(label: String, okay: bool) -> void:
	failed = failed or not okay
	print(("PASS " if okay else "FAIL ") + label)


func _natural_bank(camera: Camera3D, environment: Environment) -> void:
	var bank := Props.block(self, Vector3(40, -0.4, -2), Vector3(12, 0.4, 14), Color(0.46, 0.38, 0.26))
	bank.rotation_degrees.x = 8.0
	Props.block(self, Vector3(42.4, 0.1, 1.5), Vector3(1.6, 2.0, 2.0), Color(0.32, 0.35, 0.31))
	var water := Water.build(self, Vector3(40, -1.5, 0), Vector3(12, 3, 14))
	var moon := DirectionalLight3D.new()
	moon.name = "Moon"
	moon.rotation_degrees = Vector3(-45, -35, 0)
	moon.light_color = Color(0.65, 0.75, 1.0)
	moon.light_energy = 0.4
	add_child(moon)
	environment.ambient_light_energy = 0.35
	environment.ambient_light_color = Color(0.45, 0.48, 0.6)
	var lamp := OmniLight3D.new()
	lamp.position = Vector3(37, 1.8, -2)
	lamp.light_color = Color(1.0, 0.55, 0.2)
	lamp.light_energy = 2.0
	lamp.omni_range = 8.0
	add_child(lamp)
	camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	camera.position = Vector3(40, 2.2, 5.8)
	camera.look_at(Vector3(40, -0.1, -1))
	for i in 30:
		await get_tree().process_frame
	water._surface_parameter("shore_ready", false)
	await _shot("01_bank_before")
	water._surface_parameter("shore_ready", true)
	await _shot("02_bank_after")

func _shot(label: String) -> void:
	for i in 10:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out + label + ".png")
