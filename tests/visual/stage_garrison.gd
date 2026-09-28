extends Node
## Windowed staging of the garrison: a still from every vantage the level
## marks and from inside each space, the night clear; then the courtyard under
## a cloud (everything shadow and torchlight); all in sheet.png. Not a test:
## look at the pictures.
##   Godot --fixed-fps 60 --resolution 1280x720 --path . res://tests/visual/stage_garrison.tscn -- --out=<dir>

const GARRISON := preload("res://maps/garrison.tscn")
const MapScript := preload("res://maps/npc_showcase.gd")

## [name, camera position, looked at] inside the spaces (beside the vantages).
const INSIDE := [
	["the gate passage", Vector3(0.0, 1.7, 22.5), Vector3(0.0, 1.8, 32.0)],
	["the corridor", Vector3(15.4, 1.7, -19.0), Vector3(15.4, 1.6, 17.0)],
	["the mess, to the hearth", Vector3(17.6, 1.7, 1.0), Vector3(29.0, 1.2, 1.0)],
	["the mess from the gallery", Vector3(15.4, 4.8, -7.0), Vector3(24.0, 0.5, 4.0)],
	["the dormitory", Vector3(17.6, 4.7, 11.0), Vector3(28.0, 3.5, 15.0)],
	["the captain's chamber", Vector3(18.0, 4.7, -9.0), Vector3(28.0, 3.6, -14.0)],
	["the chapel nave", Vector3(-4.6, 1.8, -20.8), Vector3(12.0, 2.5, -20.8)],
	["the chapel from the loft", Vector3(13.0, 4.8, -17.0), Vector3(-4.0, 1.0, -22.0)],
	["the colonnade", Vector3(-18.0, 1.6, -13.0), Vector3(-18.0, 1.4, 18.0)],
	["the armoury", Vector3(-21.0, 1.7, -3.0), Vector3(-29.0, 1.2, -12.0)],
	["the cellar", Vector3(-27.0, -1.3, 11.4), Vector3(-26.0, -2.5, 0.0)],
	["the tower's flights", Vector3(-30.5, 1.7, -24.2), Vector3(-31.0, 9.0, -28.0)],
	["the wall-walk", Vector3(-26.0, 6.7, 26.8), Vector3(26.0, 5.5, 26.8)],
	["the quay", Vector3(-24.0, 1.7, 40.0), Vector3(6.0, 3.0, 30.0)],
]
const THUMB := Vector2i(320, 180)
const ACROSS := 4

var _out := "user://stage_garrison/"
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
	var map: Node = GARRISON.instantiate()
	add_child(map)
	await map.ready_to_show

	for f in 300:
		await get_tree().physics_frame

	var camera := Camera3D.new()
	camera.fov = 55.0
	add_child(camera)
	camera.make_current()

	for view in INSIDE:
		await _shot(camera, view[0], view[1], view[2])

	for vantage in get_tree().get_nodes_in_group(&"cine_vantage"):
		var at: Vector3 = (vantage as Node3D).global_position
		await _shot(camera, "vantage %s" % (vantage as Node).name, at, _looking_from(map, at))

	# The courtyard under a cloud: everything shadow and torchlight.
	map.night.cover_moon(30.0)

	for f in 300:
		await get_tree().process_frame

	await _shot(camera, "the courtyard, the moon covered", Vector3(-14.0, 7.0, 20.0), Vector3(4.0, 0.0, -2.0))
	await _shot(camera, "the colonnade, the moon covered", Vector3(-18.0, 1.6, -13.0), Vector3(-18.0, 1.4, 18.0))
	_sheet()
	print("staged %d stills" % _stills.size())
	get_tree().quit()


## Where a vantage looks for its still: down the length of the room it is in
## (the far corner of the smallest zone round it), else at the courtyard.
func _looking_from(map: Node, at: Vector3) -> Vector3:
	var best := AABB()

	for m in map.level.of("zone"):
		var size: Vector3 = m["size"]
		var box := AABB((m["transform"] as Transform3D).origin - size * 0.5, size)

		if box.grow(0.5).has_point(at) and (not best.has_volume() or box.get_volume() < best.get_volume()):
			best = box

	if not best.has_volume():
		return Vector3(0.0, 1.0, 2.0)

	var far := at

	for corner in [Vector2(0, 0), Vector2(1, 0), Vector2(0, 1), Vector2(1, 1)]:
		var point := best.position + Vector3(best.size.x * corner.x, 1.2, best.size.z * corner.y)

		if Vector2(point.x - at.x, point.z - at.z).length() > Vector2(far.x - at.x, far.z - at.z).length():
			far = point

	return far


func _shot(camera: Camera3D, title: String, at: Vector3, look: Vector3) -> void:
	camera.global_position = at
	camera.look_at(look, Vector3.UP)

	for f in 30:
		await get_tree().process_frame

	_label.text = title
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	image.save_png(_out + "%02d_%s.png" % [_stills.size(), title.replace(" ", "_").replace("'", "").replace(",", "")])
	_stills.append(image)


func _sheet() -> void:
	var rows := int(ceil(float(_stills.size()) / ACROSS))
	var sheet := Image.create(THUMB.x * ACROSS, THUMB.y * rows, false, Image.FORMAT_RGB8)

	for i in _stills.size():
		var still: Image = (_stills[i] as Image).duplicate()
		still.convert(Image.FORMAT_RGB8)
		still.resize(THUMB.x, THUMB.y, Image.INTERPOLATE_BILINEAR)
		sheet.blit_rect(still, Rect2i(Vector2i.ZERO, THUMB), Vector2i((i % ACROSS) * THUMB.x, (i / ACROSS) * THUMB.y))

	sheet.save_png(_out + "sheet.png")
