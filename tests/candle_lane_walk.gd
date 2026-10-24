extends Node3D
## The candle lane's walk (docs/superpowers/plans/2026-10-23-candle-lane.md, Task 8): from his arch, a look back at the
## chapel's quiet, then west down the lane past her stall's noise and light, the niche's stillness, out to the mouth's
## neon. Windowed --fixed-fps 60 --resolution 1280x720, then -- --out=DIR: JPEG frames, 30 a second (game time as it
## runs), for ffmpeg; a caption names each pocket as the walk reaches it. Sound is marked and silent: none is recorded.
const LANE := preload("res://maps/candle_lane.tscn")
const RATE := 30
## The walk: [where the eye is, what it looks at, seconds to get there from the last, the caption from there on].
const WALK := [
	[Vector3(5.6, 1.65, 1.4), Vector3(16.0, 1.3, 0.6), 0.0, "his arch: quiet (the chapel's end beyond)"],
	[Vector3(5.6, 1.65, 1.4), Vector3(6.2, 1.5, 4.6), 3.0, "his arch: quiet"],
	[Vector3(4.6, 1.65, 1.3), Vector3(-2.0, 1.4, 0.6), 2.5, "her stall: loud"],
	[Vector3(1.6, 1.65, 1.5), Vector3(-1.0, 1.4, -1.0), 3.0, "her stall: loud"],
	[Vector3(-4.0, 1.65, 1.4), Vector3(-10.0, 1.3, -1.6), 4.0, "the niche: quiet"],
	[Vector3(-8.0, 1.65, 1.0), Vector3(-10.0, 1.2, -2.3), 3.0, "the niche: quiet"],
	[Vector3(-11.5, 1.65, 1.1), Vector3(-20.0, 1.7, 1.1), 3.5, "the mouth: loud"],
	[Vector3(-13.3, 1.65, 1.5), Vector3(-21.0, 1.7, 0.6), 3.0, "the mouth: loud"],
	[Vector3(-13.6, 1.65, 1.6), Vector3(-21.0, 1.6, 2.0), 6.0, "the mouth: loud (the Pasaje's crowd)"],
]

var out := "/tmp/candle_lane_walk/"
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
	var lane: Node3D = LANE.instantiate()
	add_child(lane)
	await _frames(8)
	lane.player.queue_free()
	if lane.get("keys_label") != null:
		lane.keys_label.visible = false
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
	_place(lane.to_global(WALK[0][0]), lane.to_global(WALK[0][1]))
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
			_place(lane.to_global((a[0] as Vector3).lerp(b[0], t)), lane.to_global((a[1] as Vector3).lerp(b[1], t)))
			await _frames(2)
			_capture()
	print("walk: %d frames" % written)
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
