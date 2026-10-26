class_name Gusts
extends Node
## The district's wind on its trees, washing and smoke (Materials.blow): a
## steady breeze from `prevailing`, breathing, and gusts that rise and die
## away every so often, the way never quite the same; for a district
## without the night's weather (scripts/Night/Night.gd's wind).

const SaveFields := preload("res://scripts/Save/SaveFields.gd")
## What a save keeps of it (SaveFields): its clock.
const SAVED := ["_time"]

const Materials := preload("res://scripts/Visual/Materials.gd")

## Where the wind blows toward (flat), its breeze and its strongest gusts (m/s).
@export var prevailing := Vector3(1.0, 0.0, 0.35)
@export var breeze := 2.5
@export var gust := 6.0

var _time := 0.0


## The wind at time t (s): the breeze breathing, gusts on top, the way
## swinging up to 20 degrees either side of the prevailing.
func at(t: float) -> Vector3:
	var breathe := 0.7 + 0.3 * sin(t * 0.23) * sin(t * 0.071 + 1.3)
	# Gusts: two slow waves meeting; only their tops blow.
	var wave := sin(t * 0.31 + 0.4) * 0.6 + sin(t * 0.137 + 2.2) * 0.4
	var gusting := pow(maxf(wave - 0.15, 0.0) / 0.85, 2.0)
	var turn := deg_to_rad(20.0) * sin(t * 0.053 + 0.9) * (0.6 + 0.4 * sin(t * 0.41))
	var way := prevailing.normalized().rotated(Vector3.UP, turn)
	return way * (breeze * breathe + gust * gusting)


## The wind now.
func wind() -> Vector3:
	return at(_time)


func _process(delta: float) -> void:
	_time += delta
	Materials.blow(at(_time))


func _ready() -> void:
	# Saves itself (SaveGame); absent when a tool runs the script alone.
	var save := get_node_or_null("/root/SaveGame")

	if save != null:
		save.register(self)


## Its clock, for a save (SaveGame).
func save_state() -> Dictionary:
	var state := SaveFields.save(self, SAVED)
	return state


func load_state(state: Dictionary) -> void:
	SaveFields.restore(self, state, SAVED)
