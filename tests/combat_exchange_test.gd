extends Node3D
## Real player/guard exchanges: earned openings, feint follow-through and contact feedback.
const PLAYER := preload("res://Player.tscn")
const GUARD := preload("res://Guard.tscn")
const Props := preload("res://scripts/Interaction/Props.gd")
const TimeFx := preload("res://scripts/Visual/TimeFx.gd")
var player: CharacterBody3D
var combat: Node
var results: Array[String] = []
var failed := false
var _contacts: Array[StringName] = []

func _ready() -> void:
	Props.block(self, Vector3(0, -0.5, 0), Vector3(80, 1, 80))
	player = PLAYER.instantiate()
	add_child(player)
	player.debug_traversal = false
	player.invulnerable = true
	player.reload_on_death = false
	if player.has_node("LightGem"):
		player.get_node("LightGem").queue_free()
	Props.give_weapons(player)
	player.inventory.select_by_id(&"sword")
	combat = player.combat
	if combat.has_signal("contact"):
		combat.connect("contact", func(kind): _contacts.append(kind))
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	await _frames(5)
	await _feints()
	await _openings()
	await _feedback()
	await _edge_cases()
	await _live_exchange()
	await _moving_and_throwing()
	_release()
	print("\n==== RESULTS ====")
	for r in results:
		print(r)
	get_tree().quit(1 if failed else 0)

func _feints() -> void:
	await _place()
	await _feint_cut(&"left")
	combat.add_look_motion(Vector2(0, 0.3))
	Input.action_press("throw")
	await _frames(2)
	Input.action_release("throw")
	_check("EX1 changing to a point after a fresh feint starts quicker", combat.phase == combat.Phase.WINDUP and combat._direction == &"thrust" and combat._windup < 0.105, "phase %d direction %s windup %.3f" % [combat.phase, combat._direction, combat._windup])
	Input.action_press("block")
	await _frames(2)
	Input.action_release("block")
	await _frames(2)
	combat.add_look_motion(Vector2(0.3, 0))
	Input.action_press("throw")
	await _frames(2)
	Input.action_release("throw")
	_check("EX2 repeated feints cannot renew a fast follow-through indefinitely", combat._windup >= 0.139, "windup %.3f" % combat._windup)

	await _place()
	await _feint_cut(&"left")
	combat.add_look_motion(Vector2(0.3, 0))
	Input.action_press("throw")
	await _frames(2)
	Input.action_release("throw")
	_check("EX3 repeating the same cut after a feint gets no speed bonus", combat._windup >= 0.139, "windup %.3f" % combat._windup)

	await _place()
	await _feint_cut(&"left")
	await _frames(40)
	combat.add_look_motion(Vector2(0, 0.3))
	Input.action_press("throw")
	await _frames(2)
	Input.action_release("throw")
	_check("EX4 a delayed follow-through loses the feint opportunity", combat._windup > 0.11, "windup %.3f" % combat._windup)

	await _place()
	await _feint_cut(&"left")
	combat.reset_for_practice()
	combat.add_look_motion(Vector2(0, 0.3))
	Input.action_press("throw")
	await _frames(2)
	Input.action_release("throw")
	_check("EX5 a restart clears the feint opportunity", combat._windup > 0.11, "windup %.3f" % combat._windup)

func _openings() -> void:
	await _place()
	var g := _guard()
	_commit(g)
	player.global_position.x = 2.0
	_miss(g)
	var earned: bool = g.has_method("punishable_by") and g.call("punishable_by", player)
	_check("EX6 close footwork earns an opening and breaks the enemy string", earned and g._fighter._combo_left == 0, "opening %s combo %d" % [earned, g._fighter._combo_left])
	_check("EX7 a whiff opening gives no free player stamina or universal riposte", combat.stamina >= 99.9 and combat._riposte_until < combat._game_time, "stamina %.1f riposte %.3f" % [combat.stamina, combat._riposte_until])
	var other := Node3D.new()
	add_child(other)
	_check("EX8 the opening belongs only to the opponent who baited it", not (g.has_method("punishable_by") and g.call("punishable_by", other)), "target-bound")
	other.queue_free()
	g._fighter.guarding = true
	g._phase = &""
	var before: float = g.health
	combat._direction = &"left"
	combat._strike_target(g, g.eye_position(), Vector3.FORWARD)
	_check("EX9 punishing a whiff beats his guard and hits harder", before - g.health > 40.0 and _contacts.has(&"punish"), "damage %.2f contacts %s" % [before - g.health, _contacts])
	_check("EX10 a punish is consumed by one hit", not (g.has_method("punishable_by") and g.call("punishable_by", player)), "one opening")
	g.queue_free()
	await _frames(2)

	await _place()
	g = _guard()
	player.global_position = Vector3(0, 1.05, 7)
	_commit(g)
	player.global_position = Vector3(2, 1.05, 0)
	_miss(g)
	_check("EX11 a blow committed out of reach earns no opening", not (g.has_method("punishable_by") and g.call("punishable_by", player)), "distant commitment")
	g.queue_free()
	await _frames(2)

	await _place()
	g = _guard()
	_commit(g)
	player.global_position.y = 6.0
	_miss(g)
	_check("EX12 being unreachable above him earns no footwork opening", not (g.has_method("punishable_by") and g.call("punishable_by", player)), "height mismatch")
	g.queue_free()
	await _frames(2)

	await _place()
	g = _guard()
	_commit(g)
	player.global_position.x = 2.0
	_miss(g)
	g._game_time += 0.7
	_check("EX13 waiting too long loses the whiff opening", not (g.has_method("punishable_by") and g.call("punishable_by", player)), "expired")
	g.queue_free()
	await _frames(2)

	await _place()
	g = _guard()
	g._fighter._schedule_parry(g._game_time, 0.1, g._game_time)
	g._game_time += 0.3
	g._fighter._tick(0.3, g._game_time)
	_check("EX14 an enemy parry baited into thin air earns a punish opening", g.has_method("punishable_by") and g.call("punishable_by", player), "missed parry")
	g.queue_free()
	await _frames(2)

func _feedback() -> void:
	await _place()
	var g := _guard()
	g._fighter.guarding = true
	combat._direction = &"left"
	combat._strike_target(g, g.eye_position(), Vector3.FORWARD)
	_check("EX15 stopped steel has a distinct contact cue", _contacts == [&"steel"], "contacts %s" % [_contacts])
	g._fighter.guarding = false
	g._stagger = 0.0
	g._phase = &""
	_contacts.clear()
	combat._strike_target(g, g.eye_position(), Vector3.FORWARD)
	_check("EX16 clean flesh has a distinct contact cue", _contacts == [&"flesh"], "contacts %s" % [_contacts])
	await _frames(2)
	_check("EX17 the live HUD receives the flesh contact cue", player.hud._crosshair.get("contact_kind") == &"flesh" and float(player.hud._crosshair.get("contact_amount")) > 0.0, "HUD contact")
	await _frames(35)
	_check("EX18 contact fades instead of sticking through recovery", player.hud._crosshair.get("contact_amount") != null and float(player.hud._crosshair.get("contact_amount")) <= 0.001, "HUD fade")
	g._stagger = 0.0
	g._fighter.add_posture(200.0)
	_contacts.clear()
	combat._strike_target(g, g.eye_position(), Vector3.FORWARD)
	_check("EX19 a deathblow overrides the ordinary flesh cue", _contacts == [&"deathblow"], "contacts %s" % [_contacts])
	g.queue_free()
	await _frames(2)

func _edge_cases() -> void:
	await _place()
	var g := _guard()
	g._fighter._schedule_parry(g._game_time, 0.1, g._game_time)
	g._game_time += 0.3
	g._fighter._tick(0.3, g._game_time)
	combat.phase = combat.Phase.RECOVER
	combat._outcome = &"miss"
	g._fighter._punish_until = g._game_time + 1.0
	player.global_position.z = 1.0
	g._fighter._consider_attack(0.0167, player, Vector3.BACK * 3.0, 3.0, 0.0)
	_check("EX20 enemy whiff retaliation cannot erase his own recovery opening", g._phase == &"" and g.has_method("punishable_by") and g.call("punishable_by", player), "phase %s" % g._phase)
	g.queue_free()
	await _frames(2)

	await _place()
	g = _guard()
	_commit(g)
	var wall := Props.block(self, Vector3(0, 2, -1), Vector3(2, 4, 0.2))
	await _frames(3)
	_miss(g)
	_check("EX21 a wall intercepting his blade grants no footwork bonus", not g.punishable_by(player), "player %s guard %s wall hit %s phase %s outcome %s" % [player.global_position, g.global_position, g._fighter._wall_between(player), g._phase, g._fighter._outcome])
	wall.queue_free()
	g.queue_free()
	await _frames(2)

	await _place()
	g = _guard()
	g._fighter._schedule_parry(g._game_time, 0.1, g._game_time)
	var other := Node3D.new()
	add_child(other)
	g._target = other
	g._game_time += 0.3
	g._fighter._tick(0.3, g._game_time)
	_check("EX22 replacing the enemy target transfers no baited-parry opening", not g.punishable_by(player) and not g.punishable_by(other), "target replaced")
	g.queue_free()
	other.queue_free()
	await _frames(2)

	await _place()
	g = _guard()
	g._fighter._schedule_parry(g._game_time, 0.1, g._game_time)
	g._game_time += 0.15
	combat._direction = &"left"
	combat._strike_target(g, g.eye_position(), Vector3.FORWARD)
	g._game_time += 0.3
	g._fighter._tick(0.3, g._game_time)
	_check("EX23 a successful enemy parry creates no wasted-parry opening", _contacts == [&"turned"] and not g.punishable_by(player), "contacts %s" % [_contacts])
	g.queue_free()
	await _frames(2)

func _moving_and_throwing() -> void:
	await _place()
	var g := _guard()
	g._fighter._schedule_parry(g._game_time, 0.1, g._game_time)
	g._game_time += 0.3
	g._fighter._tick(0.3, g._game_time)
	var crate := Props.crate(self, Vector3(4, 1, 0))
	g._hands._hold(crate)
	g._fighter._unreachable = true
	g._fighter._consider_attack(0.0167, player, Vector3.BACK * 2.0, 2.0, 0.0)
	_check("EX26 an improvised throw cannot erase a baited recovery opening", g._phase == &"" and g.punishable_by(player), "phase %s" % g._phase)
	g.queue_free()
	await _frames(2)

	await _place()
	g = _guard()
	g.position.z = -4.0
	g._fighter._start(&"lunge")
	_step_attack(g, g._phase_length * 0.7)
	_step_attack(g, 0.001)
	# The lunge closes the ground after its glint, before the point arrives.
	g.position.z = -2.0
	_step_attack(g, 0.1)
	player.global_position.x = 2.0
	_miss(g)
	_check("EX27 a committed lunge closing into range can earn a footwork opening", g.punishable_by(player), "moving lunge opening %s" % g.punishable_by(player))
	g.queue_free()
	await _frames(2)

func _live_exchange() -> void:
	await _place()
	var g := _guard()
	g.block_chance = 0.0
	g._fighter.parry_chance = 0.0
	g._fighter.dodge_chance = 0.0
	g._fighter.counter_chance = 0.0
	g._fighter.read_skill = 0.0
	g._fighter.spacing = 0.0
	g._fighter.strafe_speed = 0.0
	g.attack_cooldown = 999.0
	g._attack_timer = 999.0
	g._engage(player)
	g.set_physics_process(true)
	g._fighter._start(&"overhead")
	g._fighter._combo_left = 2
	await _until(func(): return g._fighter.progress() >= 0.68, 90)
	player.global_position.x = 2.0
	await _until(func(): return g._phase != &"windup", 60)
	var opening: bool = g.punishable_by(player)
	_check("EX24 live committed enemy miss exposes him and cancels his combo", opening and g._fighter._combo_left == 0, "phase %s opening %s combo %d" % [g._phase, opening, g._fighter._combo_left])
	player.global_position = Vector3(0.8, 1.05, -0.5)
	player.velocity = Vector3.ZERO
	var to := g.global_position - player.global_position
	player.rotation.y = atan2(-to.x, -to.z)
	combat._look_motion = Vector2.ZERO
	var health_before: float = g.health
	Input.action_press("throw")
	await _frames(2)
	Input.action_release("throw")
	await _until(func(): return not _contacts.is_empty(), 60)
	_check("EX25 a real player blade sweep takes the earned opening", _contacts.has(&"punish") and health_before - g.health > 40.0, "damage %.2f contacts %s" % [health_before - g.health, _contacts])
	g.queue_free()
	await _frames(2)

func _until(condition: Callable, frames: int) -> void:
	for i in frames:
		if condition.call():
			return
		await get_tree().physics_frame

func _guard() -> CharacterBody3D:
	var g: CharacterBody3D = GUARD.instantiate()
	g.archetype = &"swordsman"
	g.debug_ai = false
	g.position = Vector3(0, 0, -2)
	g.rotation.y = PI
	add_child(g)
	g.set_physics_process(false)
	g._target = player
	g.state = 4
	g.health = 180.0
	g.max_health = 180.0
	g._fighter.feint_chance = 0.0
	g._fighter.timing_variance = 0.0
	g._fighter.stays_put = true
	return g

func _commit(g: CharacterBody3D) -> void:
	g._fighter._start(&"overhead")
	g._fighter._combo_left = 2
	_step_attack(g, g._phase_length * 0.7)
	_step_attack(g, 0.001)

func _miss(g: CharacterBody3D) -> void:
	_step_attack(g, g._phase_timer + 0.001)

func _step_attack(g: CharacterBody3D, delta: float) -> void:
	g._game_time += delta
	var feet: Vector3 = g._feet_of(player)
	var to := feet - g.global_position
	to.y = 0.0
	g._fighter._update_attack(delta, player, true, to, to.length(), feet.y - g.global_position.y)

func _feint_cut(direction: StringName) -> void:
	combat.add_look_motion(Vector2(0.3 if direction == &"left" else -0.3, 0))
	Input.action_press("throw")
	await _frames(2)
	Input.action_release("throw")
	Input.action_press("block")
	await _frames(2)
	Input.action_release("block")
	await _frames(2)

func _place() -> void:
	_release()
	combat.reset_for_practice()
	player.global_position = Vector3(0, 1.05, 0)
	player.rotation = Vector3.ZERO
	player.neck.rotation = Vector3.ZERO
	player.velocity = Vector3.ZERO
	player.shove(Vector3.ZERO, 0.0)
	await _frames(3)
	_contacts.clear()

func _release() -> void:
	for action in ["throw", "block", "dodge", "kick", "move_left", "move_right", "move_back", "move_forward"]:
		Input.action_release(action)

func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame

func _check(label: String, ok: bool, detail: String) -> void:
	failed = failed or not ok
	results.append("%s  %s [%s]" % ["PASS" if ok else "FAIL", label, detail])
