extends Node
## How you die, when something you can fight has killed you: by the eyes, by the ánimas, by both
## (the design: docs/superpowers/specs/2026-11-02-player-deaths-design.md). Decided once, as you
## go, and timed here. The camera, the leech, its hands and the HUD read the clock and carry the
## fight on to its end, without a cut. Anything else that kills you is the old fall.

const Sfx := preload("res://scripts/Audio/Sfx.gd")
const TimeFx := preload("res://scripts/Visual/TimeFx.gd")

signal finished
## The words have landed (or you pressed): the page may come.
signal page_due

## The fall takes this long, the words this long after any death (DeathQuote.TAKES).
const FALL_TAKES := 2.0
const QUOTE_TAKES := 3.4
## How long each takes (s).
const LENGTHS := {&"eyes": 3.0, &"animas": 4.2, &"both": 4.6, &"swipe": 2.0, &"mouth": 2.6, &"possessed": 3.5}
## An attack press ends it, after this long. The words come up over this much at the very end.
const SKIP_AFTER := 1.0
const WORDS_FROM_END := 0.5
## How long in what has you goes on holding you (s): its gulps slowing to this many times as long,
## and a last long one taking this long.
const LETS_GO := {&"animas": 3.2, &"both": 3.6, &"swipe": 0.4, &"mouth": 2.4, &"possessed": 2.5}
const GULPS_SLOW_TO := 3.0
const LAST_GULP_TAKES := 1.0
## What has you hauls you down: buckled at once, a lurch with each gulp, the floor with the last;
## how quick and how loose the lurch; how hard each hits, and the last.
const BUCKLES := 0.24
const LURCH := 0.2
const LURCH_RATE := 3.2
const LURCH_LOOSE := 0.42
const GULP_HITS := 0.24
const LAST_HITS := 0.5
const LAST_STOPS := 0.07
## How far down your head goes to reach the floor, how far it rolls, and how far aside. Kneeling,
## as the eyes have you, how far down and how far your head has dropped. How quick a swipe's is.
const GOES_DOWN := 1.3
const ROLLS := 1.15
const GOES_ASIDE := 0.12
const KNEELS := 0.7
const HEAD_DROPS := 0.5
const KNEELS_TAKES := 1.6
const SWIPE_DOWN_TAKES := 0.7
## Swallowed by the mouth, full: how long its ribs take to shut on you.
const SWALLOW_TAKES := 1.0

## Possessed: your head wrenched round (rad) and a body walking under you that isn't yours (how fast, how far), until it lets you drop.
## (Your hands: a stand-in, none of their own yet. They are posed with the user: plan Task 11.)
const POSSESSED_TURNS := 1.5
const POSSESSED_NODS := 0.28
const POSSESSED_STEPS := 5.5
const POSSESSED_BOBS := 0.04
const POSSESSED_SWAYS := 0.045
const POSSESSED_DROPS_AT := 2.75

## The eyes' death: your heart, how long between beats at the start and at its fastest, and from
## how far through it stops (as the HUD's flesh fails: StealthHUD.EYES_FAIL_FROM).
const HEART_GAPS := Vector2(0.55, 0.26)
const HEART_STOPS_AT := 0.7
## When you hit the floor (s), for each; when the last eye tears open (share).
const FLOORED := {&"eyes": 2.7, &"animas": 3.1, &"both": 3.5, &"swipe": 0.65, &"mouth": 1.9, &"possessed": 3.35}
const EYE_TEARS_AT := 0.6

## How many beats of your heart it has played.
var heartbeats := 0
## &"" alive, or which death: &"eyes", &"animas", &"both", &"swipe", &"fall".
var kind: StringName = &""
var player: CharacterBody3D

var _at := 0.0
var _running := false
var _since := 0.0
var _page_called := false
var _haul := 0.0
var _haul_speed := 0.0
var _haul_to := 0.0
var _was_cursed := false
var _floored := false
var _beat_in := 0.0
var _eye_torn := false
var _gulped_last := false
## The side you go down on: + your right.
var _side := 1.0


## You are going. `last_blow` is what the blow says it kills as (`kills_as`), or nothing.
## The full mouth had you: it was no ordinary death.
var swallowed := false
## A revenant's second touch: your body isn't yours, and that is how you go.
var possessed := false


func begin(last_blow: StringName) -> void:
	if kind != &"":
		return

	_was_cursed = player.statuses.has(&"evil_eye")
	kind = _which(last_blow)
	_at = 0.0
	_since = 0.0
	_running = LENGTHS.has(kind)
	_side = _falls_to()

	if kind == &"animas" or kind == &"both":
		_haul_to = BUCKLES
		player.leech.gulped.connect(_hauled)
		_hauled()


