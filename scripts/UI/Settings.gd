extends RefCounted
## Lazy persistent HUD settings in user://settings.cfg; setters save immediately.
## path and reload() let tests isolate their config. Unknown/missing awareness_marks values default to true.

## Where they are kept. Tests point this elsewhere (and reload), so a run
## never changes the player's own.
static var path := "user://settings.cfg"

static var _loaded := false
static var _awareness_marks := true


## The marks over men noticing you (StealthHUD's awareness marks), and the
## ticks as one makes you out.
static func awareness_marks() -> bool:
	_load()
	return _awareness_marks


## Updates the cached bool and immediately writes hud/awareness_marks to path, preserving other config entries.
## ConfigFile save errors are not surfaced; the in-memory value still changes.
static func set_awareness_marks(on: bool) -> void:
	_load()
	_awareness_marks = on
	_save()


## Forget what was read: the next ask reads `path` again (tests).
static func reload() -> void:
	_loaded = false
	_awareness_marks = true


static func _load() -> void:
	if _loaded:
		return

	_loaded = true
	var file := ConfigFile.new()

	if file.load(path) == OK:
		_awareness_marks = _as_bool(file.get_value("hud", "awareness_marks", true), true)


## A value from the file as a switch, however it was written (true, 1,
## "false"); `otherwise` if it is not one.
static func _as_bool(value: Variant, otherwise: bool) -> bool:
	match typeof(value):
		TYPE_BOOL:
			return value
		TYPE_INT, TYPE_FLOAT:
			return value != 0
		TYPE_STRING, TYPE_STRING_NAME:
			var said := str(value).strip_edges().to_lower()

			if said in ["true", "1", "yes", "on"]:
				return true

			if said in ["false", "0", "no", "off"]:
				return false

	return otherwise


static func _save() -> void:
	var file := ConfigFile.new()
	# Whatever else is in it stays.
	file.load(path)
	file.set_value("hud", "awareness_marks", _awareness_marks)
	file.save(path)
