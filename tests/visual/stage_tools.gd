## Visual check, not a test: the tools on your belt, through your own eyes
## (PlayerFrob, ThrownTool.gd): a flash bomb thrown at a guard (the throw, the
## white-out, him with a hand over his eyes, and from the side); a water
## flask thrown at a torch on a wall (out); a lock picked (the ring closing).
##   Godot --fixed-fps 60 --resolution 960x540 --path . res://tests/visual/stage_tools.tscn -- --out=/some/folder
extends Node3D

const PLAYER := preload("res://Player.tscn")
const GUARD := preload("res://Guard.tscn")
const Props := preload("res://scripts/Interaction/Props.gd")
const NavBakerScript := preload("res://scripts/AISystem/NavBaker.gd")
const TemperamentScript := preload("res://scripts/AISystem/Temperament.gd")
const TorchScript := preload("res://scripts/Visual/Torch.gd")
const Sfx := preload("res://scripts/Audio/Sfx.gd")

var out_dir := "user://tools/"
var player: CharacterBody3D
var side: Camera3D


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.substr(6).trim_suffix("/") + "/"

	DirAccess.make_dir_recursive_absolute(out_dir)
	Sfx.volume_db = -60.0
	TemperamentScript.rolling = false
	var stone := Color(0.42, 0.4, 0.38)
	Props.block(self, Vector3(0, -0.5, 0), Vector3(60, 1, 60), Color(0.3, 0.29, 0.28))
	Props.block(self, Vector3(0, 1.5, -11), Vector3(12, 3, 0.4), stone)
	Props.block(self, Vector3(9, 1.5, -2), Vector3(0.4, 3, 8), stone)
	var torch: Node3D = TorchScript.new()
	torch.can_douse = true
	add_child(torch)
	torch.global_position = Vector3(8.6, 2.3, -2)
	var lamp: Node3D = TorchScript.new()
	add_child(lamp)
	lamp.global_position = Vector3(-3, 2.6, -10.6)
	# A locked door, behind you.
	Props.block(self, Vector3(-2.75, 1.25, 6), Vector3(3.5, 2.5, 0.3), stone)
	Props.block(self, Vector3(2.75, 1.25, 6), Vector3(3.5, 2.5, 0.3), stone)
	var door := Props.door(self, Vector3(-0.5, 0, 6), 0.0, 1.0, 2.1, true, &"nokey", "cellar door")
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.03, 0.03, 0.05)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.35, 0.38, 0.5)
	environment.ambient_light_energy = 0.4
	var world := WorldEnvironment.new()
	world.environment = environment
	add_child(world)
	var baker := NavigationRegion3D.new()
	baker.set_script(NavBakerScript)
	add_child(baker)
	player = PLAYER.instantiate()
	add_child(player)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	player.invulnerable = true
	player.reload_on_death = false
	player.show_hud = true
	player.global_position = Vector3(0, 1.05, 0)
	side = Camera3D.new()
	add_child(side)
	side.fov = 45
	await baker.baked
	Props.give_tools(player)

	var g: CharacterBody3D = GUARD.instantiate()
	g.debug_ai = false
	g.position = Vector3(0.5, 0, -7)
	g.rotation.y = PI
	add_child(g)
	g._habits._wait = 999.0
	g._life._talk_rest = 999.0
	g.hearing_acuity = 0.0
	g._attack_timer = 999.0
	g.attack_cooldown = 999.0
	player.debug_light_level = 0.0

	# The flash bomb.
	player.inventory.select_by_id(&"flashbomb")
	await _frames(50)
	_aim(g.global_position + Vector3(0, 0.2, 1.2))
	await _frames(3)
	await _shot("tools_00_flash_in_hand")
	Input.action_press("throw")
	await _frames(2)
	Input.action_release("throw")

	for i in 7:
		await _frames(3)
		await _shot("tools_%02d_flash_throw" % (1 + i))

	for i in 6:
		await _frames(12)
		await _shot("tools_%02d_flash_after" % (8 + i))

	print("flash: blinded %s (%.1f s), state %d" % [g.blinded(), g._blind, int(g.state)])
	side.current = true
	side.global_position = g.global_position + Vector3(2.2, 1.7, 1.6)
	side.look_at(g.global_position + Vector3(0, 1.4, 0))
	side.reset_physics_interpolation()
	await _frames(2)
	await _shot("tools_14_blinded_side")
	await _frames(20)
	await _shot("tools_15_blinded_side")
	side.current = false
	player.get_node("Neck/Camera3D").current = true

	# The water flask, at the torch.
	g.queue_free()
	player.inventory.select_by_id(&"waterflask")
	player.global_position = Vector3(3, 1.05, -2)
	await _frames(50)
	_aim(torch.global_position)
	await _frames(3)
	await _shot("tools_16_flask_in_hand")
	Input.action_press("throw")
	await _frames(2)
	Input.action_release("throw")

	for i in 6:
		await _frames(5)
		await _shot("tools_%02d_flask_throw" % (17 + i))

	print("flask: torch lit %s" % torch.lit)

	# The lock.
	player.global_position = Vector3(0, 1.05, 4.7)
	player.rotation.y = PI
	await _frames(20)
	_aim(door.to_global(Vector3(0.5, 1.05, 0.0)))
	await _frames(5)
	await _shot("tools_23_lock_prompt")
	Input.action_press("frob")
	await _frames(2)
	Input.action_release("frob")

	for i in 5:
		await _frames(40)
		await _shot("tools_%02d_picking" % (24 + i))

	print("lock: locked %s" % door.locked)
	Sfx.silence()
	await _frames(3)
	get_tree().quit()


func _aim(target: Vector3) -> void:
	var eye: Vector3 = player.get_node("Neck").global_position
	var d := target - eye
	player.rotation.y = atan2(-d.x, -d.z)
	player.get_node("Neck").rotation.x = atan2(d.y, Vector2(d.x, d.z).length())


func _shot(shot_name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out_dir + shot_name + ".png")


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame
