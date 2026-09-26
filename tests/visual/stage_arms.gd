## Visual check, not a test: run it in a window and look at the screenshots.
##   Godot --fixed-fps 60 --resolution 1280x720 --path . res://tests/visual/stage_arms.tscn -- --out=/some/folder
extends Node3D
## Your own arms in the view: each weapon at rest and in a swing, the bow at
## rest and drawn, the purse, a ledge, a kick.

const PLAYER := preload("res://Player.tscn")
const Props := preload("res://scripts/Interaction/Props.gd")
const Sfx := preload("res://scripts/Audio/Sfx.gd")

var out_dir := "user://arms/"
var player: CharacterBody3D


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.substr(6).trim_suffix("/") + "/"

	Sfx.volume_db = -60.0
	DirAccess.make_dir_recursive_absolute(out_dir)
	var stone := Color(0.42, 0.4, 0.38)
	Props.block(self, Vector3(0, -0.5, 0), Vector3(80, 1, 80), Color(0.3, 0.29, 0.28))
	Props.block(self, Vector3(0, 2, -6), Vector3(12, 4, 0.4), stone)
	# A ledge to hang from.
	Props.block(self, Vector3(20, 1.8, -4.5), Vector3(4, 3.6, 3), stone)

	for at in [Vector3(-2, 3.0, -2), Vector3(2.5, 2.6, 1.0), Vector3(20, 3.6, -1.0)]:
		var light := OmniLight3D.new()
		light.light_color = Color(1.0, 0.8, 0.55)
		light.light_energy = 2.0
		light.omni_range = 9.0
		add_child(light)
		light.global_position = at

	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.05, 0.05, 0.07)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.45, 0.47, 0.55)
	environment.ambient_light_energy = 0.4
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
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
	player.inventory.add_belt_item(&"blackjack", "blackjack", Props.blackjack_mesh())
	await _frames(20)

	for weapon in [&"sword", &"dagger", &"blackjack"]:
		player.inventory.select_by_id(weapon)
		await _frames(40)
		await _shot("%s_rest" % weapon)
		Input.action_press("throw")
		await _frames(5)
		await _shot("%s_windup" % weapon)
		Input.action_release("throw")
		await _frames(4)
		await _shot("%s_strike" % weapon)
		await _frames(40)

	player.inventory.select_by_id(&"sword")
	await _frames(40)
	Input.action_press("block")
	await _frames(20)
	await _shot("sword_block")
	Input.action_release("block")
	await _frames(20)

	player.inventory.select_by_id(&"bow")
	await _frames(40)
	await _shot("bow_rest")
	Input.action_press("throw")
	await _frames(12)
	await _shot("bow_drawing")
	await _frames(40)
	await _shot("bow_drawn")
	Input.action_release("throw")
	await _frames(40)

	player.inventory.select_by_id(&"sword")
	await _frames(40)
	Input.action_press("inventory")
	await _frames(30)
	await _shot("purse")
	Input.action_release("inventory")
	await _frames(30)

	await _tap("kick")
	await _frames(5)
	await _shot("kick_chamber")
	await _frames(5)
	await _shot("kick_out")
	await _frames(30)

	# Up onto a ledge: hanging, both hands on the lip.
	player.global_position = Vector3(20, 1.05, -1.5)
	await _frames(20)
	Input.action_press("move_forward")
	await _frames(40)
	Input.action_press("jump")
	await _until(func(): return player.movement_state == 2, 120)
	Input.action_release("move_forward")
	Input.action_release("jump")
	await _frames(30)
	await _shot("hang")
	get_tree().quit()


func _shot(shot_name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out_dir + shot_name + ".png")


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
