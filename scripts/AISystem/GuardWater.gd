extends RefCounted
## Tracks the containing WaterVolume and wading/swimming state.
## Depth scales movement speed; swimming suspends guard/strike behaviour and places
## feet below the surface. Adjusts NavigationAgent path height for the swim mesh
## (and, on land, where the navmesh lies well over his feet: the water stairs
## down a quay's face); GuardClimb/NavLinks handle high banks. Steps/strokes
## emit gameplay sound.

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
## On land, over his feet by more than this (steps the bake smoothed over),
## the navmesh's path comes down to them (at most LAND_MOST); looked at every
## LAND_EVERY s.
const LAND_GAP := 0.35
const LAND_MOST := 1.0
const LAND_EVERY := 0.25

var guard: CharacterBody3D
## The water he is in, or null; whether he is swimming (not standing).
var water: Node3D = null
var swimming := false
var _strokes := 0.0
var _land_offset := 0.0
var _land_timer := 0.0


func _init(p_guard: CharacterBody3D) -> void:
	guard = p_guard


## Queries WaterVolume at feet, sets water/swimming and updates agent path height.
## Out of water the height offset is the navmesh's over his feet (_over_feet);
## call before movement.
func update(delta: float) -> void:
	var feet: Vector3 = guard.global_position
	water = WaterScript.at(guard.get_tree(), feet + Vector3.UP * 0.05, 0.25)
	var agent: NavigationAgent3D = guard._agent

	if water == null:
		swimming = false

		if agent != null:
			agent.path_height_offset = _over_feet(feet, delta)

		return

	swimming = water.deep_at(feet) and water.depth_of(feet) > 0.9

	# The swim region lies at the surface; his feet are under it.
	if agent != null:
		agent.path_height_offset = maxf(water.surface_y() + NAV_LIFT - feet.y, 0.0) if water.has_meta(&"swim_region") else 0.0


## On land, how far the navmesh lies over his feet when that is more than
## its lift (LAND_GAP): on steps the bake smoothed over it can stand 0.7 m
## over them, and a path point over his head is then never counted reached
## (the agent measures in 3D) and he treads round under it for good. 0 on
## ground the navmesh lies on as baked.
func _over_feet(feet: Vector3, delta: float) -> float:
	_land_timer -= delta

	if _land_timer > 0.0:
		return _land_offset

	_land_timer = LAND_EVERY
	var closest := NavigationServer3D.map_get_closest_point(guard.get_world_3d().navigation_map, feet)
	var gap := closest.y - feet.y
	var near := Vector2(closest.x - feet.x, closest.z - feet.z).length() < 0.75
	_land_offset = minf(gap, LAND_MOST) if near and gap > LAND_GAP else 0.0
	return _land_offset


## The share of his speed the water leaves him.
func speed_scale() -> float:
	if water == null:
		return 1.0

	if swimming:
		return SWIM_SCALE

	var deep := clampf(water.depth_of(guard.global_position) / 1.1, 0.0, 1.0)
	return lerpf(1.0, WADE_SCALE, deep)


## Requires current swimming water; adjusts velocity toward surface-relative feet,
## limits horizontal speed, clears fall peak and emits stroke audio/gameplay sound.
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
