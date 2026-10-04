## Visual check, not a test: run it in a window and look at the screenshots.
##   Godot --fixed-fps 60 --resolution 1280x720 --path . res://tests/visual/stage_letter.tscn -- --out=/some/folder
extends Node3D
## The letter held up in both hands (the harbour's job): its front, its back
## of pencil notes, and in the dark.

const PLAYER := preload("res://Player.tscn")
const Props := preload("res://scripts/Interaction/Props.gd")
const Sfx := preload("res://scripts/Audio/Sfx.gd")

var out_dir := "user://letter/"
var player: CharacterBody3D
var light: OmniLight3D


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.substr(6).trim_suffix("/") + "/"

	Sfx.volume_db = -60.0
	DirAccess.make_dir_recursive_absolute(out_dir)
	Props.block(self, Vector3(0, -0.5, 0), Vector3(80, 1, 80), Color(0.3, 0.29, 0.28))
	Props.block(self, Vector3(0, 2, -6), Vector3(12, 4, 0.4), Color(0.42, 0.4, 0.38))
	light = OmniLight3D.new()
	light.light_color = Color(1.0, 0.8, 0.55)
	light.light_energy = 2.0
	light.omni_range = 9.0
	add_child(light)
	light.global_position = Vector3(-1.5, 2.6, -1.0)
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

	CityState.begin()
	CityState.job.arrive(&"harbour")

	for note in CityState.job.book["notes"].keys():
		CityState.job.learn(note)

	player = PLAYER.instantiate()
	add_child(player)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	player.invulnerable = true
	player.reload_on_death = false
	player.global_position = Vector3(0, 1.05, 0)
	Props.give_blackjack(player)
	await _frames(30)
	await _shot("blackjack_rest")
	player.frob.open_letter()
	await _frames(40)
	await _shot("letter_front")
	player.hand.turn_page()
	await _frames(10)
	await _shot("letter_back")
	player.hand.turn_page()
	await _frames(10)
	await _shot("letter_back_2")
	light.visible = false
	environment.ambient_light_energy = 0.05
	await _frames(10)
	await _shot("letter_dark")
	get_tree().quit()


func _shot(shot_name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out_dir + shot_name + ".png")


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame
