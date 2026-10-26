extends Node3D
## The candle lane's candles as the player sees them in the real Metro: down the lane to the chapel, each votive
## ledge close, the masses on the floor by the doorway. Windowed, in the game's time:
##   Godot --path . --fixed-fps 60 --resolution 1152x648 res://tests/lane_candles_stills.tscn
## Saved to docs/superpowers/refs/underground/candles/ (review media, not committed).
const MAP := preload("res://maps/metro.tscn")
const OUT := "res://docs/superpowers/refs/underground/candles/"
## In the lane's frame: [where the eye is, what it looks at, the file's name].
const VIEWS := [
	[Vector3(2.0, 1.65, 1.1), Vector3(16.8, 1.2, 1.1), "1_down_the_lane_to_the_chapel"],
	[Vector3(8.5, 1.5, 0.9), Vector3(12.0, 1.05, -2.35), "2_the_north_ledge"],
	[Vector3(13.0, 1.4, 2.2), Vector3(12.8, 1.0, 4.55), "3_the_south_ledge_close"],
	[Vector3(12.5, 1.5, 1.0), Vector3(16.5, 0.3, 1.1), "4_the_masses_by_the_doorway"],
]

var eye: Camera3D
var lane: Node3D


func _ready() -> void:
	AudioServer.set_bus_mute(0, true)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var map: Node3D = MAP.instantiate()
	add_child(map)
	await _seconds(0.5)
	var fov: float = get_viewport().get_camera_3d().fov
	map.player.global_position = map.spawn_point() + Vector3(0.0, 1.05, 0.0)
	lane = map.get_node("candle_lane")
	eye = Camera3D.new()
	eye.fov = fov
	add_child(eye)
	eye.make_current()
	await _seconds(4.0)
	for view in VIEWS:
		eye.global_transform = Transform3D(Basis.IDENTITY, lane.to_global(view[0])).looking_at(lane.to_global(view[1]),
			Vector3.UP)
		await _seconds(0.5)
		RenderingServer.force_draw(false)
		get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path(OUT + view[2] + ".png"))
	get_tree().quit(0)


## `s` seconds of the game's time (60 frames a second under --fixed-fps 60).
func _seconds(s: float) -> void:
	for i in maxi(int(s * 60.0), 1):
		await get_tree().process_frame