## A gulp as you go: down another lurch.
func _hauled() -> void:
	_haul_to = minf(_haul_to + LURCH, 1.0)
	player.juice.add_trauma(GULP_HITS)


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
			return _laid_down(clampf(_haul, 0.0, 1.05))
		&"swipe":
			return _laid_down(smoothstep(0.0, SWIPE_DOWN_TAKES, _at))
		&"mouth":
			return _laid_down(smoothstep(SWALLOW_TAKES * 0.5, SWALLOW_TAKES * 2.0, _at))
		&"possessed":
			var round_on := smoothstep(0.15, 1.5, _at)
			var walks := smoothstep(0.5, 1.0, _at) * (1.0 - smoothstep(POSSESSED_DROPS_AT - 0.2, POSSESSED_DROPS_AT, _at))
			var laid := _laid_down(smoothstep(POSSESSED_DROPS_AT, length_of_possessed(), _at))
			return {"down": sin(_at * POSSESSED_STEPS) * POSSESSED_BOBS * walks + float(laid["down"]), "turn": Vector3(-POSSESSED_NODS * round_on, POSSESSED_TURNS * round_on, 0.1 * sin(_at * POSSESSED_STEPS * 0.5) * walks) + (laid["turn"] as Vector3), "side": sin(_at * POSSESSED_STEPS * 0.5) * POSSESSED_SWAYS * walks + float(laid["side"])}

	return {}


func length_of_possessed() -> float:
	return float(FLOORED[&"possessed"]) + 0.1


func _laid_down(how_far: float) -> Dictionary:
	return {"down": GOES_DOWN * how_far, "turn": Vector3(0.2 * how_far, 0.25 * _side * how_far, -_side * ROLLS * how_far), "side": GOES_ASIDE * _side * how_far}


func _which(last_blow: StringName) -> StringName:
	if possessed:
		return &"possessed"

	if swallowed:
		return &"mouth"

	if player.leech.count() > 0:
		return &"both" if player.statuses.has(&"evil_eye") else &"animas"

	return last_blow if last_blow == &"eyes" or last_blow == &"swipe" else &"fall"


## One of these took you: what it has done to your sight stays, under the page.
func holds_screen() -> bool:
	return LENGTHS.has(kind)


## The curse's flesh is part of how you are going.
func flesh_stays() -> bool:
	return holds_screen() and (kind == &"eyes" or _was_cursed)


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
	if kind == &"mouth":
		return clampf(_at / SWALLOW_TAKES, 0.0, 1.0)

	return clampf((_at - (float(LETS_GO.get(kind, INF)) - LAST_GULP_TAKES)) / LAST_GULP_TAKES, 0.0, 1.0)


func _ends_at() -> float:
	return float(LENGTHS.get(kind, FALL_TAKES))


## Seconds since the death itself was over; below 0 until then.
func since_end() -> float:
	return _since - _ends_at() if kind != &"" else -1.0


## The words and the last of the dark, 0 until near the end, then up to 1.
func words_share() -> float:
	return clampf((_at - (float(LENGTHS[kind]) - WORDS_FROM_END)) / WORDS_FROM_END, 0.0, 1.0) if LENGTHS.has(kind) else 0.0


func _haul_down(delta: float) -> void:
	if kind != &"animas" and kind != &"both" and kind != &"mouth":
		return

	# The last of it takes you to the floor.
	if last_gulp() > 0.0 or not holding():
		_haul_to = 1.0

	var w := minf(TAU * LURCH_RATE, 0.8 / delta)
	_haul_speed += (w * w * (_haul_to - _haul) - 2.0 * LURCH_LOOSE * w * _haul_speed) * delta
	_haul += _haul_speed * delta


## Stand-ins until the takes come (docs/superpowers/refs/hunt/sounds_needed.md).
func _sound(delta: float) -> void:
	if not _floored and _at >= float(FLOORED[kind]):
		_floored = true
		Sfx.play_flat(self, &"body_fall", 2.0, 0.9)

	if kind == &"eyes":
		_beat_in -= delta

		if _beat_in <= 0.0 and share() < HEART_STOPS_AT:
			heartbeats += 1
			_beat_in = lerpf(HEART_GAPS.x, HEART_GAPS.y, share() / HEART_STOPS_AT)
			Sfx.play_flat(self, &"heartbeat", -2.0, lerpf(0.9, 1.15, share() / HEART_STOPS_AT))

		if not _eye_torn and share() >= EYE_TEARS_AT:
			_eye_torn = true
			Sfx.play_flat(self, &"flesh_heavy", 0.0, 0.7)
	elif (kind == &"animas" or kind == &"both" or kind == &"mouth") and not _gulped_last and last_gulp() > 0.0:
		_gulped_last = true
		player.juice.add_trauma(LAST_HITS)
		TimeFx.hitstop(get_tree(), LAST_STOPS)
		Sfx.play_flat(self, &"flesh_heavy", -2.0, 0.55)
		Sfx.play_flat(self, &"anima_moan", -6.0, 0.5)


func _physics_process(delta: float) -> void:
	if kind == &"":
		return

	_since += delta

	# Over: the words, and a press or their landing brings the page.
	if not _running:
		if not _page_called and _since >= _ends_at() and (_since - _ends_at() >= QUOTE_TAKES or Input.is_action_just_pressed("throw")):
			_page_called = true
			page_due.emit()

		return

	var length: float = LENGTHS[kind]
	_at += delta

	_sound(delta)
	_haul_down(delta)

	if _at >= SKIP_AFTER and _at < length - WORDS_FROM_END and Input.is_action_just_pressed("throw"):
		_at = length - WORDS_FROM_END
		_since = _at

	if _at >= length:
		_at = length
		_running = false
		finished.emit()
