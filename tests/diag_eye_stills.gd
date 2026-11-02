extends Node3D
## Stills of the floating eye up close in each of its states, from the real game:
##   Godot --path . --resolution 1152x648 res://tests/diag_eye_stills.tscn -- --out=<folder>

const GYM := preload("res://maps/hunt_gym.tscn")
const EyeScript := preload("res://scripts/Monsters/FloatingEye.gd")

var out := "user://"
var p: CharacterBody3D
var e: CharacterBody3D


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.trim_prefix("--out=")

	var gym: Node3D = GYM.instantiate()
	add_child(gym)
	await _frames(100)
	p = gym.player
	p.invulnerable = true
	p.teleport(Transform3D(Basis.IDENTITY, Vector3(-11, 1.05, -16)))
	gym.wave_now = 1
	await _frames(30)
	e = EyeScript.new()
	e.seed_value = 77
	add_child(e)
	e.next_swoop_in = 100.0
	e.state = e.State.CIRCLE
	await _hold(2.4, 0.0)
	await _shot("rest")
	e.process_mode = Node.PROCESS_MODE_DISABLED
	var was: Vector3 = e.global_position
	e.global_position = p.camera.global_position + Vector3(0.0, -0.05, -1.05)
	e.body.global_position = e.global_position
	await _frames(3)
	await _shot("close")
	e.global_position = was
	e.process_mode = Node.PROCESS_MODE_INHERIT
	e.take_hit(30.0, p, &"bullet", e.global_position + Vector3(0.1, 0.1, 0.2), Vector3.FORWARD)
	await _frames(3)
	await _shot("hit")
	await _hold(1.4, 0.0)
	await _shot("hurt_after")
	e.next_swoop_in = 0.0
	e.state = e.State.CIRCLE
	await _until_tell()
	await _hold_tell()
	await _shot("tell")
	e.state = e.State.CIRCLE
	e.next_swoop_in = 100.0
	await _hold(0.6, 0.0)
	e.limpia(p)
	await _hold(1.0, 0.0, false)
	await _shot("shut")
	await _hold(3.5, 0.0, false)
	e.state = e.State.CIRCLE
	await _hold(0.1, 0.0)
	e.process_mode = Node.PROCESS_MODE_DISABLED
	e.body.global_position = e.global_position
	# The crown turned away, to see its side and its back.
	e.body.rotate_y(1.3)
	await _frames(3)
	await _shot("from_side")
	e.body.rotate_y(1.5)
	await _frames(3)
	await _shot("from_behind")
	e.process_mode = Node.PROCESS_MODE_INHERIT
	await _hold(0.3, 0.0)
	e.take_hit(5000.0, p, &"blast", e.global_position, Vector3.FORWARD)
	await _frames(5)
	await _shot("burst")
	await _frames(70)
	await _shot("fallen")
	get_tree().quit(0)


## Keeps it 2 m in front of the player, turned `round` radians about them.
func _hold(seconds: float, round_by: float, keep_state := true) -> void:
	var was := Time.get_ticks_msec()
	var at: Vector3 = p.camera.global_position + Basis(Vector3.UP, round_by) * Vector3(0.0, 0.0, -2.0)

	for i in int(seconds * 60.0):
		e.global_position = at
		await get_tree().physics_frame


func _until_tell() -> void:
	var at: Vector3 = p.camera.global_position + Vector3(0.0, 0.0, -2.0)

	for i in 200:
		e.global_position = at
		e.statuses.clear(&"exposed")
		e.next_swoop_in = 0.0
		await get_tree().physics_frame

		if e.state == e.State.TELL:
			return


func _hold_tell() -> void:
	var at: Vector3 = p.camera.global_position + Vector3(0.0, 0.0, -2.0)

	for i in 24:
		e.global_position = at
		await get_tree().physics_frame


func _shot(name_of: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out.path_join("eye_" + name_of + ".png"))
	print("STILL ", name_of, " state ", e.state, " lids ", e.body.lids, " pupil ", e.body.pupil)


func _frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame
