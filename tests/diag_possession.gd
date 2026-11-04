extends Node3D
## Possession, for Movie Maker, first person, in the real game: taken by a revenant's second touch, with the gun, then with the brazier.
##   Godot --path . --resolution 1280x720 --fixed-fps 60 --write-movie <file>.avi res://tests/diag_possession.tscn

const GYM := preload("res://maps/hunt_gym.tscn")

var gym: Node3D
var p: CharacterBody3D


func _ready() -> void:
	var with_brazier := "--brazier" in OS.get_cmdline_user_args()
	gym = GYM.instantiate()
	add_child(gym)
	await _frames(60)
	gym.set_physics_process(false)

	for other in get_tree().get_nodes_in_group(&"monsters"):
		other.queue_free()

	p = gym.player
	p.reload_on_death = false
	p.teleport(Transform3D(Basis.IDENTITY, Vector3(-5, 1.05, -8)))

	if with_brazier:
		p.loadout.pack_item(&"brazier")
		await _frames(10)
		p.inventory.select_by_id(&"brazier")

	await _frames(90)
	p.invulnerable = false
	p.death.possessed = true
	p.drain_life(p.health + 1.0)
	await _frames(int(4.2 * 60.0))
	get_tree().quit()


func _frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame
