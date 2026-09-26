## Visual check: walks the retro showcase and saves screenshots (see stage_combat.gd).
extends Node3D
## Windowed staging for the look: walks the showcase and saves screenshots.

const OUT_DEFAULT := "user://shots/"

## Where screenshots go: user://shots/, or --out=<folder> after "--".
var out_dir := OUT_DEFAULT
const Sfx := preload("res://scripts/Audio/Sfx.gd")

var level: Node3D
var player: CharacterBody3D


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.substr(6).trim_suffix("/") + "/"
	Sfx.volume_db = -60.0
	DirAccess.make_dir_recursive_absolute(out_dir)
	level = load("res://maps/retro_showcase.tscn").instantiate()
	add_child(level)
	player = level.player
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	player.invulnerable = true
	player.debug_light_level = 0.0
	await _frames(90)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var retro := get_node("/root/Retro")

	await _view("01_hall", Vector3(0, 1.05, 4.2), 0.0, 0.05)
	await _view("02_windows", Vector3(-2.0, 1.05, 0.5), deg_to_rad(-70), 0.12)
	await _view("03_shafts_side", Vector3(3.0, 1.05, 3.0), deg_to_rad(20), 0.05)
	await _view("04_idol", Vector3(0, 1.05, -3.8), 0.0, -0.3)
	await _view("05_mist", Vector3(-1.5, 1.05, 1.5), deg_to_rad(125), -0.25)
	var guard: Node3D = level.get_node("Guard")
	var to := guard.global_position - Vector3(0, 0, 0)
	await _view("06_guard", guard.global_position + Vector3(1.6, 1.05, 1.6), atan2(1.6, 1.6), -0.05)
	await _view("07_gallery", Vector3(0, 1.05, -4.5), 0.0, 0.35)
	retro.virtual_height = 240
	await _view("08_hall_240", Vector3(0, 1.05, 4.2), 0.0, 0.05)
	retro.virtual_height = 448
	await _view("09_hall_448", Vector3(0, 1.05, 4.2), 0.0, 0.05)
	retro.virtual_height = 0
	await _view("10_hall_off", Vector3(0, 1.05, 4.2), 0.0, 0.05)
	retro.virtual_height = 360
	Sfx.silence()
	await _frames(3)
	get_tree().quit()


func _view(shot_name: String, at: Vector3, yaw: float, pitch: float) -> void:
	player.movement_state = 0
	player.velocity = Vector3.ZERO
	player.global_position = at
	player.rotation.y = yaw
	player.get_node("Neck").rotation.x = pitch
	await _frames(20)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out_dir + shot_name + ".png")


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame
