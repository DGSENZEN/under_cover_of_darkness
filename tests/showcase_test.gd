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

## Who is at which kind of station at the start of the night.
const STATIONED := {"Piers": &"sit", "Col": &"eat", "Tam": &"sleep", "Gideon": &"rummage", "Ned": &"carry", "Brand": &"chop"}
## What each station's man shows at it.
const SHOWS := {
	&"sit": [&"sit", &"sit_talk", &"sit_down"],
	&"eat": [&"eat", &"", &"talk", &"listen", &"fold_arms", &"drink"],
	&"sleep": [&"sleep", &"lie_down"],
	&"rummage": [&"lid", &"rummage", &""],
	&"carry": [&"carry", &"lift", &"set_down", &""],
	&"chop": [&"chop", &"drink"],
}

var results: Array[String] = []
## The showcase now loaded (a reload swaps it: _reload).
var _loaded: Node = null


## A story for the director's own checks: beats that end, and one that never
## does.
class TestStory:
	var acts_list: Array = []

	func acts() -> Array:
		return acts_list


func _ready() -> void:
	await _run()
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

	var jory: Node3D = map.cast.get("Jory")
	var posted: bool = jory != null and jory.global_position.distance_to(map.marks["postern_post"]) < 1.2
	var nav := get_viewport().world_3d.navigation_map
	var path := NavigationServer3D.map_get_path(nav, map.marks["gate"], map.marks["postern_post"], true)
	var length := 0.0

	for i in range(1, path.size()):
		length += path[i - 1].distance_to(path[i])

	var straight: float = (map.marks["gate"] as Vector3).distance_to(map.marks["postern_post"])
	_check("D1 the yard builds and bakes, every cast member stands at his place, and each station has its man",
		missing.is_empty() and wrong.is_empty() and posted and path.size() > 1 and length < straight * 1.6,
		"missing %s, not at their stations %s, Jory at his post %s, gate to postern %.1f m walked for %.1f m straight" % [missing, wrong, posted, length, straight])

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
		guards10 == 12 and listeners10 == 12 and SquadScript._squads.is_empty() and GarrisonScript._garrisons.is_empty() and is_equal_approx(Engine.time_scale, 1.0) and DirectorScript.start_act == 2,
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
	await _unload(_loaded)


## The director's reload for a test: the showcase freed and loaded afresh
## (the real one reloads the scene).
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
