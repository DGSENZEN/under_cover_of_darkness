extends Node3D
## The exchange: every blow a call, every answer its own. A perfect deflect,
## a counter, a clash, a Mikiri; a blow committed after his glint; a running
## blow and a blow thrown backing away; what being parried costs you; how a
## blow slows you; his balance over his head (PlayerCombat, GuardFighter,
## StealthHUD).

const PLAYER := preload("res://Player.tscn")
const GUARD_SCRIPT := preload("res://scripts/AISystem/Guard.gd")
const GUARD := preload("res://Guard.tscn")
const Props := preload("res://scripts/Interaction/Props.gd")
const NavBakerScript := preload("res://scripts/AISystem/NavBaker.gd")
const TemperamentScript := preload("res://scripts/AISystem/Temperament.gd")
const GarrisonScript := preload("res://scripts/AISystem/Garrison.gd")
const SquadScript := preload("res://scripts/AISystem/Squad.gd")
const TimeFx := preload("res://scripts/Visual/TimeFx.gd")

const IDLE := 0
const WINDUP := 1
const STRIKE := 3
const RECOVER := 4
const STAGGER := 8

var player: CharacterBody3D
var combat: Node
var results: Array[String] = []
var _defences: Array = []
var _outcomes: Array = []


func _ready() -> void:
	# Every guard at his class's own temperament: these checks are exact.
	TemperamentScript.rolling = false
	GUARD_SCRIPT.bleeding_on = false
	Props.block(self, Vector3(60, -0.5, 30), Vector3(200, 1, 120))

	var baker := NavigationRegion3D.new()
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

	player.debug_light_level = 1.0
	player.global_position = Vector3(0, 1.05, 50)
	Props.give_weapons(player, 12)
	combat = player.combat
	combat.defended.connect(func(r): _defences.append(r))
	combat.landed.connect(func(_t, r, _d): _outcomes.append(r))

	await baker.baked
	await _frames(5)
	await _run()

	print("\n==== RESULTS ====")
	for r in results:
		print(r)
	get_tree().quit()


func _run() -> void:
	var weapon: Resource = combat.current_weapon()

	# B1 a perfect deflect (right on the blow) throws him further off his
	#    balance than a late parry, costs nothing, and its riposte is quicker
	var g1 := _swinger(&"swordsman", Vector3(0, 0, -1.3), &"overhead")
	var perfects := [0]
	combat.perfect_parry.connect(func(): perfects[0] += 1)
	_put_player(Vector3(0, 1.05, 0))
	await _frames(10)
	g1._attack_timer = 0.0
	await _parry_at(g1, 0.2)
	var late_posture: float = g1._fighter.posture
	var late_perfects: int = perfects[0]
	await _until(func(): return g1._stagger <= 0.0, 120)
	g1._fighter.posture = 0.0
	await _frames(20)
	g1._attack_timer = 0.0
	await _parry_at(g1, 0.07)
	var perfect_posture: float = g1._fighter.posture
	var stamina_after: float = combat.stamina
	# Straight into the riposte.
	Input.action_press("throw")
	await _frames(2)
	var riposte_windup: float = combat._windup
	Input.action_release("throw")
	var base_windup: float = weapon.windup
	_check("B1 a perfect deflect throws him further off his balance than a late parry, costs nothing, and its riposte comes quicker",
		late_perfects == 0 and perfects[0] == 1 and perfect_posture >= late_posture * 1.4 and stamina_after >= combat.stamina_max - 0.01 and riposte_windup < base_windup * combat.riposte_windup_scale - 0.005,
		"late %.1f perfect %.1f (perfects %d then %d) stamina %.0f riposte windup %.3f (a plain riposte's %.3f)" % [late_posture, perfect_posture, late_perfects, perfects[0], stamina_after, riposte_windup, base_windup * combat.riposte_windup_scale])
	g1.queue_free()
	await _frames(40)

	# B2 two perfect deflects and a swordsman's balance is gone: he is open
	var g2 := _swinger(&"swordsman", Vector3(0, 0, -1.3), &"overhead")
	var broke := [0]
	g2.posture_broken.connect(func(): broke[0] += 1)
	_put_player(Vector3(0, 1.05, 0))
	await _frames(10)
	for n in 2:
		g2._attack_timer = 0.0
		await _parry_at(g2, 0.07)
		await _until(func(): return g2._stagger <= 0.0 or g2.is_open(), 120)
	_check("B2 two perfect deflects and a swordsman's balance is gone: he is open", broke[0] == 1 and g2.is_open(),
		"broken %d open %s posture %.0f" % [broke[0], g2.is_open(), g2._fighter.posture])
	g2.queue_free()
	await _frames(40)

	# B3 a counter: a cut of yours begun as his cut comes turns his aside, and
	#    yours goes on into him as a riposte; you take nothing
	var g3 := _swinger(&"swordsman", Vector3(0, 0, -1.3), &"overhead")
	var counters := [0]
	combat.countered.connect(func(_f): counters[0] += 1)
	_put_player(Vector3(0, 1.05, 0))
	player.invulnerable = false
	player.health = player.max_health
	await _frames(10)
	_outcomes.clear()
	g3._attack_timer = 0.0
	await _until(func(): return g3._phase == &"windup" and g3._phase_timer < 0.12, 240)
	Input.action_press("throw")
	await _frames(2)
	Input.action_release("throw")
	await _frames(40)
	_check("B3 a counter: your cut begun as his comes turns it aside, and yours lands as a riposte; you take nothing",
		counters[0] == 1 and player.health == player.max_health and _near(g3.health, g3.max_health - weapon.damage * combat.riposte_damage, 0.1) and _outcomes.has(&"hit"),
		"counters %d your health %.0f his %.1f (a riposte's %.1f) outcomes %s" % [counters[0], player.health, g3.health, g3.max_health - weapon.damage * combat.riposte_damage, _outcomes])
	player.invulnerable = true
	g3.queue_free()
	await _frames(40)

	# B4 a counter must answer the call: a cut into his thrust is none (it
	#    lands, and your blow is lost); a thrust into it is
	var g4 := _swinger(&"swordsman", Vector3(0, 0, -1.3), &"thrust")
	_put_player(Vector3(0, 1.05, 0))
	player.invulnerable = false
	player.health = player.max_health
	var staggers: Array = []
	combat.staggered.connect(func(why): staggers.append(why))
	await _frames(10)
	var counted_before: int = counters[0]
	g4._attack_timer = 0.0
	await _until(func(): return g4._phase == &"windup" and g4._phase_timer < 0.12, 240)
	Input.action_press("throw")
	await _frames(2)
	Input.action_release("throw")
	await _frames(30)
	var wrong_hurt: bool = player.health < player.max_health
	var wrong_counted: bool = counters[0] > counted_before
	await _until(func(): return g4._stagger <= 0.0 and g4._phase == &"", 120)
	await _until(func(): return combat.phase == IDLE, 120)
	player.health = player.max_health
	await _frames(20)
	g4._attack_timer = 0.0
	await _until(func(): return g4._phase == &"windup" and g4._phase_timer < 0.12, 240)
	# Up: the point.
	combat.add_look_motion(Vector2(0.0, 0.3))
	Input.action_press("throw")
	await _frames(2)
	Input.action_release("throw")
	await _frames(30)
	_check("B4 a counter must answer the call: a cut into his thrust is no counter, a thrust is",
		wrong_hurt and not wrong_counted and staggers.has(&"flinch") and counters[0] == counted_before + 1 and player.health == player.max_health,
		"cut into it: hurt %s countered %s staggers %s; thrust into it: countered %d health %.0f" % [wrong_hurt, wrong_counted, staggers, counters[0] - counted_before, player.health])
	player.invulnerable = true
	g4.queue_free()
	await _frames(40)

	# B5 a clash: your blade already in the air when his arrives, not the
	#    answer to it: the blades meet, neither lands, both are thrown back
	var g5 := _swinger(&"swordsman", Vector3(0, 0, -1.3), &"thrust")
	var clashes := [0]
	combat.clashed.connect(func(_f): clashes[0] += 1)
	_put_player(Vector3(0, 1.05, 0))
	player.invulnerable = false
	player.health = player.max_health
	await _frames(10)
	g5._attack_timer = 0.0
	await _until(func(): return g5._phase == &"windup" and g5._phase_timer < 0.21, 240)
	Input.action_press("throw")
	await _frames(2)
	Input.action_release("throw")
	await _until(func(): return clashes[0] > 0 or g5._phase != &"windup", 30)
	var clash_phase: int = combat.phase
	var clash_outcome: StringName = combat._outcome
	await _frames(30)
	_check("B5 a clash: blades in the air together, neither lands, both thrown back",
		clashes[0] == 1 and player.health == player.max_health and g5.health == g5.max_health and clash_phase == RECOVER and clash_outcome == &"clashed" and g5._fighter.posture >= 11.0,
		"clashes %d your health %.0f his %.0f you %d (%s) his balance %.0f" % [clashes[0], player.health, g5.health, clash_phase, clash_outcome, g5._fighter.posture])
	player.invulnerable = true
	g5.queue_free()
	await _frames(40)

	# B6 Mikiri: step into his thrust as it comes and pin his blade: no harm to
	#    you, he is thrown hard off his balance, and your answer is ready
	var g6 := _swinger(&"swordsman", Vector3(0, 0, -1.6), &"thrust")
	_put_player(Vector3(0, 1.05, 0))
	player.invulnerable = false
	player.health = player.max_health
	await _frames(10)
	_defences.clear()
	g6._attack_timer = 0.0
	await _until(func(): return g6._phase == &"windup" and g6._phase_timer < 0.2, 240)
	Input.action_press("move_forward")
	await _tap("dodge")
	await _frames(12)
	Input.action_release("move_forward")
	var mikiri_riposte: bool = combat._riposte_until > combat._game_time
	_check("B6 Mikiri: step into his thrust as it comes and you are on his blade: no harm, he is thrown hard, your answer is ready",
		_defences.has(&"mikiri") and player.health == player.max_health and g6._fighter.posture >= 60.0 and g6._stagger > 0.5 and mikiri_riposte,
		"defences %s your health %.0f his balance %.0f reeling %.2f riposte ready %s" % [_defences, player.health, g6._fighter.posture, g6._stagger, mikiri_riposte])
	player.invulnerable = true
	g6.queue_free()
	await _frames(40)

	# B7 stepping into a cut is no Mikiri: it lands
	var g7 := _swinger(&"swordsman", Vector3(0, 0, -1.6), &"overhead")
	_put_player(Vector3(0, 1.05, 0))
	player.invulnerable = false
	player.health = player.max_health
	await _frames(10)
	_defences.clear()
	g7._attack_timer = 0.0
	await _until(func(): return g7._phase == &"windup" and g7._phase_timer < 0.2, 240)
	Input.action_press("move_forward")
	await _tap("dodge")
	await _frames(12)
	Input.action_release("move_forward")
	_check("B7 stepping into a cut is no Mikiri: it lands", not _defences.has(&"mikiri") and player.health < player.max_health,
		"defences %s your health %.0f" % [_defences, player.health])
	player.invulnerable = true
	g7.queue_free()
	await _frames(40)

	# B8 before his glint a cut beats him to it (his blow is lost); after it,
	#    his blade is committed: your cut lands and so does his
	var g8 := _swinger(&"swordsman", Vector3(0, 0, -1.3), &"overhead")
	_put_player(Vector3(0, 1.05, 0))
	player.invulnerable = false
	player.health = player.max_health
	await _frames(10)
	g8._attack_timer = 0.0
	await _until(func(): return g8._phase == &"windup", 240)
	Input.action_press("throw")
	await _frames(2)
	Input.action_release("throw")
	await _until(func(): return g8.health < g8.max_health, 30)
	var early_stopped: bool = g8._phase != &"windup"
	await _frames(40)
	var early_hurt: bool = player.health < player.max_health
	await _until(func(): return g8._stagger <= 0.0 and combat.phase == IDLE, 120)
	g8.health = g8.max_health
	player.health = player.max_health
	await _frames(20)
	g8._attack_timer = 0.0
	await _until(func(): return g8._phase == &"windup" and g8._phase_timer < 0.34, 240)
	Input.action_press("throw")
	await _frames(2)
	Input.action_release("throw")
	await _until(func(): return g8.health < g8.max_health, 30)
	var late_went_on: bool = g8._phase == &"windup"
	await _frames(40)
	_check("B8 before his glint your cut beats him to it; after it his blade is committed and you trade",
		early_stopped and not early_hurt and late_went_on and g8.health < g8.max_health and player.health < player.max_health,
		"early: his blow stopped %s you hurt %s; late: his blow went on %s he %.0f you %.0f" % [early_stopped, early_hurt, late_went_on, g8.health, player.health])
	player.invulnerable = true
	g8.queue_free()
	await _frames(40)

	# B9 a running blow: carried into him, harder, and as hard on his guard as
	#    a heavy one
	var g9 := _swinger(&"swordsman", Vector3(0, 0, -8.0), &"overhead")
	g9.chase_speed = 0.0
	_put_player(Vector3(0, 1.05, 4))
	await _frames(10)
	_outcomes.clear()
	Input.action_press("move_forward")
	Input.action_press("sprint")
	await _until(func(): return player.global_position.z < -5.3, 240)
	Input.action_press("throw")
	await _frames(2)
	var running: bool = combat.is_running_blow()
	var slowed_running: float = combat.speed_scale()
	Input.action_release("throw")
	await _until(func(): return not _outcomes.is_empty(), 40)
	_release_all()
	var running_damage: float = g9.max_health - g9.health
	await _frames(30)
	# Against his raised guard.
	g9.health = g9.max_health
	g9._fighter.posture = 0.0
	_put_player(Vector3(0, 1.05, 4))
	await _frames(20)
	_outcomes.clear()
	Input.action_press("move_forward")
	Input.action_press("sprint")
	await _until(func(): return player.global_position.z < -5.3, 240)
	g9._fighter.guarding = true
	g9._fighter._guard_hold = 5.0
	Input.action_press("throw")
	await _frames(2)
	Input.action_release("throw")
	await _until(func(): return not _outcomes.is_empty(), 40)
	_release_all()
	var guard_posture: float = g9._fighter.posture
	_check("B9 a running blow: carried in, a third again as hard, and as hard on his guard as a heavy one",
		running and is_equal_approx(slowed_running, 1.0) and _near(running_damage, weapon.damage * combat.running_damage, 0.1) and _outcomes.has(&"blocked") and guard_posture >= 8.0 * combat.running_poise - 0.5,
		"running %s speed scale %.2f damage %.1f (%.1f) then %s, his balance %.1f" % [running, slowed_running, running_damage, weapon.damage * combat.running_damage, _outcomes, guard_posture])
	g9.queue_free()
	await _frames(40)

	# B10 a blow thrown backing away has less of you in it
	var g10 := _swinger(&"swordsman", Vector3(0, 0, -1.2), &"overhead")
	g10.chase_speed = 0.0
	_put_player(Vector3(0, 1.05, 0))
	await _frames(10)
	_outcomes.clear()
	Input.action_press("move_back")
	await _frames(8)
	Input.action_press("throw")
	await _frames(1)
	Input.action_release("move_back")
	await _frames(1)
	Input.action_release("throw")
	await _until(func(): return not _outcomes.is_empty(), 40)
	_release_all()
	var backing: float = combat._backing
	var backing_damage: float = g10.max_health - g10.health
	_check("B10 a blow thrown backing away has less of you in it", _outcomes.has(&"hit") and backing > 0.5 and backing_damage < weapon.damage - 3.0 and backing_damage >= weapon.damage * (1.0 - combat.backing_penalty) - 0.1,
		"outcomes %s backing %.2f damage %.1f (a still one's %.1f)" % [_outcomes, backing, backing_damage, weapon.damage])
	g10.queue_free()
	await _frames(40)

	# B11 parried, your balance pays: your blade flung aside costs you stamina
	var g11 := _swinger(&"duelist", Vector3(0, 0, -1.6), &"left")
	g11._fighter.parry_chance = 1.0
	g11._attack_timer = 999.0
	_put_player(Vector3(0, 1.05, 0))
	await _frames(20)
	_outcomes.clear()
	_aim(g11.global_position + Vector3.UP * 1.3)
	var stamina_before: float = combat.stamina
	await _tap("throw")
	await _until(func(): return not _outcomes.is_empty(), 40)
	var paid: float = stamina_before - combat.stamina
	_check("B11 parried, your balance pays for it", _outcomes.has(&"parried") and paid >= combat.cost_quick + combat.cost_parried - 0.5,
		"outcomes %s stamina paid %.1f (a swing %.0f, being parried %.0f)" % [_outcomes, paid, combat.cost_quick, combat.cost_parried])
	g11.queue_free()
	await _frames(40)

	# B12 a blow has weight: it slows you while it is under way
	_put_player(Vector3(0, 1.05, 0))
	await _frames(10)
	Input.action_press("throw")
	await _frames(2)
	Input.action_release("throw")
	var slowest := [1.0]
	for i in 60:
		slowest[0] = minf(slowest[0], combat.speed_scale())
		await _frames(1)
	_check("B12 a blow has weight: it slows you while it is under way", slowest[0] <= combat.strike_speed_scale + 0.001 and combat.speed_scale() == 1.0,
		"slowest %.2f, after %.2f" % [slowest[0], combat.speed_scale()])
	await _frames(20)

	# B13 his balance shows over him once it is shaken; open, a red mark
	var g13 := _swinger(&"swordsman", Vector3(0, 0, -1.6), &"overhead")
	_put_player(Vector3(0, 1.05, 0))
	await _frames(10)
	var hud: Node = player.hud
	var none_before: bool = hud.posture_marks().is_empty()
	g13._fighter.add_posture(45.0)
	await _frames(3)
	var shaken_marks: Array = hud.posture_marks()
	g13._fighter.add_posture(80.0)
	await _frames(3)
	var open_marks: Array = hud.posture_marks()
	_check("B13 his balance shows over him once it is shaken; open, a red mark",
		none_before and shaken_marks.size() == 1 and float(shaken_marks[0][1]) > 0.4 and not bool(shaken_marks[0][2]) and open_marks.size() == 1 and bool(open_marks[0][2]),
		"before %s shaken %s open %s" % [none_before, shaken_marks, open_marks])
	g13.queue_free()
	await _frames(40)

	# B14 counter them and they learn you parry: they feint more
	var g14 := _swinger(&"swordsman", Vector3(0, 0, -1.3), &"overhead")
	_put_player(Vector3(0, 1.05, 0))
	await _frames(10)
	var squad14 = g14._fighter.squad
	var read_before: float = float(squad14.read.get(&"parry", 0.0))
	g14._attack_timer = 0.0
	await _until(func(): return g14._phase == &"windup" and g14._phase_timer < 0.12, 240)
	Input.action_press("throw")
	await _frames(2)
	Input.action_release("throw")
	await _frames(20)
	_check("B14 counter them and they read it as a parry", float(squad14.read.get(&"parry", 0.0)) >= read_before + 0.29,
		"parry read %.2f -> %.2f" % [read_before, float(squad14.read.get(&"parry", 0.0))])
	g14.queue_free()
	await _frames(20)


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

## A guard fighting you, facing you, who throws only `kind` when told to
## (_attack_timer = 0), one at a time, and does not defend.
func _swinger(archetype: StringName, at: Vector3, kind: StringName) -> CharacterBody3D:
	GarrisonScript.clear_all()
	SquadScript.clear_all()
	var g: CharacterBody3D = GUARD.instantiate()
	g.archetype = archetype
	g.debug_ai = false
	g.position = at
	g.rotation.y = PI
	add_child(g)
	g.block_chance = 0.0
	g._fighter.parry_chance = 0.0
	g._fighter.feint_chance = 0.0
	g._fighter.dodge_chance = 0.0
	g._fighter.counter_chance = 0.0
	g._fighter.kick_chance = 0.0
	g._fighter.backstep_chance = 0.0
	g._fighter.lunge_chance = 0.0
	g._fighter.leap_chance = 0.0
	g._fighter.timing_variance = 0.0
	g._fighter.delay_chance = 0.0
	g._fighter.read_skill = 0.0
	g._fighter.spacing = 0.0
	g._fighter.strafe_speed = 0.0
	g._fighter.attacks = {kind: 1.0}
	g._fighter.follow = {}
	g._fighter.combo_max = 1
	g.parry_stun = 0.4
	g.attack_cooldown = 999.0
	g._attack_timer = 999.0
	g._engage(player)
	return g


## Raises your guard when his blow is `before` seconds from landing, holds
## it through the blow, and lets it down.
func _parry_at(g: CharacterBody3D, before: float) -> void:
	await _until(func(): return g._phase == &"windup" and g._phase_timer < before, 240)
	Input.action_press("block")
	await _until(func(): return g._phase != &"windup", 60)
	await _frames(4)
	Input.action_release("block")
	await _frames(2)


func _put_player(at: Vector3) -> void:
	_release_all()
	player.movement_state = 0
	player.current_move = null
	player.velocity = Vector3.ZERO
	player.global_position = at
	player.rotation.y = 0.0
	player.get_node("Neck").rotation.x = 0.0
	player.combat._reset()
	player.combat.adrenaline = 0.0
	player.combat.stamina = player.combat.stamina_max
	player.combat._riposte_until = -100.0
	player.reset_physics_interpolation()


func _aim(target: Vector3) -> void:
	var eye: Vector3 = player.get_node("Neck").global_position
	var d := target - eye
	player.rotation.y = atan2(-d.x, -d.z)
	player.get_node("Neck").rotation.x = atan2(d.y, Vector2(d.x, d.z).length())


func _release_all() -> void:
	for a in ["move_forward", "move_back", "move_left", "move_right", "jump", "sprint", "crouch", "frob", "throw", "block", "kick", "dodge"]:
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


func _near(a: float, b: float, tol: float) -> bool:
	return absf(a - b) <= tol


func _check(test_name: String, ok: bool, detail: String) -> void:
	results.append("%s  %s   [%s]" % ["PASS" if ok else "FAIL", test_name, detail])
