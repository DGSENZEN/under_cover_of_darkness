extends Node3D
## Windowed --fixed-fps 60 --resolution 1280x720, then -- --out=DIR [--clips] [--clip=view] [--only=a,b].
## --clip=view records that one view for six seconds from the moment the eye arrives (its books opening).
const MAP := preload("res://maps/underground_library_lab.tscn")
var out := "/tmp/underground_library_stills/"
var eye: Camera3D

func _ready() -> void:
	var clips := false
	var clip := ""
	var only := PackedStringArray()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.trim_prefix("--out=").trim_suffix("/") + "/"
		elif arg.begins_with("--only="):
			only = arg.trim_prefix("--only=").split(",")
		elif arg.begins_with("--clip="):
			clip = arg.trim_prefix("--clip=")
		clips = clips or arg == "--clips"
	DirAccess.make_dir_recursive_absolute(out)
	AudioServer.set_bus_mute(0, true)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var map := MAP.instantiate()
	add_child(map)
	await _frames(8)
	map.player.queue_free()
	map.keys_label.visible = false
	eye = Camera3D.new()
	eye.fov = 62.0
	add_child(eye)
	eye.make_current()
	var lib: Node3D = map.library
	var views := [
		["joined_corridor", Vector3(-3, 1.75, 3.2), Vector3(13, 1.8, 0.6)],
		["library_entrance", Vector3(9.3, 1.7, 1.1), Vector3(15.6, 1.65, 1.1)],
		["library_back_out", lib.to_global(Vector3(-2.45, 1.65, -4.8)), lib.to_global(Vector3(0, 1.6, 2))],
		["alive_cage", lib.to_global(Vector3(-0.95, 1.5, -4.3)), lib.to_global(Vector3(-1.85, 0.9, -5.8))],
		["alive_pages", lib.to_global(Vector3(2.1, 1.75, -1.1)), lib.to_global(Vector3(2.9, 0.88, -0.3))],
		["alive_spell", lib.to_global(Vector3(-2.5, 1.75, -1.3)), lib.to_global(Vector3(-2.8, 1.1, -0.4))],
		["chained_cover", lib.to_global(Vector3(-1.3, 1.4, -3.95)), lib.to_global(Vector3(-0.95, 1.1, -4.4))],
		["shop_inside", lib.to_global(Vector3(0.0, 1.7, -0.6)), lib.to_global(Vector3(0.0, 1.5, -6.0))],
		["shop_corner", lib.to_global(Vector3(0.0, 1.6, -2.4)), lib.to_global(Vector3(0.0, 1.2, -6.0))],
		["aisle_left", lib.to_global(Vector3(-2.45, 1.7, -1.3)), lib.to_global(Vector3(-2.45, 1.4, -6.0))],
		["aisle_right", lib.to_global(Vector3(2.45, 1.7, -1.3)), lib.to_global(Vector3(2.45, 1.4, -6.0))],
		["shelf_necromancy", lib.to_global(Vector3(-2.3, 1.65, -4.6)), lib.to_global(Vector3(-3.6, 1.4, -4.8))],
		["shelf_alchemy", lib.to_global(Vector3(2.3, 1.65, -1.8)), lib.to_global(Vector3(3.6, 1.4, -1.7))],
		["chrono_open", lib.to_global(Vector3(-2.45, 1.6, -0.9)), lib.to_global(Vector3(-3.7, 1.15, -1.3))],
		["chrono_close", lib.to_global(Vector3(-3.0, 1.32, -1.0)), lib.to_global(Vector3(-3.72, 1.2, -1.28))],
		["necro_open", lib.to_global(Vector3(-2.5, 1.75, -3.9)), lib.to_global(Vector3(-3.72, 1.55, -4.35))],
		["necro_close", lib.to_global(Vector3(-3.05, 1.68, -4.05)), lib.to_global(Vector3(-3.74, 1.6, -4.33))],
		["alch_open", lib.to_global(Vector3(2.5, 1.75, -1.25)), lib.to_global(Vector3(3.72, 1.55, -1.5))],
		["alch_close", lib.to_global(Vector3(3.05, 1.68, -1.38)), lib.to_global(Vector3(3.74, 1.58, -1.55))],
	]
	if not clip.is_empty():
		for view in views:
			if view[0] == clip:
				await _frames(90)
				_place(view[1], view[2])
				for i in 180:
					_capture("%s_%03d.png" % [view[0], i])
					await _frames(2)
		get_tree().quit()
		return
	for view in views:
		if not only.is_empty() and view[0] not in only:
			continue
		_place(view[1], view[2])
		await _frames(100)
		_capture(view[0] + ".png")
	if clips:
		# (Settled first: with no stills before it, the walk began before the map's light and fog had come up.)
		await _frames(90)
		var start := Vector3(7.2, 1.7, 1.1)
		var end: Vector3 = lib.to_global(Vector3(0, 1.7, -3.1))
		for i in 240:
			_place(start.lerp(end, smoothstep(0, 1, i / 239.0)), end + Vector3(2, -0.05, 0))
			_capture("walk_%03d.png" % i)
			await _frames(2)
		for view in [views[3], views[4], views[6]]:
			_place(view[1], view[2])
			await _frames(90)
			for i in 180:
				if view[0] == "chained_cover" and i % 75 == 0:
					lib.chained.strain_now()
				_capture("%s_%03d.png" % [view[0], i])
				await _frames(2)
	get_tree().quit()

func _place(from: Vector3, target: Vector3) -> void:
	eye.global_transform = Transform3D(Basis.IDENTITY, from).looking_at(target, Vector3.UP)

func _capture(file: String) -> void:
	RenderingServer.force_draw(false)
	get_viewport().get_texture().get_image().save_png(out + file)
	if file.get_basename().right(3).is_valid_int() == false:
		print("capture: ", file)

func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame
