## Visual check, not a test: a torch on a wall put out (Torch.put_out: dark,
## a wisp of smoke), a guard at his post noticing it (GuardLife), going to it
## and lighting it again, his hand up to it (GuardHands.relight, GuardRig).
##   Godot --fixed-fps 60 --resolution 960x540 --path . res://tests/visual/stage_lights.tscn -- --out=/some/folder
extends Node3D

const PLAYER := preload("res://Player.tscn")
const GUARD := preload("res://Guard.tscn")
const Props := preload("res://scripts/Interaction/Props.gd")
const NavBakerScript := preload("res://scripts/AISystem/NavBaker.gd")
const TemperamentScript := preload("res://scripts/AISystem/Temperament.gd")
const TorchScript := preload("res://scripts/Visual/Torch.gd")
const Sfx := preload("res://scripts/Audio/Sfx.gd")

var out_dir := "user://lights/"
var camera: Camera3D


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.substr(6).trim_suffix("/") + "/"

	DirAccess.make_dir_recursive_absolute(out_dir)
	Sfx.volume_db = -60.0
	TemperamentScript.rolling = false
	var stone := Color(0.42, 0.4, 0.38)
	Props.block(self, Vector3(0, -0.5, 0), Vector3(40, 1, 40), Color(0.3, 0.29, 0.28))
	Props.block(self, Vector3(0, 1.5, -4.2), Vector3(10, 3, 0.4), stone)
	var torch: Node3D = TorchScript.new()
	torch.can_douse = true
	add_child(torch)
	torch.global_position = Vector3(1.5, 2.3, -3.75)
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.03, 0.03, 0.05)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.35, 0.38, 0.5)
	environment.ambient_light_energy = 0.3
	var world := WorldEnvironment.new()
	world.environment = environment
	add_child(world)
	var baker := NavigationRegion3D.new()
	baker.set_script(NavBakerScript)
	add_child(baker)
	var player: CharacterBody3D = PLAYER.instantiate()
	add_child(player)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	player.invulnerable = true
	player.reload_on_death = false
	player.global_position = Vector3(15, 1.05, 15)
	player.debug_light_level = 0.0
	camera = Camera3D.new()
	add_child(camera)
	camera.fov = 50
	camera.current = true
	camera.global_position = Vector3(5.5, 2.4, 2.5)
	camera.look_at(Vector3(0.5, 1.4, -3.0))
	await baker.baked

	var g: CharacterBody3D = GUARD.instantiate()
	g.debug_ai = false
	g.position = Vector3(-2, 0, 3)
	add_child(g)
	g._habits._wait = 999.0
	g._life._talk_rest = 999.0
	g.hearing_acuity = 0.0
	await _frames(40)
	await _shot("lights_00_burning")
	torch.put_out(player)
	var shots := 1

	for i in 900:
		await _frames(1)

		if i % 15 == 0 and shots < 50:
			var doing: StringName = g.activity()
			await _shot("lights_%02d_%s" % [shots, doing if doing != &"" else &"state%d" % int(g.state)])
			shots += 1

		if torch.lit and i % 15 == 0:
			print("t %.1f lit again" % (i / 60.0))
			break

	for i in 4:
		await _frames(15)
		await _shot("lights_%02d_after" % shots)
		shots += 1

	print("torch lit %s, guard state %d" % [torch.lit, int(g.state)])
	Sfx.silence()
	await _frames(3)
	get_tree().quit()


func _shot(shot_name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out_dir + shot_name + ".png")


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame
