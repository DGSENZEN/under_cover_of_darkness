extends RefCounted
## Synchronous gameplay-sound event bus, separate from audible playback.
## Static listeners implement hear_sound(event: Dictionary). Sound range is 15 m at
## 50 dB and doubles every 7 dB; emission-point masking reduces effective loudness.
## Listeners decide audibility. Emission skips source/also_skip and prunes freed listeners.

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


## Registers listener once; it must implement hear_sound(event: Dictionary).
static func add_listener(listener: Object) -> void:
	if not _listeners.has(listener):
		_listeners.append(listener)


## Unregisters listener; absent entries are no-op.
static func remove_listener(listener: Object) -> void:
	_listeners.erase(listener)


## How far a sound of this loudness carries, in metres.
static func range_for(db: float) -> float:
	return REFERENCE_RANGE * pow(2.0, (db - REFERENCE_DB) / DB_PER_DOUBLING)


## Synchronously dispatches {position: Vector3, db: float, range: float,
## source: Object, kind: StringName}. db <= 0 emits nothing. range uses masking at
## position; source/also_skip are excluded. Listeners filter their own audibility.
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


## Dispatches the same sound schema plus message: Dictionary; db <= 0 is no-op.
## No distance/wall filtering occurs in the bus; listeners interpret the payload.
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
