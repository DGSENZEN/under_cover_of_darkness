extends Node3D
## Windowed visual QA: the revolver in hand, a frame each: at rest, at the top
## of a shot's kick, both hands on it, rolled to the gate mid-reload, the
## thumb at the hammer's nose, the chambers checked (Tab), the tome in the
## left hand, and the bare left hand casting. Run with the
## new arms:
## FP_ARMS=new Godot --fixed-fps 60 --resolution 960x540 --path . res://tests/visual/stage_revolver.tscn -- --out=/tmp/revolver

const PLAYER := preload("res://Player.tscn")
const HANDHOLD := preload("res://scripts/PlayerUtils/Handhold.gd")
const PROPS := preload("res://scripts/Interaction/Props.gd")

var _out := "/tmp/revolver/"
var player: CharacterBody3D


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.trim_prefix("--out=").trim_suffix("/") + "/"
	DirAccess.make_dir_recursive_absolute(_out)
	AudioServer.set_bus_mute(0, true)
	_light()
	_box(Vector3(0, -0.5, 0), Vector3(120, 1, 40), Color(0.35, 0.33, 0.3))
	_box(Vector3(0, 1.5, -8), Vector3(8, 3, 0.4), Color(0.55, 0.3, 0.25))
	player = PLAYER.instantiate()
	add_child(player)
	player.debug_traversal = false
	player.reload_on_death = false
	player.invulnerable = true
	var hud := player.get_node_or_null("HUD")
	if hud != null:
		hud.visible = false
	await _frames(10)
	PROPS.give_revolver(player)
	player.inventory.select_by_id(&"revolver")
	await _place(Vector3(0, 0.1, 0))
	await _frames(60)
	await _shot("rest")

	# The top of the kick, a frame after the shot.
	Input.action_press("throw")
	await _frames(3)
	Input.action_release("throw")
	await _shot("recoil")
	await _frames(12)
	await _shot("recoil_settling")
	await _frames(40)

	player.revolver.set_braced(true)
	await _frames(40)
	await _shot("braced")
	player.revolver.set_braced(false)
	await _frames(40)

	# Mid-reload: the gate open, rounds going in.
	Input.action_press("reload")
	await _frames(2)
	Input.action_release("reload")
	await _frames(30)
	await _shot("gate")
	await _frames(80)

	player.revolver.flip_barrel()
	await _frames(4)
	await _shot("flip")
	await _frames(30)

	player.hand.set_checking(true)
	await _frames(30)
	await _shot("check")
	player.hand.set_checking(false)
	await _frames(10)

	# The left hand: the tome out, then the bare hand mid-cast.
	player.caster.select(&"empower")
	await _frames(40)
	await _shot("tome")
	player.caster.select(&"shard")
	await _frames(20)
	Input.action_press("block")
	await _frames(15)
	await _shot("cast")
	Input.action_release("block")
	await _frames(10)
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
	tube.top_radius = 0.045
	tube.bottom_radius = 0.045
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
