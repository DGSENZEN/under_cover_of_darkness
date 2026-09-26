## Visual check, not a test: each of a guard's blows as the fight plays it
## (his own clock, his dashes and steps), filmed side on and from your eyes at
## the moments that matter: the gather, the held key pose, the release, the
## blow, the recovery. Last, a man thrown off his balance, open.
##   Godot --fixed-fps 60 --resolution 960x540 --path . res://tests/visual/stage_moves.tscn -- --out=/some/folder [--moves=sweep,bash]
extends Node3D

const PLAYER := preload("res://Player.tscn")
const GUARD := preload("res://Guard.tscn")
const Props := preload("res://scripts/Interaction/Props.gd")
const Sfx := preload("res://scripts/Audio/Sfx.gd")
const NavBakerScript := preload("res://scripts/AISystem/NavBaker.gd")

## [move, archetype, how far off he starts]
const MOVES := [
	[&"overhead", &"swordsman", 1.6], [&"left", &"swordsman", 1.6], [&"right", &"swordsman", 1.6],
	[&"thrust", &"swordsman", 1.7], [&"sweep", &"swordsman", 1.6], [&"bash", &"swordsman", 1.2],
	[&"heavy", &"brute", 1.9], [&"charge", &"brute", 5.5], [&"leap", &"duelist", 3.8], [&"lunge", &"duelist", 3.6],
	[&"open", &"swordsman", 1.8],
]
## Where to take a picture: [phase, progress through it].
const MOMENTS := [[&"windup", 0.12], [&"windup", 0.35], [&"windup", 0.62], [&"windup", 0.9], [&"strike", 0.4], [&"recover", 0.25], [&"recover", 0.6], [&"recover", 0.9]]

var out_dir := "user://moves/"
var player: CharacterBody3D
var side_view: SubViewport
var eye_view: SubViewport
var side_cam: Camera3D
var eye_cam: Camera3D


func _ready() -> void:
	var only: Array = []

	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.substr(6).trim_suffix("/") + "/"
		elif arg.begins_with("--moves="):
			only = Array(arg.substr(8).split(","))

	DirAccess.make_dir_recursive_absolute(out_dir)
	Sfx.volume_db = -60.0
	Props.block(self, Vector3(0, -0.5, 0), Vector3(40, 1, 40), Color(0.4, 0.38, 0.36))
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(-0.8, 0.7, 0.0)
	add_child(sun)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.45, 0.45, 0.5)
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.12, 0.12, 0.14)
	add_child(env)
	# Dashes and steps keep to the navmesh.
	var baker := NavigationRegion3D.new()
	baker.set_script(NavBakerScript)
	add_child(baker)

	player = PLAYER.instantiate()
	player.position = Vector3(0, 1.05, 0)
	add_child(player)
	player.invulnerable = true
	player.reload_on_death = false

	if player.has_node("LightGem"):
		player.get_node("LightGem").queue_free()

	player.debug_light_level = 1.0
	player.set_physics_process(false)

	await baker.baked
	side_view = _view()
	side_cam = side_view.get_child(0) as Camera3D
	eye_view = _view()
	eye_cam = eye_view.get_child(0) as Camera3D

	side_view = _view()
	side_cam = side_view.get_child(0) as Camera3D
	eye_view = _view()
	eye_cam = eye_view.get_child(0) as Camera3D

	for i in 10:
		await get_tree().physics_frame

	for spec in MOVES:
		if not only.is_empty() and not only.has(String(spec[0])):
			continue

		await _film(spec[0], spec[1], spec[2])

	get_tree().quit()


func _view() -> SubViewport:
	var view := SubViewport.new()
	view.size = Vector2i(480, 400)
	view.world_3d = get_viewport().world_3d
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(view)
	var cam := Camera3D.new()
	cam.fov = 50
	view.add_child(cam)
	cam.current = true
	return view


func _film(move: StringName, archetype: StringName, distance: float) -> void:
	var g: CharacterBody3D = GUARD.instantiate()
	g.archetype = archetype
	g.debug_ai = false
	g.position = Vector3(0, 0, -distance)
	# Facing you.
	g.rotation.y = PI
	add_child(g)
	g.block_chance = 0.0
	g._fighter.parry_chance = 0.0
	g._fighter.feint_chance = 0.0
	g._fighter.dodge_chance = 0.0
	g._fighter.backstep_chance = 0.0
	g._fighter.lunge_chance = 0.0
	g._fighter.leap_chance = 0.0
	g._fighter.charge_chance = 0.0
	g._fighter.timing_variance = 0.0
	g._fighter.combo_max = 1
	g._fighter.strafe_speed = 0.0
	g._fighter.stays_put = true
	g._attack_timer = 999.0
	g.attack_cooldown = 999.0
	g._engage(player)

	for i in 40:
		await get_tree().physics_frame

	var mid := Vector3(0, 1.0, -distance * 0.5)
	side_cam.global_position = Vector3(3.2 + distance * 0.45, 1.3, mid.z)
	side_cam.look_at(mid)
	# Your eyes, just in front of your own head.
	eye_cam.global_position = Vector3(0, 1.62, -0.3)
	eye_cam.look_at(Vector3(0, 1.1, -distance))

	var shots: Array[String] = []

	if move == &"open":
		g._fighter.add_posture(g._fighter.posture_max)
		var times := [0.05, 0.15, 0.3, 0.6, 1.0, 1.3, 1.5, 1.65]
		var elapsed := 0.0

		for t in times:
			while elapsed < t:
				await get_tree().physics_frame
				elapsed += 1.0 / 60.0

			await _shot("%s_%d" % [move, shots.size()], shots)
	else:
		g._fighter.stays_put = false
		g._fighter._start(move)


		for moment in MOMENTS:
			var ok := await _wait_for(g, moment[0], moment[1])

			if ok:
				await _shot("%s_%d" % [move, shots.size()], shots)

	g.queue_free()

	for i in 20:
		await get_tree().physics_frame


func _wait_for(g: CharacterBody3D, phase: StringName, u: float) -> bool:
	for i in 240:
		if not is_instance_valid(g):
			return false

		if g._phase == phase and g._fighter.progress() >= u:
			return true

		# Past it already.
		if phase == &"windup" and g._phase in [&"strike", &"recover"]:
			return false

		if phase == &"strike" and g._phase == &"recover":
			return false

		if g._phase == &"" and i > 5:
			return false

		await get_tree().physics_frame

	return false


func _shot(shot_name: String, shots: Array[String]) -> void:
	await RenderingServer.frame_post_draw
	var side := side_view.get_texture().get_image()
	var eye := eye_view.get_texture().get_image()
	var both := Image.create(side.get_width() + eye.get_width(), side.get_height(), false, side.get_format())
	both.blit_rect(side, Rect2i(Vector2i.ZERO, side.get_size()), Vector2i.ZERO)
	both.blit_rect(eye, Rect2i(Vector2i.ZERO, eye.get_size()), Vector2i(side.get_width(), 0))
	both.save_png(out_dir + shot_name + ".png")
	shots.append(shot_name)
