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

	# From above: the whole place.
	var above := Camera3D.new()
	add_child(above)
	above.global_position = Vector3(0, 70, -30)
	above.rotation_degrees = Vector3(-90, 0, 0)
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

	get_tree().quit()


func _shot(shot_name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out_dir + shot_name + ".png")


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame
