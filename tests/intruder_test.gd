extends Node3D
## The intruder of the NPC showcase: a guard's body with the guard's mind
## switched off (Guard.puppet), who answers to the guards as the player does
## (Intruder.gd, IntruderCombat.gd) and is driven by the director
## (IntruderBrain.gd).
##
##   Godot --headless --fixed-fps 60 --quit-after 40000 --path . res://tests/intruder_test.tscn

const GUARD := preload("res://Guard.tscn")
const INTRUDER := preload("res://Intruder.tscn")
const Props := preload("res://scripts/Interaction/Props.gd")
const NavBakerScript := preload("res://scripts/AISystem/NavBaker.gd")
const SquadScript := preload("res://scripts/AISystem/Squad.gd")
const GarrisonScript := preload("res://scripts/AISystem/Garrison.gd")
const TemperamentScript := preload("res://scripts/AISystem/Temperament.gd")
const GuardScript := preload("res://scripts/AISystem/Guard.gd")
const SoundBus := preload("res://scripts/StimuliSystem/SoundBus.gd")
const LightProbe := preload("res://scripts/StimuliSystem/LightProbe.gd")
const Sfx := preload("res://scripts/Audio/Sfx.gd")
const TimeFx := preload("res://scripts/Visual/TimeFx.gd")

const RELAXED := 0
const SUSPICIOUS := 1
const INVESTIGATING := 2
const SEARCHING := 3
const COMBAT := 4

## The near-black the intruder's outfit is dyed.
const DYE := Color(0.07, 0.07, 0.08)

var results: Array[String] = []
var _barks := {}


func _ready() -> void:
	TemperamentScript.rolling = false
	GuardScript.bleeding_on = false
	Props.block(self, Vector3(200, -0.5, 0), Vector3(500, 1, 60))
	# (I20's doorway: a wall across the floor at x 430, a 1.2 m gap in it.)
	Props.block(self, Vector3(430, 1.5, -15.3), Vector3(0.4, 3.0, 29.4))
	Props.block(self, Vector3(430, 1.5, 15.3), Vector3(0.4, 3.0, 29.4))

	var baker := NavigationRegion3D.new()
	baker.set_script(NavBakerScript)
	add_child(baker)
	await baker.baked
	await _frames(5)
	await _run()

	GuardScript.randomize_on = true
	print("\n==== RESULTS ====")
	for r in results:
		print(r)
	get_tree().quit()


func _run() -> void:
	# I1 he is the one the guards are after, not one of them, and deaf
	await _fresh()
	var i1 := _intruder(Vector3(0, 0, 0))
	await _frames(5)
	_check("I1 the intruder is in the player group, not the guards group, and not a SoundBus listener",
		i1.is_in_group(&"player") and not i1.is_in_group(&"guards") and not SoundBus._listeners.has(i1),
		"player %s guards %s listener %s" % [i1.is_in_group(&"player"), i1.is_in_group(&"guards"), SoundBus._listeners.has(i1)])

	# I2 dressed as the archer, in near-black, a sword in his hand
	var man: Node = i1._rig.man
	var look: Variant = man.get("look")
	var dressed: bool = look is Dictionary and not (look as Dictionary).is_empty()
	var dyed: bool = not dressed or ((look as Dictionary).get("dye", Color.WHITE) as Color).is_equal_approx(DYE)
	_check("I2 his look is the archer outfit dyed near-black, with a sword",
		i1._rig._carried == &"sword" and dyed,
		"carried %s, dressed %s, dye %s" % [i1._rig._carried, dressed, (look as Dictionary).get("dye", "-") if dressed else "painted"])

	# I3 a guard in the light beside him: the guard reacts, he does not
	await _fresh()
	_light(Vector3(40, 3, 0))
	var i3 := _intruder(Vector3(40, 0, 0))
	var g3 := _guard(&"", Vector3(40, 0, 5), 0.0)
	_barks[i3] = []
	i3.barked.connect(func(t): _barks[i3].append(t))
	await _frames(30)
	# A shout right beside him, and a guard beside him: nothing stirs him.
	SoundBus.emit_sound(i3.global_position + Vector3(1, 1, 0), 75.0, g3, &"shout")
	await _frames(300)
	_check("I3 he never barks, and his state and alert never change by themselves (a shout beside him, a guard in light)",
		_barks[i3].is_empty() and i3.state == RELAXED and i3.alert == 0.0,
		"his barks %s, his state %d, his alert %.1f" % [_barks[i3], i3.state, i3.alert])

	# I4 killed, he is nobody's friend: no body to find, no post, no dread
	await _fresh()
	var i4 := _intruder(Vector3(80, 0, 0))
	var g4 := _guard(&"", Vector3(80, 0, 2), PI)
	await _frames(10)
	var garrison4: RefCounted = GarrisonScript.of(i4)
	# (His plot armour would keep him up: the director lifts it to kill him.)
	if i4.has_method("fall"):
		i4.fall()
	i4.take_hit(999.0, g4, &"quick", i4.global_position + Vector3.UP, Vector3.BACK)
	await _frames(10)
	var bodies := get_tree().get_nodes_in_group(&"bodies")
	_check("I4 killed, he leaves no body in \"bodies\", no fallen post in the garrison, and no dread",
		bodies.is_empty() and garrison4.fallen.is_empty() and garrison4.dread == 0.0,
		"bodies %d, fallen %s, dread %.2f" % [bodies.size(), garrison4.fallen, garrison4.dread])


	# Answering to the guards as the player does (Intruder, IntruderCombat)

	# I5 seen in the light, he is taken on
	await _fresh()
	_light(Vector3(120, 3, 2))
	var i5 := _intruder(Vector3(120, 0, 0))
	var g5 := _guard(&"", Vector3(120, 0, 4), 0.0)
	await _until(func(): return g5.state == COMBAT, 240)
	_check("I5 a guard who sees him in light takes him on",
		g5.state == COMBAT and g5._target == i5,
		"state %d, target %s" % [g5.state, g5._target])

	# I6 light and crouching show in his exposure
	await _fresh()
	_light(Vector3(160, 3, 0))
	var lit6 := _intruder(Vector3(160, 0, 0))
	var dark6 := _intruder(Vector3(190, 0, 0))
	await _frames(5)
	var lit_standing: float = lit6.get_exposure()
	lit6.crouched = true
	var lit_crouched: float = lit6.get_exposure()
	var dark_standing: float = dark6.get_exposure()
	_check("I6 his exposure follows the light and his crouch: lit > dark, crouched < standing",
		lit_standing > dark_standing + 0.1 and lit_crouched < lit_standing,
		"lit %.2f, lit crouched %.2f, dark %.2f" % [lit_standing, lit_crouched, dark_standing])

	# I7 his cut lands through the guard's own take_hit
	await _fresh()
	var i7 := _intruder(Vector3(220, 0, 0))
	var g7 := _guard(&"swordsman", Vector3(220, 0, -1.2), PI)
	var struck7 := []
	g7.struck_by.connect(func(result, kind, _d): struck7.append([result, kind]))
	await _frames(10)
	i7.combat.swing(&"left")
	await _frames(60)
	_check("I7 his quick cut reaches a guard through take_hit",
		struck7.any(func(e): return e[1] == &"quick"),
		"struck %s" % [struck7])

	# I8 a guard with his guard up catches it
	await _fresh()
	var i8 := _intruder(Vector3(250, 0, 0))
	var g8 := _guard(&"swordsman", Vector3(250, 0, -1.4), 0.0)
	g8._attack_timer = 999.0
	g8.attack_cooldown = 999.0
	var struck8 := []
	g8.struck_by.connect(func(result, kind, _d): struck8.append([result, kind]))
	g8._engage(i8)
	await _frames(20)
	g8.look_at(i8.global_position, Vector3.UP)
	i8.combat.swing(&"right")
	for f in 60:
		g8._fighter.guarding = true
		g8._fighter._parry_at = -1.0
		i8.look_at(g8.global_position, Vector3.UP)
		await _frames(1)
	_check("I8 a guarding guard blocks his cut",
		struck8.any(func(e): return e[0] == &"blocked"),
		"struck %s" % [struck8])

	# I9 his parry throws a guard's blow aside; I13 the squad sees it
	await _fresh()
	var i9 := _intruder(Vector3(280, 0, 0))
	var g9 := _guard(&"swordsman", Vector3(280, 0, -1.5), 0.0)
	g9._engage(i9)
	await _frames(30)
	i9.look_at(g9.global_position, Vector3.UP)
	var posture9: float = g9._fighter.posture
	g9._attack_timer = 999.0
	g9._fighter._start(&"overhead")
	await _until(func(): return g9._phase == &"windup" and g9._phase_timer <= 0.1, 120)
	var at9 := "phase %s timer %.2f dist %.2f" % [g9._phase, g9._phase_timer, g9.global_position.distance_to(i9.global_position)]
	i9.look_at(g9.global_position, Vector3.UP)
	i9.combat.guard_up(true)
	var defended9 := []
	i9.combat.defended.connect(func(r): defended9.append(r))
	await _frames(20)
	_check("I9 his parry throws a guard's blow aside",
		g9._stagger > 0.0 and g9._fighter.posture >= posture9 + 34.0 - 0.01,
		"stagger %.2f, posture %.1f -> %.1f, at the guard-up %s, defended %s, his health %.0f" % [g9._stagger, posture9, g9._fighter.posture, at9, defended9, i9.health])
	var read9: Dictionary = SquadScript.of(i9).read
	var parry_read := float(read9.get(&"parry", 0.0))
	i9.combat.guard_up(false)
	i9.combat.dodge(g9.global_position)
	await _frames(5)
	_check("I13 his parry and his dodge feed the squad's reads (defended, dodged)",
		parry_read > 0.0 and float(read9.get(&"dodge", 0.0)) > 0.0,
		"parry %.2f, dodge %.2f" % [parry_read, float(read9.get(&"dodge", 0.0))])

	# I10 what a guard can read off his blow
	await _fresh()
	var i10 := _intruder(Vector3(310, 0, 0))
	await _frames(5)
	var serial_before: int = i10.combat.threat_serial()
	i10.combat.swing(&"overhead")
	await _frames(3)
	var windup_phase: StringName = i10.combat.threat_phase()
	var contact: float = i10.combat.time_to_contact()
	var serial_after: int = i10.combat.threat_serial()
	await _frames(60)
	_check("I10 his read-outs follow his swing",
		windup_phase == &"windup" and contact > 0.0 and serial_after != serial_before and i10.combat.threat_phase() == &"",
		"windup %s, contact %.2f, serial %d -> %d, after %s" % [windup_phase, contact, serial_before, serial_after, i10.combat.threat_phase()])

	# I11 behind his guard, the squad reads a turtle
	await _fresh()
	_light(Vector3(340, 3, 0))
	var i11 := _intruder(Vector3(340, 0, 0))
	var a11 := _guard(&"swordsman", Vector3(340, 0, -2.0), 0.0)
	var b11 := _guard(&"", Vector3(341.5, 0, -1.5), 0.0)
	a11._engage(i11)
	b11._engage(i11)
	await _frames(30)
	for f in 480:
		# (A boot knocks his guard down: he raises it again, as a turtle does.)
		i11.combat.guard_up(true)
		i11.look_at(a11.global_position, Vector3.UP)
		await _frames(1)
	var turtle := float(SquadScript.of(i11).read.get(&"turtle", 0.0))
	_check("I11 a squad reads his turtle",
		turtle > 0.55,
		"turtle %.2f" % turtle)

	# I12 plot armour, then none
	await _fresh()
	var i12 := _intruder(Vector3(370, 0, 0))
	var g12 := _guard(&"", Vector3(370, 0, 2), PI)
	await _frames(5)
	i12.take_damage(500.0, g12)
	await _frames(2)
	var floor_health: float = i12.health
	var max12: float = i12.max_health
	i12.fall()
	i12.take_damage(500.0, g12)
	await _frames(5)
	_check("I12 plot armour: blows cannot take him under his floor (40%); after fall() they kill him",
		absf(floor_health - 0.4 * max12) < 0.5 and (not is_instance_valid(i12) or i12.is_dead),
		"health after the first %.1f of %.1f, dead after fall %s" % [floor_health, max12, not is_instance_valid(i12) or i12.is_dead])

	# I13b an archer's arrow finds him (it is aimed at his chest, not his feet)
	await _fresh()
	_light(Vector3(395, 3, 0))
	var i13 := _intruder(Vector3(395, 0, 0))
	var archer := _guard(&"archer", Vector3(395, 0, 9), 0.0, &"steady")
	archer._engage(i13)
	var health13: float = i13.health
	await _until(func(): return i13.health < health13, 900)
	_check("I13b an archer's arrow finds him",
		i13.health < health13,
		"health %.1f -> %.1f" % [health13, i13.health])


	# His brain (IntruderBrain), and the sound and time around him

	# I14 he sneaks where he is sent
	await _fresh()
	var i14 := _intruder(Vector3(20, 0, 20))
	await _frames(5)
	var goal14 := Vector3(26, 0, 20)
	i14.brain.go_to(goal14, &"sneak")
	var sneaking14 := [false]
	var crouched14 := [false]
	await _until(func():
		sneaking14[0] = sneaking14[0] or i14.activity() == &"sneak"
		crouched14[0] = crouched14[0] or i14.crouched
		return i14.brain.done(), 900)
	_check("I14 go_to(sneak) arrives, crouched, showing \"sneak\"",
		i14.brain.done() and _flat(i14.global_position, goal14) < 0.9 and sneaking14[0] and crouched14[0],
		"done %s, %.2f m off, sneak shown %s, crouched %s" % [i14.brain.done(), _flat(i14.global_position, goal14), sneaking14[0], crouched14[0]])

	# I15 a knife in the back of a man who does not know he is there
	await _fresh()
	var g15 := _guard(&"", Vector3(40, 0, 20), 0.0)
	var i15 := _intruder(Vector3(40, 0, 26))
	await _frames(10)
	i15.brain.backstab(g15)
	# Held weakly: a knife in the back frees him, and a lambda holding him
	# outright would be handed null (an engine error).
	var held15: WeakRef = weakref(g15)
	await _until(func(): return held15.get_ref() == null or held15.get_ref()._knocked_out, 900)
	_check("I15 backstab kills an unaware guard from behind",
		not is_instance_valid(g15) or g15._knocked_out,
		"guard %s" % ("dead" if not is_instance_valid(g15) or g15._knocked_out else "alive, state %d" % g15.state))

	# I16 trading with a swordsman, he meets most blows that reach him
	await _fresh()
	_light(Vector3(60, 3, 20))
	var i16 := _intruder(Vector3(60, 0, 20))
	var g16 := _guard(&"swordsman", Vector3(60, 0, 17.5), 0.0)
	# (This is about his guard, not his blade: the swordsman lasts.)
	g16.max_health = 2000.0
	g16.health = 2000.0
	g16._fighter.posture_max = 1.0e6
	var met16 := [0]
	var came16 := [0]
	i16.combat.defended.connect(func(_r): met16[0] += 1)
	var through16 := []
	var reeling16 := [0]
	g16.caught_player.connect(func(_p):
		# Reeling (parried, booted) he can answer nothing: not counted.
		if i16._stagger > 0.0 or i16._knock > 0.0:
			reeling16[0] += 1
			return
		came16[0] += 1
		if not i16.combat.blocking:
			through16.append("%s(ph %d)" % [g16._attack, i16.combat.phase]))
	g16._engage(i16)
	i16.brain.fight(&"trade")
	await _frames(1200)
	_check("I16 in trade he meets most of a swordsman's blows that reach him while he can answer (20 s)",
		came16[0] >= 3 and float(met16[0]) >= 0.6 * float(came16[0]),
		"met %d of %d that reached him free to answer (%d more while reeling); unguarded: %s; the swordsman %s" % [met16[0], came16[0], reeling16[0], through16, "standing" if is_instance_valid(g16) else "dead"])

	# I17 pressing, he never cuts a man on his knees
	await _fresh()
	_light(Vector3(80, 3, 20))
	var i17 := _intruder(Vector3(80, 0, 20))
	# The beggar right in front of him, nearer than the man he fights: a cut
	# at the fighter would fall on him first if anything let it.
	var beggar := _guard(&"", Vector3(80.0, 0, 19.0), PI, &"craven")
	var fighter17 := _guard(&"", Vector3(80.6, 0, 18.4), 0.0)
	var cut_beggar := [0]
	var cut_fighter := [0]
	beggar.struck_by.connect(func(_r, _k, _d): cut_beggar[0] += 1)
	fighter17.struck_by.connect(func(_r, _k, _d): cut_fighter[0] += 1)
	fighter17._engage(i17)
	i17.brain.fight(&"press")
	for f in 600:
		if not is_instance_valid(beggar):
			break
		beggar._mercy.pleading = true
		beggar._mercy.kneeling = true
		# Kept a metre in front of him, in the way of any cut he makes.
		if f > 30:
			beggar.global_position = i17.global_position - i17.global_basis.z * 1.0
		await _frames(1)
	_check("I17 press never strikes a begging man, and does strike the man fighting",
		cut_beggar[0] == 0 and cut_fighter[0] > 0,
		"the beggar struck %d times, the fighter %d" % [cut_beggar[0], cut_fighter[0]])

	# I18 his wounds are nobody's: the world's sound is not dulled by them
	await _fresh()
	var i18 := _intruder(Vector3(100, 0, 20))
	var g18 := _guard(&"", Vector3(100, 0, 24), PI)
	await _frames(5)
	i18.take_damage(500.0, g18)
	g18.health = 30.0
	await _frames(2)
	_check("I18 his hurt muffles nothing (Sfx.health_of: him 1, a hurt man 0.3)",
		is_equal_approx(Sfx.health_of(i18), 1.0) and absf(Sfx.health_of(g18) - 0.3) < 0.01,
		"him %.2f at %.0f health, a guard at 30 of 100 %.2f" % [Sfx.health_of(i18), i18.health, Sfx.health_of(g18)])

	# I19 the show's slow motion, and a hit-stop inside it
	TimeFx.clear()
	TimeFx.set_base(0.5)
	var halved := Engine.time_scale
	TimeFx.hitstop(get_tree(), 0.1)
	var stopped := Engine.time_scale
	await _frames(30)
	var after := Engine.time_scale
	TimeFx.set_base(1.0)
	_check("I19 TimeFx.set_base(0.5) halves time, and a hit-stop under it gives back 0.5 after",
		is_equal_approx(halved, 0.5) and stopped < 0.1 and is_equal_approx(after, 0.5) and is_equal_approx(Engine.time_scale, 1.0),
		"base %.2f, in the stop %.3f, after %.2f, reset %.2f" % [halved, stopped, after, Engine.time_scale])

	# I20 fleeing, a man standing in the way of his route where he cannot go
	# round (a doorway): he cuts at him, and once the man gives way he runs on
	# (three men holding the barracks door once kept him there a minute and a
	# half, and the escape never came)
	await _fresh()
	var i20 := _intruder(Vector3(427, 0, 0))
	var g20 := _guard(&"", Vector3(430.3, 0, 0), PI * 0.5)
	await _frames(5)
	# (He stands his ground, and does nothing else.)
	g20.set_physics_process(false)
	var struck20 := [0]
	g20.struck_by.connect(func(_r, _k, _d): struck20[0] += 1)
	var route20: Array[Vector3] = [Vector3(433, 0, 0), Vector3(437, 0, 0)]
	i20.brain.flee_by(route20)
	await _until(func(): return struck20[0] > 0, 360)
	var cut20: bool = struck20[0] > 0

	if is_instance_valid(g20):
		g20.global_position = Vector3(430.3, 0, 12)

	await _until(func(): return _flat(i20.global_position, Vector3(437, 0, 0)) < 1.0, 480)
	var through20 := _flat(i20.global_position, Vector3(437, 0, 0)) < 1.0
	_check("I20 fleeing, a man standing in his way in a doorway: he cuts at him within 6 s, and runs on once the man gives way",
		cut20 and through20, "cut at him %s (%d), through %s, at %s" % [cut20, struck20[0], through20, i20.global_position])

	# I21 a doorway held by three men fighting him, one behind another (the
	# chase calls bring them all to him): he gets through (cut, then barged
	# down: a man still in his way after a cut or two goes over)
	await _fresh()
	var i21 := _intruder(Vector3(427, 0, 0))
	var held21: Array = [_guard(&"", Vector3(430.3, 0, 0), PI * 0.5), _guard(&"", Vector3(431.3, 0, 0.35), PI * 0.5), _guard(&"", Vector3(431.3, 0, -0.35), PI * 0.5)]
	await _frames(5)

	# (On him, fighting: they parry and strike back.)
	for g in held21:
		g._engage(i21)

	var route21: Array[Vector3] = [Vector3(433, 0, 0), Vector3(437, 0, 0)]
	i21.brain.flee_by(route21)
	await _until(func(): return _flat(i21.global_position, Vector3(437, 0, 0)) < 1.0, 900)
	var through21 := _flat(i21.global_position, Vector3(437, 0, 0)) < 1.0
	var downed21: int = held21.filter(func(g): return is_instance_valid(g) and g.is_downed()).size()
	_check("I21 a doorway held by three men fighting him, one behind another: he gets through within 15 s (cut, then barged down)",
		through21, "through %s at %s, men downed %d" % [through21, i21.global_position, downed21])

	# I22 a man in the doorway his cuts do not move (he stands and takes
	# them): he barges him off his feet and gets through
	await _fresh()
	var i22 := _intruder(Vector3(427, 0, 0))
	var g22 := _guard(&"", Vector3(430.3, 0, 0), PI * 0.5)
	await _frames(5)
	g22.set_physics_process(false)
	g22.max_health = 99999.0
	g22.health = 99999.0
	var route22: Array[Vector3] = [Vector3(433, 0, 0), Vector3(437, 0, 0)]
	i22.brain.flee_by(route22)
	await _until(func(): return _flat(i22.global_position, Vector3(437, 0, 0)) < 1.0, 600)
	var through22 := _flat(i22.global_position, Vector3(437, 0, 0)) < 1.0
	var downed22: bool = is_instance_valid(g22) and g22.is_downed()
	_check("I22 a man in the doorway his cuts do not move: barged off his feet, and he gets through within 10 s",
		through22 and downed22, "through %s at %s, the man downed %s" % [through22, i22.global_position, downed22])


func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


func _intruder(at: Vector3) -> CharacterBody3D:
	var i: CharacterBody3D = INTRUDER.instantiate()
	i.position = at
	add_child(i)
	return i


func _guard(archetype: StringName, at: Vector3, yaw := 0.0, preset: StringName = &"steady") -> CharacterBody3D:
	var g: CharacterBody3D = GUARD.instantiate()
	g.archetype = archetype
	g.temperament = preset
	g.position = at
	g.rotation.y = yaw
	add_child(g)
	_barks[g] = []
	g.barked.connect(func(t): _barks[g].append(t))
	return g


func _light(at: Vector3) -> void:
	var lamp := OmniLight3D.new()
	lamp.omni_range = 12.0
	lamp.light_energy = 3.0
	lamp.add_to_group(&"test_lights")
	add_child(lamp)
	lamp.global_position = at
	LightProbe.invalidate()


## A clean start: nobody left, nothing lying about, nothing remembered.
func _fresh() -> void:
	for group in [&"guards", &"player"]:
		for g in get_tree().get_nodes_in_group(group):
			g.remove_from_group(group)
			g.set_physics_process(false)
			g.queue_free()

	for group in [&"bodies", &"dropped_weapons", &"dropped_lights", &"test_lights", &"stray_arrows"]:
		for thing in get_tree().get_nodes_in_group(group):
			thing.queue_free()

	SquadScript.clear_all()
	GarrisonScript.clear_all()
	LightProbe.invalidate()
	await _frames(3)
	# The same fight every run: no man reseeds the dice as he is made.
	GuardScript.randomize_on = false
	seed(1926)


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
