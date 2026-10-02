extends Node3D
## Windowed sky QA plus a real GPU/CPU density comparison. Screenshots:
## Godot --path . res://tests/visual/stage_clouds.tscn -- --out=/tmp/cloud-shots
const NightScript := preload("res://scripts/Night/Night.gd")
var _out := "/tmp/cloud-shots/"

func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.trim_prefix("--out=").trim_suffix("/") + "/"
	DirAccess.make_dir_recursive_absolute(_out)
	AudioServer.set_bus_mute(0, true)
	var moon := DirectionalLight3D.new()
	add_child(moon)
	moon.global_basis = Basis.looking_at(Vector3(0.6, -0.5, 0.6).normalized(), Vector3.UP)
	var world := WorldEnvironment.new()
	world.environment = Environment.new()
	add_child(world)
	var night := NightScript.new()
	night.moon = moon
	night.environment = world.environment
	night.seed = 17
	add_child(night)
	night.set_process(false)
	var camera := Camera3D.new()
	add_child(camera)
	camera.current = true
	camera.fov = 38.0
	camera.look_at(night.moon_direction())
	await _shot("00_clear_000s")
	var elapsed := 0.0
	var partial := false
	var full := false
	while elapsed < 240.0:
		night._process(0.25)
		elapsed += 0.25
		var cover: float = night.cloud_cover()
		if elapsed in [15.0, 30.0, 60.0, 120.0]:
			await _shot("clear_%03ds" % int(elapsed))
			print("Clear sky %.0fs: moon visibility %.3f, field offset %s" % [elapsed, night.moon_visibility(), night._offset])
		if not partial and cover > 0.2 and cover < 0.7:
			partial = true
			camera.fov = 12.0
			await _shot("partial_close_%03ds" % int(elapsed))
			camera.fov = 38.0
			await _density_probe(night)
		if not full and cover > 0.99:
			full = true
			await _shot("opaque_belly_%03ds" % int(elapsed))
	print("Cloud stills at %s; partial %s, naturally opaque %s" % [_out, partial, full])
	get_tree().quit()

func _shot(label: String) -> void:
	for i in 3:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(_out + label + ".png")

func _density_probe(night: Node) -> void:
	# Execute the production shader's density functions on the GPU, replacing
	# only its final colour presentation. Compare those pixels to density_at.
	var source: ShaderMaterial = night._sky.material
	var shader := Shader.new()
	shader.code = source.shader.code.split("void sky() {")[0] + "void sky() { COLOR = vec3(clouds(normalize(EYEDIR))); }"
	var material := ShaderMaterial.new()
	material.shader = shader
	for parameter in ["cloud_field", "cloud_offset", "cloud_cover"]:
		material.set_shader_parameter(parameter, source.get_shader_parameter(parameter))
	var view := SubViewport.new()
	view.size = Vector2i(96, 96)
	view.own_world_3d = true
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(view)
	var world := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	environment.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	environment.sky = Sky.new()
	environment.sky.sky_material = material
	world.environment = environment
	view.add_child(world)
	var camera := Camera3D.new()
	camera.fov = 48.0
	view.add_child(camera)
	camera.current = true
	camera.look_at(night.moon_direction())
	for i in 4:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image := view.get_texture().get_image()
	image.save_png(_out + "density_probe.png")
	var largest := 0.0
	var sum := 0.0
	var count := 0
	for y in range(4, 92, 4):
		for x in range(4, 92, 4):
			var dir := camera.project_ray_normal(Vector2(x + 0.5, y + 0.5))
			var gpu := image.get_pixel(x, y).srgb_to_linear().r
			var cpu: float = night.density_at(dir)
			var error := absf(gpu - cpu)
			largest = maxf(largest, error)
			sum += error
			count += 1
	print("%s GPU cloud opacity matches CPU across %d directions; mean error %.4f, max %.4f" % ["PASS" if largest < 0.035 else "FAIL", count, sum / count, largest])
	view.queue_free()
