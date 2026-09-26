## Visual check: hands on the world. Hangs from a ledge, mantles, climbs a
## ladder and a rope, and saves screenshots (see stage_combat.gd for options).
extends Node3D

const PLAYER := preload("res://Player.tscn")
const Props := preload("res://scripts/Interaction/Props.gd")
const Sfx := preload("res://scripts/Audio/Sfx.gd")
const CLIMB := preload("res://scripts/PlayerUtils/ClimbVolume.gd")
const ROPE := preload("res://scripts/PlayerUtils/VerletRope.gd")
const TorchScript := preload("res://scripts/Visual/Torch.gd")
const RetroScript := preload("res://scripts/Visual/Retro.gd")
const OUT_DEFAULT := "user://shots/"

var out_dir := OUT_DEFAULT
var player: CharacterBody3D


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.substr(6).trim_suffix("/") + "/"

	Sfx.volume_db = -60.0
	DirAccess.make_dir_recursive_absolute(out_dir)
	var stone := Color(0.45, 0.43, 0.4)
	Props.block(self, Vector3(0, -0.5, 0), Vector3(80, 1, 80), Color(0.3, 0.29, 0.28))
	Props.block(self, Vector3(0, 1.8, -4.5), Vector3(4, 3.6, 3), stone)      # a 3.6 m wall to hang from
	Props.block(self, Vector3(10, 0.55, -2.0), Vector3(3, 1.1, 1.0), stone)   # a waist-high ledge to mantle
	Props.block(self, Vector3(20, 2.5, -4.5), Vector3(3, 5, 3), stone)       # a wall with a ladder
	var ladder := Area3D.new()
	ladder.set_script(CLIMB)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.4, 5.0, 0.7)
	shape.shape = box
	ladder.add_child(shape)
	add_child(ladder)
	ladder.global_position = Vector3(20, 2.5, -2.65)
	var rope := Area3D.new()
	rope.set_script(ROPE)
	rope.length = 6.0
	add_child(rope)
	rope.global_position = Vector3(30, 7.0, -3.0)

	for at in [Vector3(-2, 3.4, -2.5), Vector3(10, 2.5, 0.5), Vector3(20, 3.5, -1.5), Vector3(30, 3.0, 0.0)]:
		var torch: Node3D = TorchScript.new()
		add_child(torch)
		torch.global_position = at

	var world := WorldEnvironment.new()
	world.environment = RetroScript.night_environment(Color(0.36, 0.4, 0.55), 0.35)
	add_child(world)

	player = PLAYER.instantiate()
	add_child(player)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	player.invulnerable = true
	Props.give_weapons(player)
	player.inventory.select_by_id(&"sword")
	await _frames(40)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	# A hang: jump at the wall and grab the top.
	await _place(Vector3(0, 1.05, -1.5))
	Input.action_press("move_forward")
	await _frames(40)
	Input.action_press("jump")
	await _until(func(): return player.movement_state == 2, 120)
	_release_all()
	await _frames(30)
	await _shot("t01_hang")
	player.get_node("Neck").rotation.x = 0.35
	await _frames(10)
	await _shot("t02_hang_look_up")
	_release_all()
	await _frames(10)

	# A mantle, caught mid-move.
	await _place(Vector3(10, 1.05, 0.0))
	Input.action_press("move_forward")
	await _frames(15)
	await _tap("jump")
	await _until(func(): return player.movement_state == 1, 60)
	await _frames(8)
	await _shot("t03_mantle")
	await _frames(60)
	_release_all()

	# Up a ladder.
	await _place(Vector3(20, 1.05, 0.0))
	Input.action_press("move_forward")
	await _until(func(): return player.movement_state == 3, 180)
	await _frames(40)
	await _shot("t04_ladder")
	_release_all()
	await _frames(10)

	# A rope.
	await _place(Vector3(30, 1.05, 0.5))
	Input.action_press("move_forward")
	await _until(func(): return player.movement_state == 3, 180)
	await _frames(30)
	player.get_node("Neck").rotation.x = 0.4
	await _frames(10)
	await _shot("t05_rope")
	_release_all()
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
	for a in ["move_forward", "move_back", "move_left", "move_right", "jump", "sprint", "crouch"]:
		Input.action_release(a)


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
