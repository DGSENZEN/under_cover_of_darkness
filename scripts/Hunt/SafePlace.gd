extends Node3D
## A place out of the hunt. Walking out seals what you packed (Loadout.gd) and
## saves, so dying brings you back to the door with all of it, free to pack
## otherwise with what you have learnt. Coming back costs the walk: your lost
## shields return, and the table fills you up again from what you own, once you
## have really been away and nothing awake is close behind you. What you killed
## stays dead. It asks each tick where you are: a physics area's word comes a
## tick late, and when a map is taken away it reports you walking out.

## You walked out; you came back in from out there, and it took.
signal left
signal returned

## Seconds out before coming back counts: a step at the door does not.
const MIN_OUT := 3.0
## Something awake this near (m) and the room gives nothing yet.
const HUNTED_WITHIN := 12.0

@export var size := Vector3(10.0, 4.0, 10.0)
## Seconds outside since you last sealed your pack. A load comes back free.
var out_for := MIN_OUT

var _was_inside := false
var _known := false


static func build(parent: Node, center: Vector3, box: Vector3) -> Node3D:
	var place: Node3D = (load("res://scripts/Hunt/SafePlace.gd") as GDScript).new()
	place.size = box
	parent.add_child(place)
	place.global_position = center
	return place


## Whether `body`'s middle is in the room.
func holds(body: Node3D) -> bool:
	return AABB(-size * 0.5, size).has_point(to_local(body.global_position))


func _physics_process(delta: float) -> void:
	var player := get_tree().get_first_node_in_group(&"player") as CharacterBody3D

	if player == null:
		return

	var inside := holds(player)

	# The first look only says where you are: you did not just arrive.
	if _known and _was_inside and not inside:
		_walked_out(player)

	_known = true
	_was_inside = inside

	if not inside:
		out_for += delta
	elif player.loadout.locked and not player.is_dead and out_for >= MIN_OUT and not _hunted(player):
		player.health = player.max_health
		player.loadout.unlock()
		player.loadout.restock()
		returned.emit()


func _walked_out(player: CharacterBody3D) -> void:
	# Already sealed, or dead: nothing to do.
	if player.loadout.locked or player.is_dead:
		return

	player.loadout.restock()
	player.loadout.lock()
	out_for = 0.0
	SaveGame.request_save(&"auto")
	left.emit()


func _hunted(player: CharacterBody3D) -> bool:
	for monster in get_tree().get_nodes_in_group(&"monsters"):
		if not monster.dead and not monster.asleep and monster.global_position.distance_to(player.global_position) <= HUNTED_WITHIN:
			return true

	return false
