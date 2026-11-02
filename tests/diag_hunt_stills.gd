extends Node3D
## Stills of the hunt gym's combat marks, from the real game, windowed:
##   Godot --path . --resolution 1152x648 res://tests/diag_hunt_stills.tscn -- --out=<folder>

const GYM := preload("res://maps/hunt_gym.tscn")

var out := "user://"


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.trim_prefix("--out=")

	var gym: Node3D = GYM.instantiate()
	add_child(gym)
	await _frames(120)
	var p: CharacterBody3D = gym.player
	p.invulnerable = true
	await _shot("room_lead")

	p.loadout.pack_round(&"copal")
	p.loadout.pack_item(&"egg")
	gym.kit_table.show_for(p.loadout)
	await _frames(10)
	await _shot("room_packed")

	p.teleport(Transform3D(Basis.IDENTITY, Vector3(0, 1.05, -8)))
	await _frames(60)
	gym.wave(1)
	await _frames(100)
	await _shot("yard_wave")

	var g: Node = p.revolver
	g.cylinder_round = &"copal"
	g.loaded[&"cylinder"] = 3
	p.inventory.ammo[&"copal_rounds"] = 9
	await _frames(5)
	await _shot("yard_copal_three")

	var cross: Control = p.hud.get("_crosshair")
	cross.contact(&"weak")
	await _frames(2)
	await _shot("mark_weak")
	await _frames(40)
	cross.contact(&"resisted")
	await _frames(2)
	await _shot("mark_resisted")

	g.flip_barrel()
	await _frames(5)
	await _shot("shell_up")
	g.flip_barrel()

	g.loaded[&"cylinder"] = 2
	g._start_loading(g.weapon())
	await _frames(40)
	await _shot("reloading")
	g._stop_loading()

	# Polish round one: what answers look like.
	var eyes: Array = get_tree().get_nodes_in_group(&"monsters").filter(func(m): return not m.asleep and not m.dead)
	var at: Transform3D = g.aim()
	var ahead: Vector3 = at.origin - at.basis.z * 6.0
	eyes[0].global_position = ahead + Vector3(-1.0, 0.0, 0.0)
	eyes[1].global_position = ahead + Vector3(1.0, 0.0, 0.0)
	eyes[0].round_hint = &"copal"
	eyes[0].take_hit(55.0, p, &"bullet", eyes[0].global_position, Vector3.FORWARD)
	await _frames(25)
	await _shot("cloud_rising")
	await _frames(70)
	await _shot("cloud_full")
	for cloud in get_tree().get_nodes_in_group(&"copal_clouds"):
		cloud.queue_free()
	var close: Vector3 = g.aim().origin - g.aim().basis.z * 4.0
	eyes[1].global_position = close
	eyes[1].take_hit(5000.0, p, &"blast", close, Vector3.FORWARD)
	await _frames(4)
	await _shot("death_burst")
	await _frames(40)
	await _shot("death_remains")
	await _frames(40)
	await _shot("death_lying")

	Input.action_press("sprint")
	Input.action_press("move_forward")
	await _frames(30)
	Input.action_press("crouch")
	await _frames(10)
	await _shot("slide")
	Input.action_release("crouch")
	Input.action_release("sprint")
	Input.action_release("move_forward")
	await _frames(30)

	p.statuses.apply(&"evil_eye", 30.0)
	await _frames(100)
	await _shot("evil_eye")
	p.teleport(Transform3D(Basis(Vector3.UP, PI), Vector3(0, 1.05, 1.0)))
	await _frames(30)
	await _shot("evil_eye_room")
	get_tree().quit(0)


func _shot(name_of: String) -> void:
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	image.save_png(out.path_join(name_of + ".png"))
	var view := image.get_size()
	var crop := Rect2i(view / 2 - Vector2i(50, 50), Vector2i(100, 100)) if name_of.begins_with("mark") else Rect2i(view - Vector2i(210, 160), Vector2i(210, 160))
	var close := image.get_region(crop)
	close.resize(crop.size.x * 3, crop.size.y * 3, Image.INTERPOLATE_NEAREST)
	close.save_png(out.path_join("crop_" + name_of + ".png"))
	var p: Node = get_tree().get_first_node_in_group(&"player")
	print("STILL ", name_of, " eggs ", p.loadout.item_counts, " using ", p.loadout.using(), " input ", Input.is_action_pressed("use_item"))


func _frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame
