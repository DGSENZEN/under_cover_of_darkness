extends RefCounted
## A guard in water (WaterVolume). Where he can stand he wades: the deeper,
## the slower, and every step splashes. Where he cannot, he swims: afloat,
## his head out of it (lower in it on the move, flat on the surface), at
## SWIM_SCALE of his speed, heard stroke by stroke; he neither guards nor
## strikes. His path runs along the water's own navmesh (NavBaker's swim
## region, on the surface), so what his path follows is lifted to his feet
## (path_height_offset). He gets in and out where the bank is low, or by a
## jump in and a haul out (GuardClimb, NavLinks).

const WaterScript := preload("res://scripts/Interaction/WaterVolume.gd")
const Sfx := preload("res://scripts/Audio/Sfx.gd")
const SoundBus := preload("res://scripts/StimuliSystem/SoundBus.gd")

## Swimming, his feet this far under the surface: on the move (flat on it),
## and treading water (upright, his head out).
const FLOAT := 1.0
const TREAD := 1.35
## Of his speed, swimming; wading at waist deep.
const SWIM_SCALE := 0.45
const WADE_SCALE := 0.6
## A stroke (every this many metres) is heard this loud (dB).
const STROKE := 1.4
const STROKE_DB := 44.0
## The navmesh lies this far above what it was baked from.
const NAV_LIFT := 0.2

var guard: CharacterBody3D
## The water he is in, or null; whether he is swimming (not standing).
var water: Node3D = null
var swimming := false
var _strokes := 0.0


func _init(p_guard: CharacterBody3D) -> void:
	guard = p_guard


## Every physics frame, before he moves: which water he is in, and whether
## he stands or swims in it; his path lifted to his feet.
func update(_delta: float) -> void:
	var feet: Vector3 = guard.global_position
	water = WaterScript.at(guard.get_tree(), feet + Vector3.UP * 0.05, 0.25)
	var agent: NavigationAgent3D = guard._agent

	if water == null:
		swimming = false

		if agent != null:
			agent.path_height_offset = 0.0

		return

	swimming = water.deep_at(feet) and water.depth_of(feet) > 0.9

	# The swim region lies at the surface; his feet are under it.
	if agent != null:
		agent.path_height_offset = maxf(water.surface_y() + NAV_LIFT - feet.y, 0.0) if water.has_meta(&"swim_region") else 0.0


## The share of his speed the water leaves him.
func speed_scale() -> float:
	if water == null:
		return 1.0

	if swimming:
		return SWIM_SCALE

	var deep := clampf(water.depth_of(guard.global_position) / 1.1, 0.0, 1.0)
	return lerpf(1.0, WADE_SCALE, deep)


## Swimming, in place of standing on the ground: afloat at his height for
## how he is moving, no faster than he can swim, and nothing of a fall left
## in him (the water took it). Heard stroke by stroke.
func float_him(delta: float) -> void:
	var flat := Vector3(guard.velocity.x, 0.0, guard.velocity.z)
	var most: float = float(guard.chase_speed) * SWIM_SCALE

	if flat.length() > most:
		flat = flat.normalized() * most

	var moving := clampf(flat.length() / maxf(most, 0.1), 0.0, 1.0)
	var afloat: float = water.surface_y() - lerpf(TREAD, FLOAT, moving)
	guard.velocity.x = flat.x
	guard.velocity.z = flat.z
	guard.velocity.y = clampf((afloat - guard.global_position.y) * 4.0, -3.0, 2.0)
	guard._fall_peak = 0.0
	_strokes += flat.length() * delta / STROKE

	if _strokes >= 1.0:
		_strokes -= 1.0
		var at := Vector3(guard.global_position.x, water.surface_y(), guard.global_position.z)
		Sfx.play(guard, Sfx.step("water", moving > 0.7), at, Sfx.loudness(STROKE_DB))
		SoundBus.emit_sound(at, STROKE_DB, guard, &"swim")


## Wading: no faster than the water lets him.
func wade(_delta: float) -> void:
	var scale := speed_scale()

	if scale >= 1.0:
		return

	var flat := Vector3(guard.velocity.x, 0.0, guard.velocity.z)
	var most: float = float(guard.chase_speed) * scale

	if flat.length() > most:
		flat = flat.normalized() * most
		guard.velocity.x = flat.x
		guard.velocity.z = flat.z


## What the rig shows: "swim" on the move, "tread" still, "" out of it or
## standing in it.
func activity() -> StringName:
	if not swimming:
		return &""

	return &"swim" if Vector2(guard.velocity.x, guard.velocity.z).length() > 0.35 else &"tread"
