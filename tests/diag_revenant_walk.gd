extends Node3D
## A revenant at work, for Movie Maker, in light enough to judge how it moves: walking side on and from the front, each attack seen in full, surging,
## falling and rising, burning, dying.
##   Godot --path . --resolution 1280x720 --fixed-fps 60 --write-movie <out.avi> res://tests/diag_revenant_walk.tscn

const GYM := preload("res://maps/hunt_gym.tscn")
const RevenantScript := preload("res://scripts/Monsters/Revenant.gd")
const STATE: Dictionary = RevenantScript.State

var gym: Node3D
var camera: Camera3D
var one: CharacterBody3D
var p: CharacterBody3D


func _ready() -> void:
	gym = GYM.instantiate()
	add_child(gym)
	await _frames(60)
	gym.set_physics_process(false)

	for other in get_tree().get_nodes_in_group(&"monsters"):
		other.queue_free()

	p = gym.player
	p.invulnerable = true
	p.hud.visible = false
	Engine.time_scale = 1.0
	p.teleport(Transform3D(Basis.IDENTITY, Vector3(-5, 1.05, -6)))
	p.visible = false
	one = RevenantScript.new()
	one.position = Vector3(-5, 0, -30)
	gym.add_child(one)
	camera = Camera3D.new()
	gym.add_child(camera)
	camera.current = true
	camera.fov = 52.0
	var lit := OmniLight3D.new()
	lit.light_color = Color(0.85, 0.82, 0.72)
	lit.light_energy = 2.2
	lit.omni_range = 14.0
	lit.shadow_enabled = true
	gym.add_child(lit)
	await _frames(2)
	one._surge_in = 99.0
	one._attack_in = 99.0

	# Walking, side on.
	for i in 300:
		_watch(Vector3(-5.2, 1.3, 0.6), lit)
		await get_tree().physics_frame

	# From the front.
	for i in 180:
		_watch(Vector3(0.6, 1.5, 6.0), lit)
		await get_tree().physics_frame

	# Each blow, seen from the side of it: it stops where it is, you in reach.
	p.teleport(Transform3D(Basis.IDENTITY, one.global_position + Vector3(0, 1.05, 2.2)))

	for what in [STATE.SWIPE_WIND, STATE.RAKE_WIND, STATE.GRASP_WIND, STATE.SWIPE_WIND]:
		one._attack_in = 99.0
		one._enter(what)

		while one.state != STATE.WALK:
			one._attack_in = 99.0
			_watch(Vector3(2.8, 1.45, 3.4), lit)
			await get_tree().physics_frame

		for i in 50:
			one._attack_in = 99.0
			_watch(Vector3(2.8, 1.45, 3.4), lit)
			await get_tree().physics_frame

	# A surge.
	p.teleport(Transform3D(Basis.IDENTITY, one.global_position + Vector3(0, 1.05, 12.0)))
	one._surge_in = 0.0

	for i in 130:
		_watch(Vector3(6.0, 1.5, 2.0), lit)
		await get_tree().physics_frame

	# Down, and up.
	one._surge_in = 99.0

	while not one.is_down():
		one.take_hit(55.0, p, &"bullet", one.global_position, Vector3.FORWARD)

	for i in 430:
		_watch(Vector3(3.6, 1.3, 2.6), lit)
		await get_tree().physics_frame

	# Burning, as it comes; and its end.
	one._attack_in = 99.0
	one.take_hit(5.0, p, &"fire", one.global_position, Vector3.BACK)

	for i in 180:
		_watch(Vector3(3.6, 1.5, 3.0), lit)
		await get_tree().physics_frame

	one.health = 1.0
	one.take_hit(5.0, p, &"fire", one.global_position, Vector3.BACK)

	for i in 200:
		_watch(Vector3(3.6, 1.5, 3.0), lit)
		await get_tree().physics_frame

	get_tree().quit()


func _watch(off: Vector3, lit: OmniLight3D) -> void:
	camera.global_position = one.global_position + off
	camera.look_at(one.global_position + Vector3(0, 1.1, 0) - one.global_basis.z * 0.5)
	lit.global_position = one.global_position + Vector3(1.5, 3.2, 3.0)


func _frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame
