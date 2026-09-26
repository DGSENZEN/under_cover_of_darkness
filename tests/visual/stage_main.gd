## Visual check: loads a scene (--scene=res://...; default main.tscn), turns around, saves screenshots.
extends Node3D
const OUT_DEFAULT := "user://shots/"

## Where screenshots go: user://shots/, or --out=<folder> after "--".
var out_dir := OUT_DEFAULT
const Sfx := preload("res://scripts/Audio/Sfx.gd")
func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.substr(6).trim_suffix("/") + "/"
	Sfx.volume_db = -60.0
	DirAccess.make_dir_recursive_absolute(out_dir)
	var scene_path := "res://main.tscn"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--scene="):
			scene_path = arg.substr(8)
	var level: Node = load(scene_path).instantiate()
	add_child(level)
	await _frames(60)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var player: Node3D = get_tree().get_first_node_in_group(&"player")
	var retro := get_node("/root/Retro")

	# --at=x,y,z puts you there; --look=x,y,z points you at it.
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--at="):
			var p := arg.substr(5).split_floats(",")
			player.global_position = Vector3(p[0], p[1], p[2])
			player.reset_physics_interpolation()
		elif arg.begins_with("--look="):
			var p := arg.substr(7).split_floats(",")
			var d: Vector3 = Vector3(p[0], p[1], p[2]) - player.get_node("Neck").global_position
			player.rotation.y = atan2(-d.x, -d.z)
			player.get_node("Neck").rotation.x = atan2(d.y, Vector2(d.x, d.z).length())

	await _frames(20)
	var base_yaw: float = player.rotation.y
	var base_pitch: float = player.get_node("Neck").rotation.x
	for view in [[0.0, 0.0], [PI * 0.5, 0.0], [PI, -0.2], [-PI * 0.5, 0.1]]:
		player.rotation.y = base_yaw + view[0]
		player.get_node("Neck").rotation.x = base_pitch + view[1]
		await _frames(15)
		await _shot("%s_%d" % [scene_path.get_file().get_basename(), int(rad_to_deg(view[0]))])
	retro.virtual_height = 0
	player.rotation.y = base_yaw
	player.get_node("Neck").rotation.x = base_pitch
	await _frames(10)
	await _shot("%s_off" % scene_path.get_file().get_basename())
	get_tree().quit()
func _shot(n: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out_dir + n + ".png")
func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame
