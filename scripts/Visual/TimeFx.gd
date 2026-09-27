extends RefCounted
## The one owner of Engine.time_scale. Hit-stop (a blow freezes the world for
## a few hundredths of a second) and slow motion (the finisher) both ask for
## time to slow; the slowest request running wins, and when every request is
## over, time runs at 1 again. Nothing else should write Engine.time_scale.
##
## Durations are real seconds: the timers ignore the time scale they set.

## How much of a slow motion the sound follows (0 none, 1 all of it).
const AUDIO_SLOWDOWN := 0.6

static var _requests := {}
static var _token := 0
## The speed everything runs at when nothing slows it (the NPC showcase's
## slow motion); requests slow it further.
static var base := 1.0


## Time at `scale` when nothing else slows it (1 is normal speed).
static func set_base(scale: float) -> void:
	base = clampf(scale, 0.01, 1.0)
	_apply()


## Slow time to `scale` for `real_seconds`. A request with the same `id`
## replaces the older one, so repeated hits extend a hit-stop, never stack it.
static func request(tree: SceneTree, id: StringName, scale: float, real_seconds: float) -> void:
	if tree == null or real_seconds <= 0.0:
		return

	_token += 1
	var token := _token
	_requests[id] = { "scale": clampf(scale, 0.01, 1.0), "token": token }
	_apply()

	tree.create_timer(real_seconds, true, false, true).timeout.connect(
		func() -> void:
			var entry: Dictionary = _requests.get(id, {})

			if not entry.is_empty() and int(entry["token"]) == token:
				_requests.erase(id)
				_apply()
	)


## Slow time to `scale` over `ease_in`, hold it `hold`, and ease it back to
## 1 over `ease_out` (real seconds each); then the request is gone. The same
## `id` begins again; clear() ends it. Paused or slowed, it keeps real time.
static func ramp(tree: SceneTree, id: StringName, scale: float, ease_in: float, hold: float, ease_out: float) -> void:
	if tree == null:
		return

	_token += 1
	var token := _token
	var low := clampf(scale, 0.01, 1.0)
	_requests[id] = { "scale": 1.0, "token": token }
	var set_scale := func(value: float) -> void:
		var entry: Dictionary = _requests.get(id, {})

		if not entry.is_empty() and int(entry["token"]) == token:
			entry["scale"] = value
			_apply()

	var tween := tree.create_tween()
	tween.set_ignore_time_scale(true)
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_method(set_scale, 1.0, low, maxf(ease_in, 0.001)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_interval(maxf(hold, 0.0))
	tween.tween_method(set_scale, low, 1.0, maxf(ease_out, 0.001)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_callback(func() -> void:
		var entry: Dictionary = _requests.get(id, {})

		if not entry.is_empty() and int(entry["token"]) == token:
			_requests.erase(id)
			_apply())


## A short freeze on impact. Heavier blows freeze longer.
static func hitstop(tree: SceneTree, real_seconds: float, scale := 0.05) -> void:
	request(tree, &"hitstop", scale, real_seconds)


## Real seconds, whatever the time scale: counted in physics ticks, which the
## engine runs at a steady real-time rate and only hands a scaled delta to.
## Dividing a frame's delta by Engine.time_scale is wrong on the frame the
## scale changes (a hit-stop), when it reads 25 times too long.
static func real_time() -> float:
	var hz := float(maxi(Engine.physics_ticks_per_second, 1))
	return (float(Engine.get_physics_frames()) + Engine.get_physics_interpolation_fraction()) / hz


## Real seconds since `last` (a value real_time() gave before), capped, so a
## pause or a hitch does not read as a long time.
static func real_since(last: float) -> float:
	return clampf(real_time() - last, 0.0, 0.1)


static func is_active(id: StringName) -> bool:
	return _requests.has(id)


## Everything back to normal speed at once (death, level change, tests).
static func clear() -> void:
	_requests.clear()
	_apply()


static func _apply() -> void:
	var scale := 1.0

	for entry in _requests.values():
		scale = minf(scale, float(entry["scale"]))

	Engine.time_scale = scale * base

	# Slow motion is heard too: the whole mix slows and drops, part of the
	# way. (A hit-stop is too short to hear that way: it would only warble.)
	var heard := 1.0

	for id in _requests.keys():
		if id != &"hitstop":
			heard = minf(heard, lerpf(1.0, float(_requests[id]["scale"]), AUDIO_SLOWDOWN))

	AudioServer.playback_speed_scale = maxf(heard, 0.45)
