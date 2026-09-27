extends Node
## Windowed staging of the NPC showcase: stills of the yard and its people.
## Not a test (nothing is checked): look at the pictures.
##   Godot --path . --resolution 1280x720 res://tests/visual/stage_showcase.tscn -- --out=<dir>

const MAP := preload("res://maps/npc_showcase.tscn")
const MapScript := preload("res://maps/npc_showcase.gd")

## [name, camera position, looked at].
const REST_SHOTS := [
	["wide", Vector3(16, 24, 26), Vector3(-1, 0, -2)],
	["fire", Vector3(5.5, 3.2, 6.0), Vector3(0, 0.8, 0)],
	["store", Vector3(8.0, 4.0, 4.0), Vector3(14.5, 0.6, -1.0)],
	["shed", Vector3(-12.0, 3.5, 5.0), Vector3(-18.0, 0.3, -1.0)],
	["wall", Vector3(4.0, 6.0, -6.0), Vector3(10.0, 3.0, -14.5)],
	["woodpile", Vector3(-7.5, 3.5, 15.0), Vector3(-12.5, 0.6, 11.0)],
	["cart", Vector3(4.5, 3.5, 5.0), Vector3(9.0, 0.8, 9.5)],
	["postern", Vector3(13.5, 4.5, -3.0), Vector3(19.5, 0.8, -9.0)],
]

var _out := "user://stage_showcase/"


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.trim_prefix("--out=").trim_suffix("/") + "/"

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out) if _out.begins_with("user://") else _out)
	AudioServer.set_bus_mute(0, true)
	MapScript.run_show = false
	var map: Node = MAP.instantiate()
	add_child(map)
	await map.ready_to_show

	# The yard settles: everyone to his station.
	for f in 1200:
		await get_tree().physics_frame

	var camera := Camera3D.new()
	camera.fov = 55.0
	add_child(camera)
	camera.make_current()

	for shot in REST_SHOTS:
		camera.global_position = shot[1]
		camera.look_at(shot[2], Vector3.UP)
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(_out + "rest_%s.png" % shot[0])

	print("staged %d shots" % REST_SHOTS.size())
	get_tree().quit()
