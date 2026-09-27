extends Node
## The director: given a scene (who matters, and how to watch them), it
## chooses the shots and cuts between them as a film editor would, told what
## happens by CineEvents, and hands each shot to its operator (CineOperator)
## to take. Two ways of watching:
##   observe  Tarkovsky: long takes (15 to 45 s) from far off on a long lens,
##            or drifting slowly round the men; it moves rather than cuts,
##            never cuts in the middle of a line, pushes in over a long talk,
##            holds a while after it, and in a long quiet drifts to the fire
##            or a torch.
##   drama    Kurosawa (see _drama_step).
## Either way: no jump cut, a new shot when the man it is on is hidden or
## gone, never a cut before FLOOR, and a pinned shot held whatever happens.
## Knows nothing of any level's story: a scene is {mode, subjects (the men,
## or a Callable giving them, asked once a second), pin, letterbox}.

signal shot_started(shot: Dictionary)

const CineEvents := preload("res://scripts/Cinema/CineEvents.gd")
const CineShot := preload("res://scripts/Cinema/CineShot.gd")
const CineVantage := preload("res://scripts/Cinema/CineVantage.gd")
const CineOperator := preload("res://scripts/Cinema/CineOperator.gd")
const CineScreen := preload("res://scripts/Cinema/CineScreen.gd")
const TimeFx := preload("res://scripts/Visual/TimeFx.gd")

## Observe: a take's length (s); a new interest this near is moved to, not
## cut to (m); over a talk the lens narrows to this share of its width in
## this long (s); after a talk it holds this long (s); after this long quiet
## (s, no line for QUIET) it drifts to a fire or a torch this near (m).
const TAKE := Vector2(15.0, 45.0)
const MOVE_WITHIN := 12.0
const PUSH_TO := 0.7
const PUSH_OVER := 20.0
const LINGER := 3.0
const ELEMENT_AFTER := Vector2(60.0, 90.0)
const QUIET := 8.0
const ELEMENTS := [&"fires", &"torches"]
const ELEMENT_REACH := 25.0
## Drifting round the men: how far off (m), how high (m), how much of a
## circle at most (rad), and in how many points.
const ROVE_RADIUS := 4.0
const ROVE_HEIGHT := 1.7
const ROVE_MOST := 1.6
const ROVE_POINTS := 4
## Both: a hidden subject this long (s) and it is a new shot; no cut before
## this (s); events this near a subject count (m); a cut to the same size
## from within this angle (deg) is a jump cut; lines this close together
## are one talk (s).
const HIDDEN_FOR := 0.6
const FLOOR := 1.5
const NEAR := 12.0
const SAME_ANGLE := 30.0
const TALK_GAP := 3.0
const RESOLVE_EVERY := 1.0
## Which events come first when several fall at once.
const PRIORITY := {&"death": 6, &"knife": 5, &"blow": 4, &"alert": 3, &"spotted": 3, &"line": 2, &"gathering": 1}

var _camera: Camera3D = null
var _operator: Node = null
var _screen: CanvasLayer = null
var _intent: Dictionary = {}
var _mode: StringName = &"observe"
var _subjects: Array = []
var _resolve_in := 0.0
var _shot: Dictionary = {}
var _history: Array = []
var _clock := 0.0
var _last := -1.0
var _hidden := 0.0
var _talk_until := -INF
var _talk_since := -INF
var _speaker: Node3D = null
var _quiet_since := 0.0
var _interest: Dictionary = {}
var _element_in := 60.0
var _pin_until := -INF
var _place := Vector3.ZERO
var _rove_next := false


func _init() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE


## Takes `camera`: an operator and a screen of its own, and it listens.
func take_over(camera: Camera3D) -> void:
	_camera = camera
	_screen = CineScreen.new()
	add_child(_screen)
	_operator = CineOperator.new()
	add_child(_operator)
	_operator.attach(camera, _screen)
	_operator.set_mode(_mode)
	CineEvents.add_listener(self)
	_element_in = randf_range(ELEMENT_AFTER.x, ELEMENT_AFTER.y)
	_quiet_since = _clock
	_last = -1.0


## Lets the camera go: its slow motion over, its screen cleared, its operator
## gone.
func release() -> void:
	CineEvents.remove_listener(self)
	TimeFx.cancel(&"cinema")

	if _screen != null and is_instance_valid(_screen):
		_screen.clear()
		_screen.queue_free()

	if _operator != null and is_instance_valid(_operator):
		_operator.queue_free()

	_camera = null
	_screen = null
	_operator = null
	_shot = {}


func _exit_tree() -> void:
	CineEvents.remove_listener(self)


## A new scene: `intent` {mode "observe"|"drama", subjects (men, or a Callable
## giving them), pin {kind, subjects, seconds}, letterbox}. Its first shot at
## once.
func scene(intent: Dictionary) -> void:
	_intent = intent.duplicate()
	_mode = StringName(intent.get("mode", &"observe"))

	if _operator != null:
		_operator.set_mode(_mode)

	_resolve()
	_talk_until = -INF
	_interest = {}
	_quiet_since = _clock
	var pin: Dictionary = intent.get("pin", {})

	if not pin.is_empty() and _camera != null:
		var men := _men_of(pin.get("subjects", _subjects))
		_pin_until = _clock + float(pin.get("seconds", 5.0))
		_start(StringName(pin.get("kind", &"medium")), men, &"pin", &"cut", {}, float(pin.get("seconds", 5.0)))
		return

	_pin_until = -INF

	if _camera != null:
		_fresh_take(&"scene")


func mode() -> StringName:
	return _mode


## The shot being taken: {kind, size, subjects, cause, how, at, real_at, ...}.
func current() -> Dictionary:
	return _shot


## Every shot taken, in order.
func history() -> Array:
	return _history


func screen() -> CanvasLayer:
	return _screen


## CineEvents: what happened, if it is near the scene's men.
func cine_event(kind: StringName, data: Dictionary) -> void:
	if _camera == null or not _relevant(data):
		return

	_quiet_since = _clock

	if kind == &"line":
		if _clock > _talk_until + TALK_GAP:
			_talk_since = _clock

		_talk_until = maxf(_talk_until, _clock + float(data.get("seconds", 1.0)))
		_speaker = data.get("speaker") as Node3D

	var priority := int(PRIORITY.get(kind, 0))

	if _interest.is_empty() or float(_interest["at"]) < _clock or priority >= int(_interest["priority"]):
		_interest = {"kind": kind, "data": data, "at": _clock, "priority": priority}


func _process(_delta: float) -> void:
	var dt := TimeFx.real_since(_last) if _last >= 0.0 else 0.0
	_last = TimeFx.real_time()

	if _camera == null or not is_instance_valid(_camera):
		return

	_clock += dt
	_resolve_in -= dt

	if _resolve_in <= 0.0:
		_resolve()

	_subjects = _subjects.filter(_valid)

	if not _subjects.is_empty():
		_place = CineShot.centre_of(_subjects)

	if _shot.is_empty():
		_fresh_take(&"start")
		return

	var age := _clock - float(_shot["at"])
	var framed: Array = _shot["subjects"]
	var live := framed.filter(_valid)
	var pinned := _clock < _pin_until

	# A man it was on is gone (freed): a new shot.
	if live.size() < framed.size() and age >= FLOOR and not pinned:
		_fresh_take(&"lost")
		return

	_follow(live)
	_watch(live, dt)

	if _hidden > HIDDEN_FOR and age >= FLOOR and not pinned:
		_fresh_take(&"hidden")
		return

	if pinned:
		return

	_observe_step(age)


# ---------------------------------------------------------------------------
# Observe
# ---------------------------------------------------------------------------

func _observe_step(age: float) -> void:
	if _subjects.is_empty():
		if _shot["kind"] != &"establishing" and age >= FLOOR:
			_fresh_take(&"nobody")

		return

	# Nothing cut in the middle of a line, nor straight after the talk.
	if _clock < _talk_until or _clock - _talk_until < LINGER:
		return

	if age < TAKE.x:
		return

	var newer: bool = not _interest.is_empty() and float(_interest["at"]) > float(_shot["at"])

	if age >= float(_shot.get("planned", TAKE.y)) or newer or _element_due():
		_fresh_take(&"interest" if newer else &"take")


## The next take: the fire or a torch in a long quiet; else, turn about, from
## far off on a long lens or drifting round the men; the place from on high
## with nobody to watch.
func _fresh_take(cause: StringName) -> void:
	var men := _subjects.filter(_valid)

	if men.is_empty():
		_start(&"establishing", [], &"nobody" if cause != &"scene" else cause, &"cut", {"from": _high_over(_place), "place": _place}, TAKE.y)
		return

	var length := randf_range(TAKE.x, TAKE.y)

	if _element_due():
		var element := _element()

		if element != null:
			_element_in = randf_range(ELEMENT_AFTER.x, ELEMENT_AFTER.y)
			_quiet_since = _clock
			_start(&"insert", [], &"element", &"cut", {"target": element}, length)
			return

	var space := _camera.get_world_3d().direct_space_state
	var tries := [&"roving", &"observe"] if _rove_next else [&"observe", &"roving"]
	_rove_next = not _rove_next

	for kind in tries:
		var plan := _observe_plan(kind, men, space, length)

		if plan.is_empty() or _jump_cut(plan):
			continue

		_start(kind, men, cause, plan["how"], plan["context"], length)
		return

	# Nothing fresh to be had: a take from far off all the same.
	_start(&"observe", men, cause, &"cut", {"from": _high_over(CineShot.centre_of(men))}, length)


## Where a take of `kind` comes from: {how, context, position, size}; empty if
## there is nowhere to take it from.
func _observe_plan(kind: StringName, men: Array, space: PhysicsDirectSpaceState3D, length: float) -> Dictionary:
	var centre := CineShot.centre_of(men)

	if kind == &"observe":
		var from := CineVantage.best(get_tree(), men, &"long", Vector3.ZERO, space)

		if from == Vector3.INF:
			return {}

		var framing := CineShot.frame(&"observe", men, {"from": from, "aspect": _aspect()})
		var how := _how_to(from)
		var context := {"from": from}

		if how == &"path":
			context["path"] = PackedVector3Array([_camera.global_position, from])

		return {"how": how, "context": context, "position": from, "size": framing["size"]}

	# Drifting round them: an arc from the side the camera is on, as far as
	# the take lets it go at a dolly's pace, every point seeing them.
	var start_dir := _camera.global_position - centre
	start_dir.y = 0.0
	start_dir = start_dir.normalized() if start_dir.length() > 0.1 else Vector3.BACK
	var span := minf(length * float(CineOperator.MODES[&"observe"]["speed"]) * 0.8 / ROVE_RADIUS, ROVE_MOST)
	var turn := 1.0 if randf() < 0.5 else -1.0

	for attempt in [0.0, PI * 0.5, -PI * 0.5, PI]:
		var points := PackedVector3Array()
		var clear := true

		for i in ROVE_POINTS:
			var angle := float(attempt) + turn * span * float(i) / float(ROVE_POINTS - 1)
			var point := Vector3(centre.x, 0.0, centre.z) + start_dir.rotated(Vector3.UP, angle) * ROVE_RADIUS + Vector3.UP * ROVE_HEIGHT

			if not CineVantage.sees(space, point, men):
				clear = false
				break

			points.append(point)

		if not clear:
			continue

		var how := _how_to(points[0])
		var path := points

		if how == &"path":
			path = PackedVector3Array([_camera.global_position])
			path.append_array(points)
		else:
			how = &"path"

		return {"how": how, "context": {"path": path, "from": points[0]}, "position": points[0], "size": &"medium", "cut_first": _how_to(points[0]) != &"path"}

	return {}


## A move there if it is near and the way is clear; else a cut.
func _how_to(position: Vector3) -> StringName:
	var here := _camera.global_position

	if here.distance_to(position) <= MOVE_WITHIN and not _operator.blocked(here, position):
		return &"path" if _mode == &"observe" else &"glide"

	return &"cut"


## Whether `plan` would cut to the same size from within SAME_ANGLE of the
## shot now (a moving take is not a cut).
func _jump_cut(plan: Dictionary) -> bool:
	if _shot.is_empty() or plan.get("how") == &"path" and not plan.get("cut_first", false):
		return false

	if plan.get("size") != _shot.get("size"):
		return false

	var centre := CineShot.centre_of(_shot.get("subjects", []).filter(_valid)) if not (_shot.get("subjects", []) as Array).is_empty() else _place
	var was: Vector3 = _camera.global_position - centre
	var will: Vector3 = (plan["position"] as Vector3) - centre
	was.y = 0.0
	will.y = 0.0

	if was.length() < 0.1 or will.length() < 0.1:
		return false

	return rad_to_deg(was.angle_to(will)) < SAME_ANGLE


func _element_due() -> bool:
	return _clock - _quiet_since + TAKE.x >= _element_in and _clock - _talk_until >= QUIET and _element() != null


## The fire or torch nearest the men, near enough; else null.
func _element() -> Node3D:
	var best: Node3D = null

	for group in ELEMENTS:
		for node in get_tree().get_nodes_in_group(group):
			if not (node is Node3D) or not is_instance_valid(node):
				continue

			var d := (node as Node3D).global_position.distance_to(_place)

			if d <= ELEMENT_REACH and (best == null or d < best.global_position.distance_to(_place)):
				best = node

	return best


# ---------------------------------------------------------------------------
# Taking a shot
# ---------------------------------------------------------------------------

## Begins the shot `kind` of `men`, taken `how` ("cut", "glide", "path",
## "wipe"), planned to run `planned` s; tells whoever listens.
func _start(kind: StringName, men: Array, cause: StringName, how: StringName, context: Dictionary, planned: float) -> void:
	var ctx := context.duplicate()
	ctx["aspect"] = _aspect()
	var framing := CineShot.frame(kind, men, ctx)

	if how == &"path":
		var path: PackedVector3Array = ctx.get("path", PackedVector3Array())

		if path.size() < 2:
			how = &"cut"
		else:
			framing["position"] = path[path.size() - 1]
			framing["path"] = path

			# The first point is somewhere else altogether: be there first.
			if _camera.global_position.distance_to(path[0]) > 0.5:
				var first := framing.duplicate()
				first["position"] = path[0]
				_operator.show(first, &"cut")

	_operator.show(framing, how)
	_shot = {"kind": kind, "size": framing["size"], "subjects": men.duplicate(), "cause": cause, "how": how, "at": _clock,
		"real_at": TimeFx.real_time(), "framing": framing, "context": ctx, "planned": planned,
		"offset": (framing["look"] as Vector3) - (framing["subject"] as Vector3)}
	_history.append(_shot)
	_hidden = 0.0
	shot_started.emit(_shot)


## The shot's marks kept on its men as they move: from a fixed place the aim
## follows; drifting, the aim from where it has got to; over a talk the lens
## narrows and the aim leans toward whoever speaks.
func _follow(live: Array) -> void:
	var kind: StringName = _shot["kind"]

	if kind in [&"establishing", &"insert", &"overhead"] or live.is_empty():
		return

	var ctx: Dictionary = (_shot["context"] as Dictionary).duplicate()
	ctx["aspect"] = _aspect()

	if kind == &"roving":
		ctx["from"] = _camera.global_position

	var framing := CineShot.frame(kind, live, ctx)

	if not (kind in [&"roving", &"observe", &"group"]):
		framing["position"] = _shot["framing"]["position"]
		framing["look"] = (framing["subject"] as Vector3) + (_shot["offset"] as Vector3)

	var base_fov := float(_shot["framing"]["fov"])

	# Over a talk the lens narrows (and stays narrowed for the rest of the
	# take).
	if _mode == &"observe" and _clock < _talk_until + TALK_GAP and _talk_since > -INF:
		var talked := _clock - maxf(_talk_since, float(_shot["at"]))
		_shot["pushed"] = minf(float(_shot.get("pushed", base_fov)), base_fov * lerpf(1.0, PUSH_TO, clampf(talked / PUSH_OVER, 0.0, 1.0)))

		if _speaker != null and is_instance_valid(_speaker) and live.has(_speaker):
			framing["look"] = (framing["look"] as Vector3) + (CineShot.head_of(_speaker) - (framing["subject"] as Vector3)) * 0.3

	framing["fov"] = float(_shot.get("pushed", base_fov))

	_operator.follow(framing)


## How long the man it is on has been out of sight.
func _watch(live: Array, dt: float) -> void:
	if live.is_empty() or _shot["kind"] in [&"insert", &"establishing", &"overhead"]:
		_hidden = 0.0
		return

	var space := _camera.get_world_3d().direct_space_state
	_hidden = 0.0 if CineVantage.sees(space, _camera.global_position, [live[0]]) else _hidden + dt


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

func _resolve() -> void:
	_resolve_in = RESOLVE_EVERY
	_subjects = _men_of(_intent.get("subjects", []))


func _men_of(subjects: Variant) -> Array:
	var men: Variant = subjects.call() if subjects is Callable else subjects
	return (men as Array).filter(_valid) if men is Array else []


func _valid(man: Variant) -> bool:
	return man != null and is_instance_valid(man) and (man as Node).is_inside_tree()


func _relevant(data: Dictionary) -> bool:
	for key in ["speaker", "man", "attacker", "victim"]:
		var who: Variant = data.get(key)

		if who != null and _subjects.has(who):
			return true

	for key in ["listeners", "men"]:
		for who in data.get(key, []):
			if _subjects.has(who):
				return true

	var where: Variant = data.get("where")

	if where is Vector3:
		for m in _subjects:
			if _valid(m) and CineShot.head_of(m).distance_to(where) <= NEAR:
				return true

	return false


func _aspect() -> float:
	var size := _camera.get_viewport().get_visible_rect().size if _camera != null and _camera.is_inside_tree() else Vector2(16, 9)
	return size.x / maxf(size.y, 1.0)


## A place high over `at`, to see it all from.
func _high_over(at: Vector3) -> Vector3:
	return at + Vector3(10.0, 12.0, 14.0)
