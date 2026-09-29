extends RefCounted
## Gameplay sound, separate from audio. A footstep, a thrown crate landing, a
## door rattling: each is an EVENT with a position and a loudness, and anyone
## listening decides what to make of it. What the player hears through the
## speakers is a different system entirely.
##
## No autoload needed: the listener list is static, so every script that
## preloads this file shares it.
##
## Loudness follows The Dark Mod's rule: a 50 dB sound carries 15 m, and every
## 7 dB doubles or halves that.

const REFERENCE_DB := 50.0
const REFERENCE_RANGE := 15.0
const DB_PER_DOUBLING := 7.0

## Draw every event for a moment. Set from anywhere: SoundBus.debug = true
static var debug := false
## The noise floor (dB): rain and wind drowning sounds out (Night). Every
## sound carries as if it were this much quieter.
static var masking_db := 0.0

static var _listeners: Array = []
## Noise zones (a level's `noise_zone` markers): inside each box, sound is
## masked by its own noise floor (a blowhole's roar, a fountain), where it
## is louder than the night's. id -> [box, dB].
static var _zones := {}
static var _next_zone := 1


## A box of noise: what is made inside it carries as if it were `db`
## quieter (or the night's masking, whichever is more). Returns its id.
static func add_zone(box: AABB, db: float) -> int:
	var id := _next_zone
	_next_zone += 1
	_zones[id] = [box, db]
	return id


## The zone's noise changes (a roar rising and falling).
static func set_zone_db(id: int, db: float) -> void:
	if _zones.has(id):
		_zones[id][1] = db


static func remove_zone(id: int) -> void:
	_zones.erase(id)


static func clear_zones() -> void:
	_zones.clear()


## How much a sound made at `position` is masked (dB): the night's noise
## floor, or the loudest noise zone round it.
static func masking_at(position: Vector3) -> float:
	var db := masking_db

	for id in _zones:
		if (_zones[id][0] as AABB).has_point(position):
			db = maxf(db, float(_zones[id][1]))

	return db


static func add_listener(listener: Object) -> void:
	if not _listeners.has(listener):
		_listeners.append(listener)


static func remove_listener(listener: Object) -> void:
	_listeners.erase(listener)


## How far a sound of this loudness carries, in metres.
static func range_for(db: float) -> float:
	return REFERENCE_RANGE * pow(2.0, (db - REFERENCE_DB) / DB_PER_DOUBLING)


## Listeners need `hear_sound(event: Dictionary)`. The event holds:
## position: Vector3, db: float, range: float, source: Object, kind: StringName
##
## The source never hears its own sound. `also_skip` is a second listener who
## should not: a guard does not "hear" the clang of the club on his own helmet
## as a noise somewhere to go and investigate.
static func emit_sound(position: Vector3, db: float, source: Object, kind: StringName, also_skip: Object = null) -> void:
	if db <= 0.0:
		return

	_emit({
		"position": position,
		"db": db,
		"range": range_for(db - masking_at(position)),
		"source": source,
		"kind": kind,
	}, also_skip)


## A sound that says something: a guard calling out where you are, a bell
## rung. It carries exactly as emit_sound does (so walls, distance and a
## listener's hearing decide who gets it), and each listener finds what was
## said in the event under "message" (Comms.gd).
static func emit_message(position: Vector3, db: float, source: Object, kind: StringName, message: Dictionary) -> void:
	if db <= 0.0:
		return

	_emit({
		"position": position,
		"db": db,
		"range": range_for(db - masking_at(position)),
		"source": source,
		"kind": kind,
		"message": message,
	}, null)


static func _emit(event: Dictionary, also_skip: Object) -> void:
	var position: Vector3 = event["position"]
	var kind: StringName = event["kind"]
	var db: float = event["db"]
	var source: Object = event["source"]

	if debug:
		DebugDraw3D.draw_sphere(position, 0.25, Color(0.4, 0.8, 1.0), 0.5)
		DebugDraw3D.draw_text(position + Vector3.UP * 0.5, "%s %d dB  %.0f m" % [kind, int(db), event["range"]], 32, Color(0.4, 0.8, 1.0), 0.8)

	for listener in _listeners.duplicate():
		if not is_instance_valid(listener):
			_listeners.erase(listener)
			continue

		if listener == source or listener == also_skip:
			continue

		listener.hear_sound(event)
