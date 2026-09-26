## Visual check of the proving grounds and the fighters in them: overviews,
## the three archetypes side by side, each blow wound up, a guard's guard,
## his parry and his kick, and your own hands charging and blocking.
##   Godot --path . --resolution 1280x720 res://tests/visual/stage_arena.tscn -- --out=<dir>
extends Node3D

const ARENA := preload("res://maps/combat_arena.tscn")
const Sfx := preload("res://scripts/Audio/Sfx.gd")

var out_dir := "user://shots/"
var arena: Node3D
var player: CharacterBody3D


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.substr(6).trim_suffix("/") + "/"

	Sfx.volume_db = -60.0
	DirAccess.make_dir_recursive_absolute(out_dir)
	arena = ARENA.instantiate()
	add_child(arena)
	player = arena.player
	player.invulnerable = true
	await arena._baker.baked
	await _frames(30)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	# Nobody at a post notices the camera wandering about.
	for g in get_tree().get_nodes_in_group(&"guards"):
		g.set_physics_process(false)

	await _view(Vector3(0, 1.05, 14), Vector3(0, 1.0, -12), "arena_entry")
	await _view(Vector3(-13.5, 4.25, -6.0), Vector3(-2, 0.5, -16), "arena_gallery")
	await _view(Vector3(-30, 1.05, 2), Vector3(-30, 0.8, -12), "arena_yard")
	await _view(Vector3(30, 1.05, 2), Vector3(30, 1.0, -14), "arena_garden")
	await _view(Vector3(-30, 1.05, -36.5), Vector3(-26, 1.0, -48), "arena_cells")

	# The three of them, side by side, in the ring.
	var line: Array = []

	for i in 3:
		var kind: StringName = [&"swordsman", &"duelist", &"brute"][i]
		var g: CharacterBody3D = arena._spawn(kind, Vector3(-2.4 + i * 2.4, 0, -14), PI)
		g._attack_timer = 999.0
		g._fighter.stays_put = true
		line.append(g)

	await _frames(10)

	for g in line:
		g._engage(player)

	await _view(Vector3(0, 1.05, -8.5), Vector3(0, 1.3, -14), "arena_lineup")

	# Each blow, wound up and held just before it falls.
	var swordsman: CharacterBody3D = line[0]
	var brute: CharacterBody3D = line[2]
	line[1].queue_free()
	brute.global_position = Vector3(3.5, 0, -14)

	for kind in [&"overhead", &"left", &"right", &"thrust"]:
		await _blow(swordsman, kind, Vector3(-2.4, 1.05, -10.8))

	await _blow(brute, &"heavy", Vector3(6.5, 1.05, -9.8))

	# His guard up, his parry, his kick.
	swordsman._fighter.guarding = true
	swordsman._fighter._guard_hold = 5.0
	await _view(Vector3(-2.4, 1.05, -11.2), Vector3(-2.4, 1.3, -14), "guard_guarding", 20)
	swordsman._fighter.guarding = false
	swordsman._fighter._parry_at = swordsman._game_time + 0.18
	await _view(Vector3(-2.4, 1.05, -11.2), Vector3(-2.4, 1.3, -14), "guard_parry", 10)
	await _blow(swordsman, &"kick", Vector3(-4.6, 1.05, -12.6), 0.85)

	# Your hands: a charged blow, and a raised guard, with stamina spent.
	for g in [swordsman, brute]:
		g.queue_free()

	player.inventory.select_by_id(&"sword")
	player.global_position = Vector3(0, 1.05, -8)
	player.rotation.y = 0.0
	player.get_node("Neck").rotation.x = 0.0
	player.combat.stamina = 55.0
	await _frames(40)
	Input.action_press("throw")
	await _frames(45)
	await _shot("hands_charging")
	Input.action_release("throw")
	await _frames(40)
	Input.action_press("block")
	await _frames(20)
	await _shot("hands_blocking")
	Input.action_release("block")
	get_tree().quit()


## Starts `kind` on `g`, waits until it is `at` of the way up, and looks.
func _blow(g: CharacterBody3D, kind: StringName, from: Vector3, at := 0.72) -> void:
	player.global_position = from
	_look(g.global_position + Vector3.UP * 1.3)
	await _frames(15)
	g._phase = &""
	g._stagger = 0.0
	g._fighter._start(kind)

	for i in 120:
		if g._phase == &"windup" and g._fighter.progress() >= at:
			break

		await _frames(1)

	await _shot("blow_%s_%s" % [g.archetype, kind])
	await _frames(60)


func _view(at: Vector3, look: Vector3, name: String, settle := 30) -> void:
	player.global_position = at
	player.velocity = Vector3.ZERO
	player.reset_physics_interpolation()
	_look(look)
	await _frames(settle)
	await _shot(name)


func _look(target: Vector3) -> void:
	var d: Vector3 = target - player.get_node("Neck").global_position
	player.rotation.y = atan2(-d.x, -d.z)
	player.get_node("Neck").rotation.x = atan2(d.y, Vector2(d.x, d.z).length())


func _shot(n: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out_dir + n + ".png")


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame
