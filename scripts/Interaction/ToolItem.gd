class_name ToolItem
extends RigidBody3D
## Something that belongs on the belt: a flash bomb, a lockpick, a bundle of
## arrows. Frob it and it hangs from a loop at your waist; take it in hand
## from there. What a tool DOES when used is up to later systems.

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
