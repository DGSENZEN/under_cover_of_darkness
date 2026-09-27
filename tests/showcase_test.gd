extends Node
## The NPC showcase (maps/npc_showcase.tscn): the yard and its people, the
## director's acts and beats, the camera and the viewer's overlay.
##
##   Godot --headless --fixed-fps 60 --quit-after 3000000 --path . res://tests/showcase_test.tscn

const MAP := preload("res://maps/npc_showcase.tscn")
const MapScript := preload("res://maps/npc_showcase.gd")
const SquadScript := preload("res://scripts/AISystem/Squad.gd")
const GarrisonScript := preload("res://scripts/AISystem/Garrison.gd")
const GuardScript := preload("res://scripts/AISystem/Guard.gd")
const DirectorScript := preload("res://scripts/Showcase/ShowDirector.gd")
const TimeFx := preload("res://scripts/Visual/TimeFx.gd")
const SoundBus := preload("res://scripts/StimuliSystem/SoundBus.gd")
const CameraScript := preload("res://scripts/Showcase/ShowCamera.gd")
const OverlayScript := preload("res://scripts/Showcase/ShowOverlay.gd")
const Sfx := preload("res://scripts/Audio/Sfx.gd")
const TalkDirector := preload("res://scripts/AISystem/Talk/TalkDirector.gd")
const TalkScript := preload("res://scripts/AISystem/Talk/TalkScript.gd")
const GatheringScript := preload("res://scripts/AISystem/Gathering.gd")
const NightRotaScript := preload("res://scripts/AISystem/NightRota.gd")
const CineEvents := preload("res://scripts/Cinema/CineEvents.gd")
const CineShot := preload("res://scripts/Cinema/CineShot.gd")
const CineVantage := preload("res://scripts/Cinema/CineVantage.gd")
const CineScreen := preload("res://scripts/Cinema/CineScreen.gd")

## Who is at which kind of station at the start of the night.
const STATIONED := {"Piers": &"sit", "Col": &"eat", "Tam": &"sleep", "Gideon": &"rummage", "Ned": &"carry", "Brand": &"chop"}
## What each station's man shows at it.
const SHOWS := {
	&"sit": [&"sit", &"sit_talk", &"sit_down"],
	&"eat": [&"eat", &"", &"talk", &"listen", &"fold_arms", &"drink", &"scratch", &"spit", &"roll_shoulders", &"stamp", &"check_blade", &"look_up", &"warm_hands"],
	&"sleep": [&"sleep", &"lie_down"],
	&"rummage": [&"lid", &"rummage", &""],
	&"carry": [&"carry", &"lift", &"set_down", &""],
	&"chop": [&"chop", &"drink"],
}

var results: Array[String] = []
## Every Cinema event over the runs (D39): [kind, outcome or state].
var _heard: Array = []


## Hears the Cinema events for D39.
class Ears:
	var into: Array

	func _init(p_into: Array) -> void:
		into = p_into

	func cine_event(kind: StringName, data: Dictionary) -> void:
		into.append([kind, data.get("outcome", data.get("state", &""))])
## The showcase now loaded (a reload swaps it: _reload).
var _loaded: Node = null


## Game time, as the world lives it (slowed with it).
class GameClock extends Node:
	var seconds := 0.0

	func _physics_process(delta: float) -> void:
		seconds += delta


## A story for the director's own checks: beats that end, and one that never
## does.
class TestStory:
	var acts_list: Array = []

	func acts() -> Array:
		return acts_list


func _ready() -> void:
	var ears := Ears.new(_heard)
	CineEvents.add_listener(ears)
	await _run()
	CineEvents.remove_listener(ears)
	GuardScript.randomize_on = true
	print("\n==== RESULTS ====")
	for r in results:
		print(r)
	get_tree().quit()


func _run() -> void:
	# D1 the yard builds and bakes, and its people are where they belong
	var map := await _map(false)
	await _frames(1200)
	var missing := []

	for name in MapScript.CAST_NAMES:
		if not map.cast.has(name) or not is_instance_valid(map.cast[name]):
			missing.append(name)

	var wrong := []

	for name in STATIONED:
		var man: Node = map.cast.get(name)

		if man == null or not is_instance_valid(man) or not (StringName(man.activity()) in SHOWS[STATIONED[name]]) or man._rota._held() == null:
			wrong.append("%s:%s" % [name, man.activity() if man != null and is_instance_valid(man) else "gone"])

	# Hendrik has the postern at the start of the night; Jory is on the bench
	# until the watch changes.
	var hendrik: Node3D = map.cast.get("Hendrik")
	var posted: bool = hendrik != null and hendrik.global_position.distance_to(map.marks["postern_post"]) < 1.2
	var jory: Node3D = map.cast.get("Jory")
	var benched: bool = jory != null and StringName(jory.activity()) in [&"sit", &"sit_talk", &"sit_down"]
	var nav := get_viewport().world_3d.navigation_map
	var path := NavigationServer3D.map_get_path(nav, map.marks["gate"], map.marks["postern_post"], true)
	var length := 0.0

	for i in range(1, path.size()):
		length += path[i - 1].distance_to(path[i])

	var straight: float = (map.marks["gate"] as Vector3).distance_to(map.marks["postern_post"])
	_check("D1 the yard builds and bakes, every cast member stands at his place, and each station has its man",
		missing.is_empty() and wrong.is_empty() and posted and benched and path.size() > 1 and length < straight * 1.6,
		"missing %s, not at their stations %s, Hendrik at the postern %s, Jory on the bench %s, gate to postern %.1f m walked for %.1f m straight" % [missing, wrong, posted, benched, length, straight])

	# D1b the carrier really carries: crates from the cart to the store
	var drop: Vector3 = map.get_node("CratesDrop").global_position
	await _until(func(): return _crates_near(drop, 2.2) >= 1, 3600)
	_check("D1b Ned carries crates off the cart to the store's north end",
		_crates_near(drop, 2.2) >= 1,
		"crates at the store %d, Ned %s at %s" % [_crates_near(drop, 2.2), map.cast["Ned"].activity(), map.cast["Ned"].global_position])
	await _unload(map)

	# ------------------------------------------------------------------
	# The director
	# ------------------------------------------------------------------

	# D2 a beat that never comes true is let go, and the show goes on
	var story2 := TestStory.new()
	story2.acts_list = [{"title": "A test", "beats": [
		{"name": &"never", "until": func(): return false, "timeout": 1.0},
		{"name": &"next", "min": 0.5},
	]}]
	var director2: Node = DirectorScript.new()
	add_child(director2)
	director2.setup(null, story2)
	var skipped2 := []
	var started2 := []
	var ended2 := [false]
	director2.beat_skipped.connect(func(n): skipped2.append(n))
	director2.beat_started.connect(func(n, _shot): started2.append(n))
	director2.show_ended.connect(func(): ended2[0] = true)
	director2.run()
	await _until(func(): return ended2[0], 300)
	_check("D2 a beat whose condition never comes true times out, is skipped with a log line, and the next beat starts",
		skipped2 == [&"never"] and started2 == [&"never", &"next"] and ended2[0] and director2.log_lines.any(func(l): return l.contains("never")),
		"skipped %s, started %s, ended %s, log %s" % [skipped2, started2, ended2[0], director2.log_lines])
	director2.queue_free()

	# D3 what the command line asks for
	var director3: Node = DirectorScript.new()
	director3.read_args(PackedStringArray(["--act=3", "--ending=escape", "--auto", "--quit-at-end"]))
	_check("D3 --act=3 --ending=escape --auto --quit-at-end are read from the command line",
		DirectorScript.start_act == 3 and DirectorScript.ending == &"escape" and director3.auto and director3.quit_at_end,
		"act %d, ending %s, auto %s, quit %s" % [DirectorScript.start_act, DirectorScript.ending, director3.auto, director3.quit_at_end])
	director3.free()
	DirectorScript.start_act = 1
	DirectorScript.ending = &"random"

	# D10 jumping about the acts leaves nothing behind
	_loaded = await _map(false)
	var director10: Node = DirectorScript.new()
	add_child(director10)
	director10.setup(_loaded, TestStory.new())
	director10.reload = _reload
	# A hunt, a garrison that remembers, time slowed: all to be forgotten.
	var someone: Node3D = _loaded.spawn_intruder(Vector3(0, 0, 8))
	SquadScript.of(someone)
	GarrisonScript.of(someone).dread = 0.5
	TimeFx.request(get_tree(), &"test", 0.3, 30.0)
	await director10.jump_to(3)
	await director10.jump_to(2)
	var guards10 := get_tree().get_nodes_in_group(&"guards").size()
	var listeners10 := SoundBus._listeners.size()
	_check("D10 jumping acts twice leaves one cast, no hunts, no garrison memory, time at 1, and the act asked for",
		guards10 == 12 and listeners10 == 12 + get_tree().get_nodes_in_group(&"atmosphere").size() and SquadScript._squads.is_empty() and GarrisonScript._garrisons.is_empty() and is_equal_approx(Engine.time_scale, 1.0) and DirectorScript.start_act == 2,
		"guards %d, listeners %d, hunts %d, garrisons %d, time %.2f, act %d" % [guards10, listeners10, SquadScript._squads.size(), GarrisonScript._garrisons.size(), Engine.time_scale, DirectorScript.start_act])
	director10.queue_free()
	DirectorScript.start_act = 1

	# D11 paused in the middle of a hit-stop: time comes back at the show speed
	var director11: Node = DirectorScript.new()
	add_child(director11)
	director11.setup(_loaded, TestStory.new())
	director11.set_speed(1)
	TimeFx.hitstop(get_tree(), 0.1)
	director11.toggle_pause()
	var paused11 := get_tree().paused
	await _frames(30)
	director11.toggle_pause()
	await _frames(5)
	var after11 := Engine.time_scale
	director11.set_speed(2)
	_check("D11 paused during a hit-stop, time comes back at the show speed after unpausing",
		paused11 and not get_tree().paused and is_equal_approx(after11, 0.5),
		"paused %s, now paused %s, time after %.3f" % [paused11, get_tree().paused, after11])
	director11.queue_free()

	# D20 in slow motion a beat's time is the world's time
	var clock20 := GameClock.new()
	add_child(clock20)
	var story20 := TestStory.new()
	story20.acts_list = [{"title": "Slow", "beats": [
		{"name": &"a_second", "until": func(): return clock20.seconds >= 1.0, "timeout": 2.0},
		{"name": &"after", "min": 0.1},
	]}]
	var director20: Node = DirectorScript.new()
	add_child(director20)
	director20.setup(null, story20)
	director20.set_speed(0)
	var skipped20 := []
	var ended20 := [false]
	director20.beat_skipped.connect(func(n): skipped20.append(n))
	director20.show_ended.connect(func(): ended20[0] = true)
	director20.run()
	await _until(func(): return ended20[0], 900)
	director20.set_speed(2)
	_check("D20 at quarter speed a beat waits in the world's time: one second of game time comes before its two-second timeout",
		ended20[0] and skipped20.is_empty() and clock20.seconds >= 1.0,
		"ended %s, skipped %s, game time %.2f s" % [ended20[0], skipped20, clock20.seconds])
	director20.queue_free()
	clock20.queue_free()
	await _unload(_loaded)

	# D19 the showcase starts the score and the ambience (Sfx.warm)
	var was_enabled := Sfx.enabled
	Sfx.enabled = true
	var map19 := await _map(false)
	await _frames(5)
	var music19 := get_tree().current_scene.get_node_or_null("Music") != null
	Sfx.enabled = was_enabled
	_check("D19 the showcase starts the score and the ambience (there is a Music node)",
		music19,
		"music %s" % music19)
	var music_node := get_tree().current_scene.get_node_or_null("Music")
	if music_node != null:
		music_node.queue_free()
	var ambience_node := get_tree().current_scene.get_node_or_null("Ambience")
	if ambience_node != null:
		ambience_node.queue_free()
	await _unload(map19)

	# ------------------------------------------------------------------
	# The camera
	# ------------------------------------------------------------------

	var map13 := await _map(false)
	var camera: Camera3D = CameraScript.new()
	add_child(camera)
	camera.setup(map13, null)
	camera.make_current()

	# D14 a pinned close shot puts his head on a third, his eyes high (a man
	# at his ease: before D13 sets the yard running)
	var osric: Node3D = map13.cast["Osric"]
	camera.want({"mode": &"observe", "subjects": [osric], "pin": {"kind": &"close", "subjects": [osric], "seconds": 30.0}})
	await _frames(300)
	var head: Vector3 = CineShot.head_of(osric)
	var size := get_viewport().get_visible_rect().size
	var on_screen := camera.unproject_position(head)
	var on_third: bool = (absf(on_screen.x - size.x / 3.0) < 0.08 * size.x or absf(on_screen.x - size.x * 2.0 / 3.0) < 0.08 * size.x) \
		and on_screen.y >= 0.2 * size.y and on_screen.y <= 0.45 * size.y and not camera.is_position_behind(head)
	_check("D14 a pinned close shot on a guard puts his head on a third, his eyes in the upper third",
		on_third and camera.global_position.distance_to(head) < 4.0,
		"head at %s of %s, %.1f m off; camera %s, mode %d, osric moved %s" % [on_screen, size, camera.global_position.distance_to(head), camera.global_position, camera.mode, osric.velocity])

	# D13 following a man who dies
	var col: Node3D = map13.cast["Col"]
	camera.follow(col)
	await _frames(60)
	var fell_at := col.global_position
	col.take_hit(999.0, map13.cast["Osric"], &"power", col.global_position + Vector3.UP, Vector3.FORWARD)
	await _frames(30)
	var framing13: Vector3 = camera.focus_point()
	var held13: bool = framing13.distance_to(fell_at) < 2.5 and camera.mode == CameraScript.Mode.FOLLOW
	await _until(func(): return camera.mode == CameraScript.Mode.DIRECTOR, 240)
	_check("D13 following a man who dies, the camera frames where he fell, then returns to DIRECTOR within 3 s, with no errors",
		held13 and camera.mode == CameraScript.Mode.DIRECTOR,
		"held on where he fell %s (%.1f m off), mode now %d" % [held13, framing13.distance_to(fell_at), camera.mode])

	# D22 the camera is drawn where it is put (not physics-interpolated: it
	# moves every drawn frame)
	await _frames(30)
	var drawn22: Vector3 = camera.get_global_transform_interpolated().origin
	_check("D22 the show camera is drawn where it is put, not interpolated between physics ticks",
		camera.physics_interpolation_mode == Node.PHYSICS_INTERPOLATION_MODE_OFF and drawn22.distance_to(camera.global_position) < 0.01,
		"mode %d, drawn %.3f m from where it is" % [camera.physics_interpolation_mode, drawn22.distance_to(camera.global_position)])

	# D21 choosing the ending is not flying: V chooses it and leaves the
	# director the camera; E flies and leaves the ending alone
	var director21: Node = DirectorScript.new()
	add_child(director21)
	director21.setup(map13, null)
	camera.mode = CameraScript.Mode.DIRECTOR
	var ending_before: StringName = DirectorScript.ending
	var v := InputEventKey.new()
	v.physical_keycode = KEY_V
	v.pressed = true
	Input.parse_input_event(v)
	await _frames(5)
	var chose21: bool = DirectorScript.ending != ending_before and camera.mode == CameraScript.Mode.DIRECTOR
	var ending_mid: StringName = DirectorScript.ending
	var e_down := InputEventKey.new()
	e_down.physical_keycode = KEY_E
	e_down.pressed = true
	Input.parse_input_event(e_down)
	await _frames(10)
	var e_up := InputEventKey.new()
	e_up.physical_keycode = KEY_E
	e_up.pressed = false
	Input.parse_input_event(e_up)
	await _frames(2)
	_check("D21 V chooses the ending and leaves the camera to the director; E flies and leaves the ending alone",
		chose21 and DirectorScript.ending == ending_mid and camera.mode == CameraScript.Mode.FREE,
		"chose %s, ending after E %s (was %s), camera mode %d" % [chose21, DirectorScript.ending, ending_mid, camera.mode])
	director21.queue_free()
	DirectorScript.ending = &"random"

	# D40 flying free, the director keeps its hands off: slow motion ends as
	# you take the camera, a new beat neither moves nor re-lenses it, its blur
	# is off, and nothing slows while you fly
	var mirelle: Node3D = map13.cast["Mirelle"]
	camera.mode = CameraScript.Mode.DIRECTOR
	camera.want({"mode": &"drama", "subjects": [osric]})
	await _frames(30)
	CineEvents.emit(&"knife", {"attacker": mirelle, "victim": osric, "where": osric.global_position})
	await _frames(18)
	var slowed40 := Engine.time_scale
	camera.mode = CameraScript.Mode.FREE
	var freed40 := Engine.time_scale
	await _frames(2)
	var at40 := camera.global_position
	var fov40 := camera.fov
	camera.want({"mode": &"drama", "subjects": [mirelle]})
	await _frames(3)
	var blur40: bool = camera.attributes is CameraAttributesPractical and (camera.attributes as CameraAttributesPractical).dof_blur_far_enabled
	var moved40 := camera.global_position.distance_to(at40)
	await _frames(9 * 60)
	CineEvents.emit(&"death", {"man": mirelle, "killer": osric, "where": mirelle.global_position})
	await _frames(18)
	var later40 := Engine.time_scale
	_check("D40 taking the camera ends slow motion; flying, a new beat neither moves nor re-lenses it, its blur is off, nothing slows it",
		slowed40 < 0.9 and absf(freed40 - 1.0) < 0.001 and moved40 < 0.01 and is_equal_approx(camera.fov, fov40) and is_equal_approx(fov40, 55.0) and not blur40 and absf(later40 - 1.0) < 0.001,
		"slowed %.2f, on taking %.2f, moved %.3f m, fov %.1f -> %.1f, blur %s, a death while flying %.2f" % [slowed40, freed40, moved40, fov40, camera.fov, blur40, later40])

	# D15 flying while paused
	camera.mode = CameraScript.Mode.FREE
	get_tree().paused = true
	var before15 := camera.global_position
	var press := InputEventKey.new()
	press.physical_keycode = KEY_W
	press.pressed = true
	Input.parse_input_event(press)
	await _frames(30)
	var release := InputEventKey.new()
	release.physical_keycode = KEY_W
	release.pressed = false
	Input.parse_input_event(release)
	get_tree().paused = false
	_check("D15 moving in FREE mode while paused changes the camera position",
		camera.global_position.distance_to(before15) > 0.5,
		"moved %.2f m" % camera.global_position.distance_to(before15))
	camera.queue_free()
	await _unload(map13)

	# ------------------------------------------------------------------
	# The overlay
	# ------------------------------------------------------------------

	var map16 := await _map(false)
	var eye := Camera3D.new()
	add_child(eye)
	var osric16: Node3D = map16.cast["Osric"]
	eye.global_position = osric16.global_position + Vector3(0, 1.8, 6.0)
	eye.look_at(osric16.global_position + Vector3.UP * 1.5, Vector3.UP)
	eye.make_current()
	var overlay: CanvasLayer = OverlayScript.new()
	add_child(overlay)
	overlay.setup(map16)

	# D16 what a man in view says is shown, with his name; not one behind you
	var behind: Node3D = map16.cast["Aldous"]
	osric16.bark("A test line.")
	behind.bark("Unseen line.")
	await _frames(3)
	var shown16: Array = overlay.shown_subtitles()
	_check("D16 a bark from a guard in view shows as a subtitle with his name; one behind the camera does not",
		shown16.has("Osric: A test line.") and not shown16.any(func(t): return String(t).contains("Unseen")),
		"shown %s" % [shown16])

	# D17 into a fight: "!" over him for about 2 s
	osric16.alert_changed.emit(4, 0)
	await _frames(3)
	var marked17: bool = overlay.shown_marks().has([osric16, "!"])
	await _frames(150)
	var gone17: bool = not overlay.shown_marks().has([osric16, "!"])
	_check("D17 a man going to COMBAT shows \"!\" over him for about 2 s",
		marked17 and gone17,
		"marked %s, gone after 2.5 s %s" % [marked17, gone17])

	# D18 H hides it all, and shows it again
	overlay.title("II. A Knife in the Dark")
	var key := InputEventKey.new()
	key.physical_keycode = KEY_H
	key.pressed = true
	Input.parse_input_event(key)
	await _frames(2)
	var hidden18: bool = not overlay.visible
	osric16.bark("Said while hidden.")
	await _frames(2)
	var none18: bool = overlay.shown_subtitles().is_empty()
	var key2 := InputEventKey.new()
	key2.physical_keycode = KEY_H
	key2.pressed = true
	Input.parse_input_event(key2)
	await _frames(2)
	_check("D18 H hides every subtitle, mark and title (and shows them again)",
		hidden18 and none18 and overlay.visible,
		"hidden %s, nothing shown %s, back %s" % [hidden18, none18, overlay.visible])
	overlay.queue_free()
	eye.queue_free()
	await _unload(map16)

	# ------------------------------------------------------------------
	# The night (ShowNight), act by act from each act's own start
	# ------------------------------------------------------------------

	# D4 Act I: the watch at rest
	DirectorScript.start_act = 1
	var map4 := await _map(true)
	var shown4 := {}
	var talked4 := [false]
	var habits4 := {}
	var clock4 := GameClock.new()
	add_child(clock4)
	await _until(func():
		for man in map4.cast.values():
			if is_instance_valid(man) and man._habits.habit != &"":
				habits4[man._habits.habit] = true
		for name in STATIONED:
			var man: Node = map4.cast.get(name)
			if man != null and is_instance_valid(man) and StringName(man.activity()) in [&"sit", &"sit_talk", &"eat", &"sleep", &"rummage", &"carry", &"chop"]:
				shown4[name] = true
		for name in ["Mirelle", "Osric", "Piers", "Col"]:
			var man: Node = map4.cast.get(name)
			if man != null and is_instance_valid(man) and StringName(man.activity()) in [&"talk", &"sit_talk"]:
				talked4[0] = true
		return map4.director.act_index >= 2, 20000)
	_check("D4 Act I: every stationed man shows his station's activity at least once, and a pair talk",
		shown4.size() == STATIONED.size() and talked4[0] and map4.director.act_index >= 2,
		"shown %s, talked %s, act now %d" % [shown4.keys(), talked4[0], map4.director.act_index])

	# D30 Act I is a night that moves: eight conversations or more (none but
	# those meant to be said again said twice), three gatherings and the watch
	# changing, and Jory at the postern for Act II
	var played4: Array = TalkDirector.of(map4).played()
	var history4: Array = GatheringScript.of(map4).history()
	var again := {}

	for conv in TalkScript.library()["conversations"]:
		again[conv["id"]] = bool(conv["again"])

	var twice4 := []

	for id in played4:
		if not again.get(id, false) and played4.count(id) > 1 and not twice4.has(id):
			twice4.append(id)

	var distinct4 := {}

	for id in played4:
		distinct4[id] = true

	var kinds4 := {}

	for kind in history4:
		if kind != &"watch_change":
			kinds4[kind] = true

	var jory4: Node3D = map4.cast.get("Jory")
	var at_post4: bool = jory4 != null and jory4.global_position.distance_to(map4.marks["postern_post"]) < 1.2
	_check("D30 Act I is a night that moves: eight conversations or more, none repeated, three gatherings and the watch changing, Jory at the postern for Act II",
		distinct4.size() >= 8 and twice4.is_empty() and kinds4.size() >= 3 and history4.has(&"watch_change") and at_post4 and clock4.seconds <= 300.0,
		"%d conversations (%s), said twice %s, gatherings %s, Jory at the postern %s, Act I took %.0f s" % [distinct4.size(), played4, twice4, history4, at_post4, clock4.seconds])

	# D35 his own ways (GuardHabits) keep a man at his mark: a fidget, the
	# wall behind him; never off to a friend or a seat (the night is the
	# rota's and the gatherings')
	var free4 := []

	for name in map4.cast:
		var man: Node = map4.cast[name]

		if is_instance_valid(man) and man._habits.leanings.keys().any(func(h): return float(man._habits.leanings[h]) > 0.0 and not (h in [&"fidget", &"lean"])):
			free4.append(name)

	_check("D35 in the showcase a man's own ways keep him at his mark: fidgets and the wall behind him, never off to a friend",
		free4.is_empty() and habits4.keys().all(func(h): return h in [&"fidget", &"lean"]),
		"free to wander %s, did %s" % [free4, habits4.keys()])

	# D36 Act I is watched, in long takes
	var shots4: Array = map4.camera.cinema_editor().history()
	var modes4: Array = shots4.map(func(sh): return sh.get("mode", &"observe"))
	var total4 := 0.0

	for i in range(shots4.size() - 1):
		total4 += float(shots4[i + 1]["at"]) - float(shots4[i]["at"])

	var mean4 := total4 / float(maxi(shots4.size() - 1, 1))
	_check("D36 Act I is watched (observe throughout), its takes 15 s long on average or more",
		map4.camera.cinema_editor().mode() == &"observe" and not modes4.has(&"drama") and mean4 >= 15.0 and shots4.size() >= 2,
		"%d shots, mean %.1f s, kinds %s" % [shots4.size(), mean4, shots4.map(func(sh): return sh["kind"])])
	clock4.queue_free()
	await _unload(map4)

	# D5 Act II: the knife in the dark, and the man who saw it
	DirectorScript.start_act = 2
	var map5 := await _map(true)
	var jory5: Node3D = map5.cast["Jory"]
	var ned: Node3D = map5.cast["Ned"]
	var ned_barks := []
	ned.barked.connect(func(t): ned_barks.append(t))
	var osric5: Node3D = map5.cast["Osric"]
	var osric_barks := []
	osric5.barked.connect(func(t): osric_barks.append(t))
	# Held weakly: once he is dead the check must not touch him.
	var jory_held: WeakRef = weakref(jory5)
	var damped5 := [false]
	var killed_at := [-1]
	var frame5 := [0]
	await _until(func():
		frame5[0] += 1
		if map5.intruder != null and is_instance_valid(map5.intruder) and map5.intruder.exposure_scale < 0.5:
			damped5[0] = true
		var jory_now: Variant = jory_held.get_ref()
		if killed_at[0] < 0 and (jory_now == null or not is_instance_valid(jory_now) or jory_now._knocked_out):
			killed_at[0] = frame5[0]
		return killed_at[0] >= 0 and frame5[0] > killed_at[0] + 720, 9000)
	var undamped5: bool = map5.intruder != null and is_instance_valid(map5.intruder) and is_equal_approx(map5.intruder.exposure_scale, 1.0)
	var saw5: bool = is_instance_valid(ned) and (ned.state >= 3 or ned_barks.any(func(t): return String(t).contains("Murder")))
	_check("D5 Act II: Jory dies by backstab, the damping is off after the kill, and Ned sees it (combat or searching, or a Murder bark) within 12 s",
		killed_at[0] >= 0 and damped5[0] and undamped5 and saw5,
		"Jory killed at frame %d, damped before %s, undamped after %s, Ned state %d, said %s" % [killed_at[0], damped5[0], undamped5, ned.state if is_instance_valid(ned) else -1, ned_barks])

	# D31 after the murder his brother calls his name
	_check("D31 after the murder, Osric calls his brother's name", osric_barks.any(func(t): return String(t).contains("Jory")),
		"Osric said %s" % [osric_barks])
	await _unload(map5)

	# D6 Act III: the cry goes round, the bell, the hunt
	DirectorScript.start_act = 3
	var map6 := await _map(true)
	var rung6 := [false]
	for bell in get_tree().get_nodes_in_group(&"alarm_bells"):
		bell.rung.connect(func(_by): rung6[0] = true)
	var stirred6 := {}
	var states6 := {}
	var searching6 := [0]
	await _until(func():
		for name in map6.cast:
			var man: Variant = map6.cast[name]
			if man != null and is_instance_valid(man) and (man as Node).state != 0:
				stirred6[name] = true
				states6[name] = maxi(int(states6.get(name, 0)), int((man as Node).state))
		var searching := 0
		for man in get_tree().get_nodes_in_group(&"guards"):
			if man.state == 3:
				searching += 1
		searching6[0] = maxi(searching6[0], searching)
		return stirred6.size() >= map6.cast.size() - 1 and rung6[0] and searching6[0] >= 2, 1800)
	_check("D6 Act III: within 30 s every man is out of RELAXED, the bell has rung, and at least two men search",
		stirred6.size() >= map6.cast.size() - 1 and rung6[0] and searching6[0] >= 2,
		"stirred %d of %d, bell %s, most searching at once %d; highest states %s; beats skipped %s" % [stirred6.size(), map6.cast.size(), rung6[0], searching6[0], states6, map6.director.log_lines])
	await _unload(map6)

	# D7 Act IV: steel, beat by beat
	DirectorScript.start_act = 4
	DirectorScript.ending = &"victor"
	var map7 := await _map(true)
	var berserk7 := [false]
	var plea7 := [false]
	await _until(func():
		var brand: Variant = map7.cast.get("Brand")
		if brand != null and is_instance_valid(brand) and (brand as Node)._fighter.squad != null and (brand as Node)._fighter.squad.role_of(brand) == &"berserk":
			berserk7[0] = true
		for man in get_tree().get_nodes_in_group(&"guards"):
			if man._mercy.pleading:
				plea7[0] = true
		return map7.director.act_index >= 5 or map7.director.log_lines.size() >= 3, 12000)
	var skipped7: Array = map7.director.log_lines
	var needed7 := skipped7.filter(func(l): return l.contains("turtle") or l.contains(" parry ") or l.contains("focus"))
	var deathblows7: int = map7.story.deathblows() + map7.story.riposte_kills()
	var mirelle_dead: bool = map7.story._dead("Mirelle")
	_check("D7 Act IV: turtle brings the squad's break plan with Brand as breaker; parry cuts a man down (deathblow or riposte); focus leaves Mirelle dead and Brand berserk; press brings a plea",
		needed7.is_empty() and deathblows7 >= 1 and mirelle_dead and berserk7[0] and map7.director.act_index >= 5,
		"skipped %s, deathblows and riposte kills %d, Mirelle dead %s, Brand berserk %s, a plea %s, act now %d" % [skipped7, deathblows7, mirelle_dead, berserk7[0], plea7[0], map7.director.act_index])
	await _unload(map7)

	# D8 each ending, from Act V's own start
	for ending in [&"overwhelmed", &"victor", &"escape"]:
		DirectorScript.start_act = 5
		DirectorScript.ending = ending
		var map8 := await _map(true)
		var ended8 := [false]
		map8.director.show_ended.connect(func(): ended8[0] = true)
		await _until(func(): return ended8[0], 7200)
		var skipped8: Array = map8.director.log_lines
		var outcome8: String = map8.story.ending_outcome()
		_check("D8 the %s ending finishes before its timeout (%s)" % [ending, outcome8],
			ended8[0] and skipped8.is_empty() and map8.story.ending_done(),
			"ended %s, skipped %s, outcome %s" % [ended8[0], skipped8, outcome8])
		await _unload(map8)

	# D12 the intruder cut down mid-act, and the next beats' verbs skipped
	# through (N): nothing asked of him, nothing breaks, the show goes on
	DirectorScript.start_act = 4
	DirectorScript.ending = &"escape"
	var map12 := await _map(true)
	await _until(func(): return map12.director.beat_name == &"trade", 1800)
	var intruder12: Node3D = map12.intruder
	var in_trade: bool = map12.director.beat_name == &"trade" and intruder12 != null
	if intruder12 != null:
		intruder12.fall()
		intruder12.take_hit(9999.0, map12.cast["Brand"], &"power", intruder12.global_position + Vector3.UP, Vector3.FORWARD)
	await _frames(10)
	var beats12 := [map12.director.beat_name]
	for code in [KEY_N, KEY_N, KEY_N]:
		var key12 := InputEventKey.new()
		key12.physical_keycode = code
		key12.pressed = true
		Input.parse_input_event(key12)
		await _frames(60)
		beats12.append(map12.director.beat_name)
	var brainless12: bool = map12.story._brain() == null and map12.story._intruder() == null
	_check("D12 with the intruder cut down mid-act and the next beats skipped through (N x3), nothing is asked of him, nothing breaks, and the show goes on",
		in_trade and brainless12 and beats12.size() == 4 and beats12[3] != beats12[0],
		"in trade %s, nothing asked %s, beats %s" % [in_trade, brainless12, beats12])
	await _unload(map12)
	DirectorScript.ending = &"random"

	# D9 the whole night, unattended, from the first act to the end
	DirectorScript.start_act = 1
	DirectorScript.ending = &"escape"
	var map9 := await _map(true)
	var ended9 := [false]
	var frames9 := [0]
	var knife_at := [-1.0]
	var coda_at := [-1.0]
	var bars9 := []
	var seen9 := [0, 0]
	var blind9 := []
	var editor9: Node = map9.camera.cinema_editor()
	var checked9 := [0]
	map9.director.show_ended.connect(func(): ended9[0] = true)
	map9.director.beat_started.connect(func(beat: StringName, _scene: Dictionary) -> void:
		if beat == &"the_knife":
			knife_at[0] = float(editor9._clock)
		if beat in [&"silence", &"walk_out", &"gone"] and coda_at[0] < 0.0:
			coda_at[0] = float(editor9._clock))
	await _until(func():
		frames9[0] += 1
		# Each new shot: does the camera see the man it is on?
		var history: Array = editor9.history()
		while checked9[0] < history.size() - 1 or (checked9[0] < history.size() and frames9[0] % 2 == 0):
			var shot: Dictionary = history[checked9[0]]
			checked9[0] += 1
			var on: Array = (shot["subjects"] as Array).filter(func(m): return m != null and is_instance_valid(m))
			if not on.is_empty():
				seen9[0] += 1
				var saw: bool = CineVantage.sees(map9.get_world_3d().direct_space_state, map9.camera.global_position, [on[0]])
				seen9[1] += 1 if saw else 0
				if not saw:
					blind9.append([shot["kind"], shot["cause"], shot["how"], String(on[0].get("given_name")), snappedf((on[0] as Node3D).global_position.x, 0.1), snappedf((on[0] as Node3D).global_position.z, 0.1)])
		if knife_at[0] >= 0.0 and float(editor9._clock) - knife_at[0] > 2.0:
			bars9.append(editor9.screen().bar_height())
		return ended9[0], 25200)
	_check("D9 the whole night from Act I plays to its end in under 7 minutes of game time",
		ended9[0] and frames9[0] < 25200,
		"ended %s after %.0f s, beats skipped %s" % [ended9[0], frames9[0] / 60.0, map9.director.log_lines])

	# D37 from the knife on: the letterbox up and the shots short
	var drama9: Array = editor9.history().filter(func(sh): return float(sh["at"]) >= knife_at[0] and (coda_at[0] < 0.0 or float(sh["at"]) < coda_at[0]))
	var total9 := 0.0

	for i in range(drama9.size() - 1):
		total9 += float(drama9[i + 1]["at"]) - float(drama9[i]["at"])

	var mean9 := total9 / float(maxi(drama9.size() - 1, 1))
	var target9: float = CineScreen.bar_for(get_viewport().get_visible_rect().size)
	var bars_up: bool = not bars9.is_empty() and bars9.slice(int(90)).all(func(b): return b >= 0.9 * target9)
	_check("D37 from the knife on the letterbox is up and the shots are short (7 s or less on average)",
		knife_at[0] >= 0.0 and bars_up and drama9.size() >= 5 and mean9 <= 7.0,
		"knife at %.1f, %d shots, mean %.1f s, bar %s of %.1f; causes %s" % [knife_at[0], drama9.size(), mean9, bars9.slice(bars9.size() - 1) if not bars9.is_empty() else [], target9, _tally(drama9.map(func(sh): return String(sh["kind"]) + "/" + String(sh["cause"])))])

	# D38 every shot sees the man it is on when it starts (1 in 20 may not)
	_check("D38 every shot sees the man it is on as it begins (at most 1 in 20 not)",
		seen9[0] >= 10 and float(seen9[1]) >= 0.95 * float(seen9[0]), "%d of %d shots saw their man; blind %s" % [seen9[1], seen9[0], blind9])

	# D39 the world told the camera everything it needed
	var kinds39 := {}

	for e in _heard:
		kinds39[e[0]] = true

	var blows39 := _heard.filter(func(e): return e[0] == &"blow").map(func(e): return e[1])
	var gathered39 := _heard.filter(func(e): return e[0] == &"gathering").map(func(e): return e[1])
	var all39: bool = [&"line", &"gathering", &"alert", &"spotted", &"blow", &"death", &"knife"].all(func(k): return kinds39.has(k)) \
		and blows39.has(&"landed") and (blows39.has(&"blocked") or blows39.has(&"parried")) and gathered39.has(&"started") and gathered39.has(&"ended")
	_check("D39 over the night the camera heard lines, gatherings begun and ended, alerts, spottings, blows landed and turned, deaths and the knife",
		all39, "kinds %s, blows %s, gatherings %s" % [kinds39.keys(), blows39.slice(0, 8), gathered39.slice(0, 6)])
	await _unload(map9)
	DirectorScript.start_act = 1
	DirectorScript.ending = &"random"
	await _other_nights()


## How many of each in `items`.
func _tally(items: Array) -> Dictionary:
	var counts := {}

	for item in items:
		counts[item] = int(counts.get(item, 0)) + 1

	return counts


## The director's reload for a test: the showcase freed and loaded afresh
## (the real one reloads the scene).
## D32 and D33 (called at the end of the run).
func _other_nights() -> void:
	# D32 Act I comes to its end on other nights too
	var times := []

	for night in [7, 99]:
		MapScript.seed_override = night
		DirectorScript.start_act = 1
		var map32 := await _map(true)
		var clock32 := GameClock.new()
		add_child(clock32)
		await _until(func(): return map32.director.act_index >= 2 or clock32.seconds > 330.0, 20400)
		times.append([night, map32.director.act_index >= 2, clock32.seconds])
		clock32.queue_free()
		await _unload(map32)

	MapScript.seed_override = -1
	_check("D32 Act I comes to its end on other nights too (seeds 7 and 99)", times.all(func(t): return t[1] and float(t[2]) <= 330.0),
		"%s" % [times])

	# D34 however Act I went, Act II finds Jory at the postern and nobody
	# still gathering
	DirectorScript.start_act = 1
	var map34 := await _map(true)
	await _frames(60)

	while map34.director.act_index < 2:
		map34.director.next_beat()
		await _frames(30)

	await _frames(60)
	var jory34: Node3D = map34.cast.get("Jory")
	var posted34: bool = jory34 != null and jory34.global_position.distance_to(map34.marks["postern_post"]) < 1.2
	var gatherings34: RefCounted = GatheringScript.of(map34)
	_check("D34 whatever Act I came to, Act II finds Jory at the postern and no gathering going on or asked for",
		posted34 and gatherings34.live().is_empty() and gatherings34.queued().is_empty(),
		"Jory at %s, gatherings live %d, asked for %s" % [jory34.global_position if jory34 != null else "gone", gatherings34.live().size(), gatherings34.queued()])
	await _unload(map34)

	# D33 a whisper is shown smaller than talk, a shout larger
	_check("D33 the subtitles show a whisper small and a shout large",
		OverlayScript.size_for(&"whisper") < OverlayScript.size_for(&"") and OverlayScript.size_for(&"") < OverlayScript.size_for(&"shout"),
		"whisper %d, talk %d, shout %d" % [OverlayScript.size_for(&"whisper"), OverlayScript.size_for(&""), OverlayScript.size_for(&"shout")])


func _reload() -> void:
	if _loaded != null and is_instance_valid(_loaded):
		_loaded.queue_free()
		await _frames(2)

	_loaded = await _map(false)


func _crates_near(point: Vector3, reach: float) -> int:
	var count := 0

	for crate in get_tree().get_nodes_in_group(&"cargo"):
		if Vector2(crate.global_position.x - point.x, crate.global_position.z - point.z).length() < reach:
			count += 1

	return count


## The showcase, loaded; `show` false leaves the director out (the people
## just live).
func _map(show: bool) -> Node:
	MapScript.run_show = show
	var map: Node = MAP.instantiate()
	add_child(map)
	await map.ready_to_show
	return map


func _unload(map: Node) -> void:
	map.queue_free()

	# What the fight left under the scene's root, not the map's (cut-off limbs,
	# blood): the next check's yard would find them.
	for child in get_children():
		child.queue_free()

	for group in [&"bodies", &"dropped_weapons", &"dropped_lights", &"stray_arrows"]:
		for thing in get_tree().get_nodes_in_group(group):
			thing.queue_free()

	await _frames(3)
	SquadScript.clear_all()
	GarrisonScript.clear_all()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _until(cond: Callable, max_frames: int) -> void:
	for i in max_frames:
		if cond.call():
			return
		await get_tree().physics_frame


func _check(test_name: String, ok: bool, detail: String) -> void:
	results.append("%s  %s   [%s]" % ["PASS" if ok else "FAIL", test_name, detail])
