extends Node3D
## A revenant coming at someone who stands still, for Movie Maker: walk, surge, each attack, a fall and a rise.
##   Godot --path . --resolution 1280x720 --fixed-fps 60 --write-movie <out.avi> res://tests/diag_revenant_walk.tscn

const GYM := preload("res://maps/hunt_gym.tscn")
const RevenantScript := preload("res://scripts/Monsters/Revenant.gd")
const STATE: Dictionary = RevenantScript.State

var gym: Node3D
var camera: Camera3D
var one: CharacterBody3D


func _ready() -> void:
	gym = GYM.instantiate()
	add_child(gym)
	await _frames(60)
	gym.set_physics_process(false)

	for other in get_tree().get_nodes_in_group(&"monsters"):
		other.queue_free()

	var p: CharacterBody3D = gym.player
	p.invulnerable = true
	p.hud.visible = false
	p.teleport(Transform3D(Basis.IDENTITY, Vector3(-1, 1.05, -10)))
	p.visible = false
	one = RevenantScript.new()
	one.position = Vector3(-1, 0, -22)
	gym.add_child(one)
	camera = Camera3D.new()
	gym.add_child(camera)
	camera.current = true
	camera.fov = 58.0
	await _frames(2)

	# Side on, moving with it: how it walks.
	one._surge_in = 99.0

	for i in 240:
		_follow(Vector3(5.2, 1.5, 0.0))
		await get_tree().physics_frame

	one._surge_in = 0.0

	for i in 130:
		_follow(Vector3(5.6, 1.5, 1.0))
		await get_tree().physics_frame

	# From where you stand: what it does to you.
	one._surge_in = 99.0

	for i in 620:
		camera.global_position = p.global_position + Vector3(0.0, 0.55, 0.6)
		camera.look_at(one.global_position + Vector3.UP * 1.5)
		await get_tree().physics_frame

	while not one.is_down():
		one.take_hit(55.0, p, &"bullet", one.global_position, Vector3.FORWARD)

	for i in 480:
		camera.global_position = one.global_position + Vector3(3.2, 1.3, 2.2)
		camera.look_at(one.global_position + Vector3.UP * 0.9)
		await get_tree().physics_frame

	get_tree().quit()


func _follow(off: Vector3) -> void:
	camera.global_position = one.global_position + off
	camera.look_at(one.global_position + Vector3.UP * 1.3)


func _frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame
