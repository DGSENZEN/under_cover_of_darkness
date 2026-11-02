extends Node3D
## Stills of the ánimas' fight from the real game, windowed:
##   Godot --path . --resolution 1152x648 res://tests/diag_anima_stills.tscn -- --out=<folder> [--only=<part>]

const GYM := preload("res://maps/hunt_gym.tscn")
const AnimaScript := preload("res://scripts/Monsters/Anima.gd")

var out := "user://"
var only := ""
var gym: Node3D
var p: CharacterBody3D


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.trim_prefix("--out=")
		elif arg.begins_with("--only="):
			only = arg.trim_prefix("--only=")

	gym = GYM.instantiate()
	add_child(gym)
	await _frames(100)
	p = gym.player
	p.invulnerable = true
	gym.wave_now = 3
	p.teleport(Transform3D(Basis.IDENTITY, Vector3(-2, 1.05, -14)))
	await _frames(40)

	if only == "" or only == "burst":
		await _burst()

	get_tree().quit()


func _burst() -> void:
	for i in 6:
		var turn := float(i) * TAU / 6.0 + 0.2
		var e: CharacterBody3D = AnimaScript.new()
		e.form = [&"hands", &"face", &"torso"][i % 3]
		e.position = p.global_position + Vector3(cos(turn) * 4.0, 0.0, sin(turn) * 4.0)
		add_child(e)

	await _frames(30)
	Input.action_press("spell_4")
	await _frames(12)
	await _shot("burst_windup")
	await _frames(7)
	Input.action_release("spell_4")
	await _shot("burst_release")
	await _frames(6)
	await _shot("burst_ring")
	await _frames(40)
	await _shot("burst_after")


func _shot(name_of: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out.path_join("anima_" + name_of + ".png"))
	print("STILL ", name_of)


func _frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame
