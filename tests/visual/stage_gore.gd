## Visual check, not a test: wounds and what is left. A kill up close through
## your own eyes (blood across the view), a bleeding man's trail seen from
## above, a corpse hacked apart, a blast.
##   Godot --fixed-fps 60 --resolution 960x540 --path . res://tests/visual/stage_gore.tscn -- --out=/some/folder
extends Node3D

const PLAYER := preload("res://Player.tscn")
const GUARD := preload("res://Guard.tscn")
const Props := preload("res://scripts/Interaction/Props.gd")
const Sfx := preload("res://scripts/Audio/Sfx.gd")
const NavBakerScript := preload("res://scripts/AISystem/NavBaker.gd")

var out_dir := "user://gore/"
var player: CharacterBody3D


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.substr(6).trim_suffix("/") + "/"

	DirAccess.make_dir_recursive_absolute(out_dir)
	Sfx.volume_db = -60.0
	Props.block(self, Vector3(0, -0.5, 0), Vector3(60, 1, 60), Color(0.46, 0.44, 0.4))
	Props.block(self, Vector3(0, 1.5, -3.2), Vector3(8, 3, 0.4), Color(0.55, 0.53, 0.5))
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(-0.9, 0.5, 0.0)
	add_child(sun)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.6, 0.6, 0.64)
	add_child(env)
	var baker := NavigationRegion3D.new()
	baker.set_script(NavBakerScript)
	add_child(baker)

	player = PLAYER.instantiate()
	player.position = Vector3(0, 1.05, 0.6)
	add_child(player)
	player.invulnerable = true
	player.reload_on_death = false

	if player.has_node("LightGem"):
		player.get_node("LightGem").queue_free()

	player.debug_light_level = 1.0
	Props.give_weapons(player, 12)
	player.inventory.select_by_id(&"sword")
	await baker.baked

	# 1. A kill up close, through your eyes.
	var g := _guard(Vector3(0, 0, -0.75))
	g.max_health = 30.0
	g.health = 6.0
	await _frames(40)
	Input.action_press("throw")
	await _frames(2)
	Input.action_release("throw")
	await _frames(8)
	await _shot("a_kill_close")
	await _frames(40)
	await _shot("b_after")
	await _frames(100)
	await _shot("c_later")

	# 2. A corpse hacked apart: from the side.
	var above := Camera3D.new()
	add_child(above)
	above.fov = 55
	above.global_position = Vector3(3.2, 2.6, 2.6)
	above.look_at(Vector3(0.0, 0.2, -0.6))
	above.current = true
	var corpse := _last_body()

	if corpse != null:
		var man: Node3D = corpse.man()
		var skeleton: Skeleton3D = man.skeleton

		for bone in [&"upperarm_l", &"thigh_r"]:
			var child: StringName = &"lowerarm_l" if bone == &"upperarm_l" else &"calf_r"
			var a: Vector3 = skeleton.global_transform * (man.pose_now(skeleton.find_bone(bone)) as Transform3D).origin
			var b: Vector3 = skeleton.global_transform * (man.pose_now(skeleton.find_bone(child)) as Transform3D).origin
			corpse.struck(a.lerp(b, 0.5), Vector3.DOWN + Vector3.RIGHT * 0.3, true, true)
			await _frames(20)

	await _frames(60)
	await _shot("d_hacked")

	# 3. A bleeding man walking off: the trail he leaves, from above.
	var walker := _guard(Vector3(-4, 0, 6))
	await _frames(20)
	walker.take_hit(40.0, player, &"power", walker._rig.chest(), Vector3.FORWARD)
	walker.take_hit(30.0, player, &"power", walker._rig.chest(), Vector3.FORWARD)
	walker._stagger = 0.0
	walker.set_physics_process(false)
	walker.set_physics_process(true)
	var way := (Vector3(6, 0, 10) - walker.global_position).normalized()

	# Carried along at a walk (whatever he would rather do), dripping.
	for i in 240:
		walker.global_position += way * 2.2 / 60.0
		walker.velocity = Vector3.ZERO
		walker._attack_timer = 999.0
		await get_tree().physics_frame

	above.global_position = Vector3(1.0, 7.5, 12.5)
	above.look_at(Vector3(1.0, 0.0, 8.0))
	await _frames(2)
	await _shot("e_trail")

	# 4. A blast.
	var boom := _guard(Vector3(4, 0, -1))
	await _frames(20)
	above.global_position = Vector3(6.5, 2.4, 2.5)
	above.look_at(Vector3(4.0, 0.6, -1.0))
	boom.take_hit(150.0, null, &"blast", boom._rig.chest() + Vector3(0.3, -0.3, 0.3), Vector3.UP)
	await _frames(6)
	await _shot("f_blast")
	await _frames(70)
	await _shot("g_blast_after")
	get_tree().quit()


func _guard(at: Vector3) -> CharacterBody3D:
	var g: CharacterBody3D = GUARD.instantiate()
	g.archetype = &"swordsman"
	g.position = at
	# Facing you.
	g.rotation.y = PI if at.z < player.global_position.z else 0.0
	add_child(g)
	g._attack_timer = 999.0
	g.attack_cooldown = 999.0
	g.block_chance = 0.0
	g._fighter.parry_chance = 0.0
	return g


func _last_body() -> Node:
	var found: Node = null

	for n in get_tree().get_nodes_in_group(&"bodies"):
		if n.has_method("man") and not n.is_queued_for_deletion():
			found = n

	return found


func _shot(shot_name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out_dir + shot_name + ".png")


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame
