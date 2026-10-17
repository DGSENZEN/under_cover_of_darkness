extends RefCounted
## The body hanging from the hands on a climb: a sprung, slightly loose weight
## under whatever is holding it. It swings under the one hand that holds while
## the other reaches, drops onto an arm as a hand lands, lags behind a pull as
## it starts and carries past it as it stops. Its output is an offset of the
## view (CameraJuice.climb_offset / climb_roll); the hands stay on the stone,
## so the arms are seen to take the weight.

## The spring the body hangs on: how quick (rad/s) and how loose.
var omega := 15.0
var damping_ratio := 0.42
## How far the body swings toward the one hand holding (share of the hand's
## offset), and how much the view rolls with it (rad per metre).
var hang_follow := 0.35
var roll_per_metre := 0.9
## The pull's acceleration felt as weight (s^2): the body lags, then carries.
var inertia := 0.006
## A hand landing: how hard the body drops onto it (m/s), and leans (rad/s).
var land_drop := 0.55
var land_lean := 0.15
## The most it may sway (m) and roll (rad).
var max_offset := 0.09
var max_roll := deg_to_rad(1.5)

## The view offset (world space) and roll (rad) to draw.
var offset := Vector3.ZERO
var roll := 0.0

var _velocity := Vector3.ZERO
var _roll_velocity := 0.0
var _last_position := Vector3.ZERO
var _last_velocity := Vector3.ZERO
var _primed := false


## One tick. climbing: on a hold or moving between holds. body: the body's
## origin. lateral: the wall's sideways (right) axis. holding: world points of
## the hands holding on (0, 1 or 2). centre: where the hands' middle would be
## for the body as it is (its grip line).
func step(delta: float, climbing: bool, body: Vector3, lateral: Vector3, holding: Array, centre: Vector3) -> void:
	if delta <= 0.0:
		return

	var velocity := Vector3.ZERO
	var accel := Vector3.ZERO

	if _primed:
		velocity = (body - _last_position) / delta
		accel = (velocity - _last_velocity) / delta

	_primed = true
	_last_position = body
	_last_velocity = velocity

	var target := Vector3.ZERO
	var target_roll := 0.0

	if climbing and holding.size() == 1:
		var across: float = ((holding[0] as Vector3) - centre).dot(lateral)
		target = lateral * across * hang_follow
		target_roll = -across * hang_follow * roll_per_metre

	# The spring, with the climb's acceleration as a felt force on the body.
	var k := omega * omega
	var c := 2.0 * damping_ratio * omega
	var force := (target - offset) * k - _velocity * c

	if climbing:
		force -= accel.limit_length(40.0) * inertia * k

	_velocity += force * delta
	offset += _velocity * delta
	offset = offset.limit_length(max_offset)

	var roll_force := (target_roll - roll) * k - _roll_velocity * c
	_roll_velocity += roll_force * delta
	roll = clampf(roll + _roll_velocity * delta, -max_roll, max_roll)


## A hand landing on a hold (side -1 left, 1 right of the view): the weight
## drops onto it and leans its way.
func hand_landed(side: float, lateral: Vector3) -> void:
	_velocity += Vector3.DOWN * land_drop
	_roll_velocity += side * land_lean


## Off the wall (a teleport, a fall): nothing carried over.
func reset() -> void:
	offset = Vector3.ZERO
	roll = 0.0
	_velocity = Vector3.ZERO
	_roll_velocity = 0.0
	_primed = false
