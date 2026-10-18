extends Node3D
## Stills (and clips) of the librarian's shop's bay (maps/library_lab.tscn), lit and under the form light,
## for the user's review. Windowed:
##   Godot --path . --resolution 1600x900 res://tests/library_lab_stills.tscn -- --out=DIR [--only=a,b] [--settle=S]
##     [--clip=S [--dolly=M]]   a clip instead of a still: S seconds of frames (30 a second), the eye walking M
##                              metres toward what it looks at, at its own height
##     [--strain]               the chained book strains as the clip begins, and every 2.2 s

const LAB := preload("res://maps/library_lab.tscn")

## Each view: its name, where the eye stands, what it looks at.
## Each view: its name, the eye, what it looks at, and (for the live books) how long to hold it first (s, at the
## 60 frames a second the stills run at: --fixed-fps 60).
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
	["close_patch", Vector3(-2.4, 1.6, -4.5), Vector3(-3.0, 1.5, -6.0)],
	["close_skirting", Vector3(-3.2, 0.7, -2.0), Vector3(-4.0, 0.1, -3.0)],
	["corner_desk", Vector3(0.0, 1.75, -2.6), Vector3(0.0, 1.0, -4.4)],
	["corner_top", Vector3(0.1, 1.85, -3.55), Vector3(0.05, 1.05, -4.4)],
	["corner_chair", Vector3(-1.5, 1.5, -3.3), Vector3(0.12, 0.6, -5.2)],
	["corner_hook", Vector3(0.0, 1.6, -3.0), Vector3(1.18, 1.3, -4.82)],
	["corner_behind", Vector3(1.6, 1.6, -5.7), Vector3(0.0, 0.9, -4.3)],
	["close_lamp", Vector3(-0.95, 1.6, -3.75), Vector3(-0.4, 1.3, -4.5)],
	["close_things", Vector3(0.95, 1.5, -3.75), Vector3(0.5, 1.05, -4.55)],
	["close_hat", Vector3(0.6, 2.0, -3.9), Vector3(1.18, 1.85, -4.82)],
	["corner_rite", Vector3(-0.3, 1.75, -3.35), Vector3(-0.3, 1.1, -4.45)],
	["close_rituale", Vector3(-0.95, 1.45, -3.75), Vector3(-0.6, 1.07, -4.24)],
	["close_reliquary", Vector3(-0.05, 1.32, -3.68), Vector3(-0.15, 1.12, -4.17)],
	["close_stole", Vector3(-1.05, 1.6, -3.95), Vector3(-0.48, 1.35, -4.52)],
	["close_crucifix", Vector3(-0.55, 1.45, -3.95), Vector3(-0.25, 1.2, -4.69)],
	["close_medal", Vector3(0.3, 1.12, -3.45), Vector3(0.0, 1.015, -4.0)],
	["corner_hunt", Vector3(0.0, 1.95, -3.85), Vector3(0.0, 2.0, -6.0)],
	["close_trap", Vector3(0.35, 2.45, -4.95), Vector3(0.0, 2.5, -5.92)],
	["close_crossbow", Vector3(-0.25, 2.05, -4.95), Vector3(-0.15, 2.12, -5.92)],
	["close_lower", Vector3(-0.45, 1.55, -4.85), Vector3(-0.35, 1.45, -5.92)],
	["close_gun", Vector3(0.75, 1.6, -4.95), Vector3(0.6, 1.4, -5.92)],
	["corner_chained", Vector3(-1.75, 1.55, -3.6), Vector3(-1.06, 1.1, -4.4)],
	["close_chained", Vector3(-1.3, 1.4, -3.95), Vector3(-0.95, 1.1, -4.4)],
	["corner_cage", Vector3(-0.95, 1.5, -4.3), Vector3(-1.85, 0.9, -5.8)],
	["corner_ward", Vector3(0.0, 3.4, -1.7), Vector3(0.0, 0.0, -4.4)],
	["shelf_chronology", Vector3(-1.9, 1.8, 0.0), Vector3(-3.5, 2.0, -1.8)],
	["shelf_necromancy", Vector3(-1.9, 1.8, -3.0), Vector3(-3.5, 2.1, -4.8)],
	["shelf_alchemy", Vector3(1.9, 1.8, 0.0), Vector3(3.5, 2.0, -1.8)],
	["shelf_metaphysics", Vector3(1.9, 1.8, -2.5), Vector3(3.5, 2.1, -4.3)],
	["shelf_hunting", Vector3(2.4, 1.8, -2.6), Vector3(2.65, 2.2, -5.6)],
	["shelf_middle", Vector3(0.0, 1.6, -0.2), Vector3(-1.15, 0.8, -1.9)],
	["shelf_ladder", Vector3(-2.2, 1.6, -0.6), Vector3(-3.0, 1.6, -1.6)],
	["shelf_crests", Vector3(-0.5, 2.0, -0.4), Vector3(-3.5, 3.4, -3.2)],
	["books_wall", Vector3(-1.3, 1.6, -2.2), Vector3(-3.6, 1.3, -3.6)],
	["books_close", Vector3(-2.75, 1.55, -1.45), Vector3(-3.65, 1.4, -1.95)],
	["books_low", Vector3(0.0, 1.1, -1.4), Vector3(0.8, 0.55, -2.2)],
	["books_hunting", Vector3(2.0, 1.6, -4.2), Vector3(2.7, 1.2, -5.7)],
	["table_shut", Vector3(0.0, 1.65, 1.8), Vector3(1.17, 0.9, -0.6), 1.5],
	["table_open", Vector3(0.05, 1.6, -0.25), Vector3(1.17, 0.88, -0.65), 1.5],
	["lectern_shut", Vector3(0.0, 1.65, 0.2), Vector3(-1.15, 1.1, -3.3), 1.5],
	["lectern_open", Vector3(-0.35, 1.65, -2.35), Vector3(-1.15, 1.1, -3.3), 1.5],
	["study_necromancy", Vector3(-2.6, 1.65, -4.0), Vector3(-3.7, 1.5, -4.25), 1.5],
	["study_chronology", Vector3(-2.5, 1.55, -1.1), Vector3(-3.7, 1.05, -1.3), 1.5],
	["clip_table", Vector3(0.1, 1.6, 1.6), Vector3(1.17, 0.9, -0.6)],
]


func _ready() -> void:
	var out := "/tmp/library_stills/"
	var only := []
	var settle := 0.0
	var clip := 0.0
	var dolly := 0.0
	var straining := false

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
		elif arg == "--strain":
			straining = true

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
			# (A view of the live books held long enough for them to open, or shut, before it is taken.)
			await _frames(12 + (int(view[3] * 60.0) if view.size() > 3 else 0))

			if clip > 0.0:
				var start: Vector3 = view[1]
				# (Walked at the eye's own height, as someone would.)
				var ahead: Vector3 = ((view[2] - view[1]) * Vector3(1, 0, 1)).normalized() * dolly
				var count := int(clip * 30.0)
				for k in count:
					if straining and k % 66 == 0 and lab.chained != null:
						lab.chained.strain_now()
					var t := smoothstep(0.0, 1.0, float(k) / maxf(count - 1, 1))
					eye.global_transform = Transform3D(Basis(), start + ahead * t).looking_at(view[2], Vector3.UP)
					RenderingServer.force_draw(false)
					get_viewport().get_texture().get_image().save_png("%s%s_%03d.png" % [out, view[0], k])
					await _frames(2)
				print("clip: ", view[0])
				continue

			var file := "%s%s_%s.png" % [out, view[0], "form" if form else "lit"]
			# (Drawn now, whether or not the window is on screen: hidden, it would hand back its last frame.)
			RenderingServer.force_draw(false)
			get_viewport().get_texture().get_image().save_png(file)
			print("still: ", file)

	get_tree().quit()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame
