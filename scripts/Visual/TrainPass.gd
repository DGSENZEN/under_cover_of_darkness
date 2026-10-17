class_name TrainPass
extends Node
## The metro breathing: every so often a train passes in the tunnel beyond the
## wall. Its strength (0-1) builds as it comes, holds as it runs by, and fades
## as it goes; what answers it (a gust, a rumble, the lights browning out,
## dust off the vault, jars rattling) reads strength() each frame. On game
## time, seeded: two runs of a scene hear the same trains.

## Seconds between trains.
const EVERY := Vector2(90.0, 150.0)
## A pass: coming, running by, going (s).
const BUILD := 5.0
const HOLD := 3.0
const FADE := 6.0

signal began
signal peaked

@export var seed := 0

## Seconds until the next train.
var next := 0.0
var _into := -1.0
var _peaked := false
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.seed = seed
	next = _rng.randf_range(EVERY.x, EVERY.y)


func _process(delta: float) -> void:
	if _into >= 0.0:
		_into += delta

		if not _peaked and _into >= BUILD:
			_peaked = true
			peaked.emit()

		if _into >= BUILD + HOLD + FADE:
			_into = -1.0
			next = _rng.randf_range(EVERY.x, EVERY.y)

		return

	next -= delta

	if next <= 0.0:
		start_pass()


## A train now (the next one reckoned when it has gone).
func start_pass() -> void:
	_into = 0.0
	_peaked = false
	began.emit()


func passing() -> bool:
	return _into >= 0.0


## How near the train is: 0 none, 1 running by.
func strength() -> float:
	if _into < 0.0:
		return 0.0

	if _into < BUILD:
		return smoothstep(0.0, BUILD, _into)

	if _into < BUILD + HOLD:
		return 1.0

	return 1.0 - smoothstep(BUILD + HOLD, BUILD + HOLD + FADE, _into)
