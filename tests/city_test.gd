extends Node3D
## The city on the rock's harbour, played (the harbour plan, Task 15): the map
## loaded as it is played, then: its load, every marker made, the guards'
## reach, the locks, the light, the ways in walked, climbed and swum through
## the controller, the spit, the blowhole, the zones, a chase into the bay,
## the shadow budget.
##   Godot --headless --fixed-fps 60 --path . res://tests/city_test.tscn
##
## The guards stand frozen while the ways in are tried (the checks measure the
## place, not a fight); one is let go for the chase.

const CITY := preload("res://maps/city.tscn")
const LevelLoader := preload("res://scripts/Level/LevelLoader.gd")
const LightProbe := preload("res://scripts/StimuliSystem/LightProbe.gd")
const SoundBus := preload("res://scripts/StimuliSystem/SoundBus.gd")
const LightBudget := preload("res://scripts/Visual/Lights/LightBudget.gd")
const ZonesScript := preload("res://scripts/Level/Zones.gd")

## What each kind of marker is made into (C2): its list in LevelGameplay's
## made, or the group it joins.
const MADE := {"door": "doors", "light": "lights", "water": "water", "ladder": "ladders", "rope": "ropes", "bell": "bells", "route": "routes",
	"station": "stations", "chest": "chests", "prop": "props", "noise_zone": "noise_zones"}
const GROUPS := {"exit": &"district_exit", "secret": &"secret", "probe": &"probe", "objective": &"objective"}
const PICKUPS := ["loot", "key", "tool"]
const MECHANISMS := ["lever", "wheel", "portcullis", "sluice", "hoist", "slider"]

var results: Array[String] = []
## Where the last walk went (every half second): a failed way's detail.
var trace: Array[String] = []
var city: Node3D
var player: CharacterBody3D


## A listener keeping every sound it hears (C11).
class Ear:
	extends RefCounted
	var heard: Array = []

	func hear_sound(event: Dictionary) -> void:
		heard.append(event)


func _ready() -> void:
	var started := Time.get_ticks_msec()
	city = CITY.instantiate()
	add_child(city)
	# (The loading screen from the first frame; what it says while the
	# navmesh bakes; gone once the map is played.)
	var screen: Node = city.get_node_or_null("LoadingScreen")
	var shown := screen != null
	var said := [""]

	while not city.get("player"):
		if screen != null and is_instance_valid(screen) and city.baker != null and not bool(city.baker.is_baked):
			said[0] = String(screen.get("_text"))

		await get_tree().process_frame

	if not city.get("load_seconds"):
		await city.ready_to_play

	player = city.player
	await _seconds(1.5)
	_check("C15 a loading screen shows from the map's first frame, says what it is doing while the navmesh bakes, and is gone once it is played",
		shown and said[0] != "" and not is_instance_valid(screen), "screen %s, while baking \"%s\", gone %s" % [shown, said[0],
			not is_instance_valid(screen)])
	_load_check(started)
	_markers()
	_reach()
	_locks()
	_freeze(true)
	await _probes()
	_sea_gate()
	await _carrack()
	await _roofs()
	await _swim()
	await _spit()
	await _blowhole()
	await _zones()
	await _light_budget()
	await _chase()
	_release_all()
	print("\n==== RESULTS ====")

	for line in results:
		print(line)

	var failed := results.filter(func(r): return r.begins_with("FAIL")).size()
	print("\n%d pass, %d fail" % [results.size() - failed, failed])
	get_tree().quit()


# ---------------------------------------------------------------------------
# C1-C5: the place as loaded
# ---------------------------------------------------------------------------

func _load_check(started: int) -> void:
	var harbour := city.get_node_or_null("city_harbour")
	var massing := city.get_node_or_null("city_massing")
	var seconds := (Time.get_ticks_msec() - started) / 1000.0
	_check("C1 the harbour and the massing load under their own roots; the navmesh bakes; the load takes under 15 s",
		harbour != null and massing != null and bool(city.baker.is_baked) and city.load_seconds < 15.0,
		"roots %s %s, baked %s, the map's load %.1f s (the suite's %.1f s)" % [harbour != null, massing != null, city.baker.is_baked,
			city.load_seconds, seconds])


func _markers() -> void:
	var missing: Array[String] = []

	for district in city.levels:
		var level: LevelLoader.Level = city.levels[district]
		var made: Dictionary = city.made[district]
		var counts := {}

		for m in level.markers:
			counts[m["ucd"]] = int(counts.get(m["ucd"], 0)) + 1

		for ucd in MADE:
			if int(counts.get(ucd, 0)) != (made[MADE[ucd]] as Variant).size():
				missing.append("%s %s: %d markers, %d made" % [district, ucd, int(counts.get(ucd, 0)), (made[MADE[ucd]] as Variant).size()])

		var picks := 0
		var mechs := 0

		for ucd in PICKUPS:
			picks += int(counts.get(ucd, 0))

		for ucd in MECHANISMS:
			mechs += int(counts.get(ucd, 0))

		if picks != (made["pickups"] as Dictionary).size():
			missing.append("%s pickups: %d markers, %d made" % [district, picks, (made["pickups"] as Dictionary).size()])

		if mechs != (made["mechanisms"] as Array).size():
			missing.append("%s mechanisms: %d markers, %d made" % [district, mechs, (made["mechanisms"] as Array).size()])

	for ucd in GROUPS:
		var marked := 0

		for district in city.levels:
			marked += (city.levels[district] as LevelLoader.Level).of(ucd).size()

		if marked != get_tree().get_nodes_in_group(GROUPS[ucd]).size():
			missing.append("%s: %d markers, %d made" % [ucd, marked, get_tree().get_nodes_in_group(GROUPS[ucd]).size()])

	var guards := 0

	for district in city.levels:
		guards += (city.levels[district] as LevelLoader.Level).of("guard").size()

	if guards != city.guards.size():
		missing.append("guards: %d markers, %d made" % [guards, city.guards.size()])

	_check("C2 every marker is made into its node", missing.is_empty(), "; ".join(missing))


func _reach() -> void:
	var map: RID = city.baker.get_navigation_map()
	var short: Array[String] = []

	for name in city.guards:
		var g: Node3D = city.guards[name]
		var at := g.global_position
		var layers := 1
		var agent := g.get_node_or_null("NavigationAgent3D") as NavigationAgent3D

		if agent != null:
			layers = agent.navigation_layers

		if NavigationServer3D.map_get_closest_point(map, at).distance_to(at) > 1.0:
			short.append("%s off the navmesh" % name)
			continue

		var route := g.get("patrol_route") as NodePath

		if route == null or route.is_empty():
			continue

		for point in g.get_node(route).get_children():
			var to: Vector3 = (point as Node3D).global_position
			var path := NavigationServer3D.map_get_path(map, at, to, true, layers)

			if path.is_empty() or path[path.size() - 1].distance_to(to) > 0.5:
				short.append("%s to %s: ends %s" % [name, to.snapped(Vector3.ONE * 0.1), path[path.size() - 1].snapped(Vector3.ONE * 0.1) if not path.is_empty() else "nowhere"])

	_check("C3 every guard stands on the navmesh and can reach every point of his route", short.is_empty(), "; ".join(short))


func _locks() -> void:
	var keys := {}
	var stuck: Array[String] = []

	for district in city.levels:
		for m in (city.levels[district] as LevelLoader.Level).of("key"):
			keys[StringName(String(m["props"].get("key_id", "")))] = true

	for district in city.made:
		var made: Dictionary = city.made[district]

		for things in [made["doors"].values(), made["chests"].values()]:
			for thing in things:
				if not bool(thing.get("locked")):
					continue

				var key := StringName(thing.get("key_id"))

				if not bool(thing.get("pickable")) and not keys.has(key):
					stuck.append("%s (key %s, no pick)" % [thing.name, key])

	_check("C4 every locked door and chest opens: its key is in the level, or it can be picked", stuck.is_empty(), "; ".join(stuck))


func _probes() -> void:
	await _frames(5)
	var wrong: Array[String] = []
	var read: Array[String] = []

	for probe in get_tree().get_nodes_in_group(&"probe"):
		var at: Vector3 = (probe as Node3D).global_position
		var expect := String(probe.get_meta(&"expect", ""))
		var level := LightProbe.light_at(self, at)
		var flame := _flame_reaching(at)
		var ok := false

		match expect:
			"shadow":
				ok = level < 0.2 and flame == null
			"moon":
				ok = level >= 0.3 and flame == null
			"lamp":
				ok = level >= 0.3 and flame != null

		read.append("%s %s %.2f%s" % [probe.name, expect, level, " (%s)" % flame.name if flame != null else ""])

		if not ok:
			wrong.append(read[-1])

	_check("C5 every probe reads what it expects (shadow: no flame, under 0.2 (the night's floor 0.15); moon: 0.3 or more, no flame; lamp: 0.3 or more by a flame)",
		wrong.is_empty(),
		"wrong: %s; all: %s" % ["; ".join(wrong), "; ".join(read)])


## The nearest flame's light whose reach takes in `at` (null if none).
func _flame_reaching(at: Vector3) -> Light3D:
	var best: Light3D = null

	for light in city.find_children("*", "OmniLight3D", true, false):
		var omni := light as OmniLight3D

		if omni.visible and omni.global_position.distance_to(at) < omni.omni_range:
			if best == null or omni.global_position.distance_to(at) < best.global_position.distance_to(at):
				best = omni

	return best


# ---------------------------------------------------------------------------
# C6-C10: the ways in, through the controller
# ---------------------------------------------------------------------------

func _sea_gate() -> void:
	var map: RID = city.baker.get_navigation_map()
	var from := Vector3(-55.0, 2.5, -60.0)
	var to := Vector3(-55.0, 2.5, -89.0)
	var path := NavigationServer3D.map_get_path(map, from, to, true, 1)
	var ends: Vector3 = path[path.size() - 1] if not path.is_empty() else Vector3.INF
	var bars: Node3D = null

	for district in city.made:
		for m in city.made[district]["mechanisms"]:
			if String((m as Node).get_meta(&"kind", "")) == "portcullis":
				bars = m

	var raised := bars != null and String(bars.get_meta(&"state", "")) == "up"
	_check("C8 the Sea Gate's passage is on the navmesh from the Terreiro to the city side; its portcullis is up",
		ends.distance_to(to) < 0.5 and raised, "path ends %s (%.1f m short); portcullis %s, up %s" % [ends.snapped(Vector3.ONE * 0.1),
			ends.distance_to(to), bars != null, raised])


func _carrack() -> void:
	var shrouds := _ladder_through(Vector3(40.0, 11.0, 3.0))
	var hurt := [0.0]

	if shrouds == null:
		_check("C6 the carrack's way: deck, shrouds, top, yard, down onto the wall-walk, through the controller, within 60 s, unhurt", false,
			"no shrouds' climb by the mainmast")
		return

	await _face_ladder(shrouds, 2.0)
	trace.clear()
	# (Up beside the yard, which crosses the shrouds' middle overhead.)
	player.global_position.x -= 0.9
	var start := Time.get_ticks_msec()
	var health: float = player.health
	Input.action_press("move_forward")
	await _until(func(): return player.movement_state == player.MoveState.CLIMBING, 240)
	var climbed: bool = player.movement_state == player.MoveState.CLIMBING
	# (Forward held over the top and onto it, as a player would.)
	await _until(func(): return player.movement_state == player.MoveState.LOCOMOTION and player.is_on_floor() and player.global_position.y > 19.5,
		1800)
	var topped: bool = player.is_on_floor() and player.global_position.y > 19.5
	_release_all()
	# Along the yard (it runs north over the sea wall) to above the walk,
	# then off its side, straight down onto the walk.
	var balanced := await _steer([Vector3(40.0, 0.0, 3.6), Vector3(40.0, 0.0, -7.6)],
		func(): return player.global_position.z < -7.0 and player.global_position.y > 18.5, 1800)
	await _frames(20)
	Input.action_press("move_right")
	await _frames(12)
	_release_all()
	await _until(func(): return player.is_on_floor() and player.global_position.y < 16.0, 300)
	var walked: bool = balanced and player.is_on_floor()
	await _frames(30)
	hurt[0] = health - player.health
	var at := player.global_position
	var seconds := (Time.get_ticks_msec() - start) / 1000.0
	_check("C6 the carrack's way: deck, shrouds, top, yard, down onto the wall-walk, through the controller, within 60 s, unhurt",
		climbed and topped and walked and absf(at.y - 15.4) < 0.6 and hurt[0] <= 0.0 and seconds < 60.0,
		"climbed %s, on the top %s, off the yard %s, at %s, hurt %.0f, %.0f s; went %s" % [climbed, topped, walked, at.snapped(Vector3.ONE * 0.1), hurt[0],
			seconds, " > ".join(trace.slice(0, 16))])


func _roofs() -> void:
	var vine := _ladder_through(Vector3(-137.6, 8.0, -5.75))
	var hurt := [0.0]

	if vine == null:
		_check("C7 the roofs' way: up casa_d's vine and over its roof onto the wall-walk, through the controller, unhurt", false, "no vine")
		return

	await _face_ladder(vine, 2.5)
	trace.clear()
	var health: float = player.health
	Input.action_press("move_forward")
	await _until(func(): return player.movement_state == player.MoveState.CLIMBING, 240)
	var climbed: bool = player.movement_state == player.MoveState.CLIMBING
	await _until(func(): return player.movement_state == player.MoveState.LOCOMOTION and player.is_on_floor() and player.global_position.y > 15.5,
		1800)
	var roofed: bool = player.is_on_floor() and player.global_position.y > 15.5

	_release_all()
	# (Over a merlon, not through a crenel: one is 0.9 m, the thief 1.0 m.)
	var walked := await _steer([Vector3(-139.0, 0.0, -13.0), Vector3(-140.5, 0.0, -19.6), Vector3(-140.5, 0.0, -22.0)],
		func(): return player.global_position.z < -21.0 and player.global_position.y < 15.2, 1800)
	await _frames(30)
	hurt[0] = health - player.health
	var at := player.global_position
	_check("C7 the roofs' way: up casa_d's vine and over its roof onto the wall-walk, through the controller, unhurt",
		climbed and roofed and walked and absf(at.y - 15.4) < 0.6 and hurt[0] <= 0.0,
		"climbed %s, on the roof %s, through the crenel %s, at %s, hurt %.0f; went %s" % [climbed, roofed, walked, at.snapped(Vector3.ONE * 0.1), hurt[0],
			" > ".join(trace.slice(0, 16))])


func _swim() -> void:
	# Down the water stair into the bay, round the carrack, through the Nasrid
	# gate and up the slipway.
	_put(Vector3(-55.0, 3.5, -2.0), PI)
	var swam := [false]
	var watch := func() -> bool:
		swam[0] = swam[0] or player.movement_state == player.MoveState.SWIMMING
		return player.global_position.z < -31.0 and player.global_position.y > 2.0

	var out := await _steer([Vector3(-55.0, 0.0, 16.0), Vector3(62.0, 0.0, 16.0), Vector3(71.0, 0.0, 8.0), Vector3(71.0, 0.0, -7.0),
		Vector3(71.0, 0.0, -20.0), Vector3(71.0, 0.0, -36.0)], watch, 10800)
	_check("C9 the bay is swum: off the water stair the player swims, and reaches the Nasrid gate's slip", swam[0] and out,
		"swam %s, out on the slip %s, at %s; went %s" % [swam[0], out, player.global_position.snapped(Vector3.ONE * 0.1), " > ".join(trace.slice(0, 16))])


func _spit() -> void:
	# Along the west spit's crest toward the fort.
	_put(Vector3(-176.0, 6.0, 65.5), 0.0)
	# (Landed, not still falling on the floor flag the last place left.)
	await _frames(5)
	await _until(func(): return player.is_on_floor() and absf(player.velocity.y) < 0.5, 240)
	await _frames(5)
	var surface := String(player.call(&"_surface_name"))
	var walked := await _steer([Vector3(-156.5, 0.0, 93.0)], func(): return Vector2(player.global_position.x + 156.5, player.global_position.z - 93.0).length() < 1.0,
		900)
	var on_rock := player.is_on_floor() and player.global_position.y > 1.0
	_check("C10 the west spit is solid rock underfoot (stone), and walked along", surface == "stone" and walked and on_rock,
		"surface %s, walked %s, at %s" % [surface, walked, player.global_position.snapped(Vector3.ONE * 0.1)])


# ---------------------------------------------------------------------------
# C11-C14: the air, the zones, the chase, the shadows
# ---------------------------------------------------------------------------

func _blowhole() -> void:
	var roar: Node = null

	for z in city.made["city_harbour"]["noise_zones"]:
		if z is Node and (z as Node).name == "blowhole_roar":
			roar = z

	if roar == null:
		_check("C11 the blowhole's roar hides a noise in its zone, not one outside", false, "no blowhole")
		return

	# (Between its roars, then one now.)
	await _until(func(): return not bool(roar.get("roaring")), 900)
	var ear := Ear.new()
	SoundBus.add_listener(ear)
	var inside := Vector3(230.0, 3.0, 10.0)
	var outside := Vector3(230.0, 3.0, 40.0)
	SoundBus.emit_sound(inside, 60.0, null, &"test")
	var quiet_reach: float = ear.heard[-1]["range"]
	roar.call(&"roar")
	SoundBus.emit_sound(inside, 60.0, null, &"test")
	var roared_reach: float = ear.heard[-1]["range"]
	SoundBus.emit_sound(outside, 60.0, null, &"test")
	var beside_reach: float = ear.heard[-1]["range"]
	SoundBus.remove_listener(ear)
	_check("C11 the blowhole's roar hides a noise: a 60 dB noise carries 12 m outside its zone and not inside it while it roars",
		quiet_reach >= 12.0 and roared_reach < 12.0 and beside_reach >= 12.0,
		"inside, quiet %.1f m; roaring %.1f m; outside %.1f m" % [quiet_reach, roared_reach, beside_reach])


func _zones() -> void:
	var zones: Node = get_tree().get_first_node_in_group(&"level_zones")
	var wrong: Array[String] = []

	for case in [["terreiro", Vector3(-55.0, 3.4, -40.0), "outside"], ["shipyard", Vector3(58.6, 3.4, -45.0), "indoors"],
			["customs", Vector3(2.0, 3.4, -20.0), "indoors"], ["cave", Vector3(230.0, 2.6, 10.0), "cellar"]]:
		_put(case[1], 0.0)
		# (Eased in: a twentieth of the way left every three EASEs.)
		await _seconds(ZonesScript.EASE * 4.0)
		var mid: Color = zones.look()["mid"] if zones != null else Color.BLACK
		var want: Color = ZonesScript.GRADES[case[2]]["mid"]

		if zones == null or zones.current != case[2] or Vector3(mid.r - want.r, mid.g - want.g, mid.b - want.b).length() > 0.05:
			wrong.append("%s: %s, mid %s" % [case[0], zones.current if zones != null else "no zones", mid])

	_check("C12 each zone's grade eases in with the camera in it (terreiro, shipyard, customs, cave)", wrong.is_empty(), "; ".join(wrong))


func _light_budget() -> void:
	var most := 0
	var where := Vector3.ZERO

	for i in range(1, 9):
		var m: Dictionary = city.marker("bench_%d" % i)

		if m.is_empty():
			continue

		_put((m["transform"] as Transform3D).origin, 0.0)
		await _seconds(0.6)

		if LightBudget.shadowed() > most:
			most = LightBudget.shadowed()
			where = player.global_position

	_check("C14 no more than six lights cast shadows at once anywhere on the benchmark path", most <= LightBudget.SHADOWS,
		"most %d (at %s)" % [most, where.snapped(Vector3.ONE * 0.1)])


func _chase() -> void:
	# Inigo after the thief on the quay; the thief dives off into the bay.
	var g: CharacterBody3D = city.guards.get("Inigo")

	if g == null:
		_check("C13 a guard chasing the player into the bay never walks its bed", false, "no Inigo")
		return

	_freeze(false, g)
	_put(g.global_position + Vector3(0.0, 0.5, 2.5), PI)
	await _frames(10)
	g.call(&"_engage", player)
	await _seconds(1.0)
	_put(Vector3(g.global_position.x, 0.2, 30.0), PI)
	var lowest := INF
	var swam := false

	for i in 1200:
		await get_tree().physics_frame
		lowest = minf(lowest, g.global_position.y)
		swam = swam or String(g.call(&"activity")) in ["swim", "tread"] if g.has_method("activity") else swam

	var state := int(g.get("state"))
	_check("C13 a guard chasing the player into the bay never walks its bed: in 20 s he swims after him or searches the quay",
		lowest > -2.0 and (swam or state >= 2), "lowest %.1f, swam %s, alert %d, at %s" % [lowest, swam, state, g.global_position.snapped(Vector3.ONE * 0.1)])
	_freeze(true)


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

## The climb (ladder, shrouds, vine) whose box holds `point`.
func _ladder_through(point: Vector3) -> Area3D:
	for district in city.made:
		for volume in city.made[district]["ladders"]:
			var box := ((volume as Area3D).get_child(0) as CollisionShape3D).shape as BoxShape3D
			var local := (volume as Area3D).global_transform.affine_inverse() * point

			if absf(local.x) <= box.size.x * 0.5 and absf(local.y) <= box.size.y * 0.5 and absf(local.z) <= box.size.z * 0.5:
				return volume

	return null


## You on the floor at a climb's foot, a step out from it, facing into it.
func _face_ladder(volume: Area3D, floor_y: float) -> void:
	var box := ((volume.get_child(0) as CollisionShape3D).shape as BoxShape3D)
	var into := -volume.global_basis.z
	into.y = 0.0
	into = into.normalized()
	# (A climb that is a deep box, the shrouds': stood in it, just inside its
	# front; a thin one, a vine's or a ladder's: a step out in front of it.)
	var half := box.size.z * 0.5
	var at := volume.global_position - into * (half - 0.5 if half > 0.6 else half + 0.45)
	_put(Vector3(at.x, floor_y + 1.0, at.z), atan2(-into.x, -into.z))
	await _until(func(): return player.is_on_floor(), 120)
	await _frames(10)


## Walks you through `targets` (only their x and z: facing each in turn as you
## go, as a player aims), until `done` or `max_frames`: whether done.
func _steer(targets: Array, done: Callable, max_frames: int) -> bool:
	var next := 0
	var moved := [Vector3.INF]
	trace.clear()
	Input.action_press("move_forward")

	for i in max_frames:
		await _stuck_jump(moved, i)

		if i % 30 == 0:
			trace.append("%s %d" % [player.global_position.snapped(Vector3.ONE * 0.1), player.movement_state])

		if done.call():
			_release_all()
			return true

		var at := player.global_position
		var target: Vector3 = targets[next]
		var flat := Vector2(target.x - at.x, target.z - at.z)

		if flat.length() < 0.6 and next < targets.size() - 1:
			next += 1
			target = targets[next]
			flat = Vector2(target.x - at.x, target.z - at.z)

		if flat.length() > 0.05:
			player.rotation.y = atan2(-flat.x, -flat.y)

		await get_tree().physics_frame

	_release_all()
	print("TRACE ", " > ".join(trace))
	return false


## Forward held but going nowhere these frames: a player jumps (a mantle
## over what stops him, a merlon, a ledge).
func _stuck_jump(moved: Array, i: int) -> void:
	if i % 20 == 0:
		var at := player.global_position

		if moved[0] != Vector3.INF and Vector2(at.x - moved[0].x, at.z - moved[0].z).length() < 0.1 and player.is_on_floor():
			Input.action_press("jump")
			await get_tree().physics_frame
			Input.action_release("jump")

		moved[0] = at


## You at `at` (your body's middle), facing `yaw`, still.
func _put(at: Vector3, yaw: float) -> void:
	_release_all()
	player.movement_state = player.MoveState.LOCOMOTION
	player.current_move = null
	player.velocity = Vector3.ZERO
	player.global_position = at
	player.rotation.y = yaw
	player.get_node("Neck").rotation.x = 0.0
	player.reset_physics_interpolation()


## Every guard held still (or let go); `but` is left as he is.
func _freeze(on: bool, but: Node = null) -> void:
	for name in city.guards:
		var g: Node = city.guards[name]

		if g != but:
			g.set_physics_process(not on)
			g.set_process(not on)

	if but != null:
		but.set_physics_process(true)
		but.set_process(true)


func _release_all() -> void:
	for a in ["move_forward", "move_back", "move_left", "move_right", "jump", "sprint", "crouch", "frob"]:
		if InputMap.has_action(a):
			Input.action_release(a)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _seconds(s: float) -> void:
	await _frames(int(s * Engine.physics_ticks_per_second))


func _until(cond: Callable, max_frames: int) -> void:
	for i in max_frames:
		if cond.call():
			return

		if i % 30 == 0 and player != null:
			trace.append("u%s %d" % [player.global_position.snapped(Vector3.ONE * 0.1), player.movement_state])

		await get_tree().physics_frame


func _check(test_name: String, ok: bool, detail: String) -> void:
	results.append("%s  %s   [%s]" % ["PASS" if ok else "FAIL", test_name, detail])
