extends RefCounted
## What happens that a camera might want to see, told to whoever listens
## (CineEditor). No autoload: the listener list is static, as SoundBus's.
##
## Every event carries `where` (Vector3) and the men it concerns:
##   line       {speaker, listeners, seconds, delivery, text}: a line begun
##              (Guard.speak, a bark); delivery "whisper", "murmur", "shout"
##              or "" as he would.
##   alert      {man, from, to}: his state changed (Guard.Alert).
##   spotted    {man, target}: he goes to fight seeing whom he fights.
##   blow       {attacker, victim, weight, outcome}: weight "light" or
##              "heavy"; outcome "landed", "blocked", "parried" or "killed".
##   death      {man, killer}: dead, or knocked out.
##   knife      {attacker, victim}: a man stabbed from behind.
##   gathering  {kind, men, state}: a gathering "started" or "ended".
## A listener has `cine_event(kind: StringName, data: Dictionary)`.

static var _listeners: Array = []


static func add_listener(listener: Object) -> void:
	if not _listeners.has(listener):
		_listeners.append(listener)


static func remove_listener(listener: Object) -> void:
	_listeners.erase(listener)


## Tells every listener still there (one freed without leaving is dropped).
static func emit(kind: StringName, data: Dictionary) -> void:
	for listener in _listeners.duplicate():
		if not is_instance_valid(listener):
			_listeners.erase(listener)
			continue

		listener.cine_event(kind, data)


static func clear() -> void:
	_listeners.clear()
