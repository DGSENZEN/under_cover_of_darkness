class_name KeyItem
extends RigidBody3D
## Frobbable rigid key transferring key_id and its mesh to player.inventory once.
## Matching doors/chests can then unlock. It cannot be carried; frob queues deletion.

@export var key_id: StringName = &"key"
@export var key_name := "key"

var taken := false


func get_prompt(_player: Node) -> String:
	return "Take " + key_name


func can_carry() -> bool:
	return false


func frob(player: Node) -> void:
	if taken:
		return

	taken = true

	var mesh: Mesh = null
	var visual := get_node_or_null("MeshInstance3D") as MeshInstance3D

	if visual != null:
		mesh = visual.mesh

	player.inventory.add_key(key_id, key_name, mesh)
	queue_free()
