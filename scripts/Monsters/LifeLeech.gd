extends Node
## What is on you and drinking (Anima.gd). It drinks your willpower and your life, a
## little more with each one on you, up to three at once, while you slow under them.
## With no willpower left your life goes twice as fast. Runs as the player's "Leech"
## child, as EvilEyeCurse.gd does.

signal latched(who: Node3D)
signal released(who: Node3D)

const MOST := 3
## Your pace by how many are on you.
const PACE := [1.0, 0.8, 0.65, 0.5]
## Each holds on from the side it came at you, this far out from your chest, and
## stays there as you turn, so you can turn on it and shoot it. No two share a side.
const HOLD_OUT := 0.85
const APART := 1.1
## Your chest, from the middle of you.
const CHEST := 0.15

## A drink: the voice now and then, and your heart slowing as your will goes.
const DRINK_EVERY := 2.6
const HEART_FAST := 0.9
const HEART_SLOW := 1.7
const MUFFLE := 0.65
const Sfx := preload("res://scripts/Audio/Sfx.gd")

var player: CharacterBody3D
var _drink_in := 0.0
var _heart_in := 0.0
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


## Where the one in `slot` is held, in the world.
func slot_position(slot: int) -> Vector3:
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


func _physics_process(delta: float) -> void:
	for i in _slots.size():
		if _slots[i] != null and not is_instance_valid(_slots[i]):
			_slots[i] = null

	if player == null or count() == 0:
		Sfx.drain_muffle = 0.0
		return

	Sfx.drain_muffle = MUFFLE
	_drink_in -= delta
	_heart_in -= delta

	if _drink_in <= 0.0:
		_drink_in = DRINK_EVERY
		var drinker: Node3D = on_me()[randi() % count()]
		Sfx.play(drinker, &"anima_moan", drinker.global_position, -3.0, 0.72)

	if _heart_in <= 0.0:
		var will: float = player.power.power / player.power.MAX
		_heart_in = lerpf(HEART_SLOW, HEART_FAST, will)
		Sfx.play_flat(self, &"heartbeat", -6.0, 0.9)

	if player.is_dead:
		free_all()
		return

	var life := 0.0

	for who in on_me():
		var taken := minf(float(who.drain_power()) * delta, player.power.power)
		player.power.power -= taken
		who.fed += taken
		life += float(who.drain_life()) * delta

	# With nothing left to take, it takes twice as much of the rest.
	player.drain_life(life * (2.0 if player.power.power <= 0.0 else 1.0))
