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
	# (The chained book strains only when the stills ask it to, so a view never catches one of its own halfway.)
	lib.chained._next = 1e9
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
		["meta_open", lib.to_global(Vector3(2.5, 1.5, -4.2)), lib.to_global(Vector3(3.72, 1.1, -4.55))],
		["meta_close", lib.to_global(Vector3(3.05, 1.3, -4.35)), lib.to_global(Vector3(3.74, 1.13, -4.55))],
		["hunt_open", lib.to_global(Vector3(2.9, 1.75, -4.4)), lib.to_global(Vector3(3.05, 1.55, -5.72))],
		["hunt_close", lib.to_global(Vector3(3.0, 1.66, -5.0)), lib.to_global(Vector3(3.05, 1.58, -5.72))],
		["novel_sword", lib.to_global(Vector3(3.15, 1.35, -0.95)), lib.to_global(Vector3(3.12, 1.02, -0.3))],
		["novel_rose", lib.to_global(Vector3(0.55, 1.85, -1.15)), lib.to_global(Vector3(1.15, 1.55, -1.6))],
		["spell_close", lib.to_global(Vector3(-2.55, 1.6, -1.05)), lib.to_global(Vector3(-2.8, 1.22, -0.4))],
		["words_wave", lib.to_global(Vector3(0.2, 1.7, -3.4)), lib.to_global(Vector3(0.0, 2.3, -1.0))],
		["words_stream", lib.to_global(Vector3(-2.2, 1.55, -1.4)), lib.to_global(Vector3(-2.8, 1.5, -0.4))],
		["floating_vault", lib.to_global(Vector3(0.0, 1.7, -0.6)), lib.to_global(Vector3(0.0, 3.1, -3.4))],
		["floating_home", lib.to_global(Vector3(-1.5, 1.8, -1.0)), lib.to_global(Vector3(-3.4, 1.95, -1.2))],
		["corner_ward_rest", lib.to_global(Vector3(0.6, 2.5, -1.9)), lib.to_global(Vector3(-0.1, 0.25, -4.5))],
		["corner_ward", lib.to_global(Vector3(0.6, 2.5, -1.9)), lib.to_global(Vector3(-0.1, 0.25, -4.5))],
		["corner_chained", lib.to_global(Vector3(-0.15, 1.6, -3.3)), lib.to_global(Vector3(-0.85, 0.85, -4.3))],
		["corner_words", lib.to_global(Vector3(0.9, 0.9, -2.7)), lib.to_global(Vector3(-0.3, 0.5, -4.1))],
		["rug_zapotec", lib.to_global(Vector3(-1.5, 1.7, -0.9)), lib.to_global(Vector3(-2.4, 0.0, -2.5))],
		["rug_persian", lib.to_global(Vector3(1.5, 1.7, -0.9)), lib.to_global(Vector3(2.4, 0.0, -2.6))],
		["rug_petate", lib.to_global(Vector3(1.5, 1.6, -1.5)), lib.to_global(Vector3(2.7, 0.0, -0.4))],
		["rug_sarape", lib.to_global(Vector3(-2.6, 1.5, -3.8)), lib.to_global(Vector3(-1.85, 0.0, -5.05))],
		["ward_candle", lib.to_global(Vector3(1.2, 0.4, -3.3)), lib.to_global(Vector3(0.9, 0.12, -3.64))],
	]
	if clip == "shadow":
		# Down the room, the necromancy case in the corner of the eye: he crosses its front; then the eye turns to look
		# at him, and he is gone.
		var at: Vector3 = lib.to_global(Vector3(-0.4, 1.65, -0.6))
		var ahead: Vector3 = lib.to_global(Vector3(-0.2, 1.4, -6.0))
		var shadow: Node3D = lib.effects.shadow
		await _frames(90)
		_place(at, ahead)
		await _frames(20)
		shadow.only = 1
		shadow.cross_now(1)
		var turned_to := Vector3.ZERO
		for i in 160:
			if i == 75:
				turned_to = shadow.shade.global_position
			if i >= 75 and i < 95:
				_place(at, ahead.lerp(turned_to, smoothstep(0.0, 1.0, (i - 75) / 19.0)))
			_capture("shadow_%03d.png" % i)
			await _frames(2)
		get_tree().quit()
		return
	if clip == "ward":
		# The ward from a swing across its front, high, the book made to strain every 5.3 s: each candle and the
		# salt's opening in sight in turn.
		var middle: Vector3 = lib.to_global(Vector3(0.0, 0.35, -4.5))
		await _frames(90)
		for i in 480:
			var a := deg_to_rad(lerpf(-62.0, 62.0, smoothstep(0.0, 1.0, i / 479.0)))
			_place(lib.to_global(Vector3(2.5 * sin(a), 2.3, -4.4 + 2.5 * cos(a))), middle)
			if i % 160 == 15:
				lib.chained.strain_now()
			_capture("ward_%03d.png" % i)
			await _frames(2)
		get_tree().quit()
		return
	if clip == "stir":
		# Looking at the chronology case, turning away to the vault until it has gone unseen long enough, its boards
		# stirring, turning back. The before and after also saved as stills.
		var at: Vector3 = lib.to_global(Vector3(-2.3, 1.6, -0.9))
		var case_look: Vector3 = lib.to_global(Vector3(-3.7, 1.25, -1.2))
		var away_look: Vector3 = lib.to_global(Vector3(1.5, 1.9, -1.6))
		var case: Node3D = lib.sections["chronology"]
		await _frames(90)
		_place(at, case_look)
		await _frames(30)
		_capture("stir_before.png")
		var frame := 0
		for i in 60:
			_capture("stir_%03d.png" % frame)
			frame += 1
			await _frames(2)
		for i in 45:
			_place(at, case_look.lerp(away_look, smoothstep(0.0, 1.0, i / 44.0)))
			_capture("stir_%03d.png" % frame)
			frame += 1
			await _frames(2)
		for i in 200:
			if i == 190:
				var stirred := 0
				for b in lib.book_spots.size():
					if lib.book_spots[b]["case"] == case and lib.stir.try_board(b):
						stirred += 1
				print("stirred boards: ", stirred)
			if i % 3 == 0:
				_capture("stir_%03d.png" % frame)
				frame += 1
			await _frames(2)
		for i in 45:
			_place(at, away_look.lerp(case_look, smoothstep(0.0, 1.0, i / 44.0)))
			_capture("stir_%03d.png" % frame)
			frame += 1
			await _frames(2)
		for i in 90:
			_capture("stir_%03d.png" % frame)
			frame += 1
			await _frames(2)
		_capture("stir_after.png")
		get_tree().quit()
		return
	if not clip.is_empty():
		for view in views:
			if view[0] == clip:
				await _frames(90)
				_place(view[1], view[2])
				# (A floating book sent home to the chronology case for the clip.)
				if clip == "floating_home":
					lib.floating.come_home(6)
				# (The ward's views: the book strains as the clip begins.)
				if clip.begins_with("corner_"):
					lib.chained.strain_now()
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
		# (The ward's views taken as the book strains, its words at the chalk; the rest view while it is still. Each
		# waits out the last view's words first: a strain while they are still out sends none.)
		if view[0] in ["corner_ward", "corner_chained", "corner_words"]:
			await _frames(140)
			lib.chained.strain_now()
			await _frames(96 if view[0] != "corner_chained" else 36)
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
