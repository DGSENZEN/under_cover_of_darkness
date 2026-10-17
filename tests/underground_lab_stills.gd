extends Node3D
## The Underground's look-dev bay staged for judging (part 1 plan, Task 9):
## the hero stall from seven views, each under the work lights and again
## under the neutral form light.
##   Godot --path . --resolution 1920x1080 res://tests/underground_lab_stills.tscn -- --out=/tmp/underground-lab
##   (-- --only=front,close_counter  some views; -- --plain  the atlas drawn unshaded, to check its mapping)

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
]

var out := "/tmp/underground-lab/"


func _ready() -> void:
	var only := []
	var plain := false

	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.trim_prefix("--out=").trim_suffix("/") + "/"
		elif arg.begins_with("--only="):
			only = arg.trim_prefix("--only=").split(",")
		elif arg == "--plain":
			plain = true

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

	for form in ([false] if plain else [false, true]):
		if not plain:
			lab.set_form(form)

		for view in VIEWS:
			if not only.is_empty() and not view[0] in only:
				continue

			eye.global_transform = Transform3D(Basis(), view[1]).looking_at(view[2], Vector3.UP)
			await _frames(12)
			var file := "%s%s_%s.png" % [out, view[0], "plain" if plain else ("form" if form else "lit")]
			get_viewport().get_texture().get_image().save_png(file)
			print("still: ", file)

	get_tree().quit()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame
