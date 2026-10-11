extends Node3D
## A clip of the Zócalo from one of its cameras (tools/level/layouts/zocalo/cameras.py),
## day or night, frames a tenth of a second apart (--every=s) (tools/eclipse/clip.py makes
## them a GIF), or from anywhere (--at=x,y,z --look=x,y,z), through any lens (--fov). In a window:
##   Godot --path . --resolution 960x540 res://tests/zocalo_clip.tscn -- --camera=brazier_watch --night --out=/tmp/clip

const MAP := preload("res://maps/zocalo.tscn")


func _ready() -> void:
	var camera := "god_devotion"
	var night := false
	var frames := 50
	var out := "/tmp/clip/"
	var warm := 1.5
	var startle := Vector3.INF
	var deep := false
	var fov := 66.0
	var every := 0.1
	var at := Vector3.INF
	var look := Vector3.INF

	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--camera="):
			camera = arg.trim_prefix("--camera=")
		elif arg == "--night":
			night = true
		elif arg.begins_with("--frames="):
			frames = int(arg.trim_prefix("--frames="))
		elif arg.begins_with("--out="):
			out = arg.trim_prefix("--out=").trim_suffix("/") + "/"
		elif arg.begins_with("--fov="):
			fov = float(arg.trim_prefix("--fov="))
		elif arg == "--deep":
			deep = true
		elif arg.begins_with("--startle="):
			startle = _vector(arg.trim_prefix("--startle="))
		elif arg.begins_with("--every="):
			every = float(arg.trim_prefix("--every="))
		elif arg.begins_with("--warm="):
			warm = float(arg.trim_prefix("--warm="))
		elif arg.begins_with("--at="):
			at = _vector(arg.trim_prefix("--at="))
		elif arg.begins_with("--look="):
			look = _vector(arg.trim_prefix("--look="))

	DirAccess.make_dir_recursive_absolute(out)
	var map: Node3D = MAP.instantiate()
	add_child(map)
	await get_tree().process_frame
	map.player.process_mode = Node.PROCESS_MODE_DISABLED
	# (Its body would stand at the spawn, T-posed.)
	map.player.visible = false
	var spot: Dictionary = {"at": at, "look_at": look} if at != Vector3.INF else map.cameras().filter(func(c): return c["name"] == camera)[0]
	var eye := Camera3D.new()
	eye.fov = fov
	add_child(eye)
	eye.make_current()
	eye.global_transform = Transform3D(Basis(), spot["at"]).looking_at(spot["look_at"], Vector3.UP)
	map.player.global_position = spot["at"] + Vector3(0, -50, 0)
	map.set_day(not night)

	# The effects running a while first (--warm=s).
	var started := Time.get_ticks_msec()

	while Time.get_ticks_msec() - started < warm * 1000.0:
		await get_tree().process_frame

	# (--deep: the god's breath set to the start of a deep one as the clip
	# begins, its exhale turning 3.5 s in.)
	var begun := Time.get_ticks_msec()

	if deep:
		map.breath.time = Breath.PERIOD * (Breath.DEEP_EVERY - 1)
		map.breath.deep_exhale.connect(func(): print("clip: the deep exhale at %.2f s" % ((Time.get_ticks_msec() - begun) / 1000.0)))

	for k in frames:
		# (--startle: the unseen player walks up to a spot a moment in, and
		# away again after two seconds: the pigeons there lift, then settle.)
		if startle != Vector3.INF and k == 5:
			map.player.global_position = startle
		elif startle != Vector3.INF and k == 5 + int(2.0 / every):
			map.player.global_position = spot["at"] + Vector3(0, -50, 0)

		# (Each frame on the clock from the clip's start: saving one takes a
		# while, and timed from the last it slowed the clip's time.)
		while Time.get_ticks_msec() - begun < (k + 1) * every * 1000.0:
			await get_tree().process_frame

		RenderingServer.force_draw()
		get_viewport().get_texture().get_image().save_png(out + "frame_%03d.png" % k)

	print("clip: %d frames of %s in %s" % [frames, camera, out])
	get_tree().quit()


func _vector(text: String) -> Vector3:
	var n := text.split_floats(",")
	return Vector3(n[0], n[1], n[2])
