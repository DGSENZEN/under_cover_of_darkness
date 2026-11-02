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

	if only == "" or only == "drain":
		await _drain()

	get_tree().quit()


func _drain() -> void:
	var spots := [Vector3(-0.9, 0.5, -0.3), Vector3(0.9, 0.5, -0.3), Vector3(0.0, 0.5, 1.0)]
	var forms := [&"face", &"torso", &"hands"]
	var on: Array = []

	for i in 3:
		var e: CharacterBody3D = AnimaScript.new()
		e.form = forms[i]
		e.position = p.global_position + spots[i]
		add_child(e)
		await _frames(1)
		e.put_on_you()
		on.append(e)
		await _frames(70)
		await _shot("drain_%d" % (i + 1))

	p.statuses.apply(&"evil_eye", 40.0)
	await _frames(70)
	await _shot("drain_with_curse")
	p.statuses.clear(&"evil_eye")
	await _frames(70)
	p.leech.free_all()
	await _frames(4)
	await _shot("drain_released")


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
