extends Node3D
## Loads harbour and city massing, instantiates marker gameplay and bakes navigation.
## The level roots own imported geometry; this map owns player/guard spawns and night setup.
## Run res://maps/city.tscn; scene options and diagnostics are in docs/systems/development.md.

const LevelLoader := preload("res://scripts/Level/LevelLoader.gd")
const LevelGameplay := preload("res://scripts/Level/LevelGameplay.gd")
const NavBakerScript := preload("res://scripts/AISystem/NavBaker.gd")
const NightScript := preload("res://scripts/Night/Night.gd")
const RetroScript := preload("res://scripts/Visual/Retro.gd")
const WindScript := preload("res://scripts/Visual/Wind.gd")
const WildlifeScript := preload("res://scripts/Visual/Wildlife.gd")
const TemperamentScript := preload("res://scripts/AISystem/Temperament.gd")
const GuardScript := preload("res://scripts/AISystem/Guard.gd")
const SquadScript := preload("res://scripts/AISystem/Squad.gd")
const GarrisonScript := preload("res://scripts/AISystem/Garrison.gd")
const LightProbe := preload("res://scripts/StimuliSystem/LightProbe.gd")
const Props := preload("res://scripts/Interaction/Props.gd")
const Sfx := preload("res://scripts/Audio/Sfx.gd")
const LoadingScreen := preload("res://scripts/UI/LoadingScreen.gd")
const PLAYER := preload("res://Player.tscn")
const GUARD := preload("res://Guard.tscn")

const DISTRICTS := ["res://assets/level/city_harbour", "res://assets/level/city_massing"]
## The loading screen's words, yours to write: its title, and a line for
## each step of the load ("" shows none).
const LOADING := {
	"title": "",
	"city_harbour": "",
	"city_massing": "",
	"night": "",
	"navmesh": "",
	"guards": "",
	"player": "",
}
## The moon: from the south-south-west, over the sea; its shadows this far.
const MOON_TOWARD := Vector3(0.3, -0.57, -0.77)
const MOON_ENERGY := 0.36
const SHADOW_DISTANCE := 120.0
const AMBIENT := 0.40
## The navmesh over the land and 25 m of water round it (the guards'), its
## agent the garrison's.
const BAKE_BOUNDS := AABB(Vector3(-240.0, -12.0, -130.0), Vector3(520.0, 60.0, 360.0))
const AGENT_RADIUS := 0.4
## Its cells (the garrison's 0.1 over a harbour trips the engine's check on
## a bake's size; the radius still whole cells); its home, where the floor
## kept is reached from (the Terreiro).
const CELL := 0.2
const HOME := Vector3(-55.0, 2.5, -30.0)
const MAX_CLIMB := 0.3
const MIN_ISLAND := 1.2
## The night's weather: [minute, state, over s].
const WEATHER := [[4.0, &"cloudy", 60.0], [9.0, &"drizzle", 45.0], [13.0, &"shower", 30.0], [16.0, &"cloudy", 60.0]]
const SEED := 1947
## Where rain pools (on the Terreiro and the quays); where mist lies (the
## harbour's water).
const PUDDLES := [Vector3(-70, 2.52, -30), Vector3(-40, 2.52, -50), Vector3(-55, 2.52, -14), Vector3(-82, 2.52, -8), Vector3(-130, 2.52, -3),
	Vector3(-95, 2.52, -3), Vector3(8, 2.52, -3), Vector3(128, 2.52, -24)]
const MIST := [AABB(Vector3(-190.0, -0.5, 0.0), Vector3(355.0, 3.0, 200.0))]
## Bats round the golden tower's lantern.
const TOWER_BATS := Vector3(92.0, 37.0, 203.0)
const SKYLINE := "res://assets/sky/skyline_city.png"

signal ready_to_play

## Each district's Level (LevelLoader) by its folder's name.
var levels := {}
var made := {}
var guards := {}
var player: CharacterBody3D = null
var night: Node3D = null
var baker: NavigationRegion3D = null
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
	# (Up from the first frame, saying what is being done.)
	var screen := LoadingScreen.open(self, String(LOADING["title"]))

	for i in DISTRICTS.size():
		var district: String = (DISTRICTS[i] as String).get_file()
		await screen.step(String(LOADING.get(district, "")), 0.05 + 0.25 * i)
		levels[district] = LevelLoader.load_level(self, DISTRICTS[i], district)
		made[district] = LevelGameplay.build_all(self, levels[district])

	await screen.step(String(LOADING["night"]), 0.4)
	var moon := _environment()
	_night(moon)
	var wind := Node.new()
	wind.name = "Wind"
	wind.set_script(WindScript)
	add_child(wind)
	var life := WildlifeScript.new()
	add_child(life)
	life.bats(TOWER_BATS, 5, 6.0)
	_exits()
	set_meta(&"acoustics", "stone")
	set_meta(&"cold", true)
	Sfx.warm(self)

	baker = NavigationRegion3D.new()
	baker.set_script(NavBakerScript)
	baker.cell_size = CELL
	baker.agent_radius = AGENT_RADIUS
	baker.agent_max_climb = MAX_CLIMB
	baker.min_island = MIN_ISLAND
	baker.drop_unreached = true
	baker.home = HOME
	baker.bake_bounds = BAKE_BOUNDS

	# (The massing is no guard's: left out of the bake, still solid.)
	for body in (levels["city_massing"] as LevelLoader.Level).root.find_children("*", "CollisionObject3D", true, false):
		body.add_to_group(&"nav_ignore")

	await screen.step(String(LOADING["navmesh"]), 0.45)
	screen.creep_to(0.9)
	add_child(baker)
	await baker.baked
	LightProbe.invalidate()
	await screen.step(String(LOADING["guards"]), 0.92)

	# The same night every run: nobody reseeds the dice as he is made.
	GuardScript.randomize_on = false
	seed(SEED)

	for district in levels:
		var d: Dictionary = made[district]
		guards.merge(LevelGameplay.guards(self, levels[district], d["routes"], d["stations"], GUARD))

	GuardScript.randomize_on = true
	await screen.step(String(LOADING["player"]), 0.97)
	_player()
	screen.close()
	load_seconds = (Time.get_ticks_msec() - started) / 1000.0
	var mesh: NavigationMesh = baker.navigation_mesh
	var off_mesh: Array[String] = []

	for g in guards.values():
		var at: Vector3 = (g as Node3D).global_position

		if NavigationServer3D.map_get_closest_point(baker.get_navigation_map(), at).distance_to(at) > 1.0:
			off_mesh.append(String((g as Node).name))

	print("city: loaded in %.1f s, %d guards (off the navmesh: %s), navmesh %d polygons (%d links, %d unreached dropped)" % [load_seconds,
		guards.size(), off_mesh, mesh.get_polygon_count() if mesh != null else 0, baker.link_count, baker.unreached_count])
	ready_to_play.emit()

	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--fps-report="):
			_fps_report(float(arg.trim_prefix("--fps-report=")))


func _exit_tree() -> void:
	TemperamentScript.rolling = _was_rolling


## Returns the first district's marker matching marker_name, or {} when absent.
func marker(marker_name: String) -> Dictionary:
	for district in levels:
		var m: Dictionary = (levels[district] as LevelLoader.Level).get_marker(marker_name)

		if not m.is_empty():
			return m

	return {}


## The night's environment and its moon.
func _environment() -> DirectionalLight3D:
	environment = RetroScript.night_environment(Color(0.34, 0.36, 0.44), AMBIENT)
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
	moon.light_energy = MOON_ENERGY
	moon.shadow_enabled = true
	moon.light_volumetric_fog_energy = 4.0
	moon.directional_shadow_max_distance = SHADOW_DISTANCE
	add_child(moon)
	moon.global_basis = Basis.looking_at(MOON_TOWARD.normalized(), Vector3.UP)
	return moon


## The night over the harbour: weather on WEATHER's schedule, persistent
## clouds drifting with the wind; wet stone once it rains.
func _night(moon: DirectionalLight3D) -> void:
	night = NightScript.new()
	night.name = "Night"
	night.moon = moon
	night.environment = environment
	night.seed = SEED
	night.start = &"clear"
	night.skyline = SKYLINE
	var puddles: Array[Vector3] = []

	for at in PUDDLES:
		puddles.append(at)

	night.puddles = puddles
	var mist: Array[AABB] = []

	for box in MIST:
		mist.append(box)

	night.mist_boxes = mist
	add_child(night)

	for entry in WEATHER:
		night.to(entry[1], float(entry[2]), float(entry[0]) * 60.0)

	for district in levels:
		for body in (levels[district] as LevelLoader.Level).root.find_children("*", "MeshInstance3D", true, false):
			for i in (body as MeshInstance3D).get_surface_override_material_count():
				var material := (body as MeshInstance3D).get_surface_override_material(i) as StandardMaterial3D

				if material != null:
					night.register_wet(material)


## Each exit to a district not built yet: said, and printed, when the thief
## reaches it.
func _exits() -> void:
	for area in get_tree().get_nodes_in_group(&"district_exit"):
		(area as Area3D).body_entered.connect(func(body: Node3D) -> void:
			if body == player:
				var label := String(area.get_meta(&"label", "somewhere"))
				print("city: exit: %s" % label)

				if player.get("hud") != null:
					player.hud.show_caption("On to %s" % label, 4.0))


## The thief: in his rowboat (or at a vantage: --vantage=<name>), his
## blackjack and tools.
func _player() -> void:
	var at: Transform3D = marker("start").get("transform", Transform3D())

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
