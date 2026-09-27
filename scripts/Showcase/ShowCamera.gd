extends Camera3D
## The NPC showcase's camera, three ways:
##   FREE      fly it: WASD, Q/E down and up, the right mouse button held to
##             look, Shift for fast, the scroll wheel for speed.
##   FOLLOW    a man clicked on (or Tab through the cast): it orbits him, the
##             scroll wheel for how far off, the right mouse button to go
##             round him.
##   DIRECTOR  each beat of the night asks for a shot (ShowDirector's
##             beat_started) and it glides to it, or cuts when that is too far
##             to glide. With nothing asked, it frames whoever last changed his
##             mind about something.
## A fly key or looking with the mouse takes it from the director; C gives it
## back. It moves on real time (TimeFx.real_time): paused or slowed, you can
## still fly round the moment.

const TimeFx := preload("res://scripts/Visual/TimeFx.gd")

## Following someone (for the overlay's name card), or nobody.
signal following(man: Node3D)

enum Mode { FREE, FOLLOW, DIRECTOR }

## Flying: the speed range (m/s), what a scroll notch does to it, Shift.
const FLY_SPEED := Vector2(0.5, 40.0)
const FLY_STEP := 1.25
const FAST := 4.0
## Looking with the mouse (radians a pixel).
const LOOK := 0.004
## Following: how far off (m), and where on him it looks.
const ORBIT := Vector2(2.0, 20.0)
const ORBIT_HEIGHT := 1.7
## A followed man gone: his last place held this long, then the director.
const LOST_HOLD := 2.0
## Gliding: the half-life of the gap to the shot (s), and of where it looks
## (quicker: the subject stays in frame); further than this and it cuts.
const GLIDE := 0.6
const GLIDE_LOOK := 0.25
## A close shot keeps the side it began on, turning with its man only this
## slowly (half-life, s), not with every turn of his head.
const CLOSE_TURN := 3.0
const CUT_BEYOND := 25.0
## The shots: the crane's distance, height and drift; a close shot's distance;
## a tracking shot's place behind and above; a reveal's pull-back time.
const CRANE := Vector3(30.0, 18.0, 0.03)
const CLOSE := 1.6
const TRACK := Vector2(4.0, 4.5)
const REVEAL := 5.0
## The yard's middle, for the crane.
const YARD := Vector3(0, 0.5, -1.0)
## A two-shot of men far apart: no further off than this, higher the more
## they are spread.
const TWO_FAR := 14.0
const TWO_RISE := 0.5
## Where a man's head is, by what he is doing (lying, kneeling), over his
## feet (times his size).
const HEAD_LYING := 0.35
const HEAD_KNEELING := 0.95
const HEAD_STANDING := 1.6
## A wall between the camera and what it frames: it rises over it by these
## steps (m), or else comes in to just short of it.
const CLEAR_STEPS := [1.5, 3.0, 5.0, 8.0, 12.0]
## The last resort: from above, a little to the south.
const OVERHEAD := Vector3(0.0, 14.0, 3.0)
## With nothing asked, a man whose state changed this recently is framed.
const RECENT := 10.0

var mode := Mode.DIRECTOR
var map: Node3D = null
var story: RefCounted = null

var _speed := 6.0
var _yaw := 0.0
var _pitch := -0.5
var _looking := false
var _clock := 0.0
var _last := -1.0
## The director's shot and when it began; the men it names.
var _shot: Dictionary = {}
var _shot_at := 0.0
var _subjects: Array = []
## Where it looks now, and where the shot wants it (position, look-at).
var _look_at := YARD
var _goal_position := Vector3.ZERO
var _goal_look := YARD
## Following: whom, how far, round him; where he last was, and since when gone.
var _followed: Node3D = null
var _orbit := 5.0
var _orbit_yaw := 0.6
var _orbit_pitch := -0.35
var _last_seen := Vector3.ZERO
var _gone_for := -1.0
var _follow_index := -1
## The way a close shot looks at its man from (unset: INF).
var _close_from := Vector3.INF
var _dt := 0.0
## The last man to change his mind about something, and when.
var _recent: Node3D = null
var _recent_at := -100.0


func _init() -> void:
	name = "ShowCamera"
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Moved every drawn frame, so drawn where it is put (interpolated between
	# physics ticks it would lag and judder: PlayerController does the same).
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	fov = 55.0


func setup(p_map: Node3D, p_story: RefCounted) -> void:
	map = p_map
	story = p_story

	if map != null:
		for name in map.cast:
			var man: Node = map.cast[name]
			man.alert_changed.connect(_on_alert_changed.bind(man))


func _ready() -> void:
	global_position = YARD + Vector3(CRANE.x * 0.6, CRANE.y, CRANE.x * 0.8)
	look_at(YARD, Vector3.UP)
	_yaw = rotation.y
	_pitch = rotation.x


## The director's shot for the beat: {"type", "subjects"} (subjects cast
## names, "intruder", or men).
func want(shot: Dictionary) -> void:
	_shot = shot
	_shot_at = _clock
	_subjects = _resolve(shot)
	_close_from = Vector3.INF

	if mode == Mode.DIRECTOR:
		_aim(0.0)

		if global_position.distance_to(_goal_position) > CUT_BEYOND:
			_cut()


func follow(man: Node3D) -> void:
	if man == null or not is_instance_valid(man):
		return

	_followed = man
	_gone_for = -1.0
	mode = Mode.FOLLOW
	following.emit(man)


## The next man of the cast to follow (Tab).
func next_follow() -> void:
	if map == null:
		return

	var names: Array = map.cast.keys()

	for step in names.size():
		_follow_index = (_follow_index + 1) % names.size()
		var man: Variant = map.cast[names[_follow_index]]

		if man != null and is_instance_valid(man) and not (man as Node3D)._knocked_out:
			follow(man)
			return


## What it frames now: the followed man, the shot's subjects, or where it
## looks.
func focus_point() -> Vector3:
	if mode == Mode.FOLLOW:
		return _last_seen if _followed == null or not is_instance_valid(_followed) else _followed.global_position

	return _look_at


# ---------------------------------------------------------------------------
# Input
# ---------------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var button := event as InputEventMouseButton

		if button.button_index == MOUSE_BUTTON_RIGHT:
			_looking = button.pressed
		elif button.pressed and button.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			var up := button.button_index == MOUSE_BUTTON_WHEEL_UP

			if mode == Mode.FOLLOW:
				_orbit = clampf(_orbit / FLY_STEP if up else _orbit * FLY_STEP, ORBIT.x, ORBIT.y)
			else:
				_speed = clampf(_speed * FLY_STEP if up else _speed / FLY_STEP, FLY_SPEED.x, FLY_SPEED.y)
		elif button.pressed and button.button_index == MOUSE_BUTTON_LEFT:
			var man := _man_under(button.position)

			if man != null:
				follow(man)
	elif event is InputEventMouseMotion and _looking:
		# In screen pixels, whatever size the window is.
		var motion := (event as InputEventMouseMotion).screen_relative

		if mode == Mode.FOLLOW:
			_orbit_yaw -= motion.x * LOOK
			_orbit_pitch = clampf(_orbit_pitch - motion.y * LOOK, -1.3, 0.2)
		else:
			_take_over()
			_yaw -= motion.x * LOOK
			_pitch = clampf(_pitch - motion.y * LOOK, -1.5, 1.5)
	elif event is InputEventKey and event.pressed and not event.echo:
		match (event as InputEventKey).physical_keycode:
			KEY_C:
				mode = Mode.DIRECTOR
				following.emit(null)
			KEY_TAB:
				next_follow()
			_:
				return

		get_viewport().set_input_as_handled()


## A fly key or a look: the camera is yours now.
func _take_over() -> void:
	if mode != Mode.FREE:
		mode = Mode.FREE
		_yaw = rotation.y
		_pitch = rotation.x
		following.emit(null)


func _fly_input() -> Vector3:
	var wish := Vector3.ZERO

	if Input.is_physical_key_pressed(KEY_W):
		wish.z -= 1.0
	if Input.is_physical_key_pressed(KEY_S):
		wish.z += 1.0
	if Input.is_physical_key_pressed(KEY_A):
		wish.x -= 1.0
	if Input.is_physical_key_pressed(KEY_D):
		wish.x += 1.0
	if Input.is_physical_key_pressed(KEY_E):
		wish.y += 1.0
	if Input.is_physical_key_pressed(KEY_Q):
		wish.y -= 1.0

	return wish


func _man_under(at: Vector2) -> Node3D:
	var from := project_ray_origin(at)
	var query := PhysicsRayQueryParameters3D.create(from, from + project_ray_normal(at) * 200.0, 2)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	var collider: Object = hit.get("collider")
	return collider as Node3D if collider is Node3D and (collider as Node).is_in_group(&"guards") else null


# ---------------------------------------------------------------------------
# Every drawn frame
# ---------------------------------------------------------------------------

func _process(_delta: float) -> void:
	var now := TimeFx.real_time()
	var dt := clampf(now - _last, 0.0, 0.1) if _last >= 0.0 else 0.0
	_last = now
	_clock += dt

	var wish := _fly_input()

	if wish != Vector3.ZERO and mode != Mode.FREE:
		_take_over()

	match mode:
		Mode.FREE:
			_fly(wish, dt)
		Mode.FOLLOW:
			_follow(dt)
		Mode.DIRECTOR:
			_direct(dt)


func _fly(wish: Vector3, dt: float) -> void:
	rotation = Vector3(_pitch, _yaw, 0.0)
	var fast := FAST if Input.is_physical_key_pressed(KEY_SHIFT) else 1.0
	var move := global_basis * Vector3(wish.x, 0.0, wish.z)
	move.y += wish.y
	global_position += move.normalized() * _speed * fast * dt if move.length() > 0.01 else Vector3.ZERO
	_look_at = global_position - global_basis.z * 10.0


func _follow(dt: float) -> void:
	if _followed != null and is_instance_valid(_followed) and not _followed._knocked_out:
		_last_seen = _followed.global_position
		_gone_for = -1.0
	else:
		# Gone: where he fell a while, then the director.
		_gone_for = 0.0 if _gone_for < 0.0 else _gone_for + dt

		if _gone_for >= LOST_HOLD:
			_followed = null
			mode = Mode.DIRECTOR
			following.emit(null)
			return

	var target := _last_seen + Vector3.UP * ORBIT_HEIGHT
	var offset := Vector3(0, 0, _orbit).rotated(Vector3.RIGHT, _orbit_pitch).rotated(Vector3.UP, _orbit_yaw)
	_glide(target + offset, target, dt)


func _direct(dt: float) -> void:
	_aim(dt)

	# A wall across the way there: a cut, not a glide through it.
	if global_position.distance_to(_goal_position) > 1.0 and is_inside_tree() and not _ray(get_world_3d().direct_space_state, global_position, _goal_position).is_empty():
		_cut()
		return

	_glide(_goal_position, _goal_look, dt)


## Where the shot wants the camera now (_goal_position, _goal_look).
func _aim(_dt: float) -> void:
	self._dt = _dt
	var type: StringName = _shot.get("type", &"")
	var men := _subjects.filter(func(m): return m != null and is_instance_valid(m) and not (m as Node3D)._knocked_out)

	# Nothing asked, or nobody left in it: whoever last changed his mind.
	if men.is_empty() and type != &"wide":
		if _recent != null and is_instance_valid(_recent) and _clock - _recent_at < RECENT:
			men = [_recent]
			type = &"two"
		else:
			type = &"wide"

	match type:
		&"close":
			_frame_close(men[0], _dt)
		&"track":
			_frame_track(men)
		&"reveal":
			var t := clampf((_clock - _shot_at) / REVEAL, 0.0, 1.0)

			if t < 0.25:
				_frame_close(men[0], _dt)
			else:
				var close_position := _goal_position
				var close_look := _goal_look
				_frame_wide()
				_goal_position = close_position.lerp(_goal_position, smoothstep(0.25, 1.0, t))
				_goal_look = close_look.lerp(_goal_look, smoothstep(0.25, 1.0, t))
		&"two":
			_frame_two(men)
		_:
			_frame_wide()

	# Nothing solid between it and what it frames.
	_goal_position = _clear_view(_goal_look, _goal_position)


func _frame_wide() -> void:
	var yaw := 0.65 + _clock * CRANE.z
	_goal_position = YARD + Vector3(sin(yaw) * CRANE.x, CRANE.y, cos(yaw) * CRANE.x)
	_goal_look = YARD


func _frame_close(man: Node3D, dt := 0.0) -> void:
	var head := man.global_position + Vector3.UP * _head_height(man)
	var ahead := -man.global_basis.z
	ahead.y = 0.0
	ahead = ahead.normalized() if ahead.length() > 0.01 else Vector3.FORWARD

	# From the side it began on, turning only slowly with him.
	if _close_from == Vector3.INF:
		_close_from = ahead
	else:
		_close_from = _close_from.slerp(ahead, 1.0 - pow(0.5, dt / CLOSE_TURN) if dt > 0.0 else 0.0).normalized()

	var side := Vector3.UP.cross(_close_from).normalized()
	_goal_position = head + _close_from * CLOSE + side * 0.35 + Vector3.UP * 0.1
	_goal_look = head


func _frame_track(men: Array) -> void:
	var man: Node3D = men[0]
	var going: Vector3 = man.velocity if man.get("velocity") is Vector3 else Vector3.ZERO
	going.y = 0.0

	if going.length() < 0.5:
		going = -man.global_basis.z
		going.y = 0.0

	going = going.normalized() if going.length() > 0.01 else Vector3.FORWARD
	var at := _centre(men)
	_goal_position = at - going * TRACK.x + Vector3.UP * TRACK.y
	_goal_look = at + going * 2.0 + Vector3.UP * 0.6


func _frame_two(men: Array) -> void:
	var at := _centre(men)
	var spread := 0.0

	for a in men:
		for b in men:
			spread = maxf(spread, (a as Node3D).global_position.distance_to((b as Node3D).global_position))

	var across := Vector3.RIGHT

	if men.size() >= 2:
		var line: Vector3 = (men[1] as Node3D).global_position - (men[0] as Node3D).global_position
		line.y = 0.0

		if line.length() > 0.05:
			across = Vector3.UP.cross(line.normalized())

	# The side of the pair the camera is on already (no flip across them).
	if across.dot(global_position - at) < 0.0:
		across = -across

	_goal_position = at + across * minf(2.2 * spread + 3.0, TWO_FAR) + Vector3.UP * (1.2 + spread * TWO_RISE)
	_goal_look = at


func _centre(men: Array) -> Vector3:
	var sum := Vector3.ZERO

	for m in men:
		sum += (m as Node3D).global_position

	return sum / float(men.size()) + Vector3.UP * 1.3


func _head_height(man: Node3D) -> float:
	var doing: StringName = man.activity() if man.has_method("activity") else &""

	if doing in [&"sleep", &"lie_down", &"wake"]:
		return HEAD_LYING

	if doing in [&"kneel", &"plead_kneel", &"rise_knees", &"rummage", &"sit", &"sit_talk", &"sit_down", &"sneak"]:
		return HEAD_KNEELING * _size(man)

	return HEAD_STANDING * _size(man)


func _size(man: Node3D) -> float:
	var rig: Variant = man.get("_rig")
	return float(rig.get("size")) if rig != null and rig.get("size") != null else 1.0


## `want`, or, if a wall stands between it and `look`, the lowest of the
## CLEAR_STEPS over it with a clear view; then the same from the other side
## of `look`; failing all, straight down on it from high up (the yard has no
## roofs over it).
func _clear_view(look: Vector3, want: Vector3) -> Vector3:
	if not is_inside_tree():
		return want

	var space := get_world_3d().direct_space_state

	if _ray(space, look, want).is_empty():
		return want

	var across := look + Vector3(look.x - want.x, want.y - look.y, look.z - want.z)

	for side in [want, across]:
		for step in CLEAR_STEPS:
			var higher: Vector3 = side + Vector3.UP * float(step)

			if _ray(space, look, higher).is_empty():
				return higher

	return look + OVERHEAD


func _ray(space: PhysicsDirectSpaceState3D, from: Vector3, to: Vector3) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(from, to, 1)
	query.collide_with_areas = false
	return space.intersect_ray(query)


## Toward `where`, looking at `look`: a glide with a half-life of GLIDE.
func _glide(where: Vector3, look: Vector3, dt: float) -> void:
	var k := 1.0 - pow(0.5, dt / GLIDE) if dt > 0.0 else 0.0
	var k_look := 1.0 - pow(0.5, dt / GLIDE_LOOK) if dt > 0.0 else 0.0
	global_position = global_position.lerp(where, k)
	_look_at = _look_at.lerp(look, k_look)

	if global_position.distance_to(_look_at) > 0.05:
		look_at(_look_at, Vector3.UP)


func _cut() -> void:
	global_position = _goal_position
	_look_at = _goal_look
	look_at(_look_at, Vector3.UP)


func _resolve(shot: Dictionary) -> Array:
	var found := []

	for subject in shot.get("subjects", []):
		if subject is Node3D:
			found.append(subject)
		elif story != null and story.has_method("subjects"):
			found.append_array(story.subjects({"subjects": [subject]}))

	return found


func _on_alert_changed(_new_state: int, _old_state: int, man: Node) -> void:
	_recent = man as Node3D
	_recent_at = _clock
