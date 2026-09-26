## Visual check: your hands on the world, frame by frame. A grab, a shimmy
## along the ledge, a mantle, a vault, a ladder, a rope, a crate.
##   Godot --fixed-fps 60 --resolution 960x540 --path . res://tests/visual/stage_hands.tscn -- --out=/folder
extends Node3D

const PLAYER := preload("res://Player.tscn")
const Props := preload("res://scripts/Interaction/Props.gd")
const Sfx := preload("res://scripts/Audio/Sfx.gd")
const CLIMB := preload("res://scripts/PlayerUtils/ClimbVolume.gd")
const ROPE := preload("res://scripts/PlayerUtils/VerletRope.gd")
const TorchScript := preload("res://scripts/Visual/Torch.gd")

var out_dir := "user://hands/"
var player: CharacterBody3D


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.substr(6).trim_suffix("/") + "/"

	Sfx.volume_db = -60.0
	DirAccess.make_dir_recursive_absolute(out_dir)
	var stone := Color(0.5, 0.48, 0.44)
	Props.block(self, Vector3(0, -0.5, 0), Vector3(120, 1, 80), Color(0.3, 0.29, 0.28))
	Props.block(self, Vector3(0, 1.8, -4.5), Vector3(6, 3.6, 3), stone)
	Props.block(self, Vector3(10, 0.55, -2.0), Vector3(3, 1.1, 1.0), stone)
	Props.block(self, Vector3(20, 0.45, -2.5), Vector3(3, 0.9, 0.4), stone)
	Props.block(self, Vector3(30, 2.5, -4.5), Vector3(3, 5, 3), stone)
	var ladder := Area3D.new()
	ladder.set_script(CLIMB)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.4, 5.0, 0.7)
	shape.shape = box
	ladder.add_child(shape)
	add_child(ladder)
	ladder.global_position = Vector3(30, 2.5, -2.65)
	var rope := Area3D.new()
	rope.set_script(ROPE)
	rope.length = 6.0
	add_child(rope)
	rope.global_position = Vector3(40, 7.0, -3.0)
	Props.crate(self, Vector3(50, 0.3, -1.4), 0.4, 2.0)

	for at in [Vector3(-2, 3.4, -1.5), Vector3(2, 3.4, -1.5), Vector3(10, 2.5, 0.5), Vector3(20, 2.5, 0.5), Vector3(30, 3.5, -1.5), Vector3(40, 3.0, 0.0), Vector3(50, 2.5, 0.5)]:
		var torch: Node3D = TorchScript.new()
		add_child(torch)
		torch.global_position = at

	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.06, 0.06, 0.08)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.5, 0.52, 0.6)
	environment.ambient_light_energy = 0.5
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var world := WorldEnvironment.new()
	world.environment = environment
	add_child(world)

	player = PLAYER.instantiate()
	add_child(player)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	player.invulnerable = true
	Props.give_weapons(player)
	player.inventory.select_by_id(&"sword")
	await _frames(40)

	# The grab, and the hang.
	await _place(Vector3(0, 1.05, -1.5))
	Input.action_press("move_forward")
	await _frames(40)
	Input.action_press("jump")
	for i in 40:
		await _frames(1)
		if player.movement_state != 0 and i % 4 == 0:
			await _shot("a_grab_%02d" % i)
	_release_all()
	await _frames(20)
	await _shot("b_hang")

	# Along the ledge.
	Input.action_press("move_right")
	for i in 48:
		await _frames(1)
		if i % 6 == 0:
			await _shot("c_shimmy_%02d" % i)
	_release_all()
	await _frames(10)

	# A mantle.
	await _place(Vector3(10, 1.05, 0.0))
	Input.action_press("move_forward")
	await _frames(15)
	await _tap("jump")
	for i in 40:
		await _frames(1)
		if player.movement_state == 1 and i % 3 == 0:
			await _shot("d_mantle_%02d" % i)
	_release_all()
	await _frames(30)

	# A vault over a low wall, at a run.
	await _place(Vector3(20, 1.05, 1.5))
	Input.action_press("move_forward")
	Input.action_press("sprint")
	await _frames(24)
	await _tap("jump")
	for i in 40:
		await _frames(1)
		if player.movement_state == 1 and i % 3 == 0:
			await _shot("e_vault_%02d" % i)
	_release_all()
	await _frames(30)

	# Up a ladder.
	await _place(Vector3(30, 1.05, 0.0))
	Input.action_press("move_forward")
	await _until(func(): return player.movement_state == 3, 180)
	for i in 60:
		await _frames(1)
		if i % 10 == 0:
			await _shot("f_ladder_%02d" % i)
	_release_all()
	await _frames(10)

	# A rope.
	await _place(Vector3(40, 1.05, 0.5))
	Input.action_press("move_forward")
	await _until(func(): return player.movement_state == 3, 180)
	player.get_node("Neck").rotation.x = 0.4
	for i in 60:
		await _frames(1)
		if i % 10 == 0:
			await _shot("g_rope_%02d" % i)
	_release_all()
	await _frames(10)

	# A crate, picked up.
	await _place(Vector3(50, 1.05, -0.4))
	player.get_node("Neck").rotation.x = -0.9
	await _frames(10)
	await _tap("frob")
	await _frames(30)
	player.get_node("Neck").rotation.x = -0.2
	await _frames(20)
	await _shot("h_carry")
	get_tree().quit()


func _place(at: Vector3) -> void:
	_release_all()
	player.movement_state = 0
	player.current_move = null
	player.current_climb = null
	player.velocity = Vector3.ZERO
	player.global_position = at
	player.rotation.y = 0.0
	player.get_node("Neck").rotation.x = 0.0
	player.reset_physics_interpolation()
	await _frames(20)


func _shot(shot_name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out_dir + shot_name + ".png")


func _release_all() -> void:
	for action in ["move_forward", "move_back", "move_left", "move_right", "jump", "sprint", "crouch", "frob"]:
		Input.action_release(action)


func _tap(action: String) -> void:
	Input.action_press(action)
	await _frames(2)
	Input.action_release(action)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _until(cond: Callable, max_frames: int) -> void:
	for i in max_frames:
		if cond.call():
			return

		await get_tree().physics_frame
