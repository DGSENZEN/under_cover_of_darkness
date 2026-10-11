extends Node3D
## A clip of the Zócalo from one of its cameras (tools/level/layouts/zocalo/cameras.py),
## day or night, frames a tenth of a second apart (tools/eclipse/clip.py makes
## them a GIF). In a window:
##   Godot --path . --resolution 960x540 res://tests/zocalo_clip.tscn -- --camera=brazier_watch --night --out=/tmp/clip

const MAP := preload("res://maps/zocalo.tscn")


func _ready() -> void:
	var camera := "god_devotion"
	var night := false
	var frames := 50
	var out := "/tmp/clip/"

	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--camera="):
			camera = arg.trim_prefix("--camera=")
		elif arg == "--night":
			night = true
		elif arg.begins_with("--frames="):
			frames = int(arg.trim_prefix("--frames="))
		elif arg.begins_with("--out="):
			out = arg.trim_prefix("--out=").trim_suffix("/") + "/"

	DirAccess.make_dir_recursive_absolute(out)
	var map: Node3D = MAP.instantiate()
	add_child(map)
	await get_tree().process_frame
	map.player.process_mode = Node.PROCESS_MODE_DISABLED
	var spot: Dictionary = map.cameras().filter(func(c): return c["name"] == camera)[0]
	var eye := Camera3D.new()
	eye.fov = 66.0
	add_child(eye)
	eye.make_current()
	eye.global_transform = Transform3D(Basis(), spot["at"]).looking_at(spot["look_at"], Vector3.UP)
	map.player.global_position = spot["at"] + Vector3(0, -50, 0)
	map.set_day(not night)

	for i in 90:
		await get_tree().process_frame

	for k in frames:
		var start := Time.get_ticks_msec()

		while Time.get_ticks_msec() - start < 100:
			await get_tree().process_frame

		RenderingServer.force_draw()
		get_viewport().get_texture().get_image().save_png(out + "frame_%03d.png" % k)

	print("clip: %d frames of %s in %s" % [frames, camera, out])
	get_tree().quit()
