extends RefCounted
## Cosmetic head and shoulder springs driven once per physics tick by Frame.
## Head offsets are eye-local; shoulder offsets are relative to the head.
## Outputs interpolate the previous/current tick and never change gameplay aim.

## The most the head is moved (m) and turned, per axis, and the shoulders.
const HEAD_CAP := 0.15
const HEAD_TURN_CAP := deg_to_rad(3.0)
const SHOULDER_CAP := 0.2
const SHOULDER_TURN_CAP := deg_to_rad(6.0)

## The share of the torso's turning the head keeps.
const KEEP := 0.2
## Hips to the base of the neck: turns a lean of the torso into an angle.
const TORSO := 0.6
## The most acceleration the body answers to (a wall, a shove, a teleport).
const ACC_CAP := 45.0

# Footfalls: half the up-and-down travel of a step, and half the side-to-side
# shift of the weight over the planted foot.
const WALK_DROP := 0.006
const SPRINT_DROP := 0.010
const CROUCH_DROP := 0.003
const WALK_SHIFT := 0.003
const SPRINT_SHIFT := 0.003
const CROUCH_SHIFT := 0.0045
## The head tips toward the planted foot, this much at full shift.
const STEP_ROLL := deg_to_rad(0.25)
## Where in the stride (two steps, 0..1) the weight is furthest over a foot:
## a fifth of the way through each foot's step.
const SHIFT_PHASE := 0.314

# The torso: how far it carries the head per m/s² of the body's acceleration
# along its motion (speeding up the head lags, slowing it carries on) and
# across it (turning, it leans in), and its spring.
const LAG_START := 0.00035
const LAG_STOP := 0.0008
const BANK := 0.0005
const TORSO_OMEGA := 12.0
const TORSO_ZETA := 0.8
## Leaning into a sprint: the head forward and lower, never pitched.
const SPRINT_FORWARD := 0.03
const SPRINT_DOWN := 0.02

# The legs: a spring that landings, the push of a jump and the bend of a
# lean move. A hard landing softens it for a moment, so it goes deeper and
# comes back slower.
const LEG_OMEGA := 16.0
const LEG_SOFT_OMEGA := 10.0
const LEG_ZETA := 0.8
## How far a spring with LEG_ZETA goes when kicked from rest, per unit of
## kick, times its omega: kick = depth * omega / KICK_PEAK reaches `depth`.
const KICK_PEAK := 0.424
const JUMP_RISE := 0.02
const LEAN_DIP := 0.01

# The stance: the eyes' own spring into a crouch and back up. It sets off a
# touch faster than the gameplay eye eases, so the view is never behind it
# (nor more than a few centimetres ahead), and passes the new height by
# about a centimetre before it settles.
const STANCE_OMEGA := 11.0
const STANCE_ZETA := 0.9
const STANCE_LEAD := 1.05

## The springs are moved in steps no longer than this, so they behave the
## same at any physics tick rate (one Euler step per tick over-damps them).
const SUBSTEP := 1.0 / 240.0

# The arms, hanging from the shoulders: tuned near the steps' own rate, so a
# footfall swings them a little further than the head, a beat after it.
const ARM_OMEGA := 22.0
const ARM_ZETA := 0.45
## How far they are carried per m/s² of the body's acceleration.
const ARM_EXTRA := 0.0004
const ARM_ACC_CAP := 60.0

# Breathing: its travel in the view and in the hands, and its rate (Hz) at
# rest and after a sprint.
const BREATH_HEAD := 0.001
const BREATH_HANDS := 0.002
const BREATH_REST := 0.25
const BREATH_HARD := 0.55


## One tick of what the body feels, filled in by the controller.
class Frame:
	var velocity := Vector3.ZERO
	var facing := Basis.IDENTITY
	var grounded := true
	## Plain locomotion and alive: walking, running, crouching, in the air.
	var locomotion := true
	var crouched := false
	## The walk, in steps: a foot lands at each whole step (0..2).
	var gait := 0.0
	## -1 leaning fully left, +1 fully right.
	var lean := 0.0
	## The gameplay eye's drop below its standing height now (m), and where it
	## is going (0 standing, the crouch's drop when crouched).
	var eye_drop := 0.0
	var eye_target_drop := 0.0
	var walk_speed := 6.5
	var sprint_speed := 8.5
	var crouch_speed := 3.0


## The master dial (the player's camera_feel): 0 switches all of it off.
var intensity := 1.0

var _footfall: Curve
var _eye_rate := 12.0

var _vel_prev := Vector3.ZERO
var _have_prev := false
var _heading := Vector3.FORWARD

var _lean := Vector3.ZERO
var _lean_v := Vector3.ZERO
var _sprint := 0.0
var _posture := Vector3.ZERO
var _weight := 0.0
var _crouch := 0.0

var _leg := 0.0
var _leg_v := 0.0
var _leg_omega := LEG_OMEGA

var _stance := 0.0
var _stance_v := 0.0
var _stance_target := 0.0
## The gameplay eye's drop, eased here the way the controller eases it, in
## step with the spring: the controller eases its own after the tick, so its
## value in the Frame is a tick behind.
var _eye := 0.0

var _arm := Vector3.ZERO
var _arm_v := Vector3.ZERO
var _head_y1 := 0.0
var _head_y2 := 0.0

var _exertion := 0.0
var _breath := 0.0

var _head_before := Transform3D.IDENTITY
var _head_now := Transform3D.IDENTITY
var _shoulder_before := Transform3D.IDENTITY
var _shoulder_now := Transform3D.IDENTITY


## Uses footfall_curve or the built-in curve when null; eye_rate controls stance following.
func setup(footfall_curve: Curve, eye_rate: float) -> void:
	_footfall = footfall_curve if footfall_curve != null else default_footfall()
	_eye_rate = eye_rate


## Advances cosmetic springs from Frame in game seconds; nonpositive delta is a no-op.
## Integration caps a tick at 1/30 s and substeps springs for stability.
func step(delta: float, frame: Frame) -> void:
	if delta <= 0.0:
		return

	if _footfall == null:
		_footfall = default_footfall()

	# Springs are only stable for short steps: a long one is taken as 1/30 s.
	var dt := minf(delta, 1.0 / 30.0)
	var active := frame.locomotion

	# What the body feels, in its own space (x right, z back). The push is
	# measured in the world and then turned into the body, so turning the
	# view alone is not a push.
	var flat := Vector3(frame.velocity.x, 0.0, frame.velocity.z)
	var to_body := frame.facing.orthonormalized().inverse()
	var local := to_body * flat
	local.y = 0.0
	var speed := local.length()
	var accel := Vector3.ZERO

	# The first tick back in plain locomotion feels nothing: the end of a
	# move, or a teleport, is not a push.
	if active and _have_prev:
		accel = (to_body * ((flat - _vel_prev) / delta)).limit_length(ACC_CAP)
		accel.y = 0.0

	_vel_prev = flat
	_have_prev = active

	if speed > 0.3:
		_heading = local / speed

	# Along the motion the head lags a push and carries on through a stop;
	# across it (a turn) the body leans in.
	var tangential := accel
	var normal := Vector3.ZERO

	if speed > 0.3:
		tangential = _heading * accel.dot(_heading)
		normal = accel - tangential

	var walk := maxf(frame.walk_speed, 0.01)
	var gain := LAG_START if accel.dot(local) > 0.0 else LAG_STOP
	var lean_target := -tangential * gain + normal * BANK * clampf(speed / walk, 0.0, 1.0)
	var torso: Array = _spring3(_lean, _lean_v, lean_target, TORSO_OMEGA, TORSO_ZETA, dt)
	_lean = torso[0]
	_lean_v = torso[1]
	var torso_pitch := _lean.z / TORSO
	var torso_roll := -_lean.x / TORSO

	# Into a sprint: forward and lower, never pitched.
	var sprint_target := 0.0

	if active and not frame.crouched:
		sprint_target = clampf((speed - walk) / maxf(frame.sprint_speed - walk, 0.01), 0.0, 1.0)

	var blend := 1.0 - exp(-dt / 0.25)
	_sprint = lerpf(_sprint, sprint_target, blend)
	# The lean itself eases, not only how far into it you are: a flick of the
	# view mid-sprint swings it round instead of jumping it sideways.
	var posture_target := _heading * SPRINT_FORWARD * sprint_target + Vector3(0.0, -SPRINT_DOWN * sprint_target, 0.0)
	_posture = _posture.lerp(posture_target, blend)
	var posture := _posture

	# The steps: as strong as the pace asks, walking, running or creeping.
	_crouch = lerpf(_crouch, 1.0 if frame.crouched else 0.0, 1.0 - exp(-dt / 0.15))
	var reference := maxf(lerpf(walk, frame.crouch_speed, _crouch), 0.01)
	var weight_target := clampf(speed / reference, 0.0, 1.0) if active and frame.grounded else 0.0
	_weight = lerpf(_weight, weight_target, 1.0 - exp(-dt / 0.12))
	var drop_amount := lerpf(lerpf(WALK_DROP, SPRINT_DROP, _sprint), CROUCH_DROP, _crouch) * _weight
	var shift_amount := lerpf(lerpf(WALK_SHIFT, SPRINT_SHIFT, _sprint), CROUCH_SHIFT, _crouch) * _weight
	var drop := _footfall.sample(fposmod(frame.gait, 1.0)) * drop_amount
	var sway := sin(TAU * fposmod(frame.gait, 2.0) * 0.5 + SHIFT_PHASE)
	var side := sway * shift_amount
	var roll := -sway * STEP_ROLL * _weight

	# The legs, and the bend of a lean.
	_leg_omega = move_toward(_leg_omega, LEG_OMEGA, (LEG_OMEGA - LEG_SOFT_OMEGA) / 0.6 * dt)
	var leg_target := -LEAN_DIP * frame.lean * frame.lean if active else 0.0
	var legs := _spring1(Vector2(_leg, _leg_v), leg_target, _leg_omega, LEG_ZETA, dt)
	_leg = legs.x
	_leg_v = legs.y

	# The knees into a crouch or up out of one: the view follows its own
	# spring to the new height; what it adds is how far that is from the
	# gameplay eye. Out of plain locomotion it simply follows the eye.
	var stance_y := 0.0

	if active:
		if not is_equal_approx(frame.eye_target_drop, _stance_target):
			_stance_target = frame.eye_target_drop
			_stance_v = STANCE_LEAD * _eye_rate * (_stance_target - _stance)

		_eye = lerpf(_eye, _stance_target, 1.0 - exp(-_eye_rate * dt))
		var knees := _spring1(Vector2(_stance, _stance_v), _stance_target, STANCE_OMEGA, STANCE_ZETA, dt)
		_stance = knees.x
		_stance_v = knees.y
		stance_y = _eye - _stance
	else:
		# Moving with the eye, at its speed: coming back (a drop from a
		# peeking hang, the eye still easing down) the knees carry on with it
		# instead of setting off from rest behind it.
		_eye = frame.eye_drop
		_stance = frame.eye_drop
		_stance_v = STANCE_LEAD * _eye_rate * (frame.eye_target_drop - frame.eye_drop)
		_stance_target = frame.eye_target_drop

	# Breathing, harder for a while after a sprint.
	var exerting := active and _sprint > 0.5
	_exertion = move_toward(_exertion, 1.0 if exerting else 0.0, dt * (0.35 if exerting else 0.2))
	_breath = fposmod(_breath + lerpf(BREATH_REST, BREATH_HARD, _exertion) * dt, 1.0)
	var breath := sin(TAU * _breath) * (1.0 + _exertion)

	var head := Vector3(side, drop + _leg + stance_y + breath * BREATH_HEAD, 0.0) + _lean + posture
	var head_turn := Vector3(torso_pitch * KEEP, 0.0, torso_roll * KEEP + roll)

	# The arms hang from the shoulders like a weight from a moving hook: the
	# head's own vertical acceleration (a footfall, a landing) makes them lag
	# and swing past it, and the body's push makes them lag a start and swing
	# on at a stop.
	var head_acc := clampf((head.y - 2.0 * _head_y1 + _head_y2) / (dt * dt), -ARM_ACC_CAP, ARM_ACC_CAP)
	_head_y2 = _head_y1
	_head_y1 = head.y
	var arm_target := -tangential * ARM_EXTRA
	arm_target.y = 0.0
	var arms: Array = _spring3(_arm, _arm_v, arm_target, ARM_OMEGA, ARM_ZETA, dt, Vector3(0.0, -head_acc, 0.0))
	_arm = arms[0]
	_arm_v = arms[1]
	var shoulder := _arm + Vector3(0.0, breath * BREATH_HANDS, 0.0)
	var shoulder_turn := Vector3(torso_pitch * (1.0 - KEEP), 0.0, torso_roll * (1.0 - KEEP) + roll * 2.0)

	# Scaled by the dial, then held inside the caps.
	var k := maxf(intensity, 0.0)
	var head_now := Transform3D.IDENTITY
	var shoulder_now := Transform3D.IDENTITY

	if k > 0.0:
		head_now = Transform3D(Basis.from_euler(_capped(head_turn * k, HEAD_TURN_CAP)), (head * k).limit_length(HEAD_CAP))
		shoulder_now = Transform3D(Basis.from_euler(_capped(shoulder_turn * k, SHOULDER_TURN_CAP)), (shoulder * k).limit_length(SHOULDER_CAP))

	_head_before = _head_now
	_head_now = head_now
	_shoulder_before = _shoulder_now
	_shoulder_now = shoulder_now


## Feet hit the ground at `fall_speed` (m/s): the legs take it, deeper and
## slower to come back the harder it was, with a nod on a hard one, and the
## arms keep falling a moment after the legs have stopped.
func on_land(fall_speed: float) -> void:
	var depth := 0.03 * fall_speed / 9.6 if fall_speed < 9.6 else 0.03 + (fall_speed - 9.6) * 0.007
	depth = clampf(depth, 0.0, 0.12)
	var hard := clampf((fall_speed - 9.6) / 7.4, 0.0, 1.0)
	_leg_omega = lerpf(LEG_OMEGA, LEG_SOFT_OMEGA, hard)
	_leg_v -= depth * _leg_omega / KICK_PEAK
	_lean_v.z -= 0.35 * hard
	_arm_v.y -= 0.8 * depth * ARM_OMEGA


## The push-off: the legs straighten, and the view rises a little faster
## than the body does.
func on_jump() -> void:
	_leg_v += JUMP_RISE * _leg_omega / KICK_PEAK


## Clears motion history and spring outputs; preserves configuration and footfall curve.
func reset() -> void:
	_vel_prev = Vector3.ZERO
	_have_prev = false
	_heading = Vector3.FORWARD
	_lean = Vector3.ZERO
	_lean_v = Vector3.ZERO
	_sprint = 0.0
	_posture = Vector3.ZERO
	_weight = 0.0
	_crouch = 0.0
	_leg = 0.0
	_leg_v = 0.0
	_leg_omega = LEG_OMEGA
	_stance = 0.0
	_stance_v = 0.0
	_stance_target = 0.0
	_eye = 0.0
	_arm = Vector3.ZERO
	_arm_v = Vector3.ZERO
	_head_y1 = 0.0
	_head_y2 = 0.0
	_exertion = 0.0
	_head_before = Transform3D.IDENTITY
	_head_now = Transform3D.IDENTITY
	_shoulder_before = Transform3D.IDENTITY
	_shoulder_now = Transform3D.IDENTITY


## The head's offset from the eye (x right, y up, z back), drawn `fraction`
## of the way from the last tick to this one.
func head_offset(fraction: float) -> Transform3D:
	return _between(_head_before, _head_now, fraction)


## The shoulders' offset from the head, in the view's space, drawn the same
## way: what the hands add to the view's own motion.
func shoulder_offset(fraction: float) -> Transform3D:
	return _between(_shoulder_before, _shoulder_now, fraction)


## How far into a sprint the body has leaned, 0..1: the hands' running carry.
func sprint_lean() -> float:
	return _sprint


## One step's rise and fall (x: 0 as the foot lands, 1 as the next does; y:
## -1 lowest, 1 highest): already falling as the foot lands, lowest early in
## the step, rising through the rest of it.
static func default_footfall() -> Curve:
	var curve := Curve.new()
	curve.min_value = -1.0
	curve.max_value = 1.0
	curve.add_point(Vector2(0.0, 0.3), 0.0, -7.0)
	curve.add_point(Vector2(0.16, -1.0), 0.0, 0.0)
	curve.add_point(Vector2(0.62, 1.0), 0.0, 0.0)
	curve.add_point(Vector2(1.0, 0.3), -7.0, 0.0)
	return curve


## A damped spring's position and speed (x, y) after `dt`, pulled toward
## `target` and pushed by `force` (m/s²), moved in SUBSTEP steps.
static func _spring1(state: Vector2, target: float, omega: float, zeta: float, dt: float, force := 0.0) -> Vector2:
	var count := maxi(ceili(dt / SUBSTEP), 1)
	var h := dt / count
	var x := state.x
	var v := state.y

	for i in count:
		v += (omega * omega * (target - x) - 2.0 * zeta * omega * v + force) * h
		x += v * h

	return Vector2(x, v)


## The same for a spring in three dimensions: [position, velocity].
static func _spring3(x: Vector3, v: Vector3, target: Vector3, omega: float, zeta: float, dt: float, force := Vector3.ZERO) -> Array:
	var count := maxi(ceili(dt / SUBSTEP), 1)
	var h := dt / count

	for i in count:
		v += (omega * omega * (target - x) - 2.0 * zeta * omega * v + force) * h
		x += v * h

	return [x, v]


static func _between(from: Transform3D, to: Transform3D, fraction: float) -> Transform3D:
	if from == to:
		return to

	return from.interpolate_with(to, clampf(fraction, 0.0, 1.0))


static func _capped(turn: Vector3, cap: float) -> Vector3:
	return Vector3(clampf(turn.x, -cap, cap), clampf(turn.y, -cap, cap), clampf(turn.z, -cap, cap))
