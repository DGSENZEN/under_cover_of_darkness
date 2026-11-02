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

	if only == "" or only == "hands":
		await _hands()

	if only == "" or only == "burst":
		await _burst()

	if only == "" or only == "drain":
		await _drain()

	get_tree().quit()


## No curse in these: the drain alone, in a gulp and between gulps.
func _drain() -> void:
	var spots := [Vector3(-0.9, 0.5, -0.3), Vector3(0.9, 0.5, -0.3), Vector3(0.0, 0.5, 1.0)]
	var on: Array = []

	for i in 3:
		var e: CharacterBody3D = AnimaScript.new()
		e.form = &"hands"
		e.position = p.global_position + spots[i]
		add_child(e)
		await _frames(1)
		e.put_on_you()
		on.append(e)
		await _until_gulp()
		await _frames(4)
		await _shot("drain_%d_gulp" % (i + 1))
		await _frames(12)
		await _shot("drain_%d_raked" % (i + 1))
		await _frames(14)
		await _shot("drain_%d_between" % (i + 1))

	await _until_wind_up()
	await _shot("drain_wind_up")
	p.power.power = 5.0
	await _frames(80)
	await _until_gulp()
	await _frames(10)
	await _shot("drain_will_gone")
	p.power.power = 100.0
	p.leech.free_all()
	await _frames(4)
	await _shot("drain_released")


func _until_wind_up() -> void:
	var left := 200

	while left > 0 and p.leech.coming() < 0.92:
		left -= 1
		await get_tree().physics_frame


func _until_gulp() -> void:
	await p.leech.gulped


var pinned: CharacterBody3D
var pin_at := Vector3.ZERO


func _physics_process(_delta: float) -> void:
	if is_instance_valid(pinned):
		pinned.global_position = pin_at


## The hands, held in place walking: in the room's light, close and at distance, and
## in the yard's.
func _hands() -> void:
	var e: CharacterBody3D = AnimaScript.new()
	e.form = &"hands"
	e.position = Vector3(0, 0.3, -30)
	add_child(e)
	await _frames(2)
	pinned = e

	# The lit room, the player at its door, looking in.
	p.teleport(Transform3D(Basis(Vector3.UP, PI), Vector3(0, 1.05, -3.0)))
	pin_at = Vector3(0, 0.25, -1.4)
	e.state = e.State.RUSH
	await _frames(20)
	await _shot("hand_room_close")
	await _frames(9)
	await _shot("hand_room_close_2")
	p.teleport(Transform3D(Basis(Vector3.UP, PI), Vector3(1.4, 1.05, -2.4)))
	pin_at = Vector3(0.2, 0.25, -1.4)
	await _frames(11)
	await _shot("hand_room_side")
	p.teleport(Transform3D(Basis(Vector3.UP, PI * 1.5), Vector3(-1.9, 1.05, -1.0)))
	pin_at = Vector3(0.0, 0.25, -1.0)
	p.neck.rotation.x = -0.25
	await _frames(13)
	await _shot("hand_room_profile")
	p.neck.rotation.x = 0.0
	# The yard, at fight distance, and close.
	p.teleport(Transform3D(Basis.IDENTITY, Vector3(-2, 1.05, -14)))
	pin_at = Vector3(-1, 0.25, -20)
	await _frames(14)
	await _shot("hand_yard_far")
	pin_at = Vector3(-1.6, 0.25, -16)
	await _frames(14)
	await _shot("hand_yard_near")
	pinned = null
	e.queue_free()
	await _frames(3)


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
