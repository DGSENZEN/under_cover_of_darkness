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
## Where each sits, in the yaw of your view: in front of you, where it can be seen
## and shot, and off the crosshair. From your chest.
const SLOTS := [Vector3(-0.55, -0.2, -0.6), Vector3(0.55, -0.2, -0.6), Vector3(0.0, -0.55, -0.7)]
const CHEST := 1.45

var player: CharacterBody3D
var _slots: Array = [null, null, null]


func latch(who: Node3D) -> bool:
	if player == null or player.is_dead or count() >= MOST:
		return false

	_slots[_slots.find(null)] = who
	latched.emit(who)
	return true


func release(who: Node3D) -> void:
	var at := _slots.find(who)

	if at >= 0:
		_slots[at] = null
		released.emit(who)


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
	var yaw := Basis(Vector3.UP, player.global_rotation.y)
	return player.global_position + Vector3.UP * CHEST + yaw * SLOTS[slot]


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
		return

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
