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
## How long in what has you goes on holding you (s): its gulps slowing to this many times as long,
## and a last long one taking this long.
const LETS_GO := {&"animas": 2.6, &"both": 3.0, &"swipe": 0.4}
const GULPS_SLOW_TO := 3.0
const LAST_GULP_TAKES := 0.8
## How far down your head goes to reach the floor, how far it rolls, and how far aside. Kneeling,
## as the eyes have you, how far down and how far your head has dropped. How quick a swipe's is.
const GOES_DOWN := 1.3
const ROLLS := 1.15
const GOES_ASIDE := 0.12
const KNEELS := 0.7
const HEAD_DROPS := 0.5
const KNEELS_TAKES := 1.6
const SWIPE_DOWN_TAKES := 0.7

## &"" alive, or which death: &"eyes", &"animas", &"both", &"swipe", &"fall".
var kind: StringName = &""
var player: CharacterBody3D

var _at := 0.0
var _running := false
## The side you go down on: + your right.
var _side := 1.0


## You are going. `last_blow` is what the blow says it kills as (`kills_as`), or nothing.
func begin(last_blow: StringName) -> void:
	if kind != &"":
		return

	kind = _which(last_blow)
	_at = 0.0
	_running = LENGTHS.has(kind)
	_side = _falls_to()


func _falls_to() -> float:
	if kind == &"animas" or kind == &"both":
		var first: Node3D = player.leech.on_me()[0]
		return signf((player.global_basis.inverse() * player.leech.slot_side(player.leech.slot_of(first))).x + 0.001)

	# Off the blow, away from the side it came from.
	if kind == &"swipe" and player.hud != null:
		return -signf(player.hud.cut_side() + 0.001)

	return 1.0


## How your head goes down, now: {"down": m, "turn": Euler, "side": m}. Held once it is over.
func camera_pose() -> Dictionary:
	match kind:
		&"eyes":
			var length: float = LENGTHS[kind]
			var kneel := smoothstep(0.0, KNEELS_TAKES, _at)
			var lie := smoothstep(length - 1.0, length - 0.2, _at)
			return {"down": lerpf(KNEELS * kneel, GOES_DOWN, lie), "turn": Vector3(-HEAD_DROPS * kneel * (1.0 - lie) + 0.25 * lie, 0.0, -_side * ROLLS * lie), "side": GOES_ASIDE * _side * lie}
		&"animas", &"both":
			return _laid_down(smoothstep(0.0, float(LETS_GO[kind]), _at))
		&"swipe":
			return _laid_down(smoothstep(0.0, SWIPE_DOWN_TAKES, _at))

	return {}


func _laid_down(how_far: float) -> Dictionary:
	return {"down": GOES_DOWN * how_far, "turn": Vector3(0.2 * how_far, 0.25 * _side * how_far, -_side * ROLLS * how_far), "side": GOES_ASIDE * _side * how_far}


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


## Whether what has you has you still.
func holding() -> bool:
	return _running and _at < float(LETS_GO.get(kind, 0.0))


## How many times longer a gulp takes now.
func gulps_slow() -> float:
	return lerpf(1.0, GULPS_SLOW_TO, clampf(_at / float(LETS_GO.get(kind, 1.0)), 0.0, 1.0))


## The last long gulp, 0 until it starts, then up to 1, and held.
func last_gulp() -> float:
	return clampf((_at - (float(LETS_GO.get(kind, INF)) - LAST_GULP_TAKES)) / LAST_GULP_TAKES, 0.0, 1.0)


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
