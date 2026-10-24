extends Node
## The left hand's magic: which way it is held with the revolver drawn (a
## bare casting hand or the tome; aiming, both hands are on the gun), and the cast
## itself. The more powerful a spell, the longer it takes (Spells.gd): hold
## its key (1 Shard, 2 Ward, 3 Empower) while the circle closes or the
## pages turn; let go early and nothing is cast or spent. Innate spells (cantrips) need no hand; the
## movement ones work from anywhere. Runs as the player's "Caster" child and
## draws on its "Power" (PowerPool.gd).

const Spells := preload("res://scripts/Magic/Spells.gd")
const ViewPoses := preload("res://scripts/Combat/ViewPoses.gd")
const Blink := preload("res://scripts/Magic/Blink.gd")
const ShardScript := preload("res://scripts/Magic/Shard.gd")
const WardScript := preload("res://scripts/Magic/Ward.gd")
const MagicFx := preload("res://scripts/Visual/MagicFx.gd")
const MagicView := preload("res://scripts/Visual/MagicView.gd")
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
}

## A blow this heavy, or of these kinds, breaks a tome spell being cast.
const BREAKS_AT := 25.0
const BREAKING_KINDS := [&"power", &"blast", &"crush"]
## Spell keys, in order.
const KEYED := [&"shard", &"ward", &"empower"]
## Seconds the casting hand stays up after a hand spell is let go.
const FOLLOW_THROUGH := 0.18
## Q let go within this long is a tap (a step, or the dodge); held longer,
## it aims.
const TAP_TIME := 0.18
## Empower: how long the beast strength waits for its one use, and how much
## more it gives a blow, a blink's reach, a jump's height.
const EMPOWER_TIME := 8.0
const EMPOWER_BLOW := 3.0
const EMPOWER_REACH := 2.0
## A jump spends it only if the key is still held this long after takeoff.
const EMPOWER_JUMP_HOLD := 0.2

## Where the left hand is while it works, in camera space at full size: the
## bare hand palm-forward as its circle closes; the tome open toward you.
const CAST_HAND := Transform3D(Basis(Vector3(0, -0.5, -0.866), Vector3(0, 0.866, -0.5), Vector3(1, 0, 0)), Vector3(-0.2, -0.2, -0.45))
const TOME_HELD := [Vector3(-0.24, -0.32, -0.5), Vector3(0.15, 0.6, -0.78), Vector3(-0.2, -0.78, -0.6)]

var player: CharacterBody3D
var loadout := Loadout.HAND
var selected: StringName = &"shard"

var _casting: StringName = &""
var _cast_t := 0.0
## The spell whose key is held (&"" for none), and whether this press has
## begun its cast (one cast for one press).
var _held_key: StringName = &""
var _begun_this_press := false
## Seconds Q has been held; -1 while it is up.
var _blink_held := -1.0
var _aiming := false
## Where an aimed blink would land (the body's position), and the lip it
## would hang from ({} for none: Blink.ledge_at).
var _aim_at := Vector3.ZERO
var _aim_ledge := {}
var _ticks := 0
var _game_time := 0.0
## When a hand spell was last let go (game time): the hand stays up a moment
## after, pushing out (FOLLOW_THROUGH).
var _loosed_at := -INF
## Empower's charge waits until then (game time); -1 when there is none.
var empowered_until := -1.0


func _ready() -> void:
	player = get_parent() as CharacterBody3D
	_ensure_action(&"spell_1", KEY_1)
	_ensure_action(&"spell_2", KEY_2)
	_ensure_action(&"spell_3", KEY_3)
	_ensure_action(&"blink", KEY_Q)


func _physics_process(delta: float) -> void:
	_game_time += delta
	var gun: bool = player.combat != null and player.combat.gun_drawn()

	if empowered_until >= 0.0 and _game_time >= empowered_until:
		empowered_until = -1.0

	_empowered_jump()

	# A spell key: that spell, its hand raised (the revolver drawn for it if
	# something else is in hand, the sights let go of).
	for i in KEYED.size():
		if Input.is_action_just_pressed("spell_%d" % (i + 1)):
			_press_key(KEYED[i])

	if _held_key != &"" and not Input.is_action_pressed(_key_action(_held_key)):
		_held_key = &""

	# Whatever stopped it being castable (the gun put away, up on a hold),
	# or the key let go of, ends it, for nothing.
	if _casting != &"" and (not can_cast(_casting) or _held_key != _casting):
		_cancel()

	_update_blink(delta)

	# Held, and ready: the circle begins to close, or the pages to turn.
	if _held_key != &"" and _casting == &"" and not _aiming and not _begun_this_press and player.combat.gun_drawn() and can_cast(_held_key):
		_begun_this_press = true
		_begin(_held_key)

	if _casting != &"":
		_cast_t += delta

		if _cast_t >= float(Spells.info(_casting).get("cast_time", 0.0)):
			_complete()

	_show_left()
	_show_empower(delta)


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


## A spell key pressed: that spell, the hand set for it; the revolver
## drawn if something else is in hand; the sights let go of.
func _press_key(id: StringName) -> void:
	select(id)
	_held_key = id
	_begun_this_press = false

	if not player.combat.gun_drawn() and player.inventory.count_of(&"revolver") > 0:
		player.inventory.select_by_id(&"revolver")

	if player.revolver != null:
		player.revolver.drop_aim()


func _key_action(id: StringName) -> String:
	return "spell_%d" % (KEYED.find(id) + 1)


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
			return gun and loadout == Loadout.HAND and player.combat.is_able() and not _aiming_gun()
		Spells.Tier.TOME:
			return gun and loadout == Loadout.TOME and player.combat.is_able() and not _aiming_gun()

	return false


## Up at the eye with both hands on the gun: the left hand is not free.
func _aiming_gun() -> bool:
	return player.revolver != null and player.revolver.aim_amount() > 0.0


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

	if Spells.info(id).get("tier") == Spells.Tier.HAND:
		_loosed_at = _game_time

		if player.hand != null and player.hand.has_method("release_cast"):
			player.hand.release_cast(Spells.info(id).get("school", &""))

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
			# Thrown from the hand: a small kick to the view.
			player.juice.punch(0.8, 0.15)
		&"ward":
			WardScript.cast_on(player)
		&"empower":
			empowered_until = _game_time + EMPOWER_TIME
			Sfx.play_flat(player, &"heartbeat", -2.0, 0.85)
			player.juice.add_trauma(0.2)


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
	# Seen leaving the circle at your hand.
	var seen: Vector3 = player.hand.circle_world_position() if player.hand != null and player.hand.has_method("circle_world_position") else Vector3.INF
	shard.launch(spawn, forward * ShardScript.SPEED, ShardScript.DAMAGE, player, seen)


# Empower

## A charge of beast strength waiting for its one use.
func empowered() -> bool:
	return empowered_until >= 0.0


## Spends the charge on `use` ("blow", "shot", "jump", "blink"): true once,
## and then it is gone; false with none. Where it lands (`at`, square to
## `facing`), its shockwave.
func spend_empower(use: StringName, at := Vector3.INF, facing := Vector3.UP) -> bool:
	if not empowered():
		return false

	empowered_until = -1.0
	_show_beast(0.0)

	# The ring square to `facing`: the way a blow or a shot went, so you see
	# it whole; flat on the ground at your feet for a jump or a blink.
	if at != Vector3.INF:
		MagicFx.shockwave(player, at, facing)
	Sfx.play_flat(player, &"roar", -10.0, 0.7)
	player.juice.add_trauma(0.25)
	return use != &""


## The jump: still held a moment after takeoff, it spends the charge and goes
## on to twice the height (a hop let go at once leaves it be).
func _empowered_jump() -> void:
	if not empowered() or player.is_on_floor() or not Input.is_action_pressed("jump") or player.velocity.y <= 0.0:
		return

	var since: float = player._game_time - float(player.last_jump_at)

	if since < EMPOWER_JUMP_HOLD or since > EMPOWER_JUMP_HOLD + 0.1:
		return

	if not spend_empower(&"jump", player.global_position - Vector3.UP * Blink._origin_above_feet(player)):
		return

	var gravity: float = player.gravity
	var normal_top: float = player.jump_speed * player.jump_speed / (2.0 * gravity)
	var risen: float = player.global_position.y - float(player.last_jump_from_y)
	var still := maxf(normal_top * 2.0 - risen, 0.0)
	player.velocity.y = sqrt(2.0 * gravity * still)


