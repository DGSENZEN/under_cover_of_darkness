class_name Loot
extends RigidBody3D
## Frobbable rigid pickup transferring value to player.inventory.purse once.
## It cannot be carried; successful frob marks taken and queues the body for deletion.

const PickupState := preload("res://scripts/Interaction/PickupState.gd")

@export var value := 25
@export var loot_name := "trinket"

var taken := false


func get_prompt(_player: Node) -> String:
	return "Take %s (%d)" % [loot_name, value]


func can_carry() -> bool:
	return false


func frob(player: Node) -> void:
	if taken:
		return

	taken = true
	player.inventory.add_loot(value)
	queue_free()


func _ready() -> void:
	# Saves itself (SaveGame); absent when a tool runs the script alone.
	var save := get_node_or_null("/root/SaveGame")

	if save != null:
		save.register(self)


## Taken or not, and where it lies (PickupState), for the district's memory.
func save_state() -> Dictionary:
	return PickupState.save(self)


func load_state(state: Dictionary) -> void:
	PickupState.restore(self, state)
