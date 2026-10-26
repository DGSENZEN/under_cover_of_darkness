extends Node3D
## The Pasaje's middle stretch as the player sees it in the real Metro (docs/superpowers/plans/2026-10-26-pasaje-market.md):
## the player camera's field of view, the eye 1.65 m over the floor. The in-game views, then the same places lit by a
## work lamp carried at the eye, to judge the joints close. Windowed, in the game's time:
##   Godot --path . --fixed-fps 60 --resolution 1152x648 res://tests/pasaje_stills.tscn
## Saved to docs/superpowers/refs/underground/pasaje/ (review media, not committed).
const MAP := preload("res://maps/metro.tscn")
const OUT := "res://docs/superpowers/refs/underground/pasaje/"
## In the set's frame: [where the eye is, what it looks at, the file's name].
const VIEWS := [
	[Vector3(6.2, 1.65, 0.45), Vector3(-5.0, 1.3, -1.0), "1_the_lanes_mouth_looking_out"],
	[Vector3(0.0, 1.65, -19.2), Vector3(0.0, 1.4, 20.0), "2_the_north_end_looking_south"],
	[Vector3(0.0, 1.65, 18.5), Vector3(0.0, 1.6, -20.0), "3_the_south_end_looking_north"],
	[Vector3(1.5, 1.65, -6.0), Vector3(-4.7, 1.8, -1.0), "4_the_herb_markets_mouth"],
	[Vector3(-2.0, 1.65, -7.0), Vector3(4.7, 2.6, 0.5), "5_the_lanes_mouth_from_the_street"],
	[Vector3(0.0, 1.65, 2.0), Vector3(0.0, 4.4, 6.5), "6_the_ceiling_and_girders"],
]
## The close views lit: [eye, looks at, name].
const CLOSE := [
	[Vector3(-2.6, 1.4, -4.4), Vector3(-4.7, 1.2, -3.0), "7_lit_herb_reveal_jamb"],
	[Vector3(3.0, 3.2, -4.6), Vector3(4.7, 3.6, -3.3), "8_lit_mains_turning_in"],
	[Vector3(-3.4, 3.6, 1.0), Vector3(-4.7, 4.3, 0.0), "9_lit_girder_bearing"],
	[Vector3(-3.0, 1.3, -3.6), Vector3(-4.9, 0.0, -1.0), "10_lit_herb_sill"],
	[Vector3(0.0, 1.2, -17.6), Vector3(1.0, 0.0, -20.0), "11_lit_north_joint"],
]

var eye: Camera3D
var pasaje: Node3D


func _ready() -> void:
	AudioServer.set_bus_mute(0, true)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var map: Node3D = MAP.instantiate()
	add_child(map)
	await _seconds(0.5)
	var fov: float = get_viewport().get_camera_3d().fov
	map.player.global_position = map.spawn_point() + Vector3(0.0, 1.05, 0.0)
	pasaje = map.get_node("pasaje")
	eye = Camera3D.new()
	eye.fov = fov
	add_child(eye)
	eye.make_current()
	await _seconds(4.0)
	for view in VIEWS:
		_look(view[0], view[1])
		await _seconds(0.5)
		_shot(view[2])
	var lamp := OmniLight3D.new()
	lamp.light_color = Color(1.0, 0.95, 0.88)
	lamp.light_energy = 1.6
	lamp.omni_range = 7.0
	eye.add_child(lamp)
	for view in CLOSE:
		_look(view[0], view[1])
		await _seconds(0.5)
		_shot(view[2])
	get_tree().quit(0)


func _look(from: Vector3, target: Vector3) -> void:
	eye.global_transform = Transform3D(Basis.IDENTITY, pasaje.to_global(from)).looking_at(pasaje.to_global(target), Vector3.UP)


func _shot(file_name: String) -> void:
	RenderingServer.force_draw(false)
	get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path(OUT + file_name + ".png"))


## `s` seconds of the game's time (60 frames a second under --fixed-fps 60).
func _seconds(s: float) -> void:
	for i in maxi(int(s * 60.0), 1):
		await get_tree().process_frame
