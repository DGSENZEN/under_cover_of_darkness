extends Node3D
## Camera staging only; production scenes and supernatural behaviours are unchanged.
## --write-movie /tmp/environment.avi --fixed-fps 30 --resolution 1920x1080
## res://tests/environment_showcase.tscn -- [--preview=/tmp/frames] [--only=shot_name]
const MAP := preload("res://maps/underground_library_lab.tscn")
var map: Node3D
var eye: Camera3D
var aside: Camera3D
var shots: Array = []
var preview := ""
var only := ""

func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--preview="):
			preview = arg.trim_prefix("--preview=")
		elif arg.begins_with("--only="):
			only = arg.trim_prefix("--only=")
	if not preview.is_empty():
		DirAccess.make_dir_recursive_absolute(preview)
		AudioServer.set_bus_mute(0, true)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	map = MAP.instantiate()
	add_child(map)
	map.player.queue_free()
	map.keys_label.visible = false
	eye = Camera3D.new()
	eye.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	eye.fov = 62
	eye.doppler_tracking = Camera3D.DOPPLER_TRACKING_DISABLED
	add_child(eye)
	eye.make_current()
	aside = Camera3D.new()
	aside.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	add_child(aside)
	aside.position = Vector3(0, 1.6, 1)
	aside.look_at(Vector3(0, 1.6, -5))
	map.ownerless.watcher = aside
	map.nahual.intruder = null
	map.animas.flee_from = null
	_shots()
	_place(shots[0], 0)
	await _frames(90)
	var timeline := 0.0
	for shot: Dictionary in shots:
		if not only.is_empty() and shot.name != only:
			continue
		_place(shot, 0)
		_cue(shot.name)
		print("SHOT %.2f %s (%s s)" % [timeline, shot.name, shot.seconds])
		for frame in int(shot.seconds * 30):
			var t := frame / maxf(shot.seconds * 30 - 1, 1)
			_place(shot, smoothstep(0, 1, t))
			if shot.name == "chained_book" and frame % 75 == 0:
				map.library.chained.strain_now()
			if not preview.is_empty() and frame in [int(shot.seconds * 7.5), int(shot.seconds * 15), int(shot.seconds * 22.5)]:
				RenderingServer.force_draw(false)
				get_viewport().get_texture().get_image().save_png("%s/%s_%03d.png" % [preview, shot.name, frame])
			await get_tree().process_frame
		timeline += shot.seconds
	print("SHOWCASE COMPLETE %.2f seconds plus 3-second opening hold" % timeline)
	get_tree().quit()

func _cue(name: String) -> void:
	map.animas.flee_from = null
	map.nahual.intruder = eye if name == "nahual_scatter" else null
	match name:
		"animas_drain":
			for i in 3:
				map.animas.rise_now()
		"nahual_watch":
			map.nahual.appear()
		"procession":
			map.procession.start()
			map.procession._process(7.0)
		"ownerless_shadow":
			map.ownerless.cross_now()
			map.ownerless._process(4.0)
		"dark_train":
			map.dark_train.start_pass()
			map.dark_train._process(2.0)

func _place(shot: Dictionary, t: float) -> void:
	var from: Vector3 = shot.from.lerp(shot.to, t)
	var target: Vector3 = shot.look.lerp(shot.look_end, t)
	eye.global_transform = Transform3D(Basis.IDENTITY, from).looking_at(target, Vector3.UP)

func _add(name: String, seconds: float, from: Vector3, to: Vector3, look: Vector3, look_end: Variant = null, library := false) -> void:
	var target_end: Vector3 = look if look_end == null else look_end
	if library:
		from = map.library.to_global(from)
		to = map.library.to_global(to)
		look = map.library.to_global(look)
		target_end = map.library.to_global(target_end)
	shots.append({"name": name, "seconds": seconds, "from": from, "to": to, "look": look, "look_end": target_end})

func _shots() -> void:
	_add("corridor", 7, Vector3(-10,1.7,2.7), Vector3(-6,1.7,2.8), Vector3(4,1.8,0.7))
	_add("stall", 7, Vector3(3,1.7,3.2), Vector3(-1.8,1.65,2.5), Vector3(0,1.45,-0.4))
	_add("ofrenda", 6, Vector3(-0.5,1.5,0.85), Vector3(-1.7,1.45,0.9), Vector3(-1.13,1.25,-0.3))
	_add("animas_drain", 8, Vector3(-2.9,1.1,0.1), Vector3(-2.65,0.95,-0.1), Vector3(-1.9,0.45,-1.5))
	_add("animas_candles", 8, Vector3(-1.45,1.55,0.65), Vector3(-0.65,1.55,1.05), Vector3(-1.15,1.25,-0.4))
	_add("nahual_watch", 8, Vector3(-3.5,1.25,1.6), Vector3(-5.8,1.1,1.8), Vector3(-5,0.65,3.7))
	_add("nahual_scatter", 5, Vector3(-5.8,1.1,1.8), Vector3(-5.2,1.1,3.35), Vector3(-5,0.65,3.65))
	_add("procession", 9, Vector3(-0.2,1.65,2.3), Vector3(-4,1.55,1.5), Vector3(-3.3,0.8,-0.4))
	_add("shrine_and_cart", 6, Vector3(2,1.75,0.6), Vector3(5.9,1.5,0.9), Vector3(1.2,1.7,4.3), Vector3(4.2,1,2.6))
	_add("vent", 6, Vector3(3,1.3,-0.5), Vector3(4.4,1.1,-0.4), Vector3(3.6,0.5,-2.3))
	_add("ownerless_shadow", 6, Vector3(0,1.7,0.3), Vector3(0.6,1.7,0.5), Vector3(0,1.5,4.55))
	_add("dark_train", 8, Vector3(-3,1.75,3.2), Vector3(-1,1.7,3.1), Vector3(13,1.8,0.6))
	_add("library_approach", 9, Vector3(7.2,1.7,1.1), Vector3(15.5,1.7,1.1), Vector3(17,1.55,1.1))
	_add("chronology_necromancy", 7, Vector3(-1.9,1.7,-0.1), Vector3(-2.45,1.6,-4), Vector3(-3.5,1.7,-1.8), Vector3(-3.7,1.5,-4.25), true)
	_add("alchemy_metaphysics", 7, Vector3(1.9,1.7,-0.1), Vector3(2.45,1.6,-4), Vector3(3.5,1.7,-1.8), Vector3(3.7,1.7,-4.3), true)
	_add("hunting_and_vault", 6, Vector3(2,1.7,-4.1), Vector3(0.5,1.8,-3), Vector3(2.7,1.7,-5.8), Vector3(0.5,4,-4), true)
	_add("living_novels", 6, Vector3(2.1,1.75,-1.1), Vector3(2.25,1.5,-0.85), Vector3(2.9,0.9,-0.3), null, true)
	_add("spellbook", 6, Vector3(-2.5,1.75,-1.3), Vector3(-2.3,1.55,-1.1), Vector3(-2.8,1.1,-0.4), null, true)
	_add("haunted_cage", 7, Vector3(-0.95,1.5,-4.3), Vector3(-1.1,1.3,-4.6), Vector3(-1.85,0.9,-5.8), null, true)
	_add("chained_book", 7, Vector3(-1.3,1.4,-3.95), Vector3(-1.4,1.3,-4.1), Vector3(-0.95,1.1,-4.4), null, true)
	_add("desk_and_ward", 6, Vector3(0,2.7,-2.4), Vector3(0.7,2,-3.3), Vector3(0,0.8,-4.6), null, true)
	_add("return_to_corridor", 8, Vector3(0,1.7,-3.1), Vector3(0,1.7,1.6), Vector3(0,1.6,5), null, true)

func _frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame
