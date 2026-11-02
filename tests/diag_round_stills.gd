extends Node3D
## Stills of each round's shot from the real game, windowed:
##   Godot --path . --resolution 1152x648 res://tests/diag_round_stills.tscn -- --out=<folder>

const GYM := preload("res://maps/hunt_gym.tscn")
const EyeScript := preload("res://scripts/Monsters/FloatingEye.gd")

var out := "user://"
var p: CharacterBody3D
## The eye held still, and the view on it, so each shot lands.
var eye: CharacterBody3D
const PIN := Vector3(1.0, 2.2, -21.0)


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.trim_prefix("--out=")

	var gym: Node3D = GYM.instantiate()
	add_child(gym)
	await _frames(100)
	p = gym.player
	p.invulnerable = true
	gym.wave_now = 3
	CityState.job.read_slot("eye_clue")
	gym.kit_table.piece(&"copal").frob(p)
	await _frames(5)
	p.teleport(Transform3D(Basis.IDENTITY, Vector3(-2, 1.05, -14)))
	p.inventory.ammo[&"copal_rounds"] = 60
	await _frames(60)
	eye = EyeScript.new()
	eye.seed_value = 5
	eye.position = PIN
	add_child(eye)
	eye.next_swoop_in = 100.0
	await _frames(20)
	await _shoot("lead")
	await _frames(40)
	Input.action_press("switch_round")
	await _frames(2)
	Input.action_release("switch_round")
	await _frames(4)
	await _shot("switched")
	await _shoot("copal")
	await _frames(40)
	await _shot("copal_smoked")
	await _frames(40)
	await _shot("copal_cloud")
	get_tree().quit()


func _shoot(name_of: String) -> void:
	await _until_ready()
	await _frames(3)
	Input.action_press("throw")
	await _frames(1)
	Input.action_release("throw")
	await _shot(name_of + "_1")
	await _frames(1)
	await _shot(name_of + "_2")
	await _frames(5)
	await _shot(name_of + "_3")


func _physics_process(_delta: float) -> void:
	if is_instance_valid(eye):
		eye.global_position = PIN
		eye.velocity = Vector3.ZERO
		_face(eye)


func _until_ready() -> void:
	var left := 400

	while left > 0 and not p.revolver.ready_to_fire():
		left -= 1
		await get_tree().physics_frame


func _face(target: Node3D) -> void:
	var way: Vector3 = (target.global_position - p.camera.global_position).normalized()
	p.rotation.y = atan2(-way.x, -way.z)
	p.neck.rotation = Vector3(asin(way.y), 0.0, 0.0)


func _shot(name_of: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out.path_join("round_" + name_of + ".png"))
	print("STILL ", name_of)


func _frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame
