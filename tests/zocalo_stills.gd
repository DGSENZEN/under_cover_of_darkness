extends Node3D
## Stills of the Zócalo's greybox (the Zócalo plan, Task 7), in a window
## (headless runs draw nothing):
##   Godot --path . --resolution 1920x1080 res://tests/zocalo_stills.tscn -- --out=/tmp/zocalo
## top_day.png from straight above, <camera>_day/_night.png from each of the
## plan's cameras, and sheet_cameras.png, the day views on one sheet.

const MAP := preload("res://maps/zocalo.tscn")
const FRAMES := 12
const THUMB := Vector2i(480, 270)
const COLUMNS := 4

var out := "/tmp/zocalo/"


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.trim_prefix("--out=").trim_suffix("/") + "/"

	DirAccess.make_dir_recursive_absolute(out)
	AudioServer.set_bus_mute(0, true)
	var map: Node3D = MAP.instantiate()
	add_child(map)
	await _frames(4)
	map.player.queue_free()
	var eye := Camera3D.new()
	eye.fov = 66.0
	eye.far = 2000.0
	add_child(eye)
	eye.make_current()

	# From straight above, the whole map.
	map.set_day(true)
	eye.projection = Camera3D.PROJECTION_ORTHOGONAL
	eye.size = 680.0
	eye.global_transform = Transform3D(Basis.from_euler(Vector3(-PI / 2, 0, 0)), Vector3(0, 500, -20))
	await _frames(FRAMES)
	_save("top_day.png")
	eye.projection = Camera3D.PROJECTION_PERSPECTIVE
	var thumbs := []

	for day in [true, false]:
		map.set_day(day)

		for c in map.cameras():
			eye.global_transform = Transform3D(Basis(), c["at"]).looking_at(c["look_at"], Vector3.UP)
			await _frames(FRAMES)
			var image := _save("%s_%s.png" % [c["name"], "day" if day else "night"])

			if day:
				image.resize(THUMB.x, THUMB.y, Image.INTERPOLATE_BILINEAR)
				thumbs.append(image)

	var rows := ceili(thumbs.size() / float(COLUMNS))
	var sheet := Image.create(THUMB.x * COLUMNS, THUMB.y * rows, false, thumbs[0].get_format())

	for i in thumbs.size():
		sheet.blit_rect(thumbs[i], Rect2i(Vector2i.ZERO, THUMB), Vector2i((i % COLUMNS) * THUMB.x, (i / COLUMNS) * THUMB.y))

	sheet.save_png(out + "sheet_cameras.png")
	print("still: ", out + "sheet_cameras.png")
	get_tree().quit()


func _save(file: String) -> Image:
	var image := get_viewport().get_texture().get_image()
	image.save_png(out + file)
	print("still: ", out + file)
	return image


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame
