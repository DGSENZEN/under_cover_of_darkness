extends Node
## What lies on someone for a while (the evil eye, smoked, exposed): each has
## its seconds left, which run out in game time. Runs as a child of whoever
## bears them, the player or a monster. What a status does is the bearer's
## business; this only keeps the time.

signal started(id: StringName)
signal ended(id: StringName)

var _left := {}


## On for `seconds`, or on as long as it already was if that is longer.
func apply(id: StringName, seconds: float) -> void:
	var fresh := not _left.has(id)
	_left[id] = maxf(float(_left.get(id, 0.0)), seconds)

	if fresh:
		started.emit(id)


func has(id: StringName) -> bool:
	return _left.has(id)


func left(id: StringName) -> float:
	return float(_left.get(id, 0.0))


func clear(id: StringName) -> void:
	if _left.erase(id):
		ended.emit(id)


func save_state() -> Dictionary:
	return {"left": _left.duplicate()}


func load_state(state: Dictionary) -> void:
	_left = {}

	for id in state.get("left", {}):
		_left[StringName(id)] = float(state["left"][id])


func _physics_process(delta: float) -> void:
	for id in _left.keys():
		_left[id] = float(_left[id]) - delta

		if float(_left[id]) <= 0.0:
			_left.erase(id)
			ended.emit(id)
