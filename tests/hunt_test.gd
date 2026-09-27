extends Node3D
## Fighting as one mind (Squad.gd, Garrison.gd, Temperament.gd): the hunt
## outlives the men in it, the level remembers you and comes to dread you,
## and each man's temperament decides when he breaks, whether he presses too
## hard and whether he works round behind you. Broken men fetch help, and
## hunters split the search.

const PLAYER := preload("res://Player.tscn")
const GUARD := preload("res://Guard.tscn")
const Props := preload("res://scripts/Interaction/Props.gd")
const NavBakerScript := preload("res://scripts/AISystem/NavBaker.gd")
const SquadScript := preload("res://scripts/AISystem/Squad.gd")
const TemperamentScript := preload("res://scripts/AISystem/Temperament.gd")
const GarrisonScript := preload("res://scripts/AISystem/Garrison.gd")
const SoundBus := preload("res://scripts/StimuliSystem/SoundBus.gd")

var player: CharacterBody3D
var results: Array[String] = []


func _ready() -> void:
	# Everyone at his class's own temperament unless a check pins another.
	TemperamentScript.rolling = false
	# The checks sit side by side along x.
	Props.block(self, Vector3(260, -0.5, 5), Vector3(640, 1, 70))

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
	player.inventory.select_by_id(&"sword")

	await baker.baked
	await _frames(5)
	await _run()

	print("\n==== RESULTS ====")
	for r in results:
		print(r)
	get_tree().quit()


func _run() -> void:
	# H16a temperaments: presets, rolls, tags and lines
	var rash = TemperamentScript.roll(&"swordsman", &"rash")
	var presets_ok: bool = is_equal_approx(rash.nerve, 0.6) and is_equal_approx(rash.drive, 0.85) and is_equal_approx(rash.guile, 0.25) and rash.tag == &"rash" \
		and is_equal_approx(TemperamentScript.roll(&"duelist", &"stubborn").nerve, 0.98)
	TemperamentScript.rolling = true
	var lo := 1.0
	var hi := 0.0
	var within := true

	for i in 50:
		var t = TemperamentScript.roll(&"duelist")
		within = within and absf(t.nerve - 0.7) <= 0.2001 and absf(t.drive - 0.45) <= 0.2001 and absf(t.guile - 0.85) <= 0.2001
		lo = minf(lo, t.nerve)
		hi = maxf(hi, t.nerve)

	TemperamentScript.rolling = false
	var base = TemperamentScript.roll(&"duelist")
	var tags_ok: bool = base.tag == &"sly" and TemperamentScript.roll(&"archer").tag == &"craven" and TemperamentScript.roll(&"brute").tag == &"rash" \
		and TemperamentScript.roll(&"").tag == &"steady" and TemperamentScript.roll(&"swordsman").tag == &"steady"
	var line: String = TemperamentScript.roll(&"swordsman", &"stubborn").line(&"hold")
	var g := _guard(&"", Vector3(0, 0, 27), &"craven", false)
	await _frames(2)
	_check("H16a temperaments: presets exact, rolls within 0.2 of the class, tags, lines, and every guard has one",
		presets_ok and within and hi - lo > 0.1 and is_equal_approx(base.nerve, 0.7) and tags_ok
		and line in TemperamentScript.LINES[&"stubborn"][&"hold"] and g._fighter.temper != null and g._fighter.temper.tag == &"craven",
		"rash %.2f/%.2f/%.2f %s  rolls %.2f..%.2f  line '%s'" % [rash.nerve, rash.drive, rash.guile, rash.tag, lo, hi, line])
	g.queue_free()
	await _frames(5)

	# H16e a preset means what it says whatever his class: a rash watchman is
	#      rash (and goes all in), a craven swordmaster craven, a sly brute
	#      sly, a stubborn watchman stubborn (and never breaks)
	var rash_watch = TemperamentScript.roll(&"", &"rash")
	var craven_master = TemperamentScript.roll(&"duelist", &"craven")
	var sly_brute = TemperamentScript.roll(&"brute", &"sly")
	var stubborn_watch = TemperamentScript.roll(&"", &"stubborn")
	_check("H16e a preset means what it says, whatever the class",
		rash_watch.tag == &"rash" and rash_watch.drive >= SquadScript.DESPERATE_DRIVE and craven_master.tag == &"craven" and sly_brute.tag == &"sly"
		and stubborn_watch.tag == &"stubborn" and stubborn_watch.nerve >= SquadScript.UNBREAKABLE_NERVE,
		"rash watchman %s d%.2f, craven swordmaster %s, sly brute %s, stubborn watchman %s n%.2f" % [rash_watch.tag, rash_watch.drive, craven_master.tag, sly_brute.tag, stubborn_watch.tag, stubborn_watch.nerve])

	# H4 the garrison: habits build slowly and never fade; dread rises with
	#    their dead and fades once it has been quiet
	await _fresh()
	var garrison = GarrisonScript.of(player)
	garrison.learn({&"turtle": 0.9, &"spam": 0.0, &"kite": 0.0, &"bow": 0.0}, 20.0)
	var built: float = garrison.habits[&"turtle"]
	garrison.learn({&"turtle": 0.2, &"spam": 0.0, &"kite": 0.0, &"bow": 0.0}, 60.0)
	var kept: float = garrison.habits[&"turtle"]
	garrison.habits[&"turtle"] = 1.0
	garrison.advance(600.0)
	var forever: float = garrison.habits[&"turtle"]
	garrison.dread = 0.0
	garrison.on_death(false)
	garrison.on_death(true)
	garrison.on_gore()
	garrison.on_body_found()
	var added: float = garrison.dread
	garrison.advance(29.0)
	var held: float = garrison.dread
	garrison.advance(60.0)
	_check("H4 habits build slowly and never fade; dread rises with their dead and fades once it has been quiet",
		built > 0.5 and built < 0.65 and is_equal_approx(kept, built) and is_equal_approx(forever, 1.0)
		and is_equal_approx(added, 0.43) and garrison.dead == 2 and garrison.captains == 1
		and is_equal_approx(held, 0.43) and absf(garrison.dread - (0.43 - 0.1 * 59.0 / 60.0)) < 0.005
		and is_equal_approx(garrison.fear_of(0.25), garrison.dread * 0.75) and garrison.anger_of(0.6) == 0.0
		and is_equal_approx(garrison.opening_heart(), 1.0 - 0.3 * garrison.dread),
		"built %.2f kept %.2f dread %.2f -> %.2f -> %.3f" % [built, kept, added, held, garrison.dread])

	# H4b what the garrison knows stays in their hands all fight, whatever they
	#     have just seen
	var sq4 = SquadScript.of(player)
	sq4.read[&"turtle"] = 0.0
	sq4.tactic = &"envelop"
	_check("H4b a known turtle meets the boot all fight, even when they have not just seen it", sq4.bonus(&"kick") >= 0.2399,
		"kick bonus %.2f" % sq4.bonus(&"kick"))

	# H2 a lull does not wipe them
	await _fresh()
	_put_player(Vector3(20, 1.05, 0))
	var g1 := _guard(&"swordsman", Vector3(20, 0, -2.4))
	var g2 := _guard(&"swordsman", Vector3(22, 0, -2.8))
	await _frames(40)
	var squad = g1._fighter.squad
	squad.morale = 0.5
	squad.read[&"turtle"] = 0.8
	player.debug_light_level = 0.0

	for one in [g1, g2]:
		one._since_seen = 99.0
		one.alert = 70.0
		one._set_state(3)

	await _frames(30)
	var kept_members: int = squad.members().size()
	g1._engage(player)
	await _frames(10)
	_check("H2 a lull does not wipe them: both searching, one fights again, and it is the same mind",
		g1._fighter.squad == squad and kept_members == 2 and absf(squad.morale - 0.5) < 0.1 and float(squad.read[&"turtle"]) > 0.5
		and squad.largest == 2 and squad.fighting().size() >= 1,
		"same %s members %d heart %.2f turtle %.2f largest %d fighting %d" % [g1._fighter.squad == squad, kept_members, squad.morale, squad.read[&"turtle"], squad.largest, squad.fighting().size()])

	# H3 the last to give up ends the hunt; the next starts from what the
	#    garrison knows
	await _fresh()
	_put_player(Vector3(40, 1.05, 0))
	player.debug_light_level = 0.0
	var known = GarrisonScript.of(player)
	known.habits[&"turtle"] = 0.9
	known.dread = 0.5
	var h1 := _guard(&"swordsman", Vector3(40, 0, -2.4))
	var h2 := _guard(&"swordsman", Vector3(42, 0, -2.8))
	await _frames(30)
	var old = h1._fighter.squad
	h1._give_up()
	h2._give_up()
	await _frames(5)
	var dissolved: bool = SquadScript.of(player) != old and old.members().is_empty()
	var h3 := _guard(&"swordsman", Vector3(40, 0, -2.4))
	await _frames(30)
	var fresh = h3._fighter.squad
	_check("H3 when the last of them gives up the hunt ends; the next starts from what the garrison knows",
		dissolved and fresh != null and fresh != old and float(fresh.read[&"turtle"]) > 0.55 and absf(fresh.morale - 0.85) < 0.05 and fresh.tactic == &"break",
		"dissolved %s turtle %.2f heart %.2f plan %s" % [dissolved, fresh.read[&"turtle"] if fresh else -1.0, fresh.morale if fresh else -1.0, fresh.tactic if fresh else &""])

	# H3b freed without dying (the gym clearing a bay): dropped, and a new
	#     squad for the next fight
	await _fresh()
	var f1 := _guard(&"swordsman", Vector3(40, 0, -2.4))
	var f2 := _guard(&"swordsman", Vector3(42, 0, -2.8))
	await _frames(20)
	var freed_squad = f1._fighter.squad
	f1.queue_free()
	f2.queue_free()
	await _frames(3)
	_check("H3b men freed without dying are dropped, and the next fight gets a new squad",
		freed_squad.members().is_empty() and SquadScript.of(player) != freed_squad, "members %d" % freed_squad.members().size())

	# H3c a hunter knocked out: their heart drops, their dread does not rise
	await _fresh()
	_put_player(Vector3(40, 1.05, 0))
	player.debug_light_level = 0.0
	var k1 := _guard(&"swordsman", Vector3(40, 0, -2.4))
	var k2 := _guard(&"swordsman", Vector3(42, 0, -2.8))
	await _frames(20)
	var ksquad = k1._fighter.squad
	ksquad.morale = 0.8
	k2._since_seen = 99.0
	k2.alert = 70.0
	k2._set_state(3)
	await _frames(3)
	var dread_before: float = GarrisonScript.of(player).dread
	var out: bool = k2.knock_out(player, true)
	await _frames(3)
	_check("H3c a hunter knocked out leaves the hunt: their heart drops, their dread does not rise",
		out and not ksquad.members().has(k2) and absf(ksquad.morale - 0.6) < 0.05 and is_equal_approx(GarrisonScript.of(player).dread, dread_before),
		"heart %.2f dread %.2f -> %.2f" % [ksquad.morale, dread_before, GarrisonScript.of(player).dread])

	# H3d a freed target's garrison and squad are let go
	var gone := Node3D.new()
	add_child(gone)
	var gone_g = GarrisonScript.of(gone)
	var gone_s = SquadScript.of(gone)
	gone.free()
	var other := Node3D.new()
	add_child(other)
	GarrisonScript.of(other)
	SquadScript.of(other)
	_check("H3d a freed target's garrison and squad are let go", not GarrisonScript._garrisons.values().has(gone_g) and not SquadScript._squads.values().has(gone_s), "")
	other.queue_free()

	# H1 the last man is still the group
	await _fresh()
	_put_player(Vector3(0, 1.05, 0))
	var lead := _guard(&"duelist", Vector3(0, 0, -2.2))
	var a := _guard(&"swordsman", Vector3(-1.8, 0, -2.6))
	var c := _guard(&"swordsman", Vector3(1.8, 0, -2.6), &"craven")
	await _frames(40)
	var s1 = c._fighter.squad
	lead.die(null)
	a.die(null)
	await _think(s1)
	await _frames(660)
	_check("H1 the last man keeps the group's mind: 11 s after his captain fell the craven one is still away, not in a fresh fight",
		c._fighter.squad == s1 and s1.largest == 3 and s1.will_of(c) == &"broken" and s1.role_of(c) == &"flee" and c.global_position.distance_to(player.global_position) > 8.0,
		"will %s place %s heart %.2f at %.1f m" % [s1.will_of(c), s1.role_of(c), s1.morale, c.global_position.distance_to(player.global_position)])

	# H5 they break one by one
	await _fresh()
	_put_player(Vector3(60, 1.05, 0))
	var stub := _guard(&"swordsman", Vector3(60, 0, -2.4), &"stubborn")
	var mid := _guard(&"swordsman", Vector3(58.2, 0, -2.8))
	var crav := _guard(&"swordsman", Vector3(61.8, 0, -2.8), &"craven")
	await _frames(40)
	var s5 = stub._fighter.squad
	s5.morale = 0.15
	await _think(s5)
	var first := [s5.will_of(crav), s5.will_of(mid), s5.will_of(stub)]
	s5.morale = 0.0
	await _think(s5)
	_check("H5 they break one by one: the craven first, then the steady; the stubborn man holds",
		first[0] == &"broken" and first[1] != &"broken" and first[2] != &"broken"
		and s5.will_of(mid) == &"broken" and s5.will_of(stub) != &"broken" and s5.role_of(stub) == &"hold" and s5.tactic == &"rout",
		"%s then %s/%s %s plan %s" % [first, s5.will_of(mid), s5.will_of(stub), s5.role_of(stub), s5.tactic])

	# H6 a rash man breaks into an all-in charge
	await _fresh()
	_put_player(Vector3(80, 1.05, 0))
	var r := _guard(&"swordsman", Vector3(80, 0, -2.4), &"rash")
	var s := _guard(&"swordsman", Vector3(82, 0, -2.8))
	await _frames(40)
	var s6 = r._fighter.squad
	s.die(null)
	s6.morale = 0.0
	await _think(s6)
	await _frames(20)
	_check("H6 a rash man who breaks goes all in, not away",
		s6.will_of(r) == &"broken" and s6.role_of(r) == &"desperate" and r._fighter.mood == &"desperate" and r.global_position.distance_to(player.global_position) < 4.0,
		"will %s place %s mood %s" % [s6.will_of(r), s6.role_of(r), r._fighter.mood])

	# H8 the most cunning flanker goes behind you
	await _fresh()
	_put_player(Vector3(100, 1.05, 0))
	var front := _guard(&"swordsman", Vector3(100, 0, -2.0))
	var sly := _guard(&"swordsman", Vector3(98.5, 0, -3.5), &"sly")
	var plain := _guard(&"swordsman", Vector3(101.5, 0, -3.5))
	await _frames(40)
	var s8 = front._fighter.squad
	_check("H8 the most cunning flanker takes the place behind you",
		s8.role_of(front) == &"engage" and s8.role_of(sly) == &"flank" and is_equal_approx(s8.slot_angle(sly), 170.0) and is_equal_approx(absf(s8.slot_angle(plain)), 100.0),
		"front %s sly %s at %.0f plain at %.0f" % [s8.role_of(front), s8.role_of(sly), s8.slot_angle(sly), s8.slot_angle(plain)])

	# H12 with nobody to fetch he flees, and comes back when their heart returns
	await _fresh()
	_put_player(Vector3(120, 1.05, 0))
	var holder := _guard(&"swordsman", Vector3(120, 0, -2.4), &"stubborn")
	var runner := _guard(&"swordsman", Vector3(122, 0, -2.8), &"craven")
	await _frames(40)
	var s12 = holder._fighter.squad
	s12.morale = 0.1
	await _think(s12)
	await _frames(90)
	var fled: bool = s12.role_of(runner) == &"flee" and runner.global_position.distance_to(player.global_position) > 5.0
	s12.morale = 0.95
	await _think(s12)
	await _frames(150)
	_check("H12 with nobody to fetch he flees, and comes back when their heart returns",
		fled and s12.will_of(runner) != &"broken" and s12.role_of(runner) != &"flee" and runner.global_position.distance_to(player.global_position) < 5.0,
		"fled %s then %s/%s at %.1f m" % [fled, s12.will_of(runner), s12.role_of(runner), runner.global_position.distance_to(player.global_position)])

	# H15a a timid man alone will not face you
	await _fresh()
	_put_player(Vector3(140, 1.05, 0))
	GarrisonScript.of(player).dread = 0.5
	var t := _guard(&"", Vector3(140, 0, -3.0), &"steady", false)
	var hold_lines := [0]
	t.barked.connect(func(text): hold_lines[0] += 1 if text in TemperamentScript.LINES[&"steady"][&"hold"] else 0)
	t._engage(player)
	t._attack_timer = 0.0
	t.attack_cooldown = 1.1
	var swung := false
	for i in 240:
		swung = swung or t._phase != &""
		await _frames(1)
	var s15 = t._fighter.squad
	_check("H15a a timid man alone will not face you: he holds off out of reach, calling for help",
		s15.role_of(t) == &"hold" and t.global_position.distance_to(player.global_position) > 3.2 and not swung and hold_lines[0] >= 1,
		"place %s at %.1f m swung %s calls %d" % [s15.role_of(t), t.global_position.distance_to(player.global_position), swung, hold_lines[0]])

	# H7 a rash flanker loses patience; a sly one waits for you to commit,
	# longer, though not for ever
	await _fresh()
	_put_player(Vector3(160, 1.05, 0))
	var f7 := _guard(&"swordsman", Vector3(160, 0, -2.0))
	var rash7 := _guard(&"swordsman", Vector3(158.5, 0, -3.5), &"rash")
	var sly7 := _guard(&"swordsman", Vector3(161.5, 0, -3.5), &"sly")
	await _frames(40)
	_aim(f7.global_position + Vector3.UP * 1.2)
	var s7 = f7._fighter.squad
	var p_rash: float = s7.patience_of(rash7)
	var expected := lerpf(4.0, 1.0, (0.85 - 0.65) / 0.35)
	rash7._fighter._flank_waited = p_rash + 0.1
	sly7._fighter._flank_waited = p_rash + 0.1
	var sly_waits: bool = not s7.may_strike(sly7)
	sly7._fighter._flank_waited = s7.patience_of(sly7) + 0.1
	var sly_goes: bool = s7.may_strike(sly7)
	sly7._fighter._flank_waited = 0.0
	_check("H7 a rash flanker loses patience and goes in out of turn; a sly one waits for you to commit, longer, though not for ever",
		s7.role_of(rash7) == &"flank" and absf(p_rash - expected) < 0.01 and s7.patience_of(sly7) >= 7.0 and s7.may_strike(rash7) and sly_waits and sly_goes,
		"patience %.2f (want %.2f) sly %.1f: waits %s, goes in after %s" % [p_rash, expected, s7.patience_of(sly7), sly_waits, sly_goes])

	# H7b ...and he really swings while you stand watching the man in front
	rash7._fighter._flank_waited = 0.0
	rash7._attack_timer = 0.0
	rash7.attack_cooldown = 1.0
	var went := false
	for i in 480:
		if rash7._phase != &"":
			went = true
			break
		await _frames(1)
	_check("H7b the rash flanker swings while you stand idle facing another", went and not player.combat.blocking, "swung %s" % went)

	# H9 the leader's hold
	await _fresh()
	_put_player(Vector3(180, 1.05, 0))
	var lead9 := _guard(&"duelist", Vector3(180, 0, -2.0))
	var rash9 := _guard(&"swordsman", Vector3(178.5, 0, -3.5), &"rash")
	var other9 := _guard(&"swordsman", Vector3(181.5, 0, -3.5))
	await _frames(40)
	var s9 = lead9._fighter.squad
	var held_before: bool = s9.held(rash9)
	var p_held: float = s9.patience_of(rash9)
	lead9.die(null)
	await _think(s9)
	_check("H9 while the captain stands they keep their places; with him dead the rash one is twice as quick to go in",
		held_before and not s9.held(rash9) and absf(p_held - 2.0 * s9.patience_of(rash9)) < 0.01,
		"held %s -> %s patience %.2f -> %.2f" % [held_before, s9.held(rash9), p_held, s9.patience_of(rash9)])

	# H15b dread makes a bold man angry
	await _fresh()
	GarrisonScript.of(player).dread = 0.8
	var bold := _guard(&"swordsman", Vector3(200, 0, -2.4), &"stubborn")
	await _frames(10)
	_check("H15b dread makes a bold man angry: he presses harder", bold._fighter.drive_now() > bold._fighter.temper.drive + 0.2,
		"drive %.2f -> %.2f" % [bold._fighter.temper.drive, bold._fighter.drive_now()])

	# H16b the class average fights as his archetype; a rash man rests and guards less
	await _fresh()
	var avg := _guard(&"swordsman", Vector3(210, 0, -2.4))
	var hot := _guard(&"swordsman", Vector3(214, 0, -2.4), &"rash")
	await _frames(10)
	_check("H16b a class-average man fights as his archetype; a rash one rests and guards less",
		is_equal_approx(avg._fighter._cooldown_scale(), 1.0) and avg._fighter._guard_bias() == 0.0 and is_equal_approx(avg._fighter._step_factor(), 1.0)
		and hot._fighter._cooldown_scale() < 0.9 and hot._fighter._guard_bias() < -0.1,
		"avg x%.2f hot x%.2f bias %.2f" % [avg._fighter._cooldown_scale(), hot._fighter._cooldown_scale(), hot._fighter._guard_bias()])

	# H10 a man who breaks runs for help, and the man he fetches joins knowing where you were
	await _fresh()
	_put_player(Vector3(240, 1.05, 0))
	var helper := _guard(&"", Vector3(240, 0, -26), &"steady", false)
	helper.hearing_acuity = 0.1
	var stub10 := _guard(&"swordsman", Vector3(240, 0, -2.4), &"stubborn")
	var crav10 := _guard(&"swordsman", Vector3(242, 0, -2.8), &"craven")
	await _frames(40)
	player.debug_light_level = 0.0
	var s10 = stub10._fighter.squad
	var resting: bool = helper.state == 0
	s10.morale = 0.15
	await _think(s10)
	await _frames(10)
	var running: bool = s10.role_of(crav10) == &"fetch" and s10.helper_of(crav10) == helper
	await _frames(60)
	helper.global_position += Vector3(6, 0, 0)      # he moves while being fetched
	var roused := false
	for i in 720:
		if s10.members().has(helper):
			roused = true
			break
		await _frames(1)
	await _frames(5)
	_check("H10 a man who breaks runs for help (even as the man moves), and the man he fetches joins knowing where you were",
		resting and running and roused and helper.state >= 2 and helper.last_known_position.distance_to(player.global_position) < 2.5 and s10.help_coming(),
		"resting %s running %s roused %s state %d knows %.1f m off help %s" % [resting, running, roused, helper.state, helper.last_known_position.distance_to(player.global_position), s10.help_coming()])

	# H10b half of them down: the captain sends a man for help
	await _fresh()
	_put_player(Vector3(280, 1.05, 0))
	var helper_b := _guard(&"", Vector3(280, 0, -26), &"steady", false)
	helper_b.hearing_acuity = 0.1
	var cap := _guard(&"duelist", Vector3(280, 0, -2.2))
	var man := _guard(&"swordsman", Vector3(278.5, 0, -3.0))
	var d1 := _guard(&"swordsman", Vector3(281.5, 0, -3.0))
	var d2 := _guard(&"swordsman", Vector3(282.5, 0, -4.0))
	await _frames(40)
	player.debug_light_level = 0.0
	var sb = cap._fighter.squad
	d1.die(null)
	d2.die(null)
	await _think(sb)
	await _frames(10)
	_check("H10b with half of them down they fall back, and the captain sends a man for help",
		sb.tactic == &"fall_back" and sb.role_of(man) == &"fetch" and sb.helper_of(man) == helper_b, "plan %s man %s" % [sb.tactic, sb.role_of(man)])

	# H10c an archer who breaks runs for help on foot
	await _fresh()
	_put_player(Vector3(320, 1.05, 0))
	var helper_c := _guard(&"", Vector3(320, 0, -26), &"steady", false)
	helper_c.hearing_acuity = 0.1
	var stub_c := _guard(&"swordsman", Vector3(320, 0, -2.4), &"stubborn")
	var archer_c := _guard(&"archer", Vector3(322, 0, -9.0))
	await _frames(40)
	player.debug_light_level = 0.0
	var sc = stub_c._fighter.squad
	var gap_before: float = archer_c.global_position.distance_to(helper_c.global_position)
	sc.morale = 0.1
	await _think(sc)
	await _frames(60)
	_check("H10c an archer who breaks runs for help instead of keeping his distance",
		sc.role_of(archer_c) == &"fetch" and archer_c.global_position.distance_to(helper_c.global_position) < gap_before - 2.0,
		"place %s gap %.1f -> %.1f" % [sc.role_of(archer_c), gap_before, archer_c.global_position.distance_to(helper_c.global_position)])

	# H11 kill the runner before he gets there and nobody comes
	await _fresh()
	_put_player(Vector3(360, 1.05, 0))
	var helper11 := _guard(&"", Vector3(360, 0, -26), &"steady", false)
	helper11.hearing_acuity = 0.1
	var stub11 := _guard(&"swordsman", Vector3(360, 0, -2.4), &"stubborn")
	var crav11 := _guard(&"swordsman", Vector3(362, 0, -2.8), &"craven")
	await _frames(40)
	player.debug_light_level = 0.0
	var s11 = stub11._fighter.squad
	s11.morale = 0.15
	await _think(s11)
	await _frames(30)
	var was_running: bool = s11.role_of(crav11) == &"fetch"
	crav11.die(null)
	await _frames(480)
	_check("H11 kill the runner before he gets there and nobody comes", was_running and helper11.state == 0 and not s11.members().has(helper11),
		"was running %s helper state %d" % [was_running, helper11.state])

	# H13 they split the search
	await _fresh()
	_put_player(Vector3(400, 1.05, 0))
	var sly13 := _guard(&"swordsman", Vector3(400, 0, -2.4), &"sly")
	var a13 := _guard(&"swordsman", Vector3(402, 0, -2.8))
	var b13 := _guard(&"swordsman", Vector3(398, 0, -2.8))
	await _frames(30)
	var s13 = sly13._fighter.squad
	var at := Vector3(400, 0, 0)
	s13.last_sighting = {"position": at, "time": s13.clock, "velocity": Vector3(4, 0, 0)}
	for one in [sly13, a13, b13]:
		one.last_known_position = at
		one.has_last_known = true
	var pa: Variant = s13.search_point_for(a13)
	var pb: Variant = s13.search_point_for(b13)
	var ps: Variant = s13.search_point_for(sly13)
	var spread_ok: bool = pa is Vector3 and pb is Vector3 and Vector2(pa.x - pb.x, pa.z - pb.z).length() >= 4.0
	var lean_ok: bool = spread_ok and (pa - at).normalized().dot(Vector3.RIGHT) > 0.0 and (pb - at).normalized().dot(Vector3.RIGHT) > 0.0
	var cut_ok: bool = ps is Vector3 and Vector2(ps.x - (at.x + 10.0), ps.z - at.z).length() < 3.0
	_check("H13 they split the search: points apart, leaning the way you ran; the sly one cuts you off ahead", spread_ok and lean_ok and cut_ok,
		"a %s b %s sly %s" % [pa, pb, ps])

	# H13b ...every time: over many tries both hunters search ahead of where
	#      you ran, and apart
	var always := true
	var worst := 1.0

	for trial in 20:
		s13._claims.clear()
		var qa: Variant = s13.search_point_for(a13)
		var qb: Variant = s13.search_point_for(b13)

		if not (qa is Vector3 and qb is Vector3):
			always = false
			break

		var la: float = (qa - at).normalized().dot(Vector3.RIGHT)
		var lb: float = (qb - at).normalized().dot(Vector3.RIGHT)
		worst = minf(worst, minf(la, lb))
		always = always and la > 0.0 and lb > 0.0 and Vector2(qa.x - qb.x, qa.z - qb.z).length() >= 4.0

	_check("H13b every time, both hunters search ahead of where you ran, and apart", always, "worst lean %.2f" % worst)

	# H14 whoever finds you calls the hunters near enough
	await _fresh()
	_put_player(Vector3(440, 1.05, 0))
	player.debug_light_level = 0.0
	var finder := _guard(&"swordsman", Vector3(440, 0, -2.4))
	var near := _guard(&"swordsman", Vector3(450, 0, 0))
	var far := _guard(&"swordsman", Vector3(485, 0, 0))
	for one in [near, far]:
		one.hearing_acuity = 0.05
	await _frames(20)
	for one in [finder, near, far]:
		one._since_seen = 99.0
		one.alert = 70.0
		one._set_state(3)
	await _frames(20)
	# Each thinks you are somewhere near himself: only the call can tell him.
	near.last_known_position = near.global_position
	far.last_known_position = far.global_position
	var far_before: Vector3 = far.last_known_position
	finder._engage(player)
	await _frames(5)
	_check("H14 whoever finds you calls the hunters near enough, and they come",
		near.last_known_position.distance_to(player.global_position) < 1.5 and near._since_stimulus < 0.3 and far.last_known_position.distance_to(far_before) < 0.01,
		"near knows %.1f m off, far moved %.2f m" % [near.last_known_position.distance_to(player.global_position), far.last_known_position.distance_to(far_before)])

	# H15c the bold man's first words are about their dead
	await _fresh()
	GarrisonScript.of(player).dread = 0.8
	var said := [""]
	var vengeful := _guard(&"swordsman", Vector3(480, 0, -2.4), &"stubborn", false)
	vengeful.barked.connect(func(text): if said[0] == "": said[0] = text)
	vengeful._engage(player)
	await _frames(3)
	_check("H15c a bold man's first words, with their dead on his mind, are revenge", said[0] in TemperamentScript.LINES[&"stubborn"][&"revenge"], "'%s'" % said[0])

	# H15d "For the captain!" only once a captain has fallen
	var bold_t = TemperamentScript.roll(&"swordsman", &"stubborn")
	var no_captain := true
	var for_captain := 0

	for i in 40:
		no_captain = no_captain and bold_t.revenge_line(0) != TemperamentScript.CAPTAIN_LINE
		for_captain += 1 if bold_t.revenge_line(1) == TemperamentScript.CAPTAIN_LINE else 0

	_check("H15d they swear by their captain only once one has fallen", no_captain and for_captain > 5 and for_captain < 35, "with a captain dead %d/40" % for_captain)

	# H16c each shows what he is
	await _fresh()
	_put_player(Vector3(520, 1.05, 0))
	var r16 := _guard(&"swordsman", Vector3(518, 0, -2.4), &"rash")
	var c16 := _guard(&"swordsman", Vector3(520, 0, -2.4), &"craven")
	var s16 := _guard(&"swordsman", Vector3(522, 0, -2.4), &"sly")
	var glanced := false
	for i in 300:
		glanced = glanced or absf(c16._rig._glance) > 0.3
		await _frames(1)
	_check("H16c each shows what he is: the rash man leans in, the craven one leans back and looks over his shoulder, the sly one crouches",
		r16._rig.stance_lean() < -0.05 and c16._rig.stance_lean() > 0.04 and s16._rig.stance_crouch() < -0.03 and glanced,
		"lean %.2f/%.2f crouch %.2f glanced %s" % [r16._rig.stance_lean(), c16._rig.stance_lean(), s16._rig.stance_crouch(), glanced])

	# H8b two flankers alike keep their sides: no swapping every think
	await _fresh()
	_put_player(Vector3(100, 1.05, 0))
	var f8b := _guard(&"swordsman", Vector3(100, 0, -2.0))
	var p1 := _guard(&"swordsman", Vector3(98.5, 0, -3.5))
	var p2 := _guard(&"swordsman", Vector3(101.5, 0, -3.5))
	await _frames(40)
	var s8b = f8b._fighter.squad
	var swaps := 0
	var sides := [s8b.slot_angle(p1), s8b.slot_angle(p2)]

	for i in 30:
		await _frames(18)
		var now_sides := [s8b.slot_angle(p1), s8b.slot_angle(p2)]

		if now_sides != sides:
			swaps += 1

		sides = now_sides

	_check("H8b two flankers alike keep their sides", swaps == 0 and s8b.role_of(p1) == &"flank" and s8b.role_of(p2) == &"flank",
		"swaps %d, %s/%s" % [swaps, s8b.role_of(p1), s8b.role_of(p2)])

	# H2b a lull is not a loss: hunters coming back one at a time do not fall
	#     back (nobody is down)
	await _fresh()
	_put_player(Vector3(540, 1.05, 0))
	player.debug_light_level = 0.0
	var lulled: Array = []

	for spot in [Vector3(540, 0, -2.4), Vector3(542, 0, -2.8), Vector3(538, 0, -2.8), Vector3(541, 0, -4.0)]:
		lulled.append(_guard(&"swordsman", spot))

	await _frames(30)
	var sl = lulled[0]._fighter.squad

	for one in lulled:
		one._since_seen = 99.0
		one.alert = 70.0
		one._set_state(3)

	await _frames(20)
	lulled[0]._engage(player)
	await _think(sl)
	await _frames(10)
	var first_back: StringName = sl.tactic
	lulled[1]._engage(player)
	await _think(sl)
	await _frames(10)
	_check("H2b a lull is not a loss: hunters coming back one at a time do not fall back", sl.largest == 4 and first_back != &"fall_back" and sl.tactic != &"fall_back",
		"largest %d plans %s then %s" % [sl.largest, first_back, sl.tactic])

	# H12b a man who left the hunt and comes back is judged afresh (not still
	#      broken), and his coming back is help arriving
	await _fresh()
	_put_player(Vector3(520, 1.05, 0))
	var anchor := _guard(&"swordsman", Vector3(520, 0, -2.4), &"stubborn")
	var returner := _guard(&"swordsman", Vector3(522, 0, -2.8), &"craven")
	await _frames(40)
	var sr = anchor._fighter.squad
	sr.morale = 0.1
	await _think(sr)
	var broke: bool = sr.will_of(returner) == &"broken"
	# Gone back to his post, where he cannot see you: back only when brought.
	player.debug_light_level = 0.0
	returner._give_up()
	await _frames(240)
	sr.morale = 0.55
	returner._engage(player)
	await _frames(5)
	await _think(sr)
	_check("H12b a man back in the hunt is judged afresh, and counts as help arriving", broke and returner._fighter.squad == sr and sr.will_of(returner) != &"broken" and sr.morale > 0.65,
		"broke %s then %s, heart %.2f" % [broke, sr.will_of(returner), sr.morale])

	# H10d one errand: a runner still broken after fetching one man keeps
	#      running; he does not go on to rouse the next
	await _fresh()
	_put_player(Vector3(300, 1.05, 0))
	var first_help := _guard(&"", Vector3(300, 0, -26), &"steady", false)
	var second_help := _guard(&"", Vector3(328, 0, -26), &"steady", false)

	for one in [first_help, second_help]:
		one.hearing_acuity = 0.1

	var stay := _guard(&"swordsman", Vector3(300, 0, -2.4), &"stubborn")
	var errand := _guard(&"swordsman", Vector3(302, 0, -2.8), &"craven")
	await _frames(40)
	player.debug_light_level = 0.0
	var se = stay._fighter.squad
	se.morale = 0.15
	await _think(se)
	var fetched_first := false

	for i in 720:
		if se.members().has(first_help):
			fetched_first = true
			break

		await _frames(1)

	await _frames(60)
	_check("H10d one errand each: still broken after fetching one man, he runs; the next man is left be",
		fetched_first and se.will_of(errand) == &"broken" and se.role_of(errand) == &"flee" and second_help.state == 0,
		"fetched %s, then %s/%s, the next man's state %d" % [fetched_first, se.will_of(errand), se.role_of(errand), second_help.state])

	# H11b a runner who cannot get to the man gives it up and gets away
	#      instead: nobody frozen, shouting, for the rest of the hunt
	await _fresh()
	_put_player(Vector3(500, 1.05, 0))
	Props.block(self, Vector3(500, 1.5, -25), Vector3(4, 3, 4))
	var perched := _guard(&"", Vector3(500, 0, -20), &"steady", false)
	perched.hearing_acuity = 0.1
	var stay_b := _guard(&"swordsman", Vector3(500, 0, -2.4), &"stubborn")
	var stuck := _guard(&"swordsman", Vector3(502, 0, -2.8), &"craven")
	await _frames(40)
	player.debug_light_level = 0.0
	var sb2 = stay_b._fighter.squad
	sb2.morale = 0.15
	await _think(sb2)
	await _frames(10)
	var set_off: bool = sb2.role_of(stuck) == &"fetch"
	# Up where no path goes (a block laid down after the navmesh was baked).
	perched.global_position = Vector3(500, 3.05, -25)
	perched._home.origin = Vector3(500, 3.05, -25)
	await _frames(600)
	_check("H11b a runner who cannot reach the man gives it up and runs instead", set_off and sb2.role_of(stuck) == &"flee" and sb2.helper_of(stuck) == null,
		"set off %s, then %s" % [set_off, sb2.role_of(stuck)])

	# H10e a broken man does not run past you for help: the only man there is
	#      beyond you, so he runs instead
	await _fresh()
	_put_player(Vector3(560, 1.05, 0))
	var beyond := _guard(&"", Vector3(560, 0, 24), &"steady", false, PI)
	beyond.hearing_acuity = 0.1
	var stay_e := _guard(&"swordsman", Vector3(560, 0, -2.4), &"stubborn")
	var crav_e := _guard(&"swordsman", Vector3(562, 0, -2.8), &"craven")
	await _frames(40)
	player.debug_light_level = 0.0
	var se2 = stay_e._fighter.squad
	se2.morale = 0.15
	await _think(se2)
	await _frames(10)
	_check("H10e a broken man does not run past you for help: with the only man beyond you, he runs instead",
		se2.will_of(crav_e) == &"broken" and se2.role_of(crav_e) == &"flee" and se2.helper_of(crav_e) == null and beyond.state == 0,
		"will %s place %s fetching %s, the man beyond %d" % [se2.will_of(crav_e), se2.role_of(crav_e), se2.helper_of(crav_e), beyond.state])

	await _chase_checks()


## Chasing: on after you when you are lost running, to fresh word of you at a
## run, called to a fight at a run, one watch for each place you were last
## seen, told where you are only when it helps, and never your back to a man
## behind you.
func _chase_checks() -> void:
	# H17 lost on the run: the search starts by running on the way you went,
	#     as far as you could have got, not by standing where you were last
	#     seen
	await _fresh()
	_put_player(Vector3(200, 1.05, 0))
	var tracker := _guard(&"swordsman", Vector3(200, 0, 6))
	await _frames(30)
	player.debug_light_level = 0.0
	_put_player(Vector3(200, 1.05, -28))
	var s17 = tracker._fighter.squad
	# Last had at (200, 0, 0), going west at a run, as long ago as he takes
	# to give you up for lost (Guard.lose_time).
	s17.last_sighting = {"position": Vector3(200, 0, 0), "time": s17.clock - tracker.lose_time, "velocity": Vector3(-6, 0, 0)}
	tracker.last_known_position = Vector3(200, 0, 0)
	tracker.has_last_known = true
	tracker._seen_heading = Vector3(-6, 0, 0)
	tracker._since_seen = tracker.lose_time + 0.1
	tracker._since_stimulus = tracker.lose_time + 0.1
	tracker.alert = 70.0
	tracker._set_state(3)
	var trailing: bool = tracker._trailing
	var trail_to: Vector3 = tracker._agent.target_position
	var fastest := 0.0

	for i in 150:
		await _frames(1)
		fastest = maxf(fastest, Vector2(tracker.velocity.x, tracker.velocity.z).length())

	_check("H17 lost on the run, he runs on the way you went, as far as you could have got, not stood where you were last seen",
		trailing and trail_to.x < 190.0 and tracker.global_position.x < 192.0 and fastest > tracker.investigate_speed + 0.8,
		"on the trail %s to x %.1f, now at x %.1f, fastest %.1f m/s" % [trailing, trail_to.x, tracker.global_position.x, fastest])

	# H18 searching, word of you breaks off his look: he goes to it at a run,
	#     and does not give up while it keeps coming
	await _fresh()
	_put_player(Vector3(220, 1.05, -28))
	player.debug_light_level = 0.0
	var searcher := _guard(&"", Vector3(220, 0, 0), &"steady", false)
	await _frames(10)
	searcher.last_known_position = Vector3(220, 0, 0)
	searcher.has_last_known = true
	searcher.alert = 70.0
	searcher._set_state(3)
	await _frames(5)
	searcher._search_left = 1
	searcher._start_looking()
	var was_looking: bool = searcher._look_timer > 0.0
	SoundBus.emit_sound(Vector3(226, 0, 9), 62.0, self, &"test")
	await _frames(3)
	var broke_off: bool = searcher._look_timer <= 0.0
	var quickest := 0.0

	for i in 60:
		await _frames(1)
		quickest = maxf(quickest, Vector2(searcher.velocity.x, searcher.velocity.z).length())

	_check("H18 searching, a sound of you breaks off his look: he goes to it at a run, and keeps at the search",
		was_looking and broke_off and quickest > searcher.investigate_speed + 0.8 and searcher._search_left >= 2 and int(searcher.state) == 3,
		"looking %s broke off %s fastest %.1f m/s, places left %d, state %d" % [was_looking, broke_off, quickest, searcher._search_left, int(searcher.state)])

	# H19 called to a fight he runs; stirred by a noise he walks to look
	await _fresh()
	_put_player(Vector3(260, 1.05, -28))
	player.debug_light_level = 0.0
	var called := _guard(&"", Vector3(256, 0, 0), &"steady", false)
	var stirred := _guard(&"", Vector3(264, 0, 0), &"steady", false)
	await _frames(10)
	called.hear_call(Vector3(256, 0, 16))
	stirred.last_known_position = Vector3(264, 0, 16)
	stirred.has_last_known = true
	stirred._stimulus = &"noise"
	stirred._since_stimulus = 0.0
	stirred.alert = 50.0
	var runs := 0.0
	var walks := 0.0

	for i in 90:
		await _frames(1)
		runs = maxf(runs, Vector2(called.velocity.x, called.velocity.z).length())
		walks = maxf(walks, Vector2(stirred.velocity.x, stirred.velocity.z).length())

	_check("H19 called to a fight he runs; stirred by a noise he walks to look",
		int(called.state) == 2 and int(stirred.state) == 2 and runs > called.investigate_speed + 0.8 and walks < stirred.investigate_speed + 0.3,
		"states %d/%d, the called man %.1f m/s, the stirred one %.1f m/s" % [int(called.state), int(stirred.state), runs, walks])

	# H20 the hunt's watcher keeps one watch for each place you were last
	#     seen: his time up, he searches with the rest, nobody is set to watch
	#     that place over again, and nobody says so again
	await _fresh()
	_put_player(Vector3(340, 1.05, 0))
	var hunters20 := []

	for spot in [Vector3(340, 0, -3), Vector3(342, 0, -3.5), Vector3(338, 0, -3.5)]:
		hunters20.append(_guard(&"swordsman", spot))

	var watch_lines := [0]

	for one in hunters20:
		one.barked.connect(func(t: String) -> void:
			if t in TemperamentScript.LINES.get(one._fighter.temper.tag, {}).get(&"watch", []) or t in TemperamentScript.MORE_LINES.get(one._fighter.temper.tag, {}).get(&"watch", []):
				watch_lines[0] += 1)

	await _frames(30)
	var s20 = hunters20[0]._fighter.squad
	player.debug_light_level = 0.0
	_put_player(Vector3(340, 1.05, -28))

	for one in hunters20:
		one._since_seen = 99.0
		one.alert = 70.0
		one._set_state(3)

	await _frames(10)
	var first_watcher: Node3D = s20.watcher()
	s20._watch_until = s20.clock - 1.0

	for one in hunters20:
		one._look_timer = 0.0
		one._next_search_point()

	await _frames(10)
	var watching_after := hunters20.filter(func(one): return one._watching).size()
	_check("H20 the hunt's watcher keeps one watch for each place you were last seen, and says so once",
		first_watcher != null and s20.watcher() == null and watching_after == 0 and watch_lines[0] <= 1,
		"watcher %s, after his time %s, watching %d, said so %d times" % [first_watcher != null, s20.watcher() != null, watching_after, watch_lines[0]])

	# H21 where you are is called to those who would come to it, not to a man
	#     fighting at your side who lost you a moment
	await _fresh()
	_put_player(Vector3(420, 1.05, 0))
	var caller := _guard(&"swordsman", Vector3(420, 0, -2.4))
	var beside := _guard(&"swordsman", Vector3(422.5, 0, 0.5))
	await _frames(30)
	var s21 = caller._fighter.squad
	beside.can_see_target = false
	beside._since_seen = 3.0
	beside._since_heard_of = 3.0
	caller._fighter._spot_timer = 0.0
	s21._last_spot_call = -100.0
	caller._fighter._call_out_where(0.1, player)
	var told_beside: bool = s21._last_spot_call > -100.0
	beside.global_position = Vector3(420, 0, 24)
	beside.alert = 70.0
	beside._set_state(3)
	beside.can_see_target = false
	beside._since_seen = 3.0
	beside._since_heard_of = 3.0
	caller._fighter._spot_timer = 0.0
	s21._last_spot_call = -100.0
	caller._fighter._call_out_where(0.1, player)
	var told_far: bool = s21._last_spot_call > -100.0
	_check("H21 where you are is called to a man off searching, not to one fighting at your side",
		not told_beside and told_far, "told the man beside you %s, the man searching %s" % [told_beside, told_far])

	# H22 a man at your back strikes, busy or not; at your side he waits for
	#     his moment
	await _fresh()
	_put_player(Vector3(460, 1.05, 0))
	var front22 := _guard(&"swordsman", Vector3(460, 0, -2.2), &"stubborn")
	var back22 := _guard(&"swordsman", Vector3(460.4, 0, 2.4), &"sly")
	await _frames(40)
	var s22 = front22._fighter.squad
	back22.global_position = Vector3(460.3, 0, 2.4)
	_aim(front22.global_position + Vector3.UP * 1.2)
	await _frames(1)
	back22._fighter._flank_waited = 0.0
	var not_at_once: bool = not s22.may_strike(back22)
	back22._fighter._flank_waited = SquadScript.BACK_WAIT + 0.1
	var at_back: bool = s22.may_strike(back22)
	back22.global_position = Vector3(462.4, 0, 0)
	var at_side: bool = s22.may_strike(back22)
	_check("H22 a man at your back strikes, busy or not; at your side he waits for his moment",
		s22.role_of(back22) == &"flank" and not_at_once and at_back and not at_side,
		"role %s, at once %s, after a moment at your back %s, at your side %s" % [s22.role_of(back22), not not_at_once, at_back, at_side])


# --------------------------------------------------------------------------

## A guard of `archetype` at `at`, facing `yaw` (set before he enters the
## tree: a man at his post keeps turning back to the way he first faced).
func _guard(archetype: StringName, at: Vector3, preset: StringName = &"steady", engage := true, yaw := 0.0) -> CharacterBody3D:
	var g: CharacterBody3D = GUARD.instantiate()
	g.archetype = archetype
	g.temperament = preset
	g.debug_ai = false
	g.position = at
	g.rotation.y = yaw
	add_child(g)
	g._attack_timer = 999.0
	g.attack_cooldown = 999.0

	if engage:
		g._engage(player)

	return g


## A clean start: nobody left, no bodies to find, no squad, nothing
## remembered, lit.
func _fresh() -> void:
	for g in get_tree().get_nodes_in_group(&"guards"):
		g.remove_from_group(&"guards")
		g.set_physics_process(false)
		g.queue_free()

	for b in get_tree().get_nodes_in_group(&"bodies"):
		b.queue_free()

	SquadScript.clear_all()
	GarrisonScript.clear_all()
	player.debug_light_level = 1.0
	await _frames(5)


## Makes the squad think again, and free to change its plan, at once.
func _think(squad: RefCounted) -> void:
	squad._last_think = -100.0
	squad._tactic_since = -100.0
	await _frames(3)


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
	player.combat._reset()
	player.reset_physics_interpolation()


func _aim(target: Vector3) -> void:
	var eye: Vector3 = player.get_node("Neck").global_position
	var d := target - eye
	player.rotation.y = atan2(-d.x, -d.z)
	player.get_node("Neck").rotation.x = atan2(d.y, Vector2(d.x, d.z).length())


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _check(test_name: String, ok: bool, detail: String) -> void:
	results.append("%s  %s   [%s]" % ["PASS" if ok else "FAIL", test_name, detail])
