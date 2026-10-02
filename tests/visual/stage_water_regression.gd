extends Node3D
## GPU regressions for stable surface depth and excluding the first-person
## representation from opaque screen buffers used by water reflections.
const Water := preload("res://scripts/Interaction/WaterVolume.gd")
const Arms := preload("res://scripts/Interaction/ViewArms.gd")
const Player := preload("res://Player.tscn")
const Hand := preload("res://scripts/Interaction/HandSlot.gd")
var failed := false
var out := "/tmp/water-regression-shots/"

func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.trim_prefix("--out=").trim_suffix("/") + "/"
	DirAccess.make_dir_recursive_absolute(out)
	AudioServer.set_bus_mute(0, true)
	await _surface_depth()
	await _viewmodel(false)
	await _viewmodel(true)
	await _blood_order()
	get_tree().quit(1 if failed else 0)

func _viewport() -> SubViewport:
	var view := SubViewport.new()
	view.size = Vector2i(256, 256)
	view.own_world_3d = true
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(view)
	var world := WorldEnvironment.new()
	world.environment = Environment.new()
	world.environment.background_mode = Environment.BG_COLOR
	world.environment.background_color = Color(0.02, 0.07, 0.12)
	world.environment.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	view.add_child(world)
	return view

func _surface_depth() -> void:
	var view := _viewport()
	var water := Water.build(view, Vector3(0, -1, 0), Vector3(12, 2, 12))
	water.set_process(false)
	var camera := Camera3D.new()
	view.add_child(camera)
	camera.current = true
	camera.position = Vector3(0, 3, 4)
	camera.look_at(Vector3.ZERO)
	var shader := Shader.new()
	shader.code = """shader_type spatial;
render_mode unshaded, fog_disabled, cull_disabled, depth_draw_never, depth_test_disabled;
uniform sampler2D depth_map : hint_depth_texture, filter_nearest;
void vertex() { POSITION = vec4(VERTEX.xy, 1.0, 1.0); }
void fragment() {
	float d = texture(depth_map, SCREEN_UV).r;
	vec4 p = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, max(d, 0.00001), 1.0);
	vec3 w = (INV_VIEW_MATRIX * vec4(p.xyz / p.w, 1.0)).xyz;
	ALBEDO = vec3(clamp(w.y * 5.0 + 0.5, 0.0, 1.0));
	ALPHA = 1.0;
}"""
	_overlay(view, shader)
	water._paint.set_shader_parameter("water_clock", 0.0)
	var first := await _capture(view, "00_depth_phase0")
	water._paint.set_shader_parameter("water_clock", 3.0)
	var second := await _capture(view, "01_depth_phase3")
	var difference := 0.0
	var count := 0
	for y in range(80, 240, 3):
		for x in range(30, 225, 3):
			difference += absf(first.get_pixel(x, y).r - second.get_pixel(x, y).r)
			count += 1
	difference /= count
	_check("surface geometry remains at the same depth while shader ripples flow (%.5f)" % difference, difference < 0.001)
	view.queue_free()
	await get_tree().process_frame

func _viewmodel(arms: bool) -> void:
	var view := _viewport()
	var camera := Camera3D.new()
	view.add_child(camera)
	camera.current = true
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(1, 0, 1)
	if arms:
		material = Arms._squeezed(material) as StandardMaterial3D
	else:
		Hand._squeeze(material)
	var instance := MeshInstance3D.new()
	var mesh := QuadMesh.new()
	mesh.size = Vector2(0.7, 0.7)
	instance.mesh = mesh
	instance.material_override = material
	instance.position.z = -1
	view.add_child(instance)
	# Copy the opaque buffer's centre into an empty corner. The real hand
	# must stay visible at centre but never appear in this reflection source.
	var shader := Shader.new()
	shader.code = """shader_type spatial;
render_mode unshaded, fog_disabled, cull_disabled, depth_draw_never, depth_test_disabled;
uniform sampler2D screen : hint_screen_texture, filter_nearest;
void vertex() { POSITION = vec4(VERTEX.xy, 1.0, 1.0); }
void fragment() {
	if (SCREEN_UV.x > 0.25 || SCREEN_UV.y > 0.25) { discard; }
	ALBEDO = texture(screen, vec2(0.5)).rgb;
	ALPHA = 1.0;
}"""
	_overlay(view, shader)
	var image := await _capture(view, "03_arms" if arms else "02_weapon")
	var source := image.get_pixel(30, 30)
	var direct := image.get_pixel(128, 128)
	var label := "arms" if arms else "held item"
	_check(label + " stays visible in first person", direct.r > 0.8 and direct.b > 0.8 and direct.g < 0.1)
	_check(label + " is absent from the opaque reflection source", source.r < 0.3 and source.b < 0.5)
	view.queue_free()
	await get_tree().process_frame

func _blood_order() -> void:
	var view := _viewport()
	var player := Player.instantiate() as CharacterBody3D
	player.show_hud = false
	view.add_child(player)
	player.set_physics_process(false)
	player.set_process(false)
	player.hide()
	var camera := Camera3D.new()
	view.add_child(camera)
	camera.current = true
	var base := StandardMaterial3D.new()
	base.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	base.albedo_color = Color(1, 0, 1)
	Hand._squeeze(base)
	# Clone the live blood overlay's scheduling, with a solid diagnostic
	# colour instead of its sparse texture so missing pixels are unambiguous.
	var overlay: ShaderMaterial = player.get_node("Neck/Camera3D/Hand")._blood_overlay.duplicate()
	var shader := Shader.new()
	shader.code = """shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;
uniform float z_clip = 0.05;
void vertex() { VERTEX += NORMAL * 0.0006; Z_CLIP_SCALE = z_clip; }
void fragment() { ALBEDO = vec3(0.0, 1.0, 0.0); ALPHA = 1.0; }
"""
	overlay.shader = shader
	var instance := MeshInstance3D.new()
	var mesh := QuadMesh.new()
	mesh.size = Vector2(0.7, 0.7)
	instance.mesh = mesh
	instance.material_override = base
	instance.material_overlay = overlay
	instance.position.z = -1
	view.add_child(instance)
	var image := await _capture(view, "04_blood_overlay_order")
	var colour := image.get_pixel(128, 128)
	_check("blood overlay draws after the held blade", colour.g > 0.8 and colour.r < 0.1)
	view.queue_free()
	await get_tree().process_frame

func _overlay(view: SubViewport, shader: Shader) -> void:
	var instance := MeshInstance3D.new()
	var mesh := QuadMesh.new()
	mesh.size = Vector2(2, 2)
	instance.mesh = mesh
	instance.extra_cull_margin = 16384
	var material := ShaderMaterial.new()
	material.shader = shader
	material.render_priority = -127
	instance.material_override = material
	view.add_child(instance)

func _capture(view: SubViewport, label: String) -> Image:
	for i in 8:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image := view.get_texture().get_image()
	image.save_png(out + label + ".png")
	return image

func _check(label: String, okay: bool) -> void:
	failed = failed or not okay
	print(("PASS " if okay else "FAIL ") + label)
