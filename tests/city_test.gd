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
const Layers := preload("res://scripts/Visual/Layers.gd")
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
	var filled := [-1.0, -1.0]

	while not city.get("player"):
		if screen != null and is_instance_valid(screen) and city.baker != null and not bool(city.baker.is_baked):
			filled[0] = float(screen.get("fraction")) if filled[0] < 0.0 else filled[0]
			filled[1] = float(screen.get("fraction"))

		await get_tree().process_frame

	if not city.get("load_seconds"):
		await city.ready_to_play

	player = city.player
	await _seconds(1.5)
	_check("C15 a loading screen shows from the map's first frame, its rule moving on while the navmesh bakes, and is gone once it is played",
		shown and filled[1] > filled[0] and not is_instance_valid(screen), "screen %s, the rule while baking %.2f to %.2f, gone %s" % [shown,
			filled[0], filled[1], not is_instance_valid(screen)])
	_load_check(started)
	# (--only=<step>: that step alone, after the load's checks.)
	var only := ""

	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--only="):
			only = arg.trim_prefix("--only=")

	var steps := [["markers", _markers], ["douse", _douse], ["reach", _reach], ["locks", _locks], ["freeze", _freeze.bind(true)], ["probes", _probes],
		["sea_gate", _sea_gate], ["carrack", _carrack], ["roofs", _roofs], ["swim", _swim], ["spit", _spit], ["blowhole", _blowhole],
		["zones", _zones], ["light_budget", _light_budget], ["chase", _chase], ["holes", _holes], ["loose", _loose], ["roofed", _roofed], ["distance", _distance]]

	for step in steps:
		if only == "" or step[0] == only or step[0] == "freeze":
			await (step[1] as Callable).call()

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


## C16: a light marked dousable (its marker's douse, true by default) is
## found by the hand (its Reach) and known to the guards (the "lights" group,
## their relighting rounds); one marked not, neither. (A glow or a window's
## shaft is no flame: not counted.)
func _douse() -> void:
	var wrong: Array[String] = []
	var flames := 0

	for district in city.levels:
		var made: Dictionary = city.made[district]

		for m in (city.levels[district] as LevelLoader.Level).of("light"):
			var node: Variant = made["lights"].get(String(m["name"]))

			if node == null or not is_instance_valid(node) or node.get("can_douse") == null:
				continue

			flames += 1
			var marked := bool(m["props"].get("douse", true))
			var reach: bool = (node as Node).get_node_or_null("Reach") != null
			var known: bool = (node as Node).is_in_group(&"lights")

			if bool(node.get("can_douse")) != marked or reach != marked or known != marked:
				wrong.append("%s (%s, marked %s): douses %s, reach %s, rounds %s" % [m["name"], m["props"].get("kind", ""), marked,
					node.get("can_douse"), reach, known])

	_check("C16 every flame marked dousable is found by the hand and on the guards' rounds; one marked not, neither",
		flames > 0 and wrong.is_empty(), "%d flames; %s" % [flames, "; ".join(wrong.slice(0, 8))])


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
		swam = swam or _afloat(g)

	var state := int(g.get("state"))
	# (Engaged, he is in combat from the first frame: searching is a choice
	# he made, combat on the quay is not one.)
	_check("C13 a guard chasing the player into the bay never walks its bed: in 20 s he swims after him or searches the quay",
		lowest > -2.0 and (swam or state == SEARCHING), "lowest %.1f, swam %s, alert %d, at %s" % [lowest, swam, state,
			g.global_position.snapped(Vector3.ONE * 0.1)])

	# The thief swims off, far out in the open sea and out of his sight (the
	# sea is a swim region to its edge, z 420): he gives him up and searches
	# on, place to place (never treading round one spot he cannot reach),
	# and does not stay in the water.
	_put(Vector3(g.global_position.x + 120.0, 0.2, 400.0), PI)
	var gave_up := -1.0
	var ashore := -1.0
	var from := g.global_position
	var wandered := 0.0
	var timeline: Array[String] = []

	for i in 60 * 90:
		await get_tree().physics_frame
		lowest = minf(lowest, g.global_position.y)
		wandered = maxf(wandered, Vector2(g.global_position.x - from.x, g.global_position.z - from.z).length())

		if gave_up < 0.0 and int(g.get("state")) <= SEARCHING:
			gave_up = i / 60.0

		ashore = -1.0 if _afloat(g) else (i / 60.0 if ashore < 0.0 else ashore)

		if i % 600 == 0:
			timeline.append("%ds %s %d %s" % [i / 60, String(g.call(&"activity")), int(g.get("state")), g.global_position.snapped(Vector3.ONE)])

	_check("C13b a guard whose thief swims off out of sight gives him up, searches on (4 m or more from where he lost him) and is out of the water (for good) within 90 s, never walking the bed",
		gave_up >= 0.0 and wandered >= 4.0 and ashore >= 0.0 and lowest > -2.0, "gave up at %.0f s, went %.1f m, ashore since %.0f s, lowest %.1f; %s" % [gave_up,
			wandered, ashore, lowest, ", ".join(timeline)])
	_freeze(true)


## The guards' alert at which a hunt is searching, not fighting (Guard.Alert).
## The built front of the harbour (x0, z0, x1, z1), looked under from these
## heights for a hole a man could drop through.
const FRONT := [-200.0, -80.0, 160.0, 10.0]
const UNDER := [4.0, 7.5]


# ---------------------------------------------------------------------------
# C17-C18: nowhere to fall out of the world
# ---------------------------------------------------------------------------

func _holes() -> void:
	var space := get_world_3d().direct_space_state
	var world: Rect2 = city.WORLD
	var void_at: Array[String] = []
	var x := world.position.x + 1.0

	while x < world.end.x:
		var z := world.position.y + 1.0

		while z < world.end.y:
			if _floor_under(space, Vector3(x, 400.0, z)) == null:
				void_at.append("(%d, %d)" % [x, z])

			z += 2.0

		x += 2.0

	# Walking out any way, he meets the world's wall (at the sea's surface, a
	# man's height over the land, high over the rock).
	var open: Array[String] = []
	var middle := world.get_center()

	for out in [Vector3.LEFT, Vector3.RIGHT, Vector3.FORWARD, Vector3.BACK]:
		for y in [0.5, 60.0, 180.0]:
			var edge := Vector3(middle.x + out.x * (world.size.x * 0.5 - 6.0), y, middle.y + out.z * (world.size.y * 0.5 - 6.0))
			var q := PhysicsRayQueryParameters3D.create(edge, edge + out * 20.0, 1)

			if space.intersect_ray(q).is_empty():
				open.append("%s at %d" % [out, y])

	_check("C17 the world is closed: a wall round it every way, and under any point inside it the ground (a ray down every 2 m)",
		void_at.is_empty() and open.is_empty(), "void at %d points %s; open %s" % [void_at.size(), ", ".join(void_at.slice(0, 12)), open])
	var holes: Array[String] = []

	for h in UNDER:
		x = FRONT[0] + 0.5

		while x < FRONT[2]:
			var z := FRONT[1] + 0.5

			while z < FRONT[3]:
				var at := Vector3(x, h, z)

				if _open_air(space, at) and _floor_under(space, at) == null:
					holes.append("(%.1f, %.1f, %.1f)" % [x, h, z])

				z += 1.0

			x += 1.0

	_check("C18 nowhere on the harbour's built front can a man drop through: from 4 and 7.5 m up, wherever there is room, a floor or the water's bed is under him",
		holes.is_empty(), "%d holes: %s" % [holes.size(), ", ".join(holes.slice(0, 16))])
	# The slipway runs down between the floors beside it: walled both sides
	# (it once ran under 0.2 m floors over nothing).
	var open_sides: Array[String] = []
	var z := -31.5

	# (Where the ramp is a man's height under the floors beside it.)
	while z < -26.0:
		var ramp_y := 2.5 - 4.5 * (z + 34.0) / 8.0

		for side in [-1.0, 1.0]:
			var from := Vector3(71.0, ramp_y + 1.0, z)
			var q := PhysicsRayQueryParameters3D.create(from, from + Vector3(side * 6.0, 0.0, 0.0), 1)
			var hit := space.intersect_ray(q)

			if hit.is_empty() or absf(hit["position"].x - 71.0) > 4.5:
				open_sides.append("z %.1f side %d" % [z, side])

		z += 0.5

	_check("C18b the slipway is walled both sides all the way down (no way under the floors beside it)", open_sides.is_empty(), ", ".join(open_sides))


# ---------------------------------------------------------------------------
# C19: loose things
# ---------------------------------------------------------------------------

func _loose() -> void:
	var level = city.levels["city_harbour"]
	var bodies: Array = level.loose
	var heavy: Array[String] = []
	var moved: Array[String] = []
	var start := {}

	for b in bodies:
		start[b] = (b as Node3D).global_position

		if not (b is RigidBody3D) or (b as RigidBody3D).mass > float(player.frob.max_carry_mass):
			heavy.append(String((b as Node).name))

	# Woken and left a while: each rests where it was laid (nothing through
	# a table or a floor, nothing thrown off by its neighbours).
	for b in bodies:
		(b as RigidBody3D).sleeping = false

	await _seconds(3.0)

	for b in bodies:
		var d := (b as Node3D).global_position.distance_to(start[b])

		if d > 0.25:
			moved.append("%s %.2f m" % [(b as Node).name, d])

	_check("C19 loose things lie about to be taken: 40 or more bodies a man can carry, each resting where it was laid when woken",
		bodies.size() >= 40 and heavy.is_empty() and moved.is_empty(), "%d bodies; too heavy %s; moved %s" % [bodies.size(), heavy, moved.slice(0, 12)])


# ---------------------------------------------------------------------------
# C20: what stands under a roof spares the moon's shadow pass
# ---------------------------------------------------------------------------

func _roofed() -> void:
	var root: Node3D = (city.levels["city_harbour"] as LevelLoader.Level).root
	var moon := city.find_child("Moon", true, false) as DirectionalLight3D
	var wrong: Array[String] = []

	# Under roofs: the naves' vaults and inner arches (merged a cell at a
	# time), the office's desk, the yard's forge, a crate in the customs hall
	# (by its box).
	var vaults: Array = root.find_children("merged_shipyard_roofed_*", "", true, false)
	var arcades: Array = root.find_children("merged_shipyard_open_*", "", true, false)
	var under: Array[String] = ["desk_writing_001", "forge_001", "crate_stack_005"]

	for node in vaults:
		under.append(String(node.name))

	for name in under:
		for mesh in _drawn(root, name):
			if mesh.layers != Layers.ROOFED:
				wrong.append("%s under a roof on %d" % [mesh.name, mesh.layers])

	# In the moonlight: the naves' piers and east arcade, a quay's bollard,
	# the king's beam in the open loggia, crates stacked out of doors.
	var open: Array[String] = ["bollard_001", "kings_beam_001", "crate_stack_001"]

	for node in arcades:
		open.append(String(node.name))

	for name in open:
		for mesh in _drawn(root, name):
			if mesh.layers & Layers.ROOFED:
				wrong.append("%s in the open on the roofed layer" % mesh.name)

	var counted := vaults.size() + arcades.size() + _drawn(root, "bollard_001").size()
	_check("C20 what stands under a roof is drawn on its own layer, which the moon casts no shadow from; what stands in the open casts",
		moon != null and moon.shadow_caster_mask & Layers.ROOFED == 0 and moon.shadow_caster_mask & Layers.WORLD != 0 and counted >= 2 and wrong.is_empty(),
		"%d meshes looked at; %s" % [counted, wrong])


# ---------------------------------------------------------------------------
# C21-C22: the distance
# ---------------------------------------------------------------------------

func _distance() -> void:
	var env: Environment = city.environment
	var sky := env.sky.sky_material as ShaderMaterial if env.sky != null else null
	var far: Node = city.distance
	var counts: Dictionary = far.counts() if far != null else {}
	var massing = city.levels["city_massing"]
	var colossus: Node = massing.root.find_child("mass_colossus_001", true, false)
	var farland: Node = massing.root.find_child("terrain_far_land", true, false)
	_check("C21 the distance hazes, the far land and the colossus stand round the rock, the comet crosses the sky, torches and the balefire burn far off, mist lies low, chimneys smoke",
		env.fog_enabled and env.fog_mode == Environment.FOG_MODE_DEPTH and env.fog_depth_begin >= 60.0 and env.fog_sky_affect == 0.0
		and sky != null and float(sky.get_shader_parameter("comet")) > 0.0 and colossus != null and farland != null
		and int(counts.get("torches", 0)) >= 15 and bool(counts.get("balefire", false)) and int(counts.get("mist", 0)) >= 10
		and int(counts.get("smoke", 0)) >= 10 and int(counts.get("wisps", 0)) >= 5,
		"fog %s depth %s; comet %s; colossus %s; far land %s; %s" % [env.fog_enabled, env.fog_mode == Environment.FOG_MODE_DEPTH,
			sky.get_shader_parameter("comet") if sky != null else null, colossus != null, farland != null, counts])

	# A corpse-light stared at goes out, and comes back after a while.
	var eye := Camera3D.new()
	city.add_child(eye)
	eye.current = true
	var low := 1.0

	for i in int((far.STARE + 1.5) * Engine.physics_ticks_per_second):
		var at: Vector3 = far.wisp(0)[0]
		eye.global_position = at + Vector3(0.0, 2.0, 30.0)
		eye.look_at(at, Vector3.UP)
		await get_tree().process_frame
		low = minf(low, float(far.wisp(0)[1]))

	eye.global_position += Vector3(0.0, 400.0, 0.0)
	eye.look_at(eye.global_position + Vector3(0.0, 0.0, -1.0), Vector3.UP)

	for i in int((far.GONE + 6.0) * Engine.physics_ticks_per_second):
		await get_tree().process_frame

	var back := float(far.wisp(0)[1])
	eye.queue_free()
	_check("C22 a corpse-light looked at too long goes out, and drifts back after a while", low < 0.1 and back > 0.9, "lowest %.2f, then %.2f" % [low, back])


## The drawn meshes of the piece named `name` (itself or under it).
func _drawn(root: Node, name: String) -> Array[GeometryInstance3D]:
	var out: Array[GeometryInstance3D] = []
	var node := root.find_child(name, true, false)

	if node is GeometryInstance3D:
		out.append(node)

	if node != null:
		for child in node.find_children("*", "GeometryInstance3D", true, false):
			out.append(child)

	return out


## The first thing under `at` (layer 1), or null.
func _floor_under(space: PhysicsDirectSpaceState3D, at: Vector3) -> Variant:
	var q := PhysicsRayQueryParameters3D.create(at, Vector3(at.x, -120.0, at.z), 1)
	var hit := space.intersect_ray(q)
	return null if hit.is_empty() else hit["position"]


## `at` is in the open: inside nothing solid, under no rock.
func _open_air(space: PhysicsDirectSpaceState3D, at: Vector3) -> bool:
	var p := PhysicsPointQueryParameters3D.new()
	p.position = at
	p.collision_mask = 1

	if not space.intersect_point(p, 1).is_empty():
		return false

	var from := Vector3(at.x, 400.0, at.z)

	# (The terrain's trimesh is met only from above: what is over the point,
	# coming down from the sky.)
	for i in 12:
		if from.y <= at.y + 0.05:
			break

		var q := PhysicsRayQueryParameters3D.create(from, at, 1)
		q.hit_from_inside = false
		var over := space.intersect_ray(q)

		if over.is_empty():
			break

		if String((over["collider"] as Node).name).begins_with("terrain_"):
			return false

		from = Vector3(at.x, over["position"].y - 0.02, at.z)

	return true


const SEARCHING := 3


## Whether a guard is afloat (swimming or treading water: GuardWater).
func _afloat(g: Node) -> bool:
	return String(g.call(&"activity")) in ["swim", "tread"]


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
