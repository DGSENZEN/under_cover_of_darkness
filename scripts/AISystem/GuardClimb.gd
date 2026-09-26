extends RefCounted
## How a guard crosses what his path cannot walk (NavLinks), as his path
## comes to it (Guard._on_link_reached): up onto a top (hands on it, and a
## pull), down off it (a hop; from higher, lowered off the edge to hang and
## let go), across a gap (a leap), up or down a ladder or a rope, into deep
## water off a high bank (a jump) and out of it again (hauled up the bank).
## Low banks he wades in and out of: no move of their own (GuardWater).
##
## Each is his whole body moved from where he stands to the far end, along a
## few legs, over its own time: nothing else moves him meanwhile, and he
## neither guards nor strikes. A blow or a boot takes him off it (interrupt):
## off a wall or a ladder, he falls. The rig shows it (activity) and it is
## heard: armour against stone, a landing.

const Sfx := preload("res://scripts/Audio/Sfx.gd")
const SoundBus := preload("res://scripts/StimuliSystem/SoundBus.gd")

## Up a wall, and up or down a ladder (m/s): the climbing clip covers a metre
## in its 0.67 s.
const CLIMB_SPEED := 1.5
const LADDER_SPEED := 1.4
## Falling (m/s²), as the guards fall (Guard._apply_ground).
const GRAVITY := 24.0
## Hanging from an edge, his feet are this far below it.
const HANG := 1.9
## Across a gap, this fast (m/s), the arc this high over the higher end.
const LEAP_SPEED := 5.0
const LEAP_ARC := 0.45
## A swimmer's feet are this far under the surface (GuardWater.FLOAT).
const FLOAT := 1.3
## Off a bank this far over the water or more, he jumps in; less, he wades.
const JUMP_IN := 0.6
## The navmesh lies this far above the floor it was baked from.
const NAV_LIFT := 0.2
## As the moves are heard (dB): a man climbing in mail, landing, a splash.
const CLIMB_DB := 44.0
const LAND_DB := 52.0

var guard: CharacterBody3D
## The kind of way being crossed ("climb", "drop", "leap", "ladder", "rope",
## "water"), or "" when he is not on one.
var kind: StringName = &""

## The legs of the move: each [to, seconds, what, how]: "what" is shown by the
## rig (activity), "how" is how he gets there: "line" (straight, eased),
## "fall" (under gravity), "arc" (a leap).
var _legs: Array = []
var _leg := 0
var _leg_t := 0.0
var _leg_from := Vector3.ZERO
var _facing := Vector3.ZERO
var _climbed := 0.0
var _splash_at := -INF
var _water: Node3D = null


func _init(p_guard: CharacterBody3D) -> void:
	guard = p_guard


func active() -> bool:
	return kind != &""


## What the rig shows: "climb", "ladder", "hang", "gather", "fall",
## "leap", "land", or "".
func activity() -> StringName:
	if not active() or _leg >= _legs.size():
		return &""

	return _legs[_leg][2]


## How far into the leg under way, 0..1.
func progress() -> float:
	if not active() or _leg >= _legs.size():
		return 0.0

	return clampf(_leg_t / maxf(float(_legs[_leg][1]), 0.001), 0.0, 1.0)


## Metres climbed so far (the rig paces the climbing clip by it).
func climbed() -> float:
	return _climbed


## His path has come to a link (NavigationAgent3D.link_reached's `details`):
## the move across it, from where he stands. False if it is walked (a low
## bank) or not his to cross from here.
func begin(details: Dictionary) -> bool:
	var link: Variant = details.get("owner")

	if not (link is NavigationLink3D) or not (link as Node).has_meta(&"kind"):
		return false

	var entry: Vector3 = details.get("link_entry_position", Vector3.INF)
	var exit: Vector3 = details.get("link_exit_position", Vector3.INF)

	if entry == Vector3.INF or exit == Vector3.INF:
		return false

	# Too far from it to have come to it (a path planned from elsewhere).
	if Vector2(entry.x - guard.global_position.x, entry.z - guard.global_position.z).length() > 1.6:
		return false

	var what: StringName = (link as Node).get_meta(&"kind")
	var from: Vector3 = guard.global_position
	var a := Vector3(entry.x, entry.y - NAV_LIFT, entry.z)
	var b := Vector3(exit.x, exit.y - NAV_LIFT, exit.z)
	_legs.clear()
	_climbed = 0.0
	_water = null

	match what:
		&"climb":
			if b.y >= a.y:
				_plan_mantle(from, a, b)
			else:
				_plan_hop(from, a, b)
		&"drop":
			_plan_drop(from, a, b)
		&"leap":
			_plan_leap(from, a, b)
		&"ladder", &"rope":
			var volume: Variant = (link as Node).get_meta(&"volume") if (link as Node).has_meta(&"volume") else null

			if not (volume is Node3D) or not is_instance_valid(volume):
				return false

			_plan_ladder(from, a, b, volume, what == &"rope")
		&"water":
			if not _plan_water(from, a, b):
				return false
		_:
			return false

	if _legs.is_empty():
		return false

	kind = what
	_leg = 0
	_leg_t = 0.0
	_leg_from = from
	guard.velocity = Vector3.ZERO
	_noise(CLIMB_DB)
	return true


## A blow, a boot: he loses his hold. Off a wall or a ladder he falls from
## where he is; in the air he carries on falling (the ground has him).
func interrupt() -> void:
	if not active():
		return

	kind = &""
	_legs.clear()
	guard.velocity = Vector3(guard.velocity.x, minf(guard.velocity.y, 0.0), guard.velocity.z)


## Every physics frame while active: along the legs. The body is put where it
## goes; its velocity is what that was, for whoever reads it (the rig).
func update(delta: float) -> void:
	if not active():
		return

	var before := guard.global_position
	_leg_t += delta

	while _leg < _legs.size() and _leg_t >= float(_legs[_leg][1]):
		_leg_t -= float(_legs[_leg][1])
		_arrive(_legs[_leg])
		_leg_from = _legs[_leg][0]
		_leg += 1

	if _leg >= _legs.size():
		_finish()
		guard.velocity = (guard.global_position - before) / maxf(delta, 0.0001)
		return

	var leg: Array = _legs[_leg]
	var to: Vector3 = leg[0]
	var u := clampf(_leg_t / maxf(float(leg[1]), 0.001), 0.0, 1.0)
	var at := _leg_from

	match leg[3]:
		&"fall":
			var t := _leg_t
			at = Vector3(lerpf(_leg_from.x, to.x, u), maxf(_leg_from.y - 0.5 * GRAVITY * t * t, to.y), lerpf(_leg_from.z, to.z, u))
		&"arc":
			at = _leg_from.lerp(to, u) + Vector3.UP * (LEAP_ARC + absf(to.y - _leg_from.y) * 0.5) * 4.0 * u * (1.0 - u)
		_:
			at = _leg_from.lerp(to, smoothstep(0.0, 1.0, u))

	if leg[2] in [&"climb", &"ladder"] and at.y > guard.global_position.y:
		_climbed += at.y - guard.global_position.y
	elif leg[2] == &"ladder":
		_climbed += guard.global_position.y - at.y

	guard.global_position = at
	guard.velocity = (at - before) / maxf(delta, 0.0001)

	if _facing != Vector3.ZERO:
		guard._face(_facing, delta, 2.0)

	# Into the water: a splash as he goes in.
	if _water != null and before.y > _water.surface_y() - 0.2 and at.y <= _water.surface_y() - 0.2 and guard._game_time - _splash_at > 1.0:
		_splash_at = guard._game_time
		_water.splash(at, -guard.velocity.y, guard)


# ---------------------------------------------------------------------------
# The moves
# ---------------------------------------------------------------------------

## Up onto a top: to its foot, facing it; hands up, and pulled up the face;
## over the lip, and onto his feet.
func _plan_mantle(from: Vector3, a: Vector3, b: Vector3) -> void:
	var toward := _flat(b - a)
	_facing = toward
	var rise := b.y - a.y
	_legs.append([Vector3(a.x, from.y, a.z), 0.15, &"climb", &"line"])
	_legs.append([Vector3(a.x, b.y - 0.15, a.z), maxf(rise - 0.15, 0.1) / CLIMB_SPEED + 0.1, &"climb", &"line"])
	_legs.append([Vector3(a.x, b.y, a.z) + toward * 0.4, 0.25, &"climb", &"line"])
	_legs.append([b, 0.25, &"land", &"line"])


## Down off a top he could climb: to the edge, and a hop down.
func _plan_hop(from: Vector3, a: Vector3, b: Vector3) -> void:
	var toward := _flat(b - a)
	_facing = toward
	var edge := a + toward * maxf(_flat_distance(a, b) - 0.35, 0.1)
	var drop := a.y - b.y
	_legs.append([Vector3(edge.x, from.y, edge.z), 0.2, &"gather", &"line"])
	_legs.append([b, sqrt(2.0 * drop / GRAVITY) + 0.05, &"fall", &"fall"])
	_legs.append([b, 0.25, &"land", &"line"])


## Down from high: to the edge, lowered off it to hang by his hands, and let
## go; the fall that is left is short.
func _plan_drop(from: Vector3, a: Vector3, b: Vector3) -> void:
	var toward := _flat(b - a)
	_facing = toward
	var edge := a + toward * maxf(_flat_distance(a, b) - 0.6, 0.1)
	var hang := Vector3(edge.x, a.y - HANG, edge.z) + toward * 0.3
	_legs.append([Vector3(edge.x, from.y, edge.z), 0.3, &"gather", &"line"])
	_legs.append([hang, 0.55, &"hang", &"line"])
	_legs.append([b, sqrt(2.0 * maxf(hang.y - b.y, 0.05) / GRAVITY) + 0.05, &"fall", &"fall"])
	_legs.append([b, 0.35, &"land", &"line"])


## Across a gap: gathered, over it in an arc, and down on the far side.
func _plan_leap(from: Vector3, a: Vector3, b: Vector3) -> void:
	_facing = _flat(b - a)
	_legs.append([Vector3(a.x, from.y, a.z), 0.12, &"gather", &"line"])
	_legs.append([b, maxf(a.distance_to(b) / LEAP_SPEED, 0.3), &"leap", &"arc"])
	_legs.append([b, 0.2, &"land", &"line"])


## Up or down a ladder (or a rope): to its foot (or over its top), hand over
## hand along it, and off at the far end.
func _plan_ladder(from: Vector3, a: Vector3, b: Vector3, volume: Node3D, rope: bool) -> void:
	var out: Vector3 = volume.get_climb_normal() if volume.has_method("get_climb_normal") else _flat(a - b)
	var line: Vector3 = volume.global_position + out * 0.35

	if rope:
		line = volume.global_position + _flat(a - volume.global_position) * 0.25

	_facing = -out if not rope else _flat(volume.global_position - a)

	if b.y >= a.y:
		_legs.append([Vector3(line.x, from.y, line.z), 0.3, &"ladder", &"line"])
		_legs.append([Vector3(line.x, b.y - 0.15, line.z), maxf(b.y - a.y - 0.15, 0.1) / LADDER_SPEED, &"ladder", &"line"])
		_legs.append([Vector3(line.x, b.y, line.z) - out * 0.5, 0.3, &"climb", &"line"])
		_legs.append([b, 0.25, &"land", &"line"])
	else:
		_legs.append([Vector3(line.x, from.y, line.z) - out * 0.5, 0.3, &"gather", &"line"])
		_legs.append([Vector3(line.x, a.y - 0.15, line.z), 0.3, &"climb", &"line"])
		_legs.append([Vector3(line.x, b.y, line.z), maxf(a.y - b.y - 0.15, 0.1) / LADDER_SPEED, &"ladder", &"line"])
		_legs.append([b, 0.25, &"land", &"line"])


## Into deep water off a high bank: a jump in (a low one, he wades). Out of
## it up a high bank: hauled up it (a low one, he wades out). False: wading.
func _plan_water(from: Vector3, a: Vector3, b: Vector3) -> bool:
	var into := a.y > b.y
	var water: Node3D = _water_at(b if into else a)

	if water == null:
		return false

	var surface: float = water.surface_y()

	if into:
		if a.y - surface < JUMP_IN:
			return false

		_water = water
		var toward := _flat(b - a)
		_facing = toward
		var edge := a + toward * maxf(_flat_distance(a, b) * 0.5, 0.1)
		var afloat := Vector3(b.x, surface - FLOAT, b.z)
		_legs.append([Vector3(edge.x, from.y, edge.z), 0.2, &"gather", &"line"])
		_legs.append([afloat, sqrt(2.0 * maxf(edge.y - afloat.y, 0.05) / GRAVITY) + 0.05, &"fall", &"fall"])
		return true

	# Out: where he can stand at the bank and it is low, he wades out; afloat
	# at a wall, he is hauled up it and over.
	if b.y - surface < 0.35 and not water.deep_at(from):
		return false

	var toward := _flat(b - a)
	_facing = toward
	_legs.append([Vector3(from.x, from.y, from.z), 0.1, &"climb", &"line"])
	_legs.append([Vector3(from.x, b.y - 0.15, from.z), maxf(b.y - from.y - 0.15, 0.1) / CLIMB_SPEED + 0.1, &"climb", &"line"])
	_legs.append([Vector3(from.x, b.y, from.z) + toward * 0.45, 0.25, &"climb", &"line"])
	_legs.append([b, 0.25, &"land", &"line"])
	return true


# ---------------------------------------------------------------------------

## Come to the end of `leg`: a landing is heard.
func _arrive(leg: Array) -> void:
	if leg[3] == &"fall" and _water == null:
		Sfx.play(guard, guard._chain_land(), guard.global_position, 0.0)
		_noise(LAND_DB)


## Across: back to walking, his path's next point the far end.
func _finish() -> void:
	kind = &""
	_legs.clear()
	guard._stuck_time = 0.0
	guard._last_walk_position = guard.global_position
	guard._fall_peak = 0.0


func _noise(db: float) -> void:
	SoundBus.emit_sound(guard.global_position + Vector3.UP * 1.0, db, guard, &"footstep")


func _water_at(point: Vector3) -> Node3D:
	for water in guard.get_tree().get_nodes_in_group(&"water"):
		if water.has_method("over") and water.over(point):
			return water

	return null


static func _flat(v: Vector3) -> Vector3:
	var f := Vector3(v.x, 0.0, v.z)
	return f.normalized() if f.length() > 0.001 else Vector3.FORWARD


static func _flat_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(b.x - a.x, b.z - a.z).length()
