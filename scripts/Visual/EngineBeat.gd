class_name EngineBeat
extends Node
## The Company's engine's one beat (docs/superpowers/specs/2026-11-01-engine-presence-design.md): its cranks' clock
## on game time. A crank strokes as its crosshead tops its travel (its angle crossing π/2, EngineCrank.head_height's
## top), a quarter turn after the last: a stroke a second. Everything the engine gives off reads it, so none of it
## keeps a clock of its own.

signal stroke(index: int)

## Turns a second (the cranks'), and each crank's start angle (the kit's json).
@export var turns := 0.25
@export var starts := PackedFloat32Array()
## How hard it is working (0-1): a train drawing on the line.
var strain := 0.0
## Game time since it started (s).
var time := 0.0
var _last_stroke := -INF


func _ready() -> void:
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	process_mode = Node.PROCESS_MODE_PAUSABLE


func _process(delta: float) -> void:
	var before := time
	time += delta
	for i in starts.size():
		if floorf(_tops(i, before)) != floorf(_tops(i, time)):
			_last_stroke = time
			stroke.emit(i)


## Crank `index`'s angle now (radians).
func angle(index: int) -> float:
	return starts[index] + TAU * turns * time


## Seconds since the last stroke of any crank.
func since_stroke() -> float:
	return time - _last_stroke


## How full its breath is (0-1): rising once a turn, with a lift on each stroke that dies away.
func swell() -> float:
	var turn := 0.5 - 0.5 * cos(TAU * turns * time)
	return clampf(0.55 * turn + 0.45 * exp(-since_stroke() / 0.25), 0.0, 1.0)


## How many times crank `index` has topped its travel by `at` (fractional).
func _tops(index: int, at: float) -> float:
	return (starts[index] + TAU * turns * at - PI / 2.0) / TAU
