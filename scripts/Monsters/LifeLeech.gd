extends Node
## What is on you and drinking (Anima.gd). It drinks your willpower and your life, a
## little more with each one on you, up to three at once, while you slow under them.
## With no willpower left your life goes twice as fast. Runs as the player's "Leech"
## child, as EvilEyeCurse.gd does.

signal latched(who: Node3D)
signal released(who: Node3D)
## A gulp: it drinks in beats, and each is felt.
signal gulped

const MOST := 3
## Your pace by how many are on you.
const PACE := [1.0, 0.8, 0.65, 0.5]
## Each holds on from the side it came at you, this far out from your chest, and
## stays there as you turn, so you can turn on it and shoot it. No two share a side.
const HOLD_OUT := 0.85
const APART := 1.1
## Your chest, from the middle of you.
const CHEST := 0.15
## A face is on your face: this far ahead of your eyes, wherever you look, and this far apart
## from another. You hit it where you see it (LeechFace.gd).
const FACE_OUT := 0.8
const FACE_APART := 0.34
## The mouth is all round you: it is this far ahead of your eyes, wherever you look.
const MOUTH_OUT := 0.9

## The gulps: slower as your will goes, as your heart does, sharper the more are on
## you. How long each is felt, what it does to your view, how hard it hauls at you.
const GULP_FAST := 0.72
const GULP_SLOW := 1.25
const GULP_FADES := 0.5
## What is drunk between gulps, of the steady rate: the rest goes with the gulp.
const BETWEEN_GULPS := 0.15
const GULP_TRAUMA := 0.05
const GULP_HAUL := 0.9
const MUFFLE := 0.65
## Your gun arm under it: how fast it sinks, and comes back; how far it can sink (m and
## radians). Your view goes heavy.
const SAG_TAKES := 0.8
const SAG_RETURNS := 4.0
const SAG_DROP := 0.016
const SAG_TURN := 0.05
const HEAVY := 0.55
const Sfx := preload("res://scripts/Audio/Sfx.gd")

var player: CharacterBody3D
var _gulp_in := 0.25
var _gulp := 0.0
var _gulp_span := GULP_FAST
var _sag := 0.0
var _was_held := false
var _last_gulp_begun := false
var _slots: Array = [null, null, null]
var _sides: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO, Vector3.ZERO]


func latch(who: Node3D) -> bool:
	if player == null or player.is_dead or count() >= MOST:
		return false

	var slot := _slots.find(null)
	_slots[slot] = who
	_sides[slot] = _side_for(who)
	latched.emit(who)
	return true


func release(who: Node3D) -> void:
	var at := _slots.find(who)

	if at >= 0:
		_slots[at] = null
		released.emit(who)


## Who is in `slot`, or null.
func who_in(slot: int) -> Node3D:
	var who: Variant = _slots[slot]
	return who if is_instance_valid(who) else null


func on_me() -> Array:
	return _slots.filter(func(who): return is_instance_valid(who))


func count() -> int:
	return on_me().size()


func has_room() -> bool:
	return count() < MOST


func slot_of(who: Node3D) -> int:
	return _slots.find(who)


## A gulp: its hands squeeze (LeechHands.gd), your sight dips, it hauls you toward it,
## and you hear it, and your heart.
func _gulp_now() -> void:
	var will: float = player.power.power / player.power.MAX
	_gulp_in = lerpf(GULP_SLOW, GULP_FAST, will)
	_gulp_span = _gulp_in
	_gulp = 1.0
	var drinker: Node3D = on_me()[randi() % count()]
	var felt := 0.7 + 0.15 * float(count())
	Sfx.play(drinker, &"flesh", drinker.global_position, -5.0, 0.55)
	Sfx.play(drinker, &"anima_moan", drinker.global_position, -8.0, 0.7)
	Sfx.play_flat(self, &"heartbeat", -3.0, lerpf(0.8, 1.0, will))
	player.velocity -= _sides[_slots.find(drinker)] * -GULP_HAUL
	var juice = player.get("juice")

	if juice != null:
		juice.add_trauma(GULP_TRAUMA * felt)
		# Rolled toward it, not aimed at it: a kick here would walk your aim off.
		var way: Vector3 = player.global_basis.inverse() * _sides[_slots.find(drinker)]
		juice.punch(0.0, 0.0, way.x * 1.2 * felt)

	gulped.emit()


## You are dead and it goes on, each gulp slower than the last, to one last long one. Then it has
## no more use for you.
func _finish(delta: float) -> void:
	var death: Node = player.death

	if not death.holding():
		for who in on_me():
			who.lose_interest()

		return

	if death.last_gulp() > 0.0:
		if not _last_gulp_begun:
			_last_gulp_begun = true
			_gulp_now()

		return

	_gulp_in -= delta / death.gulps_slow()

	if _gulp_in <= 0.0:
		_gulp_now()


## The last long gulp as you die, 0 until it starts, then up to 1, and held.
func last_gulp() -> float:
	return float(player.death.last_gulp()) if player != null and player.is_dead else 0.0


