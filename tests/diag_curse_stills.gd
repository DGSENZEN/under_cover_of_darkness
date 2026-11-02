extends Node3D
## Stills of the evil eye on the screen, from the real game, windowed:
##   Godot --path . --resolution 1152x648 res://tests/diag_curse_stills.tscn -- --out=<folder>

const GYM := preload("res://maps/hunt_gym.tscn")
const EyeScript := preload("res://scripts/Monsters/FloatingEye.gd")

var out := "user://"


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.trim_prefix("--out=")

	var gym: Node3D = GYM.instantiate()
	add_child(gym)
	await _frames(100)
	var p: CharacterBody3D = gym.player
	p.invulnerable = true
	p.teleport(Transform3D(Basis.IDENTITY, Vector3(-2, 1.05, -14)))
	gym.wave_now = 3
	p.loadout.pack_item(&"egg")
	p.loadout.item_counts[&"egg"] = 2
	await _frames(30)
	var right: CharacterBody3D = EyeScript.new()
	right.seed_value = 5
	right.position = Vector3(5, 2.5, -20)
	add_child(right)
	var left: CharacterBody3D = EyeScript.new()
	left.seed_value = 6
	left.position = Vector3(-8, 2.5, -12)
	add_child(left)

	for e in [right, left]:
		e.state = e.State.CIRCLE
		e.next_swoop_in = 100.0

	await _until_stared(p, 0.75)
	await _shot("warning")
	await _until_cursed(p)
	await _frames(80)
	await _shot("cursed_full")
	p.statuses.apply(&"evil_eye", 8.0)
	p.statuses._left[&"evil_eye"] = 3.4
	await _frames(40)
	await _shot("cursed_half")
	p.statuses._left[&"evil_eye"] = 8.0
	Input.action_press("use_item")
	await _frames(2)
	Input.action_release("use_item")
	await _frames(49)
	await _shot("dispel_start")
	await _frames(10)
	await _shot("dispel_middle")
	await _frames(8)
	await _shot("dispel_late")
	await _frames(25)
	await _shot("cleansed")
	# Again, to let it run out by itself.
	p.statuses.clear(&"cleansed")
	p.statuses.apply(&"evil_eye", 3.0)
	await _frames(70)
	p.statuses._left[&"evil_eye"] = 0.1
	await _frames(35)
	await _shot("easing_away")
	get_tree().quit(0)


func _until_stared(p: Node, level: float) -> void:
	for i in 400:
		await get_tree().physics_frame
		if p.statuses.stared() >= level:
			return


func _until_cursed(p: Node) -> void:
	for i in 400:
		await get_tree().physics_frame
		if p.statuses.has(&"evil_eye"):
			return


func _shot(name_of: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out.path_join("curse_" + name_of + ".png"))
	print("STILL ", name_of)


func _frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame
