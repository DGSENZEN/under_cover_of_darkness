extends Node3D
## The candle lane in the Metro (docs/superpowers/plans/2026-10-23-candle-lane.md, Task 10): from the greybox Pasaje
## into the lane, past her stall, into the librarian's shop to his desk, back out and on through the chapel's doorway
## into the greybox chapel. Windowed --fixed-fps 60 --resolution 1280x720, then -- --out=DIR: JPEG frames, 30 a
## second (game time as it runs), for ffmpeg; a caption names each place. Sound is marked and silent.
const MAP := preload("res://maps/metro.tscn")
const RATE := 30
## The walk, in the plan's frame (the eye 1.65 m over the floor at -11): [where the eye is, what it looks at,
## seconds to get there from the last, the caption from there on].
const WALK := [
	[Vector3(-9.0, -9.35, 70.5), Vector3(-3.0, -9.6, 75.45), 0.0, "the Pasaje (greybox): the lane's mouth"],
	[Vector3(-6.5, -9.35, 74.6), Vector3(1.0, -9.6, 75.4), 3.0, "the Pasaje (greybox): the lane's mouth"],
	[Vector3(1.5, -9.35, 75.6), Vector3(12.0, -9.7, 74.5), 4.0, "the candle lane: her stall"],
	[Vector3(12.5, -9.35, 75.9), Vector3(19.0, -9.8, 79.5), 4.0, "the candle lane: his arch"],
	[Vector3(19.0, -9.35, 77.4), Vector3(19.0, -9.7, 84.0), 2.5, "the librarian's shop"],
	[Vector3(19.0, -9.35, 81.0), Vector3(20.5, -9.9, 84.5), 3.0, "the librarian's shop"],
	[Vector3(19.0, -9.35, 79.0), Vector3(25.0, -9.6, 75.0), 3.0, "the candle lane: the chapel's end"],
	[Vector3(26.0, -9.35, 75.0), Vector3(30.0, -9.5, 74.55), 3.0, "the candle lane: the chapel's doorway"],
	[Vector3(31.5, -9.35, 74.55), Vector3(44.0, -9.6, 72.5), 3.5, "the chapel (greybox), on to lane_se"],
]

var out := "/tmp/metro_lane_showcase/"
var eye: Camera3D
var caption: Label
var written := 0


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.trim_prefix("--out=").trim_suffix("/") + "/"
	DirAccess.make_dir_recursive_absolute(out)
	AudioServer.set_bus_mute(0, true)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var map: Node3D = MAP.instantiate()
	add_child(map)
	await _frames(30)
	# (The map's player out of the way, at the far platform: the eye walks alone.)
	map.player.global_position = map.spawn_point() + Vector3(0.0, 1.05, 0.0)
	eye = Camera3D.new()
	eye.fov = 70.0
	add_child(eye)
	eye.make_current()
	var screen := CanvasLayer.new()
	add_child(screen)
	caption = Label.new()
	caption.add_theme_font_size_override("font_size", 22)
	caption.add_theme_color_override("font_shadow_color", Color.BLACK)
	caption.position = Vector2(40, 660)
	screen.add_child(caption)
	_place(WALK[0][0], WALK[0][1])
	await _frames(90)
	caption.text = WALK[0][3]
	for i in 30:
		await _frames(2)
		_capture()
	for k in range(1, WALK.size()):
		var a: Array = WALK[k - 1]
		var b: Array = WALK[k]
		caption.text = b[3]
		var n := int(float(b[2]) * RATE)
		for i in n:
			var t := smoothstep(0.0, 1.0, float(i) / maxf(n - 1, 1))
			_place((a[0] as Vector3).lerp(b[0], t), (a[1] as Vector3).lerp(b[1], t))
			await _frames(2)
			_capture()
	print("showcase: %d frames" % written)
	get_tree().quit()


func _place(from: Vector3, target: Vector3) -> void:
	eye.global_transform = Transform3D(Basis.IDENTITY, from).looking_at(target, Vector3.UP)


func _capture() -> void:
	RenderingServer.force_draw(false)
	get_viewport().get_texture().get_image().save_jpg(out + "f_%05d.jpg" % written, 0.92)
	written += 1


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame
