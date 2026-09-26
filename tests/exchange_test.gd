extends Node3D
## Call and answer: each of his blows asks something of you (GuardFighter.CALLS)
## and shows it; answered as it asks, he is thrown off his balance (his
## posture), and broken he is open to a deathblow. A thrust asks for a parry
## or a step aside, a sweep for a jump, an unblockable blow for a dodge; the
## archer kicks you off him; strings of blows follow on from each other; his
## windups hold their key pose and let go fast.

const PLAYER := preload("res://Player.tscn")
const GUARD := preload("res://Guard.tscn")
const Props := preload("res://scripts/Interaction/Props.gd")
const NavBakerScript := preload("res://scripts/AISystem/NavBaker.gd")
const GuardFighterScript := preload("res://scripts/AISystem/GuardFighter.gd")
const GuardRigScript := preload("res://scripts/AISystem/GuardRig.gd")
const ArrowScript := preload("res://scripts/Combat/Arrow.gd")
const TemperamentScript := preload("res://scripts/AISystem/Temperament.gd")
const GarrisonScript := preload("res://scripts/AISystem/Garrison.gd")

var player: CharacterBody3D
var combat: Node
var results: Array[String] = []
var answers: Array = []
var defences: Array = []
var deathblows: Array = []


func _ready() -> void:
	# Every guard at his class's own temperament: these checks are exact.
	TemperamentScript.rolling = false
	Props.block(self, Vector3(0, -0.5, 0), Vector3(120, 1, 120))

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
	player.global_position = Vector3(0, 1.05, 30)
	Props.give_weapons(player, 12)
	combat = player.combat
	combat.answered.connect(func(how): answers.append(how))
	combat.defended.connect(func(r): defences.append(r))
	combat.deathblow_landed.connect(func(t): deathblows.append(t))
	player.inventory.select_by_id(&"sword")

	await baker.baked
	await _frames(5)
	await _run()

	print("\n==== RESULTS ====")
	for r in results:
		print(r)
	get_tree().quit()


func _run() -> void:
	# X1 parry him again and again and his balance goes: he is open
	var g1 := _fighter(&"swordsman", Vector3(0, 0, -1.3))
	g1._fighter.attacks = {&"overhead": 1.0}
	g1._fighter.follow = {}
	g1._fighter.combo_max = 1
	g1.parry_stun = 0.4
	g1.attack_cooldown = 0.3
	var broke := [0]
	g1.posture_broken.connect(func(): broke[0] += 1)
	_put_player(Vector3(0, 1.05, 0))
	await _frames(10)
	defences.clear()
	var postures: Array = []

	for n in 3:
		g1._attack_timer = 0.0
		await _parry_next(g1)
		postures.append(snappedf(g1._fighter.posture, 0.1))
		await _until(func(): return g1._stagger <= 0.0 or g1.is_open(), 120)

	var open1: bool = g1.is_open()
	_check("X1 three parries in a row throw a swordsman off his balance: he is open", broke[0] == 1 and open1 and defences.count(&"parry") == 3,
		"parries %d postures %s broken %d open %s" % [defences.count(&"parry"), postures, broke[0], open1])

	# X2 whatever lands on an open man is a deathblow
	await _frames(20)
	var shown_open: bool = g1._rig.is_open_shown()
	var kneeling: bool = g1._rig.man._held[g1._rig.man._front] == GuardRigScript.OPEN_CLIP
	deathblows.clear()
	var g1_id := g1.get_instance_id()
	await _tap("throw")
	await _until(func(): return not is_instance_id_valid(g1_id), 60)
	_check("X2 an open man is shown down on one knee, and one blow kills him", shown_open and kneeling and deathblows.size() == 1 and not is_instance_id_valid(g1_id),
		"shown open %s kneeling %s deathblows %d dead %s" % [shown_open, kneeling, deathblows.size(), not is_instance_id_valid(g1_id)])
	await _frames(30)

	# X3 a brute takes two
	var g3 := _fighter(&"brute", Vector3(0, 0, -1.6))
	var brute_max: float = g3.max_health
	_put_player(Vector3(0, 1.05, 0))
	await _frames(10)
	g3._fighter.add_posture(g3._fighter.posture_max)
	await _frames(10)
	await _tap("throw")
	await _frames(40)
	var after_one: float = g3.health
	await _until(func(): return combat.phase == combat.Phase.IDLE, 60)
	await _frames(20)
	g3._fighter.add_posture(g3._fighter.posture_max)
	await _frames(10)
	var g3_id := g3.get_instance_id()
	await _tap("throw")
	await _until(func(): return not is_instance_id_valid(g3_id), 60)
	_check("X3 a brute takes two deathblows", after_one > 0.0 and after_one < brute_max * 0.55 and not is_instance_id_valid(g3_id),
		"health after one %.0f of %.0f, dead after two %s" % [after_one, brute_max, not is_instance_id_valid(g3_id)])
	await _frames(30)

	# X4 a thrust on a raised guard: some of it gets through, and it costs
	player.invulnerable = false
	player.health = player.max_health
	var g4 := _fighter(&"", Vector3(0, 0, -1.4))
	g4._fighter.attacks = {&"thrust": 1.0}
	g4.attack_cooldown = 5.0
	_put_player(Vector3(0, 1.05, 0))
	Input.action_press("block")
	await _frames(40)
	defences.clear()
	g4._attack_timer = 0.0
	await _until(func(): return defences.size() > 0, 240)
	await _frames(2)
	Input.action_release("block")
	var through: float = player.max_health - player.health
	var spent: float = combat.stamina_max - combat.stamina
	var thrust_damage: float = g4.attack_damage * float(GuardFighterScript.ATTACKS[&"thrust"]["damage"])
	var thrust_cost: float = g4._fighter.guard_damage * float(GuardFighterScript.ATTACKS[&"thrust"]["guard"]) * 1.5
	_check("X4 a raised guard turns a thrust only partly, and dearly", defences.has(&"block") and _near(through, thrust_damage * 0.4, 0.3) and _near(spent, thrust_cost, 1.5),
		"through %.1f (expected %.1f) stamina spent %.1f (expected %.1f)" % [through, thrust_damage * 0.4, spent, thrust_cost])

	# X5 a parried thrust throws him further off his feet than a parried cut
	await _until(func(): return g4._phase == &"", 120)
	await _frames(30)
	player.health = player.max_health
	g4._fighter.posture = 0.0
	defences.clear()
	g4._attack_timer = 0.0
	await _parry_next(g4)
	var stun: float = g4._stagger
	var shaken: float = g4._fighter.posture
	_check("X5 a parried thrust staggers him longer and shakes him more", defences.has(&"parry") and stun > g4.parry_stun * 1.1 and _near(shaken, 50.0, 1.0),
		"defended %s stun %.2f (a cut's %.2f) posture %.1f" % [defences, stun, g4.parry_stun, shaken])
	g4.queue_free()
	await _frames(30)

	# X6 a sweep goes under a raised guard; jumped, it leaves him overreaching
	player.health = player.max_health
	var g6 := _fighter(&"", Vector3(0, 0, -1.4))
	g6._fighter.attacks = {&"sweep": 1.0}
	g6.attack_cooldown = 5.0
	_put_player(Vector3(0, 1.05, 0))
	Input.action_press("block")
	await _frames(40)
	g6._attack_timer = 0.0
	await _until(func(): return g6._phase == &"recover", 240)
	Input.action_release("block")
	var under: float = player.max_health - player.health
	var sweep_damage: float = g6.attack_damage * float(GuardFighterScript.ATTACKS[&"sweep"]["damage"])
	await _until(func(): return g6._phase == &"", 120)
	await _frames(20)
	player.health = player.max_health
	answers.clear()
	g6._fighter.posture = 0.0
	g6._attack_timer = 0.0
	await _until(func(): return g6._phase == &"windup" and g6._phase_timer < 0.12, 240)
	Input.action_press("jump")
	await _until(func(): return g6._phase != &"windup", 60)
	Input.action_release("jump")
	await _frames(2)
	var jump_stun: float = g6._stagger
	var riposte_open: bool = combat._game_time <= combat._riposte_until
	_check("X6 a sweep goes under a raised guard; jump it and he is left overreaching", _near(under, sweep_damage, 0.5) and answers.has(&"jumped") and _near(player.health, player.max_health, 0.1) and jump_stun > 0.5 and _near(g6._fighter.posture, 38.0, 1.0) and riposte_open,
		"under the guard %.1f (a sweep %.1f) answers %s health %.0f stun %.2f posture %.0f riposte %s" % [under, sweep_damage, answers, player.health, jump_stun, g6._fighter.posture, riposte_open])
	g6.queue_free()
	await _frames(40)

	# X7 dodge out of an unblockable blow at the last moment: he overreaches
	player.health = player.max_health
	var g7 := _fighter(&"", Vector3(0, 0, -1.8))
	g7._fighter.attacks = {&"heavy": 1.0}
	g7.attack_cooldown = 5.0
	_put_player(Vector3(0, 1.05, 0))
	await _frames(20)
	answers.clear()
	g7._attack_timer = 0.0
	await _until(func(): return g7._phase == &"windup" and g7._phase_timer < 0.3, 240)
	await _tap("dodge")
	await _until(func(): return g7._phase != &"windup", 60)
	await _frames(2)
	_check("X7 a last-moment dodge out of an unblockable blow leaves him overreaching", answers.has(&"dodged") and _near(player.health, player.max_health, 0.1) and g7._stagger > 0.5,
		"answers %s health %.0f stun %.2f" % [answers, player.health, g7._stagger])
	g7.queue_free()
	await _frames(40)

	# X8 the archer kicks you off him at a sword's length
	player.invulnerable = true
	var g8 := _fighter(&"archer", Vector3(0, 0, -1.8))
	_put_player(Vector3(0, 1.05, 0))
	await _frames(10)
	g8._attack_timer = 0.0
	g8.attack_cooldown = 5.0
	var kinds := {}
	for i in 120:
		if g8._phase != &"":
			kinds[g8._attack] = true
		await _frames(1)
	_check("X8 the archer kicks you off him when you are at his sword's length", kinds.has(&"kick") and not kinds.has(&"shoot"),
		"his blows %s" % [kinds.keys()])
	g8.queue_free()
	await _frames(30)

	# X9 strings of blows: what follows a blow is one of those he follows it with
	var g9 := _fighter(&"swordsman", Vector3(0, 0, -1.4))
	g9._fighter.attacks = {&"left": 1.0}
	g9._fighter.combo_max = 3
	g9._fighter.delay_chance = 0.0
	g9.attack_cooldown = 0.3
	_put_player(Vector3(0, 1.05, 0))
	await _frames(10)
	g9._attack_timer = 0.0
	var follows: Array = []
	var last_phase: StringName = &""
	var last_kind: StringName = &""
	for i in 900:
		if g9._phase == &"windup" and last_phase == &"strike":
			follows.append([last_kind, g9._attack])
		if g9._phase != &"":
			last_kind = g9._attack
		last_phase = g9._phase
		if follows.size() >= 4:
			break
		await _frames(1)
	var table: Dictionary = GuardFighterScript.ARCHETYPES[&"swordsman"]["follow"]
	# (A blow with nothing listed after it is followed by any.)
	var listed := follows.filter(func(f): return table.has(f[0]))
	var in_table := listed.filter(func(f): return (table.get(f[0], []) as Array).has(f[1]))
	_check("X9 his strings follow on: each blow after another is one he follows it with", listed.size() >= 2 and in_table.size() == listed.size(),
		"strings %s" % [follows])
	g9.queue_free()
	await _frames(30)

	# X10 his blade says what his blow asks of you
	var colours := {}
	for spec in [[&"thrust", 0.9], [&"heavy", 0.35], [&"sweep", 0.35], [&"overhead", 0.9]]:
		var g := _fighter(&"", Vector3(0, 0, -1.4))
		g._fighter.attacks = {spec[0]: 1.0}
		g.attack_cooldown = 5.0
		_put_player(Vector3(0, 1.05, 0))
		await _frames(10)
		g._attack_timer = 0.0
		await _until(func(): return g._phase == &"windup" and g._fighter.progress() >= float(spec[1]), 240)
		await _frames(2)
		var steel: Array = g._rig._steel
		colours[spec[0]] = (steel[0] as StandardMaterial3D).emission if not steel.is_empty() else Color.BLACK
		g.queue_free()
		await _frames(20)
	var blue: Color = colours[&"thrust"]
	var red: Color = colours[&"heavy"]
	var orange: Color = colours[&"sweep"]
	var pale: Color = colours[&"overhead"]
	_check("X10 his blade glows the colour of his call: blue a thrust, red unblockable, orange low, pale a cut",
		blue.b > blue.r + 0.1 and red.r > 0.85 and red.g < 0.35 and orange.r > 0.85 and orange.g > 0.35 and orange.b < 0.3 and absf(pale.r - pale.b) < 0.12,
		"thrust %s heavy %s sweep %s overhead %s" % [blue, red, orange, pale])

	# X11 his windup gets to its key pose fast, holds it, and lets go fast
	var over: Dictionary = GuardRigScript.SWINGS[&"overhead"]
	var at := func(u: float) -> float: return GuardRigScript.windup_time_in(over, u, 0.55)
	var early: float = at.call(0.15)
	var held_a: float = at.call(0.4)
	var held_b: float = at.call(0.7)
	var late: float = at.call(0.9)
	var end: float = at.call(1.0)
	_check("X11 his windup: quickly up to the cocked pose, held, then let go into the blow",
		early > float(over["from"]) + (float(over["cocked"]) - float(over["from"])) * 0.5 and _near(held_a, over["cocked"], 0.001) and _near(held_b, over["cocked"], 0.001) and late > float(over["cocked"]) and late < float(over["contact"]) and _near(end, over["contact"], 0.001),
		"t at u 0.15 %.3f 0.4 %.3f 0.7 %.3f 0.9 %.3f 1.0 %.3f (cocked %.2f contact %.2f)" % [early, held_a, held_b, late, end, over["cocked"], over["contact"]])

	# X12 left alone, his balance comes back
	var g12 := _fighter(&"swordsman", Vector3(0, 0, -2.5))
	await _frames(10)
	g12._fighter.add_posture(50.0)
	await _frames(50)
	var soon: float = g12._fighter.posture
	await _frames(150)
	var later: float = g12._fighter.posture
	_check("X12 given room, his balance comes back", _near(soon, 50.0, 0.5) and later < 30.0,
		"posture after 0.8 s %.1f, after 3.3 s %.1f" % [soon, later])
	g12.queue_free()
	await _frames(20)

	# X13 your blows on his raised guard wear his balance down too
	var g13 := _fighter(&"swordsman", Vector3(0, 0, -1.4))
	_put_player(Vector3(0, 1.05, 0))
	await _frames(10)
	for n in 2:
		g13._fighter.guarding = true
		g13._fighter._guard_hold = 5.0
		await _tap("throw")
		await _until(func(): return combat.phase == combat.Phase.IDLE, 90)
		await _frames(6)
	_check("X13 blows caught on his guard wear down his balance", g13._fighter.posture >= 12.0 and g13.health == g13.max_health,
		"posture %.1f health %.0f" % [g13._fighter.posture, g13.health])
	g13.queue_free()
	await _frames(20)

	# X14 back away from a lunge and it falls short
	player.invulnerable = false
	player.health = player.max_health
	var g14 := _fighter(&"duelist", Vector3(0, 0, -3.6))
	_put_player(Vector3(0, 1.05, 0))
	await _frames(10)
	g14._fighter._start(&"lunge")
	await _until(func(): return g14._fighter.progress() > 0.3, 60)
	_put_player(Vector3(0, 1.05, 2.4))
	await _until(func(): return g14._phase == &"recover" or g14._phase == &"", 120)
	_check("X14 back away from a lunge and it falls short", _near(player.health, player.max_health, 0.1) and not g14._fighter._landed,
		"health %.0f landed %s gap %.2f" % [player.health, g14._fighter._landed, g14.global_position.distance_to(player.global_position)])
	g14.queue_free()
	player.invulnerable = true
	await _frames(20)

	# X15 a riposte rocks him hard but briefly: it takes the opening his
	#     parried blow made, and he is soon back in the fight
	var g15 := _fighter(&"swordsman", Vector3(0, 0, -1.3))
	g15._fighter.attacks = {&"overhead": 1.0}
	g15._fighter.follow = {}
	g15.attack_cooldown = 5.0
	var stun_at := [-1.0]
	g15.struck_by.connect(func(result, _kind, _damage): if result == &"hit": stun_at[0] = g15._stagger)
	_put_player(Vector3(0, 1.05, 0))
	await _frames(10)
	g15._attack_timer = 0.0
	await _parry_next(g15)
	await _tap("throw")
	await _until(func(): return stun_at[0] >= 0.0, 40)
	await _frames(40)
	var back: bool = g15._stagger <= 0.0
	_check("X15 a riposte rocks him hard but briefly, and he is soon back in the fight", stun_at[0] >= g15.stagger_time * 1.2 and stun_at[0] <= g15.stagger_time * 1.5 and stun_at[0] < g15.parry_stun * 0.6 and back,
		"stun %.2f (a quick cut's %.2f, the parry's %.2f) back on his feet %.2f s later %s" % [stun_at[0], g15.stagger_time, g15.parry_stun, 40.0 / 60.0, back])
	g15.queue_free()
	await _frames(20)

	# X16 shaken, he steps back to find his feet and will not come at you
	var g16 := _fighter(&"swordsman", Vector3(0, 0, -2.4))
	_put_player(Vector3(0, 1.05, 0))
	# Shaken from the start (had he come into reach first, crowded, he would
	# lash out).
	g16._fighter.add_posture(80.0)
	await _frames(6)
	var start_gap: float = g16.global_position.distance_to(player.global_position)
	g16._attack_timer = 0.0
	g16.attack_cooldown = 0.3
	var swung := false
	for i in 60:
		if g16._phase != &"":
			swung = true
		await _frames(1)
	var gap: float = g16.global_position.distance_to(player.global_position)
	var mood_then: StringName = g16._fighter.mood
	# Not for long: however shaken, he comes again.
	await _frames(40)
	var came_back: bool = g16._fighter.mood != &"shaken"
	_check("X16 shaken, he backs off to find his feet, but only for a moment", mood_then == &"shaken" and gap > start_gap + 0.4 and not swung and came_back,
		"mood %s gap %.2f -> %.2f swung %s, %.1f s on: %s (balance %.0f)" % [mood_then, start_gap, gap, swung, 106.0 / 60.0, g16._fighter.mood, g16._fighter.posture])
	g16.queue_free()
	await _frames(20)

	# X17 badly hurt: alone, a rash man is desperate and a steady one careful;
	#     beside a friend, careful
	var g17b := _fighter(&"swordsman", Vector3(0, 0, -2.2), &"steady")
	g17b.health = g17b.max_health * 0.3
	await _frames(30)
	var alone_steady: StringName = g17b._fighter.mood
	g17b.queue_free()
	await _frames(20)
	var g17 := _fighter(&"swordsman", Vector3(0, 0, -2.2), &"rash")
	g17.health = g17.max_health * 0.3
	await _frames(30)
	var alone: StringName = g17._fighter.mood
	var friend := _fighter(&"swordsman", Vector3(1.6, 0, -2.2))
	await _frames(40)
	var together: StringName = g17._fighter.mood
	_check("X17 badly hurt: alone, a rash man is desperate and a steady man careful; beside a friend, careful",
		alone == &"desperate" and alone_steady == &"hurt" and together == &"hurt" and g17._fighter._cooldown_scale() > 1.2,
		"alone rash %s steady %s, with a friend %s, cooldown x%.2f" % [alone, alone_steady, together, g17._fighter._cooldown_scale()])
	g17.queue_free()
	friend.queue_free()
	await _frames(20)

	# X18 you in trouble: he presses; a brute badly hurt is enraged
	var g18 := _fighter(&"swordsman", Vector3(0, 0, -2.2))
	var brute := _fighter(&"brute", Vector3(2.5, 0, -2.5))
	brute.health = brute.max_health * 0.3
	player.health = player.max_health * 0.3
	await _frames(30)
	_check("X18 with you in trouble he presses; a brute badly hurt is enraged", g18._fighter.mood == &"pressing" and g18._fighter._cooldown_scale() < 1.0 and brute._fighter.mood == &"enraged",
		"his mood %s (cooldown x%.2f) the brute's %s" % [g18._fighter.mood, g18._fighter._cooldown_scale(), brute._fighter.mood])
	g18.queue_free()
	brute.queue_free()
	player.health = player.max_health
	await _frames(20)

	# X19 get away and catch your breath: the shield you are in fills again
	player.invulnerable = false
	player.health = player.max_health
	_put_player(Vector3(20, 1.05, 20))
	player.take_damage(50.0, null)
	var hurt_to: float = player.health
	await _frames(180)
	var resting: float = player.health
	await _frames(420)
	var rested: float = player.health
	var top: float = player.max_health / float(player.shields) * ceilf(hurt_to / (player.max_health / float(player.shields)) - 0.001)
	_check("X19 left alone a while, the shield you are in fills again, and no further", _near(resting, hurt_to, 0.1) and _near(rested, top, 0.1) and rested < player.max_health,
		"hurt to %.0f, after 3 s %.0f, after 10 s %.0f (shield top %.0f)" % [hurt_to, resting, rested, top])
	player.invulnerable = true
	player.health = player.max_health
	await _frames(20)

	# X20 an arrow flies on, and lands, after the archer who loosed it is gone
	var archer := _fighter(&"archer", Vector3(0, 0, -30.0))
	_put_player(Vector3(0, 1.05, 0))
	await _frames(10)
	var arrow: StaticBody3D = ArrowScript.new()
	add_child(arrow)
	arrow.launch(archer.eye_position() + Vector3(0, 0, 0.6), Vector3(0, 0, 30.0), 10.0, archer, 1.5)
	archer.queue_free()
	var flew := 0
	for i in 90:
		if is_instance_valid(arrow) and arrow.get("shooter") == null:
			flew += 1
		await _frames(1)
	_check("X20 an arrow flies on after its archer is gone, and forgets him", flew > 0, "frames flown without him %d" % flew)


## Waits for his next blow and parries it.
func _parry_next(g: CharacterBody3D) -> void:
	await _until(func(): return g._phase == &"windup" and g._phase_timer < 0.12, 240)
	Input.action_press("block")
	await _until(func(): return g._phase != &"windup", 60)
	await _frames(4)
	Input.action_release("block")
	await _frames(2)


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

## A guard already fighting you, facing you, who will not strike first and
## does not defend unless told to.
func _fighter(archetype: StringName, at: Vector3, preset: StringName = &"") -> CharacterBody3D:
	# A new fight: no dread carried over from the last one's dead.
	GarrisonScript.clear_all()
	var g: CharacterBody3D = GUARD.instantiate()
	g.archetype = archetype
	g.temperament = preset
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
	g._fighter.charge_chance = 0.0
	g._fighter.timing_variance = 0.0
	g._fighter.read_skill = 0.0
	g._attack_timer = 999.0
	g.attack_cooldown = 999.0
	g._engage(player)
	return g


func _put_player(at: Vector3) -> void:
	for a in ["move_forward", "move_back", "move_left", "move_right", "jump", "sprint", "crouch", "frob", "throw", "block", "kick", "dodge"]:
		if InputMap.has_action(a):
			Input.action_release(a)

	player.movement_state = 0
	player.current_move = null
	player.velocity = Vector3.ZERO
	player.global_position = at
	player.rotation.y = 0.0
	player.get_node("Neck").rotation.x = 0.0
	combat._reset()
	combat.adrenaline = 0.0
	combat.stamina = combat.stamina_max


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
