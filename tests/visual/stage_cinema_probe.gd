extends Node
## Windowed probe for the Cinema camera (not a test: look at the pictures).
## Osric at the fire, close, without and with depth of field, and the frame
## as the viewport hands it back (does it carry the retro grid?); the frame
## rate both ways.
##   Godot --fixed-fps 60 --resolution 1920x1080 --path . res://tests/visual/stage_cinema_probe.tscn -- --out=<dir>

const MAP := preload("res://maps/npc_showcase.tscn")
const MapScript := preload("res://maps/npc_showcase.gd")

var _out := "user://stage_cinema_probe/"


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

	for f in 600:
		await get_tree().physics_frame

	var osric: Node3D = map.cast["Osric"]
	var head := osric.global_position + Vector3.UP * 1.6
	var ahead := -osric.global_basis.z
	ahead.y = 0.0
	var camera := Camera3D.new()
	camera.fov = 40.0
	add_child(camera)
	camera.global_position = head + ahead.normalized() * 2.2 + Vector3.UP * 0.1
	camera.look_at(head, Vector3.UP)
	camera.make_current()

	await _frames(30)
	var off := await _fps()
	await _save("dof_off.png")

	var attributes := CameraAttributesPractical.new()
	attributes.dof_blur_far_enabled = true
	attributes.dof_blur_far_distance = camera.global_position.distance_to(head) + 1.5
	attributes.dof_blur_far_transition = 2.0
	attributes.dof_blur_amount = 0.12
	camera.attributes = attributes
	await _frames(30)
	var on := await _fps()
	await _save("dof_on.png")
	await _save("capture.png")
	print("[probe] fps off %.1f on %.1f" % [off, on])
	get_tree().quit()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


## The frame rate over 120 drawn frames (real time).
func _fps() -> float:
	var start := Time.get_ticks_usec()
	await _frames(120)
	return 120.0 / (float(Time.get_ticks_usec() - start) / 1000000.0)


func _save(file: String) -> void:
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(_out + file)
