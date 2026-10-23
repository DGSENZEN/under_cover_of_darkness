extends Node
## The revolver's hand (the right): its two barrels, the kick and the slow
## settle, both hands on the gun, the reload through the gate. Runs as the
## player's "Revolver" child while the revolver is the weapon in hand;
## PlayerCombat stands down for it then, but for the kick.
## Shots follow the head's aim (PlayerCombat.aim), not the camera's shake.

const WeaponScript := preload("res://scripts/Combat/Weapon.gd")
const RagdollScript := preload("res://scripts/Visual/Ragdoll.gd")
const SoundBus := preload("res://scripts/StimuliSystem/SoundBus.gd")
const Fx := preload("res://scripts/Visual/Fx.gd")
const Sfx := preload("res://scripts/Audio/Sfx.gd")
const TimeFx := preload("res://scripts/Visual/TimeFx.gd")

## A shot: `barrel` is "cylinder" or "shot"; `hits` what each ball or pellet
## struck ({target, point, damage, headshot}; target null for the world).
signal fired(barrel: StringName, hits: Array)
## The hammer fell on a spent chamber.
signal clicked_empty

## Stand-ins until the user's recordings (docs/superpowers/refs/
## revolver_sounds.md): each of the revolver's own sounds as [an existing
## sound, volume, pitch].
const SOUNDS := {
	&"gunshot": [&"explosion", -7.0, 1.9],
	&"shellshot": [&"explosion", -4.0, 1.45],
	&"click_empty": [&"gear", -9.0, 1.7],
	&"hammer": [&"gear", -14.0, 1.3],
}

## How far a ball carries, in metres.
const RANGE := 120.0
## One-handed, at the top of the kick, a shot strays this far (degrees).
const SPREAD_ONE_HAND := 2.5
## Where a stray shot goes, in turn: a fixed ring, so a run is repeatable.
const ROSETTE := [Vector2(0.0, 1.0), Vector2(0.87, -0.5), Vector2(-0.87, -0.5), Vector2(0.5, 0.87), Vector2(-1.0, 0.0), Vector2(0.5, -0.87)]
## The camera's kick for a shot from the cylinder, in one hand.
const KICK_TRAUMA := 0.3
const KICK_PUNCH := 0.9

var player: CharacterBody3D
var loaded := {&"cylinder": 6, &"shot": 1}
var barrel: StringName = &"cylinder"
## Both hands on the gun.
var braced := false

var _game_time := 0.0
## When the next shot may go (game time).
var _ready_at := 0.0
## Taking the gun in both hands, or letting one go, until then.
var _grip_until := 0.0
var _kick := 0.0
## Seconds the last kick takes to settle.
var _settle := 0.6
var _shots := 0


func _ready() -> void:
	player = get_parent() as CharacterBody3D
	_ensure_action(&"grip", KEY_G)


func _physics_process(delta: float) -> void:
	_game_time += delta
	_kick = move_toward(_kick, 0.0, delta / maxf(_settle, 0.01))
	var gun: Resource = weapon()

	if gun == null or not player.combat.is_able():
		return

	if Input.is_action_just_pressed("grip"):
		set_braced(not braced)

	var spent: bool = player.is_mouse_input_swallowed() or player.is_attack_press_spent()

	if Input.is_action_just_pressed("throw") and not spent:
		_pull(gun)


## The revolver, when it is the weapon in hand; else null.
func weapon() -> Resource:
	if player == null or player.combat == null or not player.combat.gun_drawn():
		return null

	return player.combat.current_weapon()


func ready_to_fire() -> bool:
	return _game_time >= _ready_at and _game_time >= _grip_until


## The kick, 1 the moment of the shot, easing to 0 as the gun settles.
func kick_amount() -> float:
	return _kick


func aim() -> Transform3D:
	return player.combat.aim()


## Both hands on the gun, or one let go: either takes grip_change seconds,
## with no shot meanwhile.
func set_braced(on: bool) -> void:
	if on == braced:
		return

	braced = on
	var gun: Resource = WeaponScript.find(&"revolver")
	_grip_until = _game_time + gun.grip_change


## Full, settled and in one hand, as a practice bay (and a test) starts.
func reset_for_practice() -> void:
	loaded = {&"cylinder": 6, &"shot": 1}
	barrel = &"cylinder"
	braced = false
	_ready_at = 0.0
	_grip_until = 0.0
	_kick = 0.0


# The shot

func _pull(gun: Resource) -> void:
	if not ready_to_fire():
		return

	if int(loaded[barrel]) <= 0:
		_sound(&"click_empty")
		_ready_at = _game_time + 0.2
		clicked_empty.emit()
		return

	loaded[barrel] = int(loaded[barrel]) - 1
	_shots += 1
	var at := aim()
	var hits: Array = [_ball(at, _stray(at.basis), gun.bullet_damage, gun)]
	var muzzle := _muzzle(at, &"muzzle")
	_kicked(1.0, gun)
	SoundBus.emit_sound(muzzle, gun.shot_db, player, &"gunshot")
	_sound(&"gunshot")
	Fx.flash(player, muzzle, Color(1.0, 0.72, 0.42), 3.0, 6.0, 0.06)
	fired.emit(&"cylinder", hits)


## Where the shot goes: one-handed and still kicking, off along the rosette.
func _stray(aim_basis: Basis) -> Vector3:
	var forward := -aim_basis.z

	if braced or _kick <= 0.001:
		return forward

	var offset: Vector2 = ROSETTE[_shots % ROSETTE.size()] * deg_to_rad(SPREAD_ONE_HAND) * _kick
	return (aim_basis * Vector3(offset.x, offset.y, -1.0)).normalized()


## One ball (or pellet) along `direction`: what it struck, as a hit record.
func _ball(at: Transform3D, direction: Vector3, damage: float, gun: Resource) -> Dictionary:
	var from := at.origin
	var query := PhysicsRayQueryParameters3D.create(from, from + direction * RANGE, 1 | 2 | 4, [player.get_rid()])
	query.hit_from_inside = true
	var hit := player.get_world_3d().direct_space_state.intersect_ray(query)
	var record := {"target": null, "point": from + direction * RANGE, "damage": 0.0, "headshot": false}

	if hit.is_empty():
		return record

	var collider: Object = hit.get("collider")
	var point: Vector3 = hit["position"]
	record["point"] = point

	# A limb: its man's, if he is down but alive.
	if collider is PhysicalBone3D:
		var limb := collider as PhysicalBone3D
		var owner_now := RagdollScript.owner_of(limb)

		if owner_now != null and owner_now.has_method("take_hit"):
			collider = owner_now
		else:
			limb.apply_central_impulse(direction * 4.0)
			Fx.blood(player, point, direction, 0.4)
			return record

	if collider != null and collider.has_method("take_hit"):
		var target := collider as Node3D
		var eye: float = target.get("eye_height") if target.get("eye_height") != null else 1.65
		var headshot := point.y - target.global_position.y >= eye - 0.25
		var dealt: float = damage * (gun.headshot_multiplier if headshot else 1.0)
		record["target"] = target
		record["damage"] = dealt
		record["headshot"] = headshot
		collider.take_hit(dealt, player, &"bullet", point, direction)
		TimeFx.hitstop(get_tree(), 0.04)
		return record

	if collider is RigidBody3D:
		var body := collider as RigidBody3D
		body.apply_impulse(direction * 6.0, point - body.global_position)

	# A powder barrel, a rope.
	if collider != null and collider.has_method("strike"):
		collider.strike(&"bullet", point, direction)

	var normal: Vector3 = hit.get("normal", -direction)
	var surface := "stone"

	if collider is Node and (collider as Node).has_meta(&"surface"):
		surface = String((collider as Node).get_meta(&"surface"))
	elif collider is RigidBody3D or (collider != null and collider.has_method("frob")):
		surface = "wood"

	if surface == "wood":
		Fx.chips(player, point, normal, 0.6)
	else:
		Fx.dust(player, point, normal, 0.6, surface)

	return record


## The muzzle, in the world: out along the aim from the eye, where the
## gun's barrel ends (`which`: "muzzle" or "shot_muzzle").
func _muzzle(at: Transform3D, which: StringName) -> Vector3:
	var gun: Resource = WeaponScript.find(&"revolver")
	var tip: Vector3 = gun.mesh.get_meta(which, Vector3(0, 0.1, -0.32))
	return at.origin + at.basis * Vector3(0.18, -0.18 + tip.y * 0.62, -0.45 + tip.z * 0.62)


## The kick: the camera jolts, and the gun settles over the ready time.
## `strength` 1 for a ball, more for the shell.
func _kicked(strength: float, gun: Resource) -> void:
	var held := 0.5 if braced else 1.0
	_settle = gun.ready_braced if braced else gun.ready_one_hand
	_ready_at = _game_time + _settle
	_kick = 1.0
	player.juice.add_trauma(KICK_TRAUMA * strength * held)
	player.juice.punch(KICK_PUNCH * strength * held, 0.0)


func _sound(name: StringName) -> void:
	var take: Array = SOUNDS.get(name, [name, 0.0, 1.0])
	Sfx.play_flat(player, take[0], take[1], take[2])


func _ensure_action(action: StringName, key: Key) -> void:
	if InputMap.has_action(action):
		return

	InputMap.add_action(action)
	var key_event := InputEventKey.new()
	key_event.physical_keycode = key
	InputMap.action_add_event(action, key_event)