# Blink

## Q: a tap steps (the way you are moving, or ahead); held, it aims, and let
## go it goes to the mark (a fresh right mouse lets the aim go, for nothing).
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
		_aim_ledge = Blink.ledge_at(player, at.origin, -at.basis.z, Blink.RANGE * _reach_scale())
		_aim_at = _aim_ledge["anchor"] if not _aim_ledge.is_empty() else Blink.arrival(player, at.origin, -at.basis.z, Blink.RANGE * _reach_scale())

		if _ticks % 3 == 0:
			Fx.glint(player, _aim_at + (at.origin - player.global_position), 0.08, null, Color(0.75, 0.8, 0.95))

		# A fresh right mouse lets it go (and raises no sights).
		if Input.is_action_just_pressed("aim"):
			if player.revolver != null:
				player.revolver.drop_aim()

			_aiming = false
			_blink_held = -1.0
			return

	if _blink_held >= 0.0 and not Input.is_action_pressed("blink"):
		if _aiming:
			_blink_to(_aim_at, _aim_ledge)
		elif not _dodges_instead():
			var at: Transform3D = player.combat.aim()
			_blink_to(Blink.arrival(player, at.origin, _step_direction(), Blink.STEP * _reach_scale()))

		_blink_held = -1.0
		_aiming = false


## Empowered, a blink reaches twice as far.
func _reach_scale() -> float:
	return EMPOWER_REACH if empowered() else 1.0


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

	# Empowered, the charge went into this one's reach (its wave where you land).
	var beast := spend_empower(&"blink")
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
	# A mirror-crack where you stood, the cold of the glass as you pass, a
	# ripple where you land.
	MagicFx.mirror_crack(player, from)
	MagicView.cold(get_tree())
	MagicFx.ripple(player, player.global_position)

	if beast:
		MagicFx.shockwave(player, player.global_position - Vector3.UP * Blink._origin_above_feet(player))
	Sfx.play_flat(player, &"whoosh_light", -4.0, 0.7)
	cast_done.emit(&"blink")


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
	elif loadout == Loadout.HAND and (_casting != &"" or _game_time - _loosed_at < FOLLOW_THROUGH):
		hand.set_left_hold(&"cast", CAST_HAND)
	else:
		hand.set_left_hold(&"", Transform3D.IDENTITY)

	if hand.has_method("set_circle"):
		var hand_spell: bool = _casting != &"" and Spells.info(_casting).get("tier") == Spells.Tier.HAND
		hand.set_circle(Spells.info(_casting).get("school", &"") if hand_spell else &"", cast_progress())


## Empower in your hands: the pages turning while it is read; while its
## charge waits, the pelt-shadow on the arm (eased in) and the pulse at the
## edges of the view.
func _show_empower(delta: float) -> void:
	var hand: Node = player.hand

	if hand == null or not hand.has_method("set_tome_flutter"):
		return

	hand.set_tome_flutter(cast_progress() if _casting == &"empower" else 0.0)
	var pelt: float = minf(float(hand.pelt_amount()) + delta / 0.3, 1.0) if empowered() else 0.0
	_show_beast(pelt)


func _show_beast(amount: float) -> void:
	var hand: Node = player.hand

	if hand != null and hand.has_method("set_pelt"):
		hand.set_pelt(amount)

	MagicView.of(get_tree()).set_beast(amount)


func _ensure_action(action: StringName, key: Key) -> void:
	if InputMap.has_action(action):
		return

	InputMap.add_action(action)
	var key_event := InputEventKey.new()
	key_event.physical_keycode = key
	InputMap.action_add_event(action, key_event)
