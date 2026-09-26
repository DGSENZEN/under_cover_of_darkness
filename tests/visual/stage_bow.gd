## Visual check, not a test: the bow in your hands, through a whole shot.
##   Godot --fixed-fps 60 --resolution 960x540 --path . res://tests/visual/stage_bow.tscn -- --out=/some/folder
##   Each moment twice: through your eye, and from beside you (a camera that
##   sees the view's small world from the side, to judge the pose).
extends Node3D

const PLAYER := preload("res://Player.tscn")
const Props := preload("res://scripts/Interaction/Props.gd")
const Sfx := preload("res://scripts/Audio/Sfx.gd")
const Layers := preload("res://scripts/Visual/Layers.gd")

var out_dir := "user://bow/"
var player: CharacterBody3D
var side: Camera3D


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.substr(6).trim_suffix("/") + "/"

	Sfx.volume_db = -60.0
	DirAccess.make_dir_recursive_absolute(out_dir)
	Props.block(self, Vector3(0, -0.5, 0), Vector3(80, 1, 80), Color(0.32, 0.31, 0.3))
	Props.block(self, Vector3(0, 1.5, -14), Vector3(10, 3, 0.4), Color(0.45, 0.42, 0.4))
	# A mark to aim at.
	Props.block(self, Vector3(0, 1.6, -13.7), Vector3(0.5, 0.5, 0.1), Color(0.7, 0.2, 0.15))

	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(-0.7, 0.4, 0.0)
	add_child(sun)
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.08, 0.08, 0.1)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.5, 0.5, 0.55)
	environment.ambient_light_energy = 0.6
	var world := WorldEnvironment.new()
	world.environment = environment
	add_child(world)

	player = PLAYER.instantiate()
	add_child(player)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	player.invulnerable = true
	player.reload_on_death = false
	player.global_position = Vector3(0, 1.05, 0)
	Props.give_weapons(player)
	await _frames(20)
	player.inventory.select_by_id(&"bow")
	await _frames(50)

	# Beside you, level with your eye, looking across at your hands.
	side = Camera3D.new()
	side.cull_mask = 0xFFFFF
	side.fov = 45
	add_child(side)

	await _both("a_rest")
	Input.action_press("throw")

	for i in range(7):
		await _frames(6)
		await _both("b_draw_%d" % i)

	await _frames(30)
	await _both("c_drawn")
	Input.action_release("throw")
	await _frames(1)
	await _both("d_loose_01")
	await _frames(3)
	await _both("d_loose_04")
	await _frames(8)
	await _both("d_loose_12")
	await _frames(20)
	await _both("d_loose_32")
	await _frames(40)
	await _both("e_after")
	Input.action_press("move_forward")
	Input.action_press("sprint")
	await _frames(40)
	await _both("f_sprint")
	Input.action_release("move_forward")
	Input.action_release("sprint")
	get_tree().quit()


## Through your eye, then from beside you.
func _both(shot_name: String) -> void:
	var eye: Camera3D = player.camera
	eye.current = true
	await _shot(shot_name + "_eye")
	var at: Vector3 = eye.global_position
	var right: Vector3 = eye.global_basis.x
	var ahead: Vector3 = -eye.global_basis.z
	side.global_position = at + right * 0.9 + ahead * 0.25 + Vector3.UP * 0.05
	side.look_at(at + ahead * 0.35 + Vector3.DOWN * 0.08)
	side.current = true
	await _shot(shot_name + "_side")
	eye.current = true


func _shot(shot_name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out_dir + shot_name + ".png")


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame
