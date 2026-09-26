extends Node3D
## Windowed staging: every kind of guard in every pose, photographed. Not a
## test (nothing is checked); run it with a window and look at the pictures.
##   Godot --path . --resolution 1280x720 res://tests/visual/stage_guards.tscn

const GuardScene := preload("res://Guard.tscn")
const OUT := "user://stage_guards/"
const KINDS := [&"", &"swordsman", &"duelist", &"brute", &"archer", &"trainer"]

## [name, state, then what to set]: phase/attack/u, velocity (his own space),
## or a reaction started at the pose's start.
const POSES := [
	["relaxed", 0, {}],
	["hunting", 3, {}],
	["walk", 0, {"velocity": Vector3(0, 0, -1.2)}],
	["strafe", 4, {"velocity": Vector3(1.5, 0, 0)}],
	["backoff", 4, {"velocity": Vector3(0, 0, 1.3)}],
	["overhead_up", 4, {"phase": &"windup", "attack": &"overhead", "u": 0.7}],
	["overhead_hit", 4, {"phase": &"strike", "attack": &"overhead", "u": 0.3}],
	["left_up", 4, {"phase": &"windup", "attack": &"left", "u": 0.7}],
	["left_hit", 4, {"phase": &"strike", "attack": &"left", "u": 0.3}],
	["right_up", 4, {"phase": &"windup", "attack": &"right", "u": 0.7}],
	["thrust_hit", 4, {"phase": &"strike", "attack": &"thrust", "u": 0.4}],
	["heavy_up", 4, {"phase": &"windup", "attack": &"heavy", "u": 0.8}],
	["heavy_hit", 4, {"phase": &"strike", "attack": &"heavy", "u": 0.5}],
	["kick_up", 4, {"phase": &"windup", "attack": &"kick", "u": 0.9}],
	["kick_hit", 4, {"phase": &"strike", "attack": &"kick", "u": 0.6}],
	["block", 4, {"block": true}],
	["reel", 4, {"react": &"parried"}],
	["kicked", 4, {"react": &"kicked"}],
	["flinch", 4, {"react": &"hit", "wait": 0.15}],
	["shoot_span", 4, {"phase": &"windup", "attack": &"shoot", "u": 0.3}],
	["shoot_aim", 4, {"phase": &"windup", "attack": &"shoot", "u": 0.85}],
]

var guards: Array = []
var pose: Array = []
var _pose_time := 0.0
var cams: Array[Camera3D] = []


func _ready() -> void:
	AudioServer.set_bus_mute(0, true)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.13, 0.14, 0.18)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.65, 0.68, 0.78)
	e.ambient_light_energy = 0.55
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.environment = e
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-38, 25, 0)
	sun.light_energy = 1.5
	sun.shadow_enabled = true
	add_child(sun)
	var floor := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(40, 1, 40)
	shape.shape = box
	shape.position.y = -0.5
	floor.add_child(shape)
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(40, 40)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.36, 0.34, 0.32)
	plane.material = mat
	ground.mesh = plane
	floor.add_child(ground)
	add_child(floor)

	for i in KINDS.size():
		var g: CharacterBody3D = GuardScene.instantiate()
		g.archetype = KINDS[i]
		g.name = "G_%s" % (KINDS[i] if KINDS[i] != &"" else &"watchman")
		add_child(g)
		g.global_position = Vector3(-4.5 + i * 1.8, 0, 0)
		# Facing the camera.
		g.rotation.y = PI
		g.set_physics_process(false)
		guards.append(g)

	for spec in [[Vector3(-2.7, 1.3, 4.2), Vector3(-0.06, 0, 0)], [Vector3(2.7, 1.3, 4.2), Vector3(-0.06, 0, 0)],
			[Vector3(0.6, 1.4, 3.0), Vector3(-0.08, deg_to_rad(62), 0)], [Vector3(6.2, 1.4, 1.2), Vector3(-0.08, deg_to_rad(62), 0)]]:
		var cam := Camera3D.new()
		add_child(cam)
		cam.position = spec[0]
		cam.rotation = spec[1]
		cam.fov = 50
		cams.append(cam)

	await get_tree().physics_frame

	for p in POSES:
		await _stage(p)

	await _deaths()
	print("staged into ", ProjectSettings.globalize_path(OUT))
	get_tree().quit()


func _physics_process(delta: float) -> void:
	if pose.is_empty():
		return

	_pose_time += delta
	var set: Dictionary = pose[2]

	for g in guards:
		if not is_instance_valid(g):
			continue

		g.state = pose[1]
		var local: Vector3 = set.get("velocity", Vector3.ZERO)
		g.velocity = g.global_basis * local

		var shooter: bool = g.archetype == &"archer"

		if set.has("phase") and (set["attack"] == &"shoot") == shooter or set.has("phase") and set["attack"] == &"kick":
			var attack: StringName = set["attack"]
			g._phase = set["phase"]
			g._attack = attack
			g._phase_length = 0.5
			g._phase_timer = 0.5 * (1.0 - float(set["u"]))
		else:
			g._phase = &""

		g._block_flash = 0.3 if set.get("block", false) else 0.0

		if pose[2].get("react", &"") == &"kicked":
			g._knock = maxf(g._knock - delta, 0.01)
		else:
			g._knock = 0.0

		g._rig.update(delta)
		# His head as his AI would turn it.
		g._update_head(delta)


func _stage(p: Array) -> void:
	pose = p
	_pose_time = 0.0
	var set: Dictionary = p[2]

	for g in guards:
		match set.get("react", &""):
			&"parried":
				g._rig.react_parried(1.5)
			&"kicked":
				g._knock = 1.1
				g._rig.react_kick(g.global_basis.z * 3.0, 1.1)
			&"hit":
				g._rig.react_hit(g.global_basis.z, 1.0)

	var wait: float = set.get("wait", 0.45)

	while _pose_time < wait:
		await get_tree().process_frame

	await _shoot(p[0])


func _shoot(label: String) -> void:
	for c in cams.size():
		cams[c].current = true
		await get_tree().process_frame
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(OUT + "%s_%d.png" % [label, c])


func _deaths() -> void:
	pose = []

	for g in guards:
		g.set_physics_process(false)
		g.die(null)

	var t := 0.0

	for at in [0.3, 0.7, 1.6]:
		while t < at:
			await get_tree().process_frame
			t += get_process_delta_time()

		await _shoot("death_%.1f" % at)
