extends Node3D
## The brazier in your hand, for Movie Maker, first person, in the real game: held, walked, a lash that misses, a lash that lands on a revenant, a close hit on it, one on the wall, one to finish it.
##   Godot --path . --resolution 1280x720 --fixed-fps 60 --write-movie <file>.avi res://tests/diag_brazier.tscn

const GYM := preload("res://maps/hunt_gym.tscn")
const RevenantScript := preload("res://scripts/Monsters/Revenant.gd")

var gym: Node3D
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
	p.teleport(Transform3D(Basis.IDENTITY, Vector3(-5, 1.05, -8)))
	p.loadout.pack_item(&"brazier")
	await _frames(40)
	p.inventory.select_by_id(&"brazier")
	# Held: looking about.
	await _frames(70)
	await _turn(0.5, 40)
	await _turn(-1.0, 60)
	await _turn(0.5, 40)
	# Walking.
	Input.action_press("move_forward")
	await _frames(70)
	Input.action_release("move_forward")
	await _frames(30)
	# A lash at nothing.
	await _lash()
	await _frames(30)
	# A close hit at nothing.
	await _close()
	await _frames(30)
	var one: CharacterBody3D = RevenantScript.new()
	one.position = p.global_position + Vector3(0, -1.05, -4.6)
	gym.add_child(one)
	await _frames(40)
	await _lash()
	await _frames(20)
	await _close()
	await _frames(40)
	await _lash()
	await _frames(20)
	await _lash()
	await _frames(240)
	get_tree().quit()


func _turn(by: float, over: int) -> void:
	for i in over:
		p.rotate_y(by / over)
		await get_tree().physics_frame


func _lash() -> void:
	Input.action_press("throw")
	await _frames(3)
	Input.action_release("throw")
	await _frames(70)


func _close() -> void:
	Input.action_press("throw")
	await _frames(16)
	Input.action_release("throw")
	await _frames(50)


func _frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame
