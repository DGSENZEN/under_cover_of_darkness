extends RefCounted
## A validated, choreographed movement. The controller carries the body along
## `points` over `duration` seconds, then hands back `exit_velocity`.
##
## The path was fit-tested by the planner before this object was created, so
## the player never aborts a move halfway.

var label: StringName = &""
var kind := 0

## World-space positions of the body ORIGIN, including the starting point.
var points := PackedVector3Array()

var duration := 0.3
## 0 = constant speed, 1 = symmetric ease in and out.
var smoothing := 1.0
## 0..1: how much the move launches fast and slows toward the end.
var ease_out := 0.0

## A pause before the path plays, with a small dip: the body gathers itself.
var windup_time := 0.0
var windup_dip := 0.0
var exit_velocity := Vector3.ZERO

## True when the path only fits with the crouched capsule.
var use_crouch_shape := false

## Total yaw change applied over the move, in radians. Used when lowering over
## an edge, which turns the body around to face the wall.
var yaw_delta := 0.0

## Speed toward the obstacle when the move began, and the fraction of it that
## survives. A chained move scans ahead with entry_speed * speed_kept.
var entry_speed := 0.0
var speed_kept := 0.0

## The edge this move touches: where hands would plant. `contact_point` is on
## the obstacle's top front edge (or the lip being grabbed); `contact_normal`
## points out of the face, toward the player.
var has_contact := false
var contact_point := Vector3.ZERO
var contact_normal := Vector3.ZERO

## Loudness of the effort, in dB. Emitted once when the move starts.
var noise_db := 0.0

var ends_in_hang := false
var hang_normal := Vector3.ZERO
var hang_lip_y := 0.0

var total_length := 0.0
var _cumulative := PackedFloat32Array()


func bake() -> void:
	_cumulative.clear()
	_cumulative.append(0.0)
	total_length = 0.0

	for i in range(1, points.size()):
		total_length += points[i - 1].distance_to(points[i])
		_cumulative.append(total_length)


## s is the normalized distance along the whole path, 0..1.
func position_at(s: float) -> Vector3:
	if points.is_empty():
		return Vector3.ZERO

	if total_length <= 0.0001:
		return points[points.size() - 1]

	var distance := clampf(s, 0.0, 1.0) * total_length

	for i in range(1, points.size()):
		if distance <= _cumulative[i]:
			var segment := _cumulative[i] - _cumulative[i - 1]
			var u := 0.0

			if segment > 0.00001:
				u = (distance - _cumulative[i - 1]) / segment

			return points[i - 1].lerp(points[i], u)

	return points[points.size() - 1]
