class_name ToolItem
extends RigidBody3D
## Frobbable rigid belt pickup transferring tool_id, count, and optional mesh
## to player.inventory once, then queuing deletion. It cannot be carried.
## PlayerFrob and PlayerCombat interpret the selected tool ID.

const PickupState := preload("res://scripts/Interaction/PickupState.gd")

@export var tool_id: StringName = &"tool"
@export var tool_name := "tool"
@export var count := 1

var taken := false


func get_prompt(_player: Node) -> String:
	if count > 1:
		return "Take %s (%d)" % [tool_name, count]

	return "Take " + tool_name


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

	player.inventory.add_belt_item(tool_id, tool_name, mesh, count)
	queue_free()


## Taken or not, and where it lies (PickupState), for the district's memory.
func save_state() -> Dictionary:
	return PickupState.save(self)


func load_state(state: Dictionary) -> void:
	PickupState.restore(self, state)
