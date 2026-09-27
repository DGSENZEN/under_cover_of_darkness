extends Node3D
## Windowed staging: a man at every kind of station (GuardRota), photographed
## from two sides once he is at it. Not a test (nothing is checked): look at
## the pictures (seat height, the lying pose, the crate in his arms).
##   Godot --path . --resolution 1280x720 res://tests/visual/stage_stations.tscn -- --out=<dir>

const GUARD := preload("res://Guard.tscn")
const Props := preload("res://scripts/Interaction/Props.gd")
const NavBakerScript := preload("res://scripts/AISystem/NavBaker.gd")
const GuardStationScript := preload("res://scripts/AISystem/GuardStation.gd")
const TemperamentScript := preload("res://scripts/AISystem/Temperament.gd")

const WOOD := Color(0.36, 0.25, 0.15)

var _out := "user://stage_stations/"
## [label, guard, the activity to wait for, station].
var _cases: Array = []


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.trim_prefix("--out=").trim_suffix("/") + "/"

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out) if _out.begins_with("user://") else _out)
	AudioServer.set_bus_mute(0, true)
	TemperamentScript.rolling = false
	_light_the_yard()
	Props.block(self, Vector3(0, -0.5, 0), Vector3(40, 1, 24), Color(0.3, 0.29, 0.27))

	# Bench (seat top 0.45 m) for the sitter and the eater.
	Props.block(self, Vector3(-12, 0.22, -0.55), Vector3(2.6, 0.45, 0.45), WOOD)
	_case("sit", &"sit", Vector3(-12.6, 0, 0), PI, &"sit")
	_case("eat", &"eat", Vector3(-11.4, 0, 0), PI, &"eat")

	# A bedroll on the floor.
	Props.block(self, Vector3(-6, 0.02, 0), Vector3(0.8, 0.04, 2.0), Color(0.35, 0.3, 0.22))
	_case("sleep", &"sleep", Vector3(-6, 0, 0), PI, &"sleep")

	# A chest, lid up.
	var chest: Node3D = Props.chest(self, Vector3(0, 0, -1.0), 0.0)
	_case("rummage", &"rummage", Vector3(0, 0, 0), PI, &"rummage", {"chest": chest})

	# Crates from here to a spot 6 m off.
	var drop := Marker3D.new()
	add_child(drop)
	drop.global_position = Vector3(10, 0, 4)

	for i in 3:
		var crate := Props.crate(self, Vector3(4.6 + i * 0.6, 0.3, 4), 0.5, 5.0)
		crate.add_to_group(&"cargo")

	_case("carry", &"carry", Vector3(4, 0, 4), -PI * 0.5, &"carry", {"drop_to": drop})

	# A chopping block, and a rail.
	Props.block(self, Vector3(6, 0.3, -0.7), Vector3(0.5, 0.6, 0.5), WOOD)
	_case("chop", &"chop", Vector3(6, 0, 0), PI, &"chop")
	Props.block(self, Vector3(12, 0.55, -0.55), Vector3(2.0, 1.1, 0.12), WOOD)
	_case("lean", &"lean", Vector3(12, 0, 0), PI, &"lean")

	var baker := NavigationRegion3D.new()
	baker.set_script(NavBakerScript)
	add_child(baker)
	await baker.baked

	for c in _cases:
		_spawn(c)

	var camera := Camera3D.new()
	camera.fov = 50.0
	add_child(camera)
	camera.make_current()

	for c in _cases:
		var man: Node3D = c[1]
		var want: StringName = c[2]
		var station: Node3D = c[3]

		for f in 1800:
			if man.activity() == want:
				break

			await get_tree().physics_frame

		# A moment into it, then two views: from the front-left and the side.
		for f in 40:
			await get_tree().physics_frame

		var at: Vector3 = man.global_position if want == &"carry" else station.global_position
		var ahead: Vector3 = station.facing() if want != &"carry" else -man.global_basis.z

		for view in [[ahead.rotated(Vector3.UP, 0.5), "front"], [ahead.rotated(Vector3.UP, PI * 0.5), "side"]]:
			camera.global_position = at + (view[0] as Vector3) * 3.0 + Vector3.UP * 1.3
			camera.look_at(at + Vector3.UP * 0.8, Vector3.UP)
			await RenderingServer.frame_post_draw
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(_out + "%s_%s.png" % [c[0], view[1]])

		print("staged %s: %s" % [c[0], man.activity()])

	get_tree().quit()


func _case(label: String, kind: StringName, at: Vector3, yaw: float, want: StringName, links := {}) -> void:
	var station: Marker3D = GuardStationScript.new()
	station.kind = kind
	add_child(station)
	station.global_position = at
	station.rotation.y = yaw

	for key in links:
		station.set(key, station.get_path_to(links[key]))

	_cases.append([label, null, want, station])


func _spawn(c: Array) -> void:
	var station: Node3D = c[3]
	var g: CharacterBody3D = GUARD.instantiate()
	g.temperament = &"steady"
	g.position = station.global_position + Vector3(0, 0, 3.0)
	var paths: Array[NodePath] = [station.get_path()]
	g.stations = paths
	add_child(g)
	c[1] = g


func _light_the_yard() -> void:
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.13, 0.14, 0.18)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.65, 0.68, 0.78)
	e.ambient_light_energy = 0.6
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.environment = e
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40, 30, 0)
	sun.light_energy = 1.4
	sun.shadow_enabled = true
	add_child(sun)
