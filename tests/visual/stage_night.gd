extends Node
## Windowed staging of the night and its weather in the showcase yard: every
## state (clear, cloudy, drizzle, shower, storm, fog) from four places, then
## the moon close, a cloud over it, and a lightning flash; all put together in
## sheet.png. Not a test (nothing is checked): look at the pictures.
##   Godot --fixed-fps 60 --resolution 1280x720 --path . res://tests/visual/stage_night.tscn -- --out=<dir>

const MAP := preload("res://maps/npc_showcase.tscn")
const MapScript := preload("res://maps/npc_showcase.gd")
const NightScript := preload("res://scripts/Night/Night.gd")

## [name, camera position, looked at (null: toward the moon)].
const VIEWS := [
	["toward the moon", Vector3(4, 1.7, 9), null],
	["over the north wall", Vector3(-4, 6.2, -13.5), Vector3(-4, 9, -60)],
	["the yard from the tower", Vector3(18.5, 12.0, -13.5), Vector3(0, 0, 4)],
	["south, over the gate", Vector3(0, 1.7, 11), Vector3(0, 7, 45)],
]
const THUMB := Vector2i(320, 180)
const ACROSS := 4

var _out := "user://stage_night/"
var _stills: Array = []
var _label: Label


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.trim_prefix("--out=").trim_suffix("/") + "/"

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out) if _out.begins_with("user://") else _out)
	AudioServer.set_bus_mute(0, true)
	var layer := CanvasLayer.new()
	layer.layer = 20
	add_child(layer)
	_label = Label.new()
	_label.position = Vector2(10, 8)
	_label.add_theme_font_size_override(&"font_size", 20)
	_label.add_theme_color_override(&"font_color", Color(1.0, 0.9, 0.3))
	_label.add_theme_color_override(&"font_outline_color", Color.BLACK)
	_label.add_theme_constant_override(&"outline_size", 6)
	layer.add_child(_label)

	MapScript.run_show = false
	var map: Node = MAP.instantiate()
	add_child(map)
	await map.ready_to_show

	for f in 600:
		await get_tree().physics_frame

	var night: Node = map.night
	var camera := Camera3D.new()
	camera.fov = 50.0
	add_child(camera)
	camera.make_current()
	var toward_moon: Vector3 = night.moon.global_basis.z

	for state in NightScript.ORDER:
		night.to(state, 0.0)
		night.wetness = night.rain()

		for f in 180:
			await get_tree().process_frame

		for view in VIEWS:
			camera.global_position = view[1]
			camera.look_at(view[1] + toward_moon * 20.0 if view[2] == null else view[2], Vector3.UP)

			for f in 20:
				await get_tree().process_frame

			await _still("%s: %s" % [state, view[0]])

	# The moon close, a cloud over it, a flash.
	night.to(&"clear", 0.0)
	night.wetness = 0.0
	camera.fov = 18.0
	camera.global_position = Vector3(0, 1.7, 6)
	camera.look_at(camera.global_position + toward_moon * 20.0, Vector3.UP)

	for f in 60:
		await get_tree().process_frame

	await _still("the moon")
	night.cover_moon(10.0)

	for f in 270:
		await get_tree().process_frame

	await _still("a cloud over the moon")
	night.cover_moon(0.0)
	night.to(&"storm", 0.0)
	camera.fov = 50.0
	camera.global_position = Vector3(18.5, 12.0, -13.5)
	camera.look_at(Vector3(0, 0, 4), Vector3.UP)

	for f in 120:
		await get_tree().process_frame

	night.flash()
	await get_tree().process_frame
	await _still("lightning")
	_sheet()
	print("staged %d stills" % _stills.size())
	get_tree().quit()


func _still(title: String) -> void:
	_label.text = title
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var file := "%02d_%s.png" % [_stills.size(), title.replace(" ", "_").replace(":", "").replace(",", "")]
	image.save_png(_out + file)
	_stills.append(image)


func _sheet() -> void:
	if _stills.is_empty():
		return

	var rows := int(ceil(float(_stills.size()) / ACROSS))
	var sheet := Image.create(THUMB.x * ACROSS, THUMB.y * rows, false, Image.FORMAT_RGB8)

	for i in _stills.size():
		var still: Image = (_stills[i] as Image).duplicate()
		still.convert(Image.FORMAT_RGB8)
		still.resize(THUMB.x, THUMB.y, Image.INTERPOLATE_BILINEAR)
		sheet.blit_rect(still, Rect2i(Vector2i.ZERO, THUMB), Vector2i((i % ACROSS) * THUMB.x, (i / ACROSS) * THUMB.y))

	sheet.save_png(_out + "sheet.png")
