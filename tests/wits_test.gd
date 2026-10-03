extends Node3D
## The guards' wits: how they get about (GuardNav), what they tell each other
## (Comms), what they notice and how they pass the time (GuardLife), what
## they pick up, throw and use against you (GuardHands, Dangers), their new
## places in the hunt (Squad: lookout, intercept, the watcher), how their
## blows answer the way you fight (GuardFighter), and how a broken man begs
## for his life and runs to his own when you let him go (GuardMercy).

const PLAYER := preload("res://Player.tscn")
const GUARD := preload("res://Guard.tscn")
const Props := preload("res://scripts/Interaction/Props.gd")
const NavBakerScript := preload("res://scripts/AISystem/NavBaker.gd")
const SquadScript := preload("res://scripts/AISystem/Squad.gd")
const GarrisonScript := preload("res://scripts/AISystem/Garrison.gd")
const TemperamentScript := preload("res://scripts/AISystem/Temperament.gd")
const BarrelScript := preload("res://scripts/Combat/Barrel.gd")
const HangingWeightScript := preload("res://scripts/Combat/HangingWeight.gd")
const AlarmBellScript := preload("res://scripts/Interaction/AlarmBell.gd")
const ArrowScript := preload("res://scripts/Combat/Arrow.gd")
const GuardScript := preload("res://scripts/AISystem/Guard.gd")
const GuardFighterScript := preload("res://scripts/AISystem/GuardFighter.gd")
const SoundBus := preload("res://scripts/StimuliSystem/SoundBus.gd")
const Comms := preload("res://scripts/AISystem/Comms.gd")
const LightProbe := preload("res://scripts/StimuliSystem/LightProbe.gd")
const TorchScript := preload("res://scripts/Visual/Torch.gd")
const LifeScript := preload("res://scripts/AISystem/GuardLife.gd")

const RELAXED := 0
const SUSPICIOUS := 1
const INVESTIGATING := 2
const SEARCHING := 3
const COMBAT := 4

var player: CharacterBody3D
var results: Array[String] = []
var _barks := {}
var _door9: Node3D
var _door3: Node3D


func _ready() -> void:
	# Every man at his class's own temperament, and exact cuts.
	TemperamentScript.rolling = false
	GuardScript.bleeding_on = false
	# The checks sit side by side along x.
	Props.block(self, Vector3(500, -0.5, 0), Vector3(1100, 1, 70))
	Props.block(self, Vector3(1225, -0.5, 0), Vector3(350, 1, 70))

	# W1 a passage 2.4 m wide.
	Props.block(self, Vector3(0, 1.5, 1.45), Vector3(16, 3, 0.5))
	Props.block(self, Vector3(0, 1.5, -1.45), Vector3(16, 3, 0.5))
	# W3 a wall with a door in it, across the way.
	Props.block(self, Vector3(77.25, 1.25, 0), Vector3(4.5, 2.5, 0.3))
	Props.block(self, Vector3(82.75, 1.25, 0), Vector3(4.5, 2.5, 0.3))
	Props.block(self, Vector3(80.0, 2.3, 0), Vector3(1.0, 0.4, 0.3))
	_door3 = Props.door(self, Vector3(79.5, 0, 0), 0.0, 1.0, 2.1)
	# W5 a lookout's platform.
	Props.block(self, Vector3(160, 1.5, -12), Vector3(3, 3, 3))
	# W9 a wall with a door in it.
	Props.block(self, Vector3(317.25, 1.25, 0), Vector3(4.5, 2.5, 0.3))
	Props.block(self, Vector3(322.75, 1.25, 0), Vector3(4.5, 2.5, 0.3))
	Props.block(self, Vector3(320.0, 2.3, 0), Vector3(1.0, 0.4, 0.3))
	_door9 = Props.door(self, Vector3(319.5, 0, 0), 0.0, 1.0, 2.1)
	# W10 a wall to shoot an arrow into.
	Props.block(self, Vector3(360, 1.5, -4), Vector3(6, 3, 0.4))
	# W18 a roof he cannot climb.
	Props.block(self, Vector3(680, 1.5, -8), Vector3(4, 3, 4))
	# W19 a wall of spikes.
	Props.block(self, Vector3(720, 1.5, -2.8), Vector3(6, 3, 0.4))
	# W22 a wall between one of them and you.
	Props.block(self, Vector3(766, 1.5, 5), Vector3(16, 3, 0.4))
	# W36, W37 walls with torches on them.
	Props.block(self, Vector3(800, 1.5, -4.2), Vector3(6, 3, 0.4))
	Props.block(self, Vector3(1000, 1.5, -4.2), Vector3(16, 3, 0.4))

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
	player.global_position = Vector3(500, 1.05, 30)
	Props.give_weapons(player, 12)
	player.inventory.select_by_id(&"sword")

	await baker.baked
	# Spikes are not level geometry: after the bake, like any trap.
	Props.spikes(self, Vector3(720, 1.0, -2.55), 5.0, 2.0, Vector3.BACK)
	await _frames(5)
	await _run()

	print("\n==== RESULTS ====")
	for r in results:
		print(r)
	get_tree().quit()


func _run() -> void:
	# Getting about

	# W1 two men meeting in a passage pass each other
	await _fresh()
	var east := _walker(Vector3(-6, 0, 0), Vector3(6, 0, 0))
	var west := _walker(Vector3(6, 0, 0), Vector3(-6, 0, 0))
	await _until(func(): return east.global_position.x > 5.0 and west.global_position.x < -5.0, 900)
	_check("W1 two men meeting nose to nose in a passage pass each other", east.global_position.x > 5.0 and west.global_position.x < -5.0,
		"east at x %.1f, west at x %.1f" % [east.global_position.x, west.global_position.x])

	# W2 a crate in the open on his way is walked round, not taken for his goal
	await _fresh()
	var jam := Props.crate(self, Vector3(40, 0.35, 0), 0.7, 30.0)
	jam.freeze = true
	var round := _walker(Vector3(34, 0, 0), Vector3(46, 0, 0))
	var gave_up := [false]
	for i in 720:
		await _frames(1)
		if round._path_blocked:
			gave_up[0] = true
		if round.global_position.x > 45.0:
			break
	_check("W2 a crate in his way is walked round, not taken for where he was going", round.global_position.x > 45.0 and not gave_up[0],
		"reached x %.1f gave up %s detours %d" % [round.global_position.x, gave_up[0], round._nav.detours])
	jam.queue_free()

	# W3 a door on his way is opened as he comes to it, not walked into
	await _fresh()
	var through := _walker(Vector3(80, 0, 5), Vector3(80, 0, -5))
	var gap_at_open := [-1.0]
	for i in 900:
		await _frames(1)
		if gap_at_open[0] < 0.0 and _door3.is_open:
			gap_at_open[0] = Vector2(through.global_position.x - 80.0, through.global_position.z).length()
		if through.global_position.z < -4.0:
			break
	_check("W3 a door on his way is opened before he reaches it, and he goes through", _door3.is_open and gap_at_open[0] >= 0.9 and through.global_position.z < -4.0,
		"opened %.2f m short, through to z %.1f" % [gap_at_open[0], through.global_position.z])

	# W4 chasing a runner, he makes for where the runner is going
	await _fresh()
	_put_player(Vector3(120, 1.05, 0))
	var chaser := _guard(&"swordsman", Vector3(120, 0, 9), PI)
	await _frames(20)
	Input.action_press("move_right")
	Input.action_press("sprint")
	await _frames(40)
	var feet: Vector3 = player.get_feet_position()
	var run: Vector3 = Vector3(player.velocity.x, 0, player.velocity.z)
	var goal: Vector3 = chaser._agent.target_position
	var lead := (goal - feet).dot(run.normalized()) if run.length() > 0.5 else 0.0
	_release_all()
	_check("W4 chasing a runner he makes for where you will be, not where you are", run.length() > 3.0 and lead > 0.8,
		"your speed %.1f, his goal %.2f m ahead of you" % [run.length(), lead])

	# Word, and lookouts

	# W5 a lookout who sees you stays at his post and calls where you are
	await _fresh()
	_put_player(Vector3(160, 1.05, 2))
	var watchman := _guard(&"", Vector3(160, 3.0, -12), PI, &"steady", false)
	watchman.lookout = true
	watchman.fov_vertical = 179.0
	var heard := _guard(&"swordsman", Vector3(172, 0, 12), PI, &"steady", false)
	await _until(func(): return watchman.state == COMBAT, 300)
	await _frames(240)
	var post_gap: float = Vector2(watchman.global_position.x - 160.0, watchman.global_position.z + 12.0).length()
	var spotted := _barks_of(watchman).filter(func(t): return _is_spotted_line(t))
	_check("W5 a lookout who sees you keeps his post and calls where you are; a man who hears it comes",
		watchman.state == COMBAT and post_gap < 1.0 and not spotted.is_empty() and heard.state >= INVESTIGATING and heard.last_known_position.distance_to(player.global_position) < 3.0,
		"lookout %d, %.2f m off his post, calls %s; the other %d, %.1f m off you" % [watchman.state, post_gap, spotted, heard.state, heard.last_known_position.distance_to(player.global_position)])

	# W6 a lookout with a bell near rings it: the whole garrison comes
	await _fresh()
	_put_player(Vector3(200, 1.05, 4))
	var bell: StaticBody3D = AlarmBellScript.build(self, Vector3(205, 0, -8), 0.0)
	var rang := [false]
	bell.rung.connect(func(_by): rang[0] = true)
	var bellman := _guard(&"", Vector3(200, 0, -8), PI, &"steady", false)
	bellman.lookout = true
	var faraway := _guard(&"swordsman", Vector3(240, 0, 25), 0.0, &"steady", false)
	faraway.hearing_acuity = 0.1
	await _until(func(): return rang[0], 600)
	await _frames(10)
	_check("W6 a lookout runs to the bell and rings it: far off men come to where he saw you, and the garrison is roused",
		rang[0] and faraway.state >= INVESTIGATING and faraway.last_known_position.distance_to(player.global_position) < 4.0 and GarrisonScript.of(player).alarm >= 0.99,
		"rang %s, far man %d %.1f m off you, alarm %.2f" % [rang[0], faraway.state, faraway.last_known_position.distance_to(player.global_position), GarrisonScript.of(player).alarm])
	bell.queue_free()

	# W7 a noise heard by two at their ease: one goes to look, the other covers
	await _fresh()
	player.debug_light_level = 0.0
	_put_player(Vector3(500, 1.05, 30))
	var one := _guard(&"", Vector3(240, 0, 0), 0.0, &"steady", false)
	var two := _guard(&"", Vector3(243, 0, 0), 0.0, &"steady", false)
	for g in [one, two]:
		g.look_around_time = 0.4
		g.search_points = 1
	await _frames(20)
	var at := Vector3(241.5, 0, -8)
	SoundBus.emit_sound(at, 58.0, self, &"test")
	SoundBus.emit_sound(at, 58.0, self, &"test")
	await _frames(40)
	var lookers := [one, two].filter(func(g): return g.state == INVESTIGATING)
	var coverers := [one, two].filter(func(g): return g.state == SUSPICIOUS and g._life.covering())
	var asked: Node = lookers[0] if not lookers.is_empty() else one
	var asked_ok: bool = _barks_of(asked).any(func(t): return _is_line(t, &"noise_ask"))
	await _until(func(): return one.state == RELAXED and two.state == RELAXED, 2400)
	var cleared: bool = _barks_of(asked).any(func(t): return _is_line(t, &"clear"))
	_check("W7 a noise heard by two: one says so and goes to look, the other covers him, and stands easy when he calls it clear",
		lookers.size() == 1 and coverers.size() == 1 and asked_ok and cleared and one.state == RELAXED and two.state == RELAXED,
		"looking %d covering %d asked %s cleared %s states %d/%d" % [lookers.size(), coverers.size(), asked_ok, cleared, one.state, two.state])

	# W8 two men at their ease talk; anything that stirs them ends it
	await _fresh()
	player.debug_light_level = 0.0
	var talker := _guard(&"", Vector3(280, 0, 0), -PI * 0.5, &"steady", false)
	var listener := _guard(&"", Vector3(282.6, 0, 0), PI * 0.5, &"steady", false)
	talker._life._talk_rest = 0.0
	listener._life._talk_rest = 0.0
	var said_by := []
	talker.barked.connect(func(t): said_by.append([talker, t]))
	listener.barked.connect(func(t): said_by.append([listener, t]))
	await _until(func(): return said_by.size() >= 2, 900)
	var talking: bool = talker._life.talking() and listener._life.talking()
	var turns: bool = said_by.size() >= 2 and said_by[0][0] != said_by[1][0]
	SoundBus.emit_sound(Vector3(281, 0, -6), 60.0, self, &"test")
	await _frames(20)
	_check("W8 two men at their ease talk, turn and turn about; a noise ends it",
		talking and turns and not talker._life.talking() and not listener._life.talking(),
		"talking %s lines %s, after the noise %s/%s" % [talking, said_by.map(func(e): return e[1]), talker._life.talking(), listener._life.talking()])

	# Things out of place

	# W9 a door you left open is noticed and shut
	await _fresh()
	player.debug_light_level = 0.0
	_light(Vector3(320, 2.6, 2.5))
	var porter := _guard(&"", Vector3(320, 0, 7), 0.0, &"steady", false)
	await _frames(20)
	_door9.frob(player)
	await _until(func(): return porter.state >= INVESTIGATING, 300)
	var noticed: bool = porter.state >= INVESTIGATING and _barks_of(porter).any(func(t): return _is_line(t, &"odd_door"))
	await _until(func(): return not _door9.is_open, 900)
	_check("W9 a door you left open is noticed, gone to and shut; the garrison stirs",
		noticed and not _door9.is_open and GarrisonScript.of(player).alarm >= 0.2,
		"noticed %s shut %s alarm %.2f" % [noticed, not _door9.is_open, GarrisonScript.of(player).alarm])

	# W10 your arrow in a wall is noticed and pulled out
	await _fresh()
	player.debug_light_level = 0.0
	_light(Vector3(360, 2.6, -1.5))
	var finder := _guard(&"", Vector3(360, 0, 2), 0.0, &"steady", false)
	await _frames(10)
	var arrow: StaticBody3D = ArrowScript.new()
	add_child(arrow)
	arrow.launch(Vector3(361.5, 1.3, 1.0), Vector3(0, 0, -40), 20.0, player, 1.0)
	# By its id: the arrow itself is gone once he has it.
	var arrow_id := arrow.get_instance_id()
	await _until(func(): return not is_instance_id_valid(arrow_id), 1200)
	var odd_arrow: bool = _barks_of(finder).any(func(t): return _is_line(t, &"odd_arrow"))
	_check("W10 your arrow in a wall is noticed and taken; the garrison stirs", not is_instance_id_valid(arrow_id) and odd_arrow and GarrisonScript.of(player).alarm >= 0.35,
		"taken %s said so %s alarm %.2f" % [not is_instance_id_valid(arrow_id), odd_arrow, GarrisonScript.of(player).alarm])

	# W11 a man gone from his post is missed by one who knew him
	await _fresh()
	player.debug_light_level = 0.0
	_light(Vector3(400, 2.6, -2))
	var friend := _guard(&"", Vector3(400, 0, 7), 0.0, &"steady", false)
	var taken := _guard(&"", Vector3(400, 0, -2), PI, &"steady", false)
	var name: String = taken.given_name
	await _frames(20)
	taken.knock_out(player, true)
	await _frames(2)
	for b in get_tree().get_nodes_in_group(&"bodies"):
		b.queue_free()
	await _until(func(): return friend.state >= INVESTIGATING, 600)
	var missed: bool = _barks_of(friend).any(func(t): return String(t).contains(name))
	_check("W11 a man gone from his post is missed, by name, by one who knew him, and he goes to look",
		missed and friend.state >= INVESTIGATING and friend.last_known_position.distance_to(Vector3(400, 0, -2)) < 1.5,
		"said %s, state %d, goes to %s" % [_barks_of(friend), friend.state, friend.last_known_position])

	# W12 searching the dark with the garrison roused, he lights a lantern
	await _fresh()
	player.debug_light_level = 0.0
	_put_player(Vector3(500, 1.05, 30))
	var searcher := _guard(&"", Vector3(440, 0, 0), 0.0, &"steady", false)
	await _frames(10)
	GarrisonScript.of(player).raise_alarm(0.6)
	searcher.alert = 70.0
	searcher.last_known_position = Vector3(440, 0, -6)
	searcher.has_last_known = true
	searcher._set_state(SEARCHING)
	await _until(func(): return searcher._hands.lantern != null, 240)
	await _frames(5)
	LightProbe.invalidate()
	var lit: float = LightProbe.light_at(self, searcher.global_position + Vector3.UP * 1.0)
	_check("W12 searching in the dark with the garrison roused, he lights a lantern (and it lights him)",
		searcher._hands.lantern != null and lit > 0.1, "lantern %s light %.2f" % [searcher._hands.lantern != null, lit])

	# The world, turned on you

	# W13 lit powder near him in a fight: he gets clear and shouts it
	await _fresh()
	_put_player(Vector3(480, 1.05, 4))
	var wary := _guard(&"swordsman", Vector3(480, 0, 0), 0.0)
	var mate := _guard(&"swordsman", Vector3(482, 0, -1), 0.0)
	await _frames(20)
	var powder: RigidBody3D = BarrelScript.new()
	powder.fuse = 3.0
	add_child(powder)
	powder.global_position = Vector3(480.6, 0.4, 1.6)
	powder.light(3.0)
	var at_blast := [0.0, 0.0]
	powder.exploded.connect(func(p): at_blast[0] = wary.global_position.distance_to(p) if is_instance_valid(wary) else 99.0; at_blast[1] = mate.global_position.distance_to(p) if is_instance_valid(mate) else 99.0)
	var powder_id := powder.get_instance_id()
	await _until(func(): return not is_instance_id_valid(powder_id), 400)
	var shouted: bool = _barks_of(wary).any(func(t): return t in Comms.DANGER) or _barks_of(mate).any(func(t): return t in Comms.DANGER)
	_check("W13 lit powder in a fight: they get clear of it and shout it", shouted and at_blast[0] > 4.0 and at_blast[1] > 4.0,
		"shouted %s, %.1f m and %.1f m off at the blast" % [shouted, at_blast[0], at_blast[1]])

	# W14 an archer sets off the powder beside you rather than shoot you
	await _fresh()
	_put_player(Vector3(520, 1.05, 0))
	var keg: RigidBody3D = BarrelScript.new()
	add_child(keg)
	keg.global_position = Vector3(521.3, 0.4, 0.4)
	var bowman := _guard(&"archer", Vector3(520, 0, -12), 0.0)
	bowman._attack_timer = 0.0
	bowman.attack_cooldown = 1.4
	var keg_id := keg.get_instance_id()
	await _until(func(): return not is_instance_id_valid(keg_id) or (instance_from_id(keg_id) as RigidBody3D).lit, 600)
	var went_up: bool = not is_instance_id_valid(keg_id) or (instance_from_id(keg_id) as RigidBody3D).lit
	_check("W14 an archer shoots the powder beside you", went_up, "went up %s" % went_up)
	await _frames(90)

	# W15 an archer cuts the rope of the weight you stand under
	await _fresh()
	_put_player(Vector3(560, 1.05, 0))
	var weight: Node3D = HangingWeightScript.new()
	weight.drop = 2.5
	add_child(weight)
	weight.global_position = Vector3(560, 6.4, 0)
	var shooter := _guard(&"archer", Vector3(560, 0, -12), 0.0)
	shooter._attack_timer = 0.0
	shooter.attack_cooldown = 1.4
	await _until(func(): return weight.cut, 600)
	_check("W15 an archer shoots the rope of the weight hung over you", weight.cut, "cut %s" % weight.cut)
	await _frames(60)
	weight.queue_free()

	# W16 knocked off his feet he loses his sword, and goes back for it
	await _fresh()
	_put_player(Vector3(600, 1.05, 8))
	var loser := _guard(&"swordsman", Vector3(600, 0, 0), 0.0)
	loser._fighter.grip_loss = 1.0
	await _frames(20)
	loser.knock_down(Vector3(0, 1.0, -2.5), null)
	await _frames(5)
	var dropped: bool = not loser._hands.armed and not get_tree().get_nodes_in_group(&"dropped_weapons").is_empty()
	await _until(func(): return is_instance_valid(loser) and loser._hands.armed, 900)
	_check("W16 knocked off his feet he loses his blade, gets up, and goes back for it",
		dropped and loser._hands.armed and loser._rig.weapon.visible,
		"dropped %s armed again %s" % [dropped, loser._hands.armed])

	# W17 his blade out of his reach, he fights with his fists (and cannot parry)
	await _fresh()
	_put_player(Vector3(640, 1.05, 0))
	var bare := _guard(&"swordsman", Vector3(640, 0, -1.6), 0.0)
	await _frames(10)
	var lost_blade: RigidBody3D = bare._hands.lose_weapon(Vector3.ZERO)
	if lost_blade != null:
		lost_blade.queue_free()
	bare._attack_timer = 0.0
	bare.attack_cooldown = 0.8
	var fists := [false]
	for i in 480:
		await _frames(1)
		if bare._phase == &"windup" and bare._attack in [&"punch", &"jab", &"kick"]:
			fists[0] = true
			break
	_check("W17 with no blade to be had he fights with fists and boots, and has no guard",
		fists[0] and bare._fighter.defend(&"quick", player) == &"", "threw %s: %s" % [fists[0], bare._attack])

	# W18 you on a roof: he throws what he can pick up
	await _fresh()
	player.invulnerable = false
	player.health = player.max_health
	_put_player(Vector3(680, 4.05, -8))
	var box := Props.crate(self, Vector3(681.2, 0.3, -2.6), 0.45, 2.5)
	var thrower := _guard(&"", Vector3(680, 0, -2.2), 0.0)
	thrower.fov_vertical = 179.0
	thrower._attack_timer = 0.0
	thrower.attack_cooldown = 1.5
	var held := [false]
	var nearest := [99.0]
	for i in 600:
		await _frames(1)
		if thrower._hands.held != null:
			held[0] = true
		if held[0] and is_instance_valid(box):
			nearest[0] = minf(nearest[0], box.global_position.distance_to(player.global_position))
		if player.health < player.max_health:
			break
	_check("W18 you out of his reach on a roof: he picks something up and throws it at you",
		held[0] and (player.health < player.max_health or nearest[0] < 1.5),
		"held %s nearest %.2f m your health %.0f" % [held[0], nearest[0], player.health])
	player.invulnerable = true

	# W19 spikes at your back: he kicks you onto them
	await _fresh()
	player.invulnerable = false
	player.health = player.max_health
	_put_player(Vector3(720, 1.05, -1.3))
	var kicker := _guard(&"swordsman", Vector3(720, 0, 0.4), 0.0)
	# Sure to mean it (0.6 and the hazard's 0.4): the check is that he closes
	# for the boot, not how often he thinks of it.
	kicker._fighter.kick_chance = 0.6
	kicker._attack_timer = 0.0
	kicker.attack_cooldown = 0.6
	var kicked := [false]
	var saw_it := [false]
	for i in 600:
		await _frames(1)
		saw_it[0] = saw_it[0] or kicker._fighter._hazard_there
		if kicker._phase == &"windup" and kicker._attack == &"kick":
			kicked[0] = true
			break
	_check("W19 your back to spikes: he sees them and puts his boot into you", saw_it[0] and kicked[0], "saw the spikes %s kicked %s" % [saw_it[0], kicked[0]])
	player.invulnerable = true

	# Their blows, and how they read you

	# W20 what follows a blow answers how it went
	await _fresh()
	var reader := _guard(&"swordsman", Vector3(900, 0, -20), 0.0, &"steady", false)
	await _frames(5)
	var f = reader._fighter
	f.read_skill = 1.0
	f._outcome = &"blocked"
	var bashes := 0
	for i in 400:
		if f._follow_up(&"left") == &"bash":
			bashes += 1
	f._outcome = &"dodged"
	var thrusts := 0
	for i in 400:
		if f._follow_up(&"overhead") == &"thrust":
			thrusts += 1
	# Blocked, with more of his string to come: straight into the pommel.
	reader._engage(player)
	reader._attack = &"left"
	reader._phase = &"strike"
	f._combo_left = 1
	f.recover_from_block()
	_check("W20 caught on your guard he follows with the pommel; stepped out of, the point; and a blocked string turns straight to it",
		bashes > 200 and thrusts > 240 and reader._attack == &"bash" and reader._phase == &"windup",
		"bash after a block %d/400, thrust after a dodge %d/400, after the block: %s %s" % [bashes, thrusts, reader._phase, reader._attack])

	# W21 parry them and they see it: more feints, blows held back, blows no
	#     parry is for
	await _fresh()
	_put_player(Vector3(900, 1.05, 10))
	var watcher21 := _guard(&"swordsman", Vector3(900, 0, 7.6), 0.0)
	await _frames(20)
	var squad21 = watcher21._fighter.squad
	var feint_before: float = squad21.bonus(&"feint")
	for i in 3:
		player.combat.defended.emit(&"parry")
	_check("W21 parry them and they read it: they feint more, hold blows back, and use the ones no parry is for",
		float(squad21.read[&"parry"]) >= 0.85 and squad21.bonus(&"feint") > feint_before + 0.2 and squad21.bonus(&"delay") > 0.25 and squad21.bonus(&"perilous") > 0.45,
		"read %.2f feint %.2f -> %.2f delay %.2f perilous %.2f" % [squad21.read[&"parry"], feint_before, squad21.bonus(&"feint"), squad21.bonus(&"delay"), squad21.bonus(&"perilous")])

	# The hunt

	# W22 one who still sees you tells the one who cannot where you are
	await _fresh()
	_put_player(Vector3(760, 1.05, 0))
	var sees22 := _guard(&"swordsman", Vector3(760, 0, -3), 0.0)
	var blind22 := _guard(&"swordsman", Vector3(765, 0, 8), 0.0)
	blind22.lose_time = 3.0
	# Rooted behind the wall: only word can tell him where you are.
	blind22.chase_speed = 0.0
	blind22._fighter.strafe_speed = 0.0
	await _frames(60)
	_put_player(Vector3(757, 1.05, 1.5))
	await _frames(240)
	_check("W22 whoever sees you tells the one who cannot: he keeps after you, to where you are now",
		blind22.state == COMBAT and not blind22.can_see_target and blind22.last_known_position.distance_to(player.global_position) < 2.0,
		"state %d sees %s knows %.2f m off" % [blind22.state, blind22.can_see_target, blind22.last_known_position.distance_to(player.global_position)])

	# W23 hunting in numbers, one of them keeps watch from a vantage
	await _fresh()
	_put_player(Vector3(800, 1.05, 0))
	var hunters: Array = []
	for spot in [Vector3(800, 0, -2.4), Vector3(802, 0, -2.8), Vector3(798, 0, -2.8)]:
		hunters.append(_guard(&"swordsman", spot, 0.0))
	await _frames(30)
	var squad23 = hunters[0]._fighter.squad
	player.debug_light_level = 0.0
	_put_player(Vector3(500, 1.05, 30))
	for one23 in hunters:
		one23._since_seen = 99.0
		one23.alert = 70.0
		one23._set_state(SEARCHING)
	await _frames(20)
	var watching = squad23.watcher()
	var where: Variant = watching._agent.target_position if watching != null else null
	var seen_at: Vector3 = squad23.last_sighting["position"]
	var off: float = Vector2(where.x - seen_at.x, where.z - seen_at.z).length() if where is Vector3 else -1.0
	_check("W23 hunting in numbers, one of them keeps watch from a vantage near where you were last seen",
		watching != null and watching._watching and off >= 4.0 and off <= 12.5,
		"watcher %s, his vantage %.1f m from the last sighting" % [watching != null, off])
	player.debug_light_level = 1.0

	# W24 running from them: one comes after you, one cuts you off
	await _fresh()
	_put_player(Vector3(840, 1.05, 0))
	var near24 := _guard(&"swordsman", Vector3(840, 0, -2.5), 0.0)
	var far24 := _guard(&"swordsman", Vector3(843, 0, -3.5), 0.0)
	await _frames(20)
	Input.action_press("move_right")
	Input.action_press("sprint")
	var cut_off := [false]
	for i in 120:
		await _frames(1)
		var sq = near24._fighter.squad
		if sq != null and (sq.role_of(near24) == &"intercept" or sq.role_of(far24) == &"intercept"):
			cut_off[0] = true
	_release_all()
	_check("W24 running from them, one of them goes to cut you off", cut_off[0], "cut off %s" % cut_off[0])

	# W25 losing you, he looks first the way you went
	await _fresh()
	var looker := _guard(&"", Vector3(880, 0, 0), 0.0, &"steady", false)
	await _frames(5)
	looker._seen_heading = Vector3(4, 0, 0)
	looker._since_seen = 1.0
	looker._start_looking()
	var first: float = float(looker._scan[0])
	_check("W25 losing you, he looks first the way you were going", absf(wrapf(first - (-PI * 0.5), -PI, PI)) < 0.05,
		"first look at %.2f rad (east is %.2f)" % [first, -PI * 0.5])

	# W26 sent for help with a bell nearer than any man, he rings it
	await _fresh()
	var runner := _guard(&"swordsman", Vector3(920, 0, 0), 0.0, &"steady", false)
	var bell26: StaticBody3D = AlarmBellScript.build(self, Vector3(926, 0, 0), 0.0)
	_guard(&"", Vector3(960, 0, 20), 0.0, &"steady", false)
	await _frames(10)
	var squad26 = SquadScript.of(player)
	var help: Node3D = squad26.helper_for(runner)
	_check("W26 a man sent for help makes for the bell when it is nearer than any man", help == bell26, "fetching %s" % [help])
	bell26.queue_free()

	# At your mercy

	# W27 broken and caught, badly hurt: his blade thrown down, on his knees
	await _fresh()
	_put_player(Vector3(1080, 1.05, 0))
	var beggar := _guard(&"", Vector3(1080, 0, 2.2), 0.0)
	beggar.health = beggar.max_health * 0.3
	await _frames(10)
	_break_heart(beggar)
	# Free to swing, if he had it in him.
	beggar._attack_timer = 0.0
	beggar.attack_cooldown = 0.5
	var swung := [false]
	for i in 120:
		await _frames(1)
		swung[0] = swung[0] or beggar._phase != &""
	var thrown_down := get_tree().get_nodes_in_group(&"dropped_weapons").any(func(w): return (w as Node3D).global_position.distance_to(beggar.global_position) < 3.5)
	var begged_27: bool = _barks_of(beggar).any(func(t): return _is_line(t, &"plead"))
	_check("W27 broken, badly hurt and caught: he throws his blade down and begs on his knees, and neither guards nor strikes",
		beggar._mercy.pleading and beggar._mercy.kneeling and beggar.activity() == &"plead_kneel" and not beggar._hands.armed and thrown_down and begged_27 and not swung[0] and not beggar._fighter.guarding,
		"begging %s kneeling %s (%s) armed %s blade down %s said %s swung %s" % [beggar._mercy.pleading, beggar._mercy.kneeling, beggar.activity(), beggar._hands.armed, thrown_down, _barks_of(beggar), swung[0]])

	# W28 broken but whole: he runs while you stand off; run him down and he
	#     begs on his feet, a hand out to you
	await _fresh()
	_put_player(Vector3(1120, 1.05, 0))
	var stander := _guard(&"", Vector3(1120, 0, 2.2), 0.0)
	await _frames(10)
	_break_heart(stander)
	await _frames(45)
	var ran_off: float = stander.global_position.distance_to(Vector3(1120, 0, 2.2))
	var begged_standing_off: bool = stander._mercy.pleading
	await _run_down(stander, 240)
	await _frames(20)
	_check("W28 broken but whole, he runs while you stand off; run him down and he begs on his feet",
		ran_off > 1.0 and not begged_standing_off and stander._mercy.pleading and not stander._mercy.kneeling and stander.activity() == &"plead_stand" and not stander._hands.armed,
		"ran %.1f m (begging %s), run down: begging %s kneeling %s (%s), terror %.2f" % [ran_off, begged_standing_off, stander._mercy.pleading, stander._mercy.kneeling, stander.activity(), stander._mercy.terror()])

	# W29 walk away from him: up and away to his own, and they hear of you
	await _fresh()
	_put_player(Vector3(1160, 1.05, 0))
	var spared := _guard(&"", Vector3(1160, 0, 2.2), 0.0)
	var mates: Array = [_guard(&"", Vector3(1158, 0, 28), 0.0, &"steady", false), _guard(&"", Vector3(1162, 0, 28), 0.0, &"steady", false)]
	await _frames(10)
	_break_heart(spared)
	await _run_down(spared, 240)
	var begged_29: bool = spared._mercy.pleading
	var begged_at: Vector3 = spared.global_position
	# You walk off.
	_put_player(Vector3(begged_at.x, 1.05, begged_at.z - 16.0))
	var near_mates := func() -> bool:
		return mates.any(func(m): return is_instance_valid(m) and Vector2(m.global_position.x - spared.global_position.x, m.global_position.z - spared.global_position.z).length() < 4.5)
	await _until(near_mates, 900)
	var reached: bool = near_mates.call()
	await _frames(40)
	var told: bool = mates.any(func(m): return is_instance_valid(m) and m.state >= INVESTIGATING)
	var thanked: bool = _barks_of(spared).any(func(t): return _is_line(t, &"spared"))
	_check("W29 walk away from a man begging: he is up and away to his own, and they hear where you are",
		begged_29 and thanked and reached and told and GarrisonScript.of(player).spared.size() == 1,
		"begged %s thanked %s reached them %s (%.1f m from where he begged) told %s" % [begged_29, thanked, reached, spared.global_position.distance_to(begged_at), told])

	# W30 strike him while he begs: he runs, and will not beg you again
	await _fresh()
	_put_player(Vector3(1220, 1.05, 0))
	var hit := _guard(&"", Vector3(1220, 0, 2.2), 0.0)
	await _frames(10)
	_break_heart(hit)
	await _run_down(hit, 240)
	var begged_30: bool = hit._mercy.pleading
	var hit_at: Vector3 = hit.global_position
	hit.take_hit(8.0, player, &"quick", Vector3.ZERO, Vector3(0, 0, -1))
	var cried: bool = _barks_of(hit).any(func(t): return _is_line(t, &"struck"))
	await _frames(90)
	var ran: float = hit.global_position.distance_to(hit_at)
	# You run him down again.
	var again := [false]
	for i in 3:
		await _run_down(hit, 60)
		again[0] = again[0] or hit._mercy.pleading
	_check("W30 strike a man begging: he cries out and runs, and does not beg you again",
		begged_30 and cried and ran > 2.0 and not again[0],
		"begged %s cried %s ran %.1f m begged again %s" % [begged_30, cried, ran, again[0]])

	# W31 a proud man does not beg
	await _fresh()
	_put_player(Vector3(1260, 1.05, 0))
	var proud := _guard(&"duelist", Vector3(1260, 0, 2.2), 0.0)
	await _frames(10)
	_break_heart(proud)
	var begged_31 := [false]
	for i in 90:
		await _frames(1)
		begged_31[0] = begged_31[0] or proud._mercy.pleading
	_check("W31 a proud man broken does not beg", not begged_31[0] and proud._fighter.squad.will_of(proud) == &"broken",
		"begged %s will %s" % [begged_31[0], proud._fighter.squad.will_of(proud)])

	# W32 cut a man down on his knees: they fear you the more, and the next
	#     man thinks twice before he begs
	await _fresh()
	_put_player(Vector3(1300, 1.05, 0))
	var doomed := _guard(&"", Vector3(1300, 0, 2.2), 0.0)
	doomed.health = doomed.max_health * 0.3
	await _frames(10)
	_break_heart(doomed)
	await _until(func(): return doomed._mercy.pleading, 120)
	var begged_32: bool = doomed._mercy.pleading
	var garrison32 = GarrisonScript.of(player)
	var dread_before: float = garrison32.dread
	doomed.take_hit(500.0, player, &"power", Vector3.ZERO, Vector3(0, 0, -1))
	await _frames(5)
	_check("W32 cut a man down begging: they dread you the more, and the next thinks twice before he begs",
		begged_32 and garrison32.slain_begging.size() == 1 and garrison32.dread >= dread_before + 0.17 and garrison32.mercy_hope() < 0.7,
		"begged %s slain begging %d dread %.2f -> %.2f hope %.2f" % [begged_32, garrison32.slain_begging.size(), dread_before, garrison32.dread, garrison32.mercy_hope()])

	# W33 two broken men caught together: one begs, the other runs while he
	#     can (not all of them at your feet at once)
	await _fresh()
	_put_player(Vector3(1340, 1.05, 0))
	var first33 := _guard(&"", Vector3(1339, 0, 2.2), 0.0)
	var second33 := _guard(&"", Vector3(1341, 0, 2.2), 0.0)
	await _frames(10)
	_break_heart(first33)
	await _run_down(first33, 240)
	var first_begs: bool = first33._mercy.pleading
	var second_from: Vector3 = second33.global_position
	var second_begged := [false]
	# At the other, while the first is on his knees beside him.
	Input.action_press("move_forward")

	for i in 45:
		var to33: Vector3 = second33.global_position - player.global_position
		player.rotation.y = atan2(-to33.x, -to33.z)
		await _frames(1)
		second_begged[0] = second_begged[0] or second33._mercy.pleading

	_release_all()
	player.velocity = Vector3.ZERO
	_check("W33 two broken men caught together: one begs, the other runs while he can",
		first_begs and first33._mercy.pleading and not second_begged[0] and second33.global_position.distance_to(second_from) > 1.5,
		"the first begs %s; the second begged %s, ran %.1f m" % [first_begs, second_begged[0], second33.global_position.distance_to(second_from)])

	# W34 spared, with nobody of his own to run to: he gets clear of you and
	#     goes back to his post, not stood about in the open
	await _fresh()
	_put_player(Vector3(1380, 1.05, 0))
	var lone := _guard(&"", Vector3(1380, 0, 2.2), 0.0)
	await _frames(10)
	_break_heart(lone)
	await _run_down(lone, 240)
	var begged_34: bool = lone._mercy.pleading
	# You walk off into the dark.
	player.debug_light_level = 0.0
	_put_player(Vector3(1380, 1.05, -30))
	var back_at := [-1]

	for i in 60 * 14:
		await _frames(1)

		if int(lone.state) == 0:
			back_at[0] = i
			break

	_check("W34 spared with nobody to run to, he gets clear and goes back to his post, not stood about",
		begged_34 and back_at[0] >= 0 and back_at[0] < 60 * 9,
		"begged %s, back to his post after %.1f s" % [begged_34, float(back_at[0]) / 60.0])

	# W35 running from you with you on his heels in the dark (heard, not
	#     seen): he does not give up the flight
	await _fresh()
	_put_player(Vector3(1380, 1.05, 0))
	var hounded := _guard(&"", Vector3(1380, 0, 2.2), 0.0)
	await _frames(10)
	player.debug_light_level = 0.0
	_break_heart(hounded)
	var dropped_it := [false]

	for i in 60 * 15:
		# His heart kept broken (nothing to give it back but time).
		if hounded._fighter.squad != null:
			hounded._fighter.squad.morale = -2.0

		# Five metres behind him, whichever way he runs.
		var off35: Vector3 = hounded.global_position - player.global_position
		off35.y = 0.0

		if off35.length() > 5.5 or off35.length() < 4.5:
			var at35: Vector3 = hounded.global_position - (off35.normalized() if off35.length() > 0.01 else Vector3.FORWARD) * 5.0
			player.global_position = Vector3(at35.x, 1.05, at35.z)
			player.velocity = Vector3.ZERO

		await _frames(1)
		dropped_it[0] = dropped_it[0] or int(hounded.state) != 4

	_check("W35 run from with you on his heels in the dark (heard, not seen), he does not give up the flight",
		not dropped_it[0] and hounded._fighter.squad != null and hounded._fighter.squad.will_of(hounded) == &"broken",
		"gave up %s, will %s" % [dropped_it[0], hounded._fighter.squad.will_of(hounded) if hounded._fighter.squad != null else &"-"])

	# W36 a torch you put out is noticed, gone to and lit again (his hand up
	#     to it); the garrison stirs
	await _fresh()
	_put_player(Vector3(800, 1.05, 30))
	player.debug_light_level = 0.0
	var torch36 := _wall_torch(Vector3(800, 2.4, -3.75))
	var keeper := _guard(&"", Vector3(800, 0, 4), 0.0, &"steady", false)
	keeper.hearing_acuity = 0.0
	await _frames(20)
	torch36.put_out(player)
	var reached_up := [false]
	await _until(func():
		reached_up[0] = reached_up[0] or float(keeper._rig._light_out) > 0.6
		return torch36.lit, 1500)
	var odd36: bool = _barks_of(keeper).any(func(t): return _is_line(t, &"odd_light"))
	_check("W36 a torch you put out is noticed, gone to and lit again, his hand up to it; the garrison stirs",
		torch36.lit and odd36 and reached_up[0] and GarrisonScript.of(player).alarm >= LifeScript.TORCH_ALARM - 0.001,
		"lit again %s said so %s reached up %s alarm %.2f" % [torch36.lit, odd36, reached_up[0], GarrisonScript.of(player).alarm])

	# W37 a second torch out not long after the first: no draught; someone is
	#     putting them out, and the garrison is roused
	await _fresh()
	_put_player(Vector3(1000, 1.05, 30))
	player.debug_light_level = 0.0
	var torch_a := _wall_torch(Vector3(995, 2.4, -3.75))
	var torch_b := _wall_torch(Vector3(1005, 2.4, -3.75))
	var first37 := _guard(&"", Vector3(995, 0, 3), 0.0, &"steady", false)
	var second37 := _guard(&"", Vector3(1005, 0, 3), 0.0, &"steady", false)

	for man in [first37, second37]:
		man.hearing_acuity = 0.0

	await _frames(20)
	torch_a.put_out(player)
	await _until(func(): return torch_a.lit, 1500)
	torch_b.put_out(player)
	await _until(func(): return torch_b.has_meta(&"noticed"), 600)
	await _frames(5)
	var said_lights := _barks_of(first37).any(func(t): return _is_line(t, &"odd_lights")) or _barks_of(second37).any(func(t): return _is_line(t, &"odd_lights"))
	_check("W37 a second torch out not long after the first: someone is putting them out, and the garrison is roused",
		torch_a.lit and torch_b.has_meta(&"noticed") and said_lights and GarrisonScript.of(player).alarm >= LifeScript.TORCHES_ALARM - 0.001,
		"first lit again %s, second noticed %s, said so %s, alarm %.2f" % [torch_a.lit, torch_b.has_meta(&"noticed"), said_lights, GarrisonScript.of(player).alarm])
	torch36.queue_free()
	torch_a.queue_free()
	torch_b.queue_free()


