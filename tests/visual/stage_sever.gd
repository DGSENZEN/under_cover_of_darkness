## Visual check, not a test: cut apart.
##   Godot --fixed-fps 60 --resolution 960x540 --path . res://tests/visual/stage_sever.tscn -- --out=/some/folder
extends Node3D

const GUARD := preload("res://Guard.tscn")
const Props := preload("res://scripts/Interaction/Props.gd")
const Sfx := preload("res://scripts/Audio/Sfx.gd")

var out_dir := "user://sever/"


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.substr(6).trim_suffix("/") + "/"

	DirAccess.make_dir_recursive_absolute(out_dir)
	Sfx.volume_db = -60.0
	Props.block(self, Vector3(0, -0.5, 0), Vector3(60, 1, 60), Color(0.42, 0.4, 0.37))
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(-0.8, 0.5, 0.0)
	sun.shadow_enabled = true
	add_child(sun)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.55, 0.55, 0.6)
	add_child(env)
	var cam := Camera3D.new()
	add_child(cam)
	cam.fov = 55
	cam.current = true
	cam.global_position = Vector3(0.0, 1.7, 6.0)
	cam.look_at(Vector3(0.0, 0.9, 0.0))

	# The blow comes from the camera's side, travelling -Z.
	var cuts := [
		[[&"neck_01"], 1.62],
		[[&"lowerarm_r"], 1.2],
		[[&"upperarm_l"], 1.3],
		[[&"thigh_l", &"thigh_r"], 0.7],
		[[&"calf_l", &"calf_r"], 0.35],
	]
	var guards := []

	for i in range(cuts.size()):
		var g: CharacterBody3D = GUARD.instantiate()
		# Placed before it is made: made in one place and moved, a man stood
		# on by another is flung off at the speed of the move.
		g.position = Vector3(-3.2 + i * 1.6, 0.0, 0.0)
		g.rotation.y = PI
		add_child(g)
		g._attack_timer = 99.0
		guards.append(g)

	for i in 40:
		await get_tree().physics_frame

	await _shoot("s0")

	for i in range(cuts.size()):
		var g: CharacterBody3D = guards[i]
		var at: Vector3 = g.global_position + Vector3(0.0, float(cuts[i][1]), 0.25)
		g.sever_hint.assign(cuts[i][0])
		g.health = 5.0
		g.take_hit(60.0, null, &"power", at, Vector3(-0.3, 0.0, -1.0).normalized())

	var marks := {3: "s1", 10: "s2", 25: "s3", 60: "s4", 150: "s5"}

	for frame in 151:
		if marks.has(frame):
			await _shoot(marks[frame])

		await get_tree().physics_frame

	var pieces := get_tree().get_nodes_in_group(&"bodies").filter(func(b): return b.get("part") != null)
	print("pieces %d: %s" % [pieces.size(), pieces.map(func(p): return "%s at %s" % [p.part, p.global_position])])
	get_tree().quit()


func _shoot(name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out_dir + name + ".png")
