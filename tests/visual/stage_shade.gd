extends Node3D
## Windowed visual QA: the curandera's shade (duelist, copal) at night under
## one lamp, calm, flare, dim and gutter, from the front and three-quarters at
## 2 m, and close on the fraying feet. With --more, the angles that catch a
## see-through body's faults too: behind, the side, above, the head close up,
## a turn, and against a bright wall.
## Godot --fixed-fps 60 --resolution 1280x720 --path . res://tests/visual/stage_shade.tscn -- --out=/tmp/shade

const SHADE := preload("res://scripts/Interaction/Shade.gd")
const DialogueBook := preload("res://scripts/Level/DialogueBook.gd")
const RetroScript := preload("res://scripts/Visual/Retro.gd")

var _out := "/tmp/shade/"
var _more := false
var shade: StaticBody3D
var camera: Camera3D


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.trim_prefix("--out=").trim_suffix("/") + "/"
		elif arg == "--more":
			_more = true

	DirAccess.make_dir_recursive_absolute(_out)
	AudioServer.set_bus_mute(0, true)
	DialogueBook.use(DialogueBook.load_dir("res://tests/fixtures/dialogue"))
	_night()
	camera = Camera3D.new()
	camera.fov = 60.0
	add_child(camera)
	camera.current = true

	shade = SHADE.new()
	shade.character = "fx_curandera"
	add_child(shade)
	# Facing +Z, toward the cameras.
	shade.rotation.y = PI
	await _frames(90)

	for state in [&"calm", &"flare", &"dim", &"gutter"]:
		shade.set_resting(state)
		shade.speaking(state == &"flare")
		await _frames(100)
		_look(Vector3(0.0, 1.35, 2.0), Vector3(0.0, 0.95, 0.0))
		await _shot("%s_front" % state)
		_look(Vector3(2.0 * sin(deg_to_rad(40.0)), 1.35, 2.0 * cos(deg_to_rad(40.0))), Vector3(0.0, 0.95, 0.0))
		await _shot("%s_three_quarter" % state)

	shade.speaking(false)
	shade.set_resting(&"calm")
	await _frames(100)
	_look(Vector3(0.25, 0.42, 0.85), Vector3(0.0, 0.18, 0.0))
	await _shot("feet_fray")

	if _more:
		await _inspect()

	get_tree().quit()


## The angles where a see-through body shows its faults.
func _inspect() -> void:
	# The back of the head and the nape, close.
	_look(Vector3(0.0, 1.6, -0.7), Vector3(0.0, 1.45, 0.0))
	await _shot("x_nape_close")

	# The three-quarter view through a long lens: its legs and its waist.
	camera.fov = 14.0
	_look(Vector3(2.0 * sin(deg_to_rad(40.0)), 1.35, 2.0 * cos(deg_to_rad(40.0))), Vector3(0.0, 0.45, 0.0))
	await _shot("x_legs_zoom")
	_look(Vector3(2.0 * sin(deg_to_rad(40.0)), 1.35, 2.0 * cos(deg_to_rad(40.0))), Vector3(0.0, 1.0, 0.0))
	await _shot("x_waist_zoom")
	camera.fov = 60.0
	_look(Vector3(0.0, 1.35, -2.0), Vector3(0.0, 0.95, 0.0))
	await _shot("x_back")
	_look(Vector3(2.0, 1.2, 0.0), Vector3(0.0, 0.95, 0.0))
	await _shot("x_side")
	_look(Vector3(0.6, 2.6, 1.2), Vector3(0.0, 1.0, 0.0))
	await _shot("x_above")
	_look(Vector3(0.15, 1.62, 0.6), Vector3(0.0, 1.58, 0.0))
	await _shot("x_head_close")
	_look(Vector3(-0.5, 1.3, 0.7), Vector3(0.0, 1.2, 0.0))
	await _shot("x_arm_over_body")
	shade.speaking(true)
	await _frames(40)
	_look(Vector3(-1.2, 1.4, 1.4), Vector3(0.0, 1.1, 0.0))
	await _shot("x_speaking_arms")
	shade.speaking(false)
	shade.cue(&"nod")
	await _frames(20)
	_look(Vector3(0.0, 1.5, 1.2), Vector3(0.0, 1.4, 0.0))
	await _shot("x_nod")
	await _frames(60)
	shade.cue(&"shake")
	await _frames(45)
	await _shot("x_shake")
	await _frames(120)
	shade.end_line()
	# Turning to face someone off to her left.
	shade.face(Vector3(3.0, 1.6, 0.5))
	await _frames(8)
	_look(Vector3(1.0, 1.45, 1.8), Vector3(0.0, 1.2, 0.0))
	await _shot("x_turn_head_leads")
	await _frames(60)
	await _shot("x_turned")
	# In front of the lit wall: the see-through reads against it.
	shade.global_position = Vector3(0.0, 0.0, -2.2)
	shade.face(Vector3(0.0, 1.6, 2.0))
	await _frames(90)
	_look(Vector3(0.6, 1.3, 0.2), Vector3(0.0, 1.0, -2.2))
	await _shot("x_against_wall")
	# A pane of see-through glazing between the camera and her (the sorting
	# risk: her colour, drawn after, may paint over it).
	shade.global_position = Vector3.ZERO
	shade.face(Vector3(0.0, 1.6, 2.0))
	var pane := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(0.5, 0.8)
	var glass := StandardMaterial3D.new()
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glass.albedo_color = Color(0.3, 0.55, 0.9, 0.45)
	quad.material = glass
	pane.mesh = quad
	add_child(pane)
	pane.global_position = Vector3(-0.15, 1.2, 0.7)
	await _frames(90)
	_look(Vector3(0.0, 1.3, 2.0), Vector3(0.0, 1.15, 0.0))
	await _shot("x_sort_glass")
	pane.queue_free()

	# Gutter, a few moments apart.
	shade.global_position = Vector3.ZERO
	shade.set_resting(&"gutter")
	await _frames(60)
	_look(Vector3(0.0, 1.35, 2.0), Vector3(0.0, 0.95, 0.0))

	for i in 4:
		await _frames(7)
		await _shot("x_gutter_%d" % i)


## Night, one lamp: a lantern on a post to her right, a wall behind her and
## stone underfoot.
func _night() -> void:
	var world := WorldEnvironment.new()
	world.environment = RetroScript.night_environment()
	add_child(world)
	_box(Vector3(0.0, -0.5, 0.0), Vector3(16.0, 1.0, 16.0), Color(0.3, 0.3, 0.31))
	_box(Vector3(0.0, 2.0, -3.0), Vector3(8.0, 4.0, 0.4), Color(0.42, 0.43, 0.46))
	_box(Vector3(1.7, 1.35, -0.9), Vector3(0.1, 2.7, 0.1), Color(0.12, 0.11, 0.1))
	_box(Vector3(1.45, 2.68, -0.9), Vector3(0.5, 0.05, 0.05), Color(0.12, 0.11, 0.1))
	var lantern := MeshInstance3D.new()
	var cube := BoxMesh.new()
	cube.size = Vector3(0.18, 0.24, 0.18)
	var glass := StandardMaterial3D.new()
	glass.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glass.albedo_color = Color(1.0, 0.85, 0.6) * 2.0
	cube.material = glass
	lantern.mesh = cube
	lantern.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(lantern)
	lantern.position = Vector3(1.25, 2.52, -0.9)
	var lamp := OmniLight3D.new()
	lamp.light_color = Color(1.0, 0.82, 0.6)
	lamp.light_energy = 2.2
	lamp.omni_range = 7.0
	lamp.shadow_enabled = true
	add_child(lamp)
	lamp.position = Vector3(1.2, 2.35, -0.75)


func _look(from: Vector3, at: Vector3) -> void:
	camera.global_position = from
	camera.look_at(at)


func _box(center: Vector3, size: Vector3, colour: Color) -> void:
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	var mesh := MeshInstance3D.new()
	var cube := BoxMesh.new()
	cube.size = size
	var material := StandardMaterial3D.new()
	material.albedo_color = colour
	cube.material = material
	mesh.mesh = cube
	body.add_child(mesh)
	add_child(body)
	body.global_position = center


func _shot(label: String) -> void:
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(_out + label + ".png")


func _frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame
