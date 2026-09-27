extends Node
## The hands on the camera: puts it where a shot's framing says, the way the
## editor asks (a cut, a glide, a path, a wipe), as a dolly and a crane
## would: critically damped springs (no floating, no overshoot) held to each
## mode's speeds, the lens eased, focus pulled onto the subject, a little
## handheld sway, and shake from blows. It runs on real time
## (TimeFx.real_time), so a slowed world does not slow the camera.
##   observe  a slow dolly (0.4 m/s, 8 deg/s), all but still in the hand.
##   drama    quick (6 m/s, 90 deg/s), handheld up close.

const TimeFx := preload("res://scripts/Visual/TimeFx.gd")

## Focus effects on (the probe found them fit under the retro filter).
const DEPTH_OF_FIELD := true
## Per mode: the top speed (m/s), the fastest turn (deg/s), how long a move
## takes to settle (s), and the handheld sway on a close shot and otherwise
## (deg).
const MODES := {
	&"observe": {"speed": 0.4, "turn": 8.0, "settle": 1.2, "close_sway": 0.0, "sway": 0.0, "drift": 0.0},
	&"drama": {"speed": 6.0, "turn": 90.0, "settle": 0.35, "close_sway": 0.15, "sway": 0.0, "drift": 0.005},
}
## The handheld's slow drift: how fast (Hz) (how far the camera itself
## moves: MODES "drift", m).
const SWAY_RATE := 0.35
## Shake: its most (deg, at trauma 1, as trauma squared), how fast it
## wanders (Hz), and how fast trauma dies (a second).
const SHAKE_MOST := 2.5
const SHAKE_RATE := 14.0
const SHAKE_DECAY := 1.5
## The lens eases at most this fast (deg/s); focus is pulled in about this
## long (s).
const LENS_RATE := 12.0
const FOCUS_PULL := 0.4
## Depth of field, only on a close shot or a portrait: far blur begins this
## far behind the subject (m), this soft. Nothing else is blurred.
const FAR_BEHIND := 4.0
const BLUR_AMOUNT := 0.04
const FAR_TRANSITION := 2.0
## Over a shoulder, what is nearer than this (m) goes soft.
const NEAR_SOFT := 1.0
const NEAR_TRANSITION := 0.6
## A glide that would pass through a wall (a sphere of this radius) is a cut.
const CLEARANCE := 0.3

## How shaken it is (0..1; the shake is its square).
var trauma := 0.0

var _camera: Camera3D
var _screen: CanvasLayer
var _mode := MODES[&"drama"]
var _framing: Dictionary = {}
var _goal := Vector3.ZERO
## Where it stands before the hand's drift (what the springs move).
var _base := Vector3.ZERO
var _velocity := Vector3.ZERO
var _look := Vector3.ZERO
var _look_velocity := Vector3.ZERO
var _fov := 40.0
var _focus := 5.0
var _path := PackedVector3Array()
var _path_at := 0.0
var _last := -1.0
var _clock := 0.0
var _noise := FastNoiseLite.new()
var _attributes: CameraAttributesPractical
## The camera's own lens and attributes, given back whenever it is not ours.
var _own_fov := 75.0
var _own_attributes: CameraAttributes = null


func _ready() -> void:
	_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	_noise.fractal_octaves = 3
	_noise.frequency = 1.0
	_noise.seed = 1932


## Takes `camera` (drawn where it is put: no physics interpolation), and
## `screen` for wipes.
func attach(camera: Camera3D, screen: CanvasLayer) -> void:
	_camera = camera
	_screen = screen
	_own_fov = camera.fov
	_own_attributes = camera.attributes
	_camera.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	_goal = camera.global_position
	_base = camera.global_position
	_look = camera.global_position - camera.global_basis.z * 5.0
	_fov = camera.fov

	if DEPTH_OF_FIELD:
		_attributes = CameraAttributesPractical.new()
		_attributes.dof_blur_far_transition = FAR_TRANSITION
		_attributes.dof_blur_near_transition = NEAR_TRANSITION
		camera.attributes = _attributes


## The camera given back for a while (flown, following, let go): its own
## lens and attributes, no shake left in it.
func stand_down() -> void:
	trauma = 0.0

	if _camera != null and is_instance_valid(_camera):
		_camera.fov = _own_fov
		_camera.attributes = _own_attributes


## The camera taken again: its focus ours again (the next shot sets the lens).
func stand_up() -> void:
	if _camera != null and is_instance_valid(_camera) and _attributes != null:
		_camera.attributes = _attributes

	_last = -1.0


## "observe" or "drama": its speeds and its sway.
func set_mode(mode: StringName) -> void:
	_mode = MODES.get(mode, MODES[&"drama"])


## A new shot, `how`: "cut" (there at once), "glide" (moved there; a cut if
## a wall is in the way), "path" (along framing.path, at the mode's speed),
## or "wipe" (the last frame wiped away over the new shot, cut to).
func show(framing: Dictionary, how: StringName) -> void:
	if _camera == null:
		return

	_framing = framing
	_goal = framing.get("position", _goal)
	_path = PackedVector3Array()
	# A new shot's lens is its own at once (a push-in within it is follow's).
	_fov = float(framing.get("fov", _fov))
	_camera.fov = _fov

	match how:
		&"glide":
			if blocked(_base, _goal):
				_cut()
		&"path":
			var points: PackedVector3Array = framing.get("path", PackedVector3Array())

			if points.size() >= 2:
				_path = points
				_path_at = 0.0
			else:
				_cut()
		&"wipe":
			_wipe_away()
			_cut()
		_:
			_cut()


## The same shot, its marks moved (the man it is on has moved): the goal,
## the aim, the lens and the focus follow; a path keeps to its path.
func follow(framing: Dictionary) -> void:
	var keep: Variant = _framing.get("path")
	_framing = framing

	if keep != null:
		_framing["path"] = keep

	if _path.is_empty():
		_goal = framing.get("position", _goal)


## Adds to the shake (a blow: 0.3 light, 0.5 heavy, 0.8 a death).
func shake(amount: float) -> void:
	trauma = clampf(trauma + amount, 0.0, 1.0)


func fov() -> float:
	return _fov


func focus_distance() -> float:
	return _focus


## Where it aims (before the hand's sway and the shake).
func look_point() -> Vector3:
	return _look


## Still moving to its mark, or along its path.
func moving() -> bool:
	return not _path.is_empty() or _base.distance_to(_goal) > 0.01


func _process(_delta: float) -> void:
	var dt := TimeFx.real_since(_last) if _last >= 0.0 else 0.0
	_last = TimeFx.real_time()

	if _camera == null or not is_instance_valid(_camera) or _framing.is_empty():
		return

	_clock += dt
	var omega := 4.0 / maxf(float(_mode["settle"]), 0.05)

	if not _path.is_empty():
		_along_path(dt)
	else:
		var was := _base
		var next := _spring(was, _goal, _velocity, omega, dt)
		_base = _held_to(was, next[0], float(_mode["speed"]), dt)
		_velocity = (_base - was) / dt if dt > 0.0 else Vector3.ZERO
		# Held back by the speed limit it carries more speed than the spring
		# would this near: no more than it can shed before its mark.
		var stop := omega * _base.distance_to(_goal)

		if _velocity.length() > stop:
			_velocity = _velocity.normalized() * stop

	_aim(omega, dt)
	_lens(dt)
	trauma = maxf(trauma - SHAKE_DECAY * dt, 0.0)
	_hand()


## Toward `target`, critically damped (exact for the frame): [where, speed].
static func _spring(at: Vector3, target: Vector3, speed: Vector3, omega: float, dt: float) -> Array:
	var gap := at - target
	var push := (speed + gap * omega) * dt
	var fade := exp(-omega * dt)
	return [target + (gap + push) * fade, (speed - push * omega) * fade]


## `to` from `from`, but no further in `dt` than `speed` allows.
static func _held_to(from: Vector3, to: Vector3, speed: float, dt: float) -> Vector3:
	var step := to - from
	var most := speed * dt

	if step.length() > most and step.length() > 0.0:
		return from + step.normalized() * most

	return to


## Along the path (Catmull-Rom through its points) at the mode's speed:
## this frame's distance spent piece by piece, each at its own pace (the
## curve's slope), so no join goes faster than the rest.
func _along_path(dt: float) -> void:
	var count := _path.size()
	var left := float(_mode["speed"]) * dt

	while left > 0.0 and _path_at < float(count - 1):
		var piece := clampi(int(_path_at), 0, count - 2)
		var t := _path_at - float(piece)
		var pace := maxf(_slope(piece, t).length(), 0.01)
		var step := left / pace

		if t + step < 1.0:
			_path_at += step
			left = 0.0
		else:
			left -= (1.0 - t) * pace
			_path_at = float(piece + 1)

	if _path_at >= float(count - 1):
		_base = _path[count - 1]
		_goal = _path[count - 1]
		_path = PackedVector3Array()
		return

	var segment := clampi(int(_path_at), 0, count - 2)
	_base = _catmull(segment, _path_at - float(segment))


## How fast the curve goes through piece `segment` at `t` (m per unit t).
func _slope(segment: int, t: float) -> Vector3:
	var count := _path.size()
	var p0 := _path[maxi(segment - 1, 0)]
	var p1 := _path[segment]
	var p2 := _path[mini(segment + 1, count - 1)]
	var p3 := _path[mini(segment + 2, count - 1)]
	return 0.5 * ((-p0 + p2) + 2.0 * (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t + 3.0 * (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t * t)


func _catmull(segment: int, t: float) -> Vector3:
	var count := _path.size()
	var p0 := _path[maxi(segment - 1, 0)]
	var p1 := _path[segment]
	var p2 := _path[mini(segment + 1, count - 1)]
	var p3 := _path[mini(segment + 2, count - 1)]
	var t2 := t * t
	var t3 := t2 * t
	return 0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3)


## The aim follows the framing's look point, no faster than the mode turns.
func _aim(omega: float, dt: float) -> void:
	var target: Vector3 = _framing.get("look", _look)
	var next := _spring(_look, target, _look_velocity, omega * 1.5, dt)
	var from := _base
	var was_dir := (_look - from).normalized()
	var want_dir: Vector3 = (next[0] - from).normalized()
	var most := deg_to_rad(float(_mode["turn"])) * dt
	var angle := was_dir.angle_to(want_dir)

	if angle > most and angle > 0.0001:
		want_dir = was_dir.slerp(want_dir, most / angle)

	var reach := maxf(from.distance_to(next[0]), 0.5)
	var was_look := _look
	_look = from + want_dir * reach
	_look_velocity = (_look - was_look) / dt if dt > 0.0 else Vector3.ZERO


## The lens eased to the framing's; focus pulled onto the subject.
func _lens(dt: float) -> void:
	_fov = move_toward(_fov, float(_framing.get("fov", _fov)), LENS_RATE * dt)
	_camera.fov = _fov
	var subject: Vector3 = _framing.get("subject", _framing.get("look", _look))
	var wanted := _base.distance_to(subject)
	_focus = lerpf(_focus, wanted, 1.0 - exp(-dt * 3.0 / FOCUS_PULL)) if dt > 0.0 else wanted

	if _attributes == null:
		return

	# Only up close: a close shot or a portrait.
	var up_close: bool = StringName(_framing.get("size", &"")) == &"close" or StringName(_framing.get("kind", &"")) == &"portrait"
	_attributes.dof_blur_far_enabled = up_close
	_attributes.dof_blur_far_distance = _focus + FAR_BEHIND
	_attributes.dof_blur_amount = BLUR_AMOUNT
	_attributes.dof_blur_near_enabled = up_close and bool(_framing.get("near_blur", false))
	_attributes.dof_blur_near_distance = NEAR_SOFT


## The camera where it stands, turned to its aim, then the hand's sway and
## the shake on top (a drama close shot drifts its place too).
func _hand() -> void:
	var from := _base
	_camera.global_position = from

	if from.distance_to(_look) < 0.05:
		return

	_camera.look_at(_look, Vector3.UP)
	var close := StringName(_framing.get("size", &"")) == &"close"
	var portrait := StringName(_framing.get("kind", &"")) == &"portrait"
	var drifts: bool = close and not portrait and float(_mode["drift"]) > 0.0
	var sway := 0.0 if portrait else deg_to_rad(float(_mode["close_sway"] if close else _mode["sway"]))
	var shaken := deg_to_rad(SHAKE_MOST) * trauma * trauma
	var t := _clock * SWAY_RATE
	var s := _clock * SHAKE_RATE
	var tilt := Vector2(sway * _noise.get_noise_2d(t, 0.0) + shaken * _noise.get_noise_2d(s, 50.0),
		sway * _noise.get_noise_2d(t, 100.0) + shaken * _noise.get_noise_2d(s, 150.0))
	var most := deg_to_rad(SHAKE_MOST)

	# However hard it shakes, never further off its aim than SHAKE_MOST.
	if tilt.length() > most:
		tilt = tilt.normalized() * most

	var yaw := tilt.x
	var pitch := tilt.y
	var roll := sway * 0.5 * _noise.get_noise_2d(t, 200.0) + shaken * 0.5 * _noise.get_noise_2d(s, 250.0)
	_camera.rotate_object_local(Vector3.UP, yaw)
	_camera.rotate_object_local(Vector3.RIGHT, pitch)
	_camera.rotate_object_local(Vector3.FORWARD, roll)

	if drifts:
		_camera.global_position = from + _camera.global_basis * Vector3(_noise.get_noise_2d(t, 300.0), _noise.get_noise_2d(t, 400.0), 0.0) * float(_mode["drift"])


func _cut() -> void:
	_base = _goal
	_camera.global_position = _goal
	_velocity = Vector3.ZERO
	_look = _framing.get("look", _look)
	_look_velocity = Vector3.ZERO
	_fov = float(_framing.get("fov", _fov))
	_camera.fov = _fov
	var subject: Vector3 = _framing.get("subject", _look)
	_focus = _goal.distance_to(subject)

	if _goal.distance_to(_look) > 0.05:
		_camera.look_at(_look, Vector3.UP)


## Whether a sphere moved from `from` to `to` meets a wall.
func blocked(from: Vector3, to: Vector3) -> bool:
	if not is_inside_tree() or from.distance_to(to) < 0.01:
		return false

	var space := _camera.get_world_3d().direct_space_state
	var query := PhysicsShapeQueryParameters3D.new()
	var ball := SphereShape3D.new()
	ball.radius = CLEARANCE
	query.shape = ball
	query.transform = Transform3D(Basis.IDENTITY, from)
	query.motion = to - from
	query.collision_mask = 1
	var fractions := space.cast_motion(query)
	return fractions.size() == 2 and fractions[1] < 1.0


## The frame just drawn, handed to the screen to wipe away (not headless:
## there is no frame to take there, and it is a plain cut).
func _wipe_away() -> void:
	if _screen == null or not _screen.has_method("wipe") or DisplayServer.get_name() == "headless":
		return

	var image := _camera.get_viewport().get_texture().get_image()

	if image == null or image.is_empty():
		return

	_screen.wipe(ImageTexture.create_from_image(image))
