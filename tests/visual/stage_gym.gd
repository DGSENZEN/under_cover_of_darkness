## Visual check, not a test: the NPC gym.
##   Godot --fixed-fps 60 --resolution 960x540 --path . res://tests/visual/stage_gym.tscn -- --out=/some/folder
extends Node3D

const GYM := preload("res://maps/npc_gym.tscn")
const Sfx := preload("res://scripts/Audio/Sfx.gd")

var out_dir := "user://gym/"
var gym: Node3D


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.substr(6).trim_suffix("/") + "/"

	DirAccess.make_dir_recursive_absolute(out_dir)
	Sfx.volume_db = -60.0
	gym = GYM.instantiate()
	add_child(gym)
	await gym._baker.baked
	gym.player.invulnerable = true
	await _frames(30)

	# From above: the whole place, north to the right.
	var above := Camera3D.new()
	add_child(above)
	above.global_position = Vector3(0, 64, -26)
	above.rotation_degrees = Vector3(-90, 90, 0)
	above.fov = 70
	above.current = true
	await _shot("a_overview")
	gym.player.camera.current = true
	await _shot("b_hub")

	for spec in [[0, 60, "c_watchman"], [5, 150, "d_squad"], [5, 150, "e_squad_later"], [6, 60, "f_bodies"], [3, 90, "g_brute"],
			[8, 120, "h_guardhouse"], [8, 240, "i_guardhouse_later"]]:
		# A "_later" shot carries on the fight before it.
		if not String(spec[2]).ends_with("_later"):
			gym._start_bay(spec[0])

		await _frames(spec[1])
		await _shot(spec[2])

	# Down the dark loop behind the guardhouse's yard: it should be dark.
	gym.player.global_position = Vector3(-13, 1.05, 30)
	gym.player.rotation.y = PI
	gym.player.reset_physics_interpolation()
	await _frames(20)
	await _shot("j_guardhouse_dark")

	# Bay 10: in at its mouth; then up on the tower, and in the pool, with
	# them coming after you.
	gym._start_bay(9)
	await _frames(40)
	await _shot("k_climb_swim")
	var side := Camera3D.new()
	add_child(side)
	# From the side: what they think and say would hide them.
	gym._labels_on = false
	gym._panel.visible = false
	gym._log.visible = false

	for spec in [[Vector3(11, 4.6, -95), Vector3(3.0, 3.2, -84.5), Vector3(11, 2.2, -93.5), 270, "l_climb_swim_tower"],
			[Vector3(-8, -0.8, -88), Vector3(-2.0, 2.4, -82.0), Vector3(-8, -0.8, -88.5), 200, "m_climb_swim_pool"]]:
		gym._start_bay(9)
		await _frames(2)
		gym.player.global_position = spec[0]
		gym.player.velocity = Vector3.ZERO
		gym.player.reset_physics_interpolation()
		await _frames(1)

		for g in gym._bay_guards[9]:
			g._engage(gym.player)

		side.global_position = spec[1]
		side.look_at(spec[2])
		side.current = true
		await _frames(spec[3])
		await _shot(spec[4])

	get_tree().quit()


func _shot(shot_name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out_dir + shot_name + ".png")


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame
