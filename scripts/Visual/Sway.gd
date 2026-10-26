class_name Sway
extends Node3D
## Something hung that sways in a draught (the Underground's bulbs, lanterns,
## herb bundles): this node is the pivot, what hangs is its child. The swing
## runs across the draught, a few degrees at most, on game time with a
## seeded phase, so two runs of a scene sway alike and no two hangings
## swing as one.

## The widest swing (degrees), the slow swing's period (s), and the way the
## draught blows (the swing runs along it).
const SaveFields := preload("res://scripts/Save/SaveFields.gd")
## What a save keeps of it (SaveFields): its clock.
const SAVED := ["_time"]

@export var amplitude := 2.5
@export var period := 2.6
@export var draught := Vector3(1.0, 0.0, 0.0)
@export var seed := 0:
	set(value):
		seed = value
		_seeded()

## A gust over the draught (a passing train's): the swing grows by this much.
var gust := 0.0
var _time := 0.0
var _phase := 0.0


func _init() -> void:
	_seeded()


func _process(delta: float) -> void:
	_time += delta
	var axis := draught.cross(Vector3.UP)

	if axis.length() < 1e-4:
		return

	basis = Basis(axis.normalized(), deg_to_rad(angle_at(_time)))


## The swing (degrees) at `t` seconds: a slow sway with a slower gust over it,
## never past `amplitude`.
func angle_at(t: float) -> float:
	return amplitude * (1.0 + gust) * (0.8 * sin(TAU * t / period + _phase) + 0.2 * sin(TAU * t / (period * 2.7) + _phase * 1.7))


func _seeded() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	_phase = rng.randf() * TAU


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
