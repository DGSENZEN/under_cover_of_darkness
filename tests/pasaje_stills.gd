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
	[Vector3(3.9, 1.65, 0.5), Vector3(-0.8, 1.2, -14.0), "11a_life_from_the_lanes_mouth_north"],
	[Vector3(3.9, 1.65, 0.5), Vector3(-0.8, 1.2, 15.0), "11b_life_from_the_lanes_mouth_south"],
	[Vector3(0.6, 1.65, -13.8), Vector3(-3.8, 1.3, -15.6), "11c_keeper_tortas"],
	[Vector3(0.6, 1.65, -3.6), Vector3(-3.8, 1.3, -5.25), "11d_keeper_herbs"],
	[Vector3(0.8, 1.65, -14.4), Vector3(-2.7, 1.1, -17.4), "11e_the_medium_at_the_circle"],
	[Vector3(-0.4, 1.65, -1.2), Vector3(2.3, 1.1, -3.5), "11f_the_curandero_censing"],
	[Vector3(0.0, 1.65, 3.5), Vector3(0.0, 1.4, 14.0), "11g_the_south_end_the_organ_grinder"],
	[Vector3(0.0, 1.65, 11.5), Vector3(0.0, 1.5, 17.2), "12a_the_kiosk"],
	[Vector3(-1.4, 1.65, 14.4), Vector3(0.2, 1.2, 17.0), "12b_the_kiosk_close"],
	[Vector3(-3.0, 1.65, 19.4), Vector3(0.0, 1.4, 17.4), "12c_behind_the_kiosk"],
	[Vector3(-1.0, 1.65, -40.0), Vector3(0.0, 1.6, -20.0), "13a_astral_north_from_the_stairs"],
	[Vector3(0.0, 1.65, -32.0), Vector3(0.0, 1.8, -20.0), "13b_astral_north_halfway"],
	[Vector3(-1.0, 1.65, -30.0), Vector3(-5.0, 2.4, -27.0), "13c_astral_north_its_wall"],
	[Vector3(0.5, 1.65, -31.0), Vector3(14.0, 0.5, -28.0), "13f_astral_north_looking_east"],
	[Vector3(-0.5, 1.65, -31.0), Vector3(-14.0, 7.0, -33.0), "13g_astral_north_looking_west_up"],
	[Vector3(0.5, 1.65, -27.0), Vector3(2.0, -12.0, -24.0), "13h_astral_north_looking_down"],
	[Vector3(0.0, 1.65, -23.5), Vector3(0.0, 1.6, -14.0), "13j_astral_the_markets_threshold"],
	[Vector3(-1.0, 1.65, -37.0), Vector3(-1.0, 1.4, -46.0), "13k_astral_the_stairs_threshold"],
	[Vector3(0.0, 1.65, -14.0), Vector3(0.0, 1.6, -32.0), "13l_astral_from_the_market"],
	[Vector3(0.0, 1.65, 23.0), Vector3(0.0, 1.6, 40.0), "13d_astral_south_going_on"],
	[Vector3(0.0, 1.65, 36.0), Vector3(0.0, 1.6, 15.0), "13e_astral_south_coming_back"],
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
	# From inside the north passage through a long lens: the serpent, its head, an eye in its crack, the lit
	# constellation (each aimed again just before its shot: they move).
	var passage: Node3D = map.get_node_or_null("astral_north")
	if passage != null:
		var stand := pasaje.to_global(Vector3(0.0, 1.65, -31.0))
		var serpent: Node3D = passage.presences.filter(func(p): return p.get_meta("kind", "") == "serpent")[0]
		var eyes: Node3D = passage.presences.filter(func(p): return p.get_meta("kind", "") == "eyes")[0]
		var long := [
			[func(): return serpent.to_global(Vector3(0.0, 0.0, -6.0)), 34.0, "13m_astral_zoom_the_serpent"],
			[func(): return serpent.to_global(Vector3(0.0, 0.2, 1.2)), 9.0, "13n_astral_zoom_its_head"],
			[func(): return (eyes.get_child(0) as Node3D).global_position, 8.0, "13o_astral_zoom_an_eye", -37.5],
			[func(): return passage.constellations[2].global_position, 40.0, "13p_astral_zoom_a_constellation"],
		]
		# (A view's own stand along the passage, when it names one.)
		for view in long:
			var from: Vector3 = pasaje.to_global(Vector3(0.0, 1.65, view[3])) if view.size() > 3 else stand
			eye.fov = view[1]
			eye.global_transform = Transform3D(Basis.IDENTITY, from).looking_at(view[0].call(), Vector3.UP)
			await _seconds(0.5)
			eye.global_transform = Transform3D(Basis.IDENTITY, from).looking_at(view[0].call(), Vector3.UP)
			_shot(view[2])
		eye.fov = fov
		# The glimpses from spot to spot, the plane over the eye: the player stood at each spot (so the passage
		# shows what it shows there), the eye beside them looking where the glimpse is.
		var main: PackedVector3Array = passage.way[0]
		var spots := [[0.15, Vector3(0.0, 30.0, 0.0), "13q_astral_glimpse_the_echo_overhead"],
			[0.5, Vector3(25.0, 80.0, 5.0), "13r_astral_glimpse_the_star_skirt"],
			[0.85, (passage.glimpses[2].get_child(0) as Node3D).global_position if passage.glimpses[2].get_child_count() > 0 else Vector3.ZERO, "13s_astral_glimpse_the_great_door"]]
		for spot in spots:
			var stand_at: Vector3 = main[int(spot[0] * (main.size() - 1))] + Vector3(0.0, 1.05, 0.0)
			map.player.global_position = stand_at
			var look_at: Vector3 = spot[1] if spot[2].ends_with("door") else stand_at + spot[1]
			eye.global_transform = Transform3D(Basis.IDENTITY, stand_at + Vector3(0.0, 0.6, 0.0)).looking_at(look_at, Vector3.UP)
			await _seconds(3.0)
			_shot(spot[2])
		map.player.global_position = map.spawn_point() + Vector3(0.0, 1.05, 0.0)
		await _seconds(2.0)
	var lamp := OmniLight3D.new()
	lamp.light_color = Color(1.0, 0.95, 0.88)
	lamp.light_energy = 1.6
	lamp.omni_range = 7.0
	eye.add_child(lamp)
	for view in CLOSE:
		_look(view[0], view[1])
		await _seconds(0.5)
		_shot(view[2])
	# In the north astral passage through the player's own camera, its hands up: the void behind them, never over them.
	lamp.queue_free()
	var player: Node3D = map.player
	player.global_position = pasaje.to_global(Vector3(-1.0, 1.05, -37.5))
	player.rotation.y = PI
	var own: Array = player.find_children("*", "Camera3D", true, false)
	if not own.is_empty():
		(own[0] as Camera3D).make_current()
		await _seconds(1.5)
		_shot("13i_astral_through_your_own_eyes")
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
