extends Node3D
## Windowed visual QA: course layout, station instructions, HUD and guard.
## Godot --path . --resolution 1280x720 res://tests/visual/stage_movement_gym.tscn -- --out=/tmp/movement-gym-shots
const GYM := preload("res://maps/traversal_gym.tscn")
var _out := "/tmp/movement-gym-shots/"

func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.trim_prefix("--out=").trim_suffix("/") + "/"
	DirAccess.make_dir_recursive_absolute(_out)
	AudioServer.set_bus_mute(0, true)
	var gym = GYM.instantiate()
	add_child(gym)
	await _frames(15)
	var above := Camera3D.new()
	add_child(above)
	above.projection = Camera3D.PROJECTION_ORTHOGONAL
	above.size = 210.0
	above.global_position = Vector3(54, 150, -66)
	above.look_at(Vector3(54, 0, -66), Vector3.FORWARD)
	above.current = true
	await _frames(5)
	await _shot("overview")
	gym.player.camera.current = true
	for index in [0, 3, 8, 9, 10, 11, 13, 14, 15]:
		gym.select_station(index)
		await _frames(10)
		await _shot("station_%02d" % (index + 1))
		if index == 13:
			above.size = 23.0
			above.global_position = gym.stations[index].root.global_position + Vector3(0, 18, -8)
			above.look_at(gym.stations[index].root.global_position + Vector3(0, 0, -9), Vector3.FORWARD)
			above.current = true
			await _frames(5)
			await _shot("station_14_water_geometry")
			gym.player.camera.current = true
	gym._guard_enabled = true
	gym._enable_guard()
	await gym._baker.baked
	await _frames(20)
	await _shot("guard_relay")
	get_tree().quit()

func _shot(label: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(_out + label + ".png")

func _frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame
