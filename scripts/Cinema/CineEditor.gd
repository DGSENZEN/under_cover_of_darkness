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
##   drama    Kurosawa: short shots (2 to 7 s) cut on what happens, the
##            camera kept to one side of the line between the two men it is
##            on; over the shoulder onto whoever speaks, and the listener's
##            face as a hard line lands; three cuts straight in on a man
##            stirred; a face-off held still, side on, on a long lens, until
##            the first blow; the hunt from far off or alongside; slow motion
##            on the knife, a parry or a death (once in 8 s); a wipe into a
##            scene of other men; the letterbox in, and shake from blows.
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
const PUSH_TO := 0.8
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
## Drama: a shot's length (s); an axial cut-in's steps this far apart (s);
## a face-off: two men this near (m), facing each other within (deg), no
## blow nor line for (s), watched from this far off to the side (m); a blow
## this near the man a shot is on shakes it, by weight; slow motion (to, in,
## held, out: s), once in this long (s) at most; men running this fast
## (m/s), this many of them, is a hunt.
const SHOT := Vector2(3.0, 8.0)
## A drama cut due waits this long for a beat to land on (a line begun, a
## blow, a death); after two shots shorter than SHORT the next is planned
## LONG_AFTER.
const BEAT_WAIT := 1.5
const SHORT := 4.0
const LONG_AFTER := Vector2(6.0, 8.0)
const AXIAL_EVERY := 0.6
## An axial cut-in once for a man in a scene, and one in this long (s) at
## most (a whole garrison stirred is not a dozen cut-ins).
const AXIAL_REST := 10.0
## A listener's face after a hard line once in this long (s) at most (a
## fight is all shouting).
const REACTION_REST := 6.0
## Setups: remembered for these kinds of one man; kept while he stays this
## near (m) where it was made.
const SETUP_KINDS := [&"close", &"medium", &"reaction", &"portrait"]
const SETUP_WITHIN := 1.5
## A conversation: portraits from this line (by mode); a new speaker's
## portrait this long into his line (s); a listener's face after a hard line
## once in this long (s); back to the two of them every this many changes of
## speaker; a portrait re-aims only if his head moves this far (m).
const PORTRAIT_FROM := {&"observe": 3, &"drama": 2}
const SPEAKER_CUT := 0.3
const REACTION_EVERY := 8.0
const REESTABLISH_EVERY := 4
const STILL_WITHIN := 0.3
## A conversation is men standing: none going faster than this (m/s), and no
## blow for this long (s); lines traded in a fight or on the move are not.
const TALK_STILL := 1.0
const FIGHT_QUIET := 5.0
const FACE_OFF_NEAR := 4.0
const FACE_OFF_FACING := 45.0
const FACE_OFF_QUIET := 1.0
const FACE_OFF_OFF := 10.0
## Once blows have fallen, a pause this long (s) before it is a standoff
## again (not every breath between blows).
const FACE_OFF_LULL := 4.0
const SHAKE_NEAR := 6.0
const SHAKES := {&"light": 0.3, &"heavy": 0.5, &"death": 0.8}
const SLOW := [0.3, 0.2, 1.2, 0.5]
const SLOW_EVERY := 8.0
const RUNNING := 2.0
const HUNTERS := 3
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
## Drama: the event waiting for the next cut; the axial cut-in under way;
## when time was last slowed; the last blow; the two men of the last line or
## blow, and the line between the two a shot keeps to one side of; a
## listener's face due as a hard line ends; the men of the last scene; the
## coverage turned through.
var _pending: Dictionary = {}
var _axial: Dictionary = {}
var _axial_at := -INF
var _axial_men: Array = []
var _slowed_at := -INF
var _last_blow := -INF
## When the last beat fell: a line begun, a blow, a death; the last blow
## (in any mode).
var _beat_at := -INF
var _fought_at := -INF
var _exchange: Array = []
var _line_pair: Array = []
var _line_side := Vector3.ZERO
var _reaction: Dictionary = {}
var _reacted_at := -INF
var _scene_men: Array = []
var _cycle := 0
## Held (the camera someone else's); a scene's first shot waiting out the
## floor (when, with a wipe or not, asked when); a face-off nowhere could see
## tried again after this.
var _held := false
var _rng := RandomNumberGenerator.new()
## An act's scene to open through black, kept until a scene opens.
var _fade_due := false
## The scene's setups: by man and kind ("id:kind"), where the camera stood for
## him, through what lens, on what side, and where his head was.
var _setups := {}
## A conversation among the scene's men: {lines, speaker, listener, speakers,
## changes, portraits, end, portrait_of, next (the cut due), react (the
## listener's face due), reestablishing}.
var _talk := {}
var _scene_due := -INF
var _scene_wipe := false
var _scene_asked := -INF
var _face_off_retry := -INF


func _init() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	# Its own dice (seeded from the world's once): what the camera chooses
	# never changes what happens in the world.
	_rng.seed = randi()


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
	_element_in = _rng.randf_range(ELEMENT_AFTER.x, ELEMENT_AFTER.y)
	_quiet_since = _clock
	_last = -1.0


## Lets the camera go: its slow motion over, its screen cleared, its operator
## gone.
func release() -> void:
	CineEvents.remove_listener(self)
	TimeFx.cancel(&"cinema")

	if _operator != null and is_instance_valid(_operator):
		_operator.stand_down()

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


## Held: the camera is someone else's for now (flown, following a man); the
## scene is kept and events still heard, and it takes up again as it was.
## On hold: its slow motion over, any wipe gone, the camera's own lens back,
## and nothing it hears slows or shakes anything. Taken up again, it forgets
## what it heard meanwhile and takes a fresh shot of the scene as it is.
func hold(held: bool) -> void:
	if held == _held:
		return

	_held = held
	process_mode = Node.PROCESS_MODE_DISABLED if held else Node.PROCESS_MODE_PAUSABLE

	if _operator != null:
		_operator.process_mode = Node.PROCESS_MODE_INHERIT

	_last = -1.0

	if held:
		TimeFx.cancel(&"cinema")

		if _screen != null:
			_screen.clear()

		if _operator != null:
			_operator.stand_down()

		return

	_pending = {}
	_reaction = {}
	_axial = {}
	_talk = {}
	_scene_due = -INF

	if _operator != null:
		_operator.stand_up()

	if _camera != null:
		_next_shot(&"back")


## A new scene: `intent` {mode "observe"|"drama", subjects (men, or a Callable
## giving them), pin {kind, subjects, seconds}, letterbox}. Its first shot at
## once, or when the shot now has had FLOOR; held, when it is taken up again.
func scene(intent: Dictionary) -> void:
	_intent = intent.duplicate()
	_mode = StringName(intent.get("mode", &"observe"))

	if _operator != null:
		_operator.set_mode(_mode)

	_resolve()
	_talk_until = -INF
	_talk = {}
	_fade_due = _fade_due or StringName(intent.get("transition", &"")) == &"fade"
	_interest = {}
	_pending = {}
	_axial = {}
	_axial_men = []
	_reaction = {}
	_quiet_since = _clock
	# Into a scene of other men in drama: a wipe.
	var before := _scene_men.filter(_valid)
	var wipe: bool = _mode == &"drama" and not before.is_empty() and not _subjects.any(func(m): return before.has(m))
	_scene_men = _subjects.duplicate()

	if _screen != null:
		if intent.has("letterbox"):
			_screen.letterbox(bool(intent["letterbox"]))
		elif _mode == &"drama":
			_screen.letterbox(true)

	_pin_until = -INF
	_scene_asked = _clock

	if _camera == null or _held:
		return

	var age := _clock - float(_shot["at"]) if not _shot.is_empty() else INF

	if age < FLOOR:
		_scene_due = float(_shot["at"]) + FLOOR
		_scene_wipe = wipe
		return

	_open_scene(wipe)


## The scene's first shot: its pin (what is left of it), or the mode's own;
## through black if the intent's transition is "fade", else wiped (`wipe`)
## or cut to.
func _open_scene(wipe: bool) -> void:
	_scene_due = -INF
	_setups.clear()
	var pin: Dictionary = _intent.get("pin", {})
	var fade := _fade_due
	_fade_due = false
	var how: StringName = &"fade" if fade else (&"wipe" if wipe else &"cut")

	if not pin.is_empty():
		var men := _men_of(pin.get("subjects", _subjects))
		var seconds := maxf(float(pin.get("seconds", 5.0)) - (_clock - _scene_asked), FLOOR)
		var kind := StringName(pin.get("kind", &"medium"))
		var side := _side_of(_principals())
		_pin_until = _clock + seconds

		# The shot asked for, from whichever side sees; else as near to it as
		# sees him.
		if men.is_empty():
			_start(kind, men, &"pin", how, {"side": side}, seconds)
		else:
			var across := side if side != Vector3.ZERO else Vector3.UP.cross(CineShot.facing(men[0]))
			_pick([[kind, men, {"side": across}], [kind, men, {"side": -across}], [&"medium", men.slice(0, 1)], [&"close", men.slice(0, 1)]],
				&"pin", side, seconds, false, how)

		return

	if _mode == &"drama":
		_drama_next(&"scene", how)
	elif fade or not _carry_on():
		_fresh_take(&"scene", &"fade" if fade else &"dissolve")


## Observing, a new scene whose men the take already sees: the take goes on,
## its eye drifting to them (Tarkovsky's long take), rather than a cut.
func _carry_on() -> bool:
	if _shot.is_empty() or _shot.get("mode") != &"observe" or not (_shot["kind"] in [&"roving", &"observe"]) or _subjects.is_empty():
		return false

	if _clock - float(_shot["at"]) >= float(_shot.get("planned", TAKE.y)):
		return false

	var space := _camera.get_world_3d().direct_space_state

	if not CineVantage.sees(space, _camera.global_position, _subjects) or _camera.global_position.distance_to(CineShot.centre_of(_subjects)) > 30.0:
		return false

	_shot["subjects"] = _subjects.duplicate()
	_shot["offset"] = Vector3.ZERO
	return true


## A shot asked for now, in the scene as it is: `kind` of `men` (`context` as
## CineShot's: "toward" for a portrait), from its setup if it has one; else
## the nearest to it that stands clear and sees him.
func cut_to(kind: StringName, men: Array, context := {}) -> void:
	var live := men.filter(_valid)

	if live.is_empty() or _camera == null:
		return

	var options := [[kind, live, context]]

	if live.size() == 1 and kind != &"medium":
		options.append([&"medium", live, {}])

	_pick(options, &"asked", _side_of(_principals()), _rng.randf_range(SHOT.x, SHOT.y), false)


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

	if kind in [&"line", &"blow", &"death"]:
		_beat_at = _clock

	if kind == &"blow":
		_fought_at = _clock

	if kind == &"line":
		if _clock > _talk_until + TALK_GAP:
			_talk_since = _clock

		_talk_until = maxf(_talk_until, _clock + float(data.get("seconds", 1.0)))
		_speaker = data.get("speaker") as Node3D

		if not _held:
			_talk_line(data)

	var priority := int(PRIORITY.get(kind, 0))

	if _interest.is_empty() or float(_interest["at"]) < _clock or priority >= int(_interest["priority"]):
		_interest = {"kind": kind, "data": data, "at": _clock, "priority": priority}

	if _mode == &"drama" and not _held:
		_drama_event(kind, data, priority)


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

	# A scene asked for too soon after the last cut: its first shot now.
	if _scene_due > -INF and _clock >= _scene_due:
		_open_scene(_scene_wipe)
		return

	var age := _clock - float(_shot["at"])
	var framed: Array = _shot["subjects"]
	var live := framed.filter(_valid)
	var pinned := _clock < _pin_until

	# A man it was on is gone (freed): a new shot.
	if live.size() < framed.size() and age >= FLOOR and not pinned and _axial.is_empty():
		_next_shot(&"lost")
		return

	_follow(live)
	_watch(live, dt)

	if _hidden > HIDDEN_FOR and age >= FLOOR and not pinned and _axial.is_empty():
		_next_shot(&"hidden")
		return

	if pinned or _scene_due > -INF:
		return

	if _talk_step(age):
		return

	if _mode == &"drama":
		_drama_step(age)
	else:
		_observe_step(age)


## A new shot, as the mode takes one.
func _next_shot(cause: StringName) -> void:
	if _mode == &"drama":
		_drama_next(cause, &"cut")
	else:
		_fresh_take(cause)


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
## with nobody to watch. One that does not drift there comes in `how` (a
## dissolve, or a fade opening an act).
func _fresh_take(cause: StringName, how: StringName = &"dissolve") -> void:
	var men := _subjects.filter(_valid)

	if men.is_empty():
		_start(&"establishing", [], &"nobody" if cause != &"scene" else cause, how, {"from": _high_over(_place), "place": _place}, TAKE.y)
		return

	var length := _rng.randf_range(TAKE.x, TAKE.y)

	if _element_due():
		var element := _element()

		if element != null:
			_element_in = _rng.randf_range(ELEMENT_AFTER.x, ELEMENT_AFTER.y)
			_quiet_since = _clock
			_start(&"insert", [], &"element", how, {"target": element}, length)
			return

	var space := _camera.get_world_3d().direct_space_state
	var tries := [&"roving", &"observe"] if _rove_next else [&"observe", &"roving"]
	_rove_next = not _rove_next

	for kind in tries:
		var plan := _observe_plan(kind, men, space, length)

		if plan.is_empty() or _jump_cut(plan):
			continue

		# Through black it is there when the picture comes up (a drift waits
		# at its first point); else it drifts or glides there, or comes in `how`.
		_start(kind, men, cause, how if how == &"fade" or plan["how"] == &"cut" else plan["how"], plan["context"], length)
		return

	# Nothing fresh to be had: from wherever they can be seen, all the same.
	for lens in [&"long", &"medium"]:
		var from := CineVantage.best(get_tree(), men, lens, Vector3.ZERO, space)

		if from != Vector3.INF:
			_start(&"observe", men, cause, how, {"from": from}, length)
			return

	_start(&"overhead", men, cause, how, {}, length)


## Where a take of `kind` comes from: {how, context, position, size}; empty if
## there is nowhere to take it from.
func _observe_plan(kind: StringName, men: Array, space: PhysicsDirectSpaceState3D, length: float) -> Dictionary:
	var centre := CineShot.centre_of(men)

	if kind == &"observe":
		var from := CineVantage.best(get_tree(), men, &"long", Vector3.ZERO, space)

		if from == Vector3.INF:
			return {}

		var framing := CineShot.frame(&"observe", men, {"from": from, "aspect": _aspect()})
		var how := _how_to(from, men)
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
	var turn := 1.0 if _rng.randf() < 0.5 else -1.0

	for attempt in [0.0, PI * 0.5, -PI * 0.5, PI]:
		var points := PackedVector3Array()
		var clear := true

		for i in ROVE_POINTS:
			var angle := float(attempt) + turn * span * float(i) / float(ROVE_POINTS - 1)
			var point := Vector3(centre.x, 0.0, centre.z) + start_dir.rotated(Vector3.UP, angle) * ROVE_RADIUS + Vector3.UP * ROVE_HEIGHT

			if not CineVantage.clear(space, point) or not CineVantage.sees(space, point, men):
				clear = false
				break

			points.append(point)

		if not clear:
			continue

		var how := _how_to(points[0], men)
		var path := points

		if how == &"path":
			path = PackedVector3Array([_camera.global_position])
			path.append_array(points)
		else:
			how = &"path"

		return {"how": how, "context": {"path": path, "from": points[0]}, "position": points[0], "size": &"medium", "cut_first": path[0] == points[0]}

	return {}


## A move there if it is near, the way is clear, and `men` are seen from
## where it is now (a move that begins blind is a cut); else a cut.
func _how_to(position: Vector3, men: Array) -> StringName:
	var here := _camera.global_position
	var space := _camera.get_world_3d().direct_space_state

	if here.distance_to(position) <= MOVE_WITHIN and not _operator.blocked(here, position) and CineVantage.sees(space, here, men):
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
# Conversations
# ---------------------------------------------------------------------------

## The listener a line is spoken to, if the line is between two of the
## scene's men standing, and no fight on (a line of a conversation); else
## null.
func _talk_of(data: Dictionary) -> Variant:
	var speaker: Variant = data.get("speaker")

	if not _valid(speaker) or not _subjects.has(speaker) or not _talk_calm([speaker]):
		return null

	for listener in data.get("listeners", []):
		if _valid(listener) and _subjects.has(listener) and listener != speaker and _talk_calm([listener]):
			return listener

	return null


## Whether `men` can be in a conversation: standing (none faster than
## TALK_STILL), no blow in FIGHT_QUIET.
func _talk_calm(men: Array) -> bool:
	if _clock - _fought_at < FIGHT_QUIET:
		return false

	return men.filter(_valid).all(func(m): return _flat_speed(m) <= TALK_STILL)


## A line of a conversation: what the talk cuts to next. It builds (drama: a
## two-shot of them), goes to portraits of whoever speaks, 0.3 s into his line
## (the same man again keeps his), goes back to the two of them every
## REESTABLISH_EVERY changes of speaker or when a third man speaks, and after
## a hard line gives the listener's face as it ends.
func _talk_line(data: Dictionary) -> void:
	var listener: Variant = _talk_of(data)

	if listener == null:
		return

	var speaker: Node3D = data["speaker"]
	var seconds := float(data.get("seconds", 1.0))

	if _talk.is_empty() or _clock > float(_talk["end"]) + TALK_GAP:
		_talk = {"lines": 0, "speaker": null, "listener": null, "speakers": [], "changes": 0, "portraits": false, "end": _clock,
			"portrait_of": null, "next": {}, "react": {}, "reestablishing": false}

	var changed: bool = _talk["speaker"] != null and _talk["speaker"] != speaker
	var third: bool = (_talk["speakers"] as Array).size() >= 2 and not (_talk["speakers"] as Array).has(speaker)
	_talk["lines"] = int(_talk["lines"]) + 1
	_talk["changes"] = int(_talk["changes"]) + (1 if changed else 0)

	if not (_talk["speakers"] as Array).has(speaker):
		(_talk["speakers"] as Array).append(speaker)

	_talk["speaker"] = speaker
	_talk["listener"] = listener
	_talk["end"] = maxf(float(_talk["end"]), _clock + seconds)
	var at := _clock + SPEAKER_CUT
	var due_again: bool = changed and int(_talk["changes"]) % REESTABLISH_EVERY == 0

	if int(_talk["lines"]) == 1 and _mode == &"drama":
		_talk["next"] = {"kind": &"two", "at": at}
	elif (third or due_again) and _shot.get("cause") != &"reestablish":
		_talk["next"] = {"kind": &"reestablish", "at": at}
		_talk["reestablishing"] = true
	elif not bool(_talk["portraits"]) and int(_talk["lines"]) >= int(PORTRAIT_FROM.get(_mode, 3)):
		_talk["portraits"] = true
		_talk["next"] = {"kind": &"portrait", "man": speaker, "toward": listener, "at": at}
	elif bool(_talk["portraits"]) and (bool(_talk["reestablishing"]) or speaker != _talk["portrait_of"]):
		_talk["reestablishing"] = false
		_talk["next"] = {"kind": &"portrait", "man": speaker, "toward": listener, "at": at}

	var grieving: bool = float(speaker.get("grief") if speaker.get("grief") != null else 0.0) > 0.5

	if (data.get("delivery") == &"shout" or grieving) and _clock - _reacted_at >= REACTION_EVERY:
		_talk["react"] = {"man": listener, "toward": speaker, "at": _clock + seconds}


## The talk's cuts, when they are due (after FLOOR). True while the talk has
## the camera (portraits, or the drama build-up); a death, the knife or a man
## stirred still cut through it.
func _talk_step(age: float) -> bool:
	if _talk.is_empty():
		return false

	# Over, or no longer men standing talking (a blow, or one walks off).
	if _clock > float(_talk["end"]) + TALK_GAP or not _talk_calm([_talk["speaker"], _talk["listener"]]):
		_talk = {}
		return false

	if _mode == &"drama" and not _pending.is_empty() and float(_pending["at"]) >= float(_shot["at"]) and _pending["kind"] in [&"death", &"knife", &"alert"]:
		return false

	# The three cuts in on a man stirred run their course.
	if not _axial.is_empty():
		return false

	var react: Dictionary = _talk["react"]

	if not react.is_empty() and _clock >= float(react["at"]) and age >= FLOOR:
		_talk["react"] = {}
		_reacted_at = _clock
		_talk_cut({"kind": &"portrait", "man": react["man"], "toward": react["toward"]}, &"reaction")
		return true

	var next: Dictionary = _talk["next"]

	if not next.is_empty() and _clock >= float(next["at"]) and age >= FLOOR:
		_talk["next"] = {}
		_talk_cut(next, next["kind"])
		return true

	return bool(_talk["portraits"]) or _mode == &"drama"


## One of the talk's cuts: the two of them, the group, or a man's portrait
## (his setup, facing the man he speaks to).
func _talk_cut(next: Dictionary, cause: StringName) -> void:
	var speaker: Variant = _talk["speaker"]
	var listener: Variant = _talk["listener"]
	var pair := [speaker, listener].filter(_valid)

	match next["kind"]:
		&"two":
			# Already on the two of them: nothing to cut.
			if _shot.get("kind") == &"two" and pair.all(func(m): return (_shot["subjects"] as Array).has(m)):
				return

			if pair.size() == 2:
				_pick([[&"two", pair]], cause, _side_of(pair), SHOT.y, false, &"cut", false)
		&"reestablish":
			var men: Array = (_talk["speakers"] as Array).duplicate()

			if _valid(listener) and not men.has(listener):
				men.append(listener)

			men = men.filter(_valid)
			var options: Array = []

			if men.size() >= 3:
				var space := _camera.get_world_3d().direct_space_state
				var from := CineVantage.best(get_tree(), men, &"medium", Vector3.ZERO, space)

				if from != Vector3.INF:
					options.append([&"group", men, {"from": from}])

			if pair.size() == 2:
				options.append([&"two", pair])

			if not options.is_empty():
				_pick(options, cause, _side_of(pair), SHOT.y, false, &"cut", false)
		&"portrait":
			var man: Variant = next["man"]
			var toward: Variant = next["toward"]

			if not _valid(man):
				return

			_talk["portrait_of"] = man

			# His portrait already on screen: he keeps it.
			if _shot.get("kind") == &"portrait" and _shot["subjects"] == [man]:
				return

			var context := {"toward": CineShot.head_of(toward)} if _valid(toward) else {}
			var side := _side_of([man, toward]) if _valid(toward) else Vector3.ZERO
			# His portrait from anywhere round him before a close of him.
			if not _pick([[&"portrait", [man], context]], cause, side, SHOT.y, false, &"cut", false, true):
				_pick([[&"close", [man]], [&"medium", [man]]], cause, side, SHOT.y, false, &"cut", false)


# ---------------------------------------------------------------------------
# Drama
# ---------------------------------------------------------------------------

## What an event does in drama at once (shake, slow motion), and what it
## leaves for the next cut.
func _drama_event(kind: StringName, data: Dictionary, priority: int) -> void:
	var where: Variant = data.get("where")

	match kind:
		&"blow":
			_last_blow = _clock
			_exchange_of(data.get("attacker"), data.get("victim"))
			_shake_for(where, float(SHAKES.get(data.get("weight", &"light"), 0.3)))

			if data.get("outcome") == &"parried":
				_slow()
		&"death":
			_shake_for(where, float(SHAKES[&"death"]))
			_slow()
		&"knife":
			_slow()
		&"line":
			var listeners: Array = data.get("listeners", [])
			var listener: Variant = listeners[0] if not listeners.is_empty() else null
			_exchange_of(data.get("speaker"), listener)

			# A line of a conversation is the talk's to cut (_talk_step).
			if _talk_of(data) != null:
				return

			var speaker: Variant = data.get("speaker")
			var grieving: bool = speaker != null and is_instance_valid(speaker) and float(speaker.get("grief") if speaker.get("grief") != null else 0.0) > 0.5

			if listener != null and (data.get("delivery") == &"shout" or grieving):
				_reaction = {"man": listener, "at": _clock + float(data.get("seconds", 1.0))}
		&"alert":
			# Only a man stirred to search or fight is cut in on.
			if int(data.get("to", 0)) < 3:
				return

	if _pending.is_empty() or priority >= int(_pending["priority"]):
		_pending = {"kind": kind, "data": data, "at": _clock, "priority": priority}


func _drama_step(age: float) -> void:
	# Three cuts straight in: the next, 0.6 s after the last.
	if not _axial.is_empty():
		if _clock >= float(_axial["next_at"]):
			var step := int(_axial["step"]) + 1
			var man: Variant = _axial["man"]

			if step > 2 or not _valid(man):
				_axial = {}
			else:
				_axial["step"] = step
				_axial["next_at"] = _clock + AXIAL_EVERY
				_start(&"axial", [man], &"alert", &"cut", {"from": _axial["from"], "step": step}, AXIAL_EVERY)

				if step == 2:
					_axial = {}

		return

	var face := _face_off()

	# A face-off held still until the first blow (or until it is over).
	if _shot.get("cause") == &"face_off" and not face.is_empty() and (_pending.is_empty() or float(_pending["at"]) < float(_shot["at"])):
		return

	if age < FLOOR:
		return

	# The shot's time up, the cut waits for a beat to land on, up to
	# BEAT_WAIT; then it cuts all the same.
	var planned := float(_shot.get("planned", SHOT.y))
	var on_beat := age >= planned and _beat_at >= float(_shot["at"]) + planned
	var due := on_beat or age >= planned + BEAT_WAIT

	# A death, the knife, a man stirred or seeing you: cut to at once. A line
	# or a blow is action to cut on when the cut is due.
	if not _pending.is_empty() and float(_pending["at"]) >= float(_shot["at"]):
		var breaks_face_off: bool = _shot.get("cause") == &"face_off" and _pending["kind"] == &"blow"

		if _pending["kind"] in [&"death", &"knife", &"alert"] or breaks_face_off or due:
			_on_pending()
			return

	if not _reaction.is_empty() and _clock >= float(_reaction["at"]) and age >= SHOT.x:
		var listener: Variant = _reaction["man"]
		_reaction = {}

		if _valid(listener) and _subjects.has(listener) and _clock - _reacted_at >= REACTION_REST:
			_reacted_at = _clock
			_start(&"reaction", [listener], &"reaction", &"cut", {"side": _side_of(_principals())}, _rng.randf_range(SHOT.x, SHOT.y))
			return

	if not face.is_empty() and _shot.get("cause") != &"face_off" and _clock >= _face_off_retry:
		if _face_off_shot(face):
			return

		# Nowhere sees it: not again for a while, and the shots go on.
		_face_off_retry = _clock + 2.0

	if due:
		_drama_next(&"rhythm", &"cut")


## The event waiting, cut to.
func _on_pending() -> void:
	var kind: StringName = _pending["kind"]
	var data: Dictionary = _pending["data"]
	_pending = {}
	var length := _rng.randf_range(SHOT.x, SHOT.y)
	var side := _side_of(_principals())

	match kind:
		&"death":
			var man: Variant = data.get("man")
			var killer: Variant = data.get("killer")

			if _valid(man):
				_pick([[&"close", [man]], [&"medium", [man]]], &"death", side, length, false)
			elif _valid(killer):
				_pick([[&"medium", [killer]], [&"close", [killer]]], &"death", side, length, false)
			else:
				_drama_next(&"death", &"cut")
		&"knife":
			var pair := [data.get("attacker"), data.get("victim")].filter(_valid)
			_pick([[&"two", pair], [&"medium", pair.slice(0, 1)]] if pair.size() == 2 else [[&"medium", pair]], &"knife", side, length, false)
		&"blow", &"spotted":
			var who: Variant = data.get("attacker") if kind == &"blow" else data.get("man")

			if _valid(who):
				_pick([[&"medium", [who]], [&"close", [who]]], kind, side, length, false)
			else:
				_drama_next(kind, &"cut")
		&"alert":
			var man: Variant = data.get("man")
			var from := _camera.global_position

			if _valid(man) and not _axial_men.has(man) and _clock - _axial_at >= AXIAL_REST and _axial_clear(man, from):
				_axial_men.append(man)
				_axial_at = _clock
				_axial = {"man": man, "step": 0, "next_at": _clock + AXIAL_EVERY, "from": from}
				_start(&"axial", [man], &"alert", &"cut", {"from": from, "step": 0}, AXIAL_EVERY)
			elif _valid(man):
				_pick([[&"medium", [man]], [&"close", [man]]], &"alert", side, length, false)
			else:
				_drama_next(kind, &"cut")
		&"line":
			var speaker: Variant = data.get("speaker")
			var listeners: Array = (data.get("listeners", []) as Array).filter(_valid)

			if _valid(speaker) and not listeners.is_empty():
				_pick([[&"over_shoulder", [speaker, listeners[0]]], [&"close", [speaker]], [&"medium", [speaker]]], &"line", side, length, false)
			elif _valid(speaker):
				_pick([[&"close", [speaker]], [&"medium", [speaker]]], &"line", side, length, false)
			else:
				_drama_next(kind, &"cut")
		_:
			_drama_next(kind, &"cut")


## Whether each of the three steps in on `man` from `from` sees him.
func _axial_clear(man: Node3D, from: Vector3) -> bool:
	var space := _camera.get_world_3d().direct_space_state

	for step in 3:
		var framing := CineShot.frame(&"axial", [man], {"from": from, "step": step, "aspect": _aspect()})

		if not CineVantage.clear(space, framing["position"]) or not CineVantage.sees(space, framing["position"], [man]):
			return false

	return true


## The next piece of coverage: the pair from the side of their line (two,
## over each shoulder, each man close and waist up), or one man; the hunt
## from far off and alongside; the size changed from the shot before.
func _drama_next(cause: StringName, how: StringName) -> void:
	var men := _subjects.filter(_valid)

	if men.is_empty():
		_start(&"establishing", [], &"nobody", how, {"from": _high_over(_place), "place": _place}, SHOT.y)
		return

	var length := _rng.randf_range(SHOT.x, SHOT.y)
	var runners := men.filter(func(m): return _flat_speed(m) > RUNNING)

	if runners.size() >= HUNTERS:
		runners.sort_custom(func(x, y): return _flat_speed(x) > _flat_speed(y))
		var space := _camera.get_world_3d().direct_space_state
		var from := CineVantage.best(get_tree(), runners, &"long", Vector3.ZERO, space)
		var hunt: Array = [[&"track", [runners[0]]]]

		if from != Vector3.INF:
			hunt.push_front([&"group", runners, {"from": from}])

		_pick(hunt, &"hunt", Vector3.ZERO, length, true, how)
		return

	var pair := _principals()
	var side := _side_of(pair)
	var options: Array

	if pair.size() == 2:
		options = [[&"two", pair], [&"over_shoulder", [pair[0], pair[1]]], [&"close", [pair[0]]], [&"medium", [pair[1]]],
			[&"over_shoulder", [pair[1], pair[0]]], [&"close", [pair[1]]], [&"medium", [pair[0]]]]
	else:
		options = [[&"medium", [men[0]]], [&"close", [men[0]]]]

	var turned: Array = []

	for i in options.size():
		turned.append(options[(_cycle + i) % options.size()])

	_cycle += 1
	_pick(turned, cause, side, length, true, how)


## `man`'s setup for `kind` in this scene, if he is within SETUP_WITHIN of
## where it was made and it stands clear and sees him; else nothing.
func _setup(man: Node3D, kind: StringName, space: PhysicsDirectSpaceState3D) -> Dictionary:
	var kept: Dictionary = _setups.get("%d:%s" % [man.get_instance_id(), kind], {})

	if kept.is_empty():
		return {}

	if CineShot.head_of(man).distance_to(kept["head"]) > SETUP_WITHIN or not CineVantage.clear(space, kept["position"]) or not CineVantage.sees(space, kept["position"], [man]):
		return {}

	return kept


## The first of `options` ([kind, men, context?]) that sees its man and is
## no jump cut (and, if `new_size`, of another size than the shot now),
## taken; else the first that sees him; else from wherever he can be seen.
## `strict`: only one of `options` (false if none can be taken).
func _pick(options: Array, cause: StringName, side: Vector3, length: float, new_size: bool, how: StringName = &"cut", check_jump := true, strict := false) -> bool:
	var chosen: Array = []
	var space := _camera.get_world_3d().direct_space_state

	# Every option as it comes first; only then a single man taken from
	# further round him (on the same side of the line), for when those are
	# walled in: a new size before a new angle on the same size.
	for turn in [0.0, 30.0, -30.0, 60.0, -60.0, 120.0, -120.0]:
		for option in options:
			var men: Array = (option[1] as Array).filter(_valid)

			if men.is_empty() or (turn != 0.0 and not (option[0] in [&"close", &"medium", &"reaction", &"portrait"] and men.size() == 1)):
				continue

			var context: Dictionary = (option[2] as Dictionary).duplicate() if option.size() > 2 else {}

			if not context.has("side"):
				context["side"] = side

			context["aspect"] = _aspect()
			context["turn"] = turn
			var one: bool = men.size() == 1 and option[0] in SETUP_KINDS

			# A man's setup in this scene, if he is still near where it was made
			# and it still sees him: the same place and lens again.
			if one:
				var kept: Dictionary = _setup(men[0], option[0], space)

				if not kept.is_empty():
					if turn != 0.0:
						continue

					context["from"] = kept["position"]
			var framing := CineShot.frame(option[0], men, context)
			var at: Vector3 = framing["position"]
			var line_side: Vector3 = context["side"]

			if turn != 0.0 and line_side != Vector3.ZERO and (at - CineShot.head_of(men[0])).dot(line_side) < 0.0:
				continue

			if not CineVantage.clear(space, at) or not CineVantage.sees(space, at, [men[0]]):
				continue

			if not CineVantage.open(space, at, framing["subject"], float(framing["fov"]), _aspect(), _rids_of(men)):
				continue

			if chosen.is_empty():
				chosen = [option[0], men, context]

			if new_size and not _shot.is_empty() and framing["size"] == _shot.get("size"):
				continue

			if check_jump and _jump_cut({"how": &"cut", "size": framing["size"], "position": at}):
				continue

			if one and not context.has("from"):
				_setups["%d:%s" % [men[0].get_instance_id(), option[0]]] = {"position": at, "fov": framing["fov"], "side": context["side"], "head": CineShot.head_of(men[0])}

			_start(option[0], men, cause, how, context, length)
			return true

	if not chosen.is_empty():
		_start(chosen[0], chosen[1], cause, how, chosen[2], length)
		return true

	if strict:
		return false

	# Nothing near sees him: from wherever he can be seen, on a long lens.
	var men: Array = (options[0][1] as Array).filter(_valid) if not options.is_empty() else []
	var from := CineVantage.best(get_tree(), men, &"long", side, space) if not men.is_empty() else Vector3.INF

	if from != Vector3.INF:
		_start(&"observe", men, cause, how, {"from": from, "side": side}, length)
	else:
		_start(&"establishing", [], cause, how, {"from": _high_over(_place), "place": _place}, length)

	return true


## A face-off: from well off to the side of their line, on a long lens, still.
## False if nowhere sees it.
func _face_off_shot(pair: Array) -> bool:
	var side := _side_of(pair)
	var centre := CineShot.centre_of(pair)
	var from := centre + side * FACE_OFF_OFF
	var space := _camera.get_world_3d().direct_space_state

	if not CineVantage.clear(space, from) or not CineVantage.sees(space, from, pair) or not CineVantage.open(space, from, centre, 28.0, _aspect(), _rids_of(pair)):
		from = CineVantage.best(get_tree(), pair, &"long", side, space)

	if from == Vector3.INF:
		return false

	_start(&"observe", pair, &"face_off", &"cut", {"from": from, "side": side}, SHOT.y)
	return true


## Two of the men squared up: near, facing each other, no blow or line
## lately; else nothing.
func _face_off() -> Array:
	var quiet := FACE_OFF_QUIET if _last_blow == -INF else FACE_OFF_LULL

	if _clock - _last_blow < quiet or _clock < _talk_until + FACE_OFF_QUIET:
		return []

	var men := _subjects.filter(_valid)

	for i in men.size():
		for j in range(i + 1, men.size()):
			var a: Node3D = men[i]
			var b: Node3D = men[j]
			var between := b.global_position - a.global_position
			between.y = 0.0

			if between.length() > FACE_OFF_NEAR or between.length() < 0.1:
				continue

			var limit := cos(deg_to_rad(FACE_OFF_FACING))

			if CineShot.facing(a).dot(between.normalized()) < limit or CineShot.facing(b).dot(-between.normalized()) < limit:
				continue

			# Men with minds of their own face off only if they mean each
			# other harm (two of the hunt conferring do not).
			if (&"_target" in a or &"_target" in b) and a.get("_target") != b and b.get("_target") != a:
				continue

			return [a, b]

	return []


## The two men of the latest line or blow if they are both in the scene;
## else its first two.
func _principals() -> Array:
	if _exchange.size() == 2 and _exchange.all(func(m): return _valid(m) and _subjects.has(m)):
		return _exchange

	var men := _subjects.filter(_valid)
	return men.slice(0, 2) if men.size() >= 2 else []


func _exchange_of(a: Variant, b: Variant) -> void:
	if _valid(a) and _valid(b) and a != b:
		_exchange = [a, b]


## The side of the line between the pair the camera keeps to: the side it is
## on when the pair is first cut between.
func _side_of(pair: Array) -> Vector3:
	if pair.size() < 2:
		return Vector3.ZERO

	var line := CineShot.head_of(pair[1]) - CineShot.head_of(pair[0])
	line.y = 0.0

	if line.length() < 0.05:
		return Vector3.ZERO

	var across := Vector3.UP.cross(line.normalized())
	var same: bool = _line_pair.size() == 2 and pair.has(_line_pair[0]) and pair.has(_line_pair[1])

	if not same:
		_line_pair = pair.duplicate()
		var centre := CineShot.centre_of(pair)
		_line_side = across if (_camera.global_position - centre).dot(across) >= 0.0 else -across

	return across if across.dot(_line_side) >= 0.0 else -across


func _shake_for(where: Variant, amount: float) -> void:
	if not (where is Vector3) or _operator == null:
		return

	var framed: Array = (_shot.get("subjects", []) as Array).filter(_valid)
	var at: Vector3 = CineShot.head_of(framed[0]) if not framed.is_empty() else _place

	if at.distance_to(where) <= SHAKE_NEAR:
		_operator.shake(amount)


## Time slowed on the moment, if it has not been lately.
func _slow() -> void:
	if _clock - _slowed_at < SLOW_EVERY:
		return

	_slowed_at = _clock
	TimeFx.ramp(get_tree(), &"cinema", SLOW[0], SLOW[1], SLOW[2], SLOW[3])


func _flat_speed(man: Node3D) -> float:
	var going: Variant = man.get("velocity")
	return Vector2((going as Vector3).x, (going as Vector3).z).length() if going is Vector3 else 0.0


# ---------------------------------------------------------------------------
# Taking a shot
# ---------------------------------------------------------------------------

## Begins the shot `kind` of `men`, taken `how` ("cut", "glide", "path",
## "wipe"), planned to run `planned` s; tells whoever listens.
func _start(kind: StringName, men: Array, cause: StringName, how: StringName, context: Dictionary, planned: float) -> void:
	# In drama, after two short shots a long one (the three cuts in and a pin
	# keep their own time).
	if _mode == &"drama" and kind != &"axial" and cause != &"pin" and _history.size() >= 2:
		var last := _clock - float(_history[-1]["at"])
		var before := float(_history[-1]["at"]) - float(_history[-2]["at"])

		if last < SHORT and before < SHORT:
			planned = maxf(planned, _rng.randf_range(LONG_AFTER.x, LONG_AFTER.y))

	var ctx := context.duplicate()
	ctx["aspect"] = _aspect()
	var framing := CineShot.frame(kind, men, ctx)
	# How the take's first frame comes (a drift may have to be somewhere
	# else first).
	var enter := how

	if how == &"path":
		var path: PackedVector3Array = ctx.get("path", PackedVector3Array())

		if path.size() < 2:
			how = &"cut"
			enter = how
		else:
			framing["position"] = path[path.size() - 1]
			framing["path"] = path

			# The first point is somewhere else altogether: be there first
			# (watching, dissolved to, as any new take).
			if _camera.global_position.distance_to(path[0]) > 0.5:
				var first := framing.duplicate()
				first["position"] = path[0]
				enter = &"dissolve" if _mode == &"observe" else &"cut"
				_operator.show(first, enter)

	_operator.show(framing, how)
	_shot = {"kind": kind, "size": framing["size"], "subjects": men.duplicate(), "cause": cause, "how": how, "enter": enter, "at": _clock, "mode": _mode,
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

	# A portrait holds still: it turns to him only once his head has moved.
	if kind == &"portrait":
		var head := CineShot.head_of(live[0])

		if not _shot.has("still_head"):
			_shot["still_head"] = head
			return

		if head.distance_to(_shot["still_head"]) < STILL_WITHIN:
			return

		_shot["still_head"] = head

	var framing := CineShot.frame(kind, live, ctx)

	# A track runs alongside its man (where the way is clear); every other
	# shot stays where it was put and turns to keep him.
	if kind == &"track":
		if _operator.blocked(_camera.global_position, framing["position"]):
			return
	elif not (kind in [&"roving", &"observe", &"group"]):
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


func _rids_of(men: Array) -> Array[RID]:
	var rids: Array[RID] = []

	for m in men:
		if m is CollisionObject3D and is_instance_valid(m):
			rids.append((m as CollisionObject3D).get_rid())

	return rids


func _aspect() -> float:
	var size := _camera.get_viewport().get_visible_rect().size if _camera != null and _camera.is_inside_tree() else Vector2(16, 9)
	return size.x / maxf(size.y, 1.0)


## A place high over `at`, to see it all from.
func _high_over(at: Vector3) -> Vector3:
	return at + Vector3(10.0, 12.0, 14.0)
