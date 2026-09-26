extends Node
## What the player carries, as data. There is no inventory screen: loot is a
## purse total, keys open the doors they fit on their own, and belt items are
## shown in the hand when selected. HandSlot renders the selection.

signal changed
signal loot_taken(value: int, total: int)
signal key_taken(key_id: StringName)
signal belt_selection_changed(item: Dictionary)

var purse := 0
var keys: Array[StringName] = []

## Each entry: { "id": StringName, "name": String, "mesh": Mesh, "count": int }
var belt: Array[Dictionary] = []
var belt_index := -1


func add_loot(value: int) -> void:
	purse += value
	loot_taken.emit(value, purse)
	changed.emit()


func add_key(key_id: StringName, key_name: String, mesh: Mesh = null) -> void:
	if not keys.has(key_id):
		keys.append(key_id)

	key_taken.emit(key_id)
	add_belt_item(key_id, key_name, mesh)


func has_key(key_id: StringName) -> bool:
	return keys.has(key_id)


func add_belt_item(id: StringName, item_name: String, mesh: Mesh = null, count := 1) -> void:
	for entry in belt:
		if entry["id"] == id:
			entry["count"] += count
			changed.emit()
			return

	belt.append({ "id": id, "name": item_name, "mesh": mesh, "count": count })

	if belt_index < 0:
		belt_index = belt.size() - 1
		belt_selection_changed.emit(selected_item())

	changed.emit()


func selected_item() -> Dictionary:
	if belt_index < 0 or belt_index >= belt.size():
		return {}

	return belt[belt_index]


## Cycles through the belt. Empty hands is one of the stops, so the wheel can
## always put everything away.
func select_next(step := 1) -> void:
	if belt.is_empty():
		return

	var stops := belt.size() + 1
	belt_index = posmod(belt_index + 1 + step, stops) - 1
	belt_selection_changed.emit(selected_item())
	changed.emit()


func select_by_id(id: StringName) -> bool:
	for i in range(belt.size()):
		if belt[i]["id"] == id:
			belt_index = i
			belt_selection_changed.emit(selected_item())
			changed.emit()
			return true

	return false


## Put whatever is in hand back on the belt.
func holster() -> void:
	if belt_index < 0:
		return

	belt_index = -1
	belt_selection_changed.emit({})
	changed.emit()


func is_key_item(id: StringName) -> bool:
	return keys.has(id)
