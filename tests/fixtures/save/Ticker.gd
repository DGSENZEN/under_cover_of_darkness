extends Node3D
## A schedule that saves itself through SaveFields, for the save suites: a
## clock, a typed list and its own dice.

const SaveFields := preload("res://scripts/Save/SaveFields.gd")
const SAVED := ["clock", "next", "seen", "_rng"]

var clock := 0.0
var next := 0.0
var seen: Array[int] = []
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.seed = 11
	next = _rng.randf_range(1.0, 2.0)
	var save := get_node_or_null("/root/SaveGame")

	if save != null:
		save.register(self)


func tick(seconds: float) -> void:
	clock += seconds

	while clock >= next:
		seen.append(_rng.randi_range(0, 99))
		next += _rng.randf_range(1.0, 2.0)


func roll() -> int:
	return _rng.randi_range(0, 1000000)


func save_state() -> Dictionary:
	return SaveFields.save(self, SAVED)


func load_state(state: Dictionary) -> void:
	SaveFields.restore(self, state, SAVED)
