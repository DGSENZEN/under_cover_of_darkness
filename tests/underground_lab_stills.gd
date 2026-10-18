extends Node3D
## The Underground's look-dev bay staged for judging (part 1 plan, Task 9):
## the hero stall from seven views, each under the work lights and again
## under the neutral form light.
##   Godot --path . --resolution 1920x1080 res://tests/underground_lab_stills.tscn -- --out=/tmp/underground-lab
##   (-- --only=front,close_counter  some views; -- --plain  the atlas drawn unshaded, to check its mapping;
##    -- --train  shot as a train runs by; -- --settle=4  effects given 4 s to fill out first;
##    -- --rise  an ánima sent up from the drain first; -- --dark  shot as the dark train runs by;
##    -- --unlit  the work lights off, the corridor by its own lights; -- --procession  her dead walking;
##    -- --shadow  the ownerless shadow crossing the far wall)

const LAB := preload("res://maps/underground_lab.tscn")

## name, eye, looking at (Godot: the stall's front faces +Z, its counter at z 0).
const VIEWS := [
	["front", Vector3(0.0, 1.7, 4.3), Vector3(0.0, 1.45, -0.6)],
	["three_quarter", Vector3(3.2, 1.8, 3.4), Vector3(0.0, 1.35, -0.6)],
	["side", Vector3(4.0, 1.7, 0.2), Vector3(0.0, 1.3, -0.8)],
	["close_counter", Vector3(0.6, 1.55, 1.3), Vector3(-0.2, 1.05, -0.3)],
	["close_ofrenda", Vector3(-0.55, 1.5, 0.85), Vector3(-1.13, 1.25, -0.3)],
	["close_awning", Vector3(0.6, 1.85, 1.0), Vector3(0.0, 2.25, -0.2)],
	["close_neon", Vector3(0.8, 2.35, 1.5), Vector3(0.0, 2.65, 0.0)],
	["aisle", Vector3(1.15, 1.65, -1.0), Vector3(-1.0, 1.15, -1.5)],
	["corridor_far", Vector3(-9.0, 1.8, 3.2), Vector3(0.0, 1.5, -0.8)],
	["floor_litter", Vector3(0.9, 1.3, 1.9), Vector3(-0.15, 0.0, 0.5)],
	["floor_trail", Vector3(-1.0, 1.7, 2.6), Vector3(-3.4, 0.0, -0.6)],
	["floor_stock", Vector3(-2.5, 1.5, 0.4), Vector3(-3.7, 0.3, -2.0)],
	["floor_cable", Vector3(3.2, 1.7, 0.2), Vector3(2.6, 0.7, -2.2)],
	["floor_coil", Vector3(6.3, 1.4, -0.9), Vector3(7.4, 0.0, -2.1)],
	["floor_papers", Vector3(-2.6, 1.4, 2.8), Vector3(-3.6, 0.0, 1.7)],
	["services_back", Vector3(3.5, 1.7, 2.5), Vector3(0.0, 3.2, -2.3)],
	["services_far", Vector3(2.0, 1.7, 1.0), Vector3(6.5, 3.0, 4.5)],
	["close_spill", Vector3(2.5, 2.4, 0.2), Vector3(0.95, 3.3, -1.9)],
	["close_valve", Vector3(7.2, 2.6, 2.8), Vector3(7.0, 3.5, 4.35)],
	["close_hydrant", Vector3(-9.6, 1.6, 2.6), Vector3(-11.3, 1.4, 4.3)],
	["furn_cart", Vector3(2.4, 1.6, 4.0), Vector3(4.2, 1.0, 2.6)],
	["furn_bench", Vector3(-3.0, 1.6, 1.6), Vector3(-2.8, 0.6, 4.4)],
	["furn_niche", Vector3(1.2, 1.6, 2.7), Vector3(1.2, 1.6, 4.5)],
	["furn_vent", Vector3(3.1, 1.1, -0.7), Vector3(3.6, 0.6, -2.35)],
	["furn_bin", Vector3(-1.2, 1.3, 3.0), Vector3(-1.75, 0.5, 4.15)],
	["furn_niche_far", Vector3(1.2, 1.7, 1.2), Vector3(1.2, 1.9, 4.5)],
	["floor_drain", Vector3(-2.5, 1.3, -0.3), Vector3(-1.8, 0.0, -1.75)],
	["floor_worn", Vector3(-6.0, 1.6, 0.6), Vector3(-6.0, 0.0, 2.6)],
	["wall_crack", Vector3(-4.6, 1.2, -0.7), Vector3(-5.4, 0.5, -2.35)],
	["wall_bills", Vector3(5.4, 1.7, 0.6), Vector3(6.2, 1.9, -2.35)],
	["wall_tablet", Vector3(-9.0, 1.7, 1.2), Vector3(-9.0, 1.8, -2.35)],
	["uncanny_drain", Vector3(-2.3, 0.9, -0.9), Vector3(-1.8, 0.0, -1.75)],
	["uncanny_rise", Vector3(-3.0, 1.0, 0.2), Vector3(-1.7, 0.25, -1.6)],
	["uncanny_warm", Vector3(-2.3, 1.55, -1.7), Vector3(-1.15, 1.25, -0.4)],
	["uncanny_warm_b", Vector3(-1.1, 1.7, 1.2), Vector3(-1.15, 1.25, -0.4)],
	["uncanny_beg", Vector3(-2.2, 1.65, 0.1), Vector3(-1.0, 1.3, -0.6)],
	["uncanny_nahual", Vector3(-3.6, 1.6, 1.6), Vector3(-4.8, 0.5, 4.0)],
	["uncanny_procession", Vector3(-0.5, 1.7, 2.6), Vector3(-3.4, 0.9, -0.4)],
	["uncanny_shadow", Vector3(0.0, 1.7, 0.2), Vector3(0.0, 1.5, 4.5)],
	["uncanny_eyes", Vector3(-4.3, 1.05, 1.7), Vector3(-5.0, 0.95, 3.0)],
	["uncanny_nahual_far", Vector3(0.5, 1.6, 0.8), Vector3(-4.8, 0.6, 4.0)],
]

var out := "/tmp/underground-lab/"


func _ready() -> void:
	var only := []
	var plain := false
	var passing := false
	var settle := 0.0
	var rising := false
	var dark := false
	var unlit := false
	var walking := false
	var shadowed := false
	var begging := false

	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.trim_prefix("--out=").trim_suffix("/") + "/"
		elif arg.begins_with("--only="):
			only = arg.trim_prefix("--only=").split(",")
		elif arg == "--plain":
			plain = true
		elif arg == "--train":
			passing = true
		elif arg == "--procession":
			walking = true
		elif arg == "--shadow":
			shadowed = true
		elif arg == "--beg":
			begging = true
		elif arg == "--unlit":
			unlit = true
		elif arg == "--dark":
			dark = true
		elif arg == "--rise":
			rising = true
		elif arg.begins_with("--settle="):
			settle = float(arg.trim_prefix("--settle="))

	DirAccess.make_dir_recursive_absolute(out)
	AudioServer.set_bus_mute(0, true)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var lab: Node3D = LAB.instantiate()
	add_child(lab)
	# (Effects given --settle seconds to fill out before the first still.)
	await _frames(4 + int(settle * 60.0))
	lab.player.queue_free()
	lab.keys_label.visible = false
	var eye := Camera3D.new()
	eye.fov = 62.0
	add_child(eye)
	eye.make_current()

	if plain:
		var flat := StandardMaterial3D.new()
		flat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		flat.albedo_texture = lab._painted(["stall.png", "stall_base.png"])

		for mesh: MeshInstance3D in lab.stall.find_children("*", "MeshInstance3D", true, false):
			if mesh.name != "stall_neon":
				mesh.material_override = flat

	if rising:
		# An ánima sent up from the drain, shot leaning toward her candles.
		lab.animas.rise_now()

		for i in 150:
			await get_tree().process_frame

	if begging:
		# The eye stands still by the drain, the living the ánimas beg of; shot once one has come to it.
		for view in VIEWS:
			if view[0] == "uncanny_beg":
				eye.global_transform = Transform3D(Basis(), view[1]).looking_at(view[2], Vector3.UP)
		lab.animas.flee_from = eye

		for i in 720:
			await get_tree().process_frame

	if walking:
		# Her dead set out, shot as the file has come out on to the floor.
		lab.procession.start()

		for i in 900:
			await get_tree().process_frame

	if shadowed:
		# A second eye looking away from the wall, so the shadow keeps crossing while the still looks at it.
		var aside := Camera3D.new()
		add_child(aside)
		aside.global_position = Vector3(0.0, 1.6, 1.0)
		aside.look_at(Vector3(0.0, 1.6, -5.0), Vector3.UP)
		lab.ownerless.watcher = aside
		lab.ownerless.cross_now()

		# (Shot once it is well on to the wall, by its own distance, whatever the frame rate.)
		var started: float = lab.ownerless.decal.global_position.x
		while absf(lab.ownerless.decal.global_position.x - started) < 4.5 and lab.ownerless.decal.visible:
			await get_tree().process_frame

		print("shadow at ", lab.ownerless.decal.global_position, " visible ", lab.ownerless.decal.visible, " a ", lab.ownerless.decal.modulate.a)

	if dark:
		lab.dark_train.start_pass()

		for i in int((TrainPass.BUILD + 1.0) * 60.0):
			await get_tree().process_frame

	if passing:
		lab.train.start_pass()

		for i in int((TrainPass.BUILD + 1.0) * 60.0):
			await get_tree().process_frame

	for form in ([false] if plain or passing or dark or unlit else [false, true]):
		if not plain:
			lab.set_form(form)

		if unlit:
			lab.set_work_lights(false)

		for view in VIEWS:
			if not only.is_empty() and not view[0] in only:
				continue

			eye.global_transform = Transform3D(Basis(), view[1]).looking_at(view[2], Vector3.UP)
			# (The nahual goes once looked at and looked away from: every still begins with it there.)
			if lab.nahual != null:
				lab.nahual.appear()
			await _frames(12)
			var file := "%s%s_%s.png" % [out, view[0], "plain" if plain else ("train" if passing else ("dark" if dark else ("form" if form else ("unlit" if unlit else "lit"))))]
			get_viewport().get_texture().get_image().save_png(file)
			print("still: ", file)

	get_tree().quit()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame
