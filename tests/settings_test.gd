extends Node
## The settings store: defaults, keeping, checking, buses, keys.
const Settings := preload("res://scripts/UI/Settings.gd")
const PATH := "user://settings_store_test.cfg"
var failures := 0

func check(ok: bool, message: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + message)
	if not ok:
		failures += 1

func fresh(contents := "") -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))
	if not contents.is_empty():
		var file := FileAccess.open(PATH, FileAccess.WRITE)
		file.store_string(contents)
		file.close()
	GameSettings.use_path(PATH)
	GameSettings.reread()

func _ready() -> void:
	# A test run starts on no file at all: defaults, nothing read or written.
	check(GameSettings.current_path() == "", "a test run reads and writes no settings file (%s)" % GameSettings.current_path())
	var real := ProjectSettings.globalize_path("user://settings.cfg")
	var real_before := FileAccess.get_modified_time(real) if FileAccess.file_exists(real) else -1
	var original := GameSettings.current_path()
	var default_jump := InputMap.action_get_events(&"jump").duplicate()
	store_checks()
	startup_checks()
	bus_checks()
	key_checks()
	shim_checks()
	await hook_checks()
	# Leave the player's own settings and keys as they were.
	GameSettings.reset_keys()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))
	GameSettings.use_path(original)
	GameSettings.reread()
	check(InputMap.action_get_events(&"jump").size() == default_jump.size(), "the default keys are back after the suite")
	var real_after := FileAccess.get_modified_time(real) if FileAccess.file_exists(real) else -1
	check(real_after == real_before, "the player's own settings file is never touched")
	print("==== RESULTS ====")
	get_tree().quit(1 if failures else 0)

func store_checks() -> void:
	fresh()
	check(GameSettings.value("audio/music") == 1.0 and GameSettings.value("video/fov") == 75.0 and GameSettings.value("video/grid") == 480 and GameSettings.value("hud/subtitles") == true and GameSettings.value("comfort/camera_motion") == 1.0, "defaults")
	var heard := []
	# A lambda held by the static notifier past the end crashes the engine at
	# exit; nodes' methods let go when the node does, a lambda must be let go.
	var listen := func(key): heard.append(key)
	GameSettings.events().changed.connect(listen)
	var wanted := {"audio/master_volume": 0.4, "audio/music": 0.3, "audio/effects": 0.6, "audio/ambience": 0.2, "audio/souls": 0.9,
		"video/window": 1, "video/vsync": false, "video/fps": 60, "video/brightness": 1.2, "video/fov": 90.0, "video/grid": 240,
		"controls/sensitivity": 1.5, "controls/invert": true, "hud/awareness_marks": false, "hud/subtitles": false,
		"hud/subtitle_size": 2, "hud/crosshair": false, "comfort/camera_motion": 0.25}
	for key in wanted:
		GameSettings.set_value(key, wanted[key])
	GameSettings.events().changed.disconnect(listen)
	check(heard.size() == wanted.size(), "every change is announced (%d)" % heard.size())
	GameSettings.reread()
	var kept := true
	for key in wanted:
		if GameSettings.value(key) != wanted[key]:
			kept = false
			print("  not kept: %s = %s" % [key, GameSettings.value(key)])
	check(kept, "every setting survives a reload")
	GameSettings.set_value("video/fov", 300.0)
	GameSettings.set_value("audio/music", -2.0)
	GameSettings.set_value("video/fps", 75)
	GameSettings.set_value("video/grid", 100)
	GameSettings.set_value("hud/subtitle_size", 9)
	check(GameSettings.value("video/fov") == 100.0 and GameSettings.value("audio/music") == 0.0 and GameSettings.value("video/fps") == 60 and GameSettings.value("video/grid") == 240 and GameSettings.value("hud/subtitle_size") == 2, "out-of-range values are clamped, unknown steps refused")
	fresh("[video]\nfov=\"wide\"\ngrid=7\n[audio]\nmusic=nan\n[keys]\njump=\"banana\"\n")
	check(GameSettings.value("video/fov") == 75.0 and GameSettings.value("video/grid") == 480 and GameSettings.value("audio/music") == 1.0 and InputMap.action_get_events(&"jump").size() > 0, "a hand-spoilt file falls back to defaults, key by key")
	check(GameSettings.look_scale() == 1.0, "the look scale is 1 at the default sensitivity")

func startup_checks() -> void:
	# Read at start-up, only what the player changed is applied, so command
	# line flags (--disable-vsync, --max-fps) and tools keep theirs.
	fresh()
	Engine.max_fps = 77
	GameSettings.reread()
	GameSettings.value("video/fps")
	check(Engine.max_fps == 77, "a default frame limit read at start-up leaves the engine's own")
	fresh("[video]\nfps=30\n")
	GameSettings.value("video/fps")
	check(Engine.max_fps == (77 if GameSettings.flags_override_video() else 30), "a frame limit the player set is applied at start-up")
	Engine.max_fps = 0

func bus_checks() -> void:
	fresh()
	var music := AudioServer.get_bus_index(&"Music")
	if music < 0:
		AudioServer.add_bus()
		music = AudioServer.bus_count - 1
		AudioServer.set_bus_name(music, &"Music")
	var base := AudioServer.get_bus_volume_db(music)
	GameSettings.set_value("audio/music", 0.5)
	check(is_equal_approx(AudioServer.get_bus_volume_db(music), base + linear_to_db(0.5)), "the music slider sets its bus, relative to the bus's own level")
	GameSettings.set_value("audio/music", 1.0)
	check(is_equal_approx(AudioServer.get_bus_volume_db(music), base), "and full returns it to that level")
	GameSettings.set_value("audio/master_volume", 0.35)
	check(is_equal_approx(db_to_linear(AudioServer.get_bus_volume_db(0)), 0.35), "master sets the Master bus")
	GameSettings.set_value("audio/effects", 0.25)
	var late := AudioServer.get_bus_index(&"World")
	if late < 0:
		# As Sfx makes them: added (still "New Bus"), then named.
		AudioServer.add_bus()
		late = AudioServer.bus_count - 1
		AudioServer.set_bus_name(late, &"World")
		check(is_equal_approx(AudioServer.get_bus_volume_db(late), linear_to_db(0.25)), "a bus made later (World) gets its volume when it is named")
	else:
		check(is_equal_approx(AudioServer.get_bus_volume_db(late), GameSettings.bus_base(&"World") + linear_to_db(0.25)), "the effects slider sets World")
	GameSettings.set_value("audio/master_volume", 1.0)
	GameSettings.set_value("audio/effects", 1.0)

func key_checks() -> void:
	fresh()
	var to_f := InputEventKey.new()
	to_f.physical_keycode = KEY_F
	var jump_key := GameSettings.key_name(&"jump")
	var frob_key := GameSettings.key_name(&"frob")
	var holder := &""
	for action in GameSettings.ACTIONS:
		if GameSettings.key_name(action) == "F":
			holder = action
	var swapped := GameSettings.bind(&"jump", to_f)
	check(GameSettings.key_name(&"jump") == "F", "a key binds to an action (jump on F)")
	check(swapped == holder and (holder == &"" or GameSettings.key_name(holder) == jump_key), "a key another action used swaps with it (%s had F, now %s)" % [holder, GameSettings.key_name(holder) if holder != &"" else "-"])
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_RIGHT
	GameSettings.bind(&"kick", click)
	check(GameSettings.key_name(&"kick") == "Mouse 2", "a mouse button binds too")
	GameSettings.reread()
	check(GameSettings.key_name(&"jump") == "F" and GameSettings.key_name(&"kick") == "Mouse 2", "bindings survive a reload")
	check(GameSettings.ACTIONS.all(func(a): return InputMap.action_get_events(a).size() > 0), "no action is left without a key")
	GameSettings.reset_keys()
	check(GameSettings.key_name(&"jump") == jump_key and GameSettings.key_name(&"frob") == frob_key, "reset puts every key back (%s, %s)" % [GameSettings.key_name(&"jump"), GameSettings.key_name(&"frob")])

func shim_checks() -> void:
	fresh()
	Settings.path = PATH
	Settings.reread()
	Settings.set_master_volume(0.6)
	check(is_equal_approx(GameSettings.value("audio/master_volume"), 0.6), "the old Settings calls write the store")
	GameSettings.set_value("hud/awareness_marks", false)
	check(not Settings.awareness_marks(), "and read it")
	GameSettings.set_value("audio/master_volume", 1.0)
	GameSettings.set_value("hud/awareness_marks", true)

func hook_checks() -> void:
	fresh()
	# The camera: its field of view and how much it moves.
	var juice: RefCounted = load("res://scripts/PlayerUtils/CameraJuice.gd").new()
	var camera := Camera3D.new()
	add_child(camera)
	juice.setup(camera)
	check(juice.base_fov == 75.0 and juice.comfort == 1.0, "the camera starts at the settings' field of view and motion")
	GameSettings.set_value("video/fov", 90.0)
	GameSettings.set_value("comfort/camera_motion", 0.4)
	check(juice.base_fov == 90.0 and is_equal_approx(juice.comfort, 0.4), "and follows them")
	# Turning.
	var player_script: Script = load("res://scripts/PlayerController.gd")
	var turn: Vector2 = player_script.look_turn(Vector2(10, 10), 0.002)
	check(turn.is_equal_approx(Vector2(0.02, 0.02)), "turning at the defaults (%s)" % turn)
	GameSettings.set_value("controls/sensitivity", 2.0)
	GameSettings.set_value("controls/invert", true)
	turn = player_script.look_turn(Vector2(10, 10), 0.002)
	check(turn.is_equal_approx(Vector2(0.04, -0.04)), "sensitivity scales it and invert flips the pitch (%s)" % turn)
	# The screen.
	var retro := get_node_or_null(^"/root/Retro")
	GameSettings.set_value("video/grid", 360)
	check(retro != null and retro.virtual_height == 360, "the pixel grid follows the setting")
	GameSettings.set_value("video/brightness", 1.3)
	check(retro.brightness_pass.visible and is_equal_approx(float(retro.brightness_pass.material.get_shader_parameter("brightness")), 1.3), "brightness lifts the picture")
	GameSettings.set_value("video/brightness", 1.0)
	check(not retro.brightness_pass.visible, "and at 100% the pass is off")
	# The HUD's subtitles.
	var hud_script: Script = load("res://scripts/UI/StealthHUD.gd")
	check(hud_script.subtitle_px(0) < 21 and hud_script.subtitle_px(1) == 21 and hud_script.subtitle_px(2) > 21, "three subtitle sizes around today's")
	for key in ["video/fov", "comfort/camera_motion", "controls/sensitivity", "controls/invert", "video/grid"]:
		GameSettings.set_value(key, GameSettings.SPECS[key].default)
	camera.queue_free()
	await get_tree().process_frame
