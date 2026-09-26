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

static var _listeners: Array = []


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

	var event := {
		"position": position,
		"db": db,
		"range": range_for(db),
		"source": source,
		"kind": kind,
	}

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
