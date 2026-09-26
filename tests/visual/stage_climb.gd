## Visual check, not a test: guards climbing and swimming (GuardClimb,
## GuardWater). Up onto a block, up a ladder, off a tower, across a gap, and
## after you through water: side on, a frame every so often.
##   Godot --fixed-fps 60 --resolution 960x540 --path . res://tests/visual/stage_climb.tscn -- --out=/some/folder
extends Node3D

const PLAYER := preload("res://Player.tscn")
const GUARD := preload("res://Guard.tscn")
const Props := preload("res://scripts/Interaction/Props.gd")
const NavBakerScript := preload("res://scripts/AISystem/NavBaker.gd")
const TemperamentScript := preload("res://scripts/AISystem/Temperament.gd")
const WaterScript := preload("res://scripts/Interaction/WaterVolume.gd")
const CLIMB := preload("res://scripts/PlayerUtils/ClimbVolume.gd")
const Sfx := preload("res://scripts/Audio/Sfx.gd")

var out_dir := "user://climb/"
var player: CharacterBody3D
var camera: Camera3D


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.substr(6).trim_suffix("/") + "/"

	DirAccess.make_dir_recursive_absolute(out_dir)
	Sfx.volume_db = -60.0
	TemperamentScript.rolling = false
	var stone := Color(0.4, 0.38, 0.36)
	Props.block(self, Vector3(0, -0.5, 0), Vector3(60, 1, 30), stone)
	Props.block(self, Vector3(49, -0.5, 0), Vector3(22, 1, 30), stone)
	Props.block(self, Vector3(34, -0.5, 10), Vector3(8, 1, 10), stone)
	Props.block(self, Vector3(34, -0.5, -10), Vector3(8, 1, 10), stone)
	Props.block(self, Vector3(34, -3.1, 0), Vector3(8, 1, 10), stone)
	Props.block(self, Vector3(-20, 0.75, -3), Vector3(3, 1.5, 3), stone)
	Props.block(self, Vector3(-10, 1.75, -3), Vector3(3, 3.5, 3), stone)
	var ladder := Area3D.new()
	ladder.set_script(CLIMB)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.2, 3.4, 0.7)
	shape.shape = box
	ladder.add_child(shape)
	add_child(ladder)
	ladder.global_position = Vector3(-10, 1.7, -1.15)
	Props.block(self, Vector3(2.5, 0.75, -3), Vector3(3, 1.5, 4), stone)
	Props.block(self, Vector3(7.4, 0.75, -3), Vector3(3, 1.5, 4), stone)
	WaterScript.build(self, Vector3(34, -1.55, 0), Vector3(8, 2.1, 10))
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(-0.8, 0.7, 0.0)
	add_child(sun)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.55, 0.55, 0.6)
	add_child(env)
	var baker := NavigationRegion3D.new()
	baker.set_script(NavBakerScript)
	add_child(baker)
	player = PLAYER.instantiate()
	add_child(player)
	player.invulnerable = true
	player.debug_light_level = 1.0
	player.global_position = Vector3(0, 1.05, 12)
	camera = Camera3D.new()
	add_child(camera)
	camera.fov = 50
	camera.current = true
	await baker.baked
	await _frames(5)

	await _scene("a_mantle", Vector3(-20, 0, 2.0), Vector3(-20, 2.55, -3.2), Vector3(-15.5, 1.4, -1.0), Vector3(-20, 1.0, -2.0), 14, 8)
	await _scene("b_ladder", Vector3(-10, 0, 3.0), Vector3(-10, 4.55, -3.4), Vector3(-5.0, 2.2, 1.5), Vector3(-10, 1.8, -1.5), 16, 12)
	await _scene("c_drop", Vector3(-10, 3.5, -3.6), Vector3(-10, 1.05, 3.5), Vector3(-5.0, 2.0, 1.5), Vector3(-10, 1.6, -1.5), 14, 8)
	await _scene("d_leap", Vector3(2.0, 1.5, -3), Vector3(7.6, 2.55, -3), Vector3(4.9, 2.0, 4.0), Vector3(4.9, 1.6, -3), 12, 6)
	await _scene("e_swim", Vector3(28, 0, 0), Vector3(35, 0.8, 0), Vector3(33, 1.2, 6.5), Vector3(32, -0.6, 0), 16, 12)
	get_tree().quit()


## `name`: a guard at `from` after you at `you` (the player placed there), seen
## from `eye` looking at `look`; `shots` frames, `gap` physics frames apart.
func _scene(scene_name: String, from: Vector3, you: Vector3, eye: Vector3, look: Vector3, shots: int, gap: int) -> void:
	for g in get_tree().get_nodes_in_group(&"guards"):
		g.queue_free()

	await _frames(2)
	player.velocity = Vector3.ZERO
	player.movement_state = 0
	player.global_position = you
	player.reset_physics_interpolation()
	var g: CharacterBody3D = GUARD.instantiate()
	g.debug_ai = false
	g.position = from
	add_child(g)
	g._attack_timer = 999.0
	g.lose_time = 999.0
	g._engage(player)
	camera.global_position = eye
	camera.look_at(look)
	await _frames(4)

	for i in shots:
		await _frames(gap)
		await _shot("%s_%02d_%s" % [scene_name, i, g.activity()])


func _shot(shot_name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out_dir + shot_name + ".png")


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame
