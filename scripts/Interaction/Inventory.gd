extends Node
## Player inventory data: purse total, key IDs, counted belt entries, selection.
## HandSlot renders the selected entry; -1 selects empty hands.
## Mutation signals are synchronous and selected_item() returns the stored dictionary.

const PropsScript := preload("res://scripts/Interaction/Props.gd")

signal changed
signal loot_taken(value: int, total: int)
signal key_taken(key_id: StringName)
signal belt_selection_changed(item: Dictionary)

var purse := 0
var keys: Array[StringName] = []

## Each entry: { "id": StringName, "name": String, "mesh": Mesh, "count": int }
var belt: Array[Dictionary] = []
var belt_index := -1


## Adds value without clamping; emits loot_taken(value, purse), then changed.
func add_loot(value: int) -> void:
	purse += value
	loot_taken.emit(value, purse)
	changed.emit()


## Adds a unique key ID and one belt item; always emits key_taken, even for duplicates.
## mesh may be null; duplicate keys still increase their belt count.
func add_key(key_id: StringName, key_name: String, mesh: Mesh = null) -> void:
	if not keys.has(key_id):
		keys.append(key_id)

	key_taken.emit(key_id)
	add_belt_item(key_id, key_name, mesh)


func has_key(key_id: StringName) -> bool:
	return keys.has(key_id)


## Merges count by ID or appends {id, name, mesh, count}; mesh may be null.
## A new item auto-selects only when belt_index < 0. Emits changed.
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


## Returns the selected stored Dictionary, or {} for empty/invalid selection.
## The returned dictionary is not a copy.
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


## Selects id and emits selection/changed; returns false without mutation if absent.
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


## How many of `id` are on the belt (0: none).
func count_of(id: StringName) -> int:
	for entry in belt:
		if entry["id"] == id:
			return int(entry["count"])

	return 0


## Consumes one matching item; at zero count removes it and clears matching selection.
## Missing IDs are a no-op; removing an earlier item shifts belt_index.
func take_one(id: StringName) -> void:
	for i in range(belt.size()):
		if belt[i]["id"] != id:
			continue

		belt[i]["count"] = int(belt[i]["count"]) - 1

		if int(belt[i]["count"]) <= 0:
			belt.remove_at(i)

			if belt_index == i:
				belt_index = -1
				belt_selection_changed.emit({})
			elif belt_index > i:
				belt_index -= 1

		changed.emit()
		return


## What the player carries through a gate (CityState): the purse, the keys,
## the belt's items and counts (not their meshes) and which is in hand.
func save_state() -> Dictionary:
	var items := []

	for entry in belt:
		items.append({"id": entry["id"], "name": entry["name"], "count": int(entry["count"])})

	return {"purse": purse, "keys": keys.duplicate(), "belt": items, "belt_index": belt_index}


## Carries what was saved (save_state): the belt rebuilt with each item's
## own mesh (Props.belt_mesh), the same item in hand.
func load_state(state: Dictionary) -> void:
	purse = int(state.get("purse", 0))
	keys.clear()

	for key in state.get("keys", []):
		keys.append(StringName(key))

	belt.clear()

	for item in state.get("belt", []):
		var id := StringName(item["id"])
		belt.append({"id": id, "name": String(item["name"]), "mesh": PropsScript.belt_mesh(id, keys.has(id)), "count": int(item["count"])})

	belt_index = int(state.get("belt_index", -1)) if int(state.get("belt_index", -1)) < belt.size() else -1
	belt_selection_changed.emit(selected_item())
	changed.emit()
