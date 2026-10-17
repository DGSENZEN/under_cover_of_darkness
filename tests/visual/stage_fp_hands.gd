extends Node3D
## Windowed visual QA: the first-person hands holding things, a frame each:
## hooked on a sill, wrapped round a drainpipe, pressing flat as they pull up
## (every frame of it, for a clip), and round the sword's grip. Run with the
## new arms:
## FP_ARMS=new Godot --fixed-fps 60 --resolution 960x540 --path . res://tests/visual/stage_fp_hands.tscn -- --out=/tmp/hands

const PLAYER := preload("res://Player.tscn")
const HANDHOLD := preload("res://scripts/PlayerUtils/Handhold.gd")
const PROPS := preload("res://scripts/Interaction/Props.gd")

var _out := "/tmp/hands/"
var player: CharacterBody3D


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.trim_prefix("--out=").trim_suffix("/") + "/"
	DirAccess.make_dir_recursive_absolute(_out)
	AudioServer.set_bus_mute(0, true)
	_light()
	_box(Vector3(0, -0.5, 0), Vector3(120, 1, 40), Color(0.35, 0.33, 0.3))
	player = PLAYER.instantiate()
	add_child(player)
	player.debug_traversal = false
	player.reload_on_death = false
	player.invulnerable = true
	var hud := player.get_node_or_null("HUD")
	if hud != null:
		hud.visible = false
	await _frames(10)

	# Hooked on a sill, looking at the hands and a little up at them.
	_box(Vector3(0, 4.5, -4.5), Vector3(4, 9, 3), Color(0.55, 0.3, 0.25))
	# A stone sill standing 20 cm out of the wall, held at its front edge.
	var sill := _hold(HANDHOLD.Kind.LEDGE, Vector3(0, 2.4, -2.8), 1.0)
	_box(Vector3(0, 2.36, -2.9), Vector3(1.4, 0.08, 0.2), Color(0.6, 0.6, 0.58))
	await _frames(2)
	await _hang_on(sill)
	await _frames(40)
	await _shot("hang_sill")
	player.neck.rotation.x = 0.35
	await _frames(10)
	await _shot("hang_sill_look_up")
	player._drop_from_hang()
	await _frames(60)

	# Round a drainpipe.
	_box(Vector3(20, 3, -4.5), Vector3(4, 6, 3), Color(0.55, 0.3, 0.25))
	# As the gym's: a 12 cm pipe, held on its front face.
	_hold(HANDHOLD.Kind.POLE, Vector3(20, 0, -2.9), 6.0)
	_pipe(Vector3(20, 3, -2.96), 6.0)
	await _frames(2)
	await _place(Vector3(20, 1.03, -1.6))
	Input.action_press("move_forward")
	var shot := 0
	for i in 160:
		await _frames(1)
		if player.movement_state == 3 and i % 20 == 0 and shot < 4:
			await _shot("pole_%d" % shot)
			shot += 1
	Input.action_release("move_forward")
	await _place(Vector3(30, 0.1, 0))
	await _frames(30)

	# Hanging, then pulling up onto a top: every frame.
	_box(Vector3(40, 1.2, -4.5), Vector3(4, 2.4, 3), Color(0.55, 0.3, 0.25))
	var lip := _hold(HANDHOLD.Kind.LEDGE, Vector3(40, 2.4, -3), 1.0)
	await _frames(2)
	await _hang_on(lip)
	await _frames(30)
	Input.action_press("jump")
	for i in 70:
		await _frames(1)
		await _shot("pullup_%03d" % i)
	Input.action_release("jump")
	await _place(Vector3(-20, 0.1, 0))
	await _frames(30)

	# The sword in hand.
	PROPS.give_weapons(player)
	player.inventory.select_by_id(&"sword")
	await _frames(90)
	await _shot("sword")
	player.neck.rotation.x = -0.4
	await _frames(10)
	await _shot("sword_look_down")
	# Looking right down at yourself: the coat's chest and the arms.
	player.inventory.select_by_id(&"")
	await _frames(40)
	player.neck.rotation.x = -1.3
	await _frames(10)
	await _shot("look_down")
	get_tree().quit()


func _light() -> void:
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(-0.9, 0.6, 0.0)
	sun.light_energy = 1.2
	add_child(sun)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.45, 0.5, 0.58)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.5, 0.52, 0.56)
	add_child(env)


## A drainpipe to see (a POLE hold has none of its own).
func _pipe(center: Vector3, height: float) -> void:
	var mesh := MeshInstance3D.new()
	var tube := CylinderMesh.new()
	tube.top_radius = 0.06
	tube.bottom_radius = 0.06
	tube.height = height
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.25, 0.27, 0.3)
	material.metallic = 0.6
	tube.material = material
	mesh.mesh = tube
	add_child(mesh)
	mesh.global_position = center


func _hold(kind: int, at: Vector3, length: float) -> Node3D:
	var hold: Node3D = HANDHOLD.new()
	hold.kind = kind
	hold.length = length
	add_child(hold)
	hold.global_position = at
	return hold


func _hang_on(hold: Node3D) -> void:
	var lip: float = hold.global_position.y
	var anchor: Vector3 = player.planner.hang_anchor(hold.global_position, Vector3.BACK, lip)
	await _place(anchor)
	player.global_position = anchor
	player._enter_hang(Vector3.BACK, lip, false, &"", hold)
	await _frames(2)


func _place(at: Vector3) -> void:
	player.teleport(Transform3D(Basis.IDENTITY, at))
	player._set_crouched(false)
	player.neck.rotation.x = 0.0
	await _frames(3)


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
	get_viewport().get_texture().get_image().save_png(_out + label + ".png")


func _frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame
