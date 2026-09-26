## Visual check, not a test: men begging for their lives (GuardMercy). One
## badly hurt, on his knees; one whole, on his feet; each broken, with you in
## front of him, then from the side as he goes down and gets up.
##   Godot --fixed-fps 60 --resolution 960x540 --path . res://tests/visual/stage_mercy.tscn -- --out=/some/folder
extends Node3D

const PLAYER := preload("res://Player.tscn")
const GUARD := preload("res://Guard.tscn")
const Props := preload("res://scripts/Interaction/Props.gd")
const NavBakerScript := preload("res://scripts/AISystem/NavBaker.gd")
const TemperamentScript := preload("res://scripts/AISystem/Temperament.gd")
const Sfx := preload("res://scripts/Audio/Sfx.gd")

var out_dir := "user://mercy/"
var player: CharacterBody3D


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.substr(6).trim_suffix("/") + "/"

	DirAccess.make_dir_recursive_absolute(out_dir)
	Sfx.volume_db = -60.0
	TemperamentScript.rolling = false
	Props.block(self, Vector3(0, -0.5, 0), Vector3(60, 1, 60), Color(0.4, 0.38, 0.36))
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
	player.global_position = Vector3(0, 1.05, 0)
	await baker.baked
	await _frames(5)

	var kneeler: CharacterBody3D = await _beggar(Vector3(-1.2, 0, 2.4), 0.3)
	var stander: CharacterBody3D = await _beggar(Vector3(1.2, 0, 2.4), 1.0)
	var camera := Camera3D.new()
	add_child(camera)
	camera.fov = 50
	camera.current = true
	# Off your shoulder, looking at them as you do.
	camera.global_position = Vector3(-2.6, 1.5, -0.6)
	camera.look_at(Vector3(-0.4, 0.7, 2.4))

	for i in 6:
		await _frames(12)
		await _shot("a_front_%d_%s_%s" % [i, kneeler.activity(), stander.activity()])

	# From the side.
	camera.global_position = Vector3(5.5, 1.3, 2.4)
	camera.look_at(Vector3(0, 0.7, 2.4))
	await _frames(20)
	await _shot("b_side_%s_%s" % [kneeler.activity(), stander.activity()])

	# You walk off: up and away.
	player.global_position = Vector3(0, 1.05, -12)
	player.reset_physics_interpolation()

	for i in 8:
		await _frames(15)
		await _shot("c_let_go_%d_%s_%s" % [i, kneeler.activity(), stander.activity()])

	get_tree().quit()


## A watchman broken and caught, at `health` of his whole.
func _beggar(at: Vector3, health: float) -> CharacterBody3D:
	var g: CharacterBody3D = GUARD.instantiate()
	g.archetype = &""
	g.debug_ai = false
	g.position = at
	add_child(g)
	g.health = g.max_health * health
	g._attack_timer = 999.0
	g._engage(player)
	await _frames(5)
	g._fighter.squad.morale = -2.0
	g._fighter.squad._last_think = -100.0
	return g


func _shot(shot_name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out_dir + shot_name + ".png")


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame
