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
const Blink := preload("res://scripts/Magic/Blink.gd")
const ShardScript := preload("res://scripts/Magic/Shard.gd")
const WeaponScript := preload("res://scripts/Combat/Weapon.gd")
const Fx := preload("res://scripts/Visual/Fx.gd")
const Sfx := preload("res://scripts/Audio/Sfx.gd")

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
## Q let go within this long is a tap (a step, or the dodge); held longer,
## it aims.
const TAP_TIME := 0.18

## Where the left hand is while it works, in camera space at full size: the
## bare hand palm-forward as its circle closes; the tome open toward you.
const CAST_HAND := Transform3D(Basis(Vector3(0, -0.5, -0.866), Vector3(0, 0.866, -0.5), Vector3(1, 0, 0)), Vector3(-0.2, -0.2, -0.45))
const TOME_HELD := [Vector3(-0.24, -0.32, -0.5), Vector3(0.15, 0.6, -0.78), Vector3(-0.2, -0.78, -0.6)]

var player: CharacterBody3D
var loadout := Loadout.HAND
var selected: StringName = &"shard"

var _casting: StringName = &""
var _cast_t := 0.0
## Seconds Q has been held; -1 while it is up.
var _blink_held := -1.0
var _aiming := false
## Where an aimed blink would land (the body's position), and the lip it
## would hang from ({} for none: Blink.ledge_at).
var _aim_at := Vector3.ZERO
var _aim_ledge := {}
var _ticks := 0


func _ready() -> void:
	player = get_parent() as CharacterBody3D
	_ensure_action(&"spell_1", KEY_1)
	_ensure_action(&"spell_2", KEY_2)
	_ensure_action(&"spell_3", KEY_3)
	_ensure_action(&"grip", KEY_G)
	_ensure_action(&"blink", KEY_Q)


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
	_update_blink(delta)

	if gun and _casting == &"" and not _aiming and Input.is_action_just_pressed("block") and not swallowed:
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


## What each spell does, once cast and paid for.
func _effect(id: StringName) -> void:
	match id:
		&"shard":
			_loose_shard()


## A splinter from the circle, out along your aim: from just ahead of the
## eye, unless something is nearer than that (then from the eye).
func _loose_shard() -> void:
	var at: Transform3D = player.combat.aim()
	var forward := -at.basis.z
	var spawn := at.origin + forward * 0.5
	var clear := PhysicsRayQueryParameters3D.create(at.origin, spawn, 1 | 2, [player.get_rid()])

	if not player.get_world_3d().direct_space_state.intersect_ray(clear).is_empty():
		spawn = at.origin

	var shard: StaticBody3D = ShardScript.new()
	player.get_parent().add_child(shard)
	shard.launch(spawn, forward * ShardScript.SPEED, ShardScript.DAMAGE, player)


# Blink

## Q: a tap steps (the way you are moving, or ahead); held, it aims, and let
## go it goes to the mark (the right mouse lets the aim go, for nothing).
## With a blade or bow drawn on the ground, a tap is the dodge (PlayerCombat)
## and only a hold blinks.
func _update_blink(delta: float) -> void:
	_ticks += 1

	if Input.is_action_just_pressed("blink"):
		_blink_held = 0.0
	elif _blink_held >= 0.0 and Input.is_action_pressed("blink"):
		_blink_held += delta

	if _blink_held >= TAP_TIME and not _aiming and can_cast(&"blink"):
		_aiming = true

	if _aiming:
		var at: Transform3D = player.combat.aim()
		_aim_ledge = Blink.ledge_at(player, at.origin, -at.basis.z, Blink.RANGE)
		_aim_at = _aim_ledge["anchor"] if not _aim_ledge.is_empty() else Blink.arrival(player, at.origin, -at.basis.z, Blink.RANGE)

		if _ticks % 3 == 0:
			Fx.glint(player, _aim_at + (at.origin - player.global_position), 0.08, null, Color(0.75, 0.8, 0.95))

		if Input.is_action_just_pressed("block"):
			_aiming = false
			_blink_held = -1.0
			return

	if _blink_held >= 0.0 and not Input.is_action_pressed("blink"):
		if _aiming:
			_blink_to(_aim_at, _aim_ledge)
		elif not _dodges_instead():
			var at: Transform3D = player.combat.aim()
			_blink_to(Blink.arrival(player, at.origin, _step_direction(), Blink.STEP))

		_blink_held = -1.0
		_aiming = false


## A blade or a bow in hand on the ground: Q tapped is the old dodge.
func _dodges_instead() -> bool:
	var weapon: Resource = player.combat.current_weapon()
	return weapon != null and weapon.kind != WeaponScript.Kind.GUN and player.is_on_floor()


## The way you are moving, level; straight ahead if you are not.
func _step_direction() -> Vector3:
	var axis := Input.get_vector("move_left", "move_right", "move_forward", "move_back")

	if axis.length() < 0.2:
		axis = Vector2(0.0, -1.0)

	var direction: Vector3 = player.global_basis * Vector3(axis.x, 0.0, axis.y)
	direction.y = 0.0
	return direction.normalized()


## Through the glass to `at`, paid for on arrival; nowhere to go is no blink
## and nothing spent. Falling, you go on falling; onto a lip (`ledge`,
## Blink.ledge_at), you hang from it. A guard's blow it takes you
## out of counts as dodged (GuardFighter asks combat.dodged_within).
func _blink_to(at: Vector3, ledge := {}) -> void:
	if not can_cast(&"blink") or at.distance_to(player.global_position) < 0.3:
		return

	if not player.power.pay(float(Spells.info(&"blink")["cost"])):
		player.power.refused()
		return

	var from: Vector3 = player.global_position
	var falling: Vector3 = player.velocity
	var airborne: bool = not player.is_on_floor()
	player.teleport(Transform3D(player.global_basis, at))

	# Onto a lip: hanging from it, as a catch would leave you.
	if not ledge.is_empty():
		player._enter_hang(ledge["normal"], ledge["lip_y"])
	elif airborne:
		player.velocity = falling

	player.combat._dodged_at = player.combat._game_time
	Fx.glint(player, from + Vector3.UP, 0.3, null, Color(0.75, 0.8, 0.95))
	Fx.glint(player, at + Vector3.UP, 0.3, null, Color(0.75, 0.8, 0.95))
	Sfx.play_flat(player, &"whoosh_light", -4.0, 0.7)
	cast_done.emit(&"blink")


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

	if hand.has_method("set_circle"):
		var hand_spell: bool = _casting != &"" and Spells.info(_casting).get("tier") == Spells.Tier.HAND
		hand.set_circle(Spells.info(_casting).get("school", &"") if hand_spell else &"", cast_progress())


func _ensure_action(action: StringName, key: Key) -> void:
	if InputMap.has_action(action):
		return

	InputMap.add_action(action)
	var key_event := InputEventKey.new()
	key_event.physical_keycode = key
	InputMap.action_add_event(action, key_event)