## Free: you get your breath, and your head comes up.
func _gasp() -> void:
	_gulp_in = 0.25
	Sfx.play_flat(self, &"whoosh_light", -6.0, 0.72)
	var juice = player.get("juice")

	if juice != null:
		juice.add_trauma(0.08)


## Your gun arm, sinking as your will goes.
func _feel_arm(delta: float) -> void:
	if player == null:
		return

	var wanted := 0.0

	if count() > 0 and not player.is_dead:
		wanted = maxf(1.0 - player.power.power / player.power.MAX, 0.25)

	_sag = move_toward(_sag, wanted, delta * (SAG_TAKES if wanted > _sag else SAG_RETURNS))
	var hand: Node3D = player.get("hand")

	if hand != null:
		var shake := sin(Time.get_ticks_msec() * 0.031) * 0.002 * _sag
		hand.position = Vector3(shake, -SAG_DROP * _sag - 0.005 * _gulp, 0.0)
		hand.rotation.x = -SAG_TURN * _sag


## Whether the one in `slot` is a face, on your face.
func holds_face(slot: int) -> bool:
	var who := who_in(slot)
	return who != null and who.get("form") == &"face"


## Whether the one in `slot` is the mouth, closed on you (LeechCage.gd).
func holds_mouth(slot: int) -> bool:
	var who := who_in(slot)
	return who != null and who.get("form") == &"torso"


## Whether the one in `slot` isn't on any side of you, but before your eyes wherever you look.
func holds_before_you(slot: int) -> bool:
	return holds_face(slot) or holds_mouth(slot)


## How far to the side of your view the face in `slot` is, in metres, if there are others.
func face_offset(slot: int) -> float:
	var faces: Array[int] = []

	for i in _slots.size():
		if holds_face(i):
			faces.append(i)

	return (float(faces.find(slot)) - float(faces.size() - 1) * 0.5) * FACE_APART * 2.0 if faces.size() > 1 else 0.0


## Where the one in `slot` is held, in the world.
func slot_position(slot: int) -> Vector3:
	if holds_face(slot):
		var eyes: Transform3D = player.camera.global_transform
		return eyes.origin - eyes.basis.z * FACE_OUT + eyes.basis.x * face_offset(slot)

	if holds_mouth(slot):
		var eyes: Transform3D = player.camera.global_transform
		return eyes.origin - eyes.basis.z * MOUTH_OUT

	return player.global_position + Vector3.UP * CHEST + _sides[slot] * HOLD_OUT


## The way out from you to the one in `slot`, on the level.
func slot_side(slot: int) -> Vector3:
	return _sides[slot]


## The side it came from, turned clear of any already taken.
func _side_for(who: Node3D) -> Vector3:
	var side := who.global_position - player.global_position
	side.y = 0.0
	side = side.normalized() if side.length() > 0.01 else -player.global_basis.z

	for i in 6:
		var clear := true

		for slot in _slots.size():
			if _slots[slot] != null and _slots[slot] != who and _sides[slot].angle_to(side) < APART:
				clear = false

		if clear:
			break

		side = side.rotated(Vector3.UP, APART)

	return side


## Your pace under them.
func speed() -> float:
	return PACE[count()]


## All thrown off at once: stunned, exposed, and thrown clear.
func free_all() -> void:
	for who in on_me():
		who.throw_off(player.global_position)


## Torn free of them, as a blink does: they lose their hold, and nothing else.
func tear_free() -> void:
	for who in on_me():
		who.let_go()


## The last gulp, felt: 1 as it lands, 0 when it has passed.
func gulp() -> float:
	return _gulp


## How near the next gulp is, 0..1: what the hands wind up on.
func coming() -> float:
	return clampf(1.0 - _gulp_in / maxf(_gulp_span, 0.01), 0.0, 1.0)


## How far your arm has sunk under them, 0..1.
func sag() -> float:
	return _sag


func _physics_process(delta: float) -> void:
	for i in _slots.size():
		if _slots[i] != null and not is_instance_valid(_slots[i]):
			_slots[i] = null

	_gulp = move_toward(_gulp, 0.0, delta / GULP_FADES)
	_feel_arm(delta)

	if player == null or count() == 0:
		Sfx.drain_muffle = 0.0

		if _was_held and player != null and not player.is_dead:
			_gasp()

		_was_held = false
		return

	_was_held = true
	Sfx.drain_muffle = MUFFLE

	# It has you, and finishes (PlayerDeath.gd): no more to take, but it isn't done.
	if player.is_dead:
		_finish(delta)
		return

	_gulp_in -= delta

	if _gulp_in <= 0.0:
		_gulp_now()


	var life := 0.0
	# It comes in lurches: a gulp's share over its fading, the same amount in the end.
	var lurch := BETWEEN_GULPS + _gulp * (1.0 - BETWEEN_GULPS) * _gulp_span / (GULP_FADES * 0.5)

	for who in on_me():
		var taken := minf(float(who.drain_power()) * delta * lurch, player.power.power)
		player.power.power -= taken
		who.fed += taken
		life += float(who.drain_life()) * delta * lurch

	# With nothing left to take, it takes twice as much of the rest.
	player.drain_life(life * (2.0 if player.power.power <= 0.0 else 1.0))
