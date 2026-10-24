extends Node3D
## Stills of the candle lane set: windowed --fixed-fps 60 --resolution 1280x720, then -- --out=DIR [--only=a,b].
## Views in the lane's own frame (x along it, z across: the north wall at -2.35, the south at 4.55).
const LANE := preload("res://maps/candle_lane.tscn")
var out := "/tmp/candle_lane_stills/"
var eye: Camera3D


func _ready() -> void:
	var only := PackedStringArray()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.trim_prefix("--out=").trim_suffix("/") + "/"
		elif arg.begins_with("--only="):
			only = arg.trim_prefix("--only=").split(",")
	DirAccess.make_dir_recursive_absolute(out)
	AudioServer.set_bus_mute(0, true)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var lane: Node3D = LANE.instantiate()
	add_child(lane)
	await _frames(8)
	lane.player.queue_free()
	if lane.get("keys_label") != null:
		lane.keys_label.visible = false
	eye = Camera3D.new()
	eye.fov = 62.0
	add_child(eye)
	eye.make_current()
	var views := [
		["lane_from_mouth", Vector3(-19.0, 1.7, 1.1), Vector3(10.0, 1.6, 1.1)],
		["lane_from_chapel", Vector3(15.8, 1.7, 0.6), Vector3(-15.0, 1.6, 1.1)],
		["lane_shop_front", Vector3(6.2, 1.7, -1.6), Vector3(6.2, 1.5, 6.0)],
		["lane_shop_angle", Vector3(-3.5, 1.7, 1.6), Vector3(8.0, 1.4, 4.55)],
		["lane_stall", Vector3(-7.0, 1.7, 2.6), Vector3(-0.5, 1.2, -1.6)],
		["lane_niche", Vector3(-5.5, 1.7, 2.8), Vector3(-10.5, 1.1, 0.0)],
		["lane_services", Vector3(-16.0, 2.2, 1.1), Vector3(16.0, 3.2, 1.1)],
		["lane_chapel_end", Vector3(8.0, 1.7, 1.1), Vector3(17.0, 1.4, 0.6)],
		["lane_doorway", Vector3(13.5, 1.6, 0.4), Vector3(17.5, 1.6, 0.15)],
		["lane_votives", Vector3(11.0, 1.55, 0.2), Vector3(13.0, 1.0, -2.35)],
		["lane_milagros", Vector3(15.2, 1.6, 2.4), Vector3(16.8, 1.5, 2.85)],
		["lane_mouth_out", Vector3(-11.0, 1.7, 1.1), Vector3(-22.0, 1.8, 1.1)],
		["lane_mouth_in", Vector3(-24.0, 1.7, 3.0), Vector3(-14.0, 2.0, 1.1)],
		["lane_puesto", Vector3(-21.5, 1.6, 2.5), Vector3(-17.5, 1.2, 6.2)],
		["lane_arrows", Vector3(-11.5, 1.7, 2.6), Vector3(-14.2, 2.05, -2.35)],
	]
	for view in views:
		if not only.is_empty() and view[0] not in only:
			continue
		_place(lane.to_global(view[1]), lane.to_global(view[2]))
		await _frames(100)
		_capture(view[0] + ".png")
	get_tree().quit()


func _place(from: Vector3, target: Vector3) -> void:
	eye.global_transform = Transform3D(Basis.IDENTITY, from).looking_at(target, Vector3.UP)


func _capture(file: String) -> void:
	RenderingServer.force_draw(false)
	get_viewport().get_texture().get_image().save_png(out + file)
	print("capture: ", file)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame
