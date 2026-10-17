extends Node3D
## Diagnostic (not a suite): the censer's smoke, close, over a few seconds.
##   Godot --path . --resolution 1280x720 res://tests/diag_ulab_smoke.tscn -- --out=/tmp/ulab-smoke

const LAB := preload("res://maps/underground_lab.tscn")
var out := "/tmp/ulab-smoke/"


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.trim_prefix("--out=").trim_suffix("/") + "/"

	DirAccess.make_dir_recursive_absolute(out)
	var lab: Node3D = LAB.instantiate()
	add_child(lab)
	await _frames(4)
	lab.player.queue_free()
	lab.keys_label.visible = false
	var eye := Camera3D.new()
	eye.fov = 55.0
	add_child(eye)
	eye.make_current()
	# Let the smoke fill in first.
	await _frames(400)
	var views := [["front", Vector3(0.0, 1.55, 1.3), Vector3(0.0, 1.6, -0.22)],
		["side", Vector3(1.3, 1.6, -0.2), Vector3(0.0, 1.65, -0.22)]]

	for view in views:
		eye.global_transform = Transform3D(Basis(), view[1]).looking_at(view[2], Vector3.UP)

		for k in 3:
			await _frames(40)
			get_viewport().get_texture().get_image().save_png("%s%s_%d.png" % [out, view[0], k])

	print("diag smoke done")
	get_tree().quit()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame
