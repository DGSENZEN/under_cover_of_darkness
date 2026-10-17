extends Node3D
## Windowed visual QA: the first-person arms through station 17's free-run
## route (wall run, reaches, leap, pull-up) and a landing roll, a frame every
## few ticks while a move plays.
## Godot --fixed-fps 60 --resolution 960x540 --path . res://tests/visual/stage_freerun_arms.tscn -- --out=/tmp/arms

const GYM := preload("res://maps/traversal_gym.tscn")
var _out := "/tmp/arms/"
## Every how many ticks a frame is kept (1: a clip).
var _every := 3


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.trim_prefix("--out=").trim_suffix("/") + "/"
		if arg.begins_with("--every="):
			_every = maxi(int(arg.trim_prefix("--every=")), 1)
	DirAccess.make_dir_recursive_absolute(_out)
	var gym = GYM.instantiate()
	add_child(gym)
	await _frames(10)
	var p = get_tree().get_first_node_in_group("player")
	p.inventory.select_by_id(&"")
	var hud := gym.get_node_or_null("HUD")
	if hud != null:
		hud.visible = false
	gym.select_station(16)
	await _frames(20)
	Input.action_press("sprint")
	Input.action_press("move_forward")
	var shot := 0
	for i in 700:
		await _frames(1)
		var label: String = String(p.current_move.label) if p.current_move != null else ""
		if label != "" and label != "vault" and i % _every == 0:
			await _shot("route_%03d_%s" % [shot, label.replace(" ", "_")])
			shot += 1
		if p.movement_state == 0 and p.get_feet_position().y > 8.9 and p.global_position.z - gym.stations[16].root.position.z < -10.0:
			break
	Input.action_release("sprint")
	Input.action_release("move_forward")
	await _frames(30)
	# A sprinting landing from 9 m: the roll.
	p.teleport(Transform3D(Basis.IDENTITY, gym.stations[16].root.position + Vector3(-6, 10.05, 6)))
	await _frames(3)
	Input.action_press("sprint")
	Input.action_press("move_forward")
	var landed := -1
	for i in 120:
		await _frames(1)
		if landed < 0 and p._on_floor_now():
			landed = i
		if landed >= 0 and i - landed <= 45 and (i - landed) % _every == 0:
			await _shot("roll_%02d" % (i - landed))
	get_tree().quit()


func _shot(label: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(_out + label + ".png")


func _frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame
