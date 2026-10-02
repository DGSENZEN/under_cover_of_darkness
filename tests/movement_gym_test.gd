extends Node3D

const GYM := preload("res://maps/traversal_gym.tscn")
const TimeFx := preload("res://scripts/Visual/TimeFx.gd")
var failed := false
var checks := 0

func _ready() -> void:
	var original_rate := Engine.physics_ticks_per_second
	var original_scale := Engine.time_scale
	var gym = GYM.instantiate()
	add_child(gym)
	await _frames(6)
	var p = get_tree().get_first_node_in_group("player")
	# A reset during an aimed drop used to leave a live target and assisted
	# jump/catch cooldowns behind, even though the player appeared on his feet.
	p.drop_target = {"anchor": Vector3(100, 5, 100), "normal": Vector3.BACK, "lip_y": 6.05}
	p._assist_active = true
	p._regrab_timer = 0.8
	p._failed_plan_cooldown = 0.5
	p._climb_reattach_timer = 0.5
	p._kicks_this_airtime = 1
	Input.action_press("jump")
	p.teleport(Transform3D(Basis.IDENTITY, Vector3(0, 1.05, 8)))
	_check("MG1 teleport clears unfinished traversal and consumes held jump", p.drop_target.is_empty() and not p._assist_active and p._regrab_timer == 0.0 and p._failed_plan_cooldown == 0.0 and p._climb_reattach_timer == 0.0 and p._kicks_this_airtime == 0 and p._jump_hold_consumed)
	Input.action_release("jump")
	if not gym.has_method("select_station"):
		_check("MG2 advanced gym has station navigation", false)
	else:
		await _exercise(gym, p)
	gym.queue_free()
	await _frames(2)
	_check("MG11 leaving the gym restores engine settings", Engine.physics_ticks_per_second == original_rate and is_equal_approx(Engine.time_scale, original_scale))
	print("\n==== RESULTS ====\n%d checks, %d failed" % [checks, int(failed)])
	get_tree().quit(1 if failed else 0)

func _exercise(gym, p) -> void:
	_check("MG2 sixteen separated stations", gym.stations.size() == 16 and gym.stations[0].root.position.distance_to(gym.stations[1].root.position) >= 30.0)
	gym.select_station(8)
	await _frames(4)
	_check("MG3 station spawn fits real player capsule", p.global_position.distance_to(gym.stations[8].spawn) < 0.1 and p.scanner.fits(p.global_position, false))
	# Practice routes start at gate zero; ignored gates cannot skip a route.
	gym.checkpoint_reached(8, 2, p)
	_check("MG4 finish cannot start a course", not gym.run.running and not gym.run.finished)
	gym.checkpoint_reached(8, 0, p)
	gym.run.tick(1.25)
	gym.checkpoint_reached(8, 2, p)
	_check("MG5 out-of-order checkpoint does not advance", gym.run.next_gate == 1)
	gym.checkpoint_reached(8, 1, p)
	gym.run.tick(0.75)
	gym.checkpoint_reached(8, 2, p)
	_check("MG6 finish records ordered splits and best time", gym.run.finished and is_equal_approx(gym.run.best[8], 2.0) and gym.run.splits.size() == 3)
	gym.select_station(11)
	gym._obstacle_time = 1.0
	gym._update_obstacles()
	var moved: Vector3 = gym.movers[0].body.position
	p.health = 2.0
	p.combat.stamina = 1.0
	p.combat.adrenaline = p.combat.adrenaline_max
	gym.reset_station()
	_check("MG7 reset restores resources and deterministic obstacle phase", p.health == 100.0 and p.combat.stamina == p.combat.stamina_max and gym._obstacle_time == 0.0 and not gym.movers[0].body.position.is_equal_approx(moved))
	_check("MG16 reset clears a ready combat finisher", p.combat.adrenaline == 0.0)
	_check("MG8 restart clears route and retains personal best", not gym.run.running and gym.run.next_gate == 0 and gym.run.best.has(8))
	# Actual low-ceiling fixture: a standing mantle cannot fit, crouched can.
	gym.select_station(10)
	var origin: Vector3 = gym.stations[10].root.position
	p.teleport(Transform3D(Basis.IDENTITY, origin + Vector3(0, 1.03, -2.48)))
	await _frames(3)
	var profile = p.scanner.scan(Vector3.FORWARD, Vector3.ZERO, false)
	var accepted: bool = profile != null and p._try_traversal(profile)
	await _frames(100)
	_check("MG9 gym low ceiling forces safe crouched mantle", accepted and p.is_crouched and p.movement_state == 0 and p.global_position.z < origin.z - 3.0)
	# Reset ignores gates from another station and objects other than player.
	gym.reset_station()
	gym.checkpoint_reached(0, 0, p)
	gym.checkpoint_reached(10, 0, self)
	_check("MG10 inactive gates and other bodies cannot start route", not gym.run.running)
	gym.select_station(0)
	Input.action_press("move_forward")
	await _frames(75)
	Input.action_release("move_forward")
	_check("MG12 walking through real START area starts timer", gym.run.running and gym.run.next_gate == 1)
	p._die()
	gym.reset_station()
	_check("MG13 practice death restores visible hands", not p.is_dead and not p.hand._suppressed)
	var slow := InputEventKey.new()
	slow.keycode = KEY_F9
	slow.pressed = true
	gym._input(slow)
	TimeFx.hitstop(get_tree(), 0.01)
	await get_tree().create_timer(0.03, true, false, true).timeout
	_check("MG14 slow-motion preset survives combat hitstop", is_equal_approx(Engine.time_scale, 0.5))
	TimeFx.clear()
	TimeFx.set_base(1.0)
	gym.select_station(6)
	var ladder_at: Vector3 = gym.stations[6].root.position + Vector3(0, 1.05, -2.2)
	p.teleport(Transform3D(Basis.IDENTITY, ladder_at))
	Input.action_press("move_forward")
	await _frames(12)
	var attached: bool = p.movement_state == 3
	gym.reset_station()
	await _frames(4)
	Input.action_release("move_forward")
	_check("MG15 reset with forward held cannot reattach distant ladder", attached and p.movement_state == 0 and p.global_position.distance_to(gym.stations[6].spawn) < 0.5)
	# Exercise the wet geometry players can revisit in station 14.
	gym.select_station(13)
	var wet_origin: Vector3 = gym.stations[13].root.position
	p.teleport(Transform3D(Basis.IDENTITY, wet_origin + Vector3(-4.5, 1.32, -5)))
	await _frames(5)
	var was_swimming: bool = p.movement_state == 4
	Input.action_press("move_forward")
	for i in 300:
		await _frames(1)
		if p.movement_state == 0 and p.global_position.z < wet_origin.z - 10.2:
			break
	Input.action_release("move_forward")
	await _frames(40)
	_check("MG20 water station supports a wet stair exit", was_swimming and p.movement_state == 0 and p.get_feet_position().y > 1.9 and p.global_position.z < wet_origin.z - 10.2)
	p.teleport(Transform3D(Basis.IDENTITY, wet_origin + Vector3(4, 1.32, -7.6)))
	await _frames(5)
	was_swimming = p.movement_state == 4
	Input.action_press("move_forward")
	Input.action_press("jump")
	for i in 180:
		await _frames(1)
		if p.movement_state == 0 and absf(p.global_position.z - wet_origin.z + 9) < 0.2:
			break
	Input.action_release("move_forward")
	Input.action_release("jump")
	await _frames(40)
	_check("MG21 water station supports a boat rail clamber", was_swimming and p.movement_state == 0 and absf(p.get_feet_position().y - 1.88) < 0.04 and absf(p.global_position.z - wet_origin.z + 9) < 0.2)
	var clock_before := TimeFx.real_time()
	Engine.physics_ticks_per_second = 120
	var clock_after := TimeFx.real_time()
	_check("MG17 changing physics rate preserves feedback clock", clock_after >= clock_before and clock_after - clock_before < 0.05)
	await _frames(6)
	var clock_later := TimeFx.real_time()
	_check("MG18 feedback clock advances at the new rate", clock_later - clock_after > 0.025 and clock_later - clock_after < 0.09)
	Engine.physics_ticks_per_second = 30
	_check("MG19 lowering physics rate cannot jump feedback deadlines forward", TimeFx.real_time() - clock_later < 0.05)
	Engine.time_scale = 0.5

func _frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame

func _check(label: String, passed: bool) -> void:
	checks += 1
	failed = failed or not passed
	print("%s %s" % ["PASS" if passed else "FAIL", label])
