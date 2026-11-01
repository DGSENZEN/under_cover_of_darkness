extends Area3D
## A place out of the hunt. Walking out seals what you packed (Loadout.gd) and
## saves, so dying brings you back here with all of it, free to pack otherwise
## with what you have learnt. Walking back in costs only the walk: your lost
## shields return, and the table fills you up again from what you own. What you
## killed stays dead.

## You walked out; you came back in from out there.
signal left
signal returned

@export var size := Vector3(10.0, 4.0, 10.0)


static func build(parent: Node, center: Vector3, box: Vector3) -> Area3D:
	var place: Area3D = (load("res://scripts/Hunt/SafePlace.gd") as GDScript).new()
	place.size = box
	parent.add_child(place)
	place.global_position = center
	return place


func _ready() -> void:
	collision_layer = 0
	collision_mask = 1
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	add_child(shape)
	body_exited.connect(_on_exited)
	body_entered.connect(_on_entered)


func _on_exited(body: Node3D) -> void:
	if not body.is_in_group(&"player") or body.get("is_dead"):
		return

	var loadout: Node = body.get("loadout")
	loadout.restock()
	loadout.lock()
	SaveGame.request_save(&"auto")
	left.emit()


func _on_entered(body: Node3D) -> void:
	if not body.is_in_group(&"player"):
		return

	var loadout: Node = body.get("loadout")

	# Only coming back from out there: not the first frame of the map.
	if not loadout.locked:
		return

	body.set("health", body.get("max_health"))
	loadout.unlock()
	loadout.restock()
	returned.emit()
