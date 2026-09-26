extends RefCounted

const TimeFx := preload("res://scripts/Visual/TimeFx.gd")
## Camera feel. Works out the camera's offset from the eye (view_position,
## view_rotation, read as view_transform()) and writes the Camera3D's fov.
## The controller places the camera: eye * view_transform(). It never fights
## the neck (pitch, crouch height, peek) or the body (yaw). Everything here
## is cosmetic; gameplay reads nothing from it.

var camera: Camera3D
var base_fov := 75.0

## Master dial. 0 switches all of it off.
var intensity := 1.0

# Head bob
var bob_cycle_distance := 3.2
## The walk in steps (the controller's gait: a foot lands at each whole
## step). Given, the bob follows it and the head is lowest as each foot lands;
## negative, the bob keeps its own time by bob_cycle_distance.
var gait := -1.0
var bob_height := 0.035
var bob_sway := 0.02

# Strafe lean and sprint
var strafe_roll_degrees := 1.8
var sprint_fov_add := 6.0

# Landing and jumping
var landing_dip_per_speed := 0.11
var landing_dip_max := 2.4
var jump_kick := 0.5

# Choreographed moves
var mantle_dip := 0.10
var mantle_pitch_degrees := 5.0
var vault_pitch_degrees := 4.0
## Looking at your own hands as they land on the top (mantles, vaults): how
## far below the view they are (radians; set by the player each frame, 0 when
## they hold nothing), how far below the middle they may be and still be seen
## well, and the most the view tips down to see them. It comes back up as you
## go over them.
var grip_below := 0.0
var grip_comfort_degrees := 22.0
var grip_look_max_degrees := 30.0
var vault_dip := 0.16
var vault_roll_degrees := 7.0
var vault_fov_add := 5.0
var lower_pitch_degrees := 12.0
var leap_pitch_degrees := 7.0
var leap_windup_pitch_degrees := 5.0
var leap_fov_add := 3.0

# Springs
var spring_stiffness := 140.0
var spring_damping := 17.0

var _bob_phase := 0.0
var _bob_weight := 0.0
var _dip := 0.0
var _dip_velocity := 0.0
var _pitch := 0.0
var _pitch_velocity := 0.0
var _roll := 0.0
var _fov_add := 0.0
var _move_dip := 0.0
var _move_pitch := 0.0
var _move_roll := 0.0

## Leaning, set by the controller. Not scaled by `intensity`: it is a
## gameplay view, not a flourish.
var lean_offset := 0.0
var lean_roll := 0.0
## The body under the camera (BodyMotion.gd) carries the walk: when true, the
## bob, the strafe roll and the sprint widening here are left out, and
## body_head, the head's offset from the eye set by the controller each frame
## (already scaled by the dial), is added to the view instead.
var locomotion_from_body := false
var body_head := Transform3D.IDENTITY
## The camera's offset from the eye, in the eye's space, this frame.
var view_position := Vector3.ZERO
var view_rotation := Vector3.ZERO
## Killed: 0 standing, 1 lying on the floor. The head drops (faster and
## faster) and rolls onto its side.
var death := 0.0

var _roll_kick := 0.0
var _zoom := 0.0

# Impacts. Trauma is how shaken the view is (0..1); the shake is its square,
# so small knocks barely show and big ones rattle. It runs on real time, so a
# hit-stop freezes the world but not the jolt. Mostly moved, little turned:
# turning the head swings the whole horizon and sickens; moving it shows
# the blow on what is close (the talk's rule: rotation small, impact in
# translation).
var shake_degrees := 1.7
var shake_offset := 0.022
var trauma_decay := 1.7
var _trauma := 0.0
var _shake_time := 0.0
var _last_real := -1.0
var _yaw := 0.0
var _yaw_velocity := 0.0
## Forward (-) and back (+) along the view: lunges and recoils.
var _push := 0.0
var _push_velocity := 0.0
## Sideways (+ right): the head knocked aside, or carried with a cut.
var _side := 0.0
var _side_velocity := 0.0
var _fov_kick := 0.0
var _fov_kick_velocity := 0.0


func setup(p_camera: Camera3D) -> void:
	camera = p_camera
	base_fov = camera.fov


## Where the walk is in its stride (radians) and how strongly it bobs (0..1+),
## for anything that should move in step with it (the hands).
func bob_phase() -> float:
	return _bob_phase


func bob_weight() -> float:
	return _bob_weight


func on_land(fall_speed: float) -> void:
	_dip_velocity -= clampf(fall_speed * landing_dip_per_speed, 0.0, landing_dip_max)
	_pitch_velocity -= clampf(fall_speed * 0.015, 0.0, 0.5)


func on_jump() -> void:
	_dip_velocity += jump_kick


func on_hit() -> void:
	_dip_velocity -= 1.0
	_pitch_velocity += 0.35
	_push_velocity += 0.5


## A blow being gathered: the head goes the other way first (the talk's
## "the head leads the action": anticipate opposite, lead into it, reverse,
## settle). `side` +1 for a cut going to the left; a power blow's gathering
## goes further.
func on_windup(side: float, kind: StringName = &"", power := false) -> void:
	var k := 1.5 if power else 1.0
	_yaw_velocity -= side * 0.14 * k
	_side_velocity += side * 0.16 * k

	match kind:
		&"overhead":
			_pitch_velocity += 0.3 * k
			_dip_velocity += 0.25 * k
		&"thrust":
			_push_velocity += 0.45 * k
		_:
			_pitch_velocity += 0.1 * k


## A swing: the view goes with the cut. `side` +1 cuts to the left, -1 to
## the right; `kind` is the swing ("overhead", "thrust"...); power is bigger.
## The head is carried with the body's turn: a little turned, more moved.
func on_swing(side: float, power := false, kind: StringName = &"") -> void:
	var k := 1.6 if power else 1.0
	_roll_kick += side * 0.05 * k
	_yaw_velocity += side * 0.26 * k
	_side_velocity -= side * 0.3 * k

	match kind:
		&"overhead":
			_pitch_velocity -= 0.5 * k
			_dip_velocity -= 0.45 * k
		&"thrust":
			_push_velocity -= 0.9 * k
			_fov_kick_velocity -= 12.0 * k
		_:
			_pitch_velocity -= 0.18 * k

	if power:
		_push_velocity -= 0.5


## Dropping into a crouch (or rising from one): the eyes' height eases on
## its own; this is the weight in it, settling a little past and back.
func on_crouch(down: bool) -> void:
	_dip_velocity += -0.35 if down else 0.22
	_pitch_velocity += -0.08 if down else 0.05


## Throwing something: the body goes into it, the head with it.
func on_throw(strength := 1.0) -> void:
	_push_velocity -= 0.5 * strength
	_pitch_velocity -= 0.15 * strength
	_dip_velocity -= 0.2 * strength


## Shake the view: 0.2 a knock, 0.5 a heavy blow, 1 as hard as it gets.
func add_trauma(amount: float) -> void:
	_trauma = clampf(_trauma + amount, 0.0, 1.0)


## A kick to the view's springs, in radians per second.
func punch(pitch: float, yaw: float, roll := 0.0) -> void:
	_pitch_velocity += pitch
	_yaw_velocity += yaw
	_roll_kick += roll * 0.1


## Pushed along the view: negative forward, positive back.
func lunge(amount: float) -> void:
	_push_velocity += amount


## The view narrows (positive) or widens for an instant.
func fov_kick(degrees_per_second: float) -> void:
	_fov_kick_velocity -= degrees_per_second


## Struck: the head snaps away from where the blow came from. `from` is the
## attacker's direction in the player's own space.
func hurt_from(from: Vector3, strength: float) -> void:
	var side := 0.0

	if absf(from.x) > 0.2:
		side = signf(from.x)

	_pitch_velocity += 0.5 * strength
	# Away from the blow: a hit from the right knocks the head to the left
	# (mostly moved, a little turned).
	_yaw_velocity += side * 0.7 * strength
	_side_velocity -= side * 0.9 * strength
	_roll_kick += side * 0.05 * strength
	_dip_velocity -= 0.7 * strength
	_push_velocity += 0.8 * strength
	add_trauma(0.45 * strength)


## Steel meeting something: a sharp jolt, stronger for harder hits, felt as
## a knock back and down more than a turn.
func on_impact(strength: float) -> void:
	_dip_velocity -= 0.8 * strength
	_push_velocity += 0.35 * strength
	_pitch_velocity += 0.18 * strength


## Drawing a bow narrows the view, as far as `amount` degrees.
func set_zoom(amount: float) -> void:
	_zoom = amount


## The knee coming up for a kick: the weight goes back onto the other foot,
## the head with it; the boot's contact then drives it forward (on_kick_land).
func on_kick() -> void:
	_dip_velocity += 0.7
	_pitch_velocity += 0.2
	_push_velocity += 0.45


## The boot met something: the body follows it in.
func on_kick_land(strength := 1.0) -> void:
	_push_velocity -= 0.9 * strength
	_dip_velocity -= 0.3 * strength


func on_catch() -> void:
	# Hands take the weight: a short sharp drop.
	_dip_velocity -= 1.1
	_pitch_velocity -= 0.25


## move_kind: 0 none, 1 mantle-like, 2 vault, 3 lowering, 4 leap.
## move_s: 0..1 along the move. windup: 0..1 through a pre-launch pause.
func update(
	delta: float,
	horizontal_speed: float,
	reference_speed: float,
	strafe: float,
	grounded: bool,
	crouched: bool,
	sprinting: bool,
	move_kind: int,
	move_s: float,
	windup := 0.0
) -> void:
	if camera == null:
		return

	# --- springs settle toward zero -------------------------------------
	# A long frame (a hitch, a slow machine) must not throw the springs:
	# they are only stable for short steps.
	delta = minf(delta, 1.0 / 30.0)
	_dip_velocity += (-spring_stiffness * _dip - spring_damping * _dip_velocity) * delta
	_dip += _dip_velocity * delta
	_pitch_velocity += (-spring_stiffness * _pitch - spring_damping * _pitch_velocity) * delta
	_pitch += _pitch_velocity * delta
	_yaw_velocity += (-spring_stiffness * _yaw - spring_damping * _yaw_velocity) * delta
	_yaw += _yaw_velocity * delta
	_push_velocity += (-spring_stiffness * _push - spring_damping * _push_velocity) * delta
	_push += _push_velocity * delta
	_side_velocity += (-spring_stiffness * _side - spring_damping * _side_velocity) * delta
	_side += _side_velocity * delta
	_fov_kick_velocity += (-spring_stiffness * _fov_kick - spring_damping * _fov_kick_velocity) * delta
	_fov_kick += _fov_kick_velocity * delta

	# --- the shake runs on real time ------------------------------------------
	var real_delta := TimeFx.real_since(_last_real) if _last_real >= 0.0 else 0.0
	_last_real = TimeFx.real_time()
	_shake_time += real_delta
	_trauma = maxf(_trauma - trauma_decay * real_delta, 0.0)
	var shake := _trauma * _trauma
	var shake_pitch := _noise(_shake_time, 1.3) * shake * deg_to_rad(shake_degrees)
	var shake_yaw := _noise(_shake_time, 7.1) * shake * deg_to_rad(shake_degrees)
	var shake_roll := _noise(_shake_time, 13.7) * shake * deg_to_rad(shake_degrees) * 0.8

	# --- head bob ---------------------------------------------------------
	var moving := grounded and move_kind == 0 and horizontal_speed > 0.6
	var target_weight := 0.0

	if moving:
		target_weight = clampf(horizontal_speed / maxf(reference_speed, 0.01), 0.0, 1.3)

		if crouched:
			target_weight *= 0.55

	_bob_weight = lerpf(_bob_weight, target_weight, 1.0 - exp(-9.0 * delta))

	if gait >= -0.5:
		# Lowest (sin 2φ = -1) on each whole step, when the foot lands.
		_bob_phase = fmod(gait * PI + PI * 0.75 + TAU * 2.0, TAU * 2.0)
	elif moving:
		_bob_phase += horizontal_speed / maxf(bob_cycle_distance, 0.01) * TAU * delta
		_bob_phase = fmod(_bob_phase, TAU * 2.0)

	var bob_y := sin(_bob_phase * 2.0) * bob_height * _bob_weight
	var bob_x := sin(_bob_phase) * bob_sway * _bob_weight

	# --- lean into strafes, widen the view when sprinting -------------------
	var target_roll := -strafe * deg_to_rad(strafe_roll_degrees)
	var target_fov := 0.0

	if sprinting and horizontal_speed > reference_speed:
		target_fov = sprint_fov_add

	# The body carries the walk instead: its steps, its lean into turns, and
	# no widening (the run is felt in the stride, not the lens).
	if locomotion_from_body:
		bob_x = 0.0
		bob_y = 0.0
		target_roll = 0.0
		target_fov = 0.0

	# --- choreographed moves: one smooth arc over the whole move -----------
	var arc := sin(clampf(move_s, 0.0, 1.0) * PI)
	var move_dip := 0.0
	var move_pitch := 0.0
	var move_roll := 0.0

	# Down to the hands as they land, up again as the body goes over them.
	var to_hands := clampf(grip_below - deg_to_rad(grip_comfort_degrees), 0.0, deg_to_rad(grip_look_max_degrees))

	match move_kind:
		1:
			move_dip = -mantle_dip * arc
			to_hands *= 1.0 - smoothstep(0.3, 0.85, move_s)
			move_pitch = -maxf(deg_to_rad(mantle_pitch_degrees) * arc, to_hands)
		2:
			move_dip = -vault_dip * arc
			to_hands *= 1.0 - smoothstep(0.3, 0.7, move_s)
			move_pitch = -maxf(deg_to_rad(vault_pitch_degrees) * arc, to_hands)
			move_roll = deg_to_rad(vault_roll_degrees) * arc
			target_fov += vault_fov_add * arc
		3:
			move_pitch = -deg_to_rad(lower_pitch_degrees) * arc
		4:
			# Gather, then look up into the launch and down into the catch.
			move_pitch = -deg_to_rad(leap_windup_pitch_degrees) * sin(windup * PI)
			move_pitch += deg_to_rad(leap_pitch_degrees) * cos(clampf(move_s, 0.0, 1.0) * PI) * (1.0 - windup)
			target_fov += leap_fov_add * arc

	_roll = lerpf(_roll, target_roll, 1.0 - exp(-10.0 * delta))
	_fov_add = lerpf(_fov_add, target_fov - _zoom, 1.0 - exp(-7.0 * delta))
	_roll_kick = lerpf(_roll_kick, 0.0, 1.0 - exp(-9.0 * delta))

	# The arcs are followed through a filter, so a chained move that restarts
	# its arc at zero does not make the camera pop.
	var follow := 1.0 - exp(-16.0 * delta)
	_move_dip = lerpf(_move_dip, move_dip, follow)
	# Quicker down to your hands than back up: they land fast.
	var look_follow := 1.0 - exp(-28.0 * delta) if move_pitch < _move_pitch else follow
	_move_pitch = lerpf(_move_pitch, move_pitch, look_follow)
	_move_roll = lerpf(_move_roll, move_roll, follow)

	var k := intensity
	var shake_move := Vector3(shake_yaw, shake_pitch, 0.0) * (shake_offset / deg_to_rad(shake_degrees))
	view_position = (Vector3(bob_x + _side, bob_y + _dip + _move_dip, _push) + shake_move) * k + Vector3(lean_offset, 0.0, 0.0)
	view_rotation = Vector3(
		(_pitch + _move_pitch + shake_pitch) * k,
		(_yaw + shake_yaw) * k,
		(_roll + _move_roll + _roll_kick + shake_roll) * k + lean_roll
	)
	camera.fov = base_fov + (_fov_add + _fov_kick) * k

	# The body the head rides on (already scaled by the dial).
	if locomotion_from_body:
		view_position += body_head.origin
		view_rotation += body_head.basis.get_euler()

	if death > 0.0:
		var fall := death * death
		var settle := smoothstep(0.0, 1.0, death)
		view_position += Vector3(0.12 * settle, -1.3 * fall, 0.0)
		view_rotation += Vector3(0.35 * settle, 0.25 * settle, 1.15 * settle)


## The offset as a transform, rotation in the camera's own order (Y, X, Z).
func view_transform() -> Transform3D:
	return Transform3D(Basis.from_euler(view_rotation), view_position)


## How shaken the view is right now, 0..1.
func trauma() -> float:
	return _trauma


## Smooth noise from a few sines: enough for a shake, and the same every run.
static func _noise(t: float, seed_offset: float) -> float:
	return (
		sin(t * 31.0 + seed_offset) * 0.5
		+ sin(t * 17.3 + seed_offset * 2.1) * 0.3
		+ sin(t * 53.9 + seed_offset * 0.7) * 0.2
	)
