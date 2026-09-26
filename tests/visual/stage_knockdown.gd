## Visual check, not a test: kicked off their feet.
##   Godot --fixed-fps 60 --resolution 960x540 --path . res://tests/visual/stage_knockdown.tscn -- --out=/some/folder
##   A: kicked mid-swing, he flies, lands, and gets up. B: kicked into a friend,
##   both go down. C: kicked onto spikes.
extends Node3D

const PLAYER := preload("res://Player.tscn")
const GUARD := preload("res://Guard.tscn")
const Props := preload("res://scripts/Interaction/Props.gd")
const NavBakerScript := preload("res://scripts/AISystem/NavBaker.gd")
const Sfx := preload("res://scripts/Audio/Sfx.gd")

var out_dir := "user://knockdown/"
var player: CharacterBody3D
var cam: Camera3D


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.substr(6).trim_suffix("/") + "/"

	DirAccess.make_dir_recursive_absolute(out_dir)
	Sfx.volume_db = -60.0
	Props.block(self, Vector3(0, -0.5, 0), Vector3(80, 1, 80), Color(0.42, 0.4, 0.37))
	# C: a spiked wall behind the third man.
	Props.block(self, Vector3(20, 1.5, -3.2), Vector3(4, 3, 0.3), Color(0.35, 0.33, 0.3))
	Props.spikes(self, Vector3(20, 1.1, -3.0), 3.0, 1.6, Vector3.BACK)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(-0.9, 0.6, 0.0)
	sun.shadow_enabled = true
	add_child(sun)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.55, 0.55, 0.6)
	add_child(env)
	var baker := NavigationRegion3D.new()
	baker.set_script(NavBakerScript)
	add_child(baker)
	player = PLAYER.instantiate()
	add_child(player)
	player.invulnerable = true
	player.reload_on_death = false
	player.global_position = Vector3(0, 1.05, 30)
	await baker.baked
	cam = Camera3D.new()
	add_child(cam)
	cam.fov = 60
	cam.current = true

	await _scene_a()
	await _scene_b()
	await _scene_c()
	get_tree().quit()


func _guard(at: Vector3, yaw := 0.0) -> CharacterBody3D:
	var g: CharacterBody3D = GUARD.instantiate()
	g.position = at
	g.rotation.y = yaw
	add_child(g)
	g._attack_timer = 99.0
	return g


func _shoot(name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out_dir + name + ".png")


## The boot, from the player's side of him (+Z), `speed` m/s along -Z.
func _kick(g: CharacterBody3D, speed := 7.5) -> void:
	player.global_position = g.global_position + Vector3(0, 1.05, 1.2)
	g.kick(Vector3(0, 0, -speed), player)


func _scene_a() -> void:
	var g := _guard(Vector3(0, 0, 0))
	cam.global_position = Vector3(4.5, 1.4, -1.5)
	cam.look_at(Vector3(0, 0.8, -1.5))
	await _frames(40)
	# Caught in the middle of his blow.
	g._phase = &"windup"
	g._attack = &"overhead"
	g._phase_length = 0.6
	g._phase_timer = 0.3
	_kick(g)
	var marks := {0: "a0", 9: "a1", 24: "a2", 48: "a3", 90: "a4", 132: "a5", 180: "a6", 228: "a7", 276: "a8"}

	for frame in 277:
		if marks.has(frame):
			await _shoot(marks[frame])
			print("A %s downed %s rising %.2f stagger %.2f at %s" % [marks[frame], g.is_downed(), g._rising, g._stagger, g.global_position])

		await get_tree().physics_frame

	g.queue_free()


func _scene_b() -> void:
	var a := _guard(Vector3(10, 0, 0))
	var b := _guard(Vector3(10, 0, -1.3), PI)
	cam.global_position = Vector3(14.5, 1.6, -0.8)
	cam.look_at(Vector3(10, 0.8, -1.2))
	await _frames(40)
	a._stagger = 0.4
	_kick(a, 8.5)
	var marks := {0: "b0", 12: "b1", 30: "b2", 60: "b3", 120: "b4"}

	for frame in 121:
		if marks.has(frame):
			await _shoot(marks[frame])
			print("B %s kicked downed %s | behind downed %s" % [marks[frame], a.is_downed(), b.is_downed()])

		await get_tree().physics_frame

	a.queue_free()
	b.queue_free()


func _scene_c() -> void:
	var g := _guard(Vector3(20, 0, -1.4))
	cam.global_position = Vector3(23.5, 1.6, 0.5)
	cam.look_at(Vector3(20, 1.0, -2.5))
	await _frames(40)
	g._stagger = 0.4
	_kick(g, 8.0)
	var marks := {0: "c0", 10: "c1", 25: "c2", 60: "c3", 150: "c4"}

	for frame in 151:
		if marks.has(frame):
			await _shoot(marks[frame])
			print("C %s alive %s" % [marks[frame], is_instance_valid(g)])

		await get_tree().physics_frame


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame
