## Visual check, not a test: the marks over men noticing you (StealthHUD's
## awareness marks). One ahead makes you out (his eye opening, the ring
## filling, then his "!" and his name), one off to the left comes to look (a
## "?" at the edge), one behind you heard something (at the bottom edge).
##   Godot --fixed-fps 60 --resolution 960x540 --path . res://tests/visual/stage_detect.tscn -- --out=/some/folder
extends Node3D

const PLAYER := preload("res://Player.tscn")
const GUARD := preload("res://Guard.tscn")
const Props := preload("res://scripts/Interaction/Props.gd")
const NavBakerScript := preload("res://scripts/AISystem/NavBaker.gd")
const TemperamentScript := preload("res://scripts/AISystem/Temperament.gd")
const SoundBus := preload("res://scripts/StimuliSystem/SoundBus.gd")
const Sfx := preload("res://scripts/Audio/Sfx.gd")

var out_dir := "user://detect/"
var player: CharacterBody3D


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.substr(6).trim_suffix("/") + "/"

	DirAccess.make_dir_recursive_absolute(out_dir)
	Sfx.volume_db = -60.0
	TemperamentScript.rolling = false
	Props.block(self, Vector3(0, -0.5, 0), Vector3(80, 1, 80), Color(0.3, 0.29, 0.28))
	Props.block(self, Vector3(0, 2, -24), Vector3(30, 4, 0.4), Color(0.42, 0.4, 0.38))

	for at in [Vector3(-4, 3.0, -12), Vector3(4, 3.0, -12), Vector3(0, 3.0, 2)]:
		var lamp := OmniLight3D.new()
		lamp.light_color = Color(1.0, 0.72, 0.42)
		lamp.light_energy = 1.8
		lamp.omni_range = 12.0
		add_child(lamp)
		lamp.global_position = at

	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.03, 0.03, 0.05)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.35, 0.38, 0.5)
	environment.ambient_light_energy = 0.3
	var world := WorldEnvironment.new()
	world.environment = environment
	add_child(world)
	var baker := NavigationRegion3D.new()
	baker.set_script(NavBakerScript)
	add_child(baker)
	player = PLAYER.instantiate()
	add_child(player)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	player.invulnerable = true
	player.reload_on_death = false
	player.show_hud = true
	player.global_position = Vector3(0, 1.05, 0)
	player.debug_light_level = 0.0
	await baker.baked

	# Ahead of you, facing you; off to your left, sent to look; behind you.
	var ahead := _man(Vector3(1.5, 0, -9), PI)
	var left := _man(Vector3(-17, 0, -3), -PI * 0.5)
	var behind := _man(Vector3(2, 0, 11), 0.0)
	await _frames(30)
	left.last_known_position = Vector3(-2, 0, -1)
	left.has_last_known = true
	left._stimulus = &"noise"
	left._since_stimulus = 0.0
	left.alert = 50.0
	SoundBus.emit_sound(Vector3(3, 0, 13), 50.0, self, &"test")
	# Half lit: he makes you out over a second or two.
	player.debug_light_level = 0.45

	for i in 16:
		await _frames(8)
		await _shot("detect_%02d" % i)

	# Had: his "!", his name.
	await _until(func(): return int(ahead.state) == 4, 240)
	await _frames(4)
	await _shot("detect_had_a")
	await _frames(20)
	await _shot("detect_had_b")
	# Turned away from him: his mark at the edge.
	player.rotation.y = PI * 0.6
	await _frames(10)
	await _shot("detect_turned")
	print("detect: ahead %d (%.0f) left %d (%.0f) behind %d (%.0f)" % [int(ahead.state), ahead.alert, int(left.state), left.alert, int(behind.state), behind.alert])
	Sfx.silence()
	await _frames(3)
	get_tree().quit()


func _man(at: Vector3, yaw: float) -> CharacterBody3D:
	var g: CharacterBody3D = GUARD.instantiate()
	g.debug_ai = false
	g.position = at
	g.rotation.y = yaw
	add_child(g)
	g._habits._wait = 999.0
	g._life._talk_rest = 999.0
	g._attack_timer = 999.0
	g.attack_cooldown = 999.0
	return g


func _shot(shot_name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out_dir + shot_name + ".png")


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _until(cond: Callable, max_frames: int) -> void:
	for i in max_frames:
		if cond.call():
			return

		await get_tree().physics_frame
