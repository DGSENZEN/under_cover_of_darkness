extends Node3D
## A ladder can disappear while its navigation link remains in a queued plan.
const GUARD := preload("res://Guard.tscn")

func _ready() -> void:
	var guard := GUARD.instantiate() as CharacterBody3D
	add_child(guard)
	guard.set_physics_process(false)
	var ladder := Node3D.new()
	add_child(ladder)
	var link := NavigationLink3D.new()
	link.set_meta(&"kind", &"ladder")
	link.set_meta(&"volume", ladder)
	add_child(link)
	ladder.free()
	var begun = guard._climb.begin({"owner": link, "link_entry_position": Vector3.ZERO, "link_exit_position": Vector3.UP * 3})
	var okay: bool = begun is bool and begun == false and not guard._climb.active()
	print("==== RESULTS ====")
	print("%s GL1 a guard rejects a queued ladder whose volume was freed" % ("PASS" if okay else "FAIL"))
	link.queue_free()
	guard.queue_free()
	get_tree().quit(0 if okay else 1)
