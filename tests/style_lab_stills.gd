extends Node3D
## The style lab staged for judging (its plan, Task 6): for each station (each
## blend), by night and by day, seven views: the front at 9 m, along under the
## arcade, the kiosk close, the whole at 30 m, grazing along the façade, and
## the stair from its head and from its landing.
## Then, by night, each station's front drawn 240 frames with its painterly
## materials and again with plain ones, the frame times printed.
##   Godot --path . --resolution 1920x1080 res://tests/style_lab_stills.tscn -- --out=/tmp/style-lab
##   (-- --only=even  one station)

const LAB := preload("res://maps/style_lab.tscn")
const FRAMES := 240

var out := "/tmp/style-lab/"


func _ready() -> void:
	var only := ""

	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.trim_prefix("--out=").trim_suffix("/") + "/"
		elif arg.begins_with("--only="):
			only = arg.trim_prefix("--only=")

	DirAccess.make_dir_recursive_absolute(out)
	AudioServer.set_bus_mute(0, true)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var lab: Node3D = LAB.instantiate()
	add_child(lab)
	await _frames(4)
	lab.player.queue_free()
	var eye := Camera3D.new()
	eye.fov = 66.0
	add_child(eye)
	eye.make_current()

	for k in lab.STATIONS.size():
		var preset: StringName = lab.STATIONS[k]

		if only != "" and String(preset) != only:
			continue

		for day in [false, true]:
			lab.set_day(day)

			for view in _views(lab.STATION_X[k], lab.KIOSK_Z, lab.BAYS_Z):
				eye.global_transform = Transform3D(Basis(), view[1]).looking_at(view[2], Vector3.UP)
				await _frames(10)
				var file := "%s%s_%s_%s.png" % [out, preset, "day" if day else "night", view[0]]
				get_viewport().get_texture().get_image().save_png(file)
				print("still: ", file)

	# The frame-time gate: painterly against plain, each station's front by night.
	lab.set_day(false)

	for k in lab.STATIONS.size():
		var preset: StringName = lab.STATIONS[k]

		if only != "" and String(preset) != only:
			continue

		var front: Array = _views(lab.STATION_X[k], lab.KIOSK_Z, lab.BAYS_Z)[0]
		eye.global_transform = Transform3D(Basis(), front[1]).looking_at(front[2], Vector3.UP)
		await _frames(30)
		var painterly := await _frame_ms()
		var swapped := _plain(lab.get_node(String(preset)))
		await _frames(30)
		var plain := await _frame_ms()

		for entry in swapped:
			entry[0].set_surface_override_material(entry[1], entry[2])

		print("frame: %s painterly %.2f ms plain %.2f ms (%+.2f)" % [preset, painterly, plain, painterly - plain])

	get_tree().quit()


func _views(x: float, kiosk_z: float, bays_z: float) -> Array:
	return [
		["front", Vector3(x, 1.7, kiosk_z + 9.0), Vector3(x, 3.0, bays_z)],
		["arcade", Vector3(x - 6.0, 1.7, bays_z - 2.0), Vector3(x + 6.0, 1.9, bays_z - 2.0)],
		["kiosk_close", Vector3(x + 1.8, 1.6, kiosk_z + 2.5), Vector3(x, 1.2, kiosk_z - 1.0)],
		["far", Vector3(x, 3.0, kiosk_z + 30.0), Vector3(x, 3.0, bays_z)],
		["grazing", Vector3(x - 12.0, 4.5, bays_z + 2.2), Vector3(x + 6.0, 4.5, bays_z + 0.3)],
		["stair_down", Vector3(x, 1.7, kiosk_z + 1.0), Vector3(x, -2.0, kiosk_z - 5.0)],
		["stair_up", Vector3(x, -1.4, kiosk_z - 7.2), Vector3(x, 0.6, kiosk_z)],
	]


## Mean milliseconds a frame over FRAMES frames.
func _frame_ms() -> float:
	var start := Time.get_ticks_usec()

	for i in FRAMES:
		await get_tree().process_frame

	return (Time.get_ticks_usec() - start) / 1000.0 / FRAMES


## The station's painterly surfaces drawn plain (their atlas, no shader);
## what was there, to put back: [[mesh, surface, material], ...].
func _plain(station: Node) -> Array:
	var swapped := []

	for mesh: MeshInstance3D in station.find_children("*", "MeshInstance3D", true, false):
		for i in mesh.mesh.get_surface_count():
			var drawn := mesh.get_surface_override_material(i)

			if drawn is ShaderMaterial:
				var plain := StandardMaterial3D.new()
				plain.albedo_texture = drawn.get_shader_parameter("atlas")
				plain.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
				swapped.append([mesh, i, drawn])
				mesh.set_surface_override_material(i, plain)

	return swapped


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame
