extends Node3D
## Skill and weight: the combo buffer, feints, parries and ripostes, stamina,
## the dodge, drop attacks; guards who guard, parry, feint, take turns and
## kick; the brute; powder, rope and fire; the recordings.

const PLAYER := preload("res://Player.tscn")
const GUARD_SCRIPT := preload("res://scripts/AISystem/Guard.gd")
const GUARD := preload("res://Guard.tscn")
const Props := preload("res://scripts/Interaction/Props.gd")
const NavBakerScript := preload("res://scripts/AISystem/NavBaker.gd")
const Sfx := preload("res://scripts/Audio/Sfx.gd")
const BarrelScript := preload("res://scripts/Combat/Barrel.gd")
const HangingWeightScript := preload("res://scripts/Combat/HangingWeight.gd")
const FireScript := preload("res://scripts/Combat/Fire.gd")
const DummyScript := preload("res://scripts/Combat/TrainingDummy.gd")
const GuardFighterScript := preload("res://scripts/AISystem/GuardFighter.gd")
const TemperamentScript := preload("res://scripts/AISystem/Temperament.gd")
const GarrisonScript := preload("res://scripts/AISystem/Garrison.gd")

var player: CharacterBody3D
var combat: Node
var results: Array[String] = []


func _ready() -> void:
	# Every guard at his class's own temperament: these checks are exact.
	TemperamentScript.rolling = false
	# Exact damage is checked here: cuts do not go on bleeding.
	GUARD_SCRIPT.bleeding_on = false
	Props.block(self, Vector3(60, -0.5, 30), Vector3(200, 1, 120))
	# D22 the drop: a platform to fall from.
	Props.block(self, Vector3(130, 2.0, 34), Vector3(4, 4, 4))

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
	Props.give_blackjack(player)
	combat = player.combat

	await baker.baked
	await _frames(5)
	await _run()

	print("\n==== RESULTS ====")
	for r in results:
		print(r)
	get_tree().quit()


func _run() -> void:
	# D1 throwing what you hold is not a sword stroke
	_wield(&"sword")
	_put_player(Vector3(30, 1.05, 30))
	var crate := Props.crate(self, Vector3(30, 0.3, 28.9), 0.4, 2.0)
	await _frames(20)
	_aim(crate.global_position)
	await _frames(2)
	await _tap("frob")
	await _frames(10)
	var carried: bool = player.frob.is_carrying()
	var swings: Array = []
	combat.swung.connect(func(p, d): swings.append(d))
	await _tap("throw")
	await _frames(40)
	var after_throw := swings.size()
	var phase_after: int = combat.phase
	await _tap("throw")
	await _frames(30)
	_check("D1 throwing what you hold does not also swing the sword", carried and not player.frob.is_carrying() and after_throw == 0 and phase_after == combat.Phase.IDLE and swings.size() == 1,
		"carried %s swings after throw %d, phase %d, next click swings %d" % [carried, after_throw, phase_after, swings.size() - after_throw])
	crate.queue_free()

	# D2 a click during a swing: the next follows, sooner than it could start fresh
	var g2 := _fighter(&"", Vector3(0, 0, -1.5))
	_put_player(Vector3(0, 1.05, 0))
	await _frames(20)
	swings.clear()
	var swing_frames: Array = []
	var frame := [0]
	combat.swung.connect(func(p, d): swing_frames.append(frame[0]))
	for i in 60:
		frame[0] = i

		if i == 0 or i == 12:
			Input.action_press("throw")
		elif i == 2 or i == 14:
			Input.action_release("throw")

		await _frames(1)
	var gap: int = swing_frames[1] - swing_frames[0] if swing_frames.size() >= 2 else -1
	# A fresh blow after a full recovery: windup + strike + recovery.
	var weapon: Resource = combat.current_weapon()
	var fresh := int((weapon.windup + weapon.strike_time + weapon.recovery + weapon.windup) * 60.0)
	_check("D2 a click mid-swing chains the next blow, sooner than a fresh one", swing_frames.size() == 2 and gap > 0 and gap < fresh and _near(g2.health, 32.0, 0.1),
		"swings at %s (gap %d frames, fresh %d), health %.0f" % [swing_frames, gap, fresh, g2.health])
	g2.queue_free()

	# D3 block during your own windup: a feint (no blow, a little stamina, guard up)
	var g3 := _fighter(&"", Vector3(0, 0, -1.5))
	_put_player(Vector3(0, 1.05, 0))
	combat.stamina = combat.stamina_max
	await _frames(20)
	swings.clear()
	var feints := [0]
	combat.feinted.connect(func(): feints[0] += 1)
	Input.action_press("throw")
	await _frames(3)
	Input.action_press("block")
	await _frames(3)
	var guard_up: bool = combat.blocking
	Input.action_release("throw")
	await _frames(20)
	Input.action_release("block")
	_check("D3 block during your windup is a feint: no blow, guard up", feints[0] == 1 and swings.is_empty() and guard_up and g3.health == g3.max_health and _near(combat.stamina, combat.stamina_max - combat.cost_feint, 1.0),
		"feints %d swings %d guard up %s health %.0f stamina %.0f" % [feints[0], swings.size(), guard_up, g3.health, combat.stamina])
	g3.queue_free()
	await _frames(30)

	# D4 parry his blow, and your answer is a riposte: quick and hard
	var g4 := _fighter(&"", Vector3(0, 0, -1.3))
	g4.attack_cooldown = 5.0
	_put_player(Vector3(0, 1.05, 0))
	await _frames(10)
	g4._attack_timer = 0.0
	var defences: Array = []
	combat.defended.connect(func(r): defences.append(r))
	var ripostes := [0]
	combat.riposte_started.connect(func(): ripostes[0] += 1)
	await _until(func(): return g4._phase == &"windup" and g4._phase_timer < 0.12, 240)
	Input.action_press("block")
	await _until(func(): return g4._phase != &"windup", 60)
	await _frames(4)
	Input.action_release("block")
	await _frames(3)
	var riposte_windup := -1.0
	Input.action_press("throw")
	await _frames(2)
	riposte_windup = combat._windup
	Input.action_release("throw")
	await _frames(40)
	_check("D4 a parry opens a riposte: a quicker windup, half again the damage", defences.has(&"parry") and ripostes[0] == 1 and riposte_windup < weapon.windup and _near(g4.health, 100.0 - 34.0 * 1.5, 0.1),
		"defended %s ripostes %d windup %.3f (normal %.3f) health %.0f" % [defences, ripostes[0], riposte_windup, weapon.windup, g4.health])
	g4.queue_free()
	await _frames(20)

	# D5 a parry is a commitment: tapping block again at once opens no parry
	_put_player(Vector3(0, 1.05, 0))
	await _frames(40)
	await _tap("block")
	# Past the first window, but too soon for another.
	await _frames(20)
	Input.action_press("block")
	await _frames(2)
	var spammed: bool = combat.is_parrying()
	Input.action_release("block")
	await _frames(45)
	Input.action_press("block")
	await _frames(2)
	var fresh_parry: bool = combat.is_parrying()
	Input.action_release("block")
	_check("D5 a parry cannot be spammed: a quick second press opens none", not spammed and fresh_parry,
		"second press parrying %s, later press parrying %s" % [spammed, fresh_parry])
	await _frames(20)

	# D6 a block costs stamina; with too little, the blow breaks through
	player.invulnerable = false
	player.health = player.max_health
	var g6 := _fighter(&"", Vector3(0, 0, -1.3))
	g6.attack_cooldown = 5.0
	_put_player(Vector3(0, 1.05, 0))
	combat.stamina = combat.stamina_max
	Input.action_press("block")
	await _frames(40)
	defences.clear()
	g6._attack_timer = 0.0
	await _until(func(): return defences.size() > 0, 240)
	await _frames(2)
	var after_block: float = combat.stamina
	var health_block: float = player.health
	defences.clear()
	var staggers: Array = []
	combat.staggered.connect(func(why): staggers.append(why))
	await _until(func(): return g6._phase == &"", 120)
	combat.stamina = 5.0
	g6._attack_timer = 0.0
	await _until(func(): return defences.size() > 0, 240)
	await _frames(2)
	var broken_phase: int = combat.phase
	Input.action_release("block")
	var cost: float = g6._fighter.guard_damage
	_check("D6 a block costs stamina; with too little the guard breaks and most gets through", _near(after_block, combat.stamina_max - cost, 1.5) and _near(health_block, 100.0 - 34.0 * 0.2, 0.2) and defences.has(&"broken") and staggers.has(&"broken") and broken_phase == combat.Phase.STAGGER and _near(player.health, health_block - 34.0 * combat.guard_break_damage, 0.3),
		"stamina after block %.1f (cost %.0f) health %.1f -> %.1f, defended %s, phase %d" % [after_block, cost, health_block, player.health, defences, broken_phase])
	g6.queue_free()
	player.invulnerable = true
	player.health = player.max_health
	await _frames(40)

	# D7 the dodge: a quick step back, for stamina
	_put_player(Vector3(50, 1.05, 30))
	combat.stamina = combat.stamina_max
	await _frames(20)
	var dodges: Array = []
	combat.dodged.connect(func(d): dodges.append(d))
	var before_dodge: Vector3 = player.global_position
	await _tap("dodge")
	await _frames(24)
	var moved: float = player.global_position.z - before_dodge.z
	_check("D7 Q dodges: a quick step back, for stamina", dodges.size() == 1 and moved > 1.0 and _near(combat.stamina, combat.stamina_max - combat.cost_dodge, 2.0),
		"dodges %d moved back %.2f m stamina %.0f" % [dodges.size(), moved, combat.stamina])
	await _frames(20)

	# D8 cut while charging: the blow is lost
	player.invulnerable = false
	var g8 := _fighter(&"", Vector3(0, 0, -1.3))
	g8.attack_cooldown = 5.0
	_put_player(Vector3(0, 1.05, 0))
	await _frames(10)
	g8._attack_timer = 0.0
	await _until(func(): return g8._phase == &"windup", 120)
	swings.clear()
	staggers.clear()
	Input.action_press("throw")
	await _until(func(): return g8._phase == &"recover", 120)
	await _frames(2)
	var flinched: bool = staggers.has(&"flinch")
	await _frames(20)
	Input.action_release("throw")
	await _frames(30)
	_check("D8 cut while charging: that blow is lost", flinched and swings.is_empty() and player.health < player.max_health,
		"flinched %s swings %d health %.0f" % [flinched, swings.size(), player.health])
	g8.queue_free()
	player.invulnerable = true
	player.health = player.max_health
	await _frames(20)

	# D9 a guard who sees it coming raises his guard; the blow stops dead
	var g9 := _fighter(&"", Vector3(0, 0, -1.5))
	g9.block_chance = 1.0
	_put_player(Vector3(0, 1.05, 0))
	await _frames(20)
	var outcomes: Array = []
	combat.landed.connect(func(t, r, d): outcomes.append(r))
	var raised := [false]
	for i in 40:
		if i == 0:
			Input.action_press("throw")
		elif i == 2:
			Input.action_release("throw")

		if g9._fighter.guarding and outcomes.is_empty():
			raised[0] = true

		await _frames(1)

		if not outcomes.is_empty() and i < 30:
			break
	# Stopped dead, and held a moment (short: the fight goes on at once).
	var stopped: bool = combat.phase == combat.Phase.RECOVER and is_equal_approx(combat._recovery, combat.blocked_recovery) and combat._recovery <= 0.35
	_check("D9 he raises his guard in time; a blocked blow stops dead and holds you a moment", raised[0] and outcomes.has(&"blocked") and stopped and g9.health == g9.max_health,
		"guard raised %s outcomes %s recovering %s (%.2f s)" % [raised[0], outcomes, stopped, combat._recovery])
	await _frames(40)

	# D10 a power blow breaks a raised guard and lands in full
	var broke := [0]
	g9.guard_broken.connect(func(): broke[0] += 1)
	g9._stagger = 0.0
	Input.action_press("throw")
	await _frames(50)
	Input.action_release("throw")
	await _frames(40)
	_check("D10 a power blow breaks his guard and lands in full", broke[0] == 1 and _near(g9.health, 30.0, 0.1),
		"guard broken %d health %.0f" % [broke[0], g9.health])
	g9.queue_free()
	await _frames(20)

	# D11 enough quick blows on a raised guard break it too
	var g11 := _fighter(&"", Vector3(0, 0, -1.5))
	g11.block_chance = 1.0
	var broke11 := [0]
	g11.guard_broken.connect(func(): broke11[0] += 1)
	_put_player(Vector3(0, 1.05, 0))
	await _frames(20)
	for i in 6:
		if broke11[0] > 0:
			break

		await _tap("throw")
		await _frames(56)
	_check("D11 enough quick blows wear his guard down until it breaks", broke11[0] == 1, "guard broken %d, poise %.1f" % [broke11[0], g11._fighter._poise])
	g11.queue_free()
	await _frames(20)

	# D12 the kick knocks a raised guard aside
	var g12 := _fighter(&"", Vector3(0, 0, -1.2))
	var broke12 := [0]
	g12.guard_broken.connect(func(): broke12[0] += 1)
	_put_player(Vector3(0, 1.05, 0))
	await _frames(20)
	g12._fighter.guarding = true
	g12._fighter._guard_hold = 2.0
	await _tap("kick")
	await _frames(40)
	_check("D12 a kick knocks his guard aside", broke12[0] == 1 and not g12._fighter.guarding, "guard broken %d" % broke12[0])
	g12.queue_free()
	await _frames(20)

	# D13 a duelist parries a careless blow, and his answer is fast
	var g13 := _fighter(&"duelist", Vector3(0, 0, -1.6))
	g13._fighter.parry_chance = 1.0
	g13._fighter.dodge_chance = 0.0
	g13._fighter.feint_chance = 0.0
	g13._fighter.counter_chance = 0.0
	_put_player(Vector3(0, 1.05, 0))
	await _frames(20)
	outcomes.clear()
	_aim(g13.global_position + Vector3.UP * 1.3)
	await _tap("throw")
	await _until(func(): return not outcomes.is_empty(), 40)
	var parried_recovery: float = combat._recovery
	var answer := [-1.0]
	for i in 30:
		if g13._phase == &"windup" and answer[0] < 0.0:
			answer[0] = g13._phase_length

		await _frames(1)
	# Your blade is flung aside a little longer than his answer takes: it
	# lands unless you raise your guard (which you can at once).
	_check("D13 a duelist parries a careless blow and answers fast", outcomes.has(&"parried") and is_equal_approx(parried_recovery, combat.parried_recovery) and answer[0] > 0.0 and answer[0] <= 0.3 and answer[0] < parried_recovery and g13.health == g13.max_health,
		"outcomes %s your recovery %.2f his answer's windup %.2f" % [outcomes, parried_recovery, answer[0]])
	g13.queue_free()
	await _frames(60)

	# D14 a feint wastes his parry: strike after it and the blow lands
	var g14 := _fighter(&"duelist", Vector3(0, 0, -1.6))
	g14._fighter.parry_chance = 1.0
	g14._fighter.dodge_chance = 0.0
	g14._fighter.feint_chance = 0.0
	g14._fighter.counter_chance = 0.0
	_put_player(Vector3(0, 1.05, 0))
	await _frames(20)
	outcomes.clear()
	var flicked := [false]
	_aim(g14.global_position + Vector3.UP * 1.3)
	Input.action_press("throw")
	await _frames(3)
	Input.action_press("block")
	await _frames(2)
	Input.action_release("throw")
	Input.action_release("block")
	for i in 12:
		if g14._fighter.parry_pose() > 0.5:
			flicked[0] = true

		await _frames(1)
	_aim(g14.global_position + Vector3.UP * 1.3)
	await _tap("throw")
	await _frames(30)
	_check("D14 a feint draws his parry out; the blow after it lands", flicked[0] and outcomes.has(&"hit") and g14.health < g14.max_health,
		"he parried thin air %s, outcomes %s health %.0f" % [flicked[0], outcomes, g14.health])
	g14.queue_free()
	await _frames(40)

	# D15 a crowd takes turns
	var crowd: Array = []
	for at in [Vector3(-1.4, 0, -1.4), Vector3(1.4, 0, -1.4), Vector3(0, 0, 1.6)]:
		var g := _fighter(&"swordsman", at)
		# Facing you, wherever he stands (behind you too).
		g.rotation.y = atan2(at.x, at.z)
		g._attack_timer = 0.0
		g.attack_cooldown = 0.4
		g.block_chance = 0.0
		g._fighter.parry_chance = 0.0
		g._fighter.feint_chance = 0.0
		g._fighter.kick_chance = 0.0
		crowd.append(g)
	_put_player(Vector3(0, 1.05, 0))
	var most := 0
	var who := {}
	var worn: Node = null
	for i in 420:
		var swinging := 0
		for g in crowd:
			if g._phase == &"windup" or g._phase == &"strike":
				swinging += 1
				who[g] = true
		most = maxi(most, swinging)
		# The man in front, worn down, gives his place to a fresher one (the
		# squad holds its front man otherwise).
		if worn == null and who.size() == 1:
			worn = who.keys()[0]
			worn.health = worn.max_health * 0.25
		await _frames(1)
	_check("D15 a crowd takes turns: one swings at a time, and the turn passes", most == 1 and who.size() >= 2,
		"most at once %d, different attackers %d" % [most, who.size()])
	for g in crowd:
		g.queue_free()
	await _frames(20)

	# D16 a guard behind you winding up shows on the HUD
	var g16 := _fighter(&"", Vector3(0, 0, 1.4))
	g16.rotation.y = 0.0
	_put_player(Vector3(0, 1.05, 0))
	await _frames(60)
	g16._attack_timer = 0.0
	g16.attack_cooldown = 5.0
	await _until(func(): return g16._phase == &"windup", 120)
	await _frames(2)
	var fresh_marks: Array = player.hud._warn_marks.marks.filter(func(m): return float(m[1]) > 0.8)
	var behind: bool = not fresh_marks.is_empty() and absf(float(fresh_marks[0][0])) > 2.5
	_check("D16 a blow wound up behind you is shown at the edge of the view", behind, "fresh marks %s" % [fresh_marks])
	g16.queue_free()
	await _frames(40)

	# D17 his kick goes through a raised guard, shoves you back and winds you
	var g17 := _fighter(&"swordsman", Vector3(0, 0, -1.3))
	g17.block_chance = 0.0
	g17._fighter.parry_chance = 0.0
	g17._fighter.feint_chance = 0.0
	g17._fighter.kick_chance = 1.0
	g17._fighter.attacks = {&"overhead": 1.0}
	g17.attack_cooldown = 0.5
	_put_player(Vector3(0, 1.05, 0))
	combat.stamina = combat.stamina_max
	staggers.clear()
	Input.action_press("block")
	await _frames(10)
	g17._attack_timer = 0.0
	var start_z: float = player.global_position.z
	await _until(func(): return staggers.has(&"kicked"), 360)
	await _frames(20)
	Input.action_release("block")
	_check("D17 hide behind your guard and he kicks it aside: shoved back, winded", staggers.has(&"kicked") and player.global_position.z - start_z > 0.8,
		"staggers %s pushed %.2f m stamina %.0f" % [staggers, player.global_position.z - start_z, combat.stamina])
	g17.queue_free()
	await _frames(30)

	# D18 his feint: up it goes, back it comes, and the real one follows
	var g18 := _fighter(&"swordsman", Vector3(0, 0, -1.4))
	g18._fighter.feint_chance = 1.0
	# Blows that can be feinted (a sweep or a bash cannot).
	g18._fighter.attacks = {&"overhead": 1.0, &"left": 1.0, &"right": 1.0}
	g18._fighter.kick_chance = 0.0
	g18.block_chance = 0.0
	g18._fighter.parry_chance = 0.0
	g18.attack_cooldown = 5.0
	var feinted := [0]
	g18.feinted.connect(func(): feinted[0] += 1)
	_put_player(Vector3(0, 1.05, 0))
	await _frames(10)
	g18._attack_timer = 0.0
	await _until(func(): return feinted[0] > 0, 120)
	g18._fighter.feint_chance = 0.0
	var real := [false]
	for i in 60:
		if g18._phase == &"strike":
			real[0] = true
		await _frames(1)
	_check("D18 a swordsman feints: the blow is abandoned, and a real one follows", feinted[0] == 1 and real[0], "feints %d then struck %s" % [feinted[0], real[0]])
	g18.queue_free()
	await _frames(30)

	# D19 the brute: his great blow goes through any guard; quick cuts do not stop him
	player.invulnerable = false
	player.health = player.max_health
	var g19 := _fighter(&"brute", Vector3(0, 0, -1.9))
	g19._fighter.attacks = {&"heavy": 1.0}
	g19.block_chance = 0.0
	g19.attack_cooldown = 5.0
	_put_player(Vector3(0, 1.05, 0))
	combat.stamina = combat.stamina_max
	var knocked: Array = []
	combat.staggered.connect(func(why): knocked.append(why))
	Input.action_press("block")
	await _frames(40)
	g19._attack_timer = 0.0
	await _until(func(): return knocked.size() > 0, 240)
	var through: bool = knocked.has(&"crushed") and player.health < player.max_health
	Input.action_release("block")
	await _frames(40)
	var big: bool = (g19.get_node("CollisionShape3D").shape as CapsuleShape3D).radius > 0.35
	await _until(func(): return g19._phase == &"", 180)
	g19._stagger = 0.0
	g19._attack_timer = 0.0
	player.invulnerable = true
	await _until(func(): return g19._phase == &"windup" and g19._fighter.progress() > 0.35, 240)
	outcomes.clear()
	_aim(g19.global_position + Vector3.UP * 1.4)
	await _tap("throw")
	await _until(func(): return not outcomes.is_empty(), 30)
	var swinging_on: bool = g19._phase == &"windup" or g19._phase == &"strike"
	_check("D19 the brute: his great blow goes through a raised guard; quick cuts do not stop him", big and through and outcomes.has(&"hit") and swinging_on,
		"big %s knocked %s your cut %s he swings on %s" % [big, knocked, outcomes, swinging_on])
	g19.queue_free()
	player.health = player.max_health
	await _frames(60)

	# D20 a drop attack: onto a guard from above, LMB as you fall
	_wield(&"sword")
	var g20 := _new_guard(&"", Vector3(130, 0, 31.2), PI)
	_put_player(Vector3(130, 5.05, 32.6))
	await _frames(10)
	player.global_position = Vector3(130, 4.6, 31.3)
	var drops := [0]
	combat.drop_attacked.connect(func(t): drops[0] += 1)
	for i in 60:
		if i == 6:
			Input.action_press("throw")
		elif i == 8:
			Input.action_release("throw")
		await _frames(1)
	_check("D20 falling on a guard with LMB is a drop attack", drops[0] == 1 and not is_instance_valid(g20),
		"drop attacks %d guard alive %s" % [drops[0], is_instance_valid(g20)])
	await _frames(30)

	# D21 a thrown crate knocks a guard about
	var g21 := _fighter(&"", Vector3(30, 0, 26.5))
	var hits21: Array = []
	g21.struck_by.connect(func(r, k, d): hits21.append(k))
	_put_player(Vector3(30, 1.05, 30))
	var box := Props.crate(self, Vector3(30, 0.3, 28.9), 0.4, 4.0)
	await _frames(20)
	_aim(box.global_position)
	await _frames(2)
	await _tap("frob")
	await _frames(10)
	_aim(g21.global_position + Vector3.UP * 1.2)
	await _frames(4)
	await _tap("throw")
	await _frames(40)
	_check("D21 a thrown crate knocks a guard about", hits21.has(&"thrown") and g21.health < g21.max_health, "hits %s health %.0f" % [hits21, g21.health])
	g21.queue_free()
	if is_instance_valid(box):
		box.queue_free()
	await _frames(20)

	# D22 powder: a barrel goes up, sets its neighbour off, and throws a guard
	var barrel_a: RigidBody3D = BarrelScript.new()
	var barrel_b: RigidBody3D = BarrelScript.new()
	add_child(barrel_a)
	add_child(barrel_b)
	barrel_a.global_position = Vector3(70, 0.4, 30)
	barrel_b.global_position = Vector3(71.2, 0.4, 30)
	var g22 := _new_guard(&"", Vector3(70.6, 0, 31.6), 0.0)
	await _frames(20)
	barrel_a.strike(&"arrow", barrel_a.global_position)
	await _frames(90)
	_check("D22 a powder barrel goes up, sets off the next, and kills a guard beside it", not is_instance_valid(barrel_a) and not is_instance_valid(barrel_b) and not is_instance_valid(g22),
		"barrels left %d guard alive %s" % [int(is_instance_valid(barrel_a)) + int(is_instance_valid(barrel_b)), is_instance_valid(g22)])
	await _frames(20)

	# D23 an arrow through the rope drops the weight on the guard under it
	var weight: Node3D = HangingWeightScript.new()
	weight.drop = 3.0
	add_child(weight)
	weight.global_position = Vector3(90, 6.1, 30)
	var g23 := _new_guard(&"", Vector3(90, 0, 30), 0.0)
	_wield(&"bow")
	_put_player(Vector3(90, 1.05, 38))
	await _frames(30)
	_aim(Vector3(90, 4.6, 30))
	await _frames(2)
	Input.action_press("throw")
	await _frames(60)
	Input.action_release("throw")
	await _frames(90)
	_check("D23 an arrow through the rope drops the weight on the guard below", weight.cut and not is_instance_valid(g23), "cut %s guard alive %s" % [weight.cut, is_instance_valid(g23)])
	await _frames(20)

	# D24 kicked into a brazier, he burns
	_wield(&"sword")
	FireScript.brazier(self, Vector3(110, 0, 30))
	var g24 := _new_guard(&"", Vector3(110, 0, 31.4), 0.0)
	var burn_health: float = g24.max_health
	_put_player(Vector3(110, 1.05, 32.6))
	await _frames(20)
	await _tap("kick")
	await _until(func(): return not is_instance_valid(g24) or g24.is_burning(), 90)
	var lit: bool = is_instance_valid(g24) and g24.is_burning()
	await _frames(90)
	var burnt: bool = not is_instance_valid(g24) or g24.health < burn_health - 10.0
	_check("D24 kicked into the fire, he catches and burns", lit and burnt, "burning %s hurt %s" % [lit, burnt])
	if is_instance_valid(g24):
		g24.queue_free()
	await _frames(20)

	# D25 straw men: they take it; a shielded one catches quick cuts until broken
	var straw: StaticBody3D = DummyScript.new()
	add_child(straw)
	straw.global_position = Vector3(150, 0, 28.5)
	straw.rotation.y = PI
	var shield: StaticBody3D = DummyScript.new()
	shield.guards = true
	add_child(shield)
	shield.global_position = Vector3(160, 0, 28.5)
	shield.rotation.y = PI
	var straw_hits: Array = []
	straw.struck.connect(func(r, k, d): straw_hits.append(r))
	var shield_hits: Array = []
	shield.struck.connect(func(r, k, d): shield_hits.append(r))
	_put_player(Vector3(150, 1.05, 30))
	await _frames(20)
	await _tap("throw")
	await _frames(40)
	_put_player(Vector3(160, 1.05, 30))
	await _frames(20)
	await _tap("throw")
	await _frames(40)
	await _until(func(): return combat.phase == combat.Phase.IDLE, 90)
	Input.action_press("throw")
	var weapon25: Resource = combat.current_weapon()
	await _frames(int(ceil((weapon25.windup + weapon25.charge_time + 0.12) * 60.0)))
	Input.action_release("throw")
	await _frames(40)
	_check("D25 straw men: struck; a shield catches quick cuts, a power blow gets through", straw_hits == [&"hit"] and shield_hits == [&"blocked", &"hit"],
		"straw %s shield %s" % [straw_hits, shield_hits])

	# D26 the recordings are the ones heard, a sound set per name
	var expected := {&"whoosh": 3, &"flesh": 3, &"clang": 3, &"parry": 3, &"twang": 2, &"bow_draw": 2,
		&"arrow_thunk": 3, &"arrow_flesh": 3, &"blade_draw": 2, &"sheath": 2, &"bow_out": 1, &"bow_away": 1}
	var wrong: Array = []
	for sound in expected:
		var files: Array = Sfx._load_files(sound)
		var first: AudioStreamWAV = Sfx.stream(sound) as AudioStreamWAV
		if files.size() != expected[sound] or first == null or first.mix_rate != 44100 or first.stereo:
			wrong.append(sound)
	_check("D26 the blades and the bow play the recordings (mono, 44.1 kHz, every variation)", wrong.is_empty(), "wrong %s" % [wrong])

	# D26b every sound the game names is a recording: nothing is made up in code
	var unrecorded: Array = []
	var names: Array = Sfx.GAIN.keys()
	for surface in ["stone", "wood", "dirt", "water", "carpet", "metal", "grass", ""]:
		for running in [false, true]:
			for mail in [false, true]:
				for what in ["step", "jump", "land"]:
					var generated: StringName = Sfx.step(surface, running, what, mail)
					if not names.has(generated):
						names.append(generated)
	for sound in names:
		var takes: Array = Sfx._load_files(sound)
		var ok_takes := not takes.is_empty() and Sfx.GAIN.has(sound)
		for take in takes:
			var wav := take as AudioStreamWAV
			# (The score's stings are in stereo.)
			ok_takes = ok_takes and wav != null and (not wav.stereo or sound in Sfx.MUSICAL) and wav.mix_rate == 44100
		if not ok_takes:
			unrecorded.append(sound)
	_check("D26b every sound the game names is a levelled recording (mono, 44.1 kHz)", unrecorded.is_empty() and names.size() >= 75,
		"%d sounds, not recorded %s" % [names.size(), unrecorded])

	# D27 each weapon sounds like itself: a power blow's rush and thump, the
	# bow off the back and away again, an arrow into a man
	Sfx.recording = true
	Sfx.recorded.clear()
	_wield(&"sword")
	var g27 := _fighter(&"", Vector3(0, 0, -1.5))
	_put_player(Vector3(0, 1.05, 0))
	await _frames(20)
	Input.action_press("throw")
	await _frames(50)
	Input.action_release("throw")
	await _frames(30)
	var power_names := _names()
	g27.queue_free()
	Sfx.recorded.clear()
	player.hand._time = 1.0
	_wield(&"bow")
	await _frames(40)
	_wield(&"sword")
	await _frames(40)
	var bow_names := _names()
	Sfx.recorded.clear()
	var g27b := _new_guard(&"", Vector3(0, 0, -8.0), PI)
	_wield(&"bow")
	_put_player(Vector3(0, 1.05, 0))
	await _frames(30)
	_aim(g27b.global_position + Vector3.UP * 1.2)
	Input.action_press("throw")
	await _frames(60)
	Input.action_release("throw")
	await _frames(40)
	var arrow_names := _names()
	Sfx.recording = false
	if is_instance_valid(g27b):
		g27b.queue_free()
	_check("D27 a power blow rushes and thumps; the bow comes off the back and goes back; an arrow thuds into a man",
		power_names.has(&"whoosh") and power_names.has(&"whoosh_heavy") and power_names.has(&"flesh") and power_names.has(&"flesh_heavy")
		and bow_names.has(&"bow_out") and bow_names.has(&"bow_away") and arrow_names.has(&"twang") and arrow_names.has(&"arrow_flesh"),
		"power %s bow %s arrow %s" % [power_names, bow_names, arrow_names])

	# D28 a trained man is not cut to pieces: two cuts land, the third meets his guard
	_wield(&"sword")
	var g28 := _fighter(&"swordsman", Vector3(0, 0, -1.5))
	_put_player(Vector3(0, 1.05, 0))
	await _frames(20)
	outcomes.clear()
	for i in 90:
		if i == 0 or i == 14 or i == 28 or i == 42:
			Input.action_press("throw")
		elif i == 2 or i == 16 or i == 30 or i == 44:
			Input.action_release("throw")
		await _frames(1)
	_check("D28 a swordsman is not stun-locked: a chained cut after two that landed meets his guard", outcomes.size() >= 3 and outcomes[0] == &"hit" and outcomes[1] == &"hit" and outcomes.slice(2).has(&"blocked"),
		"outcomes %s" % [outcomes])
	if is_instance_valid(g28):
		g28.queue_free()
	await _frames(30)

	# D29 a plain watchman still goes down under a combo
	var g29 := _fighter(&"", Vector3(0, 0, -1.5))
	_put_player(Vector3(0, 1.05, 0))
	await _frames(20)
	outcomes.clear()
	# Clicking on through the combo, as a player would.
	for i in 110:
		if i % 14 == 0:
			Input.action_press("throw")
		elif i % 14 == 2:
			Input.action_release("throw")
		await _frames(1)
	_check("D29 a plain watchman has no answer to a combo", outcomes == [&"hit", &"hit", &"killed"], "outcomes %s" % [outcomes])
	if is_instance_valid(g29):
		g29.queue_free()
	await _frames(30)

	# D30 the archer: he draws (you can see it coming) and his arrow hurts
	player.invulnerable = false
	player.health = player.max_health
	var archer := _fighter(&"archer", Vector3(0, 0, -10.0))
	archer._fighter.dodge_chance = 0.0
	archer.attack_cooldown = 6.0
	_put_player(Vector3(0, 1.05, 0))
	await _frames(20)
	archer._attack_timer = 0.0
	var drew := [false]
	await _until(func(): drew[0] = drew[0] or (archer._phase == &"windup" and archer._attack == &"shoot"); return player.health < player.max_health, 240)
	_check("D30 the archer draws (a warning) and his arrow hurts", drew[0] and _near(player.health, player.max_health - archer.attack_damage, 0.5),
		"drew %s health %.0f" % [drew[0], player.health])

	# D31 a raised guard stops an arrow, for a little stamina
	player.health = player.max_health
	combat.stamina = combat.stamina_max
	defences.clear()
	Input.action_press("block")
	await _frames(40)
	await _until(func(): return archer._phase == &"", 120)
	archer._attack_timer = 0.0
	await _until(func(): return defences.size() > 0, 240)
	await _frames(2)
	Input.action_release("block")
	_check("D31 a raised guard knocks his arrow away", defences.has(&"block") and player.health == player.max_health and combat.stamina < combat.stamina_max,
		"defended %s health %.0f stamina %.0f" % [defences, player.health, combat.stamina])

	# D32 a late step aside and the arrow flies past
	await _until(func(): return archer._phase == &"", 120)
	_put_player(Vector3(0, 1.05, 0))
	player.health = player.max_health
	await _frames(10)
	archer._attack_timer = 0.0
	await _until(func(): return archer._phase == &"windup" and archer._attack == &"shoot" and archer._fighter.progress() >= 0.93, 240)
	Input.action_press("move_right")
	await _tap("dodge")
	await _frames(12)
	Input.action_release("move_right")
	await _frames(40)
	_check("D32 a step aside at the last moment and his arrow flies past", player.health == player.max_health, "health %.0f" % player.health)

	# D33 close in on him: he backs away, and on top of him he kicks you off
	archer.attack_cooldown = 0.6
	_put_player(Vector3(0, 1.05, -7.6))
	var near_start: float = archer.global_position.distance_to(player.global_position)
	await _frames(60)
	var backed: float = archer.global_position.distance_to(player.global_position) - near_start
	staggers.clear()
	archer._attack_timer = 0.0
	player.global_position = archer.global_position + (player.global_position - archer.global_position).normalized() * 1.0 + Vector3.UP * 1.05
	_aim(archer.global_position + Vector3.UP * 1.3)
	await _until(func(): return staggers.has(&"kicked"), 180)
	_check("D33 the archer backs away from you, and kicks you off when you close", backed > 0.6 and staggers.has(&"kicked"),
		"backed off %.2f m, staggers %s" % [backed, staggers])
	archer.queue_free()
	player.invulnerable = true
	player.health = player.max_health
	await _frames(20)

	# D34 blows mashed on each other's heels are read: a trained man starts
	#     catching them even with no guard of his own to speak of
	var g34 := _fighter(&"swordsman", Vector3(0, 0, -1.5))
	g34._fighter.read_skill = 0.9
	g34._fighter.combo_breaker = false
	g34.health = 10000.0
	_put_player(Vector3(0, 1.05, 0))
	await _frames(20)
	outcomes.clear()
	for i in 150:
		if i % 14 == 0:
			Input.action_press("throw")
		elif i % 14 == 2:
			Input.action_release("throw")
		await _frames(1)
	await _frames(30)
	var late: Array = outcomes.slice(maxi(outcomes.size() - 4, 0))
	_check("D34 mashing gets read: the first cuts land, later ones are caught", outcomes.size() >= 4 and outcomes[0] == &"hit" and late.has(&"blocked"),
		"outcomes %s" % [outcomes])
	g34.queue_free()
	await _frames(30)

	# D35 each blow has its own ways: a thrust reaches where a side cut does
	#     not; an overhead lands harder than a side cut
	var g35 := _fighter(&"", Vector3(0, 0, -2.55))
	g35._fighter.stays_put = true
	g35.health = 10000.0
	_put_player(Vector3(0, 1.05, 0))
	_aim(g35.global_position + Vector3.UP * 1.2)
	await _frames(20)
	var reached := {}
	for style in [&"left", &"thrust"]:
		outcomes.clear()
		combat.add_look_motion(Vector2(0.0, 0.25) if style == &"thrust" else Vector2.ZERO)
		await _tap("throw")
		await _frames(50)
		reached[style] = outcomes.has(&"hit")
	g35.global_position = Vector3(0, 0, -1.5)
	await _frames(10)
	var dealt := {}
	var damage_seen: Array = []
	combat.landed.connect(func(t, r, d): damage_seen.append(d))
	for style in [&"left", &"overhead"]:
		damage_seen.clear()
		combat.add_look_motion(Vector2(0.0, -0.25) if style == &"overhead" else Vector2.ZERO)
		await _tap("throw")
		await _frames(50)
		dealt[style] = damage_seen[0] if not damage_seen.is_empty() else 0.0
	_check("D35 a thrust out-reaches a side cut; an overhead hits harder", not reached[&"left"] and reached[&"thrust"] and float(dealt[&"overhead"]) > float(dealt[&"left"]) * 1.15,
		"reached %s dealt %s" % [reached, dealt])
	g35.queue_free()
	await _frames(30)

	# D36 a long swing at a light-footed man: he steps out of it, and makes
	#     you pay for the miss
	var g36 := _fighter(&"duelist", Vector3(0, 0, -1.85))
	g36._fighter.backstep_chance = 1.0
	g36._fighter.read_skill = 1.0
	g36._fighter._strafe = 1.0
	g36.health = 10000.0
	_put_player(Vector3(0, 1.05, 0))
	await _frames(20)
	outcomes.clear()
	var punished := [false]
	await _tap("throw")
	for i in 60:
		await _frames(1)
		if combat.phase == combat.Phase.RECOVER and g36._phase == &"windup":
			punished[0] = true
	_check("D36 a duelist steps out of a long swing and punishes the miss", not outcomes.has(&"hit") and punished[0],
		"outcomes %s punished %s" % [outcomes, punished[0]])
	g36.queue_free()
	await _frames(40)

	# D37 out of reach is not out of danger: a swordsman lunges in
	var g37 := _fighter(&"swordsman", Vector3(0, 0, -3.8))
	g37._fighter.lunge_chance = 30.0
	g37._attack_timer = 0.0
	g37.attack_cooldown = 999.0
	_put_player(Vector3(0, 1.05, 0))
	var lunged := [false]
	var closest := [99.0]
	for i in 120:
		await _frames(1)
		if g37._attack == &"lunge" and g37._phase != &"":
			lunged[0] = true
		closest[0] = minf(closest[0], g37.global_position.distance_to(player.global_position))
	_check("D37 a swordsman lunges in from out of reach", lunged[0] and closest[0] < 2.4,
		"lunged %s closest %.2f m" % [lunged[0], closest[0]])
	g37.queue_free()
	await _frames(40)

	# D38 three on one: those waiting their turn spread to your sides and back
	var ring: Array = []
	for x in [-0.9, 0.0, 0.9]:
		var gx := _fighter(&"swordsman", Vector3(x, 0, -2.6))
		ring.append(gx)
	_put_player(Vector3(0, 1.05, 0))
	await _frames(5)
	ring[1]._fighter._take_token(player)
	await _frames(150)
	var angles: Array = []
	for gx in ring:
		if gx == ring[1]:
			continue
		var to: Vector3 = gx.global_position - player.global_position
		to.y = 0.0
		angles.append(rad_to_deg((-player.global_basis.z).angle_to(to.normalized())))
	_check("D38 guards waiting their turn spread round you", angles.size() == 2 and float(angles[0]) > 60.0 and float(angles[1]) > 60.0,
		"angles off your front %s" % [angles])
	ring[1]._fighter.release_token()

	# D39 one of them is parried: another comes in while you are busy with him
	for gx in ring:
		gx._attack_timer = 5.0
	ring[0]._fighter.on_parried()
	var stepped := false
	for gx in ring:
		if gx != ring[0] and gx._attack_timer <= 0.2:
			stepped = true
	_check("D39 parry one and another steps in", stepped, "timers %s" % [ring.map(func(gx): return snappedf(gx._attack_timer, 0.01))])
	for gx in ring:
		gx.queue_free()
	await _frames(20)


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

## A guard already fighting you, facing you, who will not strike first and
## does not defend unless told to.
func _fighter(archetype: StringName, at: Vector3) -> CharacterBody3D:
	# A new fight: no dread carried over from the last one's dead.
	GarrisonScript.clear_all()
	var g := _new_guard(archetype, at, PI)
	g.block_chance = 0.0
	g._fighter.parry_chance = 0.0
	g._fighter.feint_chance = 0.0
	g._fighter.dodge_chance = 0.0
	g._fighter.counter_chance = 0.0
	g._fighter.kick_chance = 0.0
	g._fighter.backstep_chance = 0.0
	g._fighter.lunge_chance = 0.0
	g._fighter.timing_variance = 0.0
	g._fighter.read_skill = 0.0
	g._attack_timer = 999.0
	g.attack_cooldown = 999.0
	g._engage(player)
	return g


func _new_guard(archetype: StringName, at: Vector3, yaw: float) -> CharacterBody3D:
	var g: CharacterBody3D = GUARD.instantiate()
	g.archetype = archetype
	g.debug_ai = false
	g.position = at
	g.rotation.y = yaw
	add_child(g)
	return g


func _wield(weapon_id: StringName) -> void:
	player.inventory.select_by_id(weapon_id)


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


func _aim(target: Vector3) -> void:
	var eye: Vector3 = player.get_node("Neck").global_position
	var d := target - eye
	player.rotation.y = atan2(-d.x, -d.z)
	player.get_node("Neck").rotation.x = atan2(d.y, Vector2(d.x, d.z).length())


func _release_all() -> void:
	for a in ["move_forward", "move_back", "move_left", "move_right", "jump", "sprint", "crouch", "frob", "throw", "block", "kick", "dodge"]:
		if InputMap.has_action(a):
			Input.action_release(a)


func _names() -> Array:
	var names := []
	for entry in Sfx.recorded:
		if not names.has(entry[0]):
			names.append(entry[0])
	return names


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
