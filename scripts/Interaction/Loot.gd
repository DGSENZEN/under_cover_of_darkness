class_name Loot
extends RigidBody3D
## Something worth stealing. Frob it and its value goes into the purse. It is
## a RigidBody3D so it can also sit in a chest, fall off a shelf, or be
## knocked over, but it is never carried: taking it is the whole point.

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
