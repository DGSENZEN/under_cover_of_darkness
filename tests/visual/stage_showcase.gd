extends Node
## Windowed staging of the NPC showcase: a still of every beat of the night
## as the auto-director frames it (the whole night with the escape ending,
## then Act V again for the other two endings), or the yard at rest (--rest);
## all put together in sheet.png, each still labelled with its act and beat.
## Not a test (nothing is checked): look at the pictures.
##   Godot --fixed-fps 60 --resolution 1280x720 --path . res://tests/visual/stage_showcase.tscn -- --out=<dir> [--rest]

const MAP := preload("res://maps/npc_showcase.tscn")
const MapScript := preload("res://maps/npc_showcase.gd")
const DirectorScript := preload("res://scripts/Showcase/ShowDirector.gd")

## [name, camera position, looked at]: the yard at rest (--rest).
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
## How long into a beat its still is taken (the camera has glided there).
const INTO_BEAT := 2.5
## The sheet: each still this big, this many across.
const THUMB := Vector2i(320, 180)
const ACROSS := 5
const ROMAN := ["", "I", "II", "III", "IV", "V"]

var _out := "user://stage_showcase/"
var _stills: Array = []
var _label: Label


func _ready() -> void:
	var rest := false

	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.trim_prefix("--out=").trim_suffix("/") + "/"
		elif arg == "--rest":
			rest = true

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

	if rest:
		await _rest()
	else:
		await _night(1, &"escape")
		await _night(5, &"overwhelmed")
		await _night(5, &"victor")

	_sheet()
	print("staged %d stills" % _stills.size())
	get_tree().quit()


## A night from `act` with `ending`: a still of each beat.
func _night(act: int, ending: StringName) -> void:
	DirectorScript.start_act = act
	DirectorScript.ending = ending
	MapScript.run_show = true
	var map: Node = MAP.instantiate()
	add_child(map)
	await map.ready_to_show
	var pending := []
	map.director.beat_started.connect(func(beat: StringName, _scene: Dictionary) -> void:
		pending.append([map.director.act_index, beat, 0.0]))
	var ended := [false]
	map.director.show_ended.connect(func() -> void: ended[0] = true)

	while not ended[0]:
		await get_tree().physics_frame

		for p in pending.duplicate():
			p[2] += 1.0 / 60.0

			if p[2] >= INTO_BEAT:
				pending.erase(p)
				await _still("%s %s%s" % [ROMAN[p[0]], p[1], " (%s)" % ending if p[0] == 5 else ""])

	map.queue_free()

	for child in get_children():
		if child != map and not (child is CanvasLayer):
			child.queue_free()

	await get_tree().physics_frame


func _rest() -> void:
	MapScript.run_show = false
	var map: Node = MAP.instantiate()
	add_child(map)
	await map.ready_to_show

	for f in 1200:
		await get_tree().physics_frame

	var camera := Camera3D.new()
	camera.fov = 55.0
	add_child(camera)
	camera.make_current()

	for shot in REST_SHOTS:
		camera.global_position = shot[1]
		camera.look_at(shot[2], Vector3.UP)
		await _still("rest %s" % shot[0])


func _still(title: String) -> void:
	_label.text = title
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var file := "%02d_%s.png" % [_stills.size(), title.replace(" ", "_").replace("(", "").replace(")", "")]
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
