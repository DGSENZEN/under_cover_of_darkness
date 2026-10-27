extends Node3D
## Diagnostic: the player's own eye stepped through the north astral passage's gates, a frame every 15 cm, to see what
## happens as the eye crosses a gate. Windowed, in the game's time:
##   Godot --path . --fixed-fps 60 --resolution 1152x648 res://tests/diag_astral_entry.tscn
## Saved to docs/superpowers/refs/underground/pasaje/entry/ (review media, not committed).
const MAP := preload("res://maps/metro.tscn")
const OUT := "res://docs/superpowers/refs/underground/pasaje/entry/"
## [from, to (x, z on the floor), which way the player faces (yaw), its name].
const WALKS := [
	[Vector2(-10.0, 26.0), Vector2(-10.0, 35.4), PI, "stairs_in"],
	[Vector2(-9.0, 57.0), Vector2(-9.0, 53.4), 0.0, "mouth_in"],
	[Vector2(-9.0, 53.4), Vector2(-9.0, 57.0), PI, "mouth_out"],
]
const STEP := 0.15


func _ready() -> void:
	AudioServer.set_bus_mute(0, true)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var map: Node3D = MAP.instantiate()
	add_child(map)
	await _frames(60)
	var player: Node3D = map.player
	var floor_y: float = map.get_node("astral_north").bounds.position.y
	for walk in WALKS:
		var from: Vector2 = walk[0]
		var to: Vector2 = walk[1]
		var steps := int(from.distance_to(to) / STEP)
		player.global_position = Vector3(from.x, floor_y + 1.05, from.y)
		player.rotation.y = walk[2]
		await _frames(90)
		for k in steps + 1:
			var at := from.lerp(to, float(k) / steps)
			player.global_position = Vector3(at.x, floor_y + 1.05, at.y)
			player.rotation.y = walk[2]
			await _frames(4)
			_shot("%s_%02d" % [walk[3], k])
	get_tree().quit(0)


func _shot(file_name: String) -> void:
	RenderingServer.force_draw(false)
	get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path(OUT + file_name + ".png"))


func _frames(n: int) -> void:
	for i in n:
		# (Never held by the pause screen a windowed run can raise when it loses focus.)
		get_tree().paused = false
		await get_tree().process_frame
