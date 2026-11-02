extends Node
## What lies on someone for a while (the evil eye, smoked, exposed): each has
## its seconds left, which run out in game time, and how many times over it lies
## (its stacks, from 1). Runs as a child of whoever bears them, the player or a
## monster. What a status does is the bearer's business; this only keeps count.

signal started(id: StringName)
signal ended(id: StringName)

## Being stared at, building toward a curse, 0..1, kept here so a whole pack adds
## up: forgotten slowly after a moment of nobody looking.
const STARE_HELD := 0.5
const STARE_FADES := 1.0

var _left := {}
var _full := {}
var _stare := 0.0
var _stare_rest := 0.0
var _stacks := {}
## Seconds since anything last looked at the bearer.
var _stare_ago := INF


## On for `seconds`, or on as long as it already was if that is longer.
func apply(id: StringName, seconds: float) -> void:
	var fresh := not _left.has(id)
	_left[id] = maxf(float(_left.get(id, 0.0)), seconds)
	_full[id] = _left[id]

	if fresh:
		_stacks[id] = 1
		started.emit(id)


func stacks(id: StringName) -> int:
	return int(_stacks.get(id, 0))


func set_stacks(id: StringName, count: int) -> void:
	if _left.has(id):
		_stacks[id] = count


func looked_ago() -> float:
	return _stare_ago


func has(id: StringName) -> bool:
	return _left.has(id)


func left(id: StringName) -> float:
	return float(_left.get(id, 0.0))


## How much of it is left, 0..1.
func fraction(id: StringName) -> float:
	return float(_left.get(id, 0.0)) / maxf(float(_full.get(id, 1.0)), 0.001)


## A look at the bearer: true when, added up, it has been stared at for `needed` s.
func stare(delta: float, needed: float) -> bool:
	_stare += delta / needed
	_stare_rest = STARE_HELD
	_stare_ago = 0.0

	if _stare >= 1.0:
		_stare = 0.0
		return true

	return false


func stared() -> float:
	return _stare


func forget_stare() -> void:
	_stare = 0.0


func clear(id: StringName) -> void:
	_stacks.erase(id)

	if _left.erase(id):
		ended.emit(id)


func save_state() -> Dictionary:
	return {"left": _left.duplicate(), "stacks": _stacks.duplicate()}


func load_state(state: Dictionary) -> void:
	_left = {}

	for id in state.get("left", {}):
		_left[StringName(id)] = float(state["left"][id])
		_stacks[StringName(id)] = int(state.get("stacks", {}).get(id, 1))


func _physics_process(delta: float) -> void:
	_stare_rest -= delta
	_stare_ago += delta

	if _stare_rest <= 0.0:
		_stare = move_toward(_stare, 0.0, delta * STARE_FADES)

	for id in _left.keys():
		_left[id] = float(_left[id]) - delta

		if float(_left[id]) <= 0.0:
			_left.erase(id)
			_stacks.erase(id)
			ended.emit(id)
