extends Node
## The revolver's hand (the right): its two barrels, the kick and the slow
## settle, both hands on the gun, the reload through the gate. Runs as the
## player's "Revolver" child while the revolver is the weapon in hand;
## PlayerCombat stands down for it then, but for the kick.
## Shots follow the head's aim (PlayerCombat.aim), not the camera's shake.

const WeaponScript := preload("res://scripts/Combat/Weapon.gd")
const RagdollScript := preload("res://scripts/Visual/Ragdoll.gd")
const ViewPoses := preload("res://scripts/Combat/ViewPoses.gd")
const WardScript := preload("res://scripts/Magic/Ward.gd")
const SoundBus := preload("res://scripts/StimuliSystem/SoundBus.gd")
const Fx := preload("res://scripts/Visual/Fx.gd")
const Sfx := preload("res://scripts/Audio/Sfx.gd")
const TimeFx := preload("res://scripts/Visual/TimeFx.gd")

## A shot: `barrel` is "cylinder" or "shot"; `hits` what each ball or pellet
## struck ({target, point, damage, headshot}; target null for the world).
signal fired(barrel: StringName, hits: Array)
## The hammer fell on a spent chamber.
signal clicked_empty
## A shot found a man: "shot" (the body), "headshot", or "kill".
signal hit_confirmed(kind: StringName)

## Stand-ins until the user's recordings (docs/superpowers/refs/
## revolver_sounds.md): each of the revolver's own sounds as [an existing
## sound, volume, pitch].
const SOUNDS := {
	&"gunshot": [&"explosion", -7.0, 1.9],
	&"shellshot": [&"explosion", -4.0, 1.45],
	&"click_empty": [&"gear", -9.0, 1.7],
	&"hammer": [&"gear", -14.0, 1.3],
	&"gate": [&"unlock", -10.0, 1.5],
	&"round_in": [&"coins", -12.0, 1.6],
	&"hit_tick": [&"ting", -10.0, 1.8],
	&"kill_tick": [&"thud", -6.0, 0.7],
}

## How far a ball carries, in metres.
const RANGE := 120.0
## One-handed, at the top of the kick, a shot strays this far (degrees).
const SPREAD_ONE_HAND := 2.5
## Where a stray shot goes, in turn: a fixed ring, so a run is repeatable.
const ROSETTE := [Vector2(0.0, 1.0), Vector2(0.87, -0.5), Vector2(-0.87, -0.5), Vector2(0.5, 0.87), Vector2(-1.0, 0.0), Vector2(0.5, -0.87)]
## The camera's kick for a shot from the cylinder, in one hand.
const KICK_TRAUMA := 0.38
const KICK_PUNCH := 2.1
## The kick throws the aim itself (the neck's pitch, the body's yaw), in
## degrees: up from the hip, up aimed, and to the side as far as this along
## YAW_PATTERN by shot. Then RECOVER of the climb comes back by itself over
## the settle; the rest is yours to pull down.
const KICK_PITCH := 3.5
const KICK_PITCH_AIMED := 1.75
const KICK_YAW_MAX := 0.8
const YAW_PATTERN := [0.6, -0.3, 0.8, -0.7, 0.2, -0.5]
const SHELL_CLIMB := 1.4
const RECOVER := 0.6
## The shell kicks harder than a ball.
const SHELL_KICK := 1.4
## Seconds the thumb takes on the hammer's nose.
const FLIP_TIME := 0.15
## Pellets of one shell into one man, inside blast_range: a blast.
const BLAST_PELLETS := 6
## Empowered, a shell is one blast into a man this near (metres).
const EMPOWERED_SHELL_RANGE := 6.0
## The hold on a hit, and on a kill (real seconds).
const HIT_HITSTOP := 0.04
const KILL_HITSTOP := 0.07
## A ball this close by a man's chest is a near miss to him (metres).
const NEAR_MISS := 1.5
## Aiming down the sights: seconds up and down, the view narrowed by this
## many degrees (75 to 62), and walking at this much of your pace.
const AIM_RAISE := 0.18
const AIM_LOWER := 0.15
const AIM_FOV_CUT := 13.0
const AIM_SPEED := 0.7
## Seconds for the gate to snap shut when you fire mid-reload.
const GATE_SNAP := 0.1
## The pistol-whip: a man this near (metres), this far off your aim
## (degrees); the blow lands this far in, and it is over by WHIP_TIME.
const WHIP_REACH := 1.3
const WHIP_CONE := 35.0
const WHIP_LANDS := 0.15
const WHIP_TIME := 0.35
const WHIP_DAMAGE := 20.0

## A reload under way: the gate opening (or shutting), rounds going in, or
## the shell.
enum Load {
	NONE,
	GATE,
	ROUNDS,
	SHELL,
}

var player: CharacterBody3D
var loaded := {&"cylinder": 6, &"shot": 1}
var loading := Load.NONE
var barrel: StringName = &"cylinder"
## Up at the eye, both hands on the gun (right mouse held, fully raised).
var aimed := false

var _game_time := 0.0
## When the next shot may go (game time).
var _ready_at := 0.0
## How far up to the eye the gun is, 0 at the hip to 1 aimed.
var _aim := 0.0
## Dropped (a reload, a spell key) until right mouse is let go.
var _aim_dropped := false
## The view is narrowed for the aim (set_zoom), to be given back.
var _zoomed := false
## The thumb at the hammer's nose, until then.
var _flip_until := 0.0
## Seconds into the step of the reload under way.
var _load_t := 0.0
## The gate shutting (GATE), not opening.
var _gate_shutting := false
## A shot asked for mid-reload: it goes once the gate is shut.
var _owed_shot := false
var _kick := 0.0
## The last shot's climb of the aim (radians, as thrown: pitch, yaw), and
## how far into coming back it is (seconds).
var _climb := Vector2.ZERO
var _climb_t := -1.0
## Seconds the last kick takes to settle.
var _settle := 0.6
var _shots := 0

# How it is shown: each eased toward what is wanted, 0..1.
var _gate_shown := 0.0
var _flip_shown := 0.0
var _sprint_shown := 0.0
var _boot_shown := 0.0
var _whip_shown := 0.0
## Seconds into a pistol-whip; -1 when none.
var _whip_t := -1.0
var _whip_target: Node3D = null
## The cylinder's turn as drawn (radians), catching up with the shots.
var _turn_shown := 0.0


func _ready() -> void:
	player = get_parent() as CharacterBody3D
	_ensure_action(&"barrel", KEY_X)
	_ensure_action(&"reload", KEY_R)
	_ensure_action(&"aim", KEY_NONE, MOUSE_BUTTON_RIGHT)


func _physics_process(delta: float) -> void:
	_game_time += delta
	_kick = move_toward(_kick, 0.0, delta / maxf(_settle, 0.01))
	_recover_climb(delta)
	var gun: Resource = weapon()
	_update_whip(delta)

	var able: bool = gun != null and player.combat.is_able()
	_update_aim(delta, able)

	if gun != null:
		_send_pose(delta)

	# Put away, up on a hold, carrying: a reload under way is over. Only the
	# rounds already in are spent.
	if not able:
		_stop_loading()
		return

	if Input.is_action_just_pressed("barrel"):
		_stop_loading()
		flip_barrel()

	if Input.is_action_just_pressed("reload") and loading == Load.NONE:
		_start_loading(gun)

	var spent: bool = player.is_mouse_input_swallowed() or player.is_attack_press_spent()

	if Input.is_action_just_pressed("throw") and not spent:
		if loading == Load.NONE:
			_pull(gun)
		else:
			# Mid-reload: the gate snaps shut and the shot goes.
			_stop_loading()
			_owed_shot = true
			_ready_at = maxf(_ready_at, _game_time + GATE_SNAP)

	if loading != Load.NONE:
		_update_loading(delta, gun)
	elif _owed_shot and ready_to_fire():
		_owed_shot = false
		_pull(gun)


## The revolver, when it is the weapon in hand; else null.
func weapon() -> Resource:
	if player == null or player.combat == null or not player.combat.gun_drawn():
		return null

	return player.combat.current_weapon()


func ready_to_fire() -> bool:
	return loading == Load.NONE and _whip_t < 0.0 and _game_time >= _ready_at and _game_time >= _flip_until


func is_reloading() -> bool:
	return loading != Load.NONE


## How far open the loading gate is, 0 shut to 1 open.
func gate_open() -> float:
	var gun: Resource = WeaponScript.find(&"revolver")
	var t := clampf(_load_t / maxf(gun.gate_time, 0.01), 0.0, 1.0)

	match loading:
		Load.GATE:
			return 1.0 - t if _gate_shutting else t
		Load.ROUNDS:
			return 1.0

	return 0.0


## The thumb flicks the hammer's nose: the other barrel fires next.
func flip_barrel() -> void:
	barrel = &"shot" if barrel == &"cylinder" else &"cylinder"
	_flip_until = _game_time + FLIP_TIME
	_sound(&"hammer")


## The nine pellets of a shell about the aim: one down the middle, eight on
## a fixed ring half the cone's width out.
func pellet_dirs(aim_basis: Basis) -> Array[Vector3]:
	var gun: Resource = WeaponScript.find(&"revolver")
	var dirs: Array[Vector3] = [-aim_basis.z]
	var ring: float = tan(deg_to_rad(gun.spread_degrees * 0.5))
	var others: int = int(gun.pellets) - 1

	for i in others:
		var turn := TAU * float(i) / float(others)
		dirs.append((aim_basis * Vector3(cos(turn) * ring, sin(turn) * ring, -1.0)).normalized())

	return dirs


## The kick, 1 the moment of the shot, easing to 0 as the gun settles.
func kick_amount() -> float:
	return _kick


func aim() -> Transform3D:
	return player.combat.aim()


## How far up to the eye the gun is: 0 at the hip, 1 aimed.
func aim_amount() -> float:
	return _aim


## The aim let go of until right mouse is pressed again (a reload, a spell
## key: the left hand is wanted elsewhere).
func drop_aim() -> void:
	if _aim > 0.0 or Input.is_action_pressed("aim"):
		_aim_dropped = true


## Right mouse: up to the eye over AIM_RAISE, down over AIM_LOWER; the view
## narrowed by AIM_FOV_CUT as it comes up. Gone at once when the gun is.
func _update_aim(delta: float, able: bool) -> void:
	var held := Input.is_action_pressed("aim")

	if not held:
		_aim_dropped = false

	if not able:
		_aim = 0.0
	else:
		# Raising the sights stops a reload, as a shot does.
		if Input.is_action_just_pressed("aim") and loading != Load.NONE:
			_stop_loading()

		var wanted := held and not _aim_dropped and loading == Load.NONE
		_aim = move_toward(_aim, 1.0 if wanted else 0.0, delta / (AIM_RAISE if wanted else AIM_LOWER))

	aimed = _aim >= 1.0

	if _aim > 0.0 or _zoomed:
		player.juice.set_zoom(AIM_FOV_CUT * _aim)
		_zoomed = _aim > 0.0


## Full, settled and in one hand, as a practice bay (and a test) starts.
func reset_for_practice() -> void:
	loaded = {&"cylinder": 6, &"shot": 1}
	barrel = &"cylinder"
	_ready_at = 0.0
	_aim = 0.0
	aimed = false
	_aim_dropped = false
	_flip_until = 0.0
	_kick = 0.0
	_owed_shot = false
	_whip_t = -1.0
	_whip_target = null
	_stop_loading()


# The pistol-whip

## F with a man in arm's reach and in front of you: the gun's butt, not the
## boot (PlayerCombat asks first). False with nobody there.
func try_whip() -> bool:
	if weapon() == null or _whip_t >= 0.0:
		return false

	var at := aim()
	var ahead := -at.basis.z
	ahead.y = 0.0
	var best: Node3D = null
	var nearest := WHIP_REACH

	for guard in get_tree().get_nodes_in_group(&"guards"):
		if not (guard is Node3D) or not guard.has_method("take_hit") or float(guard.get("health")) <= 0.0:
			continue

		var to: Vector3 = (guard as Node3D).global_position - player.global_position
		to.y = 0.0
		var reach := to.length()

		if reach > nearest or reach < 0.01:
			continue

		if rad_to_deg(ahead.normalized().angle_to(to / reach)) > WHIP_CONE:
			continue

		best = guard
		nearest = reach

	if best == null:
		return false

	_stop_loading()
	_whip_t = 0.0
	_whip_target = best
	Sfx.play_flat(player, &"whoosh_light", -6.0, 1.2)
	return true


func _update_whip(delta: float) -> void:
	if _whip_t < 0.0:
		return

	var before := _whip_t
	_whip_t += delta

	if before < WHIP_LANDS and _whip_t >= WHIP_LANDS and is_instance_valid(_whip_target):
		var at: Vector3 = _whip_target.eye_position() if _whip_target.has_method("eye_position") else _whip_target.global_position + Vector3.UP * 1.6
		var blow: Vector3 = (at - aim().origin).normalized()

		# Empowered (Caster.gd): three times the blow, and it throws him.
		if player.caster != null and player.caster.spend_empower(&"blow"):
			_hint_gib(_whip_target, true)
			_whip_target.take_hit(WHIP_DAMAGE * player.caster.EMPOWER_BLOW, player, &"blast", at, blow)
			_hint_gib(_whip_target, false)
		else:
			_whip_target.take_hit(WHIP_DAMAGE, player, &"power", at, blow)
		player.juice.add_trauma(0.25)
		player.juice.punch(0.3, 0.0)
		Sfx.play(player, &"thud", at, 0.0, 0.9)

	if _whip_t >= WHIP_TIME:
		_whip_t = -1.0
		_whip_target = null


# The reload

## R: the selected barrel. The cylinder through the gate, round by round
## while there are rounds and room; the shot barrel's one shell.
func _start_loading(gun: Resource) -> void:
	if barrel == &"cylinder":
		if int(loaded[&"cylinder"]) >= int(gun.rounds) or int(player.inventory.ammo.get(&"rounds", 0)) <= 0:
			return

		loading = Load.GATE
		_gate_shutting = false
		drop_aim()
	else:
		if int(loaded[&"shot"]) >= int(gun.shells) or int(player.inventory.ammo.get(&"shells", 0)) <= 0:
			return

		loading = Load.SHELL
		drop_aim()

	_load_t = 0.0
	_owed_shot = false
	_sound(&"gate")


func _update_loading(delta: float, gun: Resource) -> void:
	_load_t += delta

	match loading:
		Load.GATE:
			if _load_t < gun.gate_time:
				return

			if _gate_shutting:
				loading = Load.NONE
				_sound(&"gate")
			else:
				loading = Load.ROUNDS
				_load_t = 0.0
		Load.ROUNDS:
			if _load_t < gun.round_load:
				return

			# Each round is taken from the stock as it goes in, not before.
			_load_t = 0.0

			if player.inventory.take_ammo(&"rounds", 1) == 1:
				loaded[&"cylinder"] = int(loaded[&"cylinder"]) + 1
				_sound(&"round_in")

			if int(loaded[&"cylinder"]) >= int(gun.rounds) or int(player.inventory.ammo.get(&"rounds", 0)) <= 0:
				loading = Load.GATE
				_gate_shutting = true
		Load.SHELL:
			if _load_t < gun.shell_load:
				return

			if player.inventory.take_ammo(&"shells", 1) == 1:
				loaded[&"shot"] = int(loaded[&"shot"]) + 1
				_sound(&"round_in")

			loading = Load.NONE


## Whatever reload was under way is over, nothing taken for a round not yet in.
func _stop_loading() -> void:
	loading = Load.NONE
	_load_t = 0.0
	_gate_shutting = false


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

	# Empowered (Caster.gd): this shot carries the beast strength.
	var empowered: bool = player.caster != null and player.caster.spend_empower(&"shot")

	if barrel == &"shot":
		_shell(at, gun, empowered)
		return

	var direction := _stray(at.basis)
	var record := _trace(at.origin, direction)
	_apply(record, direction, gun.bullet_damage, &"blast" if empowered else &"bullet", gun)
	_near_misses(at.origin, record)
	var muzzle := _muzzle(at, &"muzzle")
	_kicked(1.0, gun)
	SoundBus.emit_sound(muzzle, gun.shot_db, player, &"gunshot")
	_sound(&"gunshot")
	Fx.flash(player, muzzle, Color(1.0, 0.72, 0.42), 3.0, 6.0, 0.06)
	fired.emit(&"cylinder", [record])


## The shell: its pellets traced first, then dealt. Most of them into one man
## close by are one blast, not pellets.
func _shell(at: Transform3D, gun: Resource, empowered := false) -> void:
	var records: Array = []
	var dirs := pellet_dirs(at.basis)
	var into := {}

	for direction in dirs:
		var record := _trace(at.origin, direction)
		record["direction"] = direction
		var reach: float = at.origin.distance_to(record["point"])
		var falloff: float = 1.0 - clampf((reach - gun.falloff_start) / maxf(gun.falloff_end - gun.falloff_start, 0.01), 0.0, 1.0)
		record["damage"] = gun.pellet_damage * falloff
		records.append(record)

		if record["target"] != null:
			into[record["target"]] = into.get(record["target"], []) + [record]

	for target in into.keys():
		var group: Array = into[target]
		var close: bool = at.origin.distance_to(group[0]["point"]) <= gun.blast_range
		# Empowered, every pellet into a man within EMPOWERED_SHELL_RANGE is one blast.
		var beast: bool = empowered and at.origin.distance_to(group[0]["point"]) <= EMPOWERED_SHELL_RANGE

		if ((close and group.size() >= BLAST_PELLETS) or beast) and is_instance_valid(target):
			var total := 0.0

			for record in group:
				total += float(record["damage"])

			var middle: Dictionary = group[0]
			# Point-blank, or empowered: it bursts him if it kills him.
			_hint_gib(target, true)
			_confirm(target.take_hit(total, player, &"blast", middle["point"], -at.basis.z), false)
			_hint_gib(target, false)
			continue

		var felt := false

		for record in group:
			if is_instance_valid(target) and float(record["damage"]) > 0.0:
				_deal(target, record, record["direction"], record["damage"], &"shot", gun)
				felt = true

		if felt:
			_confirm(&"hit" if is_instance_valid(target) and float(target.get("health")) > 0.0 else &"killed", false)

	for record in records:
		if record["target"] == null:
			_strike_world(record, record["direction"])

	# The shell's middle pellet: who it went close by.
	_near_misses(at.origin, records[0])


	var muzzle := _muzzle(at, &"shot_muzzle")
	_kicked(SHELL_KICK, gun)
	SoundBus.emit_sound(muzzle, gun.shell_db, player, &"gunshot")
	_sound(&"shellshot")
	Fx.flash(player, muzzle, Color(1.0, 0.68, 0.38), 4.0, 7.0, 0.07)
	fired.emit(&"shot", records)


## Where the shot goes: one-handed and still kicking, off along the rosette.
func _stray(aim_basis: Basis) -> Vector3:
	var forward := -aim_basis.z

	if aimed or _kick <= 0.001:
		return forward

	var offset: Vector2 = ROSETTE[_shots % ROSETTE.size()] * deg_to_rad(SPREAD_ONE_HAND) * _kick
	return (aim_basis * Vector3(offset.x, offset.y, -1.0)).normalized()


## What a ball (or pellet) along `direction` from `from` strikes, as a hit
## record: {target (a man, or null), point, damage, headshot, collider,
## normal}. Nothing is dealt yet.
func _trace(from: Vector3, direction: Vector3) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(from, from + direction * RANGE, 1 | 2 | 4, [player.get_rid()])
	query.hit_from_inside = true
	var hit := player.get_world_3d().direct_space_state.intersect_ray(query)
	var record := {"target": null, "point": from + direction * RANGE, "damage": 0.0, "headshot": false, "collider": null, "normal": -direction}

	if hit.is_empty():
		return record

	# A ward in the way (another's: yours lets your shots out) takes it.
	var warded := WardScript.stops(from, hit["position"], player)

	if warded != Vector3.INF:
		record["point"] = warded
		WardScript.turned_aside(player, warded, direction)
		return record

	var collider: Object = hit.get("collider")
	record["point"] = hit["position"]
	record["normal"] = hit.get("normal", -direction)

	# A limb: its man's, if he is down but alive.
	if collider is PhysicalBone3D:
		var owner_now := RagdollScript.owner_of(collider)

		if owner_now != null and owner_now.has_method("take_hit"):
			collider = owner_now

	record["collider"] = collider

	if collider != null and collider.has_method("take_hit"):
		record["target"] = collider

	return record


## A ball's record dealt: to the man it found, or into the world.
func _apply(record: Dictionary, direction: Vector3, damage: float, kind: StringName, gun: Resource) -> void:
	if record["target"] != null:
		_deal(record["target"], record, direction, damage, kind, gun)
	else:
		_strike_world(record, direction)


## A man to burst if this blow kills him (Guard.gib_hint), or not.
static func _hint_gib(target: Object, on: bool) -> void:
	if is_instance_valid(target) and target.get("gib_hint") != null:
		target.set("gib_hint", on)


## Every man the ball went close by and missed (within NEAR_MISS of his
## chest): he starts, and his squad reads the gun (Guard.near_miss).
func _near_misses(from: Vector3, record: Dictionary) -> void:
	var to: Vector3 = record["point"]

	for guard in get_tree().get_nodes_in_group(&"guards"):
		if guard == record["target"] or not (guard is Node3D) or not guard.has_method("near_miss"):
			continue

		var chest: Vector3 = (guard as Node3D).global_position + Vector3.UP * 1.2
		var nearest := Geometry3D.get_closest_point_to_segment(chest, from, to)

		if nearest.distance_to(chest) <= NEAR_MISS:
			guard.near_miss(player, nearest)


## Into a man: a ball in the head takes the headshot's multiple (not a
## pellet: a shell's harm is in how many find him).
func _deal(target: Node3D, record: Dictionary, direction: Vector3, damage: float, kind: StringName, gun: Resource) -> void:
	var point: Vector3 = record["point"]
	var eye: float = target.get("eye_height") if target.get("eye_height") != null else 1.65
	var headshot := kind != &"shot" and point.y - target.global_position.y >= eye - 0.25
	var dealt: float = damage * (gun.headshot_multiplier if headshot else 1.0)
	record["damage"] = dealt
	record["headshot"] = headshot
	var result: StringName = target.take_hit(dealt, player, kind, point, direction)

	# A pellet's mark is the shell's, once (_shell).
	if kind != &"shot":
		_confirm(result, headshot)


## A hit felt: the crosshair's mark, a tick, a hold (a kill's the longer).
func _confirm(result: StringName, headshot: bool) -> void:
	if result == &"none" or result == &"blocked" or result == &"parried":
		return

	var killed := result == &"killed"
	TimeFx.hitstop(get_tree(), KILL_HITSTOP if killed else HIT_HITSTOP)
	_sound(&"hit_tick")

	if killed:
		_sound(&"kill_tick")

	hit_confirmed.emit(&"kill" if killed else (&"headshot" if headshot else &"shot"))


## Into the world: a limb of the dead knocked, a crate shoved, a powder
## barrel struck, dust or chips where it lands.
func _strike_world(record: Dictionary, direction: Vector3) -> void:
	var collider: Object = record["collider"]
	var point: Vector3 = record["point"]

	if collider == null or not is_instance_valid(collider):
		return

	if collider is PhysicalBone3D:
		(collider as PhysicalBone3D).apply_central_impulse(direction * 4.0)
		Fx.blood(player, point, direction, 0.4)
		return

	if collider is RigidBody3D:
		var body := collider as RigidBody3D
		body.apply_impulse(direction * 6.0, point - body.global_position)

	# A powder barrel, a rope.
	if collider.has_method("strike"):
		collider.strike(&"bullet", point, direction)

	var normal: Vector3 = record["normal"]
	var surface := "stone"

	if collider is Node and (collider as Node).has_meta(&"surface"):
		surface = String((collider as Node).get_meta(&"surface"))
	elif collider is RigidBody3D or collider.has_method("frob"):
		surface = "wood"

	var iron := surface in ["metal", "iron"]

	if iron:
		Fx.sparks(player, point, normal, 0.8)
	elif surface == "wood":
		Fx.chips(player, point, normal, 0.6)
	else:
		Fx.dust(player, point, normal, 0.6, surface)

	# A hole, in what stays put: the world's stone and timber, not a crate
	# that would carry it off.
	if collider is StaticBody3D or collider is CSGShape3D:
		Fx.hole(player, point, normal, "metal" if iron else surface)


## The muzzle, in the world: out along the aim from the eye, where the
## gun's barrel ends (`which`: "muzzle" or "shot_muzzle").
func _muzzle(at: Transform3D, which: StringName) -> Vector3:
	var gun: Resource = WeaponScript.find(&"revolver")
	var tip: Vector3 = gun.mesh.get_meta(which, Vector3(0, 0.1, -0.32))
	return at.origin + at.basis * Vector3(0.18, -0.18 + tip.y * 0.62, -0.45 + tip.z * 0.62)


## The kick: the camera jolts, and the gun settles over the ready time.
## `strength` 1 for a ball, more for the shell.
func _kicked(strength: float, gun: Resource) -> void:
	var held := 0.5 if aimed else 1.0
	_settle = gun.ready_braced if aimed else gun.ready_one_hand
	_ready_at = _game_time + _settle
	_kick = 1.0
	_climb_aim(strength)
	player.juice.add_trauma(KICK_TRAUMA * strength * held)
	player.juice.punch(KICK_PUNCH * strength * held, 0.08 * held, 0.22 * strength * held)
	player.juice.lunge(0.7 * strength * held)


# How the hand looks

## Poses the gun in your view (ViewPoses.REVOLVER) and moves its parts: at
## rest (lower at a run), both hands on it, kicked up by a shot and settling,
## rolled to the gate while loading or checking (Tab), the thumb at the nose.
func _send_pose(delta: float) -> void:
	var poses: Dictionary = ViewPoses.REVOLVER
	var sprinting: bool = player.has_method("_is_sprinting") and player._is_sprinting() and Vector2(player.velocity.x, player.velocity.z).length() > float(player.get("walk_speed")) + 0.3
	var checking: bool = player.hand != null and player.hand.has_method("is_checking") and player.hand.is_checking()
	var booting: bool = player.combat.phase == player.combat.Phase.KICK
	_sprint_shown = move_toward(_sprint_shown, 1.0 if sprinting and _kick <= 0.0 and loading == Load.NONE else 0.0, delta * 4.0)
	_gate_shown = move_toward(_gate_shown, 1.0 if loading != Load.NONE or checking else 0.0, delta / 0.2)
	_flip_shown = move_toward(_flip_shown, 1.0 if _game_time < _flip_until else 0.0, delta / 0.07)
	_boot_shown = move_toward(_boot_shown, 1.0 if booting else 0.0, delta / 0.1)
	_whip_shown = move_toward(_whip_shown, 1.0 if _whip_t >= 0.0 and _whip_t < WHIP_LANDS + 0.05 else 0.0, delta / 0.08)

	var frame := ViewPoses.revolver_frame(poses["rest"])
	frame = ViewPoses.blend(frame, ViewPoses.revolver_frame(poses["sprint"]), _ease(_sprint_shown))
	frame = ViewPoses.blend(frame, ViewPoses.revolver_frame(poses["aim"]), _ease(_aim))
	# The kick snaps up and settles slowly: half as far in both hands.
	frame = ViewPoses.blend(frame, ViewPoses.revolver_frame(poses["recoil"]), pow(_kick, 1.35) * (0.55 if aimed else 1.0))
	frame = ViewPoses.blend(frame, ViewPoses.revolver_frame(poses["flip"]), _ease(_flip_shown))
	frame = ViewPoses.blend(frame, ViewPoses.revolver_frame(poses["gate"]), _ease(_gate_shown))
	frame = ViewPoses.blend(frame, ViewPoses.revolver_frame(poses["kick"]), _ease(_boot_shown))
	frame = ViewPoses.blend(frame, ViewPoses.revolver_frame(poses["whip"]), _ease(_whip_shown))

	var turned := float(_shots) * TAU / 6.0
	_turn_shown = move_toward(_turn_shown, turned, delta * TAU / 6.0 / 0.12)
	var gate := maxf(gate_open(), _gate_shown if checking else 0.0)
	var hand: Node = player.hand

	if hand != null:
		hand.set_weapon_frame(frame)

		if hand.has_method("set_revolver_parts"):
			hand.set_revolver_parts(_turn_shown, _kick, gate)

		if hand.has_method("set_gun_support"):
			hand.set_gun_support(_aim * (1.0 - _gate_shown))

		if hand.has_method("set_gun_aim"):
			hand.set_gun_aim(_aim)


## The shot throws the aim up (and a little aside, by the pattern), as far
## as the look can go.
func _climb_aim(strength: float) -> void:
	var neck: Node3D = player.get("neck")

	if neck == null:
		return

	var up := deg_to_rad((KICK_PITCH_AIMED if aimed else KICK_PITCH) * (SHELL_CLIMB if strength > 1.0 else 1.0))
	var limit := deg_to_rad(float(player.get("max_pitch_degrees")))
	var before := neck.rotation.x
	neck.rotation.x = minf(before + up, limit)
	var aside := deg_to_rad(KICK_YAW_MAX * float(YAW_PATTERN[_shots % YAW_PATTERN.size()])) * (0.5 if aimed else 1.0)
	player.rotation.y += aside
	_climb = Vector2(neck.rotation.x - before, aside)
	_climb_t = 0.0


## RECOVER of the last climb comes back over the settle, eased in and out,
## as a change each tick: your own look moves on top of it.
func _recover_climb(delta: float) -> void:
	if _climb_t < 0.0:
		return

	var neck: Node3D = player.get("neck")
	var before := smoothstep(0.0, 1.0, _climb_t / maxf(_settle, 0.01))
	_climb_t += delta
	var after := smoothstep(0.0, 1.0, _climb_t / maxf(_settle, 0.01))
	var back := _climb * RECOVER * (after - before)

	if neck != null:
		neck.rotation.x -= back.x

	player.rotation.y -= back.y

	if _climb_t >= _settle:
		_climb_t = -1.0


static func _ease(t: float) -> float:
	var c := clampf(t, 0.0, 1.0)
	return c * c * (3.0 - 2.0 * c)


func _sound(name: StringName) -> void:
	var take: Array = SOUNDS.get(name, [name, 0.0, 1.0])
	Sfx.play_flat(player, take[0], take[1], take[2])


func _ensure_action(action: StringName, key: Key, mouse_button := -1) -> void:
	if InputMap.has_action(action):
		return

	InputMap.add_action(action)

	if key != KEY_NONE:
		var key_event := InputEventKey.new()
		key_event.physical_keycode = key
		InputMap.action_add_event(action, key_event)

	if mouse_button != -1:
		var mouse_event := InputEventMouseButton.new()
		mouse_event.button_index = mouse_button
		InputMap.action_add_event(action, mouse_event)
