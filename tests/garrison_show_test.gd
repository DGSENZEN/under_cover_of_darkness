extends Node
## The NPC showcase's night in the garrison (maps/garrison.tscn, its story
## scripts/Showcase/GarrisonNight.gd): six acts, the divided hunt, the chapel
## fight, the captain's door and the three endings; the camera and the
## weather as the yard's.
##
## The sections are played by suite scenes a few at a time (each within
## tools/run_suites' 900 s): garrison_acts_test (S1 with S0, S2, S3),
## garrison_hunt_test (S4, S5), garrison_endings_test (S6),
## garrison_night_test (S7, S8).
##   Godot --headless --fixed-fps 60 --path . res://tests/garrison_acts_test.tscn
##   Godot --headless --fixed-fps 60 --path . res://tests/garrison_acts_test.tscn -- --only=S2

const MAP := preload("res://maps/garrison.tscn")
const MapScript := preload("res://maps/npc_showcase.gd")
const SquadScript := preload("res://scripts/AISystem/Squad.gd")
const GarrisonScript := preload("res://scripts/AISystem/Garrison.gd")
const GuardScript := preload("res://scripts/AISystem/Guard.gd")
const DirectorScript := preload("res://scripts/Showcase/ShowDirector.gd")
const TalkDirector := preload("res://scripts/AISystem/Talk/TalkDirector.gd")
const GatheringScript := preload("res://scripts/AISystem/Gathering.gd")
const CineEvents := preload("res://scripts/Cinema/CineEvents.gd")
const CineVantage := preload("res://scripts/Cinema/CineVantage.gd")

## The groups the captain divides the hunt into, by their ground.
const GROUPS := ["area_barracks", "area_west", "area_walls", "area_courtyard"]

## A night of two acts (for the director asked for a later act than it has).
class TwoActs:
	var staged := []

	func acts() -> Array:
		return [{"title": "one", "beats": [{"name": &"a", "min": 0.05}]},
			{"title": "two", "stage": func() -> void: staged.append(2), "beats": [{"name": &"b", "min": 0.05}]}]


## The sections this scene plays (empty: all of them).
@export var sections: PackedStringArray = []

var results: Array[String] = []


func _ready() -> void:
	await _run()
	GuardScript.randomize_on = true
	DirectorScript.start_act = 1
	DirectorScript.ending = &"random"
	print("\n==== RESULTS ====")

	for r in results:
		print(r)

	get_tree().quit()


func _run() -> void:
	# The scene's sections (each suite scene a few of them: tools/run_suites
	# gives each 900 s), or -- --only=S2,S5: those alone; else all.
	var only: Array = Array(sections)

	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--only="):
			only = arg.trim_prefix("--only=").split(",", false)

	# (S1 plays on into S0: Act I.)
	for section in ["S1", "S2", "S3", "S4", "S5", "S6", "S7"]:
		if only.is_empty() or only.has(section):
			var began := Time.get_ticks_msec()
			await call("_" + String(section).to_lower())
			print("[section] %s took %.0f s" % [section, (Time.get_ticks_msec() - began) / 1000.0])


func _s1() -> void:
	# S1 the night has six acts; 6 starts the last (read from the command
	# line); a night of fewer acts asked for a later one starts at its last,
	# staged
	DirectorScript.start_act = 1
	var args := PackedStringArray(["--act=6"])
	var director := DirectorScript.new()
	director.read_args(args)
	var read6 := DirectorScript.start_act
	director.free()
	var short := TwoActs.new()
	var short_director := DirectorScript.new()
	var short_map := Node3D.new()
	add_child(short_map)
	short_map.add_child(short_director)
	short_director.setup(short_map, short)
	DirectorScript.start_act = 6
	await short_director.run()
	var short_act: int = short_director.act_index
	var short_ok: bool = short.staged == [2] and short_act == 2
	short_map.queue_free()
	DirectorScript.start_act = 1
	var map1 := await _map(true)
	var acts1: Array = map1.story.acts()
	var titles1 := acts1.map(func(a): return a["title"] if a["title"] is String else "(ending)")
	_check("S1 the garrison's night is six acts, --act=6 starts the last, and a shorter night asked for act 6 plays its last act staged",
		acts1.size() == 6 and read6 == 6 and short_ok, "acts %s, --act=6 read as %d, the two-act night staged %s and ended at act %d" % [titles1, read6, short.staged, short_act])

	# S0 Act I: the night moves (conversations, gatherings, the watch changing
	# at the colonnade), and a man goes to his prayers
	var gideon: Node3D = map1.cast["Gideon"]
	var prayed := [false]
	var ended1 := [false]
	map1.director.act_started.connect(func(index: int, _t: String) -> void:
		if index >= 2:
			ended1[0] = true)
	await _until(func():
		if is_instance_valid(gideon) and StringName(gideon.activity()) == &"pray":
			prayed[0] = true
		return ended1[0], 24000)
	var talk: RefCounted = TalkDirector.of(map1)
	var played: Array = talk.played() if talk != null else []
	var gatherings: Array = GatheringScript.of(map1).history() if GatheringScript.of(map1).has_method("history") else []
	var jory: Node3D = map1.cast["Jory"]
	var colonnade: bool = map1.rota.duty_of(jory) == &"colonnade" and _flat(jory.global_position, map1.marks["colonnade_post"]) < 1.2
	_check("S0 Act I is a night that moves: six conversations or more, the watch changing (Jory on the colonnade for Act II), a man at his prayers",
		ended1[0] and played.size() >= 6 and colonnade and prayed[0],
		"ended %s, conversations %d, gatherings %s, Jory on the colonnade %s, prayed %s, skipped %s" % [ended1[0], played.size(), gatherings, colonnade, prayed[0], map1.director.log_lines])
	await _unload(map1)


func _s2() -> void:
	# S2 Act II: the knife in the dark colonnade under the clouded moon, and
	# the man who saw it
	DirectorScript.start_act = 2
	var map2 := await _map(true)
	var ned: Node3D = map2.cast["Ned"]
	var ned_said := []
	ned.barked.connect(func(t): ned_said.append(t))
	var jory_held: WeakRef = weakref(map2.cast["Jory"])
	var jory_at := [Vector3.INF]
	var cover2 := [-1.0]
	var killed2 := [-1]
	var frame2 := [0]
	await _until(func():
		frame2[0] += 1
		var j: Variant = jory_held.get_ref()
		if killed2[0] < 0 and (j == null or not is_instance_valid(j) or j._knocked_out):
			killed2[0] = frame2[0]
			cover2[0] = float(map2.night.cloud_cover())
		elif killed2[0] < 0:
			# (Where he stands until he falls: the dead man's node goes.)
			jory_at[0] = (j as Node3D).global_position
		return killed2[0] >= 0 and frame2[0] > killed2[0] + 840, 12000)
	var saw2: bool = is_instance_valid(ned) and (ned.state >= 3 or ned_said.any(func(t): return String(t).contains("Murder")))
	var in_colonnade: bool = jory_at[0] != Vector3.INF and _flat(jory_at[0], map2.marks["colonnade_post"]) < 3.0
	_check("S2 Act II: Jory knifed at his post in the colonnade with the moon clouded, and Ned sees it within 14 s",
		killed2[0] >= 0 and in_colonnade and cover2[0] >= 0.9 and saw2,
		"killed at frame %d, where %s, the moon's cloud %.2f, Ned state %d, said %s, skipped %s" % [killed2[0], jory_at[0], cover2[0], ned.state if is_instance_valid(ned) else -1, ned_said, map2.director.log_lines])
	await _unload(map2)


func _s3() -> void:
	# S3 Act III: the cry, the bell, lanterns, and the captain dividing them
	DirectorScript.start_act = 3
	var map3 := await _map(true)
	var osric3: Node3D = map3.cast["Osric"]
	var osric_said := []
	osric3.barked.connect(func(t): osric_said.append(t))
	await _frames(30)
	var fallen3 := _bodies_near(map3.marks["colonnade_post"], 3.0)
	var rung3 := [false]
	for bell in get_tree().get_nodes_in_group(&"alarm_bells"):
		bell.rung.connect(func(_by): rung3[0] = true)
	var lanterns3 := [0]
	var ended3 := [false]
	map3.director.act_started.connect(func(index: int, _t: String) -> void:
		if index >= 4:
			ended3[0] = true)
	await _until(func():
		var lit := 0
		for man in get_tree().get_nodes_in_group(&"guards"):
			if man.get("_hands") != null and man._hands.lantern != null:
				lit += 1
		lanterns3[0] = maxi(lanterns3[0], lit)
		return ended3[0], 7200)
	var groups3 := _groups(map3)
	var grieved3 := osric_said.any(func(t): return String(t).contains("Jory"))
	_check("S3 Act III: Jory lies where he fell, his brother calls his name, the bell rings, men take up lanterns, and the captain divides them: three groups or more, each sent to its own ground",
		ended3[0] and fallen3 >= 1 and grieved3 and rung3[0] and lanterns3[0] >= 2 and groups3.size() >= 3 and groups3.values().all(func(g): return (g as Array).size() >= 2 and (g as Array).size() <= 4),
		"act over %s, Jory's body at his post %s, Osric said %s, bell %s, lanterns %d, groups %s, skipped %s" % [ended3[0], fallen3, osric_said, rung3[0], lanterns3[0], groups3, map3.director.log_lines])
	await _unload(map3)


func _s4() -> void:
	# S4 Act IV: the divided hunt; he moves through the barracks unseen
	DirectorScript.start_act = 4
	var map4 := await _map(true)
	var areas4 := _areas()
	var stray4 := []
	var unseen4 := [0]
	var seen4 := [0]
	var searched4 := {}
	var ended4 := [false]
	var beats4 := []
	map4.director.act_started.connect(func(index: int, _t: String) -> void:
		if index >= 5:
			ended4[0] = true)
	map4.director.beat_started.connect(func(beat: StringName, _scene: Dictionary) -> void:
		var i: Node3D = map4.intruder
		beats4.append([String(beat), i.global_position.snapped(Vector3.ONE * 0.1) if i != null and is_instance_valid(i) else Vector3.INF]))
	await _until(func():
		# (Once Act V begins its own orders are given: nothing more of IV's.)
		if ended4[0]:
			return true
		for man in get_tree().get_nodes_in_group(&"guards"):
			if man == map4.intruder or man._knocked_out:
				continue
			var group := String(man.get_meta(&"hunt_group", &""))
			var spot: Dictionary = man._spot
			if group != "" and not spot.is_empty():
				searched4[group] = int(searched4.get(group, 0)) + (0 if spot.get("counted", false) else 1)
				spot["counted"] = true
				if not (areas4[group] as AABB).grow(0.3).has_point(spot["stand"]):
					stray4.append("%s at %s" % [man.given_name, (spot["stand"] as Vector3).snapped(Vector3.ONE * 0.1)])
		var i: Node3D = map4.intruder
		if i != null and is_instance_valid(i) and (areas4["area_barracks"] as AABB).has_point(i.global_position + Vector3.UP * 0.5):
			var anyone := false
			for man in get_tree().get_nodes_in_group(&"guards"):
				if man != i and not man._knocked_out and bool(man.get("can_see_target")):
					anyone = true
			if anyone:
				seen4[0] += 1
			else:
				unseen4[0] += 1
		return ended4[0], 14400)
	var i4: Node3D = map4.intruder
	var hidden4: bool = i4 != null and is_instance_valid(i4) and _flat(i4.global_position, map4.marks["chapel_hide"]) < 1.5
	_check("S4 Act IV: three groups or more search each its own ground, and he moves through the barracks unseen for 20 s or more, to the chapel",
		ended4[0] and searched4.size() >= 3 and stray4.is_empty() and unseen4[0] >= 1200 and hidden4,
		"act over %s, places searched by group %s, outside their ground %s, in the barracks unseen %.1f s, seen %.1f s, in the chapel %s, skipped %s, beats and where he was %s" % [ended4[0], searched4, stray4.slice(0, 5), unseen4[0] / 60.0, seen4[0] / 60.0, hidden4, map4.director.log_lines, beats4])
	await _unload(map4)


func _s5() -> void:
	# S5 Act V: the barracks group finds him in the chapel; they fight and he
	# is left standing; lightning through the glass
	DirectorScript.start_act = 5
	var map5 := await _map(true)
	var chapel5: AABB = _areas()["area_chapel"]
	var fought_in5 := [0]
	var flashes5 := [0]
	map5.night.flashed.connect(func(): flashes5[0] += 1)
	var ended5 := [false]
	map5.director.act_started.connect(func(index: int, _t: String) -> void:
		if index >= 6:
			ended5[0] = true)
	await _until(func():
		var i: Node3D = map5.intruder
		if i != null and is_instance_valid(i) and chapel5.has_point(i.global_position + Vector3.UP * 0.5):
			for name in ["Osric", "Brand", "Col"]:
				var man: Variant = map5.cast.get(name)
				if man != null and is_instance_valid(man) and not man._knocked_out and man.state == 4:
					fought_in5[0] += 1
					break
		return ended5[0], 14400)
	var beaten5 := ["Osric", "Brand", "Col"].all(func(n): return _beaten(map5, n))
	var standing5: bool = map5.intruder != null and is_instance_valid(map5.intruder) and not map5.intruder.is_dead
	_check("S5 Act V: the barracks group fights him in the chapel, and he is left standing over them, lightning through the glass",
		ended5[0] and fought_in5[0] >= 120 and beaten5 and standing5 and flashes5[0] >= 1,
		"act over %s, fought in the chapel %.1f s, the three beaten %s, he stands %s, flashes %d, skipped %s" % [ended5[0], fought_in5[0] / 60.0, beaten5, standing5, flashes5[0], map5.director.log_lines])
	await _unload(map5)


func _s6() -> void:
	# S6 each ending from Act VI's own start: the captain's door fails him,
	# then over the wall, cut down, or the victor
	for ending in [&"escape", &"overwhelmed", &"victor"]:
		DirectorScript.start_act = 6
		DirectorScript.ending = ending
		var map6 := await _map(true)
		await _frames(30)
		var chapel6: AABB = _areas()["area_chapel"]
		var in_chapel6 := get_tree().get_nodes_in_group(&"bodies").filter(func(b): return chapel6.has_point((b as Node3D).global_position + Vector3.UP * 0.3)).size()
		var rattled6 := [0]
		var door: Node = map6.doors.get("captain_door")
		if door != null:
			door.rattled.connect(func(): rattled6[0] += 1)
		var ended6 := [false]
		map6.director.show_ended.connect(func(): ended6[0] = true)
		await _until(func(): return ended6[0], 12000)
		var outcome6: String = map6.story.ending_outcome()
		_check("S6 the %s ending: the chapel's dead lie in it, the captain's door fails him, and it finishes before its timeout (%s)" % [ending, outcome6],
			ended6[0] and in_chapel6 >= 3 and rattled6[0] >= 1 and map6.director.log_lines.is_empty() and map6.story.ending_done(),
			"ended %s, the chapel's dead in the chapel %d, the door rattled %d, skipped %s, outcome %s" % [ended6[0], in_chapel6, rattled6[0], map6.director.log_lines, outcome6])
		await _unload(map6)

	DirectorScript.ending = &"random"


func _s7() -> void:
	# S7 the whole night unattended: to its end, the weather by the act, each
	# act up through black, the camera on its men
	DirectorScript.start_act = 1
	DirectorScript.ending = &"escape"
	var map7 := await _map(true)
	var editor7: Node = map7.camera.cinema_editor()
	var ended7 := [false]
	var frames7 := [0]
	var acts7 := []
	var weather7 := {}
	var due7 := []
	var seen7 := [0, 0]
	var blind7 := []
	var checked7 := [0]
	map7.director.show_ended.connect(func(): ended7[0] = true)
	map7.director.act_started.connect(func(index: int, _t: String) -> void:
		acts7.append([index, editor7.history().size()])
		due7.append([index, float(editor7._clock) + 0.7]))
	await _until(func():
		frames7[0] += 1
		var history: Array = editor7.history()
		# (Each new shot within two frames of its start, while the camera is on
		# it.)
		while checked7[0] < history.size() - 1 or (checked7[0] < history.size() and frames7[0] % 2 == 0):
			var shot: Dictionary = history[checked7[0]]
			checked7[0] += 1
			var on: Array = (shot["subjects"] as Array).filter(func(m): return m != null and is_instance_valid(m))
			if not on.is_empty():
				seen7[0] += 1
				var saw7: bool = CineVantage.sees(map7.get_world_3d().direct_space_state, map7.camera.global_position, [on[0]])
				seen7[1] += 1 if saw7 else 0
				if not saw7:
					blind7.append([map7.director.act_index, String(map7.director.beat_name), shot["kind"], shot["cause"], shot["how"], String(on[0].get("given_name")),
						(on[0] as Node3D).global_position.snapped(Vector3.ONE * 0.1), map7.camera.global_position.snapped(Vector3.ONE * 0.1)])
		for due in due7.duplicate():
			if float(editor7._clock) >= float(due[1]):
				weather7[due[0]] = snappedf(float(map7.night.rain()), 0.01)
				due7.erase(due)
		return ended7[0], 60000)
	var wanted7 := {1: 0.0, 2: 0.0, 3: 0.6, 4: 0.8, 5: 1.0, 6: 1.0}
	var fits7 := wanted7.keys().all(func(k): return weather7.has(k) and absf(float(weather7[k]) - float(wanted7[k])) <= 0.05)
	var opened7 := acts7.map(func(act): return editor7.history()[act[1]]["how"] if editor7.history().size() > act[1] else &"none")
	_check("S7 the whole night plays to its end (under 16 minutes of game time), each act in its weather (clear, clear, shower, rain, storm, storm) and up through black",
		ended7[0] and fits7 and acts7.size() == 6 and opened7.all(func(h): return h == &"fade"),
		"ended %s after %.0f s, rain as each act opens %s, openings %s, skipped %s" % [ended7[0], frames7[0] / 60.0, weather7, opened7, map7.director.log_lines])
	_check("S8 over the night every shot sees the man it is on as it begins (at most 1 in 20 not)",
		seen7[0] >= 20 and float(seen7[1]) >= 0.95 * float(seen7[0]), "%d of %d shots saw their man; blind [act, beat, kind, cause, how, man, at, camera] %s" % [seen7[1], seen7[0], blind7])
	await _unload(map7)

## The men sent to each ground, by their group: {group: [names]}.
func _groups(map: Node) -> Dictionary:
	var groups := {}

	for name in map.cast:
		var man: Variant = map.cast[name]

		if man == null or not is_instance_valid(man) or man._knocked_out:
			continue

		var group := String(man.get_meta(&"hunt_group", &""))

		if group != "":
			if not groups.has(group):
				groups[group] = []

			groups[group].append(name)

	return groups


## How many bodies lie within `reach` (flat) of `at`.
func _bodies_near(at: Vector3, reach: float) -> int:
	return get_tree().get_nodes_in_group(&"bodies").filter(func(b): return _flat((b as Node3D).global_position, at) < reach).size()


## Every hunt area's box, by its name.
func _areas() -> Dictionary:
	var areas := {}

	for node in get_tree().get_nodes_in_group(&"hunt_area"):
		areas[String(node.name)] = node.get_meta(&"box")

	return areas


## Beaten: dead or down, begging, broken or running from the fight.
func _beaten(map: Node, name: String) -> bool:
	var man: Variant = map.cast.get(name)

	if man == null or not is_instance_valid(man) or man._knocked_out:
		return true

	var squad: RefCounted = man._fighter.squad if man._fighter != null else null
	return bool(man._mercy.pleading) or (squad != null and (squad.status_of(man) in [&"running", &"down"] or squad.will_of(man) == &"broken"))


func _map(show: bool) -> Node:
	MapScript.run_show = show
	var map: Node = MAP.instantiate()
	add_child(map)
	await map.ready_to_show
	return map


func _unload(map: Node) -> void:
	map.queue_free()

	for child in get_children():
		child.queue_free()

	for group in [&"bodies", &"dropped_weapons", &"dropped_lights", &"stray_arrows"]:
		for thing in get_tree().get_nodes_in_group(group):
			thing.queue_free()

	await _frames(3)
	SquadScript.clear_all()
	GarrisonScript.clear_all()


static func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


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
	# (Said as it comes too: the whole night is long.)
	print("[check] " + results[-1])
