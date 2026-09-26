## Visual check, not a test: run it in a window and look at the screenshots.
##   Godot --fixed-fps 60 --resolution 1280x720 --path . res://tests/visual/stage_combat.tscn -- --only=hit --out=/some/folder
##   sequences: hit, telegraph, block, kill, kick, bow, wall (all without --only)
extends Node3D
## Windowed staging: plays out blows, blocks, kills, a kick and arrows, and
## saves screenshots at the moments that matter. Not a test: a camera.

const PLAYER := preload("res://Player.tscn")
const GUARD := preload("res://Guard.tscn")
const Props := preload("res://scripts/Interaction/Props.gd")
const NavBakerScript := preload("res://scripts/AISystem/NavBaker.gd")
const Sfx := preload("res://scripts/Audio/Sfx.gd")
const Fx := preload("res://scripts/Visual/Fx.gd")

const OUT_DEFAULT := "user://shots/"

## Where screenshots go: user://shots/, or --out=<folder> after "--".
var out_dir := OUT_DEFAULT

var player: CharacterBody3D
var only := ""


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.substr(6).trim_suffix("/") + "/"
	Sfx.volume_db = -60.0
	DirAccess.make_dir_recursive_absolute(out_dir)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--only="):
			only = arg.substr(7)
	_arena()
	var baker := NavigationRegion3D.new()
	baker.set_script(NavBakerScript)
	add_child(baker)
	player = PLAYER.instantiate()
	add_child(player)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	player.invulnerable = true
	player.reload_on_death = false
	player.show_hud = true
	player.global_position = Vector3(0, 1.05, 0)
	Props.give_weapons(player)
	player.inventory.select_by_id(&"sword")
	await baker.baked
	await _frames(30)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	if only == "" or only == "hit":
		await _hit_sequence()
	if only == "" or only == "telegraph":
		await _telegraph_sequence()
	if only == "" or only == "block":
		await _block_sequence()
	if only == "" or only == "kill":
		await _kill_sequence()
	if only == "" or only == "kick":
		await _kick_sequence()
	if only == "" or only == "bow":
		await _bow_sequence()
	if only == "" or only == "wall":
		await _wall_sequence()

	Sfx.silence()
	await _frames(5)
	get_tree().quit()


func _arena() -> void:
	var stone := Color(0.42, 0.4, 0.38)
	Props.block(self, Vector3(0, -0.5, 0), Vector3(80, 1, 80), Color(0.3, 0.29, 0.28))
	Props.block(self, Vector3(0, 2, -4.2), Vector3(12, 4, 0.4), stone)          # back wall
	Props.block(self, Vector3(-6, 2, 0), Vector3(0.4, 4, 12), stone)           # left wall
	Props.block(self, Vector3(20, 2, -4.2), Vector3(12, 4, 0.4), stone)
	Props.block(self, Vector3(-20, 1.5, -1.0), Vector3(4, 3, 0.3), stone)        # wall to swing at
	for at in [Vector3(-3, 3.2, -3.5), Vector3(3, 3.2, -3.5), Vector3(20, 3.2, -3.5), Vector3(-20, 3.0, 1.5), Vector3(40, 3.0, 1.0), Vector3(1.5, 3.0, 2.5), Vector3(21.5, 3.0, 2.5), Vector3(41, 3.0, -6.0)]:
		_torch(at)
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.03, 0.03, 0.05)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.35, 0.38, 0.5)
	environment.ambient_light_energy = 0.25
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.volumetric_fog_enabled = true
	environment.volumetric_fog_density = 0.02
	environment.glow_enabled = true
	var world := WorldEnvironment.new()
	world.environment = environment
	add_child(world)


func _torch(at: Vector3) -> void:
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.72, 0.42)
	light.light_energy = 2.2
	light.omni_range = 11.0
	light.omni_attenuation = 1.1
	light.shadow_enabled = true
	add_child(light)
	light.global_position = at


# --- sequences ---------------------------------------------------------------

func _hit_sequence() -> void:
	var g := _fighter(Vector3(0, 0, -1.6))
	_put_player(Vector3(0, 1.05, 0), 0.0)
	await _frames(40)
	await _shot("a00_ready")
	var hit := [false]
	player.combat.landed.connect(func(_t, _r, _d): hit[0] = true, CONNECT_ONE_SHOT)
	Input.action_press("throw")
	await _frames(2)
	Input.action_release("throw")
	await _frames(5)
	await _shot("a01_windup")
	await _until(func(): return player.combat.phase == player.combat.Phase.STRIKE, 20)
	await _frames(2)
	await _shot("a02_strike")
	await _until(func(): return hit[0], 30)
	await _shot("a03_contact")
	await _frames(3)
	await _shot("a04_contact_plus3")
	await _frames(8)
	await _shot("a05_spray")
	await _frames(25)
	await _shot("a06_drops")
	await _frames(60)
	await _shot("a07_after")
	g.queue_free()
	await _frames(10)


func _telegraph_sequence() -> void:
	var g := _fighter(Vector3(0, 0, -1.4))
	g._attack_timer = 0.0
	g.attack_cooldown = 9.0
	_put_player(Vector3(0, 1.05, 0), 0.0)
	await _until(func(): return g._phase == &"windup", 120)
	await _frames(12)
	await _shot("b01_raising")
	await _until(func(): return g._phase == &"windup" and g._phase_timer < 0.17, 60)
	await _shot("b02_glint")
	await _until(func(): return g._phase == &"windup" and g._phase_timer < 0.06, 60)
	await _shot("b03_downswing")
	await _until(func(): return g._phase == &"strike", 30)
	await _frames(2)
	await _shot("b04_strike")
	await _frames(20)
	g.queue_free()
	await _frames(10)


func _block_sequence() -> void:
	var g := _fighter(Vector3(0, 0, -1.4))
	g._attack_timer = 0.0
	g.attack_cooldown = 9.0
	_put_player(Vector3(0, 1.05, 0), 0.0)
	Input.action_press("block")
	await _frames(20)
	await _shot("c01_guard_up")
	await _until(func(): return g._phase == &"recover", 150)
	await _shot("c02_blocked")
	await _frames(2)
	await _shot("c03_blocked_plus2")
	await _frames(6)
	await _shot("c04_blocked_plus8")
	Input.action_release("block")
	g.queue_free()
	await _frames(20)
	# A quick blow he catches on his blade.
	var g2 := _fighter(Vector3(0, 0, -1.5))
	g2.block_chance = 1.0
	_put_player(Vector3(0, 1.05, 0), 0.0)
	await _frames(30)
	var landed := [false]
	player.combat.landed.connect(func(_t, _r, _d): landed[0] = true, CONNECT_ONE_SHOT)
	await _tap("throw")
	await _until(func(): return landed[0], 30)
	await _shot("c05_he_blocks")
	await _frames(4)
	await _shot("c06_he_blocks_plus4")
	g2.queue_free()
	await _frames(20)


func _kill_sequence() -> void:
	var g := _fighter(Vector3(0, 0, -1.6))
	g.health = 30.0
	_put_player(Vector3(0, 1.05, 0), 0.0)
	await _frames(30)
	var id := g.get_instance_id()
	player.combat.add_look_motion(Vector2(0.2, 0.0))
	Input.action_press("throw")
	await _frames(2)
	Input.action_release("throw")
	await _frames(8)
	await _until(func(): return not is_instance_id_valid(id), 40)
	await _shot("d01_killed")
	await _frames(12)
	await _shot("d02_falling")
	await _frames(20)
	await _shot("d03_landed")
	# Look down at him.
	player.get_node("Neck").rotation.x = -0.6
	await _frames(150)
	await _shot("d04_pool")
	for b in get_tree().get_nodes_in_group(&"bodies"):
		b.visible = false
	await _frames(200)
	await _shot("d05_pool_under")
	player.get_node("Neck").rotation.x = 0.0


func _kick_sequence() -> void:
	var g := _fighter(Vector3(20, 0, -1.2))
	_put_player(Vector3(20, 1.05, 0), 0.0)
	await _frames(30)
	await _tap("kick")
	await _frames(4)
	await _shot("e01_chamber")
	await _frames(4)
	await _shot("e02_contact")
	await _frames(8)
	await _shot("e03_flying")
	await _frames(20)
	await _shot("e04_skid")
	g.queue_free()
	await _frames(10)


func _bow_sequence() -> void:
	player.inventory.select_by_id(&"bow")
	var g := _fighter(Vector3(40, 0, -9))
	g.chase_speed = 0.0
	g.health = 300.0
	_put_player(Vector3(40, 1.05, 0), 0.0)
	await _frames(30)
	_aim(Vector3(40, 1.3, -9))
	Input.action_press("throw")
	await _frames(55)
	await _shot("f01_drawn")
	Input.action_release("throw")
	await _frames(5)
	await _shot("f02_flight")
	await _frames(30)
	await _shot("f03_stuck")
	_put_player(Vector3(40.5, 1.05, -7.8), 0.0)
	_aim(g.global_position + Vector3.UP * 1.1)
	await _frames(5)
	await _shot("f04_close")
	g.queue_free()
	player.inventory.select_by_id(&"sword")
	await _frames(20)


func _wall_sequence() -> void:
	_put_player(Vector3(-20, 1.05, 0.2), 0.0)
	await _frames(30)
	var bounced := [false]
	player.combat.deflected.connect(func(_p): bounced[0] = true, CONNECT_ONE_SHOT)
	await _tap("throw")
	await _until(func(): return bounced[0], 40)
	await _shot("g01_deflect")
	await _frames(4)
	await _shot("g02_deflect_plus4")
	await _frames(40)
	await _shot("g03_scratch")


# --- helpers -------------------------------------------------------------------

func _fighter(at: Vector3) -> CharacterBody3D:
	player.debug_light_level = 1.0
	var g: CharacterBody3D = GUARD.instantiate()
	g.position = at
	add_child(g)
	g.block_chance = 0.0
	g._attack_timer = 999.0
	g.attack_cooldown = 999.0
	g.rotation.y = PI
	g._engage(player)
	return g


func _put_player(at: Vector3, yaw: float) -> void:
	for a in ["move_forward", "move_back", "move_left", "move_right", "throw", "block", "kick"]:
		Input.action_release(a)
	player.movement_state = 0
	player.velocity = Vector3.ZERO
	player.global_position = at
	player.rotation.y = yaw
	player.get_node("Neck").rotation.x = 0.0
	player.combat._reset()
	player.combat.adrenaline = 0.0


func _aim(target: Vector3) -> void:
	var eye: Vector3 = player.get_node("Neck").global_position
	var d := target - eye
	player.rotation.y = atan2(-d.x, -d.z)
	player.get_node("Neck").rotation.x = atan2(d.y, Vector2(d.x, d.z).length())


func _shot(shot_name: String) -> void:
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	image.save_png(out_dir + shot_name + ".png")


func _tap(action: String) -> void:
	Input.action_press(action)
	await _frames(2)
	Input.action_release(action)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _until(cond: Callable, max_frames: int) -> void:
	for i in max_frames:
		if cond.call():
			return
		await get_tree().physics_frame
