extends RefCounted
## Static cinematic event listeners, without an autoload. Each listener implements cine_event(kind, data).
## Events include world where and relevant actors; schemas are in docs/systems/cinematics.md.
## Emit dispatches synchronously and removes freed listeners; callers own registration lifetime.

static var _listeners: Array = []


## Registers listener once; it must implement cine_event(StringName, Dictionary).
## Registration stores the Object in a static Array until removal or invalid-instance pruning.
static func add_listener(listener: Object) -> void:
	if not _listeners.has(listener):
		_listeners.append(listener)


static func remove_listener(listener: Object) -> void:
	_listeners.erase(listener)


## Synchronously dispatches kind/data to valid listeners implementing cine_event and prunes freed instances.
## The Dictionary is passed by reference; listeners should not mutate another listener's input.
static func emit(kind: StringName, data: Dictionary) -> void:
	for listener in _listeners.duplicate():
		if not is_instance_valid(listener):
			_listeners.erase(listener)
			continue

		listener.cine_event(kind, data)


## Drops every static listener; used for scene/test cleanup.
static func clear() -> void:
	_listeners.clear()
