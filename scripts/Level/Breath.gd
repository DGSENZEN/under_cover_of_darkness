class_name Breath
extends Node
## The caged god's breath (the effects plan): in and out about every seven
## seconds, every fourth breath a deep one. What breathes with it (the wards,
## the lamps round its ring, the smoke and petals it pulls in, the fog round
## its cage, its chains) reads it; nothing else times itself to the god.

const PERIOD := 7.0
const DEEP_EVERY := 4
## A breath that is not deep goes this far in and out.
const SHALLOW := 0.7

## On the turn of a deep breath, from in to out (the chains snap taut).
signal deep_exhale

var time := 0.0


## The breath at time t (s): +1 drawn fully in, -1 fully out.
func at(t: float) -> float:
	var phase := fposmod(t, PERIOD) / PERIOD
	return sin(phase * TAU) * (1.0 if _deep_at(t) else SHALLOW)


## The breath now.
func value() -> float:
	return at(time)


## Whether this breath is a deep one.
func deep() -> bool:
	return _deep_at(time)


func _deep_at(t: float) -> bool:
	return posmod(floori(t / PERIOD), DEEP_EVERY) == DEEP_EVERY - 1


func _process(delta: float) -> void:
	step(delta)


## One step of `delta` seconds (the suite steps it by hand).
func step(delta: float) -> void:
	var before := fposmod(time, PERIOD) / PERIOD
	var same := floori(time / PERIOD) == floori((time + delta) / PERIOD)
	time += delta
	var after := fposmod(time, PERIOD) / PERIOD

	if same and before < 0.5 and after >= 0.5 and deep():
		deep_exhale.emit()
