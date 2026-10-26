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
	[Vector3(1.2, 1.65, -11.0), Vector3(-4.0, 1.4, -16.0), "7_the_tortas_stall"],
	[Vector3(0.5, 1.65, -1.0), Vector3(4.0, 1.5, -5.0), "8_the_copal_stall_by_the_mouth"],
	[Vector3(0.8, 1.65, -12.6), Vector3(-3.8, 1.2, -15.6), "8a_close_tortas"],
	[Vector3(-0.6, 1.65, -6.4), Vector3(3.8, 1.2, -8.9), "8b_close_candles"],
	[Vector3(0.6, 1.65, -2.6), Vector3(-3.8, 1.2, -5.25), "8c_close_herbs"],
	[Vector3(-0.6, 1.65, 10.4), Vector3(3.8, 1.2, 13.1), "8d_close_atole"],
	[Vector3(0.0, 1.65, 9.5), Vector3(0.0, 2.7, 19.5), "8e_the_canopy"],
	[Vector3(1.5, 1.65, 15.5), Vector3(-1.0, 2.9, 19.0), "8f_under_the_canopy"],
	[Vector3(1.8, 1.4, 9.0), Vector3(-4.7, 1.2, 9.0), "8g_wall_west_alcove"],
	[Vector3(-1.8, 1.4, 15.3), Vector3(4.7, 1.2, 15.3), "8h_wall_east_by_the_canopy"],
	[Vector3(0.0, 1.65, 6.0), Vector3(0.0, 1.5, 20.0), "8i_the_south_end"],
	[Vector3(-1.6, 1.4, -6.7), Vector3(4.7, 1.4, -6.7), "8j_wall_east_by_the_lanes_mouth"],
	[Vector3(1.6, 1.4, -18.4), Vector3(-4.7, 1.4, -18.4), "8k_wall_west_at_the_north_end"],
	[Vector3(0.6, 1.65, -15.4), Vector3(-2.6, 0.0, -18.6), "9a_ward_the_north_circle"],
	[Vector3(-0.6, 1.65, 15.8), Vector3(2.0, 0.0, 19.15), "9b_ward_under_the_canopy"],
	[Vector3(1.4, 1.6, -6.7), Vector3(4.3, 0.3, -6.7), "9c_ward_the_copal_alcove"],
	[Vector3(-1.2, 1.6, -1.0), Vector3(-4.8, 0.7, -1.0), "9d_ward_the_herb_markets_threshold"],
	[Vector3(1.6, 1.6, 0.45), Vector3(4.8, 0.3, 0.45), "9e_ward_the_lanes_threshold"],
	[Vector3(-2.4, 1.6, 13.8), Vector3(-4.7, 1.4, 13.8), "9f_bills_close_south_west"],
	[Vector3(2.4, 1.6, -14.4), Vector3(4.7, 1.4, -14.4), "9g_bills_close_north_east"],
	[Vector3(1.6, 1.65, -14.6), Vector3(-3.2, 0.9, -18.4), "10a_happened_the_north_rite"],
	[Vector3(0.6, 1.65, -16.0), Vector3(-1.05, 0.0, -17.55), "10b_happened_the_spiral_cracks"],
	[Vector3(0.6, 1.65, 2.2), Vector3(3.3, 0.0, 1.3), "10c_happened_the_claws_from_the_lane"],
	[Vector3(-1.0, 1.65, 4.4), Vector3(3.6, 0.3, 1.2), "10d_happened_the_claws_from_the_street"],
	[Vector3(0.3, 1.65, 18.9), Vector3(-4.7, 2.0, 18.6), "10e_happened_the_hand"],
]
## The close views lit: [eye, looks at, name].
const CLOSE := [
	[Vector3(1.0, 1.65, -13.0), Vector3(-4.0, 1.2, -15.6), "9_lit_tortas_stall"],
	[Vector3(0.6, 1.65, -6.5), Vector3(4.0, 1.4, -8.9), "10_lit_candles_booth"],
	[Vector3(-1.0, 1.65, -9.5), Vector3(-4.0, 0.7, -11.6), "11_lit_fruit_barrow"],
	[Vector3(-1.2, 1.65, 9.6), Vector3(-4.0, 1.4, 11.6), "12_lit_coffee_lean_to"],
	[Vector3(1.6, 0.5, -4.75), Vector3(4.2, 0.15, -4.75), "13_lit_under_the_copal_counter"],
	[Vector3(-3.0, 1.3, -3.4), Vector3(-4.85, 0.0, -1.0), "14_lit_herb_sill_salt"],
	[Vector3(-3.0, 1.5, 9.0), Vector3(-4.7, 1.4, 9.0), "15_lit_bills_west"],
	[Vector3(3.0, 1.5, -18.4), Vector3(4.7, 1.4, -18.4), "16_lit_bills_north_end"],
	[Vector3(-2.0, 1.4, -17.0), Vector3(-4.7, 1.0, -18.4), "17_lit_the_scorch"],
	[Vector3(1.6, 1.3, 1.0), Vector3(3.4, 0.0, 1.4), "18_lit_the_claws"],
	[Vector3(-2.4, 1.7, 17.6), Vector3(-4.7, 2.2, 18.6), "19_lit_the_hand"],
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
