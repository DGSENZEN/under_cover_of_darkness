extends Node
## How you die, when something you can fight has killed you: by the eyes, by the ánimas, by both
## (the design: docs/superpowers/specs/2026-11-02-player-deaths-design.md). Decided once, as you
## go, and timed here. The camera, the leech, its hands and the HUD read the clock and carry the
## fight on to its end, without a cut. Anything else that kills you is the old fall.

signal finished

## How long each takes (s).
const LENGTHS := {&"eyes": 3.0, &"animas": 3.5, &"both": 4.0, &"swipe": 2.0}
## An attack press ends it, after this long. The words come up over this much at the very end.
const SKIP_AFTER := 1.0
const WORDS_FROM_END := 0.5

## &"" alive, or which death: &"eyes", &"animas", &"both", &"swipe", &"fall".
var kind: StringName = &""
var player: CharacterBody3D

var _at := 0.0
var _running := false


## You are going. `last_blow` is what the blow says it kills as (`kills_as`), or nothing.
func begin(last_blow: StringName) -> void:
	if kind != &"":
		return

	kind = _which(last_blow)
	_at = 0.0
	_running = LENGTHS.has(kind)


func _which(last_blow: StringName) -> StringName:
	if player.leech.count() > 0:
		return &"both" if player.statuses.has(&"evil_eye") else &"animas"

	return last_blow if last_blow == &"eyes" or last_blow == &"swipe" else &"fall"


## A death of this kind is running: the fight stays on screen.
func playing() -> bool:
	return _running


## Seconds since you went.
func at() -> float:
	return _at


## How far through it is, 0..1.
func share() -> float:
	return clampf(_at / float(LENGTHS[kind]), 0.0, 1.0) if LENGTHS.has(kind) else 0.0


## The words and the last of the dark, 0 until near the end, then up to 1.
func words_share() -> float:
	return clampf((_at - (float(LENGTHS[kind]) - WORDS_FROM_END)) / WORDS_FROM_END, 0.0, 1.0) if LENGTHS.has(kind) else 0.0


func _physics_process(delta: float) -> void:
	if not _running:
		return

	var length: float = LENGTHS[kind]
	_at += delta

	if _at >= SKIP_AFTER and _at < length - WORDS_FROM_END and Input.is_action_just_pressed("throw"):
		_at = length - WORDS_FROM_END

	if _at >= length:
		_at = length
		_running = false
		finished.emit()
