extends Camera3D
## The NPC showcase's camera, three ways:
##   FREE      fly it: WASD, Q/E down and up, the right mouse button held to
##             look, Shift for fast, the scroll wheel for speed.
##   FOLLOW    a man clicked on (or Tab through the cast): it orbits him, the
##             scroll wheel for how far off, the right mouse button to go
##             round him.
##   DIRECTOR  the night filmed by the Cinema editor (scripts/Cinema): each
##             beat hands it a scene (ShowNight: whom to watch, observed or
##             dramatic) and it chooses and cuts the shots itself, told what
##             happens by the men.
## A fly key or looking with the mouse takes it from the director; C gives it
## back. It moves on real time (TimeFx.real_time): paused or slowed, you can
## still fly round the moment.

const TimeFx := preload("res://scripts/Visual/TimeFx.gd")
const CineEditorScript := preload("res://scripts/Cinema/CineEditor.gd")
const CineShot := preload("res://scripts/Cinema/CineShot.gd")

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
## Following: the half-life of the gap to its place (s), and of where it
## looks (quicker: he stays in frame).
const GLIDE := 0.6
const GLIDE_LOOK := 0.25
## Where it starts, over the yard, before the first scene.
const YARD := Vector3(0, 0.5, -1.0)
const START := Vector3(18.0, 18.0, 24.0)

## Who has it: flown, following a man, or the director (who is held while
## the others have it).
var mode := Mode.DIRECTOR:
	set(value):
		mode = value

		if _editor != null:
			_editor.hold(value != Mode.DIRECTOR)
var map: Node3D = null
var story: RefCounted = null

var _editor: Node = null
var _fade_next := false
var _speed := 6.0
var _yaw := 0.0
var _pitch := -0.5
var _looking := false
var _last := -1.0
var _look_at := YARD
## Following: whom, how far, round him; where he last was, and since when gone.
var _followed: Node3D = null
var _orbit := 5.0
var _orbit_yaw := 0.6
var _orbit_pitch := -0.35
var _last_seen := Vector3.ZERO
var _gone_for := -1.0
var _follow_index := -1


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


func _ready() -> void:
	# (Where the level says, if it does.)
	var home: Array = map.camera_home() if map != null and map.has_method("camera_home") else [START, YARD]
	global_position = home[0]
	_look_at = home[1]
	look_at(home[1], Vector3.UP)
	_yaw = rotation.y
	_pitch = rotation.x
	_editor = CineEditorScript.new()
	add_child(_editor)
	_editor.take_over(self)
	_editor.hold(mode != Mode.DIRECTOR)


## The beat's scene for the director: {mode, subjects, pin, letterbox}, its
## subjects cast names, "intruder", "@talk"... (found through the story, a
## second at a time) or men.
func want(intent: Dictionary) -> void:
	if _editor == null:
		return

	var scene := intent.duplicate(true)
	scene["subjects"] = _subjects_of(intent.get("subjects", []))

	if _fade_next:
		_fade_next = false
		scene["transition"] = &"fade"

	var pin: Dictionary = intent.get("pin", {})

	if not pin.is_empty():
		var pinned := pin.duplicate()
		pinned["subjects"] = _subjects_of(pin.get("subjects", intent.get("subjects", [])))
		scene["pin"] = pinned

	_editor.scene(scene)


## The next scene wanted opens through black (an act begins).
func fade_next() -> void:
	_fade_next = true


## The director (for the overlay, the stills and the checks).
func cinema_editor() -> Node:
	return _editor


## The director's screen (the letterbox: the overlay puts subtitles in it).
func cinema_screen() -> CanvasLayer:
	return _editor.screen() if _editor != null else null


func follow(man: Node3D) -> void:
	if man == null or not is_instance_valid(man):
		return

	_followed = man
	_gone_for = -1.0
	_look_at = global_position - global_basis.z * 10.0
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


## What it frames now: the followed man, the director's man, or where it
## looks.
func focus_point() -> Vector3:
	if mode == Mode.FOLLOW:
		return _last_seen if _followed == null or not is_instance_valid(_followed) else _followed.global_position

	if mode == Mode.DIRECTOR and _editor != null:
		var on: Array = (_editor.current().get("subjects", []) as Array).filter(func(m): return m != null and is_instance_valid(m))

		if not on.is_empty():
			return CineShot.head_of(on[0])

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
	var wish := _fly_input()

	if wish != Vector3.ZERO and mode != Mode.FREE:
		_take_over()

	match mode:
		Mode.FREE:
			_fly(wish, dt)
		Mode.FOLLOW:
			_follow(dt)


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


## Toward `where`, looking at `look`: a glide with a half-life of GLIDE.
func _glide(where: Vector3, look: Vector3, dt: float) -> void:
	var k := 1.0 - pow(0.5, dt / GLIDE) if dt > 0.0 else 0.0
	var k_look := 1.0 - pow(0.5, dt / GLIDE_LOOK) if dt > 0.0 else 0.0
	global_position = global_position.lerp(where, k)
	_look_at = _look_at.lerp(look, k_look)

	if global_position.distance_to(_look_at) > 0.05:
		look_at(_look_at, Vector3.UP)


## The men `names` names: men as they are, else found through the story when
## the director asks.
func _subjects_of(names: Array) -> Variant:
	if names.all(func(n): return n is Node3D):
		return names

	var told := story
	return func() -> Array: return told.subjects({"subjects": names}) if told != null else []
