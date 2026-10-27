extends Node3D
## Diagnostic: the Metro loaded, a few frames, then freed and quit: what errors its teardown raises. Run headless:
##   Godot --headless --path . res://tests/diag_metro_quit.tscn -- [--no-south]
const MAP := preload("res://maps/metro.tscn")


func _ready() -> void:
	var map: Node3D = MAP.instantiate()
	add_child(map)
	for i in 30:
		await get_tree().process_frame
	if "--parts" in OS.get_cmdline_user_args():
		var south: Node3D = map.get_node("astral_south")
		var parts := south.get_children()
		# (Its glimpses first, then the rest in order.)
		parts.sort_custom(func(p, q): return int(p.has_meta("shown")) > int(q.has_meta("shown")))
		for part in parts:
			print("diag: freeing ", part.name)
			part.free()
	if "--no-south" in OS.get_cmdline_user_args() and map.get_node_or_null("astral_south") != null:
		map.get_node("astral_south").free()
		print("diag: south freed first")
	print("diag: freeing the map")
	map.free()
	print("diag: freed")
	await get_tree().process_frame
	get_tree().quit(0)
