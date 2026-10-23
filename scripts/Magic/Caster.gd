extends Node
## The left hand's magic: which way it is held with the revolver drawn (a
## bare casting hand, the tome, or both hands on the gun), and the cast
## itself. The more powerful a spell, the longer it takes (Spells.gd): hold
## the right mouse while the circle closes or the pages turn; let go early
## and nothing is cast or spent. Innate spells (cantrips) need no hand; the
## movement ones work from anywhere. Runs as the player's "Caster" child and
## draws on its "Power" (PowerPool.gd).

const Spells := preload("res://scripts/Magic/Spells.gd")
const ViewPoses := preload("res://scripts/Combat/ViewPoses.gd")

signal cast_started(id: StringName)
signal cast_done(id: StringName)
## A hard hit broke a tome spell before it was done (nothing was spent).
signal cast_broken(id: StringName)

enum Loadout {
	HAND,
	TOME,
	BRACED,
}

## A blow this heavy, or of these kinds, breaks a tome spell being cast.
const BREAKS_AT := 25.0
const BREAKING_KINDS := [&"power", &"blast", &"crush"]
## Spell keys, in order.
const KEYED := [&"shard", &"ward", &"empower"]

## Where the left hand is while it works, in camera space at full size: the
## bare hand palm-forward as its circle closes; the tome open toward you.
const CAST_HAND := Transform3D(Basis(Vector3(0, -0.5, -0.866), Vector3(0, 0.866, -0.5), Vector3(1, 0, 0)), Vector3(-0.2, -0.2, -0.45))
const TOME_HELD := [Vector3(-0.24, -0.32, -0.5), Vector3(0.15, 0.6, -0.78), Vector3(-0.2, -0.78, -0.6)]

var player: CharacterBody3D
var loadout := Loadout.HAND
var selected: StringName = &"shard"

var _casting: StringName = &""
var _cast_t := 0.0


func _ready() -> void:
	player = get_parent() as CharacterBody3D
	_ensure_action(&"spell_1", KEY_1)
	_ensure_action(&"spell_2", KEY_2)
	_ensure_action(&"spell_3", KEY_3)
	_ensure_action(&"grip", KEY_G)


func _physics_process(delta: float) -> void:
	var gun: bool = player.combat != null and player.combat.gun_drawn()

	if gun:
		for i in KEYED.size():
			if Input.is_action_just_pressed("spell_%d" % (i + 1)):
				select(KEYED[i])

		if Input.is_action_just_pressed("grip"):
			toggle_braced()

	# Whatever stopped it being castable (the gun put away, up on a hold)
	# ends it, for nothing.
	if _casting != &"" and not can_cast(_casting):
		_cancel()

	var swallowed: bool = player.is_mouse_input_swallowed()

	if gun and _casting == &"" and Input.is_action_just_pressed("block") and not swallowed:
		_begin(selected)

	if _casting != &"":
		if not Input.is_action_pressed("block"):
			_cancel()
		else:
			_cast_t += delta

			if _cast_t >= float(Spells.info(_casting).get("cast_time", 0.0)):
				_complete()

	_show_left()


## The spell keyed for the left hand, and the hand set for it: a hand spell
## bare, a tome spell with the tome. Both hands on the gun let go of it.
func select(id: StringName) -> void:
	var info := Spells.info(id)

	if info.is_empty():
		return

	if _casting != &"" and _casting != id:
		_cancel()

	selected = id
	loadout = Loadout.TOME if info["tier"] == Spells.Tier.TOME else Loadout.HAND
	_set_braced(false)


## G: both hands on the gun, or the left back to its spell.
func toggle_braced() -> void:
	if loadout == Loadout.BRACED:
		select(selected)
		return

	_cancel()
	loadout = Loadout.BRACED
	_set_braced(true)


func casting() -> StringName:
	return _casting


func cast_progress() -> float:
	if _casting == &"":
		return 0.0

	return clampf(_cast_t / maxf(float(Spells.info(_casting).get("cast_time", 0.0)), 0.001), 0.0, 1.0)


## Whether `id` can be cast as you are now. Innate movement spells: always
## (hanging, climbing, carrying, any weapon, in the air). Other innate spells:
## with a hand free (empty hands, or the gun drawn). Hand and tome spells:
## with the gun drawn, the left hand set for them, on your feet.
func can_cast(id: StringName) -> bool:
	var info := Spells.info(id)

	if info.is_empty() or player.is_dead or get_tree().paused:
		return false

	var gun: bool = player.combat.gun_drawn()

	match info["tier"]:
		Spells.Tier.INNATE:
			if info["movement"]:
				return true

			return gun or player.combat.current_weapon() == null
		Spells.Tier.HAND:
			return gun and loadout == Loadout.HAND and player.combat.is_able()
		Spells.Tier.TOME:
			return gun and loadout == Loadout.TOME and player.combat.is_able()

	return false


## Hurt (PlayerController.take_damage): a hard enough hit breaks a tome
## spell being cast.
func on_hit(damage: float, kind: StringName) -> void:
	if _casting == &"" or Spells.info(_casting).get("tier") != Spells.Tier.TOME:
		return

	if damage >= BREAKS_AT or kind in BREAKING_KINDS:
		var id := _casting
		_cancel()
		cast_broken.emit(id)


# The cast

func _begin(id: StringName) -> void:
	if not can_cast(id):
		return

	var cost := float(Spells.info(id)["cost"])

	if not player.power.can_pay(cost):
		player.power.refused()
		return

	_casting = id
	_cast_t = 0.0
	cast_started.emit(id)

	if float(Spells.info(id)["cast_time"]) <= 0.0:
		_complete()


func _complete() -> void:
	var id := _casting
	_casting = &""
	_cast_t = 0.0

	if not player.power.pay(float(Spells.info(id)["cost"])):
		player.power.refused()
		return

	_effect(id)
	cast_done.emit(id)


func _cancel() -> void:
	_casting = &""
	_cast_t = 0.0


## What each spell does, once cast and paid for (Blink, Shard, Ward, Empower
## fill these in).
func _effect(_id: StringName) -> void:
	pass


func _set_braced(on: bool) -> void:
	if player.revolver != null:
		player.revolver.set_braced(on)


# How the left hand looks

## The left hand, with the gun drawn: up and open while a hand spell's
## circle closes, holding the tome open with the tome out; else not ours.
func _show_left() -> void:
	var hand: Node = player.hand

	if hand == null or not hand.has_method("set_left_hold"):
		return

	if not player.combat.gun_drawn():
		hand.set_left_hold(&"", Transform3D.IDENTITY)
	elif loadout == Loadout.TOME:
		hand.set_left_hold(&"tome", ViewPoses.revolver_frame(TOME_HELD))
	elif loadout == Loadout.HAND and _casting != &"":
		hand.set_left_hold(&"cast", CAST_HAND)
	else:
		hand.set_left_hold(&"", Transform3D.IDENTITY)


func _ensure_action(action: StringName, key: Key) -> void:
	if InputMap.has_action(action):
		return

	InputMap.add_action(action)
	var key_event := InputEventKey.new()
	key_event.physical_keycode = key
	InputMap.action_add_event(action, key_event)
