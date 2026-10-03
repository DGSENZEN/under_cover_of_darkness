class_name DistrictMap
extends Node3D
## A district's map (the old town's spec, section 3A): its own levels at full
## detail, the rest of the city as massing and as the other built districts'
## proxies, the night, its navmesh (loaded as saved, else baked), its guards
## and the player. Each district's map extends this with its own look
## (_dress), its navmesh's settings (_nav) and its loading words.
##
## Options (after `--`): --vantage=<marker> puts the player at a marker;
## --fps-report=<s> flies a camera along bench_1..bench_8 and prints the
## frame rate; --bake-navmesh bakes the navmesh, saves it and quits.

const LevelLoader := preload("res://scripts/Level/LevelLoader.gd")
const LevelGameplay := preload("res://scripts/Level/LevelGameplay.gd")
const Districts := preload("res://scripts/Level/Districts.gd")
const NavBakerScript := preload("res://scripts/AISystem/NavBaker.gd")
const TemperamentScript := preload("res://scripts/AISystem/Temperament.gd")
const GuardScript := preload("res://scripts/AISystem/Guard.gd")
const SquadScript := preload("res://scripts/AISystem/Squad.gd")
const GarrisonScript := preload("res://scripts/AISystem/Garrison.gd")
const LightProbe := preload("res://scripts/StimuliSystem/LightProbe.gd")
const Props := preload("res://scripts/Interaction/Props.gd")
const LoadingScreen := preload("res://scripts/UI/LoadingScreen.gd")
const NightScript := preload("res://scripts/Night/Night.gd")
const RetroScript := preload("res://scripts/Visual/Retro.gd")
const PLAYER := preload("res://Player.tscn")
const GUARD := preload("res://Guard.tscn")

## Where every level's export is; the city's massing; where each district's
## baked navmesh is kept (<district>.scn).
const LEVELS_DIR := "res://assets/level"
const MASSING := "city_massing"
const NAVMESH_DIR := "res://assets/level/navmesh"
## The same night every run: nobody reseeds the dice as the guards are made.
const SEED := 1947

signal ready_to_play

## This map's district (data/districts.json).
@export var district: StringName = &""
## Where the player arrives (an arrival marker's name), set before the map
## enters the tree; empty: the district's spawn.
var arrival: StringName = &""
## Each level's Level (LevelLoader) and what LevelGameplay made of it, by
## the level's name.
var levels := {}
var made := {}
## The guards by name; the men who followed the player in through a gate,
## by name: their spec (Guard.spec), kept once they are down.
var guards := {}
var visitors := {}
var player: CharacterBody3D = null
var night: Node3D = null
var baker: NavBaker = null
var load_seconds := 0.0
var environment: Environment = null
var _was_rolling := true


func _ready() -> void:
	var started := Time.get_ticks_msec()
	reset_physics_interpolation.call_deferred()
	_was_rolling = TemperamentScript.rolling
	TemperamentScript.rolling = false
	SquadScript.clear_all()
	GarrisonScript.clear_all()
	LightProbe.invalidate()
	var words := _loading_words()
	# (Up from the first frame, saying what is being done.)
	var screen := LoadingScreen.open(self, String(words.get("title", "")))
	var own: Array = Districts.entry(district).get("levels", [])

	for i in own.size():
		var level := String(own[i])
		await screen.step(String(words.get(level, "")), 0.05 + 0.1 * i)
		levels[level] = LevelLoader.load_level(self, LEVELS_DIR.path_join(level), level)
		made[level] = LevelGameplay.build_all(self, levels[level])

	await screen.step(String(words.get(MASSING, "")), 0.3)
	levels[MASSING] = LevelLoader.load_level(self, LEVELS_DIR.path_join(MASSING), MASSING, _massing_left_out())
	made[MASSING] = LevelGameplay.build_all(self, levels[MASSING])

	for other in _proxied():
		for level in Districts.entry(other).get("levels", []):
			LevelLoader.load_proxy(self, LEVELS_DIR.path_join(String(level)))

	await screen.step(String(words.get("night", "")), 0.4)
	_dress()
	_exits()

	baker = NavBakerScript.new()
	baker.bake_on_ready = false
	_nav(baker)

	# (The massing is no guard's: left out of the bake, still solid.)
	for body in (levels[MASSING] as LevelLoader.Level).root.find_children("*", "CollisionObject3D", true, false):
		body.add_to_group(&"nav_ignore")

	await screen.step(String(words.get("navmesh", "")), 0.45)
	screen.creep_to(0.9)
	add_child(baker)
	var baking := OS.get_cmdline_user_args().has("--bake-navmesh")
	var saved := NAVMESH_DIR.path_join(String(district) + ".scn")
	var hash := NavBakerScript.source_hash(_baked_from(), _nav_settings())

	if baking or not baker.load_baked(saved, hash):
		if not baking:
			print("navmesh: %s stale or missing, baking live" % district)

		baker.bake()

	await baker.baked

	if baking:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(NAVMESH_DIR))
		var err := baker.save_baked(saved, hash)
		print("navmesh: %s baked and saved to %s (%s)" % [district, saved, error_string(err)])
		get_tree().quit(0 if err == OK else 1)
		return

	LightProbe.invalidate()
	await screen.step(String(words.get("guards", "")), 0.92)
	GuardScript.randomize_on = false
	seed(SEED)

	for level in levels:
		var d: Dictionary = made[level]
		guards.merge(LevelGameplay.guards(self, levels[level], d["routes"], d["stations"], GUARD))

	GuardScript.randomize_on = true
	await screen.step(String(words.get("player", "")), 0.97)
	_player()

	if _mission() != null:
		CityState.enter(self)

	screen.close()
	load_seconds = (Time.get_ticks_msec() - started) / 1000.0
	_report()
	ready_to_play.emit()

	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--fps-report="):
			_fps_report(float(arg.trim_prefix("--fps-report=")))


func _exit_tree() -> void:
	TemperamentScript.rolling = _was_rolling


## Returns the first of this map's levels' markers named marker_name, or {}.
func marker(marker_name: String) -> Dictionary:
	for level in levels:
		var m: Dictionary = (levels[level] as LevelLoader.Level).get_marker(marker_name)

		if not m.is_empty():
			return m

	return {}


## The Mission holding this map (the game's travel between districts), or
## null when the map is played by itself.
func _mission() -> Node:
	var holder := get_parent()
	return holder if holder != null and holder.has_method("travel") else null


# What a district's map overrides

## The loading screen's words: "title", and a line per step (a level's name,
## "city_massing", "night", "navmesh", "guards", "player"); "" shows none.
func _loading_words() -> Dictionary:
	return {}


## The district's own look, once its levels are loaded: its environment and
## night, its wind and life, its acoustics.
func _dress() -> void:
	pass


## The navmesh's settings for this district (cell, agent, home, bounds...).
func _nav(_baker: NavBaker) -> void:
	pass


# The city's night, for a district's _dress

## The retro night environment (`ambient` its fill) and the moon from
## `toward`, its shadows reaching `shadows` m; environment set, the moon
## returned.
func _moonlit(toward: Vector3, energy: float, shadows: float, ambient: float) -> DirectionalLight3D:
	environment = RetroScript.night_environment(Color(0.34, 0.36, 0.44), ambient)
	# Lift the playable streets as well as moon-facing walls; exposure alone
	# leaves shadowed routes unreadable and washes out the lamps.
	environment.tonemap_exposure = 1.25
	environment.volumetric_fog_density = 0.006
	environment.ssr_enabled = true
	var world := WorldEnvironment.new()
	world.environment = environment
	add_child(world)
	var moon := DirectionalLight3D.new()
	moon.name = "Moon"
	moon.light_color = Color(0.55, 0.65, 0.95)
	moon.light_energy = energy
	moon.shadow_enabled = true
	moon.light_volumetric_fog_energy = 4.0
	moon.directional_shadow_max_distance = shadows
	add_child(moon)
	moon.global_basis = Basis.looking_at(toward.normalized(), Vector3.UP)
	return moon


## The night over the district (Night): `weather` its schedule ([minute,
## state, over s]), clouds drifting with the wind, rain pooling at
## `puddles`, mist in `mist`, the skyline far off; every level's stone made
## wet once it rains.
func _night_over(moon: DirectionalLight3D, skyline: String, weather: Array, puddles: Array, mist: Array) -> void:
	night = NightScript.new()
	night.name = "Night"
	night.moon = moon
	night.environment = environment
	night.seed = SEED
	night.start = &"clear"
	night.skyline = skyline
	var pools: Array[Vector3] = []

	for at in puddles:
		pools.append(at)

	night.puddles = pools
	var boxes: Array[AABB] = []

	for box in mist:
		boxes.append(box)

	night.mist_boxes = boxes
	add_child(night)

	for entry in weather:
		night.to(entry[1], float(entry[2]), float(entry[0]) * 60.0)

	for level in levels:
		for body in (levels[level] as LevelLoader.Level).root.find_children("*", "MeshInstance3D", true, false):
			for i in (body as MeshInstance3D).get_surface_override_material_count():
				var material := (body as MeshInstance3D).get_surface_override_material(i) as StandardMaterial3D

				if material != null:
					night.register_wet(material)


# The rest of the city

## The massing's sectors left out: this district's own, and those of the
## built districts drawn by their proxies.
func _massing_left_out() -> Array:
	var out := []

	for other in Districts.registry()["districts"]:
		var entry := Districts.entry(StringName(other))
		var sector := String(entry.get("massing", ""))

		if sector != "" and (StringName(other) == district or bool(entry.get("proxy", false))):
			out.append(sector)

	return out


## The other built districts this map draws by their proxies.
func _proxied() -> Array:
	var out := []

	for other in Districts.registry()["districts"]:
		if StringName(other) != district and bool(Districts.entry(StringName(other)).get("proxy", false)):
			out.append(StringName(other))

	return out


## What the navmesh is baked from (its levels' and the massing's exports).
func _baked_from() -> Array:
	var out := []

	for level in Districts.entry(district).get("levels", []):
		out.append(LEVELS_DIR.path_join(String(level)))

	out.append(LEVELS_DIR.path_join(MASSING))
	return out


func _nav_settings() -> Dictionary:
	return {"cell": baker.cell_size, "radius": baker.agent_radius, "climb": baker.agent_max_climb, "island": baker.min_island,
		"unreached": baker.drop_unreached, "home": baker.home, "bounds": baker.bake_bounds}


# The ways out

## Each exit: said, and printed, when the player reaches it.
func _exits() -> void:
	for area in get_tree().get_nodes_in_group(&"district_exit"):
		if not is_ancestor_of(area):
			continue

		(area as Area3D).body_entered.connect(func(body: Node3D) -> void:
			if body == player:
				var label := String(area.get_meta(&"label", "somewhere"))
				print("city: exit: %s" % label)

				if player.get("hud") != null:
					player.hud.show_caption("On to %s" % label, 4.0))


# The player

## The player: at his arrival (coming through a gate), at a vantage
## (--vantage=<name>), or at the district's spawn; with the starting kit
## (what he carries through a gate replaces it: CityState.enter).
func _player() -> void:
	var at := _spawn()

	if arrival != &"":
		var m := marker(String(arrival))

		if not m.is_empty():
			at = m["transform"]

	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--vantage="):
			var m := marker(arg.trim_prefix("--vantage="))

			if not m.is_empty():
				at = m["transform"]

	player = PLAYER.instantiate()
	add_child(player)
	player.global_position = at.origin + Vector3.UP * 1.05
	player.rotation.y = at.basis.get_euler().y
	Props.give_blackjack(player)
	Props.give_tools(player)


## The first spawn marker of the district's own levels.
func _spawn() -> Transform3D:
	for level in Districts.entry(district).get("levels", []):
		var found: Array = (levels[String(level)] as LevelLoader.Level).of("spawn")

		if not found.is_empty():
			return found[0]["transform"]

	return Transform3D()


func _report() -> void:
	var mesh: NavigationMesh = baker.navigation_mesh
	var off_mesh: Array[String] = []

	for g in guards.values():
		var at: Vector3 = (g as Node3D).global_position

		if NavigationServer3D.map_get_closest_point(baker.get_navigation_map(), at).distance_to(at) > 1.0:
			off_mesh.append(String((g as Node).name))

	print("city: %s loaded in %.1f s, %d guards (off the navmesh: %s), navmesh %d polygons (%d links, %d unreached dropped)%s" % [district,
		load_seconds, guards.size(), off_mesh, mesh.get_polygon_count() if mesh != null else 0, baker.link_count, baker.unreached_count,
		", from file" if baker.from_file else ""])


## A camera along the benchmark's marks (bench_1 .. bench_8) over `seconds`;
## the frames' average and their 99th percentile printed, then quit.
func _fps_report(seconds: float) -> void:
	var points: Array[Vector3] = []

	for i in range(1, 9):
		var m := marker("bench_%d" % i)

		if not m.is_empty():
			points.append((m["transform"] as Transform3D).origin)

	var camera := Camera3D.new()
	camera.far = 1500.0
	add_child(camera)
	camera.make_current()
	var frames: Array[float] = []
	var t := 0.0

	while t < seconds:
		var delta := get_process_delta_time()
		t += delta
		frames.append(delta)
		var along := clampf(t / seconds, 0.0, 1.0) * (points.size() - 1)
		var i := mini(int(along), points.size() - 2)
		var here := points[i].lerp(points[i + 1], along - i)
		camera.global_position = here
		camera.look_at(here + (points[i + 1] - points[i]).normalized() + Vector3.DOWN * 0.1, Vector3.UP)
		await get_tree().process_frame

	frames = frames.slice(30)
	frames.sort()
	var total := 0.0

	for f in frames:
		total += f

	var p99 := frames[int(frames.size() * 0.99)] if not frames.is_empty() else 0.0
	print("city: fps avg %.1f, p99 %.1f ms, load %.1f s" % [frames.size() / maxf(total, 0.001), p99 * 1000.0, load_seconds])
	get_tree().quit()