## A torch on a wall, one of the level's own (you can put it out).
func _wall_torch(at: Vector3) -> Node3D:
	var torch: Node3D = TorchScript.new()
	torch.can_douse = true
	add_child(torch)
	torch.global_position = at
	LightProbe.invalidate()
	return torch



## A guard of `archetype` at `at`, facing `yaw`. Engaged: fighting you, not
## striking until told.
func _guard(archetype: StringName, at: Vector3, yaw := 0.0, preset: StringName = &"steady", engage := true) -> CharacterBody3D:
	var g: CharacterBody3D = GUARD.instantiate()
	g.archetype = archetype
	g.temperament = preset
	g.debug_ai = false
	g.position = at
	g.rotation.y = yaw
	add_child(g)
	g._attack_timer = 999.0
	g.attack_cooldown = 999.0
	_barks[g] = []
	g.barked.connect(func(t): _barks[g].append(t))

	if engage:
		g._engage(player)

	return g


## A man walking from `from` to `to` (a patrol of those two points, waiting
## long at the far one).
func _walker(from: Vector3, to: Vector3) -> CharacterBody3D:
	var route := Node3D.new()
	add_child(route)

	for point in [from, to]:
		var marker := Marker3D.new()
		route.add_child(marker)
		marker.global_position = point

	var g := _guard(&"", from, 0.0, &"steady", false)
	g.patrol_wait = 30.0
	g.patrol_route = g.get_path_to(route)
	g._waypoints.assign(route.get_children())
	g._waypoint_index = 1
	g._go_to(to, true)
	return g


## You run at `g` flat out, turning to him as he goes, until he begs you
## (GuardMercy) or `max_frames` pass; then you stop.
func _run_down(g: Node3D, max_frames: int) -> void:
	Input.action_press("move_forward")
	Input.action_press("sprint")

	for i in max_frames:
		var to: Vector3 = g.global_position - player.global_position
		player.rotation.y = atan2(-to.x, -to.z)
		await _frames(1)

		if g._mercy.pleading:
			break

	_release_all()
	player.velocity = Vector3.ZERO


## Takes the heart out of `g`'s squad: he is judged broken at once
## (Squad.will_of).
func _break_heart(g: Node) -> void:
	var squad = g._fighter.squad
	squad.morale = -2.0
	squad._last_think = -100.0


func _light(at: Vector3) -> void:
	var lamp := OmniLight3D.new()
	lamp.omni_range = 9.0
	lamp.light_energy = 2.0
	lamp.add_to_group(&"wits_lights")
	add_child(lamp)
	lamp.global_position = at
	LightProbe.invalidate()


## A clean start: nobody left, nothing lying about, nothing remembered.
func _fresh() -> void:
	_release_all()

	for g in get_tree().get_nodes_in_group(&"guards"):
		g.remove_from_group(&"guards")
		g.set_physics_process(false)
		g.queue_free()

	for group in [&"bodies", &"dropped_weapons", &"dropped_lights", &"wits_lights", &"stray_arrows"]:
		for thing in get_tree().get_nodes_in_group(group):
			thing.queue_free()

	SquadScript.clear_all()
	GarrisonScript.clear_all()
	player.debug_light_level = 1.0
	player.invulnerable = true
	player.health = player.max_health
	await _frames(5)
	LightProbe.invalidate()


func _barks_of(g: Node) -> Array:
	return _barks.get(g, [])


## One of the lines a man calls on seeing you (Comms.SPOTTED).
func _is_spotted_line(text: String) -> bool:
	for form in Comms.SPOTTED:
		var head: String = String(form).split("%s")[0]

		if text.begins_with(head):
			return true

	return false


## One of the lines any temperament has for `situation`.
func _is_line(text: String, situation: StringName) -> bool:
	for tag in TemperamentScript.MORE_LINES:
		if text in (TemperamentScript.MORE_LINES[tag] as Dictionary).get(situation, []):
			return true

	return false


func _put_player(at: Vector3) -> void:
	_release_all()
	player.movement_state = 0
	player.current_move = null
	player.velocity = Vector3.ZERO
	player.global_position = at
	player.rotation.y = 0.0
	player.get_node("Neck").rotation.x = 0.0
	player.combat._reset()
	player.reset_physics_interpolation()


func _release_all() -> void:
	for a in ["move_forward", "move_back", "move_left", "move_right", "jump", "sprint", "crouch", "frob", "throw", "block", "kick", "dodge"]:
		if InputMap.has_action(a):
			Input.action_release(a)


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
