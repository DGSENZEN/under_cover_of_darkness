extends Node3D
## Diagnostic: the Metro loaded, a few frames, then freed and quit: what errors its teardown raises. Run headless:
##   Godot --headless --path . res://tests/diag_metro_quit.tscn
const MAP := preload("res://maps/metro.tscn")


func _ready() -> void:
	var map: Node3D = MAP.instantiate()
	add_child(map)
	for i in 30:
		await get_tree().process_frame
	print("diag: freeing the map")
	map.free()
	print("diag: freed")
	await get_tree().process_frame
	get_tree().quit(0)
