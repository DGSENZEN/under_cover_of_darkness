## Visual check, not a test: a man hunting you in a room with somewhere to
## hide (Guard._next_search_point, SearchSpots.gd): a dark corner, a nook
## between crates, a lit open floor, a side room through a door, a ledge.
## He goes from one likely place to the next, looking into each as he comes
## (his lantern held out to it), then about him. A second man, later, holds
## the door while the first goes through it.
##   Godot --fixed-fps 60 --resolution 960x540 --path . res://tests/visual/stage_search.tscn -- --out=/some/folder
extends Node3D

const PLAYER := preload("res://Player.tscn")
const GUARD := preload("res://Guard.tscn")
const Props := preload("res://scripts/Interaction/Props.gd")
const NavBakerScript := preload("res://scripts/AISystem/NavBaker.gd")
const TemperamentScript := preload("res://scripts/AISystem/Temperament.gd")
const Sfx := preload("res://scripts/Audio/Sfx.gd")

var out_dir := "user://search/"
var camera: Camera3D
var player: CharacterBody3D


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.substr(6).trim_suffix("/") + "/"

	DirAccess.make_dir_recursive_absolute(out_dir)
	Sfx.volume_db = -60.0
	TemperamentScript.rolling = false
	var stone := Color(0.42, 0.4, 0.38)
	Props.block(self, Vector3(0, -0.5, 0), Vector3(80, 1, 80), Color(0.3, 0.29, 0.28))
	# A dark corner, back left.
	Props.block(self, Vector3(-3.9, 1.5, -4.6), Vector3(3.8, 3, 0.3), stone)
	Props.block(self, Vector3(-5.65, 1.5, -2.9), Vector3(0.3, 3, 3.7), stone)
	# A nook between crates, left.
	var wood := Color(0.5, 0.38, 0.24)
	Props.block(self, Vector3(-5.6, 0.6, 3.0), Vector3(0.9, 1.2, 2.8), wood)
	Props.block(self, Vector3(-4.4, 0.6, 1.9), Vector3(1.6, 1.2, 0.6), wood)
	Props.block(self, Vector3(-4.4, 0.6, 4.1), Vector3(1.6, 1.2, 0.6), wood)
	# A side room, right, its door on this side.
	Props.block(self, Vector3(7, 1.5, -2.5), Vector3(0.3, 3, 3), stone)
	Props.block(self, Vector3(7, 1.5, 2.5), Vector3(0.3, 3, 3), stone)
	Props.block(self, Vector3(7, 2.55, 0), Vector3(0.3, 0.9, 2), stone)
	Props.block(self, Vector3(13, 1.5, 0), Vector3(0.3, 3, 8), stone)
	Props.block(self, Vector3(10, 1.5, -4), Vector3(6, 3, 0.3), stone)
	Props.block(self, Vector3(10, 1.5, 4), Vector3(6, 3, 0.3), stone)
	Props.door(self, Vector3(7, 0, -0.5), -PI * 0.5)
	# A ledge, at the back.
	Props.block(self, Vector3(1.5, 1.25, -6.8), Vector3(5, 2.5, 1.6), stone)

	# Light over the open floor, front right; the rest dark.
	var lamp := OmniLight3D.new()
	lamp.light_color = Color(1.0, 0.72, 0.42)
	lamp.light_energy = 1.6
	lamp.omni_range = 9.0
	lamp.shadow_enabled = true
	add_child(lamp)
	lamp.global_position = Vector3(4, 3.5, 6)
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.03, 0.03, 0.05)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.35, 0.38, 0.5)
	environment.ambient_light_energy = 0.35
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
	player.global_position = Vector3(34, 1.05, 34)
	player.debug_light_level = 0.0
	camera = Camera3D.new()
	add_child(camera)
	camera.fov = 55
	camera.current = true
	await baker.baked
	await _frames(20)

	# He lost you here, and searches round it with a lantern.
	var g := _man(Vector3(2, 0, 7), PI)
	await _frames(30)
	g._hands.light_lantern()
	g.last_known_position = Vector3(0, 0, 0)
	g.has_last_known = true
	g.alert = 70.0
	g._set_state(3)
	g._search_left = 8
	var last_kind := &""
	var shots := 0

	for i in 2700:
		await _frames(1)
		var spot: Dictionary = g._spot
		var kind: StringName = spot.get("kind", &"") if not spot.is_empty() else &"-"

		if kind != last_kind:
			last_kind = kind
			print("t %.1f  %s  stand %s peer %s  (state %d)" % [i / 60.0, kind, spot.get("stand", "-"), spot.get("peer", "-"), int(g.state)])

		# Close on him as he comes to a place, and as he looks; the room from
		# over it now and then.
		if i % 20 == 0 and shots < 80:
			var peer: Vector3 = g.peer_point()
			var looking := "peer" if peer != Vector3.INF else ("look" if g._look_timer > 0.0 else "walk")
			await _shoot_near(g, "search_%03d_%s_%s" % [shots, kind, looking])
			shots += 1

		if i % 120 == 0:
			await _shoot_over("over_%04d" % i)

		if int(g.state) != 3:
			print("t %.1f  gave up (state %d)" % [i / 60.0, int(g.state)])
			break

	print("searched: %s" % [g._searched])
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
	g.hearing_acuity = 0.0
	return g


## From before him and to his left, above: him, his light, and what he
## looks into.
func _shoot_near(g: Node3D, shot_name: String) -> void:
	var ahead := -g.global_basis.z
	camera.global_position = g.global_position + ahead * 2.6 - g.global_basis.x * 2.4 + Vector3.UP * 2.9
	camera.look_at(g.global_position + ahead * 0.8 + Vector3.UP * 0.9)
	camera.reset_physics_interpolation()
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out_dir + shot_name + ".png")


## The whole room from high over it.
func _shoot_over(shot_name: String) -> void:
	camera.global_position = Vector3(1, 17, 9)
	camera.look_at(Vector3(1, 0, -0.5))
	camera.reset_physics_interpolation()
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out_dir + shot_name + ".png")


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame
