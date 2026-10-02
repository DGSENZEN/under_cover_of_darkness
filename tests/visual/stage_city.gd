extends Node3D
## Compare the actual city's streets and harbour at fixed viewpoints.
const City := preload("res://maps/city.tscn")
var out := "/tmp/city-shots/"

func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.trim_prefix("--out=").trim_suffix("/") + "/"
	DirAccess.make_dir_recursive_absolute(out)
	AudioServer.set_bus_mute(0, true)
	var city := City.instantiate()
	add_child(city)
	await city.ready_to_play
	city.player.set_physics_process(false)
	city.night.set_process(false)
	await _shot("spawn")
	var camera := Camera3D.new()
	add_child(camera)
	camera.current = true
	camera.fov = 75
	for pair in [
		["streets", Vector3(-55, 4.2, -25), Vector3(-55, 5.5, -65)],
		["harbour", Vector3(-120, 6, 12), Vector3(-150, 12, -14)],
		["waterline", Vector3(-35, 2.0, 10), Vector3(-45, 0, 0)],
	]:
		camera.position = pair[1]
		camera.look_at(pair[2])
		await _shot(String(pair[0]))
	print("PASS city street, harbour and waterline captures")
	get_tree().quit()

func _shot(label: String) -> void:
	for i in 20:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out + label + ".png")
