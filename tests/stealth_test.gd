extends Node3D

const PLAYER := preload("res://Player.tscn")
const GUARD := preload("res://Guard.tscn")
const Props := preload("res://scripts/Interaction/Props.gd")
const NavBakerScript := preload("res://scripts/AISystem/NavBaker.gd")
const SoundBus := preload("res://scripts/StimuliSystem/SoundBus.gd")
const LightProbe := preload("res://scripts/StimuliSystem/LightProbe.gd")


class Ear:
	var events: Array = []

	func hear_sound(event: Dictionary) -> void:
		events.append(event)

const RELAXED := 0
const SUSPICIOUS := 1
const INVESTIGATING := 2
const SEARCHING := 3
const COMBAT := 4

var player: CharacterBody3D
var guard: CharacterBody3D
var baker: NavigationRegion3D
var results: Array[String] = []
var barks: Array[String] = []


func _ready() -> void:
	Props.block(self, Vector3(0, -0.5, 0), Vector3(80, 1, 60))           # floor, top at 0
	Props.block(self, Vector3(0, 1.5, -6), Vector3(4, 3, 0.4))           # tall wall, blocks sight
	Props.block(self, Vector3(10, 0.5, -4), Vector3(3, 1.0, 0.3))        # low wall, partial cover

	# A wall with a 1 m doorway at x = -20, and a closed door in it.
	Props.block(self, Vector3(-23.0, 1.25, -5), Vector3(5.0, 2.5, 0.3))
	Props.block(self, Vector3(-17.0, 1.25, -5), Vector3(5.0, 2.5, 0.3))
	Props.block(self, Vector3(-20.0, 2.3, -5), Vector3(1.0, 0.4, 0.3))
	var door := Props.door(self, Vector3(-20.5, 0, -5))

	baker = NavigationRegion3D.new()
	baker.set_script(NavBakerScript)
	add_child(baker)

	player = PLAYER.instantiate()
	add_child(player)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	player.debug_traversal = false
	player.invulnerable = true
	player.reload_on_death = false
	if player.has_node("LightGem"):
		player.get_node("LightGem").queue_free()
	player.global_position = Vector3(30, 1.05, 20)

	guard = GUARD.instantiate()
	guard.debug_ai = false
	add_child(guard)
	guard.barked.connect(func(text): barks.append(text))

	await baker.baked
	await _frames(5)
	await _run(door)

	print("\n==== RESULTS ====")
	for r in results:
		print(r)
	get_tree().quit()


func _run(door: Node3D) -> void:
	# S1 the navmesh baked from the level's static bodies
	var polygons: int = baker.navigation_mesh.get_polygon_count()
	_check("S1 navmesh bakes at load", baker.is_baked and polygons > 4, "polygons %d" % polygons)

	# S2 in darkness, in plain view, 8 m away: nothing
	await _stage(Vector3.ZERO, Vector3(0, 1.05, -8 + 12), 0.03, true)
	_put_player(Vector3(0, 1.05, -4.5))
	await _frames(240)
	_check("S2 dark and in view: unseen", guard.alert < 1.0 and guard.state == RELAXED,
		"alert %.1f state %d vis %.3f" % [guard.alert, guard.state, guard.visibility])

	# S3 same spot, lit: spotted at once
	await _stage(Vector3.ZERO, Vector3(0, 1.05, -4.5), 1.0, true)
	var frames_to_combat := -1
	for i in 120:
		await _frames(1)
		if guard.state == COMBAT:
			frames_to_combat = i
			break
	_check("S3 lit and in view: combat within a second", frames_to_combat >= 0 and frames_to_combat < 60 and barks.has("You there! Stop!"),
		"frames %d barks %s" % [frames_to_combat, barks])

	# S4 lit, but behind the guard
	await _stage(Vector3.ZERO, Vector3(0, 1.05, 6), 1.0, true)
	await _frames(180)
	_check("S4 lit but behind the guard: unseen", guard.alert < 1.0, "alert %.1f vis %.3f" % [guard.alert, guard.visibility])

	# S5 lit, in the view cone, but a wall is in the way
	await _stage(Vector3.ZERO, Vector3(0, 1.05, -9), 1.0, true)
	await _frames(180)
	_check("S5 lit but behind a wall: unseen", guard.alert < 1.0, "alert %.1f vis %.3f" % [guard.alert, guard.visibility])

	# S6 partial cover: a low wall hides part of you, crouching hides more
	await _stage(Vector3(10, 0, 0), Vector3(10, 1.05, -5), 0.5, true)
	await _frames(3)
	var vis_standing: float = guard.visibility
	await _stage(Vector3(10, 0, 0), Vector3(10, 1.05, -5), 0.5, true)
	Input.action_press("crouch")
	await _frames(12)
	guard.alert = 0.0
	await _frames(2)
	var vis_crouched: float = guard.visibility
	Input.action_release("crouch")
	_check("S6 cover and crouching reduce visibility", vis_standing > 0.05 and vis_crouched > 0.0 and vis_crouched < vis_standing * 0.6,
		"standing %.3f crouched %.3f" % [vis_standing, vis_crouched])

	# S7 a noise behind the guard: suspicious, then holds, then calms down
	await _stage(Vector3.ZERO, Vector3(30, 1.05, 20), 0.0, true)
	SoundBus.emit_sound(Vector3(0, 0, 7), 55.0, self, &"test")
	await _frames(2)
	var alert_after_noise: float = guard.alert
	var state_after_noise: int = guard.state
	await _frames(100)
	var held: bool = guard.state == SUSPICIOUS and guard.alert > alert_after_noise - 1.0
	await _frames(260)
	_check("S7 hysteresis: rises at once, holds, decays", state_after_noise == SUSPICIOUS and alert_after_noise > 25.0 and held and guard.state == RELAXED and barks.has("Probably nothing."),
		"alert %.1f state %d held %s final state %d alert %.1f" % [alert_after_noise, state_after_noise, held, guard.state, guard.alert])

	# S8 louder: goes to look, searches, gives up, and stays a little warier
	await _stage(Vector3.ZERO, Vector3(30, 1.05, 20), 0.0, true)
	guard.look_around_time = 0.4
	guard.search_points = 2
	var noise_at := Vector3(0, 0, 8)
	SoundBus.emit_sound(noise_at, 58.0, self, &"test")
	SoundBus.emit_sound(noise_at, 58.0, self, &"test")
	await _frames(2)
	var went_to_look: bool = guard.state == INVESTIGATING
	var closest := INF
	var searched := false
	for i in 2400:
		await _frames(1)
		closest = minf(closest, guard.global_position.distance_to(noise_at))
		if guard.state == SEARCHING:
			searched = true
		if searched and guard.state == RELAXED:
			break
	_check("S8 investigate, search, give up", went_to_look and closest < 2.5 and searched and guard.state == RELAXED and guard.wariness > 1.1 and barks.has("Must have been rats."),
		"looked %s closest %.2f searched %s state %d wariness %.2f" % [went_to_look, closest, searched, guard.state, guard.wariness])

	# S9 sound alone never makes combat
	await _stage(Vector3.ZERO, Vector3(30, 1.05, 20), 0.0, true)
	for i in 6:
		SoundBus.emit_sound(Vector3(0, 0, 3), 66.0, self, &"test")
		await _frames(2)
	_check("S9 hearing cannot reach combat", guard.alert <= 85.01 and guard.alert > 60.0 and guard.state != COMBAT,
		"alert %.1f state %d" % [guard.alert, guard.state])

	# S10 seen, chased, then lost behind the wall in the dark
	await _stage(Vector3.ZERO, Vector3(0, 1.05, -4.5), 1.0, true)
	guard.lose_time = 1.0
	guard.look_around_time = 0.4
	guard.search_points = 1
	await _until(func(): return guard.state == COMBAT, 120)
	var was_combat: bool = guard.state == COMBAT
	var start_gap: float = guard.global_position.distance_to(player.global_position)
	await _frames(30)
	var chasing: bool = guard.global_position.distance_to(player.global_position) < start_gap - 0.5
	player.debug_light_level = 0.0
	_put_player(Vector3(30, 1.05, 20))
	await _until(func(): return guard.state == SEARCHING, 400)
	var lost: bool = guard.state == SEARCHING
	await _until(func(): return guard.state == RELAXED, 2400)
	_check("S10 chase, lose, search, stand down", was_combat and chasing and lost and guard.state == RELAXED and is_equal_approx(guard.wariness, 1.15),
		"combat %s chasing %s lost %s state %d wariness %.2f" % [was_combat, chasing, lost, guard.state, guard.wariness])

	# S11 footsteps in the dark: sprinting up behind a guard is heard, creeping is not
	var sprint_alert := await _approach_from_behind(true, false)
	var creep_alert := await _approach_from_behind(false, true)
	_check("S11 sprinting is heard, creeping is not", sprint_alert >= 20.0 and creep_alert < 20.0,
		"alert at 3.5 m: sprinting %.1f creeping %.1f" % [sprint_alert, creep_alert])

	# S12 a thrown crate draws the guard to where it LANDS
	await _stage(Vector3(20, 0, -10), Vector3(20, 1.05, 6), 0.0, true)
	var crate := Props.crate(self, Vector3(20, 0.3, 4.6))
	await _frames(20)
	_aim(crate.global_position)
	await _frames(3)
	await _tap("frob")
	await _frames(15)
	var holding: bool = player.frob.held == crate
	player.rotation.y = 0.0
	player.get_node("Neck").rotation.x = 0.25
	await _frames(3)
	await _tap("throw")
	await _until(func(): return guard.has_last_known, 240)
	var landed_at: Vector3 = crate.global_position
	var heard_at: Vector3 = guard.last_known_position
	_check("S12 thrown object distracts", holding and guard.has_last_known and guard.alert > 20.0 and heard_at.distance_to(landed_at) < 3.5 and heard_at.distance_to(player.global_position) > 3.0,
		"holding %s alert %.1f heard %.1f m from the crate, %.1f m from the player" % [holding, guard.alert, heard_at.distance_to(landed_at), heard_at.distance_to(player.global_position)])

	# S13 a patrol route through a closed door: the guard opens it and carries on
	var route := Node3D.new()
	add_child(route)
	for point in [Vector3(-20, 0, -1), Vector3(-20, 0, -9)]:
		var marker := Marker3D.new()
		route.add_child(marker)
		marker.global_position = point
	var walker: CharacterBody3D = GUARD.instantiate()
	walker.debug_ai = false
	walker.patrol_wait = 0.2
	add_child(walker)
	walker.global_position = Vector3(-20, 0, -1)
	walker.patrol_route = walker.get_path_to(route)
	walker._waypoints.assign(route.get_children())
	walker._go_to(route.get_child(1).global_position)
	player.debug_light_level = 0.0
	_put_player(Vector3(30, 1.05, 20))
	await _until(func(): return walker.global_position.z < -8.0, 1500)
	_check("S13 guard opens a door on its route", door.is_open and walker.global_position.z < -8.0,
		"door open %s guard z %.2f" % [door.is_open, walker.global_position.z])

	# ------------------------------------------------------------------
	# Knockouts, bodies, and the rest. Fresh guards from here on.
	# ------------------------------------------------------------------
	guard.queue_free()
	walker.queue_free()
	await _frames(3)
	Props.give_blackjack(player)

	# K1 an unaware guard, from behind, in the dark: down he goes
	var g1 := _new_guard(Vector3(30, 0, -12), 0.0)
	player.debug_light_level = 0.0
	_put_player(Vector3(30, 1.05, -10.7))
	await _frames(10)
	_aim(g1.global_position + Vector3.UP * 1.4)
	await _frames(3)
	await _tap("throw")
	await _frames(40)
	var bodies := get_tree().get_nodes_in_group(&"bodies")
	_check("K1 blackjack knocks out an unaware guard", not is_instance_valid(g1) and bodies.size() == 1,
		"guard gone %s bodies %d" % [not is_instance_valid(g1), bodies.size()])
	var body: RigidBody3D = bodies[0] if bodies.size() > 0 else null

	# K3 shoulder the body: slower, no sprint, then put it down
	_aim(body.global_position)
	await _frames(4)
	var prompt_body: String = player.frob.current_prompt()
	await _tap("frob")
	await _frames(5)
	var shouldering: bool = player.frob.is_shouldering() and not body.visible
	await _frames(3)
	var body_pose_name: String = String(player.body_pose.pose)
	player.rotation.y = PI
	player.get_node("Neck").rotation.x = 0.0
	Input.action_press("move_forward")
	Input.action_press("sprint")
	await _frames(60)
	var loaded_speed: float = Vector3(player.velocity.x, 0, player.velocity.z).length()
	_release_all()
	await _frames(20)
	await _tap("frob")
	await _frames(30)
	# Set down: left to physics (a man with a body of his own: limp again).
	var put_down: bool = not player.frob.is_shouldering() and body.visible and (not body.freeze or (body.get("limp") == true and body.ragdoll() != null and body.ragdoll().is_limp()))
	var body_gap: float = Vector3(body.global_position.x - player.global_position.x, 0, body.global_position.z - player.global_position.z).length()
	_check("K3 shoulder a body, walk slowly, put it down", body_pose_name == "carry_body" and prompt_body == "Shoulder the body" and shouldering and loaded_speed < player.walk_speed * 0.65 and loaded_speed > 2.0 and put_down and body_gap < 1.8,
		"prompt '%s' shouldering %s speed %.1f put down %s gap %.2f" % [prompt_body, shouldering, loaded_speed, put_down, body_gap])

	# K2 a guard already fighting cannot be clubbed
	var g2 := _new_guard(Vector3(10, 0, 18), 0.0)
	player.debug_light_level = 1.0
	_put_player(Vector3(10, 1.05, 14))
	await _until(func(): return g2.state == COMBAT, 180)
	await _until(func(): return g2.global_position.distance_to(player.global_position) < 2.2, 300)
	_aim(g2.global_position + Vector3.UP * 1.4)
	await _frames(2)
	await _tap("throw")
	await _frames(30)
	_check("K2 blackjack fails on a guard in combat", is_instance_valid(g2) and g2.state == COMBAT and barks_of(g2).has("Club me, would you?"),
		"alive %s state %d" % [is_instance_valid(g2), g2.state if is_instance_valid(g2) else -1])
	g2.queue_free()
	await _frames(3)

	# K5 a body in darkness, right in front of a guard: not found
	player.debug_light_level = 0.0
	_put_player(Vector3(30, 1.05, 20))
	body.freeze = true
	body.global_position = Vector3(-30, 0.4, -20)
	body.freeze = false
	var g3 := _new_guard(Vector3(-30, 0, -14), 0.0)
	LightProbe.invalidate()
	await _frames(150)
	var dark_light: float = LightProbe.light_at(self, body.global_position + Vector3.UP * 0.25)
	_check("K5 a body in the dark is not found", g3.state == RELAXED and not body.discovered and dark_light < 0.01,
		"state %d discovered %s light %.3f" % [g3.state, body.discovered, dark_light])

	# K4 light the same spot: found, alarm raised
	var lamp := OmniLight3D.new()
	lamp.omni_range = 8.0
	lamp.light_energy = 2.0
	add_child(lamp)
	lamp.global_position = Vector3(-30, 2.5, -20)
	LightProbe.invalidate()
	await _until(func(): return body.discovered, 240)
	var lit_light: float = LightProbe.light_at(self, body.global_position + Vector3.UP * 0.25)
	_check("K4 a body in the light is found", body.discovered and g3.state == SEARCHING and barks_of(g3).has("A body! Someone's in here!") and is_equal_approx(g3.wariness, 1.3) and lit_light > 0.3,
		"discovered %s state %d wariness %.2f light %.2f" % [body.discovered, g3.state, g3.wariness, lit_light])
	g3.queue_free()
	lamp.queue_free()
	await _frames(3)

	# K6 one guard sees you and shouts: his colleague, facing away, comes running
	var g4 := _new_guard(Vector3(0, 0, 0), 0.0)
	var g5 := _new_guard(Vector3(0, 0, 14), PI)
	player.debug_light_level = 1.0
	_put_player(Vector3(0, 1.05, -4.5))
	await _until(func(): return g4.state == COMBAT, 120)
	await _frames(3)
	var helper_state: int = g5.state
	var helper_goal: Vector3 = g5.last_known_position
	_check("K6 a shout brings a colleague", g4.state == COMBAT and helper_state >= INVESTIGATING and helper_goal.distance_to(player.global_position) < 2.5 and barks_of(g5).has("I'm coming!"),
		"shouter %d helper %d goal %.1f m from the player barks %s" % [g4.state, helper_state, helper_goal.distance_to(player.global_position), barks_of(g5)])
	g5.queue_free()

	# K7 caught: he hits you until you drop
	player.invulnerable = false
	player.health = player.max_health
	var hits := 0
	var died := [false]
	player.died.connect(func(): died[0] = true)
	player.damaged.connect(func(_a): hits += 1)
	await _until(func(): return player.is_dead, 900)
	_check("K7 being caught costs health, then your life", player.is_dead and died[0] and player.health <= 0.0,
		"dead %s health %.0f" % [player.is_dead, player.health])
	g4.queue_free()
	player.is_dead = false
	player.health = player.max_health
	player.invulnerable = true
	await _frames(3)

	# K8 carpet is quieter than stone, by the table's amount
	var ear := Ear.new()
	SoundBus.add_listener(ear)
	Props.block(self, Vector3(-30, 0.05, 10), Vector3(4, 0.1, 12), Color(0.5, 0.2, 0.2), "carpet")
	player.debug_light_level = 0.0
	_put_player(Vector3(-30, 1.15, 15))
	await _frames(20)
	ear.events.clear()
	Input.action_press("move_forward")
	await _frames(70)
	_release_all()
	var carpet_db := _loudest(ear.events, &"footstep")
	_put_player(Vector3(-20, 1.05, 15))
	await _frames(20)
	ear.events.clear()
	Input.action_press("move_forward")
	await _frames(70)
	_release_all()
	var stone_db := _loudest(ear.events, &"footstep")
	SoundBus.remove_listener(ear)
	_check("K8 carpet muffles footsteps", is_equal_approx(stone_db, 48.0) and is_equal_approx(carpet_db, 34.0),
		"stone %.0f dB carpet %.0f dB" % [stone_db, carpet_db])

	# K9 leaning: the head goes out, and a wall stops it
	_put_player(Vector3(-10, 1.05, 22))
	await _frames(10)
	Input.action_press("lean_right")
	await _frames(50)
	var open_lean: float = player.lean
	var head: Vector3 = player.get_sight_points()[0]
	var chest: Vector3 = player.get_sight_points()[1]
	Input.action_release("lean_right")
	await _frames(40)
	var recentred: float = player.lean
	Props.block(self, Vector3(-10 + 0.5 + 0.15, 1.5, 22), Vector3(0.3, 3, 2))
	await _frames(5)
	Input.action_press("lean_right")
	await _frames(50)
	var walled_lean: float = player.lean
	Input.action_release("lean_right")
	_check("K9 lean out, and not through walls", open_lean > 0.95 and head.x - chest.x > 0.4 and absf(recentred) < 0.02 and walled_lean > 0.3 and walled_lean < 0.8,
		"open %.2f head out %.2f m recentred %.2f at a wall %.2f" % [open_lean, head.x - chest.x, recentred, walled_lean])

	# K10 the light probe matches Godot's falloff, and walls cast shadow
	var probe_lamp := OmniLight3D.new()
	probe_lamp.omni_range = 8.0
	probe_lamp.omni_attenuation = 1.0
	probe_lamp.light_energy = 1.0
	probe_lamp.shadow_enabled = true
	add_child(probe_lamp)
	probe_lamp.global_position = Vector3(-30, 4.0, 24)
	Props.block(self, Vector3(-26, 2.0, 24), Vector3(0.3, 4, 3))
	LightProbe.invalidate()
	await _frames(3)
	var at_two: float = LightProbe.light_at(self, Vector3(-30, 2.0, 24))
	var at_four: float = LightProbe.light_at(self, Vector3(-30, 0.02, 24))
	var shadowed: float = LightProbe.light_at(self, Vector3(-24, 2.0, 24))
	_check("K10 light probe: 0.50 at 2 m, 0.22 at 4 m, 0 behind a wall", absf(at_two - 0.496) < 0.01 and absf(at_four - 0.22) < 0.01 and shadowed < 0.001,
		"2 m %.3f  4 m %.3f  shadowed %.3f" % [at_two, at_four, shadowed])


var _bark_log := {}


func _new_guard(at: Vector3, yaw: float) -> CharacterBody3D:
	var g: CharacterBody3D = GUARD.instantiate()
	g.debug_ai = false
	g.position = at
	g.rotation.y = yaw
	add_child(g)
	_bark_log[g] = []
	g.barked.connect(func(text): _bark_log[g].append(text))
	return g


func barks_of(g: Node) -> Array:
	return _bark_log.get(g, [])


func _loudest(events: Array, kind: StringName) -> float:
	var best := 0.0
	for event in events:
		if event["kind"] == kind:
			best = maxf(best, event["db"])
	return best


## The player runs or creeps up on the guard's back in total darkness.
## Returns the guard's alert when the player is 3.5 m away.
func _approach_from_behind(sprint: bool, crouch: bool) -> float:
	await _stage(Vector3(-10, 0, 0), Vector3(-10, 1.05, 12), 0.0, true)
	player.rotation.y = 0.0

	if crouch:
		Input.action_press("crouch")
		await _frames(10)

	Input.action_press("move_forward")

	if sprint:
		Input.action_press("sprint")

	await _until(func(): return player.global_position.z < 3.5, 900)
	var heard: float = guard.alert
	_release_all()
	await _frames(10)
	return heard


# --------------------------------------------------------------------------
## Put the guard on post at `guard_at` facing -Z, calm, and the player at
## `player_at` with the given light level.
func _stage(guard_at: Vector3, player_at: Vector3, light: float, reset_wariness: bool) -> void:
	_release_all()
	barks.clear()
	player.debug_light_level = light
	_put_player(player_at)

	guard.global_position = guard_at
	guard.rotation.y = 0.0
	guard.velocity = Vector3.ZERO
	guard._home = Transform3D(Basis.IDENTITY, guard_at)
	guard.alert = 0.0
	guard.has_last_known = false
	guard._since_stimulus = 99.0
	guard._since_seen = 99.0
	guard._look_timer = 0.0
	guard.lose_time = 4.0
	guard.look_around_time = 3.0
	guard.search_points = 3
	guard.state = RELAXED
	guard._go_to(guard_at)

	if reset_wariness:
		guard.wariness = 1.0

	if guard.get_node_or_null("Head") != null:
		guard.get_node("Head").rotation.y = 0.0
	guard._idle_time = 0.0

	await _frames(3)
	guard.alert = 0.0
	barks.clear()


func _put_player(at: Vector3) -> void:
	player.movement_state = 0
	player.current_move = null
	player.velocity = Vector3.ZERO
	player.global_position = at
	player.rotation.y = 0.0
	player.get_node("Neck").rotation.x = 0.0


func _aim(target: Vector3) -> void:
	var eye: Vector3 = player.get_node("Neck").global_position
	var d := target - eye
	player.rotation.y = atan2(-d.x, -d.z)
	player.get_node("Neck").rotation.x = atan2(d.y, Vector2(d.x, d.z).length())


func _release_all() -> void:
	for a in ["move_forward", "move_back", "move_left", "move_right", "jump", "sprint", "crouch", "frob", "throw"]:
		if InputMap.has_action(a):
			Input.action_release(a)


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


func _check(test_name: String, ok: bool, detail: String) -> void:
	results.append("%s  %s   [%s]" % ["PASS" if ok else "FAIL", test_name, detail])
