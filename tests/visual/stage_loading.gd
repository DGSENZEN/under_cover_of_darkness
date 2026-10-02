extends Node3D
## The city's loading screen as it is drawn: one still early (laying out the
## harbour), one while the navmesh bakes, then the city once it has faded.
##   Godot --path . --resolution 1280x720 res://tests/visual/stage_loading.tscn -- --out=/tmp/loading-shots
const City := preload("res://maps/city.tscn")
var out := "/tmp/loading-shots/"


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.trim_prefix("--out=").trim_suffix("/") + "/"

	DirAccess.make_dir_recursive_absolute(out)
	AudioServer.set_bus_mute(0, true)
	var city := City.instantiate()
	add_child(city)
	await _shot("1_laying_out")

	# (Once the navmesh is baking.)
	while city.player == null and (city.baker == null or not city.baker.is_inside_tree()):
		await get_tree().process_frame

	await _shot("2_baking", 30)
	await city.ready_to_play if city.player == null else get_tree().process_frame
	await _shot("3_played", 90)
	print("PASS the loading screen captured: laying out, baking, played")
	get_tree().quit()


func _shot(label: String, frames := 2) -> void:
	for i in frames:
		await get_tree().process_frame

	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out + label + ".png")
