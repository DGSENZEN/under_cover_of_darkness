class_name GameSettings
extends RefCounted
## Every setting the player can change, kept in user://settings.cfg and put
## where it belongs: the sound buses, the window, the keys (InputMap). Things
## that live in a scene (the camera, the player's look, the screen pass, the
## HUD) read their values and follow events().changed. Loaded on first ask;
## Retro, an autoload, asks at start-up.

## Where they are kept. Tests point this elsewhere (use_path, then reload),
## so a run never changes the player's own. Set through use_path: a static
## var assigned from another script did not reach these functions (4.5.1),
## and the tests wrote the player's file.
static var _path := _default_path()


## The player's file; none at all on a test run (a scene or script under
## res://tests/), so a suite starts on defaults and never reads or writes it.
static func _default_path() -> String:
	for arg in OS.get_cmdline_args():
		if arg.begins_with("res://tests/") or arg.begins_with("tests/"):
			return ""
	return "user://settings.cfg"


## Command-line flags that set the video themselves (tools, recordings):
## then the start-up leaves window, VSync and frame limit to them.
static func flags_override_video() -> bool:
	for arg in OS.get_cmdline_args():
		if arg in ["--disable-vsync", "--max-fps", "--fixed-fps", "--write-movie", "--fullscreen", "--windowed", "--maximized"]:
			return true
	return false


static func use_path(where: String) -> void:
	_path = where


static func current_path() -> String:
	return _path

## Each setting: its default, and either its range (min, max: clamped) or its
## steps (anything else is refused). Switches have only a default.
const SPECS := {
	"audio/master_volume": {"default": 1.0, "min": 0.0, "max": 1.0},
	"audio/music": {"default": 1.0, "min": 0.0, "max": 1.0},
	"audio/effects": {"default": 1.0, "min": 0.0, "max": 1.0},
	"audio/ambience": {"default": 1.0, "min": 0.0, "max": 1.0},
	"audio/souls": {"default": 1.0, "min": 0.0, "max": 1.0},
	"video/window": {"default": 0, "min": 0, "max": 2},
	"video/vsync": {"default": true},
	"video/fps": {"default": 0, "steps": [30, 60, 120, 144, 0]},
	"video/brightness": {"default": 1.0, "min": 0.5, "max": 1.5},
	"video/fov": {"default": 75.0, "min": 60.0, "max": 100.0},
	"video/grid": {"default": 0, "steps": [480, 360, 240, 0]},
	"controls/sensitivity": {"default": 1.0, "min": 0.25, "max": 3.0},
	"controls/invert": {"default": false},
	"hud/awareness_marks": {"default": true},
	"hud/subtitles": {"default": true},
	"hud/subtitle_size": {"default": 1, "min": 0, "max": 2},
	"hud/crosshair": {"default": true},
	"comfort/camera_motion": {"default": 1.0, "min": 0.0, "max": 1.0},
}
## Which buses each volume moves. Master is set outright; the others keep the
## level they were given and are scaled from it.
const BUSES := {
	"audio/master_volume": [&"Master"],
	"audio/music": [&"Music"],
	"audio/effects": [&"World", &"WorldFar", &"Body"],
	"audio/ambience": [&"Ambience"],
	"audio/souls": [&"Souls"],
}
## The game's actions the player may rebind, in the order the page lists them.
const ACTIONS: Array[StringName] = [&"move_forward", &"move_back", &"move_left", &"move_right", &"jump", &"sprint",
		&"crouch", &"frob", &"inventory", &"throw", &"block", &"kick", &"dodge", &"lean_left", &"lean_right",
		&"belt_next", &"belt_prev", &"quick_save", &"quick_load"]

## Tells the scene's pieces a setting changed: changed(key). Connect a node's
## method (it lets go when the node is freed); a lambda left connected is
## still held at exit and crashes the engine.
class Notifier extends RefCounted:
	signal changed(key: String)

static var _loaded := false
static var _values := {}
static var _events := Notifier.new()
## Each bus's own level when first seen (dB), kept across reloads.
static var _bus_base := {}
## The project's keys, before any of the player's, as text (key:70,
## mouse:2): a static holding the events themselves crashes the engine at exit.
static var _default_keys := {}


static func events() -> Notifier:
	return _events


static func value(key: String) -> Variant:
	_load()
	return _values.get(key, SPECS[key].default if SPECS.has(key) else null)


## Checks, keeps and applies a setting, then announces it. A value it can't
## take (out of its steps, not a number) is refused and nothing changes.
static func set_value(key: String, wanted: Variant) -> void:
	_load()
	if not SPECS.has(key):
		push_warning("No setting %s." % key)
		return
	var checked: Variant = _checked(key, wanted)
	if checked == null:
		return
	_values[key] = checked
	_apply(key)
	_save()
	_events.changed.emit(key)


## Turning: the mouse's sensitivity as a multiple of the game's own (1 at default).
static func look_scale() -> float:
	return float(value("controls/sensitivity"))


## Forget what was read: the next ask reads the file again (tests). Not
## "reload": on a script class that is Script.reload, which recompiles the
## script and resets its state, path and all.
static func reread() -> void:
	_loaded = false
	_values.clear()


static func _load() -> void:
	if _loaded:
		return
	_loaded = true
	if _default_keys.is_empty():
		for action in ACTIONS:
			if InputMap.has_action(action):
				_default_keys[action] = InputMap.action_get_events(action).map(_event_text)
	var file := ConfigFile.new()
	var read := not _path.is_empty() and file.load(_path) == OK
	for key in SPECS:
		var parts: PackedStringArray = key.split("/")
		var kept: Variant = _checked(key, file.get_value(parts[0], parts[1])) if read and file.has_section_key(parts[0], parts[1]) else null
		_values[key] = SPECS[key].default if kept == null else kept
	_restore_default_keys()
	if read and file.has_section("keys"):
		for action in ACTIONS:
			var event := _event_from(str(file.get_value("keys", String(action), "")) if file.has_section_key("keys", String(action)) else "")
			if event != null:
				_set_events(action, [event])
	for key in SPECS:
		_apply(key, true)


static func _checked(key: String, wanted: Variant) -> Variant:
	var spec: Dictionary = SPECS[key]
	var default: Variant = spec.default
	if wanted == null:
		return null
	if default is bool:
		return _as_bool(wanted)
	if not (wanted is int or wanted is float) or not is_finite(float(wanted)):
		return null
	if spec.has("steps"):
		return int(wanted) if int(wanted) in spec.steps and float(wanted) == float(int(wanted)) else null
	if default is int:
		return clampi(int(wanted), int(spec.min), int(spec.max))
	return clampf(float(wanted), float(spec.min), float(spec.max))


static func _as_bool(wanted: Variant) -> Variant:
	match typeof(wanted):
		TYPE_BOOL:
			return wanted
		TYPE_INT, TYPE_FLOAT:
			return wanted != 0
		TYPE_STRING, TYPE_STRING_NAME:
			var said := str(wanted).strip_edges().to_lower()
			if said in ["true", "1", "yes", "on"]:
				return true
			if said in ["false", "0", "no", "off"]:
				return false
	return null


static func _save() -> void:
	if _path.is_empty():
		return
	var file := ConfigFile.new()
	file.load(_path)
	for key in SPECS:
		var parts: PackedStringArray = key.split("/")
		file.set_value(parts[0], parts[1], _values[key])
	file.save(_path)


# Applying

## At start-up the window, VSync and frame limit are set only if the player
## changed them, and never against command-line flags that set them.
static func _apply(key: String, at_start := false) -> void:
	if BUSES.has(key):
		apply_buses()
	elif key.begins_with("video/"):
		if at_start and key in ["video/window", "video/vsync", "video/fps"] and (_values[key] == SPECS[key].default or flags_override_video()):
			return
		_apply_video(key)


## Sets every volume's buses that exist now. Retro (an autoload) calls it
## again whenever buses are added, so ones made later get theirs.
static func apply_buses() -> void:
	if not _loaded:
		return
	for key in BUSES:
		var gain := linear_to_db(maxf(float(_values.get(key, 1.0)), 0.0001))
		for bus in BUSES[key]:
			var index := AudioServer.get_bus_index(bus)
			if index < 0:
				continue
			if not _bus_base.has(bus):
				_bus_base[bus] = 0.0 if bus == &"Master" else AudioServer.get_bus_volume_db(index)
			AudioServer.set_bus_volume_db(index, float(_bus_base[bus]) + gain)


## A bus's own level, before its slider (dB).
static func bus_base(bus: StringName) -> float:
	return float(_bus_base.get(bus, 0.0))


static func _apply_video(key: String) -> void:
	match key:
		"video/fps":
			Engine.max_fps = int(_values[key])
		"video/window", "video/vsync":
			# Nothing to set without a window (the headless test runs).
			if DisplayServer.get_name() == "headless":
				return
			if key == "video/window":
				var modes := [DisplayServer.WINDOW_MODE_WINDOWED, DisplayServer.WINDOW_MODE_FULLSCREEN, DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN]
				if DisplayServer.window_get_mode() != modes[int(_values[key])]:
					DisplayServer.window_set_mode(modes[int(_values[key])])
			else:
				DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if _values[key] else DisplayServer.VSYNC_DISABLED)


# Keys

## Binds `event` to `action`. Another action that had it takes this one's old
## key in exchange (so nothing is left unbound); returns that action, or &"".
static func bind(action: StringName, event: InputEvent) -> StringName:
	_load()
	var old: Array = InputMap.action_get_events(action)
	var swapped := &""
	for other in ACTIONS:
		if other != action and InputMap.has_action(other) and InputMap.action_get_events(other).any(func(e): return _same(e, event)):
			swapped = other
			_set_events(other, old.slice(0, 1) if not old.is_empty() else [])
			break
	_set_events(action, [event])
	if not _path.is_empty():
		var file := ConfigFile.new()
		file.load(_path)
		file.set_value("keys", String(action), _event_text(event))
		if swapped != &"" and not old.is_empty():
			file.set_value("keys", String(swapped), _event_text(old[0]))
		file.save(_path)
	_events.changed.emit("keys/%s" % action)
	return swapped


## Every key back as the game first had them.
static func reset_keys() -> void:
	_load()
	_restore_default_keys()
	if not _path.is_empty():
		var file := ConfigFile.new()
		file.load(_path)
		if file.has_section("keys"):
			file.erase_section("keys")
		file.save(_path)
	_events.changed.emit("keys")


## The key on an action as the page shows it: "W", "Space", "Mouse 1".
static func key_name(action: StringName) -> String:
	_load()
	var all := InputMap.action_get_events(action) if InputMap.has_action(action) else []
	if all.is_empty():
		return "—"
	return event_name(all[0])


static func event_name(event: InputEvent) -> String:
	if event is InputEventKey:
		var key := event as InputEventKey
		var code := key.physical_keycode if key.physical_keycode != KEY_NONE else key.keycode
		return OS.get_keycode_string(code)
	if event is InputEventMouseButton:
		var button := (event as InputEventMouseButton).button_index
		if button == MOUSE_BUTTON_WHEEL_UP:
			return "Wheel up"
		if button == MOUSE_BUTTON_WHEEL_DOWN:
			return "Wheel down"
		return "Mouse %d" % button
	return "?"


static func _restore_default_keys() -> void:
	for action in _default_keys:
		_set_events(action, _default_keys[action].map(_event_from).filter(func(e): return e != null))


static func _set_events(action: StringName, events_wanted: Array) -> void:
	if not InputMap.has_action(action):
		return
	InputMap.action_erase_events(action)
	for event in events_wanted:
		InputMap.action_add_event(action, event)


static func _same(a: InputEvent, b: InputEvent) -> bool:
	return _event_text(a) == _event_text(b)


static func _event_text(event: InputEvent) -> String:
	if event is InputEventKey:
		var key := event as InputEventKey
		return "key:%d" % (key.physical_keycode if key.physical_keycode != KEY_NONE else key.keycode)
	if event is InputEventMouseButton:
		return "mouse:%d" % (event as InputEventMouseButton).button_index
	return ""


static func _event_from(text: String) -> InputEvent:
	var parts := text.split(":")
	if parts.size() != 2 or not parts[1].is_valid_int():
		return null
	if parts[0] == "key":
		var key := InputEventKey.new()
		key.physical_keycode = int(parts[1]) as Key
		return key
	if parts[0] == "mouse":
		var button := InputEventMouseButton.new()
		button.button_index = int(parts[1]) as MouseButton
		return button
	return null
