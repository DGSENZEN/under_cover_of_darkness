extends Node3D
## The Underground's look-dev bay staged for judging (part 1 plan, Task 9):
## the hero stall from seven views, each under the work lights and again
## under the neutral form light.
##   Godot --path . --resolution 1920x1080 res://tests/underground_lab_stills.tscn -- --out=/tmp/underground-lab
##   (-- --only=front,close_counter  some views; -- --plain  the atlas drawn unshaded, to check its mapping;
##    -- --train  shot as a train runs by)

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
]

var out := "/tmp/underground-lab/"


func _ready() -> void:
	var only := []
	var plain := false
	var passing := false

	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.trim_prefix("--out=").trim_suffix("/") + "/"
		elif arg.begins_with("--only="):
			only = arg.trim_prefix("--only=").split(",")
		elif arg == "--plain":
			plain = true
		elif arg == "--train":
			passing = true

	DirAccess.make_dir_recursive_absolute(out)
	AudioServer.set_bus_mute(0, true)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var lab: Node3D = LAB.instantiate()
	add_child(lab)
	await _frames(4)
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

	if passing:
		lab.train.start_pass()

		for i in int((TrainPass.BUILD + 1.0) * 60.0):
			await get_tree().process_frame

	for form in ([false] if plain or passing else [false, true]):
		if not plain:
			lab.set_form(form)

		for view in VIEWS:
			if not only.is_empty() and not view[0] in only:
				continue

			eye.global_transform = Transform3D(Basis(), view[1]).looking_at(view[2], Vector3.UP)
			await _frames(12)
			var file := "%s%s_%s.png" % [out, view[0], "plain" if plain else ("train" if passing else ("form" if form else "lit"))]
			get_viewport().get_texture().get_image().save_png(file)
			print("still: ", file)

	get_tree().quit()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame
