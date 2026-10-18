extends Node3D
## Stills (and clips) of the librarian's shop's bay (maps/library_lab.tscn), lit and under the form light,
## for the user's review. Windowed:
##   Godot --path . --resolution 1600x900 res://tests/library_lab_stills.tscn -- --out=DIR [--only=a,b] [--settle=S]
##     [--clip=S [--dolly=M]]   a clip instead of a still: S seconds of frames (30 a second), the eye walking M
##                              metres toward what it looks at, at its own height

const LAB := preload("res://maps/library_lab.tscn")

## Each view: its name, where the eye stands, what it looks at.
const VIEWS := [
	["shop_front", Vector3(0.0, 1.65, 3.3), Vector3(0.0, 1.9, -2.0)],
	["shop_inside", Vector3(0.0, 1.7, -0.3), Vector3(0.0, 1.6, -6.0)],
	["shop_corner", Vector3(0.0, 1.6, -2.2), Vector3(0.0, 1.2, -6.0)],
	["shop_aisle_l", Vector3(-2.4, 1.6, -0.5), Vector3(-2.4, 1.4, -6.0)],
	["shop_aisle_r", Vector3(2.4, 1.6, -0.5), Vector3(2.4, 1.4, -6.0)],
	["shop_vault", Vector3(0.0, 1.4, -0.5), Vector3(0.0, 4.4, -4.0)],
	["shop_back_out", Vector3(0.0, 1.7, -5.6), Vector3(0.0, 1.8, 2.0)],
	["close_arch", Vector3(2.3, 2.3, 1.4), Vector3(1.55, 2.5, 0.4)],
	["close_arch_in", Vector3(-1.2, 1.9, -1.3), Vector3(-1.55, 2.4, 0.0)],
	["close_fascia", Vector3(1.0, 2.6, 2.2), Vector3(0.8, 3.6, 0.4)],
	["close_vault_end", Vector3(3.2, 2.6, -5.2), Vector3(4.0, 3.3, -6.0)],
	["close_vault_front", Vector3(-3.0, 2.4, -0.9), Vector3(-4.0, 3.2, 0.0)],
	["close_threshold", Vector3(0.6, 1.0, 1.2), Vector3(0.0, 0.0, -0.2)],
	["close_patch", Vector3(1.6, 1.6, -4.4), Vector3(2.3, 1.5, -6.0)],
	["close_skirting", Vector3(-3.2, 0.7, -2.0), Vector3(-4.0, 0.1, -3.0)],
]


func _ready() -> void:
	var out := "/tmp/library_stills/"
	var only := []
	var settle := 0.0
	var clip := 0.0
	var dolly := 0.0

	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.trim_prefix("--out=").trim_suffix("/") + "/"
		elif arg.begins_with("--only="):
			only = arg.trim_prefix("--only=").split(",")
		elif arg.begins_with("--settle="):
			settle = float(arg.trim_prefix("--settle="))
		elif arg.begins_with("--clip="):
			clip = float(arg.trim_prefix("--clip="))
		elif arg.begins_with("--dolly="):
			dolly = float(arg.trim_prefix("--dolly="))

	DirAccess.make_dir_recursive_absolute(out)
	AudioServer.set_bus_mute(0, true)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var lab: Node3D = LAB.instantiate()
	add_child(lab)
	await _frames(4 + int(settle * 60.0))
	lab.player.queue_free()
	lab.keys_label.visible = false
	var eye := Camera3D.new()
	eye.fov = 62.0
	add_child(eye)
	eye.make_current()

	for form in ([false] if clip > 0.0 else [false, true]):
		lab.set_form(form)

		for view in VIEWS:
			if not only.is_empty() and not view[0] in only:
				continue

			eye.global_transform = Transform3D(Basis(), view[1]).looking_at(view[2], Vector3.UP)
			await _frames(12)

			if clip > 0.0:
				var start: Vector3 = view[1]
				# (Walked at the eye's own height, as someone would.)
				var ahead: Vector3 = ((view[2] - view[1]) * Vector3(1, 0, 1)).normalized() * dolly
				var count := int(clip * 30.0)
				for k in count:
					var t := smoothstep(0.0, 1.0, float(k) / maxf(count - 1, 1))
					eye.global_transform = Transform3D(Basis(), start + ahead * t).looking_at(view[2], Vector3.UP)
					get_viewport().get_texture().get_image().save_png("%s%s_%03d.png" % [out, view[0], k])
					await _frames(2)
				print("clip: ", view[0])
				continue

			var file := "%s%s_%s.png" % [out, view[0], "form" if form else "lit"]
			get_viewport().get_texture().get_image().save_png(file)
			print("still: ", file)

	get_tree().quit()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame
