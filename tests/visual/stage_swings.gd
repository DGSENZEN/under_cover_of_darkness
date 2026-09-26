## Visual check, not a test: every swing photographed every other frame.
##   Godot --fixed-fps 60 --resolution 960x540 --path . res://tests/visual/stage_swings.tscn -- --out=/folder [--weapon=dagger]
extends Node3D

const PLAYER := preload("res://Player.tscn")
const Props := preload("res://scripts/Interaction/Props.gd")
const Sfx := preload("res://scripts/Audio/Sfx.gd")

const FLICKS := {&"overhead": Vector2(0.0, -0.2), &"left": Vector2(0.2, 0.0), &"right": Vector2(-0.2, 0.0), &"thrust": Vector2(0.0, 0.2)}

var out_dir := "user://swings/"
var weapon: StringName = &"sword"
var player: CharacterBody3D
## --side: each shot also from the side, the arm itself in view (joints).
var side_view := false
var side_camera: Camera3D


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.substr(6).trim_suffix("/") + "/"
		if arg.begins_with("--weapon="):
			weapon = StringName(arg.substr(9))
		if arg == "--side":
			side_view = true

	Sfx.volume_db = -60.0
	DirAccess.make_dir_recursive_absolute(out_dir)
	Props.block(self, Vector3(0, -0.5, 0), Vector3(80, 1, 80), Color(0.3, 0.29, 0.28))
	Props.block(self, Vector3(0, 2, -6), Vector3(12, 4, 0.4), Color(0.42, 0.4, 0.38))

	for at in [Vector3(-2, 3.0, -2), Vector3(2.5, 2.6, 1.0)]:
		var light := OmniLight3D.new()
		light.light_color = Color(1.0, 0.82, 0.6)
		light.light_energy = 2.0
		light.omni_range = 9.0
		add_child(light)
		light.global_position = at

	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.05, 0.05, 0.07)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.5, 0.52, 0.6)
	environment.ambient_light_energy = 0.45
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var world := WorldEnvironment.new()
	world.environment = environment
	add_child(world)

	player = PLAYER.instantiate()
	add_child(player)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	player.invulnerable = true
	player.global_position = Vector3(0, 1.05, 0)
	Props.give_weapons(player)
	await _frames(10)
	player.inventory.select_by_id(weapon)
	await _frames(40)

	if side_view:
		side_camera = Camera3D.new()
		side_camera.cull_mask = 0xFFFFF
		side_camera.fov = 55.0
		add_child(side_camera)

	for direction in FLICKS.keys():
		await _swing(direction, false)

	await _swing(&"left", true)
	# Two in a row: the second from the other side.
	player.combat.add_look_motion(FLICKS[&"left"])
	Input.action_press("throw")
	await _frames(2)
	Input.action_release("throw")

	for i in 16:
		await _frames(2)

		if i == 4:
			Input.action_press("throw")
		if i == 6:
			Input.action_release("throw")

		await _shot("chain_%02d" % i)

	await _frames(40)
	get_tree().quit()


func _swing(direction: StringName, power: bool) -> void:
	var label := String(direction) + ("_power" if power else "")
	player.combat.add_look_motion(FLICKS[direction])
	Input.action_press("throw")

	if power:
		for i in 22:
			await _frames(2)

			if i % 6 == 5:
				await _shot("%s_charge_%02d" % [label, i])

		player.combat.add_look_motion(FLICKS[direction])
		Input.action_release("throw")
	else:
		await _frames(2)
		Input.action_release("throw")

	for i in 16:
		await _frames(2)
		await _shot("%s_%02d" % [label, i])

	await _frames(30)


func _shot(shot_name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out_dir + shot_name + ".png")

	if side_view:
		# From off your right shoulder, looking at your arm.
		var eye: Transform3D = player.camera.global_transform
		side_camera.global_position = eye * Vector3(0.75, 0.05, -0.1)
		side_camera.look_at(eye * Vector3(0.05, -0.2, -0.3), eye.basis.y)
		side_camera.current = true
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(out_dir + shot_name + "_side.png")
		player.camera.current = true


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame
